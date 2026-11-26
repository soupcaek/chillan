# 1.4.74: loot rolls grow out of Pulse; the picks come from the loot history list (this client has no
# "Kenny has selected Greed" chat lines for others), with the chat lines as a fallback
import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__)) + "/"
REPO = _os.path.dirname(HERE.rstrip("/")) + "/"
from lupa import lua51
toc = [l.strip().replace("\\", "/") for l in open(REPO + "Chillan_Camelot.toc") if l.strip().endswith(".lua")]

def client(name, history):
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    mock = open(HERE + "mock.lua").read()
    me = L.table_from({"name": name, "realm": "ClassicBetaPvP", "class": "WARRIOR", "race": "Orc", "level": 33, "zone": "Durotar", "money": 1000})
    f = L.eval("function(src, me) local f = assert(loadstring(src)) f(me) end")
    f(mock, me)
    L.execute('''
GetServerTime = function() return 1795600000 end
C_DateAndTime = { GetCurrentCalendarTime = function() return { monthDay = 26, month = 11, year = 2026, hour = 10, minute = 0 } end }
GetRealmName = function() return "ClassicBetaPvP" end
GetUnitName = function() return (UnitName("player")) end
GetChannelList = function() return 1, "General", false, 2, "Trade", false end
GetNumDisplayChannels = function() return 0 end
UnitGUID = function() return "Player-1234-ABCDEF" end
GetLocale = function() return "enUS" end
Enum.EncounterLootDropRollState = { NeedMainSpec = 0, NeedOffSpec = 1, Transmog = 2, Greed = 3, NoRoll = 4, Pass = 5 }
''')
    if history:
        L.execute('''
DROPS = {}
C_LootHistory = { GetSortedInfoForDrop = function(e, k) return DROPS[e .. ":" .. k] end }
''')
    ns = L.globals().LOAD(REPO, L.table_from(toc))
    ns.debug = True
    G = L.globals()
    G.FIRE("ADDON_LOADED", "Chillan"); G.FIRE("PLAYER_LOGIN"); G.FIRE("PLAYER_ENTERING_WORLD", True, False)
    L.execute("""
UnitClass = function(u) if u == 'player' then return 'Shaman', 'SHAMAN' end return 'Rogue', 'ROGUE' end
UnitName = function(u) if u == 'player' then return 'Thunka' end if u == 'party1' then return 'Kenny' end if u == 'party2' then return 'Valdrin' end end
GetNumGroupMembers = function() return 3 end
IsInRaid = function() return false end
GetLootRollItemLink = function() return '|cff0070dd|Hitem:16723::::::::60:::::|h[Lightforge Belt]|h|r' end
GetLootRollItemInfo = function() return 132500 end
""")
    return L, G, ns

fails = []
def check(label, ok):
    print(("ok  " if ok else "FAIL") + " " + label)
    if not ok: fails.append(label)
link = "|cff0070dd|Hitem:16723::::::::60:::::|h[Lightforge Belt]|h|r"

# ---- this client: the history list ----
L, G, ns = client("Thunka", True)
R = ns.LootRolls
def setdrop(states, winner=None, allpassed=False):
    rows = ",".join("{ playerName = '%s', playerClass = 'ROGUE', state = %s, roll = %s, isWinner = %s }" % (n, s, r or "nil", "true" if n == winner else "false") for n, s, r in states)
    L.execute("DROPS['5:1'] = { itemHyperlink = '%s', rollInfos = { %s }, winner = %s, allPassed = %s }" %
              (link, rows, ("{ playerName = '%s' }" % winner) if winner else "nil", "true" if allpassed else "false"))
    G.FIRE("LOOT_HISTORY_UPDATE_DROP", 5, 1)
