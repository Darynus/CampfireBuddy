-- Funkenfänger: Funken steigen aus dem Lagerfeuer. Der Spieler hält ein Einmachglas kopfüber über
-- das Feuer, es folgt der Maus. Funken, die in die Öffnung steigen, sind gefangen (kein Zielen mit
-- Klicks mehr, Patrick 16. Okt: "das Gefühl stimmt nicht"). Ein Klick schöpft: Das Glas taucht kurz
-- nach unten, die Öffnung fängt dabei weiter. Schnelle Fänge hintereinander bauen eine Kombo auf
-- (alle vier Fänge eine Stufe, bis x4), nach 1,5 Sekunden ohne Fang ist sie weg. Blaue Funken sind
-- seltener und schneller, sie zählen 3. Graue Aschewolken nicht berühren: -1, Kombo weg, das Glas
-- wackelt. Zehn Funken füllen das Glas, dann wirbeln sie hinaus in den Himmel: 5 Punkte dazu.
--
-- Grafik: Szene, Glas (fünf Neigungen zum Schwingen), Licht im Glas und Asche kommen aus Blender
-- (grafik/blender/funkenglas.py, Media/Funkenglas.tga, Koordinaten in Funkenglas.lua). Funken sind
-- der weiche Funke aus dem Atlas der Spiele, additiv, mit einem Schweif aus dem weichen Schein.
-- Alles läuft in Tick (vom Rahmen geschützt), die Bilder liegen in festen Vorräten.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F = S.F
local SP = ns.Spiel

local GLAS = 52                 -- Größe des Glas-Bildes in der Spielfläche
local HALT = 6                  -- der Mauszeiger hält das Glas knapp über seinem Boden (verdeckt es kaum)
local MUND_MIN = 72             -- so tief darf die Öffnung (über dem Feuer ist es zu heiß)
local VOLL = 10                 -- so viele Funken passen ins Glas
local VOLL_BONUS = 5
local KETTE_ZEIT = 1.5          -- Sekunden bis zum nächsten Fang, sonst ist die Kombo weg
local SCHOEPFEN_DAUER, SCHOEPFEN_PAUSE, SCHOEPFEN_TIEF = 0.26, 0.7, 16
local WACKELN = 0.4
local MAX_FUNKEN, MAX_ASCHE, SPUR = 16, 4, 5
local ORANGE, BLAU, GRAU = { 1, 0.6, 0.2, 1 }, { 0.45, 0.75, 1, 1 }, { 0.78, 0.78, 0.8, 1 }
-- Farbe eines Funkens über sein Leben: heiß, glühend, verglühend
local FARBEN = {
  funke = { { 1, 0.92, 0.62 }, { 1, 0.6, 0.2 }, { 0.8, 0.24, 0.06 } },
  blau = { { 0.82, 0.94, 1 }, { 0.42, 0.72, 1 }, { 0.22, 0.42, 1 } },
}

-- Ausschnitt eines Teils für die Legende (ohne den leeren Rand des Bildes)
local function ausschnitt(name, rand)
  local k = S.FUNKENGLAS_TEILE and S.FUNKENGLAS_TEILE[name]
  if not k then return nil end
  local b, h = k[2] - k[1], k[4] - k[3]
  return { k[1] + b * rand, k[2] - b * rand, k[3] + h * rand, k[4] - h * rand }
end

local FK = { key = "funken", musik = "mayhem", name = L.GAME_SPARKS, info = L.GAME_SPARKS_INFO,
  icon = "Interface\\Icons\\INV_Spark_Shard_Orange", dauer = 30,
  legende = {
    { atlas = "funke", farbe = ORANGE, punkte = 1 },
    { atlas = "funke", farbe = BLAU, punkte = 3 },
    { bild = S.FUNKENGLAS, coords = ausschnitt("asche1", 0.12), punkte = -1 },
    { bild = S.FUNKENGLAS, coords = ausschnitt("glas3", 0.04), punkte = VOLL_BONUS },
  } }

local function begrenzt(v, a, b) return v < a and a or (v > b and b or v) end

-- Teil aus Media/Funkenglas.tga setzen
local function teil(t, name)
  local k = S.FUNKENGLAS_TEILE and S.FUNKENGLAS_TEILE[name]
  if not k then return false end
  t:SetTexture(S.FUNKENGLAS)
  t:SetTexCoord(k[1], k[2], k[3], k[4])
  return true
end

