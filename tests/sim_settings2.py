# 1.4.64 Settings: side list of groups, search, switches, choice bars
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A
run(3)
LA.execute('ADDON_NS.Window:Create(); ADDON_NS.Window.frame:Show()')
r = LA.eval('(function() local t = ADDON_NS.Window.tabs.settings local ok, e = pcall(t.def.build, t) t.built = true return tostring(ok) .. " " .. tostring(e) end)()')
print("build:", r); assert r.startswith("true")
LA.execute('ADDON_NS.Window:Select("settings"); ADDON_NS.Window.tabs.settings:Refresh()')
# a switch flips its setting
LA.execute('ADDON_NS.db.settings.sounds = true; ADDON_NS.Window.tabs.settings:ShowGroup("notifications")')
# search: "sound" lights up Notifications
LA.execute('''local t = ADDON_NS.Window.tabs.settings
for _, c in ipairs({ t:GetChildren() }) do end''')
print("FEIL:", list(GA.ERRORS.values())[:4])
