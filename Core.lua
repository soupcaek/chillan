-- Chillan? – core: namespace, saved data, events and helpers
local ADDON, ns = ...
_G.Chillan = ns

do
  local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local v = getMeta and getMeta(ADDON, "Version") or nil
  if not v or v:find("@", 1, true) then v = "0.0.0-dev" end
  ns.VERSION = (v:gsub("^v", ""))
end
ns.PROTO = "1"
ns.PREFIX = "Chillan"
-- (1.4.26) market prices use their own prefixes (each has its own send allowance in the game)
ns.MARKET_PREFIX = { ChillanM1 = true, ChillanM2 = true }
ns.MARKET_PREFIXES = { "ChillanM1", "ChillanM2" }
ns.MEDIA = "Interface\\AddOns\\Chillan\\Media\\"
ns.TEX = ns.MEDIA .. "Textures\\"
ns.FONT = ns.MEDIA .. "Fonts\\Inter-Regular.ttf"
ns.FONT_SEMI = ns.MEDIA .. "Fonts\\Inter-SemiBold.ttf"
ns.FONT_BOLD = ns.MEDIA .. "Fonts\\Inter-Bold.ttf"

---------------------------------------------------------------------------
-- Farger
---------------------------------------------------------------------------
local function hex(h)
  h = h:gsub("#", "")
  return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
end
ns.hex = hex

ns.C = {
  backdrop = "0C0D0F",
  window = "17191C",
  card = "1D2024",
  cardHover = "22262B",
  line = "24282D",
  input = "202328",
  inputLine = "2A2E33",
  active = "2A2E33",
  activeLine = "3A3F45",
  text = "E8EAED",
  text2 = "C9CDD2",
  muted = "9BA1A8",
  dim = "858B92",
  accent = "C8D1DC",
  accentText = "121417",
  green = "5FD18B",
  amber = "E0B04F",
  red = "F2777A",
  purple = "B9AEDB",
  gold = "E0C068",
  silver = "C8D1DC",
  bronze = "C9946A",
  sosBg = "3A1D1F",
  sosLine = "5A2A2C",
  sosText = "FFB4B5",
}

-- Klassefarger (shaman lysnet litt for lesbarhet på mørk bakgrunn)
local CLASS_HEX = {
  WARRIOR = "C69B6D", PALADIN = "F48CBA", HUNTER = "AAD372", ROGUE = "FFF468",
  PRIEST = "FFFFFF", SHAMAN = "3D96F2", MAGE = "3FC7EB", WARLOCK = "8788EE",
  DRUID = "FF7C0A", DEATHKNIGHT = "C41E3A", MONK = "00FF98", DEMONHUNTER = "A330C9", EVOKER = "33937F",
}
function ns.ClassHex(classFile)
  return CLASS_HEX[classFile or ""] or ns.C.text2
end
function ns.ClassColor(classFile)
  return hex(ns.ClassHex(classFile))
end
function ns.Colorize(text, h)
  return "|cff" .. (h or ns.C.text) .. tostring(text) .. "|r"
end

---------------------------------------------------------------------------
-- Hendelser (spillhendelser og interne meldinger)
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local handlers = {}
ns.eventFrame = eventFrame

function ns:On(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
    if not ok then handlers[event].unknown = true end
  end
  table.insert(handlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]
  if not list then return end
  for i = 1, #list do
    local ok, err = pcall(list[i], ...)
    if not ok and ns.debug then print("|cffF2777AChillan error|r", event, err) end
  end
end)

local listeners = {}
function ns:Listen(name, fn)
  listeners[name] = listeners[name] or {}
  table.insert(listeners[name], fn)
end
---------------------------------------------------------------------------
-- Mute and Do not disturb (local only, friends never see it)
-- Muted friend: no popups and no sounds from them. Their events still land in the feed,
-- stats and the normal WoW chat window, and their @mentions of you still come through.
-- Do not disturb (your own status): every popup and sound is muted, mentions included.
---------------------------------------------------------------------------
function ns:IsDND() return ns.db and ns.db.statusOverride == "DND" or false end
function ns:IsMuted(pid)
  return (pid and pid ~= ns.pid and ns.db and ns.db.muted and ns.db.muted[pid]) and true or false
end
function ns:SetMuted(pid, on)
  if not pid or pid == ns.pid then return end
  ns.db.muted = ns.db.muted or {}
  ns.db.muted[pid] = on and true or nil
  local p = ns:GetPerson(pid)
  ns.Print((on and "Muted " or "Unmuted ") .. (p and ns:PersonFirst(p) or "friend")
    .. (on and " – no popups or sounds from them (the feed still shows everything)." or "."))
  ns:MarkDirty()
end
-- true when a popup/sound from pid (kind = popup or sound kind) should be skipped
function ns:Silenced(pid, kind)
  if ns:IsDND() then return true end
  if kind == "mention" then return false end
  return ns:IsMuted(pid)
end
local POPUP_EVENTS = { DING = true, TOAST = true }

