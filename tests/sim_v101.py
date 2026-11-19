# 1.0.1: popup rules, react from the event window, bundled trophies, manual-only Cunt List, "Died to"
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
LB.execute('POPS = {}; ADDON_NS:Listen("DING", function(it) table.insert(POPS, it.kind) end)')
LB.execute('TOASTS = {}; ADDON_NS:Listen("TOAST", function(t) table.insert(TOASTS, t.title) end)')
run(3)
def deaths(n, gap=30):
    for i in range(n):
        LA.execute('ADDON_NS.Tracker:Event("DEAD", "Arathi Highlands", "PLAYER:1", "Stabsalot", "Level 60 Rogue")')
        run(gap)
# normal: 6 deaths in 3 min -> 1 popup
LB.execute('ADDON_NS.PopupGateReset()'); deaths(6)
print("normal, 6 deaths:", LB.eval('#POPS'))
# 10 min later: pops again
LB.execute('GT = GT + 601'); deaths(1)
print("after 10 min:", LB.eval('#POPS'))
# kills share nothing with deaths' cooldown
LA.execute('ADDON_NS.Tracker:Event("KILL", "Arathi Highlands", "KILL:1", "Bob", "")'); run(6)
LA.execute('ADDON_NS.Tracker:Event("KILL", "Arathi Highlands", "KILL:1", "Rob", "")'); run(6)
print("2 kills:", LB.eval('table.concat(POPS, " ")'))
# hourly cap of 6
LB.execute('POPS = {}; ADDON_NS.PopupGateReset()')
# deaths and kills alternating, each kind 10 min apart: 12 chances in ~55 min, the cap stops it at 6
for i in range(6):
    LB.execute('GT = GT + 300'); deaths(1, 2)
    LB.execute('GT = GT + 300'); LA.execute('ADDON_NS.Tracker:Event("KILL", "Arathi Highlands", "KILL:1", "Bob%d", "")' % i); run(6)
print("hour cap (12 chances):", LB.eval('#POPS'))
# calm: none; all: every one
LB.execute('POPS = {}; ADDON_NS.db.settings.popupLevel = "calm"; ADDON_NS.PopupGateReset()'); deaths(3)
print("calm:", LB.eval('#POPS'))
LB.execute('ADDON_NS.db.settings.popupLevel = "all"'); deaths(3)
print("all:", LB.eval('#POPS'))
LB.execute('ADDON_NS.db.settings.popupLevel = "normal"')
# event window: react link on A's death at B, gone after reacting
line = LB.eval('ADDON_NS.EventWindow.entries[#ADDON_NS.EventWindow.entries].text')
print("react link:", "chillanreact:" in line)
LB.execute('local it = ADDON_NS.EventWindow.entries[#ADDON_NS.EventWindow.entries].item; ADDON_NS.Data:React(it, 1); ADDON_NS.EventWindow:Redraw()')
print("after react:", "chillanreact:" in LB.eval('ADDON_NS.EventWindow.entries[#ADDON_NS.EventWindow.entries].text'))
# Died to (gang-wide, from death posts)
print("died to:", LB.eval('(function() local e = ADDON_NS.db.diedTo["stabsalot"] return e and (e.name .. " " .. e.n .. " " .. ADDON_NS.DiedTo:Victims(e)) end)()'))
print("enemy of the week:", LB.eval('(function() local e, n = ADDON_NS.DiedTo:WeekTop() return e and (e.name .. " " .. n) end)()'))
# revenge: B kills Stabsalot
LB.execute('ADDON_NS.Kills.PostKill("Stabsalot", "test")'); run(3)
print("revenge:", LB.eval('(function() for i = #ADDON_NS.db.feed, 1, -1 do local it = ADDON_NS.db.feed[i] if it.kind == "KILL" and it.c == "Stabsalot" then return it.b end end end)()'), LB.eval('ADDON_NS.db.cnt.revengeKills'))
# Cunt List: manual only. Migration 4 drops the automatic entries, an old client's auto entry is refused
LB.execute('''local db = ADDON_NS.db
db.cunts = { ["sneaky"] = { name = "Sneaky", reason = "ninja looted the Ironfoe", by = "x", t = time(), notes = {} },
  ["camper"] = { name = "Camper", reason = "From the enemy log", t = time(), notes = {} },
  ["ganker"] = { name = "Ganker", reason = "killed me in Tanaris · Level 60 Rogue", t = time(), notes = {} } }
ADDON_NS.MIGRATIONS[4](db)''')
print("cunts after cleanup:", LB.eval('(function() local t = {} for k in pairs(ADDON_NS.db.cunts) do t[#t+1] = k end table.sort(t) return table.concat(t, ",") end)()'))
LB.execute('ADDON_NS.Comm.handlers["CU"]({ "Autoguy", "From the enemy log", "x", "X-Realm", "0" })')
LB.execute('ADDON_NS.Comm.handlers["CU"]({ "Realguy", "stole my node", "x", "X-Realm", "0" })')
print("auto refused / manual kept:", LB.eval('ADDON_NS.db.cunts["autoguy"] == nil'), LB.eval('ADDON_NS.db.cunts["realguy"] ~= nil'))
# own small trophies within seconds: one notice
LA.execute('TT = {}; ADDON_NS:Listen("TOAST", function(t) if t.kind == "trophy" then table.insert(TT, t.title) end end)')
LA.execute('ADDON_NS.Ach:Notice(ADDON_NS.Ach.byId["K1"]); ADDON_NS.Ach:Notice(ADDON_NS.Ach.byId["Q10"]); ADDON_NS.Ach:Notice(ADDON_NS.Ach.byId["HOP1"])'); run(6)
print("trophy notices:", LA.eval('table.concat(TT, " | ")'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:4], [e for e in list(GB.ERRORS.values()) if 'HookScript' not in str(e)][:4])
