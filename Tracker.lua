-- Chillan? – sporer din egen karakter: tid, level, quests, gull, dødsfall, posisjon
local ADDON, ns = ...
local Tracker = {}
ns.Tracker = Tracker

local lastTick
local lastMoney
local session = { start = 0, levels = 0, quests = 0, gold = 0, deaths = 0, sos = 0, startLevel = 0, xp = 0 }
ns.session = session

function Tracker:Me()
  return ns:GetPerson(ns.pid, true)
end

function Tracker:MyChar()
  local me = self:Me()
  local full = ns.Comm:MyFull()
  local c = me.chars[full]
  if not c then
    c = {}
    me.chars[full] = c
  end
  return c, full
end

function Tracker:RefreshCharInfo()
  local me = self:Me()
  local c, full = self:MyChar()
  c.name = ns.MyDisplayName() or c.name
  local _, classFile = ns.S(UnitClass, "player")
  c.class = classFile or c.class
  c.race = ns.S(UnitRace, "player") or c.race
  c.level = ns.S(UnitLevel, "player") or c.level or 1
  me.main = full
  me.heard = ns.Now()
  -- levelhistorikk til statistikkgrafen
  c.hist = c.hist or {}
  if #c.hist == 0 or c.hist[#c.hist].l < c.level then
    table.insert(c.hist, { t = ns.Now(), l = c.level, p = c.played })
  end
end

local function rollWeek(stats)
  local wk = ns.WeekKey()
  if stats.wk ~= wk then
    if stats.wk then
      stats.prev = { wk = stats.wk, Online = stats.wOnline or 0, Quests = stats.wQuests or 0,
        Gold = stats.wGold or 0, Deaths = stats.wDeaths or 0, Levels = stats.wLevels or 0, Kills = stats.wKills or 0 }
    end
    stats.wk = wk
    stats.wOnline, stats.wQuests, stats.wGold, stats.wDeaths = 0, 0, 0, 0
    stats.wLevels, stats.wKills, stats.wNight = 0, 0, 0
  end
end

function Tracker:AddStat(key, amount)
  local s = self:Me().stats
  rollWeek(s)
  s["w" .. key] = (s["w" .. key] or 0) + amount
  s["t" .. key] = (s["t" .. key] or 0) + amount
end

-- /played akkurat nå (oppdateres løpende mens du er logget på)
function Tracker:PlayedNow()
  local c = self:MyChar()
  return c.played
end

function Tracker:Status()
  local o = ns.db.statusOverride
  if o and o ~= "AUTO" then
    if o == "HELP" and ns.db.statusOverrideAt and ns.Now() - ns.db.statusOverrideAt > 900 then
      ns.db.statusOverride = nil
    else
      return o
    end
  end
  if ns.S(UnitIsAFK, "player") then return "AFK" end
  local inInst, kind = ns.S(IsInInstance)
  if inInst then
    if kind == "pvp" or kind == "arena" then return "BG" end
    return "DUNGEON"
  end
  return "QUEST"
end

function Tracker:SetStatus(code)
  ns.db.statusOverride = (code ~= "AUTO") and code or nil
  ns.db.statusOverrideAt = ns.Now()
  self:SendStatus()
  ns:MarkDirty()
end

function Tracker:Location()
  local loc = {}
  local inInst = ns.S(IsInInstance)
  loc.inInst = inInst and true or false
  if inInst then
    loc.zone = (ns.S(GetInstanceInfo)) or ns.S(GetRealZoneText) or ""
    loc.sub = ""
  else
    loc.zone = ns.S(GetRealZoneText) or ns.S(GetZoneText) or ""
    loc.sub = ns.S(GetSubZoneText) or ""
  end
  local ok = pcall(function()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID or ns.isSecret(mapID) then return end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    if not x or ns.isSecret(x) or ns.isSecret(y) or (x == 0 and y == 0) then return end
    loc.mapID, loc.x, loc.y = mapID, x, y
    local cont, wp = C_Map.GetWorldPosFromMapPos(mapID, pos)
    if cont and wp and not ns.isSecret(cont) then
      local wx, wy = wp:GetXY()
      if not ns.isSecret(wx) and not ns.isSecret(wy) then
        loc.cont, loc.wx, loc.wy = cont, wx, wy
      end
    end
  end)
  return loc
