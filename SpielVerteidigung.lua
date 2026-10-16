-- Lagerverteidigung: Das Lager steht links, Murlocs kommen in fünf Wellen auf drei Bahnen von
-- rechts, in der letzten Welle mit King Mrgl. Mit Glut baut der Spieler auf die Felder vor dem
-- Lager: Feuertotem (schießt, hält Murlocs auf), Frosttotem (bremst), Bombenfalle (explodiert,
-- wenn ein Murloc darüberläuft). Ein zweiter Klick auf ein Totem wertet es auf, danach repariert er.
-- Murlocs bleiben an Totems stehen und knabbern sie an. Ein Klick auf einen Murloc haut ihn (Bonk).
-- Besiegte Murlocs lassen manchmal Glut fallen, die man anklicken kann. Erreicht ein Murloc das
-- Lager, ist ein Leben weg. Alle Wellen geschafft: Bonus für jedes übrige Leben.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba
local SP = ns.Spiel

local BAHNEN, SPALTEN = 3, 4
local FELD = 36
local BAHN_Y = { -52, -100, -148 }
local LAGER_X = 30                      -- erreicht ein Murloc diese Stelle, ist ein Leben weg
local START_X = SP.BREITE - 14
local FELD_X0, FELD_ABSTAND = 52, 46    -- Mitte des ersten Felds, Abstand der Felder
local START_GLUT, LEBEN = 6, 3
local AUFWERTEN, REPARIEREN = 4, 1
local MAX_FEINDE, MAX_SCHUESSE, MAX_FUNKEN, MAX_GLUT, MAX_KNALL = 16, 24, 36, 4, 3
local KOPF = "Interface\\Icons\\INV_Misc_Head_Murloc_01"
local RAND = { 0.3, 0.22, 0.16, 0.8 }
local ROT, GRUEN, GOLD = { 0.94, 0.38, 0.35, 1 }, { 0.4, 0.84, 0.56, 1 }, { 1, 0.84, 0.25, 1 }

-- Totems: Kosten, Bild, Schusstakt, Lebenspunkte. Stufe II schießt schneller und hält mehr aus.
local TURM = {
  feuer = { kosten = 3, bild = "Interface\\Icons\\Spell_Fire_SearingTotem", takt = 1.1, hp = 3,
    schuss = { 1, 0.55, 0.15, 1 }, name = L.DEFENSE_FIRE, info = L.DEFENSE_FIRE_INFO },
  frost = { kosten = 4, bild = "Interface\\Icons\\Spell_FrostResistanceTotem_01", takt = 1.5, hp = 3, bremse = true,
    schuss = { 0.5, 0.8, 1, 1 }, name = L.DEFENSE_FROST, info = L.DEFENSE_FROST_INFO },
  falle = { kosten = 2, bild = "Interface\\Icons\\INV_Misc_Bomb_02", falle = true,
    name = L.DEFENSE_TRAP, info = L.DEFENSE_TRAP_INFO },
}
local TURM_REIHE = { "feuer", "frost", "falle" }

-- Murlocs: Lebenspunkte, Tempo (Pixel pro Sekunde), Größe, Biss gegen Totems, Punkte, Farbe
local FEINDE = {
  murloc = { hp = 2, tempo = { 15, 21 }, groesse = 26, biss = 1, punkte = 1, farbe = { 1, 1, 1 } },
  flitzer = { hp = 1, tempo = { 32, 38 }, groesse = 20, biss = 1, punkte = 1, farbe = { 1, 0.85, 0.35 } },
  brocken = { hp = 6, tempo = { 9, 11 }, groesse = 34, biss = 2, punkte = 3, farbe = { 0.55, 0.75, 1 } },
  koenig = { hp = 24, tempo = { 7, 7 }, groesse = 42, biss = 3, punkte = 15, farbe = { 1, 0.82, 0.3 }, boss = true },
}

