-- Marshmallow rösten: Nahaufnahme am Lagerfeuer. Der Marshmallow steckt auf einem grünen Gabelast,
-- der von rechts unten ins Bild ragt. Die Maus bestimmt die Höhe: tief in den Flammen bräunt er
-- schnell, kann aber Feuer fangen, oben über den Flammenspitzen geht es langsam. Die Seite zum
-- Feuer bräunt, die obere kaum, ein Klick dreht ihn um. Brennt er, schnell pusten (klicken) oder
-- hochziehen, sonst fällt er verkohlt ins Feuer. Eat (oder Rechtsklick) isst ihn: beide Seiten
-- golden gibt die meisten Punkte, dann steckt ein neuer auf dem Ast. 45 Sekunden, so viele wie
-- möglich. Ab und zu lodert das Feuer auf.
--
-- Bilder aus Blender (grafik/blender/roesten.py, Lagen in Roesten.lua): Feuerstelle mit
-- eingebackenem Feuerschein, Flammen als Schleife aus derselben Kamera (zwei Lagen blenden weich
-- ineinander), Stock, Marshmallow in fünf Röststufen. Je Seite zwei Lagen (Stufe und nächste
-- Stufe überblendet), die untere Hälfte ist weich freigestellt: so sieht man beide Seiten zugleich.
-- Funken (Atlas "funke"), Rauch und kleine Flammen sind wiederverwendete Texturen. Alles wird an
-- den Rändern der Spielfläche beschnitten (auch die Texturkoordinaten), nichts ragt hinaus. Kein
-- SetRotation: das überschreibt die Texturkoordinaten.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba
local SP = ns.Spiel

local BREITE, HOEHE = SP.BREITE, SP.HOEHE
local VOLL = { 0, 1, 0, 1 }
local ORT = S.ROESTEN_ORT or { x = 0.47, bett = 0.71, krone = 0.5, spitze = 0.31, oben = 0.2 }
local FLAMMEN = S.ROESTEN_FLAMMEN or { x = 0.25, y = 0.11, b = 0.43, h = 0.67 }
local STOCK = S.ROESTEN_STOCK or { coords = VOLL, b = 180, h = 112, x = 8, y = 8 }
local ZELLE = S.ROESTEN_ZELLE or 64
local function teil(name) return (S.ROESTEN_TEIL and S.ROESTEN_TEIL[name]) or VOLL end

-- Lage und Hitze
local FEUER_X = ORT.x * BREITE
local SPITZE_X = FEUER_X + 2              -- Stockspitze (Mitte des Marshmallows), waagerecht
local HOCH = 24                           -- höchste Lage der Spitze: kühl, über den Flammen
local TIEF = ORT.krone * HOEHE - 8        -- tiefste Lage: mitten in den Flammen über den Scheiten
local TEMPO = 0.3                         -- Bräune je Sekunde bei voller Hitze (Seite zum Feuer)
local OBEN_ANTEIL = 0.1                   -- so viel davon bekommt die obere Seite ab
local DREHEN = 0.26                       -- Sekunden für das Umdrehen
-- Wertung einer Seite: 0 roh, 0,5 golden, 1 verkohlt
local GOLD, GOLD_BREIT, PERFEKT = 0.5, 0.1, 0.04
local ROH, SCHWARZ = 0.2, 0.85

-- Bildschleife der Flammen: 8 Bilder auf 4 x 2 Feldern
local BILDER, TAKT = 8, 0.085
local FEUER_K = {}
for n = 0, BILDER - 1 do
  local sp, ze = n % 4, math.floor(n / 4)
  FEUER_K[n + 1] = { sp / 4, (sp + 1) / 4, ze / 2, (ze + 1) / 2 }
end
-- Texturkoordinaten der Röststufen und kleinen Flammen, einmal nachgeschlagen
local K = { ganz = {}, unten = {}, biss = {}, bissUnten = {}, zunge = {} }
for i = 0, 4 do
  K.ganz[i], K.unten[i] = teil("ganz" .. i), teil("unten" .. i)
  K.biss[i], K.bissUnten[i] = teil("biss" .. i), teil("bissUnten" .. i)
end
for i = 1, 8 do K.zunge[i] = teil("zunge" .. i) end
-- Farben der Stufen für die Seitenanzeige (roh, hell, golden, dunkel, verkohlt)
local FARBEN = { { 0.95, 0.93, 0.88 }, { 0.93, 0.78, 0.55 }, { 0.84, 0.54, 0.2 }, { 0.42, 0.2, 0.07 }, { 0.1, 0.07, 0.06 } }
-- Flammen auf dem brennenden Marshmallow: Fuß relativ zur Mitte
local BRAND_ORT = { { -9, -6 }, { 0, -10 }, { 9, -5 } }

