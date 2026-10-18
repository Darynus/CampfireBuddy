-- Leiste: klein und verschiebbar. Je verfolgtem Buff eine Zeile mit Icon, Name, Restzeit und
-- Balken. Ohne Buff "No camp buff", am Lagerfeuer "Campfire nearby" (Knöpfe dafür im Camp Kit).
-- Fehlt der Essens-Buff, eine eigene Zeile "No food buff".
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba

local B = {}
ns.Leiste = B

local BREITE, ZEILE, RAND = 230, 34, 4
local MAX_ZEILEN = 4
local WARNFARBE = { 0.96, 0.77, 0.32, 1 }

local function setzen(schrift, text)
  if schrift.zuletzt ~= text then
    schrift.zuletzt = text
    schrift:SetText(text)
  end
end

-- Position speichern und setzen, immer über die linke obere Ecke. So wächst die Leiste nach unten,
-- wenn Zeilen dazukommen, egal wo sie auf dem Bildschirm steht.
function B.Merken(f)
  local links, oben = f:GetLeft(), f:GetTop()
  if not (links and oben) then return nil end
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", links, oben)
  return { punkt = "TOPLEFT", relativ = "BOTTOMLEFT", x = links, y = oben }
end

function B.Position(f, pos, ...)
  f:ClearAllPoints()
  if pos and pos.punkt then
    f:SetPoint(pos.punkt, UIParent, pos.relativ or pos.punkt, pos.x, pos.y)
  else
    f:SetPoint(...)
  end
end

local function zeileBauen(f, i)
  local z = CreateFrame("Frame", nil, f)
  z:SetSize(BREITE - 2 * RAND, ZEILE)
  z:SetPoint("TOPLEFT", RAND, -RAND - (i - 1) * ZEILE)
  z.icon = z:CreateTexture(nil, "ARTWORK")
  z.icon:SetSize(26, 26)
  z.icon:SetPoint("LEFT", 4, 0)
  z.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  z.name = S.schrift(z, "GameFontHighlightSmall", F.text)
  z.name:SetPoint("TOPLEFT", 38, -5)
  z.name:SetWidth(BREITE - 2 * RAND - 38 - 70)
  z.name:SetJustifyH("LEFT")
  z.name:SetWordWrap(false)
  z.zeit = S.schrift(z, "GameFontHighlightSmall", F.text)
  z.zeit:SetPoint("TOPRIGHT", -6, -5)
  z.zeit:SetWidth(64)
  z.zeit:SetJustifyH("RIGHT")
  z.zeit:SetWordWrap(false)
  z.balken = S.balken(z, BREITE - 2 * RAND - 44, 6)
  z.balken:SetPoint("TOPLEFT", 38, -21)
  return z
end

