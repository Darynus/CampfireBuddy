-- Lager-Objekte: Jeder Beruf hat Objekte, die man am Lagerfeuer aufstellt, in drei Stufen (ab 20,
-- 140 und 300). Das Rezept (Zauber) baut daraus einen Gegenstand für die Taschen, Benutzen stellt
-- ihn auf (Patricks Beobachtung in der Beta, 14. Okt). Auch das Lagerfeuer entsteht als Bausatz.
-- Höhere Stufen geben den Bonus der ersten Stufe und ersetzen sie am Feuer.
-- Zauber- und Gegenstands-IDs aus öffentlichen Forever-Datenbanken (Wowhead, abgeglichen mit dem
-- MIT-lizenzierten Add-on Fireside, Stand 16. Okt 2026), Texte eigene.
-- Erkannt wird alles über IDs: Beruf über die Fertigkeitslinie, Material über die Gegenstands-ID.
local ADDON, ns = ...
local L = ns.L

local O = {}
ns.Objekte = O

-- Fertigkeitslinien der Berufe
local ALCHEMIE, SCHMIED, KOCHEN, VERZAUBERN, INGENIEUR, ERSTE_HILFE = 171, 164, 185, 333, 202, 129
local ANGELN, KRAEUTER, LEDER, BERGBAU, KUERSCHNER, SCHNEIDER = 356, 182, 165, 186, 393, 197

-- Familien: Objekte desselben Bonus. konflikt: Klassen-Buffs (Zauber-IDs, Rang 1 und Gruppen-
-- fassung), mit denen der Bonus nicht zusammen wirkt. Laut Forever-Tooltips und Guides.
-- aura: eigener Buff des Bonus, neben Camp Benefits (IDs aus den Add-ons Tweaks Forever und
-- Campfire Tooltips, im Spiel noch zu bestätigen). Beim Zelt ist es die Sperre "Boosted Rest"
-- (eine Stunde nach dem Erholungsbonus bringt ein weiteres Zelt nichts).
O.FAMILIE = {
  feuer = {},
  mana = { konflikt = { 19742, 25894 }, aura = 1230587 },      -- Blessing of Wisdom, Greater
  schleifen = { konflikt = { 8076, 8075 }, aura = 1230172 },   -- Strength of Earth (Buff, Totem)
  laute = { konflikt = { 1126, 21849 }, aura = 1230653 },      -- Mark of the Wild, Gift of the Wild
  bot = {},
  verband = { konflikt = { 1243, 21562 }, aura = 1230124 },    -- Power Word: Fortitude, Prayer of Fortitude
  fisch = { konflikt = { 20217, 25898 }, aura = 1230098 },     -- Blessing of Kings, Greater
  kerze = { konflikt = { 1459, 23028 }, aura = 1229513 },      -- Arcane Intellect, Arcane Brilliance
  zelt = { aura = 1229451 },                                   -- Boosted Rest (im Spiel bestätigt, 18. Okt)
  stein = { konflikt = { 19740, 25782 }, aura = 1230164 },     -- Blessing of Might, Greater
  stuhl = { konflikt = { 24907 }, aura = 1229519 },            -- Moonkin Aura
  banner = { konflikt = { 14752, 27681 }, aura = 1229718 },    -- Divine Spirit, Prayer of Spirit
  festmahl = {},
  ofen = {},
}

