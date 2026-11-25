-- Chillan? – battleground panel (1.4.50)
-- Inside a battleground the gang chat is paused (the game blocks addon messages there), so the
-- event window's feed turns into the battleground's objectives: bases and towers by owner with
-- the time until an assaulted one falls, the win estimate, and the two flag carrier slots in
-- Warsong Gulch and Darkspear Islands (click to target, also in combat). Back to the feed on leaving.
local ADDON, ns = ...
local UI, C = ns.UI, ns.C
local hex = ns.hex

local B = {}
ns.BGPanel = B

local HORDE, ALLI, AMBER = C.red, "6FA8F2", C.amber
-- (1.4.54) one colour rule for every battleground: bright = being taken (by that side),
-- deep = held (by that side), dark = destroyed or nobody's
local BRIGHT = { h = "E2575C", a = "4E8FE0" }
local DEEP = { h = "8E2F35", a = "2B5288" }
local function sideColor(s) return s == "h" and HORDE or s == "a" and ALLI or C.dim end
local function sideName(s) return s == "h" and "Horde" or "Alliance" end
local function mmss(s) return string.format("%d:%02d", math.floor(s / 60), s % 60) end
local function dim(t) return ns.Colorize(t, C.dim) end
local MAX_CHIPS = 5
local FLAG_SPELLS = { [23333] = true, [23335] = true }   -- Warsong Flag, Silverwing Flag

function B.Enabled() return ns.db and ns.db.settings and ns.db.settings.bgPanel ~= false end
function B.Active() return B.Enabled() and ns.BGObj and ns.BGObj.key ~= nil end

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------
local function makeChip(parent)
  local c = UI.Panel(parent, C.active, nil, true)
  c:SetHeight(26)
  c.text = UI.Text(c, 11, "semi", C.text)
  c.text:SetPoint("CENTER", 0, 1)
  c.text:SetWordWrap(false)
  -- (1.4.55) the white countdown bar inside a base being taken
  c.fill = c:CreateTexture(nil, "OVERLAY")
  c.fill:SetTexture("Interface\\Buttons\\WHITE8x8")
  c.fill:SetVertexColor(1, 1, 1, 0.9)
  c.fill:SetHeight(2)
  c.fill:SetPoint("BOTTOMLEFT", 4, 3)
  c.fill:Hide()
  return c
end

local SLOT_H = 46
local function makeSlot(parent, label)
  local s = UI.Panel(parent, C.card, C.line, true)
  s:SetHeight(SLOT_H)
  s.label = UI.Text(s, 11, nil, C.dim)
  s.label:SetPoint("TOPLEFT", 8, -6)
  s.label:SetText(label)
  s.hint = UI.Text(s, 10, nil, C.dim)
  s.hint:SetPoint("TOPRIGHT", -8, -7)
  s.name = UI.Text(s, 12, "semi", C.text)
  s.name:SetPoint("LEFT", s.label, "RIGHT", 6, 0)
  s.name:SetPoint("RIGHT", s.hint, "LEFT", -6, 0)
  s.name:SetJustifyH("LEFT")
  s.name:SetWordWrap(false)
  s.bar = CreateFrame("StatusBar", nil, s)
  s.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
  s.bar:SetPoint("TOPLEFT", 8, -22)
  s.bar:SetPoint("TOPRIGHT", -8, -22)
  s.bar:SetHeight(4)
  s.bar:SetMinMaxValues(0, 1)
  s.bar:SetValue(0)
  s.bar.bg = s.bar:CreateTexture(nil, "BACKGROUND")
  s.bar.bg:SetAllPoints()
  UI.Track(s.bar.bg):SetColorTexture(hex(C.active))
  s.where = UI.Text(s, 11, nil, C.dim)
  s.where:SetPoint("BOTTOMLEFT", 8, 6)
  s.where:SetPoint("BOTTOMRIGHT", -8, 6)
  s.where:SetJustifyH("LEFT")
  s.where:SetWordWrap(false)
  return s
end

-- the click-to-target button over a slot: a secure button the game lets us click in combat. Its
-- unit is set outside combat only, so the enemy slot uses the game's own carrier unit (arena1),
-- which always points at whoever holds the flag.
local function makeSecure(slot)
  local b = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
  b:SetFrameStrata("HIGH")
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "target")
  b.slot = slot
  b:Hide()
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Click: target the carrier", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

