-- Chillan? – the Now card (1.1.0, Gang pulse): under the four fixed boxes, what matters for what
-- you're doing right now. 1.4.0: one layout per scenario –
--   open world: level bar, this session (+ what you gathered), "Died to" players near you
--   dungeon: next boss + boss track, pace against the gang's best run, deaths and wipes, loot
--   raid: next boss + boss track, the gang here, the gang's loot tonight, your own raid prep
--   battleground: your kills/deaths/streak, the gang's K/D here, this week's honor, wins today
-- and a "moment" that takes over the card for a while: the ding, the end of a run or raid night,
-- the end of a battleground. In combat the boxes and this card fold away (unless pinned).
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex
local N = {}
ns.NowCard = N

local PAD = 10
local MAX_LINES = 6
local MOMENT_SECS = { ding = 20, run = 60, bg = 45 }

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

local function mmss(secs)
  if not secs then return "" end
  if secs >= 3600 then return ns.Duration(secs) end
  return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end

local function dim(t) return ns.Colorize(t, C.dim) end

function N:Create()
  local m = ns.Overlays.minibar
  if not m or self.frame then return end
  local f = CreateFrame("Frame", "ChillanNow", UIParent)
  f:SetFrameStrata("MEDIUM")
  f:SetFrameLevel(m:GetFrameLevel() + 5)
  f:SetSize(330, 60)
  f:EnableMouse(true)
  self.frame = f
  f.head = UI.Text(f, 10, "semi", C.accent)
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
  for i = 1, MAX_LINES do
    local l = UI.Text(f, 11, nil, C.text2)
    l:SetJustifyH("LEFT")
    l:SetWordWrap(false)
    f.lines[i] = l
  end
  -- the boss track: one small block per boss (green = dead, accent = next)
  f.track = CreateFrame("Frame", nil, f)
  f.track:SetHeight(10)
  f.track.blocks = {}
  -- (1.4.2) hover the track: the list of bosses (green = killed, accent = next)
  f.track:EnableMouse(true)
  f.track:SetScript("OnEnter", function(self) GameTooltip:Hide() if ns.Tiles and ns.Tiles.BossList then ns.Tiles:BossList(self) end end)
  f.track:SetScript("OnLeave", function() if ns.Tiles and ns.Tiles.bossFrame then ns.Tiles.bossFrame:Hide() end end)
  f.track:SetScript("OnMouseUp", function() end)
  f.btn = UI.Button(f, 96, 20, "Ready check", "secondary", function() ns.Extras:StartReadyCheck() end)
  f.btn.label:SetFont(ns.FONT_SEMI or ns.FONT, 11, "")
  f.btn.tooltip = "Bags, durability and food/drink for everyone in your group"
  f.btnNote = UI.Text(f, 11, nil, C.dim)
  f:SetScript("OnMouseUp", function(_, btn)
    if N.moment then N.moment = nil N:Update() return end   -- a click closes the moment
    ns.Window:Toggle("stats")
  end)
  f:SetScript("OnEnter", function(self) N:Tooltip(self) end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)

  ns:Listen("PULSE", function() N:Update() end)
  ns:Listen("PULSE_MODE", function() N:Update() if ns.Overlays.UpdateGroup then ns.Overlays:UpdateGroup() end end)
  ns:Listen("DATA", function() N:Update() end)
  ns:Listen("LEVEL_RECAP", function(x) N:Moment("ding", x) end)
  ns:Listen("RUN_CARD", function(x) N:Moment("run", x) end)
  ns:Listen("BG_CARD", function(x) N:Moment("bg", x) end)
  ns:On("PLAYER_REGEN_DISABLED", function() N.inCombat = true N:Relayout() end)
  ns:On("PLAYER_REGEN_ENABLED", function() N.inCombat = false N:Relayout() end)
  C_Timer.NewTicker(2, function() N:Update() end)
  self:Update()
end

function N:Moment(kind, data)
  if not data then return end
  self.moment = { kind = kind, data = data, untilT = GetTime() + (MOMENT_SECS[kind] or 30) }
  self:Update()
end

