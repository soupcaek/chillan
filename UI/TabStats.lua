-- Chillan? – fanen "Stats": race til 60, level over tid, tabell og morsomme fakta
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("stats", "Stats", "Board", function(tab)
  local RIGHT_W = 214
  local page = "overview"
  local histMode = "milestones"
  local mode = "week"
  local sortKey = "level"

  local left = CreateFrame("Frame", nil, tab)
  left:SetPoint("TOPLEFT", 16, -14)
  left:SetPoint("BOTTOMRIGHT", -RIGHT_W - 30, 14)

  -- Underfaner
  local pageBtns = {}
  local PAGES = { { "overview", "Overview" }, { "graph", "Progress" }, { "titles", "Titles" }, { "history", "History" } }
  local pages = {}
  local function paintPages()
    for k, b in pairs(pageBtns) do
      local on = k == page
      b.panel:SetColors(on and C.active or nil, on and C.activeLine or C.inputLine)
      b.label:SetTextColor(hex(on and C.text or C.muted))
      b.style = { fill = on and C.active or nil, line = on and C.activeLine or C.inputLine, text = on and C.text or C.muted, hover = on and C.activeHover or C.card }
    end
    for k, f in pairs(pages) do f:SetShown(k == page) end
  end
  local prev
  for _, def in ipairs(PAGES) do
    local b = UI.Button(left, 10, 28, def[2], "ghost", function() page = def[1] paintPages() tab:Refresh() end)
    b:SetWidth(b.label:GetStringWidth() + 22)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", 0, 2) end
    prev = b
    pageBtns[def[1]] = b
  end

  local function newPage(key)
    local f = CreateFrame("Frame", nil, left)
    f:SetPoint("TOPLEFT", 0, -40)
    f:SetPoint("BOTTOMRIGHT", 0, 0)
    pages[key] = f
    return f
  end

  -------------------------------------------------------------------------
  -- 1) Race til 60
  -------------------------------------------------------------------------
  local medal = { C.gold, C.silver, C.bronze }
  local racePage = newPage("race")
  local function createRace(list)
    local row = CreateFrame("Button", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.rank = UI.Text(row, 13, "bold", C.dim)
    row.rank:SetPoint("LEFT", 12, 0)
    row.name = UI.Text(row, 13, "semi", C.text)
    row.name:SetPoint("TOPLEFT", 38, -7)
    row.name:SetWidth(170)
    row.sub = UI.Text(row, 11, nil, C.muted)
    row.sub:SetPoint("BOTTOMLEFT", 38, 7)
    row.sub:SetWidth(170)
    row.lvl = UI.Text(row, 15, "bold", C.text)
    row.lvl:SetPoint("RIGHT", -12, 0)
    row.track = row:CreateTexture(nil, "ARTWORK")
    row.track:SetTexture(ns.TEX .. "RoundedSmall")
    row.track:SetVertexColor(hex(C.active))
    row.track:SetHeight(8)
    row.track:SetPoint("LEFT", 214, 0)
    row.track:SetPoint("RIGHT", -48, 0)
    row.bar = row:CreateTexture(nil, "OVERLAY")
    row.bar:SetTexture(ns.TEX .. "RoundedSmall")
    row.bar:SetHeight(8)
    row.bar:SetPoint("LEFT", row.track, "LEFT")
    row:SetScript("OnEnter", function(self)
      self.panel:SetColors(C.cardHover, C.line)
      if self.item then ns.Overlays:ShowProfile(self, self.item.pid) end
    end)
    row:SetScript("OnLeave", function(self) self.panel:SetColors(C.card, C.line) ns.Overlays:HideProfile() end)
    return row
  end
  local function updateRace(row, p, idx)
    local c = ns:PersonChar(p) or {}
    local lvl = ns:PersonMaxLevel(p)
    row.rank:SetText(idx)
    row.rank:SetTextColor(hex(medal[idx] or C.dim))
    row.name:SetText(ns:PersonLabel(p))
    local played = ns:PersonPlayed(p)
    row.sub:SetText((played > 0 and ("/played " .. ns.Duration(played)) or "/played unknown") .. (p.pid == ns.pid and "  ·  you" or ""))
    row.lvl:SetText(lvl)
    row.bar:SetVertexColor(ns.ClassColor(c.class))
    local w = row.track:GetWidth()
    if not w or w <= 0 then w = 160 end
    row.bar:SetWidth(math.max(2, w * math.min(lvl, 60) / 60))
  end
  local raceList = UI.List(racePage, 42, 6, createRace, updateRace)
  raceList:SetAllPoints()
  raceList.emptyText = "No data yet."

  -------------------------------------------------------------------------
  -- 2) Level over tid (linjegraf)
  -------------------------------------------------------------------------
  local graphPage = newPage("graph")
  local graph = UI.Panel(graphPage, C.card, C.line, false)
  graph:SetPoint("TOPLEFT")
  graph:SetPoint("BOTTOMRIGHT", 0, 40)
  local plot = CreateFrame("Frame", nil, graph)
  plot:SetPoint("TOPLEFT", 36, -14)
  plot:SetPoint("BOTTOMRIGHT", -14, 26)
  local gridLines, gridLabels, lines, legend = {}, {}, {}, {}
  for i = 1, 7 do
    local g = plot:CreateTexture(nil, "BACKGROUND")
    g:SetColorTexture(hex(C.line))
    g:SetHeight(1)
    gridLines[i] = g
    local l = UI.Text(graph, 10, nil, C.dim)
    l:SetJustifyH("RIGHT")
    gridLabels[i] = l
  end
  local xStart = UI.Text(graph, 10, nil, C.dim)
  xStart:SetPoint("BOTTOMLEFT", plot, "BOTTOMLEFT", 0, -18)
  local xEnd = UI.Text(graph, 10, nil, C.dim)
  xEnd:SetPoint("BOTTOMRIGHT", plot, "BOTTOMRIGHT", 0, -18)
  xEnd:SetText("now")
  local graphEmpty = UI.Text(graph, 12, nil, C.muted)
  graphEmpty:SetPoint("CENTER")
  graphEmpty:SetWordWrap(true)
  graphEmpty:SetWidth(320)
  graphEmpty:SetJustifyH("CENTER")
  graphEmpty:SetText("The graph fills up as you ding. Level history is stored from version 0.2.")
  for i = 1, 8 do
    local lg = UI.Text(graphPage, 11, "semi", C.text)
    legend[i] = lg
  end

  local function getLine(i)
    local ln = lines[i]
    if not ln then
      ln = plot:CreateLine(nil, "ARTWORK")
      ln:SetThickness(2)
      lines[i] = ln
    end
    return ln
  end

  local function drawGraph()
    for _, ln in ipairs(lines) do ln:Hide() end
    for _, lg in ipairs(legend) do lg:Hide() end
    local people = ns:SortedPeople()
    table.sort(people, function(a, b) return ns:PersonMaxLevel(a) > ns:PersonMaxLevel(b) end)
    local series, tMin, lMin, lMax = {}, nil, 60, 1
    for _, p in ipairs(people) do
      local c = ns:PersonChar(p)
      -- bruk karakteren med høyest level
      for _, ch in pairs(p.chars) do if (ch.level or 0) > ((c and c.level) or 0) then c = ch end end
      if c and c.hist and #c.hist >= 2 and #series < 8 then
        series[#series + 1] = { p = p, c = c }
        for _, h in ipairs(c.hist) do
          if not tMin or h.t < tMin then tMin = h.t end
          if h.l < lMin then lMin = h.l end
          if h.l > lMax then lMax = h.l end
        end
      end
    end
    if #series == 0 then
      graphEmpty:Show()
      for i = 1, 7 do gridLines[i]:Hide() gridLabels[i]:Hide() end
      xStart:SetText("")
      return
    end
    graphEmpty:Hide()
    lMin = math.max(1, math.floor((lMin - 1) / 10) * 10)
    lMax = math.min(60, math.ceil(lMax / 10) * 10)
    if lMax <= lMin then lMax = lMin + 10 end
    local W, H = plot:GetWidth(), plot:GetHeight()
    if W <= 0 then W = 380 end
    if H <= 0 then H = 280 end
    local tMax = ns.Now()
    if tMax - tMin < 3600 then tMin = tMax - 3600 end
    xStart:SetText(date("%d.%m", tMin))
    -- rutenett for hvert 10. level
    local gi = 0
    for lv = lMin, lMax, 10 do
      gi = gi + 1
      if gi <= 7 then
        local y = (lv - lMin) / (lMax - lMin) * H
        gridLines[gi]:ClearAllPoints()
        gridLines[gi]:SetPoint("BOTTOMLEFT", plot, "BOTTOMLEFT", 0, y)
        gridLines[gi]:SetPoint("BOTTOMRIGHT", plot, "BOTTOMRIGHT", 0, y)
        gridLines[gi]:Show()
        gridLabels[gi]:ClearAllPoints()
        gridLabels[gi]:SetPoint("RIGHT", plot, "BOTTOMLEFT", -8, y)
        gridLabels[gi]:SetText(lv)
        gridLabels[gi]:Show()
      end
    end
    for i = gi + 1, 7 do gridLines[i]:Hide() gridLabels[i]:Hide() end
    local n = 0
    for si, s in ipairs(series) do
      local r, g, b = ns.ClassColor(s.c.class)
      local pts = {}
      for _, h in ipairs(s.c.hist) do pts[#pts + 1] = h end
      -- forleng linja til nå på dagens level
      pts[#pts + 1] = { t = tMax, l = pts[#pts].l }
      for i = 1, #pts - 1 do
        local a, bpt = pts[i], pts[i + 1]
        n = n + 1
        local ln = getLine(n)
        local x1 = (a.t - tMin) / (tMax - tMin) * W
        local y1 = (a.l - lMin) / (lMax - lMin) * H
        local x2 = (bpt.t - tMin) / (tMax - tMin) * W
        local y2 = (bpt.l - lMin) / (lMax - lMin) * H
        ln:SetStartPoint("BOTTOMLEFT", plot, x1, y1)
        ln:SetEndPoint("BOTTOMLEFT", plot, x2, y2)
        ln:SetColorTexture(r, g, b, 1)
        ln:Show()
      end
      local lg = legend[si]
      lg:ClearAllPoints()
      local col, row = (si - 1) % 4, math.floor((si - 1) / 4)
      lg:SetPoint("BOTTOMLEFT", graphPage, "BOTTOMLEFT", col * 112, 20 - row * 18)
      lg:SetText(ns.Colorize("— " .. (ns:PersonAlias(s.p) or ns:PersonFirst(s.p)), ns.ClassHex(s.c.class)))
      lg:Show()
    end
  end

  -------------------------------------------------------------------------
  -- 3) Tabell (sorterbar, uke/totalt)
  -------------------------------------------------------------------------
  local tablePage = newPage("overview")
  local COLS = {
    { key = "rank", label = "#", w = 24 },
    { key = "name", label = "Player", w = 0 },
    { key = "level", label = "Lvl", w = 34, tip = "Highest character level" },
    { key = "quests", label = "Quests", w = 48, tip = "Quests completed" },
    { key = "gold", label = "Gold", w = 50, tip = "Gold earned (looted, quest rewards, sales)" },
    { key = "kills", label = "PvP", w = 34, tip = "PvP kills (honorable kills)" },
    { key = "deaths", label = "Died", w = 34, tip = "Deaths" },
    { key = "points", label = "Pts", w = 40, tip = "Achievement points from the Trophies tab:\nBronze 5 · Silver 10 · Gold 25 · Legendary 50\n(always all-time, not just this week)" },
  }
  local seg = UI.Panel(tablePage, C.input, C.inputLine, true)
  seg:SetSize(170, 28)
  seg:SetPoint("TOPRIGHT", 0, 0)
  local segBtns = {}
  local function paintSeg()
    for k, b in pairs(segBtns) do
      local on = k == mode
      b.panel:SetColors(on and C.activeHover or nil, nil)
      b.label:SetTextColor(hex(on and C.text or C.muted))
      b.style = { fill = on and C.activeHover or nil, text = on and C.text or C.muted, hover = C.cardHover }
    end
  end
  for i, def in ipairs({ { "week", "This week" }, { "total", "Total" } }) do
    local b = UI.Button(seg, 82, 22, def[2], "nav", function() mode = def[1] paintSeg() tab:Refresh() end)
    b:SetPoint("LEFT", 3 + (i - 1) * 83, 0)
    segBtns[def[1]] = b
  end
  paintSeg()
  local sortHint = UI.Text(tablePage, 11, nil, C.dim)
  sortHint:SetPoint("LEFT", 0, 0)
  sortHint:SetPoint("TOP", seg, "TOP", 0, -8)
  sortHint:SetText("Click a column to sort")

  local function layoutCols(parent, cells)
    local rightX = -10
    for i = #COLS, 3, -1 do
      local col = COLS[i]
      cells[col.key]:ClearAllPoints()
      cells[col.key]:SetPoint("RIGHT", parent, "RIGHT", rightX, 0)
      cells[col.key]:SetWidth(col.w)
      cells[col.key]:SetJustifyH("RIGHT")
      rightX = rightX - col.w - 6
    end
    cells.rank:ClearAllPoints()
    cells.rank:SetPoint("LEFT", parent, "LEFT", 10, 0)
    cells.rank:SetWidth(COLS[1].w)
    cells.name:ClearAllPoints()
    cells.name:SetPoint("LEFT", parent, "LEFT", 40, 0)
    cells.name:SetPoint("RIGHT", parent, "RIGHT", rightX, 0)
  end
  local header = CreateFrame("Frame", nil, tablePage)
  header:SetPoint("TOPLEFT", 0, -38)
  header:SetPoint("TOPRIGHT", -6, -38)
  header:SetHeight(16)
  local headerTexts = {}
  for _, col in ipairs(COLS) do
    local t = UI.Text(header, 10, "semi", C.dim)
    t:SetText(col.label:upper())
    headerTexts[col.key] = t
    if col.key ~= "rank" and col.key ~= "name" then
      local hit = CreateFrame("Button", nil, header)
      hit:SetAllPoints(t)
      hit:SetScript("OnClick", function() sortKey = col.key tab:Refresh() end)
      hit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(col.tip or col.label)
        GameTooltip:AddLine("Click to sort", 0.6, 0.63, 0.66)
        GameTooltip:Show()
      end)
      hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
  end
  layoutCols(header, headerTexts)

  local function value(p, key)
    if key == "level" then return ns:PersonMaxLevel(p) end
    if key == "points" then return ns.Ach:Points(p.pid) end
    local map = { quests = "Quests", gold = "Gold", kills = "Kills", deaths = "Deaths" }
    local k = map[key]
    if not k then return 0 end
    return mode == "week" and ns:WeekStat(p, k) or ns:TotalStat(p, k)
  end

  local function createRow(list)
    local row = CreateFrame("Button", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.cells = {}
    row.cells.rank = UI.Text(row, 13, "bold", C.dim)
    row.cells.name = UI.Text(row, 13, "semi", C.text)
    for _, k in ipairs({ "level", "quests", "gold", "kills", "deaths", "points" }) do row.cells[k] = UI.Text(row, 12, nil, C.text2) end
    layoutCols(row, row.cells)
    -- race to 60: thin level bar under the name
    row.cells.name:ClearAllPoints()
    row.cells.name:SetPoint("TOPLEFT", row, "TOPLEFT", 40, -5)
    row.cells.name:SetPoint("RIGHT", row.cells.level, "LEFT", -8, 0)
    row.track = row:CreateTexture(nil, "ARTWORK")
    row.track:SetTexture(ns.TEX .. "RoundedSmall")
    row.track:SetVertexColor(hex(C.active))
    row.track:SetHeight(4)
    row.track:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 40, 7)
    row.track:SetWidth(120)
    row.bar = row:CreateTexture(nil, "OVERLAY")
    row.bar:SetTexture(ns.TEX .. "RoundedSmall")
    row.bar:SetHeight(4)
    row.bar:SetPoint("LEFT", row.track, "LEFT")
    row:SetScript("OnEnter", function(self)
      self.panel:SetColors(C.cardHover, C.line)
      if self.item then ns.Overlays:ShowProfile(self, self.item.pid) end
    end)
    row:SetScript("OnLeave", function(self) self.panel:SetColors(C.card, C.line) ns.Overlays:HideProfile() end)
    return row
  end
  local function updateRow(row, p, idx)
    local c = ns:PersonChar(p) or {}
    row.cells.rank:SetText(idx)
    row.cells.rank:SetTextColor(hex(medal[idx] or C.dim))
    row.cells.name:SetText(ns:ShortWho(p))   -- alias in class colour (full name on hover)
    row.cells.level:SetText(ns:PersonMaxLevel(p))
    row.cells.quests:SetText(math.floor(value(p, "quests")))
    row.cells.gold:SetText(math.floor(value(p, "gold") / 10000) .. "g")
    row.cells.kills:SetText(math.floor(value(p, "kills")))
    row.cells.deaths:SetText(math.floor(value(p, "deaths")))
    row.cells.points:SetText(ns.Ach:Points(p.pid))
    local lvl = ns:PersonMaxLevel(p) or 1
    local s3 = ns:PersonS3(p)
    local frac = (s3 and s3.xpMax and s3.xpMax > 0) and ((s3.xp or 0) / s3.xpMax) or 0
    row.bar:SetWidth(math.max(2, 120 * math.min(1, (lvl - 1 + frac) / 59)))
    row.bar:SetVertexColor(hex(ns.ClassHex(c.class)))
  end
  local tableList = UI.List(tablePage, 36, 5, createRow, updateRow)
  tableList:SetPoint("TOPLEFT", 0, -58)
  tableList:SetPoint("BOTTOMRIGHT", 6, 0)

  -------------------------------------------------------------------------
  -- 5) Titler denne uka
  -------------------------------------------------------------------------
  local titlesPage = newPage("titles")
  local function createTitle(list)
    local row = CreateFrame("Button", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.tile = UI.Panel(row, C.active, nil, false)
    row.tile:SetSize(30, 30)
    row.tile:SetPoint("LEFT", 8, 0)
    row.icon = UI.Icon(row.tile, "Crown", 16, C.gold)
    row.icon:SetPoint("CENTER")
    row.name = UI.Text(row, 13, "semi", C.text)
    row.name:SetPoint("TOPLEFT", 48, -7)
    row.name:SetPoint("RIGHT", -170, 0)
    row.desc = UI.Text(row, 11, nil, C.muted)
    row.desc:SetPoint("BOTTOMLEFT", 48, 7)
    row.desc:SetPoint("RIGHT", -170, 0)
    row.who = UI.Text(row, 13, "semi", C.text)
    row.who:SetPoint("TOPRIGHT", -12, -7)
    row.who:SetJustifyH("RIGHT")
    row.who:SetWidth(156)
    row.val = UI.Text(row, 11, nil, C.muted)
    row.val:SetPoint("BOTTOMRIGHT", -12, 7)
    row.val:SetJustifyH("RIGHT")
    row.val:SetWidth(156)
    row:SetScript("OnEnter", function(self)
      self.panel:SetColors(C.cardHover, C.line)
      if self.item then ns.Titles:Tooltip(self, self.item.def.key) end
    end)
    row:SetScript("OnLeave", function(self) self.panel:SetColors(C.card, C.line) GameTooltip:Hide() end)
    return row
  end
  local function updateTitle(row, e)
    local def = e.def
    row.icon:SetTexture(ns.TEX .. "Icon" .. def.icon)
    row.icon:SetVertexColor(hex(def.color))
    row.name:SetText(def.name)
    row.name:SetTextColor(hex(e.holder and C.gold or C.dim))
    row.desc:SetText(def.desc)
    if e.holder then
      local p = ns:GetPerson(e.holder.pid) or {}
      row.who:SetText(ns:ShortWho(p))
      local lead = e.holder.value - (e.holder.second or 0)
      row.val:SetText(ns.Titles:Format(def, e.holder.value) .. (lead > 0 and e.holder.second and e.holder.second > 0 and (" · leads by " .. ns.Titles:Format(def, lead)) or ""))
      row:SetAlpha(1)
    else
      row.who:SetText(ns.Colorize("ledig", C.dim))
      row.val:SetText("")
      row:SetAlpha(0.6)
    end
  end
  local titleList = UI.List(titlesPage, 44, 6, createTitle, updateTitle)
  titleList:SetAllPoints()

  -------------------------------------------------------------------------
  -- 4) Morsomme fakta
  -------------------------------------------------------------------------
  -------------------------------------------------------------------------
  -- History: milestones, dungeon records and fun facts (switch at the top)
  -------------------------------------------------------------------------
  local historyPage = newPage("history")
  local hseg = UI.Panel(historyPage, C.input, C.inputLine, true)
  hseg:SetSize(4 * 96 + 6, 28)
  hseg:SetPoint("TOPLEFT", 0, 0)
  local hsegBtns, histFrames = {}, {}
  local function paintHist()
    for k, b in pairs(hsegBtns) do
      local on = k == histMode
      b.panel:SetColors(on and C.activeHover or nil, nil)
      b.label:SetTextColor(hex(on and C.text or C.muted))
      b.style = { fill = on and C.activeHover or nil, text = on and C.text or C.muted, hover = C.cardHover }
    end
    for k, f in pairs(histFrames) do f:SetShown(k == histMode) end
  end
  for i, def in ipairs({ { "feed", "Feed" }, { "milestones", "Milestones" }, { "dungeons", "Dungeons" }, { "facts", "Fun facts" } }) do
    local b = UI.Button(hseg, 94, 22, def[2], "nav", function() histMode = def[1] paintHist() tab:Refresh() end)
    b:SetPoint("LEFT", 3 + (i - 1) * 96, 0)
    hsegBtns[def[1]] = b
  end
  local function histFrame(key)
    local f = CreateFrame("Frame", nil, historyPage)
    f:SetPoint("TOPLEFT", 0, -38)
    f:SetPoint("BOTTOMRIGHT", 0, 0)
    histFrames[key] = f
    return f
  end

  -- milestones (the gang's chronicle)
  local msFrame = histFrame("milestones")
  local function createMs(list)
    local row = CreateFrame("Button", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.date = UI.Text(row, 11, "semi", C.dim)
    row.date:SetPoint("LEFT", 12, 0)
    row.date:SetWidth(40)
    row.tile = UI.Panel(row, C.active, nil, false)
    row.tile:SetSize(26, 26)
    row.tile:SetPoint("LEFT", 54, 0)
    row.icon = UI.Icon(row.tile, "Star", 14, C.gold)
    row.icon:SetPoint("CENTER")
    row.text = UI.Text(row, 12, nil, C.text)
    row.text:SetPoint("LEFT", row.tile, "RIGHT", 10, 0)
    row.text:SetPoint("RIGHT", -10, 0)
    row:SetScript("OnEnter", function(self)
      self.panel:SetColors(C.cardHover, C.line)
      if self.item and self.item.pid then ns.Overlays:ShowProfile(self, self.item.pid) end
    end)
    row:SetScript("OnLeave", function(self) self.panel:SetColors(C.card, C.line) ns.Overlays:HideProfile() end)
    return row
  end
  local function updateMs(row, e)
    row.date:SetText(e.t and date("%d.%m", e.t) or "")
    row.icon:SetTexture(ns.TEX .. "Icon" .. (e.icon or "Star"))
    row.icon:SetVertexColor(hex(e.color or C.gold))
    local p = ns:GetPerson(e.pid) or {}
    row.text:SetText(ns:ShortWho(p, e.char) .. " " .. ns.Colorize(e.text, C.text2))
  end
  local msList = UI.List(msFrame, 38, 5, createMs, updateMs)
  msList:SetAllPoints()
  msList.emptyText = "The chronicle fills itself: first to level 10, first mount, first epic, first through a dungeon and gold achievements."

  -- dungeon records
  local dgFrame = histFrame("dungeons")
  local function createRec(l)
    local row = CreateFrame("Button", nil, l)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.icon = UI.Icon(row, "Shield", 15, "8FB8E8")
    row.icon:SetPoint("LEFT", 12, 0)
    row.name = UI.Text(row, 13, "semi", C.text)
    row.name:SetPoint("TOPLEFT", 36, -8)
    row.name:SetPoint("RIGHT", -90, 0)
    row.time = UI.Text(row, 14, "bold", C.text)
    row.time:SetPoint("RIGHT", -12, 0)
    row.time:SetJustifyH("RIGHT")
    row.who = UI.Text(row, 11, nil, C.muted)
    row.who:SetPoint("BOTTOMLEFT", 36, 8)
    row.who:SetPoint("RIGHT", -90, 0)
    return row
  end
  local function updateRec(row, r)
    row.name:SetText(r.name)
    row.time:SetText(ns.Duration(r.dur))
    local names = {}
    for _, p in ipairs(ns.Extras:RunMembers(r.item)) do names[#names + 1] = ns:ShortWho(p) end
    if #names == 0 then names[1] = ns:ShortWho(ns:GetPerson(r.item.pid) or {}, r.item.char) end
    row.who:SetText(table.concat(names, ns.Colorize(", ", C.dim)) .. ns.Colorize("  ·  " .. date("%d.%m", r.item.t), C.dim))
  end
  local dgList = UI.List(dgFrame, 44, 5, createRec, updateRec)
  dgList:SetAllPoints()
  dgList.emptyText = "No finished dungeons yet. Runs are logged automatically (time, deaths and bosses) – the fastest run per dungeon shows here."

  -- the gang feed (moved here from the Chat tab): every ding, drop, death and SOS, newest at the bottom
  local feedPage = histFrame("feed")
  local feedBox = UI.Panel(feedPage, C.card, C.line, false)
  feedBox:SetAllPoints()
  local feedMsgs = UI.MessageFrame(feedBox, 12)
  feedMsgs:SetPoint("TOPLEFT", 14, -12)
  feedMsgs:SetPoint("BOTTOMRIGHT", -14, 12)
  feedMsgs:SetSpacing(6)
  local function drawFeed()
    feedMsgs:Clear()
    local feed = ns.db.feed or {}
    for i = math.max(1, #feed - 80), #feed do feedMsgs:AddMessage(ns.FeedLine(feed[i], true)) end
    if #feed == 0 then feedMsgs:AddMessage(ns.Colorize("Dings, drops, deaths and SOS calls show up here.", C.dim)) end
  end

  local factsPage = histFrame("facts")
  local factsBox = UI.Panel(factsPage, C.card, C.line, false)
  factsBox:SetAllPoints()
  local facts = UI.MessageFrame(factsBox, 13)
  facts:SetPoint("TOPLEFT", 14, -12)
  facts:SetPoint("BOTTOMRIGHT", -14, 12)
  facts:SetSpacing(10)
  facts:SetInsertMode("TOP")

  local function nameOf(p)
    local c = ns:PersonChar(p) or {}
    return ns:PersonLabel(p)
  end
  local function fact(icon, color, label, text)
    facts:AddMessage(UI.InlineIcon(icon, color, 14) .. "  " .. ns.Colorize(label, C.dim) .. "   " .. text)
  end

  local function drawFacts()
    facts:Clear()
    local people = ns:SortedPeople()
    local lines = {}
    -- Raskeste ding
    local best
    for _, p in ipairs(people) do
      for _, c in pairs(p.chars) do
        local hst = c.hist or {}
        for i = 2, #hst do
          local dt = hst[i].t - hst[i - 1].t
          if hst[i].l == hst[i - 1].l + 1 and dt > 0 and (not best or dt < best.dt) then
            best = { p = p, dt = dt, l = hst[i].l }
          end
        end
      end
    end
    local function maxBy(fn)
      local bp, bv = nil, 0
      for _, p in ipairs(people) do
        local v = fn(p) or 0
        if v > bv then bp, bv = p, v end
      end
      return bp, bv
    end
    local entries = {}
    if best then entries[#entries + 1] = { "Up", C.green, "Fastest ding", nameOf(best.p) .. " to level " .. best.l .. " in " .. ns.Duration(best.dt) } end
    local lp, lv = maxBy(function(p) return (p.stats or {}).tLongest end)
    if lp then entries[#entries + 1] = { "Clock", C.accent, "Longest session", nameOf(lp) .. " – " .. ns.Duration(lv) } end
    local pp, pv = maxBy(function(p) return ns:PersonPlayed(p) end)
    if pp then entries[#entries + 1] = { "Clock", C.purple, "Most /played", nameOf(pp) .. " – " .. ns.Duration(pv) } end
    -- Farligste sone (flest dødsfall i feeden)
    local zones = {}
    for _, it in ipairs(ns.db.feed) do
      if it.kind == "DEAD" and it.a then
        local z = tostring(it.a):match(",%s*(.+)$") or tostring(it.a)
        zones[z] = (zones[z] or 0) + 1
      end
    end
    local bz, bzv = nil, 0
    for z, v in pairs(zones) do if v > bzv then bz, bzv = z, v end end
    if bz then entries[#entries + 1] = { "Skull", C.red, "Deadliest zone", bz .. " – " .. bzv .. " deaths" } end
    local dp, dv = maxBy(function(p) return ns:TotalStat(p, "Deaths") end)
    if dp then entries[#entries + 1] = { "Skull", C.dim, "Most deaths", nameOf(dp) .. " – " .. math.floor(dv) } end
    local gp, gv = maxBy(function(p) return ns:TotalStat(p, "Gold") end)
    if gp then entries[#entries + 1] = { "Star", C.gold, "Most gold earned", nameOf(gp) .. " – " .. ns.Money(gv) } end
    local qp, qv = maxBy(function(p) return ns:TotalStat(p, "Quests") end)
    if qp then entries[#entries + 1] = { "Check", C.green, "Most quests", nameOf(qp) .. " – " .. math.floor(qv) } end
    local kp, kv = maxBy(function(p) return ns:TotalStat(p, "Kills") end)
    if kp then entries[#entries + 1] = { "Target", C.red, "Most PvP kills", nameOf(kp) .. " – " .. math.floor(kv) } end
    -- Mest gratulert
    local grats = {}
    for _, it in ipairs(ns.db.feed) do
      if it.reacts then grats[it.pid] = (grats[it.pid] or 0) + #it.reacts end
    end
    local gpid, gcount = nil, 0
    for pid, v in pairs(grats) do if v > gcount then gpid, gcount = pid, v end end
    if gpid then entries[#entries + 1] = { "Star", C.purple, "Most congratulated", nameOf(ns:GetPerson(gpid) or {}) .. " – " .. gcount .. " reactions" } end
    -- Mest pratsom
    local talk = {}
    for _, it in ipairs(ns.db.chat) do talk[it.pid] = (talk[it.pid] or 0) + 1 end
    local tpid, tcount = nil, 0
    for pid, v in pairs(talk) do if v > tcount then tpid, tcount = pid, v end end
    if tpid then entries[#entries + 1] = { "Chat", C.accent, "Most talkative", nameOf(ns:GetPerson(tpid) or {}) .. " – " .. tcount .. " messages" } end

    if #entries == 0 then
      facts:AddMessage(ns.Colorize("No facts yet – play a bit and they show up here.", C.dim))
      return
    end
    for i = #entries, 1, -1 do fact(entries[i][1], entries[i][2], entries[i][3], entries[i][4]) end
  end

  -------------------------------------------------------------------------
  -- Høyre kolonne: utfordring, skammens tavle, først i gjengen
  -------------------------------------------------------------------------
  local right = CreateFrame("Frame", nil, tab)
  right:SetPoint("TOPRIGHT", -16, -14)
  right:SetPoint("BOTTOMRIGHT", -16, 14)
  right:SetWidth(RIGHT_W)

  local function card(height, titleText)
    local cd = UI.Panel(right, C.card, C.line, false)
    cd:SetHeight(height)
    cd.title = UI.Text(cd, 10, "semi", C.muted)
    cd.title:SetPoint("TOPLEFT", 12, -12)
    cd.title:SetText(titleText:upper())
    return cd
  end

  local ch = card(92, "Weekly challenge")
  ch:SetPoint("TOPLEFT") ch:SetPoint("TOPRIGHT")
  ch.main = UI.Text(ch, 14, "semi", C.text)
  ch.main:SetPoint("TOPLEFT", 12, -30)
  ch.sub = UI.Text(ch, 12, nil, C.text2)
  ch.sub:SetPoint("TOPLEFT", 12, -50)
  ch.sub:SetPoint("RIGHT", -10, 0)
  ch.last = UI.Text(ch, 11, nil, C.muted)
  ch.last:SetPoint("TOPLEFT", 12, -70)
  ch.last:SetPoint("RIGHT", -10, 0)

  local shame = card(80, "Wall of shame (week)")
  shame:SetPoint("TOPLEFT", ch, "BOTTOMLEFT", 0, -8)
  shame:SetPoint("TOPRIGHT", ch, "BOTTOMRIGHT", 0, -8)
  shame.big = UI.Text(shame, 24, "bold", C.text)
  shame.big:SetPoint("TOPLEFT", 12, -28)
  shame.who = UI.Text(shame, 12, nil, C.text2)
  shame.who:SetPoint("BOTTOMLEFT", shame.big, "BOTTOMRIGHT", 8, 3)
  shame.who:SetPoint("RIGHT", -10, 0)
  shame.last = UI.Text(shame, 11, nil, C.muted)
  shame.last:SetPoint("BOTTOMLEFT", 12, 10)
  shame.last:SetPoint("RIGHT", -10, 0)

  -------------------------------------------------------------------------
  -- Two rotating "spotlight" cards under the challenge and the wall of shame:
  -- a new fun fact every 20 s (hover pauses, click shows the next one)
  -------------------------------------------------------------------------
  local spots = {}
  local spotHolder = CreateFrame("Frame", nil, right)
  spotHolder:SetPoint("TOPLEFT", shame, "BOTTOMLEFT", 0, -8)
  spotHolder:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT")
  for i = 1, 2 do
    local cd = UI.Panel(spotHolder, C.card, C.line, false)
    local btn = CreateFrame("Button", nil, cd)
    btn:SetAllPoints()
    cd.title = UI.Text(cd, 10, "semi", C.muted)
    cd.title:SetPoint("TOPLEFT", 12, -12)
    cd.title:SetPoint("RIGHT", -34, 0)
    cd.page = UI.Text(cd, 10, nil, C.dim)
    cd.page:SetPoint("TOPRIGHT", -10, -12)
    cd.page:SetJustifyH("RIGHT")
    cd.big = UI.Text(cd, 15, "semi", C.text)
    cd.big:SetPoint("TOPLEFT", 12, -30)
    cd.big:SetPoint("RIGHT", -10, 0)
    cd.big:SetWordWrap(false)
    cd.sub = UI.Text(cd, 11, nil, C.text2)
    cd.sub:SetPoint("TOPLEFT", cd.big, "BOTTOMLEFT", 0, -6)
    cd.sub:SetPoint("RIGHT", -10, 0)
    cd.sub:SetWordWrap(true)
    cd.sub:SetJustifyV("TOP")
    cd.sub:SetSpacing(4)
    btn:SetScript("OnEnter", function()
      cd.hover = true
      cd:SetColors(C.cardHover, C.line)
      local f = cd.fact
      if f and f.item then
        GameTooltip:SetOwner(cd, "ANCHOR_LEFT")
        GameTooltip:SetHyperlink("item:" .. f.item)
        GameTooltip:Show()
      end
    end)
    btn:SetScript("OnLeave", function() cd.hover = false cd:SetColors(C.card, C.line) GameTooltip:Hide() end)
    btn:SetScript("OnClick", function() tab:NextSpot(i) end)
    spots[i] = cd
  end
  spotHolder:SetScript("OnSizeChanged", function(self, w, h)
    local each = (h - 8) / 2
    for i, cd in ipairs(spots) do
      cd:ClearAllPoints()
      cd:SetPoint("TOPLEFT", 0, -(i - 1) * (each + 8))
      cd:SetSize(w, each)
    end
  end)

  function tab:Refresh()
    local people = ns:SortedPeople()
    if page == "race" then
      table.sort(people, function(a, b)
        local la, lb = ns:PersonMaxLevel(a), ns:PersonMaxLevel(b)
        if la ~= lb then return la > lb end
        return ns:PersonPlayed(a) < ns:PersonPlayed(b)
      end)
      raceList:SetData(people)
    elseif page == "graph" then
      drawGraph()
    elseif page == "overview" then
      table.sort(people, function(a, b)
        local va, vb = value(a, sortKey), value(b, sortKey)
        if va ~= vb then return va > vb end
        return ns:PersonMaxLevel(a) > ns:PersonMaxLevel(b)
      end)
      tableList:SetData(people)
      for key, t in pairs(headerTexts) do t:SetTextColor(hex(key == sortKey and C.accent or C.dim)) end
    elseif page == "history" then
      paintHist()
      if histMode == "feed" then drawFeed()
      elseif histMode == "milestones" then msList:SetData(ns.Extras:Chronicle())
      elseif histMode == "dungeons" then dgList:SetData(ns.Extras:DungeonRecords())
      else drawFacts() end
    elseif page == "titles" then
      local cur = ns.Titles:Current()
      local data = {}
      for _, def in ipairs(ns.Titles.DEFS) do data[#data + 1] = { def = def, holder = cur[def.key] } end
      titleList:SetData(data)
    end

    -- Utfordring
    local chal, leader, v = ns.Data:CurrentLeader()
    ch.main:SetText(chal.label)
    local wday = tonumber(date("%w"))
    local daysLeft = (8 - wday) % 7
    if daysLeft == 0 then daysLeft = 7 end
    if leader then
      local lc = ns:PersonChar(leader) or {}
      ch.sub:SetText("Leader: " .. ns:ShortWho(leader) .. " – " .. chal.fmt(v))
    else
      ch.sub:SetText("No points yet")
    end
    local pch, pbest, pv = ns.Data:LastWeekWinner()
    if pbest then
      ch.last:SetText(daysLeft .. " d left · last week: " .. ns:PersonFirst(pbest) .. " (" .. pch.fmt(pv) .. ")")
    else
      ch.last:SetText(daysLeft .. " d left")
    end

    -- Flest dødsfall denne uka
    local worst, wv = nil, 0
    for _, p in ipairs(people) do
      local d = ns:WeekStat(p, "Deaths")
      if d > wv then worst, wv = p, d end
    end
    if worst then
      local wc = ns:PersonChar(worst) or {}
      shame.big:SetText(math.floor(wv))
      shame.who:SetText("deaths · " .. ns:ShortWho(worst))
      shame.last:SetText(worst.deathZone and ("Last: " .. worst.deathZone .. ", " .. ns.Ago(worst.deathAt)) or "")
    else
      shame.big:SetText("0")
      shame.who:SetText("deaths – impressive")
      shame.last:SetText("")
    end

    tab:BuildSpots()
    tab:ShowSpots()
  end

  -------------------------------------------------------------------------
  -- spotlight facts (each returns nil when there's nothing to show yet)
  -------------------------------------------------------------------------
  local WEEK = 7 * 86400
  local function shortNum(n)
    n = n or 0
    if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
    if n >= 1e4 then return string.format("%dk", math.floor(n / 1000)) end
    return tostring(math.floor(n))
  end
  local function recent(p) return (ns.Now() - (p.lastSeen or 0)) < 14 * 86400 or p == ns.db.people[ns.pid] end
  local function people() local out = {} for _, p in ipairs(ns:SortedPeople()) do if recent(p) then out[#out + 1] = p end end return out end

  local FACTS = {
    -- First in the gang (now with more milestones)
    function()
      local lines = {}
      local function add(label, f)
        if not f then return end
        local p = ns:GetPerson(f.pid) or {}
        lines[#lines + 1] = ns.Colorize(label, C.muted) .. "  " .. ns:ShortWho(p, f.char)
      end
      for _, lv in ipairs({ 60, 50, 40, 30, 20, 10 }) do add("Level " .. lv, ns.db.firsts["L" .. lv]) end
      add("Mount", ns.db.firsts.MOUNT)
      add("Epic", ns.db.firsts.EPIC)
      local dgs = {}
      for key, f in pairs(ns.db.firsts) do if key:sub(1, 3) == "DG:" then dgs[#dgs + 1] = { key:sub(4), f } end end
      table.sort(dgs, function(a, b) return a[2].t > b[2].t end)
      for i = 1, math.min(2, #dgs) do add(dgs[i][1], dgs[i][2]) end
      if #lines == 0 then return nil end
      return { title = "First in the gang", big = nil, sub = table.concat(lines, "\n", 1, math.min(#lines, 5)) }
    end,
    -- Level race: the two closest friends
    function()
      local list = {}
      for _, p in ipairs(people()) do
        local s3 = ns:PersonS3(p) or {}
        local lvl = ns:PersonMaxLevel(p)
        local frac = (s3.xp and s3.xpMax and s3.xpMax > 0) and (s3.xp / s3.xpMax) or 0
        if lvl and lvl > 0 then list[#list + 1] = { p = p, v = lvl + frac, lvl = lvl, frac = frac } end
      end
      table.sort(list, function(a, b) return a.v > b.v end)
      local best
      for i = 1, #list - 1 do
        local d = list[i].v - list[i + 1].v
        if not best or d < best.d then best = { a = list[i], b = list[i + 1], d = d } end
      end
      if not best then return nil end
      local function fmt(x) return x.lvl .. " · " .. math.floor(x.frac * 100) .. " %" end
      return { title = "Level race", big = ns:ShortWho(best.a.p) .. ns.Colorize("  vs  ", C.dim) .. ns:ShortWho(best.b.p),
        sub = fmt(best.a) .. "  vs  " .. fmt(best.b) .. "\n" .. (best.d >= 1 and string.format("%.1f levels apart", best.d) or ("Only " .. math.max(1, math.floor(best.d * 100 + 0.5)) .. " % of a level apart")) }
    end,
    -- Next ding: who levels next at their current pace
    function()
      local best
      for _, p in ipairs(people()) do
        local s3 = ns:PersonS3(p) or {}
        if ns:IsOnline(p) and s3.sessXP and s3.sessSec and s3.sessSec > 600 and s3.sessXP > 0 and s3.xp and s3.xpMax then
          local xph = s3.sessXP / s3.sessSec * 3600
          local eta = (s3.xpMax - s3.xp) / xph * 3600
          if not best or eta < best.eta then best = { p = p, eta = eta, xph = xph } end
        end
      end
      if not best then return nil end
      local lvl = ns:PersonMaxLevel(best.p)
      return { title = "Next ding", big = ns:ShortWho(best.p) .. ns.Colorize("  in ~" .. ns.Duration(best.eta), C.text2),
        sub = "Level " .. lvl .. " to " .. (lvl + 1) .. "\n" .. shortNum(best.xph) .. " XP/h this session" }
    end,
    -- Loot of the week
    function()
      local best
      for _, it in ipairs(ns.db.feed or {}) do
        if it.kind == "LOOT" and (ns.Now() - (it.t or 0)) < WEEK then
          local q = tonumber(it.b) or 0
          if not best or q > best.q or (q == best.q and it.t > best.it.t) then best = { it = it, q = q } end
        end
      end
      if not best then return nil end
      local id = tonumber(best.it.a)
      local name = id and ((C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(id)) or (GetItemInfo and GetItemInfo(id)))
      local hexq = (ns.QUALITY_HEX and ns.QUALITY_HEX[best.q]) or C.text
      local p = ns:GetPerson(best.it.pid) or {}
      return { title = "Loot of the week", item = id, big = ns.Colorize("[" .. (name or "item") .. "]", hexq),
        sub = "Looted by " .. ns:ShortWho(p) .. " · " .. ns.Ago(best.it.t) }
    end,
    -- Deadliest zone this week
    function()
      local zones, who = {}, {}
      for _, it in ipairs(ns.db.feed or {}) do
        if it.kind == "DEAD" and it.a and it.a ~= "" and (ns.Now() - (it.t or 0)) < WEEK then
          zones[it.a] = (zones[it.a] or 0) + 1
          who[it.a] = who[it.a] or {}
          who[it.a][it.pid] = (who[it.a][it.pid] or 0) + 1
        end
      end
      local z, n = nil, 0
      for k, v in pairs(zones) do if v > n then z, n = k, v end end
      if not z then return nil end
      local wp, wn = nil, 0
      for pid, v in pairs(who[z]) do if v > wn then wp, wn = pid, v end end
      return { title = "Deadliest zone", big = z,
        sub = n .. " death" .. (n == 1 and "" or "s") .. " this week" .. (wp and ("\nMost: " .. ns:ShortWho(ns:GetPerson(wp) or {}) .. " (" .. wn .. ")") or "") }
    end,
    -- Enemy log: the newest tagged Alliance player
    function()
      local e
      for _, x in pairs(ns.db.enemies or {}) do if not e or (x.t or 0) > (e.t or 0) then e = x end end
      if not e then return nil end
      local by = e.by and ns:GetPerson(e.by)
      return { title = "Enemy of the week", big = ns.Colorize(e.name, C.red),
        sub = ((e.note and e.note ~= "") and ("“" .. e.note .. "”\n") or "") .. "Tagged " .. ns.Ago(e.t) .. (by and (" by " .. ns:ShortWho(by)) or "") }
    end,
    -- Hot streak: most days in a row
    function()
      local bp, bv = nil, 0
      for _, p in ipairs(people()) do
        local s3 = ns:PersonS3(p) or {}
        if (s3.streak or 0) > bv then bp, bv = p, s3.streak end
      end
      if not bp or bv < 2 then return nil end
      return { title = "Hot streak", big = bv .. " days in a row", sub = ns:ShortWho(bp) .. " hasn't missed a day" }
    end,
    -- The gang this week, all together
    function()
      local xp, q, gold, lv = 0, 0, 0, 0
      for _, p in ipairs(people()) do
        local s3 = ns:PersonS3(p) or {}
        if p == ns.db.people[ns.pid] or s3.wk == ns.WeekKey() then xp = xp + (s3.wXP or 0) end
        q = q + ns:WeekStat(p, "Quests")
        gold = gold + ns:WeekStat(p, "Gold")
        lv = lv + ns:WeekStat(p, "Levels")
      end
      if xp == 0 and q == 0 then return nil end
      return { title = "The gang this week", big = shortNum(xp) .. " XP",
        sub = math.floor(q) .. " quests · " .. ns.Money(gold) .. "\n" .. math.floor(lv) .. " levels together" }
    end,
    -- Dungeon records
    function()
      local recs = ns.Extras:DungeonRecords()
      if #recs == 0 then return nil end
      table.sort(recs, function(a, b) return (a.item.t or 0) > (b.item.t or 0) end)
      local lines = {}
      for i = 1, math.min(3, #recs) do
        lines[#lines + 1] = recs[i].name .. ns.Colorize("  " .. ns.Duration(recs[i].dur), C.accent)
      end
      return { title = "Dungeon records", sub = table.concat(lines, "\n") }
    end,
  }

  local spotFacts, spotIdx = {}, { 1, 2 }
  function tab:BuildSpots()
    spotFacts = {}
    for _, fn in ipairs(FACTS) do
      local ok, f = pcall(fn)
      if ok and f then spotFacts[#spotFacts + 1] = f end
    end
  end

  local function paint(i)
    local cd = spots[i]
    local n = #spotFacts
    if n == 0 then
      cd.title:SetText(i == 1 and "SPOTLIGHT" or "")
      cd.big:SetText(i == 1 and ns.Colorize("Play a bit – fun facts show up here", C.muted) or "")
      cd.sub:SetText("") cd.page:SetText("") cd.fact = nil
      return
    end
    local f = spotFacts[((spotIdx[i] - 1) % n) + 1]
    cd.fact = f
    cd.title:SetText((f.title or ""):upper())
    cd.big:SetText(f.big or "")
    cd.big:SetShown(f.big ~= nil)
    cd.sub:ClearAllPoints()
    if f.big then cd.sub:SetPoint("TOPLEFT", cd.big, "BOTTOMLEFT", 0, -6) else cd.sub:SetPoint("TOPLEFT", 12, -30) end
    cd.sub:SetPoint("RIGHT", -10, 0)
    cd.sub:SetText(f.sub or "")
    cd.page:SetText((((spotIdx[i] - 1) % n) + 1) .. "/" .. n)
  end

  function tab:ShowSpots()
    -- the two cards never show the same fact
    if #spotFacts >= 2 and ((spotIdx[1] - 1) % #spotFacts) == ((spotIdx[2] - 1) % #spotFacts) then spotIdx[2] = spotIdx[2] + 1 end
    paint(1) paint(2)
  end

  function tab:NextSpot(i)
    local n = #spotFacts
    if n == 0 then return end
    spotIdx[i] = spotIdx[i] + 1
    local other = i == 1 and 2 or 1
    if n >= 2 and ((spotIdx[i] - 1) % n) == ((spotIdx[other] - 1) % n) then spotIdx[i] = spotIdx[i] + 1 end
    paint(i)
  end

  -- rotate every 20 s while the Stats tab is open (a card you're hovering waits)
  C_Timer.NewTicker(20, function()
    if not tab:IsVisible() then return end
    tab:BuildSpots()
    for i = 1, 2 do if not spots[i].hover then spotIdx[i] = spotIdx[i] + 2 end end
    tab:ShowSpots()
  end)

  function tab:SetPage(k, h)
    page = k
    if h then histMode = h end
    paintPages()
    self:Refresh()
  end

  paintPages()
end)
