-- Chillan? – the "Died to" page (1.0.1): Alliance players who killed someone in the gang.
-- It fills itself. Nobody gets warned about these – put someone on the Cunt List for that.
local ADDON, ns = ...
local UI, C = ns.UI, ns.C

ns:RegisterTab("diedto", "Died to", "Skull", function(tab)
  local head = UI.Text(tab, 16, "semi", C.text)
  head:SetPoint("TOPLEFT", 16, -16)   -- (1.1.7) same margins as Friends
  head:SetText("Died to")
  local sub = UI.Text(tab, 11, nil, C.dim)
  sub:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -4)
  sub:SetPoint("RIGHT", tab, "RIGHT", -16, 0)
  sub:SetJustifyH("LEFT")
  sub:SetWordWrap(true)
  sub:SetText("Alliance players who killed someone in the gang, the last 60 days. It fills itself and warns nobody. Killing one of them within a week of their last kill counts as revenge.")

  local search = UI.EditBox(tab, 100, 30, "Search names and zones …", function(self) self:ClearFocus() end)
  search:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -10)
  search:SetPoint("RIGHT", tab, "RIGHT", -16, 0)
  search.edit:HookScript("OnTextChanged", function() tab:Refresh() end)

  local function createRow(list)
    local row = CreateFrame("Frame", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
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
    return row
  end
  local function updateRow(row, e)
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
  local list = UI.List(tab, 62, 6, createRow, updateRow)
  list:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -10)
  list:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -14, 14)
  list.emptyText = "Nobody yet. When an Alliance player kills one of the gang, they show up here."

  function tab:Refresh()
    local q = (search:GetText() or ""):lower()
    local out = {}
    for _, e in ipairs(ns.DiedTo:List()) do
      if q == "" or e.name:lower():find(q, 1, true) or (e.zone or ""):lower():find(q, 1, true) then
        out[#out + 1] = e
      end
    end
    list:SetData(out)
  end
  ns:Listen("CUNTS", function() if tab:IsVisible() then tab:Refresh() end end)
  ns:Listen("DATA", function() if tab:IsVisible() then tab:Refresh() end end)
end)
