-- Chillan? – fanen "Topp": leaderboard og konkurranser
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("board", "Topp", "Board", function(tab)
  local RIGHT_W = 214
  local mode = "week"
  local sortKey = "level"
  local COLS = {
    { key = "rank", label = "#", w = 26 },
    { key = "name", label = "Spiller", w = 0 },
    { key = "level", label = "Level", w = 48, right = true },
    { key = "played", label = "/played", w = 74, right = true },
    { key = "online", label = "Online", w = 74, right = true },
    { key = "quests", label = "Quests", w = 54, right = true },
  }

  local left = CreateFrame("Frame", nil, tab)
  left:SetPoint("TOPLEFT", 16, -14)
  left:SetPoint("BOTTOMRIGHT", -RIGHT_W - 30, 14)

  local h = UI.Text(left, 15, "semi", C.text)
  h:SetPoint("TOPLEFT")
  h:SetText("Leaderboard")

  local seg = UI.Panel(left, C.input, C.inputLine, true)
  seg:SetSize(170, 30)
  seg:SetPoint("TOPRIGHT", 0, 4)
  local segBtns = {}
  local function paintSeg()
    for k, b in pairs(segBtns) do
      if k == mode then b.panel:SetColors("33383E", nil) b.label:SetTextColor(hex(C.text))
      else b.panel:SetColors(nil, nil) b.label:SetTextColor(hex(C.muted)) end
      b.style = { fill = k == mode and "33383E" or nil, text = k == mode and C.text or C.muted, hover = "2D3237" }
    end
  end
  for i, def in ipairs({ { "week", "Denne uka" }, { "total", "Totalt" } }) do
    local b = UI.Button(seg, 82, 24, def[2], "nav", function() mode = def[1] paintSeg() tab:Refresh() end)
    b:SetPoint("LEFT", 3 + (i - 1) * 83, 0)
    segBtns[def[1]] = b
  end
  paintSeg()

  -- Kolonneoverskrifter (klikk for å sortere)
  local header = CreateFrame("Frame", nil, left)
  header:SetPoint("TOPLEFT", 0, -38)
  header:SetPoint("TOPRIGHT", -6, -38)
  header:SetHeight(18)
  local headerTexts = {}

  local function layoutCols(parent, cells, inset)
    local x = inset or 10
    local rightX = -(inset or 10)
    for i = #COLS, 3, -1 do
      local col = COLS[i]
      cells[col.key]:ClearAllPoints()
      cells[col.key]:SetPoint("RIGHT", parent, "RIGHT", rightX, 0)
      cells[col.key]:SetWidth(col.w)
      cells[col.key]:SetJustifyH("RIGHT")
      rightX = rightX - col.w - 8
    end
    cells.rank:ClearAllPoints()
    cells.rank:SetPoint("LEFT", parent, "LEFT", x, 0)
    cells.rank:SetWidth(COLS[1].w)
    cells.name:ClearAllPoints()
    cells.name:SetPoint("LEFT", parent, "LEFT", x + COLS[1].w + 8, 0)
    cells.name:SetPoint("RIGHT", parent, "RIGHT", rightX, 0)
  end

  for _, col in ipairs(COLS) do
    local t = UI.Text(header, 10, "semi", C.dim)
    t:SetText(col.label:upper())
    headerTexts[col.key] = t
    if col.key ~= "rank" and col.key ~= "name" then
      local hit = CreateFrame("Button", nil, header)
      hit:SetAllPoints(t)
      hit:SetScript("OnClick", function() sortKey = col.key tab:Refresh() end)
    end
  end
  layoutCols(header, headerTexts, 10)

  local medal = { C.gold, C.silver, C.bronze }

  local function createRow(list)
    local row = CreateFrame("Button", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.cells = {}
    row.cells.rank = UI.Text(row, 13, "bold", C.dim)
    row.cells.name = UI.Text(row, 13, "semi", C.text)
    row.cells.level = UI.Text(row, 13, nil, C.text)
    row.cells.played = UI.Text(row, 13, nil, C.text2)
    row.cells.online = UI.Text(row, 13, nil, C.text2)
    row.cells.quests = UI.Text(row, 13, nil, C.text2)
    row.alts = UI.Text(row, 11, nil, C.dim)
    layoutCols(row, row.cells, 10)
    row.cells.name:ClearAllPoints()
    row.cells.name:SetPoint("TOPLEFT", row, "TOPLEFT", 10 + COLS[1].w + 8, -7)
    row.cells.name:SetPoint("RIGHT", row.cells.level, "LEFT", -8, 0)
    row.alts:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10 + COLS[1].w + 8, 7)
    row:SetScript("OnEnter", function(self)
      self.panel:SetColors(C.cardHover, C.line)
      if self.item then ns.Overlays:ShowProfile(self, self.item.pid) end
    end)
    row:SetScript("OnLeave", function(self)
      self.panel:SetColors(self.isTop and C.cardHover or C.card, C.line)
      ns.Overlays:HideProfile()
    end)
    return row
  end

  local function value(p, key)
    if key == "level" then return ns:PersonMaxLevel(p) end
    if key == "played" then return ns:PersonPlayed(p) end
    if key == "online" then return mode == "week" and ns:WeekStat(p, "Online") or ns:TotalStat(p, "Online") end
    if key == "quests" then return mode == "week" and ns:WeekStat(p, "Quests") or ns:TotalStat(p, "Quests") end
    return 0
  end

  local function updateRow(row, p, idx)
    local c = ns:PersonChar(p) or {}
    row.isTop = idx == 1
    row.panel:SetColors(idx == 1 and C.cardHover or C.card, C.line)
    row.cells.rank:SetText(idx)
    row.cells.rank:SetTextColor(hex(medal[idx] or C.dim))
    row.cells.name:SetText(ns.Colorize(ns:PersonName(p), ns.ClassHex(c.class)))
    local alts = ns:PersonAltCount(p)
    local pid = p.pid
    row.alts:SetText((pid == ns.pid and "deg · " or "") .. (alts > 0 and ("+ " .. alts .. (alts == 1 and " alt" or " alts")) or "ingen alts"))
    row.cells.level:SetText(ns:PersonMaxLevel(p))
    local played = ns:PersonPlayed(p)
    row.cells.played:SetText(played > 0 and ns.Duration(played) or "–")
    row.cells.online:SetText(ns.Duration(value(p, "online")))
    row.cells.quests:SetText(math.floor(value(p, "quests")))
  end

  local list = UI.List(left, 44, 6, createRow, updateRow)
  list:SetPoint("TOPLEFT", 0, -62)
  list:SetPoint("BOTTOMRIGHT", 6, 0)
  list.emptyText = "Ingen data ennå."

  -- Høyre kolonne: kort
  local right = CreateFrame("Frame", nil, tab)
  right:SetPoint("TOPRIGHT", -16, -14)
  right:SetPoint("BOTTOMRIGHT", -16, 14)
  right:SetWidth(RIGHT_W)

  local function card(height, titleText)
    local cd = UI.Panel(right, C.card, C.line, false)
    cd:SetHeight(height)
    cd.title = UI.Text(cd, 10, "semi", C.dim)
    cd.title:SetPoint("TOPLEFT", 12, -12)
    cd.title:SetText(titleText:upper())
    return cd
  end

  local ch = card(76, "Ukens utfordring")
  ch:SetPoint("TOPLEFT") ch:SetPoint("TOPRIGHT")
  ch.main = UI.Text(ch, 14, "semi", C.text)
  ch.main:SetPoint("TOPLEFT", 12, -30)
  ch.sub = UI.Text(ch, 12, nil, C.muted)
  ch.sub:SetPoint("TOPLEFT", 12, -50)
  ch.sub:SetPoint("RIGHT", -10, 0)

  local race = card(110, "Race til 60")
  race:SetPoint("TOPLEFT", ch, "BOTTOMLEFT", 0, -8)
  race:SetPoint("TOPRIGHT", ch, "BOTTOMRIGHT", 0, -8)
  race.rows = {}
  for i = 1, 3 do
    local r = CreateFrame("Frame", nil, race)
    r:SetHeight(24)
    r:SetPoint("TOPLEFT", 12, -30 - (i - 1) * 26)
    r:SetPoint("RIGHT", -12, 0)
    r.name = UI.Text(r, 12, "semi", C.text)
    r.name:SetPoint("TOPLEFT")
    r.lvl = UI.Text(r, 12, nil, C.muted)
    r.lvl:SetPoint("TOPRIGHT")
    r.track = r:CreateTexture(nil, "ARTWORK")
    r.track:SetTexture(ns.TEX .. "RoundedSmall")
    r.track:SetVertexColor(hex(C.active))
    r.track:SetHeight(5)
    r.track:SetPoint("BOTTOMLEFT") r.track:SetPoint("BOTTOMRIGHT")
    r.bar = r:CreateTexture(nil, "OVERLAY")
    r.bar:SetTexture(ns.TEX .. "RoundedSmall")
    r.bar:SetVertexColor(hex(C.accent))
    r.bar:SetHeight(5)
    r.bar:SetPoint("BOTTOMLEFT")
    race.rows[i] = r
  end

  local shame = card(76, "Skammens tavle")
  shame:SetPoint("TOPLEFT", race, "BOTTOMLEFT", 0, -8)
  shame:SetPoint("TOPRIGHT", race, "BOTTOMRIGHT", 0, -8)
  shame.big = UI.Text(shame, 24, "bold", C.text)
  shame.big:SetPoint("TOPLEFT", 12, -28)
  shame.who = UI.Text(shame, 12, nil, C.muted)
  shame.who:SetPoint("BOTTOMLEFT", shame.big, "BOTTOMRIGHT", 8, 3)
  shame.who:SetPoint("RIGHT", -10, 0)
  shame.last = UI.Text(shame, 11, nil, C.dim)
  shame.last:SetPoint("BOTTOMLEFT", 12, 10)
  shame.last:SetPoint("RIGHT", -10, 0)

  local firsts = card(10, "Først i gjengen")
  firsts:SetPoint("TOPLEFT", shame, "BOTTOMLEFT", 0, -8)
  firsts:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT")
  firsts.text = UI.Text(firsts, 12, nil, C.text2)
  firsts.text:SetPoint("TOPLEFT", 12, -30)
  firsts.text:SetPoint("RIGHT", -10, 0)
  firsts.text:SetWordWrap(true)
  firsts.text:SetJustifyV("TOP")
  firsts.text:SetSpacing(4)

  function tab:Refresh()
    local people = ns:SortedPeople()
    table.sort(people, function(a, b)
      local va, vb = value(a, sortKey), value(b, sortKey)
      if va ~= vb then return va > vb end
      return ns:PersonPlayed(a) > ns:PersonPlayed(b)
    end)
    list:SetData(people)
    for key, t in pairs(headerTexts) do
      t:SetTextColor(hex(key == sortKey and C.accent or C.dim))
    end
    headerTexts.online:SetText(mode == "week" and "ONLINE UKE" or "ONLINE")

    -- Utfordring
    local chal, leader, v = ns.Data:CurrentLeader()
    ch.main:SetText(chal.label)
    local wday = tonumber(date("%w")) -- 0 = søndag
    local daysLeft = (8 - wday) % 7
    if daysLeft == 0 then daysLeft = 7 end
    if leader then
      local lc = ns:PersonChar(leader) or {}
      ch.sub:SetText("Leder: " .. ns.Colorize(ns:PersonName(leader), ns.ClassHex(lc.class)) .. " – " .. chal.fmt(v) .. " · " .. daysLeft .. " d igjen")
    else
      ch.sub:SetText("Ingen poeng ennå · " .. daysLeft .. " d igjen")
    end

    -- Race til 60
    local byLevel = ns:SortedPeople()
    table.sort(byLevel, function(a, b) return ns:PersonMaxLevel(a) > ns:PersonMaxLevel(b) end)
    for i, r in ipairs(race.rows) do
      local p = byLevel[i]
      if p then
        local c = ns:PersonChar(p) or {}
        local lvl = ns:PersonMaxLevel(p)
        r.name:SetText(ns.Colorize(ns:PersonName(p), ns.ClassHex(c.class)))
        r.lvl:SetText(lvl .. " / 60")
        local w = r:GetWidth() > 0 and r:GetWidth() or (RIGHT_W - 24)
        r.bar:SetWidth(math.max(1, w * math.min(lvl, 60) / 60))
        r:Show()
      else
        r:Hide()
      end
    end

    -- Flest dødsfall
    local worst, wv = nil, 0
    for _, p in ipairs(people) do
      local d = mode == "week" and ns:WeekStat(p, "Deaths") or ns:TotalStat(p, "Deaths")
      if d > wv then worst, wv = p, d end
    end
    if worst then
      local wc = ns:PersonChar(worst) or {}
      shame.big:SetText(wv)
      shame.who:SetText("dødsfall · " .. ns.Colorize(ns:PersonName(worst), ns.ClassHex(wc.class)))
      shame.last:SetText(worst.deathZone and ("Sist: " .. worst.deathZone .. ", " .. ns.Ago(worst.deathAt)) or "")
    else
      shame.big:SetText("0")
      shame.who:SetText("dødsfall – imponerende")
      shame.last:SetText("")
    end

    -- Milepæler
    local lines = {}
    for _, key in ipairs({ "L10", "L20", "L30", "L40", "L50", "L60", "MOUNT" }) do
      local f = ns.db.firsts[key]
      if f then
        local p = ns:GetPerson(f.pid) or {}
        local c = (p.chars and p.chars[f.char]) or {}
        local label = key == "MOUNT" and "Mount" or ("Level " .. key:sub(2))
        lines[#lines + 1] = ns.Colorize(label, C.dim) .. "  " .. ns.Colorize(ns.ShortName(f.char), ns.ClassHex(c.class))
      end
    end
    firsts.text:SetText(#lines > 0 and table.concat(lines, "\n") or ns.Colorize("Ingen ennå – første til level 10?", C.dim))
  end
end)
