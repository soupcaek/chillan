exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(4)
# A adds a ninja looter
LA.execute('ADDON_NS.Cunts:Add("Ninja Bob", "ninja looted the Whitemane boots")'); run(5)
print("B has entry:", LB.eval('ADDON_NS.Cunts:Get("Ninja Bob") and ADDON_NS.Cunts:Get("Ninja Bob").reason'))
print("B feed line:", LB.eval('(function() for i = #ADDON_NS.db.feed, 1, -1 do local it = ADDON_NS.db.feed[i] if it.kind == "CUNT" then return ADDON_NS.FeedShort(it) end end end)()'))
# B adds a note (via adding again)
LB.execute('ADDON_NS.Cunts:Add("ninja bob", "did it again in SM")'); run(4)
print("A notes:", LA.eval('#ADDON_NS.Cunts:Get("Ninja Bob").notes'))
# B can't remove, A can
LB.execute('ADDON_NS.Cunts:Remove("ninja bob")'); run(3)
print("after B tries remove, A still has:", LA.eval('ADDON_NS.Cunts:Get("Ninja Bob") ~= nil'))
# warnings on B: invite, target, whisper filter
LB.execute('TOASTS = {}; ADDON_NS:Listen("TOAST", function(t) table.insert(TOASTS, t.title) end)')
GB.FIRE("PARTY_INVITE_REQUEST", "Ninja Bob"); run(1)
LB.execute('UnitIsPlayer = function(u) return u == "target" end; local un = UnitName; UnitName = function(u) if u == "target" then return "Ninja Bob" end return un(u) end')
GB.FIRE("PLAYER_TARGET_CHANGED"); run(1)
print("B toasts:", LB.eval('table.concat(TOASTS, " | ")'))
# late joiner: C gets the list on login via HI
exec_c = 'C' in dir()
# removal by A reaches B, and a re-sync does not bring it back
LA.execute('ADDON_NS.Cunts:Remove("ninja bob")'); run(4)
print("B after A removes:", LB.eval('ADDON_NS.Cunts:Get("Ninja Bob") == nil'))
LA.execute('ADDON_NS.Cunts:SyncTo(ADDON_NS.Comm:MyFull())'); run(3)
print("discord outbox has CUNT + UNCUNT:", LA.eval('(function() local k = {} for _, e in ipairs(ADDON_NS.db.discord and ADDON_NS.db.discord.out or {}) do k[#k+1] = e.k end return table.concat(k, ",") end)()'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:4], [e for e in list(GB.ERRORS.values()) if 'HookScript' not in str(e)][:4])
LA.execute('ADDON_NS.Cunts:Add("Greedy Gus", "rolled need on everything")'); run(3)
print("discord card:", LA.eval('(function() for i = #ADDON_NS.db.feed, 1, -1 do local it = ADDON_NS.db.feed[i] if it.kind == "CUNT" then local e = ADDON_NS.Discord:FromItem(it) return e and (e.k .. " " .. e.vi .. " / " .. e.rs) end end end)()'))
LA.execute('ADDON_NS.Window:Create(); ADDON_NS.Window.frame:Show(); ADDON_NS.Window:Select("cunts")'); run(1)
print("page rows:", LA.eval('ADDON_NS.Window.tabs.cunts and #ADDON_NS.Cunts:List()'))
print("FEIL2:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:4])
