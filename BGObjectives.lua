-- Chillan? – battleground objectives (1.4.50)
-- What the battleground's own map and score display say: who owns each base or tower, which ones are
-- being taken and how long until they fall, the score race and a win estimate, and the flag
-- respawn in Warsong Gulch. Only what this client can see: inside a battleground the game blocks
-- addon messages, so nothing here is shared.
local ADDON, ns = ...

local O = {}
ns.BGObj = O

-- the four battlegrounds, by the instance id the game gives (GetInstanceInfo's 8th value)
O.KEYS = { [30] = "AV", [489] = "WSG", [529] = "AB" }
-- seconds from "assaulted" to "captured"
O.CAP = { AV = 300, AB = 60, DI = 60 }
O.FLAG_RESPAWN = 12

-- the map's base icons (textureIndex in the minimap POI icon sheet), as the game draws them:
-- assaulted, with the side doing the assaulting
local ASSAULT = {
  [3] = "a", [13] = "h",                  -- graveyard
  [8] = "a", [11] = "h",                  -- tower / bunker
  [17] = "a", [19] = "h",                 -- mine
  [22] = "a", [24] = "h",                 -- lumber mill
  [27] = "a", [29] = "h",                 -- blacksmith
  [32] = "a", [34] = "h",                 -- farm
  [37] = "a", [39] = "h",                 -- stables
  [208] = "a", [209] = "h", [213] = "a", [214] = "h", [218] = "a", [219] = "h",
}
-- held: the Arathi Basin bases come in fives (neutral, Alliance assaulting, Alliance, Horde
-- assaulting, Horde) from 16 to 40
local function heldBy(icon)
  if type(icon) ~= "number" then return nil end
  if ASSAULT[icon] then return nil end
  if icon >= 16 and icon <= 40 then
    local r = (icon - 16) % 5
    if r == 2 then return "a" elseif r == 4 then return "h" elseif r == 0 then return "n" end
  end
  return nil
end
O.heldBy = heldBy
O.ASSAULT = ASSAULT

-- short names for the chips
local SHORT = {
  ["Stables"] = "ST", ["Blacksmith"] = "BS", ["Lumber Mill"] = "LM", ["Gold Mine"] = "GM", ["Farm"] = "Farm",
  ["Abandoned Tower"] = "Tower", ["Shipwreck Cove"] = "Cove",
}
function O.Short(name)
  if type(name) ~= "string" then return "?" end
  return SHORT[name] or name:match("^(%S+)") or name
end
-- Alterac Valley's towers: the bunkers are the Alliance's, the towers the Horde's
local function avTowerSide(name)
  if type(name) ~= "string" then return nil end
  if name:find("Bunker") then return "a" end
  if name:find("Tower") then return "h" end
  return nil
end
O.avTowerSide = avTowerSide

local function now() return GetTime and GetTime() or ns.Now() end

-- which battleground we're in ("AV", "AB", "WSG", "DI"), or nil
function O.Key()
  if not (ns.InBattleground and ns.InBattleground()) then return nil end
  local ok, name, _, _, _, _, _, _, id = pcall(GetInstanceInfo)
  if not ok then return nil end
  if type(id) == "number" and not ns.isSecret(id) and O.KEYS[id] then return O.KEYS[id] end
  if type(name) == "string" and not ns.isSecret(name) then
    if name:find("Darkspear") then return "DI" end
    if name:find("Alterac") then return "AV" end
    if name:find("Arathi") then return "AB" end
    if name:find("Warsong") then return "WSG" end
  end
  return nil
end

---------------------------------------------------------------------------
-- bases and towers, from the map
---------------------------------------------------------------------------
O.nodes = {}       -- name -> { icon, side (held), atk (assaulting side), since }
O.order = {}

local function readPOIs()
  local A = C_AreaPoiInfo
  if not A or not A.GetAreaPOIForMap or not A.GetAreaPOIInfo or not C_Map or not C_Map.GetBestMapForUnit then return nil end
  local okM, map = pcall(C_Map.GetBestMapForUnit, "player")
  if not okM or type(map) ~= "number" or ns.isSecret(map) then return nil end
  local okP, pois = pcall(A.GetAreaPOIForMap, map)
  if not okP or type(pois) ~= "table" then return nil end
  local out = {}
  for _, id in ipairs(pois) do
    local okI, info = pcall(A.GetAreaPOIInfo, map, id)
    if okI and type(info) == "table" and type(info.name) == "string" and not ns.isSecret(info.name) then
      local icon = info.textureIndex
      if ns.isSecret(icon) then icon = nil end
      out[#out + 1] = { name = info.name, icon = icon, atlas = (not ns.isSecret(info.atlasName)) and info.atlasName or nil, id = id }
    end
  end
  return out
end
O.readPOIs = readPOIs

function O:ScanNodes()
  local list = readPOIs()
  if not list then return end
  local t = now()
  local seen = {}
  for _, p in ipairs(list) do
    seen[p.name] = true
    local n = self.nodes[p.name]
    if not n then
      n = { name = p.name }
      self.nodes[p.name] = n
      self.order[#self.order + 1] = p.name
    end
    local atk = p.icon and ASSAULT[p.icon]
    if atk then
      -- a new assault (or the other side took it back mid-way): the clock starts now. Seen for the
      -- first time already assaulted (after a /reload), we don't know when it started.
      if n.atk ~= atk then n.since = (n.icon ~= nil) and t or nil end
      n.atk = atk
    else
      n.atk, n.since = nil, nil
      local held = heldBy(p.icon)
      if held then n.side = held elseif self.key == "AV" then n.side = avTowerSide(p.name) or n.side end
    end
    n.icon = p.icon or false
  end
  for name, n in pairs(self.nodes) do if not seen[name] then n.gone = true end end
end

-- seconds until an assaulted node falls (nil when we don't know when it started)
function O:Left(n)
  if not n or not n.atk or not n.since then return nil end
  local cap = O.CAP[self.key or ""] or 60
  return math.max(0, math.floor(cap - (now() - n.since)))
end

-- the nodes to show: Arathi Basin and Darkspear Islands every base, Alterac Valley only the
-- ones under attack
function O:Chips()
  local out = {}
  for _, name in ipairs(self.order) do
    local n = self.nodes[name]
    if n and not n.gone then
      if self.key == "AV" then
        if n.atk then out[#out + 1] = n end
      elseif n.atk or n.side or n.icon then
        out[#out + 1] = n
      end
    end
  end
  return out
end

-- Alterac Valley: towers still standing per side (a destroyed tower leaves the tower icons)
function O:TowersStanding()
  local h, a = 0, 0
  for _, n in pairs(self.nodes) do
    local side = avTowerSide(n.name)
    if side and not n.gone and type(n.icon) == "number" and n.icon >= 8 and n.icon <= 11 then
      if side == "h" then h = h + 1 else a = a + 1 end
    end
  end
  if h + a == 0 then return nil end
  return h, a
end

-- (1.4.51) per side: towers standing (burning ones included) and burning (assaulted by the other side)
function O:TowerStates()
  local st = { h = { standing = 0, burning = 0 }, a = { standing = 0, burning = 0 } }
  local any = false
  for _, n in pairs(self.nodes) do
    local side = avTowerSide(n.name)
    if side and not n.gone and type(n.icon) == "number" and n.icon >= 8 and n.icon <= 11 then
      any = true
      st[side].standing = st[side].standing + 1
      if n.atk and n.atk ~= side then st[side].burning = st[side].burning + 1 end
    end
  end
  if not any then return nil end
  return st
end

---------------------------------------------------------------------------
-- the score display at the top of the screen
---------------------------------------------------------------------------
local function clean(t) return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- { a = {score, max, bases}, h = {…} } or nil. Arathi Basin uses widget 1893 (Alliance) and 1894
-- (Horde); otherwise the two "n/max" texts in the order the game shows them (Alliance first)
function O:Score()
  local W = C_UIWidgetManager
  if not W or not W.GetIconAndTextWidgetVisualizationInfo then return nil end
  local function parse(id)
    local ok, info = pcall(W.GetIconAndTextWidgetVisualizationInfo, id)
    local t = ok and type(info) == "table" and info.text
    if type(t) ~= "string" or ns.isSecret(t) then return nil end
    t = clean(t)
    local s, m = t:match("(%d+)%s*/%s*(%d+)")
    if not s then return nil end
    return { score = tonumber(s), max = tonumber(m), bases = tonumber(t:match("(%d+)[^%d/]+%d+%s*/")) }
  end
  local a, h = parse(1893), parse(1894)
  if a and h then return { a = a, h = h } end
  if not W.GetTopCenterWidgetSetID or not W.GetAllWidgetsBySetID then return nil end
  local ok, set = pcall(W.GetTopCenterWidgetSetID)
  if not ok or not set then return nil end
  local ok2, widgets = pcall(W.GetAllWidgetsBySetID, set)
  if not ok2 or type(widgets) ~= "table" then return nil end
  local found = {}
  for _, w in ipairs(widgets) do
    if w.widgetType == 0 then
      local r = parse(w.widgetID)
      if r then found[#found + 1] = r end
    end
  end
  if #found >= 2 then return { a = found[1], h = found[2] } end
  return nil
end

-- win estimate from how fast each side's score has been going up the last minute
O.samples = {}
function O:Sample(sc)
  if not sc then return end
  local t = now()
  local s = self.samples
  local last = s[#s]
  if last and last.a == sc.a.score and last.h == sc.h.score and t - last.t < 30 then return end
  s[#s + 1] = { t = t, a = sc.a.score, h = sc.h.score }
  while #s > 2 and t - s[2].t > 90 do table.remove(s, 1) end
end

-- "h"/"a" and seconds, or nil when there's nothing to go on yet
function O:Estimate(sc)
  sc = sc or self:Score()
  local s = self.samples
  if not sc or #s < 2 then return nil end
  local first, last = s[1], s[#s]
  local dt = last.t - first.t
  if dt < 20 then return nil end
  local ra, rh = (last.a - first.a) / dt, (last.h - first.h) / dt
  local max = sc.a.max or 2000
  local ta = ra > 0 and (max - sc.a.score) / ra or math.huge
  local th = rh > 0 and (max - sc.h.score) / rh or math.huge
  if ta == math.huge and th == math.huge then return nil end
  if th <= ta then return "h", th end
  return "a", ta
end

-- Warsong Gulch: flags captured per side, and the respawn after a capture
function O:Flags()
  local sc = self:Score()
  if not sc then return nil end
  return sc.h.score, sc.a.score
end
function O:NoteFlags()
  local h, a = self:Flags()
  if not h then return end
  if self.lastFlags and (h > self.lastFlags[1] or a > self.lastFlags[2]) then self.respawnAt = now() + O.FLAG_RESPAWN end
  self.lastFlags = { h, a }
end
function O:RespawnLeft()
  if not self.respawnAt then return nil end
  local left = math.ceil(self.respawnAt - now())
  if left <= 0 then self.respawnAt = nil return nil end
  return left
end

---------------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------------
function O:Reset(key)
  self.key = key
  self.nodes, self.order, self.samples = {}, {}, {}
  self.lastFlags, self.respawnAt = nil, nil
end

function O:Update()
  local key = O.Key()
  if key ~= self.key then self:Reset(key) end
  if not key then return end
  if key ~= "WSG" then self:ScanNodes() end
  if key == "AB" or key == "DI" then self:Sample(self:Score()) end
  if key == "WSG" then self:NoteFlags() end
end

ns:On("PLAYER_ENTERING_WORLD", function() O:Reset(nil) C_Timer.After(2, function() O:Update() ns:Fire("BGOBJ") end) end)
ns:On("AREA_POIS_UPDATED", function() if O.key then O:Update() ns:Fire("BGOBJ") end end)
ns:On("UPDATE_UI_WIDGET", function() if O.key then O:Update() ns:Fire("BGOBJ") end end)

-- /chill bgdebug: what the game shows us here, to tune the panel for a battleground
function O.Debug()
  ns.Print("Battleground: " .. tostring(O.Key()))
  local list = readPOIs()
  if not list then ns.Print("No map points readable here.") else
    for _, p in ipairs(list) do print(string.format("  %s  icon=%s  atlas=%s", p.name, tostring(p.icon), tostring(p.atlas))) end
  end
  local sc = O:Score()
  if sc then print(string.format("  score A %s/%s (%s bases)  H %s/%s (%s bases)", sc.a.score, sc.a.max, tostring(sc.a.bases), sc.h.score, sc.h.max, tostring(sc.h.bases))) end
  for _, u in ipairs({ "arena1", "arena2" }) do
    local ok, ex = pcall(UnitExists, u)
    local okN, nm = pcall(UnitName, u)
    print("  " .. u .. ": " .. ((ok and ex and not ns.isSecret(ex)) and ((okN and type(nm) == "string" and not ns.isSecret(nm)) and nm or "(hidden name)") or "-"))
  end
end
