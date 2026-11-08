-- Chillan? – changelog shown in the "What's new" tab (newest first)
local ADDON, ns = ...

ns.CHANGELOG = {
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
