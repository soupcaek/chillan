# Nettverkstest: 4 klienter, D på annen kanal-server, B hører ikke kanalen, tap av meldinger
exec(open("sim.py").read().split("A = client(")[0])
names = [("Grimtusk","WARRIOR","Orc"),("Thunka","SHAMAN","Tauren"),("Kenny Bolt","ROGUE","Undead"),("Ret Adeen","PALADIN","BloodElf")]
cl = [client(n, c, r, 30, "Barrens") for n,c,r in names]
full = {id(c): n+"-ClassicBetaPvP" for c,(n,_,_) in zip(cl,names)}
backend = {id(cl[0]):1, id(cl[1]):1, id(cl[2]):1, id(cl[3]):2}
hearsChan = {id(c): True for c in cl}
hearsChan[id(cl[1])] = False   # B: sender på kanalen, men hører den ikke
drop = {"on": False, "dst": None}
def route_all():
    outs = []
    for c in cl:
        out = list(c[1].OUTBOX.values()); c[1].OUTBOX = c[0].table_from([])
        outs.append((c, out))
    for src, out in outs:
        for m in out:
            for dst in cl:
                if dst is src: continue
                if drop["on"] and dst is drop["dst"]: continue
                if m[3] == "CHANNEL" and (backend[id(dst)] != backend[id(src)] or not hearsChan[id(dst)]): continue
                if m[3] == "WHISPER" and m[4] != full[id(dst)]: continue
                dst[1].FIRE("CHAT_MSG_ADDON", m[1], m[2], m[3], full[id(src)], m[4])
def run(sec):
    for i in range(int(sec/2)):
        for c in cl: c[1].ADVANCE(2)
        route_all()
for c in cl: c[2].SetCode(c[2], "CHILL-TEST")
cl[3][2].Data.AddManual(cl[3][2].Data, full[id(cl[0])])
cl[1][2].Data.AddManual(cl[1][2].Data, full[id(cl[2])])
run(180)
L = "ABCD"
def online(c): return sum(1 for p in c[2].db.people.values() if c[2].IsOnline(c[2], p))
print("online (inkl. meg):", {L[i]: online(c) for i,c in enumerate(cl)})
for i,c in enumerate(cl):
    c[2].Data.SendChat(c[2].Data, "hei fra " + L[i])
run(30)
for i,c in enumerate(cl):
    print(L[i], "chat:", sorted(it.text[-1] for it in c[2].db.chat.values()))
# tap: B mister alt i 10 sek mens C chatter
drop.update(on=True, dst=cl[1])
cl[2][2].Data.SendChat(cl[2][2].Data, "tapt melding X")
run(10)
drop["on"] = False
print("B rett etter tap:", any("X" in it.text for it in cl[1][2].db.chat.values()))
run(90)
print("B etter synk:", any("X" in it.text for it in cl[1][2].db.chat.values()))
for i,c in enumerate(cl):
    errs = list(c[1].ERRORS.values())
    if errs: print("FEIL", L[i], errs[:3])
for i,c in enumerate(cl):
    print(L[i], "chat til slutt:", sorted(it.text[-1] for it in c[2].db.chat.values()))
for i,c in enumerate(cl):
    print(L[i], "roster:", [(k.split("-")[0], round(c[2].Now()-(r.heard or 0)), bool(r.chan), bool(r.forceWhisper)) for k,r in c[2].db.roster.items()])
# Forsinkelse: A og D chatter, hvor raskt når det alle?
import itertools
for src in (0, 3, 1):
    cl[src][2].Data.SendChat(cl[src][2].Data, "fart" + L[src])
    got = {}
    for tick in range(30):
        for c in cl: c[1].ADVANCE(0.5)
        route_all()
        for i,c in enumerate(cl):
            if i not in got and any(it.text == "fart"+L[src] for it in c[2].db.chat.values()):
                got[i] = (tick+1)*0.5
    print("chat fra", L[src], "nådde (sek):", {L[i]: t for i,t in sorted(got.items())})
