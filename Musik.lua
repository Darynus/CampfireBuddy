-- Eigene Arcade-Musik in den Lagerfeuer-Spielen. Die vier Stücke sind selbst komponiert und mit
-- einem eigenen kleinen Synthesizer erzeugt (tools/musik): Arcade fürs Menü, Mayhem für die
-- schnellen Spiele, Teich für die ruhigen, Rennen fürs Murloc-Rennen. Läuft nur, solange das Spielfenster offen ist, mit
-- der Musiklautstärke des Spiels, abschaltbar (spielMusik). Danach spielt wieder die Zonenmusik.
local ADDON, ns = ...

local MU = {}
ns.Musik = MU

local PFAD = "Interface\\AddOns\\CampfireBuddy\\Media\\Musik\\"
MU.STUECKE = { arcade = "Arcade", mayhem = "Mayhem", teich = "Teich", rennen = "Rennen" }

function MU:Spielen(name)
  self.gewuenscht = name
  if not (ns.db and ns.db.spielMusik) or not PlayMusic then return self:Stop(true) end
  if self.laeuft == name then return end
  local datei = MU.STUECKE[name]
  if not datei then return end
  local ok = pcall(PlayMusic, PFAD .. datei .. ".ogg")
  self.laeuft = ok and name or nil
end

-- behalten: das gewünschte Stück merken (Musik nur abgeschaltet, Fenster noch offen)
function MU:Stop(behalten)
  if not behalten then self.gewuenscht = nil end
  if self.laeuft and StopMusic then pcall(StopMusic) end
  self.laeuft = nil
end

-- Schalter in den Optionen umgelegt
function MU:Einstellung()
  if ns.db.spielMusik and self.gewuenscht then self:Spielen(self.gewuenscht) else self:Stop(true) end
end
