-- Chillan? Dungeon Journal – core: colours, helpers, quest status, gang data, slash command
local ADDON, ns = ...
_G.ChillanDJ = ns

ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version"))
  or (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "dev"
if ns.VERSION == "@project-version@" then ns.VERSION = "dev" end

ns.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
ns.FONT = ns.MEDIA .. "Fonts\\Inter-Regular.ttf"
ns.FONT_SEMI = ns.MEDIA .. "Fonts\\Inter-SemiBold.ttf"
ns.FONT_BOLD = ns.MEDIA .. "Fonts\\Inter-Bold.ttf"
ns.TEX = ns.MEDIA .. "Textures\\"

-- Same graphite look as Chillan?
ns.C = {
  bg = "0F1013", window = "16171B", card = "1E2026", cardHover = "23252B", line = "2A2D33", line2 = "3A3D44",
  text = "E6E8EB", text2 = "B9BEC4", dim = "8A9097",
  accent = "C69B6D", green = "5FD18B", amber = "E0B04F", red = "F2777A", blue = "8FB8E8", purple = "B9AEDB",
  rareBlue = "5AA2FF",
}

function ns.hex(h, a)
  h = h or "FFFFFF"
  return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, a or 1
end
function ns.Colorize(text, h) return "|cff" .. (h or "FFFFFF") .. tostring(text) .. "|r" end
function ns.Print(msg) print("|cffC69B6DChillan? DJ|r " .. tostring(msg)) end

-- Class colour of a class token or localized name
function ns.ClassHex(class)
  if not class then return ns.C.text end
  local token = class:upper():gsub("%s", "")
  local c = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[token])
  if not c and LOCALIZED_CLASS_NAMES_MALE then
    for k, v in pairs(LOCALIZED_CLASS_NAMES_MALE) do if v == class then c = RAID_CLASS_COLORS[k] break end end
  end
  if not c then return ns.C.text end
  return string.format("%02X%02X%02X", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
end

---------------------------------------------------------------------------
-- Maps: find a uiMap by its name (IDs differ between game versions), cache the result
---------------------------------------------------------------------------
local mapCache = {}
function ns.FindMap(names, hint, mapType)
  local key = table.concat(names, "|")
  if mapCache[key] ~= nil then return mapCache[key] or nil end
  local want = {}
  for _, n in ipairs(names) do want[n:lower()] = true end
  local function ok(id)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
    return info and info.name and want[info.name:lower()] and (not mapType or info.mapType == mapType)
  end
  if hint and ok(hint) then mapCache[key] = hint return hint end
  for id = 1, 3000 do
    if ok(id) then mapCache[key] = id return id end
  end
  mapCache[key] = false
  return nil
end

function ns.SetWaypoint(mapID, x, y, label)
  if not (mapID and x and y and C_Map and C_Map.SetUserWaypoint and UiMapPoint) then
    ns.Print("Couldn't set a waypoint here.")
    return false
  end
  local ok = pcall(function()
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
  end)
  if ok then ns.Print("Waypoint set: " .. (label or "") .. string.format(" (%.1f, %.1f)", x * 100, y * 100)) end
  return ok
end

function ns.OpenWorldMap(mapID)
  pcall(function()
    if not WorldMapFrame:IsShown() then ToggleWorldMap() end
    if mapID then WorldMapFrame:SetMapID(mapID) end
  end)
end

---------------------------------------------------------------------------
-- Quest status for me: "done", "log" (with progress text) or "available"
---------------------------------------------------------------------------
local function logIndexByTitle(title)
  if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return nil end
  for i = 1, C_QuestLog.GetNumQuestLogEntries() do
    local info = C_QuestLog.GetInfo(i)
    if info and not info.isHeader and info.title == title then return i, info.questID end
  end
end

function ns.MyQuestStatus(q)
  local id = q.id
  if id and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id) then return "done" end
  local idx
  if id and C_QuestLog.GetLogIndexForQuestID then idx = C_QuestLog.GetLogIndexForQuestID(id) end
  local qid = id
  if not idx then idx, qid = logIndexByTitle(q.name) end
  if idx then
    -- objective progress, e.g. "14/20"
    local prog
    local objs = qid and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(qid)
    if objs and objs[1] then
      local parts = {}
      for _, o in ipairs(objs) do
        if o.numRequired and o.numRequired > 1 then parts[#parts + 1] = (o.numFulfilled or 0) .. "/" .. o.numRequired end
      end
      prog = table.concat(parts, " · ")
    end
    if qid and C_QuestLog.IsComplete and C_QuestLog.IsComplete(qid) then return "ready", "ready to turn in" end
    return "log", prog
  end
  return "available"
end

---------------------------------------------------------------------------
-- The gang, read from Chillan? if it's installed (who has which quest)
---------------------------------------------------------------------------
local function online(p)
  local t = time()
  if p.heard and (t - p.heard) < 120 then return true end
  if p.byeAt and (t - p.byeAt) < 90 then return false end
  return p.via and (t - p.via) < 100 or false
end

function ns.HasChillan() return type(_G.ChillanDB) == "table" and type(_G.ChillanDB.people) == "table" end

-- list of { name, hex, online, level } for friends (not me) who have quest id in their log
function ns.GangWithQuest(q)
  local out = {}
  if not ns.HasChillan() or not q.id then return out end
  local db = _G.ChillanDB
  for pid, p in pairs(db.people) do
    if pid ~= db.pid and p.main and p.quests and p.quests[q.id] then
      local c = p.chars and p.chars[p.main] or {}
      out[#out + 1] = {
        name = (p.alias and p.alias ~= "") and p.alias or (c.name and c.name:match("^(%S+)")) or "?",
        hex = ns.ClassHex(c.class), online = online(p), level = c.level,
      }
    end
  end
  table.sort(out, function(a, b) if a.online ~= b.online then return a.online end return a.name < b.name end)
  return out
end

-- friends in level range for a dungeon
function ns.GangInRange(lo, hi)
  local n, total = 0, 0
  if not ns.HasChillan() then return nil end
  local db = _G.ChillanDB
  for pid, p in pairs(db.people) do
    if p.main and p.chars and p.chars[p.main] then
      local lvl = tonumber(p.chars[p.main].level)
      if lvl and (time() - (p.lastSeen or 0)) < 30 * 86400 then
        total = total + 1
        if lvl >= lo and lvl <= hi then n = n + 1 end
      end
    end
  end
  return n, total
end

---------------------------------------------------------------------------
-- Boss kills this visit (ticks off on the Bosses tab while you're inside)
---------------------------------------------------------------------------
ns.killed = {}
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("ENCOUNTER_END")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, e, a1, a2, _, _, a5)
  if e == "ADDON_LOADED" and a1 == ADDON then
    ChillanDJDB = ChillanDJDB or {}
    ChillanDJDB.pins = ChillanDJDB.pins or {}
    ns.db = ChillanDJDB
  elseif e == "ENCOUNTER_END" then
    -- encounterID, encounterName, difficultyID, groupSize, success
    if a5 == 1 and type(a2) == "string" then
      ns.killed[a2] = true
      if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    end
  elseif e == "PLAYER_ENTERING_WORLD" then
    local inInst = IsInInstance and IsInInstance()
    if not inInst then ns.killed = {} end
  end
end)