-- familie: siehe oben, stufe: Berufswert, item: Gegenstand, der beim Bauen entsteht
-- Feuer: platz = Zauber beim Aufstellen des Bausatzes (aus fremden Add-ons, im Spiel zu bestätigen),
-- plaetze = wie viele Objekte daneben passen. Bei den Objekten kommt der Zauber zum Aufstellen vom
-- Spiel selbst (C_Item.GetItemSpell, Lager.lua).
-- art: "feuer" (Lagerfeuer, braucht kein Feuer in der Nähe) oder "objekt" (am Lagerfeuer)
-- mats: { { Gegenstands-ID, Menge }, ... }, werkzeug: Gegenstand, der nicht verbraucht wird
-- fraktion: nur für diese Fraktion (Token aus UnitFactionGroup)
-- mehrdeutig: heißt wie ein normales Ding im Dorf (Amboss, Gerbgestell, Spinnrad, Webstuhl), wird
-- deshalb nie über die Maus erkannt (Lager.lua)
O.LISTE = {
  { spell = 1229737, item = 279981, platz = 1307227, plaetze = 3, familie = "feuer", beruf = KOCHEN, stufe = 1, art = "feuer",
    mats = { { 4470, 1 } }, werkzeug = 4471,
    name = L.OBJ_CAMPFIRE, info = L.OBJ_CAMPFIRE_INFO, lernen = L.LEARN_TRAINER },
  { spell = 1283400, item = 279961, platz = 1307252, plaetze = 5, familie = "feuer", beruf = KOCHEN, stufe = 90, art = "feuer",
    mats = { { 11291, 1 } }, werkzeug = 4471,
    name = L.OBJ_CAMPFIRE_2, info = L.OBJ_CAMPFIRE_2_INFO, lernen = L.LEARN_BLUEPRINT },
  { spell = 1291341, item = 279974, platz = 1307237, plaetze = 10, familie = "feuer", beruf = KOCHEN, stufe = 200, art = "feuer",
    mats = { { 272941, 1 } }, werkzeug = 4471,
    name = L.OBJ_CAMPFIRE_3, info = L.OBJ_CAMPFIRE_3_INFO, lernen = L.LEARN_BLUEPRINT },

  { spell = 1230564, item = 279956, familie = "mana", beruf = ALCHEMIE, stufe = 20,
    mats = { { 2447, 1 }, { 3371, 1 } }, name = L.OBJ_MANA_WELL, info = L.OBJ_MANA_WELL_INFO },
  { spell = 1263005, item = 279970, familie = "mana", beruf = ALCHEMIE, stufe = 140,
    mats = { { 3372, 1 }, { 3356, 1 }, { 2452, 1 } }, name = L.OBJ_FERMENTER, info = L.OBJ_FERMENTER_INFO },

  { spell = 1230171, item = 279944, familie = "schleifen", beruf = SCHMIED, stufe = 20,
    mats = { { 2835, 1 }, { 2840, 1 } }, name = L.OBJ_SHARPENING_WHEEL, info = L.OBJ_SHARPENING_WHEEL_INFO },
  { spell = 1263041, item = 279988, mehrdeutig = true, familie = "schleifen", beruf = SCHMIED, stufe = 140,
    mats = { { 2841, 5 }, { 3478, 2 }, { 2319, 2 } }, name = L.OBJ_ANVIL, info = L.OBJ_ANVIL_INFO },
  { spell = 1263073, item = 279955, familie = "schleifen", beruf = SCHMIED, stufe = 300,
    mats = { { 273127, 1 }, { 12359, 5 }, { 8170, 2 } }, name = L.OBJ_MASTER_FORGE, info = L.OBJ_MASTER_FORGE_INFO },

  { spell = 1230643, item = 279976, familie = "laute", beruf = VERZAUBERN, stufe = 20,
    mats = { { 4470, 1 }, { 10940, 1 } }, name = L.OBJ_LUTE, info = L.OBJ_LUTE_INFO },
  { spell = 1263056, item = 279985, familie = "laute", beruf = VERZAUBERN, stufe = 140,
    mats = { { 11137, 2 }, { 11174, 1 } }, name = L.OBJ_SALVAGER, info = L.OBJ_SALVAGER_INFO },
  { spell = 1263082, item = 279987, familie = "laute", beruf = VERZAUBERN, stufe = 300,
    mats = { { 273128, 1 }, { 14344, 2 }, { 16203, 4 } }, name = L.OBJ_ARCANE_FORGE, info = L.OBJ_ARCANE_FORGE_INFO },

  { spell = 1230656, item = 279950, familie = "bot", beruf = INGENIEUR, stufe = 20,
    mats = { { 4359, 1 }, { 4361, 1 } }, name = L.OBJ_REAGENT_BOT, info = L.OBJ_REAGENT_BOT_INFO },
  { spell = 1263034, item = 279949, familie = "bot", beruf = INGENIEUR, stufe = 140,
    mats = { { 4375, 2 }, { 4371, 1 }, { 4234, 1 } }, name = L.OBJ_REPAIR_BOT, info = L.OBJ_REPAIR_BOT_INFO },
  { spell = 1263083, item = 279989, familie = "bot", beruf = INGENIEUR, stufe = 300,
    mats = { { 273129, 1 }, { 15994, 2 } }, name = L.OBJ_WORKBENCH, info = L.OBJ_WORKBENCH_INFO },

  { spell = 1230117, item = 279968, familie = "verband", beruf = ERSTE_HILFE, stufe = 20,
    mats = { { 1251, 3 }, { 159, 1 } }, name = L.OBJ_FIRST_AID, info = L.OBJ_FIRST_AID_INFO },
  { spell = 1262996, item = 279940, familie = "verband", beruf = ERSTE_HILFE, stufe = 140,
    mats = { { 6452, 1 }, { 8544, 2 }, { 4470, 2 } }, name = L.OBJ_TOXIN_STUDY, info = L.OBJ_TOXIN_STUDY_INFO },
  { spell = 1263001, item = 279951, familie = "verband", beruf = ERSTE_HILFE, stufe = 300,
    mats = { { 4470, 2 }, { 6453, 2 }, { 14530, 5 } }, name = L.OBJ_PLAGUE_LAB, info = L.OBJ_PLAGUE_LAB_INFO },

  { spell = 1229745, item = 279967, familie = "fisch", beruf = ANGELN, stufe = 20,
    mats = { { 6291, 1 }, { 3371, 1 } }, name = L.OBJ_FISH_BOWL, info = L.OBJ_FISH_BOWL_INFO },
  { spell = 1262990, item = 279965, familie = "fisch", beruf = ANGELN, stufe = 140,
    mats = { { 4470, 2 }, { 8925, 1 }, { 8365, 2 } }, name = L.OBJ_FISHING_RACK, info = L.OBJ_FISHING_RACK_INFO },
  { spell = 1262998, item = 279966, familie = "fisch", beruf = ANGELN, stufe = 300,
    mats = { { 4470, 5 }, { 14048, 2 }, { 273295, 1 } }, name = L.OBJ_FISHING_HUT, info = L.OBJ_FISHING_HUT_INFO },

  { spell = 1229705, item = 279962, familie = "kerze", beruf = KRAEUTER, stufe = 20,
    mats = { { 2447, 1 }, { 765, 1 } }, name = L.OBJ_CANDLE, info = L.OBJ_CANDLE_INFO },
  { spell = 1262980, item = 279964, familie = "kerze", beruf = KRAEUTER, stufe = 140,
    mats = { { 4470, 2 }, { 8836, 1 }, { 8831, 1 } }, name = L.OBJ_GREENHOUSE, info = L.OBJ_GREENHOUSE_INFO },
  { spell = 1263070, item = 279947, familie = "kerze", beruf = KRAEUTER, stufe = 300,
    mats = { { 13465, 4 }, { 8925, 1 }, { 14047, 2 } }, name = L.OBJ_HYBRIDIZER, info = L.OBJ_HYBRIDIZER_INFO },

  { spell = 1229432, item = 279978, familie = "zelt", beruf = LEDER, stufe = 20,
    mats = { { 2318, 5 } }, name = L.OBJ_TENT, info = L.OBJ_TENT_INFO },
  { spell = 1263031, item = 279941, mehrdeutig = true, familie = "zelt", beruf = LEDER, stufe = 140,
    mats = { { 2319, 5 }, { 2321, 3 }, { 4470, 2 } }, name = L.OBJ_TANNING_RACK, info = L.OBJ_TANNING_RACK_INFO },
  { spell = 1263079, item = 279945, familie = "zelt", beruf = LEDER, stufe = 300,
    mats = { { 273130, 1 }, { 8170, 5 }, { 14341, 1 } }, name = L.OBJ_SEWING_MACHINE, info = L.OBJ_SEWING_MACHINE_INFO },

  { spell = 1230161, item = 279960, familie = "stein", beruf = BERGBAU, stufe = 20,
    mats = { { 2835, 1 }, { 2840, 1 } }, name = L.OBJ_LODESTONE, info = L.OBJ_LODESTONE_INFO },
  { spell = 1262975, item = 279948, familie = "stein", beruf = BERGBAU, stufe = 140,
    mats = { { 2838, 2 }, { 2772, 1 }, { 2842, 1 } }, name = L.OBJ_ROCK_GARDEN, info = L.OBJ_ROCK_GARDEN_INFO },
  { spell = 1263071, item = 279952, familie = "stein", beruf = BERGBAU, stufe = 300,
    mats = { { 12359, 5 }, { 12365, 2 }, { 6037, 1 } }, name = L.OBJ_FOUNDRY, info = L.OBJ_FOUNDRY_INFO },

  { spell = 1229517, item = 279979, familie = "stuhl", beruf = KUERSCHNER, stufe = 20,
    mats = { { 2318, 3 }, { 4470, 2 } }, name = L.OBJ_CHAIR, info = L.OBJ_CHAIR_INFO },
  { spell = 1262985, item = 279969, familie = "stuhl", beruf = KUERSCHNER, stufe = 140,
    mats = { { 2319, 3 }, { 5784, 2 }, { 2321, 1 } }, name = L.OBJ_FIELD_GUIDE, info = L.OBJ_FIELD_GUIDE_INFO },
  { spell = 1262982, item = 279938, familie = "stuhl", beruf = KUERSCHNER, stufe = 300,
    mats = { { 4470, 2 }, { 4234, 4 }, { 3575, 1 } }, name = L.OBJ_TRAPPER, info = L.OBJ_TRAPPER_INFO },

  -- Das Banner gibt es je Fraktion als eigenes Rezept
  { spell = 1263425, item = 279973, familie = "banner", fraktion = "Alliance", beruf = SCHNEIDER, stufe = 20,
    mats = { { 2996, 1 }, { 2320, 1 } }, name = L.OBJ_BANNER, info = L.OBJ_BANNER_INFO },
  { spell = 1229504, item = 279972, familie = "banner", fraktion = "Horde", beruf = SCHNEIDER, stufe = 20,
    mats = { { 2996, 1 }, { 2320, 1 } }, name = L.OBJ_BANNER, info = L.OBJ_BANNER_INFO },
  { spell = 1263032, item = 279943, mehrdeutig = true, familie = "banner", beruf = SCHNEIDER, stufe = 140,
    mats = { { 4470, 2 }, { 4305, 5 }, { 2321, 3 } }, name = L.OBJ_SPINNING_WHEEL, info = L.OBJ_SPINNING_WHEEL_INFO },
  { spell = 1263080, item = 279959, mehrdeutig = true, familie = "banner", beruf = SCHNEIDER, stufe = 300,
    mats = { { 273131, 1 }, { 14048, 4 }, { 4470, 4 } }, name = L.OBJ_LOOM, info = L.OBJ_LOOM_INFO },

  { spell = 1262978, item = 279957, familie = "festmahl", beruf = KOCHEN, stufe = 140,
    mats = { { 12037, 2 }, { 12204, 1 }, { 3713, 1 } }, name = L.OBJ_FEAST, info = L.OBJ_FEAST_INFO },
  { spell = 1263067, item = 279982, familie = "ofen", beruf = KOCHEN, stufe = 300,
    mats = { { 10284, 10 }, { 159, 5 }, { 3713, 4 } }, name = L.OBJ_OVEN, info = L.OBJ_OVEN_INFO },
}

