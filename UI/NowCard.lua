-- Chillan? – the Now card (1.1.0, Gang pulse): under the four fixed boxes, what matters for what
-- you're doing right now. Open world: time to level, this session, "Died to" players near you.
-- Dungeon: loot this run, your own bags/durability when low, Ready check. Battleground: kills,
-- deaths, streak, honor today. In combat the boxes and this card fold away (unless pinned).
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex
local N = {}
ns.NowCard = N

local PAD = 10

function N:Collapsed()
  return self.inCombat and not ns.db.settings.pulsePin
end

local function goldText(copper)
  if not copper then return "–" end
  local neg = copper < 0
  copper = math.abs(copper)
  local g, s = math.floor(copper / 10000), math.floor((copper % 10000) / 100)
  local t = g > 0 and (ns.Num(g) .. "g " .. s .. "s") or (s .. "s " .. (copper % 100) .. "c")
  return (neg and "−" or "") .. t
end

local function freeBags()
  local free = 0
  local api = C_Container
  for bag = 0, 4 do
    local ok, f = pcall(api and api.GetContainerNumFreeSlots or GetContainerNumFreeSlots, bag)
    if ok and type(f) == "number" and not ns.isSecret(f) then free = free + f end
  end
  return free
end

function N:Create()
  local m = ns.Overlays.minibar
  if not m or self.frame then return end
  local f = CreateFrame("Frame", "ChillanNow", UIParent)
  f:SetFrameStrata("MEDIUM")
  f:SetFrameLevel(m:GetFrameLevel() + 5)
  f:SetSize(330, 60)
  f:EnableMouse(true)
  self.frame = f
  f.big = UI.Text(f, 18, "bold", C.text)
  f.bigSub = UI.Text(f, 11, nil, C.muted)
  f.right = UI.Text(f, 11, nil, C.muted)
  f.right:SetJustifyH("RIGHT")
  f.meter = CreateFrame("Frame", nil, f)
  f.meter:SetHeight(5)
  f.meter.bg = f.meter:CreateTexture(nil, "ARTWORK")
  f.meter.bg:SetAllPoints()
  UI.Track(f.meter.bg):SetColorTexture(hex(C.active))
  f.meter.fill = f.meter:CreateTexture(nil, "OVERLAY")
  f.meter.fill:SetPoint("TOPLEFT")
  f.meter.fill:SetPoint("BOTTOMLEFT")
  UI.Track(f.meter.fill):SetColorTexture(hex(C.accent))
  f.lines = {}
  for i = 1, 3 do
    local l = UI.Text(f, 11, nil, C.text2)
    l:SetJustifyH("LEFT")
    l:SetWordWrap(false)
    f.lines[i] = l
  end
  f.btn = UI.Button(f, 96, 20, "Ready check", "secondary", function() ns.Extras:StartReadyCheck() end)
  f.btn.label:SetFont(ns.FONT_SEMI or ns.FONT, 11, "")
  f.btn.tooltip = "Bags, durability and food/drink for everyone in your group"
  f.btnNote = UI.Text(f, 11, nil, C.dim)
  f:SetScript("OnMouseUp", function() ns.Window:Toggle("stats") end)
  f:SetScript("OnEnter", function(self) N:Tooltip(self) end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)

  ns:Listen("PULSE", function() N:Update() end)
  ns:Listen("PULSE_MODE", function() N:Update() if ns.Overlays.UpdateGroup then ns.Overlays:UpdateGroup() end end)
  ns:Listen("DATA", function() N:Update() end)
  ns:On("PLAYER_REGEN_DISABLED", function() N.inCombat = true N:Relayout() end)
  ns:On("PLAYER_REGEN_ENABLED", function() N.inCombat = false N:Relayout() end)
  C_Timer.NewTicker(2, function() N:Update() end)
  self:Update()
end

function N:Relayout()
  if ns.Tiles and ns.Tiles.holder then ns.Tiles:Layout() elseif ns.Overlays.UpdateGroup then ns.Overlays:UpdateGroup() end
end

