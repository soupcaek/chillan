-- Chillan? – hovedvinduet med sidemeny og faner
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

local WIDTH, HEIGHT, TITLE_H, NAV_W = 780, 500, 48, 68

local function savePos(f)
  local point, _, rel, x, y = f:GetPoint(1)
  ns.db.settings.window = { point = point, rel = rel, x = x, y = y }
end

function W:Create()
  if self.frame then return self.frame end
  local f = CreateFrame("Frame", "ChillanMainFrame", UIParent)
  self.frame = f
  f:SetSize(WIDTH, HEIGHT)
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
  ver:SetTextColor(hex(C.muted))
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
  close.icon:SetVertexColor(hex(C.muted))

  local online = UI.Text(title, 13, nil, C.muted)
  online:SetPoint("RIGHT", close, "LEFT", -10, 0)
  self.onlineText = online
  local dot = title:CreateTexture(nil, "ARTWORK")
  dot:SetTexture(ns.TEX .. "Circle")
  dot:SetSize(8, 8)
  dot:SetVertexColor(hex(C.green))
  dot:SetPoint("RIGHT", online, "LEFT", -6, 0)

  local line1 = UI.SolidLine(f)
  line1:SetPoint("TOPLEFT", 1, -TITLE_H)
  line1:SetPoint("TOPRIGHT", -1, -TITLE_H)
  line1:SetHeight(1)

  -- Sidemeny
  local nav = CreateFrame("Frame", nil, f)
  nav:SetPoint("TOPLEFT", 0, -TITLE_H - 1)
  nav:SetPoint("BOTTOMLEFT", 0, 1)
  nav:SetWidth(NAV_W)
  local line2 = UI.SolidLine(f)
  line2:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, 0)
  line2:SetPoint("BOTTOMLEFT", nav, "BOTTOMRIGHT", 0, 0)
  line2:SetWidth(1)

  local navIndex = 0
  for _, def in ipairs(self.tabDefs) do
   if not def.hidden then
    navIndex = navIndex + 1
    local i = navIndex
    local b = UI.Button(nav, NAV_W - 12, 42, "", "nav")
    b:SetPoint("TOP", 0, -4 - (i - 1) * 44)
    b.ic = UI.Icon(b, def.icon, 18, C.dim)
    b.ic:SetPoint("TOP", 0, -6)
    b.label:ClearAllPoints()
    b.label:SetPoint("BOTTOM", 0, 5)
    b.label:SetFont(ns.FONT_SEMI, 10, "")
    b:SetLabel(def.label)
    b.key = def.key
    b:SetScript("OnClick", function() W:Select(def.key) end)
    b:SetScript("OnLeave", function(self)
      if W.current == self.key then self.panel:SetColors(C.active, nil) else self.panel:SetColors(nil, nil) end
    end)
    -- unread badge (small accent circle with a number) on the icon's top-right
    b.badge = CreateFrame("Frame", nil, b)
    b.badge:SetSize(16, 16)
    b.badge:SetPoint("CENTER", b.ic, "TOPRIGHT", 3, -1)
    b.badge:SetFrameLevel(b:GetFrameLevel() + 5)
    b.badge.bg = b.badge:CreateTexture(nil, "OVERLAY")
    b.badge.bg:SetTexture(ns.TEX .. "Circle")
    b.badge.bg:SetAllPoints()
    b.badge.bg:SetVertexColor(hex(C.red))
    b.badge.text = UI.Text(b.badge, 9, "bold", "FFFFFF")
    b.badge.text:SetPoint("CENTER", 0, 0)
    b.badge:Hide()
    self.navButtons[def.key] = b
   end
  end

  -- Innholdsflate
  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", NAV_W + 1, -TITLE_H - 1)
  content:SetPoint("BOTTOMRIGHT", -1, 1)
  self.content = content

  for _, def in ipairs(self.tabDefs) do
    local tab = CreateFrame("Frame", nil, content)
    tab:SetAllPoints()
    tab:Hide()
    def.build(tab)
    self.tabs[def.key] = tab
  end

  self:BuildSetup()

  f:SetScript("OnShow", function() W:Refresh() end)
  ns:Listen("DATA", function() if f:IsShown() then W:Refresh() end end)
  ns:Listen("CODE_CHANGED", function() if f:IsShown() then W:Refresh() end end)
  self:Select("friends")
  return f
end

function W:UpdateBadges()
  if self.updBtn then
    local newer = ns.newestVersion and ns.NewerVersion(ns.newestVersion, ns.VERSION)
    if newer then
      self.updBtn.text:SetText("· update available (" .. ns.newestVersion .. ")")
      self.updBtn:SetWidth(self.updBtn.text:GetStringWidth() + 4)
    end
    self.updBtn:SetShown(newer and true or false)
  end
  for key, b in pairs(self.navButtons or {}) do
    if b.badge then
      local viewing = key == self.current and self.frame and self.frame:IsShown()
      if viewing and (key == "chat" or key == "ideas") then
        ns.db.seen = ns.db.seen or {}
        ns.db.seen[key] = ns.Now()
      end
      local n = viewing and 0 or ns.Badges:Count(key)
      if n > 0 then
        b.badge.text:SetText(key == "changelog" and "!" or (n > 9 and "9+" or tostring(n)))
        b.badge:Show()
      else
        b.badge:Hide()
      end
    end
  end
end
ns:Listen("BADGES", function() if W.frame then W:UpdateBadges() end end)

function W:Select(key)
  self.current = key
  if key == "chat" or key == "ideas" or key == "changelog" then ns.Badges:MarkSeen(key) end
  for k, tab in pairs(self.tabs) do
    if k == key then tab:Show() else tab:Hide() end
  end
  for k, b in pairs(self.navButtons) do
    if k == key then
      b.panel:SetColors(C.active, nil)
      b.ic:SetVertexColor(hex(C.accent))
      b.label:SetTextColor(hex(C.accent))
    else
      b.panel:SetColors(nil, nil)
      b.ic:SetVertexColor(hex(C.dim))
      b.label:SetTextColor(hex(C.dim))
    end
  end
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
  if not hasCode and self.current ~= "more" then
    self.setup:Show()
    for _, tab in pairs(self.tabs) do tab:Hide() end
    return
  end
  self.setup:Hide()
  local tab = self.tabs[self.current]
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
  p:SetText("Create a new gang and share the code with your friends, or enter the code you got. Everyone with the same code sees each other, whatever their guild.")

  local al = UI.Text(card, 12, nil, C.dim)
  al:SetPoint("TOPLEFT", p, "BOTTOMLEFT", 0, -18)
  al:SetText("Your name (IRL) – shown next to all your characters")
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
  orl:SetText("Or start a brand new gang:")
  local new = UI.Button(card, 392, 38, "Create gang", "primary", function() apply(ns:NewCode()) end)
  new:SetPoint("TOPLEFT", orl, "BOTTOMLEFT", 0, -8)
end
