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
local SEND_EVERY = 1.0          -- seconds between price messages (one message ≈ 14 prices)
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

-- the newest scan time we have (what a friend who logs in asks about)
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

-- turn raw rows ({ id, buyout, count }) into prices, a few hundred rows per frame so the game never stalls
local function digest(rows, done)
  local byId, i = {}, 0
  local function step()
    local stop = math.min(#rows, i + 400)
    for k = i + 1, stop do
      local r = rows[k]
      if r.id and r.buyout and r.buyout > 0 and (r.count or 0) > 0 then
        byId[r.id] = byId[r.id] or {}
        table.insert(byId[r.id], { unit = r.buyout / r.count, n = r.count })
      end
    end
    i = stop
    M.status = "Working out prices … " .. math.floor(i / math.max(1, #rows) * 100) .. " %"
    ns:Fire("MARKET")
    if i < #rows then C_Timer.After(0, step) return end
    local t, changed, n = ns.Now(), {}, 0
    for id, list in pairs(byId) do
      local v = M.Value(list)
      local ok, old = M:Set(id, v, t, ns.pid)
      if ok then
        n = n + 1
        if not old or math.abs(v - old.v) > old.v * 0.05 then changed[#changed + 1] = id end
      end
    end
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
  if not can then
    M.status = "Next full scan in " .. ns.Duration(left)
    ns:Fire("MARKET")
    return
  end
  if self.scanning then return end
  self.scanning = true
  ns.db.marketFullAt = ns.Now()
  M.status = "Scanning the auction house …"
  ns:Fire("MARKET")
  if modern() then
    self.waitReplicate = true
    pcall(C_AuctionHouse.ReplicateItems)
    -- the list arrives with REPLICATE_ITEM_LIST_UPDATE (see below); give up after 60 s
    C_Timer.After(60, function()
      if M.waitReplicate then M.waitReplicate = nil M.scanning = nil M.status = "The auction house didn't answer – try again later" ns:Fire("MARKET") end
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
  ns:Fire("MARKET")
  ns.Cnt("marketScans")
  if #changed > 0 then M:Share(changed) end
  ns.Print("Market: " .. ns.Num(n) .. " prices updated" .. (#changed > 0 and (" – sharing " .. ns.Num(#changed) .. " changed ones with the gang") or "") .. ".")
end

ns:On("REPLICATE_ITEM_LIST_UPDATE", function()
  if not M.waitReplicate then return end
  M.waitReplicate = nil
  local rows = {}
  local okN, n = pcall(C_AuctionHouse.GetNumReplicateItems)
  for i = 0, (okN and n or 0) - 1 do
    local ok, _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, id = pcall(C_AuctionHouse.GetReplicateItemInfo, i)
    if ok and id then rows[#rows + 1] = { id = id, buyout = buyout, count = count } end
  end
  digest(rows, afterScan)
end)

-- classic list results: a full scan, or one of our quick bag checks
ns:On("AUCTION_ITEM_LIST_UPDATE", function()
  if not M.waitClassic then return end
  local kind = M.waitClassic
  M.waitClassic = nil
  local rows = {}
  local okN, n = pcall(GetNumAuctionItems, "list")
  for i = 1, (okN and n or 0) do
    local ok, _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, id = pcall(GetAuctionItemInfo, "list", i)
    if ok and id then rows[#rows + 1] = { id = id, buyout = buyout, count = count } end
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

local outbox, sending = {}, false
local function pump()
  local job = table.remove(outbox, 1)
  if not job then sending = false return end
  if job.to then Comm:SendTo(job.to, job.msg, 3) else Comm:Broadcast(job.msg, 3) end
  C_Timer.After(SEND_EVERY, pump)
end
local function queueIds(ids, to)
  local now, parts = ns.Now(), {}
  local function flush()
    if #parts == 0 then return end
    outbox[#outbox + 1] = { msg = Comm:Build("MK", table.concat(parts, ";")), to = to }
    parts = {}
  end
  for _, id in ipairs(ids) do
    local e = db()[id]
    if e then
      parts[#parts + 1] = b36(id) .. "," .. b36(e.v) .. "," .. b36(math.max(0, math.floor((now - e.t) / 60)))
      if #parts >= PER_MSG then flush() end
    end
  end
  flush()
  if not sending and #outbox > 0 then sending = true C_Timer.After(1, pump) end
end

function M:Share(ids)
  if not on() or ns.db.settings.marketShare == false then return end
  queueIds(ids)
end

Comm:Handle("MK", function(f, sender)
  if not on() then return end
  local n = 0
  for part in tostring(f[1] or ""):gmatch("[^;]+") do
    local a, b, c = part:match("^(%w+),(%w+),(%w+)$")
    local id, v, ago = a and un36(a), b and un36(b), c and un36(c)
    if id and v and ago then
      if M:Set(id, v, ns.Now() - ago * 60, ns.ShortName(sender or "")) then n = n + 1 end
    end
  end
  if n > 0 then
    M.heardFrom = ns.ShortName(sender or "")
    M.heardAt = ns.Now()
  end
end)

-- someone logged in: whoever has newer prices offers; the first to say "MA" sends
Comm:Handle("MQ", function(f, sender)
  if not on() or ns.db.settings.marketShare == false then return end
  local theirs = tonumber(f[1]) or 0
  local mine = M:Latest()
  if mine <= theirs + 300 or Comm:IsMe(sender) then return end
  local req = ns.ShortName(sender or "")
  M.answering = M.answering or {}
  local delay = 2 + math.random() * 6
  C_Timer.After(delay, function()
    if M.answering[req] and ns.Now() - M.answering[req] < 600 then return end   -- someone else took it
    M.answering[req] = ns.Now()
    Comm:Broadcast(Comm:Build("MA", req), 2)
    local ids = {}
    for id, e in pairs(db()) do if (e.t or 0) > theirs then ids[#ids + 1] = id end end
    table.sort(ids, function(a, b) return db()[a].t > db()[b].t end)
    while #ids > MAX_SYNC do table.remove(ids) end
    queueIds(ids, sender)
  end)
end)
-- (1.3.4) "MI": someone hovered items we may know the price of – answer those right away
local asked, askQueue, askTimer = {}, {}, false
function M:Ask(id)
  if not on() or not id or asked[id] and ns.Now() - asked[id] < 600 then return end
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
  C_Timer.After(0.3 + math.random() * 1.5, function() queueIds(have, sender) end)
end)

Comm:Handle("MA", function(f)
  M.answering = M.answering or {}
  if f[1] then M.answering[f[1]] = ns.Now() end
end)

ns:On("PLAYER_LOGIN", function()
  C_Timer.After(25, function()
    if not on() or not ns.db then return end
    M:Prune()
    Comm:Broadcast(Comm:Build("MQ", M:Latest()), 3)
  end)
end)

---------------------------------------------------------------------------
-- tooltip: one line, "Market  12g 34s  · 2h ago"
---------------------------------------------------------------------------
-- money with the gold / silver / copper coins, like the game's own tooltips
local function coins(copper)
  copper = math.floor(copper or 0)
  local f = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString
  if f then
    local ok, s = pcall(f, copper)
    if ok and type(s) == "string" and s ~= "" then return s end
  end
  local g, sv, c = math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = g .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t" end
  if sv > 0 then parts[#parts + 1] = sv .. "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t" end
  if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t" end
  return table.concat(parts, " ")
end
M.Coins = coins

-- how many are in the stack you're hovering (bag slots), else 1
local function hoveredCount(tt)
  local owner = tt and tt.GetOwner and tt:GetOwner()
  if not owner then return 1 end
  local okB, bag = pcall(function() return owner.GetBagID and owner:GetBagID() or (owner.GetParent and owner:GetParent() and owner:GetParent().GetID and owner:GetParent():GetID()) end)
  local okS, slot = pcall(function() return owner.GetID and owner:GetID() end)
  if okB and okS and type(bag) == "number" and type(slot) == "number" and C_Container and C_Container.GetContainerItemInfo then
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if ok and type(info) == "table" and type(info.stackCount) == "number" then return info.stackCount end
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

-- (1.3.2) the tooltip block:
--   Chillan? Market   4s each · 22 min ago
--   Stack of 20       39s 40c              (when you hover a stack)
--   Best: Auction     +35c over vendor     (after the auction house's 5 % cut)
--   Since last scan   +12 %                (when the price moved)
local function addLine(tt, id, count)
  if not on() or not id or not tt or not tt.AddDoubleLine then return end
  local e = M:Get(id)
  if not e then M:Ask(id) return end
  count = count or hoveredCount(tt)
  local old = ns.Now() - (e.t or 0) > STALE
  local age = ns.Ago(e.t)
  local each = count > 1 and " each" or ""
  if old then
    tt:AddDoubleLine("Market (old)", coins(e.v) .. each .. "  · " .. age, 0.55, 0.57, 0.6, 0.55, 0.57, 0.6)
  else
    tt:AddDoubleLine("|cffC69B6DChillan?|r Market", coins(e.v) .. each .. "  |cff858B92· " .. age .. "|r", 0.9, 0.9, 0.9, 1, 1, 1)
  end
  if count > 1 then tt:AddDoubleLine("Stack of " .. count, coins(e.v * count), 0.75, 0.78, 0.82, 1, 1, 1) end
  local sell = vendorPrice(id)
  if sell and sell > 0 then
    local net = math.floor(e.v * (1 - AH_CUT))
    local n = math.max(1, count)
    if net > sell then
      tt:AddDoubleLine("Best: Auction", "+" .. coins((net - sell) * n) .. " over vendor", 0.75, 0.78, 0.82, 0.37, 0.82, 0.55)
    elseif sell > net then
      tt:AddDoubleLine("Best: Vendor", "+" .. coins((sell - net) * n) .. " over auction", 0.75, 0.78, 0.82, 0.88, 0.69, 0.31)
    end
  end
  if e.p and e.p > 0 and not old then
    local pct = math.floor((e.v - e.p) / e.p * 100 + 0.5)
    if math.abs(pct) >= 5 then
      tt:AddDoubleLine("Since last scan", (pct > 0 and "+" or "") .. pct .. " %", 0.75, 0.78, 0.82,
        pct > 0 and 0.37 or 0.95, pct > 0 and 0.82 or 0.47, pct > 0 and 0.55 or 0.48)
    end
  end
  if tt.Show then tt:Show() end
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
-- the button on the auction house
---------------------------------------------------------------------------
function M:AttachButton()
  local host = (AuctionHouseFrame and AuctionHouseFrame:IsShown() and AuctionHouseFrame) or (AuctionFrame and AuctionFrame:IsShown() and AuctionFrame)
  if not host then return end
  local UI, C = ns.UI, ns.C
  if not self.button then
    local b = UI.Button(UIParent, 120, 24, "Chillan? scan", "secondary", function() M:FullScan() end)
    b:SetFrameStrata("HIGH")
    b.tooltip = "Scan the whole auction house (the game allows this once every 15 minutes). Prices go to your tooltips and to the gang."
    b.status = UI.Text(b, 11, nil, C.muted)
    b.status:SetPoint("RIGHT", b, "LEFT", -8, 0)
    b.status:SetJustifyH("RIGHT")
    self.button = b
    ns:Listen("MARKET", function() M:PaintButton() end)
  end
  self.button:SetParent(host)
  self.button:SetFrameLevel((host:GetFrameLevel() or 1) + 20)
  self.button:ClearAllPoints()
  -- (1.3.1) a tab along the bottom, right after the last tab of the auction house (its own, or ones
  -- other addons add); if none are found, a tab on top of the window
  local last, right
  local function consider(t)
    if t and t.IsShown and t:IsShown() and t.GetRight and t:GetRight() and (not right or t:GetRight() > right) then
      local b = t:GetBottom()
      local hb = host:GetBottom()
      if b and hb and math.abs(b - hb) < 60 then last, right = t, t:GetRight() end
    end
  end
  local name = host:GetName()
  if name then for i = 1, 20 do consider(_G[name .. "Tab" .. i]) end end
  if type(host.Tabs) == "table" then for _, t in ipairs(host.Tabs) do consider(t) end end
  if last then
    self.button:SetPoint("LEFT", last, "RIGHT", 6, 0)
  else
    self.button:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", -40, 2)
  end
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
  b:SetLabel(self.scanning and "Scanning …" or (can and "Chillan? scan" or ("Scan in " .. math.ceil(left / 60) .. " min")))
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
ns:On("AUCTION_HOUSE_SHOW", opened)
ns:On("AUCTION_HOUSE_CLOSED", function()
  M.bagChecking = nil
  bagQueue = {}
  if M.button then M.button:Hide() end
end)

ns:On("PLAYER_LOGIN", function() C_Timer.After(1, function() if on() then M:HookTooltips() end end) end)

function M:StatusText()
  local newest = self:Latest()
  return ns.Num(self:Count()) .. " prices" .. (newest > 0 and (", newest " .. ns.Ago(newest)) or "")
    .. (M.heardFrom and (" · last received from " .. M.heardFrom .. " " .. ns.Ago(M.heardAt)) or "")
    .. (#outbox > 0 and (" · sending " .. #outbox .. " messages") or "")
end

-- /chill selftest: what this auction house lets us do
function M:SelfTest()
  return (modern() and "modern (full scan via ReplicateItems)" or classic() and "classic (list queries)" or "none")
    .. " · " .. ns.Num(self:Count()) .. " prices stored"
end
