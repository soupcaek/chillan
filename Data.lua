-- Chillan? – mottak og lagring av alt som deles i gjengen
local ADDON, ns = ...
local Data = {}
ns.Data = Data
local Comm = ns.Comm

local loginAt = 0
local syncedFrom = nil

local function num(v) return tonumber(v) end
local function ago2t(v) return ns.Now() - (tonumber(v) or 0) end
local function fresh(t) return (ns.Now() - t) < 180 end

local function quiet()
  -- det første minuttet etter innlogging kommer mye på en gang: ingen popup-spam
  return (GetTime() - loginAt) < 60
end

---------------------------------------------------------------------------
-- Status og statistikk fra andre
---------------------------------------------------------------------------
Comm:Handle("ST", function(f, sender, channel)
  local pid = f[1]
  if not pid or pid == ns.pid then return end
  local p = ns:GetPerson(pid, true)
  local wasOnline = ns:IsOnline(p)
  local wasDirect = p.heard and (ns.Now() - p.heard) < 100
  local char = f[2] ~= "" and f[2] or sender
  local c = p.chars[char] or {}
  p.chars[char] = c
  c.name = ns.ShortName(char)
  c.class, c.race, c.level = f[3], f[4], num(f[5]) or c.level
  p.main = char
  local L = p.live or {}
  p.live = L
  L.char = char
  L.zone, L.sub, L.status = f[6], f[7], f[8]
  L.session = ns.Now() - (num(f[9]) or 0)
  L.inInst = f[10] == "1"
  L.mapID = num(f[11])
  L.x = num(f[12]) and num(f[12]) / 1000 or nil
  L.y = num(f[13]) and num(f[13]) / 1000 or nil
  L.cont, L.wx, L.wy = num(f[14]), num(f[15]), num(f[16])
  -- fullt karakternavn (Forever: fornavn + etternavn) fra eldre klienter kan mangle
  if f[17] and f[17] ~= "" and (f[18] and f[18] ~= "") then c.name = f[17] end
  if f[18] and f[18] ~= "" then p.version = f[18] Data:CheckVersion(f[18], pid) end
  if f[19] and f[19] ~= "" then p.alias = f[19] end
  p.heard = ns.Now()
  p.lastSeen = ns.Now()
  local r = ns.db.roster[sender]
  if r then r.pid = pid end
  -- navnet slik spillet selv oppga det er det som virker for whisper
  if sender:sub(1, 3) ~= "bn:" then p.whisperTo = sender end
  -- «logget på» bare når han faktisk nettopp logget på (økten hans er fersk), ikke når
  -- vi selv logger inn eller når han dukker opp igjen etter et layer-/serverbytte.
  -- Hver økt varsles maks én gang.
  local sessAge = num(f[9]) or 0
  local sessKey = math.floor((ns.Now() - sessAge) / 60)
  local freshLogin = sessAge < 150 and p.announcedSession ~= sessKey and not quiet()
    and (not p.announcedSession or math.abs(sessKey - p.announcedSession) > 2)
  p.announcedSession = sessKey
  if not wasOnline and freshLogin then
    do
      ns:Fire("ACTIVITY", ns.UI.InlineIcon("Login", ns.C.green, 13) .. "  " .. ns:PersonLabel(p) .. ns.Colorize(" logget på" .. ((L.zone and L.zone ~= "") and (" · " .. L.zone) or ""), ns.C.text2))
      ns:Fire("FEEDEVENT", ns.UI.InlineIcon("Login", ns.C.green, 12) .. "  " .. ns:ShortWho(p) .. ns.Colorize(" logget på", ns.C.text2))
    end
    if ns.db.settings.onlineToasts then
      ns:Fire("TOAST", { kind = "online", pid = pid,
        title = ns:PersonLabel(p) .. " logget på",
        text = (c.level and ("Lvl " .. c.level .. " · ") or "") .. (L.zone or "") })
    end
  end
  if not wasDirect then
    -- ny venn på nett: svar med vår status med en gang, så han ser oss også
    Comm:SendTo(sender, ns.Tracker:BuildST(), 1)
    -- send våre egne data og hent historikk ved behov
    Data:OnPeerOnline(pid, sender)
    if not Data.sentTo then Data.sentTo = {} end
    if not Data.sentTo[pid] then
      Data.sentTo[pid] = true
      Comm:SendTo(sender, ns.Tracker:BuildSS(), 3)
      Comm:SendTo(sender, ns.Tracker:BuildS2(), 3)
      Comm:SendTo(sender, ns.Tracker:BuildS3(), 3)
      ns.Ach:SendList(sender)
      ns.Tracker:SendHistory(sender)
      ns.Quests:SendTo(sender)
      ns.Extras:SendNotes(sender)
    end
    -- når vi bare når vennen via whisper, tips resten av gjengen på kanalen
    if channel == "WHISPER" and p.whisperTo then
      Comm:SendChannel(Comm:Build("RO", pid, p.whisperTo), 3)
    end
  end
  ns:MarkDirty()
end)

-- Vennen logger ut (eller laster UI på nytt): vis ham som offline med en gang
Comm:Handle("BY", function(f, sender)
  local pid = f[1]
  if not pid or pid == ns.pid then return end
  local p = ns.db.people[pid]
  if p then
    p.heard, p.via, p.byeAt = nil, nil, ns.Now()
    p.lastSeen = ns.Now()
  end
  local r = ns.db.roster[sender]
  if r then r.heard = nil end
  ns:MarkDirty()
end)

Comm:Handle("SS", function(f, sender)
  local pid = f[1]
  if not pid or pid == ns.pid then return end
  local p = ns:GetPerson(pid, true)
  local char = f[2] ~= "" and f[2] or sender
  local c = p.chars[char] or {}
  p.chars[char] = c
  c.name = c.name or ns.ShortName(char)
  if num(f[3]) then c.played = num(f[3]) c.playedAt = ns.Now() end
  local s = p.stats or {}
  p.stats = s
  s.wk = f[4]
  s.wOnline, s.wQuests, s.wGold, s.wDeaths = num(f[5]) or 0, num(f[6]) or 0, num(f[7]) or 0, num(f[8]) or 0
  s.tOnline, s.tQuests, s.tGold, s.tDeaths = num(f[9]) or 0, num(f[10]) or 0, num(f[11]) or 0, num(f[12]) or 0
  if f[13] and f[13] ~= "" then
    s.prev = { wk = f[13], Online = num(f[14]) or 0, Quests = num(f[15]) or 0, Gold = num(f[16]) or 0, Deaths = num(f[17]) or 0 }
  end
  if f[18] and f[18] ~= "" then p.deathZone = f[18] end
  if num(f[19]) then p.deathAt = ago2t(f[19]) end
  p.main = p.main or char
  ns:MarkDirty()
end)

