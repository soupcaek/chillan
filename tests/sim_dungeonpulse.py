# 1.4.76 Dungeon Pulse: choices at the door, the rolling boss list, loot so far, the pull timer
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(3)
fails = []
def check(label, ok):
    print(("ok  " if ok else "FAIL") + " " + label)
    if not ok: fails.append(label)
def clean(s): return LA.eval('(function(x) return (tostring(x):gsub("|T.-|t", "#"):gsub("|c%%x%%x%%x%%x%%x%%x%%x%%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")) end)(%s)' % s)
LA.execute('IN_INSTANCE = true; GetInstanceInfo = function() return "Stratholme" end; FIRE("PLAYER_ENTERING_WORLD")'); run(6)
LA.execute('ADDON_NS.NowCard:Update()')
f = 'ADDON_NS.NowCard.frame'
check("door: two sides " + str(LA.eval(f + '.doors[1].t:GetText()')) + " / " + str(LA.eval(f + '.doors[2].t:GetText()')),
      LA.eval(f + '.doors[1]:IsShown()') and LA.eval(f + '.doors[2].t:GetText()') == "Service Entrance" and "6 bosses" in str(LA.eval(f + '.doors[2].s:GetText()')))
check("door line", "Which side" in clean(f + '.lines[1]:GetText()'))
LA.execute('FIRE("ENCOUNTER_START", 1, "Baroness Anastari", 1, 5)'); run(10)
LA.execute('FIRE("ENCOUNTER_END", 1, "Baroness Anastari", 1, 5, 1)'); run(3)
LA.execute('ADDON_NS.NowCard:Update()')
check("doors gone", not LA.eval(f + '.doors[1]:IsShown()'))
check("head says the side: " + str(LA.eval(f + '.head:GetText()')), LA.eval(f + '.head:GetText()') == "STRATHOLME · SERVICE ENTRANCE")
rows = [clean(f + '.brows[%d].name:GetText()' % i) for i in range(1, 6)]
print("  rows", rows)
check("✓ Anastari, ▸ next lit, two after, +2 more", rows[0] == "Baroness Anastari" and rows[1] == "Magistrate Barthilas" and LA.eval(f + '.brows[2].bg:IsShown()') and rows[4].startswith("+2 more"))
LA.execute('FIRE("CHAT_MSG_LOOT", "Kenny receives loot: |cffa335ee|Hitem:13505::::::::60:::::|h[Runeblade of Baron Rivendare]|h|r.")')
LA.execute('FIRE("CHAT_MSG_LOOT", "Kenny receives loot: |cff1eff00|Hitem:13000::::::::60:::::|h[Green thing]|h|r.")')
LA.execute('ADDON_NS.NowCard:Update()')
lr = LA.eval(f + '.lootRow')
check("loot so far: only the epic " + str(clean(f + '.lines[%d]:GetText()' % (lr or 1))), lr and clean(f + '.lines[%d]:GetText()' % lr).count("#") == 1)
LA.execute('ADDON_NS.NowCard:LootTooltip(UIParent)')
# pull timer solo (allowed), chip counts down
LA.execute('ADDON_NS.Extras:Pull("5")'); run(1)
LA.execute('ADDON_NS.NowCard:Update()')
check("pull chip " + str(LA.eval(f + '.pull.t:GetText()')), str(LA.eval(f + '.pull.t:GetText()')).startswith("Pull in"))
run(8)
LA.execute('ADDON_NS.NowCard:Update()')
check("pull chip gone after", not LA.eval(f + '.pull:IsShown()'))
# the posted run name carries the side
check("run name " + str(LA.eval('ADDON_NS.Bosses:RunName("Stratholme", { ["Baroness Anastari"] = 200 })')), LA.eval('ADDON_NS.Bosses:RunName("Stratholme", { ["Baroness Anastari"] = 200 })') == "Stratholme · Service Entrance")
# feed filter: dungeon only hides events from people outside the group, keeps chat
LA.execute('ADDON_NS.db.settings.feedHere = true; ADDON_NS.EventWindow:Redraw(); ADDON_NS.EventWindow:HereSwitch()')
LA.execute('ADDON_NS.db.settings.feedHere = nil; ADDON_NS.EventWindow:Redraw()')
errs = [e for e in GA.ERRORS.values()]
check("no Lua errors " + str(errs[:2]), not errs)
print("PASS" if not fails else "FAILED %s" % fails)
if fails: raise SystemExit(1)
