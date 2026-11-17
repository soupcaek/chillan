exec(open("sim_v08.py").read().split("# quest-kompis")[0])
B[1].FIRE("PLAYER_DEAD"); run(6)
item = [x for x in A[2].db.feed.values() if x.kind == "DEAD"][-1]
A[2].Data.React(A[2].Data, item, 4); run(4)
B2 = [x for x in B[2].db.feed.values() if x.kind == "DEAD"][-1]
print("B ser reacts:", len(B2.reacts or {}))
A[1].ADVANCE(1)
ent = [e for e in A[2].EventWindow.entries.values() if e.item and e.item.id == item.id][-1]
print("A linje:", ent.text[-120:])
e = list(A[1].ERRORS.values()); print("FEIL:", e[:3])
