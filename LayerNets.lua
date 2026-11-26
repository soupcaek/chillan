-- Chillan? – more layer networks behind the same Swap button.
-- Besides the gang and LayerSwap users (UI/LayerHop.lua), a swap also asks the users of three other
-- layer addons, each in its own message format:
--   Forever Layer Hop  hidden whispers "FLHNET2" (LQ/LO/LR offers, DR direct asks, LW/LI/LN answers)
--   VoidNet            hidden whispers "VLAYER" (Q asks, A answers, HR/HA invites), found through an
--                      hourly hidden channel whose name and password every VoidNet user works out alike
--   AutoLayer          an "inv layer" line in AutoLayer's "layer" chat channels, which its users read
-- Hosting for them is the same opt-in switch as for LayerSwap users ("layerStrangers") with the same
-- limits (L.HostStranger). Chillan's own code, written from the message formats (the way Layer
-- Anarchy talks to all of them).
local ADDON, ns = ...
local L = ns.LayerHop
if not L then return end

local N = {}
L.Nets = N
local secret, S = ns.U.Secret, ns.U.Settings
local norm, isGangChar = ns.U.NormName, ns.U.IsGangChar

local function safe(v) if v == nil or secret(v) then return nil end return v end
local function now() return GetTime() end
local function myName() return safe(GetUnitName and GetUnitName("player", false)) or safe(UnitName("player")) end
local function isMe(name) local me = myName() return me ~= nil and type(name) == "string" and norm(name) == norm(me) end
local function zone() return L.ZoneMap and L.ZoneMap() or nil end
local function rawMap()
  local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
  if ok and not secret(id) and type(id) == "number" and id > 0 then return id end
end
local function inInstance() return (ns.S(IsInInstance)) and true or false end
local function locked()
  if InCombatLockdown and InCombatLockdown() then return true end
  if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
    local ok, v = pcall(C_ChatInfo.InChatMessagingLockdown)
    if ok and v == true then return true end
  end
  return false
end
-- may Chillan invite a stranger right now (for the "can host" flags the networks share)
local function canHost() return S().layerStrangers and L.PauseWhy() == nil and not (L.mine and not L.mine.joinedAt) end

-- a short per-sender gate: true at most once per `gap` seconds for that key
local gates = {}
local function gate(what, key, gap)
  local k = what .. ":" .. key
  local t = now()
  if gates[k] and t - gates[k] < gap then return false end
  gates[k] = t
  return true
end

