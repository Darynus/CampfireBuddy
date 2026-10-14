-- Stil: Bausteine für Leiste und Hauptfenster. Vorlage aus Pigeon Post und Duo, hier mit
-- glutrotem Akzent. Alles selbst gezeichnet (nur BackdropTemplate), damit nichts von
-- Blizzard-Vorlagen abhängt, die es in Forever vielleicht nicht gibt.
local ADDON, ns = ...

local S = {}
ns.Stil = S

S.WEISS = "Interface\\Buttons\\WHITE8x8"
S.ICON = "Interface\\AddOns\\CampfireBuddy\\Media\\Icon"
-- Lager-Symbol aus Forever selbst ("Camp Benefits", Patricks Wahl), Nachtszene und freigestelltes
-- Lagerfeuer für Show und Spiele (eigene Grafiken aus grafik/)
S.LAGER = "Interface\\Icons\\INV_Camelot_Camping_CampBenefits"
S.NACHT = "Interface\\AddOns\\CampfireBuddy\\Media\\Nacht"
S.NACHT_HOEHE = 199 / 256       -- genutzter Teil der Nachtszene (Rest ist Boden zum Abschneiden)
S.FLAMME = "Interface\\AddOns\\CampfireBuddy\\Media\\Lagerfeuer"

-- Markenzeichen: der grüne Murloc aus den Icons des Spiels (liegt im Client, nichts wird
-- mitgeliefert), dazu unser Lagerfeuer-Abzeichen unten rechts. Fehlt ein Icon im Client,
-- gilt das nächste der Liste.
S.MARKE = {
  "Interface\\Icons\\INV_10XP_WorldEvent_Special_MurlocFigure",
  "Interface\\Icons\\INV_BabyMurloc3_Yellow",
  "Interface\\Icons\\INV_Misc_Head_Murloc_01",
}
S.ABZEICHEN = "Interface\\AddOns\\CampfireBuddy\\Media\\Abzeichen"

function S.markeSetzen(t)
  for _, datei in ipairs(S.MARKE) do
    if t:SetTexture(datei) ~= false then break end
  end
  t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

-- Abzeichen über die rechte untere Ecke eines Icons legen
function S.abzeichen(parent, icon, groesse)
  local a = parent:CreateTexture(nil, "OVERLAY", nil, 7)
  a:SetSize(groesse, groesse)
  a:SetPoint("CENTER", icon, "BOTTOMRIGHT", -groesse * 0.12, groesse * 0.12)
  a:SetTexture(S.ABZEICHEN)
  return a
end
S.STERN = "Interface\\Common\\FavoritesIcon"
S.PFEIL = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up"
S.RICHTUNG = "Interface\\Minimap\\MinimapArrow"

S.F = {
  grund   = { 0.07, 0.05, 0.07, 1 },
  kopf    = { 0.14, 0.08, 0.07, 1 },
  seite   = { 0.09, 0.07, 0.09, 1 },
  flaeche = { 0.14, 0.11, 0.13, 1 },
  rand    = { 0.32, 0.22, 0.20, 1 },
  akzent  = { 1.00, 0.55, 0.22, 1 },
  erholt  = { 0.32, 0.55, 0.95, 0.65 },
  text    = { 0.92, 0.94, 0.97, 1 },
  leise   = { 0.56, 0.62, 0.72, 1 },
  erfolg  = { 0.40, 0.84, 0.56, 1 },
  fehler  = { 0.94, 0.38, 0.35, 1 },
  hinweis = { 0.96, 0.77, 0.32, 1 },
  stern   = { 1.00, 0.82, 0.20, 1 },
  aufAkzent = { 0.12, 0.05, 0.02, 1 },  -- Schrift auf glutrotem Grund, Weiß wäre zu blass
}
local F = S.F

function S.rgba(f) return f[1], f[2], f[3], f[4] or 1 end
local rgba = S.rgba

function S.heller(f)
  return { f[1] + (1 - f[1]) * 0.2, f[2] + (1 - f[2]) * 0.2, f[3] + (1 - f[3]) * 0.2, f[4] or 1 }
