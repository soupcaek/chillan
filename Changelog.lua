-- Chillan? – changelog shown in the "What's new" tab (newest first)
local ADDON, ns = ...

ns.CHANGELOG = {
  { v = "0.28.2", date = "12.11", items = {
    "Fix: Layer hop's search for LayerSwap users was blocked by the game – it now runs first thing in your click, like LayerSwap's own",
  } },
  { v = "0.28.1", date = "13.11", items = {
    "Companion 2.0.1: WoWUp can now update Chillan while the companion is running (it no longer keeps the addon folder busy)",
    "Layer hop: the search for LayerSwap users in your zone now reads the answer reliably and asks 8 players at once, and /chill layer status shows the last search",
  } },
  { v = "0.28.0", date = "13.11", items = {
    "Alliance kills: every honorable kill pops up for the gang with one of 100 spicy lines, and goes to the feed, Discord, recaps and stats",
    "Group kills become one message naming everyone who was in on it",
    "Kill someone who killed one of us before, and you get a revenge line instead",
    "No death or kill messages inside battlegrounds or arenas",
    "Gang members who log in later now get the Discord relay link (and the companion card) straight away",
    "Layer hop 2.0: Chillan reads which layer you're on (target or mouse over an NPC) and shows it next to your status and next to everyone's zone in the gang list",
    "One click on Layer hop: a gang member in your zone on another layer invites you by themselves, you accept, Chillan checks you moved and leaves the group 30 s later (the layer stays)",
    "No gang member on another layer? The same click asks players in the zone who run LayerSwap. Hosting for LayerSwap users is opt-in in Settings",
    "@mentions work for nicknames with spaces or symbols (like \"Eirik / LINK\"), and the first word alone works too",
  } },
  { v = "0.27.0", date = "12.11", items = {
    "Discord feed for the whole gang: the relay link is shared in game, so everyone's Chillan saves events for the feed with no setup",
    "The Chillan companion now comes with Chillan (Companion folder). Run it once: it installs itself, starts with Windows, updates itself, and only reads Chillan's saved data, never your screen",
    "Live posting (reading the WoW window) stays on only where it's switched on, and now also works when WoW is behind other windows",
    "A one-time card tells you where the companion is, with the path ready to copy",
  } },
  { v = "0.26.3", date = "12.11", items = {
    "Discord relay: the black-and-white strip is replaced by a 3-pixel dark line in the top-left corner, shown for 0.4 s. Gang status is only sent when someone logs in, logs out or levels (at most every 5 minutes). Needs companion 1.1.0",
  } },
  { v = "0.26.2", date = "12.11", items = {
    "Discord: when you log in, Chillan relays what the gang did while you were offline, and the bot sums it up in one catch-up card",
  } },
  { v = "0.26.1", date = "12.11", items = {
    "Discord relay: the code strip uses bigger cells so the companion can read it on more screens, and /chill discord test keeps it up for 8 seconds",
  } },
  { v = "0.26.0", date = "12.11", items = {
    "New: Discord feed. Deaths (with the funny lines), dings, level recaps, blue-or-better loot, achievements and dungeon runs can be posted to your Discord by the Chillan companion and bot. Only the person running the companion needs /chill discord on",
    "/chill discord on | off | test | flush",
  } },
  { v = "0.25.7", date = "12.11", items = {
    "Death lines: the 116 clean ones are gone, replaced by new spicy ones. All 200 now have some bite, and every mob family (murlocs, raptors, gnolls, Defias…) keeps its own lines",
  } },
  { v = "0.25.6", date = "12.11", items = {
    "Fix: loot in the feed and event window no longer gets stuck as \"(item 6504)\". It shows the real item link as soon as the game has loaded it",
  } },
  { v = "0.25.5", date = "11.11", items = {
    "Fix: item links in gang chat show as normal [Name] links in the item's colour, instead of \"(name)\" or \"(item 251359)\". Items the game hasn't loaded yet show \"loading item…\" until they're ready",
  } },
  { v = "0.25.4", date = "11.11", items = {
    "Death lines now name what killed you from the game's own death recap, tested in Dustwallow (no target needed)",
    "Fix: dying no longer looks like drowning or exhaustion to the backup checks",
  } },
  { v = "0.25.3", date = "11.11", items = {
    "Death lines: killed by an Alliance player's pet now counts as a player kill instead of a wild wolf or cat",
  } },
  { v = "0.25.2", date = "11.11", items = {
    "Death lines work out who killed you in more ways: the game's own death recap, the breath and fatigue timers (drowning, exhaustion), a fall tracker, and your target",
    "New: /chill deathtest. After your next death, a window shows everything Chillan could and couldn't read, with text you can copy. /chill deathtest off stops it",
  } },
  { v = "0.25.1", date = "11.11", items = {
    "Fix: Chillan no longer tries to read the combat log on WoW Forever (the game blocks it and could show an \"addon blocked\" warning). Death lines use your target to work out who killed you",
  } },
  { v = "0.25.0", date = "11.11", items = {
    "New: \"Gratz on the ding!\" every time you level, with how long the level took and a button to see the level recap. Waits until you're out of combat",
    "New: level recap: time on the level (vs. the one before), XP per hour, deaths (Alliance vs. mobs), mobs killed, money gained, quests, best loot, who you played with, your gang ranking for that level, and achievements/dungeons. One click shares it in gang chat",
    "New: funny death lines (200 of them, plenty of them spicy). They're picked by who killed you (Alliance, murlocs, turtles, raptors, falling, drowning and more) and shown in the death popup, the event window and the feed. You won't see the same line again until 10 others have been used",
    "An Alliance player who kills you is added to the enemy log automatically",
    "Settings: \"Level recap when you ding\" can be turned off",
  } },
  { v = "0.24.0", date = "10.11", items = {
    "Fix: the \"First in the gang\" card no longer spills into the next card – lines never wrap and only the ones that fit are shown, newest first",
    "Legend book: the climber is now clearly \"most levels gained this week\" (no more \"nobody could catch…\"), and the highest level in the gang gets its own line",
    "Legend book: \"firsts\" come from the gang's record book, so the same first can no longer be credited to two people; ties always go to the same person",
    "Legend book: finished weeks keep their numbers (quests, time, gold, levels) even if nobody had the book open that week",
    "Level race now shows the two highest levels in the gang; the closest pair further down is a separate \"Neck and neck\" card",
    "Weekly titles Loot Goblin, Chatterbox and Cheer Squad now count the whole week (they used to lose the oldest events when the feed was trimmed)",
    "Weekly kings (achievements) need a minimum like the titles, and ties are decided the same way for everyone",
    "\"No. N in the gang\" on a ding is only shown for fresh dings (old ones from a sync counted everyone who had passed that level since)",
    "A week that crosses New Year is now one week, not two",
  } },
  { v = "0.23.3", date = "10.11", items = {
    "Fix: wide emotes were squeezed into thin slivers or cut off in the chat – width and height were swapped, so they now show in their real shape",
  } },
  { v = "0.23.2", date = "10.11", items = {
    "Emotes: hover an emote in gang chat, the event window or Stats to see its name (:Pog:) and a bigger picture, like the Twitch Emotes addon",
  } },
  { v = "0.23.1", date = "10.11", items = {
    "Stats: Wall of shame on top, then three rotating cards (the weekly challenge is now one of them)",
    "Legend book: the chapter text stays inside the page (scroll with the mouse wheel), many firsts become one line, no duplicate \"Most quests\"",
    "Fix: the layer-hop popup no longer shows up on login with \"Someone\" (it mixed up a level-history message) – it now always shows the name",
  } },
  { v = "0.23.0", date = "10.11", items = {
    "\"Since you last played\" card 10 s after login: dings, firsts, epics, gold achievements, dungeon runs and deaths while you were away, plus who's online and in your zone (Settings to turn off)",
    "Gear compare: everyone's equipped gear is shared (nothing from bags or bank). Hover a friend for \"Gear ilvl 27 · better in 3 slots\"; Compare has a new Gear view, slot by slot with item tooltips",
    "Legend book (Stats → Legend book): a chapter for every week, written from what the gang did – flip back through earlier weeks",
  } },
  { v = "0.22.0", date = "09.11", items = {
    "Fix: dying in a dungeon (corpse run outside) no longer posts the run as finished – a run ends after 10 min outside or when you enter another dungeon",
    "Dungeon runs read clearer: \"Olav ran Scarlet Monastery · 42m · 4 bosses · 2 deaths\"",
    "Reaction toasts use aliases (Adee, Henrik) instead of character names",
    "SOS: you no longer get your own SOS popup; the popup has a new random cheeky reaction button (Get rekt, Skill issue, lol gl, Popcorn time …)",
    "Fix: /reload or a disconnect inside a dungeon no longer counts as a new run (gave Double dose and extra dungeon runs) – the dungeon run timer also survives a reload",
    "Layer hop: click your status in the Chillan? bar (or /chill layer) to ask the gang for an invite – friends who are online and not in a group, dungeon or combat get a popup with Invite / Not now; the first one invites, the popup closes for the rest, and you accept automatically",
    "Emotes in Chillan? from the Twitch Emotes v2 addon (install it from WowUp): gang chat, event window, mirrored chat, reactions, popups and toasts",
    "Emote picker: star button in the chat input – favourites (right-click), recent and search",
    "Autocomplete: type :kek for suggestions with previews, or a name + Tab",
    "New emote reactions: PogChamp, peepoClap, OMEGALUL, Sadge, PepeHands, monkaS and more",
    "/chill emotes checks that the emotes are found",
    "Stats: two rotating spotlight cards – First in the gang (now incl. mount, epic, dungeons), Level race, Next ding, Loot of the week, Deadliest zone, Enemy of the week, Hot streak, The gang this week, Dungeon records. New fact every 20 s, hover pauses, click for the next",
  } },
  { v = "0.21.0", date = "08.11", items = {
    "Chillan? sounds: a soft pop for new gang chat, a chime when you're @mentioned, a sad trombone when someone dies, and a pling when friends log in and out",
    "Settings → Notifications: turn the chat sound and the log in/out sound on or off",
    "Restart the game fully once (not just /reload) so it finds the new sound files – until then you hear the old Blizzard sounds",
  } },
  { v = "0.20.0", date = "08.11", items = {
    "Faster sync: since launch the game silently drops addon messages in chat channels, so Chillan? no longer wastes sends there – everything goes straight by whisper (it checks every 5 min in case Blizzard opens channels again)",
    "Chat, dings and SOS always have sends ready, so a message reaches several friends at once instead of queuing behind background updates",
    "Less background traffic: your status only goes out when something changed (zone, level, AFK …) or once a minute, map position at most every 40 s, stats every 3 min",
    "Quicker online/offline: when someone joins or leaves the gang channel you say hi right away, and a friend who logged off shows as offline almost instantly",
    "Tip: add each other as WoW friends – friends get messages across realms and layers more reliably",
  } },
  { v = "0.19.1", date = "08.11", items = {
    "@mentions in chat now show the person card on hover too (shift-click pins it), also when gang chat is mirrored into normal WoW chat",
  } },
  { v = "0.19.0", date = "08.11", items = {
    "Hover a gang member's name in gang chat, the event window, the feed, Friends, Stats or normal WoW chat to see a small card: name, alias, class, level with XP bar, where they are (or last seen) and their latest ding",
    "Shift-click a name to pin the card: Whisper, Invite, Profile and Waypoint buttons; drag it around, Esc or the X closes it",
    "The small card replaces the bigger profile card on Friends and Stats rows (everything else is still on the player page)",
  } },
  { v = "0.18.0", date = "08.11", items = {
    "Friends: online on top, then an Offline section (last seen + last zone); waypoint button and coordinates on each friend",
    "The Map tab is merged into Friends (map button in the header); offline friends show dimmed on the world map at their last spot",
    "Quests: one list – quests you share first, then group quests",
    "Chat tab: full width with day separators (Today / Yesterday); the gang feed moved to Stats → History → Feed",
    "Header shows \"update available\" when someone in the gang has a newer version",
    "Stats: aliases instead of cut-off names, short column headers with tooltips (incl. what Points are)",
    "@names in chat show in class colour",
    "Fixes: item links left \"cnIQ2:\" and \"r\" in chat, leftover Norwegian text, attached feed no longer repeats the Chillan? title, idea status as a coloured pill",
  } },
  { v = "0.17.0", date = "08.11", items = {
    "@mentions with suggestions: type @ and a few letters – matches aliases, characters and alts; Tab/Enter picks, arrows move",
    "Item links in gang chat: shift-click an item while the chat input is active (max 3 per message)",
    "Items in chat show in quality colour with tooltip; shift-click one to link it on in normal WoW chat",
  } },
  { v = "0.16.0", date = "08.11", items = {
    "Attached event window can be resized: drag its corner sideways to change the width of the whole bar group, up/down for the chat height",
    "Width 330–700 px; cards stay at least 110 px wide; Lock positions also locks this",
    "Detaching brings the window back to its own old size and place; attaching again restores the attached size",
  } },
  { v = "0.15.5", date = "08.11", items = {
    "Fix: Lua error when detaching the event window from the bar",
  } },
  { v = "0.15.4", date = "08.11", items = {
    "Session time removed from the Chillan? bar, and the bar group is a little narrower (~370 px)",
  } },
  { v = "0.15.3", date = "08.11", items = {
    "Reactions line: a small corner under the event, then the reactions in brackets ([ Gay ]  [ Grats! 2 ])",
  } },
  { v = "0.15.2", date = "08.11", items = {
    "Reactions sit on their own line under the death/ding/achievement in the event window",
  } },
  { v = "0.15.1", date = "08.11", items = {
    "Wider cards (3 per row now ~400 px), and an attached event window is at least 400 px wide",
    "Attached event window hides its own online count (the bar shows it) so the filters don't collide",
  } },
  { v = "0.15.0", date = "08.11", items = {
    "Pinned cards are joined to the Chillan? bar – one panel with a thin line between",
    "Attach the event window to the bar (arrow button in its header, or Settings) – it hangs under the cards with the same width",
  } },
  { v = "0.14.9", date = "08.11", items = {
    "Menus are as wide as their longest line – no more text sticking out of the pin menu",
  } },
  { v = "0.14.8", date = "08.11", items = {
    "Your status in the Chillan? bar – click it to set LFG, Needs help or Do not disturb",
    "The newest gang event shows in the bar for a minute (session time when nothing is happening)",
  } },
  { v = "0.14.7", date = "08.11", items = {
    "Pinned cards are one block with thin divider lines, tucked right under the bar",
    "The Chillan? bar shows your session time when it has room",
  } },
  { v = "0.14.5", date = "08.11", items = {
    "The Chillan? bar grows with your pinned cards (max 3 per row, then they continue downwards)",
    "New card: Time on this level (live /played for the level, with the previous level's time)",
  } },
  { v = "0.14.4", date = "07.11", items = {
    "Event window has a \"–\" button (or double-click the header) that folds it down to just the header, with a count of new lines",
    "Right-click the Chillan? bar or minimap button to bring the event window back after closing it with X",
  } },
  { v = "0.14.3", date = "07.11", items = {
    "What's new reads top-down with a line between each version",
    "\"NEW\" only marks versions you haven't seen before",
  } },
  { v = "0.14.2", date = "07.11", items = {
    "Reactions are random: 50 options each for dings, deaths and achievements, 4 new ones every popup",
    "Death toast now shows what people reacted with instead of always \"laughed at you\"",
  } },
  { v = "0.14.1", date = "07.11", items = {
    "Titles are hoverable: what they mean, who holds them and the top 5 this week (click opens the Titles page)",
    "Title announcements only when someone actually overtakes – not when their numbers arrive at login",
    "Several titles to the same person become one line",
    "Titles need a minimum to be held (e.g. 30 min online, 3 quests), so Monday mornings aren't a title storm",
    "Fixes: old XP from last week counted as this week, unknown loot counted as epic, ties gave different holders",
  } },
  { v = "0.14.0", date = "07.11", items = {
    "Idea box has its own tab with an unread badge",
    "New \"What's new\" tab (this one) with a badge when there's a new version",
    "Unread badges on Chat (when the event window doesn't show chat) and Ideas",
    "Red dot on the minibar logo when something is unread",
    "Friends list: names and zones no longer get cut off with \"...\" when there is room",
  } },
  { v = "0.13.0", date = "07.11", items = {
    "Idea box: suggest features, vote up/down, admin sets status (/chill admin)",
    "Copy list – top ideas as text to paste on",
  } },
  { v = "0.12.1", date = "07.11", items = { "Reactions shown in [ brackets ] in the event window" } },
  { v = "0.12.0", date = "07.11", items = {
    "The whole addon is now in English",
    "6 themes that recolour everything: Graphite, Midnight, Coal, Slate, Horde, Void",
    "Accent follows the theme, your class colour (new default) or a fixed colour",
    "Opacity slider for popups, event window, tiles and minibar",
    "Stats tab: Overview with level bars, Progress, Titles and History (milestones, dungeons, fun facts)",
    "Board and Chronicle tabs removed",
  } },
  { v = "0.11.0", date = "06.11", items = {
    "No more false \"logged in\" alerts after your own login or layer changes",
    "Logging out tells the gang right away",
    "Durability: warnings at 30 % and 10 %, shared with the gang, tile on the bar",
  } },
  { v = "0.10.0", date = "06.11", items = {
    "New network model for Forever: Battle.net friends, introductions and a smarter send queue",
    "Everyone sees the same people online across servers and layers",
  } },
  { v = "0.9.0", date = "06.11", items = {
    "Weekly titles, compare players, dungeon log, ready check, group radar and map notes",
    "Hover achievements and items in the event window",
  } },
  { v = "0.8.0", date = "06.11", items = {
    "Quest buddy, @mentions, popups wait until after combat, accent colours, lock positions",
  } },
  { v = "0.7.0", date = "06.11", items = { "Pin stat tiles under the Chillan? bar" } },
  { v = "0.6.0", date = "06.11", items = { "Event window with gang chat, reactions and a chat box" } },
}
