# 1.2.2 Watching: pin a friend, they show under the Now card with level, zone and a bar; flash, unpin
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(4)
print("strip shown, empty:", LA.eval('ADDON_NS.Watch.frame and ADDON_NS.Watch.frame:IsShown()'), LA.eval('ADDON_NS.Watch.frame.add:IsShown()'))
LA.execute('ADDON_NS.Watch:Toggle("%s")' % nsB.pid); run(2)
LA.execute('ADDON_NS.Watch:Update()')
r = 'ADDON_NS.Watch.frame.rows[1]'
print("row:", LA.eval(r + '.name:GetText()'), "|", LA.eval(r + '.where:GetText()'), "| bar shown", LA.eval(r + '.fill:IsShown()'))
# B dies: the row says dead and flashes
LB.execute('ADDON_NS.Tracker:Event("DEAD", "Stranglethorn Vale", "MOB:1", "Raptor", "")'); run(4)
LA.execute('ADDON_NS.Watch:Update()')
print("after B died:", LA.eval(r + '.where:GetText()'))
# the menu and the Friends eye open without errors; shift-click a name toggles
LA.execute('ADDON_NS.Watch:Menu(ADDON_NS.Watch.frame.more)')
LA.execute('ADDON_NS.Window:Create(); ADDON_NS.Window.frame:Show(); ADDON_NS.Window:Select("friends"); ADDON_NS.Window.tabs.friends:Refresh()'); run(2)
LA.execute('IsShiftKeyDown = function() return true end; ADDON_NS.PersonCard:OnLinkClick("chillan:%s"); IsShiftKeyDown = function() return false end' % nsB.pid)
print("unwatched by shift-click:", LA.eval('not ADDON_NS.Watch:Has("%s")' % nsB.pid))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5])
