-- Chillan? – kommunikasjon mellom klientene
-- Bruker en privat, passordbeskyttet kanal som hovedvei, og whispers direkte
-- til venner som ikke kan nås via kanalen (f.eks. på en annen backend-realm).
local ADDON, ns = ...
local Comm = {}
ns.Comm = Comm

local SEP = "~"
local queue = { {}, {}, {} } -- prioritet 1 (høy), 2 (normal), 3 (lav)
Comm._queue = queue
local tokens = 5
local MAX_TOKENS = 8
local TOKEN_EVERY = 1.0
local recentWhispers = {}
local seenIds = {}
local myFull

local function now() return GetTime() end

-- Navn kan skrives "Navn-Realm", "Navn Realm" eller bare "Navn" i ulike meldinger.
-- Sammenlign uten store bokstaver, mellomrom og bindestrek.
local function norm(s) return (tostring(s or ""):lower():gsub("[%s%-']", "")) end
local function sameChar(a, b)
  local na, nb = norm(a), norm(b)
  if na == nb then return true end
  local sa, sb = norm(ns.ShortName(a)), norm(ns.ShortName(b))
  return sa == nb or sb == na or sa == sb
end
Comm.SameChar = sameChar

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
  self.joinAttemptAt = GetTime()
  if JoinTemporaryChannel then
    pcall(JoinTemporaryChannel, name, ns.db.code)
  elseif JoinChannelByName then
    pcall(JoinChannelByName, name, ns.db.code)
  end
  -- serveren kan bruke noen sekunder på å slippe oss inn: sjekk hvert sekund i 20 sek
  local tries = 0
  local function check()
    tries = tries + 1
    local cid = GetChannelName(name)
    if cid and cid > 0 then
      self.chanId = cid
      removeFromChatFrames(name)
      ns:Fire("CHANNEL_READY")
    elseif tries < 20 and self:ChannelName() == name then
      C_Timer.After(1, check)
    end
  end
  C_Timer.After(1, check)
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

-- Tilstandsmeldinger (status, statistikk, lister) erstatter en eldre kopi som fortsatt
-- står i køen til samme mottaker i stedet for å legge seg bakerst. Ellers hoper det seg
-- opp mange like meldinger ved oppstart, og chat og «jeg er online» må vente lenge.
local COALESCE = { ST = 2, SS = 2, S2 = 2, S3 = 2, HR = 2, QL = 2, HI = 2, PF = 2, SC = 3,
  LH = 5, AL = 4, PR = 4 } -- tall = hvor mange felt (fra starten) som utgjør nøkkelen
