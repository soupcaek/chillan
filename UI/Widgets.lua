-- Chillan? – byggeklosser for det moderne utseendet
local ADDON, ns = ...
local UI = {}
ns.UI = UI
local C = ns.C
local hex = ns.hex

local SLICE_MODE = (Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched) or 0

function UI.Rounded(tex, small)
  local file = small and "RoundedSmall" or "Rounded"
  local m = small and 6 or 12
  tex:SetTexture(ns.TEX .. file)
  if tex.SetTextureSliceMargins then
    tex:SetTextureSliceMargins(m, m, m, m)
    if tex.SetTextureSliceMode then tex:SetTextureSliceMode(SLICE_MODE) end
  end
end

local function roundedBorder(tex, small)
  local file = small and "RoundedSmallBorder" or "RoundedBorder"
  local m = small and 6 or 12
  tex:SetTexture(ns.TEX .. file)
  if tex.SetTextureSliceMargins then
    tex:SetTextureSliceMargins(m, m, m, m)
    if tex.SetTextureSliceMode then tex:SetTextureSliceMode(SLICE_MODE) end
  end
end

-- Panel med avrundede hjørner, fyllfarge og kantlinje
function UI.Panel(parent, fill, line, small, alpha)
  local f = CreateFrame("Frame", nil, parent)
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints()
  UI.Rounded(f.bg, small)
  f.border = f:CreateTexture(nil, "BORDER")
  f.border:SetAllPoints()
  roundedBorder(f.border, small)
  function f:SetColors(fillHex, lineHex, a)
    if fillHex then
      local r, g, b = hex(fillHex)
      self.bg:SetVertexColor(r, g, b, a or 1)
      self.bg:Show()
    else
      self.bg:Hide()
    end
    if lineHex then
      local r, g, b = hex(lineHex)
      self.border:SetVertexColor(r, g, b, 1)
      self.border:Show()
    else
      self.border:Hide()
    end
  end
  f:SetColors(fill, line, alpha)
  return f
end

function UI.SolidLine(parent, h)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture(hex(h or C.line))
  return t
end

