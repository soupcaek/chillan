# 1.4.57 Market window: sell queue + pricing, post, listings, buy (quote + confirm), my auctions +
# undercut + cancel, sales stats, shopping list, gang stats shared between two clients
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(3)
def errors(c, label):
    errs = list(c[1].ERRORS.values())
    if errs: print("ERRORS", label, errs[:5])
    c[1].ERRORS = c[0].table_from([])
errors(A, "A-start"); errors(B, "B-start")
LA.execute(r'''
Enum.ItemCommodityStatus = { Unknown = 0, Item = 1, Commodity = 2 }
Enum.AuctionHouseSortOrder = { Price = 0, Name = 1, Level = 2, Bid = 3, Buyout = 4 }
Enum.AuctionStatus = { Active = 0, Sold = 1 }
ItemLocation = { CreateEmpty = function() return { SetBagAndSlot = function(self, b, s) self.b, self.s = b, s end } end,
  CreateFromBagAndSlot = function(_, b, s) return { b = b, s = s } end }
-- bags: 40 Heavy Leather (commodity), 20 Mithril Ore (commodity), a green (item), linen bandages (vendor wins)
BAG = { [1] = { itemID = 4234, stackCount = 40, hyperlink = "|cffffffff|Hitem:4234|h[Heavy Leather]|h|r", iconFileID = 1, quality = 1 },
        [2] = { itemID = 3858, stackCount = 20, hyperlink = "|cffffffff|Hitem:3858|h[Mithril Ore]|h|r", iconFileID = 2, quality = 1 },
        [3] = { itemID = 6000, stackCount = 1, hyperlink = "|cff1eff00|Hitem:6000|h[Glimmering Mail Gauntlets]|h|r", iconFileID = 3, quality = 2 },
        [4] = { itemID = 1251, stackCount = 10, hyperlink = "|cffffffff|Hitem:1251|h[Linen Bandage]|h|r", iconFileID = 4, quality = 1 } }
COMMOD = { [4234] = true, [3858] = true, [1251] = true }
VENDOR = { [4234] = 375, [3858] = 500, [6000] = 2000, [1251] = 100 }
C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and 4 or 0 end,
  GetContainerItemInfo = function(bag, slot) if bag == 0 then return BAG[slot] end end }
C_Item = C_Item or {}
C_Item.GetItemInfo = function(id) local n = ({ [4234] = "Heavy Leather", [3858] = "Mithril Ore", [6000] = "Glimmering Mail Gauntlets", [1251] = "Linen Bandage" })[id]
  return n, nil, 1, 1, 1, "", "", COMMOD[id] and 20 or 1, "", 1, VENDOR[id] or 0 end
C_Item.IsEquippableItem = function(id) return id == 6000 end
C_Item.GetItemCount = function(id) local n = 0 for _, b in pairs(BAG) do if b.itemID == id then n = n + b.stackCount end end return n end
-- the auction house
LIST = { [4234] = { { unitPrice = 3600, quantity = 120, numOwnerItems = 0, auctionID = 11 }, { unitPrice = 3700, quantity = 20, numOwnerItems = 20, auctionID = 12 } },
         [3858] = {}, [1251] = { { unitPrice = 102, quantity = 50, numOwnerItems = 0, auctionID = 13 } } }
ITEMS = { [6000] = { { buyoutAmount = 30000, quantity = 1, auctionID = 21, containsOwnerItem = false } } }
SENT, POSTS, BIDS, CANCELS = {}, {}, {}, {}
C_AuctionHouse = {
  PostCommodity = function(loc, d, q, p) table.insert(POSTS, { "c", loc.b, loc.s, d, q, p }) return false end,
  PostItem = function(loc, d, q, bid, p) table.insert(POSTS, { "i", loc.b, loc.s, d, q, p }) return false end,
  SendSearchQuery = function(key) table.insert(SENT, key.itemID) end,
  SendSellSearchQuery = function(key) table.insert(SENT, key.itemID) end,
  MakeItemKey = function(id) return { itemID = id, itemLevel = 0, itemSuffix = 0 } end,
  GetItemKeyFromItem = function(loc) return { itemID = BAG[loc.s].itemID, itemLevel = 20, itemSuffix = 0 } end,
  IsSellItemValid = function() return true end,
  GetItemCommodityStatus = function(loc) return COMMOD[BAG[loc.s].itemID] and 2 or 1 end,
  IsThrottledMessageSystemReady = function() return true end,
  SupportsCopperValues = function() return true end,
  GetNumCommoditySearchResults = function(id) return #(LIST[id] or {}) end,
  GetCommoditySearchResultInfo = function(id, i) return LIST[id][i] end,
  GetNumItemSearchResults = function(k) return #(ITEMS[k.itemID] or {}) end,
  GetItemSearchResultInfo = function(k, i) return ITEMS[k.itemID][i] end,
  CalculateCommodityDeposit = function(id, d, q) return 15 * q * d end,
  CalculateItemDeposit = function() return 500 end,
  StartCommoditiesPurchase = function(id, q) QUOTE = { id, q } end,
  ConfirmCommoditiesPurchase = function(id, q) CONFIRMED = { id, q } end,
  CancelCommoditiesPurchase = function() end,
  PlaceBid = function(id, p) table.insert(BIDS, { id, p }) end,
  QueryOwnedAuctions = function() OWNED_ASKED = true end,
  GetNumOwnedAuctions = function() return #OWNED end,
  GetOwnedAuctionInfo = function(i) return OWNED[i] end,
  GetItemKeyInfo = function(k) return { itemName = "x" .. k.itemID, quality = 1, isCommodity = COMMOD[k.itemID] or false } end,
  CanCancelAuction = function() return true end,
  CancelAuction = function(id) table.insert(CANCELS, id) end,
  SendBrowseQuery = function(q) BROWSED = q.searchString end,
  GetBrowseResults = function() return { { itemKey = { itemID = 4234, itemLevel = 0, itemSuffix = 0 }, minPrice = 3600, totalQuantity = 140 } } end,
}
OWNED = {}
-- the gang's price for mithril (nothing listed)
ADDON_NS.Market:Set(3858, 6500, time(), "x")
ADDON_NS.Market:Set(4234, 3800, time(), "x")
function ANSWER() -- the auction house answers the last search
  local id = SENT[#SENT]
  if COMMOD[id] then FIRE("COMMODITY_SEARCH_RESULTS_UPDATED", id) else FIRE("ITEM_SEARCH_RESULTS_UPDATED", { itemID = id, itemLevel = 20, itemSuffix = 0 }) end
end
''')
LA.execute('FIRE("AUCTION_HOUSE_SHOW")'); run(2)
errors(A, "A-open")
print("window open:", LA.eval('ADDON_NS.MarketWin.frame and ADDON_NS.MarketWin.frame:IsShown()'), "| owned asked:", LA.eval('OWNED_ASKED'))
q = LA.eval('(function() local o = {} for _, e in ipairs(ADDON_NS.MarketWin.sellQueue) do o[#o+1] = e.name .. "=" .. tostring(e.each) end return table.concat(o, ", ") end)()')
v = LA.eval('(function() local o = {} for _, e in ipairs(ADDON_NS.MarketWin.vendQueue) do o[#o+1] = e.name end return table.concat(o, ", ") end)()')
print("up next:", q, "| for a vendor:", v)
assert "Linen Bandage" in v and "Heavy Leather" in q
# Heavy Leather first: 1c under the cheapest that isn't ours (36s -> 35s 99c)
LA.execute('ANSWER()'); run(2)
print("current:", LA.eval('ADDON_NS.MarketWin.sell.cur.name'), "| price:", LA.eval('ADDON_NS.MarketWin.sell.price:GetText()'), "| why:", LA.eval('ADDON_NS.MarketWin.sell.why:GetText()'))
print("you get:", LA.eval('ADDON_NS.MarketWin.sell.get:GetText():gsub("|T.-|t", "¤")'))
assert LA.eval('ADDON_NS.MarketWin.sell.price:GetText()') == "35s 99c"
assert LA.eval('select(1, ADDON_NS.MarketWin:SellValues()).name') == "Heavy Leather"
# post it
LA.execute('ADDON_NS.MarketWin.sell.postBtn:Click()')
print("posted:", LA.eval('POSTS[1] and table.concat(POSTS[1], ",")'))
assert LA.eval('POSTS[1][6]') == 3599 and LA.eval('POSTS[1][5]') == 40
LA.execute('FIRE("AUCTION_HOUSE_AUCTION_CREATED"); BAG[1] = nil; FIRE("BAG_UPDATE_DELAYED")'); run(2)
print("posts counted:", LA.eval('ADDON_NS.AH.Stats().w.p'), "| next:", LA.eval('ADDON_NS.MarketWin.sell.cur and ADDON_NS.MarketWin.sell.cur.name'))
# mithril: nothing listed -> the gang price
LA.execute('ANSWER()'); run(2)
print("mithril price:", LA.eval('ADDON_NS.MarketWin.sell.price:GetText()'), LA.eval('ADDON_NS.MarketWin.sell.why:GetText()'))
# a price under the vendor is pushed up: floor = ceil(vendor / 0.95)
print("floor for 1s vendor:", LA.eval('ADDON_NS.AH.Floor(1251)'))
assert LA.eval('ADDON_NS.AH.Floor(1251)') == 106
# skip goes to the next item
LA.execute('ADDON_NS.MarketWin.sell.skipBtn:Click()'); run(2)
print("after skip:", LA.eval('ADDON_NS.MarketWin.sell.cur and ADDON_NS.MarketWin.sell.cur.name'))

