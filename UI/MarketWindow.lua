-- Chillan? – the Market window beside the auction house (1.4.57)
-- Five tabs, as on the canvas: Sell (your bags as a queue, most valuable first), Buy (search by
-- name, saved and recent searches, listings, buy), My auctions (undercut check and cancel),
-- Shopping (your own list) and Gang (who made the most gold, sold the most, posted the most).
-- The game wants a real click for every post, buy and cancel: every one of them is a button.
local ADDON, ns = ...
local UI, C = ns.UI, ns.C
local hex = ns.hex
local AH = ns.AH

local W = ns.MarketWin or {}
ns.MarketWin = W

local WIDTH, MIN_H = 600, 600
local PAD = 12
local ROW_H, GAP = 20, 2
local TABS = { "Sell", "Buy", "My auctions", "Shopping", "Gang" }

local function dim(t) return ns.Colorize(t, C.dim) end
local function coins(c) return ns.Market and ns.Market.Coins and ns.Market.Coins(c or 0) or tostring(c or 0) end
local function qhex(q)
  local c = ITEM_QUALITY_COLORS and q and ITEM_QUALITY_COLORS[q]
  return c and c.hex or "|cffe8eaed"
end
local function itemName(id)
  local okI, name, _, q, _, _, _, _, _, _, icon = pcall(C_Item.GetItemInfo, id)
  if okI and name then return name, q, icon end
  return nil
end
local function left(secs)
  if not secs or secs <= 0 then return "" end
  if secs >= 3600 then return math.floor(secs / 3600) .. "h" end
  return math.max(1, math.floor(secs / 60)) .. "m"
end
-- "1g 20s 5c" for an edit box
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
-- small pieces
---------------------------------------------------------------------------
local function section(parent, text)
  local t = UI.Text(parent, 10, "semi", C.dim)
  t:SetText(text:upper())
  return t
end

-- a list row: icon + name on the left, right-aligned columns, an optional button at the end
local function makeRow(parent, cols, btnW)
  local r = CreateFrame("Button", nil, parent)
  r:SetHeight(ROW_H)
  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints()
  r.bg:SetColorTexture(0.88, 0.69, 0.31, 0.10)
  r.bg:Hide()
  r.hl = r:CreateTexture(nil, "HIGHLIGHT")
  r.hl:SetAllPoints()
  r.hl:SetColorTexture(1, 1, 1, 0.04)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(16, 16)
  r.icon:SetPoint("LEFT", 4, 0)
  r.name = UI.Text(r, 12, nil, C.text)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)
  r.cols = {}
  local x = -4
  if btnW then
    r.btn = UI.Button(r, btnW, ROW_H - 2, "", "secondary")
    r.btn:SetPoint("RIGHT", x, 0)
    x = x - btnW - 8
  end
  for i = #cols, 1, -1 do
    local t = UI.Text(r, 12, nil, C.text2)
    t:SetJustifyH("RIGHT")
    t:SetWordWrap(false)
    t:SetWidth(cols[i])
    t:SetPoint("RIGHT", x, 0)
    r.cols[i] = t
    x = x - cols[i] - 8
  end
  r.name:SetPoint("RIGHT", r, "RIGHT", x, 0)
  function r:Set(icon, name, ...)
    if icon then self.icon:SetTexture(icon) self.icon:Show() else self.icon:Hide() end
    self.name:SetText(name or "")
    for i, t in ipairs(self.cols) do t:SetText((select(i, ...)) or "") end
  end
  return r
end

local function header(parent, cols, btnW, first)
  local h = CreateFrame("Frame", nil, parent)
  h:SetHeight(16)
  local r = makeRow(h, cols, nil)
  r:SetAllPoints()
  r:EnableMouse(false)
  for _, t in ipairs(r.cols) do t:SetFont(ns.FONT, 10, "") t:SetTextColor(hex(C.dim)) end
  r.name:SetFont(ns.FONT, 10, "")
  r.name:SetTextColor(hex(C.dim))
  r.icon:SetSize(1, 16)
  if btnW then
    for _, t in ipairs(r.cols) do local p, rel, rp, x, y = t:GetPoint(1) t:SetPoint(p, rel, rp, x - btnW - 8, y) end
  end
  local line = h:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT") line:SetPoint("BOTTOMRIGHT")
  line:SetColorTexture(hex(C.line))
  h.r = r
  function h:Set(...) r:Set(nil, first, ...) end
  return h
end

local function list(parent, cols, btnW, update, onClick)
  local l = UI.List(parent, ROW_H, GAP, function(self)
    local r = makeRow(self, cols, btnW)
    r:SetScript("OnClick", function(row, button) if onClick and row.item then onClick(row.item, button, row) end end)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnEnter", function(row)
      if row.item and row.item.link then
        GameTooltip:SetOwner(row, "ANCHOR_LEFT")
        pcall(GameTooltip.SetHyperlink, GameTooltip, row.item.link)
        GameTooltip:Show()
      elseif row.item and row.item.itemID and GameTooltip.SetItemByID then
        GameTooltip:SetOwner(row, "ANCHOR_LEFT")
        pcall(GameTooltip.SetItemByID, GameTooltip, row.item.itemID)
        GameTooltip:Show()
      end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
  end, update)
  return l
end

local function seg(parent, opts, get, set)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(22)
  f.btns = {}
  local x = 0
  for i, o in ipairs(opts) do
    local b = UI.Button(f, 0, 22, o, "ghost", function() set(i) f:Refresh() end)
    local w = math.max(44, math.ceil(b.label:GetStringWidth()) + 18)
    b:SetWidth(w)
    b:SetPoint("LEFT", x, 0)
    x = x + w + 2
    f.btns[i] = b
  end
  f:SetWidth(x)
  function f:Refresh() for i, b in ipairs(self.btns) do b:SetStyle(get() == i and "secondary" or "ghost") end end
  f:Refresh()
  return f
end

local function edit(parent, w, placeholder, onEnter)
  local e = UI.EditBox(parent, w, 24, placeholder, onEnter)
  e.edit:SetFont(ns.FONT, 12, "")
  e.edit.ph:SetFont(ns.FONT, 12, "")
  return e
