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

ns.befehl("test", L.CMD_TEST, function() ns.Erinnerung:Vorschau() end)

ns.befehl("show", L.CMD_SHOW, function() ns.Show:Vorschau() end)

ns.befehl("play", L.CMD_PLAY, function() ns.Spiel:Menue(false) end)

ns.befehl("help", L.CMD_HELP, function()
  ns.melde(L.COMMANDS)
  for _, wort in ipairs(ns.befehlsListe) do
    DEFAULT_CHAT_FRAME:AddMessage("  /campfire " .. (wort == "window" and "" or wort) .. "  " .. ns.befehle[wort].hilfe)
  end
end)
