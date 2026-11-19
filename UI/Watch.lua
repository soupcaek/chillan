-- Chillan? – Watching (1.2.2): pin up to 4 friends and see them in the Gang pulse, under the Now card:
-- online dot, name, level, where they are (zone, dungeon, "dead", your layer) and a thin bar for how
-- far into the level they are. Pins are yours only and kept between sessions.
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex
local W = {}
ns.Watch = W

local MAX = 4
local ROW_H = 30

local function list()
  ns.db.watch = ns.db.watch or {}
  return ns.db.watch
end

-- the person shown for a pid (another install with the same name counts as the same person)
local function resolve(pid)
  local hidden = ns:HiddenDuplicates()
  return hidden[pid] or pid
end

function W:Has(pid)
  pid = resolve(pid)
  for _, x in ipairs(list()) do if resolve(x) == pid then return true end end
  return false
end

function W:Toggle(pid)
  if not pid or pid == ns.pid then return end
  pid = resolve(pid)
  local l = list()
  for i, x in ipairs(l) do
    if resolve(x) == pid then
      table.remove(l, i)
      self:Changed()
      return false
    end
  end
  if #l >= MAX then
    ns.Print("You can watch up to " .. MAX .. " friends – unpin one first (hover their row, click ×).")
    return false
  end
  l[#l + 1] = pid
  local p = ns:GetPerson(pid)
  ns.Print("Watching " .. ((p and ns:PersonFirst(p)) or "them") .. " – they're under the Now card. Unpin the same way.")
  self:Changed()
  return true
end

function W:People()
  local out, seen = {}, {}
  for _, x in ipairs(list()) do
    local pid = resolve(x)
    local p = ns.db.people[pid]
    if p and p.main and not seen[pid] then seen[pid] = true p.pid = pid out[#out + 1] = p end
  end
  return out
end

function W:Changed()
  self:Update()
  if ns.Overlays.UpdateGroup then ns.Overlays:UpdateGroup() end
  ns:Fire("WATCH")
end

-- pick who to watch: the gang, online first
function W:Menu(anchor)
  local people = ns:SortedPeople(function(p, pid) return pid ~= ns.pid end)
  table.sort(people, function(a, b)
    local oa, ob = ns:IsOnline(a) and 1 or 0, ns:IsOnline(b) and 1 or 0
    if oa ~= ob then return oa > ob end
    return ns:PersonMaxLevel(a) > ns:PersonMaxLevel(b)
  end)
  local items = { { text = "WATCHING (up to " .. MAX .. ")", color = C.muted, func = function() end } }
  for _, p in ipairs(people) do
    local on = self:Has(p.pid)
    local c = ns:PersonChar(p) or {}
    items[#items + 1] = {
      text = (on and "• " or "   ") .. ns:ShortWho(p) .. ns.Colorize("  " .. tostring(c.level or "?") .. (ns:IsOnline(p) and "" or "  offline"), C.dim),
      func = function() W:Toggle(p.pid) end,
    }
  end
  UI.Menu(anchor, items, true)
end

---------------------------------------------------------------------------
-- the strip
---------------------------------------------------------------------------
local function where(p)
  local L = p.live or {}
  if not ns:IsOnline(p) then
    return ns.Colorize("offline · " .. ns.Ago(p.lastSeen), C.dim)
  end
  if p.deathAt and ns.Now() - p.deathAt < 150 and (not p.aliveAt or p.aliveAt < p.deathAt) then
    return ns.Colorize("dead · " .. tostring(p.deathZone or L.zone or "?"), C.red)
  end
  local z = L.zone or ""
  if L.inInst then return ns.Colorize(z ~= "" and z or "in a dungeon", "8FB8E8") end
  local mine = ns.Layer and ns.Layer:Current()
  if L.layer and mine and L.layer == mine then z = z .. ns.Colorize("  · your layer", "9BE08A") end
  return ns.Colorize(z, C.muted)
end

local function makeRow(f, i)
  local r = CreateFrame("Button", nil, f)
  r:SetHeight(ROW_H)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r.hl = r:CreateTexture(nil, "BACKGROUND")
  r.hl:SetAllPoints()
  r.hl:SetColorTexture(1, 1, 1, 0.04)
  r.hl:Hide()
  r.dot = UI.Track(r:CreateTexture(nil, "ARTWORK"))
  r.dot:SetTexture(ns.TEX .. "Circle")
  r.dot:SetSize(7, 7)
  r.dot:SetPoint("TOPLEFT", 0, -6)
  r.name = UI.Text(r, 12, "semi", C.text)
  r.name:SetPoint("TOPLEFT", 12, -2)
  r.where = UI.Text(r, 11, nil, C.muted)
  r.where:SetPoint("TOPRIGHT", -2, -3)
  r.where:SetJustifyH("RIGHT")
  r.where:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
  r.bar = UI.Track(r:CreateTexture(nil, "ARTWORK"))
  r.bar:SetPoint("BOTTOMLEFT", 0, 5)
  r.bar:SetPoint("BOTTOMRIGHT", 0, 5)
  r.bar:SetHeight(3)
  r.bar:SetColorTexture(hex(C.active))
  r.fill = r:CreateTexture(nil, "OVERLAY")
  r.fill:SetPoint("TOPLEFT", r.bar, "TOPLEFT")
  r.fill:SetPoint("BOTTOMLEFT", r.bar, "BOTTOMLEFT")
  r.x = UI.IconButton(r, 16, "Close", "Stop watching", function(b) if b:GetParent().pid then W:Toggle(b:GetParent().pid) end end)
  r.x:SetPoint("TOPRIGHT", 2, 0)
  r.x:Hide()
  r:SetScript("OnEnter", function(self)
    self.hl:Show()
    self.x:Show()
    self.where:SetPoint("TOPRIGHT", -18, -3)
    if self.pid then ns.Overlays:ShowProfile(self, self.pid) end
  end)
  r:SetScript("OnLeave", function(self)
    if self.x:IsMouseOver() then return end
    self.hl:Hide()
    self.x:Hide()
    self.where:SetPoint("TOPRIGHT", -2, -3)
    ns.Overlays:HideProfile()
  end)
  r.x:HookScript("OnLeave", function() if not r:IsMouseOver() then r:GetScript("OnLeave")(r) end end)
  r:SetScript("OnClick", function(self, btn)
    if not self.pid then return end
    if btn == "RightButton" then W:Toggle(self.pid) return end
    local p = ns:GetPerson(self.pid)
    if p then ns.Whisper((p.live and p.live.char) or p.main) end
  end)
  return r
end

function W:Create()
  local m = ns.Overlays.minibar
  if not m or self.frame then return end
  local f = CreateFrame("Frame", "ChillanWatch", UIParent)
  f:SetFrameStrata("MEDIUM")
  f:SetFrameLevel(m:GetFrameLevel() + 5)
  f:SetSize(300, 30)
  f:EnableMouse(true)
  self.frame = f
  f.head = UI.Text(f, 10, "semi", C.dim)
  f.head:SetPoint("TOPLEFT", 10, -8)
  f.head:SetText("WATCHING")
  f.more = CreateFrame("Button", nil, f)
  f.more:SetSize(60, 14)
  f.more:SetPoint("TOPRIGHT", -8, -6)
  f.more.t = UI.Text(f.more, 10, "semi", C.dim)
  f.more.t:SetPoint("RIGHT")
  f.more.t:SetText("+ / –")
  f.more:SetScript("OnClick", function(b) W:Menu(b) end)
  f.more:SetScript("OnEnter", function(b) b.t:SetTextColor(hex(C.text)) end)
  f.more:SetScript("OnLeave", function(b) b.t:SetTextColor(hex(C.dim)) end)
  f.add = CreateFrame("Button", nil, f)
  f.add:SetPoint("TOPLEFT", 10, -4)
  f.add:SetPoint("TOPRIGHT", -10, -4)
  f.add:SetHeight(18)
  f.add.t = UI.Text(f.add, 11, nil, C.dim)
  f.add.t:SetPoint("LEFT")
  f.add.t:SetText("+  Watch someone – see where they are and how they're doing")
  f.add:SetScript("OnClick", function(b) W:Menu(b) end)
  f.add:SetScript("OnEnter", function(b) b.t:SetTextColor(hex(C.text)) end)
  f.add:SetScript("OnLeave", function(b) b.t:SetTextColor(hex(C.dim)) end)
  f.rows = {}
  ns:Listen("DATA", function() W:Update() end)
  ns:Listen("LAYER", function() W:Update() end)
  -- a little flash when a watched friend dings, dies or loots an epic (no popup)
  ns:Listen("FEEDEVENT", function(_, item)
    if not item or not W:Has(item.pid) then return end
    if item.kind == "DING" or item.kind == "DEAD" or (item.kind == "LOOT" and (tonumber(item.b) or 0) >= 4) then W:Flash(item.pid) end
  end)
  C_Timer.NewTicker(5, function() W:Update() end)
  self:Update()
end

function W:Flash(pid)
  for _, r in ipairs(self.frame and self.frame.rows or {}) do
    if r:IsShown() and r.pid == resolve(pid) then
      r.hl:Show()
      local n = 0
      local t
      t = C_Timer.NewTicker(0.25, function()
        n = n + 1
        r.hl:SetShown(n % 2 == 0)
        if n >= 8 then t:Cancel() r.hl:SetShown(r:IsMouseOver()) end
      end)
    end
  end
end

function W:Update()
  local f = self.frame
  if not f then return end
  local people = self:People()
  local w = f:GetWidth()
  for _, r in ipairs(f.rows) do r:Hide() end
  if #people == 0 then
    f.head:Hide() f.more:Hide()
    f.add:Show()
    f:SetHeight(26)
  else
    f.add:Hide()
    f.head:Show() f.more:Show()
    local y = -22
    for i, p in ipairs(people) do
      local r = f.rows[i] or makeRow(f, i)
      f.rows[i] = r
      r.pid = p.pid
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 10, y)
      r:SetPoint("TOPRIGHT", -10, y)
      local c = ns:PersonChar(p) or {}
      local online = ns:IsOnline(p)
      r:SetAlpha(online and 1 or 0.5)
      r.dot:SetVertexColor(hex(online and C.green or "4A4F55"))
      r.name:SetText(ns.Colorize(ns:PersonFirst(p) or c.name or "?", ns.ClassHex(c.class)) .. ns.Colorize("  " .. tostring(c.level or "?"), C.muted))
      r.where:SetText(where(p))
      local s3 = ns:PersonS3(p) or {}
      local pct = (s3.xp and s3.xpMax and s3.xpMax > 0) and (s3.xp / s3.xpMax) or nil
      if (c.level or 0) >= 60 then pct = 1 end
      local cr, cg, cb = ns.ClassColor(c.class)
      r.fill:SetColorTexture(cr, cg, cb, 0.9)
      r.fill:SetWidth(math.max(1, (w - 20) * (pct or 0)))
      r.fill:SetShown(pct ~= nil)
      r:Show()
      y = y - ROW_H
    end
    f:SetHeight(-y + 4)
  end
  if self.lastH ~= math.floor(f:GetHeight()) then
    self.lastH = math.floor(f:GetHeight())
    if ns.Overlays.UpdateGroup then ns.Overlays:UpdateGroup() end
  end
end