end

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
  local bg = UI.Panel(f, C.window, C.line)
  bg:SetAllPoints()
  bg:SetFrameLevel(f:GetFrameLevel())

  local title = UI.Text(f, 13, "semi", C.text)
  title:SetPoint("TOPLEFT", PAD, -10)
  title:SetText("Chillan" .. ns.Colorize("?", C.amber) .. " " .. ns.Colorize("Market", C.muted))
  local close = UI.IconButton(f, 22, "Close", nil, function() W.closedThisVisit = true f:Hide() W:PaintReopen() end)
  close:SetPoint("TOPRIGHT", -6, -5)
  close.tooltip = "Close for this visit. The \"Chillan? Market\" tab on the auction house opens it again."

  -- tabs
  self.tabBtns = {}
  local x = 4
  for i, name in ipairs(TABS) do
    local b = CreateFrame("Button", nil, f)
    b.text = UI.Text(b, 12, nil, C.muted)
    b.text:SetPoint("CENTER", 0, 1)
    b.text:SetText(name)
    local w = math.ceil(b.text:GetStringWidth()) + 24
    b:SetSize(w, 28)
    b:SetPoint("TOPLEFT", x, -30)
    x = x + w
    b.line = b:CreateTexture(nil, "ARTWORK")
    b.line:SetHeight(2)
    b.line:SetPoint("BOTTOMLEFT", 6, 0) b.line:SetPoint("BOTTOMRIGHT", -6, 0)
    b.line:SetColorTexture(hex(C.amber))
    b:SetScript("OnClick", function() W:Show(i) end)
    self.tabBtns[i] = b
  end
  local sep = f:CreateTexture(nil, "ARTWORK")
  sep:SetHeight(1)
  sep:SetPoint("TOPLEFT", 0, -58) sep:SetPoint("TOPRIGHT", 0, -58)
  sep:SetColorTexture(hex(C.line))

  -- footer
  local fsep = f:CreateTexture(nil, "ARTWORK")
  fsep:SetHeight(1)
  fsep:SetPoint("BOTTOMLEFT", 0, 26) fsep:SetPoint("BOTTOMRIGHT", 0, 26)
  fsep:SetColorTexture(hex(C.line))
  self.status = UI.Text(f, 11, nil, C.dim)
  self.status:SetPoint("BOTTOMLEFT", PAD, 8)
  self.gold = UI.Text(f, 11, nil, C.dim)
  self.gold:SetPoint("BOTTOMRIGHT", -PAD, 8)

  self.pages = {}
  for i = 1, #TABS do
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", PAD, -68)
    p:SetPoint("BOTTOMRIGHT", -PAD, 34)
    p:Hide()
    self.pages[i] = p
  end
  self:BuildSell(self.pages[1])
  self:BuildBuy(self.pages[2])
  self:BuildAuctions(self.pages[3])
  self:BuildShop(self.pages[4])
  self:BuildGang(self.pages[5])

  ns:Listen("MKAH", function(what) W:OnChange(what) end)
  ns:Listen("MARKET", function() if f:IsShown() then W:PaintFooter() end end)
  f:SetScript("OnShow", function() W:Refresh() end)
end

function W:PaintFooter()
  local M = ns.Market
  if M then
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
  local t = self.tab or 1
  if t == 1 then self:DrawSell() elseif t == 2 then self:DrawBuy() elseif t == 3 then self:DrawAuctions()
  elseif t == 4 then self:DrawShop() else self:DrawGang() end
end

function W:OnChange(what)
  if not self.frame or not self.frame:IsShown() then return end
  if what == "posted" or what == "bought" then self.bagsDirty = true end
  if self.tab == 3 and what == "listing" then
    -- many answers arrive while checking: draw at most a few times a second
    if self.pendingDraw then return end
    self.pendingDraw = true
    C_Timer.After(0.3, function() self.pendingDraw = nil self:Refresh() end)
    return
  end
  self:Refresh()
end

