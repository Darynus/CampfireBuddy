-- Erzeugt von tools/grafik/wiese.js (npm run wiese), nicht von Hand ändern.
-- Waldwiese für Whack-a-Murloc (Media/Wiese.tga) und die Lage ihrer sechs Löcher, 0 bis 1 von
-- oben links: x, y Mitte des Lochs, breite der Öffnung, schnitt Oberkante des vorderen Erdwalls.
local ADDON, ns = ...
local S = ns.Stil

S.WIESE = "Interface\\AddOns\\CampfireBuddy\\Media\\Wiese"
S.WIESE_B, S.WIESE_H = 0.58594, 0.74219   -- genutzter Teil der Textur
S.WIESE_LOECHER = {
  { x = 0.26326, y = 0.44507, breite = 0.0896, schnitt = 0.46879 },   -- hinten
  { x = 0.5, y = 0.43607, breite = 0.08834, schnitt = 0.45746 },   -- hinten
  { x = 0.73563, y = 0.45473, breite = 0.08918, schnitt = 0.47372 },   -- hinten
  { x = 0.16551, y = 0.65757, breite = 0.13017, schnitt = 0.72698 },   -- vorne
  { x = 0.5, y = 0.64856, breite = 0.1275, schnitt = 0.69315 },   -- vorne
  { x = 0.8355, y = 0.65195, breite = 0.13056, schnitt = 0.72006 },   -- vorne
}
