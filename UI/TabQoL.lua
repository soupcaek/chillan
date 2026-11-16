-- Chillan? – "QoL" tab: helpers in cards, two columns, with small options under each switch
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

-- { label, settingKey, tooltip, subs = { ... } }  ·  sub { kind = "slot" } is the trinket slot picker
local CARDS = {
  { col = 1, title = "Mount gear", icon = "Up", desc = "Riding gear on, your own gear back on dismount", items = {
    { "Riding trinket when mounted", "qolMount", "Puts on Riding Crop, Skybreaker Whip or Carrot on a Stick when you mount, and your own trinket back when you get off. Finds them in your bags by itself. Never mid-fight – it waits until combat is over. Type /chill qol test if it doesn't swap.", subs = {
      { kind = "slot" },
      { "Also spurs boots and riding gloves", "qolMountArmor", "Boots with Mithril Spurs and gloves with the Riding Skill enchant go on while mounted too." },
      { "Druid: flight form charm", "qolDruidCharm", "Charm of Swift Flight goes on in flight form." },
      { "Say it in chat when it swaps", "qolMountMsg", "A short line in chat when the riding gear goes on and comes off." },
    } },
    { "Swim gear in water", "qolSwim", "Hydrocane, Azure Silk Belt and Deepdive Helmet go on after a moment in water and come off again on land." },
  } },
  { col = 2, title = "Vendor & loot", icon = "Star", desc = "Hold Shift at a vendor to skip once", items = {
    { "Auto-repair", "qolRepair", "Repairs all your gear when you open a vendor that can repair.", subs = {
      { "Guild bank money first", "qolGuildRepair", "If your guild lets you, repairs come out of the guild bank first. Your own gold covers the rest." },
      { "Show the cost in chat", "qolRepairMsg", "A line in chat with what the repair cost." },
    } },
    { "Sell grey junk", "qolJunk", "Sells every grey item in your bags at any vendor. Buy back from the vendor's Buyback tab if needed.", subs = {
      { "Show the total in chat", "qolJunkMsg", "A line in chat with how much the junk sold for." },
    } },
    { "Fast loot", "qolFastLoot", "Loots everything instantly when auto loot is on, so the loot window barely flashes. Your normal auto loot key still works." },
  } },
  { col = 1, title = "Questing", icon = "Scroll", desc = "Hold Shift at an NPC to skip once", items = {
    { "Auto accept quests", "qolAutoQuest", "Accepts quests when the quest text opens.", subs = {
      { "Also turn in finished quests", "qolQuestTurnIn", "Hands in finished quests. Stops when there are rewards to pick from, and never hands in repeatable item turn-ins (cloth, tokens)." },
      { "Pick quests from NPC chat lists", "qolQuestGossip", "When an NPC has a list, picks a finished quest first, then a new one." },
    } },
    { "Skip cutscenes you've seen", "qolSkipCine", "The first time you always see it. After that it's skipped (hold Shift to watch it again)." },
    { "XP bar text", "qolXPText", "Shows % done on your XP bar.", subs = {
      { "Rested XP", "qolXPRested", "How much rested XP you have, as % of the level." },
      { "Quests to next level", "qolXPQuests", "Rough number of quests left, from the XP of your last ten hand-ins." },
    } },
  } },
  { col = 2, title = "Fewer annoyances", icon = "Shield", desc = "Popups and noise you never wanted", items = {
    { "Decline duels", "qolNoDuels", "Duel requests are declined straight away.", subs = {
      { "Let the gang duel me", "qolDuelsGang", "Gang members' duel requests come through as normal." },
    } },
    { "Decline guild invites", "qolNoGuildInv", "Guild invites and charter signature requests are declined.", subs = {
      { "Let the gang through", "qolGuildGang", "Invites and charters from gang members come through as normal." },
    } },
    { "Accept summons", "qolSummon", "Accepts a warlock or meeting stone summon, never while you're in combat." },
    { "Accept resurrection", "qolRes", "Takes a res as soon as it's offered.", subs = {
      { "Not during boss fights", "qolResBoss", "During a boss fight you decide yourself." },
    } },
    { "Hide red error spam", "qolNoErrors", "Hides \"Not enough rage\", \"Out of range\", \"Ability not ready\" and the like. Useful ones like \"Inventory is full\" still show." },
    { "Max camera zoom-out", "qolMaxZoom", "Zoom the camera further out than normal. Switching it off puts your old setting back." },
  } },
  { col = 1, title = "Info", icon = "Eye", desc = "Little extras on screen", items = {
    { "Red tint on items you can't use", "qolTint", "Bag items you can't use yet (level, class, skill, already known) get a red icon." },
    { "Flight timer", "qolFlightTimer", "A small bar with time left on flight paths. Learns each route the first time you fly it. Drag it to move it." },
  } },
}

local PAD, ROW, SUB, HEAD = 14, 28, 24, 58

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
  head:SetText("Quality of life")
  local sub = UI.Text(content, 11, nil, C.dim)
  sub:SetPoint("LEFT", head, "RIGHT", 12, -1)
  sub:SetPoint("RIGHT", content, "RIGHT", -16, 0)
  sub:SetJustifyH("LEFT")
  sub:SetText("Hover any switch to see exactly what it does.")

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
    cb:SetHeight(22)
    cb.box:SetSize(14, 14)
    cb.mark:SetSize(11, 11)
    local font, _, flags = cb.label:GetFont()
    if font then cb.label:SetFont(font, 12, flags) end
    cb.label:SetPoint("LEFT", cb.box, "RIGHT", 8, 0)
    cb.parentKey = parentKey
    tip(cb, def[1], def[3])
    subs[#subs + 1] = cb
    return cb
  end

  local colY = { -40, -40 }
  for _, card in ipairs(CARDS) do
    -- height: header + rows + sub-rows
    local h = HEAD + PAD
    for _, it in ipairs(card.items) do
      h = h + ROW
      for _, sd in ipairs(it.subs or {}) do h = h + SUB + (sd.kind == "slot" and 16 or 0) end
    end
    local f = CreateFrame("Frame", nil, content)
    if card.col == 1 then
      f:SetPoint("TOPLEFT", content, "TOPLEFT", 16, colY[1])
      f:SetPoint("RIGHT", mid, "LEFT", -6, 0)
    else
      f:SetPoint("TOPRIGHT", content, "TOPRIGHT", -16, colY[2])
      f:SetPoint("LEFT", mid, "RIGHT", 6, 0)
    end
    f:SetHeight(h)
    colY[card.col] = colY[card.col] - h - 12
    f.bg = UI.Panel(f, C.card, C.line, false)
    f.bg:SetAllPoints()
    f.bg:SetFrameLevel(f:GetFrameLevel())

    local ic = UI.Icon(f, card.icon, 15, C.accent)
    ic:SetPoint("TOPLEFT", PAD, -PAD)
    local t = UI.Text(f, 14, "semi", C.text)
    t:SetPoint("LEFT", ic, "RIGHT", 8, 0)
    t:SetText(card.title)
    local d = UI.Text(f, 11, nil, C.dim)
    d:SetPoint("TOPLEFT", ic, "BOTTOMLEFT", 0, -6)
    d:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    d:SetJustifyH("LEFT")
    d:SetWordWrap(false)
    d:SetText(card.desc)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(hex(C.line))
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", PAD, -(HEAD - 6))
    line:SetPoint("TOPRIGHT", -PAD, -(HEAD - 6))

    local y = -HEAD
    for _, it in ipairs(card.items) do
      local cb = UI.Check(f, it[1], function() return S()[it[2]] and true or false end, function(v)
        S()[it[2]] = v
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
