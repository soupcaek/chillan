-- Chillan? – Discord relay
-- Addons can't reach the internet, so this hands events to the Chillan companion (a small Windows
-- program) two ways:
--   1. live: a short black-and-white code strip flashed at the top edge of the screen, which the
--      companion reads from the WoW window (only when /chill discord is on, i.e. on the PC running it)
--   2. backup: an outbox in the saved data, which the game writes on /reload, logout and exit
-- The companion forwards both to Discord; the bot removes duplicates.
local ADDON, ns = ...

local X = {}
ns.Discord = X

local STRIP_VERSION = 1
local CELL_W, CELL_H = 2, 3  -- physical pixels per code cell
local LEVELS = { 0, 24, 48, 72 } -- the four dark shades per colour channel (0-255)
local MAX_BYTES = 560     -- payload limit per strip
local SHOW_FOR = 0.4      -- seconds a strip stays on screen
local GAP = 0.15          -- pause between two strips
local OUTBOX_MAX = 400
local STATUS_EVERY = 60

---------------------------------------------------------------------------
-- tiny JSON encoder (strings, numbers, booleans, arrays, objects)
---------------------------------------------------------------------------
local function jstr(s)
  s = tostring(s)
  s = s:gsub('[%c"\\]', function(ch)
    if ch == '"' then return '\\"' elseif ch == "\\" then return "\\\\"
    elseif ch == "\n" then return "\\n" else return string.format("\\u%04x", ch:byte()) end
  end)
  return '"' .. s .. '"'
end

local function isArray(t)
  local n = 0
  for k in pairs(t) do
    if type(k) ~= "number" then return false end
    n = n + 1
  end
  return n == #t
end

