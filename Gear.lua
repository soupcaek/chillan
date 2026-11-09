-- Chillan? – shared gear: what everyone wears, for the profile card and the Compare page.
-- Only equipped items are shared (no bags, no bank, no gold).
local ADDON, ns = ...
local Comm = ns.Comm

local G = {}
ns.Gear = G

-- the slots shown, in paper-doll order (shirt and tabard left out)
G.SLOTS = {
  { 1, "Head" }, { 2, "Neck" }, { 3, "Shoulder" }, { 15, "Back" }, { 5, "Chest" }, { 9, "Wrist" },
  { 10, "Hands" }, { 6, "Waist" }, { 7, "Legs" }, { 8, "Feet" }, { 11, "Ring" }, { 12, "Ring" },
  { 13, "Trinket" }, { 14, "Trinket" }, { 16, "Main hand" }, { 17, "Off hand" }, { 18, "Ranged" },
}

-- "item:ID:ench:g1:g2:g3:g4:suffix:..." -> "ID.suffix" (suffix = "of the Bear" etc.)
local function compact(link)
  if type(link) ~= "string" then return nil end
  local s = link:match("item:([%-%d:]+)")
  if not s then return nil end
  local f = {}
  for v in (s .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
  local id, suffix = tonumber(f[1]), tonumber(f[7])
  if not id then return nil end
  return (suffix and suffix ~= 0) and (id .. "." .. suffix) or tostring(id)
end

-- "ID.suffix" -> an item string the game can show and price
function G.ItemString(c)
  if not c or c == "" then return nil end
  local id, suffix = c:match("^(%d+)%.?(%-?%d*)$")
  if not id then return nil end
  return "item:" .. id .. "::::::" .. ((suffix ~= "" and suffix) or "")
end

function G:Mine()
  local out = {}
  for _, s in ipairs(self.SLOTS) do
    out[s[1]] = compact(ns.S(GetInventoryItemLink, "player", s[1]))
  end
  return out
end

function G:For(p)
  if not p then return nil end
  if p == ns.db.people[ns.pid] then return self:Mine() end
  return p.gear
end

-- item level of a compact item (nil until the game has the item cached)
local waiting = {}
function G.Level(c)
  local str = G.ItemString(c)
  if not str then return nil end
  local lvl
  if C_Item and C_Item.GetDetailedItemLevelInfo then lvl = C_Item.GetDetailedItemLevelInfo(str) end
  if not lvl then
    local _, _, _, il = (C_Item and C_Item.GetItemInfo or GetItemInfo)(str)
    lvl = il
  end
  if not lvl then
    local id = tonumber(c:match("^(%d+)"))
    if id and not waiting[id] then
      waiting[id] = true
      if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    end
  end
  return lvl
end

function G.Link(c)
  local str = G.ItemString(c)
  if not str then return nil end
  local _, link = (C_Item and C_Item.GetItemInfo or GetItemInfo)(str)
  return link, str
end

-- compare their gear to mine: slots where they're better / worse, and their average
function G:Compare(p)
  local mine, theirs = self:Mine(), self:For(p)
  if not theirs then return nil end
  local better, worse, sum, n = 0, 0, 0, 0
  for _, s in ipairs(self.SLOTS) do
    local a, b = G.Level(mine[s[1]]), G.Level(theirs[s[1]])
    if b then sum, n = sum + b, n + 1 end
    if a and b then
      if b > a then better = better + 1 elseif b < a then worse = worse + 1 end
    elseif b and not mine[s[1]] then
      better = better + 1
    end
  end
  return { better = better, worse = worse, avg = n > 0 and (sum / n) or nil, at = p.gearAt }
end

---------------------------------------------------------------------------
-- sync: two messages (slot halves), sent when gear changes and to new friends
---------------------------------------------------------------------------
local function build(part)
  local mine = G:Mine()
  local fields = {}
  local from, to = part == 1 and 1 or 10, part == 1 and 9 or #G.SLOTS
  for i = from, to do
    local slot = G.SLOTS[i][1]
    fields[#fields + 1] = slot .. "=" .. (mine[slot] or "")
  end
  return Comm:Build("GR", ns.pid, part, table.concat(fields, ","))
end

function G:SendTo(target)
  Comm:SendTo(target, build(1), 3)
  Comm:SendTo(target, build(2), 3)
end

local pending
function G:Broadcast()
  if pending then return end
  pending = true
  C_Timer.After(6, function()
    pending = false
    Comm:Broadcast(build(1), 3)
    Comm:Broadcast(build(2), 3)
  end)
end

Comm:Handle("GR", function(f)
  local pid, list = f[1], f[3]
  if not pid or pid == ns.pid or not list then return end
  local p = ns:GetPerson(pid, true)
  p.gear = p.gear or {}
  for slot, c in list:gmatch("(%d+)=([%d%.%-]*)") do
    p.gear[tonumber(slot)] = (c ~= "" and c) or nil
  end
  p.gearAt = ns.Now()
  ns:MarkDirty()
end)

ns:On("PLAYER_EQUIPMENT_CHANGED", function() G:Broadcast() end)
ns:On("PLAYER_LOGIN", function() C_Timer.After(20, function() G:Broadcast() end) end)
ns:On("GET_ITEM_INFO_RECEIVED", function(id)
  if waiting[id] then waiting[id] = nil ns:MarkDirty() end
end)
