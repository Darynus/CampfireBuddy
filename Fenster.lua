-- Hauptfenster: Status, Buffs, Camp kit, Settings, Help.
-- Öffnen mit /campfire, Rechtsklick auf die Leiste, Minikarten-Knopf oder Optionen-Menü.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba

local W = { seiten = {} }
ns.Fenster = W

local BREITE, HOEHE = 640, 460
local SEITE = 150
local X = SEITE + 16
local B = BREITE - X - 16
local OBEN = -60

local REITER = {
  { schluessel = "status", text = L.TAB_STATUS },
  { schluessel = "buffs", text = L.TAB_BUFFS },
  { schluessel = "kit", text = L.TAB_KIT },
  { schluessel = "einstellungen", text = L.TAB_SETTINGS },
  { schluessel = "hilfe", text = L.TAB_HELP },
}

local function seite(schluessel)
  local f = CreateFrame("Frame", nil, W.rahmen)
  f:SetPoint("TOPLEFT", X, OBEN)
  f:SetSize(B, HOEHE + OBEN - 16)
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
  f.balken = S.balken(f, B, 10)
  f.balken:SetPoint("TOPLEFT", 0, -66)
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
      self.hilfe:SetText("")
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
local REIHENFOLGE = { vorrat = 0, bereit = 1, material = 2, stufe = 3, beruf = 4 }

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
      return e.o.info .. "\n" .. O.MaterialText(e.o) .. "\n" .. (e.o.lernen or L.LEARN_TRAINER_PROF)
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

  local FARBE = { vorrat = F.erfolg, bereit = F.erfolg, material = F.hinweis, stufe = F.leise, beruf = F.leise }
  function f:Aktualisieren()
    local berufe = O.Berufe()
    local daten = {}
    for i, o in ipairs(O.LISTE) do
      table.insert(daten, { o = o, nr = i, zustand = O.Zustand(o, berufe), wert = berufe[o.beruf] })
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
      elseif e.zustand == "stufe" then zustand = string.format(L.KIT_NEED_SKILL, beruf, e.o.stufe, e.wert or 0)
      else zustand = string.format(L.KIT_NEED_PROF, beruf, e.o.stufe) end
      z.zustand:SetText(zustand)
      z.zustand:SetTextColor(rgba(FARBE[e.zustand]))
      z.info:SetText(e.o.info)
      z.mats:SetText(string.format(L.KIT_PROF, beruf, e.o.stufe) .. "   " .. O.MaterialText(e.o))
      local kann = e.zustand == "bereit" or (e.zustand == "vorrat" and O.MaterialDa(e.o))
      z.bauen:SetShown(kann and true or false)
      if kann then
        z.bauen.text:SetText(ns.Kit.OffenerBeruf() == e.o.beruf and L.KIT_BTN_CRAFT or L.KIT_BTN_OPEN)
      end
    end, "")
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
    f.schalter[i] = h
  end

  function f:Aktualisieren()
    self.warnen:Setzen(ns.db.warnenMinuten)
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

function W:Bauen()
  local r = S.kasten(UIParent, "Frame", F.grund, F.rand, "CampfireBuddyFrame")
  self.rahmen = r
  r:SetSize(BREITE, HOEHE)
  local pos = ns.db.fenster
  if pos and pos.punkt then r:SetPoint(pos.punkt, UIParent, pos.punkt, pos.x, pos.y) else r:SetPoint("CENTER") end
  r:SetFrameStrata("HIGH")
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
  self.reiter = {}
  for i, t in ipairs(REITER) do
    local b = S.zeile(r)
    b:SetSize(SEITE, 30)
    b:SetPoint("TOPLEFT", 1, -54 - (i - 1) * 32)
    b.text = S.schrift(b, "GameFontHighlight", F.leise)
    b.text:SetPoint("LEFT", 16, 0)
    b.text:SetText(t.text)
    b.schluessel = t.schluessel
    b:SetScript("OnClick", function() S.klick() W:Zeigen(t.schluessel) end)
    self.reiter[i] = b
  end

  -- Restzeit im Status jede Sekunde
  local warten = 0
  r:SetScript("OnUpdate", function(_, dt)
    warten = warten + dt
    if warten < 1 then return end
    warten = 0
    if W.aktiv == "status" then W:Aktualisieren() end
  end)

  bauenStatus()
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
  for _, b in ipairs(self.reiter) do
    local an = b.schluessel == self.aktiv
    b.wahl:SetShown(an)
    b.text:SetTextColor(rgba(an and F.text or F.leise))
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
