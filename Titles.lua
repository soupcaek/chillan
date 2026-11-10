-- Chillan? – morsomme ukentlige titler som bytter eier automatisk
local ADDON, ns = ...
local T = {}
ns.Titles = T
local C = ns.C

-- Mandag 00:00 denne uka (lokal tid)
function ns.WeekStart() return ns.MondayOf() end

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
  { key = "deaths", name = "Floor Inspector", desc = "most deaths this week", icon = "Skull", color = "F2777A", val = wk("Deaths"), fmt = "n", min = 2 },
  { key = "xp", name = "The Machine", desc = "most XP this week", icon = "Up", color = "5FD18B",
    val = function(p)
      local s = ns:PersonS3(p)
      if not s then return 0 end
      -- stored S3 from someone who hasn't been on since last week is not this week's XP
      if p ~= ns.db.people[ns.pid] and s.wk ~= ns.WeekKey() then return 0 end
      return s.wXP or 0
    end, fmt = "n", min = 5000 },
  { key = "quests", name = "Quest Machine", desc = "most quests this week", icon = "Book", color = "5FD18B", val = wk("Quests"), fmt = "n", min = 3 },
  { key = "levels", name = "Climber", desc = "most levels this week", icon = "Up", color = "8FB8E8", val = wk("Levels"), fmt = "n", min = 1 },
  { key = "online", name = "Marathon Runner", desc = "most time online this week", icon = "Clock", color = "C8D1DC", val = wk("Online"), fmt = "t", min = 1800 },
  { key = "night", name = "Night Owl", desc = "most playtime between 00 and 05", icon = "Clock", color = "B9AEDB", val = wk("Night"), fmt = "t", min = 600 },
  { key = "gold", name = "Gold Hog", desc = "most gold earned this week", icon = "Star", color = "E0C068", val = wk("Gold"), fmt = "g", min = 10000 },
  { key = "kills", name = "Bloodthirsty", desc = "most PvP kills this week", icon = "Target", color = "F2777A", val = wk("Kills"), fmt = "n", min = 1 },
  { key = "loot", name = "Loot Goblin", desc = "most epic drops this week", icon = "Star", color = "A335EE", count = function() return ns.Legend:Counts("loot") end, fmt = "n" },
  { key = "chat", name = "Chatterbox", desc = "most chat messages this week", icon = "Chat", color = "8FB8C9", fmt = "n", min = 4,
    count = function() return ns.Legend:Counts("chat") end },
  { key = "grats", name = "Cheer Squad", desc = "most reactions given this week", icon = "Star", color = "F0A8D0", fmt = "n", min = 2,
    count = function() return ns.Legend:Counts("react") end },
}
T.byKey = {}
for _, d in ipairs(T.DEFS) do T.byKey[d.key] = d end

-- Hvor mye må en utfordrer lede med for å ta tittelen? (unngår at den hopper fram og
-- tilbake når to er nesten like, eller når statistikk fra andre kommer litt forsinket)
local MARGIN = { n = 1, t = 900, g = 5000 }
local function beats(def, challenger, holder)
  return challenger > holder * 1.10 + (MARGIN[def.fmt] or 1)
end

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
        -- ties are broken the same way on every client (lowest pid), so everyone sees the same holder
        if v > bestV or (v == bestV and v > 0 and best and pid < best) then
          if best and best ~= pid then second = math.max(second, bestV) end
          best, bestV = pid, v
        elseif v > second then second = v end
      end
    end
    if best and bestV > (def.min or 0) then
      out[def.key] = { pid = best, value = bestV, second = second, values = values }
    end
  end
  return out
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

-- Clickable/hoverable title name for the event window and chat
function T.Link(def)
  return "|Hchillantitle:" .. def.key .. "|h" .. ns.Colorize(def.name, "E0C068") .. "|h"
end

-- Did the challenger actually play their way past the holder, or did their numbers just arrive?
function T:RealOvertake(def, pid, holder)
  if pid == ns.pid then
    return true
  end
  local p = ns:GetPerson(pid)
  if not p or not ns:IsOnline(p) then return false end              -- offline: late data, not a real event
  local L = p.live or {}
  if L.session and (ns.Now() - L.session) < 300 then return false end -- just logged in: numbers are syncing
  local lv = self.lastVals and self.lastVals[def.key]
  if not lv or lv[pid] == nil then return false end                 -- we had no earlier numbers to compare
  local hv = lv[holder] or 0
  return not beats(def, lv[pid], hv)                                -- must have been behind last round
