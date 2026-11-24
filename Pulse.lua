-- Chillan? – Gang pulse data (1.1.0): which mode you're in (open world, dungeon, battleground) and
-- the numbers each mode shows: gold/h and session counts, the dungeon run (XP, loot), the
-- battleground (honor, kills, wins today), and "Died to" players near you.
local ADDON, ns = ...
local P = {}
ns.Pulse = P

local MODES = { world = "Open world", dungeon = "Dungeon", raid = "Raid", bg = "Battleground" }
P.MODES = MODES

local function now() return ns.Now() end
local function money() local m = ns.S(GetMoney) return type(m) == "number" and m or nil end

---------------------------------------------------------------------------
-- Mode
---------------------------------------------------------------------------
function P:Detect()
  local inInst, kind = ns.S(IsInInstance)
  if inInst and (kind == "pvp" or kind == "arena") then return "bg" end
  if ns.InBattleground and ns.InBattleground() then return "bg" end
  if inInst and kind == "raid" then return "raid" end
  if inInst and kind == "party" then return "dungeon" end
  return "world"
end

function P:Mode()
  local lock = ns.db and ns.db.settings.pulseMode
  if lock and MODES[lock] then return lock end
  return self.mode or "world"
end

-- the label in the bar: the dungeon or battleground's name, else the zone
function P:Place()
  if self:Mode() ~= "world" then
    local name = ns.S(GetInstanceInfo)
    if type(name) == "string" and name ~= "" then return name end
    return MODES[self:Mode()]
  end
  local z = ns.S(GetRealZoneText)
  return (type(z) == "string" and z ~= "") and z or MODES.world
end

local function setMode()
  local m = P:Detect()
  if m ~= P.mode then
    local old = P.mode
    P.mode = m
    if m == "bg" then P:StartBG() end
    if old == "bg" then P:EndBG() end
    ns:Fire("PULSE_MODE", m, old)
  end
  ns:Fire("PULSE")
end
ns:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, setMode) end)
ns:On("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(1, setMode) end)

---------------------------------------------------------------------------
-- Session (open world): gold/h, quests and mobs since you logged in
---------------------------------------------------------------------------
P.sess = { start = nil, money0 = nil, quests = 0, mobs = 0 }

-- (1.1.4) a /reload or a quick relog (under 15 min) carries on the same session, so gold/h and the
-- session counts don't start over; a real break starts a new one
function P:StartSession()
  local me = ns.Comm and ns.Comm.MyFull and ns.Comm:MyFull() or "?"
  local saved = ns.db.pulseSess
  if saved and saved.char == me and saved.start and (now() - (saved.seen or 0)) < 900 then
    self.sess = saved
  else
    self.sess = { start = now(), money0 = money(), quests = 0, mobs = 0, char = me }
  end
  self.sess.seen = now()
  ns.db.pulseSess = self.sess
end
C_Timer.NewTicker(30, function() if P.sess and P.sess.start then P.sess.seen = now() end end)
ns:On("PLAYER_LOGOUT", function() if P.sess and P.sess.start then P.sess.seen = now() end end)

function P:GoldPerHour()
  local s = self.sess
  if not s.start then return nil end
  local hours = (now() - s.start) / 3600
  if hours < 5 / 60 then return nil end   -- too early to say
  -- (1.4.17) only gold that came in (loot, quests, sales); buying things doesn't count against it
  return math.floor((s.earned or 0) / hours)
end

function P:SessionGold()
  local m = money()
  if not self.sess.money0 or not m then return nil end
  return m - self.sess.money0
end

-- roughly how many quests to the next level, from the XP of your last ten hand-ins
function P:QuestsLeft()
  local d = ns.Tracker:S3Data() or {}
  local h = ns.db.qolQuestXP or {}
  if #h < 3 or not d.xp or not d.xpMax then return nil end
  local sum = 0
  for _, x in ipairs(h) do sum = sum + x end
  local avg = sum / #h
  if avg <= 0 then return nil end
  return math.ceil((d.xpMax - d.xp) / avg)
end

local xpPattern
local function buildPattern()
  local fmt = COMBATLOG_XPGAIN_FIRSTPERSON or "%s dies, you gain %d experience."
  fmt = fmt:gsub("%%s", "@S@"):gsub("%%d", "@D@")
  fmt = fmt:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  fmt = fmt:gsub("@S@", "(.+)"):gsub("@D@", "(%%d+)")
  xpPattern = "^" .. fmt
end
ns:On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
  if type(msg) ~= "string" or ns.isSecret(msg) then return end
  if not xpPattern then buildPattern() end
  if msg:match(xpPattern) then P.sess.mobs = P.sess.mobs + 1 end
end)
ns:On("QUEST_TURNED_IN", function() P.sess.quests = P.sess.quests + 1 end)

---------------------------------------------------------------------------
-- Dungeon run: the run itself (time, bosses, deaths) comes from Extras; here XP and loot
---------------------------------------------------------------------------
P.run = nil
function P:Run()
  local r = ns.Extras and ns.Extras.CurrentRun and ns.Extras:CurrentRun()
  if not r then return nil, nil end
  if not self.run or self.run.key ~= r.start then
    local saved = ns.db.pulseRun
    if saved and saved.key == r.start then self.run = saved
    else self.run = { key = r.start, xp = 0, money = 0, items = {}, grey = 0 } end
    ns.db.pulseRun = self.run
  end
  return r, self.run
end

