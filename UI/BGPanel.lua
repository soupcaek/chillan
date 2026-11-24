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
  local carriers = key == "WSG" or key == "DI"

  -- bases and towers
  if key ~= "WSG" then
    local list = O:Chips()
    if #list == 0 then
      self.empty:ClearAllPoints()
      self.empty:SetPoint("TOPLEFT", 0, y)
      self.empty:SetText(key == "AV" and "No towers or graveyards under attack" or "Waiting for the bases …")
      y = y - 18
    else
      local n = math.min(#list, MAX_CHIPS)
      local perRow = key == "AV" and 2 or n
      local cw = math.floor((w - (perRow - 1) * 4) / perRow)
      for i = 1, n do
        local node, c = list[i], self.chips[i]
        local col = (i - 1) % perRow
        local row = math.floor((i - 1) / perRow)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", col * (cw + 4), y - row * 26)
        c:SetWidth(cw)
        local label = key == "AV" and (node.name:gsub(" Graveyard$", " GY")) or ns.BGObj.Short(node.name)
        if node.atk then
          local left = O:Left(node)
          c:SetColors("3A3220", AMBER)
          c.text:SetText(label .. " " .. ns.Colorize(left and mmss(left) or "…", sideColor(node.atk)))
        else
          local s = node.side
          c:SetColors(s == "h" and "3A1F22" or s == "a" and "1C2A3D" or C.active)
          c.text:SetText(ns.Colorize(label, s and s ~= "n" and sideColor(s) or C.muted))
        end
        c:Show()
      end
      y = y - (math.floor((n - 1) / perRow) + 1) * 26 - 2
    end
  end

  -- the line under the chips
  local left, right = "", ""
  if key == "AV" then
    local h, a = O:TowersStanding()
    if h then left = dim("Towers standing ") .. ns.Colorize(h, HORDE) .. dim(" vs ") .. ns.Colorize(a, ALLI) end
  elseif key == "AB" or key == "DI" then
    local sc = O:Score()
    if sc and sc.h.bases and sc.a.bases then left = dim("Bases ") .. ns.Colorize(sc.h.bases, HORDE) .. dim(" vs ") .. ns.Colorize(sc.a.bases, ALLI) end
    local side, secs = O:Estimate(sc)
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
