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
  c:SetHeight(22)
  c.text = UI.Text(c, 11, "semi", C.text)
  c.text:SetPoint("CENTER")
  c.text:SetWordWrap(false)
  return c
end

local function makeSlot(parent, label)
  local s = UI.Panel(parent, C.card, C.line, true)
  s:SetHeight(32)
  s.label = UI.Text(s, 11, nil, C.dim)
  s.label:SetPoint("TOPLEFT", 8, -5)
  s.label:SetText(label)
  s.name = UI.Text(s, 11, "semi", C.text)
  s.name:SetPoint("LEFT", s.label, "RIGHT", 6, 0)
  s.name:SetPoint("RIGHT", -8, 0)
  s.name:SetJustifyH("LEFT")
  s.name:SetWordWrap(false)
  s.bar = CreateFrame("StatusBar", nil, s)
  s.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
  s.bar:SetPoint("BOTTOMLEFT", 8, 5)
  s.bar:SetPoint("BOTTOMRIGHT", -8, 5)
  s.bar:SetHeight(4)
  s.bar:SetMinMaxValues(0, 1)
  s.bar:SetValue(0)
  s.bar.bg = s.bar:CreateTexture(nil, "BACKGROUND")
  s.bar.bg:SetAllPoints()
  UI.Track(s.bar.bg):SetColorTexture(hex(C.active))
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
  b:SetAllPoints(slot)
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
  self.empty = UI.Text(f, 12, nil, C.dim)
  self.score = UI.Text(f, 13, "semi", C.text)
  self.score:SetJustifyH("LEFT")
  self.scoreR = UI.Text(f, 13, "semi", C.text)
  self.scoreR:SetJustifyH("RIGHT")
  self.slots = { makeSlot(f, "Enemy carrier"), makeSlot(f, "Our carrier") }
  self.secure = { makeSecure(self.slots[1]), makeSecure(self.slots[2]) }
  self.secure[1]:SetAttribute("unit", "arena1")
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

local function fillSlot(s, unit, emptyText)
  if unit and unitOK(unit) then
    local okN, name = pcall(UnitName, unit)
    if okN and name ~= nil then pcall(s.name.SetText, s.name, name) end
    local okC, _, cls = pcall(UnitClass, unit)
    if okC and type(cls) == "string" and not ns.isSecret(cls) then s.name:SetTextColor(hex(ns.ClassHex(cls))) else s.name:SetTextColor(hex(C.text)) end
    local okM, mx = pcall(UnitHealthMax, unit)
    local okH, hp = pcall(UnitHealth, unit)
    if okM and okH then
      pcall(s.bar.SetMinMaxValues, s.bar, 0, mx)
      pcall(s.bar.SetValue, s.bar, hp)
    end
    s.bar:Show()
    s:SetAlpha(1)
    return true
  end
  s.name:SetText(emptyText)
  s.name:SetTextColor(hex(C.dim))
  s.bar:Hide()
  s:SetAlpha(0.7)
  return false
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
  v.big = UI.Text(f, 24, "bold", AMBER)
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
  self.av = v
end

