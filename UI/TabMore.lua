-- Chillan? – fanen "More": gjeng, fiendelogg og hvem som kan lage hva
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

function ns.ChangeCode(code)
  if ns.Clean(code or "", 24) == "" then return false end
  ns.Comm:LeaveChannel(ns.Comm:ChannelName())
  return ns:SetCode(code) -- CODE_CHANGED kobler til ny kanal og sier hei
end

function ns.SetAlias(text)
  local a = ns.Clean(text or "", 20)
  if a == "" then ns.Print("Enter your name.") return false end
  ns.db.alias = a
  ns.Tracker:SendStatus(1)
  ns:MarkDirty()
  ns.Print("Your name is saved: " .. a)
  return true
end

function ns.TagTarget(note)
  local name = ns.S(UnitName, "target")
  if not name then ns.Print("Target a hostile player first.") return end
  if not (ns.S(UnitIsPlayer, "target") and ns.S(UnitIsEnemy, "player", "target")) then
    ns.Print("Your target isn't a hostile player.")
    return
  end
  if ns.Data:AddEnemy(name, note) then ns.Print(name .. " was added to the enemy log.") end
end

ns:RegisterTab("more", "More", "More", function(tab)
  local LEFT_W = 300

  -- top switch: General | Ideas
  local general = CreateFrame("Frame", nil, tab)
  general:SetPoint("TOPLEFT", 0, -44)
  general:SetPoint("BOTTOMRIGHT", 0, 0)
  local ideasPage = CreateFrame("Frame", nil, tab)
  ideasPage:SetPoint("TOPLEFT", 16, -52)
  ideasPage:SetPoint("BOTTOMRIGHT", -16, 14)
  local subPage = "general"
  local subBtns = {}
  local function paintSub()
    for k, b in pairs(subBtns) do
      local on = k == subPage
      b.panel:SetColors(on and C.active or nil, on and C.activeLine or C.inputLine)
      b.label:SetTextColor(hex(on and C.text or C.muted))
      b.style = { fill = on and C.active or nil, line = on and C.activeLine or C.inputLine, text = on and C.text or C.muted, hover = on and C.activeHover or C.card }
    end
    general:SetShown(subPage == "general")
    ideasPage:SetShown(subPage == "ideas")
  end
  local prevSub
  for _, def in ipairs({ { "general", "General" }, { "ideas", "Idea box" } }) do
    local b = UI.Button(tab, 10, 28, def[2], "ghost", function() subPage = def[1] paintSub() tab:Refresh() end)
    b:SetWidth(b.label:GetStringWidth() + 24)
    if prevSub then b:SetPoint("LEFT", prevSub, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", 16, -12) end
    prevSub = b
    subBtns[def[1]] = b
  end

  local left = CreateFrame("Frame", nil, general)
  left:SetPoint("TOPLEFT", 16, -6)
  left:SetPoint("BOTTOMLEFT", 16, 14)
  left:SetWidth(LEFT_W)

  local h = UI.Text(left, 15, "semi", C.text)
  h:SetPoint("TOPLEFT")
  h:SetText("The gang")

  local cl = UI.Text(left, 12, nil, C.dim)
  cl:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -12)
  cl:SetText("Gang code – share it with your friends (select and Ctrl+C)")
  local code = UI.EditBox(left, LEFT_W - 96, 34, "No code")
  code:SetPoint("TOPLEFT", cl, "BOTTOMLEFT", 0, -6)
  code.edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  code.edit:SetScript("OnTextChanged", function(self, user)
    if user then self:SetText(ns.db.code or "") self:HighlightText() end
  end)
  local change = UI.Button(left, 88, 34, "Change", "ghost", function()
    UI.Prompt("Change gang", { { label = "New gang code", placeholder = "CHILL-XXXX" } }, function(v)
      if ns.ChangeCode(v) then ns.Print("Switched to the gang " .. ns.db.code .. ".") else return true end
    end)
  end)
  change:SetPoint("LEFT", code, "RIGHT", 8, 0)

  local al = UI.Text(left, 12, nil, C.dim)
  al:SetPoint("TOPLEFT", code, "BOTTOMLEFT", 0, -12)
  al:SetText("Your name (IRL) – shown next to all your characters")
  local aliasBox = UI.EditBox(left, LEFT_W - 96, 34, "e.g. Henrik", function(self)
    ns.SetAlias(self:GetText())
    self:ClearFocus()
  end)
  aliasBox:SetPoint("TOPLEFT", al, "BOTTOMLEFT", 0, -6)
  local saveAlias = UI.Button(left, 88, 34, "Save", "secondary", function()
    ns.SetAlias(aliasBox:GetText())
    aliasBox.edit:ClearFocus()
  end)
  saveAlias:SetPoint("LEFT", aliasBox, "RIGHT", 8, 0)

  local addFriend = UI.Button(left, LEFT_W, 30, "Friend not showing up? Add them manually", "ghost", function()
    UI.Prompt("Add friend manually", {
      { label = "Character name (use this if a friend doesn't show up)", placeholder = "Name or Name-Realm" },
    }, function(v) ns.Data:AddManual(v) end)
  end)
  addFriend.tooltip = "Say hi directly to a character who doesn't show up automatically"
  addFriend:SetPoint("TOPLEFT", aliasBox, "BOTTOMLEFT", 0, -8)

  local tip = UI.Text(left, 12, nil, C.dim)
  tip:SetPoint("TOPLEFT", addFriend, "BOTTOMLEFT", 0, -18)
  tip:SetWidth(LEFT_W)
  tip:SetWordWrap(true)
  tip:SetText("Colours, notifications, position lock and modules are under Settings in the menu on the left.\n\nUseful commands:\n/chill · /cg text · /chill sos · /chill events · /chill lock · /chill debug")
  local ver = UI.Text(left, 11, nil, C.dim)
  ver:SetPoint("LEFT", h, "RIGHT", 10, 0)
  ver:SetText("versjon " .. ns.VERSION)

  -- Høyre: fiendelogg og "kan lage"
  local right = CreateFrame("Frame", nil, general)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 20, 0)
  right:SetPoint("BOTTOMRIGHT", -16, 14)

  local eh = UI.Text(right, 15, "semi", C.text)
  eh:SetPoint("TOPLEFT")
  eh:SetText("Enemy log")
  local tag = UI.Button(right, 130, 28, "Tag your target", "secondary", function()
    if not ns.S(UnitExists, "target") then ns.Print("Target a hostile player first.") return end
    UI.Prompt("Add to the enemy log", { { label = "Note (optional)", placeholder = "e.g. ganks lowbies in STV" } },
      function(note) ns.TagTarget(note) end)
  end)
  tag:SetIcon("Target", 13)
  tag:SetPoint("TOPRIGHT", 0, 4)

  local function createEnemy(list)
    local row = CreateFrame("Frame", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.name = UI.Text(row, 13, "semi", C.red)
    row.name:SetPoint("TOPLEFT", 12, -8)
    row.name:SetPoint("RIGHT", -44, 0)
    row.note = UI.Text(row, 11, nil, C.dim)
    row.note:SetPoint("BOTTOMLEFT", 12, 8)
    row.note:SetPoint("RIGHT", -44, 0)
    row.del = UI.IconButton(row, 26, "Close", "Remove from the log")
    row.del:SetPoint("RIGHT", -8, 0)
    return row
  end
  local function updateEnemy(row, e)
    row.name:SetText(e.name)
    local by = e.byChar and ns.ShortName(e.byChar) or "?"
    row.note:SetText((e.note ~= "" and (e.note .. " · ") or "") .. "tagged by " .. by .. " · " .. ns.Ago(e.t))
    row.del:SetScript("OnClick", function() ns.Data:RemoveEnemy(e.key) end)
  end
  local enemies = UI.List(right, 44, 6, createEnemy, updateEnemy)
  enemies:SetPoint("TOPLEFT", eh, "BOTTOMLEFT", 0, -10)
  enemies:SetPoint("RIGHT", right, "RIGHT", 6, 0)
  enemies:SetHeight(150)
  enemies.emptyText = "No enemies yet. Target an Alliance player and press «Tag your target»."

  local kh = UI.Text(right, 15, "semi", C.text)
  kh:SetPoint("TOPLEFT", enemies, "BOTTOMLEFT", 0, -14)
  kh:SetText("Who can make what?")
  local search
  search = UI.EditBox(right, 100, 32, "Search for a recipe or profession …", function(self) self:ClearFocus() end)
  search:SetPoint("TOPLEFT", kh, "BOTTOMLEFT", 0, -8)
  search:SetPoint("RIGHT", right, "RIGHT", 0, 0)
  search.edit:HookScript("OnTextChanged", function() tab:Refresh() end)

  local function createCraft(list)
    local row = CreateFrame("Frame", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.what = UI.Text(row, 12, "semi", C.text)
    row.what:SetPoint("TOPLEFT", 12, -7)
    row.what:SetPoint("RIGHT", -90, 0)
    row.who = UI.Text(row, 11, nil, C.dim)
    row.who:SetPoint("BOTTOMLEFT", 12, 7)
    row.who:SetPoint("RIGHT", -90, 0)
    row.ask = UI.Button(row, 74, 26, "Ask", "secondary")
    row.ask:SetPoint("RIGHT", -8, 0)
    return row
  end
  local function updateCraft(row, it)
    row.what:SetText(it.what)
    local p = ns:GetPerson(it.pid) or {}
    local c = ns:PersonChar(p) or {}
    row.who:SetText(ns:PersonLabel(p) .. " · " .. it.detail)
    if it.pid == ns.pid then row.ask:Hide() else
      row.ask:Show()
      row.ask:SetScript("OnClick", function() ns.Data:RequestCraft(it.pid, it.what) end)
    end
  end
  local crafts = UI.List(right, 40, 6, createCraft, updateCraft)
  crafts:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -8)
  crafts:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 6, 0)
  crafts.emptyText = "Professions are shared automatically. Open your profession window once, and your recipes are shared too."

  local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
  end

  -------------------------------------------------------------------------
  -- Idea box
  -------------------------------------------------------------------------
  local I = ns.Ideas
  local ideaFilter = "open"
  local titleBox = UI.EditBox(ideasPage, 260, 32, "Your idea, e.g. Show durability on the minibar")
  titleBox:SetPoint("TOPLEFT")
  titleBox.edit:SetMaxLetters(60)
  local descBox = UI.EditBox(ideasPage, 250, 32, "Details (optional)")
  descBox:SetPoint("LEFT", titleBox, "RIGHT", 8, 0)
  descBox.edit:SetMaxLetters(200)
  local addIdea = UI.Button(ideasPage, 90, 32, "Suggest", "primary", function()
    I:Add(titleBox:GetText(), descBox:GetText())
    titleBox:SetText("") descBox:SetText("")
    titleBox.edit:ClearFocus() descBox.edit:ClearFocus()
  end)
  addIdea:SetPoint("LEFT", descBox, "RIGHT", 8, 0)
  addIdea:SetPoint("RIGHT", 0, 0)
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
    local b = CreateFrame("Button", nil, ideasPage)
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
  local adminInfo = UI.Text(ideasPage, 11, nil, C.dim)
  adminInfo:SetPoint("LEFT", prevF, "RIGHT", 14, 0)

  -- copy box (top ideas as text to paste on)
  local copyFrame = UI.Panel(ideasPage, C.window, C.activeLine, false)
  copyFrame:SetFrameStrata("DIALOG")
  copyFrame:SetSize(560, 260)
  copyFrame:SetPoint("CENTER", ideasPage, "CENTER", 0, 0)
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
  local copyBtn = UI.Button(ideasPage, 100, 24, "Copy list", "ghost", function()
    ce:SetText(I:ExportText())
    copyFrame:Show()
    ce:SetFocus()
    ce:HighlightText()
  end)
  copyBtn:SetPoint("TOPRIGHT", addIdea, "BOTTOMRIGHT", 0, -10)
  local claim = UI.Button(ideasPage, 110, 24, "Become admin", "ghost", function() I:ClaimAdmin() tab:Refresh() end)
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
    row.status = UI.Button(row, 86, 22, "New", "ghost", function(self)
      if not row.item or not I:IsAdmin() then return end
      local items = {}
      for _, k in ipairs(I.STATUS_ORDER) do
        items[#items + 1] = { text = I.STATUS[k].name, color = I.STATUS[k].color, func = function() I:SetStatus(row.item.id, k) end }
      end
      UI.Menu(self, items, true)
    end)
    row.status:SetPoint("RIGHT", -36, 0)
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
    row.status:SetLabel(st.name)
    row.status.label:SetTextColor(hex(st.color))
    row.del:SetShown(it.pid == ns.pid or I:IsAdmin())
  end
  local ideaList = UI.List(ideasPage, 46, 6, createIdea, updateIdea)
  ideaList:SetPoint("TOPLEFT", titleBox, "BOTTOMLEFT", 0, -44)
  ideaList:SetPoint("BOTTOMRIGHT", 6, 0)
  ideaList.emptyText = "No ideas here yet. Suggest something above – everyone in the gang can vote."

  function tab:ShowSub(k)
    subPage = k
    self:Refresh()
  end

  function tab:Refresh()
    paintSub()
    if subPage == "ideas" then
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
      return
    end
    code:SetText(ns.db.code or "")
    if not aliasBox.edit:HasFocus() then aliasBox:SetText(ns.db.alias or "") end

    local es = {}
    for key, e in pairs(ns.db.enemies) do e.key = key es[#es + 1] = e end
    table.sort(es, function(a, b) return (a.t or 0) > (b.t or 0) end)
    enemies:SetData(es)

    local q = (search:GetText() or ""):lower()
    local out = {}
    for pid, p in pairs(ns.db.people) do
      if p.main then
        for _, prof in ipairs(p.profs or {}) do
          if q == "" or prof.name:lower():find(q, 1, true) then
            out[#out + 1] = { pid = pid, what = prof.name, detail = prof.skill .. " / " .. prof.max, sort = 0 }
          end
        end
        if q ~= "" and #q >= 3 then
          for profName, ids in pairs(p.recipes or {}) do
            for _, id in ipairs(ids) do
              local name = spellName(id)
              if name and name:lower():find(q, 1, true) then
                out[#out + 1] = { pid = pid, what = name, detail = profName, sort = 1 }
              end
              if #out > 60 then break end
            end
          end
        end
      end
    end
    table.sort(out, function(a, b) if a.sort ~= b.sort then return a.sort < b.sort end return a.what < b.what end)
    crafts:SetData(out)
  end
end)