-- my "layer key" for the networks: a number that stays the same until I change layer (layer numbers are
-- private, so it can't be the real one)
local token, tokenEpoch, epoch = nil, -1, 0
local function layerKey()
  if tokenEpoch ~= epoch or not token then token, tokenEpoch = math.random(100000, 999999), epoch end
  return tostring(token)
end
local function moved() epoch = epoch + 1 end
ns:On("SHARD_TRANSFER", moved)
ns:Listen("LAYER", moved)

-- whispers out, paced like the other addons: 8 at once, then one every 1.1 s
local queue, tokens, filled, pumping = {}, 8, 0, false
local pump
local function refill() pumping = false pump() end
pump = function()
  local t = now()
  tokens = math.min(8, tokens + (t - filled) / 1.1)
  filled = t
  while tokens >= 1 and queue[1] do
    local q = table.remove(queue, 1)
    if not q.exp or q.exp > t then
      local ok, res = pcall(C_ChatInfo.SendAddonMessage, q.prefix, q.text, q.kind or "WHISPER", q.to)
      if ok and not secret(res) and (res == 3 or res == 4) then   -- the game's budget, or chat locked
        table.insert(queue, 1, q)
        tokens = 0
        break
      end
      tokens = tokens - 1
    end
  end
  if queue[1] and not pumping then pumping = true C_Timer.After(1.1, refill) end
end
local function send(prefix, text, to, urgent, life, kind)
  if #text > 255 then return end
  if #queue >= 60 then if not urgent then return end table.remove(queue) end
  local q = { prefix = prefix, text = text, to = to, kind = kind, exp = life and (now() + life) or nil }
  if urgent then
    local i = 1
    while queue[i] and queue[i].urgent do i = i + 1 end
    q.urgent = true
    table.insert(queue, i, q)
  else
    queue[#queue + 1] = q
  end
  pump()
end
N.Queue = queue

-- the hop we're on: who we asked (their invites are expected) and what came back
local function expect(m, name, net)
  if not m or type(name) ~= "string" then return end
  m.whispered = m.whispered or {}
  m.whispered[norm(name)] = true
  m.netOf = m.netOf or {}
  if not m.netOf[norm(name)] then
    m.netOf[norm(name)] = net
    m.netSent = (m.netSent or 0) + 1
  end
end
local function answered(m, name, host)
  if not m then return end
  m.netReplies = m.netReplies or {}
  m.netReplies[norm(name)] = host and "host" or "no"
  ns:Fire("LAYERHOP")
end
local function hopOpen(m) return m ~= nil and m == L.mine and not m.joinedAt and not m.moved end

---------------------------------------------------------------------------
-- hidden chat channels (VoidNet, AutoLayer): joined quietly, kept off the chat windows
---------------------------------------------------------------------------
local function channelId(name)
  local ok, id = pcall(GetChannelName, name)
  if ok and type(id) == "number" and id > 0 then return id end
end
local function channelCount()
  local ok, list = pcall(function() return { GetChannelList() } end)
  if not ok or type(list) ~= "table" then return 0 end
  return math.floor(#list / 3)
end
local function hideChannel(name)
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local f = _G["ChatFrame" .. i]
    if f then
      if ChatFrame_RemoveChannel then pcall(ChatFrame_RemoveChannel, f, name) end
      if f.RemoveChannel then pcall(f.RemoveChannel, f, name) end
    end
  end
end
N.channels = {}   -- name -> owner ("voidnet" / "autolayer")
local function join(owner, name, pw)
  if channelId(name) then hideChannel(name) N.channels[name] = owner return true end
  if locked() then return false end
  -- leave room for the player's own channels (the game allows 10)
  if channelCount() >= 8 then return false end
  local fn = JoinTemporaryChannel or JoinChannelByName
  if not fn or not pcall(fn, name, pw) then return false end
  N.channels[name] = owner
  C_Timer.After(2, function()
    local id = channelId(name)
    if not id then return end
    hideChannel(name)
    -- the first slots belong to General, Trade & co.: a hidden channel that got one waits and rejoins
    if id <= 4 and not N.relocated then
      N.relocated = true
      pcall(LeaveChannelByName, name)
      C_Timer.After(30, function() join(owner, name, pw) end)
    end
  end)
  return true
end
local function leaveOwned(owner, keep)
  for name, by in pairs(N.channels) do
    if by == owner and not (keep and keep[name]) then
      if channelId(name) then pcall(LeaveChannelByName, name) end
      N.channels[name] = nil
    end
  end
end

---------------------------------------------------------------------------
-- Forever Layer Hop
---------------------------------------------------------------------------
local FLH = { prefix = "FLHNET2", wire = "0.1.3", build = "0.2.1" }
N.FLH = FLH
local peers = {}   -- key -> { n = name, t, m = map, k = layer key, h = 1 host / 0 }
FLH.peers = peers
local flhLang = (function()
  local l = (GetLocale and GetLocale() or "enUS"):sub(1, 2)
  local known = { en = 1, pt = 1, es = 1, de = 1, fr = 1, ko = 1, zh = 1, ja = 1, ru = 1 }
  return known[l] and l or "other"
end)()
local function flhRealm()
  local r = safe(GetNormalizedRealmName and GetNormalizedRealmName()) or safe(GetRealmName()) or ""
  r = r:gsub("[|:%s]", "")
  return r ~= "" and r or "?"
end
local function flhTail() return "LANG=" .. flhLang .. "|POP=0|BUILD=" .. FLH.build end
local function flhCid()
  local g = safe(UnitGUID("player"))
  return g and g:gsub("[|:]", "_")
end
local function flhSend(text, kind, to)
  local cid = flhCid()
  if cid and #text + 5 + #cid <= 255 then text = text .. "|CID=" .. cid end
  send(FLH.prefix, text, to, true, 15, kind)
end
local function flhSplit(s)
  local out, pos = {}, 1
  while true do
    local at = s:find("[|:]", pos)
    if not at then out[#out + 1] = s:sub(pos) return out end
    out[#out + 1] = s:sub(pos, at - 1)
    pos = at + 1
  end
end
local function isNum(v) return type(v) == "string" and v:find("^%d+$") ~= nil end
local function isKey(v) return isNum(v) and tonumber(v) > 0 end
local function hostFlag() return canHost() and 1 or 0 end
local function myMap() return rawMap() or 0 end
local function zoneOf(map)
  map = tonumber(map)
  if not map or map <= 0 then return nil end
  local id = map
  for _ = 1, 8 do
    local ok, info = pcall(C_Map.GetMapInfo, id)
    if not ok or type(info) ~= "table" then return map end
    if info.mapType == 3 then return id end
    if (info.mapType or 0) < 3 then return map end
    id = info.parentMapID
    if not id or id <= 0 then return map end
  end
  return map
end
local function hereMap(map)
  map = tonumber(map)
  if not map then return false end
  if map == rawMap() then return true end
  local z = zoneOf(map)
  return z ~= nil and z == zone()
end
local function see(key, name, map, layer, host)
  local p = peers[key] or {}
  peers[key] = p
  p.n, p.t = name, now()
  map = tonumber(map)
  if map and map > 0 then p.m = map end
  if isKey(layer) then p.k = layer end
  if host ~= nil then p.h = tonumber(host) == 1 and 1 or 0 end
end
local function hiText()
  return ("HI|%d|%s|%d|%s|%s|%s"):format(myMap(), layerKey(), hostFlag(), FLH.build, flhRealm(), flhTail())
end
local lastGuildHI = -1e9
local function guildHI()
  if now() - lastGuildHI < 120 or not canHost() or not IsInGuild() then return end
  lastGuildHI = now()
  flhSend(hiText(), "GUILD")
end

-- hosting: an FLH user asks me
local REASON = { off = "hosting disabled", instance = "inside an instance" }
local function flhHost(id, sender)
  local ok, why = L.HostStranger(sender, "Forever Layer Hop")
  if not ok then return flhSend(("LN|%s|%s"):format(id, REASON[why] or "busy"), "WHISPER", sender) end
  flhSend("LW|" .. id, "WHISPER", sender)
  flhSend("LI|" .. id, "WHISPER", sender)
end
local offersMade, lastOfferAt = {}, -1e9

-- asking: offers first, then known hosts directly, then a round of "who can host?"
local ask   -- { m, zone, tried, offers, lqTo, lqId, req, tries, waiting, gen }
local flhNext
local function flhLive(st) return st and st == ask and hopOpen(st.m) end
local function arm(st, secs, fn)
  st.gen = st.gen + 1
  local g = st.gen
  C_Timer.After(secs, function() if flhLive(st) and st.gen == g then fn(st) end end)
end
local function drop(st) st.req = nil st.gen = st.gen + 1 flhNext(st) end
local function candidates(st, hostsOnly)
  local list, t = {}, now()
  for key, p in pairs(peers) do
    if p.n and p.m and p.k and t - p.t <= 180 and not st.tried[key] and (not hostsOnly or p.h == 1)
      and zoneOf(p.m) == st.zone and not isGangChar(p.n) and not L.Avoided(p.n) then
      list[#list + 1] = key
    end
  end
  table.sort(list, function(a, b) return peers[a].t > peers[b].t end)
  return list
end
local function tryHost(st, key, o)
  local p = peers[key]
  st.tried[key], st.tries = true, st.tries + 1
  local id
  if o then
    id = st.lqId
    flhSend(("LR|%s|%d|%s|%s"):format(id, o.m, o.k, FLH.wire), "WHISPER", p.n)
  else
    id = tostring(math.random(10000, 99999))
    flhSend(("DR|%s|%d|%s|%s"):format(id, p.m, p.k, layerKey()), "WHISPER", p.n)
  end
  st.req = { id = id, key = key, name = p.n }
  expect(st.m, p.n, "Forever Layer Hop")
  arm(st, 5, drop)
end
local function bestOffer(st)
  local best, bo, t = nil, nil, now()
  for key, o in pairs(st.offers) do
    if not st.tried[key] and peers[key] and t - o.t < 25
      and (not bo or o.size < bo.size or (o.size == bo.size and o.load < bo.load)) then
      best, bo = key, o
    end
  end
  return best, bo
end
flhNext = function(st)
  if not flhLive(st) or st.req or st.waiting or st.tries >= 3 then return end
  local best, bo = bestOffer(st)
  if best then return tryHost(st, best, bo) end
  local hosts = candidates(st, true)
  if hosts[1] then return tryHost(st, hosts[1]) end
  if st.lqId then return end
  local list = candidates(st, false)
  if not list[1] then return end
  st.lqId = tostring(math.random(10000, 99999))
  local k = layerKey()
  for i = 1, math.min(#list, 8) do
    local p = peers[list[i]]
    st.lqTo[list[i]] = true
    flhSend(("LQ|%s|%d|*|%s|%s|LANG=%s"):format(st.lqId, p.m, k, k, flhLang), "WHISPER", p.n)
  end
  st.waiting = true
  arm(st, 2.5, function(s) s.waiting = false flhNext(s) end)
end
local function poke() if ask then flhNext(ask) end end
function FLH.Ask(m)
  local z = zone()
  if not z then return 0 end
  ask = { m = m, zone = z, gen = 0, tries = 0, tried = {}, offers = {}, lqTo = {} }
  flhNext(ask)
  return #candidates(ask, false)
end

local H = {}
function H.WP(f, ct, key, sender)
  if ct ~= "WHISPER" or not isNum(f[2]) then return end
  see(key, sender, f[5], f[6], f[7])
  if gate("flh wp", key, 2) then
    flhSend(("WR|%s|%s|%s|%d|%s|%d|%s"):format(f[2], flhRealm(), FLH.wire, myMap(), layerKey(), hostFlag(), flhTail()), "WHISPER", sender)
  end
  poke()
end
function H.WR(f, ct, key, sender) if ct == "WHISPER" then see(key, sender, f[5], f[6], f[7]) poke() end end
function H.HI(f, ct, key, sender)
  see(key, sender, f[2], f[3], f[4])
  if ct == "GUILD" then guildHI() end
  poke()
end
function H.GQ(_, ct, key)
  if (ct == "PARTY" or ct == "RAID" or ct == "INSTANCE_CHAT") and gate("flh gq", key, 3) then flhSend(hiText(), ct) end
end
function H.CQ(f, ct, key, sender)
  if (ct ~= "WHISPER" and ct ~= "CHANNEL") or not isNum(f[2]) then return end
  see(key, sender, f[3], f[4], f[5])
  if (ct == "WHISPER" or hereMap(f[3])) and gate("flh cq", key, 10) then
    flhSend(("CA|%s|%d|%s|%d|%s|%s|%s"):format(f[2], myMap(), layerKey(), hostFlag(), FLH.wire, flhRealm(), flhTail()), "WHISPER", sender)
  end
  poke()
end
function H.CA(f, ct, key, sender) if ct == "WHISPER" then see(key, sender, f[3], f[4], f[5]) poke() end end
function H.DISCOVER(f, ct, key, sender)
  see(key, sender, f[2], f[3])
  if hereMap(f[2]) and gate("flh discover", key, 20) then
    local k = layerKey()
    flhSend(("P|%d|%s|%s|%s|%s"):format(myMap(), k, FLH.wire, k, flhTail()), "WHISPER", sender)
  end
  if ct == "GUILD" then guildHI() end
end
function H.LQ(f, ct, key, sender)
  if (ct ~= "WHISPER" and ct ~= "CHANNEL") or not isNum(f[2]) then return end
  see(key, sender, f[3], f[5])
  local k = layerKey()
  if not hereMap(f[3]) or (f[4] ~= "*" and f[4] ~= k) or f[5] == k then return end
  if not canHost() then return end
  if now() - lastOfferAt > 30 then wipe(offersMade) end
  lastOfferAt = now()
  offersMade[key] = { id = f[2], t = now() }
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  flhSend(("LO|%s|%d|%s|%d|%d|ACT=0|LANG=%s"):format(f[2], myMap(), k, n, 0, flhLang), "WHISPER", sender)
end
function H.LR(f, _, key, sender)
  local id = f[2]
  if not isNum(id) then return end
  local o = offersMade[key]
  offersMade[key] = nil
  if not o or o.id ~= id or now() - o.t > 30 then return flhSend(("LN|%s|host unavailable"):format(id), "WHISPER", sender) end
  if not hereMap(f[3]) or f[4] ~= layerKey() then return flhSend(("LN|%s|layer changed"):format(id), "WHISPER", sender) end
  flhHost(id, sender)
end
local function direct(f, ct, key, sender, gap)
  local id = f[2]
  if ct ~= "WHISPER" or not isNum(id) or not isKey(f[4]) then return end
  if gap and not gate("flh dr", key, gap) then return end
  if not hereMap(f[3]) or f[4] ~= layerKey() then return flhSend(("LN|%s|layer changed"):format(id), "WHISPER", sender) end
  flhHost(id, sender)
end
function H.DR(f, ct, key, sender) direct(f, ct, key, sender, 3) end
function H.ZI(f, ct, key, sender) direct(f, ct, key, sender) end
function H.LO(f, _, key, sender)
  local st = ask
  if not flhLive(st) or f[2] ~= st.lqId or not st.lqTo[key] then return end
  local map = tonumber(f[3])
  if not map or not isKey(f[4]) then return end
  see(key, sender, map, f[4], 1)
  st.offers[key] = { m = map, k = f[4], size = tonumber(f[5]) or 0, load = tonumber(f[6]) or 0, t = now() }
  answered(st.m, sender, true)
  flhNext(st)
end
local function onHop(cmd, f, key)
  local st = ask
  local r = flhLive(st) and st.req
  if not r or r.done or f[2] ~= r.id or key ~= r.key then return end
  if cmd == "LW" or cmd == "HQ" then
    if r.ack then return end
    r.ack = true
    arm(st, 25, drop)
  elseif cmd == "LI" then
    r.done = true
    answered(st.m, r.name, true)
    local leader = f[3] == "S" and f[4] ~= "" and f[4]
    if leader then expect(st.m, leader, "Forever Layer Hop") end
    arm(st, 25, drop)
  else
    if cmd == "LN" and f[3] == "layer changed" and peers[key] then peers[key].k = nil end
    answered(st.m, r.name, false)
    drop(st)
  end
end
for _, cmd in ipairs({ "LW", "HQ", "LI", "LD", "LA", "LN" }) do H[cmd] = function(f, _, key) onHop(cmd, f, key) end end
FLH.H = H

function FLH.OnAddon(text, ct, sender)
  local handler = H[text:match("^[^|:]+") or ""]
  if handler then handler(flhSplit(text), ct, norm(sender), sender) end
end

---------------------------------------------------------------------------
-- VoidNet
---------------------------------------------------------------------------
local VN = { q = "VLAYER", guard = "VOIDNET" }
N.VN = VN
local ALPHA, MOD = "bcdfghjkmnpqrstvwxz23456789", 2147483629
local function mix(h, n) return (h * 31 + n) % MOD end
local function vcode(seed, len)
  local h, out = seed, {}
  for i = 1, len do
    h = mix(mix(h, i), 7919)
    local c = h % #ALPHA + 1
    out[i] = ALPHA:sub(c, c)
  end
  return table.concat(out)
end
-- the hour's channel: the same name and password for every VoidNet user of a faction
function VN.Derive(slot, hour, side)
  local salt = 52817 + slot
  local s = mix(mix(mix(salt, hour), salt % 97), side)
  return "Vn" .. vcode(s, 6), vcode(mix(s, 104729), 8)
end
local function side()
  local f = safe(UnitFactionGroup("player"))
  return (f == "Horde" and 1) or (f == "Alliance" and 2) or 3
end
local function hourNow() return math.floor(GetServerTime() / 3600) end
local function pair() return layerKey() .. "-0" end
local function canon(p) return p and p:match("^(%d+)%-%d+$") end
local function validName(n) return type(n) == "string" and #n >= 1 and #n <= 48 and not n:find("[|:]") end
VN.slot, VN.slotHour = 0, nil
VN.roster = { names = {}, keys = {}, at = 0 }
VN.heard, VN.census, VN.seenQ, VN.inbound, VN.votes = {}, {}, {}, {}, {}

function VN.Join()
  if not VN.wanted then return end
  local hour = hourNow()
  if VN.slotHour ~= hour then VN.slot, VN.slotHour = 0, hour end
  local name, pw = VN.Derive(VN.slot, hour, side())
  if VN.chan and VN.chan.name == name and channelId(name) then return end
  if join("voidnet", name, pw) then
    VN.chan = { name = name, hour = hour, slot = VN.slot }
    leaveOwned("voidnet", { [name] = true })
  else
    VN.waiting = true
  end
end
-- a wrong password or a ban on the hour's channel: the next slot (the others move there too)
ns:On("CHAT_MSG_CHANNEL_NOTICE", function(kind, _, _, _, _, _, _, _, base)
  kind, base = safe(kind), safe(base)
  if not (VN.chan and base and base:lower() == VN.chan.name:lower()) then return end
  if (kind == "WRONG_PASSWORD" or kind == "BANNED") and VN.slot < 3 then
    VN.slot = VN.slot + 1
    VN.chan = nil
    VN.Join()
  end
end)
local function scheduleHour()
  local wait = 3600 - GetServerTime() % 3600 + math.random(20, 40)
  C_Timer.After(wait, function()
    if VN.chan and VN.chan.hour ~= hourNow() then
      wipe(VN.seenQ) wipe(VN.inbound) wipe(VN.votes)
      VN.Join()
    end
    scheduleHour()
  end)
end
N.ScheduleHour = scheduleHour

local function displayIndex(name)
  local wanted = name:lower()
  for i = 1, (GetNumDisplayChannels and GetNumDisplayChannels() or 0) do
    local cname, header, _, _, count, active = GetChannelDisplayInfo(i)
    if not header and type(cname) == "string" and cname:lower() == wanted then return i, count, active end
  end
end
local function readNow(idx, count)
  count = tonumber(count) or 0
  local names, keys = {}, {}
  for j = 1, math.min(count, 300) do
    local ok, name = pcall(C_ChatInfo.GetChannelRosterInfo, idx, j)
    name = ok and safe(name) or nil
    if type(name) == "string" and name ~= "" and not keys[norm(name)] then
      keys[norm(name)] = name
      names[#names + 1] = name
    end
  end
  if #names == 0 then return false end
  VN.roster = { names = names, keys = keys, at = now() }
  return true
end
-- the channel's member list: needs the channel picked in the game's channel list, put back afterwards
function VN.ReadRoster(done)
  if not VN.chan or (ChannelFrame and ChannelFrame:IsShown()) or VN.reading then return done(false) end
  local idx, count = displayIndex(VN.chan.name)
  if not idx then return done(false) end
  local okP, prev = pcall(GetSelectedDisplayChannel)
  VN.reading = true
  local finished = false
  local function finish(ok)
    if finished then return end
    finished, VN.reading = true, nil
    if okP and prev and prev ~= idx and not (ChannelFrame and ChannelFrame:IsShown()) then pcall(SetSelectedDisplayChannel, prev) end
    done(ok)
  end
  VN.onRoster = function(i, c) if i == idx and readNow(idx, c) then finish(true) end end
  pcall(SetSelectedDisplayChannel, idx)
  if readNow(idx, count) then return finish(true) end
  C_Timer.After(8, function() finish(readNow(idx, select(5, GetChannelDisplayInfo(idx)))) end)
end
ns:On("CHANNEL_ROSTER_UPDATE", function(i, c)
  if VN.onRoster and VN.reading then VN.onRoster(safe(i), safe(c)) end
end)

-- asking: up to 10 at a time ("can anyone here host?"), hosts that answer get "invite me"
local vask
local function vLive(st) return st and st == vask and hopOpen(st.m) end
local function vTry()
  local st = vask
  if not vLive(st) or st.try or IsInGroup() then return end
  while st.queue[1] do
    local key = table.remove(st.queue, 1)
    local c = VN.census[key]
    if c and not st.tried[key] and c.zone == st.zone and now() - c.t <= 300 then
      local try = { key = key, name = c.name, nonce = tostring(math.random(100000, 999999)), at = now() }
      st.tried[key], st.try, st.nonces[try.nonce] = true, try, key
      expect(st.m, c.name, "VoidNet")
      send(VN.q, ("HR:1:%d:%s:%s"):format(st.zone, c.pair, try.nonce), c.name, true, 12)
      C_Timer.After(12, function()
        if not vLive(st) or st.try ~= try then return end
        if try.ok and now() - try.at < 30 then
          C_Timer.After(try.at + 30 - now(), function() if vLive(st) and st.try == try then st.try = nil vTry() end end)
          return
        end
        if not try.ok then VN.census[key] = nil end
        st.try = nil
        vTry()
      end)
      return
    end
  end
end
local function vPick(n, exclude)
  local me, out, used = norm(myName() or ""), {}, {}
  local function ok(name)
    local k = norm(name)
    if k == me or used[k] or exclude[k] or isGangChar(name) or not gate("vn ask", k, 60) then return false end
    used[k] = true
    return true
  end
  local hosts, strangers = {}, {}
  for k, h in pairs(VN.heard) do if now() - h.t < 3600 and ok(h.name) then hosts[#hosts + 1] = h.name end end
  for _, name in ipairs(VN.roster.names) do if ok(name) then strangers[#strangers + 1] = name end end
  for i = #strangers, 2, -1 do local j = math.random(i) strangers[i], strangers[j] = strangers[j], strangers[i] end
  for i = 1, math.min(3, #hosts) do out[#out + 1] = hosts[i] end
  for _, name in ipairs(strangers) do if #out >= n then break end out[#out + 1] = name end
  for i = 4, #hosts do if #out >= n then break end out[#out + 1] = hosts[i] end
  return out
end
local function vWave(st)
  if not vLive(st) then return 0 end
  local me = myName()
  if not validName(me) then return 0 end
  local targets = vPick(10, st.asked)
  st.lastQ = now()
  local text = ("Q:1:1:%d:%s:%s"):format(st.zone, st.nonce, me)
  for _, name in ipairs(targets) do
    st.asked[norm(name)] = true
    expect(st.m, name, "VoidNet")
    send(VN.q, text, name, false, 15)
  end
  return #targets
end
function VN.Ask(m)
  local z = zone()
  if not z then return end
  VN.wanted = true
  VN.Join()
  local st = { m = m, zone = z, nonce = tostring(math.random(100000, 999999)), queue = {}, tried = {}, nonces = {}, asked = {} }
  vask = st
  for key, c in pairs(VN.census) do if c.zone == z and now() - c.t <= 300 then st.queue[#st.queue + 1] = key end end
  vTry()
  vWave(st)
  if now() - VN.roster.at > 300 then
    -- a channel joined just now needs a moment before its list can be read
    C_Timer.After(VN.chan and 0.5 or 3, function()
      if vLive(st) then VN.ReadRoster(function(ok) if ok then vWave(st) end end) end
    end)
  end
  -- a second wave a little later, while nobody has invited
  C_Timer.After(15, function() if vLive(st) and not st.try then vWave(st) end end)
end

local VH = {}
function VH.Q(text, sender, key)
  local ttl, z, nonce, asker = text:match("^Q:1:(%d+):(%d+):(%d+):(.+)$")
  ttl, z = tonumber(ttl), tonumber(z)
  if not ttl or ttl > 1 or not validName(asker) then return end
  local ak = norm(asker)
  if isMe(asker) then return end
  if ttl == 1 and ak ~= key then return end
  if ttl == 0 and not (VN.roster.keys[ak] or VN.heard[ak]) then return end
  if VN.seenQ[nonce] == ak then return end
  VN.seenQ[nonce] = ak
  -- pass it on to a few others in the channel (the network's way to reach everyone)
  if ttl == 1 and #queue < 20 and #VN.roster.names > 0 then
    local relayed, tries = 0, 0
    local relayText = ("Q:1:0:%d:%s:%s"):format(z, nonce, asker)
    while relayed < 4 and tries < 12 do
      tries = tries + 1
      local name = VN.roster.names[math.random(#VN.roster.names)]
      local k = norm(name)
      if k ~= key and k ~= ak and not isMe(name) then relayed = relayed + 1 send(VN.q, relayText, name, false, 6) end
    end
  end
  if inInstance() or z ~= zone() then return end
  if not gate("vn answer", ak, 60) then return end
  send(VN.q, ("A:1:%d:%s:%d"):format(z, pair(), canHost() and 1 or 0), asker, true, 6)
end
function VH.A(text, sender, key)
  local z, p, h = text:match("^A:1:(%d+):(%d+%-%d+):([01])$")
  z = tonumber(z)
  local st = vask
  if not z or #p > 20 or h ~= "1" or not vLive(st) then return end
  if z ~= st.zone or not st.lastQ or now() - st.lastQ > 60 then return end
  VN.census[key] = { name = sender, zone = z, pair = p, t = now() }
  answered(st.m, sender, true)
  if not st.tried[key] then st.queue[#st.queue + 1] = key end
  vTry()
end
function VH.HR(text, sender)
  local z, p, nonce = text:match("^HR:1:(%d+):(%d+%-%d+):(%d+)$")
  z = tonumber(z)
  if not z or #p > 20 then return end
  local no
  if canon(p) ~= canon(pair()) then no = "layer"
  elseif z ~= zone() then no = "layer"
  else
    local ok, why = L.HostStranger(sender, "VoidNet")
    if not ok then no = why == "off" and "off" or "busy" end
  end
  if no then return send(VN.q, ("HA:1:%s:no:%s"):format(nonce, no), sender, true, 10) end
  send(VN.q, ("HA:1:%s:ok"):format(nonce), sender, true, 10)
  send(VN.q, ("HP:1:%s:%s"):format(nonce, pair()), sender, true, 10)
end
function VH.HA(text, sender, key)
  local nonce, rest = text:match("^HA:1:(%d+):(.+)$")
  local st = vask
  if not nonce or not st or st.nonces[nonce] ~= key then return end
  local try = st.try and st.try.nonce == nonce and st.try or nil
  if rest == "ok" then
    answered(st.m, sender, true)
    if try then try.ok = true end
  elseif rest:sub(1, 2) == "no" then
    answered(st.m, sender, false)
    VN.census[key] = nil
    if try then st.try = nil vTry() end
  end
end
VN.H = VH

local function vGuard(text, sender, key)
  if text:find("^O:%d+$") then
    if gate("vn ping", key, 10) then send(VN.guard, "o", sender, true) end
    return
  end
  -- two members voting for the next slot: the hour's channel moved
  local slot, hour = text:match("^M:(%d+):(%d+)$")
  slot, hour = tonumber(slot), tonumber(hour)
  if not slot or not VN.chan or hour ~= VN.chan.hour or slot <= VN.chan.slot or slot > 3 then return end
  if not VN.roster.keys[key] then return end
  local v = VN.votes[slot]
  if not v or v.hour ~= hour then v = { hour = hour, n = 0, by = {} } VN.votes[slot] = v end
  if v.by[key] then return end
  v.by[key], v.n = true, v.n + 1
  if v.n >= 2 then VN.slot = slot VN.chan = nil VN.Join() end
end

function VN.OnAddon(prefix, text, ct, sender)
  if ct ~= "WHISPER" or #text > 255 then return end
  local key = norm(sender)
  local h = VN.heard[key] or {}
  VN.heard[key] = h
  h.name, h.t = sender, now()
  if prefix == VN.guard then return vGuard(text, sender, key) end
  local r = VN.inbound[key]
  if not r or now() - r.t > 60 then r = { t = now(), n = 0 } VN.inbound[key] = r end
  r.n = r.n + 1
  if r.n > 20 then return end
  local handler = VH[text:match("^(%u%u?):1:") or ""]
  if handler then handler(text, sender, key) end
end

---------------------------------------------------------------------------
-- AutoLayer: its users read an "inv layer" line in a "layer" chat channel
---------------------------------------------------------------------------
local AL = {}
N.AL = AL
local function adlerHex(s)
  local a, b = 1, 0
  for i = 1, #s do
    a = (a + s:byte(i)) % 65521
    b = (b + a) % 65521
  end
  return ("%04x%04x"):format(b, a)
end
AL.Adler = adlerHex
function AL.Names()
  local t = C_DateAndTime.GetCurrentCalendarTime()
  local realm = safe(GetRealmName()) or ""
  local d, mo, y = t.monthDay, t.month, t.year
  local names = {}
  for _, day in ipairs({ ("%02d-%02d-%04d"):format(d, mo, y), ("%04d-%02d-%02d"):format(y, mo, d), ("%02d-%02d-%04d"):format(mo, d, y) }) do
    names[#names + 1] = "layer" .. adlerHex(realm .. "-" .. day)
  end
  names[#names + 1] = "layer"
  return names
end
-- the zone written as 4 letters (AAAA = 0): "<ALZBCDE>"
function AL.Encode(v)
  if not v or v < 1 or v > 456975 then return nil end
  local t = {}
  for i = 4, 1, -1 do t[i] = string.char(65 + v % 26) v = math.floor(v / 26) end
  return table.concat(t)
end
function AL.Decode(code)
  local v = 0
  for i = 1, 4 do
    local d = code:byte(i) - 97
    if d < 0 or d >= 26 then return nil end
    v = v * 26 + d
  end
  return v >= 1 and v or nil
end
local SEG = { [947] = "AZ", [1945] = "OL", [2521] = "ZI", [2665] = "ZI", [2524] = "DI", [908] = "AZ",
  [1941] = "OL", [1942] = "OL", [1943] = "OL", [1947] = "OL", [1950] = "OL", [1954] = "OL", [1957] = "OL" }
local function segment()
  local id = rawMap()
  for _ = 1, 10 do
    if not id or id <= 0 then return nil end
    if SEG[id] then return SEG[id] end
    local ok, info = pcall(C_Map.GetMapInfo, id)
    id = ok and type(info) == "table" and info.parentMapID or nil
  end
end
function AL.Line()
  local seg = segment()
  if not seg then return "inv layer " end
  local code = AL.Encode(zone())
  return "<" .. seg .. "> " .. (code and ("<ALZ" .. code .. "> ") or "") .. "inv layer "
end
local LAYER_WORD = "%f[%a]layers?%f[%A]"
function AL.Parse(text)
  local s = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower():gsub("^%s+", "")
  local z
  for _ = 1, 2 do
    local tok, rest = s:match("^<(%w+)>%s*(.*)$")
    if not tok then break end
    local code = tok:match("^alz(%a%a%a%a)$")
    if code then z = AL.Decode(code) end
    s = rest
  end
  if s:find("%d") or not s:find(LAYER_WORD) then return nil end
  return z, s
end
function AL.Join()
  AL.names = AL.Names()
  AL.lists = {}
  for _, n in ipairs(AL.names) do AL.lists[n:lower()] = true end
  local keep = {}
  for _, n in ipairs(AL.names) do if join("autolayer", n) then keep[n] = true end end
  leaveOwned("autolayer", keep)
end
function AL.Channel()
  for _, n in ipairs(AL.names or {}) do local id = channelId(n) if id then return id end end
end
local alSeen = {}
ns:On("CHAT_MSG_CHANNEL", function(text, sender, _, _, _, _, _, _, base)
  base = safe(base)
  if not (base and AL.lists and AL.lists[base:lower()]) then return end
  sender, text = safe(sender), safe(text)
  if type(sender) ~= "string" or type(text) ~= "string" then return end
  if isMe(sender) then
    -- my own ask went out: the AutoLayer user who invites in the next 45 s is expected
    if L.mine and not L.mine.joinedAt then L.mine.anyUntil = now() + 45 ns:Fire("LAYERHOP") end
    return
  end
  if not text:find("<[Aa][Ll][Zz]%a%a%a%a>") then return end
  local key = norm(sender)
  local seen = alSeen[key]
  if seen and seen.text == text and now() - seen.t < 3 then return end
  alSeen[key] = { text = text, t = now() }
  local z, body = AL.Parse(text)
  if not body or not z then return end
  if z ~= zone() and z ~= rawMap() then return end
  L.HostStranger(sender, "AutoLayer")
end)
-- puts the AutoLayer ask in the chat box: Enter sends it (only a key press may write in a channel)
function AL.Prompt()
  local id = AL.Channel()
  if not id or locked() then return false end
  local line = AL.Line()
  local box
  if ChatFrameUtil and ChatFrameUtil.OpenChat then
    local active = ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow()
    if active and active.GetText and active:GetText() ~= "" then return false end
    pcall(ChatFrameUtil.OpenChat, line, DEFAULT_CHAT_FRAME)
    box = ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow()
  elseif ChatFrame_OpenChat then
    pcall(ChatFrame_OpenChat, line, DEFAULT_CHAT_FRAME)
    box = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
  end
  if not box then return false end
  pcall(box.SetAttribute, box, "chatType", "CHANNEL")
  pcall(box.SetAttribute, box, "channelTarget", id)
  if box.UpdateHeader then pcall(box.UpdateHeader, box) elseif ChatEdit_UpdateHeader then pcall(ChatEdit_UpdateHeader, box) end
  AL.promptAt = now()
  return true
end

---------------------------------------------------------------------------
-- wiring
---------------------------------------------------------------------------
for _, p in ipairs({ FLH.prefix, VN.q, VN.guard }) do
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, p) end
end
ns:On("CHAT_MSG_ADDON", function(prefix, text, ct, sender)
  if prefix ~= FLH.prefix and prefix ~= VN.q and prefix ~= VN.guard then return end
  if secret(text) or secret(sender) or type(text) ~= "string" or type(sender) ~= "string" or isMe(sender) then return end
  if prefix == FLH.prefix then FLH.OnAddon(text, ct, sender) else VN.OnAddon(prefix, text, ct, sender) end
end)

-- a swap: every network at once (called from LayerHop when the LayerSwap round starts)
function N.Ask(m)
  local ok, err = pcall(function()
    N.Start()
    FLH.Ask(m)
    VN.Ask(m)
  end)
  if not ok then N.lastError = tostring(err) end
end

-- the channels: joined a little after login when hosting is on, otherwise at the first swap
local function start()
  if N.started then return end
  N.started = true
  VN.wanted = true
  VN.Join()
  AL.Join()
  scheduleHour()
end
N.Start = start
local function unlocked()
  if VN.waiting and not locked() then VN.waiting = nil VN.Join() end
  pump()
end
ns:On("PLAYER_REGEN_ENABLED", unlocked)
ns:On("PLAYER_ENTERING_WORLD", function()
  C_Timer.After(15, function()
    if S().layerStrangers and not locked() then start() end
    unlocked()
  end)
end)
-- AutoLayer's channel names follow the date
if C_Timer.NewTicker then
  C_Timer.NewTicker(600, function()
    if AL.names and AL.Names()[1] ~= AL.names[1] and not locked() then AL.Join() end
  end)
end

---------------------------------------------------------------------------
-- another layer addon loaded: Chillan does it all now (a hint once a day)
---------------------------------------------------------------------------
N.OTHERS = { "LayerSwap", "LayerAnarchy", "AutoLayer", "LayerHopForAutoLayer", "ForeverLayerHop", "ForeverLayers",
  "BuloLayerForever", "VoidLayer", "ChangeLayer", "LayerHop" }
function N.OthersLoaded()
  local found = {}
  local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  if not loaded then return found end
  for _, name in ipairs(N.OTHERS) do
    local ok, v = pcall(loaded, name)
    if ok and v then found[#found + 1] = name end
  end
  return found
end
ns:On("PLAYER_LOGIN", function()
  C_Timer.After(12, function()
    local found = N.OthersLoaded()
    if #found == 0 then return end
    local today = date("%Y-%m-%d")
    if ns.db.layerHintDay == today then return end
    ns.db.layerHintDay = today
    ns.Print("Layer swap: Chillan's Swap button now reaches LayerSwap, Forever Layer Hop, VoidNet and AutoLayer users by itself. "
      .. table.concat(found, ", ") .. " can be turned off, so you don't get double invites.")
  end)
end)

function N.Status()
  local np = 0
  for _, p in pairs(peers) do if now() - p.t < 180 then np = np + 1 end end
  local nc = 0
  for _ in pairs(N.channels) do nc = nc + 1 end
  return "Forever Layer Hop users nearby: " .. np .. ". VoidNet channel: " .. ((VN.chan and channelId(VN.chan.name)) and ("joined, " .. #VN.roster.names .. " members read") or "not joined")
    .. ". AutoLayer channels: " .. (AL.Channel() and "joined" or "not joined") .. "."
end
