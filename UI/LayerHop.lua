-- Chillan? – layer hop: change layer by joining the group of someone on another layer.
-- In WoW Forever you move to the leader's layer when you join their group (Blizzard's "shard
-- transfer"), and on live Forever the new layer stays after you leave again.
--
-- 1) The gang: every Chillan knows its own layer (Layer.lua) and shares it with its status.
--    A hop asks the gang; a friend in the same zone on another layer invites by itself
--    (setting "layerHost"), the asker accepts, checks that it moved, and leaves 30 s later.
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
local REQUEST_TTL = 90
local VERIFY_AFTER = 15     -- no move this long after joining: the host stood on our layer
local LEAVE_AFTER = 30      -- after a confirmed move, leave the host's group
local HOST_MAX, HOST_WINDOW, HOST_PER_PLAYER = 6, 600, 60
local ZONE_MAP = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3

local function secret(v) return ns.isSecret and ns.isSecret(v) end
local function S() return ns.db.settings end

local function inGroup() return IsInGroup and IsInGroup() and true or false end
local function inCombat()
  if InCombatLockdown and InCombatLockdown() then return true end
  return ns.S(UnitAffectingCombat, "player") and true or false
end
local function inInstance() return (ns.S(IsInInstance)) and true or false end

local function canHelp()
  return not inGroup() and not inInstance() and not inCombat() and not ns.S(UnitIsDeadOrGhost, "player")
end

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

local function norm(name)
  if type(name) ~= "string" then return "" end
  return (ns.ShortName(name) or name):lower():gsub("[%s%-]", "")
end

local function isGangChar(name)
  local short = norm(name)
  if short == "" then return false end
  for pid, p in pairs(ns.db.people or {}) do
    if pid ~= ns.pid then
      for key, c in pairs(p.chars or {}) do
        if norm((c and c.name) or key) == short then return true end
      end
    end
  end
  return false
end

local function leave()
  local fn = (C_PartyInfo and C_PartyInfo.LeaveParty) or LeaveParty
  if fn then pcall(fn) end
end

local function label(key) return (ns.Layer and ns.Layer.Label(key)) or "a new layer" end