end

function Tracker:UpdateLive()
  local me = self:Me()
  local loc = self:Location()
  me.live = me.live or {}
  local L = me.live
  L.char = ns.Comm:MyFull()
  L.zone, L.sub, L.inInst = loc.zone, loc.sub, loc.inInst
  L.mapID, L.x, L.y, L.cont, L.wx, L.wy = loc.mapID, loc.x, loc.y, loc.cont, loc.wx, loc.wy
  L.status = self:Status()
  L.session = session.start
  me.heard = ns.Now()
  me.lastSeen = ns.Now()
  return L
end

---------------------------------------------------------------------------
-- Meldinger om meg selv
---------------------------------------------------------------------------
function Tracker:BuildST()
  self:RefreshCharInfo()
  local L = self:UpdateLive()
  local c = self:MyChar()
  return ns.Comm:Build("ST", ns.pid, L.char, c.class, c.race, c.level,
    ns.Clean(L.zone, 32), ns.Clean(L.sub, 32), L.status, ns.Now() - session.start,
    L.inInst, L.mapID or "", L.x and math.floor(L.x * 1000) or "", L.y and math.floor(L.y * 1000) or "",
    L.cont or "", L.wx and math.floor(L.wx) or "", L.wy and math.floor(L.wy) or "",
    ns.Clean(c.name or "", 40), ns.VERSION, ns.Clean(ns.db.alias or "", 20))
end

---------------------------------------------------------------------------
-- Detaljert statistikk til spillersiden (XP-tempo, streak, gull, item level)
---------------------------------------------------------------------------
local xpState = {}

function Tracker:ReadXP()
  return ns.S(UnitXP, "player"), ns.S(UnitXPMax, "player"), ns.S(GetXPExhaustion)
end

function Tracker:Streak(days)
  days = days or {}
  local n, t = 0, ns.Now()
  if not days[date("%Y-%m-%d", t)] then t = t - 86400 end
  while days[date("%Y-%m-%d", t)] do
    n = n + 1
    t = t - 86400
  end
  return n
end

local function topZone(zones)
  local bz, bv = nil, 0
  for z, v in pairs(zones or {}) do if v > bv then bz, bv = z, v end end
  return bz
end

-- Laveste holdbarhet på utstyret i prosent (nil hvis ingenting har holdbarhet)
function ns.Durability()
  if not GetInventoryItemDurability then return nil end
  local low
  for slot = 1, 18 do
    local cur, max = ns.S(GetInventoryItemDurability, slot)
    if cur and max and max > 0 then
      local pct = cur / max * 100
      if not low or pct < low then low = pct end
    end
  end
  return low and math.floor(low) or nil
end

-- Varsel når utstyret begynner å bli slitt (30 %) og nesten ødelagt (10 %)
local duraWarned = 100
local function checkDurability()
  local d = ns.Durability()
  if not d then return end
  if math.abs(d - (Tracker.lastDura or d)) >= 5 then Tracker:SendS3Soon() end
  Tracker.lastDura = d
  if d >= 50 then duraWarned = 100 return end
  local level = (d <= 10 and 10) or (d <= 30 and 30) or nil
  if level and level < duraWarned then
    duraWarned = level
    if ns.db.settings.duraWarn == false then return end
    ns:Fire("TOAST", { kind = "repair",
      title = level == 10 and ("Your gear is almost broken (" .. d .. " %)") or ("Your gear is worn (" .. d .. " %)"),
      text = "Repair at a vendor before the next pull" })
    ns.Sound("sos")
  end
end
ns:On("UPDATE_INVENTORY_DURABILITY", function() C_Timer.After(0.5, checkDurability) end)
ns:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(8, checkDurability) end)

function Tracker:ItemLevel()
  if not GetAverageItemLevel then return nil end
  local _, equipped = ns.S(GetAverageItemLevel)
  if equipped and equipped > 0 then return math.floor(equipped + 0.5) end
end

