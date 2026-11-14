-- Waffenbuffs verfolgen (Patrick, 14. Nov: „Waffenbuffs wie Gifte vom Schurken oder Windfury
-- tracken“): Gifte, Wetzsteine, Öle, Windfury und andere Verzauberungen auf Zeit. Das Spiel zählt
-- sie nicht zu den Auren, deshalb fehlten sie in der Buff-Liste. Es nennt sie je Waffe in
-- C_Item.GetWeaponEnchantInfo, wie in seiner eigenen Buffleiste: Restzeit, Ladungen, Kennung
-- (enchantID) und Symbol.
-- Verfolgt wird je Char und Hand (Reiter Buffs, Knopf Track). Dann steht der Buff in der Leiste mit
-- Restzeit und Ladungen, Warnung und Meldung beim Ablauf gelten wie bei anderen Buffs, und fehlt er,
-- sagt die Leiste "No weapon buff". Nur lesen und anzeigen, auftragen nur per Klick (Lagerkiste).
-- Den Namen ("Instant Poison VI") nennt die Schnittstelle nicht. Er kommt aus dem Tooltip der Waffe,
-- aus der Zeile "<Name> (<Zahl> ...)", deren Zahl zur Restzeit passt. Also in der Sprache des Spiels
-- und nur zur Anzeige. Ohne Treffer heißt er "Main hand buff" oder "Off hand buff".
local ADDON, ns = ...
local L = ns.L

local W = { aktiv = {}, namen = {}, versucht = {}, gelesen = false }
ns.Waffen = W

W.HAENDE = { 16, 17 }  -- Ausrüstungsplätze: Haupthand, Nebenhand
local KURZ = 60        -- kürzere Buffs (Windfury Totem, 10 s, kommt alle paar Sekunden neu) melden kein Ende
local ANGEL = 20       -- Unterklasse Angelrute: Köder zählen auch, eine Rute ohne Köder fehlt aber nichts

local function geheim(v) return issecretvalue ~= nil and issecretvalue(v) end
local function imKampf() return InCombatLockdown and InCombatLockdown() end

-- Gegenstand in der Hand, wenn es eine Waffe ist (Klasse 2): Gegenstands-ID und Unterklasse
local function waffe(platz)
  if not GetInventoryItemID then return nil end
  local ok, id = pcall(GetInventoryItemID, "player", platz)
  if not ok or type(id) ~= "number" then return nil end
  local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if not f then return id end
  local ok2, gefunden, _, _, _, _, klasse, unter = pcall(f, id)
  if not ok2 or not gefunden or klasse ~= 2 then return nil end
  return id, unter
end

local function waffenSymbol(platz)
  if not GetInventoryItemTexture then return nil end
  local ok, icon = pcall(GetInventoryItemTexture, "player", platz)
  if ok and icon and not geheim(icon) then return icon end
end
W.Symbol = waffenSymbol

-- Verzauberung je Hand frisch vom Spiel: { [16] = { rest, ladungen, id, icon } }. Zweiter Wert:
-- false, wenn das Spiel gerade nichts Lesbares liefert (geheime Werte im Kampf).
function W.Roh()
  local t = {}
  if C_Item and C_Item.GetWeaponEnchantInfo then
    local ws = Enum and Enum.WeaponSlot
    local lesbar = true
    for platz, slot in pairs({ [16] = ws and ws.MainHand or 0, [17] = ws and ws.OffHand or 1 }) do
      local ok, liste = pcall(C_Item.GetWeaponEnchantInfo, slot)
      if ok and type(liste) == "table" then
        for _, e in pairs(liste) do
          if type(e) == "table" then
            if geheim(e.hasEnchant) then
              lesbar = false
            elseif e.hasEnchant then
              local ms, n, id, icon = e.timeLeft, e.charges, e.enchantID, e.enchantIconID
              t[platz] = {
                rest = (type(ms) == "number" and not geheim(ms)) and ms / 1000 or 0,
                ladungen = (type(n) == "number" and not geheim(n)) and n or 0,
                id = (type(id) == "number" and not geheim(id)) and id or 0,
                icon = (type(icon) == "number" and not geheim(icon) and icon > 0) and icon or nil,
              }
              break
            end
          end
        end
      end
    end
    return t, lesbar
  end
  if not GetWeaponEnchantInfo then return t, false end
  local ok, hatH, zeitH, ladH, idH, hatN, zeitN, ladN, idN = pcall(GetWeaponEnchantInfo)
  if not ok or geheim(hatH) or geheim(hatN) then return t, false end
  if hatH then t[16] = { rest = (zeitH or 0) / 1000, ladungen = ladH or 0, id = idH or 0 } end
  if hatN then t[17] = { rest = (zeitN or 0) / 1000, ladungen = ladN or 0, id = idN or 0 } end
  return t, true
end

-- Name aus dem Tooltip ---------------------------------------------------------------

