-- Lager-Erkennung: Was steht an diesem Lagerfeuer, wie groß ist es (3, 5 oder 10 Plätze) und was
-- kann der Char noch beisteuern oder aufwerten? Das Spiel hat dafür keine Schnittstelle. Gesammelt
-- wird aus vier Quellen, die stärkste gewinnt:
--   1. Aufstellen: der Zauber beim Benutzen eines Bausatzes (eigener Char und Gruppe in der Nähe).
--      Genaues Objekt samt Stufe, beim Feuer die Größe. Zauber-IDs der Objekte liefert das Spiel
--      (C_Item.GetItemSpell), die der Feuer stehen in Objekte.lua.
--   2. Tooltip von Camp Benefits: eine Zeile je Objekt ("Name: Wirkung"). Ingenieurs- und
--      Koch-Objekte fehlen dort.
--   3. Maus über dem Feuer oder einem Objekt (Tooltip eines Spielobjekts). Nicht bei Objekten,
--      die genauso heißen wie normale Dinge im Dorf (Amboss, Webstuhl, Spinnrad, Gerbgestell,
--      Objekte.lua "mehrdeutig"): Das Spiel nennt bei Objekten weder Position noch Kennung
--      (Patricks Fund in Goldshire, 16. Okt).
--   4. Aufstellen durch Fremde in der Nähe (Namensplaketten, Ziel, Maus), solange man am Feuer ist.
-- Die Boni selbst stehen in Forever alle im einen Buff Camp Benefits (Zeilen "Objekt: Wirkung"),
-- eigene Buffs je Objekt gibt es nicht (Patricks Screenshot, 16. Okt). LG:Benefits liest sie.
-- Namen werden nur mit den Namen verglichen, die das Spiel selbst zu den IDs nennt. So passt es in
-- jeder Spielsprache. Gelesen wird nur außerhalb des Kampfes. Es wird nichts gesendet.
local ADDON, ns = ...
local L = ns.L
local O = ns.Objekte

local LG = { objekte = {}, aktiv = false }
ns.Lager = LG

local FEUER_DAUER = 15 * 60   -- ein Feuer brennt etwa 15 Minuten
local WEG_FRIST = 90          -- so lange darf man weg sein, ohne dass das Lager vergessen wird
local FEUER_VORLAUF = 20      -- Feuer aufgestellt, "Campfire Nearby" kommt kurz danach

local function geheim(v) return issecretvalue ~= nil and issecretvalue(v) end
local function imKampf() return InCombatLockdown and InCombatLockdown() end
local function serverZeit() return (GetServerTime and GetServerTime()) or time() end

-- Stufe eines Objekts in seiner Familie (1, 2, 3). Beide Faction Banner sind Stufe 1.
local RANG = {}
do
  local zaehler = {}
  for _, o in ipairs(O.LISTE) do
    if o.fraktion and o.fraktion ~= "Alliance" then
      RANG[o] = 1
    else
      zaehler[o.familie] = (zaehler[o.familie] or 0) + 1
      RANG[o] = zaehler[o.familie]
    end
  end
end
function LG.Rang(o) return RANG[o] or 1 end

