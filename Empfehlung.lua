-- Empfehlung nach Klasse und Spec: Welche Lager-Boni nützen diesem Char, und lohnt sich das
-- Hinsetzen an diesem Feuer? Die Rolle kommt aus der Spezialisierung (moderne Schnittstelle), sonst
-- aus dem Talentbaum mit den meisten Punkten, sonst aus der Klasse. Erkannt wird über das
-- Klassen-Token und die Nummer des Baums, nie über Namen. Namen von Spec und Klasse werden nur
-- angezeigt. Rollen: nah (Nahkampf), fern (Jäger), zauber (Schaden mit Zaubern), heiler, tank.
local ADDON, ns = ...
local L = ns.L
local O = ns.Objekte

local EM = {}
ns.Empfehlung = EM

-- Ohne Talente: Rolle aus der Klasse (Hybride bleiben offen)
local KLASSE_TYP = { WARRIOR = "nah", ROGUE = "nah", HUNTER = "fern", MAGE = "zauber", WARLOCK = "zauber", PRIEST = "heiler" }
-- Talentbäume in der Reihenfolge des Spiels
local BAUM_TYP = {
  WARRIOR = { "nah", "nah", "tank" }, PALADIN = { "heiler", "tank", "nah" }, HUNTER = { "fern", "fern", "fern" },
  ROGUE = { "nah", "nah", "nah" }, PRIEST = { "heiler", "heiler", "zauber" }, SHAMAN = { "zauber", "nah", "heiler" },
  MAGE = { "zauber", "zauber", "zauber" }, WARLOCK = { "zauber", "zauber", "zauber" }, DRUID = { "zauber", "nah", "heiler" },
}
local ROLLE_TYP = { TANK = "tank", HEALER = "heiler" }
-- Klassen mit Mana, die auch im Nahkampf von Intelligenz und Manaregeneration etwas haben
local MANA_NAH = { PALADIN = true, SHAMAN = true }

-- Nutzen je Bonus und Rolle: 2 gut, 1 etwas, 0 kaum. alle: für jede Rolle gleich.
local NUTZEN = {
  stein = { nah = 2, tank = 2 },                                        -- Nahkampf-Angriffskraft
  schleifen = { nah = 2, tank = 2 },                                    -- Stärke
  stuhl = { nah = 2, fern = 2, zauber = 2, heiler = 1, tank = 1 },      -- kritische Treffer
  kerze = { zauber = 2, heiler = 2, fern = 1 },                         -- Intelligenz
  mana = { zauber = 2, heiler = 2, fern = 1 },                          -- Manaregeneration
  banner = { heiler = 2, zauber = 1 },                                  -- Willenskraft
  verband = { alle = 2 },                                               -- Ausdauer
  fisch = { alle = 2 },                                                 -- alle Werte
  laute = { tank = 2, nah = 1, fern = 1, zauber = 1, heiler = 1 },      -- Rüstung und Widerstände
}

local function ok(v) return v ~= nil and not (issecretvalue ~= nil and issecretvalue(v)) end

local function spec(klasse)
  local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
  local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
  if not (getSpec and getInfo) then return nil end
  local gut, nr = pcall(getSpec)
  if not (gut and type(nr) == "number" and nr > 0) then return nil end
  local gut2, id, name, _, _, rolle = pcall(getInfo, nr)
  if not (gut2 and id) then return nil end
  local typ = (ok(rolle) and ROLLE_TYP[rolle]) or (BAUM_TYP[klasse] and BAUM_TYP[klasse][nr])
  if typ then return typ, ok(name) and name or nil end
end

-- Talentbaum mit den meisten Punkten. GetTalentTabInfo liefert je nach Client
-- (id, name, beschreibung, symbol, punkte, ...) oder (name, symbol, punkte, ...).
local function baum(klasse)
  if not (GetNumTalentTabs and GetTalentTabInfo and BAUM_TYP[klasse]) then return nil end
  local gut, anzahl = pcall(GetNumTalentTabs)
  if not (gut and type(anzahl) == "number") then return nil end
  local bester, meiste, bestName = nil, 0, nil
  for i = 1, anzahl do
    local gut2, a, b, c, _, e = pcall(GetTalentTabInfo, i)
    if gut2 then
      local name, punkte
      if type(a) == "number" then name, punkte = b, e else name, punkte = a, c end
      if type(punkte) == "number" and punkte > meiste then bester, meiste, bestName = i, punkte, name end
    end
  end
  if bester then return BAUM_TYP[klasse][bester], type(bestName) == "string" and bestName or nil end
end

-- Rolle, angezeigter Name ("Holy Paladin" oder nur "Paladin") und Klassen-Token
function EM:Rolle()
  local gut, klassenName, klasse = pcall(UnitClass, "player")
  if not gut then klassenName, klasse = nil, nil end
  local typ, specName = spec(klasse)
  if not typ then typ, specName = baum(klasse) end
  if not typ then typ = KLASSE_TYP[klasse] end
  local anzeige = klassenName
  -- Forever nennt als Spec teils den Klassennamen ("Warlock Warlock", Patricks Screenshot 16. Okt)
  if specName and klassenName and specName ~= "" and specName ~= klassenName then
    anzeige = string.format(L.FIT_SPEC_CLASS, specName, klassenName)
  end
  return typ, anzeige, klasse
end

local function maxStufe()
  local gut, stufe = pcall(UnitLevel, "player")
  local max = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion())
    or (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
  return gut and type(stufe) == "number" and type(max) == "number" and stufe >= max
end

-- Nutzen eines Bonus (Familie) für diesen Char: 2 gut, 1 etwas, 0 kaum
function EM:Nutzen(fam, typ, klasse)
  if fam == "zelt" then return maxStufe() and 0 or 2 end
  local n = NUTZEN[fam]
  if not n then return 1 end
  if n.alle then return n.alle end
  if not typ then return 1 end
  local wert = n[typ] or 0
  if (fam == "kerze" or fam == "mana") and typ == "nah" and MANA_NAH[klasse] then wert = math.max(wert, 1) end
  return wert
end

-- Am Feuer: Wie viele Objekte hier bringen einen Bonus, der dem Char gut nützt, und wie viele
-- davon hat er noch nicht? Ohne Lager nil.
function EM:Lohnt()
  local LG = ns.Lager
  if not LG.aktiv then return nil end
  local typ, _, klasse = self:Rolle()
  local benefits = LG:Benefits()
  local neu, gut = 0, 0
  for fam, e in pairs(LG.objekte) do
    if O.FAMILIE[fam] and O.FAMILIE[fam].bonus and self:Nutzen(fam, typ, klasse) >= 2 and not O.Konflikt(e.o) then
      gut = gut + 1
      if not benefits[fam] then neu = neu + 1 end
    end
  end
  return neu, gut
end

-- Ein Satz für das Fenster und den Sitz-Knopf
function EM:Urteil()
  local neu, gut = self:Lohnt()
  if not neu then return nil end
  if gut == 0 then return L.FIT_NOTHING end
  if neu == 0 then return L.FIT_HAVE end
  if neu == 1 then return L.FIT_WORTH_ONE end
  return string.format(L.FIT_WORTH, neu)
end
