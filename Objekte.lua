-- Lager-Objekte: Jeder Beruf hat ein Objekt, das man am Lagerfeuer aufstellt. Das Rezept (Zauber)
-- baut daraus einen Gegenstand für die Taschen, Benutzen stellt ihn auf (Patricks Beobachtung in der
-- Beta, 14. Okt). Beim Lagerfeuer sind sich die Guides nicht einig: Es steht sofort, oder es entsteht
-- erst ein Bausatz für die Taschen. Beides geht: Entsteht ein Gegenstand, wird er gelernt und wie
-- die anderen Objekte aus den Taschen aufgestellt. Die Werte aller Objekte stecken in Camp Benefits.
-- Zauber- und Gegenstands-IDs aus öffentlichen Forever-Übersichten (Stand Okt 2026), Texte eigene.
-- Erkannt wird alles über IDs: Beruf über die Fertigkeitslinie, Material über die Gegenstands-ID.
local ADDON, ns = ...
local L = ns.L

local O = {}
ns.Objekte = O

-- Fertigkeitslinien der Berufe
local ALCHEMIE, SCHMIED, KOCHEN, VERZAUBERN, INGENIEUR, ERSTE_HILFE = 171, 164, 185, 333, 202, 129
local ANGELN, KRAEUTER, LEDER, BERGBAU, KUERSCHNER, SCHNEIDER = 356, 182, 165, 186, 393, 197

-- art: "feuer" (Lagerfeuer, braucht kein Feuer in der Nähe) oder "objekt" (am Lagerfeuer)
-- mats: { { Gegenstands-ID, Menge }, ... }, werkzeug: Gegenstand, der nicht verbraucht wird
O.LISTE = {
  { spell = 818, beruf = KOCHEN, stufe = 1, art = "feuer", mats = { { 4470, 1 } }, werkzeug = 4471,
    name = L.OBJ_CAMPFIRE, info = L.OBJ_CAMPFIRE_INFO, lernen = L.LEARN_TRAINER },
  { spell = 1283400, beruf = KOCHEN, stufe = 90, art = "feuer", mats = { { 11291, 1 } }, werkzeug = 4471,
    name = L.OBJ_CAMPFIRE_2, info = L.OBJ_CAMPFIRE_2_INFO, lernen = L.LEARN_BLUEPRINT },
  { spell = 1291341, beruf = KOCHEN, stufe = 220, art = "feuer", mats = { { 272941, 1 } }, werkzeug = 4471,
    name = L.OBJ_CAMPFIRE_3, info = L.OBJ_CAMPFIRE_3_INFO, lernen = L.LEARN_BLUEPRINT },
  { spell = 1230564, beruf = ALCHEMIE, stufe = 20, mats = { { 2447, 1 }, { 3371, 1 } },
    name = L.OBJ_MANA_WELL, info = L.OBJ_MANA_WELL_INFO },
  { spell = 1230171, beruf = SCHMIED, stufe = 20, mats = { { 2835, 1 }, { 2840, 1 } },
    name = L.OBJ_SHARPENING_WHEEL, info = L.OBJ_SHARPENING_WHEEL_INFO },
  { spell = 1230643, beruf = VERZAUBERN, stufe = 20, mats = { { 4470, 1 }, { 10940, 1 } },
    name = L.OBJ_LUTE, info = L.OBJ_LUTE_INFO },
  { spell = 1230656, beruf = INGENIEUR, stufe = 20, mats = { { 4359, 1 }, { 4361, 1 } },
    name = L.OBJ_REAGENT_BOT, info = L.OBJ_REAGENT_BOT_INFO },
  { spell = 1230117, beruf = ERSTE_HILFE, stufe = 20, mats = { { 1251, 3 }, { 159, 1 } },
    name = L.OBJ_FIRST_AID, info = L.OBJ_FIRST_AID_INFO },
  { spell = 1229745, beruf = ANGELN, stufe = 20, mats = { { 6291, 1 }, { 3371, 1 } },
    name = L.OBJ_FISH_BOWL, info = L.OBJ_FISH_BOWL_INFO },
  { spell = 1229705, beruf = KRAEUTER, stufe = 20, mats = { { 2447, 1 }, { 765, 1 } },
    name = L.OBJ_CANDLE, info = L.OBJ_CANDLE_INFO },
  { spell = 1229432, beruf = LEDER, stufe = 20, mats = { { 2318, 5 } },
    name = L.OBJ_TENT, info = L.OBJ_TENT_INFO },
  { spell = 1230161, beruf = BERGBAU, stufe = 20, mats = { { 2835, 1 }, { 2840, 1 } },
    name = L.OBJ_LODESTONE, info = L.OBJ_LODESTONE_INFO },
  { spell = 1229517, beruf = KUERSCHNER, stufe = 20, mats = { { 2318, 3 }, { 4470, 2 } },
    name = L.OBJ_CHAIR, info = L.OBJ_CHAIR_INFO },
  { spell = 1263425, beruf = SCHNEIDER, stufe = 20, mats = { { 2996, 1 }, { 2320, 1 } },
    name = L.OBJ_BANNER, info = L.OBJ_BANNER_INFO },
}

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

