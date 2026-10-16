-- Holz stapeln: Ein Scheit schwingt hin und her, ein Klick lässt ihn fallen. Was übersteht,
-- wird abgesägt, der nächste Scheit ist so breit wie der Rest. Genau getroffen: Scheit bleibt
-- breit und zählt doppelt. Daneben: Der Stapel fällt um.
--
-- Animation (nur Anzeige, die Wertung passiert sofort beim Klick): Der Scheit fällt mit
-- Schwerkraft auf den Stapel und federt beim Aufprall, Späne fliegen, Staub steigt auf. Das
-- abgesägte Stück kippt über die Kante und fällt sich drehend weg. Genau getroffen: kurzes
-- goldenes Aufleuchten. Daneben: Der ganze Scheit purzelt hinunter, danach ist das Spiel vorbei.
-- Gedreht wird mit einer Animationsgruppe (geht auch mit Atlas-Bildern), bewegt von Hand.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba
local SP = ns.Spiel

local HOCH, SICHTBAR = 14, 9
local HOLZ = { { 0.55, 0.33, 0.17 }, { 0.62, 0.38, 0.2 }, { 0.48, 0.29, 0.15 } }
-- Mit dem Holzscheit aus Blender nur leichte Unterschiede in der Helligkeit
local HELL = { { 1, 1, 1 }, { 1.0, 0.92, 0.86 }, { 0.88, 0.84, 0.8 } }
local SCHWERE = 1100        -- Pixel je Sekunde², so fällt alles
local FEDERN = 0.14         -- Sekunden, die der gelandete Scheit nachfedert
local SPAENE, STUECKE = 18, 4
local UMFALLEN_DAUER = 1.1  -- so lange purzelt der Scheit, bevor das Spiel endet

local ST = { key = "stapel", musik = "arcade", name = L.GAME_STACK, info = L.GAME_STACK_INFO,
  icon = "Interface\\Icons\\INV_TradeSkillItem_01", dauer = 90 }

local function scheitBild(t)
  if not S.atlas(t, "scheit") then t:SetTexture(S.WEISS) end
end

