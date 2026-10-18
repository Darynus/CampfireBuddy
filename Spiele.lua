-- Spiele am Lagerfeuer: ein Fenster mit Menü und zehn kleinen Spielen für die Minute am Feuer
-- (und länger, wer mag). Reine Oberfläche: keine Spielaktion, keine Nachrichten, nur auf Klick.
-- Bei Kampfbeginn schließt sich alles. Rekorde je Spiel in CampfireBuddyDB.rekorde.
--
-- Ein Spiel meldet sich mit ns.Spiel.Registrieren({ ... }) an:
--   key, name, info, icon, dauer (Sekunden, nil = das Spiel endet selbst)
--   musik: Stück aus Musik.lua ("arcade", "mayhem", "teich", "rennen")
--   legende (optional): was gibt welche Punkte, unter der Spielfläche (SP:LegendeZeigen)
--   stufen (optional): { { wert, text, info, dauer, rekord }, ... } Wahl vor dem Start, die
--                        gewählte steht in self.stufe, rekord ist der Schlüssel für den Rekord
--   Bauen(self, rahmen)  einmal, rahmen ist die Spielfläche (BREITE x HOEHE)
--   Start(self)          jede Runde
--   Tick(self, dt, jetzt) jedes Bild, solange es läuft
--   Stop(self)           beim Ende (aufräumen)
-- Punkte: SP:Plus(n), Ende von innen: SP:Fertig(text). Runde geschafft, weiter mit neuer Zeit:
-- SP:Runde(text, weiter). Nach dem Ende bleibt das Ergebnis stehen, mit Play again und Games.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba

local SP = { liste = {}, spiele = {} }
ns.Spiel = SP

SP.BREITE, SP.HOEHE = 300, 190
local RAHMEN_B, RAHMEN_H = SP.BREITE + 20, SP.HOEHE + 70
local RUNDE_KUERZER, RUNDE_MINDESTENS = 5, 30   -- jede weitere Runde 5 Sekunden kürzer

function SP.Registrieren(spiel)
  table.insert(SP.liste, spiel)
  SP.spiele[spiel.key] = spiel
end

function SP.zufall(a, b) return a + math.random() * (b - a) end

local function rekord(key) return (ns.db.rekorde or {})[key] or 0 end

-- Schlüssel des Rekords: je Stufe eigener Rekord, wenn das Spiel Stufen hat
local function rekordKey(spiel) return spiel.stufe and spiel.stufe.rekord or spiel.key end

-- Zuletzt gewählte Stufe eines Spiels (sonst die erste)
local function letzteStufe(spiel)
  local wert = ns.db.stufen and ns.db.stufen[spiel.key]
  for _, s in ipairs(spiel.stufen or {}) do if s.wert == wert then return s end end
  return spiel.stufen and spiel.stufen[1]
end

-- Halbdunkle Fläche über dem Spiel mit Text und bis zu drei Knöpfen (Spielende, Rundenende,
-- Stufenwahl)
local function tafelBauen(bereich)
  local t = CreateFrame("Frame", nil, bereich)
  t:SetAllPoints()
  t:SetFrameLevel(((bereich.GetFrameLevel and bereich:GetFrameLevel()) or 1) + 30)
  t:EnableMouse(true)
  local grund = t:CreateTexture(nil, "BACKGROUND")
  grund:SetAllPoints()
  grund:SetColorTexture(0, 0, 0, 0.62)
  t.titel = S.schrift(t, "GameFontNormalLarge", F.akzent)
  t.titel:SetPoint("TOP", 0, -36)
  t.text = S.schrift(t, "GameFontHighlight", F.text)
  t.text:SetPoint("TOP", t.titel, "BOTTOM", 0, -8)
  t.text:SetWidth(SP.BREITE - 30)
  t.knoepfe = {}
  for i = 1, 3 do
    local b = S.textKnopf(t, "", 120, function(self) if self.aktion then self.aktion() end end)
    b:SetHeight(24)
    b.info = S.schrift(b, "GameFontHighlightSmall", F.leise)
    b.info:SetPoint("TOP", b, "BOTTOM", 0, -3)
    b.info:SetWordWrap(true)
    t.knoepfe[i] = b
  end
  t:Hide()
  return t
