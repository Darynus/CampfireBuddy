-- Murloc-Show: Während der Sitz-Minute am Lagerfeuer läuft ein Murloc mit zufälligem Namen über
-- eine kleine Nachtszene zum Feuer. Unterwegs wechselt er ständig, was er tut (gehen, rennen,
-- winken, tanzen, umschauen, hüpfen, durch die Luft schwimmen, Käfer jagen), kommt aber pünktlich
-- an. Dann zeigt er eines von zehn Finales, nie zweimal hintereinander dasselbe.
-- Nur Anzeige, keine Spielaktion. Abschaltbar, bei Kampfbeginn weg.
--
-- 3D-Modell: einer der Baby-Murlocs Murky (Display-ID 15369) oder Gurky (15984), laut Wowhead in
-- Forever vorhanden. Lädt keiner, der große Murloc (31, murloc2.m2). Animationen nach AnimationData;
-- hat das Modell eine nicht (HasAnimation), nimmt die Show die nächste aus der Liste.
-- Lädt gar kein Modell, hüpft ein 2D-Murloc-Kopf mit eigenen Bewegungen.
-- Blickrichtung (SetFacing): +pi/2 schaut nach rechts (Patricks Test in der Beta, 14. Okt).
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba

local SH = {}
ns.Show = SH

local BREITE, HOEHE = 340, 132
local BODEN = 26                     -- Höhe des Bodens
local SPUR_LINKS, SPUR_RECHTS = 22, BREITE - 64
local FIGUR = 84
local MURLOC_DISPLAYS = { 15369, 15984 }
local MURLOC_ERSATZ = 31
local MURLOC_KOPF = "Interface\\Icons\\INV_Misc_Head_Murloc_01"
local RECHTS, LINKS, VORNE = math.pi / 2, -math.pi / 2, 0
local FINALE_DAUER = 5
local PARTIKEL = 18

-- Animationen mit Ersatz, falls das Modell eine nicht hat
local ANIM = {
  stehen = { 0 }, gehen = { 4 }, rennen = { 5, 4 }, rueckwaerts = { 13, 4 },
  springen = { 38, 37, 0 }, winken = { 67, 60, 0 }, tanzen = { 69, 55, 0 }, jubeln = { 68, 55, 0 },
  bruellen = { 74, 55, 0 }, muskeln = { 82, 55, 0 }, lachen = { 70, 60, 0 }, angriff = { 16, 17, 0 },
  schwimmen = { 42, 4 }, umfallen = { 1, 0 }, schlafen = { 71, 72, 0 }, weinen = { 77, 0 },
}

-- Was er unterwegs tut: Name, Gewicht, Dauer, bewegt er sich (Tempo-Faktor), Blick
local AKTE = {
  { name = "gehen", gewicht = 5, von = 2, bis = 4, tempo = 1, blick = RECHTS, anim = "gehen" },
  { name = "huepfen", gewicht = 1.2, von = 1.6, bis = 2.4, tempo = 1, blick = RECHTS, anim = "gehen", hopp = true },
  { name = "rennen", gewicht = 1, von = 1.2, bis = 2, tempo = 2.4, blick = RECHTS, anim = "rennen" },
  { name = "schwimmen", gewicht = 0.7, von = 1.6, bis = 2.4, tempo = 1.1, blick = RECHTS, anim = "schwimmen", schweben = 12 },
  { name = "winken", gewicht = 1.1, von = 1.4, bis = 2, tempo = 0, blick = VORNE, anim = "winken", spruch = true },
  { name = "tanzen", gewicht = 1, von = 1.5, bis = 2.2, tempo = 0, blick = VORNE, anim = "tanzen" },
  { name = "umschauen", gewicht = 0.9, von = 1.4, bis = 2, tempo = 0, blick = "pendeln", anim = "stehen" },
  { name = "kaefer", gewicht = 0.7, von = 1.3, bis = 1.8, tempo = 0, blick = RECHTS, anim = "angriff", spruch = "kaefer" },
}

local FINALES = { "breakdance", "moonwalk", "jubeln", "muskeln", "bruellen", "ehrenrunde", "party",
  "feuerwerk", "bauchklatscher", "einschlafen" }

