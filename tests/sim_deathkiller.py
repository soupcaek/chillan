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
# (1.4.78) price answers: the scanner's character name → their alias
L.execute('ADDON_NS.db.people["p9"] = { main = "Helse Prest-X", alias = "Adrian", chars = { ["Helse Prest-X"] = { name = "Helse Prest", class = "PRIEST" } } }')
check("Helse → Adrian", L.eval('(ADDON_NS:PersonAlias((ADDON_NS:PersonByChar("Helse"))))') == "Adrian")
line = L.eval('select(3, ADDON_NS.SceneLine({ kind = "PRICE", a = "underworld band", d = "12345^499994^1020^Helse^Underworld Band", t = 1795600000 }))')
check("price line names Adrian: " + str(line), "Adrian" in str(line) and "Helse" not in str(line))
errs = [e for e in G.ERRORS.values()]
check("no Lua errors " + str(errs[:2]), not errs)
print("PASS" if not fails else "FAILED %s" % fails)
if fails: raise SystemExit(1)
