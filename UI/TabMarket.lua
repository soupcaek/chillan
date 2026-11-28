-- Chillan? Market tab (1.4.78: rethought) – the auction house window's views, anywhere, from the
-- gang's newest prices. Sub-tabs: Search (any item: price, graph, what a vendor pays, how many you
-- have, who scanned it, ★ to track), Item Tracker (the same list as at the auction house, with
-- alerts that also fire away from it), My bags (what it's worth and where it pays most), Gang (the
-- sales boards) and Disenchantry. The status is one line at the bottom; the switches sit behind
-- ⚙ Market settings.
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

local SUBS = { "Search", "Item Tracker", "My bags", "Gang", "Disenchantry" }
local function dim(t) return ns.Colorize(t, C.dim) end
local function coins(c) return ns.Market and ns.Market.Coins(c) or ns.Money(c) end
local function W() return ns.MarketWin or {} end
local function itemName(id)
  if W().ItemName then return W().ItemName(id) end
  local okI, name, link, q, _, _, _, _, _, _, icon = pcall(C_Item.GetItemInfo, id)
  if okI then return name, q, icon, link end
end
local function qhex(q)
  local col = ITEM_QUALITY_COLORS and q and ITEM_QUALITY_COLORS[q]
  return col and col.hex or "|cffffffff"
