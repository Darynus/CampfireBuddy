-- Lagerfeuer-Angeln: Der Schwimmer treibt auf dem Teich. Taucht er ab, schnell klicken.
-- Je seltener der Fisch, desto kürzer das Zeitfenster. Jeder Fang kommt ins Fangbuch, das sich
-- über alle Abende füllt (CampfireBuddyDB.fangbuch). Zu früh geklickt: Der Fisch erschrickt.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba
local SP = ns.Spiel

-- Fische: Name aus Locale, Seltenheit (Farbe), Punkte, Zeitfenster in Sekunden, Gewicht für den Zufall
local FISCHE = {
  { key = "elritze", name = L.FISH_1, q = 1, punkte = 1, fenster = 0.95, gewicht = 30 },
  { key = "sonnenbarsch", name = L.FISH_2, q = 1, punkte = 1, fenster = 0.9, gewicht = 26 },
  { key = "stiefel", name = L.FISH_3, q = 0, punkte = 0, fenster = 1.2, gewicht = 10 },
  { key = "schlammhecht", name = L.FISH_4, q = 1, punkte = 2, fenster = 0.8, gewicht = 18 },
  { key = "mondlachs", name = L.FISH_5, q = 2, punkte = 4, fenster = 0.62, gewicht = 9 },
  { key = "glutaal", name = L.FISH_6, q = 2, punkte = 5, fenster = 0.55, gewicht = 7 },
  { key = "mrglkarpfen", name = L.FISH_7, q = 3, punkte = 8, fenster = 0.45, gewicht = 4 },
  { key = "sternenfisch", name = L.FISH_8, q = 4, punkte = 15, fenster = 0.38, gewicht = 1.5 },
}
local QUALITAET = { [0] = { 0.6, 0.6, 0.6, 1 }, { 1, 1, 1, 1 }, { 0.2, 1, 0.2, 1 }, { 0.3, 0.55, 1, 1 }, { 0.75, 0.4, 1, 1 } }

local A = { key = "angeln", name = L.GAME_FISHING, info = L.GAME_FISHING_INFO,
  icon = "Interface\\Icons\\INV_Misc_2H_FishingPole_B_01", dauer = 60 }

local function ziehen()
  local summe = 0
  for _, f in ipairs(FISCHE) do summe = summe + f.gewicht end
  local w = math.random() * summe
  for _, f in ipairs(FISCHE) do
    w = w - f.gewicht
    if w <= 0 then return f end
  end
  return FISCHE[1]
end

function A:Bauen(r)
  local teich = S.kreis(r, 220, 110, { 0.08, 0.22, 0.35, 1 }, "BACKGROUND")
  teich:SetPoint("CENTER", 0, -10)
  self.glanz = S.kreis(r, 160, 60, { 0.3, 0.55, 0.8, 0.25 }, "BORDER", true)
  self.glanz:SetPoint("CENTER", -20, 0)
  self.ring = S.kreis(r, 30, 14, { 0.7, 0.85, 1, 0.5 }, "ARTWORK", true)
  self.ring:Hide()
  self.schwimmer = CreateFrame("Button", nil, r)
  self.schwimmer:SetSize(26, 26)
  self.schwimmer.rot = S.kreis(self.schwimmer, 14, 14, { 0.9, 0.15, 0.1, 1 }, "ARTWORK")
  self.schwimmer.rot:SetPoint("BOTTOM", 0, 10)
  self.schwimmer.weiss = S.kreis(self.schwimmer, 14, 9, { 1, 1, 1, 1 }, "ARTWORK")
  self.schwimmer.weiss:SetPoint("BOTTOM", 0, 5)
  self.schwimmer:SetScript("OnMouseDown", function() A:Klick() end)
  local ganz = CreateFrame("Button", nil, r)   -- Klick irgendwo auf den Teich zählt auch
  ganz:SetAllPoints()
  ganz:SetScript("OnMouseDown", function() A:Klick() end)
  local basis = (r.GetFrameLevel and r:GetFrameLevel()) or 1
  ganz:SetFrameLevel(basis + 1)
  self.schwimmer:SetFrameLevel(basis + 3)
  self.text = S.schrift(r, "GameFontNormal", F.text)
  self.text:SetPoint("TOP", 0, -8)
  self.buch = S.schrift(r, "GameFontHighlightSmall", F.leise)
  self.buch:SetPoint("BOTTOMRIGHT", -8, 6)
