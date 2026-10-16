-- Whack-a-Murloc: Murlocs steigen aus sechs Erdlöchern einer Waldwiese. Klick: ein Punkt, goldener
-- Murloc drei. Aber Vorsicht: Bomben (-3, BOOM) und das Schaf (-2) lieber nicht anklicken. Eine
-- Legende unter der Wiese zeigt die Punkte.
-- Je mehr Punkte, desto kürzer bleiben sie. Murlocs rufen beim Auftauchen und Treffen.
--
-- Die Wiese ist eine Blender-Szene (Media/Wiese.tga aus grafik/blender/wiese.py, Lage der Löcher in
-- Wiese.lua). Die Murlocs sind echte Modelle aus dem Spiel wie in der Show: Murky (15369), der
-- goldene ist Murky in goldenem Licht. Das Schaf (856, das Schaf der Verwandlung, sonst Hase 328)
-- ist klar anders als die Murlocs (rosa Babys waren nicht zu unterscheiden). Damit sie aus dem Loch
-- steigen, liegt unter jedem Loch ein Stück derselben Wiese über dem Modell: Was unterhalb des
-- vorderen Erdwalls ist, verschwindet dahinter. Die hintere Reihe liegt unter der vorderen.
-- Lädt kein Modell, steigt der Murloc-Kopf als Symbol auf, die Bombe ist immer ein Bild.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F = S.F
local SP = ns.Spiel

local KOPF = "Interface\\Icons\\INV_Misc_Head_Murloc_01"
local BOMBE = "Interface\\Icons\\INV_Misc_Bomb_02"
local SCHAF_SYMBOL = "Interface\\Icons\\Spell_Nature_Polymorph"
local MURKY, SCHAF, HASE, ERSATZ = 15369, 856, 328, 31
local ARTEN = {
  { art = "murloc", gewicht = 70, wert = 1, modell = "murky", farbe = { 1, 1, 1 } },
  { art = "gold", gewicht = 9, wert = 3, modell = "murky", farbe = { 1, 0.84, 0.25 }, licht = "gold" },
  { art = "bombe", gewicht = 12, wert = -3, bombe = true, farbe = { 1, 1, 1 } },
  { art = "baby", gewicht = 9, wert = -2, modell = "schaf", farbe = { 1, 1, 1 }, symbol = SCHAF_SYMBOL },
}
local ROT, GRUEN = { 0.94, 0.38, 0.35, 1 }, { 0.4, 0.84, 0.56, 1 }
local AUF, AB = 0.16, 0.14     -- Sekunden zum Auftauchen und Abtauchen
local SICHTBAR = 0.7           -- dieser Teil des Modells ragt oben aus dem Loch
-- Rahmen des Modells größer als der Murloc, Kamera im selben Maß weiter weg: gleiche Größe, aber
-- Luft rundum. Sonst schneidet der Rahmen Arme und Flossen beim Winken ab (Patrick, 16. Okt).
local RAND = 1.4
local HUB = 0.42               -- so weit (Anteil der Größe) taucht die Figur ab
-- Animationen beim Auftauchen (stehen, brüllen, winken, lachen) und beim Treffer, mit Ersatz
local POP_ANIM = { { 0 }, { 74, 55, 0 }, { 67, 60, 0 }, { 70, 60, 0 } }
local TREFFER_ANIM = { 9, 10, 1, 0 }

local W = { key = "whack", musik = "mayhem", name = L.GAME_WHACK, info = L.GAME_WHACK_INFO,
  icon = "Interface\\Icons\\INV_BabyMurloc3_Yellow", dauer = 30,
  legende = {
    { bild = KOPF, punkte = 1 },
    { bild = KOPF, farbe = { 1, 0.84, 0.25 }, punkte = 3 },
    { bild = SCHAF_SYMBOL, punkte = -2 },
    { atlas = "bombe", bild = BOMBE, punkte = -3 },
  } }

local function ziehen()
  local summe = 0
  for _, a in ipairs(ARTEN) do summe = summe + a.gewicht end
  local w = math.random() * summe
  for _, a in ipairs(ARTEN) do
    w = w - a.gewicht
    if w <= 0 then return a end
  end
  return ARTEN[1]
end

-- Modelle --------------------------------------------------------------------------------------

