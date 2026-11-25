-- Chillan? – the four fixed boxes under the bar (1.1.0: Gang pulse). Each mode has its own four:
-- open world, dungeon, battleground. They never move, so your eyes know where to look.
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

local T = {}
ns.Tiles = T

local MAX = 4
local PER_ROW = 4
local W, H, GAP = 70, 40, 0   -- cards sit flush under the bar, sharing its background

local function me() return ns:GetPerson(ns.pid, true) end
local function s3() return ns.Tracker:S3Data() end
local function today(key) return ((ns.db.cnt or {})[key] or {})[date("%Y-%m-%d")] or 0 end

local startMoney, startHK
local function hk()
  if not GetPVPLifetimeStats then return nil end
  local ok, v = pcall(GetPVPLifetimeStats)
  if ok and type(v) == "number" and not ns.isSecret(v) then return v end
end

local function goldText(copper)
  if not copper then return "–" end
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  if g > 0 then return ns.Num(g) .. "g " .. s .. "s" end
  return s .. "s " .. (copper % 100) .. "c"
end

local function minDurability()
  if not GetInventoryItemDurability then return nil end
  local low
  for slot = 1, 18 do
    local ok, cur, max = pcall(GetInventoryItemDurability, slot)
    if ok and cur and max and max > 0 and not ns.isSecret(cur) then
      local pct = cur / max * 100
      if not low or pct < low then low = pct end
    end
  end
  return low
end

local function freeBags()
  local free, total = 0, 0
  local api = C_Container
  for bag = 0, 4 do
    local ok1, f = pcall(api and api.GetContainerNumFreeSlots or GetContainerNumFreeSlots, bag)
    local ok2, n = pcall(api and api.GetContainerNumSlots or GetContainerNumSlots, bag)
    if ok1 and type(f) == "number" then free = free + f end
    if ok2 and type(n) == "number" then total = total + n end
  end
  return free, total
end

