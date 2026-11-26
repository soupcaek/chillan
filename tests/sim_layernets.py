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
def outbox():
    out = [(m[1], m[2], m[3], m[4]) for m in G.OUTBOX.values()]
    G.OUTBOX = L.table_from([])
    return out
def adv(s): G.ADVANCE(s)

N = ns.LayerHop.Nets
check("LayerNets loaded", N is not None)
L.execute("ADDON_NS.db.settings = ADDON_NS.db.settings or {}")
S = L.eval("ADDON_NS.U.Settings()")
S.layerStrangers = True
adv(1); outbox()

# --- VoidNet's hourly channel: the same name for every user (checked against the formula, worked out here)
MOD = 2147483629; ALPHA = "bcdfghjkmnpqrstvwxz23456789"
def mix(h, n): return (h * 31 + n) % MOD
def code(seed, ln):
    h, out = seed, ""
    for i in range(1, ln + 1):
        h = mix(mix(h, i), 7919); out += ALPHA[h % len(ALPHA)]
    return out
def derive(slot, hour, side):
    salt = 52817 + slot
    s = mix(mix(mix(salt, hour), salt % 97), side)
    return "Vn" + code(s, 6), code(mix(s, 104729), 8)
name, pw = N.VN.Derive(0, 498777, 1)
check("VoidNet channel name/password " + name, (name, pw) == derive(0, 498777, 1))

# --- AutoLayer: zone code and line
def adler(s):
    a, b = 1, 0
    for ch in s.encode(): a = (a + ch) % 65521; b = (b + a) % 65521
    return "%04x%04x" % (b, a)
names = list(N.AL.Names().values())
check("AutoLayer channel names", names[0] == "layer" + adler("ClassicBetaPvP-26-11-2026") and names[-1] == "layer")
enc = N.AL.Encode(1411)
check("zone code round trip " + enc, N.AL.Decode(enc.lower()) == 1411)
z, body = N.AL.Parse("<AZ> <ALZ" + enc + "> inv layer")
check("AutoLayer ask parsed", z == 1411 and body is not None)
check("a line with a number isn't an ask", N.AL.Parse("<AZ> <ALZ" + enc + "> layer 3 pls") is None)

# --- hosting: Forever Layer Hop direct ask
G.FIRE("CHAT_MSG_ADDON", "FLHNET2", "DR|12345|1411|111111|222222", "WHISPER", "Stranger-ClassicBetaPvP")
adv(0.5)
o = outbox()
check("FLH: wrong layer key gets 'layer changed'", any(m[0] == "FLHNET2" and m[1].startswith("LN|12345|layer changed") for m in o))
G.FIRE("CHAT_MSG_ADDON", "FLHNET2", "WP|777|ClassicBetaPvP|0.1.3|1411|333333|1|LANG=en", "WHISPER", "Peer-ClassicBetaPvP")
adv(0.5)
wr = [m for m in outbox() if m[1].startswith("WR|777|")]
check("FLH: presence answered (WR)", len(wr) == 1)
mine = wr[0][1].split("|")[5] if wr else "0"
adv(4)
G.FIRE("CHAT_MSG_ADDON", "FLHNET2", "DR|12346|1411|%s|222222" % mine, "WHISPER", "Stranger-ClassicBetaPvP")
adv(0.5)
o = outbox()
check("FLH: LW + LI sent", any(m[1].startswith("LW|12346") for m in o) and any(m[1].startswith("LI|12346") for m in o))
adv(2)
check("FLH: stranger invited", G.LAST_INVITE == "Stranger-ClassicBetaPvP")
G.LAST_INVITE = None

# --- hosting: VoidNet
G.FIRE("CHAT_MSG_ADDON", "VLAYER", "Q:1:1:1411:424242:Asker-ClassicBetaPvP", "WHISPER", "Asker-ClassicBetaPvP")
adv(0.5)
a = [m for m in outbox() if m[1].startswith("A:1:1411:")]
check("VoidNet: answered as a host", len(a) == 1 and a[0][1].endswith(":1") and a[0][3] == "Asker-ClassicBetaPvP")
p = a[0][1].split(":")[3] if a else "0-0"
G.FIRE("CHAT_MSG_ADDON", "VLAYER", "HR:1:1411:%s:5555" % p, "WHISPER", "Asker-ClassicBetaPvP")
adv(0.5)
o = outbox()
check("VoidNet: HA ok + HP", any(m[1] == "HA:1:5555:ok" for m in o) and any(m[1].startswith("HP:1:5555:") for m in o))
adv(2)
check("VoidNet: asker invited", G.LAST_INVITE == "Asker-ClassicBetaPvP")
G.LAST_INVITE = None

