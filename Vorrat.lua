-- Lagerkiste: zweite Reihe im Camp Kit am Feuer (Vorschlag vom 13. Nov, so machen es auch andere
-- Lager-Add-ons): Waffenbuff für Haupt- und Nebenhand (Wetzstein, Gewichtsstein, Öl, Gift) mit
-- Restzeit, der Schlafsack und drei freie Plätze für Essen, Trinken oder Tränke.
-- Ein Klick benutzt den Gegenstand, wie ein Aktionsknopf (sicherer Knopf, ein Klick eine Aktion).
-- Waffenbuffs kommen mit einem Klick auf die Waffe: Makro "/use <Tasche Platz>" und "/use 16"
-- (Haupthand) oder "/use 17" (Nebenhand), so wie man es auch von Hand tippen würde.
-- Belegen: Gegenstand aus den Taschen auf den Platz ziehen. Rechtsklick leert den Platz. Ohne
-- eigene Wahl nimmt ein Waffenplatz den besten passenden Waffenbuff aus den Taschen.
-- Alle Knöpfe haben feste Namen, damit sie Tasten bekommen können (Bindings.xml).
-- Attribute sicherer Knöpfe ändern sich nur außerhalb des Kampfes (Kit.lua ruft V:Anordnen).
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba
local O = ns.Objekte

local V = { knoepfe = {} }
ns.Vorrat = V

local GROESSE, ABSTAND = 32, 4
V.SCHLAFSACK = 211527   -- Cozy Sleeping Bag, Zauber "Unroll Bag" 429961, Buff "Well-Rested" 429959

-- Waffenbuffs (Wowhead Forever, 13. Nov), je Art das Beste zuerst. Ohne die Steine und Öle gegen
-- Untote (nur für bestimmte Gegner).
local WETZSTEIN = { 18262, 12404, 7964, 2871, 2863, 2862 }
local GEWICHTSSTEIN = { 12643, 7965, 3241, 3240, 3239 }
local OEL = { 20749, 20748, 20750, 20747, 20746, 20745, 20744, 3824, 3829 }
local GIFT = { 8928, 8927, 8926, 6950, 6949, 6947, 20844, 8985, 8984, 2893, 2892, 10922, 10921, 10920,
  10918, 3776, 3775, 9186, 6951, 5237 }
V.WAFFENBUFF = {}
for _, liste in ipairs({ WETZSTEIN, GEWICHTSSTEIN, OEL, GIFT, { 23122, 23123 } }) do
  for _, id in ipairs(liste) do V.WAFFENBUFF[id] = true end
end

-- Waffenarten (Unterklasse von Waffen, Klasse 2): scharf nimmt Wetzsteine, stumpf Gewichtssteine,
-- Faustwaffen beides
local SCHARF = { [0] = true, [1] = true, [6] = true, [7] = true, [8] = true, [15] = true, [13] = true }
local STUMPF = { [4] = true, [5] = true, [10] = true, [13] = true }

local PLAETZE = {
  { schluessel = "haupt", name = "CampfireBuddyWeaponMain", waffe = 16 },
  { schluessel = "neben", name = "CampfireBuddyWeaponOff", waffe = 17 },
  { schluessel = "schlafsack", name = "CampfireBuddySleepingBag", fest = V.SCHLAFSACK },
  { schluessel = 1, name = "CampfireBuddySupply1" },
  { schluessel = 2, name = "CampfireBuddySupply2" },
  { schluessel = 3, name = "CampfireBuddySupply3" },
}
V.PLAETZE = PLAETZE

local function imKampf() return InCombatLockdown and InCombatLockdown() end

local function anzahl(id)
  if not id then return 0 end
  local f = (C_Item and C_Item.GetItemCount) or GetItemCount
  if not f then return 0 end
  local ok, n = pcall(f, id)
  return ok and type(n) == "number" and n or 0
end

local function klasse(id)
  local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if not (f and id) then return nil end
  local ok, gefunden, _, _, _, _, k, u = pcall(f, id)
  if ok and gefunden then return k, u end
end