---------------------------------------------------------------------------
-- Sell
---------------------------------------------------------------------------
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
  s.icon = p:CreateTexture(nil, "ARTWORK")
  s.icon:SetSize(36, 36)
  s.icon:SetPoint("TOPLEFT", 0, 0)
  s.name = UI.Text(p, 15, "semi", C.text)
  s.name:SetPoint("TOPLEFT", s.icon, "TOPRIGHT", 10, -1)
  s.name:SetPoint("RIGHT", p, "RIGHT", -90, 0)
  s.name:SetJustifyH("LEFT")
  s.name:SetWordWrap(false)
  s.sub = UI.Text(p, 11, nil, C.dim)
  s.sub:SetPoint("TOPLEFT", s.name, "BOTTOMLEFT", 0, -4)
  s.pos = UI.Text(p, 11, nil, C.dim)
  s.pos:SetPoint("TOPRIGHT", 0, -2)
  local iconBtn = CreateFrame("Frame", nil, p)
  iconBtn:SetAllPoints(s.icon)
  iconBtn:EnableMouse(true)
  iconBtn:SetScript("OnEnter", function(b)
    if s.cur and s.cur.link then GameTooltip:SetOwner(b, "ANCHOR_LEFT") pcall(GameTooltip.SetHyperlink, GameTooltip, s.cur.link) GameTooltip:Show() end
  end)
  iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local function label(text, y)
    local t = UI.Text(p, 12, nil, C.muted)
    t:SetPoint("TOPLEFT", 0, y)
    t:SetText(text)
    return t
  end
  local l1 = label("Price each", -52)
  s.price = edit(p, 120, "price", function(e) e:ClearFocus() end)
  s.price:SetPoint("TOPLEFT", 90, -46)
  s.price.edit:HookScript("OnTextChanged", function(e, user)
    if user then s.userPrice = parseMoney(e:GetText()) end
    W:PaintSellTotals()
  end)
  s.why = UI.Text(p, 11, nil, C.dim)
  s.why:SetPoint("LEFT", s.price, "RIGHT", 8, 0)
  s.whyTip = UI.InfoTip(p, s.why, "Price each",
    "Starts 1c under the cheapest listing that isn't yours. With nothing listed it uses the gang price, and it never goes under what a vendor pays (after the auction house's 5 % cut). Type 1g 20s 5c; a plain number counts as silver.")
  label("Quantity", -84)
  s.qty = edit(p, 60, "", function(e) e:ClearFocus() end)
  s.qty:SetPoint("TOPLEFT", 90, -78)
  s.qty.edit:SetNumeric(true)
  s.qty.edit:HookScript("OnTextChanged", function(e, user) if user then s.userQty = tonumber(e:GetText()) end W:PaintSellTotals() end)
  s.of = UI.Text(p, 11, nil, C.dim)
  s.of:SetPoint("LEFT", s.qty, "RIGHT", 8, 0)
  s.all = UI.Button(p, 36, 20, "All", "ghost", function() if s.cur then s.userQty = s.cur.count s.qty:SetText(tostring(s.cur.count)) W:PaintSellTotals() end end)
  s.all:SetPoint("LEFT", s.of, "RIGHT", 6, 0)
  label("Duration", -114)
  s.dur = seg(p, (function() local o = {} for i, d in ipairs(durations()) do o[i] = d[2] end return o end)(),
    function() return ns.db.settings.mkDuration or 2 end,
    function(i) ns.db.settings.mkDuration = i W:PaintSellTotals() end)
  s.dur:SetPoint("TOPLEFT", 90, -110)

  -- what you get
  local box = UI.Panel(p, C.card, C.line, true)
  box:SetPoint("TOPLEFT", 0, -142)
  box:SetPoint("TOPRIGHT", 0, -142)
  box:SetHeight(50)
  local gl = UI.Text(box, 11, nil, C.dim)
  gl:SetPoint("TOPLEFT", 10, -7)
  gl:SetText("You get after the 5 % cut")
  UI.InfoTip(box, gl, "After the cut", "The auction house keeps 5 % of every sale. This is price each × 0.95 (rounded down) × quantity: what actually reaches your mailbox.")
  s.get = UI.Text(box, 17, "semi", C.green)
  s.get:SetPoint("BOTTOMLEFT", 10, 7)
  s.deposit = UI.Text(box, 11, nil, C.dim)
  s.deposit:SetPoint("CENTER", 20, 0)
  s.postBtn = UI.Button(box, 90, 30, "Post", "primary", function() W:DoPost() end)
  s.postBtn:SetPoint("RIGHT", -10, 0)
  s.skipBtn = UI.Button(box, 60, 30, "Skip", "secondary", function() W:SkipCurrent() end)
  s.skipBtn:SetPoint("RIGHT", s.postBtn, "LEFT", -6, 0)
  s.skipBtn.tooltip = "Not now: next item. Right-click an Up Next row to hide an item for good (right-click it under For a vendor to bring it back)."

  -- listings
  s.lh = section(p, "On the auction house now")
  s.lh:SetPoint("TOPLEFT", 0, -204)
  s.refresh = UI.Button(p, 60, 16, "Refresh", "ghost", function() if s.cur then AH.Ask(W:SellReq(s.cur), nil, true, true) end end)
  s.refresh:SetPoint("TOPRIGHT", 0, -202)
  s.lhead = header(p, { 80, 110 }, nil, "Price each")
  s.lhead:SetPoint("TOPLEFT", 0, -222) s.lhead:SetPoint("TOPRIGHT", 0, -222)
  s.lhead:Set("Available", "")
  s.listings = list(p, { 80, 110 }, nil, function(r, it)
    r:Set(nil, coins(it.price), tostring(it.qty), it.tag or "")
    r.icon:SetSize(1, 16)
    r.bg:SetShown(it.own > 0)
  end)
  s.listings:SetPoint("TOPLEFT", 0, -240) s.listings:SetPoint("TOPRIGHT", 0, -240)
  s.listings:SetHeight(4 * (ROW_H + GAP))

  -- up next / for a vendor
  s.uh = section(p, "Up next")
  s.uh:SetPoint("TOPLEFT", 0, -336)
  s.uhr = UI.Text(p, 10, nil, C.dim)
  s.uhr:SetPoint("TOPRIGHT", 0, -336)
  s.uhead = header(p, { 90, 90 }, nil, "Item")
  s.uhead:SetPoint("TOPLEFT", 0, -352) s.uhead:SetPoint("TOPRIGHT", 0, -352)
  s.uhead:Set("You get each", "Total")
  s.queue = list(p, { 90, 90 }, nil, function(r, it)
    r:Set(it.icon, qhex(it.quality) .. it.name .. "|r" .. (it.count > 1 and dim("  ×" .. it.count) or ""),
      it.each and coins(it.each) or dim("no price"), it.each and coins(it.each * it.count) or "")
    r.bg:SetShown(s.cur and s.cur.key == it.key)
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
  s.queue:SetPoint("TOPLEFT", 0, -370) s.queue:SetPoint("BOTTOMRIGHT", 0, 30)
  s.queue.emptyText = "Nothing in your bags is worth more on the auction house than at a vendor."
  s.vend = CreateFrame("Button", nil, p)
  s.vend:SetHeight(24)
  s.vend:SetPoint("BOTTOMLEFT", 0, 0) s.vend:SetPoint("BOTTOMRIGHT", 0, 0)
  local vline = s.vend:CreateTexture(nil, "ARTWORK")
  vline:SetHeight(1) vline:SetPoint("TOPLEFT") vline:SetPoint("TOPRIGHT")
  vline:SetColorTexture(hex(C.line))
  s.vendL = UI.Text(s.vend, 12, nil, C.muted)
  s.vendL:SetPoint("LEFT", 8, -1)
  s.vendR = UI.Text(s.vend, 12, nil, C.muted)
  s.vendR:SetPoint("RIGHT", -8, -1)
  s.vend:SetScript("OnClick", function() s.showVendor = not s.showVendor W:DrawSell() end)

  ns:On("BAG_UPDATE_DELAYED", function() if W.frame and W.frame:IsShown() and W.tab == 1 then W.bagsDirty = true W:DrawSell() end end)
end

function W:SellReq(e)
  return { key = e.key, itemID = e.itemID, commodity = e.commodity, itemKey = e.itemKey, bagEntry = e }
end

-- the queue: what pays more on the auction house (after the cut) than at a vendor, most first
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
      e.hiddenMark = true
      vend[#vend + 1] = e
      vendTotal = vendTotal + vendor * e.count
    elseif (e.each and e.each > vendor) or (not e.each and (vendor == 0 or (e.quality or 1) >= 2)) then
      -- no price yet: anything a vendor won't buy, and greens and better, get looked at
      up[#up + 1] = e
    else
      vend[#vend + 1] = e
      vendTotal = vendTotal + vendor * e.count
    end
  end
  local skipped = self.skipped or {}
  table.sort(up, function(a, b)
    local sa, sb = skipped[a.key] or 0, skipped[b.key] or 0
    if sa ~= sb then return sa < sb end
    local wa, wb = (a.each or -1) * a.count, (b.each or -1) * b.count
    if wa ~= wb then return wa > wb end
    return a.name < b.name
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
    -- keep the item you're on while it's still in your bags
    if s.cur then
      local still
      for _, e in ipairs(self.sellQueue) do if e.key == s.cur.key then still = e end end
      for _, e in ipairs(self.vendQueue) do if e.key == s.cur.key then still = e end end
      if still then s.cur = still else s.cur = nil end
    end
  end
  local up, vend = self.sellQueue, self.vendQueue
  if not s.cur and up[1] then self:SelectSell(up[1], true) end
  -- header
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
  -- listings
  local L = e and AH.Listing(e.key)
  local rows = {}
  local cheapestTagged = false
  if L and L.rows then
    for _, r in ipairs(L.rows) do
      local tag
      if r.own > 0 then tag = ns.Colorize("yours", C.amber)
      elseif not cheapestTagged then tag = dim("cheapest") cheapestTagged = true end
      rows[#rows + 1] = { price = r.price, qty = r.qty, own = r.own, tag = tag }
    end
  end
  s.listings.emptyText = not e and "" or (L and (L.state == "listed" and "Nothing listed: the gang price is used." or "No answer from the auction house. Refresh to ask again.") or "Asking the auction house …")
  s.listings:SetData(rows)
  -- queue or vendor list
  if s.showVendor then
    s.uh:SetText(("For a vendor"):upper())
    s.uhr:SetText("right-click to put back in Up Next")
    s.uhead:Set("Vendor each", "Total")
    local data = {}
    for _, x in ipairs(vend) do
      data[#data + 1] = setmetatable({ each = x.vendor > 0 and x.vendor or nil }, { __index = x })
    end
    s.queue:SetData(data)
  else
    s.uh:SetText(("Up next"):upper())
    s.uhr:SetText("worth more on the auction than at a vendor")
    s.uhead:Set("You get each", "Total")
    s.queue:SetData(up)
  end
  s.vendL:SetText(s.showVendor and "‹ Back to Up Next" or ("For a vendor  " .. dim(#vend .. " " .. (#vend == 1 and "item" or "items") .. " where the vendor pays more than the auction after the cut")))
  s.vendR:SetText(s.showVendor and "" or (coins(self.vendTotal or 0) .. "  ›"))
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
    s.get:SetText("")
    s.deposit:SetText("")
    s.of:SetText("")
    s.postBtn:SetEnabled(false)
    return
  end
  s.of:SetText("of " .. e.count)
  s.get:SetText(coins(AH.AfterCut(price) * qty))
  local d = AH.Deposit(e, qty, dur)
  s.deposit:SetText(d and (dim("Deposit ") .. coins(d)) or "")
  local can = AH.CanPost() and price > 0
  s.postBtn:SetEnabled(can)
  s.postBtn:SetLabel(AH.PostWaiting() and "Posting …" or "Post")
  local under = price < AH.Floor(e.itemID)
  s.get:SetTextColor(hex(under and C.red or C.green))
end

function W:DoPost()
  local e, price, qty, dur = self:SellValues()
  if not e or not price then return end
  local s = self.sell
  local done = AH.Post(e, qty, price, dur, function(good)
    if good then
      -- the next one, and this item's listings are now stale
      local c = AH.Listing(e.key)
      if c then c.at = 0 end
      s.cur = nil
      W.bagsDirty = true
    end
    W:DrawSell()
  end)
  if not done then ns.Print("Market: the auction house isn't ready – try again in a moment.") end
  self:PaintSellTotals()
end

function W:SkipCurrent()
  local s = self.sell
  if not s.cur then return end
  self.skipped = self.skipped or {}
  self.skipN = (self.skipN or 0) + 1
  self.skipped[s.cur.key] = self.skipN
  local cur = s.cur
  self.bagsDirty = true
  s.cur = nil
  self:DrawSell()
  if s.cur == cur then s.cur = nil end
end

---------------------------------------------------------------------------
-- Buy
---------------------------------------------------------------------------
function W:BuildBuy(p)
  local b = {}
  self.buyP = b
  b.box = edit(p, 330, "Search by name", function(e) e:ClearFocus() W:DoSearch() end)
  b.box:SetPoint("TOPLEFT", 0, 0)
  b.go = UI.Button(p, 70, 24, "Search", "primary", function() W:DoSearch() end)
  b.go:SetPoint("LEFT", b.box, "RIGHT", 6, 0)
  b.save = UI.Button(p, 66, 24, "Save", "secondary", function()
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
  b.chipRow = CreateFrame("Frame", nil, p)
  b.chipRow:SetPoint("TOPLEFT", 0, -30) b.chipRow:SetPoint("TOPRIGHT", 0, -30)
  b.chipRow:SetHeight(20)

  b.rh = section(p, "Results")
  b.rh:SetPoint("TOPLEFT", 0, -58)
  b.rhead = header(p, { 90, 64, 90 }, nil, "Item")
  b.rhead:SetPoint("TOPLEFT", 0, -74) b.rhead:SetPoint("TOPRIGHT", 0, -74)
  b.rhead:Set("Cheapest", "Available", "vs gang price")
  b.results = list(p, { 90, 64, 90 }, nil, function(r, it)
    local g = AH.GangPrice(it.itemID)
    local vs = dim("no price")
    if g and it.minPrice and g > 0 then
      local pct = math.floor((it.minPrice - g) / g * 100 + 0.5)
      vs = ns.Colorize((pct > 0 and "+" or pct < 0 and "−" or "") .. math.abs(pct) .. " %", pct <= -5 and C.green or pct >= 5 and C.red or C.muted)
    end
    r:Set(it.icon, qhex(it.quality) .. (it.name or ("item " .. it.itemID)) .. "|r", it.minPrice and coins(it.minPrice) or "", ns.Num(it.qty or 0), vs)
    r.bg:SetShown(b.sel and b.sel.itemKey == it.itemKey)
  end, function(it) W:SelectBuy(it) end)
  b.results:SetPoint("TOPLEFT", 0, -92) b.results:SetPoint("TOPRIGHT", 0, -92)
  b.results:SetHeight(5 * (ROW_H + GAP))

  b.ih = section(p, "Pick a result")
  b.ih:SetPoint("TOPLEFT", 0, -214)
  b.ihr = UI.Text(p, 10, nil, C.dim)
  b.ihr:SetPoint("TOPRIGHT", 0, -214)
  b.lhead = header(p, { 80, 110 }, nil, "Price each")
  b.lhead:SetPoint("TOPLEFT", 0, -230) b.lhead:SetPoint("TOPRIGHT", 0, -230)
  b.lhead:Set("Available", "")
  b.listings = list(p, { 80, 110 }, nil, function(r, it)
    r:Set(nil, coins(it.price), tostring(it.qty), it.tag or "")
    r.icon:SetSize(1, 16)
    r.bg:SetShown(it.deal)
  end)
  b.listings:SetPoint("TOPLEFT", 0, -248) b.listings:SetPoint("BOTTOMRIGHT", 0, 56)

  local bar = UI.Panel(p, C.card, C.line, true)
  bar:SetPoint("BOTTOMLEFT", 0, 0) bar:SetPoint("BOTTOMRIGHT", 0, 0)
  bar:SetHeight(46)
  local bl = UI.Text(bar, 12, nil, C.muted)
  bl:SetPoint("LEFT", 10, 0)
  bl:SetText("Buy")
  b.qty = edit(bar, 50, "", function(e) e:ClearFocus() end)
  b.qty:SetPoint("LEFT", bl, "RIGHT", 8, 0)
  b.qty.edit:SetNumeric(true)
  b.qty.edit:HookScript("OnTextChanged", function(_, user) if user then AH.Drop() end W:PaintBuyBar() end)
  b.for_ = UI.Text(bar, 12, nil, C.text)
  b.for_:SetPoint("LEFT", b.qty, "RIGHT", 8, 0)
  b.buyBtn = UI.Button(bar, 120, 28, "Buy", "primary", function() W:DoBuy() end)
  b.buyBtn:SetPoint("RIGHT", -10, 0)
  b.shopBtn = UI.Button(bar, 110, 28, "+ Shopping list", "secondary", function()
    if b.sel then AH.ShopAdd(b.sel.itemID, math.max(1, tonumber(b.qty:GetText()) or 1)) b.shopBtn:SetLabel("Added ✓") C_Timer.After(1.5, function() b.shopBtn:SetLabel("+ Shopping list") end) end
  end)
  b.shopBtn:SetPoint("RIGHT", b.buyBtn, "LEFT", -6, 0)
end

function W:DoSearch()
  local b = self.buyP
  AH.Search(b.box:GetText())
  b.box.edit:ClearFocus()
  self:DrawBuy()
end

function W:SelectBuy(it)
  local b = self.buyP
  b.sel = it
  AH.Drop()
  b.qty:SetText("1")
  AH.Ask(AH.ResultReq(it), function() W:DrawBuy() end, true, true)
  self:DrawBuy()
end

function W:DrawBuy()
  local b = self.buyP
  if not b then return end
  -- saved and recent searches as chips
  for _, c in ipairs(b.chips) do c:Hide() end
  local d = AH.DB()
  local x, n = 0, 0
  local function chip(text, saved)
    n = n + 1
    local c = b.chips[n]
    if not c then
      c = UI.Button(b.chipRow, 10, 20, "", "ghost")
      c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      b.chips[n] = c
    end
    c:SetLabel(saved and ("★ " .. text) or text)
    c:SetStyle(saved and "secondary" or "ghost")
    local w = math.ceil(c.label:GetStringWidth()) + 18
    if x + w > WIDTH - 2 * PAD then return end
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
    x = x + w + 4
  end
  for _, t in ipairs(d.saved) do chip(t, true) end
  local savedSet = {}
  for _, t in ipairs(d.saved) do savedSet[t:lower()] = true end
  for _, t in ipairs(d.recent) do if not savedSet[t:lower()] then chip(t, false) end end

  b.results.emptyText = AH.searching and "Searching …" or (AH.open and (AH.searchText and "Nothing found." or "Search for an item by name.") or "Open the auction house to search.")
  b.results:SetData(AH.results)

  local sel = b.sel
  local rows = {}
  if sel then
    local key = AH.KeyOf(sel.itemKey, sel.commodity, sel.itemID)
    local g = AH.GangPrice(sel.itemID)
    b.ih:SetText((sel.name or ("item " .. sel.itemID)):upper())
    b.ihr:SetText(g and ("gang price " .. coins(g)) or "")
    local L = AH.Listing(key)
    if L and L.rows then
      for _, r in ipairs(L.rows) do
        local mine = r.own >= r.qty
        local deal = g and r.price <= g * 0.9 and not mine
        rows[#rows + 1] = { price = r.price, qty = r.qty - r.own, own = r.own, auctionID = r.auctionID,
          tag = mine and ns.Colorize("yours", C.amber) or deal and ns.Colorize("deal", C.green) or "", deal = deal }
      end
    end
    b.listings.emptyText = L and "Nothing listed." or "Asking the auction house …"
  else
    b.ih:SetText(("Pick a result"):upper())
    b.ihr:SetText("")
    b.listings.emptyText = ""
  end
  b.rowsNow = rows
  b.listings:SetData(rows)
  self:PaintBuyBar()
end

-- what n of the selected item costs, cheapest first (others' listings only)
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
  if not sel then
    b.for_:SetText("")
    b.buyBtn:SetEnabled(false)
    b.buyBtn:SetLabel("Buy")
    b.shopBtn:SetEnabled(false)
    return
  end
  b.shopBtn:SetEnabled(true)
  local n = math.max(1, tonumber(b.qty:GetText()) or 1)
  if not sel.commodity then n = 1 end
  local total, got = costOf(b.rowsNow, n)
  if got > 0 then
    b.for_:SetText(dim("for ") .. coins(total) .. (got > 1 and dim("   avg ") .. coins(math.floor(total / got)) or "") .. (got < n and dim("  (only " .. got .. ")") or ""))
  else
    b.for_:SetText(dim("nothing to buy"))
  end
  if state == "quoted" then
    b.buyBtn:SetLabel("Confirm " .. ns.Money(quoted or total))
  elseif state then
    b.buyBtn:SetLabel("Buying …")
  else
    b.buyBtn:SetLabel("Buy")
  end
  b.buyBtn:SetEnabled(got > 0 and AH.open and (state == nil or state == "quoted"))
end

function W:DoBuy()
  local b = self.buyP
  local sel = b.sel
  if not sel then return end
  local state = AH.Buying()
  if state == "quoted" then AH.Confirm() self:PaintBuyBar() return end
  if state then return end
  local key = AH.KeyOf(sel.itemKey, sel.commodity, sel.itemID)
  if sel.commodity then
    local n = math.max(1, tonumber(b.qty:GetText()) or 1)
    local total, got = costOf(b.rowsNow, n)
    if got <= 0 then return end
    AH.Quote(key, sel.itemID, got, nil, function() C_Timer.After(0.3, function() AH.Ask(AH.ResultReq(sel), function() W:DrawBuy() end, true, true) end) end)
  else
    for _, r in ipairs(b.rowsNow or {}) do
      if r.auctionID and r.qty > 0 then
        AH.BuyItem(key, r.auctionID, r.price, function() C_Timer.After(0.3, function() AH.Ask(AH.ResultReq(sel), function() W:DrawBuy() end, true, true) end) end)
        break
      end
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
  local tw = math.floor((WIDTH - 2 * PAD) / 3)
  for i = 1, 3 do
    local t = UI.Panel(p, C.card, C.line, true)
    t:SetSize(tw - (i < 3 and 4 or 0), 46)
    t:SetPoint("TOPLEFT", (i - 1) * tw, 0)
    t.v = UI.Text(t, 16, "semi", C.text)
    t.v:SetPoint("TOPLEFT", 10, -7)
    t.k = UI.Text(t, 11, nil, C.dim)
    t.k:SetPoint("BOTTOMLEFT", 10, 7)
    a.tiles[i] = t
  end
  a.filter = 1
  a.seg = seg(p, { "All", "Undercut", "Sold" }, function() return a.filter end, function(i) a.filter = i W:DrawAuctions() end)
  a.seg:SetPoint("TOPLEFT", 0, -56)
  a.cancel = UI.Button(p, 150, 24, "Cancel undercut", "danger", function()
    local x = AH.NextUndercut()
    if x then AH.Cancel(x) end
    W:DrawAuctions()
  end)
  a.cancel:SetPoint("TOPRIGHT", 0, -55)
  a.cancel.tooltip = "Cancels the next undercut auction, one per click (the game wants a click for each). The items come back by mail; then post them again from the Sell tab."
  a.check = UI.Button(p, 70, 24, "Check", "ghost", function() AH.CheckOwned(true) W:DrawAuctions() end)
  a.check:SetPoint("RIGHT", a.cancel, "LEFT", -6, 0)
  a.check.tooltip = "Look up every auction again."
  a.head = header(p, { 80, 80, 110, 36 }, nil, "Item")
  a.head:SetPoint("TOPLEFT", 0, -90) a.head:SetPoint("TOPRIGHT", 0, -90)
  a.head:Set("Your price", "Cheapest", "Status", "Left")
  a.list = list(p, { 80, 80, 110, 36 }, nil, function(r, x)
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
  a.list:SetPoint("TOPLEFT", 0, -108) a.list:SetPoint("BOTTOMRIGHT", 0, 0)
end

function W:DrawAuctions()
  local a = self.aucP
  if not a then return end
  if not a.checkedOnce or (a.checkedFor ~= #AH.owned) then
    a.checkedOnce, a.checkedFor = true, #AH.owned
    AH.CheckOwned(false)
  end
  local listed, nListed, under, data = 0, 0, 0, {}
  for _, x in ipairs(AH.owned) do
    local st = AH.Status(x)
    if not x.sold and not x.cancelled then listed, nListed = listed + (x.price or 0) * (x.commodity and x.qty or 1), nListed + 1 end
    if st == "undercut" and not x.cancelled then under = under + 1 end
    if a.filter == 1 or (a.filter == 2 and st == "undercut") or (a.filter == 3 and st == "sold") then data[#data + 1] = x end
  end
  local sold7 = AH.SoldSince(7 * 86400)
  a.tiles[1].v:SetText(coins(listed))
  a.tiles[1].k:SetText("listed · " .. nListed .. " " .. (nListed == 1 and "auction" or "auctions"))
  a.tiles[2].v:SetText(under > 0 and ns.Colorize(tostring(under), C.red) or "0")
  a.tiles[2].k:SetText("undercut")
  a.tiles[3].v:SetText(coins(sold7))
  a.tiles[3].k:SetText("sold last 7 days")
  a.cancel:SetLabel("Cancel undercut" .. (under > 0 and (" (" .. under .. ")") or ""))
  a.cancel:SetEnabled(under > 0)
  a.seg:Refresh()
  a.list.emptyText = AH.open and (a.filter == 1 and "No auctions." or "None here.") or "Open the auction house to see your auctions."
  a.list:SetData(data)
end

---------------------------------------------------------------------------
-- Shopping
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

function W:BuildShop(p)
  local s = {}
  self.shopP = s
  s.add = edit(p, 300, "Add an item, or shift-click one", function() W:DoShopAdd() end)
  s.add:SetPoint("TOPLEFT", 0, 0)
  s.want = edit(p, 50, "how many", function() W:DoShopAdd() end)
  s.want:SetPoint("LEFT", s.add, "RIGHT", 6, 0)
  s.want.edit:SetNumeric(true)
  s.want:SetText("1")
  local ml = UI.Text(p, 11, nil, C.dim)
  ml:SetPoint("LEFT", s.want, "RIGHT", 6, 0)
  ml:SetText("max")
  s.max = edit(p, 80, "any", function() W:DoShopAdd() end)
  s.max:SetPoint("LEFT", ml, "RIGHT", 6, 0)
  s.addBtn = UI.Button(p, 50, 24, "Add", "secondary", function() W:DoShopAdd() end)
  s.addBtn:SetPoint("TOPRIGHT", 0, 0)
  s.msg = UI.Text(p, 11, nil, C.dim)
  s.msg:SetPoint("TOPLEFT", 0, -30)
  s.head = header(p, { 50, 80, 80 }, 80, "Item")
  s.head:SetPoint("TOPLEFT", 0, -48) s.head:SetPoint("TOPRIGHT", 0, -48)
  s.head:Set("Have", "Max each", "Cheapest")
  s.list = list(p, { 50, 80, 80 }, 80, function(r, it)
    local name, q, icon = itemName(it.id)
    local have = AH.Have(it.id)
    local L = AH.Listing(AH.ShopReq(it).key)
    local cheapest = L and AH.Cheapest(AH.ShopReq(it).key)
    r:Set(icon, qhex(q) .. (name or ("item " .. it.id)) .. "|r" .. dim("  ×" .. it.want), tostring(have),
      it.max and coins(it.max) or dim("any"), cheapest and coins(cheapest) or (L and dim("none") or dim("not checked")))
    local need = it.want - have
    r.btn:SetScript("OnClick", nil)
    r.btn:Show()
    r.btn:SetEnabled(false)
    r.btn:SetStyle("ghost")
    if need <= 0 then r.btn:SetLabel("done ✓")
    elseif not L then r.btn:SetLabel("—")
    else
      local n, cost = W:ShopCan(it, need)
      local state, quoted, bkey = AH.Buying()
      local mine = bkey == AH.ShopReq(it).key
      if mine and state == "quoted" then
        r.btn:SetLabel("Confirm") r.btn:SetStyle("primary") r.btn:SetEnabled(true)
        r.btn:SetScript("OnClick", function() AH.Confirm() W:DrawShop() end)
      elseif mine and state then r.btn:SetLabel("Buying …")
      elseif n > 0 then
        r.btn:SetLabel("Buy " .. n) r.btn:SetStyle("primary") r.btn:SetEnabled(AH.open and not state)
        r.btn:SetScript("OnClick", function() W:ShopBuy(it, n) end)
      else r.btn:SetLabel("too dear") end
    end
  end, function(it, button)
    if button == "RightButton" then AH.ShopRemove(it.id) W:DrawShop() end
  end)
  s.list:SetPoint("TOPLEFT", 0, -66) s.list:SetPoint("BOTTOMRIGHT", 0, 34)
  s.list.emptyText = "Your shopping list is empty. Add what you want and the most you'll pay each."
  s.sum = UI.Text(p, 12, nil, C.muted)
  s.sum:SetPoint("BOTTOMLEFT", 0, 6)
  s.check = UI.Button(p, 130, 24, "Check prices", "secondary", function()
    for _, it in ipairs(AH.ShopList()) do AH.Ask(AH.ShopReq(it), function() W:DrawShop() end, true) end
    W:DrawShop()
  end)
  s.check:SetPoint("BOTTOMRIGHT", 0, 0)

  -- shift-click an item into the box
  if ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", function(link)
      if s.add.edit:HasFocus() and type(link) == "string" then s.add:SetText(link) end
    end)
  end
end

-- how many of a shopping entry can be bought at or under its max, and for how much
function W:ShopCan(it, need)
  local L = AH.Listing(AH.ShopReq(it).key)
  local n, cost = 0, 0
  for _, r in ipairs(L and L.rows or {}) do
    local avail = r.qty - r.own
    if avail > 0 and (not it.max or r.price <= it.max) then
      local take = math.min(avail, need - n)
      n, cost = n + take, cost + take * r.price
      if n >= need then break end
    end
  end
  return n, cost
end

function W:ShopBuy(it, n)
  local req = AH.ShopReq(it)
  local function after() C_Timer.After(0.3, function() AH.Ask(req, function() W:DrawShop() end, true, true) end) end
  if req.commodity then
    AH.Quote(req.key, it.id, n, nil, after)
  else
    local L = AH.Listing(req.key)
    for _, r in ipairs(L and L.rows or {}) do
      if r.auctionID and r.qty > r.own and (not it.max or r.price <= it.max) then AH.BuyItem(req.key, r.auctionID, r.price, after) break end
    end
  end
  self:DrawShop()
end

function W:DoShopAdd()
  local s = self.shopP
  local id = resolveItem(s.add:GetText())
  if not id then s.msg:SetText(ns.Colorize("Couldn't find that item. Shift-click it, or type its exact name.", C.red)) return end
  local want = math.max(1, tonumber(s.want:GetText()) or 1)
  local max = s.max:GetText() ~= "" and parseMoney(s.max:GetText()) or nil
  AH.ShopAdd(id, want, max)
  s.add:SetText("") s.max:SetText("") s.want:SetText("1")
  s.add.edit:ClearFocus() s.want.edit:ClearFocus() s.max.edit:ClearFocus()
  s.msg:SetText(dim("Added. Right-click a row to remove it."))
  if AH.open then AH.Ask(AH.ShopReq({ id = id }), function() W:DrawShop() end, true, true) end
  self:DrawShop()
end

function W:DrawShop()
  local s = self.shopP
  if not s then return end
  local l = AH.ShopList()
  local under, total, unchecked = 0, 0, 0
  for _, it in ipairs(l) do
    local need = it.want - AH.Have(it.id)
    if need > 0 then
      if not AH.Listing(AH.ShopReq(it).key) then unchecked = unchecked + 1 end
      local n, cost = self:ShopCan(it, need)
      if n > 0 then under, total = under + 1, total + cost end
    end
  end
  s.sum:SetText(#l == 0 and "" or (under .. " " .. (under == 1 and "item" or "items") .. " under your max" .. (under > 0 and (" · " .. coins(total) .. dim(" for all")) or "")))
  s.check:SetLabel("Check prices" .. (#l > 0 and (" (" .. #l .. ")") or ""))
  s.check:SetEnabled(AH.open and #l > 0)
  s.list:SetData(l)
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
  g.note:SetPoint("TOPRIGHT", -20, -5)
  g.tip = UI.InfoTip(p, g.note, "Gang market stats",
    "Gold is what reached the mailbox after the auction house's 5 % cut. Sell-through is auctions sold out of auctions posted (from 3 posts). Each friend's Chillan shares only its own totals and its three biggest sales of the week. Sales are counted when you visit the auction house.")
  g.boards = {}
  local bw = math.floor((WIDTH - 2 * PAD - 10) / 2)
  for i, def in ipairs(BOARDS) do
    local b = UI.Panel(p, C.card, C.line, true)
    b:SetSize(bw, 140)
    b:SetPoint("TOPLEFT", ((i - 1) % 2) * (bw + 10), -32 - math.floor((i - 1) / 2) * 150)
    b.title = UI.Text(b, 11, "semi", C.muted)
    b.title:SetPoint("TOPLEFT", 10, -8)
    b.title:SetText(def[1])
    b.rows = {}
    for k = 1, 5 do
      local y = -26 - (k - 1) * 21
      local r = {}
      r.n = UI.Text(b, 12, "semi", k == 1 and C.amber or C.dim)
      r.n:SetPoint("TOPLEFT", 10, y)
      r.n:SetText(tostring(k))
      r.who = UI.Text(b, 12, "semi", C.text)
      r.who:SetPoint("TOPLEFT", 26, y)
      r.who:SetWidth(76)
      r.who:SetJustifyH("LEFT")
      r.who:SetWordWrap(false)
      r.track = b:CreateTexture(nil, "ARTWORK")
      r.track:SetColorTexture(hex(C.active))
      r.track:SetHeight(6)
      r.track:SetPoint("TOPLEFT", 108, y - 4)
      r.track:SetPoint("TOPRIGHT", -92, y - 4)
      r.bar = b:CreateTexture(nil, "OVERLAY")
      r.bar:SetHeight(6)
      r.bar:SetPoint("TOPLEFT", r.track, "TOPLEFT")
      r.bar:SetColorTexture(hex(k == 1 and C.amber or "6B6355"))
      r.v = UI.Text(b, 12, nil, C.text)
      r.v:SetPoint("TOPRIGHT", -10, y)
      r.v:SetJustifyH("RIGHT")
      b.rows[k] = r
    end
    b.empty = UI.Text(b, 11, nil, C.dim)
    b.empty:SetPoint("CENTER", 0, -6)
    g.boards[i] = b
  end
  g.sh = section(p, "Biggest sales")
  g.sh:SetPoint("TOPLEFT", 0, -338)
  g.sales = list(p, { 90, 60 }, nil, function(r, it)
    local name, q, icon = itemName(it.id)
    r:Set(icon, ns.Colorize(it.who, it.col) .. "   " .. qhex(q) .. (name or ("item " .. it.id)) .. "|r" .. (it.q > 1 and dim("  ×" .. it.q) or ""),
      coins(it.g), dim(ns.Ago(it.at)))
  end)
  g.sales:SetPoint("TOPLEFT", 0, -354) g.sales:SetPoint("TOPRIGHT", 0, -354)
  g.sales:SetHeight(3 * (ROW_H + GAP))
  g.sales.emptyText = "No sales yet."
  g.mine = UI.Text(p, 11, nil, C.dim)
  g.mine:SetPoint("BOTTOMLEFT", 0, 4)
end

-- everyone's numbers for the chosen range: { name, col, x = {g,i,s,p}, tops }
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
  local monday = ns.MondayOf(ns.Now())
  out[#out + 1] = { name = n, col = col, me = true, x = mine or { g = 0, i = 0, s = 0, p = 0 }, tops = range == 1 and AH.TopSales(monday, 3) or {} }
  local dup = ns:HiddenDuplicates() or {}
  for pid, p in pairs(ns.db.people or {}) do
    if pid ~= ns.pid and p.mk and not dup[pid] then
      local mk, x = p.mk, nil
      if range == 1 then x = mk.wk == wk and mk.w or nil
      elseif range == 2 then x = (mk.wk == wk and mk.pwk == pwk and mk.pw) or (mk.wk == pwk and mk.w) or nil
      else x = mk.t end
      local nm, c = who(p)
      out[#out + 1] = { name = nm, col = c, x = x or { g = 0, i = 0, s = 0, p = 0 }, tops = (range == 1 and mk.wk == wk) and mk.tops or {} }
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
  local withChillan = 0
  for _, r in ipairs(rows) do if (r.x.p or 0) + (r.x.s or 0) > 0 or r.me then withChillan = withChillan + 1 end end
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
      if e then
        row.n:Show() row.who:Show() row.track:Show() row.v:Show()
        row.who:SetText(ns.Colorize(e.r.name, e.r.col))
        row.v:SetText(def[3](e.v))
        local tw = row.track:GetWidth()
        if not tw or tw <= 0 then tw = 100 end
        row.bar:SetWidth(math.max(2, tw * e.v / top))
        row.bar:Show()
      else
        row.n:Hide() row.who:Hide() row.track:Hide() row.bar:Hide() row.v:Hide()
      end
    end
    b.empty:SetText(#ranked == 0 and "Nothing yet" or "")
    for k, e in ipairs(ranked) do if e.r.me then myPlaces[bi] = k end end
  end
  -- biggest sales
  local sales = {}
  for _, r in ipairs(rows) do
    for _, t in ipairs(r.tops or {}) do sales[#sales + 1] = { who = r.name, col = r.col, id = t.id, q = t.q, g = t.g, at = t.at } end
  end
  table.sort(sales, function(a, c) return a.g > c.g end)
  while #sales > 3 do table.remove(sales) end
  g.sh:SetText((g.range == 1 and "Biggest sales this week" or "Biggest sales this week (shown for this week only)"):upper())
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
    f:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
  end
end

function W:PaintReopen()
  local host = _G.AuctionHouseFrame
  if not host then return end
  if not self.reopen then
    local b = UI.Button(host, 120, 22, "Chillan? Market", "secondary", function()
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
