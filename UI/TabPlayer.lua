-- Chillan? – the player page: every number for one friend (opened from Friends)
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex
local St = ns.St

ns:RegisterTab("player", "Player", "Friends", function(tab)
  local showAlts = false

  -------------------------------------------------------------------------
  -- (1.4.72) the canvas layout: Back and the buttons on one row, who, five tiles, then the panels in
  -- three columns (label left, value right; a long value wraps, nothing is cut with "…")
  -------------------------------------------------------------------------
  local back = UI.Button(tab, 76, 26, "‹ Back", "ghost", function()
    ns.Window:Select(ns.Window.returnTo or "friends")
  end)
  back:SetPoint("TOPLEFT", 16, -12)

  local invite = UI.Button(tab, 76, 26, "Invite", "primary")
  invite:SetPoint("TOPRIGHT", -16, -12)
  local whisper = UI.Button(tab, 80, 26, "Whisper", "secondary")
  whisper:SetPoint("RIGHT", invite, "LEFT", -6, 0)
  local compare = UI.Button(tab, 100, 26, "Compare", "ghost")
  compare:SetIcon("Compare", 14)
  compare:SetPoint("RIGHT", whisper, "LEFT", -6, 0)
  -- mute: no popups or sounds from this friend (feed still shows everything)
  local mute = UI.Button(tab, 70, 26, "Mute", "ghost")
  mute:SetPoint("RIGHT", compare, "LEFT", -6, 0)

  local avatar = UI.Avatar(tab, 44)
  avatar:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 0, -12)
  local name = UI.Text(tab, 18, "bold", C.text)
  name:SetPoint("TOPLEFT", avatar, "TOPRIGHT", 12, -2)
  name:SetWordWrap(false)
  local crown = UI.TitleHit(tab)
  local sub = UI.Text(tab, 12, nil, C.text2)
  sub:SetPoint("BOTTOMLEFT", avatar, "BOTTOMRIGHT", 12, 3)
  sub:SetPoint("RIGHT", -16, 0)
  sub:SetWordWrap(false)

  -------------------------------------------------------------------------
  -- five tiles (the first four can be pinned under the Chillan bar on your own page)
  -------------------------------------------------------------------------
  local TILE_Y = -12 - 26 - 12 - 44 - 14
  local tileCols = { C.accent, "C69B6D", "6FA8F2", C.gold, C.green }
  local tiles = {}
  for i = 1, 5 do
    local t = UI.NumTile(tab, true)
    t:Accent(tileCols[i])
    t.pinKey = ({ "level", "xph", "eta", "played" })[i]
    if t.pinKey then
      t.pin = UI.Icon(t, "Plus", 12, C.dim)
      t.pin:SetPoint("TOPRIGHT", -8, -8)
      t:EnableMouse(true)
      t:SetScript("OnMouseUp", function(self)
        if not self.isMe then return end
        local on = ns.Tiles:Toggle(self.pinKey)
        ns.Print(on and "Pinned under the Chillan? bar." or "Removed from the Chillan? bar.")
        self:RefreshPin()
      end)
      function t:RefreshPin()
        self.pin:SetShown(self.isMe and true or false)
        local on = ns.Tiles:IsPinned(self.pinKey)
        self.pin:SetTexture(ns.TEX .. "Icon" .. (on and "Check" or "Plus"))
        UI.Track(self.pin):SetVertexColor(hex(on and C.green or C.dim))
      end
      t:SetScript("OnEnter", function(self)
        if not self.isMe then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(ns.Tiles:IsPinned(self.pinKey) and "Click: remove from the Chillan? bar" or "Click: pin under the Chillan? bar", 1, 1, 1)
        GameTooltip:Show()
      end)
      t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    tiles[i] = t
  end

  -------------------------------------------------------------------------
  -- the panels, scrolled
  -------------------------------------------------------------------------
  local PANELS_Y = TILE_Y - 58 - 12
  local scroll = CreateFrame("ScrollFrame", nil, tab)
  scroll:SetPoint("TOPLEFT", 16, PANELS_Y)
  scroll:SetPoint("BOTTOMRIGHT", -16, 10)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(700, 400)
  scroll:SetScrollChild(content)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local maxScroll = math.max(0, content:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 40)))
  end)

  local panels, pIndex = {}, 0
  local function getPanel()
    pIndex = pIndex + 1
    local sp = panels[pIndex]
    if not sp then
      sp = UI.Section(content, "")
      sp.kv = UI.KVRows(sp.body)
      sp.btn = UI.Button(sp, 120, 20, "", "ghost")
      sp.btn:SetPoint("RIGHT", sp, "TOPRIGHT", -6, -(sp.stripH / 2))
      panels[pIndex] = sp
    end
    sp.btn:Hide()
    sp:Show()
    return sp
  end

  local function dur(x) return x and ns.Duration(x) or "–" end
  local PANEL_ORDER = { ["Leveling"] = 1, ["Time"] = 2, ["Quests and gold"] = 3, ["Deaths"] = 4, ["PvP"] = 5,
    ["Gear and addon"] = 6, ["Dungeons and raids"] = 7, ["Professions"] = 8, ["Trophies"] = 9, ["Social"] = 10,
    ["Other characters"] = 11 }

  function tab:Refresh()
    local pid = ns.Window.playerPid
    local p = ns:GetPerson(pid)
    if not p then return end
    local me = pid == ns.pid
    local c = ns:PersonChar(p) or {}
    local s3 = ns:PersonS3(p) or {}
    local online = ns:IsOnline(p)
    local L = p.live or {}
    local W = math.max(600, math.floor(tab:GetWidth() + 0.5))
    local inner = W - 32

    avatar:Set(c.name, c.class, (online or me) and C.green or "4A4F55", C.window)
    name:SetText(ns.WhoLine(p))
    name:SetWidth(math.min(inner - 60, math.ceil(name:GetStringWidth() or 100) + 4))
    name:ClearAllPoints()
    name:SetPoint("TOPLEFT", avatar, "TOPRIGHT", 12, -2)
    crown:ClearAllPoints()
    crown:SetPoint("LEFT", name, "RIGHT", 10, 0)
    crown:Set(p)
    sub:SetText(ns.WhereLine(p))
    local target = L.char or p.main
    whisper:SetScript("OnClick", function() ns.Whisper(target) end)
    invite:SetScript("OnClick", function() ns.Invite(target) end)
    whisper:SetShown(not me) invite:SetShown(not me and online)
    compare:SetShown(not me)
    compare:SetScript("OnClick", function() ns.Window:OpenCompare(p.pid) end)
    mute:SetShown(not me)
    mute:SetLabel(ns:IsMuted(pid) and "Unmute" or "Mute")
    mute:SetScript("OnClick", function() ns:SetMuted(pid, not ns:IsMuted(pid)) tab:Refresh() end)

    -- tiles
    local pct = ns.Pct(s3.xp, s3.xpMax)
    local rate = St:XPRate(p)
    local eta = St:ETA(p)
    local nChars = 0
    for _ in pairs(p.chars or {}) do nChars = nChars + 1 end
    local played = ns:PersonPlayed(p)
    local vals = {
      { tostring(c.level or "?"), pct and (pct .. " % to level " .. ((tonumber(c.level) or 0) + 1)) or "level" },
      { rate and ns.Num(rate) or "–", "XP per hour" },
      { eta and ("~" .. ns.Duration(eta)) or "–", "to next level" },
      { played > 0 and ns.Duration(played) or "–", "Played" .. (nChars > 1 and (" · " .. nChars .. " characters") or "") },
      { s3.streak and ns.Plural(s3.streak, "day") or "–", "streak" },
    }
    for i, t in ipairs(tiles) do
      t:Set(vals[i][1], vals[i][2])
      t.isMe = me
      if t.RefreshPin then t:RefreshPin() end
    end
    UI.LayTiles(tiles, tab, 16, TILE_Y, inner, 10)

    -- panels
    for _, sp in ipairs(panels) do sp:Hide() sp.kv:Hide() end
    pIndex = 0
    local COLS = W >= 860 and 3 or 2
    local GAP = 12
    content:SetWidth(inner)
    local colW = math.floor((inner - GAP * (COLS - 1)) / COLS)
    local colY = {}
    for k = 1, COLS do colY[k] = 0 end
    local function section(title, rows, button)
      local sp = getPanel()
      sp:SetTitle(title)
      if button then
        sp.btn:SetLabel(button.label)
        sp.btn:SetWidth(sp.btn.label:GetStringWidth() + 20)
        sp.btn:SetScript("OnClick", button.onClick)
        sp.btn:Show()
      end
      -- (1.4.72) each panel has its own column, so nothing moves around when a number changes (the
      -- shortest-column rule swapped panels between columns as heights changed)
      local idx = PANEL_ORDER[title] or 1
      local k = ((idx - 1) % COLS) + 1
      sp:ClearAllPoints()
      sp:SetWidth(colW)
      sp:SetPoint("TOPLEFT", content, "TOPLEFT", (k - 1) * (colW + GAP), colY[k])
      local h = sp.kv:Draw(rows, 0, 0, colW - 24, 1)
      sp:FitBody(h)
      colY[k] = colY[k] - sp:GetHeight() - GAP
    end

    local lvl = St:LevelSummary(p)
    section("Leveling", {
      { "XP now", (s3.xp and s3.xpMax) and (ns.Num(s3.xp) .. " / " .. ns.Num(s3.xpMax)) or nil },
      { "Rested", (s3.rested and s3.xpMax and s3.rested > 0) and (ns.Num(s3.rested) .. " (" .. ns.Pct(s3.rested, s3.xpMax) .. " %)") or "none" },
      { "This session", s3.sessXP and (ns.Num(s3.sessXP) .. " XP") or nil },
      { "This week", s3.wXP and (ns.Num(s3.wXP) .. " XP") or nil },
      { "Average level", lvl and (dur(lvl.avg) .. (lvl.estimated and " (est.)" or "")) or nil },
      { "Fastest", (lvl and lvl.fast) and (lvl.fast.level .. " · " .. dur(lvl.fast.secs)) or nil },
      { "Slowest", (lvl and lvl.slow) and (lvl.slow.level .. " · " .. dur(lvl.slow.secs)) or nil },
      { "To 60", St:ETA60(p) and ("~" .. dur(St:ETA60(p)) .. " played") or ((c.level or 0) >= 60 and "done" or nil) },
    })

    local sessionLen = online and L.session and (ns.Now() - L.session) or nil
    section("Time", {
      { "This session", sessionLen and dur(sessionLen) or "offline" },
      { "Today", s3.today and dur(s3.today) or nil },
      { "This week", dur(ns:WeekStat(p, "Online")) },
      { "Total", dur(ns:TotalStat(p, "Online")) },
      { "Longest session", dur((p.stats or {}).tLongest) },
      { "Streak", s3.streak and ns.Plural(s3.streak, "day") or nil },
      { "Most played zone", s3.zone },
    })

    local qph = St:PerHour(p, "Quests")
    section("Quests and gold", {
      { "Quests this week", ns.Num(math.floor(ns:WeekStat(p, "Quests"))) },
      { "Quests total", ns.Num(math.floor(ns:TotalStat(p, "Quests"))) },
      { "Quests per hour", qph and string.format("%.1f", qph) or nil },
      { "Gold this week", ns.WeekGoldLine(p) },
      { "Gold total", ns.Money(ns:TotalStat(p, "Gold")) },
      { "Gold now", s3.money and ns.Money(s3.money) or nil },
    })

    local maxLvl = math.max(1, ns:PersonMaxLevel(p))
    local deathsT = ns:TotalStat(p, "Deaths")
    section("Deaths", {
      { "This week", ns.Num(math.floor(ns:WeekStat(p, "Deaths"))) },
      { "Total", ns.Num(math.floor(deathsT)) },
      { "Per 10 levels", string.format("%.1f", deathsT / maxLvl * 10) },
      { "Last", p.deathZone and (p.deathZone .. ns.Colorize(" · " .. ns.Ago(p.deathAt), C.dim)) or nil },
    })

    -- who has killed them the most ("Died to")
    local foe, foeN = nil, 0
    if ns.DiedTo and ns.DiedTo.List then
      for _, e in ipairs(ns.DiedTo:List()) do
        local n = e.by and e.by[pid] or 0
        if n > foeN then foe, foeN = e, n end
      end
    end
    section("PvP", {
      { "HKs this week", ns.Num(math.floor(ns:WeekStat(p, "Kills"))) },
      { "HKs total", ns.Num(math.floor(ns:TotalStat(p, "Kills"))) },
      { "Killed by most", foe and (ns.Colorize(foe.name, C.red) .. " · " .. foeN .. "×") or nil },
    })

    -- (1.4.72) dungeons and raids, counted from the gang's run and boss posts
    local x = ns.PvETally and ns.PvETally:For(pid)
    if x and (x.runs + x.raids + x.bosses) > 0 then
      local most, mostN = ns.PvETally:MostRun(x)
      local recs = ns.PvETally:Records(pid)
      section("Dungeons and raids", {
        { "Dungeons run", ns.Num(x.runs) },
        { "Raids", x.raids > 0 and ns.Num(x.raids) or nil },
        { "Bosses killed", ns.Num(x.bosses) },
        { "Most run", most and (most .. ns.Colorize(" · " .. mostN .. "×", C.dim)) or nil },
        { "Fastest run", x.fastRun and (x.fastRun.inst .. ns.Colorize(" · " .. ns.Duration(x.fastRun.s), C.dim)) or nil },
        { "Fastest boss", x.fastBoss and (x.fastBoss.boss .. ns.Colorize(" · " .. string.format("%d:%02d", math.floor(x.fastBoss.s / 60), x.fastBoss.s % 60), C.dim)) or nil },
        { "Gang records", recs > 0 and ns.Colorize(recs .. " held", C.gold) or nil },
        { "Last run", x.last and (x.last.inst .. ns.Colorize(" · " .. ns.Ago(x.last.t), C.dim)) or nil },
      })
    end

    local cmp = (not me) and ns.Gear and ns.Gear:Compare(p)
    local vs
    if cmp and cmp.avg then
      local parts = {}
      if cmp.worse > 0 then parts[#parts + 1] = ns.Colorize(cmp.worse .. " worse", C.red) end
      if cmp.better > 0 then parts[#parts + 1] = ns.Colorize(cmp.better .. " better", C.green) end
      vs = #parts > 0 and table.concat(parts, " · ") or "same"
    end
    local dura = s3.dura and ns.Colorize(s3.dura .. " %", s3.dura <= 10 and C.red or (s3.dura <= 30 and C.amber or C.text)) or nil
    section("Gear and addon", {
      { "Item level", s3.ilvl and tostring(s3.ilvl) or nil },
      { "Vs yours", vs },
      { "Durability", dura },
      { "Chillan", ns.VersionLine(p) },
    })

    -- professions (also on their other installs, marked with that character)
    local profRows = {}
    for _, pr in ipairs(p.profs or {}) do
      local gain = pr.base and (pr.skill - pr.base) or 0
      profRows[#profRows + 1] = { pr.name, pr.skill .. " / " .. pr.max .. (gain > 0 and ns.Colorize("  +" .. gain, C.green) or "") }
    end
    for i, opid in ipairs(ns:LinkedPids(p)) do
      local q = i > 1 and ns.db.people[opid]
      if q then
        local cn = (q.chars and q.main and q.chars[q.main] and q.chars[q.main].name) or ns.ShortName(q.main or "?")
        for _, pr in ipairs(q.profs or {}) do
          profRows[#profRows + 1] = { pr.name .. ns.Colorize(" (" .. cn .. ")", C.dim), pr.skill .. " / " .. pr.max }
        end
      end
    end
    if #profRows > 0 then section("Professions", profRows) end

    local achN, achP = ns.Ach:Count(pid), ns.Ach:Points(pid)
    local list = pid == ns.pid and ns.Ach:Mine() or (p.ach or {})
    local sorted = {}
    for id, t in pairs(list) do
      local d = ns.Ach.byId[id]
      if d then sorted[#sorted + 1] = { d = d, t = type(t) == "number" and t or 0 } end
    end
    table.sort(sorted, function(a2, b2) return a2.t > b2.t end)
    local latest = sorted[1] and ns.Colorize(sorted[1].d.name, ns.Ach.TIERS[sorted[1].d.tier].color) or "none yet"
    section("Trophies", {
      { "Unlocked", achN .. " of " .. #ns.Ach.defs },
      { "Points", tostring(achP) },
      { "Latest", latest },
    }, { label = "See all", onClick = function() ns.Window:OpenAch(pid) end })

    local got, gave = St:Grats(p)
    local firsts = St:Firsts(p)
    -- (1.4.72) the latest epic only (quality 4 or better), as an item link you can hover
    local epic
    for i = #(ns.db.feed or {}), 1, -1 do
      local it = ns.db.feed[i]
      if it.pid == pid and it.kind == "LOOT" and (tonumber(it.b) or 0) >= 4 then
        epic = ns.ItemLink(tonumber(it.a)) or "an epic (loading …)"
        break
      end
    end
    section("Social", {
      { "Congrats got", tostring(got) },
      { "Congrats given", tostring(gave) },
      { "First in the gang", #firsts > 0 and table.concat(firsts, ", ") or "none yet" },
      { "Latest epic", epic or "–", link = epic and epic:find("|Hitem:", 1, true) and epic or nil },
    })

    -- every character of the person, from all their installs
    local alts = {}
    for _, x in ipairs(ns:AllChars(p)) do
      if x.full ~= p.main then alts[#alts + 1] = x.ch end
    end
    table.sort(alts, function(a2, b2) return (a2.level or 0) > (b2.level or 0) end)
    if #alts > 0 then
      local altRows = {}
      for _, ch in ipairs(alts) do
        altRows[#altRows + 1] = { ns.Colorize(ch.name or "?", ns.ClassHex(ch.class)),
          (ch.level or "?") .. " " .. ns.ClassName(ch) .. (ch.played and ns.Colorize(" · " .. dur(ch.played), C.dim) or "") }
      end
      section("Other characters", altRows)
    end

    local deepest = 0
    for k = 1, COLS do deepest = math.min(deepest, colY[k]) end
    content:SetHeight(-deepest + 10)
  end

  tab:SetScript("OnShow", function() scroll:SetVerticalScroll(0) end)
  tab:HookScript("OnSizeChanged", function() if tab:IsVisible() and tab.Refresh then tab:Refresh() end end)
end, true)
