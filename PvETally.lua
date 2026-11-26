-- Chillan? – dungeons and raids per person (1.4.72), for the Player page. Counted from the gang's
-- run and boss posts as they arrive (kept, unlike the feed, which only holds the latest 150), and
-- once from what the feed still has. Everyone in the post counts, not only the one who posted it.
local ADDON, ns = ...
local T = {}
ns.PvETally = T

-- a boss "killed" in less than this was already dead or the timer missed the pull: not a record
T.MIN_BOSS = 30
local function db()
  -- v2: kept from 1.4.72-dev10 on (counted again from the feed: the first count kept 0 s kills)
  if not ns.db.pveTally or ns.db.pveTally.v ~= 2 then ns.db.pveTally = { v = 2, seen = {}, p = {} } end
  return ns.db.pveTally
end
local function person(pid)
  local d = db()
  local x = d.p[pid]
  if not x then x = { runs = 0, raids = 0, bosses = 0, where = {} } d.p[pid] = x end
  return x
end
-- the pids in a post: the poster plus the list in d ("2|pid,pid" for a run, "0:1:3:pid,pid" for a boss)
local function members(item)
  local out, seen = {}, {}
  local function add(pid) if pid and pid ~= "" and not seen[pid] then seen[pid] = true out[#out + 1] = pid end end
  add(item.pid)
  local list = tostring(item.d or ""):match("([^|:]*)$") or ""
  for pid in list:gmatch("[^,]+") do if ns.db.people and ns.db.people[pid] then add(pid) end end
  return out
end
function T:Add(item)
  if not item or not item.id then return end
  local k = item.kind
  if k ~= "DUNGEON" and k ~= "RAID" and k ~= "BOSS" then return end
  local d = db()
  if d.seen[item.id] then return end
  d.seen[item.id] = item.t or true
  local secs = tonumber(k == "BOSS" and item.c or item.b)
  for _, pid in ipairs(members(item)) do
    local x = person(pid)
    if k == "BOSS" then
      x.bosses = x.bosses + 1
      if secs and secs >= T.MIN_BOSS and (not x.fastBoss or secs < x.fastBoss.s) then
        x.fastBoss = { s = secs, boss = tostring(item.b or "?"), inst = tostring(item.a or "") }
      end
    else
      if k == "RAID" then x.raids = x.raids + 1 else x.runs = x.runs + 1 end
      local name = tostring(item.a or "?")
      x.where[name] = (x.where[name] or 0) + 1
      if k == "DUNGEON" and secs and secs > 0 and (not x.fastRun or secs < x.fastRun.s) then
        x.fastRun = { s = secs, inst = name }
      end
      if not x.last or (item.t or 0) > x.last.t then x.last = { inst = name, t = item.t or 0 } end
    end
  end
  -- forget very old "seen" ids (the feed won't bring them back)
  local n = 0
  for _ in pairs(d.seen) do n = n + 1 end
  if n > 3000 then d.seen = {} end
end
-- what the feed still holds, once
function T:Backfill()
  local d = db()
  if d.filled then return end
  d.filled = true
  for _, it in ipairs(ns.db.feed or {}) do self:Add(it) end
end
function T:For(pid)
  self:Backfill()
  return db().p[pid]
end
-- most run: "Blackrock Depths", 6
function T:MostRun(x)
  local best, n = nil, 0
  for name, c in pairs(x and x.where or {}) do if c > n then best, n = name, c end end
  return best, n
end
-- gang records this person holds (fastest boss kills and runs)
function T:Records(pid)
  local n = 0
  for _, inst in pairs(ns.db.bossRec or {}) do for _, r in pairs(inst) do if type(r) == "table" and r.pid == pid then n = n + 1 end end end
  for _, r in pairs(ns.db.runRec or {}) do if type(r) == "table" and r.pid == pid then n = n + 1 end end
  return n
end
