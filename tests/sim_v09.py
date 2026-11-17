exec(open("sim_v08.py").read().split("# quest-kompis")[0])
for c in cl: c[1].FIRE("PLAYER_LOGIN") if False else None
# titler
B[1].FIRE("PLAYER_DEAD"); B[1].FIRE("PLAYER_DEAD")
run(130)
A[2].Titles.Update(A[2].Titles)
cur = A[2].Titles.Current(A[2].Titles)
print("titler hos A:", {k: (v.pid == A[2].pid and "A" or "B", v.value) for k,v in cur.items()})
# klar-sjekk
A[2].Extras.StartReadyCheck(A[2].Extras)
run(4)
print("klar-sjekk:", {("A" if pid==A[2].pid else "B"): (d.free, d.total, d.dur, d.food) for pid,d in A[2].Extras.ready.items()})
# dungeon-logg
for c in cl: c[1].IN_INSTANCE = True
A[1].FIRE("ZONE_CHANGED_NEW_AREA"); run(4)
A[1].FIRE("ENCOUNTER_END", 1, "Lord Cobrahn", 1, 5, 1); A[1].FIRE("PLAYER_DEAD")
run(400)
for c in cl: c[1].IN_INSTANCE = False
A[1].FIRE("ZONE_CHANGED_NEW_AREA"); run(8)
print("B ser dungeon:", [(it.a, it.b, it.c, it.d) for it in B[2].db.feed.values() if it.kind=="DUNGEON"])
print("krønike B:", [e.text for e in B[2].Extras.Chronicle(B[2].Extras).values()][:5])
# kartnotat
A[2].Extras.AddNote(A[2].Extras, 1413, 0.5, 0.4, "gank", "rogue campet", 3)
run(4)
print("B notater:", [(n.kind, n.text) for n in B[2].db.notes.values()])
# åpne nye faner
A[2].Window.Toggle(A[2].Window)
for key in ["quests","settings","stats"]: A[2].Window.Select(A[2].Window, key)
st = A[2].Window.tabs["stats"]
bpid = [p for p,v in A[2].db.people.items() if p != A[2].pid][0]
A[2].Window.OpenCompare(A[2].Window, bpid)
A[2].Window.OpenPlayer(A[2].Window, bpid)
# reaksjon-linje
it = [x for x in A[2].db.feed.values() if x.pid != A[2].pid][-1]
A[2].EventWindow.QueueReaction(A[2].EventWindow, it, A[2].GetPerson(A[2], bpid), "Kenny Bolt-ClassicBetaPvP", 1)
A[1].ADVANCE(6)
print("rx-linje:", list(A[2].EventWindow.entries.values())[-1].text[-160:])
for c,l in ((A,"A"),(B,"B")):
    e=list(c[1].ERRORS.values())
    if e: print("FEIL",l,e[:5])
