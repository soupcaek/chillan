-- Chillan? – "Home": what's going on right now, in one look (1.0).
-- Who's online, the gang's latest moments, quick actions and this week's race.
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("home", "Home", "Friends", function(tab)
  local LEFT_W, RIGHT_W = 250, 214

  -- left: online now
  local left = CreateFrame("Frame", nil, tab)
  left:SetPoint("TOPLEFT", 14, -12)
  left:SetPoint("BOTTOMLEFT", 14, 12)
  left:SetWidth(LEFT_W)
  local lh = UI.Text(left, 11, "semi", C.dim)
  lh:SetPoint("TOPLEFT", 2, 0)
  lh:SetText("ONLINE NOW")

  local function createRow(list)
    local row = CreateFrame("Button", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.name = UI.Text(row, 13, "semi", C.text)
    row.name:SetPoint("TOPLEFT", 10, -7)
    row.name:SetPoint("RIGHT", -56, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.tag = UI.Text(row, 10, nil, C.muted)
    row.tag:SetPoint("TOPRIGHT", -10, -9)
    row.sub = UI.Text(row, 11, nil, C.dim)
    row.sub:SetPoint("BOTTOMLEFT", 10, 7)
    row.sub:SetPoint("RIGHT", -10, 0)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetWordWrap(false)
    row:SetScript("OnEnter", function(self)
      if not self.item or self.item.note then return end
      self.panel:SetColors(C.cardHover, C.line)
      ns.Overlays:ShowProfile(self, self.item.pid)
    end)
    row:SetScript("OnLeave", function(self)
      self.panel:SetColors(C.card, C.line)
      ns.Overlays:HideProfile()
    end)
    row:SetScript("OnClick", function(self)
      if not self.item or self.item.note then return end
      ns.Overlays:HideProfile()
      if IsShiftKeyDown() then ns.PersonCard:Pin(self.item.pid) else ns.Window:OpenPlayer(self.item.pid) end
    end)
    return row
  end
  local function updateRow(row, p)
    if p.note then
      row.panel:Hide()
      row.name:SetText("")
      row.tag:SetText("")
      row.sub:SetText(p.note)
      return
    end
    row.panel:Show()
    local c = ns:PersonChar(p) or {}
    local L = p.live or {}
    row.name:SetText(ns:ShortWho(p) .. ns.Colorize(" · " .. tostring(c.level or "?"), C.muted))
    local tag = ""
    if L.inInst then tag = "dungeon"
    elseif L.status == "AFK" then tag = "AFK"
    elseif L.layer and ns.Layer then tag = ns.Layer.Label(L.layer) end
    local mine = ns.Layer and ns.Layer:Current()
    row.tag:SetText(tag)
    row.tag:SetTextColor(hex((L.layer and mine and L.layer == mine and not L.inInst) and "9BE08A" or C.muted))
    local z = L.zone or ""
    if L.sub and L.sub ~= "" and L.sub ~= z then z = z .. ", " .. L.sub end
    row.sub:SetText(z ~= "" and z or "online")
  end
  local list = UI.List(left, 44, 6, createRow, updateRow)
  list:SetPoint("TOPLEFT", lh, "BOTTOMLEFT", -2, -8)
  list:SetPoint("BOTTOMRIGHT", 0, 0)
  list.emptyText = "Nobody else online right now."

  -- right: quick actions and this week
  local right = CreateFrame("Frame", nil, tab)
  right:SetPoint("TOPRIGHT", -14, -12)
  right:SetPoint("BOTTOMRIGHT", -14, 12)
  right:SetWidth(RIGHT_W)
  local rh = UI.Text(right, 11, "semi", C.dim)
  rh:SetPoint("TOPLEFT", 2, 0)
  rh:SetText("QUICK ACTIONS")

  local function action(label, icon, tip, fn)
    local b = UI.Button(right, RIGHT_W, 36, label, "secondary", fn)
    if icon then b:SetIcon(icon, 14) end
    b.tooltip = tip
    return b
  end
  local hop = action("Layer hop", "Radar", "Join someone on another layer – the gang first, then LayerSwap users nearby",
    function() ns.LayerHop:Request() end)
  hop:SetPoint("TOPLEFT", rh, "BOTTOMLEFT", -2, -8)
  local ready = action("Ready check", "Check", "Bag space, durability and food/drink for everyone in the group",
    function() ns.Extras:StartReadyCheck() end)
  ready:SetPoint("TOPLEFT", hop, "BOTTOMLEFT", 0, -8)
  local edit = action("Move things on screen", "Gear", "Edit mode: drag every Chillan piece on screen at once (/chill edit)",
    function() ns.UI.EditMode(true) end)
  edit:SetPoint("TOPLEFT", ready, "BOTTOMLEFT", 0, -8)

  local wh = UI.Text(right, 11, "semi", C.dim)
  wh:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", 2, -18)
  wh:SetText("THIS WEEK")
  local week = UI.Panel(right, C.card, C.line, false)
  week:SetPoint("TOPLEFT", wh, "BOTTOMLEFT", -2, -8)
  week:SetPoint("RIGHT", right, "RIGHT", 0, 0)
  week:SetHeight(112)
  week.title = UI.Text(week, 12, "semi", C.text)
  week.title:SetPoint("TOPLEFT", 12, -10)
  week.title:SetPoint("RIGHT", -12, 0)
  week.title:SetJustifyH("LEFT")
  week.body = UI.Text(week, 12, nil, C.text2)
  week.body:SetPoint("TOPLEFT", week.title, "BOTTOMLEFT", 0, -6)
  week.body:SetPoint("RIGHT", -12, 0)
  week.body:SetJustifyH("LEFT")
  week.body:SetSpacing(3)

  local nextEv = UI.Text(right, 12, nil, C.text2)
  nextEv:SetPoint("TOPLEFT", week, "BOTTOMLEFT", 2, -12)
  nextEv:SetPoint("RIGHT", right, "RIGHT", 0, 0)
  nextEv:SetJustifyH("LEFT")
  nextEv:SetWordWrap(true)

  -- middle: the gang's latest moments
  local mid = CreateFrame("Frame", nil, tab)
  mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 16, 0)
  mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", -16, 0)
  local mh = UI.Text(mid, 11, "semi", C.dim)
  mh:SetPoint("TOPLEFT", 2, 0)
  mh:SetText("THE GANG LATELY")
  local box = UI.Panel(mid, C.card, C.line, false)
  box:SetPoint("TOPLEFT", mh, "BOTTOMLEFT", -2, -8)
  box:SetPoint("BOTTOMRIGHT", 0, 0)
  local feed = UI.MessageFrame(box, 12)
  feed:SetPoint("TOPLEFT", 12, -10)
  feed:SetPoint("BOTTOMRIGHT", -12, 10)
  feed:SetSpacing(6)

  -- small things (quests, online/offline) aren't feed items; the feed is already the big moments
  local function drawFeed()
    feed:Clear()
    local items = ns.db.feed or {}
    for i = math.max(1, #items - 40), #items do
      local ok, line = pcall(ns.FeedLine, items[i], true)
      if ok and line then feed:AddMessage(line) end
    end
    if #items == 0 then feed:AddMessage(ns.Colorize("Dings, drops, kills and trophies from the gang show up here.", C.dim)) end
  end

  local function drawWeek()
    local ok, chal, leader = pcall(ns.Data.CurrentLeader, ns.Data)
    if not ok or not chal then week.title:SetText("Weekly challenge") week.body:SetText("") return end
    week.title:SetText("Challenge: " .. tostring(chal.label))
    local rank = {}
    for _, p in ipairs(ns:SortedPeople()) do
      local x = ns:WeekStat(p, chal.key)
      if x > 0 then rank[#rank + 1] = { p = p, v = x } end
    end
    table.sort(rank, function(a, b) if a.v ~= b.v then return a.v > b.v end return (a.p.pid or "") < (b.p.pid or "") end)
    local lines = {}
    for k = 1, math.min(3, #rank) do
      lines[k] = k .. ". " .. ns:ShortWho(rank[k].p) .. ns.Colorize("  " .. (chal.fmt and chal.fmt(rank[k].v) or tostring(rank[k].v)), C.muted)
    end
    -- where am I? (titles and challenges are a race)
    local me = ns:GetPerson(ns.pid)
    for k, r in ipairs(rank) do
      if r.p == me and k > 1 then
        local gap = rank[k - 1].v - r.v
        lines[#lines + 1] = ns.Colorize("You're no. " .. k .. ", " .. (chal.fmt and chal.fmt(gap) or gap) .. " behind", C.accent)
        break
      end
    end
    week.body:SetText(#lines > 0 and table.concat(lines, "\n") or ns.Colorize("No points yet this week.", C.dim))
  end

  local function drawEvent()
    local best
    for _, ev in ipairs(ns.db.events or {}) do
      if not best or (ev.t or 0) > (best.t or 0) then best = ev end
    end
    if best then
      local coming = 0
      for _, st in pairs(best.rsvp or {}) do if st == "yes" or st == 1 or st == "coming" then coming = coming + 1 end end
      nextEv:SetText(ns.Colorize(tostring(best.when or ""), C.text) .. "\n" .. tostring(best.title or "") .. (coming > 0 and ns.Colorize("  ·  " .. coming .. " coming", C.muted) or ""))
    else
      nextEv:SetText(ns.Colorize("No plans yet – add one under Gang.", C.dim))
    end
  end

  function tab:Refresh()
    local people = ns:SortedPeople(function(p, pid) return pid ~= ns.pid and ns:IsOnline(p) end)
    table.sort(people, function(a, b) return ns:PersonMaxLevel(a) > ns:PersonMaxLevel(b) end)
    local total = 0
    for pid, p in pairs(ns.db.people or {}) do if pid ~= ns.pid and p.main then total = total + 1 end end
    if total > #people then people[#people + 1] = { note = (total - #people) .. " offline · see Gang" } end
    list:SetData(people)
    local cur = ns.Layer and ns.Layer:CurrentLabel()
    hop:SetLabel(cur and ("Layer hop  ·  " .. cur) or "Layer hop")
    drawFeed()
    drawWeek()
    drawEvent()
  end
end)
