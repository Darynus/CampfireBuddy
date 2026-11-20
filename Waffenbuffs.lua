-- Waffenbuffs verfolgen (Patrick, 14. Nov: „Waffenbuffs wie Gifte vom Schurken oder Windfury
-- tracken“): Gifte, Wetzsteine, Öle, Windfury und andere Verzauberungen auf Zeit. Das Spiel zählt
-- sie nicht zu den Auren, deshalb fehlten sie in der Buff-Liste. Es nennt sie je Waffe in
-- C_Item.GetWeaponEnchantInfo, wie in seiner eigenen Buffleiste: Restzeit, Ladungen, Kennung
-- (enchantID), Art (enchantType) und Symbol. Forever erlaubt mehrere je Waffe, zum Beispiel Gift und
-- Wetzstein zugleich (Patricks Buffleiste, 14. Nov: vier Symbole für zwei Waffen).
-- Verfolgt wird je Char und Hand (Reiter Buffs, Knopf Track). Dann stehen die Buffs der Hand in der
-- Leiste mit Restzeit und Ladungen, Warnung und Meldung beim Ablauf gelten wie bei anderen Buffs,
-- und hat die Waffe keinen, sagt die Leiste "No weapon buff". Nur lesen und anzeigen, auftragen nur
-- per Klick (Lagerkiste).
-- Den Namen ("Instant Poison VI") nennt die Schnittstelle nicht. Er kommt aus dem Tooltip der Waffe,
-- aus der Zeile "<Name> (<Zahl> ...)", deren Zahl zur Restzeit passt. Also in der Sprache des Spiels
-- und nur zur Anzeige. Ohne Treffer heißt er "Main hand buff" oder "Off hand buff".
local ADDON, ns = ...
local L = ns.L

local W = { aktiv = { [16] = {}, [17] = {} }, namen = {}, versucht = {}, gelesen = false }
ns.Waffen = W

W.HAENDE = { 16, 17 }  -- Ausrüstungsplätze: Haupthand, Nebenhand
local KURZ = 60        -- kürzere Buffs (Windfury Totem, 10 s, kommt alle paar Sekunden neu) melden kein Ende
local ANGEL = 20       -- Unterklasse Angelrute: Köder zählen auch, eine Rute ohne Köder fehlt aber nichts

local function geheim(v) return issecretvalue ~= nil and issecretvalue(v) end
local function imKampf() return InCombatLockdown and InCombatLockdown() end
local function zahl(v) return type(v) == "number" and not geheim(v) end
-- Wert für die Fehlersuche, geheime Werte nicht anfassen
local function zeige(v) if geheim(v) then return "secret" end return tostring(v) end

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

-- Plätze der Schnittstelle wie in der Buffleiste des Spiels: Werte aus Enum.WeaponSlot (0 Haupthand,
-- 1 Nebenhand), Ausrüstungsplatz 16 + Wert. Die Namen im Enum braucht es dafür nicht.
local function plaetze()
  local p = {}
  local ok = pcall(function()
    for _, wert in pairs(Enum.WeaponSlot) do
      if wert == 0 or wert == 1 then p[16 + wert] = wert end
    end
  end)
  if not ok or not p[16] or not p[17] then p = { [16] = 0, [17] = 1 } end
  return p
end

