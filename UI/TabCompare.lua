-- Chillan? – "Compare": deg mot en kompis, side om side
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex
local W = ns.Window

function W:OpenCompare(pid)
  self:Create()
  if not self.frame:IsShown() then self.frame:Show() end
  self.comparePid = pid
  self:Select("compare")
end

local function s3(p) return ns:PersonS3(p) or {} end
local function achPoints(p) return (ns.Ach and ns.Ach.Points and ns.Ach:Points(p.pid)) or 0 end

-- { navn, verdi(p), format, lavest er best }
local ROWS = {
  { "Level", function(p) return ns:PersonMaxLevel(p) end, "n" },
  { "XP per hour", function(p) return ns.St:XPRate(p) or 0 end, "n" },
  { "XP this week", function(p) return s3(p).wXP or 0 end, "n" },
  { "Quests this week", function(p) return ns:WeekStat(p, "Quests") end, "n" },
  { "Quests total", function(p) return ns:TotalStat(p, "Quests") end, "n" },
  { "Online this week", function(p) return ns:WeekStat(p, "Online") end, "t" },
  { "/played", function(p) return ns:PersonPlayed(p) end, "t" },
  { "Longest session", function(p) return (p.stats or {}).tLongest or 0 end, "t" },
  { "Gold earned (week)", function(p) return ns:WeekStat(p, "Gold") end, "g" },
  { "PvP kills total", function(p) return ns:TotalStat(p, "Kills") end, "n" },
  { "Deaths total", function(p) return ns:TotalStat(p, "Deaths") end, "n", true },
  { "Achievement points", achPoints, "n" },
  { "Streak", function(p) return s3(p).streak or 0 end, "d" },
  { "Item level", function(p) return s3(p).ilvl or 0 end, "n" },
}

local function fmt(kind, v)
  if kind == "t" then return ns.Duration(v) end
  if kind == "g" then return ns.Money(v) end
  if kind == "d" then return math.floor(v) .. " d" end
  return ns.Num(v)
end

