-- Camp Kit: kleine Leiste mit Knöpfen, die am Lagerfeuer erscheint. Ein Klick setzt den Char hin
-- oder macht beim Lager-Objekt den nächsten Schritt: Liegt ein fertiges Objekt in den Taschen,
-- wird es benutzt (aufgestellt, sicherer Knopf Typ item). Sonst wird es gebaut. Die Objekte sind in
-- Forever Berufsrezepte (Beta, 14. Okt): Gebaut wird wie mit "Create" im Berufsfenster
-- (C_TradeSkillUI.CraftRecipe, ein Stück pro Klick). Ist das Fenster des Berufs zu, öffnet der
-- erste Klick es, der zweite baut.
-- Die Knöpfe sind sichere Aktionsknöpfe wie auf der Aktionsleiste (SecureActionButtonTemplate):
-- Das Spiel führt die Aktion nur bei einem echten Klick aus, ein Klick ist genau eine Aktion.
-- Sichere Knöpfe dürfen im Kampf nicht ein- oder ausgeblendet oder verschoben werden. Deshalb
-- ändert die Leiste sich nur außerhalb des Kampfes und holt Änderungen danach nach.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba
local O = ns.Objekte

local K = { knoepfe = {} }
ns.Kit = K

local GROESSE, ABSTAND, RAND = 32, 4, 6
local SITZEN = "Interface\\Icons\\Spell_Nature_Sleep"

local function imKampf() return InCombatLockdown and InCombatLockdown() end

local function tooltip(b)
  local o = b.objekt
  GameTooltip:SetOwner(b, "ANCHOR_TOP")
  if not o then
    GameTooltip:SetText(L.BTN_SIT, 1, 1, 1)
    GameTooltip:AddLine(L.SIT_HELP, F.leise[1], F.leise[2], F.leise[3], true)
    -- Lohnt sich das Hinsetzen für diesen Char? (Empfehlung.lua)
    local urteil = ns.Empfehlung and ns.Empfehlung:Urteil()
    if urteil then GameTooltip:AddLine(urteil, F.akzent[1], F.akzent[2], F.akzent[3], true) end
  else
    local name = O.Anzeige(o)
    GameTooltip:SetText(name, 1, 1, 1)
    GameTooltip:AddLine(o.info, F.leise[1], F.leise[2], F.leise[3], true)
    local basis = O.BASIS[o.familie]
    if basis and basis ~= o and o.art ~= "feuer" then
      GameTooltip:AddLine(string.format(L.KIT_REPLACES, (O.Anzeige(basis))), F.leise[1], F.leise[2], F.leise[3], true)
    end
    local konflikt = O.Konflikt(o)
    if konflikt then
      GameTooltip:AddLine(string.format(L.KIT_CONFLICT, konflikt), F.hinweis[1], F.hinweis[2], F.hinweis[3], true)
    elseif O.BonusAktiv(o) then
      GameTooltip:AddLine(L.KIT_BONUS_ACTIVE, F.erfolg[1], F.erfolg[2], F.erfolg[3], true)
    end
    local vorrat = O.Vorrat(o)
    if vorrat > 0 then
      GameTooltip:AddLine(string.format(L.KIT_IN_BAGS, vorrat), 0.4, 0.84, 0.56, true)
      GameTooltip:AddLine(L.KIT_CLICK_PLACE, F.akzent[1], F.akzent[2], F.akzent[3], true)
    else
      local da = O.MaterialDa(o)
      GameTooltip:AddLine(O.MaterialText(o), da and 0.4 or 0.94, da and 0.84 or 0.38, da and 0.56 or 0.35, true)
      local klick = o.art == "feuer" and L.KIT_CLICK or L.KIT_CLICK_BUILD
      GameTooltip:AddLine(da and klick or L.KIT_MISSING, F.akzent[1], F.akzent[2], F.akzent[3], true)
    end
  end
  GameTooltip:Show()
end

