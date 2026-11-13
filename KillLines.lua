-- Chillan? – Alliance kill lines (the flip side of DeathLines)
-- {n} = the gang member(s) in on the kill, {v} = the Alliance player, {c} = their race/class,
-- {z} = zone. Lines are past tense so they work for one killer and for several.
-- Detection: the game's honour message ("X dies, honorable kill…"), which every player who helped
-- gets. Not posted in battlegrounds or arenas.
local ADDON, ns = ...

local K = {}
ns.Kills = K

K.POOLS = {
  KILL = {
    "{n} fucking rekt {v} in {z}.",
    "{n} absolutely fucked up {v}, a filthy {c}, in {z}.",
    "{n} sent {v} crying back to Stormwind.",
    "{n} farmed {v} like a goddamn herb node in {z}.",
    "{n} turned {v} into an honorable kill and a bad memory.",
    "{n} deleted {v} in {z}. Alliance tears taste great.",
    "{n} slapped the shit out of {v} in {z}.",
    "{n} put {v} in the dirt where the Alliance belongs.",
    "{n} made {v} regret rolling Alliance.",
    "{n} bodied a {c} named {v} in {z}. Fucking delicious.",
    "{n} curb-stomped {v} in {z}. For the Horde!",
    "{n} gave {v} a free ticket to the spirit healer.",
    "{n} clapped {v}'s cheeks in {z}. Respectfully.",
    "{n} turned {v} into a corpse run and a rage quit.",
    "{n} wiped the floor with {v}. Lok'tar, motherfucker.",
    "{n} ganked {v} in {z} and felt absolutely nothing.",
    "{n} smoked {v} like a cheap cigar.",
    "{n} ended {v}'s whole bloodline in {z}.",
    "{n} sent {v} to the graveyard with a goddamn bow on top.",
    "{n} folded {v} like a cheap-ass lawn chair.",
    "{n} beat {v} like he owed the Horde gold.",
    "{n} rag-dolled {v} across {z}.",
    "{n} served {v} a full-course ass-kicking.",
    "{n} murdered {v} in {z}. The Alliance won't recover from this.",
    "{n} made {v} eat dirt in {z}. Tasty.",
    "{n} uninstalled {v}'s confidence.",
    "{n} turned {v} into a lootable corpse. Shame there's nothing to loot.",
    "{n} demolished {v}. Some {c} is having a terrible day.",
    "{n} speedran {v} to the spirit healer.",
    "{n} handed {v} his own ass in {z}.",
    "{n} absolutely dumpstered {v}. Get that bastard a rez.",
    "{n} took {v}'s lunch money and his life.",
    "{n} pancaked {v} in {z}. Flat as fuck.",
    "{n} showed {v} what the Horde is about.",
    "{n} merked {v} in {z}. Holy shit.",
    "{n} bullied {v} to death. Deserved.",
    "{n} reduced {v} to a pile of Alliance-flavoured paste.",
    "{n} murked a {c} in {z}. Next.",
    "{n} chewed up {v} and spat out his shitty gear.",
    "{n} made {v} rethink his life choices.",
    "{n} punted {v} straight back to the loading screen.",
    "{n} gave {v} the full Horde experience.",
    "{n} hunted {v} down like a goddamn quest mob.",
    "{n} absolutely shitstomped {v} in {z}.",
    "{n} ate {v} for breakfast. Still hungry.",
    "{n} slapped {v} into next week.",
    "{n} turned {v} into honor points and a sad /cry.",
    "{n} sent {v} home in a body bag.",
    "{n} made {v} a fucking statistic.",
    "{n} caught {v} slipping in {z}. Rest in pieces.",
    "{n} one-tapped {v}'s will to live.",
    "{n} beat {v} so hard his ancestors felt it.",
    "{n} flattened {v}. Somewhere a paladin is crying.",
    "{n} fucked {v} up so bad the spirit healer winced.",
    "{n} left {v} face down in {z}. Lol.",
    "{n} wrecked {v}'s whole evening.",
    "{n} absolutely cooked {v}. Well done, extra crispy.",
    "{n} smashed {v} in {z}. Alliance diff.",
    "{n} said hi to {v} with a fucking axe.",
    "{n} reminded {v} why the Alliance should stay in Elwynn.",
    "{n} sent {v} to /2 to complain about ganking.",
    "{n} made {v} alt-F4 in shame.",
    "{n} turned {v} into a cautionary tale.",
    "{n} played whack-a-mole with {v}. {v} lost.",
    "{n} recycled {v} into honor.",
    "{n} absolutely clowned on {v} in {z}.",
    "{n} gave {v} a dirt nap in {z}.",
    "{n} took {v} down without breaking a sweat.",
    "{n} made {v} the gang's newest trophy.",
    "{n} turned {v}'s armor into a repair bill.",
    "{n} handled {v} like a goddamn tutorial boss.",
    "{n} sent {v} to meet his maker. His maker laughed too.",
    "{n} beat {v} like a rented mule in {z}.",
    "{n} smacked {v} so hard his hearthstone went on cooldown.",
    "{n} put {v} on the floor and kept walking.",
    "{n} deleted a {c}. Patch notes: Alliance nerfed.",
    "{n} dragged {v} through the mud in {z}.",
    "{n} absolutely bodybagged {v}.",
    "{n} served {v} his ass on a plate.",
    "{n} made {v} remember the name. Probably.",
    "{n} ganked {v} so hard he reported it as a bug.",
    "{n} turned {v} into fertiliser for {z}.",
    "{n} ran {v} over like a fucking kodo.",
    "{n} cleaned {v} out of {z}. Good riddance.",
    "{n} roasted {v} alive. Barbecue's ready.",
    "{n} snapped {v} like a twig.",
    "{n} absolutely obliterated {v}. Not even close.",
    "{n} put {v} on the spirit healer's waiting list.",
    "{n} gave {v} the Horde welcome to {z}.",
    "{n} pantsed and killed {v}. In that order.",
    "{n} made the Alliance one {c} lighter.",
    "{n} taught {v} a lesson he'll forget by the next corpse run.",
    "{n} sent {v} back to Ironforge in pieces.",
    "{n} kicked {v}'s shit in, in {z}.",
    "{n} gave {v} a reason to roll Horde.",
    "{n} turned {v} into a loading screen tip.",
    "{n} stomped {v} flat. Zug zug.",
    "{n} absolutely embarrassed {v} in front of the whole zone.",
    "{n} hit {v} with the Horde special. Death.",
    "{n} fucking annihilated {v} in {z}. Gang, we eat tonight.",
  },
  REVENGE = {
    "REVENGE! {n} finally fucking rekt {v}. The bastard had it coming.",
    "{n} got revenge on {v}. Payback's a bitch, isn't it?",
    "{v} picked the wrong Horde to fuck with. {n} settled the score.",
    "{n} hunted down {v} and collected the debt. With interest.",
    "Remember {v}? {n} sure did. Now he's dead.",
    "{n} crossed {v} off the shit list. Permanently.",
    "Karma came for {v}, and its name was {n}.",
    "{n} returned the favour to {v}. Twice as hard.",
    "{v} thought the Horde forgets. {n} doesn't.",
    "{n} served {v} a cold plate of revenge in {z}.",
    "The enemy log just got lighter: {n} rekt {v}.",
    "{n} made {v} pay for his sins. Amen.",
    "{v} ganked the gang. {n} ganked {v}. Circle of life, bitch.",
    "{n} avenged the gang. {v} is now very dead.",
    "Long time no see, {v}. {n} said hi with an axe.",
    "{n} finally caught {v} in {z}. Sweet, sweet revenge.",
    "{v} is back on the floor where he belongs, thanks to {n}.",
    "{n} told {v} \"remember me?\" and then fucking ended him.",
    "Justice for the gang: {n} put {v} in the dirt.",
    "{v} owed the Horde a corpse. {n} collected.",
  },
}

