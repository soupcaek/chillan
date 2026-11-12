-- Chillan? – små stat-rubrikker som kan festes under minibaren
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

local T = {}
ns.Tiles = T

local MAX = 8
local PER_ROW = 3
local W, H, GAP = 124, 44, 0   -- cards sit flush under the bar, sharing its background

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
    return rate and ns.Num(rate) or "–", "XP/h" .. (label == "this session" and " · session" or label and " · week" or "")
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
-- action buttons: same size as the stat tiles, a coloured edge and an icon; left-click does it
T.ACTIONS = {
  { key = "act_layer", name = "Layer hop", icon = "Radar", color = "7FB8FF",
    tip = "Left-click: move to another layer (a LayerSwap host or a gang member on another layer invites you)",
    get = function()
      if ns.LayerHop and ns.LayerHop.TileState then return ns.LayerHop:TileState() end
      return "Layer hop", "Click to hop"
    end,
    click = function() ns.LayerHop:Request() end },
  { key = "act_sos", name = "SOS – need help", icon = "SOS", color = "F2777A",
    tip = "Left-click: tell the gang you need help, with your zone and position",
    get = function() return "SOS", "Need help? Click" end,
    click = function() ns.Data:SOS() end },
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
  local S = ns.db.settings
  if S.tiles == nil then S.tiles = { "level", "xph", "eta" } end
  return S.tiles
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
  t.v = UI.Text(t, 14, "bold", C.text)
  t.v:SetPoint("TOPLEFT", 9, -7)
  t.v:SetPoint("RIGHT", -6, 0)
  t.v:SetWordWrap(false)
  t.k = UI.Text(t, 10, nil, C.muted)
  t.k:SetPoint("BOTTOMLEFT", 9, 7)
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
      if self.key then T:Toggle(self.key) end
    elseif d and d.click then
      -- straight from the click: some actions (the layer hop's zone search) only work that way
      d.click()
      C_Timer.After(0.2, function() T:Update() end)
    else
      ns.Window:OpenPlayer(ns.pid)
    end
  end)
  t:SetScript("OnEnter", function(self)
    local d = self.key and T.byKey[self.key]
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(d and d.name or "Chillan?", 1, 1, 1)
    GameTooltip:AddLine((d and d.tip) and (d.tip .. "  ·  Right-click: remove") or "Left-click: My page  ·  Right-click: remove", 0.52, 0.55, 0.57, true)
    GameTooltip:Show()
  end)
  t:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
      t.v:SetTextColor(hex(col or C.text))
      t.k:SetText(sub or "")
      if d.action then
        t.edge:SetColorTexture(hex(d.color))
        t.edge:Show()
        t.icon:SetTexture(ns.TEX .. "Icon" .. d.icon)
        t.icon:SetVertexColor(hex(d.color))
        t.icon:Show()
        t.v:SetPoint("RIGHT", -28, 0)
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
  local show = m and m:IsShown() and #list > 0
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
  local blockW = math.max(cols * (docked and 110 or W), ns.Overlays:BaseWidth())
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
    l:SetColorTexture(hex(C.line))
    l:ClearAllPoints()
    l:SetPoint("TOPLEFT", self.holder, "TOPLEFT", x1, y1)
    l:SetPoint("BOTTOMRIGHT", self.holder, "TOPLEFT", x2, y2)
    l:Show()
  end
  for c = 1, cols - 1 do line(c * tw, -8, c * tw + 1, -(rows * H) + 8) end
  for r = 1, rows - 1 do line(8, -r * H, blockW - 8, -r * H - 1) end
  for i = li + 1, #self.lines do self.lines[i]:Hide() end
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

  -- "+"-knapp på minibaren
  local plus = UI.IconButton(m, 22, "Plus", "Pin stats under the bar", function(b) T:OpenMenu(b) end)
  plus:SetScript("OnClick", function(b) T:OpenMenu(b) end)
  m.plus = plus

  m:HookScript("OnShow", function() T:Layout() end)
  m:HookScript("OnHide", function() T:Layout() end)
  ns:Listen("MINIBAR", function() T:Layout() end)
  ns:Listen("DATA", function() T:Update() end)
  ns:Listen("LAYERHOP", function() T:Update() end)
  ns:Listen("LAYER", function() T:Update() end)
  ns:On("PLAYER_REGEN_DISABLED", function() holder:SetAlpha(0.3) end)
  ns:On("PLAYER_REGEN_ENABLED", function() holder:SetAlpha(1) end)
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
