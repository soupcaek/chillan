-- Chillan? – morsomme ukentlige titler som bytter eier automatisk
local ADDON, ns = ...
local T = {}
ns.Titles = T
local C = ns.C

-- Mandag 00:00 denne uka (lokal tid)
function ns.WeekStart()
  local d = date("*t")
  local daysSinceMonday = (d.wday + 5) % 7
  return time({ year = d.year, month = d.month, day = d.day, hour = 0 }) - daysSinceMonday * 86400
end

local function countFeed(kind, filter)
  local out, start = {}, ns.WeekStart()
  for _, it in ipairs(ns.db.feed or {}) do
    if it.t and it.t >= start and (not kind or it.kind == kind) and (not filter or filter(it)) then
      out[it.pid] = (out[it.pid] or 0) + 1
    end
  end
  return out
end

local function wk(key) return function(p) return ns:WeekStat(p, key) end end

T.DEFS = {
  { key = "deaths", name = "Floor Inspector", desc = "most deaths this week", icon = "Skull", color = "F2777A", val = wk("Deaths"), fmt = "n" },
  { key = "xp", name = "The Machine", desc = "most XP this week", icon = "Up", color = "5FD18B",
    val = function(p) local s = ns:PersonS3(p) return s and s.wXP or 0 end, fmt = "n" },
  { key = "quests", name = "Quest Machine", desc = "most quests this week", icon = "Book", color = "5FD18B", val = wk("Quests"), fmt = "n" },
  { key = "levels", name = "Climber", desc = "most levels this week", icon = "Up", color = "8FB8E8", val = wk("Levels"), fmt = "n" },
  { key = "online", name = "Marathon Runner", desc = "most time online this week", icon = "Clock", color = "C8D1DC", val = wk("Online"), fmt = "t" },
  { key = "night", name = "Night Owl", desc = "most playtime between 00 and 05", icon = "Clock", color = "B9AEDB", val = wk("Night"), fmt = "t", min = 600 },
  { key = "gold", name = "Gold Hog", desc = "most gold earned this week", icon = "Star", color = "E0C068", val = wk("Gold"), fmt = "g" },
  { key = "kills", name = "Bloodthirsty", desc = "most PvP kills this week", icon = "Target", color = "F2777A", val = wk("Kills"), fmt = "n" },
  { key = "loot", name = "Loot Goblin", desc = "most epic drops this week", icon = "Star", color = "A335EE", count = function() return countFeed("LOOT", function(it) return (tonumber(it.b) or 4) >= 4 end) end, fmt = "n" },
  { key = "chat", name = "Chatterbox", desc = "most chat messages this week", icon = "Chat", color = "8FB8C9", fmt = "n",
    count = function()
      local out, start = {}, ns.WeekStart()
      for _, it in ipairs(ns.db.chat or {}) do if it.t and it.t >= start then out[it.pid] = (out[it.pid] or 0) + 1 end end
      return out
    end },
  { key = "grats", name = "Cheer Squad", desc = "most reactions given this week", icon = "Star", color = "F0A8D0", fmt = "n",
    count = function()
      local out, start = {}, ns.WeekStart()
      for _, it in ipairs(ns.db.feed or {}) do
        if it.t and it.t >= start then
          for _, r in ipairs(it.reacts or {}) do out[r.pid] = (out[r.pid] or 0) + 1 end
        end
      end
      return out
    end },
}
T.byKey = {}
for _, d in ipairs(T.DEFS) do T.byKey[d.key] = d end

function T:Format(def, v)
  if def.fmt == "t" then return ns.Duration(v) end
  if def.fmt == "g" then return ns.Money(v) end
  return ns.Num(v)
end

-- Regn ut hvem som leder hver tittel nå: { key = { pid, value, second, values } }
function T:Compute()
  local out = {}
  for _, def in ipairs(self.DEFS) do
    local counts = def.count and def.count() or nil
    local values, best, bestV, second = {}, nil, 0, 0
    for pid, p in pairs(ns.db.people) do
      if p.main and (pid == ns.pid or (ns.Now() - (p.lastSeen or 0)) < 14 * 86400) then
        local v = counts and (counts[pid] or 0) or (def.val(p) or 0)
        values[pid] = v
        if v > bestV then second, best, bestV = bestV, pid, v elseif v > second then second = v end
      end
    end
    if best and bestV > (def.min or 0) then
      out[def.key] = { pid = best, value = bestV, second = second, values = values }
    end
  end
  return out
