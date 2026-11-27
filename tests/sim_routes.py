# 1.4.76: rolling boss lists – sides and usual runs pick themselves at the first kills;
# the Ring of Law is one boss, chests don't count
exec(open(__file__.replace("sim_routes", "sim_cards")).read().split("L, G, ns = client")[0])
L, G, ns = client("Thunka")
fails = []
def check(label, ok):
    print(("ok  " if ok else "FAIL") + " " + label)
    if not ok: fails.append(label)
L.execute("""
function FOR(inst, killed)
  local list, wing, known, doors = ADDON_NS.Bosses:For(inst, killed or {}, false)
  local n, total = ADDON_NS.Bosses:Count(inst, killed or {})
  return list, wing, doors, n, total
end
function NAMES(t) local o = {} for _, x in ipairs(t or {}) do o[#o+1] = x.name end return table.concat(o, ",") end
""")
G = L.globals()
# BRD at the door: the usual runs, no list
lst, wing, doors, n, total = G.FOR("Blackrock Depths")
check("BRD door: 4 runs " + str(G.NAMES(doors)), G.NAMES(doors) == "Arena,Arena · Anger · Golem,Emperor run,Full run" and total is None)
# Ring of Law → Arena, and which arena boss
lst, wing, doors, n, total = G.FOR("Blackrock Depths", L.table_from({"Gorosh the Dervish": 95}))
check("Gorosh: Arena 1/1 " + str(wing), wing == "Arena" and n == 1 and total == 1 and lst[1]["as"] == "Gorosh the Dervish")
lst, wing, doors, n, total = G.FOR("Blackrock Depths", L.table_from({"Grizzle": 95, "General Angerforge": 300}))
check("then Angerforge: Arena · Anger · Golem 2/3 " + str(wing), wing == "Arena · Anger · Golem" and n == 2 and total == 3)
lst, wing, doors, n, total = G.FOR("Blackrock Depths", L.table_from({"Grizzle": 95, "Bael'Gar": 300}))
check("off the usual paths: open run, full list " + str(wing) + " " + str(total), wing == "Open run" and total == 20)
# Strat: sides at the door, UD at the first UD boss; the Main Gate has 6
lst, wing, doors, n, total = G.FOR("Stratholme")
check("Strat door: 2 sides", G.NAMES(doors) == "Main Gate,Service Entrance" and total is None)
lst, wing, doors, n, total = G.FOR("Stratholme", L.table_from({"Baroness Anastari": 250}))
check("Anastari: UD 1/6 " + str(wing), wing == "Service Entrance" and n == 1 and total == 6)
lst, wing, doors, n, total = G.FOR("Stratholme", L.table_from({"Timmy the Cruel": 250}))
check("Timmy: Main Gate 1/6 " + str(total), wing == "Main Gate" and total == 6)
# BRS: Lower 9, Upper 7
lst, wing, doors, n, total = G.FOR("Blackrock Spire", L.table_from({"Highlord Omokk": 100}))
check("Omokk: Lower 1/9", wing == "Lower" and total == 9)
lst, wing, doors, n, total = G.FOR("Blackrock Spire", L.table_from({"Pyroguard Emberseer": 100}))
check("Emberseer: Upper 1/7", wing == "Upper" and total == 7)
# Maraudon
lst, wing, doors, n, total = G.FOR("Maraudon", L.table_from({"Noxxion": 100}))
check("Noxxion: Orange 1/3", wing == "Orange" and total == 3)
lst, wing, doors, n, total = G.FOR("Maraudon", L.table_from({"Noxxion": 100, "Lord Vyletongue": 300}))
check("both sides: Full 8 " + str(total), wing == "Full" and total == 8)
# DM North: the Tribute chest isn't a boss
lst, wing, doors, n, total = G.FOR("Dire Maul", L.table_from({"Guard Mol'dar": 100}))
check("DM North 1/6 " + str(total), wing == "North" and total == 6)
# a one-way dungeon is there from the door
lst, wing, doors, n, total = G.FOR("Zul'Farrak")
check("ZF: list from the door, 9", doors is None and total == 9)
# UBRS Rend run: Gyth and Rend → "Upper · Rend run", 2/3; a Solakar kill makes it a full Upper run
lst, wing, doors, n, total = G.FOR("Blackrock Spire", L.table_from({"Gyth": 60, "Warchief Rend Blackhand": 61}))
check("Rend run " + str(wing) + " " + str(n) + "/" + str(total), wing == "Upper · Rend run" and n == 2 and total == 3)
lst, wing, doors, n, total = G.FOR("Blackrock Spire", L.table_from({"Pyroguard Emberseer": 60}))
check("Emberseer alone is just Upper", wing == "Upper" and total == 7)
lst, wing, doors, n, total = G.FOR("Blackrock Spire", L.table_from({"Gyth": 60, "Solakar Flamewreath": 61}))
check("Solakar too: full Upper", wing == "Upper" and total == 7)
rn = L.eval('ADDON_NS.Bosses:RunName("Blackrock Spire", { Gyth = 60, ["Warchief Rend Blackhand"] = 61 })')
check("run name " + str(rn), rn == "Blackrock Spire · Upper · Rend run")
lab = L.eval('(ADDON_NS.RunLabel("Blackrock Spire", { Gyth = 60, ["Warchief Rend Blackhand"] = 61 }):gsub("|H.-|h", ""):gsub("|h", ""))')
check("label " + str(lab), lab == "UBRS Rend")
lab = L.eval('(ADDON_NS.RunLabel("Stratholme · Service Entrance"):gsub("|H.-|h", ""):gsub("|h", ""))')
check("label " + str(lab), lab == "Strat UD")
# records: a part run never beats a whole one; a name without its side never counts
check("2 of 7 is no record", not L.eval('ADDON_NS.Bosses:NoteRun("Blackrock Spire · Upper", 2220, "p1", 1, "2")'))
L.execute('ADDON_NS.Bosses:NoteRun("Blackrock Spire · Upper", 2520, "p1", 1, "7")')
check("7 of 7 is one", L.eval('ADDON_NS.Bosses:RunRecord("Blackrock Spire · Upper").s') == 2520)
check("plain BRS never counts", not L.eval('ADDON_NS.Bosses:IsComplete("Blackrock Spire", 9)'))
check("Rend run 3/3 counts", L.eval('ADDON_NS.Bosses:IsComplete("Blackrock Spire · Upper · Rend run", 3)'))
# the end line takes the progress line's place (same group key with and without the side)
k1 = L.eval('ADDON_NS.FeedGroupKey({ kind = "BOSS", pid = "k", a = "Blackrock Spire" })')
k2 = L.eval('ADDON_NS.FeedGroupKey({ kind = "DUNGEON", pid = "k", a = "Blackrock Spire · Upper · Rend run" })')
check("same group key", k1 == k2)
errs = [e for e in G.ERRORS.values()]
check("no Lua errors " + str(errs[:2]), not errs)
print("PASS" if not fails else "FAILED %s" % fails)
if fails: raise SystemExit(1)
