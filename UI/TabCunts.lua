-- Chillan? – the Cunt List page: every entry, why, who added it, notes; search, note, remove
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("cunts", "Cunts", "Skull", function(tab)
  -- (1.4.68) the Kit layout: search and the add buttons on top, the list in a panel
  local add = UI.Button(tab, 150, 28, "Add your target", "secondary", function()
    local n = ns.S(UnitIsPlayer, "target") and ns.S(UnitName, "target")
    if type(n) ~= "string" or n == "" then ns.Print("Target a player first (or right-click their name in chat).") return end
    ns.Cunts:AskAdd(n)
  end)
  add:SetIcon("Plus", 13)
  add:SetPoint("TOPRIGHT", -12, -12)
  local byName = UI.Button(tab, 130, 28, "Add by name", "secondary", function() ns.Cunts:AskAddByName() end)
  byName:SetIcon("Plus", 13)
  byName:SetPoint("RIGHT", add, "LEFT", -8, 0)
  local search = UI.EditBox(tab, 100, 28, "Search names and reasons …", function(self) self:ClearFocus() end)
  search:SetPoint("TOPLEFT", 12, -12)
  search:SetPoint("RIGHT", byName, "LEFT", -8, 0)
  search.edit:HookScript("OnTextChanged", function() tab:Refresh() end)
  local lp = UI.Section(tab, "The Cunt List")
  lp:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -10)
  lp:SetPoint("BOTTOMRIGHT", -12, 12)
  lp.right:SetText("right-click a name to add")
  UI.InfoTip(lp, lp.title, "The Cunt List", "Ninja looters and general dicks. Right-click a player's name or portrait (or use the buttons) to add them – the whole gang gets warned when one is near.")

  local function createRow(list)
    local row = CreateFrame("Frame", nil, list)
    row.stripe = UI.Track(row:CreateTexture(nil, "BACKGROUND"))
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(hex(C.rowAlt or C.window))
    row:EnableMouse(true)
    row.name = UI.Text(row, 13, "semi", C.red)
    row.name:SetPoint("TOPLEFT", 12, -8)
    row.name:SetPoint("RIGHT", -120, 0)
    row.reason = UI.Text(row, 12, nil, C.text)
    row.reason:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.reason:SetPoint("RIGHT", -120, 0)
    row.meta = UI.Text(row, 10, nil, C.dim)
    row.meta:SetPoint("BOTTOMLEFT", 12, 7)
    row.meta:SetPoint("RIGHT", -120, 0)
    row.note = UI.Button(row, 70, 24, "Note", "ghost")
    row.note:SetPoint("RIGHT", -40, 0)
    row.del = UI.IconButton(row, 24, "Close", "Take off the list (only the one who added them)")
    row.del:SetPoint("RIGHT", -8, 0)
    row:SetScript("OnEnter", function(self)
      local e = self.entry
      if not e or not e.notes or #e.notes == 0 then return end
      GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
      GameTooltip:AddLine(e.name, 0.95, 0.47, 0.48)
      for _, n in ipairs(e.notes) do
        local p = n.pid and ns:GetPerson(n.pid)
        GameTooltip:AddLine(((p and ns:PersonFirst(p)) or ns.ShortName(n.char or "?")) .. ", " .. ns.Ago(n.t) .. ": " .. n.text, 0.85, 0.85, 0.85, true)
      end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
  end
  local function updateRow(row, e, idx)
    row.stripe:SetShown((idx or 1) % 2 == 0)
    row.entry = e
    row.name:SetText(e.name)
    row.reason:SetText(e.reason)
    local nn = #(e.notes or {})
    row.meta:SetText("added by " .. ns.Cunts:WhoAdded(e) .. " · " .. ns.Ago(e.t)
      .. (nn > 0 and ("  ·  " .. ns.Colorize("+" .. nn .. (nn == 1 and " note" or " notes") .. " (hover)", C.amber)) or ""))
    row.note:SetScript("OnClick", function() ns.Cunts:AskAdd(e.name) end)
    if ns.Cunts:CanRemove(e) then row.del:Show() else row.del:Hide() end
    row.del:SetScript("OnClick", function() ns.Cunts:Remove(e.key) end)
  end
  local list = UI.List(lp.body, 62, 0, createRow, updateRow)
  list:SetPoint("TOPLEFT", 0, 0)
  list:SetPoint("BOTTOMRIGHT", lp.body, "BOTTOMRIGHT", 6, 0)
  list.emptyText = "Nobody yet. Right-click a player's name or portrait → «Add to the Cunt List»."

  function tab:Refresh()
    local q = (search:GetText() or ""):lower()
    local out = {}
    for _, e in ipairs(ns.Cunts:List()) do
      if q == "" or e.name:lower():find(q, 1, true) or (e.reason or ""):lower():find(q, 1, true) then
        out[#out + 1] = e
      end
    end
    list:SetData(out)
  end
  ns:Listen("CUNTS", function() if tab:IsVisible() then tab:Refresh() end end)
end)
