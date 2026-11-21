# 1.4.20 two matches of the same BG (and two runs of the same dungeon) keep their own feed lines
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(3)
def lines(key):
    return LB.eval('(function() local out = {} for _, e in ipairs(ADDON_NS.EventWindow.entries) do if e.gkey == "%s" then out[#out+1] = (e.base or ""):gsub("|T.-|t", ""):gsub("|c%%x%%x%%x%%x%%x%%x%%x%%x", ""):gsub("|r", "") end end return table.concat(out, "  //  ") end)()' % key)
LA.execute('ADDON_NS.Tracker:Event("BGEND", "Alterac Valley", 0, "", "Entec:4:120:1:900")'); run(6)
for e in (LA, LB): e.execute('NOW = NOW + 600; GT = GT + 600')
LA.execute('ADDON_NS.Tracker:Event("BGEND", "Alterac Valley", 1, "", "Entec:1:60:1:300")'); run(6)
print("B BG lines:", lines("BG:Alterac Valley"))
key = "RUN:" + LA.eval('ADDON_NS.pid') + ":Wailing Caverns"
LA.execute('ADDON_NS.Tracker:Event("BOSS", "Wailing Caverns", "Mutanus", 60, "0:1:1:")'); run(6)
LA.execute('ADDON_NS.Tracker:Event("DUNGEON", "Wailing Caverns", 2400, 0, "")'); run(6)
for e in (LA, LB): e.execute('NOW = NOW + 900; GT = GT + 900')
LA.execute('ADDON_NS.Tracker:Event("BOSS", "Wailing Caverns", "Kresh", 40, "0:1:1:")'); run(6)
print("B run lines:", lines(key))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5], [e for e in list(GB.ERRORS.values()) if 'HookScript' not in str(e)][:5])