local function coalesceKey(item)
  local parts = {}
  local i = 0
  for field in (item.msg .. "~"):gmatch("([^~]*)~") do
    i = i + 1
    parts[i] = field
    if i >= 8 then break end
  end
  local n = COALESCE[parts[3] or ""]
  if not n then return nil end
  -- PROTO~kode~TYPE~felt…  →  TYPE + de første feltene + kanaltype + mottaker
  local key = { parts[3], item.chatType, tostring(item.target or "") }
  for j = 4, 2 + n do key[#key + 1] = parts[j] or "" end
  return table.concat(key, "|")
end

local function enqueue(item, prio)
  prio = prio or 2
  local key = coalesceKey(item)
  if key then
    item.ckey = key
    for p = 1, 3 do
      local q = queue[p]
      for i = 1, #q do
        if q[i].ckey == key then
          if p <= prio then
            q[i].msg = item.msg -- nyeste innhold, samme plass i køen
          else
            table.remove(q, i)
            table.insert(queue[prio], item) -- flytt opp til høyere prioritet
          end
          return
        end
      end
    end
  end
  table.insert(queue[prio], item)
end

-- Send til én mottaker (whisper)
function Comm:SendTo(target, msg, prio, logged)
  if not target or not ns.codeHash then return end
  enqueue({ msg = msg, chatType = "WHISPER", target = target, logged = logged }, prio)
end

-- Send til hele gjengen: kanalen + whisper til venner kanalen ikke når
-- Send til hele gjengen. Gjengkanalen virker bare innenfor én «backend-realm» i
-- Forever (det finnes flere per ruleset), så for hver venn velger vi én vei:
--   1) kanalen, hvis han hører oss der (HR-hjerteslaget i Sync.lua sier fra)
--   2) Battle.net, hvis han er Battle.net-venn (virker på tvers av realm og layer)
--   3) whisper til navnet slik spillet selv oppga det
function Comm:Broadcast(msg, prio, logged)
  if not ns.codeHash then return end
  self:RefreshChannelId()
  if self.chanId then
    enqueue({ msg = msg, chatType = "CHANNEL", target = tostring(self.chanId), logged = logged }, prio)
  end
  local t = ns.Now()
  local groups = {}
  for char, r in pairs(ns.db.roster) do
    if r.heard and (t - r.heard) <= self.ONLINE_WINDOW and not (r.offlineAt and (t - r.offlineAt) < 300)
      and not (r.pid and r.pid == ns.pid) then
      local key = r.pid or char
      groups[key] = groups[key] or {}
      table.insert(groups[key], { char = char, r = r })
    end
  end
  local covered = {}
  for key, list in pairs(groups) do
    covered[key] = true
    local p = ns.db.people[key]
    local forced = p and p.forceWhisper and (t - p.forceWhisper) < 120
    local chanOK = false
    for _, e in ipairs(list) do
      if e.r.forceWhisper and (t - e.r.forceWhisper) < 120 then forced = true end
      if not e.r.bn and e.r.chan and (t - e.r.chan) < self.CHAN_FRESH then chanOK = true end
    end
    if forced or not chanOK then
      local target = self:BestRoute(list, t)
      if target then enqueue({ msg = msg, chatType = "WHISPER", target = target, logged = logged }, prio) end
    end
  end
  -- viktige meldinger (chat, ding, død, SOS …): send også direkte til venner vi bare vet er
  -- online gjennom andre i gjengen (annen layer/realm), så ingen går glipp av dem
  if prio == 1 then
    for pid, p in pairs(ns.db.people) do
      if pid ~= ns.pid and not covered[pid] and p.via and (t - p.via) < 80 then
        local target = self:TargetFor(p)
        local r = target and ns.db.roster[target]
        if target and not (r and r.offlineAt and (t - r.offlineAt) < 600) then
          enqueue({ msg = msg, chatType = "WHISPER", target = target, logged = logged }, prio)
        end
      end
    end
  end
end

-- Ved utlogging: send «BY» direkte på kanalen og til de vi når direkte (maks 10)
function Comm:SendBye()
  if not ns.codeHash then return end
  local msg = self:Build("BY", ns.pid)
  self:RefreshChannelId()
  if self.chanId then pcall(C_ChatInfo.SendAddonMessage, ns.PREFIX, msg, "CHANNEL", tostring(self.chanId)) end
  local t, n, done = ns.Now(), 0, {}
  for char, r in pairs(ns.db.roster) do
    if n < 10 and r.heard and (t - r.heard) < 120 and not (r.chan and (t - r.chan) < self.CHAN_FRESH)
      and not done[r.pid or char] then
      done[r.pid or char] = true
      n = n + 1
      if char:sub(1, 3) == "bn:" then
        local fn = (C_BattleNet and C_BattleNet.SendGameData) or BNSendGameData
        if fn then pcall(fn, tonumber(char:sub(4)), ns.PREFIX, msg) end
      else
        pcall(C_ChatInfo.SendAddonMessage, ns.PREFIX, msg, "WHISPER", r.whisperAs or char)
      end
    end
  end
end

-- Beste direkte vei til en venn blant flere roster-oppføringer: Battle.net først
function Comm:BestRoute(list, t)
  t = t or ns.Now()
  local best, bestT
  for _, e in ipairs(list) do
    if e.r.bn and e.r.heard and (t - e.r.heard) < 150 then return e.char end
  end
  for _, e in ipairs(list) do
    if not e.r.bn and not (e.r.noWhisper and (t - e.r.noWhisper) < 600) then
      local h = e.r.heard or 0
      if not bestT or h > bestT then best, bestT = e.char, h end
    end
  end
  return best
end

-- Navnet andre kan hviske til (Forever: «Fornavn Etternavn», uten realm)
function ns.WhisperName(p)
  if not p then return nil end
  if p.whisperTo then return p.whisperTo end
  local n = (p.live and p.live.char) or p.main
  return n and ns.ShortName(n) or nil
end

-- Hvor sender vi direkte til en person? (Battle.net, ellers navnet spillet ga oss)
function Comm:TargetFor(p)
  if not p then return nil end
  local list, t = {}, ns.Now()
  for char, r in pairs(ns.db.roster) do
    if r.pid == p.pid then table.insert(list, { char = char, r = r }) end
  end
  -- I Forever er whisper-navnet «Fornavn Etternavn» uten realm
  local fallback = p.whisperTo or (p.live and p.live.char) or p.main
  if fallback and fallback:sub(1, 3) ~= "bn:" and not p.whisperTo then fallback = ns.ShortName(fallback) end
  return self:BestRoute(list, t) or fallback
