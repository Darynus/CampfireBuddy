# Campfire Buddy changelog

## 0.2.0-beta (2026-10-16)

- **New minimap icon**: a small rendered campfire. Prefer the murloc or the game's Camp symbol? Pick it in Settings next to the minimap button.

- **A real, flickering campfire**: the fire in the murloc show and in the games is now a rendered campfire (logs, stone ring, glowing embers) whose flames move in an eight frame loop, instead of a flat drawing.

- **The window now looks like a real WoW window**: portrait frame with the murloc, title bar, inset panel, tabs along the bottom, red buttons, the game's checkboxes and radio buttons, a status bar like the game's own, and gold headings. The buff bar and the Camp Kit keep their look.

- **Camp tab: know your camp**: which campfire it is (Basic 3, Journeyman 5 or Expert 10 slots), which objects stand there, an overview of all ten camp bonuses (active with their values, at the fire, covered by a class buff, or missing), and what you can still add or upgrade. Campfire Buddy learns this from your Camp Benefits, objects placed by you, your group or players nearby, and the fire and objects you hover over. It never sends anything.
- **Camp tip**: after a minute at the fire, one chat line tells you what this camp can still use from your bags or crafts.
- **Camp Kit knows the camp**: objects the camp still needs come first and get the ember border. Objects already there, or replaced by a better one, stay plain.
- **Active camp bonuses** on the Status page and in the Camp tab, read from your Camp Benefits with their values (for example Stamina +3, Attack power +12).
- Objects at the camp also come from players nearby who place them, and from hovering over objects with a clear name. Objects named like everyday things in town (Anvil, Loom, Spinning Wheel, Tanning Rack) are never taken from hovering.
- `/campfire debug` shows in chat what Campfire Buddy reads at the camp, for bug reports.

- **All camp objects**: every profession now has its tier 2 and tier 3 objects (skill 140 and 300), plus Cookie's Feast and the Iron Oven. The Camp Kit bar shows one button per bonus: your best object in the bags, or the best one you can build right now.
- **Horde Faction Banner**: Horde characters now get their own banner recipe.
- **Class buff check**: an object that gives nothing on top of a class buff you already have (Blessing of Might, Arcane Intellect, Mark of the Wild and so on) says so in its tooltip. Works in every game language.
- **Recipe not learned**: once you open the profession window, objects you have not learned yet stop showing up as buildable.
- **Countdown at the fire**: the one minute Welcoming Campfire buff is now recognized by its spell ID.
- **Fix**: placing an object from your bags now uses its bag slot, which Forever accepts.
- **Fix**: Camp Kit buttons react to one mouse edge only, so one click is always one action.

## 0.1.0-beta (2026-10-14)

First public beta for WoW Forever.

- **Buff bar**: Camp Benefits with time left and a progress bar, plus your food buff and any other buff you choose to track.
- **Reminders**: 2, 5 or 10 minutes before a buff runs out (or off), a chat line at login or when you join a group without a camp or food buff, and a hint when you walk up to a campfire.
- **All set!**: a short message once Camp Benefits and your food buff are both active.
- **Food buff**: shows when Well Fed from cooked food is missing. Recognized by its symbol in every game language. If a meal is not noticed, mark it once on the Status page.
- **Camp spot**: at a campfire the bar glows warmly and says Camp spot! Sit down.
- **Camp Kit**: at a campfire, a Sit button and one button for each camp object your professions can build. A finished object from your bags is placed first, otherwise one click builds one (the first click opens the profession window if it is closed). Cooldowns show on the buttons.
- **Light a campfire**: away from a fire, when Camp Benefits are missing, the Camp Kit offers your campfire (Cooking). The Status page tells you what you need.
- **Camp kit tab**: every camp object, which profession builds it, what it gives, your materials, and a Craft button.
- **Murloc show**: during the minute at the fire, a baby murloc walks through a little night scene to the fire, keeps doing silly things on the way and ends with one of ten finales. Stand up too early and he is sad.
- **Eight campfire games**: Whack-a-Murloc, Marshmallow, Murloc Race, Spark Catcher, Campfire Fishing, Log Stack, Camp Memory and Camp Defense (five waves and King Mrgl). Each with its own best score. They close when combat starts.
- **Fun sounds**: murloc shouts and little effects in the show and the games, can be turned off.
- Works in every game language: everything is recognized by IDs, never by names. Nothing is read in combat.
- Window with Status, Buffs, Camp kit, Settings and Help. Minimap button, addon compartment entry and a page under Options > AddOns.
