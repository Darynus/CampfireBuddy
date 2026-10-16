-- Murloc-Show: Während der Sitz-Minute am Lagerfeuer läuft ein Murloc mit zufälligem Namen über
-- eine kleine Nachtszene auf einem Trampelpfad zum Feuer. Unterwegs wechselt er ständig, was er tut
-- (gehen, bummeln, rennen, winken, tanzen, umschauen, etwas aufheben, kurz hinsetzen, Käfer jagen),
-- kommt aber pünktlich an. Dann zeigt er eines von zehn Finales, nie zweimal hintereinander dasselbe.
-- Er bleibt immer mit den Füßen auf dem Weg: kein Hüpfen, Schweben oder Schwimmen.
-- Nur Anzeige, keine Spielaktion. Abschaltbar, bei Kampfbeginn weg.
--
-- 3D-Modell: einer der Baby-Murlocs Murky (Display-ID 15369) oder Gurky (15984), laut Wowhead in
-- Forever vorhanden. Lädt keiner, der große Murloc (31, murloc2.m2). Animationen nach AnimationData;
-- hat das Modell eine nicht (HasAnimation), nimmt die Show die nächste aus der Liste.
-- Lädt gar kein Modell, läuft ein 2D-Murloc-Kopf mit eigenen Bewegungen.
-- Blickrichtung (SetFacing): +pi/2 schaut nach rechts (Patricks Test in der Beta, 14. Okt).
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba

local SH = {}
ns.Show = SH

local BREITE, HOEHE = 400, 132
-- Die Nachtszene liegt 1 Pixel innerhalb des Rahmens
local SZENE_B, SZENE_H = BREITE - 2, HOEHE - 2
-- Weg und Feuer in der Nachtszene, aus Blender gemessen (Atlas.lua, tools/grafik/spiele.js):
-- Mittellinie des Wegs am linken und rechten Bildrand, von oben (0 bis 1 der Szene), und die
-- Lage des Feuers in der Breite. Fehlt Atlas.lua, gelten die Maße der alten Szene.
local WEG = S.NACHT_WEG or { 0.84, 0.84 }
local FEUER_X = 1 + (S.NACHT_FEUER or 0.915) * SZENE_B
local SPUR_LINKS, SPUR_RECHTS = 22, FEUER_X - 30
local FIGUR = 84
-- Ein PlayerModel lässt mit der Standardkamera unter den Füßen etwas Luft: bei 84 Pixeln
-- Rahmenhöhe etwa 8 Pixel (so stand der Murloc in der Beta auf dem Boden). Um so viel sitzt der
-- Rahmen tiefer als die Weg-Linie, dann stehen die Füße darauf.
local FUSS_LUFT = 8
-- Bildblatt des Lagerfeuers: 52 Pixel, die Mitte des Steinrings liegt 10 Pixel über dem unteren Rand
local FEUER_GROESSE, FEUER_LUFT = 52, 10
local MURLOC_DISPLAYS = { 15369, 15984 }
local MURLOC_ERSATZ = 31
local MURLOC_KOPF = "Interface\\Icons\\INV_Misc_Head_Murloc_01"
local RECHTS, LINKS, VORNE = math.pi / 2, -math.pi / 2, 0
local SCHRAEG = math.pi / 4          -- halb nach rechts, halb zum Betrachter
local FINALE_DAUER = 5
local FEUERWERK = 18                 -- Teilchen je Feuerwerkskörper
local KONFETTI = 26
local FUNKEN = 3                     -- höchstens so viele Funken gleichzeitig über dem Feuer
local KONFETTI_FARBEN = { { 1, 0.35, 0.3 }, { 0.35, 0.8, 1 }, { 1, 0.85, 0.25 }, { 0.5, 1, 0.4 }, { 1, 0.5, 0.9 } }

-- Animationen mit Ersatz, falls das Modell eine nicht hat. Alle am Boden: Schwimmen (42) und
-- Springen (37, 38) sehen in der kleinen Szene aus, als würde der Murloc fliegen.
local ANIM = {
  stehen = { 0 }, gehen = { 4 }, rennen = { 5, 4 }, rueckwaerts = { 13, 4 },
  winken = { 67, 60, 0 }, tanzen = { 69, 55, 0 }, jubeln = { 68, 55, 0 }, klatschen = { 80, 68, 0 },
  bruellen = { 74, 55, 0 }, muskeln = { 82, 55, 0 }, lachen = { 70, 60, 0 }, angriff = { 16, 17, 0 },
  aufheben = { 50, 61, 0 }, sitzen = { 97, 72, 0 }, umfallen = { 1, 0 }, schlafen = { 71, 72, 0 },
  weinen = { 77, 0 },
}

