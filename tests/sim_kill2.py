exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
def kills(L): return L.eval('(function() local n = 0 for _, it in ipairs(ADDON_NS.db.feed) do if it.kind == "KILL" then n = n + 1 end end return n end)()')
def lastc(L): return L.eval('(function() for i = #ADDON_NS.db.feed, 1, -1 do local it = ADDON_NS.db.feed[i] if it.kind == "KILL" then return tostring(it.c) end end end)()')
LA.execute('''TGT = nil
UnitIsPlayer = function(u) return u == "target" and TGT ~= nil end
UnitCanAttack = function(a, u) return u == "target" and TGT ~= nil end
UnitIsDead = function(u) return u == "target" and TGT and TGT.dead end
local un = UnitName; UnitName = function(u) if u == "target" and TGT then return TGT.name end return un(u) end
HK = 0; GetPVPSessionStats = function() return HK, 0 end
issecretvalue = function(v) return v == "SECRET" end''')
run(4)
# 1) honour line hidden by the game, kill counter event, dead enemy targeted
k0 = kills(LA)
LA.execute('TGT = { name = "Stabby", dead = true }')
GA.FIRE("CHAT_MSG_COMBAT_HONOR_GAIN", "SECRET"); GA.FIRE("PLAYER_PVP_KILLS_CHANGED"); LA.execute('HK = 1'); run(6)
print("hidden line + counter -> posted:", kills(LA) - k0, "victim:", lastc(LA))
# 2) honour line readable + counter + session -> one post
k0 = kills(LA)
GA.FIRE("CHAT_MSG_COMBAT_HONOR_GAIN", "Grimbo dies, honorable kill Rank: Private (Estimated Honor Points: 12)"); GA.FIRE("PLAYER_PVP_KILLS_CHANGED"); LA.execute('HK = 2'); run(8)
print("readable line + counter + session -> posted:", kills(LA) - k0, "victim:", lastc(LA))
# 3) only the session count changes, no target
k0 = kills(LA)
LA.execute('TGT = nil'); run(25); LA.execute('HK = 3'); run(6)
print("session count only -> posted:", kills(LA) - k0, "victim:", repr(lastc(LA)))
print("B feed has kills:", kills(LB))
LA.execute('ADDON_NS.Kills:Report()')
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:4])
# 4) two named kills back to back + count +2 -> two posts
k0 = kills(LA); run(15)
GA.FIRE("CHAT_MSG_COMBAT_HONOR_GAIN", "Aaa dies, honorable kill Rank: Private (Estimated Honor Points: 12)")
GA.FIRE("CHAT_MSG_COMBAT_HONOR_GAIN", "Bbb dies, honorable kill Rank: Private (Estimated Honor Points: 12)")
LA.execute('HK = 5'); run(8)
print("two named + count+2 -> posted:", kills(LA) - k0)
# 5) count +2, no lines -> two posts
k0 = kills(LA); run(15)
LA.execute('HK = 7'); run(8)
print("count+2 only -> posted:", kills(LA) - k0)
print("FEIL3:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:4])