# ---- Buy: search, pick, quote, confirm
LA.execute('ADDON_NS.MarketWin:Show(2); ADDON_NS.MarketWin.buyP.box:SetText("heavy"); ADDON_NS.MarketWin:DoSearch(); FIRE("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")'); run(2)
print("searched:", LA.eval('BROWSED'), "| results:", LA.eval('#ADDON_NS.AH.results'), "| recent:", LA.eval('ADDON_NS.AH.DB().recent[1]'))
LA.execute('ADDON_NS.MarketWin:SelectBuy(ADDON_NS.AH.results[1]); ANSWER()'); run(2)
LA.execute('ADDON_NS.MarketWin.buyP.qty:SetText("130"); ADDON_NS.MarketWin:PaintBuyBar()')
print("buy bar:", LA.eval('ADDON_NS.MarketWin.buyP.for_:GetText():gsub("|T.-|t", "¤"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")'))
LA.execute('ADDON_NS.MarketWin.buyP.buyBtn:Click()')
print("quote asked:", LA.eval('QUOTE and (QUOTE[1] .. " x" .. QUOTE[2])'))
assert LA.eval('QUOTE[2]') == 120   # only 120 that aren't ours
LA.execute('FIRE("COMMODITY_PRICE_UPDATED", 3600, 432000)')
print("button:", LA.eval('ADDON_NS.MarketWin.buyP.buyBtn.label:GetText():gsub("|T.-|t", "¤")'))
LA.execute('ADDON_NS.MarketWin.buyP.buyBtn:Click(); FIRE("COMMODITY_PURCHASE_SUCCEEDED")')
print("confirmed:", LA.eval('CONFIRMED and CONFIRMED[2]'), "| state after:", LA.eval('tostring(ADDON_NS.AH.Buying())'))
assert LA.eval('CONFIRMED[2]') == 120

