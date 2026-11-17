exec(open("sim.py").read().split("A = client(")[0])
A = client("Grimtusk", "WARRIOR", "Orc", 33, "Barrens")
B = client("Kenny Bolt", "ROGUE", "Undead", 32, "Barrens")
cl=[A,B]; full={id(A):"Grimtusk-ClassicBetaPvP", id(B):"Kenny Bolt-ClassicBetaPvP"}
def route():
    outs=[(c,list(c[1].OUTBOX.values())) for c in cl]
    for c in cl: c[1].OUTBOX=c[0].table_from([])
    for src,out in outs:
        for m in out:
            for dst in cl:
                if dst is src: continue
                if m[3]=="WHISPER" and m[4]!=full[id(dst)]: continue
                dst[1].FIRE("CHAT_MSG_ADDON", m[1], m[2], m[3], full[id(src)], m[4])
def run(sec):
    for i in range(int(sec/2)):
        for c in cl: c[1].ADVANCE(2)
        route()
toasts={id(A):[], id(B):[]}
for c in cl:
    c[2].SetCode(c[2],"CHILL-TEST")
    c[2].Listen(c[2], "TOAST", lambda info, c=c: toasts[id(c)].append((info.kind, info.title, info.text)))
A[2].db.alias="Henrik"
run(40)
# quest-kompis
B[1].MY_QUESTS = B[0].table_from([B[0].table_from([101,"Ulvejakt",0]), B[0].table_from([202,"Elite: Ogre",3])])
B[1].FIRE("QUEST_ACCEPTED", 101); B[1].FIRE("QUEST_ACCEPTED", 202)
run(40)
A[1].MY_QUESTS = A[0].table_from([A[0].table_from([101,"Ulvejakt",0])])
A[1].FIRE("QUEST_ACCEPTED", 101)
run(10)
print("A quest-toasts:", [t for t in toasts[id(A)] if t[0]=="quest"])
sh, gr = A[2].Quests.Overview(A[2].Quests)
print("A felles:", [e.id for e in sh.values()], "gruppe:", [e.id for e in gr.values()])
# @navn
B[2].Data.SendChat(B[2].Data, "@henrik skal vi ta ulvene?")
B[2].Data.SendChat(B[2].Data, "ingen nevnt her")
run(6)
print("A mention-toasts:", [t[1] for t in toasts[id(A)] if t[0]=="mention"])
print("A chat mention-flagg:", [(c.text, bool(c.mention)) for c in A[2].db.chat.values()][-2:])
# kamp-kø
n0=len(toasts[id(A)])
A[1].IN_COMBAT=True
B[1].FIRE("PLAYER_LEVEL_UP", 33)
run(6)
print("A ding i kamp vist?", A[2].Overlays.ding.IsShown(A[2].Overlays.ding))
A[1].IN_COMBAT=False
A[1].FIRE("PLAYER_REGEN_ENABLED")
run(4)
print("A ding etter kamp vist?", A[2].Overlays.ding.IsShown(A[2].Overlays.ding))
# egen ding: ingen popup
A[2].Overlays.ding.Hide(A[2].Overlays.ding)
A[1].FIRE("PLAYER_LEVEL_UP", 34)
run(4)
print("A egen ding popup?", A[2].Overlays.ding.IsShown(A[2].Overlays.ding))
# lås
A[2].db.settings.locked=True
print("låst:", A[2].UI.IsLocked())
for c,l in ((A,"A"),(B,"B")):
    e=list(c[1].ERRORS.values())
    if e: print("FEIL",l,e[:4])