-- Namen aller Objekte, wie das Spiel sie nennt (Gegenstand, Rezept, Aufstell-Zauber), längste
-- zuerst. Noch nicht geladene Gegenstände werden angefordert und später nachgetragen.
local namen, namenVoll = nil, false
local function namenListe()
  if namen and namenVoll then return namen end
  local t, voll = {}, true
  local function dazu(n, o)
    if type(n) == "string" and n ~= "" and not geheim(n) then table.insert(t, { n = n, o = o }) end
  end
  for _, o in ipairs(O.LISTE) do
    if O.Passt(o) then
      local itemName = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(o.item)
      if not itemName then
        voll = false
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, o.item) end
      end
      dazu(itemName, o)
      dazu(C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(o.spell), o)
      if o.platz then dazu(C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(o.platz), o) end
    end
  end
  table.sort(t, function(a, b) return #a.n > #b.n end)
  namen, namenVoll = t, voll
  return t
end

-- Welches Objekt meint dieser Text? Er muss mit dem Namen beginnen ("Lodestone: +12 ...").
function LG.Erkennen(text)
  if type(text) ~= "string" or geheim(text) then return nil end
  text = string.gsub(text, "^%s+", "")
  for _, e in ipairs(namenListe()) do
    if string.sub(text, 1, #e.n) == e.n then return e.o end
  end
end

-- Aufstell-Zauber: [Zauber-ID] = Objekt. Fehlende werden höchstens alle 10 Sekunden nachgefragt.
local platz, platzFehlt, platzZeit = {}, true, -100
local function platzKarte()
  if platzFehlt and ns.jetzt() - platzZeit > 10 then
    platzZeit, platzFehlt = ns.jetzt(), false
    for _, o in ipairs(O.LISTE) do
      if o.platz then platz[o.platz] = o end
      local ok, _, id = false, nil, nil
      if C_Item and C_Item.GetItemSpell then ok, _, id = pcall(C_Item.GetItemSpell, o.item) end
      if ok and type(id) == "number" then platz[id] = o else platzFehlt = true end
    end
  end
  return platz
end
LG.PlatzKarte = platzKarte

-- Lager-Sitzung ------------------------------------------------------------------------------

function LG:Neu()
  self.seit = ns.jetzt()
  self.feuer = nil
  self.objekte = {}
  self.tipp = nil
  self.gelesen = nil
end

-- Position des Chars in Metern der Welt (nil in Instanzen oder wenn das Spiel sie nicht nennt)
local function position()
  if not UnitPosition then return nil end
  local ok, y, x, _, karte = pcall(UnitPosition, "player")
  if not ok or type(x) ~= "number" or type(y) ~= "number" or geheim(x) or geheim(y) then return nil end
  return { x = x, y = y, karte = karte }
end

-- Gemerkten Stand nach /reload zurückholen: nur, wenn er höchstens so alt ist wie ein Feuer und
-- man am selben Feuer steht (Feuer sind mindestens 100 Meter voneinander entfernt). Ohne Position
-- nur bei der ersten Ankunft seit dem Laden, also nach /reload am Feuer.
local function wiederholen(self, ersteAnkunft)
  local m = ns.db and ns.db.lager
  if type(m) ~= "table" or type(m.zeit) ~= "number" or serverZeit() - m.zeit > FEUER_DAUER then return end
  local hier = position()
  if hier and type(m.x) == "number" then
    local dx, dy = hier.x - m.x, hier.y - m.y
    if hier.karte ~= m.karte or dx * dx + dy * dy > 60 * 60 then return end
  elseif not ersteAnkunft then
    return
  end
  local nachZauber = {}
  for _, o in ipairs(O.LISTE) do nachZauber[o.spell] = o end
  if m.feuer and nachZauber[m.feuer] then self.feuer = { o = nachZauber[m.feuer], quelle = m.feuerQuelle or "cast" } end
  for _, e in ipairs(m.objekte or {}) do
    local o = type(e) == "table" and nachZauber[e.spell]
    -- Maus-Funde bei mehrdeutigen Objekten zählen nicht (siehe oben), auch nicht aus älteren Ständen
    if o and not (e.quelle == "maus" and o.mehrdeutig) then self.objekte[o.familie] = { o = o, quelle = e.quelle, wer = e.wer, genau = true } end
  end
end

local function speichern(self)
  if not ns.db then return end
  local liste = {}
  for _, e in pairs(self.objekte) do
    if e.genau then table.insert(liste, { spell = e.o.spell, quelle = e.quelle, wer = e.wer }) end
  end
  local hier = position() or {}
  ns.db.lager = { zeit = serverZeit(), feuer = self.feuer and self.feuer.o.spell,
    feuerQuelle = self.feuer and self.feuer.quelle, objekte = liste, x = hier.x, y = hier.y, karte = hier.karte }
end

-- "Campfire Nearby" kam (Buffs.lua)
function LG:Ankunft()
  local t = ns.jetzt()
  if not self.aktiv and not (self.weg and t - self.weg < WEG_FRIST) then
    self:Neu()
    wiederholen(self, not self.schonDa)
    -- Ab jetzt gehört der gemerkte Stand zu diesem Lager (auch wenn es leer ist)
    speichern(self)
  end
  self.schonDa = true
  self.aktiv, self.weg = true, nil
  local f = self.letztesFeuer
  if f and t - f.zeit < FEUER_VORLAUF then self:FeuerSetzen(f.o, "cast", f.wer) end
  self:Geaendert()
end

-- "Campfire Nearby" ist weg
function LG:Weg()
  if not self.aktiv then return end
  self.aktiv, self.weg = false, ns.jetzt()
  self:Geaendert()
end

function LG:FeuerSetzen(o, quelle, wer)
  local alt = self.feuer
  if alt and alt.o == o then return end
  -- Ein genauer Fund (Aufstellen) wird nicht von einer Vermutung überschrieben
  if alt and alt.quelle == "cast" and quelle ~= "cast" then return end
  self.feuer = { o = o, quelle = quelle, wer = wer }
  speichern(self)
  self:Geaendert()
end

-- Objekt am Feuer merken. Höhere Stufe gewinnt (sie ersetzt die kleinere am Feuer).
function LG:Merken(o, quelle, wer)
  if o.art == "feuer" then return self:FeuerSetzen(o, quelle, wer) end
  local alt = self.objekte[o.familie]
  if alt and alt.genau then
    if LG.Rang(alt.o) > LG.Rang(o) then return end
    if alt.o == o then
      if wer and not alt.wer then alt.wer = wer speichern(self) end
      return
    end
  end
  self.objekte[o.familie] = { o = o, quelle = quelle, wer = wer, genau = true }
  speichern(self)
  self:Geaendert()
end

-- Wurde diese Aura während dieses Lagers vergeben? Bonus-Buffs halten eine Stunde und stammen
-- sonst womöglich vom letzten Lager.
local function frisch(self, a)
  if not (a and self.seit) or (a.dauer or 0) <= 0 then return false end
  return (a.ende - a.dauer) >= self.seit - 5
end

-- Ohne Farbcodes (|cffxxxxxx ... |r), sonst passt der Anfang der Zeile nicht zum Namen
local function ohneFarbe(text)
  return (string.gsub(string.gsub(text, "|c%x%x%x%x%x%x%x%x", ""), "|r", ""))
end

local function zerlegen(zeilen, feld)
  if type(feld) == "string" and not geheim(feld) then
    for teil in string.gmatch(ohneFarbe(feld), "[^\r\n]+") do
      teil = string.gsub(teil, "^%s+", "")
      if teil ~= "" then table.insert(zeilen, teil) end
    end
  end
end

-- Zeilen aus dem Tooltip einer Aura. Erst über C_TooltipInfo, sonst über einen eigenen,
-- unsichtbaren Tooltip.
local lesen
local function tooltipZeilen(instanz)
  local zeilen = {}
  if not instanz then return zeilen end
  if C_TooltipInfo and C_TooltipInfo.GetUnitBuffByAuraInstanceID then
    local ok, daten = pcall(C_TooltipInfo.GetUnitBuffByAuraInstanceID, "player", instanz)
    if ok and type(daten) == "table" and type(daten.lines) == "table" then
      for _, l in ipairs(daten.lines) do
        zerlegen(zeilen, l.leftText)
        zerlegen(zeilen, l.rightText)
      end
    end
  end
  if #zeilen == 0 and GameTooltip and GameTooltip.SetUnitBuffByAuraInstanceID then
    if lesen == nil then
      local ok, t = pcall(CreateFrame, "GameTooltip", "CampfireBuddyLesen", nil, "GameTooltipTemplate")
      lesen = ok and t or false
    end
    if lesen then
      lesen:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE")
      if pcall(lesen.SetUnitBuffByAuraInstanceID, lesen, "player", instanz) then
        for i = 1, (lesen.NumLines and lesen:NumLines()) or 0 do
          local s = _G["CampfireBuddyLesenTextLeft" .. i]
          if s and s.GetText then zerlegen(zeilen, s:GetText()) end
        end
      end
      lesen:Hide()
    end
  end
  return zeilen
end

-- Camp Benefits lesen: { [Familie] = { o = Objekt, wert = Zahl } } und die Zeilen dazu. Je
-- Vergabe einmal (gemerkt über die Ablaufzeit), im Kampf der letzte Stand.
function LG:Benefits()
  local cb = (ns.Buffs.ids or {})[ns.CAMP_BENEFITS]
  if type(cb) ~= "table" then
    self.benefits, self.benefitsEnde, self.benefitsZeilen = nil, nil, nil
    return {}, {}
  end
  if (self.benefits and self.benefitsEnde == cb.ende) or imKampf() then
    return self.benefits or {}, self.benefitsZeilen or {}
  end
  local instanz = cb.instanz
  if not instanz and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, ns.CAMP_BENEFITS)
    if ok and type(a) == "table" and not geheim(a.auraInstanceID) then instanz = a.auraInstanceID end
  end
  local zeilen = tooltipZeilen(instanz)
  local boni = {}
  for _, z in ipairs(zeilen) do
    local o = LG.Erkennen(z)
    if o and o.art ~= "feuer" then
      local wert = tonumber(string.match(z, ":%D*(%d+)"))
      local alt = boni[o.familie]
      if not alt or LG.Rang(o) > LG.Rang(alt.o) then boni[o.familie] = { o = o, wert = wert } end
    end
  end
  -- Nur merken, wenn der Tooltip schon Zeilen hatte (gleich nach der Vergabe kann er leer sein)
  if #zeilen > 0 then self.benefits, self.benefitsEnde, self.benefitsZeilen = boni, cb.ende, zeilen end
  return boni, zeilen
end

-- Camp Benefits gerade an diesem Feuer bekommen? Seit dem Ankommen, oder in den letzten zwei
-- Minuten (man sitzt eine Minute, dabei kann "Campfire Nearby" kurz fehlen).
local function hierBekommen(self, cb)
  if (cb.dauer or 0) <= 0 then return false end
  local vergeben = cb.ende - cb.dauer
  return vergeben >= (self.seit or 0) - 90 or vergeben >= ns.jetzt() - 120
end

-- Nach jedem Lesen der Buffs (außerhalb des Kampfes): Camp Benefits auswerten
local nochmal = 0
function LG:Pruefen()
  if imKampf() then return end
  local ids = ns.Buffs.ids or {}
  local cb = ids[ns.CAMP_BENEFITS]
  local boni, zeilen = self:Benefits()
  if not self.aktiv then return end
  local neu = false
  -- Gerade an diesem Feuer bekommen: die Objekte darin stehen hier (einmal je Vergabe)
  if type(cb) == "table" and hierBekommen(self, cb) and self.gelesen ~= cb.ende then
    if #zeilen > 0 then
      self.gelesen = cb.ende
      for _, b in pairs(boni) do self:Merken(b.o, "lager") end
      neu = true
    elseif nochmal < 5 and C_Timer and C_Timer.After then
      -- Tooltip noch leer: gleich noch einmal versuchen
      nochmal = nochmal + 1
      C_Timer.After(1, function() LG:Pruefen() end)
    end
  end
  if type(cb) == "table" and self.gelesen == cb.ende then nochmal = 0 end
  -- Bonus-Buffs: Familie da, Stufe unbekannt (nur, wenn nichts Genaueres bekannt ist)
  for fam, f in pairs(O.FAMILIE) do
    local a = f.aura and ids[f.aura]
    if type(a) == "table" and frisch(self, a) and not self.objekte[fam] and fam ~= "zelt" then
      self.objekte[fam] = { o = O.BASIS[fam], quelle = "bonus", genau = false }
      neu = true
    end
  end
  if neu then self:Geaendert() end
  if type(cb) == "table" and self.gelesen == cb.ende and not self.tipp then
    self.tipp = true
    self:Tipp()
  end
end

-- Ereignisse ---------------------------------------------------------------------------------

local function gruppenEinheit(einheit)
  return einheit == "player" or (type(einheit) == "string" and (string.match(einheit, "^party%d") or string.match(einheit, "^raid%d")))
end

-- Fremde in Sichtweite (Namensplakette, Ziel, Fokus, Maus): Wer am selben Feuer steht, ist nah
-- genug, dass das Spiel ihn so kennt. Lagerfeuer stehen mindestens 100 Meter auseinander.
local function fremdNah(einheit)
  return type(einheit) == "string" and (string.match(einheit, "^nameplate%d") ~= nil or einheit == "target"
    or einheit == "focus" or einheit == "mouseover")
end

local function naheBei(einheit)
  if einheit == "player" or not UnitInRange then return true end
  local ok, drin, geprueft = pcall(UnitInRange, einheit)
  if ok and geprueft and not geheim(drin) then return drin and true or false end
  return true
end

local function name(einheit)
  local ok, n = pcall(UnitName, einheit)
  if ok and type(n) == "string" and not geheim(n) then return n end
end

function LG:Gezaubert(einheit, spellID)
  local gruppe = gruppenEinheit(einheit)
  if not (gruppe or (self.aktiv and fremdNah(einheit))) or geheim(spellID) or type(spellID) ~= "number" then return end
  local o = platzKarte()[spellID]
  if not o then return end
  local wer = name(einheit)
  if o.art == "feuer" then
    self.letztesFeuer = { o = o, zeit = ns.jetzt(), wer = wer }
    -- Selbst angezündet: neues Lager genau hier
    if einheit == "player" then
      self:Neu()
      self.aktiv = true
      self:FeuerSetzen(o, "cast", wer)
    end
  elseif self.aktiv and (not gruppe or naheBei(einheit)) then
    self:Merken(o, "cast", wer)
  end
end

ns.ereignis("UNIT_SPELLCAST_SUCCEEDED", function(einheit, _, spellID) LG:Gezaubert(einheit, spellID) end)

-- Maus über einem Spielobjekt am Feuer: Feuer und Objekte mit eindeutigem Namen
function LG:Objekt(text)
  if not self.aktiv or imKampf() then return end
  local o = LG.Erkennen(text)
  if o and not o.mehrdeutig then self:Merken(o, "maus") end
end

ns.beimStart(function()
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
    and Enum.TooltipDataType.Object then
    pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Object, function(_, daten)
      local zeile = type(daten) == "table" and type(daten.lines) == "table" and daten.lines[1]
      if type(zeile) == "table" then LG:Objekt(zeile.leftText) end
    end)
  end
end)

