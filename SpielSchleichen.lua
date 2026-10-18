-- Sneaky Mrgl: Schleich-Spiel als Arcade-Runde (Patricks Idee, 18. Okt, frei nach den Schleich-
-- Spielen der Neunziger, eigene Umsetzung). Zweite Fassung nach Patricks Test ("zu klein, man sieht
-- wenig, Ziel langweilig"): größere Karte und Figuren, der Murloc folgt direkt der Maus, und es
-- geht um Fische statt um eine Mission.
--
-- Agent Mrgl (eigenes Bild aus Blender, grafik/blender/agent.py) schleicht nachts durch ein Defias-
-- Lager (Karte aus Blender, grafik/blender/schleichen.py). Überall liegen Fische. Er trägt bis zu
-- drei und bringt sie in den Bach: Je mehr auf einmal, desto mehr sind sie wert, aber desto mehr
-- verliert er, wenn man ihn erwischt. Goldfische zählen dreifach, eine Runde ganz ohne Alarm gibt
-- das Anderthalbfache. Alle zwei heimgebrachten Fische kommt ein Defias dazu, die Wachen werden
-- schneller. Erwischt ist das Spiel vorbei.
--
-- Die Wachen sind echte Defias aus dem Spiel (PlayerModel). Steht der Murloc in ihrem Sichtkegel
-- und nicht hinter einem Hindernis, füllt sich über ihrem Kopf ein "?" (schneller, je näher er
-- ist), sie bleiben stehen und drehen sich hin. Erst wenn es voll ist: "!", Alarm, Jagd. Wer im
-- Bach ist oder AUFGEBEN Sekunden außer Sicht, ist entkommen.
-- Pappkarton (Rechtsklick): Steht er still, sehen die Wachen nur eine Kiste (außer ganz nah).
-- Läuft er, fällt er langsamer auf als ein Murloc. Keine Spielaktion, keine Nachrichten.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F = S.F
local SP = ns.Spiel
local KARTE = ns.Schleichkarte
local atan2 = math.atan2 or math.atan

local B, H = SP.BREITE, SP.HOEHE
local ZELLE = 5                                      -- Raster für Wege und Sicht (Punkte)
local SPALTEN, ZEILEN = math.ceil(B / ZELLE), math.ceil(H / ZELLE)
local OBEN_FREI = 14                                 -- so weit vom oberen Rand bleiben die Füße
local R = 6                                          -- Abstand zu Hindernissen (Murloc und Wachen)
local TEMPO, TEMPO_KARTON = 72, 30                   -- Punkte je Sekunde
local MURLOC_BILD = 50                               -- Bildgröße des Murlocs in Punkten
-- Wachen: Modellrahmen 1,6-mal so groß wie die Figur (wie in Camp Defense), die Kamera geht um denselben
-- Faktor zurück, so werden Arme und Beine beim Laufen nicht abgeschnitten
local WACHE, RAND = 48, 1.6
local WACHE_TEMPO, WACHE_PLUS, WACHE_MAX, JAGD_TEMPO = 26, 1.2, 40, 56
local SICHT = 66                                     -- so weit sehen die Wachen
local HALB = math.rad(32)                            -- halber Öffnungswinkel, wie Media/Sichtkegel
local MELDEN = 0.8                                   -- Sekunden bis "!" am Rand der Sicht (näher: schneller)
local VERGESSEN = 0.6                                -- so schnell leert sich das "?" wieder
local STUTZEN = 0.35                                 -- ab diesem "?" bleibt die Wache stehen
local NAH_KARTON = 16                                -- einen stillen Karton erkennt sie nur aus dieser Nähe
local FANG = 13
local AUFGEBEN = 3                                   -- Sekunden außer Sicht, dann gibt die Wache auf
local HOEREN = 70                                    -- so weit hören andere Wachen den Ruf
local SAMMELN, TRAGEN = 12, 3
local FISCH, GOLD, GOLD_CHANCE = 10, 30, 0.15
local FISCHE_DA = 2                                  -- so viele Fische liegen gleichzeitig herum
local NEUE_WACHE_JE = 2                              -- heimgebrachte Fische je neuer Wache
local START_WACHEN = 2
local FISCH_BILD = 40
local TEIL_FUSS = 10 / 32                            -- Gegenstände: Fußpunkt über dem unteren Bildrand

local ANIM = { stehen = { 0 }, gehen = { 4, 0 }, rennen = { 5, 4, 0 }, alarm = { 74, 55, 0 }, fangen = { 17, 16, 0 } }

-- Runden der Wachen in Punkten der Karte, in der Reihenfolge, in der sie dazukommen. schleife:
-- Rundweg, sonst hin und zurück. steht: bleibt an seinem Platz und schaut abwechselnd in die
-- Richtungen aus blicke (Grad, 0 = rechts, 90 = unten). display: echte Defias aus dem Spiel (auf
-- Wowhead nachgeschlagen), die weiteren als Ersatz.
local ROUTEN = {
  { name = "feuer", punkte = { { 128, 80 }, { 194, 80 }, { 196, 132 }, { 126, 132 } }, schleife = true,
    display = { 5035, 2357, 2361 } },                                    -- Defias Thug
  { name = "oben", punkte = { { 60, 50 }, { 110, 48 }, { 206, 50 }, { 262, 54 } }, display = { 2357, 5035, 2361 } },  -- Bandit
  { name = "rechts", punkte = { { 274, 88 }, { 276, 174 }, { 244, 174 }, { 244, 96 } }, schleife = true,
    display = { 2361, 2357, 5035 } },                                    -- Cutpurse
  { name = "unten", punkte = { { 56, 176 }, { 150, 178 }, { 236, 176 } }, display = { 2336, 2342, 2357 } },  -- Pathstalker
  { name = "mitte", punkte = { { 60, 100 }, { 90, 112 }, { 150, 150 } }, display = { 2342, 2336, 2357 } },  -- Highwayman
  { name = "tuer", punkte = { { 150, 46 } }, steht = true, blicke = { 90, 150, 30 }, display = { 2316, 2314, 2357 } },  -- Overseer
}

local SN = {
  key = "schleichen", musik = "schleichen", name = L.GAME_SNEAK, info = L.GAME_SNEAK_INFO,
  icon = "Interface\\Icons\\Ability_Stealth",
  legende = {
    { bild = KARTE.teileTextur, coords = KARTE.teile.fisch, punkte = FISCH },
    { bild = KARTE.teileTextur, coords = KARTE.teile.goldfisch, punkte = GOLD },
    { bild = "Interface\\Icons\\Ability_Stealth", text = L.SNEAK_LEGEND_UNSEEN },
    { bild = KARTE.teileTextur, coords = KARTE.teile.karton0, text = L.SNEAK_LEGEND_BOX },
    { bild = KARTE.pfeil, coords = { 0, 1, 0, 1 }, farbe = { 1, 0.82, 0.3 }, text = L.SNEAK_LEGEND_STREAM },
  },
  ROUTEN = ROUTEN, FISCH = FISCH, GOLD = GOLD, TRAGEN = TRAGEN, FANG = FANG, AUFGEBEN = AUFGEBEN,
  NAH_KARTON = NAH_KARTON, START_WACHEN = START_WACHEN, NEUE_WACHE_JE = NEUE_WACHE_JE, RAND = RAND, WACHE = WACHE,
}

-- Kleinkram ----------------------------------------------------------------------------------------

-- Eigene Effekte in der Lautstärke des Reglers unter den Spielen (Musik.lua)
local function ton(name) ns.Musik.Effekt(name) end

local function teil(t, name)
  local k = KARTE.teile[name]
  if not k then return false end
  t:SetTexture(KARTE.teileTextur)
  t:SetTexCoord(k[1], k[2], k[3], k[4])
  return true
end

local function abstand(x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

-- Winkel auf der Karte (0 = rechts, pi/2 = unten) und Drehen mit begrenzter Geschwindigkeit
local function winkel(dx, dy) return atan2(dy, dx) end
local function drehen(von, nach, schritt)
  local d = (nach - von + math.pi) % (2 * math.pi) - math.pi
  if math.abs(d) <= schritt then return nach end
  return von + (d > 0 and schritt or -schritt)
end

-- Richtung 0 bis 7 der Murloc-Bilder: 0 zum Betrachter (nach unten), dann im Uhrzeigersinn
local function richtungsNr(dx, dy)
  local grad = math.deg(atan2(dx, dy)) % 360
  return math.floor((grad + 22.5) / 45) % 8
end

-- Modelle (wie in Camp Defense) --------------------------------------------------------------------

local function kamera(m)
  if m.SetCamDistanceScale then pcall(m.SetCamDistanceScale, m, RAND) end
end

local function licht(m)
  if not (m and m.SetLight) then return end
  local ok = false
  if CreateColor and CreateVector3D then
    ok = pcall(m.SetLight, m, true, {
      omnidirectional = false, point = CreateVector3D(-0.6, 1, -0.4),
      ambientIntensity = 0.75, ambientColor = CreateColor(0.6, 0.68, 0.95),
      diffuseIntensity = 0.85, diffuseColor = CreateColor(1, 0.74, 0.46),
    })
  end
  if not ok then pcall(m.SetLight, m, true, false, -0.6, 1, -0.4, 0.75, 0.6, 0.68, 0.95, 0.85, 1, 0.74, 0.46) end
end

local function geladen(m)
  if not (m and m.GetModelFileID) then return false end
  local ok, datei = pcall(m.GetModelFileID, m)
  return ok and type(datei) == "number" and datei > 0
end

local function anim(w, liste)
  if w.anim == liste or not (w.m and w.dreiD) then
    w.anim = liste
    return
  end
  w.anim = liste
  for _, id in ipairs(liste) do
    local hat = true
    if w.m.HasAnimation then
      local ok, ja = pcall(w.m.HasAnimation, w.m, id)
      if ok and ja ~= nil then hat = ja end
    end
    if hat then
      pcall(w.m.SetAnimation, w.m, id)
      return
    end
  end
end

-- Hindernisse, Raster, Wege -------------------------------------------------------------------------

-- Punkt in einem Hindernis (rand: Abstand dazu). sicht: dünne Laternenpfähle nehmen keine Sicht.
local function imHindernis(x, y, rand, sicht)
  for _, h in ipairs(KARTE.hindernisse) do
    if h[1] == "r" then
      if x >= h[2] - rand and x <= h[4] + rand and y >= h[3] - rand and y <= h[5] + rand then return true end
    elseif not (sicht and h[4] <= 3) then
      local dx, dy, r = x - h[2], y - h[3], h[4] + rand
      if dx * dx + dy * dy <= r * r then return true end
    end
  end
  return false
end
SN.imHindernis = imHindernis

-- Aus Hindernissen und über den Rand hinaus zurückschieben (der Murloc gleitet an Kisten entlang)
local function schieben(x, y, r)
  x = math.max(4, math.min(B - 4, x))
  y = math.max(OBEN_FREI, math.min(H - 4, y))
  for _, h in ipairs(KARTE.hindernisse) do
    if h[1] == "r" then
      local l, o, re, u = h[2] - r, h[3] - r, h[4] + r, h[5] + r
      if x > l and x < re and y > o and y < u then
        local dl, dr, dob, du = x - l, re - x, y - o, u - y
        local m = math.min(dl, dr, dob, du)
        if m == dl then x = l elseif m == dr then x = re elseif m == dob then y = o else y = u end
      end
    else
      local dx, dy = x - h[2], y - h[3]
      local rr = h[4] + r
      local d = math.sqrt(dx * dx + dy * dy)
      if d < rr then
        if d < 0.01 then dx, dy, d = 1, 0, 1 end
        x, y = h[2] + dx / d * rr, h[3] + dy / d * rr
      end
    end
  end
  return x, y
end
SN.schieben = schieben

local WACHE_GEHEN, SICHT_FREI = {}, {}
local function rasterBauen()
  for i = 1, SPALTEN do
    WACHE_GEHEN[i], SICHT_FREI[i] = {}, {}
    for j = 1, ZEILEN do
      local x, y = (i - 0.5) * ZELLE, (j - 0.5) * ZELLE
      local rand = x < 4 or x > B - 4 or y < OBEN_FREI or y > H - 4
      WACHE_GEHEN[i][j] = not rand and x >= KARTE.bachX + 6 and not imHindernis(x, y, R)
      SICHT_FREI[i][j] = not imHindernis(x, y, 0, true)
    end
  end
end
SN.WACHE_GEHEN, SN.SICHT = WACHE_GEHEN, SICHT_FREI

local function zelle(x, y)
  return math.max(1, math.min(SPALTEN, math.floor(x / ZELLE) + 1)), math.max(1, math.min(ZEILEN, math.floor(y / ZELLE) + 1))
end
local function offen(raster, x, y)
  local i, j = zelle(x, y)
  return raster[i][j]
end

local function linieFrei(raster, x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  local n = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / 2))
  for k = 0, n do
    if not offen(raster, x1 + dx * k / n, y1 + dy * k / n) then return false end
  end
  return true
end
SN.linieFrei = linieFrei

local function naechsteFreie(raster, i, j)
  if raster[i][j] then return i, j end
  for r = 1, 14 do
    local bi, bj, bd
    for a = -r, r do
      for b = -r, r do
        if math.max(math.abs(a), math.abs(b)) == r then
          local x, y = i + a, j + b
          if x >= 1 and x <= SPALTEN and y >= 1 and y <= ZEILEN and raster[x][y] then
            local d = a * a + b * b
            if not bd or d < bd then bi, bj, bd = x, y, d end
          end
        end
      end
    end
    if bi then return bi, bj end
  end
  return nil
end

local NACHBARN = { { 1, 0, 1 }, { -1, 0, 1 }, { 0, 1, 1 }, { 0, -1, 1 },
  { 1, 1, 1.414 }, { 1, -1, 1.414 }, { -1, 1, 1.414 }, { -1, -1, 1.414 } }

-- Kürzester Weg (A* mit kleinem Haufen), danach geglättet: von jedem Punkt so weit wie möglich
-- geradeaus. Gibt eine Liste { x, y } bis zum Ziel zurück (ohne den Startpunkt), sonst nil.
local function wegSuchen(raster, x1, y1, x2, y2)
  local si, sj = naechsteFreie(raster, zelle(x1, y1))
  local zi, zj = naechsteFreie(raster, zelle(x2, y2))
  if not (si and zi) then return nil end
  local function nr(i, j) return (j - 1) * SPALTEN + i end
  local start, ziel = nr(si, sj), nr(zi, zj)
  local g, von, zu = { [start] = 0 }, {}, {}
  local haufen = {}
  local function rein(k, f)
    local n = #haufen + 1
    haufen[n] = { k, f }
    while n > 1 do
      local p = math.floor(n / 2)
      if haufen[p][2] <= haufen[n][2] then break end
      haufen[p], haufen[n] = haufen[n], haufen[p]
      n = p
    end
  end
  local function raus()
    local oben = haufen[1][1]
    local letzt = table.remove(haufen)
    if #haufen > 0 then
      haufen[1] = letzt
      local n = 1
      while true do
        local l, r, k = 2 * n, 2 * n + 1, n
        if haufen[l] and haufen[l][2] < haufen[k][2] then k = l end
        if haufen[r] and haufen[r][2] < haufen[k][2] then k = r end
        if k == n then break end
        haufen[k], haufen[n] = haufen[n], haufen[k]
        n = k
      end
    end
    return oben
  end
  local function schaetzen(i, j)
    local a, b = math.abs(i - zi), math.abs(j - zj)
    return math.max(a, b) + 0.414 * math.min(a, b)
  end
  rein(start, 0)
  while #haufen > 0 do
    local k = raus()
    if k == ziel then break end
    if not zu[k] then
      zu[k] = true
      local i, j = (k - 1) % SPALTEN + 1, math.floor((k - 1) / SPALTEN) + 1
      for _, n in ipairs(NACHBARN) do
        local a, b = i + n[1], j + n[2]
        -- schräg nur, wenn beide Nachbarn frei sind (keine Ecken abschneiden)
        if a >= 1 and a <= SPALTEN and b >= 1 and b <= ZEILEN and raster[a][b]
          and (n[3] == 1 or (raster[i][b] and raster[a][j])) then
          local nk = nr(a, b)
          local ng = g[k] + n[3]
          if not g[nk] or ng < g[nk] then
            g[nk], von[nk] = ng, k
            rein(nk, ng + schaetzen(a, b))
          end
        end
      end
    end
  end
  if not g[ziel] then return nil end
  local punkte = {}
  local k = ziel
  while k do
    local i, j = (k - 1) % SPALTEN + 1, math.floor((k - 1) / SPALTEN) + 1
    table.insert(punkte, 1, { (i - 0.5) * ZELLE, (j - 0.5) * ZELLE })
    k = von[k]
  end
  if offen(raster, x2, y2) then punkte[#punkte] = { x2, y2 } end
  local glatt, ax, ay, n = {}, x1, y1, 1
  while n <= #punkte do
    local weit = n
    for m = n + 1, #punkte do
      if linieFrei(raster, ax, ay, punkte[m][1], punkte[m][2]) then weit = m else break end
    end
    glatt[#glatt + 1] = punkte[weit]
    ax, ay = punkte[weit][1], punkte[weit][2]
    n = weit + 1
  end
  return glatt
end
SN.wegSuchen = wegSuchen

-- Aufbau -------------------------------------------------------------------------------------------

function SN:Bauen(r)
  self.r = r
  rasterBauen()
  local grund = r:CreateTexture(nil, "BACKGROUND")
  grund:SetAllPoints()
  grund:SetTexture(KARTE.textur)
  grund:SetTexCoord(0, KARTE.b, 0, KARTE.h)
  local flamme = r:CreateTexture(nil, "ARTWORK")
  flamme:SetSize(26, 34)
  flamme:SetPoint("BOTTOM", r, "TOPLEFT", KARTE.feuer[1], -(KARTE.feuer[2] + 5))
  S.feuer(flamme)
  local basis = (r.GetFrameLevel and r:GetFrameLevel()) or 1
  self.basis = basis
  local function ebene(stufe)
    local e = CreateFrame("Frame", nil, r)
    e:SetAllPoints()
    e:SetFrameLevel(basis + stufe)
    return e
  end
  local kegel, dinge, oben = ebene(1), ebene(2), ebene(22)
  self.oben = oben

  -- Fische auf dem Boden
  self.fischBilder = {}
  for i = 1, FISCHE_DA + 1 do
    local t = dinge:CreateTexture(nil, "ARTWORK")
    t:SetSize(FISCH_BILD, FISCH_BILD)
    t:Hide()
    self.fischBilder[i] = t
  end

  -- Murloc, darüber die Fische in seiner Tasche
  local mf = CreateFrame("Frame", nil, r)
  mf:SetSize(MURLOC_BILD, MURLOC_BILD)
  mf.bild = mf:CreateTexture(nil, "ARTWORK")
  mf.bild:SetAllPoints()
  self.murlocBild = mf
  self.tascheBilder = {}
  for i = 1, TRAGEN do
    local t = oben:CreateTexture(nil, "OVERLAY")
    t:SetSize(18, 18)
    t:Hide()
    self.tascheBilder[i] = t
  end

  -- Wachen: Modell, Ersatzbild (Defias-Maske), Sichtkegel, "?" und "!" über dem Kopf
  self.wachen = {}
  for i, ro in ipairs(ROUTEN) do
    local w = { nr = i, route = ro }
    local ok, m = pcall(CreateFrame, "PlayerModel", nil, r)
    if ok and m and m.SetDisplayInfo then
      m:SetSize(WACHE * RAND, WACHE * RAND)
      if m.SetKeepModelOnHide then pcall(m.SetKeepModelOnHide, m, true) end
      m:SetScript("OnModelLoaded", kamera)
      m:Hide()
      w.m = m
    end
    w.ersatz = dinge:CreateTexture(nil, "OVERLAY")
    w.ersatz:SetSize(22, 22)
    w.ersatz:SetTexture("Interface\\Icons\\INV_Misc_Bandana_03")
    w.ersatz:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    w.ersatz:Hide()
    w.kegel = kegel:CreateTexture(nil, "ARTWORK")
    w.kegel:SetTexture(KARTE.kegel)
    w.kegel:Hide()
    w.marke = S.schrift(oben, "GameFontNormalHuge", F.hinweis)
    w.marke:Hide()
    self.wachen[i] = w
  end

  self.status = S.schrift(oben, "GameFontHighlightSmall", F.text)
  self.status:SetPoint("TOPLEFT", r, "TOPLEFT", 4, -3)
  self.hinweis = S.schrift(oben, "GameFontNormalLarge", F.hinweis)
  self.hinweis:SetPoint("CENTER", r, "CENTER", 0, -4)
  self.ziel = S.schrift(oben, "GameFontHighlight", F.text)
  self.ziel:SetPoint("TOP", self.hinweis, "BOTTOM", 0, -6)
  self.ziel:SetWidth(B - 40)

  -- Wer Fische trägt, sieht den Weg nach Hause: der Bach leuchtet sanft, am Ufer zeigt ein goldener
  -- Pfeil hinein (Patrick, 18. Okt: "noch nicht so ganz intuitiv")
  local bach = dinge:CreateTexture(nil, "BACKGROUND")
  bach:SetTexture(S.WEISS)
  bach:SetVertexColor(0.55, 0.85, 1)
  bach:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
  bach:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT", KARTE.bachX, 0)
  bach:Hide()
  self.bachLicht = bach
  local pfeil = oben:CreateTexture(nil, "OVERLAY")
  pfeil:SetSize(26, 26)
  pfeil:SetTexture(KARTE.pfeil)
  pfeil:SetVertexColor(1, 0.82, 0.3)
  pfeil:Hide()
  self.pfeil = pfeil
  self.pfeilText = S.schrift(oben, "GameFontNormalSmall", F.hinweis)
  self.pfeilText:SetPoint("LEFT", pfeil, "RIGHT", 2, 0)
  self.pfeilText:SetText(L.SNEAK_ARROW)
  self.pfeilText:Hide()

  -- Klickfläche über allem (unter Tafel und Zurufen von Spiele.lua)
  local klick = CreateFrame("Frame", nil, r)
  klick:SetAllPoints()
  klick:SetFrameLevel(basis + 23)
  klick:EnableMouse(true)
  klick:SetScript("OnMouseDown", function(_, knopf) SN:Klick(knopf) end)
  self.klick = klick
end

-- Modell einer Wache setzen. Lädt es nicht, kommt der nächste Defias aus der Liste, zuletzt das
-- Ersatzbild.
function SN:Modell(w, nr)
  w.displayNr, w.dreiD, w.anim = nr, false, nil
  w.ladeBis = self.t + 1.5
  if w.m then
    pcall(w.m.SetDisplayInfo, w.m, w.route.display[nr])
    kamera(w.m)
    licht(w.m)
    w.m:Show()
  end
end

-- Eine Wache kommt dazu (am Anfang ihrer Runde)
function SN:WacheDazu(w)
  local ro = ROUTEN[w.nr]
  w.route = ro
  w.aktiv = true
  w.x, w.y = ro.punkte[1][1], ro.punkte[1][2]
  w.idx, w.vor = math.min(2, #ro.punkte), 1
  w.zustand, w.meter, w.weg, w.pauseBis, w.verloren = "runde", 0, nil, 0, 0
  w.blickNr, w.blickZeit = 1, 0
  local naechst = ro.punkte[w.idx]
  w.blick = ro.steht and math.rad(ro.blicke[1]) or winkel(naechst[1] - w.x, naechst[2] - w.y)
  self:Modell(w, 1)
  w.kegel:Show()
  w.ersatz:Hide()
  self.aktive = (self.aktive or 0) + 1
end

function SN:Start()
  self.t, self.los, self.vorbei, self.endeBei = 0, false, nil, nil
  self.aktive, self.gebracht, self.tasche, self.gesehen = 0, 0, {}, false
  self.wachTempo = WACHE_TEMPO
  self.m = { x = KARTE.start[1], y = KARTE.start[2], richtung = 2, karton = false, laeuft = false }
  self.fische = {}
  for _, t in ipairs(self.fischBilder) do t:Hide() end
  for _, w in ipairs(self.wachen) do
    w.aktiv = false
    if w.m then w.m:Hide() end
    w.kegel:Hide()
    w.ersatz:Hide()
    w.marke:Hide()
  end
  for i = 1, START_WACHEN do self:WacheDazu(self.wachen[i]) end
  for _ = 1, FISCHE_DA do self:FischLegen() end
  self.hinweis:SetText(L.SNEAK_CLICK)
  self.hinweis:Show()
  self.ziel:SetText(L.SNEAK_GOAL)
  self.ziel:Show()
  self.ersterFisch = true
  self:Status()
  self:Zeichnen()
end

function SN:Stop()
  for _, w in ipairs(self.wachen) do w.marke:Hide() end
  self.hinweis:Hide()
  self.ziel:Hide()
  self.pfeil:Hide()
  self.pfeilText:Hide()
  self.bachLicht:Hide()
end

function SN:Status()
  self.status:SetText(string.format(L.SNEAK_STATUS, #self.tasche, TRAGEN, self.gebracht))
end

-- Zuruf über einem Punkt der Karte (y nach unten)
function SN:RufBei(text, x, y, farbe) SP:Ruf(text, x, -y, farbe) end

-- Fische -------------------------------------------------------------------------------------------

-- Neuer Fisch an einem freien Platz, nicht direkt neben dem Murloc oder einem anderen Fisch
function SN:FischLegen()
  local frei = {}
  for i, p in ipairs(KARTE.plaetze) do
    local ok = abstand(p[1], p[2], self.m.x, self.m.y) >= 60
    for _, f in ipairs(self.fische) do
      if f.platz == i or abstand(p[1], p[2], f.x, f.y) < 30 then ok = false end
    end
    if ok then frei[#frei + 1] = i end
  end
  if #frei == 0 then return end
  local i = frei[math.random(1, #frei)]
  local p = KARTE.plaetze[i]
  table.insert(self.fische, { x = p[1], y = p[2], platz = i, gold = math.random() < GOLD_CHANCE, seit = self.t })
end

function SN:Ziele()
  local m = self.m
  for i = #self.fische, 1, -1 do
    local f = self.fische[i]
    if abstand(m.x, m.y, f.x, f.y) <= SAMMELN then
      if #self.tasche < TRAGEN then
        table.remove(self.fische, i)
        table.insert(self.tasche, f.gold and GOLD or FISCH)
        self:RufBei(f.gold and L.SNEAK_GOLD or SP.spruch(L.SNEAK_FISH), m.x, m.y - MURLOC_BILD, F.erfolg)
        if self.ersterFisch then
          -- Beim ersten Fisch der Runde einmal deutlich sagen, wohin er gehört
          self.ersterFisch = false
          self:RufBei(L.SNEAK_TO_STREAM, B / 2, H / 2, F.hinweis)
        end
        ns.ton("plopp")
        ns.mrgl(0.3)
        self:FischLegen()
        self:Status()
      elseif self.t >= (self.vollBis or 0) then
        self.vollBis = self.t + 2.5
        self:RufBei(L.SNEAK_BAG_FULL, m.x, m.y - MURLOC_BILD, F.hinweis)
      end
    end
  end
  -- Im Bach: Fische abgeben. Mehr auf einmal zählt mehr, ganz ohne Alarm noch einmal die Hälfte dazu.
  if m.x < KARTE.bachX and #self.tasche > 0 then
    local summe = 0
    for _, wert in ipairs(self.tasche) do summe = summe + wert end
    local n = #self.tasche
    local punkte = summe * (1 + 0.5 * (n - 1))
    if not self.gesehen then
      punkte = punkte * 1.5
      self:RufBei(L.SNEAK_UNSEEN, m.x + 20, m.y - MURLOC_BILD - 14, F.stern)
    end
    punkte = math.floor(punkte + 0.5)
    SP:Plus(punkte)
    self:RufBei(string.format(L.SNEAK_BANKED, punkte), m.x + 20, m.y - MURLOC_BILD, F.erfolg)
    ns.ton("muenze")
    ns.mrgl()
    self.gebracht = self.gebracht + n
    self.tasche, self.gesehen = {}, false
    self.wachTempo = math.min(WACHE_MAX, WACHE_TEMPO + WACHE_PLUS * self.gebracht)
    -- Verstärkung: alle zwei Fische ein Defias mehr
    local soll = math.min(#self.wachen, START_WACHEN + math.floor(self.gebracht / NEUE_WACHE_JE))
    while self.aktive < soll do
      local w = self.wachen[self.aktive + 1]
      self:WacheDazu(w)
      self:RufBei(L.SNEAK_NEW_GUARD, w.x, w.y - WACHE - 6, F.fehler)
    end
    self:Status()
  end
end

-- Steuerung ----------------------------------------------------------------------------------------

function SN:Maus()
  if not GetCursorPosition then return nil end
  local x, y = GetCursorPosition()
  local r = self.r
  local s = (r.GetEffectiveScale and r:GetEffectiveScale()) or 1
  local links, oben = r:GetLeft(), r:GetTop()
  if not (x and links and oben and s and s > 0) then return nil end
  return x / s - links, oben - y / s
end

function SN:Klick(knopf)
  if not (SP.laeuft and SP.aktiv == self) or SP.pause or self.vorbei then return end
  if not self.los then
    self.los = true
    self.hinweis:Hide()
    self.ziel:Hide()
    return
  end
  if knopf == "RightButton" then self:Karton() end
end

function SN:Karton()
  local m = self.m
  m.karton = not m.karton
  ton("Karton")
  if m.karton then self:RufBei(L.SNEAK_BOX_ON, m.x, m.y - MURLOC_BILD, F.leise) end
end

-- Der Murloc läuft zur Maus (die Füße zum Mauszeiger), gleitet an Hindernissen entlang. Ist die
-- Maus nicht über der Karte, bleibt er stehen.
function SN:MurlocTick(dt)
  local m = self.m
  m.laeuft = false
  if not self.los then return end
  local x, y = self:Maus()
  if not x or x < 0 or x > B or y < 0 or y > H then return end
  local dx, dy = x - m.x, y - m.y
  local d = math.sqrt(dx * dx + dy * dy)
  if d < 1.5 then return end
  local s = math.min(d, (m.karton and TEMPO_KARTON or TEMPO) * dt)
  local nx, ny = schieben(m.x + dx / d * s, m.y + dy / d * s, R)
  local bx, by = nx - m.x, ny - m.y
  if bx * bx + by * by > 0.0025 then
    m.richtung = richtungsNr(bx, by)
    m.laeuft = true
  end
  m.x, m.y = nx, ny
end

-- Ablauf -------------------------------------------------------------------------------------------

function SN:Tick(dt)
  dt = math.min(dt, 0.1)
  self.t = self.t + dt
  if self.vorbei then
    if self.endeBei and self.t >= self.endeBei then
      self.endeBei = nil
      SP:Fertig(self.endText)
    end
    return self:Zeichnen()
  end
  self:MurlocTick(dt)
  for _, w in ipairs(self.wachen) do
    if w.aktiv then self:WacheTick(w, dt) end
  end
  if not self.vorbei then self:Ziele() end
  self:Zeichnen()
end

-- Sieht die Wache den Murloc? Gibt sichtbar und Abstand zurück. Im Bach sieht ihn niemand.
function SN:Sieht(w)
  local m = self.m
  if m.x < KARTE.bachX then return false end
  local d = abstand(w.x, w.y, m.x, m.y)
  if d > SICHT then return false end
  if d > 8 then
    local a = (winkel(m.x - w.x, m.y - w.y) - w.blick + math.pi) % (2 * math.pi) - math.pi
    if math.abs(a) > HALB then return false end
  end
  if not linieFrei(SICHT_FREI, w.x, w.y, m.x, m.y) then return false end
  return true, d
end

-- Laufen entlang w.weg, gibt true zurück, wenn der Weg zu Ende ist
function SN:Folgen(w, tempo, dt)
  local ziel = w.weg and w.weg[1]
  if not ziel then return true end
  local dx, dy = ziel[1] - w.x, ziel[2] - w.y
  local d = math.sqrt(dx * dx + dy * dy)
  local s = tempo * dt
  if d > 0.01 then w.blick = drehen(w.blick, winkel(dx, dy), dt * 8) end
  if d <= s then
    w.x, w.y = ziel[1], ziel[2]
    table.remove(w.weg, 1)
    return #w.weg == 0
  end
  w.x, w.y = w.x + dx / d * s, w.y + dy / d * s
  return false
end

function SN:Runde(w, dt)
  local ro = w.route
  if ro.steht then
    w.blickZeit = w.blickZeit + dt
    if w.blickZeit > 2.4 then
      w.blickZeit = 0
      w.blickNr = w.blickNr % #ro.blicke + 1
    end
    if w.meter < STUTZEN then w.blick = drehen(w.blick, math.rad(ro.blicke[w.blickNr]), dt * 2.2) end
    return anim(w, ANIM.stehen)
  end
  -- Stutzt die Wache ("?" halb voll) oder schaut sich am Ende ihres Wegs um, bleibt sie stehen
  if w.meter >= STUTZEN or self.t < w.pauseBis then return anim(w, ANIM.stehen) end
  local ziel = ro.punkte[w.idx]
  w.weg = { { ziel[1], ziel[2] } }
  if self:Folgen(w, self.wachTempo, dt) then
    if ro.schleife then
      w.idx = w.idx % #ro.punkte + 1
    else
      w.idx = w.idx + w.vor
      if w.idx > #ro.punkte then w.idx, w.vor = #ro.punkte - 1, -1 end
      if w.idx < 1 then w.idx, w.vor = 2, 1 end
      if w.idx == #ro.punkte - 1 or w.idx == 2 then w.pauseBis = self.t + 0.8 end
    end
  end
  anim(w, ANIM.gehen)
end

-- Sehen: das "?" füllt sich (näher: schneller), die Wache dreht sich hin. Voll: Alarm.
function SN:Wahrnehmen(w, dt)
  local sieht, d = self:Sieht(w)
  local m = self.m
  local tempo = 0
  if sieht then
    if m.karton and not m.laeuft then
      if d <= NAH_KARTON then tempo = 4 end
    else
      tempo = (1 + 2 * (1 - d / SICHT)) / MELDEN
      if m.karton then tempo = tempo * 0.4 end
    end
  end
  if tempo > 0 then
    if w.meter == 0 then ns.ton("plopp") end
    w.meter = math.min(1, w.meter + tempo * dt)
    w.blick = drehen(w.blick, winkel(m.x - w.x, m.y - w.y), dt * 2.5 * w.meter)
    if w.meter >= 1 then
      if m.karton and not m.laeuft then self:RufBei(L.SNEAK_BOX_FOUND, w.x, w.y - WACHE - 22, F.fehler) end
      self:Alarm(w)
    end
  else
    w.meter = math.max(0, w.meter - VERGESSEN * dt)
  end
end

-- Eine Wache schlägt Alarm. Wachen in Hörweite rennen mit.
function SN:Alarm(w)
  local m = self.m
  local erster = true
  for _, v in ipairs(self.wachen) do
    if v.aktiv and v.zustand == "jagd" then erster = false end
  end
  self.gesehen = true
  if erster then
    ton("Entdeckt")
    ns.mrgl()
    ns.Musik:Spielen("alarm")
    self:RufBei(SP.spruch(L.SNEAK_SPOTTED), w.x, w.y - WACHE - 22, F.fehler)
  end
  for _, v in ipairs(self.wachen) do
    if v.aktiv and v.zustand ~= "jagd" and (v == w or abstand(v.x, v.y, w.x, w.y) <= HOEREN) then
      v.zustand, v.weg, v.planBei, v.meter, v.verloren = "jagd", nil, 0, 1, 0
      v.zuletzt = { m.x, m.y }
      v.alarmAnimBis = self.t + 0.6
      v.anim = nil
      anim(v, ANIM.alarm)
    end
  end
end

function SN:Jagd(w, dt)
  local m = self.m
  local sieht = self:Sieht(w)
  if sieht then
    w.zuletzt, w.verloren = { m.x, m.y }, 0
  else
    w.verloren = w.verloren + dt
  end
  if m.x < KARTE.bachX then w.verloren = AUFGEBEN end
  if w.verloren >= AUFGEBEN then return self:Aufgeben(w) end
  if not w.weg or self.t >= (w.planBei or 0) then
    local z = w.zuletzt
    w.weg = wegSuchen(WACHE_GEHEN, w.x, w.y, math.max(z[1], KARTE.bachX + 6), z[2]) or {}
    w.planBei = self.t + 0.4
  end
  local angekommen = self:Folgen(w, JAGD_TEMPO, dt)
  if angekommen then
    w.blick = w.blick + dt * 2.5          -- am letzten bekannten Ort: umschauen
    anim(w, ANIM.stehen)
  elseif self.t >= (w.alarmAnimBis or 0) then
    anim(w, ANIM.rennen)
  end
  if m.x >= KARTE.bachX and abstand(w.x, w.y, m.x, m.y) <= FANG then self:Gefangen(w) end
end

-- Murloc verloren: zurück zur Runde. Jagt keiner mehr, ist der Alarm vorbei.
function SN:Aufgeben(w)
  w.zustand, w.meter = "zurueck", 0.2
  local ro = w.route
  local beste, bd = 1, math.huge
  for i, p in ipairs(ro.punkte) do
    local d = abstand(w.x, w.y, p[1], p[2])
    if d < bd then beste, bd = i, d end
  end
  w.idx = beste
  local p = ro.punkte[beste]
  w.weg = wegSuchen(WACHE_GEHEN, w.x, w.y, p[1], p[2]) or { { p[1], p[2] } }
  self:RufBei(SP.spruch(L.SNEAK_GIVE_UP), w.x, w.y - WACHE - 6, F.leise)
  for _, v in ipairs(self.wachen) do
    if v.aktiv and v.zustand == "jagd" then return end
  end
  ns.Musik:Spielen("schleichen")
  self:RufBei(L.SNEAK_ESCAPED, self.m.x, self.m.y - MURLOC_BILD, F.erfolg)
end

function SN:Gefangen(w)
  self.vorbei, self.endeBei = "gefasst", self.t + 1.4
  local verloren = #self.tasche
  self.endText = verloren > 0 and string.format(L.SNEAK_CAUGHT_BAG, self.gebracht, verloren)
    or string.format(L.SNEAK_CAUGHT, self.gebracht)
  w.anim = nil
  anim(w, ANIM.fangen)
  ton("Gefasst")
  ns.mrgl()
  self:RufBei(SP.spruch(L.SNEAK_GOTCHA), w.x, w.y - WACHE - 10, F.fehler)
end

function SN:WacheTick(w, dt)
  -- Modell nachladen: lädt es nicht, der nächste Defias, zuletzt das Ersatzbild
  if not w.dreiD and w.ladeBis and self.t >= w.ladeBis then
    if geladen(w.m) then
      w.dreiD, w.ladeBis = true, nil
      local liste = w.anim
      w.anim = nil
      anim(w, liste or ANIM.stehen)
    elseif w.displayNr < #w.route.display then
      self:Modell(w, w.displayNr + 1)
    else
      w.ladeBis = nil
      if w.m then w.m:Hide() end
      w.ersatz:Show()
    end
  end
  if w.zustand == "runde" then
    self:Runde(w, dt)
    self:Wahrnehmen(w, dt)
  elseif w.zustand == "zurueck" then
    if w.meter >= STUTZEN then
      anim(w, ANIM.stehen)
    else
      anim(w, ANIM.gehen)
      if self:Folgen(w, self.wachTempo, dt) then w.zustand = "runde" end
    end
    self:Wahrnehmen(w, dt)
  elseif w.zustand == "jagd" then
    self:Jagd(w, dt)
  end
end

-- Zeichnen -----------------------------------------------------------------------------------------

local KEGEL_FARBE = { ruhig = { 1, 0.9, 0.5, 0.6 }, jagd = { 1, 0.22, 0.18, 0.85 } }

-- Mit Fischen in der Tasche: Bach leuchtet, Pfeil am Ufer auf der Höhe des Murlocs, wippt leicht
function SN:WegNachHause()
  local m = self.m
  local zeigen = #self.tasche > 0 and not self.vorbei
  self.bachLicht:SetShown(zeigen)
  if zeigen then self.bachLicht:SetAlpha(0.06 + 0.1 * (0.5 + 0.5 * math.sin(self.t * 4))) end
  local pfeil = zeigen and m.x > KARTE.bachX + 26
  self.pfeil:SetShown(pfeil)
  self.pfeilText:SetShown(pfeil)
  if pfeil then
    local y = math.max(24, math.min(H - 16, m.y - 18))
    self.pfeil:ClearAllPoints()
    self.pfeil:SetPoint("CENTER", self.r, "TOPLEFT", KARTE.bachX + 16 + 3 * math.sin(self.t * 6), -y)
  end
end

function SN:Zeichnen()
  local m, r = self.m, self.r
  self:WegNachHause()
  local mf = self.murlocBild
  mf:ClearAllPoints()
  mf:SetPoint("BOTTOM", r, "TOPLEFT", m.x, -(m.y + KARTE.murlocFuss * MURLOC_BILD))
  local name
  if m.karton then
    name = (m.laeuft and math.floor(self.t * 6) % 2 == 1) and "karton1" or "karton0"
  else
    name = "m" .. m.richtung .. "_" .. (m.laeuft and math.floor(self.t * 9) % 4 or 0)
  end
  teil(mf.bild, name)
  mf.name = name
  mf:SetAlpha(m.x < KARTE.bachX and 0.8 or 1)
  mf:SetFrameLevel(self.basis + 3 + math.floor(m.y / 12))
  -- Fische in der Tasche über dem Kopf
  for i, t in ipairs(self.tascheBilder) do
    local wert = self.tasche[i]
    if wert and not m.karton then
      teil(t, wert == GOLD and "goldfisch" or "fisch")
      t:ClearAllPoints()
      t:SetPoint("BOTTOM", r, "TOPLEFT", m.x + (i - (#self.tasche + 1) / 2) * 13, -(m.y - MURLOC_BILD * 0.82))
      t:Show()
    else
      t:Hide()
    end
  end
  -- Fische auf dem Boden, leicht pulsierend, Goldfische stärker
  for i, t in ipairs(self.fischBilder) do
    local f = self.fische[i]
    if f then
      teil(t, f.gold and "goldfisch" or "fisch")
      local puls = math.sin((self.t - f.seit) * (f.gold and 7 or 4))
      local g = FISCH_BILD * (1 + (f.gold and 0.1 or 0.05) * puls)
      t:SetSize(g, g)
      t:ClearAllPoints()
      t:SetPoint("BOTTOM", r, "TOPLEFT", f.x, -(f.y + TEIL_FUSS * g))
      t:SetAlpha(math.min(1, (self.t - f.seit) * 3))
      t:Show()
    else
      t:Hide()
    end
  end
  for _, w in ipairs(self.wachen) do
    if w.aktiv then
      if w.m then
        w.m:ClearAllPoints()
        w.m:SetPoint("CENTER", r, "TOPLEFT", w.x, -(w.y - WACHE / 2))
        w.m:SetFrameLevel(self.basis + 3 + math.floor(w.y / 12))
        -- Blickrichtung des Modells: 0 schaut zum Betrachter, +pi/2 nach rechts
        if w.m.SetFacing then pcall(w.m.SetFacing, w.m, atan2(math.cos(w.blick), math.sin(w.blick))) end
      end
      w.ersatz:ClearAllPoints()
      w.ersatz:SetPoint("BOTTOM", r, "TOPLEFT", w.x, -w.y)
      local k = w.kegel
      k:SetSize(SICHT * 2, SICHT * 2)
      k:ClearAllPoints()
      k:SetPoint("CENTER", r, "TOPLEFT", w.x, -w.y)
      -- Die Karte zählt y nach unten, das Spiel dreht gegen den Uhrzeigersinn: daher das Minus
      if k.SetRotation then k:SetRotation(-w.blick) end
      local jagd = w.zustand == "jagd"
      local c = jagd and KEGEL_FARBE.jagd or KEGEL_FARBE.ruhig
      if not jagd and w.meter > 0 then
        -- je voller das "?", desto röter der Kegel
        c = { 1, 0.9 - 0.6 * w.meter, 0.5 - 0.35 * w.meter, 0.6 + 0.25 * w.meter }
      end
      k:SetVertexColor(c[1], c[2], c[3], c[4])
      -- "?" füllt sich, "!" bei der Jagd
      local mk = w.marke
      if jagd then
        mk:SetText("!")
        mk:SetTextColor(1, 0.25, 0.2)
        mk:SetAlpha(1)
        mk:Show()
      elseif w.meter > 0.02 then
        mk:SetText("?")
        mk:SetTextColor(1, 0.95 - 0.5 * w.meter, 0.3 - 0.2 * w.meter)
        mk:SetAlpha(0.35 + 0.65 * w.meter)
        mk:Show()
      else
        mk:Hide()
      end
      mk:ClearAllPoints()
      mk:SetPoint("BOTTOM", r, "TOPLEFT", w.x, -(w.y - WACHE - 2))
    else
      w.marke:Hide()
    end
  end
end

SP.Registrieren(SN)
