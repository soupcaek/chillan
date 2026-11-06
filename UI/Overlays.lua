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
        GameTooltip:AddDoubleLine(ns.FirstName(c.name or "?") .. "  " .. (c.level or ""), (p.live and p.live.zone) or "", r, g, b, 0.6, 0.63, 0.66)
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
  mats = { icon = "Mail", color = C.amber, label = "Trenger mats" },
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
-- Profilkort (hover) – stor, lesbar tekst og rader som brytes riktig
---------------------------------------------------------------------------
local CARD_W, KEY_W = 340, 96

function O:CreateProfile()
  local f = CreateFrame("Frame", "ChillanProfileCard", UIParent)
  self.profile = f
  f:SetWidth(CARD_W)
  f:SetFrameStrata("TOOLTIP")
  f:SetClampedToScreen(true)
  f:Hide()
  f.panel = UI.Panel(f, "1B1E22", C.activeLine, false)
  f.panel:SetAllPoints()
  f.panel:SetFrameLevel(f:GetFrameLevel())
  f.avatar = UI.Avatar(f, 42)
  f.avatar:SetPoint("TOPLEFT", 16, -16)
  f.name = UI.Text(f, 15, "semi", C.text)
  f.name:SetPoint("TOPLEFT", f.avatar, "TOPRIGHT", 12, -2)
  f.name:SetPoint("RIGHT", -14, 0)
  f.sub = UI.Text(f, 12, nil, C.text2)
  f.sub:SetPoint("BOTTOMLEFT", f.avatar, "BOTTOMRIGHT", 12, 2)
  f.sub:SetPoint("RIGHT", -14, 0)
  f.divider = UI.SolidLine(f)
  f.divider:SetHeight(1)
  f.divider:SetPoint("TOPLEFT", 16, -70)
  f.divider:SetPoint("TOPRIGHT", -16, -70)
  f.rows = {}
  for i = 1, 8 do
    local k = UI.Text(f, 12, nil, C.muted)
    k:SetWidth(KEY_W)
    local v = UI.Text(f, 13, nil, C.text)
    v:SetWidth(CARD_W - 32 - KEY_W)
    v:SetWordWrap(true)
    v:SetJustifyV("TOP")
    f.rows[i] = { k = k, v = v }
  end
end