# --- hosting: AutoLayer channel ask
N.AL.Join()
G.FIRE("CHAT_MSG_CHANNEL", "<AZ> <ALZ" + enc + "> inv layer", "Auto-ClassicBetaPvP", "", "5. layer", "", "", 0, 5, "layer")
adv(2)
check("AutoLayer: asker invited", G.LAST_INVITE == "Auto-ClassicBetaPvP")
G.LAST_INVITE = None
G.FIRE("CHAT_MSG_CHANNEL", "<AZ> <ALZ" + N.AL.Encode(1413) + "> inv layer", "Far-ClassicBetaPvP", "", "5. layer", "", "", 0, 5, "layer")
adv(2)
check("AutoLayer: other zone ignored", G.LAST_INVITE is None)

# --- hosting off: refused
S.layerStrangers = False
adv(70)
G.FIRE("CHAT_MSG_ADDON", "FLHNET2", "DR|12347|1411|%s|222222" % mine, "WHISPER", "Other-ClassicBetaPvP")
adv(0.5)
check("FLH: hosting off is said", any(m[1].startswith("LN|12347|hosting disabled") for m in outbox()))

# --- asking: an FLH host we heard of, then its invite is expected
G.FIRE("CHAT_MSG_ADDON", "FLHNET2", "HI|1411|55555|1|0.2.1|ClassicBetaPvP|LANG=en", "WHISPER", "Hosty-ClassicBetaPvP")
L.execute("ADDON_NS.LayerHop.mine = { id = 'x', t = ADDON_NS.Now(), mode = 'ls', whispered = {} }")
m = L.eval("ADDON_NS.LayerHop.mine")
N.FLH.Ask(m)
adv(0.5)
dr = [x for x in outbox() if x[0] == "FLHNET2" and x[1].startswith("DR|") and x[3] == "Hosty-ClassicBetaPvP"]
check("FLH ask: direct ask to the host", len(dr) == 1)
rid = dr[0][1].split("|")[1] if dr else "0"
G.FIRE("CHAT_MSG_ADDON", "FLHNET2", "LW|" + rid, "WHISPER", "Hosty-ClassicBetaPvP")
G.FIRE("CHAT_MSG_ADDON", "FLHNET2", "LI|" + rid, "WHISPER", "Hosty-ClassicBetaPvP")
check("FLH ask: counted as asked + answered", m.netSent == 1 and L.eval("ADDON_NS.LayerHop.mine.netReplies and ADDON_NS.LayerHop.mine.netReplies['hosty'] == 'host'"))
G.FIRE("PARTY_INVITE_REQUEST", "Hosty-ClassicBetaPvP")
check("FLH ask: the host's invite is offered to accept", m.pendingHost == "Hosty-ClassicBetaPvP")
big, small, _c = L.eval("ADDON_NS.LayerHop:TileState()")
check("tile: " + str(small), str(small).startswith("Asked 1, 1 answered"))

# --- asking: VoidNet wave to the channel's members, a host answers, we ask it to invite
L.execute("ADDON_NS.LayerHop.mine = { id = 'y', t = ADDON_NS.Now(), mode = 'ls', whispered = {} }")
m = L.eval("ADDON_NS.LayerHop.mine")
L.execute("ADDON_NS.LayerHop.Nets.VN.roster = { names = { 'Void-ClassicBetaPvP', 'Two-ClassicBetaPvP' }, keys = { void = 'Void-ClassicBetaPvP', two = 'Two-ClassicBetaPvP' }, at = GetTime() }")
N.VN.Ask(m)
adv(0.5)
q = [x[3] for x in outbox() if x[0] == "VLAYER" and x[1].startswith("Q:1:1:1411:")]
check("VoidNet ask: Q to the channel's members (and a host heard before)", {"Void-ClassicBetaPvP", "Two-ClassicBetaPvP", "Asker-ClassicBetaPvP"} == set(q))
G.FIRE("CHAT_MSG_ADDON", "VLAYER", "A:1:1411:987654-0:1", "WHISPER", "Void-ClassicBetaPvP")
adv(0.5)
hr = [x for x in outbox() if x[1].startswith("HR:1:1411:987654-0:")]
check("VoidNet ask: HR to the host", len(hr) == 1 and hr[0][3] == "Void-ClassicBetaPvP")

# --- AutoLayer: my own line seen → any invite in the next 45 s is accepted
G.FIRE("CHAT_MSG_CHANNEL", "<AZ> inv layer", "Thunka-ClassicBetaPvP", "", "5. layer", "", "", 0, 5, "layer")
G.FIRE("PARTY_INVITE_REQUEST", "Random-ClassicBetaPvP")
check("AutoLayer ask: an unasked invite right after is offered", m.pendingHost == "Random-ClassicBetaPvP")

# another layer addon loaded: the hint
L.execute("C_AddOns = C_AddOns or {}; C_AddOns.IsAddOnLoaded = function(n) return n == 'LayerSwap' end; ADDON_NS.db.layerHintDay = nil")
found = list(N.OthersLoaded().values())
check("other layer addons found", found == ["LayerSwap"])

errs = [e for e in G.ERRORS.values() if 'HookScript' not in str(e)]
check("no Lua errors " + str(errs[:3]), not errs)
print("PASS" if not fails else "FAILED: %s" % fails)
if fails: raise SystemExit(1)
