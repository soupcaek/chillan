-- Chillan? – Notes (1.4.72): a personal to-do list and a notepad. Kept in your own saved variables,
-- one list for all your characters, and never sent to anyone.
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

local N = {}
ns.Notes = N
local ROW_H = 28

local function today() return date("%Y-%m-%d") end
function N.Data()
  ns.db.notes = ns.db.notes or {}
  local d = ns.db.notes
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
  ed:SetScript("OnTextChanged", function(self, user) if user then N.Data().text = self:GetText() end end)
  -- a click anywhere in the field writes
  field:EnableMouse(true)
  field:SetScript("OnMouseDown", function() ed:SetFocus() ed:SetCursorPosition(#(ed:GetText() or "")) end)
  ed:SetScript("OnEditFocusGained", function() field:SetColors(C.field or C.input, C.accent) end)
  ed:SetScript("OnEditFocusLost", function() field:SetColors(C.field or C.input, C.border or C.inputLine) end)

  function tab:Refresh()
    local view, nOpen = N.View()
    todo.right:SetText(nOpen > 0 and (nOpen .. " left") or "")
    clear:SetShown(#view > nOpen)
    list:SetData(view)
    if not ed:HasFocus() then ed:SetText(N.Data().text) end
  end
  tab:HookScript("OnShow", function() tab:Refresh() end)
end)

-- /chill todo <text>: add without opening the window
function N.Slash(rest)
  if N.Add(rest) then
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
