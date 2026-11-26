# 1.4.71: Forever Layer Hop, VoidNet and AutoLayer behind the same Swap button (LayerNets.lua)
import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__)) + "/"
REPO = _os.path.dirname(HERE.rstrip("/")) + "/"
from lupa import lua51
toc = [l.strip().replace("\\", "/") for l in open(REPO + "Chillan_Camelot.toc") if l.strip().endswith(".lua")]

def client(name):
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
''')
    ns = L.globals().LOAD(REPO, L.table_from(toc))
    ns.debug = True
    G = L.globals()
    G.FIRE("ADDON_LOADED", "Chillan"); G.FIRE("PLAYER_LOGIN"); G.FIRE("PLAYER_ENTERING_WORLD", True, False)
    return L, G, ns

L, G, ns = client("Thunka")
fails = []
def check(label, ok):
    print(("ok  " if ok else "FAIL") + " " + label)
    if not ok: fails.append(label)
L.execute("""
UnitClass = function(u) if u == 'player' then return 'Shaman', 'SHAMAN' end return 'Rogue', 'ROGUE' end
UnitName = function(u) if u == 'player' then return 'Thunka' end if u == 'party1' then return 'Kenny' end if u == 'party2' then return 'Valdrin' end end
GetNumGroupMembers = function() return 3 end
IsInRaid = function() return false end
GetLootRollItemLink = function() return '|cff0070dd|Hitem:16723::::::::60:::::|h[Lightforge Belt]|h|r' end
GetLootRollItemInfo = function() return 132500 end
GetItemInfo = function() return nil end
""")
R = ns.LootRolls
link = "|cff0070dd|Hitem:16723::::::::60:::::|h[Lightforge Belt]|h|r"
e = R.Parse("Kenny has selected Greed for: " + link)
check("parse greed", e and e.kind == "Greed" and e.who == "Kenny")
e = R.Parse("Need Roll - 87 for " + link + " by Valdrin")
check("parse roll", e and e.kind == "roll" and e.roll == 87 and e.who == "Valdrin")
e = R.Parse("You passed on: " + link)
check("parse self pass", e and e.kind == "Pass" and e.who == "Thunka")
check("ordinary loot isn't a roll line", R.Parse("You receive loot: " + link) is None)
G.FIRE("START_LOOT_ROLL", 7, 60000)
G.ADVANCE(0.2)
roll = R.rolls[7]
check("roll opened with the group", roll is not None and len(list(roll.players.values())) == 3)
for line in ("Kenny has selected Greed for: ", "Valdrin has selected Need for: ", "You have selected Need for: "):
    G.FIRE("CHAT_MSG_LOOT", line + link)
G.FIRE("CHAT_MSG_LOOT", "Need Roll - 87 for " + link + " by Valdrin")
G.FIRE("CHAT_MSG_LOOT", "Need Roll - 41 for " + link + " by Thunka")
check("panel: 3 of 3", "3 of 3" in str(roll.panel.right.GetText(roll.panel.right)))
G.FIRE("CHAT_MSG_LOOT", "[Loot]: Kenny Surname has selected Greed for: " + link)
check("[Loot] prefix + surname matched to Kenny", len(list(roll.players.values())) == 3)
G.FIRE("CHAT_MSG_LOOT", "Valdrin won: " + link)
check("winner set", roll.winner == "Valdrin" and roll.done)
r1 = roll.panel.rows[1]
check("winner first with star", "Valdrin" in str(r1.name.GetText(r1.name)) and r1.star.GetText(r1.star) == "\u2605")
G.ADVANCE(21)
check("closes after 20 s", R.rolls[7] is None)
check("finished roll remembered", len(list(R.history.values())) == 1)
L.execute("SlashCmdList.CHILLAN('rolls')")
past = [r for k, r in R.rolls.items()]
check("/chill rolls reopens it", len(past) == 1 and past[0].winner == "Valdrin")
G.ADVANCE(20)
check("a reopened list stays", len([r for k, r in R.rolls.items()]) == 1)
L.execute("for _, r in pairs(ADDON_NS.LootRolls.rolls) do ADDON_NS.LootRolls:Close(r, true) end")
check("the close button closes it", len([r for k, r in R.rolls.items()]) == 0)
L.execute("SlashCmdList.CHILLAN('need')")
G.ADVANCE(9)
t = [r for k, r in R.rolls.items()]
check("test roll finished with a winner", len(t) == 1 and t[0].winner == "Eirik")
G.ADVANCE(9)
errs = [e for e in G.ERRORS.values() if 'HookScript' not in str(e)]
check("no Lua errors " + str(errs[:3]), not errs)
print("PASS" if not fails else "FAILED %s" % fails)
if fails: raise SystemExit(1)
