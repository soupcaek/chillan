# 1.4.38 PvP page: games recorded per battleground, stats per range, gang numbers shared
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(3)
LA.execute('''REPV = 26595
C_Reputation = C_Reputation or {}
C_Reputation.GetFactionDataByID = function(id) if id == 729 then return { name = "Frostwolf Clan", currentStanding = REPV, reaction = 7, currentReactionThreshold = 21000, nextReactionThreshold = 42000 } end end
UnitFactionGroup = function() return "Horde", "Horde" end
GetInstanceInfo = function() return "Alterac Valley", "pvp", 0, "", 40, 0, false, 30 end
local P = ADDON_NS.Pulse
for i = 1, 5 do
  P:StartBG(); P.bg.start = ADDON_NS.Now() - 1500; P.bg.honorChat = 400 + i * 10; P.bg.won = (i ~= 3)
  REPV = REPV + (P.bg.won and 600 or 150)
  P:EndBG()
end''')
print("stats AV:", LA.eval('(function() local s = ADDON_NS.Pulse.PvPStats("all").AV return s.won .. "/" .. s.played .. " rate " .. s.rate .. " best " .. s.best .. " cur " .. s.cur .. " honorH " .. tostring(s.honorH) end)()'))
LA.execute('ADDON_NS.Window:Create(); ADDON_NS.Window.frame:Show(); ADDON_NS.Window:Select("pvp")'); run(1)
run(70)
print("B got:", LB.eval('(function() local p = ADDON_NS:GetPerson("' + LA.eval('ADDON_NS.pid') + '") local g = p and p.pvp and p.pvp.AV return g and (g.won .. "/" .. g.played .. " hk " .. g.hkPer .. " re " .. tostring(g.reaction) .. " wl " .. tostring(g.winsLeft)) or "nil" end)()'))
LB.execute('ADDON_NS.Window:Create(); ADDON_NS.Window.frame:Show(); ADDON_NS.Window:Select("pvp")'); run(1)
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5], [e for e in list(GB.ERRORS.values()) if 'HookScript' not in str(e)][:5])
# 1.4.39 Darkspear Islands: faction found by name, instance learned
LA.execute('''C_Reputation.GetNumFactions = function() return 2 end
C_Reputation.GetFactionDataByIndex = function(i) if i == 2 then return { name = "Darkspear Raiders", factionID = 2601 } end return { name = "Orgrimmar", factionID = 76 } end
local old = C_Reputation.GetFactionDataByID
C_Reputation.GetFactionDataByID = function(id) if id == 2601 then return { name = "Darkspear Raiders", currentStanding = DIV or 4000, reaction = 5, currentReactionThreshold = 3000, nextReactionThreshold = 9000 } end return old(id) end
GetInstanceInfo = function() return "Darkspear Islands", "pvp", 0, "", 15, 0, false, 9999 end
DIV = 4000
local P = ADDON_NS.Pulse
P:StartBG(); P.bg.start = ADDON_NS.Now() - 900; P.bg.won = true; DIV = 4300; P:EndBG()''')
print("DI:", LA.eval('(function() local s = ADDON_NS.Pulse.PvPStats("all").DI local r = ADDON_NS.Pulse.RepForKey("DI") return (s and (s.won .. "/" .. s.played) or "nil") .. " | " .. (r and (r.name .. " " .. r.standing .. " wins " .. tostring(r.winsLeft)) or "nil") .. " | learned " .. tostring(ADDON_NS.db.bgInstIds and ADDON_NS.db.bgInstIds[9999]) end)()'))
LA.execute('ADDON_NS.Window:Select("pvp")'); run(1)
print("FEIL2:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5])
# 1.4.47: a friend's full PvP page
LA.execute('ADDON_NS.Pulse.SharePvP()'); run(90)
print("B has A's page:", LB.eval('(function() local p = ADDON_NS:GetPerson("' + LA.eval('ADDON_NS.pid') + '") local f = p and p.pvpFull return f and f.all and f.all.AV and (f.all.AV.won .. "/" .. f.all.AV.played .. " best " .. f.all.AV.best .. " hpg " .. f.all.AV.honorPer) or "nil" end)()'))
LB.execute('ADDON_NS.Window:Select("pvp")'); run(1)
print("FEIL3:", [e for e in list(GB.ERRORS.values()) if 'HookScript' not in str(e)][:5])
