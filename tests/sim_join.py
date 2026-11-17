exec(open("sim_mesh.py").read().split("# Forsinkelse")[0].split("run(180)")[0])
run(120)
N = client("Ny Kompis", "MAGE", "Troll", 20, "Barrens")
full[id(N)] = "Ny Kompis-ClassicBetaPvP"; backend[id(N)] = 1; hearsChan[id(N)] = True
cl.append(N)
N[2].SetCode(N[2], "CHILL-TEST")
seen_by = {}
for tick in range(60):
    for c in cl: c[1].ADVANCE(1)
    route_all()
    t = tick + 1
    n_sees = sum(1 for p in N[2].db.people.values() if N[2].IsOnline(N[2], p)) - 1
    others = sum(1 for c in cl[:4] if any(p.main and "Ny Kompis" in p.main and c[2].IsOnline(c[2], p) for p in c[2].db.people.values()))
    if "n" not in seen_by and n_sees >= 4: seen_by["n"] = t
    if "o" not in seen_by and others >= 4: seen_by["o"] = t
print("ny ser alle 4 etter", seen_by.get("n"), "sek; alle 4 ser ny etter", seen_by.get("o"), "sek")