local lastXP, lastMax, lastMoney
ns:On("PLAYER_XP_UPDATE", function()
  local xp, mx = ns.S(UnitXP, "player"), ns.S(UnitXPMax, "player")
  if type(xp) ~= "number" or type(mx) ~= "number" then return end
  if lastXP and (P:Mode() == "dungeon" or P:Mode() == "raid") then
    local _, pr = P:Run()
    if pr then
      local gain = (xp >= lastXP) and (xp - lastXP) or ((lastMax or 0) - lastXP + xp)
      if gain > 0 then pr.xp = pr.xp + gain end
    end
  end
  lastXP, lastMax = xp, mx
  -- (1.4.0) about to ding: the gang gets a line so they can be ready to react
  local lvl = ns.S(UnitLevel, "player")
  if type(lvl) == "number" and lvl > 1 and lvl < 60 and mx > 0 and xp / mx >= 0.98 then
    ns.db.nearDing = ns.db.nearDing or {}
    local me = ns.Comm and ns.Comm:MyFull() or "?"
    if ns.db.nearDing[me] ~= lvl then
      ns.db.nearDing[me] = lvl
      ns.Tracker:Event("NEARDING", lvl + 1, math.max(1, math.floor((mx - xp) / mx * 100 + 0.5)))
    end
  end
end)
ns:On("PLAYER_MONEY", function()
  local m = money()
  if not m then return end
  if lastMoney and m > lastMoney and (P:Mode() == "dungeon" or P:Mode() == "raid") and not (MerchantFrame and MerchantFrame:IsShown()) then
    local _, pr = P:Run()
    if pr then pr.money = pr.money + (m - lastMoney) end
  end
  -- (1.4.17) gold/h counts what came in, not what you spent (a vendor trip made it go negative)
  if lastMoney and m > lastMoney and P.sess and P.sess.start then
    P.sess.earned = (P.sess.earned or 0) + (m - lastMoney)
  end
  P.GoldDay()
  lastMoney = m
end)

local lootPatterns
local function buildLoot()
  lootPatterns = {}
  for _, fmt in ipairs({ LOOT_ITEM_SELF_MULTIPLE or "You receive loot: %sx%d.", LOOT_ITEM_SELF or "You receive loot: %s." }) do
    local f = fmt:gsub("%%s", "@S@"):gsub("%%d", "@D@")
    f = f:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    f = f:gsub("@S@", "(.+)"):gsub("@D@", "%%d+")
    lootPatterns[#lootPatterns + 1] = "^" .. f
  end
end
-- item quality from the link's colour
local QCOL = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5 }
function P.LinkQuality(link)
  local hexc = type(link) == "string" and link:match("|c%x%x(%x%x%x%x%x%x)")
  return hexc and QCOL[hexc:lower()] or 1
end
-- (1.4.0) what the loot is worth: the Market price (or what a vendor pays) plus the gold looted
local function itemId(link) return tonumber(tostring(link or ""):match("item:(%d+)")) end
local function sellPrice(id)
  local info = C_Item and C_Item.GetItemInfo or GetItemInfo
  if not info then return 0 end
  local ok, _, _, _, _, _, _, _, _, _, _, price = pcall(info, id)
  return (ok and type(price) == "number") and price or 0
end
function P.ItemValue(link)
  local id = itemId(link)
  if not id then return 0 end
  local count = tonumber(tostring(link):match("x(%d+)$")) or 1
  local e = ns.Market and ns.Market:Get(id)
  local q = P.LinkQuality(link)
  if e and e.v and q > 0 then return e.v * count end
  return sellPrice(id) * count
end
function P:LootValue(pr)
  if not pr then return 0 end
  local v = pr.money or 0
  for _, link in ipairs(pr.items or {}) do v = v + P.ItemValue(link) end
  return v + (pr.greyValue or 0)
end

-- gathering this session: herbs, ore and stone, leather (class 7 = trade goods)
local GATHER = { [9] = true, [7] = true, [6] = true }
P.gather = { n = 0, value = 0 }
-- (1.4.17) only loot that follows your own gathering counts (a quest reward of ore isn't "gathered").
-- Base spell IDs; ranks and newer IDs are matched by the spell's name.
local GATHER_SPELLS = { 2575, 2366, 8613 }   -- Mining, Herb Gathering, Skinning
local gatherNames, gatherUntil = nil, 0
local function spellName(id)
  if C_Spell and C_Spell.GetSpellName then local ok, n = pcall(C_Spell.GetSpellName, id) if ok then return n end end
  if GetSpellInfo then local ok, n = pcall(GetSpellInfo, id) if ok then return n end end
end
local GATHER_IDS = { [2575] = 1, [2576] = 1, [3564] = 1, [10248] = 1, [2366] = 1, [2368] = 1, [3570] = 1,
  [11993] = 1, [8613] = 1, [8617] = 1, [8618] = 1, [10768] = 1, [32640] = 1, [265837] = 1, [265819] = 1, [265856] = 1 }
function P.IsGatherSpell(id)
  if type(id) ~= "number" or ns.isSecret(id) then return false end
  if GATHER_IDS[id] then return true end
  if not gatherNames then
    gatherNames = {}
    for i = 1, 3 do local n = spellName(GATHER_SPELLS[i]) if type(n) == "string" then gatherNames[n] = true end end
  end
  local n = spellName(id)
  return type(n) == "string" and not ns.isSecret(n) and gatherNames[n] == true
end
ns:On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
  if unit == "player" and P.IsGatherSpell(spellID) then gatherUntil = GetTime() + 8 end
end)
-- the loot window from a node stays open while you take the items; keep the window open with it
ns:On("LOOT_OPENED", function() if GetTime() < gatherUntil then gatherUntil = GetTime() + 8 end end)
function P.Gathering() return GetTime() < gatherUntil end
local function gathered(link, count)
  if P:Mode() ~= "world" then return end
  if not P.Gathering() then return end
  local id = itemId(link)
  if not id or not C_Item or not C_Item.GetItemInfoInstant then return end
  local ok, _, _, _, _, _, classID, subID = pcall(C_Item.GetItemInfoInstant, id)
  if not ok or classID ~= 7 or not GATHER[subID] then return end
  local g = P.sess.gather or { n = 0, value = 0 }
  P.sess.gather = g
  g.n = g.n + (count or 1)
  local e = ns.Market and ns.Market:Get(id)
  g.value = g.value + ((e and e.v) or sellPrice(id)) * (count or 1)
end

