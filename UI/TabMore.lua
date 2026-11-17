-- Chillan? – "Gang": gang code, members and who can craft what
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
  if not ns.S(UnitIsPlayer, "target") then ns.Print("Your target isn't a player.") return end
  if note and note ~= "" then ns.Cunts:Add(name, note) else ns.Cunts:AskAdd(name) end
end

ns:RegisterTab("more", "Gang & crafters", "More", function(tab)
  local LEFT_W = 300

  local general = CreateFrame("Frame", nil, tab)
  general:SetPoint("TOPLEFT", 0, -8)
  general:SetPoint("BOTTOMRIGHT", 0, 0)

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
  tip:SetText("Colours, notifications and modules are under Settings (the cog at the top). Move things on screen with /chill edit.\n\nUseful commands:\n/chill · /cg text · /chill events · /chill edit · /chill selftest · /chill debug")
  local ver = UI.Text(left, 11, nil, C.dim)
  ver:SetPoint("LEFT", h, "RIGHT", 10, 0)
  ver:SetText("version " .. ns.VERSION)

  -- right: who can make what
  local right = CreateFrame("Frame", nil, general)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 20, 0)
  right:SetPoint("BOTTOMRIGHT", -16, 14)

  local kh = UI.Text(right, 15, "semi", C.text)
  kh:SetPoint("TOPLEFT")
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

  function tab:Refresh()
    code:SetText(ns.db.code or "")
    if not aliasBox.edit:HasFocus() then aliasBox:SetText(ns.db.alias or "") end


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