function B:Create()
  local E = ns.EventWindow
  if self.frame or not E or not E.frame then return end
  local f = CreateFrame("Frame", nil, E.frame)
  f:SetPoint("TOPLEFT", E.sep, "BOTTOMLEFT", 2, -8)
  f:SetPoint("BOTTOMRIGHT", E.frame, "BOTTOMRIGHT", -10, 8)
  f:Hide()
  self.frame = f
  self.chips = {}
  for i = 1, MAX_CHIPS do self.chips[i] = makeChip(f) end
  self.info = UI.Text(f, 12, nil, C.text2)
  self.info:SetJustifyH("LEFT")
  self.info:SetWordWrap(false)
  self.right = UI.Text(f, 12, nil, C.text2)
  self.right:SetJustifyH("RIGHT")
  self.right:SetWordWrap(false)
  self.info2 = UI.Text(f, 12, nil, C.text2)
  self.info2:SetJustifyH("LEFT")
  self.right2 = UI.Text(f, 12, "semi", C.text)
  self.right2:SetJustifyH("RIGHT")
  self.empty = UI.Text(f, 12, nil, C.dim)
  self.score = UI.Text(f, 13, "semi", C.text)
  self.score:SetJustifyH("LEFT")
  self.scoreR = UI.Text(f, 13, "semi", C.text)
  self.scoreR:SetJustifyH("RIGHT")
  -- (1.4.56) Darkspear Islands has its own slot at the very bottom: it used to borrow the Enemy FC
  -- slot, which sits above the (hidden) Our FC one and so landed on top of the base chips
  self.slots = { makeSlot(f, "Enemy FC"), makeSlot(f, "Our FC"), makeSlot(f, "Centre flag") }
  -- (1.4.52) fixed at the bottom and never moved: a frame a secure button is anchored to can't be
  -- moved or hidden in combat
  self.slots[2]:SetPoint("BOTTOMLEFT", 0, 0)
  self.slots[2]:SetPoint("BOTTOMRIGHT", 0, 0)
  self.slots[1]:SetPoint("BOTTOMLEFT", self.slots[2], "TOPLEFT", 0, 4)
  self.slots[1]:SetPoint("BOTTOMRIGHT", self.slots[2], "TOPRIGHT", 0, 4)
  self.slots[3]:SetPoint("BOTTOMLEFT", 0, 0)
  self.slots[3]:SetPoint("BOTTOMRIGHT", 0, 0)
  self.slots[1]:Hide() self.slots[2]:Hide() self.slots[3]:Hide()
  self.secure = { makeSecure(self.slots[1]), makeSecure(self.slots[2]), makeSecure(self.slots[3]) }
  self.secure[1]:SetAttribute("unit", "arena1")
  self.secure[3]:SetAttribute("unit", "arena1")
end

---------------------------------------------------------------------------
-- the carriers
---------------------------------------------------------------------------
local function unitOK(u)
  local ok, ex = pcall(UnitExists, u)
  return ok and ex == true
end

-- our carrier: a raid member with a flag buff (names and auras the game hides are skipped)
local function findOurCarrier()
  if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return nil end
  local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
  if ns.isSecret(n) then return nil end
  for i = 1, math.min(n, 40) do
    local u = "raid" .. i
    if unitOK(u) then
      for j = 1, 40 do
        local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, u, j, "HELPFUL")
        if not ok or type(a) ~= "table" then break end
        local id, nm = a.spellId, a.name
        if not ns.isSecret(id) and FLAG_SPELLS[id] then return u end
        if not ns.isSecret(nm) and type(nm) == "string" and nm:find(" Flag$") then return u end
      end
    end
  end
  return nil
end

