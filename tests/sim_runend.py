# 1.4.62 dungeon recap timing: the run ends at once when you leave the group, the group is new,
# the dungeon is reset or you queue; otherwise 5 minutes outside (time dead doesn't count)
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
L, G, ns = A
def runs(): return L.eval('#(ADDON_NS.db.runs or {})')
def enter():
    L.execute('''IsInInstance = function() return true, "party" end
GetInstanceInfo = function() return "Wailing Caverns", "party", 1, "", 5, 0, false, 43 end''')
    G.FIRE("PLAYER_ENTERING_WORLD", False, True); run(4)
    L.execute('NOW = NOW + 300'); run(4)
    G.FIRE("ENCOUNTER_END", 585, "Lady Anacondra", 1, 5, 1); run(4)
def leave():
    L.execute('IsInInstance = function() return false, "none" end; GetInstanceInfo = function() return "" end')
    G.FIRE("PLAYER_ENTERING_WORLD", False, False); run(4)
GROUP = ["Grimtusk", "Bob", "Tim"]
def setGroup(names):
    L.execute('GNAMES = {%s}' % ",".join('"%s"' % n for n in names))
    L.execute('''GetNumGroupMembers = function() return #GNAMES end
IsInGroup = function() return #GNAMES > 1 end
UnitName = function(u) if u == "player" then return MOCK_ME.name end local i = tonumber((u or ""):match("party(%d)")) return i and GNAMES[i + 1] end''')
base = runs()
# 1) grouped: walk out, the group is still there -> waits; then you leave the group -> ends at once
setGroup(GROUP); enter(); leave(); run(20)
waiting = runs() == base
setGroup(["Grimtusk"]); G.FIRE("GROUP_ROSTER_UPDATE"); run(4)
print("grouped: waited while in the group:", waiting, "| ended on leaving the group:", runs() == base + 1)
assert waiting and runs() == base + 1
# 2) a new group outside -> ends at once
setGroup(GROUP); enter(); leave()
setGroup(["Grimtusk", "Xx", "Yy", "Zz"]); G.FIRE("GROUP_ROSTER_UPDATE"); run(4)
print("new group ends it:", runs() == base + 2); assert runs() == base + 2
# 3) reset message
setGroup(GROUP); enter(); leave()
G.FIRE("CHAT_MSG_SYSTEM", "Wailing Caverns has been reset."); run(2)
print("reset ends it:", runs() == base + 3); assert runs() == base + 3
# 4) solo: walking out doesn't end it; dead time doesn't count; 5 minutes alive outside does
setGroup(["Grimtusk"]); enter(); leave()
L.execute('DEAD = true; UnitIsDeadOrGhost = function(u) return DEAD end')
for _ in range(40):
    L.execute('NOW = NOW + 10'); run(10)
dead_wait = runs() == base + 3
L.execute('DEAD = false; NOW = NOW + 200'); run(10)
mid = runs() == base + 3
L.execute('NOW = NOW + 120'); run(10)
print("solo: waited while dead:", dead_wait, "| ended after 5 min alive outside:", runs() == base + 4)
assert dead_wait and mid and runs() == base + 4
print("FEIL:", list(G.ERRORS.values())[:4])