-- place the parts top-down and size the card
local function place(f, rows)
  local y = -8
  local width = f:GetWidth()
  f.big:ClearAllPoints() f.bigSub:ClearAllPoints() f.right:ClearAllPoints() f.meter:ClearAllPoints()
  if f.big:GetText() and f.big:GetText() ~= "" then
    f.big:SetPoint("TOPLEFT", PAD, y)
    f.bigSub:SetPoint("BOTTOMLEFT", f.big, "BOTTOMRIGHT", 6, 2)
    f.right:SetPoint("TOPRIGHT", -PAD, y - 5)
    y = y - 24
    f.big:Show() f.bigSub:Show() f.right:Show()
  else
    f.big:Hide() f.bigSub:Hide() f.right:Hide()
  end
  if f.meter.pct then
    f.meter:SetPoint("TOPLEFT", PAD, y)
    f.meter:SetPoint("TOPRIGHT", -PAD, y)
    f.meter.fill:SetWidth(math.max(1, (width - 2 * PAD) * math.min(1, f.meter.pct)))
    f.meter:Show()
    y = y - 11
  else
    f.meter:Hide()
  end
  for i, l in ipairs(f.lines) do
    l:ClearAllPoints()
    if rows[i] then
      l:SetPoint("TOPLEFT", PAD, y)
      l:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
      l:SetText(rows[i])
      l:Show()
      y = y - 17
    else
      l:Hide()
    end
  end
  f.btn:ClearAllPoints() f.btnNote:ClearAllPoints()
  if f.showBtn then
    f.btn:SetPoint("TOPLEFT", PAD, y - 1)
    f.btnNote:SetPoint("LEFT", f.btn, "RIGHT", 8, 0)
    f.btnNote:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    f.btnNote:SetJustifyH("LEFT")
    f.btn:Show() f.btnNote:Show()
    y = y - 25
  else
    f.btn:Hide() f.btnNote:Hide()
  end
  f:SetHeight(-y + 6)
end

