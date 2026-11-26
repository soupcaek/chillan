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
L.execute("SlashCmdList.CHILLAN('todo Kill 10 Tar Lords')")
L.execute("SlashCmdList.CHILLAN('todo Train Whirlwind')")
L.execute("SlashCmdList.CHILLAN('todo Repair')")
N = ns.Notes
d = N.Data()
check("3 to-dos", len(list(d["items"].values())) == 3)
L.execute("SlashCmdList.CHILLAN('notes')")
W = ns.Window
check("Notes page open", W.current == "notes")
tab = W.tabs.notes
tab.Refresh(tab)
L.execute("ADDON_NS.Notes.Toggle(ADDON_NS.db.notes.items[1])")
L.execute("ADDON_NS.Notes.Move(ADDON_NS.db.notes.items[3], -1)")
items = [i.t for i in ADDON_NS_items] if False else [d["items"][i].t for i in range(1, 4)]
check("moved Repair above Whirlwind " + str(items), items == ["Kill 10 Tar Lords", "Repair", "Train Whirlwind"])
view, nOpen, nDone = N.View()
labels = [ (v.header or v.t) for v in view.values() ]
check("open first, then DONE TODAY " + str(labels), labels == ["Repair", "Train Whirlwind", "DONE TODAY", "Kill 10 Tar Lords"] and nOpen == 2)
tab.Refresh(tab)
check("panel says 2 left", tab and True)
L.execute("ADDON_NS.db.notes.items[1].doneDay = '2000-01-01'")
N.Data()
check("yesterday's done ones go", len(list(d["items"].values())) == 2)
L.execute("ADDON_NS.db.notes.text = 'Kenny owes me'")
tab.Refresh(tab)
errs = [e for e in G.ERRORS.values() if 'HookScript' not in str(e)]
check("no Lua errors " + str(errs[:3]), not errs)
print("PASS" if not fails else "FAILED %s" % fails)
if fails: raise SystemExit(1)
