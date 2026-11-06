-- Chillan? – fanen "LFG": grupper, avstemning og avtaler
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("lfg", "LFG", "LFG", function(tab)
  local LEFT_W = 236
  local need = { Tank = false, Healer = false, DPS = false }

  -- Venstre: ny forespørsel
  local left = CreateFrame("Frame", nil, tab)
  left:SetPoint("TOPLEFT", 16, -14)
  left:SetPoint("BOTTOMLEFT", 16, 14)
  left:SetWidth(LEFT_W)

  local h = UI.Text(left, 15, "semi", C.text)
  h:SetPoint("TOPLEFT")
  h:SetText("Ny forespørsel")

  local al = UI.Text(left, 12, nil, C.dim)
  al:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -12)
  al:SetText("Aktivitet")
  local act = UI.EditBox(left, LEFT_W, 32, "f.eks. Wailing Caverns")
  act:SetPoint("TOPLEFT", al, "BOTTOMLEFT", 0, -6)

  local nl = UI.Text(left, 12, nil, C.dim)
  nl:SetPoint("TOPLEFT", act, "BOTTOMLEFT", 0, -10)
  nl:SetText("Trenger")
  local roleButtons = {}
  local function paintRole(role)
    local b = roleButtons[role]
    if need[role] then
      b.panel:SetColors(C.active, C.accent) b.label:SetTextColor(hex(C.text))
      b.style = { fill = C.active, line = C.accent, text = C.text, hover = "33383E" }
    else
      b.panel:SetColors(nil, C.inputLine) b.label:SetTextColor(hex(C.muted))
      b.style = { fill = nil, line = C.inputLine, text = C.muted, hover = C.card }
    end
  end
  local bw = math.floor((LEFT_W - 12) / 3)
  for i, role in ipairs({ "Tank", "Healer", "DPS" }) do
    local b = UI.Button(left, bw, 30, role, "ghost", function()
      need[role] = not need[role]
      paintRole(role)
    end)
    b:SetPoint("TOPLEFT", nl, "BOTTOMLEFT", (i - 1) * (bw + 6), -6)
    roleButtons[role] = b
    paintRole(role)
  end

  local ml = UI.Text(left, 12, nil, C.dim)
  ml:SetPoint("TOPLEFT", nl, "BOTTOMLEFT", 0, -46)
  ml:SetText("Plasser og melding")
  local slots = UI.EditBox(left, 48, 32, "5")
  slots:SetPoint("TOPLEFT", ml, "BOTTOMLEFT", 0, -6)
  slots.edit:SetNumeric(true)
  slots.edit:SetMaxLetters(2)
  local msg = UI.EditBox(left, LEFT_W - 56, 32, "Møtes ved inngangen")
  msg:SetPoint("LEFT", slots, "RIGHT", 8, 0)

  local post = UI.Button(left, LEFT_W, 36, "Post til gjengen", "primary", function()
    local roles = {}
    for _, r in ipairs({ "Tank", "Healer", "DPS" }) do if need[r] then roles[#roles + 1] = r:lower() end end
    if ns.Data:PostLFG(act:GetText(), table.concat(roles, ", "), slots:GetText(), msg:GetText()) then
      act:SetText("") msg:SetText("")
      for r in pairs(need) do need[r] = false paintRole(r) end
    else
      ns.Print("Skriv hvilken aktivitet det gjelder.")
    end
  end)
  post:SetPoint("TOPLEFT", slots, "BOTTOMLEFT", 0, -10)

  -- Avstemning
  local pollCard = UI.Panel(left, C.card, C.line, false)
  pollCard:SetPoint("TOPLEFT", post, "BOTTOMLEFT", 0, -12)
  pollCard:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", 0, 0)
  local pq = UI.Text(pollCard, 13, "semi", C.text)
  pq:SetPoint("TOPLEFT", 12, -12)
  pq:SetPoint("RIGHT", -40, 0)
  local newPoll = UI.IconButton(pollCard, 26, "Plus", "Ny avstemning", function()
    UI.Prompt("Ny avstemning", {
      { label = "Spørsmål", placeholder = "Hva kjører vi i kveld?" },
      { label = "Alternativer (skill med ;)", placeholder = "Scarlet Monastery; World PvP; Questing" },
    }, function(q, opts)
      if not ns.Data:CreatePoll(q, opts) then
        ns.Print("Skriv et spørsmål og minst to alternativer skilt med ;")
        return true
      end
    end)
  end)
  newPoll:SetPoint("TOPRIGHT", -8, -8)
  local optRows = {}
  for i = 1, 4 do
    local r = CreateFrame("Button", nil, pollCard)
    r:SetHeight(28)
    r:SetPoint("TOPLEFT", 12, -36 - (i - 1) * 32)
    r:SetPoint("RIGHT", -12, 0)
    r.label = UI.Text(r, 12, nil, C.text2)
    r.label:SetPoint("TOPLEFT")
    r.label:SetPoint("RIGHT", -24, 0)
    r.votes = UI.Text(r, 12, nil, C.dim)
    r.votes:SetPoint("TOPRIGHT")
    r.track = r:CreateTexture(nil, "ARTWORK")
    r.track:SetTexture(ns.TEX .. "RoundedSmall")
    r.track:SetVertexColor(hex(C.active))
    r.track:SetHeight(6)
    r.track:SetPoint("BOTTOMLEFT")
    r.track:SetPoint("BOTTOMRIGHT")
    r.bar = r:CreateTexture(nil, "OVERLAY")
    r.bar:SetTexture(ns.TEX .. "RoundedSmall")
    r.bar:SetVertexColor(hex(C.accent))
    r.bar:SetHeight(6)
    r.bar:SetPoint("BOTTOMLEFT")
    r:SetScript("OnEnter", function(self) self.label:SetTextColor(hex(C.text)) end)
    r:SetScript("OnLeave", function(self) self.label:SetTextColor(hex(C.text2)) end)
    optRows[i] = r
  end

  -- Høyre: åpne grupper og avtaler
  local right = CreateFrame("Frame", nil, tab)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 14, 0)
  right:SetPoint("BOTTOMRIGHT", -16, 14)

  local rh = UI.Text(right, 15, "semi", C.text)
  rh:SetPoint("TOPLEFT")
  rh:SetText("Åpne grupper")
  local rc = UI.Text(right, 12, nil, C.dim)
  rc:SetPoint("TOPRIGHT", 0, -2)

  local function createPost(list)
    local row = CreateFrame("Frame", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.what = UI.Text(row, 14, "semi", C.text)
    row.what:SetPoint("TOPLEFT", 12, -12)
    row.what:SetPoint("RIGHT", -70, 0)
    row.slots = UI.Pill(row)
    row.slots:SetPoint("TOPRIGHT", -12, -10)
    row.msg = UI.Text(row, 12, nil, C.muted)
    row.msg:SetPoint("TOPLEFT", row.what, "BOTTOMLEFT", 0, -6)
    row.msg:SetPoint("RIGHT", -12, 0)
    row.who = UI.Text(row, 12, nil, C.dim)
    row.who:SetPoint("BOTTOMLEFT", 12, 12)
    row.who:SetPoint("RIGHT", -100, 0)
    row.btn = UI.Button(row, 80, 28, "Bli med", "primary")
    row.btn:SetPoint("BOTTOMRIGHT", -12, 9)
    return row
  end
  local function updatePost(row, post)
    local p = ns:GetPerson(post.pid) or {}
    local c = (p.chars and p.chars[post.char]) or ns:PersonChar(p) or {}
    row.what:SetText(post.activity)
    row.slots:Set((post.size or 1) .. "/" .. (post.slots or 5), C.accent)
    row.msg:SetText(post.msg or "")
    local needText = (post.need and post.need ~= "") and ("trenger " .. post.need) or "alle velkommen"
    row.who:SetText(ns.Colorize(ns.ShortName(post.char), ns.ClassHex(c.class)) .. "  ·  " .. needText .. "  ·  " .. ns.Ago(post.t))
    if post.pid == ns.pid then
      row.btn:SetStyle("ghost")
      row.btn:SetLabel("Fjern")
      row.btn:SetScript("OnClick", function() ns.Data:RemoveLFG(post.id) end)
    else
      row.btn:SetStyle("primary")
      row.btn:SetLabel("Bli med")
      row.btn:SetScript("OnClick", function() ns.Data:JoinLFG(post) end)
    end
  end
  local posts = UI.List(right, 86, 8, createPost, updatePost)
  posts:SetPoint("TOPLEFT", rh, "BOTTOMLEFT", 0, -10)
  posts:SetPoint("RIGHT", right, "RIGHT", 6, 0)
  posts:SetPoint("BOTTOM", right, "BOTTOM", 0, 150)
  posts.emptyText = "Ingen åpne grupper. Post en forespørsel til venstre."

  local eh = UI.Text(right, 13, "semi", C.text)
  eh:SetPoint("BOTTOMLEFT", 0, 124)
  eh:SetText("Avtaler")
  local newEv = UI.IconButton(right, 24, "Plus", "Ny avtale", function()
    UI.Prompt("Ny avtale", {
      { label = "Hva", placeholder = "Scarlet Monastery" },
      { label = "Når", placeholder = "Torsdag 20:00" },
    }, function(t, w)
      if not ns.Data:CreateEvent(t, w) then ns.Print("Skriv hva avtalen gjelder.") return true end
    end)
  end)
  newEv:SetPoint("LEFT", eh, "RIGHT", 8, 0)

  local function createEv(list)
    local row = CreateFrame("Frame", nil, list)
    row.panel = UI.Panel(row, C.card, C.activeLine, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.ic = UI.Icon(row, "Calendar", 18, C.accent)
    row.ic:SetPoint("LEFT", 12, 0)
    row.title = UI.Text(row, 13, "semi", C.text)
    row.title:SetPoint("TOPLEFT", 40, -10)
    row.title:SetPoint("RIGHT", -230, 0)
    row.counts = UI.Text(row, 12, nil, C.dim)
    row.counts:SetPoint("BOTTOMLEFT", 40, 10)
    row.no = UI.Button(row, 46, 28, "Nei", "ghost")
    row.no:SetPoint("RIGHT", -10, 0)
    row.maybe = UI.Button(row, 70, 28, "Kanskje", "ghost")
    row.maybe:SetPoint("RIGHT", row.no, "LEFT", -6, 0)
    row.yes = UI.Button(row, 70, 28, "Kommer", "ghost")
    row.yes:SetPoint("RIGHT", row.maybe, "LEFT", -6, 0)
    return row
  end
  local function updateEv(row, ev)
    row.title:SetText(ev.title .. (ev.when ~= "" and (" – " .. ev.when) or ""))
    local y, m, n = 0, 0, 0
    for _, st in pairs(ev.rsvp) do
      if st == 1 then y = y + 1 elseif st == 2 then m = m + 1 elseif st == 3 then n = n + 1 end
    end
    row.counts:SetText(string.format("%d kommer · %d kanskje · %d nei", y, m, n))
    local mine = ev.rsvp[ns.pid]
    for st, b in pairs({ [1] = row.yes, [2] = row.maybe, [3] = row.no }) do
      b:SetStyle(mine == st and "secondary" or "ghost")
      b:SetScript("OnClick", function() ns.Data:RSVP(ev, st) end)
    end
  end
  local evList = UI.List(right, 52, 6, createEv, updateEv)
  evList:SetPoint("TOPLEFT", right, "BOTTOMLEFT", 0, 116)
  evList:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 6, 0)
  evList.emptyText = "Ingen avtaler. Trykk + for å lage en."

  function tab:Refresh()
    local list = {}
    for _, post in pairs(ns.db.lfg) do list[#list + 1] = post end
    table.sort(list, function(a, b) return a.t > b.t end)
    posts:SetData(list)
    rc:SetText(#list .. " aktive")

    local evs = {}
    for _, ev in ipairs(ns.db.events) do evs[#evs + 1] = ev end
    table.sort(evs, function(a, b) return a.t > b.t end)
    evList:SetData(evs)

    local poll = ns.Data:ActivePoll()
    if poll then
      pq:SetText(poll.q)
      local counts, maxV = {}, 1
      for _, idx in pairs(poll.votes) do counts[idx] = (counts[idx] or 0) + 1 end
      for i = 1, #poll.opts do if (counts[i] or 0) > maxV then maxV = counts[i] end end
      for i, r in ipairs(optRows) do
        local opt = poll.opts[i]
        if opt then
          local v = counts[i] or 0
          local mine = poll.votes[ns.pid] == i
          r.label:SetText((mine and "|cffc8d1dc• |r" or "") .. opt)
          r.votes:SetText(v)
          local w = r:GetWidth() > 0 and r:GetWidth() or 200
          r.bar:SetWidth(math.max(1, w * v / maxV))
          r.bar:SetShown(v > 0)
          r:SetScript("OnClick", function() ns.Data:Vote(poll, i) end)
          r:Show()
        else
          r:Hide()
        end
      end
    else
      pq:SetText("Ingen avstemning – trykk + for å starte en")
      for _, r in ipairs(optRows) do r:Hide() end
    end
  end
end)
