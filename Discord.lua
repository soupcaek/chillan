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
local CELL = 3            -- physical pixels per code cell (2 blurred on some screens)
local ROWS = 16           -- data rows per column (2 bytes)
local MAX_BYTES = 560     -- payload limit per strip
local SHOW_FOR = 0.7      -- seconds a strip stays on screen
local GAP = 0.25          -- pause between two strips
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

function X:Enabled() return db().on == true end

local function outbox(e)
  local d = db()
  local s = json(e)
  for _, old in ipairs(d.out) do if old.id == e.id then return end end
  d.out[#d.out + 1] = { id = e.id, t = e.t, j = s }
  while #d.out > OUTBOX_MAX do table.remove(d.out, 1) end
end

---------------------------------------------------------------------------
-- the code strip
-- Layout (cells): quiet zone of black around everything; row 0 and row 17 are white borders on
-- every column; column 0 is all white, columns 1–2 are fixed sync patterns (0xAAAA, 0x5555),
-- column 3 holds the payload length, then 2 payload bytes per column, then the CRC column.
-- Bits: top row of the 16 = most significant bit of the first byte of that column.
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
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints()
  f.bg:SetColorTexture(0, 0, 0, 1)
  f:Hide()
  return f
end

local function cellTex()
  used = used + 1
  local t = pool[used]
  if not t then
    t = strip:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(1, 1, 1, 1)
    pool[used] = t
  end
  t:Show()
  return t
end

-- columns of 16-bit values -> textures (vertical runs of white merged into one texture)
local function draw(cols)
  strip = strip or makeStrip()
  local _, physH = physSize()
  strip:SetScale(768 / physH) -- 1 unit = 1 physical pixel (parent scale ignored)
  for i = 1, used do pool[i]:Hide() end
  used = 0
  local quiet = 2
  local ncols = #cols
  local wCells, hCells = ncols + quiet * 2, ROWS + 2 + quiet * 2
  strip:SetSize(wCells * CELL, hCells * CELL)
  local physW = physSize()
  strip:ClearAllPoints()
  strip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", math.floor((physW - wCells * CELL) / 2), 0)
  for ci, v in ipairs(cols) do
    local x = (quiet + ci - 1) * CELL
    -- rows: 0 border, 1..16 bits (MSB first), 17 border
    local bits = { 1 }
    for r = 15, 0, -1 do bits[#bits + 1] = math.floor(v / 2 ^ r) % 2 end
    bits[#bits + 1] = 1
    local r = 1
    while r <= #bits do
      if bits[r] == 1 then
        local s = r
        while r + 1 <= #bits and bits[r + 1] == 1 do r = r + 1 end
        local t = cellTex()
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", strip, "TOPLEFT", x, -((quiet + s - 1) * CELL))
        t:SetSize(CELL, (r - s + 1) * CELL)
      end
      r = r + 1
    end
  end
  strip:Show()
end

-- payload string -> list of 16-bit column values
function X:Encode(s)
  local bytes = { s:byte(1, -1) }
  local cols = { 0xFFFF, 0xAAAA, 0x5555, #bytes }
  for i = 1, #bytes, 2 do cols[#cols + 1] = bytes[i] * 256 + (bytes[i + 1] or 0) end
  cols[#cols + 1] = crc16(bytes)
  return cols
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

function X:Send(e, live, hold)
  if not e then return end
  if not X:Enabled() then return end
  outbox(e)
  if live ~= false then flash(e, hold) end
end

---------------------------------------------------------------------------
-- wiring
---------------------------------------------------------------------------
local lastStatus, lastStatusAt = nil, 0

function X:PushStatus(force)
  if not X:Enabled() then return end
  local st = X:Status()
  local sig = json(st.g)
  if not force and sig == lastStatus and ns.Now() - lastStatusAt < 600 then return end
  lastStatus, lastStatusAt = sig, ns.Now()
  db().status = json(st)
  flash(st)
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
  if X:Enabled() then
    local st = X:Status()
    db().status = json(st)
  end
end)

-- /chill discord [on|off|test|flush]
function X:Slash(rest)
  rest = (rest or ""):lower()
  local d = db()
  if rest == "on" then
    d.on = true
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
    ns.Print("Test strip sent: it stays at the top of the screen for 8 seconds. The companion should count it, and Discord should get a test card.")
  elseif rest == "flush" then
    ns.Print("Saving now so the companion picks up everything in the outbox…")
    C_Timer.After(0.5, function() ReloadUI() end)
  else
    ns.Print("Discord relay is " .. (d.on and "|cff9BE08Aon|r" or "off") .. ". Outbox: " .. #d.out
      .. " events. Commands: /chill discord on | off | test | flush")
  end
end
