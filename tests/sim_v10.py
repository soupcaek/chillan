# 1.0: enemy log merged into the Cunt List, new trophies, popup rule, SOS gone, selftest
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A
run(3)
# an old enemy log in saved data: migration 3 moves it into the Cunt List
LA.execute('''local db = ADDON_NS.db
db.enemies = { ["sneaky rogue"] = { name = "Sneaky Rogue", note = "camps STV", by = "x1", byChar = "Bob-Realm", t = time() - 100 } }
db.schema = 2
ADDON_NS.MIGRATIONS[3](db)''')
print("migrated:", LA.eval('ADDON_NS.db.cunts["sneaky rogue"] and ADDON_NS.db.cunts["sneaky rogue"].reason'), "| enemies left:", LA.eval('next(ADDON_NS.db.enemies) == nil'))
# trophies
print("trophies:", LA.eval('#ADDON_NS.Ach.defs'))
for i in ["K10", "Q100", "GT100", "FL60", "HOP1", "ENM1", "RVNG", "SOS1"]:
    print(" ", i, LA.eval('ADDON_NS.Ach.byId["%s"] and (ADDON_NS.Ach.byId["%s"].tier .. " pops=" .. tostring(ADDON_NS.Ach:IsBig("%s"))) or "gone"' % (i, i, i)))
print("popup count (gang-wide):", LA.eval('(function() local n = 0 for _, d in ipairs(ADDON_NS.Ach.defs) do if ADDON_NS.Ach:IsBig(d.id) then n = n + 1 end end return n end)()'))
LA.execute('ADDON_NS.Cnt("allianceKills", 12); ADDON_NS.Cnt("layerHops"); ADDON_NS.Ach:CheckSoon()'); run(5)
print("unlocked K10, HOP1:", LA.eval('tostring(ADDON_NS.Ach:Has(ADDON_NS.pid, "K10")) .. " " .. tostring(ADDON_NS.Ach:Has(ADDON_NS.pid, "HOP1"))'))
print("SOS gone:", LA.eval('ADDON_NS.Data.SOS == nil and ADDON_NS.Overlays.sos == nil'))
LA.execute('ADDON_NS.SelfTest()')
print("FEIL:", [e for e in list(GA.ERRORS.values())][:6])
