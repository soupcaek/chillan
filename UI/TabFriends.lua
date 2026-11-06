-- Chillan? – fanen "Venner"
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

ns:RegisterTab("friends", "Venner", "Friends", function(tab)
  local filter = "online"

  local head = UI.Text(tab, 15, "semi", C.text)
  head:SetPoint("TOPLEFT", 16, -16)
  head:SetText("Venner")
  local count = UI.Text(tab, 13, nil, C.dim)
  count:SetPoint("LEFT", head, "RIGHT", 8, 0)
  local mine = UI.Button(tab, 80, 26, "Min side", "ghost", function() ns.Window:OpenPlayer(ns.pid) end)
  mine:SetPoint("LEFT", count, "RIGHT", 10, 0)

  local filterButtons = {}
  local function setFilter(key)
    filter = key
    for k, b in pairs(filterButtons) do
      if k == key then
        b.panel:SetColors(C.active, C.activeLine) b.label:SetTextColor(hex(C.text)) b.style = { fill = C.active, line = C.activeLine, text = C.text, hover = "33383E" }
      else
        b.panel:SetColors(nil, C.inputLine) b.label:SetTextColor(hex(C.muted)) b.style = { fill = nil, line = C.inputLine, text = C.muted, hover = C.card }
      end
    end
    tab:Refresh()
  end
  local prev
  for _, def in ipairs({ { "zone", "Samme sone" }, { "all", "Alle" }, { "online", "Online" } }) do
    local b = UI.Button(tab, 10, 28, def[2], "ghost", function() setFilter(def[1]) end)
    b:SetWidth(b.label:GetStringWidth() + 22)
    if prev then b:SetPoint("RIGHT", prev, "LEFT", -6, 0) else b:SetPoint("TOPRIGHT", -16, -12) end
    prev = b
    filterButtons[def[1]] = b
  end

  -- Rader
  local function createRow(list)
    local row = CreateFrame("Button", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.avatar = UI.Avatar(row, 34)
    row.avatar:SetPoint("LEFT", 10, 0)
    row.name = UI.Text(row, 14, "semi", C.text)
    row.name:SetPoint("TOPLEFT", row.avatar, "TOPRIGHT", 12, 0)
    row.name:SetWidth(186)
    row.sub = UI.Text(row, 12, nil, C.dim)
    row.sub:SetPoint("BOTTOMLEFT", row.avatar, "BOTTOMRIGHT", 12, 0)
    row.sub:SetWidth(170)
    row.zone = UI.Text(row, 13, nil, C.text2)
    row.zone:SetPoint("TOPLEFT", row.avatar, "TOPRIGHT", 196, 0)
    row.zone:SetWidth(170)
    row.time = UI.Text(row, 12, nil, C.dim)
    row.time:SetPoint("BOTTOMLEFT", row.avatar, "BOTTOMRIGHT", 196, 0)
    row.time:SetWidth(170)
    row.invite = UI.Button(row, 66, 30, "Inviter", "primary")
    row.invite:SetPoint("RIGHT", -10, 0)
    row.whisper = UI.IconButton(row, 30, "Chat", "Hvisk")
    row.whisper:SetPoint("RIGHT", row.invite, "LEFT", -6, 0)
    row.pill = UI.Pill(row)
    row.pill:SetPoint("RIGHT", row.whisper, "LEFT", -10, 0)
    row:SetScript("OnEnter", function(self)
      self.panel:SetColors(C.cardHover, C.line)
      if self.item then ns.Overlays:ShowProfile(self, self.item.pid) end
    end)
    row:SetScript("OnLeave", function(self)
      self.panel:SetColors(C.card, C.line)
      ns.Overlays:HideProfile()
    end)
    row:SetScript("OnClick", function(self)
      ns.Overlays:HideProfile()
      if self.item then tab:ToggleQuick(self, self.item) end
    end)
    return row
  end

  local function updateRow(row, p)
    local online = ns:IsOnline(p)
    local c = ns:PersonChar(p) or {}
    local L = p.live or {}
    local status = online and (L.status or "QUEST") or "OFFLINE"
    local st = ns.STATUS[status] or ns.STATUS.QUEST
    row.avatar:Set(c.name, c.class, online and (status == "AFK" and C.amber or C.green) or nil)
    row.name:SetText(ns:PersonLabel(p))
    row.sub:SetText(string.format("Lvl %s · %s %s", c.level or "?", c.race or "", c.class and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class] or c.class) or ""))
    if online then
      local z = L.zone or ""
      if L.sub and L.sub ~= "" and L.sub ~= z then z = z .. ", " .. L.sub end
      row.zone:SetText(z)
      row.time:SetText("Online " .. ns.Duration(ns.Now() - (L.session or ns.Now())))
      row:SetAlpha(1)
      row.invite:Show()
    else
      row.zone:SetText(L.zone or "")
      row.time:SetText("Sist sett " .. ns.Ago(p.lastSeen))
      row:SetAlpha(0.55)
      row.invite:Hide()
    end
    row.pill:Set(st.label, st.color)
    local target = L.char or p.main
    row.whisper:SetScript("OnClick", function() ns.Whisper(target) end)
    row.invite:SetScript("OnClick", function() ns.Invite(target) end)
  end

  local list = UI.List(tab, 52, 6, createRow, updateRow)
  list:SetPoint("TOPLEFT", 12, -48)
  list:SetPoint("BOTTOMRIGHT", -12, 60)
  list.emptyText = "Ingen her ennå. Del gjengkoden din (se fanen Mer), så dukker vennene dine opp når de logger på."

  -- Hurtigkort som dukker opp under vennen du klikker på
  local quick = UI.Panel(tab, "202429", C.activeLine, false)
  quick:SetHeight(112)
  quick:SetFrameLevel(list:GetFrameLevel() + 30)
  quick:EnableMouse(true)
  quick:Hide()
  quick.cells = {}
  for i = 1, 4 do
    local cell = CreateFrame("Frame", nil, quick)
    cell:SetSize(130, 40)
    cell:SetPoint("TOPLEFT", 14 + (i - 1) * 136, -12)
    cell.v = UI.Text(cell, 15, "bold", C.text)
    cell.v:SetPoint("TOPLEFT")
    cell.v:SetWidth(128)
    cell.k = UI.Text(cell, 11, nil, C.muted)
    cell.k:SetPoint("BOTTOMLEFT")
    cell.k:SetWidth(128)
    quick.cells[i] = cell
  end
  quick.info = UI.Text(quick, 12, nil, C.text2)
  quick.info:SetPoint("BOTTOMLEFT", 14, 16)
  quick.info:SetPoint("RIGHT", -230, 0)
  quick.open = UI.Button(quick, 120, 30, "Åpne spiller ›", "primary")
  quick.open:SetPoint("BOTTOMRIGHT", -12, 10)
  quick.wh = UI.Button(quick, 70, 30, "Hvisk", "secondary")
  quick.wh:SetPoint("RIGHT", quick.open, "LEFT", -8, 0)

  local function fillQuick(p)
    local s3 = ns:PersonS3(p) or {}
    local rate = ns.St:XPRate(p)
    local eta = ns.St:ETA(p)
    local pct = ns.Pct(s3.xp, s3.xpMax)
    local vals = {
      { rate and ns.Num(rate) or "–", "XP per time" },
      { eta and ("ca. " .. ns.Duration(eta)) or "–", "til neste level" .. (pct and (" (" .. pct .. " %)") or "") },
      { s3.today and ns.Duration(s3.today) or "–", "online i dag" },
      { s3.streak and (s3.streak .. " d") or "–", "streak" },
    }
    for i, cell in ipairs(quick.cells) do
      cell.v:SetText(vals[i][1])
      cell.k:SetText(vals[i][2])
    end
    local parts = {}
    parts[#parts + 1] = math.floor(ns:WeekStat(p, "Quests")) .. " quests denne uka"
    if s3.money then parts[#parts + 1] = ns.Money(s3.money) .. " i lomma" end
    if s3.ilvl then parts[#parts + 1] = "ilvl " .. s3.ilvl end
    quick.info:SetText(table.concat(parts, "  ·  "))
    local target = (p.live and p.live.char) or p.main
    quick.wh:SetScript("OnClick", function() ns.Whisper(target) end)
    quick.wh:SetShown(p.pid ~= ns.pid)
    quick.open:SetScript("OnClick", function() quick:Hide() ns.Window:OpenPlayer(p.pid) end)
  end

  function tab:ToggleQuick(row, p)
    if quick:IsShown() and quick.pid == p.pid then quick:Hide() return end
    quick.pid = p.pid
    quick.row = row
    fillQuick(p)
    quick:ClearAllPoints()
    quick:SetPoint("LEFT", row, "LEFT", 0, 0)
    quick:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    -- under raden hvis det er plass, ellers over
    local rowBottom, listBottom = row:GetBottom(), list:GetBottom()
    if rowBottom and listBottom and (rowBottom - 118) < listBottom then
      quick:SetPoint("BOTTOM", row, "TOP", 0, 4)
    else
      quick:SetPoint("TOP", row, "BOTTOM", 0, -4)
    end
    quick:Show()
  end
  list:HookScript("OnMouseWheel", function() quick:Hide() end)
  tab:HookScript("OnHide", function() quick:Hide() end)

  -- Bunnlinje: egen status og SOS
  local line = UI.SolidLine(tab)
  line:SetPoint("BOTTOMLEFT", 0, 52)
  line:SetPoint("BOTTOMRIGHT", 0, 52)
  line:SetHeight(1)

  local sl = UI.Text(tab, 12, nil, C.dim)
  sl:SetPoint("BOTTOMLEFT", 16, 20)
  sl:SetText("Din status")
  local statusBtn = UI.Button(tab, 170, 32, "", "ghost")
  statusBtn:SetPoint("LEFT", sl, "RIGHT", 10, 0)
  statusBtn.label:SetTextColor(hex(C.text))
  statusBtn:SetScript("OnClick", function(self)
    local items = {}
    for _, code in ipairs(ns.MANUAL_STATUS) do
      local label = code == "AUTO" and "Automatisk" or ns.STATUS[code].label
      items[#items + 1] = { text = label, color = code ~= "AUTO" and ns.STATUS[code].color or nil,
        func = function() ns.Tracker:SetStatus(code) tab:Refresh() end }
    end
    UI.Menu(self, items)
  end)

  local sos = UI.Button(tab, 170, 36, "SOS – blir ganket", "danger", function() ns.Data:SOS() end)
  sos:SetIcon("SOS", 15)
  sos:SetPoint("BOTTOMRIGHT", -16, 8)

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
    list:SetData(people)
    if quick:IsShown() then
      if not quick.row or not quick.row.item or quick.row.item.pid ~= quick.pid then
        quick:Hide()
      else
        fillQuick(quick.row.item)
      end
    end
    local n, total = ns.Window:OnlineCount()
    count:SetText(n .. " av " .. total .. " online")
    local st = ns.Tracker:Status()
    local manual = ns.db.statusOverride
    statusBtn:SetLabel((ns.STATUS[st] and ns.STATUS[st].label or st) .. (manual and "" or "  (auto)"))
  end

  setFilter("online")
end)
