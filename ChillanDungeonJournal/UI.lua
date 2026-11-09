-- Chillan? Dungeon Journal – the window: dungeon list, Overview / Quests / Map / Bosses
local ADDON, ns = ...
local C, hex = ns.C, ns.hex

local UI = {}
ns.UI = UI
local updaters = {}   -- functions run on every Refresh (quest status, kills, gang)

---------------------------------------------------------------------------
-- small widgets
---------------------------------------------------------------------------
local function Text(parent, size, weight, color, wrap)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  local font = weight == "bold" and ns.FONT_BOLD or (weight == "semi" and ns.FONT_SEMI or ns.FONT)
  if not fs:SetFont(font, size or 13, "") then fs:SetFont(STANDARD_TEXT_FONT, size or 13, "") end
  fs:SetTextColor(hex(color or C.text))
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(wrap and true or false)
  return fs
end

local function Panel(parent, fill, line)
  local f = CreateFrame("Frame", nil, parent)
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints()
  function f:SetColors(fl, ln)
    if fl then self.bg:SetColorTexture(hex(fl)) self.bg:Show() else self.bg:Hide() end
    if not self.edges then
      self.edges = {}
      for i = 1, 4 do self.edges[i] = self:CreateTexture(nil, "BORDER") end
      local e = self.edges
      e[1]:SetPoint("TOPLEFT") e[1]:SetPoint("TOPRIGHT") e[1]:SetHeight(1)
      e[2]:SetPoint("BOTTOMLEFT") e[2]:SetPoint("BOTTOMRIGHT") e[2]:SetHeight(1)
      e[3]:SetPoint("TOPLEFT") e[3]:SetPoint("BOTTOMLEFT") e[3]:SetWidth(1)
      e[4]:SetPoint("TOPRIGHT") e[4]:SetPoint("BOTTOMRIGHT") e[4]:SetWidth(1)
    end
    for _, t in ipairs(self.edges) do
      if ln then t:SetColorTexture(hex(ln)) t:Show() else t:Hide() end
    end
  end
  f:SetColors(fill, line)
  return f
end

