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

-- (1.1.7) "Crafters": who can make what, grouped by profession. The gang code and your name moved to
-- Settings → Your gang.
ns:RegisterTab("more", "Crafters", "More", function(tab)
  -- (1.4.68) compact: one striped row per profession or recipe, the people on the same line, each
  -- person once (alts and second installs of the same person are one chip, with their best skill)
  local search
  search = UI.EditBox(tab, 100, 28, "Search for a recipe or profession …", function(self) self:ClearFocus() end)
  search:SetPoint("TOPLEFT", 12, -12)
  search:SetPoint("RIGHT", tab, "RIGHT", -12, 0)
  search.edit:HookScript("OnTextChanged", function() tab:Refresh() end)
  local cp = UI.Section(tab, "Who can make what")
  cp:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -10)
  cp:SetPoint("BOTTOMRIGHT", -12, 12)
  UI.InfoTip(cp, cp.title, "Who can make what?", "Search for a recipe to see who can craft it. Click a name to send them a request. Professions are shared automatically; open your profession window once and your recipes are shared too.")
  local right = cp.body
  local WHAT_W = 170

  local CHIPS = 6
  local function createCraft(list)
    local row = CreateFrame("Frame", nil, list)
    row.stripe = UI.Track(row:CreateTexture(nil, "BACKGROUND"))
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(hex(C.rowAlt or C.window))
    row.what = UI.Text(row, 12, "semi", C.text)
    row.what:SetPoint("LEFT", 8, 0)
    row.what:SetWidth(WHAT_W - 12)
    row.what:SetWordWrap(false)
    row.chips = {}
    for i = 1, CHIPS do
      local b = UI.Button(row, 60, 22, "", "ghost")
      b.label:SetFont(ns.FONT, 11, "")
      row.chips[i] = b
    end
    return row
  end
  local function updateCraft(row, it, idx)
    row.stripe:SetShown(idx % 2 == 0)
    row.what:SetText(it.what .. (it.sub and ns.Colorize("  " .. it.sub, C.dim) or ""))
    local x = WHAT_W
    for i, b in ipairs(row.chips) do
      local who = it.people[i]
      local p = who and (ns:GetPerson(who.pid) or {})
      if who then
        b:SetLabel(ns:PersonLabel(p) .. (who.detail and ns.Colorize("  " .. who.detail, C.dim) or ""))
        b:SetWidth((b.label:GetStringWidth() or 60) + 18)
      end
      if who and x + b:GetWidth() < (row:GetWidth() or 600) - 4 then
        b:ClearAllPoints()
        b:SetPoint("LEFT", x, 0)
        x = x + b:GetWidth() + 6
        if who.pid == ns.pid then
          b.tooltip = "That's you"
          b:SetScript("OnClick", nil)
        else
          b.tooltip = "Ask " .. (ns:PersonFirst(p) or "them") .. " to make " .. (it.ask or it.what)
          b:SetScript("OnClick", function() ns.Data:RequestCraft(who.pid, it.ask or it.what) end)
        end
        b:Show()
      else
        b:Hide()
      end
    end
  end
  local crafts = UI.List(right, 32, 0, createCraft, updateCraft)
  crafts:SetPoint("TOPLEFT", 0, 0)
  crafts:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 6, 0)
  crafts.emptyText = "Professions are shared automatically. Open your profession window once, and your recipes are shared too."

  local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
  end

  function tab:Refresh()
    local q = (search:GetText() or ""):lower()
    local groups, order = {}, {}
    local hidden = ns:HiddenDuplicates()
    local function add(key, what, sub, ask, pid, detail, skill)
      pid = hidden[pid] or pid     -- the same person on another install counts once
      local g = groups[key]
      if not g then g = { what = what, sub = sub, ask = ask, people = {}, byPid = {}, sort = sub and 1 or 0 } groups[key] = g order[#order + 1] = g end
      local have = g.byPid[pid]
      if have then
        if (skill or 0) > have.skill then have.skill, have.detail = skill or 0, detail end
        return
      end
      local e = { pid = pid, detail = detail, skill = skill or 0 }
      g.byPid[pid] = e
      g.people[#g.people + 1] = e
    end
    -- every install counts here: an alt's profession is still something the person can make
    for pid, p in pairs(ns.db.people) do
      if p.main then
        for _, prof in ipairs(p.profs or {}) do
          if q == "" or prof.name:lower():find(q, 1, true) then
            add("P:" .. prof.name, prof.name, nil, nil, pid, prof.skill .. "/" .. prof.max, prof.skill)
          end
        end
        if q ~= "" and #q >= 3 then
          local n = 0
          for profName, ids in pairs(p.recipes or {}) do
            for _, id in ipairs(ids) do
              local name = spellName(id)
              if name and name:lower():find(q, 1, true) and n < 40 then
                n = n + 1
                add("R:" .. name, name, profName, name, pid, nil, 0)
              end
            end
          end
        end
      end
    end
    for _, g in ipairs(order) do table.sort(g.people, function(a, b) return a.skill > b.skill end) end
    table.sort(order, function(a, b) if a.sort ~= b.sort then return a.sort < b.sort end return a.what < b.what end)
    crafts:SetData(order)
  end
end)