-- Was jede Familie bringt (kurz, für den Reiter Camp), und die Reihenfolge der Boni dort
local BONUS = {
  stein = L.BONUS_STEIN, schleifen = L.BONUS_SCHLEIFEN, stuhl = L.BONUS_STUHL, kerze = L.BONUS_KERZE,
  mana = L.BONUS_MANA, banner = L.BONUS_BANNER, verband = L.BONUS_VERBAND, fisch = L.BONUS_FISCH,
  laute = L.BONUS_LAUTE, zelt = L.BONUS_ZELT, bot = L.BONUS_BOT, festmahl = L.BONUS_FESTMAHL, ofen = L.BONUS_OFEN,
}
for fam, text in pairs(BONUS) do O.FAMILIE[fam].bonus = text end
O.BONUS_REIHE = { "stein", "schleifen", "stuhl", "kerze", "mana", "banner", "verband", "fisch", "laute", "zelt" }

-- Erste Stufe jeder Familie (für "ersetzt ..." im Tooltip)
O.BASIS = {}
for _, o in ipairs(O.LISTE) do
  if not O.BASIS[o.familie] then O.BASIS[o.familie] = o end
end

-- Gilt das Objekt für die Fraktion des Chars? (Faction Banner)
function O.Passt(o)
  if not o.fraktion then return true end
  local f = UnitFactionGroup and UnitFactionGroup("player")
  return f == nil or f == o.fraktion
