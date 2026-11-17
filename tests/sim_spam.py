exec(open("sim.py").read().split("A = client(")[0])
A = client("Grimtusk", "WARRIOR", "Orc", 33, "Barrens")
A[2].SetCode(A[2], "CHILL-TEST"); A[1].ADVANCE(5); A[1].OUTBOX = A[0].table_from([])
G = A[0].globals()
def addon_from(sender, chan="CHANNEL"):
    msg = A[2].Comm.Build(A[2].Comm, "ST", "pidELENDI", sender, "MAGE", "Troll", 20, "Barrens")
    A[1].FIRE("CHAT_MSG_ADDON", "CHLN", msg, chan, sender, "")
prefix = A[2].PREFIX
def recv(sender):
    msg = A[2].Comm.Build(A[2].Comm, "ST", "pidELENDI", sender, "MAGE", "Troll", 20, "Barrens")
    A[1].FIRE("CHAT_MSG_ADDON", prefix, msg, "CHANNEL", sender, "")
full = "Elendi Forever-Camelot"
recv(full)
r = A[2].db.roster[full]
r.forceWhisper = A[2].Now()
spam = 0
for i in range(20):
    recv(full)                                   # han snakker fortsatt på kanalen
    A[2].Comm.Broadcast(A[2].Comm, A[2].Comm.Build(A[2].Comm, "CH", "x"+str(i), A[2].pid, "Grimtusk", 0, "hei"), 1)
    A[1].ADVANCE(2)
    for m in list(A[1].OUTBOX.values()):
        if m[3] == "WHISPER":
            spam += 1
            A[1].FIRE("CHAT_MSG_SYSTEM", "No player named 'Elendi Forever' is currently playing.")
    A[1].OUTBOX = A[0].table_from([])
print("ikke-funnet-meldinger på 40 sek:", spam, "| whisperAs:", r.whisperAs, "| noWhisper:", bool(r.noWhisper))
print("FEIL:", list(A[1].ERRORS.values())[:3])
