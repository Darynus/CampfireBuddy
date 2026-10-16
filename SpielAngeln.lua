-- Lagerfeuer-Angeln: ruhiges Angeln an einem Waldteich bei Nacht, mit Murky am Ufer.
--
-- Auswerfen: Maus halten, die Wurfweite pendelt hin und her (Balken unten, ein blasser Schwimmer
-- zeigt die Stelle, darüber Shallow, Deep oder Too far). Loslassen wirft: Der Schwimmer fliegt im
-- Bogen und landet mit Spritzer und Wellen. Die Richtung kommt von der Maus. In der Mitte des Teichs
-- ist es tief (größere und seltene Fische), am Ufer flach (kleine Fische, mehr Beifang). Zu weit
-- geworfen, hängt der Schwimmer im Schilf.
-- Anbiss: Ein Schatten schwimmt heran (der goldene schimmert golden), knabbert ein paar Mal (der
-- Schwimmer zuckt nur), dann zieht er ihn ganz unter, mit Spritzer. Wer beim Knabbern klickt,
-- verscheucht ihn, wer beim Abtauchen klickt, hat ihn am Haken. Seltene Fische ziehen nur kurz.
-- Beifang knabbert nicht, der Schwimmer sinkt langsam (etwas Schweres).
-- Drill: Maus halten holt ein, loslassen gibt Schnur. Die Spannung muss im grünen Feld bleiben: zu
-- straff reißt die Schnur, zu lange locker schüttelt der Fisch den Haken ab. Zieht der Fisch (es
-- spritzt), lieber loslassen. Große Fische ziehen stärker und öfter. Rute biegt sich, die Schnur
-- hängt durch, wenn sie locker ist.
-- Fang: Der Fisch springt aus dem Wasser, eine Karte zeigt Art, Größe und Punkte. Das Fangbuch
-- (CampfireBuddyDB.fangbuch, größte Fänge in fangmass) füllt sich über alle Abende, oben rechts
-- lässt es sich aufschlagen. Acht Würmer pro Spiel: Jeder Fisch, der an den Haken will, nimmt einen.
-- Leer einholen kostet nichts.
--
-- Grafiken aus Blender (grafik/blender/angeln.py, Atlas Media/Angeln.tga, Lage in Angeln.lua),
-- Hintergrund Media/Teich.tga. Murky ist ein echtes Modell (15369, sonst der große Murloc 31) und
-- steht ganz innerhalb der Fläche, lädt keins, fehlt er einfach.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba
local SP = ns.Spiel

local B, H = SP.BREITE, SP.HOEHE
local KOEDER = 8
local ATLAS = S.ANGELN_ATLAS or {}
local TIEFE = S.ANGELN_TIEFE or {}
local SPITZE = S.ANGELN_SPITZE or {}
local WASSERLINIE = S.ANGELN_WASSERLINIE or 0.64
local FUSS = S.ANGELN_SPRITZER_FUSS or 0.66
local ROD = 118                                       -- Kantenlänge der Rute auf der Fläche
local ROD_X, ROD_Y = B - ROD + 6, H - ROD + 2         -- oben links der Rute, der Griff ragt unten rechts hinaus
local HUD_X, HUD_B = 92, 96                           -- Balken unten zwischen Murky und Rute
local LEINE_TEILE = 8
local MURKY, MURLOC_ERSATZ, MURKY_GROESSE = 15369, 31, 64
-- Rahmen des Modells deutlich größer als der sichtbare Murky, die Kamera zoomt um denselben Faktor
-- heraus: sonst schneidet der Rahmen Posen ab, die breiter sind als das Stehen (Jubeln, Brüllen)
local RAND = 1.6
local MURKY_RAHMEN = MURKY_GROESSE * RAND
-- Der Rahmen steht ganz in der Fläche (unten links bei 2, 2). Die Kamera mittelt das Modell, die
-- Füße stehen also um MURKY_GROESSE * (RAND - 1) / 2 über der Unterkante des Rahmens.
local MURKY_X = 2 + MURKY_RAHMEN / 2                  -- Mitte von Murky auf der Fläche
local MURKY_KOPF = H - 2 - MURKY_GROESSE * (RAND - 1) / 2 - MURKY_GROESSE   -- y über dem Kopf (von oben)
local MURKY_BLICK = 0.95                              -- schaut nach rechts zum Teich
local TIEF_AB = 5                                     -- ab dieser Tiefe (1 bis 9) gilt das Wasser als tief

local QUALITAET = { [0] = { 0.62, 0.62, 0.62, 1 }, { 1, 1, 1, 1 }, { 0.12, 1, 0, 1 }, { 0.25, 0.6, 1, 1 },
  { 0.78, 0.45, 1, 1 }, { 1, 0.78, 0.2, 1 } }

-- Fische: Punkte, Größe in cm, kraft (0 bis 1: wie stark er zieht), fenster (so lange zieht er den
-- Schwimmer unter), knabbern (wie oft vorher), Gewicht im flachen und im tiefen Wasser, laenge
-- (Größe von Schatten und Sprung), glanz (Farbe des Schimmers unter Wasser, nur seltene)
local FISCHE = {
  { key = "elritze", name = L.FISH_1, q = 1, punkte = 1, cm = { 5, 12 }, kraft = 0.12, fenster = 1.0,
    knabbern = { 2, 4 }, flach = 30, tief = 4, laenge = 0.25 },
  { key = "sonnenbarsch", name = L.FISH_2, q = 1, punkte = 2, cm = { 11, 25 }, kraft = 0.25, fenster = 0.95,
    knabbern = { 1, 3 }, flach = 26, tief = 6, laenge = 0.38 },
  { key = "brasse", name = L.FISH_3, q = 1, punkte = 3, cm = { 22, 48 }, kraft = 0.38, fenster = 0.9,
    knabbern = { 1, 3 }, flach = 18, tief = 10, laenge = 0.52 },
  { key = "mondlachs", name = L.FISH_4, q = 2, punkte = 5, cm = { 30, 62 }, kraft = 0.55, fenster = 0.8,
    knabbern = { 1, 2 }, flach = 4, tief = 22, laenge = 0.6 },
  { key = "wels", name = L.FISH_5, q = 2, punkte = 6, cm = { 45, 95 }, kraft = 0.72, fenster = 0.85,
    knabbern = { 0, 2 }, flach = 2, tief = 17, laenge = 0.8 },
  { key = "schlammhecht", name = L.FISH_6, q = 3, punkte = 8, cm = { 55, 110 }, kraft = 0.88, fenster = 0.65,
    knabbern = { 0, 1 }, flach = 3, tief = 13, laenge = 0.9 },
  { key = "mrglkarpfen", name = L.FISH_7, q = 4, punkte = 12, cm = { 40, 80 }, kraft = 0.65, fenster = 0.55,
    knabbern = { 0, 1 }, flach = 1, tief = 5, laenge = 0.7, glanz = { 1, 0.62, 0.4 } },
  { key = "sternenfisch", name = L.FISH_8, q = 5, punkte = 25, cm = { 18, 36 }, kraft = 0.8, fenster = 0.42,
    knabbern = { 0, 0 }, flach = 0.4, tief = 1.8, laenge = 0.5, glanz = { 1, 0.78, 0.2 } },
}
local BEIFANG = {
  { key = "stiefel", name = L.FISH_JUNK_1, q = 0, punkte = 0, kraft = 0.1, fenster = 0.9, flach = 6, tief = 3,
    laenge = 0.5, beifang = true },
  { key = "dose", name = L.FISH_JUNK_2, q = 0, punkte = 0, kraft = 0.06, fenster = 0.9, flach = 6, tief = 2,
    laenge = 0.45, beifang = true },
}
local ALLE = {}
for _, f in ipairs(FISCHE) do
  f.bild = "fisch_" .. f.key
  f.bildAuf, f.bildAb = f.bild .. "_auf", f.bild .. "_ab"
  table.insert(ALLE, f)
end
for _, f in ipairs(BEIFANG) do
  f.bild = f.key
  f.bildAuf, f.bildAb = f.bild, f.bild
  table.insert(ALLE, f)
end
local FERN = { FISCHE[1], FISCHE[2], FISCHE[3], FISCHE[4] }   -- springen weit draußen
-- Namen der Bilder fertig, damit im Takt keine Zeichenketten entstehen
local SPRITZER_BILD = { "spritzer1", "spritzer2", "spritzer3", "spritzer4" }
local SCHATTEN_BILD = { "schatten1", "schatten2" }
local GLANZ_BILD = { "schatten_hell1", "schatten_hell2" }

