exec(open("sim_market.py").read().split("# Disenchantry")[0])
# B has an old (14h) Linen price; A rescans with the same price -> not pushed; B hovers after MS
LB.execute('local M = ADDON_NS.Market; ADDON_NS.db.market[2589] = { v = 12, t = time() - 14*3600, by = "x" }')
LA.execute('ADDON_NS.db.marketFullAt = 0; C_AuctionHouse = nil; QueryAuctionItems = function() end; ADDON_NS.Market:FullScan(); FIRE("AUCTION_ITEM_LIST_UPDATE")'); run(6)
print("A linen t age:", LA.eval('time() - ADDON_NS.Market:Get(2589).t'))
print("B gangScanAt:", LB.eval('ADDON_NS.Market.gangScanAt'), LB.eval('ADDON_NS.Market.gangScanBy'))
LB.execute('TT.lines = {}; ADDON_NS.Market.AddTooltipLine(TT, 2589, 1)'); run(12)
print("B linen age after hover:", LB.eval('time() - ADDON_NS.Market:Get(2589).t'))
print("FEIL:", list(GA.ERRORS.values())[:3], list(GB.ERRORS.values())[:3])
# a friend with older prices answering a login sync must not silence the one with the newest
LB.execute('ADDON_NS.Market.answering = { Someone = { at = time(), latest = time() - 50000 } }')
print("who:", LA.eval('ADDON_NS.Market:WhoText()'))
print("status:", LB.eval('ADDON_NS.Market:StatusText()'))
