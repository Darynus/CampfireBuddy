-- Erzeugt von tools/grafik/rennbahn.js (npm run rennbahn), nicht von Hand ändern.
-- Strand-Rennbahn für das Murloc-Rennen (Media/Rennbahn.tga), alle Werte 0 bis 1 von oben links:
-- je Bahn (hinten zuerst) y der Mittellinie, x von Start, Ziel und Ende des Auslaufs, mass ist die
-- Bildbreite je Meter in dieser Tiefe (für die Größe der Läufer). Dazu der Platz des Lagerfeuers
-- und die Flammen der Fackeln.
local ADDON, ns = ...
local S = ns.Stil

S.RENNBAHN = "Interface\\AddOns\\CampfireBuddy\\Media\\Rennbahn"
S.RENNBAHN_B, S.RENNBAHN_H = 0.58594, 0.74219   -- genutzter Teil der Textur
S.RENNBAHN_BAHNEN = {
  { y = 0.58149, start = 0.22298, ziel = 0.65928, ende = 0.71469, mass = 0.06925 },   -- hinten
  { y = 0.72784, start = 0.19017, ziel = 0.67815, ende = 0.74011, mass = 0.07746 },   -- Mitte
  { y = 0.91353, start = 0.14855, ziel = 0.70208, ende = 0.77238, mass = 0.08786 },   -- vorne
}
S.RENNBAHN_FEUER = { x = 0.86611, y = 0.72106, mass = 0.07708 }
S.RENNBAHN_FACKELN = {
  { x = 0.13518, y = 0.30414, mass = 0.06633 },
  { x = 0.35471, y = 0.30098, mass = 0.06604 },
  { x = 0.54641, y = 0.30609, mass = 0.0663 },
  { x = 0.74638, y = 0.30983, mass = 0.06659 },
}
