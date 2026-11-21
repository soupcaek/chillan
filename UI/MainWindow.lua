-- Chillan? – the main window: sections across the top, pages inside
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex
local W = { tabDefs = {}, tabs = {}, navButtons = {} }
ns.Window = W

function ns:RegisterTab(key, label, icon, build, hidden)
  table.insert(W.tabDefs, { key = key, label = label, icon = icon, build = build, hidden = hidden })
end

-- Åpne achievements for en person
function W:OpenAch(pid)
  self:Create()
  if not self.frame:IsShown() then self.frame:Show() end
  self.achPid = pid
  self:Select("ach")
end

-- Åpne spillersiden for en person
function W:OpenPlayer(pid)
  self:Create()
  if not self.frame:IsShown() then self.frame:Show() end
  self.returnTo = (self.current ~= "player") and self.current or (self.returnTo or "friends")
  self.playerPid = pid
  self:Select("player")
end

local WIDTH, HEIGHT, TITLE_H, PAGEBAR_H = 860, 560, 48, 38
local MIN_W, MIN_H = 780, 500

-- Five sections; each opens its pages. Settings and What's new sit in the header.
W.SECTIONS = {
  { key = "home", label = "Home", pages = { "home" } },
  { key = "gang", label = "Gang", pages = { "friends", "cunts", "diedto", "more" }, hidden = { "player", "compare" } },
  { key = "chat", label = "Chat", pages = { "chat" } },
  { key = "progress", label = "Progress", pages = { "stats", "graph", "titles", "ach", "history", "legend" } },
  { key = "market", label = "Market", pages = { "market" } },
  { key = "tools", label = "Tools", pages = { "qol", "ideas" } },
  { key = "settings", label = "Settings", pages = { "settings" }, header = true },
  { key = "changelog", label = "What's new", pages = { "changelog" }, header = true },
}
W.PAGE_LABELS = { home = "Home", friends = "Friends", cunts = "Cunt List", diedto = "Died to", more = "Crafters", chat = "Gang chat",
  stats = "Overview", graph = "Chart", titles = "Titles", history = "History", legend = "Legend book", ach = "Trophies", market = "Market", qol = "QoL helpers", ideas = "Idea box", settings = "Settings", changelog = "What's new",
  player = "Player", compare = "Compare" }
W.lastPage = {}
-- (1.1.7) Progress is one row of pages; Chart, Titles, History and Legend book live inside the Stats page
W.VIRTUAL = { graph = { "stats", "graph" }, titles = { "stats", "titles" }, history = { "stats", "history" }, legend = { "stats", "legend" } }
local function realOf(key) local v = W.VIRTUAL[key] return v and v[1] or key end
local function has(list, v) for _, x in ipairs(list or {}) do if x == v then return true end end return false end

function W:SectionOf(key)
  for _, sec in ipairs(self.SECTIONS) do
    for _, p in ipairs(sec.pages) do if p == key then return sec.key, sec end end
    for _, p in ipairs(sec.hidden or {}) do if p == key then return sec.key, sec end end
  end
  return "home", self.SECTIONS[1]
end
function W:LastPage(secKey)
  if self.lastPage[secKey] then return self.lastPage[secKey] end
  for _, sec in ipairs(self.SECTIONS) do if sec.key == secKey then return sec.pages[1] end end
  return "home"
end

-- one size for the window (the popups share the setting from Settings / edit mode)
function W:ApplyScale()
  if not self.frame then return end
  local sc = (ns.db.settings.popupScale or 1)
  pcall(self.frame.SetScale, self.frame, sc)
end

local function savePos(f)
  local point, _, rel, x, y = f:GetPoint(1)
  ns.db.settings.window = { point = point, rel = rel, x = x, y = y }
end

