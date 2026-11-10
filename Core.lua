-- Chillan? – kjerne: navnerom, database, hendelser og hjelpefunksjoner
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
function ns:Fire(name, ...)
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
  return name, quality
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
    if alias and alias ~= "" then map[alias:lower()] = col pids[alias:lower()] = pid end
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
    -- try "two words", then "one word" after the @
    local two = plain:match("^@(%S+ %S+)", at)
    local one = plain:match("^@(%S+)", at)
    local name, col
    if two and map[two:lower():gsub("[%p]+$", "")] then
      name = two:gsub("[%p]+$", "") col = map[name:lower()]
    elseif one and map[one:lower():gsub("[%p]+$", "")] then
      name = one:gsub("[%p]+$", "") col = map[name:lower()]
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
  local map, pids = {}, {}
  if text:find("@", 1, true) then map, pids = mentionColors() end
  if not text:find("{i:", 1, true) then return colorMentions(text, baseHex, map, pids) end
  local out, pos = {}, 1
  for s, id, e in text:gmatch("(){i:(%d+)}()") do
    if s > pos then out[#out + 1] = colorMentions(text:sub(pos, s - 1), baseHex, map, pids) end
    local nid = tonumber(id)
    local name, q = itemInfo(nid)
    local hexq = (ns.QUALITY_HEX and ns.QUALITY_HEX[q or 1]) or "FFFFFF"
    out[#out + 1] = "|Hitem:" .. id .. "|h" .. ns.Colorize("[" .. (name or "loading…") .. "]", name and hexq or ns.C.dim) .. "|h"
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
  if not t or t == 0 then return "aldri" end
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

function ns.Sound(kind)
  if not (ns.db and ns.db.settings.sounds) then return end
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
    minibar = true, sounds = true, toasts = true, mapPins = true, mapPinsOffline = true, briefing = true,
    onlineToasts = true, lootMinQuality = 4, minimapButton = true, minimapAngle = 200,
    chatMirror = true, activityMirror = true, chatTab = true, eventFeed = true, feedChat = true,
    accent = "class", theme = "graphite", overlayAlpha = 0.95, locked = false, questBuddy = true, mentionSound = true, chatSound = true, presenceSound = true, combatQueue = true,
    radar = true, titles = true, mapNotes = true, duraWarn = true,
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

function ns:InitDB()
  ChillanDB = ChillanDB or {}
  fill(ChillanDB, DEFAULTS)
  if not ChillanDB.pid then ChillanDB.pid = ns.RandomId(8) end
  ns.db = ChillanDB
  ns.pid = ChillanDB.pid
  -- 0.12: class colour is the new default accent (grey was the old default)
  if not ChillanDB.migr012 then
    if ChillanDB.settings.accent == "grey" then ChillanDB.settings.accent = "class" end
    ChillanDB.migr012 = true
  end
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
  if ns.db.alias and ns.db.alias ~= "" then names[#names + 1] = lowerTrim(ns.db.alias) end
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

function ns:SortedPeople(filter)
  local out = {}
  for pid, p in pairs(ns.db.people) do
    if p.main and (not filter or filter(p, pid)) then
      p.pid = pid
      out[#out + 1] = p
    end
  end
  return out
end

-- Liste som holdes kort
function ns.PushCapped(list, item, cap)
  list[#list + 1] = item
  while #list > cap do table.remove(list, 1) end
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
