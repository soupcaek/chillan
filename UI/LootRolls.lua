-- Chillan? – loot rolls: who picked what (1.4.72)
-- Under the game's own roll window, a small panel lists everyone in the group with their Need, Greed or
-- Pass as it comes in, then the rolls with a star on the winner (8 s, then it goes). The choices are read
-- from the game's own loot lines in chat ("Kenny has selected Greed for: [item]"), so it works in any
-- group. When the roll window closes (you picked), the panel stays where it was and shows the item itself.
-- /chill need shows a test roll with made-up players.
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex
local secret, S = ns.U.Secret, ns.U.Settings
local norm = ns.U.NormName

local R = {}
ns.LootRolls = R
R.rolls = {}        -- rollID -> roll
R.panels = {}       -- free panels
local W, ROW, HEAD, MAX_ROWS = 250, 18, 22, 12
local NEED, GREED, PASS = "5FD18B", "E0B04F", "858B92"
local CHOICE_COL = { Need = NEED, Greed = GREED, Pass = PASS, Disenchant = "B9AEDB" }
local CHOICE_ORDER = { Need = 1, Greed = 2, Disenchant = 3, Pass = 4 }

local function safe(v) if v == nil or secret(v) then return nil end return v end
local function on() return S().lootRolls ~= false end
local function itemId(link) return type(link) == "string" and link:match("item:(%d+)") or nil end
local function me() return safe(UnitName("player")) or "?" end