function W:Create()
  if self.frame then return self.frame end
  local f = CreateFrame("Frame", "ChillanMainFrame", UIParent)
  self.frame = f
  local sz = ns.db.settings.windowSize
  f:SetSize(math.max(MIN_W, (sz and sz.w) or WIDTH), math.max(MIN_H, (sz and sz.h) or HEIGHT))
  local pos = ns.db.settings.window
  if pos and pos.point then
    f:SetPoint(pos.point, UIParent, pos.rel or pos.point, pos.x, pos.y)
  else
    f:SetPoint("CENTER", 0, 40)
  end
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:Hide()
  tinsert(UISpecialFrames, "ChillanMainFrame")

  local shadow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  shadow:SetTexture(ns.TEX .. "Shadow")
  shadow:SetPoint("TOPLEFT", -40, 30)
  shadow:SetPoint("BOTTOMRIGHT", 40, -50)
  shadow:SetVertexColor(0, 0, 0, 0.9)

  local bg = UI.Panel(f, C.window, C.inputLine, false)
  bg:SetAllPoints()
  bg:SetFrameLevel(f:GetFrameLevel())

  -- Tittellinje (dra for å flytte)
  local title = CreateFrame("Frame", nil, f)
  title:SetPoint("TOPLEFT")
  title:SetPoint("TOPRIGHT")
  title:SetHeight(TITLE_H)
  title:EnableMouse(true)
  title:RegisterForDrag("LeftButton")
  title:SetScript("OnDragStart", function() f:StartMoving() end)
  title:SetScript("OnDragStop", function() f:StopMovingOrSizing() savePos(f) end)

  local seal = title:CreateTexture(nil, "ARTWORK")
  seal:SetTexture(ns.TEX .. "Logo")
  seal:SetSize(26, 26)
  seal:SetPoint("LEFT", 14, 0)
  local logo = UI.Text(title, 19, "bold", C.text)
  logo:SetPoint("LEFT", seal, "RIGHT", 8, 0)
  logo:SetText("Chillan")
  local q = UI.Text(title, 19, "bold", C.accent)
  q:SetPoint("LEFT", logo, "RIGHT", 0, 0)
  q:SetText("?")

  local chip = UI.Panel(title, C.input, C.inputLine, true)
  chip:SetHeight(24)
  chip:SetPoint("LEFT", q, "RIGHT", 12, 0)
  chip.text = UI.Text(chip, 12, nil, C.muted)
  chip.text:SetPoint("CENTER")
  self.chip = chip

  -- versjon synlig i tittellinja, så det er lett å sjekke etter oppdatering
  local ver = UI.Text(title, 11, nil, C.dim)
  ver:SetPoint("LEFT", chip, "RIGHT", 10, 0)
  ver:SetText("v" .. ns.VERSION)
  UI.Track(ver):SetTextColor(hex(C.muted))
  self.ver = ver
  -- "update available" when someone in the gang runs a newer version
  local upd = CreateFrame("Button", nil, title)
  upd:SetHeight(20)
  upd:SetPoint("LEFT", ver, "RIGHT", 8, 0)
  upd.text = UI.Text(upd, 11, "semi", C.amber)
  upd.text:SetPoint("LEFT")
  upd:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Chillan? " .. tostring(ns.newestVersion) .. " is out")
    local p = ns.newestVersionPid and ns:GetPerson(ns.newestVersionPid)
    if p then GameTooltip:AddLine((ns:PersonFirst(p) or "Someone") .. " already has it.", 0.8, 0.82, 0.85) end
    GameTooltip:AddLine("Update in WowUp, then /reload.", 0.6, 0.63, 0.66)
    GameTooltip:Show()
  end)
  upd:SetScript("OnLeave", function() GameTooltip:Hide() end)
  upd:Hide()
  self.updBtn = upd

  local close = UI.IconButton(title, 32, "Close", nil, function() f:Hide() end)
  close:SetPoint("RIGHT", -10, 0)
  close.panel:SetColors(nil, nil)
  close.style = { fill = nil, line = nil, text = C.muted, hover = C.card }
  UI.Track(close.icon):SetVertexColor(hex(C.muted))

  local online = UI.Text(title, 13, nil, C.muted)
  online:SetPoint("RIGHT", close, "LEFT", -10, 0)
  self.onlineText = online
  local dot = title:CreateTexture(nil, "ARTWORK")
  dot:SetTexture(ns.TEX .. "Circle")
  dot:SetSize(8, 8)
  UI.Track(dot):SetVertexColor(hex(C.green))
  dot:SetPoint("RIGHT", online, "LEFT", -6, 0)

  local line1 = UI.SolidLine(f)
  line1:SetPoint("TOPLEFT", 1, -TITLE_H)
  line1:SetPoint("TOPRIGHT", -1, -TITLE_H)
  line1:SetHeight(1)

  -- Sections across the top (1.0). The old side rail was full: 10 tabs took 444 of its 452 px.
  local secX = nil
  self.secButtons = {}
  for i, sec in ipairs(W.SECTIONS) do
    -- Settings and What's new are the cog and the bell on the right, not tabs as well (1.1.5)
    if sec.header then break end
    local b = UI.Button(title, 10, 30, sec.label, "nav")
    b.label:SetFont(ns.FONT_SEMI, 13, "")
    b:SetWidth(b.label:GetStringWidth() + 26)
    if secX then b:SetPoint("LEFT", secX, "RIGHT", 2, 0) else b:SetPoint("LEFT", q, "RIGHT", 22, 0) end
    secX = b
    b.key = sec.key
    b:SetScript("OnClick", function() W:Select(W:LastPage(sec.key)) end)
    b:SetScript("OnLeave", function(self)
      if W:SectionOf(W.current) == self.key then self.panel:SetColors(C.active, nil) else self.panel:SetColors(nil, nil) end
    end)
    b.badge = CreateFrame("Frame", nil, b)
    b.badge:SetSize(16, 16)
    b.badge:SetPoint("CENTER", b, "TOPRIGHT", -4, -6)
    b.badge:SetFrameLevel(b:GetFrameLevel() + 5)
    b.badge.bg = b.badge:CreateTexture(nil, "OVERLAY")
    b.badge.bg:SetTexture(ns.TEX .. "Circle")
    b.badge.bg:SetAllPoints()
    UI.Track(b.badge.bg):SetVertexColor(hex(C.red))
    b.badge.text = UI.Text(b.badge, 9, "bold", "FFFFFF")
    b.badge.text:SetPoint("CENTER", 0, 0)
    b.badge:Hide()
    self.secButtons[sec.key] = b
  end

  -- header icons: settings and what's new
  local cog = UI.IconButton(title, 30, "Gear", "Settings", function() W:Select("settings") end)
  cog:SetPoint("RIGHT", close, "LEFT", -4, 0)
  local bell = UI.IconButton(title, 30, "Scroll", "What's new", function() W:Select("changelog") end)
  bell:SetPoint("RIGHT", cog, "LEFT", -4, 0)
  bell.badge = bell:CreateTexture(nil, "OVERLAY")
  bell.badge:SetTexture(ns.TEX .. "Circle")
  bell.badge:SetSize(8, 8)
  bell.badge:SetPoint("TOPRIGHT", -5, -5)
  UI.Track(bell.badge):SetVertexColor(hex(C.accent))
  bell.badge:Hide()
  self.cogBtn, self.bellBtn = cog, bell
  online:ClearAllPoints()
  online:SetPoint("RIGHT", bell, "LEFT", -12, 0)
  -- (1.1.7) "N online" opens the Friends page
  local onlineBtn = CreateFrame("Button", nil, title)
  onlineBtn:SetPoint("TOPLEFT", online, "TOPLEFT", -16, 4)
  onlineBtn:SetPoint("BOTTOMRIGHT", online, "BOTTOMRIGHT", 2, -4)
  onlineBtn:SetScript("OnClick", function() W:Select("friends") end)
  onlineBtn:SetScript("OnEnter", function(self)
    online:SetTextColor(hex(C.text))
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Friends")
    GameTooltip:Show()
  end)
  onlineBtn:SetScript("OnLeave", function() online:SetTextColor(hex(C.muted)) GameTooltip:Hide() end)

  -- page bar: the pages of the current section, the gang code and the version on the right
  local pagebar = CreateFrame("Frame", nil, f)
  pagebar:SetPoint("TOPLEFT", 0, -TITLE_H - 1)
  pagebar:SetPoint("TOPRIGHT", 0, -TITLE_H - 1)
  pagebar:SetHeight(PAGEBAR_H)
  self.pagebar = pagebar
  self.pageButtons = {}
  local line2 = UI.SolidLine(f)
  line2:SetPoint("TOPLEFT", 1, -TITLE_H - PAGEBAR_H - 1)
  line2:SetPoint("TOPRIGHT", -1, -TITLE_H - PAGEBAR_H - 1)
  line2:SetHeight(1)
  chip:SetParent(pagebar)
  chip:ClearAllPoints()
  upd:SetParent(pagebar)
  ver:SetParent(pagebar)
  ver:ClearAllPoints()
  ver:SetPoint("RIGHT", pagebar, "RIGHT", -14, 0)
  chip:SetPoint("RIGHT", ver, "LEFT", -10, 0)
  upd:ClearAllPoints()
  upd:SetPoint("RIGHT", chip, "LEFT", -10, 0)

  -- content
  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", 1, -TITLE_H - PAGEBAR_H - 2)
  content:SetPoint("BOTTOMRIGHT", -1, 1)
  self.content = content

  -- pages are built the first time they're opened (all 12 were built when the window opened before 1.0)
  for _, def in ipairs(self.tabDefs) do
    local tab = CreateFrame("Frame", nil, content)
    tab:SetAllPoints()
    tab:Hide()
    tab.def = def
    self.tabs[def.key] = tab
  end

  -- resize grip (bottom right); the window can't go below the size it had before 1.0
  f:SetResizable(true)
  if f.SetResizeBounds then f:SetResizeBounds(MIN_W, MIN_H, 1600, 1100)
  elseif f.SetMinResize then f:SetMinResize(MIN_W, MIN_H) end
  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -3, 3)
  grip:SetFrameLevel(f:GetFrameLevel() + 20)
  grip.tex = grip:CreateTexture(nil, "OVERLAY")
  grip.tex:SetAllPoints()
  grip.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    ns.db.settings.windowSize = { w = math.floor(f:GetWidth()), h = math.floor(f:GetHeight()) }
    savePos(f)
    W:Refresh()
  end)
  self:ApplyScale()

  self:BuildSetup()

  f:SetScript("OnShow", function() W:Refresh() end)
  ns:Listen("DATA", function() if f:IsShown() then W:Refresh() end end)
  ns:Listen("CODE_CHANGED", function() if f:IsShown() then W:Refresh() end end)
  self:Select("home")
  return f