-- Weicher Funke aus dem Atlas, additiv oder normal (Ascheflocken). motiv "schein": ohne hellen Kern
-- (für den Schweif, damit er nicht in Punkte zerfällt)
local function funkenBild(r, ebene, unter, additiv, motiv)
  local t = r:CreateTexture(nil, ebene, nil, unter)
  if not (motiv and S.atlas(t, motiv)) and not S.atlas(t, "funke") then t:SetTexture(S.KREIS) end
  if additiv and t.SetBlendMode then t:SetBlendMode("ADD") end
  t:Hide()
  return t
end

local function setze(t, x, y, g)
  t:SetSize(g, g)
  t:ClearAllPoints()
  t:SetPoint("CENTER", FK.r, "BOTTOMLEFT", x, y)
end

local function mischen(liste, k, out)
  local a, b, f
  if k < 0.3 then a, b, f = liste[1], liste[2], k / 0.3 else a, b, f = liste[2], liste[3], (k - 0.3) / 0.7 end
  f = begrenzt(f, 0, 1)
  out[1], out[2], out[3] = a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
  return out
end
local farbe = { 1, 1, 1 }

-- Form des Glases je Neigung: Öffnung relativ zum Drehpunkt, Achse und Quer-Richtung
local function formen()
  local dreh = S.FUNKENGLAS_DREH or { x = 0.5, y = 0.056 }
  local liste = {}
  for i = 1, 5 do
    local g = S.FUNKENGLAS_GLAS and S.FUNKENGLAS_GLAS[i]
    local ox, oy
    if g then
      ox, oy = (g.mx - dreh.x) * GLAS, -(g.my - dreh.y) * GLAS
    else
      local w = math.rad((i - 3) * 7.5)
      ox, oy = math.sin(w) * 46, -math.cos(w) * 46
    end
    local laenge = math.sqrt(ox * ox + oy * oy)
    local ax, ay = ox / laenge, oy / laenge
    liste[i] = { ox = ox, oy = oy, ax = ax, ay = ay, qx = -ay, qy = ax, laenge = laenge,
      rx = math.max(12, ((g and g.breite) or 0.41) * GLAS * 0.5 + 3) }
  end
  return liste, dreh
end

-- Aufbau ---------------------------------------------------------------------------------------

function FK:Bauen(r)
  self.r = r
  self.form, self.dreh = formen()
  local szene = r:CreateTexture(nil, "BACKGROUND")
  szene:SetAllPoints()
  if S.FUNKENGLAS_SZENE then
    szene:SetTexture(S.FUNKENGLAS)
    local k = S.FUNKENGLAS_SZENE
    szene:SetTexCoord(k[1], k[2], k[3], k[4])
  else
    szene:SetColorTexture(0.02, 0.025, 0.05, 1)
  end
  -- Feuer: flackerndes Bildblatt auf der Feuerstelle der Szene, dazu ein weicher Schein, der mit
  -- dem Knistern aufleuchtet
  self.glut = S.glut(r, 170, 84, { 1, 0.5, 0.15, 1 }, "BORDER")
  self.glut:SetPoint("BOTTOM", r, "BOTTOM", 0, 0)
  self.feuer = r:CreateTexture(nil, "ARTWORK")
  self.feuer:SetSize(72, 72)
  self.feuer:SetPoint("BOTTOM", 0, 0)
  S.feuer(self.feuer)

  self.asche = {}
  for i = 1, MAX_ASCHE do
    local t = r:CreateTexture(nil, "ARTWORK", nil, 2)
    if not teil(t, "asche" .. (((i - 1) % 3) + 1)) then t:SetColorTexture(0, 0, 0, 0) end
    t:Hide()
    self.asche[i] = { t = t, nr = ((i - 1) % 3) + 1 }
  end
  self.funken = {}
  for i = 1, MAX_FUNKEN do
    local f = { spur = {}, hx = {}, hy = {} }
    for k = 1, SPUR do f.spur[k] = funkenBild(r, "ARTWORK", 4, true, "schein") end
    f.t = funkenBild(r, "ARTWORK", 5, true)
    f.kern = funkenBild(r, "ARTWORK", 6, true)
    self.funken[i] = f
  end

  -- Das Glas: Glasbild, Licht von innen (additiv, je voller desto heller), gefangene Funken
  self.glas = r:CreateTexture(nil, "OVERLAY", nil, 0)
  self.glas:SetSize(GLAS, GLAS)
  self.licht = r:CreateTexture(nil, "OVERLAY", nil, 1)
  self.licht:SetSize(GLAS, GLAS)
  if self.licht.SetBlendMode then self.licht:SetBlendMode("ADD") end
  self.innen = {}
  for i = 1, VOLL do
    self.innen[i] = { t = funkenBild(r, "OVERLAY", 2, true), phase = i * 1.7, tempo = 1.6 + (i % 4) * 0.45 }
  end
  -- Funkenregen beim Fang und beim Leeren (additiv), Ascheflocken (normal, dunkel)
  self.glanz, self.flocken = {}, {}
  for i = 1, 40 do self.glanz[i] = { t = funkenBild(r, "OVERLAY", 3, true) } end
  -- eigener Vorrat für den Wirbel beim Leeren, damit er nie an vollen Spritzern scheitert
  for i = 1, VOLL do self.glanz[40 + i] = { t = funkenBild(r, "OVERLAY", 3, true), nurWirbel = true } end
  for i = 1, 14 do self.flocken[i] = { t = funkenBild(r, "OVERLAY", 4, false) } end

  -- Schrift über allem: Kombo am Glas, Hinweis zu Beginn
  local oben = CreateFrame("Frame", nil, r)
  oben:SetAllPoints()
  oben:SetFrameLevel(((r.GetFrameLevel and r:GetFrameLevel()) or 1) + 5)
  self.kombo = S.schrift(oben, "GameFontNormalLarge", F.akzent)
  self.hinweis = S.schrift(oben, "GameFontHighlightSmall", F.text)
  self.hinweis:SetPoint("TOP", 0, -8)
  self.hinweis:SetText(L.SPARKS_HINT)

  -- Klick irgendwo in die Fläche: schöpfen. Die Fläche nimmt die Maus, so zieht kein Klick das Fenster.
  local knopf = CreateFrame("Button", nil, r)
  knopf:SetAllPoints()
  knopf:SetScript("OnMouseDown", function() FK:Schoepfen() end)
  self.knopf = knopf
  self.x, self.y = SP.BREITE / 2, SP.HOEHE - 20
  self:GlasZeichnen(3)
