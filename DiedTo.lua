-- Chillan? – the "Died to" list (1.0.1): Alliance players who killed someone in the gang.
-- It fills itself from the gang's death posts (no extra messages). It's kept apart from the
-- Cunt List, which is manual only: being on this list warns nobody and pops nothing.
local ADDON, ns = ...
local DT = {}
ns.DiedTo = DT

local KEEP_DAYS, MAX_ENTRIES, KEEP_TIMES = 60, 300, 20

local function db()
  ns.db.diedTo = ns.db.diedTo or {}
  return ns.db.diedTo
end

-- one death post: pid died to killer in zone at time t (extra = level/class text from the death recap)
-- "Maraudon, Maraudon" → "Maraudon"
local function cleanZone(z)
  z = tostring(z or "")
  local a, b = z:match("^(.-),%s*(.+)$")
  if a and a == b then return a end
  return z
end
DT.CleanZone = cleanZone

function DT:Record(id, pid, killer, zone, t, extra)
  -- (1.1.7) a pet's killing blow: we can't tell whose pet it was, so it isn't listed
  if type(killer) == "string" and killer:find("%(pet%)%s*$") then return end
  killer = ns.ShortName(killer or "")
  if killer == "" or not pid then return end
  zone = cleanZone(zone)
  local k = killer:lower()
  local list = db()
  local e = list[k]
  if not e then
    e = { name = killer, n = 0, by = {}, times = {}, ids = {}, first = t }
    list[k] = e
  end
  e.ids = e.ids or {}
  if id then
    for _, x in ipairs(e.ids) do if x == id then return end end
    e.ids[#e.ids + 1] = id
    while #e.ids > KEEP_TIMES do table.remove(e.ids, 1) end
  end
  e.n = (e.n or 0) + 1
  e.by = e.by or {}
  e.by[pid] = (e.by[pid] or 0) + 1
  e.times = e.times or {}
  e.times[#e.times + 1] = t
  table.sort(e.times)
  while #e.times > KEEP_TIMES do table.remove(e.times, 1) end
  if not e.last or t >= e.last then
    e.last, e.zone, e.lastPid = t, zone ~= "" and zone or e.zone, pid
    if extra and extra ~= "" then e.extra = extra end
  end
  e.first = math.min(e.first or t, t)
  ns:MarkDirty()
end

function DT:Prune()
  local list = db()
  local cutoff = ns.Now() - KEEP_DAYS * 86400
  local all = {}
  for k, e in pairs(list) do
    if e.zone then e.zone = cleanZone(e.zone) end
    if (e.last or 0) < cutoff or (e.name or ""):find("%(pet%)") then list[k] = nil else all[#all + 1] = { k = k, t = e.last or 0 } end
  end
  if #all > MAX_ENTRIES then
    table.sort(all, function(a, b) return a.t > b.t end)
    for i = MAX_ENTRIES + 1, #all do list[all[i].k] = nil end
  end
end

-- deaths to this killer since time t
function DT:Since(e, t)
  local n = 0
  for _, x in ipairs(e.times or {}) do if x >= t then n = n + 1 end end
  return n
end

-- newest first
function DT:List()
  self:Prune()
  local out = {}
  for k, e in pairs(db()) do e.key = k out[#out + 1] = e end
  table.sort(out, function(a, b) return (a.last or 0) > (b.last or 0) end)
  return out
end

-- most gang deaths in the last 7 days
function DT:WeekTop()
  local since, best, bn = ns.Now() - 7 * 86400, nil, 0
  for _, e in pairs(db()) do
    local n = self:Since(e, since)
    if n > bn or (n == bn and n > 0 and (e.last or 0) > (best.last or 0)) then best, bn = e, n end
  end
  return best, bn
end

-- "Grukk 3×, Zulja" – who in the gang died to them
-- (1.4.72) "on Olav" / "on Olav and Henrik" / "on Olav, Henrik +2": who they killed, not "the gang"
function DT:OnWho(e)
  local rows = {}
  for pid, n in pairs(e and e.by or {}) do rows[#rows + 1] = { pid = pid, n = n } end
  table.sort(rows, function(a, b) return a.n > b.n end)
  local names = {}
  for i = 1, math.min(2, #rows) do
    local p = ns:GetPerson(rows[i].pid)
    names[#names + 1] = (p and ns:PersonFirst(p)) or "?"
  end
  if #names == 0 then return "on the gang" end
  if #rows == 1 then return "on " .. names[1] end
  if #rows == 2 then return "on " .. names[1] .. " and " .. names[2] end
  return "on " .. names[1] .. ", " .. names[2] .. " +" .. (#rows - 2)
end
function DT:Victims(e, max)
  local rows = {}
  for pid, n in pairs(e.by or {}) do rows[#rows + 1] = { pid = pid, n = n } end
  table.sort(rows, function(a, b) return a.n > b.n end)
  local parts = {}
  for i = 1, math.min(max or 3, #rows) do
    local p = ns:GetPerson(rows[i].pid)
    local who = (p and ns:PersonFirst(p)) or "?"
    parts[#parts + 1] = who .. (rows[i].n > 1 and (" " .. rows[i].n .. "×") or "")
  end
  if #rows > (max or 3) then parts[#parts + 1] = "+" .. (#rows - (max or 3)) end
  return table.concat(parts, ", ")
end

-- fill from the death posts already in the feed (first start on 1.0.1)
function DT:Backfill()
  for _, it in ipairs(ns.db.feed or {}) do
    if it.kind == "DEAD" and type(it.b) == "string" and it.b:find("^PLAYER:") and it.c and it.c ~= "" then
      self:Record(it.id, it.pid, it.c, it.a or "", it.t or ns.Now(), it.d)
    end
  end
end
