-- Chillan? – vennene dine som nåler på verdenskartet
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex
local P = { pins = {} }
ns.MapPins = P

local function createPin(canvas)
  local pin = CreateFrame("Frame", nil, canvas)
  pin:SetSize(20, 20)
  pin:SetFrameStrata("HIGH")
  pin:EnableMouse(true)
  pin.ring = pin:CreateTexture(nil, "ARTWORK")
  pin.ring:SetTexture(ns.TEX .. "Circle")
  pin.ring:SetAllPoints()
  pin.inner = pin:CreateTexture(nil, "OVERLAY")
  pin.inner:SetTexture(ns.TEX .. "Circle")
  pin.inner:SetPoint("TOPLEFT", 3, -3)
  pin.inner:SetPoint("BOTTOMRIGHT", -3, 3)
  pin.inner:SetVertexColor(hex(C.window))
  pin.letter = pin:CreateFontString(nil, "OVERLAY")
  pin.letter:SetFont(ns.FONT_BOLD, 9, "")
  pin.letter:SetPoint("CENTER", 0, 0)
  pin:SetScript("OnEnter", function(self)
    local p = self.person
    if not p then return end
    local c = ns:PersonChar(p) or {}
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local r, g, b = ns.ClassColor(c.class)
    GameTooltip:AddLine((c.name or "?") .. "  (lvl " .. (c.level or "?") .. ")", r, g, b)
    local L = p.live or {}
    GameTooltip:AddLine((L.sub and L.sub ~= "" and (L.sub .. ", ") or "") .. (L.zone or ""), 0.8, 0.82, 0.85)
    local st = ns.STATUS[L.status or "QUEST"]
    if st then GameTooltip:AddLine(st.label, hex(st.color)) end
    GameTooltip:Show()
  end)
  pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return pin
end

function P:Update()
  local map = WorldMapFrame
  if not map or not map:IsShown() then return end
  local canvas = map.ScrollContainer and map.ScrollContainer.Child
  if not canvas then return end
  for _, pin in ipairs(self.pins) do pin:Hide() end
  if not ns.db.settings.mapPins or not ns.db.code then return end
  local mapID = map:GetMapID()
  if not mapID then return end
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  local scale = canvas:GetEffectiveScale()
  local inv = scale > 0 and (UIParent:GetEffectiveScale() / scale) or 1
  local n = 0
  for pid, p in pairs(ns.db.people) do
    local L = p.live
    if pid ~= ns.pid and p.main and ns:IsOnline(p) and L and L.cont and L.wx and L.wy then
      local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, L.cont, CreateVector2D(L.wx, L.wy), mapID)
      if ok and pos then
        local x, y = pos:GetXY()
        if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
          n = n + 1
          local pin = self.pins[n]
          if not pin then
            pin = createPin(canvas)
            self.pins[n] = pin
          end
          local c = ns:PersonChar(p) or {}
          pin.person = p
          pin.ring:SetVertexColor(ns.ClassColor(c.class))
          pin.letter:SetText((c.name or "?"):sub(1, 1):upper())
          pin.letter:SetTextColor(ns.ClassColor(c.class))
          pin:SetScale(inv * 1.15)
          pin:ClearAllPoints()
          pin:SetPoint("CENTER", canvas, "TOPLEFT", (x * w) / (inv * 1.15), (-y * h) / (inv * 1.15))
          pin:Show()
        end
      end
    end
  end
end

function P:Init()
  if not WorldMapFrame then return end
  local ticker
  WorldMapFrame:HookScript("OnShow", function()
    P:Update()
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(1, function() P:Update() end)
  end)
  WorldMapFrame:HookScript("OnHide", function()
    if ticker then ticker:Cancel() ticker = nil end
  end)
  if WorldMapFrame.OnMapChanged then
    hooksecurefunc(WorldMapFrame, "OnMapChanged", function() P:Update() end)
  end
  ns:Listen("MAP_PINS", function() P:Update() end)
end