-- Murky: Animation mit Ersatz, falls das Modell eine nicht hat
local MURKY_ANIM = {
  stehen = { 0 }, jubeln = { 68, 55, 0 }, lachen = { 70, 60, 0 }, weinen = { 77, 0 }, zeigen = { 84, 60, 0 },
  bruellen = { 74, 55, 0 }, tanzen = { 69, 68, 0 },
}

local function legendeEintrag(name, punkte)
  local k = ATLAS[name]
  if k then return { bild = S.ANGELN, coords = { k[1], k[2], k[3], k[4] }, punkte = punkte } end
end
local legende = {}
for _, e in ipairs({ { "fisch_elritze", 1 }, { "fisch_mondlachs", 5 }, { "fisch_schlammhecht", 8 },
  { "fisch_mrglkarpfen", 12 }, { "fisch_sternenfisch", 25 }, { "stiefel", 0 } }) do
  local eintrag = legendeEintrag(e[1], e[2])
  if eintrag then table.insert(legende, eintrag) end
end

local A = { key = "angeln", musik = "teich", name = L.GAME_FISHING, info = L.GAME_FISHING_INFO,
  icon = "Interface\\Icons\\INV_Misc_2H_FishingPole_B_01", legende = legende }

-- Hilfen -----------------------------------------------------------------------------------------

local function klemmen(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function zufall(a, b) return a + math.random() * (b - a) end
local function weich(t) t = klemmen(t, 0, 1) return t * t * (3 - 2 * t) end

-- Motiv aus dem Atlas, spiegeln: links und rechts tauschen
local function bild(t, name, spiegeln)
  local k = ATLAS[name]
  if not k then return false end
  if spiegeln then t:SetTexCoord(k[2], k[1], k[3], k[4]) else t:SetTexCoord(k[1], k[2], k[3], k[4]) end
  return true
end

-- Tiefe an einer Stelle der Fläche (x, y von oben links): 0 Ufer, 1 flach bis 9 tief
local function tiefe(x, y)
  local zeile = TIEFE[math.floor(y / 10) + 1]
  if not zeile or x < 0 then return 0 end
  local s = math.floor(x / 10) + 1
  if s > #zeile then return 0 end
  return (string.byte(zeile, s) or 48) - 48
end

-- Wasser in der Spalte bei x: Mitte der obersten und der untersten Zelle mit Wasser
local function spalte(x)
  local s = math.floor(klemmen(x, 0, B - 1) / 10) + 1
  local oben, unten
  for z = 1, #TIEFE do
    if (string.byte(TIEFE[z], s) or 48) > 48 then
      oben = oben or z
      unten = z
    end
  end
  if not oben then return nil end
  return (oben - 1) * 10 + 3, (unten - 1) * 10 + 6
end

-- Spalten mit Wasser von links bis rechts (Wurfrichtung bleibt darin)
local WASSER_LINKS, WASSER_RECHTS = B, 0
for x = 5, B - 5, 10 do
  if spalte(x) then
    WASSER_LINKS = math.min(WASSER_LINKS, x)
    WASSER_RECHTS = math.max(WASSER_RECHTS, x)
  end
end
if WASSER_RECHTS < WASSER_LINKS then WASSER_LINKS, WASSER_RECHTS = 30, B - 30 end

-- Perspektive: hinten (oben) wirkt alles kleiner
local function nah(y) return 0.55 + 0.45 * klemmen((y - 75) / 85, 0, 1) end

local function gewicht(f, d)
  local t = weich((d - 2) / 5)
  local w = f.flach * (1 - t) + f.tief * t
  if f.key == "sternenfisch" and d >= 8 then w = w * 2 end
  return w
end

local function ziehen(d)
  local summe = 0
  for _, f in ipairs(ALLE) do summe = summe + gewicht(f, d) end
  local w = math.random() * summe
  for _, f in ipairs(ALLE) do
    w = w - gewicht(f, d)
    if w <= 0 then return f end
  end
  return ALLE[1]
end

-- Murky-Modell wie in Whack und Show
local function geladen(m)
  if not m then return false end
  local ok, datei = pcall(m.GetModelFileID, m)
  return ok and type(datei) == "number" and datei > 0
end

local function anim(m, liste)
  for _, id in ipairs(liste or MURKY_ANIM.stehen) do
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

-- Mondlicht als Grundlicht, warmes Feuerlicht von links
local function licht(m)
  if not (m and m.SetLight) then return end
  local ok = false
  if CreateColor and CreateVector3D then
    ok = pcall(m.SetLight, m, true, {
      omnidirectional = false, point = CreateVector3D(-0.6, 1, -0.4),
      ambientIntensity = 0.75, ambientColor = CreateColor(0.62, 0.68, 0.92),
      diffuseIntensity = 0.8, diffuseColor = CreateColor(1, 0.74, 0.46),
    })
  end
  if not ok then pcall(m.SetLight, m, true, false, -0.6, 1, -0.4, 0.75, 0.62, 0.68, 0.92, 0.8, 1, 0.74, 0.46) end
end

local function buch() ns.db.fangbuch = ns.db.fangbuch or {} return ns.db.fangbuch end
local function masse() ns.db.fangmass = ns.db.fangmass or {} return ns.db.fangmass end

local function artenImBuch()
  local n, b = 0, buch()
  for _, f in ipairs(FISCHE) do if (b[f.key] or 0) > 0 then n = n + 1 end end
  return n
end

-- Aufbau -------------------------------------------------------------------------------------------

local function textur(eltern, ebene, unter)
  local t = eltern:CreateTexture(nil, ebene, nil, unter)
  t:SetTexture(S.ANGELN)
  t:Hide()
  return t
end

function A:Bauen(r)
  self.r = r
  local basis = (r.GetFrameLevel and r:GetFrameLevel()) or 1
  -- Waldteich bei Nacht aus Blender über die ganze Fläche
  local teich = r:CreateTexture(nil, "BACKGROUND", nil, 3)
  teich:SetAllPoints()
  teich:SetTexture(S.TEICH)
  teich:SetTexCoord(0, S.TEICH_B, 0, S.TEICH_H)

  -- Unter Wasser: Schatten des Fischs, darüber Wellen, Zielmarke, Schnur, Schwimmer, Spritzer
  self.schatten = textur(r, "BORDER", 0)
  self.glanz = textur(r, "BORDER", 1)
  self.wellen = {}
  for i = 1, 10 do
    local w = textur(r, "ARTWORK", 0)
    bild(w, "welle")
    self.wellen[i] = w
  end
  self.ziel = textur(r, "ARTWORK", 1)
  bild(self.ziel, "schwimmer")
  self.ziel:SetAlpha(0.45)
  self.zielText = S.schrift(r, "GameFontHighlightSmall", F.text)
  self.zielText:Hide()
  self.leine = {}
  if r.CreateLine then
    for i = 1, LEINE_TEILE do
      local l = r:CreateLine(nil, "ARTWORK", nil, 2)
      if not l then break end
      l:SetThickness(1)
      l:SetColorTexture(0.86, 0.9, 0.94, 0.55)
      l:Hide()
      self.leine[i] = l
    end
  end
  self.schwimmer = textur(r, "ARTWORK", 3)
  self.spritzer = {}
  for i = 1, 5 do self.spritzer[i] = textur(r, "ARTWORK", 4) end
  self.springer = textur(r, "ARTWORK", 5)   -- Fang springt aus dem Wasser
  self.fern = textur(r, "ARTWORK", 5)       -- Fisch springt weit draußen
  self.rute = textur(r, "ARTWORK", 6)
  self.rute:SetSize(ROD, ROD)
  self.rute:Show()

  -- Murky am Ufer links unten, der (große) Rahmen ganz in der Fläche
  local ok, m = pcall(CreateFrame, "PlayerModel", nil, r)
  if ok and m and m.SetDisplayInfo then
    m:SetSize(MURKY_RAHMEN, MURKY_RAHMEN)
    m:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 2, 2)
    m:SetFrameLevel(basis + 2)
    if m.SetKeepModelOnHide then pcall(m.SetKeepModelOnHide, m, true) end
    -- fertig geladen: Kamera wieder herauszoomen, sonst wirkt er im großen Rahmen riesig
    m:SetScript("OnModelLoaded", function(self)
      if self.SetCamDistanceScale then pcall(self.SetCamDistanceScale, self, RAND) end
    end)
    m:Hide()
    self.murky = m
  end

  -- Maus: halten und loslassen auf der ganzen Fläche
  local fang = CreateFrame("Button", nil, r)
  fang:SetAllPoints()
  fang:SetFrameLevel(basis + 5)
  fang:SetScript("OnMouseDown", function(_, taste) if taste == nil or taste == "LeftButton" then A:Druecken() end end)
  fang:SetScript("OnMouseUp", function(_, taste) if taste == nil or taste == "LeftButton" then A:Loslassen() end end)
  self.flaeche = fang

  self:HudBauen(r, basis)
  -- Texte: Würmer links oben, Fangbuch rechts oben, Hinweis darunter in der Mitte
  self.koederText = S.schrift(r, "GameFontHighlightSmall", F.text)
  self.koederText:SetPoint("TOPLEFT", 8, -6)
  self.hinweis = S.schrift(r, "GameFontNormal", F.text)
  self.hinweis:SetPoint("TOP", 0, -24)
  self:BuchKnopfBauen(r, basis)
  self:KarteBauen(r, basis)
  self:BuchSeiteBauen(r, basis)
