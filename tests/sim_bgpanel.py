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
POIS = { {"Stonehearth Bunker", 11}, {"Iceblood Tower", 10}, {"Tower Point", 10}, {"Dun Baldar North Bunker", 11}, {"Snowfall Graveyard", 15}, {"Frostwolf Graveyard", 13} }
ADDON_NS.BGObj:Update(); ADDON_NS.BGPanel:Draw()''')
LA.execute('POIS[1][2] = 12; POIS[2][2] = 9; ADDON_NS.BGObj:Update(); GT = GT + 60; POIS[5][2] = 14; ADDON_NS.BGObj:Update(); GT = GT + 12; ADDON_NS.BGPanel:Draw()')
strip = '(%s or ""):gsub("|c%%x%%x%%x%%x%%x%%x%%x%%x", ""):gsub("|r", "")'
v = 'ADDON_NS.BGPanel.av'
print("AV next:", LA.eval(strip % (v + '.name:GetText()')), "|", LA.eval(v + '.big:GetText()'))
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
LA.execute('POIS[3][2] = 9; ADDON_NS.BGObj:Update(); GT = GT + 30; ADDON_NS.BGObj:Reset(nil); ADDON_NS.BGObj:Update()')
left = LA.eval('ADDON_NS.BGObj:Left(ADDON_NS.BGObj.nodes["Iceblood Tower"])')
print("after reload, Iceblood Tower burns in:", left)
assert left and 265 <= left <= 271
print("hover H:", LA.eval('(function() local o = {} for _, t in ipairs(ADDON_NS.BGObj:TowerList("h")) do o[#o+1] = t.name .. "=" .. t.state end return table.concat(o, ", ") end)()'))
print("icon log:", LA.eval('ADDON_NS.db.bgIconLog[#ADDON_NS.db.bgIconLog]'))
# in a fight the carrier slots are left alone (a secure button may hold on to them)
LA.execute('IN_COMBAT = true; ADDON_NS.BGPanel:Draw(); IN_COMBAT = false')
print("drew in combat without touching slots: ok")
# 1.4.54: flags from the map, not from units the game may hide
LA.execute('''IsInInstance = function() return true, "pvp" end; ADDON_NS.InBattleground = function() return true end
GetInstanceInfo = function() return "Warsong Gulch", "pvp", 0, "", 10, 0, false, 489 end
POIS = { {"Silverwing Hold", 0}, {"Warsong Lumber Mill", 0} }
C_AreaPoiInfo.GetAreaPOIInfo = function(_, id) local p = POIS[id] local px = id == 1 and 0.5 or 0.5 local py = id == 1 and 0.1 or 0.9
  return { name = p[1], textureIndex = p[2], position = { GetXY = function() return px, py end } } end
GetNumBattlefieldFlagPositions = function() return 1 end
GetBattlefieldFlagPosition = function(i) return 0.52, 0.15, "Interface\\\\WorldStateFrame\\\\HordeFlag" end
ADDON_NS.BGObj:Reset(nil); ADDON_NS.BGObj:Update(); ADDON_NS.BGPanel:Apply(); ADDON_NS.BGPanel:Draw()''')
strip = '(%s or ""):gsub("|c%%x%%x%%x%%x%%x%%x%%x%%x", ""):gsub("|r", "")'
print("WSG slots:", LA.eval(strip % 'ADDON_NS.BGPanel.slots[1].label:GetText() .. ": " .. ADDON_NS.BGPanel.slots[1].name:GetText()'), "|",
  LA.eval(strip % 'ADDON_NS.BGPanel.slots[2].label:GetText() .. ": " .. ADDON_NS.BGPanel.slots[2].name:GetText()'))
# 1.4.54: learning Forever's icons from the bases count
LA.execute('''GetInstanceInfo = function() return "Darkspear Islands", "pvp", 0, "", 15, 0, false, 9999 end
GetNumBattlefieldFlagPositions = function() return 0 end
ADDON_NS.db.bgLearn = nil
POIS = { {"Camp", 500}, {"Ruins", 500}, {"Abandoned Tower", 500}, {"Shipwreck Cove", 500}, {"Darkspear Flag", 600} }
C_AreaPoiInfo.GetAreaPOIInfo = function(_, id) local p = POIS[id] return { name = p[1], textureIndex = p[2] } end
BASES = { a = 0, h = 0 }
C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo = function(id)
  if id == 1893 then return { text = "Bases: " .. BASES.a .. "  Resources: 100/2000" } end
  if id == 1894 then return { text = "Bases: " .. BASES.h .. "  Resources: 100/2000" } end
