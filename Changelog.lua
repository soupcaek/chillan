-- Chillan? – changelog shown in the "What's new" tab (newest first)
local ADDON, ns = ...

ns.CHANGELOG = {
  { v = "1.4.64", date = "25.11", items = {
    "The Market look everywhere: every button has a real border, cards have crisper edges, checkboxes are on/off switches, and choices are choice bars. Built from your theme's own colours, with your accent (theme or class) as the highlight everywhere, the Market too; gold is kept for money",
    "Main window: the section you're in has an accent underline, and its pages are one choice bar on a darker band",
    "Settings rebuilt: a side list of groups (Your gang, Appearance, Windows, Notifications, Quiet, Map & radar, Layer hop, Market) with a search box; each group in panels, switches with an ⓘ for the explanation, Popups how many / where as choice bars",
    "Friends: the filters as one choice bar, the members in a Gang panel with striped rows",
    "Pulse window: a thin accent edge on the first box. Popups: the accent edge on free-floating toasts too" } },
  { v = "1.4.63", date = "25.11", items = {
    "Darkspear Islands: the flag row follows the flag again (it got stuck on \"in the middle\" when the other side carried it). The flag counts as back in the middle only when its map point comes back after being gone",
    "Battlegrounds: the panel keeps room for the win estimate (and Warsong Gulch's clock and flag timers) from the start, so the base boxes no longer slide onto the flag row when the line appears mid-fight" } },
  { v = "1.4.62", date = "25.11", items = {
    "Dungeon recap in Pulse comes much sooner: the run ends as soon as you're outside and leave the group (or it breaks up), the group is mostly new people, the dungeon is reset, or you queue for another. Otherwise after 5 minutes outside (was 10); time spent dead doesn't count, so a corpse run never splits a run in two. A full clear still posts right after the last boss" } },
  { v = "1.4.61", date = "25.11", items = {
    "Market: the scan button is in the window's title bar (Full scan, or Quick scan · 12 min in between), with its progress in the footer",
    "Wishlist is now Item Tracker: cheapest now, the 14-day average, the change over 7 days, how many are up, and a Buy button for the cheapest one. Set a price alert (when adding, or right-click a row): when a scan, a search or the gang finds it under, you get a chat line and a sound, and the row turns green",
    "Victory card: no \"best kill streak\" line; a win streak rides on the honor line (\"· 3 in a row\")" } },
  { v = "1.4.60", date = "25.11", items = {
    "Flag rows: \"click to target\" shows only when the click really targets the carrier on screen. The game only lets addons point the button at a new carrier outside a fight, so a flag taken mid-fight shows no hint until the fight ends; then it's armed again by itself" } },
  { v = "1.4.59", date = "25.11", items = {
    "Market window redesigned (canvas option A): every area is its own panel with a border and a title strip, buttons have real borders, rows are striped, and prices are never cut off (no copper from 10g up). Sell: Up Next on the left, Post and the listings on the right. Buy: search and results on the left, the item with its price graph, listings and buy bar on the right",
    "Shopping is now Wishlist, with a price graph (7, 14 or 30 days) of the row you pick: low, high, average and trend",
    "Price history: Chillan keeps one price per item per day from every scan, yours and the gang's (14 days, 30 for your wishlist). Any item's graph: /chill price <name>, or Alt-click an item",
    "Buy: \"vs gang price\" compares with the price before your own search (it read 0 % everywhere), and a new search clears the old item",
    "The ⓘ markers show their i again. The rep box's hover names the faction: \"Frostwolf Clan · +200 this session · 181 per hour\"" } },
  { v = "1.4.58", date = "25.11", items = {
    "Flag rows (Darkspear Islands and Warsong Gulch): the side in its colour as the headline – \"Alliance has the flag\", \"Alliance has our flag\" – then the carrier's name, or the game's own line (\"Nunte Aor has taken the flag!\") when the game keeps the name from addons, then where and how long: \"near Cove · held 0:42\". No more \"near near\"",
    "Darkspear Islands: bases read from the map's own labels (Neutral, Contested, Horde/Alliance Controlled) and Forever's own icon numbers, so a neutral Tower or Cove no longer shows as Horde's. The centre flag is \"in the middle\" whenever its map point is back",
    "\"Alliance wins in ~2 min\" is in the winner's colour, like the score",
    "Honor today counts your battleground honor (it showed 0 right after a game)",
    "The rep box shows \"+200 rep this session\" when the big card already shows that faction and its rate, and the session line stops repeating it. Short faction names everywhere: Frostwolf, Darkspear, Defilers, Warsong" } },
  { v = "1.4.57", date = "25.11", items = {
    "Chillan? Market window: opens beside the auction house with five tabs. Turn Naowh's Market off so the two don't fight over the same searches",
    "Sell: your bags as a queue, most valuable first. The price starts 1c under the cheapest listing that isn't yours, uses the gang price when nothing is listed, and never goes under what a vendor pays. A big green \"You get after the 5 % cut\", the deposit, Skip and Post. Under it the listings right now, Up Next (worth more on the auction than at a vendor) and For a vendor",
    "Buy: search by name, saved and recent searches, results compared with the gang price, then Buy (and Confirm for stackable goods). My auctions: listed, undercut and sold last 7 days, each auction checked against the cheapest that isn't yours, Cancel undercut one click at a time",
    "Shopping: your own list with how many you want and the most you'll pay; Check prices, then Buy exactly what's missing. Gang: who made the most gold (after the cut), sold the most, posted the most and whose auctions sell, plus the week's biggest sales",
    "Tooltip: Best: auction vs vendor uses the same after-cut sum as Up Next, also for older prices, so the two always agree" } },
  { v = "1.4.56", date = "25.11", items = {
    "Darkspear Islands: the centre flag row sits at the bottom of the panel again instead of on top of the base boxes, and says it all in one line: who carries it, \"dropped · back in 0:07\", \"back in 0:18\" or \"in the middle\"",
    "Darkspear Islands and Arathi Basin: before the gates open no base shows as held (a fresh game showed two Horde bases while we waited)" } },
  { v = "1.4.55", date = "25.11", items = {
    "Battlegrounds read right: Chillan now uses Forever's own map icons (the same numbers DBM-PvP and Capping use) and the battleground's own lines (\"The Alliance has assaulted the Ruins!\") in Arathi Basin and Darkspear Islands. Owners and capture timers are right for both sides, and the game's own time left is used where it gives one",
    "PvP mode: the top says \"PvP mode · social paused\", without friends' faces (their status can't be heard in a battleground). The window's height follows what the panel shows; your own size comes back when you leave",
    "Card: \"+133 honor this game\" next to rep this game, HKs and deaths always (no kill streak), rep as \"Friendly · 7 680 / 12 000 · 64 %\", and Today just wins for this battleground",
    "Alterac Valley: only what's on a countdown – next to fall with a big timer, the rest with bars in the colour of the side taking it, no extra text. Arathi Basin and Darkspear Islands: score and bases per side, \"Horde wins in ~6 min\" with a final score estimate, base boxes deep when held and bright with a white countdown bar while being taken. Darkspear Islands' score now shows",
    "Warsong Gulch: flags as 2/3, the game clock, Enemy FC and Our FC rows (name, class, health bar, where the flag is, click to target), dropped flag and flag respawn countdowns. Darkspear Islands: the centre flag's carrier and the 21 s reset after a capture",
    "/chill perf lists how much memory Chillan and your other addons use" } },
  { v = "1.4.54", date = "25.11", items = {
    "Battleground bases: Chillan now learns Forever's own map icons. When a base's icon changes at the same moment as a side's base count, it knows what that icon means and remembers it for later games. Until then a base being taken shows a grey timer instead of nothing",
    "Flag rows rebuilt from the flags' places on the map: Warsong Gulch \"Our flag: taken · near …\" / \"Their flag: we have it · near …\", Darkspear Islands \"Centre flag: carried · near …\". Name, health and click-to-target only when the game gives the carrier",
    "One colour rule in every battleground: bright red or blue while being taken, deeper once held, dark when destroyed or nobody's (Alterac Valley's countdown, bars and tower squares too)",
    "Chillan also records the score display's layout per battleground, to read the Darkspear Islands score next" } },
  { v = "1.4.53", date = "25.11", items = {
    "Battleground panel: base boxes follow the width of the window, and the centre flag point in Darkspear Islands no longer shows as a base",
    "New colours: a base being captured is bright red (Horde) or bright blue (Alliance) with a white timer; once captured it turns deeper red or deeper blue. No more yellow",
    "Chillan now records what the map shows for every base (icon, label, changes) so the next update can read Forever's bases exactly – type /reload once after a battleground to save it" } },
  { v = "1.4.52", date = "24.11", items = {
    "Fixed: a Lua error (blocked action) from the battleground panel during fights",
    "Alterac Valley: towers and graveyards only count as under attack when Chillan sees them change. Joining a game in progress or reloading no longer shows bunkers as burning when they aren't. Attacks Chillan did see survive a /reload, with the right time",
    "Hover the tower squares to see each tower: standing, burning (with time left) or destroyed" } },
  { v = "1.4.51", date = "24.11", items = {
    "Alterac Valley panel redone: \"Next to fall\" with a big countdown and bar, then everything else under attack with its own timer bar in the colour of the side taking it, and the towers each side has left (filled = standing, amber = burning, dark = gone). An attack that started before you joined says so instead of \"…\"",
    "First battleground tile is now reputation this game (AV had an empty score). Arathi Basin, Warsong Gulch and Darkspear Islands show the score at the top of the panel instead, with bases per side",
    "Layer hop: fits LayerSwap 1.14.54 – waits 5 s for hosts that hold their reply before asking again, and remembers hosts that skip one ask as hosts for the next hop" } },
  { v = "1.4.50", date = "24.11", items = {
    "New: battleground objectives. In a battleground the gang chat is paused anyway, so the event window shows the battleground instead – back to the feed when you leave",
    "Arathi Basin and Darkspear Islands: every base by owner (red Horde, blue Alliance); an assaulted base turns amber and counts down to capture. Bases held per side and a win estimate (\"Horde wins in ~6 min\")",
    "Alterac Valley: only towers and graveyards under attack, with the time until they fall, and the towers still standing per side",
    "Warsong Gulch and Darkspear Islands: two carrier slots, enemy and ours, with health. Click a slot to target the carrier, also in combat. Warsong Gulch also shows when the flags are back after a capture",
    "Turn it off under Settings › Windows and layout. /chill bgdebug prints what the game shows Chillan in a battleground (handy if something looks wrong)" } },
  { v = "1.4.49", date = "24.11", items = {
    "No more \"We haven't heard from anyone in the gang yet\" in battlegrounds and dungeons – the check waits until you've been out for a couple of minutes",
    "Minibar tooltip in a battleground says \"Paused in BG\" instead of \"Nobody else online\"",
    "Wins to Exalted tile: this game's rep gain moved to the card's tooltip (\"This game +420\"), so the tile only says how many wins are left" } },
  { v = "1.4.48", date = "24.11", items = {
    "Inside battlegrounds and dungeons the game blocks addon messages, so the header says \"Paused in BG\" (or dungeon) instead of \"0 online\". Hover it for why. Friends keep the status they had when you went in, and the gang syncs again when you leave",
    "Battleground card trimmed to the essentials: HKs on the big line (deaths only when you have any), the reputation bar, and one Today line for this battleground. Tiles: score, honor this game, wins to Exalted and time in the BG. Rep left, average per win, this week's honor and your rank are in the card's tooltip",
    "Battleground recap: honor now includes the end-of-match bonus (it said +10 instead of +115 because the card was made before the bonus arrived)",
    "Less text everywhere: explanations under headings moved into a small \"i\" you hover (Died to, The Cunt List, Who can make what?, Market, interface scale), and a few lines that said nothing new are gone" } },
  { v = "1.4.47", date = "24.11", items = {
    "PvP tab: pick anyone in the gang from the button next to the title to see their whole PvP page – record, streaks, honor, HKs, time and reputation per battleground, for today, the week or all time. Each friend's page is sent when they finish a battleground and when they log in, and kept on your PC, so you can open it while they're offline (it says how old it is). Opening the list asks whoever is online for fresh numbers",
    "Fixed errors in battlegrounds (\"invalid value (secret)\"): the scoreboard's numbers can be hidden by the game and are now treated as unknown" } },
  { v = "1.4.46", date = "24.11", items = {
    "Battleground wins: your team is read from the battleground itself (not only your faction), and the result is checked against the battleground's own \"The Horde wins!\" message and corrected if they disagree",
    "In a battleground the Today line shows this battleground's record first, then all battlegrounds, from the recorded games (e.g. \"2 / 3 here · 5 / 7 all BGs\"). Earlier versions could count a game twice after a /reload, so today's old totals were too high" } },
  { v = "1.4.45", date = "24.11", items = { "Layer hop: a host whose invite came from your own layer is left out for 5 minutes (was 20 s), and the declined invite's window can no longer pop up a moment later" } },
  { v = "1.4.44", date = "24.11", items = { "Battleground result line: honor now includes the end-of-match bonus. The line is posted when you leave the battleground (or 45 s after the end) instead of 3 s after it, and honor is the highest of the game's count, the honor messages and the scoreboard" } },
  { v = "1.4.43", date = "24.11", items = {
    "Battlegrounds today counted too many games: every time you entered – also after a /reload inside, or when the game briefly reported you outside – counted as a new game. A game now counts only when it ends with a result, and a /reload inside carries on the same game (its time, kills and deaths)",
    "Today's count is repaired once from the games recorded today" } },
  { v = "1.4.42", date = "24.11", items = {
    "Layer hop: requests to LayerSwap hosts carry LayerSwap's rules marker (r3), so hosts on LayerSwap 1.14.52 invite you again. Chillan keeps every rule it stands for: at most 10 moves an hour, no request in combat, and none while dead or a ghost",
    "An invite from a LayerSwap host is now yours to accept (click Accept), as in LayerSwap itself. Hops through the gang still join by themselves" } },
  { v = "1.4.41", date = "24.11", items = {
    "Layer hop: an invite from someone on your own layer is now recognised by the game's own flag and declined automatically, and the search goes on for a host on another layer",
    "Layer hop: a refusal from the game no longer locks Swap layer for 15 minutes when fewer than 10 moves are known – you can simply try again" } },
  { v = "1.4.40", date = "24.11", items = { "PvP tab: the reputation line no longer overlaps the battleground name and win rate (shorter faction names, and cut with … if it doesn't fit)" } },
  { v = "1.4.39", date = "24.11", items = {
    "Darkspear Islands (WoW Forever's new 15v15 battleground) on the PvP tab, with Darkspear Raiders / Theramore Expeditionary Force reputation, and in the battleground boxes, rep bar and recap like the other battlegrounds",
    "PvP cards are a bit more compact so all four fit" } },
  { v = "1.4.38", date = "24.11", items = {
    "New PvP tab: a card for Alterac Valley, Warsong Gulch and Arathi Basin with record and win rate, win streak, honor per hour and per game, HKs per game, best game, average and total time, and your reputation toward Exalted",
    "Switch between today, this week and all time. Next to each card, the gang: win rate, HKs per game and standing for everyone who has played it",
    "Games are recorded from this version on (each one when you leave the battleground)",
    "Your own achievement and death popups no longer have empty space where the reaction buttons would be" } },
  { v = "1.4.37", date = "24.11", items = {
    "Level 60: the Now card's bar follows the faction you pick with \"Show as Experience Bar\" in the reputation window (standing, progress and rep per hour). Without one it shows your PvP rank as before",
    "Battleground: the reputation line no longer repeats the wins to Exalted (they're in the box), so the details fit",
    "Honor per hour and honor today in battlegrounds use the honor messages when the game's own count stays at 0" } },
  { v = "1.4.36", date = "24.11", items = {
    "Battleground recap showed 0 HKs, 0 deaths and 0 honor: the scoreboard is now read with the WoW Forever API, and when it can't be read Chillan uses its own counts (HKs, deaths, and honor from the honor messages)",
    "Without a scoreboard the killing blows box shows your best kill streak instead",
    "Wins to Exalted right after a win now includes that game in your average, instead of the starting estimate" } },
  { v = "1.4.35", date = "24.11", items = { "Disenchant next: a button under your bags and on the Market tab (for characters with Enchanting) disenchants, one click per item, the item in your bags that gains most from disenchanting instead of selling. Hover it for the list. Can be turned off in Market › Disenchant button" } },
  { v = "1.4.34", date = "24.11", items = {
    "Battleground reputation: in Alterac Valley (and Warsong Gulch and Arathi Basin) one Pulse box shows how many wins you need to Exalted, with this game's reputation live (\"27 wins · to Exalted · +412\")",
    "In a battleground the Now card's bar shows your reputation toward the next standing instead of XP, with a line like \"Frostwolf: 27 wins to Exalted · 14 993 rep left · avg +562 over 16 wins\"",
    "The average is your own: each game's reputation is measured from entering to leaving, wins and losses separately. Until your first win it uses an estimate",
    "Watching a friend in (or just out of) a battleground shows their wins to Exalted in the rotating line, and the battleground recap includes it" } },
  { v = "1.4.33", date = "22.11", items = { "No recap prompt at logout any more: the session is saved and offered as \"Show last session recap\" when you log in. Dungeon, raid and battleground recaps are unchanged" } },
  { v = "1.4.32", date = "22.11", items = { "?price posts one line: Chillan first asks the gang for those items and waits a few seconds, so the answer already has the newest price anyone has. A \"Price update\" only appears if a fresher price turns up afterwards, and only once" } },
  { v = "1.4.31", date = "22.11", items = {
    "Market catch-up works both ways: if a friend logs in with a newer scan than yours, your Chillan now asks them for it (before, only the person logging in was caught up)",
    "Every 20 minutes Chillan quietly checks whether anyone online has a newer scan, so friends who were online all along also get each other's prices",
    "A ?price answer from an old price is corrected: whoever has a fresher price sends it and posts a \"Price update\" line" } },
  { v = "1.4.30", date = "22.11", items = {
    "Price check: items the game hadn't loaded yet showed as white, unclickable text. They are now real item links straight away, and turn to the item's colour as soon as the game has the item",
    "Session recap rebuilt: the time is the real session (a /reload no longer restarts it), and it shows only what you actually did – reputation, gold, honor, gathering, bosses, mobs or quests, whichever you did most – plus gold per hour against your week's average",
    "The logout recap is saved and offered at the next login. The session prompt now sits a third of the way down the screen" } },
  { v = "1.4.29", date = "22.11", items = {
    "Recap prompt now has the same size and look as the other popups: icon tile, title, a short teaser line (e.g. \"16/19 bosses · 58m · 3 deaths\") and Show/Close",
    "Fixed an error when pressing Show at logout: the game does not let addons stop the logout countdown, so the recap card now simply opens while it runs (and is offered again at the next login)" } },
  { v = "1.4.28", date = "22.11", items = {
    "Recaps: a small prompt grows out of the screen with \"Show recap\" and \"Close\". Show grows it into a card with four headline numbers that count up, the best moments, a bar against the gang's (or your own) best, and Share to gang",
    "At logout and login the prompt appears in the middle of the screen, replacing the big summary card. At logout, Show pauses the countdown and the card has a Log out button",
    "When a dungeon, raid or battleground ends, the prompt appears at the top of the screen: time inside, bosses, deaths, loot value, fastest boss, best drop, gang record, or HKs, killing blows, honor, flags and streaks",
    "Ignored for 20 seconds, the prompt slides away and a \"recap ready · [Show]\" line stays in the feed. Can be turned off in Settings › Quiet" } },
  { v = "1.4.27", date = "22.11", items = {
    "Auction house scan is smoother: listings are read in slices instead of all at once, so the game no longer freezes while a big auction house is read",
    "Between full scans (the game allows one per 15 minutes) the button now does a quick page-by-page scan of the lowest price of every item, instead of saying \"Scan in 12 min\"",
    "A full scan started by another addon (such as Naowh's Scan Prices) is captured and shared too, and prices of items you browse yourself are kept" } },
  { v = "1.4.26", date = "22.11", items = {
    "Market sharing is much faster: after a scan, all prices go to the gang (not only the ones that changed), packed tighter and on their own message lane – about 40 prices a second instead of 14, without slowing chat",
    "Catching up fixed: friends logging in (or using /chill market sync) now get every price from the newest full scan. Before, one recently hovered item could make Chillan think they were up to date",
    "Price lines no longer show a garbled name (\"bn:40\") for prices from Battle.net friends" } },
  { v = "1.4.25", date = "22.11", items = { "?price and the Market search now find prices scanned before 1.4.24: Chillan loads the item names first (a minute or two after login) and then answers, instead of saying there is no price" } },
  { v = "1.4.24", date = "21.11", items = {
    "Price search on the Market tab: type part of an item name to see every matching price the gang has scanned, with when and who scanned it",
    "Type ?price followed by an item name (or a shift-clicked item) in gang chat and Chillan posts the price for the whole gang, e.g. \"Price check: Long Elegant Feather 1g 20s (3h ago, Adrian)\"",
    "No price yet? The question is remembered for a day, and the answer is posted automatically when someone's auction house scan brings it in" } },
  { v = "1.4.23", date = "21.11", items = { "Run-speed gear: if you unequip an item such as Hyjal Postal Clasp yourself (or put another trinket in its slot), Chillan no longer equips it again. It stays off until you equip it yourself" } },
  { v = "1.4.22", date = "21.11", items = { "Mount gear: an item you equip yourself is never swapped back. Previously a leftover \"restore\" entry from an earlier ride could replace or unequip a trinket you put on manually" } },
  { v = "1.4.21", date = "21.11", items = {
    "Mount gear: run-speed gear you equip manually (such as Hyjal Postal Clasp) is no longer removed, even with run-speed gear turned off. While mounted, Carrot on a Stick uses the other trinket slot so the run-speed trinket stays equipped",
    "Option labels no longer extend outside their panels",
    "Rewrote the text in QoL helpers, Settings and several pages to be clearer and more consistent" } },
  { v = "1.4.20", date = "21.11", items = { "Feed: a second match of the same battleground (or a second run of the same dungeon) no longer wipes the first one's result line – each match and run keeps its own line" } },
  { v = "1.4.19", date = "21.11", items = { "Battleground result line: alone in a battleground it no longer says \"MVP <you>\" – it shows your HKs, honor and match time instead. The gang MVP only shows when 2 or more of the gang played. The victory card says \"Your match\" when you were alone" } },
  { v = "1.4.18", date = "21.11", items = {
    "Popups now slide out of the side of the Pulse window and back in, with a coloured edge where they join (they grow to the left if the window sits at the right edge of the screen)",
    "Settings › Quiet › Where: Attached (new default), Free (top of the screen, as before) or Off (feed only). While the Pulse window is hidden, attached popups show at the top of the screen" } },
  { v = "1.4.17", date = "21.11", items = {
    "Level 60: the open-world boxes swap XP/h and time-to-level for Honor today (every other few seconds: bosses and runs today), Reputation per hour (your top faction) and Gold today (net, with gold/h under it)",
    "Level 60: the Now card shows your PvP rank and the bar fills toward the next rank; \"This session\" counts HKs and honor, rep gained and bosses killed",
    "Watching a friend at 60: their bar shows progress to their next PvP rank (red), and the rotating line shows rank, HKs and honor today, runs today, gold/h and their best drop this week. No more \"to 61\"",
    "Layer box: says \"Swap layer\" with \"8 hops left\", \"Wait 12:30\" or \"Moved 3m ago\" (layer numbers are private now)",
    "Gold/h only counts gold that came in, so buying things no longer makes it negative",
    "Gathered only counts loot right after your own Mining, Herb Gathering or Skinning – not ore from a quest" } },
  { v = "1.4.16", date = "21.11", items = { "Gang player history: hover a player and the tooltip says what the gang knows – \"Olav grouped with them in Blackrock Depths · 2 days ago\", \"Killed the gang 3× · last Olav\", \"The gang killed them 5×\". Only people you grouped with for 3+ minutes or fought are kept, shared with the gang" } },
  { v = "1.4.15", date = "21.11", items = { "Gang records: the fastest kill of every boss and the fastest run of every dungeon, by anyone in the gang. The boss hover list shows \"best 1:12 Olav\", and the run line in the feed says \"gang record! (was 1:40)\" when someone beats one" } },
  { v = "1.4.14", date = "21.11", items = { "Mount gear knows more speed gear (from AutoCarrot Forever 4.0.22): Rider of the Plaguelands (ring + cloak, mounted in the Plaguelands), swim gear (Azure Silk Belt, Cloak of Hermitic Bliss) while swimming, and run-speed gear on foot (Spry Boots, Hyjal Postal Clasp, Agamaggan's Clutch, Blessing of Kalimdor). The Desert Rose works in more desert zones. Switches in QoL › Mount gear" } },
  { v = "1.4.13", date = "21.11", items = {
    "Layer hop: since the game patch of 20 Nov each player reads their own layer numbers, so Chillan no longer shows a friend's layer or \"same layer\" (it would be wrong) and asks any friend in your zone to host",
    "Layer hop: the game allows about 10 layer changes an hour and then silently refuses – Chillan counts your hops, shows \"3 left this hour\" and \"Wait 12:30\" instead of trying in vain",
    "Layer hop: the group is left 4 s after joining, as LayerSwap does now" } },
  { v = "1.4.12", date = "21.11", items = { "Boss lists now come from the Forever dungeon journal data: the right names, order and rares for every Forever dungeon plus The Barrow Deeps and Hyjal Summit. Kills are matched by the game's encounter ID, so a boss can't show up twice under two names" } },
  { v = "1.4.11", date = "20.11", items = { "Feed: a kill count updates where it stands instead of jumping below newer chat", "A friend with 5 kills within 3 minutes is treated as being in a battleground: their kills are left out of the feed for 15 minutes, even if their addon is old" } },
  { v = "1.4.10", date = "20.11", items = { "Feed: the \"killed 149 Alliance\" line came again and again – fixed (one line that counts up)", "A friend's kills within 15 minutes are stored as one item, so a battleground of kills no longer pushes the rest out of the feed" } },
  { v = "1.4.9", date = "20.11", items = { "Alliance kills: one person's kills within 15 minutes are one line that counts up everywhere – in the feed, in \"earlier today\" and on Home (one kill still gets its funny line)", "Battlegrounds: two more checks, and 5 kills within 3 minutes now counts as a battleground even where the game says you're in the open world – no kill lines for 15 minutes" } },
  { v = "1.4.8", date = "20.11", items = { "Alliance kills in battlegrounds are left out of the feed again (the battleground check now also works where the old one missed)", "Feed: reactions to a kill no longer get a line of their own (\"Simon · kill  Nice gank! Olav\"); a kill burst line shows the reactions to all its kills" } },
  { v = "1.4.7", date = "20.11", items = { "Feed: every death gets its own line with its funny text again (no more \"died 2 times\"). The first death pops up; more deaths within 10 minutes only go to the feed" } },
  { v = "1.4.6", date = "20.11", items = { "An Alliance kill can't pop up any more, whatever version the friend has", "/chill popups lists the popups you've had this session and what they were about" } },
  { v = "1.4.5", date = "20.11", items = { "Alliance kills no longer pop up – they're in the feed, where you can react if you want" } },
  { v = "1.4.4", date = "20.11", items = { "QoL: a gold coin on the quest reward that sells for the most at a vendor (count included), in the quest window and the quest log – hover it for the price. Switch: QoL › Questing" } },
  { v = "1.4.3", date = "20.11", items = { "Feed: a dungeon or raid run is one line that counts up (\"WC 4 / 8 bosses · last Skum 0:36\") instead of a line per boss; the end-of-run line takes its place", "Feed: everyone in the gang in the same run or battleground is on one line with all names; a battleground's flags, revenges and result are one line", "Feed: \"is 2 % from level X\" goes away when the ding comes", "The end-of-run line comes the moment the last boss dies, not when you leave" } },
  { v = "1.4.2", date = "20.11", items = { "Dungeons: the boss list on hover showed only a black box – fixed", "Boss lists for Blackmaw Hold, Krol'dok Stronghold, Alcaz Prison and Shaper's Terrace (bosses the guides call optional only count once killed)", "Hover the little boss track in the Now card for the boss list; the card's tooltip says what the parts are" } },
  { v = "1.4.1", date = "20.11", items = { "Feed icons are back in small framed boxes, tinted in the line's colour", "Loot uses a diamond icon in the item's quality colour" } },
  { v = "1.4.0", date = "20.11", items = {
    "Feed icons: loot shows the real item icon with its quality border, everything else a small coloured icon with no box",
    "Dungeons: the first box is \"3 / 8 bosses\" – hover it for every boss here, the ones you've killed struck through with the time the kill took. Covers the classic dungeons and raids and the new Forever dungeons; bosses the list doesn't know are learned from the gang's kills",
    "Dungeons: boss track and next boss, pace against the gang's best run, deaths (who died most) and wipes, loot value from the Market in the boxes",
    "Dungeons and raids: a feed line for every boss kill (\"Gang killed X · 1:58 · no deaths\") – no popup, but you can react to it",
    "Dungeons: a run card when the last boss dies – time, XP, loot value, best drop, floor inspector, fastest boss and a record badge",
    "Raids get their own mode: bosses, raid time, wipes, repair so far; the gang here, the gang's epics tonight, your fire resist/flask/lockouts, and a raid night card. Gang news waits until a boss is dead (the game blocks addon messages during the fight)",
    "Battlegrounds: the score in the first box, your kills/deaths from the scoreboard, each friend's kills/deaths in the same BG, this week's honor and rank, wins today and a win streak",
    "Battlegrounds: feed lines for flag captures and returns, revenge on someone from the Died-to list, and the result with a gang MVP; a victory card with MVP, flag hero and revenges",
    "Questing: a ding card in the Now card for 20 s; the gang gets \"X is 2 % from 58 – get your grats ready\"; herbs, ore and leather you gather this session with their Market value",
    "/chill selftest shows whether the boss, scoreboard and honor calls exist in Forever" } },
  { v = "1.3.13", date = "20.11", items = { "Feed: the time you see on hover has its own lane on the right and no longer sits on top of the text", "Feed: the react \"+\" shows on the line's icon while you hover" } },
  { v = "1.3.12", date = "20.11", items = { "Feed: the game's own icons at 22 px – loot shows the item itself with its quality colour, dungeons their own icon, plus skull, level-up, PvP and trophy icons", "Feed: no time column – hover a line to see its time; a thin divider with the time sits between groups of lines 10+ minutes apart", "Feed: short dungeon names (BRD, SM Library …) – hover for the full name" } },
  { v = "1.3.11", date = "20.11", items = { "Market: after a friend's scan, an old price you hover is asked for again until it arrives (\"Asking … for a newer price\" shows in the tooltip)", "Market: at login the friend with the newest prices answers – a friend with older prices no longer blocks them", "/chill market who: which online friends can share prices (version check)", "/chill market shows who scanned last and how many prices" } },
  { v = "1.3.10", date = "20.11", items = { "Market: the tooltip you're looking at updates by itself when a newer price for it arrives from the gang" } },
  { v = "1.3.9", date = "19.11", items = { "Market tooltip: items on the character sheet, an inspect window or any other place that isn't a bag no longer count as a stack – a ring could count as 12, which made Best: show 12× too much" } },
  { v = "1.3.8", date = "19.11", items = { "Market tooltip: the text no longer runs out over the right edge (coin icons now count when the tooltip sizes itself), and the lines are a bit shorter" } },
  { v = "1.3.7", date = "19.11", items = { "Market: the tooltip can list what disenchanting gives – one line per mat with how many, the chance and the mat's price. Switch: Market page → Tooltip → What disenchanting gives" } },
  { v = "1.3.6", date = "19.11", items = { "Reactions under a feed line wrap onto a new line when the window is narrow, instead of running off the edge" } },
  { v = "1.3.5", date = "19.11", items = {
    "Chillan? Market has its own page: Market in the top bar. It shows where your prices stand, an \"Ask the gang now\" button, a switch for each tooltip line and for sharing",
    "Disenchantry: the tooltip shows what green, blue and purple gear gives when disenchanted and what the mats are worth, and Best: now picks between auction, vendor and disenchant. The Market page lists the gear in your bags with the verdict for each",
    "Prices reach the gang much better: one message carries more prices, it goes on the gang channel only (not a copy per friend), and it waits while chat and status are sending – before, a big scan could take very long to arrive",
    "When a friend scans, prices you hover that are older than their scan are asked for and update in a second or two",
    "The scan button is a tab on top of the auction house window (top left), clear of the tabs other addons put along the bottom",
  } },
  { v = "1.3.4", date = "19.11", items = {
    "Market: hover an item with no price and Chillan asks the gang for it – whoever has it answers within a second or two (hover again to see it)",
    "Market: when you log in you now get all the gang's newer prices, not just the first 1 500, and a bit faster",
    "/chill market shows how many prices you have and who sent the last ones; /chill market sync asks the gang again",
  } },
  { v = "1.3.3", date = "19.11", items = {
    "Mount swap: never tries to put on a trinket that isn't bound to you yet. A Bind-on-Equip trinket in the bags made it ask \"bind it to you?\" again and again – now it's left alone, and only trinkets you've already worn are put back",
  } },
  { v = "1.3.2", date = "19.11", items = {
    "Market tooltip: Best: Auction or Best: Vendor, with how much more you get (after the auction house's 5 % cut), the price of the whole stack you're hovering, and how much the price moved since the last scan",
    "Watching: shorter place text (\"dead · Western Plaguelands\"), and a small fact under each name that changes every 6 s – XP/h, % of the level, time to the next one, gold/h this week, quests, kills and deaths this week, time online today, streak, item level",
  } },
  { v = "1.3.1", date = "19.11", items = {
    "Market: the scan button is a tab along the bottom of the auction house, right after its other tabs (also next to tabs other auction addons add), with the status beside it",
    "Market: tooltip prices use the gold, silver and copper coins like the game's own tooltips",
  } },
  { v = "1.3.0", date = "19.11", items = {
    "Chillan? Market: auction house prices for the whole gang. Open the auction house and click \"Chillan? scan\" (top right) – the game allows a full scan every 15 minutes",
    "Every item tooltip shows its market value and how old the price is (greyed after 3 days). Market value = the typical price of the cheapest listings, ignoring silly ones",
    "Prices are shared: after you scan, the ones that changed go to the gang quietly over a few minutes, and when you log in a friend with newer prices sends you what you missed. The newest scan always wins",
    "On the classic-style auction house it also checks the items in your bags when you open it (and stops as soon as you search yourself)",
    "Settings → Modules: switch the tooltip prices or the sharing off. /chill selftest shows which auction house this is",
  } },
  { v = "1.2.4", date = "19.11", items = {
    "Gang pulse: the faces of the friends online are bigger, and at most 4 are shown – the rest as \"+2\"",
    "On a low alt, XP/h and time to level no longer borrow your main's pace for the week (it said 218k XP/h and 0m at level 1)",
  } },
  { v = "1.2.3", date = "19.11", items = { "Watching: the empty strip just says \"+ Watch someone\" (the explanation is in the tooltip)" } },
  { v = "1.2.2", date = "19.11", items = {
    "Watching: keep an eye on up to 4 friends right in the Gang pulse, under the Now card – online dot, name, level, where they are (zone, dungeon, \"dead\", or \"your layer\") and a thin bar for how far into the level they are",
    "Add someone: the Watch button on their person card, the eye on their Friends row, \"+ Watch someone\" in the strip, or Shift-click their name (Ctrl-click now pins the profile card)",
    "Hover a watched friend for their card, click to whisper, × or right-click to stop watching. The row flashes once when they ding, die or loot an epic – no popup",
    "Who you watch is yours only and kept between sessions. ⋯ → Show the Watching strip hides it",
  } },
  { v = "1.2.1", date = "19.11", items = {
    "Layer hop leaves the group again: it now keeps trying every 2 s for half a minute (a fight, a loading screen or a leave the game ignored only delay it). Before, it tried once, and only in a group of two – so a host with another hopper in the group, or combat at that moment, left you stuck in the group",
    "If the friend you hosted is still in your group a minute after the hop, you leave, so the group ends either way",
    "Never leaves a raid or a dungeon group, and says /leave in chat if it really can't",
  } },
  { v = "1.2.0", date = "19.11", items = {
    "Person card: click someone on Friends and the card opens joined to their row (the row lights up with the same edge), or beside their card on Home",
    "The card lists all their characters – from every install with the same name – with a green dot on the ones online right now, and where",
    "At level 60 the card shows item level and kills this week instead of XP per hour and time to level",
    "Home: clicking a gang member opens the card (Open player is in it); Shift-click still pins the profile",
  } },
  { v = "1.1.9", date = "19.11", items = {
    "Alts on other installs are now one person: everyone with the same name (\"Simon\") is shown once, and their page lists all their characters under Other characters – with the professions from those characters too",
    "Friends shows \"+2 alts\" next to people with more characters. Clicking an alt's name anywhere opens the person",
    "Crafters lists professions from every character again, so an alt's profession can still be asked for",
  } },
  { v = "1.1.8", date = "19.11", items = {
    "Carrot on a Stick stuck on: when it's on while you're on foot and Chillan has nothing saved to put back, it now picks your own trinket – the last one you wore in that slot, else the one from your other trinket slot, else the best trinket in your bags",
    "/chill qol test also shows which of your own items it remembers per slot",
  } },
  { v = "1.1.7", date = "19.11", items = {
    "The same friend no longer shows up twice (a second PC or a new install): the one online, or furthest along, is shown",
    "Deaths are counted the same everywhere – the Legend book now agrees with the Wall of Shame",
    "Progress chart: lines run to the level people have now, the legend shows the right level, and history that started late no longer draws a wall from level 1",
    "Level race and Neck and neck are for the ones still levelling – level 60 is the finish line",
    "Time to next level uses this week's pace until a session has run 20 minutes, and ignores a session spent standing in town",
    "Gold/h shows – until you've earned or spent something",
    "Died to: pets aren't listed (we can't tell whose pet it was), and \"Maraudon, Maraudon\" is just Maraudon",
    "\"Last seen\" no longer turns into \"just now\" when a friend passes on someone they had no time for",
    "QoL: under a switch that's off, the small options show unticked",
    "Navigation: Progress is one row – Overview, Chart, Titles, Trophies, History, Legend book. The side cards are on Overview only, so the other pages get the full width",
    "Pages with only one tab (Home, Chat) no longer show a page pill. \"N online\" in the top bar opens Friends",
    "Gang: \"Gang & crafters\" is now Crafters, grouped by profession – click a name to ask them. The gang code, your name and \"add a friend\" moved to Settings → Your gang",
    "Friends: no \"Offline\" pill or map button on offline friends, no gap when nobody is online, and the crown is explained",
    "Cunt List and Died to have the same margins as the other pages; small text fixes (1 death, titles and card headings no longer cut off)",
  } },
  { v = "1.1.6", date = "19.11", items = {
    "Gang pulse: the XP bar and level line are gone at level 60",
    "Gang pulse: before 60 it says how much XP is left to the next level instead of a guess at how many quests",
  } },
  { v = "1.1.5", date = "19.11", items = {
    "Themes and accent colours change straight away – no more reload",
    "Home: everyone in the gang as a small card on the left (online first, then offline with when they were last on)",
    "Home: the gang's latest moments are drawn like the feed – icons in tinted boxes, reactions as pills, + on hover to react",
    "Home: quick actions are Layer hop, Plan something (post a plan the gang can say yes to), Cunt List: your target, and Move things on screen",
    "Home: under This week you also see your own week (quests, levels, gold, kills, deaths, time played), the enemy of the week and the next plan",
    "Settings and What's new are only the cog and the bell in the top right now, not tabs as well",
    "Your own ding popup no longer says 'the gang can react now'",
  } },
  { v = "1.1.4", date = "19.11", items = {
    "WowUp shows the version as v1.1.4 instead of the zip file's name",
    "A /reload (or a quick relog) no longer starts the session over: gold/h, quests and mobs carry on. After 15 minutes away a new session starts",
  } },
  { v = "1.1.3", date = "19.11", items = {
    "Carrot on a Stick that stayed on after dismounting: when the game drops the swap back (it often does right after you dismount), Chillan now keeps trying until your own trinket is really back on – before, it forgot after the first try",
    "If the game blocks a gear swap, the mount swap pauses for a minute instead of until /reload",
    "A swap that misses because of timing no longer makes Chillan switch to the slower pick-up-and-place way when the normal way has already worked",
    "Carrot (or spurs/gloves) still on while you're on foot with nothing to put back? Chillan remembers your own gear per slot and puts it back",
  } },
  { v = "1.1.2", date = "19.11", items = {
    "The feed is drawn as real rows: the time, the icon in a small tinted box, then the text – like the design",
    "Reactions are pills on their own line under the event, with the count. Hover a pill to see who, click it to give the same reaction",
    "Hover a line and a small + shows on the right: click it to react. No more star or (react) in the text",
    "The boxes and the Now card stay open in combat by default. Unpin (the lock in the bar) if you want them to fold away",
  } },
  { v = "1.1.1", date = "19.11", items = {
    "Gang pulse is slimmer: the four boxes are narrower and the panel can be dragged down to 270 px wide (starts at 300)",
    "The Now card shows how far into your level you are (%) instead of the time to level again – that's in the box above",
    "React is a small star at the end of the line, only on the last 30 minutes, so lines wrap less",
    "The 'earlier today' marker no longer shows as empty boxes",
  } },
  { v = "1.1.0", date = "19.11", items = {
    "Gang pulse: the bar, the stat tiles and the event window are now one panel that changes with where you are – open world, dungeon or battleground",
    "Top bar: the friends online as small overlapping dots and \"N online\" – hover for who, where, level and layer. The chip says your status, or the dungeon or battleground you're in",
    "Four fixed boxes under the bar. Open world: layer hop, XP/h, gold/h, time to next level. Dungeon: bosses, run time, XP this run, XP/h. Battleground: honor/h, kills, time in the BG, wins today",
    "The Now card under them: time to level with a bar, this session's quests, mobs and gold, and a warning when someone from \"Died to\" is near you. In a dungeon: loot this run, your bags and durability when they're low, and Ready check. In a battleground: kills, deaths, streak and today's honor",
    "In combat the boxes and the card fold away so only the feed shows. The pin keeps them open. The ⋯ button has the feed filter, the mode lock, layout and settings",
    "The feed: kills or deaths by the same person within 15 minutes are one line that counts up, the earlier-today marker sits above the old lines, and more of the last 12 hours is shown",
    "Stats → Progress: hover a line to see who, the level and the date – the line lights up and the rest fade. Players of the same class get their own shade, and a character made again no longer draws a line going down",
  } },
  { v = "1.0.1", date = "19.11", items = {
    "Fewer popups: when someone dies or kills an Alliance player, it pops up once, then deaths (and kills) stay quiet for 10 minutes for the whole gang. At most 6 of those an hour. Everything still lands in the event window",
    "React from the event window: others' deaths, kills, dings and trophies get a [react] link, so a death that didn't pop up can still get its laugh or F",
    "Settings → Quiet → Popups: Calm (only the big moments), Normal (the new default) or All (every death and kill, like before)",
    "Your own small trophies that unlock together come as one notice instead of one each",
    "The Cunt List is manual only again. Entries that came in by themselves (deaths, the old enemy log) are cleaned out – the ones someone added on purpose stay",
    "New page under Gang: Died to – the Alliance players who killed someone in the gang, how often, who and where. It fills itself and warns nobody. 'Cunt List …' on a row adds them for real",
    "Revenge now also counts killing someone who killed anyone in the gang in the last week. Enemy of the week on the Stats page is the one with the most kills on the gang",
  } },
  { v = "1.0.0", date = "17.11", items = {
    "Chillan 1.0! A new main window: sections along the top (Home, Gang, Chat, Progress, Tools), with Settings behind the cog and What's new behind the bell. Resize it from the corner – the size is remembered",
    "New Home page: who's online, what the gang has been up to lately, quick actions (layer hop, ready check) and this week's challenge with your place in it",
    "Move things on screen: /chill edit (or the button in Settings) shows every Chillan frame at once so you can drag them, with 1080p and 1440p presets and a reset",
    "Fewer popups: only a short list of big moments pops up for the whole gang. Everything else goes to the feed with a small notice",
    "The SOS button is gone – nobody used it",
    "The old enemy log is merged into the Cunt List, so there's one list. Revenge kills count anyone on it, or anyone who killed you in the last 7 days",
    "New trophies: revenge kill, first layer hop, hosting 10 layer hops, tagging enemies. Alliance kills Chillan sees now count toward the kill trophies. 'Layer hopper' was renamed 'Zone hopper' (it counts zone changes)",
    "Layer hop: 'it didn't move you' is only said when it's sure (several creatures still on your old layer after 15 s). Otherwise it tells you it couldn't tell",
    "QoL: lighter on the game (reacts to events instead of checking 4 times a second), and steps aside if AutoCarrot or Leatrix Plus already handles mount gear, repairs or junk",
    "/chill selftest checks what the game lets Chillan do right now (messages, channel, who's online) – handy when something seems off",
    "Version now shows as plain 1.0.0 in WoWUp",
  } },
  { v = "0.33.5", date = "16.11", items = {
    "Layer hop: players you can see are on your layer, so they're never asked for a hop and their invites are no longer accepted (a host standing right next to you could invite you and move nothing)",
    "Layer hop: the second ask to LayerSwap hosts that don't know their layer yet now waits until the first round is done and no host on another layer has answered – that second ask made them invite blind, even from your own layer. Hosts that didn't move you aren't asked that way again for 10 min",
  } },
  { v = "0.33.4", date = "16.11", items = {
    "Layer hop, updated with LayerSwap 1.14.25's lessons: after a hop that worked you leave the host's group after 4 s instead of 30 s – longer stays could pull the host onto your layer",
    "Layer hop reaches more players: each click searches the zone, then one class at a time (the game lists 50 per search), and the zone search now works on non-English clients too",
    "Known LayerSwap hosts are remembered for a week instead of 3 hours. One that's offline is skipped for 10 minutes instead of forgotten",
    "Hosting pauses while you're in the group finder or a dungeon queue, and while a world refresh counts down (it already paused in combat). /chill layer status says why",
    "An invite from a host whose reply said it's on your layer isn't auto-accepted any more (it wouldn't move you), and a host that didn't move you is skipped for 20 s",
  } },
  { v = "0.33.3", date = "16.11", items = {
    "Mount swap rebuilt for WoW Forever: Carrot on a Stick, The Desert Rose (desert zones), Wintersaber Hide Lined Gloves (Winterspring), Riding Skill gloves and Mithril Spurs boots. Riding Crop, Skybreaker Whip and the swim gear don't exist in Forever, so they're gone",
    "Probably why the carrot didn't swap: a carrot that's never been worn isn't soulbound, and the game won't let addons equip it. Chillan now tells you – equip it once by hand and it swaps from then on",
    "The swap waits while you cast, hold an item on the cursor or have a vendor, mail, bank or loot window open, and says in chat if the game blocks it",
    "/chill qol test lists every speed item it finds and why it would or wouldn't swap; /chill qol reset clears a blocked state",
  } },
  { v = "0.33.2", date = "16.11", items = {
    "Fix: Lua error (ContainerFrame.lua) when opening bags with the red tint on",
  } },
  { v = "0.33.1", date = "16.11", items = {
    "Fix: the riding trinket didn't swap for everyone – Chillan now checks the swap worked and, if not, does it the old pick-up-and-place way, and retries a couple of times",
    "/chill qol test shows what the mount swap sees (mounted, slot, trinket found) and its last steps – send a screenshot if it still won't swap",
    "QoL tab redone: cards side by side, with small options under each switch (greyed out when the switch is off)",
    "New small options: chat line when riding gear swaps, druid flight charm, repair cost and junk total in chat (each on/off), turn in quests and pick from NPC lists separately, rested XP and quests-to-level separately, let the gang duel or invite you, res during boss fights or not",
  } },
  { v = "0.33.0", date = "16.11", items = {
    "New QoL tab (/chill qol): switch helpers on and off. Hover a switch to see what it does",
    "Mount gear: Riding Crop, Skybreaker Whip or Carrot on a Stick goes on when you mount and your own trinket comes back when you get off (spurs boots and riding gloves too). Swim gear in water. Found in your bags automatically, never swapped in combat",
    "Vendor: auto-repair (guild bank first), sell grey junk, and fast loot",
    "Questing: auto accept and turn in (off by default, stops when you must pick a reward), skip cutscenes you've seen, XP bar text with rested and quests to level",
    "Fewer annoyances: decline duels and guild invites from strangers, accept summons and res, hide red error spam, max camera zoom",
    "Info: red tint on bag items you can't use, flight timer on flight paths",
    "Hold Shift at a vendor or quest giver to skip the automatic stuff once",
  } },
  { v = "0.32.2", date = "17.11", items = {
    "No more offline sound – a friend's /reload looked like a logout and made noise for nothing (and no login sound when they're back after a reload)",
  } },
  { v = "0.32.1", date = "16.11", items = {
    "Fewer popups: dings pop up at level 10, 15 and from 20 (level 60 gets its own MAX LEVEL popup); the rest are in the feed",
    "Only the big achievements pop up for the gang (first epic, first mount, raids, 300 professions, 60 fast, weekly win …) – the rest show in the feed, and you get a small notice for your own",
    "Several things from one person at once (a ding and an achievement) come as one popup",
    "Discord follows the same rules: cards only for those dings and big achievements, the rest still count in the recaps",
  } },
  { v = "0.32.0", date = "15.11", items = {
    "Mute friends: Mute on their row (click the row) or their profile. No popups or sounds from them – dings, deaths, achievements, kills, SOS, logins, reactions, chat pops. Their stuff still shows in the feed, stats and the normal WoW chat window, and their @mentions of you still come through. Only you know who you've muted",
    "Do not disturb: picking the status (Friends page or Settings → Quiet) mutes every popup and sound, @mentions included, until you switch it off",
    "Settings → Quiet lists everyone you've muted, with Unmute buttons",
  } },
  { v = "0.31.1", date = "15.11", items = {
    "Stats cards: the rest got the same treatment – Next ding is now XP bars for the two closest, Deadliest zones shows the two worst as bars, Hot streak shows the top two, Enemy of the week wraps the note instead of cutting it, and Dungeon records / First in the gang are tidy rows (name left, time or first right)",
    "Stats cards: bars are a bit tighter so two always fit in a card",
  } },
  { v = "0.31.0", date = "15.11", items = {
    "Stats cards redone: no more cut-off text. Wall of shame shows the two worst as bars with the gang total (hover for top 5 and the last death), Neck and neck and Level race show class-coloured XP bars, the weekly challenge shows the top 3, and The gang this week shows quests against last week",
    "Stats cards: the counter in the corner now shows which card you're on («2 of 9») – it used to show a line count",
    "Weekly challenge: the winner is now decided only once everyone who played that week has synced their final numbers (or by Thursday at the latest), and then locked, so playing at different times no longer gives the wrong winner",
    "Weekly stats sync: last week's levels and PvP kills no longer get wiped or carried into the new week, and friends who are offline now pass on levels and kills too",
    "«Winner of the week» now says what was won (e.g. Most quests – 333 quests) in chat, the popup and Discord",
    "Kills: reactions to your kill now say «X reacted to your kill – You killed Y in Z» (it used to say «On level <zone>»), and you no longer get the kill popup for a group kill you were in on yourself",
    "Friends opens on «All» instead of «Online only»",
    "Removed the Quests tab",
  } },
  { v = "0.30.7", date = "15.11", items = {
    "Bigger «+» on the bar for pinning buttons and stats",
  } },
  { v = "0.30.6", date = "15.11", items = {
    "Cunt List: players only – no 'Add to the Cunt List' on NPCs, names must be real character names, and «Add by name» looks the player up first (not online? you're asked whether to add them anyway)",
  } },
  { v = "0.30.5", date = "15.11", items = {
    "Cunt List: «Add by name» – add someone without targeting them, just type the name and why",
  } },
  { v = "0.30.4", date = "14.11", items = {
    "Settings: the popup size slider's text no longer overlaps its value",
  } },
  { v = "0.30.3", date = "15.11", items = {
    "New setting: size of popups (ding, reactions, toasts, SOS, ready check, level recap) – Settings → Appearance. Try 80 % on a 1080p screen; «Show a test popup» to see it",
  } },
  { v = "0.30.2", date = "15.11", items = {
    "New look: the Chillan? seal in the addon list, on the minimap button and in the window header",
  } },
  { v = "0.30.1", date = "15.11", items = {
    "Cunts page: the text at the top no longer runs under the «Add your target» button",
  } },
  { v = "0.30.0", date = "15.11", items = {
    "The Cunt List: right-click a player's name or portrait → «Add to the Cunt List», say why, and the whole gang has it",
    "Warnings when someone on the list invites you, joins your group or gets targeted, red lines in their tooltip, and a [Cunt] tag on their chat lines and whispers",
    "New Cunts page: every entry with reason, who added it and when; search, add notes ('did it again'), and remove the ones you added. Also /chill cunt <name>",
    "New entries go to the feed and Discord (/cunts in Discord lists them)",
  } },
  { v = "0.29.5", date = "15.11", items = {
    "Fix: the level recap and 'Gratz' box no longer pop up out of nowhere when changing zone – a ding in combat (when the game hides the level) is now handled right away, and a loading screen no longer resets your level record",
  } },
  { v = "0.29.4", date = "14.11", items = {
    "Only gear, recipes, mounts and pets are posted as drops – writs, quest items, consumables and materials no longer show up, whatever their colour",
  } },
  { v = "0.29.3", date = "14.11", items = {
    "Item links in the gang chat and feed work like in normal chat: Ctrl-click opens the dressing room, a plain click shows the item, Shift-click links it",
    "Drops are only posted when they really came from looting (a corpse, chest, loot roll or quest reward) – crafting, mail, the auction house, trades, vendors and the bank no longer count as new gear",
  } },
  { v = "0.29.2", date = "13.11", items = {
    "Layer hop asks the players in your zone first (the search also lists players elsewhere, who can't move you), up to 49, and stops as soon as an invite comes",
    "Layer hop reads the LayerSwap hosts' answers: no invite after a round tells you why (on your layer / not hosting / nobody answered), and clicking again starts a fresh round",
    "No more 'No player named … is currently playing' lines from layer hop asks to players who logged off",
    "Alliance kills are caught even when the game hides the honour line mid-fight (Chillan watches the kill count) – /chill kills shows what it saw",
    "Enchanting shards, trade goods and reagents are no longer posted as drops",
  } },
  { v = "0.29.1", date = "13.11", items = {
    "Fix: deaths (and everything else) during a dungeon boss fight reach the gang right after the fight – the game blocks addon messages mid-fight, and they used to get thrown away and only show up much later",
    "Blue drops and better are always shared now, also when the game hides the loot line in dungeons (Chillan spots the new item in your bags) and when an item wasn't loaded yet",
    "Up to 9 tiles and buttons under the bar (3 x 3)",
  } },
  { v = "0.29.0", date = "12.11", items = {
    "Buttons under the bar: the + menu now has a Buttons section – Layer hop, SOS, Open Stats and Open Trophies – next to the stat tiles",
    "The Layer hop button shows your layer and what's happening (searching, asked 12, invite from …, moved!) – one click hops",
  } },
  { v = "0.28.8", date = "12.11", items = {
    "Layer hop works like LayerSwap: the click searches your zone first (the game only allows that straight from a click), then asks the LayerSwap users it finds – a host on another layer invites you",
    "If a gang member in your zone is on another layer they're asked first; no invite within 10 s and the LayerSwap users your click found are asked automatically",
  } },
  { v = "0.28.7", date = "12.11", items = {
    "Test command for the layer hop player search: /chillwho",
  } },
  { v = "0.28.6", date = "12.11", items = {
    "Layer hop without LayerSwap: the gang pools the LayerSwap users each Chillan has learned, and players who chatted in a channel in your zone are asked too (only LayerSwap users can read the request – nobody sees anything)",
  } },
  { v = "0.28.5", date = "12.11", items = {
    "Layer hop: the gang is only asked when someone is known to be on another layer in your zone – no more pointless invites from friends on your own layer",
  } },
  { v = "0.28.4", date = "12.11", items = {
    "Layer hop: if the game blocks the player search, Chillan notices it every time (also when the game reports it a moment late), stops trying for a week and asks the LayerSwap users it knows",
  } },
  { v = "0.28.3", date = "12.11", items = {
    "Layer hop: when the game won't let Chillan search for players, it asks the LayerSwap users it already knows in your zone instead – Chillan learns them by itself as they ask for hops nearby (and from LayerSwap's own list if you have it)",
    "/chill layer status shows how many LayerSwap users Chillan knows nearby",
  } },
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
