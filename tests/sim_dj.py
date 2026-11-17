import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__)) + "/"
REPO = _os.path.dirname(HERE.rstrip("/")) + "/"
exec(open("sim.py").read().split("A = client(")[0])
A = client("Grimtusk", "WARRIOR", "Orc", 20, "The Barrens")
L, G, ns = A
L.execute('''
C_Map.GetMapInfo = C_Map.GetMapInfo or function(id) if id == 279 then return {name="Wailing Caverns", mapType=4} elseif id == 1413 then return {name="The Barrens", mapType=3} elseif id == 1456 then return {name="Thunder Bluff", mapType=3} end end
C_Map.GetMapArtLayers = function(id) return {{layerWidth=1002, layerHeight=668, tileWidth=256, tileHeight=256}} end
C_Map.GetMapArtLayerTextures = function(id, l) local t = {} for i=1,12 do t[i]=1000+i end return t end
C_Map.SetUserWaypoint = function() end
UiMapPoint = {CreateFromCoordinates=function() return {} end}
C_QuestLog.GetNumQuestLogEntries = C_QuestLog.GetNumQuestLogEntries or function() return 0 end
C_QuestLog.GetInfo = C_QuestLog.GetInfo or function() return nil end
C_QuestLog.IsQuestFlaggedCompleted = function(id) return id == 865 end
C_QuestLog.GetLogIndexForQuestID = function(id) if id == 1486 then return 3 end end
C_QuestLog.GetQuestObjectives = function(id) return {{numFulfilled=14, numRequired=20}} end
C_QuestLog.IsComplete = function() return false end
UISpecialFrames = UISpecialFrames or {}
tinsert = tinsert or table.insert
''')
# give a friend the quest in ChillanDB
L.execute('''
ChillanDB.people.friend1 = {main="Helse Prest", alias="Kenny", heard=time(), lastSeen=time(), chars={["Helse Prest"]={name="Helse Prest", class="PRIEST", level=22}}, quests={[1486]="", [959]=""}}
''')
files = ["Core.lua", "Data/WailingCaverns.lua", "Map.lua", "UI.lua"]
dj = L.eval('''function(base, files)
  local ns = {}
  for _, f in ipairs(files) do
    local chunk, err = loadfile(base .. f)
    if not chunk then table.insert(ERRORS, "load " .. f .. ": " .. err)
    else local ok, e = pcall(chunk, "ChillanDungeonJournal", ns) if not ok then table.insert(ERRORS, "run " .. f .. ": " .. tostring(e)) end end
  end
  return ns end''')(REPO + "ChillanDungeonJournal/", L.table_from(files))
G.FIRE("ADDON_LOADED", "ChillanDungeonJournal")
L.execute('ChillanDJ.UI:Toggle()')
print("shown:", L.eval('ChillanDJ.UI.frame:IsShown()'))
for t in ["overview","quests","map","bosses"]:
    L.execute('ChillanDJ.UI:Select("%s")' % t)
G.FIRE("ENCOUNTER_END", 1, "Kresh", 1, 5, 1)
L.execute('ChillanDJ.Debug()')
L.execute('ChillanDJ.Map:PrintPins()')
print("gang:", L.eval('#ChillanDJ.GangWithQuest({id=1486})'), "status:", L.eval('ChillanDJ.MyQuestStatus({id=1486})'))
print("FEIL:", list(G.ERRORS.values())[:8])
