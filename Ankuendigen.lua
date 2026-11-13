-- Lager ankündigen und mit der Gruppe teilen (Vorschlag vom 13. Nov, Patrick: "mach das alles").
--   Ankündigen: Ein Klick schreibt das Lager in den Chat (Sagen oder allgemeiner Kanal 1), mit
--   Kartennadel des Spiels. Der Text ist einstellbar. Chat geht nur aus einem echten Klick oder
--   einem getippten Befehl (Regel 3, Forever verlangt das auch).
--   Teilen: Ein Klick schickt das Lager als Add-on-Nachricht an die eigene Gruppe. Mitglieder mit
--   Campfire Buddy sehen es dann auf ihrer Karte. Regel 4: nur auf Knopfdruck, nie im Bosskampf,
--   höchstens eine Nachricht alle 10 Sekunden. Kein eigener Chat-Kanal (die versteckten Kanäle
--   schaltet Forever ab, und Spieler klagen über zu viele davon).
--   Empfangen nur aus der eigenen Gruppe, streng geprüft (nur Zahlen, nur bekannte Objekte),
--   höchstens ein Lager je Absender alle 10 Sekunden.
local ADDON, ns = ...
local L = ns.L

local A = {}
ns.Ankuendigen = A

A.PRAEFIX = "CampfireBuddy"
local ABSTAND = 10
local MAX_TEXT = 255
local zuletztChat, zuletztTeilen = -100, -100
local vonWem = {}

local function imKampf() return InCombatLockdown and InCombatLockdown() end
local function bossKampf() return IsEncounterInProgress and IsEncounterInProgress() end

-- Bekannte Lager-Objekte nach Zauber-ID
local nachZauber
local function objekt(spell)
  if not nachZauber then
    nachZauber = {}
    for _, o in ipairs(ns.Objekte.LISTE) do nachZauber[o.spell] = o end
  end
  return spell and nachZauber[spell]
end
A.Objekt = objekt

-- Feuer, Objekte (Namen vom Spiel) und Restzeit des Lagers hier
local function lager()
  local LG = ns.Lager
  local feuer = LG.feuer and (ns.Objekte.Anzeige(LG.feuer.o)) or L.MAP_FIRE
  local namen = {}
  for _, e in pairs(LG.objekte or {}) do table.insert(namen, (ns.Objekte.Anzeige(e.o))) end
  table.sort(namen)
  local rest
  local e = LG.kartenNr and ns.db.karte and ns.db.karte[LG.kartenNr]
  if e and e.ende then rest = math.max(0, e.ende - LG.Zeit()) end
  return feuer, namen, rest, e and e.hoechstens
end

