-- Chillan? – /chill kit: every building block side by side, to check against the canvas "Kit" board
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

local K = {}
ns.Kit = K

function K:Build()
  local f = CreateFrame("Frame", "ChillanKitFrame", UIParent)
  f:SetSize(720, 420)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetFrameStrata("DIALOG")
  f.box = UI.Panel(f, C.window, C.border or C.line)
  f.box:SetAllPoints()
  f.box:SetFrameLevel(f:GetFrameLevel())
  f:EnableMouse(true) f:SetMovable(true) f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() UI.SnapFrame(self) end)
  local title = UI.Text(f, 16, "bold", C.text) title:SetPoint("TOPLEFT", 20, -16) title:SetText("Chillan? kit")
  local close = UI.Button(f, 70, 26, "Close", "ghost", function() f:Hide() end)
  close:SetPoint("TOPRIGHT", -16, -12)

  local function label(t, x, y) local l = UI.Text(f, 11, "semi", C.dim) l:SetPoint("TOPLEFT", x, y) l:SetText(t:upper()) end
  -- buttons
  label("Buttons", 20, -54)
  local x = 20
  for _, st in ipairs({ "primary", "secondary", "ghost", "danger" }) do
    local b = UI.Button(f, 110, 28, st:sub(1, 1):upper() .. st:sub(2), st)
    b:SetPoint("TOPLEFT", x, -72) x = x + 120
  end
  -- switches
  label("Switches", 520, -54)
  local s1 = UI.Switch(f) s1:SetPoint("TOPLEFT", 520, -77) s1:Set(true)
  local s2 = UI.Switch(f) s2:SetPoint("TOPLEFT", 566, -77) s2:Set(false)
  -- input + seg
  label("Input and choice bar", 20, -118)
  local e = UI.EditBox(f, 260, 28, "Search settings") e:SetPoint("TOPLEFT", 20, -136)
  local segV = "Normal"
  local seg = UI.Seg(f, { "Calm", "Normal", "All" }, function() return segV end, function(v) segV = v end)
  seg:SetPoint("TOPLEFT", 300, -136)
  -- section with switch rows
  label("Panel", 20, -182)
  local sec = UI.Section(f, "Popups")
  sec:SetPoint("TOPLEFT", 20, -200) sec:SetWidth(330)
  local on = { true, false }
  local r1 = UI.SwitchRow(sec.body, "Delay until combat ends", function() return on[1] end, function(v) on[1] = v end, "Explanation")
  r1:SetPoint("TOPLEFT") r1:SetPoint("TOPRIGHT")
  local r2 = UI.SwitchRow(sec.body, "Member logins", function() return on[2] end, function(v) on[2] = v end, "Explanation")
  r2:SetPoint("TOPLEFT", 0, -30) r2:SetPoint("TOPRIGHT", 0, -30)
  sec:FitBody(60)
  -- tiles
  label("Tiles", 370, -182)
  local tx = 370
  for i, d in ipairs({ { "31h", "played this week", C.accent }, { "+4", "levels", "6CA8F0" }, { "212g", "gold earned", "E8C060" } }) do
    local t = UI.Panel(f, C.panel or C.card, C.border or C.line)
    t:SetSize(104, 58) t:SetPoint("TOPLEFT", tx, -200) tx = tx + 112
    local top = UI.Track(t:CreateTexture(nil, "ARTWORK")) top:SetColorTexture(hex(d[3]))
    top:SetPoint("TOPLEFT", 4, 0) top:SetPoint("TOPRIGHT", -4, 0) top:SetHeight(2)
    local v = UI.Text(t, 18, "bold", C.text) v:SetPoint("TOPLEFT", 10, -12) v:SetText(d[1])
    local l = UI.Text(t, 11, nil, C.muted) l:SetPoint("TOPLEFT", 10, -36) l:SetText(d[2])
  end
  -- scale info
  f.info = UI.Text(f, 11, nil, C.dim) f.info:SetPoint("BOTTOMLEFT", 20, 14)
  f:SetScript("OnShow", function(self)
    local w, h = GetPhysicalScreenSize()
    self.info:SetText(string.format("scale %.3f · 1 px = %.3f units · screen %dx%d", self:GetEffectiveScale(), UI.Px(self), w, h))
  end)
  UI.SnapFrame(f)
  self.frame = f
end

function K:Toggle()
  if not self.frame then self:Build() self.frame:Show() self.frame:GetScript("OnShow")(self.frame) return end
  self.frame:SetShown(not self.frame:IsShown())
end