-- Schlüssel einer Tabelle in fester Reihenfolge (Zahlen der Größe nach)
local function sortiert(t)
  local k = {}
  for x in pairs(t) do k[#k + 1] = x end
  table.sort(k, function(a, b)
    if type(a) == "number" and type(b) == "number" then return a < b end
    return tostring(a) < tostring(b)
  end)
  return k
end

-- Alle Waffenbuffs je Hand frisch vom Spiel: { [16] = { { typ, rest, ladungen, id, icon }, ... } }.
-- Zweiter Wert: false, wenn die Werte gerade geheim sind (Kampf). Dritter: was die Schnittstelle
-- geliefert hat, für /campfire debug und die gespeicherte Fehlersuche (W:Merken).
-- Liefert C_Item.GetWeaponEnchantInfo nichts Lesbares, fragt sie die alte Funktion GetWeaponEnchantInfo.
function W.Roh()
  local t, lesbar, notiz, gefunden = { [16] = {}, [17] = {} }, true, {}, false
  if C_Item and C_Item.GetWeaponEnchantInfo then
    for platz, slot in pairs(plaetze()) do
      local ok, liste = pcall(C_Item.GetWeaponEnchantInfo, slot)
      if not ok then
        notiz[#notiz + 1] = string.format("C_Item %d: error %s", slot, tostring(liste))
      elseif type(liste) ~= "table" then
        notiz[#notiz + 1] = string.format("C_Item %d: %s", slot, type(liste))
      else
        local n = 0
        for _, k in ipairs(sortiert(liste)) do
          local e = liste[k]
          n = n + 1
          if type(e) ~= "table" then
            notiz[#notiz + 1] = string.format("C_Item %d #%s: %s", slot, tostring(k), type(e))
          else
            notiz[#notiz + 1] = string.format("C_Item %d #%s: has %s, time %s, charges %s, id %s, icon %s, type %s",
              slot, tostring(k), zeige(e.hasEnchant), zeige(e.timeLeft), zeige(e.charges), zeige(e.enchantID),
              zeige(e.enchantIconID), zeige(e.enchantType))
            if geheim(e.hasEnchant) then
              lesbar = false
            elseif e.hasEnchant then
              local ms, ch, id, icon, typ = e.timeLeft, e.charges, e.enchantID, e.enchantIconID, e.enchantType
              table.insert(t[platz], {
                typ = zahl(typ) and typ or nil,
                rest = zahl(ms) and ms / 1000 or 0,
                ladungen = zahl(ch) and ch or 0,
                id = zahl(id) and id or 0,
                icon = (zahl(icon) and icon > 0) and icon or nil,
              })
              gefunden = true
            end
          end
        end
        if n == 0 then notiz[#notiz + 1] = string.format("C_Item %d: empty", slot) end
      end
    end
  else
    notiz[#notiz + 1] = "C_Item.GetWeaponEnchantInfo missing"
  end
  if not gefunden and GetWeaponEnchantInfo then
    local ok, hatH, zeitH, ladH, idH, hatN, zeitN, ladN, idN = pcall(GetWeaponEnchantInfo)
    if not ok then
      notiz[#notiz + 1] = "global: error " .. tostring(hatH)
    else
      notiz[#notiz + 1] = string.format("global: %s %s %s %s | %s %s %s %s", zeige(hatH), zeige(zeitH), zeige(ladH),
        zeige(idH), zeige(hatN), zeige(zeitN), zeige(ladN), zeige(idN))
      if not geheim(hatH) and not geheim(hatN) then
        local function eintrag(zeit, lad, id)
          return { rest = zahl(zeit) and zeit / 1000 or 0, ladungen = zahl(lad) and lad or 0, id = zahl(id) and id or 0 }
        end
        if hatH then table.insert(t[16], eintrag(zeitH, ladH, idH)) end
        if hatN then table.insert(t[17], eintrag(zeitN, ladN, idN)) end
        lesbar = true
      end
    end
  end
  return t, lesbar, table.concat(notiz, " | ")
end

-- Schlüssel je Waffenbuff einer Hand: die Art (enchantType), wenn jede Art nur einmal vorkommt, sonst
-- die Kennung. So bleibt das Gift das Gift, auch wenn der Stein vorher abläuft, und ein anderes Gift
-- ersetzt das alte, statt als abgelaufen zu gelten.
local function schluessel(liste)
  local arten, doppelt = {}, false
  for _, e in ipairs(liste) do
    if e.typ == nil or arten[e.typ] then doppelt = true end
    if e.typ ~= nil then arten[e.typ] = true end
  end
  local gesehen = {}
  for i, e in ipairs(liste) do
    local k = doppelt and ("e" .. e.id) or ("t" .. e.typ)
    if gesehen[k] then k = k .. "-" .. i end
    gesehen[k] = true
    e.schluessel = k
  end
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

-- Zeilen im Tooltip der Waffe ohne die erste (Name der Waffe)
local function tooltipZeilen(platz)
  local z = {}
  if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return z end
  local ok, daten = pcall(C_TooltipInfo.GetInventoryItem, "player", platz)
  if not ok or type(daten) ~= "table" or type(daten.lines) ~= "table" then return z end
  for i, l in ipairs(daten.lines) do
    local t = type(l) == "table" and l.leftText
    if i > 1 and type(t) == "string" and not geheim(t) then z[#z + 1] = t end
  end
  return z
end

-- Namen für die Waffenbuffs einer Hand (Felder spielName). Bekannte je Kennung gemerkt, sonst aus dem
-- Tooltip, höchstens alle 10 Sekunden je Hand, nie im Kampf. Passen zwei Zeilen zur selben Zeit (Gift
-- und Stein zusammen aufgetragen), bekommt ein Buff mit Ladungen die Zeile mit seiner Zahl, sonst
-- gilt die Reihenfolge. Nur eindeutige Namen werden je Kennung gemerkt.
function W:Namen(platz, liste)
  local offen = {}
  for _, x in ipairs(liste) do
    if not x.spielName and x.enchant ~= 0 and self.namen[x.enchant] then x.spielName = self.namen[x.enchant] end
    if not x.spielName then offen[#offen + 1] = x end
  end
  if #offen == 0 then return end
  -- Wartezeit je Satz unbekannter Buffs: Ein neuer Buff bekommt seinen Namen sofort
  local ids = {}
  for _, x in ipairs(offen) do ids[#ids + 1] = tostring(x.enchant) end
  local versuch = platz .. ":" .. table.concat(ids, ",")
  local jetzt = ns.jetzt()
  if imKampf() or jetzt - (self.versucht[versuch] or -100) < 10 then return end
  self.versucht[versuch] = jetzt
  local kandidaten = {}
  for _, t in ipairs(tooltipZeilen(platz)) do
    if not wirkung(t) then
      local name, n = string.match(t, "^(.-) %((%d+)[^%)]*%)")
      n = tonumber(n)
      if name and name ~= "" and n then kandidaten[#kandidaten + 1] = { name = name, n = n, text = t } end
    end
  end
  local benutzt = {}
  for _, x in ipairs(liste) do if x.spielName then benutzt[x.spielName] = true end end
  -- Buffs mit Ladungen zuerst, sie lassen sich an ihrer Zahl erkennen
  table.sort(offen, function(p, q) return (p.ladungen or 0) > (q.ladungen or 0) end)
  for _, x in ipairs(offen) do
    local passend = {}
    for _, k in ipairs(kandidaten) do
      if not benutzt[k.name] and passt(k.n, x.rest or 0) then passend[#passend + 1] = k end
    end
    local wahl, eindeutig = passend[1], #passend == 1
    if #passend > 1 and (x.ladungen or 0) > 1 then
      for _, k in ipairs(passend) do
        if string.find(string.sub(k.text, #k.name + 1), tostring(x.ladungen), 1, true) then
          wahl, eindeutig = k, true
          break
        end
      end
    end
    if wahl then
      benutzt[wahl.name] = true
      x.spielName = wahl.name
      if eindeutig and x.enchant ~= 0 then self.namen[x.enchant] = wahl.name end
    end
  end
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
  W.SicherLesen()
  ns.aktualisieren()
  return h[platz] == true
end

function W.Hand(platz) return platz == 17 and L.SUPPLY_OFF_HAND or L.SUPPLY_MAIN_HAND end

-- Lesen ----------------------------------------------------------------------------------

-- Rückgabe: false, wenn nicht gelesen werden konnte (geheime Werte im Kampf). Dann bleibt der letzte
-- Stand, und die Restzeit läuft aus der gemerkten Ablaufzeit weiter, wie bei den Auren.
function W:Lesen()
  if not ns.db then return false end
  local roh, lesbar, notiz = W.Roh()
  self.notiz = notiz
  self:Merken()
  if not lesbar then
    self.nachKampf = true
    return false
  end
  local jetzt = ns.jetzt()
  local geaendert = not self.gelesen
  for _, platz in ipairs(W.HAENDE) do
    local item = waffe(platz)
    local liste = roh[platz]
    schluessel(liste)
    local alt = {}
    for _, a in ipairs(self.aktiv[platz]) do alt[a.schluessel] = a end
    local neu = {}
    for _, e in ipairs(liste) do
      local a = alt[e.schluessel]
      alt[e.schluessel] = nil
      local x = a
      if not (a and a.enchant == e.id and a.item == item) then
        x = { platz = platz, schluessel = e.schluessel, id = "waffe" .. platz .. e.schluessel, enchant = e.id, item = item }
        geaendert = true
      end
      if x.ladungen ~= e.ladungen or x.weg then geaendert = true end
      x.ladungen, x.weg, x.rest = e.ladungen, nil, e.rest
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
      neu[#neu + 1] = x
    end
    self:Namen(platz, neu)
    for _, x in ipairs(neu) do x.name = x.spielName or (platz == 17 and L.WEAPON_BUFF_OFF or L.WEAPON_BUFF_MAIN) end
    for _, a in pairs(alt) do
      if jetzt < (self.ruheBis or 0) then
        -- Nach dem Ladebildschirm kurz Ruhe: Die Daten der Ausrüstung sind nicht immer sofort da
        neu[#neu + 1] = a
      elseif a.ende > jetzt + 3 and jetzt - (a.weg or jetzt) < 1.5 then
        -- Ein Buff mit Restzeit muss eine Weile fehlen, bevor er als weg gilt (sonst eine falsche
        -- Meldung). Die Leiste zeigt ihn solange schon nicht mehr.
        if not a.weg then a.weg, geaendert = jetzt, true end
        neu[#neu + 1] = a
      else
        geaendert = true
        -- Weg und dieselbe Waffe in der Hand: abgelaufen (Zeit um) oder aufgebraucht (es gab Ladungen).
        -- Ohne Ladungen und mit Restzeit: abgebrochen. Kurze Buffs (Windfury Totem) melden kein Ende.
        local rest = a.ende - jetzt
        if a.item == item and (a.dauer or 0) >= KURZ and (rest <= 3 or (a.ladungen or 0) > 0) and W.Verfolgt(platz) then
          ns.Erinnerung:Abgelaufen(a, false)
        end
      end
    end
    table.sort(neu, function(p, q) return p.schluessel < q.schluessel end)
    self.aktiv[platz] = neu
  end
  self.gelesen, self.nachKampf = true, false
  if geaendert then ns.aktualisieren() end
  return true
end

-- Lesen mit Fehlerfang: Ein Fehler steht einmal im Chat und im Fehlerprotokoll (fehlerLog), statt
-- jede Sekunde still aufzutreten (ohne BugSack sieht man Lua-Fehler sonst nicht).
function W.SicherLesen()
  local ok, fehler = pcall(W.Lesen, W)
  if not ok then
    W.fehler = tostring(fehler)
    if W.fehler ~= W.gemeldet then
      W.gemeldet = W.fehler
      ns.melde(string.format(L.ERR_EVENT, "weapon buffs", W.fehler))
    end
  end
end

-- Für die Fehlersuche: was die Schnittstelle zuletzt geliefert hat und die Zeilen im Tooltip der
-- Waffen. Steht in den gespeicherten Daten (waffenDiagnose, nach /reload lesbar) und kommt mit
-- /campfire debug. Höchstens alle 10 Sekunden, nur der letzte Stand.
function W:Merken()
  local jetzt = ns.jetzt()
  if self.notiz == self.gemerkt or jetzt - (self.gemerktZeit or -100) < 10 then return end
  self.gemerkt, self.gemerktZeit = self.notiz, jetzt
  local d = { zeit = date("%Y-%m-%d %H:%M:%S"), api = self.notiz, fehler = self.fehler }
  if not imKampf() then
    for _, platz in ipairs(W.HAENDE) do d["tooltip" .. platz] = tooltipZeilen(platz) end
  end
  ns.db.waffenDiagnose = d
end

-- Abfragen -------------------------------------------------------------------------------

local function laeuft(a)
  local rest = ns.Buffs.Rest(a)
  return not a.weg and (rest == nil or rest > 0)
end

-- Alle Waffenbuffs, die gerade laufen, beide Hände (Reiter Buffs)
function W:Alle()
  local l = {}
  for _, platz in ipairs(W.HAENDE) do
    for _, a in ipairs(self.aktiv[platz]) do
      if laeuft(a) then l[#l + 1] = a end
    end
  end
  return l
end

-- Verfolgte Waffenbuffs, die gerade laufen (für Leiste, Status und Erinnerung)
function W:Liste()
  local l = {}
  for _, a in ipairs(self:Alle()) do
    if W.Verfolgt(a.platz) then l[#l + 1] = a end
  end
  return l
end

-- Für Warnung und Ablauf (Erinnerung.lua): verfolgte Waffenbuffs, auch die, deren Zeit gerade um ist.
-- Ohne kurze Buffs: Windfury Totem (10 s) kommt ständig neu und würde sonst ständig "ran out" melden.
function W:ZuPruefen()
  local l = {}
  for _, platz in ipairs(W.HAENDE) do
    if W.Verfolgt(platz) then
      for _, a in ipairs(self.aktiv[platz]) do
        if not a.weg and (a.dauer or 0) >= KURZ then l[#l + 1] = a end
      end
    end
  end
  return l
end

-- Verfolgte Hände mit Waffe, aber ohne Buff: { 16, 17 }. Eine Angelrute ohne Köder fehlt nichts.
function W:Fehlt()
  local t = {}
  if not (ns.db and self.gelesen) then return t end
  for _, platz in ipairs(W.HAENDE) do
    if W.Verfolgt(platz) then
      local da = false
      for _, a in ipairs(self.aktiv[platz]) do
        if laeuft(a) then da = true end
      end
      if not da then
        local id, unter = waffe(platz)
        if id and unter ~= ANGEL then t[#t + 1] = platz end
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
  if not (C_Timer and C_Timer.After) then return W.SicherLesen() end
  geplant = true
  C_Timer.After(0.2, function()
    geplant = false
    W.SicherLesen()
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
  if ns.db then W.SicherLesen() end
end)
