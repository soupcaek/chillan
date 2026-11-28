-- Chillan? Market (1.3.5): its own page – where the prices stand, the tooltip lines (each one can be
-- switched off), sharing, and Disenchantry: what in your bags is worth more disenchanted than sold.
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("market", "Market", "Star", function(tab)
  local S = function() return ns.db.settings end
  local LEFT_W = 330

  -- (1.4.66) the Kit look: the left column is panels (Market, Tooltip, Auction house and sharing)
  -- in a scroll area; the right column Price search and Disenchantry panels
  local scroll = CreateFrame("ScrollFrame", nil, tab)
  scroll:SetPoint("TOPLEFT", 12, -12)
  scroll:SetPoint("BOTTOMLEFT", 12, 12)
  scroll:SetWidth(LEFT_W)
  local left = CreateFrame("Frame", nil, scroll)
  left:SetSize(LEFT_W, 600)
  scroll:SetScrollChild(left)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, left:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 40)))
  end)
  local y = 0
  local function stack(p, bodyH)
    p:SetPoint("TOPLEFT", 0, -y) p:SetPoint("TOPRIGHT", 0, -y)
    p:FitBody(bodyH)
    y = y + p:GetHeight() + 10
    left:SetHeight(y)
  end

  local mp = UI.Section(left, "Market", true)
  -- (1.4.78) one fact per line: label left, value right (it ran over the line under it)
  local stL, stR = {}, {}
  for i = 1, 4 do
    stL[i] = UI.Text(mp.body, 11, nil, C.dim)
    stL[i]:SetPoint("TOPLEFT", 0, -(i - 1) * 17)
    stR[i] = UI.Text(mp.body, 11, nil, C.text2)
    stR[i]:SetPoint("TOPRIGHT", 0, -(i - 1) * 17)
    stR[i]:SetJustifyH("RIGHT")
    stR[i]:SetPoint("LEFT", stL[i], "RIGHT", 8, 0)
  end
  local status = { SetText = function(_, lines)
    for i = 1, 4 do
      local l = lines and lines[i]
      stL[i]:SetText(l and l[1] or "") stR[i]:SetText(l and l[2] or "")
    end
  end }
  local how = UI.Text(mp.body, 11, nil, C.dim)
  how:SetPoint("TOPLEFT", 0, -72) how:SetPoint("RIGHT")
  how:SetJustifyH("LEFT")
  how:SetWordWrap(false)
  how:SetText("Scan from the auction house · every 15 minutes")
  UI.InfoTip(mp.body, how, "Scanning", "Open the auction house and select the Chillan? scan tab (available every 15 minutes). Prices are added to item tooltips and shared with the gang.")
  local sync = UI.Button(mp.body, 150, 28, "Ask the gang now", "secondary", function()
    ns.Comm:Broadcast(ns.Comm:Build("MQ", 0), 2)
    ns.Print("Market: asked the gang for their prices – they arrive over the next few minutes.")
  end)
  sync:SetPoint("TOPLEFT", 0, -92)
  sync.tooltip = "Fetch newer prices from other gang members"
  stack(mp, 120)

  local checks = {}
  local function rowsPanel(title, defs)
    local p = UI.Section(left, title)
    for i, def in ipairs(defs) do
      local r = UI.SwitchRow(p.body, def[1], function() return S()[def[2]] ~= false end, function(v)
        S()[def[2]] = v
        if def[2] == "market" and v and ns.Market then ns.Market:HookTooltips() end
        tab:Refresh()
      end, def[3])
      r:SetPoint("TOPLEFT", 0, -(i - 1) * 30) r:SetPoint("TOPRIGHT", 0, -(i - 1) * 30)
      checks[#checks + 1] = r
    end
    stack(p, #defs * 30)
  end
  rowsPanel("Tooltip", {
    { "Market on", "market", "The whole Chillan? Market: scanning, tooltip lines and sharing." },
    { "Market value", "mkPrice", "The typical price of the cheapest listings, and how old it is." },
    { "Stack value", "mkStack", "The price of the whole stack you hover in your bags." },
    { "Best: auction, vendor or disenchant", "mkBest", "Which pays most, and by how much (auction after the 5 % cut)." },
    { "Disenchant value", "mkDE", "What disenchanting the item is worth: the expected value of the mats at the auction house." },
    { "Disenchant button", "mkDEButton", "Adds a Disenchant next button under your bags and on this page. Each click disenchants the item in your bags that gains most from disenchanting." },
    { "What disenchanting gives", "mkDEList", "One line per mat under the disenchant value: how many, the chance, and the mat's price." },
    { "Price change since the last scan", "mkTrend", "Shown when the price moved 5 % or more." },
  })
  rowsPanel("Auction house and sharing", {
    { "Market window at the auction house", "mkWindow", "Opens with the auction house: Sell (your bags as a queue, priced 1c under the cheapest), Buy, My auctions, Item Tracker and Gang. Close it with × for one visit; the Chillan? Market tab on the auction house brings it back." },
    { "Share prices with the gang", "marketShare", "After you scan, the prices that changed go to the gang quietly; friends logging in get the newest ones, and an item you hover with no price is asked for." },
  })

  -------------------------------------------------------------------------
  -- right: price search and Disenchantry
  -------------------------------------------------------------------------
  local right = CreateFrame("Frame", nil, tab)
  right:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 12, 0)
  right:SetPoint("BOTTOMRIGHT", -12, 12)
  -- (1.4.24) price search: every price the gang has scanned, by item name
  local sp = UI.Section(right, "Price search")
  sp:SetPoint("TOPLEFT") sp:SetPoint("TOPRIGHT")
  sp:FitBody(28 + 6 + 6 * 20 + 18)
  sp.right:SetText("Gang prices · ?price in chat")
  local ssub = sp.right
  UI.InfoTip(sp, sp.title, "Price search", "Search all prices scanned by the gang. In gang chat, type ?price followed by an item name to post the answer for everyone.")
  local results = {}
  local box
  local function runSearch()
    local q = box:GetText()
    local hits, total, unnamed = ns.Market:Search(q, 6)
    for i, r in ipairs(results) do
      local h = hits[i]
      r.hit = h
      if h then
        local link = ns.ItemLink(h.id)
        r.name:SetText(link or ns.Colorize(h.name, C.text))
        r.price:SetText(ns.Market.Coins(h.v))
        r.meta:SetText(ns.Ago(h.t) .. ((ns.Market.ByName(h.by)) and (" · " .. ns.Market.ByName(h.by)) or ""))
        r:Show()
      else r:Hide() end
    end
    if #q >= 2 and (unnamed or 0) > 0 and #hits < 6 then
      results.empty:SetText("Loading item names for " .. ns.Num(unnamed) .. " prices – more results appear in a moment.")
      C_Timer.After(3, function() if tab:IsVisible() and box:GetText() == q then runSearch() end end)
    elseif #q >= 2 and #hits == 0 then
      results.empty:SetText("No scanned price matches \"" .. q .. "\". Prices appear after someone in the gang scans the auction house.")
    elseif total > #hits then
      results.empty:SetText(total - #hits .. " more matches – type more of the name to narrow it down.")
    else results.empty:SetText("") end
  end
  box = UI.EditBox(sp.body, 260, 28, "Item name, e.g. long elegant feather", function(e) e:ClearFocus() runSearch() end)
  box:SetPoint("TOPLEFT", 0, 0)
  box:SetPoint("RIGHT", sp.body, "RIGHT", 0, 0)
  box.edit:HookScript("OnTextChanged", function(_, user) if user then runSearch() end end)
  local last = box
  for i = 1, 6 do
    local r = CreateFrame("Button", nil, sp.body)
    r:SetHeight(20)
    r:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, i == 1 and -6 or 0)
    r:SetPoint("RIGHT", sp.body, "RIGHT", 0, 0)
    r.name = UI.Text(r, 12, nil, C.text)
    r.name:SetPoint("LEFT", 2, 0)
    r.name:SetPoint("RIGHT", -190, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.meta = UI.Text(r, 10, nil, C.dim)
    r.meta:SetPoint("RIGHT", -96, 0)
    r.meta:SetJustifyH("RIGHT")
    r.price = UI.Text(r, 12, "semi", C.text)
    r.price:SetPoint("RIGHT", -2, 0)
    r.price:SetJustifyH("RIGHT")
    r:SetScript("OnEnter", function(self)
      if not self.hit then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      pcall(GameTooltip.SetItemByID, GameTooltip, self.hit.id)
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self)
      if self.hit and IsModifiedClick and IsModifiedClick("CHATLINK") then
        local link = ns.ItemLink(self.hit.id)
        if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
      end
    end)
    r:Hide()
    results[i] = r
    last = r
  end
  results.empty = UI.Text(sp.body, 11, nil, C.dim)
  results.empty:SetPoint("BOTTOMLEFT", 2, 0)
  results.empty:SetPoint("RIGHT", sp.body, "RIGHT", 0, 0)
  results.empty:SetJustifyH("LEFT")
  results.empty:SetWordWrap(false)

  local dp = UI.Section(right, "Disenchantry")
  dp:SetPoint("TOPLEFT", sp, "BOTTOMLEFT", 0, -10)
  dp:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 0)
  UI.InfoTip(dp, dp.title, "Disenchantry", "Disenchant or vendor? Compares the auction value of the disenchanting materials with the vendor price, for uncommon, rare and epic gear in your bags. Needs material prices from a scan.")
  local dh = dp.title

  local function createRow(list)
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
  local coins = function(c) return ns.Market and ns.Market.Coins(c) or ns.Money(c) end
  local function updateRow(row, it)
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
  local list = UI.List(dp.body, 44, 6, createRow, updateRow)
  list:SetPoint("TOPLEFT", 0, 0)
  list:SetPoint("BOTTOMRIGHT", dp.body, "BOTTOMRIGHT", 6, 0)
  list.emptyText = "No green, blue or purple gear in your bags right now."
  -- (1.4.35) disenchant the best one per click (shown for characters who know Disenchant)
  local deBtn = ns.Disenchant:MakeButton(dp, 150, 20, false)
  deBtn:SetPoint("RIGHT", dp, "TOPRIGHT", -8, -(1 + dp.stripH / 2))

  local function bagItems() return ns.Disenchant:BagItems() end

  function tab:Refresh()
    for _, cb in ipairs(checks) do cb:Refresh() end
    local M = ns.Market
    status:SetText(M and M:StatusLines() or nil)
    list:SetData(bagItems())
    if ns.Disenchant.RefreshButtons then ns.Disenchant.RefreshButtons() end
  end
  ns:Listen("MARKET", function() if tab:IsVisible() then tab:Refresh() if box:GetText() ~= "" then runSearch() end end end)
  ns:On("BAG_UPDATE_DELAYED", function() if tab:IsVisible() then tab:Refresh() end end)
end)
