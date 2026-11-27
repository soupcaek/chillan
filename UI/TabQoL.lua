-- Chillan? – "QoL" tab: helpers in cards, two columns, with small options under each switch
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

-- { label, settingKey, tooltip, subs = { ... } }  ·  sub { kind = "slot" } is the trinket slot picker
local CARDS = {
  { col = 1, title = "Mount gear", icon = "Up", desc = "Equips speed gear while mounted and restores your gear afterwards", items = {
    { "Carrot on a Stick", "qolMount", "Equips Carrot on a Stick when you mount and restores your previous trinket when you dismount. Swaps never happen in combat, while casting, or with a vendor, mailbox, bank or loot window open. The item must be equipped manually once to bind it. Use /chill qol test to troubleshoot.", subs = {
      { kind = "slot" },
      { "Mithril Spurs and Riding Skill gloves", "qolMountArmor", "Equips boots with Mithril Spurs and gloves with the Riding Skill enchant while mounted." },
      { "Zone-specific gear", "qolMountZone", "Equips zone-specific speed items while mounted in their zones: Desert Rose (desert zones such as Tanaris, Silithus, Desolace and the Barrens), Wintersaber Hide Lined Gloves (Winterspring) and Rider of the Plaguelands ring and cloak (Eastern and Western Plaguelands)." },
      { "Swim gear while swimming", "qolSwimGear", "Equips Azure Silk Belt and Cloak of Hermitic Bliss while swimming and removes them when you leave the water." },
      { "Run-speed gear on foot", "qolRunGear", "Keeps Spry Boots and Hyjal Postal Clasp equipped, plus Agamaggan's Clutch and Blessing of Kalimdor in their zones, whenever mount gear does not need the slot. Run-speed gear you equip manually is never removed, and an item you unequip manually stays off until you equip it again." },
      { "Announce swaps in chat", "qolMountMsg", "Prints a short message when mount gear is equipped or removed." },
    } },
  } },
  { col = 2, title = "Vendor and loot", icon = "Star", desc = "Hold Shift when opening a vendor to skip once", items = {
    { "Auto repair", "qolRepair", "Repairs all equipment when you open a vendor that offers repairs.", subs = {
      { "Use guild funds first", "qolGuildRepair", "Uses guild bank funds when permitted. Personal gold covers any remainder." },
      { "Report repair cost", "qolRepairMsg", "Prints the repair cost in chat." },
    } },
    { "Sell junk", "qolJunk", "Sells all poor-quality (grey) items when you open a vendor. Items can be bought back from the Buyback tab.", subs = {
      { "Report sale total", "qolJunkMsg", "Prints the total sale value in chat." },
    } },
    { "Faster auto loot", "qolFastLoot", "Loots all items instantly when auto loot is enabled. Your auto loot modifier key still works." },
  } },
  { col = 1, title = "Questing", icon = "Scroll", desc = "Hold Shift when talking to an NPC to skip once", items = {
    { "Auto accept quests", "qolAutoQuest", "Accepts quests automatically when the quest dialog opens.", subs = {
      { "Auto turn in quests", "qolQuestTurnIn", "Turns in completed quests. Stops when a reward choice is required and skips repeatable item turn-ins." },
      { "Select quests from NPC dialogs", "qolQuestGossip", "Selects completed quests first, then available quests, from NPC dialog lists." },
    } },
    { "Highlight best-selling reward", "qolRewardCoin", "Marks the quest reward with the highest vendor value (including stack size) with a gold coin. Hover the coin to see the price." },
    { "Skip watched cutscenes", "qolSkipCine", "Skips cutscenes you have already seen. Hold Shift to watch again." },
    { "Experience bar text", "qolXPText", "Shows progress as a percentage on the experience bar.", subs = {
      { "Rested experience", "qolXPRested", "Shows rested experience as a percentage of the level." },
      { "Quests to next level", "qolXPQuests", "Estimates quests remaining, based on your last ten turn-ins." },
    } },
  } },
  { col = 2, title = "Interruptions", icon = "Shield", desc = "Blocks unwanted requests and messages", items = {
    { "Decline duels", "qolNoDuels", "Declines duel requests automatically.", subs = {
      { "Allow gang members", "qolDuelsGang", "Duel requests from gang members are not declined." },
    } },
    { "Decline guild invites", "qolNoGuildInv", "Declines guild invitations and charter signature requests automatically.", subs = {
      { "Allow gang members", "qolGuildGang", "Invitations and charters from gang members are not declined." },
    } },
    { "Accept summons", "qolSummon", "Accepts warlock and meeting stone summons automatically. Never accepts in combat." },
    { "Accept resurrection", "qolRes", "Accepts resurrection offers automatically.", subs = {
      { "Not during boss encounters", "qolResBoss", "Resurrection offers during boss encounters are left to you." },
    } },
    { "Hide error messages", "qolNoErrors", "Hides frequent error messages such as \"Not enough rage\", \"Out of range\" and \"Ability is not ready yet\". Important messages such as \"Inventory is full\" still show." },
    { "Maximum camera distance", "qolMaxZoom", "Raises the maximum camera zoom distance. Disabling restores your previous setting." },
  } },
  -- (1.4.72) Chillan's own extensions, switched here too (Settings has the same switches)
  { col = 2, title = "Loot rolls", icon = "Star", desc = "/chill rolls shows the last 5 · /chill need shows a test", items = {
    { "Loot rolls under Pulse", "lootRolls", "One row per item under Pulse while it's rolled for. Hover a row for who picked what.", subs = {
      { "Also in raids and battlegrounds", "lootRollsBig", "Shows the rows in groups bigger than five too." },
      { "Keep finished rows", "lootRollsKeep", "A finished row stays until you close it with the ✕." },
    } },
  } },
  -- (1.4.76) the dungeon card under Pulse
  { col = 2, title = "Dungeons", icon = "Skull", desc = "/chill pull 8 starts a pull timer", items = {
    { "Pull timer", "dgPull", "A Pull chip on the dungeon card for the leader or the tank, and the countdown for everyone with Chillan." },
    { "Loot so far", "dgLoot", "Rare and epic drops this run under the boss list, and your take. Hover for who got what." },
  } },
  { col = 2, title = "Market", icon = "Board", desc = "Prices, the auction house window and the gang's prices", items = {
    { "Market on", "market", "Prices in tooltips, scanning at the auction house and the gang's prices.", subs = {
      { "Window beside the auction house", "mkWindow", "Sell, Buy, My auctions, Item Tracker and Gang open beside the auction house." },
      { "Share prices with the gang", "marketShare", "After a scan, prices that changed go to the gang quietly." },
    } },
  } },
  { col = 1, title = "Interface", icon = "Eye", desc = "Additional information on screen", items = {
    { "Mark unusable items", "qolTint", "Tints bag items you cannot use (level, class, skill or already learned) red." },
    { "Flight timer", "qolFlightTimer", "Shows a bar with remaining flight time. Each route is learned the first time you fly it. Drag the bar to move it." },
    { "How many you have", "itemCount", "Item tooltips say how many you have: Bags 12 · Bank 40 = 52. The bank is remembered each time you open it." },
  } },
}