ns:RegisterTab("compare", "Compare", "Compare", function(tab)
  local back = UI.Button(tab, 80, 26, "‹ Back", "ghost", function()
    if W.comparePid then W:OpenPlayer(W.comparePid) else W:Select("friends") end
  end)
  back:SetPoint("TOPLEFT", 16, -14)

  local leftName = UI.Text(tab, 17, "bold", C.text)
  leftName:SetPoint("TOPRIGHT", tab, "TOP", -60, -50)
  leftName:SetJustifyH("RIGHT")
  local vs = UI.Text(tab, 12, "semi", C.dim)
  vs:SetPoint("TOP", 0, -54)
  vs:SetText("VS")
  local rightName = UI.Text(tab, 17, "bold", C.text)
  rightName:SetPoint("TOPLEFT", tab, "TOP", 60, -50)
  local score = UI.Text(tab, 12, nil, C.muted)
  score:SetPoint("TOP", 0, -76)

  -- Stats | Gear
  local mode = "stats"
  local seg = {}
  local function paintSeg()
    for k, b in pairs(seg) do
      local on = k == mode
      b.panel:SetColors(on and C.active or nil, on and C.activeLine or C.inputLine)
      b.label:SetTextColor(hex(on and C.text or C.muted))
      b.style = { fill = on and C.active or nil, line = on and C.activeLine or C.inputLine, text = on and C.text or C.muted, hover = on and C.activeHover or C.card }
    end
  end
  function tab:SetMode(m) mode = m paintSeg() self:Refresh() end
  local prevB
  for _, def in ipairs({ { "stats", "Stats" }, { "gear", "Gear" } }) do
    local b = UI.Button(tab, 70, 26, def[2], "ghost", function() mode = def[1] paintSeg() tab:Refresh() end)
    if prevB then b:SetPoint("LEFT", prevB, "RIGHT", 6, 0) else b:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -92, -14) end
    seg[def[1]] = b
    prevB = b
  end

  -- gear view: slot by slot, theirs vs yours, hover for the item tooltip
  local gearFrame = CreateFrame("Frame", nil, tab)
  gearFrame:SetPoint("TOPLEFT", 16, -96)
  gearFrame:SetPoint("BOTTOMRIGHT", -16, 10)
  gearFrame:Hide()
  local gearRows = {}
  local function itemCell(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(19)
    b.text = UI.Text(b, 12, nil, C.text)
    b.text:SetPoint("LEFT")
    b.text:SetPoint("RIGHT", -40, 0)
    b.text:SetWordWrap(false)
    b.lvl = UI.Text(b, 12, "semi", C.text)
    b.lvl:SetPoint("RIGHT")
    b.lvl:SetJustifyH("RIGHT")
    b:SetScript("OnEnter", function(self)
      if not self.item then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(self.item)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end
  local gh1 = UI.Text(gearFrame, 10, "semi", C.dim)
  gh1:SetPoint("TOPLEFT", 90, 0)
  gh1:SetText("YOU")
  local gh2 = UI.Text(gearFrame, 10, "semi", C.dim)
  gh2:SetPoint("TOPLEFT", gearFrame, "TOP", 50, 0)
  gh2:SetText("THEM")
  for i, slot in ipairs(ns.Gear.SLOTS) do
    local r = {}
    local y = -16 - (i - 1) * 20
    r.slot = UI.Text(gearFrame, 11, nil, C.muted)
    r.slot:SetPoint("TOPLEFT", 0, y - 3)
    r.slot:SetText(slot[2])
    r.mine = itemCell(gearFrame)
    r.mine:SetPoint("TOPLEFT", 90, y)
    r.mine:SetPoint("RIGHT", gearFrame, "CENTER", 20, 0)
    r.theirs = itemCell(gearFrame)
    r.theirs:SetPoint("TOPLEFT", gearFrame, "TOP", 50, y)
    r.theirs:SetPoint("RIGHT", gearFrame, "RIGHT", 0, 0)
    gearRows[i] = r
  end
  local gearNote = UI.Text(gearFrame, 11, nil, C.dim)
  gearNote:SetPoint("BOTTOMLEFT", 0, 0)

  local function fillCell(cell, c, other)
    local link, str = ns.Gear.Link(c)
    local lvl = ns.Gear.Level(c)
    local olvl = ns.Gear.Level(other)
    cell.item = str
    if not c then
      cell.text:SetText(ns.Colorize("–", C.dim)) cell.lvl:SetText("")
      return
    end
    cell.text:SetText(link or ns.Colorize("[loading…]", C.dim))
    cell.lvl:SetText(lvl and tostring(lvl) or "")
    local col = C.text
    if lvl and olvl then col = lvl > olvl and C.green or (lvl < olvl and C.red or C.text) elseif lvl and not other then col = C.green end
    cell.lvl:SetTextColor(hex(col))
  end

  local function fillGear(them)
    local mine, theirs = ns.Gear:Mine(), ns.Gear:For(them)
    for i, slot in ipairs(ns.Gear.SLOTS) do
      local r = gearRows[i]
      local a, b = mine[slot[1]], theirs and theirs[slot[1]]
      fillCell(r.mine, a, b)
      fillCell(r.theirs, b, a)
    end
    if not theirs then
      gearNote:SetText("No gear from them yet – it arrives when they're online with Chillan? 0.22 or newer.")
    else
      gearNote:SetText("Updated " .. ns.Ago(them.gearAt or ns.Now()) .. " · green = better item level in that slot")
    end
  end

  local CENTER_W = 150
  local rows = {}
  for i = 1, #ROWS do
    local r = {}
    local y = -100 - (i - 1) * 25
    r.label = UI.Text(tab, 11, nil, C.muted)
    r.label:SetPoint("TOP", tab, "TOP", 0, y - 4)
    r.label:SetJustifyH("CENTER")
    r.label:SetWidth(CENTER_W)
    r.lv = UI.Text(tab, 13, "semi", C.text)
    r.lv:SetPoint("TOPRIGHT", tab, "TOP", -CENTER_W / 2 - 8, y - 3)
    r.lv:SetJustifyH("RIGHT")
    r.rv = UI.Text(tab, 13, "semi", C.text)
    r.rv:SetPoint("TOPLEFT", tab, "TOP", CENTER_W / 2 + 8, y - 3)
    r.lbar = tab:CreateTexture(nil, "ARTWORK")
    r.lbar:SetTexture(ns.TEX .. "RoundedSmall")
    r.lbar:SetHeight(6)
    r.lbar:SetPoint("TOPRIGHT", tab, "TOP", -CENTER_W / 2 - 80, y - 8)
    r.rbar = tab:CreateTexture(nil, "ARTWORK")
    r.rbar:SetTexture(ns.TEX .. "RoundedSmall")
    r.rbar:SetHeight(6)
    r.rbar:SetPoint("TOPLEFT", tab, "TOP", CENTER_W / 2 + 80, y - 8)
    rows[i] = r
  end

  -- stolpene vokser fram når siden åpnes
  local anim = 0
  tab:SetScript("OnUpdate", function(self, dt)
    if anim >= 1 then return end
    anim = math.min(1, anim + dt * 2.5)
    for _, r in ipairs(rows) do
      if r.lw then r.lbar:SetWidth(math.max(1, r.lw * anim)) r.rbar:SetWidth(math.max(1, r.rw * anim)) end
    end
  end)

  local lastPid
  function tab:Refresh()
    local me = ns:GetPerson(ns.pid, true)
    local them = ns:GetPerson(W.comparePid)
    if not them then return end
    leftName:SetText(ns:ShortWho(me))
    rightName:SetText(ns:ShortWho(them))
    paintSeg()
    local isGear = mode == "gear"
    gearFrame:SetShown(isGear)
    for _, r in ipairs(rows) do
      for _, k in ipairs({ "label", "lv", "rv", "lbar", "rbar" }) do r[k]:SetShown(not isGear) end
    end
    if isGear then
      fillGear(them)
      local cmp = ns.Gear:Compare(them)
      score:SetText(cmp and (cmp.better .. " slots better for them · " .. cmp.worse .. " better for you") or "")
      return
    end
    local MAXW = 150
    local lw, rw = 0, 0
    for i, def in ipairs(ROWS) do
      local r = rows[i]
      local a = def[2](me) or 0
      local b = def[2](them) or 0
      r.label:SetText(def[1])
      r.lv:SetText(fmt(def[3], a))
      r.rv:SetText(fmt(def[3], b))
      local top = math.max(a, b)
      r.lw = top > 0 and (MAXW * a / top) or 1
      r.rw = top > 0 and (MAXW * b / top) or 1
      local aWins = (def[4] and a < b) or (not def[4] and a > b)
      local bWins = (def[4] and b < a) or (not def[4] and b > a)
      if aWins then lw = lw + 1 end
      if bWins then rw = rw + 1 end
      r.lbar:SetVertexColor(hex(aWins and C.accent or C.activeLine))
      r.rbar:SetVertexColor(hex(bWins and C.accent or C.activeLine))
      r.lv:SetTextColor(hex(aWins and C.text or C.muted))
      r.rv:SetTextColor(hex(bWins and C.text or C.muted))
    end
    score:SetText("You lead " .. lw .. " – " .. rw .. (lw > rw and "  ·  nice work" or (lw < rw and "  ·  time to catch up" or "  ·  dead even")))
    if lastPid ~= W.comparePid then
      lastPid = W.comparePid
      anim = 0
    end
  end
end, true)