-- quest log changes refresh the open window
local qev = CreateFrame("Frame")
qev:RegisterEvent("QUEST_LOG_UPDATE")
qev:RegisterEvent("QUEST_TURNED_IN")
qev:SetScript("OnEvent", function()
  if ns.UI and ns.UI.frame and ns.UI.frame:IsShown() and not ns.UI.pending then
    ns.UI.pending = true
    C_Timer.After(0.5, function() ns.UI.pending = false ns.UI:Refresh() end)
  end
end)

SLASH_CHILLANDJ1 = "/cdj"
SLASH_CHILLANDJ2 = "/dungeons"
SlashCmdList.CHILLANDJ = function(msg)
  msg = (msg or ""):lower()
  if msg == "pins" then
    ns.Map:PrintPins()
  elseif msg == "debug" then
    ns.Debug()
  else
    ns.UI:Toggle()
  end
end

function ChillanDJ_OnCompartmentClick() ns.UI:Toggle() end

-- /cdj debug: checks quest IDs against the game's names, and which map was found
function ns.Debug()
  local d = ns.DUNGEONS and ns.DUNGEONS[1]
  if not d then return end
  ns.Print("Map: " .. tostring(ns.Map:MapID(d)) .. "  ·  Chillan? data: " .. (ns.HasChillan() and "yes" or "no"))
  for _, q in ipairs(d.allQuests) do
    local title = q.id and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(q.id)
    local st = ns.MyQuestStatus(q)
    print(string.format("  %s  id=%s  game title=%s  status=%s", q.name, tostring(q.id), tostring(title), st))
  end
end
