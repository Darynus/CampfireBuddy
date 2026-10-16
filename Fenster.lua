-- Hauptfenster: Status, Camp, Buffs, Camp kit, Settings, Help.
-- Öffnen mit /campfire, Rechtsklick auf die Leiste, Minikarten-Knopf oder Optionen-Menü.
-- Aussehen wie die Fenster des Spiels (Patrick, 16. Okt: "was Authentisches"): Porträtrahmen mit
-- Titelleiste, versenkte Innenfläche, Reiter unten, rote Knöpfe, Haken und Auswahlknöpfe aus dem
-- Client. Fehlt eine dieser Vorlagen, baut das Fenster sich wie früher flach selbst.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba

local W = { seiten = {} }
ns.Fenster = W

-- Maße: werden in W:Bauen je nach Aufbau gesetzt (echt oder flach)
local BREITE, HOEHE = 640, 460
local SEITE = 150
local X = SEITE + 16
local B = BREITE - X - 16
local OBEN = -60
local UNTEN = 16

local REITER = {
  { schluessel = "status", text = L.TAB_STATUS },
  { schluessel = "lager", text = L.TAB_CAMP },
  { schluessel = "buffs", text = L.TAB_BUFFS },
  { schluessel = "kit", text = L.TAB_KIT },
  { schluessel = "einstellungen", text = L.TAB_SETTINGS },
  { schluessel = "hilfe", text = L.TAB_HELP },
}

local function seite(schluessel)
  local f = CreateFrame("Frame", nil, W.rahmen)
  f:SetPoint("TOPLEFT", X, OBEN)
  f:SetSize(B, HOEHE + OBEN - UNTEN)
  -- Über der versenkten Fläche des echten Fensters
  if W.echt then f:SetFrameLevel((W.rahmen:GetFrameLevel() or 1) + 4) end
  f:Hide()
  W.seiten[schluessel] = f
  return f
end

local function uhrzeit(rest)
  return date("%H:%M", time() + math.floor(rest))
end

-- Seite: Status ------------------------------------------------------------------------

