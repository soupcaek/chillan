-- Chillan? – the Now card (1.1.0, Gang pulse): under the four fixed boxes, what matters for what
-- you're doing right now. 1.4.0: one layout per scenario –
--   open world: level bar, this session (+ what you gathered), "Died to" players near you
--   dungeon: next boss + boss track, pace against the gang's best run, deaths and wipes, loot
--   raid: next boss + boss track, the gang here, the gang's loot tonight, your own raid prep
--   battleground: your kills/deaths/streak, the gang's K/D here, this week's honor, wins today
-- and a "moment" that takes over the card for a while: the ding, the end of a run or raid night,
-- the end of a battleground. In combat the boxes and this card fold away (unless pinned).
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex
local N = {}
ns.NowCard = N

local PAD = 20          -- (1.4.66) 8 px to the card + 12 px inside it
local MAX_LINES = 6
local MOMENT_SECS = { ding = 20, run = 60, bg = 45 }

function N:Collapsed()
  return self.inCombat and not ns.db.settings.pulsePin
end

local function goldText(copper)
  if not copper then return "–" end
  local neg = copper < 0
  copper = math.abs(copper)
  local g, s = math.floor(copper / 10000), math.floor((copper % 10000) / 100)
  local t = g > 0 and (ns.Num(g) .. "g " .. s .. "s") or (s .. "s " .. (copper % 100) .. "c")
  return (neg and "−" or "") .. t
end

local function freeBags()
  local free = 0
  local api = C_Container
  for bag = 0, 4 do
    local ok, f = pcall(api and api.GetContainerNumFreeSlots or GetContainerNumFreeSlots, bag)
    if ok and type(f) == "number" and not ns.isSecret(f) then free = free + f end
  end
  return free
end

local function mmss(secs)
  if not secs then return "" end
  if secs >= 3600 then return ns.Duration(secs) end
  return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end

local function dim(t) return ns.Colorize(t, C.dim) end

