-- Chillan? – which layer am I on?
-- The game has no layer API. A creature's GUID is Creature-0-[server]-[map]-[zoneUID]-[npc]-[spawn];
-- on live WoW Forever the layer is the [server] part (measured by the LayerSwap authors, Nov 2026:
-- joining a host with another server part moved the guest, the same server part never did).
-- We read the creatures the game shows anyway (nameplates, target, mouseover) and believe a
-- layer once two different creatures agree – three of the last five to change a known one.
local ADDON, ns = ...

local Ly = {}
ns.Layer = Ly

local VOTES = 5
local votes, voted, nVoted = {}, {}, 0
local current          -- layer key (the server number as a string), or nil
local moved = false    -- the game just moved us (shard transfer / new zone): two votes are enough
local stale            -- { untilAt, guid = {} }: creatures of the layer we just left

local function secret(v) return ns.isSecret and ns.isSecret(v) end

function Ly.KeyOf(guid)
  if secret(guid) or type(guid) ~= "string" then return nil end
  local kind, _, server, _, zoneUID = strsplit("-", guid)
  if (kind ~= "Creature" and kind ~= "Vehicle") or not zoneUID then return nil end
  if not server or not server:match("^%d+$") then return nil end
  return server
end

-- what the gang sees: a short, stable label for a layer key
function Ly.Label(key)
  if not key or key == "" then return nil end
  return "L" .. tostring(key)
end

function Ly:Current() return current end
function Ly:CurrentLabel() return Ly.Label(current) end

local function forget()
  votes, voted, nVoted = {}, {}, 0
end

local function set(key)
  local old = current
  current = key
  moved = false
  Ly.since = GetTime()
  if old ~= key then
    ns:Fire("LAYER", key, old)
    if ns.Tracker and ns.Tracker.MaybeSendStatus then pcall(ns.Tracker.MaybeSendStatus, ns.Tracker) end
    ns:MarkDirty()
  end
end

local function observe(unit)
  local okE, there = pcall(UnitExists, unit)
  if not okE or secret(there) or there ~= true then return end
  local ok, guid = pcall(UnitGUID, unit)
  if not ok then return end
  local key = Ly.KeyOf(guid)
  if not key then return end
  -- our own summons (totems, guardians) carry the place they were made
  local okP, pc = pcall(UnitPlayerControlled, unit)
  if okP and not secret(pc) and pc == true then return end
  if stale and GetTime() < stale.untilAt and stale.guid[guid] then return end
  if voted[guid] then
    if key == current then Ly.seenAt = GetTime() end
    return
  end
  if nVoted > 400 then voted, nVoted = {}, 0 end
  voted[guid] = true
  nVoted = nVoted + 1
  votes[#votes + 1] = key
  if #votes > VOTES then table.remove(votes, 1) end
  if key == current then
    Ly.seenAt = GetTime()
    moved = false
    return
  end
  local n = 0
  for _, v in ipairs(votes) do if v == key then n = n + 1 end end
  if n >= ((current and not moved) and 3 or 2) then set(key) end
  ns:Fire("LAYER_READ", key)
end
Ly.Observe = observe

function Ly:Scan()
  observe("target")
  observe("mouseover")
  for i = 1, 40 do observe("nameplate" .. i) end
end

-- the creatures in view when the game moves us still belong to the old layer for a moment
local function markStale()
  local guids = {}
  local function add(unit)
    local okE, there = pcall(UnitExists, unit)
    if not okE or secret(there) or there ~= true then return end
    local ok, g = pcall(UnitGUID, unit)
    if ok and not secret(g) and type(g) == "string" then guids[g] = true end
  end
  for i = 1, 40 do add("nameplate" .. i) end
  add("target")
  add("mouseover")
  stale = { untilAt = GetTime() + 10, guid = guids }
end

ns:On("NAME_PLATE_UNIT_ADDED", function(unit) if unit then observe(unit) end end)
ns:On("UPDATE_MOUSEOVER_UNIT", function() observe("mouseover") end)
ns:On("PLAYER_TARGET_CHANGED", function() observe("target") end)

-- Blizzard's own name for a layer change
ns:On("SHARD_TRANSFER", function()
  markStale()
  forget()
  moved = true
  Ly.transferAt = GetTime()
  ns:Fire("LAYER_TRANSFER")
  C_Timer.After(2, function() Ly:Scan() end)
  C_Timer.After(6, function() Ly:Scan() end)
end)

local function newPlace()
  forget()
  moved = true
  local inInst = ns.S and ns.S(IsInInstance)
  if inInst then
    if current then current = nil ns:Fire("LAYER", nil) end
    return
  end
  C_Timer.After(3, function() Ly:Scan() end)
end
ns:On("ZONE_CHANGED_NEW_AREA", newPlace)
ns:On("PLAYER_ENTERING_WORLD", newPlace)
