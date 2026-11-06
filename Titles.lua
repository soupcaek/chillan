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
  { key = "deaths", name = "Gulvinspektør", desc = "flest dødsfall denne uka", icon = "Skull", color = "F2777A", val = wk("Deaths"), fmt = "n" },
  { key = "xp", name = "Maskinen", desc = "mest XP denne uka", icon = "Up", color = "5FD18B",
    val = function(p) local s = ns:PersonS3(p) return s and s.wXP or 0 end, fmt = "n" },
  { key = "quests", name = "Questmaskin", desc = "flest quests denne uka", icon = "Book", color = "5FD18B", val = wk("Quests"), fmt = "n" },
  { key = "levels", name = "Klatremus", desc = "flest levels denne uka", icon = "Up", color = "8FB8E8", val = wk("Levels"), fmt = "n" },
  { key = "online", name = "Maratonløper", desc = "mest tid online denne uka", icon = "Clock", color = "C8D1DC", val = wk("Online"), fmt = "t" },
  { key = "night", name = "Nattugle", desc = "mest spilling mellom 00 og 05", icon = "Clock", color = "B9AEDB", val = wk("Night"), fmt = "t", min = 600 },
  { key = "gold", name = "Gullgris", desc = "mest gull tjent denne uka", icon = "Star", color = "E0C068", val = wk("Gold"), fmt = "g" },
  { key = "kills", name = "Blodtørstig", desc = "flest PvP-drap denne uka", icon = "Target", color = "F2777A", val = wk("Kills"), fmt = "n" },
  { key = "loot", name = "Lootgoblin", desc = "flest episke drops denne uka", icon = "Star", color = "A335EE", count = function() return countFeed("LOOT", function(it) return (tonumber(it.b) or 4) >= 4 end) end, fmt = "n" },
  { key = "chat", name = "Pratmaker", desc = "flest chatmeldinger denne uka", icon = "Chat", color = "8FB8C9", fmt = "n",
    count = function()
      local out, start = {}, ns.WeekStart()
      for _, it in ipairs(ns.db.chat or {}) do if it.t and it.t >= start then out[it.pid] = (out[it.pid] or 0) + 1 end end
      return out
    end },
  { key = "grats", name = "Heiagjeng", desc = "flest reaksjoner gitt denne uka", icon = "Star", color = "F0A8D0", fmt = "n",
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

-- Regn ut hvem som har hver tittel nå: { key = { pid, value, second } }
function T:Compute()
  local out = {}
  local prev = ns.db.titles or {}
  for _, def in ipairs(self.DEFS) do
    local counts = def.count and def.count() or nil
    local best, bestV, second = nil, 0, 0
    for pid, p in pairs(ns.db.people) do
      if p.main and (pid == ns.pid or (ns.Now() - (p.lastSeen or 0)) < 14 * 86400) then
        local v = counts and (counts[pid] or 0) or (def.val(p) or 0)
        if v > bestV or (v == bestV and v > 0 and prev[def.key] == pid) then
          if best ~= pid then second = bestV end
          best, bestV = pid, v
        elseif v > second then
          second = v
        end
      end
    end
    if best and bestV > (def.min or 0) then
      out[def.key] = { pid = best, value = bestV, second = second }
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

local started = false
function T:Update()
  local cur = self:Compute()
  self.cur = cur
  local prev = ns.db.titles or {}
  local wkKey = ns.WeekKey()
  local announce = started and ns.db.titlesWeek == wkKey and ns.db.settings.titles ~= false
  local shown = 0
  for _, def in ipairs(self.DEFS) do
    local now = cur[def.key] and cur[def.key].pid
    if now and prev[def.key] ~= now and announce and shown < 2 then
      shown = shown + 1
      local p = ns:GetPerson(now) or {}
      local lost = prev[def.key] and ns:GetPerson(prev[def.key])
      ns:Fire("TOAST", { kind = "title", pid = now,
        title = ns:ShortWho(p) .. " er ny " .. ns.Colorize(def.name, "E0C068"),
        text = def.desc .. (lost and (" – tok den fra " .. (ns:PersonAlias(lost) or ns:PersonName(lost))) or "") })
      ns:Fire("FEEDEVENT", ns.UI.InlineIcon("Crown", "E0C068", 12) .. "  " .. ns:ShortWho(p) .. " er ny " .. ns.Colorize(def.name, "E0C068"))
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
