-- Chillan? – the "Died to" page (1.0.1): Alliance players who killed someone in the gang.
-- It fills itself. Nobody gets warned about these – put someone on the Cunt List for that.
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("diedto", "Died to", "Skull", function(tab)
  -- (1.4.68) the Kit layout: search and sort on top, the list in a panel
  local sortBy = ns.db.settings.diedToSort or 1
  local sortSeg = UI.Seg(tab, { "Latest", "Most kills" }, function() return sortBy end, function(i)
    sortBy = i ns.db.settings.diedToSort = i tab:Refresh()
  end)
  sortSeg:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -12, -12)
  local search = UI.EditBox(tab, 100, 28, "Search names and zones …", function(self) self:ClearFocus() end)
  search:SetPoint("TOPLEFT", 12, -12)
  search:SetPoint("RIGHT", sortSeg, "LEFT", -8, 0)
  search.edit:HookScript("OnTextChanged", function() tab:Refresh() end)
  local lp = UI.Section(tab, "Enemies who killed one of us")
  lp:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -10)
  lp:SetPoint("BOTTOMRIGHT", -12, 12)
  UI.InfoTip(lp, lp.title, "Died to", "Enemy players who killed a gang member in the last 60 days. The list updates by itself. Killing one within a week of their last kill counts as revenge.")

  local function createRow(list)
    local row = CreateFrame("Frame", nil, list)
    row.stripe = UI.Track(row:CreateTexture(nil, "BACKGROUND"))
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(hex(C.rowAlt or C.window))
    row.name = UI.Text(row, 13, "semi", C.text)
    row.name:SetPoint("TOPLEFT", 12, -8)
    row.name:SetPoint("RIGHT", -170, 0)
    row.name:SetJustifyH("LEFT")
    row.who = UI.Text(row, 12, nil, C.text2)
    row.who:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.who:SetPoint("RIGHT", -170, 0)
    row.who:SetJustifyH("LEFT")
    row.who:SetWordWrap(false)
    row.meta = UI.Text(row, 10, nil, C.dim)
    row.meta:SetPoint("BOTTOMLEFT", 12, 7)
    row.meta:SetPoint("RIGHT", -170, 0)
    row.meta:SetJustifyH("LEFT")
    row.count = UI.Text(row, 18, "bold", C.red)
    row.count:SetPoint("RIGHT", -132, 0)
    row.add = UI.Button(row, 110, 24, "Cunt List …", "ghost")
    row.add:SetPoint("RIGHT", -10, 0)
    row.add.tooltip = "Put them on the Cunt List (you write why) – then the whole gang gets warned"
    -- (1.4.68) the button only on the row under the mouse (a column of buttons was loud)
    row:EnableMouse(true)
    row.add:SetAlpha(0)
    row:SetScript("OnEnter", function(self) self.add:SetAlpha(1) end)
    row:SetScript("OnLeave", function(self) if not self.add:IsMouseOver() then self.add:SetAlpha(0) end end)
    row.add:HookScript("OnLeave", function() if not row:IsMouseOver() then row.add:SetAlpha(0) end end)
    return row
  end
  local function updateRow(row, e, idx)
    row.stripe:SetShown((idx or 1) % 2 == 0)
    local onList = ns.Cunts and ns.Cunts:Get(e.name)
    row.name:SetText(e.name .. (e.extra and e.extra ~= "" and ns.Colorize("  " .. e.extra, C.muted) or "")
      .. (onList and ns.Colorize("  · on the Cunt List", C.red) or ""))
    row.who:SetText("Killed " .. ns.DiedTo:Victims(e, 4))
    local week = ns.DiedTo:Since(e, ns.Now() - 7 * 86400)
    row.meta:SetText("last " .. ns.Ago(e.last) .. (e.zone and e.zone ~= "" and (" in " .. e.zone) or "")
      .. (week > 0 and ("  ·  " .. week .. " this week") or "")
      .. ((e.revenge or 0) > 0 and ns.Colorize("  ·  revenge taken " .. e.revenge .. "×", C.green) or ""))
    row.count:SetText((e.n or 0) .. "×")
    row.add:SetShown(not onList)
    row.add:SetScript("OnClick", function() ns.Cunts:AskAdd(e.name) end)
  end
  local list = UI.List(lp.body, 62, 0, createRow, updateRow)
  list:SetPoint("TOPLEFT", 0, 0)
  list:SetPoint("BOTTOMRIGHT", lp.body, "BOTTOMRIGHT", 6, 0)
  list.emptyText = "Nobody yet. When an Alliance player kills one of the gang, they show up here."

  function tab:Refresh()
    local q = (search:GetText() or ""):lower()
    local out = {}
    for _, e in ipairs(ns.DiedTo:List()) do
      if q == "" or e.name:lower():find(q, 1, true) or (e.zone or ""):lower():find(q, 1, true) then
        out[#out + 1] = e
      end
    end
    if sortBy == 2 then
      table.sort(out, function(a, b)
        if (a.n or 0) ~= (b.n or 0) then return (a.n or 0) > (b.n or 0) end
        return (a.last or 0) > (b.last or 0)
      end)
    end
    sortSeg:Refresh()
    list:SetData(out)
  end
  ns:Listen("CUNTS", function() if tab:IsVisible() then tab:Refresh() end end)
  ns:Listen("DATA", function() if tab:IsVisible() then tab:Refresh() end end)
end)