-- Auswertung ---------------------------------------------------------------------------------

-- Plätze: gesamt (nil, wenn die Feuergröße unbekannt ist) und bekannte Objekte
function LG:Plaetze()
  local belegt = 0
  for _ in pairs(self.objekte) do belegt = belegt + 1 end
  return self.feuer and self.feuer.o.plaetze, belegt
end

-- Was kann dieser Char für das Lager tun? Je Bonus das beste eigene Objekt:
--   art "neu": der Bonus fehlt am Feuer, art "besser": höhere Stufe ersetzt die vorhandene.
-- Ohne Lager in der Nähe: alles, was er grundsätzlich beisteuern kann.
-- Sortiert: in den Taschen, dann baubar, dann fehlendes Material.
local ORDNUNG = { vorrat = 1, bereit = 2, material = 3 }
function LG:Vorschlaege(berufe)
  berufe = berufe or O.Berufe()
  local t, gesehen = {}, {}
  for i, basis in ipairs(O.LISTE) do
    local fam = basis.familie
    if basis.art ~= "feuer" and not gesehen[fam] then
      gesehen[fam] = true
      local best, z = O.Bestes(fam, berufe)
      local da = self.objekte[fam]
      if best then
        if not da then
          table.insert(t, { o = best, art = "neu", zustand = z, nr = i })
        elseif da.genau and LG.Rang(best) > LG.Rang(da.o) and (z == "vorrat" or z == "bereit") then
          table.insert(t, { o = best, art = "besser", zustand = z, statt = da.o, nr = i })
        end
      end
    end
  end
  table.sort(t, function(a, b)
    if ORDNUNG[a.zustand] ~= ORDNUNG[b.zustand] then return ORDNUNG[a.zustand] < ORDNUNG[b.zustand] end
    if a.art ~= b.art then return a.art == "neu" end
    return a.nr < b.nr
  end)
  return t
