-- Erzeugt von tools/grafik/funkenglas.js (npm run funkenglas), nicht von Hand ändern.
-- Grafiken des Funkenfängers in Media/Funkenglas.tga: Szene (Lagerfeuer-Platz bei Nacht), Einmachglas
-- kopfüber in fünf Neigungen, sein Licht von innen (additiv) und Aschewolken.
local ADDON, ns = ...
local S = ns.Stil

S.FUNKENGLAS = "Interface\\AddOns\\CampfireBuddy\\Media\\Funkenglas"
S.FUNKENGLAS_SZENE = { 0, 0.58594, 0, 0.74219 }
-- Feuerstelle in der Szene (0 bis 1 von oben links)
S.FUNKENGLAS_FEUER = { x = 0.5, y = 0.93 }
S.FUNKENGLAS_TEILE = {
  glas1 = { 0.625, 0.75, 0, 0.25 },
  glas2 = { 0.75, 0.875, 0, 0.25 },
  glas3 = { 0.875, 1, 0, 0.25 },
  glas4 = { 0.625, 0.75, 0.25, 0.5 },
  glas5 = { 0.75, 0.875, 0.25, 0.5 },
  licht1 = { 0.875, 1, 0.25, 0.5 },
  licht2 = { 0.625, 0.75, 0.5, 0.75 },
  licht3 = { 0.75, 0.875, 0.5, 0.75 },
  licht4 = { 0.875, 1, 0.5, 0.75 },
  licht5 = { 0.625, 0.75, 0.75, 1 },
  asche1 = { 0.75, 0.875, 0.75, 1 },
  asche2 = { 0.875, 1, 0.75, 1 },
  asche3 = { 0, 0.125, 0.75, 1 },
}
-- Glas je Neigung (links nach rechts): Mitte der Öffnung im Bild (0 bis 1 von oben links) und
-- Breite der Öffnung (Anteil der Bildbreite). Drehpunkt ist der Boden oben, Länge und Breite des
-- Glases als Anteil der Bildbreite.
S.FUNKENGLAS_GLAS = {
  { mx = 0.27111, my = 0.91049, breite = 0.39845 },   -- -15 Grad
  { mx = 0.38457, my = 0.93306, breite = 0.40897 },   -- -7.5 Grad
  { mx = 0.5, my = 0.94063, breite = 0.4125 },   -- 0 Grad
  { mx = 0.61543, my = 0.93306, breite = 0.40897 },   -- 7.5 Grad
  { mx = 0.72889, my = 0.91049, breite = 0.39845 },   -- 15 Grad
}
S.FUNKENGLAS_DREH = { x = 0.5, y = 0.05625 }
S.FUNKENGLAS_LAENGE, S.FUNKENGLAS_BREITE = 0.88438, 0.5875
