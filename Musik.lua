-- Eigene Arcade-Musik in den Lagerfeuer-Spielen. Die vier Stücke sind selbst komponiert und mit
-- einem eigenen kleinen Synthesizer erzeugt (tools/musik): Arcade fürs Menü, Mayhem für die
-- schnellen Spiele, Teich für die ruhigen, Rennen fürs Murloc-Rennen, Schleichen und Alarm fürs
-- Schleich-Spiel. Läuft nur, solange das
-- Spielfenster offen ist, abschaltbar (spielMusik). Danach spielt wieder die Zonenmusik.
-- Ist die Musik im Spiel an, läuft das Stück über den Musikkanal (PlayMusic, mit der
-- Musiklautstärke des Spiels). Ist sie aus (Sound_EnableMusic 0), wäre PlayMusic stumm: Patrick
-- hatte die Zonenmusik abgestellt und hörte in den Spielen nichts mehr (18. Okt). Dann läuft das
-- Stück über den Effektkanal (PlaySoundFile) und wird nach seiner Länge neu gestartet.
local ADDON, ns = ...

local MU = {}
ns.Musik = MU

local PFAD = "Interface\\AddOns\\CampfireBuddy\\Media\\Musik\\"
local TOENE = "Interface\\AddOns\\CampfireBuddy\\Media\\Toene\\"
-- Lautstärkeregler unter den Spielen (Patrick, 18. Okt): 0 aus, 1 = 33 %, 2 = 66 %, 3 = 100 %. Ein
-- Add-on kann einen Ton nicht leiser abspielen, deshalb liegen Musik und Spiel-Effekte in drei
-- Fassungen da (tools/musik/leiser.js). Die Lautstärke des Spiels selbst bleibt unberührt.
local ENDUNG = { [1] = "_33", [2] = "_66", [3] = "" }

function MU.Stufe()
  local s = ns.db and ns.db.spielLautstaerke
  if type(s) ~= "number" or s < 0 or s > 3 then return 3 end
  return math.floor(s)
end

function MU.Datei(name) return PFAD .. MU.STUECKE[name] .. (ENDUNG[MU.Stufe()] or "") .. ".ogg" end

-- Effekt eines Spiels (Media/Toene/<name>.ogg) in der Lautstärke des Reglers, aus bei Stufe 0 oder
-- wenn die lustigen Töne aus sind
function MU.Effekt(name)
  local stufe = MU.Stufe()
  if stufe == 0 or not (ns.db and ns.db.murlocTon and PlaySoundFile) then return end
  pcall(PlaySoundFile, TOENE .. name .. (ENDUNG[stufe] or "") .. ".ogg", "SFX")
end
MU.STUECKE = { arcade = "Arcade", mayhem = "Mayhem", teich = "Teich", rennen = "Rennen", schleichen = "Schleichen",
  alarm = "Alarm" }
-- Länge in Sekunden (ffprobe), für die Wiederholung über den Effektkanal
MU.LAENGE = { arcade = 43.64, mayhem = 31.58, teich = 43.64, rennen = 40.0, schleichen = 34.29, alarm = 22.33 }

-- Ist die Musik im Spiel eingeschaltet? Ohne Antwort: ja
local function spielMusikAn()
  if not GetCVar then return true end
  local ok, wert = pcall(GetCVar, "Sound_EnableMusic")
  return not ok or wert ~= "0"
end

-- Über den Effektkanal spielen und nach der Länge des Stücks neu starten. Die Nummer beendet eine
-- alte Schleife, sobald ein anderes Stück läuft oder die Musik stoppt.
function MU:Schleife(name)
  self.nummer = (self.nummer or 0) + 1
  local nummer = self.nummer
  local ok, spielt, griff = pcall(PlaySoundFile, MU.Datei(name), "SFX")
  if not (ok and spielt) then
    self.laeuft = nil
    return
  end
  self.laeuft, self.art, self.griff = name, "effekt", griff
  if C_Timer and C_Timer.After then
    C_Timer.After(MU.LAENGE[name] or 40, function()
      if self.nummer == nummer and self.laeuft == name then self:Schleife(name) end
    end)
  end
end

function MU:Spielen(name)
  self.gewuenscht = name
  if not (ns.db and ns.db.spielMusik) or MU.Stufe() == 0 then return self:Stop(true) end
  if self.laeuft == name then return end
  if not MU.STUECKE[name] then return end
  -- Ein Stück über den Effektkanal läuft weiter, bis man es anhält
  if self.art == "effekt" then self:Stop(true) end
  if spielMusikAn() and PlayMusic then
    local ok = pcall(PlayMusic, MU.Datei(name))
    self.laeuft, self.art = ok and name or nil, ok and "musik" or nil
  elseif PlaySoundFile then
    self:Schleife(name)
  end
end

-- behalten: das gewünschte Stück merken (Musik nur abgeschaltet, Fenster noch offen)
function MU:Stop(behalten)
  if not behalten then self.gewuenscht = nil end
  self.nummer = (self.nummer or 0) + 1
  if self.laeuft then
    if self.art == "effekt" then
      if self.griff and StopSound then pcall(StopSound, self.griff) end
    elseif StopMusic then
      pcall(StopMusic)
    end
  end
  self.laeuft, self.art, self.griff = nil, nil, nil
end

-- Schalter in den Optionen umgelegt oder Lautstärke geändert: das Stück neu in der passenden Fassung
function MU:Einstellung()
  local stueck = self.gewuenscht
  self:Stop(true)
  if ns.db.spielMusik and stueck then self:Spielen(stueck) end
end
