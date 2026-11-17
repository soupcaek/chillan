exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
L, G, ns = A
L.execute('C_Item.GetItemInfo = function(id) return nil end')
it = L.eval('{ kind = "LOOT", pid = ADDON_NS.pid, char = "x", a = "6504", b = "3", t = 1 }')
print("uncached short:", ns.FeedShort(it))
print("uncached line:", ns.FeedLine(it, False))
L.execute('C_Item.GetItemInfo = function(id) return "Rifle", "|cff0070dd|Hitem:" .. id .. "::|h[Rifle]|h|r", 3 end')
fired = []
L.execute('ADDON_NS:Listen("ITEMINFO", function() ITEMINFO_FIRED = true end)')
G.FIRE("GET_ITEM_INFO_RECEIVED", 6504, True); run(1)
print("redraw fired:", L.eval('ITEMINFO_FIRED'))
print("loaded short:", ns.FeedShort(it))
print("FEIL:", list(G.ERRORS.values())[:3])
print("dbg waiting fired via direct:", L.execute('''
local ok = false
ADDON_NS:Listen("ITEMINFO", function() ok = true end)
C_Item.GetItemInfo = function() return nil end
ADDON_NS.ItemLink(7777)
return tostring(ok)'''))
G.FIRE("GET_ITEM_INFO_RECEIVED", 7777, True); run(2)
print("after event, global:", L.eval('ITEMINFO_FIRED'))
