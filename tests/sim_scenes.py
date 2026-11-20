# 1.4.0 the four scenarios: dungeon (boss x/y, hover list, deaths, wipes, boss lines, run card),
# raid mode, battleground (score, scoreboard, flags, revenge, victory card), questing (about to ding, gathering)
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(3)
def clean(s): return LA.eval('(function(x) return (tostring(x):gsub("|T.-|t", ""):gsub("|c%%x%%x%%x%%x%%x%%x%%x%%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")) end)(%s)' % s)
# boss data
print("BRD count:", LA.eval('select(2, ADDON_NS.Bosses:Count("Blackrock Depths", {}))'), "| Thanes alt name:", LA.eval('ADDON_NS.Bosses:Count("The Hall of Thanes", { Magmatus = 90 })'))
print("SM wing:", LA.eval('(function() local l, w = ADDON_NS.Bosses:For("Scarlet Monastery", { Herod = 60 }) return w .. " " .. #l end)()'))
print("unknown inst learned:", LA.eval('(function() ADDON_NS.Bosses:Learn("Blackmaw Hold", "Grukk") local n, t = ADDON_NS.Bosses:Count("Blackmaw Hold", {}) return n .. "/" .. tostring(t) end)()'))
# dungeon run
LA.execute('IN_INSTANCE = true; GetInstanceInfo = function() return "Wailing Caverns" end; FIRE("PLAYER_ENTERING_WORLD")'); run(6)
print("mode:", LA.eval('ADDON_NS.Pulse:Mode()'), "| boxes:", LA.eval('table.concat(ADDON_NS.Tiles:List(), ",")'))
LA.execute('FIRE("ENCOUNTER_START", 585, "Lady Anacondra", 1, 5)'); run(10)
LA.execute('FIRE("ENCOUNTER_END", 585, "Lady Anacondra", 1, 5, 1)'); run(10)
LA.execute('FIRE("ENCOUNTER_START", 586, "Lord Cobrahn", 1, 5)'); run(4)
LA.execute('FIRE("ENCOUNTER_END", 586, "Lord Cobrahn", 1, 5, 0)'); run(2)
LA.execute('UnitIsDeadOrGhost = function(u) return u == "player" end'); run(4)
LA.execute('UnitIsDeadOrGhost = function() return false end'); run(2)
LA.execute('FIRE("CHAT_MSG_LOOT", "You receive loot: |cffa335ee|Hitem:11684::::::::60:::::|h[Ironfoe]|h|r.")')
LA.execute('ADDON_NS.NowCard:Update(); ADDON_NS.Tiles:Update()')
print("tiles:", LA.eval('(function() local t = {} for _, x in ipairs(ADDON_NS.Tiles.tiles) do if x:IsShown() then t[#t+1] = tostring(x.v:GetText()) .. "/" .. tostring(x.k:GetText()) end end return table.concat(t, " | ") end)()'))
for i in range(1, 5):
    print("  now", i, clean('ADDON_NS.NowCard.frame.lines[%d]:GetText()' % i))
print("track blocks:", LA.eval('(function() local n = 0 for _, b in ipairs(ADDON_NS.NowCard.frame.track.blocks) do if b:IsShown() then n = n + 1 end end return n end)()'))
LA.execute('ADDON_NS.Tiles:BossList(ADDON_NS.Tiles.tiles[1])')
print("hover:", LA.eval('ADDON_NS.Tiles.bossFrame.title:GetText()'), "|", LA.eval('ADDON_NS.Tiles.bossFrame.rows[1].text:GetText()'), "struck:", LA.eval('ADDON_NS.Tiles.bossFrame.rows[1].line:IsShown()'), LA.eval('ADDON_NS.Tiles.bossFrame.rows[1].time:GetText()'), "| row2:", LA.eval('ADDON_NS.Tiles.bossFrame.rows[2].text:GetText()'))
print("B got boss line:", LB.eval('(function() for i = #ADDON_NS.db.feed, 1, -1 do local it = ADDON_NS.db.feed[i] if it.kind == "BOSS" then return it.b .. " " .. it.c .. " " .. it.d end end end)()'))
LB.execute('ADDON_NS.EventWindow:Redraw()'); run(2)
print("B line:", LB.eval('(function() for i = #ADDON_NS.EventWindow.entries, 1, -1 do local e = ADDON_NS.EventWindow.entries[i] if e.item and e.item.kind == "BOSS" then return (e.base:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")) end end end)()'))
# kill the rest -> run card
LA.execute('''for _, b in ipairs({ "Lord Cobrahn", "Kresh", "Lord Pythas", "Skum", "Lord Serpentis", "Verdan the Everliving", "Mutanus the Devourer" }) do
  FIRE("ENCOUNTER_START", 1, b, 1, 5); FIRE("ENCOUNTER_END", 1, b, 1, 5, 1) end'''); run(8)
