-- Chillan? – spillersiden: all statistikk for én venn (åpnes fra Venner)
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex
local St = ns.St

ns:RegisterTab("player", "Player", "Friends", function(tab)
  local showAlts = false

  -------------------------------------------------------------------------
  -- Topp: tilbake, avatar, navn, knapper
  -------------------------------------------------------------------------
  local back = UI.Button(tab, 86, 28, "‹ Back", "ghost", function()
    ns.Window:Select(ns.Window.returnTo or "friends")
  end)
  back:SetPoint("TOPLEFT", 16, -14)

  local avatar = UI.Avatar(tab, 42)
  avatar:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 0, -10)
  local name = UI.Text(tab, 18, "bold", C.text)
  name:SetPoint("TOPLEFT", avatar, "TOPRIGHT", 12, -1)
  name:SetPoint("RIGHT", -200, 0)
  local sub = UI.Text(tab, 12, nil, C.text2)
  sub:SetPoint("BOTTOMLEFT", avatar, "BOTTOMRIGHT", 12, 1)
  sub:SetPoint("RIGHT", -200, 0)

  local invite = UI.Button(tab, 80, 30, "Invite", "primary")
  invite:SetPoint("TOPRIGHT", -16, -62)
  local whisper = UI.Button(tab, 80, 30, "Whisper", "secondary")
  whisper:SetPoint("RIGHT", invite, "LEFT", -8, 0)
  local compare = UI.Button(tab, 110, 30, "Compare", "ghost")
  compare:SetIcon("Compare", 14)
  compare:SetPoint("RIGHT", whisper, "LEFT", -8, 0)

  -------------------------------------------------------------------------
  -- Fire store tall
  -------------------------------------------------------------------------
  local tiles = {}
  local tileW = math.floor((711 - 32 - 24) / 4)
  for i = 1, 4 do
    local t = UI.Panel(tab, C.card, C.line, false)
    t:SetSize(tileW, 66)
    t:SetPoint("TOPLEFT", 16 + (i - 1) * (tileW + 8), -110)
    t.v = UI.Text(t, 20, "bold", C.text)
    t.v:SetPoint("TOPLEFT", 12, -10)
    t.v:SetPoint("RIGHT", -26, 0)
    t.k = UI.Text(t, 11, nil, C.muted)
    t.k:SetPoint("BOTTOMLEFT", 12, 10)
    t.k:SetPoint("RIGHT", -8, 0)
    -- på Min side: klikk for å feste rubrikken under Chillan?-baren
    t.pinKey = ({ "level", "xph", "eta", "played" })[i]
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
      self.pin:SetVertexColor(hex(on and C.green or C.dim))
    end
    t:SetScript("OnEnter", function(self)
      if not self.isMe then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(ns.Tiles:IsPinned(self.pinKey) and "Click: remove from the Chillan? bar" or "Click: pin under the Chillan? bar", 1, 1, 1)
      GameTooltip:AddLine("More tiles: «+» on the bar", 0.52, 0.55, 0.57)
      GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tiles[i] = t
  end

  -------------------------------------------------------------------------
  -- Rullbar flate med seksjoner i to kolonner
  -------------------------------------------------------------------------
  local scroll = CreateFrame("ScrollFrame", nil, tab)
  scroll:SetPoint("TOPLEFT", 16, -186)
  scroll:SetPoint("BOTTOMRIGHT", -12, 10)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(711 - 28, 400)
  scroll:SetScrollChild(content)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local maxScroll = math.max(0, content:GetHeight() - self:GetHeight())
    local v = math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 40))
    self:SetVerticalScroll(v)
  end)

  local COL_W = math.floor((711 - 28 - 10 - 6) / 2)
  local cards, rowsPool = {}, {}
  local cardIndex, rowIndex = 0, 0

  local function getCard()
    cardIndex = cardIndex + 1
    local cd = cards[cardIndex]
    if not cd then
      cd = UI.Panel(content, C.card, C.line, false)
      cd.title = UI.Text(cd, 10, "semi", C.muted)
      cd.title:SetPoint("TOPLEFT", 12, -12)
      cd.btn = UI.Button(cd, 150, 24, "", "ghost")
      cd.btn:SetPoint("TOPRIGHT", -8, -6)
      cards[cardIndex] = cd
    end
    cd.btn:Hide()
    cd:Show()
    return cd
  end

  local function getRow(parent)
    rowIndex = rowIndex + 1
    local r = rowsPool[rowIndex]
    if not r then
      r = {}
      r.k = UI.Text(content, 12, nil, C.muted)
      r.v = UI.Text(content, 13, nil, C.text)
      r.v:SetWordWrap(true)
      r.v:SetJustifyV("TOP")
      rowsPool[rowIndex] = r
    end
    r.k:SetParent(parent) r.v:SetParent(parent)
    r.k:Show() r.v:Show()
    return r
  end

  -- legger en seksjon i kolonnen og returnerer ny y
  local function section(colX, y, title, rows, button)
    local cd = getCard()
    cd:ClearAllPoints()
    cd:SetPoint("TOPLEFT", content, "TOPLEFT", colX, y)
    cd:SetWidth(COL_W)
    cd.title:SetText(title:upper())
    if button then
      cd.btn:SetLabel(button.label)
      cd.btn:SetWidth(cd.btn.label:GetStringWidth() + 22)
      cd.btn:SetScript("OnClick", button.onClick)
      cd.btn:Show()
    end
    local ry = -34
    for _, row in ipairs(rows) do
      local r = getRow(cd)
      r.k:ClearAllPoints()
      r.k:SetPoint("TOPLEFT", cd, "TOPLEFT", 12, ry - 1)
      r.k:SetWidth(128)
      r.v:ClearAllPoints()
      r.v:SetPoint("TOPLEFT", cd, "TOPLEFT", 142, ry)
      r.v:SetWidth(COL_W - 154)
      r.k:SetText(row[1])
      r.v:SetText(row[2] or "–")
      ry = ry - math.max(16, r.v:GetStringHeight() or 16) - 6
    end
    local h = -ry + 6
    cd:SetHeight(h)
    return y - h - 10
  end

  local function dur(s) return s and ns.Duration(s) or "–" end

  function tab:Refresh()
    local pid = ns.Window.playerPid
    local p = ns:GetPerson(pid)
    if not p then return end
    local me = pid == ns.pid
    local c = ns:PersonChar(p) or {}
    local s3 = ns:PersonS3(p) or {}
    local online = ns:IsOnline(p)
    local L = p.live or {}

    avatar:Set(c.name, c.class, online and C.green or nil, C.window)
    name:SetText(ns:PersonLabel(p))
    local className = c.class and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class] or c.class) or ""
    local where = online and ("Online · " .. (L.zone or "")) or ("Offline · last seen " .. ns.Ago(p.lastSeen))
    sub:SetText(string.format("Level %s %s %s  ·  %s", c.level or "?", c.race or "", className, where))
    local target = L.char or p.main
    whisper:SetScript("OnClick", function() ns.Whisper(target) end)
    invite:SetScript("OnClick", function() ns.Invite(target) end)
    whisper:SetShown(not me) invite:SetShown(not me and online)
    compare:SetShown(not me)
    compare:SetScript("OnClick", function() ns.Window:OpenCompare(p.pid) end)
    local tl = {}
    for _, def in ipairs(ns.Titles:For(p.pid)) do tl[#tl + 1] = def.name end
    if #tl > 0 then name:SetText(ns:PersonLabel(p) .. "  " .. ns.Titles:Badge(p.pid) .. " " .. ns.Colorize(table.concat(tl, ", "), C.gold)) end

    -- store tall
    for _, t in ipairs(tiles) do t.isMe = me t:RefreshPin() end
    local pct = ns.Pct(s3.xp, s3.xpMax)
    tiles[1].v:SetText(c.level or "?")
    tiles[1].k:SetText(pct and (pct .. " % to next" .. ((s3.rested or 0) > 0 and " · rested" or "")) or "level")
    local rate, rateLabel = St:XPRate(p)
    tiles[2].v:SetText(rate and ns.Num(rate) or "–")
    tiles[2].k:SetText("XP per hour" .. (rateLabel and (" · " .. rateLabel) or ""))
    local eta = St:ETA(p)
    tiles[3].v:SetText(eta and ("~" .. ns.Duration(eta)) or "–")
    tiles[3].k:SetText("to next level")
    local played = ns:PersonPlayed(p)
    tiles[4].v:SetText(played > 0 and ns.Duration(played) or "–")
    tiles[4].k:SetText("/played (all characters)")

    -- seksjoner
    for _, cd in ipairs(cards) do cd:Hide() end
    for _, r in ipairs(rowsPool) do r.k:Hide() r.v:Hide() end
    cardIndex, rowIndex = 0, 0
    local xL, xR = 0, COL_W + 10
    local yL, yR = 0, 0

    local lvl = St:LevelSummary(p)
    local levelRows = {
      { "XP now", (s3.xp and s3.xpMax) and (ns.Num(s3.xp) .. " / " .. ns.Num(s3.xpMax) .. (pct and (" (" .. pct .. " %)") or "")) or nil },
      { "Rested XP", (s3.rested and s3.xpMax and s3.rested > 0) and (ns.Num(s3.rested) .. " (" .. ns.Pct(s3.rested, s3.xpMax) .. " %)") or "none" },
      { "XP this session", s3.sessXP and ns.Num(s3.sessXP) or nil },
      { "XP this week", s3.wXP and ns.Num(s3.wXP) or nil },
      { "Average per level", lvl and (dur(lvl.avg) .. (lvl.estimated and " (estimated)" or "")) or nil },
      { "Fastest level", (lvl and lvl.fast) and ("level " .. lvl.fast.level .. " in " .. dur(lvl.fast.secs)) or nil },
      { "Slowest level", (lvl and lvl.slow) and ("level " .. lvl.slow.level .. " in " .. dur(lvl.slow.secs)) or nil },
      { "Estimated to 60", St:ETA60(p) and ("~" .. dur(St:ETA60(p)) .. " spilletid") or ((c.level or 0) >= 60 and "Already 60!" or nil) },
    }
    yL = section(xL, yL, "Leveling", levelRows)

    local sessionLen = online and L.session and (ns.Now() - L.session) or nil
    local sessionRows = {
      { "This session", sessionLen and dur(sessionLen) or "offline" },
      { "Today", s3.today and dur(s3.today) or nil },
      { "This week", dur(ns:WeekStat(p, "Online")) },
      { "Total", dur(ns:TotalStat(p, "Online")) },
      { "Longest session", dur((p.stats or {}).tLongest) },
      { "Streak", s3.streak and (s3.streak .. (s3.streak == 1 and " day" or " days in a row")) or nil },
      { "Most played zone", s3.zone },
    }
    yL = section(xL, yL, "Sessions", sessionRows)

    local achN, achP = ns.Ach:Count(pid), ns.Ach:Points(pid)
    local recent = {}
    local list = pid == ns.pid and ns.Ach:Mine() or (p.ach or {})
    local sorted = {}
    for id, t in pairs(list) do
      local d = ns.Ach.byId[id]
      if d then sorted[#sorted + 1] = { d = d, t = type(t) == "number" and t or 0 } end
    end
    table.sort(sorted, function(a, b) return a.t > b.t end)
    for i = 1, math.min(3, #sorted) do
      local d = sorted[i].d
      recent[#recent + 1] = ns.Colorize(d.name, ns.Ach.TIERS[d.tier].color)
    end
    yL = section(xL, yL, "Achievements", {
      { "Unlocked", achN .. " of " .. #ns.Ach.defs },
      { "Points", tostring(achP) },
      { "Latest", #recent > 0 and table.concat(recent, ", ") or "none yet" },
    }, { label = "See all", onClick = function() ns.Window:OpenAch(pid) end })

    local got, gave = St:Grats(p)
    local firsts = St:Firsts(p)
    local loot = St:RecentLoot(p, 3)
    local socialRows = {
      { "Congrats received", tostring(got) },
      { "Congrats given", tostring(gave) },
      { "First in the gang", #firsts > 0 and table.concat(firsts, ", ") or "none yet" },
      { "Latest epics", #loot > 0 and table.concat(loot, ", ") or "none yet" },
    }
    yL = section(xL, yL, "Social", socialRows)

    local qph, gph = St:PerHour(p, "Quests"), St:PerHour(p, "Gold")
    local goldRows = {
      { "Quests this week", tostring(math.floor(ns:WeekStat(p, "Quests"))) },
      { "Quests total", tostring(math.floor(ns:TotalStat(p, "Quests"))) },
      { "Quests per hour", qph and string.format("%.1f", qph) or nil },
      { "Gold earned this week", ns.Money(ns:WeekStat(p, "Gold")) },
      { "Gold earned total", ns.Money(ns:TotalStat(p, "Gold")) },
      { "Gold per hour", gph and ns.Money(gph) or nil },
      { "Gold now", s3.money and ns.Money(s3.money) or nil },
    }
    yR = section(xR, yR, "Quests and gold", goldRows)

    local maxLvl = math.max(1, ns:PersonMaxLevel(p))
    local deathsT = ns:TotalStat(p, "Deaths")
    local pvpRows = {
      { "Deaths this week", tostring(math.floor(ns:WeekStat(p, "Deaths"))) },
      { "Deaths total", tostring(math.floor(deathsT)) },
      { "Per 10 levels", string.format("%.1f", deathsT / maxLvl * 10) },
      { "Last place of death", p.deathZone and (p.deathZone .. " (" .. ns.Ago(p.deathAt) .. ")") or nil },
      { "PvP kills this week", tostring(math.floor(ns:WeekStat(p, "Kills"))) },
      { "PvP kills total", tostring(math.floor(ns:TotalStat(p, "Kills"))) },
    }
    yR = section(xR, yR, "Death and PvP", pvpRows)

    local gearRows = { { "Item level", s3.ilvl and tostring(s3.ilvl) or nil } }
    for _, pr in ipairs(p.profs or {}) do
      local gain = pr.base and (pr.skill - pr.base) or 0
      gearRows[#gearRows + 1] = { pr.name, pr.skill .. " / " .. pr.max .. (gain > 0 and ns.Colorize("  +" .. gain .. " this week", C.green) or "") }
    end
    yR = section(xR, yR, "Gear and professions", gearRows)

    local alts = {}
    for full, ch in pairs(p.chars) do
      if full ~= p.main then alts[#alts + 1] = ch end
    end
    table.sort(alts, function(a, b) return (a.level or 0) > (b.level or 0) end)
    local altRows = {}
    if showAlts then
      for _, ch in ipairs(alts) do
        local cn = ch.class and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[ch.class] or ch.class) or ""
        altRows[#altRows + 1] = { ns.Colorize(ch.name or "?", ns.ClassHex(ch.class)),
          "Level " .. (ch.level or "?") .. " " .. cn .. (ch.played and (" · " .. dur(ch.played)) or "") }
      end
    else
      altRows[1] = { "Count", #alts == 0 and "no other characters" or (#alts .. (#alts == 1 and " karakter" or " karakterer")) }
    end
    yR = section(xR, yR, "Other characters", altRows, #alts > 0 and {
      label = showAlts and "Hide" or "Show other characters",
      onClick = function() showAlts = not showAlts tab:Refresh() end,
    } or nil)

    content:SetHeight(math.max(-yL, -yR) + 10)
  end

  tab:SetScript("OnShow", function() scroll:SetVerticalScroll(0) end)
end, true)
