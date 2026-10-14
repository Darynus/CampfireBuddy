-- Spiele am Lagerfeuer: ein Fenster mit Menü und acht kleinen Spielen für die Minute am Feuer
-- (und länger, wer mag). Reine Oberfläche: keine Spielaktion, keine Nachrichten, nur auf Klick.
-- Bei Kampfbeginn schließt sich alles. Rekorde je Spiel in CampfireBuddyDB.rekorde.
--
-- Ein Spiel meldet sich mit ns.Spiel.Registrieren({ ... }) an:
--   key, name, info, icon, dauer (Sekunden, nil = das Spiel endet selbst)
--   Bauen(self, rahmen)  einmal, rahmen ist die Spielfläche (BREITE x HOEHE)
--   Start(self)          jede Runde
--   Tick(self, dt, jetzt) jedes Bild, solange es läuft
--   Stop(self)           beim Ende (aufräumen)
-- Punkte: SP:Plus(n), Ende von innen: SP:Fertig(text)
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba

local SP = { liste = {}, spiele = {} }
ns.Spiel = SP

SP.BREITE, SP.HOEHE = 300, 190
local RAHMEN_B, RAHMEN_H = SP.BREITE + 20, SP.HOEHE + 70
local NACHLAUF = 5

function SP.Registrieren(spiel)
  table.insert(SP.liste, spiel)
  SP.spiele[spiel.key] = spiel
end

function SP.zufall(a, b) return a + math.random() * (b - a) end

local function rekord(key) return (ns.db.rekorde or {})[key] or 0 end

function SP:Bauen()
  if self.rahmen then return end
  local f = S.kasten(UIParent, "Frame", F.grund, F.rand, "CampfireBuddyGames")
  self.rahmen = f
  f:SetSize(RAHMEN_B, RAHMEN_H)
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
  bereich:SetPoint("TOPLEFT", 10, -30)
  -- Hintergrund: die Nachtszene der Show, mittlerer Ausschnitt, stark abgedunkelt
  local grund = bereich:CreateTexture(nil, "BACKGROUND")
  grund:SetAllPoints()
  grund:SetTexture(S.NACHT)
  local anteil = SP.BREITE / SP.HOEHE * S.NACHT_HOEHE * 256 / 512 / 2
  grund:SetTexCoord(0.5 - anteil, 0.5 + anteil, 0, S.NACHT_HOEHE)
  grund:SetVertexColor(0.42, 0.42, 0.5)
  f.ergebnis = S.schrift(f, "GameFontNormal", F.text)
  f.ergebnis:SetPoint("BOTTOM", 0, 14)

  -- Schwebende Zurufe ("+3", "BOOM!", "Mrgl!") über allem, steigen auf und verblassen
  local ruf = CreateFrame("Frame", nil, bereich)
  ruf:SetAllPoints()
  ruf:SetFrameLevel(((bereich.GetFrameLevel and bereich:GetFrameLevel()) or 1) + 40)
  self.rufe = {}
  for i = 1, 8 do
    local s = S.schrift(ruf, "GameFontNormalLarge", F.akzent)
    s:Hide()
    self.rufe[i] = s
  end
  self.rufEbene = ruf

  -- Menü: zwei Spalten mit Symbol, Name und Rekord
  local menue = CreateFrame("Frame", nil, bereich)
  self.menue = menue
  menue:SetAllPoints()
  menue.knoepfe = {}
  local kb, kh = (SP.BREITE - 12) / 2, 42
  for i, spiel in ipairs(SP.liste) do
    local b = S.kasten(menue, "Button", F.flaeche, F.rand)
    b:SetSize(kb, kh)
    local spalte, reihe = (i - 1) % 2, math.floor((i - 1) / 2)
    b:SetPoint("TOPLEFT", 4 + spalte * (kb + 4), -4 - reihe * (kh + 4))
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(30, 30)
    b.icon:SetPoint("LEFT", 6, 0)
    b.icon:SetTexture(spiel.icon)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.name = S.schrift(b, "GameFontHighlightSmall", F.text)
    b.name:SetPoint("TOPLEFT", 42, -7)
    b.name:SetText(spiel.name)
    b.best = S.schrift(b, "GameFontHighlightSmall", F.leise)
    b.best:SetPoint("TOPLEFT", 42, -22)
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
  for _, b in ipairs(self.menue.knoepfe) do
    b.best:SetText(string.format(L.GAME_BEST, rekord(b.key)))
  end
  self.menue:Show()
  self.rahmen.titel:SetText(L.GAMES_TITLE)
  self.rahmen.stand:SetText("")
  self.rahmen.ergebnis:SetText("")
  self.rahmen.zurueck:Hide()
  self.rahmen:Show()
end

function SP:Spielen(key)
  local spiel = self.spiele[key]
  if not spiel then return end
  self:Bauen()
  self:Anhalten()
  self.menue:Hide()
  for _, s in ipairs(self.liste) do if s.rahmen then s.rahmen:Hide() end end
  if not spiel.rahmen then
    spiel.rahmen = CreateFrame("Frame", nil, self.bereich)
    spiel.rahmen:SetAllPoints()
    spiel:Bauen(spiel.rahmen)
  end
  spiel.rahmen:Show()
  self.aktiv, self.punkte, self.laeuft, self.schluss = spiel, 0, true, nil
  local jetzt = ns.jetzt()
  self.ende = spiel.dauer and (jetzt + spiel.dauer) or nil
  self.rahmen.titel:SetText(spiel.name)
  self.rahmen.ergebnis:SetText("")
  self.rahmen.zurueck:Show()
  self:Anzeigen()
  spiel:Start()
  self.rahmen:Show()
end

function SP:Anzeigen()
  if not (self.rahmen and self.aktiv) then return end
  local text = string.format(L.GAME_SCORE, self.punkte or 0)
  if self.laeuft and self.ende then
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
  frei:SetText(text)
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

-- Spielende: Rekord merken, Ergebnis kurz stehen lassen, dann zurück ins Menü
function SP:Fertig(text)
  if not self.laeuft then return end
  local spiel = self.aktiv
  self.laeuft = false
  if spiel.Stop then pcall(spiel.Stop, spiel) end
  ns.db.rekorde = ns.db.rekorde or {}
  local neu = self.punkte > rekord(spiel.key)
  if neu then ns.db.rekorde[spiel.key] = self.punkte end
  local zeile = neu and self.punkte > 0 and string.format(L.GAME_RECORD, self.punkte)
    or string.format(L.GAME_OVER, self.punkte, rekord(spiel.key))
  self.rahmen.ergebnis:SetText(text and (text .. "  " .. zeile) or zeile)
  self.schluss = ns.jetzt() + NACHLAUF
  ns.ton(neu and self.punkte > 0 and "rekord" or "fertig")
  self:Anzeigen()
end

-- Laufendes Spiel ohne Wertung anhalten (Menü, Schließen, Kampf)
function SP:Anhalten()
  if self.laeuft and self.aktiv and self.aktiv.Stop then pcall(self.aktiv.Stop, self.aktiv) end
  self.laeuft, self.schluss = false, nil
end

function SP:Schliessen()
  self:Anhalten()
  if self.rahmen then self.rahmen:Hide() end
end

function SP:Tick(dt)
  local jetzt = ns.jetzt()
  self:RufeTick()
  if self.schluss and jetzt >= self.schluss then
    self.schluss = nil
    return self:Menue()
  end
  if not (self.laeuft and self.aktiv) then return end
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
