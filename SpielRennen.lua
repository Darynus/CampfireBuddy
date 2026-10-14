-- Murloc-Rennen: drei Murlocs rennen zum Lagerfeuer. Vorher auf einen tippen, dann zuschauen.
-- Jeder Murloc hat Tagesform, Sprints und Stolperer. Richtig getippt: 5 Punkte, drei Siege in
-- Folge geben 5 extra. Fünf Rennen pro Spiel.
local ADDON, ns = ...
local L, S = ns.L, ns.Stil
local F, rgba = S.F, S.rgba
local SP = ns.Spiel

local KOPF = "Interface\\Icons\\INV_Misc_Head_Murloc_01"
local RENNEN = 5
local FARBEN = { { 0.55, 0.85, 1 }, { 0.55, 1, 0.55 }, { 1, 0.6, 0.55 } }

local R = { key = "rennen", name = L.GAME_RACE, info = L.GAME_RACE_INFO,
  icon = "Interface\\Icons\\INV_MurlocMount", dauer = 150 }

function R:Bauen(r)
  self.bahnen = {}
  self.ziel = r:CreateTexture(nil, "ARTWORK")
  self.ziel:SetSize(28, 28)
  self.ziel:SetPoint("RIGHT", -6, 4)
  self.ziel:SetTexture(S.FLAMME)
  local linie = r:CreateTexture(nil, "BACKGROUND")
  linie:SetSize(2, 130)
  linie:SetPoint("RIGHT", -40, 4)
  linie:SetColorTexture(1, 1, 1, 0.25)
  for i = 1, 3 do
    local y = -30 - (i - 1) * 42
    local bahn = r:CreateTexture(nil, "BACKGROUND")
    bahn:SetSize(SP.BREITE - 20, 30)
    bahn:SetPoint("TOPLEFT", 10, y)
    bahn:SetColorTexture(FARBEN[i][1] * 0.15, FARBEN[i][2] * 0.15, FARBEN[i][3] * 0.15, 0.8)
    -- Die ganze Bahn ist zum Tippen da, nicht nur der kleine Kopf
    local feld = CreateFrame("Button", nil, r)
    feld:SetSize(SP.BREITE - 20, 30)
    feld:SetPoint("TOPLEFT", 10, y)
    feld.hell = feld:CreateTexture(nil, "BORDER")
    feld.hell:SetAllPoints()
    feld.hell:SetColorTexture(FARBEN[i][1], FARBEN[i][2], FARBEN[i][3], 0.18)
    feld.hell:Hide()
    feld:SetScript("OnEnter", function(self) if R.phase == "tippen" then self.hell:Show() end end)
    feld:SetScript("OnLeave", function(self) self.hell:Hide() end)
    feld:SetScript("OnClick", function(self) self.hell:Hide() R:Tippen(i) end)
    local m = CreateFrame("Button", nil, r)
    m:SetSize(28, 28)
    m.kopf = m:CreateTexture(nil, "ARTWORK")
    m.kopf:SetAllPoints()
    m.kopf:SetTexture(KOPF)
    m.kopf:SetTexCoord(0.92, 0.08, 0.08, 0.92)   -- gespiegelt: Blick nach rechts
    m.kopf:SetVertexColor(FARBEN[i][1], FARBEN[i][2], FARBEN[i][3])
    m.wahl = m:CreateTexture(nil, "OVERLAY")
    m.wahl:SetSize(34, 34)
    m.wahl:SetPoint("CENTER")
    m.wahl:SetTexture(S.WEISS)
    m.wahl:SetVertexColor(1, 0.84, 0.3, 0.35)
    m.wahl:Hide()
    m.y, m.nr = y - 1, i
    m:SetScript("OnClick", function() R:Tippen(i) end)
    m.name = S.schrift(r, "GameFontHighlightSmall", { FARBEN[i][1], FARBEN[i][2], FARBEN[i][3], 0.8 })
    m.name:SetPoint("TOPRIGHT", r, "TOPLEFT", SP.BREITE - 46, y - 2)
    self.bahnen[i] = m
  end
  self.text = S.schrift(r, "GameFontNormal", F.text)
  self.text:SetPoint("TOP", 0, -8)
end

local function setzen(m, x)
  m:ClearAllPoints()
  m:SetPoint("TOPLEFT", 12 + x, m.y)
end

