# 1.4.16 gang player history: grouping (shared), kills, died-to, tooltip lines
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(2)
LA.execute('''IsInGroup = function() return true end; IsInRaid = function() return false end; GetNumGroupMembers = function() return 2 end
local un = UnitName; UnitName = function(u) if u == "party1" then return "Strangerdude" end return un(u) end
IsInInstance = function() return true, "party" end; GetInstanceInfo = function() return "Blackrock Depths" end''')
GA.ADVANCE(0); 
for _ in range(14): run(60)
print("A lines:", LA.eval('table.concat(ADDON_NS.PlayerHistory:Lines("Strangerdude"), " | ")'))
print("B lines:", LB.eval('table.concat(ADDON_NS.PlayerHistory:Lines("Strangerdude"), " | ")'))
LA.execute('ADDON_NS.Tracker:Event("KILL", "Arathi Highlands", "KILL:x", "Stabsalot", "")'); run(4)
LB.execute('ADDON_NS.db.diedTo = ADDON_NS.db.diedTo or {}; ADDON_NS.db.diedTo["stabsalot"] = { name = "Stabsalot", n = 3, lastPid = ADDON_NS.pid }')
print("B stab:", LB.eval('table.concat(ADDON_NS.PlayerHistory:Lines("Stabsalot"), " | ")'))
print("FEIL:", list(GA.ERRORS.values())[:3], list(GB.ERRORS.values())[:3])