-- gang members who could move me: online, same zone, known layer that isn't mine
function L:GangHosts()
  local mine, map = ns.Layer and ns.Layer:Current(), zoneMap()
  local myZone = ns.Tracker:Me().live and ns.Tracker:Me().live.zone
  local out = {}
  for pid, p in pairs(ns.db.people or {}) do
    local lv = p.live
    if pid ~= ns.pid and p.main and ns:IsOnline(p) and lv and lv.layer and not lv.inInst
      and lv.layer ~= mine and lv.zone and lv.zone == myZone then
      out[#out + 1] = p
    end
  end
  return out, mine, map
end

---------------------------------------------------------------------------
-- asking
---------------------------------------------------------------------------
function L:Request()
  if inGroup() then
    ns.Print("Leave your group first – you change layer by joining someone's group.")
    return
  end
  if inInstance() then ns.Print("You can't change layer inside a dungeon.") return end
  if inCombat() then ns.Print("Not in combat.") return end
  local m = self.mine
  -- a second click while the gang couldn't help: ask the LayerSwap users in the zone
  if m and not m.joinedAt and ns.Now() - m.t < REQUEST_TTL then
    if m.mode == "gang" and ns.Now() - m.t >= 8 then
      self:AskLayerSwap(m)
    else
      ns.Print("Already asking for a layer hop…")
    end
    return
  end
  local hosts, from, map = self:GangHosts()
  local id = Comm:NewId()
  m = { id = id, t = ns.Now(), from = from, map = map, mode = "gang", whispered = {} }
  self.mine = m
  -- the player search must be the first thing this click does: the game allows it only straight
  -- from a click, and anything sent before it in the same click gets it blocked
  if #hosts == 0 then self:AskLayerSwap(m) end
  C_Timer.After(0.1, function()
    Comm:Broadcast(Comm:Build("LQ", id, ns.pid, Comm:MyFull(), ns.Now(), from or "", map or ""), 1)
  end)
  if #hosts > 0 then
    local names = {}
    for i, p in ipairs(hosts) do if i <= 3 then names[#names + 1] = ns:ShortWho(p) end end
    ns.Print("Layer hop: asking the gang (" .. table.concat(names, ", ") .. (#hosts > 3 and " …" or "")
      .. " can move you" .. (from and (" off " .. label(from)) or "") .. ").")
  else
    -- nobody in the gang stands on another layer here: ask LayerSwap users right away (this click)
    ns.Print("Layer hop: nobody in the gang is on another layer in this zone – asking LayerSwap users here too.")
  end
  ns:Fire("LAYERHOP")
  C_Timer.After(12, function()
    if self.mine == m and not m.by and not m.joinedAt and m.mode == "gang" then
      ns.Print("Layer hop: no gang invite yet. |cffE0C068Click again|r to also ask LayerSwap users in the zone.")
    end
  end)
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
  if S().layerHost ~= false and mine then
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
  end
end)

function L:Help(id, auto)
  local r = self.open[id]
  if not r then return end
  self.open[id] = nil
  Comm:Broadcast(Comm:Build("LK", id, ns.pid), 1)
  ns.Invite(r.target)
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

local function lsLine(m)
  local parts = { "<LS" }
  if m.map then parts[#parts + 1] = tostring(m.map) end
  if m.from then parts[#parts + 1] = "not " .. m.from .. "-0" end
  local x, y = mapPos(m.map)
  if m.map and x then parts[#parts + 1] = string.format("%.1f,%.1f", x * 100, y * 100) end
  return "inv layer " .. table.concat(parts, " ") .. ">"
end

-- LayerSwap users we know of, learned without any search: every LayerSwap user who asks for a hop
-- nearby whispers the players of the zone (us too) and names the layer it leaves; every host that
-- answers our ask says its layer. ns.db.lsBook[name] = { at, layer, zone, host }
local BOOK_TTL, BOOK_MAX = 3 * 3600, 400
local function book()
  ns.db.lsBook = ns.db.lsBook or {}
  return ns.db.lsBook
end
local function learn(name, layer, zone, host)
  if type(name) ~= "string" or name == "" or secret(name) or isGangChar(name) then return end
  local b = book()
  local e = b[name] or {}
  e.at = time()
  if layer and layer ~= "" then e.layer = layer end
  if zone then e.zone = tonumber(zone) or e.zone end
  if host ~= nil then e.host = host or nil end
  b[name] = e
end
L.Learn = learn
local function pruneBook()
  local b, n, t = book(), 0, time()
  for name, e in pairs(b) do
    if type(e) ~= "table" or t - (e.at or 0) > BOOK_TTL then b[name] = nil else n = n + 1 end
  end
  return n
end
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

-- the LayerSwap users of this zone on another layer, hosts and the most recent first
function L:BookNames(m)
  pruneBook()
  local out = {}
  for name, e in pairs(book()) do
    if (not m.map or not e.zone or e.zone == m.map) and not (m.from and e.layer == m.from) then
      out[#out + 1] = { name = name, e = e }
    end
  end
  table.sort(out, function(a, b)
    local ha, hb = a.e.host and 1 or 0, b.e.host and 1 or 0
    if ha ~= hb then return ha > hb end
    return (a.e.at or 0) > (b.e.at or 0)
  end)
  local names = {}
  for i, x in ipairs(out) do if i <= 30 then names[#names + 1] = x.name end end
  return names
end

local who = nil   -- { m, at, muted }
local whoBlocking = false

local function unmute()
  for _, f in ipairs((who and who.muted) or {}) do pcall(f.RegisterEvent, f, "WHO_LIST_UPDATE") end
  if who then who.muted = nil end
end

-- one /who of the zone (only works from a click), then hidden whispers to who it found
function L:AskLayerSwap(m)
  m.mode = "ls"
  m.t = ns.Now()
  seedFromLayerSwap()
  local blockedAt = ns.db.whoBlockedAt
  if not (C_FriendList and C_FriendList.SendWho) or (blockedAt and time() - blockedAt < 7 * 86400) then
    return self:AskBook(m)
  end
  local zone = ns.S(GetRealZoneText) or ""
  local text = zone ~= "" and ('z-"' .. zone .. '"') or ""
  who = { m = m, at = GetTime() }
  -- keep the game's own who lists (Forever's group finder, the Friends window) out of our search
  who.muted = {}
  for _, name in ipairs({ "LFGWhoListFrame", "FriendsFrame" }) do
    local f = _G[name]
    if type(f) == "table" and f.IsEventRegistered and f.IsVisible then
      local okR, reg = pcall(f.IsEventRegistered, f, "WHO_LIST_UPDATE")
      local okV, seen = pcall(f.IsVisible, f)
      if okR and reg == true and okV and seen ~= true and pcall(f.UnregisterEvent, f, "WHO_LIST_UPDATE") then
        who.muted[#who.muted + 1] = f
      end
    end
  end
  local origin = (Enum and Enum.SocialWhoOrigin and Enum.SocialWhoOrigin.Social) or 1
  local ok, err = false, nil
  whoBlocking, who.blocked = true, false
  if m.map then
    ok, err = pcall(C_FriendList.SendWho, text, origin, { classIDs = {}, raceIDs = {}, uiMapIDs = { m.map } })
    who.how = "map " .. tostring(m.map)
  end
  if not ok and not who.blocked then
    ok, err = pcall(C_FriendList.SendWho, text, origin)
    who.how = text
  end
  whoBlocking = false
  if who.blocked then
    -- this game won't let Chillan search for players: remember it, and use the users we know of
    ns.db.whoBlockedAt = time()
    L.lastWho = { at = time(), how = who.how, err = "blocked by the game – using known LayerSwap users" }
    unmute()
    who = nil
    return self:AskBook(m)
  end
  if ok and C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, true) end
  L.lastWho = { at = time(), how = who.how, err = (not ok) and tostring(err) or nil }
  if not ok then unmute() who = nil ns.Print("Layer hop: the game refused the player search (" .. tostring(err) .. ").") return end
  -- the answer can come late, or without the event: look at what the game holds after a few seconds
  C_Timer.After(4, function() if who and who.m == m and not who.done then L:WhoResults("late") end end)
  C_Timer.After(10, function()
    if who and who.m == m and not who.done then
      local okN, n = pcall(C_FriendList.GetNumWhoResults)
      if okN and type(n) == "number" and not secret(n) and n > 0 then L:WhoResults("timeout") return end
      unmute()
      who = nil
      L.lastWho.result = "no answer"
      ns.Print("Layer hop: the player search got no answer (the game allows one search every few seconds) – click Layer hop again in a moment.")
    end
  end)
end

ns:On("WHO_LIST_UPDATE", function() L:WhoResults("event") end)

function L:WhoResults(via)
  if not who or who.done then return end
  local okN0, n0 = pcall(C_FriendList.GetNumWhoResults)
  if via == "late" and not (okN0 and type(n0) == "number" and not secret(n0) and n0 > 0) then return end
  who.done = true
  local m = who.m
  unmute()
  local okN, n = pcall(C_FriendList.GetNumWhoResults)
  if not okN or secret(n) or type(n) ~= "number" then n = 0 end
  local me = norm(ns.S(UnitName, "player") or "")
  local names = {}
  for i = 1, math.min(n, 50) do
    local okI, info = pcall(C_FriendList.GetWhoInfo, i)
    local name = okI and type(info) == "table" and info.fullName
    if type(name) == "string" and not secret(name) and name ~= "" and norm(name) ~= me and not isGangChar(name) then
      names[#names + 1] = name
    end
  end
  who = nil
  if L.lastWho then L.lastWho.result = n .. " found, " .. #names .. " to ask (" .. via .. ")" end
  -- shuffle so the same few players aren't always asked first
  for i = #names, 2, -1 do local j = math.random(i) names[i], names[j] = names[j], names[i] end
  -- known LayerSwap hosts first
  local seen, all = {}, {}
  for _, nm in ipairs(L:BookNames(m)) do if not seen[norm(nm)] then seen[norm(nm)] = true all[#all + 1] = nm end end
  for _, nm in ipairs(names) do if not seen[norm(nm)] then seen[norm(nm)] = true all[#all + 1] = nm end end
  if #all == 0 then ns.Print("Layer hop: the search found nobody else in the zone to ask.") return end
  L:Whisper(m, all)
end

-- asks the LayerSwap users we already know of in this zone (no search needed)
function L:AskBook(m)
  local names = self:BookNames(m)
  if #names == 0 then
    ns.Print("Layer hop: no LayerSwap users known in this zone yet. Chillan learns them as players nearby ask for hops – try again in a few minutes.")
    return
  end
  self:Whisper(m, names)
end

function L:Whisper(m, names)
  local line, sent, i = lsLine(m), 0, 1
  local first = true
  local function burst()
    if L.mine ~= m or m.joinedAt then return end
    -- the game takes about 10 addon messages at once, then about one a second
    for _ = 1, (first and 8 or 1) do
      local name = names[i]
      if not name or i > 30 then break end
      i = i + 1
      local ok, res = pcall(C_ChatInfo.SendAddonMessage, LS_PREFIX, line, "WHISPER", name)
      if ok and (res == nil or res == 0 or res == true) then
        sent = sent + 1
        m.whispered[norm(name)] = true
      end
    end
    first = false
    if names[i] and i <= 30 then C_Timer.After(1, burst)
    else ns.Print("Layer hop: asked " .. sent .. " player" .. (sent == 1 and "" or "s") .. " here – any LayerSwap host on another layer will invite you.") end
  end
  burst()
end

-- hosting for LayerSwap users (opt-in), with LayerSwap's own limits
local hosted, lastHosted = {}, {}

local function hostRoom()
  local t, n = GetTime(), 0
  for i = #hosted, 1, -1 do
    if t - hosted[i] > HOST_WINDOW then table.remove(hosted, i) else n = n + 1 end
  end
  return n < HOST_MAX
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
  if isGangChar(sender) then return end
  local key = norm(sender)
  if lastHosted[key] and GetTime() - lastHosted[key] < HOST_PER_PLAYER then return end
  if not hostRoom() then return end
  lastHosted[key] = GetTime()
  hosted[#hosted + 1] = GetTime()
  -- tell their LayerSwap we heard it (it then leaves our group by itself once moved)
  pcall(C_ChatInfo.SendAddonMessage, LS_PREFIX,
    "heard " .. sender .. "|" .. mine .. "-0|" .. tostring(myMap) .. "|h", "WHISPER", sender)
  C_Timer.After(0.5 + math.random(), function()
    if canHelp() then
      ns.Invite(sender)
      ns.Print("Layer hop: invited " .. ns.ShortName(sender) .. " (LayerSwap user) to your layer.")
    end
  end)
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
    local _, layer, zone, host = text:match("^heard (.-)|([^|]*)|([^|]*)|([^|]*)$")
    if layer then learn(sender, layer:match("^(%d+)"), zone ~= "-" and zone or nil, host == "h") end
  end
  if channel ~= "WHISPER" then return end
  onLayerSwap(text, sender)
end)

---------------------------------------------------------------------------
-- joining, checking it worked, leaving
---------------------------------------------------------------------------
ns:On("PARTY_INVITE_REQUEST", function(inviter)
  local m = L.mine
  if not m or m.joinedAt or ns.Now() - m.t > REQUEST_TTL then return end
  if secret(inviter) or type(inviter) ~= "string" then return end
  if not (isGangChar(inviter) or m.whispered[norm(inviter)]) then return end
  if AcceptGroup then AcceptGroup() end
  if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
  m.host = inviter
  m.joinedAt = GetTime()
  local myM = m
  -- Forever may ask to confirm the move ("shard transfer"): confirm it, we asked for this
  C_Timer.After(0.5, function()
    local prompt = _G.ShardTransferImminentFrame
    if L.mine == myM and prompt and prompt:IsShown() then pcall(prompt.Click, prompt, "LeftButton", true) end
  end)
  C_Timer.After(VERIFY_AFTER, function() L:Verify(myM) end)
end)

local function done(m, newKey)
  if L.mine ~= m or m.moved then return end
  m.moved = true
  ns.Print("Layer hop: |cff9BE08Ayou're on " .. label(newKey) .. " now|r" .. (m.from and (" (was " .. label(m.from) .. ")") or "")
    .. ". Leaving the group in " .. LEAVE_AFTER .. " s – the layer stays.")
  if ns.Sound then pcall(ns.Sound, "chat") end
  C_Timer.After(LEAVE_AFTER, function()
    if L.mine == m then L.mine = nil end
    local members = GetNumGroupMembers and GetNumGroupMembers() or 0
    if inGroup() and members <= 2 and not inCombat() and not inInstance() then leave() end
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

function L:Verify(m)
  if self.mine ~= m or m.moved then return end
  if m.transfer and not m.from then done(m, ns.Layer and ns.Layer:Current()) return end
  if m.transfer then
    -- moved, but the creatures haven't shown the new layer yet: give it a little longer
    C_Timer.After(10, function()
      if self.mine == m and not m.moved then done(m, ns.Layer and ns.Layer:Current()) end
    end)
    return
  end
  local host = m.host and ns.ShortName(m.host) or "The host"
  ns.Print("Layer hop: " .. host .. " was on your layer, so nothing changed. Left the group – click Layer hop to try again.")
  self.mine = nil
  local members = GetNumGroupMembers and GetNumGroupMembers() or 0
  if inGroup() and members <= 2 and not inCombat() then leave() end
  ns:Fire("LAYERHOP")
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
    ns.Print((what == "host" and "Auto-invite gang members for layer hops: " or "Host layer hops for LayerSwap users (strangers): ")
      .. (S()[key] and "|cff9BE08Aon|r" or "off"))
    return
  end
  if what == "status" or what == "info" then
    local cur = ns.Layer and ns.Layer:Current()
    ns.Print("Your layer: " .. (cur and label(cur) or "unknown – target or mouse over an NPC or two")
      .. ". Gang auto-invite: " .. (S().layerHost ~= false and "on" or "off")
      .. ". LayerSwap hosting: " .. (S().layerStrangers and "on" or "off") .. ".")
    ns.Print("LayerSwap users known nearby: " .. pruneBook() .. ".")
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
-- the game blocks our player search (the event can come during the call or just after it):
-- remember it for a week and ask the LayerSwap users we know of instead
ns:On("ADDON_ACTION_BLOCKED", function(addon)
  if addon ~= ADDON or not who then return end
  if whoBlocking then who.blocked = true return end
  if GetTime() - (who.at or 0) > 3 or who.done then return end
  local m = who.m
  who.done = true
  ns.db.whoBlockedAt = time()
  L.lastWho = { at = time(), how = who.how, err = "blocked by the game – using known LayerSwap users" }
  unmute()
  who = nil
  if L.mine == m and not m.joinedAt then L:AskBook(m) end
end)
