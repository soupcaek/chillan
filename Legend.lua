-- Chillan? – the legend book: one chapter per week, written from what the gang did.
-- Weekly facts are collected as events arrive (so they survive the feed being trimmed).
local ADDON, ns = ...

local L = {}
ns.Legend = L

function L:Week(t, create)
  ns.db.legend = ns.db.legend or {}
  local wk = ns.WeekKey(t)
  local w = ns.db.legend[wk]
  if not w and create then
    w = { wk = wk, mon = ns.MondayOf(t), seen = {}, deaths = {}, dz = {}, lv = {}, firsts = {}, loot = {}, runs = {}, ach = {}, sos = {}, mounts = {}, chat = {}, react = {} }
    ns.db.legend[wk] = w
    -- keep the last 30 weeks
    local keys = {}
    for k in pairs(ns.db.legend) do keys[#keys + 1] = k end
    table.sort(keys)
    for i = 1, #keys - 30 do ns.db.legend[keys[i]] = nil end
  end
  return w
end

function L:Add(item)
  if not item or not item.id or not item.t then return end
  local w = self:Week(item.t, true)
  if not w.seen then return end -- sealed (older than last week): numbers are final
  if w.seen[item.id] then return end
  w.seen[item.id] = true
  local pid, k = item.pid, item.kind
  if k == "DEAD" then
    w.deaths[pid] = (w.deaths[pid] or 0) + 1
    if item.a and item.a ~= "" then
      w.dz[pid] = w.dz[pid] or {}
      w.dz[pid][item.a] = (w.dz[pid][item.a] or 0) + 1
    end
  elseif k == "DING" then
    local lvl = tonumber(item.a)
    if lvl then
      local r = w.lv[pid] or { from = lvl - 1, to = lvl }
      r.from, r.to = math.min(r.from, lvl - 1), math.max(r.to, lvl)
      w.lv[pid] = r
      if item.first then w.firsts[#w.firsts + 1] = { pid = pid, what = "reach level " .. lvl, short = "level " .. lvl } end
    end
  elseif k == "LOOT" then
    local q = tonumber(item.b) or 0
    if q >= 4 then
      w.loot[#w.loot + 1] = { pid = pid, id = tonumber(item.a), q = q }
      if item.first then w.firsts[#w.firsts + 1] = { pid = pid, what = "loot an epic", short = "first epic" } end
    end
  elseif k == "MOUNT" then
    w.mounts[#w.mounts + 1] = pid
    if item.first then w.firsts[#w.firsts + 1] = { pid = pid, what = "get a mount", short = "first mount" } end
  elseif k == "DUNGEON" then
    w.runs[#w.runs + 1] = { pid = pid, name = item.a, dur = tonumber(item.b), deaths = tonumber(item.c) or 0, d = item.d }
    if item.first then w.firsts[#w.firsts + 1] = { pid = pid, what = "clear " .. tostring(item.a), short = tostring(item.a) } end
  elseif k == "ACH" then
    w.ach[pid] = (w.ach[pid] or 0) + 1
  elseif k == "SOS" then
    w.sos[pid] = (w.sos[pid] or 0) + 1
  end
end

-- chat messages and reactions per person per week (the chat list and the feed are trimmed, these are not)
function L:AddChat(item)
  if not item or not item.id or not item.t or not item.pid then return end
  local w = self:Week(item.t, true)
  if not w.seen then return end
  local key = "c:" .. item.id
  if w.seen[key] then return end
  w.seen[key] = true
  w.chat = w.chat or {}
  w.chat[item.pid] = (w.chat[item.pid] or 0) + 1
end

function L:AddReact(item, pid)
  if not item or not item.id or not pid then return end
  local w = self:Week(item.t or ns.Now(), true)
  if not w.seen then return end
  local key = "r:" .. item.id .. ":" .. pid
  if w.seen[key] then return end
  w.seen[key] = true
  w.react = w.react or {}
  w.react[pid] = (w.react[pid] or 0) + 1
end

ns:Listen("CHAT", function(item) L:AddChat(item) end)
ns:Listen("REACTION", function(item, rp) if rp then L:AddReact(item, rp.pid) end end)

-- per-person counts for the current week: "loot" (epics), "chat", "react"
function L:Counts(kind)
  local w = self:Week(ns.Now(), true)
  local out = {}
  if kind == "loot" then
    for _, l in ipairs(w.loot or {}) do out[l.pid] = (out[l.pid] or 0) + 1 end
  else
    for pid, n in pairs(w[kind] or {}) do out[pid] = n end
  end
  return out
end

-- keep the "seen" lists only for this and last week (older weeks never change again)
function L:Seal()
  local keys = {}
  for k in pairs(ns.db.legend or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  for i = 1, #keys - 2 do ns.db.legend[keys[i]].seen = nil end
end

-- hook into the event stream
local orig = ns.Data.ApplyEvent
ns.Data.ApplyEvent = function(self, id, ...)
  orig(self, id, ...)
  for i = #ns.db.feed, 1, -1 do
    local it = ns.db.feed[i]
    if it.id == id then L:Add(it) break end
  end
end

-- fill this week from the feed we already have (first time after an update)
function L:Backfill()
  for _, it in ipairs(ns.db.feed or {}) do
    self:Add(it)
    for _, r in ipairs(it.reacts or {}) do self:AddReact(it, r.pid) end
  end
  for _, c in ipairs(ns.db.chat or {}) do self:AddChat(c) end
  self:Seal()
end

---------------------------------------------------------------------------
-- writing the chapter
---------------------------------------------------------------------------
local function name(pid)
  local p = ns:GetPerson(pid)
  return p and ns:ShortWho(p) or "Someone"
end

-- stable "random" pick per week, so a chapter reads the same every time you open it
local function picker(seed)
  local h = 0
  for i = 1, #seed do h = (h * 31 + seed:byte(i)) % 2147483647 end
  return function(list)
    h = (h * 1103515245 + 12345) % 2147483648
    return list[(h % #list) + 1]
  end
end

local function maxOf(t)
  local bk, bv = nil, 0
  -- ties go to the lowest id, so every client (and every time you open the book) picks the same one
  for k, v in pairs(t) do
    if v > bv or (v == bv and v > 0 and bk and tostring(k) < tostring(bk)) then bk, bv = k, v end
  end
  return bk, bv
end

-- snapshot of weekly stats (quests, hours, levels ...). Taken live for the current week and
-- refreshed every few minutes, so the finished week keeps its numbers; for a week we never
-- snapshotted we fall back to the "last week" numbers each person shares.
function L:Snapshot(w)
  if w.wk ~= ns.WeekKey() then
    -- finished week: the numbers people shared as "last week" are final, so they win over an
    -- older snapshot (which may have been taken on Wednesday)
    local snap, any = w.snap, w.snap ~= nil
    snap = snap or { quests = {}, online = {}, gold = {}, levels = {}, level = {} }
    snap.levels, snap.level = snap.levels or {}, snap.level or {}
    for pid, p in pairs(ns.db.people or {}) do
      local pv = p.stats and p.stats.prev
      if p.main and pv and pv.wk == w.wk then
        snap.quests[pid], snap.online[pid], snap.gold[pid] = pv.Quests or 0, pv.Online or 0, pv.Gold or 0
        snap.levels[pid] = pv.Levels or 0
        any = true
      end
    end
    if any then w.snap = snap return snap end
    return nil
  end
  local snap = { quests = {}, online = {}, gold = {}, levels = {}, level = {} }
  for pid, p in pairs(ns.db.people or {}) do
    if p.main then
      snap.quests[pid] = ns:WeekStat(p, "Quests")
      snap.online[pid] = ns:WeekStat(p, "Online")
      snap.gold[pid] = ns:WeekStat(p, "Gold")
      snap.levels[pid] = ns:WeekStat(p, "Levels")
      snap.level[pid] = ns:PersonMaxLevel(p)
    end
  end
  local chal, leader, v = ns.Data:CurrentLeader()
  if leader then snap.chal = { label = chal.label, pid = leader.pid, text = chal.fmt(v) } end
  w.snap = snap
  return snap
end

function L:Chapter(wk)
  local w = ns.db.legend and ns.db.legend[wk]
  if not w then return nil end
  local C = ns.C
  local pick = picker(wk)
  local story, facts = {}, {}
  local snap = self:Snapshot(w) or {}

  -- the climber: the most levels GAINED this week (not the highest level)
  local climbPid, climbN = nil, 0
  for pid, n in pairs(snap.levels or {}) do
    if n > climbN or (n == climbN and n > 0 and climbPid and pid < climbPid) then climbPid, climbN = pid, n end
  end
  local lvlOf = function(pid)
    local p = ns:GetPerson(pid)
    return (snap.level and snap.level[pid]) or (p and ns:PersonMaxLevel(p)) or 0
  end
  if climbPid and climbN > 0 then
    story[#story + 1] = pick({
      "%s gained the most levels this week: %d level%s, now level %d.",
      "%s had the biggest week: +%d level%s, now level %d.",
      "%s climbed %d level%s – the most in the gang – and is now level %d.",
    }):format(name(climbPid), climbN, climbN == 1 and "" or "s", lvlOf(climbPid))
  end

  -- the highest level in the gang (only when we know it for this week)
  local topPid, topLvl = nil, 0
  for pid, l in pairs(snap.level or {}) do
    if l > topLvl or (l == topLvl and l > 0 and topPid and pid < topPid) then topPid, topLvl = pid, l end
  end
  if topPid and topLvl >= 10 then
    if topPid == climbPid then
      story[#story + 1] = name(topPid) .. " is also the highest level in the gang."
    else
      story[#story + 1] = name(topPid) .. " leads the gang at level " .. topLvl .. "."
    end
  end

  -- firsts of the week, straight from the gang's record book (earliest one wins, same on every client)
  local firsts = {}
  local from, to = w.mon, w.mon + 7 * 86400
  for key, f in pairs(ns.db.firsts or {}) do
    if f.t and f.t >= from and f.t < to then
      local what, short
      local lv = key:match("^L(%d+)$")
      if lv then what, short = "reach level " .. lv, "level " .. lv
      elseif key == "MOUNT" then what, short = "get a mount", "first mount"
      elseif key == "EPIC" then what, short = "loot an epic", "first epic"
      elseif key:sub(1, 3) == "DG:" then what, short = "clear " .. key:sub(4), key:sub(4) end
      if what then firsts[#firsts + 1] = { pid = f.pid, what = what, short = short, t = f.t } end
    end
  end
  table.sort(firsts, function(a, b) return a.t < b.t end)

  -- firsts: one line each when there are few, grouped per person when there are many
  if #firsts > 0 and #firsts <= 2 then
    for _, f in ipairs(firsts) do
      story[#story + 1] = pick({
        "%s was the first in the gang to %s.",
        "History was made: %s was first in the gang to %s.",
      }):format(name(f.pid), f.what)
    end
  elseif #firsts > 2 then
    local by, order = {}, {}
    for _, f in ipairs(firsts) do
      if not by[f.pid] then by[f.pid] = {} order[#order + 1] = f.pid end
      table.insert(by[f.pid], f.short or f.what)
    end
    local parts = {}
    for _, pid in ipairs(order) do parts[#parts + 1] = name(pid) .. " (" .. table.concat(by[pid], ", ") .. ")" end
    story[#story + 1] = "A week of firsts in the gang: " .. table.concat(parts, ", ") .. "."
  end

  -- the floor inspector
  local dPid, dN = maxOf(w.deaths)
  if dPid and dN >= 2 then
    local zone = w.dz[dPid] and maxOf(w.dz[dPid])
    story[#story + 1] = pick({
      "%s spent a lot of time on the floor – %d deaths%s.",
      "It was not %s's week: %d deaths%s.",
      "%s kept the spirit healers busy with %d deaths%s.",
    }):format(name(dPid), dN, zone and (", most of them in " .. zone) or "")
  end

  -- loot
  table.sort(w.loot, function(a, b) return a.q > b.q end)
  if w.loot[1] then
    local l = w.loot[1]
    local item = l.id and (C_Item and C_Item.GetItemInfo or GetItemInfo)(l.id)
    local q = ns.QUALITY_HEX and ns.QUALITY_HEX[l.q] or C.purple
    story[#story + 1] = pick({
      "The loot gods smiled on %s: %s.",
      "%s walked away with %s.",
    }):format(name(l.pid), ns.Colorize("[" .. (item or "an epic") .. "]", q))
  end

  -- dungeons
  if #w.runs > 0 then
    local names, deaths = {}, 0
    for _, r in ipairs(w.runs) do names[r.name or "?"] = (names[r.name or "?"] or 0) + 1 deaths = deaths + (r.deaths or 0) end
    local list = {}
    for n, c in pairs(names) do list[#list + 1] = c > 1 and (n .. " ×" .. c) or n end
    table.sort(list)
    story[#story + 1] = ("The gang ran %d dungeon%s (%s)%s."):format(#w.runs, #w.runs == 1 and "" or "s",
      table.concat(list, ", "), deaths > 0 and (" and died " .. deaths .. " times along the way") or "")
  end

  -- SOS
  local sPid, sN = maxOf(w.sos)
  if sPid then
    story[#story + 1] = pick({ "%s called for help %d time%s.", "%s sent %d SOS call%s – the Alliance had a good week." })
      :format(name(sPid), sN, sN == 1 and "" or "s")
  end

  -- facts box
  local q, qn = maxOf(snap.quests or {})
  if q then facts[#facts + 1] = { "Most quests", name(q) .. " · " .. math.floor(qn) } end
  local o, on = maxOf(snap.online or {})
  if o then facts[#facts + 1] = { "Most time online", name(o) .. " · " .. ns.Duration(on) } end
  local g, gn = maxOf(snap.gold or {})
  if g then facts[#facts + 1] = { "Most gold earned", name(g) .. " · " .. ns.Money(gn) } end
  if dPid then facts[#facts + 1] = { "Most deaths", name(dPid) .. " · " .. dN } end
  local a, an = maxOf(w.ach)
  if a then facts[#facts + 1] = { "Most achievements", name(a) .. " · " .. an } end
  if snap.chal then
    local dup = false
    for _, f in ipairs(facts) do if f[1] == snap.chal.label then dup = true end end
    if not dup then facts[#facts + 1] = { snap.chal.label, name(snap.chal.pid) .. " · " .. snap.chal.text } end
  end

  if #story == 0 then
    story[1] = pick({ "A quiet week. The calm before the storm?", "Not much happened this week – the gang was resting up." })
  end

  local sun = w.mon + 6 * 86400
  local num = tonumber(wk:match("%-(%d+)$")) or 0
  return {
    wk = wk,
    title = "Week " .. num,
    range = date("%d.%m", w.mon) .. " – " .. date("%d.%m", sun),
    current = wk == ns.WeekKey(),
    story = story,
    facts = facts,
  }
end

function L:Weeks()
  local keys = {}
  for k in pairs(ns.db.legend or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

ns:On("PLAYER_LOGIN", function()
  C_Timer.After(5, function() L:Backfill() end)
  -- keep this week's numbers (and last week's, until it is final) saved
  C_Timer.After(60, function() L:Snapshot(L:Week(ns.Now(), true)) end)
  C_Timer.NewTicker(600, function() if ns.db then L:Snapshot(L:Week(ns.Now(), true)) end end)
end)