end

-- Lohnt dieses Objekt hier (Camp-Kit-Leiste)? Ohne Lager: wenn sein Bonus dem Char noch fehlt.
function LG:Vorschlag(o)
  if not self.aktiv then return not O.BonusAktiv(o) and not O.Konflikt(o) end
  local da = self.objekte[o.familie]
  return not da or (da.genau and LG.Rang(o) > LG.Rang(da.o))
end

-- Alle Lager-Boni mit Zustand, für die Übersicht im Reiter Camp. Je Bonus:
--   { fam, bonus, basis, best, bestZustand, konflikt, da, punkte, zustand }
-- zustand: "aktiv" (Bonus-Buff da), "klasse" (ein Klassen-Buff deckt ihn), "da" (Objekt steht am
-- Feuer, noch nicht abgesessen), "du" (du hast es dabei oder kannst es bauen), "material", "fehlt"
function LG:BoniUebersicht(berufe)
  berufe = berufe or O.Berufe()
  local ids = ns.Buffs.ids or {}
  local benefits = self:Benefits()
  local t = {}
  for _, fam in ipairs(O.BONUS_REIHE) do
    local f, basis = O.FAMILIE[fam], O.BASIS[fam]
    local a = f.aura and ids[f.aura]
    local b = benefits[fam]
    local best, z = O.Bestes(fam, berufe)
    local e = { fam = fam, bonus = f.bonus, basis = basis, best = best, bestZustand = z,
      konflikt = O.Konflikt(basis), da = self.aktiv and self.objekte[fam] or nil }
    if b then e.zustand, e.punkte, e.von = "aktiv", b.wert, b.o
    elseif type(a) == "table" then e.zustand, e.punkte = "aktiv", a.punkte
    elseif e.konflikt then e.zustand = "klasse"
    elseif e.da then e.zustand = "da"
    elseif z == "vorrat" or z == "bereit" then e.zustand = "du"
    elseif z == "material" then e.zustand = "material"
    else e.zustand = "fehlt" end
    table.insert(t, e)
  end
  return t
