exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
L, G, ns = A
print("cached:", ns.RenderChatText("look {i:251359} nice", "FFFFFF"))
L.execute('C_Item.GetItemInfo = function(id) return nil end')
print("uncached:", ns.RenderChatText("look {i:251360}", "FFFFFF"))
L.execute('C_Item.GetItemInfo = function(id) return "Plans", "|cff0070dd|Hitem:" .. id .. "::|h[Plans: X]|h|r", 3 end')
G.FIRE("GET_ITEM_INFO_RECEIVED", 251360, True); run(1)
print("after load:", ns.RenderChatText("look {i:251360}", "FFFFFF"))
print("FEIL:", list(G.ERRORS.values())[:3])
