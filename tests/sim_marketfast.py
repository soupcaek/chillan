# 1.4.26 faster market sharing: full scan shared on its own prefixes, and catch-up by full-scan mark
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(3)
print("channel usable A:", LA.eval('ADDON_NS.Comm:ChannelUsable()'))
# A "scans" 2000 prices
LA.execute('''local M = ADDON_NS.Market
local all = {}
for i = 1, 2000 do M:Set(10000 + i, 1000 + i, ADDON_NS.Now(), ADDON_NS.pid); all[#all+1] = 10000 + i end
ADDON_NS.db.marketFullT = ADDON_NS.Now()
ADDON_NS.Comm:Broadcast(ADDON_NS.Comm:Build("MS", 2000, 2000), 2)
M:Share(all)''')
for sec in (30, 60, 120):
    run(60 if sec == 30 else (60 if sec == 60 else 120))
    print("B has after ~%ds:" % sec, LB.eval('ADDON_NS.Market:Count()'), "fullT set:", LB.eval('(ADDON_NS.db.marketFullT or 0) > 0'))
# catch-up: B forgets, asks with its mark; also B has one fresh hovered price (old bug)
LB.execute("local C = ADDON_NS.Comm; local h = C.handlers.MZ; MHSEEN = 0; C.handlers.MZ = function(f, s) MHSEEN = MHSEEN + 1; MHF = tostring(f[1]) .. \"/\" .. tostring(f[2]) .. \" from \" .. tostring(s); local r = h(f, s); INC = ADDON_NS.Market.incoming[s]; return r end; local hp = C.handlers.MP; MPN = 0; C.handlers.MP = function(f, s) MPN = MPN + 1; MPS = tostring(s); return hp(f, s) end")
LB.execute('ADDON_NS.db.market = {}; ADDON_NS.db.marketFullT = 0; ADDON_NS.db.marketFullAt = 0; ADDON_NS.Market:Set(99, 5, ADDON_NS.Now(), "x")')
LA.execute('local o = C_ChatInfo.SendAddonMessage; SENTLOG = {}; C_ChatInfo.SendAddonMessage = function(p, m, c, t) if m:find("~MZ~") or m:find("~MQ~") then SENTLOG[#SENTLOG+1] = p .. " " .. c .. " " .. tostring(t) .. " " .. m end return o(p, m, c, t) end')
LB.execute('ADDON_NS.Comm:Broadcast(ADDON_NS.Comm:Build("MQ", ADDON_NS.Market:FullT()), 2)')
run(4); print("incoming:", LB.eval("(function() local o={} for k,v in pairs(ADDON_NS.Market.incoming) do o[#o+1]=k..\" \"..v.n..\" \"..v.got end return table.concat(o,\",\") end)()"))
run(150)
print("B after catch-up ~75s:", LB.eval('ADDON_NS.Market:Count()'), "fullT set:", LB.eval('(ADDON_NS.db.marketFullT or 0) > 0'))
print("inc:", LB.eval("(function() local o={} for k,v in pairs(ADDON_NS.Market.incoming) do o[#o+1]=k..\" \"..v.n..\" \"..v.got end return table.concat(o,\",\") end)()"), "fullT", LB.eval("tostring(ADDON_NS.db.marketFullT)"))
print("INC:", LB.eval("INC and (INC.n .. \" \" .. INC.got .. \" t=\" .. tostring(INC.t)) or \"nil\""))
print("MH:", LB.eval("MHSEEN"), LB.eval("tostring(MHF)"), "MP:", LB.eval("MPN"), LB.eval("tostring(MPS)"))
print("A sent:", LA.eval("table.concat(SENTLOG, \" | \")"))
print("price 10500 at B:", LB.eval('ADDON_NS.Market:Get(10500).v'), "by", LB.eval('ADDON_NS.Market:Get(10500).by'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5], [e for e in list(GB.ERRORS.values()) if 'HookScript' not in str(e)][:5])
