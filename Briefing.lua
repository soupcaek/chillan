-- Chillan? – daily briefing: "since you last played" card shortly after login
local ADDON, ns = ...

local B = {}
ns.Briefing = B

local prevAlive -- when this account was last online (read before the session ticker overwrites it)

local function who(pid)
  local p = ns:GetPerson(pid)
  return p and ns:ShortWho(p) or "?"
end

-- the lines for everything that happened after `since`
function B:Lines(since)
  local dings, deaths, deathZone, epics, achs, runs, firsts = {}, {}, {}, {}, {}, {}, {}
  for _, it in ipairs(ns.db.feed or {}) do
    if (it.t or 0) > since and it.pid ~= ns.pid then
      local k = it.kind
      if k == "DING" then
        local lvl = tonumber(it.a)
        if lvl and (not dings[it.pid] or lvl > dings[it.pid]) then dings[it.pid] = lvl end
        if it.first then firsts[#firsts + 1] = who(it.pid) .. " became first in the gang to " .. lvl end
      elseif k == "DEAD" then
        deaths[it.pid] = (deaths[it.pid] or 0) + 1
        deathZone[it.pid] = it.a
      elseif k == "LOOT" and (tonumber(it.b) or 0) >= 4 then
        epics[#epics + 1] = it
      elseif k == "ACH" and (it.b == "G" or it.b == "L") then
        achs[#achs + 1] = it
      elseif k == "DUNGEON" then
        runs[#runs + 1] = it
      end
    end
  end
  local lines = {}
  local C = ns.C
  for _, f in ipairs(firsts) do lines[#lines + 1] = ns.Colorize(f, C.gold) end
  local dl = {}
  for pid, lvl in pairs(dings) do dl[#dl + 1] = { pid = pid, lvl = lvl } end
  table.sort(dl, function(a, b) return a.lvl > b.lvl end)
  for i = 1, math.min(3, #dl) do lines[#lines + 1] = who(dl[i].pid) .. ns.Colorize(" dinged " .. dl[i].lvl, C.green) end
  if #dl > 3 then lines[#lines + 1] = ns.Colorize("+" .. (#dl - 3) .. " more dings", C.dim) end
  for i = 1, math.min(2, #epics) do
    local it = epics[i]
    local id = tonumber(it.a)
    local name = id and (C_Item and C_Item.GetItemInfo or GetItemInfo)(id)
    local q = ns.QUALITY_HEX and ns.QUALITY_HEX[tonumber(it.b) or 4] or C.purple
    lines[#lines + 1] = who(it.pid) .. " looted " .. ns.Colorize("[" .. (name or "an epic") .. "]", q)
  end
  for i = 1, math.min(2, #achs) do
    local it = achs[i]
    local d = ns.Ach and ns.Ach.byId[it.a]
    lines[#lines + 1] = who(it.pid) .. " unlocked " .. ns.Colorize("«" .. (d and d.name or "an achievement") .. "»", C.gold)
  end
  for i = 1, math.min(2, #runs) do
    local it = runs[i]
    lines[#lines + 1] = who(it.pid) .. " ran " .. tostring(it.a) .. ns.Colorize(" · " .. ns.Duration(tonumber(it.b) or 0), C.dim)
  end
  local worst, wn = nil, 0
  for pid, n in pairs(deaths) do if n > wn then worst, wn = pid, n end end
  if worst then
    lines[#lines + 1] = who(worst) .. ns.Colorize(" died " .. wn .. (wn == 1 and " time" or " times")
      .. (deathZone[worst] and (" (last in " .. deathZone[worst] .. ")") or ""), C.red)
  end
  return lines
end

-- who is on right now, and who is near you
function B:NowLine()
  local on, near = 0, {}
  local myZone = ns.S(GetRealZoneText)
  for pid, p in pairs(ns.db.people or {}) do
    if pid ~= ns.pid and p.main and ns:IsOnline(p) then
      on = on + 1
      if myZone and p.live and p.live.zone == myZone then near[#near + 1] = ns:ShortWho(p) end
    end
  end
  if on == 0 then return nil end
  local s = on .. " online now"
  if #near > 0 then s = s .. " · " .. table.concat(near, ", ") .. (#near == 1 and " is" or " are") .. " in " .. myZone .. " with you" end
  return s
end

function B:Show(force)
  local since = prevAlive or (ns.Now() - 86400)
  local lines = self:Lines(since)
  if #lines == 0 and not force then return end
  local now = self:NowLine()
  ns:Fire("BRIEFING", { since = since, lines = lines, now = now })
end

ns:On("PLAYER_LOGIN", function()
  prevAlive = ns.db and ns.db.lastAliveAt
  -- /reload or a quick reconnect: no briefing
  if prevAlive and (ns.Now() - prevAlive) < 600 then return end
  C_Timer.After(10, function()
    if ns.db.settings.briefing == false then return end
    B:Show()
  end)
end)
