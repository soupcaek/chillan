-- Chillan? – "Ideas" tab: the gang's idea box with votes and status
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("ideas", "Ideas", "Star", function(tab)
  -------------------------------------------------------------------------
  -- Idea box
  -------------------------------------------------------------------------
  local I = ns.Ideas
  local ideaFilter = "open"
  local titleBox = UI.EditBox(tab, 260, 32, "Your idea, e.g. Show durability on the minibar")
  titleBox:SetPoint("TOPLEFT", 16, -16)
  titleBox.edit:SetMaxLetters(60)
  local descBox = UI.EditBox(tab, 250, 32, "Details (optional)")
  descBox:SetPoint("LEFT", titleBox, "RIGHT", 8, 0)
  descBox.edit:SetMaxLetters(200)
  local addIdea = UI.Button(tab, 90, 32, "Suggest", "primary", function()
    I:Add(titleBox:GetText(), descBox:GetText())
    titleBox:SetText("") descBox:SetText("")
    titleBox.edit:ClearFocus() descBox.edit:ClearFocus()
  end)
  addIdea:SetPoint("LEFT", descBox, "RIGHT", 8, 0)
  addIdea:SetPoint("RIGHT", -16, 0)
  titleBox.edit:SetScript("OnEnterPressed", function() descBox.edit:SetFocus() end)
  descBox.edit:SetScript("OnEnterPressed", function() addIdea:Click() end)

  local fseg, fbtns = nil, {}
  local function paintFilter()
    for k, b in pairs(fbtns) do
      local on = k == ideaFilter
      b.label:SetTextColor(hex(on and C.text or C.dim))
      b.line:SetShown(on)
    end
  end
  local prevF
  for _, def in ipairs({ { "open", "Open" }, { "done", "Done" }, { "rejected", "Rejected" }, { "all", "All" } }) do
    local b = CreateFrame("Button", nil, tab)
    b.label = UI.Text(b, 12, "semi", C.dim)
    b.label:SetPoint("CENTER")
    b.label:SetText(def[2])
    b:SetSize(b.label:GetStringWidth() + 16, 24)
    b.line = b:CreateTexture(nil, "ARTWORK")
    b.line:SetColorTexture(hex(C.accent))
    b.line:SetHeight(1)
    b.line:SetPoint("BOTTOMLEFT", 8, 1)
    b.line:SetPoint("BOTTOMRIGHT", -8, 1)
    if prevF then b:SetPoint("LEFT", prevF, "RIGHT", 2, 0) else b:SetPoint("TOPLEFT", titleBox, "BOTTOMLEFT", -6, -10) end
    b:SetScript("OnClick", function() ideaFilter = def[1] paintFilter() tab:Refresh() end)
    fbtns[def[1]] = b
    prevF = b
  end
  local adminInfo = UI.Text(tab, 11, nil, C.dim)
  adminInfo:SetPoint("LEFT", prevF, "RIGHT", 14, 0)

  -- copy box (top ideas as text to paste on)
  local copyFrame = UI.Panel(tab, C.window, C.activeLine, false)
  copyFrame:SetFrameStrata("DIALOG")
  copyFrame:SetSize(560, 260)
  copyFrame:SetPoint("CENTER", tab, "CENTER", 0, 0)
  copyFrame:EnableMouse(true)
  copyFrame:Hide()
  local ct = UI.Text(copyFrame, 13, "semi", C.text)
  ct:SetPoint("TOPLEFT", 14, -12)
  ct:SetText("Copy with Ctrl+C")
  local cclose = UI.IconButton(copyFrame, 22, "Close", nil, function() copyFrame:Hide() end)
  cclose:SetPoint("TOPRIGHT", -8, -8)
  local cs = CreateFrame("ScrollFrame", nil, copyFrame)
  cs:SetPoint("TOPLEFT", 14, -38)
  cs:SetPoint("BOTTOMRIGHT", -14, 12)
  local ce = CreateFrame("EditBox", nil, cs)
  ce:SetMultiLine(true)
  ce:SetAutoFocus(false)
  ce:SetFont(ns.FONT, 12, "")
  ce:SetTextColor(hex(C.text2))
  ce:SetWidth(530)
  ce:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
  cs:SetScrollChild(ce)
  local copyBtn = UI.Button(tab, 100, 24, "Copy list", "ghost", function()
    ce:SetText(I:ExportText())
    copyFrame:Show()
    ce:SetFocus()
    ce:HighlightText()
  end)
  copyBtn:SetPoint("TOPRIGHT", addIdea, "BOTTOMRIGHT", 0, -10)
  local claim = UI.Button(tab, 110, 24, "Become admin", "ghost", function() I:ClaimAdmin() tab:Refresh() end)
  claim:SetPoint("RIGHT", copyBtn, "LEFT", -6, 0)
  claim.tooltip = "The admin sets status (planned, done, rejected). The first one to claim it in the gang gets it."

  local function createIdea(list)
    local row = CreateFrame("Frame", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.up = UI.IconButton(row, 20, "Up", "Vote up", function() if row.item then I:Vote(row.item.id, 1) end end)
    row.up:SetPoint("TOPLEFT", 8, -5)
    row.down = UI.IconButton(row, 20, "Up", "Vote down", function() if row.item then I:Vote(row.item.id, -1) end end)
    row.down:SetPoint("BOTTOMLEFT", 8, 5)
    if row.down.icon and row.down.icon.SetRotation then row.down.icon:SetRotation(math.pi) end
    row.score = UI.Text(row, 14, "bold", C.text)
    row.score:SetPoint("LEFT", 32, 0)
    row.score:SetWidth(30)
    row.score:SetJustifyH("CENTER")
    row.title = UI.Text(row, 13, "semi", C.text)
    row.title:SetPoint("TOPLEFT", 70, -8)
    row.title:SetPoint("RIGHT", -140, 0)
    row.meta = UI.Text(row, 11, nil, C.muted)
    row.meta:SetPoint("BOTTOMLEFT", 70, 8)
    row.meta:SetPoint("RIGHT", -140, 0)
    -- status as a coloured pill; the admin clicks it to change status
    row.pill = UI.Pill(row)
    row.pill:SetPoint("RIGHT", -36, 0)
    row.status = CreateFrame("Button", nil, row)
    row.status:SetAllPoints(row.pill)
    row.status:SetScript("OnClick", function(self)
      if not row.item or not I:IsAdmin() then return end
      local items = {}
      for _, k in ipairs(I.STATUS_ORDER) do
        items[#items + 1] = { text = I.STATUS[k].name, color = I.STATUS[k].color, func = function() I:SetStatus(row.item.id, k) end }
      end
      UI.Menu(self, items, true)
    end)
    row.status:SetScript("OnEnter", function(self)
      if not I:IsAdmin() then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Click to change status")
      GameTooltip:Show()
    end)
    row.status:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.del = UI.IconButton(row, 22, "Close", "Delete", function() if row.item then I:Delete(row.item.id) end end)
    row.del:SetPoint("RIGHT", -8, 0)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
      local it = self.item
      if not it then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(it.title or "", 1, 1, 1, true)
      if it.desc and it.desc ~= "" then GameTooltip:AddLine(it.desc, 0.8, 0.82, 0.85, true) end
      local ups, downs = {}, {}
      for pid, v in pairs(it.votes or {}) do
        local p = ns:GetPerson(pid) or {}
        local n = ns:PersonAlias(p) or ns:PersonName(p) or "?"
        if v > 0 then ups[#ups + 1] = n elseif v < 0 then downs[#downs + 1] = n end
      end
      if #ups > 0 then GameTooltip:AddLine("Up: " .. table.concat(ups, ", "), 0.37, 0.82, 0.55, true) end
      if #downs > 0 then GameTooltip:AddLine("Down: " .. table.concat(downs, ", "), 0.95, 0.47, 0.48, true) end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
  end
  local function updateIdea(row, it)
    local score = I:Score(it)
    local mine = (it.votes or {})[ns.pid]
    row.score:SetText((score > 0 and "+" or "") .. score)
    row.score:SetTextColor(hex(score > 0 and C.green or (score < 0 and C.red or C.muted)))
    row.up.icon:SetVertexColor(hex(mine == 1 and C.green or C.dim))
    row.down.icon:SetVertexColor(hex(mine == -1 and C.red or C.dim))
    row.title:SetText(it.title or "")
    local p = ns:GetPerson(it.pid) or {}
    row.meta:SetText(ns:ShortWho(p, it.char) .. ns.Colorize("  ·  " .. ns.Ago(it.t) .. ((it.desc and it.desc ~= "") and ("  ·  " .. it.desc) or ""), C.dim))
    local st = I.STATUS[it.status or "new"]
    row.pill:Set(st.name, st.color)
    row.del:SetShown(it.pid == ns.pid or I:IsAdmin())
  end
  local ideaList = UI.List(tab, 46, 6, createIdea, updateIdea)
  ideaList:SetPoint("TOPLEFT", titleBox, "BOTTOMLEFT", 0, -44)
  ideaList:SetPoint("BOTTOMRIGHT", -10, 14)
  ideaList.emptyText = "No ideas here yet. Suggest something above – everyone in the gang can vote."

  function tab:Refresh()
    paintFilter()
    ideaList:SetData(I:List(ideaFilter))
    local admin = I:Admin()
    if admin then
      local ap = ns:GetPerson(admin) or {}
      adminInfo:SetText("Admin: " .. (ns:PersonAlias(ap) or ns:PersonName(ap) or "?") .. (I:IsAdmin() and "  (you – click a status to change it)" or ""))
    else
      adminInfo:SetText("No admin yet")
    end
    claim:SetShown(not admin)
    ns.Badges:MarkSeen("ideas")
  end
end)