function N:Relayout()
  if ns.Tiles and ns.Tiles.holder then ns.Tiles:Layout() elseif ns.Overlays.UpdateGroup then ns.Overlays:UpdateGroup() end
end

local function drawTrack(f, list, width)
  local tr = f.track
  for _, b in ipairs(tr.blocks) do b:Hide() end
  if not list or #list == 0 then tr:Hide() return 0 end
  local n = #list
  local bw = math.max(4, math.min(14, math.floor((width + 3) / n) - 3))
  local nextDone = false
  for i, b in ipairs(list) do
    local t = tr.blocks[i]
    if not t then t = tr:CreateTexture(nil, "ARTWORK") tr.blocks[i] = t end
    t:ClearAllPoints()
    t:SetSize(bw, 6)
    t:SetPoint("LEFT", tr, "LEFT", (i - 1) * (bw + 3), 0)
    if b.killed then t:SetColorTexture(hex("5FD18B"))
    elseif not nextDone then nextDone = true t:SetColorTexture(hex(C.accent))
    else t:SetColorTexture(hex(C.active)) end
    t:Show()
  end
  local w = n * (bw + 3) - 3
  tr:SetWidth(w)
  tr:Show()
  return w
end

-- place the parts top-down and size the card
local function place(f, rows, track)
  local y = -8
  local width = f:GetWidth()
  f.head:ClearAllPoints() f.big:ClearAllPoints() f.bigSub:ClearAllPoints() f.right:ClearAllPoints() f.meter:ClearAllPoints()
  f.track:ClearAllPoints()
  if f.head:GetText() and f.head:GetText() ~= "" then
    f.head:SetPoint("TOPLEFT", PAD, y)
    f.head:Show()
    y = y - 15
  else
    f.head:Hide()
  end
  if f.big:GetText() and f.big:GetText() ~= "" then
    f.big:SetPoint("TOPLEFT", PAD, y)
    f.bigSub:SetPoint("BOTTOMLEFT", f.big, "BOTTOMRIGHT", 6, 2)
    f.bigSub:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    f.bigSub:SetJustifyH("LEFT")
    f.bigSub:SetWordWrap(false)
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
  local trackW = 0
  if track then trackW = drawTrack(f, track, math.floor((width - 2 * PAD) * 0.45)) else drawTrack(f, nil) end
  for i, l in ipairs(f.lines) do
    l:ClearAllPoints()
    if rows[i] then
      l:SetPoint("TOPLEFT", PAD, y)
      -- the first line shares its row with the boss track
      if i == 1 and trackW > 0 then
        f.track:SetPoint("RIGHT", f, "TOPRIGHT", -PAD, y - 6)
        l:SetPoint("RIGHT", f.track, "LEFT", -8, 0)
      else
        l:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
      end
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

