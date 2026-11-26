-- Chillan? – "Home": what's going on right now, in one look (1.0, reworked 1.1.5).
-- Left: everyone in the gang as a small card (online first). Middle: the gang's latest moments, drawn
-- like the feed (icons in tinted boxes, reactions as pills). Right: quick actions and this week.
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

-- "4m", "19h", "2d" for the time column
local function shortAgo(t)
  local s = ns.Now() - (t or ns.Now())
  if s < 60 then return "now" end
  if s < 3600 then return math.floor(s / 60) .. "m" end
  if s < 86400 then return math.floor(s / 3600) .. "h" end
  return math.floor(s / 86400) .. "d"
end

local function goldText(copper)
  copper = math.floor(copper or 0)
  local g = math.floor(copper / 10000)
  if g > 0 then return ns.Num(g) .. "g" end
  return math.floor((copper % 10000) / 100) .. "s"
end

ns:RegisterTab("home", "Home", "Friends", function(tab)
  local LEFT_W, RIGHT_W = 230, 214

  ---------------------------------------------------------------------------
  -- left: the gang, one card each
  ---------------------------------------------------------------------------
  -- (1.4.66) the Kit look: each column is a panel with a title strip
  local lp = UI.Section(tab, "The gang")
  lp:SetPoint("TOPLEFT", 12, -12)
  lp:SetPoint("BOTTOMLEFT", 12, 12)
  lp:SetWidth(LEFT_W)
  local left = lp.body

  local quick   -- the person card (made below, once the list exists)
  local function createRow(list)
    local row = CreateFrame("Button", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.dot = row:CreateTexture(nil, "ARTWORK")
    row.dot:SetTexture(ns.TEX .. "Circle")
    row.dot:SetSize(7, 7)
    row.dot:SetPoint("TOPLEFT", 10, -12)
    row.name = UI.Text(row, 13, "semi", C.text)
    row.name:SetPoint("TOPLEFT", 22, -7)
    row.name:SetPoint("RIGHT", -64, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.tag = UI.Text(row, 10, nil, C.muted)
    row.tag:SetPoint("TOPRIGHT", -10, -9)
    row.tag:SetJustifyH("RIGHT")
    row.sub = UI.Text(row, 11, nil, C.dim)
    row.sub:SetPoint("BOTTOMLEFT", 22, 7)
    row.sub:SetPoint("RIGHT", -10, 0)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetWordWrap(false)
    row:SetScript("OnEnter", function(self)
      if not self.item or self.quickOpen then return end
      self.panel:SetColors(C.cardHover, nil)
    end)
    row:SetScript("OnLeave", function(self)
      if not self.quickOpen then self.panel:SetColors(self.rest, nil) end
    end)
    -- (1.2.0) click: a card beside it with their pace, all their characters and "Open player"
    row:SetScript("OnClick", function(self)
      if not self.item then return end
      if IsShiftKeyDown() then ns.Watch:Toggle(self.item.pid) return end
      if quick then quick:Toggle(self, self.item) end
    end)
    return row
  end
  local function updateRow(row, p, idx)
    -- (1.4.68) rows inside the panel: striped, no box around each (cards in a card looked busy)
    row.rest = (idx or 1) % 2 == 0 and (C.rowAlt or C.window) or nil
    row.striped, row.stripe = true, row.rest
    if not row.quickOpen then row.panel:SetColors(row.rest, nil) end
    local c = ns:PersonChar(p) or {}
    local online = ns:IsOnline(p)
    local L = p.live or {}
    row:SetAlpha(online and 1 or 0.55)
    UI.Track(row.dot):SetVertexColor(hex(online and C.green or C.dim))
    local cr, cg, cb = ns.ClassColor(c.class)
    row.name:SetText(ns:ShortWho(p) .. ns.Colorize(" · " .. tostring(c.level or "?"), C.muted))
    if online then
      local tag = ""
      if L.inInst then tag = "dungeon"
      elseif L.status == "AFK" then tag = "AFK"
      elseif L.layer and ns.Layer and ns.Layer.Comparable() then tag = ns.Layer.Label(L.layer) end
      local mine = ns.Layer and ns.Layer:Current()
      -- (1.4.72) an old Chillan shows instead (it matters more: they miss what the gang has)
      local old = ns.IsOutdated(p)
      if old then tag = "old v" .. tostring(p.version) end
      row.tag:SetText(tag)
      UI.Track(row.tag):SetTextColor(hex(old and "E0C068" or (L.layer and mine and L.layer == mine and not L.inInst and ns.Layer and ns.Layer.Comparable()) and "9BE08A" or C.muted))
      local z = L.zone or ""
      if L.sub and L.sub ~= "" and L.sub ~= z then z = z .. ", " .. L.sub end
      row.sub:SetText(z ~= "" and z or "online")
    else
      row.tag:SetText(p.lastSeen and ns.Ago(p.lastSeen) or "")
      UI.Track(row.tag):SetTextColor(hex(C.dim))
      row.sub:SetText(c.zone or (p.live and p.live.zone) or "offline")
    end
  end
  local list = UI.List(left, 44, 0, createRow, updateRow)
  list:SetPoint("TOPLEFT", 0, 0)
  list:SetPoint("BOTTOMRIGHT", 6, 0)
  list.emptyText = "Nobody in the gang yet."
  quick = UI.PersonQuick(tab, { side = "right", width = 400, bounds = tab })
  quick:SetFrameLevel(list:GetFrameLevel() + 40)
  list:HookScript("OnMouseWheel", function() quick:Close() end)
  tab:HookScript("OnHide", function() quick:Close() end)

  ---------------------------------------------------------------------------
  -- right: quick actions and this week
  ---------------------------------------------------------------------------
  local qa = UI.Section(tab, "Quick actions")
  qa:SetPoint("TOPRIGHT", -12, -12)
  qa:SetWidth(RIGHT_W)
  qa:FitBody(4 * 28 + 3 * 6)
  local right = qa.body
  local rh = CreateFrame("Frame", nil, right)
  rh:SetPoint("TOPLEFT", 0, 6) rh:SetSize(1, 1)

  local function action(label, icon, tip, fn)
    local b = UI.Button(right, RIGHT_W - 24, 28, label, "secondary", fn)
    if icon then b:SetIcon(icon, 14) end
    b.tooltip = tip
    return b
  end
  local hop = action("Layer hop", "Radar", "Join someone on another layer – the gang first, then LayerSwap users nearby",
    function() ns.LayerHop:Request() end)
  hop:SetPoint("TOPLEFT", 0, 0)
  local plan = action("Plan something", "Calendar", "Put a plan up for the gang (a dungeon run, a BG night) – they can say if they're coming",
    function()
      UI.Prompt("Plan something", {
        { label = "What", placeholder = "Strat run" },
        { label = "When", placeholder = "Saturday 20:00" },
      }, function(what, when)
        if ns.Data:CreateEvent(what or "", when or "") then ns.Print("Plan posted to the gang.") end
      end)
    end)
  plan:SetPoint("TOPLEFT", hop, "BOTTOMLEFT", 0, -6)
  local tag = action("Cunt List: your target", "Skull", "Put the player you have targeted on the Cunt List (you write why)",
    function() if ns.TagTarget then ns.TagTarget() end end)
  tag:SetPoint("TOPLEFT", plan, "BOTTOMLEFT", 0, -6)
  local edit = action("Move things on screen", "Gear", "Edit mode: drag every Chillan piece on screen at once (/chill edit)",
    function() ns.UI.EditMode(true) end)
  edit:SetPoint("TOPLEFT", tag, "BOTTOMLEFT", 0, -6)

  local wp = UI.Section(tab, "This week")
  wp:SetPoint("TOPLEFT", qa, "BOTTOMLEFT", 0, -10)
  wp:SetPoint("BOTTOMRIGHT", -12, 12)
  if wp.body.SetClipsChildren then wp.body:SetClipsChildren(true) end
  local wh = CreateFrame("Frame", nil, wp.body)
  wh:SetPoint("TOPLEFT", 0, 0) wh:SetPoint("TOPRIGHT", 0, 0) wh:SetHeight(1)
  -- one block per fact, a hairline between them
  local function card(anchor, gap)
    local k = CreateFrame("Frame", nil, wp.body)
    k:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, anchor == wh and 0 or -8)
    k:SetPoint("RIGHT", wp.body, "RIGHT", 0, 0)
    k.line = UI.Track(k:CreateTexture(nil, "ARTWORK"))
    k.line:SetColorTexture(hex(C.line))
    k.line:SetPoint("BOTTOMLEFT", 0, -4) k.line:SetPoint("BOTTOMRIGHT", 0, -4) k.line:SetHeight(1)
    k.title = UI.Text(k, 12, "semi", C.text)
    k.title:SetPoint("TOPLEFT", 0, 0)
    k.title:SetPoint("RIGHT", 0, 0)
    k.body = UI.Text(k, 11, nil, C.text2)
    k.body:SetPoint("TOPLEFT", k.title, "BOTTOMLEFT", 0, -4)
    k.body:SetPoint("RIGHT", 0, 0)
    k.body:SetJustifyH("LEFT")
    k.body:SetWordWrap(true)
    k.body:SetSpacing(2)
    function k:Fit() self:SetHeight(math.max(20, (self.title:GetStringHeight() or 14) + 4 + (self.body:GetStringHeight() or 0))) end
    return k
  end
  local week = card(wh)
  local mine = card(week)
  -- (1.4.72) your week as a two-column list (label left, number right)
  mine.kv = UI.KVRows(mine)
  function mine:Fit()
    local w = math.max(120, math.floor((self:GetWidth() or 200) + 0.5))
    local h = self.kv:Draw(self.rows or {}, 0, -((self.title:GetStringHeight() or 14) + 2), w, 2)
    self:SetHeight((self.title:GetStringHeight() or 14) + 2 + h)
  end
  mine:HookScript("OnSizeChanged", function(self) self:Fit() end)
  local place = card(mine)
  local enemy = card(place)
  local ding = card(enemy)
  local nextEv = card(ding)

  ---------------------------------------------------------------------------
  -- middle: the gang's latest moments (rows with icon boxes and reaction pills)
  ---------------------------------------------------------------------------
  local mp = UI.Section(tab, "The gang lately")
  mp:SetPoint("TOPLEFT", lp, "TOPRIGHT", 12, 0)
  mp:SetPoint("BOTTOMRIGHT", wp, "BOTTOMLEFT", -12, 0)
  local box = mp.body
  local feed = UI.FeedRows(box)
  feed:SetPoint("TOPLEFT", 0, 0)
  feed:SetPoint("BOTTOMRIGHT", 0, 0)
  if feed.SetClipsChildren then feed:SetClipsChildren(true) end
  feed.timeText = function(e) return shortAgo(e.t) end
  feed.onLinkClick = function(_, link, text, button)
    if type(link) == "string" and link:find("^item:") then ns.ItemLinkClick(link, text, button) return end
    if ns.PersonCard then ns.PersonCard:OnLinkClick(link) end
  end

  local function drawFeed()
    feed:Clear()
    local items = ns.db.feed or {}
    for _, x in ipairs(ns.FeedEntries(items, #items - 60)) do
      feed:AddMessage(x.line, { kind = "ev", base = x.line, t = x.t, item = x.item })
    end
    if #items == 0 then feed:AddMessage(ns.Colorize("Dings, drops, kills and trophies from the gang show up here.", C.dim)) end
  end

  local function drawWeek()
    local ok, chal = pcall(ns.Data.CurrentLeader, ns.Data)
    if not ok or not chal then
      week.title:SetText("Weekly challenge")
      week.body:SetText(ns.Colorize("No challenge this week.", C.dim))
    else
      week.title:SetText("Challenge: " .. tostring(chal.label))
      local rank = {}
      for _, p in ipairs(ns:SortedPeople()) do
        local x = ns:WeekStat(p, chal.key)
        if x > 0 then rank[#rank + 1] = { p = p, v = x } end
      end
      table.sort(rank, function(a, b) if a.v ~= b.v then return a.v > b.v end return (a.p.pid or "") < (b.p.pid or "") end)
      local lines = {}
      for k = 1, math.min(3, #rank) do
        lines[k] = k .. ". " .. ns:ShortWho(rank[k].p) .. ns.Colorize("  " .. (chal.fmt and chal.fmt(rank[k].v) or tostring(rank[k].v)), C.muted)
      end
      local me = ns:GetPerson(ns.pid)
      for k, r in ipairs(rank) do
        if r.p == me and k > 1 then
          local gap = rank[k - 1].v - r.v
          lines[#lines + 1] = ns.Colorize("You're no. " .. k .. ", " .. (chal.fmt and chal.fmt(gap) or gap) .. " behind", C.accent)
          break
        end
      end
      week.body:SetText(#lines > 0 and table.concat(lines, "\n") or ns.Colorize("No points yet this week.", C.dim))
    end
    week:Fit()
    -- your own week
    local me = ns:GetPerson(ns.pid, true)
    local function ws(k) return ns:WeekStat(me, k) end
    mine.title:SetText("Your week")
    mine.body:SetText("")
    mine.rows = {
      { "Quests", ns.Num(math.floor(ws("Quests"))) }, { "Levels", tostring(math.floor(ws("Levels"))) },
      { "HKs", ns.Num(math.floor(ws("Kills"))) }, { "Deaths", tostring(math.floor(ws("Deaths"))) },
      { "Gold", ns.WeekGoldLine(me) }, { "Online", ns.Duration(ws("Online")) },
    }
    mine:Fit()
    -- (1.4.72) your place in the gang this week, and how far to the one above in quests
    place.title:SetText("Your place")
    local function rankOf(key)
      local list = {}
      for _, q in ipairs(ns:SortedPeople()) do list[#list + 1] = { p = q, v = ns:WeekStat(q, key) } end
      table.sort(list, function(a, b) return a.v > b.v end)
      for i, r in ipairs(list) do if r.p == me then return i, list[i - 1], r.v end end
    end
    local ord = function(n) return n .. ((n % 100 >= 11 and n % 100 <= 13) and "th" or ({ "st", "nd", "rd" })[n % 10] or "th") end
    local kr = rankOf("Kills")
    local qr, above, qv = rankOf("Quests")
    if kr and qr and (ws("Kills") > 0 or ws("Quests") > 0) then
      local t = ord(kr) .. " in kills  ·  " .. ord(qr) .. " in quests"
      if above and above.v > qv then
        t = t .. "\n" .. ns.Colorize(ns.Num(math.floor(above.v - qv)) .. " quests behind ", C.text) .. ns:ShortWho(above.p)
      end
      place.body:SetText(ns.Colorize(t, C.muted))
    else
      place.body:SetText(ns.Colorize("Do a quest or two to get on the board.", C.dim))
    end
    place:Fit()
    -- most kills on the gang this week ("Died to")
    local e, n
    if ns.DiedTo then e, n = ns.DiedTo:WeekTop() end
    enemy.title:SetText("Enemy of the week")
    if e and (n or 0) > 0 then
      enemy.body:SetText(ns.Colorize(e.name, C.red) .. ns.Colorize("  " .. n .. (n == 1 and " kill " or " kills ") .. ns.DiedTo:OnWho(e), C.muted))
    else
      enemy.body:SetText(ns.Colorize("Nobody has killed the gang this week.", C.dim))
    end
    enemy:Fit()
    -- (1.4.72) who in the gang levels next, from their XP per hour
    ding.title:SetText("Next ding")
    local best, bestEta
    for _, q in ipairs(ns:SortedPeople()) do
      local c = ns:PersonChar(q) or {}
      local eta = (c.level or 0) < 60 and ns.St:ETA(q) or nil
      if eta and eta > 0 and (ns:IsOnline(q) or q.pid == ns.pid) and (not bestEta or eta < bestEta) then best, bestEta = q, eta end
    end
    if best then
      local c = ns:PersonChar(best) or {}
      ding.body:SetText(ns:ShortWho(best) .. ns.Colorize("  ·  level " .. ((c.level or 0) + 1) .. " in ~" .. ns.Duration(bestEta), C.muted))
    else
      ding.body:SetText(ns.Colorize("Nobody online is levelling right now.", C.dim))
    end
    ding:Fit()
  end

  local function drawEvent()
    local best
    for _, ev in ipairs(ns.db.events or {}) do
      if not best or (ev.t or 0) > (best.t or 0) then best = ev end
    end
    nextEv.title:SetText("Next plan")
    if best then
      local coming = 0
      for _, st in pairs(best.rsvp or {}) do if st == "yes" or st == 1 or st == "coming" then coming = coming + 1 end end
      nextEv.body:SetText(tostring(best.title or "") .. "\n" .. ns.Colorize(tostring(best.when or "") .. (coming > 0 and ("  ·  " .. coming .. " coming") or ""), C.muted))
    else
      nextEv.body:SetText(ns.Colorize("Nothing planned – use Plan something above.", C.dim))
    end
    nextEv:Fit()
  end

  function tab:Refresh()
    local people = ns:SortedPeople(function(p, pid) return pid ~= ns.pid end)
    table.sort(people, function(a, b)
      local oa, ob = ns:IsOnline(a) and 1 or 0, ns:IsOnline(b) and 1 or 0
      if oa ~= ob then return oa > ob end
      if oa == 1 then return ns:PersonMaxLevel(a) > ns:PersonMaxLevel(b) end
      return (a.lastSeen or 0) > (b.lastSeen or 0)
    end)
    list:SetData(people)
    quick:Refresh()
    local cur = ns.Layer and ns.Layer:CurrentLabel()
    hop:SetLabel(cur and ("Layer hop  ·  " .. cur) or "Layer hop")
    drawFeed()
    drawWeek()
    drawEvent()
  end
end)
