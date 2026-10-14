-- Whack-a-Murloc: Köpfe tauchen kurz in sechs Löchern auf. Klick: ein Punkt, goldener Murloc drei.
-- Aber Vorsicht: Bomben (-3, BOOM) und rosa Murloc-Babys (-2) lieber nicht anklicken.
-- Je mehr Punkte, desto kürzer bleiben sie. Murlocs rufen beim Auftauchen und Treffen.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F = S.F
local SP = ns.Spiel

local KOPF = "Interface\\Icons\\INV_Misc_Head_Murloc_01"
local BOMBE = "Interface\\Icons\\INV_Misc_Bomb_02"
local LOCH, SPALTEN = 54, 3
local ARTEN = {
  { art = "murloc", gewicht = 70, wert = 1, bild = KOPF, farbe = { 1, 1, 1 } },
  { art = "gold", gewicht = 9, wert = 3, bild = KOPF, farbe = { 1, 0.84, 0.25 } },
  { art = "bombe", gewicht = 12, wert = -3, bild = BOMBE, farbe = { 1, 1, 1 } },
  { art = "baby", gewicht = 9, wert = -2, bild = KOPF, farbe = { 1, 0.62, 0.8 }, klein = true },
}
local ROT, GRUEN = { 0.94, 0.38, 0.35, 1 }, { 0.4, 0.84, 0.56, 1 }

local W = { key = "whack", name = L.GAME_WHACK, info = L.GAME_WHACK_INFO,
  icon = "Interface\\Icons\\INV_BabyMurloc3_Yellow", dauer = 30 }

local function ziehen()
  local summe = 0
  for _, a in ipairs(ARTEN) do summe = summe + a.gewicht end
  local w = math.random() * summe
  for _, a in ipairs(ARTEN) do
    w = w - a.gewicht
    if w <= 0 then return a end
  end
  return ARTEN[1]
end

function W:Bauen(r)
  self.loecher = {}
  local abstandX = (SP.BREITE - SPALTEN * LOCH) / (SPALTEN + 1)
  for i = 1, 6 do
    local reihe, spalte = math.floor((i - 1) / SPALTEN), (i - 1) % SPALTEN
    local b = CreateFrame("Button", nil, r)
    b:SetSize(LOCH, LOCH)
    b.mx = abstandX + spalte * (LOCH + abstandX) + LOCH / 2
    b.my = -22 - reihe * (LOCH + 30) - LOCH / 2
    b:SetPoint("CENTER", r, "TOPLEFT", b.mx, b.my)
    b.rand = S.kreis(b, LOCH + 10, LOCH * 0.5, { 0.30, 0.20, 0.11, 1 }, "BACKGROUND")
    b.rand:SetPoint("BOTTOM", 0, -8)
    b.loch = S.kreis(b, LOCH, LOCH * 0.42, { 0.02, 0.01, 0.02, 1 }, "BORDER")
    b.loch:SetPoint("BOTTOM", 0, -5)
    b.kopf = b:CreateTexture(nil, "ARTWORK")
    b.kopf:SetSize(LOCH - 12, LOCH - 12)
    b.kopf:SetPoint("BOTTOM", 0, 2)
    b.kopf:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.kopf:Hide()
    b:SetScript("OnClick", function(self) W:Treffer(self) end)
    self.loecher[i] = b
  end
end

function W:Start()
  self.naechster, self.serie = ns.jetzt() + 0.6, 0
  for _, b in ipairs(self.loecher) do b.bis = nil b.kopf:Hide() end
end

function W:Treffer(b)
  if not (SP.laeuft and SP.aktiv == self and b.bis) then return end
  local a = b.art
  SP:Plus(a.wert)
  b.bis = nil
  b.kopf:Hide()
  if a.art == "bombe" then
    self.serie = 0
    SP:Ruf(L.WHACK_BOOM, b.mx, b.my, ROT)
    ns.ton("boom")
  elseif a.art == "baby" then
    self.serie = 0
    SP:Ruf(SP.spruch(L.WHACK_BABY), b.mx, b.my, ROT)
    ns.ton("minus")
  else
    self.serie = self.serie + 1
    local text = "+" .. a.wert
    if self.serie > 0 and self.serie % 5 == 0 then text = SP.spruch(L.WHACK_STREAK) end
    SP:Ruf(text, b.mx, b.my, a.art == "gold" and { 1, 0.84, 0.25, 1 } or GRUEN)
    ns.ton(a.art == "gold" and "muenze" or (self.serie % 5 == 0 and "paar" or "treffer"))
    ns.mrgl(0.3)
  end
end

function W:Tick(_, jetzt)
  for _, b in ipairs(self.loecher) do
    if b.bis then
      -- Kopf taucht in 0,12 s auf und wieder ab
      local rest = b.bis - jetzt
      local auf = math.min(1, (jetzt - b.seit) / 0.12, rest / 0.12)
      b.kopf:SetHeight(math.max(1, b.hoehe * auf))
      if jetzt >= b.bis then
        b.bis = nil
        b.kopf:Hide()
        -- verpasster Murloc streckt die Zunge raus
        if b.art.wert > 0 and math.random(1, 4) == 1 then SP:Ruf(SP.spruch(L.WHACK_MISS), b.mx, b.my - 10, F.leise) end
      end
    end
  end
  if jetzt >= self.naechster then
    local frei = {}
    for _, b in ipairs(self.loecher) do if not b.bis then table.insert(frei, b) end end
    if #frei > 0 then
      local b = frei[math.random(1, #frei)]
      local a = ziehen()
      b.art = a
      b.kopf:SetTexture(a.bild)
      b.kopf:SetVertexColor(a.farbe[1], a.farbe[2], a.farbe[3])
      b.hoehe = a.klein and (LOCH - 22) or (LOCH - 12)
      b.kopf:SetWidth(b.hoehe)
      b.seit = jetzt
      b.bis = jetzt + math.max(0.55, 1.05 - (SP.punkte or 0) * 0.02)
      b.kopf:Show()
      if a.art == "murloc" and math.random(1, 6) == 1 then
        SP:Ruf(SP.spruch(L.WHACK_POP), b.mx, b.my + 34, F.text)
        ns.mrgl()
      end
    end
    self.naechster = jetzt + SP.zufall(0.45, 0.9)
  end
end

function W:Stop()
  for _, b in ipairs(self.loecher or {}) do b.bis = nil b.kopf:Hide() end
end

SP.Registrieren(W)