-- Alt spillersiden trenger om meg selv, i samme form som andre sender det
function Tracker:S3Data()
  local s = self:Me().stats
  local xp, xpMax, rested = self:ReadXP()
  return {
    xp = xp, xpMax = xpMax, rested = rested or 0,
    wXP = s.wk == ns.WeekKey() and (s.wXP or 0) or 0, tXP = s.tXP or 0,
    sessXP = session.xp, sessSec = ns.Now() - session.start,
    money = ns.S(GetMoney), ilvl = self:ItemLevel(),
    today = (s.days or {})[date("%Y-%m-%d")] or 0, streak = self:Streak(s.days),
    zone = topZone(s.zones), at = ns.Now(), dura = ns.Durability(),
  }
end

function Tracker:BuildS3()
  local d = self:S3Data()
  return ns.Comm:Build("S3", ns.pid, d.xp or "", d.xpMax or "", d.rested or 0, math.floor(d.wXP), math.floor(d.tXP),
    math.floor(d.sessXP), math.floor(d.sessSec), d.money or "", d.ilvl or "", math.floor(d.today), d.streak,
    ns.Clean(d.zone or "", 30), d.dura or "")
end

local s3Pending = false
function Tracker:SendS3Soon()
  if s3Pending or not ns.codeHash then return end
  s3Pending = true
  C_Timer.After(30, function()
    s3Pending = false
    ns.Comm:Broadcast(Tracker:BuildS3(), 3)
  end)
end

ns:On("PLAYER_XP_UPDATE", function()
  local xp, xpMax = Tracker:ReadXP()
  local lvl = ns.S(UnitLevel, "player")
  if not xp or not xpMax or not lvl then return end
  if xpState.xp then
    local d
    if xpState.level and lvl > xpState.level then
      d = (xpState.max - xpState.xp) + xp
    else
      d = xp - xpState.xp
    end
    if d > 0 and d < 1000000 then
      session.xp = session.xp + d
      Tracker:AddStat("XP", d)
    end
  end
  xpState.xp, xpState.max, xpState.level = xp, xpMax, lvl
  Tracker:SendS3Soon()
end)

