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
    if not ok and ns.debug then print("|cffF2777AChillan feil|r", event, err) end
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
    if not ok and ns.debug then print("|cffF2777AChillan feil|r", name, err) end
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
  if d > 0 then return string.format("%d d %d t", d, h) end
  if h > 0 then return string.format("%d t %02d m", h, m) end
  return string.format("%d m", m)
end

function ns.Ago(t)
  if not t or t == 0 then return "aldri" end
  local s = ns.Now() - t
  if s < 60 then return "nå" end
  if s < 3600 then return math.floor(s / 60) .. " min siden" end
  if s < 86400 then return math.floor(s / 3600) .. " t siden" end
  if s < 172800 then return "i går" end
  return math.floor(s / 86400) .. " dager siden"
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

function ns.WeekKey(t)
  return date("%Y-%W", t or ns.Now())
end

function ns.PrevWeekKey()
  return date("%Y-%W", ns.Now() - 7 * 86400)
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

function ns.Sound(kind)
  if not (ns.db and ns.db.settings.sounds) then return end
  local kit = SOUNDKIT or {}
  local id
  if kind == "ding" then id = kit.UI_LEVELUP_GENERIC or 888
  elseif kind == "sos" then id = kit.RAID_WARNING or 8959
  elseif kind == "online" then id = kit.UI_CHAT_SOUND_NOTIFY or kit.TELL_MESSAGE or 3081
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
    minibar = true, sounds = true, toasts = true, mapPins = true,
    onlineToasts = true, lootMinQuality = 4, minimapButton = true, minimapAngle = 200,
    chatMirror = true, activityMirror = true, chatTab = true, eventFeed = true, feedChat = true,
    accent = "grey", locked = false, questBuddy = true, mentionSound = true, combatQueue = true,
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
  ns:ApplyAccent()
end

---------------------------------------------------------------------------
-- Aksentfarge (velges i Innstillinger, gjelder etter /reload)
---------------------------------------------------------------------------
ns.ACCENTS = {
  { key = "grey", name = "Grå", hex = "C8D1DC" },
  { key = "blue", name = "Blå", hex = "8FB8E8" },
  { key = "green", name = "Grønn", hex = "7FD6A0" },
  { key = "purple", name = "Lilla", hex = "B9AEDB" },
  { key = "gold", name = "Gull", hex = "E0C068" },
  { key = "red", name = "Rød", hex = "F2999B" },
  { key = "pink", name = "Rosa", hex = "F0A8D0" },
  { key = "teal", name = "Turkis", hex = "7ED6D1" },
  { key = "class", name = "Klassefarge", hex = nil },
}

local function lighten(h, f)
  local r, g, b = tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)
  local function l(v) return math.min(255, math.floor(v + (255 - v) * f)) end
  return string.format("%02X%02X%02X", l(r), l(g), l(b))
end

function ns.AccentHex(key)
  for _, a in ipairs(ns.ACCENTS) do
    if a.key == key then
      if a.hex then return a.hex end
      local _, class = UnitClass("player")
      return CLASS_HEX[class or ""] or "C8D1DC"
    end
  end
  return "C8D1DC"
end

function ns:ApplyAccent()
  local h = ns.AccentHex(ns.db.settings.accent or "grey")
  ns.C.accent = h
  ns.C.accentHover = lighten(h, 0.35)
  if ns.UI and ns.UI.STYLES then
    ns.UI.STYLES.primary.fill = h
    ns.UI.STYLES.primary.hover = ns.C.accentHover
  end
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
  if t:find("@alle", 1, true) or t:find("@all%f[%W]") then return true end
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
  if p.heard and (t - p.heard) < 100 then return true end
  -- noen andre i gjengen hører ham (f.eks. han er på en annen layer enn oss)
  return p.via and (t - p.via) < 80 or false
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
  return ns:PersonName(p)
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
  DUNGEON = { label = "I dungeon", color = "C8D1DC" },
  BG = { label = "I battleground", color = "C8D1DC" },
  AFK = { label = "AFK", color = "E0B04F" },
  LFG = { label = "Ledig for gruppe", color = "B9AEDB" },
  HELP = { label = "Trenger hjelp", color = "F2777A" },
  DND = { label = "Ikke forstyrr", color = "9BA1A8" },
  OFFLINE = { label = "Offline", color = "858B92" },
}
ns.MANUAL_STATUS = { "AUTO", "LFG", "HELP", "DND" }