function O:ShowProfile(anchor, pid)
  local p = ns:GetPerson(pid)
  if not p then return end
  local f = self.profile
  local c = ns:PersonChar(p) or {}
  local online = ns:IsOnline(p)
  f.avatar:Set(c.name, c.class, online and C.green or nil, "1B1E22")
  f.name:SetText(ns.Colorize(c.name or "?", ns.ClassHex(c.class)))
  local where = (p.live and p.live.zone) or ""
  f.sub:SetText(online and ("Online" .. (where ~= "" and (" · " .. where) or "")) or ("Offline · sist sett " .. ns.Ago(p.lastSeen)))
  local rows = {}
  local className = c.class and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class] or c.class) or ""
  rows[#rows + 1] = { "Karakter", string.format("Level %s %s %s", c.level or "?", c.race or "", className) }
  local alts = {}
  for full, ch in pairs(p.chars) do
    if full ~= p.main then
      alts[#alts + 1] = ns.Colorize(ns.FirstName(ch.name or full), ns.ClassHex(ch.class)) .. " " .. (ch.level or "")
    end
  end
  if #alts > 0 then rows[#rows + 1] = { "Alts", table.concat(alts, ", ") } end
  local profs = {}
  for _, pr in ipairs(p.profs or {}) do profs[#profs + 1] = pr.name .. " " .. pr.skill end
  if #profs > 0 then rows[#rows + 1] = { "Profesjoner", table.concat(profs, ", ") } end
  local played = ns:PersonPlayed(p)
  if played > 0 then rows[#rows + 1] = { "/played", ns.Duration(played) } end
  rows[#rows + 1] = { "Denne uka", math.floor(ns:WeekStat(p, "Levels")) .. " levels · " .. math.floor(ns:WeekStat(p, "Quests")) .. " quests · " .. ns.Duration(ns:WeekStat(p, "Online")) }
  if p.deathZone then rows[#rows + 1] = { "Sist død", p.deathZone .. " (" .. ns.Ago(p.deathAt) .. ")" } end
  if p.version and p.pid ~= ns.pid then rows[#rows + 1] = { "Versjon", p.version } end
  local y = -82
  for i, r in ipairs(f.rows) do
    local def = rows[i]
    if def then
      r.k:ClearAllPoints()
      r.k:SetPoint("TOPLEFT", 16, y - 1)
      r.v:ClearAllPoints()
      r.v:SetPoint("TOPLEFT", 16 + KEY_W, y)
      r.k:SetText(def[1])
      r.v:SetText(def[2])
      r.k:Show() r.v:Show()
      local h = math.max(16, r.v:GetStringHeight() or 16)
      y = y - h - 8
    else
      r.k:Hide() r.v:Hide()
    end
  end
  f:SetHeight(-y + 10)
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 10, 0)
  f:Show()
end

function O:HideProfile()
  if self.profile then self.profile:Hide() end
end

---------------------------------------------------------------------------
-- Ding midt på skjermen, med gratulasjonsknapper
---------------------------------------------------------------------------
local dingQueue = {}

function O:CreateDing()
  local d = CreateFrame("Frame", "ChillanDing", UIParent)
  self.ding = d
  d:SetSize(440, 168)
  d:SetPoint("CENTER", 0, 170)
  d:SetFrameStrata("DIALOG")
  d:EnableMouse(true)
  d:Hide()
  d.shadow = d:CreateTexture(nil, "BACKGROUND", nil, -8)
  d.shadow:SetTexture(ns.TEX .. "Shadow")
  d.shadow:SetPoint("TOPLEFT", -30, 24)
  d.shadow:SetPoint("BOTTOMRIGHT", 30, -36)
  d.shadow:SetVertexColor(0, 0, 0, 0.8)
  d.panel = UI.Panel(d, C.window, C.activeLine, false, 0.97)
  d.panel:SetAllPoints()
  d.panel:SetFrameLevel(d:GetFrameLevel())
  d.tile = UI.Panel(d, C.active, nil, false)
  d.tile:SetSize(52, 52)
  d.tile:SetPoint("TOPLEFT", 20, -20)
  d.icon = UI.Icon(d.tile, "Up", 26, C.green)
  d.icon:SetPoint("CENTER")
  d.kicker = UI.Text(d, 11, "semi", C.green)
  d.kicker:SetPoint("TOPLEFT", d.tile, "TOPRIGHT", 16, -2)
  d.kicker:SetText("DING!")
  d.title = UI.Text(d, 18, "bold", C.text)
  d.title:SetPoint("LEFT", d.tile, "RIGHT", 16, -2)
  d.title:SetPoint("RIGHT", -20, 0)
  d.text = UI.Text(d, 12, nil, C.text2)
  d.text:SetPoint("BOTTOMLEFT", d.tile, "BOTTOMRIGHT", 16, 0)
  d.text:SetPoint("RIGHT", -20, 0)
  d.close = UI.IconButton(d, 24, "Close", nil, function() O:NextDing() end)
  d.close:SetPoint("TOPRIGHT", -8, -8)
  d.close.panel:SetColors(nil, nil)
  d.close.style = { text = C.dim, hover = C.card }
  d.close.icon:SetVertexColor(hex(C.dim))
  d.buttons = {}
  local bw = math.floor((440 - 40 - 16) / 3)
  for i, label in ipairs(ns.REACTIONS) do
    local b = UI.Button(d, bw, 36, label, i == 1 and "primary" or "secondary")
    b:SetPoint("BOTTOMLEFT", 20 + (i - 1) * (bw + 8), 20)
    d.buttons[i] = b
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
  local c = (p.chars and p.chars[item.char]) or {}
  d.title:SetText(ns.Colorize(ns.FirstName(item.char), ns.ClassHex(c.class)) .. " nådde level " .. tostring(item.a))
  local parts = {}
  if tonumber(item.b) then parts[#parts + 1] = "/played " .. ns.Duration(tonumber(item.b)) end
  if item.first then parts[#parts + 1] = ns.Colorize("først i gjengen!", C.gold)
  elseif item.place and tonumber(item.a) and tonumber(item.a) % 10 == 0 then parts[#parts + 1] = "nr. " .. item.place .. " i gjengen" end
  d.text:SetText(table.concat(parts, " · "))
  d.sent:Hide()
  for i, b in ipairs(d.buttons) do
    b:Show()
    b:SetScript("OnClick", function()
      ns.Data:React(item, i)
      for _, x in ipairs(d.buttons) do x:Hide() end
      d.sent:SetText("Sendt: " .. ns.REACTIONS[i])
      d.sent:Show()
      d.life = 2
    end)
  end
  d.life = 12
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
  b.bg:SetVertexColor(hex(C.window))
  b.ring = b:CreateTexture(nil, "BORDER")
  b.ring:SetTexture(ns.TEX .. "Circle")
  b.ring:SetPoint("TOPLEFT", -1, 1)
  b.ring:SetPoint("BOTTOMRIGHT", 1, -1)
  b.ring:SetVertexColor(hex(C.activeLine))
  b.bg:SetDrawLayer("ARTWORK", 0)
  b.icon = b:CreateTexture(nil, "OVERLAY")
  b.icon:SetTexture(ns.TEX .. "IconFriends")
  b.icon:SetSize(18, 18)
  b.icon:SetPoint("CENTER")
  b.icon:SetVertexColor(hex(C.accent))
  b.dot = b:CreateTexture(nil, "OVERLAY", nil, 2)
  b.dot:SetTexture(ns.TEX .. "Circle")
  b.dot:SetSize(9, 9)
  b.dot:SetPoint("TOPRIGHT", -1, -1)
  b.dot:SetVertexColor(hex(C.green))

  local function place()
    local a = math.rad(ns.db.settings.minimapAngle or 200)
    local r = (Minimap:GetWidth() / 2) + 6
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
  end
  self.placeMinimap = place
  b:SetScript("OnDragStart", function(self)
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
    if btn == "RightButton" then ns.Window:Toggle("chat") else ns.Window:Toggle() end
  end)
  b:SetScript("OnEnter", function(self)
    self.ring:SetVertexColor(hex(C.accent))
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Chillan?", 1, 1, 1)
    local n = ns.Window.OnlineCount and ns.Window:OnlineCount() or 0
    GameTooltip:AddLine(n .. " venner online", 0.79, 0.8, 0.82)
    GameTooltip:AddLine("Klikk: åpne · Høyreklikk: chat · Dra: flytt", 0.6, 0.63, 0.66)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(self)
    self.ring:SetVertexColor(hex(C.activeLine))
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

function O:Init()
  self:CreateMinibar()
  self:CreateSOS()
  self:CreateSummary()
  self:CreateProfile()
  self:CreateDing()
  self:CreateMinimapButton()
  ns:Listen("DING", function(item) O:ShowDing(item) end)
  ns:Listen("TOAST", function(info) O:Toast(info) end)
  ns:Listen("SOS", function(item) O:ShowSOS(item) end)
  ns:Listen("SHOW_SUMMARY", function(sum, previous) O:ShowSummary(sum, previous) end)
end
