-- Erzeugt von tools/grafik/angeln.js (npm run angeln), nicht von Hand ändern.
-- Grafiken fürs Lagerfeuer-Angeln aus Blender im Atlas Media/Angeln.tga:
-- Name = { links, rechts, oben, unten } als Texturkoordinaten.
local ADDON, ns = ...
local S = ns.Stil

S.ANGELN = "Interface\\AddOns\\CampfireBuddy\\Media\\Angeln"
S.ANGELN_ATLAS = {
  dose = { 0.46875, 0.5625, 0.625, 0.8125 },
  fisch_brasse = { 0.5625, 0.65625, 0.25, 0.4375 },
  fisch_brasse_ab = { 0.75, 0.84375, 0.25, 0.4375 },
  fisch_brasse_auf = { 0.65625, 0.75, 0.25, 0.4375 },
  fisch_elritze = { 0, 0.09375, 0.25, 0.4375 },
  fisch_elritze_ab = { 0.1875, 0.28125, 0.25, 0.4375 },
  fisch_elritze_auf = { 0.09375, 0.1875, 0.25, 0.4375 },
  fisch_mondlachs = { 0.84375, 0.9375, 0.25, 0.4375 },
  fisch_mondlachs_ab = { 0.09375, 0.1875, 0.4375, 0.625 },
  fisch_mondlachs_auf = { 0, 0.09375, 0.4375, 0.625 },
  fisch_mrglkarpfen = { 0.75, 0.84375, 0.4375, 0.625 },
  fisch_mrglkarpfen_ab = { 0, 0.09375, 0.625, 0.8125 },
  fisch_mrglkarpfen_auf = { 0.84375, 0.9375, 0.4375, 0.625 },
  fisch_schlammhecht = { 0.46875, 0.5625, 0.4375, 0.625 },
  fisch_schlammhecht_ab = { 0.65625, 0.75, 0.4375, 0.625 },
  fisch_schlammhecht_auf = { 0.5625, 0.65625, 0.4375, 0.625 },
  fisch_sonnenbarsch = { 0.28125, 0.375, 0.25, 0.4375 },
  fisch_sonnenbarsch_ab = { 0.46875, 0.5625, 0.25, 0.4375 },
  fisch_sonnenbarsch_auf = { 0.375, 0.46875, 0.25, 0.4375 },
  fisch_sternenfisch = { 0.09375, 0.1875, 0.625, 0.8125 },
  fisch_sternenfisch_ab = { 0.28125, 0.375, 0.625, 0.8125 },
  fisch_sternenfisch_auf = { 0.1875, 0.28125, 0.625, 0.8125 },
  fisch_wels = { 0.1875, 0.28125, 0.4375, 0.625 },
  fisch_wels_ab = { 0.375, 0.46875, 0.4375, 0.625 },
  fisch_wels_auf = { 0.28125, 0.375, 0.4375, 0.625 },
  rute_biegen1 = { 0.75, 0.875, 0, 0.25 },
  rute_biegen2 = { 0.875, 1, 0, 0.25 },
  rute_ruhe = { 0.5, 0.625, 0, 0.25 },
  rute_zurueck = { 0.625, 0.75, 0, 0.25 },
  schatten1 = { 0, 0.125, 0.8125, 0.9375 },
  schatten2 = { 0.125, 0.25, 0.8125, 0.9375 },
  schatten_hell1 = { 0.4375, 0.5625, 0.8125, 0.9375 },
  schatten_hell2 = { 0.5625, 0.6875, 0.8125, 0.9375 },
  schwimmer = { 0.375, 0.4375, 0.8125, 0.9375 },
  spritzer1 = { 0, 0.125, 0, 0.25 },
  spritzer2 = { 0.125, 0.25, 0, 0.25 },
  spritzer3 = { 0.25, 0.375, 0, 0.25 },
  spritzer4 = { 0.375, 0.5, 0, 0.25 },
  stiefel = { 0.375, 0.46875, 0.625, 0.8125 },
  welle = { 0.25, 0.375, 0.8125, 0.9375 },
}
-- Rutenspitze im Bild der Rute, 0 bis 1 von oben links
S.ANGELN_SPITZE = {
  ruhe = { 0.23513, 0.35005 },
  zurueck = { 0.6467, 0.06808 },
  biegen1 = { 0.18692, 0.43393 },
  biegen2 = { 0.17337, 0.51916 },
}
S.ANGELN_WASSERLINIE = 0.64419   -- Wasserlinie im Bild des Schwimmers (von oben)
S.ANGELN_SPRITZER_FUSS = 0.66351   -- Wasserfläche im Bild der Spritzer (von oben)
-- Tiefe des Teichs je 10 x 10 Pixel der Spielfläche (300 x 190), Zeile für Zeile von oben:
-- 0 Ufer, 1 flach bis 9 tief
S.ANGELN_TIEFE = {
  "000000000000000000000000000000",
  "000000000000000000000000000000",
  "000000000000000000000000000000",
  "000000000000000000000000000000",
  "000000000000000000000000000000",
  "000000000000000000000000000000",
  "000000000000000000000000000000",
  "000000000000000000000000000000",
  "000000002333333333333320000000",
  "000000233456666666665432000000",
  "000233345677888888876543200000",
  "002345666778999888887654332000",
  "000233334566777666666654320000",
  "000000023334565433333333200000",
  "000000000023333320000000000000",
  "000000000000022000000000000000",
  "000000000000000000000000000000",
  "000000000000000000000000000000",
  "000000000000000000000000000000",
}