end

O.BERUF_NAME = {
  [ALCHEMIE] = L.PROF_ALCHEMY, [SCHMIED] = L.PROF_BLACKSMITHING, [KOCHEN] = L.PROF_COOKING,
  [VERZAUBERN] = L.PROF_ENCHANTING, [INGENIEUR] = L.PROF_ENGINEERING, [ERSTE_HILFE] = L.PROF_FIRST_AID,
  [ANGELN] = L.PROF_FISHING, [KRAEUTER] = L.PROF_HERBALISM, [LEDER] = L.PROF_LEATHERWORKING,
  [BERGBAU] = L.PROF_MINING, [KUERSCHNER] = L.PROF_SKINNING, [SCHNEIDER] = L.PROF_TAILORING,
}

-- Berufe des Chars: [Fertigkeitslinie] = Wert. Direkt nach dem Login liefert Forever noch nichts.
function O.Berufe()
  local t = {}
  if not (GetProfessions and GetProfessionInfo) then return t end
  local ok, a, b, c, d, e = pcall(GetProfessions)
  if not ok then return t end
  for _, idx in pairs({ a, b, c, d, e }) do
    local ok2, _, _, wert, _, _, _, linie = pcall(GetProfessionInfo, idx)
    if ok2 and linie then t[linie] = wert or 0 end
  end
  return t
end

local function anzahl(itemID)
  if C_Item and C_Item.GetItemCount then
    local ok, n = pcall(C_Item.GetItemCount, itemID)
    if ok and n then return n end
  end
  return 0
end

-- Fehlt Material? Rückgabe: true, wenn alles da ist (auch das Werkzeug)
function O.MaterialDa(o)
  for _, m in ipairs(o.mats) do
    if anzahl(m[1]) < m[2] then return false end
  end
  if o.werkzeug and anzahl(o.werkzeug) < 1 then return false end
  return true
end