end

-- Maus in Koordinaten der Spielfläche (unten links 0, 0), als Drehpunkt des Glases
function FK:Zeiger()
  local r = self.r
  if not (GetCursorPosition and r and r.GetLeft) then return end
  local x, y = GetCursorPosition()
  local s = r:GetEffectiveScale()
  local links, unten = r:GetLeft(), r:GetBottom()
  if not unten then
    local o, h = r:GetTop(), r:GetHeight()
    unten = o and h and (o - h)
  end
  if not (x and y and s and s > 0 and links and unten) then return end
  return x / s - links, y / s - unten - HALT
end

-- Drehpunkt (Boden des Glases) innerhalb der Fläche halten, die Öffnung über dem Feuer
function FK:Begrenzen(x, y)
  local d = self.dreh
  return begrenzt(x, GLAS * d.x + 4, SP.BREITE - GLAS * (1 - d.x) - 4),
    begrenzt(y, MUND_MIN + self.form[3].laenge, SP.HOEHE - GLAS * d.y - 1)
end

-- Runde --------------------------------------------------------------------------------------------

local function aus(liste)
  for _, f in ipairs(liste) do
    f.aktiv = false
    f.t:Hide()
    if f.kern then f.kern:Hide() end
    if f.spur then for _, s in ipairs(f.spur) do s:Hide() end end
  end
end

function FK:Aufraeumen()
  aus(self.funken)
  aus(self.asche)
  aus(self.glanz)
  aus(self.flocken)
  for _, f in ipairs(self.innen) do f.aktiv = false f.t:Hide() end
  self.fuellung, self.blitz, self.stoss, self.wackeln, self.schoepfen = 0, 0, 0, nil, nil
  self.kette, self.multi, self.ketteBis = 0, 1, nil
  self.kombo:SetText("")
  self.licht:SetAlpha(0)
  self.glas:SetVertexColor(1, 1, 1)
  self.tauchen, self.wackelX = 0, 0
end

function FK:Start()
  local jetzt = ns.jetzt()
  self:Aufraeumen()
  self.beginn, self.zeit = jetzt, 0
  self.naechster, self.naechsterStoss, self.naechsteAsche = jetzt + 0.3, jetzt + 1.6, jetzt + 2.2
  self.schoepfenBereit, self.tonBis = 0, 0
  local x, y = self:Zeiger()
  self.x, self.y = self:Begrenzen(x or SP.BREITE / 2, y or SP.HOEHE - 20)
  self.vx, self.neigung = 0, 0
  self.hinweis:SetAlpha(1)
  self.hinweis:Show()
  self:GlasZeichnen(3)