-- Was er unterwegs tut: Name, Gewicht, Dauer, bewegt er sich (Tempo-Faktor), Blick
local AKTE = {
  { name = "gehen", gewicht = 5, von = 2, bis = 4, tempo = 1, blick = RECHTS, anim = "gehen" },
  { name = "bummeln", gewicht = 1.4, von = 1.8, bis = 2.6, tempo = 0.75, blick = SCHRAEG, anim = "gehen" },
  { name = "rennen", gewicht = 1, von = 1.2, bis = 2, tempo = 2.4, blick = RECHTS, anim = "rennen" },
  { name = "winken", gewicht = 1.1, von = 1.4, bis = 2, tempo = 0, blick = VORNE, anim = "winken", spruch = true },
  { name = "tanzen", gewicht = 1, von = 1.5, bis = 2.2, tempo = 0, blick = VORNE, anim = "tanzen" },
  { name = "umschauen", gewicht = 0.9, von = 1.4, bis = 2, tempo = 0, blick = "pendeln", anim = "stehen" },
  { name = "aufheben", gewicht = 0.7, von = 1.2, bis = 1.6, tempo = 0, blick = RECHTS, anim = "aufheben", spruch = true },
  { name = "verschnaufen", gewicht = 0.5, von = 1.6, bis = 2.2, tempo = 0, blick = VORNE, anim = "sitzen" },
  { name = "kaefer", gewicht = 0.7, von = 1.3, bis = 1.8, tempo = 0, blick = RECHTS, anim = "angriff", spruch = "kaefer" },
}

local FINALES = { "breakdance", "moonwalk", "jubeln", "muskeln", "bruellen", "ehrenrunde", "party",
  "feuerwerk", "stolpern", "einschlafen" }

