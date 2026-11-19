-- Chillan? Market (1.3.5): its own page – where the prices stand, the tooltip lines (each one can be
-- switched off), sharing, and Disenchantry: what in your bags is worth more disenchanted than sold.
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("market", "Market", "Star", function(tab)
  local S = function() return ns.db.settings end
  local LEFT_W = 330

  local left = CreateFrame("Frame", nil, tab)
  left:SetPoint("TOPLEFT", 16, -16)
  left:SetPoint("BOTTOMLEFT", 16, 14)
  left:SetWidth(LEFT_W)

  local h = UI.Text(left, 15, "semi", C.text)
  h:SetPoint("TOPLEFT")
  h:SetText(ns.Logo() .. " Market")
  local status = UI.Text(left, 11, nil, C.muted)
  status:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
  status:SetWidth(LEFT_W)
  status:SetJustifyH("LEFT")
  status:SetWordWrap(true)
  local how = UI.Text(left, 11, nil, C.dim)
  how:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -6)
  how:SetWidth(LEFT_W)
  how:SetJustifyH("LEFT")
  how:SetWordWrap(true)
  how:SetText("Scan: open the auction house and click the Chillan? scan tab on top of its window (every 15 min). Prices go to your tooltips and to the gang.")
  local sync = UI.Button(left, 160, 26, "Ask the gang now", "secondary", function()
    ns.Comm:Broadcast(ns.Comm:Build("MQ", 0), 2)
    ns.Print("Market: asked the gang for their prices – they arrive over the next few minutes.")
  end)
  sync:SetPoint("TOPLEFT", how, "BOTTOMLEFT", 0, -10)
  sync.tooltip = "Get every price the gang has that's newer than yours"

  local checks = {}
  local function section(anchor, title, gap)
    local t = UI.Text(left, 13, "semi", C.text)
    t:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or 18))
    t:SetText(title)
    return t
  end
  local function checkList(anchor, defs)
    local last = anchor
    for i, def in ipairs(defs) do
      local cb = UI.Check(left, def[1], function() return S()[def[2]] ~= false end, function(v)
        S()[def[2]] = v
        if def[2] == "market" and v and ns.Market then ns.Market:HookTooltips() end
        tab:Refresh()
      end)
      cb:SetWidth(LEFT_W)
      cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, i == 1 and -6 or -1)
      if def[3] then cb.tooltip = def[3] cb:HookScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT") GameTooltip:AddLine(def[1], 1, 1, 1) GameTooltip:AddLine(def[3], 0.75, 0.78, 0.82, true) GameTooltip:Show() end) cb:HookScript("OnLeave", function() GameTooltip:Hide() end) end
      checks[#checks + 1] = cb
      last = cb
    end
    return last
  end
  local th = section(sync, "Tooltip")
  local lastT = checkList(th, {
    { "Market on (prices in tooltips)", "market", "The whole Chillan? Market: scanning, tooltip lines and sharing." },
    { "Market value", "mkPrice", "The typical price of the cheapest listings, and how old it is." },
    { "Stack value", "mkStack", "The price of the whole stack you hover in your bags." },
    { "Best: auction, vendor or disenchant", "mkBest", "Which pays most, and by how much (auction after the 5 % cut)." },
    { "Disenchant value", "mkDE", "What disenchanting the item is worth: the expected value of the mats at the auction house." },
    { "What disenchanting gives", "mkDEList", "One line per mat under the disenchant value: how many, the chance, and the mat's price." },
    { "Price change since the last scan", "mkTrend", "Shown when the price moved 5 % or more." },
  })
  local sh = section(lastT, "Sharing")
  checkList(sh, {
    { "Share prices with the gang", "marketShare", "After you scan, the prices that changed go to the gang quietly; friends logging in get the newest ones, and an item you hover with no price is asked for." },
  })

  -------------------------------------------------------------------------
  -- Disenchantry: what in your bags is worth more as mats
  -------------------------------------------------------------------------
  local right = CreateFrame("Frame", nil, tab)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 24, 0)
  right:SetPoint("BOTTOMRIGHT", -16, 14)
  local dh = UI.Text(right, 15, "semi", C.text)
  dh:SetPoint("TOPLEFT")
  dh:SetText("Disenchantry")
  local dsub = UI.Text(right, 11, nil, C.dim)
  dsub:SetPoint("TOPLEFT", dh, "BOTTOMLEFT", 0, -6)
  dsub:SetPoint("RIGHT", right, "RIGHT", 0, 0)
  dsub:SetJustifyH("LEFT")
  dsub:SetWordWrap(true)
  dsub:SetText("Green, blue and purple gear in your bags: what disenchanting gives (expected value of the mats at the auction house) against selling it. Needs mat prices – a scan, or the gang's.")

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
  local list = UI.List(right, 44, 6, createRow, updateRow)
  list:SetPoint("TOPLEFT", dsub, "BOTTOMLEFT", 0, -10)
  list:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 6, 0)
  list.emptyText = "No green, blue or purple gear in your bags right now."

  local function bagItems()
    local out, seen = {}, {}
    for bag = 0, 4 do
      local n = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)) or 0
      for slot = 1, n do
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if ok and type(info) == "table" and info.hyperlink then
          local id = info.itemID or tonumber(info.hyperlink:match("item:(%d+)"))
          if id and not seen[id] then
            local res = ns.Disenchant:Results(id)
            if res then
              seen[id] = true
              local de = ns.Disenchant:Value(id)
              if not de then ns.Disenchant:AskMats(id) end
              local e = (not info.isBound) and ns.Market:Get(id)
              local net = e and math.floor(e.v * 0.95) or 0
              local vend = ns.Market.VendorPrice(id) or 0
              local sell, how = vend, "vendor"
              if net > vend then sell, how = net, "auction" end
              out[#out + 1] = { link = info.hyperlink, res = res, de = de, sell = sell, sellHow = how, gain = (de or 0) - sell }
            end
          end
        end
      end
    end
    table.sort(out, function(a, b) return a.gain > b.gain end)
    return out
  end

  function tab:Refresh()
    for _, cb in ipairs(checks) do cb:Refresh() end
    local M = ns.Market
    status:SetText(M and (M:StatusText() .. (M.gangScanBy and (" · " .. M.gangScanBy .. " scanned " .. ns.Ago(M.gangScanAt)) or "")) or "")
    list:SetData(bagItems())
  end
  ns:Listen("MARKET", function() if tab:IsVisible() then tab:Refresh() end end)
  ns:On("BAG_UPDATE_DELAYED", function() if tab:IsVisible() then tab:Refresh() end end)
end)
