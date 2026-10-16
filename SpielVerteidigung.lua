-- Camp Defense (Lagerverteidigung): Turmverteidigung auf einer echten Karte. Murlocs steigen oben
-- rechts aus dem See und laufen den gewundenen Erdweg entlang bis zum Lager links. Neben dem Weg
-- liegen neun runde Bauplätze aus Stein. Klick auf einen freien Platz: Wahl aus fünf Türmen (was man
-- sich nicht leisten kann, ist gesperrt), Klick auf einen Turm: aufwerten oder verkaufen. Beim Zeigen
-- erscheint die Reichweite als Fläche auf dem Boden.
--
-- Türme mit klaren Rollen, keiner schafft alles allein:
--   Feuertotem   schnelle Feuerbälle auf ein Ziel. Gut gegen Murlocs und Flitzer, Gepanzerte spüren
--                kaum etwas.
--   Frosttotem   kühlt alle in seiner Nähe und bremst sie, sehr wenig Schaden.
--   Bombenmörser langsam, Bomben fliegen im Bogen und treffen eine ganze Gruppe, Panzer hilft nicht.
--                Die Bombe zielt dorthin, wo ein Murloc im normalen Schritt beim Aufschlag wäre:
--                schnelle Flitzer sind dann schon vorbei, gebremste treffen sie.
--   Speerturm    große Reichweite, schwere Speere durchschlagen Panzer, zielt auf den Stärksten, wirft
--                aber langsam.
--   Sturmtotem   Kettenblitz: trifft den vordersten und springt auf zwei bis vier Murlocs in der Nähe,
--                mit jedem Sprung schwächer. Gut gegen Gruppen, schwach gegen einen einzelnen Zähen.
-- Schüsse: Feuerbälle ziehen eine glühende Spur und zerplatzen in Funken, Frostsplitter glitzern und
-- färben den Getroffenen blau, Bomben fliegen im Bogen mit Schatten am Boden und explodieren als
-- gerenderte Explosion in vier Bildern, dabei wackelt, wer getroffen ist. Blitze sind gezackte Linien
-- zwischen den Zielen, in jedem Bild neu verwackelt (Line-Objekte, ohne sie gedrehte Striche).
-- Gegner: Murloc, Flitzer (schnell, wenig Leben), Orakel (heilt die anderen in seiner Nähe), Brocken
-- (gepanzert, langsam, viel Leben) und King Mrgl (Boss der letzten Welle, gepanzert, ruft bei halbem
-- Leben Flitzer zu Hilfe).
-- Glut: Startgeld, Beute je Murloc, Bonus je geschaffter Welle, wer die nächste Welle früher ruft,
-- bekommt Extra-Glut. Verkaufen bringt 70 Prozent zurück. Das Lager hat 20 Herzen. Zehn Wellen,
-- dazwischen eine kurze Bauzeit mit dem Knopf Next wave. Die Legende unter der Spielfläche zeigt
-- Glut, Herzen und Welle.
--
-- Karte, Weg und Bauplätze kommen aus Blender (grafik/blender/verteidigung.py, erzeugt Lagerkarte.lua),
-- die Türme auch (Media/Verteidigung.tga, je drei Stufen). Die Murlocs sind echte Modelle wie in
-- Whack: Murky (15369) als Flitzer, Gurky (15984) als Orakel, der große Murloc (31) als Murloc,
-- Brocken und King Mrgl, unterschieden durch Größe und Licht. Lädt ein Modell nicht, läuft ein
-- Murloc-Kopf als Symbol. Modelle schneidet die Spielfläche nicht sicher ab: Der Weg bleibt so weit
-- vom Rand weg, dass jedes Modell ganz in der Spielfläche steht.
-- Tiefe: Türme und Murlocs liegen auf Ebenen nach ihrer Höhe im Bild, was weiter vorn steht,
-- verdeckt, was dahinter ist. Alles bleibt unter der Tafel des Rahmens (Ebene + 30).
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba
local SP = ns.Spiel
local KARTE = ns.Lagerkarte

local B, H = SP.BREITE, SP.HOEHE
local K = KARTE.k                                   -- Verkürzung der Tiefe (Blick von schräg oben)
local floor, min, max, sqrt, sin, cos, abs, pi = math.floor, math.min, math.max, math.sqrt, math.sin, math.cos, math.abs, math.pi
local atan2 = math.atan2 or math.atan

local KOPF = "Interface\\Icons\\INV_Misc_Head_Murloc_01"
local ROT, GRUEN, GOLD, BLAU = { 0.94, 0.38, 0.35, 1 }, { 0.4, 0.84, 0.56, 1 }, { 1, 0.84, 0.25, 1 }, { 0.55, 0.8, 1, 1 }
local WEISS, WEISS_GELB, ORANGE = { 1, 1, 1 }, { 1, 0.9, 0.6 }, { 1, 0.55, 0.15 }
local EIS, EIS_HELL, BLITZ_FARBE = { 0.45, 0.72, 1 }, { 0.7, 0.9, 1 }, { 0.55, 0.65, 1 }

local START_GLUT, HERZEN = 24, 20
local BAU_ZEIT_START, BAU_ZEIT = 30, 12              -- Sekunden bis zur ersten und jeder weiteren Welle
local FRUEH_TEILER, FRUEH_MAX = 3, 4                 -- früher Ruf: je 3 Sekunden Rest eine Glut, höchstens 4
local VERKAUF = 0.7
local MAX_FEINDE, MAX_GESCHOSSE, MAX_EFFEKTE, MAX_STRICHE, MAX_KETTEN = 26, 40, 110, 64, 10
local SCHRITT = 0.05                                 -- Teilschritt der Spiellogik
local TIEFE0, TIEFEN = 3, 20                         -- Ebenen für die Tiefe über dem Spielrahmen
local FUSS = 0.12                                    -- Anteil der Murloc-Größe unter den Füßen
-- Modellrahmen: deutlich größer als der Murloc (RAND = 1,6 in Breite und Höhe), die Kamera zoomt um
-- denselben Faktor heraus (SetCamDistanceScale), so bleibt der Murloc gleich groß. Ein PlayerModel
-- zeichnet nur in seinem Rahmen: Im knappen Rahmen wurden Arme und Beine beim Laufen gerade
-- abgeschnitten (Patricks Test in der Beta). Die Kamera zentriert das Modell, die Füße sitzen deshalb
-- um groesse * (RAND - 1) / 2 höher im Rahmen, der Rahmen rutscht um so viel nach unten. Der Rahmen
-- bleibt mit seinem leeren Rand ganz in der Spielfläche (der Weg hat genug Abstand, sonst begrenzt).
local RAND = 1.6
local TURM_B, TURM_H, TURM_FUSS = 32, 48, 16         -- Turmbild und Lage des Bauplatzes darin
local LEVEL = { "I", "II", "III" }

-- Türme. reichweite in Punkten am Boden, takt in Sekunden, hoehe: Abschusspunkt über dem Bauplatz.
-- Aufwerten kostet das 0,9- und 1,5-fache des Grundpreises.
local TURM = {
  feuer = { kosten = 10, name = L.DEFENSE_FIRE, info = L.DEFENSE_FIRE_INFO, hoehe = 36,
    reichweite = { 46, 50, 55 }, takt = { 0.85, 0.75, 0.65 }, schaden = { 4, 7, 11 }, ziel = "erster" },
  frost = { kosten = 10, name = L.DEFENSE_FROST, info = L.DEFENSE_FROST_INFO, hoehe = 38,
    reichweite = { 40, 44, 48 }, takt = { 1.2, 1.1, 1.0 }, schaden = { 1, 2, 3 }, bremse = { 0.55, 0.45, 0.35 }, dauer = 1.6 },
  bombe = { kosten = 14, name = L.DEFENSE_BOMB, info = L.DEFENSE_BOMB_INFO, hoehe = 22,
    reichweite = { 60, 64, 70 }, takt = { 2.7, 2.5, 2.3 }, schaden = { 10, 17, 26 }, radius = { 20, 22, 24 }, ziel = "erster" },
  speer = { kosten = 16, name = L.DEFENSE_SPEAR, info = L.DEFENSE_SPEAR_INFO, hoehe = 34,
    reichweite = { 66, 72, 78 }, takt = { 3.0, 2.7, 2.4 }, schaden = { 14, 24, 38 }, ziel = "staerkster" },
  sturm = { kosten = 12, name = L.DEFENSE_STORM, info = L.DEFENSE_STORM_INFO, hoehe = 42,
    reichweite = { 50, 54, 58 }, takt = { 1.7, 1.6, 1.5 }, schaden = { 7, 10, 14 }, spruenge = { 2, 3, 4 }, ziel = "erster" },
}
local TURM_REIHE = { "feuer", "frost", "sturm", "bombe", "speer" }
-- Schaden gegen Panzer (Brocken und King Mrgl)
local PANZER = { feuer = 0.25, frost = 0.5, bombe = 1, speer = 1.5, sturm = 0.35 }
-- Kettenblitz: so weit springt er am Boden, jeder Sprung macht 70 Prozent des letzten Schadens
local SPRUNG_WEITE, SPRUNG_ABNAHME, BLITZ_DAUER = 40, 0.7, 0.2

-- Gegner: Leben, Tempo (Punkte je Sekunde am Boden), Größe des Modells, Beute (Glut), Punkte,
-- Herzen, die er dem Lager nimmt, Modell, Farbe des Ersatzsymbols, Licht des Modells, Laufanimation
local FEINDE = {
  murloc = { hp = 14, tempo = 24, groesse = 30, beute = 1, punkte = 2, schaden = 1, modell = "gross",
    farbe = { 1, 1, 1 }, licht = "normal", anim = { 4, 0 } },
  flitzer = { hp = 8, tempo = 46, groesse = 25, beute = 1, punkte = 1, schaden = 1, modell = "murky",
    farbe = { 1, 0.9, 0.45 }, licht = "normal", anim = { 5, 4, 0 } },
  orakel = { hp = 18, tempo = 22, groesse = 27, beute = 2, punkte = 4, schaden = 1, modell = "gurky",
    farbe = { 0.7, 1, 0.75 }, licht = "orakel", anim = { 4, 0 }, heilt = true },
  brocken = { hp = 55, tempo = 15, groesse = 36, beute = 3, punkte = 5, schaden = 2, modell = "gross",
    farbe = { 0.6, 0.75, 1 }, licht = "panzer", anim = { 4, 0 }, panzer = true },
  koenig = { hp = 800, tempo = 10, groesse = 42, beute = 15, punkte = 50, schaden = 10, modell = "gross",
    farbe = { 1, 0.84, 0.3 }, licht = "gold", anim = { 4, 0 }, panzer = true, boss = true },
}
local FEIND_REIHE = { "murloc", "flitzer", "orakel", "brocken", "koenig" }
local HEIL_TAKT, HEIL_ANTEIL, HEIL_WEITE = 3, 0.12, 42

