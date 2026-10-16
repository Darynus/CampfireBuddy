-- Buffs lesen: die verfolgten Zauber-IDs (Camp Benefits und selbst gewählte), den Essens-Buff
-- (+5 % Erfahrung durch Kills laut Beta-Guides) und ob man an einem Lagerfeuer steht.
-- Außerhalb des Kampfes, höchstens alle 0,2 Sekunden.
-- Im Kampf liefert das Spiel teils geheime Werte. Dann bleibt der letzte Stand, und die
-- Restzeit läuft aus der gemerkten Ablaufzeit weiter.
local ADDON, ns = ...

local B = { aktiv = {}, amFeuer = false, gelesen = false, essen = nil }
ns.Buffs = B

-- Jedes Essen hat seinen eigenen "Well Fed"-Buff mit eigener Zauber-ID. Gemeinsam ist das
-- Symbol (Spell_Misc_Food, Datei-ID 136000), und das hängt nicht an der Spielsprache.
-- Nimmt Forever ein anderes Symbol, markiert der Spieler seinen Buff einmal im Fenster.
ns.ESSEN_ICON = 136000
ns.ESSEN_TEXTUR = "Interface\\Icons\\Spell_Misc_Food"

local function geheim(v) return issecretvalue ~= nil and issecretvalue(v) end

-- Alle verfolgten Zauber-IDs
function B.Verfolgt()
  local t = {}
  for id in pairs(ns.STANDARD_BUFFS) do t[id] = true end
  for id in pairs(ns.db.eigeneBuffs) do t[id] = true end
  return t
end

-- Kopie einer Aura. nil, wenn irgendein Feld geheim ist: Dann wird sie ganz übersprungen,
-- statt später beim Vergleichen oder Rechnen einen Fehler auszulösen.
local function kopie(a)
  local id, name, dauer, ende, icon = a.spellId, a.name, a.duration, a.expirationTime, a.icon
  if geheim(id) or geheim(name) or geheim(dauer) or geheim(ende) or geheim(icon) then return nil end
  if type(id) ~= "number" then return nil end
  -- Instanz (für den Tooltip von Camp Benefits) und Werte (Punkte, z. B. +12 Stärke), nur wenn lesbar
  local instanz = a.auraInstanceID
  if geheim(instanz) or type(instanz) ~= "number" then instanz = nil end
  local punkte
  if type(a.points) == "table" and not geheim(a.points) then
    local p = a.points[1]
    if type(p) == "number" and not geheim(p) then punkte = p end
  end
  return { id = id, name = name, icon = icon, dauer = dauer or 0, ende = ende or 0, instanz = instanz, punkte = punkte }
end

-- Alle hilfreichen Buffs des Spielers: { {id, name, icon, dauer, ende} }.
-- Zweiter Rückgabewert: ob das Spiel die Liste liefern kann (nicht im Kampf, Funktion vorhanden).
function B.Alle()
  local liste = {}
  if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return liste, false end
  if InCombatLockdown and InCombatLockdown() then return liste, false end
  -- Bis das Spiel nichts mehr liefert. Retail kennt keine Grenze bei 40, passive Auren zählen mit.
  for i = 1, 255 do
    local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
    if not ok or not a then break end
    local k = kopie(a)
    if k then table.insert(liste, k) end
  end
  return liste, true
end

-- Gezielt nach einer Zauber-ID fragen (nur, wenn es die Liste nicht gibt)
local function einzeln(id)
  if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil end
  local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
  if not ok or not a then return nil end
  return kopie(a)
end

-- Ist dieser Buff ein Essens-Buff? Über gelernte IDs und Symbole oder das Well-Fed-Symbol.
function B.IstEssen(a)
  if not a then return false end
  if ns.db.essenIds[a.id] then return true end
  local icon = a.icon
  return type(icon) == "number" and (icon == ns.ESSEN_ICON or ns.db.essenIcons[icon] ~= nil)
end

-- Restzeit in Sekunden. nil: der Buff hat keine Ablaufzeit (hält, solange man bleibt).
function B.Rest(a)
  if not a or not a.ende or a.ende == 0 then return nil end
  return a.ende - ns.jetzt()
end

local function laenger(a, b)
  if not b then return true end
  return (B.Rest(a) or 1e9) > (B.Rest(b) or 1e9)
end

