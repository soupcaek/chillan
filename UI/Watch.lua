-- Chillan? – Watching (1.2.2): pin up to 4 friends and see them in the Gang pulse, under the Now card:
-- online dot, name, level, where they are (zone, dungeon, "dead", your layer) and a thin bar for how
-- far into the level they are. Pins are yours only and kept between sessions.
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex
local W = {}
ns.Watch = W

local MAX = 4
local ROW_H = 38

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
-- "Ruins of Andorhal, Western Plaguelands" → "Western Plaguelands"
local function mainZone(z)
  z = tostring(z or "")
  return z:match(",%s*([^,]+)$") or z
end

local function where(p)
  local L = p.live or {}
  if not ns:IsOnline(p) then
    return ns.Colorize("offline · " .. ns.Ago(p.lastSeen), C.dim)
  end
  if p.deathAt and ns.Now() - p.deathAt < 150 and (not p.aliveAt or p.aliveAt < p.deathAt) then
    return ns.Colorize("dead", C.red) .. ns.Colorize(" · " .. mainZone(p.deathZone or L.zone), C.dim)
  end
  local z = mainZone(L.zone)
  if L.inInst then return ns.Colorize(z ~= "" and z or "in a dungeon", "8FB8E8") end
  local mine = ns.Layer and ns.Layer:Current()
  if L.layer and mine and L.layer == mine and ns.Layer and ns.Layer.Comparable() then z = z .. ns.Colorize("  · your layer", "9BE08A") end
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
  r.fact = UI.Text(r, 10, nil, C.dim)
  r.fact:SetPoint("TOPLEFT", 12, -17)
  r.fact:SetPoint("RIGHT", -2, 0)
  r.fact:SetWordWrap(false)
  r.bar = UI.Track(r:CreateTexture(nil, "ARTWORK"))
  r.bar:SetPoint("BOTTOMLEFT", 0, 4)
  r.bar:SetPoint("BOTTOMRIGHT", 0, 4)
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
  f.add.t:SetText("+  Watch someone")
  f.add:SetScript("OnClick", function(b) W:Menu(b) end)
  f.add:SetScript("OnEnter", function(b)
    b.t:SetTextColor(hex(C.text))
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Watch someone")
    GameTooltip:AddLine("Pick up to 4 friends – see where they are and their level right here.", 0.75, 0.78, 0.82, true)
    GameTooltip:Show()
  end)
  f.add:SetScript("OnLeave", function(b) b.t:SetTextColor(hex(C.dim)) GameTooltip:Hide() end)
  f.rows = {}
  ns:Listen("DATA", function() W:Update() end)
  ns:Listen("LAYER", function() W:Update() end)
  -- a little flash when a watched friend dings, dies or loots an epic (no popup)
  ns:Listen("FEEDEVENT", function(_, item)
    if not item or not W:Has(item.pid) then return end
    if item.kind == "DING" or item.kind == "DEAD" or (item.kind == "LOOT" and (tonumber(item.b) or 0) >= 4) then W:Flash(item.pid) end
  end)
  C_Timer.NewTicker(6, function() W.tick = (W.tick or 0) + 1 W:Update() end)
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

