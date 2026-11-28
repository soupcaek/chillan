# 1.4.78: the Market tab, rethought – sub-tabs, search with a price card, Item Tracker anywhere,
# My bags, Gang, Disenchantry, ⚙ settings; tracker alerts away from the auction house
exec(open(__file__.replace("sim_markettab", "sim_cards")).read().split("L, G, ns = client")[0])
L, G, ns = client("Thunka")
fails = []
def check(label, ok):
    print(("ok  " if ok else "FAIL") + " " + label)
    if not ok: fails.append(label)
L.execute("""
local now = GetServerTime()
local M = ADDON_NS.Market
M:Set(12640, 5650000, now - 3600, "p9")
M:Set(12640, 5900000, now - 86400 * 3, "p9")
M:Set(14047, 2700, now - 600, "p9")
ADDON_NS.db.marketNames = ADDON_NS.db.marketNames or {}
ADDON_NS.db.marketNames[12640] = "Lionheart Helm"
ADDON_NS.db.marketNames[14047] = "Runecloth"
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end
C_Container.GetContainerItemInfo = function(bag, slot) if bag == 0 then return slot == 1 and { itemID = 14047, stackCount = 20 } or { itemID = 12640, stackCount = 1 } end end
TOASTS = 0
local o = ADDON_NS.Overlays.Toast
ADDON_NS.Overlays.Toast = function(self, info) if tostring(info.title):find("Item Tracker") then TOASTS = TOASTS + 1 end end
ADDON_NS.Window:Create(); ADDON_NS.Window.frame:Show(); ADDON_NS.Window:Select("market")
""")
G = L.globals()
T = 'ADDON_NS.Window.tabs.market'
for i in range(1, 6):
    L.execute('%s.sub = %d' % (T, i)); L.execute('%s:Refresh()' % T)
check("all five sub-tabs draw", not [e for e in G.ERRORS.values()])
L.execute('%s.sub = 1; %s:Refresh()' % (T, T))
L.execute('local t = %s; t.results:SetData(ADDON_NS.Market:Search("runecloth", 40)) t.selSearch = 14047 t:Refresh()' % T)
check("search finds Runecloth", L.eval('#(ADDON_NS.Market:Search("runecloth", 40))') >= 1)
rows, total = L.eval('%s.BagRows()' % T)
check("my bags: Lionheart Helm first, worth > 0 (total %s)" % total, total and total > 0 and rows[1].id == 12640 and rows[1].how == "Auction")
# sorting: Total is the default (biggest first); by name puts Lionheart Helm before Runecloth
L.execute('local t = %s; t.sort3.col, t.sort3.desc = 1, false; t.sub = 3; t:Refresh()' % T)
check("sort by name doesn't error", not [e for e in G.ERRORS.values()])
L.execute('local t = %s; t.sort3.col, t.sort3.desc = 4, true; t:Refresh()' % T)
# tracker + alert away from the auction house: chat + Pulse ping
L.execute('ADDON_NS.AH.ShopAdd(12640, 6000000)')
L.execute('%s.sub = 2; %s:Refresh()' % (T, T))
L.execute('ADDON_NS.Market:Set(12640, 5500000, GetServerTime(), "p9"); FIRE_LISTEN = true')
L.execute('ADDON_NS:Fire("MARKET")'); G.ADVANCE(4)
check("alert pinged on Pulse (%s)" % L.eval('TOASTS'), L.eval('TOASTS') == 1)
L.execute('ADDON_NS:Fire("MARKET")'); G.ADVANCE(4)
check("no second ping for the same price", L.eval('TOASTS') == 1)
L.execute('%s:ToggleSettings()' % T)
errs = [e for e in G.ERRORS.values()]
check("no Lua errors " + str(errs[:2]), not errs)
print("PASS" if not fails else "FAILED %s" % fails)
if fails: raise SystemExit(1)
