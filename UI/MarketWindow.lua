-- Chillan? – the Market window beside the auction house (1.4.57, panels 1.4.59)
-- Five tabs, as on the canvas (round 2, option A): Sell (Up Next on the left; Post and the listings
-- on the right), Buy (search and results left; the item with its price graph, listings and buy bar
-- right), My auctions, Wishlist (with a price graph) and Gang. Every area is its own bordered panel
-- with a title strip. The game wants a real click for every post, buy and cancel: all are buttons.
local ADDON, ns = ...
local UI, C = ns.UI, ns.C
local hex = ns.hex
local AH = ns.AH

local W = ns.MarketWin or {}
ns.MarketWin = W

local WIDTH, MIN_H = 900, 660
local PAD = 12
local ROW_H, GAP = 22, 0
local TABS = { "Sell", "Buy", "My auctions", "Item Tracker", "Gang" }
-- (1.4.64) the theme's own colours and your accent (gold stays for money only)
local BLUE = "6FA8F2"
local function PANELc() return C.panel or C.card end
local function PHEADc() return C.strip or C.cardHover end
local function PLINEc() return C.border or C.activeLine end
local function ROWALTc() return C.rowAlt or C.window end
local function ACCc() return C.accent end

local function dim(t) return ns.Colorize(t, C.dim) end
-- money, never cut: no copper from 10g up
local function coins(c)
  c = math.floor(c or 0)
  if c >= 100000 then c = math.floor(c / 100) * 100 end
  return ns.Market and ns.Market.Coins and ns.Market.Coins(c) or tostring(c)
end
W.Coins = coins
local function qhex(q)
  local c = ITEM_QUALITY_COLORS and q and ITEM_QUALITY_COLORS[q]
  return c and c.hex or "|cffe8eaed"
end
local askedNames = {}
local function itemName(id)
  local okI, name, link, q, _, _, _, _, _, _, icon = pcall(C_Item.GetItemInfo, id)
  if okI and name then return name, q, icon, link end
  -- (1.4.72) not in the game's cache yet: ask for it (the page redraws when it comes), and meanwhile
  -- use the name the gang's scans saw, never a bare item number
  if id and not askedNames[id] and C_Item and C_Item.RequestLoadItemDataByID then
    askedNames[id] = true
    pcall(C_Item.RequestLoadItemDataByID, id)
  end
  local known = ns.db.marketNames and ns.db.marketNames[id]
  if known then
    local okIcon, ic = pcall(C_Item.GetItemIconByID, id)
    return known, nil, okIcon and ic or nil
  end
  return nil
end
ns:On("GET_ITEM_INFO_RECEIVED", function(id)
  if not askedNames[id] or W.namesRedraw then return end
  W.namesRedraw = true
  C_Timer.After(0.5, function()
    W.namesRedraw = nil
    if W.gangP and W.gangP.salesP and W.gangP.salesP:IsVisible() then W:DrawGang() end
  end)
end)
local function left(secs)
  if not secs or secs <= 0 then return "" end
  if secs >= 3600 then return math.floor(secs / 3600) .. "h" end
  return math.max(1, math.floor(secs / 60)) .. "m"
end
local function moneyText(c)
  c = math.floor(c or 0)
  local g, s, cc = math.floor(c / 10000), math.floor(c % 10000 / 100), c % 100
  local t = {}
  if g > 0 then t[#t + 1] = g .. "g" end
  if s > 0 then t[#t + 1] = s .. "s" end
  if cc > 0 or #t == 0 then t[#t + 1] = cc .. "c" end
  return table.concat(t, " ")
end
-- "1g 20s 5c", "36s", "1.5g"; a plain number counts as silver
local function parseMoney(text)
  text = tostring(text or ""):lower():gsub(",", ".")
  local total, any = 0, false
  for n, unit in text:gmatch("([%d%.]+)%s*([gsc])") do
    local v = tonumber(n)
    if v then
      any = true
      total = total + v * (unit == "g" and 10000 or unit == "s" and 100 or 1)
    end
  end
  if not any then
    local v = tonumber(text:match("^%s*([%d%.]+)%s*$") or "")
    if not v then return nil end
    total = v * 100
  end
  return math.floor(total + 0.5)
end
W.ParseMoney, W.MoneyText = parseMoney, moneyText

---------------------------------------------------------------------------
-- building blocks
---------------------------------------------------------------------------
local function solid(parent, color, layer)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND")
  t:SetColorTexture(hex(color))
  return t
end

local function button(parent, w, h, label, style, onClick)
  return UI.Button(parent, w, h, label, style or "mkSec", onClick)
end

-- a panel: border, a title strip ("UP NEXT" ... right text), a body with padding
local function panel(parent, title, accent)
  local p = UI.Panel(parent, PANELc(), PLINEc(), true)
  if accent then
    local a = solid(p, accent, "ARTWORK")
    a:SetHeight(2)
    a:SetPoint("TOPLEFT", 1, -1) a:SetPoint("TOPRIGHT", -1, -1)
  end
  local strip = solid(p, PHEADc(), "BORDER")
  strip:SetPoint("TOPLEFT", 1, accent and -3 or -1)
  strip:SetPoint("TOPRIGHT", -1, accent and -3 or -1)
  strip:SetHeight(25)
  local line = solid(p, PLINEc(), "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", strip, "BOTTOMLEFT") line:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT")
  p.title = UI.Text(p, 11, "semi", "C9CDD2")
  p.title:SetPoint("LEFT", strip, "LEFT", 10, 0)
  p.title:SetText((title or ""):upper())
  p.right = UI.Text(p, 11, nil, C.dim)
  p.right:SetPoint("RIGHT", strip, "RIGHT", -10, 0)
  p.body = CreateFrame("Frame", nil, p)
  p.body:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 9, -9)
  p.body:SetPoint("BOTTOMRIGHT", -10, 9)
  p.strip = strip
  function p:SetTitle(t) self.title:SetText((t or ""):upper()) end
  return p
end

-- a list row: icon + name on the left, right-aligned columns, an optional button at the end
local function makeRow(parent, cols, btnW)
  local r = CreateFrame("Button", nil, parent)
  r:SetHeight(ROW_H)
  r.alt = solid(r, ROWALTc())
  r.alt:SetAllPoints()
  r.bg = r:CreateTexture(nil, "BACKGROUND", nil, 1)
  r.bg:SetAllPoints()
  do local ar, ag, ab = hex(C.accent) r.bg:SetColorTexture(ar, ag, ab, 0.13) end
  r.bg:Hide()
  r.bar = r:CreateTexture(nil, "ARTWORK")
  r.bar:SetWidth(2)
  r.bar:SetPoint("TOPLEFT") r.bar:SetPoint("BOTTOMLEFT")
  r.bar:SetColorTexture(hex(ACCc()))
  r.bar:Hide()
  r.hl = r:CreateTexture(nil, "HIGHLIGHT")
  r.hl:SetAllPoints()
  r.hl:SetColorTexture(1, 1, 1, 0.04)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(16, 16)
  r.icon:SetPoint("LEFT", 6, 0)
  r.name = UI.Text(r, 12, nil, C.text)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 7, 0)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)
  r.cols = {}
  local x = -6
  if btnW then
    r.btn = button(r, btnW, ROW_H - 4, "", "mkSec")
    r.btn:SetPoint("RIGHT", x, 0)
    r.pill = UI.Pill(r)
    r.pill:SetPoint("RIGHT", x, 0)
    r.pill:Hide()
    x = x - btnW - 10
  end
  for i = #cols, 1, -1 do
    local t = UI.Text(r, 12, nil, C.text2)
    t:SetJustifyH("RIGHT")
    t:SetWordWrap(false)
    t:SetWidth(cols[i])
    t:SetPoint("RIGHT", x, 0)
    r.cols[i] = t
    x = x - cols[i] - 10
  end
  r.name:SetPoint("RIGHT", r, "RIGHT", x, 0)
  function r:Set(icon, name, ...)
    if icon then self.icon:SetTexture(icon) self.icon:SetSize(16, 16) self.icon:Show()
    else self.icon:SetSize(1, 16) self.icon:Hide() end
    self.name:SetText(name or "")
    for i, t in ipairs(self.cols) do t:SetText((select(i, ...)) or "") end
  end
  function r:Mark(on) self.bg:SetShown(on and true or false) self.bar:SetShown(on and true or false) end
  return r
end

local function header(parent, cols, btnW, first, ...)
  local h = CreateFrame("Frame", nil, parent)
  h:SetHeight(18)
  local x = -6 - (btnW and (btnW + 10) or 0)
  local labels = { ... }
  for i = #cols, 1, -1 do
    local t = UI.Text(h, 10, nil, C.dim)
    t:SetJustifyH("RIGHT")
    t:SetWidth(cols[i])
    t:SetPoint("TOPRIGHT", x, -2)
    t:SetText(labels[i] or "")
    x = x - cols[i] - 10
  end
  local f = UI.Text(h, 10, nil, C.dim)
  f:SetPoint("TOPLEFT", 6, -2)
  f:SetText(first or "")
  local line = solid(h, PLINEc(), "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT") line:SetPoint("BOTTOMRIGHT")
  h.first = f
  return h
end

local function list(parent, cols, btnW, update, onClick)
  local l = UI.List(parent, ROW_H, GAP, function(self)
    local r = makeRow(self, cols, btnW)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(row, button) if onClick and row.item then onClick(row.item, button, row) end end)
    r:SetScript("OnEnter", function(row)
      local it = row.item
      if not it then return end
      GameTooltip:SetOwner(row, "ANCHOR_LEFT")
      if it.link then pcall(GameTooltip.SetHyperlink, GameTooltip, it.link)
      elseif (it.itemID or it.id) and GameTooltip.SetItemByID then pcall(GameTooltip.SetItemByID, GameTooltip, it.itemID or it.id)
      else return end
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
  end, function(r, it, idx)
    r.alt:SetShown(idx % 2 == 0)
    r:Mark(false)
    update(r, it, idx)
  end)
  return l
end

local function seg(parent, opts, get, set)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(24)
  local bg = UI.Panel(f, C.field or C.input, C.btnLine or C.activeLine, true)
  bg:SetAllPoints()
  f.btns = {}
  local x = 2
  for i, o in ipairs(opts) do
    local b = UI.Button(f, 0, 20, o, "nav", function() set(i) f:Refresh() end)
    local w = math.max(40, math.ceil(b.label:GetStringWidth()) + 20)
    b:SetWidth(w)
    b:SetPoint("LEFT", x, 0)
    x = x + w + 1
    f.btns[i] = b
  end
  f:SetWidth(x + 1)
  function f:Refresh() for i, b in ipairs(self.btns) do b:SetStyle(get() == i and "mkOn" or "nav") end end
  f:Refresh()
  return f
end

local function edit(parent, w, placeholder, onEnter)
  local e = UI.EditBox(parent, w, 26, placeholder, onEnter)
  
  e.edit:SetFont(ns.FONT, 12, "")
  e.edit.ph:SetFont(ns.FONT, 12, "")
  return e
end

local function pill(p, text, color)
  p:Set(text, color)
  p:SetHeight(18)
end