end
local function change(pts)
  if #pts < 2 or pts[1].v <= 0 then return nil end
  return math.floor((pts[#pts].v - pts[1].v) / pts[1].v * 100 + 0.5)
end
local function pctText(p)
  if not p then return dim("—") end
  return ns.Colorize((p > 0 and "+" or p < 0 and "−" or "") .. math.abs(p) .. " %", p < 0 and C.green or p > 0 and C.red or C.muted)
end
local function sellPrice(id)
  local okI, _, _, _, _, _, _, _, _, _, _, price = pcall(C_Item.GetItemInfo, id)
  return (okI and type(price) == "number") and price or 0
end

-- a plain row for the lists: icon, name, then up to three right-aligned columns
local function makeRow(list, cols)
  local r = CreateFrame("Button", nil, list)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  -- (1.4.78) every other row a shade lighter, a thin line between rows; r.bg is the selection
  r.stripe = r:CreateTexture(nil, "BACKGROUND", nil, 1)
  r.stripe:SetAllPoints()
  r.stripe:SetColorTexture(1, 1, 1, 0.035)
  r.sepl = UI.Track(r:CreateTexture(nil, "BORDER"))
  r.sepl:SetColorTexture(hex(C.line))
  r.sepl:SetAlpha(0.6)
  r.sepl:SetHeight(1)
  r.sepl:SetPoint("BOTTOMLEFT", 0, -1) r.sepl:SetPoint("BOTTOMRIGHT", 0, -1)
  r.bg = UI.Track(r:CreateTexture(nil, "BACKGROUND", nil, 2))
  r.bg:SetAllPoints()
  r.bg:SetColorTexture(1, 1, 1, 0.03)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(18, 18)
  r.icon:SetPoint("LEFT", 4, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.name = UI.Text(r, 12, nil, C.text)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
  r.name:SetWordWrap(false)
  r.c = {}
  local x = -6
  for i = #cols, 1, -1 do
    local t = UI.Text(r, 11, nil, C.text)
    t:SetPoint("RIGHT", x, 0)
    t:SetWidth(cols[i])
    t:SetJustifyH("RIGHT")
    t:SetWordWrap(false)
    r.c[i] = t
    x = x - cols[i] - 10
  end
  r.name:SetPoint("RIGHT", r, "RIGHT", x, 0)
  r:SetScript("OnEnter", function(self)
    if not self.id then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetItemByID, GameTooltip, self.id)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return r
end
local function stripe(r, idx) r.stripe:SetShown(idx % 2 == 0) end

-- (1.4.78) the column titles: readable, clickable to sort (again: the other way), a line under them.
-- st = { col = n, desc = bool } is changed in place; onSort() redraws
local function header(parent, cols, labels, st, onSort)
  local h = CreateFrame("Frame", nil, parent)
  h:SetHeight(22)
  local ul = UI.Track(h:CreateTexture(nil, "ARTWORK"))
  ul:SetColorTexture(hex(C.line))
  ul:SetHeight(1)
  ul:SetPoint("BOTTOMLEFT") ul:SetPoint("BOTTOMRIGHT")
  h.btns = {}
  local function mk(i, w, anchorRight, x)
    local b = CreateFrame("Button", nil, h)
    b:SetHeight(20)
    b.t = UI.Text(b, 11, "semi", C.muted)
    b.t:SetText(labels[i] or "")
    b.arrow = b:CreateTexture(nil, "OVERLAY")
    b.arrow:SetSize(10, 10)
    b.arrow:SetTexture(ns.TEX .. "IconUp")
    b.arrow:Hide()
    if anchorRight then
      b:SetPoint("RIGHT", x, 1)
      b:SetWidth(w)
      b.t:SetPoint("RIGHT", 0, 0)
      b.arrow:SetPoint("RIGHT", b.t, "LEFT", -3, 0)
    else
      b:SetPoint("LEFT", 30, 1)
      b:SetWidth(140)
      b.t:SetPoint("LEFT", 0, 0)
      b.arrow:SetPoint("LEFT", b.t, "RIGHT", 3, 0)
    end
    b:SetScript("OnClick", function()
      if st.col == i then st.desc = not st.desc else st.col, st.desc = i, i ~= 1 end
      h:Paint()
      if onSort then onSort() end
    end)
    b:SetScript("OnEnter", function(self) self.t:SetTextColor(hex(C.text)) end)
    b:SetScript("OnLeave", function() h:Paint() end)
    h.btns[i] = b
  end
  mk(1)
  local x = -6
  for i = #cols, 1, -1 do
    mk(i + 1, cols[i], true, x)
    x = x - cols[i] - 10
  end
  function h:Paint()
    for i, b in ipairs(self.btns) do
      local on = st.col == i
      b.t:SetTextColor(hex(on and C.text or C.muted))
      b.arrow:SetShown(on)
      UI.Track(b.arrow):SetVertexColor(hex(C.accent))
      if st.desc then b.arrow:SetTexCoord(0, 1, 1, 0) else b.arrow:SetTexCoord(0, 1, 0, 1) end
    end
  end
  h:Paint()
  return h
end
-- sort a list by its header: getters[i](item) gives the value for column i (1 = the name)
local function sortBy(data, getters, st)
  if not st.col or not getters[st.col] then return data end
  local g, desc = getters[st.col], st.desc
  table.sort(data, function(a, b)
    local va, vb = g(a), g(b)
    if va == nil and vb == nil then return false end
    if va == nil then return false end
    if vb == nil then return true end
    if va == vb then return false end
    if desc then return va > vb else return va < vb end
  end)
  return data
end
local function nameKey(id) return tostring(itemName(id) or ""):lower() end

ns:RegisterTab("market", "Market", "Star", function(tab)
  local S = function() return ns.db.settings end
  local M = ns.Market
  local AH = ns.AH

  ---------------------------------------------------------------------------
  -- sub-tabs, the panes, the bottom bar
  ---------------------------------------------------------------------------
  local bar = CreateFrame("Frame", nil, tab)
  bar:SetPoint("TOPLEFT", 12, -8)
  bar:SetPoint("TOPRIGHT", -12, -8)
  bar:SetHeight(30)
  local line = UI.Track(bar:CreateTexture(nil, "ARTWORK"))
  line:SetColorTexture(hex(C.line))
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT") line:SetPoint("BOTTOMRIGHT")
  local foot = CreateFrame("Frame", nil, tab)
  foot:SetPoint("BOTTOMLEFT", 12, 8)
  foot:SetPoint("BOTTOMRIGHT", -12, 8)
  foot:SetHeight(28)
  local panes, btns = {}, {}
  tab.sub = S().mkSub or 1
  local function show(i)
    tab.sub = i
    S().mkSub = i
    for k, p in ipairs(panes) do p:SetShown(k == i) end
    for k, b in ipairs(btns) do
      b.t:SetTextColor(hex(k == i and C.text or C.muted))
      b.u:SetShown(k == i)
    end
    if tab.Refresh then tab:Refresh() end
  end
  local x = 0
  for i, name in ipairs(SUBS) do
    local b = CreateFrame("Button", nil, bar)
    b.t = UI.Text(b, 12, "semi", C.muted)
    b.t:SetPoint("CENTER", 0, 1)
    b.t:SetText(name)
    local w = math.floor((b.t:GetStringWidth() or 60) + 24)
    b:SetSize(w, 30)
    b:SetPoint("BOTTOMLEFT", x, 0)
    b.u = UI.Track(b:CreateTexture(nil, "OVERLAY"))
    b.u:SetColorTexture(hex(C.accent))
    b.u:SetHeight(2)
    b.u:SetPoint("BOTTOMLEFT", 6, 0) b.u:SetPoint("BOTTOMRIGHT", -6, 0)
    b:SetScript("OnClick", function() show(i) end)
    btns[i] = b
    x = x + w
    local p = CreateFrame("Frame", nil, tab)
    p:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -10)
    p:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", 0, 6)
    p:Hide()
    panes[i] = p
  end

  -- the bottom bar: one line of status, Ask the gang now, ⚙ Market settings
  local status = UI.Text(foot, 11, nil, C.dim)
  status:SetPoint("LEFT", 2, 0)
  status:SetWordWrap(false)
  local gear = UI.Button(foot, 150, 24, "Market settings", "ghost", function() tab:ToggleSettings() end)
  gear:SetPoint("RIGHT", 0, 0)
  local ask = UI.Button(foot, 140, 24, "Ask the gang now", "secondary", function()
    ns.Comm:Broadcast(ns.Comm:Build("MQ", 0), 2)
    ns.Print("Market: asked the gang for their prices – they arrive over the next few minutes.")
  end)
  ask:SetPoint("RIGHT", gear, "LEFT", -8, 0)
  ask.tooltip = "Fetch newer prices from other gang members"
  status:SetPoint("RIGHT", ask, "LEFT", -10, 0)

  ---------------------------------------------------------------------------
  -- ⚙ Market settings: the switches, in a small panel over the tab
  ---------------------------------------------------------------------------
  local sp = UI.Panel(tab, C.panel or C.card, C.border or C.line, false)
  sp:SetFrameStrata("DIALOG")
  sp:SetWidth(360)
  sp:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", 0, 6)
  sp:EnableMouse(true)
  sp:Hide()
  local checks = {}
  local sy = -12
  local function group(title, defs)
    local t = UI.Text(sp, 10, "semi", C.dim)
    t:SetPoint("TOPLEFT", 14, sy)
    t:SetText(title:upper())
    sy = sy - 20
    for _, def in ipairs(defs) do
      local r = UI.SwitchRow(sp, def[1], function() return S()[def[2]] ~= false end, function(v)
        S()[def[2]] = v
        if def[2] == "market" and v and ns.Market then ns.Market:HookTooltips() end
        tab:Refresh()
      end, def[3])
      r:SetPoint("TOPLEFT", 14, sy) r:SetPoint("TOPRIGHT", -14, sy)
      checks[#checks + 1] = r
      sy = sy - 28
    end
    sy = sy - 8
  end
  group("Tooltip", {
    { "Market on", "market", "The whole Chillan? Market: scanning, tooltip lines and sharing." },
    { "Market value", "mkPrice", "The typical price of the cheapest listings, and how old it is." },
    { "Stack value", "mkStack", "The price of the whole stack you hover in your bags." },
    { "Best: auction, vendor or disenchant", "mkBest", "Which pays most, and by how much (auction after the 5 % cut)." },
    { "Disenchant value", "mkDE", "What disenchanting the item is worth: the expected value of the mats at the auction house." },
    { "Disenchant button", "mkDEButton", "Adds a Disenchant next button under your bags and on this page. Each click disenchants the item in your bags that gains most from disenchanting." },
    { "What disenchanting gives", "mkDEList", "One line per mat under the disenchant value: how many, the chance, and the mat's price." },
    { "Price change since the last scan", "mkTrend", "Shown when the price moved 5 % or more." },
  })
  group("Auction house and sharing", {
    { "Market window at the auction house", "mkWindow", "Opens with the auction house: Sell, Buy, My auctions, Item Tracker and Gang. Close it with × for one visit; the Chillan? Market tab on the auction house brings it back." },
    { "Share prices with the gang", "marketShare", "After you scan, the prices that changed go to the gang quietly; friends logging in get the newest ones." },
    { "How many you have (in tooltips)", "itemCount", "Item tooltips say how many you have: in bags, in bank and the total." },
  })
  sp:SetHeight(-sy + 4)
  local close = UI.IconButton(sp, 14, "Close", "Close", function() sp:Hide() end)
  close:SetPoint("TOPRIGHT", -10, -10)
  function tab:ToggleSettings()
    sp:SetShown(not sp:IsShown())
    for _, cb in ipairs(checks) do cb:Refresh() end
  end

  ---------------------------------------------------------------------------
  -- the price card: graph, facts, Track / ?price (Search and Item Tracker both use it)
  ---------------------------------------------------------------------------
  local function priceCard(parent, withTrack)
    local pc = UI.Section(parent, "Price")
    pc.range = 2
    pc.rb = {}
    for i, lab in ipairs({ "7d", "14d", "30d" }) do
      local b = UI.Button(pc, 40, 18, lab, "ghost", function() pc.range = i pc:Draw(pc.id) end)
      b:SetPoint("RIGHT", pc, "TOPRIGHT", -8 - (3 - i) * 44, -(1 + pc.stripH / 2))
      pc.rb[i] = b
    end
    -- (1.4.79) the graph across the whole card on top, the facts in two columns under it
    pc.chart = W().MakeChart and W().MakeChart(pc.body)
    pc.facts = CreateFrame("Frame", nil, pc.body)
    pc.facts:SetPoint("BOTTOMLEFT", 0, 34)
    pc.facts:SetPoint("BOTTOMRIGHT", 0, 34)
    pc.facts:SetHeight(62)
    local sep = UI.Track(pc.facts:CreateTexture(nil, "ARTWORK"))
    sep:SetColorTexture(hex(C.line))
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 0, 4) sep:SetPoint("TOPRIGHT", 0, 4)
    if pc.chart then
      pc.chart:SetPoint("TOPLEFT", 0, 0)
      pc.chart:SetPoint("BOTTOMRIGHT", pc.facts, "TOPRIGHT", 0, 10)
    end
    pc.kv = {}
    for i, k in ipairs({ "Average", "Vendor pays", "You have", "Scanned by", "Alert under", "" }) do
      local col, rowN = (i - 1) % 2, math.floor((i - 1) / 2)
      local cell = CreateFrame("Frame", nil, pc.facts)
      cell:SetHeight(18)
      cell:ClearAllPoints()
      if col == 0 then
        cell:SetPoint("TOPLEFT", pc.facts, "TOPLEFT", 0, -6 - rowN * 19)
        cell:SetPoint("RIGHT", pc.facts, "CENTER", -12, 0)
      else
        cell:SetPoint("TOPLEFT", pc.facts, "TOP", 12, -6 - rowN * 19)
        cell:SetPoint("RIGHT", pc.facts, "RIGHT", 0, 0)
      end
      local l = UI.Text(cell, 11, nil, C.dim)
      l:SetPoint("LEFT")
      l:SetText(k)
      local v = UI.Text(cell, 11, nil, C.text)
      v:SetPoint("RIGHT")
      v:SetJustifyH("RIGHT")
      v:SetPoint("LEFT", l, "RIGHT", 8, 0)
      v:SetWordWrap(false)
      pc.kv[i] = v
      pc.kv[k] = l
    end
    pc.track = UI.Button(pc.body, 130, 24, "Track this item", "primary", function()
      if not pc.id or not AH then return end
      AH.ShopAdd(pc.id)
      ns.Print("Item Tracker: tracking " .. (select(4, itemName(pc.id)) or ("item " .. pc.id)) .. ". Set an alert from its row in the Item Tracker.")
      pc:Draw(pc.id)
    end)
    pc.track:SetPoint("BOTTOMLEFT", 0, 0)
    pc.track:SetShown(withTrack and true or false)
    pc.ask = UI.Button(pc.body, 120, 24, "?price in chat", "secondary", function()
      if not pc.id then return end
      local name = itemName(pc.id)
      if name and ns.Data and ns.Data.SendChat then ns.Data:SendChat("?price " .. name) end
    end)
    pc.ask:SetPoint("BOTTOMLEFT", withTrack and 138 or 0, 0)
    function pc:Draw(id)
      self.id = id
      for i, b in ipairs(self.rb) do b:SetStyle(i == self.range and "secondary" or "ghost") end
      local days = ({ 7, 14, 30 })[self.range] or 14
      if not id then
        self:SetTitle("Price")
        if self.chart then self.chart.title:SetText("Pick an item") self.chart:SetData({}, days) end
        for _, v in ipairs(self.kv) do v:SetText("") end
        self.track:SetEnabled(false) self.ask:SetEnabled(false)
        return
      end
      local name, q = itemName(id)
      self:SetTitle("Price · " .. (name or ("item " .. id)))
      local pts = M.History(id, days)
      if self.chart then
        self.chart.title:SetText(qhex(q) .. (name or ("item " .. id)) .. "|r")
        self.chart:SetData(pts, days)
      end
      local sum = 0
      for _, p in ipairs(pts) do sum = sum + p.v end
      local e = M:Get(id)
      self.kv[1]:SetText(#pts > 0 and coins(math.floor(sum / #pts)) or dim("—"))
      local vend = sellPrice(id)
      self.kv[2]:SetText(vend > 0 and coins(vend) or dim("nothing"))
      local bags, bank = 0, 0
      if ns.ItemCount then local b, k = ns.ItemCount.For(id) bags, bank = b, k end
      self.kv[3]:SetText((bags + bank) > 0 and (bags .. " in bags" .. (bank > 0 and (" · " .. bank .. " bank") or "")) or dim("none"))
      self.kv[4]:SetText(e and ((M.ByName(e.by) or "?") .. " · " .. ns.Ago(e.t)) or dim("nobody yet"))
      local tracked
      for _, s in ipairs(AH and AH.ShopList() or {}) do if s.id == id then tracked = s end end
      self.kv[5]:SetText(tracked and (tracked.alert and coins(tracked.alert) or dim("no alert")) or dim("not tracked"))
      self.track:SetEnabled(not tracked)
      self.track:SetLabel(tracked and "Tracked" or "Track this item")
      self.ask:SetEnabled(true)
    end
    return pc
  end

  ---------------------------------------------------------------------------
  -- 1 · Search
  ---------------------------------------------------------------------------
  local p1 = panes[1]
  local sl = UI.Section(p1, "Search")
  sl:SetPoint("TOPLEFT") sl:SetPoint("BOTTOMLEFT")
  sl:SetWidth(470)
  sl.right:SetText("gang prices")
  local card1 = priceCard(p1, true)
  card1:SetPoint("TOPLEFT", sl, "TOPRIGHT", 10, 0)
  card1:SetPoint("BOTTOMRIGHT", p1, "BOTTOMRIGHT", 0, 0)
  local cols1 = { 110, 64, 48 }
  tab.sort1 = { }
  local box
  local results = UI.List(sl.body, 24, 2, function(list)
    local r = makeRow(list, cols1)
    r:SetScript("OnClick", function(self, btn)
      if not self.id then return end
      if IsModifiedClick and IsModifiedClick("CHATLINK") then
        local link = select(4, itemName(self.id))
        if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
        return
      end
      tab.selSearch = self.id
      card1:Draw(self.id)
      tab.results:Render()
    end)
    return r
  end, function(r, h, idx)
    r.id = h.id
    stripe(r, idx)
    local name, q, icon = itemName(h.id)
    r.icon:SetTexture(icon or 134400)
    r.name:SetText(qhex(q) .. (name or h.name or ("item " .. h.id)) .. "|r")
    r.c[1]:SetText(coins(h.v))
    r.c[2]:SetText(pctText(change(M.History(h.id, 14))))
    r.c[3]:SetText(dim(ns.Ago(h.t):gsub(" ago", "")))
    r.bg:SetColorTexture(hex(C.accent))
    r.bg:SetAlpha(tab.selSearch == h.id and 0.12 or 0)
  end)
  tab.results = results
  local h1 = header(sl.body, cols1, { "Item", "Price", "14 days", "Seen" }, tab.sort1, function() tab:Search() end)
  box = UI.EditBox(sl.body, 260, 28, "Item name, e.g. long elegant feather", function(e) e:ClearFocus() tab:Search() end)
  box:SetPoint("TOPLEFT", 0, 0)
  box:SetPoint("RIGHT", sl.body, "RIGHT", 0, 0)
  box.edit:HookScript("OnTextChanged", function(_, user) if user then tab:Search() end end)
  h1:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -8) h1:SetPoint("RIGHT", sl.body, "RIGHT", 0, 0)
  results:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -2)
  results:SetPoint("BOTTOMRIGHT", sl.body, "BOTTOMRIGHT", 4, 16)
  results.emptyText = "Type an item's name: every price the gang has scanned comes up here."
  local more = UI.Text(sl.body, 10, nil, C.dim)
  more:SetPoint("BOTTOMLEFT", 2, 0)
  function tab:Search()
    local q = box:GetText()
    local hits, total, unnamed = M:Search(q, 40)
    sortBy(hits, { function(h) return nameKey(h.id) end, function(h) return h.v end,
      function(h) return change(M.History(h.id, 14)) end, function(h) return -(h.t or 0) end }, tab.sort1)
    results:SetData(hits)
    if #q >= 2 and (unnamed or 0) > 0 and #hits < 10 then
      more:SetText("Loading item names for " .. ns.Num(unnamed) .. " prices …")
      C_Timer.After(3, function() if tab:IsVisible() and box:GetText() == q then tab:Search() end end)
    elseif #q >= 2 and #hits == 0 then
      more:SetText("No scanned price matches \"" .. q .. "\" yet.")
    elseif (total or 0) > #hits then
      more:SetText((total - #hits) .. " more – type more of the name.")
    else more:SetText("") end
    if not tab.selSearch and hits[1] then tab.selSearch = hits[1].id end
    card1:Draw(tab.selSearch)
  end

  ---------------------------------------------------------------------------
  -- 2 · Item Tracker (the auction house list, anywhere)
  ---------------------------------------------------------------------------
  local p2 = panes[2]
  local tl = UI.Section(p2, "Item Tracker")
  tl:SetPoint("TOPLEFT") tl:SetPoint("TOPRIGHT")
  tl:SetHeight(250)
  local card2 = priceCard(p2, false)
  card2:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, -10)
  card2:SetPoint("BOTTOMRIGHT", p2, "BOTTOMRIGHT", 0, 0)
  local add = UI.EditBox(tl.body, 300, 26, "Track an item: type its name, or shift-click it", function() tab:TrackAdd() end)
  add:SetPoint("TOPLEFT", 0, 0)
  local al = UI.Text(tl.body, 11, nil, C.dim)
  al:SetPoint("LEFT", add, "RIGHT", 10, 0)
  al:SetText("alert under")
  local alertBox = UI.EditBox(tl.body, 90, 26, "no alert", function() tab:TrackAdd() end)
  alertBox:SetPoint("LEFT", al, "RIGHT", 8, 0)
  local addBtn = UI.Button(tl.body, 64, 26, "Track", "secondary", function() tab:TrackAdd() end)
  addBtn:SetPoint("LEFT", alertBox, "RIGHT", 8, 0)
  local tmsg = UI.Text(tl.body, 11, nil, C.dim)
  tmsg:SetPoint("LEFT", addBtn, "RIGHT", 10, 0)
  tmsg:SetPoint("RIGHT", tl.body, "RIGHT", 0, 0)
  tmsg:SetWordWrap(false)
  if ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", function(link)
      if add.edit:HasFocus() and type(link) == "string" then add:SetText(link) end
    end)
  end
  local cols2 = { 120, 64, 110 }
  tab.sort2 = { }
  local h2 = header(tl.body, cols2, { "Item", "Now", "14 days", "Alert" }, tab.sort2, function() tab:Refresh() end)
  h2:SetPoint("TOPLEFT", add, "BOTTOMLEFT", 0, -8) h2:SetPoint("RIGHT", tl.body, "RIGHT", 0, 0)
  local tracker = UI.List(tl.body, 24, 2, function(list)
    local r = makeRow(list, cols2)
    r:SetScript("OnClick", function(self, btn)
      local it = self.it
      if not it then return end
      if btn == "RightButton" then
        local name = itemName(it.id) or ("item " .. it.id)
        local items = {
          { text = it.alert and "Change the alert" or "Set an alert", func = function()
            UI.Prompt("Alert: " .. name, { { label = "Tell me when it's under", placeholder = "190g", value = it.alert and W().MoneyText and W().MoneyText(it.alert) or "" } },
              function(v) AH.SetAlert(it.id, v and v ~= "" and W().ParseMoney and W().ParseMoney(v) or nil) tab:Refresh() end)
          end },
        }
        if it.alert then items[#items + 1] = { text = "Remove the alert", func = function() AH.SetAlert(it.id, nil) tab:Refresh() end } end
        items[#items + 1] = { text = "Stop tracking", func = function() AH.ShopRemove(it.id) if tab.selTrack == it.id then tab.selTrack = nil end tab:Refresh() end }
        UI.Menu(self, items)
        return
      end
      tab.selTrack = it.id
      tab:Refresh()
    end)
    return r
  end, function(r, it, idx)
    r.id, r.it = it.id, it
    stripe(r, idx)
    local name, q, icon = itemName(it.id)
    r.icon:SetTexture(icon or 134400)
    r.name:SetText(qhex(q) .. (name or ("item " .. it.id)) .. "|r")
    local e = M:Get(it.id)
    r.c[1]:SetText(e and coins(e.v) or dim("no price"))
    r.c[2]:SetText(pctText(change(M.History(it.id, 14))))
    local under = it.alert and e and e.v <= it.alert
    r.c[3]:SetText(it.alert and ns.Colorize("under " .. coins(it.alert) .. (under and " ✓" or ""), under and C.green or C.text2) or dim("—"))
    if under then r.bg:SetColorTexture(0.37, 0.82, 0.55) r.bg:SetAlpha(0.14)
    else r.bg:SetColorTexture(hex(C.accent)) r.bg:SetAlpha(tab.selTrack == it.id and 0.12 or 0) end
  end)
  tracker:SetPoint("TOPLEFT", h2, "BOTTOMLEFT", 0, -2)
  tracker:SetPoint("BOTTOMRIGHT", tl.body, "BOTTOMRIGHT", 4, 0)
  tracker.emptyText = "Nothing tracked yet. Type an item above, or ★ it from Search. Right-click a row for its alert."
  function tab:TrackAdd()
    local id = W().ResolveItem and W().ResolveItem(add:GetText())
    if not id then
      local hits = M:Search(add:GetText(), 1)
      id = hits[1] and hits[1].id
    end
    if not id then tmsg:SetText(ns.Colorize("Couldn't find that item. Shift-click it, or type its name.", C.red)) return end
    local alert = alertBox:GetText() ~= "" and W().ParseMoney and W().ParseMoney(alertBox:GetText()) or nil
    AH.ShopAdd(id, alert)
    tab.selTrack = id
    add:SetText("") alertBox:SetText("")
    add.edit:ClearFocus() alertBox.edit:ClearFocus()
    tmsg:SetText(dim("Tracking. Right-click a row for its alert."))
    tab:Refresh()
  end

  ---------------------------------------------------------------------------
  -- 3 · My bags: what it's worth and where it pays most
  ---------------------------------------------------------------------------
  local p3 = panes[3]
  local bl = UI.Section(p3, "My bags")
  bl:SetPoint("TOPLEFT") bl:SetPoint("BOTTOMRIGHT")
  UI.InfoTip(bl, bl.title, "My bags", "Every item in your bags with its best price: the auction house (gang price after the 5 % cut, not for soulbound items), a vendor, or disenchanting it (the mats at gang prices).")
  local cols3 = { 80, 110, 110 }
  tab.sort3 = { col = 4, desc = true }
  local h3 = header(bl.body, cols3, { "Item", "Best", "Each", "Total" }, tab.sort3, function() tab:Refresh() end)
  h3:SetPoint("TOPLEFT") h3:SetPoint("TOPRIGHT")
  local BEST_COL = { Auction = "8FB8E8", Vendor = "E0B04F", Disenchant = "B9AEDB" }
  local bags = UI.List(bl.body, 24, 2, function(list) return makeRow(list, cols3) end, function(r, it, idx)
    r.id = it.id
    stripe(r, idx)
    local name, q, icon = itemName(it.id)
    r.icon:SetTexture(icon or 134400)
    r.name:SetText(qhex(q) .. (name or ("item " .. it.id)) .. "|r" .. (it.n > 1 and dim("  ×" .. it.n) or ""))
    r.c[1]:SetText(it.how and ns.Colorize(it.how, BEST_COL[it.how] or C.text) or dim("—"))
    r.c[2]:SetText(it.each > 0 and coins(it.each) or dim("—"))
    r.c[3]:SetText(it.worth > 0 and coins(it.worth) or dim("—"))
    r.bg:SetAlpha(0)
  end)
  bags:SetPoint("TOPLEFT", h3, "BOTTOMLEFT", 0, -2)
  bags:SetPoint("BOTTOMRIGHT", bl.body, "BOTTOMRIGHT", 4, 26)
  bags.emptyText = "Nothing in your bags is worth anything yet (or no prices)."
  local btotal = UI.Text(bl.body, 12, "semi", C.text)
  btotal:SetPoint("BOTTOMRIGHT", -6, 4)
  local bnote = UI.Text(bl.body, 11, nil, C.dim)
  bnote:SetPoint("BOTTOMLEFT", 2, 4)
  bnote:SetText("Bags total")
  function tab.BagRows()
    local byId, out, total = {}, {}, 0
    if not (C_Container and C_Container.GetContainerNumSlots) then return out, 0 end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
      local okN, n = pcall(C_Container.GetContainerNumSlots, bag)
      for slot = 1, (okN and n or 0) do
        local okI, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if okI and type(info) == "table" and info.itemID then
          local e = byId[info.itemID]
          if not e then e = { id = info.itemID, n = 0, bound = info.isBound } byId[info.itemID] = e out[#out + 1] = e end
          e.n = e.n + (info.stackCount or 1)
          e.bound = e.bound or info.isBound
        end
      end
    end
    for _, e in ipairs(out) do
      local m = (not e.bound) and M:Get(e.id)
      local opts = {
        { "Auction", m and math.floor(m.v * 0.95) or 0 },
        { "Vendor", sellPrice(e.id) },
        { "Disenchant", (ns.Disenchant and ns.Disenchant.Value and (ns.Disenchant:Value(e.id))) or 0 },
      }
      table.sort(opts, function(a, b) return a[2] > b[2] end)
      e.how = opts[1][2] > 0 and opts[1][1] or nil
      e.each = opts[1][2]
      e.worth = e.each * e.n
      total = total + e.worth
    end
    table.sort(out, function(a, b) return a.worth > b.worth end)
    local shown = {}
    for _, e in ipairs(out) do if e.worth > 0 then shown[#shown + 1] = e end end
    return shown, total
  end

  ---------------------------------------------------------------------------
  -- 4 · Gang: the sales boards from the auction house window
  ---------------------------------------------------------------------------
  local p4 = panes[4]
  local gangView = setmetatable({}, { __index = function(_, k) return W()[k] end })
  local gangBuilt = false

  ---------------------------------------------------------------------------
  -- 5 · Disenchantry (as before)
  ---------------------------------------------------------------------------
  local p5 = panes[5]
  local dp = UI.Section(p5, "Disenchantry")
  dp:SetPoint("TOPLEFT") dp:SetPoint("BOTTOMRIGHT")
  UI.InfoTip(dp, dp.title, "Disenchantry", "Disenchant or vendor? Compares the auction value of the disenchanting materials with the vendor price, for uncommon, rare and epic gear in your bags. Needs material prices from a scan.")
  local function createDE(list)
    local row = CreateFrame("Button", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.name = UI.Text(row, 12, "semi", C.text)
    row.name:SetPoint("TOPLEFT", 12, -7)
    row.name:SetPoint("RIGHT", -150, 0)
    row.name:SetWordWrap(false)
    row.mats = UI.Text(row, 10, nil, C.dim)
    row.mats:SetPoint("BOTTOMLEFT", 12, 7)
    row.mats:SetPoint("RIGHT", -150, 0)
    row.mats:SetWordWrap(false)
    row.verdict = UI.Text(row, 12, "semi", C.text)
    row.verdict:SetPoint("TOPRIGHT", -12, -7)
    row.verdict:SetJustifyH("RIGHT")
    row.diff = UI.Text(row, 10, nil, C.muted)
    row.diff:SetPoint("BOTTOMRIGHT", -12, 7)
    row.diff:SetJustifyH("RIGHT")
    row:SetScript("OnEnter", function(self)
      if not self.item then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      pcall(GameTooltip.SetHyperlink, GameTooltip, self.item.link)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
  end
  local function updateDE(row, it)
    row.item = it
    row.name:SetText(it.link)
    row.mats:SetText(ns.Disenchant:Describe(it.res))
    if it.de and it.de > it.sell then
      row.verdict:SetText(ns.Colorize("Disenchant", "B9AEDB"))
      row.diff:SetText("+" .. coins(it.de - it.sell) .. " over " .. it.sellHow)
    elseif it.de then
      row.verdict:SetText(ns.Colorize(it.sellHow == "auction" and "Auction" or "Vendor", it.sellHow == "auction" and C.green or C.amber))
      row.diff:SetText("+" .. coins(it.sell - it.de) .. " over disenchant")
    else
      row.verdict:SetText(ns.Colorize("no mat prices", C.dim))
      row.diff:SetText("")
    end
  end
  local delist = UI.List(dp.body, 44, 6, createDE, updateDE)
  delist:SetPoint("TOPLEFT", 0, 0)
  delist:SetPoint("BOTTOMRIGHT", dp.body, "BOTTOMRIGHT", 6, 0)
  delist.emptyText = "No green, blue or purple gear in your bags right now."
  -- (1.4.78) no Disenchant button here: a secure button inside the main window makes the whole window
  -- protected, so the game refuses to close it in combat (Escape gave ADDON_ACTION_BLOCKED). The
  -- button under your bags does the same.
  dp.right:SetText("Disenchant: the button under your bags")

  ---------------------------------------------------------------------------
  function tab:Refresh()
    for _, cb in ipairs(checks) do cb:Refresh() end
    -- the status, one line
    local parts = {}
    for _, l in ipairs(M and M:StatusLines() or {}) do
      if l[1] == "Prices" then
        local n, rest = l[2]:match("^(.-)%s*(·.*)$")
        parts[#parts + 1] = ns.Colorize(n or l[2], C.text2) .. dim(" prices" .. (rest and (" " .. rest) or ""))
      else
        parts[#parts + 1] = dim(l[1]:lower() .. " ") .. ns.Colorize(l[2], C.text2)
      end
    end
    status:SetText(table.concat(parts, dim("   ·   ")))
    local i = tab.sub or 1
    if i == 1 then
      if box:GetText() ~= "" then tab:Search() else card1:Draw(tab.selSearch) end
    elseif i == 2 then
      local l = AH and AH.ShopList() or {}
      local under = 0
      for _, it in ipairs(l) do local e = M:Get(it.id) if it.alert and e and e.v <= it.alert then under = under + 1 end end
      tl.right:SetText(#l .. (#l == 1 and " item" or " items") .. (under > 0 and (" · " .. under .. " under your alert") or ""))
      if not tab.selTrack and l[1] then tab.selTrack = l[1].id end
      local sorted = {}
      for _, it in ipairs(l) do sorted[#sorted + 1] = it end
      sortBy(sorted, { function(it) return nameKey(it.id) end, function(it) local e = M:Get(it.id) return e and e.v end,
        function(it) return change(M.History(it.id, 14)) end, function(it) return it.alert end }, tab.sort2)
      tracker:SetData(sorted)
      card2:Draw(tab.selTrack)
    elseif i == 3 then
      local rows, total = tab.BagRows()
      sortBy(rows, { function(e) return nameKey(e.id) end, function(e) return e.how or "" end,
        function(e) return e.each end, function(e) return e.worth end }, tab.sort3)
      bags:SetData(rows)
      btotal:SetText(coins(total))
    elseif i == 4 then
      if not gangBuilt and W().BuildGang then
        gangBuilt = true
        W().BuildGang(gangView, p4)
      end
      if gangBuilt and W().DrawGang then W().DrawGang(gangView) end
    elseif i == 5 then
      delist:SetData(ns.Disenchant:BagItems())
      if ns.Disenchant.RefreshButtons then ns.Disenchant.RefreshButtons() end
    end
  end
  show(math.max(1, math.min(#SUBS, tab.sub or 1)))
  ns:Listen("MARKET", function() if tab:IsVisible() then tab:Refresh() end end)
  ns:Listen("MKAH", function() if tab:IsVisible() then tab:Refresh() end end)
  ns:On("BAG_UPDATE_DELAYED", function() if tab:IsVisible() and (tab.sub == 3 or tab.sub == 5) then tab:Refresh() end end)
end)