---------------------------------------------------------------------------
-- the game's loot lines → patterns
---------------------------------------------------------------------------
local function pat(fmt)
  if type(fmt) ~= "string" or secret(fmt) then return nil end
  -- the %s / %d (or %1$s) first become markers, then the rest is made literal, then the markers captures
  local p = fmt:gsub("%%%d?%$?([sd])", function(kind) return "\001" .. kind end)
  p = p:gsub("[%%%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
  p = p:gsub("\001s", "(.+)"):gsub("\001d", "(%%d+)")
  return "^" .. p .. "$"
end
-- { global, fallback, kind, args }: args names what each %s/%d is
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
    -- the game's own wording (any language) first, the English one as a fallback
    for i = 1, 2 do
      local p = pat(i == 1 and _G[l[1]] or l[2])
      if p then compiled[#compiled + 1] = { p = p, kind = l[3], args = l[4], self = l[5] } end
    end
  end
  -- "You passed on: …" would also fit "%s passed on: %s": the lines about you are tried first
  -- (and the longer wordings before the short ones they contain, like "automatically passed on")
  table.sort(compiled, function(a, b)
    local sa, sb = a.self and 1 or 0, b.self and 1 or 0
    if sa ~= sb then return sa > sb end
    return #a.p > #b.p
  end)
end
-- one loot line → { kind, who, item, roll } or nil
function R.Parse(text)
  if type(text) ~= "string" or secret(text) then return nil end
  -- (dev5) this client starts loot lines with "[Loot]: "
  text = text:gsub("^%[[^%]|]+%]:%s*", "")
  if not compiled then compile() end
  for _, c in ipairs(compiled) do
    local caps = { text:match(c.p) }
    if caps[1] then
      local out = { kind = c.kind }
      for i, a in ipairs(c.args) do out[a] = caps[i] end
      if c.self then out.who = me() end
      if out.roll then out.roll = tonumber(out.roll) end
      if out.item and itemId(out.item) then return out end
    end
  end
end

---------------------------------------------------------------------------
-- the group
---------------------------------------------------------------------------
local function roster()
  local out = {}
  local function add(unit)
    local name = safe(UnitName(unit))
    if type(name) == "string" and name ~= "" then
      local _, cls = UnitClass(unit)
      out[#out + 1] = { name = name, class = safe(cls) }
    end
  end
  add("player")
  local raid = IsInRaid and IsInRaid()
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  if raid then
    for i = 1, n do
      local u = "raid" .. i
      if not UnitIsUnit or not UnitIsUnit(u, "player") then add(u) end
    end
  else
    for i = 1, math.max(0, n - 1) do add("party" .. i) end
  end
  return out
end

---------------------------------------------------------------------------
-- the panel
---------------------------------------------------------------------------
local function newPanel()
  local f = UI.OverlayPanel(UIParent, C.panel or C.card, C.border or C.activeLine, 4)
  f:SetFrameStrata("DIALOG")
  f:SetWidth(W)
  f.head = f:CreateTexture(nil, "BORDER", nil, 1)
  UI.Track(f.head):SetColorTexture(hex(C.strip or C.cardHover))
  f.head:SetPoint("TOPLEFT", 1, -1) f.head:SetPoint("TOPRIGHT", -1, -1) f.head:SetHeight(HEAD - 1)
  f.headLine = f:CreateTexture(nil, "ARTWORK")
  UI.Track(f.headLine):SetColorTexture(hex(C.border or C.activeLine))
  f.headLine:SetPoint("TOPLEFT", 1, -HEAD) f.headLine:SetPoint("TOPRIGHT", -1, -HEAD) f.headLine:SetHeight(1)
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(14, 14)
  f.icon:SetPoint("LEFT", f, "TOPLEFT", 6, -HEAD / 2)
  f.title = UI.Text(f, 10, "bold", C.text2)
  f.right = UI.Text(f, 10, nil, C.dim)
  f.right:SetPoint("RIGHT", f, "TOPRIGHT", -8, -HEAD / 2)
  f.title:SetPoint("RIGHT", f.right, "LEFT", -6, 0)
  f.rows = {}
  -- the item's tooltip on the title
  f:EnableMouse(true)
  f:SetScript("OnEnter", function(self)
    local r = self.roll
    if r and r.link and GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      pcall(GameTooltip.SetHyperlink, GameTooltip, r.link)
      GameTooltip:Show()
    end
  end)
  f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  -- (dev5) drag it anywhere (it stays there for that roll); the wheel scrolls a long list
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if GameTooltip then GameTooltip:Hide() end self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local r = self.roll
    if r then r.moved, r.detached, r.anchor, r.placed = true, true, nil, true r.lastX, r.lastY = self:GetLeft(), self:GetTop() R:Draw(r) end
  end)
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(self, d)
    local r = self.roll
    if not r then return end
    r.scroll = math.max(0, math.min((r.scrollMax or 0), (r.scroll or 0) - d * 3))
    R:Draw(r)
  end)
  f.more = UI.Text(f, 10, nil, C.dim)
  f.more:SetPoint("BOTTOMRIGHT", -8, 4)
  return f
end
local function row(f, i)
  local r = f.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, f)
  r:SetHeight(ROW)
  r:SetPoint("TOPLEFT", 1, -(HEAD + 2 + (i - 1) * ROW))
  r:SetPoint("RIGHT", -1, 0)
  r.bg = r:CreateTexture(nil, "BACKGROUND", nil, 2)
  r.bg:SetAllPoints()
  UI.Track(r.bg):SetColorTexture(hex(C.rowAlt or C.window or "17191C"))
  r.name = UI.Text(r, 11, "semi", C.text)
  r.name:SetPoint("LEFT", 8, 0)
  r.star = UI.Text(r, 11, nil, C.gold)
  r.star:SetPoint("RIGHT", -6, 0)
  r.star:SetWidth(10)
  r.roll = UI.Text(r, 11, nil, C.muted)
  r.roll:SetPoint("RIGHT", r.star, "LEFT", -4, 0)
  r.roll:SetWidth(24)
  r.roll:SetJustifyH("RIGHT")
  r.choice = UI.Text(r, 11, "semi", C.dim)
  r.choice:SetPoint("RIGHT", r.roll, "LEFT", -6, 0)
  r.name:SetPoint("RIGHT", r.choice, "LEFT", -6, 0)
  f.rows[i] = r
  return r
end

local function blizzFrame(rollID)
  for i = 1, 8 do
    local g = _G["GroupLootFrame" .. i]
    if g and g.rollID == rollID and g:IsShown() then return g end
  end
end