local function knopf(parent, objekt)
  local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate,BackdropTemplate")
  b:SetSize(GROESSE, GROESSE)
  -- Nur eine Tastenkante: Mit beiden führt Forever die Aktion pro Klick zweimal aus (Befund aus
  -- Fireside). Welche, sagt die Einstellung "Aktion beim Drücken" der Aktionsleisten.
  b.runter = (GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")) and true or false
  b:RegisterForClicks(b.runter and "AnyDown" or "AnyUp")
  if objekt then
    b:SetAttribute("type", "spell")
    b:SetAttribute("spell", objekt.spell)
  else
    -- Hinsetzen über das Emote, als Makro des Spiels, nicht über eine Add-on-Funktion
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "/sit")
  end
  b.objekt = objekt
  if b.SetBackdrop then
    b:SetBackdrop({ bgFile = S.WEISS, edgeFile = S.WEISS, edgeSize = 1 })
    b:SetBackdropColor(rgba(F.flaeche))
    b:SetBackdropBorderColor(rgba(F.rand))
  end
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if objekt then
    local _, icon = O.Anzeige(objekt)
    b.icon:SetTexture(icon)
  else
    b.icon:SetTexture(SITZEN)
  end
  b.anzahl = S.schrift(b, "NumberFontNormal", F.text)
  b.anzahl:SetPoint("BOTTOMRIGHT", -2, 2)
  b.abklingen = S.schrift(b, "GameFontNormalSmall", F.text)
  b.abklingen:SetPoint("CENTER", 0, 0)
  -- Bauen läuft über das Berufsfenster, nicht über den sicheren Teil des Knopfs
  b:HookScript("OnClick", function(self, taste, runter) K:BauKlick(self, runter) end)
  b:HookScript("OnEnter", function(self) S.randFarbe(self, S.heller(F.akzent)) tooltip(self) end)
  b:HookScript("OnLeave", function(self) K.Rand(self) GameTooltip:Hide() end)
  b:Hide()
  return b
end

-- Rand eines Knopfs: glutrot, wenn das Objekt hier vorgeschlagen wird, sonst schlicht
function K.Rand(b)
  S.randFarbe(b, b.vorschlag and F.akzent or F.rand)
end

function K:Bauen()
  if self.rahmen then return end
  local f = S.kasten(UIParent, "Frame", F.grund, F.rand)
  self.rahmen = f
  f:SetSize(100, GROESSE + 2 * RAND + 14)
  -- Über der Buff-Leiste: Die wächst nach unten, wenn Zeilen dazukommen
  ns.Leiste.Position(f, ns.db.kit, "TOP", 0, -74)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if not ns.db.gesperrt and not imKampf() then self:StartMoving() K.zieht = true end
  end)
  f:SetScript("OnDragStop", function(self)
    if not K.zieht then return end
    K.zieht = false
    self:StopMovingOrSizing()
    if not imKampf() then ns.db.kit = ns.Leiste.Merken(self) end
  end)
  S.schatten(f)
  f.titel = S.schrift(f, "GameFontHighlightSmall", F.akzent)
  f.titel:SetPoint("TOPLEFT", RAND, -3)
  f.titel:SetText(L.KIT_TITLE)
  f:Hide()
  -- Abklingzeit der Objekte einmal pro Sekunde (nur Texte und Farbe, das geht auch im Kampf)
  local warten = 0
  f:SetScript("OnUpdate", function(_, dt)
    warten = warten + dt
    if warten < 1 then return end
    warten = 0
    K:Abklingen()
  end)

  self.sitzen = knopf(f, nil)
  for i, o in ipairs(O.LISTE) do self.knoepfe[i] = knopf(f, o) end
end

-- Welche Knöpfe jetzt? Am Feuer: Sitzen und alle Objekte, die der Char bauen kann.
-- Ohne Feuer, wenn Camp Benefits fehlen oder bald enden: das passende Lagerfeuer (aus den Taschen
-- aufstellen oder bauen). Fehlt nur Material, erscheint es grau und der Tooltip sagt, was fehlt.
function K:Auswahl()
  local berufe = O.Berufe()
  local am = ns.Buffs.amFeuer
  local liste = {}
  if am then
    table.insert(liste, { knopf = self.sitzen, zustand = "bereit" })
    -- Je Bonus nur ein Knopf: die beste Stufe, die der Char hat oder bauen kann. Was dieses Lager
    -- noch brauchen kann (Lager.lua), steht vorne und bekommt den glutroten Rand.
    local objekte = {}
    for _, e in ipairs(O.FuersKit(berufe)) do
      local bereit = e.zustand == "vorrat" or e.zustand == "bereit"
      e.vorschlag = bereit and ns.Lager:Vorschlag(e.o)
      table.insert(objekte, e)
    end
    table.sort(objekte, function(a, b)
      if (a.vorschlag and true or false) ~= (b.vorschlag and true or false) then return a.vorschlag and true or false end
      return a.nr < b.nr
    end)
    for _, e in ipairs(objekte) do
      table.insert(liste, { knopf = self.knoepfe[e.nr], zustand = e.zustand, vorschlag = e.vorschlag })
    end
  elseif ns.Buffs:BrauchtLager() then
    local _, z, nr = O.BestesFeuer(berufe)
    if nr then table.insert(liste, { knopf = self.knoepfe[nr], zustand = z }) end
  end
  return liste
