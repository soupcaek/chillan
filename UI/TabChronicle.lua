-- Chillan? – fanen "Krønike": gjengens historie og dungeon-rekorder
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("chronicle", "Krønike", "Scroll", function(tab)
  local RIGHT_W = 250

  local h = UI.Text(tab, 15, "semi", C.text)
  h:SetPoint("TOPLEFT", 16, -16)
  h:SetText("Gjengens krønike")
  local hs = UI.Text(tab, 11, nil, C.dim)
  hs:SetPoint("LEFT", h, "RIGHT", 10, 0)
  hs:SetText("de store øyeblikkene – nyeste øverst")

  local function createRow(list)
    local row = CreateFrame("Button", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.date = UI.Text(row, 11, "semi", C.dim)
    row.date:SetPoint("LEFT", 12, 0)
    row.date:SetWidth(46)
    row.tile = UI.Panel(row, C.active, nil, false)
    row.tile:SetSize(28, 28)
    row.tile:SetPoint("LEFT", 60, 0)
    row.icon = UI.Icon(row.tile, "Star", 15, C.gold)
    row.icon:SetPoint("CENTER")
    row.text = UI.Text(row, 13, nil, C.text)
    row.text:SetPoint("LEFT", row.tile, "RIGHT", 12, 0)
    row.text:SetPoint("RIGHT", -12, 0)
    row:SetScript("OnEnter", function(self)
      self.panel:SetColors(C.cardHover, C.line)
      if self.item and self.item.pid then ns.Overlays:ShowProfile(self, self.item.pid) end
    end)
    row:SetScript("OnLeave", function(self) self.panel:SetColors(C.card, C.line) ns.Overlays:HideProfile() end)
    return row
  end
  local function updateRow(row, e)
    row.date:SetText(e.t and date("%d.%m", e.t) or "")
    row.icon:SetTexture(ns.TEX .. "Icon" .. (e.icon or "Star"))
    row.icon:SetVertexColor(hex(e.color or C.gold))
    local p = ns:GetPerson(e.pid) or {}
    row.text:SetText(ns:ShortWho(p, e.char) .. " " .. ns.Colorize(e.text, C.text2))
  end
  local list = UI.List(tab, 40, 6, createRow, updateRow)
  list:SetPoint("TOPLEFT", 12, -44)
  list:SetPoint("BOTTOMRIGHT", -RIGHT_W - 28, 14)
  list.emptyText = "Krøniken fylles av seg selv: første til level 10, første mount, første episke drop, første gjennom en dungeon og gull-achievements."

  -- Høyre: raskeste dungeon-runs
  local rh = UI.Text(tab, 15, "semi", C.text)
  rh:SetPoint("TOPLEFT", tab, "TOPRIGHT", -RIGHT_W - 16, -16)
  rh:SetText("Dungeon-rekorder")
  local function createRec(l)
    local row = CreateFrame("Button", nil, l)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.name = UI.Text(row, 12, "semi", C.text)
    row.name:SetPoint("TOPLEFT", 10, -7)
    row.name:SetPoint("RIGHT", -64, 0)
    row.time = UI.Text(row, 13, "bold", C.text)
    row.time:SetPoint("TOPRIGHT", -10, -7)
    row.time:SetJustifyH("RIGHT")
    row.who = UI.Text(row, 10, nil, C.muted)
    row.who:SetPoint("BOTTOMLEFT", 10, 7)
    row.who:SetPoint("RIGHT", -10, 0)
    return row
  end
  local function updateRec(row, r)
    row.name:SetText(r.name)
    row.time:SetText(ns.Duration(r.dur))
    local names = {}
    for _, p in ipairs(ns.Extras:RunMembers(r.item)) do names[#names + 1] = ns:ShortWho(p) end
    if #names == 0 then names[1] = ns:ShortWho(ns:GetPerson(r.item.pid) or {}, r.item.char) end
    row.who:SetText(table.concat(names, ns.Colorize(", ", C.dim)) .. ns.Colorize("  ·  " .. date("%d.%m", r.item.t), C.dim))
  end
  local recs = UI.List(tab, 44, 6, createRec, updateRec)
  recs:SetPoint("TOPLEFT", rh, "BOTTOMLEFT", -4, -12)
  recs:SetPoint("BOTTOMRIGHT", -12, 14)
  recs.emptyText = "Ingen fullførte dungeons ennå. Runs logges automatisk (tid, dødsfall og bosser)."
  recs.empty:SetWidth(RIGHT_W - 20)

  function tab:Refresh()
    list:SetData(ns.Extras:Chronicle())
    recs:SetData(ns.Extras:DungeonRecords())
  end
end)
