-- Chillan? – fanen "Statistikk": race til 60, level over tid, tabell og morsomme fakta
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("stats", "Statistikk", "Board", function(tab)
  local RIGHT_W = 214
  local page = "race"
  local mode = "week"
  local sortKey = "level"

  local left = CreateFrame("Frame", nil, tab)
  left:SetPoint("TOPLEFT", 16, -14)
  left:SetPoint("BOTTOMRIGHT", -RIGHT_W - 30, 14)

  -- Underfaner
  local pageBtns = {}
  local PAGES = { { "race", "Race til 60" }, { "graph", "Level over tid" }, { "table", "Tabell" }, { "facts", "Fakta" } }
  local pages = {}
  local function paintPages()
    for k, b in pairs(pageBtns) do
      local on = k == page
      b.panel:SetColors(on and C.active or nil, on and C.activeLine or C.inputLine)
      b.label:SetTextColor(hex(on and C.text or C.muted))
      b.style = { fill = on and C.active or nil, line = on and C.activeLine or C.inputLine, text = on and C.text or C.muted, hover = on and "33383E" or C.card }
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
    row.name:SetText(ns.Colorize(ns:PersonName(p), ns.ClassHex(c.class)))
    local played = ns:PersonPlayed(p)
    row.sub:SetText((played > 0 and ("/played " .. ns.Duration(played)) or "/played ukjent") .. (p.pid == ns.pid and "  ·  deg" or ""))
    row.lvl:SetText(lvl)
    row.bar:SetVertexColor(ns.ClassColor(c.class))
    local w = row.track:GetWidth()
    if not w or w <= 0 then w = 160 end
    row.bar:SetWidth(math.max(2, w * math.min(lvl, 60) / 60))
  end
  local raceList = UI.List(racePage, 42, 6, createRace, updateRace)
  raceList:SetAllPoints()
  raceList.emptyText = "Ingen data ennå."

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
  xEnd:SetText("nå")
  local graphEmpty = UI.Text(graph, 12, nil, C.muted)
  graphEmpty:SetPoint("CENTER")
  graphEmpty:SetWordWrap(true)
  graphEmpty:SetWidth(320)
  graphEmpty:SetJustifyH("CENTER")
  graphEmpty:SetText("Grafen fylles etter hvert som dere dinger. Levelhistorikk lagres fra versjon 0.2.")
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
      lg:SetText(ns.Colorize("— " .. ns:PersonFirst(s.p), ns.ClassHex(s.c.class)))
      lg:Show()
    end
  end

  -------------------------------------------------------------------------
  -- 3) Tabell (sorterbar, uke/totalt)
  -------------------------------------------------------------------------
  local tablePage = newPage("table")
  local COLS = {
    { key = "rank", label = "#", w = 24 },
    { key = "name", label = "Spiller", w = 0 },
    { key = "level", label = "Level", w = 42 },
    { key = "quests", label = "Quests", w = 50 },
    { key = "gold", label = "Gull", w = 62 },
    { key = "kills", label = "Kills", w = 40 },
    { key = "deaths", label = "Død", w = 34 },
  }
  local seg = UI.Panel(tablePage, C.input, C.inputLine, true)
  seg:SetSize(170, 28)
  seg:SetPoint("TOPRIGHT", 0, 0)
  local segBtns = {}
  local function paintSeg()
    for k, b in pairs(segBtns) do
      local on = k == mode
      b.panel:SetColors(on and "33383E" or nil, nil)
      b.label:SetTextColor(hex(on and C.text or C.muted))
      b.style = { fill = on and "33383E" or nil, text = on and C.text or C.muted, hover = "2D3237" }
    end
  end
  for i, def in ipairs({ { "week", "Denne uka" }, { "total", "Totalt" } }) do
    local b = UI.Button(seg, 82, 22, def[2], "nav", function() mode = def[1] paintSeg() tab:Refresh() end)
    b:SetPoint("LEFT", 3 + (i - 1) * 83, 0)
    segBtns[def[1]] = b
  end
  paintSeg()
  local sortHint = UI.Text(tablePage, 11, nil, C.dim)
  sortHint:SetPoint("LEFT", 0, 0)
  sortHint:SetPoint("TOP", seg, "TOP", 0, -8)
  sortHint:SetText("Klikk på en kolonne for å sortere")

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
    end
  end
  layoutCols(header, headerTexts)

  local function value(p, key)
    if key == "level" then return ns:PersonMaxLevel(p) end
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
    for _, k in ipairs({ "level", "quests", "gold", "kills", "deaths" }) do row.cells[k] = UI.Text(row, 12, nil, C.text2) end
    layoutCols(row, row.cells)
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
    row.cells.name:SetText(ns.Colorize(ns:PersonFirst(p), ns.ClassHex(c.class)))
    row.cells.level:SetText(ns:PersonMaxLevel(p))
    row.cells.quests:SetText(math.floor(value(p, "quests")))
    row.cells.gold:SetText(math.floor(value(p, "gold") / 10000) .. "g")
    row.cells.kills:SetText(math.floor(value(p, "kills")))
    row.cells.deaths:SetText(math.floor(value(p, "deaths")))
  end
  local tableList = UI.List(tablePage, 36, 5, createRow, updateRow)
  tableList:SetPoint("TOPLEFT", 0, -58)
  tableList:SetPoint("BOTTOMRIGHT", 6, 0)

  -------------------------------------------------------------------------
  -- 4) Morsomme fakta
  -------------------------------------------------------------------------
  local factsPage = newPage("facts")
  local factsBox = UI.Panel(factsPage, C.card, C.line, false)
  factsBox:SetAllPoints()
  local facts = UI.MessageFrame(factsBox, 13)
  facts:SetPoint("TOPLEFT", 14, -12)
  facts:SetPoint("BOTTOMRIGHT", -14, 12)
  facts:SetSpacing(10)
  facts:SetInsertMode("TOP")

  local function nameOf(p)
    local c = ns:PersonChar(p) or {}
    return ns.Colorize(ns:PersonFirst(p), ns.ClassHex(c.class))
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
    if best then entries[#entries + 1] = { "Up", C.green, "Raskeste ding", nameOf(best.p) .. " til level " .. best.l .. " på " .. ns.Duration(best.dt) } end
    local lp, lv = maxBy(function(p) return (p.stats or {}).tLongest end)
    if lp then entries[#entries + 1] = { "Clock", C.accent, "Lengste økt", nameOf(lp) .. " – " .. ns.Duration(lv) } end
    local pp, pv = maxBy(function(p) return ns:PersonPlayed(p) end)
    if pp then entries[#entries + 1] = { "Clock", C.purple, "Mest /played", nameOf(pp) .. " – " .. ns.Duration(pv) } end
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
    if bz then entries[#entries + 1] = { "Skull", C.red, "Farligste sone", bz .. " – " .. bzv .. " dødsfall" } end
    local dp, dv = maxBy(function(p) return ns:TotalStat(p, "Deaths") end)
    if dp then entries[#entries + 1] = { "Skull", C.dim, "Flest dødsfall", nameOf(dp) .. " – " .. math.floor(dv) } end
    local gp, gv = maxBy(function(p) return ns:TotalStat(p, "Gold") end)
    if gp then entries[#entries + 1] = { "Star", C.gold, "Mest gull tjent", nameOf(gp) .. " – " .. ns.Money(gv) } end
    local qp, qv = maxBy(function(p) return ns:TotalStat(p, "Quests") end)
    if qp then entries[#entries + 1] = { "Check", C.green, "Flest quests", nameOf(qp) .. " – " .. math.floor(qv) } end
    local kp, kv = maxBy(function(p) return ns:TotalStat(p, "Kills") end)
    if kp then entries[#entries + 1] = { "Target", C.red, "Flest PvP-kills", nameOf(kp) .. " – " .. math.floor(kv) } end
    -- Mest gratulert
    local grats = {}
    for _, it in ipairs(ns.db.feed) do
      if it.reacts then grats[it.pid] = (grats[it.pid] or 0) + #it.reacts end
    end
    local gpid, gcount = nil, 0
    for pid, v in pairs(grats) do if v > gcount then gpid, gcount = pid, v end end
    if gpid then entries[#entries + 1] = { "Star", C.purple, "Mest gratulert", nameOf(ns:GetPerson(gpid) or {}) .. " – " .. gcount .. " gratulasjoner" } end
    -- Mest pratsom
    local talk = {}
    for _, it in ipairs(ns.db.chat) do talk[it.pid] = (talk[it.pid] or 0) + 1 end
    local tpid, tcount = nil, 0
    for pid, v in pairs(talk) do if v > tcount then tpid, tcount = pid, v end end
    if tpid then entries[#entries + 1] = { "Chat", C.accent, "Mest pratsom", nameOf(ns:GetPerson(tpid) or {}) .. " – " .. tcount .. " meldinger" } end

    if #entries == 0 then
      facts:AddMessage(ns.Colorize("Ingen fakta ennå – spill litt, så dukker de opp her.", C.dim))
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

  local ch = card(92, "Ukens utfordring")
  ch:SetPoint("TOPLEFT") ch:SetPoint("TOPRIGHT")
  ch.main = UI.Text(ch, 14, "semi", C.text)
  ch.main:SetPoint("TOPLEFT", 12, -30)
  ch.sub = UI.Text(ch, 12, nil, C.text2)
  ch.sub:SetPoint("TOPLEFT", 12, -50)
  ch.sub:SetPoint("RIGHT", -10, 0)
  ch.last = UI.Text(ch, 11, nil, C.muted)
  ch.last:SetPoint("TOPLEFT", 12, -70)
  ch.last:SetPoint("RIGHT", -10, 0)

  local shame = card(80, "Skammens tavle (uka)")
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

  local firsts = card(10, "Først i gjengen")
  firsts:SetPoint("TOPLEFT", shame, "BOTTOMLEFT", 0, -8)
  firsts:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT")
  firsts.text = UI.Text(firsts, 12, nil, C.text2)
  firsts.text:SetPoint("TOPLEFT", 12, -30)
  firsts.text:SetPoint("RIGHT", -10, 0)
  firsts.text:SetWordWrap(true)
  firsts.text:SetJustifyV("TOP")
  firsts.text:SetSpacing(5)

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
    elseif page == "table" then
      table.sort(people, function(a, b)
        local va, vb = value(a, sortKey), value(b, sortKey)
        if va ~= vb then return va > vb end
        return ns:PersonMaxLevel(a) > ns:PersonMaxLevel(b)
      end)
      tableList:SetData(people)
      for key, t in pairs(headerTexts) do t:SetTextColor(hex(key == sortKey and C.accent or C.dim)) end
    elseif page == "facts" then
      drawFacts()
    end

    -- Utfordring
    local chal, leader, v = ns.Data:CurrentLeader()
    ch.main:SetText(chal.label)
    local wday = tonumber(date("%w"))
    local daysLeft = (8 - wday) % 7
    if daysLeft == 0 then daysLeft = 7 end
    if leader then
      local lc = ns:PersonChar(leader) or {}
      ch.sub:SetText("Leder: " .. ns.Colorize(ns:PersonFirst(leader), ns.ClassHex(lc.class)) .. " – " .. chal.fmt(v))
    else
      ch.sub:SetText("Ingen poeng ennå")
    end
    local pch, pbest, pv = ns.Data:LastWeekWinner()
    if pbest then
      ch.last:SetText(daysLeft .. " d igjen · forrige uke: " .. ns:PersonFirst(pbest) .. " (" .. pch.fmt(pv) .. ")")
    else
      ch.last:SetText(daysLeft .. " d igjen")
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
      shame.who:SetText("dødsfall · " .. ns.Colorize(ns:PersonFirst(worst), ns.ClassHex(wc.class)))
      shame.last:SetText(worst.deathZone and ("Sist: " .. worst.deathZone .. ", " .. ns.Ago(worst.deathAt)) or "")
    else
      shame.big:SetText("0")
      shame.who:SetText("dødsfall – imponerende")
      shame.last:SetText("")
    end

    local lines = {}
    for _, key in ipairs({ "L10", "L20", "L30", "L40", "L50", "L60", "MOUNT" }) do
      local f = ns.db.firsts[key]
      if f then
        local p = ns:GetPerson(f.pid) or {}
        local c = (p.chars and p.chars[f.char]) or {}
        local label = key == "MOUNT" and "Mount" or ("Level " .. key:sub(2))
        lines[#lines + 1] = ns.Colorize(label, C.muted) .. "  " .. ns.Colorize(ns.FirstName(f.char), ns.ClassHex(c.class))
      end
    end
    firsts.text:SetText(#lines > 0 and table.concat(lines, "\n") or ns.Colorize("Ingen ennå – hvem blir først til level 10?", C.muted))
  end

  paintPages()
end)
