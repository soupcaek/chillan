import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__)) + "/"
REPO = _os.path.dirname(HERE.rstrip("/")) + "/"
from lupa import lua51
import re
BASE = REPO
toc = [l.strip().replace("\\", "/") for l in open(BASE + "Chillan_Camelot.toc") if l.strip().endswith(".lua")]

def client(name, cls, race, level, zone):
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    mock = open(HERE + "mock.lua").read()
    me = L.table_from({"name": name, "realm": "ClassicBetaPvP", "class": cls, "race": race, "level": level, "zone": zone, "money": 1000})
    L.execute("local f = loadstring(...) ; return f", mock)
    f = L.eval("function(src, me) local f = assert(loadstring(src)) f(me) end")
    f(mock, me)
    files = L.table_from(toc)
    ns = L.globals().LOAD(BASE, files)
    ns.debug = True
    G = L.globals()
    G.FIRE("ADDON_LOADED", "Chillan")
    G.FIRE("PLAYER_LOGIN")
    G.FIRE("PLAYER_ENTERING_WORLD", True, False)
    return L, G, ns

A = client("Grimtusk", "WARRIOR", "Orc", 33, "Stranglethorn Vale")
B = client("Thunka", "SHAMAN", "Tauren", 29, "Thousand Needles")
fullname = {id(A): "Grimtusk-ClassicBetaPvP", id(B): "Thunka-ClassicBetaPvP"}

def errors(c, label):
    errs = list(c[1].ERRORS.values())
    if errs:
        print("ERRORS", label, errs)
    c[1].ERRORS = c[0].table_from([])

def route(src, dst):
    out = list(src[1].OUTBOX.values())
    src[1].OUTBOX = src[0].table_from([])
    n = 0
    for m in out:
        prefix, msg, ctype, target = m[1], m[2], m[3], m[4]
        if ctype == "WHISPER" and target != fullname[id(dst)]:
            continue
        dst[1].FIRE("CHAT_MSG_ADDON", prefix, msg, ctype, fullname[id(src)], target)
        n += 1
    return n

def step(sec):
    for c in (A, B):
        c[1].ADVANCE(sec)
    a = route(A, B); b = route(B, A)
    return a, b

# Begge setter samme gjengkode
A[2].SetCode(A[2], "CHILL-TEST")
B[2].SetCode(B[2], "CHILL-TEST")
for i in range(12):
    r = step(2)
print("etter oppstart, meldinger A->B/B->A:", r)
for c, l in ((A, "A"), (B, "B")): errors(c, l)

def people(c):
    out = []
    for pid, p in c[2].db.people.items():
        out.append((p.main, c[2].IsOnline(c[2], p)))
    return out
print("A ser:", people(A))
print("B ser:", people(B))

# Chat
A[2].Data.SendChat(A[2].Data, "hei gjengen!")
step(2); step(2)
print("B chat:", [it.text for it in B[2].db.chat.values()])

# Ding, død, SOS
B[1].FIRE("PLAYER_LEVEL_UP", 30)
B[1].FIRE("PLAYER_DEAD")
step(2); step(2)
step(2); step(2)
print("A feed:", [(it.kind, it.a) for it in A[2].db.feed.values()])

# Ding med reaksjon
dings = [it for it in A[2].db.feed.values() if it.kind == "DING"]
A[2].Data.React(A[2].Data, dings[-1], 1)
step(2); step(2); step(5)
print("B ding reacts:", [len(it.reacts or {}) for it in B[2].db.feed.values() if it.kind == "DING"])
print("A ser B hist:", [[(h.l) for h in (c.hist or {}).values()] for p in A[2].db.people.values() for c in p.chars.values()])

deads = [it for it in A[2].db.feed.values() if it.kind == "DEAD"]
A[2].Data.React(A[2].Data, deads[-1], 1)
step(2); step(2); step(5)
print("B dead reacts:", [len(it.reacts or {}) for it in B[2].db.feed.values() if it.kind == "DEAD"])
ev = list(B[2].EventWindow.entries.values())
print("B hendelsesvindu:", len(ev), "linjer; kinds:", sorted(set(e.kind for e in ev)))
for e in ev[-4:]: print("   ", e.text[:150])