-- Eigene Wahl je Char: ns.db.vorrat["Name-Realm"] = { haupt, neben, [1], [2], [3] }
local function wahl()
  local name = UnitName and UnitName("player") or "?"
  local schluessel = name .. "-" .. ((GetRealmName and GetRealmName()) or "?")
  ns.db.vorrat = ns.db.vorrat or {}
  ns.db.vorrat[schluessel] = ns.db.vorrat[schluessel] or {}
  return ns.db.vorrat[schluessel]
end

-- Waffe in einem Platz (16 Haupthand, 17 Nebenhand): Unterklasse, oder nil ohne Nahkampfwaffe
local function waffe(platz)
  if not GetInventoryItemID then return nil end
  local ok, id = pcall(GetInventoryItemID, "player", platz)
  if not ok or not id then return nil end
  local k, u = klasse(id)
  if k == 2 and u and (SCHARF[u] or STUMPF[u]) then return u end
end

local function geheim(v) return issecretvalue ~= nil and issecretvalue(v) end

-- Restzeit des Waffenbuffs in Sekunden je Hand (16, 17), nil ohne Buff. Forever fragt je Waffe
-- über C_Item.GetWeaponEnchantInfo (wie die Buffleiste des Spiels), ältere Clients global.
function V.Verzauberung()
  local t = {}
  if C_Item and C_Item.GetWeaponEnchantInfo then
    local ws = Enum and Enum.WeaponSlot
    for platz, slot in pairs({ [16] = ws and ws.MainHand or 0, [17] = ws and ws.OffHand or 1 }) do
      local ok, liste = pcall(C_Item.GetWeaponEnchantInfo, slot)
      if ok and type(liste) == "table" then
        for _, e in pairs(liste) do
          if type(e) == "table" and not geheim(e.hasEnchant) and e.hasEnchant then
            local ms = e.timeLeft
            t[platz] = (type(ms) == "number" and not geheim(ms)) and ms / 1000 or 0
            break
          end
        end
      end
    end
    return t
  end
  if not GetWeaponEnchantInfo then return t end
  local ok, hatH, zeitH, _, _, hatN, zeitN = pcall(GetWeaponEnchantInfo)
  if not ok or geheim(hatH) or geheim(hatN) then return t end
  t[16] = hatH and (zeitH or 0) / 1000 or nil
  t[17] = hatN and (zeitN or 0) / 1000 or nil
  return t
end

-- Erster passender Waffenbuff aus den Taschen: Gift, dann Stein passend zur Waffe, dann Öl
local function bestesFuer(unterklasse)
  local reihen = { GIFT }
  if SCHARF[unterklasse] then table.insert(reihen, WETZSTEIN) end
  if STUMPF[unterklasse] then table.insert(reihen, GEWICHTSSTEIN) end
  table.insert(reihen, OEL)
  for _, liste in ipairs(reihen) do
    for _, id in ipairs(liste) do
      if anzahl(id) > 0 then return id end
    end
  end
end

-- Was liegt jetzt in einem Platz? Gegenstands-ID oder nil, dazu ob der Platz gezeigt wird
function V.Inhalt(p)
  local w = wahl()
  if p.waffe then
    local art = waffe(p.waffe)
    if not art then return nil, false end
    local id = w[p.schluessel]
    if id and anzahl(id) == 0 then id = nil end
    return id or bestesFuer(art), true
  end
  if p.fest then
    if anzahl(p.fest) > 0 then return p.fest, true end
    return nil, false
  end
  return w[p.schluessel], true
end

local function tooltip(b)
  local p = b.platz
  GameTooltip:SetOwner(b, "ANCHOR_TOP")
  if b.itemID then
    if not pcall(GameTooltip.SetItemByID, GameTooltip, b.itemID) then GameTooltip:SetText(tostring(b.itemID)) end
  else
    GameTooltip:SetText(p.waffe and (p.waffe == 16 and L.SUPPLY_MAIN_HAND or L.SUPPLY_OFF_HAND) or L.SUPPLY_EMPTY, 1, 1, 1)
  end
  GameTooltip:AddLine(" ")
  if p.waffe then
    GameTooltip:AddLine(p.waffe == 16 and L.SUPPLY_MAIN_HAND_HELP or L.SUPPLY_OFF_HAND_HELP, F.leise[1], F.leise[2], F.leise[3], true)
  elseif p.fest then
    GameTooltip:AddLine(L.SUPPLY_BAG_HELP, F.leise[1], F.leise[2], F.leise[3], true)
  else
    GameTooltip:AddLine(L.SUPPLY_PICK_HELP, F.leise[1], F.leise[2], F.leise[3], true)
  end
  if not p.fest then GameTooltip:AddLine(L.SUPPLY_DROP_HELP, F.leise[1], F.leise[2], F.leise[3], true) end
  GameTooltip:Show()
