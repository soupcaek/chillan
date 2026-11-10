-- Chillan? – achievements: definisjoner, tellere, evaluering og deling
local ADDON, ns = ...
local A = {}
ns.Ach = A

A.TIERS = {
  B = { name = "Bronze", points = 5, color = "C9946A" },
  S = { name = "Silver", points = 10, color = "C8D1DC" },
  G = { name = "Gold", points = 25, color = "E0C068" },
  L = { name = "Legendary", points = 50, color = "B9AEDB" },
}

A.CATS = {
  { key = "lvl", name = "Leveling" }, { key = "first", name = "First in the gang" },
  { key = "time", name = "Time and sessions" }, { key = "quest", name = "Quests" },
  { key = "gold", name = "Gold" }, { key = "death", name = "Death and shame" },
  { key = "pvp", name = "PvP" }, { key = "gang", name = "The gang" },
  { key = "dung", name = "Dungeons and raids" }, { key = "expl", name = "Exploration" },
  { key = "prof", name = "Professions" }, { key = "gear", name = "Gear and mounts" },
  { key = "tempo", name = "Tempo" }, { key = "fun", name = "Secret" },
}

---------------------------------------------------------------------------
-- Tellere (lagres per konto)
---------------------------------------------------------------------------
local function db() ns.db.cnt = ns.db.cnt or {} return ns.db.cnt end
function ns.Cnt(key, n)
  local c = db()
  c[key] = (c[key] or 0) + (n or 1)
  A:CheckSoon()
