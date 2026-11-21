# 1.4.21 run-speed gear put on by hand stays on, even with run gear switched off; and comes back after a ride
src = open("sim_qol2.py").read()
exec(src.split("def tick(n=6):")[0])
def tick(n=6):
    for _ in range(n): LA.execute("ADDON_NS.QoL:MountTick()"); GA.ADVANCE(0.5)
LA.execute('''ADDON_NS.db.settings.qolRunGear = false
INV[13] = "|cff1eff00|Hitem:5101::::|h[My Trinket A]|h|r"; BOUND[5101] = true
INV[14] = "|cff1eff00|Hitem:5102::::|h[My Trinket B]|h|r"; BOUND[5102] = true
ZONE = "Durotar"; BOUND[11122] = true''')
tick(6)
# Kenny equips the clasp by hand in slot 14; his trinket goes to the bags
LA.execute('''BAGS[0][3] = INV[14]; INV[14] = "|cff1eff00|Hitem:260308::::|h[Hyjal Postal Clasp]|h|r"; BOUND[260308] = true''')
tick(10)
print("clasp stays (run gear off):", LA.eval('tostring(INV[14])'))
LA.execute('ADDON_NS.db.settings.qolRunGear = true'); tick(10)
print("clasp stays (run gear on):", LA.eval('tostring(INV[14])'))
LA.execute('MOUNTED = true'); tick(12)
print("mounted 13/14:", LA.eval("tostring(INV[13])"), LA.eval("tostring(INV[14])"))
LA.execute('MOUNTED = false'); tick(12)
print("dismounted slot 14:", LA.eval('tostring(INV[14])'))
print("log:", LA.eval("table.concat(ADDON_NS.QoL.lastLog, \" ; \")"), LA.eval("tostring(ADDON_NS.QoL.waiting)"), LA.eval("tostring(ADDON_NS.db.settings.qolMount)"))
print("FEIL:", list(GA.ERRORS.values())[:4])
