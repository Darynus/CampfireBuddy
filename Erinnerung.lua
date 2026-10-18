-- Erinnerungen: kurz vor Ablauf (einmal pro Buff), beim Ablauf, beim Login und beim Gruppenbeitritt
-- ohne Lager- oder Essens-Buff, und wenn man an ein Lagerfeuer kommt. Nur Anzeige und Ton, nichts geschieht
-- von selbst.
local ADDON, ns = ...
local L = ns.L

local E = {}
ns.Erinnerung = E

local FEUER_ABSTAND = 120   -- Sekunden zwischen zwei Lagerfeuer-Hinweisen
local FEUER_REST = 600      -- Lagerfeuer-Hinweis, wenn Camp Benefits fehlen oder kürzer laufen

-- Jede Buff-Runde hat ihre eigene Ablaufzeit. Gemerkt wird je Zauber-ID die Ablaufzeit, zu der
-- schon gewarnt wurde, in den SavedVariables (übersteht /reload). Springt die Ablaufzeit nur
-- ein wenig (Ladebildschirm), ist es dieselbe Runde. Erst ein erneuerter Buff warnt neu.
local TOLERANZ = 10
local function schonGemeldet(liste, a)
  local alt = liste[a.id]
  return alt ~= nil and math.abs(alt - (a.ende or 0)) <= TOLERANZ
end

local function name(a)
  if a.name and a.name ~= "" then return a.name end
  if a.id == ns.CAMP_BENEFITS then return L.NAME_CAMP_BENEFITS end
  return string.format(L.SPELL_ID, a.id)
end

-- Eigener Alarm, wenn das Essen mit Erfahrungsbonus ausläuft (Patricks Wunsch, 18. Okt: "so was wie
-- aus Metal Gear Solid"): selbst erzeugt mit tools/musik/effekte.js, Schlag, "!" und Magenknurren.
-- Hängt am Schalter für den Erinnerungston.
E.HUNGER = "Interface\\AddOns\\CampfireBuddy\\Media\\Toene\\Hunger.ogg"

function E:Abgelaufen(a, istEssen)
  if schonGemeldet(ns.db.abgelaufen, a) then return end
  ns.db.abgelaufen[a.id] = a.ende or 0
  ns.melde(string.format(istEssen and L.MSG_FOOD_RAN_OUT or L.MSG_RAN_OUT, name(a)))
  if istEssen and ns.db.ton and ns.Buffs.MitXp(a) ~= false and PlaySoundFile then
    pcall(PlaySoundFile, E.HUNGER, "SFX")
  end
end

-- Jede Sekunde aufgerufen. Läuft auch im Kampf, aus der zuletzt gelesenen Ablaufzeit.
function E:Pruefen()
  if not ns.db then return end
  local warnen = (ns.db.warnenMinuten or 0) * 60
  local geaendert = false
  local pruefen = {}
  local essen = ns.Buffs.essen
  for _, a in pairs(ns.Buffs.aktiv) do pruefen[a] = essen ~= nil and a.id == essen.id end
  if essen and not ns.Buffs.aktiv[essen.id] then pruefen[essen] = true end
  for a, istEssen in pairs(pruefen) do
    local rest = ns.Buffs.Rest(a)
    if rest then
      if rest <= 0 then
        if not schonGemeldet(ns.db.abgelaufen, a) then
          self:Abgelaufen(a, istEssen)
          geaendert = true
        end
      -- Nur Buffs, die länger laufen als die Warnzeit (sonst käme die Warnung sofort beim Anlegen)
      elseif warnen > 0 and rest <= warnen and (a.dauer or 0) > warnen and not schonGemeldet(ns.db.gewarnt, a) then
        ns.db.gewarnt[a.id] = a.ende or 0
        ns.hinweis(string.format(L.WARN_EXPIRES, name(a), ns.dauerText(rest)))
      end
    end
  end
  if geaendert then
    ns.Buffs:Bald()
    ns.aktualisieren()
  end
end

-- Ankunft an einem Lagerfeuer
function E:AmFeuer()
  if not (ns.db and ns.db.feuerHinweis) then return end
  local lager = ns.Buffs:Lager()
  local rest = ns.Buffs.Rest(lager)
  if lager and (rest == nil or rest >= FEUER_REST) then return end
  local jetzt = ns.jetzt()
  if self.letzterFeuer and jetzt - self.letzterFeuer < FEUER_ABSTAND then return end
  self.letzterFeuer = jetzt
  ns.hinweis(L.MSG_CAMPFIRE, true)
end

-- Alles da (Camp Benefits und, wenn gewünscht, Essen)? Beim Wechsel von "fehlt etwas" zu
-- "alles da" einmal melden. Der erste Stand nach dem Login ist nur der Ausgangspunkt.
function E:Vollstaendig()
  if not ns.db then return end
  local komplett = #ns.Buffs:Fehlt() == 0
  if komplett and self.komplett == false and ns.db.allesDaMelden then
    ns.hinweis(ns.db.essenErinnern and L.MSG_ALL_SET or L.MSG_ALL_SET_CAMP, true)
    ns.ton("rekord")
  end
  self.komplett = komplett
end

-- Aufgestanden, bevor die Sitz-Minute um war: trauriger Ton, dann ein Murloc-Schrei, ein Spruch
-- im Chat und das traurige Ende der Show
function E:ZuFrueh()
  ns.ton("umfallen")
  if C_Timer and C_Timer.After then C_Timer.After(0.6, function() ns.mrgl() end) else ns.mrgl() end
  local zeilen = L.MSG_STOOD_UP
  ns.melde(zeilen[math.random(1, #zeilen)])
  if ns.Show then ns.Show:Abbrechen() end
end

-- Vorschau im Fenster und mit /campfire test
function E:Vorschau()
  local minuten = ns.db.warnenMinuten or 0
  if minuten == 0 then minuten = 5 end
  ns.hinweis(string.format(L.WARN_EXPIRES, L.NAME_CAMP_BENEFITS, ns.dauerText(minuten * 60)))
end

-- Takt: ein unsichtbarer Rahmen, einmal pro Sekunde
local takt = CreateFrame("Frame")
local warten = 0
takt:SetScript("OnUpdate", function(_, dt)
  warten = warten + dt
  if warten < 1 then return end
  warten = 0
  E:Pruefen()
end)

-- Login: ein paar Sekunden warten, bis die Buffs da sind, dann einmal im Chat
ns.ereignis("PLAYER_ENTERING_WORLD", function(erstesMal)
  if not erstesMal or not (C_Timer and C_Timer.After) then return end
  C_Timer.After(5, function()
    if not ns.db.erinnernLogin then return end
    if not ns.Buffs:Lesen() then return end
    local fehlt = ns.Buffs:Fehlt()
    if #fehlt > 0 then ns.melde(string.format(L.MSG_MISSING_LOGIN, table.concat(fehlt, ", "))) end
  end)
end)

-- Gruppe: nur beim Beitreten, nicht bei jeder Änderung
ns.beimStart(function() E.inGruppe = IsInGroup and IsInGroup() or false end)
ns.ereignis("GROUP_ROSTER_UPDATE", function()
  local jetzt = IsInGroup and IsInGroup() or false
  local neu = jetzt and not E.inGruppe
  E.inGruppe = jetzt
  if neu and ns.db.erinnernGruppe and ns.Buffs.gelesen then
    local fehlt = ns.Buffs:Fehlt()
    if #fehlt > 0 then ns.melde(string.format(L.MSG_MISSING_GROUP, table.concat(fehlt, ", "))) end
  end
end)