G.FIRE("START_LOOT_ROLL", 7, 60000)
G.ADVANCE(0.2)
setdrop([("Thunka", 4, None), ("Kenny Surname", 4, None), ("Valdrin-Realm", 4, None)])
drops = list(R.drops.values())
check("one row, tied to the game's roll", len(drops) == 1 and drops[0].rollID == 7 and drops[0].hkey == "h5:1")
check("section shown", R.frame.IsShown(R.frame))
setdrop([("Thunka", 4, None), ("Kenny Surname", 3, None), ("Valdrin-Realm", 0, None)])
check("others' picks show: " + str(R.Tally(drops[0])), R.Tally(drops[0]) == "Need 1 · Greed 1 · 1 waiting")
check("your line while choosing", R.YouLine(drops[0]) == "You: pick in the game's window")
b = R.frame.blocks[1]
check("row text", "Need 1" in str(b.tally.GetText(b.tally)) and "s" in str(b.time.GetText(b.time)))
setdrop([("Thunka", 5, None), ("Kenny Surname", 3, 12), ("Valdrin-Realm", 0, 87)], winner="Valdrin-Realm")
check("winner: one line " + str(R.Tally(drops[0])), drops[0].done and R.Tally(drops[0]) == "Valdrin wins · Need 87")
check("you passed", R.YouLine(drops[0]) == "You: Pass")
check("winner in class colour", "|c" in str(b.tally.GetText(b.tally)) and "Valdrin" in str(b.tally.GetText(b.tally)))
check("remembered", len(list(R.history.values())) == 1)
h0 = R.frame.GetHeight(R.frame)
L.execute("ADDON_NS.LootRolls.hovered = ADDON_NS.LootRolls.drops[1] ADDON_NS.LootRolls:Layout()")
check("hover opens who picked what", R.frame.GetHeight(R.frame) > h0 + 40)
L.execute("""local b = ADDON_NS.LootRolls.frame.blocks[1] HIDES = 0 local o = b.Hide b.Hide = function(self) HIDES = HIDES + 1 return o(self) end
ADDON_NS.LootRolls:Layout() b.Hide = o""")
check("a repaint never hides the hovered row (that made it blink)", L.globals().HIDES == 0)
l1 = b.lines[1]
check("winner first with a star", "Valdrin" in str(l1.name.GetText(l1.name)) and l1.star.GetText(l1.star) == "★")
G.ADVANCE(1)
check("hover clears when the mouse isn't there (no stuck rows)", R.hovered is None)
G.ADVANCE(21)
check("gone after 20 s, section closes", len(list(R.drops.values())) == 0 and not R.frame.IsShown(R.frame))
L.execute("SlashCmdList.CHILLAN('rolls')")
check("/chill rolls shows the last 5", R.frame.IsShown(R.frame))
G.ADVANCE(62)
check("and closes after a minute", not R.frame.IsShown(R.frame))
# 40 players: gang first, 8 names
names = ",".join("{ playerName = 'P%d', state = 3 }" % i for i in range(40))
L.execute("DROPS['6:1'] = { itemHyperlink = '%s', rollInfos = { %s, { playerName = 'Thunka', state = 5 } } }" % (link, names))
G.FIRE("LOOT_HISTORY_UPDATE_DROP", 6, 1)
d = [x for x in R.drops.values()][0]
lst, more = R.Names(d)
check("big group: 8 names, +33 more, you first", len(list(lst.values())) == 8 and more == 33 and lst[1].name == "Thunka")
L.execute("SlashCmdList.CHILLAN('need')")
G.ADVANCE(2)
L.execute("SlashCmdList.CHILLAN('need')")
G.ADVANCE(9)
t = [x for x in R.drops.values() if x.test]
check("/chill need twice: still one test row", len(t) == 1 and t[0].winner == "Eirik")
G.ADVANCE(9)
check("finished test row goes by itself", len([x for x in R.drops.values() if x.test]) == 0)
L.execute("SlashCmdList.CHILLAN('need')")
G.ADVANCE(1)
L.execute("ADDON_NS.LootRolls:CloseAll()")
check("the header ✕ closes test rows", len([x for x in R.drops.values() if x.test]) == 0)
errs = [e for e in G.ERRORS.values() if 'HookScript' not in str(e)]
check("no Lua errors " + str(errs[:3]), not errs)

r = ns.GangRoll("/roll")
check("/roll in gang chat " + str(r), r.startswith("rolls ") and r.endswith("(1-100)"))
check("/roll 10-20", ns.GangRoll("/roll 10-20").endswith("(10-20)") and ns.GangRoll("/roll 50").endswith("(1-50)"))
check("ordinary text isn't a roll", ns.GangRoll("rolling soon") is None and ns.GangRoll("/rollx") is None)
# ---- fallback: chat lines ----
L, G, ns = client("Thunka", False)
R = ns.LootRolls
e = R.Parse("|cff00ff00[Loot]|r: Kenny has selected Greed for: " + link)
check("parse coloured tag", e and e.kind == "Greed" and e.who == "Kenny")
e = R.Parse("|Hplayer:Kenny|h[Kenny]|h has selected Need for: " + link)
check("parse player link", e and e.who == "Kenny")
check("ordinary loot isn't a roll line", R.Parse("You receive loot: " + link) is None)
G.FIRE("START_LOOT_ROLL", 7, 60000)
G.ADVANCE(0.2)
d = [x for x in R.drops.values()][0]
check("fallback: group as roster", len(list(d.players.values())) == 3)
for ln in ("Kenny Surname has selected Greed for: ", "Valdrin has selected Need for: ", "You passed on: "):
    G.FIRE("CHAT_MSG_LOOT", "[Loot]: " + ln + link)
check("fallback tally " + str(R.Tally(d)), R.Tally(d) == "Need 1 · Greed 1 · Pass 1" and len(list(d.players.values())) == 3)
G.FIRE("CHAT_MSG_LOOT", "Need Roll - 87 for " + link + " by Valdrin")
G.FIRE("CHAT_MSG_LOOT", "Valdrin won: " + link)
check("fallback winner", d.done and R.Tally(d) == "Valdrin wins · Need 87")
errs = [e for e in G.ERRORS.values() if 'HookScript' not in str(e)]
check("no Lua errors " + str(errs[:3]), not errs)
print("PASS" if not fails else "FAILED %s" % fails)
if fails: raise SystemExit(1)