local function zufall(a, b) return a + math.random() * (b - a) end
local function wahl(t) return t[math.random(1, #t)] end

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

function SH:Bauen()
  if self.rahmen then return end
  local f = S.kasten(UIParent, "Frame", F.grund, F.rand)
  self.rahmen = f
  f:SetSize(BREITE, HOEHE)
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

  -- Nachtszene (eigene Grafik: Mond, Berge, Tannen, Boden mit Weg), darüber funkelnde Sterne
  local szene = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  szene:SetPoint("TOPLEFT", 1, -1)
  szene:SetPoint("BOTTOMRIGHT", -1, 1)
  szene:SetTexture(S.NACHT)
  szene:SetTexCoord(0, 1, 0, S.NACHT_HOEHE)
  self.sterne = {}
  for i = 1, 10 do
    local s = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    s:SetSize(2, 2)
    s:SetColorTexture(1, 0.97, 0.85, 1)
    s:SetPoint("TOPLEFT", zufall(130, BREITE - 10), -zufall(24, 60))
    s.phase = zufall(0, 6)
    self.sterne[i] = s
  end

  -- Weg aus Punkten, die hinter dem Murloc aufleuchten
  self.punkte = {}
  for i = 1, 16 do
    local p = S.kreis(f, 4, 4, F.leise, "BORDER")
    p:SetPoint("CENTER", f, "BOTTOMLEFT", SPUR_LINKS + (i - 1) * (SPUR_RECHTS - SPUR_LINKS) / 15, BODEN - 6)
    self.punkte[i] = p
  end

  -- Lagerfeuer mit Schein
  self.schein = S.glut(f, 120, 76, { 1, 0.5, 0.12, 1 })
  self.schein:SetPoint("CENTER", f, "BOTTOMLEFT", SPUR_RECHTS + 30, BODEN + 10)
  self.feuer = f:CreateTexture(nil, "ARTWORK")
  self.feuer:SetSize(52, 52)
  self.feuer:SetPoint("BOTTOM", f, "BOTTOMLEFT", SPUR_RECHTS + 30, BODEN - 12)
  local takt = S.feuer(self.feuer)
  -- zweite, leuchtende Lage darüber: flackert im selben Takt
  self.flackern = f:CreateTexture(nil, "ARTWORK", nil, 1)
  self.flackern:SetAllPoints(self.feuer)
  S.feuer(self.flackern, takt)
  if self.flackern.SetBlendMode then self.flackern:SetBlendMode("ADD") end

  -- Funken und Konfetti
  self.teilchen = {}
  for i = 1, PARTIKEL do
    local t = S.kreis(f, 5, 5, F.akzent, "OVERLAY", true)
    t:Hide()
    self.teilchen[i] = t
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
  f.titel = S.schrift(f, "GameFontHighlightSmall", F.akzent)
  f.titel:SetPoint("TOPLEFT", 10, -6)
  f.zeit = S.schrift(f, "GameFontHighlightSmall", F.text)
  f.zeit:SetPoint("TOPRIGHT", -84, -6)
  local zu = S.zeichenKnopf(f, "x", function() SH:Beenden() end)
  zu:SetSize(18, 18)
  zu:SetPoint("TOPRIGHT", -3, -2)
  S.tooltip(zu, L.SHOW_CLOSE, L.SHOW_CLOSE_HELP)
  f.spielen = S.textKnopf(f, L.BTN_PLAY, 54, function() ns.Spiel:Menue(true) end)
  f.spielen:SetHeight(18)
  f.spielen:SetPoint("TOPRIGHT", -24, -2)
  S.tooltip(f.spielen, L.BTN_PLAY, L.PLAY_HELP)

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

-- Zeichnen: Figur, Schatten und Blase an Position x (0 bis 1), Höhe hoch, Blick blick
function SH:Zeichnen()
  local f = self.rahmen
  local px = SPUR_LINKS + self.x * (SPUR_RECHTS - SPUR_LINKS)
  local y = BODEN - 4 + self.hoch
  if self.dreiD and self.modell then
    self.modell:ClearAllPoints()
    self.modell:SetPoint("BOTTOM", f, "BOTTOMLEFT", px, y - 8)
    pcall(self.modell.SetFacing, self.modell, self.blick)
  else
    self.kopf:ClearAllPoints()
    self.kopf:SetPoint("BOTTOM", f, "BOTTOMLEFT", px, y + 2)
    -- 2D: SetRotation überschreibt die Texturkoordinaten. Also entweder drehen oder spiegeln.
    local dreh = self.dreh2d or 0
    if math.abs(dreh) > 0.01 then
      self.kopf:SetRotation(dreh)
    else
      self.kopf:SetRotation(0)
      if self.blick == LINKS then self.kopf:SetTexCoord(0, 1, 0, 1) else self.kopf:SetTexCoord(1, 0, 0, 1) end
    end
  end
  local s = math.max(0.4, 1 - self.hoch / 60)
  self.schatten:SetSize(36 * s, 9 * s)
  self.schatten:ClearAllPoints()
  self.schatten:SetPoint("CENTER", f, "BOTTOMLEFT", px, BODEN - 4)
  -- Blase im Rahmen halten: halbe Breite links und rechts, oben unter der Kopfzeile
  local halb = (self.blase:GetWidth() or 80) / 2 + 4
  local bx = math.min(BREITE - halb, math.max(halb, px))
  local by = math.min(HOEHE - 24 - 26, y + (self.dreiD and FIGUR - 22 or 40))
  self.blase:ClearAllPoints()
  self.blase:SetPoint("BOTTOM", f, "BOTTOMLEFT", bx, by)
end

-- Kulisse: Sterne funkeln, Feuer flackert, Funken steigen, Teilchen fliegen
function SH:Kulisse(dt, jetzt)
  for _, s in ipairs(self.sterne) do s:SetAlpha(0.35 + 0.65 * math.abs(math.sin(jetzt * 0.9 + s.phase))) end
  self.schein:SetAlpha(0.55 + 0.35 * math.sin(jetzt * 7.3) * math.sin(jetzt * 2.1))
  -- Das Feuer flackert selbst (Bildblatt), die helle Lage gibt nur noch etwas Glanz dazu
  self.flackern:SetAlpha(0.05 + 0.12 * math.abs(math.sin(jetzt * 9.1) * math.sin(jetzt * 3.3)))
  local fx = SPUR_RECHTS + 30
  for _, t in ipairs(self.teilchen) do
    if not t.aktiv and not self.feuerwerk and math.random() < dt * 0.6 then
      t.aktiv, t.x, t.y = true, fx + zufall(-6, 6), BODEN + 14
      t.vx, t.vy, t.leben, t.alter, t.schwer = zufall(-8, 8), zufall(20, 34), zufall(1.2, 2), 0, 0
      t:SetVertexColor(1, zufall(0.45, 0.75), 0.15, 1)
      t:Show()
    end
    if t.aktiv then
      t.alter = t.alter + dt
      t.vy = t.vy - t.schwer * dt
      t.x, t.y = t.x + t.vx * dt, t.y + t.vy * dt
      local rest = 1 - t.alter / t.leben
      t:SetAlpha(math.max(0, rest))
      t:ClearAllPoints()
      t:SetPoint("CENTER", self.rahmen, "BOTTOMLEFT", t.x, t.y)
      -- Unter der Titelzeile verlöschen: Ein Funke im Titel sieht aus wie ein Tippfehler
      if rest <= 0 or t.y > HOEHE - 26 then t.aktiv = false t:Hide() end
    end
  end
  if self.blaseBis and jetzt >= self.blaseBis then self.blaseBis = nil self.blase:Hide() end
  -- leuchtende Punkte hinter dem Murloc
  for i, p in ipairs(self.punkte) do
    local an = (i - 1) / 15 <= self.x
    p:SetVertexColor(rgba(an and F.akzent or F.rand))
  end
end

-- Feuerwerk oder Konfetti: Teilchen platzen aus einem Punkt
function SH:Platzen(x, y, bunt)
  for _, t in ipairs(self.teilchen) do
    local winkel = zufall(0, 2 * math.pi)
    local v = zufall(40, 90)
    t.aktiv, t.x, t.y = true, x, y
    t.vx, t.vy, t.leben, t.alter, t.schwer = math.cos(winkel) * v, math.sin(winkel) * v + 30, zufall(1, 1.6), 0, 70
    if bunt then t:SetVertexColor(zufall(0.4, 1), zufall(0.4, 1), zufall(0.4, 1), 1)
    else t:SetVertexColor(1, zufall(0.5, 0.9), 0.2, 1) end
    t:Show()
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
  -- Höhe: Hüpfen, Schweben, kleines Wippen beim 2D-Kopf
  if a.hopp then
    self.hoch = math.abs(math.sin(jetzt * 7)) * 14
  elseif a.schweben then
    self.hoch = a.schweben + math.sin(jetzt * 3) * 3
  elseif not self.dreiD and a.tempo > 0 then
    self.hoch = math.abs(math.sin(jetzt * 8)) * 4
  else
    self.hoch = math.max(0, self.hoch - dt * 60)
  end
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
  self.x = math.max(self.x, 0.97)
  self.rahmen.zeit:SetText("")
  self.zeitText = nil
  self.rahmen.titel:SetText(string.format(L.SHOW_DONE_NAME, self.name))
  self:Sagen(L.FINALE_LINES[w] or wahl(L.MURLOC_LINES), 2.4)
  self:Anim("springen")
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
  local sprung = t < 0.6 and math.sin(t / 0.6 * math.pi) * 30 or 0
  self.hoch = sprung
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
    if t >= 0.9 and t < 1.5 then self.hoch = math.sin((t - 0.9) / 0.6 * math.pi) * 24 end
    self:Einmal(1, function() self:Anim("jubeln") end)
    self.blick = VORNE
  elseif e == "muskeln" then
    self.blick = VORNE
    if t >= 0.6 then self:Einmal(1, function() self:Anim("muskeln") end) end
  elseif e == "bruellen" then
    self.blick = VORNE
    if t >= 0.6 then
      self:Einmal(1, function() self:Anim("bruellen") ns.mrgl() end)
      if t < 2 then self.hoch = math.sin(t * 60) * 1.5 end   -- bebt beim Brüllen
    end
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
      self:Platzen(BREITE / 2, HOEHE - 30, true)
      ns.ton("paar")
    end)
    self:FreundeTick(jetzt)
  elseif e == "feuerwerk" then
    self:Einmal(1, function() self:Anim("jubeln") self.feuerwerk = true end)
    self.blick = VORNE
    if t >= 0.5 and t < 3.5 and math.floor(t / 0.9) > (self.knall or -1) then
      self.knall = math.floor(t / 0.9)
      self:Platzen(SPUR_RECHTS + zufall(-40, 20), zufall(70, 100), true)
      ns.ton("boom")
    end
  elseif e == "bauchklatscher" then
    if t < 0.9 then
      self.hoch = math.sin(t / 0.9 * math.pi) * 44
    elseif t < 2.6 then
      self:Einmal(1, function() self:Anim("umfallen") self:Sagen(L.MURLOC_OUCH, 1.4) ns.ton("umfallen") end)
      self.dreh2d = math.pi / 2
    else
      self:Einmal(2, function() self:Anim("lachen") self.blick = VORNE end)
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
  if not self.dreiD and e ~= "breakdance" and e ~= "bauchklatscher" and e ~= "einschlafen" then
    self.dreh2d = math.sin(t * 6) * 0.3
  end
  if t >= FINALE_DAUER then self:Beenden() end
end

-- Zwei Murloc-Freunde springen für die Party dazu
function SH:Freunde(an)
  local f = self.rahmen
  for i = 1, 2 do
    local m, k = self.freunde[i], self.freundKoepfe[i]
    local x = SPUR_LINKS + (i == 1 and 0.62 or 0.8) * (SPUR_RECHTS - SPUR_LINKS)
    if self.dreiD and m then
      m:SetShown(an)
      if an then
        m:ClearAllPoints()
        m:SetPoint("BOTTOM", f, "BOTTOMLEFT", x, BODEN - 12)
        pcall(m.SetFacing, m, VORNE)
        self:Anim("tanzen", m)
      end
    else
      k:SetShown(an)
      if an then
        k:ClearAllPoints()
        k:SetPoint("BOTTOM", f, "BOTTOMLEFT", x, BODEN)
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
  self.ende, self.dauer = ende, math.max(1, dauer or 60)
  self.laeuft, self.finale, self.feuerwerk, self.knall = true, nil, nil, nil
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

function SH:Beenden()
  self.laeuft, self.finale, self.feuerwerk = false, nil, nil
  if self.rahmen then
    self:Freunde(false)
    for _, t in ipairs(self.teilchen) do t.aktiv = false t:Hide() end
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
