exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
setup = '''
strsplit = strsplit or function(sep, str) local t = {} for part in (str .. sep):gmatch("(.-)%" .. sep) do t[#t+1] = part end return unpack(t) end
CREATURES = {}
UnitExists = function(u) return CREATURES[u] ~= nil end
UnitGUID = function(u) return CREATURES[u] end
UnitPlayerControlled = function(u) return false end
INVITED = {}; C_PartyInfo = C_PartyInfo or {}; C_PartyInfo.InviteUnit = function(n) table.insert(INVITED, n) end
ACCEPTED = 0; AcceptGroup = function() ACCEPTED = ACCEPTED + 1 end
GROUP = false; IsInGroup = function() return GROUP end; GetNumGroupMembers = function() return GROUP and 2 or 0 end
LEFT = 0; C_PartyInfo.LeaveParty = function() LEFT = LEFT + 1; GROUP = false end
WHISPERS = {}
C_ChatInfo = C_ChatInfo or {}
local orig = C_ChatInfo.SendAddonMessage
C_ChatInfo.SendAddonMessage = function(p, m, k, t) if p == "LayerSwap" then table.insert(WHISPERS, t .. " :: " .. m) return 0 end if orig then return orig(p, m, k, t) end end
C_FriendList = { SendWho = function() WHO_SENT = true end, SetWhoToUi = function() end,
  GetNumWhoResults = function() return 2 end,
  GetWhoInfo = function(i) return ({ { fullName = "Random Dude" }, { fullName = "Other Guy" } })[i] end }
function SEE(layer)
  for i = 1, 4 do CREATURES["nameplate" .. i] = "Creature-0-" .. layer .. "-1-" .. (100 + i) .. "-3100-" .. math.random(1, 1e9) end
  for i = 1, 4 do ADDON_NS.Layer.Observe("nameplate" .. i) end
end
'''
LA.execute(setup); LB.execute(setup)
LA.execute('SEE(7001)'); LB.execute('SEE(6843)')
print("A layer:", nsA.Layer.Current(nsA.Layer), "B layer:", nsB.Layer.Current(nsB.Layer))
nsA.Tracker.SendStatus(nsA.Tracker); nsB.Tracker.SendStatus(nsB.Tracker); run(5)
pB = nsA.db.people[nsB.pid]
print("A sees B layer:", pB.live.layer, "zone:", pB.live.zone, "A zone:", nsA.Tracker.Me(nsA.Tracker).live.zone)
print("A minibar status:", LA.eval('ADDON_NS.Overlays and ADDON_NS.Overlays.minibar and ADDON_NS.Overlays.minibar.status and ADDON_NS.Overlays.minibar.status.text:GetText()'))
hosts = LA.eval('#ADDON_NS.LayerHop:GangHosts()'); print("gang hosts for A:", hosts)
LA.execute('ADDON_NS.LayerHop:Request()'); run(4)
print("B invited:", LB.eval('INVITED[1]'), "B popup:", LB.eval('ADDON_NS.LayerHop.frame and ADDON_NS.LayerHop.frame:IsShown()'))
GA.FIRE("PARTY_INVITE_REQUEST", nsB.Comm.MyFull(nsB.Comm))
LA.execute('GROUP = true')
print("A accepted:", LA.eval('ACCEPTED'))
GA.FIRE("SHARD_TRANSFER"); run(3)
LA.execute('SEE(6843)'); run(1)
print("A layer after move:", nsA.Layer.Current(nsA.Layer))
run(32)
print("A left group:", LA.eval('LEFT'), "mine cleared:", LA.eval('ADDON_NS.LayerHop.mine == nil'))
# same-layer: now both on 6843 -> B must not invite
LB.execute('INVITED = {}')
nsA.Tracker.SendStatus(nsA.Tracker); nsB.Tracker.SendStatus(nsB.Tracker); run(5)
LA.execute('ADDON_NS.LayerHop.mine = nil; ADDON_NS.LayerHop:Request()'); run(4)
print("same layer -> B invited:", LB.eval('#INVITED'), "LS who sent:", LA.eval('WHO_SENT'))
run(6)
print("A whispers:", LA.eval('table.concat(WHISPERS, " | ")'))
GA.FIRE("PARTY_INVITE_REQUEST", "Random Dude")
print("A accepted LS host:", LA.eval('ACCEPTED'))
# stranger hosting on B
LB.execute('INVITED = {}; WHISPERS = {}; ADDON_NS.db.settings.layerStrangers = true')
mapB = LB.eval('ADDON_NS.LayerHop.ZoneMap()')
print("B zone map:", mapB)
GB.FIRE("CHAT_MSG_ADDON", "LayerSwap", f"inv layer <LS {mapB} not 7001-55 50.0,50.0>", "WHISPER", "Stranger Guy"); run(3)
print("B invited stranger:", LB.eval('INVITED[1]'), "heard:", LB.eval('WHISPERS[1]'))
GB.FIRE("CHAT_MSG_ADDON", "LayerSwap", f"inv layer <LS {mapB} not 6843-55 50.0,50.0>", "WHISPER", "Same Layer"); run(3)
print("B invited same-layer stranger:", LB.eval('INVITED[2]'))
LB.execute('ADDON_NS.db.settings.layerStrangers = false')
GB.FIRE("CHAT_MSG_ADDON", "LayerSwap", f"inv layer <LS {mapB} not 7001-55 50.0,50.0>", "WHISPER", "Third One"); run(3)
print("B hosting off ->", LB.eval('INVITED[2]'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:4], [e for e in list(GB.ERRORS.values()) if 'HookScript' not in str(e)][:4])
