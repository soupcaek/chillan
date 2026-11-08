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
    if ns:IsOnline(p) then
      local st = ns.STATUS[L.status or "QUEST"]
      if st then GameTooltip:AddLine(st.label, hex(st.color)) end
    else
      GameTooltip:AddLine("Offline – last seen here " .. ns.Ago(p.lastSeen), 0.6, 0.63, 0.66)
    end
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
  if not ns.db.code then return end
  local mapID = map:GetMapID()
  if not mapID then return end
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  local scale = canvas:GetEffectiveScale()
  local inv = scale > 0 and (UIParent:GetEffectiveScale() / scale) or 1
  self:UpdateNotes(canvas, mapID, inv)
  if not ns.db.settings.mapPins then return end
  local n = 0
  for pid, p in pairs(ns.db.people) do
    local L = p.live
    local online = ns:IsOnline(p)
    -- offline friends: their last known spot, dimmed (if seen within a week)
    local showOff = not online and ns.db.settings.mapPinsOffline ~= false
      and (ns.Now() - (p.lastSeen or 0)) < 7 * 86400
    if pid ~= ns.pid and p.main and (online or showOff) and L and L.cont and L.wx and L.wy then
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
          pin:SetAlpha(online and 1 or 0.4)
          pin:SetScale(inv * (online and 1.15 or 0.95))
          pin:ClearAllPoints()
          pin:SetPoint("CENTER", canvas, "TOPLEFT", (x * w) / (inv * (online and 1.15 or 0.95)), (-y * h) / (inv * (online and 1.15 or 0.95)))
          pin:Show()
        end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Gjeng-notater (Alt + høyreklikk på kartet for å lage)
---------------------------------------------------------------------------
P.notePins = {}
local function createNotePin(canvas)
  local pin = CreateFrame("Button", nil, canvas)
  pin:SetSize(18, 18)
  pin:SetFrameStrata("HIGH")
  pin:RegisterForClicks("RightButtonUp")
  pin.bg = pin:CreateTexture(nil, "ARTWORK")
  pin.bg:SetTexture(ns.TEX .. "Circle")
  pin.bg:SetAllPoints()
  pin.bg:SetVertexColor(hex(C.window))
  pin.icon = pin:CreateTexture(nil, "OVERLAY")
  pin.icon:SetPoint("TOPLEFT", 3, -3)
  pin.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  pin:SetScript("OnEnter", function(self)
    local n = self.note
    if not n then return end
    local k = ns.Extras.noteKind[n.kind] or ns.Extras.noteKind.text
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(k.name, hex(k.color))
    if n.text and n.text ~= "" then GameTooltip:AddLine(n.text, 1, 1, 1, true) end
    local p = ns:GetPerson(n.pid) or {}
    GameTooltip:AddLine("by " .. (ns:PersonAlias(p) or ns.ShortName(n.char or "?")) .. " · expires in " .. ns.Duration((n.exp or 0) - ns.Now()), 0.6, 0.63, 0.66)
    if n.pid == ns.pid then GameTooltip:AddLine("Right-click: remove", 0.52, 0.55, 0.57) end
    GameTooltip:Show()
  end)
  pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
  pin:SetScript("OnClick", function(self)
    if self.note and self.note.pid == ns.pid then ns.Extras:RemoveNote(self.note.id) GameTooltip:Hide() end
  end)
  return pin
end

function P:UpdateNotes(canvas, mapID, inv)
  for _, pin in ipairs(self.notePins) do pin:Hide() end
  if ns.db.settings.mapNotes == false then return end
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  local n = 0
  for _, note in pairs(ns.db.notes or {}) do
    if note.mapID == mapID and (note.exp or 0) > ns.Now() then
      n = n + 1
      local pin = self.notePins[n]
      if not pin then pin = createNotePin(canvas) self.notePins[n] = pin end
      local k = ns.Extras.noteKind[note.kind] or ns.Extras.noteKind.text
      pin.note = note
      pin.icon:SetTexture(ns.TEX .. "Icon" .. k.icon)
      pin.icon:SetVertexColor(hex(k.color))
      pin:SetScale(inv * 1.1)
      pin:ClearAllPoints()
      pin:SetPoint("CENTER", canvas, "TOPLEFT", (note.x * w) / (inv * 1.1), (-note.y * h) / (inv * 1.1))
      pin:Show()
    end
  end
end

local function noteMenu(mapID, x, y)
  local items = {}
  for _, k in ipairs(ns.Extras.NOTE_KINDS) do
    items[#items + 1] = { text = k.name, color = k.color, func = function()
      UI.Prompt("Gang note: " .. k.name, {
        { label = "Text (optional)", placeholder = k.key == "gank" and "e.g. lvl 40 rogue camped here" or "" },
        { label = "How many days should it stay? (1, 3 or 7)", value = "3" },
      }, function(text, days) ns.Extras:AddNote(mapID, x, y, k.key, text, days) end)
    end }
  end
  -- usynlig anker ved musepekeren, så menyen dukker opp der du klikket
  P.cursorAnchor = P.cursorAnchor or CreateFrame("Frame", nil, UIParent)
  local a = P.cursorAnchor
  local cx, cy = GetCursorPosition()
  local sc = UIParent:GetEffectiveScale()
  a:SetSize(1, 1)
  a:ClearAllPoints()
  a:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / sc, cy / sc)
  UI.Menu(a, items, true)
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
  -- Alt + høyreklikk på kartet: lag gjengnotat der
  local sc = WorldMapFrame.ScrollContainer
  if sc then
    sc:HookScript("OnMouseUp", function(self, button)
      if button ~= "RightButton" or not IsAltKeyDown() or not ns.db.code then return end
      if ns.db.settings.mapNotes == false then return end
      local x, y = self:GetNormalizedCursorPosition()
      local mapID = WorldMapFrame:GetMapID()
      if mapID and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then noteMenu(mapID, x, y) end
    end)
  end
end