end

-- Balken unten: Wurfweite beim Zielen, beim Drill Spannung (grünes Feld) und Fortschritt darüber
function A:HudBauen(r, basis)
  local hud = CreateFrame("Frame", nil, r)
  hud:SetSize(HUD_B, 20)
  hud:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", HUD_X, 4)
  hud:SetFrameLevel(basis + 6)
  local k = S.kasten(hud, "Frame", { 0.02, 0.02, 0.03, 0.85 }, F.rand)
  k:SetSize(HUD_B, 10)
  k:SetPoint("BOTTOMLEFT", 0, 0)
  hud.kasten = k
  local function feld(farbe)
    local t = k:CreateTexture(nil, "ARTWORK", nil, 1)
    t:SetPoint("TOP", k, "TOP", 0, -1)
    t:SetPoint("BOTTOM", k, "BOTTOM", 0, 1)
    t:SetColorTexture(farbe[1], farbe[2], farbe[3], farbe[4])
    return t
  end
  hud.locker = feld({ 0.3, 0.42, 0.6, 0.55 })
  hud.gruen = feld({ 0.25, 0.72, 0.36, 0.8 })
  hud.straff = feld({ 0.86, 0.26, 0.2, 0.7 })
  hud.voll = k:CreateTexture(nil, "ARTWORK", nil, 2)
  hud.voll:SetPoint("TOPLEFT", 1, -1)
  hud.voll:SetPoint("BOTTOMLEFT", 1, 1)
  hud.voll:SetTexture(S.STATUSLEISTE)
  hud.marke = k:CreateTexture(nil, "OVERLAY")
  hud.marke:SetSize(3, 14)
  hud.marke:SetColorTexture(1, 0.95, 0.85, 1)
  local weg = S.kasten(hud, "Frame", { 0.02, 0.02, 0.03, 0.85 }, F.rand)
  weg:SetSize(HUD_B, 5)
  weg:SetPoint("BOTTOMLEFT", 0, 13)
  hud.weg = weg
  hud.wegVoll = weg:CreateTexture(nil, "ARTWORK")
  hud.wegVoll:SetPoint("TOPLEFT", 1, -1)
  hud.wegVoll:SetPoint("BOTTOMLEFT", 1, 1)
  hud.wegVoll:SetColorTexture(rgba(F.stern))
  hud:Hide()
  self.hud = hud
end

-- Feld der Breite (Anteil von bis) im Balken setzen
local function feldSetzen(t, kasten, von, bis)
  local innen = HUD_B - 2
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", kasten, "TOPLEFT", 1 + von * innen, -1)
  t:SetPoint("BOTTOMLEFT", kasten, "BOTTOMLEFT", 1 + von * innen, 1)
  t:SetWidth(math.max(0.5, (bis - von) * innen))
end

function A:BuchKnopfBauen(r, basis)
  local b = CreateFrame("Button", nil, r)
  b:SetSize(62, 18)
  b:SetPoint("TOPRIGHT", -4, -3)
  b:SetFrameLevel(basis + 7)
  b.bild = b:CreateTexture(nil, "ARTWORK")
  b.bild:SetTexture(S.ANGELN)
  b.bild:SetSize(26, 26)
  b.bild:SetPoint("LEFT", -4, 0)
  bild(b.bild, "fisch_mondlachs")
  b.text = S.schrift(b, "GameFontHighlightSmall", F.text)
  b.text:SetPoint("LEFT", b.bild, "RIGHT", -2, 0)
  b:SetScript("OnClick", function() S.klick() A:BuchOeffnen() end)
  b:HookScript("OnEnter", function(self) self.text:SetTextColor(rgba(F.akzent)) end)
  b:HookScript("OnLeave", function(self) self.text:SetTextColor(rgba(F.text)) end)
  S.tooltip(b, L.FISH_BOOK_TITLE, L.FISH_BOOK_HELP)
  self.buchKnopf = b
end

-- Fangkarte: Fisch, Name, Größe, Punkte, darunter neu, Rekord oder großer Fang
function A:KarteBauen(r, basis)
  local k = S.kasten(r, "Frame", { 0.05, 0.04, 0.05, 0.94 }, F.rand)
  k:SetSize(190, 60)
  k:SetFrameLevel(basis + 8)
  k.bild = k:CreateTexture(nil, "ARTWORK")
  k.bild:SetTexture(S.ANGELN)
  k.bild:SetSize(64, 64)
  k.bild:SetPoint("LEFT", -2, 0)
  k.name = S.schrift(k, "GameFontNormal", F.text)
  k.name:SetPoint("TOPLEFT", 62, -8)
  k.name:SetPoint("RIGHT", -40, 0)
  k.name:SetJustifyH("LEFT")
  k.name:SetWordWrap(false)
  k.groesse = S.schrift(k, "GameFontHighlightSmall", F.text)
  k.groesse:SetPoint("TOPLEFT", 62, -25)
  k.marke = S.schrift(k, "GameFontHighlightSmall", F.stern)
  k.marke:SetPoint("TOPLEFT", 62, -40)
  k.marke:SetPoint("RIGHT", -6, 0)
  k.marke:SetJustifyH("LEFT")
  k.marke:SetWordWrap(false)
  k.punkte = S.schrift(k, "GameFontNormalLarge", F.akzent)
  k.punkte:SetPoint("TOPRIGHT", -8, -8)
  k:Hide()
  self.karte = k
end

-- Fangbuch über der ganzen Fläche: acht Fische, gefangene in Farbe mit Zahl und größtem Fang,
-- noch nicht gefangene als Schatten. Klick schließt.
function A:BuchSeiteBauen(r, basis)
  local s = CreateFrame("Button", nil, r)
  s:SetAllPoints()
  s:SetFrameLevel(basis + 12)
  local grund = s:CreateTexture(nil, "BACKGROUND")
  grund:SetAllPoints()
  grund:SetColorTexture(0.02, 0.03, 0.05, 0.93)
  s.titel = S.schrift(s, "GameFontNormal", F.akzent)
  s.titel:SetPoint("TOP", 0, -7)
  s.plaetze = {}
  for i, f in ipairs(FISCHE) do
    local spalte_, reihe = (i - 1) % 4, math.floor((i - 1) / 4)
    local x, y = 6 + spalte_ * 72 + 36, 22 + reihe * 66
    local p = { f = f }
    p.bild = s:CreateTexture(nil, "ARTWORK")
    p.bild:SetTexture(S.ANGELN)
    p.bild:SetSize(58, 58)
    p.bild:SetPoint("TOP", s, "TOPLEFT", x, -y)
    bild(p.bild, f.bild)
    p.name = S.schrift(s, "GameFontHighlightSmall", F.text)
    p.name:SetPoint("TOP", s, "TOPLEFT", x, -(y + 42))
    p.name:SetWidth(71)
    p.name:SetWordWrap(false)
    p.info = S.schrift(s, "GameFontHighlightSmall", F.leise)
    p.info:SetPoint("TOP", s, "TOPLEFT", x, -(y + 54))
    p.info:SetWidth(71)
    p.info:SetWordWrap(false)
    s.plaetze[i] = p
  end
  s.beifang = S.schrift(s, "GameFontHighlightSmall", F.leise)
  s.beifang:SetPoint("BOTTOM", 0, 18)
  s.zu = S.schrift(s, "GameFontHighlightSmall", F.leise)
  s.zu:SetPoint("BOTTOM", 0, 5)
  s.zu:SetText(L.FISH_BOOK_CLOSE)
  s:SetScript("OnClick", function() S.klick() A:BuchSchliessen() end)
  s:Hide()
  self.buchSeite = s
end

-- Fangbuch -----------------------------------------------------------------------------------------