Comm:Handle("S2", function(f)
  local pid = f[1]
  if not pid or pid == ns.pid then return end
  local p = ns:GetPerson(pid, true)
  local s = p.stats or {}
  p.stats = s
  if f[2] and f[2] ~= "" then s.wk = f[2] end
  s.wLevels, s.wKills = num(f[3]) or 0, num(f[4]) or 0
  s.tLevels, s.tKills = num(f[5]) or 0, num(f[6]) or 0
  s.tLongest = num(f[7]) or s.tLongest
  if f[11] and f[11] ~= "" then s.wNight = num(f[11]) or 0 end
  if f[8] and f[8] ~= "" then
    s.prev = s.prev or { wk = f[8] }
    if s.prev.wk == f[8] then s.prev.Levels, s.prev.Kills = num(f[9]) or 0, num(f[10]) or 0 end
  end
  ns:MarkDirty()
end)

Comm:Handle("S3", function(f)
  local pid = f[1]
  if not pid or pid == ns.pid then return end
  local p = ns:GetPerson(pid, true)
  p.s3 = {
    xp = num(f[2]), xpMax = num(f[3]), rested = num(f[4]) or 0, wXP = num(f[5]) or 0, tXP = num(f[6]) or 0,
    sessXP = num(f[7]) or 0, sessSec = num(f[8]) or 0, money = num(f[9]), ilvl = num(f[10]),
    today = num(f[11]) or 0, streak = num(f[12]) or 0, zone = (f[13] ~= "" and f[13]) or nil, at = ns.Now(),
    dura = num(f[14]),
  }
  ns:MarkDirty()
end)

-- Detaljstatistikk for en person (meg selv regnes ut lokalt)
function ns:PersonS3(p)
  if not p then return nil end
  if p == ns.db.people[ns.pid] then return ns.Tracker:S3Data() end
  return p.s3
end

-- Levelhistorikk (til grafen i Statistikk)
function Data:AddHistoryPoint(pid, char, t, level, played)
  local p = ns:GetPerson(pid, true)
  local c = p.chars[char]
  if not c then c = { name = ns.ShortName(char) } p.chars[char] = c end
  c.hist = c.hist or {}
  for _, h in ipairs(c.hist) do
    if h.l == level then
      if t < h.t then h.t = t end
      if played and not h.p then h.p = played end
      return
    end
  end
  table.insert(c.hist, { t = t, l = level, p = played })
  table.sort(c.hist, function(a, b) return a.l < b.l end)
  while #c.hist > 80 do table.remove(c.hist, 1) end
end

Comm:Handle("LH", function(f)
  local pid, char = f[1], f[2]
  if not pid or pid == ns.pid or not char or char == "" then return end
  for _, part in ipairs(ns.Split(f[5] or "", ";")) do
    local ago, lvl, played = part:match("^(%d+):(%d+):?(%d*)$")
    if ago then Data:AddHistoryPoint(pid, char, ns.Now() - tonumber(ago), tonumber(lvl), tonumber(played)) end
  end
  ns:MarkDirty()
end)

-- Bufret data om en annen person (for de som er offline nå)
local function buildSC(pid, p)
  local c = ns:PersonChar(p) or {}
  local s = p.stats or {}
  local pv = s.prev or {}
  return Comm:Build("SC", pid, ns.Clean(p.alias or "", 20), p.main or "", c.class or "", c.race or "",
    c.level or 0, ns:PersonPlayed(p), ns.Now() - (p.lastSeen or ns.Now()),
    s.wk or "", s.wOnline or 0, s.wQuests or 0, s.wGold or 0, s.wDeaths or 0,
    s.tOnline or 0, s.tQuests or 0, s.tGold or 0, s.tDeaths or 0,
    pv.wk or "", pv.Online or 0, pv.Quests or 0, pv.Gold or 0, pv.Deaths or 0)
end

Comm:Handle("SC", function(f)
  local pid = f[1]
  if not pid or pid == ns.pid then return end
  local lastSeen = ago2t(f[8])
  local p = ns:GetPerson(pid, true)
  if p.lastSeen and p.lastSeen >= lastSeen - 5 then return end
  if ns:IsOnline(p) then return end
  if f[2] and f[2] ~= "" then p.alias = f[2] end
  local char = f[3]
  if char and char ~= "" then
    local c = p.chars[char] or {}
    p.chars[char] = c
    c.name = ns.ShortName(char)
    c.class, c.race, c.level = f[4], f[5], num(f[6]) or c.level
    -- totalt /played for personen (alts summert) legges på main når vi ikke vet mer
    local played = num(f[7])
    if played and played > ns:PersonPlayed(p) then
      c.played = (c.played or 0) + (played - ns:PersonPlayed(p))
    end
    p.main = char
    if not ns.db.roster[char] then ns.db.roster[char] = { pid = pid } end
  end
  p.lastSeen = lastSeen
  local s = p.stats or {}
  p.stats = s
  s.wk = f[9]
  s.wOnline, s.wQuests, s.wGold, s.wDeaths = num(f[10]) or 0, num(f[11]) or 0, num(f[12]) or 0, num(f[13]) or 0
  s.tOnline, s.tQuests, s.tGold, s.tDeaths = num(f[14]) or 0, num(f[15]) or 0, num(f[16]) or 0, num(f[17]) or 0
  if f[18] and f[18] ~= "" then
    s.prev = { wk = f[18], Online = num(f[19]) or 0, Quests = num(f[20]) or 0, Gold = num(f[21]) or 0, Deaths = num(f[22]) or 0 }
  end
  ns:MarkDirty()
end)

