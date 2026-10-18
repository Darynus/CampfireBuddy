-- Lagerfeuer auf der Weltkarte: Feuer, an denen dieser Char war, die er angezündet hat oder die
-- seine Gruppe angezündet hat. Nadel mit Tooltip (Größe, Objekte, wie lange es noch brennt).
-- Ausgebrannte Feuer verschwinden von selbst, Rechtsklick entfernt eine Nadel. Die Einträge
-- schreibt Lager.lua in ns.db.karte. Es wird nichts gesendet und nichts von anderen gelesen.
-- Die Nadeln hängen an der Zeichenfläche der Weltkarte und behalten beim Zoomen ihre Größe.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F = S.F

local K = { nadeln = {} }
ns.Karte = K

local GROESSE = 20

local nachZauber
local function objekt(spell)
  if not nachZauber then
    nachZauber = {}
    for _, o in ipairs(ns.Objekte.LISTE) do nachZauber[o.spell] = o end
  end
  return spell and nachZauber[spell]
end

local function serverZeit() return (GetServerTime and GetServerTime()) or time() end

-- Ort eines Eintrags auf der gerade gezeigten Karte. Andere Karten (Kontinent, Nachbarzone) über
-- die Weltposition, wenn das Spiel die Umrechnung kennt.
local function aufKarte(e, karte)
  if e.karte == karte then return e.x, e.y end
  if not (C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
  local ok, kontinent, welt = pcall(C_Map.GetWorldPosFromMapPos, e.karte, CreateVector2D(e.x, e.y))
  if not ok or not kontinent or type(welt) ~= "table" then return nil end
  local ok2, _, pos = pcall(C_Map.GetMapPosFromWorldPos, kontinent, welt, karte)
  if not ok2 or type(pos) ~= "table" or not pos.GetXY then return nil end
  local x, y = pos:GetXY()
  if type(x) ~= "number" or type(y) ~= "number" or x < 0 or x > 1 or y < 0 or y > 1 then return nil end
  return x, y
end

-- Aufbau wie bei den Lagerfeuern, die das Spiel selbst auf der Karte zeigt (Patricks Screenshot,
-- 17. Okt): Name, "13 Min 53 Sec remaining", "Placed by: Name". Die Sekunden zählen mit, solange
-- die Maus auf der Nadel steht (K:Zeichnen ruft den Tooltip jede Sekunde neu auf).
local function tooltip(nadel)
  local e = nadel.eintrag
  if not e then return end
  local feuer = objekt(e.feuer)
  GameTooltip:SetOwner(nadel, "ANCHOR_RIGHT")
  GameTooltip:SetText(feuer and (ns.Objekte.Anzeige(feuer)) or L.MAP_FIRE, 1, 0.82, 0)
  if e.welt then
    GameTooltip:AddLine(L.MAP_ALWAYS, F.erfolg[1], F.erfolg[2], F.erfolg[3])
  elseif e.ende then
    local rest = math.max(0, e.ende - serverZeit())
    GameTooltip:AddLine(string.format(L.MAP_REMAINING, math.floor(rest / 60), math.floor(rest % 60)), 1, 1, 1)
  end
  if e.wer then GameTooltip:AddLine(string.format(L.MAP_PLACED_BY, e.wer), 1, 1, 1) end
  local anzahl = #(e.objekte or {})
  if feuer and feuer.plaetze then
    GameTooltip:AddLine(string.format(L.MAP_SLOTS, anzahl, feuer.plaetze), F.leise[1], F.leise[2], F.leise[3])
  elseif anzahl > 0 then
    GameTooltip:AddLine(string.format(L.MAP_OBJECTS, anzahl), F.leise[1], F.leise[2], F.leise[3])
  end
  -- Je Objekt rechts sein Bonus für dein Level (grün), wie im Tooltip des Objekts
  for _, spell in ipairs(e.objekte or {}) do
    local o = objekt(spell)
    if o then
      local name, icon = ns.Objekte.Anzeige(o)
      GameTooltip:AddDoubleLine("|T" .. tostring(icon) .. ":14:14|t " .. name, ns.Objekte.WertFuerMich(o) or "",
        F.text[1], F.text[2], F.text[3], 0.1, 1, 0.1)
    end
  end
  if not e.genau then GameTooltip:AddLine(L.MAP_ROUGH, F.leise[1], F.leise[2], F.leise[3], true) end
  GameTooltip:AddLine(L.MAP_REMOVE, F.leise[1], F.leise[2], F.leise[3])
  GameTooltip:Show()
end

local function neueNadel(flaeche)
  local b = CreateFrame("Button", nil, flaeche)
  b:SetSize(GROESSE, GROESSE)
  b:RegisterForClicks("RightButtonUp")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexture(S.SYMBOL)
  b:SetHighlightTexture(S.SYMBOL, "ADD")
  b:SetScript("OnEnter", tooltip)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:SetScript("OnClick", function(self)
    if self.eintrag and self.eintrag.nr then
      GameTooltip:Hide()
      ns.Lager:KartenEintragWeg(self.eintrag.nr)
      K:Zeichnen(true)
    end
  end)
  return b
end

-- Nadeln für die gerade gezeigte Karte setzen. Bei Zoom oder Kartenwechsel neu, sonst jede Sekunde
-- (Feuer, die ausgehen).
function K:Zeichnen(sofort)
  local wm = WorldMapFrame
  if not (wm and wm.GetCanvas and wm.GetMapID) then return end
  local ok, flaeche = pcall(wm.GetCanvas, wm)
  local ok2, karte = pcall(wm.GetMapID, wm)
  if not (ok and ok2 and flaeche and karte) then return end
  local skala = 1
  if wm.GetCanvasScale then
    local ok3, s = pcall(wm.GetCanvasScale, wm)
    if ok3 and type(s) == "number" and s > 0 then skala = s end
  end
  local jetzt = ns.jetzt()
  if not sofort and karte == self.karte and skala == self.skala and jetzt - (self.zuletzt or 0) < 1 then return end
  self.karte, self.skala, self.zuletzt = karte, skala, jetzt

  local eintraege = (ns.db and ns.db.karteZeigen) and ns.Lager:KartenEintraege() or {}
  local breite, hoehe = flaeche:GetWidth() or 0, flaeche:GetHeight() or 0
  local n = 0
  for _, e in ipairs(eintraege) do
    local x, y = aufKarte(e, karte)
    if x then
      n = n + 1
      local b = self.nadeln[n] or neueNadel(flaeche)
      self.nadeln[n] = b
      b.eintrag = e
      b:SetFrameLevel((flaeche:GetFrameLevel() or 1) + 900)
      b:SetScale(1 / skala)
      b:ClearAllPoints()
      b:SetPoint("CENTER", flaeche, "TOPLEFT", x * breite * skala, -y * hoehe * skala)
      b:SetAlpha(e.genau and 1 or 0.7)
      b:Show()
      if GameTooltip:GetOwner() == b then tooltip(b) end
    end
  end
  for i = n + 1, #self.nadeln do
    self.nadeln[i].eintrag = nil
    self.nadeln[i]:Hide()
  end
end

ns.beimStart(function()
  if not WorldMapFrame then return end
  -- Läuft nur, solange die Weltkarte offen ist
  local wache = CreateFrame("Frame", nil, WorldMapFrame)
  wache:SetScript("OnUpdate", function() K:Zeichnen(false) end)
  wache:SetScript("OnShow", function() K:Zeichnen(true) end)
end)