-- Kartennadel des Spiels für die Stelle des Chars. Der eigene Wegpunkt des Spielers wird danach
-- wiederhergestellt (oder wieder entfernt, wenn es keinen gab).
local function nadel()
  if not (C_Map and C_Map.SetUserWaypoint and C_Map.GetUserWaypointHyperlink and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
    return nil
  end
  local karte, x, y = ns.Lager.KartenPos("player")
  if not karte then return nil end
  local alt = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
  local okP, punkt = pcall(UiMapPoint.CreateFromCoordinates, karte, x, y)
  if not okP or not punkt or not pcall(C_Map.SetUserWaypoint, punkt) then return nil end
  local ok, link = pcall(C_Map.GetUserWaypointHyperlink)
  if alt then pcall(C_Map.SetUserWaypoint, alt) elseif C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
  if ok and type(link) == "string" and link ~= "" then return link end
end

-- Text der Ankündigung aus der Vorlage (eigener Text oder L.ANNOUNCE_DEFAULT). Platzhalter:
-- %fire%, %objects%, %time%, %pin%. Ohne %pin% kommt die Nadel ans Ende. Höchstens 255 Zeichen,
-- gekürzt wird vor der Nadel, damit der Link ganz bleibt.
function A.Text()
  local feuer, namen, rest, hoechstens = lager()
  local vorlage = ns.db.ansageText
  if type(vorlage) ~= "string" or vorlage == "" then vorlage = L.ANNOUNCE_DEFAULT end
  local werte = {
    fire = feuer,
    objects = #namen > 0 and table.concat(namen, ", ") or L.ANNOUNCE_NO_OBJECTS,
    -- Anzünden nicht gesehen: nur "up to" (es brannte schon, als man kam)
    time = rest and (hoechstens and string.format(L.ANNOUNCE_TIME_MAX, math.max(1, math.ceil(rest / 60)))
      or string.format(L.MINUTES, math.max(1, math.floor(rest / 60 + 0.5)))) or L.ANNOUNCE_TIME_UNKNOWN,
  }
  local link = nadel() or ""
  local mitNadel = string.find(vorlage, "%pin%", 1, true) ~= nil
  local text = string.gsub(vorlage, "%%(%a+)%%", function(wort)
    if wort == "pin" then return "\001" end
    return werte[wort]
  end)
  -- Zeilenumbrüche und Steuerzeichen raus, sonst lehnt der Chat ab
  text = string.gsub(text, "[\r\n|]", " ")
  local platz = MAX_TEXT - #link - 1
  if not mitNadel then text = text .. " \001" end
  local vor, nach = string.match(text, "^(.-)\001(.*)$")
  vor, nach = vor or text, nach or ""
  if #vor + #nach > platz then
    vor = string.sub(vor, 1, math.max(0, platz - #nach))
  end
  return (string.gsub(vor .. link .. nach, "%s+$", ""))
end

-- Ein Klick: Lager in den Chat (Sagen oder Kanal 1). Muss direkt aus dem Klick kommen.
function A:Ankuendigen()
  if imKampf() then return ns.melde(L.ANNOUNCE_COMBAT) end
  if not ns.Buffs.amFeuer then return ns.melde(L.ANNOUNCE_NO_CAMP) end
  local jetzt = ns.jetzt()
  if jetzt - zuletztChat < ABSTAND then return ns.melde(L.ANNOUNCE_WAIT) end
  -- Forever hat den Chat in C_ChatInfo (wie Retail seit Midnight), ältere Clients global
  local senden = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  if not senden then return end
  local kanal, nummer = "SAY", nil
  if ns.db.ansageKanal == "GENERAL" and GetChannelName then
    local ok, id = pcall(GetChannelName, 1)
    if ok and type(id) == "number" and id > 0 then kanal, nummer = "CHANNEL", id end
  end
  zuletztChat = jetzt
  pcall(senden, A.Text(), kanal, nil, nummer)
end

-- Ein Klick: Lager als Add-on-Nachricht an die eigene Gruppe
function A:Teilen()
  if not (IsInGroup and IsInGroup()) then return ns.melde(L.SHARE_NO_GROUP) end
  if bossKampf() then return ns.melde(L.SHARE_BOSS) end
  if imKampf() then return ns.melde(L.ANNOUNCE_COMBAT) end
  if not ns.Buffs.amFeuer then return ns.melde(L.ANNOUNCE_NO_CAMP) end
  local jetzt = ns.jetzt()
  if jetzt - zuletztTeilen < ABSTAND then return ns.melde(L.ANNOUNCE_WAIT) end
  local karte, x, y = ns.Lager.KartenPos("player")
  if not karte then return ns.melde(L.SHARE_NO_POSITION) end
  local LG = ns.Lager
  local objekte = {}
  for _, e in pairs(LG.objekte or {}) do table.insert(objekte, tostring(e.o.spell)) end
  local _, _, rest = lager()
  local nachricht = string.format("L1;%d;%d;%d;%d;%s;%d", karte, math.floor(x * 10000 + 0.5), math.floor(y * 10000 + 0.5),
    LG.feuer and LG.feuer.o.spell or 0, table.concat(objekte, ","), math.floor(rest or 0))
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
  local kanal = (IsInRaid and IsInRaid()) and "RAID" or "PARTY"
  zuletztTeilen = jetzt
  local ok, ergebnis = pcall(C_ChatInfo.SendAddonMessage, A.PRAEFIX, nachricht, kanal)
  -- Retail meldet einen Zahlencode zurück: 0 heißt gesendet
  if ok and (ergebnis == nil or ergebnis == true or ergebnis == 0) then
    ns.melde(L.SHARE_SENT)
  else
    ns.melde(L.SHARE_FAILED)
  end
end

-- Nachricht aus der Gruppe: streng prüfen, dann als Lager auf die Karte
local function empfangen(praefix, text, kanal, absender)
  if praefix ~= A.PRAEFIX or (kanal ~= "PARTY" and kanal ~= "RAID") then return end
  if type(text) ~= "string" or #text > 200 or type(absender) ~= "string" then return end
  local kurz = string.match(absender, "^([^%-]+)") or absender
  if UnitName and kurz == UnitName("player") then return end
  local jetzt = ns.jetzt()
  if jetzt - (vonWem[absender] or -100) < ABSTAND then return end
  local karte, x, y, feuer, liste, rest = string.match(text, "^L1;(%d+);(%d+);(%d+);(%d+);([%d,]*);(%d+)$")
  if not karte then return end
  karte, x, y, feuer, rest = tonumber(karte), tonumber(x) / 10000, tonumber(y) / 10000, tonumber(feuer), tonumber(rest)
  if not (karte and x and y) or x > 1 or y > 1 or karte <= 0 then return end
  if feuer ~= 0 and not objekt(feuer) then feuer = 0 end
  local objekte = {}
  for id in string.gmatch(liste, "%d+") do
    local n = tonumber(id)
    if n and objekt(n) and #objekte < 10 then table.insert(objekte, n) end
  end
  vonWem[absender] = jetzt
  ns.Lager:GruppenLager(karte, x, y, feuer ~= 0 and feuer or nil, objekte, math.min(rest or 0, 20 * 60), kurz)
  ns.melde(string.format(L.SHARE_RECEIVED, kurz))
end

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, A.PRAEFIX) end
ns.ereignis("CHAT_MSG_ADDON", empfangen)