-- (1.4.55) a carrier row: "Enemy FC  Thornleaf Druid" with a health bar (the game draws it; the
-- number is hidden, so no %), and where the flag is. unit: the game's carrier unit or a raid
-- member; chatName: who the announcement said picked it up. Returns true when someone carries it.
local function fillSlot(s, label, unit, chatName, where, barColor)
  s.label:SetText(label)
  local has = unit and unitOK(unit)
  if has then
    local okN, name = pcall(UnitName, unit)
    local okC, cname, cls = pcall(UnitClass, unit)
    local nameOK = okN and type(name) == "string" and not ns.isSecret(name)
    local clsOK = okC and type(cls) == "string" and not ns.isSecret(cls)
    if nameOK then
      s.name:SetText(ns.Colorize(name, clsOK and ns.ClassHex(cls) or C.text) .. ((okC and type(cname) == "string" and not ns.isSecret(cname)) and dim("  " .. cname) or ""))
    elseif okN and name ~= nil then
      pcall(s.name.SetText, s.name, name)      -- a hidden name the game still lets us draw
    else
      s.name:SetText(chatName or "")
    end
    local okM, mx = pcall(UnitHealthMax, unit)
    local okH, hp = pcall(UnitHealth, unit)
    if okM and okH then
      pcall(s.bar.SetMinMaxValues, s.bar, 0, mx)
      pcall(s.bar.SetValue, s.bar, hp)
    end
    s.bar:SetStatusBarColor(hex(barColor or C.green))
    s.bar:Show()
    s.hint:SetText("click to target")
  elseif chatName or where then
    s.name:SetText(chatName and ns.Colorize(chatName, C.text) or "")
    s.bar:Hide()
    s.hint:SetText("")
  else
    s.name:SetText(dim("at base"))
    s.bar:Hide()
    s.hint:SetText("")
  end
  s.where:SetText(where or "")
  s:SetAlpha((has or chatName or where) and 1 or 0.7)
  return has or chatName ~= nil or where ~= nil
end

---------------------------------------------------------------------------
-- Alterac Valley (1.4.51): "next to fall" with a big countdown and bar, the other attacks with a
-- thin bar each, and the towers each side has left
---------------------------------------------------------------------------
local MAX_ROWS = 4
local function makeBar(parent, h)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
  bar:SetHeight(h)
  bar:SetMinMaxValues(0, 1)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints()
  UI.Track(bar.bg):SetColorTexture(hex(C.active))
  return bar
end

function B:CreateAV()
  if self.av then return end
  local f = self.frame
  local v = {}
  v.kicker = UI.Text(f, 11, nil, C.dim)
  v.kicker:SetText("Next to fall")
  v.name = UI.Text(f, 15, "bold", C.text)
  v.name:SetWordWrap(false)
  v.sub = UI.Text(f, 12, nil, C.text2)
  v.sub:SetWordWrap(false)
  v.big = UI.Text(f, 24, "bold", C.text)
  v.big:SetJustifyH("RIGHT")
  v.bar = makeBar(f, 8)
  v.also = UI.Text(f, 10, "semi", C.dim)
  v.also:SetText("ALSO UNDER ATTACK")
  v.rows = {}
  for i = 1, MAX_ROWS do
    local r = {}
    r.label = UI.Text(f, 12, nil, C.text)
    r.label:SetJustifyH("LEFT")
    r.label:SetWordWrap(false)
    r.time = UI.Text(f, 12, "bold", C.text)
    r.time:SetJustifyH("RIGHT")
    r.bar = makeBar(f, 5)
    v.rows[i] = r
  end
  v.line = f:CreateTexture(nil, "ARTWORK")
  UI.Track(v.line):SetColorTexture(hex(C.line))
  v.line:SetHeight(1)
  v.hLabel = UI.Text(f, 12, nil, HORDE)
  v.hLabel:SetText("Horde towers")
  v.aLabel = UI.Text(f, 12, nil, ALLI)
  v.aLabel:SetText("Alliance towers")
  v.pips = { h = {}, a = {} }
  for _, side in ipairs({ "h", "a" }) do
    for i = 1, 4 do
      local t = f:CreateTexture(nil, "ARTWORK")
      t:SetSize(11, 11)
      t:SetTexture("Interface\\Buttons\\WHITE8x8")
      v.pips[side][i] = t
    end
  end
  -- (1.4.52) hover the squares: which towers stand, burn or are gone
  v.hit = {}
  for _, side in ipairs({ "h", "a" }) do
    local hit = CreateFrame("Frame", nil, f)
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(sideName(side) .. " towers", hex(sideColor(side)))
      for _, t in ipairs(ns.BGObj:TowerList(side)) do
        local r, g, b = 0.6, 0.63, 0.66
        local txt = t.state
        if t.state == "standing" then r, g, b = hex(sideColor(side))
        elseif t.state == "burning" then r, g, b = hex(BRIGHT[side == "h" and "a" or "h"]) txt = "burning" .. (t.left and (" · " .. mmss(t.left)) or "")
        elseif t.state == "gone" then txt = "destroyed"
        else txt = "not seen yet" end
        GameTooltip:AddDoubleLine(t.name, txt, 1, 1, 1, r, g, b)
      end
      GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    v.hit[side] = hit
  end
  self.av = v
