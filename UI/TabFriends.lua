-- Chillan? – "Friends"
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

function ns.Whisper(char)
  if not char then return end
  local target = char
  local fn = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell
  if fn then pcall(fn, target) end
end

function ns.Invite(char)
  if not char then return end
  if C_PartyInfo and C_PartyInfo.InviteUnit then
    pcall(C_PartyInfo.InviteUnit, char)
  elseif InviteUnit then
    pcall(InviteUnit, char)
  end
end

ns:RegisterTab("friends", "Friends", "Friends", function(tab)
  local filter = "all"

  local head = UI.Text(tab, 15, "semi", C.text)
  head:SetPoint("TOPLEFT", 16, -16)
  head:SetText("Friends")
  local count = UI.Text(tab, 13, nil, C.dim)
  count:SetPoint("LEFT", head, "RIGHT", 8, 0)
  head:Hide() count:Hide()   -- (1.4.65) the count is in the Gang panel's strip
  local mine = UI.Button(tab, 80, 26, "My page", "ghost", function() ns.Window:OpenPlayer(ns.pid) end)
  mine:SetPoint("TOPLEFT", 12, -12)
  local mapBtn = UI.IconButton(tab, 26, "Map", "Open the world map (friends are pinned on it)", function() ns.OpenMapAt(nil) end)
  mapBtn:SetPoint("LEFT", mine, "RIGHT", 6, 0)
  local crownKey = UI.Text(tab, 11, nil, C.dim)
  crownKey:SetPoint("LEFT", mapBtn, "RIGHT", 12, 0)
  crownKey:SetText("")   -- (1.4.65) this week's titles are in their own panel

  -- (1.4.64) the filters as one choice bar, the list in a panel (the Market look)
  local FILTERS = { "all", "online", "zone" }
  local seg = UI.Seg(tab, { "All", "Online only", "Same zone" }, function()
    for i, k in ipairs(FILTERS) do if k == filter then return i end end
    return 1
  end, function(i) filter = FILTERS[i] tab:Refresh() end, 26)
  seg:SetPoint("TOPRIGHT", -12 - 270, -12)
  local function setFilter(key) filter = key seg:Refresh() tab:Refresh() end

  -- Rader
  local function createRow(list)
    local row = CreateFrame("Button", nil, list)
    row.panel = UI.Panel(row, nil, nil, true)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.avatar = UI.Avatar(row, 34)
    row.avatar:SetPoint("LEFT", 10, 0)
    row.name = UI.Text(row, 14, "semi", C.text)
    row.name:SetPoint("TOPLEFT", row.avatar, "TOPRIGHT", 12, 0)
    row.name:SetWordWrap(false)
    row.sub = UI.Text(row, 12, nil, C.dim)
    row.sub:SetPoint("BOTTOMLEFT", row.avatar, "BOTTOMRIGHT", 12, 0)
    row.sub:SetWordWrap(false)
    row.zone = UI.Text(row, 13, nil, C.text2)
    row.zone:SetJustifyH("LEFT")
    row.zone:SetWordWrap(false)
    row.time = UI.Text(row, 12, nil, C.dim)
    row.time:SetJustifyH("LEFT")
    row.time:SetWordWrap(false)
    row.invite = UI.Button(row, 66, 28, "Invite", "secondary")   -- (1.4.68) one loud button per panel, not one per row
    row.invite:SetPoint("RIGHT", -10, 0)
    row.whisper = UI.IconButton(row, 30, "Chat", "Whisper")
    row.whisper:SetPoint("RIGHT", row.invite, "LEFT", -6, 0)
    row.wp = UI.IconButton(row, 30, "Map", "Set a waypoint to them")
    row.wp:SetPoint("RIGHT", row.whisper, "LEFT", -6, 0)
    row.pill = UI.Pill(row)
    row.pill:SetPoint("RIGHT", row.wp, "LEFT", -10, 0)
    -- (1.2.2) watch this friend (Gang pulse → Watching); shows on hover, or always when watched
    row.watch = UI.IconButton(row, 26, "Eye", "Watch – see them under the Now card", function(b)
      local it = b:GetParent().item
      if it and it.pid then ns.Watch:Toggle(it.pid) tab:Refresh() end
    end)
    row.watch:SetPoint("RIGHT", row.pill, "LEFT", -8, 0)
    row.watch:Hide()
    row.sepText = UI.Text(row, 11, "semi", C.dim)
    row.sepText:SetPoint("BOTTOMLEFT", 6, 8)
    row.sepText:Hide()
    row.colX = -1
    row:SetScript("OnEnter", function(self)
      if not self.item or self.item.sep then return end
      if self.item.pid ~= ns.pid then self.watch:Show() end
      if not self.quickOpen then self.panel:SetColors(C.cardHover, nil) end
      ns.Overlays:ShowProfile(self, self.item.pid)
    end)
    row:SetScript("OnLeave", function(self)
      if self.watch and not self.watch:IsMouseOver() and not (self.item and ns.Watch:Has(self.item.pid)) then self.watch:Hide() end
      if not self.quickOpen then self.panel:SetColors(self.stripe, nil) end
      ns.Overlays:HideProfile()
    end)
    row:SetScript("OnClick", function(self)
      if self.item and not self.item.sep and IsShiftKeyDown() then ns.Watch:Toggle(self.item.pid) tab:Refresh() return end
      ns.Overlays:HideProfile()
      if self.item and not self.item.sep then tab:ToggleQuick(self, self.item) end
    end)
    return row
  end

  local colX = 184
  local measure = UI.Text(tab, 14, "semi", C.text)
  measure:Hide()
  local measureSub = UI.Text(tab, 12, nil, C.dim)
  measureSub:Hide()
  local function nameText(p)
    return ns:PersonLabel(p) .. " " .. ns.Titles:Badge(p.pid) .. (ns:IsMuted(p.pid) and ns.Colorize("  muted", C.dim) or "")
  end

  local ROW_PARTS = { "panel", "avatar", "name", "sub", "zone", "time", "invite", "whisper", "wp", "pill" }
  local function updateRow(row, p, idx)
    -- (1.4.64) striped rows instead of separate cards
    row.striped = true
    row.stripe = (idx or 1) % 2 == 0 and (C.rowAlt or C.card) or nil
    if not row.quickOpen then row.panel:SetColors(row.stripe, nil) end
    -- section line between online and offline friends
    if p.sep then
      for _, k in ipairs(ROW_PARTS) do if row[k] then row[k]:Hide() end end
      row.sepText:SetText(p.label)
      row.sepText:Show()
      row:SetAlpha(1)
      return
    end
    row.sepText:Hide()
    for _, k in ipairs({ "panel", "avatar", "name", "sub", "zone", "time", "whisper", "wp", "pill" }) do row[k]:Show() end
    local online = ns:IsOnline(p)
    local c = ns:PersonChar(p) or {}
    local L = p.live or {}
    local status = online and (L.status or "QUEST") or "OFFLINE"
    local st = ns.STATUS[status] or ns.STATUS.QUEST
    row.avatar:Set(c.name, c.class, online and (status == "AFK" and C.amber or C.green) or nil)
    row.name:SetText(nameText(p))
    local nAlts = #ns:AllChars(p) - 1
    row.sub:SetText(string.format("Lvl %s · %s %s", c.level or "?", c.race or "", c.class and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class] or c.class) or "")
      .. (nAlts > 0 and ns.Colorize("  ·  +" .. ns.Plural(nAlts, "alt"), C.muted) or ""))
    if online then
      local z = L.zone or ""
      if L.sub and L.sub ~= "" and L.sub ~= z then z = z .. ", " .. L.sub end
      if L.layer and not L.inInst and ns.Layer and ns.Layer.Comparable() then
        local mine = ns.Layer:Current()
        z = z .. ns.Colorize("  ·  " .. ns.Layer.Label(L.layer), (mine and mine == L.layer) and "9BE08A" or "9BA1A8")
      end
      row.zone:SetText(z)
      -- (1.4.68) no coordinates (they crowded the place name)
      row.time:SetText("Online " .. ns.Duration(ns.Now() - (L.session or ns.Now())))
      row:SetAlpha(1)
      row.invite:Show()
    else
      row.zone:SetText(L.zone or "")
      row.time:SetText("Last seen " .. ns.Ago(p.lastSeen))
      row:SetAlpha(0.55)
      row.invite:Hide()
    end
    row.pill:Set(st.label, st.color)
    local watched = ns.Watch and ns.Watch:Has(p.pid)
    row.watch:SetShown(watched and true or false)
    UI.Track(row.watch.icon):SetVertexColor(hex(watched and C.accent or C.muted))
    row.watch.tooltip = watched and "Stop watching" or "Watch – see them under the Now card"
    -- (1.1.7) offline friends: no "Offline" pill (the section says it) and no waypoint button
    row.pill:SetShown(online)
    row.wp:SetShown(online)
    -- columns size to the content: name column as wide as the longest name in the list,
    -- zone column takes everything up to the status pill (no more "..." when there is room)
    if row.colX ~= colX then
      row.colX = colX
      row.name:SetWidth(colX - 8); row.sub:SetWidth(colX - 8)
      row.zone:ClearAllPoints(); row.time:ClearAllPoints()
      row.zone:SetPoint("TOPLEFT", row.avatar, "TOPRIGHT", 12 + colX, 0)
      -- (1.4.68) the place ends with "…" before the watch eye, so they never overlap
      row.zone:SetPoint("RIGHT", row.watch, "LEFT", -6, 0)
      row.time:SetPoint("BOTTOMLEFT", row.avatar, "BOTTOMRIGHT", 12 + colX, 0)
      row.time:SetPoint("RIGHT", row.watch, "LEFT", -6, 0)
    end
    local target = L.char or p.main
    row.whisper:SetScript("OnClick", function() ns.Whisper(target) end)
    row.invite:SetScript("OnClick", function() ns.Invite(target) end)
    local c2 = c
    local canWp = online and L.x and L.y and L.mapID
    row.wp:SetAlpha(canWp and 1 or 0.3)
    row.wp:SetScript("OnClick", function()
      if canWp and ns.SetWaypoint(L.mapID, L.x, L.y) then
        ns.Print("Waypoint set to " .. (ns:PersonAlias(p) or c2.name or "?") .. ".")
        ns.OpenMapAt(L.mapID)
      end
    end)
  end

  local listP = UI.Section(tab, "Gang")
  listP:SetPoint("TOPLEFT", 12, -46)
  listP:SetPoint("BOTTOMRIGHT", -12 - 270, 12)
  local list = UI.List(listP.body, 52, 0, createRow, updateRow)
  list:SetPoint("TOPLEFT", -4, 0)
  list:SetPoint("BOTTOMRIGHT", 4, 0)
  list.emptyText = "Nobody here yet. Share your gang code (see the More tab), and your friends show up when they log in."

  -- (1.2.0) the quick card: joined to the row you clicked, with all their characters
  local quick = UI.PersonQuick(tab, { side = "below", bounds = list, onChange = function() tab:Refresh() end })
  quick:SetFrameLevel(list:GetFrameLevel() + 30)
  function tab:ToggleQuick(row, p) quick:Toggle(row, p) end
  list:HookScript("OnMouseWheel", function() quick:Close() end)
  tab:HookScript("OnHide", function() quick:Close() end)

  -- Bottom line: your own status and the ready check
  -- (1.4.65) the side column (canvas): your status, the group buttons, this week's titles
  local side = CreateFrame("Frame", nil, tab)
  side:SetPoint("TOPRIGHT", -12, -12)
  side:SetPoint("BOTTOMRIGHT", -12, 12)
  side:SetWidth(260)
  local stP = UI.Section(side, "Your status", true)
  stP:SetPoint("TOPLEFT") stP:SetPoint("TOPRIGHT")
  stP:FitBody(48)
  local statusCodes = ns.MANUAL_STATUS
  local stSeg = UI.Seg(stP.body, (function()
    local o = {}
    for i, code in ipairs(statusCodes) do
      o[i] = code == "AUTO" and { "Auto", "Your status follows what you do (questing, in a dungeon, AFK)" }
        or code == "LFG" and { "LFG", ns.STATUS.LFG.label } or code == "HELP" and { "Help", ns.STATUS.HELP.label }
        or code == "DND" and { "DND", ns.STATUS.DND.label } or { code }
    end
    return o
  end)(), function()
    local cur = ns.db.statusOverride or "AUTO"
    for i, code in ipairs(statusCodes) do if code == cur then return i end end
    return 1
  end, function(i) ns.Tracker:SetStatus(statusCodes[i]) tab:Refresh() end)
  stSeg:SetPoint("TOPLEFT", 0, 0)
  local stNow = UI.Text(stP.body, 11, nil, C.dim)
  stNow:SetPoint("TOPLEFT", 0, -32)
  local grP = UI.Section(side, "Group")
  grP:SetPoint("TOPLEFT", stP, "BOTTOMLEFT", 0, -10) grP:SetPoint("TOPRIGHT", stP, "BOTTOMRIGHT", 0, -10)
  grP:FitBody(28)
  local ready = UI.Button(grP.body, 112, 28, "Ready check", "secondary", function() ns.Extras:StartReadyCheck() end)
  ready:SetIcon("Check", 12)
  ready:SetPoint("TOPLEFT", 0, 0)
  ready.tooltip = "Checks bag space, durability and food and drink for everyone in the group"
  local hop = UI.Button(grP.body, 104, 28, "Layer hop", "secondary", function() if ns.LayerHop then ns.LayerHop:Request() end end)
  hop:SetPoint("LEFT", ready, "RIGHT", 6, 0)
  hop.tooltip = "Join someone on another layer – the gang first, then LayerSwap users nearby"
  local wkP = UI.Section(side, "This week")
  wkP:SetPoint("TOPLEFT", grP, "BOTTOMLEFT", 0, -10) wkP:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", 0, 0)
  local wkRows = {}
  for i = 1, 8 do
    local l = UI.Text(wkP.body, 12, nil, C.dim)
    l:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
    local r = UI.Text(wkP.body, 12, nil, C.text)
    r:SetPoint("TOPRIGHT", 0, -(i - 1) * 22)
    r:SetJustifyH("RIGHT")
    wkRows[i] = { l = l, r = r }
  end
  local function paintWeek()
    local cur = ns.Titles and ns.Titles:Current() or {}
    local i = 0
    for _, def in ipairs(ns.Titles and ns.Titles.DEFS or {}) do
      local h = cur[def.key]
      local p = h and ns:GetPerson(h.pid)
      if p and i < #wkRows then
        i = i + 1
        wkRows[i].l:SetText(ns.Colorize(def.name, def.color))
        wkRows[i].r:SetText(ns:PersonLabel(p))
      end
    end
    for k = i + 1, #wkRows do wkRows[k].l:SetText("") wkRows[k].r:SetText("") end
    if i == 0 then wkRows[1].l:SetText("No titles yet this week.") end
  end

  function tab:Refresh()
    local myZone = ns.Tracker:Me().live and ns.Tracker:Me().live.zone
    local people = ns:SortedPeople(function(p, pid)
      if pid == ns.pid then return false end
      local on = ns:IsOnline(p)
      if filter == "online" then return on end
      if filter == "zone" then return on and p.live and p.live.zone == myZone end
      -- skjul de som ikke har vært innom på over 30 dager
      return on or (ns.Now() - (p.lastSeen or 0)) < 30 * 86400
    end)
    table.sort(people, function(a, b)
      local ao, bo = ns:IsOnline(a), ns:IsOnline(b)
      if ao ~= bo then return ao end
      if ao then return ns:PersonMaxLevel(a) > ns:PersonMaxLevel(b) end
      return (a.lastSeen or 0) > (b.lastSeen or 0)
    end)
    local w = 0
    for _, p in ipairs(people) do
      measure:SetText(nameText(p))
      w = math.max(w, measure:GetStringWidth() + 4)
      local c = ns:PersonChar(p) or {}
      measureSub:SetText(string.format("Lvl %s · %s %s", c.level or "?", c.race or "", c.class or ""))
      w = math.max(w, measureSub:GetStringWidth())
    end
    local maxCol = math.max(184, (list:GetWidth() or 640) - 360)
    colX = math.floor(math.min(maxCol, math.max(150, w + 18)))
    -- "All": online on top, then an "Offline" line and the rest dimmed
    if filter == "all" then
      local firstOff
      for i, p in ipairs(people) do if not ns:IsOnline(p) then firstOff = i break end end
      if firstOff and firstOff > 1 then   -- (1.1.7) no gap when nobody is online
        table.insert(people, firstOff, { sep = true, label = "OFFLINE  ·  " .. (#people - firstOff + 1) })
      end
    end
    list:SetData(people)
    quick:Refresh()
    local n, total = ns.Window:OnlineCount()
    count:SetText(n .. " of " .. total .. " online")
    listP.right:SetText(n .. " of " .. total .. " online")
    local st = ns.Tracker:Status()
    stSeg:Refresh()
    stNow:SetText("Friends see: " .. ns.Colorize(ns.STATUS[st] and ns.STATUS[st].label or st, ns.STATUS[st] and ns.STATUS[st].color or C.text))
    paintWeek()
  end

  setFilter("all")
end)
