-- Lager-Check (Patricks Idee, 18. Okt): kleines Fenster am linken Bildschirmrand, solange man an
-- einem Lagerfeuer ist, nur außerhalb des Kampfes. Es sagt, ob sich das Hinsetzen lohnt, und listet:
--   Du bekommst: Boni dieses Feuers, die du noch nicht hast, oder eine stärkere Stufe
--   Du verlierst: Boni deiner jetzigen Camp Benefits, die es hier nicht gibt (Hinsetzen ersetzt
--                 Camp Benefits ganz), oder eine schwächere Stufe
--   Bleibt: Boni, die du schon hast
--   Nicht mehr gesehen: Objekte, die länger als FRISCH Sekunden niemand bestätigt hat. Sie können
--                 längst weg sein (Patrick, 18. Okt: Fish Bowl war verschwunden, der Check sagte
--                 trotzdem "You keep: All stats", und das Hinsetzen nahm ihm die 8 %). Hängt das
--                 Urteil an ihnen, heißt es "erst mit der Maus nachsehen".
-- Bewertet nach Klasse und Spec (Empfehlung.lua): ein Bonus, der dir kaum nützt oder den dein
-- Klassen-Buff abdeckt, zählt fast nichts. Laufen die Camp Benefits bald aus, lohnt sich das
-- Hinsetzen schon wegen der Zeit. Objekte kennt Campfire Buddy aus Maus, Aufstellen und Kampflog
-- (Lager.lua). Fehlen noch Plätze, sagt das Fenster, dass man mit der Maus über die Objekte fährt.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba
local O, LG = ns.Objekte, ns.Lager

local C = {}
ns.LagerCheck = C

