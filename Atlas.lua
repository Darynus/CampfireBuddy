-- Erzeugt von tools/grafik/spiele.js (npm run spiele), nicht von Hand ändern.
-- Eigene Grafiken der Lagerfeuer-Spiele aus Blender im Atlas Media/Spiele.tga:
-- Name = { links, rechts, oben, unten } als Texturkoordinaten. Zeichnen mit S.atlas(textur, name).
local ADDON, ns = ...
local S = ns.Stil

S.SPIELE = "Interface\\AddOns\\CampfireBuddy\\Media\\Spiele"
S.TEICH = "Interface\\AddOns\\CampfireBuddy\\Media\\Teich"
S.TEICH_B, S.TEICH_H = 1, 0.632813   -- genutzter Teil der Teich-Textur
S.NACHT_HOEHE = 0.660156   -- genutzter Teil der Nachtszene (1024 x 512)
S.NACHT_SEITE = 512 / 1024   -- Höhe zu Breite der Textur
-- Mittellinie des Wegs in der Nachtszene am linken und rechten Bildrand, von oben (0 bis 1 der
-- Szene), und Lage des Lagerfeuers in der Breite. Die Show stellt den Murloc darauf.
S.NACHT_WEG = { 0.90702, 0.85459 }
S.NACHT_FEUER = 0.915
S.ATLAS = {
  bombe = { 0.5, 0.75, 0.5, 0.75 },
  flagge = { 0.25, 0.5, 0.75, 1 },
  funke = { 0.75, 1, 0.75, 1 },
  glut = { 0.75, 1, 0.5, 0.75 },
  karte = { 0.75, 1, 0.25, 0.5 },
  loch = { 0.5, 0.75, 0.25, 0.5 },
  marshmallow0 = { 0, 0.25, 0, 0.25 },
  marshmallow1 = { 0.25, 0.5, 0, 0.25 },
  marshmallow2 = { 0.5, 0.75, 0, 0.25 },
  marshmallow3 = { 0.75, 1, 0, 0.25 },
  ring = { 0.5, 0.75, 0.75, 0.875 },
  schein = { 0.5, 0.5625, 0.9375, 1 },
  scheit = { 0.5, 0.75, 0.875, 0.9375 },
  schwimmer = { 0, 0.25, 0.25, 0.5 },
  seerose = { 0.25, 0.5, 0.25, 0.5 },
  totem_feuer = { 0, 0.25, 0.5, 0.75 },
  totem_frost = { 0.25, 0.5, 0.5, 0.75 },
  zelt = { 0, 0.25, 0.75, 1 },
}
