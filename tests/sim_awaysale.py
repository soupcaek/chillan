# 1.4.79: a sale while away from the auction house counts at once (from the price you listed it at)
exec(open(__file__.replace("sim_awaysale", "sim_cards")).read().split("L, G, ns = client")[0])
L, G, ns = client("Thunka")
fails = []
def check(label, ok):
    print(("ok  " if ok else "FAIL") + " " + label)
    if not ok: fails.append(label)
L.execute("""
ADDON_NS.db.mkOwned = {
  { auctionID = 77, itemID = 13100, qty = 1, price = 1500000, name = "Beaststalker's Gloves" },
  { auctionID = 78, itemID = 14047, qty = 20, price = 2700, name = "Runecloth", commodity = true },
}
""")
G = L.globals()
g0 = L.eval('ADDON_NS.AH.Stats().w.g')
G.FIRE("CHAT_MSG_SYSTEM", "A buyer has been found for your auction of Beaststalker's Gloves.")
g1 = L.eval('ADDON_NS.AH.Stats().w.g')
check("gloves counted after the cut: %s → %s" % (g0, g1), g1 - g0 == 1425000)
G.FIRE("CHAT_MSG_SYSTEM", "A buyer has been found for your auction of Beaststalker's Gloves.")
check("not twice", L.eval('ADDON_NS.AH.Stats().w.g') == g1)
G.FIRE("CHAT_MSG_SYSTEM", "A buyer has been found for your auction of Runecloth.")
check("trade goods wait for the auction house (could be part of the stack)", L.eval('ADDON_NS.AH.Stats().w.g') == g1)
errs = [e for e in G.ERRORS.values()]
check("no Lua errors " + str(errs[:2]), not errs)
print("PASS" if not fails else "FAILED %s" % fails)
if fails: raise SystemExit(1)
