exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
# --- 1) death during an encounter lockdown reaches B after the lockdown ends
LA.execute('LOCK = true; C_ChatInfo.InChatMessagingLockdown = function() return LOCK end')
before = LB.eval('#ADDON_NS.db.feed')
LA.execute('ADDON_NS.Tracker:Event("DEAD", "Wailing Caverns", "MOB:3", "Mad Magglish", "")'); run(8)
print("B feed during lockdown grew:", LB.eval('#ADDON_NS.db.feed') - before, "A queue:", LA.eval('ADDON_NS.Comm:QueueSize()'))
LA.execute('LOCK = false'); run(6)
print("B feed after lockdown grew:", LB.eval('#ADDON_NS.db.feed') - before)
# --- 2) result 11 from the send itself is kept, not dropped
LA.execute('''LOCK2 = true; local orig = C_ChatInfo.SendAddonMessage
C_ChatInfo.SendAddonMessage = function(...) if LOCK2 then return 11 end return orig(...) end''')
before = LB.eval('#ADDON_NS.db.feed')
LA.execute('ADDON_NS.Tracker:Event("DEAD", "Wailing Caverns", "MOB:3", "Kresh", "")'); run(8)
print("result-11 kept in queue:", LA.eval('ADDON_NS.Comm:QueueSize()') > 0)
LA.execute('LOCK2 = false'); run(8)
print("B got it after:", LB.eval('#ADDON_NS.db.feed') - before)
# --- 3) blue item shows up in the bags without a loot line
LA.execute('''BAG = {}
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(b) return b == 0 and 16 or 0 end
C_Container.GetContainerItemInfo = function(b, s) return BAG[s] end
GetInventoryItemID = function() return nil end
C_Item = C_Item or {}; C_Item.GetItemQualityByID = function(id) return ({[6504]=3,[2852]=2,[9999]=4})[id] end''')
GA.FIRE("PLAYER_ENTERING_WORLD"); run(6)
n0 = LA.eval('(function() local n = 0 for _, it in ipairs(ADDON_NS.db.feed) do if it.kind == "LOOT" then n = n + 1 end end return n end)()')
GA.FIRE("LOOT_OPENED")
LA.execute('BAG[3] = { itemID = 6504, quality = 3, stackCount = 1 }; BAG[4] = { itemID = 2852, quality = 2, stackCount = 1 }')
GA.FIRE("BAG_UPDATE_DELAYED"); run(4)
n1 = LA.eval('(function() local n = 0 for _, it in ipairs(ADDON_NS.db.feed) do if it.kind == "LOOT" then n = n + 1 end end return n end)()')
print("blue from bags posted:", n1 - n0)
# same item via the loot line right after: no double post
GA.FIRE("CHAT_MSG_LOOT", "You receive loot: |cnIQ3:|Hitem:6504::::|h[Thing]|h|r."); run(2)
n2 = LA.eval('(function() local n = 0 for _, it in ipairs(ADDON_NS.db.feed) do if it.kind == "LOOT" then n = n + 1 end end return n end)()')
print("no double post:", n2 == n1)
# an uncached item in a loot line: quality from the link
LA.execute('C_Item.GetItemQualityByID = function() return nil end')
GA.FIRE("CHAT_MSG_LOOT", "You receive loot: |cnIQ4:|Hitem:7777::::|h[Epic]|h|r."); run(2)
n3 = LA.eval('(function() local n = 0 for _, it in ipairs(ADDON_NS.db.feed) do if it.kind == "LOOT" then n = n + 1 end end return n end)()')
print("uncached epic from link posted:", n3 - n2)
# bank: withdrawing a blue is not a drop
LA.execute('C_Item.GetItemQualityByID = function(id) return 3 end')
GA.FIRE("BANKFRAME_OPENED"); LA.execute('BAG[5] = { itemID = 8888, quality = 3, stackCount = 1 }'); GA.FIRE("BAG_UPDATE_DELAYED"); run(3)
GA.FIRE("BANKFRAME_CLOSED"); run(3); GA.FIRE("BAG_UPDATE_DELAYED"); run(3)
n4 = LA.eval('(function() local n = 0 for _, it in ipairs(ADDON_NS.db.feed) do if it.kind == "LOOT" then n = n + 1 end end return n end)()')
print("bank withdraw not posted:", n4 == n3)
print("tiles max:", LA.eval('(function() ADDON_NS.db.settings.tiles = {} for i = 1, 10 do ADDON_NS.Tiles:Toggle(ADDON_NS.Tiles.DEFS[i].key) end return #ADDON_NS.db.settings.tiles end)()'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:4], [e for e in list(GB.ERRORS.values()) if 'HookScript' not in str(e)][:4])
# shards (trade goods) are not posted
LA.execute('C_Item.GetItemInfoInstant = function(id) if id == 11084 then return id, "Small Glowing Shard", "", "", 0, 7 end return id, "x", "", "", 0, 4 end; C_Item.GetItemQualityByID = function() return 3 end')
k = LA.eval('(function() local n = 0 for _, it in ipairs(ADDON_NS.db.feed) do if it.kind == "LOOT" then n = n + 1 end end return n end)()')
GA.FIRE("CHAT_MSG_LOOT", "You receive loot: |cnIQ3:|Hitem:11084::::|h[Small Glowing Shard]|h|r."); run(2)
GA.FIRE("CHAT_MSG_LOOT", "You receive loot: |cnIQ3:|Hitem:4444::::|h[Blue Sword]|h|r."); run(2)
k2 = LA.eval('(function() local n = 0 for _, it in ipairs(ADDON_NS.db.feed) do if it.kind == "LOOT" then n = n + 1 end end return n end)()')
print("shard skipped, sword posted:", k2 - k)

def loots(): return LA.eval('(function() local n = 0 for _, it in ipairs(ADDON_NS.db.feed) do if it.kind == "LOOT" then n = n + 1 end end return n end)()')
LA.execute('C_Item.GetItemInfoInstant = function(id) return id, "x", "", "", 0, 4 end; C_Item.GetItemQualityByID = function() return 3 end')
run(10)
# crafting a blue: no loot window -> not posted
k = loots(); LA.execute('BAG[7] = { itemID = 5555, quality = 3, stackCount = 1 }'); GA.FIRE("BAG_UPDATE_DELAYED"); run(4)
print("crafted blue not posted:", loots() == k)
# mail: blue taken out while the mailbox is open (+ a pushed line) -> not posted
k = loots(); GA.FIRE("MAIL_SHOW"); LA.execute('BAG[8] = { itemID = 5556, quality = 3, stackCount = 1 }')
GA.FIRE("CHAT_MSG_LOOT", "You receive item: |cnIQ3:|Hitem:5556::::|h[Mail Thing]|h|r."); GA.FIRE("BAG_UPDATE_DELAYED"); run(3)
GA.FIRE("MAIL_CLOSED"); run(4)
print("mail blue not posted:", loots() == k)
# quest reward blue -> posted
k = loots(); run(10); GA.FIRE("QUEST_TURNED_IN"); LA.execute('BAG[9] = { itemID = 5557, quality = 3, stackCount = 1 }'); GA.FIRE("BAG_UPDATE_DELAYED"); run(4)
print("quest reward blue posted:", loots() - k)
print("FEIL4:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:4])
