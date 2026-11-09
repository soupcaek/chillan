-- Chillan? – the "Since you last played" card
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

local card
local function create()
  local f = CreateFrame("Button", "ChillanBriefing", UIParent)
  f:SetSize(360, 100)
  f:SetFrameStrata("DIALOG")
  UI.Movable(f, "briefing", function(fr) fr:SetPoint("TOP", UIParent, "TOP", 0, -120) end)
  f.panel = UI.OverlayPanel(f, C.window, C.activeLine, false)
  f.panel:SetAllPoints()
  f.panel:SetFrameLevel(f:GetFrameLevel())
  f.kicker = UI.Text(f, 10, "semi", C.accent)
  f.kicker:SetPoint("TOPLEFT", 16, -14)
  f.title = UI.Text(f, 15, "semi", C.text)
  f.title:SetPoint("TOPLEFT", f.kicker, "BOTTOMLEFT", 0, -4)
  f.close = UI.IconButton(f, 24, "Close", nil, function() f:Hide() end)
  f.close:SetPoint("TOPRIGHT", -8, -8)
  f.close.panel:SetColors(nil, nil)
  f.close.icon:SetVertexColor(hex(C.dim))
  f.body = UI.Text(f, 12, nil, C.text2)
  f.body:SetPoint("TOPLEFT", 16, -56)
  f.body:SetPoint("RIGHT", -16, 0)
  f.body:SetWordWrap(true)
  f.body:SetJustifyV("TOP")
  f.body:SetSpacing(5)
  f.foot = UI.Text(f, 11, nil, C.green)
  f.foot:SetPoint("BOTTOMLEFT", 16, 14)
  f.foot:SetPoint("RIGHT", -16, 0)
  f:SetScript("OnClick", function(self) self:Hide() end)
  f:SetScript("OnEnter", function(self) self.hover = true end)
  f:SetScript("OnLeave", function(self) self.hover = false end)
  f:SetScript("OnUpdate", function(self, dt)
    if self.hover then return end
    self.life = (self.life or 0) - dt
    if self.life < 1 then self:SetAlpha(math.max(0, self.life)) end
    if self.life <= 0 then self:Hide() end
  end)
  f:Hide()
  return f
end

ns:Listen("BRIEFING", function(info)
  card = card or create()
  local ago = ns.Now() - (info.since or ns.Now())
  card.kicker:SetText("SINCE YOU LAST PLAYED")
  card.title:SetText(ago >= 86400 and (math.floor(ago / 86400) .. (ago >= 2 * 86400 and " days" or " day") .. " ago")
    or (ns.Duration(ago) .. " ago"))
  local lines = {}
  for i, l in ipairs(info.lines or {}) do
    if i > 7 then break end
    lines[#lines + 1] = ns.Colorize("•", C.accent) .. "  " .. l
  end
  if #lines == 0 then lines[1] = ns.Colorize("Quiet while you were away.", C.dim) end
  card.body:SetText(table.concat(lines, "\n"))
  card.foot:SetText(info.now or "")
  card.foot:SetShown(info.now ~= nil)
  local h = 56 + (card.body:GetStringHeight() or 60) + (info.now and 36 or 18)
  card:SetHeight(math.max(100, h))
  card.life = 30
  card:SetAlpha(1)
  card:Show()
end)