-- Alle rubrikkene: key, navn i menyen, funksjon som gir verdi + undertekst (+ ev. farge)
T.DEFS = {
  { key = "level", name = "Level and % to next", get = function()
    local d, c = s3(), ns.Tracker:MyChar() or {}
    local pct = ns.Pct(d.xp, d.xpMax)
    return tostring(c.level or "?"), pct and (pct .. " % to next") or "level"
  end },
  { key = "xph", name = "XP per hour", get = function()
    local rate, label = ns.St:XPRate(me())
    return rate and ns.Num(rate) or "–", "XP/h"
  end },
  { key = "eta", name = "Time to next level", get = function()
    local eta = ns.St:ETA(me())
    return eta and ns.Duration(eta) or "–", "to next level"
  end },
  { key = "lvltime", name = "Time on this level", get = function()
    local t = ns.Tracker:TimeThisLevel()
    local c = ns.Tracker:MyChar() or {}
    local sub = "this level"
    if c.prevLevelTime and c.prevLevelTime > 0 then sub = "last: " .. ns.Duration(c.prevLevelTime) end
    return t and ns.Duration(t) or "–", sub
  end },
  { key = "gold", name = "Gold (+/− this session)", get = function()
    local m = ns.S(GetMoney)
    if type(m) ~= "number" then return "–", "gold" end
    startMoney = startMoney or m
    local diff = m - startMoney
    local sub = diff == 0 and "gold" or ((diff > 0 and "+" or "−") .. goldText(math.abs(diff)) .. " this session")
    return goldText(m), sub, diff > 0 and C.green or diff < 0 and C.red or nil
  end },
  { key = "rested", name = "Rested XP", get = function()
    local d = s3()
    local pct = ns.Pct(d.rested or 0, d.xpMax)
    return pct and (pct .. " %") or "–", "rested of a level"
  end },
  { key = "session", name = "Session time", get = function()
    return ns.Duration(s3().sessSec or 0), "this session"
  end },
  { key = "today", name = "Online today", get = function()
    return ns.Duration(s3().today or 0), "online today"
  end },
  { key = "played", name = "Total playtime", get = function()
    local p = ns:PersonPlayed(me())
    return p > 0 and ns.Duration(p) or "–", "/played"
  end },
  { key = "quests", name = "Quests today", get = function()
    return tostring(today("questsDay")), "quests today"
  end },
  { key = "kills", name = "Kills (session / week)", get = function()
    local now = hk()
    startHK = startHK or now
    local sess = (now and startHK) and (now - startHK) or 0
    return tostring(sess), "kills this session · " .. ns:WeekStat(me(), "Kills") .. " this week"
  end },
  { key = "deaths", name = "Deaths today", get = function()
    local n = today("deathsDay")
    return tostring(n), "deaths today", n > 0 and C.red or nil
  end },
  { key = "ilvl", name = "Item level", get = function()
    local v = s3().ilvl
    return v and tostring(math.floor(v)) or "–", "item level"
  end },
  { key = "dura", name = "Durability", get = function()
    local low = ns.Durability()
    if not low then return "–", "durability" end
    local col = low < 20 and C.red or low < 50 and C.amber or nil
    return math.floor(low) .. " %", "lowest item", col
  end },
  { key = "bags", name = "Free bag space", get = function()
    local free, total = freeBags()
    return tostring(free), "free of " .. total, free <= 3 and C.red or free <= 8 and C.amber or nil
  end },
  { key = "ach", name = "Achievement points", get = function()
    return tostring(ns.Ach and ns.Ach:Points(ns.pid) or 0), "achievement points"
  end },
  { key = "streak", name = "Streak", get = function()
    local n = s3().streak or 0
    return n .. (n == 1 and " day" or " days"), "in a row"
  end },
}
-- Gang pulse boxes (1.1.0)
local function P() return ns.Pulse end
local function dur(sec) return sec and ns.Duration(sec) or "–" end
for _, d in ipairs({
  -- (1.4.17) level 60 boxes
  { key = "honor60", name = "Honor today (+ bosses today)", get = function()
    local hk, honor = P():HonorToday()
    local pve = P().PvEDay()
    -- every other 8 s, bosses and runs today, once there are any
    if pve.bosses > 0 and math.floor(GetTime() / 8) % 2 == 1 then
      return tostring(pve.bosses), (pve.bosses == 1 and "boss" or "bosses") .. " · " .. ns.Plural(pve.runs, "run")
    end
    if not honor and not hk then return "–", "honor today" end
    return ns.Num(honor or 0), "honor" .. (hk and (" · " .. hk .. " HKs") or "")
  end },
  { key = "reph", name = "Reputation per hour", tipFn = function()
    -- (1.4.59) which faction, how much and how fast
    local fac, n, rate = P():TopRep()
    if not fac then return "Reputation", "No reputation gained this session yet." end
    return fac, "+" .. ns.Num(n) .. " this session" .. (rate and (" · " .. ns.Num(rate) .. " per hour") or "") .. "\nClick: the Stats page"
  end, get = function()
    local fac, n, rate = P():TopRep()
    if not fac then return "–", "rep/h" end
    -- (1.4.58) the big card already shows this faction and its rate: the box gives the total instead
    local wf = P().WatchedRep and P().WatchedRep()
    if wf and wf.name == fac then return "+" .. ns.Num(n), "rep this session" end
    local short = ns.ShortFaction(fac)
    if #short > 11 then short = short:sub(1, 10) .. "…" end
    return rate and ns.Num(rate) or ("+" .. ns.Num(n)), short .. (rate and " /h" or "")
  end },
  { key = "goldday", name = "Gold today (net)", get = function()
    local g = P().GoldDay()
    if not g or g == 0 then return "–", "gold today" end
    local gh = P():GoldPerHour()
    return (g < 0 and "−" or "+") .. goldText(math.abs(g)),
      (gh and gh > 0) and (goldText(gh) .. "/h") or "today", g < 0 and C.red or nil
  end },
  { key = "goldh", name = "Gold per hour", get = function()
    local g = P():GoldPerHour()
    if not g or g == 0 then return "–", "gold/h" end
    return (g < 0 and "−" or "") .. goldText(math.abs(g)), "gold/h", g < 0 and C.red or nil
  end },
  { key = "bosses", name = "Bosses this run", get = function()
    local r = P():Run()
    return r and tostring(r.bosses or 0) or "0", (r and r.bosses == 1) and "boss" or "bosses"
  end },
  { key = "runtime", name = "Run time", get = function()
    local r = P():Run()
    return dur(r and (ns.Now() - r.start)), "run time"
  end },
  { key = "runxp", name = "XP this run", get = function()
    local _, pr = P():Run()
    return pr and ns.Num(pr.xp) or "0", "XP this run"
  end },
  { key = "honorh", name = "Honor per hour", get = function()
    local h = P():HonorPerHour()
    return h and ns.Num(h) or "–", "honor/h"
  end },
  -- (1.4.48) honor this game: the session count, the honor messages and the scoreboard, the most of them
  { key = "bghonor", name = "Honor this battleground", get = function()
    local b = P().bg
    if not b then return "+0", "honor this game" end
    local _, h = P():BGNumbers()
    h = math.max(h or 0, b.honorChat or 0, (b.me and b.me.honor) or 0)
    return "+" .. ns.Num(h), "honor this game"
  end },
  { key = "bghk", name = "Kills this battleground", get = function()
    local k = P():BGNumbers()
    return k and tostring(k) or "–", "HKs this BG"
  end },
  { key = "bgtime", name = "Time in this battleground", get = function()
    return dur(P().bg and (ns.Now() - P().bg.start)), "in this BG"
  end },
  -- (1.4.34) battleground reputation: wins left to Exalted (time in the BG when there is none)
  { key = "bgrep", name = "Wins to Exalted (battleground reputation)", get = function()
    local r = P():BGRep()
    if not r then return "–", "rep" end
    if r.exalted then return "Exalted", r.short end
    -- (1.4.49) this game's rep gain is in the card's tooltip, not here
    local sub = "to Exalted"
    if not r.winsLeft then return r.standing, r.short .. ((r.game and r.game > 0) and (" · +" .. ns.Num(r.game)) or "") end
    return (r.estimated and "~" or "") .. r.winsLeft .. (r.winsLeft == 1 and " win" or " wins"), sub
  end },
  { key = "bgwon", name = "Battlegrounds won today", get = function()
    local d = P().Today()
    return d.won .. " / " .. d.played, "won today"
  end },
  -- (1.4.0) dungeons, raids and battlegrounds
  { key = "bossesx", name = "Bosses x / y", tip = "Hover: the bosses here, the ones you've killed struck through", get = function()
    local r = P():Run()
    if not r then return "–", "bosses" end
    local n, total = ns.Bosses:Count(r.name, r.killed)
    return n .. " / " .. (total or "?"), "bosses"
  end, hover = function(owner) T:BossList(owner) end },
  { key = "lootval", name = "Loot value this run", get = function()
    local _, pr = P():Run()
    local v = P():LootValue(pr)
    return v > 0 and goldText(v) or "–", "loot value"
  end },
  { key = "wipes", name = "Wipes this raid", get = function()
    local r = P():Run()
    local w = r and r.wipes or 0
    return tostring(w), w == 1 and "wipe" or "wipes", w > 0 and C.amber or nil
  end },
  { key = "repair", name = "Repair so far", get = function()
    local cost = T.RepairCost()
    if cost and cost > 0 then return goldText(cost), "repair so far" end
    local low = ns.Durability and ns.Durability()
    return low and (math.floor(low) .. " %") or "–", "durability", (low and low < 30) and C.red or nil
  end },
  -- (1.4.51) the first battleground tile: reputation gained this game (the score is in the BG panel)
  { key = "bgrepgame", name = "Reputation this battleground", get = function()
    local r = P():BGRep()
    if not r then return "–", "rep this game" end
    return "+" .. ns.Num(r.game or 0), "rep this game"
  end },
  { key = "bgscore", name = "Battleground score", get = function()
    return P():BGScore() or "–", "score"
  end },
}) do T.DEFS[#T.DEFS + 1] = d end

-- what repairing your gear would cost now (from the item tooltips; nil when the game won't say)
function T.RepairCost()
  if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then return nil end
  local sum, any = 0, false
  for slot = 1, 18 do
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
    local c = ok and type(data) == "table" and data.repairCost
    if type(c) == "number" and not ns.isSecret(c) then sum = sum + c any = true end
  end
  return any and sum or nil
end

-- (1.4.0) hover list for "3 / 8 bosses": every boss here, killed ones struck through with the time
-- the kill took. A small frame of its own (a game tooltip can't strike text through).
function T:BossList(owner)
  local r = ns.Pulse:Run()
  local f = self.bossFrame
  if not f then
    f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("TOOLTIP")
    f.panel = UI.Panel(f, "101113", "3A3F45")
    f.panel:SetAllPoints()
    -- (1.4.2) text goes on a layer above the panel (the panel is its own frame and hid the text)
    f.c = CreateFrame("Frame", nil, f)
    f.c:SetAllPoints()
    f.c:SetFrameLevel(f.panel:GetFrameLevel() + 2)
    f.title = UI.Text(f.c, 12, "bold", C.text)
    f.title:SetPoint("TOPLEFT", 10, -8)
    f.rows = {}
    self.bossFrame = f
  end
  for _, row in ipairs(f.rows) do row.text:Hide() row.time:Hide() row.line:Hide() end
  if not r then f:Hide() return end
  local list, wing, known, wings = ns.Bosses:For(r.name, r.killed, true)
  f.title:SetText(r.name .. (wing and (" · " .. wing) or ""))
  local y, w = -26, 180
  local function row(i, label, killed, secs, color)
    local rw = f.rows[i]
    if not rw then
      rw = {}
      rw.text = UI.Text(f.c, 11, nil, C.text2)
      rw.time = UI.Text(f.c, 10, nil, C.dim)
      rw.line = f.c:CreateTexture(nil, "OVERLAY")
      rw.line:SetHeight(1)
      f.rows[i] = rw
    end
    rw.text:ClearAllPoints() rw.time:ClearAllPoints() rw.line:ClearAllPoints()
    rw.text:SetPoint("TOPLEFT", 10, y)
    rw.text:SetText(label)
    rw.text:SetTextColor(hex(color or (killed and "6E747B" or C.text)))
    rw.text:Show()
    if killed then
      local tw = rw.text:GetStringWidth() or 60
      rw.line:SetPoint("LEFT", rw.text, "LEFT", -1, 0)
      rw.line:SetWidth(tw + 2)
      rw.line:SetColorTexture(0.6, 0.62, 0.65, 0.9)
      rw.line:Show()
      if secs then
        rw.time:SetPoint("LEFT", rw.text, "RIGHT", 8, 0)
        rw.time:SetText(secs >= 60 and string.format("%d:%02d", math.floor(secs / 60), secs % 60) or (secs .. " s"))
        rw.time:Show()
      end
    end
    -- (1.4.15) the gang's record for this boss
    local rec = r and ns.Bosses.BossRecord and ns.Bosses:BossRecord(r.name, (label:gsub("^› ", ""):gsub("^%s+", "")))
    if rec and not (wings and label:sub(1, 2) ~= "  ") then
      local p = rec.pid and ns:GetPerson(rec.pid)
      local best = string.format("best %d:%02d", math.floor(rec.s / 60), rec.s % 60) .. (p and (" " .. ns:PersonFirst(p)) or "")
      if killed and secs and secs <= rec.s then best = "gang record!" end
      rw.time:ClearAllPoints()
      rw.time:SetPoint("LEFT", rw.text, "RIGHT", 8, 0)
      rw.time:SetText(((killed and secs) and (rw.time:GetText() .. "  ·  ") or "") .. best)
      rw.time:Show()
    end
    w = math.max(w, (rw.text:GetStringWidth() or 0) + (rw.time:IsShown() and (rw.time:GetStringWidth() or 0) or 0) + 30)
    y = y - 15
  end
  local i = 0
  if wings then
    -- a dungeon with wings and no kill yet: list each wing
    for _, wg in ipairs(wings) do
      i = i + 1 row(i, wg.name, false, nil, C.accent)
      for _, b in ipairs(wg.list) do i = i + 1 row(i, "  " .. (b:match("^[^|]+")), false) end
    end
  else
    local nextShown = false
    for _, b in ipairs(list) do
      i = i + 1
      local isNext = not b.killed and not b.opt and not nextShown
      if isNext then nextShown = true end
      if b.opt and not b.killed then
        row(i, b.name .. " (optional)", false, nil, C.dim)
      else
        row(i, (isNext and "› " or "") .. b.name, b.killed, b.secs, isNext and C.accent or nil)
      end
    end
    if #list == 0 then i = i + 1 row(i, "No boss killed here yet – the list fills in as you go", false, nil, C.dim) end
    if not known and #list > 0 then i = i + 1 row(i, "More may come – learned from the gang's kills", false, nil, C.dim) end
    i = i + 1 row(i, "Struck through = killed (with the time it took) · › = next", false, nil, C.dim)
  end
  f:SetSize(math.min(320, w), -y + 6)
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
  f:Show()
end
T.MODE_TILES = {
  world = { "act_layer", "xph", "goldh", "eta" },
  dungeon = { "bossesx", "runtime", "runxp", "lootval" },
  raid = { "bossesx", "runtime", "wipes", "repair" },
  -- (1.4.48) HKs and deaths are on the card's big line, so not here too
  bg = { "bgrepgame", "bghonor", "bgrep", "bgtime" },
  -- (1.4.17) open world at level 60: no XP to chase, so honor, rep, gold and bosses instead
  world60 = { "act_layer", "honor60", "reph", "goldday" },
}

-- action buttons: same size as the stat tiles, a coloured edge and an icon; left-click does it
T.ACTIONS = {
  { key = "act_layer", name = "Layer hop", icon = "Radar", color = "7FB8FF",
    tip = "Left-click: move to another layer (a LayerSwap host or a gang member on another layer invites you)",
    get = function()
      if ns.LayerHop and ns.LayerHop.TileState then
        local v, sub, col = ns.LayerHop:TileState()
        if sub and #sub > 18 then sub = "click to hop" end   -- the box is narrow; the tooltip says more
        return v, sub, col
      end
      return "Layer hop", "Click to hop"
    end,
    click = function() ns.LayerHop:Request() end },
  { key = "act_stats", name = "Open Stats", icon = "Board", color = "C8D1DC",
    tip = "Left-click: open the Stats page",
    get = function() return "Stats", "Open the board" end,
    click = function() ns.Window:Toggle("stats") end },
  { key = "act_trophies", name = "Open Trophies", icon = "Trophy", color = "E0C068",
    tip = "Left-click: open the Trophies page",
    get = function()
      local pts = ns.Ach and ns.Ach.Points and select(2, pcall(ns.Ach.Points, ns.Ach, ns.pid))
      return "Trophies", type(pts) == "number" and (ns.Num(pts) .. " points") or "Open your trophies"
    end,
    click = function() ns.Window:Toggle("ach") end },
}
T.byKey = {}
for _, d in ipairs(T.DEFS) do T.byKey[d.key] = d end
for _, d in ipairs(T.ACTIONS) do d.action = true T.byKey[d.key] = d end

function T:List()
  local mode = ns.Pulse and ns.Pulse:Mode() or "world"
  if mode == "world" and ns.Pulse.AtMax and ns.Pulse.AtMax() then mode = "world60" end
  return self.MODE_TILES[mode] or self.MODE_TILES.world
end

function T:IsPinned(key)
  for _, k in ipairs(self:List()) do if k == key then return true end end
  return false
end

function T:Toggle(key)
  local list = self:List()
  for i, k in ipairs(list) do
    if k == key then table.remove(list, i) self:Layout() return false end
  end
  if #list >= MAX then
    ns.Print("You can pin up to " .. MAX .. " tiles. Right-click one to remove it.")
    return false
  end
  list[#list + 1] = key
  self:Layout()
  return true
end

function T:OpenMenu(anchor)
  local items = {}
  local function head(text) items[#items + 1] = { text = text, color = C.muted, func = function() end } end
  head("BUTTONS")
  for _, d in ipairs(self.ACTIONS) do
    local on = self:IsPinned(d.key)
    items[#items + 1] = {
      text = (on and "Remove: " or "Add: ") .. d.name,
      color = on and C.green or C.text2,
      func = function() T:Toggle(d.key) end,
    }
  end
  head("STATS")
  for _, d in ipairs(self.DEFS) do
    local on = self:IsPinned(d.key)
    items[#items + 1] = {
      text = (on and "Remove: " or "Pin: ") .. d.name,
      color = on and C.green or C.text2,
      func = function() T:Toggle(d.key) end,
    }
  end
  UI.Menu(anchor, items, true)
end

local function makeTile(i)
  local t = CreateFrame("Button", nil, T.holder)
  t:SetSize(W, H)
  t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  -- cards share one background (the holder); each card only gets a hover highlight
  t.hl = t:CreateTexture(nil, "BACKGROUND", nil, 2)
  t.hl:SetPoint("TOPLEFT", 2, -2)
  t.hl:SetPoint("BOTTOMRIGHT", -2, 2)
  t.hl:SetColorTexture(1, 1, 1, 0.04)
  t.hl:Hide()
  t:HookScript("OnEnter", function(self) self.hl:Show() end)
  t:HookScript("OnLeave", function(self) self.hl:Hide() end)
  t.v = UI.Text(t, 13, "bold", C.text)
  t.v:SetPoint("TOPLEFT", 8, -6)
  t.v:SetPoint("RIGHT", -6, 0)
  t.v:SetWordWrap(false)
  t.k = UI.Text(t, 10, nil, C.muted)
  t.k:SetPoint("BOTTOMLEFT", 8, 6)
  t.k:SetPoint("RIGHT", -6, 0)
  t.k:SetWordWrap(false)
  -- action tiles: a coloured edge on the left and an icon on the right
  t.edge = t:CreateTexture(nil, "ARTWORK")
  t.edge:SetPoint("TOPLEFT", 2, -6)
  t.edge:SetPoint("BOTTOMLEFT", 2, 6)
  t.edge:SetWidth(2)
  t.edge:Hide()
  t.icon = t:CreateTexture(nil, "ARTWORK")
  t.icon:SetSize(16, 16)
  t.icon:SetPoint("TOPRIGHT", -8, -8)
  t.icon:Hide()
  t:SetScript("OnClick", function(self, btn)
    local d = self.key and T.byKey[self.key]
    if btn == "RightButton" then
      ns.Window:Toggle("stats")
    elseif d and d.click then
      -- straight from the click: some actions (the layer hop's zone search) only work that way
      d.click()
      C_Timer.After(0.2, function() T:Update() end)
    else
      ns.Window:Toggle("stats")
    end
  end)
  t:SetScript("OnEnter", function(self)
    local d = self.key and T.byKey[self.key]
    if d and d.hover then d.hover(self) return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    local tt, tx
    if d and d.tipFn then
      local ok, a, b = pcall(d.tipFn)
      if ok then tt, tx = a, b end
    end
    GameTooltip:AddLine(tt or (d and d.name) or "Chillan?", 1, 1, 1)
    GameTooltip:AddLine(tx or (d and d.tip) or "Click: the Stats page", 0.52, 0.55, 0.57, true)
    GameTooltip:Show()
  end)
  t:SetScript("OnLeave", function() GameTooltip:Hide() if T.bossFrame then T.bossFrame:Hide() end end)
  return t
end

function T:Update()
  if not self.holder or not self.holder:IsShown() then return end
  for _, t in ipairs(self.tiles) do
    if t:IsShown() and t.key then
      local d = self.byKey[t.key]
      local ok, v, sub, col = pcall(d.get)
      if not ok then v, sub, col = "–", d.name, nil end
      t.v:SetText(v or "–")
      UI.Track(t.v):SetTextColor(hex(col or C.text))
      t.k:SetText(sub or "")
      if d.action then
        UI.Track(t.edge):SetColorTexture(hex(d.color))
        t.edge:Show()
        t.icon:SetTexture(ns.TEX .. "Icon" .. d.icon)
        UI.Track(t.icon):SetVertexColor(hex(d.color))
        local roomy = (t:GetWidth() or 0) >= 100
        t.icon:SetShown(roomy)
        t.v:SetPoint("RIGHT", roomy and -28 or -6, 0)
      else
        t.edge:Hide()
        t.icon:Hide()
        t.v:SetPoint("RIGHT", -6, 0)
      end
    end
  end
end

function T:Layout()
  if not self.holder then return end
  local m = ns.Overlays.minibar
  local list = self:List()
  local show = m and m:IsShown() and #list > 0 and not (ns.NowCard and ns.NowCard:Collapsed())
  self.holder:SetShown(show and true or false)
  if not show then
    self.rowWidth = 0
    if ns.Overlays.FitMinibar then ns.Overlays:FitMinibar() end
    return
  end
  local n = 0
  for _, key in ipairs(list) do if self.byKey[key] then n = n + 1 end end
  local cols = math.min(n, PER_ROW)
  local rows = math.ceil(n / PER_ROW)
  -- the block is as wide as the bar (or the bar grows to fit 3 cards); cards split the width evenly
  local m2 = ns.Overlays.minibar
  -- attached chat lets you drag the group narrower, so cards may shrink to 110 px (never less)
  local E = ns.EventWindow
  local docked = ns.db.settings.evDocked and E and E.frame and E.frame:IsShown()
  local blockW = math.max(cols * W, ns.Overlays:BaseWidth())
  blockW = math.floor(blockW)
  local tw = math.floor(blockW / cols)   -- the last column takes the leftover pixels
  n = 0
  for i = 1, MAX do
    local t = self.tiles[i] or makeTile(i)
    self.tiles[i] = t
    local key = list[i]
    if key and self.byKey[key] then
      n = n + 1
      t.key = key
      local row, col = math.floor((n - 1) / PER_ROW), (n - 1) % PER_ROW
      t:ClearAllPoints()
      t:SetSize(col == cols - 1 and (blockW - tw * (cols - 1)) or tw, H)
      t:SetPoint("TOPLEFT", self.holder, "TOPLEFT", col * tw, -row * H)
      t:Show()
    else
      t.key = nil
      t:Hide()
    end
  end
  self.holder:SetSize(blockW, math.max(1, rows) * H)
  -- thin divider lines between the cards instead of gaps
  self.lines = self.lines or {}
  local li = 0
  local function line(x1, y1, x2, y2)
    li = li + 1
    local l = self.lines[li]
    if not l then l = self.holder:CreateTexture(nil, "ARTWORK") self.lines[li] = l end
    UI.Track(l):SetColorTexture(hex(C.line))
    l:ClearAllPoints()
    l:SetPoint("TOPLEFT", self.holder, "TOPLEFT", x1, y1)
    l:SetPoint("BOTTOMRIGHT", self.holder, "TOPLEFT", x2, y2)
    l:Show()
  end
  for c = 1, cols - 1 do line(c * tw, -8, c * tw + 1, -(rows * H) + 8) end
  for r = 1, rows - 1 do line(8, -r * H, blockW - 8, -r * H - 1) end
  for i = li + 1, #self.lines do self.lines[i]:Hide() end
  -- (1.4.64) a thin accent edge on the first card (the light version of the Market look)
  if not self.edge then self.edge = UI.Track(self.holder:CreateTexture(nil, "OVERLAY")) end
  self.edge:SetColorTexture(hex(C.accent))
  self.edge:ClearAllPoints()
  self.edge:SetPoint("TOPLEFT", self.holder, "TOPLEFT", 0, -6)
  self.edge:SetPoint("BOTTOMLEFT", self.holder, "TOPLEFT", 2, -H + 6)
  self.edge:Show()
  -- the bar grows with the cards (up to 3 wide), more cards go downwards
  self.rowWidth = blockW
  if ns.Overlays.FitMinibar then ns.Overlays:FitMinibar() end
  self:Update()
end

function T:Init()
  local m = ns.Overlays.minibar
  if not m then return end
  self.tiles = {}
  local holder = CreateFrame("Frame", "ChillanTiles", UIParent)
  holder:SetFrameStrata("MEDIUM")
  holder:SetPoint("TOPLEFT", m, "BOTTOMLEFT", 0, -GAP)
  holder:SetFrameLevel(m:GetFrameLevel() + 5)
  self.holder = holder

  m:HookScript("OnShow", function() T:Layout() end)
  m:HookScript("OnHide", function() T:Layout() end)
  ns:Listen("MINIBAR", function() T:Layout() end)
  ns:Listen("DATA", function() T:Update() end)
  ns:Listen("LAYERHOP", function() T:Update() end)
  ns:Listen("LAYER", function() T:Update() end)
  ns:Listen("PULSE_MODE", function() T:Layout() end)
  ns:On("PLAYER_LEVEL_UP", function() C_Timer.After(1, function() T:Layout() end) end)
  ns:Listen("PULSE", function() T:Update() end)
  C_Timer.NewTicker(2, function()
    T:Update()
    if ns.Overlays.UpdateMinibarExtras then ns.Overlays:UpdateMinibarExtras() end
  end)
  C_Timer.After(1, function()
    startMoney = startMoney or (type(ns.S(GetMoney)) == "number" and ns.S(GetMoney)) or nil
    startHK = startHK or hk()
    T:Layout()
  end)
end
