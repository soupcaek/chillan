# 1.4.14 more speed gear: Rider of the Plaguelands set (mounted, zone), swim gear, run gear on foot
src = open("sim_qol2.py").read()
exec(src.split("def tick(n=6):")[0])
def tick(n=6):
    for _ in range(n): LA.execute("ADDON_NS.QoL:MountTick()"); GA.ADVANCE(0.5)
LA.execute('''ADDON_NS.db.settings.qolRunGear = true; ADDON_NS.db.settings.qolSwimGear = true
BAGS[1] = BAGS[1] or {}; C_Container.GetContainerNumSlots = function(b) return (b == 0 or b == 1) and 6 or 0 end; BAGS[0][5] = nil; BAGS[0][6] = nil
BAGS[1][1] = "|cff1eff00|Hitem:284102::::|h[Rider Ring]|h|r"; BOUND[284102] = true
BAGS[1][2] = "|cff1eff00|Hitem:284100::::|h[Rider Cloak]|h|r"; BOUND[284100] = true
BAGS[1][3] = "|cff1eff00|Hitem:7052::::|h[Azure Silk Belt]|h|r"; BOUND[7052] = true
BAGS[1][4] = "|cff1eff00|Hitem:18411::::|h[Spry Boots]|h|r"; BOUND[18411] = true
INV[11] = "|cff1eff00|Hitem:5001::::|h[My Ring A]|h|r"; INV[12] = "|cff1eff00|Hitem:5002::::|h[My Ring B]|h|r"
INV[15] = "|cff1eff00|Hitem:5003::::|h[My Cloak]|h|r"; INV[6] = "|cff1eff00|Hitem:5004::::|h[My Belt]|h|r"
INV[8] = "|cff1eff00|Hitem:5005::::|h[My Boots]|h|r"; for i = 5001, 5005 do BOUND[i] = true end
ZONE = "Eastern Plaguelands"''')
tick(10)
print("on foot (run gear):", LA.eval('tostring(INV[8])'))
LA.execute('MOUNTED = true'); tick(12)
print("mounted EPL ring/cloak:", LA.eval('tostring(INV[12])'), LA.eval('tostring(INV[15])'))
LA.execute('MOUNTED = false'); tick(12)
print("dismounted ring/cloak:", LA.eval('tostring(INV[12])'), LA.eval('tostring(INV[15])'))
LA.execute('IsSwimming = function() return true end'); tick(8)
print("swimming belt:", LA.eval('tostring(INV[6])'))
LA.execute('IsSwimming = function() return false end'); tick(10)
print("out of water belt:", LA.eval('tostring(INV[6])'))
print("FEIL:", list(GA.ERRORS.values())[:4])
