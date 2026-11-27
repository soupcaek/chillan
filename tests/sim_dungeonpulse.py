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
check("loot: only the epic gets an icon", lr and LA.eval(f + '.lootIcons[1]:IsShown()') and not LA.eval(f + '.lootIcons[2]:IsShown()'))
LA.execute('ADDON_NS.NowCard:LootTooltip(UIParent)')
# (1.4.77) this client's links carry the quality as |cnIQ3: – a blue you loot yourself counts
LA.execute('FIRE("CHAT_MSG_LOOT", "You receive loot: |cnIQ3:|Hitem:12936::::::::60:::::|h[Bracers of Valor]|h|r.")')
check("cnIQ3 link is rare", LA.eval('ADDON_NS.Pulse.LinkQuality("|cnIQ3:|Hitem:12936|h[x]|h|r")') == 3)
LA.execute('ADDON_NS.NowCard:Update()')
lr = LA.eval(f + '.lootRow')
txt = clean(f + '.lines[%d]:GetText()' % lr)
check("loot line counts it, short label: " + str(txt), txt.startswith("Loot:") and LA.eval(f + '.lootIcons[2]:IsShown()'))
LA.execute(f + '.lootIcons[1]:GetScript("OnEnter")(' + f + '.lootIcons[1])')
# pull timer solo (allowed), chip counts down
LA.execute('ADDON_NS.Extras:Pull("5")'); run(1)
LA.execute('ADDON_NS.NowCard:Update()')
check("pull chip " + str(LA.eval(f + '.pull.t:GetText()')), str(LA.eval(f + '.pull.t:GetText()')).startswith("Pull in"))
run(8)
LA.execute('ADDON_NS.NowCard:Update()')
check("pull chip gone after", not LA.eval(f + '.pull:IsShown()'))
# the posted run name carries the side
check("run name " + str(LA.eval('ADDON_NS.Bosses:RunName("Stratholme", { ["Baroness Anastari"] = 200 })')), LA.eval('ADDON_NS.Bosses:RunName("Stratholme", { ["Baroness Anastari"] = 200 })') == "Stratholme · Service Entrance")
# a priest's Spirit of Redemption: dead, angel for 15 s, dead again = one death
d0 = LA.eval('ADDON_NS.Extras:Current() and ADDON_NS.Extras:Current().deaths or -1') if LA.eval('ADDON_NS.Extras.Current ~= nil') else None
LA.execute('UnitIsDeadOrGhost = function(u) return u == "party1" end; UnitName = (function(o) return function(u) if u == "party1" then return "Kenny" end return o(u) end end)(UnitName); GetNumGroupMembers = function() return 2 end'); run(2)
LA.execute('UnitIsDeadOrGhost = function() return false end'); run(15)
LA.execute('UnitIsDeadOrGhost = function(u) return u == "party1" end'); run(2)
LA.execute('UnitIsDeadOrGhost = function() return false end'); run(1)
kd = LA.eval('(function() local r = ADDON_NS.Extras:RunSummary() return r and r.deaths end)()')
check("priest angel: one death, not two (" + str(kd) + ")", kd == 1)
# feed filter: dungeon only hides events from people outside the group, keeps chat
LA.execute('ADDON_NS.db.settings.feedHere = true; ADDON_NS.EventWindow:Redraw(); ADDON_NS.EventWindow:HereSwitch()')
LA.execute('ADDON_NS.db.settings.feedHere = nil; ADDON_NS.EventWindow:Redraw()')
errs = [e for e in GA.ERRORS.values()]
check("no Lua errors " + str(errs[:2]), not errs)
print("PASS" if not fails else "FAILED %s" % fails)
if fails: raise SystemExit(1)
