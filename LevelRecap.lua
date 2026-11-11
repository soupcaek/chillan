-- Chillan? – level recap: collects what happened on each level, and shows it when you ding.
local ADDON, ns = ...

local R = {}
ns.LevelRecap = R

local function key() return ns.Comm:MyFull() end

-- the record for the level you're on now
function R:Cur()
  ns.db.lvlRec = ns.db.lvlRec or {}
  local lvl = ns.S(UnitLevel, "player") or 1
  local r = ns.db.lvlRec[key()]
  if r and lvl == r.lvl + 1 then
    -- UnitLevel can report the new level a moment before PLAYER_LEVEL_UP: keep the old record
    -- for a few seconds so the ding handler can finish it; if the event never comes, finish it here
    r.dingSeen = r.dingSeen or ns.Now()
    if ns.Now() - r.dingSeen < 10 then return r end
    R:Finish(lvl)
    return ns.db.lvlRec[key()]
  end
  if not r or r.lvl ~= lvl then
    r = { lvl = lvl, start = ns.Now(), secs = 0, deaths = 0, alli = 0, kills = 0, mobs = {}, money = 0, repairs = 0,
      quests = 0, questXP = 0, mobXP = 0, zones = {}, with = {}, ach = 0, dgs = {}, sessions = 1,
      partial = (r == nil) }  -- partial: started tracking mid-level (first install)
    ns.db.lvlRec[key()] = r
  end
  return r
end

-- finished levels, for "faster than last level" and the gang ranking
function R:Done(lvl)
  ns.db.lvlDone = ns.db.lvlDone or {}
  ns.db.lvlDone[key()] = ns.db.lvlDone[key()] or {}
  if lvl then return ns.db.lvlDone[key()][lvl] end
  return ns.db.lvlDone[key()]
end

---------------------------------------------------------------------------
-- collecting
---------------------------------------------------------------------------
local lastMoney
local inRepair = false

ns:On("PLAYER_LOGIN", function()
  local r = R:Cur()
  r.sessions = (r.sessions or 0) + ((ns.db.lastAliveAt and ns.Now() - ns.db.lastAliveAt < 600) and 0 or 1)
  lastMoney = ns.S(GetMoney)
end)

-- time, zones and who you play with (every 15 s while not AFK)
C_Timer.NewTicker(15, function()
  if not ns.db or ns.S(UnitIsAFK, "player") then return end
  local r = R:Cur()
  r.secs = r.secs + 15
  local z = ns.S(GetRealZoneText)
  if z and z ~= "" then r.zones[z] = (r.zones[z] or 0) + 15 end
  if (ns.S(GetNumGroupMembers) or 0) > 0 then
    for pid, p in pairs(ns.db.people or {}) do
      if pid ~= ns.pid and ns.InMyGroup and ns.InMyGroup(p) then r.with[pid] = (r.with[pid] or 0) + 15 end
    end
  end
end)

-- mob kills: "X dies, you gain N experience."
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
  local mob, xp = msg:match(xpPattern)
  if not mob then return end
  local r = R:Cur()
  r.kills = r.kills + 1
  r.mobs[mob] = (r.mobs[mob] or 0) + 1
  r.mobXP = r.mobXP + (tonumber(xp) or 0)
end)

ns:On("QUEST_TURNED_IN", function(_, xp)
  local r = R:Cur()
  r.quests = r.quests + 1
  if type(xp) == "number" and not ns.isSecret(xp) then r.questXP = r.questXP + xp end
end)

ns:On("PLAYER_MONEY", function()
  local m = ns.S(GetMoney)
  if not m then return end
  if lastMoney and m > lastMoney and not inRepair then R:Cur().money = R:Cur().money + (m - lastMoney) end
  lastMoney = m
end)

if RepairAllItems then
  hooksecurefunc("RepairAllItems", function()
    local cost = ns.S(GetRepairAllCost)
    if cost and cost > 0 then R:Cur().repairs = R:Cur().repairs + cost end
  end)
end

ns:On("PLAYER_DEAD", function()
  local r = R:Cur()
  r.deaths = r.deaths + 1
  C_Timer.After(0.5, function()
    local k = ns.Tracker.lastKiller
    if k and k.cat == "PLAYER" and ns.Now() - (ns.Tracker.lastKillerAt or 0) < 5 then r.alli = r.alli + 1 end
  end)
end)