end

-- Vennen er online, men vi har ikke hørt ham på kanalen nylig (f.eks. annen layer)
Comm.CHAN_FRESH = 45
Comm.ONLINE_WINDOW = 120
function Comm:NeedsWhisper(r, t)
  t = t or ns.Now()
  if not r.heard or (t - r.heard) > self.ONLINE_WINDOW then return false end
  if r.offlineAt and (t - r.offlineAt) < 300 then return false end
  -- vennen har sagt fra (HR) at han ikke hører oss på kanalen
  if r.forceWhisper and (t - r.forceWhisper) < 120 then return true end
  return not (r.chan and (t - r.chan) < self.CHAN_FRESH)
end

-- Ny sone/layer: sjekk at vi fortsatt er i kanalen og si et kort hei.
-- (HR-hjerteslaget i Sync.lua oppdager selv om noen ikke hører oss lenger,
-- så vi trenger ikke hviske til alle ved hvert sonebytte – det ga mye trafikk
-- og forsinket chatten.)
local lastWorldChange = 0
function Comm:OnWorldChanged()
  if not ns.codeHash then return end
  -- byttet vi backend-realm (f.eks. ved å gå i gruppe med noen på den andre)? Da er
  -- gjengkanalen en annen: glem hvem vi hørte på kanalen og si fra med en gang (HR)
  local realm = ns.S(GetNormalizedRealmName)
  if realm and self.lastRealm and realm ~= self.lastRealm then
    for _, r in pairs(ns.db.roster) do r.chan = nil end
    myFull = nil
    lastWorldChange = 0
    C_Timer.After(4, function() if ns.Sync then ns.Sync:Send() end end)
  end
  if realm then self.lastRealm = realm end
  if (GetTime() - lastWorldChange) < 15 then return end
  lastWorldChange = GetTime()
  self:RefreshChannelId()
  if not self.chanId then self:JoinChannel() end
  C_Timer.After(2, function()
    -- 0 = bare ny sone/layer: de andre trenger ikke sende all statistikk på nytt
    local msg = Comm:Build("HI", ns.pid, Comm:MyFull(), 0, ns.VERSION)
    Comm:RefreshChannelId()
    if Comm.chanId then
      enqueue({ msg = msg, chatType = "CHANNEL", target = tostring(Comm.chanId) }, 1)
    else
      -- uten kanal: hvisk til de vi har hørt nylig
      local t = ns.Now()
      for char, r in pairs(ns.db.roster) do
        if r.heard and (t - r.heard) < 600 and not (r.offlineAt and (t - r.offlineAt) < 300) then
          enqueue({ msg = msg, chatType = "WHISPER", target = char }, 1)
        end
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

-- Battle.net-melding (virker mellom Battle.net-venner uansett realm og layer)
local function sendBN(id, msg)
  local fn = (C_BattleNet and C_BattleNet.SendGameData) or BNSendGameData
  if not fn or not id then return false, true end
  local ok, result = pcall(fn, id, ns.PREFIX, msg)
  if not ok then Comm.stats.failed = Comm.stats.failed + 1 Comm.stats.lastErr = "BN: " .. tostring(result) return false, true end
  if result == nil or result == 0 or result == true then
    Comm.stats.sent = Comm.stats.sent + 1
    Comm.stats.sentBN = (Comm.stats.sentBN or 0) + 1
    return true
  end
  if result == 3 or result == 8 then return false, false end -- struping: prøv igjen
  Comm.stats.failed = Comm.stats.failed + 1
  Comm.stats.lastErr = "BN: " .. tostring(result)
  return false, true
end

local function trySend(item)
  if item.chatType == "WHISPER" and type(item.target) == "string" and item.target:sub(1, 3) == "bn:" then
    return sendBN(tonumber(item.target:sub(4)), item.msg)
  end
  -- ikke hvisk til noen som nettopp viste seg å være offline (de sier hei selv når de logger på)
  local target = item.target
  if item.chatType == "WHISPER" then
    local r = ns.db.roster[item.target]
    if r and r.offlineAt and (ns.Now() - r.offlineAt) < 300 and not item.hello then return false, true end
    -- whisper-navnet virker ikke for denne karakteren (vi hører ham bare på kanalen)
    if r and r.noWhisper and (ns.Now() - r.noWhisper) < 600 then return false, true end
    -- prøv navnet uten realm hvis det fullstendige navnet ikke ble funnet
    if r and r.whisperAs then target = r.whisperAs end
  end
  local fn = item.logged and C_ChatInfo.SendAddonMessageLogged or C_ChatInfo.SendAddonMessage
  if not fn then fn = C_ChatInfo.SendAddonMessage end
  if item.chatType == "WHISPER" then
    recentWhispers[norm(target)] = now()
    recentWhispers[norm(ns.ShortName(target))] = now()
    Comm.lastTarget = Comm.lastTarget or {}
    Comm.lastTarget[norm(ns.ShortName(target))] = item.target
  end
  local ok, result = pcall(fn, ns.PREFIX, item.msg, item.chatType, target)
  if not ok then Comm.stats.failed = Comm.stats.failed + 1 Comm.stats.lastErr = tostring(result) return false, true end
  if result == nil or result == true or result == 0 then Comm.stats.sent = Comm.stats.sent + 1 return true end
  Comm.stats.failed = Comm.stats.failed + 1
  Comm.stats.lastErr = tostring(result)
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
-- Sender det første som er klart, i prioritert rekkefølge. Et element som venter
-- på nytt forsøk (struping/feil) blokkerer ikke resten av køen.
ticker:SetScript("OnUpdate", function(_, dt)
  elapsedTok = elapsedTok + dt
  if elapsedTok >= TOKEN_EVERY then
    elapsedTok = 0
    if tokens < MAX_TOKENS then tokens = tokens + 1 end
  end
  elapsedSend = elapsedSend + dt
  if elapsedSend < 0.1 or tokens <= 0 then return end
  elapsedSend = 0
  local t = now()
  for p = 1, 3 do
    local q = queue[p]
    for i = 1, #q do
      local item = q[i]
      if not item.notBefore or item.notBefore <= t then
        local sent, drop = trySend(item)
        if sent or drop then
          table.remove(q, i)
          if sent then tokens = tokens - 1 end
        else
          item.tries = (item.tries or 0) + 1
          if item.tries > 4 then
            table.remove(q, i)
          else
            item.notBefore = t + 2 * item.tries
            tokens = 0
          end
        end
        return
      end
    end
  end
end)

-- Rydd gamle meldings-IDer (de trengs bare for å hindre dobbel visning)
C_Timer.NewTicker(600, function()
  local cutoff = ns.Now() - 3600
  for id, at in pairs(seenIds) do if at < cutoff then seenIds[id] = nil end end
  for k, at in pairs(recentWhispers) do if now() - at > 60 then recentWhispers[k] = nil end end
end)

function Comm:QueueSize()
  return #queue[1] + #queue[2] + #queue[3]
end

---------------------------------------------------------------------------
-- Mottak
---------------------------------------------------------------------------
Comm.handlers = {}
function Comm:Handle(msgType, fn) self.handlers[msgType] = fn end

-- Videresending: hendelser vi får via whisper fra en venn som ikke er i
-- kanalen (f.eks. annen layer), sendes videre på kanalen så alle får dem.
local RELAY = { EV = true, CH = true, RX = true, MT = true, PO = true, PV = true, AV = true, AR = true, EN = true }
local relaySeen, relayDone = {}, {}
local function relayKey(t, f)
  if t == "RX" or t == "PV" or t == "AR" then return t .. (f[4] or "") .. (f[5] or "") end
  return t .. (f[4] or "")
end

local function maybeRelay(msgType, f, text, channel)
  if not RELAY[msgType] then return end
  -- gamle meldinger (synk/historikk) skal ikke ut på kanalen igjen
  if (msgType == "CH" and (tonumber(f[7]) or 0) > 90) or (msgType == "EV" and (tonumber(f[8]) or 0) > 90) then return end
  local key = relayKey(msgType, f)
  if channel ~= "WHISPER" then
    relaySeen[key] = GetTime()
    return
  end
  if relaySeen[key] or relayDone[key] then return end
  Comm:RefreshChannelId()
  if not Comm.chanId then return end
  relayDone[key] = true
  -- litt tilfeldig ventetid, så bare én i gjengen trenger å videresende
  C_Timer.After(0.4 + math.random() * 2.5, function()
    if relaySeen[key] then return end
    Comm:RefreshChannelId()
    if Comm.chanId then
      enqueue({ msg = text, chatType = "CHANNEL", target = tostring(Comm.chanId) }, 2)
      relaySeen[key] = GetTime()
    end
  end)
end

-- Tellere til /chill debug: viser om vi får meldinger i det hele tatt, og om de er fra en annen kode
Comm.stats = { recv = 0, recvChan = 0, recvWhisper = 0, otherCode = 0, otherProto = 0, sent = 0, failed = 0 }

local function onAddonMessage(prefix, text, channel, sender, isBN)
  if prefix ~= ns.PREFIX then return end
  if ns.isSecret(text) or ns.isSecret(sender) then return end
  if type(text) ~= "string" or type(sender) ~= "string" then return end
  if Comm:IsMe(sender) then return end
  local f = ns.Split(text, SEP)
  local st = Comm.stats
  if f[1] ~= ns.PROTO then st.otherProto = st.otherProto + 1 return end
  if not ns.codeHash or f[2] ~= ns.codeHash then
    st.otherCode = st.otherCode + 1
    st.otherCodeFrom = sender
    return
  end
  st.recv = st.recv + 1
  if channel == "WHISPER" then st.recvWhisper = st.recvWhisper + 1 else st.recvChan = st.recvChan + 1 end
  local msgType = f[3]
  -- husk hvordan vi når denne karakteren
  local r = ns.db.roster[sender]
  if not r then r = {} ns.db.roster[sender] = r end
  r.heard = ns.Now()
  r.offlineAt = nil
  if isBN then
    r.bn = true
    st.recvBN = (st.recvBN or 0) + 1
  end
  if channel == "WHISPER" then
    r.whisper = ns.Now()
    -- (om vennen hører oss på kanalen avgjøres av HR-hjerteslaget i Sync.lua –
    -- å nullstille r.chan her fikk to venner til å hviske til hverandre for alltid)
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
  maybeRelay(msgType, f, text, channel)
end

-- Tips gjengen jevnlig om venner som bare nås via whisper, så alle får kontakt
function Comm:GossipWhisperPeers()
  self:RefreshChannelId()
  if not self.chanId or not ns.codeHash then return end
  local t, n, told = ns.Now(), 0, {}
  for char, r in pairs(ns.db.roster) do
    if r.pid and not told[r.pid] and r.heard and (t - r.heard) < 120 and r.whisper and (t - r.whisper) < 120
      and not (r.chan and (t - r.chan) < self.CHAN_FRESH) and n < 10 then
      local p = ns.db.people[r.pid]
      local name = (not r.bn) and char or ns.WhisperName(p)
      if name and name:sub(1, 3) ~= "bn:" then
        self:SendChannel(self:Build("RO", r.pid, name), 3)
        told[r.pid] = true
        n = n + 1
      end
    end
  end
end

ns:On("CHAT_MSG_ADDON", onAddonMessage)
ns:On("BN_CHAT_MSG_ADDON", function(prefix, text, _, senderID)
  if ns.isSecret(senderID) or type(senderID) ~= "number" then return end
  onAddonMessage(prefix, text, "WHISPER", "bn:" .. senderID, true)
end)
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
  -- bare oppføringen vi faktisk hvisket til (ikke en annen skrivemåte av samme navn som virker)
  local exact = self.lastTarget and self.lastTarget[norm(ns.ShortName(name))]
  for char, r in pairs(ns.db.roster) do
    if (exact and char == exact) or (not exact and sameChar(char, name)) then
      r.offlineAt = ns.Now()
      -- hører vi ham fortsatt på kanalen, er han ikke offline – det er whisper-navnet
      -- som ikke virker. Da slutter vi bare å hviske (ellers blir det spam).
      if r.chan and (ns.Now() - r.chan) < 60 then
        local short = ns.ShortName(char)
        if not r.whisperAs and short ~= char then
          r.whisperAs = short
          r.offlineAt = nil
        else
          r.noWhisper = ns.Now()
        end
      else
        r.heard = nil
        -- vis ham offline bare hvis vi ikke har hørt ham på en annen vei det siste minuttet
        if r.pid then
          local p = ns.db.people[r.pid]
          local alive = false
          for c2, r2 in pairs(ns.db.roster) do
            if c2 ~= char and r2.pid == r.pid and r2.heard and (ns.Now() - r2.heard) < 60 then alive = true end
          end
          if p and not alive and p.live and p.live.char and sameChar(p.live.char, name) then
            p.heard = nil
            p.via = nil
            ns:MarkDirty()
          end
        end
      end
    end
  end
end

-- Er dette en av gjengens karakterer (eller noen vi nettopp hvisket til)?
local function isOurs(who)
  local t = recentWhispers[norm(who)] or recentWhispers[norm(ns.ShortName(who))]
  if t and (now() - t) < 60 then return true end
  for char in pairs(ns.db.roster) do
    if sameChar(char, who) then return true end
  end
  return false
end

local function notFoundName(msg)
  if type(msg) ~= "string" or ns.isSecret(msg) then return nil end
  for _, pat in ipairs(notFoundPatterns) do
    local who = msg:match(pat)
    if who then return who end
  end
end

local function systemFilter(_, _, msg, ...)
  local who = notFoundName(msg)
  if who and isOurs(who) then return true end
  return false
end

-- Uavhengig av filteret: merk vennen som offline så vi slutter å hviske (stopper spammen)
ns:On("CHAT_MSG_SYSTEM", function(msg)
  local who = notFoundName(msg)
  if who and isOurs(who) then Comm:MarkOffline(who) end
end)

local function channelNoticeFilter(_, event, ...)
  local name = Comm:ChannelName()
  if not name then return false end
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) == "string" and not ns.isSecret(v) and v:lower():find(name, 1, true) then
      -- husk hva serveren svarte, så /chill debug kan si hvorfor kanalen ikke virker
      local notice = select(1, ...)
      if event == "CHAT_MSG_CHANNEL_NOTICE" and type(notice) == "string" and not ns.isSecret(notice) then
        Comm.lastNotice = notice
        Comm.lastNoticeAt = ns.Now()
      end
      return true
    end
  end
  return false
