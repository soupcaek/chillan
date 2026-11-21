# 1.4.23 run-speed gear taken off by hand stays off (Kenny: clasp kept coming back)
src = open("sim_qol2.py").read()
exec(src.split("def tick(n=6):")[0])
def tick(n=6):
    for _ in range(n): LA.execute("ADDON_NS.QoL:MountTick()"); GA.ADVANCE(0.5)
LA.execute('''ADDON_NS.db.settings.qolRunGear = true; BOUND[11122] = true
INV[13] = "|cff1eff00|Hitem:5101::::|h[Zarias Pouch]|h|r"; BOUND[5101] = true
INV[14] = "|cff1eff00|Hitem:5102::::|h[Kenny Trinket]|h|r"; BOUND[5102] = true
BAGS[0][3] = "|cff1eff00|Hitem:260308::::|h[Hyjal Postal Clasp]|h|r"; BOUND[260308] = true
ZONE = "Durotar"''')
tick(10)
print("chillan put clasp on:", LA.eval('tostring(INV[14])'))
tick(6)
LA.execute('local c = INV[14]; INV[14] = BAGS[0][3]; BAGS[0][3] = c')  # Kenny swaps his trinket back by hand
tick(16)
print("kenny's trinket stays:", LA.eval('tostring(INV[14])'), "| off:", LA.eval('tostring(ADDON_NS.db.qolRunOff[260308])'))
LA.execute('MOUNTED = true'); tick(12)
LA.execute('MOUNTED = false'); tick(14)
print("after a ride 13/14:", LA.eval('tostring(INV[13])'), LA.eval('tostring(INV[14])'))
LA.execute('local c = INV[14]; INV[14] = BAGS[0][3]; BAGS[0][3] = c'); tick(16)  # equips the clasp by hand again
print("clasp by hand stays:", LA.eval('tostring(INV[14])'), "| off:", LA.eval('tostring(ADDON_NS.db.qolRunOff[260308])'))
print("FEIL:", list(GA.ERRORS.values())[:4])
