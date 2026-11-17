exec(open("sim_layer2.py").read().split("# same-layer")[0])
# --- the game blocks Chillan's /who: fall back to known LayerSwap users
addon = LA.eval('select(1, ...)') if False else "Chillan"
def blocked(*a):
    GA.FIRE("ADDON_ACTION_BLOCKED", addon, "UNKNOWN()")
LA.globals().C_FriendList.SendWho = blocked
LA.execute('WHISPERS = {}; ADDON_NS.LayerHop.mine = nil; ADDON_NS.db.lsBook = {}; ADDON_NS.db.whoBlockedAt = nil')
mapA = LA.eval('ADDON_NS.LayerHop.ZoneMap()')
# a LayerSwap user nearby asks for a hop (whispers us) and a host answers someone
GA.FIRE("CHAT_MSG_ADDON", "LayerSwap", f"inv layer <LS {mapA} not 7100-3 50.0,50.0>", "WHISPER", "Asker Guy"); run(1)
GA.FIRE("CHAT_MSG_ADDON", "LayerSwap", f"heard Someone|6900-4|{mapA}|h", "WHISPER", "Host Lady"); run(1)
print("book:", LA.eval('(function() local t = {} for k, e in pairs(ADDON_NS.db.lsBook) do t[#t+1] = k .. "=" .. tostring(e.layer) .. (e.host and "h" or "") end table.sort(t) return table.concat(t, ",") end)()'))
# make B (gang) not a host: same layer as A now
LA.execute('ADDON_NS.LayerHop:Request()'); run(4)
print("blocked flag:", LA.eval('ADDON_NS.db.whoBlockedAt ~= nil'), "status:", LA.eval('ADDON_NS.LayerHop.lastWho and ADDON_NS.LayerHop.lastWho.err'))
print("whispers:", LA.eval('table.concat(WHISPERS, " | ")'))
# second request later: no SendWho at all
LA.execute('WHISPERS = {}; ADDON_NS.LayerHop.mine = nil'); LA.globals().C_FriendList.SendWho = lambda *a: print("!! SendWho called again")
LA.execute('ADDON_NS.LayerHop:Request()'); run(4)
print("whispers 2:", LA.eval('table.concat(WHISPERS, " | ")'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:4])