local WELLEN = {
  { murloc = 6, takt = 1.7 },
  { murloc = 6, flitzer = 4, takt = 1.4 },
  { murloc = 6, flitzer = 3, brocken = 2, takt = 1.3 },
  { murloc = 8, flitzer = 5, brocken = 3, takt = 1.1 },
  { murloc = 6, flitzer = 4, brocken = 2, koenig = 1, takt = 1.0 },
}

local V = { key = "verteidigung", name = L.GAME_DEFENSE, info = L.GAME_DEFENSE_INFO,
  icon = "Interface\\Icons\\Spell_Fire_TotemOfWrath", dauer = 240, WELLEN = WELLEN }

local function platz(obj, x, y)
  obj:ClearAllPoints()
  obj:SetPoint("CENTER", V.r, "TOPLEFT", x, y)
end

-- Aufbau -------------------------------------------------------------------------------------

local function feldTipp(feld)
  local t = feld.turm and TURM[feld.turm]
  GameTooltip:SetOwner(feld, "ANCHOR_RIGHT")
  if not t then
    local neu = TURM[V.wahl or "feuer"]
    GameTooltip:SetText(neu.name, 1, 1, 1)
    GameTooltip:AddLine(neu.info, F.leise[1], F.leise[2], F.leise[3], true)
  else
    GameTooltip:SetText(t.name .. (feld.level == 2 and " II" or ""), 1, 1, 1)
    if not t.falle then
      GameTooltip:AddLine(string.format(L.DEFENSE_TIP_HP, feld.hp, feld.maxHp), F.leise[1], F.leise[2], F.leise[3])
      local zeile = feld.level < 2 and string.format(L.DEFENSE_TIP_UPGRADE, AUFWERTEN)
        or (feld.hp < feld.maxHp and string.format(L.DEFENSE_TIP_REPAIR, REPARIEREN))
      if zeile then GameTooltip:AddLine(zeile, F.akzent[1], F.akzent[2], F.akzent[3]) end
    end
  end
  GameTooltip:Show()
end

