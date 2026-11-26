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
L.execute("""
ADDON_NS.db.people = ADDON_NS.db.people or {}
ADDON_NS.db.people.a = { pid = 'a', version = '1.4.71', chars = {}, live = {} }
ADDON_NS.db.people.b = { pid = 'b', version = '1.4.69', chars = {}, live = {} }
ADDON_NS.db.people.c = { pid = 'c', version = '1.4.72-dev3', chars = {}, live = {} }
""")
newest = L.eval("ADDON_NS.NewestRelease()")
print("newest", newest)
assert newest == "1.4.71", newest
assert L.eval("ADDON_NS.IsOutdated(ADDON_NS.db.people.b)") is True
assert not L.eval("ADDON_NS.IsOutdated(ADDON_NS.db.people.a)")
assert not L.eval("ADDON_NS.IsOutdated(ADDON_NS.db.people.c)")
L.execute("SlashCmdList.CHILLAN('versions')")
L.execute("ADDON_NS.Data:CheckVersion('1.4.99-dev1', 'c')")
assert L.eval("ADDON_NS.newestVersion") != "1.4.99-dev1"
errs = [e for e in G.ERRORS.values() if 'HookScript' not in str(e)]
assert not errs, errs
print("PASS")
