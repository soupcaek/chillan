# 1.1.3: the carrot that stayed on – a give-back the game drops is tried again, a block only pauses
# a minute, and a speed item left on foot with nothing saved comes off
src = open("sim_qol2.py").read()
exec(src.split("def tick(n=6):")[0])
def tick(n=6):
    for _ in range(n): LA.execute("ADDON_NS.QoL:MountTick()"); GA.ADVANCE(0.5)
LA.execute('BOUND[11122] = true; MOUNTED = true'); tick()
print("mounted:", LA.eval('INV[14]'))
# the game ignores the first two give-backs (e.g. still on the global cooldown after dismounting)
LA.execute('''DROP = 2; local real = C_Item.EquipItemByName
C_Item.EquipItemByName = function(link, slot) if DROP > 0 then DROP = DROP - 1 table.insert(LOG, "dropped") return end real(link, slot) end
MOUNTED = false''')
tick(20)
print("dropped twice, then:", LA.eval('INV[14]'), "| saved empty:", LA.eval('next(ADDON_NS.db.qolSaved) == nil'))
# a block pauses, then it works again
LA.execute('MOUNTED = true'); tick()
LA.execute('ADDON_NS.QoL:OnBlocked("Chillan", "C_Item.PickupContainerItem()"); MOUNTED = false'); tick(4)
print("blocked, still:", LA.eval('INV[14]'))
GA.ADVANCE(61); tick(8)
print("a minute later:", LA.eval('INV[14]'))
# carrot put on by hand while on foot, nothing saved: comes off, your own trinket back
LA.execute('''local b, s; for bb, t in pairs(BAGS) do for ss, l in pairs(t) do if l:find("Carrot") then b, s = bb, ss end end end
if b then local old = INV[14]; INV[14] = BAGS[b][s]; BAGS[b][s] = old end; ADDON_NS.db.qolSaved = {}''')
tick(8)
print("carrot on by hand on foot ->", LA.eval('INV[14]'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:4])