ns:On("CHAT_MSG_LOOT", function(msg)
  if type(msg) ~= "string" or ns.isSecret(msg) then return end
  if P:Mode() == "world" then
    if not lootPatterns then buildLoot() end
    for _, pat in ipairs(lootPatterns) do
      local link = msg:match(pat)
      if link then
        gathered(link, tonumber(msg:match("x(%d+)%.?$")) or 1)
        break
      end
    end
    return
  end
  if P:Mode() ~= "dungeon" and P:Mode() ~= "raid" then return end
  if not lootPatterns then buildLoot() end
  local link
  for _, pat in ipairs(lootPatterns) do link = msg:match(pat) if link then break end end
  if not link then return end
  local _, pr = P:Run()
  if not pr then return end
  if P.LinkQuality(link) == 0 then
    pr.grey = pr.grey + 1
    pr.greyValue = (pr.greyValue or 0) + P.ItemValue(link)
  else
    pr.items[#pr.items + 1] = link
    while #pr.items > 30 do table.remove(pr.items, 1) end
  end
  ns:Fire("PULSE")
end)

---------------------------------------------------------------------------
-- Battleground: honor, kills and deaths this match, wins today
---------------------------------------------------------------------------
local function pvpSession()
  if not GetPVPSessionStats then return nil, nil end
  local ok, hk, honor = pcall(GetPVPSessionStats)
  if not ok then return nil, nil end
  hk = (type(hk) == "number" and not ns.isSecret(hk)) and hk or nil
  honor = (type(honor) == "number" and not ns.isSecret(honor)) and honor or nil
  return hk, honor
end

local function today()
  local d = ns.db.bgDay
  if not d or d.day ~= date("%Y-%m-%d") then
    d = { day = date("%Y-%m-%d"), played = 0, won = 0, honor = 0 }
    ns.db.bgDay = d
  end
  return d
end
P.Today = today
-- (1.4.43) repair: entering (and re-entering after a /reload) was counted as a game. Today's played
-- becomes the games recorded today with a result, never fewer than the wins
ns:On("PLAYER_LOGIN", function()
  if ns.db.bgDayFixed143 then return end
  ns.db.bgDayFixed143 = true
  local d = today()
  local from = time({ year = tonumber(date("%Y")), month = tonumber(date("%m")), day = tonumber(date("%d")), hour = 0 })
  local n = 0
  for _, g in ipairs(ns.db.bgGames or {}) do if (g.t or 0) >= from then n = n + 1 end end
  d.played = math.max(d.won or 0, n)
end)

function P:StartBG()
  local name = ns.S(GetInstanceInfo)
  -- (1.4.43) a /reload inside the battleground, or the game briefly saying we left it, carries on the
  -- same game instead of starting (and counting) a new one
  local saved = ns.db.bgNow
  if saved and saved.name == name and now() - (saved.seen or 0) < 300 then
    self.bg = saved
    saved.seen = now()
    return
  end
  local hk, honor = pvpSession()
  self.bg = { start = now(), hk0 = hk, honor0 = honor, deaths = 0, streak = 0, best = 0, done = false,
    name = name, flags = {}, revs = {}, seen = now() }
  ns.db.bgNow = self.bg
  -- (1.4.43) a game is counted as played when it ends with a result (see the winner), not on entering
  -- (1.4.34) the battleground's reputation: where we start, to count this game's gain
  local fid = P.BGFaction()
  if fid then
    local r = P.RepOf(fid)
    if r then self.bg.repFid, self.bg.rep0 = fid, r.value end
  end
end

function P:EndBG()
  local b = self.bg
  if not b then return end
  -- (1.4.43) no result yet: we may be back in a moment (a /reload, a flicker) – keep it for 5 minutes
  if b.won == nil then
    b.seen = now()
    self.bg = nil
    return
  end
  ns.db.bgNow = nil
  P.NoteBGRep(b)
  local _, honor = self:BGNumbers()
  -- (1.4.37) the session count can stay at 0: use the honor messages, or the scoreboard
  if (not honor or honor == 0) and (b.honorChat or 0) > 0 then honor = b.honorChat end
  if (not honor or honor == 0) and b.me and (b.me.honor or 0) > 0 then honor = b.me.honor end
  if honor then today().honor = today().honor + honor end
  P.RecordGame(b, honor)
  self.bg = nil
end

-- kills (honorable kills) and honor this match, or nil when the game doesn't say
function P:BGNumbers()
  local b = self.bg
  if not b then return nil, nil end
  local hk, honor = pvpSession()
  local kills = (hk and b.hk0) and math.max(0, hk - b.hk0) or nil
  local hon = (honor and b.honor0) and math.max(0, honor - b.honor0) or nil
  if (not hon or hon == 0) and (b.honorChat or 0) > 0 then hon = b.honorChat end
  return kills, hon
end

function P:HonorPerHour()
  local b = self.bg
  local _, hon = self:BGNumbers()
  if not b or not hon then return nil end
  local hours = (now() - b.start) / 3600
  if hours < 2 / 60 then return nil end
  return math.floor(hon / hours)
end

ns:On("PLAYER_DEAD", function()
  if P.bg then P.bg.deaths = P.bg.deaths + 1 P.bg.streak = 0 end
end)

-- streak: kills since your last death
local lastHK
C_Timer.NewTicker(3, function()
  if not P.bg then lastHK = nil return end
  local hk = pvpSession()
  if hk and lastHK and hk > lastHK then
    P.bg.streak = P.bg.streak + (hk - lastHK)
    P.bg.best = math.max(P.bg.best, P.bg.streak)
    ns:Fire("PULSE")
  end
  lastHK = hk
end)

ns:On("UPDATE_BATTLEFIELD_STATUS", function()
  local b = P.bg
  if not b or b.done or not GetBattlefieldWinner then return end
  local ok, w = pcall(GetBattlefieldWinner)
  if not ok or type(w) ~= "number" or ns.isSecret(w) then return end
  b.done = true
  local mine = ns.S(UnitFactionGroup, "player") == "Horde" and 0 or 1
  local won = w == mine
  b.won = won
  local d = today()
  d.played = d.played + 1
  if won then d.won = d.won + 1 d.streak = (d.streak or 0) + 1 else d.streak = 0 end
  P:ReadBoard()
  local sum = P:BGSummary(won)
  ns:Fire("PULSE")
  if sum then
    C_Timer.After(1, function() ns:Fire("BG_CARD", sum) end)
    -- one of the gang in the BG posts the result
    local poster = true
    for _, g in ipairs(sum.gang) do if g.pid < ns.pid then poster = false end end
    if poster then
      C_Timer.After(3, function()
        ns.Tracker:Event("BGEND", sum.name or "", won and 1 or 0, sum.score or "",
          (sum.mvp and sum.mvp.name or "") .. ":" .. (sum.mvp and sum.mvp.hk or 0) .. ":" .. (sum.honor or 0) .. ":" .. #sum.gang
          .. ":" .. math.floor(sum.dur or 0))
      end)
    end
    if won and d.streak == 5 then ns.Tracker:Event("BGEND", "streak", 5, "", "") end
  end
end)

---------------------------------------------------------------------------
-- (1.4.0) the battleground in detail: the score at the top of the screen, the scoreboard (your
-- kills, deaths and the gang's), flags, revenge, and the card when it ends
---------------------------------------------------------------------------
-- the score the battleground shows at the top of the screen (flags, bases' resources…)
function P:BGScore()
  local W = C_UIWidgetManager
  if not W or not W.GetTopCenterWidgetSetID or not W.GetAllWidgetsBySetID then return nil end
  local ok, set = pcall(W.GetTopCenterWidgetSetID)
  if not ok or not set then return nil end
  local ok2, widgets = pcall(W.GetAllWidgetsBySetID, set)
  if not ok2 or type(widgets) ~= "table" then return nil end
  local parts = {}
  for _, w in ipairs(widgets) do
    if w.widgetType == 3 and W.GetDoubleStatusBarWidgetVisualizationInfo then
      local okI, info = pcall(W.GetDoubleStatusBarWidgetVisualizationInfo, w.widgetID)
      if okI and type(info) == "table" and info.leftBarValue and info.rightBarValue then
        return math.floor(info.leftBarValue) .. " – " .. math.floor(info.rightBarValue)
      end
    elseif w.widgetType == 0 and W.GetIconAndTextWidgetVisualizationInfo then
      local okI, info = pcall(W.GetIconAndTextWidgetVisualizationInfo, w.widgetID)
      local t = okI and type(info) == "table" and info.text
      if type(t) == "string" and not ns.isSecret(t) then
        local n = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("(%d+)%s*/%s*%d+")
        if n then parts[#parts + 1] = n end
      end
    end
  end
  if #parts >= 2 then return parts[1] .. " – " .. parts[2] end
  return nil
end

-- the scoreboard: your kills/deaths and the gang's in this battleground
local function gangByName()
  local out = {}
  for pid, p in pairs(ns.db.people) do
    for _, c in pairs(p.chars or {}) do if c.name then out[c.name] = pid end end
  end
  return out
end
function P:ReadBoard()
  local b = self.bg
  if not b or not GetNumBattlefieldScores then return end
  local okN, n = pcall(GetNumBattlefieldScores)
  if not okN or type(n) ~= "number" or ns.isSecret(n) then return end
  local byName, me = gangByName(), ns.S(UnitName, "player")
  local gang = {}
  for i = 1, n do
    local ok, name, kb, hk, deaths, honor
    -- (1.4.36) the modern client (WoW Forever) has C_PvP.GetScoreInfo instead of GetBattlefieldScore
    if C_PvP and C_PvP.GetScoreInfo then
      local okI, info = pcall(C_PvP.GetScoreInfo, i)
      if okI and type(info) == "table" then
        ok, name, kb, hk, deaths, honor = true, info.name, info.killingBlows, info.honorableKills, info.deaths, info.honorGained
      end
    end
    if not ok and GetBattlefieldScore then ok, name, kb, hk, deaths, honor = pcall(GetBattlefieldScore, i) end
    if ok and type(name) == "string" and not ns.isSecret(name) then
      local short = ns.ShortName(name)
      local row = { name = short, kb = tonumber(kb) or 0, hk = tonumber(hk) or 0, deaths = tonumber(deaths) or 0, honor = tonumber(honor) or 0 }
      if short == me then b.me = row end
      local pid = byName[short]
      if pid then row.pid = pid gang[#gang + 1] = row end
    end
  end
  table.sort(gang, function(a, c) return a.hk > c.hk end)
  b.gang = gang
  b.boardAt = now()
end
ns:On("UPDATE_BATTLEFIELD_SCORE", function() if P.bg then P:ReadBoard() ns:Fire("PULSE") end end)
C_Timer.NewTicker(10, function()
  if P.bg then P.bg.seen = now() end
  if P.bg and not P.bg.done and RequestBattlefieldScoreData then pcall(RequestBattlefieldScoreData) end
end)

-- flags: who captured or returned one ("X captured the Horde flag!", "…returned to its base by X!")
local function onBGSystem(msg)
  local b = P.bg
  if not b or type(msg) ~= "string" or ns.isSecret(msg) then return end
  local who, act = msg:match("^(.-) captured the"), "cap"
  if not who then who, act = msg:match("returned to its base by (.-)!"), "ret" end
  if not who or who == "" then return end
  who = ns.ShortName(who)
  b.flags[who] = b.flags[who] or { cap = 0, ret = 0 }
  b.flags[who][act] = b.flags[who][act] + 1
  if who == ns.S(UnitName, "player") then ns.Tracker:Event("FLAG", act, b.name or "") end
  ns:Fire("PULSE")
end
ns:On("CHAT_MSG_BG_SYSTEM_HORDE", onBGSystem)
ns:On("CHAT_MSG_BG_SYSTEM_ALLIANCE", onBGSystem)
ns:On("CHAT_MSG_BG_SYSTEM_NEUTRAL", onBGSystem)

-- (1.4.36) honor from the chat lines, for when the game's session count stays at 0
-- ("… (Estimated Honor Points: 12)" for kills, "You have been awarded 41 honor points." for objectives)
ns:On("CHAT_MSG_COMBAT_HONOR_GAIN", function(text)
  local b = P.bg
  if not b or type(text) ~= "string" or ns.isSecret(text) then return end
  local n = tonumber(text:match("(%d+)%)?%.?$") or text:match("awarded (%d+)") or "")
  if n and n > 0 and n < 5000 then b.honorChat = (b.honorChat or 0) + n end
end)
ns:On("CHAT_MSG_SYSTEM", function(text)
  local b = P.bg
  if not b or type(text) ~= "string" or ns.isSecret(text) then return end
  local n = tonumber(text:match("awarded (%d+) honor") or "")
  if n and n > 0 and n < 5000 then b.honorChat = (b.honorChat or 0) + n end
end)

-- revenge in a battleground: you killed someone who killed you or the gang ("Died to" list)
ns:On("CHAT_MSG_COMBAT_HONOR_GAIN", function(text)
  local b = P.bg
  if not b or type(text) ~= "string" or ns.isSecret(text) or not ns.Kills or not ns.Kills.VictimFrom then return end
  local victim = ns.Kills:VictimFrom(text)
  if not victim or victim == "" then return end
  local short = ns.ShortName(victim)
  local dt = ns.db.diedTo and ns.db.diedTo[short:lower()]
  local mine = ns.db.killedBy and ns.db.killedBy[short:lower()]
  if not dt and not mine then return end
  if b.revs[short] and now() - b.revs[short] < 120 then return end
  b.revs[short] = now()
  b.revN = (b.revN or 0) + 1
  ns.Cnt("revengeKills")
  ns.Tracker:Event("BGREV", short, b.name or "")
end)

-- this week's honor and your rank
function P:Week()
  local honor, rankName, prog
  if GetPVPThisWeekStats then
    local ok, _, h = pcall(GetPVPThisWeekStats)
    if ok and type(h) == "number" and not ns.isSecret(h) then honor = h end
  end
  if UnitPVPRank and GetPVPRankInfo then
    local ok, r = pcall(UnitPVPRank, "player")
    if ok and type(r) == "number" and r > 0 then
      local ok2, nm = pcall(GetPVPRankInfo, r)
      if ok2 and type(nm) == "string" then rankName = nm end
    end
  end
  if GetPVPRankProgress then
    local ok, p = pcall(GetPVPRankProgress)
    if ok and type(p) == "number" and not ns.isSecret(p) then prog = math.floor(p * 100) end
  end
  return honor, rankName, prog
end

function P:BGSummary(won)
  local b = self.bg
  if not b then return nil end
  local kills, honor = self:BGNumbers()
  if (not honor or honor == 0) and (b.honorChat or 0) > 0 then honor = b.honorChat end
  if (not honor or honor == 0) and b.me and (b.me.honor or 0) > 0 then honor = b.me.honor end
  -- (1.4.36) the scoreboard may be unreadable: fall back to what we counted ourselves
  local me = b.me or {}
  me = { hk = math.max(me.hk or 0, kills or 0), deaths = math.max(me.deaths or 0, b.deaths or 0), kb = me.kb, honor = me.honor, board = b.me ~= nil }
  local gang = b.gang or {}
  local mvp
  for _, g in ipairs(gang) do if not mvp or g.hk > mvp.hk or (g.hk == mvp.hk and g.deaths < mvp.deaths) then mvp = g end end
  local hero, heroN
  for _, g in ipairs(gang) do
    local f = b.flags[g.name]
    local k = f and (f.cap * 2 + f.ret) or 0
    if k > 0 and (not heroN or k > heroN) then hero, heroN = g.name, k end
  end
  local revNames = {}
  for n in pairs(b.revs) do revNames[#revNames + 1] = n end
  local d = today()
  return { name = b.name, won = won, score = self:BGScore(), dur = now() - b.start, honor = honor,
    gang = gang, mvp = mvp, hero = hero, heroFlags = hero and b.flags[hero], revs = revNames,
    wonToday = d.won, played = d.played, streak = d.streak or 0, best = b.best, me = me }
end

---------------------------------------------------------------------------
-- "Died to" players near you (nameplates, target, mouseover)
---------------------------------------------------------------------------
P.danger = nil
local function check(unit)
  if not ns.S(UnitIsPlayer, unit) or not ns.S(UnitIsEnemy, "player", unit) then return end
  local name = ns.S(UnitName, unit)
  if type(name) ~= "string" or name == "" then return end
  local e = ns.db.diedTo and ns.db.diedTo[name:lower()]
  if not e then return end
  local fresh = not P.danger or P.danger.name ~= e.name or GetTime() - P.danger.at > 60
  P.danger = { name = e.name, n = e.n or 1, at = GetTime() }
  if fresh then ns:Fire("PULSE") end
end
ns:On("NAME_PLATE_UNIT_ADDED", function(unit) check(unit) end)
ns:On("PLAYER_TARGET_CHANGED", function() check("target") end)
ns:On("UPDATE_MOUSEOVER_UNIT", function() check("mouseover") end)

function P:Danger()
  if self.danger and GetTime() - self.danger.at < 90 then return self.danger end
  return nil
end

local started
local function start()
  if started or not ns.db then return end
  started = true
  P:StartSession()
  lastMoney = money()
  P.GoldDay()
  P:SessionHonor()
end
ns:On("PLAYER_LOGIN", start)
C_Timer.After(0, start)

---------------------------------------------------------------------------
-- (1.4.17) Level 60: what's fun to track once the XP bar is full
---------------------------------------------------------------------------
local MAXLVL = 60
function P.AtMax()
  local l = ns.S(UnitLevel, "player")
  return type(l) == "number" and l >= MAXLVL
end

local function dayKey() return date("%Y-%m-%d") end

-- gold today, net: money now minus money at the first look today (per character)
function P.GoldDay()
  local m = money()
  if not m then return nil end
  local me = ns.Comm and ns.Comm.MyFull and ns.Comm:MyFull() or "?"
  ns.db.goldDay = ns.db.goldDay or {}
  local g = ns.db.goldDay[me]
  if not g or g.day ~= dayKey() then
    g = { day = dayKey(), start = m }
    ns.db.goldDay[me] = g
  end
  return m - g.start
end

-- bosses and runs today (a run = an instance visit with at least one boss down)
function P.PvEDay()
  local d = ns.db.pveDay
  if not d or d.day ~= dayKey() then
    d = { day = dayKey(), bosses = 0, runs = 0 }
    ns.db.pveDay = d
  end
  return d
end
local runVisit
ns:On("PLAYER_ENTERING_WORLD", function() runVisit = nil end)
ns:On("ENCOUNTER_END", function(_, _, _, _, success)
  if success ~= 1 and success ~= true then return end
  local d = P.PvEDay()
  d.bosses = d.bosses + 1
  if P.sess then P.sess.bosses = (P.sess.bosses or 0) + 1 end
  if not runVisit then runVisit = true d.runs = d.runs + 1 end
  ns:Fire("PULSE")
end)

-- honor and kills today (the game's own count, which resets daily), with our BG tally as a fallback
function P:HonorToday()
  local hk, honor = pvpSession()
  if not honor then honor = today().honor end
  return hk, honor
end

-- PvP rank: number, name and progress (0..1) to the next one, or nil when the game doesn't say
function P:Rank()
  local rank, name, prog
  if UnitPVPRank then
    local ok, r = pcall(UnitPVPRank, "player")
    if ok and type(r) == "number" and not ns.isSecret(r) then rank = r end
  end
  if rank and GetPVPRankInfo then
    local ok, n, num = pcall(GetPVPRankInfo, rank)
    if ok and type(n) == "string" and not ns.isSecret(n) then name = n end
    if ok and type(num) == "number" and not ns.isSecret(num) then rank = num end
  end
  if GetPVPRankProgress then
    local ok, pr = pcall(GetPVPRankProgress)
    if ok and type(pr) == "number" and not ns.isSecret(pr) then prog = math.max(0, math.min(1, pr)) end
  end
  if rank and rank < 1 then rank = nil end
  if not rank and not prog then return nil end
  return rank, name, prog
end

-- reputation this session, per faction ("Your X reputation has increased by N.")
local repPat
local function buildRep()
  local fmt = FACTION_STANDING_INCREASED or "Your %s reputation has increased by %d."
  local f = fmt:gsub("%%s", "@S@"):gsub("%%d", "@D@")
  f = f:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  repPat = "^" .. f:gsub("@S@", "(.+)"):gsub("@D@", "(%%d+)")
end
ns:On("CHAT_MSG_COMBAT_FACTION_CHANGE", function(msg)
  if type(msg) ~= "string" or ns.isSecret(msg) or not P.sess then return end
  if not repPat then buildRep() end
  local fac, n = msg:match(repPat)
  n = tonumber(n)
  if not fac or not n then return end
  P.sess.rep = P.sess.rep or {}
  P.sess.rep[fac] = (P.sess.rep[fac] or 0) + n
  ns:Fire("PULSE")
end)
-- the faction you gained most with this session, its total and its rate per hour
function P:TopRep()
  local best, n
  for fac, v in pairs(self.sess and self.sess.rep or {}) do
    if not n or v > n then best, n = fac, v end
  end
  if not best then return nil end
  local hours = (now() - (self.sess.start or now())) / 3600
  local rate = hours >= 5 / 60 and math.floor(n / hours) or nil
  return best, n, rate
end

-- best drop this week: the rarest, then most valuable, item you looted (green or better)
function P.BestDrop()
  local b = ns.db.bestDrop
  if b and b.wk == ns.WeekKey() then return b end
  return nil
end
local function noteDrop(link)
  local q = P.LinkQuality(link)
  if q < 2 then return end
  local id = itemId(link)
  if not id then return end
  local v = P.ItemValue(link) or 0
  local b = P.BestDrop()
  if not b or q > b.q or (q == b.q and v > (b.v or 0)) then
    ns.db.bestDrop = { wk = ns.WeekKey(), id = id, q = q, v = v, link = link }
  end
  -- (1.4.28) and the best of this session, for the session recap
  local sb = P.sess and P.sess.best
  if P.sess and (not sb or q > (sb.q or 0) or (q == sb.q and v > (sb.v or 0))) then P.sess.best = { q = q, v = v, link = link } end
end
ns:On("CHAT_MSG_LOOT", function(msg)
  if type(msg) ~= "string" or ns.isSecret(msg) then return end
  if not lootPatterns then buildLoot() end
  for _, pat in ipairs(lootPatterns) do
    local link = msg:match(pat)
    if link then noteDrop(link) return end
  end
end)

-- honor and kills this session (the game counts per day; we keep the count at session start)
function P:SessionHonor()
  local hk, honor = pvpSession()
  local s = self.sess
  if not s or not s.start then return nil end
  if hk and not s.hk0 then s.hk0 = hk end
  if honor and not s.honor0 then s.honor0 = honor end
  local dh = hk and math.max(0, hk - (s.hk0 or hk)) or nil
  local dn = honor and math.max(0, honor - (s.honor0 or honor)) or nil
  return dh, dn
end

---------------------------------------------------------------------------
-- (1.4.34) battleground reputation: wins to Exalted (Frostwolf/Stormpike in Alterac Valley,
-- Warsong Outriders/Silverwing in Warsong Gulch, Defilers/League of Arathor in Arathi Basin).
-- Each game's gain is measured from entering to leaving (the win bonus comes at the end) and
-- averaged separately for wins and losses.
---------------------------------------------------------------------------
local EXALTED = 42000
-- by instance ID (language-independent), with the English name as a fallback
local BG_REP = {
  [30] = { Horde = 729, Alliance = 730, def = 450, short = "AV" },
  [489] = { Horde = 889, Alliance = 890, def = 160, short = "WSG" },
  [529] = { Horde = 510, Alliance = 509, def = 260, short = "AB" },
  -- (1.4.39) WoW Forever's new battleground. Its instance and faction IDs are learned in the game:
  -- the instance from GetInstanceInfo the first time you're there, the factions by name from the
  -- reputation list
  DI = { HordeName = "Darkspear Raiders", AllianceName = "Theramore Expeditionary Force", def = 250, short = "DI" },
}
local BG_NAMES = { ["Alterac Valley"] = 30, ["Warsong Gulch"] = 489, ["Arathi Basin"] = 529, ["Darkspear Islands"] = "DI" }
local function bgInfo(instId, name)
  local learned = ns.db and ns.db.bgInstIds and instId and ns.db.bgInstIds[instId]
  return BG_REP[instId or 0] or (learned and BG_REP[learned]) or (name and BG_REP[BG_NAMES[name] or 0])
end
-- a faction's ID by its name, from the reputation list (remembered once found)
local function factionByName(name)
  if not name then return nil end
  ns.db.factionIds = ns.db.factionIds or {}
  if ns.db.factionIds[name] then return ns.db.factionIds[name] end
  local n = 0
  if C_Reputation and C_Reputation.GetNumFactions then local ok, x = pcall(C_Reputation.GetNumFactions) if ok then n = x or 0 end
  elseif GetNumFactions then local ok, x = pcall(GetNumFactions) if ok then n = x or 0 end end
  for i = 1, n do
    local fname, fid
    if C_Reputation and C_Reputation.GetFactionDataByIndex then
      local ok, d = pcall(C_Reputation.GetFactionDataByIndex, i)
      if ok and type(d) == "table" then fname, fid = d.name, d.factionID end
    elseif GetFactionInfo then
      local ok, a, _, _, _, _, _, _, _, _, _, _, _, _, id = pcall(GetFactionInfo, i)
      if ok then fname, fid = a, id end
    end
    if fname == name and fid then ns.db.factionIds[name] = fid return fid end
  end
  return nil
end
function P.BGFaction(instId, name)
  local learnHere = false
  if not instId then
    local ok, n, _, _, _, _, _, _, id = pcall(GetInstanceInfo)
    if ok then instId, name, learnHere = id, n, true end
  end
  local info = bgInfo(instId, name)
  if not info then return nil end
  -- learn the instance ID of a battleground known by name (only from where you actually are)
  if learnHere and instId and instId > 0 and not BG_REP[instId] and name and BG_NAMES[name] and ns.db then
    ns.db.bgInstIds = ns.db.bgInstIds or {}
    ns.db.bgInstIds[instId] = BG_NAMES[name]
  end
  local side = ns.S(UnitFactionGroup, "player") == "Alliance" and "Alliance" or "Horde"
  local fid = info[side] or factionByName(info[side .. "Name"])
  return fid, info
end

-- standing for a faction: absolute value (0 = start of Neutral, 42 000 = Exalted), and the current tier
function P.RepOf(fid)
  if C_Reputation and C_Reputation.GetFactionDataByID then
    local ok, d = pcall(C_Reputation.GetFactionDataByID, fid)
    if ok and type(d) == "table" and d.currentStanding and not ns.isSecret(d.currentStanding) then
      return { name = d.name, value = d.currentStanding, reaction = d.reaction,
        min = d.currentReactionThreshold or 0, max = d.nextReactionThreshold or EXALTED }
    end
  end
  if GetFactionInfoByID then
    local ok, name, _, standing, bmin, bmax, val = pcall(GetFactionInfoByID, fid)
    if ok and val and not ns.isSecret(val) then
      return { name = name, value = val, reaction = standing, min = bmin or 0, max = bmax or EXALTED }
    end
  end
  return nil
end
local STANDING = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
function P.StandingName(reaction) return STANDING[reaction or 0] or "" end

function P.NoteBGRep(b)
  if not (b and b.repFid and b.rep0) then return end
  local r = P.RepOf(b.repFid)
  if not r then return end
  local gained = r.value - b.rep0
  if gained < 0 or gained > 6000 then return end
  ns.db.bgRep = ns.db.bgRep or {}
  local t = ns.db.bgRep[b.repFid] or { wN = 0, wSum = 0, lN = 0, lSum = 0 }
  if b.won == true then t.wN, t.wSum = t.wN + 1, t.wSum + gained
  elseif b.won == false then t.lN, t.lSum = t.lN + 1, t.lSum + gained
  else return end
  ns.db.bgRep[b.repFid] = t
  ns.db.bgRepLast = { fid = b.repFid, at = ns.Now(), game = gained, won = b.won }
end

-- the battleground reputation picture: in a battleground (or the last one, within 30 minutes)
function P:BGRep(anyTime)
  local fid, info
  local b = self.bg
  if b and b.repFid then fid = b.repFid
  else
    local last = ns.db.bgRepLast
    if last and (anyTime or ns.Now() - (last.at or 0) < 1800) then fid = last.fid end
  end
  if not fid then return nil end
  for _, i in pairs(BG_REP) do
    if i.Horde == fid or i.Alliance == fid or (ns.db.factionIds and (ns.db.factionIds[i.HordeName or "-"] == fid or ns.db.factionIds[i.AllianceName or "-"] == fid)) then info = i end
  end
  local r = P.RepOf(fid)
  if not r then return nil end
  local t = (ns.db.bgRep or {})[fid] or { wN = 0, wSum = 0, lN = 0, lSum = 0 }
  local wN, wSum = t.wN, t.wSum
  -- (1.4.36) a game just won but not yet recorded (the recap opens before you leave) counts already
  if b and b.repFid == fid and b.won == true and b.rep0 then
    local g = r.value - b.rep0
    if g > 0 and g < 6000 then wN, wSum = wN + 1, wSum + g end
  end
  local avgW = wN > 0 and math.floor(wSum / wN) or (info and info.def or 300)
  local avgL = t.lN > 0 and math.floor(t.lSum / t.lN) or nil
  local left = math.max(0, EXALTED - r.value)
  local game = (b and b.repFid == fid and b.rep0) and math.max(0, r.value - b.rep0) or nil
  local fname = (r.name or ""):gsub(" Clan$", ""):gsub(" Guard$", "")
  return { fid = fid, name = r.name, short = fname, value = r.value, left = left, exalted = left == 0,
    reaction = r.reaction, standing = P.StandingName(r.reaction), min = r.min, max = r.max,
    avgW = avgW, wN = wN, avgL = avgL, lN = t.lN, estimated = wN == 0,
    winsLeft = avgW > 0 and math.ceil(left / avgW) or nil, game = game, inBG = b ~= nil, bg = info and info.short }
end

-- (1.4.37) the watched faction ("Show as Experience Bar" in the reputation window), for the level 60 bar
function P.WatchedRep()
  local name, reaction, bmin, bmax, val, fid
  if C_Reputation and C_Reputation.GetWatchedFactionData then
    local ok, d = pcall(C_Reputation.GetWatchedFactionData)
    if ok and type(d) == "table" and d.name and not ns.isSecret(d.name) then
      name, reaction, bmin, bmax, val, fid = d.name, d.reaction, d.currentReactionThreshold, d.nextReactionThreshold, d.currentStanding, d.factionID
    end
  end
  if not name and GetWatchedFactionInfo then
    local ok, n, r, a, b, v, id = pcall(GetWatchedFactionInfo)
    if ok and type(n) == "string" and not ns.isSecret(n) then name, reaction, bmin, bmax, val, fid = n, r, a, b, v, id end
  end
  if not name or not val or ns.isSecret(val) then return nil end
  bmin, bmax = bmin or 0, bmax or 42000
  local span = math.max(1, bmax - bmin)
  local exalted = (reaction or 0) >= 8
  local gained = P.sess and P.sess.rep and P.sess.rep[name]
  local hours = P.sess and P.sess.start and (now() - P.sess.start) / 3600 or 0
  return { name = name, fid = fid, standing = P.StandingName(reaction), exalted = exalted,
    into = math.max(0, val - bmin), span = span, pct = exalted and 1 or math.max(0, math.min(1, (val - bmin) / span)),
    perHour = (gained and hours >= 5 / 60) and math.floor(gained / hours) or nil }
end

---------------------------------------------------------------------------
-- (1.4.38) PvP page: every battleground game is kept ({ t, k, won, dur, hk, deaths, kb, honor, rep }),
-- and stats per battleground for today, this week or all time. All-time numbers go to the gang.
---------------------------------------------------------------------------
P.BG_KEYS = { { key = "AV", name = "Alterac Valley", id = 30 }, { key = "WSG", name = "Warsong Gulch", id = 489 },
  { key = "AB", name = "Arathi Basin", id = 529 }, { key = "DI", name = "Darkspear Islands" } }
local KEY_BY_NAME = { ["Alterac Valley"] = "AV", ["Warsong Gulch"] = "WSG", ["Arathi Basin"] = "AB", ["Darkspear Islands"] = "DI" }
function P.BGKey(name) return KEY_BY_NAME[name or ""] or name end

function P.RecordGame(b, honor)
  if not b or b.won == nil then return end   -- left before the end: not a game
  local kills = select(1, P:BGNumbers())
  local me = b.me or {}
  local rep
  if b.repFid and b.rep0 then
    local r = P.RepOf(b.repFid)
    if r then rep = math.max(0, r.value - b.rep0) end
  end
  ns.db.bgGames = ns.db.bgGames or {}
  local list = ns.db.bgGames
  list[#list + 1] = { t = now(), k = P.BGKey(b.name), won = b.won, dur = math.max(0, now() - (b.start or now())),
    hk = math.max(me.hk or 0, kills or 0), deaths = math.max(me.deaths or 0, b.deaths or 0), kb = me.kb,
    honor = honor or 0, rep = rep }
  while #list > 3000 do table.remove(list, 1) end
  if P.SharePvP then C_Timer.After(5, P.SharePvP) end
end

local function rangeStart(range)
  if range == "today" then
    local d = date("*t")
    return time({ year = d.year, month = d.month, day = d.day, hour = 0 })
  elseif range == "week" then
    return now() - 7 * 86400
  end
  return 0
end
-- per battleground: { played, won, rate, cur, best, honor, honorH, honorPer, hkPer, bestHK, avgDur, totalDur, repPerWin }
function P.PvPStats(range)
  local from = rangeStart(range)
  local out = {}
  for _, g in ipairs(ns.db.bgGames or {}) do
    if (g.t or 0) >= from then
      local s = out[g.k] or { played = 0, won = 0, honor = 0, hk = 0, totalDur = 0, bestHK = 0, cur = 0, best = 0, run = 0,
        repW = 0, repWN = 0 }
      out[g.k] = s
      s.played = s.played + 1
      if g.won then
        s.won = s.won + 1
        s.run = s.run + 1
        s.best = math.max(s.best, s.run)
        if g.rep then s.repW, s.repWN = s.repW + g.rep, s.repWN + 1 end
      else s.run = 0 end
      s.honor = s.honor + (g.honor or 0)
      s.hk = s.hk + (g.hk or 0)
      s.totalDur = s.totalDur + (g.dur or 0)
      s.bestHK = math.max(s.bestHK, g.hk or 0)
    end
  end
  for _, s in pairs(out) do
    s.cur = s.run
    s.rate = s.played > 0 and s.won / s.played or 0
    s.honorPer = s.played > 0 and math.floor(s.honor / s.played) or 0
    s.hkPer = s.played > 0 and (s.hk / s.played) or 0
    s.avgDur = s.played > 0 and math.floor(s.totalDur / s.played) or 0
    s.honorH = s.totalDur >= 300 and math.floor(s.honor / s.totalDur * 3600) or nil
    s.repPerWin = s.repWN > 0 and math.floor(s.repW / s.repWN) or nil
  end
  return out
end

-- reputation for a battleground by key (standing, wins to Exalted) – not only the one you're in
function P.RepForKey(key)
  local def
  for _, d in ipairs(P.BG_KEYS) do if d.key == key then def = d end end
  if not def then return nil end
  local fid = P.BGFaction(def.id or -1, def.name)
  local r = fid and P.RepOf(fid)
  if not r then return nil end
  local t = (ns.db.bgRep or {})[fid] or { wN = 0, wSum = 0 }
  local avg = t.wN > 0 and math.floor(t.wSum / t.wN) or nil
  local left = math.max(0, 42000 - r.value)
  local span = math.max(1, (r.max or 42000) - (r.min or 0))
  return { name = r.name, standing = P.StandingName(r.reaction), reaction = r.reaction, exalted = left == 0,
    pct = math.max(0, math.min(1, (r.value - (r.min or 0)) / span)), left = left, avg = avg,
    winsLeft = avg and avg > 0 and math.ceil(left / avg) or nil }
end

-- the gang: all-time numbers per battleground, "AV:played:won:hk10:honorH:reaction:winsLeft;…"
function P.SharePvP()
  if not (ns.Comm and ns.db) then return end
  local st = P.PvPStats("all")
  local parts = {}
  for _, d in ipairs(P.BG_KEYS) do
    local s = st[d.key]
    if s and s.played > 0 then
      local rep = P.RepForKey(d.key) or {}
      parts[#parts + 1] = d.key .. ":" .. s.played .. ":" .. s.won .. ":" .. math.floor(s.hkPer * 10) .. ":" .. (s.honorH or 0)
        .. ":" .. (rep.reaction or 0) .. ":" .. (rep.winsLeft or "")
    end
  end
  if #parts > 0 then ns.Comm:Broadcast(ns.Comm:Build("PV", ns.pid, table.concat(parts, ";")), 3) end
end
ns.Comm:Handle("PV", function(f, sender)
  if ns.Comm:IsMe(sender) or not f[1] or f[1] == ns.pid then return end
  local p = ns:GetPerson(f[1], true)
  p.pvp = { at = now() }
  for part in tostring(f[2] or ""):gmatch("[^;]+") do
    local k, pl, w, hk10, hh, re, wl = part:match("^(%w+):(%d+):(%d+):(%d+):(%d+):(%d+):?(%d*)$")
    if k then
      p.pvp[k] = { played = tonumber(pl), won = tonumber(w), hkPer = tonumber(hk10) / 10, honorH = tonumber(hh),
        reaction = tonumber(re), winsLeft = tonumber(wl) }
    end
  end
  ns:Fire("PVP")
end)
ns:On("PLAYER_LOGIN", function() C_Timer.After(30, P.SharePvP) end)
