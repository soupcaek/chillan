-- Chillan? PvP (1.4.38): one card per battleground – record and win rate, honor and HKs,
-- reputation toward Exalted, time – for today, this week or all time, with the gang beside it.
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("pvp", "PvP", "Target", function(tab)
  local P = ns.Pulse
  local range = "all"

  local h = UI.Text(tab, 15, "semi", C.text)
  h:SetPoint("TOPLEFT", 16, -16)
  h:SetText(ns.Logo() .. " PvP")
  local sub = UI.Text(tab, 11, nil, C.dim)
  sub:SetPoint("LEFT", h, "RIGHT", 12, -1)
  sub:SetText("Your battlegrounds, recorded from 1.4.38 on")

  -- today / week / all time
  local RANGES = { { "today", "Today" }, { "week", "Week" }, { "all", "All time" } }
  local rbtns = {}
  for i = #RANGES, 1, -1 do
    local r = RANGES[i]
    local b = UI.Button(tab, 74, 24, r[2], "secondary", function() range = r[1] tab:Refresh() end)
    b.key = r[1]
    if i == #RANGES then b:SetPoint("TOPRIGHT", -16, -12) else b:SetPoint("RIGHT", rbtns[i + 1], "LEFT", -6, 0) end
    rbtns[i] = b
  end

  -- one card per battleground
  local cards = {}
  local CARD_H = 100
  local function cell(parent, x, y, label)
    local v = UI.Text(parent, 13, "semi", C.text)
    v:SetPoint("TOPLEFT", x, y)
    local k = UI.Text(parent, 10, nil, C.dim)
    k:SetPoint("TOPLEFT", v, "BOTTOMLEFT", 0, -2)
    k:SetText(label)
    return v, k
  end
  for i, def in ipairs(P.BG_KEYS) do
    local c = UI.Panel(tab, C.card, C.line, true)
    c:SetPoint("TOPLEFT", 16, -44 - (i - 1) * (CARD_H + 6))
    c:SetPoint("RIGHT", tab, "RIGHT", -16, 0)
    c:SetHeight(CARD_H)
    c.def = def
    c.title = UI.Text(c, 14, "semi", C.text)
    c.title:SetPoint("TOPLEFT", 14, -10)
    c.title:SetText(def.name)
    c.rate = UI.Text(c, 12, "semi", C.green)
    c.rate:SetPoint("LEFT", c.title, "RIGHT", 10, 0)
    -- stats grid: 4 columns × 2 rows
    local cw = 104
    c.cells = {}
    local labels = { "record", "win streak (best)", "honor per hour", "honor per game",
      "HKs per game", "best HKs", "average game", "time played" }
    for k = 1, 8 do
      local col, row = (k - 1) % 4, math.floor((k - 1) / 4)
      local v = cell(c, 14 + col * cw, -38 - row * 30, labels[k])
      c.cells[k] = v
    end
    -- reputation
    -- reputation: a line next to the title and a thin bar under it
    c.repName = UI.Text(c, 11, nil, C.text2)
    c.repName:SetPoint("TOPRIGHT", c, "TOPLEFT", 14 + 4 * cw - 4, -12)
    c.repName:SetJustifyH("RIGHT")
    c.repBg = c:CreateTexture(nil, "ARTWORK")
    c.repBg:SetHeight(4)
    c.repBg:SetPoint("TOPLEFT", 14, -29)
    c.repBg:SetWidth(4 * cw - 14)
    UI.Track(c.repBg):SetColorTexture(hex(C.line))
    c.repBar = c:CreateTexture(nil, "OVERLAY")
    c.repBar:SetHeight(5)
    c.repBar:SetPoint("LEFT", c.repBg, "LEFT")
    UI.Track(c.repBar):SetColorTexture(hex(C.gold))
    -- gang leaderboard on the right
    c.gangHead = UI.Text(c, 10, "semi", C.dim)
    c.gangHead:SetPoint("TOPLEFT", 14 + 4 * cw + 16, -10)
    c.gangHead:SetText("GANG · WIN % · HKS/GAME · STANDING")
    c.gang = {}
    for r = 1, 4 do
      local line = UI.Text(c, 11, nil, C.text2)
      line:SetPoint("TOPLEFT", c.gangHead, "BOTTOMLEFT", 0, -5 - (r - 1) * 15)
      line:SetPoint("RIGHT", c, "RIGHT", -14, 0)
      line:SetJustifyH("LEFT")
      line:SetWordWrap(false)
      c.gang[r] = line
    end
    cards[i] = c
  end

  local STANDING = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
  local function pct(x) return math.floor((x or 0) * 100 + 0.5) .. " %" end

  function tab:Refresh()
    for _, b in ipairs(rbtns) do b:SetStyle(b.key == range and "primary" or "secondary") end
    local st = P.PvPStats(range)
    for _, c in ipairs(cards) do
      local s = st[c.def.key]
      local v = c.cells
      if s and s.played > 0 then
        c.rate:SetText(pct(s.rate) .. " won")
        v[1]:SetText(s.won .. " / " .. s.played)
        v[2]:SetText(s.cur .. " (" .. s.best .. ")")
        v[3]:SetText(s.honorH and ns.Num(s.honorH) or "–")
        v[4]:SetText(ns.Num(s.honorPer))
        v[5]:SetText(string.format("%.1f", s.hkPer))
        v[6]:SetText(tostring(s.bestHK))
        v[7]:SetText(ns.Duration(s.avgDur))
        v[8]:SetText(ns.Duration(s.totalDur))
      else
        c.rate:SetText("")
        for k = 1, 8 do v[k]:SetText("–") end
      end
      -- reputation (whatever the range: it's where you stand now)
      local rep = P.RepForKey(c.def.key)
      if rep then
        local line = rep.name .. " · " .. rep.standing
        if not rep.exalted then
          line = line .. " · " .. (rep.winsLeft and (ns.Plural(rep.winsLeft, "win") .. " to Exalted") or (ns.Num(rep.left) .. " to Exalted"))
        end
        c.repName:SetText(line)
        c.repBar:SetWidth(math.max(1, (c.repBg:GetWidth() or 400) * (rep.exalted and 1 or rep.pct)))
        c.repBar:Show() c.repBg:Show()
      else
        c.repName:SetText("")
        c.repBar:Hide() c.repBg:Hide()
      end
      -- gang: you and everyone who has shared, by win rate
      local rows = {}
      if s and s.played > 0 then
        rows[#rows + 1] = { name = ns.Colorize("You", C.gold), rate = s.rate, played = s.played, hk = s.hkPer, reaction = rep and rep.reaction }
      end
      for pid, p in pairs(ns.db.people or {}) do
        local g = pid ~= ns.pid and p.pvp and p.pvp[c.def.key]
        if g and (g.played or 0) > 0 then
          rows[#rows + 1] = { name = ns:PersonLinked(p, ns:PersonFirst(p)), rate = g.won / g.played, played = g.played, hk = g.hkPer, reaction = g.reaction }
        end
      end
      table.sort(rows, function(a, b) return a.rate > b.rate end)
      for r, line in ipairs(c.gang) do
        local x = rows[r]
        if x then
          line:SetText(x.name .. ns.Colorize("  " .. pct(x.rate) .. " of " .. x.played .. " · " .. string.format("%.1f", x.hk or 0)
            .. " · " .. (STANDING[x.reaction or 0] or "–"), C.dim))
        else
          line:SetText(r == 1 and ns.Colorize("No games recorded yet", C.dim) or "")
        end
      end
    end
  end
  ns:Listen("PVP", function() if tab:IsVisible() then tab:Refresh() end end)
  ns:Listen("PULSE_MODE", function() if tab:IsVisible() then tab:Refresh() end end)
end)
