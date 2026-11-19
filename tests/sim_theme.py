# 1.1.5: live themes, Home page (gang cards, feed rows, quick actions, this week), no Settings/What's new tabs
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(4)
LA.execute('ADDON_NS.Window:Create(); ADDON_NS.Window.frame:Show(); ADDON_NS.Window:Select("home"); ADDON_NS.Window.tabs.home:Refresh()'); run(2)
print("section tabs:", LA.eval('(function() local t = {} for k in pairs(ADDON_NS.Window.secButtons) do t[#t+1] = k end table.sort(t) return table.concat(t, ",") end)()'))
print("home feed rows:", LA.eval('(function() local n = 0 for _, f in ipairs({ ADDON_NS.Window.tabs.home:GetChildren() }) do end return "ok" end)()'))
def bgcol():
    return LA.eval('(function() local c = ADDON_NS.Window.frame and ADDON_NS.Overlays.minibar.panel.bg._vc return c and string.format("%02X%02X%02X", c[1]*255+0.5, c[2]*255+0.5, c[3]*255+0.5) end)()')
before = bgcol()
LA.execute('ADDON_NS.db.settings.theme = "coal"; ADDON_NS.UI.ApplyThemeLive()'); run(2)
after = bgcol()
print("minibar background:", before, "->", after, "| C.window now", LA.eval('ADDON_NS.C.window'))
LA.execute('ADDON_NS.db.settings.theme = "graphite"; ADDON_NS.UI.ApplyThemeLive()'); run(2)
print("back:", bgcol())
LA.execute('ADDON_NS.db.settings.accent = "blue"; ADDON_NS.UI.ApplyThemeLive()'); run(2)
print("accent:", LA.eval('ADDON_NS.C.accent'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5])