# Mats-tavle
B[2].Data.PostMats(B[2].Data, "20 Copper Bar", "til Blacksmithing")
step(2); step(2)
mp = list(A[2].db.mats.values())
print("A mats:", [(m.text, m.note) for m in mp])
A[2].Data.OfferMats(A[2].Data, mp[0])
step(2); step(2)

# Avstemning og avtale
A[2].Data.CreatePoll(A[2].Data, "Hva i kveld?", "SM; PvP; Quest")
A[2].Data.CreateEvent(A[2].Data, "Scarlet Monastery", "Torsdag 20:00")
step(2); step(2)
poll = B[2].Data.ActivePoll(B[2].Data)
B[2].Data.Vote(B[2].Data, poll, 2)
ev = list(B[2].db.events.values())[0]
B[2].Data.RSVP(B[2].Data, ev, 1)
step(2); step(2)
apoll = A[2].Data.ActivePoll(A[2].Data)
print("A poll votes:", dict(apoll.votes), "event rsvp:", dict(list(A[2].db.events.values())[0].rsvp))

# Quest, gull, uke-statistikk
A[1].FIRE("QUEST_TURNED_IN", 1, 100, 50)
step(130)
print("B ser A stats:", [(p.main, dict(p.stats or {}).get('wQuests'), dict(p.stats or {}).get('tLevels')) for p in B[2].db.people.values()])

# Åpne vinduet og alle faner (UI-røyktest)
for c, l in ((A, "A"), (B, "B")):
    c[2].Window.Toggle(c[2].Window)
    for key in ["friends", "quests", "chat", "stats", "ach", "ideas", "more", "settings"]:
        c[2].Window.Select(c[2].Window, key)
    # klikk gjennom underfanene i Statistikk
    st = c[2].Window.tabs["stats"]
    c[2].Window.Select(c[2].Window, "stats")
    c[2].Overlays.ShowProfile(c[2].Overlays, c[1].UIParent, c[2].pid)
    # hurtigkort og spillerside for alle i gjengen
    fr = c[2].Window.tabs["friends"]
    c[2].Window.Select(c[2].Window, "friends")
    for pid in list(c[2].db.people.keys()):
        p = c[2].GetPerson(c[2], pid)
        fr.ToggleQuick(fr, c[1].UIParent, p)
        c[2].Window.OpenPlayer(c[2].Window, pid)
    c[2].Window.Select(c[2].Window, "friends")
    c[1].FIRE("PLAYER_XP_UPDATE", "player")
    c[1].SlashCmdList.CHILLAN("kveld")
    c[1].SlashCmdList.CHILLAN("debug")
    c[2].Overlays.UpdateMinibar(c[2].Overlays)
    c[1].WorldMapFrame._shown = True
    c[2].MapPins.Update(c[2].MapPins)
    step(1)
    errors(c, l)

# Ny klient C på en annen backend-realm: når bare via whisper
C = client("Bonejaw", "ROGUE", "Undead", 32, "Barrens")
fullname[id(C)] = "Bonejaw-ClassicBetaPvP2"
backend = {id(A): 1, id(B): 1, id(C): 2}
clients = [A, B, C]
def route_all():
    outs = []
    for c in clients:
        out = list(c[1].OUTBOX.values()); c[1].OUTBOX = c[0].table_from([])
        outs.append((c, out))
    for src, out in outs:
        for m in out:
            for dst in clients:
                if dst is src: continue
                if m[3] == "CHANNEL" and backend[id(dst)] != backend[id(src)]: continue
                if m[3] == "WHISPER" and m[4] != fullname[id(dst)]: continue
                dst[1].FIRE("CHAT_MSG_ADDON", m[1], m[2], m[3], fullname[id(src)], m[4])
