# 1.4.77: dying to a fall (the death recap hands in { kind = "ENV", env = "Falling" }, no time) must not error
exec(open(__file__.replace("sim_deathkiller", "sim_cards")).read().split("L, G, ns = client")[0])
L, G, ns = client("Thunka")
fails = []
def check(label, ok):
    print(("ok  " if ok else "FAIL") + " " + label)
    if not ok: fails.append(label)
cat = L.eval('ADDON_NS.Deaths:Killer({ kind = "ENV", env = "Falling" }).cat')
check("fall from the recap: FALL (" + str(cat) + ")", cat == "FALL")
cat = L.eval('ADDON_NS.Deaths:Killer({ kind = "ENV", env = "Drowning" }).cat')
check("drowning: DROWN", cat == "DROWN")
check("nothing known: nil", L.eval('ADDON_NS.Deaths:Killer() == nil'))
errs = [e for e in G.ERRORS.values()]
check("no Lua errors " + str(errs[:2]), not errs)
print("PASS" if not fails else "FAILED %s" % fails)
if fails: raise SystemExit(1)
