-- Chillan? – the Market window's engine (1.4.57)
-- Everything the window beside the auction house does with the game: what in your bags can be
-- posted, the listings of one item (asked one at a time, cached), posting, buying, your own
-- auctions and cancelling, a name search, your shopping list, and your sales – counted per week
-- and shared with the gang as totals for the Gang tab.
-- Posting, buying and cancelling each need a real click: nothing here runs by itself.
-- The rule for "auction or vendor" is the same everywhere (Naowh's): price each x 0.95 rounded
-- down, times the stack, against the vendor price.
local ADDON, ns = ...
local Comm = ns.Comm

local AH = {}
ns.AH = AH

AH.CUT = 0.05
AH.SEARCH_TIMEOUT = 5
AH.POST_TIMEOUT = 6
AH.BUY_TIMEOUT = 15
AH.MAX_ROWS = 50
AH.CACHE_FOR = 120          -- seconds a listing stays fresh
AH.SALES_DAYS = 30

local function now() return GetTime and GetTime() or 0 end
local function ok(fn, ...)
  local good, a, b, c = pcall(fn, ...)
  if good then return a, b, c end
end

function AH.AfterCut(price) return math.floor((price or 0) * (1 - AH.CUT)) end
function AH.Modern()
  return C_AuctionHouse ~= nil and C_AuctionHouse.PostCommodity ~= nil and C_AuctionHouse.SendSearchQuery ~= nil
end
function AH.On() return ns.db and ns.db.settings.mkWindow ~= false and AH.Modern() end
function AH.Vendor(id) return (ns.Market and ns.Market.VendorPrice and ns.Market.VendorPrice(id)) or 0 end
function AH.GangPrice(id)
  local e = ns.Market and ns.Market:Get(id)
  return e and e.v or nil
end
-- (1.4.59) the gang price from before your own search: browsing updates the price with what you
-- just saw, which made every result read 0 %
function AH.GangBefore(id)
  local e = ns.Market and ns.Market:Get(id)
  if not e then return nil end
  if AH.searchAt and (e.t or 0) >= AH.searchAt - 1 then return e.p end
  return e.v
end
-- the price trend for a list of history points: "rising", "falling" or "steady"
function AH.Trend(pts)
  if #pts < 3 then return nil end
  local n = math.min(3, math.floor(#pts / 2))
  local a, b = 0, 0
  for i = 1, n do a = a + pts[i].v b = b + pts[#pts - i + 1].v end
  a, b = a / n, b / n
  if a <= 0 then return nil end
  local ch = (b - a) / a
  return ch >= 0.05 and "rising" or ch <= -0.05 and "falling" or "steady", ch
end
-- the lowest price that still pays at least the vendor price after the cut
function AH.Floor(id)
  local v = AH.Vendor(id)
  if v <= 0 then return 1 end
  return math.ceil(v / (1 - AH.CUT))
end
function AH.Copper()
  local f = C_AuctionHouse and C_AuctionHouse.SupportsCopperValues
  if not f then return true end
  return ok(f) ~= false
end
-- 1c under (1s under, rounded to silver, where the game takes no copper)
function AH.Under(price)
  if AH.Copper() then return math.max(1, price - 1) end
  return math.max(100, math.floor((price - 1) / 100) * 100)
end
function AH.Round(price)
  if AH.Copper() then return math.max(1, math.floor(price)) end
  return math.max(100, math.ceil(price / 100) * 100)
end

local function db()
  ns.db.mkAH = ns.db.mkAH or {}
  local d = ns.db.mkAH
  d.shop = d.shop or {}
  d.saved = d.saved or {}
  d.recent = d.recent or {}
  d.hidden = d.hidden or {}
  return d
end
AH.DB = db

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------
local function on(event, fn) ns:On(event, fn) end
AH.On_ = on

local function changed(what) ns:Fire("MKAH", what) end

---------------------------------------------------------------------------
-- keys: a commodity is its item id; an item is id:level:suffix
---------------------------------------------------------------------------
function AH.KeyOf(itemKey, commodity, itemID)
  if commodity then return itemID or (itemKey and itemKey.itemID) end
  if not itemKey then return itemID end
  return itemKey.itemID .. ":" .. (itemKey.itemLevel or 0) .. ":" .. (itemKey.itemSuffix or 0)
end

---------------------------------------------------------------------------
-- bags: what the auction house takes, one entry per item
---------------------------------------------------------------------------
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
local here

function AH.ReadBags()
  local out, byKey = {}, {}
  local loading = false
  if not here and ItemLocation and ItemLocation.CreateEmpty then here = ItemLocation:CreateEmpty() end
  if not (C_Container and here) then return out, loading end
  local COMMODITY = Enum and Enum.ItemCommodityStatus and Enum.ItemCommodityStatus.Commodity or 2
  local UNKNOWN = Enum and Enum.ItemCommodityStatus and Enum.ItemCommodityStatus.Unknown or 0
  for bag = 0, LAST_BAG do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and not info.isBound and info.itemID then
        here:SetBagAndSlot(bag, slot)
        if ok(C_AuctionHouse.IsSellItemValid, here, false) then
          local status = ok(C_AuctionHouse.GetItemCommodityStatus, here)
          if status == UNKNOWN or status == nil then
            loading = true
            if C_Item.RequestLoadItemData then pcall(C_Item.RequestLoadItemData, here) end
          else
            local commodity = status == COMMODITY
            local key = commodity and info.itemID or info.hyperlink
            local e = byKey[key]
            if not e then
              e = { key = key, itemID = info.itemID, link = info.hyperlink, icon = info.iconFileID, quality = info.quality,
                commodity = commodity, bag = bag, slot = slot, count = 0 }
              if not commodity then
                local ik = ok(C_AuctionHouse.GetItemKeyFromItem, here)
                e.itemKey = ik
              end
              e.name = (info.hyperlink and info.hyperlink:match("%[(.-)%]")) or ("item " .. info.itemID)
              byKey[key] = e
              out[#out + 1] = e
            end
            e.count = e.count + (info.stackCount or 1)
          end
        end
      end
    end
  end
  return out, loading
end

local function holds(e, info)
  return info and info.itemID == e.itemID and not info.isLocked and (e.commodity or info.hyperlink == e.link)
end
function AH.Location(e)
  if not (C_Container and ItemLocation) then return nil end
  local bag, slot
  if e.bag and holds(e, C_Container.GetContainerItemInfo(e.bag, e.slot)) then bag, slot = e.bag, e.slot end
  if not bag then
    for b = 0, LAST_BAG do
      for s = 1, (C_Container.GetContainerNumSlots(b) or 0) do
        if holds(e, C_Container.GetContainerItemInfo(b, s)) then bag, slot = b, s break end
      end
      if bag then break end
    end
  end
  if not bag then return nil end
  e.bag, e.slot = bag, slot
  return ItemLocation:CreateFromBagAndSlot(bag, slot)
end

---------------------------------------------------------------------------
-- listings: one item's auctions, cheapest first. Asked one at a time; answers are cached.
---------------------------------------------------------------------------
local cache, queue = {}, {}
local active
local gen = 0
AH.cache = cache

local function sorts(commodity)
  local O = Enum and Enum.AuctionHouseSortOrder or {}
  if commodity then return { { sortOrder = O.Price or 0, reverseSort = false } } end
  return { { sortOrder = O.Buyout or 4, reverseSort = false }, { sortOrder = O.Bid or 3, reverseSort = false } }
end

function AH.Listing(key) return key and cache[key] end
-- cheapest price that isn't yours, cheapest of yours
function AH.Cheapest(key)
  local L = cache[key]
  if not L or not L.rows then return nil end
  local other, own
  for _, r in ipairs(L.rows) do
    if not own and r.own > 0 then own = r.price end
    if not other and r.qty > r.own then other = r.price end
    if other and own then break end
  end
  return other, own
end

local pump
local function finish(state, rows)
  if not active then return end
  local a = active
  active = nil
  cache[a.key] = { rows = rows or {}, at = now(), state = state, commodity = a.commodity, itemID = a.itemID, itemKey = a.itemKey }
  local other = AH.Cheapest(a.key)
  if other then AH.CheckAlert(a.itemID, other) end
  changed("listing")
  for _, cb in ipairs(a.cbs or {}) do pcall(cb, a.key, cache[a.key]) end
  C_Timer.After(0.1, pump)
end

local function send(a)
  if a.commodity then
    C_AuctionHouse.SendSearchQuery(C_AuctionHouse.MakeItemKey(a.itemID), sorts(true), true)
    return true
  end
  local key = a.itemKey
  if not key and a.bagEntry then
    local loc = AH.Location(a.bagEntry)
    key = loc and ok(C_AuctionHouse.GetItemKeyFromItem, loc)
  end
  if not key then key = C_AuctionHouse.MakeItemKey(a.itemID) end
  a.itemKey = key
  local equip = C_Item.IsEquippableItem and ok(C_Item.IsEquippableItem, a.itemID)
  if equip and C_AuctionHouse.SendSellSearchQuery then
    local k = { itemID = key.itemID, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = key.battlePetSpeciesID or 0 }
    a.anyLevel = true
    C_AuctionHouse.SendSellSearchQuery(k, sorts(false), true)
  else
    C_AuctionHouse.SendSearchQuery(key, sorts(false), true)
  end
  return true
end

pump = function()
  if not AH.Modern() then return end
  if active or #queue == 0 or not AH.open then return end
  if not ok(C_AuctionHouse.IsThrottledMessageSystemReady) then
    C_Timer.After(0.5, pump)
    return
  end
  active = table.remove(queue, 1)
  gen = gen + 1
  local my = gen
  if not pcall(send, active) then return finish("noanswer") end
  C_Timer.After(AH.SEARCH_TIMEOUT, function() if active and gen == my then finish("noanswer") end end)
end

-- req: { key, itemID, commodity, itemKey?, bagEntry? }; cb(key, listing) when it arrives
function AH.Ask(req, cb, force, urgent)
  if not req or not req.key or not AH.open then return end
  local c = cache[req.key]
  if c and not force and now() - c.at < AH.CACHE_FOR then
    if cb then cb(req.key, c) end
    return
  end
  if active and active.key == req.key then
    if cb then active.cbs = active.cbs or {} table.insert(active.cbs, cb) end
    return
  end
  for _, q in ipairs(queue) do
    if q.key == req.key then
      if cb then q.cbs = q.cbs or {} table.insert(q.cbs, cb) end
      return
    end
  end
  local a = { key = req.key, itemID = req.itemID, commodity = req.commodity, itemKey = req.itemKey, bagEntry = req.bagEntry, cbs = cb and { cb } or nil }
  if urgent then table.insert(queue, 1, a) else queue[#queue + 1] = a end
  pump()
end
function AH.Busy() return active ~= nil, #queue end

local function readCommodities(itemID)
  local rows = {}
  local n = ok(C_AuctionHouse.GetNumCommoditySearchResults, itemID) or 0
  for i = 1, math.min(n, AH.MAX_ROWS) do
    local r = ok(C_AuctionHouse.GetCommoditySearchResultInfo, itemID, i)
    if r and r.unitPrice then
      rows[#rows + 1] = { price = r.unitPrice, qty = r.quantity or 0, own = r.numOwnerItems or 0, auctionID = r.auctionID }
    end
  end
  return rows
end
local function readItems(itemKey)
  local rows = {}
  local n = ok(C_AuctionHouse.GetNumItemSearchResults, itemKey) or 0
  for i = 1, math.min(n, AH.MAX_ROWS) do
    local r = ok(C_AuctionHouse.GetItemSearchResultInfo, itemKey, i)
    local price = r and r.buyoutAmount
    if price then
      local own = r.containsOwnerItem and (r.quantity or 1) or 0
      local last = rows[#rows]
      if last and last.price == price then
        last.qty, last.own = last.qty + (r.quantity or 1), last.own + own
        if not r.containsOwnerItem and not last.auctionID then last.auctionID = r.auctionID end
      else
        rows[#rows + 1] = { price = price, qty = r.quantity or 1, own = own, auctionID = (not r.containsOwnerItem) and r.auctionID or nil }
      end
    end
  end
  return rows
end

on("COMMODITY_SEARCH_RESULTS_UPDATED", function(itemID)
  if active and active.commodity and itemID == active.itemID then finish("listed", readCommodities(itemID)) end
end)
on("ITEM_SEARCH_RESULTS_UPDATED", function(itemKey)
  if active and not active.commodity and type(itemKey) == "table" and itemKey.itemID == active.itemID then
    finish("listed", readItems(itemKey))
  end
end)
on("AUCTION_HOUSE_THROTTLED_SYSTEM_READY", function() pump() end)

-- the price to post at: 1c under the cheapest listing that isn't yours; the gang price when
-- nothing is listed; never under what the vendor pays (after the cut). Returns price, why.
function AH.SuggestPrice(e)
  local floor = AH.Floor(e.itemID)
  local other, own = AH.Cheapest(e.key)
  local p, why
  if other then p, why = AH.Under(other), "1c under the cheapest"
  elseif own then p, why = own, "matches yours"
  else
    local g = AH.GangPrice(e.itemID)
    if g then p, why = AH.Round(g), "gang price (nothing listed)" end
  end
  if not p then return AH.Round(floor), "vendor price after the cut" end
  if p < floor then return AH.Round(floor), "not under the vendor price" end
  return p, why
end

---------------------------------------------------------------------------
-- stats: what you posted and sold, per week, shared as totals
---------------------------------------------------------------------------
local function blank() return { g = 0, i = 0, s = 0, p = 0 } end
function AH.Stats()
  ns.db.mkStats = ns.db.mkStats or {}
  local s = ns.db.mkStats
  s.t = s.t or blank()
  s.sales = s.sales or {}
  s.seen = s.seen or {}
  local wk = ns.WeekKey()
  if s.wk ~= wk then
    if s.wk and s.wk == ns.PrevWeekKey() and s.w then s.pw = s.w s.pw.wk = s.wk else s.pw = s.pw and s.pw.wk == ns.PrevWeekKey() and s.pw or nil end
    s.w = blank()
    s.wk = wk
  end
  s.w = s.w or blank()
  return s
end
function AH.NotePosted(n)
  local s = AH.Stats()
  s.w.p, s.t.p = s.w.p + (n or 1), s.t.p + (n or 1)
  AH.dirty = true
end
function AH.NoteSale(auctionID, itemID, qty, total)
  if not (auctionID and itemID and total and total > 0) then return false end
  local s = AH.Stats()
  local k = auctionID .. ":" .. (qty or 1)
  if s.seen[k] then return false end
  local t = ns.Now()
  s.seen[k] = t
  local net = AH.AfterCut(total)
  s.w.g, s.w.i, s.w.s = s.w.g + net, s.w.i + (qty or 1), s.w.s + 1
  s.t.g, s.t.i, s.t.s = s.t.g + net, s.t.i + (qty or 1), s.t.s + 1
  table.insert(s.sales, 1, { id = itemID, q = qty or 1, g = net, at = t })
  local oldest = t - AH.SALES_DAYS * 86400
  while #s.sales > 500 or (s.sales[#s.sales] and s.sales[#s.sales].at < oldest) do table.remove(s.sales) end
  for key, at in pairs(s.seen) do if at < t - 3 * 86400 then s.seen[key] = nil end end
  AH.dirty = true
  return true
end
-- (1.4.70) what a sold auction brought in, before the cut. The game's amount for a sold stack is
-- sometimes the price per item and sometimes the whole stack (a stack of Glory Dew counted as 91g:
-- the stack price times the count again). Judge it against what you asked per item when you posted
-- it, else against the market value; when it's still unclear, take the smaller reading.
function AH.SaleTotal(itemID, qty, amount, commodity)
  qty = math.max(1, qty or 1)
  if qty == 1 then return amount end
  local asked = (AH.Stats().unit or {})[itemID]
  local unit = asked and asked.p
  if not unit and ns.Market and ns.Market.Get then
    local e = ns.Market:Get(itemID)
    unit = e and e.v
  end
  if unit and unit > 0 then
    -- whichever reading lands closer to "unit price x count"
    local asTotal, asUnit = amount, amount * qty
    local want = unit * qty
    return (math.abs(asTotal - want) <= math.abs(asUnit - want)) and asTotal or asUnit
  end
  return amount
end

-- (1.4.72) a stack sale counted "count times too big" by Chillan before 1.4.70 (97 Iron Bars as 272g):
-- when the price per item is far above the gang price and the price divided by the count again
-- lands near it, the count was in there twice
function AH.FixStack(id, q, g)
  q = tonumber(q) or 1
  if q <= 1 or not g or g <= 0 then return g end
  local ref = AH.GangPrice(id)
  if (not ref or ref <= 0) and ns.Market and ns.Market.Get then local e = ns.Market:Get(id) ref = e and e.v end
  if not ref or ref <= 0 then return g end
  local per, twice = g / q, g / q / q
  if per > ref * 4 and math.abs(math.log(twice / ref)) < math.abs(math.log(per / ref)) then return math.floor(g / q) end
  return g
end
-- your own list of sales put right once (it is what the gang sees of you)
function AH.RepairSales()
  local s = AH.Stats()
  if s.fixQ then return end
  if not ns.db.market or not next(ns.db.market) then return end   -- needs the gang prices
  s.fixQ = true
  local monday = ns.MondayOf and ns.MondayOf(ns.Now()) or (ns.Now() - 7 * 86400)
  local fixed = 0
  for _, x in ipairs(s.sales) do
    local g = AH.FixStack(x.id, x.q, x.g)
    if g ~= x.g then
      local d = x.g - g
      x.g = g
      s.t.g = math.max(0, s.t.g - d)
      if x.at >= monday then s.w.g = math.max(0, s.w.g - d) end
      fixed = fixed + 1
    end
  end
  if fixed > 0 then AH.dirty = true AH.Trace("put right " .. fixed .. " stack sales counted too big") end
end
ns:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(20, function() pcall(AH.RepairSales) end) end)

-- gold after the cut and number of sales in the last n seconds
function AH.SoldSince(sec)
  local s = AH.Stats()
  local from, g, n = ns.Now() - sec, 0, 0
  for _, x in ipairs(s.sales) do if x.at >= from then g, n = g + x.g, n + 1 end end
  return g, n
end
-- your biggest sales since a time, biggest first
function AH.TopSales(from, max)
  local out = {}
  for _, x in ipairs(AH.Stats().sales) do if x.at >= from then out[#out + 1] = x end end
  table.sort(out, function(a, b) return a.g > b.g end)
  while #out > (max or 3) do table.remove(out) end
  return out
end

local function b36(n) n = math.floor(n or 0) if n <= 0 then return "0" end local s = "" local d = "0123456789abcdefghijklmnopqrstuvwxyz" while n > 0 do local r = n % 36 s = d:sub(r + 1, r + 1) .. s n = math.floor(n / 36) end return s end
local function un36(s) return tonumber(s or "", 36) or 0 end

function AH.BuildShare()
  local s = AH.Stats()
  local pw = s.pw or blank()
  local tops = {}
  for _, x in ipairs(AH.TopSales(ns.MondayOf and ns.MondayOf(ns.Now()) or (ns.Now() - 7 * 86400), 3)) do
    tops[#tops + 1] = b36(x.id) .. "," .. b36(x.q) .. "," .. b36(x.g) .. "," .. b36(math.floor((ns.Now() - x.at) / 60))
  end
  return Comm:Build("MG", ns.pid, s.wk or "",
    b36(s.w.g), b36(s.w.i), b36(s.w.s), b36(s.w.p),
    pw.wk or "", b36(pw.g), b36(pw.i), b36(pw.s), b36(pw.p),
    b36(s.t.g), b36(s.t.i), b36(s.t.s), b36(s.t.p), table.concat(tops, ";"))
end
function AH.Share(to)
  if not ns.pid or not Comm or not Comm.Broadcast then return end
  if ns.CommBlind and ns.CommBlind() then return end
  local msg = AH.BuildShare()
  if to then Comm:SendTo(to, msg, 3) else Comm:Broadcast(msg, 3) end
  AH.dirty = false
end
if Comm and Comm.Handle then
  Comm:Handle("MG", function(f)
    local pid = f[1]
    if not pid or pid == "" or pid == ns.pid then return end
    local p = ns:GetPerson(pid, true)
    local function v(i) return un36(f[i]) end
    local tops = {}
    for part in tostring(f[16] or ""):gmatch("[^;]+") do
      local a, b, c, d = part:match("^(%w+),(%w+),(%w+),(%w+)$")
      if a then tops[#tops + 1] = { id = un36(a), q = un36(b), g = un36(c), at = ns.Now() - un36(d) * 60 } end
    end
    p.mk = { wk = f[2], w = { g = v(3), i = v(4), s = v(5), p = v(6) }, pwk = f[7], pw = { g = v(8), i = v(9), s = v(10), p = v(11) },
      t = { g = v(12), i = v(13), s = v(14), p = v(15) }, tops = tops, at = ns.Now() }
    changed("gang")
  end)
  Comm:Handle("MGQ", function(_, sender)
    if Comm:IsMe(sender) then return end
    if AH.repliedAt and ns.Now() - AH.repliedAt < 60 then return end
    AH.repliedAt = ns.Now()
    C_Timer.After(2 + math.random() * 6, function() AH.Share() end)
  end)
end
function AH.AskGang()
  if AH.askedAt and ns.Now() - AH.askedAt < 300 then return end
  AH.askedAt = ns.Now()
  if ns.CommBlind and ns.CommBlind() then return end
  Comm:Broadcast(Comm:Build("MGQ"), 3)
end
ns:On("PLAYER_LOGIN", function() C_Timer.After(45, function() AH.Stats() AH.Share() end) end)

---------------------------------------------------------------------------
-- posting
---------------------------------------------------------------------------
local post = {}
AH.post = post
-- (dev4) test builds say in chat what the post did, so a dead Post button can be told apart
function AH.Trace(msg)
  if ns.VERSION and ns.VERSION:find("dev", 1, true) then ns.Print("|cff808080Market trace: " .. msg .. "|r") end
end
local function postDone(good)
  if not post.waiting then return end
  AH.Trace(good and "posted" or "not posted (no answer or an error from the auction house)")
  post.waiting, post.confirm = false, nil
  post.gen = (post.gen or 0) + 1
  if good then AH.NotePosted(post.n or 1) end
  local cb = post.cb
  post.cb = nil
  if cb then pcall(cb, good) end
  changed("posted")
end
local function postWait()
  post.gen = (post.gen or 0) + 1
  local my = post.gen
  C_Timer.After(AH.POST_TIMEOUT, function() if post.waiting and post.gen == my then postDone(false) end end)
end
local function hookWarning()
  if post.hooked or not StaticPopupDialogs or not StaticPopupDialogs.AUCTION_HOUSE_POST_WARNING then return end
  post.hooked = true
  local d = StaticPopupDialogs.AUCTION_HOUSE_POST_WARNING
  hooksecurefunc(d, "OnAccept", function()
    local a = post.confirm
    if not a then return end
    post.confirm = nil
    if a.commodity then C_AuctionHouse.ConfirmPostCommodity(a.loc, a.duration, a.qty, a.price)
    else C_AuctionHouse.ConfirmPostItem(a.loc, a.duration, a.qty, nil, a.price) end
    postWait()
  end)
  hooksecurefunc(d, "OnHide", function() if post.confirm then postDone(false) end end)
end
function AH.CanPost() return not post.waiting and ok(C_AuctionHouse.IsThrottledMessageSystemReady) and true or false end
function AH.WhyNot()
  if post.waiting then return "still waiting for the last post" end
  if not ok(C_AuctionHouse.IsThrottledMessageSystemReady) then return "the auction house is busy (throttled)" end
end
function AH.PostWaiting() return post.waiting end
function AH.Deposit(e, qty, duration)
  local d
  if e.commodity then d = ok(C_AuctionHouse.CalculateCommodityDeposit, e.itemID, duration, qty)
  else
    local loc = AH.Location(e)
    d = loc and ok(C_AuctionHouse.CalculateItemDeposit, loc, duration, qty)
  end
  return d
end
-- must run from a click
function AH.Post(e, qty, price, duration, cb)
  if not AH.CanPost() then return false end
  local loc = AH.Location(e)
  if not loc then return false end
  -- (dev4) nothing else happens in the click any more: touching the game's own sell frame here (before
  -- or after) spoiled the post. It is emptied when the auction house opens instead.
  AH.Trace("post " .. (e.commodity and "commodity" or "item") .. " " .. tostring(e.itemID) .. " x" .. qty .. " @" .. price)
  local need
  if e.commodity then need = C_AuctionHouse.PostCommodity(loc, duration, qty, price)
  else need = C_AuctionHouse.PostItem(loc, duration, qty, nil, price) end
  post.waiting, post.cb, post.multi = true, cb, (not e.commodity and qty > 1)
  post.n = e.commodity and 1 or qty
  post.key, post.itemID, post.unit, post.at = e.key, e.itemID, price, ns.Now()
  -- what you asked per item, so a sale can be counted right later (see NoteSale)
  local st = AH.Stats()
  st.unit = st.unit or {}
  st.unit[e.itemID] = { p = price, commodity = e.commodity and true or nil, at = ns.Now() }
  if need then
    post.confirm = { commodity = e.commodity, loc = loc, duration = duration, qty = qty, price = price }
    hookWarning()
    AH.Trace("the game asks to confirm this post")
    -- (dev5) no confirm box ever came: let go after 15 s, or Post stayed off for good
    local my = (post.gen or 0) + 1
    post.gen = my
    C_Timer.After(15, function() if post.waiting and post.confirm and post.gen == my then post.confirm = nil postDone(false) end end)
  else
    postWait()
  end
  return true
end
on("AUCTION_HOUSE_AUCTION_CREATED", function()
  if not post.waiting or post.confirm then return end
  if post.multi then postWait() else postDone(true) end
end)
on("AUCTION_MULTISELL_UPDATE", function(created, total)
  if not post.waiting or post.confirm then return end
  if (created or 0) >= (total or 0) then postDone(true) else postWait() end
end)
on("AUCTION_MULTISELL_FAILURE", function() postDone(false) end)
on("AUCTION_HOUSE_POST_ERROR", function() postDone(false) end)

---------------------------------------------------------------------------
-- buying
---------------------------------------------------------------------------
local buy = {}
AH.buy = buy
local function buyEnd(good)
  if not buy.state then return end
  if buy.itemID and not good and buy.state ~= "buying" then pcall(C_AuctionHouse.CancelCommoditiesPurchase) end
  local cb, key = buy.cb, buy.key
  buy.state, buy.cb = nil, nil
  buy.gen = (buy.gen or 0) + 1
  if cb then pcall(cb, good) end
  changed("bought")
  -- what's left on the auction house changed
  if key and cache[key] then cache[key].at = 0 end
end
local function buyTimer()
  buy.gen = (buy.gen or 0) + 1
  local my = buy.gen
  C_Timer.After(AH.BUY_TIMEOUT, function() if buy.state and buy.gen == my then buyEnd(false) end end)
end
function AH.Buying() return buy.state, buy.total, buy.key end
-- step 1 for a commodity (a click): the game quotes the price
function AH.Quote(key, itemID, qty, unit, cb)
  if buy.state then return false end
  buy.state, buy.itemID, buy.qty, buy.key, buy.total, buy.auctionID, buy.cb = "quoting", itemID, qty, key, nil, nil, cb
  buyTimer()
  C_AuctionHouse.StartCommoditiesPurchase(itemID, qty, unit)
  return true
end
-- step 2 (another click): pay
function AH.Confirm()
  if buy.state ~= "quoted" then return false end
  buy.state = "buying"
  buyTimer()
  C_AuctionHouse.ConfirmCommoditiesPurchase(buy.itemID, buy.qty)
  return true
end
-- an item (not a commodity): one auction at its buyout, one click
function AH.BuyItem(key, auctionID, price, cb)
  if buy.state then return false end
  buy.state, buy.itemID, buy.qty, buy.key, buy.total, buy.auctionID, buy.cb = "buying", nil, 1, key, price, auctionID, cb
  buyTimer()
  C_AuctionHouse.PlaceBid(auctionID, price)
  return true
end
function AH.Drop() if buy.state then buyEnd(false) end end
on("COMMODITY_PRICE_UPDATED", function(unit, total)
  if buy.state ~= "quoting" then return end
  buy.state, buy.total = "quoted", total
  changed("quote")
end)
on("COMMODITY_PRICE_UNAVAILABLE", function() buyEnd(false) end)
on("COMMODITY_PURCHASE_SUCCEEDED", function() if buy.state == "buying" then buyEnd(true) end end)
on("COMMODITY_PURCHASE_FAILED", function() buyEnd(false) end)
on("AUCTION_HOUSE_PURCHASE_COMPLETED", function(id) if buy.state == "buying" and id == buy.auctionID then buyEnd(true) end end)
on("AUCTION_HOUSE_SHOW_ERROR", function() if buy.state == "buying" then buyEnd(false) end end)

---------------------------------------------------------------------------
-- your auctions
---------------------------------------------------------------------------
AH.owned = {}
local wantOwned
local function askOwned()
  if not AH.Modern() then return end
  if not wantOwned or not AH.open or not ok(C_AuctionHouse.IsThrottledMessageSystemReady) then return end
  wantOwned = false
  local O = Enum and Enum.AuctionHouseSortOrder or {}
  pcall(C_AuctionHouse.QueryOwnedAuctions, { { sortOrder = O.Name or 1, reverseSort = false } })
end
function AH.RefreshOwned() wantOwned = true askOwned() end
on("AUCTION_HOUSE_THROTTLED_SYSTEM_READY", askOwned)
on("AUCTION_CANCELED", function() AH.RefreshOwned() end)
on("OWNED_AUCTIONS_UPDATED", function()
  local SOLD = Enum and Enum.AuctionStatus and Enum.AuctionStatus.Sold or 1
  local list = {}
  for i = 1, (ok(C_AuctionHouse.GetNumOwnedAuctions) or 0) do
    local a = ok(C_AuctionHouse.GetOwnedAuctionInfo, i)
    if a and a.itemKey then
      local info = ok(C_AuctionHouse.GetItemKeyInfo, a.itemKey)
      local commodity = info and info.isCommodity
      local x = { auctionID = a.auctionID, itemKey = a.itemKey, itemID = a.itemKey.itemID, link = a.itemLink, qty = a.quantity or 1,
        price = a.buyoutAmount, secs = a.timeLeftSeconds, sold = a.status == SOLD, commodity = commodity,
        name = (info and info.itemName) or (a.itemLink and a.itemLink:match("%[(.-)%]")), quality = info and info.quality,
        icon = info and info.iconFileID }
      x.key = commodity ~= nil and AH.KeyOf(a.itemKey, commodity, x.itemID) or nil
      list[#list + 1] = x
      if x.sold then
        local price = a.buyoutAmount or a.bidAmount
        if price then AH.NoteSale(a.auctionID, x.itemID, x.qty, AH.SaleTotal(x.itemID, x.qty, price, commodity)) end
      end
    end
  end
  AH.owned = list
  changed("owned")
end)
-- "lowest", "undercut", "sold", "checking", "noanswer"; and by how much
function AH.Status(x)
  if x.sold then return "sold" end
  if not x.key then return "checking" end
  local L = cache[x.key]
  if not L then return "checking" end
  if L.state ~= "listed" then return "noanswer" end
  local other = AH.Cheapest(x.key)
  if not other or not x.price then return "lowest" end
  if other < x.price then return "undercut", x.price - other, other end
  return "lowest", 0, other
end
function AH.CheckOwned(force)
  for _, x in ipairs(AH.owned) do
    if not x.sold and x.key then AH.Ask({ key = x.key, itemID = x.itemID, commodity = x.commodity, itemKey = x.itemKey }, nil, force) end
  end
end
function AH.NextUndercut()
  for _, x in ipairs(AH.owned) do
    if AH.Status(x) == "undercut" and not x.cancelled and ok(C_AuctionHouse.CanCancelAuction, x.auctionID) then return x end
  end
end
-- must run from a click
function AH.Cancel(x)
  if not x or x.cancelled or not ok(C_AuctionHouse.CanCancelAuction, x.auctionID) then return false end
  C_AuctionHouse.CancelAuction(x.auctionID)
  x.cancelled = true
  changed("owned")
  return true
end

---------------------------------------------------------------------------
-- search by name
---------------------------------------------------------------------------
AH.results = {}
AH.searching = false
function AH.Search(text)
  text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" or not AH.open then return false end
  local d = db()
  for i = #d.recent, 1, -1 do if d.recent[i]:lower() == text:lower() then table.remove(d.recent, i) end end
  table.insert(d.recent, 1, text)
  while #d.recent > 6 do table.remove(d.recent) end
  local O = Enum and Enum.AuctionHouseSortOrder or {}
  local q = { searchString = text, sorts = { { sortOrder = O.Price or 0, reverseSort = false } }, filters = {}, itemClassFilters = {} }
  AH.results, AH.searching, AH.searchText, AH.searchAt = {}, true, text, ns.Now()
  local good = pcall(C_AuctionHouse.SendBrowseQuery, q)
  if not good then AH.searching = false end
  changed("results")
  return good
end
local function readBrowse(list)
  for _, r in ipairs(list or {}) do
    if r.itemKey then
      local info = ok(C_AuctionHouse.GetItemKeyInfo, r.itemKey)
      AH.results[#AH.results + 1] = { itemKey = r.itemKey, itemID = r.itemKey.itemID, minPrice = r.minPrice, qty = r.totalQuantity,
        name = info and info.itemName, quality = info and info.quality, icon = info and info.iconFileID, commodity = info and info.isCommodity }
    end
  end
end
on("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function()
  if not AH.searching then return end
  AH.results = {}
  readBrowse(ok(C_AuctionHouse.GetBrowseResults))
  AH.searching = false
  changed("results")
end)
on("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", function(added)
  if AH.searchText and not AH.searching then readBrowse(added) changed("results") end
end)
on("AUCTION_HOUSE_BROWSE_FAILURE", function() if AH.searching then AH.searching = false changed("results") end end)
on("ITEM_KEY_ITEM_INFO_RECEIVED", function()
  for _, r in ipairs(AH.results) do
    if not r.name then
      local info = ok(C_AuctionHouse.GetItemKeyInfo, r.itemKey)
      if info then r.name, r.quality, r.icon, r.commodity = info.itemName, info.quality, info.iconFileID, info.isCommodity end
    end
  end
  for _, x in ipairs(AH.owned) do
    if x.commodity == nil then
      local info = ok(C_AuctionHouse.GetItemKeyInfo, x.itemKey)
      if info then
        x.commodity, x.name, x.quality, x.icon = info.isCommodity, x.name or info.itemName, info.quality, info.iconFileID
        x.key = AH.KeyOf(x.itemKey, x.commodity, x.itemID)
      end
    end
  end
  changed("names")
end)
-- a result's key for listings
function AH.ResultReq(r)
  return { key = AH.KeyOf(r.itemKey, r.commodity, r.itemID), itemID = r.itemID, commodity = r.commodity, itemKey = r.itemKey }
end

---------------------------------------------------------------------------
-- Item Tracker (yours only; was the shopping list): items you follow, each with an optional price
-- alert ("tell me when it's under 190g")
---------------------------------------------------------------------------
function AH.ShopList()
  local l = db().shop
  -- (1.4.61) the old "most you'll pay" becomes the alert
  for _, s in ipairs(l) do if s.max and not s.alert and not s.migrated then s.alert, s.migrated = s.max, true end end
  return l
end
function AH.ShopAdd(id, alert)
  if not id then return false end
  for _, s in ipairs(db().shop) do
    if s.id == id then if alert then s.alert = alert end return true end
  end
  table.insert(db().shop, { id = id, want = 1, alert = alert })
  changed("shop")
  return true
end
function AH.SetAlert(id, alert)
  for _, s in ipairs(db().shop) do if s.id == id then s.alert, s.alertAt, s.alertPrice = alert, nil, nil end end
  changed("shop")
end
-- a price seen for a tracked item: under its alert, say so (once per half hour, or when cheaper still)
function AH.CheckAlert(id, price)
  if not (id and price and ns.db and ns.db.mkAH) then return end
  for _, s in ipairs(ns.db.mkAH.shop or {}) do
    if s.id == id and s.alert and price <= s.alert then
      local t = ns.Now()
      if s.alertAt and t - s.alertAt < 1800 and price >= (s.alertPrice or math.huge) then return end
      s.alertAt, s.alertPrice = t, price
      local okI, name, link = pcall(C_Item.GetItemInfo, id)
      local m = ns.Market and ns.Market.Coins or tostring
      ns.Print("Item Tracker: " .. ((okI and (link or name)) or ("item " .. id)) .. " is " .. m(price) .. ", under your alert of " .. m(s.alert) .. ".")
      if ns.Sound then ns.Sound("notify") end
      changed("alert")
      return
    end
  end
end
function AH.ShopRemove(id)
  local l = db().shop
  for i = #l, 1, -1 do if l[i].id == id then table.remove(l, i) end end
  changed("shop")
end
function AH.Have(id)
  local f = (C_Item and C_Item.GetItemCount) or GetItemCount
  return (f and ok(f, id, true)) or 0
end
-- a shopping entry as a listing request (commodity or not, from the item itself)
function AH.ShopReq(s)
  local commodity = true
  local okI, _, _, _, _, _, _, _, stack = pcall(C_Item.GetItemInfo, s.id)
  if okI and type(stack) == "number" and stack <= 1 then commodity = false end
  if C_Item.IsEquippableItem and ok(C_Item.IsEquippableItem, s.id) then commodity = false end
  return { key = commodity and s.id or (s.id .. ":0:0"), itemID = s.id, commodity = commodity, itemKey = (not commodity) and C_AuctionHouse.MakeItemKey(s.id) or nil }
end

---------------------------------------------------------------------------
-- the auction house opening and closing
---------------------------------------------------------------------------
on("AUCTION_HOUSE_SHOW", function()
  -- the game's sell frame may hold an item from last time: let it go now, outside any click
  C_Timer.After(0.2, function()
    local f = _G.AuctionHouseFrame
    if f and f.ClearPostItem and not InCombatLockdown() then pcall(f.ClearPostItem, f) end
  end)
  if not AH.Modern() then return end   -- the classic auction house: only the scan button there
  AH.open = true
  AH.Stats()
  AH.RefreshOwned()
  changed("open")
end)
on("AUCTION_HOUSE_CLOSED", function()
  AH.open = false
  queue = {}
  active = nil
  if buy.state then buyEnd(false) end
  post.waiting, post.confirm = false, nil
  if AH.dirty then C_Timer.After(2, function() AH.Share() end) end
  changed("closed")
end)
