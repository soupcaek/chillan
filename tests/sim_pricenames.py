# 1.4.25 ?price for prices scanned before names were stored: waits for names to load, then answers
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(3)
LA.execute('''LOADED = {}
NAMES = { [14047] = "Runecloth", [4306] = "Silk Cloth" }
C_Item = C_Item or {}
C_Item.GetItemNameByID = function(id) return LOADED[id] and NAMES[id] or nil end
C_Item.GetItemInfo = function(id) return LOADED[id] and NAMES[id] or nil end
GetItemInfo = function(id) if type(id) == "number" and LOADED[id] then return NAMES[id] end return nil end
C_Item.RequestLoadItemDataByID = function(id) C_Timer.After(2, function() LOADED[id] = true; FIRE("GET_ITEM_INFO_RECEIVED", id, true) end) end
local M = ADDON_NS.Market
M:Set(14047, 2500, ADDON_NS.Now() - 86400, ADDON_NS.pid)
M:Set(4306, 800, ADDON_NS.Now() - 86400, ADDON_NS.pid)''')
LA.execute('ADDON_NS.Data:SendChat("?price runecloth")'); run(30)
print("B:", LB.eval('(function() for i = #ADDON_NS.db.feed, 1, -1 do local it = ADDON_NS.db.feed[i] if it.kind == "PRICE" then local _, _, l = ADDON_NS.SceneLine(it, "x") return (l:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")) end end return "none" end)()'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5], [e for e in list(GB.ERRORS.values()) if 'HookScript' not in str(e)][:5])
