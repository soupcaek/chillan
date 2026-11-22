# 1.4.31 catch-up both ways: a friend with an older scan asks back when it hears a newer MQ;
# a stale ?price answer gets corrected by whoever has the fresher price
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(3)
LA.execute('''local M = ADDON_NS.Market
for i = 1, 300 do M:Set(40000 + i, 5000 + i, ADDON_NS.Now() - 2*86400, "Zvim") end
ADDON_NS.db.marketFullT = ADDON_NS.Now() - 2*86400''')
LB.execute('''local M = ADDON_NS.Market
for i = 1, 300 do M:Set(40000 + i, 9000 + i, ADDON_NS.Now() - 9*3600, ADDON_NS.pid) end
ADDON_NS.db.marketFullT = ADDON_NS.Now() - 9*3600''')
# B (newer) sends its periodic MQ; A should ask back and receive B's scan
LB.execute('ADDON_NS.Comm:Broadcast(ADDON_NS.Comm:Build("MQ", ADDON_NS.Market:FullT()), 3)')
run(60)
print("A price 40100 now:", LA.eval('ADDON_NS.Market:Get(40100).v'), "(B has 9100)")
# stale ?price from A gets corrected by B
LA.execute('for i = 1, 300 do ADDON_NS.Market:Set(40000 + i, 5000 + i, ADDON_NS.Now() + 0, "Zvim") end') if False else None
LA.execute('ADDON_NS.db.market[40200] = { v = 1, t = ADDON_NS.Now() - 2*86400, by = "Zvim" }; ADDON_NS.Market.NoteName(40200, "Arcane Crystal")')
LA.execute('ADDON_NS.Data:SendChat("?price arcane crystal")'); run(30)
print("A price 40200 after ?price:", LA.eval('ADDON_NS.Market:Get(40200).v'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5], [e for e in list(GB.ERRORS.values()) if 'HookScript' not in str(e)][:5])
# 1.4.32: only one line, already with the fresh price
LA.execute('ADDON_NS.db.market[40250] = { v = 1, t = ADDON_NS.Now() - 2*86400, by = "Zvim" }; ADDON_NS.Market.NoteName(40250, "Devilsaur Leather")')
n0 = int(LB.eval('#ADDON_NS.db.feed'))
LA.execute('ADDON_NS.Data:SendChat("?price devilsaur leather")'); run(40)
print("lines:", LB.eval('(function() local o = {} for i = %d + 1, #ADDON_NS.db.feed do local it = ADDON_NS.db.feed[i] if it.kind == "PRICE" then o[#o+1] = (it.c == "1" and "update " or "check ") .. tostring(it.d) end end return table.concat(o, " || ") end)()' % n0))