-- Rückgabe: false, wenn nicht gelesen werden konnte (Kampf)
function B:Lesen()
  if not ns.db then return false end
  if InCombatLockdown and InCombatLockdown() then
    self.nachKampf = true
    return false
  end
  local verfolgt = B.Verfolgt()
  local neu, feuer, essen = {}, false, nil
  local alle, geht = B.Alle()
  if geht then
    -- Alle Buffs nach ID und Name, für den Vergleich mit Klassen-Buffs (Objekte.Konflikt) und die
    -- Lager-Erkennung (ids[Zauber-ID] = Kopie der Aura)
    local ids, namen = {}, {}
    for _, a in ipairs(alle) do
      ids[a.id] = a
      if type(a.name) == "string" then namen[a.name] = true end
    end
    self.ids, self.namen = ids, namen
    for _, a in ipairs(alle) do
      if verfolgt[a.id] then neu[a.id] = a end
      if a.id == ns.CAMPFIRE_NEARBY then feuer = true end
      if B.IstEssen(a) and laenger(a, essen) then essen = a end
    end
  else
    feuer = einzeln(ns.CAMPFIRE_NEARBY) ~= nil
    for id in pairs(verfolgt) do neu[id] = einzeln(id) end
    for id in pairs(ns.db.essenIds) do
      local a = einzeln(id)
      if a and laenger(a, essen) then essen = a end
    end
  end

  -- Ein Buff ist weg und seine Zeit war fast um: abgelaufen (nicht abgebrochen)
  for id, alt in pairs(self.aktiv) do
    local rest = B.Rest(alt)
    if not neu[id] and rest and rest <= 3 then ns.Erinnerung:Abgelaufen(alt, B.IstEssen(alt)) end
  end
  if self.essen and not essen then
    local rest = B.Rest(self.essen)
    if rest and rest <= 3 then ns.Erinnerung:Abgelaufen(self.essen, true) end
  end

  -- Neu dazugekommener Buff mit Ablaufzeit (zum Beispiel eben gegessen): für den Knopf
  -- "ist mein Essen" auf der Status-Seite, falls das Essen nicht von selbst erkannt wird
  -- Dazu der Countdown beim Sitzen am Feuer: Zauber-ID noch unbekannt, deshalb ein neuer Buff
  -- mit etwa einer Minute Dauer, solange man am Feuer ist (oder eine bekannte ID).
  if geht then
    local vorher = self.zuletztIds or {}
    local jetzt = {}
    for _, a in ipairs(alle) do
      jetzt[a.id] = true
      if not vorher[a.id] and self.zuletztIds then
        if (a.dauer or 0) > 0 then self.neuester = { aura = a, zeit = ns.jetzt() } end
        local countdown = ns.COUNTDOWN_IDS[a.id]
          or (feuer and a.dauer >= 45 and a.dauer <= 75 and a.id ~= ns.CAMP_BENEFITS and not B.IstEssen(a))
        if countdown and ns.Show then
          self.countdown = a
          ns.Show:Starten(a.ende, a.dauer)
        end
        if a.id == ns.CAMP_BENEFITS and ns.Show and ns.Show.laeuft then ns.Show:Finale() end
      end
    end
    -- Countdown weg, bevor die Minute um war: aufgestanden
    local c = self.countdown
    if c and not jetzt[c.id] then
      self.countdown = nil
      local rest = B.Rest(c)
      if rest and rest > 3 then ns.Erinnerung:ZuFrueh() end
    end
    self.zuletztIds = jetzt
  end

  local warFeuer = self.amFeuer
  if warFeuer and not feuer and ns.Spiel then ns.Spiel:Aufgestanden() end
  self.aktiv, self.amFeuer, self.essen = neu, feuer, essen
  self.gelesen, self.nachKampf = true, false
  if feuer and not warFeuer then ns.Erinnerung:AmFeuer() end
  -- Lager-Erkennung: ankommen, weggehen, Bonus-Buffs und Camp Benefits auswerten
  if ns.Lager then
    if feuer and not warFeuer then ns.Lager:Ankunft() end
    if warFeuer and not feuer then ns.Lager:Weg() end
    ns.Lager:Pruefen()
  end
  ns.Erinnerung:Vollstaendig()
  ns.aktualisieren()
  return true
end

-- Viele Buff-Ereignisse kurz hintereinander: einmal lesen
local geplant = false
function B:Bald()
  if geplant then return end
  if not (C_Timer and C_Timer.After) then return self:Lesen() end
  geplant = true
  C_Timer.After(0.2, function()
    geplant = false
    B:Lesen()
  end)
end

local function laeuft(a)
  local rest = B.Rest(a)
  return a ~= nil and (rest == nil or rest > 0)
end

-- Fehlen Camp Benefits oder laufen sie in unter 10 Minuten ab?
function B:BrauchtLager()
  local lager = self:Lager()
  local rest = lager and B.Rest(lager)
  return not lager or (rest ~= nil and rest < 600)
end

function B:Lager()
  local a = self.aktiv[ns.CAMP_BENEFITS]
  if laeuft(a) then return a end
end

