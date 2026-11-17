-- Enkel falsk WoW-klient for å laste Chillan og simulere meldinger
local ME = ...  -- { name=, realm=, class=, race=, level= }
MOCK_ME = ME
ERRORS = {}
OUTBOX = {}
TIMERS = {}
NOW = 1000000
GT = 100

local function noop() end
local objMT = {}
local function newObj(kind, parent)
  local o = { _kind = kind, _w = 100, _h = 30, _shown = true, _scripts = {}, _text = "", _parent = parent, _msgs = {} }
  return setmetatable(o, objMT)
end
local methods = {}
function methods:CreateTexture() return newObj("Texture", self) end
function methods:CreateFontString() return newObj("FontString", self) end
function methods:CreateLine() return newObj("Line", self) end
function methods:GetVerticalScroll() return 0 end
function methods:GetBottom() return 300 end
function UnitXP() return 12000 end
function UnitXPMax() return 45000 end
function GetXPExhaustion() return 8000 end
function GetAverageItemLevel() return 28.4, 27.6 end
function methods:GetStringHeight() return 16 end
function methods:GetCenter() return 100, 100 end
function methods:SetSize(w, h) self._w, self._h = w, h end
function methods:SetWidth(w) self._w = w end
function methods:SetHeight(h) self._h = h end
function methods:GetWidth() return self._w end
function methods:GetHeight() return self._h end
UPDATERS = {}
function methods:SetScript(k, f) self._scripts[k] = f if k == "OnUpdate" and f then table.insert(UPDATERS, self) end end
function methods:GetScript(k) return self._scripts[k] end
function methods:HookScript(k, f) self._scripts[k] = f end
function methods:Show() self._shown = true if self._scripts.OnShow then self._scripts.OnShow(self) end end
function methods:Hide() self._shown = false end
function methods:IsShown() return self._shown end
function methods:IsVisible() return self._shown end
function methods:SetShown(v) self._shown = v and true or false end
function methods:SetText(t) self._text = t and tostring(t) or "" end
function methods:GetText() return self._text end
function methods:GetStringWidth() return #(self._text or "") * 6 end
function methods:SetFont() return true end
function methods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function methods:GetFrameLevel() return 1 end
function methods:HasFocus() return self._focus or false end
function methods:SetFocus() self._focus = true end
function methods:ClearFocus() self._focus = false end
function methods:GetCursorPosition() return self._cur or #(self._text or "") end
function methods:SetCursorPosition(n) self._cur = n end
function methods:Insert(t) self._text = (self._text or "") .. t self._cur = nil end
function methods:GetEffectiveScale() return 1 end
function methods:GetScale() return 1 end
function methods:AddMessage(m) table.insert(self._msgs, m) end
function methods:Clear() self._msgs = {} end
function methods:GetMapID() return 1434 end
function methods:Click() if self._scripts.OnClick then self._scripts.OnClick(self, "LeftButton") end end
function methods:GetNumMessages() return #self._msgs end
objMT.__index = function(t, k)
  if methods[k] then return methods[k] end
  if type(k) == "string" and k:match("^%u") then return noop end
  return nil
end

function CreateFrame(kind, name, parent)
  local o = newObj(kind, parent)
  if name then _G[name] = o end
  return o
end
UIParent = newObj("Frame")
GameTooltip = newObj("GameTooltip")
WorldMapFrame = newObj("Frame")
Minimap = newObj("Frame")
DEFAULT_CHAT_FRAME = newObj("ScrollingMessageFrame")
function GetCursorPosition() return 150, 150 end
WorldMapFrame.ScrollContainer = newObj("Frame"); WorldMapFrame.ScrollContainer.Child = newObj("Frame")
WorldMapFrame._shown = false
GameFontNormal = {}
UISpecialFrames = {}
tinsert = table.insert
SlashCmdList = {}
SOUNDKIT = {}
Enum = { SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3 }, UITextureSliceMode = { Stretched = 0 } }
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", PRIEST = "Priest", ROGUE = "Rogue", SHAMAN = "Shaman" }
ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
NUM_CHAT_WINDOWS = 2

