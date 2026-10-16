-- Murloc Dive: Ein echter Murloc taucht durch einen See bei Mondlicht. Ein Klick gibt einen
-- Schwimmzug nach oben, sonst sinkt er langsam. Von rechts kommen Hindernisse: Tang und Felssäulen
-- vom Grund, Fischernetze und Anker an der Kette von oben. Jede Lücke gibt einen Punkt, Perlen zwei,
-- goldene Muscheln fünf. Mit jeder Lücke wird es etwas enger und schneller. Ein Stoß (oder der
-- Sand), und der Murloc treibt benommen nach oben: Spielende.
-- Übernommen ist nur das Prinzip (ein Knopf, Lücken), Name, Szene und Figur sind unsere eigenen.
-- Der Rekord-Schlüssel bleibt "flap" (so hieß das Spiel vorher), damit alte Rekorde gelten.
--
-- Grafik: Blender-Szene grafik/blender/unterwasser.py, gepackt von tools/grafik/unterwasser.js in
-- Media/Unterwasser.tga, Lage und Trefferprofile in Unterwasser.lua. Zwei nahtlose Ebenen: hinten
-- Felsen, Tangwald und Mondstrahlen (zieht langsam vorbei), vorn der Seegrund (im Spieltempo). Die
-- Hindernisse sind hohe Bilder, die am Rand der Fläche abgeschnitten werden, gestreckt wird nichts.
-- Ihre Trefferfläche kommt aus dem Bild selbst (Profil je 4 Pixel), also trifft nur, was man sieht.
-- Der Murloc ist ein 3D-Modell wie in der Show: Murky (15369), sonst der große Murloc (31), mit
-- Schwimm-Animation, Blick nach rechts, in einem Rahmen mit viel Rand (RAND), damit die breite
-- Schwimmhaltung nicht an der Rahmenkante abgeschnitten wird. Modelle werden von der Spielfläche
-- nicht beschnitten: sein Rahmen bleibt immer ganz in der Fläche. Lädt kein Modell, schwimmt der
-- Murloc-Kopf als Bild.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F = S.F
local SP = ns.Spiel
local UW = S.UNTERWASSER

local BREITE, HOEHE = SP.BREITE, SP.HOEHE
local KOPF = "Interface\\Icons\\INV_Misc_Head_Murloc_01"
local MURKY, ERSATZ = 15369, 31
local RECHTS = math.pi / 2
local MX, GROESSE, RADIUS = 74, 52, 10     -- Murloc: feste Spalte, sichtbare Größe, Trefferkreis
-- Rahmen des Modells deutlich größer als der Murloc: Die Schwimmhaltung ist breiter als die
-- Standhaltung, auf die das Spiel die Kamera einpasst, sonst schneidet die Rahmenkante ihn gerade
-- ab (Patricks Test im Spiel). Die Kamera rückt um denselben Faktor weg (SetCamDistanceScale),
-- so bleibt der Murloc so groß wie vorher. Trefferkreis und Blasen hängen an der Mitte des
-- Murlocs, nicht am Rahmen.
local RAND = 1.6
local FIGUR = GROESSE * RAND
local KOPF_GROESSE = 26                     -- Ersatzbild, wenn kein Modell lädt
local SINKEN, ZUG, MAX_SINKEN = 300, -150, 135
local ABSTAND = 150                         -- zwischen zwei Hindernis-Paaren
local LUECKE_START, LUECKE_MIN = 86, 60
local TEMPO_START, TEMPO_MAX = 68, 125
local FERNE = 0.3                           -- die ferne Ebene zieht langsamer vorbei
local GNADE = 2                             -- Trefferflächen je Seite etwas kleiner als das Bild
local PAARE, PERLEN, BLASEN = 3, 3, 20
local OBEN_ARTEN, UNTEN_ARTEN = { "netz", "anker" }, { "tang", "fels" }
local WERT = { perle = 2, muschel = 5 }
-- Animationen mit Ersatz, falls das Modell eine nicht hat: schwimmen, im Wasser schweben,
-- getroffen zusammenzucken, benommen
local ANIM = { schwimmen = { 42, 4, 0 }, schweben = { 41, 42, 0 }, treffer = { 9, 10, 0 }, benommen = { 14, 41, 0 } }
-- Licht unter Wasser: grünblaues Grundlicht, kühles Mondlicht von oben
local LICHT = { amb = { 0.42, 0.66, 0.78 }, ai = 0.9, dif = { 0.75, 0.9, 1 }, di = 0.8 }
local GRUEN, GOLD, ROT = { 0.4, 0.84, 0.56, 1 }, { 1, 0.84, 0.25, 1 }, { 1, 0.4, 0.3, 1 }