-- Bild der Legende: nur der Marshmallow, ohne den leeren Rand der Zelle
local function innen(k)
  local rb, rh = (k[2] - k[1]) * 0.18, (k[4] - k[3]) * 0.18
  return { k[1] + rb, k[2] - rb, k[3] + rh, k[4] - rh }
end

local M = { key = "marshmallow", musik = "teich", name = L.GAME_MARSHMALLOW, info = L.GAME_MARSHMALLOW_INFO,
  icon = "Interface\\Icons\\INV_Misc_Food_124_Skewer", dauer = 45,
  legende = {
    { bild = S.ROESTEN_TEILE, coords = innen(teil("ganz2")), punkte = 10 },
    { bild = S.ROESTEN_TEILE, coords = innen(teil("schief")), punkte = 4 },
    { bild = S.ROESTEN_TEILE, coords = innen(teil("ganz3")), punkte = 2 },
    { bild = S.ROESTEN_TEILE, coords = innen(teil("ganz0")), punkte = 1 },
    { bild = S.ROESTEN_TEILE, coords = innen(teil("ganz4")), punkte = 0 },
  } }

local function grenzen(v, a, b) return math.max(a, math.min(b, v)) end

-- Wertung beider Seiten: Punkte, Sprüche und Farbe des Zurufs
local function art(s)
  if s >= SCHWARZ then return "schwarz" end
  if math.abs(s - GOLD) <= GOLD_BREIT then return "gold" end
  if s < ROH then return "roh" end
  return "braun"
end
function M.Wertung(a, b)
  local ka, kb = art(a), art(b)
  if ka == "schwarz" or kb == "schwarz" then return 0, L.MARSH_BURNT_LINES, F.fehler end
  if ka == "gold" and kb == "gold" then
    if math.abs(a - GOLD) <= PERFEKT and math.abs(b - GOLD) <= PERFEKT then return 12, L.MARSH_PERFECT_LINES, F.stern end
    return 10, L.MARSH_GOLDEN_LINES, F.erfolg
  end
  if ka == "gold" or kb == "gold" then return 4, L.MARSH_UNEVEN_LINES, F.hinweis end
  if ka == "roh" and kb == "roh" then return 1, L.MARSH_RAW_LINES, F.leise end
  return 2, L.MARSH_TOASTED_LINES, F.hinweis
end

-- Röststufe als Bildnummer 0 bis 3 und Anteil der nächsten Stufe
local function stufe(s)
  local x = grenzen(s, 0, 1) * 4
  local i = math.min(3, math.floor(x))
  return i, x - i
end

local function neueTextur(r, ebene, unter, datei, k, mischen)
  local t = r:CreateTexture(nil, ebene, nil, unter)
  t:SetTexture(datei)
  t.k = k or VOLL
  if mischen and t.SetBlendMode then t:SetBlendMode(mischen) end
  t:Hide()
  return t
end

-- Textur mit Mitte cx, cy (von oben links) und Größe b x h zeigen, an den Rändern der Spielfläche
-- beschnitten. k = { links, rechts, oben, unten } sind die Texturkoordinaten des ganzen Bildes.
function M:Zeigen(t, cx, cy, b, h, k)
  local x0, y0 = cx - b / 2, cy - h / 2
  local l, o = math.max(0, x0), math.max(0, y0)
  local rr, u = math.min(BREITE, x0 + b), math.min(HOEHE, y0 + h)
  if b <= 0 or h <= 0 or rr - l < 0.5 or u - o < 0.5 then
    t:Hide()
    return
  end
  local kb, kh = k[2] - k[1], k[4] - k[3]
  t:SetTexCoord(k[1] + (l - x0) / b * kb, k[1] + (rr - x0) / b * kb, k[3] + (o - y0) / h * kh, k[3] + (u - y0) / h * kh)
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", self.r, "TOPLEFT", l, -o)
  t:SetSize(rr - l, u - o)
  t:Show()
end

-- Aufbau ---------------------------------------------------------------------------------------

