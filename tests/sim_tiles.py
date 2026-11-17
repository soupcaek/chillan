exec(open("sim.py").read().split("A = client(")[0])
A = client("Grimtusk", "WARRIOR", "Orc", 33, "Barrens")
A[2].SetCode(A[2], "CHILL-TEST")
A[1].ADVANCE(5)
T = A[2].Tiles
print("festet:", list(T.List(T).values()))
for d in T.DEFS.values():
    T.Toggle(T, d.key)
print("etter alle:", list(T.List(T).values()))
T.Update(T)
for t in T.tiles.values():
    if t.key: print("  ", t.key, "|", t.v._text if hasattr(t.v,"_text") else t.v.GetText(t.v), "|", t.k.GetText(t.k))
A[2].Window.OpenPlayer(A[2].Window, A[2].pid)
A[1].ADVANCE(3)
print("errors:", list(A[1].ERRORS.values())[:5])
A[2].db.settings.tiles = A[0].table_from(["level","xph","eta","ilvl","dura","bags","ach","streak"])
T.Layout(T)
for t in T.tiles.values():
    if t.key: print("  ", t.key, "|", t.v.GetText(t.v), "|", t.k.GetText(t.k))
A[2].db.settings.tiles = A[0].table_from(["event"])
T.Layout(T)
print("  event |", T.tiles[1].v.GetText(T.tiles[1].v), "| vist:", T.tiles[1].IsShown(T.tiles[1]), T.tiles[2].IsShown(T.tiles[2]))
print("errors:", list(A[1].ERRORS.values())[:5])