-- my own feed events: best loot, achievements, dungeons
local origEvent = ns.Tracker.Event
ns.Tracker.Event = function(self, kind, a, b, c, d)
  if kind == "DEAD" then ns.Tracker.lastKillerAt = ns.Now() end
  origEvent(self, kind, a, b, c, d)
  local r = R:Cur()
  if kind == "LOOT" then
    local q = tonumber(b) or 0
    if not r.loot or q > r.loot.q then r.loot = { id = tonumber(a), q = q } end
  elseif kind == "ACH" then
    r.ach = r.ach + 1
  elseif kind == "DUNGEON" and a and a ~= "" then
    r.dgs[#r.dgs + 1] = a
  end
end

---------------------------------------------------------------------------
-- the recap
---------------------------------------------------------------------------
local function top(t)
  local bk, bv = nil, 0
  for k, v in pairs(t or {}) do if v > bv then bk, bv = k, v end end
  return bk, bv
end

-- how fast others in the gang did the same level (from their level history with /played)
local function gangRank(lvl, mine)
  local times = {}
  for pid, p in pairs(ns.db.people or {}) do
    if pid ~= ns.pid then
      local best
      for _, c in pairs(p.chars or {}) do
        local a, b
        for _, h in ipairs(c.hist or {}) do
          if h.l == lvl and h.p then a = h.p end
          if h.l == lvl + 1 and h.p then b = h.p end
        end
        if a and b and b > a and (not best or b - a < best) then best = b - a end
      end
      if best then times[#times + 1] = { pid = pid, t = best } end
    end
  end
  if #times == 0 or not mine then return nil end
  local place, fastest = 1, nil
  for _, x in ipairs(times) do
    if x.t < mine then place = place + 1 end
    if not fastest or x.t < fastest.t then fastest = x end
  end
  return { place = place, of = #times + 1, fastest = fastest }
end

function R:Build(r, newLevel, levelTime, xpMax)
  local out = { from = r.lvl, to = newLevel, partial = r.partial }
  out.time = levelTime or r.secs
  out.deaths, out.alli = r.deaths, r.alli
  out.kills = r.kills
  local mob, mobN = top(r.mobs)
  out.topMob, out.topMobN = mob, mobN
  out.money, out.repairs = r.money, r.repairs
  out.quests = r.quests
  local xp = xpMax or (r.questXP + r.mobXP)
  out.xph = (out.time and out.time > 0) and math.floor(xp / out.time * 3600) or nil
  out.questShare = (xp and xp > 0) and math.floor(math.min(1, r.questXP / xp) * 100) or nil
  local zones = {}
  for z, s in pairs(r.zones) do zones[#zones + 1] = { z = z, s = s } end
  table.sort(zones, function(a, b) return a.s > b.s end)
  out.zones = { zones[1] and zones[1].z, zones[2] and zones[2].z }
  out.sessions = r.sessions
  out.loot = r.loot
  local wp, ws = top(r.with)
  out.with, out.withSecs = wp, ws
  out.ach, out.dgs = r.ach, r.dgs
  local prev = self:Done(r.lvl - 1)
  if prev and prev.time and out.time then out.vsPrev = out.time - prev.time end
  out.bestXph = true
  for _, d in pairs(self:Done()) do if d.xph and out.xph and d.xph > out.xph then out.bestXph = false end end
  out.rank = gangRank(r.lvl, out.time)
  return out
end

-- finish the record for the level just completed, start the next one, show the ding box
function R:Finish(level)
  ns.db.lvlRec = ns.db.lvlRec or {}
  local r = ns.db.lvlRec[key()]
  if not r or r.lvl >= level then return end
  local c = ns.Tracker:MyChar()
  local xpMax = ns.S(UnitXPMax, "player") -- the new level's; the old level's is r.xpMax
  local lt = (level == r.lvl + 1 and c.prevLevelTime and c.prevLevelTime > 0) and c.prevLevelTime or nil
  local recap = R:Build(r, level, lt, r.xpMax)
  R:Done()[r.lvl] = { time = recap.time, xph = recap.xph, deaths = recap.deaths, kills = recap.kills, at = ns.Now() }
  ns.db.lastRecap = recap
  ns.db.lvlRec[key()] = { lvl = level, start = ns.Now(), secs = 0, deaths = 0, alli = 0, kills = 0, mobs = {}, money = 0, repairs = 0,
    quests = 0, questXP = 0, mobXP = 0, zones = {}, with = {}, ach = 0, dgs = {}, sessions = 1, xpMax = xpMax }
  if ns.db.settings.levelRecap ~= false and level == r.lvl + 1 then
    C_Timer.After(1.5, function() ns:Fire("LEVEL_RECAP", recap) end)
  end
end

-- PLAYER_LEVEL_UP (Tracker has already stored the /played time for the level)
ns:On("PLAYER_LEVEL_UP", function(level)
  if ns.isSecret(level) or type(level) ~= "number" then return end
  R:Finish(level)
end)

-- remember how much XP the current level needs (UnitXPMax is the new level's after a ding)
ns:On("PLAYER_XP_UPDATE", function()
  local r = R:Cur()
  local m = ns.S(UnitXPMax, "player")
  if m and m > 0 then r.xpMax = m end
end)

-- text for gang chat
function R:ShareText(x)
  local parts = { "Level " .. x.from .. " → " .. x.to .. " recap: " .. ns.Duration(x.time or 0) }
  if x.xph then parts[#parts + 1] = string.format("%dk XP/h", math.floor(x.xph / 1000 + 0.5)) end
  parts[#parts + 1] = x.deaths .. (x.deaths == 1 and " death" or " deaths")
  if x.kills > 0 then parts[#parts + 1] = x.kills .. (x.kills == 1 and " kill" or " kills") end
  if x.quests > 0 then parts[#parts + 1] = x.quests .. (x.quests == 1 and " quest" or " quests") end
  if x.money > 0 then parts[#parts + 1] = "+" .. ns.Money(x.money):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
  local s = table.concat(parts, " · ")
  if x.loot and x.loot.id then
    local _, link = (C_Item and C_Item.GetItemInfo or GetItemInfo)(x.loot.id)
    if link then s = s .. " · best loot " .. link end
  end
  return s
end