function M:Bauen(r)
  self.r = r
  local basis = (r.GetFrameLevel and r:GetFrameLevel()) or 1
  local szene = r:CreateTexture(nil, "BACKGROUND", nil, 2)
  szene:SetAllPoints()
  szene:SetTexture(S.ROESTEN)
  local k = S.ROESTEN_SZENE or VOLL
  szene:SetTexCoord(k[1], k[2], k[3], k[4])
  -- Flammen: zwei Lagen, die nächste blendet ein (weich bei jeder Bildrate)
  self.flamme1 = neueTextur(r, "BORDER", 1, S.ROESTEN_FEUER)
  self.flamme2 = neueTextur(r, "BORDER", 2, S.ROESTEN_FEUER)
  for _, t in ipairs({ self.flamme1, self.flamme2 }) do
    self:Zeigen(t, (FLAMMEN.x + FLAMMEN.b / 2) * BREITE, (FLAMMEN.y + FLAMMEN.h / 2) * HOEHE, FLAMMEN.b * BREITE, FLAMMEN.h * HOEHE, VOLL)
  end
  -- Feuerschein über Glut und Boden, flackert (weicher Verlauf aus dem Atlas, bleibt in der Fläche)
  self.schein = S.glut(r, 150, 64, { 1, 0.5, 0.15, 1 }, "ARTWORK")
  self.schein:SetPoint("CENTER", r, "TOPLEFT", FEUER_X, -(ORT.bett * HOEHE - 12))
  -- Lodern: Flammenzungen schießen aus dem Feuer
  self.lohen = {}
  for i = 1, 3 do self.lohen[i] = neueTextur(r, "BORDER", 3, S.ROESTEN_TEILE) end
  -- Stock, darüber der Marshmallow: oben ganz (Stufe, nächste Stufe), unten die freigestellte Hälfte
  self.stock = neueTextur(r, "ARTWORK", 2, S.ROESTEN, STOCK.coords)
  self.lagen = {}
  for i = 1, 4 do self.lagen[i] = neueTextur(r, "ARTWORK", 3 + i, S.ROESTEN_TEILE) end
  self.brandZungen = {}
  for i = 1, 3 do self.brandZungen[i] = neueTextur(r, "OVERLAY", i, S.ROESTEN_TEILE) end
  self.rauch = {}
  for i = 1, 12 do self.rauch[i] = neueTextur(r, "OVERLAY", 4, S.ROESTEN_TEILE, teil(i % 2 == 0 and "rauch2" or "rauch1")) end
  self.funken = {}
  local fk = S.ATLAS and S.ATLAS.funke
  for i = 1, 18 do
    local t = neueTextur(r, "OVERLAY", 6, fk and S.SPIELE or S.KREIS, fk, "ADD")
    t:SetVertexColor(1, 0.62, 0.25)
    self.funken[i] = t
  end

  -- Klickfläche: Klick dreht (oder pustet), Rechtsklick isst
  local knopf = CreateFrame("Button", nil, r)
  knopf:SetAllPoints()
  knopf:SetFrameLevel(basis + 4)
  knopf:SetScript("OnMouseDown", function(_, taste)
    if taste == "RightButton" then M:Essen() else M:Klick() end
  end)
  self.knopf = knopf

  -- Bedienung über allem: Seitenanzeige oben links, Eat oben rechts (oben ist der Marshmallow
  -- kühl, der Weg zum Knopf zieht ihn also aus dem Feuer), Hinweis unten
  local ui = CreateFrame("Frame", nil, r)
  ui:SetAllPoints()
  ui:SetFrameLevel(basis + 6)
  local essen = S.textKnopf(ui, L.MARSH_EAT, 62, function() M:Essen() end)
  essen:SetPoint("TOPRIGHT", -6, -6)
  S.tooltip(essen, L.MARSH_EAT, L.MARSH_EAT_TIP)
  self.essenKnopf = essen

  local anzeige = CreateFrame("Frame", nil, ui)
  anzeige:SetSize(86, 24)
  anzeige:SetPoint("TOPLEFT", 6, -6)
  anzeige:EnableMouse(true)
  S.tooltip(anzeige, L.MARSH_SIDES_TITLE, L.MARSH_SIDES)
  self.balken = {}
  for i = 1, 2 do
    local b = CreateFrame("Frame", nil, anzeige)
    b:SetSize(68, 6)
    b:SetPoint("TOPLEFT", 16, -4 - (i - 1) * 11)
    local grund = b:CreateTexture(nil, "BACKGROUND")
    grund:SetAllPoints()
    grund:SetColorTexture(0, 0, 0, 0.6)
    local zone = b:CreateTexture(nil, "BORDER")
    zone:SetPoint("TOPLEFT", 68 * (GOLD - GOLD_BREIT), 0)
    zone:SetSize(68 * 2 * GOLD_BREIT, 6)
    zone:SetColorTexture(1, 0.84, 0.3, 0.3)
    b.voll = b:CreateTexture(nil, "ARTWORK")
    b.voll:SetPoint("TOPLEFT", 0, 0)
    b.voll:SetHeight(6)
    b.voll:SetColorTexture(1, 1, 1, 1)
    b.flamme = b:CreateTexture(nil, "OVERLAY")
    b.flamme:SetSize(11, 11)
    b.flamme:SetPoint("RIGHT", b, "LEFT", -3, 1)
    b.flamme:SetTexture(S.ROESTEN_TEILE)
    local z = K.zunge[1]
    b.flamme:SetTexCoord(z[1], z[2], z[3], z[4])
    self.balken[i] = b
  end
  self.text = S.schrift(ui, "GameFontHighlight", F.text)
  self.text:SetPoint("BOTTOM", 0, 8)
