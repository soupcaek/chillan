-- Chillan? – small hover card for gang members (chat, events, tabs and normal WoW chat).
-- Shift-klikk på et navn fester kortet med knapper (hvisk, inviter, profil, waypoint).
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

local PC = {}
ns.PersonCard = PC

local W, PAD = 290, 14

local function className(c)
  if not c.class then return nil end
  return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class]) or c.class
end

local function maxLevel()
  return ns.S(GetMaxPlayerLevel) or 60
end

local function lastDing(pid)
  local feed = ns.db.feed or {}
  for i = #feed, 1, -1 do
    local it = feed[i]
    if it.pid == pid and it.kind == "DING" then return it end
  end
end

-- Navnet slik spillet selv oppga det virker best for hvisk/invitasjon
local function target(p)
  return p.whisperTo or (p.live and p.live.char) or p.main
end

-- Finn person-id ut fra et karakternavn (fra |Hplayer:-lenker i vanlig chat)
function PC:FindByChar(name)
  if not name or name == "" then return nil end
  local short = ns.ShortName(name)
  local hidden = ns:HiddenDuplicates()
  for pid, p in pairs(ns.db.people or {}) do
    if p.whisperTo == name then return hidden[pid] or pid end
    for full, ch in pairs(p.chars or {}) do
      if full == name or ch.name == name or ns.ShortName(full) == short then return hidden[pid] or pid end
    end
  end
end

local function actionButton(parent, label, icon, onClick)
  local b = UI.Button(parent, 100, 26, label, "secondary", onClick)
  b:SetIcon(icon, 12)
  return b
end

function PC:Create()
  if self.frame then return end
  local f = CreateFrame("Frame", "ChillanPersonCard", UIParent)
  self.frame = f
  f:SetWidth(W)
  f:SetFrameStrata("TOOLTIP")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s) if PC.pinned then s:StartMoving() end end)
  f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
  f:SetScript("OnHide", function() PC:SetPinned(false) end)
  f:Hide()
  tinsert(UISpecialFrames, "ChillanPersonCard") -- Esc lukker et festet kort

  f.panel = UI.Panel(f, C.card, C.activeLine, false)
  f.panel:SetAllPoints()
  f.panel:SetFrameLevel(f:GetFrameLevel())

  f.avatar = UI.Avatar(f, 36)
  f.avatar:SetPoint("TOPLEFT", PAD, -PAD)
  f.name = UI.Text(f, 14, "semi", C.text)
  f.name:SetPoint("TOPLEFT", f.avatar, "TOPRIGHT", 10, -1)
  f.name:SetPoint("RIGHT", -34, 0)
  f.sub = UI.Text(f, 12, nil, C.muted)
  f.sub:SetPoint("BOTTOMLEFT", f.avatar, "BOTTOMRIGHT", 10, 1)
  f.sub:SetPoint("RIGHT", -PAD, 0)

  f.close = UI.IconButton(f, 22, "Close", "Close", function() f:Hide() end)
  f.close:SetPoint("TOPRIGHT", -8, -8)

  f.level = UI.Text(f, 12, nil, C.text)
  f.pct = UI.Text(f, 12, nil, C.dim)
  f.pct:SetJustifyH("RIGHT")
  f.track = f:CreateTexture(nil, "ARTWORK")
  f.track:SetTexture(ns.TEX .. "RoundedSmall")
  f.track:SetHeight(6)
  f.fill = f:CreateTexture(nil, "OVERLAY")
  f.fill:SetTexture(ns.TEX .. "RoundedSmall")
  f.fill:SetHeight(6)

  f.zone = UI.Text(f, 12, nil, C.text2)
  f.zone:SetWordWrap(true)
  f.zone:SetWidth(W - PAD * 2)

  f.bar = UI.LevelBar(f)
  f.rows = UI.KVRows(f)
  f.divider = UI.SolidLine(f)
  f.divider:SetHeight(1)
  f.ding = UI.Text(f, 11, nil, C.dim)
  f.ding:SetWidth(W - PAD * 2)
  f.ding:SetWordWrap(true)
  f.gear = UI.Text(f, 12, nil, C.text2)
  f.gear:SetWidth(W - PAD * 2)
  f.gear:SetWordWrap(true)
  f.hint = UI.Text(f, 11, nil, C.dim)
  f.hint:SetText("Shift-click the name to pin")

  f.buttons = {
    actionButton(f, "Whisper", "Chat", function() local p = ns:GetPerson(PC.pid) if p then ns.Whisper(target(p)) end end),
    actionButton(f, "Invite", "Plus", function() local p = ns:GetPerson(PC.pid) if p then ns.Invite(target(p)) end end),
    actionButton(f, "Profile", "Friends", function()
      local pid = PC.pid
      f:Hide()
      if ns.Window and ns.Window.OpenPlayer then ns.Window:OpenPlayer(pid) end
    end),
    actionButton(f, "Waypoint", "Map", function()
      local p = ns:GetPerson(PC.pid)
      local L = p and p.live or {}
      if p and ns:IsOnline(p) and L.mapID and L.x and L.y and ns.SetWaypoint(L.mapID, L.x, L.y) then
        ns.Print("Waypoint set to " .. (ns:PersonAlias(p) or ns:PersonName(p)) .. ".")
        ns.OpenMapAt(L.mapID)
      else
        ns.Print("No position to set a waypoint to right now.")
      end
    end),
  }

  -- et festet kort holder seg oppdatert (sone, XP, online)
  local acc = 0
  f:SetScript("OnUpdate", function(_, dt)
    if not PC.pinned then return end
    acc = acc + dt
    if acc > 2 then acc = 0 PC:Fill(PC.pid) end
  end)
