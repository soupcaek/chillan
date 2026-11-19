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
# 1.2.1: the host already had another hopper (group of 3), the first leave is ignored by the game,
# and a fight starts right when the hop is done – the hop group is still left
LA.execute("""GROUP = true; GROUPN = 3; GetNumGroupMembers = function() return GROUP and GROUPN or 0 end
IGNORE = 1; C_PartyInfo.LeaveParty = function() LEFT = LEFT + 1 if IGNORE > 0 then IGNORE = IGNORE - 1 return end GROUP = false end
COMBAT = false; InCombatLockdown = function() return COMBAT end; UnitAffectingCombat = function() return COMBAT end""")
GA.FIRE("SHARD_TRANSFER"); run(3)
LA.execute('SEE(6843)')
LA.execute('COMBAT = true'); run(8)
print("in combat, still grouped:", LA.eval('GROUP'))
LA.execute('COMBAT = false'); run(8)
print("after combat: grouped", LA.eval('GROUP'), "| leave calls", LA.eval('LEFT'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:4])
