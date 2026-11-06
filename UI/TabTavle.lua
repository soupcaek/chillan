-- Chillan? – fanen "Tavle": mats-tavle, avstemning og avtaler
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("tavle", "Tavle", "Calendar", function(tab)
  local LEFT_W = 300

  -------------------------------------------------------------------------
  -- Venstre: mats-tavle
  -------------------------------------------------------------------------
  local left = CreateFrame("Frame", nil, tab)
  left:SetPoint("TOPLEFT", 16, -14)
  left:SetPoint("BOTTOMLEFT", 16, 14)
  left:SetWidth(LEFT_W)

  local h = UI.Text(left, 15, "semi", C.text)
  h:SetPoint("TOPLEFT")
  h:SetText("Trenger mats")
  local hint = UI.Text(left, 11, nil, C.dim)
  hint:SetPoint("LEFT", h, "RIGHT", 8, 0)
  hint:SetText("Alle i gjengen får beskjed")

  local what = UI.EditBox(left, LEFT_W, 32, "Hva trenger du? f.eks. 20 Copper Bar")
  what:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -10)
  what.edit:SetMaxLetters(60)
  local note = UI.EditBox(left, LEFT_W - 96, 32, "Notat (valgfritt)")
  note:SetPoint("TOPLEFT", what, "BOTTOMLEFT", 0, -8)
  note.edit:SetMaxLetters(60)
  local function post()
    if ns.Data:PostMats(what:GetText(), note:GetText()) then
      what:SetText("") note:SetText("")
    else
      ns.Print("Skriv hva du trenger.")
    end
  end
  what.edit:SetScript("OnEnterPressed", function(self) post() self:ClearFocus() end)
  local postBtn = UI.Button(left, 88, 32, "Legg ut", "primary", post)
  postBtn:SetPoint("LEFT", note, "RIGHT", 8, 0)

  local function createMats(list)
    local row = CreateFrame("Frame", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.what = UI.Text(row, 13, "semi", C.text)
    row.what:SetPoint("TOPLEFT", 12, -9)
    row.what:SetPoint("RIGHT", -96, 0)
    row.who = UI.Text(row, 11, nil, C.muted)
    row.who:SetPoint("BOTTOMLEFT", 12, 9)
    row.who:SetPoint("RIGHT", -96, 0)
    row.btn = UI.Button(row, 80, 28, "Jeg har!", "primary")
    row.btn:SetPoint("RIGHT", -10, 0)
    return row
  end
  local function updateMats(row, it)
    local p = ns:GetPerson(it.pid) or {}
    local c = (p.chars and p.chars[it.char]) or ns:PersonChar(p) or {}
    row.what:SetText(it.text)
    row.who:SetText(ns:PersonLabel(p, it.char) .. "  ·  " .. ns.Ago(it.t)
      .. ((it.note and it.note ~= "") and ("  ·  " .. it.note) or ""))
    if it.pid == ns.pid then
      row.btn:SetStyle("ghost") row.btn:SetLabel("Fjern")
      row.btn:SetScript("OnClick", function() ns.Data:RemoveMats(it.id) end)
    else
      row.btn:SetStyle("primary") row.btn:SetLabel("Jeg har!")
      row.btn:SetScript("OnClick", function() ns.Data:OfferMats(it) end)
    end
  end
  local mats = UI.List(left, 50, 6, createMats, updateMats)
  mats:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -12)
  mats:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", 6, 0)
  mats.emptyText = "Ingen trenger noe akkurat nå."

  -------------------------------------------------------------------------
  -- Høyre: avstemning og avtaler
  -------------------------------------------------------------------------
  local right = CreateFrame("Frame", nil, tab)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 18, 0)
  right:SetPoint("BOTTOMRIGHT", -16, 14)

  local pollCard = UI.Panel(right, C.card, C.line, false)
  pollCard:SetPoint("TOPLEFT")
  pollCard:SetPoint("TOPRIGHT")
  pollCard:SetHeight(176)
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
    r:SetPoint("TOPLEFT", 12, -38 - (i - 1) * 32)
    r:SetPoint("RIGHT", -12, 0)
    r.label = UI.Text(r, 12, nil, C.text2)
    r.label:SetPoint("TOPLEFT")
    r.label:SetPoint("RIGHT", -24, 0)
    r.votes = UI.Text(r, 12, nil, C.muted)
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

  local eh = UI.Text(right, 15, "semi", C.text)
  eh:SetPoint("TOPLEFT", pollCard, "BOTTOMLEFT", 0, -16)
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
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.ic = UI.Icon(row, "Calendar", 18, C.accent)
    row.ic:SetPoint("LEFT", 12, 0)
    row.title = UI.Text(row, 13, "semi", C.text)
    row.title:SetPoint("TOPLEFT", 40, -10)
    row.title:SetPoint("RIGHT", -200, 0)
    row.counts = UI.Text(row, 11, nil, C.muted)
    row.counts:SetPoint("BOTTOMLEFT", 40, 10)
    row.no = UI.Button(row, 44, 28, "Nei", "ghost")
    row.no:SetPoint("RIGHT", -8, 0)
    row.maybe = UI.Button(row, 64, 28, "Kanskje", "ghost")
    row.maybe:SetPoint("RIGHT", row.no, "LEFT", -4, 0)
    row.yes = UI.Button(row, 66, 28, "Kommer", "ghost")
    row.yes:SetPoint("RIGHT", row.maybe, "LEFT", -4, 0)
    return row
  end
  local function updateEv(row, ev)
    row.title:SetText(ev.title .. ((ev.when and ev.when ~= "") and (" – " .. ev.when) or ""))
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
  evList:SetPoint("TOPLEFT", eh, "BOTTOMLEFT", 0, -10)
  evList:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 6, 0)
  evList.emptyText = "Ingen avtaler. Trykk + for å lage en."

  function tab:Refresh()
    local list = {}
    for _, it in pairs(ns.db.mats) do list[#list + 1] = it end
    table.sort(list, function(a, b) return a.t > b.t end)
    mats:SetData(list)

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