local PAD, ROW, SUB, HEAD = 12, 28, 24, 58

ns:RegisterTab("qol", "QoL", "Check", function(tab)
  local S = function() return ns.db.settings end
  local parents, subs, slotBtns = {}, {}, {}
  local foundText

  local scroll = CreateFrame("ScrollFrame", nil, tab)
  scroll:SetPoint("TOPLEFT", 0, -4)
  scroll:SetPoint("BOTTOMRIGHT", 0, 4)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(700, 900)
  scroll:SetScrollChild(content)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, content:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 40)))
  end)
  scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)

  local head = UI.Text(content, 16, "semi", C.text)
  head:SetPoint("TOPLEFT", 16, -10)
  head:SetText("")   -- (1.4.66) Kit pages start with their panels
  local sub = UI.Text(content, 11, nil, C.dim)
  sub:SetPoint("LEFT", head, "RIGHT", 12, -1)
  sub:SetPoint("RIGHT", content, "RIGHT", -16, 0)
  sub:SetJustifyH("LEFT")
  sub:SetText("")

  local mid = CreateFrame("Frame", nil, content)
  mid:SetSize(1, 1)
  mid:SetPoint("TOP", content, "TOP", 0, 0)

  local function tip(w, title, text)
    if not text then return end
    w:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(title, 1, 1, 1)
      GameTooltip:AddLine(text, 0.75, 0.78, 0.82, true)
      GameTooltip:Show()
    end)
    w:HookScript("OnLeave", function() GameTooltip:Hide() end)
  end

  local function subCheck(parent, def, parentKey)
    local cb = UI.Check(parent, def[1], function() return S()[def[2]] and true or false end, function(v)
      S()[def[2]] = v
      ns.QoL:Apply()
      tab:Refresh()
    end)
    cb:SetHeight(22)   -- (1.4.66) the sub-switches are full switches too (squeezed ones lost their track)
    local font, _, flags = cb.label:GetFont()
    if font then cb.label:SetFont(font, 12, flags) end
    cb.label:SetPoint("LEFT", cb.box, "RIGHT", 8, 0)
    cb.parentKey = parentKey
    tip(cb, def[1], def[3])
    subs[#subs + 1] = cb
    return cb
  end

  local colY = { -12, -12 }
  for _, card in ipairs(CARDS) do
    -- height: header + rows + sub-rows
    local h = HEAD + PAD
    for _, it in ipairs(card.items) do
      h = h + ROW
      for _, sd in ipairs(it.subs or {}) do h = h + SUB + (sd.kind == "slot" and 16 or 0) end
    end
    local f = CreateFrame("Frame", nil, content)
    if card.col == 1 then
      f:SetPoint("TOPLEFT", content, "TOPLEFT", 12, colY[1])
      f:SetPoint("RIGHT", mid, "LEFT", -6, 0)
    else
      f:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, colY[2])
      f:SetPoint("LEFT", mid, "RIGHT", 6, 0)
    end
    f:SetHeight(h)
    colY[card.col] = colY[card.col] - h - 12
    -- (1.4.66) a Kit panel: the title in the strip, the one-line explanation under it
    f.bg = UI.Section(f, card.title)
    f.bg:SetAllPoints()
    f.bg:SetFrameLevel(f:GetFrameLevel())
    local d = UI.Text(f, 11, nil, C.dim)
    d:SetPoint("TOPLEFT", 12, -36)
    d:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    d:SetJustifyH("LEFT")
    d:SetWordWrap(false)
    d:SetText(card.desc)

    local y = -HEAD
    for _, it in ipairs(card.items) do
      local cb = UI.Check(f, it[1], function() return S()[it[2]] and true or false end, function(v)
        S()[it[2]] = v
        if it[2] == "market" and v and ns.Market and ns.Market.HookTooltips then ns.Market:HookTooltips() end
        ns.QoL:Apply()
        tab:Refresh()
      end)
      cb:SetPoint("TOPLEFT", PAD, y)
      cb:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
      tip(cb, it[1], it[3])
      parents[#parents + 1] = cb
      y = y - ROW
      for _, sd in ipairs(it.subs or {}) do
        if sd.kind == "slot" then
          local lbl = UI.Text(f, 12, nil, C.text2)
          lbl:SetPoint("TOPLEFT", PAD + 28, y - 4)
          lbl:SetText("Trinket slot")
          for i, s in ipairs({ 13, 14 }) do
            local b = UI.Button(f, 62, 20, s == 13 and "Upper" or "Lower", "ghost", function()
              S().qolTrinketSlot = s
              tab:Refresh()
            end)
            b:SetPoint("LEFT", lbl, "RIGHT", 10 + (i - 1) * 66, 0)
            b.slot = s
            b.parentKey = it[2]
            slotBtns[#slotBtns + 1] = b
          end
          lbl.parentKey = it[2]
          subs[#subs + 1] = lbl
          foundText = UI.Text(f, 11, nil, C.dim)
          foundText:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -6)
          foundText:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
          foundText:SetJustifyH("LEFT")
          foundText:SetWordWrap(false)
          y = y - SUB - 16
        else
          local sc = subCheck(f, sd, it[2])
          sc:SetPoint("TOPLEFT", PAD + 28, y)
          sc:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
          y = y - SUB
        end
      end
    end
  end
  content:SetHeight(math.max(-colY[1], -colY[2]) + 10)

  function tab:Refresh()
    for _, cb in ipairs(parents) do cb:Refresh() end
    for _, w in ipairs(subs) do
      local live = S()[w.parentKey] and true or false
      if w.Refresh then w:Refresh() end
      -- (1.1.7) under a switch that's off, the small options show unticked (they don't apply);
      -- your choice is kept and comes back when the main switch goes on
      if not live and w.box and w.box.Set then w.box:Set(false) end
      w:SetAlpha(live and 1 or 0.35)
      if w.EnableMouse and w.Refresh then w:EnableMouse(live) end
    end
    local cur = (S().qolTrinketSlot == 13) and 13 or 14
    local live = S().qolMount and true or false
    for _, b in ipairs(slotBtns) do
      if b.SetStyle then b:SetStyle(b.slot == cur and "secondary" or "ghost") end
      b:SetAlpha(live and (b.slot == cur and 1 or 0.6) or 0.3)
      b:EnableMouse(live)
    end
    if foundText then
      local ok, txt = pcall(ns.QoL.MountGearSummary, ns.QoL)
      foundText:SetText(ok and txt or "")
      foundText:SetAlpha(live and 1 or 0.35)
    end
  end
end)