-- a price graph: a line over the last days, with low / high / now under it
-- (1.4.76) axis helpers
local M_ = {}
ns.MarketAxis = M_
function M_.NiceStep(span, n)
  local raw = span / (n or 4)
  local mag = 10 ^ math.floor(math.log10(math.max(raw, 1)))
  for _, m in ipairs({ 1, 2, 2.5, 5, 10 }) do
    if raw <= m * mag then return m * mag end
  end
  return 10 * mag
end
-- a short price for the axis: 600g · 1g 20s · 25s · 50c (silver and copper left off from 100g up)
function M_.AxisCoins(v)
  v = math.floor(v + 0.5)
  local g, sv, cv = math.floor(v / 10000), math.floor(v / 100) % 100, v % 100
  local G, S, Cc = "|cffE8C75Ag|r", "|cffC9CED6s|r", "|cffC9875Ac|r"
  if g >= 100 or (g > 0 and sv == 0) then return g .. G end
  if g > 0 then return g .. G .. " " .. sv .. S end
  if sv > 0 then return sv .. S .. (cv > 0 and (" " .. cv .. Cc) or "") end
  return cv .. Cc
end

local function makeChart(parent)
  local c = CreateFrame("Frame", nil, parent)
  -- (1.4.76) axes: the price on the left (round steps sized to the item), days along the bottom
  local AXIS_W = 50
  c.plot = CreateFrame("Frame", nil, c)
  c.plot:SetPoint("TOPLEFT", AXIS_W, -20)
  c.plot:SetPoint("BOTTOMRIGHT", -4, 16)
  c.axisL = solid(c, "3A404A", "BORDER")
  c.axisL:SetWidth(1)
  c.axisL:SetPoint("TOPLEFT", c.plot, "TOPLEFT", 0, 0)
  c.axisL:SetPoint("BOTTOMLEFT", c.plot, "BOTTOMLEFT", 0, 0)
  c.yLabels, c.xLabels = {}, {}
  c.title = UI.Text(c, 12, "semi", C.text)
  c.title:SetPoint("TOPLEFT", 0, 0)
  c.delta = UI.Text(c, 12, "semi", C.green)
  c.delta:SetPoint("TOPRIGHT", 0, 0)
  c.l1 = UI.Text(c, 10, nil, C.dim) c.l1:SetPoint("BOTTOMLEFT", 0, 0)
  c.l2 = UI.Text(c, 10, nil, C.dim) c.l2:SetPoint("BOTTOMLEFT", 0, 0)
  c.l3 = UI.Text(c, 10, nil, C.dim) c.l3:SetPoint("BOTTOMRIGHT", 0, 0)
  c.empty = UI.Text(c.plot, 11, nil, C.dim)
  c.empty:SetPoint("CENTER")
  c.grid = {}
  c.lines, c.dot = {}, solid(c.plot, ACCc(), "OVERLAY")
  c.dot:SetSize(6, 6)
  -- (1.4.76) a dot per day, and hover: a guide at the nearest day with its date, price and change
  c.dots = {}
  c.guide = solid(c.plot, "5A6070", "ARTWORK")
  c.guide:SetWidth(1)
  c.guide:Hide()
  c.hot = solid(c.plot, "FFFFFF", "OVERLAY")
  c.hot:SetSize(8, 8)
  c.hot:Hide()
  c.plot:EnableMouse(true)
  local function nearest(self)
    local pos = self.pos
    if not pos or #pos == 0 then return nil end
    local mx = GetCursorPosition() / (self.plot:GetEffectiveScale() or 1) - (self.plot:GetLeft() or 0)
    local best, bd
    for i, q in ipairs(pos) do
      local d = math.abs(q.x - mx)
      if not bd or d < bd then best, bd = i, d end
    end
    return best
  end
  local function showPoint(self, i)
    if self.hotI == i then return end
    self.hotI = i
    local q, p = self.pos[i], self.pts[i]
    self.guide:ClearAllPoints()
    self.guide:SetPoint("TOP", self.plot, "TOPLEFT", q.x, 0)
    self.guide:SetPoint("BOTTOM", self.plot, "BOTTOMLEFT", q.x, 0)
    self.guide:Show()
    self.hot:ClearAllPoints()
    self.hot:SetPoint("CENTER", self.plot, "BOTTOMLEFT", q.x, q.y)
    self.hot:Show()
    GameTooltip:SetOwner(self.plot, "ANCHOR_CURSOR")
    local ago = math.floor(ns.Now() / 86400) - p.day
    GameTooltip:AddLine(date("%a %d.%m", p.day * 86400 + 43200) .. (ago == 0 and "  · today" or ago == 1 and "  · yesterday" or ("  · " .. ago .. " days ago")), 1, 1, 1)
    GameTooltip:AddLine(coins(p.v))
    local prev = self.pts[i - 1]
    if prev and prev.v > 0 then
      local pct = math.floor((p.v - prev.v) / prev.v * 100 + 0.5)
      local col = pct < 0 and C.green or pct > 0 and C.red or C.muted
      GameTooltip:AddLine(ns.Colorize((pct > 0 and "+" or pct < 0 and "−" or "") .. math.abs(pct) .. " % vs " .. (p.day - prev.day == 1 and "the day before" or (p.day - prev.day) .. " days before"), col))
    end
    local lo, hi = self.lo, self.hi
    if lo and hi and hi > lo then
      if p.v == lo then GameTooltip:AddLine(ns.Colorize("Lowest in " .. self.days .. " days", C.green))
      elseif p.v == hi then GameTooltip:AddLine(ns.Colorize("Highest in " .. self.days .. " days", C.red)) end
    end
    GameTooltip:Show()
  end
  c.plot:SetScript("OnEnter", function() c.hotI = nil end)
  c.plot:SetScript("OnUpdate", function()
    if not c.plot:IsMouseOver() then return end
    local i = nearest(c)
    if i then showPoint(c, i) end
  end)
  c.plot:SetScript("OnLeave", function()
    c.hotI = nil
    c.guide:Hide() c.hot:Hide()
    GameTooltip:Hide()
  end)
  function c:SetData(pts, days)
    for _, l in ipairs(self.lines) do l:Hide() end
    for _, d in ipairs(self.dots) do d:Hide() end
    self.dot:Hide()
    self.pts, self.pos, self.days, self.hotI = pts, {}, days, nil
    local w, h = self.plot:GetWidth() or 0, self.plot:GetHeight() or 0
    for _, g in ipairs(self.grid) do g:Hide() end
    for _, t in ipairs(self.yLabels) do t:Hide() end
    for _, t in ipairs(self.xLabels) do t:Hide() end
    self.l1:SetText("")
    if #pts < 2 then
      self.empty:SetText(#pts == 1 and "One price so far: the graph grows a point a day." or "No history yet: Chillan keeps one price a day from now on.")
      self.delta:SetText("")
      self.l2:SetText("") self.l3:SetText("")
      return
    end
    self.empty:SetText("")
    local lo, hi = math.huge, 0
    for _, p in ipairs(pts) do lo, hi = math.min(lo, p.v), math.max(hi, p.v) end
    -- the price axis: about 4 lines in round steps (1, 2, 2.5, 5 × 10^n copper) around low–high
    local step = M_.NiceStep(math.max(1, hi - lo))
    local a, b = math.floor(lo / step) * step, math.ceil(hi / step) * step
    if b <= a then b = a + step end
    local span = b - a
    local d0 = math.floor(ns.Now() / 86400) - days + 1
    local function xy(p)
      local x = (p.day - d0) / math.max(1, days - 1) * (w - 6) + 3
      local y = (p.v - a) / span * (h - 4)
      return x, y
    end
    local n = 0
    for v = a, b + 0.5, step do
      n = n + 1
      local y = (v - a) / span * (h - 4)
      local g = self.grid[n]
      if not g then g = solid(self.plot, "2E333A", "BACKGROUND") g:SetHeight(1) self.grid[n] = g end
      g:ClearAllPoints()
      g:SetPoint("BOTTOMLEFT", self.plot, "BOTTOMLEFT", 0, y)
      g:SetPoint("BOTTOMRIGHT", self.plot, "BOTTOMRIGHT", 0, y)
      g:Show()
      local t = self.yLabels[n]
      if not t then t = UI.Text(self, 10, nil, C.dim) t:SetJustifyH("RIGHT") self.yLabels[n] = t end
      t:ClearAllPoints()
      t:SetPoint("RIGHT", self.plot, "BOTTOMLEFT", -5, y)
      t:SetText(M_.AxisCoins(v))
      t:Show()
    end
    -- the days: every third from today back, "today" on the right
    local today = math.floor(ns.Now() / 86400)
    local k = 0
    for day = today, d0, -3 do
      k = k + 1
      local t = self.xLabels[k]
      if not t then t = UI.Text(self, 10, nil, C.dim) self.xLabels[k] = t end
      local x = (day - d0) / math.max(1, days - 1) * (w - 6) + 3
      t:ClearAllPoints()
      t:SetPoint("TOP", self.plot, "BOTTOMLEFT", x, -4)
      t:SetText(day == today and "today" or date("%d.%m", day * 86400 + 43200))
      t:SetTextColor(hex(day == today and C.muted or C.dim))
      t:Show()
    end
    for i = 2, #pts do
      local l = self.lines[i - 1]
      if not l then
        l = self.plot:CreateLine(nil, "ARTWORK")
        l:SetThickness(2)
        l:SetColorTexture(hex(ACCc()))
        self.lines[i - 1] = l
      end
      local x1, y1 = xy(pts[i - 1])
      local x2, y2 = xy(pts[i])
      l:SetStartPoint("BOTTOMLEFT", self.plot, x1, y1)
      l:SetEndPoint("BOTTOMLEFT", self.plot, x2, y2)
      l:Show()
    end
    -- a small dot on every day with a price
    self.lo, self.hi = lo, hi
    for i, p in ipairs(pts) do
      local x, y = xy(p)
      self.pos[i] = { x = x, y = y }
      local d = self.dots[i]
      if not d then
        d = solid(self.plot, ACCc(), "OVERLAY")
        d:SetSize(4, 4)
        self.dots[i] = d
      end
      d:ClearAllPoints()
      d:SetPoint("CENTER", self.plot, "BOTTOMLEFT", x, y)
      d:Show()
    end
    local lx, ly = xy(pts[#pts])
    self.dot:ClearAllPoints()
    self.dot:SetPoint("CENTER", self.plot, "BOTTOMLEFT", lx, ly)
    self.dot:Show()
    local first, last = pts[1].v, pts[#pts].v
    local pct = first > 0 and math.floor((last - first) / first * 100 + 0.5) or 0
    self.delta:SetText(dim("now ") .. coins(last) .. dim("  ·  ") .. ns.Colorize((pct > 0 and "+" or pct < 0 and "−" or "") .. math.abs(pct) .. " %", pct < 0 and C.green or pct > 0 and C.red or C.muted))
    self.delta:SetTextColor(hex(pct < 0 and C.green or pct > 0 and C.red or C.muted))
    self.l2:SetText("") self.l3:SetText("")
  end
  return c
end
W.MakeChart = makeChart

---------------------------------------------------------------------------
-- the window
---------------------------------------------------------------------------
function W:Create()
  if self.frame then return end
  local f = CreateFrame("Frame", "ChillanMarketWindow", UIParent)
  f:SetSize(WIDTH, MIN_H)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:Hide()
  self.frame = f
  local bg = UI.Panel(f, C.window, C.btnLine or C.activeLine)
  bg:SetAllPoints()
  bg:SetFrameLevel(f:GetFrameLevel())

  local title = UI.Text(f, 13, "semi", C.text)
  title:SetPoint("TOPLEFT", PAD, -10)
  title:SetText("Chillan" .. ns.Colorize("?", C.amber) .. " " .. ns.Colorize("Market", C.muted))
  local close = UI.IconButton(f, 22, "Close", nil, function() W.closedThisVisit = true f:Hide() W:PaintReopen() end)
  close:SetPoint("TOPRIGHT", -6, -5)
  -- (1.4.61) the scan button, moved here from the auction house: a full scan once per 15 minutes
  -- (the game's rule), a quick page-by-page scan in between
  self.scanBtn = button(f, 130, 22, "Full scan", "mkSec", function() if ns.Market then ns.Market:FullScan() end W:PaintScan() end)
  self.scanBtn:SetPoint("RIGHT", close, "LEFT", -8, 0)
  self.scanBtn.tooltip = "Full scan: reads the whole auction house (the game allows one every 15 minutes). In between, a quick scan reads the lowest price of every item page by page. Prices go to tooltips, the price graphs and the gang."

  self.tabBtns = {}
  local x = 4
  for i, name in ipairs(TABS) do
    local b = CreateFrame("Button", nil, f)
    b.text = UI.Text(b, 12, nil, C.muted)
    b.text:SetPoint("CENTER", 0, 1)
    b.text:SetText(name)
    local w = math.ceil(b.text:GetStringWidth()) + 28
    b:SetSize(w, 30)
    b:SetPoint("TOPLEFT", x, -30)
    x = x + w
    b.line = solid(b, ACCc(), "ARTWORK")
    b.line:SetHeight(2)
    b.line:SetPoint("BOTTOMLEFT", 6, 0) b.line:SetPoint("BOTTOMRIGHT", -6, 0)
    b:SetScript("OnClick", function() W:Show(i) end)
    self.tabBtns[i] = b
  end
  local sep = solid(f, PLINEc(), "ARTWORK")
  sep:SetHeight(1)
  sep:SetPoint("TOPLEFT", 1, -60) sep:SetPoint("TOPRIGHT", -1, -60)
  local fsep = solid(f, PLINEc(), "ARTWORK")
  fsep:SetHeight(1)
  fsep:SetPoint("BOTTOMLEFT", 1, 26) fsep:SetPoint("BOTTOMRIGHT", -1, 26)
  self.status = UI.Text(f, 11, nil, C.dim)
  self.status:SetPoint("BOTTOMLEFT", PAD, 8)
  self.gold = UI.Text(f, 11, nil, C.dim)
  self.gold:SetPoint("BOTTOMRIGHT", -PAD, 8)

  self.pages = {}
  for i = 1, #TABS do
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", PAD, -72)
    p:SetPoint("BOTTOMRIGHT", -PAD, 38)
    p:Hide()
    self.pages[i] = p
  end
  self:BuildSell(self.pages[1])
  self:BuildBuy(self.pages[2])
  self:BuildAuctions(self.pages[3])
  self:BuildShop(self.pages[4])
  self:BuildGang(self.pages[5])

  ns:Listen("MKAH", function(what) W:OnChange(what) W:PaintSellTotals() end)
  ns:On("AUCTION_HOUSE_THROTTLED_SYSTEM_READY", function() if f:IsShown() then W:PaintSellTotals() end end)
  ns:Listen("MARKET", function() if f:IsShown() then W:PaintFooter() W:PaintScan() end end)
  f:SetScript("OnShow", function() W:Refresh() end)
end

function W:PaintScan()
  local M = ns.Market
  if not (M and self.scanBtn) then return end
  local can, leftS = M:CanFull()
  if M.scanning then self.scanBtn:SetLabel("Scanning …")
  elseif can then self.scanBtn:SetLabel("Full scan")
  else self.scanBtn:SetLabel("Quick scan · " .. math.max(1, math.ceil((leftS or 0) / 60)) .. " min") end
  self.scanBtn:SetEnabled(AH.open and not M.scanning)
end

function W:PaintFooter()
  local M = ns.Market
  if M and M.status and M.status ~= "" and M.scanning then
    self.status:SetText(M.status)
  elseif M then
    local n, newest = M:Count(), M:Latest()
    self.status:SetText(ns.Num(n) .. " gang prices" .. (newest and newest > 0 and (" · newest " .. ns.Ago(newest)) or ""))
  end
  local okM, money = pcall(GetMoney)
  self.gold:SetText(dim("Gold ") .. coins(okM and money or 0))
end

function W:Show(i)
  self:Create()
  self.tab = i or self.tab or 1
  for k, p in ipairs(self.pages) do p:SetShown(k == self.tab) end
  for k, b in ipairs(self.tabBtns) do
    b.text:SetTextColor(hex(k == self.tab and C.text or C.muted))
    b.line:SetShown(k == self.tab)
  end
  self:Refresh()
end

function W:Refresh()
  if not self.frame or not self.frame:IsShown() then return end
  self:PaintFooter()
  self:PaintScan()
  local t = self.tab or 1
  if t == 1 then self:DrawSell() elseif t == 2 then self:DrawBuy() elseif t == 3 then self:DrawAuctions()
  elseif t == 4 then self:DrawShop() else self:DrawGang() end
end

function W:OnChange(what)
  if not self.frame or not self.frame:IsShown() then return end
  if what == "posted" or what == "bought" then self.bagsDirty = true end
  if what == "listing" then
    if self.pendingDraw then return end
    self.pendingDraw = true
    C_Timer.After(0.2, function() self.pendingDraw = nil self:Refresh() end)
    return
  end
  self:Refresh()
end

---------------------------------------------------------------------------
-- Sell: Up Next on the left, Post and the listings on the right
---------------------------------------------------------------------------
local LEFT_W = 300
local function durations()
  return {
    { 1, (AUCTION_DURATION_ONE and AUCTION_DURATION_ONE ~= "" and AUCTION_DURATION_ONE) or "12 h" },
    { 2, (AUCTION_DURATION_TWO and AUCTION_DURATION_TWO ~= "" and AUCTION_DURATION_TWO) or "24 h" },
    { 3, (AUCTION_DURATION_THREE and AUCTION_DURATION_THREE ~= "" and AUCTION_DURATION_THREE) or "48 h" },
  }
end

function W:BuildSell(p)
  local s = {}
  self.sell = s
  s.vendP = panel(p, "For a vendor")
  s.vendP:SetPoint("BOTTOMLEFT", 0, 0)
  s.vendP:SetSize(LEFT_W, 62)
  s.vendBtn = CreateFrame("Button", nil, s.vendP.body)
  s.vendBtn:SetAllPoints()
  s.vendL = UI.Text(s.vendBtn, 12, nil, C.muted)
  s.vendL:SetPoint("LEFT", 0, 0)
  s.vendR = UI.Text(s.vendBtn, 12, nil, C.text)
  s.vendR:SetPoint("RIGHT", 0, 0)
  s.vendBtn:SetScript("OnClick", function() s.showVendor = not s.showVendor W:DrawSell() end)

  s.upP = panel(p, "Up next")
  s.upP:SetPoint("TOPLEFT", 0, 0)
  s.upP:SetPoint("BOTTOMRIGHT", s.vendP, "TOPRIGHT", 0, 10)
  s.uhead = header(s.upP.body, { 76 }, nil, "Item", "You get")
  s.uhead:SetPoint("TOPLEFT", -4, 0) s.uhead:SetPoint("TOPRIGHT", 4, 0)
  s.queue = list(s.upP.body, { 76 }, nil, function(r, it)
    r:Set(it.icon, qhex(it.quality) .. it.name .. "|r" .. (it.count > 1 and dim("  ×" .. it.count) or ""),
      it.each and coins(it.each * it.count) or dim("no price"))
    r:Mark(s.cur and s.cur.key == it.key)
  end, function(it, button)
    if button == "RightButton" then
      local d = AH.DB()
      d.hidden[it.itemID] = (not d.hidden[it.itemID]) or nil
      W.sellQueue = nil
      W:DrawSell()
      return
    end
    W:SelectSell(it)
  end)
  s.queue:SetPoint("TOPLEFT", s.uhead, "BOTTOMLEFT", 0, -2)
  s.queue:SetPoint("BOTTOMRIGHT", s.upP.body, "BOTTOMRIGHT", 4, 18)
  s.uhint = UI.Text(s.upP.body, 11, nil, C.dim)
  s.uhint:SetPoint("BOTTOMLEFT", 2, 0)
  s.uhint:SetText("worth more on the auction than at a vendor")
  s.uhintTip = UI.InfoTip(s.upP.body, s.uhint, "Up Next",
    "Your bags, most valuable first: items that pay more on the auction (after its 5 % cut) than at a vendor. Items with no price yet are here too when they're green or better. Right-click a row to hide it for good; right-click it under For a vendor to bring it back. Skip moves an item to the end for this visit.")

  s.postP = panel(p, "Post", ACCc())
  s.postP:SetPoint("TOPLEFT", LEFT_W + 12, 0)
  s.postP:SetPoint("TOPRIGHT", 0, 0)
  s.postP:SetHeight(246)
  local b = s.postP.body
  s.icon = b:CreateTexture(nil, "ARTWORK")
  s.icon:SetSize(36, 36)
  s.icon:SetPoint("TOPLEFT", 0, 0)
  s.name = UI.Text(b, 15, "semi", C.text)
  s.name:SetPoint("TOPLEFT", s.icon, "TOPRIGHT", 10, -1)
  s.name:SetPoint("RIGHT", b, "RIGHT", -70, 0)
  s.name:SetJustifyH("LEFT")
  s.name:SetWordWrap(false)
  s.sub = UI.Text(b, 11, nil, C.dim)
  s.sub:SetPoint("TOPLEFT", s.name, "BOTTOMLEFT", 0, -4)
  s.pos = UI.Text(b, 11, nil, C.dim)
  s.pos:SetPoint("TOPRIGHT", 0, -2)
  local iconHit = CreateFrame("Frame", nil, b)
  iconHit:SetAllPoints(s.icon)
  iconHit:EnableMouse(true)
  iconHit:SetScript("OnEnter", function(h)
    if s.cur and s.cur.link then GameTooltip:SetOwner(h, "ANCHOR_LEFT") pcall(GameTooltip.SetHyperlink, GameTooltip, s.cur.link) GameTooltip:Show() end
  end)
  iconHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local function label(text, y)
    local t = UI.Text(b, 12, nil, C.muted)
    t:SetPoint("TOPLEFT", 0, y)
    t:SetText(text)
  end
  label("Price each", -54)
  s.price = edit(b, 120, "price", function(e) e:ClearFocus() end)
  s.price:SetPoint("TOPLEFT", 86, -48)
  s.price.edit:HookScript("OnTextChanged", function(e, user)
    if user then s.userPrice = parseMoney(e:GetText()) end
    W:PaintSellTotals()
  end)
  s.why = UI.Text(b, 11, nil, C.dim)
  s.why:SetPoint("LEFT", s.price, "RIGHT", 10, 0)
  s.whyTip = UI.InfoTip(b, s.why, "Price each",
    "Starts 1c under the cheapest listing that isn't yours. With nothing listed it uses the gang price, and it never goes under what a vendor pays (after the auction house's 5 % cut). Type 1g 20s 5c; a plain number counts as silver.")
  label("Quantity", -88)
  s.qty = edit(b, 64, "", function(e) e:ClearFocus() end)
  s.qty:SetPoint("TOPLEFT", 86, -82)
  s.qty.edit:SetNumeric(true)
  s.qty.edit:HookScript("OnTextChanged", function(e, user) if user then s.userQty = tonumber(e:GetText()) end W:PaintSellTotals() end)
  s.of = UI.Text(b, 11, nil, C.dim)
  s.of:SetPoint("LEFT", s.qty, "RIGHT", 8, 0)
  s.all = button(b, 40, 20, "All", "mkGhost", function() if s.cur then s.userQty = s.cur.count s.qty:SetText(tostring(s.cur.count)) W:PaintSellTotals() end end)
  s.all:SetPoint("LEFT", s.of, "RIGHT", 8, 0)
  label("Duration", -120)
  s.dur = seg(b, (function() local o = {} for i, d in ipairs(durations()) do o[i] = d[2] end return o end)(),
    function() return ns.db.settings.mkDuration or 2 end,
    function(i) ns.db.settings.mkDuration = i W:PaintSellTotals() end)
  s.dur:SetPoint("TOPLEFT", 86, -115)

  local box = UI.Panel(b, "11241A", "2E5A40", true)
  box:SetPoint("BOTTOMLEFT", 0, 0)
  box:SetPoint("BOTTOMRIGHT", 0, 0)
  box:SetHeight(54)
  local gl = UI.Text(box, 11, nil, "9FD3B2")
  gl:SetPoint("TOPLEFT", 10, -8)
  gl:SetText("You get after the 5 % cut")
  UI.InfoTip(box, gl, "After the cut", "The auction house keeps 5 % of every sale. This is price each × 0.95 (rounded down) × quantity: what actually reaches your mailbox.")
  s.get = UI.Text(box, 18, "semi", C.green)
  s.get:SetPoint("BOTTOMLEFT", 10, 8)
  s.deposit = UI.Text(box, 11, nil, C.dim)
  s.deposit:SetPoint("CENTER", 10, 0)
  s.postBtn = button(box, 100, 32, "Post", "mkPri", function() W:DoPost() end)
  s.postBtn:SetPoint("RIGHT", -10, 0)
  s.skipBtn = button(box, 64, 32, "Skip", "mkSec", function() W:SkipCurrent() end)
  s.skipBtn:SetPoint("RIGHT", s.postBtn, "LEFT", -8, 0)
  s.skipBtn.tooltip = "Not now – moves it to the end of Up Next."

  s.listP = panel(p, "On the auction house now")
  s.listP:SetPoint("TOPLEFT", s.postP, "BOTTOMLEFT", 0, -10)
  s.listP:SetPoint("BOTTOMRIGHT", 0, 0)
  s.refresh = button(s.listP, 64, 18, "Refresh", "mkGhost", function() if s.cur then AH.Ask(W:SellReq(s.cur), nil, true, true) end end)
  s.refresh:SetPoint("RIGHT", s.listP.strip, "RIGHT", -6, 0)
  s.lhead = header(s.listP.body, { 80, 90 }, nil, "Price each", "Available", "")
  s.lhead:SetPoint("TOPLEFT", -4, 0) s.lhead:SetPoint("TOPRIGHT", 4, 0)
  s.listings = list(s.listP.body, { 80, 90 }, nil, function(r, it)
    r:Set(nil, coins(it.price), ns.Num(it.qty), it.tag or "")
  end)
  s.listings:SetPoint("TOPLEFT", s.lhead, "BOTTOMLEFT", 0, -2)
  s.listings:SetPoint("BOTTOMRIGHT", s.listP.body, "BOTTOMRIGHT", 4, 0)

  ns:On("BAG_UPDATE_DELAYED", function() if W.frame and W.frame:IsShown() and W.tab == 1 then W.bagsDirty = true W:DrawSell() end end)
end

function W:SellReq(e)
  return { key = e.key, itemID = e.itemID, commodity = e.commodity, itemKey = e.itemKey, bagEntry = e }
end

function W:BuildQueue()
  local bags, loading = AH.ReadBags()
  local up, vend, vendTotal = {}, {}, 0
  local hidden = AH.DB().hidden
  for _, e in ipairs(bags) do
    local other = AH.Cheapest(e.key)
    local basis = other or AH.GangPrice(e.itemID)
    local vendor = AH.Vendor(e.itemID)
    e.vendor = vendor
    e.each = basis and AH.AfterCut(basis) or nil
    if hidden[e.itemID] then
      vend[#vend + 1] = e
      vendTotal = vendTotal + vendor * e.count
    elseif (e.each and e.each > vendor) or (not e.each and (vendor == 0 or (e.quality or 1) >= 2)) then
      up[#up + 1] = e
    else
      vend[#vend + 1] = e
      vendTotal = vendTotal + vendor * e.count
    end
  end
  local skipped = self.skipped or {}
  -- (1.4.70) a steady order: an item keeps its place once it's in the list. Sorting by value every
  -- time made rows jump around whenever a price answer came back from the auction house
  self.rank = self.rank or {}
  local fresh = {}
  for _, e in ipairs(up) do if not self.rank[e.key] then fresh[#fresh + 1] = e end end
  table.sort(fresh, function(a, b)
    local wa, wb = (a.each or -1) * a.count, (b.each or -1) * b.count
    if wa ~= wb then return wa > wb end
    return a.name < b.name
  end)
  for _, e in ipairs(fresh) do self.rankN = (self.rankN or 0) + 1 self.rank[e.key] = self.rankN end
  table.sort(up, function(a, b)
    local sa, sb = skipped[a.key] or 0, skipped[b.key] or 0
    if sa ~= sb then return sa < sb end
    return self.rank[a.key] < self.rank[b.key]
  end)
  table.sort(vend, function(a, b) return (a.vendor * a.count) > (b.vendor * b.count) end)
  return up, vend, vendTotal, loading
end

function W:DrawSell()
  local s = self.sell
  if not s then return end
  if self.bagsDirty or not self.sellQueue then
    self.bagsDirty = false
    self.sellQueue, self.vendQueue, self.vendTotal = self:BuildQueue()
    if s.cur then
      local still
      for _, e in ipairs(self.sellQueue) do if e.key == s.cur.key then still = e end end
      for _, e in ipairs(self.vendQueue) do if e.key == s.cur.key then still = e end end
      s.cur = still
    end
  end
  local up, vend = self.sellQueue, self.vendQueue
  -- (1.4.70) after a post, move on to the next item, not the one just posted: the bags can take a
  -- moment to show it gone, and picking it again left a Post button that did nothing
  if not s.cur then
    local justPosted = self.justPosted
    if justPosted and ns.Now() - justPosted.at > 5 then justPosted = nil self.justPosted = nil end
    for _, e in ipairs(up) do
      if not (justPosted and justPosted.key == e.key and justPosted.left <= 0) then
        self:SelectSell(e, true)
        break
      end
    end
  end
  local e = s.cur
  if e then
    s.icon:SetTexture(e.icon)
    s.name:SetText(qhex(e.quality) .. e.name .. "|r")
    local gp = AH.GangPrice(e.itemID)
    s.sub:SetText(e.count .. " in your bags" .. (gp and (" · gang price " .. coins(gp)) or "") .. (e.vendor and e.vendor > 0 and (" · vendor " .. coins(e.vendor)) or ""))
    local idx
    for i, x in ipairs(up) do if x.key == e.key then idx = i end end
    s.pos:SetText(idx and ("Item " .. idx .. " of " .. #up) or "")
  else
    s.icon:SetTexture(nil)
    s.name:SetText(dim("Nothing to sell"))
    s.sub:SetText("")
    s.pos:SetText("")
  end
  local L = e and AH.Listing(e.key)
  local rows, tagged = {}, false
  if L and L.rows then
    for _, r in ipairs(L.rows) do
      local tag
      if r.own > 0 then tag = ns.Colorize("yours", C.amber)
      elseif not tagged then tag = dim("cheapest") tagged = true end
      rows[#rows + 1] = { price = r.price, qty = r.qty, own = r.own, tag = tag }
    end
  end
  s.listings.emptyText = not e and "" or (L and (L.state == "listed" and "Nothing listed: the gang price is used." or "No answer from the auction house. Refresh to ask again.") or "Asking the auction house …")
  s.listings:SetData(rows)
  if s.showVendor then
    s.upP:SetTitle("For a vendor")
    s.upP.right:SetText(#vend .. " " .. (#vend == 1 and "item" or "items"))
    local data = {}
    for _, x in ipairs(vend) do data[#data + 1] = setmetatable({ each = x.vendor > 0 and x.vendor or nil }, { __index = x }) end
    s.queue.emptyText = "Nothing here."
    s.queue:SetData(data)
    s.uhint:SetText("right-click a row to put it back in Up Next")
    s.vendP:SetTitle("Up next")
    s.vendL:SetText("‹ Back to Up Next")
    s.vendR:SetText("")
  else
    s.upP:SetTitle("Up next")
    s.upP.right:SetText(#up .. " " .. (#up == 1 and "item" or "items"))
    s.queue.emptyText = "Nothing in your bags is worth more on the auction house than at a vendor."
    s.queue:SetData(up)
    s.uhint:SetText("worth more on the auction than at a vendor")
    s.vendP:SetTitle("For a vendor")
    s.vendL:SetText(#vend .. " " .. (#vend == 1 and "item" or "items") .. " · vendor pays more")
    s.vendR:SetText(coins(self.vendTotal or 0) .. "  ›")
  end
  s.uhintTip:ClearAllPoints()
  s.uhintTip:SetPoint("LEFT", s.uhint, "LEFT", math.ceil(s.uhint:GetStringWidth()) + 6, 0)
  self:PaintSellTotals()
end

function W:SelectSell(e, quiet)
  local s = self.sell
  s.cur = e
  s.userPrice, s.userQty = nil, nil
  s.qty:SetText(tostring(e.count))
  s.price:SetText("")
  AH.Ask(self:SellReq(e), function()
    W.bagsDirty = true
    if s.cur and s.cur.key == e.key then W:DrawSell() W:SuggestFor(s.cur) W:PaintSellTotals() end
  end, false, true)
  self:SuggestFor(e)
  if not quiet then self:DrawSell() end
end

function W:SuggestFor(e)
  local s = self.sell
  if s.userPrice or not e then return end
  local price, why = AH.SuggestPrice(e)
  s.suggested = price
  s.price:SetText(moneyText(price))
  s.why:SetText(why or "")
  s.whyTip:ClearAllPoints()
  s.whyTip:SetPoint("LEFT", s.why, "LEFT", math.ceil(s.why:GetStringWidth()) + 6, 0)
end

function W:SellValues()
  local s = self.sell
  local e = s.cur
  if not e then return end
  local price = s.userPrice or parseMoney(s.price:GetText()) or s.suggested
  local qty = math.min(e.count, math.max(1, s.userQty or tonumber(s.qty:GetText()) or e.count))
  local dur = durations()[ns.db.settings.mkDuration or 2][1]
  return e, price, qty, dur
end

function W:PaintSellTotals()
  local s = self.sell
  if not s then return end
  local e, price, qty, dur = self:SellValues()
  if not e or not price then
    s.get:SetText("") s.deposit:SetText("") s.of:SetText("")
    s.postBtn:SetEnabled(false)
    return
  end
  s.of:SetText("of " .. e.count)
  s.get:SetText(coins(AH.AfterCut(price) * qty))
  local d = AH.Deposit(e, qty, dur)
  s.deposit:SetText(d and (dim("Deposit ") .. coins(d)) or "")
  -- (dev5) only a post in flight or no price turns Post off. "The auction house is busy" used to as
  -- well, and nothing repainted the button when it got ready again: it looked fine but did nothing
  s.postBtn:SetEnabled(price > 0 and not AH.PostWaiting())
  s.postBtn:SetLabel(AH.PostWaiting() and "Posting …" or "Post")
  s.get:SetTextColor(hex(price < AH.Floor(e.itemID) and C.red or C.green))
end

function W:DoPost()
  local e, price, qty, dur = self:SellValues()
  if not e or not price then AH.Trace("Post clicked, but no item or price is picked") return end
  local s = self.sell
  if not AH.CanPost() then
    ns.Print("Market: " .. (AH.WhyNot() or "the auction house isn't ready") .. " – click Post again in a moment.")
    self:PaintSellTotals()
    return
  end
  local done = AH.Post(e, qty, price, dur, function(good)
    if good then
      local c = AH.Listing(e.key)
      if c then c.at = 0 end
      W.justPosted = { key = e.key, left = e.count - qty, at = ns.Now() }
      -- the rest of a stack stays selected; a whole stack moves on to the next item
      if qty < e.count then e.count = e.count - qty else s.cur = nil end
      W.bagsDirty = true
    end
    W:DrawSell()
  end)
  if not done then ns.Print("Market: can't post yet – " .. (AH.WhyNot() or "the item isn't in your bags any more") .. ".") end
  self:PaintSellTotals()
end

function W:SkipCurrent()
  local s = self.sell
  if not s.cur then return end
  self.skipped = self.skipped or {}
  self.skipN = (self.skipN or 0) + 1
  self.skipped[s.cur.key] = self.skipN
  self.bagsDirty = true
  s.cur = nil
  self:DrawSell()
end

---------------------------------------------------------------------------
-- Buy: search and results left; the item, its price graph, listings and the buy bar right
---------------------------------------------------------------------------
local BUY_LEFT = 360
function W:BuildBuy(p)
  local b = {}
  self.buyP = b
  b.searchP = panel(p, "Search")
  b.searchP:SetPoint("TOPLEFT", 0, 0)
  b.searchP:SetSize(BUY_LEFT, 104)
  local sb = b.searchP.body
  b.box = edit(sb, BUY_LEFT - 160, "Search by name", function(e) e:ClearFocus() W:DoSearch() end)
  b.box:SetPoint("TOPLEFT", 0, 0)
  b.go = button(sb, 70, 26, "Search", "mkPri", function() W:DoSearch() end)
  b.go:SetPoint("LEFT", b.box, "RIGHT", 6, 0)
  b.save = button(sb, 60, 26, "Save", "mkSec", function()
    local t = b.box:GetText():gsub("^%s+", ""):gsub("%s+$", "")
    if t == "" then return end
    local d = AH.DB()
    for i = #d.saved, 1, -1 do if d.saved[i]:lower() == t:lower() then table.remove(d.saved, i) end end
    table.insert(d.saved, 1, t)
    while #d.saved > 6 do table.remove(d.saved) end
    W:DrawBuy()
  end)
  b.save:SetPoint("LEFT", b.go, "RIGHT", 6, 0)
  b.save.tooltip = "Keep this search as a button. Right-click a saved one to remove it."
  b.chips = {}
  b.chipRow = CreateFrame("Frame", nil, sb)
  b.chipRow:SetPoint("TOPLEFT", 0, -34) b.chipRow:SetPoint("TOPRIGHT", 0, -34)
  b.chipRow:SetHeight(20)

  b.resP = panel(p, "Results")
  b.resP:SetPoint("TOPLEFT", b.searchP, "BOTTOMLEFT", 0, -10)
  b.resP:SetPoint("BOTTOMLEFT", 0, 0)
  b.resP:SetWidth(BUY_LEFT)
  b.rhead = header(b.resP.body, { 96 }, nil, "Item", "Cheapest")
  b.rhead:SetPoint("TOPLEFT", -4, 0) b.rhead:SetPoint("TOPRIGHT", 4, 0)
  b.results = list(b.resP.body, { 96 }, nil, function(r, it)
    r:Set(it.icon, qhex(it.quality) .. (it.name or ("item " .. it.itemID)) .. "|r", it.minPrice and coins(it.minPrice) or "")
    r:Mark(b.sel and b.sel.itemID == it.itemID and (not it.itemKey or not b.sel.itemKey or b.sel.itemKey == it.itemKey))
  end, function(it) W:SelectBuy(it) end)
  b.results:SetPoint("TOPLEFT", b.rhead, "BOTTOMLEFT", 0, -2)
  b.results:SetPoint("BOTTOMRIGHT", b.resP.body, "BOTTOMRIGHT", 4, 0)

  b.itemP = panel(p, "Pick a result", ACCc())
  b.itemP:SetPoint("TOPLEFT", BUY_LEFT + 12, 0)
  b.itemP:SetPoint("TOPRIGHT", 0, 0)
  b.itemP:SetHeight(214)
  b.wish = button(b.itemP, 70, 18, "+ Track", "mkGhost", function()
    if b.sel then
      AH.ShopAdd(b.sel.itemID)
      b.wish:SetLabel("Tracked ✓")
      C_Timer.After(1.5, function() b.wish:SetLabel("+ Track") end)
    end
  end)
  b.wish.tooltip = "Follow this item in the Item Tracker: its price graph, and an alert when it drops under a price you set."
  b.wish:SetPoint("RIGHT", b.itemP.strip, "RIGHT", -6, 0)
  b.stats = UI.Text(b.itemP.body, 12, nil, C.text)
  b.stats:SetPoint("TOPLEFT", 0, 0)
  b.stats:SetPoint("TOPRIGHT", 0, 0)
  b.stats:SetJustifyH("LEFT")
  b.chart = makeChart(b.itemP.body)
  b.chart:SetPoint("TOPLEFT", 0, -22)
  b.chart:SetPoint("BOTTOMRIGHT", 0, 0)

  b.bar = UI.Panel(p, PANELc(), PLINEc(), true)
  b.bar:SetPoint("BOTTOMLEFT", BUY_LEFT + 12, 0)
  b.bar:SetPoint("BOTTOMRIGHT", 0, 0)
  b.bar:SetHeight(48)
  local bl = UI.Text(b.bar, 12, nil, C.muted)
  bl:SetPoint("LEFT", 10, 0)
  bl:SetText("Buy")
  b.qty = edit(b.bar, 56, "", function(e) e:ClearFocus() end)
  b.qty:SetPoint("LEFT", bl, "RIGHT", 8, 0)
  b.qty.edit:SetNumeric(true)
  b.qty.edit:HookScript("OnTextChanged", function(_, user) if user then AH.Drop() end W:PaintBuyBar() end)
  b.for_ = UI.Text(b.bar, 12, nil, C.text)
  b.for_:SetPoint("LEFT", b.qty, "RIGHT", 10, 0)
  b.buyBtn = button(b.bar, 140, 32, "Buy", "mkPri", function() W:DoBuy() end)
  b.buyBtn:SetPoint("RIGHT", -8, 0)

  b.listP = panel(p, "On the auction house now")
  b.listP:SetPoint("TOPLEFT", b.itemP, "BOTTOMLEFT", 0, -10)
  b.listP:SetPoint("BOTTOMRIGHT", b.bar, "TOPRIGHT", 0, 10)
  b.lhead = header(b.listP.body, { 80, 70 }, nil, "Price each", "Available", "")
  b.lhead:SetPoint("TOPLEFT", -4, 0) b.lhead:SetPoint("TOPRIGHT", 4, 0)
  b.listings = list(b.listP.body, { 80, 70 }, nil, function(r, it)
    r:Set(nil, coins(it.price), ns.Num(it.qty), it.tag or "")
    r:Mark(it.deal)
  end)
  b.listings:SetPoint("TOPLEFT", b.lhead, "BOTTOMLEFT", 0, -2)
  b.listings:SetPoint("BOTTOMRIGHT", b.listP.body, "BOTTOMRIGHT", 4, 0)
end

function W:DoSearch()
  local b = self.buyP
  b.sel = nil          -- (1.4.59) a new search doesn't keep the old item
  AH.Drop()
  AH.Search(b.box:GetText())
  b.box.edit:ClearFocus()
  self:DrawBuy()
end

function W:SelectBuy(it)
  local b = self.buyP
  b.sel = it
  AH.Drop()
  b.qty:SetText("1")
  if it.itemKey and AH.open then AH.Ask(AH.ResultReq(it), function() W:DrawBuy() end, true, true) end
  self:DrawBuy()
end

-- any item's price, with or without the auction house open (/chill price, Alt-click)
function W:ShowPrice(id)
  if not id then return end
  local name, q, icon, link = itemName(id)
  self:Create()
  if not self.frame:IsShown() then
    self:Place()
    self.frame:Show()
  end
  self:Show(2)
  local it = { itemID = id, name = name, quality = q, icon = icon, link = link }
  if AH.open then
    local req = AH.ShopReq({ id = id })
    it.itemKey, it.commodity = req.itemKey or C_AuctionHouse.MakeItemKey(id), req.commodity
  end
  self:SelectBuy(it)
end

function W:DrawBuy()
  local b = self.buyP
  if not b then return end
  for _, c in ipairs(b.chips) do c:Hide() end
  local d = AH.DB()
  local x, n = 0, 0
  local maxW = BUY_LEFT - 20
  local function chip(text, saved)
    n = n + 1
    local c = b.chips[n]
    if not c then
      c = button(b.chipRow, 10, 20, "", "mkGhost")
      c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      b.chips[n] = c
    end
    c:SetLabel(saved and ("★ " .. text) or text)
    c:SetStyle(saved and "mkSec" or "mkGhost")
    local w = math.ceil(c.label:GetStringWidth()) + 18
    if x + w > maxW then return end
    c:SetWidth(w)
    c:ClearAllPoints()
    c:SetPoint("LEFT", x, 0)
    c:SetScript("OnClick", function(_, button)
      if button == "RightButton" and saved then
        for i = #d.saved, 1, -1 do if d.saved[i] == text then table.remove(d.saved, i) end end
        W:DrawBuy()
        return
      end
      b.box:SetText(text)
      W:DoSearch()
    end)
    c:Show()
    x = x + w + 5
  end
  for _, t in ipairs(d.saved) do chip(t, true) end
  local savedSet = {}
  for _, t in ipairs(d.saved) do savedSet[t:lower()] = true end
  for _, t in ipairs(d.recent) do if not savedSet[t:lower()] then chip(t, false) end end

  b.resP.right:SetText(#AH.results > 0 and (#AH.results .. " found") or "")
  b.results.emptyText = AH.searching and "Searching …" or (AH.open and (AH.searchText and "Nothing found." or "Search for an item by name.") or "Open the auction house to search.\n\n/chill price <name> or Alt-click an item shows its price graph.")
  b.results:SetData(AH.results)

  local sel = b.sel
  local rows = {}
  if sel then
    local key = sel.itemKey and AH.KeyOf(sel.itemKey, sel.commodity, sel.itemID)
    local g = AH.GangBefore(sel.itemID)
    b.itemP:SetTitle(sel.name or ("item " .. sel.itemID))
    local L = key and AH.Listing(key)
    local cheapest = (key and AH.Cheapest(key)) or sel.minPrice
    local bits = {}
    if cheapest then bits[#bits + 1] = dim("Cheapest ") .. coins(cheapest) end
    if g then bits[#bits + 1] = dim("Gang price ") .. coins(g) end
    if cheapest and g and g > 0 then
      local pct = math.floor((cheapest - g) / g * 100 + 0.5)
      bits[#bits + 1] = ns.Colorize((pct > 0 and "+" or pct < 0 and "−" or "") .. math.abs(pct) .. " %" .. (pct <= -5 and " · a deal" or ""),
        pct <= -5 and C.green or pct >= 5 and C.red or C.muted)
    end
    b.stats:SetText(#bits > 0 and table.concat(bits, "     ") or dim("No price yet."))
    b.chart.title:SetText("Price, last 14 days")
    b.chart:SetData(ns.Market.History(sel.itemID, 14), 14)
    if L and L.rows then
      for _, r in ipairs(L.rows) do
        local mine = r.own >= r.qty
        local deal = g and r.price <= g * 0.9 and not mine
        rows[#rows + 1] = { price = r.price, qty = r.qty - r.own, own = r.own, auctionID = r.auctionID,
          tag = mine and ns.Colorize("yours", C.amber) or deal and ns.Colorize("deal", C.green) or "", deal = deal }
      end
    end
    b.listings.emptyText = not AH.open and "Open the auction house to see the listings." or (L and "Nothing listed." or "Asking the auction house …")
  else
    b.itemP:SetTitle("Pick a result")
    b.stats:SetText(dim("Pick a result to see its price graph and listings."))
    b.chart.title:SetText("")
    b.chart:SetData({}, 14)
    b.listings.emptyText = ""
  end
  b.rowsNow = rows
  b.listings:SetData(rows)
  self:PaintBuyBar()
end

local function costOf(rows, n)
  local got, total = 0, 0
  for _, r in ipairs(rows or {}) do
    if r.qty > 0 then
      local take = math.min(r.qty, n - got)
      got, total = got + take, total + take * r.price
      if got >= n then break end
    end
  end
  return total, got
end
W.CostOf = costOf

function W:PaintBuyBar()
  local b = self.buyP
  if not b then return end
  local sel = b.sel
  local state, quoted = AH.Buying()
  b.wish:SetEnabled(sel ~= nil)
  if not sel or not sel.itemKey then
    b.for_:SetText("")
    b.buyBtn:SetEnabled(false)
    b.buyBtn:SetLabel("Buy")
    return
  end
  local n = math.max(1, tonumber(b.qty:GetText()) or 1)
  if not sel.commodity then n = 1 end
  local total, got = costOf(b.rowsNow, n)
  if got > 0 then
    b.for_:SetText(dim("for ") .. coins(total) .. (got > 1 and dim("   avg ") .. coins(math.floor(total / got)) or "") .. (got < n and dim("  (only " .. got .. ")") or ""))
  else
    b.for_:SetText(dim("nothing to buy"))
  end
  if state == "quoted" then b.buyBtn:SetLabel("Confirm " .. ns.Money(quoted or total))
  elseif state then b.buyBtn:SetLabel("Buying …")
  else b.buyBtn:SetLabel("Buy") end
  b.buyBtn:SetEnabled(got > 0 and AH.open and (state == nil or state == "quoted"))
end

function W:DoBuy()
  local b = self.buyP
  local sel = b.sel
  if not sel or not sel.itemKey then return end
  local state = AH.Buying()
  if state == "quoted" then AH.Confirm() self:PaintBuyBar() return end
  if state then return end
  local key = AH.KeyOf(sel.itemKey, sel.commodity, sel.itemID)
  local function after() C_Timer.After(0.3, function() AH.Ask(AH.ResultReq(sel), function() W:DrawBuy() end, true, true) end) end
  if sel.commodity then
    local n = math.max(1, tonumber(b.qty:GetText()) or 1)
    local _, got = costOf(b.rowsNow, n)
    if got <= 0 then return end
    AH.Quote(key, sel.itemID, got, nil, after)
  else
    for _, r in ipairs(b.rowsNow or {}) do
      if r.auctionID and r.qty > 0 then AH.BuyItem(key, r.auctionID, r.price, after) break end
    end
  end
  self:PaintBuyBar()
end

---------------------------------------------------------------------------
-- My auctions
---------------------------------------------------------------------------
function W:BuildAuctions(p)
  local a = {}
  self.aucP = a
  a.tiles = {}
  local tw = math.floor((WIDTH - 2 * PAD - 20) / 3)
  local accents = { BLUE, C.red, C.green }
  for i = 1, 3 do
    local t = UI.Panel(p, PANELc(), PLINEc(), true)
    t:SetSize(tw, 52)
    t:SetPoint("TOPLEFT", (i - 1) * (tw + 10), 0)
    local acc = solid(t, accents[i], "ARTWORK")
    acc:SetHeight(2)
    acc:SetPoint("TOPLEFT", 1, -1) acc:SetPoint("TOPRIGHT", -1, -1)
    t.v = UI.Text(t, 17, "semi", C.text)
    t.v:SetPoint("TOPLEFT", 12, -10)
    t.k = UI.Text(t, 11, nil, C.dim)
    t.k:SetPoint("BOTTOMLEFT", 12, 8)
    a.tiles[i] = t
  end
  a.filter = 1
  a.seg = seg(p, { "All", "Undercut", "Sold" }, function() return a.filter end, function(i) a.filter = i W:DrawAuctions() end)
  a.seg:SetPoint("TOPLEFT", 0, -64)
  a.cancel = button(p, 170, 26, "Cancel undercut", "mkRed", function()
    local x = AH.NextUndercut()
    if x then AH.Cancel(x) end
    W:DrawAuctions()
  end)
  a.cancel:SetPoint("TOPRIGHT", 0, -63)
  a.cancel.tooltip = "Cancels the next undercut auction, one per click (the game wants a click for each). The items come back by mail; then post them again from the Sell tab."
  a.check = button(p, 100, 26, "Check again", "mkSec", function() AH.CheckOwned(true) W:DrawAuctions() end)
  a.check:SetPoint("RIGHT", a.cancel, "LEFT", -8, 0)
  a.listP = panel(p, "Your auctions")
  a.listP:SetPoint("TOPLEFT", 0, -100)
  a.listP:SetPoint("BOTTOMRIGHT", 0, 0)
  local cols = { 86, 86, 130, 40 }
  a.head = header(a.listP.body, cols, nil, "Item", "Your price", "Cheapest", "Status", "Left")
  a.head:SetPoint("TOPLEFT", -4, 0) a.head:SetPoint("TOPRIGHT", 4, 0)
  a.list = list(a.listP.body, cols, nil, function(r, x)
    local st, by, other = AH.Status(x)
    local stText
    if x.cancelled then stText = dim("cancelled")
    elseif st == "sold" then stText = ns.Colorize("sold · in the mail", C.amber)
    elseif st == "undercut" then stText = ns.Colorize("undercut · " .. ns.Money(by), C.red)
    elseif st == "lowest" then stText = ns.Colorize("lowest", C.green)
    elseif st == "noanswer" then stText = dim("no answer")
    else stText = dim("checking …") end
    r:Set(x.icon, qhex(x.quality) .. (x.name or ("item " .. x.itemID)) .. "|r" .. (x.qty > 1 and dim("  ×" .. x.qty) or ""),
      x.price and coins(x.price) or "", other and coins(other) or dim("—"), stText, x.sold and "" or left(x.secs))
  end)
  a.list:SetPoint("TOPLEFT", a.head, "BOTTOMLEFT", 0, -2)
  a.list:SetPoint("BOTTOMRIGHT", a.listP.body, "BOTTOMRIGHT", 4, 0)
end

function W:DrawAuctions()
  local a = self.aucP
  if not a then return end
  if a.checkedFor ~= #AH.owned then
    a.checkedFor = #AH.owned
    AH.CheckOwned(false)
  end
  local listed, nListed, under, data = 0, 0, 0, {}
  for _, x in ipairs(AH.owned) do
    local st = AH.Status(x)
    if not x.sold and not x.cancelled then listed, nListed = listed + (x.price or 0) * (x.commodity and x.qty or 1), nListed + 1 end
    if st == "undercut" and not x.cancelled then under = under + 1 end
    if a.filter == 1 or (a.filter == 2 and st == "undercut") or (a.filter == 3 and st == "sold") then data[#data + 1] = x end
  end
  a.tiles[1].v:SetText(coins(listed))
  a.tiles[1].k:SetText("listed · " .. nListed .. " " .. (nListed == 1 and "auction" or "auctions"))
  a.tiles[2].v:SetText(under > 0 and ns.Colorize(tostring(under), C.red) or "0")
  a.tiles[2].k:SetText("undercut")
  a.tiles[3].v:SetText(coins((AH.SoldSince(7 * 86400))))
  a.tiles[3].k:SetText("sold last 7 days")
  a.cancel:SetLabel("Cancel undercut" .. (under > 0 and (" (" .. under .. ")") or ""))
  a.cancel:SetEnabled(under > 0)
  a.seg:Refresh()
  a.listP.right:SetText(#AH.owned .. " " .. (#AH.owned == 1 and "auction" or "auctions"))
  a.list.emptyText = AH.open and (a.filter == 1 and "No auctions." or "None here.") or "Open the auction house to see your auctions."
  a.list:SetData(data)
end

---------------------------------------------------------------------------
-- Item Tracker (yours only; was Wishlist): what it costs now, what it usually costs, how it moved,
-- how many are up, Buy; an optional alert; the price graph of the row you pick
---------------------------------------------------------------------------
local function resolveItem(text)
  text = tostring(text or "")
  local id = tonumber(text:match("item:(%d+)") or "")
  if id then return id end
  local name = text:gsub("|c%x+", ""):gsub("|r", ""):gsub("[%[%]]", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then return nil end
  if C_Item.GetItemInfoInstant then
    local okI, iid = pcall(C_Item.GetItemInfoInstant, name)
    if okI and type(iid) == "number" then return iid end
  end
  if ns.Market and ns.Market.Search then
    local hits = ns.Market:Search(name, 1)
    if hits and hits[1] then return hits[1].id end
  end
  return nil
end
W.ResolveItem = resolveItem

local function change(pts)
  if #pts < 2 or pts[1].v <= 0 then return nil end
  return math.floor((pts[#pts].v - pts[1].v) / pts[1].v * 100 + 0.5)
end
local function pctText(p)
  if not p then return dim("—") end
  return ns.Colorize((p > 0 and "+" or p < 0 and "−" or "") .. math.abs(p) .. " %", p < 0 and C.green or p > 0 and C.red or C.muted)
end

function W:BuildShop(p)
  local s = {}
  self.shopP = s
  s.add = edit(p, 360, "Track an item: type its name, or shift-click it", function() W:DoShopAdd() end)
  s.add:SetPoint("TOPLEFT", 0, 0)
  local al = UI.Text(p, 11, nil, C.dim)
  al:SetPoint("LEFT", s.add, "RIGHT", 10, 0)
  al:SetText("alert under")
  s.max = edit(p, 96, "no alert", function() W:DoShopAdd() end)
  s.max:SetPoint("LEFT", al, "RIGHT", 8, 0)
  s.addBtn = button(p, 64, 26, "Track", "mkSec", function() W:DoShopAdd() end)
  s.addBtn:SetPoint("LEFT", s.max, "RIGHT", 8, 0)
  s.msg = UI.Text(p, 11, nil, C.dim)
  s.msg:SetPoint("LEFT", s.addBtn, "RIGHT", 10, 0)

  s.listP = panel(p, "Item Tracker")
  s.listP:SetPoint("TOPLEFT", 0, -38)
  s.listP:SetPoint("TOPRIGHT", 0, -38)
  s.listP:SetHeight(270)
  local cols = { 96, 90, 64, 64 }
  s.head = header(s.listP.body, cols, 76, "Item", "Cheapest", "14-day avg", "7 days", "Available")
  s.head:SetPoint("TOPLEFT", -4, 0) s.head:SetPoint("TOPRIGHT", 4, 0)
  s.list = list(s.listP.body, cols, 76, function(r, it)
    local name, q, icon = itemName(it.id)
    local req = AH.ShopReq(it)
    local L = AH.Listing(req.key)
    local cheapest = L and AH.Cheapest(req.key)
    local avail = 0
    for _, row in ipairs(L and L.rows or {}) do avail = avail + math.max(0, row.qty - row.own) end
    local h14 = ns.Market.History(it.id, 14)
    local sum = 0
    for _, pt in ipairs(h14) do sum = sum + pt.v end
    local under = it.alert and cheapest and cheapest <= it.alert
    r:Set(icon, qhex(q) .. (name or ("item " .. it.id)) .. "|r" .. (it.alert and dim("  alert " .. W.MoneyText(it.alert)) or ""),
      cheapest and coins(cheapest) or (L and dim("none up") or dim("not checked")),
      #h14 > 0 and coins(math.floor(sum / #h14)) or dim("—"),
      pctText(change(ns.Market.History(it.id, 7))),
      L and ns.Num(avail) or dim("—"))
    r:Mark(s.selId == it.id)
    r.alt:SetShown(not under and r.alt:IsShown())
    if under then r.bg:SetColorTexture(0.37, 0.82, 0.55, 0.14) r.bg:Show()
    else do local ar, ag, ab = hex(C.accent) r.bg:SetColorTexture(ar, ag, ab, 0.13) end end
    r.btn:SetScript("OnClick", nil)
    r.btn:Hide() r.pill:Hide()
    local state, _, bkey = AH.Buying()
    local mine = bkey == req.key
    if mine and state == "quoted" then
      r.btn:Show() r.btn:SetLabel("Confirm") r.btn:SetStyle("mkPri") r.btn:SetEnabled(true)
      r.btn:SetScript("OnClick", function() AH.Confirm() W:DrawShop() end)
    elseif mine and state then r.pill:Show() pill(r.pill, "buying …", C.muted)
    elseif cheapest and avail > 0 then
      r.btn:Show() r.btn:SetLabel("Buy") r.btn:SetStyle(under and "mkPri" or "mkSec") r.btn:SetEnabled(AH.open and not state)
      r.btn.tooltip = "Buy the cheapest one (" .. ns.Money(cheapest) .. ")."
      r.btn:SetScript("OnClick", function() W:ShopBuy(it) end)
    else r.pill:Show() pill(r.pill, "—", C.dim) end
  end, function(it, button, row)
    if button == "RightButton" then
      local name = itemName(it.id) or ("item " .. it.id)
      local items = {
        { text = it.alert and "Change the alert" or "Set an alert", func = function()
          UI.Prompt("Alert: " .. name, { { label = "Tell me when it's under", placeholder = "190g", value = it.alert and W.MoneyText(it.alert) or "" } },
            function(v) AH.SetAlert(it.id, v and v ~= "" and parseMoney(v) or nil) W:DrawShop() end)
        end },
      }
      if it.alert then items[#items + 1] = { text = "Remove the alert", func = function() AH.SetAlert(it.id, nil) W:DrawShop() end } end
      items[#items + 1] = { text = "Stop tracking", func = function() AH.ShopRemove(it.id) if s.selId == it.id then s.selId = nil end W:DrawShop() end }
      UI.Menu(row, items)
      return
    end
    s.selId = it.id
    W:DrawShop()
  end)
  s.list:SetPoint("TOPLEFT", s.head, "BOTTOMLEFT", 0, -2)
  s.list:SetPoint("BOTTOMRIGHT", s.listP.body, "BOTTOMRIGHT", 4, 36)
  s.list.emptyText = "Nothing tracked yet. Type an item's name above, or shift-click it, and set a price to be told about."
  local fl = solid(s.listP.body, PLINEc(), "ARTWORK")
  fl:SetHeight(1)
  fl:SetPoint("BOTTOMLEFT", -4, 32) fl:SetPoint("BOTTOMRIGHT", 4, 32)
  s.sum = UI.Text(s.listP.body, 12, nil, C.muted)
  s.sum:SetPoint("BOTTOMLEFT", 2, 6)
  s.check = button(s.listP.body, 140, 26, "Check prices", "mkSec", function()
    for _, it in ipairs(AH.ShopList()) do AH.Ask(AH.ShopReq(it), function() W:DrawShop() end, true) end
    W:DrawShop()
  end)
  s.check:SetPoint("BOTTOMRIGHT", 0, 0)

  s.range = 2
  s.graphP = panel(p, "Price", BLUE)
  s.graphP:SetPoint("TOPLEFT", s.listP, "BOTTOMLEFT", 0, -10)
  s.graphP:SetPoint("BOTTOMRIGHT", 0, 0)
  s.rangeSeg = seg(s.graphP, { "7d", "14d", "30d" }, function() return s.range end, function(i) s.range = i W:DrawShop() end)
  s.rangeSeg:SetPoint("RIGHT", s.graphP.strip, "RIGHT", -4, 0)
  s.rangeSeg:SetHeight(20)
  s.chart = makeChart(s.graphP.body)
  s.chart:SetPoint("TOPLEFT", 0, 0)
  s.chart:SetPoint("BOTTOMRIGHT", -200, 0)
  s.side = {}
  for i, k in ipairs({ "Average", "Alert under", "Trend" }) do
    local l = UI.Text(s.graphP.body, 12, nil, C.dim)
    l:SetPoint("TOPRIGHT", -100, -(i - 1) * 22)
    l:SetJustifyH("LEFT")
    l:SetWidth(90)
    l:SetText(k)
    local v = UI.Text(s.graphP.body, 12, nil, C.text)
    v:SetPoint("TOPRIGHT", 0, -(i - 1) * 22)
    v:SetJustifyH("RIGHT")
    s.side[i] = v
  end

  -- shift-click an item into the box; Alt-click an item anywhere: its price graph
  if ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", function(link)
      if s.add.edit:HasFocus() and type(link) == "string" then s.add:SetText(link) end
    end)
  end
  if HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", function(link)
      if type(link) ~= "string" or not IsAltKeyDown() or IsShiftKeyDown() or IsControlKeyDown() then return end
      if not AH.On() then return end
      local id = tonumber(link:match("item:(%d+)") or "")
      if id then W:ShowPrice(id) end
    end)
  end
end

-- buy the cheapest one of a tracked item (stackables: quote, then Confirm)
function W:ShopBuy(it)
  local req = AH.ShopReq(it)
  local function after() C_Timer.After(0.3, function() AH.Ask(req, function() W:DrawShop() end, true, true) end) end
  if req.commodity then
    AH.Quote(req.key, it.id, 1, nil, after)
  else
    local L = AH.Listing(req.key)
    for _, r in ipairs(L and L.rows or {}) do
      if r.auctionID and r.qty > r.own then AH.BuyItem(req.key, r.auctionID, r.price, after) break end
    end
  end
  self:DrawShop()
end

function W:DoShopAdd()
  local s = self.shopP
  local id = resolveItem(s.add:GetText())
  if not id then s.msg:SetText(ns.Colorize("Couldn't find that item. Shift-click it, or type its exact name.", C.red)) return end
  local alert = s.max:GetText() ~= "" and parseMoney(s.max:GetText()) or nil
  AH.ShopAdd(id, alert)
  s.selId = id
  s.add:SetText("") s.max:SetText("")
  s.add.edit:ClearFocus() s.max.edit:ClearFocus()
  s.msg:SetText(dim("Tracking. Right-click a row for its alert or to stop."))
  if AH.open then AH.Ask(AH.ShopReq({ id = id }), function() W:DrawShop() end, true, true) end
  self:DrawShop()
end

function W:DrawShop()
  local s = self.shopP
  if not s then return end
  local l = AH.ShopList()
  local under = 0
  for _, it in ipairs(l) do
    local key = AH.ShopReq(it).key
    local cheapest = AH.Listing(key) and AH.Cheapest(key)
    if it.alert and cheapest and cheapest <= it.alert then under = under + 1 end
  end
  s.listP.right:SetText(#l .. " " .. (#l == 1 and "item" or "items"))
  s.sum:SetText(#l == 0 and "" or (under > 0 and ns.Colorize(under .. " under your alert", C.green) or dim("none under an alert right now")))
  s.check:SetLabel("Check prices" .. (#l > 0 and (" (" .. #l .. ")") or ""))
  s.check:SetEnabled(AH.open and #l > 0)
  if not s.selId and l[1] then s.selId = l[1].id end
  s.list:SetData(l)
  local sel
  for _, it in ipairs(l) do if it.id == s.selId then sel = it end end
  local days = ({ 7, 14, 30 })[s.range] or 14
  s.rangeSeg:Refresh()
  if sel then
    local name = itemName(sel.id)
    s.graphP:SetTitle("Price · " .. (name or ("item " .. sel.id)))
    local pts = ns.Market.History(sel.id, days)
    s.chart.title:SetText("Last " .. days .. " days")
    s.chart:SetData(pts, days)
    local sum = 0
    for _, pt in ipairs(pts) do sum = sum + pt.v end
    s.side[1]:SetText(#pts > 0 and coins(math.floor(sum / #pts)) or dim("—"))
    s.side[2]:SetText(sel.alert and coins(sel.alert) or dim("none"))
    local tr = AH.Trend(pts)
    s.side[3]:SetText(tr and ns.Colorize(tr, tr == "falling" and C.green or tr == "rising" and C.red or C.muted) or dim("—"))
  else
    s.graphP:SetTitle("Price")
    s.chart.title:SetText("")
    s.chart:SetData({}, days)
    for _, v in ipairs(s.side) do v:SetText("") end
  end
end

---------------------------------------------------------------------------
-- Gang
---------------------------------------------------------------------------
local BOARDS = {
  { "Made the most gold", function(x) return x.g end, function(v) return coins(math.floor(v / 10000) * 10000) end },
  { "Sold the most items", function(x) return x.i end, function(v) return ns.Num(v) end },
  { "Most auctions posted", function(x) return x.p end, function(v) return ns.Num(v) end },
  { "Best sell-through", function(x) return (x.p or 0) >= 3 and math.min(100, math.floor((x.s or 0) / x.p * 100 + 0.5)) or nil end, function(v) return v .. " %" end },
}

function W:BuildGang(p)
  local g = {}
  self.gangP = g
  g.range = 1
  g.seg = seg(p, { "This week", "Last week", "All time" }, function() return g.range end, function(i) g.range = i W:DrawGang() end)
  g.seg:SetPoint("TOPLEFT", 0, 0)
  g.note = UI.Text(p, 11, nil, C.dim)
  g.note:SetPoint("TOPRIGHT", -22, -6)
  g.tip = UI.InfoTip(p, g.note, "Gang market stats",
    "Gold is what reached the mailbox after the auction house's 5 % cut. Sell-through is auctions sold out of auctions posted (from 3 posts). Each friend's Chillan shares only its own totals and its three biggest sales of the week. Sales are counted when you visit the auction house.")
  g.boards = {}
  local bw = math.floor((WIDTH - 2 * PAD - 10) / 2)
  for i, def in ipairs(BOARDS) do
    local b = panel(p, def[1])
    b:SetSize(bw, 152)
    b:SetPoint("TOPLEFT", ((i - 1) % 2) * (bw + 10), -34 - math.floor((i - 1) / 2) * 162)
    b.rows = {}
    for k = 1, 5 do
      local y = -(k - 1) * 21
      local r = {}
      r.n = UI.Text(b.body, 12, "semi", k == 1 and C.amber or C.dim)
      r.n:SetPoint("TOPLEFT", 0, y)
      r.n:SetText(tostring(k))
      r.who = UI.Text(b.body, 12, "semi", C.text)
      r.who:SetPoint("TOPLEFT", 18, y)
      r.who:SetWidth(90)
      r.who:SetJustifyH("LEFT")
      r.who:SetWordWrap(false)
      r.track = solid(b.body, C.active, "ARTWORK")
      r.track:SetHeight(6)
      r.track:SetPoint("TOPLEFT", 112, y - 4)
      r.track:SetPoint("TOPRIGHT", -96, y - 4)
      r.bar = solid(b.body, k == 1 and C.amber or "6B6355", "OVERLAY")
      r.bar:SetHeight(6)
      r.bar:SetPoint("TOPLEFT", r.track, "TOPLEFT")
      r.v = UI.Text(b.body, 12, nil, C.text)
      r.v:SetPoint("TOPRIGHT", 0, y)
      r.v:SetJustifyH("RIGHT")
      b.rows[k] = r
    end
    b.empty = UI.Text(b.body, 11, nil, C.dim)
    b.empty:SetPoint("CENTER")
    g.boards[i] = b
  end
  g.salesP = panel(p, "Biggest sales this week")
  g.salesP:SetPoint("TOPLEFT", 0, -366)
  g.salesP:SetPoint("BOTTOMRIGHT", 0, 22)
  g.sales = list(g.salesP.body, { 96, 60 }, nil, function(r, it)
    local name, q, icon = itemName(it.id)
    r:Set(icon, ns.Colorize(it.who, it.col) .. "   " .. qhex(q) .. (name or ("item " .. it.id)) .. "|r" .. (it.q > 1 and dim("  ×" .. it.q) or ""),
      coins(it.g), dim(ns.Ago(it.at)))
  end)
  g.sales:SetAllPoints(g.salesP.body)
  g.sales.emptyText = "No sales yet."
  g.mine = UI.Text(p, 11, nil, C.dim)
  g.mine:SetPoint("BOTTOMLEFT", 0, 2)
end

function W:GangRows(range)
  local out = {}
  local wk, pwk = ns.WeekKey(), ns.PrevWeekKey()
  local me = ns.db.people and ns.db.people[ns.pid]
  local function who(p)
    local name = (p and ns:PersonFirst(p)) or ns.ShortName(ns.Comm:MyFull() or "You")
    local ch = p and ns:PersonChar(p)
    return name, (ch and ch.class and ns.ClassHex(ch.class)) or C.text
  end
  local s = AH.Stats()
  local mine = range == 1 and s.w or range == 2 and (s.pw and s.pw.wk == pwk and s.pw or nil) or s.t
  local n, col = who(me)
  out[#out + 1] = { name = n, col = col, me = true, x = mine or { g = 0, i = 0, s = 0, p = 0 }, tops = range == 1 and AH.TopSales(ns.MondayOf(ns.Now()), 3) or {} }
  local dup = ns:HiddenDuplicates() or {}
  for pid, p in pairs(ns.db.people or {}) do
    if pid ~= ns.pid and p.mk and not dup[pid] then
      local mk, x = p.mk, nil
      if range == 1 then x = mk.wk == wk and mk.w or nil
      elseif range == 2 then x = (mk.wk == wk and mk.pwk == pwk and mk.pw) or (mk.wk == pwk and mk.w) or nil
      else x = mk.t end
      local nm, c = who(p)
      local tops = (range == 1 and mk.wk == wk) and mk.tops or {}
      -- (1.4.72) a friend still on an older Chillan sends stack sales counted too big: put the ones we can
      -- see right, and take the difference off their total
      if x and not (p.version and not ns.NewerVersion("1.4.72", p.version)) then
        local fixedTops, cut = {}, 0
        for _, t in ipairs(tops) do
          local g = AH.FixStack(t.id, t.q, t.g)
          cut = cut + (t.g - g)
          fixedTops[#fixedTops + 1] = { id = t.id, q = t.q, g = g, at = t.at }
        end
        tops = fixedTops
        if cut > 0 then x = { g = math.max(0, (x.g or 0) - cut), i = x.i, s = x.s, p = x.p } end
      end
      out[#out + 1] = { name = nm, col = c, x = x or { g = 0, i = 0, s = 0, p = 0 }, tops = tops }
    end
  end
  return out
end

function W:DrawGang()
  local g = self.gangP
  if not g then return end
  AH.AskGang()
  g.seg:Refresh()
  local rows = self:GangRows(g.range)
  g.note:SetText(#rows .. " " .. (#rows == 1 and "friend" or "friends") .. " · after the 5 % cut")
  g.tip:ClearAllPoints()
  g.tip:SetPoint("LEFT", g.note, "RIGHT", 6, 0)
  local myPlaces = {}
  for bi, def in ipairs(BOARDS) do
    local b = g.boards[bi]
    local ranked = {}
    for _, r in ipairs(rows) do
      local v = def[2](r.x)
      if v and v > 0 then ranked[#ranked + 1] = { r = r, v = v } end
    end
    table.sort(ranked, function(a, c) return a.v > c.v end)
    local top = ranked[1] and ranked[1].v or 1
    for k, row in ipairs(b.rows) do
      local e = ranked[k]
      local on = e ~= nil
      row.n:SetShown(on) row.who:SetShown(on) row.track:SetShown(on) row.v:SetShown(on) row.bar:SetShown(on)
      if e then
        row.who:SetText(ns.Colorize(e.r.name, e.r.col))
        row.v:SetText(def[3](e.v))
        local tw = row.track:GetWidth()
        if not tw or tw <= 0 then tw = 100 end
        row.bar:SetWidth(math.max(2, tw * e.v / top))
      end
    end
    b.empty:SetText(#ranked == 0 and "Nothing yet" or "")
    for k, e in ipairs(ranked) do if e.r.me then myPlaces[bi] = k end end
  end
  local sales = {}
  for _, r in ipairs(rows) do
    for _, t in ipairs(r.tops or {}) do sales[#sales + 1] = { who = r.name, col = r.col, id = t.id, q = t.q, g = t.g, at = t.at } end
  end
  table.sort(sales, function(a, c) return a.g > c.g end)
  while #sales > 5 do table.remove(sales) end
  g.salesP:SetTitle(g.range == 1 and "Biggest sales this week" or "Biggest sales (this week only)")
  g.sales:SetData(g.range == 1 and sales or {})
  local function ord(n) return n == 1 and "1st" or n == 2 and "2nd" or n == 3 and "3rd" or (n .. "th") end
  local parts = {}
  local names = { "gold", "items sold", "posts", "sell-through" }
  for bi = 1, 4 do if myPlaces[bi] then parts[#parts + 1] = ord(myPlaces[bi]) .. " in " .. names[bi] end end
  g.mine:SetText(#parts > 0 and (dim("Your line: ") .. ns.Colorize(table.concat(parts, " · "), C.text)) or dim("Your line: post something to get on the boards"))
end

---------------------------------------------------------------------------
-- opening beside the auction house
---------------------------------------------------------------------------
function W:Place()
  local f = self.frame
  local host = _G.AuctionHouseFrame
  f:ClearAllPoints()
  if host and host:IsShown() then
    f:SetPoint("TOPLEFT", host, "TOPRIGHT", 6, 0)
    local h = host:GetHeight()
    f:SetHeight((h and not ns.isSecret(h) and h > MIN_H) and h or MIN_H)
  else
    f:SetHeight(MIN_H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

function W:PaintReopen()
  local host = _G.AuctionHouseFrame
  if not host then return end
  if not self.reopen then
    local b = UI.Button(host, 120, 22, "Chillan? Market", "mkSec", function()
      W.closedThisVisit = nil
      W:Open()
    end)
    b:SetPoint("TOPLEFT", host, "TOPRIGHT", 4, -2)
    b:SetFrameStrata("HIGH")
    self.reopen = b
  end
  self.reopen:SetShown(AH.On() and AH.open and not (self.frame and self.frame:IsShown()))
end

function W:Open()
  if not AH.On() then return end
  self:Create()
  self:Place()
  self.frame:Show()
  self.sellQueue = nil
  self:Show(self.tab or 1)
  self:PaintReopen()
end

ns:Listen("MKAH", function(what)
  if what == "open" then
    W.closedThisVisit = nil
    W.skipped, W.skipN = nil, nil
    C_Timer.After(0.2, function()
      if AH.On() and not W.closedThisVisit then W:Open() else W:PaintReopen() end
    end)
  elseif what == "closed" then
    if W.frame then W.frame:Hide() end
    if W.reopen then W.reopen:Hide() end
    if W.sell then W.sell.cur = nil end
    if W.buyP then W.buyP.sel = nil end
  end
end)
