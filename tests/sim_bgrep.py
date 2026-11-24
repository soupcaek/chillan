# 1.4.34 battleground reputation: wins to Exalted in the AV box, Now card bar, recap, Watch
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(3)
LA.execute('''REPV = 26595
C_Reputation = C_Reputation or {}
C_Reputation.GetFactionDataByID = function(id) if id == 729 then return { name = "Frostwolf Clan", currentStanding = REPV, reaction = 7, currentReactionThreshold = 21000, nextReactionThreshold = 42000 } end end
UnitFactionGroup = function() return "Horde", "Horde" end
local gi = GetInstanceInfo
GetInstanceInfo = function() return "Alterac Valley", "pvp", 0, "", 40, 0, false, 30 end
ADDON_NS.db.bgRep = { [729] = { wN = 16, wSum = 16 * 562, lN = 3, lSum = 600 } }
IsInInstance = function() return true, "pvp" end
ADDON_NS.Pulse:StartBG()''')
LA.execute('REPV = REPV + 412')
print("box:", LA.eval('(function() local v, s = ADDON_NS.Tiles.byKey.bgrep.get() return tostring(v) .. " / " .. tostring(s) end)()'))
LA.execute('ADDON_NS.Pulse.mode = "bg"; ADDON_NS.NowCard:Update()')
print("now right:", LA.eval('ADDON_NS.NowCard.frame.right:GetText()'), "| pct:", LA.eval('tostring(ADDON_NS.NowCard.frame.meter.pct)'))
print("now rows:", LA.eval('(function() local o = {} for _, l in ipairs(ADDON_NS.NowCard.frame.lines) do if l:IsShown() then o[#o+1] = (l:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end end return table.concat(o, " // ") end)()'))
LA.execute('ADDON_NS.Pulse.bg.won = true; REPV = REPV + 150; ADDON_NS.Pulse:EndBG()')
print("stats:", LA.eval('ADDON_NS.db.bgRep[729].wN .. " wins, avg " .. math.floor(ADDON_NS.db.bgRep[729].wSum / ADDON_NS.db.bgRep[729].wN)'))
print("after BG box:", LA.eval('(function() local r = ADDON_NS.Pulse:BGRep() return r and (r.winsLeft .. " wins, last game " .. tostring(r.game)) or "nil" end)()'))
LA.execute('ADDON_NS.Comm:Broadcast(ADDON_NS.Tracker:BuildS3(), 3)'); run(70)
print("B sees:", LB.eval('(function() local p = ADDON_NS:GetPerson("' + LA.eval('ADDON_NS.pid') + '") local s = p and p.s3 or {} return tostring(s.bgRepS) .. " " .. tostring(s.bgWins) end)()'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5], [e for e in list(GB.ERRORS.values()) if 'HookScript' not in str(e)][:5])
# 1.4.36: summary falls back to own counts; honor from chat; won game counts in the average
LA.execute('''C_PvP = C_PvP or {}; C_PvP.GetScoreInfo = nil
ADDON_NS.db.bgRep = nil
REPV = 3000
ADDON_NS.Pulse:StartBG()
ADDON_NS.Pulse.bg.deaths = 2; ADDON_NS.Pulse.bg.best = 21
FIRE("CHAT_MSG_COMBAT_HONOR_GAIN", "Grunk dies, honorable kill Rank: Knight (Estimated Honor Points: 14)")
FIRE("CHAT_MSG_COMBAT_HONOR_GAIN", "You have been awarded 82 honor points.")
REPV = REPV + 697
ADDON_NS.Pulse.bg.won = true''')
print("summary:", LA.eval('(function() local x = ADDON_NS.Pulse:BGSummary(true) return "hk " .. x.me.hk .. " deaths " .. x.me.deaths .. " honor " .. tostring(x.honor) end)()'))
print("wins left with this game:", LA.eval('(function() local r = ADDON_NS.Pulse:BGRep() return r.winsLeft .. " (avg " .. r.avgW .. ", est " .. tostring(r.estimated) .. ")" end)()'))
# 1.4.43: a /reload (mode flicker) inside a battleground is the same game; played counts at the result only
LA.execute('''ADDON_NS.db.bgDay = nil; ADDON_NS.db.bgNow = nil
local P = ADDON_NS.Pulse
P.bg = nil
P:StartBG(); local first = P.bg; P.bg.deaths = 3
P:EndBG()          -- flicker / reload without result
P:StartBG()        -- back
SAME = (P.bg == first) and P.bg.deaths == 3''')
print("resumed same game:", LA.eval('SAME'), "| played before result:", LA.eval('ADDON_NS.Pulse.Today().played'))
