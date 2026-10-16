-- Murloc-Rennen: drei echte Murlocs rennen am Strand zum Lagerfeuer. Vor jedem Rennen setzt man
-- Münzen auf einen Läufer, die Quote zeigt, wer wahrscheinlich gewinnt. Während des Rennens darf
-- man dreimal anfeuern (Klick auf die Bahn): ein kurzer Schub, im Endspurt ein stärkerer, oder der
-- Läufer steht nach einem Sturz sofort wieder auf. Fünf Rennen, die Münzen am Ende sind die Punkte.
--
-- Die Bahn ist eine Blender-Szene (Media/Rennbahn.tga aus grafik/blender/rennbahn.py, Lage der Bahnen
-- in Rennbahn.lua). Alles, was dort hoch ragt (Fackeln, Zuschauer, Fahnen), steht hinter der
-- hinteren Bahn, die Läufer liegen also immer davor. Hintere Bahnen liegen unter den vorderen, die
-- Modelle sind dort kleiner. Kein Rahmen ragt aus der Spielfläche (Modelle schneidet sie nicht ab).
-- Läufer: Murky (15369), Gurky (15984) und der große Murloc (31), jeder mit eigener Lichtfarbe, eigenen
-- Werten und Tagesform. Lädt ein Baby nicht, nimmt es den großen Murloc, lädt gar nichts, hüpft der
-- Murloc-Kopf als Symbol. Die Quoten rechnet der Buchmacher vor jedem Rennen aus 60 gedachten
-- Rennen mit denselben Regeln aus (ohne Anfeuern).
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba
local SP = ns.Spiel

local KOPF = "Interface\\Icons\\INV_Misc_Head_Murloc_01"
local MUENZE = "Interface\\Icons\\INV_Misc_Coin_01"
local JUBEL_BILD = "Interface\\Icons\\Ability_Warrior_BattleShout"
local RENNEN = 5                -- Rennen pro Spiel
local GELD = 50                 -- Münzen zu Beginn
local EINSAETZE = { 10, 25, 50 }
local JUBEL = 3                 -- Anfeuern pro Rennen
local JUBEL_DAUER = 0.7         -- so lange hält ein Schub (Sekunden Rennzeit)
local ENDSPURT = 0.7            -- ab hier (Anteil der Strecke) ist Endspurt
local KNAPP = 0.03              -- so knapp (Anteil der Strecke) gibt es ein Zielfoto
local FIGUR_M = 1.95            -- Kantenlänge des Modellrahmens in Metern der Szene
local FUSS = 0.08               -- die Füße stehen so weit (Anteil der sichtbaren Größe) über der
                                -- Unterkante des Murlocs, wie ihn die Kamera einpasst
local GROSS_31 = 0.85           -- der große Murloc füllt sein Bild mehr aus als die Babys
-- Rahmen der Modelle größer als der Murloc selbst: Rennen, Stürzen und Jubeln sind breiter als die
-- Stehpose, auf die die Kamera das Modell einpasst, sonst schneidet der Rahmen Arme und Beine mit
-- gerader Kante ab. Die Kamera geht um denselben Faktor zurück (SetCamDistanceScale), der Murloc
-- bleibt so groß wie vorher. Weil die Kamera ihn mittig zeigt, sitzt der größere Rahmen um
-- (RAND - 1) / 2 tiefer. Wo der Platz nicht reicht (vordere Bahn unten), wird der Faktor kleiner.
local RAND, RAND_MIN = 1.6, 1.25
local ERSATZ = 31
local RECHTS, VORNE, SCHRAEG = math.pi / 2, 0, 0.5
local SIM_RENNEN, SIM_DT = 60, 0.1
local TEMPO = 1.25              -- Rennzeit läuft so viel schneller als die Uhr (ein Rennen etwa 7 s)
local GOLD = { 1, 0.82, 0.3, 1 }

-- Animationen mit Ersatz, falls das Modell eine nicht hat (wie in der Show)
local ANIM = {
  stehen = { 0 }, rennen = { 5, 4 }, stolpern = { 9, 10, 0 }, sturz = { 1, 9, 0 },
  jubeln = { 68, 55, 0 }, lachen = { 70, 60, 0 }, weinen = { 77, 0 },
  bruellen = { 74, 55, 0 }, muskeln = { 82, 55, 0 }, winken = { 67, 60, 0 },
}
local LAUNEN = { "bruellen", "muskeln", "winken", "lachen" }

-- Die drei Läufer. werte: Tempo, Ausdauer, Glück (1 bis 5, so im Tooltip). tempo: Strecke je
-- Sekunde, antritt: Sekunden bis zum vollen Tempo, ausdauer: so viel Tempo geht bis zum Ziel
-- verloren, spurt: Bonus im Endspurt, schub und stolper: wie oft je Sekunde.
local ARTEN = {
  { name = L.RACE_MURKY, merkmal = L.RACE_TRAIT_MURKY, display = 15369, ersatz = ERSATZ,
    farbe = { 0.55, 0.82, 1 }, werte = { 5, 2, 3 },
    tempo = 0.118, antritt = 0.35, ausdauer = 0.2, spurt = 0.05, schub = 0.25, stolper = 0.08 },
  { name = L.RACE_GURKY, merkmal = L.RACE_TRAIT_GURKY, display = 15984, ersatz = ERSATZ,
    farbe = { 1, 0.62, 0.8 }, werte = { 3, 4, 5 },
    tempo = 0.1, antritt = 0.6, ausdauer = 0.08, spurt = 0.1, schub = 0.4, stolper = 0.06 },
  { name = L.RACE_BIG, merkmal = L.RACE_TRAIT_BIG, display = ERSATZ,
    farbe = { 0.62, 1, 0.55 }, werte = { 2, 5, 2 },
    tempo = 0.1, antritt = 1.0, ausdauer = 0, spurt = 0.3, schub = 0.2, stolper = 0.1 },
}

