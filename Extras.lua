-- Chillan? – group radar, ready check, dungeon log, chronicle and gang notes on the map
local ADDON, ns = ...
local X = {}
ns.Extras = X
local Comm = ns.Comm

---------------------------------------------------------------------------
-- Gruppe-radar: kompis på omtrent samme level i samme sone, og dere er ikke i gruppe
---------------------------------------------------------------------------
local radarSeen = {}
function X:Radar()
  if not ns.db.settings.radar or not ns.codeHash then return end
  local me = ns.Tracker:Me()
  local L = me.live or {}
  if L.inInst or not L.zone or L.zone == "" then return end
  -- (1.4.75) already in a group: no "quest together?" popups
  if (IsInGroup and IsInGroup()) or (GetNumGroupMembers and (GetNumGroupMembers() or 0) > 0) then return end
  local myLvl = ns.S(UnitLevel, "player") or 0
  for pid, p in pairs(ns.db.people) do
    local pl = p.live or {}
    local c = ns:PersonChar(p) or {}
    if pid ~= ns.pid and p.main and ns:IsOnline(p) and not pl.inInst and pl.zone == L.zone
      and c.level and math.abs(c.level - myLvl) <= 3 and not ns.InMyGroup(p) then
      local key = pid .. "|" .. L.zone
      if not radarSeen[key] or (ns.Now() - radarSeen[key]) > 1800 then
        radarSeen[key] = ns.Now()
        ns:Fire("TOAST", { kind = "radar", pid = pid, char = pl.char or p.main,
          title = ns:ShortWho(p) .. " is also in " .. L.zone,
          text = "Level " .. c.level .. (pl.sub and pl.sub ~= "" and (" · " .. pl.sub) or "") .. " – quest together?" })
      end
    end
  end
end

---------------------------------------------------------------------------
-- Klar-sjekk før dungeon: bag-plasser, holdbarhet, mat og drikke
---------------------------------------------------------------------------
function X:MyReadiness()
  local free, total = 0, 0
  local food = 0
  local api = C_Container
  for bag = 0, 4 do
    local nSlots = api and ns.S(api.GetContainerNumSlots, bag) or 0
    local nFree = api and ns.S(api.GetContainerNumFreeSlots, bag) or 0
    total, free = total + (nSlots or 0), free + (nFree or 0)
    for slot = 1, (nSlots or 0) do
      local info = api.GetContainerItemInfo and ns.S(api.GetContainerItemInfo, bag, slot)
      if type(info) == "table" and info.itemID then
        local _, _, _, _, _, classID, subclassID = ns.S(C_Item.GetItemInfoInstant, info.itemID)
        if classID == 0 and subclassID == 5 then food = food + (info.stackCount or 1) end
      end
    end
  end
  local low
  for slot = 1, 18 do
    local cur, max = ns.S(GetInventoryItemDurability, slot)
    if cur and max and max > 0 then
      local pct = cur / max * 100
      if not low or pct < low then low = pct end
    end
  end
  return { free = free, total = total, dur = low and math.floor(low) or 100, food = food }
end

X.ready = {}
function X:StartReadyCheck()
  if not ns.codeHash then return end
  local id = Comm:NewId()
  self.readyId = id
  self.ready = { [ns.pid] = self:MyReadiness() }
  self.readyGroup = (ns.S(GetNumGroupMembers) or 0) > 0
  Comm:Broadcast(Comm:Build("RC", id, ns.pid, self.readyGroup), 1)
  ns:Fire("READY_UPDATE")
  if ns.Overlays.ShowReady then ns.Overlays:ShowReady() end
end

Comm:Handle("RC", function(f, sender)
  local id, pid, group = f[1], f[2], f[3] == "1"
  if not pid or pid == ns.pid then return end
  local p = ns:GetPerson(pid)
  if group and not ns.InMyGroup(p) then return end
  local r = X:MyReadiness()
  Comm:SendTo(sender, Comm:Build("RR", id, ns.pid, r.free, r.total, r.dur, r.food), 1)
end)

Comm:Handle("RR", function(f)
  if f[1] ~= X.readyId or not f[2] then return end
  X.ready[f[2]] = { free = tonumber(f[3]) or 0, total = tonumber(f[4]) or 0, dur = tonumber(f[5]) or 100, food = tonumber(f[6]) or 0 }
  ns:Fire("READY_UPDATE")
end)

