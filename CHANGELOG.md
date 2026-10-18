# Campfire Buddy changelog

## 1.1.2 (2026-10-18)

- **Fix**: when someone places a bigger campfire at your camp (a Journeyman Campfire after a Basic one), Campfire Buddy now notices it, and also when a normal one burns there again later. The fire you point at counts, a fire placed right next to you becomes the fire of this camp, and when a fire goes out while you stand there, the next one starts fresh. Before, the camp stayed at 3 slots and every object you pointed at pushed another one out, so the camp check said "Not worth it".
- **Fix**: when the fire gets smaller, the camp keeps only as many objects as fit ("4 of 3 known" is gone), and objects nobody has seen for 15 minutes count as gone.
- **Fix**: campfires stay on your world map after you walk away, until their time is up. Walking away from the fire was taken for the fire going out, and the pin was gone.
- **Fix**: the camp check header makes room for long fire names ("Journeyman Campfire, 5 of 5 known") instead of writing over "Camp check".
- `/campfire debug` also lists your campfire pins.

## 1.1.1 (2026-10-18)

- **Camp check with icons**: the objects at the fire sit in a row of slots right under the title, so you see at a glance what stands there. Point at one for its tooltip with your value. Objects nobody has seen lately are grey, and slots nobody has checked say they may simply be empty.
- **Campfire button**: carry a campfire kit and a small button of its own shows up away from the fire, apart from the Camp Kit. One click places the kit. Without a kit it still offers to light your own campfire when Camp Benefits are missing. Move it like the bar, or switch it off under Options.
- **Game volume**: a slider under the campfire games turns their music and sounds down to 66%, 33% or off. Your game's own volume stays as it is.
- **Fix**: camp objects that share their name with things in towns (Tanning Rack, Anvil, Spinning Wheel, Loom) are recognized again. With camp object lines in their tooltip right when you point at them, otherwise as soon as their bonus arrives at this fire: a Tanning Rack counts once you get "Boosted Rest" there.
- **Fix**: "Is this your food?" no longer asks about class buffs like Power Word: Fortitude, or about buffs from other players.
- **Fix**: on the Buffs page, "food" no longer covers the spell ID.

## 1.1.0 (2026-10-18)

- **New game: Sneaky Mrgl**, the tenth campfire game. Agent Mrgl, in his sneaking suit with bandana, silenced pistol and fish bomb, sneaks into a Defias camp at night to steal back the fish. Your murloc follows the mouse. Grab up to three fish and bring them to the stream: the more you carry at once, the more they are worth, golden fish count triple and a trip without any alarm gives one and a half times the points. The guards are real Defias with vision cones. When one sees you, a "?" fills up above his head and he turns towards you, only when it is full he shouts and chases you until you lose him. Every two fish you bring home, another Defias joins and they all get faster. Hide under the cardboard box with a right-click, a box that stands still is just a box. Own music for sneaking and for the alarm, own sound effects.
- **Hungry!** When your food buff with the experience bonus runs out, a little alarm plays: a dramatic hit, a bright "!" and a growling stomach. Made for Campfire Buddy, switch it off with the reminder sound.
- **Food buff**: every Well Fed is recognized without a click, even with its own icon. Only a Well Fed with the experience bonus counts, snacks like Bobbing Apple show "Well Fed, but no XP bonus".
- **Camp check**: a small window at the left edge while you are at a campfire. It tells you if sitting down is worth it for your class and spec, what you get, what you lose (sitting down replaces all your Camp Benefits) and what you keep, with the values for your level. Camp objects disappear after a while: objects nobody has seen in the last 90 seconds are listed as "Not seen lately", and if your decision depends on them, the check asks you to hover over them first. Hidden in combat, can be moved and switched off.
- **Tooltips like the game's own**: every camp object shows its bonus for each level range, yours in green, what it is exclusive with and its profession. Campfire Buddy learns the values when you point at a camp object in the world.
- **World map**: campfire pins show the time left to the second ("13 Min 53 Sec remaining"), who placed the fire and what each object gives you at your level.
- **Fix**: the murloc in the show stands on the path again instead of floating above its shadow.
- **Fix**: the minimap button is built exactly like the ones of our other add-ons again and stays clickable.
- **Fix**: the campfire games play their music even when the game music is switched off, then over the sound effects channel.
- The minimap button has one fixed icon again: the murloc with the campfire badge.

