-- Chillan? – the feed as real rows (1.1.2): time, an icon in a small tinted box, the text, and the
-- reactions as pills on their own line under it. Hover a line for a "+" pill to react.
-- Same calls as a ScrollingMessageFrame (Clear, AddMessage, scroll offset), so the event window
-- only swapped the widget.
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

-- (1.3.12) no time column: the time shows on the right when you hover a row, and a thin divider
-- with the time sits between groups of lines 10+ minutes apart. Icons are the game's own, 22 px.
local TILE, GAP, PILL_H, DIV_H, GROUP_GAP = 22, 7, 18, 14, 600
local TIME_W = 0

-- the game's own icon for a feed line: the item itself for loot, else one per kind
local KIND_ICON = {
  DING = "Interface\\Icons\\Spell_Holy_SurgeOfLight",
  DEAD = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
  KILL = "Interface\\Icons\\Ability_DualWield",
  ACH = "Interface\\Icons\\INV_Misc_Trophy_Argent",
  MOUNT = "Interface\\Icons\\Ability_Mount_RidingHorse",
  SOS = "Interface\\Icons\\Ability_Warrior_BattleShout",
  CUNT = "Interface\\Icons\\Spell_Shadow_DeathScream",
  ENSEEN = "Interface\\Icons\\Ability_Hunter_SniperShot",
  DUNGEON = "Interface\\Icons\\INV_Misc_Key_10",
}
local DUNGEON_ICON = {
  ["Ragefire Chasm"] = "RagefireChasm", ["Wailing Caverns"] = "WailingCaverns", ["The Deadmines"] = "Deadmines",
  ["Deadmines"] = "Deadmines", ["Shadowfang Keep"] = "ShadowFangKeep", ["Blackfathom Deeps"] = "BlackfathomDeeps",
  ["The Stockade"] = "StormwindStockades", ["Gnomeregan"] = "Gnomeregan", ["Razorfen Kraul"] = "RazorfenKraul",
  ["Scarlet Monastery"] = "ScarletMonastery", ["Razorfen Downs"] = "RazorfenDowns", ["Uldaman"] = "Uldaman",
  ["Zul'Farrak"] = "ZulFarak", ["Maraudon"] = "Maraudon", ["Sunken Temple"] = "SunkenTemple",
  ["The Temple of Atal'Hakkar"] = "SunkenTemple", ["Blackrock Depths"] = "BlackrockDepths",
  ["Lower Blackrock Spire"] = "BlackrockSpire", ["Upper Blackrock Spire"] = "BlackrockSpire",
  ["Blackrock Spire"] = "BlackrockSpire", ["Dire Maul"] = "DireMaul", ["Scholomance"] = "Scholomance",
  ["Stratholme"] = "Stratholme",
}
local exists = {}
local function fileOK(path)
  if not path then return false end
  if exists[path] == nil then
    if GetFileIDFromPath then
      local ok, id = pcall(GetFileIDFromPath, path)
      exists[path] = ok and id ~= nil
    else
      exists[path] = true
    end
  end
  return exists[path]
end
local function itemIdOf(a)
  return tonumber(a) or tonumber(tostring(a or ""):match("item:(%d+)"))
end
-- returns texture, border hex
local function feedIcon(it)
  if not it or not it.kind then return nil end
  if it.kind == "LOOT" then
    local id = itemIdOf(it.a)
    local tex = id and ((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id)))
    if tex then return tex, ns.QUALITY_HEX and ns.QUALITY_HEX[tonumber(it.b) or 4] or "A335EE" end
  elseif it.kind == "DUNGEON" then
    local key = DUNGEON_ICON[tostring(it.a or ""):gsub("^%s+", "")]
    local path = key and ("Interface\\LFGFrame\\LFGIcon-" .. key)
    if fileOK(path) then return path, "3A3F47" end
  elseif it.kind == "ACH" and ns.Ach and ns.Ach.byId and ns.Ach.TIERS then
    local d = ns.Ach.byId[it.a]
    local tier = d and ns.Ach.TIERS[d.tier]
    return KIND_ICON.ACH, tier and tier.color or "3A3F47"
  end
  local path = KIND_ICON[it.kind]
  if fileOK(path) then return path, "3A3F47" end