end

-- Ablauf ---------------------------------------------------------------------------------------

function M:Start()
  local jetzt = ns.jetzt()
  self.anzahl, self.uhr, self.bildZeit, self.bildNr = 0, 0, 0, nil
  self.y, self.v, self.ziel = HOCH + 20, 0, HOCH + 20
  self.lodernAb, self.lodernBis = jetzt + SP.zufall(5, 9), nil
  self.funkenTakt, self.rauchTakt = 0, 0
  for _, t in ipairs(self.rauch) do t.aktiv = nil t:Hide() end
  for _, t in ipairs(self.funken) do t.aktiv = nil t:Hide() end
  for _, t in ipairs(self.lohen) do t:Hide() end
  self:Neu(true)
  self:Zeichnen(jetzt, 0)
end

-- Neuer Marshmallow auf dem Ast. sofort: ohne Aufstecken (Spielbeginn)
function M:Neu(sofort)
  self.seiten, self.unten = { 0, 0 }, 1
  self.brand, self.drehen, self.gedreht, self.biss = nil, nil, nil, 0
  self.waerme, self.tempo = 0, SP.zufall(0.85, 1.15)
  self.phase, self.phaseSeit = sofort and "roesten" or "neu", ns.jetzt()
  self.fallY, self.fallV = nil, nil
  self.hinweis, self.meldungBis = nil, nil
  self:Hinweis()
end

-- Höhe des Stocks: 0 ganz oben (kühl), 1 tief in den Flammen
function M:Hoehe(anteil) self.ziel = HOCH + grenzen(anteil, 0, 1) * (TIEF - HOCH) end

-- Maus über der Spielfläche: die Spitze folgt der Mauszeile
function M:Maus()
  local k = self.knopf
  if not (k and k.IsMouseOver and k:IsMouseOver()) then return end
  local oben = self.r.GetTop and self.r:GetTop()
  local skala = self.r.GetEffectiveScale and self.r:GetEffectiveScale()
  if type(oben) ~= "number" or type(skala) ~= "number" or skala <= 0 then return end
  local _, cy = GetCursorPosition()
  if type(cy) ~= "number" then return end
  self:Hoehe((oben - cy / skala - HOCH) / (TIEF - HOCH))
end

-- Klick: brennt er, pusten, sonst umdrehen
function M:Klick()
  if not (SP.laeuft and SP.aktiv == self) or self.phase ~= "roesten" then return end
  if self.brand then
    self.brand = self.brand - 0.25
    for _ = 1, 2 do self:Rauch(self.mx, self.my - 6, "puste") end
    ns.ton("plopp")
    if self.brand <= 0 then self:Geloescht() end
    return
  end
  if self.drehen then return end
  self.drehen, self.gedreht = 0, nil
  ns.ton("karte")
end

function M:Entzuenden()
  self.brand, self.drehen, self.gedreht = 0.35, nil, nil
  SP:Ruf(L.MARSH_FIRE_CALL, self.mx, -(self.my - 26), F.fehler)
  ns.ton("boom")
  self:Hinweis()
end

function M:Geloescht()
  self.brand = nil
  SP:Ruf(SP.spruch(L.MARSH_PHEW), self.mx, -(self.my - 26), F.erfolg)
  for _ = 1, 3 do self:Rauch(self.mx, self.my - 8, "brand") end
  ns.ton("treffer")
  self:Hinweis()