local function zufall(a, b) return a + math.random() * (b - a) end
local function wahl(t) return t[math.random(1, #t)] end

-- Höhe der Weg-Mitte über dem unteren Rand an der Stelle px. Der Weg ist in Blender eine Gerade
-- und bleibt im Bild eine, also genügt es, zwischen linkem und rechtem Rand zu rechnen.
local function wegHoehe(px)
  local anteil = (px - 1) / SZENE_B
  return 1 + (1 - (WEG[1] + (WEG[2] - WEG[1]) * anteil)) * SZENE_H
end
SH.WegHoehe = wegHoehe

-- Aufbau ----------------------------------------------------------------------------------

-- Licht: kühles Mondlicht als Grundlicht, warmes Feuerlicht dazu. Ältere Clients kennen nur die
-- lange Form von SetLight, deshalb beide versuchen. Geht beides nicht, bleibt das Standardlicht.
local function licht(m)
  if not (m and m.SetLight) then return end
  local ok = false
  if CreateColor and CreateVector3D then
    ok = pcall(m.SetLight, m, true, {
      omnidirectional = false, point = CreateVector3D(-0.6, 1, -0.4),
      ambientIntensity = 0.8, ambientColor = CreateColor(0.66, 0.7, 0.92),
      diffuseIntensity = 0.85, diffuseColor = CreateColor(1, 0.74, 0.46),
    })
  end
  if not ok then pcall(m.SetLight, m, true, false, -0.6, 1, -0.4, 0.8, 0.66, 0.7, 0.92, 0.85, 1, 0.74, 0.46) end
end

local function modell(parent)
  local ok, m = pcall(CreateFrame, "PlayerModel", nil, parent)
  if ok and m and m.SetDisplayInfo then
    m:SetSize(FIGUR, FIGUR)
    -- sonst wirft das Modell beim Verstecken alles weg (leere Party-Freunde)
    if m.SetKeepModelOnHide then pcall(m.SetKeepModelOnHide, m, true) end
    -- Ist das Modell fertig geladen, die aktuelle Animation noch einmal setzen
    m:SetScript("OnModelLoaded", function()
      if SH.laeuft and SH.akt and not SH.finale then SH.aktAnim = nil SH:Anim(SH.akt.anim) end
    end)
    return m
  end
end

-- Teilchen an Stelle x, y (vom unteren linken Eck) zeichnen
local function setzen(t, rahmen, x, y)
  t:ClearAllPoints()
  t:SetPoint("CENTER", rahmen, "BOTTOMLEFT", x, y)
end

function SH:Bauen()
  if self.rahmen then return end
  local f = S.kasten(UIParent, "Frame", F.grund, F.rand)
  self.rahmen = f
  f:SetSize(BREITE, HOEHE)
  f:SetScale(SH.Faktor and SH.Faktor() or 1)
  ns.Leiste.Position(f, ns.db.show, "CENTER", 0, 110)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not ns.db.gesperrt then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    ns.db.show = ns.Leiste.Merken(self)
  end)
  S.schatten(f)
  f:Hide()

  -- Nachtszene (eigene Grafik aus Blender: Mond und Sterne, Berge, Tannen, Trampelpfad zum Feuer)
  local szene = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  szene:SetPoint("TOPLEFT", 1, -1)
  szene:SetPoint("BOTTOMRIGHT", -1, 1)
  szene:SetTexture(S.NACHT)
  szene:SetTexCoord(0, 1, 0, S.NACHT_HOEHE)

  -- Lagerfeuer am Ende des Wegs, der Steinring steht auf der Weg-Linie. Den Feuerschein auf Weg
  -- und Bank hat die Nachtszene schon (Blender), hier nur das Feuer.
  self.feuerBoden = wegHoehe(FEUER_X) - FEUER_LUFT
  self.feuer = f:CreateTexture(nil, "ARTWORK")
  self.feuer:SetSize(FEUER_GROESSE, FEUER_GROESSE)
  self.feuer:SetPoint("BOTTOM", f, "BOTTOMLEFT", FEUER_X, self.feuerBoden)
  local takt = S.feuer(self.feuer)
  -- zweite, leuchtende Lage darüber: flackert im selben Takt
  self.flackern = f:CreateTexture(nil, "ARTWORK", nil, 1)
  self.flackern:SetAllPoints(self.feuer)
  S.feuer(self.flackern, takt)
  if self.flackern.SetBlendMode then self.flackern:SetBlendMode("ADD") end

  -- Wenige kleine Funken, die aus der Flamme steigen und gleich darüber verlöschen
  self.funken = {}
  for i = 1, FUNKEN do
    local t = S.kreis(f, 3, 3, { 1, 0.62, 0.2, 1 }, "OVERLAY", true)
    t:Hide()
    self.funken[i] = t
  end
  -- Feuerwerk (nur im Finale Feuerwerk): Rakete als heller Strich, dann bunte Teilchen
  self.rakete = S.kreis(f, 2, 8, { 1, 0.9, 0.7, 1 }, "OVERLAY", true)
  self.rakete:Hide()
  self.teilchen = {}
  for i = 1, FEUERWERK do
    local t = S.kreis(f, 4, 4, F.akzent, "OVERLAY", true)
    t:Hide()
    self.teilchen[i] = t
  end
  -- Konfetti (nur im Finale Party): bunte Schnipsel, die sich drehend herabfallen
  self.konfetti = {}
  for i = 1, KONFETTI do
    local k = f:CreateTexture(nil, "OVERLAY")
    k:SetTexture(S.WEISS)
    k:SetSize(3, 5)
    k:Hide()
    self.konfetti[i] = k
  end

  -- Murloc mit Schatten, Freunde für die Party, 2D-Ersatz
  self.schatten = S.kreis(f, 36, 9, { 0, 0, 0, 0.55 }, "BORDER")
  self.modell = modell(f)
  self.freunde = { modell(f), modell(f) }
  for _, m in ipairs(self.freunde) do m:Hide() end
  self.kopf = f:CreateTexture(nil, "OVERLAY")
  self.kopf:SetSize(32, 32)
  self.kopf:SetTexture(MURLOC_KOPF)
  self.kopf:Hide()
  self.freundKoepfe = {}
  for i = 1, 2 do
    local k = f:CreateTexture(nil, "OVERLAY")
    k:SetSize(26, 26)
    k:SetTexture(MURLOC_KOPF)
    k:Hide()
    self.freundKoepfe[i] = k
  end
  self.blase = S.blase(f)
  self.blase:SetFrameLevel((f.GetFrameLevel and f:GetFrameLevel() or 1) + 10)

  -- Kopfzeile
  local leiste = f:CreateTexture(nil, "BORDER")
  leiste:SetPoint("TOPLEFT", 1, -1)
  leiste:SetPoint("TOPRIGHT", -1, -1)
  leiste:SetHeight(22)
  leiste:SetColorTexture(0, 0, 0, 0.35)
  local zu = S.zeichenKnopf(f, "x", function() SH:Beenden() end)
  zu:SetSize(18, 18)
  zu:SetPoint("TOPRIGHT", -3, -2)
  S.tooltip(zu, L.SHOW_CLOSE, L.SHOW_CLOSE_HELP)
  f.spielen = S.textKnopf(f, L.BTN_PLAY, 54, function() ns.Spiel:Menue(true) end)
  f.spielen:SetHeight(18)
  f.spielen:SetPoint("TOPRIGHT", -24, -2)
  S.tooltip(f.spielen, L.BTN_PLAY, L.PLAY_HELP)
  -- Emote und Optionen (ShowMenue.lua), links daneben die Zeit, ganz links der Titel
  local links = self:MenueBauen(f, f.spielen)
  f.zeit = S.schrift(f, "GameFontHighlightSmall", F.text)
  f.zeit:SetPoint("RIGHT", links, "LEFT", -8, 0)
  f.titel = S.schrift(f, "GameFontHighlightSmall", F.akzent)
  f.titel:SetPoint("TOPLEFT", 10, -6)
  f.titel:SetPoint("RIGHT", f.zeit, "LEFT", -8, 0)
  f.titel:SetJustifyH("LEFT")
  f.titel:SetWordWrap(false)

  f:SetScript("OnUpdate", function(_, dt) SH:Tick(dt) end)
end

-- Modell und Animationen ------------------------------------------------------------------

local function geladen(m)
  if not m then return false end
  local ok, datei = pcall(m.GetModelFileID, m)
  return ok and type(datei) == "number" and datei > 0
end

function SH:DisplaySetzen(id)
  for _, m in ipairs({ self.modell, self.freunde[1], self.freunde[2] }) do
    if m then
      pcall(m.SetDisplayInfo, m, id)
      licht(m)
    end
  end
end

-- Ein zufälliger Baby-Murloc. Ist er nach einem halben Augenblick nicht geladen, der große Murloc.
function SH:FigurLaden()
  self.dreiD = false
  self:DisplaySetzen(MURLOC_DISPLAYS[math.random(1, #MURLOC_DISPLAYS)])
  self.dreiD = geladen(self.modell)
  if not self.dreiD and C_Timer and C_Timer.After then
    local function fertig()
      if SH.laeuft and geladen(SH.modell) then
        SH.dreiD = true
        SH:FigurZeigen()
        if SH.akt and not SH.finale then SH:Anim(SH.akt.anim) end
        return true
      end
    end
    C_Timer.After(0.5, function()
      if not SH.laeuft or fertig() then return end
      SH:DisplaySetzen(MURLOC_ERSATZ)
      C_Timer.After(0.4, fertig)
    end)
  end
  self:FigurZeigen()
end

function SH:FigurZeigen()
  if self.modell then self.modell:SetShown(self.dreiD) end
  self.kopf:SetShown(not self.dreiD)
  self.aktAnim = nil
end

-- Erste Animation aus der Liste, die das Modell hat. m: anderes Modell (Freunde)
function SH:Anim(name, m)
  local ziel = m or self.modell
  if not (self.dreiD and ziel) then return end
  for _, id in ipairs(ANIM[name] or ANIM.stehen) do
    local hat = true
    if ziel.HasAnimation then
      local ok, ja = pcall(ziel.HasAnimation, ziel, id)
      if ok and ja ~= nil then hat = ja end
    end
    if hat then
      if m or self.aktAnim ~= id then
        pcall(ziel.SetAnimation, ziel, id)
        if not m then self.aktAnim = id end
      end
      return
    end
  end
end

function SH:Sagen(text, dauer)
  self.blase:Zeigen(text)
  self.blaseBis = ns.jetzt() + (dauer or 2)
end

-- Zeichnen: Figur, Schatten und Blase an Position x (0 bis 1) auf dem Weg, Blick blick.
-- hoch ist nur beim 2D-Kopf etwas über 0 (kleines Wippen beim Gehen), das Modell steht immer.
function SH:Zeichnen()
  local f = self.rahmen
  local px = SPUR_LINKS + self.x * (SPUR_RECHTS - SPUR_LINKS)
  local fuss = wegHoehe(px)
  self.px, self.fuss = px, fuss
  if self.dreiD and self.modell then
    self.modell:ClearAllPoints()
    self.modell:SetPoint("BOTTOM", f, "BOTTOMLEFT", px, fuss - FUSS_LUFT)
    pcall(self.modell.SetFacing, self.modell, self.blick)
  else
    self.kopf:ClearAllPoints()
    self.kopf:SetPoint("BOTTOM", f, "BOTTOMLEFT", px, fuss + 2 + self.hoch)
    -- 2D: SetRotation überschreibt die Texturkoordinaten. Also entweder drehen oder spiegeln.
    local dreh = self.dreh2d or 0
    if math.abs(dreh) > 0.01 then
      self.kopf:SetRotation(dreh)
    else
      self.kopf:SetRotation(0)
      if self.blick == LINKS then self.kopf:SetTexCoord(0, 1, 0, 1) else self.kopf:SetTexCoord(1, 0, 0, 1) end
    end
  end
  self.schatten:ClearAllPoints()
  self.schatten:SetPoint("CENTER", f, "BOTTOMLEFT", px, fuss)
  -- Blase im Rahmen halten: halbe Breite links und rechts, oben unter der Kopfzeile
  local halb = (self.blase:GetWidth() or 80) / 2 + 4
  local bx = math.min(BREITE - halb, math.max(halb, px))
  local by = math.min(HOEHE - 24 - 26, fuss + (self.dreiD and FIGUR - 22 or 40))
  self.blase:ClearAllPoints()
  self.blase:SetPoint("BOTTOM", f, "BOTTOMLEFT", bx, by)
end

-- Kulisse: Feuer flackert, wenige Funken steigen aus der Flamme, im Finale Feuerwerk und Konfetti
function SH:Kulisse(dt, jetzt)
  -- Das Feuer flackert selbst (Bildblatt), die helle Lage gibt nur noch etwas Glanz dazu
  self.flackern:SetAlpha(0.05 + 0.12 * math.abs(math.sin(jetzt * 9.1) * math.sin(jetzt * 3.3)))
  local f = self.rahmen
  for _, t in ipairs(self.funken) do
    if not t.aktiv and math.random() < dt * 0.5 then
      t.aktiv, t.x, t.y = true, FEUER_X + zufall(-5, 5), self.feuerBoden + zufall(24, 32)
      t.vx, t.vy, t.leben, t.alter = zufall(-4, 4), zufall(14, 24), zufall(0.6, 1), 0
      t:Show()
    end
    if t.aktiv then
      t.alter = t.alter + dt
      t.x, t.y = t.x + t.vx * dt, t.y + t.vy * dt
      local rest = 1 - t.alter / t.leben
      if rest <= 0 then
        t.aktiv = false
        t:Hide()
      else
        t:SetAlpha(rest)
        setzen(t, f, t.x, t.y)
      end
    end
  end
  -- Rakete steigt, oben platzt sie
  local r = self.rakete
  if r.aktiv then
    r.alter = r.alter + dt
    local a = r.alter / r.dauer
    if a >= 1 then
      r.aktiv = false
      r:Hide()
      self:Platzen(r.x1, r.y1)
      ns.ton("boom")
    else
      setzen(r, f, r.x0 + (r.x1 - r.x0) * a, r.y0 + (r.y1 - r.y0) * (1 - (1 - a) ^ 2))
    end
  end
  for _, t in ipairs(self.teilchen) do
    if t.aktiv then
      t.alter = t.alter + dt
      t.vy = t.vy - t.schwer * dt
      t.x, t.y = t.x + t.vx * dt, t.y + t.vy * dt
      local rest = 1 - t.alter / t.leben
      t:SetAlpha(math.max(0, rest))
      setzen(t, f, t.x, t.y)
      -- Unter der Titelzeile verlöschen: Ein Funke im Titel sieht aus wie ein Tippfehler
      if rest <= 0 or t.y > HOEHE - 26 then t.aktiv = false t:Hide() end
    end
  end
  for _, k in ipairs(self.konfetti) do
    if k.aktiv then
      if k.warte > 0 then
        k.warte = k.warte - dt
        if k.warte <= 0 then k:Show() end
      else
        k.alter = k.alter + dt
        k.y = k.y - k.vy * dt
        local x = k.x + math.sin(k.alter * 3 + k.phase) * 7
        k:SetRotation(k.alter * k.dreh)
        setzen(k, f, x, k.y)
        -- liegt auf dem Weg: weg damit
        if k.y < wegHoehe(x) - 4 then k.aktiv = false k:Hide() end
      end
    end
  end
  if self.blaseBis and jetzt >= self.blaseBis then self.blaseBis = nil self.blase:Hide() end
end

-- Feuerwerk: Teilchen platzen aus einem Punkt am Himmel
function SH:Platzen(x, y)
  for _, t in ipairs(self.teilchen) do
    local winkel = zufall(0, 2 * math.pi)
    local v = zufall(40, 90)
    t.aktiv, t.x, t.y = true, x, y
    t.vx, t.vy, t.leben, t.alter, t.schwer = math.cos(winkel) * v, math.sin(winkel) * v + 30, zufall(1, 1.6), 0, 70
    t:SetVertexColor(zufall(0.4, 1), zufall(0.4, 1), zufall(0.4, 1), 1)
    t:Show()
  end
end

-- Eine Rakete steigt neben dem Feuer vom Weg auf und platzt nach einer knappen halben Sekunde
function SH:Rakete()
  local r = self.rakete
  r.x0 = FEUER_X + zufall(-70, -15)
  r.y0 = wegHoehe(r.x0) + 4
  r.x1, r.y1 = r.x0 + zufall(-15, 15), zufall(84, HOEHE - 34)
  r.alter, r.dauer, r.aktiv = 0, 0.45, true
  setzen(r, self.rahmen, r.x0, r.y0)
  r:Show()
end

-- Konfetti: fällt über der Party nach und nach von oben herab
function SH:Konfetti()
  for _, k in ipairs(self.konfetti) do
    k.aktiv, k.warte, k.alter = true, zufall(0, 1.6), 0
    k.x, k.y = zufall(150, BREITE - 14), HOEHE - 26
    k.vy, k.phase, k.dreh = zufall(22, 34), zufall(0, 6), zufall(-7, 7)
    local farbe = wahl(KONFETTI_FARBEN)
    k:SetVertexColor(farbe[1], farbe[2], farbe[3], 1)
    k:Hide()
  end
end

-- Lauf -------------------------------------------------------------------------------------

function SH:NeuerAkt(jetzt, erzwungen)
  local akt = erzwungen
  if not akt then
    local summe = 0
    for _, a in ipairs(AKTE) do if a.name ~= self.akt.name then summe = summe + a.gewicht end end
    local w = math.random() * summe
    for _, a in ipairs(AKTE) do
      if a.name ~= self.akt.name then
        w = w - a.gewicht
        if w <= 0 then akt = a break end
      end
    end
    akt = akt or AKTE[1]
  end
  self.akt, self.aktBis = akt, jetzt + zufall(akt.von, akt.bis)
  self:Anim(akt.anim)
  if akt.spruch == true and math.random() < 0.6 then self:Sagen(wahl(L.MURLOC_LINES), 1.6)
  elseif akt.spruch == "kaefer" then self:Sagen(L.MURLOC_BUG, 1.4) end
  if akt.name == "winken" then ns.mrgl(0.5) elseif akt.name == "kaefer" then ns.ton("plopp") end
end

local function akt(name) for _, a in ipairs(AKTE) do if a.name == name then return a end end end

function SH:LaufTick(dt, jetzt)
  local rest = (self.ende or 0) - jetzt
  local ziel = math.min(1, math.max(0, 1 - rest / self.dauer))
  local zeit = string.format(L.SHOW_LEFT, ns.dauerText(rest))
  if zeit ~= self.zeitText then
    self.zeitText = zeit
    self.rahmen.zeit:SetText(zeit)
  end
  if rest <= 0 then return self:Finale() end
  -- Hinkt er hinterher oder ist bald Schluss: rennen. Sonst Akt nach Ablauf wechseln.
  if (ziel - self.x > 0.18 or rest < 3) and self.akt.tempo < 2 then
    self:NeuerAkt(jetzt, akt("rennen"))
  elseif jetzt >= self.aktBis then
    self:NeuerAkt(jetzt)
  end
  local a = self.akt
  local basis = 1.35 / self.dauer
  if a.tempo > 0 then self.x = math.min(ziel + 0.02, self.x + basis * a.tempo * dt, 1) end
  -- Nur der 2D-Kopf wippt beim Gehen ein wenig (er hat keine Gehanimation)
  self.hoch = (not self.dreiD and a.tempo > 0) and math.abs(math.sin(jetzt * 8)) * 3 or 0
  -- Blick: beim Umschauen hin und her
  if a.blick == "pendeln" then
    self.blick = (math.floor(jetzt / 0.6) % 2 == 0) and LINKS or RECHTS
  else
    self.blick = a.blick
  end
  if not self.dreiD then
    self.dreh2d = a.name == "tanzen" and math.sin(jetzt * 10) * 0.35 or 0
  end
end

-- Finale --------------------------------------------------------------------------------

function SH:Finale()
  if self.finale then return end
  local w
  repeat w = wahl(FINALES) until (w ~= self.letzte and w ~= self.vorletzte) or #FINALES < 3
  self.vorletzte, self.letzte = self.letzte, w
  self.finale, self.tf, self.schritt = w, 0, 0
  self.x, self.hoch = math.max(self.x, 0.97), 0
  self.rahmen.zeit:SetText("")
  self.zeitText = nil
  self.rahmen.titel:SetText(string.format(L.SHOW_DONE_NAME, self.name))
  self:Sagen(L.FINALE_LINES[w] or wahl(L.MURLOC_LINES), 2.4)
  -- Angekommen: kurz jubeln, dann das eigentliche Finale
  self:Anim("jubeln")
  ns.mrgl()
  ns.ton("fertig")
end

-- Hilfe: Schritt nur einmal ausführen
function SH:Einmal(nr, f)
  if self.schritt < nr then
    self.schritt = nr
    f()
  end
end

function SH:FinaleTick(dt, jetzt)
  self.tf = self.tf + dt
  local t, e = self.tf, self.finale
  self.hoch = 0
  if e == "breakdance" then
    if t >= 0.6 then
      self:Einmal(1, function() self:Anim("tanzen") end)
      self.blick = self.blick + dt * 13
      self.dreh2d = self.blick
    end
  elseif e == "moonwalk" then
    self.blick = RECHTS
    if t >= 0.6 and t < 2.6 then
      self:Einmal(1, function() self:Anim("rueckwaerts") end)
      self.x = math.max(0.7, self.x - dt * 0.12)
    elseif t >= 2.6 then
      self:Einmal(2, function() self:Anim("tanzen") self.blick = VORNE end)
      self.blick = VORNE
    end
  elseif e == "jubeln" then
    -- jubeln, dann für sich selbst klatschen
    self.blick = VORNE
    if t >= 2.4 then self:Einmal(1, function() self:Anim("klatschen") end) end
  elseif e == "muskeln" then
    self.blick = VORNE
    if t >= 0.6 then self:Einmal(1, function() self:Anim("muskeln") end) end
  elseif e == "bruellen" then
    self.blick = VORNE
    if t >= 0.6 then self:Einmal(1, function() self:Anim("bruellen") ns.mrgl() end) end
  elseif e == "ehrenrunde" then
    if t < 1.8 then
      self:Einmal(1, function() self:Anim("rennen") end)
      self.blick = LINKS
      self.x = math.max(0.55, self.x - dt * 0.25)
    elseif t < 3.4 then
      self:Einmal(2, function() self:Anim("rennen") end)
      self.blick = RECHTS
      self.x = math.min(0.97, self.x + dt * 0.26)
    else
      self:Einmal(3, function() self:Anim("jubeln") self.blick = VORNE end)
      self.blick = VORNE
    end
  elseif e == "party" then
    self.blick = VORNE
    self:Einmal(1, function()
      self:Anim("tanzen")
      self:Freunde(true)
      self:Konfetti()
      ns.ton("paar")
    end)
    self:FreundeTick(jetzt)
  elseif e == "feuerwerk" then
    -- Raketen steigen neben dem Feuer auf und platzen am Himmel, der Murloc jubelt
    self.blick = VORNE
    if t >= 0.4 and t < 3.4 and math.floor(t / 0.9) > (self.knall or -1) then
      self.knall = math.floor(t / 0.9)
      self:Rakete()
    end
  elseif e == "stolpern" then
    -- tritt rückwärts vom Feuer weg, um es zu bewundern, stolpert, fällt hin und lacht darüber
    if t < 1.1 then
      self:Einmal(1, function() self:Anim("rueckwaerts") end)
      self.blick = RECHTS
      self.x = math.max(0.85, self.x - dt * 0.08)
    elseif t < 2.7 then
      self:Einmal(2, function() self:Anim("umfallen") self:Sagen(L.MURLOC_OUCH, 1.4) ns.ton("umfallen") end)
      self.dreh2d = math.pi / 2
    else
      self:Einmal(3, function() self:Anim("lachen") self.blick = VORNE end)
      self.blick = VORNE
      self.dreh2d = 0
    end
  elseif e == "einschlafen" then
    self.blick = RECHTS
    if t >= 0.8 then
      self:Einmal(1, function() self:Anim("schlafen") self:Sagen(L.MURLOC_ZZZ, 3) end)
      self.dreh2d = 0.3
    end
  end
  if not self.dreiD and e ~= "breakdance" and e ~= "stolpern" and e ~= "einschlafen" then
    self.dreh2d = math.sin(t * 6) * 0.3
  end
  if t >= FINALE_DAUER then self:Beenden() end
end

-- Zwei Murloc-Freunde kommen für die Party dazu, auch sie stehen auf dem Weg
function SH:Freunde(an)
  local f = self.rahmen
  for i = 1, 2 do
    local m, k = self.freunde[i], self.freundKoepfe[i]
    local x = SPUR_LINKS + (i == 1 and 0.62 or 0.8) * (SPUR_RECHTS - SPUR_LINKS)
    if self.dreiD and m then
      m:SetShown(an)
      if an then
        m:ClearAllPoints()
        m:SetPoint("BOTTOM", f, "BOTTOMLEFT", x, wegHoehe(x) - FUSS_LUFT)
        pcall(m.SetFacing, m, VORNE)
        self:Anim("tanzen", m)
      end
    else
      k:SetShown(an)
      if an then
        k:ClearAllPoints()
        k:SetPoint("BOTTOM", f, "BOTTOMLEFT", x, wegHoehe(x) + 2)
      end
    end
  end
end

function SH:FreundeTick(jetzt)
  if self.dreiD then return end
  for i, k in ipairs(self.freundKoepfe) do
    k:SetRotation(math.sin(jetzt * 9 + i) * 0.4)
  end
end

-- Steuerung ---------------------------------------------------------------------------------

-- Start: ende ist die Ablaufzeit des Countdowns (GetTime), dauer seine Länge.
-- immer: auch wenn die Show in den Einstellungen aus ist (Vorschau)
function SH:Starten(ende, dauer, immer)
  if not ns.db or not (ns.db.showAn or immer) then return end
  if InCombatLockdown and InCombatLockdown() then return end
  self:Bauen()
  self:Aufraeumen()
  self.ende, self.dauer = ende, math.max(1, dauer or 60)
  self.laeuft, self.finale, self.knall = true, nil, nil
  self.x, self.hoch, self.blick = 0, 0, RECHTS
  self.akt, self.aktBis = AKTE[1], 0
  self.name = wahl(L.MURLOC_NAMES)
  self.rahmen.titel:SetText(string.format(L.SHOW_TITLE_NAME, self.name))
  self.blase:Hide()
  self.dreh2d = 0
  -- Erst zeigen, dann das Modell laden: versteckte Modelle laden nicht zuverlässig
  self.rahmen:Show()
  self:FigurLaden()
  self:Freunde(false)
  self:NeuerAkt(ns.jetzt(), AKTE[1])
  self:Sagen(wahl(L.MURLOC_START), 2)
  ns.mrgl()
  self:Zeichnen()
end

-- Aufgestanden, bevor die Minute um war: traurig, dann vorbei
function SH:Abbrechen()
  if not self.laeuft or self.finale then return end
  self.finale, self.tf, self.schritt = "traurig", FINALE_DAUER - 2, 0
  self.blick = VORNE
  self:Anim("weinen")
  self:Sagen(L.MURLOC_SAD, 2)
  if ns.Spiel then ns.Spiel:Aufgestanden() end
end

-- Funken, Feuerwerk und Konfetti wegräumen
function SH:Aufraeumen()
  for _, liste in ipairs({ self.funken, self.teilchen, self.konfetti, { self.rakete } }) do
    for _, t in ipairs(liste) do t.aktiv = false t:Hide() end
  end
end

function SH:Beenden()
  self.laeuft, self.finale = false, nil
  if self.rahmen then
    self:Freunde(false)
    self:Aufraeumen()
    self.rahmen:Hide()
  end
end

-- Ein Fehler in einem Bild beendet die Show, statt in jedem Bild erneut aufzutreten
function SH:Tick(dt)
  if not self.laeuft then return end
  local ok, fehler = pcall(self.Schritt, self, dt)
  if not ok then
    ns.melde(string.format(L.ERR_EVENT, "show", tostring(fehler)))
    self:Beenden()
  end
end

function SH:Schritt(dt)
  local jetzt = ns.jetzt()
  self:Kulisse(dt, jetzt)
  if self.finale then self:FinaleTick(dt, jetzt) else self:LaufTick(dt, jetzt) end
  if self.laeuft then self:Zeichnen() end
end

-- Vorschau ohne Lagerfeuer: 15 Sekunden Lauf, dann Finale
function SH:Vorschau()
  self:Starten(ns.jetzt() + 15, 15, true)
end

ns.ereignis("PLAYER_REGEN_DISABLED", function() SH:Beenden() end)