end

-- Tafel zeigen: knoepfe = { { text, info, aktion }, ... } nebeneinander in der Mitte. Die Knöpfe
-- werden so schmal, dass alle samt Zwischenraum in die Spielfläche passen (drei Stufen ragten mit
-- je 120 Punkten über den Rand, Patricks Screenshot 18. Okt).
local TAFEL_KNOPF, TAFEL_LUECKE, TAFEL_RAND = 120, 8, 8
function SP:Tafel(titel, text, knoepfe)
  local t = self.tafel
  t.titel:SetText(titel or "")
  t.text:SetText(text or "")
  local n = #knoepfe
  local breite = math.min(TAFEL_KNOPF, math.floor((SP.BREITE - 2 * TAFEL_RAND - (n - 1) * TAFEL_LUECKE) / math.max(1, n)))
  for i, b in ipairs(t.knoepfe) do
    local k = knoepfe[i]
    b:SetShown(k ~= nil)
    if k then
      b:SetWidth(breite)
      b.text:SetText(k.text)
      b.info:SetWidth(breite + TAFEL_LUECKE - 2)
      b.info:SetText(k.info or "")
      b.aktion = k.aktion
      b:ClearAllPoints()
      b:SetPoint("TOP", t, "TOP", (i - (n + 1) / 2) * (breite + TAFEL_LUECKE + (n < 3 and 12 or 0)), -112)
    end
  end
  t:Show()
end

