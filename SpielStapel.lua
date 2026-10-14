-- Holz stapeln: Ein Scheit schwingt hin und her, ein Klick lässt ihn fallen. Was übersteht,
-- wird abgesägt, der nächste Scheit ist so breit wie der Rest. Genau getroffen: Scheit bleibt
-- breit und zählt doppelt. Daneben: Der Stapel fällt um.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba
local SP = ns.Spiel

local HOCH, SICHTBAR = 14, 9
local HOLZ = { { 0.55, 0.33, 0.17 }, { 0.62, 0.38, 0.2 }, { 0.48, 0.29, 0.15 } }

local ST = { key = "stapel", name = L.GAME_STACK, info = L.GAME_STACK_INFO,
  icon = "Interface\\Icons\\INV_TradeSkillItem_01", dauer = 90 }

function ST:Bauen(r)
  self.r = r
  self.feuer = r:CreateTexture(nil, "ARTWORK")
  self.feuer:SetSize(36, 36)
  self.feuer:SetPoint("BOTTOMRIGHT", -8, 4)
  self.feuer:SetTexture(S.FLAMME)
  self.scheite = {}
  for i = 1, SICHTBAR + 1 do
    local t = r:CreateTexture(nil, "ARTWORK")
    t:SetHeight(HOCH - 2)
    t:SetTexture(S.WEISS)
    t:Hide()
    self.scheite[i] = t
  end
  self.schwinger = r:CreateTexture(nil, "OVERLAY")
  self.schwinger:SetHeight(HOCH - 2)
  self.schwinger:SetTexture(S.WEISS)
  self.text = S.schrift(r, "GameFontNormal", F.text)
  self.text:SetPoint("TOP", 0, -6)
  local knopf = CreateFrame("Button", nil, r)
  knopf:SetAllPoints()
  knopf:SetScript("OnMouseDown", function() ST:Fallen() end)
end

local function zeichnen(t, x, y, breite, nr)
  local h = HOLZ[(nr % #HOLZ) + 1]
  t:SetVertexColor(h[1], h[2], h[3], 1)
  t:SetWidth(math.max(1, breite))
  t:ClearAllPoints()
  t:SetPoint("BOTTOMLEFT", x, y)
  t:Show()
end

function ST:Neu()
  local oben = self.stapel[#self.stapel]
  self.breite = oben.w
  self.x, self.richtung = 0, 1
  self.tempo = math.min(260, 90 + #self.stapel * 9)
end

function ST:Start()
  self.stapel = { { x = (SP.BREITE - 120) / 2, w = 120 } }
  self.text:SetText(L.STACK_HINT)
  self.text:SetTextColor(rgba(F.leise))
  self:Neu()
  self:Zeichnen()
end

function ST:Zeichnen()
  local n = #self.stapel
  local von = math.max(1, n - SICHTBAR + 1)
  for i, t in ipairs(self.scheite) do
    local s = self.stapel[von + i - 1]
    if s then zeichnen(t, s.x, 6 + (i - 1) * HOCH, s.w, von + i - 1) else t:Hide() end
  end
  self.ebene = 6 + (n - von + 1) * HOCH
end

function ST:Fallen()
  if not (SP.laeuft and SP.aktiv == self) then return end
  local oben = self.stapel[#self.stapel]
  local links, rechts = math.max(self.x, oben.x), math.min(self.x + self.breite, oben.x + oben.w)
  local rest = rechts - links
  if rest <= 2 then
    self.text:SetText(L.STACK_FALL)
    self.text:SetTextColor(rgba(F.fehler))
    SP:Ruf(L.STACK_TIMBER, SP.BREITE / 2, -90, { 0.94, 0.38, 0.35, 1 })
    ns.ton("umfallen")
    return SP:Fertig()
  end
  if math.abs(self.x - oben.x) <= 3 then
    table.insert(self.stapel, { x = oben.x, w = oben.w })
    SP:Plus(2)
    self.text:SetText(L.STACK_PERFECT)
    self.text:SetTextColor(rgba(F.erfolg))
    SP:Ruf(SP.spruch(L.STACK_PERFECT_LINES), oben.x + oben.w / 2, -(SP.HOEHE - self.ebene) - 10, { 1, 0.84, 0.25, 1 })
    ns.ton("treffer")
  else
    table.insert(self.stapel, { x = links, w = rest })
    SP:Plus(1)
    self.text:SetText("")
    ns.ton("plopp")
  end
  if #self.stapel % 5 == 1 and #self.stapel > 1 then
    SP:Ruf(string.format(SP.spruch(L.STACK_HEIGHT), #self.stapel - 1), SP.BREITE / 2, -50, { 0.4, 0.84, 0.56, 1 })
  end
  self:Neu()
  self:Zeichnen()
end

function ST:Tick(dt)
  self.x = self.x + self.richtung * self.tempo * dt
  if self.x <= 0 then self.x, self.richtung = 0, 1 end
  if self.x + self.breite >= SP.BREITE then self.x, self.richtung = SP.BREITE - self.breite, -1 end
  zeichnen(self.schwinger, self.x, math.min(SP.HOEHE - 40, self.ebene + 26), self.breite, #self.stapel)
end

SP.Registrieren(ST)