end

-- Verkohlt: fällt vom Ast ins Feuer, keine Punkte
function M:Fallen()
  self.brand, self.drehen = nil, nil
  self.seiten[1], self.seiten[2] = 1, 1
  self.phase, self.phaseSeit = "fallen", ns.jetzt()
  self.fallY, self.fallV = self.my, -30
  SP:Ruf(SP.spruch(L.MARSH_DROP), FEUER_X, -(ORT.krone * HOEHE - 30), F.fehler)
  ns.ton("minus")
  self.anzahl = self.anzahl + 1
end

-- Essen: Wertung beider Seiten, dann zwei Bisse und ein neuer Marshmallow
function M:Essen()
  if not (SP.laeuft and SP.aktiv == self) or self.phase ~= "roesten" or self.brand then return end
  local punkte, liste, farbe = M.Wertung(self.seiten[1], self.seiten[2])
  SP:Plus(punkte)
  self.punkteZuletzt = punkte
  self.anzahl = self.anzahl + 1
  self.phase, self.phaseSeit, self.drehen = "essen", ns.jetzt(), nil
  self.essenZiel = math.max(HOCH + 2, self.y - 12)
  SP:Ruf("+" .. punkte, self.mx, -(self.my - 30), farbe)
  self.text:SetText(SP.spruch(liste))
  self.text:SetTextColor(rgba(farbe))
  self.hinweis, self.meldungBis = "meldung", ns.jetzt() + 1.6
  ns.ton(punkte >= 10 and "muenze" or (punkte == 0 and "minus" or "treffer"))
end

-- Hinweis unten, nur bei Änderung neu gesetzt
function M:Hinweis()
  if self.meldungBis and ns.jetzt() < self.meldungBis then return end
  local u, o = self.seiten[self.unten], self.seiten[3 - self.unten]
  local neu, farbe = "start", F.text
  if self.brand then
    neu, farbe = "feuer", F.fehler
  elseif art(u) == "gold" and art(o) == "gold" then
    neu, farbe = "fertig", F.erfolg
  elseif art(u) == "gold" and o < GOLD - GOLD_BREIT then
    neu, farbe = "drehen", F.hinweis
  end
  if neu == self.hinweis then return end
  self.hinweis = neu
  self.text:SetText(neu == "feuer" and L.MARSH_FIRE or neu == "fertig" and L.MARSH_READY
    or neu == "drehen" and L.MARSH_TURN or L.MARSH_HINT)
  self.text:SetTextColor(rgba(farbe))
end

function M:Roesten(dt)
  local t, s = self.anteil, self.seiten
  local lodern = self.lodernBis ~= nil and t > 0.25
  local hitze = 0.08 + t ^ 1.5 * (lodern and 1.5 or 1)
  local u, o = self.unten, 3 - self.unten
  if self.drehen then
    self.drehen = self.drehen + dt / DREHEN
    if self.drehen >= 0.5 and not self.gedreht then
      self.unten, self.gedreht = o, true
      u, o = o, u
    end
    if self.drehen >= 1 then self.drehen, self.gedreht = nil, nil end
  end
  if self.brand then
    -- brennt: beide Seiten verkohlen, oben über den Flammen geht er von selbst aus
    s[u] = math.min(1, s[u] + dt * 0.4)
    s[o] = math.min(1, s[o] + dt * 0.22)
    if t < 0.3 then
      self.brand = self.brand - dt * 0.8
    else
      self.brand = self.brand + dt * (0.22 + 0.45 * t)
    end
    if self.brand <= 0 then
      self:Geloescht()
    elseif self.brand >= 1 then
      self:Fallen()
    end
  else
    local rate = TEMPO * hitze * self.tempo
    s[u] = math.min(1, s[u] + dt * rate)
    s[o] = math.min(1, s[o] + dt * rate * OBEN_ANTEIL)
    -- Feuer fangen: tief in den Flammen, beim Lodern und wenn die Seite schon dunkel ist
    local risiko = math.max(0, t - 0.62) * 1.7 + (lodern and 0.45 or 0)
    if s[u] > 0.8 then risiko = risiko + (s[u] - 0.8) * 3 * t end
    if risiko > 0 and math.random() < risiko * dt then self:Entzuenden() end
  end
  -- warm geht er langsam auf, kühl fällt er etwas zusammen
  local ziel = math.min(1, hitze * 0.8 + (s[1] + s[2]) * 0.4)
  self.waerme = self.waerme + (ziel - self.waerme) * math.min(1, dt * 1.2)
  -- Rauch: dünner Faden, wenn die Seite unten dunkel wird, dicht, wenn er brennt
  local rate = 0
  if self.brand then
    rate = 8
  elseif s[u] > 0.6 and t > 0.3 then
    rate = 1 + (s[u] - 0.6) * 10
  elseif t > 0.75 then
    rate = 0.8
  end
  self.rauchTakt = self.rauchTakt + dt * rate
  while self.rauchTakt >= 1 do
    self.rauchTakt = self.rauchTakt - 1
    self:Rauch(self.mx + SP.zufall(-6, 6), self.my - 10, self.brand and "brand" or "faden")
  end
  self:Hinweis()