Comm:Handle("PF", function(f)
  local pid = f[1]
  if not pid or pid == ns.pid then return end
  local p = ns:GetPerson(pid, true)
  local list = {}
  for _, part in ipairs(ns.Split(f[2] or "", ";")) do
    local name, skill, max, base = part:match("^(.-):(%d+):(%d+):?(%d*)$")
    if name then list[#list + 1] = { name = name, skill = tonumber(skill), max = tonumber(max), base = tonumber(base) } end
  end
  p.profs = list
  ns:MarkDirty()
end)

local recipeParts = {}
Comm:Handle("PR", function(f)
  local pid, prof, part, total = f[1], f[2], num(f[3]), num(f[4])
  if not pid or pid == ns.pid or not prof or not part then return end
  local key = pid .. prof
  recipeParts[key] = recipeParts[key] or {}
  local ids = {}
  for _, s in ipairs(ns.Split(f[5] or "", ",")) do
    local n = tonumber(s)
    if n then ids[#ids + 1] = n end
  end
  recipeParts[key][part] = ids
  local have = 0
  for _ in pairs(recipeParts[key]) do have = have + 1 end
  if have >= (total or 1) then
    local all = {}
    for i = 1, total do
      for _, id in ipairs(recipeParts[key][i] or {}) do all[#all + 1] = id end
    end
    local p = ns:GetPerson(pid, true)
    p.recipes = p.recipes or {}
    p.recipes[prof] = all
    recipeParts[key] = nil
    ns:MarkDirty()
  end
end)

---------------------------------------------------------------------------
-- Hei / oppdagelse / synkronisering
---------------------------------------------------------------------------
-- Send hei via whisper til venner (Battle.net og vennelista) som er pålogget WoW.
-- Har de Chillan og samme gjengkode, finner vi hverandre uten felles kanal.
function Data:DiscoverFriends()
  if not ns.codeHash then return end
  local msg = Comm:Build("HI", ns.pid, Comm:MyFull(), 1, ns.VERSION)
  local targets, n = {}, 0
  local myRealm = (Comm:MyFull() or ""):match("%-(.+)$")
  local function add(name, realm)
    if not name or name == "" or ns.isSecret(name) then return end
    local full = name
    if not full:find("-") then
      realm = (realm and realm ~= "" and not ns.isSecret(realm)) and realm:gsub("%s", "") or myRealm
      if realm then full = full .. "-" .. realm end
    end
    if Comm:IsMe(full) or targets[full] then return end
    local r = ns.db.roster[full]
    if r and r.heard and (ns.Now() - r.heard) < 120 then return end
    targets[full] = true
    n = n + 1
  end
  -- Battle.net-venner som spiller WoW nå: hils via Battle.net (virker på tvers av realm/layer)
  local bnSent = 0
  pcall(function()
    local num = BNGetNumFriends and select(1, BNGetNumFriends()) or 0
    for i = 1, math.min(num or 0, 100) do
      local accounts = C_BattleNet.GetFriendNumGameAccounts(i) or 0
      for j = 1, accounts do
        local info = C_BattleNet.GetFriendGameAccountInfo(i, j)
        if info and info.clientProgram == "WoW" and info.isOnline and info.gameAccountID
          and not ns.isSecret(info.gameAccountID)
          and (not info.wowProjectID or not WOW_PROJECT_ID or info.wowProjectID == WOW_PROJECT_ID) then
          local key = "bn:" .. info.gameAccountID
          local r = ns.db.roster[key]
          if not (r and r.heard and (ns.Now() - r.heard) < 120) and bnSent < 30 then
            Comm:SendTo(key, msg, 3)
            bnSent = bnSent + 1
          end
        end
      end
    end
  end)
  -- vanlig venneliste
  pcall(function()
    local num = C_FriendList.GetNumFriends() or 0
    for i = 1, num do
      local info = C_FriendList.GetFriendInfoByIndex(i)
      if info and info.connected and info.name then add(info.name) end
    end
  end)
  local sent = 0
  for full in pairs(targets) do
    if sent >= 25 then break end
    Comm:SendTo(full, msg, 3)
    sent = sent + 1
  end
end

function Data:Hello()
  if not ns.codeHash then return end
  local msg = Comm:Build("HI", ns.pid, Comm:MyFull(), 1, ns.VERSION)
  Comm:Broadcast(msg, 1)
  if ns.S(IsInGuild) then Comm:SendScope(msg, "GUILD", 2) end
  if ns.S(IsInRaid) then Comm:SendScope(msg, "RAID", 2)
  elseif ns.S(IsInGroup) then Comm:SendScope(msg, "PARTY", 2) end
  C_Timer.After(5, function() Data:DiscoverFriends() end)
  -- venner vi tidligere bare har nådd via whisper (annen backend-realm)
  local t, n = ns.Now(), 0
  for char, r in pairs(ns.db.roster) do
    if char:sub(1, 3) ~= "bn:" and r.whisper and (t - r.whisper) < 14 * 86400 and not (r.chan and r.chan > r.whisper) and n < 20 then
      Comm:SendTo(char, msg, 3)
      n = n + 1
    end
  end
end

function Data:AddManual(name)
  name = ns.Clean(name or "", 48)
  if name == "" then return end
  if not name:find("-") then
    local realm = (Comm:MyFull() or ""):match("%-(.+)$")
    if realm then name = name .. "-" .. realm end
  end
  ns.db.roster[name] = ns.db.roster[name] or {}
  ns.db.roster[name].whisper = ns.Now()
  Comm:SendTo(name, Comm:Build("HI", ns.pid, Comm:MyFull(), 1, ns.VERSION), 1)
  ns.Print("Sendte hei til " .. name .. ". Har de addonen og samme gjengkode, dukker de opp om litt.")
end

local function iAmGossiper()
  local mine = ns.pid
  for pid, p in pairs(ns.db.people) do
    if pid ~= ns.pid and ns:IsOnline(p) and pid < mine then return false end
  end
  return true
end

-- Svar samme vei som spørsmålet kom (kanal-svar går bare på kanalen, ikke ut til alle via whisper)
local function replyTo(sender, channel, msg, prio)
  if channel == "WHISPER" then Comm:SendTo(sender, msg, prio) else Comm:SendChannel(msg, prio) end
end

-- Si fra én gang per økt hvis en venn har nyere versjon av Chillan?
local updateNoticeShown = false
function Data:CheckVersion(theirVersion, pid)
  if updateNoticeShown or not theirVersion or theirVersion == "" then return end
  if ns.VERSION:find("dev", 1, true) then return end
  if ns.NewerVersion(theirVersion, ns.VERSION) then
    updateNoticeShown = true
    local p = ns:GetPerson(pid)
    ns.Print("Ny versjon tilgjengelig: " .. theirVersion .. " (du har " .. ns.VERSION .. "). Oppdater i WowUp.")
    ns:Fire("TOAST", { kind = "info", sticky = true, title = "Ny versjon av Chillan? (" .. theirVersion .. ")",
      text = (p and (ns:PersonFirst(p) .. " har den allerede · ") or "") .. "oppdater i WowUp" })
  end
end

Comm:Handle("HI", function(f, sender, channel)
  local pid = f[1]
  if not pid or pid == ns.pid then return end
  local known = ns.db.people[pid]
  local wasOnline = known and ns:IsOnline(known)
  -- ny eller nettopp pålogget: svar også direkte, i tilfelle han ikke hører kanalen ennå
  if not wasOnline and channel ~= "WHISPER" then
    Comm:SendTo(sender, ns.Tracker:BuildST(), 1)
  end
  -- og fortell ham hvem andre som er online, så han kan hilse på dem direkte
  if not wasOnline and iAmGossiper() then
    local n = 0
    for opid, op in pairs(ns.db.people) do
      if opid ~= ns.pid and opid ~= pid and op.main and ns:IsOnline(op) and n < 15 then
        local name = ns.WhisperName(op)
        if name then Comm:SendTo(sender, Comm:Build("RO", opid, name), 2) end
        n = n + 1
      end
    end
  end
  Data:CheckVersion(f[4], pid)
  local r = ns.db.roster[sender]
  if r then r.pid = pid end
  if channel == "GUILD" or channel == "PARTY" or channel == "RAID" then channel = "WHISPER" end
  replyTo(sender, channel, ns.Tracker:BuildST(), 1)
  -- ny sone/layer hos en vi allerede har utvekslet alt med: status holder
  Data.sentTo = Data.sentTo or {}
  if f[3] == "0" and Data.sentTo[pid] then return end
  Data.sentTo[pid] = true
  replyTo(sender, channel, ns.Tracker:BuildSS(), 2)
  replyTo(sender, channel, ns.Tracker:BuildS2(), 3)
  replyTo(sender, channel, ns.Tracker:BuildS3(), 3)
  ns.Ach:SendList(sender)
  ns.Tracker:SendHistory(sender)
  if iAmGossiper() then
    local n = 0
    for opid, p in pairs(ns.db.people) do
      if opid ~= ns.pid and opid ~= pid and not ns:IsOnline(p) and p.main and n < 15 then
        Comm:SendTo(sender, buildSC(opid, p), 3)
        n = n + 1
      end
    end
  end
end)

Comm:Handle("RO", function(f)
  local pid, char = f[1], f[2]
  if not char or char == "" or pid == ns.pid or Comm:IsMe(char) then return end
  local r = ns.db.roster[char]
  if r and r.heard and (ns.Now() - r.heard) < 120 then return end
  r = r or {}
  ns.db.roster[char] = r
  r.pid = pid
  r.whisper = ns.Now()
  Comm:SendTo(char, Comm:Build("HI", ns.pid, Comm:MyFull(), 1, ns.VERSION), 2)
end)

function Data:OnPeerOnline(pid, sender)
  if syncedFrom then return end
  syncedFrom = pid
  local since = 0
  for _, it in ipairs(ns.db.feed) do if it.t > since then since = it.t end end
  for _, it in ipairs(ns.db.chat) do if it.t > since then since = it.t end end
  Comm:SendTo(sender, Comm:Build("SQ", ns.pid, ns.Now() - since), 2)
end

Comm:Handle("SQ", function(f, sender)
  local agoSince = num(f[2]) or 999999999
  local since = ns.Now() - agoSince
  local function after(list, cap)
    local out = {}
    for i = #list, 1, -1 do
      if list[i].t > since then table.insert(out, 1, list[i]) end
      if #out >= cap then break end
    end
    return out
  end
  for _, it in ipairs(after(ns.db.chat, 25)) do
    Comm:SendTo(sender, Comm:Build("CH", it.id, it.pid, it.char, ns.Now() - it.t, it.text), 3, true)
  end
  for _, it in ipairs(after(ns.db.feed, 25)) do
    Comm:SendTo(sender, Comm:Build("EV", it.id, it.pid, it.char, it.kind, ns.Now() - it.t, it.a or "", it.b or "", it.c or "", it.d or ""), 3)
  end
  for _, post in pairs(ns.db.mats) do
    Comm:SendTo(sender, Data:BuildMT(post), 3, true)
  end
  for _, poll in ipairs(ns.db.polls) do
    if ns.Now() - poll.t < 86400 then
      Comm:SendTo(sender, Data:BuildPO(poll), 3, true)
      for vpid, idx in pairs(poll.votes) do Comm:SendTo(sender, Comm:Build("PV", poll.id, vpid, idx), 3) end
    end
  end
  for _, ev in ipairs(ns.db.events) do
    Comm:SendTo(sender, Data:BuildAV(ev), 3, true)
    for rpid, st in pairs(ev.rsvp) do Comm:SendTo(sender, Comm:Build("AR", ev.id, rpid, st), 3) end
  end
  local n = 0
  for _, e in pairs(ns.db.enemies) do
    if n < 20 then
      Comm:SendTo(sender, Comm:Build("EN", e.id or "", ns.Now() - (e.t or ns.Now()), e.name, e.note or "", e.by or "", e.byChar or ""), 3, true)
      n = n + 1
    end
  end
end)

---------------------------------------------------------------------------
-- Feed-hendelser
---------------------------------------------------------------------------
local FIRST_LEVELS = { [10] = true, [20] = true, [30] = true, [40] = true, [50] = true, [60] = true }

local function setFirst(key, pid, char, t)
  local cur = ns.db.firsts[key]
  if not cur or t < cur.t then
    ns.db.firsts[key] = { pid = pid, char = char, t = t }
    return true
  end
  return false
end

function Data:ApplyEvent(id, pid, char, kind, t, a, b, c, d)
  for _, it in ipairs(ns.db.feed) do if it.id == id then return end end
  local item = { id = id, pid = pid, char = char, kind = kind, t = t, a = a, b = b, c = c, d = d }
  local p = ns:GetPerson(pid, true)
  if not p.main then
    p.main = char
    p.chars[char] = p.chars[char] or { name = ns.ShortName(char) }
  end
  if kind == "DING" then
    local lvl = num(a)
    local ch = p.chars[char]
    if ch and lvl and lvl > (ch.level or 0) then ch.level = lvl end
    if lvl then Data:AddHistoryPoint(pid, char, t, lvl, num(b)) end
    if lvl and FIRST_LEVELS[lvl] then item.first = setFirst("L" .. lvl, pid, char, t) end
    -- plass i gjengen til dette levelet
    local place = 0
    for _, op in pairs(ns.db.people) do
      if ns:PersonMaxLevel(op) >= (lvl or 0) then place = place + 1 end
    end
    item.place = math.max(1, place)
  elseif kind == "MOUNT" then
    item.first = setFirst("MOUNT", pid, char, t)
  elseif kind == "LOOT" then
    if (num(b) or 0) >= 4 then item.first = setFirst("EPIC", pid, char, t) end
  elseif kind == "DUNGEON" then
    if a and a ~= "" then item.first = setFirst("DG:" .. a, pid, char, t) end
  elseif kind == "ACH" then
    if pid ~= ns.pid then
      p.ach = p.ach or {}
      p.ach[a] = t
    end
    -- gull og legendariske achievements havner i krøniken
    if b == "G" or b == "L" then
      local def = ns.Ach and ns.Ach.byId[a]
      ns.Extras:AddChronicle("ACH:" .. tostring(a) .. ":" .. tostring(pid), t, pid, char,
        "låste opp «" .. (def and def.name or tostring(a)) .. "» (" .. (b == "L" and "legendarisk" or "gull") .. ")",
        "Trophy", b == "L" and "F0A8D0" or "E0C068")
    end
  elseif kind == "DEAD" then
    if not p.deathAt or t > p.deathAt then p.deathAt, p.deathZone = t, a end
  end
  ns.PushCapped(ns.db.feed, item, 150)
  table.sort(ns.db.feed, function(x, y) return x.t < y.t end)
  if fresh(t) then
    if pid ~= ns.pid then ns:Fire("ACTIVITY", ns.FeedLine(item, false)) end
    ns:Fire("FEEDEVENT", ns.FeedShort(item), item)
    -- egne dings og dødsfall får ingen popup hos deg selv (bare achievements)
    if kind == "DING" and pid ~= ns.pid then
      ns:Fire("DING", item)
      ns.Sound("ding")
    elseif kind == "DEAD" and pid ~= ns.pid then
      ns:Fire("DING", item)
      ns.Sound("dead")
    elseif kind == "ACH" then
      -- bronse vises bare i chatten, sølv og oppover får popup
      if b == "S" or b == "G" or b == "L" then
        ns:Fire("DING", item)
        ns.Sound("ding")
      end
    elseif kind == "SOS" then
      ns:Fire("SOS", item)
      ns.Sound("sos")
    elseif kind == "ENSEEN" then
      ns:Fire("TOAST", { kind = "enemy", pid = pid,
        title = "Fiende spottet: " .. tostring(a),
        text = ns:PersonLabel(p) .. " ser vedkommende i " .. tostring(b) })
    elseif kind == "MOUNT" and item.first then
      ns:Fire("TOAST", { kind = "star", pid = pid, title = ns:PersonLabel(p) .. " fikk mount!", text = "Først i gjengen" })
    end
  end
  ns:MarkDirty()
end

Comm:Handle("EV", function(f)
  local id = f[1]
  if Comm:Seen(id) then return end
  Data:ApplyEvent(id, f[2], f[3], f[4], ago2t(f[5]), f[6], f[7], f[8], f[9])
end)

---------------------------------------------------------------------------
-- Gjengchat
---------------------------------------------------------------------------
local function addChat(id, pid, char, t, text)
  for i = #ns.db.chat, math.max(1, #ns.db.chat - 60), -1 do
    if ns.db.chat[i].id == id then return end
  end
  local item = { id = id, pid = pid, char = char, t = t, text = text }
  if pid ~= ns.pid and ns.MentionsMe(text) then item.mention = true end
  ns.PushCapped(ns.db.chat, item, 300)
  table.sort(ns.db.chat, function(x, y) return x.t < y.t end)
  ns.chatRev = (ns.chatRev or 0) + 1
  ns:Fire("CHAT", item)
  if item.mention and fresh(t) and not quiet() then
    local p = ns:GetPerson(pid) or {}
    if ns.db.settings.mentionSound then ns.Sound("online") end
    ns:Fire("TOAST", { kind = "mention", pid = pid, char = char,
      title = ns:PersonLabel(p, char) .. " nevnte deg", text = ns.Clean(text, 90) })
  end
  ns:MarkDirty()
end

function Data:SendChat(text)
  text = ns.Clean(text, 200)
  if text == "" or not ns.codeHash then return end
  local id = Comm:NewId()
  Comm:Seen(id)
  addChat(id, ns.pid, Comm:MyFull(), ns.Now(), text)
  ns.Cnt("chatMsgs")
  ns.CntDay("chatDay")
  ns.CntMax("bestDayChat", (ns.db.cnt.chatDay or {})[date("%Y-%m-%d")] or 0)
  Comm:Broadcast(Comm:Build("CH", id, ns.pid, Comm:MyFull(), 0, text), 1, true)
end

Comm:Handle("CH", function(f)
  if Comm:Seen(f[1]) then return end
  local p = ns:GetPerson(f[2], true)
  if not p.main and f[3] ~= "" then p.main = f[3] p.chars[f[3]] = p.chars[f[3]] or { name = ns.ShortName(f[3]) } end
  addChat(f[1], f[2], f[3], ago2t(f[4]), f[5] or "")
end)

---------------------------------------------------------------------------
-- Gratulasjoner og reaksjoner på dings
---------------------------------------------------------------------------
ns.REACTIONS = { "Gratulerer!", "GZ!", "Endelig!", "Gay" }
ns.REACTIONS_DEAD = { "Hahaha!", "RIP", "Noob!", "F", "Gay" }

ns.REACTIONS_ACH = { "Gratulerer!", "GZ!", "Imponerende!", "Gay" }

function ns.ReactionText(item, idx)
  local list = ns.REACTIONS
  if item and item.kind == "DEAD" then list = ns.REACTIONS_DEAD
  elseif item and item.kind == "ACH" then list = ns.REACTIONS_ACH end
  return list[idx] or list[1]
end

local function findFeed(id)
  for i = #ns.db.feed, 1, -1 do
    if ns.db.feed[i].id == id then return ns.db.feed[i] end
  end
end

local reactBuffer = {}
local function addReaction(item, pid, char, idx)
  item.reacts = item.reacts or {}
  for _, r in ipairs(item.reacts) do if r.pid == pid then return false end end
  table.insert(item.reacts, { pid = pid, char = char, idx = idx })
  return true
end

function Data:React(item, idx)
  if not item or item.pid == ns.pid then return end
  if not addReaction(item, ns.pid, Comm:MyFull(), idx) then return end
  if item.kind == "DEAD" then
    if idx == 4 then ns.Cnt("fGiven") elseif idx == 1 or idx == 3 then ns.Cnt("laughsGiven") end
  else
    ns.Cnt("gratsGiven")
  end
  ns:Fire("REACTION", item, ns:GetPerson(ns.pid), Comm:MyFull(), idx)
  Comm:Broadcast(Comm:Build("RX", item.id, ns.pid, Comm:MyFull(), idx), 1)
  ns:MarkDirty()
end

Comm:Handle("RX", function(f)
  local item = findFeed(f[1] or "")
  if not item then return end
  local idx = num(f[4]) or 1
  if not addReaction(item, f[2], f[3], idx) then return end
  local rp = ns:GetPerson(f[2], true)
  local target = item.pid == ns.pid and "deg" or ns:PersonLabel(ns:GetPerson(item.pid) or {}, item.char)
  ns:Fire("REACTION", item, rp, f[3], idx)
  if item.pid == ns.pid then
    if item.kind == "DEAD" then
      if idx == 1 or idx == 3 then ns.Cnt("laughedAt") end
    else
      ns.Cnt("gratsGot")
      if item.kind == "DING" then ns.CntMax("maxGratsOneDing", #item.reacts) end
    end
    -- samle gratulasjonene til ett varsel
    reactBuffer[#reactBuffer + 1] = ns.FirstName(f[3])
    if #reactBuffer == 1 then
      C_Timer.After(4, function()
        local names = reactBuffer
        reactBuffer = {}
        local who = #names == 1 and names[1] or (names[1] .. " og " .. (#names - 1) .. " andre")
        if item.kind == "DEAD" then
          ns:Fire("TOAST", { kind = "dead", title = who .. " ler av deg", text = "Du døde i " .. tostring(item.a or "?") })
        else
          local what = "Med level " .. tostring(item.a)
          if item.kind == "ACH" then
            local d = ns.Ach and ns.Ach.byId[item.a]
            what = "Med «" .. (d and d.name or "achievement") .. "»"
          end
          ns:Fire("TOAST", { kind = "star", title = who .. " gratulerte deg!", text = what })
        end
        ns.Sound("online")
      end)
    end
  end
  ns:MarkDirty()
end)

---------------------------------------------------------------------------
-- Mats-tavle ("trenger 20 Copper Bar")
---------------------------------------------------------------------------
function Data:BuildMT(post)
  return Comm:Build("MT", post.id, post.pid, post.char, ns.Now() - post.t, ns.Clean(post.text, 60), ns.Clean(post.note or "", 60))
end

function Data:PostMats(text, note)
  text = ns.Clean(text, 60)
  if text == "" then return false end
  local post = { id = Comm:NewId(), pid = ns.pid, char = Comm:MyFull(), t = ns.Now(), text = text, note = ns.Clean(note or "", 60) }
  ns.db.mats[post.id] = post
  ns.Cnt("matsPosted")
  Comm:Broadcast(self:BuildMT(post), 1, true)
  ns:MarkDirty()
  return true
end

function Data:RemoveMats(id)
  ns.db.mats[id] = nil
  Comm:Broadcast(Comm:Build("MX", id), 1)
  ns:MarkDirty()
end

function Data:OfferMats(post)
  ns.Cnt("matsOffered")
  local p = ns:GetPerson(post.pid)
  local target = (p and p.live and p.live.char) or post.char
  Comm:SendTo(target, Comm:Build("MH", ns.pid, Comm:MyFull(), post.id), 1)
  ns.Print("Sa fra til " .. ns.FirstName(post.char) .. " at du har " .. post.text .. ".")
end

Comm:Handle("MT", function(f)
  local id = f[1]
  if not id or id == "" then return end
  local isNew = ns.db.mats[id] == nil
  ns.db.mats[id] = { id = id, pid = f[2], char = f[3], t = ago2t(f[4]), text = f[5] or "", note = f[6] or "" }
  ns:MarkDirty()
end)

Comm:Handle("MX", function(f)
  ns.db.mats[f[1] or ""] = nil
  ns:MarkDirty()
end)

Comm:Handle("MH", function(f, sender)
  local post = ns.db.mats[f[3] or ""]
  ns:Fire("TOAST", { kind = "craft", pid = f[1], char = f[2] ~= "" and f[2] or sender, sticky = true,
    title = ns:PersonLabel(ns:GetPerson(f[1], true), f[2]) .. " har det du trenger",
    text = post and post.text or "Mats" })
  ns.Sound("online")
end)

function Data:ExpireMats()
  for id, post in pairs(ns.db.mats) do
    if ns.Now() - post.t > 7 * 86400 then ns.db.mats[id] = nil end
  end
end

---------------------------------------------------------------------------
-- Avstemninger
---------------------------------------------------------------------------
function Data:BuildPO(poll)
  return Comm:Build("PO", poll.id, poll.pid, ns.Now() - poll.t, ns.Clean(poll.q, 60), table.concat(poll.opts, ";"))
end

local function findPoll(id)
  for _, poll in ipairs(ns.db.polls) do if poll.id == id then return poll end end
end

function Data:CreatePoll(q, optsText)
  q = ns.Clean(q, 60)
  local opts = {}
  for _, o in ipairs(ns.Split(optsText or "", ";")) do
    o = ns.Clean(o, 30)
    if o ~= "" and #opts < 4 then opts[#opts + 1] = o end
  end
  if q == "" or #opts < 2 then return false end
  local poll = { id = Comm:NewId(), pid = ns.pid, t = ns.Now(), q = q, opts = opts, votes = {} }
  ns.Cnt("pollsCreated")
  ns.PushCapped(ns.db.polls, poll, 5)
  Comm:Broadcast(self:BuildPO(poll), 1, true)
  ns:MarkDirty()
  return true
end

function Data:Vote(poll, idx)
  if not poll.votes[ns.pid] then ns.Cnt("votes") end
  poll.votes[ns.pid] = idx
  Comm:Broadcast(Comm:Build("PV", poll.id, ns.pid, idx), 1)
  ns:MarkDirty()
end

function Data:ActivePoll()
  local best
  for _, poll in ipairs(ns.db.polls) do
    if ns.Now() - poll.t < 86400 and (not best or poll.t > best.t) then best = poll end
  end
  return best
end

Comm:Handle("PO", function(f)
  if findPoll(f[1]) then return end
  local opts = {}
  for _, o in ipairs(ns.Split(f[5] or "", ";")) do if o ~= "" then opts[#opts + 1] = o end end
  ns.PushCapped(ns.db.polls, { id = f[1], pid = f[2], t = ago2t(f[3]), q = f[4], opts = opts, votes = {} }, 5)
  ns:MarkDirty()
end)

Comm:Handle("PV", function(f)
  local poll = findPoll(f[1])
  if poll and f[2] then poll.votes[f[2]] = num(f[3]) ns:MarkDirty() end
end)

---------------------------------------------------------------------------
-- Avtaler (f.eks. "Scarlet Monastery torsdag 20:00")
---------------------------------------------------------------------------
function Data:BuildAV(ev)
  return Comm:Build("AV", ev.id, ev.pid, ns.Now() - ev.t, ns.Clean(ev.title, 50), ns.Clean(ev.when, 30))
end

local function findEvent(id)
  for _, ev in ipairs(ns.db.events) do if ev.id == id then return ev end end
end

function Data:CreateEvent(title, when)
  title, when = ns.Clean(title, 50), ns.Clean(when, 30)
  if title == "" then return false end
  local ev = { id = Comm:NewId(), pid = ns.pid, t = ns.Now(), title = title, when = when, rsvp = { [ns.pid] = 1 } }
  ns.Cnt("eventsCreated")
  ns.PushCapped(ns.db.events, ev, 10)
  Comm:Broadcast(self:BuildAV(ev), 1, true)
  Comm:Broadcast(Comm:Build("AR", ev.id, ns.pid, 1), 2)
  ns:MarkDirty()
  return true
end

function Data:RSVP(ev, status)
  if status == 1 and ev.rsvp[ns.pid] ~= 1 then ns.Cnt("rsvpYes") end
  ev.rsvp[ns.pid] = status
  Comm:Broadcast(Comm:Build("AR", ev.id, ns.pid, status), 1)
  ns:MarkDirty()
end

function Data:RemoveEvent(ev)
  for i, e in ipairs(ns.db.events) do
    if e.id == ev.id then table.remove(ns.db.events, i) break end
  end
  Comm:Broadcast(Comm:Build("AX", ev.id), 1)
  ns:MarkDirty()
end

Comm:Handle("AV", function(f)
  if findEvent(f[1]) then return end
  ns.PushCapped(ns.db.events, { id = f[1], pid = f[2], t = ago2t(f[3]), title = f[4], when = f[5], rsvp = {} }, 10)
  ns:MarkDirty()
end)

Comm:Handle("AR", function(f)
  local ev = findEvent(f[1])
  if ev and f[2] then ev.rsvp[f[2]] = num(f[3]) ns:MarkDirty() end
end)

Comm:Handle("AX", function(f)
  for i, e in ipairs(ns.db.events) do
    if e.id == f[1] then table.remove(ns.db.events, i) break end
  end
  ns:MarkDirty()
end)

function Data:ExpireEvents()
  for i = #ns.db.events, 1, -1 do
    if ns.Now() - ns.db.events[i].t > 10 * 86400 then table.remove(ns.db.events, i) end
  end
end

---------------------------------------------------------------------------
-- SOS
---------------------------------------------------------------------------
function Data:SOS()
  if not ns.codeHash then ns.Print("Du må være med i en gjeng først.") return end
  local loc = ns.Tracker:Location()
  local zone = loc.zone
  if loc.sub and loc.sub ~= "" and not loc.inInst then zone = loc.sub .. ", " .. loc.zone end
  ns.Tracker:Event("SOS", ns.Clean(zone, 40), loc.mapID or "",
    loc.x and math.floor(loc.x * 1000) or "", loc.y and math.floor(loc.y * 1000) or "")
  ns.session.sos = (ns.session.sos or 0) + 1
  ns.Cnt("sosSent")
  ns.CntDay("sosDay")
  ns.CntMax("bestDaySos", (ns.db.cnt.sosDay or {})[date("%Y-%m-%d")] or 0)
  ns.Print("SOS sendt til gjengen.")
end

function Data:AnswerSOS(item)
  ns.Cnt("sosAnswered")
  local p = ns:GetPerson(item.pid)
  local target = (p and p.live and p.live.char) or item.char
  Comm:SendTo(target, Comm:Build("RS", ns.pid, Comm:MyFull()), 1)
end

Comm:Handle("RS", function(f)
  local p = ns:GetPerson(f[1], true)
  ns:Fire("TOAST", { kind = "sos", pid = f[1], title = ns:PersonLabel(p) .. " er på vei!", text = "Hold ut litt til" })
end)

---------------------------------------------------------------------------
-- Fiendelogg
---------------------------------------------------------------------------
function Data:AddEnemy(name, note, silent)
  name = ns.Clean(name or "", 48)
  if name == "" then return false end
  local key = ns.ShortName(name):lower()
  local e = { id = Comm:NewId(), name = ns.ShortName(name), note = ns.Clean(note or "", 60), by = ns.pid, byChar = Comm:MyFull(), t = ns.Now() }
  ns.db.enemies[key] = e
  if not silent then
    ns.Cnt("enemiesTagged")
    Comm:Broadcast(Comm:Build("EN", e.id, 0, e.name, e.note, e.by, e.byChar), 1, true)
  end
  ns:MarkDirty()
  return true
end

function Data:RemoveEnemy(key)
  local e = ns.db.enemies[key]
  if not e then return end
  ns.db.enemies[key] = nil
  Comm:Broadcast(Comm:Build("EX", e.name), 1)
  ns:MarkDirty()
end

Comm:Handle("EN", function(f)
  local name = f[3]
  if not name or name == "" then return end
  local key = name:lower()
  if ns.db.enemies[key] then return end
  ns.db.enemies[key] = { id = f[1], t = ago2t(f[2]), name = name, note = f[4], by = f[5], byChar = f[6] }
  ns:MarkDirty()
end)

Comm:Handle("EX", function(f)
  if f[1] then ns.db.enemies[f[1]:lower()] = nil ns:MarkDirty() end
end)

local enemyAlerted = {}
local function checkUnit(unit)
  if not ns.codeHash or not next(ns.db.enemies) then return end
  if not ns.S(UnitIsPlayer, unit) then return end
  if not ns.S(UnitIsEnemy, "player", unit) then return end
  local name = ns.S(UnitName, unit)
  if not name then return end
  local key = name:lower()
  local e = ns.db.enemies[key]
  if not e then return end
  if enemyAlerted[key] and ns.Now() - enemyAlerted[key] < 300 then return end
  enemyAlerted[key] = ns.Now()
  local zone = ns.S(GetRealZoneText) or ""
  ns.Cnt("enemySeen")
  ns:Fire("TOAST", { kind = "enemy", title = "Fiende i nærheten: " .. e.name, text = e.note ~= "" and e.note or "Fra fiendeloggen" })
  ns.Sound("sos")
  ns.Tracker:Event("ENSEEN", e.name, ns.Clean(zone, 30))
end

ns:On("PLAYER_TARGET_CHANGED", function() checkUnit("target") end)
ns:On("UPDATE_MOUSEOVER_UNIT", function() checkUnit("mouseover") end)
ns:On("NAME_PLATE_UNIT_ADDED", function(unit) if unit and not ns.isSecret(unit) then checkUnit(unit) end end)

---------------------------------------------------------------------------
-- Be om craft
---------------------------------------------------------------------------
function Data:RequestCraft(pid, text)
  local p = ns:GetPerson(pid)
  if not p then return end
  local target = (p.live and p.live.char) or p.main
  if not target then return end
  Comm:SendTo(target, Comm:Build("CR", ns.pid, Comm:MyFull(), ns.Clean(text or "", 80)), 1, true)
  ns.Print("Forespørsel sendt til " .. ns:PersonFirst(p) .. ".")
end

Comm:Handle("CR", function(f, sender)
  local p = ns:GetPerson(f[1], true)
  ns:Fire("TOAST", { kind = "craft", pid = f[1], char = f[2] ~= "" and f[2] or sender, sticky = true,
    title = ns:PersonLabel(p) .. " ber om craft", text = (f[3] and f[3] ~= "") and f[3] or "Ta kontakt i spillet" })
  ns.Sound("online")
end)

---------------------------------------------------------------------------
-- Ukens utfordring og vinner
---------------------------------------------------------------------------
ns.CHALLENGES = {
  { key = "Levels", label = "Flest levels", fmt = function(v) return tostring(math.floor(v)) .. " levels" end },
  { key = "Quests", label = "Flest quests", fmt = function(v) return tostring(math.floor(v)) .. " quests" end },
  { key = "Gold", label = "Mest gull tjent", fmt = function(v) return ns.Money(v) end },
  { key = "Kills", label = "Flest PvP-kills", fmt = function(v) return tostring(math.floor(v)) .. " kills" end },
}

-- Har noen i gjengen PvP-kills registrert? (ellers byttes den uka ut med levels)
local function anyKills()
  for _, p in pairs(ns.db.people) do
    if ((p.stats or {}).tKills or 0) > 0 then return true end
  end
  return false
end

function Data:ChallengeFor(weekKey)
  local wn = tonumber((weekKey or ns.WeekKey()):match("%-(%d+)$")) or 0
  local ch = ns.CHALLENGES[(wn % #ns.CHALLENGES) + 1]
  if ch.key == "Kills" and not anyKills() then ch = ns.CHALLENGES[1] end
  return ch
end

function Data:CurrentLeader()
  local ch = self:ChallengeFor()
  local best, bestV = nil, 0
  for _, p in ipairs(ns:SortedPeople()) do
    local v = ns:WeekStat(p, ch.key)
    if v > bestV then best, bestV = p, v end
  end
  return ch, best, bestV
end

function Data:LastWeekWinner()
  local pwk = ns.PrevWeekKey()
  local ch = self:ChallengeFor(pwk)
  local best, bestV = nil, 0
  for _, p in ipairs(ns:SortedPeople()) do
    local s = p.stats or {}
    local v = 0
    if s.prev and s.prev.wk == pwk then v = s.prev[ch.key] or 0
    elseif s.wk == pwk then v = s["w" .. ch.key] or 0 end
    if v > bestV then best, bestV = p, v end
  end
  return ch, best, bestV, pwk
end

function Data:AnnounceWinner()
  local ch, best, v, pwk = self:LastWeekWinner()
  if not best or ns.db.announced[pwk] then return end
  ns.db.announced[pwk] = true
  ns:Fire("TOAST", { kind = "trophy", pid = best.pid, sticky = true,
    title = "Forrige ukes vinner: " .. ns:PersonLabel(best),
    text = ch.label .. " – " .. ch.fmt(v) })
end

---------------------------------------------------------------------------
-- Oppstart
---------------------------------------------------------------------------
function Data:Start()
  loginAt = GetTime()
  -- Battle.net-IDer gjelder bare én økt: glem gamle
  for key in pairs(ns.db.roster) do
    if key:sub(1, 3) == "bn:" then ns.db.roster[key] = nil end
  end
  self:ExpireMats()
  self:ExpireEvents()
  C_Timer.NewTicker(60, function()
    Data:ExpireMats()
    ns:MarkDirty()
  end)
  C_Timer.NewTicker(120, function() Data:DiscoverFriends() end)
  -- prøv å koble til gjengkanalen igjen hvis den ikke virker
  C_Timer.NewTicker(15, function() if ns.codeHash then Comm:Reconnect() end end)
  -- straks kanalen er klar: si hei der, så gjengen ser oss med en gang
  ns:Listen("CHANNEL_READY", function()
    Comm:SendChannel(Comm:Build("HI", ns.pid, Comm:MyFull(), 1, ns.VERSION), 1)
    ns.Tracker:SendStatus(1)
  end)
  C_Timer.NewTicker(60, function() Comm:GossipWhisperPeers() end)
  C_Timer.After(75, function() Data:AnnounceWinner() end)
  ns.Sync:Start()
  ns.Quests:Start()
  ns.Titles:Start()
  ns.Extras:Start()
end