end

-- Knopf auf "aufstellen" (fertiges Objekt benutzen) oder "bauen" (Rezept wirken) stellen.
-- Nur außerhalb des Kampfes aufrufen: Attribute sicherer Knöpfe sind im Kampf gesperrt.
function K:Modus(b)
  local o = b.objekt
  local vorrat, id = O.Vorrat(o)
  if vorrat > 0 then
    b.modus, b.itemID = "aufstellen", id
    b:SetAttribute("type", "item")
    -- Platz in den Taschen, sonst der Name: "item:<ID>" ignoriert Forever beim Benutzen
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    b:SetAttribute("item", O.Platz(id) or name or ("item:" .. id))
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    if icon then b.icon:SetTexture(icon) end
    b.anzahl:SetText(vorrat > 1 and tostring(vorrat) or "1")
  else
    -- Bauen: der sichere Teil tut nichts, K:BauKlick übernimmt
    b.modus = "bauen"
    b:SetAttribute("type", nil)
    b:SetAttribute("spell", nil)
    local _, icon = O.Anzeige(o)
    b.icon:SetTexture(icon)
    b.anzahl:SetText("")
  end
end

-- Welcher Beruf ist gerade im Berufsfenster offen? Fertigkeitslinie oder nil.
local function offenerBeruf()
  if not (C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo) then return nil end
  if C_TradeSkillUI.IsTradeSkillReady then
    local ok, bereit = pcall(C_TradeSkillUI.IsTradeSkillReady)
    if ok and bereit == false then return nil end
  end
  local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
  if ok and type(info) == "table" then return info.professionID end
end

K.OffenerBeruf = offenerBeruf

-- Ein Stück bauen, ohne sicheren Knopf (Camp-Kit-Leiste und Hauptfenster). Ist das Fenster des
-- Berufs offen, wird das Rezept einmal gewirkt. Sonst öffnet der Klick erst das Fenster, der
-- nächste Klick baut. Pro Klick höchstens ein Stück.
function K:Craften(o)
  if not o or imKampf() then return end
  local beruf = O.BERUF_NAME[o.beruf] or "?"
  if offenerBeruf() == o.beruf and C_TradeSkillUI.CraftRecipe then
    if not O.MaterialDa(o) then return ns.melde(L.KIT_MISSING) end
    O.VorDemBauen(o)
    local ok = pcall(C_TradeSkillUI.CraftRecipe, o.spell, 1)
    if not ok then ns.melde(string.format(L.KIT_BUILD_FAILED, beruf)) end
    return
  end
  if not O.MaterialDa(o) then return ns.melde(L.KIT_MISSING) end
  if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
    local ok, offen = pcall(C_TradeSkillUI.OpenTradeSkill, o.beruf)
    if ok and offen ~= false then return ns.melde(string.format(L.KIT_OPENED, beruf)) end
  end
  ns.melde(string.format(L.KIT_OPEN_FIRST, beruf))
end

-- Klick im Modus "bauen" auf der Leiste. Nur auf der angemeldeten Tastenkante, damit ein Klick
-- nicht doppelt zählt.
function K:BauKlick(b, runter)
  if (runter and true or false) ~= b.runter or not b.objekt or b.modus ~= "bauen" then return end
  self:Craften(b.objekt)
end

-- Abklingzeit: fertiges Objekt (laut Guide eine Stunde nach dem Aufstellen) oder Lagerfeuer-Zauber
-- (etwa fünf Minuten). Dann grau und die Restzeit auf dem Knopf. Im Kampf nur die alten Texte.
local function abklingzeit(b)
  if b.modus == "aufstellen" and b.itemID and C_Container and C_Container.GetItemCooldown then
    local ok, start, dauer = pcall(C_Container.GetItemCooldown, b.itemID)
    if ok then return start, dauer end
  elseif b.modus == "bauen" and b.objekt.art == "feuer" and C_Spell and C_Spell.GetSpellCooldown then
    local ok, cd = pcall(C_Spell.GetSpellCooldown, b.objekt.spell)
    if ok and type(cd) == "table" then return cd.startTime, cd.duration end
  end
