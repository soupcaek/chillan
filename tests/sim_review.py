# 1.1.7 review fixes: every page opens, duplicate people hidden, Died to skips pets, Progress pages
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(4)
# a second install of B's player with the same name, level 1, muted
LA.execute('''local b
for pid, p in pairs(ADDON_NS.db.people) do if pid ~= ADDON_NS.pid then b = p end end
b.alias = "Kenny"
ADDON_NS.db.people["dupe0001"] = { main = "Kennyalt-R", alias = "Kenny", chars = { ["Kennyalt-R"] = { name = "Kennyalt", level = 1, class = "HUNTER" } }, lastSeen = time() - 70000 }
ADDON_NS.db.muted = { dupe0001 = true }''')
print("people shown:", LA.eval('#ADDON_NS:SortedPeople()'), "| hidden:", LA.eval('(function() local n = 0 for k in pairs(ADDON_NS:HiddenDuplicates()) do n = n + 1 end return n end)()'))
LA.execute('ADDON_NS.DiedTo:Record("x1", ADDON_NS.pid, "Hagrid (pet)", "Silverpine Forest", time(), "someone\'s pet")')
LA.execute('ADDON_NS.DiedTo:Record("x2", ADDON_NS.pid, "Vancy Lina", "Maraudon, Maraudon", time(), "Human rogue")')
print("died to pet:", LA.eval('ADDON_NS.db.diedTo["hagrid (pet)"] == nil'), "| zone:", LA.eval('ADDON_NS.db.diedTo["vancy lina"].zone'))
LA.execute('ADDON_NS.Window:Create(); ADDON_NS.Window.frame:Show()')
for k in ["home", "friends", "cunts", "diedto", "more", "chat", "stats", "graph", "titles", "ach", "history", "legend", "qol", "ideas", "settings", "changelog"]:
    LA.execute('ADDON_NS.Window:Select("%s")' % k); run(2)
print("Progress pills:", LA.eval('(function() local t = {} for _, k in ipairs(ADDON_NS.Window.SECTIONS[4].pages) do t[#t+1] = ADDON_NS.Window.PAGE_LABELS[k] end return table.concat(t, ", ") end)()'))
LA.execute('ADDON_NS.Window:Select("graph")'); run(2)
print("chart: side cards shown =", LA.eval('ADDON_NS.Window.tabs.stats.rightCol:IsShown()'))
LA.execute('ADDON_NS.Window:Select("stats")'); run(2)
print("overview: side cards shown =", LA.eval('ADDON_NS.Window.tabs.stats.rightCol:IsShown()'))
print("all chars of Kenny:", LA.eval('(function() for pid, p in pairs(ADDON_NS.db.people) do if p.alias == "Kenny" and not ADDON_NS:HiddenDuplicates()[pid] then local t = {} for _, x in ipairs(ADDON_NS:AllChars(p)) do t[#t+1] = x.ch.name end return table.concat(t, ", ") end end end)()'))
LA.execute('for pid, p in pairs(ADDON_NS.db.people) do if p.alias == "Kenny" and not ADDON_NS:HiddenDuplicates()[pid] then ADDON_NS.Window:OpenPlayer(pid) end end'); run(2)
# quick cards: Friends (joined below the row) and Home (beside the card), with characters
LA.execute('ADDON_NS.Window:Select("friends"); ADDON_NS.Window.tabs.friends:Refresh()'); run(2)
LA.execute("""local t = ADDON_NS.Window.tabs.friends
for pid, p in pairs(ADDON_NS.db.people) do if p.alias == "Kenny" and not ADDON_NS:HiddenDuplicates()[pid] then p.pid = pid t:ToggleQuick(CreateFrame("Button"), p) end end""")
LA.execute('ADDON_NS.Window:Select("home"); ADDON_NS.Window.tabs.home:Refresh()'); run(2)
print("chars live:", LA.eval('(function() for pid, p in pairs(ADDON_NS.db.people) do if p.alias == "Kenny" and not ADDON_NS:HiddenDuplicates()[pid] then p.pid = pid local t = {} for _, x in ipairs(ADDON_NS.PersonCharsLive(p)) do t[#t+1] = x.ch.name .. (x.online and "*" or "") end return table.concat(t, ", ") end end end)()'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:6])