# ---- My auctions: one undercut, one lowest, one sold
LA.execute('''OWNED = {
  { auctionID = 101, itemKey = { itemID = 1251, itemLevel = 0, itemSuffix = 0 }, quantity = 10, buyoutAmount = 110, status = 0, timeLeftSeconds = 80000 },
  { auctionID = 102, itemKey = { itemID = 6000, itemLevel = 20, itemSuffix = 0 }, quantity = 1, buyoutAmount = 29000, status = 0, timeLeftSeconds = 30000 },
  { auctionID = 103, itemKey = { itemID = 3858, itemLevel = 0, itemSuffix = 0 }, quantity = 4, buyoutAmount = 6000, status = 1, timeLeftSeconds = 3000 } }
FIRE("OWNED_AUCTIONS_UPDATED")
ADDON_NS.MarketWin:Show(3)''')
for _ in range(5):
    LA.execute('if SENT[#SENT] then ANSWER() end'); run(2)
st = LA.eval('(function() local o = {} for _, x in ipairs(ADDON_NS.AH.owned) do o[#o+1] = x.itemID .. ":" .. tostring((ADDON_NS.AH.Status(x))) end return table.concat(o, ", ") end)()')
print("statuses:", st)
assert "1251:undercut" in st and "6000:lowest" in st and "3858:sold" in st
s = LA.eval('ADDON_NS.AH.Stats().w')
print("sale counted: gold", s.g, "items", s.i, "sold", s.s)
assert s.g == 22800 and s.i == 4    # 4 x 60s = 2400s, after the cut 22800c
LA.execute('FIRE("OWNED_AUCTIONS_UPDATED")')
assert LA.eval('ADDON_NS.AH.Stats().w.s') == 1   # not counted twice
print("cancel button:", LA.eval('ADDON_NS.MarketWin.aucP.cancel.label:GetText()'))
LA.execute('ADDON_NS.MarketWin.aucP.cancel:Click()')
print("cancelled:", LA.eval('CANCELS[1]'))
assert LA.eval('CANCELS[1]') == 101