LA.execute('ADDON_NS.NowCard:Update()')
print("card head:", LA.eval('ADDON_NS.NowCard.frame.head:GetText()'), "|", LA.eval('ADDON_NS.NowCard.frame.big:GetText()'), LA.eval('ADDON_NS.NowCard.frame.bigSub:GetText()'))
for i in range(1, 5):
    print("  card", i, clean('ADDON_NS.NowCard.frame.lines[%d]:GetText()' % i))
LA.execute('ADDON_NS.NowCard.moment = nil; IN_INSTANCE = false; FIRE("PLAYER_ENTERING_WORLD")'); run(4)
# raid
LA.execute('IsInInstance = function() return true, "raid" end; GetInstanceInfo = function() return "Molten Core" end; FIRE("PLAYER_ENTERING_WORLD")'); run(6)
LA.execute('FIRE("ENCOUNTER_START", 1, "Lucifron", 9, 40); FIRE("ENCOUNTER_END", 1, "Lucifron", 9, 40, 1)'); run(2)
LA.execute('FIRE("CHAT_MSG_LOOT", "' + "Grimtusk" + ' receives loot: |cffa335ee|Hitem:16800::::::::60:::::|h[Arcanist Boots]|h|r.")')
LA.execute('ADDON_NS.NowCard:Update(); ADDON_NS.Tiles:Update()')
print("raid mode:", LA.eval('ADDON_NS.Pulse:Mode()'), "| tiles:", LA.eval('(function() local t = {} for _, x in ipairs(ADDON_NS.Tiles.tiles) do if x:IsShown() then t[#t+1] = tostring(x.v:GetText()) .. "/" .. tostring(x.k:GetText()) end end return table.concat(t, " | ") end)()'))
for i in range(1, 5):
    print("  raid", i, clean('ADDON_NS.NowCard.frame.lines[%d]:GetText()' % i))
LA.execute('IsInInstance = function() return false, "none" end; FIRE("PLAYER_ENTERING_WORLD")'); run(4)
# battleground
LA.execute('''IsInInstance = function() return true, "pvp" end; GetInstanceInfo = function() return "Warsong Gulch" end
PVPHK = 10; GetPVPSessionStats = function() return PVPHK, 100 end
GetNumBattlefieldScores = function() return 3 end
GetBattlefieldScore = function(i) if i == 1 then return UnitName("player"), 4, 7, 2, 300 elseif i == 2 then return "Grimtusk", 2, 5, 1, 250 else return "Stabsalot", 1, 2, 5, 0 end end
C_UIWidgetManager = { GetTopCenterWidgetSetID = function() return 1 end, GetAllWidgetsBySetID = function() return { { widgetType = 0, widgetID = 1 }, { widgetType = 0, widgetID = 2 } } end,
  GetIconAndTextWidgetVisualizationInfo = function(id) return { text = id == 1 and "2/3" or "1/3" } end }
ADDON_NS.db.diedTo = ADDON_NS.db.diedTo or {}; ADDON_NS.db.diedTo["stabsalot"] = { name = "Stabsalot", n = 3, last = time() }
FIRE("PLAYER_ENTERING_WORLD")'''); run(6)
LA.execute('FIRE("UPDATE_BATTLEFIELD_SCORE"); FIRE("CHAT_MSG_BG_SYSTEM_HORDE", UnitName("player") .. " captured the Alliance flag!")')
LA.execute('FIRE("CHAT_MSG_COMBAT_HONOR_GAIN", "Stabsalot dies, honorable kill Rank: Private (Estimated Honor Points: 12)")'); run(4)
LA.execute('ADDON_NS.NowCard:Update(); ADDON_NS.Tiles:Update()')
print("bg tiles:", LA.eval('(function() local t = {} for _, x in ipairs(ADDON_NS.Tiles.tiles) do if x:IsShown() then t[#t+1] = tostring(x.v:GetText()) .. "/" .. tostring(x.k:GetText()) end end return table.concat(t, " | ") end)()'))
print("bg big:", LA.eval('ADDON_NS.NowCard.frame.big:GetText() .. " " .. ADDON_NS.NowCard.frame.bigSub:GetText()'))
for i in range(1, 4):
    print("  bg", i, clean('ADDON_NS.NowCard.frame.lines[%d]:GetText()' % i))
