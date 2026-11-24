# 1.4.50 battleground panel: bases and timers from the map, score race, carriers
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(3)
LA.execute('''
UnitFactionGroup = function() return "Horde", "Horde" end
IsInInstance = function() return true, "pvp" end
GetInstanceInfo = function() return "Arathi Basin", "pvp", 0, "", 15, 0, false, 529 end
C_Map = C_Map or {}; C_Map.GetBestMapForUnit = function() return 1461 end
POIS = { {"Stables", 40}, {"Blacksmith", 30}, {"Lumber Mill", 23}, {"Gold Mine", 18}, {"Farm", 35} }
C_AreaPoiInfo = { GetAreaPOIForMap = function() local t = {} for i = 1, #POIS do t[i] = i end return t end,
  GetAreaPOIInfo = function(_, id) local p = POIS[id] return { name = p[1], textureIndex = p[2] } end }
SCORE = { a = 980, h = 1240 }
C_UIWidgetManager = C_UIWidgetManager or {}
C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo = function(id)
  if id == 1893 then return { text = "Bases: 2  Resources: " .. SCORE.a .. "/2000" } end
  if id == 1894 then return { text = "Bases: 3  Resources: " .. SCORE.h .. "/2000" } end
end
ADDON_NS.BGObj:Update()
''')
print("key:", LA.eval('tostring(ADDON_NS.BGObj.key)'))
chips = LA.eval('(function() local o = {} for _, n in ipairs(ADDON_NS.BGObj:Chips()) do o[#o+1] = ADDON_NS.BGObj.Short(n.name) .. "=" .. tostring(n.side or ("atk:" .. tostring(n.atk))) end return table.concat(o, " ") end)()')
print("chips:", chips)
assert chips == "ST=h BS=h LM=a GM=a Farm=h", chips
# the Horde assaults the Lumber Mill: 60 s countdown
LA.execute('POIS[3][2] = 24; ADDON_NS.BGObj:Update(); GT = GT + 19')
left = LA.eval('ADDON_NS.BGObj:Left(ADDON_NS.BGObj.nodes["Lumber Mill"])')
print("lumber mill falls in:", left)
assert 40 <= left <= 41
# score race: Horde gaining faster -> Horde wins estimate
LA.execute('''for i = 1, 6 do GT = GT + 12; SCORE.h = SCORE.h + 30; SCORE.a = SCORE.a + 10; ADDON_NS.BGObj:Update() end''')
est = LA.eval('(function() local s, t = ADDON_NS.BGObj:Estimate() return tostring(s) .. " " .. tostring(math.floor((t or 0) / 60)) end)()')
print("estimate:", est)
assert est.startswith("h ")
# the panel replaces the feed
LA.execute('ADDON_NS.EventWindow.frame:Show(); ADDON_NS.BGPanel:Apply()')
print("panel on:", LA.eval('ADDON_NS.BGPanel.on'), "| feed hidden:", not LA.eval('ADDON_NS.EventWindow.msg:IsShown()'))
print("panel line:", LA.eval('(ADDON_NS.BGPanel.info:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. " || " .. (ADDON_NS.BGPanel.right:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")'))
print("chip 3:", LA.eval('(ADDON_NS.BGPanel.chips[3].text:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")'))
print("score line:", LA.eval('(ADDON_NS.BGPanel.score:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")'), "|", LA.eval('(ADDON_NS.BGPanel.scoreR:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")'))
# Alterac Valley: only what's under attack, towers standing
LA.execute('''GetInstanceInfo = function() return "Alterac Valley", "pvp", 0, "", 40, 0, false, 30 end
POIS = { {"Stonehearth Bunker", 11}, {"Iceblood Tower", 9}, {"Tower Point", 9}, {"Dun Baldar North Bunker", 10}, {"Snowfall Graveyard", 3}, {"Frostwolf Graveyard", 12} }
ADDON_NS.BGObj:Update(); ADDON_NS.BGPanel:Draw()''')
LA.execute('POIS[1][2] = 8; POIS[2][2] = 11; ADDON_NS.BGObj:Update(); GT = GT + 60; POIS[5][2] = 13; ADDON_NS.BGObj:Update(); GT = GT + 12; ADDON_NS.BGPanel:Draw()')
strip = '(%s or ""):gsub("|c%%x%%x%%x%%x%%x%%x%%x%%x", ""):gsub("|r", "")'
v = 'ADDON_NS.BGPanel.av'
print("AV next:", LA.eval(strip % (v + '.name:GetText()')), "|", LA.eval(strip % (v + '.sub:GetText()')), "|", LA.eval(v + '.big:GetText()'))
print("AV row1:", LA.eval(strip % (v + '.rows[1].label:GetText()')), "|", LA.eval(strip % (v + '.rows[1].time:GetText()')))
print("AV pips:", LA.eval('(function() local s = ADDON_NS.BGObj:TowerStates() return "H " .. s.h.standing .. "/" .. s.h.burning .. "  A " .. s.a.standing .. "/" .. s.a.burning end)()'))
assert LA.eval(v + '.big:GetText()') != ""
print("tile 1:", LA.eval('(function() local a, b = ADDON_NS.Tiles.byKey.bgrepgame.get() return tostring(a) .. " / " .. tostring(b) end)()'))
print("AV chips:", LA.eval('(function() local o = {} for _, n in ipairs(ADDON_NS.BGObj:Chips()) do o[#o+1] = n.name end return table.concat(o, ", ") end)()'))
print("AV towers:", LA.eval('(function() local h, a = ADDON_NS.BGObj:TowersStanding() return tostring(h) .. " vs " .. tostring(a) end)()'))
# Warsong Gulch: carrier slots, flag respawn after a capture
LA.execute('''GetInstanceInfo = function() return "Warsong Gulch", "pvp", 0, "", 10, 0, false, 489 end
C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo = function(id)
  if id == 1893 then return { text = "1/3" } end
  if id == 1894 then return { text = FLAGS_H .. "/3" } end
end
FLAGS_H = 1
ADDON_NS.BGObj:Update()
FLAGS_H = 2
ADDON_NS.BGObj:Update(); ADDON_NS.BGPanel:Apply()''')
print("WSG respawn:", LA.eval('tostring(ADDON_NS.BGObj:RespawnLeft())'), "| slots shown:", LA.eval('ADDON_NS.BGPanel.slots[1]:IsShown()'), "| slot1:", LA.eval('ADDON_NS.BGPanel.slots[1].name:GetText()'))
# leaving: back to the feed
LA.execute('IsInInstance = function() return false end; ADDON_NS.InBattleground = function() return false end; ADDON_NS.BGObj:Update(); ADDON_NS.BGPanel:Apply()')
print("after leaving, feed shown:", LA.eval('ADDON_NS.EventWindow.msg:IsShown()'), "| panel on:", LA.eval('ADDON_NS.BGPanel.on'))
# 1.4.52: joining (or reloading) mid-game: an assault icon already there is not counted as an attack
LA.execute('''IsInInstance = function() return true, "pvp" end; ADDON_NS.InBattleground = function() return true end
GetInstanceInfo = function() return "Alterac Valley", "pvp", 0, "", 40, 0, false, 30 end
ADDON_NS.db.bgObjSave = nil
POIS = { {"Dun Baldar North Bunker", 11}, {"Frostwolf Graveyard", 13}, {"Iceblood Tower", 10} }
ADDON_NS.BGObj:Reset(nil); ADDON_NS.BGObj:Update()''')
n = LA.eval('#ADDON_NS.BGObj:Chips()')
print("attacks right after joining:", n)
assert n == 0
# seen changing: counted; and it survives a /reload
LA.execute('POIS[3][2] = 8; ADDON_NS.BGObj:Update(); GT = GT + 30; ADDON_NS.BGObj:Reset(nil); ADDON_NS.BGObj:Update()')
left = LA.eval('ADDON_NS.BGObj:Left(ADDON_NS.BGObj.nodes["Iceblood Tower"])')
print("after reload, Iceblood Tower burns in:", left)
assert left and 265 <= left <= 271
print("hover H:", LA.eval('(function() local o = {} for _, t in ipairs(ADDON_NS.BGObj:TowerList("h")) do o[#o+1] = t.name .. "=" .. t.state end return table.concat(o, ", ") end)()'))
print("icon log:", LA.eval('ADDON_NS.db.bgIconLog[#ADDON_NS.db.bgIconLog]'))
# in a fight the carrier slots are left alone (a secure button may hold on to them)
LA.execute('IN_COMBAT = true; ADDON_NS.BGPanel:Draw(); IN_COMBAT = false')
print("drew in combat without touching slots: ok")
