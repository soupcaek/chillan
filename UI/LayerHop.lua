-- Chillan? – layer hop: change layer by joining the group of someone on another layer.
-- In WoW Forever you move to the leader's layer when you join their group (Blizzard's "shard
-- transfer"), and on live Forever the new layer stays after you leave again.
--
-- 1) The gang: every Chillan knows its own layer (Layer.lua) and shares it with its status.
--    A hop asks the gang; a friend in the same zone on another layer invites by itself
--    (setting "layerHost"), the asker accepts, checks that it moved, and leaves 4 s later.
-- 2) LayerSwap users: when nobody in the gang can help, the same click asks the players in
--    the zone who run the LayerSwap addon, in LayerSwap's own hidden whisper format.
--    Hosting for them is opt-in (setting "layerStrangers"), with LayerSwap's own limits.
local ADDON, ns = ...
local UI, C, hex, Comm = ns.UI, ns.C, ns.hex, ns.Comm

local L = {}
ns.LayerHop = L
L.mine = nil      -- my open request { id, t, from, map, mode, whispered, joinedAt, host }
L.open = {}       -- requests from others I can answer: id -> { pid, target, t }

local LS_PREFIX = "LayerSwap"
local function testWhoLater(how) if L.TestWho then L.TestWho(how) end end
local REQUEST_TTL = 90
local VERIFY_AFTER = 15     -- no move this long after joining: the host stood on our layer
-- after a confirmed move, leave the host's group. LayerSwap 1.14.25: 4 s (it tried 30 s, and hosts got
-- pulled onto their guests' layers; every swap proven on live left within a few seconds)
local LEAVE_AFTER = 4
local HOST_MAX, HOST_WINDOW, HOST_PER_PLAYER = 6, 600, 60
local ZONE_MAP = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3

local secret, S = ns.U.Secret, ns.U.Settings

local function inGroup() return IsInGroup and IsInGroup() and true or false end
local inCombat = ns.U.InCombat
local function inInstance() return (ns.S(IsInInstance)) and true or false end

-- listed in the group finder or queued for a dungeon: a guest joining would take us off the list
local function listed()
  if C_LFGList and C_LFGList.HasActiveEntryInfo then
    local ok, v = pcall(C_LFGList.HasActiveEntryInfo)
    if ok and not secret(v) and v == true then return true end
  end
  if GetLFGMode then
    for cat = 1, (type(NUM_LE_LFG_CATEGORYS) == "number" and NUM_LE_LFG_CATEGORYS or 0) do
      local ok, mode = pcall(GetLFGMode, cat)
      if ok and not secret(mode) and (mode == "queued" or mode == "listed" or mode == "rolecheck" or mode == "proposal") then return true end
    end
  end
  return false
end
-- the game counts down to a world refresh: a guest let in now would go with us when it hits
L.evictAt = nil
local function refreshing()
  local at = L.evictAt
  if not at then return false end
  if GetTime() > at + 120 then L.evictAt = nil return false end
  return true
end
local function evictUpdate()
  local left
  if GetEvictionTimeRemaining then
    local ok, v = pcall(GetEvictionTimeRemaining)
    if ok and not secret(v) and type(v) == "number" and v > 0 then left = v end
  end
  L.evictAt = left and (GetTime() + left) or nil
end
ns:On("SHARD_TRANSFER_IMMINENT", evictUpdate)
ns:On("SHARD_TRANSFER_CANCELLED", evictUpdate)
ns:On("SHARD_TRANSFER", function() L.evictAt = nil end)

-- why we can't host right now (nil = we can)
function L.PauseWhy()
  if inGroup() then return "in a group" end
  if inInstance() then return "in an instance" end
  if inCombat() then return "in combat" end
  if ns.S(UnitIsDeadOrGhost, "player") then return "dead" end
  if listed() then return "in the group finder" end
  if refreshing() then return "a world refresh is counting down" end
end
local function canHelp() return L.PauseWhy() == nil end

-- the zone-level map we stand in (a city or cave map counts as its zone), like LayerSwap
local function zoneMap()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
  if not ok or secret(id) or type(id) ~= "number" or id <= 0 then return nil end
  local zone = id
  for _ = 1, 6 do
    local found, info = pcall(C_Map.GetMapInfo, zone)
    if not found or type(info) ~= "table" or secret(info.mapType) or type(info.mapType) ~= "number" then break end
    if info.mapType == ZONE_MAP then return zone end
    local up = info.parentMapID
    if info.mapType < ZONE_MAP or secret(up) or type(up) ~= "number" or up <= 0 then break end
    zone = up
  end
  return id
end
L.ZoneMap = zoneMap

local function mapPos(map)
  if not map then return nil end
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
  if not ok or not pos then return nil end
  local x, y = pos:GetXY()
  if not x or secret(x) or secret(y) or (x == 0 and y == 0) then return nil end
  return x, y
end

local norm = ns.U.NormName

local isGangChar = ns.U.IsGangChar

local function leave()
  local fn = (C_PartyInfo and C_PartyInfo.LeaveParty) or LeaveParty
  if fn then pcall(fn) end
end

-- (1.2.1) leave the hop group, and keep at it: every 2 s for up to 30 s (combat, a loading screen or a
-- call the game ignored only delay it). It used to try once, and only in a group of 2 – a host with
-- another hopper already in their group, or a fight at the wrong moment, left you in the group.
-- Never leaves a raid or a dungeon group.
local leaving
local done, notMoved   -- (1.4.13) defined further down, used by the join handler
local function leaveHop()
  if leaving then return end
  leaving = true
  local tries = 0
  local function try()
    if not inGroup() or (IsInRaid and IsInRaid()) or (ns.S(IsInInstance)) then leaving = nil return end
    tries = tries + 1
    if not inCombat() then
      local f1 = C_PartyInfo and C_PartyInfo.LeaveParty
      if f1 then pcall(f1) end
      if LeaveParty and LeaveParty ~= f1 then pcall(LeaveParty) end
    end
    if tries >= 15 then
      leaving = nil
      if inGroup() then ns.Print("Layer hop: couldn't leave the group by itself – type /leave (the new layer stays).") end
      return
    end
    C_Timer.After(2, try)
  end
  try()
end
L.LeaveHop = leaveHop

local function label(key) return (ns.Layer and ns.Layer.Label(key)) or "a new layer" end