end
UI.FeedIcon = feedIcon
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
  row.time:SetPoint("TOPRIGHT", -26, -2)
  row.time:Hide()
  row.time:SetDrawLayer("OVERLAY", 2)
  row.timeBg = row:CreateTexture(nil, "OVERLAY", nil, 1)
  row.timeBg:SetColorTexture(0.08, 0.085, 0.1, 0.92)
  row.timeBg:SetPoint("TOPLEFT", row.time, "TOPLEFT", -5, 2)
  row.timeBg:SetPoint("BOTTOMRIGHT", row.time, "BOTTOMRIGHT", 3, -2)
  row.timeBg:SetShown(false)
  hooksecurefunc(row.time, "Show", function() row.timeBg:Show() end)
  hooksecurefunc(row.time, "Hide", function() row.timeBg:Hide() end)
  row.edge = row:CreateTexture(nil, "BACKGROUND")
  row.edge:SetSize(TILE + 2, TILE + 2)
  row.edge:SetPoint("TOPLEFT", 0, 0)
  row.tile = row:CreateTexture(nil, "ARTWORK")
  row.tile:SetSize(TILE, TILE)
  row.tile:SetPoint("TOPLEFT", 1, -1)
  if row.tile.SetSnapToPixelGrid then pcall(row.tile.SetSnapToPixelGrid, row.tile, false) pcall(row.tile.SetTexelSnappingBias, row.tile, 0) end
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
  if not e or e.kind == "sep" or e.kind == "div" then
    row.time:SetText("")
    row.tile:Hide()
    row.edge:Hide()
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
  local x = 0
  local tex, edge = feedIcon(e.item)
  if tex then
    row.tile:SetTexture(tex)
    row.tile:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.tile:SetVertexColor(1, 1, 1, e.old and 0.55 or 1)
    row.edge:SetColorTexture(hex(edge))
    row.tile:Show() row.edge:Show()
    x = TILE + 2 + GAP
  elseif name then
    row.tile:SetTexture(ns.TEX .. "Tile" .. name)
    row.tile:SetTexCoord(0, 1, 0, 1)
    row.tile:SetVertexColor(r, g, b, e.old and 0.55 or 1)
    row.edge:Hide()
    row.tile:Show()
    x = TILE + 2 + GAP
  else
    row.tile:Hide() row.edge:Hide()
  end
  row.body:ClearAllPoints()
  row.body:SetPoint("TOPLEFT", x, -2)
  row.body:SetWidth(math.max(40, w - x - 24))   -- room on the right for the "+" on hover
  row.body:SetText(rest)
  local h = math.max(TILE + 2, (row.body:GetStringHeight() or 14) + 4)
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

  fr.divs = {}
  local function divider(self, n, label, y)
    local d = self.divs[n]
    if not d then
      d = CreateFrame("Frame", nil, self)
      d:SetHeight(DIV_H)
      d.text = UI.Text(d, 10, nil, "6E747B")
      d.text:SetPoint("LEFT", 0, 0)
      d.line = d:CreateTexture(nil, "ARTWORK")
      d.line:SetHeight(1)
      d.line:SetColorTexture(1, 1, 1, 0.07)
      d.line:SetPoint("LEFT", d.text, "RIGHT", 6, 0)
      d.line:SetPoint("RIGHT", 0, 0)
      self.divs[n] = d
    end
    d.text:SetText(label)
    d:ClearAllPoints()
    d:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, y)
    d:SetPoint("RIGHT", self, "RIGHT", 0, 0)
    d:Show()
  end
  local function stampOf(self, t)
    if self.timeText then return self.timeText({ t = t }) end
    local today = date("%Y%m%d", ns.Now()) == date("%Y%m%d", t)
    return today and date("%H:%M", t) or (date("%d.%m", t) .. " " .. date("%H:%M", t))
  end
  local function timeOf(m)
    local e = m and m.e
    if not e or e.kind == "sep" or not e.t then return nil end
    return e.firstT or e.t
  end
  function fr:Layout()
    self.pending = nil
    for _, r in ipairs(self.rows) do r:Hide() end
    for _, d in ipairs(self.divs) do d:Hide() end
    local H = self:GetHeight() or 200
    local y, used, nd = 0, 0, 0
    local last = #self.msgs - self.offset
    for i = last, 1, -1 do
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
      -- a divider above this line when the one before it is 10+ minutes older (or it's the top)
      local t, prev = timeOf(self.msgs[i]), nil
      for k = i - 1, 1, -1 do prev = timeOf(self.msgs[k]) if prev then break end end
      if t and (not prev or t - prev >= GROUP_GAP) then
        nd = nd + 1
        divider(self, nd, stampOf(self, t), y)
        y = y + DIV_H + self.spacing
      end
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
      if old and old.time then old.time:Hide() end
      if hover and hover.plus then hover.plus:Show() end
      if hover and hover.time and (hover.time:GetText() or "") ~= "" then hover.time:Show() end
    end
  end)
  return fr
end