-- Popup rules (1.0.1). Someone's death or Alliance kill pops up once, then that kind stays quiet for
-- 10 minutes for the whole gang; at most 6 of these an hour. Held-back ones still go to the event
-- window, where you can react to them. Settings → Popups: calm (milestones only) / normal / all.
local QUIET_FOR, HOUR_CAP = 600, 6
local quietUntil, recent = {}, {}
function ns.PopupLevel() return (ns.db and ns.db.settings.popupLevel) or "normal" end
function ns.PopupGate(kind)
  local lvl = ns.PopupLevel()
  if lvl == "all" then return true end
  if lvl == "calm" then return false end
  local now = GetTime()
  if (quietUntil[kind] or 0) > now then return false end
  for i = #recent, 1, -1 do if now - recent[i] > 3600 then table.remove(recent, i) end end
  if #recent >= HOUR_CAP then return false end
  quietUntil[kind] = now + QUIET_FOR
  recent[#recent + 1] = now
  return true
end
-- (1.4.8) in a battleground or arena? IsInInstance alone isn't enough on every BG in Forever
function ns.InBattleground()
  local inInst, kind = ns.S(IsInInstance)
  if inInst and (kind == "pvp" or kind == "arena") then return true end
  if UnitInBattleground then
    local ok, v = pcall(UnitInBattleground, "player")
    if ok and v and not ns.isSecret(v) then return true end
  end
  -- a scoreboard with players on it only exists in a battleground
  if GetNumBattlefieldScores then
    local ok, n = pcall(GetNumBattlefieldScores)
    if ok and type(n) == "number" and not ns.isSecret(n) and n > 0 then return true end
  end
  if IsActiveBattlefieldArena then
    local ok, v = pcall(IsActiveBattlefieldArena)
    if ok and v == true then return true end
  end
  if C_PvP and C_PvP.IsBattleground then
    local ok, v = pcall(C_PvP.IsBattleground)
    if ok and v == true then return true end
  end
  if GetBattlefieldStatus and GetMaxBattlefieldID then
    local okN, n = pcall(GetMaxBattlefieldID)
    for i = 1, (okN and tonumber(n) or 0) do
      local ok, st = pcall(GetBattlefieldStatus, i)
      if ok and st == "active" then return true end
    end
  end
  return false
end
function ns.PopupGateReset() quietUntil, recent = {}, {} end

function ns:Fire(name, ...)
  if POPUP_EVENTS[name] then
    local x = ...
    if type(x) == "table" and ns:Silenced(x.pid, x.kind) then return end
  end
  local list = listeners[name]
  if not list then return end
  for i = 1, #list do
    local ok, err = pcall(list[i], ...)
    if not ok and ns.debug then print("|cffF2777AChillan error|r", name, err) end
  end
end

-- "Data endret" samles slik at UI bare tegnes på nytt maks to ganger i sekundet
local dirtyPending = false
function ns:MarkDirty()
  if dirtyPending then return end
  dirtyPending = true
  C_Timer.After(0.4, function()
    dirtyPending = false
    ns:Fire("DATA")
  end)
end

---------------------------------------------------------------------------
-- Hjelpere
---------------------------------------------------------------------------
function ns.isSecret(v)
  return issecretvalue and issecretvalue(v) or false
end

-- Kall en spill-API trygt: hemmelige verdier (Midnight/Forever) blir nil i stedet for å krasje
local function cleanResults(ok, ...)
  if not ok then return end
  local n = select("#", ...)
  local out = { ... }
  for i = 1, n do
    if ns.isSecret(out[i]) then out[i] = nil end
  end
  return unpack(out, 1, n)
end
function ns.S(fn, ...)
  if type(fn) ~= "function" then return end
  return cleanResults(pcall(fn, ...))
end

function ns.Now() return time() end

function ns.ShortName(full)
  if not full then return "?" end
  return (full:match("^([^%-]+)")) or full
end

-- Forever-navn har to ord ("Lil Warrior"). Vi viser alltid hele navnet (uten realm).
function ns.FirstName(name)
  return ns.ShortName(name)
end

-- Hele karakternavnet til spilleren selv, også om spillet gir etternavnet separat
function ns.MyDisplayName()
  local n = ns.S(UnitName, "player") or "?"
  if n:find(" ") then return n end
  local _, second = ns.S(UnitFullName, "player")
  local realm = ns.S(GetNormalizedRealmName)
  if second and second ~= "" and second ~= realm and not second:find("%d") and not second:find("Classic") then
    return n .. " " .. second
  end
  return n
end

---------------------------------------------------------------------------
-- Item links in gang chat. Links can't travel in addon messages (pipes are stripped),
-- so they are sent as {i:12345} and turned back into a real link on display.
---------------------------------------------------------------------------
ns.MAX_CHAT_ITEMS = 3
function ns.EncodeItems(text)
  if type(text) ~= "string" then return "" end
  local n = 0
  local function enc(id)
    n = n + 1
    if n > ns.MAX_CHAT_ITEMS then return "" end
    return "{i:" .. id .. "}"
  end
  -- the link itself (any colour format around it is stripped below)
  text = text:gsub("|Hitem:(%d+)[^|]*|h.-|h", enc)
  -- remove every other escape code: old |cffRRGGBB, new |cnIQ2: / |cn...: colours, |r, textures, other links
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:|]*:", ""):gsub("|r", "")
  text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h(.-)|h", "%1")
  return text
end

local itemWaiting = {}
local function itemInfo(id)
  local name, link, quality
  if C_Item and C_Item.GetItemInfo then
    name, link, quality = C_Item.GetItemInfo(id)
  elseif GetItemInfo then
    name, link, quality = GetItemInfo(id)
  end
  if not name then
    itemWaiting[id] = true
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  end
  if ns.isSecret(name) or ns.isSecret(link) then return nil end
  return name, quality, link
end

-- the game's real link for an item id, or nil while it loads (chat and feed redraw when it arrives)
function ns.ItemLink(id)
  id = tonumber(id)
  if not id then return nil end
  local _, _, link = itemInfo(id)
  if type(link) == "string" and link:find("|Hitem:", 1, true) then return link end
end