-- Wellen: Gruppen nacheinander { Art, Anzahl, Abstand in Sekunden }. Leben wachsen je Welle um 26 Prozent.
local WELLEN = {
  { { "murloc", 6, 1.5 } },
  { { "murloc", 8, 1.2 }, { "flitzer", 4, 0.8 } },
  { { "flitzer", 12, 0.6 }, { "murloc", 4, 1.0 } },
  { { "murloc", 6, 1.0 }, { "brocken", 2, 2.5 }, { "murloc", 4, 1.0 } },
  { { "murloc", 4, 0.9 }, { "orakel", 2, 1.2 }, { "murloc", 4, 0.9 }, { "flitzer", 6, 0.6 } },
  { { "brocken", 2, 2.0 }, { "orakel", 2, 1.2 }, { "brocken", 2, 2.0 }, { "murloc", 10, 0.8 } },
  { { "flitzer", 10, 0.4 }, { "murloc", 6, 0.5 }, { "flitzer", 10, 0.4 } },
  { { "brocken", 3, 1.8 }, { "orakel", 3, 1.2 }, { "brocken", 3, 1.8 }, { "murloc", 8, 0.8 } },
  { { "murloc", 12, 0.6 }, { "flitzer", 14, 0.4 }, { "orakel", 2, 1.0 }, { "brocken", 5, 1.6 }, { "orakel", 2, 1.0 } },
  { { "murloc", 6, 0.7 }, { "koenig", 1, 3 }, { "orakel", 3, 1.2 }, { "brocken", 4, 2 }, { "flitzer", 8, 0.45 }, { "murloc", 6, 0.7 } },
}
local HP_JE_WELLE = 0.26

-- Modelle: je Art ein eigener Vorrat, damit nichts neu laden muss. Lädt eines nicht, der große Murloc.
local MODELLE = {
  murky = { display = 15369, ersatz = 31, anzahl = 12 },
  gross = { display = 31, anzahl = 10 },
  gurky = { display = 15984, ersatz = 31, anzahl = 4 },
}
local ANIM_TOD, ANIM_BRUELLEN, ANIM_ZAUBER = { 1, 0 }, { 74, 55, 0 }, { 51, 52, 0 }

local V = { key = "verteidigung", musik = "mayhem", name = L.GAME_DEFENSE, info = L.GAME_DEFENSE_INFO,
  icon = "Interface\\Icons\\Spell_Fire_TotemOfWrath",
  WELLEN = WELLEN, TURM = TURM, FEINDE = FEINDE, HERZEN = HERZEN, START_GLUT = START_GLUT, RAND = RAND, FUSS = FUSS }

-- Weg ----------------------------------------------------------------------------------------------

