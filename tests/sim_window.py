# 1.0 window: sections, pages built on first open, badges, resize bounds, edit mode
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A
run(3)
LA.execute('ADDON_NS.Window:Create(); ADDON_NS.Window.frame:Show()'); run(1)
print("opens on:", LA.eval('ADDON_NS.Window.current'))
print("built at open:", LA.eval('(function() local t = {} for k, v in pairs(ADDON_NS.Window.tabs) do if v.built then t[#t+1] = k end end table.sort(t) return table.concat(t, ",") end)()'))
for key in ["friends", "cunts", "more", "chat", "stats", "ach", "qol", "ideas", "settings", "changelog", "home"]:
    LA.execute('ADDON_NS.Window:Select("%s")' % key); run(0.5)
    print(key, "->", LA.eval('ADDON_NS.Window.current'), LA.eval('select(1, ADDON_NS.Window:SectionOf("%s"))' % key))
LA.execute('ADDON_NS.Window:OpenPlayer(ADDON_NS.pid)'); run(0.5)
print("player page in section:", LA.eval('select(1, ADDON_NS.Window:SectionOf(ADDON_NS.Window.current))'))
LA.execute('ADDON_NS.Window.secButtons.progress:GetScript("OnClick")()'); run(0.5)
print("Progress button remembers last page:", LA.eval('ADDON_NS.Window.current'))
LA.execute('ADDON_NS.UI.EditMode(true)'); run(0.5)
print("edit stands:", LA.eval('(function() local n = 0 for k in pairs(ADDON_NS.UI.movables) do n = n + 1 end return n end)()'))
LA.execute('ADDON_NS.UI.EditMode(false)')
print("FEIL:", [e for e in list(GA.ERRORS.values())][:6])
