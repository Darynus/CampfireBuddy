-- Marshmallow rösten: Maustaste über dem Feuer gedrückt halten, der Marshmallow bräunt.
-- Im goldenen Moment loslassen. Jeder Marshmallow bräunt ein wenig anders schnell, ab und zu
-- lodert das Feuer auf. Verbrannt gibt es nichts, nur Rauch.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba
local SP = ns.Spiel

local FARBEN = {
  { 0.98, 0.97, 0.93 }, -- roh
  { 0.98, 0.82, 0.48 }, -- golden
  { 0.62, 0.36, 0.16 }, -- dunkel
  { 0.12, 0.08, 0.06 }, -- verbrannt
}
local GOLDEN, BREITE_GOLD = 0.5, 0.09   -- Ziel und halbe Breite des goldenen Bereichs

local M = { key = "marshmallow", name = L.GAME_MARSHMALLOW, info = L.GAME_MARSHMALLOW_INFO,
  icon = "Interface\\Icons\\INV_Misc_Food_124_Skewer", dauer = 45 }

-- Farbe passend zur Wertung: genau golden bei GOLDEN, dunkel bis 0,92, danach schwarz
local STUETZEN = { 0, GOLDEN, 0.92, 1 }
local function farbe(braeune)
  for i = 1, 3 do
    if braeune <= STUETZEN[i + 1] then
      return S.mischen(FARBEN[i], FARBEN[i + 1], (braeune - STUETZEN[i]) / (STUETZEN[i + 1] - STUETZEN[i]))
    end
  end
  return S.mischen(FARBEN[4], FARBEN[4], 0)
end

function M:Bauen(r)
  local mitte = SP.BREITE / 2
  self.feuer = r:CreateTexture(nil, "ARTWORK")
  self.feuer:SetSize(64, 64)
  self.feuer:SetPoint("BOTTOM", 0, 8)
  S.feuer(self.feuer)
  self.glut = S.glut(r, 130, 84, { 1, 0.5, 0.12, 1 }, "BACKGROUND")
  self.glut:SetPoint("BOTTOM", 0, 0)
  self.stock = r:CreateTexture(nil, "ARTWORK")
  self.stock:SetSize(150, 4)
  self.stock:SetPoint("CENTER", -30, 10)
  self.stock:SetColorTexture(0.45, 0.28, 0.14, 1)
  self.stock:SetRotation(math.rad(-12))
  self.marsh = S.kreis(r, 30, 26, { 1, 1, 1, 1 }, "OVERLAY")
  self.marsh:SetPoint("CENTER", 46, -6)
  -- Anzeige: Bräune mit goldenem Bereich
  self.leiste = S.balken(r, 200, 8)
  self.leiste:SetPoint("TOP", 0, -10)
  self.ziel = r:CreateTexture(nil, "OVERLAY")
  self.ziel:SetSize(200 * BREITE_GOLD * 2, 12)
  self.ziel:SetPoint("TOPLEFT", self.leiste, "TOPLEFT", 200 * (GOLDEN - BREITE_GOLD), 2)
  self.ziel:SetColorTexture(1, 0.84, 0.3, 0.35)
  self.text = S.schrift(r, "GameFontNormal", F.text)
  self.text:SetPoint("TOP", 0, -26)
  self.rauch = S.kreis(r, 40, 40, { 0.5, 0.5, 0.5, 0.6 }, "OVERLAY")
  self.rauch:SetPoint("CENTER", 46, 20)
  self.rauch:Hide()
  -- brennender Marshmallow: kleine Flammen darauf
  self.flammen = {}
  for i = 1, 3 do
    local fl = S.kreis(r, 12, 18, { 1, 0.55, 0.1, 1 }, "OVERLAY", true)
    fl:SetPoint("BOTTOM", self.marsh, "TOP", (i - 2) * 7, -8)
    fl:Hide()
    self.flammen[i] = fl
  end
  -- Ganze Fläche ist der Knopf: drücken = über das Feuer halten
  local knopf = CreateFrame("Button", nil, r)
  knopf:SetAllPoints()
  knopf:SetScript("OnMouseDown", function() M:Halten(true) end)
  knopf:SetScript("OnMouseUp", function() M:Halten(false) end)
  self.knopf = knopf
  self.mitte = mitte
