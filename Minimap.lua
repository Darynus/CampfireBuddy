-- Zugänge zum Hauptfenster: Minikarten-Knopf, Add-on-Menü an der Minikarte und
-- Esc > Options > AddOns. Ohne Fremdbibliothek.
-- Aufbau genau wie bei Hop & Seek und Pigeon Post, deren Knöpfe gehen (Patrick, 18. Okt): Ebene
-- und Stufe nur beim Bauen setzen und danach nie wieder anfassen. Die Versuche vom 17. und 18. Okt
-- (Ebene nach dem Login neu setzen und festnageln, Ausweichen, Selbstprüfung unter der Maus) sind
-- wieder draußen. Der Knopf blieb damit bei Patrick nicht klickbar.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil

local M = {}
ns.Minimap = M

local STANDARD_WINKEL = 290

local function position(knopf)
  local winkel = math.rad(ns.db.minimapWinkel or STANDARD_WINKEL)
  local radius = (Minimap:GetWidth() or 140) / 2 + 5
  knopf:ClearAllPoints()
  knopf:SetPoint("CENTER", Minimap, "CENTER", math.cos(winkel) * radius, math.sin(winkel) * radius)
end

function M:Bauen()
  if self.knopf or not Minimap then return end
  local b = CreateFrame("Button", nil, Minimap)
  self.knopf = b
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")

  local grund = b:CreateTexture(nil, "BACKGROUND")
  grund:SetSize(24, 24)
  grund:SetPoint("CENTER")
  grund:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  -- Ein festes Bild: der Murloc mit dem Lagerfeuer-Abzeichen, wie Logo und Fenster
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER")
  S.markeSetzen(icon)
  if icon.SetMask then pcall(icon.SetMask, icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
  self.icon = icon
  self.abzeichen = S.abzeichen(b, icon, 13)
  local ring = b:CreateTexture(nil, "OVERLAY")
  ring:SetSize(53, 53)
  ring:SetPoint("TOPLEFT")
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  b:SetScript("OnClick", function(_, taste)
    if taste == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown() then
      ns.Spiel:Menue()
    elseif taste == "RightButton" then
      ns.db.leisteZeigen = not ns.db.leisteZeigen
      ns.Leiste:Sichtbarkeit()
      ns.aktualisieren()
    else
      ns.Fenster:Umschalten()
    end
  end)
  -- Ziehen: Winkel aus der Mausposition relativ zur Minikarte
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local skala = Minimap:GetEffectiveScale()
      ns.db.minimapWinkel = math.deg((math.atan2 or math.atan)(cy / skala - my, cx / skala - mx))
      position(self)
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  S.tooltip(b, L.ADDON_NAME, L.MINIMAP_TOOLTIP)
  position(b)
  self:Sichtbarkeit()
end

-- /campfire minimap: Knopf wieder zeigen, an seinen Standardplatz
function M:Zurueck()
  ns.db.minimapZeigen = true
  ns.db.minimapWinkel = STANDARD_WINKEL
  if not self.knopf then return self:Bauen() end
  position(self.knopf)
  self:Sichtbarkeit()
end

function M:Sichtbarkeit()
  if self.knopf then self.knopf:SetShown(ns.db.minimapZeigen and true or false) end
end

-- Eintrag unter Esc > Options > AddOns, mit Knopf zum Hauptfenster
function M:OptionenEintragen()
  if self.optionen or not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
  local f = CreateFrame("Frame")
  self.optionen = f
  local titel = S.schrift(f, "GameFontNormalLarge", S.F.text)
  titel:SetPoint("TOPLEFT", 16, -16)
  titel:SetText(ns.TITEL .. "  |cff8e9db8v" .. ns.VERSION .. "  " .. L.BY_AUTHOR .. "|r")
  local text = S.absatz(f, 520, S.F.leise, "GameFontHighlight")
  text:SetPoint("TOPLEFT", titel, "BOTTOMLEFT", 0, -10)
  text:SetText(L.OPTIONS_PAGE_TEXT)
  local knopf = S.knopf(f, 200, 28)
  knopf:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -16)
  knopf:Aussehen(L.OPEN_WINDOW, S.F.akzent, true)
  knopf:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel.Hide then pcall(SettingsPanel.Hide, SettingsPanel) end
    ns.Fenster:Zeigen()
  end)
  local ok, kategorie = pcall(Settings.RegisterCanvasLayoutCategory, f, L.ADDON_NAME)
  if ok and kategorie then pcall(Settings.RegisterAddOnCategory, kategorie) end
end

-- Add-on-Menü an der Minikarte (## AddonCompartmentFunc in der TOC). Muss global sein.
function CampfireBuddy_OnAddonCompartmentClick()
  if ns.db then ns.Fenster:Umschalten() end
end

ns.beimStart(function()
  -- Reste früherer Versuche aus den Einstellungen räumen
  ns.db.minimapSymbol, ns.db.minimapPlatz, ns.db.minimapVerdeckt = nil, nil, nil
  M:Bauen()
  M:OptionenEintragen()
end)
