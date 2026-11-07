-- Chillan? – fanen "Map": hvor er alle?
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

function ns.SetWaypoint(mapID, x, y)
  if not (mapID and x and y) then return false end
  local ok = pcall(function()
    local point = UiMapPoint.CreateFromCoordinates(mapID, x, y)
    C_Map.SetUserWaypoint(point)
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
      C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
  end)
  return ok
end

function ns.OpenMapAt(mapID)
  pcall(function()
    if not WorldMapFrame:IsShown() then ToggleWorldMap() end
    if mapID then WorldMapFrame:SetMapID(mapID) end
  end)
end

ns:RegisterTab("map", "Map", "Map", function(tab)
  local h = UI.Text(tab, 15, "semi", C.text)
  h:SetPoint("TOPLEFT", 16, -16)
  h:SetText("Where's the gang?")

  local openMap = UI.Button(tab, 150, 28, "Open the world map", "secondary", function()
    ns.OpenMapAt(nil)
  end)
  openMap:SetIcon("Map", 14)
  openMap:SetPoint("TOPRIGHT", -16, -12)

  local pins = UI.Check(tab, "Show friends on the map",
    function() return ns.db.settings.mapPins end,
    function(v) ns.db.settings.mapPins = v ns:Fire("MAP_PINS") end)
  pins:SetWidth(180)
  pins:SetPoint("RIGHT", openMap, "LEFT", -14, 0)

  local function createRow(list)
    local row = CreateFrame("Button", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.avatar = UI.Avatar(row, 30)
    row.avatar:SetPoint("LEFT", 10, 0)
    row.name = UI.Text(row, 13, "semi", C.text)
    row.name:SetPoint("LEFT", row.avatar, "RIGHT", 12, 0)
    row.name:SetWidth(150)
    row.zone = UI.Text(row, 13, nil, C.text2)
    row.zone:SetPoint("LEFT", row.avatar, "RIGHT", 170, 0)
    row.zone:SetWidth(240)
    row.coords = UI.Text(row, 12, nil, C.dim)
    row.coords:SetPoint("RIGHT", -110, 0)
    row.wp = UI.Button(row, 90, 28, "Waypoint", "secondary")
    row.wp:SetPoint("RIGHT", -10, 0)
    row:SetScript("OnEnter", function(self)
      self.panel:SetColors(C.cardHover, C.line)
      if self.item then ns.Overlays:ShowProfile(self, self.item.pid) end
    end)
    row:SetScript("OnLeave", function(self) self.panel:SetColors(C.card, C.line) ns.Overlays:HideProfile() end)
    return row
  end

  local function updateRow(row, p)
    local c = ns:PersonChar(p) or {}
    local L = p.live or {}
    row.avatar:Set(c.name, c.class, C.green)
    row.name:SetText(ns.Colorize(c.name or "?", ns.ClassHex(c.class)))
    local z = L.zone or "?"
    if L.sub and L.sub ~= "" and L.sub ~= z then z = z .. ", " .. L.sub end
    if L.inInst then z = z .. ns.Colorize("  (instans)", C.dim) end
    row.zone:SetText(z)
    if L.x and L.y then
      row.coords:SetText(string.format("%.0f, %.0f", L.x * 100, L.y * 100))
      row.wp:Enable()
      row.wp:SetAlpha(1)
      row.wp:SetScript("OnClick", function()
        if ns.SetWaypoint(L.mapID, L.x, L.y) then
          ns.Print("Waypoint set to " .. (c.name or "?") .. ".")
          ns.OpenMapAt(L.mapID)
        end
      end)
    else
      row.coords:SetText("")
      row.wp:Disable()
      row.wp:SetAlpha(0.4)
    end
  end

  local list = UI.List(tab, 48, 6, createRow, updateRow)
  list:SetPoint("TOPLEFT", 12, -50)
  list:SetPoint("BOTTOMRIGHT", -12, 12)
  list.emptyText = "No friends online right now."

  function tab:Refresh()
    local people = ns:SortedPeople(function(p, pid) return pid ~= ns.pid and ns:IsOnline(p) end)
    table.sort(people, function(a, b)
      local za, zb = (a.live and a.live.zone) or "", (b.live and b.live.zone) or ""
      if za ~= zb then return za < zb end
      return ns:PersonFirst(a) < ns:PersonFirst(b)
    end)
    list:SetData(people)
    pins:Refresh()
  end
end)
