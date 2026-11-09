-- Chillan? Dungeon Journal – draws the game's own dungeon map (its map art tiles) with boss pins
local ADDON, ns = ...
local C, hex = ns.C, ns.hex

local M = {}
ns.Map = M

function M:MapID(d)
  return ns.FindMap(d.map.names, d.map.hint)
end

-- pin position: your own fix (Edit pins) > the game's journal pin > our first guess
function M:PinPos(d, mapID, b)
  local own = ns.db and ns.db.pins and ns.db.pins[d.key .. ":" .. b.name]
  if own then return own[1], own[2], "you" end
  if mapID and EJ_GetMapEncounter then
    for i = 1, 30 do
      local ok, x, y, _, name = pcall(EJ_GetMapEncounter, mapID, i, true)
      if not ok or not x then break end
      if name == b.name then return x, y, "game" end
    end
  end
  if b.pin then return b.pin[1], b.pin[2], "guess" end
end

function M:PrintPins()
  local d = ns.DUNGEONS[1]
  local id = self:MapID(d)
  ns.Print("Pins for " .. d.name .. " (map " .. tostring(id) .. "):")
  local all = {}
  for _, b in ipairs(d.bosses) do all[#all + 1] = b end
  for _, b in ipairs(d.others or {}) do all[#all + 1] = b end
  for _, b in ipairs(all) do
    local x, y, src = self:PinPos(d, id, b)
    print(string.format("  %s = { %.3f, %.3f }  (%s)", b.name, x or -1, y or -1, src or "none"))
  end
end

-- Builds a map view inside parent. Returns the view; call view:Show(d) to draw.
function M:Create(parent, opts)
  opts = opts or {}
  local v = CreateFrame("Frame", nil, parent)
  v.bg = v:CreateTexture(nil, "BACKGROUND")
  v.bg:SetAllPoints()
  v.bg:SetColorTexture(hex("1A1C20"))
  v.canvas = CreateFrame("Frame", nil, v)
  v.canvas:EnableMouse(true)
  v.tiles, v.pins = {}, {}
  v.msg = v:CreateFontString(nil, "OVERLAY")
  v.msg:SetFont(ns.FONT, 13, "")
  v.msg:SetTextColor(hex(C.text2))
  v.msg:SetPoint("CENTER", 0, 10)
  v.msg:SetWidth(360)
  v.msg:SetJustifyH("CENTER")
  v.small = opts.small

  local function pin(i)
    local p = v.pins[i]
    if p then return p end
    p = CreateFrame("Button", nil, v.canvas)
    p:SetSize(v.small and 18 or 24, v.small and 18 or 24)
    p:SetFrameLevel(v.canvas:GetFrameLevel() + 5)
    p.ring = p:CreateTexture(nil, "ARTWORK")
    p.ring:SetTexture(ns.TEX .. "Circle")
    p.ring:SetAllPoints()
    p.inner = p:CreateTexture(nil, "OVERLAY")
    p.inner:SetTexture(ns.TEX .. "Circle")
    p.inner:SetPoint("TOPLEFT", 2, -2)
    p.inner:SetPoint("BOTTOMRIGHT", -2, 2)
    p.label = p:CreateFontString(nil, "OVERLAY")
    p.label:SetFont(ns.FONT_BOLD, v.small and 9 or 11, "")
    p.label:SetPoint("CENTER", 0, 0)
    p.check = p:CreateTexture(nil, "OVERLAY", nil, 2)
    p.check:SetTexture(ns.TEX .. "IconCheck")
    p.check:SetSize(12, 12)
    p.check:SetPoint("BOTTOMRIGHT", 5, -4)
    p.check:SetVertexColor(hex(C.green))
    p:SetScript("OnEnter", function(self)
      local b = self.boss
      if not b then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(b.name, hex(b.rare and C.purple or (b.final and C.red or C.accent)))
      if b.where then GameTooltip:AddLine(b.where, 0.8, 0.82, 0.85, true) end
      if b.quest then GameTooltip:AddLine("Quest item: " .. b.quest, hex(C.amber)) end
      if ns.killed[b.name] then GameTooltip:AddLine("Killed this run", hex(C.green)) end
      if v.editing then GameTooltip:AddLine("Edit: click this pin, then click where it should be", 0.6, 0.63, 0.66, true) end
      GameTooltip:Show()
    end)
    p:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p:SetScript("OnClick", function(self)
      if not v.editing then return end
      v.selected = self
      for _, o in ipairs(v.pins) do o:SetAlpha(o == self and 1 or 0.5) end
    end)
    v.pins[i] = p
    return p
  end

  -- edit mode: move the selected pin to where you click
  v.canvas:SetScript("OnMouseUp", function(self, btn)
    if not v.editing or not v.selected or btn ~= "LeftButton" then return end
    local s = self:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local x = (cx / s - self:GetLeft()) / self:GetWidth()
    local y = (self:GetTop() - cy / s) / self:GetHeight()
    if x < 0 or x > 1 or y < 0 or y > 1 then return end
    local b = v.selected.boss
    ns.db.pins[v.dungeon.key .. ":" .. b.name] = { math.floor(x * 1000) / 1000, math.floor(y * 1000) / 1000 }
    v:Show2(v.dungeon)
  end)

  function v:SetEditing(on)
    self.editing = on
    self.selected = nil
    for _, o in ipairs(self.pins) do o:SetAlpha(1) end
  end

  -- draws the map art and the pins for dungeon d
  function v:Show2(d)
    self.dungeon = d
    for _, t in ipairs(self.tiles) do t:Hide() end
    for _, p in ipairs(self.pins) do p:Hide() end
    local mapID = M:MapID(d)
    local layers = mapID and C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
    local L = layers and layers[1]
    local textures = L and C_Map.GetMapArtLayerTextures and C_Map.GetMapArtLayerTextures(mapID, 1)
    if not (L and textures and #textures > 0) then
      self.canvas:Hide()
      self.msg:SetText("The game didn't give us the " .. d.name .. " map here.\nUse \"Open on the world map\" – and tell Claude what /cdj debug says.")
      self.msg:Show()
      return false
    end
    self.msg:Hide()
    local fw, fh = self:GetWidth(), self:GetHeight()
    if not fw or fw < 10 then return end
    local scale = math.min(fw / L.layerWidth, fh / L.layerHeight)
    local cw, ch = L.layerWidth * scale, L.layerHeight * scale
    self.canvas:ClearAllPoints()
    self.canvas:SetSize(cw, ch)
    self.canvas:SetPoint("CENTER")
    self.canvas:Show()
    local cols = math.ceil(L.layerWidth / L.tileWidth)
    local rows = math.ceil(L.layerHeight / L.tileHeight)
    local tw, th = L.tileWidth * scale, L.tileHeight * scale
    local i = 0
    for r = 0, rows - 1 do
      for c = 0, cols - 1 do
        i = i + 1
        local t = self.tiles[i]
        if not t then t = self.canvas:CreateTexture(nil, "ARTWORK") self.tiles[i] = t end
        t:SetTexture(textures[i])
        t:SetSize(tw, th)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", c * tw, -r * th)
        t:Show()
      end
    end
    -- pins
    local all = {}
    for _, b in ipairs(d.bosses) do all[#all + 1] = b end
    for _, b in ipairs(d.others or {}) do all[#all + 1] = b end
    for n, b in ipairs(all) do
      local x, y = M:PinPos(d, mapID, b)
      if x and y then
        local p = pin(n)
        p.boss = b
        local col = b.rare and C.line2 or (b.final and C.red or (b.n and C.accent or C.amber))
        p.ring:SetVertexColor(hex(b.rare and C.purple or "16171B"))
        p.inner:SetVertexColor(hex(col))
        p.label:SetText(b.n and tostring(b.n) or "Q")
        p.label:SetTextColor(hex(b.rare and C.text or "16171B"))
        p.check:SetShown(ns.killed[b.name] and true or false)
        p:ClearAllPoints()
        p:SetPoint("CENTER", self.canvas, "TOPLEFT", x * cw, -y * ch)
        p:SetAlpha(1)
        p:Show()
      end
    end
    return true
  end

  v:SetScript("OnSizeChanged", function(self) if self.dungeon and self:IsVisible() then self:Show2(self.dungeon) end end)
  return v
end
