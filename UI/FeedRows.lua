-- Chillan? – the feed as real rows (1.1.2): time, an icon in a small tinted box, the text, and the
-- reactions as pills on their own line under it. Hover a line for a "+" pill to react.
-- Same calls as a ScrollingMessageFrame (Clear, AddMessage, scroll offset), so the event window
-- only swapped the widget.
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

local TIME_W, TILE, GAP, PILL_H = 32, 16, 6, 18
local REACTABLE = { DING = true, DEAD = true, KILL = true, ACH = true }

-- "|T…IconSkull:12:12:…:r:g:b|t  text" → "Skull", r, g, b, "text" (with any leading colour kept)
local function splitIcon(text)
  local col, spec, rest = text:match("^(|c%x%x%x%x%x%x%x%x)|T(.-)|t%s*(.*)$")
  if not spec then
    spec, rest = text:match("^|T(.-)|t%s*(.*)$")
    col = ""
  end
  if not spec then return nil, nil, nil, nil, text end
  local path = spec:match("^([^:]+)")
  local name = path and path:match("Icon(%w+)$")
  local r, g, b = spec:match(":(%d+):(%d+):(%d+)$")
  if not name then return nil, nil, nil, nil, text end
  return name, (tonumber(r) or 255) / 255, (tonumber(g) or 255) / 255, (tonumber(b) or 255) / 255, (col or "") .. rest
end

local function canReact(item)
  if not item or not item.id or not REACTABLE[item.kind] or item.pid == ns.pid then return false end
  for _, r in ipairs(item.reacts or {}) do if r.pid == ns.pid then return false end end
  return (ns.Now() - (item.t or 0)) < 6 * 3600
end

-- the four funny reactions for this event, from a small menu
function UI.ReactMenu(anchor, item)
  local list, picks = ns.ReactionList(item), ns.PickReactions(item, 4)
  local items = {}
  for _, i in ipairs(picks) do
    items[#items + 1] = { text = ns.Emotes and ns.Emotes:Render(list[i], 14) or list[i], func = function() ns.Data:React(item, i) end }
  end
  UI.Menu(anchor, items)
end

local function newPill(row)
  local p = CreateFrame("Button", nil, row)
  p:SetHeight(PILL_H)
  p.panel = UI.Panel(p, "24203A", nil, true)
  p.panel:SetAllPoints()
  p.panel:SetFrameLevel(p:GetFrameLevel())
  p.text = UI.Text(p, 11, nil, C.purple)
  p.text:SetPoint("CENTER", 0, 0)
  p:SetScript("OnEnter", function(self)
    self.panel:SetColors("2E2848", nil)
    if self.link then UI.LinkEnter(self, self.link)
    elseif self.tip then GameTooltip:SetOwner(self, "ANCHOR_CURSOR") GameTooltip:AddLine(self.tip, 1, 1, 1) GameTooltip:Show() end
  end)
  p:SetScript("OnLeave", function(self) self.panel:SetColors("24203A", nil) GameTooltip:Hide() end)
  return p
end

local function newRow(fr)
  local row = CreateFrame("Button", nil, fr)
  row:SetHeight(18)
  if row.SetHyperlinksEnabled then pcall(row.SetHyperlinksEnabled, row, true) end
  row.time = UI.Text(row, 11, nil, "6E747B")
  row.time:SetPoint("TOPLEFT", 0, -2)
  row.tile = row:CreateTexture(nil, "ARTWORK")
  row.tile:SetSize(TILE, TILE)
  row.tile:SetPoint("TOPLEFT", TIME_W, 0)
  row.body = UI.Text(row, 12, nil, C.text2)
  row.body:SetJustifyH("LEFT")
  row.body:SetWordWrap(true)
  row.pills = {}
  row:SetScript("OnHyperlinkEnter", function(self, link) UI.LinkEnter(self, link) end)
  row:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() if ns.PersonCard then ns.PersonCard:Hide() end end)
  row:SetScript("OnHyperlinkClick", function(self, link, text, button)
    if fr.onLinkClick then fr.onLinkClick(fr, link, text, button) end
  end)
  return row
end

