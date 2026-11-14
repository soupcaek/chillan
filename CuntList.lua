-- Chillan? – the Cunt List: ninja looters and general dicks, shared by the gang.
-- Anyone adds (with a reason), anyone can add a "me too" note, only the one who added removes.
-- Warnings: red lines in the player tooltip, a warning when you target them, when they invite
-- you or join your group, and a [Cunt] tag on their lines in chat and whispers.
local ADDON, ns = ...
local Comm = ns.Comm

local CL = {}
ns.Cunts = CL

local MAX_REASON, MAX_NOTE = 80, 80
local WARN_EVERY = 600                   -- one warning per person per 10 minutes

local function secret(v) return ns.isSecret and ns.isSecret(v) end
local function db()
  ns.db.cunts = ns.db.cunts or {}
  ns.db.cuntsGone = ns.db.cuntsGone or {}
  return ns.db.cunts, ns.db.cuntsGone
end
local function keyOf(name)
  if type(name) ~= "string" or secret(name) or name == "" then return nil end
  return (ns.ShortName(name) or name):lower()
end
CL.KeyOf = keyOf

function CL:Get(name)
  local k = keyOf(name)
  return k and db()[k] or nil, k
end

function CL:List()
  local out = {}
  for k, e in pairs(db()) do e.key = k out[#out + 1] = e end
  table.sort(out, function(a, b) return (a.t or 0) > (b.t or 0) end)
  return out
end

---------------------------------------------------------------------------
-- add, note, remove
---------------------------------------------------------------------------
function CL:Add(name, reason)
  local k = keyOf(name)
  reason = ns.Clean(reason or "", MAX_REASON)
  if not k or reason == "" then return false end
  local list, gone = db()
  local short = ns.ShortName(name)
  if list[k] then
    -- already on it: the reason becomes a note
    return self:Note(k, reason)
  end
  local e = { name = short, reason = reason, by = ns.pid, byChar = Comm:MyFull(), t = ns.Now(), notes = {} }
  list[k] = e
  gone[k] = nil
  Comm:Broadcast(Comm:Build("CU", e.name, e.reason, e.by, e.byChar, 0), 1, true)
  ns.Tracker:Event("CUNT", e.name, e.reason)
  ns.Print("|cffF2777A" .. e.name .. "|r is on the Cunt List: " .. e.reason)
  ns:MarkDirty()
  ns:Fire("CUNTS")
  return true
end

function CL:Note(k, text)
  local e = db()[k]
  text = ns.Clean(text or "", MAX_NOTE)
  if not e or text == "" then return false end
  local n = { pid = ns.pid, char = Comm:MyFull(), t = ns.Now(), text = text }
  e.notes = e.notes or {}
  e.notes[#e.notes + 1] = n
  Comm:Broadcast(Comm:Build("CV", e.name, n.pid, n.char, 0, n.text), 1, true)
  ns.Print("Added to " .. e.name .. ": " .. text)
  ns:MarkDirty()
  ns:Fire("CUNTS")
  return true
end

function CL:CanRemove(e) return e and e.by == ns.pid end

function CL:Remove(k)
  local list, gone = db()
  local e = list[k]
  if not self:CanRemove(e) then ns.Print("Only the one who added them can take them off the list.") return false end
  list[k] = nil
  gone[k] = ns.Now()
  Comm:Broadcast(Comm:Build("CW", e.name, e.by, 0), 1, true)
  if ns.Discord and ns.Discord.SendUncunt then pcall(ns.Discord.SendUncunt, ns.Discord, e.name) end
  ns:MarkDirty()
  ns:Fire("CUNTS")
  return true
end

---------------------------------------------------------------------------
-- gang sync
---------------------------------------------------------------------------
local function ago2t(a) return ns.Now() - math.max(0, tonumber(a) or 0) end

Comm:Handle("CU", function(f)
  local name, reason, by, byChar, ago = f[1], f[2], f[3], f[4], f[5]
  local k = keyOf(name)
  if not k or not reason or reason == "" then return end
  local list, gone = db()
  local t = ago2t(ago)
  if gone[k] and gone[k] >= t then return end       -- removed after it was added
  if list[k] then return end
  list[k] = { name = ns.ShortName(name), reason = reason, by = by, byChar = byChar, t = t, notes = {} }
  ns:MarkDirty()
  ns:Fire("CUNTS")
end)

Comm:Handle("CV", function(f)
  local name, pid, char, ago, text = f[1], f[2], f[3], f[4], f[5]
  local e = CL:Get(name)
  if not e or not text or text == "" then return end
  local t = ago2t(ago)
  e.notes = e.notes or {}
  for _, n in ipairs(e.notes) do
    if n.pid == pid and n.text == text then return end   -- have it
  end
  e.notes[#e.notes + 1] = { pid = pid, char = char, t = t, text = text }
  table.sort(e.notes, function(a, b) return (a.t or 0) < (b.t or 0) end)
  ns:MarkDirty()
  ns:Fire("CUNTS")
end)

Comm:Handle("CW", function(f)
  local name, by, ago = f[1], f[2], f[3]
  local k = keyOf(name)
  if not k then return end
  local list, gone = db()
  local e = list[k]
  if e and e.by ~= by then return end               -- only the one who added it removes it
  list[k] = nil
  gone[k] = math.max(gone[k] or 0, ago2t(ago))
  ns:MarkDirty()
  ns:Fire("CUNTS")
end)

-- someone came online: send them the list (and recent removals)
function CL:SyncTo(target)
  local list, gone = db()
  local n = 0
  for _, e in pairs(list) do
    if n >= 60 then break end
    n = n + 1
    Comm:SendTo(target, Comm:Build("CU", e.name, e.reason, e.by or "", e.byChar or "", ns.Now() - (e.t or ns.Now())), 3, true)
    for _, note in ipairs(e.notes or {}) do
      Comm:SendTo(target, Comm:Build("CV", e.name, note.pid or "", note.char or "", ns.Now() - (note.t or ns.Now()), note.text), 3, true)
    end
  end
  for k, t in pairs(gone) do
    if ns.Now() - t < 30 * 86400 then
      Comm:SendTo(target, Comm:Build("CW", k, "", ns.Now() - t), 3, true)
    else
      gone[k] = nil
    end
  end
end

---------------------------------------------------------------------------
-- warnings
---------------------------------------------------------------------------
local warned = {}

function CL:WhoAdded(e)
  local p = e and e.by and ns:GetPerson(e.by)
  return (p and ns:PersonFirst(p)) or (e and e.byChar and ns.ShortName(e.byChar)) or "someone"
end

function CL:Warn(name, why)
  local e, k = self:Get(name)
  if not e then return end
  if warned[k .. why] and ns.Now() - warned[k .. why] < WARN_EVERY then return end
  warned[k .. why] = ns.Now()
  local text = e.reason .. "  – " .. self:WhoAdded(e) .. ", " .. ns.Ago(e.t)
  local title = ({
    target = e.name .. " is on the Cunt List",
    invite = e.name .. " invited you – on the Cunt List!",
    group = e.name .. " is in your group – on the Cunt List!",
    whisper = e.name .. " whispered you – on the Cunt List",
  })[why] or (e.name .. " is on the Cunt List")
  ns:Fire("TOAST", { kind = "enemy", title = title, text = text, sticky = (why == "invite" or why == "group") })
  ns.Sound("sos")
  ns.Print("|cffF2777A" .. title .. "|r: " .. text)
end

local function unitName(unit)
  if not ns.S(UnitIsPlayer, unit) then return nil end
  local n = ns.S(UnitName, unit)
  if type(n) == "string" and n ~= "" then return n end
end

ns:On("PLAYER_TARGET_CHANGED", function()
  local n = unitName("target")
  if n then CL:Warn(n, "target") end
end)

ns:On("PARTY_INVITE_REQUEST", function(inviter)
  if type(inviter) == "string" and not secret(inviter) then CL:Warn(inviter, "invite") end
end)

-- someone on the list in my group (they joined, or I joined theirs)
local inGroupSeen = {}
ns:On("GROUP_ROSTER_UPDATE", function()
  if not (IsInGroup and IsInGroup()) then inGroupSeen = {} return end
  local raid = IsInRaid and IsInRaid()
  local n = ns.S(GetNumGroupMembers) or 0
  local now = {}
  for i = 1, n do
    local unit = raid and ("raid" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
    local name = unitName(unit)
    local k = name and keyOf(name)
    if k then
      now[k] = true
      if not inGroupSeen[k] and db()[k] then CL:Warn(name, "group") end
    end
  end
  inGroupSeen = now
end)

-- the tooltip: red lines with the reason
local function onUnitTooltip(tt)
  if not tt or not tt.GetUnit then return end
  local ok, _, unit = pcall(tt.GetUnit, tt)
  if not ok or not unit or secret(unit) then return end
  local name = unitName(unit)
  local e = name and CL:Get(name)
  if not e then return end
  tt:AddLine("On the Cunt List", 0.95, 0.47, 0.48)
  tt:AddLine(e.reason .. "  (" .. CL:WhoAdded(e) .. ", " .. ns.Ago(e.t) .. ")", 0.95, 0.65, 0.65, true)
  local nn = #(e.notes or {})
  if nn > 0 then
    local last = e.notes[nn]
    local p = last.pid and ns:GetPerson(last.pid)
    tt:AddLine("+" .. nn .. ": " .. last.text .. " (" .. ((p and ns:PersonFirst(p)) or ns.ShortName(last.char or "?")) .. ")", 0.8, 0.6, 0.6, true)
  end
  tt:Show()
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt)
    if tt == GameTooltip then onUnitTooltip(tt) end
  end)
elseif GameTooltip and GameTooltip.HookScript then
  pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", onUnitTooltip)
end

-- chat: a [Cunt] tag in front of their lines; a warning the first time they whisper you
local TAG = "|cffF2777A[Cunt]|r "
local function chatFilter(_, event, text, author, ...)
  if type(text) ~= "string" or secret(text) or type(author) ~= "string" or secret(author) then return false end
  local e = CL:Get(author)
  if not e then return false end
  if event == "CHAT_MSG_WHISPER" then CL:Warn(author, "whisper") end
  return false, TAG .. text, author, ...
end
if ChatFrame_AddMessageEventFilter then
  for _, ev in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_CHANNEL", "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_EMOTE" }) do
    ChatFrame_AddMessageEventFilter(ev, chatFilter)
  end
end

---------------------------------------------------------------------------
-- right-click a player: "Add to the Cunt List" (with a box for the reason)
---------------------------------------------------------------------------
function CL:AskAdd(name)
  if type(name) ~= "string" or name == "" then return end
  local e, k = self:Get(name)
  local short = ns.ShortName(name)
  if e then
    ns.UI.Prompt(short .. " is already on the list (" .. e.reason .. ")",
      { { label = "Add your own note", placeholder = "e.g. did it again in SM" } },
      function(text)
        if not text or ns.Clean(text, MAX_NOTE) == "" then return true end
        CL:Note(k, text)
      end)
    return
  end
  ns.UI.Prompt("Add " .. short .. " to the Cunt List",
    { { label = "Why are they on the list?", placeholder = "e.g. ninja looted the Whitemane boots" } },
    function(reason)
      if not reason or ns.Clean(reason, MAX_REASON) == "" then return true end   -- a reason is a must
      CL:Add(name, reason)
    end)
end

-- add someone who isn't around: type the name and the reason
function CL:AskAddByName()
  ns.UI.Prompt("Add someone to the Cunt List",
    { { label = "Character name", placeholder = "e.g. Ninja Bob" },
      { label = "Why are they on the list?", placeholder = "e.g. ninja looted the Whitemane boots" } },
    function(name, reason)
      name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if name == "" or not reason or ns.Clean(reason, MAX_REASON) == "" then return true end   -- both are needed
      if CL:Get(name) then
        CL:Note(keyOf(name), reason)
      else
        CL:Add(name, reason)
      end
    end)
end

local function menuName(ctx)
  if type(ctx) ~= "table" then return nil end
  local name = ctx.name
  if (not name or secret(name)) and ctx.unit then name = unitName(ctx.unit) end
  if type(name) ~= "string" or secret(name) or name == "" then return nil end
  if ctx.server and type(ctx.server) == "string" and not secret(ctx.server) and ctx.server ~= "" then
    name = name .. "-" .. ctx.server
  end
  return name
end

if Menu and Menu.ModifyMenu then
  local me = ns.S(UnitName, "player")
  for _, tag in ipairs({ "MENU_UNIT_PLAYER", "MENU_UNIT_TARGET", "MENU_UNIT_FOCUS", "MENU_UNIT_PARTY",
    "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_FRIEND", "MENU_UNIT_CHAT_ROSTER", "MENU_UNIT_ENEMY_PLAYER",
    "MENU_UNIT_COMMUNITIES_GUILD_MEMBER", "MENU_UNIT_COMMUNITIES_MEMBER" }) do
    pcall(Menu.ModifyMenu, tag, function(owner, root, ctx)
      local name = menuName(ctx)
      if not name or keyOf(name) == keyOf(me or UnitName("player")) then return end
      local listed = CL:Get(name)
      root:CreateDivider()
      root:CreateButton(listed and "|cffF2777ACunt List: add a note|r" or "|cffF2777AAdd to the Cunt List|r", function()
        CL:AskAdd(name)
      end)
    end)
  end
end

-- /chill cunt <name>: same box, for names you can't right-click
function CL:Slash(rest)
  rest = (rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if rest == "" then
    local n = unitName("target")
    if n then return CL:AskAdd(n) end
    if ns.Window then ns.Window:Create() ns.Window.frame:Show() ns.Window:Select("cunts") end
    return
  end
  CL:AskAdd(rest)
end