function PlaySound() end
function hooksecurefunc() end
function RequestTimePlayed() REQUESTED_PLAYED = true end
function ReloadUI() end
function time() return NOW end
function GetTime() return GT end
date = os.date
function UnitName(u) if u == "player" then return ME.name end return nil end
function UnitFullName(u) return ME.name, ME.realm end
function GetNormalizedRealmName() return ME.realm end
function UnitClass() return ME.class, ME.class end
function UnitRace() return ME.race end
function UnitLevel() return ME.level end
function UnitIsAFK() return false end
function UnitFactionGroup() return "Horde", "Horde" end
function UnitExists() return false end
function UnitIsPlayer() return false end
function UnitIsEnemy() return false end
function IsInInstance() if IN_INSTANCE then return true, "party" end return false, "none" end
function GetInstanceInfo() if IN_INSTANCE then return "Wailing Caverns" end return "" end
function GetRealZoneText() return ME.zone or "Durotar" end
function GetZoneText() return ME.zone or "Durotar" end
function GetSubZoneText() return "" end
function GetMoney() return ME.money or 0 end
function IsInGuild() return false end
function IsInGroup() return false end
function IsInRaid() return false end
function GetNumGroupMembers() return 0 end
function GetProfessions() return 1, nil end
function GetProfessionInfo() return "Mining", nil, 75, 150 end
local channels = {}
function GetChannelName(n) return channels[n] or 0 end
function JoinTemporaryChannel(n) channels[n] = 5 end
function LeaveChannelByName(n) channels[n] = nil end
function ChatFrame_AddMessageEventFilter(ev, fn) FILTERS = FILTERS or {} FILTERS[ev] = fn end
function ChatFrame_RemoveChannel() end
function ChatFrame_SendTell(n) LAST_TELL = n end
function CreateVector2D(x, y) return { x = x, y = y, GetXY = function(s) return s.x, s.y end } end

C_Timer = {
  After = function(sec, fn) table.insert(TIMERS, { at = GT + sec, fn = fn }) end,
  NewTicker = function(sec, fn) local t = { every = sec, at = GT + sec, fn = fn } table.insert(TIMERS, t)
    return { Cancel = function() t.cancelled = true end } end,
}
C_ChatInfo = {
  RegisterAddonMessagePrefix = function() end,
  SendAddonMessage = function(prefix, msg, chatType, target) table.insert(OUTBOX, { prefix, msg, chatType, target }) return 0 end,
}
C_ChatInfo.SendAddonMessageLogged = C_ChatInfo.SendAddonMessage
-- Battle.net: BN_FRIENDS = { { gameAccountID = n, characterName = "..", realmName = ".." }, ... }
BN_FRIENDS = {}
WOW_PROJECT_ID = 99
function BNGetNumFriends() return #BN_FRIENDS end
C_BattleNet = {
  GetFriendNumGameAccounts = function(i) return BN_FRIENDS[i] and 1 or 0 end,
  GetFriendGameAccountInfo = function(i, j)
    local f = BN_FRIENDS[i]
    if not f then return nil end
    return { clientProgram = "WoW", isOnline = f.online ~= false, gameAccountID = f.gameAccountID,
      characterName = f.characterName, realmName = f.realmName, wowProjectID = 99 }
  end,
  SendGameData = function(id, prefix, msg) table.insert(OUTBOX, { prefix, msg, "BN", id }) return 0 end,
}
C_FriendList = { GetNumFriends = function() return 0 end, GetFriendInfoByIndex = function() return nil end }
C_Map = {
  GetBestMapForUnit = function() return 1411 end,
  GetPlayerMapPosition = function() return CreateVector2D(0.45, 0.62) end,
  GetWorldPosFromMapPos = function() return 1, CreateVector2D(-600, -4200) end,
  GetMapPosFromWorldPos = function(cont, wp, mapID) return mapID, CreateVector2D(0.5, 0.5) end,
  SetUserWaypoint = function() WAYPOINT = true end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { m, x, y } end }
