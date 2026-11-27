# 1.4.76: the price graph's axes – round steps sized to the item, short prices
exec(open(__file__.replace("sim_pricegraph", "sim_cards")).read().split("L, G, ns = client")[0])
L, G, ns = client("Thunka")
fails = []
def check(label, ok):
    print(("ok  " if ok else "FAIL") + " " + label)
    if not ok: fails.append(label)
def clean(x): return L.eval('(function(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end)')(x)
A = ns.MarketAxis
def axis(lo, hi):
    step = A.NiceStep(max(1, hi - lo))
    import math
    a, b = math.floor(lo / step) * step, math.ceil(hi / step) * step
    out, v = [], a
    while v <= b + 0.5:
        out.append(clean(A.AxisCoins(v))); v += step
    return out
h = axis(5420000, 5960000)
check("Lionheart Helm " + str(h), h == ["540g", "560g", "580g", "600g"])
r = axis(1890, 3150)
check("Runecloth " + str(r), r[0] == "15s" and r[-1] == "35s" and "25s" in r)
m = axis(8600, 12200)
check("across 1g " + str(m), "1g" in m and "90s" in m and "1g 10s" in m)
check("copper " + clean(A.AxisCoins(45)), clean(A.AxisCoins(45)) == "45c")
# the chart draws with points
L.execute("""
local mw = ADDON_NS.MarketWindow
""")
errs = [e for e in G.ERRORS.values()]
check("no Lua errors " + str(errs[:2]), not errs)
print("PASS" if not fails else "FAILED %s" % fails)
if fails: raise SystemExit(1)