end

function FK:Stop()
  if self.funken then self:Aufraeumen() end
end

-- Neuer Funke: art "funke" oder "blau", Ort und Geschwindigkeit
function FK:Funke(art, x, y, vx, vy)
  for _, f in ipairs(self.funken) do
    if not f.aktiv then
      local blau = art == "blau"
      f.aktiv, f.art = true, art
      f.x, f.y, f.vx, f.vy = x, y, vx or 0, vy or 0
      f.alter, f.leben = 0, blau and SP.zufall(1.5, 1.9) or SP.zufall(1.8, 2.6)
      f.groesse = blau and 16 or 14
      f.phase, f.wf = math.random() * 6.3, blau and 9 or SP.zufall(4, 6.5)
      f.px, f.py, f.spurZeit = x, y, 0
      for k = 1, SPUR do f.hx[k], f.hy[k] = x, y end
      f.t:Show()
      f.kern:Show()
      for _, s in ipairs(f.spur) do s:Show() end
      return f
    end
  end
end

function FK:Wolke(x, y)
  for _, a in ipairs(self.asche) do
    if not a.aktiv then
      a.aktiv, a.x, a.y = true, x, y
      a.vx, a.vy = SP.zufall(-8, 8), SP.zufall(20, 30)
      a.alter, a.leben, a.groesse = 0, SP.zufall(5, 6.5), SP.zufall(34, 40)
      a.phase, a.weg = math.random() * 6.3, nil
      a.t:SetAlpha(0)
      a.t:Show()
      return a
    end
  end
end

-- Kleine Funken, die vom Fang wegspritzen
function FK:Spritzer(x, y, f, anzahl)
  for _ = 1, anzahl do
    for _, g in ipairs(self.glanz) do
      if not g.aktiv and not g.nurWirbel then
        local w, v = math.random() * 6.3, SP.zufall(45, 110)
        g.aktiv, g.wirbel, g.x, g.y = true, false, x, y
        g.vx, g.vy = math.cos(w) * v, math.sin(w) * v + 20
        g.alter, g.leben, g.groesse = 0, SP.zufall(0.28, 0.45), SP.zufall(4, 7)
        g.r, g.g, g.b = f[1], f[2], f[3]
        g.t:SetVertexColor(g.r, g.g, g.b)
        g.t:Show()
        break
      end
    end
  end
end

-- Spielzüge ------------------------------------------------------------------------------------

function FK:Schoepfen()
  if not (SP.laeuft and SP.aktiv == self and not SP.pause) then return end
  local jetzt = ns.jetzt()
  if jetzt < (self.schoepfenBereit or 0) then return end
  self.schoepfen, self.schoepfenBereit = 0, jetzt + SCHOEPFEN_PAUSE
  ns.ton("karte")
end

function FK:Fangen(f)
  f.aktiv = false
  f.t:Hide()
  f.kern:Hide()
  for _, s in ipairs(f.spur) do s:Hide() end
  local blau = f.art == "blau"
  local wert = (blau and 3 or 1) * self.multi
  SP:Plus(wert)
  local fo = self.form[self.bild or 3]
  local mx, my = (self.gx or self.x) + fo.ox, (self.gy or self.y) + fo.oy
  SP:Ruf("+" .. wert, mx + (self.x > SP.BREITE - 60 and -26 or 26), my - SP.HOEHE + 10, blau and BLAU or ORANGE)
  self:Spritzer(mx, my, blau and BLAU or ORANGE, 7)
  self.blitz, self.stoss = 1, 1
  -- Der Funke steigt sichtbar ins Glas und bleibt dort
  self.fuellung = self.fuellung + 1
  local innen = self.innen[self.fuellung]
  if innen then
    innen.aktiv, innen.ein, innen.blau = true, 0, blau
    local c = blau and BLAU or ORANGE
    innen.t:SetVertexColor(c[1], c[2], c[3])
    innen.t:Show()
  end
  -- Kombo: schnelle Fänge hintereinander
  local jetzt = ns.jetzt()
  self.kette, self.ketteBis = self.kette + 1, jetzt + KETTE_ZEIT
  local neu = math.min(4, 1 + math.floor(self.kette / 4))
  local hoch = neu > self.multi
  self.multi = neu
  if hoch then
    SP:Ruf(SP.spruch(L.SPARKS_COMBO_LINES), SP.BREITE / 2, -36, { 1, 0.84, 0.25, 1 })
    ns.ton("paar")
  elseif jetzt >= self.tonBis then
    -- Ton steigt mit der Kombo, höchstens alle 0,07 Sekunden einer
    ns.ton((blau or self.multi >= 4) and "muenze" or (self.multi >= 2 and "treffer" or "plopp"))
  end
  self.tonBis = jetzt + 0.07
  self.kombo:SetText(self.multi > 1 and string.format(L.SPARKS_COMBO, self.multi) or "")
  self.kombo:SetTextColor(1, 0.84, 0.25)
  self.komboFarbe = 0.35
  if self.fuellung >= VOLL then self:Leeren() end