function SP:Bauen()
  if self.rahmen then return end
  local f = S.kasten(UIParent, "Frame", F.grund, F.rand, "CampfireBuddyGames")
  self.rahmen = f
  f:SetSize(RAHMEN_B, RAHMEN_H)
  f:SetScale(ns.Show.SpielFaktor and ns.Show.SpielFaktor() or 1.6)
  -- Unter der Murloc-Show, damit beide zu sehen sind
  ns.Leiste.Position(f, ns.db.spiel, "CENTER", 0, -140)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not ns.db.gesperrt then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    ns.db.spiel = ns.Leiste.Merken(self)
  end)
  if UISpecialFrames then table.insert(UISpecialFrames, "CampfireBuddyGames") end
  -- Musik nur, solange das Fenster offen ist (auch Esc und Kampf schließen es)
  f:SetScript("OnHide", function() ns.Musik:Stop() end)
  S.schatten(f)
  f:Hide()

  f.zurueck = S.zeichenKnopf(f, "<", function() SP:Menue() end)
  f.zurueck:SetSize(20, 20)
  f.zurueck:SetPoint("TOPLEFT", 4, -4)
  S.tooltip(f.zurueck, L.GAMES_BACK, nil)
  f.titel = S.schrift(f, "GameFontHighlightSmall", F.akzent)
  f.titel:SetPoint("TOPLEFT", 28, -9)
  f.stand = S.schrift(f, "GameFontHighlightSmall", F.text)
  f.stand:SetPoint("TOPRIGHT", -30, -9)
  local zu = S.zeichenKnopf(f, "x", function() SP:Schliessen() end)
  zu:SetSize(20, 20)
  zu:SetPoint("TOPRIGHT", -4, -4)

  -- Spielfläche
  local bereich = CreateFrame("Frame", nil, f)
  self.bereich = bereich
  bereich:SetSize(SP.BREITE, SP.HOEHE)
  -- Nichts ragt aus der Spielfläche heraus (Stämme, die hereinkommen, Schein, Funken)
  if bereich.SetClipsChildren then bereich:SetClipsChildren(true) end
  bereich:SetPoint("TOPLEFT", 10, -30)
  -- Hintergrund: die Nachtszene der Show, mittlerer Ausschnitt, stark abgedunkelt
  local grund = bereich:CreateTexture(nil, "BACKGROUND")
  grund:SetAllPoints()
  grund:SetTexture(S.NACHT)
  local anteil = SP.BREITE / SP.HOEHE * S.NACHT_HOEHE * S.NACHT_SEITE / 2
  grund:SetTexCoord(0.5 - anteil, 0.5 + anteil, 0, S.NACHT_HOEHE)
  grund:SetVertexColor(0.42, 0.42, 0.5)
  f.ergebnis = S.schrift(f, "GameFontNormal", F.text)
  f.ergebnis:SetPoint("BOTTOM", 0, 14)
  -- Legende unter der Spielfläche: was gibt welche Punkte (spiel.legende), solange das Spiel läuft
  local legende = CreateFrame("Frame", nil, f)
  legende:SetSize(SP.BREITE, 16)
  legende:SetPoint("BOTTOM", 0, 12)
  legende.teile = {}
  for i = 1, 6 do
    local bild = legende:CreateTexture(nil, "ARTWORK")
    bild:SetSize(14, 14)
    local text = S.schrift(legende, "GameFontHighlightSmall", F.text)
    text:SetPoint("LEFT", bild, "RIGHT", 3, 0)
    legende.teile[i] = { bild = bild, text = text }
  end
  legende:Hide()
  f.legende = legende

  -- Schwebende Zurufe ("+3", "BOOM!", "Mrgl!") über allem, steigen auf und verblassen
  local ruf = CreateFrame("Frame", nil, bereich)
  ruf:SetAllPoints()
  ruf:SetFrameLevel(((bereich.GetFrameLevel and bereich:GetFrameLevel()) or 1) + 40)
  self.rufe = {}
  for i = 1, 8 do
    local s = S.schrift(ruf, "GameFontNormalLarge", F.akzent)
    s:SetWordWrap(true)
    s:SetJustifyH("CENTER")
    s:Hide()
    self.rufe[i] = s
  end
  self.rufEbene = ruf
  self.tafel = tafelBauen(bereich)

  -- Menü: drei Spalten mit Symbol, darunter Name und Rekord. Ab zehn Spielen vier Reihen, dann
  -- werden die Knöpfe flacher und das Symbol kleiner, damit alles in der Spielfläche bleibt.
  local menue = CreateFrame("Frame", nil, bereich)
  self.menue = menue
  menue:SetAllPoints()
  menue.knoepfe = {}
  local SP_MENUE = 3
  local reihen = math.ceil(#SP.liste / SP_MENUE)
  local abstand = reihen > 3 and 3 or 4
  local kb = (SP.BREITE - 4 * (SP_MENUE + 1)) / SP_MENUE
  local kh = math.min(58, math.floor((SP.HOEHE - 4 - (reihen - 1) * abstand - 2) / reihen))
  local symbol = kh >= 54 and 26 or 18
  local nameY = kh >= 54 and -33 or -(symbol + 5)
  for i, spiel in ipairs(SP.liste) do
    local b = S.kasten(menue, "Button", F.flaeche, F.rand)
    b:SetSize(kb, kh)
    local spalte, reihe = (i - 1) % SP_MENUE, math.floor((i - 1) / SP_MENUE)
    b:SetPoint("TOPLEFT", 4 + spalte * (kb + 4), -4 - reihe * (kh + abstand))
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(symbol, symbol)
    b.icon:SetPoint("TOP", 0, kh >= 54 and -5 or -3)
    b.icon:SetTexture(spiel.icon)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.name = S.schrift(b, "GameFontHighlightSmall", F.text)
    b.name:SetPoint("TOP", 0, nameY)
    b.name:SetWidth(kb - 4)
    b.name:SetWordWrap(false)
    b.name:SetText(spiel.name)
    b.best = S.schrift(b, "GameFontHighlightSmall", F.leise)
    b.best:SetPoint("TOP", 0, nameY - 11)
    b.best:SetWidth(kb - 4)
    b.best:SetWordWrap(false)
    b:HookScript("OnEnter", function(self) S.randFarbe(self, F.akzent) end)
    b:HookScript("OnLeave", function(self) S.randFarbe(self, F.rand) end)
    b:SetScript("OnClick", function() S.klick() SP:Spielen(spiel.key) end)
    S.tooltip(b, spiel.name, spiel.info)
    b.key = spiel.key
    menue.knoepfe[i] = b
  end

  f:SetScript("OnUpdate", function(_, dt) SP:Tick(dt) end)
end

-- Menü zeigen. ausShow: geöffnet über Play in der Murloc-Show. Dann gehören die Spiele zur
-- Sitz-Minute und schließen sich, wenn man aufsteht oder vom Feuer weggeht.
function SP:Menue(ausShow)
  self:Bauen()
  if ausShow ~= nil then self.ausShow = ausShow end
  self:Anhalten()
  for _, s in ipairs(self.liste) do if s.rahmen then s.rahmen:Hide() end end
  self.tafel:Hide()
  for _, b in ipairs(self.menue.knoepfe) do
    local spiel = self.spiele[b.key]
    local stufe = spiel.stufen and letzteStufe(spiel)
    b.best:SetText(string.format(L.GAME_BEST, rekord(stufe and stufe.rekord or b.key))
      .. (stufe and ("  (" .. stufe.text .. ")") or ""))
  end
  self.menue:Show()
  self.rahmen.legende:Hide()
  ns.Musik:Spielen("arcade")
  self.rahmen.titel:SetText(L.GAMES_TITLE)
  self.rahmen.stand:SetText("")
  self.rahmen.ergebnis:SetText("")
  self.rahmen.zurueck:Hide()
  self.rahmen:Show()
end

-- Stufen zur Wahl, bevor das Spiel startet (die zuletzt gewählte steht vorn im Titel)
function SP:Waehlen(spiel)
  self.menue:Hide()
  self.rahmen.titel:SetText(spiel.name)
  self.rahmen.stand:SetText("")
  self.rahmen.ergebnis:SetText("")
  self.rahmen.zurueck:Show()
  local knoepfe = {}
  for _, s in ipairs(spiel.stufen) do
    table.insert(knoepfe, { text = s.text, info = s.info, aktion = function()
      ns.db.stufen = ns.db.stufen or {}
      ns.db.stufen[spiel.key] = s.wert
      SP:Spielen(spiel.key, s)
    end })
  end
  self:Tafel(spiel.name, L.GAME_PICK_LEVEL, knoepfe)
  self.rahmen:Show()
end

function SP:Spielen(key, stufe)
  local spiel = self.spiele[key]
  if not spiel then return end
  self:Bauen()
  self:Anhalten()
  self.menue:Hide()
  self.tafel:Hide()
  for _, s in ipairs(self.liste) do if s.rahmen then s.rahmen:Hide() end end
  if spiel.stufen and not stufe then return self:Waehlen(spiel) end
  spiel.stufe = stufe
  if not spiel.rahmen then
    spiel.rahmen = CreateFrame("Frame", nil, self.bereich)
    spiel.rahmen:SetAllPoints()
    spiel:Bauen(spiel.rahmen)
  end
  spiel.rahmen:Show()
  self.aktiv, self.punkte, self.laeuft, self.schluss = spiel, 0, true, nil
  self.runde, self.pause = 1, nil
  local jetzt = ns.jetzt()
  self.dauer = stufe and stufe.dauer or spiel.dauer
  self.ende = self.dauer and (jetzt + self.dauer) or nil
  self.rahmen.titel:SetText(spiel.name .. (stufe and ("  " .. stufe.text) or ""))
  self.rahmen.ergebnis:SetText("")
  self.rahmen.zurueck:Show()
  self:Anzeigen()
  spiel:Start()
  self:LegendeZeigen(spiel)
  self.rahmen:Show()
  ns.Musik:Spielen(spiel.musik or "arcade")
end

-- Legende eines Spiels zeigen. spiel.legende = { { bild = Pfad oder atlas = Name, coords = { l, r, o, u },
-- farbe = { r, g, b }, punkte = Zahl oder text = Text }, ... } (höchstens sechs Einträge)
function SP:LegendeZeigen(spiel)
  local l = self.rahmen and self.rahmen.legende
  if not l then return end
  local eintraege = spiel and spiel.legende
  if not eintraege or #eintraege == 0 then return l:Hide() end
  -- Je Eintrag höchstens 58 Pixel, bei vielen Einträgen schmaler: die Legende bleibt immer in der
  -- Breite der Spielfläche (sechs Einträge ragten aus dem Fenster, Patricks Screenshot 16. Okt)
  local breite = math.min(58, math.floor(SP.BREITE / #eintraege))
  local start = -(#eintraege * breite) / 2
  for i, t in ipairs(l.teile) do
    local e = eintraege[i]
    if e then
      local ok = e.atlas and S.atlas(t.bild, e.atlas)
      if not ok then
        t.bild:SetTexture(e.bild)
        if e.coords then t.bild:SetTexCoord(e.coords[1], e.coords[2], e.coords[3], e.coords[4])
        else t.bild:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
      end
      local c = e.farbe or { 1, 1, 1 }
      t.bild:SetVertexColor(c[1], c[2], c[3])
      t.bild:ClearAllPoints()
      t.bild:SetPoint("LEFT", l, "CENTER", start + (i - 1) * breite + 4, 0)
      t.text:SetText(e.text or string.format(L.LEGEND_POINTS, e.punkte or 0))
      t.text:SetTextColor(rgba((e.punkte or 0) < 0 and F.fehler or F.text))
      t.bild:Show()
      t.text:Show()
    else
      t.bild:Hide()
      t.text:Hide()
    end
  end
  l:Show()
end

function SP:Anzeigen()
  if not (self.rahmen and self.aktiv) then return end
  local text = string.format(L.GAME_SCORE, self.punkte or 0)
  if (self.runde or 1) > 1 then text = string.format(L.GAME_ROUND, self.runde) .. "   " .. text end
  if self.laeuft and self.ende and not self.pause then
    text = text .. "   " .. ns.dauerText(self.ende - ns.jetzt())
  end
  self.rahmen.stand:SetText(text)
end

-- Punkte immer ganzzahlig, nie unter 0
function SP:Plus(n)
  if not self.laeuft then return end
  self.punkte = math.max(0, (self.punkte or 0) + math.floor(n + 0.5))
  self:Anzeigen()
end

-- Zuruf an Stelle x, y (von oben links der Spielfläche, y nach unten negativ). farbe optional.
function SP:Ruf(text, x, y, farbe)
  if not self.rufe then return end
  local frei
  for _, s in ipairs(self.rufe) do if not s.bis then frei = s break end end
  frei = frei or self.rufe[1]
  -- Nie über den Rand: zu lange Zurufe brechen um, und die Mitte rückt so weit nach innen, dass
  -- der ganze Text in der Spielfläche steht (Patricks Screenshot, 16. Okt)
  frei:SetWidth(0)
  frei:SetText(text)
  local maxB = SP.BREITE - 16
  local w = (frei.GetStringWidth and frei:GetStringWidth()) or 0
  if w > maxB then
    frei:SetWidth(maxB)
    w = maxB
  end
  local halb = w / 2 + 6
  x = math.max(halb, math.min(SP.BREITE - halb, x))
  frei:SetTextColor(rgba(farbe or F.akzent))
  frei.x, frei.y, frei.bis, frei.dauer = x, y, ns.jetzt() + 1.1, 1.1
  frei:ClearAllPoints()
  frei:SetPoint("CENTER", self.rufEbene, "TOPLEFT", x, y)
  frei:SetAlpha(1)
  frei:Show()
end

-- Zufälliger Spruch aus einer Liste
function SP.spruch(liste) return liste[math.random(1, #liste)] end

function SP:RufeTick()
  local jetzt = ns.jetzt()
  for _, s in ipairs(self.rufe or {}) do
    if s.bis then
      local rest = (s.bis - jetzt) / s.dauer
      if rest <= 0 then
        s.bis = nil
        s:Hide()
      else
        s:SetAlpha(math.min(1, rest * 1.6))
        s:ClearAllPoints()
        s:SetPoint("CENTER", self.rufEbene, "TOPLEFT", s.x, s.y + (1 - rest) * 22)
      end
    end
  end
end

-- Spielende: Rekord merken, Ergebnis stehen lassen, mit Play again und Games
function SP:Fertig(text)
  if not self.laeuft then return end
  local spiel = self.aktiv
  self.laeuft, self.pause = false, nil
  if spiel.Stop then pcall(spiel.Stop, spiel) end
  ns.db.rekorde = ns.db.rekorde or {}
  local key = rekordKey(spiel)
  local neu = self.punkte > rekord(key)
  if neu then ns.db.rekorde[key] = self.punkte end
  local zeile = neu and self.punkte > 0 and string.format(L.GAME_RECORD, self.punkte)
    or string.format(L.GAME_OVER, self.punkte, rekord(key))
  -- Unten nur Punkte und Rekord, der Text des Spiels steht schon auf der Tafel (sonst zu lang)
  self.rahmen.ergebnis:SetText(zeile)
  self.rahmen.legende:Hide()
  ns.ton(neu and self.punkte > 0 and "rekord" or "fertig")
  self:Anzeigen()
  local stufe = spiel.stufe
  self:Tafel(neu and self.punkte > 0 and L.GAME_NEW_RECORD or L.GAME_END, text, {
    { text = L.BTN_AGAIN, aktion = function() SP:Spielen(spiel.key, stufe) end },
    { text = L.BTN_GAMES, aktion = function() SP:Menue() end },
  })
end

-- Runde geschafft: Restzeit als Bonus, Uhr steht. Weiter gibt eine neue Runde mit etwas weniger
-- Zeit, Stop wertet das Spiel.
function SP:Runde(text, weiter)
  if not self.laeuft then return end
  local rest = self.ende and math.floor(math.max(0, self.ende - ns.jetzt())) or 0
  self:Plus(rest)
  self.pause = true
  self:Anzeigen()
  ns.ton("rekord")
  self:Tafel(string.format(L.GAME_ROUND_DONE, self.runde), (text or "") .. "  " .. string.format(L.GAME_TIME_BONUS, rest), {
    { text = L.BTN_NEXT_ROUND, aktion = function()
      SP.tafel:Hide()
      SP.runde = SP.runde + 1
      SP.pause = nil
      if SP.dauer then
        SP.ende = ns.jetzt() + math.max(RUNDE_MINDESTENS, SP.dauer - (SP.runde - 1) * RUNDE_KUERZER)
      end
      weiter()
      SP:Anzeigen()
    end },
    { text = L.BTN_STOP, aktion = function() SP:Fertig(text) end },
  })
end

-- Laufendes Spiel ohne Wertung anhalten (Menü, Schließen, Kampf)
function SP:Anhalten()
  if self.laeuft and self.aktiv and self.aktiv.Stop then pcall(self.aktiv.Stop, self.aktiv) end
  self.laeuft, self.schluss, self.pause = false, nil, nil
  if self.tafel then self.tafel:Hide() end
end

function SP:Schliessen()
  self:Anhalten()
  if self.rahmen then self.rahmen:Hide() end
end

function SP:Tick(dt)
  local jetzt = ns.jetzt()
  self:RufeTick()
  if not (self.laeuft and self.aktiv) or self.pause then return end
  if self.ende and jetzt >= self.ende then return self:Fertig() end
  local ok, fehler = pcall(self.aktiv.Tick, self.aktiv, dt, jetzt)
  if not ok then
    ns.melde(string.format(L.ERR_EVENT, self.aktiv.key, tostring(fehler)))
    self:Fertig()
    return
  end
  self.anzeigeWarten = (self.anzeigeWarten or 0) + dt
  if self.anzeigeWarten >= 0.25 then
    self.anzeigeWarten = 0
    self:Anzeigen()
  end
end

-- Aufgestanden oder vom Feuer weg: Spiele, die aus der Show kamen, gehen zu
function SP:Aufgestanden()
  if self.ausShow and self.rahmen and self.rahmen:IsShown() then self:Schliessen() end
  self.ausShow = false
end

-- Bei Kampfbeginn sofort zu, damit nichts im Weg ist
ns.ereignis("PLAYER_REGEN_DISABLED", function() SP:Schliessen() end)
