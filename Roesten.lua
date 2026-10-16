-- Erzeugt von tools/grafik/roesten.js (npm run roesten), nicht von Hand ändern.
-- Marshmallow rösten: Feuerstelle aus Blender (Media/Roesten.tga, darin auch der Stock), Flammen
-- als Endlosschleife (Media/RoestenFeuer.tga, 4 x 2 Bilder) und die Teile (Media/RoestenTeile.tga).
-- Lagen 0 bis 1 von oben links der Spielfläche, Größen der Teile in Einheiten der Spielfläche.
local ADDON, ns = ...
local S = ns.Stil

S.ROESTEN = "Interface\\AddOns\\CampfireBuddy\\Media\\Roesten"
S.ROESTEN_FEUER = "Interface\\AddOns\\CampfireBuddy\\Media\\RoestenFeuer"
S.ROESTEN_TEILE = "Interface\\AddOns\\CampfireBuddy\\Media\\RoestenTeile"
S.ROESTEN_SZENE = { 0, 0.58594, 0, 0.74219 }   -- Texturkoordinaten der Szene
-- Flammen-Ausschnitt in der Spielfläche
S.ROESTEN_FLAMMEN = { x = 0.24333, y = 0.22632, b = 0.42667, h = 0.67368 }
-- Feuer: x Mitte, bett Glutbett, krone Spitze der Scheite, spitze Flammenspitze, oben höchste Flamme
S.ROESTEN_ORT = { x = 0.46728, bett = 0.82279, krone = 0.60797, spitze = 0.41672, oben = 0.31444 }
-- Stock: Texturkoordinaten in Media/Roesten, Größe, Lage der Spitze (Mitte des Marshmallows) im Bild
S.ROESTEN_STOCK = { coords = { 0.625, 0.97656, 0, 0.4375 }, b = 180, h = 112, x = 8, y = 8 }
S.ROESTEN_ZELLE = 64   -- Kantenlänge einer Marshmallow-Zelle in Einheiten (Mitte = Spitze des Stocks)
S.ROESTEN_TEIL = {
  biss0 = { 0, 0.125, 0.5, 0.75 },
  biss1 = { 0.125, 0.25, 0.5, 0.75 },
  biss2 = { 0.25, 0.375, 0.5, 0.75 },
  biss3 = { 0.375, 0.5, 0.5, 0.75 },
  biss4 = { 0.5, 0.625, 0.5, 0.75 },
  bissUnten0 = { 0, 0.125, 0.75, 1 },
  bissUnten1 = { 0.125, 0.25, 0.75, 1 },
  bissUnten2 = { 0.25, 0.375, 0.75, 1 },
  bissUnten3 = { 0.375, 0.5, 0.75, 1 },
  bissUnten4 = { 0.5, 0.625, 0.75, 1 },
  ganz0 = { 0, 0.125, 0, 0.25 },
  ganz1 = { 0.125, 0.25, 0, 0.25 },
  ganz2 = { 0.25, 0.375, 0, 0.25 },
  ganz3 = { 0.375, 0.5, 0, 0.25 },
  ganz4 = { 0.5, 0.625, 0, 0.25 },
  rauch1 = { 0.625, 0.75, 0, 0.25 },
  rauch2 = { 0.75, 0.875, 0, 0.25 },
  schief = { 0.75, 0.875, 0.25, 0.5 },
  unten0 = { 0, 0.125, 0.25, 0.5 },
  unten1 = { 0.125, 0.25, 0.25, 0.5 },
  unten2 = { 0.25, 0.375, 0.25, 0.5 },
  unten3 = { 0.375, 0.5, 0.25, 0.5 },
  unten4 = { 0.5, 0.625, 0.25, 0.5 },
  zunge1 = { 0.875, 0.9375, 0, 0.125 },
  zunge2 = { 0.9375, 1, 0, 0.125 },
  zunge3 = { 0.875, 0.9375, 0.125, 0.25 },
  zunge4 = { 0.9375, 1, 0.125, 0.25 },
  zunge5 = { 0.625, 0.6875, 0.25, 0.375 },
  zunge6 = { 0.6875, 0.75, 0.25, 0.375 },
  zunge7 = { 0.625, 0.6875, 0.375, 0.5 },
  zunge8 = { 0.6875, 0.75, 0.375, 0.5 },
}
