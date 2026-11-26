-- Chillan? – loot rolls (1.4.74: rethought)
-- One Loot rolls section that grows out of the bottom of Pulse while something is being rolled for.
-- One row per item: icon, name, a thin bar that fills with Need (green), Greed (gold) and Pass (grey),
-- the counts, your own pick and the time left. Hover a row for who picked what (gang first, at most 8
-- names). When it's decided the row is one line ("Eirik wins · Need 87") for 20 s, then it goes to
-- "last 5". The game's own roll window stays where it always is: you still click there.
--
-- Where the picks come from: this client keeps them in the loot history list
-- (C_LootHistory.GetSortedInfoForDrop, LOOT_HISTORY_UPDATE_DROP) – the chat only has your own lines, so
-- 1.4.72/73 never saw the others. Without that list (older clients) the chat lines are still read.
-- When Pulse is closed the same section stands on its own as a small movable strip.
-- /chill need shows a test roll; /chill rolls shows the last 5.
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex
local secret, S = ns.U.Secret, ns.U.Settings
local norm = ns.U.NormName

local R = {}
ns.LootRolls = R
R.drops = {}        -- open (and just finished) items, oldest first
R.history = {}      -- the last 5 finished, newest first
R.rolls = R.drops   -- (old name, kept for callers)

local NEED, GREED, PASS = "5FD18B", "E0B04F", "858B92"
local CHOICE_COL = { Need = NEED, Greed = GREED, Pass = PASS, Disenchant = "B9AEDB", Transmog = "B9AEDB" }
local CHOICE_ORDER = { Need = 1, Greed = 2, Transmog = 2, Disenchant = 3, Pass = 4 }
local ROW_H, DONE_H, LINE_H, MAX_NAMES, KEEP_DONE = 42, 22, 16, 8, 20
local FREE_W = 300

local function safe(v) if v == nil or secret(v) then return nil end return v end
-- the Need addon shows the same thing in its own roll windows: Chillan's stays off while it's on
local function needAddon()
  local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  if not loaded then return false end
  for _, n in ipairs({ "Need", "NeedRolls" }) do
    local ok, v = pcall(loaded, n)
    if ok and v then return true end
  end
  return false
end
R.NeedAddon = needAddon
local function on() return S().lootRolls ~= false and not needAddon() end
local function itemId(link) return type(link) == "string" and link:match("item:(%d+)") or nil end
local function me() return safe(UnitName("player")) or "?" end
-- "Kenny-Realm" / "Gumi Megpoid" → how it's shown and how it's matched
local function shown(name) return (tostring(name or "?"):gsub("%-.*$", "")) end
local function first(name) return norm((tostring(name or ""):match("^(%S+)")) or "") end
local function same(a, b) return a and b and (norm(a) == norm(b) or first(a) == first(b)) end
local function isMe(name) return same(name, me()) end
local function big() return (GetNumGroupMembers and GetNumGroupMembers() or 0) > 5 end

---------------------------------------------------------------------------
-- the loot history list (this client)
---------------------------------------------------------------------------
local function hasHistory() return C_LootHistory and C_LootHistory.GetSortedInfoForDrop and true or false end
local STATE_CHOICE
local function choiceOf(state)
  if state == nil or secret(state) then return nil end
  if not STATE_CHOICE then
    local E = Enum and Enum.EncounterLootDropRollState or {}
    STATE_CHOICE = {}
    if E.NeedMainSpec then STATE_CHOICE[E.NeedMainSpec] = "Need" end
    if E.NeedOffSpec then STATE_CHOICE[E.NeedOffSpec] = "Need" end
    if E.Transmog then STATE_CHOICE[E.Transmog] = "Transmog" end
    if E.Greed then STATE_CHOICE[E.Greed] = "Greed" end
    if E.Pass then STATE_CHOICE[E.Pass] = "Pass" end
    -- (no NoRoll: still choosing)
  end
  return STATE_CHOICE[state]
end

