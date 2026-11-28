# 1.4.79: LayerSwap users get an answer even when we don't host (o / p / same), battleground queue
# pauses hosting, and our hidden channels give General/Trade their numbers back
exec(open(__file__.replace("sim_layeranswers", "sim_layernets")).read().split("L, G, ns = client")[0])
L, G, ns = client("Thunka")
fails = []
def check(label, ok):
    print(("ok  " if ok else "FAIL") + " " + label)
    if not ok: fails.append(label)
def outbox():
    out = [(m[1], m[2], m[3], m[4]) for m in G.OUTBOX.values()]
    G.OUTBOX = L.table_from([])
    return out
L.execute("""
ADDON_NS.Layer.Current = function() return "17" end
C_Map.GetBestMapForUnit = function() return 1413 end
C_Map.GetMapInfo = function(id) return { mapType = 3, parentMapID = 0 } end
ADDON_NS.db.settings.layerStrangers = false
""")
outbox()
G.FIRE("CHAT_MSG_ADDON", "LayerSwap", "<LS1413 not 22-5> inv layer", "WHISPER", "Stranger-ClassicBetaPvP")
o = [m for m in outbox() if m[0] == "LayerSwap"]
check("hosting off → answers o: " + str(o), any(str(m[1]).endswith("|o") for m in o))
G.FIRE("CHAT_MSG_ADDON", "LayerSwap", "<LS1413 not 22-5> inv layer", "WHISPER", "Stranger-ClassicBetaPvP")
check("one answer a minute", not [m for m in outbox() if m[0] == "LayerSwap"])
G.FIRE("CHAT_MSG_ADDON", "LayerSwap", "<LS1413 not 17-0> inv layer", "WHISPER", "Other-ClassicBetaPvP")
o = [m for m in outbox() if m[0] == "LayerSwap"]
check("they're on my layer → 'same': " + str(o), any(m[1] == "same" for m in o))
L.execute('ADDON_NS.db.settings.layerStrangers = true; GetBattlefieldStatus = function(i) return i == 1 and "queued" or "none" end; GetMaxBattlefieldID = function() return 2 end')
check("battleground queue pauses hosting", L.eval('ADDON_NS.LayerHop.PauseWhy()') == "queued for a battleground")
G.FIRE("CHAT_MSG_ADDON", "LayerSwap", "<LS1413 not 22-5> inv layer", "WHISPER", "Third-ClassicBetaPvP")
o = [m for m in outbox() if m[0] == "LayerSwap"]
check("busy → answers p: " + str(o), any(str(m[1]).endswith("|p") for m in o))
# channels: General rejoins at 6 while our hidden channel sits at 1 → they swap
L.execute("""
SWAPS = {}
C_ChatInfo.SwapChatChannelsByChannelIndex = function(a, b) SWAPS[#SWAPS + 1] = a .. "<>" .. b end
ADDON_NS.LayerHop.Nets.channels["voidzz"] = "voidnet"
GetChannelName = function(name) if name == "voidzz" then return 1, name end return 0 end
""")
G.FIRE("CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", "", "", "6. General", "", "", 0, 6, "General")
check("General gets slot 1 back: " + str(L.eval('SWAPS[1]')), L.eval('SWAPS[1]') == "1<>6")
G.FIRE("CHAT_MSG_CHANNEL_NOTICE", "YOU_JOINED", "", "", "1. voidzz", "", "", 0, 1, "voidzz")
check("our own channel joining doesn't swap", L.eval('#SWAPS') == 1)
errs = [e for e in G.ERRORS.values()]
check("no Lua errors " + str(errs[:2]), not errs)
print("PASS" if not fails else "FAILED %s" % fails)
if fails: raise SystemExit(1)