local function avHide(v)
  if not v then return end
  for _, x in ipairs({ v.kicker, v.name, v.sub, v.big, v.bar, v.also, v.line, v.hLabel, v.aLabel }) do x:Hide() end
  for _, r in ipairs(v.rows) do r.label:Hide() r.time:Hide() r.bar:Hide() end
  for _, side in pairs(v.pips) do for _, t in ipairs(side) do t:Hide() end end
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
  -- soonest first; attacks that started before we came (no time) last
  local list = O:Chips()
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
    v.sub:ClearAllPoints() v.sub:SetPoint("TOPLEFT", 0, y - 33) v.sub:SetPoint("RIGHT", 0, 0)
    v.sub:SetText(avWhat(first) .. (left and "" or dim(" · started before you joined"))) v.sub:Show()
    y = y - 52
    v.bar:ClearAllPoints() v.bar:SetPoint("TOPLEFT", 0, y) v.bar:SetPoint("TOPRIGHT", 0, y)
    v.bar:SetStatusBarColor(hex(AMBER))
    v.bar:SetValue(left and (left / cap) or 0)
    v.bar:Show()
    y = y - 16
    if #list > 1 then
      v.also:ClearAllPoints() v.also:SetPoint("TOPLEFT", 0, y) v.also:Show()
      y = y - 16
      -- as many rows as fit above the tower squares; the rest as "+N more"
      local room = (self.frame:GetHeight() or 200) + y - 34
      local fit = math.max(1, math.min(MAX_ROWS, math.floor(room / 28)))
      local shown = math.min(#list - 1, fit)
      for i = 2, shown + 1 do
        local node, r = list[i], v.rows[i - 1]
        local l = O:Left(node)
        r.label:ClearAllPoints() r.label:SetPoint("TOPLEFT", 0, y) r.label:SetPoint("RIGHT", r.time, "LEFT", -8, 0)
        r.time:ClearAllPoints() r.time:SetPoint("TOPRIGHT", 0, y)
        r.label:SetText(avName(node) .. dim(" · ") .. avWhat(node))
        r.time:SetText(l and mmss(l) or dim("before you joined"))
        r.bar:ClearAllPoints() r.bar:SetPoint("TOPLEFT", 0, y - 17) r.bar:SetPoint("TOPRIGHT", 0, y - 17)
        r.bar:SetStatusBarColor(hex(sideColor(node.atk)))
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
        local col, a = sideColor(side), 1
        if i <= s.burning then col = AMBER
        elseif i > s.standing then col, a = C.active, 1 end
        t:SetVertexColor(hex(col))
        t:SetAlpha(a)
        t:Show()
      end
    end
    y = y - 20
  end
  return y
end

---------------------------------------------------------------------------
-- drawing
---------------------------------------------------------------------------
function B:Draw()
  if not self.frame then return end
  local O = ns.BGObj
  local key = O.key
  local f = self.frame
  local w = f:GetWidth()
  if not w or w < 50 then w = 300 end
  local y = 0
  for _, c in ipairs(self.chips) do c:Hide() end
  self.info:SetText("") self.right:SetText("") self.empty:SetText("")
  self.score:SetText("") self.scoreR:SetText("")
  avHide(self.av)
  local carriers = key == "WSG" or key == "DI"

  if key == "AV" then
    y = self:DrawAV(y, w)
  else
    -- (1.4.51) the score, here instead of the first tile
    local sc = O:Score()
    if sc then
      local unit = key == "WSG" and " flags" or ""
      self.score:ClearAllPoints() self.scoreR:ClearAllPoints()
      self.score:SetPoint("TOPLEFT", 0, y)
      self.scoreR:SetPoint("TOPRIGHT", 0, y)
      self.score:SetText(ns.Colorize("Horde ", HORDE) .. ns.Colorize(sc.h.score, C.text)
        .. ((sc.h.bases and key ~= "WSG") and dim("  ·  " .. ns.Plural(sc.h.bases, "base")) or "") .. dim(unit))
      self.scoreR:SetText(((sc.a.bases and key ~= "WSG") and dim(ns.Plural(sc.a.bases, "base") .. "  ·  ") or "")
        .. ns.Colorize(sc.a.score, C.text) .. ns.Colorize(" Alliance", ALLI))
      y = y - 22
    end
  end

  -- bases (Arathi Basin, Darkspear Islands)
  if key == "AB" or key == "DI" then
    local list = O:Chips()
    if #list == 0 then
      self.empty:ClearAllPoints()
      self.empty:SetPoint("TOPLEFT", 0, y)
      self.empty:SetText("Waiting for the bases …")
      y = y - 18
    else
      local n = math.min(#list, MAX_CHIPS)
      local cw = math.floor((w - (n - 1) * 4) / n)
      for i = 1, n do
        local node, c = list[i], self.chips[i]
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", (i - 1) * (cw + 4), y)
        c:SetWidth(cw)
        local label = ns.BGObj.Short(node.name)
        if node.atk then
          local left = O:Left(node)
          c:SetColors("3A3220", AMBER)
          c.text:SetText(label .. " " .. ns.Colorize(left and mmss(left) or "", sideColor(node.atk)))
        else
          local s = node.side
          c:SetColors(s == "h" and "3A1F22" or s == "a" and "1C2A3D" or C.active)
          c.text:SetText(ns.Colorize(label, s and s ~= "n" and sideColor(s) or C.muted))
        end
        c:Show()
      end
      y = y - 28
    end
  end

  -- the line under: win estimate, or when the flags are back
  local left, right = "", ""
  if key == "AB" or key == "DI" then
    local side, secs = O:Estimate()
    if side and secs < 3600 then right = ns.Colorize(sideName(side) .. " wins in ~" .. math.max(1, math.ceil(secs / 60)) .. " min", side == "h" and C.green or HORDE) end
  elseif key == "WSG" then
    local r = O:RespawnLeft()
    if r then left = dim("Flags back in ") .. ns.Colorize(mmss(r), AMBER) end
  end
  if left ~= "" or right ~= "" then
    self.info:ClearAllPoints() self.right:ClearAllPoints()
    self.info:SetPoint("TOPLEFT", 0, y)
    self.right:SetPoint("TOPRIGHT", 0, y)
    self.info:SetText(left) self.right:SetText(right)
    y = y - 18
  end

  -- the carriers
  for i, s in ipairs(self.slots) do
    s:SetShown(carriers)
    if carriers then
      s:ClearAllPoints()
      s:SetPoint("TOPLEFT", 0, y)
      s:SetPoint("TOPRIGHT", 0, y)
      y = y - 36
    end
  end
  if carriers then
    fillSlot(self.slots[1], "arena1", "flag at base")
    local our = findOurCarrier()
    fillSlot(self.slots[2], our, "flag at base")
    if our and our ~= self.ourUnit and not InCombatLockdown() then
      self.ourUnit = our
      self.secure[2]:SetAttribute("unit", our)
    end
  end
  self:SyncSecure(carriers and f:IsVisible())
end

-- the secure buttons can only be shown, hidden or changed outside combat
function B:SyncSecure(on)
  if InCombatLockdown() then self.pendingSecure = on return end
  self.pendingSecure = nil
  for _, b in ipairs(self.secure or {}) do b:SetShown(on and true or false) end
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
  if on then self:Draw() else self:SyncSecure(false) end
  self.on = on
end

function B:Init()
  ns:Listen("BGOBJ", function() B:Apply() end)
  ns:On("PLAYER_REGEN_ENABLED", function() if B.pendingSecure ~= nil then B:SyncSecure(B.pendingSecure) end end)
  -- countdowns and carrier health: once a second while it's showing
  C_Timer.NewTicker(1, function()
    if B.on and B.frame and B.frame:IsVisible() then
      if ns.BGObj.key and ns.BGObj.key ~= "WSG" then ns.BGObj:ScanNodes() end
      B:Draw()
    end
  end)
end
