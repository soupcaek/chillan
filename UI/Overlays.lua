-- Chillan? – what shows on screen: minibar, toasts, ding box, session summary, profile card
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex
local O = {}
ns.Overlays = O

---------------------------------------------------------------------------
-- Minibar
---------------------------------------------------------------------------
function O:CreateMinibar()
  local m = CreateFrame("Button", "ChillanMinibar", UIParent)
  self.minibar = m
  m:SetHeight(34)
  m:SetFrameStrata("MEDIUM")
  m:SetMovable(true)
  m:SetClampedToScreen(true)
  m:RegisterForDrag("LeftButton")
  m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local pos = ns.db.settings.minibarPos
  if pos then m:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y) else m:SetPoint("TOPLEFT", 20, -20) end
  m:SetScript("OnDragStart", function(self)
    if UI.IsLocked() then return end
    self.isMoving = true
    self:StartMoving()
  end)
  m:SetScript("OnDragStop", function(self)
    if not self.isMoving then return end
    self.isMoving = nil
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint(1)
    ns.db.settings.minibarPos = { point = point, x = x, y = y }
  end)
  m:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then ns.EventWindow:ShowOrToggle() else ns.Window:Toggle() end
  end)
  m.posKey = "minibar"
  m.defaultPos = function(f) f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -20) end
  UI.movables.minibar = m

  m.panel = UI.OverlayPanel(m, C.window, C.inputLine, false)
  m.panel:SetAllPoints()
  m.panel:SetFrameLevel(m:GetFrameLevel())
  m.logo = UI.Text(m, 14, "bold", C.text)
  m.logo:SetPoint("LEFT", 12, 0)
  m.logo:SetText(ns.Logo())
  m.avatars = {}
  for i = 1, 8 do
    local a = UI.Avatar(m, 20)
    UI.Track(a.bg):SetVertexColor(hex(C.active))
    a:Hide()
    m.avatars[i] = a
  end
  m.count = UI.Text(m, 12, nil, C.muted)

  m:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:AddLine("Chillan?", 1, 1, 1)
    local any = false
    for pid, p in pairs(ns.db.people) do
      if pid ~= ns.pid and p.main and ns:IsOnline(p) then
        local c = ns:PersonChar(p) or {}
        local r, g, b = ns.ClassColor(c.class)
        local L = p.live or {}
        local mine = ns.Layer and ns.Layer:Current()
        local lay = L.inInst and "dungeon" or (L.layer and mine and L.layer == mine) and "|cff9BE08Asame layer|r"
          or (L.layer and ns.Layer and ns.Layer.Label(L.layer)) or ""
        GameTooltip:AddDoubleLine((ns:PersonAlias(p) or c.name or "?") .. "  |cff9BA1A8" .. (c.level or "") .. "|r",
          ((L.zone or "") .. (lay ~= "" and ("  ·  " .. lay) or "")), r, g, b, 0.75, 0.78, 0.82)
        any = true
      end
    end
    if not any then GameTooltip:AddLine("Nobody else online", 0.6, 0.63, 0.66) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: open Chillan?  ·  Drag: move", 0.52, 0.55, 0.57)
    GameTooltip:Show()
  end)
  m:SetScript("OnLeave", function() GameTooltip:Hide() end)

  ns:Listen("DATA", function() O:UpdateMinibar() end)
  ns:Listen("MINIBAR", function() O:UpdateMinibar() end)
  self:UpdateMinibar()
end