function UI.Text(parent, size, weight, color, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  local font = ns.FONT
  if weight == "semi" then font = ns.FONT_SEMI elseif weight == "bold" then font = ns.FONT_BOLD end
  if not fs:SetFont(font, size or 13, "") then
    fs:SetFontObject(GameFontNormal)
  end
  fs:SetTextColor(hex(color or C.text))
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(false)
  fs:SetShadowOffset(0, 0)
  return fs
end

function UI.Icon(parent, name, size, color)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetTexture(ns.TEX .. "Icon" .. name)
  t:SetSize(size or 16, size or 16)
  t:SetVertexColor(hex(color or C.text))
  return t
end

---------------------------------------------------------------------------
-- Flyttbare elementer: dra med venstre museknapp, posisjonen huskes
---------------------------------------------------------------------------
UI.movables = {}

local function savePos(frame, key)
  local point, _, rel, x, y = frame:GetPoint(1)
  ns.db.settings.pos = ns.db.settings.pos or {}
  ns.db.settings.pos[key] = { point = point, rel = rel, x = x, y = y }
end

function UI.RestorePos(frame)
  local key = frame.posKey
  local pos = ns.db.settings.pos and ns.db.settings.pos[key]
  frame:ClearAllPoints()
  if pos and pos.point then
    frame:SetPoint(pos.point, UIParent, pos.rel or pos.point, pos.x or 0, pos.y or 0)
  else
    frame.defaultPos(frame)
  end
end

-- Låst? (Innstillinger → Lås posisjoner, eller /chill lås)
function UI.IsLocked() return ns.db and ns.db.settings.locked end

-- target = rammen som faktisk flyttes (f.eks. et anker for en stabel med varsler)
function UI.Movable(frame, key, defaultPos, target)
  target = target or frame
  target.posKey = key
  target.defaultPos = defaultPos
  target:SetMovable(true)
  target:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:HookScript("OnDragStart", function()
    if UI.IsLocked() then return end
    target.isMoving = true
    target:StartMoving()
  end)
  frame:HookScript("OnDragStop", function()
    if not target.isMoving then return end
    target.isMoving = nil
    target:StopMovingOrSizing()
    savePos(target, key)
    if target.OnMoved then target:OnMoved() end
  end)
  UI.movables[key] = target
  UI.RestorePos(target)
end

function UI.ResetPositions()
  ns.db.settings.pos = {}
  ns.db.settings.minibarPos = nil
  for _, f in pairs(UI.movables) do UI.RestorePos(f) end
end

---------------------------------------------------------------------------
-- Knapper
---------------------------------------------------------------------------
local STYLES = {
  primary = { fill = C.accent, line = nil, text = C.accentText, hover = "DDE3EA", weight = "semi" },
  secondary = { fill = C.active, line = C.activeLine, text = C.text, hover = "33383E", weight = "semi" },
  ghost = { fill = nil, line = C.inputLine, text = C.muted, hover = C.card, weight = nil },
  danger = { fill = C.sosBg, line = C.sosLine, text = C.sosText, hover = "4A2427", weight = "semi" },
  nav = { fill = nil, line = nil, text = C.dim, hover = C.card, weight = nil },
}

UI.STYLES = STYLES

function UI.Button(parent, w, h, label, style, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w or 80, h or 30)
  b.panel = UI.Panel(b, nil, nil, true)
  b.panel:SetAllPoints()
  b.panel:SetFrameLevel(b:GetFrameLevel())
  b.label = UI.Text(b, 12, nil, C.text)
  b.label:SetPoint("CENTER", 0, 0)
  b.label:SetText(label or "")
  function b:SetStyle(st)
    self.style = STYLES[st] or STYLES.secondary
    local s = self.style
    self.panel:SetColors(s.fill, s.line)
    self.label:SetFont(s.weight == "semi" and ns.FONT_SEMI or ns.FONT, 12, "")
    self.label:SetTextColor(hex(s.text))
    if self.icon then self.icon:SetVertexColor(hex(s.text)) end
  end
  function b:SetLabel(t) self.label:SetText(t) end
  function b:SetIcon(name, size)
    if not self.icon then self.icon = self:CreateTexture(nil, "ARTWORK") end
    self.icon:SetTexture(ns.TEX .. "Icon" .. name)
    self.icon:SetSize(size or 14, size or 14)
    self.icon:SetVertexColor(hex(self.style.text))
    if self.label:GetText() and self.label:GetText() ~= "" then
      self.icon:SetPoint("RIGHT", self.label, "LEFT", -6, 0)
      self.label:ClearAllPoints()
      self.label:SetPoint("CENTER", ((size or 14) + 6) / 2, 0)
    else
      self.icon:SetPoint("CENTER")
    end
  end
  b:SetStyle(style or "secondary")
  b:SetScript("OnEnter", function(self)
    if self.style.hover then self.panel:SetColors(self.style.hover, self.style.line) end
    if self.tooltip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(self.tooltip, 1, 1, 1)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(self)
    self.panel:SetColors(self.style.fill, self.style.line)
    if self.tooltip then GameTooltip:Hide() end
  end)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

function UI.IconButton(parent, size, icon, tooltip, onClick)
  local b = UI.Button(parent, size, size, "", "ghost", onClick)
  b:SetIcon(icon, math.floor(size * 0.5))
  b.icon:SetVertexColor(hex(C.accent))
  b.tooltip = tooltip
  local base = b.SetStyle
  function b:SetStyle(st) base(self, st) if self.icon then self.icon:SetVertexColor(hex(C.accent)) end end
  return b
end

-- Liten "pille" med farget tekst
function UI.Pill(parent)
  local p = UI.Panel(parent, nil, nil, true)
  p:SetHeight(20)
  p.text = UI.Text(p, 11, "semi", C.text)
  p.text:SetPoint("CENTER")
  function p:Set(label, colorHex)
    self.text:SetText(label)
    self.text:SetTextColor(hex(colorHex))
    local r, g, b = hex(colorHex)
    self.bg:SetVertexColor(r, g, b, 0.14)
    self.bg:Show()
    self.border:Hide()
    self:SetWidth(self.text:GetStringWidth() + 18)
  end
  return p
end

-- Rund avatar med forbokstav i klassefarge og statusprikk
function UI.Avatar(parent, size)
  local a = CreateFrame("Frame", nil, parent)
  a:SetSize(size, size)
  a.bg = a:CreateTexture(nil, "BACKGROUND")
  a.bg:SetAllPoints()
  a.bg:SetTexture(ns.TEX .. "Circle")
  a.bg:SetVertexColor(hex(C.active))
  a.letter = UI.Text(a, math.floor(size * 0.42), "bold", C.text)
  a.letter:SetPoint("CENTER", 0, 0)
  a.letter:SetJustifyH("CENTER")
  local ds = math.max(8, math.floor(size * 0.32))
  a.ring = a:CreateTexture(nil, "ARTWORK")
  a.ring:SetTexture(ns.TEX .. "Circle")
  a.ring:SetSize(ds + 4, ds + 4)
  a.ring:SetPoint("BOTTOMRIGHT", 2, -2)
  a.ring:SetVertexColor(hex(C.card))
  a.dot = a:CreateTexture(nil, "OVERLAY")
  a.dot:SetTexture(ns.TEX .. "Circle")
  a.dot:SetSize(ds, ds)
  a.dot:SetPoint("CENTER", a.ring, "CENTER")
  function a:Set(name, classFile, dotHex, ringHex)
    self.letter:SetText((name or "?"):sub(1, 1):upper())
    self.letter:SetTextColor(ns.ClassColor(classFile))
    if dotHex then
      self.dot:SetVertexColor(hex(dotHex))
      self.ring:SetVertexColor(hex(ringHex or C.card))
      self.dot:Show() self.ring:Show()
    else
      self.dot:Hide() self.ring:Hide()
    end
  end
  return a
end

---------------------------------------------------------------------------
-- Tekstfelt
---------------------------------------------------------------------------
function UI.EditBox(parent, w, h, placeholder, onEnter)
  local holder = UI.Panel(parent, C.input, C.inputLine, true)
  holder:SetSize(w or 160, h or 34)
  local e = CreateFrame("EditBox", nil, holder)
  e:SetPoint("TOPLEFT", 10, 0)
  e:SetPoint("BOTTOMRIGHT", -10, 0)
  e:SetFont(ns.FONT, 13, "")
  e:SetTextColor(hex(C.text))
  e:SetAutoFocus(false)
  e:SetMaxLetters(200)
  e.ph = UI.Text(holder, 13, nil, C.dim)
  e.ph:SetPoint("LEFT", 10, 0)
  e.ph:SetPoint("RIGHT", -10, 0)
  e.ph:SetText(placeholder or "")
  local function upd()
    if e:GetText() == "" and not e:HasFocus() then e.ph:Show() else e.ph:Hide() end
  end
  e:SetScript("OnEditFocusGained", function() holder:SetColors(C.input, C.accent) upd() end)
  e:SetScript("OnEditFocusLost", function() holder:SetColors(C.input, C.inputLine) upd() end)
  e:SetScript("OnTextChanged", upd)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  e:SetScript("OnEnterPressed", function(self)
    if onEnter then onEnter(self) else self:ClearFocus() end
  end)
  holder:EnableMouse(true)
  holder:SetScript("OnMouseDown", function() e:SetFocus() end)
  holder.edit = e
  function holder:GetText() return e:GetText() end
  function holder:SetText(t) e:SetText(t or "") upd() end
  upd()
  return holder
end

---------------------------------------------------------------------------
-- Avkrysning
---------------------------------------------------------------------------
function UI.Check(parent, label, getter, setter)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(260, 26)
  b.box = UI.Panel(b, C.input, C.inputLine, true)
  b.box:SetSize(18, 18)
  b.box:SetPoint("LEFT")
  b.mark = UI.Icon(b.box, "Check", 14, C.accentText)
  b.mark:SetPoint("CENTER")
  b.label = UI.Text(b, 13, nil, C.text2)
  b.label:SetPoint("LEFT", b.box, "RIGHT", 10, 0)
  b.label:SetText(label)
  function b:Refresh()
    if getter() then
      self.box:SetColors(C.accent, nil)
      self.mark:Show()
    else
      self.box:SetColors(C.input, C.inputLine)
      self.mark:Hide()
    end
  end
  b:SetScript("OnClick", function(self)
    setter(not getter())
    self:Refresh()
  end)
  b:Refresh()
  return b
end

---------------------------------------------------------------------------
-- Virtuell liste med musehjul og tynn rullefelt-indikator
---------------------------------------------------------------------------
function UI.List(parent, rowHeight, gap, createRow, updateRow)
  local list = CreateFrame("Frame", nil, parent)
  list:SetClipsChildren(true)
  list.rows = {}
  list.data = {}
  list.offset = 0
  list.rowHeight = rowHeight
  list.gap = gap or 6
  list.thumb = list:CreateTexture(nil, "OVERLAY")
  list.thumb:SetColorTexture(hex(C.activeLine))
  list.thumb:SetWidth(3)
  list.empty = UI.Text(list, 12, nil, C.dim)
  list.empty:SetPoint("TOP", 0, -20)
  list.empty:SetJustifyH("CENTER")
  list.empty:SetWordWrap(true)
  list.empty:SetWidth(300)

  local function visibleCount()
    return math.max(1, math.ceil((list:GetHeight() or 0) / (rowHeight + list.gap)) + 1)
  end

  function list:Render()
    local n = visibleCount()
    local maxOffset = math.max(0, #self.data * (rowHeight + self.gap) - self.gap - self:GetHeight())
    if self.offset > maxOffset then self.offset = maxOffset end
    if self.offset < 0 then self.offset = 0 end
    local first = math.floor(self.offset / (rowHeight + self.gap)) + 1
    for i = 1, n do
      local row = self.rows[i]
      if not row then
        row = createRow(self)
        row:SetHeight(rowHeight)
        self.rows[i] = row
      end
      local idx = first + i - 1
      local item = self.data[idx]
      if item then
        row:ClearAllPoints()
        local y = (idx - 1) * (rowHeight + self.gap) - self.offset
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", -6, -y)
        row.item = item
        updateRow(row, item, idx)
        row:Show()
      else
        row:Hide()
      end
    end
    for i = n + 1, #self.rows do self.rows[i]:Hide() end
    local total = #self.data * (rowHeight + self.gap)
    local h = self:GetHeight()
    if total > h and h > 0 then
      local th = math.max(20, h * h / total)
      self.thumb:SetHeight(th)
      self.thumb:ClearAllPoints()
      self.thumb:SetPoint("TOPRIGHT", 0, -((h - th) * (self.offset / math.max(1, total - h))))
      self.thumb:Show()
    else
      self.thumb:Hide()
    end
    if #self.data == 0 and self.emptyText then
      self.empty:SetText(self.emptyText)
      self.empty:Show()
    else
      self.empty:Hide()
    end
  end

  function list:SetData(data)
    self.data = data or {}
    self:Render()
  end

  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function(self, delta)
    self.offset = self.offset - delta * (rowHeight + self.gap)
    self:Render()
  end)
  list:SetScript("OnSizeChanged", function(self) self:Render() end)
  return list
end

---------------------------------------------------------------------------
-- Rullende meldingsfelt (chat og feed)
---------------------------------------------------------------------------
function UI.MessageFrame(parent, size)
  local m = CreateFrame("ScrollingMessageFrame", nil, parent)
  m:SetFont(ns.FONT, size or 13, "")
  m:SetJustifyH("LEFT")
  m:SetFading(false)
  m:SetMaxLines(300)
  m:SetInsertMode("BOTTOM")
  m:SetSpacing(4)
  m:SetShadowOffset(0, 0)
  m:SetTextColor(hex(C.text2))
  m:EnableMouseWheel(true)
  m:SetScript("OnMouseWheel", function(self, delta)
    if delta > 0 then self:ScrollUp() self:ScrollUp() else self:ScrollDown() self:ScrollDown() end
  end)
  if m.SetHyperlinksEnabled then m:SetHyperlinksEnabled(true) end
  m:SetScript("OnHyperlinkEnter", function(self, link)
    if type(link) == "string" and link:find("^item:") then
      GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
      pcall(GameTooltip.SetHyperlink, GameTooltip, link)
      GameTooltip:Show()
    end
  end)
  m:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
  return m
end

function UI.InlineIcon(name, colorHex, size)
  local r, g, b = hex(colorHex or C.text)
  size = size or 14
  return string.format("|T%sIcon%s:%d:%d:0:0:64:64:0:64:0:64:%d:%d:%d|t", ns.TEX, name, size, size,
    math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

---------------------------------------------------------------------------
-- Enkel nedtrekksmeny
---------------------------------------------------------------------------
local menu
function UI.Menu(anchor, items, below)
  if not menu then
    menu = UI.Panel(UIParent, C.card, C.activeLine, false)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:EnableMouse(true)
    menu.buttons = {}
    menu:Hide()
    menu.closer = CreateFrame("Button", nil, UIParent)
    menu.closer:SetAllPoints(UIParent)
    menu.closer:SetFrameStrata("FULLSCREEN")
    menu.closer:Hide()
    menu.closer:SetScript("OnClick", function() menu:Hide() menu.closer:Hide() end)
  end
  for _, b in ipairs(menu.buttons) do b:Hide() end
  local w = 180
  for i, it in ipairs(items) do
    local b = menu.buttons[i]
    if not b then
      b = UI.Button(menu, w - 12, 28, "", "nav")
      b.label:ClearAllPoints()
      b.label:SetPoint("LEFT", 10, 0)
      menu.buttons[i] = b
    end
    b:SetLabel(it.text)
    b.label:SetTextColor(hex(it.color or C.text2))
    b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 30)
    b:SetScript("OnClick", function()
      menu:Hide() menu.closer:Hide()
      it.func()
    end)
    b:Show()
  end
  menu:SetSize(w, #items * 30 + 10)
  menu:ClearAllPoints()
  if below then
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
  else
    menu:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
  end
  menu:SetClampedToScreen(true)
  menu.closer:Show()
  menu:Show()
end

---------------------------------------------------------------------------
-- Dialog med inntil tre felt
---------------------------------------------------------------------------
local dialog
function UI.Prompt(title, fields, onOk)
  if not dialog then
    dialog = UI.Panel(UIParent, C.window, C.activeLine, false)
    dialog:SetSize(360, 200)
    dialog:SetPoint("CENTER", 0, 80)
    dialog:SetFrameStrata("DIALOG")
    dialog:EnableMouse(true)
    dialog.title = UI.Text(dialog, 15, "semi", C.text)
    dialog.title:SetPoint("TOPLEFT", 18, -16)
    dialog.inputs = {}
    dialog.labels = {}
    for i = 1, 3 do
      local l = UI.Text(dialog, 12, nil, C.dim)
      dialog.labels[i] = l
      local e = UI.EditBox(dialog, 324, 32, "", function() dialog.ok:Click() end)
      dialog.inputs[i] = e
    end
    dialog.ok = UI.Button(dialog, 100, 32, "OK", "primary")
    dialog.cancel = UI.Button(dialog, 90, 32, "Avbryt", "ghost", function() dialog:Hide() end)
  end
  dialog.title:SetText(title)
  local y = -48
  for i = 1, 3 do
    local fdef = fields[i]
    local l, e = dialog.labels[i], dialog.inputs[i]
    if fdef then
      l:SetText(fdef.label or "")
      l:ClearAllPoints()
      l:SetPoint("TOPLEFT", 18, y)
      e:ClearAllPoints()
      e:SetPoint("TOPLEFT", 18, y - 18)
      e:SetText(fdef.value or "")
      e.edit.ph:SetText(fdef.placeholder or "")
      l:Show() e:Show()
      y = y - 60
    else
      l:Hide() e:Hide()
    end
  end
  dialog:SetHeight(-y + 60)
  dialog.ok:ClearAllPoints()
  dialog.ok:SetPoint("BOTTOMRIGHT", -18, 16)
  dialog.cancel:ClearAllPoints()
  dialog.cancel:SetPoint("RIGHT", dialog.ok, "LEFT", -8, 0)
  dialog.ok:SetScript("OnClick", function()
    local vals = {}
    for i = 1, 3 do vals[i] = dialog.inputs[i]:GetText() end
    local keep = onOk(vals[1], vals[2], vals[3])
    if not keep then dialog:Hide() end
  end)
  dialog:Show()
  dialog.inputs[1].edit:SetFocus()
end
