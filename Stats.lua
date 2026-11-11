-- Chillan? – utregninger til spillersiden (XP-tempo, tid per level, m.m.)
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
  if (s.sessSec or 0) >= 600 and (s.sessXP or 0) > 0 then
    return s.sessXP / s.sessSec * 3600, "this session"
  end
  local wOnline = ns:WeekStat(p, "Online")
  if (s.wXP or 0) > 0 and wOnline >= 600 then
    return s.wXP / wOnline * 3600, "average this week"
  end
  return nil
end

-- Sekunder (spilletid) til neste level med dagens tempo
function St:ETA(p)
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