function Tracker:InitXP()
  local xp, xpMax = self:ReadXP()
  xpState.xp, xpState.max, xpState.level = xp, xpMax, ns.S(UnitLevel, "player")
  -- rydd gamle dager (behold 45)
  local s = self:Me().stats
  if s.days then
    local keys = {}
    for k in pairs(s.days) do keys[#keys + 1] = k end
    table.sort(keys)
    for i = 1, #keys - 45 do s.days[keys[i]] = nil end
  end
end

-- Tilleggsstatistikk (levels, PvP-kills, lengste økt) i egen melding
function Tracker:BuildS2()
  local s = self:Me().stats
  rollWeek(s)
  local p = s.prev or {}
  return ns.Comm:Build("S2", ns.pid, s.wk, s.wLevels or 0, s.wKills or 0, s.tLevels or 0, s.tKills or 0,
    math.floor(s.tLongest or 0), p.wk or "", p.Levels or 0, p.Kills or 0, math.floor(s.wNight or 0))
end

-- Levelhistorikk for gjeldende karakter, i biter
function Tracker:SendHistory(target)
  local c, full = self:MyChar()
  local hist = c.hist or {}
  local parts, chunk = {}, {}
  for i, h in ipairs(hist) do
    chunk[#chunk + 1] = math.floor(math.max(0, ns.Now() - h.t)) .. ":" .. h.l .. ":" .. (h.p and math.floor(h.p) or "")
    if #chunk == 14 or i == #hist then
      parts[#parts + 1] = table.concat(chunk, ";")
      chunk = {}
    end
  end
  for i, part in ipairs(parts) do
    local msg = ns.Comm:Build("LH", ns.pid, full, i, #parts, part)
    if target then ns.Comm:SendTo(target, msg, 3) else ns.Comm:Broadcast(msg, 3) end
  end
end

function Tracker:BuildSS()
  local me = self:Me()
  local s = me.stats
  rollWeek(s)
  local c = self:MyChar()
  local p = s.prev or {}
  return ns.Comm:Build("SS", ns.pid, ns.Comm:MyFull(), self:PlayedNow() or c.played or "",
    s.wk, s.wOnline or 0, s.wQuests or 0, s.wGold or 0, s.wDeaths or 0,
    s.tOnline or 0, s.tQuests or 0, s.tGold or 0, s.tDeaths or 0,
    p.wk or "", p.Online or 0, p.Quests or 0, p.Gold or 0, p.Deaths or 0,
    ns.Clean(me.deathZone or "", 30), me.deathAt and (ns.Now() - me.deathAt) or "")
end

function Tracker:SendStatus(prio)
  if not ns.codeHash then return end
  local msg = self:BuildST()
  ns.Comm:Broadcast(msg, prio or 2)
  if Tracker.MarkStatusSent then Tracker:MarkStatusSent(msg) end
  ns:MarkDirty()
end

function Tracker:SendStats(prio)
  if not ns.codeHash then return end
  ns.Comm:Broadcast(self:BuildSS(), prio or 3)
  ns.Comm:Broadcast(self:BuildS2(), 3)
  ns.Comm:Broadcast(self:BuildS3(), 3)
end

-- Status sendes bare når noe har endret seg (sone, status, level …) – ellers hvert
-- minutt som «jeg er her». Posisjon på kartet oppdateres maks hvert 40. sekund.
-- Mindre bakgrunnstrafikk = chat og dings kommer raskere fram.
local lastST = { at = 0, key = nil, pos = nil }
-- PROTO~kode~ST~pid~char~class~race~level~zone~sub~status~session~inInst~mapID~x~y~cont~wx~wy~name~version~alias
local function stKey(msg)
  local f = ns.Split(msg, "~")
  local key = table.concat({ f[5] or "", f[8] or "", f[9] or "", f[10] or "", f[11] or "", f[13] or "", f[14] or "",
    f[20] or "", f[21] or "", f[22] or "" }, "|")
  return key, (f[15] or "") .. "," .. (f[16] or "")
end

function Tracker:MarkStatusSent(msg)
  lastST.at = GetTime()
  lastST.key, lastST.pos = stKey(msg)
end

function Tracker:MaybeSendStatus()
  if not ns.codeHash then return end
  local msg = self:BuildST()
  local key, pos = stKey(msg)
  local age = GetTime() - lastST.at
  local send = key ~= lastST.key or age >= 60 or (pos ~= lastST.pos and age >= 40)
  if not send then return end
  lastST.at, lastST.key, lastST.pos = GetTime(), key, pos
  ns.Comm:Broadcast(msg, 2)
  ns:MarkDirty()
end

local stPending = false
function Tracker:SendStatusSoon()
  if stPending then return end
  stPending = true
  C_Timer.After(3, function()
    stPending = false
    Tracker:SendStatus()
  end)
end

-- Felles hendelse (feed) fra meg
function Tracker:Event(kind, a, b, c, d)
  local id = ns.Comm:NewId()
  local msg = ns.Comm:Build("EV", id, ns.pid, ns.Comm:MyFull(), kind, 0, a or "", b or "", c or "", d or "")
  ns.Comm:Seen(id)
  ns.Data:ApplyEvent(id, ns.pid, ns.Comm:MyFull(), kind, ns.Now(), a, b, c, d)
  ns.Comm:Broadcast(msg, 1)
end

---------------------------------------------------------------------------
-- Profesjoner og oppskrifter
---------------------------------------------------------------------------
function Tracker:ScanProfessions()
  local me = self:Me()
  local list = {}
  pcall(function()
    local a, b, c, d, e = GetProfessions()
    for _, idx in ipairs({ a, b, c, d, e }) do
      if idx then
        local name, _, skill, max = GetProfessionInfo(idx)
        if name then list[#list + 1] = { name = name, skill = skill or 0, max = max or 0 } end
      end
    end
  end)
  -- husk skill ved ukestart, så vi kan vise fremgang denne uka
  me.profWeek = me.profWeek or {}
  if me.profWeek.wk ~= ns.WeekKey() then me.profWeek = { wk = ns.WeekKey(), base = {} } end
  for _, p in ipairs(list) do
    if not me.profWeek.base[p.name] then me.profWeek.base[p.name] = p.skill end
    p.base = me.profWeek.base[p.name]
  end
  me.profs = list
  return list
end

function Tracker:SendProfessions()
  if not ns.codeHash then return end
  local parts = {}
  for _, p in ipairs(self:ScanProfessions()) do
    parts[#parts + 1] = ns.Clean(p.name, 20):gsub("[:;]", "") .. ":" .. p.skill .. ":" .. p.max .. ":" .. (p.base or p.skill)
  end
  ns.Comm:Broadcast(ns.Comm:Build("PF", ns.pid, table.concat(parts, ";")), 3)
end

function Tracker:ScanRecipes()
  if not C_TradeSkillUI or not C_TradeSkillUI.GetAllRecipeIDs then return end
  local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
  if not ok or type(ids) ~= "table" then return end
  local profName
  pcall(function()
    local info = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    profName = info and info.professionName
  end)
  if not profName or profName == "" then return end
  local learned = {}
  for _, id in ipairs(ids) do
    local ok2, info = pcall(C_TradeSkillUI.GetRecipeInfo, id)
    if ok2 and info and info.learned then learned[#learned + 1] = id end
  end
  table.sort(learned)
  local me = self:Me()
  me.recipes = me.recipes or {}
  local old = me.recipes[profName]
  local changed = not old or #old ~= #learned
  if not changed then
    for i = 1, #learned do if old[i] ~= learned[i] then changed = true break end end
  end
  me.recipes[profName] = learned
  if changed then self:SendRecipes(profName) end
end

function Tracker:SendRecipes(profName)
  local me = self:Me()
  local list = me.recipes and me.recipes[profName]
  if not list or not ns.codeHash then return end
  local chunk, part = {}, 1
  local total = math.max(1, math.ceil(#list / 30))
  for i, id in ipairs(list) do
    chunk[#chunk + 1] = id
    if #chunk == 30 or i == #list then
      ns.Comm:Broadcast(ns.Comm:Build("PR", ns.pid, ns.Clean(profName, 20), part, total, table.concat(chunk, ",")), 3)
      chunk, part = {}, part + 1
    end
  end
end

---------------------------------------------------------------------------
-- Spillhendelser
---------------------------------------------------------------------------
local function tick()
  local t = GetTime()
  if lastTick then
    local dt = t - lastTick
    if dt > 0 and dt < 120 then
      Tracker:AddStat("Online", dt)
      -- nattugle: tid mellom midnatt og 05
      if tonumber(date("%H")) < 5 then Tracker:AddStat("Night", dt) end
      local st = Tracker:Me().stats
      local len = ns.Now() - session.start
      if len > (st.tLongest or 0) then st.tLongest = len end
      -- tid per dag (til streak og «i dag») og per sone
      st.days = st.days or {}
      local day = date("%Y-%m-%d")
      st.days[day] = (st.days[day] or 0) + dt
      local zone = Tracker:Me().live and Tracker:Me().live.zone
      if zone and zone ~= "" then
        st.zones = st.zones or {}
        st.zones[zone] = (st.zones[zone] or 0) + dt
      end
      local c = Tracker:MyChar()
      if c.played then c.played = c.played + dt end
    end
  end
  lastTick = t
end

function Tracker:Start()
  -- /reload eller rask re-innlogging fortsetter samme økt (ellers «logger vi på» på nytt)
  local t = ns.Now()
  if ns.db.sessionStart and ns.db.lastAliveAt and (t - ns.db.lastAliveAt) < 180 then
    session.start = ns.db.sessionStart
  else
    session.start = t
  end
  ns.db.sessionStart = session.start
  session.startLevel = ns.S(UnitLevel, "player") or 1
  lastMoney = ns.S(GetMoney)
  lastTick = GetTime()
  self:RefreshCharInfo()
  self:UpdateLive()
  rollWeek(self:Me().stats)
  self:InitKills()
  self:InitXP()

  C_Timer.NewTicker(15, tick)
  C_Timer.NewTicker(20, function() Tracker:MaybeSendStatus() end)
  C_Timer.NewTicker(180, function() Tracker:SendStats() end)
  -- husk økten løpende, slik at oppsummeringen kan vises ved neste innlogging
  C_Timer.NewTicker(20, function() Tracker:SaveSession() end)
end

function Tracker:SessionSummary()
  local played = ns.Now() - session.start
  return {
    char = ns.Comm:MyFull(), at = ns.Now(), online = played,
    levels = math.max(0, (ns.S(UnitLevel, "player") or session.startLevel or 1) - (session.startLevel or 1)),
    quests = session.quests, gold = session.gold, deaths = session.deaths, sos = session.sos,
  }
end

function Tracker:SaveSession()
  ns.db.lastAliveAt = ns.Now()
  if (ns.Now() - session.start) < 120 then return end
  ns.db.lastSession = self:SessionSummary()
end

ns:On("TIME_PLAYED_MSG", function(total, thisLevel)
  if ns.isSecret(total) then return end
  local c = Tracker:MyChar()
  c.played = total
  c.playedAt = ns.Now()
  if type(thisLevel) == "number" and not ns.isSecret(thisLevel) then
    c.playedLevel, c.playedLevelAt = thisLevel, ns.Now()
  end
end)

-- /played on this level, ticking live (nil until the game has told us once this session)
function Tracker:TimeThisLevel()
  local c = self:MyChar()
  if not c.playedLevel or not c.playedLevelAt then return nil end
  if c.playedLevelAt < (ns.db.sessionStart or 0) - 5 then return nil end
  return c.playedLevel + math.max(0, ns.Now() - c.playedLevelAt)
end

ns:On("PLAYER_LEVEL_UP", function(level)
  if ns.isSecret(level) then return end
  local c = Tracker:MyChar()
  c.level = level
  c.hist = c.hist or {}
  table.insert(c.hist, { t = ns.Now(), l = level, p = c.played })
  c.prevLevelTime = Tracker:TimeThisLevel()
  c.playedLevel, c.playedLevelAt = 0, ns.Now()
  while #c.hist > 80 do table.remove(c.hist, 1) end
  session.levels = session.levels + 1
  Tracker:AddStat("Levels", 1)
  -- achievement-tellere
  local h = tonumber(date("%H"))
  if h and h < 5 then ns.CntFlag("dingNight") end
  if ns.S(IsInInstance) then ns.CntFlag("dingDungeon") end
  if (ns.S(GetXPExhaustion) or 0) > 0 then ns.CntFlag("dingRested") end
  ns.Cnt("levelsNoDeath")
  ns.CntMax("bestLevelsNoDeath", ns.db.cnt.levelsNoDeath or 0)
  session.lastDingAt = ns.Now()
  Tracker:Event("DING", level, Tracker:PlayedNow() or "")
  Tracker:SendStatusSoon()
end)

ns:On("PLAYER_DEAD", function()
  local me = Tracker:Me()
  local loc = Tracker:Location()
  local zone = loc.zone ~= "" and loc.zone or "unknown place"
  if loc.sub and loc.sub ~= "" and not loc.inInst then zone = loc.sub .. ", " .. zone end
  me.deathZone = zone
  me.deathAt = ns.Now()
  session.deaths = session.deaths + 1
  Tracker:AddStat("Deaths", 1)
  -- achievement-tellere
  ns.CntDay("deathsDay")
  ns.CntMax("bestDayDeaths", (ns.db.cnt.deathsDay or {})[date("%Y-%m-%d")] or 0)
  ns.db.cnt.deathsByZone = ns.db.cnt.deathsByZone or {}
  local dz = (loc.zone ~= "" and loc.zone) or "?"
  ns.db.cnt.deathsByZone[dz] = (ns.db.cnt.deathsByZone[dz] or 0) + 1
  ns.CntMax("maxDeathsZone", ns.db.cnt.deathsByZone[dz])
  if ns.Now() - session.start < 120 then ns.CntFlag("deathAfterLogin") end
  if session.lastDingAt and ns.Now() - session.lastDingAt < 120 then ns.CntFlag("deathAfterDing") end
  if loc.inInst then ns.CntFlag("deathDungeon") end
  if (ns.S(UnitLevel, "player") or 0) >= 60 then ns.CntFlag("deathAt60") end
  ns.db.cnt.levelsNoDeath = 0
  Tracker:Event("DEAD", ns.Clean(zone, 40))
  Tracker:SendStats(2)
end)

ns:On("QUEST_TURNED_IN", function()
  session.quests = session.quests + 1
  Tracker:AddStat("Quests", 1)
  ns.CntDay("questsDay")
  ns.CntMax("bestDayQuests", (ns.db.cnt.questsDay or {})[date("%Y-%m-%d")] or 0)
  ns:MarkDirty()
end)

ns:On("PLAYER_MONEY", function()
  local m = ns.S(GetMoney)
  if not m then return end
  if lastMoney and m > lastMoney then
    local diff = m - lastMoney
    session.gold = session.gold + diff
    Tracker:AddStat("Gold", diff)
  end
  lastMoney = m
end)

for _, ev in ipairs({ "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_FLAGS_CHANGED" }) do
  ns:On(ev, function() Tracker:SendStatusSoon() end)
end

-- PvP-kills (honorable kills), hvis spillet gir addons tilgang
local lastHK
local function readHK()
  if not GetPVPLifetimeStats then return nil end
  local ok, hk = pcall(GetPVPLifetimeStats)
  if ok and type(hk) == "number" and not ns.isSecret(hk) then return hk end
end
function Tracker:InitKills() lastHK = readHK() end
ns:On("PLAYER_PVP_KILLS_CHANGED", function()
  local hk = readHK()
  if hk and lastHK and hk > lastHK then
    Tracker:AddStat("Kills", hk - lastHK)
    ns:MarkDirty()
  end
  if hk then lastHK = hk end
end)

ns:On("NEW_MOUNT_ADDED", function()
  Tracker:Event("MOUNT")
  ns.Cnt("mounts")
  if (ns.S(UnitLevel, "player") or 60) < 40 then ns.CntFlag("mountBefore40") end
end)

-- antall mounts du allerede har (hvis spillet gir tilgang)
function Tracker:CountMounts()
  if not (C_MountJournal and C_MountJournal.GetMountIDs) then return end
  local ok, ids = pcall(C_MountJournal.GetMountIDs)
  if not ok or type(ids) ~= "table" then return end
  local n = 0
  for _, id in ipairs(ids) do
    local ok2, _, _, _, _, _, _, _, _, _, _, collected = pcall(C_MountJournal.GetMountInfoByID, id)
    if ok2 and collected and not ns.isSecret(collected) then n = n + 1 end
  end
  ns.CntMax("mounts", n)
end

ns:On("SKILL_LINES_CHANGED", function()
  if not Tracker.profTimer then
    Tracker.profTimer = true
    C_Timer.After(10, function()
      Tracker.profTimer = nil
      Tracker:SendProfessions()
    end)
  end
end)

ns:On("TRADE_SKILL_LIST_UPDATE", function()
  if Tracker.recipeTimer then return end
  Tracker.recipeTimer = true
  C_Timer.After(2, function()
    Tracker.recipeTimer = nil
    Tracker:ScanRecipes()
  end)
end)

-- Loot: del episke (eller blå, om valgt) ting du får
local lootPatterns
local function buildLootPatterns()
  lootPatterns = {}
  for _, key in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE" }) do
    local s = _G[key]
    if type(s) == "string" then
      -- "%s" i Blizzards tekst blir til (.+), "%d" til tall
      local pat = s:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", "(.+)"):gsub("%%d", "%%d+")
      lootPatterns[#lootPatterns + 1] = "^" .. pat
    end
  end
end

ns:On("CHAT_MSG_LOOT", function(text)
  if type(text) ~= "string" or ns.isSecret(text) then return end
  if not lootPatterns then buildLootPatterns() end
  for _, pat in ipairs(lootPatterns) do
    local link = text:match(pat)
    if link then
      local itemID = tonumber(link:match("item:(%d+)"))
      if not itemID then return end
      local quality = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemID)
      if quality and quality >= (ns.db.settings.lootMinQuality or 4) then
        Tracker:Event("LOOT", itemID, quality)
        if quality >= 4 then ns.Cnt("epics") end
      end
      return
    end
  end
end)

ns:On("PLAYER_CAMPING", function()
  Tracker:SaveSession()
  ns:Fire("SHOW_SUMMARY", Tracker:SessionSummary(), false)
end)

ns:On("PLAYER_LOGOUT", function()
  Tracker:SaveSession()
  -- si ha det direkte (køen rekker ikke å gå), så de andre ser oss offline med en gang
  pcall(function() ns.Comm:SendBye() end)
  if ns.db then ns.db.lastSessionShown = false end
end)

-- Bytte av sone kan også bety bytte av layer (annen backend): koble til på nytt
ns:On("ZONE_CHANGED_NEW_AREA", function() ns.Comm:OnWorldChanged() end)