end

function M:Tick(dt, jetzt)
  dt = math.min(dt, 0.05)
  self.uhr = self.uhr + dt
  self:Maus()
  -- Feder: der Ast folgt der Maus mit etwas Nachschwingen. Beim Essen ein Stück hoch zum Mund.
  local ziel = self.phase == "essen" and self.essenZiel or self.ziel
  local a = (ziel - self.y) * 70 - self.v * 13
  self.v = self.v + a * dt
  self.y = self.y + self.v * dt
  self.anteil = grenzen((self.y - HOCH) / (TIEF - HOCH), 0, 1)
  -- Lodern: kurz höhere Flammen, mehr Hitze und Funken
  if not self.lodernBis and jetzt >= self.lodernAb then
    self.lodernBis, self.lodernSeit = jetzt + 0.9, jetzt
    SP:Ruf(L.MARSH_FLARE, FEUER_X, -(ORT.spitze * HOEHE + 10), { 1, 0.55, 0.15, 1 })
    ns.ton("boom")
  elseif self.lodernBis and jetzt >= self.lodernBis then
    self.lodernBis, self.lodernAb = nil, jetzt + SP.zufall(6, 11)
  end
  local seit = jetzt - (self.phaseSeit or jetzt)
  if self.phase == "roesten" then
    self:Roesten(dt)
  elseif self.phase == "essen" then
    if seit >= 0.22 and self.biss == 0 then
      self.biss = 1
      SP:Ruf(SP.spruch(L.MARSH_NOM), self.mx - 22, -(self.my - 8), F.text)
      ns.ton("plopp")
    end
    if seit >= 0.62 then self:Neu() end
  elseif self.phase == "fallen" then
    self.fallV = self.fallV + 520 * dt
    self.fallY = self.fallY + self.fallV * dt
    if seit >= 0.9 then self:Neu() end
  elseif self.phase == "neu" and seit >= 0.35 then
    self.phase = "roesten"
  end
  if self.meldungBis and jetzt >= self.meldungBis then
    self.meldungBis = nil
    self.hinweis = nil
    self:Hinweis()
  end
  self:Zeichnen(jetzt, dt)
end

-- Rauch und Funken -----------------------------------------------------------------------------

-- art: "faden" dünn und hell, "brand" dicht und dunkel, "puste" seitlich weggeblasen
function M:Rauch(x, y, art)
  if not (x and y) then return end
  local t
  for _, r in ipairs(self.rauch) do if not r.aktiv then t = r break end end
  if not t then return end
  t.aktiv, t.x, t.y, t.alter, t.phase = true, x, y, 0, math.random() * 6
  if art == "brand" then
    t.dauer, t.g0, t.g1, t.vy, t.vx, t.a0, t.hell = 1.5, 10, 40, 28, SP.zufall(-5, 5), 0.9, 0.6
  elseif art == "puste" then
    t.dauer, t.g0, t.g1, t.vy, t.a0, t.hell = 0.9, 8, 30, 8, 0.6, 0.8
    t.vx = SP.zufall(28, 44) * (math.random() < 0.5 and -1 or 1)
  else
    t.dauer, t.g0, t.g1, t.vy, t.vx, t.a0, t.hell = 1.8, 6, 28, 18, SP.zufall(-3, 3), 0.55, 0.85
  end
  -- vom Feuer von unten angestrahlt: warmes Grau, sonst verschwindet er in der Nacht
  t:SetVertexColor(t.hell, t.hell * 0.95, t.hell * 0.9)
end

