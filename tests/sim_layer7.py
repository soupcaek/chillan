exec(open("sim_layer2.py").read().split("# same-layer")[0])
L = 'ADDON_NS.LayerHop'
# host pauses
print("pause normal:", LB.eval(L + '.PauseWhy()'))
LB.execute('C_LFGList = C_LFGList or {}; C_LFGList.HasActiveEntryInfo = function() return true end')
print("pause listed:", LB.eval(L + '.PauseWhy()'))
LB.execute('C_LFGList.HasActiveEntryInfo = function() return false end; GetEvictionTimeRemaining = function() return 45 end')
GB.FIRE("SHARD_TRANSFER_IMMINENT"); run(1)
print("pause refresh:", LB.eval(L + '.PauseWhy()'))
GB.FIRE("SHARD_TRANSFER"); run(1)
print("pause after transfer:", LB.eval(L + '.PauseWhy()'))
# search rounds: whole zone, then one class at a time
LA.execute('WHOARGS = {}; C_FriendList.SendWho = function(t, o, f) table.insert(WHOARGS, tostring(t) .. " cls=" .. tostring(f and f.classIDs and f.classIDs[1])) end')
for i in range(3):
    LA.execute(L + '.lastWhoAt = nil'); LA.execute('ADDON_NS.LayerHop:StartSearch()'); LA.execute('ADDON_NS.LayerHop:WhoResults("event")')
print("who rounds:", LA.eval('table.concat(WHOARGS, " | ")'))
# book: gone instead of deleted, skipped 10 min
LA.execute('ADDON_NS.db.lsBook = {}; ADDON_NS.LayerHop.Learn("Host Lady", "6900", ADDON_NS.LayerHop.ZoneMap(), true); ADDON_NS.LayerHop.sentTo["hostlady"] = GetTime()')
GA.FIRE("CHAT_MSG_SYSTEM", "No player named 'Host Lady' is currently playing.")
LA.execute('local f = ChatFrame_AddMessageEventFilter; ADDON_NS.LayerHop.NotPlaying("x")')
print("book kept:", LA.eval('ADDON_NS.db.lsBook["Host Lady"] ~= nil'), "| names now:", LA.eval('#ADDON_NS.LayerHop:BookNames({ map = ADDON_NS.LayerHop.ZoneMap() })'))
# same-layer guard: reply said our layer -> invite not accepted
LA.execute('''ACCEPTED = 0; AcceptGroup = function() ACCEPTED = ACCEPTED + 1 end
local m = { id = "x", t = ADDON_NS.Now(), from = "6843", mode = "ls", whispered = { samey = true }, replies = { ["Samey"] = { same = true, host = true, layer = "6843" } } }
ADDON_NS.LayerHop.mine = m''')
GA.FIRE("PARTY_INVITE_REQUEST", "Samey"); run(1)
print("same-layer invite accepted:", LA.eval('ACCEPTED'), "| avoided:", LA.eval('ADDON_NS.LayerHop.Avoided("Samey")'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) + list(GB.ERRORS.values()) if 'HookScript' not in str(e)][:5])
LA.execute('ADDON_NS.db.lsBook["Host Lady"].gone = time()')
print("gone host skipped:", LA.eval('#ADDON_NS.LayerHop:BookNames({ map = ADDON_NS.LayerHop.ZoneMap() })') == 0)
LA.execute('ADDON_NS.db.lsBook["Host Lady"].gone = time() - 700')
print("back after 10 min:", LA.eval('#ADDON_NS.LayerHop:BookNames({ map = ADDON_NS.LayerHop.ZoneMap() })') == 1)
LA.execute('ADDON_NS.db.lsBook["Host Lady"].layerAt = time() - 4000; ADDON_NS.db.lsBook["Host Lady"].layer = "6843"')
print("stale layer not used to exclude:", LA.eval('#ADDON_NS.LayerHop:BookNames({ map = ADDON_NS.LayerHop.ZoneMap(), from = "6843" })') == 1)
