# 1.1.0 Gang pulse: modes, the four boxes, the Now card, merged bursts in the feed, the Progress chart
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(3)
print("mode:", LA.eval('ADDON_NS.Pulse:Mode()'), "| boxes:", LA.eval('table.concat(ADDON_NS.Tiles:List(), ",")'))
print("now card shown:", LA.eval('ADDON_NS.NowCard.frame ~= nil and ADDON_NS.NowCard.frame:IsShown()'))
LA.execute('ADDON_NS.NowCard:Update()')
print("world rows:", LA.eval('ADDON_NS.NowCard.frame.lines[1]:GetText()'))
print("tile values:", LA.eval('(function() local t = {} for _, x in ipairs(ADDON_NS.Tiles.tiles) do if x:IsShown() then t[#t+1] = tostring(x.v:GetText()) .. "/" .. tostring(x.k:GetText()) end end return table.concat(t, " | ") end)()'))
# dungeon
LA.execute('IN_INSTANCE = true; FIRE("PLAYER_ENTERING_WORLD")'); run(4)
print("mode:", LA.eval('ADDON_NS.Pulse:Mode()'), "| boxes:", LA.eval('table.concat(ADDON_NS.Tiles:List(), ",")'), "| chip:", LA.eval('ADDON_NS.Overlays.minibar.status.text:GetText()'))
LA.execute('FIRE("CHAT_MSG_LOOT", "You receive loot: |cffa335ee|Hitem:11684::::::::60:::::|h[Ironfoe]|h|r.")')
LA.execute('FIRE("CHAT_MSG_LOOT", "You receive loot: |cff9d9d9d|Hitem:2934::::::::60:::::|h[Ruined Leather Scraps]|h|r.")')
LA.execute("local m0 = GetMoney(); GetMoney = function() return m0 + 4120 end; FIRE(\"PLAYER_MONEY\")")
LA.execute('ADDON_NS.NowCard:Update()')
print("dungeon loot row:", LA.eval('ADDON_NS.NowCard.frame.lines[1]:GetText()'))
print("ready check button:", LA.eval('ADDON_NS.NowCard.frame.btn:IsShown()'))
# combat folds the boxes and the card, the pin keeps them
LA.execute('ADDON_NS.db.settings.pulsePin = false; FIRE("PLAYER_REGEN_DISABLED")'); run(1)
print("in combat: boxes", LA.eval('ADDON_NS.Tiles.holder:IsShown()'), "card", LA.eval('ADDON_NS.NowCard.frame:IsShown()'))
LA.execute('ADDON_NS.db.settings.pulsePin = true; ADDON_NS.NowCard:Relayout()'); run(1)
print("pinned in combat: boxes", LA.eval('ADDON_NS.Tiles.holder:IsShown()'))
LA.execute('ADDON_NS.db.settings.pulsePin = false; FIRE("PLAYER_REGEN_ENABLED")'); run(1)
LA.execute('IN_INSTANCE = false; FIRE("PLAYER_ENTERING_WORLD")'); run(4)
print("back:", LA.eval('ADDON_NS.Pulse:Mode()'))
# battleground
LA.execute('IsInInstance = function() return true, "pvp" end; GetInstanceInfo = function() return "Warsong Gulch" end; PVPHK = 10; GetPVPSessionStats = function() return PVPHK, 100 end; FIRE("PLAYER_ENTERING_WORLD")'); run(4)
LA.execute('PVPHK = 13'); run(4)
LA.execute('GetBattlefieldWinner = function() return 0 end; UnitFactionGroup = function() return "Horde" end; FIRE("UPDATE_BATTLEFIELD_STATUS")'); run(1)
LA.execute('ADDON_NS.NowCard:Update(); ADDON_NS.Tiles:Update()')
print("bg:", LA.eval('ADDON_NS.Pulse:Mode()'), "| big:", LA.eval('ADDON_NS.NowCard.frame.big:GetText() .. " " .. ADDON_NS.NowCard.frame.bigSub:GetText()'), "| won:", LA.eval('ADDON_NS.Pulse.Today().won .. "/" .. ADDON_NS.Pulse.Today().played'), "| streak:", LA.eval('ADDON_NS.Pulse.bg.streak'))
LA.execute('IsInInstance = function() return false, "none" end; FIRE("PLAYER_ENTERING_WORLD")'); run(4)
# the ⋯ menu opens without errors
LA.execute('ADDON_NS.Overlays:PulseMenu(ADDON_NS.Overlays.minibar.more)')
# bursts: A dies 3 times quickly -> one line at B
for i in range(3):
    LA.execute('ADDON_NS.Tracker:Event("DEAD", "Arathi Highlands", "PLAYER:1", "Stabsalot", "")'); run(20)
LB.execute('ADDON_NS.Tracker:Event("DING", 30, 1000)'); run(4)
print("B feed last lines:")
for i in range(3, 0, -1):
    t = LB.eval('(function() local e = ADDON_NS.EventWindow.entries[#ADDON_NS.EventWindow.entries - %d] return e and e.base and e.base:gsub("|T.-|t", ""):gsub("|c%%x%%x%%x%%x%%x%%x%%x%%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "") end)()' % (i - 1))
    print("  ", t)
# feed rows: tiles and reaction pills at B
LB.execute('local e = ADDON_NS.EventWindow.entries[#ADDON_NS.EventWindow.entries]; e.item.reacts = { { pid = "x1", char = "Bob-R", idx = 1 }, { pid = "x2", char = "Rob-R", idx = 1 }, { pid = "x3", char = "Tob-R", idx = 2 } }; ADDON_NS.EventWindow:Redraw()'); run(2)
print("rows:", LB.eval('(function() local fr = ADDON_NS.EventWindow.msg local n, t, p = 0, 0, 0 for _, r in ipairs(fr.rows) do if r:IsShown() then n = n + 1 if r.tile:IsShown() then t = t + 1 end for _, x in ipairs(r.pills) do if x:IsShown() then p = p + 1 end end end end return n .. " rows, " .. t .. " icons, " .. p .. " pills" end)()'))
# Progress chart: a character remade at level 1 must not draw a line going down
LA.execute('''local p = ADDON_NS:GetPerson(ADDON_NS.pid, true)
local c = ADDON_NS.Tracker:MyChar()
c.hist = { { t = time() - 900000, l = 10 }, { t = time() - 800000, l = 20 }, { t = time() - 700000, l = 30 }, { t = time() - 600000, l = 1 } }''')
LA.execute('ADDON_NS.Window:Create(); ADDON_NS.Window.frame:Show(); ADDON_NS.Window:Select("stats"); local st = ADDON_NS.Window.tabs.stats; if st.SetPage then st:SetPage("graph") end; st:Refresh()'); run(1)
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5], [e for e in list(GB.ERRORS.values()) if 'HookScript' not in str(e)][:4])