local function newDrop(key, link)
  local d = { key = key, link = link, item = itemId(link), players = {}, startedAt = GetTime() }
  R.drops[#R.drops + 1] = d
  return d
end
local function findDrop(key)
  for _, d in ipairs(R.drops) do if d.key == key or d.hkey == key or d.rollID == key then return d end end
end
-- the open drop with this item that isn't tied to another source yet
local function unclaimed(item, field)
  for _, d in ipairs(R.drops) do
    if d.item == item and not d.done and not d[field] and not d.test then return d end
  end
end

local function player(d, who)
  for _, p in ipairs(d.players) do if same(p.name, who) then return p end end
  local p = { name = who, order = #d.players + 1 }
  d.players[#d.players + 1] = p
  return p
end

function R:FromHistory(encounterID, listID)
  encounterID, listID = safe(encounterID), safe(listID)
  if encounterID == nil or listID == nil or not hasHistory() then return end
  local ok, info = pcall(C_LootHistory.GetSortedInfoForDrop, encounterID, listID)
  if not ok or type(info) ~= "table" then return end
  local link = safe(info.itemHyperlink)
  if type(link) ~= "string" then return end
  local hkey = "h" .. tostring(encounterID) .. ":" .. tostring(listID)
  local d = findDrop(hkey)
  if not d then
    if S().lootRollsBig == false and big() then return end
    d = unclaimed(itemId(link), "hkey") or newDrop(hkey, link)
    d.hkey = hkey
  end
  d.link = link
  local list = {}
  for i, ri in ipairs(info.rollInfos or {}) do
    local name = safe(ri.playerName)
    if type(name) == "string" and name ~= "" then
      list[#list + 1] = { name = name, class = safe(ri.playerClass), choice = choiceOf(ri.state),
        roll = tonumber(safe(ri.roll)), won = safe(ri.isWinner) == true, order = i }
    end
  end
  if #list > 0 then
    -- keep when each pick came in, so "while rolling" can list them in that order
    for _, p in ipairs(list) do
      local old
      for _, q in ipairs(d.players) do if same(q.name, p.name) then old = q end end
      p.at = (old and old.at) or (p.choice and GetTime()) or nil
    end
    d.players = list
  end
  local winner = info.winner and safe(info.winner.playerName)
  if winner or safe(info.allPassed) == true then
    R:Finish(d, winner)
  else
    R:Refresh()
  end
end

---------------------------------------------------------------------------
-- the chat lines (fallback for clients without the history list)
---------------------------------------------------------------------------
local function pat(fmt)
  if type(fmt) ~= "string" or fmt == "" then return nil end
  local p = fmt:gsub("%%%d?%$?([sd])", function(kind) return "\001" .. kind end)
  p = p:gsub("[%%%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
  p = p:gsub("\001s", "(.+)"):gsub("\001d", "(%%d+)")
  return "^" .. p .. "$"
end
local LINES = {
  { "LOOT_ROLL_NEED", "%s has selected Need for: %s", "Need", { "who", "item" } },
  { "LOOT_ROLL_GREED", "%s has selected Greed for: %s", "Greed", { "who", "item" } },
  { "LOOT_ROLL_DISENCHANT", "%s has selected Disenchant for: %s", "Disenchant", { "who", "item" } },
  { "LOOT_ROLL_PASSED", "%s passed on: %s", "Pass", { "who", "item" } },
  { "LOOT_ROLL_PASSED_AUTO", "%s automatically passed on: %s because he cannot loot that item.", "Pass", { "who", "item" } },
  { "LOOT_ROLL_PASSED_AUTO_FEMALE", "%s automatically passed on: %s because she cannot loot that item.", "Pass", { "who", "item" } },
  { "LOOT_ROLL_NEED_SELF", "You have selected Need for: %s", "Need", { "item" }, true },
  { "LOOT_ROLL_GREED_SELF", "You have selected Greed for: %s", "Greed", { "item" }, true },
  { "LOOT_ROLL_DISENCHANT_SELF", "You have selected Disenchant for: %s", "Disenchant", { "item" }, true },
  { "LOOT_ROLL_PASSED_SELF", "You passed on: %s", "Pass", { "item" }, true },
  { "LOOT_ROLL_PASSED_SELF_AUTO", "You automatically passed on: %s because you cannot loot that item.", "Pass", { "item" }, true },
  { "LOOT_ROLL_ROLLED_NEED", "Need Roll - %d for %s by %s", "roll", { "roll", "item", "who" } },
  { "LOOT_ROLL_ROLLED_GREED", "Greed Roll - %d for %s by %s", "roll", { "roll", "item", "who" } },
  { "LOOT_ROLL_ROLLED_DE", "Disenchant Roll - %d for %s by %s", "roll", { "roll", "item", "who" } },
  { "LOOT_ROLL_WON", "%s won: %s", "won", { "who", "item" } },
  { "LOOT_ROLL_YOU_WON", "You won: %s", "won", { "item" }, true },
  { "LOOT_ROLL_ALL_PASSED", "Everyone passed on: %s", "allpass", { "item" } },
}
local compiled
local function compile()
  compiled = {}
  for _, l in ipairs(LINES) do
    for i = 1, 2 do
      local p = pat(i == 1 and _G[l[1]] or l[2])
      if p then compiled[#compiled + 1] = { p = p, kind = l[3], args = l[4], self = l[5] } end
    end
  end
  -- lines about you first ("You passed on" also fits "%s passed on"), then the longer wordings
  table.sort(compiled, function(a, b)
    local sa, sb = a.self and 1 or 0, b.self and 1 or 0
    if sa ~= sb then return sa > sb end
    return #a.p > #b.p
  end)
end
-- one loot line → { kind, who, item, roll } or nil
function R.Parse(text)
  if type(text) ~= "string" or secret(text) then return nil end
  -- "[Loot]: ", "|cff…[Loot]|r: ", "12:01 [Loot]: " in front: everything up to the first "]: " before a link goes
  local cut = text:find("%]|?r?:%s")
  local link = text:find("|H", 1, true)
  if cut and cut < 60 and (not link or cut < link) then
    text = text:sub(cut):gsub("^%]|?r?:%s*", "")
  end
  if not compiled then compile() end
  for _, c in ipairs(compiled) do
    local caps = { text:match(c.p) }
    if caps[1] then
      local out = { kind = c.kind }
      for i, a in ipairs(c.args) do out[a] = caps[i] end
      if c.self then out.who = me() end
      -- a player link instead of a plain name
      if out.who then out.who = out.who:gsub("|Hplayer:[^|]*|h%[?([^%]|]*)%]?|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
      if out.roll then out.roll = tonumber(out.roll) end
      if out.item and itemId(out.item) then return out end
    end
  end
end

local function roster()
  local out = {}
  local function add(unit)
    local name = safe(UnitName(unit))
    if type(name) == "string" and name ~= "" then
      local _, cls = UnitClass(unit)
      out[#out + 1] = { name = name, class = safe(cls), order = #out + 1 }
    end
  end
  add("player")
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  if IsInRaid and IsInRaid() then
    for i = 1, n do
      local u = "raid" .. i
      if not UnitIsUnit or not UnitIsUnit(u, "player") then add(u) end
    end
  else
    for i = 1, math.max(0, n - 1) do add("party" .. i) end
  end
  return out
end

function R:OnLine(text)
  local e = R.Parse(text)
  if not e then return end
  local item = itemId(e.item)
  local d
  for _, x in ipairs(R.drops) do
    if x.item == item and not x.test and (not d or (not x.done and (d.done or x.startedAt < d.startedAt))) then d = x end
  end
  if not d then return end
  if e.kind == "won" then return R:Finish(d, e.who) end
  if e.kind == "allpass" then return R:Finish(d, nil) end
  local p = player(d, e.who)
  if e.kind == "roll" then p.roll = e.roll
  else p.choice = p.choice or e.kind p.at = p.at or GetTime() end
  R:Refresh()
end

---------------------------------------------------------------------------
-- open, finish, go
---------------------------------------------------------------------------
function R:Start(rollID, seconds)
  local link = GetLootRollItemLink and safe(GetLootRollItemLink(rollID))
  local texture = GetLootRollItemInfo and safe((GetLootRollItemInfo(rollID)))
  local item = itemId(link)
  local d = findDrop(rollID) or (item and unclaimed(item, "rollID"))
  if not d then
    d = newDrop("r" .. tostring(rollID), link)
    if not hasHistory() then d.players = roster() end
  end
  d.rollID, d.texture = rollID, d.texture or texture
  d.link = d.link or link
  if seconds then d.endsAt = GetTime() + seconds end
  R:Refresh()
end

function R:Finish(d, winner)
  if d.done and (d.winner or not winner) then return R:Refresh() end
  d.done, d.winner, d.doneAt = true, winner, GetTime()
  if winner then
    for _, p in ipairs(d.players) do p.won = same(p.name, winner) or nil end
    local w = player(d, winner)
    w.won = true
  end
  if not d.test and not d.saved then
    d.saved = true
    -- the same player entries: roll numbers that come in after the winner still land here
    table.insert(R.history, 1, { link = d.link, item = d.item, texture = d.texture, winner = winner, at = time(), players = d.players })
    while #R.history > 5 do table.remove(R.history) end
  end
  R:Refresh()
end

function R:Remove(d)
  for i, x in ipairs(R.drops) do if x == d then table.remove(R.drops, i) break end end
  R:Refresh()
end

---------------------------------------------------------------------------
-- reading a drop
---------------------------------------------------------------------------
local function counts(d)
  local n = { Need = 0, Greed = 0, Pass = 0, waiting = 0, total = #d.players }
  for _, p in ipairs(d.players) do
    local c = p.choice
    if c == "Need" then n.Need = n.Need + 1
    elseif c == "Greed" or c == "Transmog" or c == "Disenchant" then n.Greed = n.Greed + 1
    elseif c == "Pass" then n.Pass = n.Pass + 1
    else n.waiting = n.waiting + 1 end
  end
  return n
end
R.Counts = counts

local function winnerOf(d)
  for _, p in ipairs(d.players) do if p.won then return p end end
  if d.winner then return { name = d.winner } end
end

-- the right-hand text of a row
function R.Tally(d)
  if d.done then
    local w = winnerOf(d)
    if not w then return "Everyone passed" end
    local how = w.choice and (w.choice .. (w.roll and (" " .. w.roll) or "")) or (w.roll and tostring(w.roll))
    return (isMe(w.name) and "You win" or (shown(w.name) .. " wins")) .. (how and (" · " .. how) or "")
  end
  local n = counts(d)
  local out = {}
  if n.Need > 0 then out[#out + 1] = "Need " .. n.Need end
  if n.Greed > 0 then out[#out + 1] = "Greed " .. n.Greed end
  if n.Pass > 0 then out[#out + 1] = "Pass " .. n.Pass end
  if n.waiting > 0 then out[#out + 1] = n.waiting .. " waiting" end
  return table.concat(out, " · ")
end

-- the line under the bar: your pick, and the time left
function R.YouLine(d)
  local mine
  for _, p in ipairs(d.players) do if isMe(p.name) then mine = p end end
  if mine and mine.choice then return "You: " .. mine.choice end
  if d.done then return "" end
  if mine or not hasHistory() then return "You: pick in the game's window" end
  return ""
end
local function timeLeft(d)
  if d.done or not d.endsAt then return "" end
  local s = math.max(0, math.floor(d.endsAt - GetTime()))
  return s .. " s"
end

-- who picked what: the winner first, then the gang (you included), then the rest; MAX_NAMES lines
function R.Names(d)
  local list = {}
  for _, p in ipairs(d.players) do list[#list + 1] = p end
  local function gang(p) return isMe(p.name) or ns.U.IsGangChar(p.name) end
  table.sort(list, function(a, b)
    if (a.won and 1 or 0) ~= (b.won and 1 or 0) then return a.won == true end
    local ga, gb = gang(a) and 1 or 0, gang(b) and 1 or 0
    if ga ~= gb then return ga > gb end
    local ca, cb = CHOICE_ORDER[a.choice or ""] or 9, CHOICE_ORDER[b.choice or ""] or 9
    if ca ~= cb then return ca < cb end
    if (a.roll or 0) ~= (b.roll or 0) then return (a.roll or 0) > (b.roll or 0) end
    return (a.order or 0) < (b.order or 0)
  end)
  local more = 0
  while #list > MAX_NAMES do table.remove(list) more = more + 1 end
  return list, more
end

---------------------------------------------------------------------------
-- the section
---------------------------------------------------------------------------
local function visibleDrops()
  local out = {}
  for _, d in ipairs(R.drops) do if not d.hidden then out[#out + 1] = d end end
  if R.pastUntil and GetTime() < R.pastUntil then
    for i = #R.history, 1, -1 do
      local h = R.history[i]
      local dup = h.hidden or false
      for _, d in ipairs(out) do if d.players == h.players then dup = true end end
      if not dup then
        -- (one view per past roll, so hovering it survives the next repaint)
        h.view = h.view or { past = h, link = h.link, item = h.item, texture = h.texture, winner = h.winner,
          players = h.players, done = true, key = h }
        table.insert(out, 1, h.view)
      end
    end
  end
  return out
end

local function makeBlock(f, i)
  local b = CreateFrame("Button", nil, f)
  b:SetHeight(ROW_H)
  b:RegisterForClicks("AnyUp")
  b.hl = UI.Track(b:CreateTexture(nil, "BACKGROUND", nil, 2))
  b.hl:SetAllPoints()
  b.hl:SetColorTexture(hex(C.rowAlt or C.cardHover or "202328"))
  b.hl:Hide()
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(24, 24)
  b.icon:SetPoint("TOPLEFT", 6, -8)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.name = UI.Text(b, 11, "semi", C.text)
  b.name:SetPoint("TOPLEFT", 38, -6)
  b.name:SetWordWrap(false)
  b.tally = UI.Text(b, 10, nil, C.dim)
  b.tally:SetPoint("TOPRIGHT", -8, -7)
  b.tally:SetJustifyH("RIGHT")
  b.name:SetPoint("RIGHT", b.tally, "LEFT", -6, 0)
  b.barBg = UI.Track(b:CreateTexture(nil, "ARTWORK", nil, 1))
  b.barBg:SetColorTexture(hex(C.active or "2A2D33"))
  b.barBg:SetHeight(3)
  b.barBg:SetPoint("TOPLEFT", 38, -22)
  b.barBg:SetPoint("TOPRIGHT", -8, -22)
  b.seg = {}
  for k, col in ipairs({ NEED, GREED, PASS }) do
    local t = b:CreateTexture(nil, "ARTWORK", nil, 2)
    t:SetColorTexture(hex(col))
    t:SetHeight(3)
    b.seg[k] = t
  end
  b.you = UI.Text(b, 10, nil, C.muted)
  b.you:SetPoint("TOPLEFT", 38, -28)
  b.time = UI.Text(b, 10, nil, C.muted)
  b.time:SetPoint("TOPRIGHT", -8, -28)
  b.x = UI.IconButton(b, 14, "Close", "Close", function(self)
    local d = b.drop
    if not d then return end
    if R.hovered == d then R.hovered = nil end
    if d.past then d.past.hidden = true R:Refresh() else R:Remove(d) end
  end)
  b.x:SetPoint("RIGHT", b, "TOPRIGHT", -4, -DONE_H / 2)
  b.x:Hide()
  b.lines = {}
  b:SetScript("OnEnter", function(self) if not R.laying and self.drop and R.hovered ~= self.drop then R.hovered = self.drop R:Layout() end end)
  b:SetScript("OnLeave", function(self)
    if GameTooltip then GameTooltip:Hide() end
    C_Timer.After(0.15, function() R:CheckHover() end)
  end)
  b:SetScript("OnClick", function(self)
    local d = self.drop
    if d and d.link and IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then HandleModifiedItemClick(d.link) end
  end)
  -- the item's tooltip on the icon
  b.iconHit = CreateFrame("Frame", nil, b)
  b.iconHit:SetAllPoints(b.icon)
  b.iconHit:EnableMouse(true)
  b.iconHit:SetScript("OnEnter", function(self)
    local d = b.drop
    if d and R.hovered ~= d then R.hovered = d R:Layout() end
    if d and d.link and GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      pcall(GameTooltip.SetHyperlink, GameTooltip, d.link)
      GameTooltip:Show()
    end
  end)
  b.iconHit:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end C_Timer.After(0.15, function() R:CheckHover() end) end)
  -- a thin line between items
  b.sep = UI.Track(b:CreateTexture(nil, "ARTWORK"))
  b.sep:SetColorTexture(hex(C.line or C.border or "2A2D33"))
  b.sep:SetHeight(1)
  b.sep:SetPoint("BOTTOMLEFT", 0, 0)
  b.sep:SetPoint("BOTTOMRIGHT", 0, 0)
  -- the inset under a row that holds who picked what
  b.inset = UI.Track(b:CreateTexture(nil, "BACKGROUND", nil, 3))
  b.inset:SetColorTexture(hex(C.window or C.field or "141619"))
  b.inset:SetAlpha(0.85)
  b.inset:Hide()
  f.blocks[i] = b
  return b
end

local function line(b, i)
  local l = b.lines[i]
  if l then return l end
  l = {}
  l.bg = UI.Track(b:CreateTexture(nil, "BACKGROUND", nil, 4))
  l.bg:SetColorTexture(hex(C.rowAlt or C.cardHover or "202328"))
  l.bg:SetHeight(LINE_H)
  l.name = UI.Text(b, 10, "semi", C.text)
  l.choice = UI.Text(b, 10, "semi", C.dim)
  l.roll = UI.Text(b, 10, nil, C.muted)
  l.roll:SetJustifyH("RIGHT")
  l.roll:SetWidth(24)
  l.star = UI.Text(b, 10, nil, C.gold)
  l.star:SetWidth(10)
  b.lines[i] = l
  return l
end

function R:Create()
  if self.frame then return self.frame end
  local f = CreateFrame("Frame", "ChillanLootRolls", UIParent)
  f:SetFrameStrata("MEDIUM")
  f:SetSize(FREE_W, 60)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not R.docked then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if not R.docked then S().lootRollsPos = { x = self:GetLeft(), y = self:GetTop() } end
  end)
  f:Hide()
  self.frame = f
  f.card = UI.Backplate(f, "Loot rolls")
  local midY = -(8 + 1 + f.card.stripH / 2 - 1)
  f.past = CreateFrame("Button", nil, f)
  f.past:SetSize(60, 16)
  f.past:SetPoint("RIGHT", f, "TOPRIGHT", -20, midY)
  f.past.t = UI.Text(f.past, 10, "semi", C.dim)
  f.past.t:SetPoint("RIGHT")
  f.past.t:SetText("last 5 ›")
  f.past:SetScript("OnClick", function() R:TogglePast() end)
  f.past:SetScript("OnEnter", function(b) b.t:SetTextColor(hex(C.text)) end)
  f.past:SetScript("OnLeave", function(b) b.t:SetTextColor(hex(C.dim)) end)
  f.close = UI.IconButton(f, 14, "Close", "Close", function() R:CloseAll() end)
  f.close:SetPoint("RIGHT", f, "TOPRIGHT", -18, midY)
  f.past:ClearAllPoints()
  f.past:SetPoint("RIGHT", f.close, "LEFT", -4, 0)
  f.blocks = {}
  return f
end

function R:CloseAll()
  R.hovered, R.pastUntil = nil, nil
  for i = #R.drops, 1, -1 do
    local d = R.drops[i]
    if d.done or d.test then table.remove(R.drops, i) else d.hidden = true end
  end
  R:Refresh()
end

-- the hovered row is where the mouse is, not what an event last said
function R:CheckHover()
  if R.laying then return end
  local f = self.frame
  local now
  if f and f:IsShown() then
    for _, b in ipairs(f.blocks) do
      if b:IsShown() and b.drop and b:IsMouseOver() then now = b.drop end
    end
  end
  if now ~= R.hovered then R.hovered = now self:Layout() end
end

function R:TogglePast()
  if R.pastUntil and GetTime() < R.pastUntil then R.pastUntil = nil
  else
    if #R.history == 0 then ns.Print("Loot rolls: no finished roll yet this session.") return end
    R.pastUntil = GetTime() + 60
    C_Timer.After(60.5, function() R:Refresh() end)
  end
  R:Refresh()
end

local function fillBlock(b, d, w)
  b.drop = d
  local open = R.hovered == d
  b.icon:SetTexture(d.texture or (d.item and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(tonumber(d.item))) or 134400)
  b.name:SetText(d.link or "?")
  b.tally:SetText(R.Tally(d))
  b.tally:SetTextColor(hex(d.done and C.text2 or C.dim))
  local h
  if d.done then
    -- one line: icon small, name, who won
    b.icon:SetSize(16, 16)
    b.icon:ClearAllPoints() b.icon:SetPoint("TOPLEFT", 8, -3)
    b.name:ClearAllPoints() b.name:SetPoint("TOPLEFT", 30, -5)
    b.tally:ClearAllPoints() b.tally:SetPoint("TOPRIGHT", -22, -5)
    b.name:SetPoint("RIGHT", b.tally, "LEFT", -6, 0)
    b.barBg:Hide() for _, t in ipairs(b.seg) do t:Hide() end
    b.you:Hide() b.time:Hide()
    b.x:Show()
    h = DONE_H
  else
    b.icon:SetSize(24, 24)
    b.icon:ClearAllPoints() b.icon:SetPoint("TOPLEFT", 6, -8)
    b.name:ClearAllPoints() b.name:SetPoint("TOPLEFT", 38, -6)
    b.tally:ClearAllPoints() b.tally:SetPoint("TOPRIGHT", -8, -7)
    b.name:SetPoint("RIGHT", b.tally, "LEFT", -6, 0)
    b.barBg:Show()
    local n = counts(d)
    local bw = math.max(10, (w or FREE_W) - 40 - 46)
    local x = 0
    for k, key in ipairs({ "Need", "Greed", "Pass" }) do
      local t = b.seg[k]
      local sw = n.total > 0 and math.floor(bw * n[key] / n.total + 0.5) or 0
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", b.barBg, "TOPLEFT", x, 0)
      t:SetWidth(math.max(1, sw))
      t:SetShown(sw > 0)
      x = x + sw
    end
    b.you:SetText(R.YouLine(d)) b.you:Show()
    b.time:SetText(timeLeft(d)) b.time:Show()
    b.x:Hide()
    h = ROW_H
  end
  -- hovering: who picked what, right under the row
  for _, l in pairs(b.lines) do l.bg:Hide() l.name:Hide() l.choice:Hide() l.roll:Hide() l.star:Hide() end
  b.hl:SetShown(open and true or false)
  b.inset:Hide()
  if open and #d.players > 0 then
    local list, more = R.Names(d)
    local top = -(h + 1)
    local y = top - 3
    for i, p in ipairs(list) do
      local l = line(b, i)
      l.bg:ClearAllPoints()
      l.bg:SetPoint("TOPLEFT", 30, y + 2) l.bg:SetPoint("TOPRIGHT", -2, y + 2)
      l.bg:SetShown(i % 2 == 1)
      l.name:ClearAllPoints() l.name:SetPoint("TOPLEFT", 38, y)
      l.star:ClearAllPoints() l.star:SetPoint("TOPRIGHT", -8, y)
      l.roll:ClearAllPoints() l.roll:SetPoint("TOPRIGHT", l.star, "TOPLEFT", -4, 0)
      l.choice:ClearAllPoints() l.choice:SetPoint("TOPRIGHT", l.roll, "TOPLEFT", -6, 0)
      l.name:SetText(ns.Colorize(shown(p.name) .. (isMe(p.name) and " (you)" or ""), p.class and ns.ClassHex(p.class) or C.text))
      l.choice:SetText(p.choice or (d.done and "–" or "…"))
      l.choice:SetTextColor(hex(CHOICE_COL[p.choice or ""] or C.dim))
      l.roll:SetText(p.roll and tostring(p.roll) or "")
      l.star:SetText(p.won and "★" or "")
      l.name:Show() l.choice:Show() l.roll:Show() l.star:Show()
      y = y - LINE_H
    end
    if more > 0 then
      local l = line(b, #list + 1)
      l.bg:Hide()
      l.name:ClearAllPoints() l.name:SetPoint("TOPLEFT", 38, y)
      l.name:SetText(ns.Colorize("+" .. more .. " more", C.dim))
      l.name:Show()
      y = y - LINE_H
    end
    b.inset:ClearAllPoints()
    b.inset:SetPoint("TOPLEFT", 30, top)
    b.inset:SetPoint("BOTTOMRIGHT", -2, 4)
    b.inset:Show()
    h = -y + 6
  end
  b:SetHeight(h)
  return h
end

-- Pulse calls this from its own layout: hang under `last` when Pulse is up, else stand alone
function R:Dock(last, pulseUp)
  local f = self.frame
  if not f or not f:IsShown() then return nil end
  self.docked = pulseUp and last and true or false
  f:ClearAllPoints()
  if self.docked then
    f:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, 0)
    f:SetPoint("TOPRIGHT", last, "BOTTOMRIGHT", 0, 0)
    local m = ns.Overlays and ns.Overlays.minibar
    if m then f:SetFrameLevel(m:GetFrameLevel() + 5) end
    return f
  end
  f:SetWidth(FREE_W)
  local pos = S().lootRollsPos
  if type(pos) == "table" and pos.x and pos.y then f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
  else f:SetPoint("TOP", UIParent, "TOP", 0, -160) end
  return nil
end

function R:Layout()
  local f = self.frame
  if not f then return end
  -- Pulse went away under us: stand alone
  local m = ns.Overlays and ns.Overlays.minibar
  if self.docked and not (m and m:IsShown()) then self:Dock(nil, false) end
  R.laying = true
  local list = visibleDrops()
  local w = f:GetWidth()
  if not w or w < 50 then w = FREE_W end
  local active = 0
  for _, d in ipairs(list) do if not d.done then active = active + 1 end end
  f.card:SetTitle("Loot rolls" .. (active > 0 and (" · " .. active) or ""))
  local y = f.card.top + 2
  -- newest on top
  local n = 0
  for i = #list, 1, -1 do
    n = n + 1
    local b = f.blocks[n] or makeBlock(f, n)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 12, y)
    b:SetPoint("TOPRIGHT", -12, y)
    local h = fillBlock(b, list[i], w)
    b.sep:SetShown(i > 1)
    b:Show()
    y = y - h
  end
  for i = n + 1, #f.blocks do local b = f.blocks[i] b.drop = nil b:Hide() end
  f:SetHeight(-y + 6)
  R.laying = nil
  local h = math.floor(f:GetHeight())
  if self.lastH ~= h then
    self.lastH = h
    if ns.Overlays and ns.Overlays.UpdateGroup then ns.Overlays:UpdateGroup() end
  end
end

-- show/hide, tidy up, repaint
function R:Refresh()
  local now = GetTime()
  for i = #R.drops, 1, -1 do
    local d = R.drops[i]
    local hold = R.hovered == d or (S().lootRollsKeep and not d.test)
    if d.done and not hold and d.doneAt and now - d.doneAt >= (d.test and 8 or KEEP_DONE) then
      table.remove(R.drops, i)
    elseif not d.done and d.endsAt and now > d.endsAt + 25 and not d.test then
      -- nobody said who won long after the time ran out: let it go
      table.remove(R.drops, i)
    end
  end
  local f = self:Create()
  local shownN = 0
  for _, d in ipairs(R.drops) do if not d.hidden then shownN = shownN + 1 end end
  local want = on() and (shownN > 0 or (R.pastUntil and now < R.pastUntil)) and true or false
  if want ~= f:IsShown() then
    f:SetShown(want)
    self.lastH = nil
    if ns.Overlays and ns.Overlays.UpdateGroup then ns.Overlays:UpdateGroup() end
    if want and not self.docked then self:Dock(nil, false) end
  end
  if want then self:Layout() self:Tick() end
end

-- every half second while something is open: the countdown, and rows that finish
function R:Tick()
  if R.ticking then return end
  R.ticking = true
  local function step()
    if #R.drops == 0 and not (R.pastUntil and GetTime() < R.pastUntil) then R.ticking = false R:Refresh() return end
    R:CheckHover()
    R:Refresh()
    C_Timer.After(0.5, step)
  end
  C_Timer.After(0.5, step)
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------
ns:On("START_LOOT_ROLL", function(id, ms)
  id = safe(id)
  if not id or not on() then return end
  if S().lootRollsBig == false and big() then return end
  local secs = safe(ms) and ms / 1000 or nil
  -- the item's details can be a frame late
  C_Timer.After(0.05, function() R:Start(id, secs) end)
end)
ns:On("LOOT_HISTORY_UPDATE_DROP", function(enc, list) if on() then R:FromHistory(enc, list) end end)
ns:On("LOOT_HISTORY_CLEAR_HISTORY", function()
  for i = #R.drops, 1, -1 do if R.drops[i].hkey and R.drops[i].done then table.remove(R.drops, i) end end
  R:Refresh()
end)
ns:On("CHAT_MSG_LOOT", function(text)
  if on() and not hasHistory() then R:OnLine(safe(text)) end
end)
ns:On("PLAYER_LOGIN", function()
  C_Timer.After(14, function()
    if S().lootRolls ~= false and needAddon() then
      ns.Print("Loot rolls: the Need addon is on, so Chillan's roll list stays off. Turn Need off to use Chillan's (it remembers the last rolls: /chill rolls).")
    end
  end)
end)

---------------------------------------------------------------------------
-- /chill rolls: the last 5 for a minute · /chill need: a test roll
---------------------------------------------------------------------------
function R:ShowPast()
  if #R.history == 0 then ns.Print("Loot rolls: no finished roll yet this session.") return end
  R.pastUntil = GetTime() + 60
  C_Timer.After(60.5, function() R:Refresh() end)
  R:Refresh()
end

local TEST_PLAYERS = {
  { name = "Thunka", class = "SHAMAN" }, { name = "Kenny", class = "ROGUE" }, { name = "Valdrin", class = "PALADIN" },
  { name = "Eirik", class = "MAGE" },
}
function R:Test()
  local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  local link = info and select(2, info(12927)) or "|cffa335ee|Hitem:12927::::::::60:::::|h[Truestrike Shoulders]|h|r"
  local icon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
  local _, myClass = UnitClass("player")
  for i = #R.drops, 1, -1 do if R.drops[i].test then table.remove(R.drops, i) end end
  R.hovered = nil
  R.testN = (R.testN or 0) + 1
  local d = newDrop("test" .. R.testN, link)
  d.test, d.texture, d.endsAt = true, icon and icon(12927) or nil, GetTime() + 30
  d.players = { { name = me(), class = safe(myClass), order = 1 } }
  for i, p in ipairs(TEST_PLAYERS) do d.players[#d.players + 1] = { name = p.name, class = p.class, order = i + 1 } end
  local script = {
    { 1.2, "Thunka", "Need" }, { 2.4, "Kenny", "Greed" }, { 3.4, "Valdrin", "Pass" }, { 5.0, "Eirik", "Need" },
    { 6.5, me(), "Pass" }, { 7.5, "Thunka", "roll", 41 }, { 7.7, "Eirik", "roll", 87 }, { 8.4, "Eirik", "won" },
  }
  for _, s in ipairs(script) do
    C_Timer.After(s[1], function()
      if not findDrop(d.key) then return end
      if s[3] == "won" then return R:Finish(d, s[2]) end
      local p = player(d, s[2])
      if s[3] == "roll" then p.roll = s[4] else p.choice, p.at = s[3], GetTime() end
      R:Refresh()
    end)
  end
  R:Refresh()
  ns.Print("Loot rolls: a test roll with made-up players (" .. (link or "?") .. "). Hover the row for who picked what.")
end