end
ADDON_NS.BGObj:Reset(nil); ADDON_NS.BGObj:Update()
POIS[3][2] = 501; ADDON_NS.BGObj:Update()          -- Alliance starts on the tower: unknown icon
T1 = ADDON_NS.BGObj.nodes["Abandoned Tower"].atk
GT = GT + 60; POIS[3][2] = 502; BASES.a = 1; ADDON_NS.BGObj:Update()   -- taken: Alliance +1
T2 = ADDON_NS.BGObj.nodes["Abandoned Tower"].side
ADDON_NS.BGObj:Reset(nil); ADDON_NS.BGObj:Update()  -- next game
POIS[1][2] = 501; ADDON_NS.BGObj:Update()           -- the same assault icon on Camp
T3 = ADDON_NS.BGObj.nodes["Camp"].atk''')
print("DI learn: unknown assault ->", LA.eval('tostring(T1)'), "| held after +1 ->", LA.eval('tostring(T2)'), "| next game, icon 501 ->", LA.eval('tostring(T3)'))
print("DI chips:", LA.eval('(function() local o = {} for _, n in ipairs(ADDON_NS.BGObj:Chips()) do o[#o+1] = n.name end return table.concat(o, ", ") end)()'))
assert LA.eval('T1') == "?" and LA.eval('T2') == "a" and LA.eval('T3') == "a"
# ---- 1.4.55 ----
strip2 = '(%s or ""):gsub("|c%%x%%x%%x%%x%%x%%x%%x%%x", ""):gsub("|r", "")'
# Darkspear Islands: chat lines drive the timers and owners, score from widget 7467, bases from labels
LA.execute('''ADDON_NS.db.bgLearn = nil
GetInstanceInfo = function() return "Darkspear Islands", "pvp", 0, "", 15, 0, false, 9999 end
POIS = { {"Camp", 0, "Horde Controlled"}, {"Ruins", 0, "Uncontrolled"}, {"Abandoned Tower", 0, "Alliance Controlled"}, {"Shipwreck Cove", 0, "Uncontrolled"}, {"Darkspear Flag", 0} }
C_AreaPoiInfo.GetAreaPOIInfo = function(_, id) local p = POIS[id] return { name = p[1], textureIndex = p[2], description = p[3] } end
C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo = function() return nil end
SC = { a = 760, h = 820 }
C_UIWidgetManager.GetDoubleStatusBarWidgetVisualizationInfo = function(id) if id == 7467 then return { leftBarValue = SC.a, leftBarMax = 2000, rightBarValue = SC.h, rightBarMax = 2000 } end end
ADDON_NS.BGObj:Reset(nil); ADDON_NS.BGObj:Update()
FIRE("CHAT_MSG_BG_SYSTEM_ALLIANCE", "The Alliance has assaulted the Ruins!")
POIS[2][3] = "Contested"
GT = GT + 15
ADDON_NS.BGObj:Update()''')
print("DI Ruins:", LA.eval('ADDON_NS.BGObj.nodes["Ruins"].atk'), LA.eval('ADDON_NS.BGObj:Left(ADDON_NS.BGObj.nodes["Ruins"])'),
      "| bases:", LA.eval('(function() local c = ADDON_NS.BGObj:CountBases() return c.h .. " vs " .. c.a end)()'),
      "| score:", LA.eval('(function() local s = ADDON_NS.BGObj:Score() return s.h.score .. "-" .. s.a.score .. " bases " .. tostring(s.h.bases) end)()'))
assert LA.eval('ADDON_NS.BGObj.nodes["Ruins"].atk') == "a"
LA.execute('''FIRE("CHAT_MSG_BG_SYSTEM_ALLIANCE", "The Alliance has taken the Ruins!"); ADDON_NS.BGObj:Update()''')
assert LA.eval('ADDON_NS.BGObj.nodes["Ruins"].side') == "a" and not LA.eval('ADDON_NS.BGObj.nodes["Ruins"].atk')
# final score estimate
LA.execute('''for i = 1, 6 do GT = GT + 12; SC.h = SC.h + 30; SC.a = SC.a + 10; ADDON_NS.BGObj:Update() end''')
print("DI estimate:", LA.eval('(function() local s, t, o = ADDON_NS.BGObj:Estimate() return tostring(s) .. " " .. math.floor(t) .. "s final other " .. tostring(o) end)()'))
# the centre flag from chat, and the reset after a capture
LA.execute('''FIRE("CHAT_MSG_BG_SYSTEM_ALLIANCE", "The flag was picked up by Brannoc!"); ADDON_NS.BGPanel:Apply(); ADDON_NS.BGPanel:Draw()''')
print("DI slot:", LA.eval(strip2 % 'ADDON_NS.BGPanel.slots[3].label:GetText() .. ": " .. ADDON_NS.BGPanel.slots[3].name:GetText()'))
LA.execute('''FIRE("CHAT_MSG_BG_SYSTEM_ALLIANCE", "The Alliance has captured the flag!")''')
print("DI reset:", LA.eval('tostring(ADDON_NS.BGObj:ResetLeft())'))
assert LA.eval('ADDON_NS.BGObj:ResetLeft()') == 21
# Warsong Gulch: flags out of 3, the clock, dropped flag
LA.execute('''GetInstanceInfo = function() return "Warsong Gulch", "pvp", 0, "", 10, 0, false, 489 end
C_UIWidgetManager.GetDoubleStatusBarWidgetVisualizationInfo = function() return nil end
C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo = function(id)
  if id == 1893 then return { text = "1/3" } end
  if id == 1894 then return { text = "2/3" } end
  if id == 6 then return { text = "14:20", state = 1 } end