-- Kennt der Char das Rezept sicher? nil, wenn das Spiel es nicht sagen kann.
function O.Gelernt(o)
  if IsPlayerSpell then
    local ok, ja = pcall(IsPlayerSpell, o.spell)
    if ok and ja then return true end
  end
  if IsSpellKnown then
    local ok, ja = pcall(IsSpellKnown, o.spell)
    if ok and ja then return true end
  end
  return nil
end

-- Welcher Gegenstand entsteht beim Bauen? Erst aus den Rezeptdaten des Spiels, sonst das, was
-- beim ersten Bauen neu in den Taschen auftauchte (CampfireBuddyDB.objektItems). nil: unbekannt
-- oder es gibt keinen (das Lagerfeuer steht sofort).
local schematik = {}
function O.Gegenstand(o)
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

function O.VorDemBauen(o)
  if O.Gegenstand(o) then return end
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
--   "material" (Material fehlt), "stufe" (Beruf da, Wert zu niedrig), "beruf" (Beruf fehlt)
function O.Zustand(o, berufe)
  if O.Vorrat(o) > 0 then return "vorrat" end
  local wert = berufe[o.beruf]
  if not wert then return "beruf" end
  if wert < o.stufe then return "stufe" end
  if not O.MaterialDa(o) then return "material" end
  return "bereit"
end

-- Das passende Lagerfeuer für diesen Char: erst ein fertiges aus den Taschen, dann eins, das er
-- jetzt bauen kann (jeweils das größte), sonst das einfachste, für das nur Material fehlt.
-- Rückgabe: Objekt, Zustand, Nummer in O.LISTE. nil, wenn Kochen fehlt oder zu niedrig ist.
function O.BestesFeuer(berufe)
  berufe = berufe or O.Berufe()
  for _, gesucht in ipairs({ "vorrat", "bereit" }) do
    for i = #O.LISTE, 1, -1 do
      local o = O.LISTE[i]
      if o.art == "feuer" and O.Zustand(o, berufe) == gesucht then return o, gesucht, i end
    end
  end
  for i, o in ipairs(O.LISTE) do
    if o.art == "feuer" and O.Zustand(o, berufe) == "material" then return o, "material", i end
  end
end

-- Objekte, die dieser Char grundsätzlich aufstellen kann (Beruf hoch genug)
function O.Meine()
  local berufe = O.Berufe()
  local t = {}
  for _, o in ipairs(O.LISTE) do
    local z = O.Zustand(o, berufe)
    if z == "vorrat" or z == "bereit" or z == "material" then table.insert(t, o) end
  end
  return t
end
