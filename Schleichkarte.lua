-- Erzeugt von tools/grafik/schleichen.js (npm run schleichen), nicht von Hand ändern.
-- Karte für Sneaky Mrgl (Media/Schleichkarte, Blender: grafik/blender/schleichen.py) und das
-- Bildblatt mit Murloc, Karton und Gegenständen (Media/SchleichTeile, Murloc aus grafik/blender/agent.py).
-- Alle Lagen in Punkten der Spielfläche (300 x 190, von oben links, y nach unten).
--   hindernisse: { "r", links, oben, rechts, unten } oder { "k", x, y, Radius } (versperren Weg und Sicht)
--   bachX: links davon ist Wasser, dort sieht den Murloc niemand, dort gibt er die Fische ab
--   plaetze: hier können Fische auftauchen
--   teile: Bildlagen im Bildblatt, m<Richtung>_<Schritt> (Richtung 0 = zum Betrachter, dann im
--   Uhrzeigersinn je 45 Grad), murlocFuss: Anteil des Bildes unter den Füßen
local ADDON, ns = ...

ns.Schleichkarte = {
  textur = "Interface\\AddOns\\CampfireBuddy\\Media\\Schleichkarte",
  b = 0.5859, h = 0.7422,   -- genutzter Teil der Textur
  kegel = "Interface\\AddOns\\CampfireBuddy\\Media\\Sichtkegel",
  pfeil = "Interface\\AddOns\\CampfireBuddy\\Media\\Pfeil",
  bachX = 30,
  start = { 16, 120 },
  feuer = { 160, 104 },
  plaetze = { { 64, 56 }, { 102, 52 }, { 150, 52 }, { 214, 52 }, { 280, 64 }, { 236, 98 }, { 282, 140 }, { 250, 172 }, { 196, 146 }, { 150, 140 }, { 104, 120 }, { 60, 124 }, { 98, 176 }, { 184, 74 } },
  laternen = { { 126, 58 }, { 208, 92 } },
  hindernisse = {
    { "r", 112, 0, 196, 34 },
    { "r", 44, 4, 84, 38 },
    { "r", 236, 8, 288, 46 },
    { "r", 92, 78, 114, 96 },
    { "r", 212, 126, 234, 144 },
    { "r", 66, 140, 86, 156 },
    { "r", 100, 148, 124, 160 },
    { "r", 226, 62, 258, 78 },
    { "r", 40, 70, 44, 110 },
    { "k", 160, 104, 12 },
    { "k", 132, 162, 7 },
    { "k", 258, 112, 7 },
    { "k", 126, 58, 3 },
    { "k", 208, 92, 3 },
  },
  teileTextur = "Interface\\AddOns\\CampfireBuddy\\Media\\SchleichTeile",
  murlocFuss = 0.16,
  teile = {
    fisch = { 0.875, 0.9375, 0.4375, 0.5625 },
    goldfisch = { 0.9375, 1, 0.4375, 0.5625 },
    karton0 = { 0.875, 0.98438, 0, 0.21875 },
    karton1 = { 0.875, 0.98438, 0.21875, 0.4375 },
    m0_0 = { 0, 0.10938, 0, 0.21875 },
    m0_1 = { 0.10938, 0.21875, 0, 0.21875 },
    m0_2 = { 0.21875, 0.32813, 0, 0.21875 },
    m0_3 = { 0.32813, 0.4375, 0, 0.21875 },
    m1_0 = { 0.4375, 0.54688, 0, 0.21875 },
    m1_1 = { 0.54688, 0.65625, 0, 0.21875 },
    m1_2 = { 0.65625, 0.76563, 0, 0.21875 },
    m1_3 = { 0.76563, 0.875, 0, 0.21875 },
    m2_0 = { 0, 0.10938, 0.21875, 0.4375 },
    m2_1 = { 0.10938, 0.21875, 0.21875, 0.4375 },
    m2_2 = { 0.21875, 0.32813, 0.21875, 0.4375 },
    m2_3 = { 0.32813, 0.4375, 0.21875, 0.4375 },
    m3_0 = { 0.4375, 0.54688, 0.21875, 0.4375 },
    m3_1 = { 0.54688, 0.65625, 0.21875, 0.4375 },
    m3_2 = { 0.65625, 0.76563, 0.21875, 0.4375 },
    m3_3 = { 0.76563, 0.875, 0.21875, 0.4375 },
    m4_0 = { 0, 0.10938, 0.4375, 0.65625 },
    m4_1 = { 0.10938, 0.21875, 0.4375, 0.65625 },
    m4_2 = { 0.21875, 0.32813, 0.4375, 0.65625 },
    m4_3 = { 0.32813, 0.4375, 0.4375, 0.65625 },
    m5_0 = { 0.4375, 0.54688, 0.4375, 0.65625 },
    m5_1 = { 0.54688, 0.65625, 0.4375, 0.65625 },
    m5_2 = { 0.65625, 0.76563, 0.4375, 0.65625 },
    m5_3 = { 0.76563, 0.875, 0.4375, 0.65625 },
    m6_0 = { 0, 0.10938, 0.65625, 0.875 },
    m6_1 = { 0.10938, 0.21875, 0.65625, 0.875 },
    m6_2 = { 0.21875, 0.32813, 0.65625, 0.875 },
    m6_3 = { 0.32813, 0.4375, 0.65625, 0.875 },
    m7_0 = { 0.4375, 0.54688, 0.65625, 0.875 },
    m7_1 = { 0.54688, 0.65625, 0.65625, 0.875 },
    m7_2 = { 0.65625, 0.76563, 0.65625, 0.875 },
    m7_3 = { 0.76563, 0.875, 0.65625, 0.875 },
  },
}