-- Falls Rennbahn.lua fehlt: ungefähre Lage der Bahnen
local BAHNEN_STANDARD = {
  { y = 0.58, start = 0.2, ziel = 0.66, ende = 0.71, mass = 0.069 },
  { y = 0.73, start = 0.16, ziel = 0.68, ende = 0.74, mass = 0.077 },
  { y = 0.91, start = 0.12, ziel = 0.7, ende = 0.77, mass = 0.088 },
}

local R = { key = "rennen", musik = "rennen", name = L.GAME_RACE, info = L.GAME_RACE_INFO,
  icon = "Interface\\Icons\\INV_MurlocMount",
  legende = {
    { bild = MUENZE, text = L.RACE_LEGEND_ODDS },
    { bild = JUBEL_BILD, text = L.RACE_LEGEND_CHEER },
  } }

-- Rennregeln --------------------------------------------------------------------------------------

-- Ein Schritt eines Läufers (auch für die gedachten Rennen des Buchmachers). t: Rennzeit.
-- Gibt ein Ereignis zurück ("schub", "stolpern", "sturz") oder nil.
local function schritt(l, dt, t)
  local a, ereignis = l.art, nil
  if t >= l.stopBis then
    if t >= l.schubBis and math.random() < a.schub * dt then
      l.schubBis = t + 0.5 + math.random() * 0.4
      ereignis = "schub"
    elseif math.random() < a.stolper * dt then
      l.sturz = math.random() < 0.4
      l.stopBis = t + (l.sturz and (0.9 + math.random() * 0.3) or (0.4 + math.random() * 0.2))
      l.schubBis = 0
      ereignis = l.sturz and "sturz" or "stolpern"
    end
  end
  if t < l.stopBis then return ereignis end
  local v = a.tempo * l.form * (1 - a.ausdauer * l.d) * (1 + 0.08 * math.sin(t * 1.7 + l.phase))
  v = v * math.min(1, 0.4 + 0.6 * t / a.antritt)
  if t < l.schubBis then v = v * 1.55 end
  if l.d >= ENDSPURT then v = v * (1 + a.spurt) end
  if t < l.jubelBis then v = v * l.jubelKraft end
  l.d = l.d + v * dt
  return ereignis
end

local function zuruecksetzen(l, phase)
  l.d, l.stopBis, l.schubBis, l.jubelBis, l.jubelKraft, l.sturz = 0, 0, 0, 0, 1, false
  l.phase = phase
end

local SIM = { {}, {}, {} }
-- Quoten aus gedachten Rennen: Siegchance mit etwas Glättung, Quote 0,9 durch Chance, in halben
-- Schritten zwischen 1,5 und 6
function R:Quoten()
  local siege = { 0, 0, 0 }
  for _ = 1, SIM_RENNEN do
    for i, l in ipairs(self.laeufer) do
      local s = SIM[i]
      s.art, s.form = l.art, l.form
      zuruecksetzen(s, math.random() * 6)
    end
    local t, sieger = 0, nil
    while not sieger and t < 40 do
      t = t + SIM_DT
      for i = 1, #SIM do schritt(SIM[i], SIM_DT, t) end
      for i = 1, #SIM do
        if SIM[i].d >= 1 and (not sieger or SIM[i].d > SIM[sieger].d) then sieger = i end
      end
    end
    if sieger then siege[sieger] = siege[sieger] + 1 end
  end
  for i, l in ipairs(self.laeufer) do
    local chance = (siege[i] + 1) / (SIM_RENNEN + 3)
    l.quote = math.max(1.5, math.min(6, math.floor(0.9 / chance * 2 + 0.5) / 2))
  end
end

local function quoteText(q)
  return string.format(L.RACE_ODDS, q % 1 == 0 and string.format("%d", q) or string.format("%.1f", q))
end

local function farbcode(c)
  return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
end

-- Modelle ------------------------------------------------------------------------------------------

-- Licht wie in der Show (kühles Grundlicht, warmes Feuerlicht von der Seite), das Grundlicht in der
-- Farbe des Läufers
local function licht(m, c)
  if not (m and m.SetLight) then return end
  local r, g, b = 0.3 + 0.55 * c[1], 0.3 + 0.55 * c[2], 0.3 + 0.55 * c[3]
  local ok = false
  if CreateColor and CreateVector3D then
    ok = pcall(m.SetLight, m, true, {
      omnidirectional = false, point = CreateVector3D(-0.6, 1, -0.4),
      ambientIntensity = 0.85, ambientColor = CreateColor(r, g, b),
      diffuseIntensity = 0.85, diffuseColor = CreateColor(1, 0.74, 0.46),
    })
  end
  if not ok then pcall(m.SetLight, m, true, false, -0.6, 1, -0.4, 0.85, r, g, b, 0.85, 1, 0.74, 0.46) end
end

local function geladen(m)
  if not m then return false end
  local ok, datei = pcall(m.GetModelFileID, m)
  return ok and type(datei) == "number" and datei > 0
end

-- Erste Animation aus der Liste, die das Modell hat (nur bei Wechsel)
local function anim(l, name)
  if l.animName == name then return end
  l.animName = name
  local m = l.m
  if not (l.dreiD and m) then return end
  for _, id in ipairs(ANIM[name] or ANIM.stehen) do
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

