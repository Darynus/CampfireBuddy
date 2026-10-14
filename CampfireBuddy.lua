-- Campfire Buddy: zeigt die Lager-Buffs und den Essens-Buff von WoW Forever mit Restzeit,
-- erinnert vor dem Ablauf und meldet, wenn ein Lagerfeuer in der Nähe ist. Eigenständig, ohne PatricksPlan_Core.
-- Regeln:
--   1. Nur lesen und anzeigen. Keine Add-on-Nachrichten, nichts geschieht von selbst.
--      Der Knopf "Sit" setzt den Char nur auf Klick hin.
--   2. Buffs nur über Zauber-IDs erkennen, nie über Namen (jede Spielsprache).
--   3. Im Kampf keine Buffs lesen (geheime Werte), die Restzeit läuft aus dem letzten Stand weiter.
local ADDON, ns = ...
local L = ns.L

ns.FARBE = "|cffff8c38"
ns.TITEL = ns.FARBE .. L.TITLE_PART1 .. "|r " .. L.TITLE_PART2
ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "0.1.0"

-- Zauber-IDs aus der Beta (Probe, 14. Okt, Lagerfeuer in Elwynn)
ns.CAMP_BENEFITS = 1229741   -- "Camp Benefits", nach einer Minute Sitzen am Feuer, 1 Stunde
ns.CAMPFIRE_NEARBY = 1283391 -- "Campfire Nearby", solange man am Feuer steht, ohne Dauer
ns.STANDARD_BUFFS = { [ns.CAMP_BENEFITS] = true }
-- Countdown-Buff beim Sitzen am Feuer: ID noch unbekannt (Beta-Test), bis dahin über die Dauer
ns.COUNTDOWN_IDS = {}

local STANDARD = {
  warnenMinuten = 5,     -- 0 = aus
  ton = true,
  erinnernLogin = true,
  erinnernGruppe = true,
  feuerHinweis = true,
  allesDaMelden = true,  -- kurze Meldung, sobald Camp Benefits und Essen beide aktiv sind
  essenErinnern = true,  -- Essens-Buff (+5 % Erfahrung durch Kills) anzeigen, wenn er fehlt
  leisteZeigen = true,
  nurMitBuff = false,
  gesperrt = false,
  leiste = {},           -- Position der Leiste
  minimapZeigen = true,
  minimapWinkel = 150,
  eigeneBuffs = {},      -- [Zauber-ID] = Name, zusätzlich verfolgte Buffs
  essenIds = {},         -- [Zauber-ID] = { name, icon }, vom Spieler als Essens-Buff markiert
  essenIcons = {},       -- [Datei-ID des Symbols] = Name, ebenso
  kitZeigen = true,      -- Camp Kit am Lagerfeuer zeigen
  showAn = true,         -- Murloc-Show während der Sitz-Minute
  murlocTon = true,      -- Murloc-Schrei in Show und Spielen
  rekorde = {},          -- Rekord je Spiel
  fangbuch = {},         -- Fänge beim Lagerfeuer-Angeln
  -- show, spiel: Positionen von Show und Spiel
  gewarnt = {},          -- [Zauber-ID] = Ablaufzeit, zu der schon gewarnt wurde
  abgelaufen = {},       -- [Zauber-ID] = Ablaufzeit, deren Ende schon gemeldet wurde
  -- kit: Position des Camp Kits
  -- fenster: Position des Hauptfensters
}

local function ergaenzen(ziel, vorlage)
  for k, v in pairs(vorlage) do
    if type(v) == "table" then
      if type(ziel[k]) ~= "table" then ziel[k] = {} end
      ergaenzen(ziel[k], v)
    elseif ziel[k] == nil then
      ziel[k] = v
    end
  end
end

function ns.melde(text)
  DEFAULT_CHAT_FRAME:AddMessage(ns.FARBE .. L.ADDON_NAME .. ":|r " .. tostring(text))
end

-- Hinweis in der Bildschirmmitte plus Chatzeile, mit kurzem Ton, wenn eingeschaltet
function ns.hinweis(text, ohneTon)
  if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo then
    RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
  end
  if not ohneTon and ns.db and ns.db.ton and PlaySound and SOUNDKIT then
    local ton = SOUNDKIT.ALARM_CLOCK_WARNING_3 or SOUNDKIT.RAID_WARNING
    if ton then pcall(PlaySound, ton) end
  end
  ns.melde(text)
end

-- Murloc-Schrei "Mrglglgl" (SoundKit 416, MurlocAggro). Höchstens alle 3 Sekunden, damit es lustig
-- bleibt und nicht nervt. chance: Wahrscheinlichkeit 0 bis 1 (Standard 1).
local letzterSchrei = -100
function ns.mrgl(chance)
  if not (ns.db and ns.db.murlocTon and PlaySound) then return end
  if chance and math.random() > chance then return end
  local jetzt = GetTime and GetTime() or time()
  if jetzt - letzterSchrei < 3 then return end
  letzterSchrei = jetzt
  pcall(PlaySound, 416, "SFX")
end