end

-- Antall chat-kanaler du er med i (WoW har en grense på 10)
function Comm:ChannelCount()
  if not GetChannelList then return nil end
  local list = { GetChannelList() }
  return math.floor(#list / 3)
end

local NOTICE_TEXT = {
  YOU_JOINED = "koblet til", YOU_CHANGED = "koblet til",
  WRONG_PASSWORD = "feil passord – sjekk at gjengkoden er helt lik",
  BANNED = "utestengt fra kanalen", NOT_MEMBER = "ikke medlem",
  TRIAL_RESTRICTED = "prøvekonto kan ikke bruke chat-kanaler",
  INVALID_NAME = "ugyldig kanalnavn", THROTTLED = "for mange forsøk – vent litt",
  YOU_LEFT = "forlot kanalen", SUSPENDED = "kanalen er midlertidig utilgjengelig",
}
function Comm:ChannelStatusText()
  self:RefreshChannelId()
  if self.chanId then return "koblet til (id " .. self.chanId .. ")" end
  local parts = { "ikke koblet" }
  if self.lastNotice then parts[#parts + 1] = "serveren svarte: " .. (NOTICE_TEXT[self.lastNotice] or self.lastNotice) end
  local n = self:ChannelCount()
  if n and n >= 10 then parts[#parts + 1] = "du er med i " .. n .. " kanaler (maks 10) – forlat én" end
  if not self.lastNotice and not (n and n >= 10) then parts[#parts + 1] = "ingen svar fra serveren – prøv /chill kanal" end
  return table.concat(parts, " · ")
end

-- Koble til på nytt (brukes av /chill kanal og automatisk hvert minutt)
function Comm:Reconnect()
  local name = self:ChannelName()
  if not name then return end
  self:RefreshChannelId()
  if self.chanId then return end
  self:JoinChannel()
end

function Comm:InstallFilters()
  buildPatterns()
  -- registrer i begge filter-API-ene som finnes (navnet har flyttet seg mellom versjoner)
  local adders = {}
  if ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter then adders[#adders + 1] = ChatFrameUtil.AddMessageEventFilter end
  if ChatFrame_AddMessageEventFilter and ChatFrame_AddMessageEventFilter ~= adders[1] then adders[#adders + 1] = ChatFrame_AddMessageEventFilter end
  for _, add in ipairs(adders) do
    pcall(add, "CHAT_MSG_SYSTEM", systemFilter)
    pcall(add, "CHAT_MSG_CHANNEL_NOTICE", channelNoticeFilter)
    pcall(add, "CHAT_MSG_CHANNEL_NOTICE_USER", channelNoticeFilter)
    pcall(add, "CHAT_MSG_CHANNEL_JOIN", channelNoticeFilter)
    pcall(add, "CHAT_MSG_CHANNEL_LEAVE", channelNoticeFilter)
  end
end

function Comm:Init()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(ns.PREFIX)
  end
  self:InstallFilters()
end
