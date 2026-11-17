# Forever-lik test: 2 backend-realms (kanal per realm), navn uten realm i sender,
# whisper til "Navn-Realm" feiler, Battle.net-venner, ny spiller som ingen kjenner.
exec(open("sim.py").read().split("A = client(")[0])
import os
specs = [("Lil Woyer","WARRIOR","Orc",1),("Kenny Bolt","ROGUE","Undead",1),("Ret Adeen","PALADIN","BloodElf",1),
         ("Helse Prest","PRIEST","Troll",2),("Elendi Forever","MAGE","Troll",2),("Zvim Bii","HUNTER","Orc",2)]
cl = []
for n,c,r,b in specs:
    x = client(n, c, r, 30, "Barrens"); cl.append(x)
name = {id(c): s[0] for c,s in zip(cl,specs)}          # det spillet viser som sender
backend = {id(c): s[3] for c,s in zip(cl,specs)}
L = "ABCDEF"
# Battle.net-vennskap (gameAccountID sett fra mottaker er avsenderens id)
gid = {id(c): 500+i for i,c in enumerate(cl)}
bnpairs = {("A","D"),("A","F"),("B","E"),("C","F")}
def isbn(a,b): return (a,b) in bnpairs or (b,a) in bnpairs
for i,c in enumerate(cl):
    fr = []
    for j,o in enumerate(cl):
        if i!=j and isbn(L[i],L[j]):
            fr.append(c[0].table_from({"gameAccountID": gid[id(o)], "characterName": name[id(o)], "realmName": ""}))
    c[1].BN_FRIENDS = c[0].table_from(fr)
notfound = {L[i]:0 for i in range(6)}
def route_all():
    outs = []
    for c in cl:
        out = list(c[1].OUTBOX.values()); c[1].OUTBOX = c[0].table_from([])
        outs.append((c, out))
    for src, out in outs:
        si = cl.index(src)
        for m in out:
            ctype, target = m[3], m[4]
            if ctype == "CHANNEL":
                if not CHAN_OK: continue
                for dst in cl:
                    if dst is not src and backend[id(dst)] == backend[id(src)]:
                        dst[1].FIRE("CHAT_MSG_ADDON", m[1], m[2], "CHANNEL", name[id(src)], "")
            elif ctype == "WHISPER":
                dst = next((d for d in cl if name[id(d)] == target), None)   # bare eksakt navn virker
                if dst: dst[1].FIRE("CHAT_MSG_ADDON", m[1], m[2], "WHISPER", name[id(src)], target)
                else:
                    notfound[L[si]] += 1
                    if os.environ.get("NFDEBUG"): print("   NOTFOUND", L[si], "->", target, m[2][:40])
                    shown = target.split("-")[0]
                    src[1].FIRE("CHAT_MSG_SYSTEM", "No player named '%s' is currently playing." % shown)
            elif ctype == "BN":
                dst = next((d for d in cl if gid[id(d)] == target), None)
                if dst and isbn(L[si], L[cl.index(dst)]):
                    dst[1].FIRE("BN_CHAT_MSG_ADDON", m[1], m[2], "WHISPER", gid[id(src)])
def run(sec, dt=2):
    for i in range(int(sec/dt)):
        for c in cl: c[1].ADVANCE(dt)
        route_all()
def online(c): return sum(1 for p in c[2].db.people.values() if p.main and c[2].IsOnline(c[2], p))
import os
CHAN_OK = os.environ.get("NOCHAN") is None
if not CHAN_OK:
    # kanalen leverer ingenting (som BFF-utvikleren så) – de første kjenner hverandre fra før
    for i,c in enumerate(cl[:5]):
        for j,o in enumerate(cl[:5]):
            if i != j and (i+j) % 2 == 0: c[2].db.roster[name[id(o)]] = c[0].table_from({"whisper": c[2].Now()})
for c in cl[:5]: c[2].SetCode(c[2], "CHILL-TEST")
t5 = None
for s_ in range(0, 180, 2):
    run(2)
    if t5 is None and all(online(c) == 5 for c in cl[:5]): t5 = s_ + 2
print("A-E ser alle 5 etter:", t5, "sek")
print("online etter 3 min (A-E):", {L[i]: online(c) for i,c in enumerate(cl[:5])})
# F blir med senere – kjenner ingen, men er Battle.net-venn med A og C
cl[5][2].SetCode(cl[5][2], "CHILL-TEST")
t_all = None
for s in range(0, 240, 2):
    run(2)
    if t_all is None and all(online(c) == 6 for c in cl): t_all = s + 2
print("alle 6 ser alle 6 etter:", t_all, "sek;", {L[i]: online(c) for i,c in enumerate(cl)})
for i,c in enumerate(cl): c[2].Data.SendChat(c[2].Data, "hei" + L[i])
run(20, 1)
for i,c in enumerate(cl):
    got = sorted(it.text[-1] for it in c[2].db.chat.values() if it.text.startswith("hei"))
    print(L[i], "fikk chat fra:", "".join(got))
before = dict(notfound); run(120)
print("«No player named» totalt:", notfound, " siste 2 min:", {k: notfound[k]-before[k] for k in notfound})
for i,c in enumerate(cl):
    e = list(c[1].ERRORS.values())
    if e: print("FEIL", L[i], e[:3])
