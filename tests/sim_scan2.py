# 1.4.27 scan: sliced replicate reading, capturing another addon's full scan, page-by-page scan on cooldown
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(3)
LA.execute('''Enum = Enum or {}
Enum.AuctionHouseFilter = { PoorQuality = 0, CommonQuality = 1, UncommonQuality = 2, RareQuality = 3, EpicQuality = 4, LegendaryQuality = 5 }
Enum.AuctionHouseSortOrder = { Price = 0, Name = 1 }
BROWSED = {}
C_AuctionHouse = { ReplicateItems = function() end, GetNumReplicateItems = function() return 30000 end,
  GetReplicateItemInfo = function(i) return "Item " .. (i % 3000), nil, 1 + i % 5, 1, true, 1, "", 0, 0, 1000 + (i % 7) * 10, 0, nil, nil, "Bob", nil, 0, 20000 + (i % 3000), true end,
  IsThrottledMessageSystemReady = function() return true end,
  SendBrowseQuery = function(q) BROWSED.sent = (BROWSED.sent or 0) + 1 end,
  RequestMoreBrowseResults = function() BROWSED.more = (BROWSED.more or 0) + 1 end,
  HasFullBrowseResults = function() return (BROWSED.more or 0) >= 2 end,
  GetBrowseResults = function() local r = {} for k = 1, 400 + 300 * (BROWSED.more or 0) do r[#r+1] = { itemKey = { itemID = 30000 + k, itemSuffix = 0 }, minPrice = 500 + k, totalQuantity = 3 } end return r end }
FIRE("AUCTION_HOUSE_SHOW")''')
run(2)
# another addon starts a full scan
LA.execute('FIRE("REPLICATE_ITEM_LIST_UPDATE")'); run(10)
print("captured other addon's scan:", LA.eval('ADDON_NS.Market:Count()'), "| status:", LA.eval('ADDON_NS.Market.status'))
# on cooldown now: our button does a page-by-page scan
LA.execute('ADDON_NS.Market:FullScan()'); run(1)
for _ in range(3):
    LA.execute('FIRE("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")'); run(1)
run(4)
print("after quick scan:", LA.eval('ADDON_NS.Market:Count()'), "| status:", LA.eval('ADDON_NS.Market.status'), "| price 30010:", LA.eval('ADDON_NS.Market:Get(30010).v'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5])