C_Container = {
  GetContainerNumSlots = function(bag) return bag == 0 and 16 or 0 end,
  GetContainerNumFreeSlots = function(bag) return bag == 0 and 5 or 0 end,
  GetContainerItemInfo = function(bag, slot) if slot == 1 then return { itemID = 4540, stackCount = 12 } end return nil end,
}
IN_COMBAT = false
function GetInventoryItemDurability(slot) if slot == 5 then return 30, 100 end return nil end
IN_INSTANCE = false
function IsAltKeyDown() return false end
function InCombatLockdown() return IN_COMBAT end
function UnitAffectingCombat() return IN_COMBAT end
function GetNumGroupMembers() return 0 end
function IsInRaid() return false end
MY_QUESTS = {}
C_QuestLog = {
  GetNumQuestLogEntries = function() return #MY_QUESTS end,
  GetInfo = function(i) local q = MY_QUESTS[i] if not q then return nil end return { questID = q[1], title = q[2], isHeader = false, suggestedGroup = q[3] or 0 } end,
  GetQuestTagInfo = function() return nil end,
  GetTitleForQuestID = function(id) return "Tittel " .. id end,
  RequestLoadQuestByID = function() end,
}
C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }
C_Item = { GetItemInfoInstant = function(id) if id == 4540 then return id, "Consumable", "Food", "", 0, 0, 5 end return id end, GetItemQualityByID = function() return 4 end, GetItemInfo = function(id) return "Item", "|cffa335ee|Hitem:" .. id .. "::|h[Epic " .. id .. "]|h|r" end }
C_Spell = { GetSpellName = function(id) return "Recipe " .. id end }
C_PartyInfo = { InviteUnit = function(n) LAST_INVITE = n end }

-- kjør tidtakere fram til et tidspunkt
function ADVANCE(sec)
  local steps = math.max(1, math.floor(sec / 0.2))
  for i = 1, steps do
    ADVANCE_RAW(sec / steps)
    for _, f in ipairs(UPDATERS) do
      local fn = f._scripts.OnUpdate
      if fn and f._shown then
        local ok, err = pcall(fn, f, sec / steps)
        if not ok then table.insert(ERRORS, "update: " .. tostring(err)) end
      end
    end
  end
end
function ADVANCE_RAW(sec)
  local target = GT + sec
  while true do
    table.sort(TIMERS, function(a, b) return a.at < b.at end)
    local t = TIMERS[1]
    if not t or t.at > target then break end
    table.remove(TIMERS, 1)
    GT = t.at
    NOW = NOW + 0 -- veggklokke følger GT
    if not t.cancelled then
      local ok, err = pcall(t.fn)
      if not ok then table.insert(ERRORS, "timer: " .. tostring(err)) end
      if t.every then t.at = GT + t.every table.insert(TIMERS, t) end
    end
  end
  NOW = NOW + (target - GT)
  GT = target
end

function FIRE(event, ...)
  local f = ADDON_NS.eventFrame
  local fn = f._scripts.OnEvent
  if fn then
    local ok, err = pcall(fn, f, event, ...)
    if not ok then table.insert(ERRORS, event .. ": " .. tostring(err)) end
  end
end

function LOAD(base, files)
  local ns = {}
  ADDON_NS = ns
  for _, file in ipairs(files) do
    local chunk, err = loadfile(base .. file)
    if not chunk then table.insert(ERRORS, "load " .. file .. ": " .. err)
    else
      local ok, e = pcall(chunk, "Chillan", ns)
      if not ok then table.insert(ERRORS, "run " .. file .. ": " .. tostring(e)) end
    end
  end
  return ns
end