local function bauenStatus()
  local f = seite("status")
  S.ueberschrift(f, L.STATUS_TITLE):SetPoint("TOPLEFT", 0, 0)
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(40, 40)
  f.icon:SetPoint("TOPLEFT", 0, -18)
  f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.zeit = S.schrift(f, "GameFontNormalLarge", F.akzent)
  f.zeit:SetPoint("TOPLEFT", 52, -20)
  f.ende = S.schrift(f, "GameFontHighlightSmall", F.leise)
  f.ende:SetPoint("TOPLEFT", 52, -42)
  f.balken = S.balken(f, B, 16, true)
  f.balken:SetPoint("TOPLEFT", 0, -64)
  f.hilfe = S.absatz(f, B, F.leise)
  f.hilfe:SetPoint("TOPLEFT", 0, -84)

  -- Kein Feuer in der Nähe: sagen, wie der Char selbst eins bekommt, mit Knopf zum Anzünden
  f.feuer = S.absatz(f, B - 170, F.text)
  f.feuer:SetPoint("TOPLEFT", 0, -130)
  f.feuerKnopf = S.textKnopf(f, "", 160, function()
    local o, z = ns.Objekte.BestesFeuer()
    if o and z == "bereit" then ns.Kit:Craften(o) end
  end)
  f.feuerKnopf:SetPoint("TOPRIGHT", 0, -128)
  S.tooltip(f.feuerKnopf, function() return f.feuerKnopf.text:GetText() end, L.FIRE_BTN_HELP)

  S.ueberschrift(f, L.FOOD_TITLE):SetPoint("TOPLEFT", 0, -168)
  f.essen = S.schrift(f, "GameFontHighlight", F.text)
  f.essen:SetPoint("TOPLEFT", 0, -184)
  f.essenHilfe = S.absatz(f, B - 190, F.leise)
  f.essenHilfe:SetPoint("TOPLEFT", 0, -202)
  -- Nur wenn nötig: eben gegessen, aber nicht erkannt. Oder falsch markiert.
  f.essenKnopf = S.textKnopf(f, "", 180, function()
    local a = ns.Buffs:EssenKandidat() or ns.Buffs:EssenMarkiert()
    if not a then return end
    local an = ns.Buffs:EssenUmschalten(a)
    ns.melde(string.format(an and L.MSG_FOOD_MARKED or L.MSG_FOOD_UNMARKED, a.name or a.id))
    W:Aktualisieren()
    ns.aktualisieren()
  end)
  f.essenKnopf:SetPoint("TOPRIGHT", 0, -182)
  S.tooltip(f.essenKnopf, L.FOOD_TITLE, L.FOOD_MARK_HELP)

  S.ueberschrift(f, L.OTHER_TRACKED):SetPoint("TOPLEFT", 0, -250)
  f.andere = S.absatz(f, B, F.text)
  f.andere:SetPoint("TOPLEFT", 0, -266)

  function f:Aktualisieren()
    local lager = ns.Buffs:Lager()
    local rest = ns.Buffs.Rest(lager)
    if lager then
      self.icon:SetTexture(lager.icon or S.LAGER)
      self.icon:SetDesaturated(false)
      self.zeit:SetText(rest and ns.dauerText(rest) or L.NO_TIMER)
      self.zeit:SetTextColor(rgba(F.akzent))
      self.ende:SetText(rest and string.format(L.ENDS_AT, uhrzeit(rest)) or "")
      self.balken:Setzen(rest and lager.dauer > 0 and rest / lager.dauer or 1, 0)
      -- Welche Boni das Lager gerade gibt (Namen vom Spiel, also in jeder Sprache richtig)
      local boni = ns.Objekte.AktiveBoni()
      self.hilfe:SetText(#boni > 0 and string.format(L.STATUS_BONUSES, table.concat(boni, ", ")) or "")
    else
      self.icon:SetTexture(S.LAGER)
      self.icon:SetDesaturated(true)
      self.zeit:SetText(L.STATUS_NONE)
      self.zeit:SetTextColor(rgba(F.leise))
      self.ende:SetText("")
      self.balken:Setzen(0, 0)
      self.hilfe:SetText(L.STATUS_NONE_HELP)
    end
    local amFeuer = ns.Buffs.amFeuer
    local text, anzuenden = L.STATUS_NEARBY, nil
    if not amFeuer then
      local Ob = ns.Objekte
      local o, z = Ob.BestesFeuer()
      if not o then
        text = L.STATUS_NOT_NEARBY .. " " .. L.FIRE_LEARN_COOKING
      elseif z == "vorrat" then
        text = string.format(L.FIRE_IN_BAGS, (Ob.Anzeige(o)))
      elseif z == "bereit" then
        text, anzuenden = string.format(L.FIRE_CAN_LIGHT, (Ob.Anzeige(o))), o
      else
        text = string.format(L.FIRE_NEED_MATS, (Ob.Anzeige(o)), Ob.MaterialText(o))
      end
    end
    self.feuer:SetText(text)
    self.feuer:SetTextColor(rgba(amFeuer and F.akzent or F.text))
    self.feuerKnopf:SetShown(anzuenden ~= nil)
    if anzuenden then
      self.feuerKnopf.text:SetText(ns.Kit.OffenerBeruf() == anzuenden.beruf and L.BTN_LIGHT_FIRE or L.BTN_OPEN_COOKING)
    end
    local essen = ns.Buffs:Essen()
    if essen then
      local r = ns.Buffs.Rest(essen)
      self.essen:SetText((essen.name or L.FOOD_BUFF) .. "   |cff8e9db8" .. (r and ns.dauerText(r) or L.NO_TIMER) .. "|r")
      self.essen:SetTextColor(rgba(F.erfolg))
      self.essenHilfe:SetText("")
    else
      self.essen:SetText(L.NO_FOOD_BUFF)
      self.essen:SetTextColor(rgba(F.hinweis))
      self.essenHilfe:SetText(L.FOOD_STATUS_HELP)
    end
    local kandidat, markiert = ns.Buffs:EssenKandidat(), ns.Buffs:EssenMarkiert()
    self.essenKnopf:SetShown(kandidat ~= nil or markiert ~= nil)
    if kandidat then
      self.essenKnopf.text:SetText(string.format(L.BTN_IS_FOOD, kandidat.name or kandidat.id))
    elseif markiert then
      self.essenKnopf.text:SetText(L.BTN_FORGET_FOOD)
    end
    local zeilen = {}
    for _, a in ipairs(ns.Buffs:Liste()) do
      if a.id ~= ns.CAMP_BENEFITS and not (essen and a.id == essen.id) then
        local r = ns.Buffs.Rest(a)
        table.insert(zeilen, (a.name or string.format(L.SPELL_ID, a.id)) .. "   |cff8e9db8" .. (r and ns.dauerText(r) or L.NO_TIMER) .. "|r")
      end
    end
    self.andere:SetText(#zeilen > 0 and table.concat(zeilen, "\n") or L.NONE_ACTIVE)
  end
end

-- Seite: Buffs -------------------------------------------------------------------------

-- verfolgt: Zeile in der Liste der verfolgten Buffs (dort kein Knopf Food, außer zum Zurücknehmen)
local function buffZeile(liste, breite, verfolgt)
  local z = S.zeile(liste)
  z.inVerfolgt = verfolgt
  z.icon = z:CreateTexture(nil, "ARTWORK")
  z.icon:SetSize(22, 22)
  z.icon:SetPoint("LEFT", 6, 0)
  z.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  z.name = S.schrift(z, "GameFontHighlight")
  z.name:SetPoint("LEFT", z.icon, "RIGHT", 8, 0)
  z.name:SetWidth(breite - 250)
  z.name:SetJustifyH("LEFT")
  z.name:SetWordWrap(false)
  z.id = S.schrift(z, "GameFontHighlightSmall", F.leise)
  z.id:SetPoint("RIGHT", -90, 0)
  z.knopf = S.textKnopf(z, "", 70, function(k)
    local e = k:GetParent().eintrag
    if not e then return end
    local an = ns.Buffs:Umschalten(e.id, e.name)
    if an ~= nil then ns.melde(string.format(an and L.MSG_TRACKED or L.MSG_UNTRACKED, e.name or e.id)) end
    W:Aktualisieren()
  end)
  z.knopf:SetPoint("RIGHT", -8, 0)
  z.knopf:SetHeight(20)
  z.fest = S.schrift(z, "GameFontHighlightSmall", F.leise)
  z.fest:SetPoint("RIGHT", -12, 0)
  -- "food" steht dort, wo sonst der Knopf Food ist, damit Track daneben frei bleibt
  z.essenFest = S.schrift(z, "GameFontHighlightSmall", F.erfolg)
  z.essenFest:SetPoint("RIGHT", -100, 0)
  return z
end

local function buffFuellen(z, e)
  z.icon:SetTexture(e.icon or S.LAGER)
  z.name:SetText(e.name or string.format(L.SPELL_ID, e.id))
  z.id:SetText(string.format(L.SPELL_ID, e.id))
  local fest = ns.STANDARD_BUFFS[e.id] ~= nil
  z.fest:SetShown(fest)
  z.fest:SetText(fest and L.TRACKED_DEFAULT or "")
  z.knopf:SetShown(not fest)
  z.knopf.text:SetText(ns.db.eigeneBuffs[e.id] and L.BTN_UNTRACK or L.BTN_TRACK)
  -- Als Essen erkannt: Hinweis statt Knopf (markieren geht auf der Status-Seite)
  local essen = ns.Buffs.IstEssen(e) and not fest
  z.essenFest:SetShown(essen)
  z.essenFest:SetText(L.FOOD_DETECTED)
end

local function bauenBuffs()
  local f = seite("buffs")
  S.ueberschrift(f, L.TRACKED_TITLE):SetPoint("TOPLEFT", 0, 0)
  f.verfolgt = S.liste(f, B, 28 * 4, 28, function(l) return buffZeile(l, B, true) end)
  f.verfolgt:SetPoint("TOPLEFT", 0, -16)

  S.ueberschrift(f, L.YOUR_BUFFS):SetPoint("TOPLEFT", 0, -144)
  f.neu = S.textKnopf(f, L.BTN_REFRESH, 80, function() W:Aktualisieren() end)
  f.neu:SetHeight(20)
  f.neu:SetPoint("TOPRIGHT", 0, -140)
  f.jetzt = S.liste(f, B, 28 * 6, 28, function(l) return buffZeile(l, B) end)
  f.jetzt:SetPoint("TOPLEFT", 0, -164)
  local hilfe = S.absatz(f, B, F.leise)
  hilfe:SetPoint("TOPLEFT", 0, -340)
  hilfe:SetText(L.YOUR_BUFFS_HELP)

  function f:Aktualisieren()
    local verfolgt = {}
    for id in pairs(ns.STANDARD_BUFFS) do
      local a = ns.Buffs.aktiv[id]
      table.insert(verfolgt, { id = id, name = a and a.name or L.NAME_CAMP_BENEFITS, icon = a and a.icon })
    end
    for id, name in pairs(ns.db.eigeneBuffs) do
      local a = ns.Buffs.aktiv[id]
      table.insert(verfolgt, { id = id, name = a and a.name or name, icon = a and a.icon })
    end
    table.sort(verfolgt, function(a, b)
      if (a.id == ns.CAMP_BENEFITS) ~= (b.id == ns.CAMP_BENEFITS) then return a.id == ns.CAMP_BENEFITS end
      return tostring(a.name) < tostring(b.name)
    end)
    self.verfolgt:Setzen(verfolgt, buffFuellen, "")
    local kampf = InCombatLockdown and InCombatLockdown()
    -- Nur Buffs mit Ablaufzeit: Aufspüren (Find Herbs), Lagerfeuer-Nähe und andere Dauer-Auren
    -- lassen sich nicht sinnvoll verfolgen
    local jetzt = {}
    for _, a in ipairs((ns.Buffs.Alle())) do
      if (a.dauer or 0) > 0 then table.insert(jetzt, a) end
    end
    self.jetzt:Setzen(jetzt, buffFuellen, kampf and L.MSG_COMBAT_LATER or L.NO_BUFFS)
  end
end

-- Seite: Camp kit (alle Lager-Objekte, wer sie baut, was sie geben, Material) --------------

local O = ns.Objekte
local REIHENFOLGE = { vorrat = 0, bereit = 1, material = 2, lernen = 3, stufe = 4, beruf = 5 }

local function bauenKit()
  local f = seite("kit")
  S.ueberschrift(f, L.KIT_TITLE_LONG):SetPoint("TOPLEFT", 0, 0)
  local text = S.absatz(f, B, F.leise)
  text:SetPoint("TOPLEFT", 0, -16)
  text:SetText(L.KIT_HELP)
  f.liste = S.liste(f, B, 46 * 6, 46, function(l)
    local z = S.zeile(l)
    z.icon = z:CreateTexture(nil, "ARTWORK")
    z.icon:SetSize(30, 30)
    z.icon:SetPoint("LEFT", 6, 0)
    z.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    z.name = S.schrift(z, "GameFontHighlight", F.text)
    z.name:SetPoint("TOPLEFT", 44, -4)
    z.zustand = S.schrift(z, "GameFontHighlightSmall", F.leise)
    z.zustand:SetPoint("TOPRIGHT", -10, -5)
    z.info = S.schrift(z, "GameFontHighlightSmall", F.leise)
    z.info:SetPoint("TOPLEFT", 44, -18)
    z.info:SetWidth(B - 140)
    z.info:SetJustifyH("LEFT")
    z.info:SetWordWrap(false)
    z.mats = S.schrift(z, "GameFontHighlightSmall", F.text)
    z.mats:SetPoint("TOPLEFT", 44, -31)
    z.mats:SetWidth(B - 140)
    z.mats:SetJustifyH("LEFT")
    z.mats:SetWordWrap(false)
    S.tooltip(z, function(self) return self.eintrag and O.Anzeige(self.eintrag.o) end, function(self)
      local e = self.eintrag
      if not e then return nil end
      local zeilen = { e.o.info }
      local basis = O.BASIS[e.o.familie]
      if basis and basis ~= e.o and e.o.art ~= "feuer" then
        table.insert(zeilen, string.format(L.KIT_REPLACES, (O.Anzeige(basis))))
      end
      local gegen = O.KonfliktText(e.o)
      if gegen then table.insert(zeilen, string.format(L.KIT_NO_STACK, gegen)) end
      local konflikt = O.Konflikt(e.o)
      if konflikt then table.insert(zeilen, string.format(L.KIT_CONFLICT, konflikt)) end
      table.insert(zeilen, O.MaterialText(e.o))
      table.insert(zeilen, e.o.lernen or L.LEARN_TRAINER_PROF)
      return table.concat(zeilen, "\n")
    end)
    -- Craften direkt aus der Liste: ein Klick, ein Stück (erster Klick öffnet sonst den Beruf)
    z.bauen = S.textKnopf(z, L.KIT_BTN_CRAFT, 70, function()
      if z.eintrag then ns.Kit:Craften(z.eintrag.o) end
    end)
    z.bauen:SetHeight(20)
    z.bauen:SetPoint("BOTTOMRIGHT", -8, 4)
    S.tooltip(z.bauen, function() return z.bauen.text:GetText() end, L.KIT_BTN_HELP)
    return z
  end)
  f.liste:SetPoint("TOPLEFT", 0, -64)

  local FARBE = { vorrat = F.erfolg, bereit = F.erfolg, material = F.hinweis, lernen = F.leise, stufe = F.leise, beruf = F.leise }
  function f:Aktualisieren()
    local berufe = O.Berufe()
    local daten = {}
    for i, o in ipairs(O.LISTE) do
      if O.Passt(o) then
        table.insert(daten, { o = o, nr = i, zustand = O.Zustand(o, berufe), wert = berufe[o.beruf] })
      end
    end
    table.sort(daten, function(a, b)
      if a.zustand ~= b.zustand then return REIHENFOLGE[a.zustand] < REIHENFOLGE[b.zustand] end
      return a.nr < b.nr
    end)
    self.liste:Setzen(daten, function(z, e)
      local name, icon = O.Anzeige(e.o)
      z.icon:SetTexture(icon)
      z.icon:SetDesaturated(e.zustand == "stufe" or e.zustand == "beruf")
      z.name:SetText(name)
      local beruf = O.BERUF_NAME[e.o.beruf] or "?"
      local zustand
      if e.zustand == "vorrat" then zustand = string.format(L.KIT_STATE_BAGS, (O.Vorrat(e.o)))
      elseif e.zustand == "bereit" then zustand = L.KIT_READY
      elseif e.zustand == "material" then zustand = L.KIT_NEED_MATS
      elseif e.zustand == "lernen" then zustand = L.KIT_NOT_LEARNED
      elseif e.zustand == "stufe" then zustand = string.format(L.KIT_NEED_SKILL, beruf, e.o.stufe, e.wert or 0)
      else zustand = string.format(L.KIT_NEED_PROF, beruf, e.o.stufe) end
      z.zustand:SetText(zustand)
      z.zustand:SetTextColor(rgba(FARBE[e.zustand]))
      local konflikt = O.Konflikt(e.o)
      local aktiv = not konflikt and O.BonusAktiv(e.o)
      z.info:SetText(konflikt and string.format(L.KIT_CONFLICT_SHORT, konflikt) or (aktiv and L.KIT_BONUS_ACTIVE_SHORT) or e.o.info)
      z.info:SetTextColor(rgba(konflikt and F.hinweis or (aktiv and F.erfolg) or F.leise))
      z.mats:SetText(string.format(L.KIT_PROF, beruf, e.o.stufe) .. "   " .. O.MaterialText(e.o))
      local kann = e.zustand == "bereit" or (e.zustand == "vorrat" and O.MaterialDa(e.o))
      z.bauen:SetShown(kann and true or false)
      if kann then
        z.bauen.text:SetText(ns.Kit.OffenerBeruf() == e.o.beruf and L.KIT_BTN_CRAFT or L.KIT_BTN_OPEN)
      end
    end, "")
  end
end

-- Seite: Camp (dieses Lager: Feuer, Plätze, was steht, was der Char beisteuern kann) --------

local MAX_PLAETZE = 10
local RAND_GRAU = { 0.62, 0.64, 0.70, 1 }   -- Rand der Kästen im Look des Spiels
local QUELLE = { cast = L.CAMP_SRC_CAST, lager = L.CAMP_SRC_LIST, maus = L.CAMP_SRC_SEEN, bonus = L.CAMP_SRC_BONUS }

local function bauenLager()
  local f = seite("lager")
  local LG = ns.Lager
  S.ueberschrift(f, L.CAMP_TITLE):SetPoint("TOPLEFT", 0, 0)
  f.feuer = S.absatz(f, B, F.text, "GameFontHighlight")
  f.feuer:SetPoint("TOPLEFT", 0, -16)

  -- Plätze am Feuer: belegt mit Symbol, frei als leerer Kasten
  f.plaetze = {}
  for i = 1, MAX_PLAETZE do
    -- Platz wie im Spiel: Rand der Auswahllisten, innen der Hintergrund eines Taschenplatzes
    local p = S.spielKasten(f, "Frame")
    p:SetSize(32, 32)
    p:SetPoint("TOPLEFT", (i - 1) * 36, -44)
    p.leer = p:CreateTexture(nil, "BACKGROUND", nil, 1)
    p.leer:SetPoint("TOPLEFT", 3, -3)
    p.leer:SetPoint("BOTTOMRIGHT", -3, 3)
    p.leer:SetTexture("Interface\\Buttons\\UI-Slot-Background")
    p.leer:SetTexCoord(0, 0.640625, 0, 0.640625)
    p.icon = p:CreateTexture(nil, "ARTWORK")
    p.icon:SetPoint("TOPLEFT", 3, -3)
    p.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    p:EnableMouse(true)
    S.tooltip(p, function(self) return self.eintrag and O.Anzeige(self.eintrag.o) or L.CAMP_SLOT_FREE end, function(self)
      local e = self.eintrag
      if not e then return nil end
      local quelle = QUELLE[e.quelle] or ""
      if e.quelle == "cast" and e.wer then quelle = string.format(L.CAMP_SRC_CAST_BY, e.wer) end
      return quelle
    end)
    f.plaetze[i] = p
  end
  f.mehr = S.schrift(f, "GameFontHighlightLarge", F.leise)
  f.mehr:SetPoint("LEFT", f.plaetze[1], "RIGHT", 4, 0)

  -- Alle Lager-Boni in zwei Spalten: Name links, Zustand rechts, Einzelheiten im Tooltip
  S.ueberschrift(f, L.CAMP_BONUSES):SetPoint("TOPLEFT", 0, -88)
  f.boni = {}
  local spalte = math.floor((B - 16) / 2)
  for i = 1, #O.BONUS_REIHE do
    local b = CreateFrame("Frame", nil, f)
    b:SetSize(spalte, 19)
    b:SetPoint("TOPLEFT", ((i - 1) % 2) * (spalte + 16), -106 - math.floor((i - 1) / 2) * 19)
    b:EnableMouse(true)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", 0, 0)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.name = S.schrift(b, "GameFontHighlightSmall", F.text)
    b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.zustand = S.schrift(b, "GameFontHighlightSmall", F.leise)
    b.zustand:SetPoint("RIGHT", -4, 0)
    S.tooltip(b, function(self) return self.eintrag and self.eintrag.bonus end, function(self)
      local e = self.eintrag
      if not e then return nil end
      local namen = {}
      for _, o in ipairs(O.LISTE) do
        if o.familie == e.fam and O.Passt(o) then table.insert(namen, (O.Anzeige(o))) end
      end
      local zeilen = { string.format(L.BONUS_FROM, table.concat(namen, ", ")) }
      if e.zustand == "aktiv" then table.insert(zeilen, L.BONUS_TIP_ACTIVE) end
      if e.zustand == "da" then table.insert(zeilen, L.BONUS_TIP_AT_FIRE) end
      if e.konflikt then table.insert(zeilen, string.format(L.KIT_CONFLICT, e.konflikt)) end
      if e.best then
        local zustand = ({ vorrat = L.CAMP_STATE_BAGS, bereit = L.CAMP_STATE_CRAFT, material = L.KIT_NEED_MATS })[e.bestZustand] or ""
        table.insert(zeilen, string.format(L.BONUS_TIP_YOURS, (O.Anzeige(e.best)), zustand))
      else
        table.insert(zeilen, L.BONUS_TIP_NONE)
      end
      return table.concat(zeilen, "\n")
    end)
    f.boni[i] = b
  end

  S.ueberschrift(f, L.CAMP_YOU_CAN_ADD):SetPoint("TOPLEFT", 0, -212)
  f.liste = S.liste(f, B, 38 * 4, 38, function(l)
    local z = S.zeile(l)
    z.icon = z:CreateTexture(nil, "ARTWORK")
    z.icon:SetSize(28, 28)
    z.icon:SetPoint("LEFT", 6, 0)
    z.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    z.name = S.schrift(z, "GameFontHighlight", F.text)
    z.name:SetPoint("TOPLEFT", 42, -4)
    z.grund = S.schrift(z, "GameFontHighlightSmall", F.akzent)
    z.grund:SetPoint("TOPLEFT", 42, -20)
    z.grund:SetWidth(B - 140)
    z.grund:SetJustifyH("LEFT")
    z.grund:SetWordWrap(false)
    z.zustand = S.schrift(z, "GameFontHighlightSmall", F.leise)
    z.zustand:SetPoint("TOPRIGHT", -10, -6)
    z.bauen = S.textKnopf(z, L.KIT_BTN_CRAFT, 70, function()
      if z.eintrag then ns.Kit:Craften(z.eintrag.o) end
    end)
    z.bauen:SetHeight(20)
    z.bauen:SetPoint("BOTTOMRIGHT", -8, 3)
    S.tooltip(z, function(self) return self.eintrag and O.Anzeige(self.eintrag.o) end, function(self)
      local e = self.eintrag
      if not e then return nil end
      local zeilen = { e.o.info, O.MaterialText(e.o) }
      local konflikt = O.Konflikt(e.o)
      if konflikt then table.insert(zeilen, string.format(L.KIT_CONFLICT, konflikt)) end
      return table.concat(zeilen, "\n")
    end)
    return z
  end)
  f.liste:SetPoint("TOPLEFT", 0, -230)

  local ZUSTAND = { vorrat = L.CAMP_STATE_BAGS, bereit = L.CAMP_STATE_CRAFT, material = L.KIT_NEED_MATS }
  local FARBE = { vorrat = F.erfolg, bereit = F.erfolg, material = F.hinweis }
  function f:Aktualisieren()
    local gesamt, belegt = LG:Plaetze()
    local feuerName = LG.feuer and (O.Anzeige(LG.feuer.o))
    local anzahl = belegt == 1 and L.CAMP_OBJECTS_ONE or string.format(L.CAMP_OBJECTS_MANY, belegt)
    if not LG.aktiv then
      self.feuer:SetText(L.CAMP_NONE)
    elseif feuerName then
      self.feuer:SetText(string.format(L.CAMP_FIRE_KNOWN, feuerName, gesamt, anzahl))
    else
      self.feuer:SetText(string.format(L.CAMP_FIRE_UNKNOWN, anzahl))
    end
    -- Plätze: bei unbekannter Größe so viele wie bekannt, mindestens 3, dahinter ein Fragezeichen
    local objekte = {}
    for _, e in pairs(LG.objekte) do table.insert(objekte, e) end
    table.sort(objekte, function(a, b) return tostring(a.o.spell) < tostring(b.o.spell) end)
    local zeigen = LG.aktiv and (gesamt or math.max(3, #objekte)) or 0
    for i, p in ipairs(self.plaetze) do
      local e = objekte[i]
      p:SetShown(i <= zeigen)
      p.eintrag = e
      if e then
        local _, icon = O.Anzeige(e.o)
        p.icon:SetTexture(icon)
        p.icon:SetDesaturated(not e.genau)
        p.icon:Show()
        S.randFarbe(p, e.genau and F.erfolg or RAND_GRAU)
      else
        p.icon:Hide()
        S.randFarbe(p, RAND_GRAU)
      end
    end
    self.mehr:ClearAllPoints()
    if zeigen > 0 then self.mehr:SetPoint("LEFT", self.plaetze[math.min(zeigen, MAX_PLAETZE)], "RIGHT", 6, 0) end
    self.mehr:SetText(LG.aktiv and not gesamt and "?" or "")

    local BONUS_TEXT = { klasse = L.BONUS_CLASS, da = L.BONUS_AT_FIRE, du = L.BONUS_YOU,
      material = L.BONUS_MATS, fehlt = L.BONUS_MISSING }
    local BONUS_FARBE = { aktiv = F.erfolg, klasse = F.hinweis, da = F.akzent, du = F.akzent,
      material = F.leise, fehlt = F.leise }
    for i, e in ipairs(LG:BoniUebersicht()) do
      local b = self.boni[i]
      b.eintrag = e
      local _, icon = O.Anzeige(e.basis)
      b.icon:SetTexture(icon)
      b.icon:SetDesaturated(e.zustand == "fehlt" or e.zustand == "material")
      b.name:SetText(e.bonus)
      b.name:SetTextColor(rgba(e.zustand == "aktiv" and F.text or F.leise))
      local text = BONUS_TEXT[e.zustand]
      if e.zustand == "aktiv" then
        if e.fam == "zelt" then text = L.BONUS_USED
        elseif e.punkte and e.punkte > 0 then text = string.format(L.BONUS_VALUE, e.punkte)
        else text = L.BONUS_ACTIVE end
      end
      b.zustand:SetText(text)
      b.zustand:SetTextColor(rgba(BONUS_FARBE[e.zustand]))
    end

    local daten = LG:Vorschlaege()
    self.liste:Setzen(daten, function(z, e)
      local name, icon = O.Anzeige(e.o)
      z.icon:SetTexture(icon)
      z.icon:SetDesaturated(e.zustand == "material")
      z.name:SetText(name)
      local grund
      if e.art == "besser" then
        grund = string.format(L.CAMP_UPGRADE, (O.Anzeige(e.statt)))
      elseif LG.aktiv then
        grund = L.CAMP_MISSING
      end
      local bonus = O.FAMILIE[e.o.familie].bonus
      grund = grund and bonus and string.format(L.CAMP_ADD_LINE, bonus, grund) or grund or bonus or e.o.info
      local konflikt = O.Konflikt(e.o)
      if konflikt then grund = grund .. "  " .. string.format(L.CAMP_ONLY_OTHERS, konflikt) end
      z.grund:SetText(grund)
      z.grund:SetTextColor(rgba(LG.aktiv and F.akzent or F.leise))
      z.zustand:SetText(ZUSTAND[e.zustand] or "")
      z.zustand:SetTextColor(rgba(FARBE[e.zustand] or F.leise))
      z.bauen:SetShown(e.zustand == "bereit")
      if e.zustand == "bereit" then
        z.bauen.text:SetText(ns.Kit.OffenerBeruf() == e.o.beruf and L.KIT_BTN_CRAFT or L.KIT_BTN_OPEN)
      end
    end, LG.aktiv and L.CAMP_NOTHING_TO_ADD or L.CAMP_NOTHING_AT_ALL)
  end
end

-- Seite: Settings ----------------------------------------------------------------------
local WARNEN = {
  { wert = 0, text = L.OFF }, { wert = 2, text = string.format(L.N_MIN, 2) },
  { wert = 5, text = string.format(L.N_MIN, 5) }, { wert = 10, text = string.format(L.N_MIN, 10) },
}

local function bauenEinstellungen()
  local f = seite("einstellungen")
  S.ueberschrift(f, L.WARN_BEFORE):SetPoint("TOPLEFT", 0, 0)
  f.warnen = S.segmente(f, 320, WARNEN, function(wert)
    ns.db.warnenMinuten = wert
    W:Aktualisieren()
    ns.aktualisieren()
  end)
  f.warnen:SetPoint("TOPLEFT", 0, -16)
  f.probe = S.textKnopf(f, L.BTN_PREVIEW, 130, function() ns.Erinnerung:Vorschau() end)
  f.probe:SetPoint("LEFT", f.warnen, "RIGHT", 12, 0)
  S.tooltip(f.probe, L.BTN_PREVIEW, L.PREVIEW_HELP)

  local schalter = {
    { feld = "ton", text = L.OPT_SOUND, hilfe = L.OPT_SOUND_HELP, y = -66 },
    { feld = "erinnernLogin", text = L.OPT_LOGIN, hilfe = L.OPT_LOGIN_HELP, y = -88 },
    { feld = "erinnernGruppe", text = L.OPT_GROUP, hilfe = L.OPT_GROUP_HELP, y = -110 },
    { feld = "feuerHinweis", text = L.OPT_CAMPFIRE, hilfe = L.OPT_CAMPFIRE_HELP, y = -132 },
    { feld = "essenErinnern", text = L.OPT_FOOD, hilfe = L.OPT_FOOD_HELP, y = -154 },
    { feld = "allesDaMelden", text = L.OPT_ALL_SET, hilfe = L.OPT_ALL_SET_HELP, y = -176 },
    { feld = "leisteZeigen", text = L.OPT_BAR, hilfe = L.OPT_BAR_HELP, y = -226 },
    { feld = "nurMitBuff", text = L.OPT_BAR_ONLY, hilfe = L.OPT_BAR_ONLY_HELP, y = -248 },
    { feld = "gesperrt", text = L.OPT_LOCK, hilfe = L.OPT_LOCK_HELP, y = -270 },
    { feld = "minimapZeigen", text = L.OPT_MINIMAP, hilfe = L.OPT_MINIMAP_HELP, y = -292,
      danach = function() ns.Minimap:Sichtbarkeit() end },
    { feld = "kitZeigen", text = L.OPT_KIT, hilfe = L.OPT_KIT_HELP, y = -314 },
    { feld = "showAn", text = L.OPT_SHOW, hilfe = L.OPT_SHOW_HELP, y = -336 },
    { feld = "murlocTon", text = L.OPT_MURLOC_SOUND, hilfe = L.OPT_MURLOC_SOUND_HELP, y = -358 },
  }
  S.ueberschrift(f, L.REMINDERS):SetPoint("TOPLEFT", 0, -50)
  S.ueberschrift(f, L.DISPLAY):SetPoint("TOPLEFT", 0, -210)
  f.schalter = {}
  for i, s in ipairs(schalter) do
    local h = S.haken(f, B, s.text, s.hilfe, function(_, an)
      ns.db[s.feld] = an
      if s.danach then s.danach() end
      W:Aktualisieren()
      ns.aktualisieren()
    end)
    h.feld = s.feld
    h:SetPoint("TOPLEFT", 0, s.y)
    -- Neben dem Minikarten-Knopf die Wahl seines Bildes, deshalb ist diese Zeile schmaler
    if s.feld == "minimapZeigen" then h:SetWidth(230) end
    f.schalter[i] = h
  end

  -- Bild im Minikarten-Knopf
  f.symbol = S.segmente(f, 210, {
    { wert = "feuer", text = L.ICON_FIRE, hilfe = L.ICON_FIRE_HELP },
    { wert = "murloc", text = L.ICON_MURLOC, hilfe = L.ICON_MURLOC_HELP },
    { wert = "lager", text = L.ICON_CAMP, hilfe = L.ICON_CAMP_HELP },
  }, function(wert)
    ns.db.minimapSymbol = wert
    ns.Minimap:Symbol()
    W:Aktualisieren()
  end)
  for _, h in ipairs(f.schalter) do
    if h.feld == "minimapZeigen" then f.symbol:SetPoint("LEFT", h, "RIGHT", 10, 0) end
  end

  function f:Aktualisieren()
    self.warnen:Setzen(ns.db.warnenMinuten)
    self.symbol:Setzen(ns.db.minimapSymbol or "feuer")
    for _, h in ipairs(self.schalter) do h:Setzen(ns.db[h.feld]) end
  end
end

-- Seite: Help ---------------------------------------------------------------------------

local function bauenHilfe()
  local f = seite("hilfe")
  local y = 0
  for _, abschnitt in ipairs({
    { L.HELP_START_TITLE, L.HELP_START },
    { L.HELP_SAFE_TITLE, L.HELP_SAFE },
    { L.HELP_COMMANDS_TITLE, L.HELP_COMMANDS },
  }) do
    S.ueberschrift(f, abschnitt[1]):SetPoint("TOPLEFT", 0, y)
    local t = S.absatz(f, B, F.text)
    t:SetPoint("TOPLEFT", 0, y - 16)
    t:SetText(abschnitt[2])
    y = y - 16 - (t:GetStringHeight() or 60) - 18
  end
  function f:Aktualisieren() end
end

-- Rahmen ---------------------------------------------------------------------------------

-- Echter Aufbau: Porträtrahmen des Spiels, darin die versenkte Fläche, unten die Reiter
local function bauenEcht(r)
  BREITE, HOEHE = 640, 480
  X, OBEN, UNTEN = 16, -72, 18
  B = BREITE - X - 18
  r:SetSize(BREITE, HOEHE)
  pcall(r.SetTitle, r, L.ADDON_NAME)
  if r.SetPortraitToAsset then pcall(r.SetPortraitToAsset, r, S.MARKE[1]) end
  -- Unser Lagerfeuer-Abzeichen auf dem Porträt
  local halter = type(r.PortraitContainer) == "table" and r.PortraitContainer or r
  local portrait = halter.portrait or r.portrait
  if type(portrait) == "table" then S.abzeichen(halter, portrait, 20) end
  local unter = S.schrift(r, "GameFontHighlightSmall")
  unter:SetPoint("TOPLEFT", 66, -36)
  unter:SetText(L.SUBTITLE)
  local version = S.schrift(r, "GameFontDisableSmall")
  version:SetPoint("TOPRIGHT", -14, -36)
  version:SetText(L.BY_AUTHOR .. "   v" .. ns.VERSION)
  local innen = S.vorlage("Frame", r, "InsetFrameTemplate")
  if innen then
    innen:SetFrameLevel((r:GetFrameLevel() or 1) + 1)
    innen:SetPoint("TOPLEFT", 4, -60)
    innen:SetPoint("BOTTOMRIGHT", -6, 4)
  end
  -- Reiter unten am Fenster. Die neue Vorlage (mit LeftActive) steht mit Abstand nebeneinander,
  -- die alte überlappt wie im Charakterfenster.
  r.Tabs = {}
  local vorher
  for i, t in ipairs(REITER) do
    local tab = S.vorlage("Button", r, "PanelTabButtonTemplate", "CampfireBuddyFrameTab" .. i)
    if tab then
      tab:SetText(t.text)
    else
      tab = S.textKnopf(r, t.text, 90, function() end)
    end
    if tab.SetID then tab:SetID(i) end
    if vorher then
      if tab.LeftActive then tab:SetPoint("TOPLEFT", vorher, "TOPRIGHT", 3, 0) else tab:SetPoint("LEFT", vorher, "RIGHT", -15, 0) end
    else
      tab:SetPoint("TOPLEFT", r, "BOTTOMLEFT", 12, 2)
    end
    if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 0) end
    tab.schluessel = t.schluessel
    tab:SetScript("OnClick", function()
      if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB) end
      W:Zeigen(t.schluessel)
    end)
    r.Tabs[i] = tab
    vorher = tab
  end
  if PanelTemplates_SetNumTabs then pcall(PanelTemplates_SetNumTabs, r, #REITER) end
  W.reiter = r.Tabs
end

-- Flacher Aufbau wie früher: Kopfzeile, Reiter links
local function bauenFlach(r)
  r:SetSize(BREITE, HOEHE)
  S.schatten(r)
  S.kopf(r, L.SUBTITLE)

  local version = S.schrift(r, "GameFontHighlightSmall", F.leise)
  version:SetPoint("TOPRIGHT", -40, -18)
  version:SetText(L.BY_AUTHOR .. "   v" .. ns.VERSION)
  local zu = S.zeichenKnopf(r, "x", function() r:Hide() end)
  zu:SetPoint("TOPRIGHT", -8, -11)

  local leiste = r:CreateTexture(nil, "BORDER")
  leiste:SetPoint("TOPLEFT", 1, -46)
  leiste:SetPoint("BOTTOMLEFT", 1, 1)
  leiste:SetWidth(SEITE)
  leiste:SetColorTexture(rgba(F.seite))
  W.reiter = {}
  for i, t in ipairs(REITER) do
    local b = S.zeile(r)
    b:SetSize(SEITE, 30)
    b:SetPoint("TOPLEFT", 1, -54 - (i - 1) * 32)
    b.text = S.schrift(b, "GameFontHighlight", F.leise)
    b.text:SetPoint("LEFT", 16, 0)
    b.text:SetText(t.text)
    b.schluessel = t.schluessel
    b:SetScript("OnClick", function() S.klick() W:Zeigen(t.schluessel) end)
    W.reiter[i] = b
  end
end

function W:Bauen()
  local r = S.vorlage("Frame", UIParent, "PortraitFrameTemplate", "CampfireBuddyFrame")
  self.echt = r ~= nil and r.SetTitle ~= nil
  if not self.echt then r = S.kasten(UIParent, "Frame", F.grund, F.rand, "CampfireBuddyFrame") end
  self.rahmen = r
  local pos = ns.db.fenster
  if pos and pos.punkt then r:SetPoint(pos.punkt, UIParent, pos.punkt, pos.x, pos.y) else r:SetPoint("CENTER") end
  r:SetFrameStrata("HIGH")
  r:SetToplevel(true)
  r:SetClampedToScreen(true)
  r:EnableMouse(true)
  r:SetMovable(true)
  r:RegisterForDrag("LeftButton")
  r:SetScript("OnDragStart", function(self) self:StartMoving() end)
  r:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local punkt, _, _, x, y = self:GetPoint()
    ns.db.fenster = { punkt = punkt, x = x, y = y }
  end)
  if UISpecialFrames then table.insert(UISpecialFrames, "CampfireBuddyFrame") end
  if self.echt then bauenEcht(r) else bauenFlach(r) end

  -- Restzeit im Status jede Sekunde
  local warten = 0
  r:SetScript("OnUpdate", function(_, dt)
    warten = warten + dt
    if warten < 1 then return end
    warten = 0
    if W.aktiv == "status" then W:Aktualisieren() end
  end)

  bauenStatus()
  bauenLager()
  bauenBuffs()
  bauenKit()
  bauenEinstellungen()
  bauenHilfe()
  r:Hide()
end

function W:Zeigen(schluessel)
  if not ns.db then return end
  if not self.rahmen then self:Bauen() end
  self.aktiv = schluessel or self.aktiv or "status"
  for k, f in pairs(self.seiten) do f:SetShown(k == self.aktiv) end
  for i, b in ipairs(self.reiter) do
    local an = b.schluessel == self.aktiv
    if self.echt then
      if an and PanelTemplates_SetTab then pcall(PanelTemplates_SetTab, self.rahmen, i) end
    else
      b.wahl:SetShown(an)
      b.text:SetTextColor(rgba(an and F.text or F.leise))
    end
  end
  self.rahmen:Show()
  self:Aktualisieren()
end

function W:Umschalten()
  if self.rahmen and self.rahmen:IsShown() then self.rahmen:Hide() else self:Zeigen() end
end

function W:Aktualisieren()
  if not (self.rahmen and self.rahmen:IsShown()) then return end
  local f = self.seiten[self.aktiv]
  if f and f.Aktualisieren then f:Aktualisieren() end
end

ns.beimAktualisieren(function() W:Aktualisieren() end)
-- Taschen ändern sich (Material gesammelt, Objekt gebaut): Status und Camp kit sofort neu zeigen
ns.ereignis("BAG_UPDATE_DELAYED", function() W:Aktualisieren() end)
