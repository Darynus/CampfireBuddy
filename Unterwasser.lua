-- Erzeugt von tools/grafik/unterwasser.js (npm run unterwasser), nicht von Hand ändern.
-- Unterwasser-Szene für Murloc Dive (Media/Unterwasser.tga, aus grafik/blender/unterwasser.py).
-- Ausschnitte als Texturkoordinaten { links, rechts, oben, unten }, Maße in Pixeln der Spielfläche.
--   hinten   ferne Ebene (Felsen, Tangwald, Mondstrahlen), 300 x 190, waagerecht nahtlos
--   vorn     Seegrund, 300 x hoehe, oben durchsichtig, waagerecht nahtlos
--   boden    Oberkante des Sandes über dem unteren Rand
--   hindernisse: b x h, oben = hängt von oben (Spitze unten), sonst steht es auf dem Grund (Spitze
--            oben). profil: je 4 Pixel ab der Spitze linke und rechte Kante, relativ zur Mitte.
local ADDON, ns = ...
local S = ns.Stil

S.UNTERWASSER = {
  datei = "Interface\\AddOns\\CampfireBuddy\\Media\\Unterwasser",
  hinten = { 0, 0.585938, 0, 0.742188 },
  vorn = { 0, 0.585938, 0.75, 1, hoehe = 64 },
  boden = 14,
  band = 4,
  hindernisse = {
    tang = { 0.59375, 0.6875, 0, 0.498047, b = 48, h = 127.5, oben = false,
      profil = { -1, 1, -2, 1.5, -9, 1.5, -9, 1, -11.5, 3, -11.5, 3, -11.5, 2.5, -11, 12.5, -11, 12.5, -11, 12.5, -11, 12.5, -13.5, 13.5, -13.5, 13.5, -13.5, 13, -13, 12.5, -12, 12, -12.5, 12, -12.5, 11.5, -12.5, 11.5, -12, 10.5, -11.5, 9.5, -11.5, 8.5, -11.5, 10.5, -11.5, 10.5, -11, 10.5, -10.5, 10, -9, 9, -7, 7.5, -11.5, 7.5, -11.5, 7, -11.5, 11, -11, 11.5 } },
    fels = { 0.695313, 0.789063, 0, 0.484375, b = 48, h = 124, oben = false,
      profil = { -6, 6, -6, 5.5, -11.5, 10, -14.5, 13, -14.5, 16, -15, 16.5, -14, 14.5, -12.5, 15.5, -11.5, 13.5, -13, 13, -13, 15.5, -12.5, 15.5, -12.5, 17.5, -12, 16.5, -12.5, 13.5, -11, 13, -11, 12.5, -10, 12.5, -14, 15.5, -14, 15.5, -13.5, 14.5, -14.5, 13.5, -15, 14.5, -14.5, 16, -14.5, 15, -14.5, 16.5, -14, 15.5, -14.5, 14.5, -14, 15, -14.5, 14.5, -15.5, 15 } },
    netz = { 0.796875, 0.890625, 0, 0.478516, b = 48, h = 122.5, oben = true,
      profil = { -15.5, 15.5, -12, 12.5, -14, 14.5, -13.5, 14, -14, 14.5, -14, 10.5, -13, 5, -14.5, 5.5, -12.5, 5.5, -14, 10.5, -14.5, 14.5, -14, 13.5, -14.5, 13.5, -12.5, 13, -14, 14.5, -12.5, 13, -14, 14.5, -10.5, 11, -10.5, 11.5, -9, 12.5, -5, 13.5, -2.5, 14, -4, 13, -10.5, 14, -14, 14.5, -13, 13.5, -14, 14, -12, 13, -13.5, 14.5, -14, 14.5, -14, 15 } },
    anker = { 0.898438, 0.992188, 0, 0.496094, b = 48, h = 127, oben = true,
      profil = { -9, 9, -14, 14, -14.5, 14.5, -14.5, 14.5, -1.5, 1.5, -1.5, 1.5, -8, 8, -4, 4, -4, 4, -2.5, 2.5, -2, 2, -2.5, 2.5, -2, 2, -2.5, 2.5, -2.5, 2.5, -2.5, 2.5, -2.5, 2.5, -1.5, 1.5, -2.5, 2.5, -2, 2, -2.5, 2.5, -2.5, 2.5, -2, 2, -2.5, 2.5, -2, 2, -2.5, 2.5, -2.5, 2.5, -2.5, 2.5, -2.5, 2.5, -2, 2, -2.5, 2.5, -2, 2 } },
  },
  perle = { 0.59375, 0.65625, 0.515625, 0.640625 },
  muschel = { 0.664063, 0.726563, 0.515625, 0.640625 },
  blase = { 0.734375, 0.796875, 0.515625, 0.640625 },
  symbol = { 0.59375, 0.6875, 0, 0.1875 },
}