local STYLES = {
  primary = { fill = C.accent, line = nil, text = "16171B", hover = "D6AD80" },
  secondary = { fill = C.cardHover, line = C.line2, text = C.text, hover = "2C2F36" },
  ghost = { fill = nil, line = C.line, text = C.text2, hover = C.card },
  tab = { fill = nil, line = nil, text = C.dim, hover = nil },
}
local function Button(parent, w, h, label, style, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)
  b.style = STYLES[style or "secondary"]
  b.panel = Panel(b, b.style.fill, b.style.line)
  b.panel:SetAllPoints()
  b.panel:SetFrameLevel(b:GetFrameLevel())
  b.label = Text(b, 12, "semi", b.style.text)
  b.label:SetPoint("CENTER")
  b.label:SetText(label or "")
  b:SetScript("OnEnter", function(self)
    if self.style.hover then self.panel:SetColors(self.style.hover, self.style.line) end
    if self.tip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(self.tip, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(self) self.panel:SetColors(self.style.fill, self.style.line) GameTooltip:Hide() end)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

local function Pill(parent)
  local p = Panel(parent, nil, nil)
  p:SetHeight(18)
  p.text = Text(p, 10, "semi", C.text)
  p.text:SetPoint("CENTER")
  function p:Set(label, color, outline)
    self.text:SetText(label)
    self.text:SetTextColor(hex(color))
    local r, g, b = hex(color)
    if outline then
      self:SetColors(nil, C.line2)
    else
      self.bg:SetColorTexture(r, g, b, 0.16) self.bg:Show()
      if self.edges then for _, t in ipairs(self.edges) do t:Hide() end end
    end
    self:SetWidth(self.text:GetStringWidth() + 14)
    self:Show()
  end
  return p
end

local function Line(parent)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture(hex(C.line))
  return t
end

-- small coloured circle inside text
local function dotText(color)
  local r, g, b = hex(color)
  return string.format("|T%sCircle:10:10:0:0:64:64:0:64:0:64:%d:%d:%d|t", ns.TEX, r * 255, g * 255, b * 255)
end

local function Dot(parent, size, color)
  local t = parent:CreateTexture(nil, "OVERLAY")
  t:SetTexture(ns.TEX .. "Circle")
  t:SetSize(size, size)
  t:SetVertexColor(hex(color))
  return t
end

-- my quest status as a pill
local function setStatus(pill, q)
  if q.talk then pill:Hide() return end
  local st, prog = ns.MyQuestStatus(q)
  if st == "done" then pill:Set("Done", C.blue)
  elseif st == "ready" then pill:Set("Ready to turn in", C.green)
  elseif st == "log" then pill:Set("In log" .. ((prog and prog ~= "") and (" · " .. prog) or ""), C.green)
  else pill:Set("Not picked up", C.dim, true) end
end

-- gang names (from Chillan?) for a quest
local function gangText(q)
  if q.talk then return "" end
  local list = ns.GangWithQuest(q)
  if #list == 0 then return "" end
  local parts = {}
  for i, g in ipairs(list) do
    if i > 4 then parts[#parts + 1] = ns.Colorize("+" .. (#list - 4), C.dim) break end
    parts[#parts + 1] = ns.Colorize(g.name, g.online and g.hex or C.dim)
  end
  return "Gang: " .. table.concat(parts, ns.Colorize(", ", C.dim))
end

local function mapFor(d, key)
  if key == "tb" then return ns.FindMap(d.tbMap.names, d.tbMap.hint) end
  return ns.FindMap(d.zoneMap.names, d.zoneMap.hint)
end

local function wpButton(parent, d, wp, label)
  local b = Button(parent, 26, 22, "", "ghost", function()
    local id = mapFor(d, wp.map)
    if ns.SetWaypoint(id, wp.x, wp.y, label) then ns.OpenWorldMap(id) end
  end)
  b.icon = b:CreateTexture(nil, "OVERLAY")
  b.icon:SetTexture(ns.TEX .. "IconMap")
  b.icon:SetSize(14, 14)
  b.icon:SetPoint("CENTER")
  b.icon:SetVertexColor(hex(C.accent))
  b.tip = "Set a waypoint: " .. (label or "")
  return b
end

---------------------------------------------------------------------------
-- window
---------------------------------------------------------------------------
local W, H = 1100, 700
local LIST_W = 250

function UI:Create()
  if self.frame then return end
  local d = ns.DUNGEONS[1]
  self.dungeon = d
  local f = CreateFrame("Frame", "ChillanDJFrame", UIParent)
  f:SetSize(W, H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f.panel = Panel(f, C.window, C.line)
  f.panel:SetAllPoints()
  f.panel:SetFrameLevel(f:GetFrameLevel())
  tinsert(UISpecialFrames, "ChillanDJFrame")
  self.frame = f

  -- title bar
  local title = Text(f, 18, "bold", C.text)
  title:SetPoint("TOPLEFT", 18, -16)
  title:SetText("Chillan" .. ns.Colorize("?", C.accent) .. " Dungeon Journal")
  local ver = Text(f, 11, nil, C.dim)
  ver:SetPoint("LEFT", title, "RIGHT", 10, -1)
  ver:SetText("demo v" .. ns.VERSION .. (ns.HasChillan() and "" or "  ·  Chillan? not found – no gang info"))
  local close = Button(f, 28, 28, "", "ghost", function() f:Hide() end)
  close:SetPoint("TOPRIGHT", -12, -12)
  close.panel:SetColors(nil, nil)
  close.style = { text = C.dim, hover = C.card }
  close.icon = close:CreateTexture(nil, "OVERLAY")
  close.icon:SetTexture(ns.TEX .. "IconClose")
  close.icon:SetSize(14, 14)
  close.icon:SetPoint("CENTER")
  close.icon:SetVertexColor(hex(C.text2))
  local hl = Line(f)
  hl:SetPoint("TOPLEFT", 0, -52) hl:SetPoint("TOPRIGHT", 0, -52) hl:SetHeight(1)

  -- dungeon list
  local list = CreateFrame("Frame", nil, f)
  list:SetPoint("TOPLEFT", 0, -53)
  list:SetPoint("BOTTOMLEFT", 0, 0)
  list:SetWidth(LIST_W)
  local vl = Line(f)
  vl:SetPoint("TOPLEFT", LIST_W, -53) vl:SetPoint("BOTTOMLEFT", LIST_W, 0) vl:SetWidth(1)
  self:BuildList(list, d)

  -- content
  local body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", LIST_W + 1, -53)
  body:SetPoint("BOTTOMRIGHT", 0, 0)
  self.body = body

  local name = Text(body, 24, "bold", C.text)
  name:SetPoint("TOPLEFT", 22, -18)
  name:SetText(d.name)
  local info = Text(body, 12, nil, C.text2)
  info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
  info:SetText(string.format("%s · %s (%.1f, %.1f) · level %d–%d · entry from %d · Group Finder from %d · %d players",
    d.zone, d.where, d.entrance.x * 100, d.entrance.y * 100, d.levels[1], d.levels[2], d.entry, d.finder, d.size))

  local wp = Button(body, 160, 32, "Waypoint to entrance", "secondary", function()
    local id = mapFor(d, "zone")
    if ns.SetWaypoint(id, d.entrance.x, d.entrance.y, d.name .. " entrance") then ns.OpenWorldMap(id) end
  end)
  wp:SetPoint("TOPRIGHT", -22, -22)
  local open = Button(body, 150, 32, "Open on world map", "ghost", function() ns.OpenWorldMap(ns.Map:MapID(d)) end)
  open:SetPoint("RIGHT", wp, "LEFT", -8, 0)

  -- tabs
  self.tabs, self.pages = {}, {}
  local tabY = -82
  local prev
  for _, def in ipairs({ { "overview", "Overview" }, { "quests", "Quests " .. (#d.allQuests - 1) }, { "map", "Map" }, { "bosses", "Bosses " .. #d.bosses } }) do
    local b = Button(body, 10, 32, def[2], "tab", function() UI:Select(def[1]) end)
    b:SetWidth(b.label:GetStringWidth() + 24)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 2, 0) else b:SetPoint("TOPLEFT", 14, tabY) end
    b.bar = b:CreateTexture(nil, "OVERLAY")
    b.bar:SetColorTexture(hex(C.accent))
    b.bar:SetHeight(2)
    b.bar:SetPoint("BOTTOMLEFT", 6, 0) b.bar:SetPoint("BOTTOMRIGHT", -6, 0)
    self.tabs[def[1]] = b
    prev = b
  end
  local tl = Line(body)
  tl:SetPoint("TOPLEFT", 22, tabY - 32) tl:SetPoint("TOPRIGHT", -22, tabY - 32) tl:SetHeight(1)

  local function page(key)
    local p = CreateFrame("Frame", nil, body)
    p:SetPoint("TOPLEFT", 22, tabY - 46)
    p:SetPoint("BOTTOMRIGHT", -22, 18)
    p:Hide()
    self.pages[key] = p
    return p
  end
  self:BuildOverview(page("overview"), d)
  self:BuildQuests(page("quests"), d)
  self:BuildMap(page("map"), d)
  self:BuildBosses(page("bosses"), d)
  f:SetScript("OnShow", function() UI:Refresh() end)
  self:Select("overview")
  f:Hide()
end

function UI:Select(key)
  self.current = key
  for k, b in pairs(self.tabs) do
    local on = k == key
    b.label:SetTextColor(hex(on and C.text or C.dim))
    b.bar:SetShown(on)
  end
  for k, p in pairs(self.pages) do p:SetShown(k == key) end
  self:Refresh()
end

function UI:Refresh()
  if not self.frame or not self.frame:IsShown() then return end
  for _, fn in ipairs(updaters) do pcall(fn) end
  local d = self.dungeon
  if self.current == "map" and self.bigMap then self.bigMap:Show2(d) end
  if self.current == "overview" and self.smallMap then self.smallMap:Show2(d) end
end

function UI:Toggle()
  self:Create()
  if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end

---------------------------------------------------------------------------
-- left list
---------------------------------------------------------------------------
local function sectionLabel(parent, text, y)
  local t = Text(parent, 10, "semi", C.dim)
  t:SetPoint("TOPLEFT", 16, y)
  t:SetText(text)
  return t
end

function UI:BuildList(list, d)
  local y = -18
  sectionLabel(list, "READY IN THIS DEMO", y)
  y = y - 20
  local card = Panel(list, C.cardHover, C.accent)
  card:SetPoint("TOPLEFT", 12, y)
  card:SetPoint("TOPRIGHT", -12, y)
  card:SetHeight(74)
  local n = Text(card, 14, "semi", C.text)
  n:SetPoint("TOPLEFT", 12, -11)
  n:SetText(d.name)
  local lv = Text(card, 11, "semi", C.green)
  lv:SetPoint("TOPRIGHT", -12, -12)
  lv:SetText(d.levels[1] .. "–" .. d.levels[2])
  local s1 = Text(card, 11, nil, C.text2)
  s1:SetPoint("TOPLEFT", n, "BOTTOMLEFT", 0, -6)
  s1:SetText(d.zone .. " · " .. #d.bosses .. " bosses · " .. (#d.allQuests - 1) .. " quests")
  local s2 = Text(card, 11, nil, C.amber)
  s2:SetPoint("TOPLEFT", s1, "BOTTOMLEFT", 0, -5)
  updaters[#updaters + 1] = function()
    local inRange = ns.GangInRange(d.levels[1], d.levels[2])
    s2:SetText(inRange and (inRange .. " friends in level range") or "Install Chillan? to see the gang")
  end
  y = y - 74 - 22
  sectionLabel(list, "COMING LATER", y)
  y = y - 22
  for _, c in ipairs(ns.COMING) do
    local t = Text(list, 12, nil, C.dim)
    t:SetPoint("TOPLEFT", 16, y)
    t:SetText(c.name .. (c.new and ns.Colorize("  NEW", C.blue) or ""))
    local l = Text(list, 11, nil, C.dim)
    l:SetPoint("TOPRIGHT", list, "TOPRIGHT", -16, y)
    l:SetJustifyH("RIGHT")
    l:SetText(c.levels)
    y = y - 26
  end
end

---------------------------------------------------------------------------
-- Overview
---------------------------------------------------------------------------
function UI:BuildOverview(p, d)
  local RIGHT_W = 300
  local left = CreateFrame("Frame", nil, p)
  left:SetPoint("TOPLEFT")
  left:SetPoint("BOTTOMRIGHT", -RIGHT_W - 20, 0)

  local mapBox = Panel(left, "1A1C20", C.line)
  mapBox:SetPoint("TOPLEFT") mapBox:SetPoint("TOPRIGHT")
  mapBox:SetHeight(250)
  local mv = ns.Map:Create(mapBox, { small = true })
  mv:SetPoint("TOPLEFT", 1, -1) mv:SetPoint("BOTTOMRIGHT", -1, 1)
  self.smallMap = mv
  local go = Button(mapBox, 110, 24, "Open big map ›", "secondary", function() UI:Select("map") end)
  go:SetPoint("BOTTOMRIGHT", -8, 8)
  go:SetFrameLevel(mv:GetFrameLevel() + 20)

  -- 4 number cards
  local cards = {}
  for i = 1, 4 do
    local c = Panel(left, C.card, C.line)
    c:SetHeight(62)
    c.v = Text(c, 18, "bold", C.text)
    c.v:SetPoint("TOPLEFT", 12, -10)
    c.k = Text(c, 11, nil, C.text2)
    c.k:SetPoint("TOPLEFT", c.v, "BOTTOMLEFT", 0, -4)
    cards[i] = c
  end
  left:SetScript("OnSizeChanged", function(self, w)
    local cw = (w - 3 * 10) / 4
    for i, c in ipairs(cards) do
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", mapBox, "BOTTOMLEFT", (i - 1) * (cw + 10), -12)
      c:SetWidth(cw)
    end
  end)
  updaters[#updaters + 1] = function()
    local inLog, done = 0, 0
    for _, q in ipairs(d.allQuests) do
      local st = ns.MyQuestStatus(q)
      if st == "log" or st == "ready" then inLog = inLog + 1 elseif st == "done" then done = done + 1 end
    end
    cards[1].v:SetText(#d.bosses) cards[1].k:SetText("bosses (1 rare)")
    cards[2].v:SetText(#d.allQuests - 1) cards[2].k:SetText("quests · " .. #d.chains .. " chains")
    cards[3].v:SetText(inLog .. " in log") cards[3].v:SetTextColor(hex(inLog > 0 and C.amber or C.text))
    cards[3].k:SetText(done .. " already done")
    cards[4].v:SetText(d.clear) cards[4].k:SetText("typical full clear")
  end

  local bl = Text(left, 10, "semi", C.dim)
  bl:SetPoint("TOPLEFT", mapBox, "BOTTOMLEFT", 0, -90)
  bl:SetText("BEFORE YOU GO")
  local y = -108
  for _, tip in ipairs(d.tips) do
    local r = Panel(left, C.card, C.line)
    r:SetPoint("TOPLEFT", mapBox, "BOTTOMLEFT", 0, y)
    r:SetPoint("TOPRIGHT", mapBox, "BOTTOMRIGHT", 0, y)
    r:SetHeight(36)
    local dot = Dot(r, 8, C[tip.color] or C.amber)
    dot:SetPoint("LEFT", 12, 0)
    local t = Text(r, 12, nil, C.text)
    t:SetPoint("LEFT", dot, "RIGHT", 10, 0)
    t:SetPoint("RIGHT", -12, 0)
    t:SetText(tip.text)
    y = y - 42
  end

  -- bosses in order
  local right = CreateFrame("Frame", nil, p)
  right:SetPoint("TOPRIGHT")
  right:SetPoint("BOTTOMRIGHT")
  right:SetWidth(RIGHT_W)
  local h = Text(right, 10, "semi", C.dim)
  h:SetPoint("TOPLEFT", 0, 0)
  h:SetText("BOSSES IN ORDER")
  local ry = -20
  for _, b in ipairs(d.bosses) do
    local row = CreateFrame("Button", nil, right)
    row:SetPoint("TOPLEFT", 0, ry)
    row:SetPoint("TOPRIGHT", 0, ry)
    row:SetHeight(30)
    local num = Dot(row, 22, b.rare and C.line2 or (b.final and C.red or C.accent))
    num:SetPoint("LEFT", 2, 0)
    local nt = Text(row, 11, "bold", b.rare and C.text or "16171B")
    nt:SetPoint("CENTER", num, "CENTER", 0, 0)
    nt:SetText(tostring(b.n))
    local nm = Text(row, 13, nil, C.text)
    nm:SetPoint("LEFT", num, "RIGHT", 10, 0)
    nm:SetText(b.name)
    local tag = Text(row, 11, nil, b.rare and C.purple or (b.quest and C.amber or C.dim))
    tag:SetPoint("RIGHT", -2, 0)
    tag:SetJustifyH("RIGHT")
    tag:SetText(b.rare and "rare" or (b.quest and (b.quest:find("^Gem") and "gem" or (b.quest:find("Shard") and "Glowing Shard" or "hide")) or ""))
    local chk = row:CreateTexture(nil, "OVERLAY")
    chk:SetTexture(ns.TEX .. "IconCheck")
    chk:SetSize(14, 14)
    chk:SetVertexColor(hex(C.green))
    chk:SetPoint("LEFT", nm, "RIGHT", 6, 0)
    updaters[#updaters + 1] = function() chk:SetShown(ns.killed[b.name] and true or false) end
    row:SetScript("OnClick", function() UI:Select("bosses") end)
    ry = ry - 32
  end
  local note = Text(right, 11, nil, C.dim, true)
  note:SetPoint("TOPLEFT", 0, ry - 6)
  note:SetWidth(RIGHT_W)
  note:SetText("Mutanus only appears after you escort the Disciple of Naralex to the ritual stone in the last room.")
end

---------------------------------------------------------------------------
-- Quests (scrolls)
---------------------------------------------------------------------------
function UI:BuildQuests(p, d)
  local scroll = CreateFrame("ScrollFrame", nil, p)
  scroll:SetAllPoints()
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(780, 900)
  scroll:SetScrollChild(content)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local max = math.max(0, content:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 50)))
  end)
  scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)

  local legend = Text(content, 11, nil, C.text2)
  legend:SetPoint("TOPLEFT", 0, 0)
  legend:SetText("Your status on each quest · " .. ns.Colorize("Gang:", C.dim) .. " friends who have it in their log (online in class colour) · map icon = waypoint")

  local y = -26
  local h = Text(content, 10, "semi", C.dim)
  h:SetPoint("TOPLEFT", 0, y)
  h:SetText("CHAINS – DO THE STEPS IN ORDER")
  y = y - 18

  local steps = {}
  for _, ch in ipairs(d.chains) do
    local card = Panel(content, C.card, C.line)
    card:SetPoint("TOPLEFT", 0, y)
    card:SetPoint("TOPRIGHT", 0, y)
    card:SetHeight(150)
    local t = Text(card, 14, "semi", C.text)
    t:SetPoint("TOPLEFT", 14, -12)
    t:SetText(ch.name)
    local x = t
    if ch.faction then
      local fp = Pill(card)
      fp:SetPoint("LEFT", t, "RIGHT", 8, 0)
      fp:Set(ch.faction:upper(), C.red, false)
      x = fp
    end
    local nt = Text(card, 12, nil, C.dim)
    nt:SetPoint("LEFT", x, "RIGHT", 10, 0)
    nt:SetText(ch.note)
    -- step cards side by side
    local n = #ch.steps
    local holder = CreateFrame("Frame", nil, card)
    holder:SetPoint("TOPLEFT", 14, -38)
    holder:SetPoint("BOTTOMRIGHT", -14, 12)
    local cells = {}
    for i, s in ipairs(ch.steps) do
      local cell = Panel(holder, C.cardHover, s.inside and C.accent or nil)
      local lab = Text(cell, 11, "bold", C.accent)
      lab:SetPoint("TOPLEFT", 10, -9)
      lab:SetText(i .. (s.level and (" · lvl " .. s.level) or "") .. (s.pre and " · pre-quest" or "") .. (s.inside and " · in the dungeon" or ""))
      local nm = Text(cell, 13, "semi", C.text)
      nm:SetPoint("TOPLEFT", lab, "BOTTOMLEFT", 0, -5)
      nm:SetText(s.name)
      local tx = Text(cell, 11, nil, C.text2, true)
      tx:SetPoint("TOPLEFT", nm, "BOTTOMLEFT", 0, -4)
      tx:SetPoint("RIGHT", -10, 0)
      tx:SetText(s.text)
      local st = Pill(cell)
      st:SetPoint("BOTTOMLEFT", 10, 8)
      local gang = Text(cell, 10, nil, C.text2)
      gang:SetPoint("LEFT", st, "RIGHT", 6, 0)
      gang:SetPoint("RIGHT", -34, 0)
      if s.wp then
        local wb = wpButton(cell, d, s.wp, s.name)
        wb:SetPoint("BOTTOMRIGHT", -6, 6)
      end
      updaters[#updaters + 1] = function() setStatus(st, s) gang:SetText(gangText(s)) end
      cells[i] = cell
    end
    holder:SetScript("OnSizeChanged", function(self, w)
      local gap = 10
      local cw = (w - gap * (n - 1)) / n
      for i, cell in ipairs(cells) do
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", (i - 1) * (cw + gap), 0)
        cell:SetSize(cw, 100)
      end
    end)
    y = y - 160
  end

  y = y - 6
  local h2 = Text(content, 10, "semi", C.dim)
  h2:SetPoint("TOPLEFT", 0, y)
  h2:SetText("SINGLE QUESTS")
  y = y - 18
  for _, q in ipairs(d.singles) do
    local r = Panel(content, C.card, C.line)
    r:SetPoint("TOPLEFT", 0, y)
    r:SetPoint("TOPRIGHT", 0, y)
    r:SetHeight(58)
    local nm = Text(r, 13, "semi", C.text)
    nm:SetPoint("TOPLEFT", 14, -11)
    nm:SetText(q.name .. ns.Colorize("  lvl " .. q.level, C.dim) .. (q.faction and ns.Colorize("  " .. q.faction:upper(), C.red) or ""))
    local tx = Text(r, 11, nil, C.text2)
    tx:SetPoint("TOPLEFT", nm, "BOTTOMLEFT", 0, -5)
    tx:SetText(q.text)
    local st = Pill(r)
    st:SetPoint("RIGHT", q.wp and -46 or -14, 0)
    local gang = Text(r, 11, nil, C.text2)
    gang:SetPoint("RIGHT", st, "LEFT", -10, 0)
    gang:SetJustifyH("RIGHT")
    if q.wp then
      local wb = wpButton(r, d, q.wp, q.name)
      wb:SetPoint("RIGHT", -12, 0)
    end
    updaters[#updaters + 1] = function() setStatus(st, q) gang:SetText(gangText(q)) end
    y = y - 64
  end
  local foot = Text(content, 11, nil, C.dim)
  foot:SetPoint("TOPLEFT", 0, y - 8)
  foot:SetText("Smart Drinks and Deviate Hides often need two runs. /cdj debug lists which quests the addon recognised.")
  content:SetHeight(-y + 40)
end

---------------------------------------------------------------------------
-- Map
---------------------------------------------------------------------------
function UI:BuildMap(p, d)
  local RIGHT_W = 300
  local box = Panel(p, "1A1C20", C.line)
  box:SetPoint("TOPLEFT")
  box:SetPoint("BOTTOMRIGHT", -RIGHT_W - 20, 0)
  local mv = ns.Map:Create(box)
  mv:SetPoint("TOPLEFT", 1, -1) mv:SetPoint("BOTTOMRIGHT", -1, 1)
  self.bigMap = mv

  local legend = Panel(box, C.window, C.line)
  legend:SetPoint("BOTTOMLEFT", 10, 10)
  legend:SetSize(330, 28)
  legend:SetFrameLevel(mv:GetFrameLevel() + 20)
  local lt = Text(legend, 11, nil, C.text2)
  lt:SetPoint("LEFT", 10, 0)
  lt:SetText(dotText(C.accent) .. " boss    " .. dotText(C.purple) .. " rare    " .. dotText(C.red) .. " final    " .. dotText(C.amber) .. " quest target")

  local edit = Button(box, 96, 26, "Edit pins", "secondary")
  edit:SetPoint("TOPRIGHT", -10, -10)
  edit:SetFrameLevel(mv:GetFrameLevel() + 20)
  edit.tip = "Pins are first guesses. Click Edit, click a pin, then click where it really is. /cdj pins prints them so you can send them to Claude."
  edit:SetScript("OnClick", function(self)
    local on = not mv.editing
    mv:SetEditing(on)
    self.label:SetText(on and "Done editing" or "Edit pins")
  end)

  local right = CreateFrame("Frame", nil, p)
  right:SetPoint("TOPRIGHT") right:SetPoint("BOTTOMRIGHT") right:SetWidth(RIGHT_W)

  local c1 = Panel(right, C.card, C.line)
  c1:SetPoint("TOPLEFT") c1:SetPoint("TOPRIGHT")
  c1:SetHeight(196)
  local t1 = Text(c1, 14, "semi", C.text)
  t1:SetPoint("TOPLEFT", 14, -12)
  t1:SetText("Finding the way in")
  local yy = -38
  for i, s in ipairs(d.entranceSteps) do
    local n = Text(c1, 12, "bold", C.accent)
    n:SetPoint("TOPLEFT", 14, yy)
    n:SetText(i)
    local t = Text(c1, 12, nil, C.text2, true)
    t:SetPoint("TOPLEFT", 30, yy)
    t:SetWidth(RIGHT_W - 46)
    t:SetText(s)
    yy = yy - (t:GetStringHeight() + 8)
  end
  local wp = Button(c1, RIGHT_W - 28, 30, "Waypoint to the cave opening", "primary", function()
    local id = mapFor(d, "zone")
    if ns.SetWaypoint(id, d.entrance.x, d.entrance.y, d.name .. " entrance") then ns.OpenWorldMap(id) end
  end)
  wp:SetPoint("BOTTOMLEFT", 14, 12)

  local c2 = Panel(right, C.card, C.line)
  c2:SetPoint("TOPLEFT", c1, "BOTTOMLEFT", 0, -12) c2:SetPoint("TOPRIGHT", c1, "BOTTOMRIGHT", 0, -12)
  c2:SetHeight(44 + #d.givers * 28)
  local t2 = Text(c2, 14, "semi", C.text)
  t2:SetPoint("TOPLEFT", 14, -12)
  t2:SetText("Quest people outside")
  yy = -40
  for _, g in ipairs(d.givers) do
    local n = Text(c2, 12, nil, C.text)
    n:SetPoint("TOPLEFT", 14, yy)
    n:SetText(g.name)
    local w = Text(c2, 11, nil, C.dim)
    w:SetPoint("TOPRIGHT", g.wp and -40 or -14, yy)
    w:SetJustifyH("RIGHT")
    w:SetText(g.where)
    if g.wp then
      local b = wpButton(c2, d, g.wp, g.name)
      b:SetPoint("TOPRIGHT", -10, yy + 4)
    end
    yy = yy - 28
  end

  local help = Text(right, 11, nil, C.dim, true)
  help:SetPoint("TOPLEFT", c2, "BOTTOMLEFT", 0, -12)
  help:SetWidth(RIGHT_W)
  help:SetText("The map is the game's own. Boss pins are placed by us – if one is off, use Edit pins and send Claude the output of /cdj pins.")
end

---------------------------------------------------------------------------
-- Bosses
---------------------------------------------------------------------------
function UI:BuildBosses(p, d)
  local sub = Text(p, 12, nil, C.text2)
  sub:SetPoint("TOPLEFT", 0, 0)
  sub:SetText("The druid lords all cast Lightning Bolt and Sleep · " .. ns.Colorize("gold", C.amber) .. " = quest item · " ..
    ns.Colorize("blue", C.rareBlue) .. " = notable drops · " .. "green tick = killed this run")
  local grid = CreateFrame("Frame", nil, p)
  grid:SetPoint("TOPLEFT", 0, -24)
  grid:SetPoint("BOTTOMRIGHT")
  local cards = {}
  for i, b in ipairs(d.bosses) do
    local c = Panel(grid, C.card, b.final and C.red or (b.rare and C.line2 or C.line))
    local num = Dot(c, 24, b.rare and C.line2 or (b.final and C.red or C.accent))
    num:SetPoint("TOPLEFT", 12, -12)
    local nt = Text(c, 11, "bold", b.rare and C.text or "16171B")
    nt:SetPoint("CENTER", num, "CENTER")
    nt:SetText(tostring(b.n))
    local nm = Text(c, 14, "semi", C.text)
    nm:SetPoint("LEFT", num, "RIGHT", 10, 0)
    nm:SetText(b.name .. (b.rare and ns.Colorize("  RARE", C.purple) or "") .. (b.final and ns.Colorize("  FINAL", C.red) or ""))
    local chk = c:CreateTexture(nil, "OVERLAY")
    chk:SetTexture(ns.TEX .. "IconCheck")
    chk:SetSize(16, 16)
    chk:SetVertexColor(hex(C.green))
    chk:SetPoint("TOPRIGHT", -12, -14)
    updaters[#updaters + 1] = function() chk:SetShown(ns.killed[b.name] and true or false) end
    local w = Text(c, 12, nil, C.text2, true)
    w:SetPoint("TOPLEFT", 12, -44)
    w:SetPoint("RIGHT", -12, 0)
    w:SetText(b.where)
    local q = Text(c, 11, nil, C.amber, true)
    q:SetPoint("TOPLEFT", w, "BOTTOMLEFT", 0, -6)
    q:SetPoint("RIGHT", -12, 0)
    q:SetText(b.quest or "")
    local l = Text(c, 11, nil, C.rareBlue, true)
    l:SetPoint("BOTTOMLEFT", 12, 10)
    l:SetPoint("RIGHT", -12, 0)
    l:SetText(b.loot and table.concat(b.loot, " · ") or "")
    cards[i] = c
  end
  grid:SetScript("OnSizeChanged", function(self, w, h)
    local gap = 12
    local cw, ch = (w - 2 * gap) / 3, (h - 2 * gap) / 3
    for i, c in ipairs(cards) do
      local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", col * (cw + gap), -row * (ch + gap))
      c:SetSize(cw, ch)
    end
  end)
end