local FL = { key = "flap", musik = "teich", name = L.GAME_DIVE, info = L.GAME_DIVE_INFO,
  icon = "Interface\\Icons\\Ability_Druid_AquaticForm", FIGUR = FIGUR,
  legende = {
    { bild = UW.datei, coords = UW.symbol, punkte = 1 },
    { bild = UW.datei, coords = UW.perle, punkte = WERT.perle },
    { bild = UW.datei, coords = UW.muschel, punkte = WERT.muschel },
  } }

-- Hilfen -------------------------------------------------------------------------------------

-- Bild t mit Ausschnitt k (Texturkoordinaten links, rechts, oben, unten) auf das Rechteck x1..x2,
-- y1..y2 der Fläche legen (von oben links, y nach unten). Was über den Rand ragt, wird abgeschnitten:
-- Bildfläche und Ausschnitt schrumpfen gemeinsam, nichts wird gestreckt und nichts ragt hinaus.
local function legen(r, t, k, x1, y1, x2, y2)
  local a1, b1 = math.max(0, x1), math.max(0, y1)
  local a2, b2 = math.min(BREITE, x2), math.min(HOEHE, y2)
  if a2 - a1 < 0.5 or b2 - b1 < 0.5 then
    t:Hide()
    return
  end
  local su, sv = (k[2] - k[1]) / (x2 - x1), (k[4] - k[3]) / (y2 - y1)
  t:SetTexCoord(k[1] + (a1 - x1) * su, k[1] + (a2 - x1) * su, k[3] + (b1 - y1) * sv, k[3] + (b2 - y1) * sv)
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", r, "TOPLEFT", a1, -b1)
  t:SetSize(a2 - a1, b2 - b1)
  t.l, t.o, t.r, t.u = a1, b1, a2, b2
  t:Show()
end

