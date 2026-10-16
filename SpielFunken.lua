-- Funkenfänger: Funken steigen aus dem Feuer und verglühen. Vorher anklicken. Alle vier Treffer in
-- Folge steigt die Kombo (bis x4), ein verglühter Funke setzt sie zurück. Blaue Funken: 3 Punkte.
-- Graue Aschewolken nicht anklicken: -1 und die Kombo ist weg.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba
local SP = ns.Spiel

local MAX = 10
local ORANGE, BLAU, ASCHE = { 1, 0.6, 0.2, 1 }, { 0.45, 0.75, 1, 1 }, { 0.55, 0.55, 0.55, 1 }

local FK = { key = "funken", name = L.GAME_SPARKS, info = L.GAME_SPARKS_INFO,
  icon = "Interface\\Icons\\INV_Spark_Shard_Orange", dauer = 30 }

function FK:Bauen(r)
  self.feuer = r:CreateTexture(nil, "ARTWORK")
  self.feuer:SetSize(48, 48)
  self.feuer:SetPoint("BOTTOM", 0, 4)
  S.feuer(self.feuer)
  self.glut = S.glut(r, 140, 76, { 1, 0.5, 0.12, 1 }, "BACKGROUND")
  self.glut:SetPoint("BOTTOM", 0, 0)
  self.kombo = S.schrift(r, "GameFontNormalLarge", F.akzent)
  self.kombo:SetPoint("TOPLEFT", 8, -8)
  self.funken = {}
  for i = 1, MAX do
    local b = CreateFrame("Button", nil, r)
    b:SetSize(26, 26)
    b.licht = S.kreis(b, 26, 26, ORANGE, "ARTWORK", true)
    b.licht:SetPoint("CENTER")
    b.kern = S.kreis(b, 10, 10, { 1, 1, 0.85, 1 }, "OVERLAY", true)
    b.kern:SetPoint("CENTER")
    b:SetScript("OnMouseDown", function(self) FK:Treffer(self) end)
    b:Hide()
    self.funken[i] = b
  end
end

function FK:Start()
  self.naechster, self.multi, self.serie = ns.jetzt() + 0.3, 1, 0
  self.kombo:SetText("")
  for _, b in ipairs(self.funken) do b.aktiv = false b:Hide() end
end

function FK:Treffer(b)
  if not (SP.laeuft and SP.aktiv == self and b.aktiv) then return end
  b.aktiv = false
  b:Hide()
  if b.art == "asche" then
    SP:Plus(-1)
    self.serie, self.multi = 0, 1
    self.kombo:SetText("")
    SP:Ruf(SP.spruch(L.SPARKS_ASH), b.x, b.y - SP.HOEHE, { 0.8, 0.8, 0.8, 1 })
    ns.ton("minus")
    return
  end
  local wert = (b.art == "blau" and 3 or 1) * self.multi
  SP:Plus(wert)
  SP:Ruf("+" .. wert, b.x, b.y - SP.HOEHE, b.art == "blau" and BLAU or ORANGE)
  ns.ton(b.art == "blau" and "muenze" or "plopp")
  self.serie = self.serie + 1
  local neu = math.min(4, 1 + math.floor(self.serie / 4))
  if neu > self.multi then
    SP:Ruf(SP.spruch(L.SPARKS_COMBO_LINES), SP.BREITE / 2, -40, { 1, 0.84, 0.25, 1 })
    ns.ton("paar")
  end
  self.multi = neu
  self.kombo:SetText(self.multi > 1 and string.format(L.SPARKS_COMBO, self.multi) or "")
end

function FK:Tick(dt, jetzt)
  self.glut:SetAlpha(0.55 + 0.35 * math.sin(jetzt * 8) * math.sin(jetzt * 2.9))
  if jetzt >= self.naechster then
    for _, b in ipairs(self.funken) do
      if not b.aktiv then
        local w = math.random(1, 12)
        b.aktiv, b.art = true, (w == 1 and "blau") or ((w == 2 or w == 3) and "asche") or "funke"
        b.x, b.y = SP.BREITE / 2 + SP.zufall(-12, 12), 30
        b.vx, b.vy = SP.zufall(-55, 55), SP.zufall(55, 95)
        b.leben, b.alter = SP.zufall(1.6, 2.6), 0
        b.licht:SetVertexColor(rgba((b.art == "blau" and BLAU) or (b.art == "asche" and ASCHE) or ORANGE))
        b.kern:SetShown(b.art ~= "asche")
        b:Show()
        break
      end
    end
    -- später kommen die Funken schneller
    self.naechster = jetzt + math.max(0.25, 0.7 - (SP.punkte or 0) * 0.005)
  end
  for _, b in ipairs(self.funken) do
    if b.aktiv then
      b.alter = b.alter + dt
      b.vx = b.vx + SP.zufall(-60, 60) * dt      -- Wind
      b.x = math.max(10, math.min(SP.BREITE - 10, b.x + b.vx * dt))
      b.y = b.y + b.vy * dt
      local rest = 1 - b.alter / b.leben
      b:SetAlpha(math.max(0, rest))
      -- Kleiner werden über die Bildgröße, nicht über SetScale (das würde die Position verschieben)
      local k = 0.6 + 0.4 * rest
      b.licht:SetSize(26 * k, 26 * k)
      b.kern:SetSize(10 * k, 10 * k)
      b:ClearAllPoints()
      b:SetPoint("CENTER", b:GetParent(), "BOTTOMLEFT", b.x, b.y)
      if rest <= 0 or b.y > SP.HOEHE then
        b.aktiv = false
        b:Hide()
        if b.art ~= "asche" then                  -- verglüht: Kombo weg (Asche darf verwehen)
          self.multi, self.serie = 1, 0
          self.kombo:SetText("")
        end
      end
    end
  end
end

function FK:Stop()
  for _, b in ipairs(self.funken or {}) do b.aktiv = false b:Hide() end
end

SP.Registrieren(FK)