end

function M:Neu()
  self.braeune, self.tempo, self.haelt = 0, SP.zufall(0.18, 0.32), false
  self.lodernBis = nil
  self.marsh:SetVertexColor(rgba(farbe(0)))
  self.marsh:SetAlpha(1)
  self.rauch:Hide()
  for _, fl in ipairs(self.flammen) do fl:Hide() end
  self.leiste:Setzen(0, 0)
  self.text:SetText(L.MARSH_HOLD)
  self.text:SetTextColor(rgba(F.text))
end

function M:Start()
  self.anzahl, self.pauseBis = 0, nil
  self:Neu()
end

-- Loslassen wertet: je näher am goldenen Ziel, desto mehr Punkte
function M:Halten(an)
  if not (SP.laeuft and SP.aktiv == self) or self.pauseBis then return end
  if an then
    self.haelt = true
    return
  end
  if not self.haelt then return end
  self.haelt = false
  if self.braeune < 0.05 then return end
  local abstand = math.abs(self.braeune - GOLDEN)
  local punkte, liste
  if self.braeune >= 0.92 then
    punkte, liste = 0, L.MARSH_BURNT_LINES
    for _, fl in ipairs(self.flammen) do fl:Show() end
  elseif abstand <= 0.03 then
    punkte, liste = 10, L.MARSH_PERFECT_LINES
  elseif abstand <= BREITE_GOLD then
    punkte, liste = 6, L.MARSH_GOOD_LINES
  elseif self.braeune < GOLDEN then
    punkte, liste = 2, L.MARSH_RAW_LINES
  else
    punkte, liste = 3, L.MARSH_DARK_LINES
  end
  SP:Plus(punkte)
  self.text:SetText(SP.spruch(liste) .. "  +" .. punkte)
  SP:Ruf("+" .. punkte, 200, -60)
  ns.ton(punkte >= 10 and "muenze" or (punkte == 0 and "minus" or "treffer"))
  self.text:SetTextColor(rgba(punkte >= 6 and F.erfolg or (punkte == 0 and F.fehler or F.hinweis)))
  self.anzahl = self.anzahl + 1
  self.pauseBis = ns.jetzt() + 1.2
end

function M:Tick(dt, jetzt)
  -- Feuer flackert, brennende Flammen tanzen
  self.glut:SetAlpha(0.6 + 0.3 * math.sin(jetzt * 9) * math.sin(jetzt * 3.7))
  for i, fl in ipairs(self.flammen) do fl:SetAlpha(0.6 + 0.4 * math.abs(math.sin(jetzt * 11 + i * 2))) end
  if self.pauseBis then
    if jetzt >= self.pauseBis then self.pauseBis = nil self:Neu() end
    return
  end
  if self.haelt then
    -- ab und zu lodert das Feuer auf: kurz doppelt so schnell
    if not self.lodernBis and math.random() < dt * 0.25 then
      self.lodernBis = jetzt + 0.6
      SP:Ruf(L.MARSH_FLARE, SP.BREITE / 2, -120, { 1, 0.55, 0.15, 1 })
      ns.ton("boom")
    end
    local faktor = (self.lodernBis and jetzt < self.lodernBis) and 2.2 or 1
    if self.lodernBis and jetzt >= self.lodernBis then self.lodernBis = nil end
    self.braeune = math.min(1, self.braeune + dt * self.tempo * faktor)
    self.marsh:SetVertexColor(rgba(farbe(self.braeune)))
    self.leiste:Setzen(self.braeune, 0)
    if self.braeune >= 1 then
      self.rauch:Show()
      self:Halten(false)
    end
  end
end

function M:Stop() self.haelt = false end

SP.Registrieren(M)
