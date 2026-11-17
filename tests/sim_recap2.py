exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
LA.execute('''LVL = 20; UnitLevel = function(u) return LVL end
RECAPS = 0; ADDON_NS:Listen("LEVEL_RECAP", function() RECAPS = RECAPS + 1 end)
issecretvalue = function(v) return v == "SECRET" end''')
LA.execute('ADDON_NS.LevelRecap:Cur()'); run(2)
def dings(L): return L.eval('(function() local n = 0 for _, it in ipairs(ADDON_NS.db.feed) do if it.kind == "DING" then n = n + 1 end end return n end)()')
# 1) loading screen: level unreadable -> record kept
LA.execute('LVL = nil; ADDON_NS.LevelRecap:Cur(); LVL = 20')
print("record kept through loading:", LA.eval('ADDON_NS.LevelRecap:Cur().lvl'))
# 2) zone changes with no ding: no recap
for i in range(5): GA.FIRE("ZONE_CHANGED_NEW_AREA"); run(4)
print("zone changes -> recaps:", LA.eval('RECAPS'))
# 3) ding in combat with hidden number: recap + DING once, right away
d0 = dings(LB)
LA.execute('LVL = 21'); GA.FIRE("PLAYER_LEVEL_UP", "SECRET"); run(5)
print("hidden ding -> recaps:", LA.eval('RECAPS'), "B got ding:", dings(LB) - d0)
for i in range(4): GA.FIRE("ZONE_CHANGED_NEW_AREA"); run(5)
print("zone changes after -> recaps still:", LA.eval('RECAPS'))
# 4) normal ding + the same event again -> one recap, one DING
d0 = dings(LB)
LA.execute('LVL = 22'); GA.FIRE("PLAYER_LEVEL_UP", 22); GA.FIRE("PLAYER_LEVEL_UP", 22); run(5)
print("normal ding -> recaps:", LA.eval('RECAPS'), "B got ding:", dings(LB) - d0)
# 5) a missed ding (no event at all): record closed quietly later, no box
LA.execute('LVL = 23'); LA.execute('ADDON_NS.LevelRecap:Cur()'); run(12); LA.execute('ADDON_NS.LevelRecap:Cur()')
print("missed ding -> recaps:", LA.eval('RECAPS'), "record now:", LA.eval('ADDON_NS.LevelRecap:Cur().lvl'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:4])