---------------------------------------------------------------------------
-- Dungeon-logg: tid, dødsfall, bosser og hvem fra gjengen som var med
---------------------------------------------------------------------------
local run
-- the dungeon or raid run in progress (Gang pulse reads time, bosses and deaths from it)
function X:CurrentRun() return run end
local function gangInGroup()
  local pids = { ns.pid }
  local n = ns.S(GetNumGroupMembers) or 0
  if n == 0 then return pids end
  local byName = {}
  for pid, p in pairs(ns.db.people) do
    for _, c in pairs(p.chars or {}) do if c.name then byName[c.name] = pid end end
  end
  local prefix = (ns.S(IsInRaid) and "raid") or "party"
  local seen = { [ns.pid] = true }
  for i = 1, n do
    local name = ns.S(UnitName, prefix .. i)
    local pid = name and byName[name]
    if pid and not seen[pid] then seen[pid] = true pids[#pids + 1] = pid end
  end
  return pids
end
X.GangInGroup = gangInGroup

-- one of the gang in the group posts (the lowest id), so lines don't come twice
local function iPost()
  local m = gangInGroup()
  table.sort(m)
  return m[1] == ns.pid, #m
end

-- (1.4.0) the gang's best time for this dungeon/raid before this run (from the feed)
function X:BestFor(name, kind)
  local rr = ns.Bosses and ns.Bosses.RunRecord and ns.Bosses:RunRecord(name)
  local best = (kind or "DUNGEON") == "DUNGEON" and rr and rr.s or nil
  for _, it in ipairs(ns.db.feed or {}) do
    if it.kind == (kind or "DUNGEON") and it.a == name then
      local d = tonumber(it.b)
      if d and d > 0 and (not best or d < best) then best = d end
    end
  end
  return best
end

-- the card when a run ends: bosses, time, XP, loot value, deaths, wipes, best drop, most deaths…
function X:RunSummary(r)
  r = r or run
  if not r then return nil end
  local n, total = ns.Bosses:Count(r.name, r.killed)
  local _, pr = ns.Pulse:Run()
  local floorName, floorN = nil, 0
  for name, k in pairs(r.deathsBy or {}) do if k > floorN then floorName, floorN = name, k end end
  local fastName, fastSecs
  for name, secs in pairs(r.killed or {}) do
    if type(secs) == "number" and secs > 5 and (not fastSecs or secs < fastSecs) then fastName, fastSecs = name, secs end
  end
  local bestDrop, bestQ = nil, -1
  for _, link in ipairs(pr and pr.items or {}) do
    local q = ns.Pulse.LinkQuality(link)
    if q > bestQ then bestDrop, bestQ = link, q end
  end
  for _, g in ipairs(r.gangLoot or {}) do
    local q = ns.Pulse.LinkQuality(g.link)
    if q > bestQ then bestDrop, bestQ = g.link, q end
  end
  local dur = (r.endAt or ns.Now()) - r.start
  local best = self:BestFor(r.name, r.raid and "RAID" or "DUNGEON")
  return { name = r.name, raid = r.raid, dur = dur, bosses = n, total = total, deaths = r.deaths or 0,
    wipes = r.wipes or 0, xp = pr and pr.xp or 0, value = ns.Pulse:LootValue(pr),
    floor = floorName, floorN = floorN, fast = fastName, fastSecs = fastSecs,
    drop = bestDrop, dropQ = bestQ, record = best and dur < best and n >= (total or n) or false, best = best,
    gangLoot = r.gangLoot }
end

local function finishRun()
  if not run then return end
  local r = run
  run = nil
  ns.db.curRun = nil
  local dur = (r.endAt or ns.Now()) - r.start
  if dur < 180 or r.bosses == 0 then return end
  r.dur = dur
  r.members = gangInGroup()
  ns.db.runs = ns.db.runs or {}
  ns.PushCapped(ns.db.runs, r, 60)
  table.sort(r.members)
  -- the card, if the last boss didn't already show it
  if not r.cardShown then
    local sum = X:RunSummary(r)
    if sum then ns:Fire("RUN_CARD", sum) end
  end
  if r.members[1] == ns.pid and not r.posted then
    if r.raid then
      local _, total = ns.Bosses:Count(r.name, r.killed)
      ns.Tracker:Event("RAID", r.name, math.floor(dur), r.wipes or 0, r.bosses .. "/" .. (total or "?") .. "|" .. #r.members)
    else
      ns.Tracker:Event("DUNGEON", r.name, math.floor(dur), r.deaths, r.bosses .. "|" .. table.concat(r.members, ","))
    end
  end
end

local function onWorld()
  local inInst, kind = ns.S(IsInInstance)
  if inInst and (kind == "party" or kind == "raid") then
    local name = ns.S(GetInstanceInfo)
    local instID = select(8, ns.S(GetInstanceInfo))
    ns.Bosses.curInstID = (type(instID) == "number" and not ns.isSecret(instID)) and instID or nil
    if name and (not run or run.name ~= name) then
      finishRun()
      -- after /reload inside the same dungeon: carry on with the saved run (time, bosses, deaths)
      local saved = ns.db.curRun
      if saved and saved.name == name and saved.char == ns.Comm:MyFull() and (ns.Now() - (saved.seen or 0)) < 1800 then
        run = saved
      else
        run = { name = name, start = ns.Now(), deaths = 0, bosses = 0, char = ns.Comm:MyFull() }
      end
      run.raid = kind == "raid"
      run.killed = run.killed or {}
      run.deathsBy = run.deathsBy or {}
      run.wipes = run.wipes or 0
      run.gangLoot = run.gangLoot or {}
      run.seen = ns.Now()
      ns.db.curRun = run
    end
  elseif run then
    -- left the dungeon: often just a death + corpse run or a hearth to repair. (1.4.62) The run
    -- ends at once when you leave the group, the group is mostly new people, the dungeon is reset
    -- or you queue for another; otherwise after 5 minutes outside (not counting time dead).
    if not run.leftAt then
      run.leftAt = ns.Now()
      run.outGroup, run.outN = X.GroupNames()
    end
  end
  if run and inInst and (kind == "party" or kind == "raid") then run.leftAt, run.outGroup, run.outN, run.deadFor = nil, nil, nil, nil end
  X.CheckRunEnd()
end

-- the names in your group right now (outside a dungeon they can be read)
function X.GroupNames()
  local out, n = {}, 0
  local num = ns.S(GetNumGroupMembers) or 0
  local raid = ns.S(IsInRaid)
  for i = 1, math.min(40, num) do
    local u = raid and ("raid" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
    local nm = ns.S(UnitName, u)
    if type(nm) == "string" and nm ~= "" then out[nm] = true n = n + 1 end
  end
  return out, n
end

X.RUN_FALLBACK = 300
local function endRun(why)
  if not run then return end
  run.endAt = run.leftAt or ns.Now()
  run.endWhy = why
  finishRun()
end
-- (1.4.62) has the run you walked out of ended? Only while you're outside it
function X.CheckRunEnd()
  if not run or not run.leftAt then return end
  -- left the group (or it broke up); a solo run waits for the fallback (corpse runs)
  if (run.outN or 0) > 1 and not ns.S(IsInGroup) then return endRun("left the group") end
  -- the group is mostly new people
  local was = run.outGroup
  if was then
    local now, n = X.GroupNames()
    local new = 0
    for nm in pairs(now) do if not was[nm] then new = new + 1 end end
    if n > 1 and new * 2 > n then return endRun("new group") end
  end
  -- queued for another dungeon
  if GetLFGMode and LE_LFG_CATEGORY_LFD then
    local ok, mode = pcall(GetLFGMode, LE_LFG_CATEGORY_LFD)
    if ok and (mode == "queued" or mode == "proposal") then return endRun("queued") end
  end
end

C_Timer.NewTicker(5, function()
  if not run or not run.leftAt then return end
  X.CheckRunEnd()
  if not run or not run.leftAt then return end
  -- time spent dead outside doesn't count (a corpse run)
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
    run.deadFor = (run.deadFor or 0) + 5
    return
  end
  if ns.Now() - run.leftAt - (run.deadFor or 0) > X.RUN_FALLBACK then endRun("5 minutes outside") end
end)
ns:On("GROUP_ROSTER_UPDATE", function() C_Timer.After(1, X.CheckRunEnd) end)
ns:On("GROUP_LEFT", function() C_Timer.After(1, X.CheckRunEnd) end)
ns:On("LFG_UPDATE", function() C_Timer.After(1, X.CheckRunEnd) end)
-- "Wailing Caverns has been reset."
ns:On("CHAT_MSG_SYSTEM", function(msg)
  if not run or type(msg) ~= "string" or ns.isSecret(msg) then return end
  local fmt = INSTANCE_RESET_SUCCESS or "%s has been reset."
  local pat = "^" .. fmt:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
  local name = msg:match(pat)
  if name and name == run.name then endRun("reset") end
end)

ns:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(2, onWorld) end)
ns:On("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(2, onWorld) end)
C_Timer.NewTicker(60, function() if run then run.seen = ns.Now() end end)
ns:On("PLAYER_LOGOUT", function() if run then run.seen = ns.Now() end end)

-- (1.4.0) deaths in the group: who's dead now vs a second ago (the combat log is closed to addons)
local deadNow = {}
local function groupUnits()
  local units = { "player" }
  local n = ns.S(GetNumGroupMembers) or 0
  if ns.S(IsInRaid) then
    for i = 1, math.min(40, n) do units[#units + 1] = "raid" .. i end
  else
    for i = 1, math.min(4, math.max(0, n - 1)) do units[#units + 1] = "party" .. i end
  end
  return units
end
local function countDeath(name)
  if not run then return end
  run.deaths = (run.deaths or 0) + 1
  run.deathsBy[name] = (run.deathsBy[name] or 0) + 1
  if run.pullAt then run.fightDeaths = (run.fightDeaths or 0) + 1 end
  ns:Fire("PULSE")
end
local lastOwnDeath = 0
C_Timer.NewTicker(1, function()
  if not run or run.leftAt then deadNow = {} return end
  local now = {}
  for _, u in ipairs(groupUnits()) do
    local name = ns.S(UnitName, u)
    local dead = ns.S(UnitIsDeadOrGhost, u)
    if type(name) == "string" and name ~= "" and dead == true then
      now[name] = true
      if not deadNow[name] then
        if u == "player" then
          if GetTime() - lastOwnDeath > 5 then countDeath(name) end
          lastOwnDeath = GetTime()
        else
          countDeath(name)
        end
      end
    end
  end
  deadNow = now
end)
-- your own death, in case the group check can't see it (secret value mid-fight)
ns:On("PLAYER_DEAD", function()
  if not run or GetTime() - lastOwnDeath < 5 then return end
  lastOwnDeath = GetTime()
  countDeath(ns.S(UnitName, "player") or "you")
end)

-- boss pulls and kills: the time each kill took, wipes, and a line in the feed
ns:On("ENCOUNTER_START", function(id, name)
  if not run then return end
  run.pullAt, run.pullName, run.fightDeaths = GetTime(), (type(name) == "string" and not ns.isSecret(name)) and name or nil, 0
  X.inEncounter = true
  ns:Fire("PULSE")
end)
ns:On("ENCOUNTER_END", function(id, name, _, _, success)
  X.inEncounter = false
  X.lastEncounter = (ns.isSecret(name) and "?" or tostring(name)) .. " (" .. (ns.isSecret(success) and "?" or tostring(success)) .. ") " .. date("%H:%M")
  if not run then return end
  -- (1.4.12) the journal's name for this encounter, so the list and the kill always match
  local canon = (not ns.isSecret(id)) and ns.Bosses.EncounterName(id)
  if canon then name = canon end
  local okName = type(name) == "string" and not ns.isSecret(name) and name ~= ""
  if ns.isSecret(success) then success = nil end
  local secs = run.pullAt and math.floor(GetTime() - run.pullAt + 0.5) or nil
  local fightDeaths = run.fightDeaths or 0
  run.pullAt = nil
  if success == 1 then
    run.bosses = run.bosses + 1
    if okName then
      run.lastBoss = name
      run.killed[name] = secs or true
      run.tries = run.tries or {}
      local tries = (run.tries[name] or 0) + 1
      ns.Bosses:Learn(run.name, name)
      -- the line for the gang, after the fight (addon messages are blocked during a boss fight)
      local poster, gangN = iPost()
      if poster then
        local others = {}
        for _, pid in ipairs(gangInGroup()) do if pid ~= ns.pid then others[#others + 1] = pid end end
        C_Timer.After(3, function()
          ns.Tracker:Event("BOSS", run and run.name or "", name, secs or 0,
            fightDeaths .. ":" .. tries .. ":" .. gangN .. ":" .. table.concat(others, ","))
        end)
      end
      -- last boss down: the run card
      local n, total = ns.Bosses:Count(run.name, run.killed)
      if total and n >= total and not run.cardShown then
        run.cardShown = true
        run.endAt = ns.Now()
        local sum = X:RunSummary(run)
        run.endAt = nil
        C_Timer.After(2, function() if sum then ns:Fire("RUN_CARD", sum) end end)
        -- (1.4.3) the end-of-run line right away, not when you leave
        local r = run
        C_Timer.After(5, function()
          if r.posted then return end
          r.posted = true
          local dur = math.floor(ns.Now() - r.start)
          local members = gangInGroup()
          table.sort(members)
          if members[1] ~= ns.pid then return end
          if r.raid then
            ns.Tracker:Event("RAID", r.name, dur, r.wipes or 0, r.bosses .. "/" .. (total or "?") .. "|" .. #members)
          else
            ns.Tracker:Event("DUNGEON", r.name, dur, r.deaths, r.bosses .. "|" .. table.concat(members, ","))
          end
        end)
      end
    end
  elseif success == 0 then
    run.wipes = (run.wipes or 0) + 1
    if okName then run.tries = run.tries or {} run.tries[name] = (run.tries[name] or 0) + 1 end
  end
  ns:Fire("PULSE")
end)

-- loot the gang gets in a raid (the gang's epics, not the whole raid's)
local otherLoot
ns:On("CHAT_MSG_LOOT", function(msg)
  if not run or not run.raid or type(msg) ~= "string" or ns.isSecret(msg) then return end
  if not otherLoot then
    local f = (LOOT_ITEM or "%s receives loot: %s."):gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    f = f:gsub("%%%%s", "(.+)")
    otherLoot = "^" .. f
  end
  local who, link = msg:match(otherLoot)
  if not who then return end
  link = link:gsub("x%d+$", "")
  if ns.Pulse.LinkQuality(link) < 4 then return end
  local gang = false
  for _, p in pairs(ns.db.people) do
    for _, c in pairs(p.chars or {}) do if c.name == who then gang = true end end
  end
  if gang then
    ns.PushCapped(run.gangLoot, { who = who, link = link, t = ns.Now() }, 20)
    ns:Fire("PULSE")
  end
end)

-- Raskeste run per dungeon (fra feeden)
function X:DungeonRecords()
  local best = {}
  for _, it in ipairs(ns.db.feed or {}) do
    if it.kind == "DUNGEON" and it.a then
      local dur = tonumber(it.b)
      if dur and (not best[it.a] or dur < best[it.a].dur) then best[it.a] = { name = it.a, dur = dur, item = it } end
    end
  end
  local out = {}
  for _, v in pairs(best) do out[#out + 1] = v end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

function X:RunMembers(it)
  local list = {}
  local _, members = (it.d or ""):match("^(%d*)|?(.*)$")
  for _, pid in ipairs(ns.Split(members or "", ",")) do
    local p = pid ~= "" and ns:GetPerson(pid)
    if p then list[#list + 1] = p end
  end
  return list
end

---------------------------------------------------------------------------
-- Krønike: gjengens store øyeblikk, eldste først
---------------------------------------------------------------------------
local FIRST_TEXT = {
  MOUNT = "first in the gang with a mount", EPIC = "first in the gang with an epic drop",
}
function X:Chronicle()
  local out = {}
  for key, f in pairs(ns.db.firsts or {}) do
    local lvl = key:match("^L(%d+)$")
    local dg = key:match("^DG:(.+)$")
    local text, icon, color
    if lvl then text, icon, color = "first in the gang to level " .. lvl, "Up", "5FD18B"
    elseif dg then text, icon, color = "first through " .. dg, "Shield", "8FB8E8"
    elseif FIRST_TEXT[key] then text, icon, color = FIRST_TEXT[key], "Star", key == "EPIC" and "A335EE" or "E0B04F" end
    if text then out[#out + 1] = { t = f.t, pid = f.pid, char = f.char, text = text, icon = icon, color = color } end
  end
  for _, e in ipairs(ns.db.chronicle or {}) do out[#out + 1] = e end
  table.sort(out, function(a, b) return (a.t or 0) > (b.t or 0) end)
  return out
end

function X:AddChronicle(key, t, pid, char, text, icon, color)
  ns.db.chronicle = ns.db.chronicle or {}
  for _, e in ipairs(ns.db.chronicle) do if e.key == key then return end end
  ns.PushCapped(ns.db.chronicle, { key = key, t = t, pid = pid, char = char, text = text, icon = icon, color = color }, 200)
end

---------------------------------------------------------------------------
-- Gjeng-notater på kartet (Alt + høyreklikk på verdenskartet)
---------------------------------------------------------------------------
X.NOTE_KINDS = {
  { key = "gank", name = "Ganked here", icon = "Target", color = "F2777A" },
  { key = "rare", name = "Rare", icon = "Star", color = "B9AEDB" },
  { key = "herb", name = "Herbs / ore", icon = "Star", color = "5FD18B" },
  { key = "meet", name = "Meeting spot", icon = "Friends", color = "8FB8E8" },
  { key = "text", name = "Note", icon = "Mail", color = "E0B04F" },
}
X.noteKind = {}
for _, k in ipairs(X.NOTE_KINDS) do X.noteKind[k.key] = k end

local function buildNote(n)
  return Comm:Build("MN", n.id, n.pid, n.char, n.mapID, math.floor(n.x * 1000), math.floor(n.y * 1000), n.kind,
    math.max(0, math.floor(n.exp - ns.Now())), ns.Clean(n.text or "", 80))
end

function X:AddNote(mapID, x, y, kind, text, days)
  if not ns.codeHash or not mapID then return end
  days = math.max(1, math.min(7, tonumber(days) or 3))
  local n = { id = Comm:NewId(), pid = ns.pid, char = Comm:MyFull(), mapID = mapID, x = x, y = y, kind = kind,
    text = ns.Clean(text or "", 80), exp = ns.Now() + days * 86400, t = ns.Now() }
  ns.db.notes = ns.db.notes or {}
  ns.db.notes[n.id] = n
  Comm:Seen(n.id)
  Comm:Broadcast(buildNote(n), 2)
  ns:Fire("MAP_PINS")
  ns.Print("Gang note added (" .. (X.noteKind[kind] or X.noteKind.text).name .. ", " .. days .. " d).")
end

function X:RemoveNote(id)
  local n = ns.db.notes and ns.db.notes[id]
  if not n then return end
  ns.db.notes[id] = nil
  Comm:Broadcast(Comm:Build("MD", id), 2)
  ns:Fire("MAP_PINS")
end

function X:ExpireNotes()
  for id, n in pairs(ns.db.notes or {}) do
    if (n.exp or 0) < ns.Now() then ns.db.notes[id] = nil end
  end
end

function X:SendNotes(target)
  self:ExpireNotes()
  for _, n in pairs(ns.db.notes or {}) do Comm:SendTo(target, buildNote(n), 3) end
end

Comm:Handle("MN", function(f)
  local id = f[1]
  if not id or id == "" then return end
  ns.db.notes = ns.db.notes or {}
  local isNew = ns.db.notes[id] == nil
  local left = tonumber(f[8]) or 0
  if left <= 0 then return end
  ns.db.notes[id] = { id = id, pid = f[2], char = f[3], mapID = tonumber(f[4]), x = (tonumber(f[5]) or 0) / 1000,
    y = (tonumber(f[6]) or 0) / 1000, kind = f[7], exp = ns.Now() + left, text = f[9] or "" }
  -- bare ferske notater (rett etter at de ble laget) varsles i hendelsesvinduet
  if isNew and f[7] == "gank" and (left % 86400) > 86400 - 900 then
    local p = ns:GetPerson(f[2]) or {}
    local zone = C_Map.GetMapInfo and ns.S(C_Map.GetMapInfo, tonumber(f[4]) or 0)
    ns:Fire("FEEDEVENT", ns.UI.InlineIcon("Target", "F2777A", 12) .. "  " .. ns:ShortWho(p, f[3])
      .. ns.Colorize(" got ganked" .. ((type(zone) == "table" and zone.name) and (" in " .. zone.name) or ""), ns.C.text2)
      .. ((f[9] and f[9] ~= "") and (": " .. f[9]) or ""))
  end
  ns:Fire("MAP_PINS")
end)

Comm:Handle("MD", function(f)
  if ns.db.notes and f[1] then ns.db.notes[f[1]] = nil ns:Fire("MAP_PINS") end
end)

function X:Start()
  self:ExpireNotes()
  C_Timer.NewTicker(60, function() X:Radar() end)
  C_Timer.NewTicker(600, function() X:ExpireNotes() end)
end
