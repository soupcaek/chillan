import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__)) + "/"
REPO = _os.path.dirname(HERE.rstrip("/")) + "/"
exec(open("sim.py").read().split("A = client(")[0])
from lupa import lua51
def client2(name):
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    mock = open(HERE + "mock.lua").read()
    me = L.table_from({"name": name, "realm": "ClassicBetaPvP", "class": "WARRIOR", "race": "Orc", "level": 20, "zone": "The Barrens", "money": 1000})
    f = L.eval("function(src, me) local f = assert(loadstring(src)) f(me) end"); f(mock, me)
    L.execute('''TwitchEmotes_defaultpack = { Kappa = "Interface\\\\AddOns\\\\TwitchEmotes\\\\Emotes\\\\Kappa.tga:28:28", KEKW = "Interface\\\\AddOns\\\\TwitchEmotes\\\\Emotes\\\\KEKW.tga:28:28", catJAM = "Interface\\\\AddOns\\\\TwitchEmotes\\\\Emotes\\\\catJAM.tga:32:28" }
    TwitchEmotes_emoticons = { ["Kappa"]="Kappa", ["KEKW"]="KEKW", [":)"]="Kappa", ["catJAM"]="catJAM" }''')
    ns = L.globals().LOAD(BASE, L.table_from(toc)); G = L.globals()
    G.FIRE("ADDON_LOADED", "Chillan"); G.FIRE("PLAYER_LOGIN"); G.FIRE("PLAYER_ENTERING_WORLD", True, False)
    return L, G, ns
A = client2("Grimtusk")
L, G, ns = A
G.ADVANCE(5)
print("available:", ns.Emotes.Available(ns.Emotes), "count:", ns.Emotes.Count(ns.Emotes))
print("render:", ns.RenderChatText("lol Kappa, @all KEKW catJAM!", "D9F0F7"))
print("search:", list(ns.Emotes.Search(ns.Emotes, "ka").values()))
print("reaction:", ns.ReactionText(L.table_from({"kind":"DEAD"}), 7))
E = ns.EventWindow; e = E.input.edit
e.SetFocus(e); e.SetText(e, "hei :ke"); e._scripts["OnTextChanged"](e, True); e._scripts["OnTabPressed"](e)
print("colon+tab:", e.GetText(e))
e.SetText(e, "lol cat"); e._scripts["OnTabPressed"](e)
print("word+tab:", e.GetText(e))
E.input.emoteBtn._scripts["OnClick"](E.input.emoteBtn)
G.FIRE_SLASH = None
print("FEIL:", list(G.ERRORS.values())[:6])