-- Material als Text: "Peacebloom 3/1, Silverleaf 0/1"
function O.MaterialText(o)
  local teile = {}
  local function name(id)
    local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if not n and C_Item and C_Item.GetItemInfo then n = C_Item.GetItemInfo(id) end
    if not n and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return n or string.format(L.ITEM_ID, id)
  end
  for _, m in ipairs(o.mats) do
    table.insert(teile, string.format(L.MAT_LINE, name(m[1]), anzahl(m[1]), m[2]))
  end
  if o.werkzeug then table.insert(teile, string.format(L.TOOL_LINE, name(o.werkzeug), anzahl(o.werkzeug))) end
  return table.concat(teile, ", ")
end

-- Name und Symbol vom Spiel, falls es den Zauber kennt
function O.Anzeige(o)
  local name, icon
  if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(o.spell) end
  if C_Spell and C_Spell.GetSpellTexture then icon = C_Spell.GetSpellTexture(o.spell) end
  return name or o.name, icon or ns.ESSEN_TEXTUR
end

-- Schlüssel des Chars für Merkzettel je Char ("Name-Realm")
local function charSchluessel()
  local name = UnitName and UnitName("player")
  local realm = GetRealmName and GetRealmName()
  if not name then return nil end
  return name .. "-" .. (realm or "")
end

-- Kennt der Char das Rezept? true, false oder nil (das Spiel kann es gerade nicht sagen).
-- Berufsrezepte stehen in Forever nicht im Zauberbuch. Sicher weiß es nur das offene Fenster des
-- Berufs (C_TradeSkillUI.GetRecipeInfo). Was es dort sagt, wird je Char gemerkt.
function O.Gelernt(o)
  if IsPlayerSpell then
    local ok, ja = pcall(IsPlayerSpell, o.spell)
    if ok and ja then return true end
  end
  local key = charSchluessel()
  local merk = key and ns.db and ns.db.rezepte and ns.db.rezepte[key]
  if ns.Kit and ns.Kit.OffenerBeruf and ns.Kit.OffenerBeruf() == o.beruf
    and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
    local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, o.spell)
    if ok and type(info) == "table" and type(info.learned) == "boolean" then
      if key and ns.db then
        ns.db.rezepte = ns.db.rezepte or {}
        ns.db.rezepte[key] = ns.db.rezepte[key] or {}
        ns.db.rezepte[key][o.spell] = info.learned
      end
      return info.learned
    end
  end
  if merk and merk[o.spell] ~= nil then return merk[o.spell] end
  return nil
end

-- Welcher Gegenstand entsteht beim Bauen? Erst was beim Bauen gelernt wurde
-- (CampfireBuddyDB.objektItems), dann die Rezeptdaten des Spiels, zuletzt die Liste oben.
local schematik = {}
local function bekannt(o)
  local gelernt = ns.db and ns.db.objektItems and ns.db.objektItems[o.spell]
  if gelernt then return gelernt end
  if schematik[o.spell] == nil then
    schematik[o.spell] = false
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic then
      local ok, s = pcall(C_TradeSkillUI.GetRecipeSchematic, o.spell, false)
      if ok and type(s) == "table" and type(s.outputItemID) == "number" and s.outputItemID > 0 then
        schematik[o.spell] = s.outputItemID
      end
    end
  end
  return schematik[o.spell] or nil
end

function O.Gegenstand(o)
  return bekannt(o) or o.item
end

-- Leere Antworten nicht für immer merken: Die Rezeptdaten können erst später geladen sein.
-- Nach jeder Taschenänderung wird für unbekannte Objekte neu gefragt.
function O.RezepteNeuFragen()
  for spell, id in pairs(schematik) do
    if id == false then schematik[spell] = nil end
  end
end

-- Wie viele fertige Objekte trägt der Char bei sich?
function O.Vorrat(o)
  local id = O.Gegenstand(o)
  return id and anzahl(id) or 0, id
end

-- Beim Bauen lernen, welcher Gegenstand entsteht: vorher die Taschen zählen (Klick auf den Knopf),
-- nach dem erfolgreichen Zauber vergleichen. Nur Gegenstände, die mehr geworden sind und kein
-- Material des Rezepts sind.
local function taschen()
  local t = {}
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return t end
  for tasche = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
    for platz = 1, C_Container.GetContainerNumSlots(tasche) or 0 do
      local info = C_Container.GetContainerItemInfo(tasche, platz)
      if info and info.itemID then t[info.itemID] = (t[info.itemID] or 0) + (info.stackCount or 1) end
    end
  end
  return t
end

