import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__)) + "/"
REPO = _os.path.dirname(HERE.rstrip("/")) + "/"
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
L, G, ns = A
L.execute('IsInInstance = function() return true, "party" end; GetInstanceInfo = function() return "Wailing Caverns" end')
G.FIRE("PLAYER_ENTERING_WORLD", False, True); run(5)
print("etter inngang:", ns.db.cnt.dungeonRuns, "state:", dict(ns.db.dgState[ns.Comm.MyFull(ns.Comm)]))
# simuler /reload: lokale variabler nullstilles, db beholdes -> kjør Achievements.lua og Extras.lua på nytt
for f in ["Achievements.lua", "Extras.lua"]:
    L.eval('function(path, ns) local c = assert(loadfile(path)) c("Chillan", ns) end')(REPO + f, ns)
run(70)
G.FIRE("PLAYER_ENTERING_WORLD", False, True); run(5)
print("etter reload:", ns.db.cnt.dungeonRuns, "curRun:", ns.db.curRun and ns.db.curRun.name)
print("FEIL:", list(G.ERRORS.values())[:4])
