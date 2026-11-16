-- Chillan? – "QoL" tab: switch the quality-of-life helpers on and off
local ADDON, ns = ...
local UI, C = ns.UI, ns.C

ns:RegisterTab("qol", "QoL", "Check", function(tab)
  local S = function() return ns.db.settings end
  local checks = {}

  local scroll = CreateFrame("ScrollFrame", nil, tab)
  scroll:SetPoint("TOPLEFT", 0, -4)
  scroll:SetPoint("BOTTOMRIGHT", 0, 4)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(700, 1000)
  scroll:SetScrollChild(content)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, content:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 40)))
  end)
  scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)

  local head = UI.Text(content, 16, "semi", C.text)
  head:SetPoint("TOPLEFT", 18, -14)
  head:SetText("Quality of life")
  local sub = UI.Text(content, 11, nil, C.dim)
  sub:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -4)
  sub:SetPoint("RIGHT", content, "RIGHT", -18, 0)
  sub:SetJustifyH("LEFT")
  sub:SetWordWrap(true)
  sub:SetText("Small helpers so you don't need five extra addons. Hover a switch to see exactly what it does. Hold Shift at a vendor or quest giver to skip the automatic stuff that one time.")

  local function section(anchor, title)
    local h = UI.Text(content, 14, "semi", C.text)
    h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -20)
    h:SetText(title)
    return h
  end

  local function checkList(anchor, defs)
    local last = anchor
    for i, def in ipairs(defs) do
      local cb = UI.Check(content, def[1], function() return S()[def[2]] and true or false end, function(v)
        S()[def[2]] = v
        ns.QoL:Apply()
        tab:Refresh()
      end)
      cb:SetWidth(420)
      cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, i == 1 and -8 or -2)
      if def[3] then
        cb:HookScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:AddLine(def[1], 1, 1, 1)
          GameTooltip:AddLine(def[3], 0.75, 0.78, 0.82, true)
          GameTooltip:Show()
        end)
        cb:HookScript("OnLeave", function() GameTooltip:Hide() end)
      end
      checks[#checks + 1] = cb
      last = cb
    end
    return last
  end

  -- Mount gear
  local h1 = section(sub, "Mount gear")
  local last = checkList(h1, {
    { "Riding trinket when mounted", "qolMount", "Puts on Riding Crop, Skybreaker Whip or Carrot on a Stick when you mount, and your own trinket back when you get off. Finds them in your bags by itself. Waits until combat is over (the game doesn't allow gear swaps in combat). Druids: Charm of Swift Flight in flight form." },
    { "Also spurs boots and riding gloves", "qolMountArmor", "If you have boots with Mithril Spurs or gloves with the Riding Skill enchant in your bags, they go on while mounted too." },
    { "Swim gear in water", "qolSwim", "Hydrocane, Azure Silk Belt and Deepdive Helmet go on after a moment in the water and come off again on land." },
  })
  local slotLbl = UI.Text(content, 12, nil, C.text2)
  slotLbl:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 28, -8)
  slotLbl:SetText("Trinket slot to use:")
  local slotBtns = {}
  for i, s in ipairs({ 13, 14 }) do
    local b = UI.Button(content, 70, 24, s == 13 and "Upper" or "Lower", "ghost", function()
      S().qolTrinketSlot = s
      tab:Refresh()
    end)
    b:SetPoint("LEFT", slotLbl, "RIGHT", 10 + (i - 1) * 76, 0)
    b.slot = s
    slotBtns[#slotBtns + 1] = b
  end
  local found = UI.Text(content, 11, nil, C.dim)
  found:SetPoint("TOPLEFT", slotLbl, "BOTTOMLEFT", 0, -10)
  found:SetPoint("RIGHT", content, "RIGHT", -18, 0)
  found:SetJustifyH("LEFT")

  -- Vendor & loot
  local h2 = section(found, "Vendor & loot")
  h2:SetPoint("TOPLEFT", found, "BOTTOMLEFT", -28, -20)
  last = checkList(h2, {
    { "Auto-repair at vendors", "qolRepair", "Repairs all your gear when you open a vendor that can repair, and says what it cost in chat." },
    { "Use guild bank money for repairs first", "qolGuildRepair", "If your guild lets you repair from the guild bank, that's used first. Your own gold covers the rest." },
    { "Sell grey junk", "qolJunk", "Sells every grey (poor) item in your bags when you open a vendor and prints the total. You can buy things back from the vendor's Buyback tab if needed." },
    { "Fast loot", "qolFastLoot", "Loots everything instantly when auto loot is on, so the loot window barely flashes. Works with your normal auto loot setting and modifier key." },
  })

  -- Questing
  local h3 = section(last, "Questing")
  last = checkList(h3, {
    { "Auto accept and turn in quests", "qolAutoQuest", "Accepts quests and hands in finished ones when you talk to the NPC. If there are several rewards to pick from, it stops so you choose. Never hands in repeatable item turn-ins (cloth, tokens). Hold Shift to talk normally." },
    { "Skip cutscenes you've already seen", "qolSkipCine", "The first time you always see it. After that it's skipped (hold Shift to watch it again)." },
    { "XP bar text", "qolXPText", "Shows % done, rested XP and roughly how many quests are left to the next level on your XP bar. The quest estimate starts after your first few hand-ins." },
  })

  -- Annoyances
  local h4 = section(last, "Fewer annoyances")
  last = checkList(h4, {
    { "Decline duels from strangers", "qolNoDuels", "Duel requests from anyone outside the gang are declined straight away. Gang members can still duel you." },
    { "Decline guild invites and charters", "qolNoGuildInv", "Guild invites and charter signature requests from strangers are declined. Gang members get through." },
    { "Accept summons automatically", "qolSummon", "Accepts a warlock or meeting stone summon, but never while you're in combat." },
    { "Accept resurrection automatically", "qolRes", "Takes a res as soon as it's offered. Not during a boss fight." },
    { "Hide red error spam", "qolNoErrors", "Hides \"Not enough rage\", \"Out of range\", \"Ability not ready\" and the like. Useful errors such as \"Inventory is full\" still show." },
    { "Max camera zoom-out", "qolMaxZoom", "Lets you zoom the camera further out than the default. Switching it off puts your old setting back." },
  })

  -- Info
  local h5 = section(last, "Info")
  last = checkList(h5, {
    { "Red tint on items you can't use", "qolTint", "Items in your bags that you can't use yet (level, class, skill, already known) get a red icon." },
    { "Flight timer", "qolFlightTimer", "Shows a small bar with time left on flight paths. The first time you fly a route it learns how long it takes. Drag it to move it." },
  })

  function tab:Refresh()
    for _, cb in ipairs(checks) do cb:Refresh() end
    local cur = (S().qolTrinketSlot == 13) and 13 or 14
    for _, b in ipairs(slotBtns) do
      if b.SetStyle then b:SetStyle(b.slot == cur and "secondary" or "ghost") end
      b:SetAlpha(b.slot == cur and 1 or 0.6)
    end
    local ok, txt = pcall(ns.QoL.MountGearSummary, ns.QoL)
    found:SetText(ok and txt or "")
  end
end)
