-- Chillan? Market (1.3.0): auction house prices for the gang.
--  * Scan: a full scan button on the auction house (once per 15 min, the game's limit) and a quick
--    check of the items in your bags when you open it.
--  * Price: one market value per item – the typical price of the cheapest listings, ignoring silly ones.
--  * Tooltip: "Market  12g 34s · 2h ago" (greyed when older than 3 days).
--  * Sharing: after a scan the prices that changed go to the gang quietly over a few minutes; when
--    someone logs in, one friend with newer prices sends them what they missed. Newest scan wins.
-- Works with both auction house APIs (the modern C_AuctionHouse one and the classic list one).
local ADDON, ns = ...
local Comm = ns.Comm
local M = {}
ns.Market = M

local FULL_COOLDOWN = 15 * 60
local KEEP_DAYS = 14
local STALE = 3 * 86400
local SEND_EVERY = 0.5          -- (1.4.26) seconds between price messages (one message ≈ 20 prices)
local MAX_SYNC = 6000           -- prices sent to someone logging in (all of them, in practice)
local PER_MSG = 14

local function db()
  ns.db.market = ns.db.market or {}
  return ns.db.market
end
local function on() return ns.db and ns.db.settings.market ~= false end

---------------------------------------------------------------------------
-- prices
---------------------------------------------------------------------------
-- market value from a list of { unit = copper, n = count }: the average of the cheapest 15 % of
-- the items for sale, after dropping listings far above the cheapest ones
function M.Value(listings)
  if #listings == 0 then return nil end
  table.sort(listings, function(a, b) return a.unit < b.unit end)
  local total = 0
  for _, l in ipairs(listings) do total = total + l.n end
  local want = math.max(1, math.floor(total * 0.15 + 0.5))
  local sum, got, first = 0, 0, listings[1].unit
  for _, l in ipairs(listings) do
    if got >= want then break end
    if l.unit > first * 3 and got > 0 then break end   -- a silly listing, stop here
    local take = math.min(l.n, want - got)
    sum = sum + l.unit * take
    got = got + take
  end
  return math.floor(sum / math.max(1, got) + 0.5)
end

function M:Set(id, value, t, by)
  if not id or not value or value <= 0 then return false end
  local d = db()
  local old = d[id]
  if old and (old.t or 0) >= t then return false end
  d[id] = { v = value, t = t, by = by, p = old and old.v or nil }
  return true, old
end

function M:Get(id)
  return id and db()[id]
end

function M:Prune()
  local cutoff = ns.Now() - KEEP_DAYS * 86400
  for id, e in pairs(db()) do if (e.t or 0) < cutoff then db()[id] = nil end end
end

-- (1.4.26) the newest full scan whose prices we hold (our own, or one received nearly complete).
-- The newest single price was a bad mark: one hovered item from today made it look like we had
-- everything, so a friend logging in was never sent the scan they missed
function M:FullT()
  return math.max(ns.db.marketFullT or 0, ns.db.marketFullAt or 0)
end
local function noteFull(t)
  if t and t > (ns.db.marketFullT or 0) then ns.db.marketFullT = t end
end
-- the newest scan time we have
function M:Latest()
  local best = 0
  for _, e in pairs(db()) do if (e.t or 0) > best then best = e.t end end
  return best
end

---------------------------------------------------------------------------
-- scanning
---------------------------------------------------------------------------
local modern = function() return C_AuctionHouse and C_AuctionHouse.ReplicateItems and true or false end
local classic = function() return QueryAuctionItems and GetAuctionItemInfo and true or false end
M.status = ""

function M:CanFull()
  local last = ns.db.marketFullAt or 0
  return (ns.Now() - last) >= FULL_COOLDOWN, FULL_COOLDOWN - (ns.Now() - last)
end

local function itemIdOf(link)
  return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- turn raw rows ({ id, buyout, count }) into per-item listing lists (the classic full scan)
local function digest(rows, done)
  local byId, i = {}, 0
  local function step()
    local stop = math.min(#rows, i + 2000)
    for k = i + 1, stop do
      local r = rows[k]
      if r.id and r.buyout and r.buyout > 0 and (r.count or 0) > 0 then
        byId[r.id] = byId[r.id] or {}
        table.insert(byId[r.id], { unit = r.buyout / r.count, n = r.count })
      end
    end
    i = stop
    if i < #rows then C_Timer.After(0, step) return end
    M.storeScan(byId, done)
  end
  step()
end
-- per-item listing lists → stored prices, a slice of items per frame
function M.storeScan(byId, done, value)
  local ids = {}
  for id in pairs(byId) do ids[#ids + 1] = id end
  local t, changed, n, all, i = ns.Now(), {}, 0, {}, 0
  local function step()
    local stop = math.min(#ids, i + 1500)
    for k = i + 1, stop do
      local id = ids[k]
      local v = value and value(byId[id]) or M.Value(byId[id])
      local ok, old = M:Set(id, v, t, ns.pid)
      if ok then
        n = n + 1
        all[#all + 1] = id
        if not old or math.abs(v - old.v) > old.v * 0.05 then changed[#changed + 1] = id end
      end
    end
    i = stop
    if i < #ids then C_Timer.After(0, step) return end
    M.lastAll = all
    M.status = "Scan done: " .. ns.Num(n) .. " prices"
    ns:Fire("MARKET")
    if done then done(n, changed) end
  end
  step()
end

-- full scan: every listing at once
function M:FullScan()
  if not on() then return end
  local can, left = self:CanFull()
  if self.scanning then return end
  if not can then
    -- (1.4.27) between full scans: read the auction house page by page instead (lowest price per item)
    if modern() and C_AuctionHouse.SendBrowseQuery then return self:BrowseScan(left) end
    M.status = "Next full scan in " .. ns.Duration(left)
    ns:Fire("MARKET")
    return
  end
  self.scanning = true
  ns.db.marketFullAt = ns.Now()
  M.status = "Scanning the auction house …"
  ns:Fire("MARKET")
  if modern() then
    self.waitReplicate = true
    pcall(C_AuctionHouse.ReplicateItems)
    -- the list arrives with REPLICATE_ITEM_LIST_UPDATE (see below); give up after 60 s
    C_Timer.After(60, function()
      if M.waitReplicate then
        M.waitReplicate = nil M.scanning = nil
        -- no answer to the full scan: read page by page instead
        if C_AuctionHouse.SendBrowseQuery and M.ahOpen then M:BrowseScan(0) return end
        M.status = "The auction house didn't answer – try again later" ns:Fire("MARKET")
      end
    end)
  elseif classic() then
    local okQ, canQ, canAll = pcall(CanSendAuctionQuery)
    if okQ and canAll then
      self.waitClassic = "all"
      pcall(QueryAuctionItems, "", nil, nil, 0, nil, nil, true, false, nil)
    else
      self.scanning = nil
      ns.db.marketFullAt = 0
      M.status = "The full scan isn't ready yet – try in a minute"
      ns:Fire("MARKET")
    end
  else
    self.scanning = nil
    M.status = "This auction house can't be scanned by addons"
    ns:Fire("MARKET")
  end
end

local function afterScan(n, changed)
  M.scanning = nil
  ns.db.marketFullT = ns.Now()
  ns:Fire("MARKET")
  -- (1.4.26) the whole scan goes to the gang, not only prices that moved 5 % (an unchanged price
  -- still has a fresh date). "MS" tells them how many are coming, so they know when they have it all
  local all = M.lastAll or changed
  Comm:Broadcast(Comm:Build("MS", n, #all), 2)
  ns.Cnt("marketScans")
  if #all > 0 then M:Share(all) end
  ns.Print("Market: " .. ns.Num(n) .. " prices updated – sharing them with the gang (about " .. ns.Duration(math.max(60, math.ceil(#all / 18 * SEND_EVERY) + 5)) .. ").")
end

-- (1.4.27) the replicate list is read in slices of 2000 listings per frame straight into per-item
-- lists (no copy of every row first), so a 60 000-listing house no longer freezes the game. A full
-- scan started by another addon (Naowh's Scan Prices, Auctionator…) is captured too, since it
-- uses the same once-per-15-minutes list
local READ_SLICE = 2000
local function readReplicate()
  local okN, total = pcall(C_AuctionHouse.GetNumReplicateItems)
  total = okN and total or 0
  if total == 0 then
    M.scanning = nil
    M.status = "The auction house returned no listings – try again in a moment"
    ns:Fire("MARKET")
    return
  end
  local byId, i, lastPct = {}, 0, -1
  local rowsN = 0
  local function step()
    local stop = math.min(total, i + READ_SLICE) - 1
    for k = i, stop do
      local ok, name, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, id = pcall(C_AuctionHouse.GetReplicateItemInfo, k)
      if ok and id and buyout and buyout > 0 and count and count > 0 then
        local list = byId[id]
        if not list then list = {} byId[id] = list M.NoteName(id, name) end
        list[#list + 1] = { unit = buyout / count, n = count }
        rowsN = rowsN + 1
      end
    end
    i = stop + 1
    local pct = math.floor(i / total * 100)
    if pct >= lastPct + 10 then
      lastPct = pct
      M.status = "Reading listings … " .. pct .. " %"
      ns:Fire("MARKET")
    end
    if i < total then C_Timer.After(0, step) return end
    M.storeScan(byId, afterScan)
  end
  step()
end
ns:On("REPLICATE_ITEM_LIST_UPDATE", function()
  if M.waitReplicate then
    M.waitReplicate = nil
    readReplicate()
  elseif M.ahOpen and on() and not M.scanning then
    -- someone else's full scan: same data, same 15-minute cooldown
    M.scanning = true
    ns.db.marketFullAt = ns.Now()
    M.status = "Capturing a full scan from another addon …"
    ns:Fire("MARKET")
    readReplicate()
  end
end)

-- classic list results: a full scan, or one of our quick bag checks
ns:On("AUCTION_ITEM_LIST_UPDATE", function()
  if not M.waitClassic then return end
  local kind = M.waitClassic
  M.waitClassic = nil
  local rows = {}
  local okN, n = pcall(GetNumAuctionItems, "list")
  for i = 1, (okN and n or 0) do
    local ok, name, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, id = pcall(GetAuctionItemInfo, "list", i)
    if ok and id then rows[#rows + 1] = { id = id, buyout = buyout, count = count } M.NoteName(id, name) end
  end
  if kind == "all" then digest(rows, afterScan)
  else digest(rows, function(_, changed) M:BagNext(changed) end) end
end)

---------------------------------------------------------------------------
-- quick check of your bags when the auction house opens (classic API: one search per item, and it
-- stops as soon as you search yourself, so it never fights you for the list)
---------------------------------------------------------------------------
local bagQueue, bagChanged = {}, {}
function M:BagCheck()
  if not on() then return end
  bagQueue, bagChanged = {}, {}
  local seen = {}
  local f = (C_Container and C_Container.GetContainerItemInfo)
  for bag = 0, 4 do
    local nSlots = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)) or 0
    for slot = 1, nSlots do
      local ok, info = pcall(f, bag, slot)
      if ok and type(info) == "table" and info.hyperlink and not info.isBound and not info.hasNoValue then
        local id = info.itemID or itemIdOf(info.hyperlink)
        local e = id and self:Get(id)
        if id and not seen[id] and (not e or ns.Now() - e.t > 3600) and (info.quality or 1) >= 1 then
          seen[id] = true
          bagQueue[#bagQueue + 1] = { id = id, link = info.hyperlink }
        end
      end
    end
  end
  if #bagQueue == 0 then return end
  self.bagChecking = true
  M.status = "Checking " .. #bagQueue .. " items from your bags …"
  ns:Fire("MARKET")
  self:BagNext()
end

function M:BagNext(changed)
  for _, id in ipairs(changed or {}) do bagChanged[#bagChanged + 1] = id end
  if not self.bagChecking then return end
  local nextItem = table.remove(bagQueue, 1)
  if not nextItem or not (AuctionFrame and AuctionFrame:IsShown()) then
    self.bagChecking = nil
    if #bagChanged > 0 then self:Share(bagChanged) end
    M.status = ""
    ns:Fire("MARKET")
    return
  end
  local name = nextItem.link:match("%[(.-)%]")
  local function try()
    if not M.bagChecking then return end
    local ok, canQ = pcall(CanSendAuctionQuery)
    if not (ok and canQ) then C_Timer.After(0.5, try) return end
    M.ownQuery = true
    M.waitClassic = "bag"
    pcall(QueryAuctionItems, name, nil, nil, 0, nil, nil, false, true, nil)
    M.ownQuery = nil
  end
  try()
end

-- you searched yourself: the quick check stops so the list is yours
if QueryAuctionItems then
  hooksecurefunc("QueryAuctionItems", function()
    if M.ownQuery then return end
    if M.bagChecking then M.bagChecking = nil bagQueue = {} M.waitClassic = nil M.status = "" ns:Fire("MARKET") end
  end)
end

---------------------------------------------------------------------------
-- sharing: MK = prices ("id,value,minutesAgo;…"), MQ = "I just logged in, my newest is t",
-- MA = "I'm answering that one" (so only one friend sends)
---------------------------------------------------------------------------
local b36 = function(n)
  n = math.floor(n)
  if n == 0 then return "0" end
  local s, d = "", "0123456789abcdefghijklmnopqrstuvwxyz"
  while n > 0 do local r = n % 36 s = d:sub(r + 1, r + 1) .. s n = math.floor(n / 36) end
  return s
end
local function un36(s) return tonumber(s, 36) end

-- (1.3.5) the outbox holds item ids, not finished messages: each message is built when it goes out
-- (so the age is right), packed as full as a message allows, sent on the gang channel only (no
-- copy per friend), and only when the line is free – chat, dings and status always go first
local outbox, sending = {}, false
local MAX_LEN = 230
-- (1.4.26) "MP": prices from the same scan share one age and one scanner, so each price is just
-- "id,value" – about 20 per message instead of 14
local function build(ids)
  local now, parts, used, len = ns.Now(), {}, 0, 40
  local t0, by0
  for k, id in ipairs(ids) do
    local e = db()[id]
    if e then
      if not t0 then t0, by0 = e.t, e.by or "" end
      if math.abs((e.t or 0) - t0) > 90 or (e.by or "") ~= by0 then break end
      local part = b36(id) .. "," .. b36(e.v)
      if len + #part + 1 > MAX_LEN then break end
      parts[#parts + 1] = part
      len = len + #part + 1
    end
    used = k
  end
  if #parts == 0 then return nil, used end
  local byShort = (by0 == ns.pid and ns.ShortName(Comm:MyFull())) or (by0:find("^bn:") and "") or ns.ShortName(by0)
  byShort = byShort:sub(1, 16)
  return Comm:Build("MP", b36(math.max(0, math.floor((now - t0) / 60))), byShort, table.concat(parts, ";")), used
end
-- (1.4.26) the market lane: two prefixes taking turns, one message every half second (about 40
-- prices a second). Falls back to the normal queue when the gang channel can't be used.
local lane = 0
local function sendFast(msg, to)
  if Comm:InLockdown() then return false end
  lane = lane % #ns.MARKET_PREFIXES + 1
  local pre = ns.MARKET_PREFIXES[lane]
  local chatType, target
  if to then
    if to:sub(1, 3) == "bn:" then return nil end
    chatType, target = "WHISPER", to
  else
    Comm:RefreshChannelId()
    if not Comm:ChannelUsable() then return nil end
    chatType, target = "CHANNEL", tostring(Comm.chanId)
  end
  local ok, res = pcall(C_ChatInfo.SendAddonMessage, pre, msg, chatType, target)
  if not ok then return nil end
  return res == nil or res == true or res == 0
end
local function pump()
  local job = outbox[1]
  if not job then sending = false return end
  local msg, used = build(job.ids)
  if msg then
    local sent = sendFast(msg, job.to)
    if sent == false then C_Timer.After(1, pump) return end   -- throttled or boss fight: same message again soon
    if sent == nil then
      -- no fast lane (channel down, Battle.net friend): the normal queue, which waits its turn
      if Comm._queue and #Comm._queue[3] > 1 then C_Timer.After(0.5, pump) return end
      if job.to then Comm:SendTo(job.to, msg, job.prio or 3) else Comm:Broadcast(msg, 3) end
      for _ = 1, used do table.remove(job.ids, 1) end
      if #job.ids == 0 then table.remove(outbox, 1) end
      C_Timer.After(1, pump)
      return
    end
  end
  for _ = 1, used do table.remove(job.ids, 1) end
  if #job.ids == 0 then table.remove(outbox, 1) end
  C_Timer.After(SEND_EVERY, pump)
end
local function queueIds(ids, to, urgent)
  if #ids == 0 then return end
  local copy = {}
  for k, id in ipairs(ids) do copy[k] = id end
  -- keep prices from the same scan together, newest scans first
  table.sort(copy, function(a, b)
    local ea, eb = db()[a] or {}, db()[b] or {}
    if (ea.t or 0) ~= (eb.t or 0) then return (ea.t or 0) > (eb.t or 0) end
    return a < b
  end)
  local job = { ids = copy, to = to, prio = urgent and 2 or 3 }
  if urgent then table.insert(outbox, 1, job) else outbox[#outbox + 1] = job end
  if not sending then sending = true C_Timer.After(urgent and 0.1 or 1, pump) end
end
M.Pending = function()
  local n = 0
  for _, j in ipairs(outbox) do n = n + #j.ids end
  return n
end

function M:Share(ids)
  if not on() or ns.db.settings.marketShare == false then return end
  queueIds(ids)
end

Comm:Handle("MK", function(f, sender)
  if not on() then return end
  local n, got = 0, {}
  for part in tostring(f[1] or ""):gmatch("[^;]+") do
    local a, b, c = part:match("^(%w+),(%w+),(%w+)$")
    local id, v, ago = a and un36(a), b and un36(b), c and un36(c)
    if id and v and ago then
      if M:Set(id, v, ns.Now() - ago * 60, ns.ShortName(sender or "")) then n = n + 1 got[id] = true end
    end
  end
  if n > 0 then
    ns:Fire("MARKET")
    M.heardFrom = ns.ShortName(sender or "")
    M.heardAt = ns.Now()
    -- (1.3.10) the tooltip you're looking at updates by itself when its price arrives
    if GameTooltip and GameTooltip:IsShown() and GameTooltip.RefreshData then
      local ok, _, link = pcall(GameTooltip.GetItem, GameTooltip)
      local id = ok and itemIdOf(link)
      if id and got[id] then pcall(GameTooltip.RefreshData, GameTooltip) end
    end
  end
end)

-- (1.4.26) incoming batches: a scan ("MS") or a catch-up ("MZ") says how many prices follow; once
-- 90 % have arrived we count that scan as ours, so the next login doesn't ask for it again
M.incoming = {}
local function expect(sender, n, t)
  if not sender or (n or 0) <= 0 then return end
  M.incoming[sender] = { n = n, got = 0, t = t, at = ns.Now() }
end
local function received(sender, k)
  local inc = sender and M.incoming[sender]
  if not inc then return end
  inc.got = inc.got + k
  if inc.got >= inc.n * 0.9 then noteFull(inc.t) M.incoming[sender] = nil end
end
Comm:Handle("MP", function(f, sender)
  if not on() then return end
  local ago = un36(f[1] or "") or 0
  local by = f[2] ~= "" and f[2] or ns.ShortName(sender or "")
  local t = ns.Now() - ago * 60
  local n, k, got = 0, 0, {}
  for part in tostring(f[3] or ""):gmatch("[^;]+") do
    local a, b = part:match("^(%w+),(%w+)$")
    local id, v = a and un36(a), b and un36(b)
    if id and v then
      k = k + 1
      if M:Set(id, v, t, by) then n = n + 1 got[id] = true end
    end
  end
  received(sender, k)
  if n > 0 then
    ns:Fire("MARKET")
    M.heardFrom = ns.ShortName(sender or "")
    M.heardAt = ns.Now()
    if GameTooltip and GameTooltip:IsShown() and GameTooltip.RefreshData then
      local ok, _, link = pcall(GameTooltip.GetItem, GameTooltip)
      local id = ok and itemIdOf(link)
      if id and got[id] then pcall(GameTooltip.RefreshData, GameTooltip) end
    end
  end
end)
Comm:Handle("MZ", function(f, sender)
  if Comm:IsMe(sender) then return end
  expect(sender, tonumber(f[1]), ns.Now() - (tonumber(f[2]) or 0))
end)

-- someone logged in: whoever has newer prices offers; the first to say "MA" sends
Comm:Handle("MQ", function(f, sender)
  if not on() or ns.db.settings.marketShare == false then return end
  local theirs = tonumber(f[1]) or 0
  local mine = M:FullT()
  if Comm:IsMe(sender) then return end
  -- (1.4.31) their scan is newer than ours: ask them back (catch-up used to happen only at our login,
  -- so a friend who came online after us never sent their scan)
  if theirs > mine + 300 then
    M.askedBack = M.askedBack or {}
    local k = ns.ShortName(sender or "")
    if not M.askedBack[k] or ns.Now() - M.askedBack[k] > 600 then
      M.askedBack[k] = ns.Now()
      C_Timer.After(1 + math.random() * 2, function() Comm:SendTo(sender, Comm:Build("MQ", M:FullT()), 2) end)
    end
    return
  end
  if mine <= theirs + 300 then return end
  local req = ns.ShortName(sender or "")
  M.answering = M.answering or {}
  -- (1.3.11) the newer your prices, the sooner you answer; someone with older prices never stops you
  local age = math.max(0, ns.Now() - mine)
  local delay = 0.5 + math.min(4, age / 3600) + math.random() * 1.5
  C_Timer.After(delay, function()
    local a = M.answering[req]
    if a and ns.Now() - a.at < 600 and (a.latest or 0) + 300 >= mine then return end   -- someone as fresh took it
    M.answering[req] = { at = ns.Now(), latest = mine }
    Comm:Broadcast(Comm:Build("MA", req, mine), 2)
    local ids = {}
    for id, e in pairs(db()) do if (e.t or 0) > theirs then ids[#ids + 1] = id end end
    table.sort(ids, function(a, b) return db()[a].t > db()[b].t end)
    while #ids > MAX_SYNC do table.remove(ids) end
    -- (1.4.26) say how many are coming, then send them on the fast lane
    local head = Comm:Build("MZ", #ids, math.max(0, ns.Now() - mine))
    if not sendFast(head, sender) then Comm:SendTo(sender, head, 2) end
    queueIds(ids, sender, true)
  end)
end)
-- (1.3.4) "MI": someone hovered items we may know the price of – answer those right away
local asked, askQueue, askTimer = {}, {}, false
function M:Ask(id)
  if not on() or not id then return end
  local e = db()[id]
  local behind = M.gangScanAt and (not e or e.t < M.gangScanAt - 120)
  if asked[id] and asked[id] >= (M.gangScanAt or 0) and ns.Now() - asked[id] < (behind and 20 or 600) then return end
  asked[id] = ns.Now()
  askQueue[#askQueue + 1] = id
  if askTimer then return end
  askTimer = true
  C_Timer.After(1, function()
    askTimer = false
    local ids = {}
    for i = 1, math.min(PER_MSG, #askQueue) do ids[#ids + 1] = b36(table.remove(askQueue, 1)) end
    if #ids > 0 then Comm:Broadcast(Comm:Build("MI", table.concat(ids, ",")), 2) end
  end)
end
Comm:Handle("MI", function(f, sender)
  if not on() or ns.db.settings.marketShare == false or Comm:IsMe(sender) then return end
  local have = {}
  for part in tostring(f[1] or ""):gmatch("[^,]+") do
    local id = un36(part)
    if id and db()[id] then have[#have + 1] = id end
  end
  if #have == 0 then return end
  C_Timer.After(0.3 + math.random() * 1.5, function() queueIds(have, sender, true) end)
end)

-- someone just scanned: prices we hover that are older than their scan get asked for
Comm:Handle("MS", function(f, sender)
  if Comm:IsMe(sender) then return end
  M.gangScanAt, M.gangScanBy, M.gangScanN = ns.Now(), ns.ShortName(sender or ""), tonumber(f[1])
  expect(sender, tonumber(f[2]), ns.Now())
  ns:Fire("MARKET")
  if GameTooltip and GameTooltip:IsShown() and GameTooltip.GetItem then
    local ok, _, link = pcall(GameTooltip.GetItem, GameTooltip)
    local id = ok and itemIdOf(link)
    if id then M:Ask(id) end
  end
end)

Comm:Handle("MA", function(f)
  M.answering = M.answering or {}
  if f[1] then M.answering[f[1]] = { at = ns.Now(), latest = tonumber(f[2]) or math.huge } end
end)

ns:On("PLAYER_LOGIN", function()
  C_Timer.After(25, function()
    if not on() or not ns.db then return end
    M:Prune()
    Comm:Broadcast(Comm:Build("MQ", M:FullT()), 3)
  end)
  -- (1.4.31) and every 20 minutes: one tiny message, so friends who were online all along still
  -- catch up on each other's scans
  C_Timer.NewTicker(1200, function()
    if on() and ns.db and not M.scanning then Comm:Broadcast(Comm:Build("MQ", M:FullT()), 3) end
  end)
end)

-- (1.4.31) a friend's ?price answer from an older price than ours: send them (and the gang) our
-- fresher prices for those items, and post the newer answer
local priceSeen = {}   -- (1.4.32) one look per answer line, and one correction per question
ns:Listen("FEEDEVENT", function(_, item)
  if not (item and item.kind == "PRICE" and on()) then return end
  local key = tostring(item.a or ""):lower()
  if item.c == "1" then priceSeen["upd:" .. key] = ns.Now() end   -- someone already posted an update
  if item.pid == ns.pid then return end
  local id = (item.pid or "") .. ":" .. tostring(item.t or "") .. ":" .. key
  if priceSeen[id] then return end
  priceSeen[id] = true
  local res = M.ParsePrice(item.d)
  local fresher, ids = false, {}
  for _, r in ipairs(res) do
    local e = db()[r.id]
    if e and (e.t or 0) > ns.Now() - (r.ago or 0) + 1800 then fresher = true ids[#ids + 1] = r.id end
  end
  if not fresher then return end
  C_Timer.After(1 + math.random() * 2, function()
    queueIds(ids, nil, true)
    -- post an update only if nobody else has in the last minute
    local u = priceSeen["upd:" .. key]
    if item.a and item.a ~= "" and not (u and ns.Now() - u < 60) and #M:Search(item.a, 1) > 0 then
      priceSeen["upd:" .. key] = ns.Now()
      M:PostPrice(item.a, true)
    end
  end)
end)

---------------------------------------------------------------------------
-- tooltip: one line, "Market  12g 34s  · 2h ago"
---------------------------------------------------------------------------
-- money with the gold / silver / copper coins, like the game's own tooltips
local function coins(copper)
  copper = math.floor(copper or 0)
  -- (1.3.8) our own coins with a fixed size: icons sized "0" (line height) aren't counted when the
  -- tooltip works out its width, so the text ran out over the right edge
  local g, sv, c = math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = g .. "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t" end
  if sv > 0 then parts[#parts + 1] = sv .. "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t" end
  if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t" end
  return table.concat(parts, " ")
end
M.Coins = coins

-- how many are in the stack you're hovering, else 1. (1.3.9) Only for a real bag slot that holds this
-- very item: on the character sheet or an inspect window the slot number pointed at a random bag
-- stack, so a ring counted as 12 and "Best" was 12× too big.
local function hoveredCount(tt, id)
  local owner = tt and tt.GetOwner and tt:GetOwner()
  if not owner or not owner.GetBagID or not owner.GetID then return 1 end
  local okB, bag = pcall(owner.GetBagID, owner)
  local okS, slot = pcall(owner.GetID, owner)
  if okB and okS and type(bag) == "number" and type(slot) == "number" and C_Container and C_Container.GetContainerItemInfo then
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if ok and type(info) == "table" and info.itemID == id and type(info.stackCount) == "number" then return info.stackCount end
  end
  return 1
end

local function vendorPrice(id)
  local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not f then return nil end
  local ok, _, _, _, _, _, _, _, _, _, _, sell = pcall(f, id)
  return ok and type(sell) == "number" and sell or nil
end
M.VendorPrice = vendorPrice

local AH_CUT = 0.05   -- what the auction house keeps when it sells

local function opt(key) return ns.db.settings[key] ~= false end

-- (1.3.5) the tooltip block (each line can be switched off on the Market page):
--   Chillan? Market   4s each · 22 min ago
--   Stack of 20       39s 40c                    (when you hover a stack)
--   Disenchant        ≈ 1g 20s                   (expected value of the mats; or what it gives)
--   Best: Disenchant  +40s over auction          (auction after the 5 % cut, vendor, disenchant)
--   Since last scan   +12 %                      (when the price moved)
local function addLine(tt, id, count)
  if not on() or not id or not tt or not tt.AddDoubleLine then return end
  local e = M:Get(id)
  -- no price, or a friend has scanned since ours: ask the gang (answers come in a second or two)
  local waiting = M.gangScanAt and e and e.t < M.gangScanAt - 120
  if not e or waiting then M:Ask(id) end
  count = count or hoveredCount(tt, id)
  local n = math.max(1, count)
  local shown = false
  local old = e and ns.Now() - (e.t or 0) > STALE
  if e and opt("mkPrice") then
    local each = count > 1 and " each" or ""
    if old then
      tt:AddDoubleLine("Market (old)", coins(e.v) .. each .. "  · " .. ns.Ago(e.t), 0.55, 0.57, 0.6, 0.55, 0.57, 0.6)
    else
      tt:AddDoubleLine("|cffC69B6DChillan?|r Market", coins(e.v) .. each .. "  |cff858B92· " .. ns.Ago(e.t) .. "|r", 0.9, 0.9, 0.9, 1, 1, 1)
    end
    if waiting and M.gangScanBy and tt.AddLine then tt:AddLine("Asking " .. M.gangScanBy .. " for a newer price …", 0.55, 0.57, 0.6) end
    shown = true
  end
  if e and count > 1 and opt("mkStack") then tt:AddDoubleLine("Stack of " .. count, coins(e.v * count), 0.75, 0.78, 0.82, 1, 1, 1) end
  -- disenchanting
  local deVal, deRes
  if opt("mkDE") and ns.Disenchant then
    deVal, deRes = ns.Disenchant:Value(id)
    if not deRes then deRes = ns.Disenchant:Results(id) end
    if deRes then
      if deVal then
        tt:AddDoubleLine("Disenchant", "≈ " .. coins(deVal), 0.75, 0.78, 0.82, 1, 1, 1)
      else
        ns.Disenchant:AskMats(id)
        if not opt("mkDEList") then tt:AddLine("Disenchant: " .. ns.Disenchant:Describe(deRes), 0.6, 0.63, 0.66, true) end
      end
      -- (1.3.7) what it gives, one line per mat, with the chance and the mat's price
      if opt("mkDEList") then
        for _, r in ipairs(deRes) do
          local i = ns.Disenchant.Info(r.id)
          local q = r.min == r.max and tostring(r.min) or (r.min .. "–" .. r.max)
          local me = M:Get(r.id)
          tt:AddDoubleLine("   " .. q .. "× " .. ((i and i.name) or ("item " .. r.id)) .. (r.chance < 1 and ("  |cff858B92" .. math.floor(r.chance * 100 + 0.5) .. " %|r") or ""),
            me and coins(me.v) or "|cff858B92no price|r", 0.75, 0.78, 0.82, 0.85, 0.85, 0.85)
        end
      end
      shown = true
    end
  end
  -- what pays most
  if opt("mkBest") then
    local options = {}
    -- (1.4.57) the same sum as the Market window's Up Next (Naowh's rule): price each x 0.95 rounded
    -- down, times the stack; an old price still counts, so the two always agree
    if e then options[#options + 1] = { "Auction", math.floor(e.v * (1 - AH_CUT)) * n } end
    local sell = vendorPrice(id)
    if sell and sell > 0 then options[#options + 1] = { "Vendor", sell * n } end
    if deVal then options[#options + 1] = { "Disenchant", deVal * n } end
    if #options >= 2 then
      table.sort(options, function(a, b) return a[2] > b[2] end)
      local best, second = options[1], options[2]
      local diff = best[2] - second[2]
      if diff > 0 then
        local col = best[1] == "Auction" and { 0.37, 0.82, 0.55 } or best[1] == "Disenchant" and { 0.73, 0.6, 0.95 } or { 0.88, 0.69, 0.31 }
        tt:AddDoubleLine("Best: " .. best[1], "+" .. coins(diff) .. " vs " .. second[1]:lower(), 0.75, 0.78, 0.82, col[1], col[2], col[3])
        shown = true
      end
    end
  end
  if e and e.p and e.p > 0 and not old and opt("mkTrend") then
    local pct = math.floor((e.v - e.p) / e.p * 100 + 0.5)
    if math.abs(pct) >= 5 then
      tt:AddDoubleLine("Since last scan", (pct > 0 and "+" or "") .. pct .. " %", 0.75, 0.78, 0.82,
        pct > 0 and 0.37 or 0.95, pct > 0 and 0.82 or 0.47, pct > 0 and 0.55 or 0.48)
    end
  end
  if shown and tt.Show then tt:Show() end
end
M.AddTooltipLine = addLine

local hooked
function M:HookTooltips()
  if hooked then return end
  hooked = true
  if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
      local id = data and data.id
      if (not id or ns.isSecret(id)) and tt.GetItem then
        local ok, _, link = pcall(tt.GetItem, tt)
        id = ok and itemIdOf(link) or nil
      end
      if id and not ns.isSecret(id) then pcall(addLine, tt, id) end
    end)
  else
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
      if tt and tt.HookScript then
        tt:HookScript("OnTooltipSetItem", function(self)
          local ok, _, link = pcall(self.GetItem, self)
          if ok then pcall(addLine, self, itemIdOf(link)) end
        end)
      end
    end
  end
end

---------------------------------------------------------------------------
-- (1.4.27) page-by-page scan, for the 15 minutes between full scans: one browse of every item,
-- asking for more until the game says it has sent everything. Each item's lowest price is kept.
---------------------------------------------------------------------------
local BROWSE_EVENTS = { "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
  "AUCTION_HOUSE_BROWSE_FAILURE", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" }
local browse = nil   -- { sent, gen }
local browseGen = 0
local function browseQuery()
  local F = Enum and Enum.AuctionHouseFilter
  local O = Enum and Enum.AuctionHouseSortOrder
  if not (F and O) then return nil end
  return { searchString = "",
    sorts = { { sortOrder = O.Price, reverseSort = false }, { sortOrder = O.Name, reverseSort = false } },
    filters = { F.PoorQuality, F.CommonQuality, F.UncommonQuality, F.RareQuality, F.EpicQuality, F.LegendaryQuality } }
end
local function browseStop(msg)
  browse = nil
  browseGen = browseGen + 1
  M.scanning = nil
  if msg then M.status = msg end
  ns:Fire("MARKET")
end
local function browseAsk()
  if not browse then return end
  local gen = browseGen
  C_Timer.After(30, function() if browse and gen == browseGen then browseStop("Scan stopped: no answer from the auction house") end end)
  local okR, ready = pcall(C_AuctionHouse.IsThrottledMessageSystemReady)
  if okR and ready == false then browse.waiting = true return end
  browse.waiting = nil
  if browse.sent then pcall(C_AuctionHouse.RequestMoreBrowseResults) return end
  local q = browseQuery()
  if not q then browseStop("This auction house can't be scanned page by page") return end
  browse.sent, browse.sending = true, true
  pcall(C_AuctionHouse.SendBrowseQuery, q)
  browse.sending = nil
end
local function browseRows(rows)
  local byId = {}
  for _, r in ipairs(rows or {}) do
    local key = r.itemKey
    local id, price = key and key.itemID, r.minPrice
    if id and price and price > 0 and (key.itemSuffix or 0) == 0 then byId[id] = { { unit = price, n = 1 } } end
  end
  return byId
end
function M:BrowseScan(left)
  if self.scanning then return end
  self.scanning = true
  browse = { at = ns.Now() }
  M.status = "Scanning page by page" .. ((left or 0) > 0 and (" (full scan free in " .. math.ceil(left / 60) .. " min)") or "") .. " …"
  ns:Fire("MARKET")
  browseAsk()
end
for _, ev in ipairs(BROWSE_EVENTS) do
  ns:On(ev, function(added)
    if ev == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
      if browse and browse.waiting then browseAsk() end
      return
    end
    if ev == "AUCTION_HOUSE_BROWSE_FAILURE" then
      if browse then browseStop("Scan stopped: the auction house refused the search") end
      return
    end
    if browse and not browse.sending and browse.sent then
      local okF, full = pcall(C_AuctionHouse.HasFullBrowseResults)
      if okF and full then
        local okR, rows = pcall(C_AuctionHouse.GetBrowseResults)
        browse = nil
        browseGen = browseGen + 1
        M.status = "Working out prices …"
        ns:Fire("MARKET")
        M.storeScan(browseRows(okR and rows or {}), afterScan, function(list) return math.floor(list[1].unit) end)
        return
      end
      local okR, rows = pcall(C_AuctionHouse.GetBrowseResults)
      M.status = "Scanning page by page … " .. ns.Num(okR and rows and #rows or 0) .. " items"
      ns:Fire("MARKET")
      browseAsk()
      return
    end
    -- passive: the lowest prices of whatever you browse yourself are kept too (a newer price wins)
    if not browse and M.ahOpen and on() and ev ~= "AUCTION_HOUSE_BROWSE_FAILURE" then
      local okR, rows = pcall(C_AuctionHouse.GetBrowseResults)
      if okR and rows and #rows > 0 and #rows <= 500 then
        local t, n = ns.Now(), 0
        for id, list in pairs(browseRows(rows)) do
          local e = db()[id]
          -- only a fresher look than a scan from the last 10 minutes
          if not e or ns.Now() - (e.t or 0) > 600 then
            if M:Set(id, math.floor(list[1].unit), t, ns.pid) then n = n + 1 end
          end
        end
        if n > 0 then ns:Fire("MARKET") end
      end
    end
  end)
end
-- another addon's search replaces our page-by-page scan
if C_AuctionHouse and hooksecurefunc then
  pcall(hooksecurefunc, C_AuctionHouse, "SendBrowseQuery", function()
    if browse and not browse.sending then browseStop("Scan stopped: another search took its place") end
  end)
end

---------------------------------------------------------------------------
-- the button on the auction house
---------------------------------------------------------------------------
function M:AttachButton()
  local host = (AuctionHouseFrame and AuctionHouseFrame:IsShown() and AuctionHouseFrame) or (AuctionFrame and AuctionFrame:IsShown() and AuctionFrame)
  if not host then return end
  local UI, C = ns.UI, ns.C
  if not self.button then
    local b = UI.Button(UIParent, 120, 24, "Chillan? scan", "secondary", function() M:FullScan() end)
    b:SetFrameStrata("HIGH")
    b.tooltip = "Scans the whole auction house. The game allows a full scan once every 15 minutes; in between, a quick scan reads the lowest price of every item page by page. Prices are added to tooltips and shared with the gang."
    b.status = UI.Text(b, 11, nil, C.muted)
    b.status:SetPoint("RIGHT", b, "LEFT", -8, 0)
    b.status:SetJustifyH("RIGHT")
    self.button = b
    ns:Listen("MARKET", function() M:PaintButton() end)
  end
  self.button:SetParent(host)
  self.button:SetFrameLevel((host:GetFrameLevel() or 1) + 20)
  self.button:ClearAllPoints()
  -- (1.3.5) a tab on top of the window, top left: the bottom row is full of tabs from the auction
  -- house and other addons
  self.button:SetPoint("BOTTOMLEFT", host, "TOPLEFT", 12, 2)
  self.button.status:ClearAllPoints()
  self.button.status:SetPoint("LEFT", self.button, "RIGHT", 8, 0)
  self.button.status:SetJustifyH("LEFT")
  self.button:Show()
  self:PaintButton()
end

function M:PaintButton()
  local b = self.button
  if not b then return end
  local can, left = self:CanFull()
  b:SetLabel(self.scanning and "Scanning …" or (can and "Chillan? scan" or "Quick scan"))
  local s = M.status ~= "" and M.status or (ns.Num(self:Count()) .. " prices" .. (M.heardFrom and (" · last from " .. M.heardFrom) or ""))
  b.status:SetText(s)
end

function M:Count()
  local n = 0
  for _ in pairs(db()) do n = n + 1 end
  return n
end

local function opened()
  if not on() then return end
  C_Timer.After(0.3, function() M:AttachButton() end)
  if classic() and not modern() then C_Timer.After(1.5, function() M:BagCheck() end) end
end
ns:On("AUCTION_HOUSE_SHOW", function() M.ahOpen = true opened() end)
ns:On("AUCTION_HOUSE_CLOSED", function()
  M.ahOpen = nil
  if browse then browseStop("Scan stopped: the auction house closed") end
  M.bagChecking = nil
  bagQueue = {}
  if M.button then M.button:Hide() end
end)

ns:On("PLAYER_LOGIN", function() C_Timer.After(1, function() if on() then M:HookTooltips() end end) end)

function M:StatusText()
  local newest = self:Latest()
  return ns.Num(self:Count()) .. " prices" .. (newest > 0 and (", newest " .. ns.Ago(newest)) or "")
    .. (M.heardFrom and (" · last received from " .. M.heardFrom .. " " .. ns.Ago(M.heardAt)) or "")
    .. (M.gangScanBy and (" · " .. M.gangScanBy .. " scanned " .. ns.Ago(M.gangScanAt) .. (M.gangScanN and (" (" .. ns.Num(M.gangScanN) .. " prices)") or "")) or "")
    .. (M.Pending() > 0 and (" · still sending " .. ns.Num(M.Pending()) .. " prices") or "")
end

-- /chill selftest: what this auction house lets us do
function M:SelfTest()
  return (modern() and "modern (full scan via ReplicateItems)" or classic() and "classic (list queries)" or "none")
    .. " · " .. ns.Num(self:Count()) .. " prices stored"
end

-- (1.3.11) /chill market who: which online friends run a version that shares prices
function M:WhoText()
  local out = {}
  for pid, p in pairs(ns.db.people or {}) do
    if pid ~= ns.pid and ns:IsOnline(p) then
      local v = p.version or "?"
      local ok = v ~= "?" and (v:find("dev", 1, true) or not ns.NewerVersion("1.3.5", v))
      out[#out + 1] = ns:PersonName(p) .. " " .. v .. (ok and "" or " |cffff6060(too old for Market – update in WoWUp)|r")
    end
  end
  table.sort(out)
  return #out > 0 and table.concat(out, ", ") or "nobody online"
end

---------------------------------------------------------------------------
-- (1.4.24) price search: find a scanned price by item name, on the Market tab or with
-- "?price <name>" in gang chat (the answer goes to the whole gang)
---------------------------------------------------------------------------
local function names()
  ns.db.marketNames = ns.db.marketNames or {}
  return ns.db.marketNames
end
function M.NoteName(id, name)
  if id and type(name) == "string" and name ~= "" and not ns.isSecret(name) then names()[id] = name end
end
local function nameOf(id)
  local n = names()[id]
  if n then return n end
  local got
  if C_Item and C_Item.GetItemNameByID then local ok, x = pcall(C_Item.GetItemNameByID, id) if ok then got = x end end
  if not got and C_Item and C_Item.GetItemInfo then local ok, x = pcall(C_Item.GetItemInfo, id) if ok then got = x end end
  if not got and GetItemInfo then local ok, x = pcall(GetItemInfo, id) if ok then got = x end end
  if type(got) == "string" and got ~= "" and not ns.isSecret(got) then names()[id] = got return got end
  return nil
end
M.NameOf = nameOf

-- items whose name we don't know yet (prices from friends) are loaded in the background, a few per second
local warmQ, warming = nil, false
local function warm()
  if warming then return end
  warmQ = {}
  for id in pairs(db()) do if not names()[id] then warmQ[#warmQ + 1] = id end end
  if #warmQ == 0 then return end
  warming = true
  local function step()
    for _ = 1, 40 do
      local id = table.remove(warmQ)
      if not id then warming = false return end
      if not nameOf(id) and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    end
    C_Timer.After(1, step)
  end
  step()
end
M.Warm = warm
ns:On("GET_ITEM_INFO_RECEIVED", function(id, ok)
  if id and ok ~= false and db()[id] and not names()[id] then nameOf(id) end
end)
ns:On("PLAYER_LOGIN", function() C_Timer.After(40, warm) end)

-- best matches for a name: exact, then starts with, then whole word, then anywhere; shorter names first
function M:Search(q, max)
  q = tostring(q or ""):lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("[%[%]]", "")
  if #q < 2 then return {}, 0 end
  local plain = q:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  local hits, unnamed = {}, 0
  for id, e in pairs(db()) do
    local n = nameOf(id)
    if not n then unnamed = unnamed + 1
    else
      local l = n:lower()
      local rank
      if l == q then rank = 0
      elseif l:sub(1, #q) == q then rank = 1
      elseif l:find("%f[%w]" .. plain) then rank = 2
      elseif l:find(q, 1, true) then rank = 3 end
      if rank then hits[#hits + 1] = { id = id, name = n, v = e.v, t = e.t, by = e.by, rank = rank } end
    end
  end
  table.sort(hits, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    if #a.name ~= #b.name then return #a.name < #b.name end
    return a.name < b.name
  end)
  local total = #hits
  while #hits > (max or 8) do table.remove(hits) end
  if unnamed > 0 then warm() end
  return hits, total, unnamed
end
function M.Warming() return warming, warmQ and #warmQ or 0 end

local function byName(by)
  if not by or by == "" or by:find("^bn:") then return nil end
  if by == ns.pid then return "you" end
  local p = ns:GetPerson(by)
  local first = p and p.main and ns.PersonFirst and ns:PersonFirst(p)
  return (first and first ~= "" and first ~= "?") and first or ns.ShortName(by)
end
M.ByName = byName

-- "?price <name>" in gang chat: the asker's Chillan posts the answer as a feed line for everyone
local function clean(s) return (tostring(s or ""):gsub("[~;|^]", " ")) end
function M:PostPrice(q, auto, tries, checked)
  local hits, total, unnamed = self:Search(q, 3)
  -- (1.4.32) before answering, ask the gang for those items and wait a moment, so the one line we
  -- post already has the newest price anyone has (instead of a second "Price update" line later)
  if not auto and not checked and #hits > 0 then
    local ids = {}
    for _, h in ipairs(hits) do ids[#ids + 1] = b36(h.id) end
    Comm:Broadcast(Comm:Build("MI", table.concat(ids, ",")), 1)
    C_Timer.After(4, function() M:PostPrice(q, auto, tries, true) end)
    return
  end
  -- (1.4.25) prices from before 1.4.24 (or from friends) have no name stored yet: wait while the
  -- names load (up to 3 minutes) before saying there's no price
  if #hits == 0 and unnamed > 0 and (tries or 0) < 36 then
    if (tries or 0) == 0 then ns.Print("Market: looking up item names for " .. ns.Num(unnamed) .. " prices first – the answer follows shortly.") end
    C_Timer.After(5, function() M:PostPrice(q, auto, (tries or 0) + 1) end)
    return
  end
  local parts = {}
  for _, h in ipairs(hits) do
    -- fields joined with "^" ("~" separates the message's own fields)
    parts[#parts + 1] = h.id .. "^" .. h.v .. "^" .. math.max(0, math.floor((ns.Now() - (h.t or ns.Now())) / 60)) .. "^"
      .. clean((h.by == ns.pid and ns.ShortName(ns.Comm:MyFull())) or byName(h.by) or ""):sub(1, 14) .. "^" .. clean(h.name):sub(1, 30)
  end
  ns.Tracker:Event("PRICE", clean(q):sub(1, 40), total, auto and "1" or "", table.concat(parts, ";"))
  if #hits == 0 then
    ns.db.marketWanted = ns.db.marketWanted or {}
    ns.db.marketWanted[q:lower()] = ns.Now()
  end
end
function M.ParsePrice(d)
  local out = {}
  for part in tostring(d or ""):gmatch("[^;]+") do
    local id, v, ago, by, name = part:match("^(%d+)%^(%d+)%^(%d+)%^([^%^]*)%^?(.*)$")
    if id then out[#out + 1] = { id = tonumber(id), v = tonumber(v), ago = tonumber(ago) * 60, by = by, name = name } end
  end
  return out
end
-- a question nobody had a price for gets answered when a scan brings one in (up to a day later)
local wantTimer = false
ns:Listen("MARKET", function()
  local w = ns.db and ns.db.marketWanted
  if not w or not next(w) or wantTimer then return end
  wantTimer = true
  C_Timer.After(5, function()
    wantTimer = false
    for q, at in pairs(w) do
      if ns.Now() - at > 86400 then w[q] = nil
      else
        local hits = M:Search(q, 1)
        if #hits > 0 and (hits[1].t or 0) >= at then w[q] = nil M:PostPrice(q, true) end
      end
    end
  end)
end)