-- Zeilen mit "Use:", "Equip:" oder "Chance on hit:" (Texte des Spiels, also in jeder Sprache)
-- sind Wirkungen der Waffe, auch wenn eine Zahl in Klammern dahinter steht
local function wirkung(t)
  for _, g in ipairs({ ITEM_SPELL_TRIGGER_ONUSE, ITEM_SPELL_TRIGGER_ONEQUIP, ITEM_SPELL_TRIGGER_ONPROC }) do
    if type(g) == "string" and g ~= "" and string.sub(t, 1, #g) == g then return true end
  end
  return false
end

-- Passt die Zahl in Klammern zur Restzeit? Minuten, Stunden oder Sekunden, wie das Spiel rundet
local function passt(n, rest)
  if math.abs(n - rest / 60) <= 1.5 then return true end
  if rest >= 3000 and math.abs(n - rest / 3600) <= 1 then return true end
  return rest < 120 and math.abs(n - rest) <= 3
end

local function nameAusTooltip(platz, rest)
  if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return nil end
  local ok, daten = pcall(C_TooltipInfo.GetInventoryItem, "player", platz)
  if not ok or type(daten) ~= "table" or type(daten.lines) ~= "table" then return nil end
  for i, z in ipairs(daten.lines) do
    local t = type(z) == "table" and z.leftText
    -- Zeile 1 ist der Name der Waffe
    if i > 1 and type(t) == "string" and not geheim(t) and not wirkung(t) then
      local name, n = string.match(t, "^(.-) %((%d+)[^%)]*%)")
      n = tonumber(n)
      if name and name ~= "" and n and passt(n, rest) then return name end
    end
  end
end

-- Name einer Verzauberung, je Kennung gemerkt. Höchstens alle 10 Sekunden ein neuer Versuch,
-- nie im Kampf.
function W:Name(platz, e)
  if e.id ~= 0 and self.namen[e.id] then return self.namen[e.id] end
  local schluessel = e.id ~= 0 and e.id or ("hand" .. platz)
  local jetzt = ns.jetzt()
  if imKampf() or jetzt - (self.versucht[schluessel] or -100) < 10 then return nil end
  self.versucht[schluessel] = jetzt
  local name = nameAusTooltip(platz, e.rest)
  if name and e.id ~= 0 then self.namen[e.id] = name end
  return name
end

-- Verfolgen je Char und Hand -------------------------------------------------------------

function W.Verfolgt(platz)
  local h = ns.db and ns.db.waffenVerfolgt[ns.charSchluessel()]
  return h ~= nil and h[platz] == true
end

-- Rückgabe: true, wenn die Hand jetzt verfolgt wird
function W:Umschalten(platz)
  local k = ns.charSchluessel()
  local h = ns.db.waffenVerfolgt[k] or {}
  h[platz] = (not h[platz]) or nil
  ns.db.waffenVerfolgt[k] = next(h) and h or nil
  self:Lesen()
  ns.aktualisieren()
  return h[platz] == true
end

function W.Hand(platz) return platz == 17 and L.SUPPLY_OFF_HAND or L.SUPPLY_MAIN_HAND end

-- Lesen ----------------------------------------------------------------------------------

-- Rückgabe: false, wenn nicht gelesen werden konnte (geheime Werte im Kampf). Dann bleibt der letzte
-- Stand, und die Restzeit läuft aus der gemerkten Ablaufzeit weiter, wie bei den Auren.
function W:Lesen()
  if not ns.db then return false end
  local roh, lesbar = W.Roh()
  if not lesbar then
    self.nachKampf = true
    return false
  end
  local jetzt = ns.jetzt()
  local neu, geaendert = {}, not self.gelesen
  for _, platz in ipairs(W.HAENDE) do
    local e, a = roh[platz], self.aktiv[platz]
    local item = waffe(platz)
    if e then
      local x = a
      if not (a and a.enchant == e.id and a.item == item) then
        x = { platz = platz, id = "waffe" .. platz, enchant = e.id, item = item }
        geaendert = true
      end
      if x.ladungen ~= e.ladungen then geaendert = true end
      x.ladungen, x.weg = e.ladungen, nil
      x.icon = e.icon or waffenSymbol(platz)
      x.ende = e.rest > 0 and jetzt + e.rest or 0
      -- Volle Dauer: die längste Restzeit, die je zu dieser Verzauberung zu sehen war. Gemerkt, damit
      -- der Balken auch nach /reload stimmt.
      local d = e.id ~= 0 and ns.db.waffenDauer[e.id] or nil
      if e.id ~= 0 and e.rest > (d or 0) + 1 then
        d = math.floor(e.rest + 0.5)
        ns.db.waffenDauer[e.id] = d
      end
      x.dauer = math.max(d or 0, x.dauer or 0, e.rest)
      x.spielName = x.spielName or self:Name(platz, e)
      x.name = x.spielName or (platz == 17 and L.WEAPON_BUFF_OFF or L.WEAPON_BUFF_MAIN)
      neu[platz] = x
    elseif a and jetzt < (self.ruheBis or 0) then
      -- Nach dem Ladebildschirm kurz Ruhe: Die Daten der Ausrüstung sind nicht immer sofort da
      neu[platz] = a
    elseif a and a.ende > jetzt + 3 and jetzt - (a.weg or jetzt) < 1.5 then
      -- Ein Buff mit Restzeit muss eine Weile fehlen, bevor er als weg gilt (sonst eine falsche Meldung).
      -- Die Leiste zeigt ihn solange schon nicht mehr.
      if not a.weg then a.weg, geaendert = jetzt, true end
      neu[platz] = a
    elseif a then
      geaendert = true
      -- Weg und dieselbe Waffe in der Hand: abgelaufen (Zeit um) oder aufgebraucht (es gab Ladungen).
      -- Ohne Ladungen und mit Restzeit: abgebrochen. Kurze Buffs (Windfury Totem) melden kein Ende.
      local rest = a.ende - jetzt
      if a.item == item and (a.dauer or 0) >= KURZ and (rest <= 3 or (a.ladungen or 0) > 0) and W.Verfolgt(platz) then
        ns.Erinnerung:Abgelaufen(a, false)
      end
    end
  end
  self.aktiv, self.gelesen, self.nachKampf = neu, true, false
  if geaendert then ns.aktualisieren() end
  return true
end

-- Verfolgte Waffenbuffs, die gerade laufen (für Leiste, Status und Erinnerung)
function W:Liste()
  local l = {}
  for _, platz in ipairs(W.HAENDE) do
    local a = self.aktiv[platz]
    local rest = a and ns.Buffs.Rest(a)
    if a and not a.weg and W.Verfolgt(platz) and (rest == nil or rest > 0) then table.insert(l, a) end
  end
  return l
end

-- Für Warnung und Ablauf (Erinnerung.lua): verfolgte Waffenbuffs, auch die, deren Zeit gerade um ist.
-- Ohne kurze Buffs: Windfury Totem (10 s) kommt ständig neu und würde sonst ständig "ran out" melden.
function W:ZuPruefen()
  local l = {}
  for _, platz in ipairs(W.HAENDE) do
    local a = self.aktiv[platz]
    if a and not a.weg and (a.dauer or 0) >= KURZ and W.Verfolgt(platz) then table.insert(l, a) end
  end
  return l
end

-- Verfolgte Hände mit Waffe, aber ohne Buff: { 16, 17 }. Eine Angelrute ohne Köder fehlt nichts.
function W:Fehlt()
  local t = {}
  if not (ns.db and self.gelesen) then return t end
  for _, platz in ipairs(W.HAENDE) do
    if W.Verfolgt(platz) then
      local a = self.aktiv[platz]
      local rest = a and ns.Buffs.Rest(a)
      if not a or a.weg or (rest ~= nil and rest <= 0) then
        local id, unter = waffe(platz)
        if id and unter ~= ANGEL then table.insert(t, platz) end
      end
    end
  end
  return t
end

-- Fehlende Waffenbuffs als Text für die Hinweise beim Login und Gruppenbeitritt
function W:FehltText()
  local t = {}
  for _, platz in ipairs(self:Fehlt()) do
    table.insert(t, platz == 17 and L.MISSING_WEAPON_OFF or L.MISSING_WEAPON_MAIN)
  end
  return t
end

-- Ereignisse: Verzauberung oder Waffe geändert. Dazu jede Sekunde, denn Ladungen sinken im Kampf.
local geplant = false
function W:Bald()
  if geplant then return end
  if not (C_Timer and C_Timer.After) then return self:Lesen() end
  geplant = true
  C_Timer.After(0.2, function()
    geplant = false
    W:Lesen()
  end)
end

ns.ereignis("WEAPON_ENCHANT_CHANGED", function() W:Bald() end)
ns.ereignis("WEAPON_SLOT_CHANGED", function() W:Bald() end)
ns.ereignis("PLAYER_EQUIPMENT_CHANGED", function(platz) if platz == 16 or platz == 17 then W:Bald() end end)
ns.ereignis("UNIT_INVENTORY_CHANGED", function(einheit) if einheit == "player" then W:Bald() end end)
ns.ereignis("PLAYER_ENTERING_WORLD", function()
  W.ruheBis = ns.jetzt() + 5
  W:Bald()
end)
ns.ereignis("PLAYER_REGEN_ENABLED", function() if W.nachKampf then W:Bald() end end)

local takt = CreateFrame("Frame")
local warten = 0
takt:SetScript("OnUpdate", function(_, dt)
  warten = warten + dt
  if warten < 1 then return end
  warten = 0
  if ns.db then W:Lesen() end
end)