-- Kleine Effekte für Show und Spiele. Nur Namen aus SOUNDKIT: Fehlt einer im Client, bleibt es
-- still. Derselbe Effekt höchstens alle 0,08 s, damit schnelle Klicks nicht scheppern.
local TOENE = {
  plopp = "IG_MAINMENU_OPTION_CHECKBOX_ON",   -- etwas taucht auf, kleiner Treffer
  treffer = "MAP_PING",                       -- guter Treffer, Fisch beißt
  muenze = "MONEY_FRAME_OPEN",                -- viele Punkte
  minus = "IG_PLAYER_INVITE_DECLINE",         -- Minuspunkte
  boom = "RAID_BOSS_EMOTE_WARNING",           -- Bombe, Feuer lodert
  start = "READY_CHECK",                      -- Rennen geht los
  karte = "IG_ABILITY_PAGE_TURN",             -- Memory-Karte umdrehen
  paar = "UI_VOID_STORAGE_UNLOCK",            -- Paar gefunden, Kombo
  umfallen = "IG_QUEST_FAILED",               -- Stapel fällt, Lager verliert ein Leben
  fertig = "UI_70_CHALLENGE_MODE_COMPLETE_NO_UPGRADE",
  rekord = "PVP_THROUGH_QUEUE",
}
local zuletzt = {}
function ns.ton(name)
  if not (ns.db and ns.db.murlocTon and PlaySound and SOUNDKIT) then return end
  local kit = TOENE[name] and SOUNDKIT[TOENE[name]]
  if not kit then return end
  local jetzt = GetTime and GetTime() or time()
  if jetzt - (zuletzt[name] or -100) < 0.08 then return end
  zuletzt[name] = jetzt
  pcall(PlaySound, kit, "SFX")
end

-- Restzeit als Text: "47 min", unter 10 Minuten "9:05", unter einer Minute "42 s"
function ns.dauerText(sekunden)
  sekunden = math.max(0, math.floor(sekunden or 0))
  if sekunden >= 600 then return string.format(L.MINUTES, math.floor(sekunden / 60 + 0.5)) end
  if sekunden >= 60 then return string.format(L.CLOCK, math.floor(sekunden / 60), sekunden % 60) end
  return string.format(L.SECONDS, sekunden)
end

function ns.jetzt() return GetTime and GetTime() or time() end

-- Ereignisse ------------------------------------------------------------------------

local ereignisse = {}
local frame = CreateFrame("Frame")

function ns.ereignis(name, funktion)
  if not ereignisse[name] then
    local ok = pcall(frame.RegisterEvent, frame, name)
    if not ok then return false end
    ereignisse[name] = {}
  end
  table.insert(ereignisse[name], funktion)
  return true
end

frame:SetScript("OnEvent", function(_, ereignis, ...)
  local liste = ereignisse[ereignis]
  if not liste then return end
  for _, f in ipairs(liste) do
    local ok, fehler = pcall(f, ...)
    if not ok then ns.melde(string.format(L.ERR_EVENT, ereignis, tostring(fehler))) end
  end
end)

local startListe = {}
function ns.beimStart(f) table.insert(startListe, f) end

-- Sichtbare Teile neu zeichnen. Fehler einmal im Chat zeigen, nicht bei jedem Neuzeichnen.
local zeichner, gemeldet = {}, {}
function ns.beimAktualisieren(f) table.insert(zeichner, f) end
function ns.aktualisieren()
  for _, f in ipairs(zeichner) do
    local ok, fehler = pcall(f)
    if not ok and not gemeldet[tostring(fehler)] then
      gemeldet[tostring(fehler)] = true
      ns.melde(string.format(L.ERR_EVENT, "redraw", tostring(fehler)))
    end
  end
end

ns.ereignis("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  CampfireBuddyDB = CampfireBuddyDB or {}
  ergaenzen(CampfireBuddyDB, STANDARD)
  ns.db = CampfireBuddyDB
  -- 0.1.0 kannte nur Whack-a-Murloc
  if (ns.db.spielBest or 0) > (ns.db.rekorde.whack or 0) then ns.db.rekorde.whack = ns.db.spielBest end
  ns.db.spielBest = nil
end)

ns.ereignis("PLAYER_LOGIN", function()
  for _, f in ipairs(startListe) do
    local ok, fehler = pcall(f)
    if not ok then ns.melde(string.format(L.ERR_EVENT, "start", tostring(fehler))) end
  end
end)

-- Befehle ---------------------------------------------------------------------------

ns.befehle = {}
ns.befehlsListe = {}
function ns.befehl(wort, hilfe, funktion)
  ns.befehle[wort] = { hilfe = hilfe, funktion = funktion }
  table.insert(ns.befehlsListe, wort)
end

SLASH_CAMPFIREBUDDY1 = "/campfire"
SLASH_CAMPFIREBUDDY2 = "/cfb"
SlashCmdList.CAMPFIREBUDDY = function(eingabe)
  if not ns.db then return end
  local wort, rest = string.match(eingabe or "", "^%s*(%S*)%s*(.-)%s*$")
  wort = string.lower(wort or "")
  if wort == "" then wort = "window" end
  local b = ns.befehle[wort]
  if b then b.funktion(rest) else ns.melde(L.ERR_UNKNOWN_CMD) end
end