local function blick(l, w)
  if l.blick == w then return end
  l.blick = w
  if l.dreiD and l.m then pcall(l.m.SetFacing, l.m, w) end
end

-- Sichtbare Größe des Murlocs in der Bahn des Läufers (so groß wäre ein knapper Rahmen)
local function groesse(l)
  local v = l.bahn.groesse
  if l.display == ERSATZ then v = v * GROSS_31 end
  return v
end

-- Kamera um den Faktor des großen Rahmens zurück: der Murloc bleibt so groß wie gewollt. Nach jedem
-- SetDisplayInfo und beim Laden des Modells neu setzen (Laden stellt die Kamera zurück).
local function kamera(l)
  local m = l.m
  if m and m.SetCamDistanceScale then pcall(m.SetCamDistanceScale, m, l.rand or RAND) end
end

-- Rahmen, Bild und Ebene an die aktuelle Bahn anpassen. Der Rahmen ist RAND mal so groß wie der
-- Murloc, höchstens so groß, dass er am Start und unten noch in die Spielfläche passt.
local function einpassen(l)
  local b = l.bahn
  local v = groesse(l)
  local passt = math.min(2 * (b.x0 - 1), 2 * (SP.HOEHE - 1 - b.y - FUSS * v) + v)
  local g = math.floor(math.max(v * RAND_MIN, math.min(v * RAND, passt)) + 0.5)
  l.v, l.g, l.rand = v, g, g / v
  if l.m then
    l.m:SetSize(g, g)
    l.m:SetFrameLevel(b.ebene)
    kamera(l)
  end
  l.huelle:SetSize(g, g)
  l.huelle:SetFrameLevel(b.ebene)
  l.kopf:SetSize(v * 0.62, v * 0.62)
  l.kopf:ClearAllPoints()
  l.kopf:SetPoint("BOTTOM", l.huelle, "BOTTOM", 0, (g - v) / 2 + v * FUSS)
end

-- 3D oder Symbol: Das Modell bleibt immer gezeigt (versteckte Modelle laden nicht zuverlässig),
-- das Symbol nur, solange es nicht geladen ist
local function figurZeigen(l)
  if l.m then l.m:Show() end
  l.huelle:SetShown(not l.dreiD)
end

local function sichtbar(l, a)
  if l.m then
    l.m:SetAlpha(a)
    if l.m.SetModelAlpha then pcall(l.m.SetModelAlpha, l.m, a) end
  end
  l.huelle:SetAlpha(a)
end

-- Aufbau -----------------------------------------------------------------------------------------