function R:Aufstellen()
  self.phase, self.tipp = "tippen", nil
  -- jedes Rennen drei neue Murlocs mit Namen
  local namen = {}
  for _, n in ipairs(L.MURLOC_NAMES) do table.insert(namen, n) end
  for _, m in ipairs(self.bahnen) do
    m.x, m.form, m.sprintBis, m.stolperBis = 0, SP.zufall(0.85, 1.15), nil, nil
    m.rufName = table.remove(namen, math.random(1, #namen))
    m.name:SetText(m.rufName)
    m.wahl:Hide()
    m.kopf:SetAlpha(1)
    setzen(m, 0)
  end
  self.text:SetText(string.format(L.RACE_PICK, self.nr, RENNEN))
  self.text:SetTextColor(rgba(F.text))
end

function R:Start()
  self.nr, self.serie = 1, 0
  self:Aufstellen()
end

function R:Tippen(i)
  if not (SP.laeuft and SP.aktiv == self) or self.phase ~= "tippen" then return end
  self.tipp, self.phase = i, "laeuft"
  self.bahnen[i].wahl:Show()
  self.text:SetText(SP.spruch(L.RACE_START))
  ns.ton("start")
  ns.mrgl()
  self.kommentarBis = ns.jetzt() + 1.5
end

function R:Tick(dt, jetzt)
  if self.phase == "pause" then
    if jetzt >= self.pauseBis then
      self.nr = self.nr + 1
      if self.nr > RENNEN then return SP:Fertig() end
      self:Aufstellen()
    end
    return
  end
  if self.phase ~= "laeuft" then return end
  local strecke = SP.BREITE - 80
  local imZiel = {}
  for _, m in ipairs(self.bahnen) do
    -- Zufall pro Bild: Sprint (schneller) oder Stolpern (kurz stehen), mit Kommentar
    if not m.sprintBis and not m.stolperBis then
      local w = math.random()
      if w < dt * 0.35 then
        m.sprintBis = jetzt + SP.zufall(0.4, 0.9)
        self:Kommentar(string.format(SP.spruch(L.RACE_SPRINT), m.rufName), jetzt)
      elseif w < dt * 0.55 then
        m.stolperBis = jetzt + SP.zufall(0.3, 0.6)
        self:Kommentar(string.format(SP.spruch(L.RACE_TRIP), m.rufName), jetzt)
      end
    end
    local tempo = 34 * m.form
    if m.sprintBis then
      tempo = tempo * 2
      if jetzt >= m.sprintBis then m.sprintBis = nil end
    elseif m.stolperBis then
      tempo = 0
      if jetzt >= m.stolperBis then m.stolperBis = nil end
    end
    m.x = m.x + tempo * dt
    -- Hüpfen beim Laufen, Stolpern: kurz abtauchen und blass (ohne Drehung, die würde die
    -- Spiegelung des Bilds aufheben)
    local hopp = tempo > 0 and math.abs(math.sin(jetzt * 14 + m.nr)) * 3 or -4
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", 12 + math.min(strecke, m.x), m.y + hopp)
    m.kopf:SetAlpha(m.stolperBis and 0.6 or 1)
    if m.x >= strecke then table.insert(imZiel, m) end
  end
  -- Wer am weitesten über die Linie ist, gewinnt. Gleichstand: Zufall, nicht die obere Bahn.
  if #imZiel > 0 then
    table.sort(imZiel, function(a, b)
      if a.x ~= b.x then return a.x > b.x end
      return math.random() < 0.5
    end)
    local knapp = imZiel[2] and (imZiel[1].x - imZiel[2].x) < 4
    return self:Ziel(imZiel[1], knapp)
  end
end

function R:Kommentar(text, jetzt)
  if jetzt < (self.kommentarBis or 0) then return end
  self.kommentarBis = jetzt + 1.4
  self.text:SetText(text)
  self.text:SetTextColor(rgba(F.text))
end

function R:Ziel(sieger, knapp)
  self.phase, self.pauseBis = "pause", ns.jetzt() + 2.4
  if knapp then SP:Ruf(L.RACE_PHOTO, SP.BREITE / 2, -100, { 1, 1, 1, 1 }) end
  if sieger.nr == self.tipp then
    self.serie = self.serie + 1
    local bonus = self.serie % 3 == 0 and 5 or 0
    SP:Plus(5 + bonus)
    self.text:SetText(string.format(bonus > 0 and L.RACE_WIN_STREAK or L.RACE_WIN, sieger.rufName))
    self.text:SetTextColor(rgba(F.erfolg))
    SP:Ruf("+" .. (5 + bonus), SP.BREITE - 60, sieger.y - 10)
    ns.ton(bonus > 0 and "paar" or "muenze")
  else
    self.serie = 0
    ns.ton("minus")
    self.text:SetText(string.format(L.RACE_LOSE, sieger.rufName))
    self.text:SetTextColor(rgba(F.hinweis))
  end
end

SP.Registrieren(R)