function A:BuchText()
  self.buchKnopf.text:SetText(string.format(L.FISH_BOOK_SHORT, artenImBuch(), #FISCHE))
end

function A:BuchOeffnen()
  if not (SP.laeuft and SP.aktiv == self) then return end
  local s, b, m = self.buchSeite, buch(), masse()
  s.titel:SetText(string.format(L.FISH_BOOK, artenImBuch(), #FISCHE))
  for _, p in ipairs(s.plaetze) do
    local n = b[p.f.key] or 0
    if n > 0 then
      p.bild:SetVertexColor(1, 1, 1)
      p.bild:SetAlpha(1)
      p.name:SetText(p.f.name)
      p.name:SetTextColor(rgba(QUALITAET[p.f.q]))
      p.info:SetText(string.format(L.FISH_BOOK_ENTRY, math.floor(n), math.floor(m[p.f.key] or 0)))
    else
      p.bild:SetVertexColor(0, 0, 0)
      p.bild:SetAlpha(0.7)
      p.name:SetText(L.FISH_BOOK_UNKNOWN)
      p.name:SetTextColor(rgba(F.leise))
      p.info:SetText("")
    end
  end
  s.beifang:SetText(string.format(L.FISH_BOOK_JUNK, math.floor(b.stiefel or 0), math.floor(b.dose or 0)))
  self.halten = false
  self.buchOffen = ns.jetzt()
  s:Show()
end

-- Beim Schließen läuft alles weiter, wo es war (die Zeitpunkte rücken um die Lesezeit nach)
function A:BuchSchliessen()
  if not self.buchOffen then return end
  local pause = ns.jetzt() - self.buchOffen
  self.buchOffen = nil
  self.buchSeite:Hide()
  for _, feld in ipairs({ "phaseStart", "naechstes", "naechstesKnabbern", "bissEnde", "wechsel", "karteBis",
    "fernNaechster", "welleNaechste", "murkyBis", "knabberStart", "bissStart", "landStart", "fernStart",
    "sprungStart", "fluchtStart" }) do
    if self[feld] then self[feld] = self[feld] + pause end
  end
end

-- Runde ------------------------------------------------------------------------------------------

function A:Start()
  local jetzt = ns.jetzt()
  self.koeder, self.gefangen = KOEDER, 0
  self.halten, self.buchOffen = false, nil
  self.buchSeite:Hide()
  self.karte:Hide()
  self.hud:Hide()
  self.springer:Hide()
  self.fern:Hide()
  self.fernAn = false
  self.schatten:Hide()
  self.glanz:Hide()
  for _, w in ipairs(self.wellen) do w.aktiv = false w:Hide() end
  for _, s in ipairs(self.spritzer) do s.aktiv = false s:Hide() end
  self.fernNaechster = jetzt + zufall(3, 7)
  self.welleNaechste = jetzt + zufall(1, 3)
  self.haltung = nil
  self:KoederText()
  self:BuchText()
  self:MurkyStart(jetzt)
  self:Bereit()
end

function A:Stop()
  self.halten = false
  self.buchOffen = nil
  if self.buchSeite then self.buchSeite:Hide() end
  if self.karte then self.karte:Hide() end
  if self.hud then self.hud:Hide() end
  if self.murky then self.murky:Hide() end
  if self.zielText then self.zielText:Hide() end
  if self.ziel then self.ziel:Hide() end
end

function A:KoederText()
  self.koederText:SetText(string.format(L.FISH_BAIT, math.floor(self.koeder)))
end

function A:Hinweis(text, farbe)
  if self.hinweisText ~= text then
    self.hinweisText = text
    self.hinweis:SetText(text or "")
  end
  self.hinweis:SetTextColor(rgba(farbe or F.text))
end

function A:Phase(name)
  self.phase = name
  self.phaseStart = ns.jetzt()
end

function A:Spitze()
  local p = SPITZE[self.haltung or "ruhe"] or SPITZE.ruhe or { 0.24, 0.35 }
  return ROD_X + p[1] * ROD, ROD_Y + p[2] * ROD
end

function A:Rute(haltung, zittern)
  if haltung ~= self.haltung then
    self.haltung = haltung
    bild(self.rute, "rute_" .. haltung)
  end
  local dx, dy = 0, 0
  if zittern then dx, dy = math.random(-1, 1) * 0.6, math.random(-1, 1) * 0.6 end
  self.rute:ClearAllPoints()
  self.rute:SetPoint("TOPLEFT", self.r, "TOPLEFT", ROD_X + dx, -(ROD_Y + dy))
end

-- Schwimmer hängt an der Rutenspitze und pendelt
function A:AnDerSpitze(jetzt)
  local x, y = self:Spitze()
  self.sx, self.sy = x + math.sin(jetzt * 1.7) * 2, y + 13
  self.sGroesse, self.inLuft, self.sinken, self.sZeigen, self.sAlpha = 16, true, 0, true, 1
end

function A:Bereit()
  self:Phase("bereit")
  self.halten = false
  self.fisch = nil
  self.hud:Hide()
  self.ziel:Hide()
  self.zielText:Hide()
  self.schatten:Hide()
  self.glanz:Hide()
  self:Rute("ruhe")
  self:AnDerSpitze(ns.jetzt())
  self:Hinweis(L.FISH_HOLD)
end

-- Ende eines Wurfs: weiter mit dem nächsten Wurm oder Schluss
function A:Weiter()
  self.karte:Hide()
  self.springer:Hide()
  self.hud:Hide()
  if self.koeder <= 0 then
    self.phase = "ende"
    SP:Fertig(string.format(L.FISH_END, math.floor(self.gefangen)))
    return
  end
  self:Bereit()
end

-- Maus -------------------------------------------------------------------------------------------

function A:Druecken()
  if not (SP.laeuft and SP.aktiv == self) or SP.pause or self.buchOffen then return end
  local p, jetzt = self.phase, ns.jetzt()
  if p == "bereit" then
    self:Zielen(jetzt)
  elseif p == "warten" then
    self:Einholen(L.FISH_REELED_IN)
  elseif p == "naehern" or p == "knabbern" then
    self:Verscheucht(jetzt)
  elseif p == "biss" or p == "schwer" then
    self:Haken(jetzt)
  elseif p == "drill" then
    self.halten = true
  elseif p == "karte" then
    self:Weiter()
  end
end

function A:Loslassen()
  if not (SP.laeuft and SP.aktiv == self) then return end
  if self.phase == "zielen" then self:Werfen(ns.jetzt()) end
  self.halten = false
end

-- Mausposition auf der Fläche (x, y von oben links)
function A:Maus()
  if not GetCursorPosition then return nil end
  local x, y = GetCursorPosition()
  local r = self.r
  local s = (r.GetEffectiveScale and r:GetEffectiveScale()) or 1
  local links, oben = r:GetLeft(), r:GetTop()
  if not (x and links and oben and s and s > 0) then return nil end
  return x / s - links, oben - y / s
end

-- Zielen und Werfen ------------------------------------------------------------------------------

function A:Zielen(jetzt)
  self:Phase("zielen")
  self:Rute("zurueck")
  self:Hinweis(L.FISH_AIM)
  local hud = self.hud
  hud.locker:Hide()
  hud.gruen:Hide()
  hud.straff:Hide()
  hud.marke:Hide()
  hud.weg:Hide()
  hud.voll:Show()
  hud:Show()
  self.zielKlasse = nil
  self.ziel:Show()
  self.zielText:Show()
  self:ZielenTick(0, jetzt)
end

-- Wurfweite pendelt: 0 am nahen Ufer, 1 knapp über das ferne Ufer hinaus (ins Schilf)
function A:Wurfweite(jetzt)
  local t = (jetzt - self.phaseStart) / 0.85
  return 1 - math.abs((t % 2) - 1)
end

function A:ZielBerechnen(x, weite)
  x = klemmen(x, WASSER_LINKS, WASSER_RECHTS)
  local oben, unten = spalte(x)
  if not oben then oben, unten = 85, 150 end
  local y = unten - weite * (unten - oben + 16)
  return x, y, tiefe(x, y)
end

function A:ZielenTick(_, jetzt)
  local weite = self:Wurfweite(jetzt)
  local mx = self:Maus()
  if mx and mx >= 0 and mx <= B then self.zielX = mx end
  local x, y, d = self:ZielBerechnen(self.zielX or B / 2, weite)
  self.zx, self.zy, self.zd, self.weite = x, y, d, weite
  local g = 18 * nah(y)
  self.ziel:SetSize(g, g)
  self.ziel:ClearAllPoints()
  self.ziel:SetPoint("CENTER", self.r, "TOPLEFT", x, -y)
  local klasse = d == 0 and "weit" or (d >= TIEF_AB and "tief" or "flach")
  if klasse ~= self.zielKlasse then
    self.zielKlasse = klasse
    self.zielText:SetText(klasse == "weit" and L.FISH_TOO_FAR or (klasse == "tief" and L.FISH_DEEP or L.FISH_SHALLOW))
    local farbe = klasse == "weit" and F.fehler or (klasse == "tief" and { 0.55, 0.75, 1, 1 } or { 0.6, 0.92, 0.82, 1 })
    self.zielText:SetTextColor(rgba(farbe))
    self.hud.voll:SetVertexColor(farbe[1], farbe[2], farbe[3])
  end
  self.zielText:ClearAllPoints()
  self.zielText:SetPoint("BOTTOM", self.r, "TOPLEFT", x, -(y - g * 0.6))
  self.hud.voll:SetWidth(math.max(0.5, weite * (HUD_B - 2)))
  self:AnDerSpitze(jetzt)
end

function A:Werfen(jetzt)
  self.ziel:Hide()
  self.zielText:Hide()
  self.hud:Hide()
  self:Rute("ruhe")
  self:Phase("flug")
  self.vonX, self.vonY = self.sx, self.sy
  local weg = math.sqrt((self.zx - self.vonX) ^ 2 + (self.zy - self.vonY) ^ 2)
  self.flugDauer = 0.45 + weg / 420
  self.flugBogen = 22 + weg * 0.3
  self:Hinweis("")
  ns.ton("karte")
end

function A:FlugTick(_, jetzt)
  local u = klemmen((jetzt - self.phaseStart) / self.flugDauer, 0, 1)
  self.sx = self.vonX + (self.zx - self.vonX) * u
  self.sy = self.vonY + (self.zy - self.vonY) * u - self.flugBogen * 4 * u * (1 - u)
  self.sGroesse = 16 + (18 * nah(self.zy) - 16) * u
  if u >= 1 then
    if self.zd == 0 then self:Haenger(jetzt) else self:Landen(jetzt) end
  end
end

function A:Landen(jetzt)
  self:Phase("warten")
  self.inLuft, self.sinken = false, 0.5
  self.landStart = jetzt
  self.bx, self.by = self.zx, self.zy
  local n = nah(self.by)
  self:Spritzer(self.bx, self.by, 30 * n)
  self:Welle(self.bx, self.by, 54 * n, 1.4, 0.9)
  self:Welle(self.bx, self.by, 34 * n, 1.0, 0.7)
  ns.ton("plopp")
  self.fisch = ziehen(self.zd)
  self.naechstes = jetzt + zufall(1.4, 3.4) + (self.zd >= TIEF_AB and 0.6 or 0)
  self.welleBobber = jetzt + zufall(2, 3)
  self:Hinweis(L.FISH_WAIT, F.leise)
end

-- Zu weit: der Schwimmer hängt im Schilf am anderen Ufer, kostet keinen Wurm
function A:Haenger(jetzt)
  self:Phase("haenger")
  self.inLuft = true
  self.sGroesse = 14 * nah(self.zy)
  self:Hinweis(L.FISH_SNAGGED, F.hinweis)
  ns.ton("minus")
  self.haengerBis = jetzt + 1.2
end

function A:HaengerTick(_, jetzt)
  -- zappelt im Schilf
  self.sx = self.zx + math.sin(jetzt * 18) * 0.8
  if jetzt >= self.haengerBis then self:Einholen() end
end

-- Warten, Anbiss -----------------------------------------------------------------------------------

-- Schwimmer treibt und wippt, nach dem Aufprall federt er nach
function A:Treiben(jetzt)
  local u = jetzt - (self.landStart or jetzt)
  local feder = u < 0.9 and 0.5 * math.exp(-u * 5) * math.cos(u * 14) or 0
  self.sinken = klemmen(0.1 + 0.06 * math.sin(jetzt * 2.3) + feder, 0, 1)
  self.sx, self.sy = self.bx, self.by + math.sin(jetzt * 1.3) * 0.6
  self.sGroesse = 18 * nah(self.by)
end

function A:WartenTick(_, jetzt)
  self:Treiben(jetzt)
  if jetzt >= self.welleBobber then
    self.welleBobber = jetzt + zufall(2.2, 3.6)
    self:Welle(self.bx, self.by, 30 * nah(self.by), 1.6, 0.45)
  end
  if jetzt >= self.naechstes then
    -- ein Fisch kommt: der Wurm ist weg, egal wie es ausgeht
    self.koeder = self.koeder - 1
    self:KoederText()
    if self.fisch.beifang then return self:Schwer(jetzt) end
    self:Annaehern(jetzt)
  end
end

function A:Annaehern(jetzt)
  self:Phase("naehern")
  local f, n = self.fisch, nah(self.by)
  self.schattenLaenge = (16 + 30 * f.laenge) * n
  -- von der Seite, auf der Wasser ist
  local seite = math.random() < 0.5 and -1 or 1
  local abstand = (34 + 14 * math.random()) * n
  if tiefe(self.bx + seite * abstand, self.by) == 0 then seite = -seite end
  if tiefe(self.bx + seite * abstand, self.by) == 0 then abstand = abstand * 0.4 end
  self.schX0, self.schY0 = self.bx + seite * abstand, self.by + zufall(-5, 5) * n
  self.schRechts = seite < 0                  -- kommt von links, schaut nach rechts
  self.knabbernRest = math.random(f.knabbern[1], f.knabbern[2])
  self.naechstesKnabbern = jetzt + 1.1 + zufall(0.2, 0.6)
end

-- Kopf des Schattens am Schwimmer, Körper dahinter
function A:SchattenAmSchwimmer()
  local versatz = self.schattenLaenge * 0.42
  return self.bx + (self.schRechts and -versatz or versatz), self.by + 2
end

function A:NaehernTick(_, jetzt)
  self:Treiben(jetzt)
  local u = klemmen((jetzt - self.phaseStart) / 1.1, 0, 1)
  local zx, zy = self:SchattenAmSchwimmer()
  local e = weich(u)
  self:SchattenZeichnen(self.schX0 + (zx - self.schX0) * e, self.schY0 + (zy - self.schY0) * e, math.min(1, u * 2.5), jetzt)
  if u >= 1 then self:Phase("knabbern") end
end

function A:KnabbernTick(_, jetzt)
  self:Treiben(jetzt)
  local zx, zy = self:SchattenAmSchwimmer()
  local stups = 0
  if self.knabberStart then
    local k = (jetzt - self.knabberStart) / 0.24
    if k < 1 then
      local beule = math.sin(math.pi * k)
      self.sinken = klemmen(self.sinken + 0.38 * beule, 0, 1)
      stups = beule * 2.5
    end
  end
  self:SchattenZeichnen(zx + (self.schRechts and stups or -stups), zy, 1, jetzt)
  if jetzt >= self.naechstesKnabbern then
    if self.knabbernRest > 0 then
      self.knabbernRest = self.knabbernRest - 1
      self.knabberStart = jetzt
      self.naechstesKnabbern = jetzt + zufall(0.6, 1.25)
      self:Welle(self.bx, self.by, 24 * nah(self.by), 0.8, 0.6)
      self:Hinweis(L.FISH_NIBBLE, F.hinweis)
    else
      self:Biss(jetzt)
    end
  end
end

function A:Biss(jetzt)
  self:Phase("biss")
  self.bissStart = jetzt
  self.bissEnde = jetzt + self.fisch.fenster
  local n = nah(self.by)
  self:Spritzer(self.bx, self.by, 30 * n)
  self:Welle(self.bx, self.by, 50 * n, 1.1, 0.9)
  self:Hinweis(L.FISH_BITE, F.akzent)
  ns.ton("treffer")
  self:Murky("zeigen", 1.2)
end

function A:BissTick(_, jetzt)
  local u = klemmen((jetzt - self.bissStart) / 0.12, 0, 1)
  self.sx, self.sy = self.bx + math.sin(jetzt * 40) * 0.8, self.by
  self.sinken = 0.15 + 0.85 * u
  local zx, zy = self:SchattenAmSchwimmer()
  self:SchattenZeichnen(zx, zy, 1, jetzt)
  if jetzt >= self.bissEnde then self:Verloren(L.FISH_GONE, jetzt) end
end

-- Beifang knabbert nicht: der Schwimmer sinkt langsam, etwas Schweres hängt dran
function A:Schwer(jetzt)
  self:Phase("schwer")
  self.bissEnde = jetzt + 1.1 + self.fisch.fenster
  self:Hinweis(L.FISH_HEAVY, F.hinweis)
end

function A:SchwerTick(_, jetzt)
  local u = klemmen((jetzt - self.phaseStart) / 1.1, 0, 1)
  self.sx, self.sy = self.bx, self.by
  self.sinken = 0.1 + 0.9 * u
  if jetzt >= self.bissEnde then self:Verloren(L.FISH_GONE, jetzt) end
end

-- Verloren, verscheucht, eingeholt -----------------------------------------------------------------

-- Schatten flieht (falls er da ist), Schwimmer taucht wieder auf, dann einholen
function A:Verloren(text, jetzt, verscheucht)
  self:Phase("pause")
  self.pauseArt = "einholen"
  self.pauseBis = jetzt + 1.1
  self.fluchtStart = jetzt
  self.hud:Hide()
  self:Rute("ruhe")
  self:Hinweis(text, F.fehler)
  ns.ton("minus")
  self:Murky(verscheucht and "lachen" or "weinen", 2)
end

function A:Verscheucht(jetzt)
  self:Verloren(L.FISH_TOO_EARLY, jetzt, true)
end

function A:PauseTick(_, jetzt)
  if self.pauseArt == "riss" then
    -- Schnur gerissen: der Schwimmer treibt allein und verblasst
    self.sAlpha = klemmen(1 - (jetzt - self.phaseStart) / 0.9, 0, 1)
    self.sinken = 0.12 + 0.05 * math.sin(jetzt * 2.3)
  else
    self.sinken = klemmen((self.sinken or 0) - 0.08, 0.1, 1)
    self.sx, self.sy = self.bx, self.by
  end
  -- Schatten schießt davon und verblasst
  if self.fisch and not self.fisch.beifang and self.schattenLaenge then
    local u = (jetzt - self.fluchtStart) / 0.6
    if u < 1 then
      local zx, zy
      if self.fx then zx, zy = self.fx, self.fy else zx, zy = self:SchattenAmSchwimmer() end
      local weg = (self.schRechts and -1 or 1) * 60 * weich(u) * nah(zy)
      self:SchattenZeichnen(zx + weg, zy, 1 - u, jetzt)
    else
      self.schatten:Hide()
      self.glanz:Hide()
    end
  end
  if jetzt >= self.pauseBis then
    self.fx = nil
    self.schatten:Hide()
    self.glanz:Hide()
    if self.pauseArt == "riss" then self:Weiter() else self:Einholen() end
  end
end

-- Schwimmer fliegt zurück an die Rutenspitze
function A:Einholen(text)
  self:Phase("einholen")
  self.vonX, self.vonY = self.sx, self.sy
  self.inLuft = true
  self.hud:Hide()
  self:Rute("ruhe")
  if text then self:Hinweis(text, F.leise) end
end

function A:EinholenTick(_, jetzt)
  local u = klemmen((jetzt - self.phaseStart) / 0.4, 0, 1)
  local zx, zy = self:Spitze()
  zy = zy + 13
  self.sx = self.vonX + (zx - self.vonX) * u
  self.sy = self.vonY + (zy - self.vonY) * u - 18 * 4 * u * (1 - u)
  self.sGroesse = 16
  if u >= 1 then self:Weiter() end
end

-- Drill ----------------------------------------------------------------------------------------------

function A:Haken(jetzt)
  local f = self.fisch
  self:Phase("drill")
  self.halten = true              -- die Maus ist gerade gedrückt: wer hält, holt gleich ein
  self.spannung, self.tempo, self.fortschritt = 0.45, 0, 0
  self.zieht, self.wechsel, self.locker = false, jetzt + 0.8, 0
  self.g0, self.g1 = 0.3 + 0.06 * f.kraft, 0.74 - 0.06 * f.kraft
  self.fx, self.fy = self.bx, self.by
  self.seit, self.ziehRichtung = 0, 1
  self.hakenX, self.hakenY = self.bx, self.by
  local sx = self:Spitze() - 10
  local _, unten = spalte(sx)
  self.landX, self.landY = sx, (unten or 150) - 4
  self.welleDrill, self.spritzerDrill = jetzt + 0.3, jetzt + 0.4
  self.schattenLaenge = self.schattenLaenge or (16 + 30 * f.laenge) * nah(self.by)
  local hud = self.hud
  hud.voll:Hide()
  hud.locker:Show()
  hud.gruen:Show()
  hud.straff:Show()
  hud.marke:Show()
  hud.weg:Show()
  feldSetzen(hud.locker, hud.kasten, 0, self.g0)
  feldSetzen(hud.gruen, hud.kasten, self.g0, self.g1)
  feldSetzen(hud.straff, hud.kasten, self.g1, 1)
  hud:Show()
  self:Rute("biegen1")
  self:Hinweis(L.FISH_REEL)
  SP:Ruf(L.FISH_HOOKED, self.bx, -(self.by - 16), F.akzent)
  ns.ton("plopp")
end

function A:DrillTick(dt, jetzt)
  local f = self.fisch
  local k = f.kraft
  -- Der Fisch wechselt zwischen Ruhe und Ziehen, Beifang zieht nie
  if jetzt >= self.wechsel then
    if self.zieht or f.beifang then
      self.zieht = false
      self.wechsel = jetzt + zufall(1.3, 2.6) * (1.3 - 0.5 * k)
    else
      self.zieht = true
      self.wechsel = jetzt + zufall(0.45, 0.9) * (0.7 + 0.6 * k)
      self.ziehRichtung = math.random() < 0.5 and -1 or 1
      self:Spritzer(self.fx, self.fy, 26 * nah(self.fy))
    end
  end
  local ziel = (self.halten and 0.42 or -0.7) + (self.zieht and (0.3 + 0.6 * k) or (f.beifang and -0.05 or -0.12))
  self.tempo = self.tempo + (ziel - self.tempo) * math.min(1, dt * 7)
  self.spannung = self.spannung + self.tempo * dt
  local s = self.spannung
  if self.halten then
    local rate = 1 / (1.6 + 4.6 * k)
    if s > self.g1 then rate = rate * 0.4 elseif s < self.g0 then rate = rate * 0.6 end
    self.fortschritt = self.fortschritt + rate * dt
  elseif self.zieht then
    self.fortschritt = math.max(0, self.fortschritt - 0.06 * dt)
  end
  if s >= 1 then return self:Gerissen(jetzt) end
  if s <= 0.02 then
    self.spannung = math.max(0, s)
    self.locker = self.locker + dt
    if self.locker > 1.2 then return self:Abgeschuettelt(jetzt) end
  else
    self.locker = 0
  end
  if self.fortschritt >= 1 then return self:Gelandet(jetzt) end
  s = self.spannung

  -- Lage des Fischs: vom Haken zum Ufer unter der Rute, beim Ziehen zur Seite
  local e = weich(self.fortschritt)
  local bx = self.hakenX + (self.landX - self.hakenX) * e
  local by = self.hakenY + (self.landY - self.hakenY) * e
  local seitZiel = self.zieht and self.ziehRichtung * 22 * nah(by) or 0
  self.seit = self.seit + (seitZiel - self.seit) * math.min(1, dt * 2)
  local x = bx + self.seit + math.sin(jetzt * 3.1) * 3
  local y = by + math.sin(jetzt * 2.3) * 1.5
  if tiefe(x, y) > 0 then
    self.fx, self.fy = x, y
  else
    self.seit = self.seit * 0.9
  end
  local n = nah(self.fy)
  if jetzt >= self.welleDrill then
    self.welleDrill = jetzt + (self.zieht and 0.3 or 0.8)
    self:Welle(self.fx, self.fy, (self.zieht and 40 or 28) * n, 1.0, self.zieht and 0.8 or 0.5)
  end
  if self.zieht and jetzt >= self.spritzerDrill then
    self.spritzerDrill = jetzt + 0.35
    self:Spritzer(self.fx + zufall(-3, 3), self.fy, 22 * n)
  end
  -- Schatten schaut weg vom Ufer (der Fisch zieht), Schwimmer halb unter Wasser
  if not f.beifang then
    local weg = self.zieht and self.ziehRichtung or (self.fx >= self.landX and 1 or -1)
    self.schRechts = weg > 0
    local versatz = self.schattenLaenge * 0.35
    self:SchattenZeichnen(self.fx + (self.schRechts and versatz or -versatz), self.fy + 3, 0.85, jetzt)
  end
  self.sx, self.sy = self.fx, self.fy
  self.sGroesse = 18 * n
  self.sinken = 0.3 + 0.55 * s
  self:Rute(s < 0.38 and "ruhe" or (s < 0.72 and "biegen1" or "biegen2"), s > 0.82)
  -- Anzeige
  local hud = self.hud
  hud.marke:ClearAllPoints()
  hud.marke:SetPoint("CENTER", hud.kasten, "LEFT", 1 + klemmen(s, 0, 1) * (HUD_B - 2), 0)
  hud.wegVoll:SetWidth(math.max(0.5, klemmen(self.fortschritt, 0, 1) * (HUD_B - 2)))
  if s > self.g1 then
    self:Hinweis(L.FISH_PULLS, F.fehler)
  elseif s < 0.12 then
    self:Hinweis(L.FISH_SLACK, F.hinweis)
  else
    self:Hinweis(L.FISH_REEL)
  end
end

function A:Gerissen(jetzt)
  self:Verloren(L.FISH_SNAP, jetzt)
  self.pauseArt = "riss"
  self.pauseBis = jetzt + 1.2
  self.bx, self.by = self.fx, self.fy
  SP:Ruf(L.FISH_SNAP_SHOUT, self.fx, -(self.fy - 14), F.fehler)
end

function A:Abgeschuettelt(jetzt)
  self.bx, self.by = self.fx, self.fy
  self:Verloren(L.FISH_ESCAPED, jetzt)
end

-- Fang -----------------------------------------------------------------------------------------------

function A:Gelandet(jetzt)
  local f = self.fisch
  local cm, gross = 0, false
  if f.cm then
    local r = math.random() ^ 1.6
    cm = math.floor(f.cm[1] + (f.cm[2] - f.cm[1]) * r + 0.5)
    gross = cm >= f.cm[1] + (f.cm[2] - f.cm[1]) * 0.85
  end
  local b, m = buch(), masse()
  local neu = not f.beifang and (b[f.key] or 0) == 0
  b[f.key] = (b[f.key] or 0) + 1
  local rekord = not f.beifang and not neu and cm > (m[f.key] or 0)
  if not f.beifang then
    if cm > (m[f.key] or 0) then m[f.key] = cm end
    self.gefangen = self.gefangen + 1
  end
  self.beute = { f = f, cm = cm, punkte = f.punkte + (gross and math.ceil(f.punkte / 2) or 0), neu = neu,
    rekord = rekord, gross = gross }
  self:Phase("sprung")
  self.sprungStart = jetzt
  self.sZeigen = false
  self.schatten:Hide()
  self.glanz:Hide()
  self.hud:Hide()
  self:Rute("biegen1")
  self:Hinweis("")
  local n = nah(self.fy)
  self:Spritzer(self.fx, self.fy, 40 * n)
  self:Welle(self.fx, self.fy, 60 * n, 1.4, 0.9)
  self:Welle(self.fx, self.fy, 36 * n, 1.0, 0.7)
  self.springRichtung = self.fx > B / 2 and -1 or 1
  self.springGroesse = (24 + 34 * f.laenge) / 0.92
  if f.beifang then
    self:Murky("lachen", 2.2)
    ns.ton("umfallen")
  elseif f.q >= 5 then
    self:Murky("bruellen", 2.6)
    ns.ton("muenze")
  else
    self:Murky("jubeln", 2.2)
    ns.ton(neu and "paar" or (f.q >= 3 and "muenze" or "treffer"))
  end
  ns.mrgl(0.5)
  self:BuchText()
end

-- Der Fang springt aus dem Wasser bis über die Wasserfläche, dann erscheint die Karte
function A:SprungTick(_, jetzt)
  local t = jetzt - self.sprungStart
  local f = self.fisch
  local u = klemmen(t / 0.45, 0, 1)
  local hoch = 46 * (1 - (1 - u) ^ 2)
  local name = u < 0.8 and f.bildAuf or f.bild
  local sp = self.springer
  bild(sp, name, self.springRichtung < 0)
  local g = self.springGroesse
  sp:SetSize(g, g)
  sp:ClearAllPoints()
  sp:SetPoint("CENTER", self.r, "TOPLEFT", self.fx + self.springRichtung * 14 * u, -(self.fy - hoch))
  sp:SetAlpha(t < 0.6 and 1 or klemmen(1 - (t - 0.6) / 0.25, 0, 1))
  sp:Show()
  if t >= 0.5 and not self.karte:IsShown() then
    self:Rute("ruhe")
    self:KarteZeigen(jetzt)
  end
  self:AnDerSpitze(jetzt)
  self.sZeigen = t >= 0.5
  if t >= 0.85 then
    sp:Hide()
    self:Phase("karte")
  end
end

function A:KarteZeigen(jetzt)
  local fa = self.beute
  local f = fa.f
  local k = self.karte
  bild(k.bild, f.bild)
  k.name:SetText(f.name)
  k.name:SetTextColor(rgba(QUALITAET[f.q]))
  k.groesse:SetText(f.beifang and L.FISH_NOT_A_FISH or string.format(L.FISH_SIZE, math.floor(fa.cm)))
  k.punkte:SetText(string.format(L.LEGEND_POINTS, math.floor(fa.punkte)))
  local marke = (L.FISH_QUIPS or {})[f.key] or ""
  if fa.neu then marke = L.FISH_NEW elseif fa.rekord then marke = L.FISH_RECORD elseif fa.gross then marke = L.FISH_BIG end
  k.marke:SetText(marke)
  S.randFarbe(k, QUALITAET[f.q])
  k.zeigenStart = jetzt
  k:SetAlpha(0)
  k:Show()
  self.karteBis = jetzt + 2.8
  SP:Plus(fa.punkte)
  if fa.punkte > 0 then SP:Ruf(string.format(L.LEGEND_POINTS, math.floor(fa.punkte)), B / 2 + 70, -78, QUALITAET[f.q]) end
  if self.murkyDa then
    local rufe = f.beifang and L.FISH_MURKY_JUNK or L.FISH_MURKY_CHEER
    SP:Ruf(SP.spruch(rufe), MURKY_X, -(MURKY_KOPF - 6), F.text)
  end
end

function A:KarteTick(_, jetzt)
  local k = self.karte
  local u = klemmen((jetzt - (k.zeigenStart or jetzt)) / 0.18, 0, 1)
  k:SetAlpha(u)
  k:ClearAllPoints()
  k:SetPoint("TOP", self.r, "TOP", 0, -(44 - 8 * u))
  self:AnDerSpitze(jetzt)
  if self.phase == "karte" and jetzt >= self.karteBis then self:Weiter() end
end

-- Zeichnen ----------------------------------------------------------------------------------------

-- Schatten des Fischs unter Wasser (Kopf zeigt im Bild nach rechts). Seltene schimmern farbig.
function A:SchattenZeichnen(x, y, alpha, jetzt)
  local f = self.fisch
  if not f or f.beifang then return end
  local w = self.schattenLaenge / 0.82
  local t = f.glanz and self.glanz or self.schatten
  local bildNr = (math.floor(jetzt * 5) % 2) + 1
  bild(t, (f.glanz and GLANZ_BILD or SCHATTEN_BILD)[bildNr], not self.schRechts)
  t:SetSize(w, w * 0.38)   -- schräg von oben: etwas flacher als von senkrecht oben
  t:ClearAllPoints()
  t:SetPoint("CENTER", self.r, "TOPLEFT", x, -y)
  local d = tiefe(x, y)
  if f.glanz then
    t:SetVertexColor(f.glanz[1], f.glanz[2], f.glanz[3])
    t:SetAlpha(alpha * (0.55 + 0.15 * math.sin(jetzt * 5)))
  else
    t:SetAlpha(alpha * (0.75 - 0.04 * d))
  end
  t:Show()
end

function A:SchwimmerZeichnen()
  local t = self.schwimmer
  local k = ATLAS.schwimmer
  if not (self.sZeigen and k and self.sx) then t:Hide() return end
  local g = self.sGroesse or 16
  t:SetAlpha(self.sAlpha or 1)
  t:ClearAllPoints()
  if self.inLuft then
    t:SetTexCoord(k[1], k[2], k[3], k[4])
    t:SetSize(g, g)
    t:SetPoint("CENTER", self.r, "TOPLEFT", self.sx, -self.sy)
    self.leineX, self.leineY = self.sx, self.sy - g * 0.45
  else
    -- nur der Teil über der Wasserlinie, beim Abtauchen immer weniger
    local sicht = WASSERLINIE * (1 - klemmen(self.sinken or 0, 0, 1))
    self.leineX, self.leineY = self.sx, self.sy - g * sicht
    if sicht <= 0.03 then t:Hide() return end
    t:SetTexCoord(k[1], k[2], k[3], k[3] + (k[4] - k[3]) * sicht)
    t:SetSize(g, g * sicht)
    t:SetPoint("BOTTOM", self.r, "TOPLEFT", self.sx, -self.sy)
  end
  t:Show()
end

-- Schnur von der Rutenspitze zum Schwimmer, hängt durch, wenn sie locker ist
function A:LeineZeichnen()
  local an = self.sZeigen and self.leineX and not (self.phase == "pause" and self.pauseArt == "riss")
  if not an then
    for _, l in ipairs(self.leine) do l:Hide() end
    return
  end
  local x0, y0 = self:Spitze()
  local x1, y1 = self.leineX, self.leineY
  local durchhang
  if self.phase == "drill" then
    durchhang = (1 - klemmen(self.spannung, 0, 1)) ^ 2 * 18 * nah(y1)
  elseif self.inLuft then
    durchhang = 2
  else
    durchhang = 10 * nah(y1)
  end
  local n = #self.leine
  for i, l in ipairs(self.leine) do
    local t0, t1 = (i - 1) / n, i / n
    l:SetStartPoint("TOPLEFT", self.r, x0 + (x1 - x0) * t0, -(y0 + (y1 - y0) * t0 + durchhang * 4 * t0 * (1 - t0)))
    l:SetEndPoint("TOPLEFT", self.r, x0 + (x1 - x0) * t1, -(y0 + (y1 - y0) * t1 + durchhang * 4 * t1 * (1 - t1)))
    l:Show()
  end
end

-- Wellenringe: wachsen und verblassen
function A:Welle(x, y, groesse, dauer, staerke)
  local frei = self.wellen[1]
  for _, w in ipairs(self.wellen) do
    if not w.aktiv then frei = w break end
    if w.start < frei.start then frei = w end
  end
  frei.aktiv, frei.x, frei.y, frei.g, frei.start, frei.dauer, frei.staerke = true, x, y, groesse, ns.jetzt(), dauer, staerke
  frei:Show()
end

function A:WellenTick(jetzt)
  for _, w in ipairs(self.wellen) do
    if w.aktiv then
      local u = (jetzt - w.start) / w.dauer
      if u >= 1 then
        w.aktiv = false
        w:Hide()
      else
        local g = w.g * (0.3 + 0.9 * u)
        w:SetSize(g, g * 0.5)
        w:ClearAllPoints()
        w:SetPoint("CENTER", self.r, "TOPLEFT", w.x, -w.y)
        w:SetAlpha(w.staerke * (1 - u) * math.min(1, u * 8))
      end
    end
  end
end

-- Wasserspritzer: vier Bilder in 0,44 Sekunden, Fuß auf der Wasserfläche
function A:Spritzer(x, y, groesse)
  local frei = self.spritzer[1]
  for _, s in ipairs(self.spritzer) do
    if not s.aktiv then frei = s break end
    if s.start < frei.start then frei = s end
  end
  frei.aktiv, frei.x, frei.y, frei.g, frei.start = true, x, y, groesse, ns.jetzt()
  frei:SetSize(groesse, groesse)
  frei:ClearAllPoints()
  frei:SetPoint("TOPLEFT", self.r, "TOPLEFT", x - groesse / 2, -(y - groesse * FUSS))
end

function A:SpritzerTick(jetzt)
  for _, s in ipairs(self.spritzer) do
    if s.aktiv then
      local u = (jetzt - s.start) / 0.44
      if u >= 1 then
        s.aktiv = false
        s:Hide()
      else
        bild(s, SPRITZER_BILD[math.floor(u * 4) + 1])
        s:SetAlpha(u > 0.75 and (1 - u) * 4 * 0.9 or 0.9)
        s:Show()
      end
    end
  end
end

-- Umgebung: weit draußen springt ab und zu ein Fisch, hier und da steigt ein Ring auf
function A:UmgebungTick(jetzt)
  local ruhig = self.phase ~= "drill" and self.phase ~= "sprung"
  if ruhig and not self.fernAn and jetzt >= self.fernNaechster then
    for _ = 1, 12 do
      local x, y = zufall(40, 260), zufall(84, 118)
      if tiefe(x, y) >= 2 and math.abs(x - (self.bx or -100)) > 40 then
        self.fernAn, self.fernStart, self.fernX, self.fernY = true, jetzt, x, y
        self.fernRichtung = math.random() < 0.5 and -1 or 1
        self.fernArt = FERN[math.random(1, #FERN)]
        self.fernGroesse = zufall(15, 20) * nah(y)
        self:Spritzer(x, y, 16 * nah(y))
        self:Welle(x, y, 26 * nah(y), 1.3, 0.6)
        break
      end
    end
    self.fernNaechster = jetzt + zufall(6, 13)
  end
  if self.fernAn then
    local u = (jetzt - self.fernStart) / 0.6
    local t = self.fern
    if u >= 1 then
      self.fernAn = false
      t:Hide()
      local x = self.fernX + self.fernRichtung * 16 * nah(self.fernY)
      self:Spritzer(x, self.fernY, 14 * nah(self.fernY))
      self:Welle(x, self.fernY, 24 * nah(self.fernY), 1.3, 0.55)
    else
      local n = nah(self.fernY)
      local art = self.fernArt
      local name = u < 0.38 and art.bildAuf or (u < 0.62 and art.bild or art.bildAb)
      bild(t, name, self.fernRichtung < 0)
      t:SetSize(self.fernGroesse, self.fernGroesse)
      t:ClearAllPoints()
      t:SetPoint("CENTER", self.r, "TOPLEFT", self.fernX + self.fernRichtung * 16 * n * u, -(self.fernY - 16 * n * 4 * u * (1 - u)))
      t:SetAlpha(0.9)
      t:Show()
    end
  end
  if jetzt >= self.welleNaechste then
    self.welleNaechste = jetzt + zufall(2, 4.5)
    for _ = 1, 8 do
      local x, y = zufall(30, 270), zufall(82, 150)
      if tiefe(x, y) >= 1 then
        self:Welle(x, y, zufall(18, 28) * nah(y), 1.6, 0.4)
        break
      end
    end
  end
end

-- Murky -----------------------------------------------------------------------------------------------

function A:MurkyStart(jetzt)
  local m = self.murky
  self.murkyDa, self.murkyErsatz, self.murkyAus, self.murkyBis = false, false, false, nil
  if not m then return end
  -- erst zeigen, dann laden: versteckte Modelle laden nicht zuverlässig
  m:Show()
  pcall(m.SetDisplayInfo, m, MURKY)
  self:MurkyKamera()
  licht(m)
  self.murkyLaden = jetzt
end

-- Kamera um RAND herauszoomen: sichtbar so groß wie MURKY_GROESSE, Platz für breite Posen
function A:MurkyKamera()
  local m = self.murky
  if m and m.SetCamDistanceScale then pcall(m.SetCamDistanceScale, m, RAND) end
end

function A:Murky(art, dauer)
  local m = self.murky
  if not (m and self.murkyDa) then return end
  anim(m, MURKY_ANIM[art])
  pcall(m.SetFacing, m, (art == "jubeln" or art == "bruellen" or art == "lachen") and 0.35 or MURKY_BLICK)
  self.murkyBis = dauer and (ns.jetzt() + dauer) or nil
end

function A:MurkyTick(jetzt)
  local m = self.murky
  if not m or self.murkyAus then return end
  if not self.murkyDa then
    if geladen(m) then
      self.murkyDa = true
      self:MurkyKamera()
      licht(m)
      pcall(m.SetFacing, m, MURKY_BLICK)
      anim(m, MURKY_ANIM.stehen)
    elseif jetzt - (self.murkyLaden or jetzt) > 0.8 then
      if not self.murkyErsatz then
        -- Murky fehlt: der große Murloc
        self.murkyErsatz, self.murkyLaden = true, jetzt
        pcall(m.SetDisplayInfo, m, MURLOC_ERSATZ)
        self:MurkyKamera()
      else
        self.murkyAus = true
        m:Hide()
      end
    end
    return
  end
  if self.murkyBis and jetzt >= self.murkyBis then
    self.murkyBis = nil
    anim(m, self.fisch and self.fisch.q == 5 and self.phase == "karte" and MURKY_ANIM.tanzen or MURKY_ANIM.stehen)
    pcall(m.SetFacing, m, MURKY_BLICK)
  end
end

-- Takt -----------------------------------------------------------------------------------------------

local PHASEN = {
  zielen = A.ZielenTick, flug = A.FlugTick, haenger = A.HaengerTick, warten = A.WartenTick,
  naehern = A.NaehernTick, knabbern = A.KnabbernTick, biss = A.BissTick, schwer = A.SchwerTick,
  pause = A.PauseTick, einholen = A.EinholenTick, drill = A.DrillTick, sprung = A.SprungTick,
}

function A:Tick(dt, jetzt)
  if self.buchOffen then return end
  -- Maustaste außerhalb losgelassen: wie loslassen
  if (self.halten or self.phase == "zielen") and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
    self:Loslassen()
  end
  self:MurkyTick(jetzt)
  local p = self.phase
  if p == "bereit" then
    self:AnDerSpitze(jetzt)
  elseif p == "karte" then
    self:KarteTick(dt, jetzt)
  elseif PHASEN[p] then
    PHASEN[p](self, dt, jetzt)
  end
  if self.karte:IsShown() and p == "sprung" then self:KarteTick(dt, jetzt) end
  if not SP.laeuft then return end
  self:WellenTick(jetzt)
  self:SpritzerTick(jetzt)
  self:UmgebungTick(jetzt)
  self:SchwimmerZeichnen()
  self:LeineZeichnen()
end

A.FISCHE, A.BEIFANG = FISCHE, BEIFANG
SP.Registrieren(A)