function R:Bauen(r)
  self.r = r
  local basis = (r.GetFrameLevel and r:GetFrameLevel()) or 1
  local B, H = SP.BREITE, SP.HOEHE
  local TB, TH = S.RENNBAHN_B or 1, S.RENNBAHN_H or 1
  local szene = r:CreateTexture(nil, "BACKGROUND", nil, 2)
  szene:SetAllPoints()
  szene:SetTexture(S.RENNBAHN)
  szene:SetTexCoord(0, TB, 0, TH)

  -- Ein Stück der Szene noch einmal hell darüber: lässt Fackeln und Feuerschein flackern
  local schein = CreateFrame("Frame", nil, r)
  schein:SetAllPoints()
  schein:SetFrameLevel(basis + 1)
  local function flackern(x, y, b, h)
    local x0, x1 = math.max(0, x - b / 2), math.min(B, x + b / 2)
    local y0, y1 = math.max(0, y - h / 2), math.min(H, y + h / 2)
    local t = schein:CreateTexture(nil, "ARTWORK")
    t:SetTexture(S.RENNBAHN)
    t:SetPoint("TOPLEFT", r, "TOPLEFT", x0, -y0)
    t:SetPoint("BOTTOMRIGHT", r, "TOPLEFT", x1, -y1)
    t:SetTexCoord(x0 / B * TB, x1 / B * TB, y0 / H * TH, y1 / H * TH)
    if t.SetBlendMode then t:SetBlendMode("ADD") end
    t:SetAlpha(0)
    t.phase = math.random() * 6
    return t
  end
  self.flammen = {}
  for _, f in ipairs(S.RENNBAHN_FACKELN or {}) do
    local m = f.mass * B
    table.insert(self.flammen, flackern(f.x * B, f.y * H + 0.15 * m, 0.9 * m, 1.3 * m))
  end
  local fe = S.RENNBAHN_FEUER or { x = 0.866, y = 0.72, mass = 0.077 }
  local fm = fe.mass * B
  self.feuerSchein = flackern(fe.x * B, fe.y * H - 0.2 * fm, 4 * fm, 2.4 * fm)

  -- Lagerfeuer am Ende der Bahn: flackerndes Bild (Stil.lua), zwischen hinterer und mittlerer Bahn
  local fg = math.floor(2.1 * fm + 0.5)
  local feuer = CreateFrame("Frame", nil, r)
  feuer:SetSize(fg, fg)
  feuer:SetFrameLevel(basis + 3)
  feuer:SetPoint("BOTTOM", r, "TOPLEFT", fe.x * B, -math.min(H, fe.y * H + 0.14 * fg))
  local ft = feuer:CreateTexture(nil, "ARTWORK")
  ft:SetAllPoints()
  local takt = S.feuer(ft)
  self.feuerHell = feuer:CreateTexture(nil, "ARTWORK", nil, 1)
  self.feuerHell:SetAllPoints(ft)
  S.feuer(self.feuerHell, takt)
  if self.feuerHell.SetBlendMode then self.feuerHell:SetBlendMode("ADD") end

  -- Bahnen in Pixeln, hinten zuerst. Vordere Bahnen liegen höher (Ebene).
  self.bahnen = {}
  for i, b in ipairs(S.RENNBAHN_BAHNEN or BAHNEN_STANDARD) do
    self.bahnen[i] = {
      nr = i, y = b.y * H, x0 = b.start * B, x1 = b.ziel * B,
      dEnde = (b.ende - b.start) / (b.ziel - b.start),
      groesse = FIGUR_M * b.mass * B, ebene = basis + 2 * i,
    }
  end

  -- Läufer: Modell, Symbol als Ersatz
  self.laeufer = {}
  for i, a in ipairs(ARTEN) do
    local l = { art = a, nr = i, display = a.display, bahn = self.bahnen[i] }
    local ok, m = pcall(CreateFrame, "PlayerModel", nil, r)
    if ok and m and m.SetDisplayInfo then
      if m.SetKeepModelOnHide then pcall(m.SetKeepModelOnHide, m, true) end
      pcall(m.SetDisplayInfo, m, a.display)
      l.m = m
      -- fertig geladen: Kamera wieder zurück, gleich prüfen
      m:SetScript("OnModelLoaded", function()
        kamera(l)
        l.pruefen = 0
      end)
    end
    l.huelle = CreateFrame("Frame", nil, r)
    l.kopf = l.huelle:CreateTexture(nil, "ARTWORK")
    l.kopf:SetTexture(KOPF)
    l.kopf:SetTexCoord(0.92, 0.08, 0.08, 0.92)   -- gespiegelt: Blick nach rechts
    l.kopf:SetVertexColor(a.farbe[1], a.farbe[2], a.farbe[3])
    self.laeufer[i] = l
    einpassen(l)
  end

  -- Schilder: Name, Quote und Merkmal neben jedem Läufer am Start, beim Rennen der Name des
  -- eigenen Läufers über ihm
  local schilder = CreateFrame("Frame", nil, r)
  schilder:SetAllPoints()
  schilder:SetFrameLevel(basis + 8)
  for _, b in ipairs(self.bahnen) do
    b.name = S.schrift(schilder, "GameFontHighlightSmall", F.text)
    b.name:SetJustifyH("LEFT")
    b.info = S.schrift(schilder, "GameFontHighlightSmall", F.leise)
    b.info:SetJustifyH("LEFT")
    b.info:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -1)
  end
  self.marke = S.schrift(schilder, "GameFontNormalSmall", GOLD)
  self.marke:Hide()

  -- Blitz fürs Zielfoto
  local blitz = CreateFrame("Frame", nil, r)
  blitz:SetAllPoints()
  blitz:SetFrameLevel(basis + 9)
  self.blitz = blitz:CreateTexture(nil, "OVERLAY")
  self.blitz:SetAllPoints()
  self.blitz:SetTexture(S.WEISS)
  self.blitz:SetVertexColor(1, 0.97, 0.9)
  self.blitz:Hide()

  -- Tippen: die Bahn am Start ist die Klickfläche (Läufer und Schild)
  self.knoepfe = {}
  for i, b in ipairs(self.bahnen) do
    local k = CreateFrame("Button", nil, r)
    local g = math.floor(b.groesse + 0.5)
    k:SetSize(math.min(120, B - (b.x0 - g / 2)), g * 0.9)
    k:SetPoint("BOTTOMLEFT", r, "TOPLEFT", math.max(0, b.x0 - g / 2), -math.min(H, b.y + 4))
    k:SetFrameLevel(basis + 10)
    k:SetScript("OnClick", function() R:Tippen(i) end)
    k:SetScript("OnEnter", function(self) R:Zeigen(i, self) end)
    k:SetScript("OnLeave", function() R:Zeigen(nil) end)
    self.knoepfe[i] = k
  end
  -- Anfeuern: während des Rennens ist die ganze Bahn die Klickfläche
  self.fang = CreateFrame("Button", nil, r)
  self.fang:SetAllPoints()
  self.fang:SetFrameLevel(basis + 10)
  self.fang:SetScript("OnClick", function() R:Jubeln() end)
  self.fang:Hide()

  -- Kopfzeile in der Szene: Einsatz oder Anfeuern links, Geldbeutel rechts, Kommentar darunter
  local hud = CreateFrame("Frame", nil, r)
  hud:SetAllPoints()
  hud:SetFrameLevel(basis + 12)
  self.einsatzNr = 1
  self.einsatzKnopf = S.textKnopf(hud, "", 64, function() R:EinsatzWechseln() end)
  self.einsatzKnopf:SetHeight(18)
  self.einsatzKnopf:SetPoint("TOPLEFT", 3, -3)
  S.tooltip(self.einsatzKnopf, L.RACE_BET_TITLE, L.RACE_BET_HELP)
  local jubel = CreateFrame("Frame", nil, hud)
  jubel:SetSize(JUBEL * 18 + 2, 18)
  jubel:SetPoint("TOPLEFT", 3, -3)
  jubel:EnableMouse(true)
  S.tooltip(jubel, L.RACE_CHEER_TITLE, L.RACE_CHEER_HELP)
  self.jubelLeiste = jubel
  self.jubelBilder = {}
  for i = 1, JUBEL do
    local t = jubel:CreateTexture(nil, "ARTWORK")
    t:SetSize(16, 16)
    t:SetPoint("LEFT", 1 + (i - 1) * 18, 0)
    t:SetTexture(JUBEL_BILD)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self.jubelBilder[i] = t
  end
  self.geld = S.schrift(hud, "GameFontNormal", GOLD)
  self.geld:SetPoint("TOPRIGHT", -6, -6)
  local beutel = hud:CreateTexture(nil, "ARTWORK")
  beutel:SetSize(14, 14)
  beutel:SetPoint("RIGHT", self.geld, "LEFT", -3, 0)
  beutel:SetTexture(MUENZE)
  beutel:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  self.text = S.schrift(hud, "GameFontNormal", F.text)
  self.text:SetPoint("TOP", 0, -25)
  self.text:SetWidth(B - 16)
