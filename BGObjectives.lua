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
-- map points that aren't bases: the centre flag ("Darkspear …" in Darkspear Islands), flags
function O.NotABase(name)
  if type(name) ~= "string" then return true end
  return name:find("^Darkspear") ~= nil or name:find("Flag") ~= nil
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

O.AV_TOWERS = {
  h = { "Iceblood Tower", "Tower Point", "East Frostwolf Tower", "West Frostwolf Tower" },
  a = { "Stonehearth Bunker", "Icewing Bunker", "Dun Baldar South Bunker", "Dun Baldar North Bunker" },
}
-- (1.4.52) one side's towers for the hover: name and "standing", "burning" (seconds left or nil) or "gone"
function O:TowerList(side)
  local out = {}
  for _, name in ipairs(O.AV_TOWERS[side] or {}) do
    local n = self.nodes[name]
    local state
    if not n or n.gone or type(n.icon) ~= "number" or n.icon < 8 or n.icon > 11 then state = n and "gone" or "unknown"
    elseif n.atk and n.atk ~= side then state = "burning"
    else state = "standing" end
    out[#out + 1] = { name = name, state = state, left = (state == "burning") and self:Left(n) or nil }
  end
  return out
end

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
      local desc = info.description
      if ns.isSecret(desc) or type(desc) ~= "string" then desc = nil end
      out[#out + 1] = { name = info.name, icon = icon, atlas = (not ns.isSecret(info.atlasName)) and info.atlasName or nil, id = id, desc = desc }
    end
  end
  return out
end
O.readPOIs = readPOIs

function O:ScanNodes(fresh)
  local list = readPOIs()
  if not list then return end
  self.changedNow = {}
  local t = now()
  local seen = {}
  for _, p in ipairs(list) do
    seen[p.name] = true
    local n = self.nodes[p.name]
    if not n then
      self:LogIcon(p.name, "first", p.icon, p.atlas, p.desc)
      n = { name = p.name }
      self.nodes[p.name] = n
      self.order[#self.order + 1] = p.name
    end
    -- (1.4.54) what this icon means: learned in earlier games first (Forever's own numbers), else
    -- the classic numbers
    local L = p.icon and self:Learned()[p.icon]
    local atk, held
    if L then
      if L.k == "atk" then atk = L.s else held = L.s end
    else
      atk = p.icon and ASSAULT[p.icon]
      held = heldBy(p.icon)
    end
    local dl = p.desc and p.desc:lower()
    if dl then
      if dl:find("horde") and dl:find("control") then atk, held = nil, "h"
      elseif dl:find("alliance") and dl:find("control") then atk, held = nil, "a" end
    end
    -- (1.4.52) an attack counts only when we SEE the icon change to an assault icon, as Capping does.
    -- An icon that was already there when we joined or reloaded says nothing for sure (live 24 Nov:
    -- every Alliance bunker read "burning" two minutes into a game). Attacks we did see survive a
    -- /reload (O:Restore).
    local changed = n.icon ~= nil and n.icon ~= false and p.icon ~= n.icon
    if changed then
      self:LogIcon(p.name, n.icon, p.icon, p.atlas, p.desc)
      n.prevIcon = n.icon
      self.changedNow[#self.changedNow + 1] = n
    end
    if atk then
      if changed and n.atk ~= atk then n.atk, n.since = atk, t end
    elseif held then
      n.atk, n.since = nil, nil
      n.side = held
    elseif changed and self.key ~= "AV" then
      -- an icon we don't know yet, seen changing: something is being taken, by whom we'll learn
      n.atk, n.since = "?", t
    elseif n.atk == "?" and n.since and t - n.since > (O.CAP[self.key or ""] or 60) + 5 then
      n.atk, n.since = nil, nil
    elseif not changed and not n.atk then
      if self.key == "AV" then n.side = avTowerSide(p.name) or n.side end
    end
    n.icon = p.icon or false
  end
  for name, n in pairs(self.nodes) do if not seen[name] then n.gone = true end end
  if fresh then self:Restore() end
  self:Save()
end

-- (1.4.54) Forever's icons, learned: per battleground, icon -> { k = "held"/"atk", s = "h"/"a" }
function O:Learned()
  if not ns.db then return {} end
  ns.db.bgLearn = ns.db.bgLearn or {}
  local k = self.key or "?"
  ns.db.bgLearn[k] = ns.db.bgLearn[k] or {}
  return ns.db.bgLearn[k]
end
function O:Learn(icon, k, side)
  if type(icon) ~= "number" or not side then return end
  local L = self:Learned()
  local old = L[icon]
  if old and old.k == k and old.s == side then return end
  L[icon] = { k = k, s = side }
  self:LogIcon("learned", tostring(icon), k .. " " .. side)
end
-- the score display counts bases per side: an icon that changes as a count changes says what it is
function O:LearnFromCounts(sc)
  if not sc or not sc.h.bases or not sc.a.bases then self.prevBases = nil return end
  local prev = self.prevBases
  self.prevBases = { h = sc.h.bases, a = sc.a.bases }
  local ch = self.changedNow or {}
  if not prev or #ch ~= 1 then return end
  local n = ch[1]
  local dh, da = sc.h.bases - prev.h, sc.a.bases - prev.a
  local function held(side)
    self:Learn(n.icon, "held", side)
    -- what it showed while being taken was the same side's assault icon
    if type(n.prevIcon) == "number" and not (self:Learned()[n.prevIcon] and self:Learned()[n.prevIcon].k == "held") then
      self:Learn(n.prevIcon, "atk", side)
    end
    n.atk, n.since, n.side = nil, nil, side
  end
  local function lost(owner)
    local taker = owner == "h" and "a" or "h"
    self:Learn(n.icon, "atk", taker)
    if n.atk == "?" or not n.atk then n.atk = taker n.since = n.since or now() end
  end
  if dh == 1 and da == 0 then held("h")
  elseif da == 1 and dh == 0 then held("a")
  elseif dh == -1 and da == 0 then lost("h")
  elseif da == -1 and dh == 0 then lost("a") end
end

-- what the score display shows, logged once per new text (to read Forever's own layout afterwards)
function O:LogWidgets()
  local W = C_UIWidgetManager
  if not W or not W.GetTopCenterWidgetSetID or not W.GetAllWidgetsBySetID then return end
  local ok, set = pcall(W.GetTopCenterWidgetSetID)
  local ok2, widgets = pcall(W.GetAllWidgetsBySetID, ok and set or 0)
  if not ok2 or type(widgets) ~= "table" then return end
  self.seenW = self.seenW or {}
  for _, w in ipairs(widgets) do
    local line
    if w.widgetType == 0 and W.GetIconAndTextWidgetVisualizationInfo then
      local okI, info = pcall(W.GetIconAndTextWidgetVisualizationInfo, w.widgetID)
      local t = okI and type(info) == "table" and info.text
      if type(t) == "string" and not ns.isSecret(t) then line = "text " .. t end
    elseif w.widgetType == 3 and W.GetDoubleStatusBarWidgetVisualizationInfo then
      local okI, info = pcall(W.GetDoubleStatusBarWidgetVisualizationInfo, w.widgetID)
      if okI and type(info) == "table" then line = string.format("double %s/%s vs %s/%s", tostring(info.leftBarValue), tostring(info.leftBarMax), tostring(info.rightBarValue), tostring(info.rightBarMax)) end
    end
    line = "widget " .. tostring(w.widgetID) .. " type " .. tostring(w.widgetType) .. (line and (": " .. line:gsub("%d+", "#")) or "")
    if not self.seenW[line] then
      self.seenW[line] = true
      self:LogIcon("widget", "", line)
    end
  end
end

-- what we saw change, for checking the icon numbers afterwards (SavedVariables, last 200)
function O:LogIcon(name, from, to, atlas, desc)
  if not ns.db then return end
  local log = ns.db.bgIconLog or {}
  ns.db.bgIconLog = log
  log[#log + 1] = string.format("%s %s %s: %s -> %s  atlas=%s  desc=%s", date("%d.%m %H:%M:%S"), self.key or "?", name, tostring(from), tostring(to), tostring(atlas), tostring(desc))
  while #log > 400 do table.remove(log, 1) end
end

-- the attacks we saw, kept over a /reload (GetTime keeps running across one)
function O:Save()
  if not ns.db or not self.key then return end
  local atk = {}
  for name, n in pairs(self.nodes) do if n.atk and n.since then atk[name] = { n.atk, n.since } end end
  ns.db.bgObjSave = { key = self.key, at = now(), atk = atk }
end
function O:Restore()
  local sv = ns.db and ns.db.bgObjSave
  if not sv or sv.key ~= self.key or not sv.at or now() - sv.at > 120 or now() < sv.at then return end
  for name, a in pairs(sv.atk or {}) do
    local n = self.nodes[name]
    if n and not n.atk and type(n.icon) == "number" and ASSAULT[n.icon] == a[1] then n.atk, n.since = a[1], a[2] end
  end
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
      elseif (n.atk or n.side or n.icon) and not O.NotABase(n.name) then
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
  -- (1.4.54) the other style: one bar per side (Alliance left, Horde right)
  if W.GetDoubleStatusBarWidgetVisualizationInfo then
    for _, w in ipairs(widgets) do
      if w.widgetType == 3 then
        local okD, d = pcall(W.GetDoubleStatusBarWidgetVisualizationInfo, w.widgetID)
        local l, r = okD and type(d) == "table" and d.leftBarValue, okD and type(d) == "table" and d.rightBarValue
        if type(l) == "number" and type(r) == "number" and not ns.isSecret(l) and not ns.isSecret(r) then
          local m = (not ns.isSecret(d.leftBarMax) and d.leftBarMax) or 2000
          local base = found[1] and found[2] and found or nil
          return { a = { score = l, max = m, bases = base and base[1].bases }, h = { score = r, max = m, bases = base and base[2].bases } }
        end
      end
    end
  end
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

-- (1.4.54) flags away from their base, from the map: { x, y, owner ("h"/"a" from the flag's
-- picture, nil for the Darkspear Islands flag), near (the closest base or graveyard by name) }
function O:FlagSpots()
  local okN, n = pcall(GetNumBattlefieldFlagPositions)
  if not okN or type(n) ~= "number" or ns.isSecret(n) or n < 1 then return nil end
  local okM, map = pcall(C_Map.GetBestMapForUnit, "player")
  local out = {}
  for i = 1, n do
    local ok, x, y, tex
    if C_PvP and C_PvP.GetBattlefieldFlagPosition and okM and map then ok, x, y, tex = pcall(C_PvP.GetBattlefieldFlagPosition, i, map) end
    if not ok or not x then ok, x, y, tex = pcall(GetBattlefieldFlagPosition, i) end
    if ok and type(x) == "number" and not ns.isSecret(x) and not ns.isSecret(y) and x > 0 then
      local t = (type(tex) == "string" and not ns.isSecret(tex)) and tex:lower() or ""
      local owner = t:find("horde") and "h" or t:find("alliance") and "a" or nil
      out[#out + 1] = { x = x, y = y, owner = owner, tex = tex, near = self:Near(x, y) }
    end
  end
  return out
end

-- the closest named map point to x, y (map coordinates 0-1)
function O:Near(x, y)
  local A = C_AreaPoiInfo
  local okM, map = pcall(C_Map.GetBestMapForUnit, "player")
  if not A or not okM or not map then return nil end
  local okP, pois = pcall(A.GetAreaPOIForMap, map)
  if not okP or type(pois) ~= "table" then return nil end
  local best, bd
  for _, id in ipairs(pois) do
    local ok, info = pcall(A.GetAreaPOIInfo, map, id)
    local pos = ok and type(info) == "table" and info.position
    if pos and pos.GetXY and type(info.name) == "string" and not ns.isSecret(info.name) then
      local px, py = pos:GetXY()
      if type(px) == "number" and not ns.isSecret(px) then
        local d = (px - x) ^ 2 + (py - y) ^ 2
        if not bd or d < bd then best, bd = info.name, d end
      end
    end
  end
  return best and O.Short(best) or nil
end

---------------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------------
function O:Reset(key)
  self.key = key
  self.prevBases, self.changedNow, self.seenW = nil, {}, nil
  self.nodes, self.order, self.samples = {}, {}, {}
  self.lastFlags, self.respawnAt = nil, nil
end

function O:Update()
  local key = O.Key()
  local fresh = key ~= self.key
  if fresh then self:Reset(key) end
  if not key then return end
  if key ~= "WSG" then
    self:ScanNodes(fresh)
  end
  if key == "AB" or key == "DI" then
    local sc = self:Score()
    self:Sample(sc)
    self:LearnFromCounts(sc)
    self:LogWidgets()
  end
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
    for _, p in ipairs(list) do print(string.format("  %s  icon=%s  atlas=%s  desc=%s", p.name, tostring(p.icon), tostring(p.atlas), tostring(p.desc))) end
  end
  local sc = O:Score()
  if sc then print(string.format("  score A %s/%s (%s bases)  H %s/%s (%s bases)", sc.a.score, sc.a.max, tostring(sc.a.bases), sc.h.score, sc.h.max, tostring(sc.h.bases))) end
  for i, sp in ipairs(O:FlagSpots() or {}) do
    print(string.format("  flag %d: %.2f, %.2f  %s  near %s", i, sp.x, sp.y, tostring(sp.tex), tostring(sp.near)))
  end
  for _, u in ipairs({ "arena1", "arena2" }) do
    local ok, ex = pcall(UnitExists, u)
    local okN, nm = pcall(UnitName, u)
    print("  " .. u .. ": " .. ((ok and ex and not ns.isSecret(ex)) and ((okN and type(nm) == "string" and not ns.isSecret(nm)) and nm or "(hidden name)") or "-"))
  end
end
