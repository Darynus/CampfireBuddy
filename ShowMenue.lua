-- Knöpfe in der Kopfzeile der Murloc-Show: Emotes (Wave, Thank you, Cheer ...) und Optionen
-- (Größe von Show und Spielen, Show beim Hinsetzen, Töne, Musik). Ein Emote geht nur per Klick
-- raus, eines je Klick, höchstens eines pro Sekunde und nie im Kampf (dann ist die Show zu).
-- Der Murloc antwortet darauf. Emotes über ihre Kennung (DoEmote), also in jeder Spielsprache.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F = S.F
local SH = ns.Show

local EMOTE_PAUSE = 1

SH.EMOTES = {
  { token = "WAVE", text = L.EMOTE_WAVE, anim = "winken", antwort = L.EMOTE_REPLY_WAVE },
  { token = "THANK", text = L.EMOTE_THANK, anim = "jubeln", antwort = L.EMOTE_REPLY_THANK },
  { token = "CHEER", text = L.EMOTE_CHEER, anim = "jubeln", antwort = L.EMOTE_REPLY_CHEER },
  { token = "DANCE", text = L.EMOTE_DANCE, anim = "tanzen", antwort = L.EMOTE_REPLY_DANCE },
  { token = "LAUGH", text = L.EMOTE_LAUGH, anim = "lachen", antwort = L.EMOTE_REPLY_LAUGH },
  { token = "APPLAUD", text = L.EMOTE_APPLAUD, anim = "jubeln", antwort = L.EMOTE_REPLY_APPLAUD },
  { token = "BOW", text = L.EMOTE_BOW, anim = "muskeln", antwort = L.EMOTE_REPLY_BOW },
  { token = "ROAR", text = L.EMOTE_ROAR, anim = "bruellen", antwort = L.EMOTE_REPLY_ROAR },
}

-- Größe von Show und Spielen
SH.GROESSEN = {
  { wert = "normal", text = L.SIZE_NORMAL, faktor = 1 },
  { wert = "gross", text = L.SIZE_LARGE, faktor = 1.3 },
  { wert = "riesig", text = L.SIZE_HUGE, faktor = 1.6 },
}

function SH.Faktor()
  local wahl = ns.db and ns.db.showGroesse or "gross"
  for _, g in ipairs(SH.GROESSEN) do if g.wert == wahl then return g.faktor end end
  return 1
end

-- Die Spiele immer mindestens in Huge, sonst sind sie zu klein zum Spielen (Patrick, 16. Okt).
-- Größer geht, wenn es später mehr Stufen gibt.
local SPIEL_MINDESTENS = 1.6
function SH.SpielFaktor()
  return math.max(SH.Faktor(), SPIEL_MINDESTENS)
end

-- Größe auf Show und Spiele anwenden
function SH.GroesseSetzen()
  local faktor = SH.Faktor()
  if SH.rahmen then SH.rahmen:SetScale(faktor) end
  if ns.Spiel and ns.Spiel.rahmen then ns.Spiel.rahmen:SetScale(SH.SpielFaktor()) end
end

-- Emote senden (ein Klick, ein Emote) und den Murloc antworten lassen
local zuletzt = -EMOTE_PAUSE
function SH:Emote(e)
  if InCombatLockdown and InCombatLockdown() then return end
  local jetzt = ns.jetzt()
  if jetzt - zuletzt < EMOTE_PAUSE then return end
  zuletzt = jetzt
  if DoEmote then pcall(DoEmote, e.token) end
  self:Antworten(e)
end

