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

-- (the Map tab is merged into Friends: waypoint button per friend, map button in the header)