local function json(v)
  local tv = type(v)
  if tv == "string" then return jstr(v)
  elseif tv == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "0" end
    if v == math.floor(v) then return string.format("%d", v) end
    return string.format("%.3f", v)
  elseif tv == "boolean" then return v and "true" or "false"
  elseif tv == "table" then
    local out = {}
    if isArray(v) then
      for i = 1, #v do out[i] = json(v[i]) end
      return "[" .. table.concat(out, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do out[#out + 1] = jstr(k) .. ":" .. json(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
  end
  return "null"
end
X.json = json

-- colour codes, textures and links out: Discord gets plain text
local function plain(s)
  if type(s) ~= "string" then return s end
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", "")
  s = s:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h(.-)|h", "%1")
  s = s:gsub("|", "")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
X.plain = plain

---------------------------------------------------------------------------
-- CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF), no bit library needed
---------------------------------------------------------------------------
local function xor16(a, b)
  local r, bitv = 0, 1
  for _ = 1, 16 do
    local x, y = a % 2, b % 2
    if x ~= y then r = r + bitv end
    a, b, bitv = (a - x) / 2, (b - y) / 2, bitv * 2
  end
  return r
end

local function crc16(bytes)
  local crc = 0xFFFF
  for i = 1, #bytes do
    crc = xor16(crc, bytes[i] * 256)
    for _ = 1, 8 do
      if crc >= 0x8000 then
        crc = xor16((crc * 2) % 0x10000, 0x1021)
      else
        crc = (crc * 2) % 0x10000
      end
    end
  end
  return crc
end
X.crc16 = crc16

---------------------------------------------------------------------------
-- building the events
---------------------------------------------------------------------------
local function personInfo(pid, char)
  local p = ns:GetPerson(pid) or {}
  local c = (char and p.chars and p.chars[char]) or ns:PersonChar(p) or {}
  return {
    p = pid,
    n = plain(ns:PersonAlias(p) or c.name or (char and ns.ShortName(char)) or "?"),
    ch = c.name or (char and ns.ShortName(char)) or "",
    cl = c.class or "",
    l = c.level or 0,
  }
end

local function base(kind, item)
  local e = personInfo(item.pid, item.char)
  e.v, e.k, e.id, e.t = STRIP_VERSION, kind, tostring(item.id), item.t or ns.Now()
  return e
end

-- returns an event table for a feed item, or nil when Discord doesn't want it
function X:FromItem(item)
  if type(item) ~= "table" or not item.id then return nil end
  local k = item.kind
  if k == "DEAD" then
    local e = base("DEAD", item)
    e.z = plain(item.a or "")
    e.kc = item.c ~= "" and plain(item.c) or nil
    e.kx = item.d ~= "" and plain(item.d) or nil
    local cat = type(item.b) == "string" and item.b:match("^([%u_]+):")
    e.cat = cat
    local line = ns.Deaths and ns.Deaths:Line(item, e.n, "FFFFFF")
    e.tx = line and plain(line) or (e.n .. " died in " .. (e.z ~= "" and e.z or "?") .. ".")
    e.kick = ns.Deaths and ns.Deaths.Kicker and plain(ns.Deaths:Kicker(item)) or nil
    return e
  elseif k == "KILL" then
    local e = base("KILL", item)
    e.z = plain(item.a or "")
    e.vi = plain(item.c or "")
    e.vx = item.d ~= "" and plain(item.d) or nil
    e.cat = type(item.b) == "string" and item.b:match("^([%u_]+):") or "KILL"
    local line = ns.Kills and ns.Kills:Line(item, e.n, "FFFFFF")
    e.tx = line and plain(line) or (e.n .. " killed " .. tostring(e.vi) .. ".")
    e.kick = ns.Kills and plain(ns.Kills:Kicker(item)) or nil
    return e
  elseif k == "CUNT" then
    local e = base("CUNT", item)
    e.vi = plain(item.a or "")
    e.rs = plain(item.b or "")
    return e
  elseif k == "DING" then
    local e = base("DING", item)
    e.l = tonumber(item.a) or e.l
    e.pl = tonumber(item.b)
    e.first = item.first and true or nil
    e.place = item.place
    return e
  elseif k == "LOOT" then
    local q = tonumber(item.b) or 0
    if q < 3 then return nil end
    local e = base("LOOT", item)
    e.i, e.q = tonumber(item.a), q
    local name = e.i and C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(e.i)
    if name and not ns.isSecret(name) then e.nm = name end
    e.first = item.first and true or nil
    return e
  elseif k == "ACH" then
    local e = base("ACH", item)
    local d = ns.Ach and ns.Ach.byId[item.a]
    local tier = d and ns.Ach.TIERS[d.tier]
    e.an = d and d.name or tostring(item.a)
    e.ad = d and d.desc and plain(d.desc) or nil
    e.at = tier and tier.name or nil
    return e
  elseif k == "DUNGEON" then
    local e = base("DUNGEON", item)
    e.dg = plain(item.a or "")
    e.dur = tonumber(item.b)
    e.dd = tonumber(item.c) or 0
    e.bo = tonumber(((item.d or ""):match("^(%d+)")))
    local names = {}
    if ns.Extras and ns.Extras.RunMembers then
      local ok, members = pcall(ns.Extras.RunMembers, ns.Extras, item)
      if ok and type(members) == "table" then
        for _, mp in ipairs(members) do
          local c = ns:PersonChar(mp) or {}
          names[#names + 1] = plain(ns:PersonAlias(mp) or c.name or "?")
        end
      end
    end
    if #names > 1 then e.with = names end
    return e
  end
end

-- someone else was in on a kill that's already in the feed: tell the bot, it adds the name
function X:SendMerge(item, pid, char)
  local e = personInfo(pid, char)
  e.v, e.k, e.t = STRIP_VERSION, "KILL", ns.Now()
  e.id = tostring(item.id) .. "+" .. tostring(pid)
  e.vi, e.z, e.merge = plain(item.c or ""), plain(item.a or ""), 1
  X:Send(e)
end

-- own level recap (only the dinging player has it)
function X:FromRecap(x)
  if type(x) ~= "table" then return nil end
  local me = ns:GetPerson(ns.pid) or {}
  local e = personInfo(ns.pid, me.main)
  e.v, e.k, e.t = STRIP_VERSION, "RECAP", ns.Now()
  e.id = "R" .. tostring(ns.pid) .. ":" .. tostring(x.to)
  e.fr, e.l = x.from, x.to
  e.time, e.xph, e.de, e.al = x.time, x.xph, x.deaths, x.alli
  e.ki, e.mo, e.qu = x.kills, x.money, x.quests
  e.tm, e.tmn = x.topMob, x.topMobN
  if x.rank then e.rk, e.rof = x.rank.place, x.rank.of end
  if x.loot and x.loot.id then e.li, e.lq = x.loot.id, x.loot.q end
  return e
end

-- the whole gang, for /gang and the live status message
function X:Status()
  local g = {}
  for pid, p in pairs(ns.db.people or {}) do
    local c = ns:PersonChar(p)
    if c and c.name then
      local L = p.live or {}
      g[#g + 1] = {
        plain(ns:PersonAlias(p) or c.name), c.name, c.class or "", c.level or 0,
        plain(L.zone or ""), ns:IsOnline(p) and 1 or 0, pid,
      }
    end
  end
  table.sort(g, function(a, b) return a[1] < b[1] end)
  return { v = STRIP_VERSION, k = "STATUS", id = "S" .. tostring(ns.Now()), t = ns.Now(), g = g }
end

---------------------------------------------------------------------------
-- outbox (saved data) – the companion reads it at reload/logout
---------------------------------------------------------------------------
local function db()
  ns.db.discord = ns.db.discord or {}
  local d = ns.db.discord
  d.out = d.out or {}
  return d
end

-- live: flash code lines for the companion (only the PC that turned it on)
function X:Enabled() return db().on == true end
-- relaying: keep an outbox in the saved data (anyone who has the gang's relay link)
function X:Relaying() return db().on == true or (type(db().link) == "string" and db().link ~= "") end

local function outbox(e)
  local d = db()
  local s = json(e)
  for _, old in ipairs(d.out) do if old.id == e.id then return end end
  d.out[#d.out + 1] = { id = e.id, t = e.t, j = s }
  while #d.out > OUTBOX_MAX do table.remove(d.out, 1) end
end

---------------------------------------------------------------------------
-- the code line ("stealth strip")
-- One row of cells, CELL_W x CELL_H physical pixels each, at the very top-left of the screen.
-- Each cell's R, G and B are one of four dark shades, so a cell carries 6 bits.
-- Cells 1-4: marker (bright, dark, bright, dark), cells 5-8: calibration (shade 0,1,2,3 on all
-- channels), then the bytes [length hi, length lo, payload…, crc hi, crc lo] as a bit stream,
-- 6 bits per cell in R(2) G(2) B(2) order, most significant bit first.
---------------------------------------------------------------------------
local strip, pool, used = nil, {}, 0
local queue, busy = {}, false

local function physSize()
  local w, h
  if GetPhysicalScreenSize then w, h = GetPhysicalScreenSize() end
  if not w or not h or ns.isSecret(w) or w <= 0 then w, h = 1920, 1080 end
  return w, h
end

local function makeStrip()
  local f = CreateFrame("Frame", "ChillanDiscordStrip", UIParent)
  f:SetFrameStrata("TOOLTIP")
  f:SetFrameLevel(9999)
  if f.SetIgnoreParentScale then f:SetIgnoreParentScale(true) end
  f:Hide()
  return f
end

local function cellTex(i)
  local t = pool[i]
  if not t then
    t = strip:CreateTexture(nil, "ARTWORK")
    pool[i] = t
  end
  t:Show()
  return t
end

-- payload string -> list of cells {r, g, b} as shade indexes 0-3
function X:Encode(s)
  local bytes = { s:byte(1, -1) }
  local n = #bytes
  local crc = crc16(bytes)
  local stream = { math.floor(n / 256), n % 256 }
  for i = 1, n do stream[#stream + 1] = bytes[i] end
  stream[#stream + 1] = math.floor(crc / 256)
  stream[#stream + 1] = crc % 256
  local bits = {}
  for _, b in ipairs(stream) do
    for k = 7, 0, -1 do bits[#bits + 1] = math.floor(b / 2 ^ k) % 2 end
  end
  while #bits % 6 ~= 0 do bits[#bits + 1] = 0 end
  local cells = { { 3, 3, 3 }, { 0, 0, 0 }, { 3, 3, 3 }, { 0, 0, 0 }, { 0, 0, 0 }, { 1, 1, 1 }, { 2, 2, 2 }, { 3, 3, 3 } }
  for i = 1, #bits, 6 do
    cells[#cells + 1] = { bits[i] * 2 + bits[i + 1], bits[i + 2] * 2 + bits[i + 3], bits[i + 4] * 2 + bits[i + 5] }
  end
  return cells
end

local function draw(cells)
  strip = strip or makeStrip()
  local _, physH = physSize()
  strip:SetScale(768 / physH) -- 1 unit = 1 physical pixel (parent scale ignored)
  for i = 1, used do pool[i]:Hide() end
  used = #cells
  strip:SetSize(#cells * CELL_W, CELL_H)
  strip:ClearAllPoints()
  strip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
  for i, c in ipairs(cells) do
    local t = cellTex(i)
    t:SetColorTexture(LEVELS[c[1] + 1] / 255, LEVELS[c[2] + 1] / 255, LEVELS[c[3] + 1] / 255, 1)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", strip, "TOPLEFT", (i - 1) * CELL_W, 0)
    t:SetSize(CELL_W, CELL_H)
  end
  strip:Show()
end

local function nextStrip()
  if busy then return end
  local s = table.remove(queue, 1)
  if not s then return end
  busy = true
  draw(X:Encode(s.text))
  C_Timer.After(s.hold or SHOW_FOR, function()
    if strip then strip:Hide() end
    C_Timer.After(GAP, function()
      busy = false
      nextStrip()
    end)
  end)
end

-- shorten an event until it fits one strip
local function fit(e)
  local s = json(e)
  if #s <= MAX_BYTES then return s end
  for _, k in ipairs({ "ad", "kx", "with", "kick", "tx" }) do
    if e[k] then
      e[k] = nil
      s = json(e)
      if #s <= MAX_BYTES then return s end
    end
  end
  if e.g then
    while #s > MAX_BYTES and #e.g > 0 do
      table.remove(e.g)
      s = json(e)
    end
  end
  return #s <= MAX_BYTES and s or nil
end

local function flash(e, hold)
  if not X:Enabled() then return end
  local s = fit(e)
  if not s then return end
  queue[#queue + 1] = { text = s, hold = hold }
  if #queue > 30 then table.remove(queue, 1) end
  nextStrip()
end

-- someone came off the Cunt List: tell the bot (no post, /cunts leaves them out)
function X:SendUncunt(name)
  local e = personInfo(ns.pid, ns.Comm:MyFull())
  e.v, e.k, e.id, e.t = STRIP_VERSION, "UNCUNT", ns.Comm:NewId(), ns.Now()
  e.vi = plain(name or "")
  self:Send(e, false)
end

function X:Send(e, live, hold)
  if not e then return end
  if not X:Relaying() then return end
  outbox(e)
  if live ~= false and X:Enabled() then flash(e, hold) end
end

---------------------------------------------------------------------------
-- wiring
---------------------------------------------------------------------------
local lastStatus, lastStatusAt = nil, 0

function X:PushStatus(force)
  if not X:Relaying() then return end
  local st = X:Status()
  local key = {}
  for _, r in ipairs(st.g) do key[#key + 1] = r[1] .. ":" .. r[4] .. ":" .. r[6] end
  local sig = table.concat(key, ",")
  db().status = json(st)
  if not force and (sig == lastStatus or ns.Now() - lastStatusAt < 300) then return end
  lastStatus, lastStatusAt = sig, ns.Now()
  if X:Enabled() then flash(st) end
end

ns:Listen("FEEDEVENT", function(_, item)
  if not item then return end
  local ok, e = pcall(X.FromItem, X, item)
  if ok and e then X:Send(e) end
end)

ns:Listen("LEVEL_RECAP", function(x)
  local ok, e = pcall(X.FromRecap, X, x)
  if ok and e then X:Send(e) end
end)

C_Timer.NewTicker(STATUS_EVERY, function() X:PushStatus(false) end)

-- the game writes saved data just after this: make sure the status is current
ns:On("PLAYER_LOGOUT", function()
  if X:Relaying() then
    local st = X:Status()
    db().status = json(st)
  end
end)

---------------------------------------------------------------------------
-- catch-up: what the gang did while this PC wasn't relaying (synced in at login)
---------------------------------------------------------------------------
local RELAYED = { DEAD = true, DING = true, LOOT = true, ACH = true, DUNGEON = true, KILL = true, CUNT = true }
local CATCHUP_MAX = 40

function X:CatchUp()
  if not X:Relaying() then return 0 end
  local d = db()
  if not d.since then d.since = ns.Now() return 0 end
  local done = {}
  for _, o in ipairs(d.out) do done[o.id] = true end
  local todo = {}
  for _, it in ipairs(ns.db.feed or {}) do
    -- fresh events go out live through FEEDEVENT; this is for the ones synced in afterwards
    if RELAYED[it.kind] and it.t and it.t > d.since and ns.Now() - it.t > 120 and not done[tostring(it.id)] then
      todo[#todo + 1] = it
    end
  end
  table.sort(todo, function(a, b) return a.t < b.t end)
  while #todo > CATCHUP_MAX do table.remove(todo, 1) end
  local n = 0
  for _, it in ipairs(todo) do
    local ok, e = pcall(X.FromItem, X, it)
    if ok and e then
      e.cu = 1
      X:Send(e, true, 0.35)
      n = n + 1
    else
      -- remember it anyway so it isn't checked again
      d.out[#d.out + 1] = { id = tostring(it.id), t = it.t, j = "" }
    end
  end
  return n
end

ns:On("PLAYER_LOGIN", function()
  local d = db()
  if X:Relaying() and not d.since then d.since = ns.Now() end
  -- pass the relay link on to gang members who don't have the newest one
  C_Timer.After(45, function() X:ShareLink() end)
  -- give the history sync time to bring in what happened while we were away
  C_Timer.After(90, function() X:CatchUp() end)
  C_Timer.After(240, function() X:CatchUp() end)
end)

---------------------------------------------------------------------------
-- the gang's relay link (a Discord webhook into the hidden raw channel)
-- set once by whoever owns the Discord side, then shared in game with everyone,
-- so every companion can pick it up from its own Chillan data with no setup
---------------------------------------------------------------------------
local LINK_PREFIX = "^https://discord%.com/api/webhooks/%d+/[%w_%-]+$"

function X:ShareLink()
  local d = db()
  if not (d.link and d.linkVer) or not ns.Comm then return end
  ns.Comm:Broadcast(ns.Comm:Build("DW", d.linkVer, d.link), 3)
end

-- someone just came online: hand them the link directly (they missed the login broadcast)
local sentTo = {}
function X:ShareLinkTo(target)
  local d = db()
  if not (d.link and d.linkVer and target) or not (ns.Comm and ns.Comm.SendTo) then return end
  if sentTo[target] and ns.Now() - sentTo[target] < 600 then return end
  sentTo[target] = ns.Now()
  C_Timer.After(3 + math.random() * 5, function()
    ns.Comm:SendTo(target, ns.Comm:Build("DW", d.linkVer, d.link), 3)
  end)
end

local function takeLink(ver, url)
  local d = db()
  ver = tonumber(ver)
  if not ver or type(url) ~= "string" then return end
  if url ~= "" and not url:match(LINK_PREFIX) then return end
  if d.linkVer and ver <= d.linkVer then return end
  local had = d.link
  d.link, d.linkVer = (url ~= "" and url or nil), ver
  if not d.since and d.link then d.since = ns.Now() end
  if d.link and not had then
    ns.Print("The gang's Discord feed is set up. To help post to it, run the Chillan companion once: "
      .. "|cffE0C068Interface\\AddOns\\Chillan\\Companion\\ChillanCompanion.exe|r in your WoW folder. It never looks at your screen.")
    ns:Fire("DISCORD_LINK")
  end
end

if ns.Comm and ns.Comm.Handle then
  ns.Comm:Handle("DW", function(f) takeLink(f[1], f[2]) end)
end

-- /chill discord [on|off|test|flush]
function X:Slash(rest)
  X.rawArg = rest or ""
  rest = (rest or ""):lower()
  local d = db()
  if rest == "on" then
    d.on = true
    d.since = d.since or ns.Now()
    ns.Print("Discord relay |cff9BE08Aon|r. Keep the Chillan companion running on this PC. Events flash as a small code strip at the top of the screen.")
    C_Timer.After(1, function() X:PushStatus(true) end)
  elseif rest == "off" then
    d.on = false
    queue = {}
    if strip then strip:Hide() end
    ns.Print("Discord relay off.")
  elseif rest == "test" then
    if not d.on then ns.Print("Turn it on first: /chill discord on") return end
    local me = ns:GetPerson(ns.pid) or {}
    local e = personInfo(ns.pid, me.main)
    e.v, e.k, e.id, e.t = STRIP_VERSION, "TEST", "T" .. tostring(ns.Now()), ns.Now()
    e.tx = "Test from Chillan? Bjørn Stian says hi. æøå ÆØÅ"
    X:Send(e, true, 8)
    ns.Print("Test sent: a thin dark line sits at the very top-left of the screen for 8 seconds. The companion should count it, and Discord should get a test card.")
  elseif rest:match("^link") then
    local url = rest:match("^link%s+(%S+)")
    -- slash text is lower-cased above; webhook tokens are case-sensitive, so take the raw text
    if url then url = (X.rawArg or ""):match("(https://%S+)") end
    if url == nil and rest:match("^link%s+clear") then
      d.link, d.linkVer = nil, ns.Now()
      ns.Comm:Broadcast(ns.Comm:Build("DW", d.linkVer, ""), 3)
      ns.Print("Relay link removed for the whole gang.")
    elseif url then
      if not url:match(LINK_PREFIX) then ns.Print("That doesn't look like a Discord webhook link.") return end
      d.link, d.linkVer = url, ns.Now()
      d.since = d.since or ns.Now()
      X:ShareLink()
      ns.Print("Relay link saved and shared with the gang. Everyone's Chillan now keeps events for the Discord feed.")
    else
      ns.Print("Relay link: " .. (d.link and ("set (…" .. d.link:sub(-6) .. ")") or "not set") .. ". Set it with /chill discord link <webhook>.")
    end
  elseif rest == "flush" then
    ns.Print("Saving now so the companion picks up everything in the outbox…")
    C_Timer.After(0.5, function() ReloadUI() end)
  else
    ns.Print("Live relay on this PC: " .. (d.on and "|cff9BE08Aon|r" or "off") .. ". Saving events for Discord: "
      .. (X:Relaying() and "yes" or "no") .. ". Outbox: " .. #d.out .. " events. Commands: /chill discord on | off | test | flush | link <webhook>")
  end
end
