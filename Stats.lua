-- Chillan? – numbers for the player page (XP pace, time per level and more)
local ADDON, ns = ...
local St = {}
ns.St = St

-- 12345 -> "12 345"
function ns.Num(n)
  if not n then return "–" end
  local s = tostring(math.floor(n))
  local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
  return (out:gsub("^%s+", ""))
end

function ns.Pct(a, b)
  if not a or not b or b <= 0 then return nil end
  return math.floor(a / b * 100 + 0.5)
end

-- Høyeste karakter for en person (der hist og played normalt ligger)
function St:MainChar(p)
  local c = ns:PersonChar(p)
  for _, ch in pairs(p.chars or {}) do
    if (ch.level or 0) > ((c and c.level) or 0) then c = ch end
  end
  return c
end

-- XP per time: denne økten hvis den er lang nok, ellers snitt denne uka
function St:XPRate(p)
  local s = ns:PersonS3(p)
  if not s then return nil end
  -- (1.1.7) the session only counts after 20 minutes, and not when it's far below your week's pace
  -- (standing in town for an hour shouldn't make the next level "4 days" away)
  local week
  local wOnline = ns:WeekStat(p, "Online")
  if (s.wXP or 0) > 0 and wOnline >= 600 then week = s.wXP / wOnline * 3600 end
  if (s.sessSec or 0) >= 1200 and (s.sessXP or 0) > 0 then
    local sess = s.sessXP / s.sessSec * 3600
    if not week or sess >= week * 0.5 then return sess, "this session" end
  end
  -- (1.2.4) the week's pace is from your main; on a low alt it means nothing (level 1 at 218k XP/h)
  if week and p == ns:GetPerson(ns.pid) then
    local cur = ns.Tracker:MyChar() or {}
    if (cur.level or 0) < ns:PersonMaxLevel(p) - 5 then week = nil end
  end
  if week then return week, "average this week" end
  return nil
end

-- Sekunder (spilletid) til neste level med dagens tempo
function St:ETA(p)
  -- (1.4.17) no "time to 61" once the character is at the cap
  local c = p and ns:PersonChar(p)
  if c and (c.level or 0) >= 60 then return nil end
  local s = ns:PersonS3(p)
  local rate = self:XPRate(p)
  if not s or not rate or rate <= 0 or not s.xp or not s.xpMax then return nil end
  return (s.xpMax - s.xp) / rate * 3600
end

-- Spilletid per level ut fra /played lagret ved hver ding
function St:LevelTimes(p)
  local c = self:MainChar(p)
  local out = {}
  local h = (c and c.hist) or {}
  for i = 2, #h do
    if h[i].l == h[i - 1].l + 1 and h[i].p and h[i - 1].p and h[i].p > h[i - 1].p then
      out[#out + 1] = { level = h[i].l, secs = h[i].p - h[i - 1].p }
    end
  end
  return out
end

function St:LevelSummary(p)
  local times = self:LevelTimes(p)
  if #times == 0 then
    -- reserve: /played delt på antall levels
    local c = self:MainChar(p)
    local played = c and c.played
    if played and c.level and c.level > 1 then
      return { avg = played / (c.level - 1), estimated = true }
    end
    return nil
  end
  local sum, fast, slow = 0, nil, nil
  for _, t in ipairs(times) do
    sum = sum + t.secs
    if not fast or t.secs < fast.secs then fast = t end
    if not slow or t.secs > slow.secs then slow = t end
  end
  return { avg = sum / #times, fast = fast, slow = slow, n = #times }
end

-- Anslått spilletid til level 60 (blir lengre per level, så vi legger på litt)
function St:ETA60(p)
  local c = self:MainChar(p)
  if not c or not c.level or c.level >= 60 then return nil end
  local sum = self:LevelSummary(p)
  if not sum or not sum.avg then return nil end
  local remaining = 60 - c.level
  return sum.avg * remaining * (1 + remaining / 60)
end

function St:PerHour(p, key)
  local online = ns:WeekStat(p, "Online")
  if online < 600 then return nil end
  return ns:WeekStat(p, key) / online * 3600
end

-- Gratulasjoner mottatt og gitt (fra feeden)
function St:Grats(p)
  local got, gave = 0, 0
  for _, it in ipairs(ns.db.feed) do
    if it.reacts then
      if it.pid == p.pid then got = got + #it.reacts end
      for _, r in ipairs(it.reacts) do if r.pid == p.pid then gave = gave + 1 end end
    end
  end
  return got, gave
end

function St:Firsts(p)
  local out = {}
  for _, key in ipairs({ "L10", "L20", "L30", "L40", "L50", "L60", "MOUNT" }) do
    local f = ns.db.firsts[key]
    if f and f.pid == p.pid then out[#out + 1] = key == "MOUNT" and "Mount" or ("Level " .. key:sub(2)) end
  end
  return out
end

function St:RecentLoot(p, n)
  local out = {}
  for i = #ns.db.feed, 1, -1 do
    local it = ns.db.feed[i]
    if it.pid == p.pid and it.kind == "LOOT" then
      local id = tonumber(it.a)
      local name = ns.ItemLink(id) and C_Item and C_Item.GetItemInfo and (C_Item.GetItemInfo(id))
      out[#out + 1] = name or "an item (loading…)"
      if #out >= (n or 3) then break end
    end
  end
  return out
end

---------------------------------------------------------------------------
-- (1.4.66) per-day numbers for the Progress chart. The gang only shares weekly totals, so once in a
-- while the weekly totals of everyone are written down under today's date; a day's number is then
-- today's total minus the day before (same week). Kept for 15 days.
---------------------------------------------------------------------------
St.DAY_KEYS = { "Online", "Quests", "Gold", "Deaths", "Levels", "Kills" }
function St:SnapDay()
  if not ns.db or not ns.db.people then return end
  local wk = ns.WeekKey()
  local day = date("%Y-%m-%d")
  ns.db.dayStats = ns.db.dayStats or {}
  local d = ns.db.dayStats[day] or {}
  ns.db.dayStats[day] = d
  for pid, p in pairs(ns.db.people) do
    local s = p.stats
    if s and s.wk == wk then
      local old = d[pid]
      local row = { wk = wk, base = old and old.wk == wk and old.base or {} }
      for _, k in ipairs(self.DAY_KEYS) do
        row[k] = s["w" .. k] or 0
        -- the first value noted today: the day's starting point when there's no earlier day
        if row.base[k] == nil then row.base[k] = row[k] end
      end
      d[pid] = row
    end
  end
  -- forget days older than 15 days
  local cut = date("%Y-%m-%d", time() - 15 * 86400)
  for k in pairs(ns.db.dayStats) do if k < cut then ns.db.dayStats[k] = nil end end
end

-- this week's days (Monday first): { {day="2026-11-23", value=n, known=true|false}, ... } for one key,
-- summed over the gang, or for one person when pid is given
function St:DaySeries(key, pid)
  local out = {}
  local ds = ns.db.dayStats or {}
  local now = time()
  local wd = tonumber(date("%w", now))           -- 0 = Sunday
  local back = (wd + 6) % 7                         -- days since Monday
  local wk = ns.WeekKey()
  local prevTotals = {}
  for i = 0, 6 do
    local t = now - (back - i) * 86400
    local day = date("%Y-%m-%d", t)
    local snap = ds[day]
    local v, known = 0, false
    if snap and t <= now then
      for id, row in pairs(snap) do
        if (not pid or id == pid) and row.wk == wk then
          -- a person's first note this week is only a starting point, unless it's Monday's (the
          -- week starts at 0 then); otherwise a whole week would land on the first day we noted
          local before = prevTotals[id] or (i == 0 and 0) or (row.base and row.base[key])
          if before then
            known = true
            v = v + math.max(0, (row[key] or 0) - before)
          end
          prevTotals[id] = row[key] or 0
        end
      end
    end
    out[#out + 1] = { day = day, value = v, known = known, future = t > now }
  end
  return out
end

if C_Timer and C_Timer.NewTicker then
  ns:On("PLAYER_LOGIN", function()
    C_Timer.After(30, function() St:SnapDay() end)
    C_Timer.NewTicker(300, function() St:SnapDay() end)
  end)
  ns:On("PLAYER_LOGOUT", function() St:SnapDay() end)
end
