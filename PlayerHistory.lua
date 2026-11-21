-- Chillan? – gang player history (1.4.16): the gang's shared memory of people you meet.
-- Hover a player and the tooltip gets a line or two when the gang knows them:
--   "Olav grouped with them in Blackrock Depths · 2 days ago"
--   "Killed the gang 3× · last Olav"        (from the Died-to list)
--   "The gang killed them 5×"                (from the gang's kill lines)
-- Only notable people are kept: someone you grouped with for 3+ minutes (not in battlegrounds, not a
-- layer hop), or who killed / was killed by the gang. Grouping is shared with a small message (PH);
-- deaths and kills already come from the feed. Kept 90 days, at most 500 people.
local ADDON, ns = ...
local PH = {}
ns.PlayerHistory = PH
local Comm = ns.Comm

local KEEP_DAYS, MAX_PEOPLE, TOGETHER = 90, 500, 180

local function secret(v) return ns.isSecret and ns.isSecret(v) end
local function keyOf(name)
  if type(name) ~= "string" or secret(name) or name == "" then return nil end
  return (ns.ShortName(name) or name):lower()
end
local function db()
  ns.db.met = ns.db.met or {}
  return ns.db.met
end
local function entry(name)
  local k = keyOf(name)
  if not k then return nil end
  local list = db()
  list[k] = list[k] or { name = ns.ShortName(name) }
  return list[k], k
end

local function isGang(name)
  local short = ns.ShortName(name or "")
  for _, p in pairs(ns.db.people or {}) do
    for _, c in pairs(p.chars or {}) do if c.name == short then return true end end
  end
  return false
end

-- grouped with: one record per person and place (the newest kept), up to 5 per person
function PH:NoteGroup(name, pid, place, t)
  local e = entry(name)
  if not e then return end
  e.g = e.g or {}
  for i = #e.g, 1, -1 do
    if e.g[i].place == place and e.g[i].pid == pid then table.remove(e.g, i) end
  end
  e.g[#e.g + 1] = { pid = pid, place = place, t = t }
  table.sort(e.g, function(a, b) return (a.t or 0) < (b.t or 0) end)
  while #e.g > 5 do table.remove(e.g, 1) end
  e.last = math.max(e.last or 0, t or 0)
end

-- the gang killed them (from KILL lines, called by Data before kills are folded)
function PH:NoteKill(victim, pid, t)
  if type(victim) ~= "string" or victim == "" or victim:find("^KILL") then return end
  local e = entry(victim)
  if not e then return end
  e.k = (e.k or 0) + 1
  e.kpid, e.kt = pid, t
  e.last = math.max(e.last or 0, t or 0)
end

function PH:Prune()
  local list, cutoff, all = db(), ns.Now() - KEEP_DAYS * 86400, {}
  for k, e in pairs(list) do
    if (e.last or 0) < cutoff then list[k] = nil else all[#all + 1] = { k = k, t = e.last or 0 } end
  end
  if #all > MAX_PEOPLE then
    table.sort(all, function(a, b) return a.t > b.t end)
    for i = MAX_PEOPLE + 1, #all do list[all[i].k] = nil end
  end
end

---------------------------------------------------------------------------
-- watching the group: 3+ minutes together counts (checked every 30 s)
---------------------------------------------------------------------------
local together, recorded, outbox = {}, {}, {}
local function place()
  local inInst, kind = ns.S(IsInInstance)
  if inInst and (kind == "party" or kind == "raid") then return (ns.S(GetInstanceInfo)) or "a dungeon" end
  return ns.S(GetRealZoneText) or "?"
end
C_Timer.NewTicker(30, function()
  if not (IsInGroup and IsInGroup()) or (ns.InBattleground and ns.InBattleground()) then together = {} return end
  if ns.LayerHop and ns.LayerHop.mine then return end   -- a layer hop's group isn't "grouping"
  local raid = IsInRaid and IsInRaid()
  local n = ns.S(GetNumGroupMembers) or 0
  if raid and n > 25 then return end
  local here, now, clock = place(), ns.Now(), GetTime()
  local seen = {}
  for i = 1, n do
    local unit = raid and ("raid" .. i) or ("party" .. i)
    local name = ns.S(UnitName, unit)
    if type(name) == "string" and not secret(name) and name ~= "" and name ~= ns.S(UnitName, "player") and not isGang(name) then
      local k = name:lower() .. "|" .. here
      seen[k] = true
      together[k] = together[k] or clock
      if clock - together[k] >= TOGETHER and not recorded[k] then
        recorded[k] = true
        PH:NoteGroup(name, ns.pid, here, now)
        outbox[#outbox + 1] = ns.ShortName(name)
      end
    end
  end
  for k in pairs(together) do if not seen[k] then together[k] = nil end end
  -- tell the gang (a few names at a time)
  if #outbox > 0 then
    local names = {}
    while #outbox > 0 and #names < 8 do names[#names + 1] = table.remove(outbox, 1) end
    Comm:Broadcast(Comm:Build("PH", ns.pid, here, table.concat(names, ",")), 3)
  end
end)

Comm:Handle("PH", function(f, sender)
  if Comm:IsMe(sender) then return end
  local pid, where, names = f[1], f[2], f[3]
  if not pid or not names then return end
  local now = ns.Now()
  for name in tostring(names):gmatch("[^,]+") do
    if not isGang(name) then PH:NoteGroup(name, pid, where or "?", now) end
  end
end)

---------------------------------------------------------------------------
-- the tooltip
---------------------------------------------------------------------------
local function who(pid)
  if pid == ns.pid then return "You" end
  local p = pid and ns:GetPerson(pid)
  return p and ns:PersonFirst(p) or "Someone in the gang"
end

function PH:Lines(name)
  local k = keyOf(name)
  if not k or isGang(name) then return {} end
  local out = {}
  local e = db()[k]
  if e and e.g and #e.g > 0 then
    local g = e.g[#e.g]
    out[#out + 1] = who(g.pid) .. " grouped with them in " .. tostring(g.place) .. " · " .. ns.Ago(g.t)
      .. (#e.g > 1 and (" (+" .. (#e.g - 1) .. ")") or "")
  end
  local dt = ns.db.diedTo and ns.db.diedTo[k]
  if dt and (dt.n or 0) > 0 then
    out[#out + 1] = "Killed the gang " .. dt.n .. "×" .. (dt.lastPid and (" · last " .. who(dt.lastPid)) or "")
  end
  if e and (e.k or 0) > 0 then
    out[#out + 1] = "The gang killed them " .. e.k .. "×" .. (e.kpid and (" · last " .. who(e.kpid)) or "")
  end
  return out
end

local function onUnitTooltip(tt)
  if not tt or not tt.GetUnit or (ns.db and ns.db.settings and ns.db.settings.playerHistory == false) then return end
  local ok, _, unit = pcall(tt.GetUnit, tt)
  if not ok or not unit or secret(unit) or not ns.S(UnitIsPlayer, unit) then return end
  local name = ns.S(UnitName, unit)
  if type(name) ~= "string" or secret(name) then return end
  local lines = PH:Lines(name)
  if #lines == 0 then return end
  for i, l in ipairs(lines) do
    tt:AddLine((i == 1 and "|cffC69B6DChillan?|r " or "") .. l, 0.85, 0.75, 0.55, true)
  end
  tt:Show()
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt)
    if tt == GameTooltip then pcall(onUnitTooltip, tt) end
  end)
elseif GameTooltip and GameTooltip.HookScript then
  pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", function(tt) pcall(onUnitTooltip, tt) end)
end

ns:On("PLAYER_LOGIN", function() C_Timer.After(20, function() pcall(PH.Prune, PH) end) end)