function V:Bauen(r)
  self.r = r
  for b = 1, BAHNEN do
    local bahn = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    bahn:SetSize(SP.BREITE - 8, FELD + 8)
    bahn:SetPoint("LEFT", r, "TOPLEFT", 4, BAHN_Y[b])
    bahn:SetColorTexture(0.10, 0.08, 0.06, 0.85)
  end
  -- Lager mit Feuerschein
  self.lagerSchein = S.kreis(r, 64, 64, { 1, 0.5, 0.15, 1 }, "BORDER", true)
  self.lagerSchein:SetPoint("CENTER", r, "TOPLEFT", 16, BAHN_Y[2])
  self.lager = r:CreateTexture(nil, "ARTWORK")
  self.lager:SetSize(34, 34)
  S.feuer(self.lager)
  platz(self.lager, 16, BAHN_Y[2])

  -- Kopfzeile: Stand links, Totem-Wahl rechts
  self.anzeige = S.schrift(r, "GameFontHighlightSmall", F.text)
  self.anzeige:SetPoint("TOPLEFT", 6, -9)
  self.wahlKnoepfe = {}
  for i, art in ipairs(TURM_REIHE) do
    local t = TURM[art]
    local k = S.kasten(r, "Button", F.flaeche, F.rand)
    k:SetSize(24, 24)
    k:SetPoint("TOPRIGHT", -4 - (#TURM_REIHE - i) * 28, -3)
    k.icon = k:CreateTexture(nil, "ARTWORK")
    k.icon:SetPoint("TOPLEFT", 2, -2)
    k.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    k.icon:SetTexture(t.bild)
    k.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    k.kosten = S.schrift(k, "NumberFontNormal", F.text)
    k.kosten:SetPoint("BOTTOMRIGHT", 2, -2)
    k.kosten:SetText(tostring(t.kosten))
    k.art = art
    k:SetScript("OnClick", function() V:Waehlen(art) end)
    S.tooltip(k, t.name, t.info)
    self.wahlKnoepfe[i] = k
  end
  self.text = S.schrift(r, "GameFontHighlightSmall", F.akzent)
  self.text:SetPoint("BOTTOM", 0, 3)

  -- Felder vor dem Lager: vier Spalten je Bahn
  self.felder = {}
  for b = 1, BAHNEN do
    for s = 1, SPALTEN do
      local feld = S.kasten(r, "Button", { 0.15, 0.12, 0.10, 0.6 }, RAND)
      feld:SetSize(FELD, FELD)
      feld.x, feld.bahn = FELD_X0 + (s - 1) * FELD_ABSTAND, b
      feld:SetPoint("CENTER", r, "TOPLEFT", feld.x, BAHN_Y[b])
      feld.bild = feld:CreateTexture(nil, "ARTWORK")
      feld.bild:SetPoint("TOPLEFT", 3, -3)
      feld.bild:SetPoint("BOTTOMRIGHT", -3, 3)
      feld.bild:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      feld.bild:Hide()
      feld.leben = feld:CreateTexture(nil, "OVERLAY")
      feld.leben:SetHeight(3)
      feld.leben:SetPoint("BOTTOMLEFT", 2, 2)
      feld.leben:SetColorTexture(1, 0.6, 0.2, 1)
      feld.leben:Hide()
      feld.stufe = S.schrift(feld, "GameFontNormalSmall", GOLD)
      feld.stufe:SetPoint("TOPRIGHT", -2, -1)
      feld.level, feld.hp, feld.maxHp = 0, 0, 1
      feld:HookScript("OnEnter", function(self) S.randFarbe(self, F.akzent) feldTipp(self) end)
      feld:HookScript("OnLeave", function(self) S.randFarbe(self, RAND) GameTooltip:Hide() end)
      feld:SetScript("OnClick", function(self) V:FeldKlick(self) end)
      table.insert(self.felder, feld)
    end
  end

  -- Murlocs, Schüsse, Funken und Glut liegen auf einer eigenen Ebene über den Feldern
  local oben = CreateFrame("Frame", nil, r)
  oben:SetAllPoints()
  local ebene = ((r.GetFrameLevel and r:GetFrameLevel()) or 1) + 20
  oben:SetFrameLevel(ebene)
  self.oben = oben
  self.feinde, self.schuesse, self.funken, self.glutStuecke, self.knalle = {}, {}, {}, {}, {}
  for i = 1, MAX_FEINDE do
    local f = CreateFrame("Button", nil, oben)
    f:SetSize(26, 26)
    f.kopf = f:CreateTexture(nil, "ARTWORK")
    f.kopf:SetAllPoints()
    f.kopf:SetTexture(KOPF)
    f.leben = f:CreateTexture(nil, "OVERLAY")
    f.leben:SetHeight(3)
    f.leben:SetPoint("BOTTOMLEFT", 0, -4)
    f.leben:SetColorTexture(0.3, 1, 0.3, 1)
    f:SetScript("OnClick", function(self) V:Bonk(self) end)
    f:Hide()
    self.feinde[i] = f
  end
  for i = 1, MAX_SCHUESSE do
    local s = S.kreis(oben, 9, 9, { 1, 0.55, 0.15, 1 }, "OVERLAY", true)
    s:Hide()
    self.schuesse[i] = s
  end
  for i = 1, MAX_FUNKEN do
    local p = oben:CreateTexture(nil, "OVERLAY")
    p:SetSize(3, 3)
    p:SetTexture(S.WEISS)
    p:Hide()
    self.funken[i] = p
  end
  for i = 1, MAX_KNALL do
    local k = S.kreis(oben, 10, 10, { 1, 0.6, 0.2, 1 }, "OVERLAY", true)
    k:Hide()
    self.knalle[i] = k
  end
  for i = 1, MAX_GLUT do
    local g = CreateFrame("Button", nil, oben)
    g:SetSize(20, 20)
    g:SetFrameLevel(ebene + 5)
    g.schein = S.kreis(g, 20, 20, { 1, 0.5, 0.15, 1 }, "ARTWORK", true)
    g.schein:SetPoint("CENTER")
    g.kern = S.kreis(g, 8, 8, { 1, 0.95, 0.6, 1 }, "OVERLAY", true)
    g.kern:SetPoint("CENTER")
    g:SetScript("OnClick", function(self) V:GlutSammeln(self) end)
    S.tooltip(g, L.DEFENSE_EMBER_DROP, nil)
    g:Hide()
    self.glutStuecke[i] = g
  end
  self.bossName = S.schrift(oben, "GameFontNormalSmall", GOLD)
  self.bossName:Hide()
  self.banner = S.schrift(oben, "GameFontNormalHuge", GOLD)
  self.banner:SetPoint("CENTER", r, "TOPLEFT", SP.BREITE / 2, -96)
end

-- Anzeige ------------------------------------------------------------------------------------

function V:Anzeigen()
  self.anzeige:SetText(string.format(L.DEFENSE_STATUS, self.glut, self.lebenRest, math.max(1, self.welle), #WELLEN))
  for _, k in ipairs(self.wahlKnoepfe) do
    S.randFarbe(k, k.art == self.wahl and F.akzent or F.rand)
    k.icon:SetDesaturated(self.glut < TURM[k.art].kosten)
  end
end

function V:Hinweis(text, farbe)
  self.text:SetText(text or "")
  self.text:SetTextColor(rgba(farbe or F.akzent))
end

function V:Banner(text, dauer)
  self.banner:SetText(text)
  self.banner:SetAlpha(1)
  self.bannerBis = ns.jetzt() + (dauer or 1.8)
end

local function feldAnzeigen(feld)
  local t = feld.turm and TURM[feld.turm]
  feld.bild:SetShown(t ~= nil)
  feld.leben:SetShown(t ~= nil and not t.falle)
  feld.stufe:SetText(feld.level == 2 and "II" or "")
  if t then
    feld.bild:SetTexture(t.bild)
    if not t.falle then feld.leben:SetWidth(math.max(1, (FELD - 4) * feld.hp / feld.maxHp)) end
  end
end

-- Runde --------------------------------------------------------------------------------------

function V:Start()
  local jetzt = ns.jetzt()
  self.glut, self.lebenRest, self.welle = START_GLUT, LEBEN, 0
  self.wahl = self.wahl or "feuer"
  self.glutZeit = jetzt + 2.5
  self.phase, self.phaseBis = "pause", jetzt + 2.5
  self.warteschlange, self.gebaut, self.wackelnBis = {}, false, nil
  for _, feld in ipairs(self.felder) do
    feld.turm, feld.level, feld.hp, feld.maxHp = nil, 0, 0, 1
    feldAnzeigen(feld)
  end
  self:Stop()
  self.banner:SetText("")
  self.bannerBis = nil
  self:Hinweis(L.DEFENSE_HINT)
  self:Anzeigen()
end

function V:Waehlen(art)
  if not TURM[art] then return end
  self.wahl = art
  S.klick()
  self:Anzeigen()
end

-- Klick auf ein Feld: leer = bauen, eigenes Totem = aufwerten, danach reparieren
function V:FeldKlick(feld)
  if not (SP.laeuft and SP.aktiv == self) then return end
  local t = feld.turm and TURM[feld.turm]
  if not t then
    local neu = TURM[self.wahl]
    if self.glut < neu.kosten then return self:Hinweis(string.format(L.DEFENSE_NEED, neu.kosten), ROT) end
    self.glut = self.glut - neu.kosten
    feld.turm, feld.level, feld.schuss = self.wahl, 1, ns.jetzt() + 0.4
    feld.maxHp = neu.hp or 1
    feld.hp = feld.maxHp
    ns.ton("plopp")
    if not self.gebaut then
      self.gebaut = true
      self:Hinweis(L.DEFENSE_HINT2)
    end
  elseif t.falle then
    return
  elseif feld.level < 2 then
    if self.glut < AUFWERTEN then return self:Hinweis(string.format(L.DEFENSE_NEED, AUFWERTEN), ROT) end
    self.glut = self.glut - AUFWERTEN
    feld.level, feld.maxHp = 2, t.hp + 2
    feld.hp = feld.maxHp
    SP:Ruf(L.DEFENSE_UPGRADE, feld.x, BAHN_Y[feld.bahn] + 24, GOLD)
    ns.ton("paar")
  elseif feld.hp < feld.maxHp then
    if self.glut < REPARIEREN then return self:Hinweis(string.format(L.DEFENSE_NEED, REPARIEREN), ROT) end
    self.glut = self.glut - REPARIEREN
    feld.hp = feld.maxHp
    SP:Ruf(L.DEFENSE_REPAIR, feld.x, BAHN_Y[feld.bahn] + 24, GRUEN)
    ns.ton("plopp")
  else
    return self:Hinweis(L.DEFENSE_MAX, F.leise)
  end
  feldAnzeigen(feld)
  self:Anzeigen()
end

local function mischen(t)
  for i = #t, 2, -1 do
    local j = math.random(1, i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end

function V:WelleStarten(jetzt)
  self.welle = self.welle + 1
  local w = WELLEN[self.welle]
  local liste = {}
  for _, art in ipairs({ "murloc", "flitzer", "brocken" }) do
    for _ = 1, w[art] or 0 do table.insert(liste, art) end
  end
  mischen(liste)
  if w.koenig then
    table.insert(liste, math.min(3, #liste + 1), "koenig")
    self:Banner(L.DEFENSE_BOSS, 2.2)
    ns.ton("boom")
    ns.mrgl()
  else
    self:Banner(string.format(L.DEFENSE_WAVE, self.welle))
    ns.ton("start")
  end
  self.warteschlange, self.takt, self.naechster = liste, w.takt, jetzt + 0.8
  self.phase, self.lebenVorher = "welle", self.lebenRest
  self:Anzeigen()
end

function V:FeindeDa()
  for _, f in ipairs(self.feinde) do if f.aktiv then return true end end
  return false
end

-- Einen Murloc auf eine Bahn setzen. false: gerade kein Platz frei
function V:Feind(art)
  local d = FEINDE[art]
  for _, f in ipairs(self.feinde) do
    if not f.aktiv then
      local extra = d.boss and 0 or math.floor((math.max(1, self.welle) - 1) / 2)
      f.aktiv, f.d = true, d
      f.bahn = d.boss and 2 or math.random(1, BAHNEN)
      f.x = START_X
      f.max = d.hp + extra
      f.hp = f.max
      f.tempo = SP.zufall(d.tempo[1], d.tempo[2])
      f.biss, f.langsamBis, f.blitzBis = 0, 0, 0
      f.groesse = d.groesse
      f:SetSize(d.groesse, d.groesse)
      f.leben:SetWidth(d.groesse)
      f.kopf:SetVertexColor(d.farbe[1], d.farbe[2], d.farbe[3])
      platz(f, f.x, BAHN_Y[f.bahn])
      f:Show()
      if d.boss then
        self.bossName:ClearAllPoints()
        self.bossName:SetPoint("BOTTOM", f, "TOP", 0, 3)
        self.bossName:SetText(L.DEFENSE_BOSS_NAME)
        self.bossName:Show()
      elseif math.random(1, 4) == 1 then
        SP:Ruf(SP.spruch(L.MURLOC_LINES), START_X - 30, BAHN_Y[f.bahn] + 16, GRUEN)
        ns.mrgl(0.5)
      end
      return true
    end
  end
  return false
end

-- Treffer, Bonk, Ende eines Murlocs ----------------------------------------------------------

function V:Treffen(f, schaden, jetzt)
  if not f.aktiv then return end
  f.hp = f.hp - schaden
  f.blitzBis = jetzt + 0.12
  f.leben:SetWidth(math.max(1, f.groesse * f.hp / f.max))
  if f.hp <= 0 then self:Besiegt(f) end
end

function V:Besiegt(f)
  f.aktiv = false
  f:Hide()
  local d = f.d
  local y = BAHN_Y[f.bahn]
  SP:Plus(d.punkte)
  SP:Ruf("+" .. d.punkte, f.x, y + 14, d.boss and GOLD or nil)
  self.glut = self.glut + 1
  self:Puff(f.x, y, d.boss and 30 or 6, d.farbe)
  if d.boss then
    self.bossName:Hide()
    self:Banner(L.DEFENSE_BOSS_DOWN, 1.6)
    ns.ton("paar")
    ns.mrgl()
  else
    ns.ton("treffer")
  end
  if d.boss or math.random() < 0.3 then self:GlutFallen(f.x, y) end
  self:Anzeigen()
end

function V:Bonk(f)
  if not (SP.laeuft and SP.aktiv == self and f.aktiv) then return end
  if not f.d.boss then f.x = math.min(START_X, f.x + 6) end
  if math.random(1, 3) == 1 then SP:Ruf(SP.spruch(L.DEFENSE_BONK), f.x, BAHN_Y[f.bahn] + 20, F.text) end
  ns.ton("plopp")
  self:Treffen(f, 1, ns.jetzt())
end

-- Glut, die ein besiegter Murloc fallen lässt: 5 Sekunden lang anklickbar
function V:GlutFallen(x, y)
  for _, g in ipairs(self.glutStuecke) do
    if not g.bis then
      g.bis, g.x, g.y = ns.jetzt() + 5, x, y + 6
      platz(g, g.x, g.y)
      g:Show()
      return g
    end
  end
end

function V:GlutSammeln(g)
  if not (SP.laeuft and SP.aktiv == self and g.bis) then return end
  g.bis = nil
  g:Hide()
  self.glut = self.glut + 2
  SP:Ruf(L.DEFENSE_EMBER, g.x, g.y + 14, GOLD)
  ns.ton("muenze")
  self:Anzeigen()
end

-- Kleine Teilchen, die aus einem Punkt fliegen
function V:Puff(x, y, n, farbe)
  local jetzt = ns.jetzt()
  for _, p in ipairs(self.funken) do
    if n <= 0 then break end
    if not p.bis then
      local w, v = SP.zufall(0, 2 * math.pi), SP.zufall(30, 75)
      p.x, p.y, p.vx, p.vy, p.bis = x, y, math.cos(w) * v, math.sin(w) * v, jetzt + 0.45
      p:SetVertexColor(farbe[1], farbe[2], farbe[3], 1)
      p:Show()
      n = n - 1
    end
  end
end

-- Bombenfalle: drei Schaden an allen Murlocs der Bahn in der Nähe, das Feld wird wieder frei
function V:Falle(feld, jetzt)
  feld.turm, feld.level = nil, 0
  feldAnzeigen(feld)
  local y = BAHN_Y[feld.bahn]
  for _, k in ipairs(self.knalle) do
    if not k.bis then
      k.x, k.y, k.bis = feld.x, y, jetzt + 0.35
      k:Show()
      break
    end
  end
  self:Puff(feld.x, y, 10, { 1, 0.6, 0.2 })
  SP:Ruf(L.WHACK_BOOM, feld.x, y + 24, ROT)
  ns.ton("boom")
  for _, f in ipairs(self.feinde) do
    if f.aktiv and f.bahn == feld.bahn and math.abs(f.x - feld.x) < 46 then self:Treffen(f, 3, jetzt) end
  end
end

-- Totem direkt vor einem Murloc in seiner Bahn (links von ihm, berührt ihn)? Fallen halten nicht auf.
function V:Hindernis(f)
  for _, feld in ipairs(self.felder) do
    local t = feld.turm and TURM[feld.turm]
    if t and not t.falle and feld.bahn == f.bahn and f.x > feld.x and f.x - feld.x < (FELD + f.groesse) / 2 - 2 then
      return feld
    end
  end
end

-- Ein Murloc erreicht das Lager. true: alle Leben weg, Spiel vorbei
function V:LagerTreffer(f, jetzt)
  f.aktiv = false
  f:Hide()
  if f.d.boss then self.bossName:Hide() end
  self.lebenRest = math.max(0, self.lebenRest - (f.d.boss and 3 or 1))
  self.wackelnBis = jetzt + 0.4
  SP:Ruf(L.DEFENSE_OUCH, LAGER_X + 8, BAHN_Y[2] + 26, ROT)
  ns.ton("umfallen")
  ns.mrgl()
  self:Anzeigen()
  if self.lebenRest <= 0 then
    self:Hinweis(L.DEFENSE_LOST, ROT)
    SP:Fertig(L.DEFENSE_LOST)
    return true
  end
end

-- Jedes Bild ---------------------------------------------------------------------------------

function V:Tick(dt, jetzt)
  -- Glut mit der Zeit
  if jetzt >= self.glutZeit then
    self.glut, self.glutZeit = self.glut + 1, jetzt + 2.5
    self:Anzeigen()
  end

  -- Wellen: Pause, dann Murlocs nacheinander. Alle besiegt: Bonus und nächste Welle
  if self.phase == "pause" and jetzt >= self.phaseBis then
    self:WelleStarten(jetzt)
  elseif self.phase == "welle" then
    if #self.warteschlange > 0 and jetzt >= self.naechster then
      if self:Feind(self.warteschlange[1]) then table.remove(self.warteschlange, 1) end
      self.naechster = jetzt + self.takt
    elseif #self.warteschlange == 0 and not self:FeindeDa() then
      local perfekt = self.lebenRest == self.lebenVorher
      local bonus = 2 + self.welle + (perfekt and 3 or 0)
      SP:Plus(bonus)
      self.glut = self.glut + 3
      if self.welle >= #WELLEN then
        SP:Plus(self.lebenRest * 5)
        self:Banner(L.DEFENSE_WON, 3)
        self:Hinweis(L.DEFENSE_WON, GRUEN)
        ns.mrgl()
        return SP:Fertig(L.DEFENSE_WON)
      end
      self:Banner(string.format(perfekt and L.DEFENSE_PERFECT or L.DEFENSE_CLEARED, bonus), 1.6)
      ns.ton(perfekt and "paar" or "treffer")
      self.phase, self.phaseBis = "pause", jetzt + 3
      self:Anzeigen()
    end
  end

  -- Totems schießen, wenn in ihrer Bahn rechts von ihnen ein Murloc ist
  for _, feld in ipairs(self.felder) do
    local t = feld.turm and TURM[feld.turm]
    if t and not t.falle and jetzt >= feld.schuss then
      local ziel = false
      for _, f in ipairs(self.feinde) do
        if f.aktiv and f.bahn == feld.bahn and f.x > feld.x then ziel = true break end
      end
      if ziel then
        for _, s in ipairs(self.schuesse) do
          if not s.aktiv then
            s.aktiv, s.bahn, s.x = true, feld.bahn, feld.x + 14
            s.bremse = t.bremse and (feld.level == 2 and 3.5 or 2.5) or nil
            s.schaden = (not t.bremse and feld.level == 2) and 2 or 1
            s:SetVertexColor(t.schuss[1], t.schuss[2], t.schuss[3], 1)
            s:Show()
            break
          end
        end
        feld.schuss = jetzt + t.takt * (feld.level == 2 and 0.65 or 1)
      end
    end
  end

  -- Schüsse fliegen nach rechts und treffen den ersten Murloc
  for _, s in ipairs(self.schuesse) do
    if s.aktiv then
      s.x = s.x + 160 * dt
      platz(s, s.x, BAHN_Y[s.bahn])
      for _, f in ipairs(self.feinde) do
        if f.aktiv and f.bahn == s.bahn and math.abs(f.x - s.x) < f.groesse / 2 then
          s.aktiv = false
          s:Hide()
          if s.bremse then f.langsamBis = jetzt + s.bremse end
          self:Treffen(f, s.schaden, jetzt)
          break
        end
      end
      if s.aktiv and s.x > SP.BREITE then s.aktiv = false s:Hide() end
    end
  end

  -- Murlocs laufen nach links. Steht ein Totem im Weg, knabbern sie es an.
  for _, f in ipairs(self.feinde) do
    if f.aktiv then
      local feld = self:Hindernis(f)
      local zx, hopp = f.x, 0
      if feld then
        if jetzt >= f.biss then
          f.biss = jetzt + 1
          feld.hp = feld.hp - f.d.biss
          if feld.hp <= 0 then
            feld.turm, feld.level = nil, 0
            SP:Ruf(L.DEFENSE_CRUNCH, feld.x, BAHN_Y[feld.bahn] + 16, ROT)
            ns.ton("minus")
          end
          feldAnzeigen(feld)
        end
        zx = f.x + math.sin(jetzt * 18) * 1.5   -- zappelt beim Knabbern
      else
        local tempo = f.tempo * (jetzt < f.langsamBis and 0.45 or 1)
        f.x = f.x - tempo * dt
        zx = f.x
        hopp = math.abs(math.sin(jetzt * (f.d.boss and 5 or 10) + f.bahn)) * (f.d.boss and 3 or 2)
        for _, fe in ipairs(self.felder) do
          if fe.turm == "falle" and fe.bahn == f.bahn and math.abs(f.x - fe.x) < 10 then self:Falle(fe, jetzt) end
        end
      end
      if f.aktiv then
        if jetzt < f.blitzBis then
          f.kopf:SetVertexColor(1, 0.4, 0.4)
        elseif jetzt < f.langsamBis then
          f.kopf:SetVertexColor(0.5, 0.75, 1)
        else
          f.kopf:SetVertexColor(f.d.farbe[1], f.d.farbe[2], f.d.farbe[3])
        end
        platz(f, zx, BAHN_Y[f.bahn] + hopp)
        if f.x <= LAGER_X and self:LagerTreffer(f, jetzt) then return end
      end
    end
  end

  -- Teilchen, Knall, Glut, Banner, Lager
  for _, p in ipairs(self.funken) do
    if p.bis then
      local rest = p.bis - jetzt
      if rest <= 0 then
        p.bis = nil
        p:Hide()
      else
        p.vy = p.vy - 120 * dt
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        p:SetAlpha(rest / 0.45)
        platz(p, p.x, p.y)
      end
    end
  end
  for _, k in ipairs(self.knalle) do
    if k.bis then
      local rest = (k.bis - jetzt) / 0.35
      if rest <= 0 then
        k.bis = nil
        k:Hide()
      else
        local g = 10 + (1 - rest) * 80
        k:SetSize(g, g)
        k:SetAlpha(rest)
        platz(k, k.x, k.y)
      end
    end
  end
  for _, g in ipairs(self.glutStuecke) do
    if g.bis then
      if jetzt >= g.bis then
        g.bis = nil
        g:Hide()
      else
        g.schein:SetAlpha(0.55 + 0.45 * math.abs(math.sin(jetzt * 6)))
      end
    end
  end
  if self.bannerBis then
    local rest = self.bannerBis - jetzt
    if rest <= 0 then
      self.bannerBis = nil
      self.banner:SetText("")
    else
      self.banner:SetAlpha(math.min(1, rest * 2))
    end
  end
  self.lagerSchein:SetAlpha(0.35 + 0.2 * math.sin(jetzt * 7) * math.sin(jetzt * 2.3))
  local dx = 0
  if self.wackelnBis then
    if jetzt < self.wackelnBis then dx = math.sin(jetzt * 60) * 3 else self.wackelnBis = nil end
  end
  platz(self.lager, 16 + dx, BAHN_Y[2])
end

function V:Stop()
  for _, f in ipairs(self.feinde or {}) do f.aktiv = false f:Hide() end
  for _, s in ipairs(self.schuesse or {}) do s.aktiv = false s:Hide() end
  for _, p in ipairs(self.funken or {}) do p.bis = nil p:Hide() end
  for _, k in ipairs(self.knalle or {}) do k.bis = nil k:Hide() end
  for _, g in ipairs(self.glutStuecke or {}) do g.bis = nil g:Hide() end
  if self.bossName then self.bossName:Hide() end
end

SP.Registrieren(V)