end

-- unread counts: chat on Chat, ideas on Tools (and its pill), what's new as a dot on the bell
local BADGE_SECTION = { chat = "chat", ideas = "tools" }
function W:UpdateBadges()
  if self.updBtn then
    local newer = ns.newestVersion and ns.NewerVersion(ns.newestVersion, ns.VERSION)
    if newer then
      self.updBtn.text:SetText("update available (" .. ns.newestVersion .. ") ·")
      self.updBtn:SetWidth(self.updBtn.text:GetStringWidth() + 4)
    end
    self.updBtn:SetShown(newer and true or false)
  end
  local shown = self.frame and self.frame:IsShown()
  local perSection = {}
  for key, sec in pairs(BADGE_SECTION) do
    local viewing = key == self.current and shown
    if viewing then
      ns.db.seen = ns.db.seen or {}
      ns.db.seen[key] = ns.Now()
    end
    local n = viewing and 0 or ns.Badges:Count(key)
    perSection[sec] = (perSection[sec] or 0) + n
    local pill = self.pageButtons and self.pageButtons[key]
    if pill and pill.count then pill.count:SetText(n > 0 and ns.Colorize(" " .. (n > 9 and "9+" or n), C.red) or "") end
  end
  for key, b in pairs(self.secButtons or {}) do
    local n = perSection[key] or 0
    if n > 0 then
      b.badge.text:SetText(n > 9 and "9+" or tostring(n))
      b.badge:Show()
    else
      b.badge:Hide()
    end
  end
  if self.bellBtn then
    local n = (self.current == "changelog" and shown) and 0 or ns.Badges:Count("changelog")
    self.bellBtn.badge:SetShown(n > 0)
  end