end
ADDON_NS.BGObj:Reset(nil); ADDON_NS.BGObj:Update()
FIRE("CHAT_MSG_BG_SYSTEM_HORDE", "The Alliance flag was dropped by Lil Woyer!")
ADDON_NS.BGPanel:Apply(); ADDON_NS.BGPanel:Draw()''')
print("WSG score:", LA.eval(strip2 % 'ADDON_NS.BGPanel.score:GetText()'), "|", LA.eval(strip2 % 'ADDON_NS.BGPanel.scoreR:GetText()'),
      "| clock:", LA.eval(strip2 % 'ADDON_NS.BGPanel.info:GetText() .. " " .. ADDON_NS.BGPanel.right:GetText()'),
      "| dropped:", LA.eval(strip2 % 'ADDON_NS.BGPanel.info2:GetText() .. " " .. ADDON_NS.BGPanel.right2:GetText()'))
print("auto height:", LA.eval('math.floor(ADDON_NS.EventWindow.frame:GetHeight())'), "content", LA.eval('ADDON_NS.BGPanel.contentH'))
# a hidden announcement is skipped
LA.execute('ISSECRET_NEXT = true')
assert LA.eval('math.floor(ADDON_NS.EventWindow.frame:GetHeight())') == 218, "auto height"
# ---- 1.4.56 ----
# a fresh Darkspear Islands before the gates: icons that read "held" count for nothing while it's 0-0
LA.execute('''GetInstanceInfo = function() return "Darkspear Islands", "pvp", 0, "", 15, 0, false, 9999 end
GetNumBattlefieldFlagPositions = function() return 0 end
UnitExists = function() return false end
C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo = function() return nil end
C_UIWidgetManager.GetDoubleStatusBarWidgetVisualizationInfo = function(id) if id == 7467 then return { leftBarValue = SC.a, leftBarMax = 2000, rightBarValue = SC.h, rightBarMax = 2000 } end end
POIS = { {"Camp", 0}, {"Ruins", 0}, {"Abandoned Tower", 153}, {"Shipwreck Cove", 148}, {"Darkspear Flag", 45} }
C_AreaPoiInfo.GetAreaPOIInfo = function(_, id) local p = POIS[id] return { name = p[1], textureIndex = p[2] } end
SC = { a = 0, h = 0 }
ADDON_NS.BGObj:Reset(nil); ADDON_NS.BGObj:Update()''')
pre = LA.eval('tostring(ADDON_NS.BGObj.nodes["Abandoned Tower"].side)')
print("DI before the gates, tower side:", pre, "| bases:", LA.eval('tostring(ADDON_NS.BGObj:CountBases())'))
assert pre == "nil"
LA.execute('''SC = { a = 0, h = 5 }; ADDON_NS.BGObj:Update()''')
assert LA.eval('ADDON_NS.BGObj.nodes["Abandoned Tower"].side') == "h"
# the centre flag row is the bottom slot, alone; the Enemy FC slot (which sits higher) stays hidden
LA.execute('''ADDON_NS.BGPanel:Apply(); ADDON_NS.BGPanel:Draw()''')
print("DI slots shown:", LA.eval('ADDON_NS.BGPanel.slots[1]:IsShown()'), LA.eval('ADDON_NS.BGPanel.slots[2]:IsShown()'), LA.eval('ADDON_NS.BGPanel.slots[3]:IsShown()'),
      "|", LA.eval(strip2 % 'ADDON_NS.BGPanel.slots[3].label:GetText() .. ": " .. ADDON_NS.BGPanel.slots[3].name:GetText()'))
assert not LA.eval('ADDON_NS.BGPanel.slots[1]:IsShown()') and LA.eval('ADDON_NS.BGPanel.slots[3]:IsShown()')
LA.execute('''FIRE("CHAT_MSG_BG_SYSTEM_HORDE", "The Horde has captured the flag!"); ADDON_NS.BGPanel:Draw()''')
row = LA.eval(strip2 % 'ADDON_NS.BGPanel.slots[3].name:GetText()')[0]
print("DI after a capture:", row, "| separate line:", repr(LA.eval('ADDON_NS.BGPanel.info2:GetText()')))
assert row.startswith("back in") and LA.eval('ADDON_NS.BGPanel.info2:GetText()') == ""

# ---- 1.4.58 ----
# Forever's own Darkspear Islands numbers and labels: a neutral Tower (150) is nobody's, mid-game too
LA.execute('''POIS = { {"Camp", 35, "Horde Controlled"}, {"Ruins", 217, "Neutral"}, {"Abandoned Tower", 150, "Neutral"}, {"Shipwreck Cove", 146, "Alliance Controlled"}, {"Darkspear Flag", 45, ""} }
C_AreaPoiInfo.GetAreaPOIInfo = function(_, id) local p = POIS[id] return { name = p[1], textureIndex = p[2], description = p[3] } end
SC = { a = 300, h = 420 }
ADDON_NS.BGObj:Reset(nil); ADDON_NS.BGObj:Update()''')
sides = LA.eval('(function() local o = {} for _, k in ipairs({"Camp","Ruins","Abandoned Tower","Shipwreck Cove"}) do o[#o+1] = k .. "=" .. tostring(ADDON_NS.BGObj.nodes[k].side) end return table.concat(o, ", ") end)()')
print("DI sides:", sides)
assert sides == "Camp=h, Ruins=nil, Abandoned Tower=nil, Shipwreck Cove=a"
# being taken: "Contested" + the Alliance's assault icon on the Tower
LA.execute('''POIS[3][2], POIS[3][3] = 152, "Contested"; ADDON_NS.BGObj:Update()''')
assert LA.eval('ADDON_NS.BGObj.nodes["Abandoned Tower"].atk') == "a"
# a hidden line on the Alliance channel: the Alliance has the flag, and the line itself is drawn
LA.execute('''issecretvalue = function(v) return type(v) == "string" and v:find("^SECRET") ~= nil end
POIS[5] = nil; ADDON_NS.BGObj:Update()
FIRE("CHAT_MSG_BG_SYSTEM_ALLIANCE", "SECRET Nunte Aor has taken the flag!")
GT = GT + 42
ADDON_NS.BGPanel:Apply(); ADDON_NS.BGPanel:Draw()''')
s3 = 'ADDON_NS.BGPanel.slots[3]'
row = [LA.eval(strip2 % (s3 + '.label:GetText()'))[0], LA.eval(s3 + '.line:GetText()'), LA.eval(strip2 % (s3 + '.where:GetText()'))[0]]
print("DI carried:", row)
assert row[0] == "Alliance has the flag" and "Nunte" in row[1] and "held 0:42" in row[2]
# no "near near"
LA.execute('''GetNumBattlefieldFlagPositions = function() return 1 end
GetBattlefieldFlagPosition = function() return 0.6, 0.4, "" end
C_PvP = nil
ADDON_NS.BGPanel:Draw()''')
w = LA.eval(strip2 % (s3 + '.where:GetText()'))[0]
print("DI where:", w)
assert "near near" not in w
# the flag's map point back: in the middle again
LA.execute('''GetNumBattlefieldFlagPositions = function() return 0 end
POIS[5] = {"Darkspear Flag", 45, ""}; ADDON_NS.BGObj:Update(); ADDON_NS.BGPanel:Draw()''')
print("DI back:", LA.eval(strip2 % (s3 + '.label:GetText() .. ": " .. ' + s3 + '.name:GetText()'))[0])
assert LA.eval(strip2 % (s3 + '.name:GetText()'))[0] == "in the middle"
# the win line is in the winner's colour
LA.execute('''issecretvalue = nil''')
# ---- 1.4.60: "click to target" only when the button really points at the carrier shown
LA.execute('''issecretvalue = nil
GetNumGroupMembers = function() return 1 end
UnitExists = function(u) return u == "raid1" end
UnitName = function(u) if u == "raid1" then return "Tribulation" end if u == "player" then return MOCK_ME.name end end
C_UnitAuras = { GetAuraDataByIndex = function(u, j) if u == "raid1" and j == 1 then return { name = "Darkspear Flag", spellId = 1 } end end }
COMBAT = true
InCombatLockdown = function() return COMBAT end
ADDON_NS.BGObj.flag = {}; ADDON_NS.BGPanel.diUnit = "arena1"
ADDON_NS.BGPanel:Draw()''')
s3 = 'ADDON_NS.BGPanel.slots[3]'
fight = LA.eval(s3 + '.hint:GetText()')
LA.execute('''COMBAT = false; ADDON_NS.BGPanel:Draw()''')
calm = LA.eval(s3 + '.hint:GetText()')
print("hint in a fight:", repr(fight), "| after:", repr(calm), "| button unit:", LA.eval('ADDON_NS.BGPanel.diUnit'))
assert fight == "" and calm == "click to target" and LA.eval('ADDON_NS.BGPanel.diUnit') == "raid1"
