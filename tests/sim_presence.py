exec(open("sim_forever.py").read().split("CHAN_OK = os.environ.get")[0])
CHAN_OK = True
toasts = {L[i]: [] for i in range(6)}
for i,c in enumerate(cl):
    c[2].Listen(c[2], "TOAST", lambda info, k=L[i]: toasts[k].append(info.kind))
active = cl[:5]
def route_active():
    global cl
    full_cl = cl; cl = active
    try: route_all()
    finally: cl = full_cl
def runA(sec, dt=2):
    for i in range(int(sec/dt)):
        for c in active: c[1].ADVANCE(dt)
        route_active()
for c in active: c[2].SetCode(c[2], "CHILL-TEST")
runA(150)
print("innlogging: online", {L[i]: online(c) for i,c in enumerate(active)}, " pålogget-varsler:", {k: v.count("online") for k,v in toasts.items() if k in "ABCDE"})
# layer-/serverbytte fram og tilbake for C og D, flere ganger
for k in toasts: toasts[k].clear()
mins = {L[i]: 99 for i in range(5)}
for rnd in range(4):
    backend[id(cl[2])] = 2 if backend[id(cl[2])] == 1 else 1
    backend[id(cl[3])] = 1 if backend[id(cl[3])] == 2 else 2
    for c in (cl[2], cl[3]):
        c[1].MOCK_ME.realm = "ClassicBetaPvP" + ("2" if backend[id(c)] == 2 else "")
        c[1].FIRE("ZONE_CHANGED_NEW_AREA")
    for s in range(30):
        runA(2)
        for i,c in enumerate(active):
            o = online(c)
            if o < mins[L[i]]:
                miss = [p.main.split("-")[0] for p in c[2].db.people.values() if p.main and not c[2].IsOnline(c[2], p)]
                now = c[2].Now()
                det = [(p.main.split("-")[0], round(now-(p.heard or 0)), round(now-(p.via or 0))) for p in c[2].db.people.values() if p.main and not c[2].IsOnline(c[2], p)]
                print("  runde", rnd, "sek", s*2, L[i], "mangler", det)
            mins[L[i]] = min(mins[L[i]], o)
print("under 4 serverbytter: laveste online", mins, " pålogget-varsler:", {k: v.count("online") for k,v in toasts.items() if k in "ABCDE"})
# ekte innlogging: F
active.append(cl[5]); cl[5][2].SetCode(cl[5][2], "CHILL-TEST")
for k in toasts: toasts[k].clear()
runA(90)
print("F logger på: varsler hos andre", {k: v.count("online") for k,v in toasts.items() if k in "ABCDE"}, " F fikk:", toasts["F"].count("online"))
# F logger ut
cl[5][1].FIRE("PLAYER_LOGOUT"); route_active(); active.remove(cl[5])
runA(4)
print("4 sek etter F logget ut, ser F online:", {L[i]: any(p.main and "Zvim" in p.main and c[2].IsOnline(c[2], p) for p in c[2].db.people.values()) for i,c in enumerate(active)})
runA(120)
print("2 min senere:", {L[i]: online(c) for i,c in enumerate(active)})
for i,c in enumerate(cl):
    e = list(c[1].ERRORS.values())
    if e: print("FEIL", L[i], e[:3])
