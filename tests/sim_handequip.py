# 1.4.22 a stale "give back" entry never overrides what you equip yourself
src = open("sim_qol2.py").read()
exec(src.split("def tick(n=6):")[0])
def tick(n=6):
    for _ in range(n): LA.execute("ADDON_NS.QoL:MountTick()"); GA.ADVANCE(0.5)
LA.execute('''ADDON_NS.db.settings.qolRunGear = false; BOUND[11122] = true
INV[13] = "|cff1eff00|Hitem:5101::::|h[My Trinket A]|h|r"; BOUND[5101] = true; INV[14] = nil
ZONE = "Durotar"''')
# stale entry: slot 14 was empty before a ride long ago
LA.execute('ADDON_NS.db.qolSaved = { [14] = false }')
LA.execute('INV[14] = "|cff1eff00|Hitem:260308::::|h[Hyjal Postal Clasp]|h|r"; BOUND[260308] = true'); tick(10)
print("clasp in 14 (stale empty entry):", LA.eval('tostring(INV[14])'))
LA.execute('ADDON_NS.db.qolSaved = { [13] = "|cff1eff00|Hitem:5999::::|h[Old Trinket]|h|r" }; BAGS[0][3] = "|cff1eff00|Hitem:5999::::|h[Old Trinket]|h|r"; BOUND[5999] = true'); tick(10)
print("trinket A in 13 (stale old entry):", LA.eval('tostring(INV[13])'))
LA.execute('MOUNTED = true'); tick(12)
print("mounted 13/14:", LA.eval('tostring(INV[13])'), LA.eval('tostring(INV[14])'))
LA.execute('MOUNTED = false'); tick(12)
print("dismounted 13/14:", LA.eval('tostring(INV[13])'), LA.eval('tostring(INV[14])'))
print("FEIL:", list(GA.ERRORS.values())[:4])
