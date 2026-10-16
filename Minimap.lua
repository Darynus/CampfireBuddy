-- Zugänge zum Hauptfenster: Minikarten-Knopf, Add-on-Menü an der Minikarte und
-- Esc > Options > AddOns. Ohne Fremdbibliothek. Vorlage: Pigeon Post, Duo und der Kern.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil

local M = {}
ns.Minimap = M

local function e() return ns.db end

local function position(knopf)
  local winkel = math.rad(e().minimapWinkel or 200)
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
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER")
  if icon.SetMask then pcall(icon.SetMask, icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
  self.icon = icon
  self.abzeichen = S.abzeichen(b, icon, 13)
  self:Symbol()
  local ring = b:CreateTexture(nil, "OVERLAY")
  ring:SetSize(53, 53)
  ring:SetPoint("TOPLEFT")
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  b:SetScript("OnClick", function(_, taste)
    if taste == "RightButton" then
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
      e().minimapWinkel = math.deg((math.atan2 or math.atan)(cy / skala - my, cx / skala - mx))
      position(self)
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  S.tooltip(b, L.ADDON_NAME, L.MINIMAP_TOOLTIP)
  position(b)
  self:Sichtbarkeit()
end

-- Bild im Knopf nach der Einstellung: Lagerfeuer (Standard), Murloc mit Abzeichen oder das
-- Symbol von Camp Benefits aus dem Spiel
function M:Symbol()
  if not self.icon then return end
  local wahl = e().minimapSymbol or "feuer"
  if wahl == "murloc" then
    S.markeSetzen(self.icon)
  elseif wahl == "lager" then
    self.icon:SetTexture(S.LAGER)
    self.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  else
    self.icon:SetTexture(S.SYMBOL)
    self.icon:SetTexCoord(0, 1, 0, 1)
  end
  self.abzeichen:SetShown(wahl == "murloc")
end

function M:Sichtbarkeit()
  if self.knopf then self.knopf:SetShown(e().minimapZeigen and true or false) end
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
  M:Bauen()
  M:OptionenEintragen()
end)