function O:UpdateMinibar()
  local m = self.minibar
  if not m then return end
  if not ns.db.settings.minibar or not ns.db.code then m:Hide() return end
  m:Show()
  local online = ns:SortedPeople(function(p, pid) return pid ~= ns.pid and ns:IsOnline(p) end)
  table.sort(online, function(a, b) return ns:PersonMaxLevel(a) > ns:PersonMaxLevel(b) end)
  local x = m.logo:GetStringWidth() + 22
  -- (1.2.4) bigger faces, at most 4; the rest as "+N"
  local SHOWN = 4
  for i, a in ipairs(m.avatars) do
    local p = i <= SHOWN and online[i]
    if p then
      local c = ns:PersonChar(p) or {}
      a:Set(c.name, c.class, nil)
      a:ClearAllPoints()
      a:SetPoint("LEFT", x, 0)
      a:SetFrameLevel(m:GetFrameLevel() + 20 - i)   -- the first sits on top; they overlap a little
      x = x + 14
      a:Show()
    else
      a:Hide()
    end
  end
  if #online > 0 then x = x + 10 end
  if not m.moreFaces then m.moreFaces = UI.Text(m, 11, "semi", C.muted) end
  if #online > SHOWN then
    m.moreFaces:ClearAllPoints()
    m.moreFaces:SetPoint("LEFT", x - 2, 0)
    m.moreFaces:SetText("+" .. (#online - SHOWN))
    m.moreFaces:Show()
    x = x + m.moreFaces:GetStringWidth() + 6
  else
    m.moreFaces:Hide()
  end
  m.count:ClearAllPoints()
  m.count:SetPoint("LEFT", x, 0)
  m.count:SetText(#online .. " online")
  local w = x + m.count:GetStringWidth() + 14
  -- your status as a small clickable pill right after the online count
  if not m.status then
    local sb = CreateFrame("Button", nil, m)
    sb:SetHeight(20)
    sb.dot = sb:CreateTexture(nil, "OVERLAY")
    sb.dot:SetTexture(ns.TEX .. "Circle")
    sb.dot:SetSize(7, 7)
    sb.dot:SetPoint("LEFT", 4, 0)
    sb.text = UI.Text(sb, 11, "semi", C.text2)
    sb.text:SetPoint("LEFT", sb.dot, "RIGHT", 5, 0)
    sb:SetScript("OnClick", function(self)
      local items = {}
      for _, code in ipairs(ns.MANUAL_STATUS) do
        local label = code == "AUTO" and "Automatic" or ns.STATUS[code].label
        items[#items + 1] = { text = label, color = code ~= "AUTO" and ns.STATUS[code].color or nil,
          func = function() ns.Tracker:SetStatus(code) O:UpdateMinibar() end }
      end
      items[#items + 1] = { text = "Layer hop – move to another layer", color = C.accent, func = function() ns.LayerHop:Request() end }
      UI.Menu(self, items, true)
    end)
    sb:SetScript("OnEnter", function(self)
      UI.Track(self.text):SetTextColor(hex(C.text))
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:AddLine("Your status")
      GameTooltip:AddLine(ns.db.statusOverride and "Set by you – click to change" or "Automatic – click to set LFG, Needs help or Do not disturb", 0.6, 0.63, 0.66, true)
      local cur = ns.Layer and ns.Layer:CurrentLabel()
      GameTooltip:AddLine("Layer: " .. (cur or "unknown – target or mouse over an NPC"), 0.6, 0.63, 0.66, true)
      GameTooltip:Show()
    end)
    sb:SetScript("OnLeave", function(self) UI.Track(self.text):SetTextColor(hex(C.text2)) GameTooltip:Hide() end)
    m.status = sb
  end
  local SHORT = { QUEST = "Questing", DUNGEON = "Dungeon", BG = "BG", AFK = "AFK", LFG = "LFG", HELP = "Help!", DND = "DND" }
  local st = ns.Tracker:Status()
  local info = ns.STATUS[st] or ns.STATUS.QUEST
  UI.Track(m.status.dot):SetVertexColor(hex(info.color))
  local lay = ns.Layer and ns.Layer:CurrentLabel()
  -- Gang pulse (1.1.0): the chip says where you are – your status in the open world, else the
  -- dungeon or battleground (the layer has its own box under the bar)
  local P = ns.Pulse
  local chip = (P and P:Mode() ~= "world") and P:Place() or (SHORT[st] or info.label)
  m.status.text:SetText(chip)
  m.status:SetWidth(m.status.text:GetStringWidth() + 18)
  m.countX, m.statusX = x, w - 8
  m.status:ClearAllPoints()
  m.status:SetPoint("LEFT", m.statusX, 0)
  w = w + m.status:GetWidth() + 2
  w = w + 52   -- pin and ⋯
  if not m.more then O:CreatePulseButtons(m) end
  m.naturalW = w
  if ns.Tiles and ns.Tiles.holder then ns.Tiles:Layout() else self:FitMinibar() end
end

-- Gang pulse buttons (1.1.0): pin (stay open in combat) and ⋯ (filters, mode, attach, settings)
function O:CreatePulseButtons(m)
  local pin = UI.IconButton(m, 22, ns.db.settings.pulsePin and "Lock" or "Unlock", "Pin: stay open in combat", function(b)
    ns.db.settings.pulsePin = not ns.db.settings.pulsePin
    b:SetIcon(ns.db.settings.pulsePin and "Lock" or "Unlock")
    UI.Track(b.icon):SetVertexColor(hex(ns.db.settings.pulsePin and C.accent or C.muted))
    if ns.NowCard then ns.NowCard:Relayout() end
  end)
  UI.Track(pin.icon):SetVertexColor(hex(ns.db.settings.pulsePin and C.accent or C.muted))
  m.pin = pin
  local more = UI.IconButton(m, 22, "More", "Filters, mode, layout and settings", function(b) O:PulseMenu(b) end)
  UI.Track(more.icon):SetVertexColor(hex(C.muted))
  m.more = more
end

function O:PulseMenu(anchor)
  local S = ns.db.settings
  local items = {}
  local function head(t) items[#items + 1] = { text = t, color = C.muted, func = function() end } end
  local function opt(label, on, fn) items[#items + 1] = { text = (on and "• " or "   ") .. label, color = on and C.text or C.text2, func = fn } end
  head("SHOW IN THE FEED")
  for _, f in ipairs({ { "all", "Everything" }, { "ev", "Events only" }, { "chat", "Chat only" } }) do
    opt(f[2], (S.evFilter or "all") == f[1], function() S.evFilter = f[1] ns.EventWindow:Redraw() end)
  end
  head("MODE")
  opt("Automatic (where you are)", not S.pulseMode, function() S.pulseMode = nil ns:Fire("PULSE_MODE") end)
  for _, k in ipairs({ "world", "dungeon", "bg" }) do
    opt("Always " .. ns.Pulse.MODES[k]:lower(), S.pulseMode == k, function() S.pulseMode = k ns:Fire("PULSE_MODE") end)
  end
  head("WATCHING")
  items[#items + 1] = { text = "   Choose who to watch…", color = C.text2, func = function() ns.Watch:Menu(anchor) end }
  opt("Show the Watching strip", S.watchStrip ~= false, function() S.watchStrip = (S.watchStrip == false) and true or false ns.Overlays:UpdateGroup() end)
  head("LAYOUT")
  opt("Gang feed attached", S.evDocked, function() ns.EventWindow:SetDocked(not S.evDocked) end)
  opt("Gang feed shown", S.eventFeed ~= false, function() S.eventFeed = not (S.eventFeed ~= false) ns.EventWindow:Apply() end)
  items[#items + 1] = { text = "   Move things on screen", color = C.text2, func = function() UI.EditMode(true) end }
  items[#items + 1] = { text = "   Settings", color = C.text2, func = function() ns.Window:Toggle("settings") end }
  UI.Menu(anchor, items, true)
end

-- bar is as wide as its content, or as the row of pinned cards under it if that is wider
-- smallest width of the bar group: its own content, or 400 when the event window is attached
function O:BaseWidth()
  local m = self.minibar
  local w = (m and m.naturalW) or 0
  local E = ns.EventWindow
  if ns.db.settings.evDocked and E and E.frame and E.frame:IsShown() then
    -- attached: the width you dragged to (default ~372), never below what the bar needs or the limits
    local want = ns.db.settings.evDockW or 300
    want = math.max(E.DOCK_MIN_W or 270, math.min(E.DOCK_MAX_W or 700, want))
    w = math.max(w, want)
  end
  return w
end

function O:FitMinibar()
  local m = self.minibar
  if not m or not m.naturalW then return end
  local w = math.max(self:BaseWidth(), (ns.Tiles and ns.Tiles.rowWidth) or 0)
  m:SetWidth(w)
  if m.more then
    m.more:ClearAllPoints()
    m.more:SetPoint("RIGHT", -4, 0)
    m.pin:ClearAllPoints()
    m.pin:SetPoint("RIGHT", m.more, "LEFT", -2, 0)
  end
  self:UpdateMinibarExtras()
  self:UpdateGroup()
end

-- The bar, the pinned cards and (if attached) the event window share one background,
-- with thin lines between the parts.
function O:UpdateGroup()
  local m = self.minibar
  if not m or not m.panel then return end
  local holder = ns.Tiles and ns.Tiles.holder
  local tilesOn = holder and holder:IsShown() and m:IsShown()
  local last = tilesOn and holder or m
  -- the Now card (1.1.0) hangs under the boxes, as wide as the bar
  local N = ns.NowCard and ns.NowCard.frame
  if N then
    local showN = tilesOn and not ns.NowCard:Collapsed()
    N:SetShown(showN and true or false)
    if showN then
      N:ClearAllPoints()
      N:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, 0)
      N:SetPoint("TOPRIGHT", last, "BOTTOMRIGHT", 0, 0)
      if not N.topLine then
        N.topLine = N:CreateTexture(nil, "ARTWORK")
        N.topLine:SetHeight(1)
        N.topLine:SetPoint("TOPLEFT", 8, 0)
        N.topLine:SetPoint("TOPRIGHT", -8, 0)
      end
      UI.Track(N.topLine):SetColorTexture(hex(C.line))
      last = N
    end
  end
  -- Watching (1.2.2): the friends you pinned, under the Now card
  local Wf = ns.Watch and ns.Watch.frame
  if Wf then
    local showW = tilesOn and not (ns.NowCard and ns.NowCard:Collapsed()) and ns.db.settings.watchStrip ~= false
    Wf:SetShown(showW and true or false)
    if showW then
      Wf:ClearAllPoints()
      Wf:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, 0)
      Wf:SetPoint("TOPRIGHT", last, "BOTTOMRIGHT", 0, 0)
      if not Wf.topLine then
        Wf.topLine = UI.Track(Wf:CreateTexture(nil, "ARTWORK"))
        Wf.topLine:SetHeight(1)
        Wf.topLine:SetPoint("TOPLEFT", 8, 0)
        Wf.topLine:SetPoint("TOPRIGHT", -8, 0)
      end
      Wf.topLine:SetColorTexture(hex(C.line))
      last = Wf
    end
  end
  -- let go of the event window first, so it can be moved back without an anchor loop
  m.panel:ClearAllPoints()
  m.panel:SetAllPoints(m)
  local E = ns.EventWindow
  if E and E.Reanchor then
    local docked = E:Reanchor(last)
    if docked then last = E.frame end
  end
  m.panel:ClearAllPoints()
  m.panel:SetPoint("TOPLEFT", m, "TOPLEFT")
  m.panel:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT")
  if not m.divider then
    m.divider = m:CreateTexture(nil, "ARTWORK")
    m.divider:SetHeight(1)
    m.divider:SetPoint("BOTTOMLEFT", 8, 0)
    m.divider:SetPoint("BOTTOMRIGHT", -8, 0)
  end
  UI.Track(m.divider):SetColorTexture(hex(C.line))
  m.divider:SetShown(last ~= m)
end

-- newest gang event, shown short in the bar
ns:Listen("FEEDEVENT", function(text)
  if type(text) ~= "string" then return end
  local short = text:gsub("|T.-|t", ""):gsub("|Hchillan[^|]*|h(.-)|h", "%1"):gsub("^%s+", "")
  O.lastEvent = { text = short, at = GetTime() }
  O:UpdateMinibarExtras()
end)

-- extra info in the spare room of a wide bar: the latest gang event
function O:UpdateMinibarExtras()
  local m = self.minibar
  if not m or not m.naturalW then return end
  if not m.extra then
    m.extra = UI.Text(m, 11, nil, C.muted)
    m.extra:SetJustifyH("RIGHT")
  end
  local d = ns.Tracker:S3Data() or {}
  -- session time, only when the bar has room to spare (no growing just for this)
  -- latest event from the gang fills the spare room (fades out after a minute)
  local ev = self.lastEvent
  local evAge = ev and (GetTime() - ev.at) or 999
  local rightEdge = m:GetWidth() - (m.plus and 30 or 8)
  if false and ev and evAge < 75 then
    -- while an event is fresh it takes the place of "N online" (the avatars still show who's on)
    m.count:Hide()
    m.status:ClearAllPoints()
    m.status:SetPoint("LEFT", m.countX - 4, 0)
    local leftX = m.countX + m.status:GetWidth() + 2
    local room = rightEdge - leftX
    m.extra:ClearAllPoints()
    m.extra:SetPoint("LEFT", leftX, 0)
    m.extra:SetWidth(room)
    m.extra:SetWordWrap(false)
    m.extra:SetJustifyH("LEFT")
    m.extra:SetText(ev.text)
    m.extra:SetAlpha(evAge < 60 and 1 or math.max(0, (75 - evAge) / 15))
    m.extra:Show()
    return
  end
  m.count:Show()
  if m.statusX then
    m.status:ClearAllPoints()
    m.status:SetPoint("LEFT", m.statusX, 0)
  end
  m.extra:SetAlpha(1)
  m.extra:SetWidth(0)
  m.extra:SetJustifyH("RIGHT")
  m.extra:SetText("")
  m.extra:Hide()
end

---------------------------------------------------------------------------
-- Popup-varsler
---------------------------------------------------------------------------
local KIND = {
  mention = { icon = "At", color = C.gold, label = "Mentioned in chat" },
  quest = { icon = "Book", color = C.green, label = "Quest buddy" },
  title = { icon = "Crown", color = C.gold, label = "New title" },
  repair = { icon = "Shield", color = C.amber, label = "Durability" },
  radar = { icon = "Radar", color = C.green, label = "Friend nearby" },
  note = { icon = "Map", color = C.amber, label = "Gang note" },
  online = { icon = "Login", color = C.green, label = "Online" },
  ding = { icon = "Up", color = C.green, label = "Ding!" },
  enemy = { icon = "Target", color = C.red, label = "Enemy log" },
  mats = { icon = "Mail", color = C.amber, label = "Needs mats" },
  join = { icon = "Friends", color = C.accent, label = "Wants to join" },
  craft = { icon = "Mail", color = C.purple, label = "Craft" },
  star = { icon = "Star", color = C.amber, label = "Milestone" },
  dead = { icon = "Skull", color = C.red, label = "Ha ha" },
  trophy = { icon = "Trophy", color = C.gold, label = "Winner of the week" },
  info = { icon = "Star", color = C.accent, label = "Chillan?" },
}
O.KIND = KIND

local toasts, pool = {}, {}

-- Usynlig anker som hele stabelen med varsler henger under (kan dras)
local toastAnchor = CreateFrame("Frame", "ChillanToastAnchor", UIParent)
toastAnchor:SetSize(380, 2)

local function layoutToasts()
  local y = 0
  for _, t in ipairs(toasts) do
    t:ClearAllPoints()
    t:SetPoint("TOP", toastAnchor, "TOP", 0, y)
    y = y - t:GetHeight() - 8
  end
end

local function removeToast(t)
  for i, x in ipairs(toasts) do
    if x == t then table.remove(toasts, i) break end
  end
  t:Hide()
  table.insert(pool, t)
  layoutToasts()
end

local function newToast()
  local t = table.remove(pool)
  if t then return t end
  t = CreateFrame("Frame", nil, UIParent)
  t:SetSize(380, 72)
  t:SetFrameStrata("DIALOG")
  t:EnableMouse(true)
  UI.Movable(t, "toasts", function(a) a:SetPoint("TOP", UIParent, "TOP", 0, -110) end, toastAnchor)
  t.panel = UI.OverlayPanel(t, C.window, C.activeLine, false)
  t.panel:SetAllPoints()
  t.panel:SetFrameLevel(t:GetFrameLevel())
  t.tile = UI.Panel(t, C.active, nil, false)
  t.tile:SetSize(44, 44)
  t.tile:SetPoint("LEFT", 14, 0)
  t.icon = UI.Icon(t.tile, "Up", 22, C.green)
  t.icon:SetPoint("CENTER")
  t.kind = UI.Text(t, 10, "semi", C.dim)
  t.kind:SetPoint("TOPLEFT", t.tile, "TOPRIGHT", 14, -1)
  t.title = UI.Text(t, 15, "semi", C.text)
  t.title:SetPoint("LEFT", t.tile, "RIGHT", 14, 1)
  t.title:SetPoint("RIGHT", -16, 0)
  t.text = UI.Text(t, 12, nil, C.muted)
  t.text:SetPoint("BOTTOMLEFT", t.tile, "BOTTOMRIGHT", 14, 1)
  t.text:SetPoint("RIGHT", -16, 0)
  t.btn = UI.Button(t, 76, 28, "", "primary")
  t.btn:SetPoint("RIGHT", -12, 0)
  t.close = UI.IconButton(t, 22, "Close", nil, function() removeToast(t) end)
  t.close:SetPoint("TOPRIGHT", -6, -6)
  t.close.panel:SetColors(nil, nil)
  t.close.style = { text = C.dim, hover = C.card }
  UI.Track(t.close.icon):SetVertexColor(hex(C.dim))
  t:SetScript("OnUpdate", function(self, dt)
    self.life = self.life - dt
    if self.life < 0.6 then self:SetAlpha(math.max(0, self.life / 0.6)) end
    if self.life <= 0 then removeToast(self) end
  end)
  t:SetScript("OnEnter", function(self) self.life = math.max(self.life, 4) self:SetAlpha(1) end)
  return t
end

function O:Toast(info)
  if not ns.db.settings.toasts and info.kind ~= "join" and info.kind ~= "craft" then return end
  local k = KIND[info.kind] or KIND.info
  local t = newToast()
  t.kind:SetText(k.label:upper())
  t.icon:SetTexture(ns.TEX .. "Icon" .. k.icon)
  UI.Track(t.icon):SetVertexColor(hex(k.color))
  local title, text = info.title, info.text
  if info.kind == "ding" and info.item then
    local it = info.item
    local p = ns:GetPerson(it.pid) or {}
    local c = (p.chars and p.chars[it.char]) or {}
    title = ns.Colorize(ns.ShortName(it.char), ns.ClassHex(c.class)) .. " reached level " .. tostring(it.a)
    local parts = {}
    if tonumber(it.b) then parts[#parts + 1] = "/played " .. ns.Duration(tonumber(it.b)) end
    if it.first then parts[#parts + 1] = "first in the gang!"
    elseif it.place then parts[#parts + 1] = "no. " .. it.place .. " in the gang" end
    text = table.concat(parts, " · ")
  end
  local emo = ns.Emotes
  t.title:SetText(emo and emo:Render(title or "", 16) or (title or ""))
  t.text:SetText(emo and emo:Render(text or "", 16) or (text or ""))
  t.title:SetPoint("RIGHT", -34, 0)
  t.text:SetPoint("RIGHT", -34, 0)
  t.btn:Hide()
  if info.kind == "join" and info.char then
    t.btn:SetLabel("Invite")
    t.btn:SetScript("OnClick", function() ns.Invite(info.char) removeToast(t) end)
    t.btn:Show()
  elseif (info.kind == "quest" or info.kind == "radar") and info.char then
    t.btn:SetLabel("Invite")
    t.btn:SetScript("OnClick", function() ns.Invite(info.char) removeToast(t) end)
    t.btn:Show()
  elseif info.kind == "mention" then
    t.btn:SetLabel("Reply")
    t.btn:SetScript("OnClick", function()
      removeToast(t)
      if ns.db.settings.eventFeed and ns.EventWindow.input then
        ns.EventWindow.input.edit:SetFocus()
      else
        ns.Window:Create() ns.Window.frame:Show() ns.Window:Select("chat")
      end
    end)
    t.btn:Show()
  elseif info.kind == "craft" and info.char then
    t.btn:SetLabel("Whisper")
    t.btn:SetScript("OnClick", function() ns.Whisper(info.char) removeToast(t) end)
    t.btn:Show()
  end
  if t.btn:IsShown() then
    t.title:SetPoint("RIGHT", -100, 0)
    t.text:SetPoint("RIGHT", -100, 0)
    t.close:Hide()
  else
    t.close:Show()
  end
  t.life = info.sticky and 25 or 7
  t:SetAlpha(1)
  t:Show()
  table.insert(toasts, 1, t)
  while #toasts > 4 do removeToast(toasts[#toasts]) end
  layoutToasts()
end


---------------------------------------------------------------------------
-- Kveldsoppsummering
---------------------------------------------------------------------------
function O:CreateSummary()
  local s = CreateFrame("Frame", "ChillanSummary", UIParent)
  self.summary = s
  s:SetSize(380, 196)
  UI.Movable(s, "summary", function(f) f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 180) end)
  s:SetFrameStrata("DIALOG")
  s:EnableMouse(true)
  s:Hide()
  s.panel = UI.OverlayPanel(s, C.window, C.inputLine, false)
  s.panel:SetAllPoints()
  s.panel:SetFrameLevel(s:GetFrameLevel())
  s.title = UI.Text(s, 15, "semi", C.text)
  s.title:SetPoint("TOPLEFT", 16, -16)
  s.sub = UI.Text(s, 12, nil, C.dim)
  s.sub:SetPoint("LEFT", s.title, "RIGHT", 10, 0)
  local close = UI.IconButton(s, 26, "Close", nil, function() s:Hide() end)
  close:SetPoint("TOPRIGHT", -8, -8)
  close.panel:SetColors(nil, nil)
  close.style = { text = C.dim, hover = C.card }
  UI.Track(close.icon):SetVertexColor(hex(C.dim))
  s.cells = {}
  local cw = math.floor((380 - 32 - 16) / 3)
  for i = 1, 6 do
    local cell = UI.Panel(s, C.card, C.line, false)
    cell:SetSize(cw, 58)
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    cell:SetPoint("TOPLEFT", 16 + col * (cw + 8), -48 - row * 66)
    cell.v = UI.Text(cell, 17, "bold", C.text)
    cell.v:SetPoint("TOPLEFT", 10, -10)
    cell.k = UI.Text(cell, 11, nil, C.dim)
    cell.k:SetPoint("BOTTOMLEFT", 10, 10)
    s.cells[i] = cell
  end
end

function O:ShowSummary(sum, previous)
  if not sum then return end
  local s = self.summary
  s.title:SetText(previous and "Last session" or "Your evening")
  s.sub:SetText(previous and (ns.ShortName(sum.char) .. " · " .. date("%d.%m %H:%M", sum.at)) or ns.ShortName(sum.char))
  local vals = {
    { ns.Duration(sum.online), "online" },
    { ((sum.levels or 0) > 0 and "+" or "") .. (sum.levels or 0), "levels" },
    { sum.quests or 0, "quests" },
    { "+" .. ns.Money(sum.gold), "gold earned" },
    { sum.deaths or 0, "deaths" },
    { sum.kills or 0, "PvP kills" },
  }
  for i, cell in ipairs(s.cells) do
    cell.v:SetText(vals[i][1])
    cell.k:SetText(vals[i][2])
  end
  s:Show()
end

---------------------------------------------------------------------------
-- Profilkort (hover) – bruker det lille personkortet (UI/PersonCard.lua)
---------------------------------------------------------------------------
function O:ShowProfile(anchor, pid)
  ns.PersonCard:Show(anchor, pid)
end

function O:HideProfile()
  ns.PersonCard:Hide()
end

---------------------------------------------------------------------------
-- Ding midt på skjermen, med gratulasjonsknapper
---------------------------------------------------------------------------
local dingQueue = {}

function O:CreateDing()
  local d = CreateFrame("Frame", "ChillanDing", UIParent)
  self.ding = d
  d:SetSize(500, 168)
  UI.Movable(d, "ding", function(f) f:SetPoint("CENTER", UIParent, "CENTER", 0, 170) end)
  d:SetFrameStrata("DIALOG")
  d:EnableMouse(true)
  d:Hide()
  d.shadow = d:CreateTexture(nil, "BACKGROUND", nil, -8)
  d.shadow:SetTexture(ns.TEX .. "Shadow")
  d.shadow:SetPoint("TOPLEFT", -30, 24)
  d.shadow:SetPoint("BOTTOMRIGHT", 30, -36)
  d.shadow:SetVertexColor(0, 0, 0, 0.8)
  d.panel = UI.OverlayPanel(d, C.window, C.activeLine, false)
  d.panel:SetAllPoints()
  d.panel:SetFrameLevel(d:GetFrameLevel())
  d.tile = UI.Panel(d, C.active, nil, false)
  d.tile:SetSize(52, 52)
  d.tile:SetPoint("TOPLEFT", 20, -20)
  d.icon = UI.Icon(d.tile, "Up", 26, C.green)
  d.icon:SetPoint("CENTER")
  d.kicker = UI.Text(d, 11, "semi", C.green)
  d.kicker:SetPoint("TOPLEFT", d.tile, "TOPRIGHT", 16, -2)
  d.kicker:SetPoint("RIGHT", -40, 0)
  d.kicker:SetText("DING!")
  -- tittelen kan bryte over to linjer (lange achievement-navn), popupen vokser
  d.title = UI.Text(d, 17, "bold", C.text)
  d.title:SetPoint("TOPLEFT", d.kicker, "BOTTOMLEFT", 0, -5)
  d.title:SetPoint("RIGHT", -20, 0)
  d.title:SetWordWrap(true)
  if d.title.SetMaxLines then d.title:SetMaxLines(2) end
  d.text = UI.Text(d, 12, nil, C.text2)
  d.text:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -5)
  d.text:SetPoint("RIGHT", -20, 0)
  d.text:SetWordWrap(true)
  if d.text.SetMaxLines then d.text:SetMaxLines(2) end
  d.close = UI.IconButton(d, 24, "Close", nil, function() O:NextDing() end)
  d.close:SetPoint("TOPRIGHT", -8, -8)
  d.close.panel:SetColors(nil, nil)
  d.close.style = { text = C.dim, hover = C.card }
  UI.Track(d.close.icon):SetVertexColor(hex(C.dim))
  d.buttons = {}
  for i = 1, 5 do
    d.buttons[i] = UI.Button(d, 100, 36, "", i == 1 and "primary" or "secondary")
  end
  d.sent = UI.Text(d, 13, "semi", C.green)
  d.sent:SetPoint("BOTTOM", 0, 30)
  d:SetScript("OnUpdate", function(self, dt)
    self.life = (self.life or 0) - dt
    if self.life < 0.5 then self:SetAlpha(math.max(0, self.life / 0.5)) end
    if self.life <= 0 then O:NextDing() end
  end)
  d:SetScript("OnEnter", function(self) self.life = math.max(self.life or 0, 5) self:SetAlpha(1) end)
end

function O:ShowDing(item)
  local d = self.ding
  if d:IsShown() then
    table.insert(dingQueue, item)
    return
  end
  local p = ns:GetPerson(item.pid) or {}
  local dead = item.kind == "DEAD"
  local ach = item.kind == "ACH"
  local parts = {}
  if ach then
    local def = ns.Ach.byId[item.a] or { name = tostring(item.a), desc = "", tier = item.b or "S" }
    local tier = ns.Ach.TIERS[def.tier] or ns.Ach.TIERS.S
    d.kicker:SetText("ACHIEVEMENT · " .. tier.name:upper())
    UI.Track(d.kicker):SetTextColor(hex(tier.color))
    d.icon:SetTexture(ns.TEX .. "IconTrophy")
    UI.Track(d.icon):SetVertexColor(hex(tier.color))
    d.title:SetText(ns:ShortWho(p, item.char) .. " unlocked " .. ns.Colorize("«" .. def.name .. "»", tier.color))
    parts[#parts + 1] = (item.c and item.c ~= "") and item.c or def.desc
    parts[#parts + 1] = tier.points .. " points"
  elseif item.kind == "KILL" and ns.Kills then
    d.kicker:SetText(ns.Kills:Kicker(item))
    UI.Track(d.kicker):SetTextColor(hex(C.gold))
    d.icon:SetTexture(ns.TEX .. "IconTarget")
    UI.Track(d.icon):SetVertexColor(hex(C.gold))
    local funny = ns.Kills:Line(item, ns.Kills:Names(item, true), C.text)
    d.title:SetText(funny or (ns:PersonLabel(p, item.char) .. " killed " .. tostring(item.c)))
    if item.d and item.d ~= "" then parts[#parts + 1] = tostring(item.c) .. " · " .. item.d end
    parts[#parts + 1] = "in " .. tostring(item.a or "?")
  elseif dead then
    d.kicker:SetText(ns.Deaths and ns.Deaths:Kicker(item) or "DEAD!")
    UI.Track(d.kicker):SetTextColor(hex(C.red))
    d.icon:SetTexture(ns.TEX .. "IconSkull")
    UI.Track(d.icon):SetVertexColor(hex(C.red))
    local funny = ns.Deaths and ns.Deaths:Line(item, ns:ShortWho(p, item.char), C.text)
    d.title:SetText(funny or (ns:PersonLabel(p, item.char) .. " died"))
    if funny then
      if item.d and item.d ~= "" and item.d ~= "player" and type(item.b) == "string" and item.b:find("^PLAYER") then
        parts[#parts + 1] = tostring(item.c) .. " · " .. item.d .. " · added to the enemy log"
      end
    else
      parts[#parts + 1] = "in " .. tostring(item.a or "unknown place")
    end
    local total = ns:TotalStat(p, "Deaths")
    if total > 0 then parts[#parts + 1] = "death no. " .. math.floor(total + 1) end
  else
    local max = tonumber(item.a) == 60
    d.kicker:SetText(max and "LEVEL 60 – MAX LEVEL!" or "DING!")
    UI.Track(d.kicker):SetTextColor(hex(max and C.gold or C.green))
    d.icon:SetTexture(ns.TEX .. "IconUp")
    UI.Track(d.icon):SetVertexColor(hex(C.green))
    d.title:SetText(ns:PersonLabel(p, item.char) .. " reached level " .. tostring(item.a))
    if tonumber(item.b) then parts[#parts + 1] = "/played " .. ns.Duration(tonumber(item.b)) end
    if item.first then parts[#parts + 1] = ns.Colorize("first in the gang!", C.gold)
    elseif item.place and tonumber(item.a) and tonumber(item.a) % 10 == 0 then parts[#parts + 1] = "no. " .. item.place .. " in the gang" end
  end
  -- more from the same person at the same moment, folded into this popup
  for _, x in ipairs(item.also or {}) do
    if x.kind == "ACH" then
      local xd = ns.Ach and ns.Ach.byId[x.a]
      if xd then parts[#parts + 1] = "also unlocked " .. ns.Colorize("«" .. xd.name .. "»", ns.Ach.TIERS[xd.tier].color) end
    elseif x.kind == "DING" then
      parts[#parts + 1] = "also dinged " .. tostring(x.a)
    end
  end
  d.text:SetText(table.concat(parts, " · "))
  -- høyde: topp + kicker + tittel + tekst + luft + knapper
  local th = math.max(20, d.title:GetStringHeight() or 20)
  local xh = math.max(14, d.text:GetStringHeight() or 14)
  d:SetHeight(math.max(168, 20 + 15 + 5 + th + 5 + xh + 24 + 36 + 20))
  -- legg ut knappene etter hvor mange reaksjoner denne typen har (ding 3, død 4)
  -- 4 random reactions from the big pool, new ones every time
  local list = ns.ReactionList(item)
  local picks = ns.PickReactions(item, 4)
  local n = #picks
  local bw = math.floor((500 - 40 - (n - 1) * 8) / n)
  for i, b in ipairs(d.buttons) do
    if i <= n then
      b:SetWidth(bw)
      b:ClearAllPoints()
      b:SetPoint("BOTTOMLEFT", 20 + (i - 1) * (bw + 8), 20)
      b:SetLabel(ns.Emotes and ns.Emotes:Render(list[picks[i]], 18) or list[picks[i]])
    end
  end
  d.sent:Hide()
  for i, b in ipairs(d.buttons) do
    b:SetShown(i <= n)
    b:SetScript("OnClick", function()
      ns.Data:React(item, picks[i])
      -- lukk med en gang du har reagert (neste i køen vises etterpå)
      O:NextDing()
    end)
  end
  d.life = 12
  -- egne hendelser: ingen knapper (du kan ikke gratulere eller le av deg selv)
  if item.pid == ns.pid then
    for _, b in ipairs(d.buttons) do b:Hide() end
    d.sent:Hide()   -- (1.1.5) no "the gang can react now" line on your own ding
    d.life = 6
  end
  d:SetAlpha(1)
  d:Show()
end

function O:NextDing()
  self.ding:Hide()
  local nxt = table.remove(dingQueue, 1)
  if nxt then C_Timer.After(0.3, function() O:ShowDing(nxt) end) end
end

---------------------------------------------------------------------------
-- Minimap-knapp (dra rundt kanten, klikk for å åpne)
---------------------------------------------------------------------------
function O:CreateMinimapButton()
  if not Minimap then return end
  local b = CreateFrame("Button", "ChillanMinimapButton", Minimap)
  self.mmb = b
  b:SetSize(32, 32)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetTexture(ns.TEX .. "Circle")
  b.bg:SetAllPoints()
  UI.Track(b.bg):SetVertexColor(hex(C.window))
  b.ring = b:CreateTexture(nil, "BORDER")
  b.ring:SetTexture(ns.TEX .. "Circle")
  b.ring:SetPoint("TOPLEFT", -1, 1)
  b.ring:SetPoint("BOTTOMRIGHT", 1, -1)
  UI.Track(b.ring):SetVertexColor(hex(C.activeLine))
  b.bg:SetDrawLayer("ARTWORK", 0)
  -- the Chillan? seal (Media/Textures/Logo), a round badge of its own: no extra background or ring
  b.bg:Hide()
  b.ring:Hide()
  b.icon = b:CreateTexture(nil, "OVERLAY")
  b.icon:SetTexture(ns.TEX .. "Logo")
  b.icon:SetAllPoints()
  b.hl = b:CreateTexture(nil, "HIGHLIGHT")
  b.hl:SetTexture(ns.TEX .. "Circle")
  b.hl:SetAllPoints()
  b.hl:SetVertexColor(1, 1, 1, 0.12)
  b.dot = b:CreateTexture(nil, "OVERLAY", nil, 2)
  b.dot:SetTexture(ns.TEX .. "Circle")
  b.dot:SetSize(9, 9)
  b.dot:SetPoint("TOPRIGHT", -1, -1)
  UI.Track(b.dot):SetVertexColor(hex(C.green))

  local function place()
    local a = math.rad(ns.db.settings.minimapAngle or 200)
    local r = (Minimap:GetWidth() / 2) + 6
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
  end
  self.placeMinimap = place
  b:SetScript("OnDragStart", function(self)
    if UI.IsLocked() then return end
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      ns.db.settings.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
      place()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then ns.EventWindow:ShowOrToggle() else ns.Window:Toggle() end
  end)
  b:SetScript("OnEnter", function(self)
    UI.Track(self.ring):SetVertexColor(hex(C.accent))
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Chillan?", 1, 1, 1)
    local n = ns.Window.OnlineCount and ns.Window:OnlineCount() or 0
    GameTooltip:AddLine(n .. " friends online", 0.79, 0.8, 0.82)
    GameTooltip:AddLine("Click: open · Right-click: event window · Drag: move", 0.6, 0.63, 0.66)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(self)
    UI.Track(self.ring):SetVertexColor(hex(C.activeLine))
    GameTooltip:Hide()
  end)
  place()
  self:UpdateMinimapButton()
  ns:Listen("DATA", function() O:UpdateMinimapButton() end)
  ns:Listen("MINIBAR", function() O:UpdateMinimapButton() end)
end

function O:UpdateMinimapButton()
  local b = self.mmb
  if not b then return end
  b:SetShown(ns.db.settings.minimapButton ~= false)
  local n = ns.Window.OnlineCount and ns.Window:OnlineCount() or 0
  b.dot:SetShown(n > 0)
end

---------------------------------------------------------------------------
-- Combat queue: popups and toasts wait until you leave combat
---------------------------------------------------------------------------
local combatQ = {}
local inCombat = ns.U.InCombat

local function shouldQueue()
  return ns.db.settings.combatQueue ~= false and inCombat()
end

function O:QueueOr(kind, payload)
  if shouldQueue() then
    combatQ[#combatQ + 1] = { kind = kind, payload = payload, at = GetTime() }
    return true
  end
  return false
end

function O:FlushCombatQueue()
  if inCombat() or #combatQ == 0 then return end
  local q = combatQ
  combatQ = {}
  local old, counts = {}, {}
  for _, e in ipairs(q) do
    if GetTime() - e.at > 120 then
      old[#old + 1] = e
      local k = e.kind == "ding" and (e.payload.kind or "DING") or "TOAST"
      counts[k] = (counts[k] or 0) + 1
    end
  end
  if #old > 0 then
    local parts = {}
    if counts.DING then parts[#parts + 1] = counts.DING .. " ding" end
    if counts.DEAD then parts[#parts + 1] = counts.DEAD .. (counts.DEAD == 1 and " deaths" or " deaths") end
    if counts.ACH then parts[#parts + 1] = counts.ACH .. " achievements" end
    if counts.TOAST then parts[#parts + 1] = counts.TOAST .. " notices" end
    O:Toast({ kind = "info", title = "While you were in combat", text = table.concat(parts, " · ") .. " – see the event window" })
  end
  for _, e in ipairs(q) do
    if GetTime() - e.at <= 120 then
      if e.kind == "ding" then O:ShowDing(e.payload) else O:Toast(e.payload) end
    end
  end
end

---------------------------------------------------------------------------
-- Klar-sjekk (/chill klar): bag-plasser, holdbarhet og mat/drikke for gruppa
---------------------------------------------------------------------------
function O:CreateReady()
  local r = CreateFrame("Frame", "ChillanReady", UIParent)
  self.readyFrame = r
  r:SetSize(380, 80)
  UI.Movable(r, "ready", function(f) f:SetPoint("CENTER", UIParent, "CENTER", 0, -60) end)
  r:SetFrameStrata("DIALOG")
  r:EnableMouse(true)
  r:Hide()
  r.panel = UI.OverlayPanel(r, C.window, C.activeLine, false)
  r.panel:SetAllPoints()
  r.panel:SetFrameLevel(r:GetFrameLevel())
  r.icon = UI.Icon(r, "Check", 16, C.green)
  r.icon:SetPoint("TOPLEFT", 16, -16)
  r.title = UI.Text(r, 14, "semi", C.text)
  r.title:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
  r.title:SetText("Ready check")
  r.sub = UI.Text(r, 11, nil, C.dim)
  r.sub:SetPoint("LEFT", r.title, "RIGHT", 8, 0)
  local close = UI.IconButton(r, 24, "Close", nil, function() r:Hide() end)
  close:SetPoint("TOPRIGHT", -8, -8)
  close.panel:SetColors(nil, nil)
  close.style = { text = C.dim, hover = C.card }
  UI.Track(close.icon):SetVertexColor(hex(C.dim))
  local heads = { { "Player", 16 }, { "Bags", 186 }, { "Gear", 250 }, { "Food/drink", 310 } }
  for _, hd in ipairs(heads) do
    local t = UI.Text(r, 10, "semi", C.dim)
    t:SetPoint("TOPLEFT", hd[2], -46)
    t:SetText(hd[1]:upper())
  end
  r.rows = {}
  for i = 1, 10 do
    local row = {}
    row.name = UI.Text(r, 13, "semi", C.text)
    row.name:SetWidth(164)
    row.bags = UI.Text(r, 13, nil, C.text)
    row.dur = UI.Text(r, 13, nil, C.text)
    row.food = UI.Text(r, 13, nil, C.text)
    local y = -64 - (i - 1) * 22
    row.name:SetPoint("TOPLEFT", 16, y)
    row.bags:SetPoint("TOPLEFT", 186, y)
    row.dur:SetPoint("TOPLEFT", 250, y)
    row.food:SetPoint("TOPLEFT", 310, y)
    r.rows[i] = row
  end
  r:SetScript("OnUpdate", function(self, dt)
    self.life = (self.life or 0) - dt
    if self.life <= 0 then self:Hide() end
  end)
  ns:Listen("READY_UPDATE", function() if r:IsShown() then O:FillReady() end end)
end

local function col(v, warn, bad, higherIsBetter)
  if higherIsBetter then
    if v <= bad then return C.red elseif v <= warn then return C.amber end
    return C.green
  end
  return C.text
end

function O:FillReady()
  local r = self.readyFrame
  local list = {}
  for pid, data in pairs(ns.Extras.ready or {}) do list[#list + 1] = { pid = pid, d = data } end
  table.sort(list, function(a, b) return a.pid == ns.pid or (b.pid ~= ns.pid and a.pid < b.pid) end)
  for i, row in ipairs(r.rows) do
    local e = list[i]
    if e then
      local p = ns:GetPerson(e.pid) or {}
      row.name:SetText(ns:ShortWho(p))
      row.bags:SetText(e.d.free .. "/" .. e.d.total)
      UI.Track(row.bags):SetTextColor(hex(col(e.d.free, 8, 3, true)))
      row.dur:SetText(e.d.dur .. " %")
      UI.Track(row.dur):SetTextColor(hex(col(e.d.dur, 50, 20, true)))
      row.food:SetText(tostring(e.d.food))
      UI.Track(row.food):SetTextColor(hex(col(e.d.food, 10, 0, true)))
      row.name:Show() row.bags:Show() row.dur:Show() row.food:Show()
    else
      row.name:Hide() row.bags:Hide() row.dur:Hide() row.food:Hide()
    end
  end
  r.sub:SetText(ns.Extras.readyGroup and "your group" or "everyone online (you're not grouped)")
  r:SetHeight(76 + math.max(1, #list) * 22)
end

function O:ShowReady()
  if not self.readyFrame then self:CreateReady() end
  self.readyFrame.life = 45
  self:FillReady()
  self.readyFrame:SetAlpha(1)
  self.readyFrame:Show()
end

function O:Init()
  self:CreateMinibar()
  if ns.NowCard then C_Timer.After(0.5, function()
    ns.NowCard:Create()
    if ns.Watch then ns.Watch:Create() end
    ns.NowCard:Relayout()
  end) end
  ns:Listen("PULSE_MODE", function() O:UpdateMinibar() end)
  self:CreateSummary()
  self:CreateDing()
  self:CreateMinimapButton()
  ns:Listen("DING", function(item) if not O:QueueOr("ding", item) then O:ShowDing(item) end end)
  ns:Listen("TOAST", function(info)
    if not O:QueueOr("toast", info) then O:Toast(info) end
  end)
  ns:On("PLAYER_REGEN_ENABLED", function() C_Timer.After(1.5, function() O:FlushCombatQueue() end) end)
  ns:Listen("SHOW_SUMMARY", function(sum, previous) O:ShowSummary(sum, previous) end)
end

-- the layer shown next to your status follows what the creatures around you say
ns:Listen("LAYER", function() if O.UpdateMinibar then pcall(O.UpdateMinibar, O) end end)