function M:Funke(x, y, schnell)
  for _, f in ipairs(self.funken) do
    if not f.aktiv then
      f.aktiv, f.x, f.y, f.alter = true, x, y, 0
      f.vx, f.vy = SP.zufall(-8, 8), SP.zufall(22, 46) * (schnell or 1)
      f.dauer, f.g, f.phase = SP.zufall(0.9, 1.8), SP.zufall(4, 7), math.random() * 6
      return
    end
  end
end

function M:Teilchen(dt)
  local u = self.uhr
  self.funkenTakt = self.funkenTakt + dt * (self.lodernBis and 24 or 6)
  while self.funkenTakt >= 1 do
    self.funkenTakt = self.funkenTakt - 1
    self:Funke(FEUER_X + SP.zufall(-30, 30), ORT.bett * HOEHE - SP.zufall(14, 44))
  end
  for _, f in ipairs(self.funken) do
    if f.aktiv then
      f.alter = f.alter + dt
      local p = f.alter / f.dauer
      f.y = f.y - f.vy * dt
      f.x = f.x + (f.vx + 10 * math.sin(u * 3 + f.phase)) * dt
      if p >= 1 or f.y < 6 then
        f.aktiv = nil
        f:Hide()
      else
        self:Zeigen(f, f.x, f.y, f.g, f.g, f.k)
        f:SetAlpha((1 - p) * math.min(1, p * 8) * (0.7 + 0.3 * math.sin(u * 20 + f.phase)))
      end
    end
  end
  for _, t in ipairs(self.rauch) do
    if t.aktiv then
      t.alter = t.alter + dt
      local p = t.alter / t.dauer
      t.y = t.y - t.vy * dt
      t.x = t.x + (t.vx + 6 * math.sin(u * 2 + t.phase)) * dt
      local g = t.g0 + (t.g1 - t.g0) * p
      -- oben am Rand ausblenden, statt hinauszuragen
      local rand = grenzen((t.y - g / 2) / 12, 0, 1)
      if p >= 1 or rand <= 0 then
        t.aktiv = nil
        t:Hide()
      else
        self:Zeigen(t, t.x, t.y, g, g, t.k)
        t:SetAlpha(t.a0 * math.min(1, p * 5) * (1 - p) * rand)
      end
    end
  end
end

-- Zeichnen -------------------------------------------------------------------------------------

function M:FlammenZeichnen(dt, jetzt)
  self.bildZeit = self.bildZeit + dt
  local pos = self.bildZeit / TAKT
  local n = math.floor(pos) % BILDER
  if n ~= self.bildNr then
    self.bildNr = n
    local k1, k2 = FEUER_K[n + 1], FEUER_K[(n + 1) % BILDER + 1]
    self.flamme1:SetTexCoord(k1[1], k1[2], k1[3], k1[4])
    self.flamme2:SetTexCoord(k2[1], k2[2], k2[3], k2[4])
  end
  self.flamme2:SetAlpha(pos - math.floor(pos))
  local u = self.uhr
  local flackern = 0.55 + 0.2 * math.sin(u * 9.3) * math.sin(u * 3.1) + 0.1 * math.sin(u * 23)
  -- Lodern: Zungen schießen aus den Flammenspitzen hoch
  if self.lodernBis then
    local p = grenzen((jetzt - self.lodernSeit) / 0.9, 0, 1)
    flackern = flackern + 0.45 * math.sin(math.pi * p)
    for i, t in ipairs(self.lohen) do
      local g = 30 + 12 * p + (i == 2 and 8 or 0)
      local x = FEUER_X + (i - 2) * 14
      local fuss = ORT.spitze * HOEHE + 22 - 30 * p - (i == 2 and 6 or 0)
      self:Zeigen(t, x, fuss - g / 2, g, g, K.zunge[(math.floor(u * 12) + i * 3) % 8 + 1])
      t:SetAlpha(math.sin(math.pi * p))
    end
  else
    for _, t in ipairs(self.lohen) do t:Hide() end
  end
  self.schein:SetAlpha(flackern)
end