-- @names in class colour: lookup of every name a person can be mentioned by
local function mentionColors()
  local map = { all = "E0C068", alle = "E0C068" }
  local pids = {} -- navn -> person-id, så @navn kan holdes musa over (personkortet)
  for pid, p in pairs(ns.db.people or {}) do
    local main = ns:PersonChar(p) or {}
    local r, g, b = ns.ClassColor(main.class)
    local col = string.format("%02X%02X%02X", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
    local alias = ns:PersonAlias(p)
    if alias and alias ~= "" then
      map[alias:lower()] = col pids[alias:lower()] = pid
      local first = alias:match("^([%w\128-\255]+)")
      if first and #first >= 3 and first ~= alias then
        map[first:lower()] = map[first:lower()] or col
        pids[first:lower()] = pids[first:lower()] or pid
      end
    end
    for _, c in pairs(p.chars or {}) do
      if c.name then
        local cr, cg, cb = ns.ClassColor(c.class or main.class)
        local cc = string.format("%02X%02X%02X", math.floor(cr * 255), math.floor(cg * 255), math.floor(cb * 255))
        map[c.name:lower()] = cc
        pids[c.name:lower()] = pid
        local first = c.name:match("^(%S+)")
        if first and #first >= 3 and not map[first:lower()] then map[first:lower()] = cc pids[first:lower()] = pid end
      end
    end
  end
  local sorted = {}
  for n in pairs(map) do sorted[#sorted + 1] = n end
  table.sort(sorted, function(a, b) return #a > #b end)
  map.__sorted = sorted
  return map, pids
end

-- emote images (Twitch Emotes v2) in plain chat text
local function emo(t) return ns.Emotes and ns.Emotes:Render(t, nil, true) or t end

local function colorMentions(plain, baseHex, map, pids)
  if not plain:find("@", 1, true) then return ns.Colorize(emo(plain), baseHex) end
  local out, pos = {}, 1
  while true do
    local at = plain:find("@", pos, true)
    if not at then break end
    -- longest known name right after the @ (aliases can be several words, e.g. "Eirik / LINK")
    local name, col
    local rest = plain:sub(at + 1):lower()
    for _, n in ipairs(map.__sorted) do
      if rest:sub(1, #n) == n and not rest:sub(#n + 1, #n + 1):match("[%w]") then
        name = plain:sub(at + 1, at + #n) col = map[n]
        break
      end
    end
    if name then
      if at > pos then out[#out + 1] = ns.Colorize(emo(plain:sub(pos, at - 1)), baseHex) end
      local pid = pids and pids[name:lower()]
      local shown = ns.Colorize("@" .. name, col)
      out[#out + 1] = pid and ("|Hchillan:" .. tostring(pid) .. "|h" .. shown .. "|h") or shown
      pos = at + 1 + #name
    else
      out[#out + 1] = ns.Colorize(emo(plain:sub(pos, at)), baseHex)
      pos = at + 1
    end
  end
  if pos <= #plain then out[#out + 1] = ns.Colorize(emo(plain:sub(pos)), baseHex) end
  return table.concat(out)
end

-- text (already cleaned) -> display string with base colour on the plain parts, @names in
-- class colour and real item links
function ns.RenderChatText(text, baseHex)
  text = text or ""
  local map, pids = { __sorted = {} }, {}
  if text:find("@", 1, true) then map, pids = mentionColors() end
  if not text:find("{i:", 1, true) then return colorMentions(text, baseHex, map, pids) end
  local out, pos = {}, 1
  for s, id, e in text:gmatch("(){i:(%d+)}()") do
    if s > pos then out[#out + 1] = colorMentions(text:sub(pos, s - 1), baseHex, map, pids) end
    local nid = tonumber(id)
    local name, q, link = itemInfo(nid)
    if type(link) == "string" and link:find("|Hitem:", 1, true) then
      -- the game's own link: the 12.x client redraws home-made item links as "(name)" / "(item 123)"
      out[#out + 1] = link
    else
      -- not loaded yet: plain text until GET_ITEM_INFO_RECEIVED redraws the chat
      out[#out + 1] = ns.Colorize("[loading item…]", ns.C.dim)
    end
    pos = e
  end
  if pos <= #text then out[#out + 1] = colorMentions(text:sub(pos), baseHex, map, pids) end
  return table.concat(out)
end

-- when the game finishes loading an item we were waiting for, redraw chat
local itemPending = false
ns:On("GET_ITEM_INFO_RECEIVED", function(id)
  if not itemWaiting[id] then return end
  itemWaiting[id] = nil
  if itemPending then return end
  itemPending = true
  C_Timer.After(0.3, function() itemPending = false ns:Fire("ITEMINFO") end)
end)

function ns.Clean(text, maxLen)
  if type(text) ~= "string" then return "" end
  text = text:gsub("[~|\r\n\t]", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if maxLen and #text > maxLen then text = text:sub(1, maxLen) end
  return text
end

function ns.Duration(sec)
  sec = math.max(0, math.floor(sec or 0))
  local d = math.floor(sec / 86400)
  local h = math.floor((sec % 86400) / 3600)
  local m = math.floor((sec % 3600) / 60)
  if d > 0 then return string.format("%dd %dh", d, h) end
  if h > 0 then return string.format("%dh %02dm", h, m) end
  return string.format("%dm", m)
end

function ns.Ago(t)
  if not t or t == 0 then return "never" end
  local s = ns.Now() - t
  if s < 60 then return "now" end
  if s < 3600 then return math.floor(s / 60) .. " min ago" end
  if s < 86400 then return math.floor(s / 3600) .. "h ago" end
  if s < 172800 then return "yesterday" end
  return math.floor(s / 86400) .. " days ago"
end

function ns.Money(copper)
  copper = math.floor(copper or 0)
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  if g > 0 then return string.format("%dg %02ds", g, s) end
  return string.format("%ds", s)
end

function ns.Clock(t)
  return date("%H:%M", t or ns.Now())
end

-- Monday 00:00 (local) of the week that t is in
function ns.MondayOf(t)
  local d = date("*t", t or ns.Now())
  local back = (d.wday + 5) % 7 -- Monday = 0
  return time({ year = d.year, month = d.month, day = d.day - back, hour = 0 })
end

-- "2026-45": year + Monday-based week number, taken from the Monday of that week, so a week that
-- crosses New Year stays one week (plain %W would split it into "2026-52" and "2027-00").
-- For every other week the key is identical to the old format.
local weekKeyMemo, weekKeyN = {}, 0
function ns.WeekKey(t)
  t = t or ns.Now()
  local day = date("%Y%m%d", t)
  local k = weekKeyMemo[day]
  if not k then
    k = date("%Y-%W", ns.MondayOf(t))
    if weekKeyN >= 60 then weekKeyMemo, weekKeyN = {}, 0 end
    weekKeyMemo[day] = k
    weekKeyN = weekKeyN + 1
  end
  return k
end

function ns.PrevWeekKey()
  return ns.WeekKey(ns.Now() - 7 * 86400)
end

local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"
function ns.RandomId(len)
  local out = {}
  for i = 1, (len or 8) do
    local n = math.random(1, 36)
    out[i] = B36:sub(n, n)
  end
  return table.concat(out)
end

-- Enkel, stabil hash av gjengkoden (brukes i kanalnavn og meldingshoder)
function ns.Hash(str)
  local h = 5381
  for i = 1, #str do
    h = (h * 33 + str:byte(i)) % 4294967296
  end
  local out = {}
  for i = 1, 6 do
    local n = h % 36
    out[i] = B36:sub(n + 1, n + 1)
    h = math.floor(h / 36)
  end
  return table.concat(out)
end

function ns.Split(str, sep)
  local out = {}
  local start = 1
  while true do
    local i = str:find(sep, start, true)
    if not i then
      out[#out + 1] = str:sub(start)
      break
    end
    out[#out + 1] = str:sub(start, i - 1)
    start = i + #sep
  end
  return out
end

-- Sammenlign versjoner: returnerer true hvis a er nyere enn b
function ns.NewerVersion(a, b)
  local function parts(v)
    local out = {}
    for n in tostring(v or ""):gmatch("%d+") do out[#out + 1] = tonumber(n) end
    return out
  end
  local pa, pb = parts(a), parts(b)
  for i = 1, math.max(#pa, #pb, 3) do
    local x, y = pa[i] or 0, pb[i] or 0
    if x ~= y then return x > y end
  end
  return false
end

function ns.Print(...)
  print("|cff" .. ns.C.accent .. "Chillan?|r", ...)
end

-- Chillan?s egne lyder (Media\Sounds). Nye lydfiler krever full omstart av spillet første
-- gang; finner ikke spillet fila ennå, spilles den vanlige Blizzard-lyden i stedet.
local CUSTOM_SOUNDS = { chat = "Chat", mention = "Mention", dead = "Dead", online = "Online", offline = "Offline" }
local FALLBACK = { chat = "notify", mention = "notify", online = "notify", offline = false }
local lastSoundAt = {}

function ns.Sound(kind, pid)
  if not (ns.db and ns.db.settings.sounds) then return end
  if ns:Silenced(pid, kind) then return end
  -- samme lyd maks hvert 1,5 sek (flere meldinger på rad = ett «pop»)
  local now = GetTime()
  if lastSoundAt[kind] and (now - lastSoundAt[kind]) < 1.5 then return end
  lastSoundAt[kind] = now
  local file = CUSTOM_SOUNDS[kind]
  if file and PlaySoundFile then
    local ok, willPlay = pcall(PlaySoundFile, ns.MEDIA .. "Sounds\\" .. file .. ".ogg", "Master")
    if ok and willPlay then return end
    if FALLBACK[kind] == false then return end
    kind = FALLBACK[kind] or kind
  end
  local kit = SOUNDKIT or {}
  local id
  if kind == "ding" then id = kit.UI_LEVELUP_GENERIC or 888
  elseif kind == "sos" then id = kit.RAID_WARNING or 8959
  elseif kind == "online" or kind == "notify" then id = kit.UI_CHAT_SOUND_NOTIFY or kit.TELL_MESSAGE or 3081
  elseif kind == "dead" then id = kit.UI_BATTLEGROUND_COUNTDOWN_FINISHED or kit.IG_QUEST_FAILED or 847
  else id = kit.IG_MAINMENU_OPTION_CHECKBOX_ON or 856 end
  pcall(PlaySound, id, "Master")
end

---------------------------------------------------------------------------
-- Database
---------------------------------------------------------------------------
local DEFAULTS = {
  version = 1,
  settings = {
    minibar = true, sounds = true, toasts = true, mapPins = true, mapPinsOffline = true, briefing = true, levelRecap = true,
    onlineToasts = true, lootMinQuality = 3, minimapButton = true, minimapAngle = 200,
    chatMirror = true, activityMirror = true, chatTab = true, eventFeed = true, feedChat = true, bgPanel = true,
    accent = "class", popupLevel = "normal", pulsePin = true, market = true, marketShare = true, theme = "graphite", overlayAlpha = 0.95, locked = false, questBuddy = true, layerHost = true, layerStrangers = false, mentionSound = true, chatSound = true, presenceSound = true, combatQueue = true,
    radar = true, titles = true, mapNotes = true, duraWarn = true,
    -- QoL tab: the safe ones start on, the ones that act for you start off
    qolMount = true, qolMountArmor = true, qolMountZone = true, qolSwimGear = true, qolRunGear = true, qolTrinketSlot = 14,
    qolRepair = true, qolGuildRepair = true, qolJunk = true, qolFastLoot = true,
    qolAutoQuest = false, qolSkipCine = true, qolXPText = true,
    qolNoDuels = false, qolNoGuildInv = false, qolSummon = false, qolRes = false, qolNoErrors = true, qolMaxZoom = false,
    qolTint = true, qolFlightTimer = true, qolRewardCoin = true,
    qolMountMsg = false, qolRepairMsg = true, qolJunkMsg = true, qolQuestTurnIn = true, qolQuestGossip = true,
    qolXPRested = true, qolXPQuests = true, qolDuelsGang = true, qolGuildGang = true, qolResBoss = true,
  },
  people = {}, roster = {}, feed = {}, chat = {}, mats = {}, polls = {}, events = {},
  enemies = {}, firsts = {}, announced = {},
}

local function fill(dst, src)
  for k, v in pairs(src) do
    if dst[k] == nil then
      if type(v) == "table" then dst[k] = {} fill(dst[k], v) else dst[k] = v end
    elseif type(v) == "table" and type(dst[k]) == "table" then
      fill(dst[k], v)
    end
  end
end

-- Saved-data migrations, numbered. Each runs once, in order, and ChillanDB.schema remembers the last one.
-- To change saved data: add the next number here (never edit an old one).
ns.MIGRATIONS = {
  -- 1: the loose flags from before 1.0 (0.12 class accent, 0.29.1 blue drops shared)
  [1] = function(db)
    if not db.migr012 and db.settings.accent == "grey" then db.settings.accent = "class" end
    if not db.migr0291 then db.settings.lootMinQuality = 3 end
    db.migr012, db.migr0291 = nil, nil
  end,
  -- 2 (1.0.0): settings for things that are gone (swim gear and the druid charm don't exist in Forever;
  -- SOS is retired)
  [2] = function(db)
    for _, k in ipairs({ "qolSwim", "qolDruidCharm", "tileSos" }) do db.settings[k] = nil end
    if type(db.settings.tiles) == "table" then
      for i = #db.settings.tiles, 1, -1 do
        if db.settings.tiles[i] == "act_sos" then table.remove(db.settings.tiles, i) end
      end
    end
  end,
  -- 3 (1.0.0): the enemy log becomes part of the Cunt List
  [3] = function(db)
    db.cunts = db.cunts or {}
    db.cuntsGone = db.cuntsGone or {}
    for key, e in pairs(db.enemies or {}) do
      local k = (e.name or key):lower()
      if type(e) == "table" and not db.cunts[k] and not db.cuntsGone[k] then
        db.cunts[k] = { name = e.name or key, reason = (e.note and e.note ~= "") and e.note or "From the enemy log",
          by = e.by or "", byChar = e.byChar or "", t = e.t or time(), notes = {} }
      end
    end
    db.enemies = {}
  end,
  -- 4 (1.0.1): the Cunt List is manual only. Entries that came in by themselves (deaths, the old
  -- enemy log) go; the Alliance players who killed us get their own "Died to" list instead.
  [4] = function(db)
    for k, e in pairs(db.cunts or {}) do
      if type(e) ~= "table" or ns.IsAutoCunt(e.reason) then db.cunts[k] = nil end
    end
    if ns.DiedTo then ns.DiedTo:Backfill() end
  end,
  -- 5 (1.1.0): Gang pulse – the bar, the four boxes, the Now card and the feed are one panel
  [5] = function(db)
    local S = db.settings
    S.minibar = true
    S.evDocked = true
    S.eventFeed = true
    S.evMin = nil
  end,
  -- 6 (1.1.1): Gang pulse slimmer by default
  [6] = function(db)
    local S = db.settings
    if not S.evDockW or S.evDockW > 300 then S.evDockW = 300 end
  end,
  -- 7 (1.1.2): the boxes and the Now card stay open in combat unless you unpin them
  [7] = function(db) db.settings.pulsePin = true end,
}

-- reasons only the old automatic enemy log wrote (a person adding someone always types a reason)
function ns.IsAutoCunt(reason)
  reason = tostring(reason or "")
  return reason == "" or reason == "From the enemy log" or reason == "Tagged as an enemy"
    or reason:lower():find("^killed me in") ~= nil
end

function ns:InitDB()
  ChillanDB = ChillanDB or {}
  fill(ChillanDB, DEFAULTS)
  if not ChillanDB.pid then ChillanDB.pid = ns.RandomId(8) end
  ns.db = ChillanDB
  ns.pid = ChillanDB.pid
  local v = ChillanDB.schema or 0
  while ns.MIGRATIONS[v + 1] do
    v = v + 1
    local ok, err = pcall(ns.MIGRATIONS[v], ChillanDB)
    if not ok and ns.debug then print("Chillan migration " .. v .. " failed:", err) end
    ChillanDB.schema = v
  end
  -- (1.4.66) the Discord link is gone: drop its outbox and settings
  ChillanDB.discord = nil
  if ChillanDB.settings and ChillanDB.settings.pos then ChillanDB.settings.pos.companioncard = nil end
  ns:ApplyAccent()
end

---------------------------------------------------------------------------
-- Aksentfarge (velges i Innstillinger, gjelder etter /reload)
---------------------------------------------------------------------------
ns.ACCENTS = {
  { key = "theme", name = "Theme", hex = nil },
  { key = "class", name = "Class colour", hex = nil },
  { key = "grey", name = "Grey", hex = "C8D1DC" },
  { key = "blue", name = "Blue", hex = "8FB8E8" },
  { key = "green", name = "Green", hex = "7FD6A0" },
  { key = "purple", name = "Purple", hex = "B9AEDB" },
  { key = "gold", name = "Gold", hex = "E0C068" },
  { key = "red", name = "Red", hex = "F2999B" },
  { key = "pink", name = "Pink", hex = "F0A8D0" },
  { key = "teal", name = "Teal", hex = "7ED6D1" },
}

-- Themes change the whole addon: background, cards, lines, text and the default accent
ns.THEMES = {
  { key = "graphite", name = "Graphite", desc = "Neutral grey",
    c = { backdrop = "0C0D0F", window = "17191C", card = "1D2024", cardHover = "22262B", line = "24282D", input = "202328",
      inputLine = "2A2E33", active = "2A2E33", activeLine = "3A3F45", text = "E8EAED", text2 = "C9CDD2", muted = "9BA1A8",
      dim = "858B92", accent = "C8D1DC", accentText = "121417" } },
  { key = "midnight", name = "Midnight", desc = "Near black, cool blue",
    c = { backdrop = "07090C", window = "0E1116", card = "161B23", cardHover = "1C222C", line = "1E2530", input = "141920",
      inputLine = "263040", active = "222A36", activeLine = "324054", text = "E6EDF6", text2 = "B9C4D2", muted = "8C99AB",
      dim = "6F7D90", accent = "8FB8E8", accentText = "0B1726" } },
  { key = "coal", name = "Coal", desc = "Pure black and gold",
    c = { backdrop = "000000", window = "050505", card = "121212", cardHover = "191919", line = "1C1C1C", input = "0E0E0E",
      inputLine = "262626", active = "202020", activeLine = "333333", text = "F2F2F2", text2 = "BDBDBD", muted = "8E8E8E",
      dim = "777777", accent = "E0C068", accentText = "2A1F05" } },
  { key = "slate", name = "Slate", desc = "Dark green-grey, teal",
    c = { backdrop = "0A0E0F", window = "14191A", card = "1B2324", cardHover = "212B2C", line = "253031", input = "182021",
      inputLine = "2C3839", active = "263233", activeLine = "36494A", text = "E3EEEC", text2 = "B5C7C5", muted = "8AA19F",
      dim = "6E8583", accent = "7ED6D1", accentText = "062523" } },
  { key = "horde", name = "Horde", desc = "Dark wine, muted red",
    c = { backdrop = "0D0A0C", window = "171316", card = "211A1E", cardHover = "281F24", line = "2E2429", input = "1D171A",
      inputLine = "352A30", active = "2E242A", activeLine = "46363E", text = "F0E6EA", text2 = "C8B9BF", muted = "9F8D94",
      dim = "87767D", accent = "F2999B", accentText = "3A0F12" } },
  { key = "void", name = "Void", desc = "Deep purple-black",
    c = { backdrop = "0A0910", window = "13121A", card = "1B1A25", cardHover = "22202E", line = "262433", input = "18171F",
      inputLine = "2E2B3D", active = "28263A", activeLine = "3B3852", text = "ECEAF6", text2 = "BDB9D0", muted = "9591AB",
      dim = "7B7792", accent = "B9AEDB", accentText = "1E1838" } },
}

function ns.Theme(key)
  for _, t in ipairs(ns.THEMES) do if t.key == key then return t end end
  return ns.THEMES[1]
end

local function lighten(h, f)
  local r, g, b = tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)
  local function l(v) return math.min(255, math.floor(v + (255 - v) * f)) end
  return string.format("%02X%02X%02X", l(r), l(g), l(b))
end
ns.Lighten = lighten

function ns.AccentHex(key, themeKey)
  if key == "theme" then return ns.Theme(themeKey or (ns.db and ns.db.settings.theme)).c.accent end
  if key == "class" then
    local _, class = UnitClass("player")
    return CLASS_HEX[class or ""] or "C8D1DC"
  end
  for _, a in ipairs(ns.ACCENTS) do
    if a.key == key and a.hex then return a.hex end
  end
  return "C8D1DC"
end

-- Apply theme + accent to ns.C (before any UI is built; changing them needs a /reload)
function ns:ApplyAccent()
  local S = ns.db.settings
  local theme = ns.Theme(S.theme)
  for k, v in pairs(theme.c) do ns.C[k] = v end
  ns.C.silver = "C8D1DC"
  local h = ns.AccentHex(S.accent or "class")
  ns.C.accent = h
  ns.C.accentHover = lighten(h, 0.35)
  ns.C.activeHover = lighten(ns.C.active, 0.06)
  -- (1.4.64) the Market's look, from each theme's own colours: panels, title strips, borders,
  -- striped rows and button edges
  ns.C.panel = ns.C.card
  ns.C.strip = lighten(ns.C.card, 0.035)
  ns.C.border = ns.C.activeLine
  ns.C.rowAlt = lighten(ns.C.window, 0.02)
  ns.C.btnLine = lighten(ns.C.activeLine, 0.16)
  ns.C.field = ns.C.backdrop
  if ns.UI and ns.UI.RebuildStyles then ns.UI.RebuildStyles() end
  if ns.Overlays and ns.Overlays.KIND then
    ns.Overlays.KIND.join.color = h
    ns.Overlays.KIND.info.color = h
  end
end

-- "Chillan?" med spørsmålstegnet i aksentfarge
function ns.Logo()
  return "Chillan|cff" .. ns.C.accent .. "?|r"
end

---------------------------------------------------------------------------
-- @navn i gjengchatten
---------------------------------------------------------------------------
local function lowerTrim(s) return (s or ""):lower():gsub("^%s+", ""):gsub("%s+$", "") end

function ns.MyMentionNames()
  local names = {}
  if ns.db.alias and ns.db.alias ~= "" then
    names[#names + 1] = lowerTrim(ns.db.alias)
    local first = ns.db.alias:match("^([%w\128-\255]+)")
    if first and #first >= 3 then names[#names + 1] = lowerTrim(first) end
  end
  local me = ns.db.people[ns.pid]
  for _, c in pairs(me and me.chars or {}) do
    if c.name then
      names[#names + 1] = lowerTrim(c.name)
      local first = c.name:match("^(%S+)")
      if first and #first >= 3 then names[#names + 1] = lowerTrim(first) end
    end
  end
  return names
end

-- Nevner teksten meg? (@alias, @karakternavn, @fornavn eller @alle)
function ns.MentionsMe(text)
  local t = (text or ""):lower()
  if not t:find("@", 1, true) then return false end
  if t:find("@alle", 1, true) or t:find("@all%f[%W]") or t:sub(-4) == "@all" then return true end
  for _, n in ipairs(ns.MyMentionNames()) do
    if n ~= "" then
      local s, e = t:find("@" .. n, 1, true)
      if s then
        local nextc = t:sub(e + 1, e + 1)
        if nextc == "" or not nextc:match("[%w]") then return true end
      end
    end
  end
  return false
end

function ns:SetCode(code)
  code = ns.Clean(code or "", 24):upper()
  if code == "" then return false end
  ns.db.code = code
  ns.codeHash = ns.Hash(code)
  ns:Fire("CODE_CHANGED")
  ns:MarkDirty()
  return true
end

function ns:NewCode()
  return "CHILL-" .. ns.RandomId(4):upper()
end

-- Person-poster
function ns:GetPerson(pid, create)
  if not pid then return nil end
  local p = ns.db.people[pid]
  if not p and create then
    p = { chars = {}, stats = {}, live = {}, profs = {}, recipes = {} }
    ns.db.people[pid] = p
  end
  if p then p.pid = pid end
  return p
end

function ns:IsOnline(p)
  if not p then return false end
  if p == ns:GetPerson(ns.pid) then return true end
  local t = ns.Now()
  if p.heard and (t - p.heard) < 120 then return true end
  -- (1.4.48) in a battleground or dungeon the game blocks most addon messages, so we hear nobody:
  -- whoever was online when we went in counts as online until 2 minutes after we come out
  local blind = ns.commBlindSince
  if blind and p.heard and p.heard >= blind - 120 and not (p.byeAt and p.byeAt >= p.heard)
    and (not ns.commBlindUntil or t < ns.commBlindUntil) then return true end
  -- nettopp logget ut: ikke la «noen andre hører ham» holde ham online
  if p.byeAt and (t - p.byeAt) < 90 then return false end
  -- noen andre i gjengen hører ham (f.eks. han er på en annen layer/server enn oss)
  return p.via and (t - p.via) < 100 or false
end

function ns:PersonChar(p)
  if not p then return nil end
  return p.main and p.chars[p.main] or nil
end

-- Fullt karakternavn (begge navnene) på personens aktive karakter
function ns:PersonName(p)
  if not p then return "?" end
  local c = ns:PersonChar(p)
  return c and c.name or "?"
end

-- Kortnavn (= hele karakternavnet) for lister og varsler
function ns:PersonFirst(p)
  return ns:PersonAlias(p) or ns:PersonName(p)
end

-- IRL-navnet personen har skrevet inn (gjelder alle karakterene deres)
function ns:PersonAlias(p)
  if not p then return nil end
  if p == ns.db.people[ns.pid] then return ns.db.alias end
  return (p.alias and p.alias ~= "") and p.alias or nil
end

-- Kort navn til hendelsesfeeden: IRL-navnet i klassefarge (eller karakternavnet)
function ns:ShortWho(p, char)
  local c = (char and p and p.chars and p.chars[char]) or ns:PersonChar(p) or {}
  local name = ns:PersonAlias(p) or c.name or (char and ns.ShortName(char)) or "?"
  return ns.Colorize(name, ns.ClassHex(c.class))
end

-- "Lil Warrior" i klassefarge + " (Henrik)" dempet
function ns:PersonLabel(p, char)
  local c = (char and p and p.chars and p.chars[char]) or ns:PersonChar(p) or {}
  local name = ns.Colorize(c.name or (char and ns.ShortName(char)) or "?", ns.ClassHex(c.class))
  local alias = ns:PersonAlias(p)
  if alias then name = name .. ns.Colorize(" (" .. alias .. ")", "9BA1A8") end
  return name
end

-- Gjør et navn hoverbart (personkort) og klikkbart (spillersiden / shift = fest kortet)
function ns:PersonLinked(p, text)
  if p and p.pid then return "|Hchillan:" .. tostring(p.pid) .. "|h" .. text .. "|h" end
  return text
end

function ns:PersonMaxLevel(p)
  local lvl = 0
  for _, c in pairs(p.chars or {}) do
    if (c.level or 0) > lvl then lvl = c.level end
  end
  return lvl
end

function ns:PersonPlayed(p)
  local sum = 0
  for _, c in pairs(p.chars or {}) do sum = sum + (c.played or 0) end
  return sum
end

function ns:PersonAltCount(p)
  local n = 0
  for _ in pairs(p.chars or {}) do n = n + 1 end
  return math.max(0, n - 1)
end

-- Ukestall som faktisk gjelder denne uka
function ns:WeekStat(p, key)
  local s = p.stats or {}
  if s.wk ~= ns.WeekKey() then return 0 end
  return s["w" .. key] or 0
end
function ns:TotalStat(p, key)
  return (p.stats or {})["t" .. key] or 0
end

-- (1.1.7) the same friend twice: a second PC or a fresh install gets a new id, so one person can show up
-- as two (same name typed in, "Simon"). Only one is shown – the one online, else the one furthest
-- along, else the one seen last. Your own other installs are hidden too.
function ns:HiddenDuplicates()
  local groups, hidden = {}, {}
  for pid, p in pairs(ns.db.people or {}) do
    local a = p.main and ns:PersonAlias(p)
    if a then
      a = a:lower()
      groups[a] = groups[a] or {}
      table.insert(groups[a], pid)
    end
  end
  for _, list in pairs(groups) do
    if #list > 1 then
      local best
      for _, pid in ipairs(list) do
        if pid == ns.pid then best = pid break end
      end
      if not best then
        table.sort(list, function(x, y)
          local px, py = ns.db.people[x], ns.db.people[y]
          local ox, oy = ns:IsOnline(px) and 1 or 0, ns:IsOnline(py) and 1 or 0
          if ox ~= oy then return ox > oy end
          local mx, my = ns.db.muted and ns.db.muted[x] and 1 or 0, ns.db.muted and ns.db.muted[y] and 1 or 0
          if mx ~= my then return mx < my end
          local lx, ly = ns:PersonMaxLevel(px), ns:PersonMaxLevel(py)
          if lx ~= ly then return lx > ly end
          return (px.lastSeen or 0) > (py.lastSeen or 0)
        end)
        best = list[1]
      end
      for _, pid in ipairs(list) do if pid ~= best then hidden[pid] = best end end
    end
  end
  return hidden
end

-- "1 death", "3 deaths"
function ns.Plural(n, one, many)
  n = n or 0
  return n .. " " .. (n == 1 and one or (many or (one .. "s")))
end

-- (1.1.9) one person, all installs: the shown entry plus the hidden duplicates with the same name
function ns:LinkedPids(p)
  local pid = p and p.pid
  if not pid then
    for k, v in pairs(ns.db.people or {}) do if v == p then pid = k break end end
  end
  local out = { pid }
  for hid, best in pairs(ns:HiddenDuplicates()) do if best == pid then out[#out + 1] = hid end end
  return out
end
-- every character of that person: { full, ch, pid }, highest level first
function ns:AllChars(p)
  local out, seen = {}, {}
  for _, pid in ipairs(ns:LinkedPids(p)) do
    local q = ns.db.people[pid]
    for full, ch in pairs(q and q.chars or {}) do
      if not seen[full] then seen[full] = true out[#out + 1] = { full = full, ch = ch, pid = pid } end
    end
  end
  table.sort(out, function(a, b) return (a.ch.level or 0) > (b.ch.level or 0) end)
  return out
end

function ns:SortedPeople(filter)
  local out = {}
  local hidden = ns:HiddenDuplicates()
  for pid, p in pairs(ns.db.people) do
    if p.main and not hidden[pid] and (not filter or filter(p, pid)) then
      p.pid = pid
      out[#out + 1] = p
    end
  end
  return out
end

-- A list kept short (oldest dropped first)
function ns.PushCapped(list, item, cap)
  list[#list + 1] = item
  while #list > cap do table.remove(list, 1) end
end

-- Insert into a list kept sorted by .t (oldest first), without re-sorting the whole list
function ns.InsertByTime(list, item, cap)
  local t, i = item.t or 0, #list
  while i > 0 and (list[i].t or 0) > t do i = i - 1 end
  table.insert(list, i + 1, item)
  while cap and #list > cap do table.remove(list, 1) end
end

---------------------------------------------------------------------------
-- Shared helpers (ns.U): one copy of the small things several files need
---------------------------------------------------------------------------
local U = {}
ns.U = U
function U.Secret(v) return ns.isSecret(v) end
-- in combat by the game's lockdown or by the player's combat flag
function U.InCombat()
  if InCombatLockdown and InCombatLockdown() then return true end
  return ns.S(UnitAffectingCombat, "player") and true or false
end
function U.Settings() return ns.db and ns.db.settings or {} end
-- a character name made comparable: no realm, no case, no spaces or hyphens ("Lil Warrior-Realm" -> "lilwarrior")
function U.NormName(name)
  if type(name) ~= "string" or ns.isSecret(name) then return "" end
  return (ns.ShortName(name) or name):lower():gsub("[%s%-]", "")
end
-- is this character one of the gang's (someone else's, not mine)?
function U.IsGangChar(name)
  local short = U.NormName(name)
  if short == "" or not ns.db then return false end
  for pid, p in pairs(ns.db.people or {}) do
    if pid ~= ns.pid then
      for key, c in pairs(p.chars or {}) do
        if U.NormName((c and c.name) or key) == short then return true end
      end
    end
  end
  return false
end
-- gold with coin icons when the game can draw them, else "12g 3s 4c"
function U.Money(copper)
  copper = copper or 0
  if GetCoinTextureString then
    local ok, s = pcall(GetCoinTextureString, copper)
    if ok and s then return s end
  end
  return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

---------------------------------------------------------------------------
-- Status
---------------------------------------------------------------------------
ns.STATUS = {
  QUEST = { label = "Questing", color = "5FD18B" },
  DUNGEON = { label = "In a dungeon", color = "C8D1DC" },
  BG = { label = "In a battleground", color = "C8D1DC" },
  AFK = { label = "AFK", color = "E0B04F" },
  LFG = { label = "Looking for group", color = "B9AEDB" },
  HELP = { label = "Needs help", color = "F2777A" },
  DND = { label = "Do not disturb", color = "9BA1A8" },
  OFFLINE = { label = "Offline", color = "858B92" },
}
ns.MANUAL_STATUS = { "AUTO", "LFG", "HELP", "DND" }

-- "a {c}" -> "an Undead Rogue" / "a Night Elf Hunter"
-- which dings are worth a popup (and a Discord card): 10, 15 and every level from 20
function ns.DingPopup(level)
  level = tonumber(level)
  return level ~= nil and (level == 10 or level == 15 or level >= 20)
end

function ns.Article(line, word)
  return (line:gsub("(%f[%a][aA]) {c}", function(a)
    return a .. (word:match("^[AEIOUaeiou]") and "n" or "") .. " " .. word
  end))
end

-- (1.4.48) when we can't hear the gang (inside an instance), and the grace after coming out
local function blindCheck()
  local ok, inInst = pcall(IsInInstance)
  local inside = ok and inInst == true
  if inside then
    if not ns.commBlindSince then ns.commBlindSince = ns.Now() end
    ns.commBlindUntil = nil
  elseif ns.commBlindSince and not ns.commBlindUntil then
    ns.commBlindUntil = ns.Now() + 120
  elseif ns.commBlindUntil and ns.Now() >= ns.commBlindUntil then
    ns.commBlindSince, ns.commBlindUntil = nil, nil
  end
end
ns.CommBlind = function() return ns.commBlindSince ~= nil and ns.commBlindUntil == nil end
ns:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(2, blindCheck) end)
C_Timer.NewTicker(30, blindCheck)

-- (1.4.48) "Paused in BG": inside an instance the game blocks addon messages, so instead of
-- "0 online" the headers say the gang sync is paused (nil when it isn't)
-- (1.4.58) short faction names for boxes and lines (the full name stays in tooltips)
local SHORT_FACTION = {
  ["Frostwolf Clan"] = "Frostwolf", ["Stormpike Guard"] = "Stormpike", ["Darkspear Raiders"] = "Darkspear",
  ["Theramore Expeditionary Force"] = "Theramore", ["The Defilers"] = "Defilers", ["The League of Arathor"] = "League",
  ["Warsong Outriders"] = "Warsong", ["Silverwing Sentinels"] = "Silverwing", ["Thorium Brotherhood"] = "Thorium",
  ["Timbermaw Hold"] = "Timbermaw", ["Cenarion Circle"] = "Cenarion", ["Zandalar Tribe"] = "Zandalar",
  ["Brood of Nozdormu"] = "Nozdormu", ["Hydraxian Waterlords"] = "Hydraxian", ["Argent Dawn"] = "Argent Dawn",
  ["Thunder Bluff"] = "Thunder Bluff", ["Darkspear Trolls"] = "Darkspear Trolls",
}
function ns.ShortFaction(name)
  if type(name) ~= "string" then return name end
  if SHORT_FACTION[name] then return SHORT_FACTION[name] end
  local s = name:gsub("^The ", ""):gsub(" Clan$", ""):gsub(" Guard$", "")
  return s
end

function ns.PausedLabel()
  if not ns.CommBlind() then return nil end
  return ns.InBattleground() and "PvP mode · social paused" or "Paused in dungeon"
end
ns.PAUSED_TIP = "The game blocks addon messages inside battlegrounds and dungeons, so gang chat, online status and sharing pause here. Everything syncs again when you leave."
