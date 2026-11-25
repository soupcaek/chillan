exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
LB.execute('POPS = {}; ADDON_NS:Listen("DING", function(it) local s = it.kind .. ":" .. tostring(it.a) for _, x in ipairs(it.also or {}) do s = s .. "+" .. x.kind .. ":" .. tostring(x.a) end table.insert(POPS, s) end)')
LA.execute('TOASTS = {}; ADDON_NS:Listen("TOAST", function(t) table.insert(TOASTS, t.title) end)')
run(3)
for lvl in [5, 9, 10, 12, 15, 19, 20, 21]:
    LA.execute(f'ADDON_NS.Tracker:Event("DING", {lvl}, 1000)'); run(4)
print("B popups for dings:", LB.eval('table.concat(POPS, " ")'))
LB.execute('POPS = {}')
# small achievement: no gang popup; big: popup; ding+big at once: one combined popup
LA.execute('ADDON_NS.Tracker:Event("ACH", "Z10", "B")'); run(4)
LA.execute('ADDON_NS.Tracker:Event("ACH", "GC100", "S")'); run(4)
print("B popups after 2 small achs:", LB.eval('#POPS'))
LA.execute('ADDON_NS.Tracker:Event("DING", 30, 1000); ADDON_NS.Tracker:Event("ACH", "EP1", "S")'); run(5)
print("B popups after ding 30 + first epic:", LB.eval('table.concat(POPS, " ")'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:4], [e for e in list(GB.ERRORS.values()) if 'HookScript' not in str(e)][:4])