---------------------------------------------------------------------------
-- the moments
---------------------------------------------------------------------------
local function momentRows(f, mo)
  local x, rows = mo.data, {}
  if mo.kind == "ding" then
    f.head:SetText("DING! LEVEL " .. tostring(x.to or "?"))
    f.head:SetTextColor(hex("E0B04F"))
    f.big:SetText(x.time and ns.Duration(x.time) or "–")
    f.bigSub:SetText("for level " .. tostring(x.from or "?") .. (x.vsPrev and (x.vsPrev < 0 and (" · " .. ns.Duration(-x.vsPrev) .. " faster than the last") or "") or ""))
    local bits = {}
    if (x.quests or 0) > 0 then bits[#bits + 1] = ns.Plural(x.quests, "quest") end
    if (x.money or 0) > 0 then bits[#bits + 1] = goldText(x.money) end
    bits[#bits + 1] = ns.Plural(x.deaths or 0, "death")
    if x.xph then bits[#bits + 1] = ns.Num(x.xph) .. " XP/h" end
    rows[#rows + 1] = table.concat(bits, dim(" · "))
    if x.rank and x.rank.of and x.rank.of > 1 then
      rows[#rows + 1] = (x.rank.place == 1 and ns.Colorize("Fastest in the gang for this level", C.green)
        or ("No. " .. x.rank.place .. " of " .. x.rank.of .. " in the gang for this level"))
    end
    rows[#rows + 1] = dim("The gang can react in the feed · click to close")
  elseif mo.kind == "run" then
    local head = x.raid and ("RAID NIGHT · " .. tostring(x.name):upper()) or "RUN DONE"
    if x.record then head = head .. " · NEW GANG RECORD" end
    f.head:SetText(head)
    f.head:SetTextColor(hex(x.raid and "F0A060" or "8FB8E8"))
    f.big:SetText(ns.Duration(x.dur or 0))
    f.bigSub:SetText(x.bosses .. " / " .. (x.total or "?") .. " bosses" .. ((x.best and x.record) and (" · old record " .. ns.Duration(x.best)) or (x.best and (" · gang best " .. ns.Duration(x.best)) or "")))
    local bits = {}
    if (x.xp or 0) > 0 then bits[#bits + 1] = ns.Num(x.xp) .. " XP" end
    if (x.value or 0) > 0 then bits[#bits + 1] = goldText(x.value) .. " loot" end
    bits[#bits + 1] = ns.Plural(x.deaths or 0, "death")
    bits[#bits + 1] = ns.Plural(x.wipes or 0, "wipe")
    rows[#rows + 1] = table.concat(bits, dim(" · "))
    if x.drop then rows[#rows + 1] = dim("Best drop  ") .. x.drop end
    if x.raid and x.gangLoot and #x.gangLoot > 0 then rows[#rows + 1] = dim("Gang epics  ") .. #x.gangLoot end
    if x.floor and (x.floorN or 0) > 0 then rows[#rows + 1] = dim(x.raid and "Lava enjoyer  " or "Floor inspector  ") .. x.floor .. dim("  " .. ns.Plural(x.floorN, "death")) end
    if x.fast then rows[#rows + 1] = dim("Fastest boss  ") .. x.fast .. dim("  " .. mmss(x.fastSecs)) end
  elseif mo.kind == "bg" then
    f.head:SetText((x.won and "VICTORY" or "DEFEAT") .. (x.score and (" · " .. x.score) or "") .. " · " .. math.floor((x.dur or 0) / 60) .. " MIN")
    f.head:SetTextColor(hex(x.won and "5FD18B" or "F2777A"))
    f.big:SetText(x.honor and ("+" .. ns.Num(x.honor)) or "–")
    f.bigSub:SetText("honor · " .. (x.wonToday or 0) .. " / " .. (x.played or 0) .. " won today")
    if x.mvp then rows[#rows + 1] = dim("Gang MVP  ") .. x.mvp.name .. dim("  " .. x.mvp.hk .. " HKs · " .. ns.Plural(x.mvp.deaths, "death")) end
    if x.hero and x.heroFlags then
      local fl = {}
      if x.heroFlags.cap > 0 then fl[#fl + 1] = ns.Plural(x.heroFlags.cap, "capture") end
      if x.heroFlags.ret > 0 then fl[#fl + 1] = ns.Plural(x.heroFlags.ret, "return") end
      rows[#rows + 1] = dim("Flag hero  ") .. x.hero .. dim("  " .. table.concat(fl, ", "))
    end
    if x.revs and #x.revs > 0 then rows[#rows + 1] = dim("Revenge  ") .. ns.Colorize(table.concat(x.revs, ", "), C.green) end
    local chips = {}
    if (x.streak or 0) > 1 then chips[#chips + 1] = "win streak " .. x.streak end
    if (x.best or 0) > 1 then chips[#chips + 1] = "best kill streak " .. x.best end
    if #chips > 0 then rows[#rows + 1] = table.concat(chips, dim(" · ")) end
  end
  return rows
end

---------------------------------------------------------------------------
-- raid prep: your own fire resist (Molten Core), flask, and the raids you're saved to
---------------------------------------------------------------------------
local function savedTo()
  local out = {}
  if not GetNumSavedInstances or not GetSavedInstanceInfo then return out end
  local ok, n = pcall(GetNumSavedInstances)
  if not ok or type(n) ~= "number" then return out end
  for i = 1, n do
    local ok2, name, _, _, _, locked = pcall(GetSavedInstanceInfo, i)
    if ok2 and locked and type(name) == "string" then out[#out + 1] = ns.ShortDungeonPlain and ns.ShortDungeonPlain(name) or name end
  end
  return out
end
local function hasFlask()
  if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return nil end
  for i = 1, 40 do
    local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
    if not ok or not a then break end
    local nm = a.name
    if type(nm) == "string" and not ns.isSecret(nm) and nm:find("Flask") then return true end
  end
  return false
end

function N:Update()
  local f = self.frame
  if not f or not f:IsShown() then return end
  local P = ns.Pulse
  local mode = P:Mode()
  local rows, track = {}, nil
  f.meter.pct, f.showBtn = nil, false
  f.head:SetText("") f.big:SetText("") f.bigSub:SetText("") f.right:SetText("")
  f.head:SetTextColor(hex(C.accent))
  local dg = P:Danger()

  if self.moment and GetTime() > self.moment.untilT then self.moment = nil end
  if self.moment then
    rows = momentRows(f, self.moment)

  elseif mode == "world" then
    local d = ns.Tracker:S3Data() or {}
    local c = ns.Tracker:MyChar() or {}
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
    if P.AtMax and P.AtMax() then
      -- (1.4.17) level 60: PvP rank progress up top, and a session line about honor, rep and bosses
      local rank, rname, prog = P:Rank()
      if rank or prog then
        f.big:SetText(rank and ("Rank " .. rank) or (math.floor((prog or 0) * 100) .. " %"))
        f.bigSub:SetText(rname or "PvP rank")
        if prog then
          f.meter.pct = prog
          f.right:SetText(math.floor(prog * 100) .. " % to rank " .. ((rank or 0) + 1))
        end
      else
        f.big:SetText("60")
        f.bigSub:SetText("max level")
      end
      local hk, honor = P:SessionHonor()
      local fac, repN = P:TopRep()
      local bits = {}
      if (hk or 0) > 0 or (honor or 0) > 0 then bits[#bits + 1] = ns.Num(hk or 0) .. " HKs · " .. ns.Num(honor or 0) .. " honor" end
      if fac then bits[#bits + 1] = "+" .. ns.Num(repN) .. " " .. fac:gsub("^The ", "") end
      if (s.bosses or 0) > 0 then bits[#bits + 1] = ns.Plural(s.bosses, "boss", "bosses") end
      if gold and gold ~= 0 then bits[#bits + 1] = ns.Colorize(goldText(gold), gold > 0 and C.text2 or C.red) end
      if #bits == 0 then bits[1] = s.quests .. " quests · " .. s.mobs .. " mobs" end
      rows[#rows + 1] = dim("This session: ") .. table.concat(bits, " · ")
    else
    local rested = ns.Pct(d.rested or 0, d.xpMax)
    rows[#rows + 1] = dim("This session: ") .. s.quests .. " quests · " .. s.mobs .. " mobs"
      .. (gold and gold ~= 0 and (" · " .. ns.Colorize(goldText(gold), gold > 0 and C.text2 or C.red)) or "")
      .. ((rested and rested > 0 and f.meter.pct) and dim("   rested " .. rested .. " %") or "")
    end
    -- (1.4.0) what you gathered, with its Market value
    local g = s.gather
    if g and g.n > 0 then
      rows[#rows + 1] = dim("Gathered: ") .. ns.Num(g.n) .. (g.value > 0 and (dim("  ≈ ") .. goldText(g.value)) or "")
    end
    if dg then
      rows[#rows + 1] = ns.Colorize("! " .. dg.name .. " nearby", C.red) .. dim("  killed the gang " .. dg.n .. "× · revenge counts")
    end

  elseif mode == "dungeon" or mode == "raid" then
    local r, pr = P:Run()
    if r then
      local n, total, list = ns.Bosses:Count(r.name, r.killed)
      track = {}
      for _, b in ipairs(list) do if b.killed or not b.opt then track[#track + 1] = b end end
      local nextB = ns.Bosses:Next(r.name, r.killed)
      if ns.Extras.inEncounter then
        rows[#rows + 1] = ns.Colorize("Boss fight", C.amber) .. dim("  · gang news waits until it's dead")
      elseif nextB then
        rows[#rows + 1] = dim("Next  ") .. ns.Colorize(nextB, C.text)
      else
        rows[#rows + 1] = n > 0 and ns.Colorize("All bosses down", C.green) or dim("No boss yet")
      end
      if mode == "dungeon" then
        -- pace against the gang's best run here
        local best = ns.Extras:BestFor(r.name, "DUNGEON")
        if best and total and total > 0 and n > 0 then
          local diff = math.floor(best * n / total - (ns.Now() - r.start))
          rows[#rows + 1] = dim("Pace  ") .. (diff >= 0 and ns.Colorize(ns.Duration(diff) .. " ahead", C.green) or ns.Colorize(ns.Duration(-diff) .. " behind", C.amber))
            .. dim("  of the gang's best (" .. ns.Duration(best) .. ")")
        end
      else
        local gang = ns.Extras.GangInGroup and ns.Extras.GangInGroup() or {}
        local size = ns.S(GetNumGroupMembers) or 0
        rows[#rows + 1] = dim("Gang here  ") .. #gang .. (size > 0 and dim(" of " .. size) or "")
        local gl = r.gangLoot or {}
        if #gl > 0 then
          local who, seen = {}, {}
          for _, g in ipairs(gl) do if not seen[g.who] then seen[g.who] = true who[#who + 1] = g.who end end
          rows[#rows + 1] = dim("Gang loot tonight  ") .. ns.Colorize(ns.Plural(#gl, "epic"), "A335EE") .. dim("  · " .. table.concat(who, ", "))
        end
      end
      -- deaths and wipes: the funny bit
      local most, mostN = nil, 0
      for name, k in pairs(r.deathsBy or {}) do if k > mostN then most, mostN = name, k end end
      rows[#rows + 1] = dim("Deaths  ") .. (r.deaths or 0) .. ((most and mostN > 1) and dim("  · most: ") .. most .. " " .. mostN or "")
        .. dim("   ·   wipes ") .. (r.wipes or 0)
    end
    if mode == "dungeon" then
      local q = { [2] = "1EFF00", [3] = "0070DD", [4] = "A335EE", [5] = "FF8000" }
      local pips, k = {}, 0
      for _, link in ipairs(pr and pr.items or {}) do
        local qq = P.LinkQuality(link)
        if q[qq] and k < 8 then
          k = k + 1
          local rr, gg, bb = hex(q[qq])
          pips[#pips + 1] = string.format("|T%sCircle:9:9:0:0:64:64:0:64:0:64:%d:%d:%d|t", ns.TEX, rr * 255, gg * 255, bb * 255)
        end
      end
      if k > 0 or (pr and pr.grey > 0) then
        rows[#rows + 1] = dim("Loot  ") .. table.concat(pips, "") .. ((pr and pr.grey > 0) and dim("  +" .. pr.grey .. " grey") or "") .. dim("  · hover for the list")
      end
    else
      -- your own raid prep
      local prep = {}
      if r and tostring(r.name):find("Molten") and UnitResistance then
        local ok, _, total = pcall(UnitResistance, "player", 2)
        if ok and type(total) == "number" and not ns.isSecret(total) then prep[#prep + 1] = "fire resist " .. total end
      end
      if (ns.S(UnitLevel, "player") or 0) >= 60 then
        local fl = hasFlask()
        if fl == false then prep[#prep + 1] = ns.Colorize("no flask", C.amber) elseif fl then prep[#prep + 1] = ns.Colorize("flask", C.green) end
      end
      local saved = savedTo()
      if #saved > 0 then prep[#prep + 1] = "saved: " .. table.concat(saved, ", ") end
      if #prep > 0 then rows[#rows + 1] = dim("You  ") .. table.concat(prep, dim(" · ")) end
    end
    -- your own bags and durability, only when low
    local warn = {}
    local free = freeBags()
    if free < 4 then warn[#warn + 1] = ns.Colorize(free .. " bag slot" .. (free == 1 and "" or "s") .. " left", C.red) end
    local dura = ns.Durability and ns.Durability()
    if dura and dura < 50 then warn[#warn + 1] = ns.Colorize(math.floor(dura) .. " % durability", dura < 20 and C.red or C.amber) end
    if #warn > 0 then rows[#rows + 1] = table.concat(warn, dim("   ·   ")) end
    if mode == "dungeon" then
      f.showBtn = true
      f.btnNote:SetText((r and r.lastBoss) and ("Last boss: " .. r.lastBoss) or "")
    end

  elseif mode == "bg" then
    local b = P.bg
    local kills = P:BGNumbers()
    local me = b and b.me
    local hk = me and me.hk or kills
    f.big:SetText(hk and tostring(hk) or "–")
    f.bigSub:SetText("kills  ·  " .. ns.Plural((me and me.deaths) or (b and b.deaths) or 0, "death"))
    f.right:SetText((b and b.streak > 0) and ns.Colorize("streak " .. b.streak, C.green) or "")
    -- the gang in this battleground, from the scoreboard
    local gang = b and b.gang or {}
    if #gang > 0 then
      local parts = {}
      for i, g in ipairs(gang) do
        if i <= 4 then parts[#parts + 1] = g.name .. dim(" " .. g.hk .. "/" .. g.deaths) end
      end
      rows[#rows + 1] = dim("Gang here  ") .. table.concat(parts, "  ")
    end
    local t = P.Today()
    rows[#rows + 1] = dim("Today  ") .. t.won .. " / " .. t.played .. " won · " .. ns.Num(t.honor) .. " honor"
      .. (((t.streak or 0) > 1) and ns.Colorize("   win streak " .. t.streak, C.green) or "")
    local wk, rank, prog = P:Week()
    if wk or rank then
      rows[#rows + 1] = dim("This week  ") .. (wk and (ns.Num(wk) .. " honor") or "")
        .. (rank and (dim(" · ") .. rank .. (prog and dim(" " .. prog .. " %") or "")) or "")
    end
    if dg then rows[#rows + 1] = ns.Colorize("Revenge: " .. dg.name .. " is here", C.green) .. dim("  killed the gang " .. dg.n .. "×") end
  end
  place(f, rows, track)
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
  if mode == "dungeon" or mode == "raid" then
    GameTooltip:AddLine("Next boss, the boss track (green = killed, bright = next – hover it for the list), deaths and wipes", 0.6, 0.63, 0.66, true)
  end
  if mode == "dungeon" or mode == "raid" then
    local r, pr = P:Run()
    if pr and #pr.items > 0 then
      GameTooltip:AddLine("Loot this run", 0.6, 0.63, 0.66)
      for i = #pr.items, math.max(1, #pr.items - 9), -1 do GameTooltip:AddLine(pr.items[i]) end
    end
    if r and r.gangLoot and #r.gangLoot > 0 then
      GameTooltip:AddLine("Gang epics", 0.6, 0.63, 0.66)
      for i = #r.gangLoot, math.max(1, #r.gangLoot - 9), -1 do GameTooltip:AddDoubleLine(r.gangLoot[i].link, r.gangLoot[i].who, 1, 1, 1, 0.6, 0.63, 0.66) end
    end
    if r then
      local most = {}
      for name, k in pairs(r.deathsBy or {}) do most[#most + 1] = { name = name, k = k } end
      table.sort(most, function(a, b) return a.k > b.k end)
      if #most > 0 then
        GameTooltip:AddLine("Deaths", 0.6, 0.63, 0.66)
        for i = 1, math.min(5, #most) do GameTooltip:AddDoubleLine(most[i].name, tostring(most[i].k), 1, 1, 1, 1, 1, 1) end
      end
    end
  elseif mode == "world" then
    local d = ns.Tracker:S3Data() or {}
    GameTooltip:AddLine("Session " .. ns.Duration(d.sessSec or 0), 0.6, 0.63, 0.66)
  end
  GameTooltip:AddLine(N.moment and "Click: close" or "Click: the Stats page", 0.52, 0.55, 0.57)
  GameTooltip:Show()
end