local function sorted(roll)
  local list = {}
  for _, p in ipairs(roll.players) do list[#list + 1] = p end
  table.sort(list, function(a, b)
    if roll.done then
      if (a.won and 1 or 0) ~= (b.won and 1 or 0) then return a.won == true end
      local ca, cb = CHOICE_ORDER[a.choice or ""] or 9, CHOICE_ORDER[b.choice or ""] or 9
      if ca ~= cb then return ca < cb end
      return (a.roll or 0) > (b.roll or 0)
    end
    -- while rolling: those who picked first (in the order they came), then the ones still waiting
    local wa, wb = a.at or 1e12, b.at or 1e12
    if wa ~= wb then return wa < wb end
    return a.order < b.order
  end)
  return list
end

function R:Draw(roll)
  local f = roll.panel
  if not f then return end
  local picked = 0
  for _, p in ipairs(roll.players) do if p.choice then picked = picked + 1 end end
  local attached = roll.anchor ~= nil
  -- attached under the roll window: "ROLLS"; standing alone: the item itself
  f.icon:SetShown(not attached)
  if roll.texture then f.icon:SetTexture(roll.texture) end
  f.title:ClearAllPoints()
  f.title:SetPoint("LEFT", f, "TOPLEFT", attached and 8 or 24, -HEAD / 2)
  f.title:SetPoint("RIGHT", f.right, "LEFT", -6, 0)
  if roll.done then
    if roll.winner then
      f.title:SetText(attached and ("WON BY " .. ns.ShortName(roll.winner):upper()) or ((roll.link or "?") .. " → " .. ns.ShortName(roll.winner)))
      local w
      for _, p in ipairs(roll.players) do if p.won then w = p end end
      f.right:SetText(w and w.choice and (w.choice .. (w.roll and (" " .. w.roll) or "")) or "")
    else
      f.title:SetText(attached and "EVERYONE PASSED" or ((roll.link or "?") .. " · everyone passed"))
      f.right:SetText("")
    end
  else
    f.title:SetText(attached and "ROLLS" or (roll.link or "ROLLS"))
    local left = roll.endsAt and math.max(0, math.floor(roll.endsAt - GetTime())) or nil
    f.right:SetText(picked .. " of " .. #roll.players .. (left and (" · " .. left .. " s") or ""))
  end
  local all = sorted(roll)
  -- (dev5) at most MAX_ROWS rows (a battleground raid has 40): the wheel scrolls the rest
  roll.scrollMax = math.max(0, #all - MAX_ROWS)
  roll.scroll = math.min(roll.scroll or 0, roll.scrollMax)
  local list = {}
  for i = roll.scroll + 1, math.min(#all, roll.scroll + MAX_ROWS) do list[#list + 1] = all[i] end
  local below = #all - roll.scroll - #list
  f.more:SetText(below > 0 and ("scroll for " .. below .. " more") or "")
  for i, p in ipairs(list) do
    local r = row(f, i)
    r:Show()
    r.bg:SetShown(i % 2 == 0)
    local you = norm(p.name) == norm(me())
    r.name:SetText(ns.ShortName(p.name) .. (you and ns.Colorize(" (you)", C.dim) or ""))
    UI.Track(r.name):SetTextColor(hex(p.class and ns.ClassHex(p.class) or C.text))
    if p.choice then
      r.choice:SetText(p.choice)
      UI.Track(r.choice):SetTextColor(hex(CHOICE_COL[p.choice] or C.dim))
    else
      r.choice:SetText("…")
      UI.Track(r.choice):SetTextColor(hex(C.dim))
    end
    r.roll:SetText(p.roll and tostring(p.roll) or "")
    UI.Track(r.roll):SetTextColor(hex(p.won and C.text or C.muted))
    r.star:SetText(p.won and "★" or "")
  end
  for i = #list + 1, #f.rows do f.rows[i]:Hide() end
  f:SetHeight(HEAD + 4 + #list * ROW + (below > 0 and 16 or 0))
end

-- where the panel goes: under the game's roll window while it's open; where it was once it closes
function R:Place(roll)
  local f = roll.panel
  if not f then return end
  local g = blizzFrame(roll.id)
  if g and not roll.moved then
    roll.anchor = g
    f:ClearAllPoints()
    f:SetPoint("TOP", g, "BOTTOM", 0, -2)
    f:SetWidth(math.max(W, math.floor((g:GetWidth() or W) + 0.5)))
    -- (dev5) remember where it sits: when the roll window closes the panel stays right there
    -- (it jumped to the top of the screen, because the spot was read after the window was gone)
    roll.lastX, roll.lastY = f:GetLeft(), f:GetTop()
    roll.placed = true
    return
  end
  if roll.anchor or not roll.placed then
    if roll.anchor then roll.detached = true end
    -- stand alone at the spot it had (or the top of the screen for a test roll)
    local x, y = roll.lastX or f:GetLeft(), roll.lastY or f:GetTop()
    roll.anchor = nil
    f:ClearAllPoints()
    if x and y and roll.placed then
      f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    else
      f:SetPoint("TOP", UIParent, "TOP", 0, -180 - (roll.slot or 0) * 10)
    end
  end
  roll.placed = true
end

function R:Open(id, link, seconds, players, texture)
  if not on() then return end
  local roll = R.rolls[id]
  if roll then return roll end
  roll = { id = id, link = link, item = itemId(link), texture = texture, startedAt = GetTime(), players = {} }
  roll.endsAt = seconds and (GetTime() + seconds) or nil
  for i, p in ipairs(players or roster()) do roll.players[i] = { name = p.name, class = p.class, order = i } end
  local n = 0
  for _ in pairs(R.rolls) do n = n + 1 end
  roll.slot = n
  roll.panel = table.remove(R.panels) or newPanel()
  roll.panel.roll = roll
  R.rolls[id] = roll
  R:Place(roll)
  R:Draw(roll)
  roll.panel:Show()
  R:Tick()
  return roll
end

function R:Close(roll)
  if not roll or R.rolls[roll.id] ~= roll then return end
  R.rolls[roll.id] = nil
  if roll.panel then
    roll.panel:Hide()
    roll.panel.roll = nil
    R.panels[#R.panels + 1] = roll.panel
    roll.panel = nil
  end
end

-- (dev5) names in loot lines carry the surname ("Gumi Megpoid"), the group list only the name ("Gumi")
local function first(name) return norm((tostring(name or ""):match("^(%S+)")) or "") end

-- the open roll a loot line is about: the oldest with that item where this player hasn't got that news yet
local function rollFor(item, who, kind)
  local best
  for _, r in pairs(R.rolls) do
    if r.item == item and not r.done then
      local p
      for _, q in ipairs(r.players) do if norm(q.name) == norm(who or "") or first(q.name) == first(who) then p = q end end
      local fresh = not who or not p or (kind == "roll" and not p.roll) or (kind ~= "roll" and not p.choice)
      if fresh and (not best or r.startedAt < best.startedAt) then best = r end
    end
  end
  if best then return best end
  -- the winner line can come just after we marked a roll done by time: take the newest with that item
  for _, r in pairs(R.rolls) do if r.item == item and (not best or r.startedAt > best.startedAt) then best = r end end
  return best
end

local function player(roll, who)
  for _, p in ipairs(roll.players) do if norm(p.name) == norm(who) then return p end end
  for _, p in ipairs(roll.players) do if first(p.name) == first(who) then return p end end
  local p = { name = who, order = #roll.players + 1 }
  roll.players[#roll.players + 1] = p
  return p
end

function R:Finish(roll, winner)
  if roll.done and roll.winner then return end
  roll.done, roll.winner = true, winner
  if winner then player(roll, winner).won = true end
  R:Place(roll)
  R:Draw(roll)
  C_Timer.After(8, function() R:Close(roll) end)
end

function R:OnLine(text)
  local e = R.Parse(text)
  if not e then return end
  local roll = rollFor(itemId(e.item), e.who, e.kind)
  if not roll then return end
  if e.kind == "won" then return R:Finish(roll, e.who) end
  if e.kind == "allpass" then return R:Finish(roll, nil) end
  local p = player(roll, e.who)
  if e.kind == "roll" then
    p.roll = e.roll
  else
    p.choice = p.choice or e.kind
    p.at = p.at or GetTime()
  end
  R:Draw(roll)
end

-- every half second: the countdown, and the move from "under the window" to "on its own"
function R:Tick()
  if R.ticking then return end
  R.ticking = true
  local function step()
    local any = false
    for _, roll in pairs(R.rolls) do
      any = true
      local g = blizzFrame(roll.id)
      if roll.anchor and g and roll.panel then roll.lastX, roll.lastY = roll.panel:GetLeft(), roll.panel:GetTop() end
      if (roll.anchor and not g) or (g and not roll.anchor and not roll.detached and not roll.moved) then R:Place(roll) end
      if not roll.done then
        -- nobody said who won long after the time ran out: let it go
        if roll.endsAt and GetTime() > roll.endsAt + 20 and not roll.test then R:Close(roll) else R:Draw(roll) end
      end
    end
    if any then C_Timer.After(0.5, step) else R.ticking = false end
  end
  C_Timer.After(0.5, step)
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------
ns:On("START_LOOT_ROLL", function(id, ms)
  id = safe(id)
  if not id or not on() then return end
  if S().lootRollsBig == false and (GetNumGroupMembers and GetNumGroupMembers() or 0) > 5 then return end
  local link = GetLootRollItemLink and safe(GetLootRollItemLink(id))
  local texture = GetLootRollItemInfo and safe((GetLootRollItemInfo(id)))
  -- the game's window appears a frame later: open then, so the panel can sit under it
  C_Timer.After(0.05, function() R:Open(id, link, safe(ms) and ms / 1000 or nil, nil, texture) end)
end)
ns:On("CHAT_MSG_LOOT", function(text) if on() then R:OnLine(safe(text)) end end)

---------------------------------------------------------------------------
-- /chill need: a test roll – made-up players pick one after another, roll, and one wins
---------------------------------------------------------------------------
local TEST_PLAYERS = {
  { name = "Thunka", class = "SHAMAN" }, { name = "Kenny", class = "ROGUE" }, { name = "Valdrin", class = "PALADIN" },
  { name = "Eirik", class = "MAGE" },
}
function R:Test()
  -- (dev4) GetItemInfo/GetItemIcon are only in C_Item on this client
  local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  local link = info and select(2, info(12927)) or "|cffa335ee|Hitem:12927::::::::60:::::|h[Truestrike Shoulders]|h|r"
  local icon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
  local texture = icon and icon(12927) or nil
  local _, myClass = UnitClass("player")
  local players = { { name = me(), class = safe(myClass) } }
  for _, p in ipairs(TEST_PLAYERS) do players[#players + 1] = p end
  local was = S().lootRolls
  S().lootRolls = true
  R.testN = (R.testN or 0) + 1
  local id = "test" .. R.testN
  local roll = R:Open(id, link, 30, players, texture)
  S().lootRolls = was
  if not roll then return end
  roll.test = true
  local item = link
  local script = {
    { 1.2, "Thunka", "Need" }, { 2.4, "Kenny", "Greed" }, { 3.4, "Valdrin", "Pass" }, { 5.0, "Eirik", "Need" },
    { 6.5, me(), "Pass" }, { 7.5, "Thunka", "roll", 41 }, { 7.7, "Eirik", "roll", 87 }, { 8.4, "Eirik", "won" },
  }
  for _, s in ipairs(script) do
    C_Timer.After(s[1], function()
      if R.rolls[id] ~= roll then return end
      if s[3] == "won" then return R:Finish(roll, s[2]) end
      local p = player(roll, s[2])
      if s[3] == "roll" then p.roll = s[4] else p.choice, p.at = s[3], GetTime() end
      R:Draw(roll)
    end)
  end
  ns.Print("Loot rolls: a test roll with made-up players (" .. (item or "?") .. "). It closes by itself.")
end