LA.execute('GetBattlefieldWinner = function() return 0 end; UnitFactionGroup = function() return "Horde" end; FIRE("UPDATE_BATTLEFIELD_STATUS")'); run(4)
LA.execute('ADDON_NS.NowCard:Update()')
print("bg card:", LA.eval('ADDON_NS.NowCard.frame.head:GetText()'), "|", clean('ADDON_NS.NowCard.frame.lines[1]:GetText()'), "|", clean('ADDON_NS.NowCard.frame.lines[2]:GetText()'), "|", clean('ADDON_NS.NowCard.frame.lines[3]:GetText()'))
run(6)
print("B bg lines:", LB.eval('(function() local out = {} for i = #ADDON_NS.db.feed, 1, -1 do local it = ADDON_NS.db.feed[i] if it.kind == "BGEND" or it.kind == "BGREV" or it.kind == "FLAG" then out[#out+1] = it.kind end end return table.concat(out, ",") end)()'))
LA.execute('ADDON_NS.NowCard.moment = nil; IsInInstance = function() return false, "none" end; FIRE("PLAYER_ENTERING_WORLD")'); run(4)
# questing: about to ding, gathering
LA.execute('UnitLevel = function() return 41 end; UnitXP = function() return 990 end; UnitXPMax = function() return 1000 end; FIRE("PLAYER_XP_UPDATE"); FIRE("PLAYER_XP_UPDATE")'); run(6)
print("B near ding:", LB.eval('(function() local n = 0 for _, it in ipairs(ADDON_NS.db.feed) do if it.kind == "NEARDING" then n = n + 1 end end return n end)()'))
LA.execute('C_Item = C_Item or {}; C_Item.GetItemInfoInstant = function(id) return id, "", "", "", "", 7, 9 end; FIRE("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:2447::::::::60:::::|h[Peacebloom]|hx3.")')
LA.execute('ADDON_NS.NowCard:Update()')
print("gather row:", clean('ADDON_NS.NowCard.frame.lines[2]:GetText()'))
# ding moment
LA.execute('ADDON_NS:Fire("LEVEL_RECAP", { from = 41, to = 42, time = 5400, quests = 12, money = 40000, deaths = 1, xph = 30000, rank = { place = 1, of = 3 } })')
print("ding card:", LA.eval('ADDON_NS.NowCard.frame.head:GetText()'), "|", LA.eval('ADDON_NS.NowCard.frame.big:GetText()'), "|", clean('ADDON_NS.NowCard.frame.lines[2]:GetText()'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5], [e for e in list(GB.ERRORS.values()) if 'HookScript' not in str(e)][:4])
# 1.4.3 groups: one run line on B, near-ding gone after the ding
run(4)
print("B run lines:", LB.eval('(function() local n, txt = 0, "" for _, e in ipairs(ADDON_NS.EventWindow.entries) do if e.gid and e.gid:find("^RUN") then n = n + 1 txt = e.base end end return n .. " | " .. (txt:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")) end)()'))
print("B bg lines:", LB.eval('(function() local n, txt = 0, "" for _, e in ipairs(ADDON_NS.EventWindow.entries) do if e.gid and e.gid:find("^BG") then n = n + 1 txt = e.base end end return n .. " | " .. (txt:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")) end)()'))
LA.execute('UnitLevel = function() return 42 end; ADDON_NS.Tracker:Event("DING", 42, 0)'); run(6)
print("B near ding after ding:", LB.eval('(function() local n = 0 for _, it in ipairs(ADDON_NS.db.feed) do if it.kind == "NEARDING" then n = n + 1 end end for _, e in ipairs(ADDON_NS.EventWindow.entries) do if e.item and e.item.kind == "NEARDING" then n = n + 1 end end return n end)()'))
print("home entries ok:", LB.eval('#ADDON_NS.FeedEntries(ADDON_NS.db.feed, 1)'))
print("FEIL2:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5], [e for e in list(GB.ERRORS.values()) if 'HookScript' not in str(e)][:4])