function B:Essen()
  if laeuft(self.essen) then return self.essen end
end

-- Aktive Buffs für Leiste und Fenster: Camp Benefits zuerst, dann was zuerst abläuft.
-- Der Essens-Buff ist dabei, auch wenn er nicht eigens verfolgt wird.
function B:Liste()
  local l = {}
  for _, a in pairs(self.aktiv) do
    if laeuft(a) then table.insert(l, a) end
  end
  local essen = self:Essen()
  if essen and not self.aktiv[essen.id] then table.insert(l, essen) end
  table.sort(l, function(x, y)
    if (x.id == ns.CAMP_BENEFITS) ~= (y.id == ns.CAMP_BENEFITS) then return x.id == ns.CAMP_BENEFITS end
    local rx, ry = B.Rest(x) or 1e9, B.Rest(y) or 1e9
    if rx ~= ry then return rx < ry end
    return x.id < y.id
  end)
  return l
end

-- Kandidat für "ist mein Essen": vor höchstens 2 Minuten dazugekommen, noch aktiv, kein Essen erkannt
function B:EssenKandidat()
  if self:Essen() or not self.neuester then return nil end
  if ns.jetzt() - self.neuester.zeit > 120 then return nil end
  local a = self.neuester.aura
  -- Essen läuft lange (meist 15 Minuten). Der Countdown beim Sitzen (1 Minute) ist nie Essen.
  if not laeuft(a) or ns.STANDARD_BUFFS[a.id] or (a.dauer or 0) <= 120 then return nil end
  return a
end

-- Wurde das erkannte Essen vom Spieler markiert (dann darf er die Markierung vergessen)?
function B:EssenMarkiert()
  local e = self:Essen()
  if not e then return nil end
  if ns.db.essenIds[e.id] or (type(e.icon) == "number" and ns.db.essenIcons[e.icon]) then return e end
end

-- Was fehlt gerade? Für die Hinweise beim Login und Gruppenbeitritt.
function B:Fehlt()
  local L = ns.L
  local t = {}
  if not self:Lager() then table.insert(t, L.MISSING_CAMP) end
  if ns.db.essenErinnern and not self:Essen() then table.insert(t, L.MISSING_FOOD) end
  return t
end

-- Buff selbst verfolgen oder nicht mehr verfolgen (Camp Benefits ist immer dabei)
function B:Umschalten(id, name)
  if ns.STANDARD_BUFFS[id] then return nil end
  local an = ns.db.eigeneBuffs[id] == nil
  ns.db.eigeneBuffs[id] = an and (name or tostring(id)) or nil
  self:Lesen()
  return an
end

-- Buff als Essens-Buff markieren oder die Markierung entfernen (über ID und Symbol)
-- Gilt der Buff schon als Essen, wird die Markierung entfernt: seine ID, sein Symbol und alle
-- anderen IDs mit demselben Symbol. Sonst werden ID und Symbol gemerkt.
-- essenIds[id] = { name, icon }
function B:EssenUmschalten(a)
  if not a then return nil end
  local an = not B.IstEssen(a)
  local name = a.name or tostring(a.id)
  local icon = type(a.icon) == "number" and a.icon or nil
  if an then
    ns.db.essenIds[a.id] = { name = name, icon = icon }
    if icon and icon ~= ns.ESSEN_ICON then ns.db.essenIcons[icon] = name end
  else
    ns.db.essenIds[a.id] = nil
    if icon then
      ns.db.essenIcons[icon] = nil
      for id, e in pairs(ns.db.essenIds) do
        if type(e) == "table" and e.icon == icon then ns.db.essenIds[id] = nil end
      end
    end
  end
  self:Lesen()
  -- Was gilt jetzt wirklich? (Ein Buff mit dem Well-Fed-Symbol bleibt Essen, auch ohne Markierung)
  return B.IstEssen(a)
end

-- UNIT_AURA nur für den Spieler, auf einem eigenen Rahmen: Gruppe, Schlachtzug und
-- Namensplaketten laufen so gar nicht erst durch. Im Kampf nur merken, nach dem Kampf lesen.
local auren = CreateFrame("Frame")
if auren.RegisterUnitEvent then
  auren:RegisterUnitEvent("UNIT_AURA", "player")
else
  auren:RegisterEvent("UNIT_AURA")
end
auren:SetScript("OnEvent", function(_, _, einheit)
  if einheit ~= "player" then return end
  if InCombatLockdown and InCombatLockdown() then B.nachKampf = true return end
  B:Bald()
end)
ns.ereignis("PLAYER_ENTERING_WORLD", function() B:Bald() end)
ns.ereignis("PLAYER_REGEN_ENABLED", function() if B.nachKampf then B:Bald() end end)