-- gang members who could move me: online, same zone, known layer that isn't mine
function L:GangHosts()
  local mine, map = ns.Layer and ns.Layer:Current(), zoneMap()
  local myZone = ns.Tracker:Me().live and ns.Tracker:Me().live.zone
  local out = {}
  for pid, p in pairs(ns.db.people or {}) do
    local lv = p.live
    local otherLayer = (ns.Layer and ns.Layer.Private()) or (lv and lv.layer and lv.layer ~= mine)
    if pid ~= ns.pid and p.main and ns:IsOnline(p) and lv and not lv.inInst
      and otherLayer and lv.zone and lv.zone == myZone then
      out[#out + 1] = p
    end
  end
  return out, mine, map
end

---------------------------------------------------------------------------
-- asking
---------------------------------------------------------------------------
-- (1.4.13) the game moves a character into a host's layer 10 times in an hour, then refuses without a
-- word (LayerSwap 1.14.38-41, from logs). An hour opens with the first move after the last hour closed.
-- Kept per character, across logins. A hop that didn't move us twice in 10 minutes holds 15 minutes
-- (we may be over a limit we didn't count, e.g. moves made in another addon).
L.CAP, L.CAP_FOR, L.CAP_UNSURE = 10, 3600, 15 * 60
local function capData()
  ns.db.layerCap = ns.db.layerCap or {}
  local me = ns.Comm:MyFull()
  ns.db.layerCap[me] = ns.db.layerCap[me] or { start = 0, n = 0 }
  return ns.db.layerCap[me]
end
function L.CountMove()
  local c = capData()
  local now = time()
  if now - (c.start or 0) >= L.CAP_FOR then c.start, c.n = now, 0 end
  c.n = (c.n or 0) + 1
  c.last = now
end
-- (1.4.17) seconds since our last counted move, or nil
function L.SinceMove()
  local c = capData()
  if not c.last then return nil end
  return time() - c.last
end
-- seconds to wait before a hop can work, or nil; and hops left this hour
function L.CapWait()
  local c = capData()
  local now = time()
  if c.holdUntil and now < c.holdUntil then return c.holdUntil - now, 0 end
  if now - (c.start or 0) >= L.CAP_FOR then return nil, L.CAP end
  local left = L.CAP - (c.n or 0)
  if left <= 0 then return (c.start + L.CAP_FOR) - now, 0 end
  return nil, left
end
-- (1.4.41) a refusal while fewer than 10 moves are known holds nothing (LayerSwap stopped holding too,
-- after players were held 15 minutes without having moved): the next click may simply try again
function L.NoteRefusal()
  local c = capData()
  c.lastRefusal = time()
  c.holdUntil = nil
end
local function mmss(sec) return string.format("%d:%02d", math.floor(sec / 60), sec % 60) end

function L:Request()
  local m = self.mine
  local wait = L.CapWait()
  if wait and not (m and m.joinedAt) then
    ns.Print("Layer hop: the game only allows about 10 layer changes an hour, and you've used them – try again in " .. mmss(wait) .. ".")
    return
  end
  -- a round of asks that's done without an invite: a new click starts a fresh round
  if m and m.mode == "ls" and m.doneAt and not m.joinedAt and not m.by and GetTime() - m.doneAt > 3 then
    -- (1.4.72) no AutoLayer line in the chat box any more: it opened the chat box (as a whisper) mid-hop
    self.mine, m = nil, nil
  end
  local pending = m and not m.joinedAt and ns.Now() - m.t < REQUEST_TTL
  -- the zone search must be the very first thing a click does: the game allows it only straight
  -- from a click or a typed command (tested: the same search typed works, after other work it's blocked)
  if (not pending or m.mode == "gang") and not (IsInGroup and IsInGroup()) and not (InCombatLockdown and InCombatLockdown()) then
    self:StartSearch()
  end
  if inGroup() then
    ns.Print("Leave your group first – you change layer by joining someone's group.")
    return
  end
  if inInstance() then ns.Print("You can't change layer inside a dungeon.") return end
  if inCombat() then ns.Print("Not in combat.") return end
  -- (1.4.42) part of LayerSwap's rules (r3): no ask while dead or a ghost
  if ns.S(UnitIsDeadOrGhost, "player") then ns.Print("Not while you're dead.") return end
  if pending then
    if m.mode == "gang" then self:AskLayerSwap(m) else ns.Print("Already asking for a layer hop…") end
    return
  end
  local hosts, from, map = self:GangHosts()
  local id = Comm:NewId()
  m = { id = id, t = ns.Now(), from = from, map = map, mode = "gang", whispered = {} }
  self.mine = m
  if #hosts == 0 then
    -- nobody in the gang can move us: don't bother them, go straight to LayerSwap users
    m.noGang = true
    self:AskLayerSwap(m)
  else
    C_Timer.After(0.1, function()
      Comm:Broadcast(Comm:Build("LQ", id, ns.pid, Comm:MyFull(), ns.Now(), from or "", map or ""), 1)
    end)
    -- (1.4.72) quiet while working: the Swap tile shows how it goes
    -- no gang invite after a while: the LayerSwap users this click found get the ask
    C_Timer.After(10, function()
      if self.mine == m and not m.by and not m.joinedAt and m.mode == "gang" then self:AskLayerSwap(m) end
    end)
  end
  ns:Fire("LAYERHOP")
  C_Timer.After(REQUEST_TTL, function()
    if self.mine == m and not m.joinedAt then
      ns.Print("Layer hop: nobody could invite you right now. Busier zones have more layers.")
      self.mine = nil
      ns:Fire("LAYERHOP")
    end
  end)
end

---------------------------------------------------------------------------
-- helping the gang
---------------------------------------------------------------------------
Comm:Handle("LQ", function(f)
  local id, pid, target, at = f[1], f[2], f[3], tonumber(f[4])
  if not id or not pid or pid == ns.pid or not target or target == "" then return end
  -- only fresh requests (never old ones that arrive late, e.g. right after login)
  if not at or math.abs(ns.Now() - at) > 60 then return end
  if not canHelp() then return end
  local askerLayer, askerMap = f[5], tonumber(f[6] or "")
  local mine = ns.Layer and ns.Layer:Current()
  L.open[id] = { pid = pid, target = target, t = ns.Now() }
  if askerLayer == nil then L:ShowAsk(id) return end     -- asker on an older Chillan
  -- I'm on their layer: inviting would change nothing
  if mine and askerLayer ~= "" and mine == askerLayer then L.open[id] = nil return end
  -- only someone in the same zone can move them
  local myMap = zoneMap()
  if askerMap and myMap and askerMap ~= myMap then L.open[id] = nil return end
  if not mine then L.open[id] = nil return end   -- can't tell whether I'd move them
  if S().layerHost ~= false then
    -- several of us may hear it: a random short wait, and the first one claims it
    C_Timer.After(0.3 + math.random() * 1.7, function()
      if L.open[id] and canHelp() then L:Help(id, true) end
    end)
  else
    L:ShowAsk(id)
  end
end)

-- someone took it: close the popup everywhere, tell the asker who's inviting
Comm:Handle("LK", function(f)
  local id, by = f[1], f[2]
  if not id then return end
  L.open[id] = nil
  if L.frame and L.frame.id == id then L.frame:Hide() end
  if L.mine and L.mine.id == id and by and by ~= ns.pid and not L.mine.by then
    L.mine.by = by
    local p = ns:GetPerson(by)
    ns.Print((p and ns:ShortWho(p) or "Someone") .. " is inviting you for a layer hop.")
    ns:Fire("LAYERHOP")
  end
end)

-- (1.2.1) host side: if the friend we invited for a hop is still in our group of two a minute later
-- (their leave didn't go through), we leave – that ends the group, and they keep the layer
function L.HostFallback(target)
  C_Timer.After(60, function()
    if not inGroup() or (IsInRaid and IsInRaid()) then return end
    local members = GetNumGroupMembers and GetNumGroupMembers() or 0
    if members ~= 2 then return end
    local short = ns.ShortName(target or ""):lower()
    local there = false
    for i = 1, 4 do
      local n = ns.S(UnitName, "party" .. i)
      if type(n) == "string" and n:lower() == short then there = true end
    end
    if there then
      ns.Print("Layer hop: " .. ns.ShortName(target) .. " is still in your group a minute after the hop – leaving so it ends.")
      leaveHop()
    end
  end)
end

function L:Help(id, auto)
  local r = self.open[id]
  if not r then return end
  self.open[id] = nil
  Comm:Broadcast(Comm:Build("LK", id, ns.pid), 1)
  ns.Invite(r.target)
  ns.Cnt("layerHosted")
  L.HostFallback(r.target)
  if self.frame then self.frame:Hide() end
  if auto then
    local p = ns:GetPerson(r.pid)
    ns.Print("Layer hop: invited " .. ((p and ns:ShortWho(p)) or ns.ShortName(r.target)) .. " to your layer. They leave by themselves.")
  end
end

---------------------------------------------------------------------------
-- LayerSwap users: their hidden whisper "inv layer <LS map not 1234-0 48.2,42.5>"
---------------------------------------------------------------------------
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, LS_PREFIX) end

L.LS_RULES = 3
local function lsLine(m)
  local parts = { "<LS" }
  if m.map then parts[#parts + 1] = tostring(m.map) end
  if m.from then parts[#parts + 1] = "not " .. m.from .. "-0" end
  -- (1.4.42) LayerSwap's rules marker: from LayerSwap 1.14.52 its hosts invite only asks that carry it.
  -- r3 = at most 10 moves an hour, no ask in combat, no ask while dead or a ghost (L:Blocked) – and the
  -- invite from a LayerSwap host is left to the player to accept (see PARTY_INVITE_REQUEST)
  parts[#parts + 1] = "r" .. L.LS_RULES
  local x, y = mapPos(m.map)
  if m.map and x then parts[#parts + 1] = string.format("%.1f,%.1f", x * 100, y * 100) end
  return "inv layer " .. table.concat(parts, " ") .. ">"
end

-- LayerSwap users we know of, learned without any search: every LayerSwap user who asks for a hop
-- nearby whispers the players of the zone (us too) and names the layer it leaves; every host that
-- answers our ask says its layer. ns.db.lsBook[name] = { at, layer, zone, host }
-- kept a week (LayerSwap 1.14.25): a known host is rare. A layer it told us is only trusted for an hour
-- (layers change at every world refresh); one the game says isn't online is paused 10 min, not dropped.
local BOOK_TTL, BOOK_MAX, LAYER_FRESH, GONE_FOR = 7 * 86400, 300, 3600, 600
local function book()
  ns.db.lsBook = ns.db.lsBook or {}
  return ns.db.lsBook
end
local function learn(name, layer, zone, host)
  if type(name) ~= "string" or name == "" or secret(name) or isGangChar(name) then return end
  local b = book()
  local e = b[name] or {}
  e.at, e.gone = time(), nil
  if layer and layer ~= "" then e.layer, e.layerAt = layer, time() end
  if zone then e.zone = tonumber(zone) or e.zone end
  if host ~= nil then e.host = host or nil end
  b[name] = e
end
L.Learn = learn
local function pruneBook()
  local b, n, t, list = book(), 0, time(), {}
  for name, e in pairs(b) do
    if type(e) ~= "table" or t - (e.at or 0) > BOOK_TTL then b[name] = nil else n = n + 1 list[n] = name end
  end
  if n > BOOK_MAX then
    table.sort(list, function(a, c) return (b[a].at or 0) > (b[c].at or 0) end)
    for i = BOOK_MAX + 1, n do b[list[i]] = nil end
    n = BOOK_MAX
  end
  return n
end
local function gone(e) return type(e.gone) == "number" and time() - e.gone < GONE_FOR end
local function layerOf(e) return (e.layer and time() - (e.layerAt or e.at or 0) < LAYER_FRESH) and e.layer or nil end
-- LayerSwap's own list, when LayerSwap runs too
local function seedFromLayerSwap()
  local db = rawget(_G, "LayerSwapDB")
  if type(db) ~= "table" or type(db.book) ~= "table" then return end
  for name, e in pairs(db.book) do
    if type(e) == "table" and type(e.at) == "number" and time() - e.at < BOOK_TTL then
      learn(name, type(e.layer) == "string" and e.layer:match("^(%d+)") or nil, e.zone, e.host and true or nil)
    end
  end
end

-- players who wrote in a chat channel lately: real players, perhaps LayerSwap users (only they can
-- read our hidden ask). Zone channels (General) are tied to our zone; custom ones (like "layer") aren't.
local chatters = {}   -- name -> { at, map }
ns:On("CHAT_MSG_CHANNEL", function(text, sender, _, _, _, _, zoneChannelID)
  if secret(sender) or type(sender) ~= "string" or sender == "" then return end
  local me = ns.S(UnitName, "player")
  if type(me) == "string" and norm(sender) == norm(me) then return end
  if isGangChar(sender) then return end
  local zoned = not secret(zoneChannelID) and type(zoneChannelID) == "number" and zoneChannelID > 0
  chatters[sender] = { at = time(), map = zoned and zoneMap() or nil }
end)
local function chatterNames(m, skip, out, limit)
  local list, t = {}, time()
  for name, c in pairs(chatters) do
    if t - c.at > 3600 then chatters[name] = nil
    elseif not skip[norm(name)] and (not c.map or not m.map or c.map == m.map) then
      list[#list + 1] = { name = name, c = c }
    end
  end
  -- zone channel first (they're in our zone for sure), then the newest
  table.sort(list, function(a, b)
    local za, zb = a.c.map and 1 or 0, b.c.map and 1 or 0
    if za ~= zb then return za > zb end
    return a.c.at > b.c.at
  end)
  for _, x in ipairs(list) do
    if #out >= limit then break end
    out[#out + 1] = x.name
    skip[norm(x.name)] = true
  end
end

-- the LayerSwap users of this zone on another layer, hosts and the most recent first
function L:BookNames(m, knownOnly)
  pruneBook()
  local out = {}
  for name, e in pairs(book()) do
    if (not m.map or not e.zone or e.zone == m.map) and not (m.from and layerOf(e) == m.from) and not gone(e)
      and not L.Avoided(name) then
      out[#out + 1] = { name = name, e = e }
    end
  end
  table.sort(out, function(a, b)
    local ha, hb = a.e.host and 1 or 0, b.e.host and 1 or 0
    if ha ~= hb then return ha > hb end
    return (a.e.at or 0) > (b.e.at or 0)
  end)
  local names, skip = {}, {}
  for i, x in ipairs(out) do if i <= 30 then names[#names + 1] = x.name skip[norm(x.name)] = true end end
  L.lastKnown = #names
  -- (players seen in chat channels are not asked: General only holds our own layer)
  return names
end

L.CLASSES = { 1, 2, 3, 4, 5, 7, 8, 9, 11 }
L.zoneFull = {}          -- [map] = the last whole-zone search hit the game's 50-name cap
local who = nil          -- the zone search in flight or just answered: { at, how, muted, done, names }
local whoBlocking = false

local function unmute()
  for _, f in ipairs((who and who.muted) or {}) do pcall(f.RegisterEvent, f, "WHO_LIST_UPDATE") end
  if who then who.muted = nil end
end

-- the zone search: called first thing in a click (see Request). Its answer is kept for the hop.
function L:StartSearch()
  if not (C_FriendList and C_FriendList.SendWho) then return false end
  if who and not who.done and GetTime() - who.at < 10 then return true end
  local okC, map = pcall(C_Map.GetBestMapForUnit, "player")
  local origin = (Enum and Enum.SocialWhoOrigin and Enum.SocialWhoOrigin.Social) or 1
  local w = { at = GetTime() }
  who = w
  whoBlocking = true
  local ok, err = false, nil
  local zone = ns.S(GetRealZoneText) or ""
  -- the zone term in the client's own language (it isn't "z-" on every client)
  local tag = WHO_TAG_ZONE
  if secret(tag) or type(tag) ~= "string" or tag == "" then tag = "z-" end
  local term = zone ~= "" and (tag .. '"' .. zone .. '"') or ""
  if okC and type(map) == "number" and not secret(map) and not L.noMapFilter then
    -- the game lists 50 players per search: each click asks the whole zone, then one class at a time,
    -- so busy zones reach players the first search didn't show (LayerSwap 1.14.25)
    L.whoRound = ((L.whoRound or -1) + 1) % (#L.CLASSES + 1)
    local cls = L.whoRound > 0 and L.CLASSES[L.whoRound] or nil
    ok, err = pcall(C_FriendList.SendWho, term, origin, { classIDs = cls and { cls } or {}, raceIDs = {}, uiMapIDs = { map } })
    w.how = "map " .. map .. (cls and (" class " .. cls) or "")
    w.slice = L.whoRound
    if not ok and not w.blocked then L.noMapFilter = true end
  end
  if not ok and not w.blocked then
    ok, err = pcall(C_FriendList.SendWho, term, origin)
    w.how = zone
    w.slice = 0
  end
  whoBlocking = false
  L.lastWho = { at = time(), how = w.how }
  if w.blocked or not ok then
    L.lastWho.err = w.blocked and "blocked by the game" or tostring(err)
    who = nil
    return false
  end
  -- keep the game's own who lists (Forever's group finder, the Friends window) from popping up
  w.muted = {}
  for _, name in ipairs({ "LFGWhoListFrame", "FriendsFrame" }) do
    local f = _G[name]
    if type(f) == "table" and f.IsEventRegistered and f.IsVisible then
      local okR, reg = pcall(f.IsEventRegistered, f, "WHO_LIST_UPDATE")
      local okV, seen = pcall(f.IsVisible, f)
      if okR and reg == true and okV and seen ~= true and pcall(f.UnregisterEvent, f, "WHO_LIST_UPDATE") then
        w.muted[#w.muted + 1] = f
      end
    end
  end
  if C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, true) end
  C_Timer.After(3, function() if who == w and not w.done then L:WhoResults("late") end end)
  C_Timer.After(8, function()
    if who == w and not w.done then
      local okN, n = pcall(C_FriendList.GetNumWhoResults)
      if okN and type(n) == "number" and not secret(n) and n > 0 then L:WhoResults("timeout") return end
      unmute()
      w.done, w.names = true, {}
      L.lastWho.result = "no answer"
      L:OnSearch()
    end
  end)
  return true
end

ns:On("WHO_LIST_UPDATE", function() L:WhoResults("event") end)

function L:WhoResults(via)
  local w = who
  if not w or w.done then return end
  local okN0, n0 = pcall(C_FriendList.GetNumWhoResults)
  if via == "late" and not (okN0 and type(n0) == "number" and not secret(n0) and n0 > 0) then return end
  w.done = true
  unmute()
  local okN, n = pcall(C_FriendList.GetNumWhoResults)
  if not okN or secret(n) or type(n) ~= "number" then n = 0 end
  local me = norm(ns.S(UnitName, "player") or "")
  -- the search also lists players elsewhere: the ones in our zone first (only they can move us)
  local zoneNames = {}
  local zn = ns.S(GetRealZoneText)
  if type(zn) == "string" and zn ~= "" then zoneNames[zn] = true end
  zn = ns.S(GetZoneText)
  if type(zn) == "string" and zn ~= "" then zoneNames[zn] = true end
  local zm = zoneMap()
  local okM, mi = pcall(C_Map.GetMapInfo, zm or 0)
  if okM and type(mi) == "table" and type(mi.name) == "string" and not secret(mi.name) then zoneNames[mi.name] = true end
  local here, away, seen = {}, {}, {}
  for i = 1, math.min(n, 50) do
    local okI, info = pcall(C_FriendList.GetWhoInfo, i)
    local name = okI and type(info) == "table" and info.fullName
    if type(name) == "string" and not secret(name) and name ~= "" and not seen[name]
      and norm(name) ~= me and not isGangChar(name) then
      seen[name] = true
      local area = info.area
      if type(area) == "string" and not secret(area) and zoneNames[area] then here[#here + 1] = name
      else away[#away + 1] = name end
    end
  end
  local function shuffle(t) for i = #t, 2, -1 do local j = math.random(i) t[i], t[j] = t[j], t[i] end end
  shuffle(here) shuffle(away)
  -- players asked in the last hours who never answered go last (LayerSwap does the same)
  local asked = ns.db.lsAsked or {}
  local function fresh(list)
    local a, b = {}, {}
    for _, nm in ipairs(list) do
      local at = asked[nm]
      if at and time() - at < 6 * 3600 then b[#b + 1] = nm else a[#a + 1] = nm end
    end
    for _, nm in ipairs(b) do a[#a + 1] = nm end
    return a
  end
  local names = fresh(here)
  w.inZone = #names
  for _, nm in ipairs(fresh(away)) do names[#names + 1] = nm end
  w.names = names
  w.full = n >= 50
  local zm2 = zoneMap() or 0
  if w.slice == 0 then L.zoneFull[zm2] = w.full end
  w.more = w.full or ((w.slice or 0) ~= 0 and L.zoneFull[zm2] == true)
  if L.lastWho then
    L.lastWho.result = n .. " found, " .. w.inZone .. " in your zone, " .. #names .. " to ask (" .. via .. ")"
  end
  L:OnSearch()
end

-- the search answered: a hop already waiting for it gets asked now
function L:OnSearch()
  local m = self.mine
  if m and m.mode == "ls" and not m.asked and not m.joinedAt then self:AskLayerSwap(m) end
end

-- ask LayerSwap users: known hosts first, then the players this click's search found
function L:AskLayerSwap(m)
  -- (1.4.42) LayerSwap's rules: never ask in combat or while dead (the gang search may have run out later)
  if inCombat() or ns.S(UnitIsDeadOrGhost, "player") then return end
  m.mode = "ls"
  m.t = ns.Now()
  -- (1.4.71) Forever Layer Hop, VoidNet and AutoLayer users are asked at the same time (LayerNets.lua)
  if L.Nets and not m.netsAsked then m.netsAsked = true L.Nets.Ask(m) end
  seedFromLayerSwap()
  local w = who
  if w and not w.done and GetTime() - w.at < 10 then return end   -- OnSearch comes back here
  local seen, all = {}, {}
  local function add(nm) if not seen[norm(nm)] then seen[norm(nm)] = true all[#all + 1] = nm end end
  for _, nm in ipairs(L:BookNames(m, true)) do add(nm) end
  if w and w.names and GetTime() - w.at < 120 then for _, nm in ipairs(w.names) do add(nm) end end
  if #all == 0 then return self:AskBook(m) end
  self:Whisper(m, all)
end

-- asks the LayerSwap users we already know of in this zone (no search needed)
function L:AskBook(m)
  if not m.pooled then
    -- ask the gang for the LayerSwap users they know in this zone, then whisper
    m.pooled = true
    Comm:Broadcast(Comm:Build("LB", m.id, ns.pid, m.map or ""), 1)
    C_Timer.After(2, function() if L.mine == m and not m.joinedAt then L:AskBook(m) end end)
    return
  end
  local names = self:BookNames(m)
  if #names == 0 then
    ns.Print("Layer hop: " .. (m.noGang and "no gang member is on another layer here, and " or "")
      .. "nobody to ask yet: no LayerSwap users known and nobody seen in chat channels here. Chillan learns them as players nearby ask for hops or chat – try again in a few minutes.")
    return
  end
  self:Whisper(m, names)
end

local ASK_MAX = 49
function L:Whisper(m, names)
  m.asked = true
  m.replies = m.replies or {}
  local line, sent, i = lsLine(m), 0, 1
  ns.db.lsAsked = ns.db.lsAsked or {}
  local nAsked = 0
  for nm, at in pairs(ns.db.lsAsked) do
    if time() - at > 6 * 3600 then ns.db.lsAsked[nm] = nil else nAsked = nAsked + 1 end
  end
  if nAsked > 2000 then ns.db.lsAsked = {} end
  local function burst()
    if L.mine ~= m or m.joinedAt then return end
    -- like LayerSwap: 8 at a time, a second apart, until an invite comes or everyone's asked
    for _ = 1, 8 do
      local name = names[i]
      if not name or (m.sent or 0) >= ASK_MAX then break end
      i = i + 1
      if not m.whispered[norm(name)] and not L.Avoided(name) and not L.SeenNearby(name) then
        local ok, res = pcall(C_ChatInfo.SendAddonMessage, LS_PREFIX, line, "WHISPER", name)
        if ok and not secret(res) and res == 3 then                        -- the game's budget: try again next second
          i = i - 1
          m.throttled = (m.throttled or 0) + 1
          break
        end
        if ok and (res == nil or res == 0 or res == true) then
          sent = sent + 1
          m.whispered[norm(name)] = true
          m.sent = (m.sent or 0) + 1
          ns.db.lsAsked[name] = time()
          L.sentTo[norm(name)] = GetTime()
        end
      end
    end
    ns:Fire("LAYERHOP")
    if names[i] and (m.sent or 0) < ASK_MAX and (m.throttled or 0) < 30 then C_Timer.After(1, burst) return end
    m.doneAt = GetTime()
    -- (1.4.51) LayerSwap 1.14.54 hosts hold their reply up to ~4 s: give them 5 before the re-ask
    C_Timer.After(5.1, function() L:Anyway(m) end)
    -- what came back, so a hop without an invite says why
    local mm = m
    C_Timer.After(12, function()
      if L.mine ~= mm or mm.joinedAt or mm.by then return end
      local same, other, busy, quiet = 0, 0, 0, 0
      for _, r in pairs(mm.replies) do
        if r.same then same = same + 1 elseif r.host and r.layer then other = other + 1
        elseif r.host then busy = busy + 1 else quiet = quiet + 1 end
      end
      local total = same + other + busy + quiet
      for _ in pairs(mm.netReplies or {}) do total = total + 1 end
      -- (1.4.72) one short line, only when it's stuck (the tile shows the counts)
      if other == 0 then
        ns.Print("Layer hop: no host on another layer answered yet – click Swap again to ask more, or try a busier zone.")
      end
    end)
  end
  burst()
end

-- "No player named 'X' is currently playing." for someone we just asked: hide the line (it's ours,
-- not the player's) and forget that name, as LayerSwap does
L.sentTo = {}
local notFoundPattern
local function notPlaying(text)
  if type(text) ~= "string" or secret(text) then return nil end
  if not notFoundPattern then
    local g = ERR_CHAT_PLAYER_NOT_FOUND_S
    if type(g) ~= "string" or secret(g) then return nil end
    notFoundPattern = "^" .. g:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%%%%s", "(.+)") .. "$"
  end
  return text:match(notFoundPattern)
end
local function systemFilter(_, _, text, ...)
  local name = notPlaying(text)
  if not name then return false end
  local key = norm(name)
  local at = L.sentTo[key]
  if not at or GetTime() - at > 60 then return false end
  -- a known host the game can't find right now is left alone 10 min, not forgotten
  local b = ns.db.lsBook
  if b then for nm, e in pairs(b) do if norm(nm) == key and type(e) == "table" then e.gone = time() end end end
  return true
end
-- (1.4.72) the filter API moved to ChatFrameUtil on this client: the old name alone left every
-- "No player named …" in chat
do
  local added = {}
  for _, add in ipairs({ ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter, ChatFrame_AddMessageEventFilter }) do
    if add and not added[add] then added[add] = true pcall(add, "CHAT_MSG_SYSTEM", systemFilter) end
  end
end
L.NotPlaying = notPlaying

-- a LayerSwap user answered our ask: "heard <me>|<their layer>|<zone>|<h or ->"
-- a host that invited from our own layer (or whose group didn't move us) is skipped for 20 s while we
-- still stand on that layer (LayerSwap 1.14.25)
L.avoid = {}
function L.AvoidHost(name, layer, secs)
  if type(name) == "string" and layer then L.avoid[norm(name)] = { at = GetTime(), layer = layer, secs = secs } end
end
function L.Avoided(name)
  local e = L.avoid[norm(name)]
  if not e then return false end
  if GetTime() - e.at > (e.secs or 20) then L.avoid[norm(name)] = nil return false end
  local cur = ns.Layer and ns.Layer:Current()
  return cur ~= nil and cur == e.layer
end

-- Players we can see are on our layer (other layers' players are invisible to us): nameplates,
-- target, mouseover. Remembered until the game moves us; never asked, never accepted for a hop.
L.near = {}
local function notePlayer(unit)
  local okE, there = pcall(UnitExists, unit)
  if not okE or secret(there) or there ~= true then return end
  local okP, isP = pcall(UnitIsPlayer, unit)
  if not okP or secret(isP) or isP ~= true then return end
  local first, surname = UnitName(unit)
  if secret(first) or type(first) ~= "string" or first == "" then return end
  local full = (not secret(surname) and type(surname) == "string" and surname ~= "") and (first .. " " .. surname) or first
  L.near[norm(full)] = GetTime()
end
ns:On("NAME_PLATE_UNIT_ADDED", function(unit) if unit then notePlayer(unit) end end)
ns:On("UPDATE_MOUSEOVER_UNIT", function() notePlayer("mouseover") end)
ns:On("PLAYER_TARGET_CHANGED", function() notePlayer("target") end)
local function clearNear() L.near = {} end
ns:On("SHARD_TRANSFER", clearNear)
ns:On("ZONE_CHANGED_NEW_AREA", clearNear)
function L.SeenNearby(name)
  if type(name) ~= "string" or secret(name) then return false end
  local key = norm(name)
  -- also anyone in view this very moment
  for i = 1, 40 do
    local u = "nameplate" .. i
    local ok, there = pcall(UnitExists, u)
    if ok and there == true then notePlayer(u) end
  end
  notePlayer("target") notePlayer("mouseover")
  local at = L.near[key]
  return at ~= nil and GetTime() - at < 1800
end

local function onHeardReply(sender, layer, zone, host)
  local m = L.mine
  if not m or not m.asked or m.joinedAt then return end
  m.replies = m.replies or {}
  local key = layer and layer:match("^(%d+)")
  local r = { host = host, layer = key, same = (key and m.from and key == m.from) and true or nil }
  m.replies[sender] = r
  ns.db.lsAsked = ns.db.lsAsked or {}
  ns.db.lsAsked[sender] = nil        -- answered: not "asked without an answer"
  r.zone = zone
  -- a host that didn't say its layer may get one more ask without the "not my layer" part (L:Anyway)
  if host and not key then C_Timer.After(5, function() L:Anyway(m) end) end
  ns:Fire("LAYERHOP")
end

-- The re-ask without "not my layer" makes a host that hasn't read its layer invite blind - from our
-- own layer, too. So, like LayerSwap: only once the burst is done, only when no host known to be on
-- another layer has answered (or it had 10 s to invite), only hosts in our zone, never one we can see
-- or one that just didn't move us.
function L:Anyway(m)
  if L.mine ~= m or m.joinedAt or m.by or not m.doneAt then return end
  local since = GetTime() - m.doneAt
  if since < 5 then C_Timer.After(5 - since + 0.1, function() L:Anyway(m) end) return end
  local other = 0
  for _, r in pairs(m.replies or {}) do if r.host and r.layer and not r.same then other = other + 1 end end
  if other > 0 and since < 10 then C_Timer.After(10 - since + 0.1, function() L:Anyway(m) end) return end
  local x, y = mapPos(m.map)
  local line = "inv layer <LS" .. (m.map and (" " .. m.map) or "") .. " r" .. L.LS_RULES
    .. ((m.map and x) and string.format(" %.1f,%.1f", x * 100, y * 100) or "") .. ">"
  for name, r in pairs(m.replies or {}) do
    if r.host and not r.layer and not r.anyway and (not m.map or tostring(r.zone) == tostring(m.map))
      and not L.SeenNearby(name) and not L.Avoided(name) and not L.NotMovedLately(name) then
      r.anyway = true
      L.sentTo[norm(name)] = GetTime()
      pcall(C_ChatInfo.SendAddonMessage, LS_PREFIX, line, "WHISPER", name)
    end
  end
end

-- hosts whose group didn't move us: never re-asked blind for 10 min while we're on that layer
L.notMoved = {}
function L.NotMovedLately(name)
  local e = L.notMoved[norm(name)]
  if not e then return false end
  if GetTime() - e.at > 600 then L.notMoved[norm(name)] = nil return false end
  local cur = ns.Layer and ns.Layer:Current()
  return cur ~= nil and cur == e.layer
end

-- a gang member asks which LayerSwap users we know in their zone: "name|layer|h;..." (fits one message)
Comm:Handle("LB", function(f)
  local id, pid, map = f[1], f[2], tonumber(f[3] or "")
  if not id or not pid or pid == ns.pid then return end
  seedFromLayerSwap()
  pruneBook()
  local parts, len = {}, 0
  local list = {}
  for name, e in pairs(book()) do
    if not map or not e.zone or e.zone == map then list[#list + 1] = { name = name, e = e } end
  end
  table.sort(list, function(a, b)
    local ha, hb = a.e.host and 1 or 0, b.e.host and 1 or 0
    if ha ~= hb then return ha > hb end
    return (a.e.at or 0) > (b.e.at or 0)
  end)
  for _, x in ipairs(list) do
    local item = x.name:gsub("[|;~]", "") .. "|" .. (layerOf(x.e) or "") .. "|" .. (x.e.host and "h" or "")
    if len + #item + 1 > 190 then break end
    parts[#parts + 1] = item
    len = len + #item + 1
  end
  if #parts == 0 then return end
  C_Timer.After(math.random() * 0.8, function()
    Comm:Broadcast(Comm:Build("LR", id, map or "", table.concat(parts, ";")), 1)
  end)
end)

Comm:Handle("LR", function(f)
  local id, map, list = f[1], tonumber(f[2] or ""), f[3]
  if not id or type(list) ~= "string" then return end
  -- everyone keeps what the gang knows; it costs nothing and helps the next hop
  local m, late = L.mine, {}
  for item in list:gmatch("[^;]+") do
    local name, layer, h = item:match("^([^|]+)|([^|]*)|(%a*)$")
    if name then
      learn(name, layer ~= "" and layer or nil, map, h == "h" or nil)
      -- my hop already went out: ask these too, if they're on another layer
      if m and m.id == id and m.asked and not m.joinedAt and not m.whispered[norm(name)]
        and not (m.from and layer == m.from) then late[#late + 1] = name end
    end
  end
  if #late > 0 then L:Whisper(m, late) end
end)

-- hosting for LayerSwap users (opt-in), with LayerSwap's own limits
local hosted, lastHosted = {}, {}

local function hostRoom()
  local t, n = GetTime(), 0
  for i = #hosted, 1, -1 do
    if t - hosted[i] > HOST_WINDOW then table.remove(hosted, i) else n = n + 1 end
  end
  return n < HOST_MAX
end

-- (1.4.71) inviting a stranger from any layer network (LayerSwap, Forever Layer Hop, VoidNet, AutoLayer):
-- the one switch, the same limits. Returns true, or false and why ("off" / "instance" / "busy").
function L.HostStranger(sender, via)
  if not S().layerStrangers then return false, "off" end
  if inInstance() then return false, "instance" end
  if not canHelp() or (L.mine and not L.mine.joinedAt) then return false, "busy" end
  if type(sender) ~= "string" or secret(sender) or sender == "" or isGangChar(sender) then return false, "busy" end
  local key = norm(sender)
  if lastHosted[key] and GetTime() - lastHosted[key] < HOST_PER_PLAYER then return false, "busy" end
  if not hostRoom() then return false, "busy" end
  lastHosted[key] = GetTime()
  hosted[#hosted + 1] = GetTime()
  C_Timer.After(0.5 + math.random(), function()
    if canHelp() then
      ns.Invite(sender)
      L.HostFallback(sender)
      ns.Print("Layer hop: invited " .. ns.ShortName(sender) .. " (" .. (via or "layer addon") .. " user) to your layer.")
      ns.Cnt("layerHosted")
    end
  end)
  return true
end

local function onLayerSwap(text, sender)
  if not S().layerStrangers or type(text) ~= "string" or secret(text) then return end
  if not text:find("inv layer", 1, true) then return end
  local body = text:match("<LS([^<>]*)>")
  if not body then return end
  local mine = ns.Layer and ns.Layer:Current()
  if not mine or not canHelp() or ns.Layer.transferAt and GetTime() - ns.Layer.transferAt < 10 then return end
  local zone = tonumber(body:match("^%s*(%d+)%s") or body:match("^%s*(%d+)%s*$") or "")
  local myMap = zoneMap()
  if not zone or not myMap or zone ~= myMap then return end
  local want = body:match("want%s+(%d+)%-%d+")
  if want and want ~= mine then return end
  for id in body:gmatch("not%s+(%d+)%-%d+") do if id == mine then return end end
  if not L.HostStranger(sender, "LayerSwap") then return end
  -- tell their LayerSwap we heard it (it then leaves our group by itself once moved); the invite follows
  pcall(C_ChatInfo.SendAddonMessage, LS_PREFIX,
    "heard " .. sender .. "|" .. mine .. "-0|" .. tostring(myMap) .. "|h", "WHISPER", sender)
end

ns:On("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
  if prefix ~= LS_PREFIX or secret(sender) or type(sender) ~= "string" then return end
  if secret(text) or type(text) ~= "string" then return end
  -- an ask names the asker's zone and the layer it leaves (= the one it stands on)
  local body = text:find("inv layer", 1, true) and text:match("<LS([^<>]*)>")
  if body then
    learn(sender, body:match("not%s+(%d+)%-%d+"), body:match("^%s*(%d+)"), nil)
  else
    -- a LayerSwap user heard an ask: "heard <asker>|<layer>|<zone>|<h or ->"
    local target, layer, zone, host = text:match("^heard (.-)|([^|]*)|([^|]*)|([^|]*)$")
    if layer then
      -- (1.4.51) "s" (LayerSwap 1.14.54): a host that skips this ask – kept as a host for the next hop
      learn(sender, layer:match("^(%d+)"), zone ~= "-" and zone or nil, host == "h" or host == "s")
      local me = ns.S(UnitName, "player")
      if channel == "WHISPER" and type(me) == "string" and norm(target) == norm(me) then
        onHeardReply(sender, layer ~= "" and layer or nil, zone, host == "h")
      end
    end
  end
  if channel ~= "WHISPER" then return end
  onLayerSwap(text, sender)
end)

---------------------------------------------------------------------------
-- joining, checking it worked, leaving
---------------------------------------------------------------------------
ns:On("PARTY_INVITE_REQUEST", function(inviter, _, _, _, _, sameField)
  L.declineToken = nil
  local m = L.mine
  if not m or m.joinedAt or ns.Now() - m.t > REQUEST_TTL then return end
  if secret(inviter) or type(inviter) ~= "string" then return end
  -- (1.4.71) or, for 45 s after our AutoLayer line went out, any invite (AutoLayer users invite unasked)
  if not (isGangChar(inviter) or m.whispered[norm(inviter)] or (m.anyUntil and GetTime() < m.anyUntil)) then return end
  -- (1.4.41) since build 71037 the invite's 6th field says whether the inviter is on another shard
  -- (false = the same one, measured right in 12 of 12 cases): such an invite can't move us, so it is
  -- declined and the search goes on
  if sameField == false and not secret(sameField) then
    -- (1.4.45) left out for 5 minutes, not 20 s: asked again, it could only invite from our layer again
    L.AvoidHost(inviter, m.from, 300)
    if DeclineGroup then pcall(DeclineGroup) end
    if StaticPopup_Hide then
      pcall(StaticPopup_Hide, "PARTY_INVITE")
      -- the game's own invite window may open just after us: closed once more next frame, unless a
      -- newer invite came in meanwhile (that one is yours to see)
      local token = {}
      L.declineToken = token
      C_Timer.After(0, function() if L.declineToken == token then pcall(StaticPopup_Hide, "PARTY_INVITE") end end)
    end
    ns.Print("Layer hop: " .. ns.ShortName(inviter) .. " is on your layer, so that invite was declined. Still looking for another host.")
    return
  end
  -- its own reply said it stands on our layer: joining would move nobody, so don't accept it
  local said
  for nm, r in pairs(m.replies or {}) do if norm(nm) == norm(inviter) and r.same then said = true end end
  if L.SeenNearby(inviter) then
    said = true
  end
  if said then
    L.AvoidHost(inviter, m.from)
    ns.Print("Layer hop: " .. ns.ShortName(inviter) .. " is on your layer (" .. (L.SeenNearby(inviter) and "you can see them" or "their addon said so")
      .. "), so that invite wouldn't move you – decline it and wait for another.")
    return
  end
  -- (1.4.42) a gang host's invite is accepted for you; a LayerSwap host's is yours to accept (LayerSwap's
  -- own rule: the invite is the player's) – Chillan carries on once you have joined
  if not isGangChar(inviter) then
    m.pendingHost = inviter
    local via = (m.netOf and m.netOf[norm(inviter)]) or (m.whispered[norm(inviter)] and "LayerSwap") or "AutoLayer"
    ns.Print("Layer hop: " .. ns.ShortName(inviter) .. " (" .. via .. ") invited you – click Accept to move.")
    ns:Fire("LAYERHOP")
    return
  end
  if AcceptGroup then AcceptGroup() end
  if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
  L.Joined(m, inviter, true)
end)

-- after joining a host's group: watch for the move, leave after LEAVE_AFTER s
function L.Joined(m, inviter, confirm)
  m.host = inviter
  m.joinedAt = GetTime()
  m.pendingHost = nil
  ns:Fire("LAYERHOP")
  local myM = m
  -- Forever may ask to confirm the move ("shard transfer"): confirmed for gang hops, which we asked for
  if confirm then
    C_Timer.After(0.5, function()
      local prompt = _G.ShardTransferImminentFrame
      if L.mine == myM and prompt and prompt:IsShown() then pcall(prompt.Click, prompt, "LeftButton", true) end
    end)
  end
  C_Timer.After(3, function() L:Verify(myM) end)
  -- (1.4.13) the group is left 4 s after the join, moved or not (LayerSwap 1.14.40): a move comes
  -- 0.6-1.1 s after the join
  C_Timer.After(LEAVE_AFTER + 0.2, function()
    if L.mine ~= myM then return end
    if myM.moved or myM.transfer then
      if not myM.moved then done(myM, ns.Layer and ns.Layer:Current()) end
    elseif ns.Layer and ns.Layer.Private() then
      notMoved(myM)
    end
  end)
end

-- you accepted a LayerSwap host's invite yourself
ns:On("GROUP_JOINED", function()
  local m = L.mine
  if m and m.pendingHost and not m.joinedAt and ns.Now() - m.t <= REQUEST_TTL + 60 then L.Joined(m, m.pendingHost, false) end
end)

done = function(m, newKey)
  if L.mine ~= m or m.moved then return end
  m.moved = true
  ns.Cnt("layerHops")
  L.CountMove()
  ns:Fire("LAYERHOP")
  ns.Print("Layer hop: |cff9BE08Ayou're on " .. label(newKey) .. " now|r" .. (m.from and (" (was " .. label(m.from) .. ")") or "")
    .. ". Leaving the group in " .. LEAVE_AFTER .. " s – the layer stays.")
  if ns.Sound then pcall(ns.Sound, "chat") end
  -- 4 s after the join (not after we noticed the move)
  local wait = math.max(0.5, (m.joinedAt or GetTime()) + LEAVE_AFTER - GetTime())
  C_Timer.After(wait, function()
    if L.mine == m then L.mine = nil end
    local members = GetNumGroupMembers and GetNumGroupMembers() or 0
    leaveHop()
    ns:Fire("LAYERHOP")
  end)
end

-- the game moved us (or a new layer shows in the creatures around us)
ns:Listen("LAYER", function(key, old)
  local m = L.mine
  if m and m.joinedAt and key and key ~= m.from then done(m, key) end
end)
ns:Listen("LAYER_TRANSFER", function()
  local m = L.mine
  if m and m.joinedAt then m.transfer = GetTime() end
end)

-- After joining a host: did we move? "Moved" as soon as the creatures (or the game) say so. "Not moved"
-- only on evidence: 3 different creatures read after the join still on our old layer, and no shard
-- transfer, at least VERIFY_AFTER seconds in (LayerSwap 1.14.25 judges the same way). Otherwise keep
-- looking every 2 s for up to a minute.
local VERIFY_GIVE_UP = 60
local function oldLayerEvidence(m)
  m.oldSeen = m.oldSeen or {}
  local function look(unit)
    local okE, there = pcall(UnitExists, unit)
    if not okE or secret(there) or there ~= true then return end
    local okP, pc = pcall(UnitPlayerControlled, unit)
    if okP and not secret(pc) and pc == true then return end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or secret(guid) then return end
    local key = ns.Layer and ns.Layer.KeyOf(guid)
    if key and key == m.from then m.oldSeen[guid] = true end
  end
  for i = 1, 40 do look("nameplate" .. i) end
  look("target") look("mouseover")
  local n = 0
  for _ in pairs(m.oldSeen) do n = n + 1 end
  return n
end

notMoved = function(m)
  if L.mine ~= m or m.moved then return end
  local host = m.host and ns.ShortName(m.host) or "The host"
  if ns.Layer and ns.Layer.Private() then
    -- with private layer numbers we can't tell "same layer" from the game's hourly limit
    L.NoteRefusal()
    m.host = m.host
    ns.Print("Layer hop: the game didn't move you – " .. host .. " may be on your layer, or you've hit the game's limit of about 10 hops an hour. Left the group.")
    if m.host then L.AvoidHost(m.host, m.from) L.notMoved[norm(m.host)] = { at = GetTime(), layer = m.from } end
    L.mine = nil
    leaveHop()
    ns:Fire("LAYERHOP")
    return
  end
  if m.host then L.AvoidHost(m.host, m.from) L.notMoved[norm(m.host)] = { at = GetTime(), layer = m.from } end
  ns.Print("Layer hop: " .. host .. " was on your layer, so nothing changed. Left the group – click Layer hop to try again.")
  L.mine = nil
  local members = GetNumGroupMembers and GetNumGroupMembers() or 0
  leaveHop()
  ns:Fire("LAYERHOP")
end

function L:Verify(m)
  if self.mine ~= m or m.moved then return end
  local since = GetTime() - (m.joinedAt or GetTime())
  if m.transfer then
    if not m.from then done(m, ns.Layer and ns.Layer:Current()) return end
    -- moved, but the creatures haven't shown the new layer yet: give it a little longer
    if GetTime() - m.transfer > 10 then done(m, ns.Layer and ns.Layer:Current()) return end
  elseif m.from and oldLayerEvidence(m) >= 3 and since >= VERIFY_AFTER then
    notMoved(m)
    return
  end
  if since >= VERIFY_GIVE_UP then
    ns.Print("Layer hop: couldn't tell whether you moved – no creatures in view to read. Left the group; mouse over an NPC or two to see your layer.")
    self.mine = nil
    local members = GetNumGroupMembers and GetNumGroupMembers() or 0
    leaveHop()
    ns:Fire("LAYERHOP")
    return
  end
  C_Timer.After(2, function() L:Verify(m) end)
end

-- what the Layer hop tile shows: big line, small line, colour
-- (1.4.17) layer numbers are private since build 71037, so the box no longer names a layer. The big text
-- says what the click does; the small text says how many moves the hour has left, how long to wait, or
-- when we last moved. A real (non-private) layer number still shows if the game gives one.
function L:TileState()
  local cur = ns.Layer and not (ns.Layer.Private and ns.Layer.Private()) and ns.Layer:CurrentLabel() or nil
  local big = cur or "Swap"   -- (1.4.68) short: the box is narrow ("Swap layer" got cut to "…")
  local m = self.mine
  if not m then
    local wait, left = L.CapWait()
    if wait then return big, "Wait " .. mmss(wait), "E0C068" end
    local since = L.SinceMove()
    if since and since < 600 then
      return big, "Moved " .. (since < 60 and "just now" or (math.floor(since / 60) .. "m ago")), "9BE08A"
    end
    left = left or L.CAP
    return big, "layer · " .. left .. " left"
  end
  if m.moved then return big, "Moved!", "9BE08A" end
  if m.joinedAt then return big, "Checking the move…", "E0C068" end
  if m.by then
    local p = ns:GetPerson(m.by)
    return big, "Invite from " .. ((p and ns:PersonFirst(p)) or "the gang"), "E0C068"
  end
  if m.mode == "ls" then
    if m.sent or m.netSent then
      local n = 0
      for _ in pairs(m.replies or {}) do n = n + 1 end
      for _ in pairs(m.netReplies or {}) do n = n + 1 end
      return big, "Asked " .. ((m.sent or 0) + (m.netSent or 0)) .. (n > 0 and (", " .. n .. " answered") or ""), "E0C068"
    end
    return big, "Searching zone…", "E0C068"
  end
  return big, "Asking the gang…", "E0C068"
end

---------------------------------------------------------------------------
-- settings by slash: /chill layer host on|off, /chill layer strangers on|off
---------------------------------------------------------------------------
function L:Slash(rest)
  rest = (rest or ""):lower()
  local what, onoff = rest:match("^(%a+)%s*(%a*)$")
  if what == "host" or what == "strangers" then
    local key = what == "host" and "layerHost" or "layerStrangers"
    if onoff == "on" then S()[key] = true elseif onoff == "off" then S()[key] = false else S()[key] = not S()[key] end
    ns.Print((what == "host" and "Auto-invite gang members for layer hops: " or "Host layer swaps for other layer addons' users (strangers): ")
      .. (S()[key] and "|cff9BE08Aon|r" or "off"))
    return
  end
  if what == "test" then testWhoLater("typed /chill layer test") return end
  if what == "status" or what == "info" then
    local cur = ns.Layer and ns.Layer:Current()
    ns.Print("Your layer: " .. (cur and label(cur) or "unknown – target or mouse over an NPC or two")
      .. ". Gang auto-invite: " .. (S().layerHost ~= false and "on" or "off")
      .. ". Hosting for strangers: " .. (S().layerStrangers and "on" or "off") .. ".")
    local why = L.PauseWhy()
    if why then ns.Print("Hosting paused right now: " .. why .. ".") end
    local nc = 0
    for _, c in pairs(chatters) do if time() - c.at < 3600 then nc = nc + 1 end end
    ns.Print("LayerSwap users known: " .. pruneBook() .. ". Players seen in chat channels (last hour): " .. nc .. ".")
    if L.Nets then ns.Print(L.Nets.Status()) end
    local w = L.lastWho
    if w then
      ns.Print("Last player search: " .. date("%H:%M:%S", w.at) .. " · " .. tostring(w.how)
        .. " · " .. (w.err and ("refused: " .. w.err) or (w.result or "waiting")))
    end
    return
  end
  self:Request()
end

---------------------------------------------------------------------------
-- popup for helpers who invite by hand (auto-invite off, or an older asker)
---------------------------------------------------------------------------
function L:ShowAsk(id)
  local r = self.open[id]
  if not r then return end
  if not self.frame then
    local f = UI.OverlayPanel and UI.OverlayPanel(UIParent, C.window, C.activeLine, true) or UI.Panel(UIParent, C.window, C.activeLine, true)
    f:SetSize(340, 96)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    UI.Movable(f, "layerhop", function(fr) fr:SetPoint("TOP", UIParent, "TOP", 0, -150) end)
    f.title = UI.Text(f, 13, "semi", C.text)
    f.title:SetPoint("TOPLEFT", 14, -14)
    f.title:SetPoint("RIGHT", -14, 0)
    f.sub = UI.Text(f, 11, nil, C.text2)
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -5)
    f.sub:SetPoint("RIGHT", -14, 0)
    f.yes = UI.Button(f, 150, 28, "Invite", "primary", function() L:Help(f.id) end)
    f.yes:SetPoint("BOTTOMLEFT", 14, 12)
    f.no = UI.Button(f, 150, 28, "Not now", "ghost", function() f:Hide() end)
    f.no:SetPoint("BOTTOMRIGHT", -14, 12)
    self.frame = f
  end
  local f = self.frame
  local p = ns:GetPerson(r.pid)
  f.id = id
  local who = (p and ns:ShortWho(p)) or ns.Colorize(ns.ShortName(r.target), C.accent)
  f.title:SetText(who .. ns.Colorize(" wants a layer-hop invite", C.text))
  f.sub:SetText("They join your group and your layer.")
  f:Show()
  if ns.Sound then pcall(ns.Sound, "mention") end
  C_Timer.After(30, function() if f.id == id and f:IsShown() then f:Hide() end end)
end

-- the game blocked a call of ours during a player search: say so in /chill layer status
-- the game blocks our zone search (the event comes during the call)
ns:On("ADDON_ACTION_BLOCKED", function(addon)
  if addon == ADDON and whoBlocking and who then who.blocked = true end
end)

---------------------------------------------------------------------------
-- test: does the game let Chillan search for players at all? (/chillwho, /chill layer test)
-- The search is the very first thing the command does.
---------------------------------------------------------------------------
local probe
local function testWho(how)
  local okC, map = pcall(C_Map.GetBestMapForUnit, "player")
  local origin = (Enum and Enum.SocialWhoOrigin and Enum.SocialWhoOrigin.Social) or 1
  probe = { at = GetTime(), how = how, blocked = false, results = nil }
  whoBlocking = true
  local ok, err = pcall(C_FriendList.SendWho, "", origin,
    { classIDs = {}, raceIDs = {}, uiMapIDs = { (okC and type(map) == "number") and map or 0 } })
  whoBlocking = false
  probe.err = (not ok) and tostring(err) or nil
  local p = probe
  C_Timer.After(4, function()
    local okN, n = pcall(C_FriendList.GetNumWhoResults)
    p.results = okN and n or "?"
    ns.Print("Player search test (" .. p.how .. "): " .. (p.blocked and "|cffF2777ABLOCKED by the game|r"
      or p.err and ("error: " .. p.err) or ("|cff9BE08Aok|r – " .. tostring(p.results) .. " results")) .. ".")
  end)
end
ns:On("ADDON_ACTION_BLOCKED", function(addon)
  if addon == ADDON and probe and GetTime() - probe.at < 3 then probe.blocked = true end
end)
SLASH_CHILLANWHO1 = "/chillwho"
SlashCmdList.CHILLANWHO = function() testWho("typed /chillwho") end
L.TestWho = testWho