end

local function place(fs, y, x)
  fs:ClearAllPoints()
  fs:SetPoint("TOPLEFT", x or PAD, y)
end

-- Fyller kortet og legger ut radene; returnerer false hvis personen ikke finnes
function PC:Fill(pid)
  local p = pid and ns:GetPerson(pid)
  if not p then return false end
  self:Create()
  local f = self.frame
  self.pid = pid
  local c = ns:PersonChar(p) or {}
  local L = p.live or {}
  local online = ns:IsOnline(p)
  local isMe = pid == ns.pid

  -- farger hentes på nytt hver gang, så temaer/aksentfarger slår inn
  f.panel:SetColors(C.card, C.activeLine, UI.OverlayAlpha and UI.OverlayAlpha() or 1)
  UI.Track(f.divider):SetColorTexture(hex(C.line))

  -- (1.4.72) the canvas card: who (status and zone in the header only), the level bar with the last
  -- ding on its right, then one fact per row
  f.avatar:Set(c.name, c.class, online and (L.status == "AFK" and C.amber or C.green) or "4A4F55", C.card)
  local badge = (ns.Titles and ns.Titles.Badge) and ns.Titles:Badge(pid) or ""
  f.name:SetText(ns.WhoLine(p) .. (badge ~= "" and ("  " .. badge) or ""))
  f.sub:SetText(ns.WhereLine(p))
  f.sub:SetWordWrap(true)
  f.sub:ClearAllPoints()
  f.sub:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
  f.sub:SetPoint("RIGHT", -PAD, 0)
  local subH = math.max(14, f.sub:GetStringHeight() or 14)
  local y = -(PAD + math.max(36, 18 + subH) + 12)

  local d = lastDing(pid)
  y = y - f.bar:Draw(p, PAD, y, W - PAD * 2, d and ("Dinged " .. tostring(d.a) .. " · " .. ns.Ago(d.t)) or nil) - 8

  local cmp = (not isMe) and ns.Gear and ns.Gear:Compare(p)
  local gear
  if cmp and cmp.avg then
    gear = "ilvl " .. string.format("%.0f", cmp.avg)
    if cmp.worse > 0 then gear = gear .. " · " .. ns.Colorize(cmp.worse .. " worse", C.red) end
    if cmp.better > 0 then gear = gear .. " · " .. ns.Colorize(cmp.better .. " better", C.green) end
    if cmp.better == 0 and cmp.worse == 0 then gear = gear .. " · " .. ns.Colorize("same as yours", C.dim) end
  end
  y = y - f.rows:Draw({
    { "Played", ns.PlayedLine(p) },
    { "Gear", gear },
    { "Chillan", ns.VersionLine(p, true) },
  }, PAD, y, W - PAD * 2, 1) - 8
  local showFoot = not self.pinned
  f.divider:SetShown(false)
  f.ding:SetShown(false)
  f.zone:SetShown(false)
  f.gear:SetShown(false)
  f.level:SetShown(false) f.pct:SetShown(false) f.track:SetShown(false) f.fill:SetShown(false)

  -- festet: knapper; hover: liten hjelpetekst
  f.close:SetShown(self.pinned and true or false)
  f.hint:SetShown(not self.pinned)
  for _, b in ipairs(f.buttons) do b:SetShown(self.pinned and true or false) end
  if self.pinned then
    y = y - 6
    local bw = math.floor((W - PAD * 2 - 8) / 2)
    for i, b in ipairs(f.buttons) do
      b:SetWidth(bw)
      b:ClearAllPoints()
      local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
      b:SetPoint("TOPLEFT", PAD + col * (bw + 8), y - row * 32)
    end
    y = y - 64
    local canWp = online and L.mapID and L.x and L.y
    f.buttons[1]:SetAlpha(isMe and 0.35 or 1)
    f.buttons[2]:SetAlpha((isMe or not online) and 0.35 or 1)
    f.buttons[4]:SetAlpha((isMe or not canWp) and 0.35 or 1)
  else
    place(f.hint, y)
    y = y - 16
  end
  f:SetHeight(-y + PAD - 4)
  return true
