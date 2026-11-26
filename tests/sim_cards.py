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
local P = ADDON_NS.db.people
P.z9 = { pid = 'z9', version = '1.4.71', chars = {} }
P.e1 = { pid = 'e1', version = '0.30.7', alias = 'Eirik', main = 'Yung-Realm', lastSeen = ADDON_NS.Now() - 120,
  chars = { ['Yung-Realm'] = { name = 'Yung', class = 'SHAMAN', level = 53, race = 'Orc', played = 500000 },
            ['Alt-Realm'] = { name = 'Alt', class = 'MAGE', level = 20, played = 20000 } },
  stats = { wk = ADDON_NS.WeekKey(), wQuests = 146, wKills = 44, wDeaths = 35, wGold = 99999, tGold = 4693800, tQuests = 388 },
  live = { zone = 'Blackrock Depths' }, s3 = { xp = 103695, xpMax = 167100, money = 2821400, ilvl = 48, dura = 85, streak = 4, today = 11580 } }
""")
L.execute("""
local D = ADDON_NS.Data
D:ApplyEvent('r1', 'e1', 'Yung-Realm', 'DUNGEON', ADDON_NS.Now() - 3600, 'Blackrock Depths', '5400', '2', '12|e1')
D:ApplyEvent('r2', 'e1', 'Yung-Realm', 'DUNGEON', ADDON_NS.Now() - 600, 'Blackrock Depths', '4800', '1', '12|e1')
D:ApplyEvent('b1', 'z9', 'Z-Realm', 'BOSS', ADDON_NS.Now() - 500, 'Blackrock Depths', 'Lord Roccor', '42', '0:1:2:e1')
D:ApplyEvent('b2', 'z9', 'Z-Realm', 'BOSS', ADDON_NS.Now() - 400, 'Sunken Temple', 'Shade of Eranikus', '3', '0:1:2:e1')
D:ApplyEvent('l1', 'e1', 'Yung-Realm', 'LOOT', ADDON_NS.Now() - 100, '12345', '3')
""")
p = L.eval("ADDON_NS.db.people.e1")
x = L.eval("ADDON_NS.PvETally:For('e1')")
check("tally: 2 runs, 1 boss (credited from someone else's post)", x and x.runs == 2 and x.bosses == 2)
check("tally: fastest boss Roccor 42 s", x.fastBoss.boss == "Lord Roccor" and x.fastBoss.s == 42)
check("week gold hidden for an old version", "needs update" in str(L.eval("ADDON_NS.WeekGoldLine(ADDON_NS.db.people.e1)")))
check("version line old", "old" in str(L.eval("ADDON_NS.VersionLine(ADDON_NS.db.people.e1)")))
check("played line", "chars" in str(L.eval("ADDON_NS.PlayedLine(ADDON_NS.db.people.e1)")))
# player page
L.execute("ADDON_NS.Window:Create(); ADDON_NS.Window.frame:Show(); ADDON_NS.Window:OpenPlayer('e1')")
check("player page open", ns.Window.current == "player")
L.execute("ADDON_NS.Window:Select('home'); ADDON_NS.Window.tabs.home:Refresh()")
check("home open", ns.Window.current == "home")
# hover cards
L.execute("ADDON_NS.PersonCard:Show(nil, 'e1', 'cursor')")
check("pulse card shown", ns.PersonCard.frame.IsShown(ns.PersonCard.frame))
L.execute("ADDON_NS.PersonCard:Pin('e1')")
L.execute("local q = ADDON_NS.UI.PersonQuick(UIParent, { side = 'right', width = 400 }); local row = CreateFrame('Frame', nil, UIParent); row.item = ADDON_NS.db.people.e1; q:Toggle(row, ADDON_NS.db.people.e1); QQ = q")
check("quick card has height", (L.eval("QQ:GetHeight()") or 0) > 200)
errs = [e for e in G.ERRORS.values() if 'HookScript' not in str(e)]
check("no Lua errors " + str(errs[:3]), not errs)
print("PASS" if not fails else "FAILED %s" % fails)
if fails: raise SystemExit(1)