end

local function avHide(v)
  if not v then return end
  for _, x in ipairs({ v.kicker, v.name, v.sub, v.big, v.bar, v.also, v.line, v.hLabel, v.aLabel }) do x:Hide() end
  for _, r in ipairs(v.rows) do r.label:Hide() r.time:Hide() r.bar:Hide() end
  for _, side in pairs(v.pips) do for _, t in ipairs(side) do t:Hide() end end
  for _, h in pairs(v.hit) do h:Hide() end
end

-- what a node is and who's taking it, in words
local function avWhat(node)
  local tower = ns.BGObj.avTowerSide(node.name)
  local taker = ns.Colorize(sideName(node.atk), sideColor(node.atk))
  if tower and node.atk == tower then
    return ns.Colorize(sideName(tower) .. " tower", sideColor(tower)) .. dim(" · ") .. taker .. dim(" taking it back")
  end
  if tower then
    return ns.Colorize(sideName(tower) .. " tower", sideColor(tower)) .. dim(" · ") .. taker .. dim(" burning it")
  end
  return taker .. dim(" taking it")
end
local function avName(node) return (node.name:gsub(" Graveyard$", " GY")) end

function B:DrawAV(y, w)
  self:CreateAV()
  local v, O = self.av, ns.BGObj
  local cap = O.CAP.AV
  -- (1.4.55) only what's on a countdown, soonest first
  local list = {}
  for _, n in ipairs(O:Chips()) do if O:Left(n) then list[#list + 1] = n end end
  table.sort(list, function(x, z)
    local lx, lz = O:Left(x), O:Left(z)
    if lx and lz then return lx < lz end
    if lx or lz then return lx ~= nil end
    return x.name < z.name
  end)
  if #list == 0 then
    self.empty:ClearAllPoints()
    self.empty:SetPoint("TOPLEFT", 0, y)
    self.empty:SetText("No towers or graveyards under attack")
    y = y - 22
  else
    local first = list[1]
    local left = O:Left(first)
    v.kicker:ClearAllPoints() v.kicker:SetPoint("TOPLEFT", 0, y) v.kicker:Show()
    v.big:ClearAllPoints() v.big:SetPoint("TOPRIGHT", 0, y - 6)
    v.big:SetText(left and mmss(left) or "")
    v.big:Show()
    v.name:ClearAllPoints() v.name:SetPoint("TOPLEFT", 0, y - 14) v.name:SetPoint("RIGHT", v.big, "LEFT", -8, 0)
    v.name:SetText(avName(first)) v.name:Show()
    -- (1.4.55) no "Alliance tower · Horde burning it": the bar's colour says who's taking it
    y = y - 36
    v.bar:ClearAllPoints() v.bar:SetPoint("TOPLEFT", 0, y) v.bar:SetPoint("TOPRIGHT", 0, y)
    v.bar:SetStatusBarColor(hex(BRIGHT[first.atk] or C.muted))
    v.big:SetTextColor(hex(BRIGHT[first.atk] or C.text))
    v.bar:SetValue(left and (left / cap) or 0)
    v.bar:Show()
    y = y - 16
    if #list > 1 then
      v.also:ClearAllPoints() v.also:SetPoint("TOPLEFT", 0, y) v.also:Show()
      y = y - 16
      -- as many rows as fit above the tower squares; the rest as "+N more"
      local shown = math.min(#list - 1, MAX_ROWS)
      for i = 2, shown + 1 do
        local node, r = list[i], v.rows[i - 1]
        local l = O:Left(node)
        r.label:ClearAllPoints() r.label:SetPoint("TOPLEFT", 0, y) r.label:SetPoint("RIGHT", r.time, "LEFT", -8, 0)
        r.time:ClearAllPoints() r.time:SetPoint("TOPRIGHT", 0, y)
        r.label:SetText(avName(node))
        r.time:SetText(mmss(l))
        r.bar:ClearAllPoints() r.bar:SetPoint("TOPLEFT", 0, y - 17) r.bar:SetPoint("TOPRIGHT", 0, y - 17)
        r.bar:SetStatusBarColor(hex(BRIGHT[node.atk] or C.muted))
        r.bar:SetValue(l and (l / cap) or 0)
        r.bar:SetAlpha(l and 1 or 0.5)
        r.label:Show() r.time:Show() r.bar:Show()
        y = y - 28
      end
      if #list - 1 > shown then
        self.empty:ClearAllPoints() self.empty:SetPoint("TOPLEFT", 0, y)
        self.empty:SetText("+" .. (#list - 1 - shown) .. " more under attack")
        y = y - 16
      end
    end
  end
  -- the towers each side has left: filled = standing, amber = burning, outline = gone
  local st = O:TowerStates()
  if st then
    v.line:ClearAllPoints() v.line:SetPoint("TOPLEFT", 0, y - 2) v.line:SetPoint("TOPRIGHT", 0, y - 2) v.line:Show()
    y = y - 10
    v.hLabel:ClearAllPoints() v.hLabel:SetPoint("TOPLEFT", 0, y) v.hLabel:Show()
    v.aLabel:ClearAllPoints()
    local pipW = 4 * 14
    v.aLabel:SetPoint("TOPRIGHT", -(pipW + 6), y) v.aLabel:Show()
    for _, side in ipairs({ "h", "a" }) do
      local s = st[side]
      for i = 1, 4 do
        local t = v.pips[side][i]
        t:ClearAllPoints()
        if side == "h" then t:SetPoint("LEFT", v.hLabel, "RIGHT", 6 + (i - 1) * 14, 0)
        else t:SetPoint("TOPRIGHT", -((4 - i) * 14), y - 1) end
        local col, a = DEEP[side], 1
        if i <= s.burning then col = BRIGHT[side == "h" and "a" or "h"]
        elseif i > s.standing then col, a = C.active, 1 end
        t:SetVertexColor(hex(col))
        t:SetAlpha(a)
        t:Show()
      end
    end
    v.hit.h:ClearAllPoints()
    v.hit.h:SetPoint("TOPLEFT", v.hLabel, "TOPLEFT", -2, 3)
    v.hit.h:SetPoint("BOTTOMRIGHT", v.pips.h[4], "BOTTOMRIGHT", 2, -3)
    v.hit.a:ClearAllPoints()
    v.hit.a:SetPoint("TOPLEFT", v.aLabel, "TOPLEFT", -2, 3)
    v.hit.a:SetPoint("BOTTOMRIGHT", v.pips.a[4], "BOTTOMRIGHT", 2, -3)
    v.hit.h:Show() v.hit.a:Show()
    y = y - 20
  end
  return y
end

---------------------------------------------------------------------------
-- flags and carriers (1.4.54): where each flag is, from the map, which the game shows everyone.
-- A carrier's name, health and click-to-target only when the game gives us the carrier itself.
---------------------------------------------------------------------------
-- (1.4.55) flags: where each one is (the map), who has it (the game's carrier unit, the
-- announcements, our raid's flag buff)
function B:DrawCarriers(key)
  local O = ns.BGObj
  local spots = O:FlagSpots() or {}
  local me = ns.S(UnitFactionGroup, "player") == "Alliance" and "a" or "h"
  local them = me == "h" and "a" or "h"
  local enemyUnit = unitOK("arena1") and "arena1" or nil
  local ourUnit = findOurCarrier()
  local function near(sp) return sp and sp.near and ("near " .. sp.near) or nil end
  if key == "WSG" then
    local ours, theirs
    for _, sp in ipairs(spots) do
      if sp.owner == me then ours = sp elseif sp.owner then theirs = sp end
    end
    -- our flag is carried by them (Enemy FC); theirs by us (Our FC)
    local fo, ft = O:FlagInfo(me), O:FlagInfo(them)
    local w1 = (ours or (fo and fo.state == "carried")) and ("Has our flag" .. (near(ours) and (dim(" · ") .. near(ours)) or "")) or nil
    local w2 = (theirs or (ft and ft.state == "carried")) and ("Has their flag" .. (near(theirs) and (dim(" · ") .. near(theirs)) or "")) or nil
    fillSlot(self.slots[1], "Enemy FC", enemyUnit, fo and fo.state == "carried" and fo.by or nil, w1 and dim(w1), BRIGHT[them])
    fillSlot(self.slots[2], "Our FC", ourUnit, ft and ft.state == "carried" and ft.by or nil, w2 and dim(w2), C.green)
  else
    -- Darkspear Islands: one flag in the middle, carried by either side. One row says it all:
    -- who carries it and where, or "dropped · back in 0:07", "back in 0:18", "in the middle".
    local s = self.slots[3]
    local sp = spots[1]
    local fi = O:FlagInfo("n")
    local carried = fi and fi.state == "carried"
    local ourSide = (fi and fi.bySide == me) or ourUnit ~= nil
    local theirSide = fi and fi.bySide == them
    local unit = ourUnit or enemyUnit
    local dl, rl = O:DroppedLeft(), O:ResetLeft()
    if unit or carried then
      local label = ourSide and "Our FC" or (theirSide or enemyUnit) and "Enemy FC" or "Centre flag"
      fillSlot(s, label, unit, carried and fi.by or nil, dim("Has the centre flag" .. (near(sp) and (" · " .. near(sp)) or "")),
        ourSide and C.green or BRIGHT[them])
      if label == "Centre flag" and not unit and not (fi and fi.by) then s.name:SetText(dim("carried")) end
    else
      fillSlot(s, "Centre flag", nil, nil, nil)
      if dl then
        s.name:SetText(dim("dropped · back in ") .. mmss(dl))
      elseif rl then
        s.name:SetText(dim("back in ") .. mmss(rl))
      elseif sp then
        -- the map shows it away from the middle but nobody said who has it
        s.name:SetText(dim("carried"))
        s.where:SetText(near(sp) and dim("near " .. near(sp)) or "")
      else
        s.name:SetText(dim("in the middle"))
      end
      s:SetAlpha(1)
    end
  end
  if ourUnit and ourUnit ~= self.ourUnit and not InCombatLockdown() then
    self.ourUnit = ourUnit
    self.secure[2]:SetAttribute("unit", ourUnit)
  end
  -- Darkspear Islands' one button: our carrier when we have it, else the game's carrier unit
  local want3 = ourUnit or "arena1"
  if key == "DI" and want3 ~= self.diUnit and not InCombatLockdown() then
    self.diUnit = want3
    self.secure[3]:SetAttribute("unit", want3)
  end
end

---------------------------------------------------------------------------
-- drawing
---------------------------------------------------------------------------
local function line(self, y, left, right)
  self.info:ClearAllPoints() self.right:ClearAllPoints()
  self.info:SetPoint("TOPLEFT", 0, y)
  self.right:SetPoint("TOPRIGHT", 0, y)
  self.info:SetText(left or "") self.right:SetText(right or "")
end
local function line2(self, y, left, right)
  self.info2:ClearAllPoints() self.right2:ClearAllPoints()
  self.info2:SetPoint("TOPLEFT", 0, y)
  self.right2:SetPoint("TOPRIGHT", 0, y)
  self.info2:SetText(left or "") self.right2:SetText(right or "")
end

function B:Draw()
  if not self.frame then return end
  local O = ns.BGObj
  local key = O.key
  local f = self.frame
  -- as wide as the window itself, never wider
  local ew = ns.EventWindow.frame and ns.EventWindow.frame:GetWidth()
  local w = f:GetWidth()
  if ew and ew > 60 then w = math.min(w and w > 50 and w or ew, ew - 20) end
  if not w or w < 50 then w = 300 end
  local y = 0
  for _, c in ipairs(self.chips) do c:Hide() end
  self.info:SetText("") self.right:SetText("") self.info2:SetText("") self.right2:SetText("") self.empty:SetText("")
  self.score:SetText("") self.scoreR:SetText("")
  avHide(self.av)
  local carriers = key == "WSG" or key == "DI"
  local nSlots = key == "WSG" and 2 or key == "DI" and 1 or 0
  local showSlot = { key == "WSG", key == "WSG", key == "DI" }

  if key == "AV" then
    y = self:DrawAV(y, w)
  else
    -- the score, per side (Warsong Gulch: flags out of 3)
    local sc = O:Score()
    if sc then
      local wsg = key == "WSG"
      local function sv(t) return wsg and (t.score .. "/" .. (t.max or 3) .. dim(" flags")) or ns.Num(t.score) end
      self.score:ClearAllPoints() self.scoreR:ClearAllPoints()
      self.score:SetPoint("TOPLEFT", 0, y)
      self.scoreR:SetPoint("TOPRIGHT", 0, y)
      self.score:SetText(ns.Colorize("Horde ", HORDE) .. sv(sc.h)
        .. ((sc.h.bases and not wsg) and dim("  ·  " .. ns.Plural(sc.h.bases, "base")) or ""))
      self.scoreR:SetText(((sc.a.bases and not wsg) and dim(ns.Plural(sc.a.bases, "base") .. "  ·  ") or "")
        .. sv(sc.a) .. ns.Colorize(" Alliance", ALLI))
      y = y - 20
    end
    if key == "AB" or key == "DI" then
      local side, secs, other = O:Estimate(sc)
      if side and secs < 3600 then
        local max = sc and sc.a.max or 2000
        line(self, y, ns.Colorize(sideName(side) .. " wins in ~" .. math.max(1, math.ceil(secs / 60)) .. " min", side == "h" and C.green or HORDE),
          other and (dim("final score estimate ") .. ns.Num(max) .. " – " .. ns.Num(other)) or "")
        y = y - 18
      end
      -- every base: deep when held, bright with a white countdown bar while being taken
      local list = O:Chips()
      if #list > 0 then
        local n = math.min(#list, MAX_CHIPS)
        local cw = math.floor((w - (n - 1) * 4) / n)
        for i = 1, n do
          local node, c = list[i], self.chips[i]
          c:ClearAllPoints()
          c:SetPoint("TOPLEFT", (i - 1) * (cw + 4), y - 2)
          c:SetWidth(cw)
          local label = ns.BGObj.Short(node.name)
          local left = node.atk and O:Left(node)
          if node.atk then
            c:SetColors(BRIGHT[node.atk] or "5A5F67", BRIGHT[node.atk] or "8A9099")
            c.text:SetText(ns.Colorize(label, "FFFFFF") .. (left and ("  " .. ns.Colorize(mmss(left), "FFFFFF")) or ""))
            local cap = O.CAP[key] or 60
            c.fill:SetWidth(math.max(1, (cw - 8) * ((left or 0) / cap)))
            c.fill:SetShown(left ~= nil)
          else
            local s = node.side
            c:SetColors(DEEP[s] or C.active)
            c.text:SetText(ns.Colorize(label, s == "h" and "F3B5B7" or s == "a" and "B9D3F5" or C.muted))
            c.fill:Hide()
          end
          c:Show()
        end
        y = y - 30
      else
        self.empty:ClearAllPoints()
        self.empty:SetPoint("TOPLEFT", 0, y)
        self.empty:SetText("Waiting for the bases …")
        y = y - 18
      end
    end
    -- Warsong Gulch: the game clock
    if key == "WSG" then
      local clock = O:GameClock()
      if clock then line(self, y, dim("Game ends in"), mmss(clock)) y = y - 18 end
    end
  end

  -- flag countdowns: a dropped flag going home, the flags back after a capture
  local t2l, t2r
  local dl = O:DroppedLeft()
  if dl and key ~= "DI" then t2l, t2r = dim("Dropped flag respawns in"), mmss(dl)
  elseif key == "WSG" and O:RespawnLeft() then t2l, t2r = dim("Flags back in"), mmss(O:RespawnLeft())
  end

  -- the carriers: fixed slots at the bottom (they can't move in a fight)
  if not InCombatLockdown() then
    for i, s in ipairs(self.slots) do
      local want = showSlot[i] and true or false
      if s:IsShown() ~= want then s:SetShown(want) end
    end
  end
  if carriers then self:DrawCarriers(key) end
  local slotsH = nSlots > 0 and (nSlots * (SLOT_H + 4)) or 0
  if t2l then
    self.info2:ClearAllPoints() self.right2:ClearAllPoints()
    line2(self, y, t2l, t2r)
    y = y - 18
  end
  self.contentH = -y + slotsH + (slotsH > 0 and 4 or 0)
  self:SyncSecure(carriers and f:IsVisible())
  self:Fit()
end

-- (1.4.55) PvP mode: the window is as tall as what it shows, the width stays yours. Your own size
-- comes back when you leave. Not changed in a fight while the carrier buttons sit on it.
function B:Fit()
  local E = ns.EventWindow
  local ef = E and E.frame
  if not ef or not self.on or not self.contentH then return end
  if InCombatLockdown() and self.secureOn then return end
  local top, sepB = ef:GetTop(), E.sep and E.sep:GetBottom()
  local head = (top and sepB and not ns.isSecret(top) and not ns.isSecret(sepB)) and (top - sepB) or 40
  local want = math.floor(math.max(60, math.min(600, head + 8 + self.contentH + 10)))
  if math.abs((ef:GetHeight() or 0) - want) >= 1 then
    ef:SetHeight(want)
    if ns.Overlays and ns.Overlays.UpdateGroup then ns.Overlays:UpdateGroup() end
  end
end

-- the secure buttons can only be shown, hidden or changed outside combat
function B:SyncSecure(on)
  if InCombatLockdown() then self.pendingSecure = on return end
  self.pendingSecure = nil
  self.secureOn = on and true or false
  for _, b in ipairs(self.secure or {}) do
    if on and b.slot:IsShown() then
      b:ClearAllPoints()
      b:SetAllPoints(b.slot)
      b:Show()
    else
      b:Hide()
      b:ClearAllPoints()   -- free the slot again, so it can be hidden in a fight
    end
  end
end

---------------------------------------------------------------------------
-- switching the event window between the feed and the battleground
---------------------------------------------------------------------------
function B:Apply()
  local E = ns.EventWindow
  if not E or not E.frame then return end
  self:Create()
  local on = B.Active() and not ns.db.settings.evMin
  self.frame:SetShown(on)
  if E.msg then E.msg:SetShown(not on) end
  if E.input then E.input:SetShown(not on) end
  for _, b in pairs(E.filterBtns or {}) do b:SetShown(not on) end
  local was = self.on
  self.on = on
  -- (1.4.55) no resizing by hand in PvP mode (the height follows the panel)
  if E.grip then E.grip:SetShown(not on and not UI.IsLocked() and not ns.db.settings.evMin) end
  if on then
    self:Draw()
  else
    self:SyncSecure(false)
    -- back to your own size
    if was and not InCombatLockdown() then
      local S = ns.db.settings
      local sz = S.evSize or { w = 380, h = 210 }
      if not S.evMin then E.frame:SetHeight(E.frame.noMove and (S.evDockH or sz.h) or sz.h) end
      if ns.Overlays and ns.Overlays.UpdateGroup then ns.Overlays:UpdateGroup() end
    elseif was then
      self.restoreLater = true
    end
  end
end

function B:Init()
  ns:Listen("BGOBJ", function() B:Apply() end)
  ns:On("PLAYER_REGEN_ENABLED", function()
    if B.pendingSecure ~= nil then B:SyncSecure(B.pendingSecure) end
    if B.restoreLater then B.restoreLater = nil B.on = true B:Apply() end
    if B.on then B:Fit() end
  end)
  -- countdowns and carrier health: once a second while it's showing
  C_Timer.NewTicker(1, function()
    if B.on and B.frame and B.frame:IsVisible() then
      if ns.BGObj.key and ns.BGObj.key ~= "WSG" then ns.BGObj:ScanNodes() end
      B:Draw()
    end
  end)
end
