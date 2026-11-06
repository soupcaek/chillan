-- Chillan? – kommunikasjon mellom klientene
-- Bruker en privat, passordbeskyttet kanal som hovedvei, og whispers direkte
-- til venner som ikke kan nås via kanalen (f.eks. på en annen backend-realm).
local ADDON, ns = ...
local Comm = {}
ns.Comm = Comm

local SEP = "~"
local queue = { {}, {}, {} } -- prioritet 1 (høy), 2 (normal), 3 (lav)
local tokens = 5
local MAX_TOKENS = 5
local TOKEN_EVERY = 1.1
local recentWhispers = {}
local seenIds = {}
local myFull

local function now() return GetTime() end

function Comm:MyFull()
  if myFull then return myFull end
  local name, realm = ns.S(UnitFullName, "player")
  if not realm or realm == "" then realm = ns.S(GetNormalizedRealmName) end
  if name and realm and realm ~= "" then
    myFull = name .. "-" .. realm
    return myFull
  end
  return name
end

function Comm:IsMe(sender)
  if not sender then return false end
  local me = self:MyFull()
  return sender == me or ns.ShortName(sender) == ns.ShortName(me) and not sender:find("-")
end

function Comm:NewId()
  return ns.RandomId(7)
end

-- Har vi sett denne meldings-IDen før? (hindrer dobbel visning når samme melding
-- kommer både via kanal og whisper)
function Comm:Seen(id)
  if not id or id == "" then return false end
  if seenIds[id] then return true end
  seenIds[id] = ns.Now()
  return false
end

---------------------------------------------------------------------------
-- Kanal
---------------------------------------------------------------------------
function Comm:ChannelName()
  if not ns.codeHash then return nil end
  return "chln" .. ns.codeHash
end

local function removeFromChatFrames(name)
  local remove = (ChatFrameUtil and ChatFrameUtil.RemoveChannel) or ChatFrame_RemoveChannel
  if not remove then return end
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local f = _G["ChatFrame" .. i]
    if f then pcall(remove, f, name) end
  end
end

function Comm:JoinChannel()
  local name = self:ChannelName()
  if not name then return end
  local id = GetChannelName(name)
  if id and id > 0 then
    self.chanId = id
    removeFromChatFrames(name)
    return
  end
  if JoinTemporaryChannel then
    pcall(JoinTemporaryChannel, name, ns.db.code)
  elseif JoinChannelByName then
    pcall(JoinChannelByName, name, ns.db.code)
  end
  C_Timer.After(1.5, function()
    local cid = GetChannelName(name)
    if cid and cid > 0 then
      self.chanId = cid
      removeFromChatFrames(name)
      ns:Fire("CHANNEL_READY")
    end
  end)
end

function Comm:LeaveChannel(oldName)
  if oldName and LeaveChannelByName then pcall(LeaveChannelByName, oldName) end
  self.chanId = nil
end

function Comm:RefreshChannelId()
  local name = self:ChannelName()
  if not name then self.chanId = nil return end
  local id = GetChannelName(name)
  self.chanId = (id and id > 0) and id or nil
end