end

-- Boni, die gerade wirken, mit Wert: { { name, punkte, o } }
function LG:Boni()
  local t = {}
  local benefits = self:Benefits()
  for _, fam in ipairs(O.BONUS_REIHE) do
    local b = benefits[fam]
    if b then table.insert(t, { name = O.FAMILIE[fam].bonus, punkte = b.wert, o = b.o }) end
  end
  return t
end

-- Eine Zeile im Chat, nachdem man am Feuer Camp Benefits bekommen hat: was dieses Lager noch
-- brauchen kann und der Char sofort dabei hat oder bauen kann.
function LG:Tipp()
  if not (ns.db and ns.db.feuerHinweis) then return end
  local teile = {}
  for _, v in ipairs(self:Vorschlaege()) do
    if v.zustand == "vorrat" or v.zustand == "bereit" then
      local n = O.Anzeige(v.o)
      table.insert(teile, string.format(v.zustand == "vorrat" and L.CAMP_TIP_BAGS or L.CAMP_TIP_CRAFT, n))
    end
  end
  if #teile > 0 then ns.melde(string.format(L.MSG_CAMP_TIP, table.concat(teile, ", "))) end
end

-- Neu zeichnen: Fenster und Camp Kit, gebündelt
local geplant = false
function LG:Geaendert()
  if geplant then return end
  if not (C_Timer and C_Timer.After) then return ns.aktualisieren() end
  geplant = true
  C_Timer.After(0.1, function()
    geplant = false
    ns.aktualisieren()
  end)
end
