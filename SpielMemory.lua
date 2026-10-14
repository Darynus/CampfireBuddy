-- Lager-Memory: zwölf Karten mit den Symbolen der Lager-Objekte. Zwei aufdecken, Paare bleiben
-- liegen. Ein Paar gibt 3 Punkte, wer alle findet, bekommt Restsekunden als Bonus.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba
local SP = ns.Spiel

local KARTE, SPALTEN, PAARE = 46, 4, 6

local ME = { key = "memory", name = L.GAME_MEMORY, info = L.GAME_MEMORY_INFO,
  icon = "Interface\\Icons\\INV_10_Inscription_DarkmoonCards_Fire_2", dauer = 60 }

function ME:Bauen(r)
  self.karten = {}
  local abstandX = (SP.BREITE - SPALTEN * KARTE) / (SPALTEN + 1)
  for i = 1, PAARE * 2 do
    local reihe, spalte = math.floor((i - 1) / SPALTEN), (i - 1) % SPALTEN
    local k = S.kasten(r, "Button", F.flaeche, F.rand)
    k:SetSize(KARTE, KARTE)
    k:SetPoint("TOPLEFT", abstandX + spalte * (KARTE + abstandX), -14 - reihe * (KARTE + 10))
    k.bild = k:CreateTexture(nil, "ARTWORK")
    k.bild:SetPoint("TOPLEFT", 4, -4)
    k.bild:SetPoint("BOTTOMRIGHT", -4, 4)
    k.bild:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    k.ruecken = k:CreateTexture(nil, "ARTWORK")
    k.ruecken:SetPoint("TOPLEFT", 8, -8)
    k.ruecken:SetPoint("BOTTOMRIGHT", -8, 8)
    k.ruecken:SetTexture("Interface\\Icons\\INV_10_Inscription_DarkmoonCards_Fire_2")
    k.ruecken:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    k.ruecken:SetAlpha(0.45)
    k:SetScript("OnClick", function(self) ME:Umdrehen(self) end)
    self.karten[i] = k
  end
end

local function zeigen(k, offen)
  k.offen = offen
  k.bild:SetShown(offen)
  k.ruecken:SetShown(not offen)
  S.randFarbe(k, k.gefunden and F.erfolg or (offen and F.akzent or F.rand))
end

function ME:Start()
  -- Sechs zufällige Lager-Objekte als Motive, gemischt
  -- Motive: Symbole der Lager-Objekte, jedes nur einmal. Kennt der Client zu wenige, kommen
  -- feste Symbole dazu, damit nie zwei Paare gleich aussehen.
  local motive, schon = {}, {}
  local function dazu(icon)
    if not icon then return end
    -- Pfad und Datei-ID desselben Bilds gelten als gleich
    local schluessel = icon
    if type(icon) == "string" and GetFileIDFromPath then schluessel = GetFileIDFromPath(icon) or icon end
    if not schon[schluessel] then schon[schluessel] = true table.insert(motive, icon) end
  end
  for _, o in ipairs(ns.Objekte.LISTE) do
    local _, icon = ns.Objekte.Anzeige(o)
    if icon ~= ns.ESSEN_TEXTUR then dazu(icon) end
  end
  for _, icon in ipairs(ME.ERSATZ) do dazu(icon) end
  for i = #motive, 2, -1 do local j = math.random(1, i) motive[i], motive[j] = motive[j], motive[i] end
  local stapel = {}
  for i = 1, PAARE do
    local m = motive[((i - 1) % #motive) + 1]
    table.insert(stapel, { motiv = m, paar = i })
    table.insert(stapel, { motiv = m, paar = i })
  end
  for i = #stapel, 2, -1 do local j = math.random(1, i) stapel[i], stapel[j] = stapel[j], stapel[i] end
  for i, k in ipairs(self.karten) do
    k.paar, k.gefunden = stapel[i].paar, false
    k.bild:SetTexture(stapel[i].motiv)
    zeigen(k, false)
  end
  self.erste, self.zweite, self.zudeckenBis, self.gefunden = nil, nil, nil, 0
end

function ME:Umdrehen(k)
  if not (SP.laeuft and SP.aktiv == self) or k.offen or k.gefunden or self.zudeckenBis then return end
  zeigen(k, true)
  ns.ton("karte")
  if not self.erste then
    self.erste = k
    return
  end
  self.zweite = k
  if self.erste.paar == k.paar then
    self.erste.gefunden, k.gefunden = true, true
    zeigen(self.erste, true) zeigen(k, true)
    self.erste, self.zweite = nil, nil
    self.gefunden = self.gefunden + 1
    SP:Plus(3)
    SP:Ruf(SP.spruch(L.MEMORY_PAIR), SP.BREITE / 2, -95, { 0.4, 0.84, 0.56, 1 })
    ns.ton("paar")
    if self.gefunden == PAARE then
      SP:Plus(math.floor(math.max(0, (SP.ende or ns.jetzt()) - ns.jetzt())))
      SP:Fertig(L.MEMORY_DONE)
    end
  else
    self.zudeckenBis = ns.jetzt() + 0.8
    if math.random(1, 3) == 1 then SP:Ruf(SP.spruch(L.MEMORY_MISS), SP.BREITE / 2, -95, { 0.6, 0.6, 0.6, 1 }) end
  end
end

function ME:Tick(_, jetzt)
  if self.zudeckenBis and jetzt >= self.zudeckenBis then
    zeigen(self.erste, false)
    zeigen(self.zweite, false)
    self.erste, self.zweite, self.zudeckenBis = nil, nil, nil
  end
end

ME.ERSATZ = { S.LAGER, "Interface\\Icons\\INV_Misc_Head_Murloc_01", "Interface\\Icons\\Spell_Fire_Fire",
  "Interface\\Icons\\INV_Fishingpole_02", "Interface\\Icons\\INV_Misc_Book_09", "Interface\\Icons\\INV_Shield_06",
  "Interface\\Icons\\Ability_Rogue_Sprint" }

SP.Registrieren(ME)