local function fill(fr, row, msg)
  local e, text = msg.e, msg.text
  local w = fr:GetWidth()
  for _, p in ipairs(row.pills) do p:Hide() end
  if row.plusBtn then row.plusBtn:Hide() end
  row.plus = nil
  row.item = nil
  if not e or e.kind == "sep" then
    row.time:SetText("")
    row.tile:Hide()
    row.body:ClearAllPoints()
    row.body:SetPoint("TOPLEFT", 0, 0)
    row.body:SetWidth(w)
    row.body:SetJustifyH(e and "CENTER" or "LEFT")
    row.body:SetText(text or "")
    local h = math.max(14, row.body:GetStringHeight() or 14)
    row:SetHeight(h)
    return h
  end
  row.body:SetJustifyH("LEFT")
  row.time:SetText(fr.timeText and fr.timeText(e) or date("%H:%M", e.t or time()))
  local name, r, g, b, rest = splitIcon(e.base or text or "")
  local x = TIME_W
  if name then
    row.tile:SetTexture(ns.TEX .. "Tile" .. name)
    row.tile:SetVertexColor(r, g, b, e.old and 0.55 or 1)
    row.tile:Show()
    x = TIME_W + TILE + GAP
  else
    row.tile:Hide()
  end
  row.body:ClearAllPoints()
  row.body:SetPoint("TOPLEFT", x, -2)
  row.body:SetWidth(math.max(40, w - x - 24))   -- room on the right for the "+" on hover
  row.body:SetText(rest)
  local h = math.max(TILE, (row.body:GetStringHeight() or 14) + 2)
  -- reactions: one pill per kind, with the count, on their own line
  local item = e.item
  row.item = item
  local order, counts = {}, {}
  for _, rx in ipairs(item and item.reacts or {}) do
    if not counts[rx.idx] then counts[rx.idx] = 0 order[#order + 1] = rx.idx end
    counts[rx.idx] = counts[rx.idx] + 1
  end
  -- (1.3.6) pills wrap onto a new line when the window is narrow
  local px, n, lines = x, 0, 1
  local function pill(label, link, tip, onClick)
    n = n + 1
    local p = row.pills[n] or newPill(row)
    row.pills[n] = p
    p.text:SetText(label)
    local pw = (p.text:GetStringWidth() or 20) + 14
    p:SetWidth(pw)
    if px > x and px + pw > w then
      px = x
      lines = lines + 1
    end
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", px, -(h + 3 + (lines - 1) * (PILL_H + 4)))
    p.link, p.tip = link, tip
    p:SetScript("OnClick", onClick)
    p:Show()
    px = px + p:GetWidth() + 4
    return p
  end
  for _, idx in ipairs(order) do
    local c = counts[idx]
    pill(ns.ReactionText(item, idx) .. (c > 1 and ("  " .. c) or ""), "chillanrx:" .. tostring(item.id) .. ":" .. idx, nil,
      function() if canReact(item) then ns.Data:React(item, idx) end end)
  end
  if n > 0 then h = h + lines * (PILL_H + 4) + 1 end
  -- "+" to react: top right of the line, shown while the mouse is on it (no jumping lines)
  if not row.plusBtn then
    row.plusBtn = newPill(row)
    row.plusBtn.text:SetText("+")
    row.plusBtn:SetWidth(20)
    row.plusBtn.tip = "React"
  end
  row.plus = canReact(item) and row.plusBtn or nil
  row.plusBtn:ClearAllPoints()
  row.plusBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
  row.plusBtn:SetScript("OnClick", function(self) UI.ReactMenu(self, item) end)
  row.plusBtn:SetShown(row.plus ~= nil and fr.hoverRow == row)
  row:SetHeight(h)
  return h
end

function UI.FeedRows(parent)
  local fr = CreateFrame("Frame", nil, parent)
  if fr.SetClipsChildren then fr:SetClipsChildren(true) end
  fr.msgs, fr.rows, fr.offset, fr.spacing = {}, {}, 0, 5
  fr:EnableMouseWheel(true)

  function fr:Layout()
    self.pending = nil
    for _, r in ipairs(self.rows) do r:Hide() end
    local H = self:GetHeight() or 200
    local y, used = 0, 0
    for i = #self.msgs - self.offset, 1, -1 do
      used = used + 1
      local row = self.rows[used] or newRow(self)
      self.rows[used] = row
      row:SetWidth(self:GetWidth())
      local h = fill(self, row, self.msgs[i])
      row:ClearAllPoints()
      row:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, y)
      row:SetPoint("RIGHT", self, "RIGHT", 0, 0)
      row:Show()
      y = y + h + self.spacing
      if y > H then break end
    end
  end
  local function soon(self)
    if self.pending then return end
    self.pending = true
    C_Timer.After(0, function() self:Layout() end)
  end
  function fr:Clear() self.msgs = {} soon(self) end
  function fr:AddMessage(text, e)
    self.msgs[#self.msgs + 1] = { text = text, e = e }
    while #self.msgs > 300 do table.remove(self.msgs, 1) end
    if self.offset > 0 then self.offset = self.offset + 1 end   -- keep what you're reading in place
    soon(self)
  end
  function fr:GetScrollOffset() return self.offset end
  function fr:SetScrollOffset(n) self.offset = math.max(0, math.min(#self.msgs - 1, n or 0)) soon(self) end
  function fr:SetSpacing(n) self.spacing = (n or 3) + 2 end
  fr:SetScript("OnMouseWheel", function(self, delta) self:SetScrollOffset(self.offset + (delta > 0 and 2 or -2)) end)
  fr:SetScript("OnSizeChanged", function(self) soon(self) end)
  -- which row is under the mouse: that one shows its "+"
  fr:SetScript("OnUpdate", function(self, el)
    self.acc = (self.acc or 0) + el
    if self.acc < 0.1 then return end
    self.acc = 0
    local hover
    if self:IsMouseOver() then
      for _, r in ipairs(self.rows) do if r:IsShown() and r:IsMouseOver() then hover = r break end end
    end
    if hover ~= self.hoverRow then
      local old = self.hoverRow
      self.hoverRow = hover
      if old and old.plusBtn then old.plusBtn:Hide() end
      if hover and hover.plus then hover.plus:Show() end
    end
  end)
  return fr
end