end

function S.kasten(parent, typ, grund, rand, name)
  local f = CreateFrame(typ or "Frame", name, parent, "BackdropTemplate")
  if f.SetBackdrop then
    f:SetBackdrop({ bgFile = S.WEISS, edgeFile = S.WEISS, edgeSize = 1 })
    f:SetBackdropColor(rgba(grund or F.flaeche))
    f:SetBackdropBorderColor(rgba(rand or F.rand))
  end
  return f
end

function S.grundFarbe(f, farbe) if f.SetBackdropColor then f:SetBackdropColor(rgba(farbe)) end end
function S.randFarbe(f, farbe) if f.SetBackdropBorderColor then f:SetBackdropBorderColor(rgba(farbe)) end end

function S.schrift(parent, vorlage, farbe)
  local s = parent:CreateFontString(nil, "OVERLAY", vorlage or "GameFontHighlightSmall")
  if farbe then s:SetTextColor(rgba(farbe)) end
  return s
end

-- Mehrzeiliger Text mit fester Breite
function S.absatz(parent, breite, farbe, vorlage)
  local s = S.schrift(parent, vorlage or "GameFontHighlightSmall", farbe or F.leise)
  s:SetWidth(breite)
  s:SetJustifyH("LEFT")
  s:SetJustifyV("TOP")
  s:SetWordWrap(true)
  return s
end

-- Tooltip mit Titel und Erklärung. titel und text dürfen Funktionen sein.
function S.tooltip(rahmen, titel, text)
  rahmen:HookScript("OnEnter", function(self)
    local t = type(titel) == "function" and titel(self) or titel
    local x = type(text) == "function" and text(self) or text
    if not t then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(t, 1, 1, 1)
    if x then GameTooltip:AddLine(x, F.leise[1], F.leise[2], F.leise[3], true) end
    GameTooltip:Show()
  end)
  rahmen:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

function S.ueberschrift(parent, text)
  local s = S.schrift(parent, "GameFontNormalSmall", F.leise)
  s:SetText(text)
  return s
end

function S.klassenFarbe(klasse)
  local c = RAID_CLASS_COLORS and klasse and RAID_CLASS_COLORS[klasse]
  if c then return { c.r, c.g, c.b, 1 } end
  return F.text
end

function S.qualitaetsFarbe(q)
  if q and q >= 2 then
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return { c.r, c.g, c.b, 1 } end
  end
  return F.rand
end

function S.klick()
  if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
  end
end

-- Kleiner Pfeil nach unten (v), aus zwei gedrehten Strichen. Farbe(f) ändert die Farbe.
function S.winkel(parent, farbe)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(12, 8)
  f.links = f:CreateTexture(nil, "OVERLAY")
  f.links:SetSize(8, 2)
  f.links:SetPoint("CENTER", -2.6, 0)
  f.links:SetRotation(math.rad(-40))
  f.rechts = f:CreateTexture(nil, "OVERLAY")
  f.rechts:SetSize(8, 2)
  f.rechts:SetPoint("CENTER", 2.6, 0)
  f.rechts:SetRotation(math.rad(40))
  function f:Farbe(c)
    self.links:SetColorTexture(rgba(c))
    self.rechts:SetColorTexture(rgba(c))
  end
  f:Farbe(farbe or F.leise)
  return f
end

-- Stern für den Favoriten. Ohne Textur im Client bleibt ein gelber Punkt.
function S.stern(parent, groesse)
  local t = parent:CreateTexture(nil, "OVERLAY")
  t:SetSize(groesse, groesse)
  t:SetTexture(S.STERN)
  return t
end