-- Punkte des Wegs in Punkten der Spielfläche und die Strecke am Boden bis zu jedem Punkt
local WX, WY, WS = {}, {}, {}
local WEG_LAENGE = 0
do
  local w = KARTE.weg
  for i = 1, floor(#w / 2) do
    WX[i], WY[i] = w[2 * i - 1] * B, w[2 * i] * H
    if i == 1 then
      WS[i] = 0
    else
      local dx, dy = WX[i] - WX[i - 1], (WY[i] - WY[i - 1]) / K
      WS[i] = WS[i - 1] + sqrt(dx * dx + dy * dy)
    end
  end
  WEG_LAENGE = WS[#WS]
end
V.WEG_LAENGE = WEG_LAENGE

-- Abstand am Boden zwischen zwei Punkten der Spielfläche (die Tiefe ist verkürzt)
local function abstand(x1, y1, x2, y2)
  local dx, dy = x2 - x1, (y2 - y1) / K
  return sqrt(dx * dx + dy * dy)
end
V.abstand = abstand

-- Lage eines Murlocs auf dem Weg aus seiner Strecke e.s. e.i: aktuelles Wegstück (läuft nur vorwärts)
local function wegPunkt(e)
  local n = #WS
  while e.i < n - 1 and WS[e.i + 1] <= e.s do e.i = e.i + 1 end
  local i = e.i
  local a, b = WS[i], WS[i + 1]
  local t = (b > a) and min(1, max(0, (e.s - a) / (b - a))) or 0
  local dx, dy = WX[i + 1] - WX[i], WY[i + 1] - WY[i]
  e.x, e.y = WX[i] + dx * t, WY[i] + dy * t
  e.rx, e.ry = dx, dy
  -- seitlich etwas versetzt, damit eine Gruppe nicht in einer Linie läuft
  local l = sqrt(dx * dx + dy * dy)
  if l > 0 then e.ox, e.oy = -dy / l * e.versatz, dx / l * e.versatz * K end
end

-- Wo ein Murloc in einer Weile wäre, wenn er im Murloc-Schritt weiterliefe (Ziel der Bombe).
-- Langsame und gebremste treffen die Bomben so gut, schnelle Flitzer sind schon vorbei.
local VORHER = { i = 1, versatz = 0, s = 0 }
local BOMBE_FLUG, BOMBE_VORHALT = 0.85, 18
local function vorhersage(e)
  VORHER.i, VORHER.s = e.i, min(WEG_LAENGE, e.s + BOMBE_VORHALT * BOMBE_FLUG)
  wegPunkt(VORHER)
  return VORHER.x, VORHER.y
end

-- Modelle ------------------------------------------------------------------------------------------

-- Licht wie in Show und Whack: Mondlicht als Grundlicht, warmes Feuerlicht dazu. Die Arten färben es.
local LICHT = {
  normal = { amb = { 0.66, 0.7, 0.92 }, ai = 0.8, dif = { 1, 0.74, 0.46 }, di = 0.85 },
  gold = { amb = { 1, 0.8, 0.32 }, ai = 1.0, dif = { 1, 0.86, 0.4 }, di = 1.1 },
  panzer = { amb = { 0.48, 0.58, 0.85 }, ai = 0.95, dif = { 0.72, 0.84, 1 }, di = 1.0 },
  orakel = { amb = { 0.55, 0.95, 0.7 }, ai = 0.95, dif = { 0.7, 1, 0.75 }, di = 0.9 },
  frost = { amb = { 0.5, 0.75, 1 }, ai = 1.1, dif = { 0.6, 0.85, 1 }, di = 1.0 },
  treffer = { amb = { 1, 0.55, 0.45 }, ai = 1.2, dif = { 1, 0.6, 0.5 }, di = 1.2 },
}
local function licht(m, art)
  if not (m and m.SetLight) then return end
  local l = LICHT[art] or LICHT.normal
  local ok = false
  if CreateColor and CreateVector3D then
    ok = pcall(m.SetLight, m, true, {
      omnidirectional = false, point = CreateVector3D(-0.6, 1, -0.4),
      ambientIntensity = l.ai, ambientColor = CreateColor(l.amb[1], l.amb[2], l.amb[3]),
      diffuseIntensity = l.di, diffuseColor = CreateColor(l.dif[1], l.dif[2], l.dif[3]),
    })
  end
  if not ok then
    pcall(m.SetLight, m, true, false, -0.6, 1, -0.4, l.ai, l.amb[1], l.amb[2], l.amb[3], l.di, l.dif[1], l.dif[2], l.dif[3])
  end
end

local function geladen(m)
  if not m then return false end
  local ok, datei = pcall(m.GetModelFileID, m)
  return ok and type(datei) == "number" and datei > 0
end

local function anim(m, liste)
  for _, id in ipairs(liste) do
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

-- Kamera um RAND zurück: der Murloc wirkt so groß wie ohne Rand, der Rahmen hat Luft für die Glieder
local function kamera(m)
  if m.SetCamDistanceScale then pcall(m.SetCamDistanceScale, m, RAND) end
end

local function anzeigen(m, display)
  pcall(m.SetDisplayInfo, m, display)
  kamera(m)
end

local function modell(r, display, ersatz)
  local ok, m = pcall(CreateFrame, "PlayerModel", nil, r)
  if not (ok and m and m.SetDisplayInfo) then return nil end
  m:SetSize(48, 48)
  -- sonst wirft das Modell beim Verstecken alles weg
  if m.SetKeepModelOnHide then pcall(m.SetKeepModelOnHide, m, true) end
  m:SetScript("OnModelLoaded", kamera)
  m.display, m.ersatzId = display, ersatz
  anzeigen(m, display)
  m:Hide()
  return m
end

local function alpha(obj, a, dreiD)
  obj:SetAlpha(a)
  if dreiD and obj.SetModelAlpha then pcall(obj.SetModelAlpha, obj, a) end
end

-- Kleinkram ----------------------------------------------------------------------------------------

local function teil(t, name)
  local k = KARTE.teile[name]
  if not k then return false end
  t:SetTexture(KARTE.teileTextur)
  t:SetTexCoord(k[1], k[2], k[3], k[4])
  return true
end

-- Weicher Lichtfleck aus dem Atlas der Spiele (Funke), ohne Atlas der runde Fleck
local function glanz(t)
  if not S.atlas(t, "funke") then
    t:SetTexture(S.KREIS)
    t:SetTexCoord(0, 1, 0, 1)
  end
end

-- Zuruf an Stelle x, y der Karte (y nach unten positiv, SP:Ruf will es negativ)
local function ruf(text, x, y, farbe) SP:Ruf(text, x, -y, farbe) end

local function platz(obj, x, y)
  obj:ClearAllPoints()
  obj:SetPoint("CENTER", V.r, "TOPLEFT", x, -y)
end

-- Strich eines Blitzes: Line-Objekt, wenn es das gibt, sonst ein gedrehter weißer Strich. Darunter ein
-- weicher, gestreckter Schein (der runde Fleck des Spiels, kein Ring).
local function strich(parent)
  local st = {}
  local ok, l = false, nil
  if parent.CreateLine then ok, l = pcall(parent.CreateLine, parent, nil, "OVERLAY", nil, 2) end
  if ok and l and l.SetStartPoint and l.SetEndPoint and l.SetThickness then
    st.linie = l
    l:SetColorTexture(1, 1, 1, 1)
  else
    st.bild = parent:CreateTexture(nil, "OVERLAY", nil, 2)
    st.bild:SetTexture(S.WEISS)
  end
  st.kern = st.linie or st.bild
  if st.kern.SetBlendMode then st.kern:SetBlendMode("ADD") end
  st.kern:SetVertexColor(0.85, 0.9, 1)
  st.kern:Hide()
  st.schein = parent:CreateTexture(nil, "OVERLAY", nil, 1)
  st.schein:SetTexture(S.KREIS)
  if st.schein.SetBlendMode then st.schein:SetBlendMode("ADD") end
  st.schein:SetVertexColor(0.35, 0.45, 1)
  st.schein:Hide()
  return st
end

local function strichSetzen(st, x1, y1, x2, y2, a)
  local dx, dy = x2 - x1, y2 - y1
  local laenge = sqrt(dx * dx + dy * dy)
  local w = atan2(-dy, dx)
  local mx, my = (x1 + x2) / 2, (y1 + y2) / 2
  if st.linie then
    st.linie:SetStartPoint("TOPLEFT", V.r, x1, -y1)
    st.linie:SetEndPoint("TOPLEFT", V.r, x2, -y2)
    st.linie:SetThickness(1.5)
  else
    st.bild:SetSize(laenge + 1, 1.5)
    platz(st.bild, mx, my)
    if st.bild.SetRotation then st.bild:SetRotation(w) end
  end
  st.kern:SetAlpha(a)
  st.kern:Show()
  st.schein:SetSize(laenge + 6, 7)
  platz(st.schein, mx, my)
  if st.schein.SetRotation then st.schein:SetRotation(w) end
  st.schein:SetAlpha(0.6 * a)
  st.schein:Show()
end

local function strichAus(st)
  st.kern:Hide()
  st.schein:Hide()
end

function V:Tiefe(y)
  return self.basis + TIEFE0 + max(0, min(TIEFEN, floor(y / H * TIEFEN)))
end

local function aufwertKosten(art, stufe)
  return floor(TURM[art].kosten * (stufe == 1 and 0.9 or 1.5) + 0.5)
end
V.aufwertKosten = aufwertKosten

-- Aufbau -------------------------------------------------------------------------------------------

function V:Bauen(r)
  self.r = r
  local basis = (r.GetFrameLevel and r:GetFrameLevel()) or 1
  self.basis = basis
  local karte = r:CreateTexture(nil, "BACKGROUND", nil, 2)
  karte:SetAllPoints()
  karte:SetTexture(KARTE.textur)
  karte:SetTexCoord(0, KARTE.b, 0, KARTE.h)

  -- Ein Klick ins Leere schließt das Menü
  local leer = CreateFrame("Button", nil, r)
  leer:SetAllPoints()
  leer:SetFrameLevel(basis + 1)
  leer:SetScript("OnClick", function() V:MenueZu() end)
  self.leer = leer

  -- Boden: Reichweite, Schatten, Hervorhebung des Bauplatzes
  local boden = CreateFrame("Frame", nil, r)
  boden:SetAllPoints()
  boden:SetFrameLevel(basis + 2)
  self.boden = boden
  self.reichweite = S.kreis(boden, 20, 20, { 1, 0.92, 0.75, 1 }, "ARTWORK")
  self.reichweite:SetAlpha(0.2)
  self.reichweite:Hide()
  self.hell = S.kreis(boden, 30, 24, { 1, 0.85, 0.6, 1 }, "ARTWORK", true)
  self.hell:SetAlpha(0.22)
  self.hell:Hide()

  -- Lagerfeuer (die Feuerstelle ist in der Karte, die Flammen flackern darüber)
  local fx, fy = KARTE.feuer[1] * B, KARTE.feuer[2] * H
  local feuerRahmen = CreateFrame("Frame", nil, r)
  feuerRahmen:SetAllPoints()
  feuerRahmen:SetFrameLevel(self:Tiefe(fy))
  self.feuer = feuerRahmen:CreateTexture(nil, "ARTWORK")
  self.feuer:SetSize(30, 30)
  S.feuer(self.feuer)
  platz(self.feuer, fx, fy - 9)
  self.lagerX, self.lagerY = WX[#WX], WY[#WY]

  -- Bauplätze: Knopf mit dem Turmbild, Ebene nach der Höhe im Bild
  self.felder = {}
  for i, f in ipairs(KARTE.felder) do
    local px, py = f.x * B, f.y * H
    local b = CreateFrame("Button", nil, r)
    b:SetSize(30, 42)
    b:SetPoint("BOTTOM", r, "TOPLEFT", px, -(py + 11))
    b:SetFrameLevel(self:Tiefe(py))
    b.px, b.py, b.nr = px, py, i
    b.bild = b:CreateTexture(nil, "ARTWORK")
    b.bild:SetSize(TURM_B, TURM_H)
    b.bild:SetPoint("TOPLEFT", r, "TOPLEFT", px - TURM_B / 2, -(py - (TURM_H - TURM_FUSS)))
    b.bild:Hide()
    b:SetScript("OnClick", function(self) V:FeldKlick(self) end)
    b:SetScript("OnEnter", function(self) V:FeldZeigen(self, true) end)
    b:SetScript("OnLeave", function(self) V:FeldZeigen(self, false) end)
    self.felder[i] = b
  end

  -- Murlocs: Modelle je Art, dazu Ersatzsymbol, Schatten und Lebensbalken je Platz
  self.vorrat = {}
  for name, d in pairs(MODELLE) do
    self.vorrat[name] = {}
    for _ = 1, d.anzahl do
      local m = modell(r, d.display, d.ersatz)
      if m then table.insert(self.vorrat[name], m) end
    end
  end
  local oben = CreateFrame("Frame", nil, r)
  oben:SetAllPoints()
  oben:SetFrameLevel(basis + TIEFE0 + TIEFEN + 1)
  self.oben = oben
  self.feinde = {}
  for i = 1, MAX_FEINDE do
    local e = { nr = i }
    e.huelle = CreateFrame("Frame", nil, r)
    e.huelle:SetSize(24, 24)
    e.huelle:Hide()
    e.kopf = e.huelle:CreateTexture(nil, "ARTWORK")
    e.kopf:SetAllPoints()
    e.kopf:SetTexture(KOPF)
    e.schatten = S.kreis(boden, 16, 6, { 0, 0, 0, 1 }, "ARTWORK")
    e.schatten:Hide()
    e.balkenGrund = oben:CreateTexture(nil, "ARTWORK")
    e.balkenGrund:SetColorTexture(0, 0, 0, 0.7)
    e.balkenGrund:Hide()
    e.balken = oben:CreateTexture(nil, "OVERLAY")
    e.balken:SetTexture(S.WEISS)
    e.balken:Hide()
    self.feinde[i] = e
  end
  self.bossName = S.schrift(oben, "GameFontNormalSmall", GOLD)
  self.bossName:SetText(L.DEFENSE_BOSS_NAME)
  self.bossName:Hide()

  -- Geschosse: Bild und Schein darüber, Schatten am Boden (Bombe)
  self.geschosse = {}
  for i = 1, MAX_GESCHOSSE do
    local g = {}
    g.schein = oben:CreateTexture(nil, "ARTWORK")
    glanz(g.schein)
    if g.schein.SetBlendMode then g.schein:SetBlendMode("ADD") end
    g.schein:Hide()
    g.bild = oben:CreateTexture(nil, "OVERLAY")
    g.bild:Hide()
    g.schatten = S.kreis(boden, 7, 3, { 0, 0, 0, 1 }, "OVERLAY")
    g.schatten:SetAlpha(0.45)
    g.schatten:Hide()
    self.geschosse[i] = g
  end
  -- Effekte: Lichtblitze, Funken, Rauch
  self.effekte = {}
  for i = 1, MAX_EFFEKTE do
    local t = oben:CreateTexture(nil, "OVERLAY", nil, 1)
    glanz(t)
    t:Hide()
    self.effekte[i] = { bild = t, textur = "glanz" }
  end
  -- Kettenblitze: Striche und Ketten (Punkte der Ziele)
  self.striche, self.ketten, self.strichZahl = {}, {}, 0
  for i = 1, MAX_STRICHE do self.striche[i] = strich(oben) end
  for i = 1, MAX_KETTEN do self.ketten[i] = { x = {}, y = {}, n = 0 } end

  -- Bedienung oben: nächste Welle, doppeltes Tempo, Hinweis; Banner in der Mitte
  local hud = CreateFrame("Frame", nil, r)
  hud:SetAllPoints()
  hud:SetFrameLevel(basis + TIEFE0 + TIEFEN + 2)
  self.hud = hud
  self.weiter = S.textKnopf(hud, L.DEFENSE_NEXT, 92, function() V:WelleRufen() end)
  self.weiter:SetHeight(18)
  self.weiter:SetPoint("TOPLEFT", 4, -4)
  S.tooltip(self.weiter, L.DEFENSE_NEXT, L.DEFENSE_NEXT_HELP)
  self.schnell = S.textKnopf(hud, L.DEFENSE_FAST, 26, function() V:TempoUmschalten() end)
  self.schnell:SetHeight(18)
  self.schnell:SetPoint("TOPLEFT", 100, -4)
  S.tooltip(self.schnell, L.DEFENSE_FAST_TITLE, L.DEFENSE_FAST_HELP)
  self.hinweis = S.schrift(hud, "GameFontHighlightSmall", F.text)
  self.hinweis:SetPoint("TOPLEFT", 132, -5)
  self.hinweis:SetWidth(B - 138)
  self.hinweis:SetJustifyH("LEFT")
  -- Banner in der Mitte: bricht um, bleibt in der Spielfläche
  self.banner = S.schrift(hud, "GameFontNormalLarge", GOLD)
  self.banner:SetWidth(B - 24)
  self.banner:SetPoint("CENTER", r, "TOPLEFT", B / 2, -H / 2)

  -- Menü am Bauplatz: bis zu fünf Knöpfe mit Bild und Preis
  local menue = S.kasten(r, "Frame", { 0.06, 0.05, 0.06, 0.94 }, F.akzent)
  menue:SetFrameLevel(basis + TIEFE0 + TIEFEN + 3)
  menue:EnableMouse(true)
  menue.titel = S.schrift(menue, "GameFontNormalSmall", F.akzent)
  menue.titel:SetPoint("TOP", 0, -4)
  menue.knoepfe = {}
  for i = 1, #TURM_REIHE do
    local k = S.kasten(menue, "Button", F.flaeche, F.rand)
    k:SetSize(30, 42)
    k.bild = k:CreateTexture(nil, "ARTWORK")
    k.bild:SetSize(22, 33)
    k.bild:SetPoint("TOP", 0, 0)
    k.preis = S.schrift(k, "GameFontNormalSmall", GOLD)
    k.preis:SetPoint("BOTTOM", 0, 2)
    k:SetScript("OnClick", function(self) V:MenueWahl(self) end)
    k:SetScript("OnEnter", function(self) S.randFarbe(self, F.akzent) V:MenueTipp(self) end)
    k:SetScript("OnLeave", function(self) S.randFarbe(self, F.rand) GameTooltip:Hide() V:MenueTipp(nil) end)
    menue.knoepfe[i] = k
  end
  menue:Hide()
  self.menue = menue
end

-- Anzeige ------------------------------------------------------------------------------------------

function V:Hinweis(text, farbe)
  self.hinweis:SetText(text or "")
  self.hinweis:SetTextColor(rgba(farbe or F.text))
end

function V:Banner(text, dauer, farbe)
  self.banner:SetText(text)
  self.banner:SetTextColor(rgba(farbe or GOLD))
  self.banner:SetAlpha(1)
  self.bannerBis = self.t + (dauer or 1.8)
end

-- Legende unter der Spielfläche: Glut, Herzen, Welle. Neu gezeigt, wenn sich etwas ändert.
function V:LegendeSetzen()
  self.legende = self.legende or {
    { atlas = "glut", bild = "Interface\\Icons\\Spell_Fire_Incinerate" },
    { bild = KARTE.teileTextur, coords = KARTE.teile.herz },
    { bild = KOPF },
  }
  self.legende[1].text = tostring(self.glut)
  self.legende[2].text = tostring(self.herzen)
  self.legende[3].text = string.format(L.DEFENSE_WAVE_OF, max(1, self.welle), #WELLEN)
  local stand = self.glut .. ":" .. self.herzen .. ":" .. self.welle
  if stand ~= self.legendeStand and SP.aktiv == self and SP.laeuft then
    self.legendeStand = stand
    SP:LegendeZeigen(self)
  end
end

function V:Glut(n, x, y)
  self.glut = self.glut + n
  if x and n ~= 0 then ruf((n > 0 and "+" or "") .. n, x, y, GOLD) end
  self:LegendeSetzen()
  self:MenueAuffrischen()
end

-- Was die nächste Welle bringt: neue Gegner bekommen einen Tipp, sonst die Zusammensetzung
function V:Vorschau()
  local w = WELLEN[self.welle + 1]
  if not w then return end
  local zahl, neu = {}, nil
  for _, g in ipairs(w) do
    zahl[g[1]] = (zahl[g[1]] or 0) + g[2]
    local frueher = false
    for i = 1, self.welle do
      for _, h in ipairs(WELLEN[i]) do if h[1] == g[1] then frueher = true end end
    end
    if not frueher and L.DEFENSE_NEW[g[1]] and not neu then neu = g[1] end
  end
  if neu then return self:Hinweis(L.DEFENSE_NEW[neu], F.hinweis) end
  local teile = {}
  for _, art in ipairs(FEIND_REIHE) do
    if zahl[art] then table.insert(teile, string.format(L.DEFENSE_COUNT, zahl[art], L.DEFENSE_UNITS[art])) end
  end
  self:Hinweis(string.format(L.DEFENSE_PREVIEW, table.concat(teile, ", ")), F.leise)
end

-- Runde --------------------------------------------------------------------------------------------

function V:Start()
  self:Stop()
  self.t, self.tempo = 0, 1
  self.glut, self.herzen, self.welle = START_GLUT, HERZEN, 0
  self.phase, self.bauBis = "bauen", BAU_ZEIT_START
  self.warteschlange, self.qi, self.serie = {}, 1, 0
  self.geleckt, self.besiegt, self.bummZeit = 0, 0, -10
  self.hpFaktor = 1
  self.bannerBis, self.legendeStand = nil, nil
  self.banner:SetText("")
  for _, f in ipairs(self.felder) do
    f.turm, f.stufe, f.investiert, f.bereit = nil, 0, 0, 0
    f.bild:Hide()
  end
  self:ModelleAufwaermen()
  self:TempoZeigen()
  self:Hinweis(L.DEFENSE_HINT, F.hinweis)
  self.weiter:Show()
  self:LegendeSetzen()
  self:WeiterZeigen()
end

-- Alle Modelle kurz unsichtbar zeigen, damit sie laden (versteckte Modelle laden nicht zuverlässig).
-- Lädt eines danach nicht, nimmt es den Ersatz.
function V:ModelleAufwaermen()
  for _, liste in pairs(self.vorrat) do
    for _, m in ipairs(liste) do
      m.benutzt = false
      m:ClearAllPoints()
      m:SetPoint("CENTER", self.r, "TOPLEFT", B / 2, -H / 2)
      alpha(m, 0, true)
      m:Show()
      anzeigen(m, m.display)
    end
  end
  self.aufwaermenBis = self.t + 0.8
end

function V:AufwaermenFertig()
  self.aufwaermenBis = nil
  for _, liste in pairs(self.vorrat) do
    for _, m in ipairs(liste) do
      if not m.benutzt then m:Hide() end
      if not geladen(m) and m.ersatzId and m.display ~= m.ersatzId then
        m.display = m.ersatzId
        anzeigen(m, m.display)
      end
    end
  end
end

function V:TempoUmschalten()
  if not (SP.laeuft and SP.aktiv == self) then return end
  self.tempo = self.tempo == 1 and 2 or 1
  self:TempoZeigen()
end

function V:TempoZeigen()
  self.schnell.text:SetTextColor(rgba(self.tempo == 2 and F.akzent or F.text))
end

function V:WeiterZeigen()
  if self.phase ~= "bauen" then
    self.weiterRest = nil
    return self.weiter:Hide()
  end
  local rest = max(0, floor(self.bauBis - self.t + 0.99))
  if rest ~= self.weiterRest then
    self.weiterRest = rest
    self.weiter.text:SetText(string.format(L.DEFENSE_NEXT_IN, rest))
    self.weiter:Show()
  end
end

-- Next wave: in der Bauzeit sofort los, je 3 Sekunden Rest eine Glut extra
function V:WelleRufen()
  if not (SP.laeuft and SP.aktiv == self) or self.phase ~= "bauen" then return end
  local bonus = min(FRUEH_MAX, floor(max(0, self.bauBis - self.t) / FRUEH_TEILER))
  if bonus > 0 then self:Glut(bonus, 60, 30) end
  self:WelleStarten()
end

function V:WelleStarten()
  self.welle = self.welle + 1
  local w = WELLEN[self.welle]
  local liste, z = {}, 0.6
  for _, g in ipairs(w) do
    for _ = 1, g[2] do
      table.insert(liste, { art = g[1], zeit = z })
      z = z + g[3]
    end
    z = z + 1.0
  end
  self.warteschlange, self.qi, self.welleStart = liste, 1, self.t
  self.hpFaktor = 1 + HP_JE_WELLE * (self.welle - 1)
  self.phase, self.geleckVorher = "welle", self.geleckt
  local boss = false
  for _, g in ipairs(w) do if FEINDE[g[1]].boss then boss = true end end
  if boss then
    self:Banner(L.DEFENSE_BOSS, 2.4, ROT)
    ns.ton("boom")
    ns.mrgl()
  else
    self:Banner(string.format(L.DEFENSE_WAVE, self.welle), 1.6)
    ns.ton("start")
  end
  self:Hinweis("")
  self:WeiterZeigen()
  self:LegendeSetzen()
end

function V:WelleGeschafft()
  local perfekt = self.geleckt == self.geleckVorher
  local bonus = 3 + floor(self.welle / 2)
  self:Glut(bonus)
  SP:Plus(self.welle * 3 + (perfekt and 5 or 0))
  if self.welle >= #WELLEN then
    SP:Plus(self.herzen * 5)
    ns.mrgl()
    return SP:Fertig(L.DEFENSE_WON)
  end
  self:Banner(string.format(perfekt and L.DEFENSE_PERFECT or L.DEFENSE_CLEARED, bonus), 2, perfekt and GOLD or GRUEN)
  ns.ton("paar")
  self.phase, self.bauBis = "bauen", self.t + BAU_ZEIT
  self:Vorschau()
  self:WeiterZeigen()
end

function V:Verloren()
  self.herzen = 0
  self:LegendeSetzen()
  local text = string.format(L.DEFENSE_LOST, self.welle)
  ns.ton("umfallen")
  ns.mrgl()
  SP:Fertig(text)
end

-- Bauen, aufwerten, verkaufen -----------------------------------------------------------------------

function V:FeldBild(f)
  if not f.turm then return f.bild:Hide() end
  teil(f.bild, f.turm .. f.stufe)
  f.bild:Show()
end

function V:Bau(f, art)
  local t = TURM[art]
  if not (t and SP.laeuft and SP.aktiv == self) or f.turm then return false end
  if self.glut < t.kosten then
    self:Hinweis(string.format(L.DEFENSE_NEED, t.kosten), ROT)
    return false
  end
  f.turm, f.stufe, f.investiert, f.bereit = art, 1, t.kosten, self.t + 0.3
  self:Glut(-t.kosten)
  self:FeldBild(f)
  self:Staub(f.px, f.py)
  ns.ton("plopp")
  if self.welle == 0 and self.phase == "bauen" then self:Hinweis(L.DEFENSE_HINT2, F.hinweis) end
  return true
end

function V:Aufwerten(f)
  if not (f.turm and SP.laeuft and SP.aktiv == self) or f.stufe >= 3 then return false end
  local preis = aufwertKosten(f.turm, f.stufe)
  if self.glut < preis then
    self:Hinweis(string.format(L.DEFENSE_NEED, preis), ROT)
    return false
  end
  f.stufe, f.investiert = f.stufe + 1, f.investiert + preis
  self:Glut(-preis)
  self:FeldBild(f)
  self:Staub(f.px, f.py)
  ruf(L.DEFENSE_LEVEL_UP, f.px, f.py - 40, GOLD)
  ns.ton("muenze")
  return true
end

function V:Erstattung(f)
  return floor(f.investiert * VERKAUF)
end

function V:Verkaufen(f)
  if not (f.turm and SP.laeuft and SP.aktiv == self) then return false end
  local zurueck = self:Erstattung(f)
  f.turm, f.stufe, f.investiert = nil, 0, 0
  self:FeldBild(f)
  self:Staub(f.px, f.py)
  self:Glut(zurueck, f.px, f.py - 24)
  ns.ton("muenze")
  return true
end

-- Menü am Bauplatz ----------------------------------------------------------------------------------

function V:ReichweiteZeigen(x, y, weite)
  if not weite then return self.reichweite:Hide() end
  self.reichweite:SetSize(weite * 2, weite * 2 * K)
  platz(self.reichweite, x, y)
  self.reichweite:Show()
end

function V:FeldZeigen(f, an)
  if an then
    self.hell:ClearAllPoints()
    self.hell:SetPoint("CENTER", self.r, "TOPLEFT", f.px, -f.py)
    self.hell:Show()
    if f.turm and not self.menueFeld then self:ReichweiteZeigen(f.px, f.py, TURM[f.turm].reichweite[f.stufe]) end
  else
    self.hell:Hide()
    if not self.menueFeld then self:ReichweiteZeigen() end
  end
end

function V:FeldKlick(f)
  if not (SP.laeuft and SP.aktiv == self) then return end
  if self.menueFeld == f then return self:MenueZu() end
  S.klick()
  self:MenueAuf(f)
end

-- Knöpfe des Menüs für einen Bauplatz: frei = vier Türme, sonst aufwerten und verkaufen
function V:MenueAuf(f)
  self.menueFeld = f
  local m = self.menue
  local knoepfe = {}
  if not f.turm then
    m.titel:SetText("")
    for _, art in ipairs(TURM_REIHE) do table.insert(knoepfe, { aktion = "bauen", art = art }) end
  else
    m.titel:SetText(TURM[f.turm].name .. " " .. LEVEL[f.stufe])
    table.insert(knoepfe, { aktion = "aufwerten", art = f.turm })
    table.insert(knoepfe, { aktion = "verkaufen", art = f.turm })
  end
  local n = #knoepfe
  local titel = f.turm and 13 or 0
  local breite = max(n * 30 + (n - 1) * 4 + 8, f.turm and 90 or 0)
  local hoehe = 50 + titel
  m:SetSize(breite, hoehe)
  local x = min(B - breite / 2 - 2, max(breite / 2 + 2, f.px))
  local y = f.py - 36 - hoehe
  if y < 24 then y = f.py + 14 end
  y = min(H - 2 - hoehe, y)
  m:ClearAllPoints()
  m:SetPoint("TOPLEFT", self.r, "TOPLEFT", x - breite / 2, -y)
  local start = (breite - (n * 30 + (n - 1) * 4)) / 2
  for i, k in ipairs(m.knoepfe) do
    local d = knoepfe[i]
    k:SetShown(d ~= nil)
    if d then
      k.aktion, k.art = d.aktion, d.art
      k:ClearAllPoints()
      k:SetPoint("TOPLEFT", m, "TOPLEFT", start + (i - 1) * 34, -(4 + titel))
    end
  end
  m:Show()
  self:MenueAuffrischen()
  self:ReichweiteZeigen(f.px, f.py, f.turm and TURM[f.turm].reichweite[f.stufe] or nil)
end

-- Preise und gesperrte Knöpfe nach dem Glutstand
function V:MenueAuffrischen()
  local f = self.menueFeld
  if not (f and self.menue:IsShown()) then return end
  for _, k in ipairs(self.menue.knoepfe) do
    if k:IsShown() then
      local preis, frei, bild = nil, true, nil
      if k.aktion == "bauen" then
        preis, bild = TURM[k.art].kosten, k.art .. "1"
        frei = self.glut >= preis
        k.preis:SetText(tostring(preis))
      elseif k.aktion == "aufwerten" then
        if f.stufe >= 3 then
          frei, bild = false, k.art .. "3"
          k.preis:SetText(L.DEFENSE_MAX)
        else
          preis, bild = aufwertKosten(k.art, f.stufe), k.art .. (f.stufe + 1)
          frei = self.glut >= preis
          k.preis:SetText(tostring(preis))
        end
      else
        k.preis:SetText("+" .. self:Erstattung(f))
      end
      if bild then
        teil(k.bild, bild)
        k.bild:SetSize(22, 33)
      elseif not S.atlas(k.bild, "glut") then
        k.bild:SetTexture("Interface\\Icons\\Spell_Fire_Incinerate")
        k.bild:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      end
      if not bild then k.bild:SetSize(22, 22) end
      if frei then k:Enable() else k:Disable() end
      if k.bild.SetDesaturated then k.bild:SetDesaturated(not frei) end
      k.preis:SetTextColor(rgba((not frei and k.aktion ~= "verkaufen") and ROT or GOLD))
    end
  end
end

function V:MenueZu()
  self.menueFeld = nil
  if self.menue then self.menue:Hide() end
  if self.reichweite then self.reichweite:Hide() end
end

function V:MenueTipp(k)
  local f = self.menueFeld
  if not f then return end
  if not k then
    return self:ReichweiteZeigen(f.px, f.py, f.turm and TURM[f.turm].reichweite[f.stufe] or nil)
  end
  local t = TURM[k.art]
  GameTooltip:SetOwner(k, "ANCHOR_RIGHT")
  if k.aktion == "bauen" then
    GameTooltip:SetText(t.name, 1, 1, 1)
    GameTooltip:AddLine(t.info, F.leise[1], F.leise[2], F.leise[3], true)
    GameTooltip:AddLine(string.format(L.DEFENSE_COST, t.kosten), GOLD[1], GOLD[2], GOLD[3])
    self:ReichweiteZeigen(f.px, f.py, t.reichweite[1])
  elseif k.aktion == "aufwerten" then
    GameTooltip:SetText(L.DEFENSE_UPGRADE, 1, 1, 1)
    if f.stufe < 3 then
      GameTooltip:AddLine(string.format(L.DEFENSE_UPGRADE_HELP, t.name, LEVEL[f.stufe + 1]), F.leise[1], F.leise[2], F.leise[3], true)
      GameTooltip:AddLine(string.format(L.DEFENSE_COST, aufwertKosten(f.turm, f.stufe)), GOLD[1], GOLD[2], GOLD[3])
      self:ReichweiteZeigen(f.px, f.py, t.reichweite[f.stufe + 1])
    else
      GameTooltip:AddLine(L.DEFENSE_MAX_HELP, F.leise[1], F.leise[2], F.leise[3], true)
    end
  else
    GameTooltip:SetText(L.DEFENSE_SELL, 1, 1, 1)
    GameTooltip:AddLine(string.format(L.DEFENSE_SELL_HELP, self:Erstattung(f)), F.leise[1], F.leise[2], F.leise[3], true)
  end
  GameTooltip:Show()
end

function V:MenueWahl(k)
  local f = self.menueFeld
  if not (f and SP.laeuft and SP.aktiv == self) then return end
  local ok
  if k.aktion == "bauen" then ok = self:Bau(f, k.art)
  elseif k.aktion == "aufwerten" then ok = self:Aufwerten(f)
  else ok = self:Verkaufen(f) end
  if ok then
    GameTooltip:Hide()
    self:MenueZu()
  end
end

-- Murlocs ------------------------------------------------------------------------------------------

local function nimmModell(self, name)
  for _, m in ipairs(self.vorrat[name] or {}) do
    if not m.benutzt then return m end
  end
end

-- Einen Murloc auf den Weg setzen. s: Strecke (King Mrgls Helfer starten bei ihm). false: kein Platz frei
function V:Feind(art, s)
  local d = FEINDE[art]
  local e
  for _, x in ipairs(self.feinde) do if not x.aktiv then e = x break end end
  if not e then return false end
  local m = nimmModell(self, d.modell)
  if not m and #(self.vorrat[d.modell] or {}) > 0 then return false end
  self.serie = self.serie + 1
  e.aktiv, e.d, e.art, e.serie = true, d, art, self.serie
  e.s, e.i, e.versatz = s or 0, 1, d.boss and 0 or SP.zufall(-3.5, 3.5)
  e.ox, e.oy = 0, 0
  e.max = floor(d.hp * (d.boss and 1 or self.hpFaktor) + 0.5)
  e.hp = e.max
  e.tempo = d.tempo * SP.zufall(0.94, 1.06)
  e.langsamBis, e.langsam, e.blitzBis = 0, 1, 0
  e.zustand, e.seit, e.stirbt = "auftauchen", self.t, nil
  e.heilen = self.t + HEIL_TAKT * SP.zufall(0.5, 1)
  e.gerufen, e.ebene, e.lichtArt, e.blickGesetzt, e.pruefen = nil, nil, nil, nil, self.t + 0.5
  e.wackelnBis, e.funkeln, e.kette = nil, nil, nil
  e.groesse = d.groesse
  e.m = m
  if m then m.benutzt = true end
  wegPunkt(e)
  e.blick = atan2(e.rx, e.ry)
  self:Darstellen(e)
  if s == nil then
    self:Spritzer(WX[1], WY[1])
    if not d.boss and math.random(1, 5) == 1 then
      ruf(SP.spruch(L.MURLOC_LINES), min(B - 40, e.x), e.y - 30, GRUEN)
      ns.mrgl(0.4)
    end
  end
  return true
end

-- Modell oder Ersatzsymbol zeigen (auch später, wenn das Modell erst dann fertig geladen ist)
function V:Darstellen(e)
  local m, d = e.m, e.d
  e.dreiD = m ~= nil and geladen(m)
  if e.dreiD then
    e.huelle:Hide()
    m:SetSize(e.groesse * RAND, e.groesse * RAND)
    kamera(m)
    m:Show()
    e.lichtArt = nil
    anim(m, e.zustand == "sterben" and ANIM_TOD or d.anim)
    e.blickGesetzt = nil
  else
    if m then m:Hide() end
    local g = floor(e.groesse * 0.72 + 0.5)
    e.huelle:SetSize(g, g)
    e.huelle:Show()
  end
  e.ebene, e.alpha, e.links, e.farbe = nil, nil, nil, nil
end

function V:Freigeben(e)
  e.aktiv, e.zustand = false, nil
  if e.m then
    e.m.benutzt = false
    e.m:Hide()
    e.m = nil
  end
  e.huelle:Hide()
  e.schatten:Hide()
  e.balken:Hide()
  e.balkenGrund:Hide()
  if e.d and e.d.boss then self.bossName:Hide() end
end

function V:Ziel(e)
  return e.aktiv and e.zustand ~= "sterben"
end

function V:Schaden(e, menge, art)
  if not self:Ziel(e) then return end
  if e.d.panzer then menge = menge * PANZER[art] end
  e.hp = e.hp - menge
  e.blitzBis = self.t + 0.1
  if e.hp <= 0 then return self:Besiegt(e) end
  -- King Mrgl ruft bei halbem Leben Flitzer zu Hilfe
  if e.d.boss and not e.gerufen and e.hp <= e.max / 2 then
    e.gerufen = true
    if e.dreiD then anim(e.m, ANIM_BRUELLEN) e.wiederLaufen = self.t + 1.2 end
    ruf(L.DEFENSE_BOSS_CALL, min(B - 50, max(50, e.x)), e.y - 52, ROT)
    ns.mrgl()
    ns.ton("boom")
    for k = 1, 5 do self:Feind("flitzer", max(0, e.s - 6 - k * 7)) end
  end
end

function V:Besiegt(e)
  e.zustand, e.stirbt = "sterben", self.t
  local d = e.d
  self.besiegt = self.besiegt + 1
  SP:Plus(d.punkte)
  self:Glut(d.beute)
  if d.beute >= 3 then ruf("+" .. d.beute, e.x, e.y - e.groesse, GOLD) end
  self:Funken(e.x, e.y - e.groesse * 0.4, d.boss and 16 or 5, { 1, 0.6, 0.2 })
  if e.dreiD then anim(e.m, ANIM_TOD) end
  e.balken:Hide()
  e.balkenGrund:Hide()
  if d.boss then
    self.bossName:Hide()
    self:Banner(L.DEFENSE_BOSS_DOWN, 2.2)
    ns.ton("paar")
    ns.mrgl()
  else
    ns.ton("treffer")
    ns.mrgl(0.08)
  end
end

-- Ein Murloc erreicht das Lager: Herzen weg
function V:LagerErreicht(e)
  local n = e.d.schaden
  self.herzen = max(0, self.herzen - n)
  self.geleckt = self.geleckt + n
  ruf(string.format(L.DEFENSE_OUCH, n), self.lagerX + 10, self.lagerY - 30, ROT)
  self.wackelnBis = self.t + 0.4
  ns.ton("umfallen")
  ns.mrgl(0.5)
  self:Freigeben(e)
  self:LegendeSetzen()
  if self.herzen <= 0 then
    self:Verloren()
    return true
  end
end

function V:FeindeDa()
  for _, e in ipairs(self.feinde) do if e.aktiv then return true end end
  return false
end

-- Geschosse und Effekte ----------------------------------------------------------------------------

local function freiesGeschoss(self)
  for _, g in ipairs(self.geschosse) do if not g.art then return g end end
end

-- Schuss eines Turms auf einen Murloc. Ist kein Geschoss frei, trifft er sofort.
function V:Schiessen(f, e)
  local t, st = TURM[f.turm], f.stufe
  local g = freiesGeschoss(self)
  local x, y = f.px, f.py - t.hoehe
  if f.turm == "bombe" then
    local zx, zy = vorhersage(e)
    if not g then return self:Explosion(zx, zy, t.radius[st], t.schaden[st]) end
    g.art, g.x0, g.y0, g.tx, g.ty = "bombe", f.px, f.py, zx, zy
    g.start, g.dauer = self.t, BOMBE_FLUG
    g.schaden, g.radius = t.schaden[st], t.radius[st]
    g.x, g.y = x, y
    if not S.atlas(g.bild, "bombe") then
      g.bild:SetTexture("Interface\\Icons\\INV_Misc_Bomb_02")
      g.bild:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    g.bild:SetSize(9, 9)
    g.bild:SetVertexColor(1, 1, 1)
    g.bild:Show()
    g.schein:Hide()
    g.schatten:Show()
    self:Rauch(x, y - 2, 2)
    return
  end
  if not g then
    if f.turm == "frost" then self:Frost(e, t.schaden[st], t.bremse[st], t.dauer) return end
    return self:Schaden(e, t.schaden[st], f.turm)
  end
  g.art, g.ziel, g.serie, g.x, g.y, g.spurZeit = f.turm, e, e.serie, x, y, 0
  g.tx, g.ty = e.x, e.y - e.groesse * 0.4
  g.schaden = t.schaden[st]
  g.bremse, g.dauer = t.bremse and t.bremse[st], t.dauer
  g.schatten:Hide()
  if f.turm == "feuer" then
    g.v = 210
    g.bild:SetSize(6, 6)
    glanz(g.bild)
    g.bild:SetVertexColor(1, 0.9, 0.55)
    g.schein:SetSize(15, 15)
    g.schein:SetVertexColor(1, 0.45, 0.1)
    g.schein:Show()
    self:Blitz(x, y, 12, { 1, 0.6, 0.2 }, 0.15)
  elseif f.turm == "frost" then
    g.v = 190
    teil(g.bild, "frostsplitter")
    g.bild:SetSize(9, 9)
    g.bild:SetVertexColor(1, 1, 1)
    g.schein:SetSize(12, 12)
    g.schein:SetVertexColor(0.35, 0.65, 1)
    g.schein:Show()
  else
    g.v = 300
    g.bild:SetSize(16, 16)
    g.bild:SetVertexColor(1, 1, 1)
    g.rx, g.ry, g.richtung = g.tx - x, g.ty - y, nil
    teil(g.bild, "speer_0")
    g.schein:Hide()
  end
  g.bild:Show()
end

function V:Frost(e, schaden, bremse, dauer)
  if not self:Ziel(e) then return end
  local b = bremse
  if e.d.boss then b = 1 - (1 - b) * 0.5 end      -- King Mrgl lässt sich nur halb so stark bremsen
  e.langsam, e.langsamBis = b, self.t + dauer
  self:Schaden(e, schaden, "frost")
end

function V:Explosion(x, y, radius, schaden)
  for _, e in ipairs(self.feinde) do
    if self:Ziel(e) and abstand(x, y, e.x, e.y) <= radius then
      e.wackelnBis = self.t + 0.3
      self:Schaden(e, schaden, "bombe")
    end
  end
  -- gerenderte Explosion: Bodenpunkt liegt bei 9 von 32 über dem unteren Bildrand
  local g = radius * 2.6
  self:Effekt("knall", x, y - g * (0.5 - 9 / 32), g, WEISS, 0.5)
  self:Blitz(x, y - 4, radius * 1.6, ORANGE, 0.25)
  self:Funken(x, y - 4, 8, ORANGE)
  self:Rauch(x, y - 8, 2)
  if self.t - self.bummZeit > 0.6 then
    self.bummZeit = self.t
    ns.ton("boom")
  end
end

local function freierEffekt(self)
  for _, e in ipairs(self.effekte) do if not e.bis then return e end end
end

-- Effekt starten: art "blitz" (wächst und verblasst), "funke" (fliegt, fällt), "rauch" (steigt, wird grau)
-- "spur" (bleibt stehen, schrumpft), "knall" (Explosion aus vier gerenderten Bildern, wackelt kurz)
function V:Effekt(art, x, y, groesse, farbe, dauer, vx, vy)
  local fx = freierEffekt(self)
  if not fx then return end
  local t = fx.bild
  if art == "knall" then
    if not teil(t, "explosion0") then
      art = "blitz"
      glanz(t)
      fx.textur = "glanz"
    else
      fx.textur, fx.nr = "knall", 0
    end
  elseif fx.textur ~= "glanz" then
    glanz(t)
    fx.textur = "glanz"
  end
  fx.art, fx.x, fx.y, fx.vx, fx.vy = art, x, y, vx or 0, vy or 0
  fx.groesse, fx.start, fx.bis = groesse, self.t, self.t + dauer
  if t.SetBlendMode then t:SetBlendMode((art == "rauch" or art == "knall") and "BLEND" or "ADD") end
  t:SetVertexColor(farbe[1], farbe[2], farbe[3])
  t:SetSize(groesse, groesse)
  platz(t, x, y)
  t:SetAlpha(1)
  t:Show()
end

function V:Blitz(x, y, groesse, farbe, dauer) self:Effekt("blitz", x, y, groesse, farbe, dauer) end

function V:Funken(x, y, n, farbe)
  for _ = 1, n do
    local w, v = SP.zufall(0, 2 * pi), SP.zufall(25, 70)
    self:Effekt("funke", x, y, SP.zufall(4, 7), farbe, SP.zufall(0.35, 0.6), cos(w) * v, sin(w) * v - 30)
  end
end

function V:Rauch(x, y, n)
  for _ = 1, n do
    self:Effekt("rauch", x + SP.zufall(-4, 4), y, SP.zufall(9, 14), { 0.35, 0.33, 0.32 }, SP.zufall(0.6, 0.9), SP.zufall(-6, 6), -SP.zufall(10, 18))
  end
end

function V:Staub(x, y)
  self:Rauch(x, y + 2, 3)
  self:Funken(x, y - 10, 4, { 1, 0.8, 0.4 })
end

function V:Spritzer(x, y)
  for _ = 1, 5 do
    local w = SP.zufall(pi * 1.1, pi * 1.9)
    self:Effekt("funke", x, y, SP.zufall(3, 5), { 0.55, 0.75, 1 }, SP.zufall(0.4, 0.6), cos(w) * 30, sin(w) * 40)
  end
end

-- Spiellogik ---------------------------------------------------------------------------------------

function V:Tick(dt)
  local rest = min(dt, 0.1) * (self.tempo or 1)
  while rest > 0 do
    local s = min(SCHRITT, rest)
    rest = rest - s
    self.t = self.t + s
    self:Logik(s)
    if not (SP.laeuft and SP.aktiv == self) then return end
  end
  self:Zeichnen(min(dt, 0.1) * (self.tempo or 1))
end

function V:Logik(dt)
  local t = self.t
  if self.aufwaermenBis and t >= self.aufwaermenBis then self:AufwaermenFertig() end

  -- Wellen: Bauzeit, dann die Murlocs der Reihe nach. Alle weg: Bonus und Bauzeit
  if self.phase == "bauen" then
    if t >= self.bauBis then self:WelleStarten() end
  elseif self.phase == "welle" then
    local q = self.warteschlange[self.qi]
    if q and t - self.welleStart >= q.zeit then
      if self:Feind(q.art) then self.qi = self.qi + 1 else self.welleStart = self.welleStart + dt end
    elseif not q and not self:FeindeDa() then
      self:WelleGeschafft()
      if not SP.laeuft then return end
    end
  end

  -- Murlocs laufen, Orakel heilen, Sterbende verblassen
  for _, e in ipairs(self.feinde) do
    if e.aktiv then
      if e.zustand == "sterben" then
        if t - e.stirbt > 0.9 then self:Freigeben(e) end
      else
        if e.zustand == "auftauchen" and t - e.seit >= 0.6 then e.zustand = "laufen" end
        local tempo = e.tempo
        if e.langsamBis > t then tempo = tempo * e.langsam end
        if e.wiederLaufen then
          tempo = 0
          if t >= e.wiederLaufen then
            e.wiederLaufen = nil
            if e.dreiD then anim(e.m, e.d.anim) end
          end
        end
        e.s = e.s + tempo * dt
        if e.s >= WEG_LAENGE then
          if self:LagerErreicht(e) then return end
        else
          wegPunkt(e)
          if e.d.heilt and t >= e.heilen then self:Heilen(e) end
        end
      end
    end
  end

  -- Türme
  for _, f in ipairs(self.felder) do
    if f.turm and t >= f.bereit then self:TurmZielen(f) end
  end

  -- Geschosse
  for _, g in ipairs(self.geschosse) do
    if g.art then self:GeschossFliegen(g, dt) end
  end
end

-- Orakel: heilt alle anderen in seiner Nähe um einen Teil ihres Lebens
function V:Heilen(o)
  o.heilen = self.t + HEIL_TAKT
  local geheilt = false
  for _, e in ipairs(self.feinde) do
    if e ~= o and self:Ziel(e) and e.hp < e.max and abstand(o.x, o.y, e.x, e.y) <= HEIL_WEITE then
      e.hp = min(e.max, e.hp + e.max * HEIL_ANTEIL)
      self:Effekt("funke", e.x, e.y - e.groesse * 0.5, 7, { 0.4, 1, 0.5 }, 0.7, 0, -22)
      geheilt = true
    end
  end
  if geheilt then
    self:Effekt("blitz", o.x, o.y - o.groesse * 0.45, 22, { 0.35, 1, 0.5 }, 0.45)
    if o.dreiD then anim(o.m, ANIM_ZAUBER) o.wiederLaufen = self.t + 0.5 end
  end
end

-- Kettenblitz: der vorderste in Reichweite, dann Sprung für Sprung zum nächsten noch nicht getroffenen
-- in der Nähe, jeder Sprung schwächer. Die Kette merkt sich die Punkte für die Zeichnung.
function V:Kette(f, erstes)
  local t, st = TURM.sturm, f.stufe
  local k
  for _, x in ipairs(self.ketten) do if not x.bis then k = x break end end
  self.kettenNr = (self.kettenNr or 0) + 1
  local nr = self.kettenNr
  local schaden = t.schaden[st]
  local akt = erstes
  local n = 1
  if k then k.x[1], k.y[1] = f.px, f.py - t.hoehe end
  for sprung = 0, t.spruenge[st] do
    if sprung > 0 then
      local bestes, bd
      for _, e in ipairs(self.feinde) do
        if self:Ziel(e) and e.kette ~= nr then
          local d = abstand(akt.x, akt.y, e.x, e.y)
          if d <= SPRUNG_WEITE and (not bd or d < bd) then bestes, bd = e, d end
        end
      end
      if not bestes then break end
      akt = bestes
      schaden = schaden * SPRUNG_ABNAHME
    end
    akt.kette = nr
    local zx, zy = akt.x, akt.y - akt.groesse * 0.45
    n = n + 1
    if k then k.x[n], k.y[n] = zx, zy end
    self:Blitz(zx, zy, 16, BLITZ_FARBE, 0.22)
    self:Blitz(zx, zy, 7, WEISS, 0.12)
    akt.wackelnBis = self.t + 0.15
    self:Schaden(akt, schaden, "sturm")
  end
  self:Blitz(f.px, f.py - t.hoehe, 18, BLITZ_FARBE, 0.25)
  if k then k.n, k.bis = n, self.t + BLITZ_DAUER end
  ns.ton("plopp")
  return n - 1
end

-- Ziel wählen und schießen. Frost trifft alle in Reichweite.
function V:TurmZielen(f)
  local t, st = TURM[f.turm], f.stufe
  local weite = t.reichweite[st]
  if f.turm == "frost" then
    local n = 0
    for _, e in ipairs(self.feinde) do
      if self:Ziel(e) and abstand(f.px, f.py, e.x, e.y) <= weite then
        n = n + 1
        self:Schiessen(f, e)
        if n >= 8 then break end
      end
    end
    if n > 0 then
      f.bereit = self.t + t.takt[st]
      self:Blitz(f.px, f.py - t.hoehe, 16, { 0.4, 0.7, 1 }, 0.25)
    end
    return
  end
  local bestes, wert
  for _, e in ipairs(self.feinde) do
    if self:Ziel(e) and e.zustand ~= "auftauchen" and abstand(f.px, f.py, e.x, e.y) <= weite then
      local w = t.ziel == "staerkster" and (e.hp + e.s * 0.001) or e.s
      if not wert or w > wert then bestes, wert = e, w end
    end
  end
  if bestes then
    if f.turm == "sturm" then self:Kette(f, bestes) else self:Schiessen(f, bestes) end
    f.bereit = self.t + t.takt[st]
  end
end

function V:GeschossWeg(g)
  g.art, g.ziel = nil, nil
  g.bild:Hide()
  g.schein:Hide()
  g.schatten:Hide()
end

function V:GeschossFliegen(g, dt)
  if g.art == "bombe" then
    local p = (self.t - g.start) / g.dauer
    if p >= 1 then
      self:GeschossWeg(g)
      return self:Explosion(g.tx, g.ty, g.radius, g.schaden)
    end
    g.bx, g.by = g.x0 + (g.tx - g.x0) * p, g.y0 + (g.ty - g.y0) * p
    g.x, g.y = g.bx, g.by - (TURM.bombe.hoehe * (1 - p) + 30 * sin(pi * p))
    return
  end
  local e = g.ziel
  if e and e.serie == g.serie and self:Ziel(e) then
    g.tx, g.ty = e.x, e.y - e.groesse * 0.4
  else
    g.ziel = nil
  end
  local dx, dy = g.tx - g.x, g.ty - g.y
  local d = sqrt(dx * dx + dy * dy)
  local weit = g.v * dt
  if d <= weit + 1 then
    local art, ziel = g.art, g.ziel
    self:GeschossWeg(g)
    if not ziel then return end
    if art == "frost" then
      self:Frost(ziel, g.schaden, g.bremse, g.dauer)
      self:Blitz(g.tx, g.ty, 12, EIS, 0.22)
      self:Funken(g.tx, g.ty, 3, EIS_HELL)
    elseif art == "feuer" then
      self:Schaden(ziel, g.schaden, art)
      self:Blitz(g.tx, g.ty, 16, ORANGE, 0.22)
      self:Blitz(g.tx, g.ty, 7, WEISS_GELB, 0.12)
      self:Funken(g.tx, g.ty, 4, ORANGE)
    else
      self:Schaden(ziel, g.schaden, art)
      self:Blitz(g.tx, g.ty, 9, WEISS_GELB, 0.18)
      self:Funken(g.tx, g.ty, 2, WEISS_GELB)
    end
    return
  end
  g.x, g.y = g.x + dx / d * weit, g.y + dy / d * weit
  g.rx, g.ry = dx, dy
  -- Spur: Feuerbälle glühen nach, Frostsplitter glitzern
  if self.t >= (g.spurZeit or 0) then
    if g.art == "feuer" then
      g.spurZeit = self.t + 0.03
      self:Effekt("spur", g.x, g.y, 9, ORANGE, 0.22)
    elseif g.art == "frost" then
      g.spurZeit = self.t + 0.05
      self:Effekt("funke", g.x + SP.zufall(-2, 2), g.y + SP.zufall(-2, 2), 4, EIS_HELL, 0.35, SP.zufall(-6, 6), -8)
    end
  end
end

-- Zeichnen -----------------------------------------------------------------------------------------

local function winkelZu(von, nach, schritt)
  local d = (nach - von + pi) % (2 * pi) - pi
  if abs(d) <= schritt then return nach end
  return von + (d > 0 and schritt or -schritt)
end

function V:Zeichnen(dt)
  local t, r = self.t, self.r
  for _, e in ipairs(self.feinde) do
    if e.aktiv then self:FeindZeichnen(e, dt, t, r) end
  end
  for _, g in ipairs(self.geschosse) do
    if g.art then
      platz(g.bild, g.x, g.y)
      if g.schein:IsShown() then platz(g.schein, g.x, g.y) end
      if g.art == "bombe" then
        platz(g.schatten, g.bx or g.x, g.by or g.y)
      elseif g.art == "speer" and g.rx then
        local nr = floor(((atan2(-g.ry, g.rx) / (2 * pi)) * 16 + 0.5) % 16)
        if nr ~= g.richtung then
          g.richtung = nr
          teil(g.bild, "speer_" .. nr)
        end
      end
    end
  end
  for _, fx in ipairs(self.effekte) do
    if fx.bis then
      local p = (t - fx.start) / (fx.bis - fx.start)
      if p >= 1 then
        fx.bis = nil
        fx.bild:Hide()
      else
        if fx.art == "blitz" then
          local g = fx.groesse * (0.5 + 0.5 * p)
          fx.bild:SetSize(g, g * 0.85)
          fx.bild:SetAlpha(1 - p)
        elseif fx.art == "knall" then
          local nr = min(3, floor(p * 4))
          if nr ~= fx.nr then
            fx.nr = nr
            teil(fx.bild, "explosion" .. nr)
          end
          fx.bild:SetAlpha(p < 0.7 and 1 or (1 - p) / 0.3)
          -- die Stelle des Einschlags wackelt kurz
          local w = p < 0.4 and (1 - p / 0.4) * 1.5 or 0
          platz(fx.bild, fx.x + sin(t * 90) * w, fx.y + cos(t * 70) * w)
        elseif fx.art == "spur" then
          local g = fx.groesse * (1 - 0.6 * p)
          fx.bild:SetSize(g, g)
          fx.bild:SetAlpha(0.8 * (1 - p))
        else
          fx.x, fx.y = fx.x + fx.vx * dt, fx.y + fx.vy * dt
          if fx.art == "funke" then
            fx.vy = fx.vy + 120 * dt
            fx.bild:SetAlpha(1 - p)
          else
            local g = fx.groesse * (1 + p)
            fx.bild:SetSize(g, g)
            fx.bild:SetAlpha(0.55 * (1 - p))
          end
          platz(fx.bild, fx.x, fx.y)
        end
      end
    end
  end
  if self.bannerBis then
    local rest = self.bannerBis - t
    if rest <= 0 then
      self.bannerBis = nil
      self.banner:SetText("")
    else
      self.banner:SetAlpha(min(1, rest * 2))
    end
  end
  self:BlitzeZeichnen(t)
  local dx = 0
  if self.wackelnBis and t < self.wackelnBis then dx = sin(t * 60) * 2 end
  platz(self.feuer, KARTE.feuer[1] * B + dx, KARTE.feuer[2] * H - 9)
  self:WeiterZeigen()
end

-- Blitze: je Glied vier Striche mit Zacken quer zur Richtung, in jedem Bild neu verwackelt
function V:BlitzeZeichnen(t)
  local n, striche = 0, self.striche
  for _, k in ipairs(self.ketten) do
    if k.bis then
      if t >= k.bis then
        k.bis = nil
      else
        local a = min(1, (k.bis - t) / BLITZ_DAUER * 1.5)
        for j = 1, k.n - 1 do
          local x1, y1, x2, y2 = k.x[j], k.y[j], k.x[j + 1], k.y[j + 1]
          local dx, dy = x2 - x1, y2 - y1
          local l = sqrt(dx * dx + dy * dy)
          local qx, qy = 0, 0
          if l > 0 then qx, qy = -dy / l, dx / l end
          local zack = min(5, l * 0.18)
          local ax, ay = x1, y1
          for teil_ = 1, 4 do
            local bx, by = x2, y2
            if teil_ < 4 then
              local q, z = teil_ / 4, (math.random() * 2 - 1) * zack
              bx, by = x1 + dx * q + qx * z, y1 + dy * q + qy * z
            end
            n = n + 1
            if striche[n] then strichSetzen(striche[n], ax, ay, bx, by, a) end
            ax, ay = bx, by
          end
        end
      end
    end
  end
  n = min(n, #striche)
  for i = n + 1, self.strichZahl do strichAus(striche[i]) end
  self.strichZahl = n
end

function V:FeindZeichnen(e, dt, t, r)
  -- Modell nachträglich geladen: vom Symbol aufs Modell wechseln
  if not e.dreiD and e.m and t >= e.pruefen then
    e.pruefen = t + 0.5
    if geladen(e.m) then self:Darstellen(e) end
  end
  local x, y = e.x + e.ox, e.y + e.oy
  -- getroffen von Bombe oder Blitz: kurz wackeln
  if e.wackelnBis and t < e.wackelnBis then x = x + sin(t * 85) * 1.6 end
  -- gebremst: Eis glitzert am Murloc
  if e.langsamBis > t and e.zustand ~= "sterben" and t >= (e.funkeln or 0) then
    e.funkeln = t + 0.3
    self:Effekt("funke", x + SP.zufall(-4, 4), y - e.groesse * SP.zufall(0.3, 0.8), 4, EIS_HELL, 0.5, 0, -10)
  end
  local a = 1
  if e.zustand == "auftauchen" then
    a = min(1, (t - e.seit) / 0.6)
    y = y + (1 - a) * 6
  elseif e.zustand == "sterben" then
    a = max(0, 1 - (t - e.stirbt - 0.35) / 0.55)
  end
  local ebene = self:Tiefe(y)
  local g = e.groesse
  if e.dreiD then
    local m = e.m
    if ebene ~= e.ebene then e.ebene = ebene m:SetFrameLevel(ebene) end
    -- großer Rahmen: unten um den halben Rand tiefer, ganz in der Spielfläche
    local gr = g * RAND
    local mx = min(B - gr / 2, max(gr / 2, x))
    local unten = min(H, max(gr, y + g * FUSS + g * (RAND - 1) / 2))
    m:ClearAllPoints()
    m:SetPoint("BOTTOM", r, "TOPLEFT", mx, -unten)
    if a ~= e.alpha then e.alpha = a alpha(m, a, true) end
    if e.zustand ~= "sterben" and not e.wiederLaufen then
      e.blick = winkelZu(e.blick, atan2(e.rx, e.ry), 7 * dt)
    end
    if not e.blickGesetzt or abs(e.blick - e.blickGesetzt) > 0.03 then
      e.blickGesetzt = e.blick
      pcall(m.SetFacing, m, e.blick)
    end
    local l = (t < e.blitzBis and "treffer") or (e.langsamBis > t and "frost") or e.d.licht
    if l ~= e.lichtArt then e.lichtArt = l licht(m, l) end
  else
    local h = e.huelle
    if ebene ~= e.ebene then e.ebene = ebene h:SetFrameLevel(ebene) end
    h:ClearAllPoints()
    h:SetPoint("BOTTOM", r, "TOPLEFT", x, -(y + 1))
    if a ~= e.alpha then e.alpha = a h:SetAlpha(a) end
    local links = e.rx < 0
    if links ~= e.links then
      e.links = links
      if links then e.kopf:SetTexCoord(0.08, 0.92, 0.08, 0.92) else e.kopf:SetTexCoord(0.92, 0.08, 0.08, 0.92) end
    end
    local c = (t < e.blitzBis and ROT) or (e.langsamBis > t and BLAU) or e.d.farbe
    if c ~= e.farbe then
      e.farbe = c
      e.kopf:SetVertexColor(c[1], c[2], c[3])
    end
  end
  -- Schatten am Boden
  e.schatten:SetSize(g * 0.55, g * 0.2)
  platz(e.schatten, x, y)
  e.schatten:SetAlpha(0.42 * a)
  e.schatten:Show()
  -- Lebensbalken über dem Kopf, sobald er getroffen ist (King Mrgl immer, mit Namen)
  if e.zustand ~= "sterben" and (e.hp < e.max or e.d.boss) then
    local w = e.d.boss and 34 or 18
    local oben = y - g * (e.dreiD and 0.92 or 0.82)
    e.balkenGrund:SetSize(w + 2, 4)
    platz(e.balkenGrund, x, oben)
    local anteil = max(0, e.hp / e.max)
    e.balken:SetSize(max(1, w * anteil), 2)
    e.balken:ClearAllPoints()
    e.balken:SetPoint("LEFT", r, "TOPLEFT", x - w / 2, -oben)
    if anteil > 0.5 then e.balken:SetVertexColor(0.35, 0.9, 0.35)
    elseif anteil > 0.25 then e.balken:SetVertexColor(1, 0.8, 0.2)
    else e.balken:SetVertexColor(1, 0.3, 0.2) end
    e.balkenGrund:Show()
    e.balken:Show()
    if e.d.boss then
      self.bossName:ClearAllPoints()
      self.bossName:SetPoint("BOTTOM", r, "TOPLEFT", min(B - 30, max(30, x)), -(oben - 3))
      self.bossName:Show()
    end
  end
end

function V:Stop()
  for _, e in ipairs(self.feinde or {}) do if e.aktiv then self:Freigeben(e) end end
  for _, liste in pairs(self.vorrat or {}) do
    for _, m in ipairs(liste) do m.benutzt = false m:Hide() end
  end
  for _, g in ipairs(self.geschosse or {}) do self:GeschossWeg(g) end
  for _, fx in ipairs(self.effekte or {}) do fx.bis = nil fx.bild:Hide() end
  for _, k in ipairs(self.ketten or {}) do k.bis = nil end
  for _, st in ipairs(self.striche or {}) do strichAus(st) end
  self.strichZahl = 0
  if self.bossName then self.bossName:Hide() end
  self:MenueZu()
  if self.hell then self.hell:Hide() end
end

SP.Registrieren(V)