end

-- Hvor mye må en utfordrer lede med for å ta tittelen? (unngår at den hopper fram og
-- tilbake når to er nesten like, eller når statistikk fra andre kommer litt forsinket)
local MARGIN = { n = 1, t = 900, g = 5000 }
local function beats(def, challenger, holder)
  return challenger > holder * 1.10 + (MARGIN[def.fmt] or 1)
end

function T:Current() return self.cur or {} end

-- Titler en person har akkurat nå
function T:For(pid)
  local list = {}
  for _, def in ipairs(self.DEFS) do
    local h = self:Current()[def.key]
    if h and h.pid == pid then list[#list + 1] = def end
  end
  return list
end

-- Liten krone + første tittel, til lister
function T:Badge(pid, withName)
  local list = self:For(pid)
  if #list == 0 then return "" end
  local s = ns.UI.InlineIcon("Crown", "E0C068", 12)
  if withName then
    s = s .. " " .. ns.Colorize(list[1].name, "E0C068")
    if #list > 1 then s = s .. ns.Colorize(" +" .. (#list - 1), C.dim) end
  end
  return s
end

local started = false
local startedAt = GetTime()
T.pending = {}
function T:Update()
  local raw = self:Compute()
  local prev = ns.db.titles or {}
  local wkKey = ns.WeekKey()
  if ns.db.titlesWeek ~= wkKey then prev = {} end
  ns.db.titleAnnouncedAt = ns.db.titleAnnouncedAt or {}
  local cur, changes = {}, {}
  for _, def in ipairs(self.DEFS) do
    local r = raw[def.key]
    local holder = prev[def.key]
    if r then
      local holderV = holder and r.values[holder]
      if not holder or holderV == nil or holderV <= (def.min or 0) then
        cur[def.key] = { pid = r.pid, value = r.value, second = r.second }
        if holder ~= r.pid then changes[#changes + 1] = { def = def, pid = r.pid, lost = holder } end
      elseif r.pid ~= holder and beats(def, r.value, holderV) then
        -- utfordreren må lede tydelig i to runder på rad (2 min) før tittelen bytter eier
        local pend = self.pending[def.key]
        if pend and pend.pid == r.pid then pend.n = pend.n + 1 else pend = { pid = r.pid, n = 1 } self.pending[def.key] = pend end
        if pend.n >= 2 then
          self.pending[def.key] = nil
          cur[def.key] = { pid = r.pid, value = r.value, second = holderV }
          changes[#changes + 1] = { def = def, pid = r.pid, lost = holder }
        else
          cur[def.key] = { pid = holder, value = holderV, second = r.value }
        end
      else
        self.pending[def.key] = nil
        cur[def.key] = { pid = holder, value = holderV, second = (r.pid ~= holder) and r.value or r.second }
      end
    end
  end
  self.cur = cur

  -- varsle: ikke første 5 min etter innlogging, maks én gang per tittel per 4 timer, maks 2 om gangen
  local announce = started and ns.db.titlesWeek == wkKey and ns.db.settings.titles ~= false
    and (GetTime() - startedAt) > 300
  local shown = 0
  for _, ch in ipairs(changes) do
    local last = ns.db.titleAnnouncedAt[ch.def.key]
    if announce and shown < 2 and ch.lost and (not last or (ns.Now() - last) > 4 * 3600) then
      shown = shown + 1
      ns.db.titleAnnouncedAt[ch.def.key] = ns.Now()
      local def = ch.def
      local p = ns:GetPerson(ch.pid) or {}
      local lost = ns:GetPerson(ch.lost)
      ns:Fire("TOAST", { kind = "title", pid = ch.pid,
        title = ns:ShortWho(p) .. " is the new " .. ns.Colorize(def.name, "E0C068"),
        text = def.desc .. (lost and (" – took it from " .. (ns:PersonAlias(lost) or ns:PersonName(lost))) or "") })
      ns:Fire("FEEDEVENT", ns.UI.InlineIcon("Crown", "E0C068", 12) .. "  " .. ns:ShortWho(p) .. " is the new " .. ns.Colorize(def.name, "E0C068"))
    end
  end
  local store = {}
  for k, v in pairs(cur) do store[k] = v.pid end
  ns.db.titles = store
  ns.db.titlesWeek = wkKey
  started = true
  ns:MarkDirty()
end

function T:Start()
  C_Timer.After(40, function() T:Update() end)
  C_Timer.NewTicker(60, function() T:Update() end)
end
