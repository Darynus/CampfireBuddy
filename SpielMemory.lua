-- Lager-Memory: Karten mit den Symbolen der Lager-Objekte. Zwei aufdecken, Paare bleiben liegen.
-- Ein Paar gibt 3 Punkte, wer alle findet, bekommt die Restsekunden als Bonus und kann mit einem
-- neuen Satz Karten weiterspielen (Next round, jede Runde etwas weniger Zeit).
-- Easy: 12 Karten, Hard: 20 Karten, jede Stufe mit eigenem Rekord.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba
local SP = ns.Spiel

-- Größe der Karten, Spalten, Paare, Abstand zwischen den Reihen, Abstand oben
local AUFBAU = {
  easy = { karte = 46, spalten = 4, paare = 6, reihe = 10, oben = 14 },
  hard = { karte = 40, spalten = 5, paare = 10, reihe = 6, oben = 6 },
}
local MAX_KARTEN = 20

local ME = { key = "memory", musik = "teich", name = L.GAME_MEMORY, info = L.GAME_MEMORY_INFO,
  icon = "Interface\\Icons\\INV_10_Inscription_DarkmoonCards_Fire_2", dauer = 60,
  stufen = {
    { wert = "easy", text = L.LEVEL_EASY, info = L.MEMORY_EASY_INFO, dauer = 60, rekord = "memory" },
    { wert = "hard", text = L.LEVEL_HARD, info = L.MEMORY_HARD_INFO, dauer = 90, rekord = "memory_hard" },
  } }

function ME:Bauen(r)
  self.karten = {}
  for i = 1, MAX_KARTEN do
    local k = S.kasten(r, "Button", F.flaeche, F.rand)
    k.bild = k:CreateTexture(nil, "ARTWORK")
    k.bild:SetPoint("TOPLEFT", 4, -4)
    k.bild:SetPoint("BOTTOMRIGHT", -4, 4)
    k.bild:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    k.ruecken = k:CreateTexture(nil, "ARTWORK")
    -- Kartenrücken aus Blender (dunkelrot, Goldrand, Lagerfeuer), sonst ein Symbol des Spiels
    if S.atlas(k.ruecken, "karte") then
      k.ruecken:SetPoint("TOPLEFT", 1, -1)
      k.ruecken:SetPoint("BOTTOMRIGHT", -1, 1)
    else
      k.ruecken:SetPoint("TOPLEFT", 8, -8)
      k.ruecken:SetPoint("BOTTOMRIGHT", -8, 8)
      k.ruecken:SetTexture("Interface\\Icons\\INV_10_Inscription_DarkmoonCards_Fire_2")
      k.ruecken:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      k.ruecken:SetAlpha(0.45)
    end
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

-- Karten nach der Stufe auslegen, übrige verstecken
local function auslegen(self, a)
  local abstandX = (SP.BREITE - a.spalten * a.karte) / (a.spalten + 1)
  for i, k in ipairs(self.karten) do
    k:SetShown(i <= a.paare * 2)
    local reihe, spalte = math.floor((i - 1) / a.spalten), (i - 1) % a.spalten
    k:SetSize(a.karte, a.karte)
    k:ClearAllPoints()
    k:SetPoint("TOPLEFT", abstandX + spalte * (a.karte + abstandX), -a.oben - reihe * (a.karte + a.reihe))
  end
end

function ME:Start()
  local a = AUFBAU[self.stufe and self.stufe.wert or "easy"] or AUFBAU.easy
  self.paare = a.paare
  auslegen(self, a)
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
  for i = 1, a.paare do
    local m = motive[((i - 1) % #motive) + 1]
    table.insert(stapel, { motiv = m, paar = i })
    table.insert(stapel, { motiv = m, paar = i })
  end
  for i = #stapel, 2, -1 do local j = math.random(1, i) stapel[i], stapel[j] = stapel[j], stapel[i] end
  for i, k in ipairs(self.karten) do
    if stapel[i] then
      k.paar, k.gefunden = stapel[i].paar, false
      k.bild:SetTexture(stapel[i].motiv)
      zeigen(k, false)
    else
      k.paar, k.gefunden = nil, true
    end
  end
  self.erste, self.zweite, self.zudeckenBis, self.gefunden = nil, nil, nil, 0
end

function ME:Umdrehen(k)
  if not (SP.laeuft and SP.aktiv == self) or SP.pause or k.offen or k.gefunden or self.zudeckenBis then return end
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
    if self.gefunden == self.paare then
      SP:Runde(L.MEMORY_DONE, function() ME:Start() end)
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
  "Interface\\Icons\\Ability_Rogue_Sprint", "Interface\\Icons\\INV_Misc_Food_15", "Interface\\Icons\\INV_Misc_Bag_10",
  "Interface\\Icons\\INV_Misc_Lantern_01", "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" }

SP.Registrieren(ME)