end

-- Gegenstand vom Mauszeiger in den Platz legen (nur außerhalb des Kampfes)
local function ablegen(b)
  if imKampf() or b.platz.fest or not GetCursorInfo then return false end
  local art, id = GetCursorInfo()
  if art ~= "item" or type(id) ~= "number" then return false end
  wahl()[b.platz.schluessel] = id
  if ClearCursor then ClearCursor() end
  ns.Kit:Aktualisieren()
  return true
end

local function knopf(p, parent)
  local b = CreateFrame("Button", p.name, parent, "SecureActionButtonTemplate,BackdropTemplate")
  b.platz = p
  b:SetSize(GROESSE, GROESSE)
  b.runter = (GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")) and true or false
  b:RegisterForClicks(b.runter and "AnyDown" or "AnyUp")
  if b.SetBackdrop then
    b:SetBackdrop({ bgFile = S.WEISS, edgeFile = S.WEISS, edgeSize = 1 })
    b:SetBackdropColor(rgba(F.flaeche))
    b:SetBackdropBorderColor(rgba(F.rand))
  end
  b.leer = b:CreateTexture(nil, "BACKGROUND", nil, 1)
  b.leer:SetPoint("TOPLEFT", 2, -2)
  b.leer:SetPoint("BOTTOMRIGHT", -2, 2)
  b.leer:SetTexture("Interface\\Buttons\\UI-Slot-Background")
  b.leer:SetTexCoord(0, 0.640625, 0, 0.640625)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.anzahl = S.schrift(b, "NumberFontNormal", F.text)
  b.anzahl:SetPoint("BOTTOMRIGHT", -2, 2)
  b.zeit = S.schrift(b, "GameFontNormalSmall", F.text)
  b.zeit:SetPoint("TOP", 0, -2)
  -- Leuchten, wenn die Waffe keinen Buff hat und einer in den Taschen liegt
  b.glanz = b:CreateTexture(nil, "OVERLAY")
  b.glanz:SetPoint("TOPLEFT", -3, 3)
  b.glanz:SetPoint("BOTTOMRIGHT", 3, -3)
  b.glanz:SetColorTexture(F.akzent[1], F.akzent[2], F.akzent[3], 0.35)
  b.glanz:SetAlpha(0)
  b.puls = S.pulsieren(b.glanz, 0.1, 1, 0.8)
  -- Mit Gegenstand am Mauszeiger belegt ein Klick den Platz, statt den alten Gegenstand zu benutzen
  b:SetScript("PreClick", function(self)
    if not imKampf() and CursorHasItem and CursorHasItem() and not self.platz.fest then
      self:SetAttribute("type1", nil)
      self.ablegen = true
    end
  end)
  b:HookScript("OnClick", function(self, taste)
    if self.ablegen then
      self.ablegen = nil
      if not ablegen(self) then ns.Kit:Aktualisieren() end
      return
    end
    if taste == "RightButton" and not imKampf() and not self.platz.fest then
      wahl()[self.platz.schluessel] = nil
      ns.Kit:Aktualisieren()
    end
  end)
  b:SetScript("OnReceiveDrag", function(self) ablegen(self) end)
  b:HookScript("OnEnter", function(self) S.randFarbe(self, S.heller(F.akzent)) tooltip(self) end)
  b:HookScript("OnLeave", function(self) S.randFarbe(self, F.rand) GameTooltip:Hide() end)
  b:Hide()
  return b
end

function V:Bauen(parent)
  if self.gebaut then return end
  self.gebaut = true
  for i, p in ipairs(PLAETZE) do self.knoepfe[i] = knopf(p, parent) end
end

-- Knopf auf seinen Gegenstand stellen (nur außerhalb des Kampfes)
local function herrichten(b, id)
  b.itemID = id
  local p = b.platz
  if id and anzahl(id) > 0 then
    local ziel = O.Platz(id) or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
    if ziel then
      b:SetAttribute("type1", "macro")
      b:SetAttribute("macrotext1", "/use " .. ziel .. (p.waffe and ("\n/use " .. p.waffe) or ""))
    else
      b:SetAttribute("type1", nil)
    end
  else
    b:SetAttribute("type1", nil)
  end
  local icon = id and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
  b.icon:SetTexture(icon)
  b.icon:SetShown(icon ~= nil)
  b.icon:SetDesaturated(id ~= nil and anzahl(id) == 0)
end

-- Zweite Reihe des Kits setzen. x, y: Ecke der Reihe im Kit. Rückgabe: Anzahl der Plätze.
function V:Anordnen(parent, x, y)
  self:Bauen(parent)
  local n = 0
  for _, b in ipairs(self.knoepfe) do
    local id, zeigen = V.Inhalt(b.platz)
    if zeigen and ns.db.vorratZeigen then
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", x + n * (GROESSE + ABSTAND), y)
      herrichten(b, id)
      b:Show()
      n = n + 1
    else
      b.itemID = nil
      b:Hide()
    end
  end
  self:Takt()
  return n
end

-- Jede Sekunde: Anzahl, Restzeit des Waffenbuffs oder Abklingzeit, Leuchten. Nur Texte und
-- Farben, das geht auch im Kampf.
function V:Takt()
  local buff = V.Verzauberung()
  local jetzt = GetTime and GetTime() or 0
  for _, b in ipairs(self.knoepfe) do
    if b:IsShown() then
      local p, id = b.platz, b.itemID
      local n = anzahl(id)
      b.anzahl:SetText(id and n > 1 and tostring(n) or "")
      local text, leuchten = "", false
      if p.waffe then
        local rest = buff[p.waffe]
        if rest and rest > 0 then
          text = rest >= 60 and string.format(L.KIT_COOLDOWN_MIN, math.floor(rest / 60)) or string.format(L.KIT_COOLDOWN_SEC, math.floor(rest))
        else
          leuchten = id ~= nil and n > 0
        end
      elseif id and C_Container and C_Container.GetItemCooldown then
        local ok, start, dauer = pcall(C_Container.GetItemCooldown, id)
        if ok and type(start) == "number" and type(dauer) == "number" and start > 0 and dauer > 1.5 then
          local rest = start + dauer - jetzt
          if rest > 0 then text = rest >= 60 and string.format(L.KIT_COOLDOWN_MIN, math.ceil(rest / 60)) or string.format(L.KIT_COOLDOWN_SEC, math.ceil(rest)) end
        end
      end
      b.zeit:SetText(text)
      b.leuchtet = leuchten
      S.puls(b.puls, leuchten)
    end
  end
end

-- Waffenbuff fehlt? Für die Leiste und den Lager-Check
function V.WaffeOhneBuff()
  local buff = V.Verzauberung()
  for _, platz in ipairs({ 16, 17 }) do
    if waffe(platz) and not buff[platz] then return true end
  end
  return false
end

-- Namen in der Tastaturbelegung des Spiels (die Belegung selbst steht in Bindings.xml)
BINDING_HEADER_CAMPFIREBUDDY = L.ADDON_NAME
for i = 1, 8 do _G["BINDING_NAME_CLICK CampfireBuddyKitSlot" .. i .. ":LeftButton"] = string.format(L.BIND_KIT_SLOT, i) end
_G["BINDING_NAME_CLICK CampfireBuddyFireKit:LeftButton"] = L.BIND_FIRE
_G["BINDING_NAME_CLICK CampfireBuddyWeaponMain:LeftButton"] = L.BIND_WEAPON_MAIN
_G["BINDING_NAME_CLICK CampfireBuddyWeaponOff:LeftButton"] = L.BIND_WEAPON_OFF
_G["BINDING_NAME_CLICK CampfireBuddySleepingBag:LeftButton"] = L.BIND_SLEEPING_BAG
for i = 1, 3 do _G["BINDING_NAME_CLICK CampfireBuddySupply" .. i .. ":LeftButton"] = string.format(L.BIND_SUPPLY, i) end