C[2].SetCode(C[2], "CHILL-TEST")
for i in range(10):
    for c in clients: c[1].ADVANCE(2)
    route_all()
print("C før manuelt:", people(C))
C[2].Data.AddManual(C[2].Data, "Grimtusk-ClassicBetaPvP")
for i in range(40):
    for c in clients: c[1].ADVANCE(2)
    route_all()
print("C ser:", people(C))
print("C chat:", [it.text for it in C[2].db.chat.values()])
print("C feed:", [it.kind for it in C[2].db.feed.values()])
# relé-test: C kjenner bare A; C dinger, B skal få det via A på kanalen
C[2].db.roster["Thunka-ClassicBetaPvP"] = None
C[1].FIRE("PLAYER_LEVEL_UP", 33)
for i in range(4):
    for c in clients: c[1].ADVANCE(2)
    route_all()
print("B fikk Cs ding via relé:", [it.a for it in B[2].db.feed.values() if it.kind == "DING" and "Bonejaw" in it.char])

# A sender chat nå – skal nå både B (kanal) og C (whisper)
A[2].Data.SendChat(A[2].Data, "test til alle")
for i in range(5):
    for c in clients: c[1].ADVANCE(2)
    route_all()
print("B siste:", list(B[2].db.chat.values())[-1].text, "| C siste:", list(C[2].db.chat.values())[-1].text if len(C[2].db.chat) else None)
print("B ser C?", people(B))
for c, l in ((A, "A"), (B, "B"), (C, "C")): errors(c, l)

print("B chatlinjer:")
for m in list(B[1].DEFAULT_CHAT_FRAME._msgs.values())[:12]: print("   ", m[:150])
print("A alias-test:", A[2].SetAlias("Henrik"))
step(35)
print("B ser A S3:", [(p.main, dict(p.s3).get("xpMax") if p.s3 else None) for p in B[2].db.people.values()])
print("B ser alias:", [(p.main, p.alias) for p in B[2].db.people.values()])

# Filter-test: A hvisker til C, C logger av, systemmeldingen skal skjules og C vises offline
A[2].Comm.SendTo(A[2].Comm, "Bonejaw-ClassicBetaPvP2", "test", 1)
A[1].ADVANCE(1)
f = A[1].FILTERS["CHAT_MSG_SYSTEM"]
print("skjult:", f(None, "CHAT_MSG_SYSTEM", "No player named 'Bonejaw' is currently playing."))
print("vanlig melding skjult:", f(None, "CHAT_MSG_SYSTEM", "You are now AFK."))
A[1].FIRE("CHAT_MSG_SYSTEM", "No player named 'Bonejaw' is currently playing.")
for pp in A[2].db.people.values(): pp.via = None
print("A ser C online:", [(p.main, A[2].IsOnline(A[2], p)) for p in A[2].db.people.values() if p.main and "Bonejaw" in p.main])

# Achievements
print("antall achievements:", len(A[2].Ach.defs))
print("A har (stille, bakover):", A[2].Ach.Count(A[2].Ach, A[2].pid), "poeng", A[2].Ach.Points(A[2].Ach, A[2].pid))
for i in range(10): A[1].FIRE("QUEST_TURNED_IN", 1, 100, 50)
for c in (A, B): c[1].ADVANCE(5)
route(A, B); route(B, A)
for c in (A, B): c[1].ADVANCE(3)
route(A, B); route(B, A)
print("A nye:", [it.a for it in A[2].db.feed.values() if it.kind == "ACH"])
print("B ser A ach:", B[2].Ach.Count(B[2].Ach, A[2].pid), "A selv:", A[2].Ach.Count(A[2].Ach, A[2].pid))
print("B vindu siste:", list(B[2].EventWindow.entries.values())[-1].text[:160])
A[2].Window.Select(A[2].Window, "ach")
A[2].Window.OpenAch(A[2].Window, B[2].pid)
A[2].Window.OpenPlayer(A[2].Window, A[2].pid)