-- Platz eines Gegenstands in den Taschen als "Tasche Platz" für den sicheren Knopf. Forever
-- ignoriert "item:<ID>" beim Benutzen still (Befund aus Fireside), Name oder Platz gehen.
function O.Platz(itemID)
  if not (itemID and C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return nil end
  for tasche = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
    for platz = 1, C_Container.GetContainerNumSlots(tasche) or 0 do
      local info = C_Container.GetContainerItemInfo(tasche, platz)
      if info and info.itemID == itemID then return tasche .. " " .. platz end
    end
  end
end

function O.VorDemBauen(o)
  if bekannt(o) then return end
  O.wartet = { o = o, vorher = taschen(), zeit = (GetTime and GetTime() or time()) }
end

function O.NachDemBauen()
  local w = O.wartet
  if not w or not w.erfolg then return end
  O.wartet = nil
  local material = {}
  for _, m in ipairs(w.o.mats) do material[m[1]] = true end
  local neu
  for id, n in pairs(taschen()) do
    if n > (w.vorher[id] or 0) and not material[id] then
      if neu then return end   -- mehrere neue Gegenstände: lieber nichts lernen
      neu = id
    end
  end
  if neu and ns.db then
    ns.db.objektItems = ns.db.objektItems or {}
    ns.db.objektItems[w.o.spell] = neu
  end
end

-- Zustand eines Objekts für diesen Char:
--   "vorrat" (fertiges Objekt in den Taschen), "bereit" (Beruf hoch genug, Material da),
--   "material" (Material fehlt), "lernen" (Beruf hoch genug, Rezept sicher noch nicht gelernt),
--   "stufe" (Beruf da, Wert zu niedrig), "beruf" (Beruf fehlt)
function O.Zustand(o, berufe)
  if O.Vorrat(o) > 0 then return "vorrat" end
  local wert = berufe[o.beruf]
  if not wert then return "beruf" end
  if wert < o.stufe then return "stufe" end
  if O.Gelernt(o) == false then return "lernen" end
  if not O.MaterialDa(o) then return "material" end
  return "bereit"
end

-- Das beste Objekt einer Familie für diesen Char: erst ein fertiges aus den Taschen, dann eins,
-- das er jetzt bauen kann (jeweils die höchste Stufe), sonst die einfachste Stufe, für die nur
-- Material fehlt. Rückgabe: Objekt, Zustand, Nummer in O.LISTE. nil: nichts davon.
function O.Bestes(familie, berufe)
  berufe = berufe or O.Berufe()
  for _, gesucht in ipairs({ "vorrat", "bereit" }) do
    for i = #O.LISTE, 1, -1 do
      local o = O.LISTE[i]
      if o.familie == familie and O.Passt(o) and O.Zustand(o, berufe) == gesucht then return o, gesucht, i end
    end
  end
  for i, o in ipairs(O.LISTE) do
    if o.familie == familie and O.Passt(o) and O.Zustand(o, berufe) == "material" then return o, "material", i end
  end
end

-- Das passende Lagerfeuer. nil, wenn Kochen fehlt oder zu niedrig ist.
function O.BestesFeuer(berufe)
  return O.Bestes("feuer", berufe)
end

-- Für die Camp-Kit-Leiste am Feuer: je Familie das beste Objekt (ohne Lagerfeuer), damit die
-- Leiste nicht mit drei Stufen desselben Bonus volläuft. { { o, zustand, nr }, ... }
function O.FuersKit(berufe)
  berufe = berufe or O.Berufe()
  local t, gesehen = {}, {}
  for _, o in ipairs(O.LISTE) do
    if o.art ~= "feuer" and not gesehen[o.familie] then
      gesehen[o.familie] = true
      local best, z, nr = O.Bestes(o.familie, berufe)
      if best then table.insert(t, { o = best, zustand = z, nr = nr }) end
    end
  end
  return t
end

-- Objekte, die dieser Char grundsätzlich aufstellen kann (Beruf hoch genug)
function O.Meine()
  local berufe = O.Berufe()
  local t = {}
  for _, o in ipairs(O.LISTE) do
    local z = O.Zustand(o, berufe)
    if O.Passt(o) and (z == "vorrat" or z == "bereit" or z == "material") then table.insert(t, o) end
  end
  return t
end

-- Hat der Char einen Klassen-Buff, neben dem dieses Objekt nichts bringt? Rückgabe: Name des
-- Buffs oder nil. Verglichen wird über die Zauber-ID und über den Namen, den das Spiel selbst zu
-- dieser ID nennt (höhere Ränge haben eigene IDs, aber denselben Namen). So passt es in jeder
-- Spielsprache. Gelesen wird nur außerhalb des Kampfes (Buffs.lua).
local konfliktNamen = {}
function O.Konflikt(o)
  local fam = O.FAMILIE[o.familie]
  local B = ns.Buffs
  if not (fam and fam.konflikt and B and B.ids and B.namen) then return nil end
  for _, id in ipairs(fam.konflikt) do
    if konfliktNamen[id] == nil then
      konfliktNamen[id] = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or false
    end
    local name = konfliktNamen[id]
    if B.ids[id] or (name and B.namen[name]) then return name or tostring(id) end
  end
end

-- Wirkt der Bonus dieser Familie schon (eigener Buff des Objekts)? Nur über die Zauber-ID, die
-- Buff-Liste liest Buffs.lua außerhalb des Kampfes. Fehlt der Buff dort (verborgene Auren),
-- wird einzeln gefragt, ebenfalls nur außerhalb des Kampfes.
function O.BonusAktiv(o)
  -- In Forever stehen alle Boni im Tooltip von Camp Benefits (Lager.lua)
  if ns.Lager and ns.Lager:Benefits()[o.familie] then return true end
  local fam = O.FAMILIE[o.familie]
  local id = fam and fam.aura
  if not id then return false end
  local B = ns.Buffs
  if B and B.ids and B.ids[id] then return true end
  if InCombatLockdown and InCombatLockdown() then return false end
  if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
    return ok and a ~= nil
  end
  return false
end

-- Lager-Boni, die gerade wirken, mit Wert ("Stamina +3"), aus dem Tooltip von Camp Benefits
function O.AktiveBoni()
  local namen = {}
  for _, b in ipairs(ns.Lager and ns.Lager:Boni() or {}) do
    table.insert(namen, b.punkte and string.format(ns.L.BONUS_NAME_VALUE, b.name, b.punkte) or b.name)
  end
  return namen
end

-- Für den Tooltip: welche Klassen-Buffs heben den Bonus auf? "Blessing of Wisdom" oder nil
function O.KonfliktText(o)
  local fam = O.FAMILIE[o.familie]
  if not (fam and fam.konflikt) then return nil end
  local id = fam.konflikt[1]
  return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or nil
end

-- Werte je Levelbereich -----------------------------------------------------------------------
-- Ein aufgestelltes Objekt nennt im Tooltip des Spiels seinen Bonus je Levelbereich, etwa
-- "+21 Stamina (24-35)" (Patricks Screenshots, 17. Okt). Lager.lua lernt diese Zeilen, sobald die
-- Maus über einem Objekt steht, und legt sie in ns.db.objektWerte[Zauber-ID] ab.
-- Bis dahin gelten die Werte aus den Screenshots: { von, bis, Wert }, ohne Bereich nur der Wert.
O.START = {
  [1230117] = { { 1, 11, 3 }, { 12, 23, 8 }, { 24, 35, 21 }, { 36, 47, 34 }, { 48, 59, 45 }, { 60, 60, 56 } },
  [1263425] = { { nil, nil, 14 } },
  [1229504] = { { nil, nil, 14 } },
}

local function ohneFarbe(t)
  t = string.gsub(t, "|c%x%x%x%x%x%x%x%x", "")
  t = string.gsub(t, "|r", "")
  return (string.gsub(string.gsub(t, "^%s+", ""), "%s+$", ""))
end

-- Eine Zeile aus dem Tooltip des Spiels: { text = "+21 Stamina", von = 24, bis = 35 } oder nil.
-- Erkannt wird nur die Form (Zahl mit Vorzeichen, Bereich in Klammern), nie ein Name.
function O.StufeLesen(t)
  if type(t) ~= "string" or (issecretvalue and issecretvalue(t)) then return nil end
  t = ohneFarbe(t)
  local wert, rest, von, bis = string.match(t, "^([%+%-]%d+%%?)%s+(.-)%s*%((%d+)%s*%-%s*(%d+)%)$")
  if wert then return { text = wert .. " " .. rest, von = tonumber(von), bis = tonumber(bis) } end
  wert, rest, von = string.match(t, "^([%+%-]%d+%%?)%s+(.-)%s*%((%d+)%)$")
  if wert then return { text = wert .. " " .. rest, von = tonumber(von), bis = tonumber(von) } end
  wert, rest = string.match(t, "^([%+%-]%d+%%?)%s+(%S.*)$")
  if wert then return { text = wert .. " " .. rest } end
end

-- Zeilen eines Tooltips (ab der zweiten) auswerten. Rückgabe: Liste der Stufen oder nil.
function O.StufenAus(zeilen)
  local t = {}
  for i = 2, #zeilen do
    local z = zeilen[i]
    local s = O.StufeLesen(type(z) == "table" and z.leftText or z)
    if s then table.insert(t, s) end
  end
  return #t > 0 and t or nil
end

-- Steht es auch im Tooltip des Gegenstands (Taschen)? Einmal je Sitzung und Objekt nachsehen,
-- nur außerhalb des Kampfes.
local imGegenstandGesucht = {}
local function ausGegenstand(o)
  if imGegenstandGesucht[o] or not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
  if InCombatLockdown and InCombatLockdown() then return nil end
  imGegenstandGesucht[o] = true
  local ok, daten = pcall(C_TooltipInfo.GetItemByID, o.item)
  if not (ok and type(daten) == "table" and type(daten.lines) == "table") then return nil end
  local stufen = O.StufenAus(daten.lines)
  if stufen and ns.db then
    ns.db.objektWerte = ns.db.objektWerte or {}
    ns.db.objektWerte[o.spell] = stufen
  end
  return stufen
end

-- Stufen eines Objekts: gelernt, aus dem Gegenstand oder aus den Startwerten
function O.Stufen(o)
  local gelernt = ns.db and ns.db.objektWerte and ns.db.objektWerte[o.spell]
  if gelernt then return gelernt end
  local g = ausGegenstand(o)
  if g then return g end
  local start = O.START[o.spell]
  if not start then return nil end
  local bonus = O.FAMILIE[o.familie] and O.FAMILIE[o.familie].bonus or ""
  local t = {}
  for _, s in ipairs(start) do
    table.insert(t, { text = string.format(L.TT_VALUE, s[3], bonus), von = s[1], bis = s[2] })
  end
  return t
end

-- Bonus für das Level des Chars als Text ("+21 Stamina"), sonst der gelernte Wert, sonst nil
function O.WertFuerMich(o)
  local level = UnitLevel and UnitLevel("player") or 0
  for _, s in ipairs(o.art ~= "feuer" and O.Stufen(o) or {}) do
    if not s.von or (level >= s.von and level <= (s.bis or s.von)) then return s.text end
  end
  local wert = ns.Lager and ns.Lager.WertText(o)
  local bonus = O.FAMILIE[o.familie] and O.FAMILIE[o.familie].bonus
  return wert and bonus and string.format(L.TT_VALUE_TEXT, wert, bonus) or nil
end

-- Name des Berufs, wie das Spiel ihn nennt, sonst aus Locale.lua
function O.BerufName(linie)
  if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName then
    local ok, n = pcall(C_TradeSkillUI.GetTradeSkillDisplayName, linie)
    if ok and type(n) == "string" and n ~= "" then return n end
  end
  return O.BERUF_NAME[linie] or "?"
end

-- Tooltip eines Lager-Objekts im Stil des Spiels: Name, Bonus je Levelbereich (der eigene grün),
-- "Exclusive with" und der Beruf. Danach hängt der Aufrufer eigene Zeilen an.
local GRUEN, GRAU, WEISS = { 0.1, 1, 0.1 }, { 0.5, 0.5, 0.5 }, { 0.85, 0.85, 0.85 }
function O.TooltipFuellen(tt, o)
  tt:SetText((O.Anzeige(o)), 1, 0.82, 0)
  local stufen = o.art ~= "feuer" and O.Stufen(o)
  local level = UnitLevel and UnitLevel("player") or 0
  if stufen then
    tt:AddLine(" ")
    for _, s in ipairs(stufen) do
      local text = s.text
      if s.von and s.bis and s.von ~= s.bis then text = string.format(L.TT_RANGE, text, s.von, s.bis)
      elseif s.von then text = string.format(L.TT_LEVEL, text, s.von) end
      local hier = s.von and level >= s.von and level <= (s.bis or s.von)
      local c = hier and GRUEN or WEISS
      tt:AddLine(text, c[1], c[2], c[3])
    end
  else
    local wert = ns.Lager and ns.Lager.WertText(o)
    local bonus = O.FAMILIE[o.familie] and O.FAMILIE[o.familie].bonus
    tt:AddLine(" ")
    tt:AddLine(wert and bonus and string.format(L.TT_VALUE_TEXT, wert, bonus) or o.info, WEISS[1], WEISS[2], WEISS[3], true)
  end
  local gegen = O.KonfliktText(o)
  if gegen then tt:AddLine(string.format(L.TT_EXCLUSIVE, gegen), 1, 0.5, 0.25) end
  tt:AddLine(O.BerufName(o.beruf), GRAU[1], GRAU[2], GRAU[3])
end

-- So einen Tooltip an einen Rahmen hängen. objektVon(self) liefert das Objekt, extra(self, tt, o)
-- hängt eigene Zeilen an (Material, Zustand). Ohne Objekt zeigt er leerText, falls gesetzt.
function O.TooltipAn(rahmen, objektVon, extra, leerText)
  rahmen:HookScript("OnEnter", function(self)
    local o = objektVon(self)
    if not o and not leerText then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if o then
      O.TooltipFuellen(GameTooltip, o)
      if extra then extra(self, GameTooltip, o) end
    else
      GameTooltip:SetText(leerText, 1, 1, 1)
    end
    GameTooltip:Show()
  end)
  rahmen:HookScript("OnLeave", function() GameTooltip:Hide() end)
end