function M:Zeichnen(jetzt, dt)
  self:FlammenZeichnen(dt, jetzt)
  self:Teilchen(dt)
  local u = self.uhr
  -- Ast schwankt leicht, der Marshmallow hängt etwas nach
  local sx = SPITZE_X + 1.6 * math.sin(u * 1.3) + 0.8 * math.sin(u * 2.9 + 0.5)
  local sy = self.y + 1.1 * math.sin(u * 1.7 + 1)
  self:Zeigen(self.stock, sx - STOCK.x + STOCK.b / 2, sy - STOCK.y + STOCK.h / 2, STOCK.b, STOCK.h, STOCK.coords)
  local mx, my = sx, sy + grenzen(-self.v * 0.025, -3, 3)
  local alpha, skala = 1, 1
  local seit = jetzt - (self.phaseSeit or jetzt)
  if self.phase == "essen" then
    skala = 1 + 0.14 * math.min(1, seit / 0.22)
    if seit >= 0.45 then alpha = grenzen(1 - (seit - 0.45) / 0.12, 0, 1) end
  elseif self.phase == "neu" then
    local p = grenzen(seit / 0.35, 0, 1)
    alpha = p
    skala = 0.6 + 0.4 * p + 0.12 * math.sin(math.pi * p)
  elseif self.phase == "fallen" then
    my = self.fallY
    alpha = grenzen(1 - (my - ORT.krone * HOEHE) / 30, 0, 1)
  end
  self.mx, self.my = mx, my
  -- Größe: geht warm auf, quetscht sich beim schnellen Bewegen, wird beim Drehen flach
  local groesse = ZELLE * skala * (1 + 0.1 * self.waerme)
  local quetsch = 1 + grenzen(self.v * 0.0015, -0.07, 0.07)
  local dreh = self.drehen and (1 - 0.45 * math.sin(math.pi * self.drehen)) or 1
  local b, h = groesse / math.sqrt(quetsch), groesse * quetsch * dreh
  -- Seiten: oben die ganze Form, unten die freigestellte Hälfte, je zwei Stufen überblendet
  local o, un = self.seiten[3 - self.unten], self.seiten[self.unten]
  local gk, uk = self.biss == 1 and K.biss or K.ganz, self.biss == 1 and K.bissUnten or K.unten
  local i1, a1 = stufe(o)
  local i2, a2 = stufe(un)
  local w = self.anteil or 0
  -- Licht vom Feuer: oben kühl und etwas dunkler, unten warm
  local lr, lg, lb = 0.8 + 0.2 * w, 0.8 + 0.14 * w, 0.88 - 0.02 * w
  local lagen = self.lagen
  if alpha <= 0 then
    for i = 1, 4 do lagen[i]:Hide() end
  else
    self:Zeigen(lagen[1], mx, my, b, h, gk[i1])
    self:Zeigen(lagen[2], mx, my, b, h, gk[i1 + 1])
    self:Zeigen(lagen[3], mx, my, b, h, uk[i2])
    self:Zeigen(lagen[4], mx, my, b, h, uk[i2 + 1])
    for i = 1, 4 do lagen[i]:SetVertexColor(lr, lg, lb) end
    lagen[1]:SetAlpha(alpha)
    lagen[2]:SetAlpha(alpha * a1)
    lagen[3]:SetAlpha(alpha)
    lagen[4]:SetAlpha(alpha * a2)
  end
  -- Flammen auf dem brennenden Marshmallow
  for i, t in ipairs(self.brandZungen) do
    if self.brand and alpha > 0 then
      local g = (14 + 16 * self.brand) * (i == 2 and 1.2 or 0.9)
      local fx, fy = mx + BRAND_ORT[i][1], my + BRAND_ORT[i][2]
      self:Zeigen(t, fx, fy - g / 2 + 3, g, g, K.zunge[(math.floor(u * 12) + i * 3) % 8 + 1])
      t:SetAlpha(math.min(1, self.brand * 3))
    else
      t:Hide()
    end
  end
  -- Seitenanzeige: Bräune beider Seiten, die Flamme zeigt die Seite zum Feuer
  for i, bk in ipairs(self.balken) do
    local s = self.seiten[i]
    local j, a = stufe(s)
    local c1, c2 = FARBEN[j + 1], FARBEN[j + 2]
    bk.voll:SetWidth(math.max(0.5, 68 * s))
    bk.voll:SetVertexColor(c1[1] + (c2[1] - c1[1]) * a, c1[2] + (c2[2] - c1[2]) * a, c1[3] + (c2[3] - c1[3]) * a)
    bk.flamme:SetShown(i == self.unten)
  end
end

function M:Stop()
  self.brand, self.drehen = nil, nil
  for _, t in ipairs(self.brandZungen or {}) do t:Hide() end
  for _, t in ipairs(self.lohen or {}) do t:Hide() end
  for _, t in ipairs(self.rauch or {}) do t.aktiv = nil t:Hide() end
  for _, t in ipairs(self.funken or {}) do t.aktiv = nil t:Hide() end
end

SP.Registrieren(M)
