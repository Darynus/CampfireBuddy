-- Befehle für /campfire. Alles geht auch im Fenster, die Befehle sind Abkürzungen.
local ADDON, ns = ...
local L = ns.L

ns.befehl("window", L.CMD_WINDOW, function() ns.Fenster:Umschalten() end)

ns.befehl("bar", L.CMD_BAR, function()
  ns.db.leisteZeigen = not ns.db.leisteZeigen
  ns.Leiste:Sichtbarkeit()
  if not ns.db.leisteZeigen then ns.melde(L.MSG_BAR_HIDDEN) end
  ns.aktualisieren()
end)

ns.befehl("lock", L.CMD_LOCK, function()
  ns.db.gesperrt = not ns.db.gesperrt
  ns.melde(ns.db.gesperrt and L.MSG_LOCKED or L.MSG_UNLOCKED)
  ns.aktualisieren()
end)

ns.befehl("minimap", L.CMD_MINIMAP, function()
  ns.db.minimapZeigen = true
  ns.Minimap:Zurueck()
  ns.melde(L.MSG_MINIMAP)
  ns.aktualisieren()
end)

ns.befehl("test", L.CMD_TEST, function() ns.Erinnerung:Vorschau() end)

ns.befehl("show", L.CMD_SHOW, function() ns.Show:Vorschau() end)

ns.befehl("play", L.CMD_PLAY, function() ns.Spiel:Menue(false) end)

-- Was Campfire Buddy an diesem Lager liest, für Fehlerberichte
ns.befehl("debug", L.CMD_DEBUG, function()
  local LG = ns.Lager
  local gesamt, belegt = LG:Plaetze()
  ns.melde(string.format("Camp: %s, fire %s, %s slots, %d objects", LG.aktiv and "yes" or "no",
    LG.feuer and (ns.Objekte.Anzeige(LG.feuer.o)) or "?", tostring(gesamt or "?"), belegt))
  for fam, e in pairs(LG.objekte) do
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s: %s (%s%s)", fam, (ns.Objekte.Anzeige(e.o)), e.quelle or "?", e.wer and (", " .. e.wer) or ""))
  end
  local cb = (ns.Buffs.ids or {})[ns.CAMP_BENEFITS]
  local boni, zeilen = LG:Benefits()
  ns.melde(string.format("Camp Benefits: %s, aura instance %s, %d tooltip lines", cb and "yes" or "no",
    tostring(cb and cb.instanz), #zeilen))
  for _, z in ipairs(zeilen) do DEFAULT_CHAT_FRAME:AddMessage("  | " .. z) end
  for fam, b in pairs(boni) do
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  -> %s: %s %s", fam, (ns.Objekte.Anzeige(b.o)), tostring(b.wert)))
  end
  -- Weltkarte: angehängt? Einträge, Ort des Chars, Restzeit je Eintrag
  local karte, x, y = LG.KartenPos("player")
  local eintraege = LG:KartenEintraege()
  ns.melde(string.format("Map: attached %s, pins %s, %d entries, you on map %s at %.3f %.3f", tostring(ns.Karte.wache ~= nil),
    tostring(ns.db.karteZeigen), #eintraege, tostring(karte), x or 0, y or 0))
  for _, e in ipairs(eintraege) do
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  #%s map %s at %.3f %.3f, %s, %s left", tostring(e.nr), tostring(e.karte),
      e.x or 0, e.y or 0, e.genau and "exact" or "rough", e.ende and ns.dauerText(e.ende - LG.Zeit()) or "always"))
  end
  -- Minikarten-Knopf: Winkel und Ebenen von Knopf und Minikarte
  local b = ns.Minimap.knopf
  local okS, strata = pcall(Minimap.GetFrameStrata, Minimap)
  ns.melde(string.format("Minimap button: angle %d, shown %s, layer %s %s (minimap %s %s)",
    math.floor((ns.db.minimapWinkel or 0) + 0.5), tostring(b and b:IsShown()), tostring(b and b:GetFrameStrata()),
    tostring(b and b:GetFrameLevel()), tostring(okS and strata), tostring((Minimap:GetFrameLevel()))))
end)

ns.befehl("help", L.CMD_HELP, function()
  ns.melde(L.COMMANDS)
  for _, wort in ipairs(ns.befehlsListe) do
    DEFAULT_CHAT_FRAME:AddMessage("  /campfire " .. (wort == "window" and "" or wort) .. "  " .. ns.befehle[wort].hilfe)
  end
end)
