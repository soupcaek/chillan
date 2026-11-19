-- Chillan? – Gang pulse data (1.1.0): which mode you're in (open world, dungeon, battleground) and
-- the numbers each mode shows: gold/h and session counts, the dungeon run (XP, loot), the
-- battleground (honor, kills, wins today), and "Died to" players near you.
local ADDON, ns = ...
local P = {}
ns.Pulse = P

local MODES = { world = "Open world", dungeon = "Dungeon", bg = "Battleground" }
P.MODES = MODES

local function now() return ns.Now() end
local function money() local m = ns.S(GetMoney) return type(m) == "number" and m or nil end

---------------------------------------------------------------------------
-- Mode
---------------------------------------------------------------------------
function P:Detect()
  local inInst, kind = ns.S(IsInInstance)
  if inInst and (kind == "pvp" or kind == "arena") then return "bg" end
  if inInst and (kind == "party" or kind == "raid") then return "dungeon" end
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
  local m = money()
  if s.start and not s.money0 and m then s.money0 = m end
  if not s.start or not s.money0 or not m then return nil end
  local hours = (now() - s.start) / 3600
  if hours < 5 / 60 then return nil end   -- too early to say
  return math.floor((m - s.money0) / hours)
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
  if lastXP and P:Mode() == "dungeon" then
    local _, pr = P:Run()
    if pr then
      local gain = (xp >= lastXP) and (xp - lastXP) or ((lastMax or 0) - lastXP + xp)
      if gain > 0 then pr.xp = pr.xp + gain end
    end
  end
  lastXP, lastMax = xp, mx
end)
ns:On("PLAYER_MONEY", function()
  local m = money()
  if not m then return end
  if lastMoney and m > lastMoney and P:Mode() == "dungeon" and not (MerchantFrame and MerchantFrame:IsShown()) then
    local _, pr = P:Run()
    if pr then pr.money = pr.money + (m - lastMoney) end
  end
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
ns:On("CHAT_MSG_LOOT", function(msg)
  if type(msg) ~= "string" or ns.isSecret(msg) or P:Mode() ~= "dungeon" then return end
  if not lootPatterns then buildLoot() end
  local link
  for _, pat in ipairs(lootPatterns) do link = msg:match(pat) if link then break end end
  if not link then return end
  local _, pr = P:Run()
  if not pr then return end
  if P.LinkQuality(link) == 0 then pr.grey = pr.grey + 1
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

function P:StartBG()
  local hk, honor = pvpSession()
  self.bg = { start = now(), hk0 = hk, honor0 = honor, deaths = 0, streak = 0, best = 0, done = false }
  today().played = today().played + 1
end

function P:EndBG()
  local b = self.bg
  if not b then return end
  local _, honor = self:BGNumbers()
  if honor then today().honor = today().honor + honor end
  self.bg = nil
end

-- kills (honorable kills) and honor this match, or nil when the game doesn't say
function P:BGNumbers()
  local b = self.bg
  if not b then return nil, nil end
  local hk, honor = pvpSession()
  local kills = (hk and b.hk0) and math.max(0, hk - b.hk0) or nil
  local hon = (honor and b.honor0) and math.max(0, honor - b.honor0) or nil
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
  if w == mine then today().won = today().won + 1 end
  ns:Fire("PULSE")
end)

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
end
ns:On("PLAYER_LOGIN", start)
C_Timer.After(0, start)
