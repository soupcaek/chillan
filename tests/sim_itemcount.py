# 1.4.76: "You have  Bags 12 · Bank 40 = 52" in item tooltips; the bank is remembered
exec(open(__file__.replace("sim_itemcount", "sim_cards")).read().split("L, G, ns = client")[0])
L, G, ns = client("Thunka")
fails = []
def check(label, ok):
    print(("ok  " if ok else "FAIL") + " " + label)
    if not ok: fails.append(label)
L.execute("""
BAGS, BANKN = 12, 40
C_Item = C_Item or {}
C_Item.GetItemCount = function(id, bank) if id ~= 2589 then return 0 end return bank and (BANKLIVE and BAGS + BANKN or BAGS) or BAGS end
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(bag) if bag == -1 then return 2 end return 0 end
C_Container.GetContainerItemInfo = function(bag, slot) if bag == -1 then return { itemID = 2589, stackCount = 20 } end end
TT = { lines = {} }
function TT:AddDoubleLine(l, r) self.lines[#self.lines + 1] = l .. "|" .. r end
function TT:Show() end
""")
G = L.globals()
L.execute("BANKLIVE = true"); G.FIRE("BANKFRAME_OPENED")
b, k, t = L.eval("ADDON_NS.ItemCount.For(2589)")
check("at the bank: 12 + 40 = 52 (%s %s %s)" % (b, k, t), (b, k, t) == (12, 40, 52))
G.FIRE("BANKFRAME_CLOSED"); L.execute("BANKLIVE = false")
b, k, t = L.eval("ADDON_NS.ItemCount.For(2589)")
check("away from the bank: remembered 40 (%s %s %s)" % (b, k, t), (b, k, t) == (12, 40, 52))
L.execute("ADDON_NS.ItemCount.AddLine(TT, 2589)")
check("tooltip line " + str(L.eval("TT.lines[1]")), L.eval("TT.lines[1]") == "You have|Bags 12 · Bank 40 = 52")
L.execute("TT.lines = {} ADDON_NS.ItemCount.AddLine(TT, 999)")
check("nothing for items you don't have", L.eval("#TT.lines") == 0)
L.execute("TT.lines = {} ADDON_NS.db.settings.itemCount = false ADDON_NS.ItemCount.AddLine(TT, 2589)")
check("off in settings", L.eval("#TT.lines") == 0)
errs = [e for e in G.ERRORS.values()]
check("no Lua errors " + str(errs[:2]), not errs)
print("PASS" if not fails else "FAILED %s" % fails)
if fails: raise SystemExit(1)
