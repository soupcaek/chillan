# 1.3.0 Chillan? Market: full scan (classic and modern AH), market value, tooltip line, sharing, login sync
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(4)
LA.execute('''
ROWS = {}
local function add(id, buyout, count) table.insert(ROWS, { id = id, buyout = buyout, count = count }) end
for i = 1, 8 do add(2589, 12 * 20, 20) end          -- Linen Cloth 12c each
add(2589, 9000, 1)                                   -- a silly listing
for i = 1, 3 do add(11684, 900000 + i * 1000, 1) end -- Ironfoe ~90g
CanSendAuctionQuery = function() return true, true end
QUERIES = 0
QueryAuctionItems = function(...) QUERIES = QUERIES + 1 end
GetNumAuctionItems = function() return #ROWS end
GetAuctionItemInfo = function(_, i) local r = ROWS[i] return "x", nil, r.count, 1, true, 1, "", 0, 0, r.buyout, 0, nil, nil, "Bob", nil, 0, r.id, true end
AuctionFrame = CreateFrame("Frame"); AuctionFrame:Show()
''')
LA.execute('FIRE("AUCTION_HOUSE_SHOW")'); run(2)
LA.execute('ADDON_NS.Market:FullScan(); FIRE("AUCTION_ITEM_LIST_UPDATE")'); run(4)
print("A linen:", LA.eval('ADDON_NS.Market:Get(2589) and ADDON_NS.Market:Get(2589).v'), "| Ironfoe:", LA.eval('ADDON_NS.Market:Get(11684) and ADDON_NS.Market:Get(11684).v'))
print("button:", LA.eval('ADDON_NS.Market.button and ADDON_NS.Market.button.label:GetText()'))
run(20)
print("B got:", LB.eval('ADDON_NS.Market:Get(2589) and ADDON_NS.Market:Get(2589).v'), LB.eval('ADDON_NS.Market:Get(11684) and ADDON_NS.Market:Get(11684).v'))
# tooltip line
LB.execute('TT = { lines = {} }; function TT:AddDoubleLine(a, b) table.insert(self.lines, a .. " | " .. b) end; ADDON_NS.Market.AddTooltipLine(TT, 11684)')
print("B tooltip:", LB.eval('TT.lines[1]'))
LB.execute('C_Item = C_Item or {}; C_Item.GetItemInfo = function(id) return "x", "l", 1, 1, 1, "", "", 20, "", 1, id == 2589 and 25 or 500000 end')
LB.execute('TT.lines = {}; ADDON_NS.Market.AddTooltipLine(TT, 2589, 20); ADDON_NS.Market.AddTooltipLine(TT, 11684, 1)')
print("B tooltip lines:", LB.eval('table.concat(TT.lines, " // "):gsub("|T.-|t", "¤")'))
# B logs in fresh: asks, A answers with what B is missing
LB.execute('ADDON_NS.db.market = {}')
LB.execute('ADDON_NS.Comm:Broadcast(ADDON_NS.Comm:Build("MQ", 0), 3)'); run(30)
print("B after login sync:", LB.eval('ADDON_NS.Market:Count()'))
# hovering an unknown item asks the gang; A answers at once
LB.execute('ADDON_NS.db.market = {}; TT.lines = {}; ADDON_NS.Market.AddTooltipLine(TT, 11684, 1)'); run(10)
print("B asked and got:", LB.eval('ADDON_NS.Market:Get(11684) and ADDON_NS.Market:Get(11684).v'))
LB.execute('ADDON_NS.Print(ADDON_NS.Market:StatusText())')
# Disenchantry: a green level-20 sword vs selling it
LB.execute("""local gi = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id) if id == 3333 then return "Green Sword", "|cff1eff00|Hitem:3333|h[Green Sword]|h|r", 2, 20, 15, "Weapon", "Swords", 1, "INVTYPE_WEAPON", 1, 150, 2 end
  if id == 10940 then return "Strange Dust", "l", 1, 1, 1, "", "", 20, "", 1, 5, 7 end
  if id == 10939 then return "Greater Magic Essence", "l", 2, 1, 1, "", "", 20, "", 1, 50, 7 end
  if id == 10978 then return "Small Glimmering Shard", "l", 2, 1, 1, "", "", 20, "", 1, 50, 7 end
  return gi(id) end
local M = ADDON_NS.Market
M:Set(10940, 300, time(), "x"); M:Set(10939, 5000, time(), "x"); M:Set(10978, 4000, time(), "x")""")
print("DE results:", LB.eval('ADDON_NS.Disenchant:Describe((ADDON_NS.Disenchant:Results(3333)))'))
print("DE value:", LB.eval('ADDON_NS.Disenchant:Value(3333)'))
LB.execute('TT.lines = {}; ADDON_NS.Market.AddTooltipLine(TT, 3333, 1)')
print("sword tooltip:", LB.eval('table.concat(TT.lines, " // "):gsub("|T.-|t", "¤")'))
LB.execute('ADDON_NS.Window:Create(); ADDON_NS.Window.frame:Show(); ADDON_NS.Window:Select("market")'); run(2)
# cooldown
LA.execute('ADDON_NS.Market:FullScan()')
print("cooldown:", LA.eval('ADDON_NS.Market.status'))
# modern AH path
LA.execute('''ADDON_NS.db.marketFullAt = 0; QueryAuctionItems = nil
C_AuctionHouse = { ReplicateItems = function() end, GetNumReplicateItems = function() return 2 end,
  GetReplicateItemInfo = function(i) return "x", nil, 1, 1, true, 1, "", 0, 0, 50000, 0, nil, nil, "Bob", nil, 0, 4306, true end }''')
LA.execute('ADDON_NS.Market:FullScan(); FIRE("REPLICATE_ITEM_LIST_UPDATE")'); run(4)
print("modern scan silk:", LA.eval('ADDON_NS.Market:Get(4306) and ADDON_NS.Market:Get(4306).v'))
LA.execute('ADDON_NS.SelfTest()')
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5], [e for e in list(GB.ERRORS.values()) if 'HookScript' not in str(e)][:3])