end

function PC:SetPinned(on)
  self.pinned = on and true or false
  if self.frame then self.frame:EnableMouse(self.pinned) end
end

local function atCursor(f)
  local x, y = GetCursorPosition()
  local s = UIParent:GetEffectiveScale()
  f:ClearAllPoints()
  f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / s + 18, y / s + 12)
end

-- Hover: vis kortet ved musa (mode "cursor") eller til høyre for en rad
function PC:Show(anchor, pid, mode)
  if self.pinned then return end
  if not self:Fill(pid) then return end
  local f = self.frame
  f:SetFrameStrata("TOOLTIP")
  if mode == "cursor" or not anchor then
    atCursor(f)
  else
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 10, 0)
  end
  f:Show()
end

function PC:Hide()
  if self.pinned or not self.frame then return end
  self.frame:Hide()
end

function PC:Pin(pid)
  local p = pid and ns:GetPerson(pid)
  if not p then return end
  self:SetPinned(true)
  self:Fill(pid)
  local f = self.frame
  atCursor(f)
  f:SetFrameStrata("DIALOG")
  f:Show()
end

-- Felles klikk på |Hchillan:pid|h-lenker: shift = fest kortet, ellers åpne spillersiden
function PC:OnLinkClick(link)
  local pid = type(link) == "string" and link:match("^chillan:(.+)$")
  if not pid then return false end
  if IsShiftKeyDown() and ns.Watch then
    ns.Watch:Toggle(pid)
  elseif IsControlKeyDown and IsControlKeyDown() then
    self:Pin(pid)
  else
    if self.frame and not self.pinned then self.frame:Hide() end
    if ns.Window and ns.Window.OpenPlayer then ns.Window:OpenPlayer(pid) end
  end
  return true
end

-- Vanlig WoW-chat: hover over et spillernavn fra gjengen viser kortet, shift-klikk fester det
local function hookChatFrame(cf)
  if not cf or cf.chillanCardHooked then return end
  cf.chillanCardHooked = true
  cf:HookScript("OnHyperlinkEnter", function(self, link)
    local name = type(link) == "string" and link:match("^player:([^:]+)")
    local pid = name and PC:FindByChar(name)
    if pid then PC:Show(self, pid, "cursor") end
  end)
  cf:HookScript("OnHyperlinkLeave", function() PC:Hide() end)
  cf:HookScript("OnHyperlinkClick", function(_, link)
    if not IsShiftKeyDown() then return end
    local name = type(link) == "string" and link:match("^player:([^:]+)")
    local pid = name and PC:FindByChar(name)
    if pid then PC:Pin(pid) end
  end)
end

function PC:Init()
  self:Create()
  for i = 1, (NUM_CHAT_WINDOWS or 10) do hookChatFrame(_G["ChatFrame" .. i]) end
  -- nye pop-out-vinduer (hvisk osv.)
  if FCF_OpenTemporaryWindow then
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
      for i = 1, (NUM_CHAT_WINDOWS or 10) + 20 do hookChatFrame(_G["ChatFrame" .. i]) end
    end)
  end
end