function N:Create()
  local m = ns.Overlays.minibar
  if not m or self.frame then return end
  local f = CreateFrame("Frame", "ChillanNow", UIParent)
  f:SetFrameStrata("MEDIUM")
  f:SetFrameLevel(m:GetFrameLevel() + 5)
  f:SetSize(330, 60)
  f:EnableMouse(true)
  self.frame = f
  f.head = UI.Text(f, 10, "bold", C.text2)
  -- (1.4.66) the canvas Pulse card: a light panel with a title strip, behind the card's own text
  f.card = UI.Backplate(f, "")
  -- (1.4.65) a small see-through title strip behind the card's heading (the light Market look)
  f.strip = UI.Track(f:CreateTexture(nil, "BACKGROUND", nil, 2))
  f.strip:SetColorTexture(hex(C.strip or C.cardHover))
  f.strip:SetAlpha(0.55)
  f.strip:SetPoint("TOPLEFT", f, "TOPLEFT", 1, 0)
  f.strip:SetPoint("RIGHT", f, "RIGHT", -1, 0)
  f.strip:SetPoint("BOTTOM", f.head, "BOTTOM", 0, -5)
  f.strip:Hide()
  f.big = UI.Text(f, 18, "bold", C.text)
  f.bigSub = UI.Text(f, 11, nil, C.muted)
  f.right = UI.Text(f, 11, nil, C.muted)
  f.right:SetJustifyH("RIGHT")
  f.meter = CreateFrame("Frame", nil, f)
  f.meter:SetHeight(5)
  f.meter.bg = f.meter:CreateTexture(nil, "ARTWORK")
  f.meter.bg:SetAllPoints()
  UI.Track(f.meter.bg):SetColorTexture(hex(C.active))
  f.meter.fill = f.meter:CreateTexture(nil, "OVERLAY")
  f.meter.fill:SetPoint("TOPLEFT")
  f.meter.fill:SetPoint("BOTTOMLEFT")
  UI.Track(f.meter.fill):SetColorTexture(hex(C.accent))
  f.lines = {}
  for i = 1, MAX_LINES do
    local l = UI.Text(f, 11, nil, C.text2)
    l:SetJustifyH("LEFT")
    l:SetWordWrap(false)
    f.lines[i] = l
  end
  -- (1.4.73) a right-aligned companion per line (pace, last split)
  f.linesR = {}
  for i = 1, MAX_LINES do
    local r = UI.Text(f, 11, nil, C.text2)
    r:SetJustifyH("RIGHT")
    r:SetWordWrap(false)
    f.linesR[i] = r
  end
  -- (1.4.73) the Baron run's 45 minutes, as a red chip in the title
  f.baron = UI.Text(f, 10, "semi", "F2777A")
  f.baron:Hide()
  -- the boss track: one small block per boss (green = dead, accent = next)
  f.track = CreateFrame("Frame", nil, f)
  f.track:SetHeight(10)
  f.track.blocks = {}
  -- (1.4.2) hover the track: the list of bosses (green = killed, accent = next)
  f.track:EnableMouse(true)
  f.track:SetScript("OnEnter", function(self) GameTooltip:Hide() if ns.Tiles and ns.Tiles.BossList then ns.Tiles:BossList(self) end end)
  f.track:SetScript("OnLeave", function() if ns.Tiles and ns.Tiles.bossFrame then ns.Tiles.bossFrame:Hide() end end)
  f.track:SetScript("OnMouseUp", function() end)
  f.btn = UI.Button(f, 96, 20, "Ready check", "secondary", function() ns.Extras:StartReadyCheck() end)
  f.btn.label:SetFont(ns.FONT_SEMI or ns.FONT, 11, "")
  f.btn.tooltip = "Bags, durability and food/drink for everyone in your group"
  f.btnNote = UI.Text(f, 11, nil, C.dim)
  -- (1.4.73) the ready check is a small check mark in the title line (hover for what it does)
  f.rc = UI.IconButton(f, 18, "Check", nil, function() ns.Extras:StartReadyCheck() end)
  f.rc:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Ready check", 1, 1, 1)
    GameTooltip:AddLine("Click: bags, durability and food/drink for everyone in your group.", 0.8, 0.8, 0.8, true)
    if f.lastBoss then GameTooltip:AddLine("Last boss: " .. f.lastBoss, 0.6, 0.6, 0.65, true) end
    GameTooltip:Show()
  end)
  f.rc:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.rc:Hide()
  -- (1.4.76) the rolling boss list: done ones fold away, the next is lit, two after it
  f.brows = {}
  for i = 1, 6 do
    local r = {}
    r.bg = UI.Track(f:CreateTexture(nil, "BACKGROUND", nil, 4))
    r.bg:SetColorTexture(hex(C.amber))
    r.bg:SetAlpha(0.09)
    r.mark = UI.Text(f, 11, "semi", C.dim)
    r.mark:SetWidth(12)
    r.name = UI.Text(f, 11, nil, C.text2)
    r.name:SetWordWrap(false)
    r.name:SetJustifyH("LEFT")
    r.right = UI.Text(f, 10, nil, C.dim)
    r.right:SetJustifyH("RIGHT")
    r.right:SetWordWrap(false)
    f.brows[i] = r
  end
  -- (1.4.76) the choices at the door (the sides of Strat, the usual BRD runs …)
  f.doors = {}
  for i = 1, 4 do
    local d = CreateFrame("Frame", nil, f)
    d.edge = UI.Track(d:CreateTexture(nil, "BACKGROUND", nil, 3))
    d.edge:SetAllPoints()
    d.edge:SetColorTexture(hex(C.active))
    d.fill = UI.Track(d:CreateTexture(nil, "BACKGROUND", nil, 4))
    d.fill:SetPoint("TOPLEFT", 1, -1)
    d.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    d.fill:SetColorTexture(hex(C.window))
    d.t = UI.Text(d, 11, "semi", C.text)
    d.t:SetPoint("TOPLEFT", 7, -5)
    d.t:SetPoint("RIGHT", d, "RIGHT", -6, 0)
    d.t:SetWordWrap(false)
    d.s = UI.Text(d, 10, nil, C.dim)
    d.s:SetPoint("TOPLEFT", 7, -19)
    d.s:SetPoint("RIGHT", d, "RIGHT", -6, 0)
    d.s:SetWordWrap(false)
    d:SetHeight(34)
    d:Hide()
    f.doors[i] = d
  end
  -- (1.4.76) the pull timer in the title: "Pull" to start it (leader/tank), "Pull in 4" while it runs
  f.pull = CreateFrame("Button", nil, f)
  f.pull:SetSize(54, 16)
  f.pull.bg = UI.Track(f.pull:CreateTexture(nil, "BACKGROUND"))
  f.pull.bg:SetAllPoints()
  f.pull.bg:SetColorTexture(hex(C.amber))
  f.pull.t = UI.Text(f.pull, 10, "semi", C.amber)
  f.pull.t:SetPoint("CENTER")
  f.pull:SetScript("OnClick", function() if not ns.Extras.pullEnds then ns.Extras:Pull(5) end end)
  f.pull:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Pull timer", 1, 1, 1)
    GameTooltip:AddLine("Click (or /chill pull 8): a countdown for the whole group. Leader or tank.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  f.pull:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.pull:Hide()
  -- (1.4.76) loot so far: hover for who got what
  f.lootHit = CreateFrame("Frame", nil, f)
  f.lootHit:EnableMouse(true)
  f.lootHit:SetScript("OnEnter", function(self) N:LootTooltip(self) end)
  f.lootHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.lootHit:Hide()
  f:SetScript("OnMouseUp", function(_, btn)
    if N.moment then N.moment = nil N:Update() return end   -- a click closes the moment
    ns.Window:Toggle("stats")
  end)
  f:SetScript("OnEnter", function(self) N:Tooltip(self) end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)

  ns:Listen("PULSE", function() N:Update() end)
  ns:Listen("PULSE_MODE", function() N:Update() if ns.Overlays.UpdateGroup then ns.Overlays:UpdateGroup() end end)
  ns:Listen("DATA", function() N:Update() end)
  ns:Listen("LEVEL_RECAP", function(x) N:Moment("ding", x) end)
  ns:Listen("RUN_CARD", function(x) N:Moment("run", x) end)
  ns:Listen("BG_CARD", function(x) N:Moment("bg", x) end)
  ns:On("PLAYER_REGEN_DISABLED", function() N.inCombat = true N:Relayout() end)
  ns:On("PLAYER_REGEN_ENABLED", function() N.inCombat = false N:Relayout() end)
  C_Timer.NewTicker(2, function() N:Update() end)
  self:Update()
end

function N:Moment(kind, data)
  if not data then return end
  self.moment = { kind = kind, data = data, untilT = GetTime() + (MOMENT_SECS[kind] or 30) }
  self:Update()
end

function N:Relayout()
  if ns.Tiles and ns.Tiles.holder then ns.Tiles:Layout() elseif ns.Overlays.UpdateGroup then ns.Overlays:UpdateGroup() end
end

local function drawTrack(f, list, width, full)
  local tr = f.track
  for _, b in ipairs(tr.blocks) do b:Hide() end
  if not list or #list == 0 then tr:Hide() return 0 end
  local n = #list
  local bw = full and math.max(4, math.floor((width + 3) / n) - 3) or math.max(4, math.min(14, math.floor((width + 3) / n) - 3))
  local nextDone = false
  for i, b in ipairs(list) do
    local t = tr.blocks[i]
    if not t then t = tr:CreateTexture(nil, "ARTWORK") tr.blocks[i] = t end
    t:ClearAllPoints()
    t:SetSize(bw, full and 8 or 6)
    t:SetPoint("LEFT", tr, "LEFT", (i - 1) * (bw + 3), 0)
    if b.killed then t:SetColorTexture(hex("5FD18B"))
    elseif not nextDone then nextDone = true t:SetColorTexture(hex(C.accent))
    else t:SetColorTexture(hex(C.active)) end
    t:Show()
  end
  local w = n * (bw + 3) - 3
  tr:SetWidth(w)
  tr:Show()
  return w
end

-- place the parts top-down and size the card
local function place(f, rows, track)
  local width = f:GetWidth()
  f.head:ClearAllPoints() f.big:ClearAllPoints() f.bigSub:ClearAllPoints() f.right:ClearAllPoints() f.meter:ClearAllPoints()
  f.track:ClearAllPoints()
  -- the heading sits in the card's title strip
  f.strip:Hide()
  f.head:SetPoint("LEFT", f, "TOPLEFT", PAD, -(8 + 1 + f.card.stripH / 2 - 1))
  f.head:SetPoint("RIGHT", f, "TOPRIGHT", -PAD, -(8 + 1 + f.card.stripH / 2 - 1))
  f.head:SetWordWrap(false)
  f.head:Show()
  local y = f.card.top
  if f.big:GetText() and f.big:GetText() ~= "" then
    f.big:SetPoint("TOPLEFT", PAD, y)
    f.bigSub:SetPoint("BOTTOMLEFT", f.big, "BOTTOMRIGHT", 6, 2)
    f.bigSub:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    f.bigSub:SetJustifyH("LEFT")
    f.bigSub:SetWordWrap(false)
    f.right:SetPoint("TOPRIGHT", -PAD, y - 5)
    y = y - 24
    f.big:Show() f.bigSub:Show() f.right:Show()
  else
    f.big:Hide() f.bigSub:Hide() f.right:Hide()
  end
  if f.meter.pct then
    f.meter:SetPoint("TOPLEFT", PAD, y)
    f.meter:SetPoint("TOPRIGHT", -PAD, y)
    f.meter.fill:SetWidth(math.max(1, (width - 2 * PAD) * math.min(1, f.meter.pct)))
    f.meter:Show()
    y = y - 11
  else
    f.meter:Hide()
  end
  local trackW = 0
  if track and f.trackFull then
    -- (1.4.73) option A: the boss track runs the full width on its own row, the lines below it
    drawTrack(f, track, width - 2 * PAD, true)
    f.track:SetPoint("TOPLEFT", PAD, y - 2)
    y = y - 16
  elseif track then trackW = drawTrack(f, track, math.floor((width - 2 * PAD) * 0.45)) else drawTrack(f, nil) end
  -- (1.4.76) the choices at the door, two to a row
  for _, d in ipairs(f.doors) do d:Hide() end
  if f.doorData then
    local colW = math.floor((width - 2 * PAD - 6) / 2)
    for i, c in ipairs(f.doorData) do
      local d = f.doors[i]
      if not d then break end
      d:ClearAllPoints()
      local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
      d:SetPoint("TOPLEFT", PAD + col * (colW + 6), y - row * 40)
      d:SetWidth(colW)
      d.t:SetText(c.name)
      d.s:SetText(c.sub or "")
      d:Show()
    end
    y = y - math.ceil(#f.doorData / 2) * 40 - 2
  end
  -- (1.4.76) the rolling boss list
  for _, r in ipairs(f.brows) do r.bg:Hide() r.mark:Hide() r.name:Hide() r.right:Hide() end
  for i, b in ipairs(f.bossData or {}) do
    local r = f.brows[i]
    if not r then break end
    r.mark:ClearAllPoints() r.name:ClearAllPoints() r.right:ClearAllPoints() r.bg:ClearAllPoints()
    r.mark:SetPoint("TOPLEFT", PAD + 4, y - 2)
    r.right:SetPoint("TOPRIGHT", -PAD - 4, y - 2)
    r.name:SetPoint("TOPLEFT", PAD + 20, y - 2)
    r.name:SetPoint("RIGHT", r.right, "LEFT", -8, 0)
    r.mark:SetText(b.mark or "")
    r.name:SetText(b.name or "")
    r.right:SetText(b.right or "")
    r.mark:Show() r.name:Show() r.right:Show()
    if b.lit then
      r.bg:SetPoint("TOPLEFT", PAD, y)
      r.bg:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
      r.bg:SetHeight(17)
      r.bg:Show()
    end
    y = y - 18
  end
  if f.bossData and #f.bossData > 0 then y = y - 3 end
  local rightT = f.rowsRight or {}
  for i, l in ipairs(f.lines) do
    l:ClearAllPoints()
    local rr = f.linesR[i]
    rr:ClearAllPoints()
    rr:Hide()
    if rows[i] and rightT[i] then
      rr:SetPoint("TOPRIGHT", -PAD, y)
      rr:SetText(rightT[i])
      rr:Show()
    end
    if rows[i] then
      l:SetPoint("TOPLEFT", PAD, y)
      -- the first line shares its row with the boss track
      if rows[i] and rightT[i] then
        l:SetPoint("RIGHT", rr, "LEFT", -8, 0)
      elseif i == 1 and trackW > 0 then
        f.track:SetPoint("RIGHT", f, "TOPRIGHT", -PAD, y - 6)
        l:SetPoint("RIGHT", f.track, "LEFT", -8, 0)
      else
        l:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
      end
      l:SetText(rows[i])
      l:Show()
      if f.lootRow == i then
        f.lootHit:ClearAllPoints()
        f.lootHit:SetPoint("TOPLEFT", PAD, y + 2)
        f.lootHit:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
        f.lootHit:SetHeight(18)
        f.lootHit:Show()
      end
      y = y - 17
    else
      l:Hide()
    end
  end
  f.btn:Hide() f.btnNote:Hide()
  if not f.lootRow then f.lootHit:Hide() end
  f.rc:ClearAllPoints()
  f.baron:ClearAllPoints()
  local headRight = nil
  if f.showBtn then
    f.rc:SetPoint("RIGHT", f, "TOPRIGHT", -PAD + 4, -(8 + 1 + f.card.stripH / 2 - 1))
    headRight = f.rc
    f.rc:Show()
  else
    f.rc:Hide()
  end
  if f.baronText then
    f.baron:SetText(f.baronText)
    if headRight then f.baron:SetPoint("RIGHT", headRight, "LEFT", -8, 0)
    else f.baron:SetPoint("RIGHT", f, "TOPRIGHT", -PAD, -(8 + 1 + f.card.stripH / 2 - 1)) end
    headRight = f.baron
    f.baron:Show()
  else
    f.baron:Hide()
  end
  -- (1.4.76) the pull chip
  f.pull:ClearAllPoints()
  if f.pullText then
    f.pull.t:SetText(f.pullText)
    f.pull:SetWidth(math.max(34, (f.pull.t:GetStringWidth() or 30) + 12))
    f.pull.bg:SetAlpha(f.pullLive and 0.22 or 0.08)
    if headRight then f.pull:SetPoint("RIGHT", headRight, "LEFT", -6, 0)
    else f.pull:SetPoint("RIGHT", f, "TOPRIGHT", -PAD, -(8 + 1 + f.card.stripH / 2 - 1)) end
    headRight = f.pull
    f.pull:Show()
  else
    f.pull:Hide()
  end
  if headRight then f.head:SetPoint("RIGHT", headRight, "LEFT", -6, 0) end
  f:SetHeight(-y + 8)
end

---------------------------------------------------------------------------
-- the moments
---------------------------------------------------------------------------
local function momentRows(f, mo)
  local x, rows = mo.data, {}
  if mo.kind == "ding" then
    f.head:SetText("DING! LEVEL " .. tostring(x.to or "?"))
    f.head:SetTextColor(hex("E0B04F"))
    f.big:SetText(x.time and ns.Duration(x.time) or "–")
    f.bigSub:SetText("for level " .. tostring(x.from or "?") .. (x.vsPrev and (x.vsPrev < 0 and (" · " .. ns.Duration(-x.vsPrev) .. " faster than the last") or "") or ""))
    local bits = {}
    if (x.quests or 0) > 0 then bits[#bits + 1] = ns.Plural(x.quests, "quest") end
    if (x.money or 0) > 0 then bits[#bits + 1] = goldText(x.money) end
    bits[#bits + 1] = ns.Plural(x.deaths or 0, "death")
    if x.xph then bits[#bits + 1] = ns.Num(x.xph) .. " XP/h" end
    rows[#rows + 1] = table.concat(bits, dim(" · "))
    if x.rank and x.rank.of and x.rank.of > 1 then
      rows[#rows + 1] = (x.rank.place == 1 and ns.Colorize("Fastest in the gang for this level", C.green)
        or ("No. " .. x.rank.place .. " of " .. x.rank.of .. " in the gang for this level"))
    end
    rows[#rows + 1] = dim("The gang can react in the feed · click to close")
  elseif mo.kind == "run" then
    local head = x.raid and ("RAID NIGHT · " .. tostring(x.name):upper()) or "RUN DONE"
    if x.record then head = head .. " · NEW GANG RECORD" end
    f.head:SetText(head)
    f.head:SetTextColor(hex(x.raid and "F0A060" or "8FB8E8"))
    f.big:SetText(ns.Duration(x.dur or 0))
    f.bigSub:SetText(x.bosses .. " / " .. (x.total or "?") .. " bosses" .. ((x.best and x.record) and (" · old record " .. ns.Duration(x.best)) or (x.best and (" · gang best " .. ns.Duration(x.best)) or "")))
    local bits = {}
    if (x.xp or 0) > 0 then bits[#bits + 1] = ns.Num(x.xp) .. " XP" end
    if (x.value or 0) > 0 then bits[#bits + 1] = goldText(x.value) .. " loot" end
    bits[#bits + 1] = ns.Plural(x.deaths or 0, "death")
    bits[#bits + 1] = ns.Plural(x.wipes or 0, "wipe")
    rows[#rows + 1] = table.concat(bits, dim(" · "))
    if x.drop then rows[#rows + 1] = dim("Best drop  ") .. x.drop end
    if x.raid and x.gangLoot and #x.gangLoot > 0 then rows[#rows + 1] = dim("Gang epics  ") .. #x.gangLoot end
    if x.floor and (x.floorN or 0) > 0 then rows[#rows + 1] = dim(x.raid and "Lava enjoyer  " or "Floor inspector  ") .. x.floor .. dim("  " .. ns.Plural(x.floorN, "death")) end
    if x.fast then rows[#rows + 1] = dim("Fastest boss  ") .. x.fast .. dim("  " .. mmss(x.fastSecs)) end
  elseif mo.kind == "bg" then
    f.head:SetText((x.won and "VICTORY" or "DEFEAT") .. (x.score and (" · " .. x.score) or "") .. " · " .. math.floor((x.dur or 0) / 60) .. " MIN")
    f.head:SetTextColor(hex(x.won and "5FD18B" or "F2777A"))
    f.big:SetText(x.honor and ("+" .. ns.Num(x.honor)) or "–")
    f.bigSub:SetText("honor · " .. (x.wonToday or 0) .. " / " .. (x.played or 0) .. " won today"
      .. ((x.streak or 0) > 1 and (" · " .. x.streak .. " in a row") or ""))
    if x.mvp and #(x.gang or {}) <= 1 then
      -- (1.4.19) alone: your own match, not "Gang MVP: you"
      rows[#rows + 1] = dim("Your match  ") .. ns.Plural(x.mvp.hk, "HK") .. dim(" · ") .. ns.Plural(x.mvp.deaths, "death")
        .. ((x.mvp.kb or 0) > 0 and (dim(" · ") .. ns.Plural(x.mvp.kb, "killing blow")) or "")
    elseif x.mvp then rows[#rows + 1] = dim("Gang MVP  ") .. x.mvp.name .. dim("  " .. x.mvp.hk .. " HKs · " .. ns.Plural(x.mvp.deaths, "death")) end
    if x.hero and x.heroFlags then
      local fl = {}
      if x.heroFlags.cap > 0 then fl[#fl + 1] = ns.Plural(x.heroFlags.cap, "capture") end
      if x.heroFlags.ret > 0 then fl[#fl + 1] = ns.Plural(x.heroFlags.ret, "return") end
      rows[#rows + 1] = dim("Flag hero  ") .. x.hero .. dim("  " .. table.concat(fl, ", "))
    end
    if x.revs and #x.revs > 0 then rows[#rows + 1] = dim("Revenge  ") .. ns.Colorize(table.concat(x.revs, ", "), C.green) end
    -- (1.4.61) no third line: the kill streak is gone, a win streak rides on the honor line
  end
  return rows
end

---------------------------------------------------------------------------
-- raid prep: your own fire resist (Molten Core), flask, and the raids you're saved to
---------------------------------------------------------------------------
local function savedTo()
  local out = {}
  if not GetNumSavedInstances or not GetSavedInstanceInfo then return out end
  local ok, n = pcall(GetNumSavedInstances)
  if not ok or type(n) ~= "number" then return out end
  for i = 1, n do
    local ok2, name, _, _, _, locked = pcall(GetSavedInstanceInfo, i)
    if ok2 and locked and type(name) == "string" then out[#out + 1] = ns.ShortDungeonPlain and ns.ShortDungeonPlain(name) or name end
  end
  return out
end
local function hasFlask()
  if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return nil end
  for i = 1, 40 do
    local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
    if not ok or not a then break end
    local nm = a.name
    if type(nm) == "string" and not ns.isSecret(nm) and nm:find("Flask") then return true end
  end
  return false
end

---------------------------------------------------------------------------
-- (1.4.76) the dungeon card: the choices at the door, or a boss list that rolls along with the run
---------------------------------------------------------------------------
local function holder(rec)
  local p = rec and rec.pid and ns:GetPerson(rec.pid)
  return p and ns:PersonFirst(p) or nil
end
local function vsRec(secs, rec)
  if not (secs and rec and rec.s) then return "" end
  local d = secs - rec.s
  return "  " .. (d <= 0 and ns.Colorize("−" .. mmss(-d), C.green) or ns.Colorize("+" .. mmss(d), C.red))
end
N.MAX_LOOT = 6
function N:DungeonRows(f, r, pr, rows)
  local B = ns.Bosses
  local list, wing, _, doors = B:For(r.name, r.killed, true)
  local n = 0
  for _, b in ipairs(list) do if b.killed then n = n + 1 end end
  f.head:SetText((r.name .. (wing and (" · " .. wing) or "")):upper())
  -- at the door: the sides or the usual runs, each with its size and the gang's best
  if doors and n == 0 then
    f.doorData = {}
    local isRun = B.RoutesFor(r.name) ~= nil
    for _, d in ipairs(doors) do
      local cnt = 0
      for _, x in ipairs(d.list or {}) do if tostring(x):sub(1, 1) ~= "?" then cnt = cnt + 1 end end
      local best = ns.Extras:BestFor(r.name .. " · " .. d.name, "DUNGEON")
      local sub = d.open and "ends at the Emperor" or ns.Plural(cnt, "boss", "bosses")
      if best then sub = sub .. " · best " .. ns.Duration(best) end
      f.doorData[#f.doorData + 1] = { name = d.name, sub = sub }
    end
    rows[#rows + 1] = dim(isRun and "Which run? It settles at the first kills." or "Which side? The list fills in at the first boss.")
    return rows
  end
  -- the rolling list
  local done, left = {}, {}
  for _, b in ipairs(list) do
    if b.killed then done[#done + 1] = b elseif not b.opt then left[#left + 1] = b end
  end
  table.sort(done, function(a, b) return (a.secs or 0) < (b.secs or 0) end)
  local data = {}
  local function recFor(name) return B:BossRecord(r.name, name) end
  if #done == 1 then
    local b = done[1]
    data[#data + 1] = { mark = ns.Colorize("✓", C.green), name = b.name,
      right = b.as and ns.Colorize(b.as, C.green) or (b.secs and (ns.Colorize(mmss(b.secs), C.green) .. vsRec(b.secs, recFor(b.name))) or "") }
  elseif #done > 1 then
    local last = done[#done]
    data[#data + 1] = { mark = ns.Colorize("✓", C.green), name = ns.Colorize(#done .. " down", C.green) .. dim("  · last ") .. last.name,
      right = last.secs and (mmss(last.secs) .. vsRec(last.secs, recFor(last.name))) or "" }
  end
  if #left == 0 then
    data[#data + 1] = { mark = ns.Colorize("✓", C.green), name = ns.Colorize(n > 0 and "All bosses down" or "No boss yet", n > 0 and C.green or C.dim) }
  else
    for i = 1, math.min(3, #left) do
      local b = left[i]
      local rec = recFor(b.name)
      if i == 1 then
        local who = holder(rec)
        -- (the game's font has no ▸: the Target icon marks the next boss)
        data[#data + 1] = { mark = UI.InlineIcon("Target", C.amber, 11), lit = true,
          name = ns.Extras.inEncounter and ns.Colorize("Boss fight", C.amber) or ns.Colorize(b.name, C.text),
          right = rec and (dim("best " .. mmss(rec.s)) .. (who and dim(" · " .. who) or "")) or "" }
      else
        data[#data + 1] = { mark = dim("○"), name = ns.Colorize(b.name, C.muted), right = rec and dim(mmss(rec.s)) or "" }
      end
    end
    if #left > 3 then
      local lastName = left[#left].name
      data[#data + 1] = { mark = "", name = dim("+" .. (#left - 3) .. " more · " .. lastName .. " at the end") }
    end
  end
  f.bossData = data
  -- deaths and the pace against the gang's best of this side or run
  rows[#rows + 1] = ns.Colorize(ns.Plural(r.deaths or 0, "death") .. " · " .. ns.Plural(r.wipes or 0, "wipe"), C.muted)
  local _, total = B:Count(r.name, r.killed)
  local best = (wing and ns.Extras:BestFor(r.name .. " · " .. wing, "DUNGEON")) or ns.Extras:BestFor(r.name, "DUNGEON")
  if best and total and total > 0 and n > 0 then
    local diff = math.floor(best * n / total - (ns.Now() - r.start))
    f.rowsRight[#rows] = (diff >= 0 and ns.Colorize("−" .. ns.Duration(diff), C.green) or ns.Colorize("+" .. ns.Duration(-diff), C.amber)) .. dim(" vs best " .. ns.Duration(best))
  elseif best then
    f.rowsRight[#rows] = dim("best " .. ns.Duration(best))
  end
  -- loot so far: rare and epic drops for the group (6, then +N), your take on the right
  local drops = pr and pr.drops or {}
  local icons = {}
  for i = #drops, math.max(1, #drops - N.MAX_LOOT + 1), -1 do
    local id = tonumber(tostring(drops[i].link):match("item:(%d+)"))
    local tex = id and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    icons[#icons + 1] = "|T" .. tostring(tex or 134400) .. ":16:16:0:0:64:64:5:59:5:59|t"
  end
  local take = pr and ns.Pulse:LootValue(pr) or 0
  if ns.db.settings.dgLoot ~= false and (#drops > 0 or take > 0) then
    rows[#rows + 1] = dim("Loot so far  ") .. table.concat(icons, " ") .. (#drops > N.MAX_LOOT and dim("  +" .. (#drops - N.MAX_LOOT)) or "")
      .. (#drops == 0 and dim("nothing rare yet") or "")
    f.rowsRight[#rows] = take > 0 and (dim("your take ") .. goldText(take)) or ""
    f.lootRow = #rows
  end
  f.lootLine = table.concat(icons, "")
  return rows
end

-- hover the loot line: each rare/epic drop, who got it and how (from the loot rolls)
function N:LootTooltip(owner)
  local _, pr = ns.Pulse:Run()
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine("Loot so far", 1, 1, 1)
  local drops = pr and pr.drops or {}
  if #drops == 0 then GameTooltip:AddLine("No rare or epic drop yet.", 0.7, 0.7, 0.7) end
  for i = #drops, 1, -1 do
    local d = drops[i]
    local how
    local R = ns.LootRolls
    local id = tostring(d.link):match("item:(%d+)")
    for _, h in ipairs(R and R.history or {}) do
      if h.item == id and h.winner then
        for _, p in ipairs(h.players or {}) do
          if p.won then how = (p.choice or "") .. (p.roll and (" " .. p.roll) or "") end
        end
      end
    end
    GameTooltip:AddDoubleLine(d.link, (d.who or "?") .. (how and how ~= "" and (" · " .. how) or ""), 1, 1, 1, 0.75, 0.75, 0.75)
  end
  local take = pr and ns.Pulse:LootValue(pr) or 0
  if take > 0 then GameTooltip:AddLine(" ") GameTooltip:AddDoubleLine("Your take", goldText(take), 0.7, 0.7, 0.7, 1, 1, 1) end
  GameTooltip:AddLine("Coins you looted + what your items sell for (market price when it has one).", 0.55, 0.55, 0.6, true)
  GameTooltip:Show()
end

-- the pull chip's countdown (Extras ticks this while a pull runs)
function N:PullTick()
  local f = self.frame
  if not f or not f:IsShown() then return end
  local X = ns.Extras
  if X.pullEnds then
    local left = X.pullEnds - GetTime()
    f.pull.t:SetText(left > 0.05 and ("Pull in " .. math.ceil(left)) or "Pull!")
    f.pull.bg:SetAlpha(0.22)
  end
end

function N:Update()
  local f = self.frame
  if not f or not f:IsShown() then return end
  local P = ns.Pulse
  local mode = P:Mode()
  local rows, track = {}, nil
  f.meter.pct, f.showBtn = nil, false
  f.trackFull, f.rowsRight, f.baronText = nil, nil, nil
  f.doorData, f.bossData, f.lootRow, f.pullText, f.pullLive = nil, nil, nil, nil, nil
  f.head:SetText("") f.big:SetText("") f.bigSub:SetText("") f.right:SetText("")
  f.head:SetTextColor(hex(C.text2))
  local dg = P:Danger()

  if self.moment and GetTime() > self.moment.untilT then self.moment = nil end
  if self.moment then
    rows = momentRows(f, self.moment)

  elseif mode == "world" then
    local d = ns.Tracker:S3Data() or {}
    local c = ns.Tracker:MyChar() or {}
    local lvl = ns.S(UnitLevel, "player") or c.level or 0
    local maxLvl = 60   -- WoW Forever caps at 60 (the engine may report a higher cap)
    if type(lvl) == "number" and lvl < maxLvl then
      local pct = (d.xp and d.xpMax and d.xpMax > 0) and math.floor(d.xp / d.xpMax * 100) or nil
      f.big:SetText(pct and (pct .. " %") or "–")
      f.bigSub:SetText("of level " .. (c.level or "?"))
      -- (1.1.6) the XP left, not a guess at quests
      local left = (d.xp and d.xpMax) and (d.xpMax - d.xp) or nil
      f.right:SetText(left and (ns.Num(left) .. " XP left") or "")
      if d.xp and d.xpMax and d.xpMax > 0 then f.meter.pct = d.xp / d.xpMax end
    end
    local s = P.sess
    local gold = P:SessionGold()
    if P.AtMax and P.AtMax() then
      -- (1.4.17) level 60: PvP rank progress up top, and a session line about honor, rep and bosses
      local rank, rname, prog = P:Rank()
      -- (1.4.37) the faction you picked with "Show as Experience Bar" in the reputation window
      local wf = P.WatchedRep and P.WatchedRep()
      if wf then
        -- (1.4.66) as on the canvas: "FROSTWOLF · FRIENDLY", 4 772 / 6 000, the rate on the right
        f.head:SetText((ns.ShortFaction(wf.name) .. " · " .. tostring(wf.standing)):upper())
        f.big:SetText(wf.exalted and "Exalted" or ns.Num(wf.into))
        f.bigSub:SetText(wf.exalted and "" or ("/ " .. ns.Num(wf.span)))
        f.meter.pct = wf.pct
        f.right:SetText(wf.perHour and (ns.Num(wf.perHour) .. " /h") or "")
      elseif rank or prog then
        f.big:SetText(rank and ("Rank " .. rank) or (math.floor((prog or 0) * 100) .. " %"))
        f.bigSub:SetText(rname or "PvP rank")
        if prog then
          f.meter.pct = prog
          f.right:SetText(math.floor(prog * 100) .. " % to rank " .. ((rank or 0) + 1))
        end
      else
        f.big:SetText("60")
        f.bigSub:SetText("max level")
      end
      local hk, honor = P:SessionHonor()
      local fac, repN = P:TopRep()
      local bits = {}
      if (hk or 0) > 0 or (honor or 0) > 0 then bits[#bits + 1] = ns.Num(hk or 0) .. " HKs · " .. ns.Num(honor or 0) .. " honor" end
      -- (1.4.58) not when it's the card's own faction (its rate is up top, its total in the rep box)
      if fac and not (wf and wf.name == fac) then bits[#bits + 1] = "+" .. ns.Num(repN) .. " " .. ns.ShortFaction(fac) end
      if (s.bosses or 0) > 0 then bits[#bits + 1] = ns.Plural(s.bosses, "boss", "bosses") end
      if gold and gold ~= 0 then bits[#bits + 1] = ns.Colorize(goldText(gold), gold > 0 and C.text2 or C.red) end
      -- (1.4.66) the session's honor, rep and gold are in the boxes above; only what they don't show
      local extra = {}
      if (s.bosses or 0) > 0 then extra[#extra + 1] = ns.Plural(s.bosses, "boss", "bosses") .. " this session" end
      if #extra > 0 then rows[#rows + 1] = dim(table.concat(extra, " · ")) end
    else
    local rested = ns.Pct(d.rested or 0, d.xpMax)
    rows[#rows + 1] = dim("This session: ") .. s.quests .. " quests · " .. s.mobs .. " mobs"
      .. (gold and gold ~= 0 and (" · " .. ns.Colorize(goldText(gold), gold > 0 and C.text2 or C.red)) or "")
      .. ((rested and rested > 0 and f.meter.pct) and dim("   rested " .. rested .. " %") or "")
    end
    -- (1.4.0) what you gathered, with its Market value
    local g = s.gather
    if g and g.n > 0 then
      rows[#rows + 1] = dim("Gathered: ") .. ns.Num(g.n) .. (g.value > 0 and (dim("  ≈ ") .. goldText(g.value)) or "")
    end
    if dg then
      rows[#rows + 1] = ns.Colorize("! " .. dg.name .. " nearby", C.red) .. dim("  killed the gang " .. dg.n .. "× · revenge counts")
    end

  elseif mode == "dungeon" or mode == "raid" then
    local r, pr = P:Run()
    if r then
      local n, total, list = ns.Bosses:Count(r.name, r.killed)
      track = {}
      for _, b in ipairs(list) do if b.killed or not b.opt then track[#track + 1] = b end end
      local nextB = ns.Bosses:Next(r.name, r.killed)
      -- (1.4.73) option A: the track on its own row; next boss + pace, then deaths + your last split
      f.trackFull = true
      f.rowsRight = {}
      local _, wing = ns.Bosses:For(r.name, r.killed, true)
      f.head:SetText((r.name .. (wing and (" · " .. wing) or "")):upper())
      -- (1.4.76) the pull timer: running → "Pull in 4", idle → "Pull" for the leader or the tank in a group
      local X = ns.Extras
      if X.pullEnds and GetTime() < X.pullEnds + 2 then
        local left = X.pullEnds - GetTime()
        f.pullText, f.pullLive = (left > 0.05 and ("Pull in " .. math.ceil(left)) or "Pull!"), true
      elseif ns.db.settings.dgPull ~= false and (ns.S(GetNumGroupMembers) or 0) > 0 and X.CanPull and X.CanPull() and not ns.Extras.inEncounter then
        f.pullText = "Pull"
      end
      if r.baronEnds then
        local left = r.baronEnds - ns.Now()
        if left > 0 and not (r.killed and r.killed["Baron Rivendare"]) then
          f.baronText = "Baron " .. string.format("%d:%02d", math.floor(left / 60), left % 60)
        end
      end
      if mode == "dungeon" then
        rows = N:DungeonRows(f, r, pr, rows)
        if f.doorData then track = nil end
      elseif ns.Extras.inEncounter then
        rows[#rows + 1] = ns.Colorize("Boss fight", C.amber) .. dim("  · gang news waits until it's dead")
      elseif nextB then
        rows[#rows + 1] = dim("Next  ") .. ns.Colorize(nextB, C.text)
      else
        rows[#rows + 1] = n > 0 and ns.Colorize("All bosses down", C.green) or dim("No boss yet")
      end
      if mode == "dungeon" then
        -- (pace and deaths are on the two lines above)
      else
        local gang = ns.Extras.GangInGroup and ns.Extras.GangInGroup() or {}
        local size = ns.S(GetNumGroupMembers) or 0
        rows[#rows + 1] = dim("Gang here  ") .. #gang .. (size > 0 and dim(" of " .. size) or "")
        local gl = r.gangLoot or {}
        if #gl > 0 then
          local who, seen = {}, {}
          for _, g in ipairs(gl) do if not seen[g.who] then seen[g.who] = true who[#who + 1] = g.who end end
          rows[#rows + 1] = dim("Gang loot tonight  ") .. ns.Colorize(ns.Plural(#gl, "epic"), "A335EE") .. dim("  · " .. table.concat(who, ", "))
        end
      end
      -- deaths and wipes: the funny bit (a dungeon has them on its second line)
      if mode ~= "dungeon" then
        local most, mostN = nil, 0
        for name, k in pairs(r.deathsBy or {}) do if k > mostN then most, mostN = name, k end end
        rows[#rows + 1] = dim("Deaths  ") .. (r.deaths or 0) .. ((most and mostN > 1) and dim("  · most: ") .. most .. " " .. mostN or "")
          .. dim("   ·   wipes ") .. (r.wipes or 0)
      end
    end
    if mode == "dungeon" then
      -- (1.4.76) the loot line is built in N:DungeonRows
    else
      -- your own raid prep
      local prep = {}
      if r and tostring(r.name):find("Molten") and UnitResistance then
        local ok, _, total = pcall(UnitResistance, "player", 2)
        if ok and type(total) == "number" and not ns.isSecret(total) then prep[#prep + 1] = "fire resist " .. total end
      end
      if (ns.S(UnitLevel, "player") or 0) >= 60 then
        local fl = hasFlask()
        if fl == false then prep[#prep + 1] = ns.Colorize("no flask", C.amber) elseif fl then prep[#prep + 1] = ns.Colorize("flask", C.green) end
      end
      local saved = savedTo()
      if #saved > 0 then prep[#prep + 1] = "saved: " .. table.concat(saved, ", ") end
      if #prep > 0 then rows[#rows + 1] = dim("You  ") .. table.concat(prep, dim(" · ")) end
    end
    -- your own bags and durability, only when low
    local warn = {}
    local free = freeBags()
    if free < 4 then warn[#warn + 1] = ns.Colorize(free .. " bag slot" .. (free == 1 and "" or "s") .. " left", C.red) end
    local dura = ns.Durability and ns.Durability()
    if dura and dura < 50 then warn[#warn + 1] = ns.Colorize(math.floor(dura) .. " % durability", dura < 20 and C.red or C.amber) end
    if #warn > 0 then rows[#rows + 1] = table.concat(warn, dim("   ·   ")) end
    if mode == "dungeon" then
      f.showBtn = true
      f.lastBoss = r and r.lastBoss or nil
    end

  elseif mode == "bg" then
    local b = P.bg
    local kills = P:BGNumbers()
    local me = b and b.me
    local hk = me and me.hk or kills
    f.big:SetText(tostring(hk or 0))
    -- (1.4.55) HKs and deaths, always both, so the line keeps its shape (no kill streak)
    local deaths = (me and me.deaths) or (b and b.deaths) or 0
    f.bigSub:SetText("HKs  ·  " .. ns.Plural(deaths, "death"))
    f.right:SetText("")
    -- (1.4.34) the bar shows the battleground's reputation instead of XP
    local rep = P:BGRep()
    if rep then
      -- (1.4.68) the faction goes up in the card's title ("ALTERAC VALLEY · FROSTWOLF"); the right
      -- side keeps only the standing and the numbers
      f.head:SetText(((b and b.name or ns.S(GetInstanceInfo) or "Battleground") .. " · " .. rep.short):upper())
      if rep.exalted then
        f.meter.pct = 1
        f.right:SetText("Exalted")
      else
        local span = math.max(1, (rep.max or 0) - (rep.min or 0))
        f.meter.pct = math.max(0, math.min(1, ((rep.value or 0) - (rep.min or 0)) / span))
        f.right:SetText(rep.standing .. " · " .. ns.Num((rep.value or 0) - (rep.min or 0)) .. " / " .. ns.Num(span))
        -- (1.4.48) rep left and the average per win are in the tooltip (hover the card)
      end
    end
    local t = P.Today()
    -- (1.4.48) today in this battleground only, from the recorded games
    local st = P.PvPStats("today")
    local here = st[P.BGKey(b and b.name or ns.S(GetInstanceInfo))]
    if here then
      -- (1.4.55) just the games won here today: honor and streak read as totals, which they weren't
      rows[#rows + 1] = dim("Today  ") .. here.won .. " / " .. here.played .. " won"
    end
    if dg then rows[#rows + 1] = ns.Colorize("Revenge: " .. dg.name .. " is here", C.green) .. dim("  killed the gang " .. dg.n .. "×") end
  end
  -- (1.4.66) every card has a title in its strip
  if (f.head:GetText() or "") == "" then
    local r = P.Run and select(1, P:Run())
    local bgName = P.bg and P.bg.name
    local lvl = ns.S(UnitLevel, "player")
    local t
    if mode == "bg" then t = bgName or "Battleground"
    elseif (mode == "dungeon" or mode == "raid") and r then t = r.name
    elseif type(lvl) == "number" and lvl < 60 then t = "Level " .. lvl
    else t = "Now" end
    f.head:SetText(tostring(t):upper())
  end
  place(f, rows, track)
  if self.lastH ~= math.floor(f:GetHeight()) then
    self.lastH = math.floor(f:GetHeight())
    if ns.Overlays.UpdateGroup then ns.Overlays:UpdateGroup() end
  end
end

function N:Tooltip(owner)
  local P = ns.Pulse
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  local mode = P:Mode()
  GameTooltip:AddLine(P.MODES[mode] .. (mode ~= "world" and (" · " .. P:Place()) or ""), 1, 1, 1)
  if mode == "dungeon" or mode == "raid" then
    GameTooltip:AddLine("Next boss, the boss track (green = killed, bright = next – hover it for the list), deaths and wipes", 0.6, 0.63, 0.66, true)
  end
  if mode == "dungeon" or mode == "raid" then
    local r, pr = P:Run()
    if pr and #pr.items > 0 then
      GameTooltip:AddLine("Loot this run", 0.6, 0.63, 0.66)
      for i = #pr.items, math.max(1, #pr.items - 9), -1 do GameTooltip:AddLine(pr.items[i]) end
    end
    if r and r.gangLoot and #r.gangLoot > 0 then
      GameTooltip:AddLine("Gang epics", 0.6, 0.63, 0.66)
      for i = #r.gangLoot, math.max(1, #r.gangLoot - 9), -1 do GameTooltip:AddDoubleLine(r.gangLoot[i].link, r.gangLoot[i].who, 1, 1, 1, 0.6, 0.63, 0.66) end
    end
    if r then
      local most = {}
      for name, k in pairs(r.deathsBy or {}) do most[#most + 1] = { name = name, k = k } end
      table.sort(most, function(a, b) return a.k > b.k end)
      if #most > 0 then
        GameTooltip:AddLine("Deaths", 0.6, 0.63, 0.66)
        for i = 1, math.min(5, #most) do GameTooltip:AddDoubleLine(most[i].name, tostring(most[i].k), 1, 1, 1, 1, 1, 1) end
      end
    end
  elseif mode == "world" then
    local d = ns.Tracker:S3Data() or {}
    GameTooltip:AddLine("Session " .. ns.Duration(d.sessSec or 0), 0.6, 0.63, 0.66)
  elseif mode == "bg" then
    -- (1.4.48) the details that left the card
    local rep = P:BGRep()
    if rep and not rep.exalted then
      GameTooltip:AddDoubleLine(rep.short, ns.Num(rep.left or 0) .. " rep left", 1, 1, 1, 1, 1, 1)
      if (rep.wN or 0) > 0 then GameTooltip:AddDoubleLine("Average per win", "+" .. ns.Num(rep.avgW) .. " (" .. ns.Plural(rep.wN, "win") .. ")", 0.6, 0.63, 0.66, 1, 1, 1) end
      if (rep.game or 0) > 0 then GameTooltip:AddDoubleLine("This game", "+" .. ns.Num(rep.game), 0.6, 0.63, 0.66, 0.4, 0.85, 0.5) end
    end
    local wk, rank, prog = P:Week()
    if wk then GameTooltip:AddDoubleLine("This week", ns.Num(wk) .. " honor", 0.6, 0.63, 0.66, 1, 1, 1) end
    if rank then GameTooltip:AddDoubleLine("Rank", rank .. (prog and (" " .. prog .. " %") or ""), 0.6, 0.63, 0.66, 1, 1, 1) end
  end
  GameTooltip:AddLine(N.moment and "Click: close" or "Click: the Stats page", 0.52, 0.55, 0.57)
  GameTooltip:Show()
end

-- (1.4.73) the Baron run: when Baron Rivendare first yells in Stratholme the 45 minutes start
ns:On("CHAT_MSG_MONSTER_YELL", function(text, sender)
  if ns.isSecret(sender) or type(sender) ~= "string" or not sender:find("Rivendare", 1, true) then return end
  local r = ns.Pulse and ns.Pulse.Run and select(1, ns.Pulse:Run())
  if r and tostring(r.name):find("Stratholme", 1, true) and not r.baronEnds then
    r.baronEnds = ns.Now() + 45 * 60
  end
end)