end
function ns.CntDay(key, n)
  local c = db()
  local day = date("%Y-%m-%d")
  c[key] = c[key] or {}
  c[key][day] = (c[key][day] or 0) + (n or 1)
  -- behold bare de siste dagene
  local keys = {}
  for k in pairs(c[key]) do keys[#keys + 1] = k end
  if #keys > 10 then
    table.sort(keys)
    for i = 1, #keys - 10 do c[key][keys[i]] = nil end
  end
  A:CheckSoon()
end
function ns.CntMax(key, v)
  local c = db()
  if v and v > (c[key] or 0) then c[key] = v A:CheckSoon() end
end
function ns.CntSet(key, sub)
  local c = db()
  c[key] = c[key] or {}
  if sub and sub ~= "" and not c[key][sub] then
    c[key][sub] = true
    A:CheckSoon()
  end
end
function ns.CntFlag(key)
  local c = db()
  if not c[key] then c[key] = true A:CheckSoon() end
end

local function cnt(k) local v = db()[k] return type(v) == "number" and v or 0 end
local function today(k) local t = db()[k] return type(t) == "table" and (t[date("%Y-%m-%d")] or 0) or 0 end
local function setSize(k)
  local n = 0
  for _ in pairs(db()[k] or {}) do n = n + 1 end
  return n
end
local function has(k) return db()[k] and true or false end
local function inSet(k, name) return (db()[k] or {})[name] and true or false end

local function me() return ns:GetPerson(ns.pid, true) end
local function stat(k) return (me().stats or {})["t" .. k] or 0 end
local function maxLevel() return ns:PersonMaxLevel(me()) end
local function maxPlayed()
  local m = 0
  for _, c in pairs(me().chars) do if (c.played or 0) > m then m = c.played end end
  return m
end
local function prof(name)
  for _, p in ipairs(me().profs or {}) do if p.name == name then return p.skill end end
  return 0
end
local function profsAtLeast(v)
  local n = 0
  for _, p in ipairs(me().profs or {}) do if (p.skill or 0) >= v then n = n + 1 end end
  return n
end
local function first(key)
  local f = ns.db.firsts[key]
  return f and f.pid == ns.pid
end
local function altsOver(lvl)
  local n = 0
  for _, c in pairs(me().chars) do if (c.level or 0) >= lvl then n = n + 1 end end
  return n
end

---------------------------------------------------------------------------
-- Definisjoner: { id, kategori, nivå, navn, beskrivelse, verdi-funksjon, mål, hemmelig }
---------------------------------------------------------------------------
local defs = {}
local function D(id, cat, tier, name, desc, value, goal, secret)
  defs[#defs + 1] = { id = id, cat = cat, tier = tier, name = name, desc = desc, value = value, goal = goal or 1, secret = secret }
end
local function V(fn) return fn end
local function flag(k) return function() return has(k) and 1 or 0 end end

-- Leveling
local L = { {5,"First steps","B"},{10,"Double digits","B"},{15,"Apprentice","B"},{20,"Adventurer","B"},{25,"Veteran in the making","S"},
  {30,"Halfway-ish","S"},{35,"Experienced","S"},{40,"Seasoned","S"},{45,"Hardened","G"},{50,"Almost there","G"},{55,"Final stretch","G"},{60,"Legend","L"} }
for _, l in ipairs(L) do D("L" .. l[1], "lvl", l[3], l[2], "Reach level " .. l[1], maxLevel, l[1]) end
D("LV2S", "lvl", "S", "Double ding", "2 levels in one session", V(function() return cnt("bestSessionLevels") end), 2)
D("LV3S", "lvl", "G", "Ding machine", "3 levels in one session", V(function() return cnt("bestSessionLevels") end), 3)
D("LVNT", "lvl", "S", "Night ding", "Ding between 00:00 and 05:00", flag("dingNight"))
D("LVDG", "lvl", "B", "Ding in the deep", "Ding inside a dungeon", flag("dingDungeon"))
D("LVRS", "lvl", "B", "Well rested", "Ding with rested XP", flag("dingRested"))
D("LVAL", "lvl", "S", "Altoholic", "Have 3 characters above level 10", V(function() return altsOver(10) end), 3)

-- Først i gjengen
for _, n in ipairs({ 10, 20, 30, 40, 50, 60 }) do
  D("F" .. n, "first", n >= 40 and "G" or "S", "First to " .. n, "First in the gang to level " .. n, V(function() return first("L" .. n) and 1 or 0 end))
end
D("FMNT", "first", "G", "First with a mount", "First in the gang with a mount", V(function() return first("MOUNT") and 1 or 0 end))
D("FEPC", "first", "G", "First with an epic", "First in the gang with an epic drop", V(function() return first("EPIC") and 1 or 0 end))

-- Tid og økter
local D1 = 86400
for i, t in ipairs({ {1,"A whole day","B"},{2,"Weekend trip","S"},{5,"Hooked","S"},{10,"No way back","G"},{20,"Lives in Azeroth","L"} }) do
  D("PL" .. t[1], "time", t[3], t[2], "/played " .. t[1] .. (t[1] == 1 and " days" or " days") .. " on one character", maxPlayed, t[1] * D1)
end
D("SE3", "time", "B", "Evening session", "One 3-hour session", V(function() return stat("Longest") end), 3 * 3600)
D("SE6", "time", "S", "Marathon", "One 6-hour session", V(function() return stat("Longest") end), 6 * 3600)
D("SE10", "time", "G", "Ultramarathon", "One 10-hour session", V(function() return stat("Longest") end), 10 * 3600)
D("ST3", "time", "B", "Habit", "3 days in a row", V(function() return ns.Tracker:Streak((me().stats or {}).days) end), 3)
D("ST7", "time", "S", "Weekly rhythm", "7 days in a row", V(function() return ns.Tracker:Streak((me().stats or {}).days) end), 7)
D("ST14", "time", "G", "No breaks", "14 days in a row", V(function() return ns.Tracker:Streak((me().stats or {}).days) end), 14)
D("ST30", "time", "L", "Loyal", "30 days in a row", V(function() return ns.Tracker:Streak((me().stats or {}).days) end), 30)
D("OWL", "time", "S", "Night Owl", "Online at 03:00", flag("online03"))
D("BIRD", "time", "S", "Early Bird", "Online at 06:00", flag("online06"))
D("WKND", "time", "S", "Weekend warrior", "10 hours in one weekend", V(function() return cnt("bestWeekend") end), 10 * 3600)

-- Quests
for _, q in ipairs({ {10,"Errand runner","B"},{50,"Helpful","B"},{100,"Quest Machine","S"},{250,"Tireless","S"},{500,"Workhorse","G"},{1000,"Thanks a thousand","G"},{2000,"Quest god","L"} }) do
  D("Q" .. q[1], "quest", q[3], q[2], q[1] .. " quests total", V(function() return stat("Quests") end), q[1])
end
D("QSES", "quest", "S", "Productive evening", "20 quests in one session", V(function() return cnt("bestSessionQuests") end), 20)
D("QDAY", "quest", "G", "A day's work", "40 quests in one day", V(function() return today("questsDay") > 0 and math.max(today("questsDay"), cnt("bestDayQuests")) or cnt("bestDayQuests") end), 40)
D("QKNG", "quest", "G", "Quest king of the week", "Most quests in the gang in a week", flag("kingQuests"))

-- Gull (kobber)
local G = 10000
for _, g in ipairs({ {10,"Pocket money","B"},{100,"Piggy bank","S"},{500,"Well-off","G"},{1000,"Goblin","L"} }) do
  D("GE" .. g[1], "gold", g[3], g[2], "Earn " .. g[1] .. "g total", V(function() return stat("Gold") end), g[1] * G)
end
for _, g in ipairs({ {50,"Fat wallet","S"},{100,"Rich guy","G"},{500,"Croesus","L"} }) do
  D("GH" .. g[1], "gold", g[3], g[2], "Have " .. g[1] .. "g at once", V(function() return cnt("maxMoney") end), g[1] * G)
end
D("GS10", "gold", "B", "Payday", "Earn 10g in one session", V(function() return cnt("bestSessionGold") end), 10 * G)
D("GS50", "gold", "G", "Gold mine", "Earn 50g in one session", V(function() return cnt("bestSessionGold") end), 50 * G)
D("GKNG", "gold", "G", "Merchant of the week", "Most gold in the gang in a week", flag("kingGold"))

-- Død og skam
D("DE1", "death", "B", "The first time is the worst", "Die for the first time", V(function() return stat("Deaths") end), 1)
D("DE10", "death", "B", "Creature of habit", "10 deaths", V(function() return stat("Deaths") end), 10)
D("DE25", "death", "S", "Clumsy", "25 deaths", V(function() return stat("Deaths") end), 25)
D("DE50", "death", "G", "Spirit Healer regular", "50 deaths", V(function() return stat("Deaths") end), 50)
D("DE100", "death", "L", "Immortal? No.", "100 deaths", V(function() return stat("Deaths") end), 100)
D("DES3", "death", "S", "Bad day", "3 deaths in one session", V(function() return cnt("bestSessionDeaths") end), 3)
D("DED5", "death", "G", "Disaster night", "5 deaths in one day", V(function() return math.max(today("deathsDay"), cnt("bestDayDeaths")) end), 5)
D("DELG", "death", "S", "Cursed", "Die within 2 min of logging in", flag("deathAfterLogin"))
D("DEDG", "death", "S", "Short-lived joy", "Die within 2 min of a ding", flag("deathAfterDing"))
D("DEZ5", "death", "S", "Favourite spot", "Die 5 times in the same zone", V(function() return cnt("maxDeathsZone") end), 5)
D("DESTV", "death", "G", "Stranglethorn tourist", "Die 10 times in Stranglethorn Vale", V(function() return (db().deathsByZone or {})["Stranglethorn Vale"] or 0 end), 10)
D("DEDN", "death", "B", "Dungeon victim", "Die inside a dungeon", flag("deathDungeon"))
D("DE60", "death", "G", "Peak reached", "Die at level 60", flag("deathAt60"))
D("DENO", "death", "S", "Careful soul", "10 levels without dying", V(function() return cnt("bestLevelsNoDeath") end), 10)
D("DEWK", "death", "G", "Infallible", "A whole week (at least 5 h) without dying", flag("weekNoDeath"))
D("DKNG", "death", "S", "King of shame", "Most deaths in the gang in a week", flag("kingDeaths"))

-- PvP
for _, k in ipairs({ {1,"First blood","B"},{10,"Enemy of the Alliance","B"},{50,"Tormentor","S"},{100,"Warmonger","S"},{250,"Butcher","G"},{500,"Horde hero","G"},{1000,"Lok'tar Ogar","L"} }) do
  D("K" .. k[1], "pvp", k[3], k[2], k[1] .. " honorable kills", V(function() return stat("Kills") end), k[1])
end
D("BG1", "pvp", "B", "Victory!", "Win a battleground", V(function() return cnt("bgWins") end), 1)
D("BG10", "pvp", "G", "Warlord", "Win 10 battlegrounds", V(function() return cnt("bgWins") end), 10)
for _, b in ipairs({ {"WSG","Wolf flag","Warsong Gulch"},{"AB","Base builder","Arathi Basin"},{"AV","Mountain general","Alterac Valley"},{"DI","Ruler of the island","Darkspear Islands"} }) do
  D("BG" .. b[1], "pvp", "S", b[2], "Win " .. b[3], V(function() return inSet("bgWonMaps", b[3]) and 1 or 0 end))
end
D("SOS1", "pvp", "B", "Cried for help", "Send your first SOS", V(function() return cnt("sosSent") end), 1)
D("SOSA", "pvp", "B", "Quick help", "Answer «on my way» to an SOS", V(function() return cnt("sosAnswered") end), 1)
D("SOS10", "pvp", "G", "Bodyguard", "Answer 10 SOS calls", V(function() return cnt("sosAnswered") end), 10)

-- Gjengen
D("CH1", "gang", "B", "Hi, gang!", "First message in gang chat", V(function() return cnt("chatMsgs") end), 1)
D("CH100", "gang", "S", "Chatterbox", "100 messages in gang chat", V(function() return cnt("chatMsgs") end), 100)
D("CH1K", "gang", "G", "Talkative", "1000 messages in gang chat", V(function() return cnt("chatMsgs") end), 1000)
D("CHDY", "gang", "S", "Loudmouth", "50 messages in one day", V(function() return math.max(today("chatDay"), cnt("bestDayChat")) end), 50)
D("GG10", "gang", "B", "Cheer Squad", "Give 10 congrats", V(function() return cnt("gratsGiven") end), 10)
D("GG50", "gang", "S", "Supporter", "Give 50 congrats", V(function() return cnt("gratsGiven") end), 50)
D("GG200", "gang", "G", "Gang mom", "Give 200 congrats", V(function() return cnt("gratsGiven") end), 200)
D("GR10", "gang", "S", "Popular", "Get 10 congrats", V(function() return cnt("gratsGot") end), 10)
D("GR50", "gang", "G", "Celebrity", "Get 50 congrats", V(function() return cnt("gratsGot") end), 50)
D("GR5D", "gang", "G", "Life of the party", "Get 5 congrats on one ding", V(function() return cnt("maxGratsOneDing") end), 5)
D("LGH10", "gang", "S", "Schadenfreude", "Laugh at 10 deaths", V(function() return cnt("laughsGiven") end), 10)
D("F10", "gang", "S", "Respect", "Press «F» 10 times", V(function() return cnt("fGiven") end), 10)
D("LGHD", "gang", "G", "Class clown", "Get laughed at 20 times", V(function() return cnt("laughedAt") end), 20)
D("GRP2", "gang", "B", "Duo", "Group with 1 from the gang", V(function() return cnt("maxGangGroup") end), 2)
D("GRP3", "gang", "B", "Trio", "Group with 2 from the gang", V(function() return cnt("maxGangGroup") end), 3)
D("GRP5", "gang", "S", "Full gang", "5-man group with only the gang", V(function() return cnt("maxGangGroup") end), 5)
D("GRP10", "gang", "G", "Raid gang", "Raid with 10 from the gang", V(function() return cnt("maxGangGroup") end), 10)
D("ON8", "gang", "G", "All hands on deck", "8 from the gang online at once", V(function() return cnt("maxOnline") end), 8)
D("POLL", "gang", "B", "Democrat", "Create a poll", V(function() return cnt("pollsCreated") end), 1)
D("VOTE", "gang", "S", "Voter", "Vote in 20 polls", V(function() return cnt("votes") end), 20)
D("EVNT", "gang", "B", "Planner", "Create an event", V(function() return cnt("eventsCreated") end), 1)
D("RSVP", "gang", "S", "Shows up", "Answer «coming» to 10 events", V(function() return cnt("rsvpYes") end), 10)
D("MATS", "gang", "B", "Needs help", "Post a mats request", V(function() return cnt("matsPosted") end), 1)
D("MATO", "gang", "S", "Supplier", "Answer «I have it!» 10 times", V(function() return cnt("matsOffered") end), 10)

-- Dungeons og raid
D("DG1", "dung", "B", "Into the dark", "First dungeon", V(function() return cnt("dungeonRuns") end), 1)
D("DG5", "dung", "B", "Dungeon crawler", "5 dungeon runs", V(function() return cnt("dungeonRuns") end), 5)
D("DG10", "dung", "S", "Cave dweller", "10 dungeon runs", V(function() return cnt("dungeonRuns") end), 10)
D("DG25", "dung", "G", "Deep diver", "25 dungeon runs", V(function() return cnt("dungeonRuns") end), 25)
D("DG50", "dung", "L", "Dedicated", "50 dungeon runs", V(function() return cnt("dungeonRuns") end), 50)
D("DGU5", "dung", "S", "Five in a row", "5 different dungeons", V(function() return setSize("dungeonsSeen") end), 5)
D("DGU10", "dung", "G", "Collector", "10 different dungeons", V(function() return setSize("dungeonsSeen") end), 10)
D("RD1", "dung", "S", "Raid debut", "First raid", V(function() return setSize("raidsSeen") end), 1)
D("RDBD", "dung", "G", "Barrow Deeps", "Enter the Barrow Deeps", V(function() return inSet("raidsSeen", "Barrow Deeps") and 1 or 0 end))
D("RDHS", "dung", "L", "Hyjal Summit", "Enter Hyjal Summit", V(function() return inSet("raidsSeen", "Hyjal Summit") and 1 or 0 end))
D("DGGG", "dung", "G", "Gang outing", "A dungeon where all five are from the gang", flag("gangDungeon"))
D("DGD2", "dung", "S", "Double dose", "2 dungeons in one evening", V(function() return math.max(today("dungeonsDay"), cnt("bestDayDungeons")) end), 2)

-- Utforsking
D("Z10", "expl", "B", "Tourist", "Visit 10 zones", V(function() return setSize("zonesSeen") end), 10)
D("Z20", "expl", "S", "Traveller", "Visit 20 zones", V(function() return setSize("zonesSeen") end), 20)
D("Z30", "expl", "G", "Explorer", "Visit 30 zones", V(function() return setSize("zonesSeen") end), 30)
D("Z40", "expl", "L", "Cartographer", "Visit 40 zones", V(function() return setSize("zonesSeen") end), 40)
D("ZCAP", "expl", "S", "At home in every city", "Visit Orgrimmar, Thunder Bluff and Undercity", V(function()
  local n = 0
  for _, z in ipairs({ "Orgrimmar", "Thunder Bluff", "Undercity" }) do if inSet("zonesSeen", z) then n = n + 1 end end
  return n
end), 3)
D("ZBB", "expl", "B", "Pirate harbour", "Visit Booty Bay", V(function() return inSet("subzonesSeen", "Booty Bay") and 1 or 0 end))
D("ZGZ", "expl", "B", "Desert rat", "Visit Gadgetzan", V(function() return inSet("subzonesSeen", "Gadgetzan") and 1 or 0 end))
D("ZEL", "expl", "S", "Frostbitten", "Visit Everlook", V(function() return inSet("subzonesSeen", "Everlook") and 1 or 0 end))
D("Z10H", "expl", "S", "Regular", "10 hours in the same zone", V(function()
  local m = 0
  for _, v in pairs((me().stats or {}).zones or {}) do if v > m then m = v end end
  return m
end), 10 * 3600)
D("LAYR", "expl", "S", "Layer hopper", "Change zone or layer 100 times", V(function() return cnt("zoneChanges") end), 100)

-- Profesjoner
D("P75", "prof", "B", "Apprentice", "One profession at 75", V(function() return profsAtLeast(75) end), 1)
D("P150", "prof", "B", "Journeyman", "One profession at 150", V(function() return profsAtLeast(150) end), 1)
D("P225", "prof", "S", "Expert", "One profession at 225", V(function() return profsAtLeast(225) end), 1)
D("P300", "prof", "G", "Master", "One profession at 300", V(function() return profsAtLeast(300) end), 1)
D("P300X2", "prof", "L", "Double master", "Two professions at 300", V(function() return profsAtLeast(300) end), 2)
D("PCOOK", "prof", "S", "Master chef", "Cooking 300", V(function() return prof("Cooking") end), 300)
D("PFISH", "prof", "S", "Fishing hero", "Fishing 300", V(function() return prof("Fishing") end), 300)
D("PFA", "prof", "S", "Doctor", "First Aid 300", V(function() return prof("First Aid") end), 300)
D("PWK50", "prof", "S", "Diligent", "+50 skill in a profession in one week", V(function()
  local m = 0
  for _, p in ipairs(me().profs or {}) do if p.base and (p.skill - p.base) > m then m = p.skill - p.base end end
  return m
end), 50)

-- Utstyr og mounts
D("EP1", "gear", "S", "Purple joy", "First epic drop", V(function() return cnt("epics") end), 1)
D("EP5", "gear", "G", "Epic collector", "5 epic drops", V(function() return cnt("epics") end), 5)
D("EP15", "gear", "L", "Gear freak", "15 epic drops", V(function() return cnt("epics") end), 15)
for _, i in ipairs({ {20,"Well dressed","B"},{40,"Well equipped","S"},{55,"Heavily armed","G"},{65,"Raid ready","L"} }) do
  D("IL" .. i[1], "gear", i[3], i[2], "Item level " .. i[1], V(function() return cnt("maxIlvl") end), i[1])
end
D("MT1", "gear", "S", "Four legs", "First mount", V(function() return cnt("mounts") end), 1)
D("MT3", "gear", "G", "Stable boy", "3 mounts", V(function() return cnt("mounts") end), 3)
D("MT5", "gear", "L", "Horseman", "5 mounts", V(function() return cnt("mounts") end), 5)
D("MTE", "gear", "G", "Rider", "Get a mount before level 40", flag("mountBefore40"))

-- Tempo
D("XP10", "tempo", "B", "Speed", "10,000 XP per hour in one session", V(function() return cnt("bestXPRate") end), 10000)
D("XP25", "tempo", "S", "Turbo", "25,000 XP per hour in one session", V(function() return cnt("bestXPRate") end), 25000)
D("XP50", "tempo", "G", "Light speed", "50,000 XP per hour in one session", V(function() return cnt("bestXPRate") end), 50000)
D("LFST", "tempo", "S", "Lightning ding", "A level in under 30 min played", flag("fastLevel"))
D("SPRN", "tempo", "G", "Speedrunner", "Fastest ding in the gang (all time)", flag("fastestInGang"))
D("EFF", "tempo", "L", "Efficient", "Level 60 in under 10 days /played", flag("efficient60"))
D("SNAIL", "tempo", "B", "Snail", "A level that takes over 5 hours played", flag("slowLevel"))

-- Hemmelige / morsomme
D("BACK", "fun", "S", "Welcome back!", "Log in after 7+ days away", flag("comeback"), 1, true)
D("LONE", "fun", "S", "Lone wolf", "3 hours without anyone from the gang online", V(function() return cnt("bestLone") end), 3 * 3600, true)
D("AFK", "fun", "B", "AFK-mester", "Stand AFK for 30 minutes", flag("afk30"), 1, true)
D("WIN1", "fun", "G", "Winner of the week", "Win the weekly challenge", V(function() return cnt("challengeWins") end), 1, true)
D("WIN5", "fun", "L", "Champion", "Win the weekly challenge 5 times", V(function() return cnt("challengeWins") end), 5, true)
D("SOS3", "fun", "S", "Spammer", "Send 3 SOS in one day", V(function() return math.max(today("sosDay"), cnt("bestDaySos")) end), 3, true)
D("ENM10", "fun", "S", "Enemy hunter", "Tag 10 enemies", V(function() return cnt("enemiesTagged") end), 10, true)
D("ENSN", "fun", "B", "I see you!", "Get an enemy alert", V(function() return cnt("enemySeen") end), 1, true)
D("ALL100", "fun", "L", "Completionist", "Unlock 100 achievements", V(function() return A:Count(ns.pid) end), 100, true)

A.defs = defs
A.byId = {}
for i, d in ipairs(defs) do d.order = i A.byId[d.id] = d end

---------------------------------------------------------------------------
-- Evaluering
---------------------------------------------------------------------------
function A:Mine() ns.db.ach = ns.db.ach or {} return ns.db.ach end

function A:Has(pid, id)
  if pid == ns.pid then return self:Mine()[id] end
  local p = ns:GetPerson(pid)
  return p and p.ach and p.ach[id]
end

function A:Count(pid)
  local n = 0
  local list = pid == ns.pid and self:Mine() or ((ns:GetPerson(pid) or {}).ach or {})
  for id in pairs(list) do if self.byId[id] then n = n + 1 end end
  return n
end

function A:Points(pid)
  local sum = 0
  local list = pid == ns.pid and self:Mine() or ((ns:GetPerson(pid) or {}).ach or {})
  for id in pairs(list) do
    local d = self.byId[id]
    if d then sum = sum + self.TIERS[d.tier].points end
  end
  return sum
end

function A:Progress(d)
  local ok, v = pcall(d.value)
  if not ok or type(v) ~= "number" then v = 0 end
  return v, d.goal
end

local checkPending = false
function A:CheckSoon()
  if checkPending or not ns.db then return end
  checkPending = true
  C_Timer.After(2, function()
    checkPending = false
    A:Check()
  end)
end

function A:Check()
  if not ns.db or not ns.db.people[ns.pid] then return end
  local mine = self:Mine()
  -- første gang noensinne: tildel det som allerede er oppnådd, uten popups
  local silent = not ns.db.achInit
  local newOnes = {}
  for _, d in ipairs(defs) do
    if not mine[d.id] then
      local v, goal = self:Progress(d)
      if v >= goal then
        mine[d.id] = ns.Now()
        newOnes[#newOnes + 1] = d
      end
    end
  end
  ns.db.achInit = true
  if #newOnes == 0 then return end
  if silent then
    self:SendList()
  else
    for _, d in ipairs(newOnes) do
      ns.Tracker:Event("ACH", d.id, d.tier)
      -- sølv/gull/legendarisk får den store popupen; bronse bare et lite varsel (ikke begge)
      if d.tier == "B" then
        ns:Fire("TOAST", { kind = "trophy", sticky = false,
          title = "Achievement: " .. d.name, text = d.desc .. " · " .. self.TIERS[d.tier].name .. " (" .. self.TIERS[d.tier].points .. " p)" })
      end
    end
  end
  ns:MarkDirty()
end

-- Del hele lista (stille) med gjengen
function A:SendList(target)
  if not ns.codeHash then return end
  local ids = {}
  for id in pairs(self:Mine()) do if self.byId[id] then ids[#ids + 1] = id end end
  table.sort(ids)
  local chunk, part, total = {}, 1, math.max(1, math.ceil(#ids / 30))
  if #ids == 0 then return end
  for i, id in ipairs(ids) do
    chunk[#chunk + 1] = id
    if #chunk == 30 or i == #ids then
      local msg = ns.Comm:Build("AL", ns.pid, part, total, table.concat(chunk, ","))
      if target then ns.Comm:SendTo(target, msg, 3) else ns.Comm:Broadcast(msg, 3) end
      chunk, part = {}, part + 1
    end
  end
end

ns.Comm:Handle("AL", function(f)
  local pid = f[1]
  if not pid or pid == ns.pid then return end
  local p = ns:GetPerson(pid, true)
  p.ach = p.ach or {}
  for _, id in ipairs(ns.Split(f[4] or "", ",")) do
    if id ~= "" and not p.ach[id] then p.ach[id] = true end
  end
  ns:MarkDirty()
end)

---------------------------------------------------------------------------
-- Hendelser som ikke fanges andre steder
---------------------------------------------------------------------------
local afkSince, loneThisSession = nil, 0
local function dgState()
  ns.db.dgState = ns.db.dgState or {}
  local me = ns.Comm:MyFull()
  ns.db.dgState[me] = ns.db.dgState[me] or {}
  return ns.db.dgState[me]
end
-- while inside, keep "last seen in this dungeon" fresh, so a long run + /reload still counts once
local function touchDungeon()
  local inInst, kind = ns.S(IsInInstance)
  if inInst and kind == "party" then
    local name = ns.S(GetInstanceInfo)
    local st = dgState()
    if name and name == st.name then st.at = ns.Now() end
  end
end
C_Timer.NewTicker(60, touchDungeon)
ns:On("PLAYER_LOGOUT", touchDungeon)

function A:Tick(dt)
  local h = tonumber(date("%H"))
  if h == 3 then ns.CntFlag("online03") end
  if h == 6 then ns.CntFlag("online06") end
  -- helg: lørdag + søndag samme helg
  local wday = tonumber(date("%w"))
  local days = (me().stats or {}).days or {}
  if wday == 6 or wday == 0 then
    local sat = wday == 6 and ns.Now() or (ns.Now() - 86400)
    local total = (days[date("%Y-%m-%d", sat)] or 0) + (days[date("%Y-%m-%d", sat + 86400)] or 0)
    ns.CntMax("bestWeekend", total)
  end
  -- AFK
  if ns.S(UnitIsAFK, "player") then
    afkSince = afkSince or ns.Now()
    if ns.Now() - afkSince >= 1800 then ns.CntFlag("afk30") end
  else
    afkSince = nil
  end
  -- ensom ulv / hvor mange online
  local online = 0
  for pid, p in pairs(ns.db.people) do
    if pid ~= ns.pid and p.main and ns:IsOnline(p) then online = online + 1 end
  end
  ns.CntMax("maxOnline", online + 1)
  if online == 0 then
    loneThisSession = loneThisSession + dt
    ns.CntMax("bestLone", loneThisSession)
  end
  -- økt-rekorder
  local s = ns.session
  ns.CntMax("bestSessionLevels", s.levels or 0)
  ns.CntMax("bestSessionQuests", s.quests or 0)
  ns.CntMax("bestSessionGold", s.gold or 0)
  ns.CntMax("bestSessionDeaths", s.deaths or 0)
  local m = ns.S(GetMoney)
  if m then ns.CntMax("maxMoney", m) end
  local il = ns.Tracker:ItemLevel()
  if il then ns.CntMax("maxIlvl", il) end
  local sessSec = ns.Now() - (s.start or ns.Now())
  if sessSec >= 1200 and (s.xp or 0) > 0 then ns.CntMax("bestXPRate", math.floor(s.xp / sessSec * 3600)) end
  -- tempo fra levelhistorikk
  local times = ns.St:LevelTimes(me())
  for _, t in ipairs(times) do
    if t.secs < 1800 then ns.CntFlag("fastLevel") end
    if t.secs > 18000 then ns.CntFlag("slowLevel") end
  end
  if maxLevel() >= 60 and maxPlayed() > 0 and maxPlayed() < 10 * 86400 then ns.CntFlag("efficient60") end
  -- raskeste ding i hele gjengen
  local myBest
  for _, t in ipairs(times) do if not myBest or t.secs < myBest then myBest = t.secs end end
  if myBest then
    local beaten = false
    for pid, p in pairs(ns.db.people) do
      if pid ~= ns.pid then
        for _, t in ipairs(ns.St:LevelTimes(p)) do if t.secs < myBest then beaten = true break end end
      end
      if beaten then break end
    end
    if not beaten and ns:PersonMaxLevel(me()) >= 10 then ns.CntFlag("fastestInGang") end
  end
  self:Check()
end

-- Ukens konger og vinner (sjekkes etter innlogging, når data om forrige uke er synket)
function A:CheckWeekKings()
  local pwk = ns.PrevWeekKey()
  -- same rules as the weekly titles: a minimum to count, ties go to the lowest id (same on every client)
  local function best(key, min)
    local bp, bv = nil, 0
    for pid, p in pairs(ns.db.people) do
      local s = p.stats or {}
      local v = 0
      if s.prev and s.prev.wk == pwk then v = s.prev[key] or 0 elseif s.wk == pwk then v = s["w" .. key] or 0 end
      if v > bv or (v == bv and v > 0 and bp and pid < bp) then bp, bv = pid, v end
    end
    if bv <= (min or 0) then return nil end
    return bp
  end
  if best("Quests", 3) == ns.pid then ns.CntFlag("kingQuests") end
  if best("Gold", 10000) == ns.pid then ns.CntFlag("kingGold") end
  if best("Deaths", 2) == ns.pid then ns.CntFlag("kingDeaths") end
  local s = me().stats or {}
  if s.prev and s.prev.wk == pwk and (s.prev.Deaths or 0) == 0 and (s.prev.Online or 0) >= 5 * 3600 then
    ns.CntFlag("weekNoDeath")
  end
  local ch, winner = ns.Data:LastWeekWinner()
  ns.db.cnt.winsCounted = ns.db.cnt.winsCounted or {}
  if winner and winner.pid == ns.pid and not ns.db.cnt.winsCounted[pwk] then
    ns.db.cnt.winsCounted[pwk] = true
    ns.Cnt("challengeWins")
  end
end

-- Dungeons, raid, soner og battlegrounds
local function onWorld()
  local inInst, kind = ns.S(IsInInstance)
  local zone = ns.S(GetRealZoneText)
  if zone and zone ~= "" and not inInst then ns.CntSet("zonesSeen", zone) end
  if inInst then
    local name = ns.S(GetInstanceInfo)
    if name and name ~= "" then
      if kind == "party" then
        ns.CntSet("dungeonsSeen", name)
        -- the last dungeon is saved (per character), so /reload or a disconnect inside
        -- the same dungeon doesn't count as a new run
        local st = dgState()
        if name ~= st.name or (ns.Now() - (st.at or 0)) > 1800 then
          ns.Cnt("dungeonRuns")
          ns.CntDay("dungeonsDay")
          ns.CntMax("bestDayDungeons", (db().dungeonsDay or {})[date("%Y-%m-%d")] or 0)
        end
        st.name, st.at = name, ns.Now()
      elseif kind == "raid" then
        ns.CntSet("raidsSeen", name)
      end
    end
  end
end
ns:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(3, onWorld) end)
ns:On("ZONE_CHANGED_NEW_AREA", function()
  ns.Cnt("zoneChanges")
  C_Timer.After(1, onWorld)
end)
ns:On("ZONE_CHANGED", function()
  local sub = ns.S(GetSubZoneText)
  if sub and sub ~= "" then ns.CntSet("subzonesSeen", sub) end
end)

ns:On("PVP_MATCH_COMPLETE", function(winner)
  if winner == nil or ns.isSecret(winner) then return end
  -- 0 = Horde, 1 = Alliance
  local faction = ns.S(UnitFactionGroup, "player")
  local mine = (faction == "Horde") and 0 or 1
  if winner == mine then
    ns.Cnt("bgWins")
    local map = ns.S(GetInstanceInfo)
    if map then ns.CntSet("bgWonMaps", map) end
  end
end)

-- Gruppe med folk fra gjengen
local function gangNames()
  local set = {}
  for char, r in pairs(ns.db.roster) do
    if r.pid then set[ns.ShortName(char):lower()] = true end
  end
  for pid, p in pairs(ns.db.people) do
    for full, c in pairs(p.chars or {}) do set[ns.ShortName(full):lower()] = true if c.name then set[c.name:lower()] = true end end
  end
  return set
end
ns:On("GROUP_ROSTER_UPDATE", function()
  local n = ns.S(GetNumGroupMembers) or 0
  if n < 2 then return end
  local set = gangNames()
  local raid = ns.S(IsInRaid)
  local count = 0
  for i = 1, n do
    local unit = raid and ("raid" .. i) or (i == n and "player" or ("party" .. i))
    local name = ns.S(UnitName, unit)
    if name and set[name:lower()] then count = count + 1 end
  end
  if not raid then count = count + 0 end
  ns.CntMax("maxGangGroup", count)
  local inInst, kind = ns.S(IsInInstance)
  if inInst and kind == "party" and n == 5 and count >= 5 then ns.CntFlag("gangDungeon") end
end)

function A:Start()
  -- «Kom tilbake!»: mer enn 7 dager siden forrige økt
  if ns.db.lastActive and (ns.Now() - ns.db.lastActive) > 7 * 86400 then ns.CntFlag("comeback") end
  C_Timer.NewTicker(15, function()
    ns.db.lastActive = ns.Now()
    A:Tick(15)
  end)
  C_Timer.After(10, function() A:Check() end)
  C_Timer.After(85, function() A:CheckWeekKings() end)
end