end

function A:Buch()
  ns.db.fangbuch = ns.db.fangbuch or {}
  local arten = 0
  for _, f in ipairs(FISCHE) do if (ns.db.fangbuch[f.key] or 0) > 0 then arten = arten + 1 end end
  self.buch:SetText(string.format(L.FISH_BOOK, arten, #FISCHE))
end

function A:Auswerfen()
  self.phase = "warten"
  self.beissen = ns.jetzt() + SP.zufall(1.8, 5)
  self.x, self.y = SP.zufall(-60, 60), SP.zufall(-25, 10)
  self.text:SetText(L.FISH_WAIT)
  self.text:SetTextColor(rgba(F.leise))
  self.ring:Hide()
end

function A:Start()
  self:Buch()
  self:Auswerfen()
end

function A:Klick()
  if not (SP.laeuft and SP.aktiv == self) then return end
  if self.phase == "warten" then
    self.text:SetText(L.FISH_TOO_EARLY)
    ns.ton("minus")
    self.text:SetTextColor(rgba(F.fehler))
    self.phase, self.pauseBis = "pause", ns.jetzt() + 1
  elseif self.phase == "biss" then
    local f = self.fisch
    SP:Plus(f.punkte)
    ns.db.fangbuch = ns.db.fangbuch or {}
    local neu = (ns.db.fangbuch[f.key] or 0) == 0
    ns.db.fangbuch[f.key] = (ns.db.fangbuch[f.key] or 0) + 1
    self.text:SetText(string.format(neu and L.FISH_CAUGHT_NEW or L.FISH_CAUGHT, f.name))
    self.text:SetTextColor(rgba(QUALITAET[f.q]))
    SP:Ruf(L.FISH_QUIPS[f.key] or ("+" .. f.punkte), SP.BREITE / 2, -150, QUALITAET[f.q])
    self:Buch()
    self.phase, self.pauseBis = "pause", ns.jetzt() + 1.4
    ns.ton(f.q >= 3 and "muenze" or "plopp")
    if f.key == "mrglkarpfen" then ns.mrgl() end
  end
end

function A:Tick(_, jetzt)
  self.glanz:SetAlpha(0.6 + 0.3 * math.sin(jetzt * 1.3))
  local tauchen = 0
  if self.phase == "warten" and jetzt >= self.beissen then
    -- Manchmal klaut ein Murloc den Köder
    if math.random(1, 12) == 1 then
      self.text:SetText(SP.spruch(L.FISH_THIEF))
      self.text:SetTextColor(rgba(F.hinweis))
      SP:Ruf(L.FISH_THIEF_SHOUT, SP.BREITE / 2 + self.x, -80, { 0.4, 0.84, 0.56, 1 })
      ns.mrgl()
      self.phase, self.pauseBis = "pause", jetzt + 1.6
      return
    end
    self.fisch, self.phase = ziehen(), "biss"
    self.weg = jetzt + self.fisch.fenster
    self.text:SetText(L.FISH_BITE)
    ns.ton("treffer")
    self.text:SetTextColor(rgba(F.akzent))
    self.ring:Show()
  elseif self.phase == "biss" then
    tauchen = -6
    self.ring:SetAlpha(math.max(0, (self.weg - jetzt) / self.fisch.fenster))
    if jetzt >= self.weg then
      self.text:SetText(L.FISH_GONE)
      self.text:SetTextColor(rgba(F.leise))
      self.phase, self.pauseBis = "pause", jetzt + 1
      self.ring:Hide()
    end
  elseif self.phase == "pause" and jetzt >= self.pauseBis then
    self:Auswerfen()
  end
  -- Schwimmer wippt sanft, beim Biss taucht er ab
  local wippen = math.sin(jetzt * 2.2) * 2 + tauchen
  self.schwimmer:ClearAllPoints()
  self.schwimmer:SetPoint("CENTER", self.x, self.y + wippen)
  self.ring:ClearAllPoints()
  self.ring:SetPoint("CENTER", self.schwimmer, "BOTTOM", 0, 6)
end

A.FISCHE = FISCHE
SP.Registrieren(A)