-- Trifft der Kreis (cx, cy, r) das Hindernis art mit Mitte mx und Spitze (Kante zur Lücke) bei
-- spitze? Geprüft werden nur die Profilbänder, die der Kreis senkrecht überdeckt.
local function trifft(art, mx, spitze, cx, cy, r)
  local p, band = art.profil, UW.band
  local von, bis
  if art.oben then von, bis = spitze - (cy + r), spitze - (cy - r)
  else von, bis = (cy - r) - spitze, (cy + r) - spitze end
  if bis < 0 then return false end
  local k0, k1 = math.max(0, math.floor(von / band)), math.min(#p / 2 - 1, math.floor(bis / band))
  for k = k0, k1 do
    local links, rechts = p[2 * k + 1] + GNADE, p[2 * k + 2] - GNADE
    if rechts > links then
      local x1, x2 = mx + links, mx + rechts
      local y1, y2
      if art.oben then y1, y2 = spitze - (k + 1) * band, spitze - k * band
      else y1, y2 = spitze + k * band, spitze + (k + 1) * band end
      local nx = math.max(x1, math.min(cx, x2))
      local ny = math.max(y1, math.min(cy, y2))
      if (cx - nx) ^ 2 + (cy - ny) ^ 2 < r * r then return true end
    end
  end
  return false
end
FL.trifft = trifft

local function geladen(m)
  if not m then return false end
  local ok, datei = pcall(m.GetModelFileID, m)
  return ok and type(datei) == "number" and datei > 0
end

-- Licht wie in Whack-a-Murloc, nur unter Wasser. Beide Formen von SetLight versuchen.
local function licht(m)
  if not (m and m.SetLight) then return end
  local ok = false
  if CreateColor and CreateVector3D then
    ok = pcall(m.SetLight, m, true, {
      omnidirectional = false, point = CreateVector3D(-0.3, 0.6, -0.9),
      ambientIntensity = LICHT.ai, ambientColor = CreateColor(LICHT.amb[1], LICHT.amb[2], LICHT.amb[3]),
      diffuseIntensity = LICHT.di, diffuseColor = CreateColor(LICHT.dif[1], LICHT.dif[2], LICHT.dif[3]),
    })
  end
  if not ok then
    pcall(m.SetLight, m, true, false, -0.3, 0.6, -0.9, LICHT.ai, LICHT.amb[1], LICHT.amb[2], LICHT.amb[3],
      LICHT.di, LICHT.dif[1], LICHT.dif[2], LICHT.dif[3])
  end
end

-- Kamera um RAND weiter weg: im großen Rahmen bleibt der Murloc so groß wie vorher
local function kamera(m)
  if m and m.SetCamDistanceScale then pcall(m.SetCamDistanceScale, m, RAND) end
end

-- Modell laden (nach jedem SetDisplayInfo die Kamera neu setzen)
local function zeigen(m, display)
  pcall(m.SetDisplayInfo, m, display)
  kamera(m)
end

-- Aufbau ---------------------------------------------------------------------------------------

function FL:Bauen(r)
  self.r = r
  local basis = (r.GetFrameLevel and r:GetFrameLevel()) or 1
  local function bild(ebene, unter)
    local t = r:CreateTexture(nil, ebene, nil, unter)
    t:SetTexture(UW.datei)
    t:Hide()
    return t
  end
  -- Ebenen von hinten nach vorn: ferne Ebene, Seegrund, Hindernisse (immer ganz zu sehen, auch
  -- zwischen den Pflanzen am Grund), Perlen, Blasen, darüber in eigenem Rahmen der Murloc
  self.fern = { bild("BACKGROUND", 1), bild("BACKGROUND", 1) }
  self.grund = { bild("BORDER", 0), bild("BORDER", 0) }
  self.paare = {}
  for i = 1, PAARE do self.paare[i] = { oben = bild("ARTWORK", 0), unten = bild("ARTWORK", 0) } end
  self.perlen = {}
  for i = 1, PERLEN do self.perlen[i] = { t = bild("ARTWORK", 3) } end
  self.blasen = {}
  for i = 1, BLASEN do self.blasen[i] = { t = bild("ARTWORK", 5) } end
  self.ersatz = r:CreateTexture(nil, "OVERLAY")
  self.ersatz:SetSize(KOPF_GROESSE, KOPF_GROESSE)
  self.ersatz:SetTexture(KOPF)
  self.ersatz:Hide()
  -- Murloc als Modell
  local ok, m = pcall(CreateFrame, "PlayerModel", nil, r)
  if ok and m and m.SetDisplayInfo then
    m:SetSize(FIGUR, FIGUR)
    m:SetFrameLevel(basis + 6)
    -- sonst wirft das Modell beim Verstecken alles weg
    if m.SetKeepModelOnHide then pcall(m.SetKeepModelOnHide, m, true) end
    -- Ist das Modell fertig geladen, setzt das Spiel die Kamera zurück: Abstand noch einmal setzen
    m:SetScript("OnModelLoaded", function(self) kamera(self) end)
    m.display = MURKY
    zeigen(m, MURKY)
    self.modell = m
  end
  self.text = S.schrift(r, "GameFontNormalLarge", F.akzent)
  self.text:SetPoint("TOP", 0, -40)
  -- Ganze Fläche: Klick = Schwimmzug (über dem Modell, damit jeder Klick ankommt)
  local knopf = CreateFrame("Button", nil, r)
  knopf:SetAllPoints()
  knopf:SetFrameLevel(basis + 10)
  knopf:SetScript("OnMouseDown", function() FL:Schwimmen() end)
  self.knopf = knopf
end

-- Modell ------------------------------------------------------------------------------------------

function FL:Anim(name)
  local m = self.modell
  if not (self.dreiD and m) or self.anim == name then return end
  self.anim = name
  for _, id in ipairs(ANIM[name]) do
    local hat = true
    if m.HasAnimation then
      local ok, ja = pcall(m.HasAnimation, m, id)
      if ok and ja ~= nil then hat = ja end
    end
    if hat then
      pcall(m.SetAnimation, m, id)
      return
    end
  end
end

-- Erst zeigen, dann laden: versteckte Modelle laden nicht zuverlässig. Pruefen schaut jedes Bild nach.
function FL:FigurLaden()
  self.dreiD, self.ladenSeit, self.aufgegeben, self.anim = false, nil, nil, nil
  if self.modell then self.modell:Show() end
  self:Pruefen(ns.jetzt())
end

-- Ist das Modell da? Wenn nicht nach einem Moment, der große Murloc als Ersatz. Lädt auch der
-- nicht, bleibt es beim Bild (kommt das Modell doch noch, schwimmt ab dann das Modell).
function FL:Pruefen(jetzt)
  local m = self.modell
  if m and not self.dreiD then
    if geladen(m) then
      self.dreiD = true
      kamera(m)
      licht(m)
      pcall(m.SetFacing, m, RECHTS)
      self.anim = nil
      self:Anim(self.phase == "warten" and "schweben" or (self.phase == "schwimmen" and "schwimmen" or "benommen"))
    elseif not self.ladenSeit then
      if not (m.IsVisible and not m:IsVisible()) then
        self.ladenSeit = jetzt
        zeigen(m, m.display)
      end
    elseif not self.aufgegeben and jetzt - self.ladenSeit > 0.8 then
      if m.display ~= ERSATZ then
        m.display, self.ladenSeit = ERSATZ, jetzt
        zeigen(m, ERSATZ)
      else
        self.aufgegeben = true
      end
    end
  end
  self.ersatz:SetShown(not self.dreiD)
end

-- Runde --------------------------------------------------------------------------------------------

function FL:Start()
  self.phase, self.durch = "warten", 0
  self.grundY = HOEHE - (UW.boden or 14)
  -- Spielraum der Murloc-Mitte: oben und unten bleibt der (große) Rahmen ganz in der Fläche.
  -- Unten liegt der Murloc selbst dann gerade auf dem Sand (sichtbare Größe), das ist der Grund.
  self.obenY = FIGUR / 2
  self.untenY = math.min(self.grundY - GROESSE / 2, HOEHE - FIGUR / 2)
  self.startY = (self.obenY + self.untenY) / 2
  self.y, self.v, self.weg, self.tempo, self.wackeln = self.startY, 0, 0, TEMPO_START, 0
  local jetzt = ns.jetzt()
  self.blaseBis, self.grundBlase = jetzt, jetzt + 0.4
  for _, p in ipairs(self.perlen) do p.aktiv = false p.t:Hide() end
  for _, b in ipairs(self.blasen) do b.aktiv = false b.t:Hide() end
  local vorher
  for i, paar in ipairs(self.paare) do
    self:NeuesPaar(paar, BREITE + 70 + (i - 1) * ABSTAND, vorher)
    vorher = paar
  end
  self.text:SetText(L.DIVE_START)
  self:FigurLaden()
  self:Zeichnen(jetzt)
end

-- Neues Hindernis-Paar bei x. vorher: das Paar davor (die Lücke springt nicht zu weit, dazwischen
-- liegt manchmal eine Perle oder eine goldene Muschel)
function FL:NeuesPaar(paar, x, vorher)
  local luecke = math.max(LUECKE_MIN, LUECKE_START - self.durch * 1.2)
  local oben = UW.hindernisse[OBEN_ARTEN[math.random(1, #OBEN_ARTEN)]]
  local unten = UW.hindernisse[UNTEN_ARTEN[math.random(1, #UNTEN_ARTEN)]]
  -- Platz unter der Oberfläche und über dem Sand. Beide Bilder reichen bis über den Rand der Fläche.
  local minM = math.max(luecke / 2 + 18, HOEHE - unten.h - luecke / 2)
  local maxM = math.min(self.grundY - luecke / 2 - 14, oben.h + luecke / 2)
  local mitte = SP.zufall(minM, maxM)
  if vorher then mitte = math.max(minM, math.min(maxM, math.max(vorher.mitte - 75, math.min(vorher.mitte + 75, mitte)))) end
  paar.x, paar.luecke, paar.mitte, paar.gezaehlt = x, luecke, mitte, false
  paar.obenArt, paar.untenArt = oben, unten
  paar.halb = math.max(oben.b, unten.b) / 2
  if vorher and math.random() < 0.6 then
    self:PerleSetzen(x - ABSTAND / 2, (vorher.mitte + mitte) / 2 + SP.zufall(-18, 18))
  end
end

function FL:PerleSetzen(x, y)
  for _, p in ipairs(self.perlen) do
    if not p.aktiv then
      p.aktiv, p.weg, p.x = true, nil, x
      p.y = math.max(self.obenY + 4, math.min(self.untenY - 4, y))
      p.art = math.random() < 0.18 and "muschel" or "perle"
      p.groesse = p.art == "muschel" and 17 or 13
      p.phase = math.random() * 6
      p.t:SetAlpha(1)
      return p
    end
  end
end

-- Luftblase: steigt auf, schwankt und treibt mit dem Wasser. Gibt sie zurück (oder nil, wenn alle unterwegs sind).
function FL:Blase(x, y, groesse, vy, vx)
  for _, b in ipairs(self.blasen) do
    if not b.aktiv then
      b.aktiv, b.x, b.y, b.s, b.alter = true, x, y, groesse, 0
      b.vx, b.vy = vx or 0, vy or -30
      b.leben, b.phase = SP.zufall(1.6, 2.6), math.random() * 6
      return b
    end
  end
end

-- Klick: ein Schwimmzug nach oben
function FL:Schwimmen()
  if not (SP.laeuft and SP.aktiv == self) or SP.pause then return end
  if self.phase == "warten" then
    self.phase = "schwimmen"
    self.text:SetText("")
    self:Anim("schwimmen")
  elseif self.phase ~= "schwimmen" then
    return
  end
  self.v = ZUG
  ns.ton("plopp")
  self:Blase(MX - 12, self.y + 9, 5, -22, -30)
  self:Blase(MX - 17, self.y + 5, 4, -30, -24)
end

-- Getroffen (oder im Sand gelandet): kurz zusammenzucken, dann treibt er benommen nach oben
function FL:Stoss(sand)
  self.phase, self.endeSeit, self.v = "treffer", ns.jetzt(), 0
  self:Anim("treffer")
  ns.ton("boom")
  ns.mrgl(0.6)
  SP:Ruf(SP.spruch(sand and L.DIVE_SAND or L.DIVE_BONK), MX + 44, -math.max(24, self.y - 16), ROT)
  for _ = 1, 8 do
    self:Blase(MX + SP.zufall(-10, 12), self.y + SP.zufall(-8, 8), SP.zufall(3, 7), SP.zufall(-55, -25), SP.zufall(-25, 25))
  end
end

function FL:Sammeln(p, jetzt)
  p.weg = jetzt
  local wert = WERT[p.art]
  SP:Plus(wert)
  local text = "+" .. wert
  if p.art == "muschel" then text = L.DIVE_SHELL .. " " .. text end
  SP:Ruf(text, p.x, -(p.y - 10), p.art == "muschel" and GOLD or GRUEN)
  ns.ton(p.art == "muschel" and "muenze" or "treffer")
  self:Blase(p.x, p.y, 4, -40, 10)
  self:Blase(p.x + 4, p.y + 3, 3, -30, -5)
end

-- Spielschritt: schwimmen und sinken, Hindernisse und Perlen ziehen vorbei
function FL:Bewegen(dt, jetzt)
  self.v = math.min(MAX_SINKEN, self.v + SINKEN * dt)
  self.y = self.y + self.v * dt
  -- An der Oberfläche ist Schluss: der Rahmen des Modells bleibt ganz in der Fläche
  if self.y < self.obenY then self.y, self.v = self.obenY, math.max(0, self.v) end
  self.tempo = math.min(TEMPO_MAX, TEMPO_START + self.durch * 2)
  local dx = self.tempo * dt
  self.weg = self.weg + dx
  local rechts
  for _, paar in ipairs(self.paare) do if not rechts or paar.x > rechts.x then rechts = paar end end
  local rechtsX = rechts.x
  for _, paar in ipairs(self.paare) do
    paar.x = paar.x - dx
    if paar.x < -paar.halb - 4 then
      self:NeuesPaar(paar, rechtsX + ABSTAND - dx, rechts)
    end
    if trifft(paar.obenArt, paar.x, paar.mitte - paar.luecke / 2, MX, self.y, RADIUS)
      or trifft(paar.untenArt, paar.x, paar.mitte + paar.luecke / 2, MX, self.y, RADIUS) then
      return self:Stoss(false)
    end
    if not paar.gezaehlt and paar.x + paar.halb < MX - RADIUS then
      paar.gezaehlt = true
      self.durch = self.durch + 1
      SP:Plus(1)
      if self.durch % 10 == 0 then
        SP:Ruf(SP.spruch(L.DIVE_STREAK), BREITE / 2, -56, GRUEN)
        ns.ton("muenze")
      end
    end
  end
  for _, p in ipairs(self.perlen) do
    if p.aktiv then
      p.x = p.x - dx
      if p.x < -p.groesse then
        p.aktiv = false
        p.t:Hide()
      elseif not p.weg and (p.x - MX) ^ 2 + (p.y - self.y) ^ 2 < (RADIUS + p.groesse / 2) ^ 2 then
        self:Sammeln(p, jetzt)
      end
    end
  end
  -- Im Sand gelandet
  if self.y >= self.untenY then
    self.y = self.untenY
    return self:Stoss(true)
  end
  -- Blasen aus dem Maul
  if jetzt >= self.blaseBis then
    self.blaseBis = jetzt + SP.zufall(0.22, 0.4)
    self:Blase(MX + 11, self.y - 5, SP.zufall(3, 4.5), -26, 0)
  end
end

-- Spielende: zucken, dann benommen nach oben treiben, dann die Tafel
function FL:Ende(dt, jetzt)
  local t = jetzt - self.endeSeit
  if self.phase == "treffer" then
    self.wackeln = math.sin(t * 45) * 2.5 * math.max(0, 1 - t / 0.45)
    if t >= 0.45 then
      self.phase, self.wackeln = "auftrieb", 0
      self:Anim("benommen")
    end
    return
  end
  self.v = math.max(-34, self.v - 50 * dt)
  self.y = math.max(self.obenY, self.y + self.v * dt)
  self.wackeln = math.sin(t * 3) * 1.5
  if jetzt >= self.blaseBis then
    self.blaseBis = jetzt + SP.zufall(0.15, 0.3)
    self:Blase(MX + SP.zufall(-6, 10), self.y - 4, SP.zufall(3, 5), -35, 0)
  end
  if t >= 2.1 then SP:Fertig() end
end

function FL:Tick(dt, jetzt)
  dt = math.min(dt, 0.05)
  if not self.dreiD then self:Pruefen(jetzt) end
  local strom = 0
  if self.phase == "warten" then
    -- Vor dem ersten Klick: im Wasser schweben
    self.y = self.startY + math.sin(jetzt * 2.2) * 5
  elseif self.phase == "schwimmen" then
    self:Bewegen(dt, jetzt)
    strom = self.tempo
  elseif self.phase == "treffer" or self.phase == "auftrieb" then
    self:Ende(dt, jetzt)
  end
  -- ab und zu steigen Blasen vom Grund auf
  if jetzt >= self.grundBlase then
    self.grundBlase = jetzt + SP.zufall(0.7, 1.8)
    self:Blase(SP.zufall(120, BREITE - 8), self.grundY - 3, SP.zufall(2.5, 4.5), -16, 0)
  end
  for _, b in ipairs(self.blasen) do
    if b.aktiv then
      b.alter = b.alter + dt
      b.vy = math.max(-55, b.vy - 25 * dt)
      b.x = b.x + (b.vx - strom) * dt + math.sin(b.alter * 6 + b.phase) * 10 * dt
      b.vx = b.vx * (1 - math.min(1, 2 * dt))
      b.y = b.y + b.vy * dt
      if b.alter >= b.leben or b.y < b.s or b.x < -b.s then
        b.aktiv = false
        b.t:Hide()
      end
    end
  end
  self:Zeichnen(jetzt)
end

-- Zeichnen ----------------------------------------------------------------------------------------

function FL:Zeichnen(jetzt)
  local r = self.r
  -- Ebenen: je zwei Stücke, die nahtlos aneinander vorbeiziehen
  local o = (self.weg * FERNE) % BREITE
  legen(r, self.fern[1], UW.hinten, -o, 0, BREITE - o, HOEHE)
  legen(r, self.fern[2], UW.hinten, BREITE - o, 0, 2 * BREITE - o, HOEHE)
  o = self.weg % BREITE
  local gh = UW.vorn.hoehe
  legen(r, self.grund[1], UW.vorn, -o, HOEHE - gh, BREITE - o, HOEHE)
  legen(r, self.grund[2], UW.vorn, BREITE - o, HOEHE - gh, 2 * BREITE - o, HOEHE)
  -- Hindernisse: oben hängt das Bild an der Spitze nach oben, unten steht es auf ihr
  for _, paar in ipairs(self.paare) do
    local a, b = paar.obenArt, paar.untenArt
    local so, su = paar.mitte - paar.luecke / 2, paar.mitte + paar.luecke / 2
    legen(r, paar.oben, a, paar.x - a.b / 2, so - a.h, paar.x + a.b / 2, so)
    legen(r, paar.unten, b, paar.x - b.b / 2, su, paar.x + b.b / 2, su + b.h)
  end
  -- Perlen wippen, gesammelte werden groß und verblassen
  for _, p in ipairs(self.perlen) do
    if p.aktiv then
      local g, alpha = p.groesse, 1
      if p.weg then
        local f = (jetzt - p.weg) / 0.3
        if f >= 1 then
          p.aktiv = false
        end
        g, alpha = g * (1 + 0.8 * math.min(1, f)), math.max(0, 1 - f)
      end
      if p.aktiv then
        local y = p.y + math.sin(jetzt * 2.5 + p.phase) * 2
        legen(r, p.t, UW[p.art], p.x - g / 2, y - g / 2, p.x + g / 2, y + g / 2)
        p.t:SetAlpha(alpha)
      else
        p.t:Hide()
      end
    end
  end
  -- Blasen: verblassen am Ende und kurz unter der Oberfläche
  for _, b in ipairs(self.blasen) do
    if b.aktiv then
      local h = b.s / 2
      legen(r, b.t, UW.blase, b.x - h, b.y - h, b.x + h, b.y + h)
      b.t:SetAlpha(math.max(0, math.min(1, (b.leben - b.alter) / 0.4, (b.y - h) / 14)) * 0.9)
    end
  end
  -- Murloc: wippt leicht, sein Rahmen bleibt ganz in der Fläche
  local wipp = math.sin(jetzt * 4.2) * 1.5
  local zy = math.max(FIGUR / 2, math.min(HOEHE - FIGUR / 2, self.y + wipp))
  local zx = MX + (self.wackeln or 0)
  self.figurY = zy
  if self.dreiD and self.modell then
    self.modell:ClearAllPoints()
    self.modell:SetPoint("CENTER", r, "TOPLEFT", zx, -zy)
  else
    local e = self.ersatz
    e:ClearAllPoints()
    e:SetPoint("CENTER", r, "TOPLEFT", zx, -zy)
    -- 2D: nach oben geneigt beim Steigen, nach unten beim Sinken
    e:SetRotation(-math.max(-0.5, math.min(0.6, (self.v or 0) / 260)))
  end
end

function FL:Stop()
  self.phase = "aus"
end

SP.Registrieren(FL)