---------------------------------------------------------------------------
-- Sending med kø (serveren struper addon-meldinger)
---------------------------------------------------------------------------
function Comm:Build(msgType, ...)
  local parts = { ns.PROTO, ns.codeHash or "", msgType }
  local n = select("#", ...)
  for i = 1, n do
    local v = select(i, ...)
    if v == nil then v = "" end
    if type(v) == "boolean" then v = v and "1" or "0" end
    if type(v) == "number" then
      if v == math.floor(v) then v = tostring(v) else v = string.format("%.1f", v) end
    end
    parts[#parts + 1] = (tostring(v):gsub(SEP, "-"))
  end
  local msg = table.concat(parts, SEP)
  if #msg > 250 then msg = msg:sub(1, 250) end
  return msg
end

local function enqueue(item, prio)
  table.insert(queue[prio or 2], item)
end

-- Send til én mottaker (whisper)
function Comm:SendTo(target, msg, prio, logged)
  if not target or not ns.codeHash then return end
  enqueue({ msg = msg, chatType = "WHISPER", target = target, logged = logged }, prio)
end

-- Send til hele gjengen: kanalen + whisper til venner kanalen ikke når
function Comm:Broadcast(msg, prio, logged)
  if not ns.codeHash then return end
  self:RefreshChannelId()
  if self.chanId then
    enqueue({ msg = msg, chatType = "CHANNEL", target = tostring(self.chanId), logged = logged }, prio)
  end
  local t = ns.Now()
  for char, r in pairs(ns.db.roster) do
    if self:NeedsWhisper(r, t) then
      enqueue({ msg = msg, chatType = "WHISPER", target = char, logged = logged }, prio)
    end
  end
end

-- Vennen er online, men vi har ikke hørt ham på kanalen nylig (f.eks. annen layer)
Comm.CHAN_FRESH = 45
Comm.ONLINE_WINDOW = 300
function Comm:NeedsWhisper(r, t)
  t = t or ns.Now()
  if not r.heard or (t - r.heard) > self.ONLINE_WINDOW then return false end
  if r.offlineAt and (t - r.offlineAt) < 300 then return false end
  return not (r.chan and (t - r.chan) < self.CHAN_FRESH)
end

-- Ny sone/layer: kanalen kan ha byttet server. Glem hvem vi når via kanalen,
-- koble til kanalen på nytt og si hei både via kanal og whisper.
local lastWorldChange = 0
function Comm:OnWorldChanged()
  if not ns.codeHash then return end
  if (GetTime() - lastWorldChange) < 15 then return end
  lastWorldChange = GetTime()
  for _, r in pairs(ns.db.roster) do r.chan = nil end
  self:RefreshChannelId()
  if not self.chanId then self:JoinChannel() end
  C_Timer.After(2, function()
    local msg = Comm:Build("HI", ns.pid, Comm:MyFull(), 1, ns.VERSION)
    Comm:RefreshChannelId()
    if Comm.chanId then enqueue({ msg = msg, chatType = "CHANNEL", target = tostring(Comm.chanId) }, 1) end
    local t = ns.Now()
    for char, r in pairs(ns.db.roster) do
      if r.heard and (t - r.heard) < 600 and not (r.offlineAt and (t - r.offlineAt) < 300) then
        enqueue({ msg = msg, chatType = "WHISPER", target = char }, 1)
      end
    end
    ns.Tracker:SendStatus(1)
  end)
end

-- Bare til kanalen (brukes for å tipse om venner som bare nås via whisper)
function Comm:SendChannel(msg, prio)
  self:RefreshChannelId()
  if self.chanId and ns.codeHash then
    enqueue({ msg = msg, chatType = "CHANNEL", target = tostring(self.chanId) }, prio)
  end
end

-- Send til gruppe/guild i tillegg (brukes kun for "hei" for å finne hverandre)
function Comm:SendScope(msg, scope, prio)
  enqueue({ msg = msg, chatType = scope }, prio)
end

local function trySend(item)
  -- ikke hvisk til noen som nettopp viste seg å være offline (de sier hei selv når de logger på)
  if item.chatType == "WHISPER" then
    local r = ns.db.roster[item.target]
    if r and r.offlineAt and (ns.Now() - r.offlineAt) < 300 and not item.hello then return false, true end
  end
  local fn = item.logged and C_ChatInfo.SendAddonMessageLogged or C_ChatInfo.SendAddonMessage
  if not fn then fn = C_ChatInfo.SendAddonMessage end
  if item.chatType == "WHISPER" then
    recentWhispers[ns.ShortName(item.target):lower()] = now()
  end
  local ok, result = pcall(fn, ns.PREFIX, item.msg, item.chatType, item.target)
  if not ok then return false, true end
  if result == nil or result == true or result == 0 then return true end
  if Enum and Enum.SendAddonMessageResult then
    local R = Enum.SendAddonMessageResult
    if result == R.Success then return true end
    if result == R.AddonMessageThrottle or result == R.ChannelThrottle or result == R.GeneralError then
      return false, false
    end
  end
  if result == false then return false, false end
  return false, true -- andre feil (f.eks. mottaker ikke gyldig): forkast
end

local ticker = CreateFrame("Frame")
local elapsedTok, elapsedSend = 0, 0
ticker:SetScript("OnUpdate", function(_, dt)
  elapsedTok = elapsedTok + dt
  if elapsedTok >= TOKEN_EVERY then
    elapsedTok = 0
    if tokens < MAX_TOKENS then tokens = tokens + 1 end
  end
  elapsedSend = elapsedSend + dt
  if elapsedSend < 0.15 or tokens <= 0 then return end
  elapsedSend = 0
  for p = 1, 3 do
    local item = queue[p][1]
    if item then
      if item.notBefore and item.notBefore > now() then return end
      local sent, drop = trySend(item)
      if sent or drop then
        table.remove(queue[p], 1)
        tokens = tokens - 1
      else
        item.tries = (item.tries or 0) + 1
        if item.tries > 4 then
          table.remove(queue[p], 1)
        else
          item.notBefore = now() + 2 * item.tries
          tokens = 0
        end
      end
      return
    end
  end
end)

function Comm:QueueSize()
  return #queue[1] + #queue[2] + #queue[3]
end

---------------------------------------------------------------------------
-- Mottak
---------------------------------------------------------------------------
Comm.handlers = {}
function Comm:Handle(msgType, fn) self.handlers[msgType] = fn end

local function onAddonMessage(prefix, text, channel, sender)
  if prefix ~= ns.PREFIX then return end
  if ns.isSecret(text) or ns.isSecret(sender) then return end
  if type(text) ~= "string" or type(sender) ~= "string" then return end
  if Comm:IsMe(sender) then return end
  local f = ns.Split(text, SEP)
  if f[1] ~= ns.PROTO or not ns.codeHash or f[2] ~= ns.codeHash then return end
  local msgType = f[3]
  -- husk hvordan vi når denne karakteren
  local r = ns.db.roster[sender]
  if not r then r = {} ns.db.roster[sender] = r end
  r.heard = ns.Now()
  r.offlineAt = nil
  if channel == "WHISPER" then
    r.whisper = ns.Now()
    -- hvisker vennen oss, når han oss ikke via kanalen: svar også via whisper
    if r.chan and (ns.Now() - r.chan) > 10 then r.chan = nil end
  else
    r.chan = ns.Now()
  end
  local fields = {}
  for i = 4, #f do fields[#fields + 1] = f[i] end
  local h = Comm.handlers[msgType]
  if h then
    local ok, err = pcall(h, fields, sender, channel)
    if not ok and ns.debug then ns.Print("feil i", msgType, err) end
  end
end

ns:On("CHAT_MSG_ADDON", onAddonMessage)
ns:On("CHAT_MSG_ADDON_LOGGED", onAddonMessage)

---------------------------------------------------------------------------
-- Skjul systemmeldinger om at offline venner ikke finnes, og kanal-varsler
---------------------------------------------------------------------------
local notFoundPatterns = {}
local function buildPatterns()
  for _, key in ipairs({ "ERR_CHAT_PLAYER_NOT_FOUND_S", "ERR_FRIEND_NOT_FOUND" }) do
    local s = _G[key]
    if type(s) == "string" then
      local pat = s:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", "(.+)")
      notFoundPatterns[#notFoundPatterns + 1] = "^" .. pat .. "$"
    end
  end
  -- reserve hvis spillet har en annen tekst enn vi forventer
  notFoundPatterns[#notFoundPatterns + 1] = "^No player named '(.+)' is currently playing%.?$"
end

-- En venn vi hvisket til er ikke pålogget: slutt å hviske og vis ham som offline
function Comm:MarkOffline(name)
  local short = ns.ShortName(name):lower()
  for char, r in pairs(ns.db.roster) do
    if ns.ShortName(char):lower() == short then
      r.heard = nil
      r.offlineAt = ns.Now()
      if r.pid then
        local p = ns.db.people[r.pid]
        if p and p.live and p.live.char and ns.ShortName(p.live.char):lower() == short then
          p.heard = nil
          ns:MarkDirty()
        end
      end
    end
  end
end

local function systemFilter(_, _, msg, ...)
  if type(msg) ~= "string" or ns.isSecret(msg) then return false end
  for _, pat in ipairs(notFoundPatterns) do
    local who = msg:match(pat)
    if who then
      local key = ns.ShortName(who):lower()
      local t = recentWhispers[key]
      if t and (now() - t) < 15 then
        Comm:MarkOffline(who)
        return true
      end
      return false
    end
  end
  return false
end

local function channelNoticeFilter(_, _, ...)
  local name = Comm:ChannelName()
  if not name then return false end
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) == "string" and not ns.isSecret(v) and v:lower():find(name, 1, true) then return true end
  end
  return false
end

function Comm:InstallFilters()
  buildPatterns()
  local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
  if not add then return end
  pcall(add, "CHAT_MSG_SYSTEM", systemFilter)
  pcall(add, "CHAT_MSG_CHANNEL_NOTICE", channelNoticeFilter)
  pcall(add, "CHAT_MSG_CHANNEL_NOTICE_USER", channelNoticeFilter)
  pcall(add, "CHAT_MSG_CHANNEL_JOIN", channelNoticeFilter)
  pcall(add, "CHAT_MSG_CHANNEL_LEAVE", channelNoticeFilter)
end

function Comm:Init()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(ns.PREFIX)
  end
  self:InstallFilters()
end