end

function K:Abklingen()
  if imKampf() then return end
  local jetzt = GetTime and GetTime() or 0
  for _, b in ipairs(self.knoepfe) do
    local text = ""
    local start, dauer = abklingzeit(b)
    if type(start) == "number" and type(dauer) == "number" and start > 0 and dauer > 1.5 then
      local rest = start + dauer - jetzt
      if rest > 0 then text = rest >= 60 and string.format(L.KIT_COOLDOWN_MIN, math.ceil(rest / 60)) or string.format(L.KIT_COOLDOWN_SEC, math.ceil(rest)) end
    end
    b.abklingen:SetText(text)
    b.icon:SetDesaturated(text ~= "" or b.zustand == "material")
  end
end

function K:Aktualisieren()
  if not self.rahmen then return end
  if imKampf() then
    self.spaeter = true
    return
  end
  self.spaeter = false
  local liste = ns.db.kitZeigen and self:Auswahl() or {}
  for _, b in ipairs(self.knoepfe) do b:Hide() end
  self.sitzen:Hide()
  for i, e in ipairs(liste) do
    local b = e.knopf
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", RAND + (i - 1) * (GROESSE + ABSTAND), -RAND - 12)
    if b.objekt then self:Modus(b) end
    b.zustand = e.zustand
    b.icon:SetDesaturated(e.zustand == "material")
    -- Glutroter Rand: Objekt ist bereit und das Lager kann es brauchen
    b.vorschlag = e.vorschlag and true or false
    K.Rand(b)
    b:Show()
  end
  if #liste == 0 then
    self.rahmen:Hide()
  else
    self.rahmen:SetWidth(math.max(90, 2 * RAND + #liste * GROESSE + (#liste - 1) * ABSTAND))
    self.rahmen:Show()
  end
end

ns.beimStart(function()
  K:Bauen()
  K:Aktualisieren()
end)
ns.beimAktualisieren(function() K:Aktualisieren() end)
ns.ereignis("BAG_UPDATE_DELAYED", function()
  O.NachDemBauen()
  O.RezepteNeuFragen()
  K:Aktualisieren()
end)
-- Bauen gelungen oder abgebrochen: für das Lernen des Gegenstands
ns.ereignis("UNIT_SPELLCAST_SUCCEEDED", function(einheit, _, spellID)
  local w = O.wartet
  if einheit == "player" and w and w.o.spell == spellID then w.erfolg = true end
end)
for _, e in ipairs({ "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
  ns.ereignis(e, function(einheit, _, spellID)
    local w = O.wartet
    if einheit == "player" and w and w.o.spell == spellID then O.wartet = nil end
  end)
end
ns.ereignis("SKILL_LINES_CHANGED", function() K:Aktualisieren() end)
-- Camp Benefits fallen ohne Ereignis unter 10 Minuten: alle 15 Sekunden nachsehen, ob das
-- Lagerfeuer jetzt angeboten werden soll
local brauchte
if C_Timer and C_Timer.NewTicker then
  C_Timer.NewTicker(15, function()
    if not ns.db then return end
    local jetzt = ns.Buffs:BrauchtLager()
    if jetzt ~= brauchte then
      brauchte = jetzt
      K:Aktualisieren()
    end
  end)
end
-- Berufsfenster auf oder zu: Knöpfe im Hauptfenster zeigen "Open" oder "Craft"
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE" }) do
  ns.ereignis(e, function() if ns.Fenster then ns.Fenster:Aktualisieren() end end)
end
ns.ereignis("PLAYER_REGEN_ENABLED", function() if K.spaeter then K:Aktualisieren() end end)
-- Kampf beginnt während des Ziehens: jetzt noch beenden und merken, gleich ist der Rahmen gesperrt
ns.ereignis("PLAYER_REGEN_DISABLED", function()
  if K.zieht and K.rahmen then
    K.zieht = false
    K.rahmen:StopMovingOrSizing()
    ns.db.kit = ns.Leiste.Merken(K.rahmen)
  end
end)
