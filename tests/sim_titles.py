exec(open("sim_v08.py").read().split("# quest-kompis")[0])
toasts = {"A": [], "B": []}
A[2].Listen(A[2], "TOAST", lambda i: toasts["A"].append(i.kind))
B[2].Listen(B[2], "TOAST", lambda i: toasts["B"].append(i.kind))
run(400)
# A og B tjener gull nesten likt i 2 timer – ledelsen skifter hele tiden
money = {"A": 100000, "B": 100000}
import random
random.seed(1)
for minute in range(120):
    for who, c in (("A", A), ("B", B)):
        money[who] += random.randint(0, 3000)
        c[1].MOCK_ME.money = money[who] if hasattr(c[1].MOCK_ME, "money") else None
        c[2].Tracker.AddStat(c[2].Tracker, "Gold", random.randint(0, 3000))
    run(60)
print("tittel-varsler på 2 timer: A", toasts["A"].count("title"), "B", toasts["B"].count("title"))
print("FEIL:", list(A[1].ERRORS.values())[:3], list(B[1].ERRORS.values())[:3])
# B drar tydelig fra i gull (ekte forbikjøring) -> skal varsles hos A
before = toasts["A"].count("title")
for minute in range(20):
    B[2].Tracker.AddStat(B[2].Tracker, "Gold", 60000)
    run(60)
print("ekte forbikjøring, nye varsler hos A:", toasts["A"].count("title") - before)
ev = A[2].Titles
print("holder gold:", ev.Current(ev)["gold"]["pid"] if ev.Current(ev)["gold"] else None, "B pid:", B[2].pid)