-- (1.2.5) a small fact under each name, a new one every 6 s: pace, gold, progress, the week
local function facts(p)
  local out = {}
  local s3 = ns:PersonS3(p) or {}
  local c = ns:PersonChar(p) or {}
  local rate = ns.St and ns.St:XPRate(p)
  if rate and (c.level or 0) < 60 then out[#out + 1] = ns.Num(math.floor(rate)) .. " XP/h" end
  local pct = ns.Pct(s3.xp, s3.xpMax)
  if pct and (c.level or 0) < 60 then out[#out + 1] = pct .. " % of level " .. tostring(c.level or "?") end
  -- (1.4.34) in (or just out of) a battleground: wins to Exalted with its reputation
  if s3.bgRepS and s3.bgWins and s3.at and ns.Now() - s3.at < 1800 then
    out[#out + 1] = s3.bgRepS .. ": " .. ns.Plural(s3.bgWins, "win") .. " to Exalted" .. ((s3.bgGame or 0) > 0 and (" · +" .. ns.Num(s3.bgGame) .. " this game") or "")
  end
  local eta = (c.level or 0) < 60 and ns.St and ns.St:ETA(p)
  if eta then out[#out + 1] = ns.Duration(eta) .. " to " .. ((c.level or 0) + 1) end
  -- (1.4.17) at 60: rank, honor, runs, gold/h and the best drop of the week
  if (c.level or 0) >= 60 then
    if s3.rank then
      out[#out + 1] = "rank " .. s3.rank .. (s3.rankProg and (" · " .. math.floor(s3.rankProg * 100) .. " % to " .. (s3.rank + 1)) or "")
    end
    if (s3.hkT or 0) > 0 then out[#out + 1] = ns.Plural(s3.hkT, "HK") .. " today" end
    if (s3.honorT or 0) > 0 then out[#out + 1] = ns.Num(s3.honorT) .. " honor today" end
    if (s3.runsT or 0) > 0 then
      out[#out + 1] = ns.Plural(s3.runsT, "run") .. " today" .. ((s3.bossT or 0) > 0 and (" · " .. ns.Plural(s3.bossT, "boss", "bosses")) or "")
    end
    if (s3.goldh or 0) > 0 then out[#out + 1] = ns.Money(s3.goldh) .. "/h" end
    if s3.best then
      local name, link = nil, nil
      if C_Item and C_Item.GetItemInfo then
        local ok, n, l = pcall(C_Item.GetItemInfo, s3.best)
        if ok then name, link = n, l end
      end
      if type(link) == "string" and not ns.isSecret(link) then out[#out + 1] = "best drop: " .. link
      elseif C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, s3.best) end
    end
  end
  local wg, wo = ns:WeekStat(p, "Gold"), ns:WeekStat(p, "Online")
  if wg > 0 and wo > 1800 then out[#out + 1] = ns.Money(math.floor(wg / wo * 3600)) .. "/h this week" end
  if s3.money then out[#out + 1] = ns.Money(s3.money) .. " in the bags" end
  local q = ns:WeekStat(p, "Quests")
  if q > 0 then out[#out + 1] = q .. " quests this week" end
  local lv = ns:WeekStat(p, "Levels")
  if lv > 0 then out[#out + 1] = "+" .. ns.Plural(lv, "level") .. " this week" end
  local k = ns:WeekStat(p, "Kills")
  if k > 0 then out[#out + 1] = ns.Plural(k, "kill") .. " this week" end
  local d = ns:WeekStat(p, "Deaths")
  if d > 0 then out[#out + 1] = ns.Plural(d, "death") .. " this week" end
  if s3.today and s3.today > 0 then out[#out + 1] = "online " .. ns.Duration(s3.today) .. " today" end
  if (s3.streak or 0) >= 2 then out[#out + 1] = s3.streak .. "-day streak" end
  if s3.ilvl then out[#out + 1] = "item level " .. math.floor(s3.ilvl) end
  if s3.dura and s3.dura < 30 then out[#out + 1] = ns.Colorize("gear at " .. s3.dura .. " %", C.amber) end
  return out
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
      local list = facts(p)
      r.fact:SetText(#list > 0 and list[(self.tick or 0) % #list + 1] or "")
      local s3 = ns:PersonS3(p) or {}
      local pct = (s3.xp and s3.xpMax and s3.xpMax > 0) and (s3.xp / s3.xpMax) or nil
      -- (1.4.17) at 60 the bar shows progress to their next PvP rank (empty until they send it)
      if (c.level or 0) >= 60 then pct = s3.rankProg end
      local cr, cg, cb = ns.ClassColor(c.class)
      if (c.level or 0) >= 60 then cr, cg, cb = 0.85, 0.3, 0.25 end   -- honor bar: Horde red
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
