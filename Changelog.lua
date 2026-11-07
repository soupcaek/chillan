-- Chillan? – changelog shown in the "What's new" tab (newest first)
local ADDON, ns = ...

ns.CHANGELOG = {
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