local BREITE, RAND = 260, 10
-- Kopf: "Camp check" links, das Feuer rechts daneben. Passt beides nicht nebeneinander, wird das
-- Fenster breiter (bis BREITE_MAX), sonst steht das Feuer in einer eigenen Zeile darunter (Patrick,
-- 18. Okt: "Journeyman Campfire, 5 of 5 known" lief in die Überschrift)
local BREITE_MAX, KOPF_ABSTAND = 340, 12
-- Plätze am Feuer als Symbole unter der Überschrift (Patrick, 18. Okt: "schnell und einfach
-- überblickbar, wie die Gegenstände aussehen"), wie im Reiter Camp, nur kleiner
local MAX_PLAETZE, PLATZ, PLATZ_ABSTAND = 10, 22, 24
local RAND_GRAU = { 0.38, 0.38, 0.42, 1 }
-- Gewicht eines Bonus nach Nutzen für den Char (Empfehlung: 2 gut, 1 etwas, 0 kaum)
local GEWICHT = { [0] = 0.15, [1] = 0.5, [2] = 1 }
local BALD = 10 * 60   -- Camp Benefits unter 10 Minuten: Hinsetzen lohnt schon wegen der Zeit
local FRISCH = 90      -- Sekunden: so lange gilt ein Objekt nach dem letzten Bestätigen als sicher da

local function imKampf() return InCombatLockdown and InCombatLockdown() end

local function farbe(c, text)
  local function k(v) return math.floor(v * 255 + 0.5) end
  return string.format("|cff%02x%02x%02x%s|r", k(c[1]), k(c[2]), k(c[3]), text)
end
local function symbol(o)
  local _, icon = O.Anzeige(o)
  return "|T" .. tostring(icon) .. ":14:14|t "
end

-- Ist das Objekt kürzlich bestätigt worden? Vermutungen aus Bonus-Buffs zählen nie als sicher.
function C.Sicher(e)
  return e.genau and (LG.Zeit() - (e.gesehen or e.zeit or 0)) <= FRISCH or false
end

local function bewerten(netto) return netto > 0.25 and "lohnt" or (netto < -0.25 and "nicht" or "gleich") end

-- Vergleich dieses Feuers mit den jetzigen Camp Benefits. Hinsetzen ersetzt Camp Benefits ganz:
-- Man bekommt genau die Boni der Objekte, die beim Hinsetzen noch stehen. Rückgabe: Tabelle mit
-- neu, weg, gleich, unsicher (lange nicht gesehen), bestens und schlimmstens (Bewertung, wenn alle
-- unsicheren noch stehen bzw. alle weg sind), rest (Sekunden oder nil), plaetze, bekannt, urteil
function C:Rechnen()
  local EM = ns.Empfehlung
  local typ, _, klasse = EM:Rolle()
  local benefits = LG:Benefits()
  local r = { neu = {}, weg = {}, gleich = {}, unsicher = {}, bestens = 0, schlimmstens = 0 }
  local function gewicht(fam, o)
    local gedeckt = O.Konflikt(o)
    if gedeckt then return 0, gedeckt end
    return GEWICHT[EM:Nutzen(fam, typ, klasse)] or 0.5
  end
  local zaehlt = {}
  for _, fam in ipairs(O.BONUS_REIHE) do zaehlt[fam] = true end
  for fam, e in pairs(LG.objekte) do
    if zaehlt[fam] then
      local b = benefits[fam]
      local g, gedeckt = gewicht(fam, e.o)
      local eintrag = { fam = fam, o = e.o, gewicht = g, gedeckt = gedeckt }
      -- Beitrag, wenn das Objekt beim Hinsetzen noch steht, und wenn es weg ist (dann ist auch
      -- der Bonus weg, den man jetzt hat)
      local steht
      if b and b.o and LG.Rang(e.o) > LG.Rang(b.o) then
        eintrag.staerker, steht = true, g * 0.5
      elseif b and b.o and LG.Rang(e.o) < LG.Rang(b.o) then
        eintrag.o, eintrag.wert, eintrag.schwaecher, steht = b.o, b.wert, true, -g * 0.5
      elseif b or O.BonusAktiv(e.o) then
        steht = 0
      else
        steht = g
      end
      local weg = b and -g or 0
      if C.Sicher(e) then
        table.insert(steht > 0 and r.neu or (steht < 0 and r.weg or r.gleich), eintrag)
        r.bestens, r.schlimmstens = r.bestens + steht, r.schlimmstens + steht
      else
        eintrag.unsicher = true
        table.insert(r.unsicher, eintrag)
        r.bestens = r.bestens + math.max(steht, weg)
        r.schlimmstens = r.schlimmstens + math.min(steht, weg)
      end
    end
  end
  for fam, b in pairs(benefits) do
    if zaehlt[fam] and not LG.objekte[fam] and b.o then
      local g, gedeckt = gewicht(fam, b.o)
      table.insert(r.weg, { fam = fam, o = b.o, wert = b.wert, gewicht = g, gedeckt = gedeckt })
      r.bestens, r.schlimmstens = r.bestens - g, r.schlimmstens - g
    end
  end
  local nachGewicht = function(a, b) return a.gewicht > b.gewicht end
  table.sort(r.neu, nachGewicht)
  table.sort(r.weg, nachGewicht)
  table.sort(r.unsicher, nachGewicht)

  local cb = (ns.Buffs.ids or {})[ns.CAMP_BENEFITS]
  if type(cb) == "table" and cb.ende then r.rest = math.max(0, cb.ende - ns.jetzt()) end
  r.plaetze, r.bekannt = LG:Plaetze()

  if not r.rest then
    r.urteil = "ohne"
  elseif r.rest < BALD then
    r.urteil = r.bestens < -0.5 and "zeit" or "bald"
  else
    -- Erst nachsehen nur, wenn Hinsetzen etwas bringen kann, aber auch etwas kosten könnte.
    -- Bringt es bestenfalls nichts, lohnt es nicht (gleich nach dem Hinsetzen sind alle Objekte
    -- bald "lange nicht gesehen", das soll nicht ständig zum Nachsehen drängen).
    local gut, schlecht = bewerten(r.bestens), bewerten(r.schlimmstens)
    if gut == schlecht then r.urteil = gut
    elseif gut == "lohnt" then r.urteil = "pruefen"
    else r.urteil = schlecht == "nicht" and "nicht" or gut end
  end
  return r
end

local URTEIL = {
  ohne = { "CHECK_NO_BENEFITS", "erfolg" }, bald = { "CHECK_SOON", "erfolg" }, lohnt = { "CHECK_WORTH", "erfolg" },
  zeit = { "CHECK_TIME_ONLY", "hinweis" }, gleich = { "CHECK_SAME", "leise" }, nicht = { "CHECK_NOT", "fehler" },
  pruefen = { "CHECK_CHECK", "hinweis" },
}

-- Eine Zeile für "Du bekommst" oder "Du verlierst": Symbol, Wert für dein Level, Zusatz
local function zeile(e, verlieren)
  local bonus = O.FAMILIE[e.fam] and O.FAMILIE[e.fam].bonus or ""
  local wert
  if verlieren and e.wert then wert = string.format(L.TT_VALUE, e.wert, bonus)
  else wert = O.WertFuerMich(e.o) or bonus end
  local zusatz = ""
  if e.gedeckt then zusatz = " " .. string.format(L.CHECK_COVERED, e.gedeckt)
  elseif e.staerker then zusatz = " " .. L.CHECK_STRONGER
  elseif e.schwaecher then zusatz = " " .. L.CHECK_WEAKER
  elseif e.gewicht < 0.5 then zusatz = " " .. L.CHECK_LITTLE_USE end
  local c = verlieren and F.fehler or F.erfolg
  if e.gedeckt or e.gewicht < 0.5 then c = F.leise end
  return symbol(e.o) .. farbe(c, wert) .. farbe(F.leise, zusatz)
end

function C:Bauen()
  if self.rahmen then return end
  local f = S.kasten(UIParent, "Frame", F.grund, F.rand, "CampfireBuddyCheck")
  self.rahmen = f
  f:SetWidth(BREITE)
  ns.Leiste.Position(f, ns.db.check, "TOPLEFT", UIParent, "LEFT", 16, 120)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  -- Immer verschiebbar, auch wenn die Leisten gesperrt sind (Patrick, 18. Okt: "Lock the bar"
  -- war an, und das Fenster ließ sich nicht bewegen). Es ist keine Leiste.
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    ns.db.check = ns.Leiste.Merken(self)
  end)
  S.tooltip(f, L.CHECK_TITLE, L.CHECK_DRAG)
  f.titel = S.schrift(f, "GameFontNormal")
  f.titel:SetPoint("TOPLEFT", RAND, -RAND)
  f.titel:SetText(L.CHECK_TITLE)
  f.feuer = S.schrift(f, "GameFontHighlightSmall", F.leise)
  f.feuer:SetPoint("TOPRIGHT", -RAND, -RAND - 1)
  -- Plätze: belegt mit dem Symbol des Objekts, frei als leerer Kasten. Grüner Rand: eben gesehen,
  -- grau und blass: lange nicht gesehen oder nur vermutet. Maus drüber: Tooltip wie im Spiel.
  f.plaetze = {}
  for i = 1, MAX_PLAETZE do
    local p = S.spielKasten(f, "Frame")
    p:SetSize(PLATZ, PLATZ)
    p:SetPoint("TOPLEFT", f.titel, "BOTTOMLEFT", (i - 1) * PLATZ_ABSTAND, -6)
    p.leer = p:CreateTexture(nil, "BACKGROUND", nil, 1)
    p.leer:SetPoint("TOPLEFT", 2, -2)
    p.leer:SetPoint("BOTTOMRIGHT", -2, 2)
    p.leer:SetTexture("Interface\\Buttons\\UI-Slot-Background")
    p.leer:SetTexCoord(0, 0.640625, 0, 0.640625)
    p.icon = p:CreateTexture(nil, "ARTWORK")
    p.icon:SetPoint("TOPLEFT", 2, -2)
    p.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    p:EnableMouse(true)
    O.TooltipAn(p, function(self) return self.eintrag and self.eintrag.o end, function(self, tt)
      if self.eintrag and not C.Sicher(self.eintrag) then
        tt:AddLine(" ")
        tt:AddLine(L.CHECK_SLOT_STALE, F.leise[1], F.leise[2], F.leise[3], true)
      end
    end, L.CAMP_SLOT_FREE)
    p:Hide()
    f.plaetze[i] = p
  end
  f.urteil = S.absatz(f, BREITE - 2 * RAND, F.erfolg, "GameFontNormalLarge")
  f.urteil:SetPoint("TOPLEFT", f.titel, "BOTTOMLEFT", 0, -6)
  f.text = S.absatz(f, BREITE - 2 * RAND, F.text, "GameFontHighlightSmall")
  f.text:SetPoint("TOPLEFT", f.urteil, "BOTTOMLEFT", 0, -6)
  f:Hide()