end
ns:Listen("BADGES", function() if W.frame then W:UpdateBadges() end end)

-- the page pills for the section we're in
function W:PaintPageBar(secKey, sec)
  for _, b in pairs(self.pageButtons) do b:Hide() end
  local pages = {}
  for _, k in ipairs(sec.pages) do pages[#pages + 1] = k end
  -- a hidden page (player, compare) shows as an extra pill while it's open
  if self.current and not has(pages, self.current) then pages[#pages + 1] = self.current end
  if #pages == 1 then return end   -- (1.1.7) one page: no pill (Home, Chat)
  local prev
  for _, key in ipairs(pages) do
    local b = self.pageButtons[key]
    if not b then
      b = UI.Button(self.pagebar, 10, 26, W.PAGE_LABELS[key] or key, "ghost", function() W:Select(key) end)
      b.count = UI.Text(b, 11, "semi", C.red)
      b.count:SetPoint("LEFT", b.label, "RIGHT", 0, 0)
      self.pageButtons[key] = b
    end
    b:SetWidth(b.label:GetStringWidth() + 26)
    b:ClearAllPoints()
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("LEFT", self.pagebar, "LEFT", 12, 0) end
    prev = b
    local on = key == self.current
    b.panel:SetColors(on and C.active or nil, on and C.activeLine or C.inputLine)
    UI.Track(b.label):SetTextColor(hex(on and C.text or C.muted))
    b.style = { fill = on and C.active or nil, line = on and C.activeLine or C.inputLine, text = on and C.text or C.muted, hover = on and C.activeHover or C.card }
    b:Show()
  end
end

function W:Select(key)
  if not self.tabs[realOf(key)] then key = "home" end
  self.current = key
  local real = realOf(key)
  if key == "chat" or key == "ideas" or key == "changelog" then ns.Badges:MarkSeen(key) end
  local tab = self.tabs[real]
  if tab and not tab.built then
    tab.built = true
    local ok, err = pcall(tab.def.build, tab)
    if not ok and ns.debug then ns.Print("UI error building " .. key .. ":", err) end
  end
  for k, t in pairs(self.tabs) do
    if k == real then t:Show() else t:Hide() end
  end
  if real == "stats" and tab and tab.SetPage then
    pcall(tab.SetPage, tab, W.VIRTUAL[key] and W.VIRTUAL[key][2] or "overview")
  end
  local secKey, sec = self:SectionOf(key)
  if not has(sec.hidden or {}, key) then self.lastPage[secKey] = key end
  for k, b in pairs(self.secButtons or {}) do
    if k == secKey then
      b.panel:SetColors(C.active, nil)
      UI.Track(b.label):SetTextColor(hex(C.accent))
    else
      b.panel:SetColors(nil, nil)
      UI.Track(b.label):SetTextColor(hex(C.muted))
    end
  end
  if self.cogBtn then UI.Track(self.cogBtn.icon):SetVertexColor(hex(key == "settings" and C.accent or C.muted)) end
  if self.bellBtn then UI.Track(self.bellBtn.icon):SetVertexColor(hex(key == "changelog" and C.accent or C.muted)) end
  self:PaintPageBar(secKey, sec)
  self:Refresh()
  self:UpdateBadges()
end

function W:OnlineCount()
  local n, total = 0, 0
  for pid, p in pairs(ns.db.people) do
    if pid ~= ns.pid and p.main then
      total = total + 1
      if ns:IsOnline(p) then n = n + 1 end
    end
  end
  return n, total
end

function W:Refresh()
  if not self.frame then return end
  local hasCode = ns.db.code ~= nil
  self.chip.text:SetText(hasCode and ("Gang: " .. ns.db.code) or "No gang yet")
  self.chip:SetWidth(self.chip.text:GetStringWidth() + 20)
  local n = self:OnlineCount()
  self.onlineText:SetText(n .. " online")
  if not hasCode and self.current ~= "settings" then
    self.setup:Show()
    for _, tab in pairs(self.tabs) do tab:Hide() end
    return
  end
  local cur = self.tabs[realOf(self.current)]
  if cur and not cur.built then self:Select(self.current) return end
  self.setup:Hide()
  local tab = self.tabs[realOf(self.current)]
  if tab then
    tab:Show()
    if tab.Refresh then
      local ok, err = pcall(tab.Refresh, tab)
      if not ok and ns.debug then ns.Print("UI-feil:", err) end
    end
  end
end

function W:Toggle(key)
  local f = self:Create()
  if f:IsShown() and (not key or key == self.current) then
    f:Hide()
  else
    f:Show()
    if key then self:Select(key) end
  end
end

---------------------------------------------------------------------------
-- Første gangs oppsett: lag eller bli med i en gjeng
---------------------------------------------------------------------------
function W:BuildSetup()
  local s = CreateFrame("Frame", nil, self.content)
  s:SetAllPoints()
  s:Hide()
  self.setup = s

  local card = UI.Panel(s, C.card, C.line, false)
  card:SetSize(440, 340)
  card:SetPoint("CENTER")

  local h = UI.Text(card, 20, "bold", C.text)
  h:SetPoint("TOPLEFT", 24, -24)
  h:SetText("Welcome to " .. ns.Logo())
  local p = UI.Text(card, 13, nil, C.muted)
  p:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -8)
  p:SetWidth(392)
  p:SetWordWrap(true)
  p:SetText("Create a new gang and share the code, or enter a code you received. Everyone with the same code is connected, regardless of guild.")

  local al = UI.Text(card, 12, nil, C.dim)
  al:SetPoint("TOPLEFT", p, "BOTTOMLEFT", 0, -18)
  al:SetText("Display name – shown next to all your characters")
  local alias = UI.EditBox(card, 392, 34, "e.g. Henrik")
  alias:SetPoint("TOPLEFT", al, "BOTTOMLEFT", 0, -6)
  alias:SetText(ns.db.alias or "")

  local cl = UI.Text(card, 12, nil, C.dim)
  cl:SetPoint("TOPLEFT", alias, "BOTTOMLEFT", 0, -16)
  cl:SetText("Got a code?")
  local code = UI.EditBox(card, 282, 34, "CHILL-XXXX")
  code:SetPoint("TOPLEFT", cl, "BOTTOMLEFT", 0, -6)

  local function apply(c)
    local a = ns.Clean(alias:GetText(), 20)
    if a ~= "" then ns.db.alias = a end
    if ns:SetCode(c) then
      ns.Print("You're in the gang " .. ns.db.code .. ". Share the code with your friends!")
    end
  end

  local join = UI.Button(card, 100, 34, "Join", "secondary", function() apply(code:GetText()) end)
  join:SetPoint("LEFT", code, "RIGHT", 10, 0)

  local orl = UI.Text(card, 12, nil, C.dim)
  orl:SetPoint("TOPLEFT", code, "BOTTOMLEFT", 0, -18)
  orl:SetText("Or create a new gang:")
  local new = UI.Button(card, 392, 38, "Create gang", "primary", function() apply(ns:NewCode()) end)
  new:SetPoint("TOPLEFT", orl, "BOTTOMLEFT", 0, -8)
end
