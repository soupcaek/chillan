-- Chillan? – one-time card: "run the companion once" (shown after the gang's relay link arrives)
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

local PATH = "World of Warcraft\\_forever_\\Interface\\AddOns\\Chillan\\Companion\\ChillanCompanion.exe"
local card, shownThisSession, pending

local function inCombat()
  if InCombatLockdown and InCombatLockdown() then return true end
  return ns.S(UnitAffectingCombat, "player") and true or false
end

local function create()
  local f = CreateFrame("Frame", "ChillanCompanionCard", UIParent)
  f:SetSize(520, 244)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  UI.Movable(f, "companioncard", function(fr) fr:SetPoint("CENTER", UIParent, "CENTER", 0, 140) end)
  f.panel = UI.OverlayPanel(f, C.window, C.activeLine, false)
  f.panel:SetAllPoints()
  f.panel:SetFrameLevel(f:GetFrameLevel())
  f.kicker = UI.Text(f, 11, "semi", C.accent)
  f.kicker:SetPoint("TOPLEFT", 22, -20)
  f.kicker:SetText("DISCORD FEED")
  f.title = UI.Text(f, 18, "bold", C.text)
  f.title:SetPoint("TOPLEFT", f.kicker, "BOTTOMLEFT", 0, -5)
  f.title:SetText("Help the gang post to Discord")
  f.text = UI.Text(f, 12, nil, C.text2)
  f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -8)
  f.text:SetPoint("RIGHT", -22, 0)
  f.text:SetText("Double-click ChillanCompanion.exe once. It's in your WoW folder (click the box and press Ctrl+C to copy the path):")
  f.box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  f.box:SetPoint("TOPLEFT", f.text, "BOTTOMLEFT", 6, -10)
  f.box:SetPoint("RIGHT", -24, 0)
  f.box:SetHeight(26)
  f.box:SetAutoFocus(false)
  f.box:SetFontObject(ChatFontNormal)
  f.box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  f.box:SetScript("OnTextChanged", function(self, user) if user then self:SetText(PATH) self:HighlightText() end end)
  f.box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  f.note = UI.Text(f, 11, nil, C.dim)
  f.note:SetPoint("TOPLEFT", f.box, "BOTTOMLEFT", -6, -10)
  f.note:SetPoint("RIGHT", -22, 0)
  f.note:SetText("It installs itself, starts with Windows and updates itself. It only reads Chillan's saved data, never your screen. If WoW is installed somewhere else, the path starts in that folder instead.")
  f.done = UI.Button(f, 230, 36, "Done, it's running", "primary", function()
    ns.db.discord.companionDone = true
    f:Hide()
  end)
  f.done:SetPoint("BOTTOMLEFT", 22, 20)
  f.later = UI.Button(f, 170, 36, "Remind me later", "ghost", function() f:Hide() end)
  f.later:SetPoint("BOTTOMRIGHT", -22, 20)
  return f
end

local function show()
  local d = ns.db.discord
  if not d or not d.link or d.companionDone or d.on or shownThisSession then return end
  if ns.db.settings.combatQueue ~= false and inCombat() then pending = true return end
  shownThisSession = true
  card = card or create()
  card.box:SetText(PATH)
  card:Show()
end

-- after login, and right after the link first arrives
ns:On("PLAYER_LOGIN", function() C_Timer.After(20, show) end)
ns:Listen("DISCORD_LINK", function() C_Timer.After(3, show) end)
ns:On("PLAYER_REGEN_ENABLED", function()
  if pending then pending = nil C_Timer.After(2, show) end
end)
