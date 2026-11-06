-- Chillan? – det som vises på skjermen: minibar, varsler, SOS, kveldsoppsummering, profilkort
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
  m:SetScript("OnDragStart", function(self) self:StartMoving() end)
  m:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint(1)
    ns.db.settings.minibarPos = { point = point, x = x, y = y }
  end)
  m:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then ns.Window:Toggle("chat") else ns.Window:Toggle() end
  end)

  m.panel = UI.Panel(m, C.window, C.inputLine, false, 0.92)
  m.panel:SetAllPoints()
  m.panel:SetFrameLevel(m:GetFrameLevel())
  m.logo = UI.Text(m, 14, "bold", C.text)
  m.logo:SetPoint("LEFT", 12, 0)
  m.logo:SetText("Chillan|cffc8d1dc?|r")
  m.avatars = {}
  for i = 1, 8 do
    local a = UI.Avatar(m, 24)
    a.bg:SetVertexColor(hex(C.active))
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
        GameTooltip:AddDoubleLine((c.name or "?") .. "  " .. (c.level or ""), (p.live and p.live.zone) or "", r, g, b, 0.6, 0.63, 0.66)
        any = true
      end
    end
    if not any then GameTooltip:AddLine("Ingen andre online", 0.6, 0.63, 0.66) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Venstreklikk: åpne  ·  Høyreklikk: chat  ·  Dra: flytt", 0.52, 0.55, 0.57)
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
  for i, a in ipairs(m.avatars) do
    local p = online[i]
    if p then
      local c = ns:PersonChar(p) or {}
      a:Set(c.name, c.class, nil)
      a:ClearAllPoints()
      a:SetPoint("LEFT", x, 0)
      x = x + 18
      a:Show()
    else
      a:Hide()
    end
  end
  if #online > 0 then x = x + 10 end
  m.count:ClearAllPoints()
  m.count:SetPoint("LEFT", x, 0)
  m.count:SetText(#online .. " online")
  m:SetWidth(x + m.count:GetStringWidth() + 14)
end

---------------------------------------------------------------------------
-- Popup-varsler
---------------------------------------------------------------------------
local KIND = {
  online = { icon = "Login", color = C.green, label = "Online" },
  ding = { icon = "Up", color = C.green, label = "Ding!" },
  enemy = { icon = "Target", color = C.red, label = "Fiendelogg" },
  lfg = { icon = "LFG", color = C.accent, label = "LFG" },
  join = { icon = "Friends", color = C.accent, label = "Vil bli med" },
  craft = { icon = "Mail", color = C.purple, label = "Craft" },
  star = { icon = "Star", color = C.amber, label = "Milepæl" },
  sos = { icon = "SOS", color = C.red, label = "SOS" },
  trophy = { icon = "Trophy", color = C.gold, label = "Ukens vinner" },
  info = { icon = "Star", color = C.accent, label = "Chillan?" },
}

local toasts, pool = {}, {}

local function layoutToasts()
  local y = -110
  for _, t in ipairs(toasts) do
    t:ClearAllPoints()
    t:SetPoint("TOP", UIParent, "TOP", 0, y)
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
  t.panel = UI.Panel(t, C.window, C.activeLine, false, 0.96)
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
  t.close.icon:SetVertexColor(hex(C.dim))
  t:SetScript("OnUpdate", function(self, dt)
    self.life = self.life - dt
    if self.life < 0.6 then self:SetAlpha(math.max(0, self.life / 0.6)) end
    if self.life <= 0 then removeToast(self) end
  end)
  t:SetScript("OnEnter", function(self) self.life = math.max(self.life, 4) self:SetAlpha(1) end)
  return t
end

function O:Toast(info)
  if not ns.db.settings.toasts and info.kind ~= "join" and info.kind ~= "craft" and info.kind ~= "sos" then return end
  local k = KIND[info.kind] or KIND.info
  local t = newToast()
  t.kind:SetText(k.label:upper())
  t.icon:SetTexture(ns.TEX .. "Icon" .. k.icon)
  t.icon:SetVertexColor(hex(k.color))
  local title, text = info.title, info.text
  if info.kind == "ding" and info.item then
    local it = info.item
    local p = ns:GetPerson(it.pid) or {}
    local c = (p.chars and p.chars[it.char]) or {}
    title = ns.Colorize(ns.ShortName(it.char), ns.ClassHex(c.class)) .. " nådde level " .. tostring(it.a)
    local parts = {}
    if tonumber(it.b) then parts[#parts + 1] = "/played " .. ns.Duration(tonumber(it.b)) end
    if it.first then parts[#parts + 1] = "først i gjengen!"
    elseif it.place then parts[#parts + 1] = "nr. " .. it.place .. " i gjengen" end
    text = table.concat(parts, " · ")
  end
  t.title:SetText(title or "")
  t.text:SetText(text or "")
  t.title:SetPoint("RIGHT", -16, 0)
  t.text:SetPoint("RIGHT", -16, 0)
  t.btn:Hide()
  if info.kind == "join" and info.char then
    t.btn:SetLabel("Inviter")
    t.btn:SetScript("OnClick", function() ns.Invite(info.char) removeToast(t) end)
    t.btn:Show()
  elseif info.kind == "craft" and info.char then
    t.btn:SetLabel("Hvisk")
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
-- SOS
---------------------------------------------------------------------------
function O:CreateSOS()
  local s = CreateFrame("Frame", "ChillanSOS", UIParent)
  self.sos = s
  s:SetSize(320, 124)
  s:SetPoint("TOPRIGHT", -24, -200)
  s:SetFrameStrata("DIALOG")
  s:EnableMouse(true)
  s:Hide()
  s.panel = UI.Panel(s, "2A181A", "6A2E31", false, 0.97)
  s.panel:SetAllPoints()
  s.panel:SetFrameLevel(s:GetFrameLevel())
  s.icon = UI.Icon(s, "SOS", 20, C.sosText)
  s.icon:SetPoint("TOPLEFT", 14, -14)
  s.title = UI.Text(s, 14, "bold", "FFD6D7")
  s.title:SetPoint("LEFT", s.icon, "RIGHT", 10, 0)
  s.title:SetPoint("RIGHT", -40, 0)
  s.close = UI.IconButton(s, 24, "Close", nil, function() s:Hide() end)
  s.close:SetPoint("TOPRIGHT", -8, -8)
  s.close.panel:SetColors(nil, nil)
  s.close.style = { text = "E5A3A5", hover = "3A2225" }
  s.close.icon:SetVertexColor(hex("E5A3A5"))
  s.text = UI.Text(s, 13, nil, "F1D9DA")
  s.text:SetPoint("TOPLEFT", 14, -44)
  s.text:SetPoint("RIGHT", -14, 0)
  s.map = UI.Button(s, 140, 32, "Vis på kart", "primary")
  s.map:SetPoint("BOTTOMLEFT", 14, 14)
  s.map.panel:SetColors("FFD6D7", nil)
  s.map.style = { fill = "FFD6D7", text = "2A181A", hover = "FFE6E7", weight = "semi" }
  s.map.label:SetTextColor(hex("2A181A"))
  s.reply = UI.Button(s, 140, 32, "Svar: på vei", "danger")
  s.reply:SetPoint("BOTTOMRIGHT", -14, 14)
  s:SetScript("OnUpdate", function(self, dt)
    self.life = (self.life or 0) - dt
    if self.life <= 0 then self:Hide() end
  end)
end

function O:ShowSOS(item)
  local s = self.sos
  local p = ns:GetPerson(item.pid) or {}
  local c = (p.chars and p.chars[item.char]) or {}
  s.title:SetText("SOS fra " .. ns.Colorize(ns.ShortName(item.char), ns.ClassHex(c.class)))
  local mapID, x, y = tonumber(item.b), tonumber(item.c), tonumber(item.d)
  local where = tostring(item.a or "?")
  if x and y then where = where .. string.format(" (%.0f, %.0f)", x / 10, y / 10) end
  s.text:SetText("Blir ganket i " .. where)
  s.map:SetScript("OnClick", function()
    if mapID and x and y then
      ns.SetWaypoint(mapID, x / 1000, y / 1000)
      ns.OpenMapAt(mapID)
    end
  end)
  s.map:SetEnabled(mapID ~= nil)
  s.reply:SetScript("OnClick", function()
    ns.Data:AnswerSOS(item)
    s.reply:SetLabel("Sendt!")
  end)
  s.reply:SetLabel("Svar: på vei")
  s.life = 45
  s:Show()
end

---------------------------------------------------------------------------
-- Kveldsoppsummering
---------------------------------------------------------------------------
function O:CreateSummary()
  local s = CreateFrame("Frame", "ChillanSummary", UIParent)
  self.summary = s
  s:SetSize(380, 196)
  s:SetPoint("BOTTOM", 0, 180)
  s:SetFrameStrata("DIALOG")
  s:EnableMouse(true)
  s:Hide()
  s.panel = UI.Panel(s, C.window, C.inputLine, false, 0.97)
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
  close.icon:SetVertexColor(hex(C.dim))
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
  s.title:SetText(previous and "Forrige økt" or "Kvelden din")
  s.sub:SetText(previous and (ns.ShortName(sum.char) .. " · " .. date("%d.%m %H:%M", sum.at)) or ns.ShortName(sum.char))
  local vals = {
    { ns.Duration(sum.online), "online" },
    { ((sum.levels or 0) > 0 and "+" or "") .. (sum.levels or 0), "levels" },
    { sum.quests or 0, "quests" },
    { "+" .. ns.Money(sum.gold), "gull tjent" },
    { sum.deaths or 0, "dødsfall" },
    { sum.sos or 0, "SOS sendt" },
  }
  for i, cell in ipairs(s.cells) do
    cell.v:SetText(vals[i][1])
    cell.k:SetText(vals[i][2])
  end
  s:Show()
end

---------------------------------------------------------------------------
-- Profilkort (hover)
---------------------------------------------------------------------------
function O:CreateProfile()
  local f = CreateFrame("Frame", "ChillanProfileCard", UIParent)
  self.profile = f
  f:SetWidth(300)
  f:SetFrameStrata("TOOLTIP")
  f:SetClampedToScreen(true)
  f:Hide()
  f.panel = UI.Panel(f, C.window, C.activeLine, false, 0.98)
  f.panel:SetAllPoints()
  f.panel:SetFrameLevel(f:GetFrameLevel())
  f.avatar = UI.Avatar(f, 40)
  f.avatar:SetPoint("TOPLEFT", 14, -14)
  f.name = UI.Text(f, 14, "semi", C.text)
  f.name:SetPoint("TOPLEFT", f.avatar, "TOPRIGHT", 12, -3)
  f.name:SetPoint("RIGHT", -12, 0)
  f.sub = UI.Text(f, 12, nil, C.dim)
  f.sub:SetPoint("BOTTOMLEFT", f.avatar, "BOTTOMRIGHT", 12, 3)
  f.sub:SetPoint("RIGHT", -12, 0)
  f.keys, f.vals = {}, {}
  for i = 1, 7 do
    local k = UI.Text(f, 12, nil, C.dim)
    k:SetPoint("TOPLEFT", 14, -66 - (i - 1) * 20)
    k:SetWidth(92)
    local v = UI.Text(f, 12, nil, C.text2)
    v:SetPoint("TOPLEFT", 106, -66 - (i - 1) * 20)
    v:SetPoint("RIGHT", -12, 0)
    f.keys[i], f.vals[i] = k, v
  end
end

function O:ShowProfile(anchor, pid)
  local p = ns:GetPerson(pid)
  if not p then return end
  local f = self.profile
  local c = ns:PersonChar(p) or {}
  local online = ns:IsOnline(p)
  f.avatar:Set(c.name, c.class, online and C.green or nil, C.window)
  f.name:SetText(ns.Colorize(c.name or "?", ns.ClassHex(c.class)) .. ((p.nick and p.nick ~= "" and p.nick ~= c.name) and ns.Colorize("  " .. p.nick, C.dim) or ""))
  f.sub:SetText(online and ("Online · " .. ((p.live and p.live.zone) or "")) or ("Sist sett " .. ns.Ago(p.lastSeen)))
  local rows = {}
  local className = c.class and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class] or c.class) or ""
  rows[#rows + 1] = { "Main", string.format("Lvl %s %s %s", c.level or "?", c.race or "", className) }
  local alts = {}
  for full, ch in pairs(p.chars) do
    if full ~= p.main then alts[#alts + 1] = ns.Colorize(ch.name or ns.ShortName(full), ns.ClassHex(ch.class)) .. " " .. (ch.level or "") end
  end
  if #alts > 0 then rows[#rows + 1] = { "Alts", table.concat(alts, ", ", 1, math.min(3, #alts)) } end
  local profs = {}
  for _, pr in ipairs(p.profs or {}) do profs[#profs + 1] = pr.name .. " " .. pr.skill end
  if #profs > 0 then rows[#rows + 1] = { "Profesjoner", table.concat(profs, " · ") } end
  local played = ns:PersonPlayed(p)
  if played > 0 then rows[#rows + 1] = { "/played", ns.Duration(played) } end
  rows[#rows + 1] = { "Denne uka", ns.Duration(ns:WeekStat(p, "Online")) .. " · " .. math.floor(ns:WeekStat(p, "Quests")) .. " quests" }
  if p.deathZone then rows[#rows + 1] = { "Sist død", p.deathZone .. ", " .. ns.Ago(p.deathAt) } end
  for i = 1, 7 do
    local r = rows[i]
    if r then
      f.keys[i]:SetText(r[1]) f.vals[i]:SetText(r[2])
      f.keys[i]:Show() f.vals[i]:Show()
    else
      f.keys[i]:Hide() f.vals[i]:Hide()
    end
  end
  f:SetHeight(76 + #rows * 20)
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 10, 0)
  f:Show()
end

function O:HideProfile()
  if self.profile then self.profile:Hide() end
end

function O:Init()
  self:CreateMinibar()
  self:CreateSOS()
  self:CreateSummary()
  self:CreateProfile()
  ns:Listen("TOAST", function(info) O:Toast(info) end)
  ns:Listen("SOS", function(item) O:ShowSOS(item) end)
  ns:Listen("SHOW_SUMMARY", function(sum, previous) O:ShowSummary(sum, previous) end)
end