-- Haken mit Text, rechts optional eine Zahl
function S.haken(parent, breite, text, hilfe, beiKlick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(breite, 20)
  b.kasten = S.kasten(b, "Frame", F.flaeche, F.rand)
  b.kasten:SetSize(14, 14)
  b.kasten:SetPoint("LEFT", 0, 0)
  b.fuellung = b.kasten:CreateTexture(nil, "OVERLAY")
  b.fuellung:SetPoint("TOPLEFT", 3, -3)
  b.fuellung:SetPoint("BOTTOMRIGHT", -3, 3)
  b.fuellung:SetColorTexture(rgba(F.akzent))
  b.name = S.schrift(b, "GameFontHighlightSmall", F.text)
  b.name:SetPoint("LEFT", b.kasten, "RIGHT", 6, 0)
  b.name:SetText(text)
  b.menge = S.schrift(b, "GameFontHighlightSmall", F.leise)
  b.menge:SetPoint("RIGHT", -4, 0)
  function b:Setzen(an)
    self.an = an and true or false
    self.fuellung:SetShown(self.an)
    S.randFarbe(self.kasten, self.an and F.akzent or F.rand)
  end
  b:SetScript("OnClick", function(self)
    S.klick()
    beiKlick(self, not self.an)
  end)
  b:HookScript("OnEnter", function(self) S.randFarbe(self.kasten, S.heller(F.akzent)) end)
  b:HookScript("OnLeave", function(self) S.randFarbe(self.kasten, self.an and F.akzent or F.rand) end)
  S.tooltip(b, text, hilfe)
  return b
end

-- Umschalter mit mehreren Feldern, eines davon aktiv
function S.segmente(parent, breite, optionen, beiWahl)
  local f = S.kasten(parent, "Frame", F.flaeche, F.rand)
  f:SetSize(breite, 22)
  local teil = (breite - 2) / #optionen
  f.knoepfe = {}
  for i, o in ipairs(optionen) do
    local b = CreateFrame("Button", nil, f)
    b:SetSize(teil, 20)
    b:SetPoint("LEFT", f, "LEFT", 1 + (i - 1) * teil, 0)
    b.grund = b:CreateTexture(nil, "ARTWORK")
    b.grund:SetAllPoints()
    b.text = S.schrift(b, "GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(o.text)
    b.wert, b.farbe = o.wert, o.farbe or F.akzent
    b:SetScript("OnClick", function() S.klick() beiWahl(o.wert) end)
    b:HookScript("OnEnter", function(self) self.text:SetTextColor(rgba(F.text)) end)
    b:HookScript("OnLeave", function() f:Setzen(f.wert) end)
    S.tooltip(b, o.text, o.hilfe)
    f.knoepfe[i] = b
  end
  function f:Setzen(wert)
    self.wert = wert
    for _, b in ipairs(self.knoepfe) do
      local an = b.wert == wert
      if an then b.grund:SetColorTexture(rgba(b.farbe)) else b.grund:SetColorTexture(0, 0, 0, 0) end
      b.text:SetTextColor(rgba(an and F.aufAkzent or F.leise))
    end
  end
  return f
end

-- Großer, gefüllter Knopf. Aussehen(text, farbe, an) setzt Text, Farbe und ob er klickbar ist.
function S.knopf(parent, breite, hoehe)
  local b = S.kasten(parent, "Button", F.akzent, F.akzent)
  b:SetSize(breite, hoehe or 30)
  b.text = S.schrift(b, "GameFontHighlight", F.text)
  b.text:SetPoint("CENTER")
  b:HookScript("OnEnter", function(self) if self:IsEnabled() then S.grundFarbe(self, S.heller(self.farbe or F.akzent)) end end)
  b:HookScript("OnLeave", function(self) if self:IsEnabled() then S.grundFarbe(self, self.farbe or F.akzent) end end)
  function b:Aussehen(text, farbe, an)
    self.text:SetText(text)
    self.farbe = farbe
    if an then
      self:Enable()
      S.grundFarbe(self, farbe)
      S.randFarbe(self, farbe)
      self.text:SetTextColor(rgba(farbe == F.akzent and F.aufAkzent or F.text))
    else
      self:Disable()
      S.grundFarbe(self, F.flaeche)
      S.randFarbe(self, F.rand)
      self.text:SetTextColor(rgba(F.leise))
    end
  end
  b:Aussehen("", F.akzent, true)
  return b
end

-- Schlichter Knopf mit Rahmen, für Nebenaktionen
function S.textKnopf(parent, text, breite, beiKlick)
  local b = S.kasten(parent, "Button", F.flaeche, F.rand)
  b:SetSize(breite, 22)
  b.text = S.schrift(b, "GameFontHighlightSmall", F.text)
  b.text:SetPoint("CENTER")
  b.text:SetText(text)
  b:HookScript("OnEnter", function(self) if self:IsEnabled() then S.randFarbe(self, F.akzent) end end)
  b:HookScript("OnLeave", function(self) S.randFarbe(self, self.randFarbe or F.rand) end)
  b:SetScript("OnClick", function(self) S.klick() beiKlick(self) end)
  function b:Aktiv(an)
    if an then self:Enable() self.text:SetTextColor(rgba(F.text)) else self:Disable() self.text:SetTextColor(rgba(F.leise)) end
  end
  return b
end

-- Kleiner Knopf mit einem Zeichen (Schließen, Einklappen, Einstellungen)
function S.zeichenKnopf(parent, zeichen, beiKlick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(22, 22)
  b.text = S.schrift(b, "GameFontHighlightLarge", F.leise)
  b.text:SetPoint("CENTER")
  b.text:SetText(zeichen)
  b:HookScript("OnEnter", function() b.text:SetTextColor(rgba(F.text)) end)
  b:HookScript("OnLeave", function() b.text:SetTextColor(rgba(F.leise)) end)
  b:SetScript("OnClick", function() S.klick() beiKlick() end)
  return b
end

-- Kopfzeile mit Icon, Titel und Untertitel. Gibt die Höhe zurück.
function S.kopf(parent, untertitel)
  local kopf = parent:CreateTexture(nil, "BORDER")
  kopf:SetPoint("TOPLEFT", 1, -1)
  kopf:SetPoint("TOPRIGHT", -1, -1)
  kopf:SetHeight(44)
  kopf:SetColorTexture(rgba(F.kopf))
  if CreateColor and kopf.SetGradient then
    pcall(kopf.SetGradient, kopf, "VERTICAL", CreateColor(0.09, 0.05, 0.06, 1), CreateColor(0.24, 0.11, 0.07, 1))
  end
  local linie = parent:CreateTexture(nil, "ARTWORK")
  linie:SetPoint("TOPLEFT", 1, -45)
  linie:SetPoint("TOPRIGHT", -1, -45)
  linie:SetHeight(1)
  linie:SetColorTexture(rgba(F.akzent))
  local icon = parent:CreateTexture(nil, "ARTWORK")
  icon:SetSize(28, 28)
  icon:SetPoint("TOPLEFT", 10, -8)
  S.markeSetzen(icon)
  S.abzeichen(parent, icon, 15)
  local titel = S.schrift(parent, "GameFontNormalLarge", F.text)
  titel:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -1)
  titel:SetText(ns.TITEL)
  local unter = S.schrift(parent, "GameFontHighlightSmall", F.leise)
  unter:SetPoint("TOPLEFT", titel, "BOTTOMLEFT", 0, -2)
  unter:SetText(untertitel)
  return 46
end

-- Fortschrittsbalken mit zweiter, heller Füllung dahinter (Erfahrung und Erholungsbonus).
-- Setzen(anteil, zweiter) mit Werten zwischen 0 und 1.
function S.balken(parent, breite, hoehe)
  local b = S.kasten(parent, "Frame", F.flaeche, F.rand)
  b:SetSize(breite, hoehe)
  b.zweit = b:CreateTexture(nil, "ARTWORK", nil, 1)
  b.zweit:SetPoint("TOPLEFT", 1, -1)
  b.zweit:SetPoint("BOTTOMLEFT", 1, 1)
  b.zweit:SetColorTexture(rgba(F.erholt))
  b.voll = b:CreateTexture(nil, "ARTWORK", nil, 2)
  b.voll:SetPoint("TOPLEFT", 1, -1)
  b.voll:SetPoint("BOTTOMLEFT", 1, 1)
  b.voll:SetColorTexture(rgba(F.akzent))
  local innen = breite - 2
  local function breiteVon(anteil)
    return math.max(0.001, math.min(1, anteil or 0)) * innen
  end
  function b:Setzen(anteil, zweiter)
    self.voll:SetWidth(breiteVon(anteil))
    self.voll:SetShown((anteil or 0) > 0)
    self.zweit:SetWidth(breiteVon(zweiter))
    self.zweit:SetShown((zweiter or 0) > (anteil or 0))
  end
  b:Setzen(0, 0)
  return b
end

function S.schatten(parent)
  local t = parent:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetPoint("TOPLEFT", -4, 4)
  t:SetPoint("BOTTOMRIGHT", 4, -4)
  t:SetColorTexture(0, 0, 0, 0.35)
  return t
end

-- Liste, die mit dem Mausrad rollt. Es gibt nur so viele Zeilen-Rahmen wie sichtbar sind.
-- bauen(liste, i) erzeugt eine Zeile, fuellen(zeile, eintrag) zeigt einen Eintrag darin.
function S.liste(parent, breite, hoehe, zeilenHoehe, bauen)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(breite, hoehe)
  f.zeilen, f.daten, f.versatz = {}, {}, 0
  f.sichtbar = math.floor(hoehe / zeilenHoehe)
  for i = 1, f.sichtbar do
    local z = bauen(f, i)
    z:SetSize(breite - 6, zeilenHoehe)
    z:SetPoint("TOPLEFT", 0, -(i - 1) * zeilenHoehe)
    f.zeilen[i] = z
  end
  f.balken = f:CreateTexture(nil, "OVERLAY")
  f.balken:SetWidth(3)
  f.balken:SetColorTexture(F.akzent[1], F.akzent[2], F.akzent[3], 0.6)
  f.leer = S.absatz(f, breite - 20, F.leise)
  f.leer:SetPoint("TOPLEFT", 4, -6)
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(self, delta) self:Rollen(-delta) end)

  function f:Setzen(daten, fuellen, leerText)
    self.daten, self.fuellen = daten, fuellen
    self.leer:SetText(#daten == 0 and (leerText or "") or "")
    self:Rollen(0)
  end
  function f:Rollen(schritte)
    local hoechster = math.max(0, #self.daten - self.sichtbar)
    self.versatz = math.min(math.max(self.versatz + schritte, 0), hoechster)
    for i, z in ipairs(self.zeilen) do
      local eintrag = self.daten[i + self.versatz]
      z.eintrag = eintrag
      if eintrag then z:Show() self.fuellen(z, eintrag) else z:Hide() end
    end
    if hoechster > 0 then
      local bh = math.max(12, hoehe * self.sichtbar / #self.daten)
      self.balken:SetHeight(bh)
      self.balken:ClearAllPoints()
      self.balken:SetPoint("TOPRIGHT", 0, -((hoehe - bh) * self.versatz / hoechster))
      self.balken:Show()
    else
      self.balken:Hide()
    end
  end
  return f
end

-- Zeile für Listen: Hintergrund beim Überfahren, zwei Textzeilen
function S.zeile(parent)
  local z = CreateFrame("Button", nil, parent)
  z.hell = z:CreateTexture(nil, "BACKGROUND")
  z.hell:SetAllPoints()
  z.hell:SetColorTexture(F.akzent[1], F.akzent[2], F.akzent[3], 0.12)
  z.hell:Hide()
  z.wahl = z:CreateTexture(nil, "BACKGROUND", nil, 1)
  z.wahl:SetPoint("TOPLEFT")
  z.wahl:SetPoint("BOTTOMLEFT")
  z.wahl:SetWidth(3)
  z.wahl:SetColorTexture(rgba(F.akzent))
  z.wahl:Hide()
  z:HookScript("OnEnter", function(self) self.hell:Show() end)
  z:HookScript("OnLeave", function(self) self.hell:Hide() end)
  return z
end


-- Weicher Puls über eine Animation des Spiels: Alpha schwillt zwischen von und bis an und ab.
-- Gibt die Animationsgruppe zurück (oder nil). S.puls(gruppe, an) startet oder stoppt sie.
function S.pulsieren(region, von, bis, dauer)
  if not (region and region.CreateAnimationGroup) then return nil end
  local gruppe = region:CreateAnimationGroup()
  if not (gruppe and gruppe.CreateAnimation) then return nil end
  gruppe:SetLooping("BOUNCE")
  local a = gruppe:CreateAnimation("Alpha")
  if not a then return nil end
  a:SetFromAlpha(von)
  a:SetToAlpha(bis)
  a:SetDuration(dauer)
  if a.SetSmoothing then a:SetSmoothing("IN_OUT") end
  gruppe.region = region
  return gruppe
end

function S.puls(gruppe, an)
  if not gruppe then return end
  if an then
    if not gruppe:IsPlaying() then gruppe:Play() end
  elseif gruppe:IsPlaying() then
    gruppe:Stop()
    gruppe.region:SetAlpha(0)
  end
end

-- Runder Fleck (Funke, Marshmallow, Schatten). Die runde Porträt-Maske des Spiels ist selbst ein
-- weißer Kreis: als Bild genommen und eingefärbt, mit weicher Kante. Als Maske griff sie in der
-- Beta nur grob (eckiger Feuerschein, Treppenkanten, 14. Okt).
S.KREIS = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
function S.kreis(parent, breite, hoehe, farbe, ebene, leuchten)
  local t = parent:CreateTexture(nil, ebene or "ARTWORK")
  t:SetSize(breite, hoehe or breite)
  t:SetTexture(S.KREIS)
  t:SetVertexColor(rgba(farbe or F.text))
  if leuchten and t.SetBlendMode then t:SetBlendMode("ADD") end
  return t
end

-- Weicher Schein: drei Kreise übereinander, außen groß und schwach, innen klein und kräftiger.
-- Gibt eine Gruppe zurück, die sich wie eine Textur bewegen und einfärben lässt.
function S.glut(parent, breite, hoehe, farbe, ebene)
  local g = { teile = {} }
  -- vier Kreise: außen groß und schwach, innen klein und kräftiger, ergibt einen weichen Rand
  local stufen = { { 1, 0.16 }, { 0.75, 0.22 }, { 0.5, 0.3 }, { 0.28, 0.4 } }
  for i, s in ipairs(stufen) do
    local t = S.kreis(parent, breite * s[1], hoehe * s[1], farbe, ebene or "BORDER", true)
    t:SetAlpha(s[2])
    t.basis = s[2]
    g.teile[i] = t
  end
  function g:SetPoint(...) for _, t in ipairs(self.teile) do t:ClearAllPoints() t:SetPoint(...) end end
  function g:SetAlpha(a) for _, t in ipairs(self.teile) do t:SetAlpha(a * t.basis * 1.6) end end
  function g:SetShown(an) for _, t in ipairs(self.teile) do t:SetShown(an) end end
  return g
end

-- Farbe zwischen zwei Farben, anteil 0 bis 1
function S.mischen(a, b, anteil)
  anteil = math.max(0, math.min(1, anteil))
  return { a[1] + (b[1] - a[1]) * anteil, a[2] + (b[2] - a[2]) * anteil, a[3] + (b[3] - a[3]) * anteil, 1 }
end

-- Sprechblase: kleiner Kasten mit Text, passt seine Breite an
function S.blase(parent)
  local b = S.kasten(parent, "Frame", { 0.98, 0.95, 0.86, 0.95 }, { 0.30, 0.22, 0.20, 1 })
  b:SetSize(80, 22)
  b.text = S.schrift(b, "GameFontNormalSmall", { 0.15, 0.10, 0.08, 1 })
  b.text:SetPoint("CENTER")
  function b:Zeigen(text)
    self.text:SetText(text)
    local breite = (self.text.GetStringWidth and self.text:GetStringWidth()) or 60
    if type(breite) ~= "number" or breite <= 0 then breite = 60 end
    self:SetWidth(breite + 16)
    self:Show()
  end
  b:Hide()
  return b
end