function SH:Antworten(e)
  if not self.laeuft then return end
  if self.finale then
    self:Anim(e.anim)
  else
    -- Kurz stehen bleiben, nach vorn schauen und antworten. Er holt die Zeit danach rennend auf.
    self:NeuerAkt(ns.jetzt(), { name = "antwort", von = 1.8, bis = 2.2, tempo = 0, blick = 0, anim = e.anim })
  end
  self:Sagen(e.antwort[math.random(1, #e.antwort)], 2)
  ns.mrgl(0.5)
end

-- Aufklappliste unter einem Knopf, im Look der Auswahllisten des Spiels
local function liste(parent, breite, hoehe)
  local m = S.spielKasten(parent, "Frame", { 0.04, 0.04, 0.05, 0.96 })
  m:SetSize(breite, hoehe)
  m:SetFrameStrata("DIALOG")
  m:SetClampedToScreen(true)
  m:EnableMouse(true)
  m:Hide()
  return m
end

local function umschalten(m, andere)
  if andere then andere:Hide() end
  m:SetShown(not m:IsShown())
end

function SH:EmoteListe(knopf)
  local zeilen = #SH.EMOTES
  local m = liste(self.rahmen, 128, zeilen * 18 + 14)
  m:SetPoint("TOPRIGHT", knopf, "BOTTOMRIGHT", 0, -2)
  m.zeilen = {}
  for i, e in ipairs(SH.EMOTES) do
    local z = S.zeile(m)
    z:SetSize(116, 18)
    z:SetPoint("TOPLEFT", 6, -7 - (i - 1) * 18)
    z.text = S.schrift(z, "GameFontHighlightSmall", F.text)
    z.text:SetPoint("LEFT", 6, 0)
    z.text:SetText(e.text)
    z:SetScript("OnClick", function()
      S.klick()
      m:Hide()
      SH:Emote(e)
    end)
    m.zeilen[i] = z
  end
  return m
end

function SH:OptionenListe(knopf)
  local m = liste(self.rahmen, 214, 150)
  m:SetPoint("TOPRIGHT", knopf, "BOTTOMRIGHT", 0, -2)
  local titel = S.ueberschrift(m, L.SHOW_SIZE)
  titel:SetPoint("TOPLEFT", 10, -10)
  m.groesse = S.segmente(m, 196, SH.GROESSEN, function(wert)
    ns.db.showGroesse = wert
    SH.GroesseSetzen()
    m:Aktualisieren()
  end)
  m.groesse:SetPoint("TOPLEFT", 8, -26)
  m.schalter = {}
  for i, s in ipairs({
    { feld = "showAn", text = L.OPT_SHOW, hilfe = L.OPT_SHOW_HELP },
    { feld = "murlocTon", text = L.OPT_MURLOC_SOUND, hilfe = L.OPT_MURLOC_SOUND_HELP },
    { feld = "spielMusik", text = L.OPT_MUSIC, hilfe = L.OPT_MUSIC_HELP },
  }) do
    local h = S.haken(m, 196, s.text, s.hilfe, function(_, an)
      ns.db[s.feld] = an
      if s.feld == "spielMusik" and ns.Musik then ns.Musik:Einstellung() end
      m:Aktualisieren()
      ns.aktualisieren()
    end)
    h.feld = s.feld
    h:SetPoint("TOPLEFT", 10, -52 - (i - 1) * 22)
    m.schalter[i] = h
  end
  local alle = S.textKnopf(m, L.SHOW_ALL_SETTINGS, 120, function()
    m:Hide()
    ns.Fenster:Zeigen("einstellungen")
  end)
  alle:SetPoint("BOTTOMLEFT", 10, 10)
  function m:Aktualisieren()
    self.groesse:Setzen(ns.db.showGroesse or "gross")
    for _, h in ipairs(self.schalter) do h:Setzen(ns.db[h.feld]) end
  end
  m:SetScript("OnShow", function(self) self:Aktualisieren() end)
  return m
end

-- Knöpfe in die Kopfzeile der Show (Show.lua ruft das beim Bauen auf)
function SH:MenueBauen(f, rechts)
  local optionen = CreateFrame("Button", nil, f)
  optionen:SetSize(18, 18)
  optionen:SetPoint("TOPRIGHT", rechts, "TOPLEFT", -4, 0)
  optionen:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
  optionen:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  S.tooltip(optionen, L.SHOW_OPTIONS, L.SHOW_OPTIONS_HELP)
  local emote = S.textKnopf(f, L.BTN_EMOTE, 58, function() end)
  emote:SetHeight(18)
  emote:SetPoint("TOPRIGHT", optionen, "TOPLEFT", -4, 0)
  S.tooltip(emote, L.BTN_EMOTE, L.EMOTE_HELP)
  f.optionen, f.emote = optionen, emote
  f.optionenListe = self:OptionenListe(optionen)
  f.emoteListe = self:EmoteListe(emote)
  optionen:SetScript("OnClick", function() S.klick() umschalten(f.optionenListe, f.emoteListe) end)
  emote:SetScript("OnClick", function() S.klick() umschalten(f.emoteListe, f.optionenListe) end)
  return emote
end