end

-- Anzeige ----------------------------------------------------------------------------------------

function R:GeldZeigen()
  self.geld:SetText(SP.punkte or 0)
  local einsatz = math.min(EINSAETZE[self.einsatzNr], SP.punkte or 0)
  self.einsatzKnopf.text:SetText(string.format(einsatz >= (SP.punkte or 0) and L.RACE_ALL_IN or L.RACE_BET, einsatz))
end

function R:JubelZeigen()
  for i, t in ipairs(self.jubelBilder) do
    local frei = i <= self.jubel
    if t.SetDesaturated then t:SetDesaturated(not frei) end
    t:SetAlpha(frei and 1 or 0.3)
  end
end

function R:Kommentar(text, wichtig, farbe)
  local jetzt = ns.jetzt()
  if not wichtig and jetzt < (self.kommentarBis or 0) then return end
  self.kommentarBis = jetzt + 1.2
  self.text:SetText(text)
  self.text:SetTextColor(rgba(farbe or F.text))
end

-- Zuruf über einem Läufer (in der Fläche gehalten)
function R:Rufen(l, text, farbe)
  SP:Ruf(text, math.max(45, math.min(SP.BREITE - 45, l.x or 150)), -math.max(30, (l.kopfOben or 60) + 4), farbe)
end

