# 1.4.28 recap pills and cards: logout, login, dungeon, battleground; ignored -> feed line
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(3)
R = 'ADDON_NS.Recap'
LA.execute('CANCELLED = 0; CancelLogout = function() CANCELLED = CANCELLED + 1 end; ADDON_NS.db.sessRec = { online = 7200 }')
LA.execute('FIRE("PLAYER_CAMPING")'); run(2)
print("logout pill:", LA.eval('ChillanRecapPill and ChillanRecapPill:IsShown() and ChillanRecapPill.text:GetText()'))
LA.execute(R + ':OpenFromPill()'); run(3)
print("card:", LA.eval('ChillanRecapCard:IsShown()'), LA.eval('ChillanRecapCard.title:GetText()'), "| cancelled logout:", LA.eval('CANCELLED'))
print("cells:", LA.eval('(function() local o = {} for _, c in ipairs(ChillanRecapCard.cells) do o[#o+1] = c.v:GetText() .. " " .. c.k:GetText() end return table.concat(o, " | ") end)()'))
print("compare:", LA.eval('ChillanRecapCard.cmpText:GetText()'))
LA.execute(R + ':CloseCard()'); run(2)
# dungeon
LA.execute('ADDON_NS:Fire("RUN_CARD", { name = "Blackrock Depths", dur = 3480, bosses = 16, total = 19, deaths = 3, wipes = 1, xp = 0, value = 410000, fast = "Golem Lord Argelmach", fastSecs = 42, floor = "Kenny", floorN = 2, best = 3840, record = true })'); run(2)
print("dungeon pill:", LA.eval('ChillanRecapPill:IsShown() and ChillanRecapPill.text:GetText()'), "point:", LA.eval('select(1, ChillanRecapPill:GetPoint(1))'))
run(46)  # ignored for 20 s
print("pill gone:", not LA.eval('ChillanRecapPill:IsShown()'))
print("feed line:", LA.eval('(function() for i = #ADDON_NS.EventWindow.entries, 1, -1 do local e = ADDON_NS.EventWindow.entries[i] if e.base and e.base:find("chillanrecap") then return (e.base:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end end return "none" end)()'))
LA.execute('ADDON_NS.EventWindow.msg.onLinkClick(nil, "chillanrecap:2", "[Show]", "LeftButton")'); run(3)
print("opened from feed:", LA.eval('ChillanRecapCard:IsShown() and ChillanRecapCard.title:GetText()'))
LA.execute(R + ':CloseCard()'); run(2)
# battleground
LA.execute('ADDON_NS:Fire("BG_CARD", { name = "Warsong Gulch", won = true, score = "3-1", dur = 1080, honor = 410, best = 5, me = { hk = 12, deaths = 2, kb = 4 }, gang = {}, revs = {}, streak = 2 })'); run(4)
LA.execute(R + ':OpenFromPill()'); run(3)
print("bg card:", LA.eval('ChillanRecapCard.title:GetText()'), "|", LA.eval('ChillanRecapCard.moms[1].text:GetText()'))
LA.execute(R + ':Share()'); run(2)
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5])
