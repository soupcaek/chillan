exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
ns = A[2]
db = ns.db
pid = next(k for k in db.people if k != ns.pid) if any(k != ns.pid for k in db.people) else None
print("other pid:", pid)
if pid:
    db.people[pid].alias = "Eirik / LINK"
for t in ["@Eirik / LINK Komma deg på disc", "hei @eirik / link!", "@Eirik alone", "@kenny bolt og @all"]:
    print(repr(t), "->", ns.RenderChatText(t, "D9F0F7"))
print("FEIL:", list(A[1].ERRORS.values())[:3])