-- Licht wie in der Show: kühles Mondlicht als Grundlicht, warmes Feuerlicht dazu. Gold färbt das
-- Licht des goldenen Murlocs.
local LICHT = {
  normal = { amb = { 0.66, 0.7, 0.92 }, ai = 0.8, dif = { 1, 0.74, 0.46 }, di = 0.85 },
  gold = { amb = { 1, 0.8, 0.32 }, ai = 1.0, dif = { 1, 0.86, 0.4 }, di = 1.1 },
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

local function modell(r, groesse, ebene, display, ersatzId)
  local ok, m = pcall(CreateFrame, "PlayerModel", nil, r)
  if not (ok and m and m.SetDisplayInfo) then return nil end
  m:SetSize(groesse * RAND, groesse * RAND)
  m:SetFrameLevel(ebene)
  -- sonst wirft das Modell beim Verstecken alles weg
  if m.SetKeepModelOnHide then pcall(m.SetKeepModelOnHide, m, true) end
  m.display, m.ersatzId = display, ersatzId
  pcall(m.SetDisplayInfo, m, display)
  local function kamera() if m.SetCamDistanceScale then pcall(m.SetCamDistanceScale, m, RAND) end end
  kamera()
  m:SetScript("OnModelLoaded", kamera)
  m:Hide()
  return m
end

-- Lädt ein Modell nicht, nimmt das Loch den Ersatz (Murky: großer Murloc, Schaf: Hase)
local function nachladen(m)
  if not m or geladen(m) then return end
  pcall(m.SetDisplayInfo, m, m.display)
  if C_Timer and C_Timer.After and m.ersatzId then
    C_Timer.After(0.6, function()
      if not geladen(m) and m.display ~= m.ersatzId then
        m.display, m.ersatz = m.ersatzId, true
        pcall(m.SetDisplayInfo, m, m.ersatzId)
      end
    end)
  end
end

-- Aufbau ---------------------------------------------------------------------------------------

-- Löcher aus Wiese.lua (0 bis 1) in Pixel der Spielfläche. Die ersten drei sind die hintere Reihe.
local function lage()
  local t = {}
  for i, l in ipairs(S.WIESE_LOECHER or {}) do
    local breite = l.breite * SP.BREITE
    t[i] = { mx = l.x * SP.BREITE, schnitt = l.schnitt * SP.HOEHE, v = math.floor(breite * 1.45 + 0.5), hinten = i <= 3 }
  end
  return t
end

function W:Bauen(r)
  self.r = r
  local basis = (r.GetFrameLevel and r:GetFrameLevel()) or 1
  local wiese = r:CreateTexture(nil, "BACKGROUND", nil, 2)
  wiese:SetAllPoints()
  wiese:SetTexture(S.WIESE)
  wiese:SetTexCoord(0, S.WIESE_B, 0, S.WIESE_H)
  self.loecher = {}
  for i, l in ipairs(lage()) do
    local ebene = basis + (l.hinten and 2 or 6)
    local b = CreateFrame("Button", nil, r)
    b.mx, b.schnitt, b.v = l.mx, l.schnitt, l.v
    b.my = -(l.schnitt - l.v * 0.55)
    -- Klickfläche: der Teil über dem vorderen Wall, über allem
    b:SetSize(l.v, l.v * SICHTBAR + 6)
    b:SetPoint("BOTTOM", r, "TOPLEFT", l.mx, -(l.schnitt + 6))
    b:SetFrameLevel(basis + 12)
    b:SetScript("OnClick", function(self) W:Treffer(self) end)
    -- Figuren: Murky und das Schaf als Modell, Bombe und Ersatz-Symbol als Bild in einer Hülle
    b.modelle = { murky = modell(r, l.v, ebene, MURKY, ERSATZ), schaf = modell(r, l.v, ebene, SCHAF, HASE) }
    b.huelle = CreateFrame("Frame", nil, r)
    b.huelle:SetSize(l.v, l.v)
    b.huelle:SetFrameLevel(ebene)
    b.huelle:Hide()
    b.bild = b.huelle:CreateTexture(nil, "ARTWORK")
    b.bild:SetPoint("BOTTOM", 0, l.v * (1 - SICHTBAR))
    -- Deckel: dasselbe Stück Wiese unter dem vorderen Wall, liegt über den Figuren
    local unten = math.min(SP.HOEHE, l.schnitt + l.v * (1 - SICHTBAR + HUB))
    local x0, x1 = l.mx - l.v * 0.65, l.mx + l.v * 0.65
    local deckel = CreateFrame("Frame", nil, r)
    deckel:SetAllPoints()
    deckel:SetFrameLevel(ebene + 1)
    local t = deckel:CreateTexture(nil, "ARTWORK")
    t:SetTexture(S.WIESE)
    t:SetPoint("TOPLEFT", r, "TOPLEFT", x0, -l.schnitt)
    t:SetPoint("BOTTOMRIGHT", r, "TOPLEFT", x1, -unten)
    t:SetTexCoord(x0 / SP.BREITE * S.WIESE_B, x1 / SP.BREITE * S.WIESE_B,
      l.schnitt / SP.HOEHE * S.WIESE_H, unten / SP.HOEHE * S.WIESE_H)
    self.loecher[i] = b
  end
end

-- Figur auf Höhe p setzen (0 im Loch, 1 ganz oben)
local function setze(b, p)
  local f = b.figur
  if not f then return end
  local unten = b.schnitt + b.v * (1 - SICHTBAR + HUB * (1 - p))
  -- Das Modell steht mittig im größeren Rahmen: Rahmen um den Rand tiefer, Füße bleiben gleich
  if b.dreiD then unten = unten + b.v * (RAND - 1) / 2 end
  f:ClearAllPoints()
  f:SetPoint("BOTTOM", W.r, "TOPLEFT", b.mx, -unten)
  local a = math.min(1, p * 3)
  f:SetAlpha(a)
  if b.dreiD and f.SetModelAlpha then pcall(f.SetModelAlpha, f, a) end
end

local function verstecken(b)
  if b.figur then b.figur:Hide() end
  b.figur, b.bis, b.weg = nil, nil, nil
end

function W:Start()
  self.naechster, self.serie = ns.jetzt() + 0.6, 0
  for _, b in ipairs(self.loecher) do
    verstecken(b)
    nachladen(b.modelle.murky)
    nachladen(b.modelle.schaf)
  end
end

-- Neue Figur in einem freien Loch
function W:Auftauchen(b, jetzt)
  local a = ziehen()
  b.art, b.seit, b.weg, b.dreiD = a, jetzt, nil, false
  b.bis = jetzt + math.max(0.55, 1.05 - (SP.punkte or 0) * 0.02)
  local m = a.modell and b.modelle[a.modell]
  if m and geladen(m) then
    b.figur, b.dreiD = m, true
    licht(m, a.licht)
    pcall(m.SetFacing, m, SP.zufall(-0.35, 0.35))
    anim(m, POP_ANIM[math.random(1, #POP_ANIM)])
  else
    b.figur = b.huelle
    local groesse = b.v * (a.klein and 0.5 or 0.64)
    b.bild:SetSize(groesse, groesse)
    b.bild:SetVertexColor(1, 1, 1)
    if a.bombe then
      if not S.atlas(b.bild, "bombe") then
        b.bild:SetTexture(BOMBE)
        b.bild:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      end
    else
      b.bild:SetTexture(a.symbol or KOPF)
      b.bild:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      b.bild:SetVertexColor(a.farbe[1], a.farbe[2], a.farbe[3])
    end
  end
  b.figur:Show()
  setze(b, 0)
  if a.art == "murloc" and math.random(1, 6) == 1 then
    SP:Ruf(SP.spruch(L.WHACK_POP), b.mx, b.my + 30, F.text)
    ns.mrgl()
  end
end

function W:Treffer(b)
  if not (SP.laeuft and SP.aktiv == self and b.bis) then return end
  local a = b.art
  SP:Plus(a.wert)
  -- Getroffen: kurz zusammenzucken, dann abtauchen
  b.bis = nil
  b.weg = ns.jetzt() + (b.dreiD and 0.22 or 0)
  if b.dreiD and b.figur then anim(b.figur, TREFFER_ANIM) end
  if a.art == "bombe" then
    self.serie = 0
    SP:Ruf(L.WHACK_BOOM, b.mx, b.my, ROT)
    ns.ton("boom")
  elseif a.art == "baby" then
    self.serie = 0
    SP:Ruf(SP.spruch(L.WHACK_BABY), b.mx, b.my, ROT)
    ns.ton("minus")
  else
    self.serie = self.serie + 1
    local text = "+" .. a.wert
    if self.serie > 0 and self.serie % 5 == 0 then text = SP.spruch(L.WHACK_STREAK) end
    SP:Ruf(text, b.mx, b.my, a.art == "gold" and { 1, 0.84, 0.25, 1 } or GRUEN)
    ns.ton(a.art == "gold" and "muenze" or (self.serie % 5 == 0 and "paar" or "treffer"))
    ns.mrgl(0.3)
  end
end

function W:Tick(_, jetzt)
  for _, b in ipairs(self.loecher) do
    if b.figur then
      if b.bis and jetzt >= b.bis then
        -- verpasst: abtauchen, ab und zu streckt er die Zunge raus
        b.bis, b.weg = nil, jetzt
        if b.art.wert > 0 and math.random(1, 4) == 1 then SP:Ruf(SP.spruch(L.WHACK_MISS), b.mx, b.my - 10, F.leise) end
      end
      local p
      if b.bis then
        p = math.min(1, (jetzt - b.seit) / AUF)
      else
        p = math.min(1, 1 - (jetzt - (b.weg or jetzt)) / AB)
      end
      if p <= 0 then verstecken(b) else setze(b, p) end
    end
  end
  if jetzt >= self.naechster then
    local frei = {}
    for _, b in ipairs(self.loecher) do if not b.figur then table.insert(frei, b) end end
    if #frei > 0 then self:Auftauchen(frei[math.random(1, #frei)], jetzt) end
    self.naechster = jetzt + SP.zufall(0.45, 0.9)
  end
end

function W:Stop()
  for _, b in ipairs(self.loecher or {}) do verstecken(b) end
end

SP.Registrieren(W)