end

-- Tooltip: what the title is, who holds it and the top 3 this week
function T:Tooltip(owner, key)
  local def = self.byKey[key]
  if not def then return end
  local hex = ns.hex
  GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
  GameTooltip:AddLine(def.name, hex("E0C068"))
  GameTooltip:AddLine("Weekly title: " .. def.desc, hex(C.text2))
  local raw = self:Compute()[key]
  local holder = self:Current()[key]
  local rows = {}
  if raw then
    for pid, v in pairs(raw.values) do if v > 0 then rows[#rows + 1] = { pid = pid, v = v } end end
    table.sort(rows, function(a, b) if a.v ~= b.v then return a.v > b.v end return a.pid < b.pid end)
  end
  if #rows > 0 then
    GameTooltip:AddLine(" ")
    for i = 1, math.min(5, #rows) do
      local p = ns:GetPerson(rows[i].pid) or {}
      local c = ns:PersonChar(p) or {}
      local r, g, b = ns.ClassColor(c.class)
      local mark = (holder and holder.pid == rows[i].pid) and "  (holder)" or ""
      GameTooltip:AddDoubleLine(i .. ".  " .. (ns:PersonAlias(p) or c.name or "?") .. mark, self:Format(def, rows[i].v), r, g, b, hex(C.text))
    end
  else
    GameTooltip:AddLine("Nobody has any this week yet.", hex(C.dim))
  end
  GameTooltip:AddLine(" ")
  if def.min and def.min > 0 then
    GameTooltip:AddLine("Needs more than " .. self:Format(def, def.min) .. " to hold it.", hex(C.dim))
  end
  GameTooltip:AddLine("To take it you need 10% more than the holder. Resets Monday 00:00.", hex(C.dim), true)
  GameTooltip:Show()
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
        if pend and pend.pid == r.pid then pend.n = pend.n + 1
        else
          pend = { pid = r.pid, n = 1, real = self:RealOvertake(def, r.pid, holder) }
          self.pending[def.key] = pend
        end
        if pend.n >= 2 then
          self.pending[def.key] = nil
          cur[def.key] = { pid = r.pid, value = r.value, second = holderV }
          changes[#changes + 1] = { def = def, pid = r.pid, lost = holder, real = pend.real }
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
  self.lastVals = {}
  for k, r in pairs(raw) do self.lastVals[k] = r.values end

  -- announce only real overtakes:
  --  * not in the first 5 min after your login, not when the title is brand new this week
  --  * not when the new holder only "won" because their numbers just arrived
  --    (they just logged in, are offline, or were already ahead the last time we had their numbers)
  --  * max once per title per 4 hours; several titles to the same person become one line
  local announce = started and ns.db.titlesWeek == wkKey and ns.db.settings.titles ~= false
    and (GetTime() - startedAt) > 300
  local byPid, order = {}, {}
  for _, ch in ipairs(changes) do
    local last = ns.db.titleAnnouncedAt[ch.def.key]
    if announce and ch.lost and ch.real and (not last or (ns.Now() - last) > 4 * 3600) then
      ns.db.titleAnnouncedAt[ch.def.key] = ns.Now()
      if not byPid[ch.pid] then byPid[ch.pid] = {} order[#order + 1] = ch.pid end
      table.insert(byPid[ch.pid], ch)
    end
  end
  for _, pid in ipairs(order) do
    local list = byPid[pid]
    local p = ns:GetPerson(pid) or {}
    local names = {}
    for i, ch in ipairs(list) do names[i] = T.Link(ch.def) end
    local joined = #names == 1 and names[1] or (table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names])
    local first = list[1]
    local lost = ns:GetPerson(first.lost)
    ns:Fire("TOAST", { kind = "title", pid = pid,
      title = ns:ShortWho(p) .. " is now " .. joined,
      text = (#list == 1 and first.def.desc or "several titles at once")
        .. ((#list == 1 and lost) and (" – took it from " .. (ns:PersonAlias(lost) or ns:PersonName(lost))) or "") })
    ns:Fire("FEEDEVENT", ns.UI.InlineIcon("Crown", "E0C068", 12) .. "  " .. ns:ShortWho(p) .. ns.Colorize(" is now ", C.text2) .. joined)
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