end

function C:Aktualisieren()
  if not ns.db then return end
  local zeigen = ns.db.checkZeigen and LG.aktiv and not imKampf()
  if not zeigen then
    if self.rahmen then self.rahmen:Hide() end
    return
  end
  self:Bauen()
  local f = self.rahmen
  local r = self:Rechnen()
  self.ergebnis = r

  local feuer = LG.feuer and (O.Anzeige(LG.feuer.o)) or L.MAP_FIRE
  f.feuer:SetText(r.plaetze and string.format(L.CHECK_SLOTS, feuer, r.bekannt, r.plaetze) or feuer)
  local noetig = 2 * RAND + (f.titel:GetStringWidth() or 0) + KOPF_ABSTAND + (f.feuer:GetStringWidth() or 0)
  local breite, kopf = BREITE, 0
  f.feuer:ClearAllPoints()
  if noetig <= BREITE_MAX then
    breite = math.max(BREITE, math.ceil(noetig))
    f.feuer:SetPoint("TOPRIGHT", -RAND, -RAND - 1)
  else
    f.feuer:SetPoint("TOPLEFT", f.titel, "BOTTOMLEFT", 0, -2)
    kopf = (f.feuer:GetStringHeight() or 12) + 2
  end
  f:SetWidth(breite)
  f.urteil:SetWidth(breite - 2 * RAND)
  f.text:SetWidth(breite - 2 * RAND)
  f.kopf = kopf
  -- Plätze: so viele wie das Feuer hat, bei unbekannter Größe so viele wie bekannt, mindestens 3
  local objekte = {}
  for _, e in pairs(LG.objekte) do table.insert(objekte, e) end
  table.sort(objekte, function(a, b) return tostring(a.o.spell) < tostring(b.o.spell) end)
  local zeigen = math.min(MAX_PLAETZE, r.plaetze or math.max(3, #objekte))
  for i, p in ipairs(f.plaetze) do
    local e = objekte[i]
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", f.titel, "BOTTOMLEFT", (i - 1) * PLATZ_ABSTAND, -6 - kopf)
    p:SetShown(i <= zeigen)
    p.eintrag = e
    if e then
      local _, icon = O.Anzeige(e.o)
      local sicher = C.Sicher(e)
      p.icon:SetTexture(icon)
      p.icon:SetDesaturated(not sicher)
      p.icon:SetAlpha(sicher and 1 or 0.6)
      p.icon:Show()
      S.randFarbe(p, sicher and F.erfolg or RAND_GRAU)
    else
      p.icon:Hide()
      S.randFarbe(p, RAND_GRAU)
    end
  end
  f.urteil:ClearAllPoints()
  f.urteil:SetPoint("TOPLEFT", f.titel, "BOTTOMLEFT", 0, -(6 + kopf + (zeigen > 0 and PLATZ + 6 or 0)))
  f.platzHoehe = zeigen > 0 and PLATZ + 6 or 0
  local u = URTEIL[r.urteil]
  f.urteil:SetText(L[u[1]])
  f.urteil:SetTextColor(rgba(F[u[2]]))

  local zeilen = {}
  local function abschnitt(titel, liste, verlieren)
    if #liste == 0 then return end
    table.insert(zeilen, farbe(F.hinweis, titel))
    for _, e in ipairs(liste) do table.insert(zeilen, "  " .. zeile(e, verlieren)) end
  end
  abschnitt(L.CHECK_GET, r.neu, false)
  abschnitt(L.CHECK_LOSE, r.weg, true)
  if #r.gleich > 0 then
    local namen = {}
    for _, e in ipairs(r.gleich) do table.insert(namen, symbol(e.o) .. O.FAMILIE[e.fam].bonus) end
    table.insert(zeilen, farbe(F.hinweis, L.CHECK_KEEP) .. " " .. farbe(F.leise, table.concat(namen, ", ")))
  end
  if #r.unsicher > 0 then
    local namen = {}
    for _, e in ipairs(r.unsicher) do table.insert(namen, symbol(e.o) .. O.FAMILIE[e.fam].bonus) end
    table.insert(zeilen, farbe(F.hinweis, L.CHECK_MAYBE) .. " " .. farbe(F.leise, table.concat(namen, ", ")))
  end
  if #r.neu == 0 and #r.weg == 0 and #r.gleich == 0 and #r.unsicher == 0 then
    table.insert(zeilen, farbe(F.leise, L.CHECK_NOTHING_KNOWN))
  end
  table.insert(zeilen, " ")
  if r.rest then
    table.insert(zeilen, farbe(F.leise, string.format(L.CHECK_TIME, math.floor(r.rest / 60 + 0.5))))
  else
    table.insert(zeilen, farbe(F.leise, L.CHECK_TIME_NONE))
  end
  local offen = r.plaetze and (r.plaetze - r.bekannt) or nil
  if r.urteil == "pruefen" then
    table.insert(zeilen, farbe(F.hinweis, string.format(L.CHECK_STALE, #r.unsicher)))
  elseif offen and offen > 0 then
    table.insert(zeilen, farbe(F.hinweis, string.format(L.CHECK_HOVER, offen)))
  elseif not r.plaetze and r.bekannt == 0 then
    table.insert(zeilen, farbe(F.hinweis, L.CHECK_HOVER_ALL))
  end
  f.text:SetText(table.concat(zeilen, "\n"))

  local hoehe = RAND + 14 + 6 + (f.kopf or 0) + (f.platzHoehe or 0) + (f.urteil:GetStringHeight() or 18) + 6 + (f.text:GetStringHeight() or 60) + RAND
  f:SetHeight(math.max(80, hoehe))
  f:Show()
end

ns.beimAktualisieren(function() C:Aktualisieren() end)
ns.ereignis("PLAYER_REGEN_DISABLED", function() if C.rahmen then C.rahmen:Hide() end end)
ns.ereignis("PLAYER_REGEN_ENABLED", function() C:Aktualisieren() end)