function N:Update()
  local f = self.frame
  if not f or not f:IsShown() then return end
  local P = ns.Pulse
  local mode = P:Mode()
  local rows = {}
  f.meter.pct, f.showBtn = nil, false
  f.big:SetText("") f.bigSub:SetText("") f.right:SetText("")
  local dg = P:Danger()
  local function dangerRow()
    if dg then
      return ns.Colorize("! " .. dg.name .. " nearby", C.red) .. ns.Colorize("  killed the gang " .. dg.n .. "× · revenge counts", C.dim)
    end
  end

  if mode == "world" then
    local d = ns.Tracker:S3Data() or {}
    local c = ns.Tracker:MyChar() or {}
    local eta = ns.St and ns.St:ETA(ns:GetPerson(ns.pid, true))
    local lvl = ns.S(UnitLevel, "player") or c.level or 0
    local maxLvl = 60   -- WoW Forever caps at 60 (the engine may report a higher cap)
    if type(lvl) == "number" and lvl < maxLvl then
      local pct = (d.xp and d.xpMax and d.xpMax > 0) and math.floor(d.xp / d.xpMax * 100) or nil
      f.big:SetText(pct and (pct .. " %") or "–")
      f.bigSub:SetText("of level " .. (c.level or "?"))
      -- (1.1.6) the XP left, not a guess at quests
      local left = (d.xp and d.xpMax) and (d.xpMax - d.xp) or nil
      f.right:SetText(left and (ns.Num(left) .. " XP left") or "")
      if d.xp and d.xpMax and d.xpMax > 0 then f.meter.pct = d.xp / d.xpMax end
    end
    local s = P.sess
    local gold = P:SessionGold()
    local rested = ns.Pct(d.rested or 0, d.xpMax)
    rows[#rows + 1] = ns.Colorize("This session: ", C.dim) .. s.quests .. " quests · " .. s.mobs .. " mobs"
      .. (gold and gold ~= 0 and (" · " .. ns.Colorize(goldText(gold), gold > 0 and C.text2 or C.red)) or "")
      .. ((rested and rested > 0 and f.meter.pct) and ns.Colorize("   rested " .. rested .. " %", C.dim) or "")
    rows[#rows + 1] = dangerRow()

  elseif mode == "dungeon" then
    local r, pr = P:Run()
    local q = { [2] = "1EFF00", [3] = "0070DD", [4] = "A335EE", [5] = "FF8000" }
    local pips, n = {}, 0
    for _, link in ipairs(pr and pr.items or {}) do
      local qq = P.LinkQuality(link)
      if q[qq] and n < 8 then
        n = n + 1
        local r, g, b = hex(q[qq])
        pips[#pips + 1] = string.format("|T%sCircle:9:9:0:0:64:64:0:64:0:64:%d:%d:%d|t", ns.TEX, r * 255, g * 255, b * 255)
      end
    end
    rows[#rows + 1] = ns.Colorize("Loot  ", C.dim) .. goldText(pr and pr.money or 0) .. "  " .. table.concat(pips, "")
      .. ((pr and pr.grey > 0) and ns.Colorize("  +" .. pr.grey .. " grey", C.dim) or "")
    -- your own bags and durability, only when low
    local warn = {}
    local free = freeBags()
    if free < 4 then warn[#warn + 1] = ns.Colorize(free .. " bag slot" .. (free == 1 and "" or "s") .. " left", C.red) end
    local dura = ns.Durability and ns.Durability()
    if dura and dura < 50 then warn[#warn + 1] = ns.Colorize(math.floor(dura) .. " % durability", dura < 20 and C.red or C.amber) end
    if #warn > 0 then rows[#rows + 1] = table.concat(warn, ns.Colorize("   ·   ", C.dim)) end
    f.showBtn = true
    f.btnNote:SetText((r and r.lastBoss) and ("Last boss: " .. r.lastBoss) or ((r and r.deaths and r.deaths > 0) and (r.deaths .. " deaths this run") or ""))

  elseif mode == "bg" then
    local b = P.bg
    local kills = P:BGNumbers()
    f.big:SetText(kills and tostring(kills) or "–")
    f.bigSub:SetText("kills  ·  " .. (b and b.deaths or 0) .. " deaths")
    f.right:SetText((b and b.streak > 0) and ns.Colorize("streak " .. b.streak, C.green) or "")
    local t = P.Today()
    rows[#rows + 1] = ns.Colorize("Today: ", C.dim) .. ns.Num(t.honor) .. " honor · " .. t.played .. " played"
      .. ((b and b.best > 1) and ns.Colorize("   best streak " .. b.best, C.dim) or "")
    if dg then rows[#rows + 1] = ns.Colorize(dg.name .. " is here – revenge!", C.green) .. ns.Colorize("  killed the gang " .. dg.n .. "×", C.dim) end
  end
  place(f, rows)
  if self.lastH ~= math.floor(f:GetHeight()) then
    self.lastH = math.floor(f:GetHeight())
    if ns.Overlays.UpdateGroup then ns.Overlays:UpdateGroup() end
  end
end

function N:Tooltip(owner)
  local P = ns.Pulse
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  local mode = P:Mode()
  GameTooltip:AddLine(P.MODES[mode] .. (mode ~= "world" and (" · " .. P:Place()) or ""), 1, 1, 1)
  if mode == "dungeon" then
    local r, pr = P:Run()
    if pr and #pr.items > 0 then
      GameTooltip:AddLine("Loot this run", 0.6, 0.63, 0.66)
      for i = #pr.items, math.max(1, #pr.items - 9), -1 do GameTooltip:AddLine(pr.items[i]) end
    end
    if r then GameTooltip:AddLine(r.bosses .. " bosses · " .. (r.deaths or 0) .. " deaths", 0.6, 0.63, 0.66) end
  elseif mode == "world" then
    local d = ns.Tracker:S3Data() or {}
    GameTooltip:AddLine("Session " .. ns.Duration(d.sessSec or 0), 0.6, 0.63, 0.66)
  end
  GameTooltip:AddLine("Click: the Stats page", 0.52, 0.55, 0.57)
  GameTooltip:Show()
end