# ---- Shopping: add by link, check, buy what's missing under the max
LA.execute('''ADDON_NS.MarketWin:Show(4)
local s = ADDON_NS.MarketWin.shopP
s.add:SetText("|cffffffff|Hitem:1251|h[Linen Bandage]|h|r"); s.want:SetText("30"); s.max:SetText("1.1s")
ADDON_NS.MarketWin:DoShopAdd()''')
LA.execute('ANSWER()'); run(2)
print("shopping:", LA.eval('#ADDON_NS.AH.ShopList()'), "| max:", LA.eval('ADDON_NS.AH.ShopList()[1].max'), "| can buy:", LA.eval('select(1, ADDON_NS.MarketWin:ShopCan(ADDON_NS.AH.ShopList()[1], 20))'))
assert LA.eval('ADDON_NS.AH.ShopList()[1].max') == 110 and LA.eval('(ADDON_NS.MarketWin:ShopCan(ADDON_NS.AH.ShopList()[1], 20))') == 20
print("summary:", LA.eval('ADDON_NS.MarketWin.shopP.sum:GetText():gsub("|T.-|t", "¤"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")'))

# ---- Gang: A shares, B sees A on the boards
LA.execute('ADDON_NS.AH.Share()'); run(10)
print("B got A's market stats:", LB.eval('(function() for pid, p in pairs(ADDON_NS.db.people) do if p.mk then return p.mk.w.g .. "c, " .. p.mk.w.p .. " posts, top " .. tostring(p.mk.tops[1] and p.mk.tops[1].id) end end end)()'))
LB.execute('ADDON_NS.MarketWin:Create(); ADDON_NS.MarketWin.frame:Show(); ADDON_NS.MarketWin:Show(5)')
rows = LB.eval('(function() local o = {} for _, r in ipairs(ADDON_NS.MarketWin:GangRows(1)) do o[#o+1] = r.name .. "=" .. r.x.g end return table.concat(o, ", ") end)()')
print("B gang rows:", rows, "| first gold board:", LB.eval('ADDON_NS.MarketWin.gangP.boards[1].rows[1].who:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")'))
assert "22800" in rows
LA.execute('FIRE("AUCTION_HOUSE_CLOSED")')
print("closed:", LA.eval('ADDON_NS.MarketWin.frame:IsShown()'))
errors(A, "A"); errors(B, "B")
# ---- 1.4.59: price history, graphs, the price before your own search, /chill price, rep hover
LA.execute('''NOW = 1795600000
local M = ADDON_NS.Market
for d = 13, 1, -1 do M:Set(9999, 50000 + d * 1000, NOW - d * 86400, "x") end
M:Set(9999, 48000, NOW, "x"); M:Set(9999, 47000, NOW + 60, "x")''')
h = LA.eval('#ADDON_NS.Market.History(9999, 14)')
print("history points:", h, "| today's:", LA.eval('ADDON_NS.Market.History(9999, 14)[%d].v' % h), "| trend:", LA.eval('ADDON_NS.AH.Trend(ADDON_NS.Market.History(9999, 14))'))
assert h == 14 and LA.eval('ADDON_NS.Market.History(9999, 14)[14].v') == 47000
assert LA.eval('ADDON_NS.Market.History(9999, 7)') and LA.eval('#ADDON_NS.Market.History(9999, 7)') == 7
LA.execute('ADDON_NS.Market.PruneHistory()')
assert LA.eval('#ADDON_NS.Market.History(9999, 30)') == 14
# the gang price from before your search
LA.execute('ADDON_NS.AH.searchAt = NOW + 50')
print("gang before search:", LA.eval('ADDON_NS.AH.GangBefore(9999)'), "| now:", LA.eval('ADDON_NS.AH.GangPrice(9999)'))
assert LA.eval('ADDON_NS.AH.GangBefore(9999)') == 48000
# /chill price opens the Buy tab on the item, with its graph
LA.execute('''C_Item.GetItemInfo = function(id) return "Thing " .. id, "|cffffffff|Hitem:" .. id .. "|h[Thing]|h|r", 1, 1, 1, "", "", 20, "", 1, 10 end
SlashCmdList.CHILLAN("price |cffffffff|Hitem:9999|h[Thing]|h|r")''')
print("price tab:", LA.eval('ADDON_NS.MarketWin.tab'), "| item:", LA.eval('ADDON_NS.MarketWin.buyP.sel and ADDON_NS.MarketWin.buyP.sel.itemID'), "| delta:", LA.eval('ADDON_NS.MarketWin.buyP.chart.delta:GetText()'))
assert LA.eval('ADDON_NS.MarketWin.buyP.sel.itemID') == 9999 and LA.eval('ADDON_NS.MarketWin.tab') == 2
# the wishlist graph
LA.execute('ADDON_NS.AH.ShopAdd(9999, 1); ADDON_NS.MarketWin.shopP.selId = 9999; ADDON_NS.MarketWin:Show(4)')
print("wishlist graph:", LA.eval('ADDON_NS.MarketWin.shopP.graphP.title:GetText()'), "|", LA.eval('ADDON_NS.MarketWin.shopP.side[3]:GetText()'))
errors(A, "A-end")