end

-- Volles Glas: die Funken wirbeln aus dem Glas in den Himmel, Bonus
function FK:Leeren()
  local fo = self.form[self.bild or 3]
  for i, innen in ipairs(self.innen) do
    if innen.aktiv then
      innen.aktiv = false
      innen.t:Hide()
      for n = #self.glanz, 1, -1 do
        local g = self.glanz[n]
        if not g.aktiv then
          g.aktiv, g.wirbel = true, true
          g.mx, g.my = (self.gx or self.x) + fo.ox * 0.5, (self.gy or self.y) + fo.oy * 0.5
          g.winkel, g.radius = i / VOLL * 6.28, 6 + (i % 3) * 3
          g.x, g.y, g.alter, g.leben, g.groesse = g.mx, g.my, 0, SP.zufall(0.8, 1.05), 9
          local c = innen.blau and BLAU or ORANGE
          g.r, g.g, g.b = c[1], c[2], c[3]
          g.t:SetVertexColor(g.r, g.g, g.b)
          g.t:Show()
          break
        end
      end
    end
  end
  self.fuellung = 0
  self.blitz = 1.6
  SP:Plus(VOLL_BONUS)
  SP:Ruf(string.format(L.SPARKS_FULL, VOLL_BONUS), begrenzt(self.x, 60, SP.BREITE - 60), -24, { 1, 0.84, 0.25, 1 })
  ns.ton("paar")
end

function FK:Asche(a)
  a.weg = 0
  SP:Plus(-1)
  self.kette, self.multi, self.ketteBis = 0, 1, nil
  self.kombo:SetText("")
  self.wackeln = 0
  SP:Ruf(SP.spruch(L.SPARKS_ASH), begrenzt(a.x, 50, SP.BREITE - 50), begrenzt(a.y + 16, 30, SP.HOEHE - 30) - SP.HOEHE, GRAU)
  ns.ton("minus")
  -- Ascheflocken stieben auseinander
  local n = 0
  for _, fl in ipairs(self.flocken) do
    if not fl.aktiv then
      local w, v = math.random() * 6.3, SP.zufall(25, 70)
      fl.aktiv, fl.x, fl.y = true, a.x + SP.zufall(-6, 6), a.y + SP.zufall(-5, 5)
      fl.vx, fl.vy = math.cos(w) * v, math.sin(w) * v
      fl.alter, fl.leben, fl.groesse = 0, SP.zufall(0.5, 0.8), SP.zufall(3, 4.5)
      local h = SP.zufall(0.12, 0.22)
      fl.t:SetVertexColor(h, h * 0.96, h * 0.92)
      fl.t:Show()
      n = n + 1
      if n >= 8 then break end
    end
  end
end

-- Ablauf --------------------------------------------------------------------------------------------

function FK:Erzeugen(jetzt)
  local dauer = SP.dauer or self.dauer or 30
  local p = begrenzt((jetzt - (self.beginn or jetzt)) / dauer, 0, 1)
  local fx = SP.BREITE * ((S.FUNKENGLAS_FEUER and S.FUNKENGLAS_FEUER.x) or 0.5)
  if jetzt >= self.naechster then
    local blau = math.random() < 0.08 + 0.05 * p
    if blau then
      local seite = math.random() < 0.5 and -1 or 1
      self:Funke("blau", fx + SP.zufall(-8, 8), SP.zufall(42, 50), seite * SP.zufall(40, 90), SP.zufall(110, 150))
    else
      self:Funke("funke", fx + SP.zufall(-13, 13), SP.zufall(38, 50), SP.zufall(-60, 60), SP.zufall(55, 90))
    end
    self.naechster = jetzt + SP.zufall(0.42, 0.6) - 0.16 * p
  end
  -- Knistern: ein Scheit knackt, mehrere Funken fächern auf, der Schein flackert auf
  if jetzt >= self.naechsterStoss then
    local n = math.random(3, 5)
    for i = 1, n do
      local w = (i - (n + 1) / 2) / n
      self:Funke("funke", fx + w * 18, SP.zufall(36, 54), w * SP.zufall(80, 140) + SP.zufall(-15, 15), SP.zufall(60, 115))
    end
    self.knistern = 1
    self.naechsterStoss = jetzt + SP.zufall(2.2, 3.4) - 0.8 * p
  end
  if jetzt >= self.naechsteAsche then
    self:Wolke(fx + SP.zufall(-10, 10), 46)
    self.naechsteAsche = jetzt + SP.zufall(2.4, 3.2) - 1.0 * p
  end