function B:Bauen()
  local f = S.kasten(UIParent, "Button", F.grund, F.rand)
  self.rahmen = f
  f:SetSize(BREITE, ZEILE + 2 * RAND)
  B.Position(f, ns.db.leiste, "TOP", 0, -140)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("RightButtonUp")
  f:SetScript("OnDragStart", function(self) if not ns.db.gesperrt then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    ns.db.leiste = B.Merken(self) or ns.db.leiste
  end)
  f:SetScript("OnClick", function() ns.Fenster:Umschalten() end)
  S.tooltip(f, L.ADDON_NAME, L.BAR_TOOLTIP_HINT)
  S.schatten(f)
  local streifen = f:CreateTexture(nil, "ARTWORK")
  streifen:SetPoint("TOPLEFT", 1, -1)
  streifen:SetPoint("BOTTOMLEFT", 1, 1)
  streifen:SetWidth(2)
  streifen:SetColorTexture(rgba(F.akzent))

  self.zeilen = {}
  for i = 1, MAX_ZEILEN do self.zeilen[i] = zeileBauen(f, i) end

  -- Zeile ohne Buff oder am Feuer
  local leer = CreateFrame("Frame", nil, f)
  self.leer = leer
  leer:SetSize(BREITE - 2 * RAND, ZEILE)
  leer.icon = leer:CreateTexture(nil, "ARTWORK")
  leer.icon:SetSize(26, 26)
  leer.icon:SetPoint("LEFT", 4, 0)
  leer.icon:SetTexture(S.LAGER)
  leer.titel = S.schrift(leer, "GameFontHighlightSmall", F.leise)
  leer.titel:SetPoint("TOPLEFT", 38, -5)
  leer.text = S.schrift(leer, "GameFontHighlightSmall", F.akzent)
  leer.text:SetPoint("TOPLEFT", 38, -19)
  leer.text:SetWidth(BREITE - 2 * RAND - 44)
  leer.text:SetJustifyH("LEFT")
  leer.text:SetWordWrap(false)
  -- Dezenter Puls, solange kein Lager-Buff aktiv ist: weicher Schimmer, der langsam an- und abschwillt
  leer.glanz = leer:CreateTexture(nil, "BACKGROUND")
  leer.glanz:SetAllPoints()
  leer.glanz:SetColorTexture(F.akzent[1], F.akzent[2], F.akzent[3], 0.22)
  leer.glanz:SetAlpha(0)
  leer.puls = S.pulsieren(leer.glanz, 0.1, 1, 1.4)
  -- Lagerplatz gefunden (am Feuer, Buff fehlt oder läuft bald ab): warmes, schnelles Flackern
  -- statt des ruhigen Pulses, das Feuer-Symbol flackert mit
  leer.feuerGlanz = leer:CreateTexture(nil, "BACKGROUND")
  leer.feuerGlanz:SetAllPoints()
  leer.feuerGlanz:SetColorTexture(1, 0.78, 0.25, 0.32)
  leer.feuerGlanz:SetAlpha(0)
  leer.feuerPuls = S.pulsieren(leer.feuerGlanz, 0.25, 1, 0.45)
  leer.flackern = S.pulsieren(leer.icon, 0.65, 1, 0.18)

  -- Feuerschein um die ganze Leiste, solange man an einem möglichen Lagerplatz steht
  local halo = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  halo:SetPoint("TOPLEFT", -7, 7)
  halo:SetPoint("BOTTOMRIGHT", 7, -7)
  halo:SetColorTexture(1, 0.6, 0.15, 0.55)
  halo:SetAlpha(0)
  self.halo = halo
  self.haloPuls = S.pulsieren(halo, 0.2, 0.9, 0.7)

  -- Zeile, wenn der Essens-Buff fehlt
  local essen = CreateFrame("Frame", nil, f)
  self.essen = essen
  essen:SetSize(BREITE - 2 * RAND, ZEILE)
  essen.icon = essen:CreateTexture(nil, "ARTWORK")
  essen.icon:SetSize(26, 26)
  essen.icon:SetPoint("LEFT", 4, 0)
  essen.icon:SetTexture(ns.ESSEN_TEXTUR)
  essen.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  essen.icon:SetDesaturated(true)
  essen.titel = S.schrift(essen, "GameFontHighlightSmall", WARNFARBE)
  essen.titel:SetPoint("TOPLEFT", 38, -5)
  essen.titel:SetText(L.NO_FOOD_BUFF)
  essen.text = S.schrift(essen, "GameFontHighlightSmall", F.leise)
  essen.text:SetPoint("TOPLEFT", 38, -19)
  essen.text:SetWidth(BREITE - 2 * RAND - 44)
  essen.text:SetJustifyH("LEFT")
  essen.text:SetWordWrap(false)
  essen.text:SetText(L.FOOD_HINT)
  -- Fehlt das Essen: Schimmer in der Warnfarbe, der an- und abschwillt (Patricks Wunsch: soll
  -- mehr auffallen)
  essen.glanz = essen:CreateTexture(nil, "BACKGROUND")
  essen.glanz:SetAllPoints()
  essen.glanz:SetColorTexture(WARNFARBE[1], WARNFARBE[2], WARNFARBE[3], 0.24)
  essen.glanz:SetAlpha(0)
  essen.puls = S.pulsieren(essen.glanz, 0.1, 1, 1.1)

  -- Restzeit zweimal pro Sekunde, nur solange die Leiste sichtbar ist
  local warten = 0
  f:SetScript("OnUpdate", function(_, dt)
    warten = warten + dt
    if warten < 0.5 then return end
    warten = 0
    B:Aktualisieren()
  end)
end

-- Soll die Leiste gerade zu sehen sein?
function B:Gewollt()
  if not ns.db.leisteZeigen then return false end
  if not ns.db.nurMitBuff then return true end
  return #ns.Buffs:Liste() > 0 or ns.Buffs.amFeuer
end