local function recentList()
  ns.db.killRecent = ns.db.killRecent or {}
  return ns.db.killRecent
end

-- a line index for the category, avoiding the last 10 used
function K:Pick(cat)
  local pool = self.POOLS[cat]
  if not pool then return nil end
  local recent = {}
  for _, r in ipairs(recentList()) do recent[r] = true end
  local idx
  for _ = 1, 12 do
    idx = math.random(#pool)
    if not recent[cat .. ":" .. idx] then break end
  end
  table.insert(recentList(), 1, cat .. ":" .. idx)
  while #recentList() > 10 do table.remove(recentList()) end
  return idx
end

-- names of everyone in on the kill (the item's own player plus merged ones)
function K:Names(item, colored)
  local out = {}
  local function add(pid, char)
    local p = ns:GetPerson(pid)
    if p then
      out[#out + 1] = colored and ns:ShortWho(p, char) or (ns:PersonAlias(p) or ns.ShortName(char or "") or "?")
    end
  end
  add(item.pid, item.char)
  for _, w in ipairs(item.w or {}) do add(w[1], w[2]) end
  if #out <= 1 then return out[1] or "Someone" end
  return table.concat(out, ", ", 1, #out - 1) .. " and " .. out[#out]
end

-- the funny line for a KILL feed item: a = zone, b = "KILL:idx"/"REVENGE:idx", c = victim, d = race/class
function K:Line(item, nameText, baseHex)
  if type(item.b) ~= "string" then return nil end
  local cat, idx = item.b:match("^(%u+):(%d+)$")
  local pool = cat and self.POOLS[cat]
  local line = pool and pool[tonumber(idx)]
  if not line then return nil end
  local C = ns.C
  local back = baseHex and ("|cff" .. baseHex) or ""
  local v = "|cff5CA8FF" .. (item.c ~= "" and item.c or "some Alliance scrub") .. "|r" .. back
  nameText = nameText .. back
  local zone = item.a and item.a ~= "" and item.a or "the middle of nowhere"
  line = line:gsub("{n}", function() return nameText end)
  line = line:gsub("{v}", function() return v end)
  line = line:gsub("{z}", function() return zone end)
  local cx = item.d ~= "" and item.d or "Alliance player"
  line = ns.Article(line, cx)
  line = line:gsub("{c}", function() return cx end)
  if baseHex then line = "|cff" .. baseHex .. line .. "|r" end
  return line
end

function K:Kicker(item)
  if type(item.b) == "string" and item.b:find("^REVENGE") then return "REVENGE!" end
  return "ALLIANCE DOWN"
end

function K:InPvPInstance()
  local inInst, kind = ns.S(IsInInstance)
  return inInst and (kind == "pvp" or kind == "arena") or false
end

---------------------------------------------------------------------------
-- detection
---------------------------------------------------------------------------
-- race/class of Alliance players seen recently (target, mouseover, nameplates)
local seen = {}
local function remember(unit)
  if not ns.S(UnitIsPlayer, unit) or not ns.S(UnitCanAttack, "player", unit) then return end
  local name = ns.S(UnitName, unit)
  if not name or name == "" then return end
  local race = ns.S(UnitRace, unit)
  local class = ns.S(UnitClass, unit)
  local txt = ((race or "") .. " " .. (class or "")):gsub("^%s+", ""):gsub("%s+$", "")
  seen[name] = { txt = txt, at = GetTime() }
end
ns:On("PLAYER_TARGET_CHANGED", function() remember("target") end)
ns:On("UPDATE_MOUSEOVER_UNIT", function() remember("mouseover") end)
ns:On("NAME_PLATE_UNIT_ADDED", function(unit) if type(unit) == "string" then remember(unit) end end)

-- build a Lua pattern from the game's own (localised) honour message
local patterns
local function honourPatterns()
  if patterns then return patterns end
  patterns = {}
  for _, g in ipairs({ "COMBATLOG_HONORGAIN", "COMBATLOG_HONORGAIN_NO_RANK", "COMBATLOG_HONORGAIN_EXHAUSTION1" }) do
    local fmt = _G[g]
    if type(fmt) == "string" and not ns.isSecret(fmt) then
      local f = fmt:gsub("%%%d%$", "%%")                         -- "%1$s" -> "%s"
      local p = f:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")      -- escape everything magic
      p = p:gsub("%%%%s", "(.-)"):gsub("%%%%d", "%%d+"):gsub("%%%%%%%.%%d*f", "[%%d%%.]+"):gsub("%%%%f", "[%%d%%.]+")
      patterns[#patterns + 1] = "^" .. p
    end
  end
  patterns[#patterns + 1] = "^(.-) dies, honorable kill"
  return patterns
end

function K:VictimFrom(text)
  if type(text) ~= "string" or ns.isSecret(text) then return nil end
  for _, p in ipairs(honourPatterns()) do
    local v = text:match(p)
    if v and v ~= "" then return (v:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
  end
end

-- A kill is spotted three ways, so one the game hides still counts:
--  1) the honour line in chat ("X dies, honorable kill") – names the victim
--  2) PLAYER_PVP_KILLS_CHANGED – the game's own kill counter went up
--  3) the session kill count (GetPVPSessionStats) went up – checked every few seconds
-- In a fight the game can hide chat lines from addons, so 2) and 3) post the kill with the
-- enemy you had targeted (if it's dead) when no honour line came.
K.diag = { honour = 0, hidden = 0, counter = 0, session = 0, posted = 0 }
local lastVictim, lastAt, lastPostAt = nil, 0, 0

local function postKill(victim, via)
  if K:InPvPInstance() then return end
  victim = victim or ""
  if victim ~= "" and victim == lastVictim and GetTime() - lastAt < 10 then return end
  if victim == "" and GetTime() - lastPostAt < 5 then return end   -- the named post already went out
  lastVictim, lastAt, lastPostAt = victim, GetTime(), GetTime()
  local short = victim ~= "" and ns.ShortName(victim) or ""
  local s = short ~= "" and (seen[victim] or seen[short]) or nil
  local extra = s and GetTime() - s.at < 600 and s.txt or ""
  local zone = ns.Clean(ns.S(GetRealZoneText) or "", 40)
  local enemy = short ~= "" and ns.db.enemies and ns.db.enemies[short:lower()]
  local cat = enemy and "REVENGE" or "KILL"
  if enemy then enemy.revenge = (enemy.revenge or 0) + 1 end
  local idx = K:Pick(cat)
  K.diag.posted = K.diag.posted + 1
  K.diag.last = via
  ns.Tracker:Event("KILL", zone, cat .. ":" .. idx, ns.Clean(short, 40), ns.Clean(extra, 30))
end
K.PostKill = postKill

-- the enemy player you were fighting: your target if it's a dead enemy player, else the last one seen
local lastFoe
local function noteFoe(unit)
  if not ns.S(UnitIsPlayer, unit) or not ns.S(UnitCanAttack, "player", unit) then return end
  local name = ns.S(UnitName, unit)
  if type(name) == "string" and name ~= "" then lastFoe = { name = name, at = GetTime() } end
end
ns:On("PLAYER_TARGET_CHANGED", function() noteFoe("target") end)
ns:On("UNIT_HEALTH", function(unit) if unit == "target" then noteFoe("target") end end)
local function foeName()
  if ns.S(UnitIsPlayer, "target") and ns.S(UnitCanAttack, "player", "target") and ns.S(UnitIsDead, "target") then
    local n = ns.S(UnitName, "target")
    if type(n) == "string" and n ~= "" then return n end
  end
  if lastFoe and GetTime() - lastFoe.at < 20 then return lastFoe.name end
  return ""
end

ns:On("CHAT_MSG_COMBAT_HONOR_GAIN", function(text)
  if ns.isSecret(text) then K.diag.hidden = K.diag.hidden + 1 return end
  K.diag.honour = K.diag.honour + 1
  local victim = K:VictimFrom(text)
  if victim then postKill(victim, "honour line") end
end)

-- Count kills so each is posted once: the game's kill count says how many kills happened, the
-- honour lines say which ones were already posted. Kills the count shows but no line named get
-- posted with the enemy we were fighting.
local owed, credit, creditAt = 0, 0, 0
local function settle()
  if GetTime() - creditAt > 30 then credit = 0 end
  while owed > 0 do
    owed = owed - 1
    lastPostAt = 0                       -- a counted kill is a kill of its own
    postKill(foeName(), "kill count")
  end
end

local sessionHK
local function sessionKills()
  if not GetPVPSessionStats then return nil end
  local ok, hk = pcall(GetPVPSessionStats)
  if ok and type(hk) == "number" and not ns.isSecret(hk) then return hk end
end

local function checkCount(via)
  local hk = sessionKills()
  if not hk then
    -- no readable count: one counter event = one kill
    if via == "kill counter" then
      if credit > 0 then credit = credit - 1 else owed = owed + 1 end
      C_Timer.After(2, settle)
    end
    return
  end
  if sessionHK and hk > sessionHK then
    local d = hk - sessionHK
    K.diag.session = K.diag.session + d
    local use = math.min(credit, d)
    credit, owed = credit - use, owed + (d - use)
    -- give a late honour line a moment to name the kill first
    C_Timer.After(2, settle)
  end
  sessionHK = hk
end

-- an honour line named a kill: it pays for one kill of the count
local namedPost = postKill
postKill = function(victim, via)
  if via == "honour line" then
    if owed > 0 then owed = owed - 1 else credit, creditAt = credit + 1, GetTime() end
  end
  return namedPost(victim, via)
end
K.PostKill = postKill

ns:On("PLAYER_PVP_KILLS_CHANGED", function()
  K.diag.counter = K.diag.counter + 1
  C_Timer.After(0.3, function() checkCount("kill counter") end)
end)

local poll = CreateFrame("Frame")
local acc = 0
poll:SetScript("OnUpdate", function(_, dt)
  acc = acc + dt
  if acc < 3 then return end
  acc = 0
  checkCount("poll")
end)

-- /chill kills: what the kill detection has seen this session
function K:Report()
  local d = self.diag
  ns.Print(("Kill detection this session: honour lines %d (hidden by the game %d), kill counter %d, session count %d, posted %d%s. Honorable kills today: %s.")
    :format(d.honour, d.hidden, d.counter, d.session, d.posted, d.last and (" (last via " .. d.last .. ")") or "",
      tostring(sessionKills() or "?")))
end