## 1.0.0 (2026-10-16)

The first full release. The music, the minigames and all the art in Campfire Buddy are made for it by Darynus. Have fun at the campfire!

### Nine campfire games, rebuilt
- **Games tab** in the window, plus Shift-click on the minimap button: every game with your best score, one click to play. The game window is always at least Huge, and a legend under every game shows the points.
- **Whack-a-Murloc**: real 3D murlocs climb out of holes dug into a forest meadow, roar, wave or laugh, and flinch when you bonk them. Golden murlocs are worth 3, bombs cost 3, and never bonk the sheep.
- **Camp Defense**: a real map with a winding path from the lake to your tent and nine stone pads. Five towers (fire, frost, storm with chain lightning, mortar and spear) with upgrades, fast runners, armored brutes, healing oracles and King Mrgl in wave ten. Fireballs leave trails, bombs arc and explode, lightning jumps from murloc to murloc. Call waves early for bonus embers, double speed with the arrows.
- **Campfire Fishing**: hold to cast, wait through the nibbles for the real bite, then reel with feeling so the line does not snap. Nine fish, soggy boots and rusty cans, a fish book with your biggest catches and Murky cheering from the shore. Eight worms per game.
- **Murloc Race**: three real murlocs sprint along a moonlit beach. Bet coins at the odds, cheer your runner on three times per race, photo finish included. Its own galloping music.
- **Marshmallow**: roast on a forked branch right over a close-up campfire, turn it, blow it out when it catches fire and eat it golden on both sides.
- **Spark Catcher**: catch the rising sparks with a glass jar that follows your mouse, combos up to x4, empty a full jar for a bonus and dodge the ash.
- **Murloc Dive** (new): swim a real murloc through a moonlit lake between kelp, rocks, nets and anchors, and grab pearls and golden shells.
- **Log Stack**: logs drop and bounce, the sawn off piece tumbles away, chips fly and a perfect drop flashes gold.
- **Camp Memory**: Easy or Hard, round after round with a time bonus.
- **Our own music**: four tunes written for Campfire Buddy, calm for fishing and memory, fast for the action games, a gallop for the race. Every game ends with Play again and Games.

### Murloc show
- A new night scene with a visible path. The murloc walks on the ground all the way, strolls, picks things up and takes a rest, no more swimming through the air.
- Emote button: Wave, Thank you, Cheer, Dance, Laugh, Applaud, Bow or Roar, and the murloc answers. Size Normal, Large or Huge.
- Ten finales, fireworks and confetti only where they belong.

### Your camp
- **See what you get before you sit**: the Camp tab shows in big letters what Camp Benefits will give you after a minute at this fire, for example +12 Attack power and +14 Strength. Values are learned from your Camp Benefits and shown for every object in the Camp kit tab.
- **Is it worth sitting down?** Campfire Buddy knows your class and spec, tells you how many bonuses at this fire help you and dims the ones that do not.
- **Objects from strangers**: objects that players outside your group place at your fire are noticed too, even without name plates.
- **Campfires on the world map**: fires you visited or lit, and your group's, with objects and time left.
- **Full camp**: a fourth object at a full Basic Campfire replaces the oldest one, like in the game.

### Fixes
- A buff you cast yourself, like Demon Skin, or got from another player is never offered as your food buff.
- Texts and legends always stay inside the game window.
- The minimap button keeps its place when the minimap changes size and moves to a free spot if another button covers it. `/campfire minimap` brings it back.
- All large images are now in the game's own compressed texture format: Campfire Buddy is about 8 MB instead of 26 MB.

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
