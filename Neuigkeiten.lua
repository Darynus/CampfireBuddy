-- Neuigkeiten: Nach einem Update zeigt Campfire Buddy einmal ein kleines Fenster mit dem, was neu ist
-- (Patricks Wunsch, 13. Nov). Nicht nach einer frischen Installation, nicht im Kampf, abschaltbar.
-- Jederzeit wieder mit /campfire news. Die Texte stehen in Locale.lua (L.NEWS, neueste Version zuerst).
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F = S.F

local N = {}
ns.Neuigkeiten = N

local BREITE, RAND = 430, 18
local NAME = "CampfireBuddyNews"

-- Versionen wie "1.2.0" vergleichen: ist a neuer als b?
local function zahlen(v)
  local t = {}
  for z in string.gmatch(tostring(v or ""), "%d+") do table.insert(t, tonumber(z)) end
  return t
end

function N.Neuer(a, b)
  local x, y = zahlen(a), zahlen(b)
  for i = 1, math.max(#x, #y) do
    if (x[i] or 0) ~= (y[i] or 0) then return (x[i] or 0) > (y[i] or 0) end
  end
  return false
end

-- Was ist neu seit der Version seit? Ohne seit nur der neueste Eintrag. Höchstens drei Versionen,
-- nie eine, die neuer ist als die installierte.
function N.Eintraege(seit)
  local t = {}
  for _, e in ipairs(L.NEWS) do
    local passt = not N.Neuer(e.version, ns.VERSION) and (seit == nil or N.Neuer(e.version, seit))
    if passt and #t < 3 and not (seit == nil and #t == 1) then table.insert(t, e) end
  end
  return t
end

function N:Bauen()
  if self.rahmen then return end
  local r = S.vorlage("Frame", UIParent, "PortraitFrameTemplate", NAME)
  self.echt = r ~= nil and r.SetTitle ~= nil
  if not self.echt then
    r = S.kasten(UIParent, "Frame", F.grund, F.rand, NAME)
    S.schatten(r)
  end
  self.rahmen = r
  r:SetSize(BREITE, 300)
  r:SetPoint("CENTER", 0, 80)
  r:SetFrameStrata("DIALOG")
  r:SetToplevel(true)
  r:SetClampedToScreen(true)
  r:EnableMouse(true)
  r:SetMovable(true)
  r:RegisterForDrag("LeftButton")
  r:SetScript("OnDragStart", function(self) self:StartMoving() end)
  r:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  if UISpecialFrames then table.insert(UISpecialFrames, NAME) end
  local oben = -16
  if self.echt then
    pcall(r.SetTitle, r, L.ADDON_NAME)
    if r.SetPortraitToAsset then pcall(r.SetPortraitToAsset, r, S.MARKE[1]) end
    local innen = S.vorlage("Frame", r, "InsetFrameTemplate")
    if innen then
      innen:SetFrameLevel((r:GetFrameLevel() or 1) + 1)
      innen:SetPoint("TOPLEFT", 4, -60)
      innen:SetPoint("BOTTOMRIGHT", -6, 4)
    end
    oben = -72
  else
    local zu = S.zeichenKnopf(r, "x", function() r:Hide() end)
    zu:SetPoint("TOPRIGHT", -8, -8)
  end
  self.oben = oben
  local inhalt = CreateFrame("Frame", nil, r)
  inhalt:SetPoint("TOPLEFT", RAND, oben)
  inhalt:SetPoint("BOTTOMRIGHT", -RAND, 14)
  if self.echt then inhalt:SetFrameLevel((r:GetFrameLevel() or 1) + 4) end
  self.titel = S.schrift(inhalt, "GameFontNormalLarge", F.akzent)
  self.titel:SetPoint("TOPLEFT", 0, 0)
  self.text = S.absatz(inhalt, BREITE - 2 * RAND, F.text, "GameFontHighlight")
  self.text:SetPoint("TOPLEFT", 0, -28)
  self.text:SetSpacing(3)
  self.haken = S.haken(inhalt, 250, L.NEWS_AGAIN, L.NEWS_AGAIN_HELP, function(h, an)
    ns.db.neuigkeitenZeigen = an
    h:Setzen(an)
  end)
  self.haken:SetPoint("BOTTOMLEFT", 0, 2)
  self.ok = S.textKnopf(inhalt, L.NEWS_OK, 110, function() r:Hide() end)
  self.ok:SetPoint("BOTTOMRIGHT", 0, 0)
  r:Hide()
end

-- seit: zuletzt gesehene Version (nil: nur das Neueste)
function N:Zeigen(seit)
  if not ns.db then return end
  self:Bauen()
  local eintraege = N.Eintraege(seit)
  if #eintraege == 0 then eintraege = N.Eintraege(nil) end
  if #eintraege == 0 then return end
  local zeilen = {}
  for i, e in ipairs(eintraege) do
    if #eintraege > 1 then
      table.insert(zeilen, (i > 1 and "\n" or "") .. "|cffffd100" .. string.format(L.NEWS_VERSION, e.version) .. "|r")
    end
    for _, z in ipairs(e.zeilen) do table.insert(zeilen, "\226\128\162  " .. z) end
  end
  self.titel:SetText(string.format(L.NEWS_TITLE, eintraege[1].version))
  self.text:SetText(table.concat(zeilen, "\n"))
  self.haken:Setzen(ns.db.neuigkeitenZeigen)
  local hoehe = self.text:GetStringHeight() or 120
  self.rahmen:SetHeight(math.min(600, math.max(220, -self.oben + 28 + hoehe + 56)))
  self.rahmen:Show()
end

function N:Umschalten()
  if self.rahmen and self.rahmen:IsShown() then self.rahmen:Hide() else self:Zeigen() end
end

-- Nach dem Einloggen: Ist die installierte Version neuer als die zuletzt gesehene? ns.bestehend
-- sagt, ob es die gespeicherten Einstellungen schon vor diesem Start gab (sonst frisch installiert).
local function pruefen()
  local alt = ns.db.zuletztVersion
  ns.db.zuletztVersion = ns.VERSION
  if alt == nil and not ns.bestehend then return end
  if alt ~= nil and not N.Neuer(ns.VERSION, alt) then return end
  if not ns.db.neuigkeitenZeigen or #N.Eintraege(alt) == 0 then return end
  local function zeigen()
    if InCombatLockdown and InCombatLockdown() then
      N.wartet = { seit = alt }
      return
    end
    N:Zeigen(alt)
  end
  if C_Timer and C_Timer.After then C_Timer.After(5, zeigen) else zeigen() end
end

ns.beimStart(pruefen)
ns.ereignis("PLAYER_REGEN_ENABLED", function()
  local w = N.wartet
  if not w then return end
  N.wartet = nil
  N:Zeigen(w.seit)
end)