-- Tooltip und Laune beim Zeigen auf einen Läufer am Start
function R:Zeigen(i, knopf)
  if self.zeigt and self.zeigt ~= i then
    local alt = self:AufBahn(self.zeigt)
    if alt and self.phase == "tippen" then anim(alt, "stehen") end
  end
  self.zeigt = i
  if not (i and self.phase == "tippen") then
    if GameTooltip then GameTooltip:Hide() end
    return
  end
  local l = self:AufBahn(i)
  anim(l, LAUNEN[math.random(1, #LAUNEN)])
  l.launeBis = ns.jetzt() + 1.6
  if not (GameTooltip and knopf) then return end
  local a = l.art
  GameTooltip:SetOwner(knopf, "ANCHOR_RIGHT")
  GameTooltip:SetText(a.name, a.farbe[1], a.farbe[2], a.farbe[3])
  GameTooltip:AddLine(a.merkmal, F.leise[1], F.leise[2], F.leise[3])
  GameTooltip:AddLine(string.format(L.RACE_STATS, a.werte[1], a.werte[2], a.werte[3]), 1, 1, 1)
  GameTooltip:AddLine(L.RACE_FORM[l.formStufe], F.leise[1], F.leise[2], F.leise[3])
  GameTooltip:AddLine(string.format(L.RACE_PAYS, quoteText(l.quote)), GOLD[1], GOLD[2], GOLD[3])
  GameTooltip:Show()
end

function R:AufBahn(i)
  for _, l in ipairs(self.laeufer) do if l.bahn.nr == i then return l end end
end

-- Läufer, Symbol, Schild und Marke an ihre Stelle setzen
function R:Zeichnen(jetzt)
  local B, H = SP.BREITE, SP.HOEHE
  for _, l in ipairs(self.laeufer) do
    local b, g, v = l.bahn, l.g, l.v
    local x = b.x0 + l.d * (b.x1 - b.x0)
    local hopp = 0
    if l.laeuft then hopp = math.abs(math.sin(jetzt * l.takt + l.phase)) * 2.2 end
    x = math.max(g / 2 + 1, math.min(B - g / 2 - 1, x))
    -- Füße auf der Mittellinie: der Murloc sitzt mittig im größeren Rahmen
    local unten = math.max(g + 1, math.min(H - 1, b.y + FUSS * v + (g - v) / 2 - hopp))
    l.x, l.oben = x, unten - g
    l.kopfOben = unten - (g - v) / 2 - v      -- Oberkante des sichtbaren Murlocs
    -- Das Modell steht auch vor dem Laden an seinem Platz (sonst lädt es womöglich nicht)
    if l.m then
      l.m:ClearAllPoints()
      l.m:SetPoint("BOTTOM", self.r, "TOPLEFT", x, -unten)
    end
    if not l.dreiD then
      l.huelle:ClearAllPoints()
      l.huelle:SetPoint("BOTTOM", self.r, "TOPLEFT", x, -unten)
      l.kopf:SetAlpha(l.liegt and 0.55 or 1)
    end
  end
  local t = self.tipp
  if t and self.marke:IsShown() then
    self.marke:ClearAllPoints()
    self.marke:SetPoint("BOTTOM", self.r, "TOPLEFT", t.x, -math.max(12, t.kopfOben + t.v * 0.1))
  end
end

-- Fackeln und Feuerschein flackern, das Feuer selbst schaltet Stil.lua weiter
function R:Kulisse(jetzt)
  for i, t in ipairs(self.flammen) do
    t:SetAlpha(0.12 + 0.3 * math.abs(math.sin(jetzt * 6.1 + t.phase) * math.sin(jetzt * 2.7 + i)))
  end
  self.feuerSchein:SetAlpha(0.06 + 0.16 * math.abs(math.sin(jetzt * 4.3) * math.sin(jetzt * 1.9 + 1)))
  self.feuerHell:SetAlpha(0.05 + 0.12 * math.abs(math.sin(jetzt * 9.1) * math.sin(jetzt * 3.3)))
  if self.blitzBis then
    local rest = (self.blitzBis - jetzt) / 0.45
    if rest <= 0 then
      self.blitzBis = nil
      self.blitz:Hide()
    else
      self.blitz:SetAlpha(0.85 * rest)
    end
  end
end

-- Lädt ein Modell, wird aus dem Symbol ein 3D-Murloc. Lädt ein Baby nicht, der große Murloc.
function R:Laden(jetzt)
  for _, l in ipairs(self.laeufer) do
    if l.m and not l.dreiD and jetzt >= (l.pruefen or 0) then
      l.pruefen = jetzt + 0.3
      if geladen(l.m) then
        l.dreiD = true
        licht(l.m, l.art.farbe)
        kamera(l)
        local name, w = l.animName, l.blick
        l.animName, l.blick = nil, nil
        anim(l, name or "stehen")
        blick(l, w or SCHRAEG)
        figurZeigen(l)
      elseif not l.erneut and jetzt >= (l.ladeStart or 0) + 0.5 then
        -- noch einmal versuchen (war das Fenster beim ersten Mal noch zu?)
        l.erneut = true
        pcall(l.m.SetDisplayInfo, l.m, l.display)
        kamera(l)
      elseif l.display ~= ERSATZ and l.art.ersatz and jetzt >= (l.ladeStart or 0) + 1.2 then
        l.display = ERSATZ
        pcall(l.m.SetDisplayInfo, l.m, ERSATZ)
        einpassen(l)
      end
    end
  end
end

-- Ablauf -----------------------------------------------------------------------------------------

function R:Start()
  self.nr = 1
  SP:Plus(GELD)
  local jetzt = ns.jetzt()
  for _, l in ipairs(self.laeufer) do
    -- jedes Spiel erst wieder das eigentliche Modell versuchen
    l.dreiD, l.animName, l.blick, l.pruefen, l.ladeStart, l.erneut = false, nil, nil, nil, jetzt, nil
    l.display = l.art.display
    if l.m then
      pcall(l.m.SetDisplayInfo, l.m, l.display)
      einpassen(l)
    end
    figurZeigen(l)
  end
  self:Aufstellen()
end

-- Neues Rennen: Bahnen auslosen, Tagesform, Quoten, alle an den Start
function R:Aufstellen()
  if (SP.punkte or 0) <= 0 then return SP:Fertig(L.RACE_BROKE) end
  self.phase, self.tipp, self.sieger, self.einsatz = "tippen", nil, nil, nil
  self.platz, self.t, self.fuehrt, self.endspurt = 0, 0, nil, nil
  self.jubel, self.jubelSperre, self.ergebnisBis, self.pauseBis, self.blitzBis = JUBEL, 0, nil, nil, nil
  self.frierenBis, self.ausgewertet, self.ankunftBis = nil, nil, nil
  local frei = { 1, 2, 3 }
  for _, l in ipairs(self.laeufer) do
    l.bahn = self.bahnen[table.remove(frei, math.random(1, #frei))]
    l.form = SP.zufall(0.94, 1.06)
    l.formStufe = l.form < 0.975 and 1 or (l.form > 1.025 and 3 or 2)
    zuruecksetzen(l, math.random() * 6)
    l.takt = 11 + math.random() * 3
    l.platz, l.steht, l.laeuft, l.liegt, l.launeBis = nil, nil, false, false, nil
    l.animName = nil
    einpassen(l)
    anim(l, "stehen")
    blick(l, SCHRAEG)
    sichtbar(l, 0)
  end
  self.einblenden = 0
  self:Quoten()
  for _, l in ipairs(self.laeufer) do
    local b, a = l.bahn, l.art
    b.name:ClearAllPoints()
    b.name:SetPoint("BOTTOMLEFT", self.r, "TOPLEFT", b.x0 + l.v * 0.32, -(b.y - l.v * 0.42))
    b.name:SetText(farbcode(a.farbe) .. a.name .. "|r  " .. farbcode(GOLD) .. quoteText(l.quote) .. "|r")
    b.info:SetText(a.merkmal)
    b.name:Show()
    b.info:Show()
  end
  for _, k in ipairs(self.knoepfe) do k:Show() end
  self.fang:Hide()
  self.marke:Hide()
  self.blitz:Hide()
  self.einsatzKnopf:Show()
  self.jubelLeiste:Hide()
  self:GeldZeigen()
  self:Kommentar(string.format(L.RACE_PICK, self.nr, RENNEN), true)
  self:Zeichnen(ns.jetzt())
end

function R:EinsatzWechseln()
  if self.phase ~= "tippen" then return end
  self.einsatzNr = self.einsatzNr % #EINSAETZE + 1
  -- Mehr als im Beutel geht nicht: dann weiter zum kleinsten Einsatz
  if EINSAETZE[self.einsatzNr] > (SP.punkte or 0) and self.einsatzNr > 1
    and EINSAETZE[self.einsatzNr - 1] >= (SP.punkte or 0) then
    self.einsatzNr = 1
  end
  self:GeldZeigen()
end

-- Tipp auf den Läufer in Bahn i: Einsatz weg, Countdown
function R:Tippen(i)
  if not (SP.laeuft and SP.aktiv == self) or self.phase ~= "tippen" then return end
  local l = self:AufBahn(i)
  local einsatz = math.min(EINSAETZE[self.einsatzNr], SP.punkte or 0)
  if not l or einsatz <= 0 then return end
  self:Zeigen(nil)
  self.tipp, self.einsatz = l, einsatz
  SP:Plus(-einsatz)
  self:GeldZeigen()
  SP:Ruf("-" .. einsatz, SP.BREITE - 24, -24, F.fehler)
  ns.ton("plopp")
  for _, b in ipairs(self.bahnen) do b.name:Hide() b.info:Hide() end
  for _, k in ipairs(self.knoepfe) do k:Hide() end
  self.einsatzKnopf:Hide()
  self.jubelLeiste:Show()
  self:JubelZeigen()
  self.marke:SetText(l.art.name)
  self.marke:Show()
  for _, o in ipairs(self.laeufer) do
    anim(o, "stehen")
    blick(o, RECHTS)
  end
  anim(l, "bruellen")
  self.phase, self.countdown, self.schritte = "countdown", ns.jetzt(), 0
  self:Kommentar(string.format(L.RACE_BET_ON, einsatz, l.art.name, quoteText(l.quote)), true, GOLD)
end

-- Anfeuern: Schub für den eigenen Läufer, im Endspurt stärker, nach einem Sturz sofort wieder auf
function R:Jubeln()
  if not (SP.laeuft and SP.aktiv == self) or self.phase ~= "rennen" or self.sieger then return end
  local l = self.tipp
  local jetzt = ns.jetzt()
  if self.jubel <= 0 then
    self:Rufen(l, L.RACE_NO_CHEERS, F.leise)
    return
  end
  if jetzt < self.jubelSperre then return end
  self.jubel = self.jubel - 1
  self.jubelSperre = jetzt + JUBEL_DAUER
  self:JubelZeigen()
  local t = self.t
  if t < l.stopBis then
    l.stopBis = t
    self:Kommentar(string.format(L.RACE_UP, l.art.name), true, GOLD)
  else
    l.jubelBis = t + JUBEL_DAUER
    l.jubelKraft = l.d >= ENDSPURT and 1.18 or 1.12
  end
  self:Rufen(l, SP.spruch(L.RACE_CHEER_SHOUT), GOLD)
  ns.ton("treffer")
  ns.mrgl(0.4)
end

function R:Ereignis(l, e)
  local name = l.art.name
  -- Nach dem Zieleinlauf bleibt das Ergebnis stehen
  if self.sieger then
    if e ~= "schub" then self:Rufen(l, SP.spruch(L.RACE_OOPS), F.text) end
    return
  end
  if e == "schub" then
    self:Kommentar(string.format(SP.spruch(L.RACE_SPRINT), name))
  elseif e == "stolpern" then
    self:Kommentar(string.format(SP.spruch(L.RACE_TRIP), name))
    self:Rufen(l, SP.spruch(L.RACE_OOPS), F.text)
  elseif e == "sturz" then
    self:Kommentar(string.format(SP.spruch(L.RACE_FALL), name), true)
    self:Rufen(l, SP.spruch(L.RACE_OOPS), F.text)
    ns.ton("plopp")
  end
end

-- Läufer überquert die Ziellinie
function R:Ueberquert(l, jetzt)
  self.platz = self.platz + 1
  l.platz = self.platz
  if l.platz > 1 then return end
  self.sieger = l
  local zweit = 0
  for _, o in ipairs(self.laeufer) do if o ~= l and o.d > zweit then zweit = o.d end end
  self.fang:Hide()
  if l.d - zweit < KNAPP then
    -- Zielfoto: Blitz, alles steht einen Augenblick still
    self.knapp = true
    self.blitz:SetAlpha(0.85)
    self.blitz:Show()
    self.blitzBis = jetzt + 0.45
    self.frierenBis = jetzt + 0.7
    for _, o in ipairs(self.laeufer) do
      if o.dreiD and o.m and o.m.SetPaused then pcall(o.m.SetPaused, o.m, true) end
    end
    SP:Ruf(L.RACE_PHOTO, SP.BREITE / 2, -62, { 1, 1, 1, 1 })
    ns.ton("karte")
    self.ergebnisBis = jetzt + 1.0
  else
    self.knapp = false
    self.ergebnisBis = jetzt + 0.3
  end
end

-- Ergebnis: Auszahlung nach Quote
function R:Auswerten()
  self.ausgewertet = true
  local s, l = self.sieger, self.tipp
  if s == l then
    local gewinn = math.floor(self.einsatz * l.quote + 0.5)
    SP:Plus(gewinn)
    self:GeldZeigen()
    SP:Ruf("+" .. gewinn, SP.BREITE - 24, -24, GOLD)
    self:Kommentar(string.format(self.knapp and L.RACE_WIN_CLOSE or L.RACE_WIN, s.art.name, gewinn), true, F.erfolg)
    ns.ton("muenze")
    ns.mrgl()
  else
    self:Kommentar(string.format(self.knapp and L.RACE_LOSE_CLOSE or L.RACE_LOSE, s.art.name, self.einsatz), true, F.hinweis)
    ns.ton("minus")
  end
  self.ankunftBis = ns.jetzt() + 5
end

-- Am Ende des Auslaufs: Sieger jubelt, die anderen lachen oder sind traurig
function R:Ankunft(l)
  l.steht, l.laeuft = true, false
  if l.platz == 1 then
    anim(l, "jubeln")
    blick(l, VORNE)
  else
    anim(l, math.random() < 0.5 and "lachen" or "weinen")
    blick(l, SCHRAEG)
  end
end

function R:Rennen(dt, jetzt)
  local faktor = (self.frierenBis and jetzt < self.frierenBis) and 0 or 1
  if self.frierenBis and faktor == 1 then
    self.frierenBis = nil
    for _, o in ipairs(self.laeufer) do
      if o.dreiD and o.m and o.m.SetPaused then pcall(o.m.SetPaused, o.m, false) end
    end
  end
  local sdt = dt * faktor * TEMPO
  self.t = self.t + sdt
  local t = self.t
  if sdt > 0 then
    for _, l in ipairs(self.laeufer) do
      if not l.steht then
        if l.d < 1 then
          local e = schritt(l, sdt, t)
          if e then self:Ereignis(l, e) end
        else
          -- Auslauf hinter dem Ziel, langsam ausrollen
          l.d = math.min(l.bahn.dEnde, l.d + l.art.tempo * 0.6 * sdt)
          if l.d >= l.bahn.dEnde then self:Ankunft(l) end
        end
        local liegt = t < l.stopBis
        l.liegt, l.laeuft = liegt, not liegt and not l.steht
        if liegt then anim(l, l.sturz and "sturz" or "stolpern")
        elseif not l.steht then anim(l, "rennen") end
      end
    end
    -- Über die Linie: wer am weitesten drüber ist, war zuerst da
    repeat
      local naechster
      for _, l in ipairs(self.laeufer) do
        if l.d >= 1 and not l.platz and (not naechster or l.d > naechster.d) then naechster = l end
      end
      if naechster then self:Ueberquert(naechster, jetzt) end
    until not naechster
  end
  if not self.sieger then
    -- Führungswechsel (mit etwas Abstand, sonst flackert der Kommentar) und Endspurt
    local erster
    for _, l in ipairs(self.laeufer) do if not erster or l.d > erster.d then erster = l end end
    if erster ~= self.fuehrt and erster.d > 0.12 and (not self.fuehrt or erster.d > self.fuehrt.d + 0.012) then
      self.fuehrt = erster
      self:Kommentar(string.format(SP.spruch(L.RACE_LEAD), erster.art.name), true)
    end
    if not self.endspurt and erster.d >= ENDSPURT then
      self.endspurt = true
      self:Kommentar(SP.spruch(L.RACE_FINAL), true)
    end
  end
  if self.ergebnisBis and not self.ausgewertet and jetzt >= self.ergebnisBis then self:Auswerten() end
  if self.ausgewertet then
    local alle = true
    for _, l in ipairs(self.laeufer) do if not l.steht then alle = false end end
    if alle or jetzt >= self.ankunftBis then
      self.phase, self.pauseBis = "pause", jetzt + (alle and 2.2 or 0.8)
    end
  end
end

function R:Tick(dt, jetzt)
  self:Kulisse(jetzt)
  self:Laden(jetzt)
  local p = self.phase
  if p == "tippen" then
    if self.einblenden < 1 then
      self.einblenden = math.min(1, self.einblenden + dt / 0.4)
      for _, l in ipairs(self.laeufer) do sichtbar(l, self.einblenden) end
    end
    -- ab und zu macht einer etwas, solange man wählt
    for _, l in ipairs(self.laeufer) do
      if l.launeBis and jetzt >= l.launeBis then
        l.launeBis = nil
        if self.zeigt ~= l.bahn.nr then anim(l, "stehen") end
      end
    end
    if jetzt >= (self.launeNaechste or 0) then
      self.launeNaechste = jetzt + SP.zufall(2.2, 3.5)
      local l = self.laeufer[math.random(1, #self.laeufer)]
      if not l.launeBis and self.zeigt ~= l.bahn.nr then
        anim(l, LAUNEN[math.random(1, #LAUNEN)])
        l.launeBis = jetzt + 1.6
      end
    end
  elseif p == "countdown" then
    -- erst kurz den Tipp zeigen, dann Ready, Set, MRGL! und los
    local seit = jetzt - self.countdown - 0.8
    local s = seit >= 0 and math.floor(seit / 0.6) + 1 or 0
    if s > self.schritte then
      self.schritte = s
      if s <= #L.RACE_READY then
        self:Kommentar(L.RACE_READY[s], true, s == #L.RACE_READY and GOLD or F.text)
        ns.ton(s == #L.RACE_READY and "start" or "plopp")
        if s == 1 then anim(self.tipp, "stehen") end
      else
        self.phase, self.t = "rennen", 0
        for _, l in ipairs(self.laeufer) do
          l.laeuft = true
          anim(l, "rennen")
        end
        self.fang:Show()
        self:Kommentar(SP.spruch(L.RACE_START), true)
        ns.mrgl()
      end
    end
  elseif p == "rennen" then
    self:Rennen(dt, jetzt)
  elseif p == "pause" and jetzt >= self.pauseBis then
    self.nr = self.nr + 1
    if self.nr > RENNEN then
      self.phase = "ende"
      return SP:Fertig(string.format(L.RACE_RESULT, SP.punkte or 0))
    end
    self:Aufstellen()
  end
  self:Zeichnen(jetzt)
end

function R:Stop()
  self.phase = "ende"
  if self.fang then self.fang:Hide() end
  if self.blitz then self.blitz:Hide() end
  if self.marke then self.marke:Hide() end
  self.blitzBis = nil
  for _, l in ipairs(self.laeufer or {}) do
    if l.dreiD and l.m and l.m.SetPaused then pcall(l.m.SetPaused, l.m, false) end
    l.laeuft = false
  end
end

SP.Registrieren(R)
