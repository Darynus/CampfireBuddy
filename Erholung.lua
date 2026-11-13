-- Erholungsbonus am Feuer: wie viel Erholung (Rested XP) gerade dazukommt und wann sie voll ist
-- (Vorschlag vom 13. Nov). Gemessen, nicht geschätzt: Beim Ankommen am Feuer merkt sich Campfire
-- Buddy den Stand, danach rechnet es aus der Veränderung die Rate pro Stunde. So stimmt es auch,
-- wenn Forever am Lager anders auffüllt als im Gasthaus. Nur lesen und anzeigen.
local ADDON, ns = ...

local R = {}
ns.Erholung = R

R.MIN_MESSEN = 120   -- Sekunden, bevor eine Rate angezeigt wird
R.VOLL = 150         -- höchstens anderthalb Stufen Erholung, in Prozent einer Stufe

local function maxStufe()
  for _, f in ipairs({ GetMaxLevelForPlayerExpansion, GetMaxPlayerLevel }) do
    if f then
      local ok, m = pcall(f)
      if ok and type(m) == "number" and m > 0 then return m end
    end
  end
  return 60
end

-- Erholung jetzt in Prozent einer Stufe (0 bis 150), nil auf Höchststufe oder ohne Werte
function R:Stand()
  if not (UnitXPMax and GetXPExhaustion and UnitLevel) then return nil end
  local okL, stufe = pcall(UnitLevel, "player")
  if not okL or type(stufe) ~= "number" or stufe >= maxStufe() then return nil end
  if IsPlayerAtEffectiveMaxLevel then
    local ok, oben = pcall(IsPlayerAtEffectiveMaxLevel)
    if ok and oben then return nil end
  end
  local okM, max = pcall(UnitXPMax, "player")
  if not okM or type(max) ~= "number" or max <= 0 then return nil end
  local okE, wert = pcall(GetXPExhaustion)
  if not okE then return nil end
  return (type(wert) == "number" and wert or 0) / max * 100
end

-- Messung: läuft, solange der Char am Feuer ist. Neue Stufe oder weniger Erholung: neu beginnen.
function R:Pruefen()
  local prozent = ns.Buffs.amFeuer and self:Stand() or nil
  if not prozent then
    self.messung, self.prozent = nil, nil
    return
  end
  local stufe = UnitLevel and UnitLevel("player")
  local m = self.messung
  local vorher = self.prozent
  if not m or prozent < (self.prozent or prozent) or stufe ~= m.stufe then
    self.messung = { zeit = ns.jetzt(), prozent = prozent, stufe = stufe }
  end
  self.prozent = prozent
  -- Am Feuer voll geworden: einmal Bescheid sagen, auf dem Bildschirm, im Chat und mit Ton
  -- (Vorschlag vom 13. Nov). Wer schon voll ankommt, bekommt keine Meldung.
  if vorher and vorher < R.VOLL - 0.05 and prozent >= R.VOLL - 0.05 then
    ns.hinweis(ns.L.MSG_RESTED_FULL)
  end
end

-- Prozent einer Stufe pro Stunde (nil: noch zu kurz gemessen)
function R:Rate()
  local m = self.messung
  if not (m and self.prozent) then return nil end
  local dauer = ns.jetzt() - m.zeit
  if dauer < R.MIN_MESSEN then return nil end
  return (self.prozent - m.prozent) * 3600 / dauer
end

-- Sekunden, bis die Erholung voll ist (nil: steigt nicht oder noch keine Rate)
function R:BisVoll()
  local rate = self:Rate()
  if not rate or rate <= 0 or not self.prozent then return nil end
  return math.max(0, (R.VOLL - self.prozent) / rate * 3600)
end

ns.ereignis("PLAYER_LEVEL_UP", function() R.messung = nil end)