function B:Aktualisieren()
  if not self.rahmen then return end
  local zeigen = self:Gewollt()
  if self.rahmen:IsShown() ~= zeigen then self.rahmen:SetShown(zeigen) end
  if not zeigen then return end

  local liste = ns.Buffs:Liste()
  local warnen = (ns.db.warnenMinuten or 0) * 60
  local n = math.min(#liste, MAX_ZEILEN)
  for i, z in ipairs(self.zeilen) do
    local a = liste[i]
    z:SetShown(a ~= nil and i <= n)
    if a then
      local rest = ns.Buffs.Rest(a)
      z.icon:SetTexture(a.icon or S.LAGER)
      setzen(z.name, a.name or string.format(L.SPELL_ID, a.id))
      if rest then
        setzen(z.zeit, ns.dauerText(rest))
        local knapp = warnen > 0 and rest <= warnen
        z.zeit:SetTextColor(rgba(knapp and WARNFARBE or F.text))
        z.balken:Setzen((a.dauer or 0) > 0 and rest / a.dauer or 1, 0)
      else
        setzen(z.zeit, L.NO_TIMER)
        z.zeit:SetTextColor(rgba(F.leise))
        z.balken:Setzen(1, 0)
      end
    end
  end

  -- Zusatzzeile: kein Lager-Buff, oder am Feuer und der Buff läuft bald aus
  local lager = ns.Buffs:Lager()
  local lagerRest = ns.Buffs.Rest(lager)
  local amFeuer = ns.Buffs.amFeuer
  local brauchtLager = not lager or (lagerRest ~= nil and lagerRest < 600)
  local leerZeigen = n == 0 or (amFeuer and brauchtLager)
  local lagerplatz = amFeuer and brauchtLager
  self.leer:SetShown(leerZeigen)
  -- Feuerschein: an bei einem möglichen Lagerplatz, beim Ankommen einmal kräftig aufblitzen
  if lagerplatz and not self.warLagerplatz then self:Aufblitzen() end
  self.warLagerplatz = lagerplatz
  S.puls(self.haloPuls, lagerplatz)
  if not lagerplatz then self.halo:SetAlpha(0) end
  S.puls(self.leer.feuerPuls, leerZeigen and lagerplatz)
  S.puls(self.leer.flackern, leerZeigen and lagerplatz)
  if not (leerZeigen and lagerplatz) then self.leer.icon:SetAlpha(1) end
  if not leerZeigen then S.puls(self.leer.puls, false) end
  if leerZeigen then
    self.leer:ClearAllPoints()
    self.leer:SetPoint("TOPLEFT", RAND, -RAND - n * ZEILE)
    self.leer.icon:SetShown(n == 0)
    self.leer.icon:SetDesaturated(not amFeuer)
    if lagerplatz then
      setzen(self.leer.titel, L.CAMP_SPOT)
      self.leer.titel:SetTextColor(1, 0.85, 0.35, 1)
      setzen(self.leer.text, L.SIT_HINT)
    else
      setzen(self.leer.titel, n == 0 and L.NO_CAMP_BUFF or L.CAMPFIRE_NEARBY)
      self.leer.titel:SetTextColor(rgba(lager and F.leise or F.akzent))
      setzen(self.leer.text, "")
    end
    -- ruhiger Puls nur ohne Feuer in der Nähe, am Feuer das Flackern
    S.puls(self.leer.puls, not lager and not lagerplatz)
  end

  local essenZeigen = ns.db.essenErinnern and ns.Buffs.gelesen and not ns.Buffs:Essen()
  self.essen:SetShown(essenZeigen and true or false)
  -- Well Fed ohne Erfahrungsbonus (Bobbing Apple): sagen, dass gekochtes Essen mehr bringt
  if essenZeigen then
    setzen(self.essen.titel, ns.Buffs:EssenOhneXp() and L.FOOD_NO_XP or L.NO_FOOD_BUFF)
  end
  S.puls(self.essen.puls, essenZeigen and true or false)
  local zeilen = n + (leerZeigen and 1 or 0)
  if essenZeigen then
    self.essen:ClearAllPoints()
    self.essen:SetPoint("TOPLEFT", RAND, -RAND - zeilen * ZEILE)
    zeilen = zeilen + 1
  end
  self.rahmen:SetHeight(zeilen * ZEILE + 2 * RAND)
end

-- Einmal kräftig aufblitzen, wenn man an einen möglichen Lagerplatz kommt
function B:Aufblitzen()
  if not self.blitz then
    self.blitz = S.pulsieren(self.halo, 1, 0.3, 0.35)
    if self.blitz then self.blitz:SetLooping("NONE") end
  end
  if self.blitz then
    self.blitz:Stop()
    self.blitz:Play()
  end
end

function B:Sichtbarkeit()
  if not self.rahmen then return end
  self:Aktualisieren()
end

ns.beimAktualisieren(function() B:Aktualisieren() end)
ns.beimStart(function()
  B:Bauen()
  B:Aktualisieren()
end)
