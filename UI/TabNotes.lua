-- Chillan? – Notes (1.4.72): a personal to-do list and a notepad. Kept in your own saved variables,
-- one list for all your characters, and never sent to anyone.
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

local N = {}
ns.Notes = N
local ROW_H = 28

local function today() return date("%Y-%m-%d") end
-- (dev4) kept in ns.db.myNotes: ns.db.notes holds the gang's map notes (Extras.lua)
function N.Data()
  local old = ns.db.notes
  if type(old) == "table" and (type(old.items) == "table" or type(old.text) == "string") and not ns.db.myNotes then
    ns.db.myNotes = { items = old.items, text = old.text }
  end
  if type(old) == "table" then old.items, old.text = nil, nil end
  ns.db.myNotes = ns.db.myNotes or {}
  local d = ns.db.myNotes
  d.items = d.items or {}
  d.text = d.text or ""
  -- done ones from an earlier day go (the list shows "Done today")
  for i = #d.items, 1, -1 do
    local it = d.items[i]
    if it.done and it.doneDay ~= today() then table.remove(d.items, i) end
  end
  return d
end
function N.Add(text)
  text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return false end
  local d = N.Data()
  d.items[#d.items + 1] = { t = text:sub(1, 200), at = time() }
  return true
end
function N.Toggle(it)
  it.done = not it.done or nil
  it.doneDay = it.done and today() or nil
end
function N.Move(it, dir)
  local items = N.Data().items
  for i, x in ipairs(items) do
    if x == it then
      -- step over to the next open one in that direction (done ones sit below anyway)
      local j = i + dir
      while items[j] and items[j].done do j = j + dir end
      if items[j] then items[i], items[j] = items[j], items[i] end
      return
    end
  end
end
function N.Remove(it)
  local items = N.Data().items
  for i, x in ipairs(items) do if x == it then table.remove(items, i) return end end
end
function N.ClearDone()
  local items = N.Data().items
  for i = #items, 1, -1 do if items[i].done then table.remove(items, i) end end
end
function N.View()
  local open, done = {}, {}
  for _, it in ipairs(N.Data().items) do
    if it.done then done[#done + 1] = it else open[#open + 1] = it end
  end
  local out = {}
  for _, it in ipairs(open) do out[#out + 1] = it end
  if #done > 0 then
    out[#out + 1] = { header = "DONE TODAY" }
    for _, it in ipairs(done) do out[#out + 1] = it end
  end
  return out, #open, #done
end

ns:RegisterTab("notes", "Notes", "Book", function(tab)
  local todo = UI.Section(tab, "To-do")
  local notes = UI.Section(tab, "Notes")
  todo:SetPoint("TOPLEFT", 12, -12)
  todo:SetPoint("BOTTOM", 0, 12)
  todo:SetPoint("RIGHT", tab, "CENTER", 30, 0)
  notes:SetPoint("TOPLEFT", todo, "TOPRIGHT", 12, 0)
  notes:SetPoint("BOTTOMRIGHT", -12, 12)
  -- (dev4) "Pin" on each box: a copy stays on screen while the Chillan window is closed
  local function pinButton(sec, which)
    local b = UI.Button(sec, 56, 20, "Pin", "ghost", function(self)
      N.SetPinned(which, not N.Pinned(which))
      self:SetLabel(N.Pinned(which) and "Unpin" or "Pin")
    end)
    b:SetPoint("RIGHT", sec, "TOPRIGHT", -6, -(sec.stripH / 2))
    b.tooltip = "Keeps this box on your screen while the Chillan window is closed. Drag it to move, the corner to resize."
    sec.right:ClearAllPoints()
    sec.right:SetPoint("RIGHT", b, "LEFT", -8, 0)
    sec.pin = b
    return b
  end
  local todoPin, notesPin = pinButton(todo, "todo"), pinButton(notes, "notes")

  -- adding
  local add
  local function addNow()
    if N.Add(add:GetText()) then add:SetText("") tab:Refresh() end
    add.edit:SetFocus()   -- stays in the box: type the next one
  end
  local addBtn = UI.Button(todo.body, 64, 28, "Add", "secondary", addNow)
  addBtn:SetPoint("TOPRIGHT", todo.body, "TOPRIGHT", 0, 0)
  add = UI.EditBox(todo.body, 100, 28, "Add a to-do and press Enter …", function() addNow() end)
  add:SetPoint("TOPLEFT", 0, 0)
  add:SetPoint("RIGHT", addBtn, "LEFT", -6, 0)

  local clear = UI.Button(todo.body, 90, 24, "Clear done", "ghost", function() N.ClearDone() tab:Refresh() end)
  clear:SetPoint("BOTTOMRIGHT", todo.body, "BOTTOMRIGHT", 0, 0)

  local function hoverOn(row, on)
    for _, b in ipairs(row.tools) do b:SetAlpha(on and 1 or 0) end
    row.hl:SetShown(on and not row.item.header)
  end
  local function createRow(list)
    local row = CreateFrame("Button", nil, list)
    row.stripe = UI.Track(row:CreateTexture(nil, "BACKGROUND"))
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(hex(C.rowAlt or C.window))
    row.hl = UI.Track(row:CreateTexture(nil, "BACKGROUND", nil, 2))
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(hex(C.accent))
    row.hl:SetAlpha(0.10)
    row.hl:Hide()
    row.bar = UI.Track(row:CreateTexture(nil, "ARTWORK"))
    row.bar:SetColorTexture(hex(C.accent))
    row.bar:SetPoint("TOPLEFT") row.bar:SetPoint("BOTTOMLEFT") row.bar:SetWidth(2)
    row.box = UI.Panel(row, C.field or C.input, C.btnLine or C.activeLine, 3)
    row.box:SetSize(14, 14)
    row.box:SetPoint("LEFT", 8, 0)
    row.tick = UI.Icon(row.box, "Check", 12, C.accentText or C.window)
    row.tick:SetPoint("CENTER")
    row.text = UI.Text(row, 12, nil, C.text)
    row.text:SetPoint("LEFT", row.box, "RIGHT", 9, 0)
    row.strike = UI.Track(row:CreateTexture(nil, "OVERLAY"))
    row.strike:SetHeight(1)
    row.strike:SetPoint("LEFT", row.text, "LEFT", 0, 0)
    row.strike:SetPoint("RIGHT", row.text, "RIGHT", 0, 0)
    row.head = UI.Text(row, 10, "bold", C.dim)
    row.head:SetPoint("BOTTOMLEFT", 8, 5)
    local function tool(icon, tip, fn)
      local b = UI.IconButton(row, 20, icon, tip, function() if row.item then fn(row.item) tab:Refresh() end end)
      b:SetAlpha(0)
      b:HookScript("OnEnter", function() hoverOn(row, true) end)
      b:HookScript("OnLeave", function() if not row:IsMouseOver() then hoverOn(row, false) end end)
      return b
    end
    row.del = tool("Close", "Delete", N.Remove)
    row.del:SetPoint("RIGHT", -6, 0)
    row.down = tool("Up", "Move down", function(it) N.Move(it, 1) end)
    row.down:SetPoint("RIGHT", row.del, "LEFT", -2, 0)
    if row.down.icon and row.down.icon.SetRotation then row.down.icon:SetRotation(math.pi) end
    row.up = tool("Up", "Move up", function(it) N.Move(it, -1) end)
    row.up:SetPoint("RIGHT", row.down, "LEFT", -2, 0)
    row.tools = { row.up, row.down, row.del }
    row.text:SetPoint("RIGHT", row.up, "LEFT", -6, 0)
    row:SetScript("OnEnter", function(self) hoverOn(self, true) end)
    row:SetScript("OnLeave", function(self) hoverOn(self, false) end)
    -- a click on the row ticks it
    row:SetScript("OnClick", function(self) if self.item and not self.item.header then N.Toggle(self.item) tab:Refresh() end end)
    return row
  end
  local function updateRow(row, it, idx)
    row.item = it
    local head = it.header ~= nil
    row.head:SetShown(head)
    row.box:SetShown(not head)
    row.text:SetShown(not head)
    row.stripe:SetShown(not head and (idx or 1) % 2 == 0)
    row.bar:SetShown(false)
    hoverOn(row, row:IsMouseOver() and not head)
    if head then
      row.head:SetText(it.header)
      row.strike:Hide()
      for _, b in ipairs(row.tools) do b:Hide() end
      return
    end
    for _, b in ipairs(row.tools) do b:Show() end
    row.up:SetShown(not it.done)
    row.down:SetShown(not it.done)
    row.text:SetText(it.t)
    UI.Track(row.text):SetTextColor(hex(it.done and C.dim or C.text))
    row.box:SetColors(it.done and C.accent or (C.field or C.input), it.done and C.accent or (C.btnLine or C.activeLine))
    row.tick:SetShown(it.done == true)
    row.strike:SetShown(it.done == true)
    UI.Track(row.strike):SetColorTexture(hex(C.dim))
  end
  local list = UI.List(todo.body, ROW_H, 0, createRow, updateRow)
  list:SetPoint("TOPLEFT", add, "BOTTOMLEFT", 0, -8)
  list:SetPoint("BOTTOMRIGHT", clear, "TOPRIGHT", 6, 8)
  list.emptyText = "Nothing to do. Type above and press Enter."

  -- the notepad: saved as you type
  local field = UI.Panel(notes.body, C.field or C.input, C.border or C.inputLine, true)
  field:SetPoint("TOPLEFT", 0, 0)
  field:SetPoint("BOTTOMRIGHT", notes.body, "BOTTOMRIGHT", 0, 22)
  local hint = UI.Text(notes.body, 11, nil, C.dim)
  hint:SetPoint("BOTTOMLEFT", 0, 4)
  hint:SetText("Saved as you type · private")
  local sf = CreateFrame("ScrollFrame", nil, field, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 10, -8)
  sf:SetPoint("BOTTOMRIGHT", -28, 8)
  local ed = CreateFrame("EditBox", nil, sf)
  ed:SetMultiLine(true)
  ed:SetAutoFocus(false)
  ed:SetFont(ns.FONT, 12, "")
  ed:SetMaxLetters(20000)
  UI.Track(ed):SetTextColor(hex(C.text))
  ed:SetWidth(300)
  sf:SetScrollChild(ed)
  sf:SetScript("OnSizeChanged", function(self, w) if w and w > 0 then ed:SetWidth(w) end end)
  ed:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  ed:SetScript("OnTextChanged", function(self, user) if user then N.Data().text = self:GetText() N.UpdatePins() end end)
  -- a click anywhere in the field writes
  field:EnableMouse(true)
  field:SetScript("OnMouseDown", function() ed:SetFocus() ed:SetCursorPosition(#(ed:GetText() or "")) end)
  ed:SetScript("OnEditFocusGained", function() field:SetColors(C.field or C.input, C.accent) end)
  ed:SetScript("OnEditFocusLost", function() field:SetColors(C.field or C.input, C.border or C.inputLine) end)

  function tab:Refresh()
    todoPin:SetLabel(N.Pinned("todo") and "Unpin" or "Pin")
    notesPin:SetLabel(N.Pinned("notes") and "Unpin" or "Pin")
    N.UpdatePins()
    local view, nOpen = N.View()
    todo.right:SetText(nOpen > 0 and (nOpen .. " left") or "")
    clear:SetShown(#view > nOpen)
    list:SetData(view)
    if not ed:HasFocus() then ed:SetText(N.Data().text) end
  end
  tab:HookScript("OnShow", function() tab:Refresh() end)
end)

---------------------------------------------------------------------------
-- (dev4) pinned boxes: the to-do list or the notes on screen while the Chillan window is closed.
-- Drag to move, the corner to resize; a click on a to-do ticks it.
---------------------------------------------------------------------------
N.pins = {}
local function pinState(which)
  local d = N.Data()
  d.pins = d.pins or {}
  d.pins[which] = d.pins[which] or {}
  return d.pins[which]
end
function N.Pinned(which) return pinState(which).on == true end
function N.SetPinned(which, on)
  pinState(which).on = on or nil
  N.UpdatePins()
end
local function mainOpen()
  local W = ns.Window
  return W and W.frame and W.frame:IsShown()
end
local PIN_ROW = 20
local function buildPin(which)
  local f = UI.OverlayPanel(UIParent, C.panel or C.card, C.border or C.line, 6)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  local st = pinState(which)
  f:SetSize(st.w or 240, st.h or (which == "todo" and 180 or 200))
  f:SetResizable(true)
  if f.SetResizeBounds then f:SetResizeBounds(160, 80, 600, 700) end
  f.title = UI.Text(f, 10, "bold", C.text2)
  f.title:SetPoint("TOPLEFT", 10, -8)
  f.title:SetText(which == "todo" and "TO-DO" or "NOTES")
  f.count = UI.Text(f, 10, nil, C.dim)
  f.count:SetPoint("TOPRIGHT", -26, -8)
  local x = UI.IconButton(f, 16, "Close", "Unpin", function()
    N.SetPinned(which, false)
    local W = ns.Window
    local tab = W and W.tabs and W.tabs.notes
    if tab and tab:IsVisible() then tab:Refresh() end
  end)
  x:SetPoint("TOPRIGHT", -5, -5)
  f.body = CreateFrame("Frame", nil, f)
  f.body:SetPoint("TOPLEFT", 10, -26)
  f.body:SetPoint("BOTTOMRIGHT", -10, 10)
  if which == "notes" then
    f.text = UI.Text(f.body, 12, nil, C.text)
    f.text:SetPoint("TOPLEFT")
    f.text:SetPoint("BOTTOMRIGHT")
    f.text:SetJustifyH("LEFT")
    f.text:SetJustifyV("TOP")
    f.text:SetWordWrap(true)
  else
    f.rows = {}
  end
  UI.Movable(f, which == "todo" and "pinTodo" or "pinNotes", function(fr)
    fr:SetPoint("RIGHT", UIParent, "RIGHT", -40, which == "todo" and 120 or -110)
  end)
  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(14, 14)
  grip:SetPoint("BOTTOMRIGHT", -2, 2)
  grip:SetFrameLevel(f:GetFrameLevel() + 10)
  grip.tex = grip:CreateTexture(nil, "OVERLAY")
  grip.tex:SetAllPoints()
  grip.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    local w, h = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
    f:SetSize(w, h)
    st.w, st.h = w, h
    UI.SnapFrame(f)
    N.DrawPin(which)
  end)
  f:HookScript("OnSizeChanged", function() if f:IsShown() then N.DrawPin(which) end end)
  N.pins[which] = f
  return f
end
function N.DrawPin(which)
  local f = N.pins[which]
  if not f then return end
  if which == "notes" then
    local t = N.Data().text or ""
    f.text:SetText(t ~= "" and t or ns.Colorize("Nothing written yet.", C.dim))
    return
  end
  local view, nOpen = N.View()
  f.count:SetText(nOpen > 0 and (nOpen .. " left") or "")
  local fit = math.max(1, math.floor((f.body:GetHeight() or 100) / PIN_ROW))
  local shown = 0
  for _, it in ipairs(view) do
    if not it.header and not it.done and shown < fit then
      shown = shown + 1
      local r = f.rows[shown]
      if not r then
        r = CreateFrame("Button", nil, f.body)
        r:SetHeight(PIN_ROW)
        r:SetPoint("TOPLEFT", 0, -(shown - 1) * PIN_ROW)
        r:SetPoint("RIGHT")
        r.box = UI.Panel(r, C.field or C.input, C.btnLine or C.activeLine, 3)
        r.box:SetSize(12, 12)
        r.box:SetPoint("LEFT", 0, 0)
        r.text = UI.Text(r, 12, nil, C.text)
        r.text:SetPoint("LEFT", r.box, "RIGHT", 7, 0)
        r.text:SetPoint("RIGHT")
        r.text:SetJustifyH("LEFT")
        r.text:SetWordWrap(false)
        r:SetScript("OnClick", function(self)
          if self.item then
            N.Toggle(self.item)
            N.DrawPin("todo")
            local W = ns.Window
            local tab = W and W.tabs and W.tabs.notes
            if tab and tab:IsVisible() then tab:Refresh() end
          end
        end)
        f.rows[shown] = r
      end
      r.item = it
      r.text:SetText(it.t)
      r:Show()
    end
  end
  for i = shown + 1, #f.rows do f.rows[i]:Hide() end
  if shown == 0 then
    f.count:SetText("all done")
  end
end
function N.UpdatePins()
  if not ns.db then return end
  for _, which in ipairs({ "todo", "notes" }) do
    local want = N.Pinned(which) and not mainOpen()
    local f = N.pins[which]
    if want and not f then f = buildPin(which) end
    if f then
      f:SetShown(want)
      if want then N.DrawPin(which) end
    end
  end
end
-- the main window's show/hide decides whether the pins are up
local hooked
local function hookWindow()
  local W = ns.Window
  if hooked or not (W and W.frame) then return end
  hooked = true
  W.frame:HookScript("OnShow", N.UpdatePins)
  W.frame:HookScript("OnHide", N.UpdatePins)
end
if ns.Window and ns.Window.Create then
  hooksecurefunc(ns.Window, "Create", function() hookWindow() N.UpdatePins() end)
end
ns:On("PLAYER_LOGIN", function() C_Timer.After(2, function() hookWindow() N.UpdatePins() end) end)

-- /chill todo <text>: add without opening the window
function N.Slash(rest)
  if N.Add(rest) then
    N.UpdatePins()
    local _, n = N.View()
    ns.Print("To-do added (" .. n .. " open). /chill notes opens the list.")
  else
    N.Open()
  end
end
function N.Open()
  local W = ns.Window
  W:Create()
  if not W.frame:IsShown() then W.frame:Show() end
  W:Select("notes")
end