end

-- Glas setzen: Bild je Neigung, Licht mit Füllung
function FK:GlasZeichnen(nr)
  if nr ~= self.bild then
    self.bild = nr
    if not teil(self.glas, "glas" .. nr) then self.glas:SetColorTexture(0, 0, 0, 0) end
    if not teil(self.licht, "licht" .. nr) then self.licht:SetColorTexture(0, 0, 0, 0) end
  end
  local x, y = self.x + (self.wackelX or 0), self.y + (self.tauchen or 0)
  local d = self.dreh
  self.glas:ClearAllPoints()
  self.glas:SetPoint("TOPLEFT", self.r, "BOTTOMLEFT", x - GLAS * d.x, y + GLAS * d.y)
  self.licht:ClearAllPoints()
  self.licht:SetPoint("TOPLEFT", self.r, "BOTTOMLEFT", x - GLAS * d.x, y + GLAS * d.y)
end

function FK:Tick(dt, jetzt)
  dt = math.min(dt or 0, 0.05)
  if dt <= 0 then return end
  self.zeit = (self.zeit or 0) + dt
  local t = self.zeit
  self:Erzeugen(jetzt)

  -- Glas folgt der Maus mit etwas Gewicht und schwingt dabei
  local zx, zy = self:Zeiger()
  if zx then zx, zy = self:Begrenzen(zx, zy) else zx, zy = self.x, self.y end
  local altX = self.x
  local k = 1 - math.exp(-dt * 20)
  self.x, self.y = self.x + (zx - self.x) * k, self.y + (zy - self.y) * k
  self.vx = self.vx + ((self.x - altX) / dt - self.vx) * math.min(1, dt * 12)
  local ziel = begrenzt(-self.vx / 260, -1, 1)
  self.neigung = self.neigung + (ziel - self.neigung) * (1 - math.exp(-dt * 9))
  local nr = begrenzt(math.floor(self.neigung * 2 + 3.5), 1, 5)
  local fo = self.form[nr]
  -- Schöpfen: kurz nach unten und zurück, mit größerer Öffnung
  local weit = 1
  self.tauchen = 0
  if self.schoepfen then
    self.schoepfen = self.schoepfen + dt
    local s = self.schoepfen / SCHOEPFEN_DAUER
    if s >= 1 then self.schoepfen = nil else
      self.tauchen = -SCHOEPFEN_TIEF * math.sin(math.pi * s)
      weit = 1.6
    end
  end
  -- Fang-Stoß (das Glas hüpft ein wenig) und Wackeln nach der Asche
  self.stoss = math.max(0, (self.stoss or 0) - dt * 8)
  self.tauchen = self.tauchen + 2.5 * self.stoss
  self.wackelX = 0
  if self.wackeln then
    self.wackeln = self.wackeln + dt
    local w = self.wackeln / WACKELN
    if w >= 1 then self.wackeln = nil self.glas:SetVertexColor(1, 1, 1) else
      self.wackelX = math.sin(self.wackeln * 55) * 4 * (1 - w)
      local g = 0.7 + 0.3 * w
      self.glas:SetVertexColor(g, g, g)
    end
  end
  self:GlasZeichnen(nr)
  local gx, gy = self.x + self.wackelX, self.y + self.tauchen
  self.gx, self.gy = gx, gy
  local mx, my = gx + fo.ox, gy + fo.oy + 2
  local rx, ry = fo.rx * weit, 10 * weit

  -- Wind für alle: langsam wechselnd
  local wind = 18 * math.sin(t * 0.45) + 12 * math.sin(t * 1.17 + 1.3)

  -- Funken
  for _, f in ipairs(self.funken) do
    if f.aktiv then
      f.alter = f.alter + dt
      f.vx = f.vx + (wind - f.vx) * 0.5 * dt
      f.vy = f.vy - f.vy * 0.25 * dt
      f.x, f.y = f.x + f.vx * dt, f.y + f.vy * dt
      local wackel = math.sin(f.alter * f.wf + f.phase) * (2 + 5 * f.alter)
      f.px, f.py = f.x + wackel, f.y
      local rest = 1 - f.alter / f.leben
      -- Gefangen? In der Öffnung, beim Schöpfen auch im Glas
      local dx, dy = (f.px - mx) / rx, (f.py - my) / ry
      local drin = dx * dx + dy * dy <= 1
      if not drin and weit > 1 then
        local lx, ly = f.px - gx, f.py - gy
        local tief = lx * fo.ax + ly * fo.ay
        drin = tief > 0 and tief < fo.laenge and math.abs(lx * fo.qx + ly * fo.qy) < 14
      end
      if drin and SP.laeuft then
        self:Fangen(f)
      elseif rest <= 0 or f.py > SP.HOEHE + 10 or f.px < -10 or f.px > SP.BREITE + 10 then
        f.aktiv = false
        f.t:Hide()
        f.kern:Hide()
        for _, s in ipairs(f.spur) do s:Hide() end
      else
        -- Spur: dichte Punkte (alle 0,022 Sekunden), nach hinten kleiner und blasser, sie fließen zu einem Schweif
        f.spurZeit = f.spurZeit + dt
        if f.spurZeit >= 0.022 then
          f.spurZeit = 0
          for n = SPUR, 2, -1 do f.hx[n], f.hy[n] = f.hx[n - 1], f.hy[n - 1] end
          f.hx[1], f.hy[1] = f.px, f.py
        end
        local a = math.min(1, f.alter / 0.08) * math.min(1, rest / 0.35) * (0.82 + 0.18 * math.sin(f.alter * 31 + f.phase))
        local g = f.groesse * (0.6 + 0.4 * rest)
        mischen(FARBEN[f.art], 1 - rest, farbe)
        f.t:SetVertexColor(farbe[1], farbe[2], farbe[3])
        f.t:SetAlpha(a)
        setze(f.t, f.px, f.py, g)
        if f.art == "blau" then f.kern:SetVertexColor(0.88, 0.96, 1) else f.kern:SetVertexColor(1, 0.95, 0.82) end
        f.kern:SetAlpha(a * 0.9 * rest)
        setze(f.kern, f.px, f.py, g * 0.5)
        for n, s in ipairs(f.spur) do
          s:SetVertexColor(farbe[1], farbe[2], farbe[3])
          s:SetAlpha(a * (0.7 - n * 0.12))
          setze(s, f.hx[n], f.hy[n], g * (0.78 - n * 0.09))
        end
      end
    end
  end

  -- Aschewolken: steigen langsam, schwanken, berühren sie das Glas, kostet es einen Punkt
  for _, a in ipairs(self.asche) do
    if a.aktiv then
      a.alter = a.alter + dt
      if a.weg then
        a.weg = a.weg + dt
        local w = a.weg / 0.35
        if w >= 1 then a.aktiv = false a.t:Hide() else
          a.t:SetAlpha(0.85 * (1 - w))
          setze(a.t, a.x, a.y, a.groesse * (1 + 0.7 * w))
        end
      else
        a.vx = a.vx + (wind * 0.6 - a.vx) * 0.4 * dt
        a.x, a.y = a.x + a.vx * dt, a.y + a.vy * dt
        local px = a.x + math.sin(a.alter * 1.3 + a.phase) * 9
        local rest = a.leben - a.alter
        a.t:SetAlpha(0.88 * math.min(1, a.alter / 0.4) * begrenzt(rest / 0.8, 0, 1))
        local g = a.groesse * (0.85 + 0.15 * math.min(1, a.alter / 2))
        setze(a.t, px, a.y, g)
        -- Abstand der Wolkenmitte zur Achse des Glases
        local lx, ly = px - gx, a.y - gy
        local tief = begrenzt(lx * fo.ax + ly * fo.ay, 0, fo.laenge)
        local qx, qy = lx - fo.ax * tief, ly - fo.ay * tief
        if SP.laeuft and a.alter > 0.3 and qx * qx + qy * qy < (15 + g * 0.3) ^ 2 then
          a.x = px
          self:Asche(a)
        elseif rest <= 0 or a.y > SP.HOEHE + 20 then
          a.aktiv = false
          a.t:Hide()
        end
      end
    end
  end

  -- Gefangene Funken im Glas: steigen zum Boden (oben), sammeln sich dort und kreisen sacht
  local voll = 0
  for i, innen in ipairs(self.innen) do
    if innen.aktiv then
      voll = voll + 1
      innen.ein = math.min(1, innen.ein + dt / 0.35)
      local e = 1 - (1 - innen.ein) * (1 - innen.ein)
      local tief = 5 + (i - 1) * 2.6 + math.cos(t * innen.tempo * 1.3 + innen.phase) * 2.5
      local quer = math.sin(t * innen.tempo + innen.phase) * 9
      local sx, sy = gx + fo.ax * tief + fo.qx * quer, gy + fo.ay * tief + fo.qy * quer
      local x, y = mx + (sx - mx) * e, my + (sy - my) * e
      innen.t:SetAlpha(0.75 + 0.25 * math.sin(t * 9 + innen.phase))
      setze(innen.t, x, y, 9 - 2 * e)
    end
  end
  self.blitz = math.max(0, (self.blitz or 0) - dt * 4)
  self.licht:SetAlpha(begrenzt(voll / VOLL * 0.8 * (0.9 + 0.1 * math.sin(t * 7)) + self.blitz * 0.45, 0, 1))

  -- Funkenregen und Wirbel
  for _, g in ipairs(self.glanz) do
    if g.aktiv then
      g.alter = g.alter + dt
      local k2 = g.alter / g.leben
      if k2 >= 1 then g.aktiv = false g.t:Hide() else
        if g.wirbel then
          local w = g.winkel + g.alter * 7
          local rad = g.radius + 46 * k2
          g.x, g.y = g.mx + math.cos(w) * rad, g.my + 70 * g.alter + math.sin(w) * rad * 0.45
        else
          local zaeh = math.exp(-dt * 5)
          g.vx, g.vy = g.vx * zaeh, g.vy * zaeh
          g.x, g.y = g.x + g.vx * dt, g.y + g.vy * dt
        end
        g.t:SetAlpha(1 - k2)
        setze(g.t, g.x, g.y, g.groesse * (1 - 0.5 * k2))
      end
    end
  end
  for _, fl in ipairs(self.flocken) do
    if fl.aktiv then
      fl.alter = fl.alter + dt
      local k2 = fl.alter / fl.leben
      if k2 >= 1 then fl.aktiv = false fl.t:Hide() else
        fl.vy = fl.vy - 60 * dt
        fl.x, fl.y = fl.x + fl.vx * dt, fl.y + fl.vy * dt
        fl.t:SetAlpha(0.9 * (1 - k2))
        setze(fl.t, fl.x, fl.y, fl.groesse)
      end
    end
  end

  -- Feuerschein flackert, beim Knistern heller
  self.knistern = math.max(0, (self.knistern or 0) - dt * 4)
  self.glut:SetAlpha(0.42 + 0.2 * math.sin(t * 8) * math.sin(t * 2.9) + 0.35 * self.knistern)

  -- Kombo neben dem Glas, verblasst, wenn die Zeit für den nächsten Fang abläuft
  if self.ketteBis and jetzt >= self.ketteBis then
    self.kette, self.multi, self.ketteBis = 0, 1, nil
    self.kombo:SetText("")
  end
  if self.multi > 1 and self.ketteBis then
    local rechts = gx < SP.BREITE - 70
    self.kombo:ClearAllPoints()
    self.kombo:SetPoint(rechts and "LEFT" or "RIGHT", self.r, "BOTTOMLEFT", gx + (rechts and 20 or -20), gy - 16)
    self.kombo:SetAlpha(0.35 + 0.65 * (self.ketteBis - jetzt) / KETTE_ZEIT)
    if self.komboFarbe then
      self.komboFarbe = self.komboFarbe - dt
      if self.komboFarbe <= 0 then
        self.komboFarbe = nil
        self.kombo:SetTextColor(F.akzent[1], F.akzent[2], F.akzent[3])
      end
    end
  end
  -- Hinweis zu Beginn, dann ausblenden
  if self.hinweis:IsShown() then
    local h = 1 - (t - 3) / 1
    if h <= 0 then self.hinweis:Hide() else self.hinweis:SetAlpha(math.min(1, h)) end
  end
end

SP.Registrieren(FK)