local function farbe(nr)
  return ((S.ATLAS and S.ATLAS.scheit) and HELL or HOLZ)[(nr % #HOLZ) + 1]
end

-- Drehung über eine Animationsgruppe, falls es sie gibt
local function drehbar(t)
  if not t.CreateAnimationGroup then return end
  local ok, ag = pcall(t.CreateAnimationGroup, t)
  if not (ok and ag and ag.CreateAnimation) then return end
  local ok2, dreh = pcall(ag.CreateAnimation, ag, "Rotation")
  if not (ok2 and dreh) then return end
  if dreh.SetOrigin then pcall(dreh.SetOrigin, dreh, "CENTER", 0, 0) end
  t.ag, t.dreh = ag, dreh
end

local function drehen(t, grad, sekunden)
  if not t.ag then return end
  pcall(t.ag.Stop, t.ag)
  pcall(t.dreh.SetDegrees, t.dreh, grad)
  pcall(t.dreh.SetDuration, t.dreh, sekunden)
  pcall(t.ag.Play, t.ag)
end

function ST:Bauen(r)
  self.r = r
  self.feuer = r:CreateTexture(nil, "ARTWORK")
  self.feuer:SetSize(36, 36)
  self.feuer:SetPoint("BOTTOMRIGHT", -8, 4)
  S.feuer(self.feuer)
  self.scheite = {}
  for i = 1, SICHTBAR + 1 do
    local t = r:CreateTexture(nil, "ARTWORK")
    t:SetHeight(HOCH - 2)
    scheitBild(t)
    t:Hide()
    self.scheite[i] = t
  end
  self.schwinger = r:CreateTexture(nil, "OVERLAY")
  self.schwinger:SetHeight(HOCH - 2)
  scheitBild(self.schwinger)
  -- Fallende Stücke, Späne, Staub und das goldene Aufleuchten
  self.stuecke = {}
  for i = 1, STUECKE do
    local t = r:CreateTexture(nil, "OVERLAY", nil, 1)
    t:SetHeight(HOCH - 2)
    scheitBild(t)
    drehbar(t)
    t:Hide()
    self.stuecke[i] = { t = t }
  end
  self.spaene = {}
  for i = 1, SPAENE do
    local t = r:CreateTexture(nil, "OVERLAY", nil, 2)
    t:SetTexture(S.WEISS)
    t:Hide()
    self.spaene[i] = { t = t }
  end
  self.staub = {}
  for i = 1, 2 do
    local t = r:CreateTexture(nil, "OVERLAY")
    if not S.atlas(t, "schein") then t:SetTexture(S.WEISS) end
    t:SetVertexColor(0.75, 0.62, 0.45)
    t:Hide()
    self.staub[i] = { t = t }
  end
  self.glanz = r:CreateTexture(nil, "OVERLAY", nil, 3)
  self.glanz:SetHeight(HOCH - 2)
  scheitBild(self.glanz)
  if self.glanz.SetBlendMode then self.glanz:SetBlendMode("ADD") end
  self.glanz:SetVertexColor(1, 0.8, 0.3)
  self.glanz:Hide()

  self.text = S.schrift(r, "GameFontNormal", F.text)
  self.text:SetPoint("TOP", 0, -6)
  local knopf = CreateFrame("Button", nil, r)
  knopf:SetAllPoints()
  knopf:SetScript("OnMouseDown", function() ST:Fallen() end)
  -- Eigene Uhr für die Effekte, sie laufen auch nach dem Spielende kurz weiter
  local uhr = CreateFrame("Frame", nil, r)
  uhr:SetScript("OnUpdate", function(_, dt) ST:Effekte(dt) end)
end

local function zeichnen(t, x, y, breite, nr)
  local h = farbe(nr)
  t:SetVertexColor(h[1], h[2], h[3], 1)
  t:SetSize(math.max(1, breite), HOCH - 2)
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

local function effekteWeg(self)
  for _, s in ipairs(self.stuecke or {}) do s.aktiv = false s.t:Hide() end
  for _, s in ipairs(self.spaene or {}) do s.aktiv = false s.t:Hide() end
  for _, s in ipairs(self.staub or {}) do s.aktiv = false s.t:Hide() end
  if self.glanz then self.glanz:Hide() end
  self.fall, self.federn, self.glanzZeit = nil, nil, nil
end

function ST:Start()
  effekteWeg(self)
  self.umgefallen = false
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
    if s then
      local y = 6 + (i - 1) * HOCH
      zeichnen(t, s.x, y, s.w, von + i - 1)
      if von + i - 1 == n then self.oben = { t = t, x = s.x, y = y, w = s.w } end
    else
      t:Hide()
    end
  end
  self.ebene = 6 + (n - von + 1) * HOCH
end

-- Effekte starten -------------------------------------------------------------------------------

local function freies(liste)
  for _, s in ipairs(liste) do if not s.aktiv then return s end end
end

-- Ein fallendes Stück: x, y unten links, Breite, Geschwindigkeit, Drehung in Grad
function ST:Stueck(x, y, w, vx, vy, grad, nr, leben)
  local s = freies(self.stuecke)
  if not s then return end
  s.aktiv, s.x, s.y, s.w, s.vx, s.vy, s.alter, s.leben = true, x, y, w, vx, vy, 0, leben or 0.9
  s.angehaengt = nil
  local h = farbe(nr)
  s.t:SetVertexColor(h[1], h[2], h[3], 1)
  s.t:SetWidth(math.max(1, w))
  s.t:SetAlpha(1)
  s.t:Show()
  drehen(s.t, grad, s.leben)
  return s
end

function ST:Spaene(x, y, anzahl)
  for _ = 1, anzahl do
    local s = freies(self.spaene)
    if not s then return end
    s.aktiv, s.alter, s.leben = true, 0, SP.zufall(0.35, 0.6)
    s.x, s.y = x + SP.zufall(-6, 6), y + SP.zufall(0, 4)
    s.vx, s.vy = SP.zufall(-90, 90), SP.zufall(70, 170)
    local g = SP.zufall(2, 3.5)
    s.t:SetSize(g, g)
    local hell = SP.zufall(0.8, 1)
    s.t:SetVertexColor(0.78 * hell, 0.58 * hell, 0.36 * hell, 1)
    s.t:Show()
  end
end

function ST:Staub(x, y)
  local s = freies(self.staub)
  if not s then return end
  s.aktiv, s.x, s.y, s.alter, s.leben = true, x, y, 0, 0.45
  s.t:Show()
end

-- Gelandet: federn, Späne an beiden Enden, Staub, bei genauem Treffer Glanz, Überstand fällt ab
function ST:Landen(f)
  self.fall = nil
  local o = self.oben
  if not o then return end
  self.federn = 0
  o.t:ClearAllPoints()
  o.t:SetPoint("BOTTOMLEFT", o.x, o.y)
  self:Spaene(o.x + 3, o.y + HOCH - 3, 4)
  self:Spaene(o.x + o.w - 3, o.y + HOCH - 3, 4)
  self:Staub(o.x, o.y)
  self:Staub(o.x + o.w, o.y)
  if f.perfekt then
    self.glanzZeit = 0
    self.glanz:ClearAllPoints()
    self.glanz:SetPoint("BOTTOMLEFT", o.x, o.y)
    self.glanz:SetWidth(o.w)
    self.glanz:Show()
  end
  local s = f.ueberstand
  if s then
    -- kippt über die Kante: Richtung nach außen, leicht nach oben angestoßen
    s.angehaengt = nil
    s.vx = s.links and SP.zufall(-70, -40) or SP.zufall(40, 70)
    s.vy = SP.zufall(30, 70)
    drehen(s.t, s.links and SP.zufall(100, 160) or -SP.zufall(100, 160), s.leben)
    self:Spaene(s.links and (s.x + s.w) or s.x, o.y + HOCH - 2, 5)
  end
end

-- Klick ----------------------------------------------------------------------------------------

function ST:Fallen()
  if not (SP.laeuft and SP.aktiv == self) or self.umgefallen then return end
  -- Schneller Klick: der letzte Scheit landet sofort
  if self.fall then self:Landen(self.fall) end
  local oben = self.stapel[#self.stapel]
  local links, rechts = math.max(self.x, oben.x), math.min(self.x + self.breite, oben.x + oben.w)
  local rest = rechts - links
  local schwingY = math.min(SP.HOEHE - 40, self.ebene + 26)
  local nr = #self.stapel
  if rest <= 2 then
    -- Daneben: der Scheit purzelt am Stapel vorbei, dann ist Schluss
    self.umgefallen = true
    self.schwinger:Hide()
    local nachLinks = self.x + self.breite / 2 < oben.x + oben.w / 2
    self:Stueck(self.x, schwingY, self.breite, nachLinks and -60 or 60, 40, nachLinks and 200 or -200, nr, UMFALLEN_DAUER)
    self.text:SetText(L.STACK_FALL)
    self.text:SetTextColor(rgba(F.fehler))
    SP:Ruf(L.STACK_TIMBER, SP.BREITE / 2, -90, { 0.94, 0.38, 0.35, 1 })
    ns.ton("umfallen")
    if C_Timer and C_Timer.After then
      C_Timer.After(UMFALLEN_DAUER, function() if SP.laeuft and SP.aktiv == ST then SP:Fertig() end end)
    else
      SP:Fertig()
    end
    return
  end
  local perfekt = math.abs(self.x - oben.x) <= 3
  local ueberstand
  if perfekt then
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
    -- Das abgesägte Stück fällt zuerst mit dem Scheit, beim Aufprall bricht es ab
    local ux = self.x < oben.x and self.x or rechts
    local uw = self.x < oben.x and (oben.x - self.x) or (self.x + self.breite - rechts)
    if uw > 1 then
      ueberstand = self:Stueck(ux, schwingY, uw, 0, 0, 0, nr)
      if ueberstand then ueberstand.angehaengt, ueberstand.links = true, self.x < oben.x end
    end
  end
  if #self.stapel % 5 == 1 and #self.stapel > 1 then
    SP:Ruf(string.format(SP.spruch(L.STACK_HEIGHT), #self.stapel - 1), SP.BREITE / 2, -50, { 0.4, 0.84, 0.56, 1 })
  end
  self:Neu()
  self:Zeichnen()
  -- Der neue oberste Scheit startet auf Schwinghöhe und fällt auf seinen Platz
  local o = self.oben
  if o and schwingY > o.y then
    self.fall = { hoehe = schwingY - o.y, zeit = 0, perfekt = perfekt, ueberstand = ueberstand }
    self.federn = nil
    o.t:ClearAllPoints()
    o.t:SetPoint("BOTTOMLEFT", o.x, schwingY)
  end
end

-- Bewegung -------------------------------------------------------------------------------------

function ST:Effekte(dt)
  if not dt or dt <= 0 then return end
  dt = math.min(dt, 0.05)
  local o = self.oben
  -- Fallender Scheit
  local f = self.fall
  if f and o then
    f.zeit = f.zeit + dt
    local weg = 0.5 * SCHWERE * f.zeit * f.zeit
    local y = o.y + math.max(0, f.hoehe - weg)
    o.t:ClearAllPoints()
    o.t:SetPoint("BOTTOMLEFT", o.x, y)
    local s = f.ueberstand
    if s and s.angehaengt then
      s.y = y
      s.t:ClearAllPoints()
      s.t:SetPoint("BOTTOMLEFT", s.x, s.y)
    end
    if weg >= f.hoehe then self:Landen(f) end
  elseif self.federn and o then
    -- Aufprall: kurz gestaucht, dann wieder voll
    self.federn = self.federn + dt
    local k = self.federn / FEDERN
    if k >= 1 then
      self.federn = nil
      o.t:SetHeight(HOCH - 2)
    else
      o.t:SetHeight((HOCH - 2) * (1 - 0.28 * math.sin(math.pi * k)))
    end
  end
  -- Glanz bei genauem Treffer
  if self.glanzZeit then
    self.glanzZeit = self.glanzZeit + dt
    local a = 0.75 * (1 - self.glanzZeit / 0.4)
    if a <= 0 then self.glanzZeit = nil self.glanz:Hide() else self.glanz:SetAlpha(a) end
  end
  -- Fallende Stücke
  for _, s in ipairs(self.stuecke) do
    if s.aktiv and not s.angehaengt then
      s.alter = s.alter + dt
      s.vy = s.vy - SCHWERE * dt
      s.x, s.y = s.x + s.vx * dt, s.y + s.vy * dt
      s.t:ClearAllPoints()
      s.t:SetPoint("BOTTOMLEFT", s.x, s.y)
      local rest = 1 - s.alter / s.leben
      s.t:SetAlpha(math.max(0, math.min(1, rest * 3)))
      if rest <= 0 or s.y < -40 then s.aktiv = false s.t:Hide() end
    end
  end
  -- Späne
  for _, s in ipairs(self.spaene) do
    if s.aktiv then
      s.alter = s.alter + dt
      s.vy = s.vy - SCHWERE * 0.6 * dt
      s.x, s.y = s.x + s.vx * dt, s.y + s.vy * dt
      s.t:ClearAllPoints()
      s.t:SetPoint("CENTER", self.r, "BOTTOMLEFT", s.x, s.y)
      local rest = 1 - s.alter / s.leben
      s.t:SetAlpha(math.max(0, rest))
      if rest <= 0 then s.aktiv = false s.t:Hide() end
    end
  end
  -- Staub: weicher Fleck, wächst und verblasst
  for _, s in ipairs(self.staub) do
    if s.aktiv then
      s.alter = s.alter + dt
      local k = s.alter / s.leben
      local g = 10 + 22 * k
      s.t:SetSize(g, g * 0.6)
      s.t:ClearAllPoints()
      s.t:SetPoint("CENTER", self.r, "BOTTOMLEFT", s.x, s.y + 2 + 6 * k)
      s.t:SetAlpha(math.max(0, 0.4 * (1 - k)))
      if k >= 1 then s.aktiv = false s.t:Hide() end
    end
  end
end

function ST:Tick(dt)
  if self.umgefallen then return end
  self.x = self.x + self.richtung * self.tempo * dt
  if self.x <= 0 then self.x, self.richtung = 0, 1 end
  if self.x + self.breite >= SP.BREITE then self.x, self.richtung = SP.BREITE - self.breite, -1 end
  zeichnen(self.schwinger, self.x, math.min(SP.HOEHE - 40, self.ebene + 26), self.breite, #self.stapel)
end

SP.Registrieren(ST)
