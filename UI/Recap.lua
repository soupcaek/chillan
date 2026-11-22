local _, ns = ...
-- (1.4.28) Recaps: a small pill grows out of the screen with "Show … recap" and "Close". Show grows
-- it into a card in the same spot: four headline numbers that count up, the best moments, a bar
-- against the gang's (or your own) best, and Share/Close.
--   login / logout: middle of the screen      dungeon / raid / battleground done: top middle
-- Ignored for 20 s, the pill slides away and a "Recap" line stays in the feed to open it later.

local UI, C = ns.UI, ns.C
local R = {}
ns.Recap = R

local PILL_W, PILL_H = 380, 72
local CARD_W = 420
local IGNORE_SECS = 20
local hex = ns.hex

R.saved = {}   -- recaps of this session, by id (for the feed's "Show" link)
local nextId = 0

local function enabled() return ns.db and ns.db.settings.recaps ~= false end

---------------------------------------------------------------------------
-- small animation helper: t goes 0 → 1 over secs, fn(eased) each frame
---------------------------------------------------------------------------
local function animate(frame, secs, fn, done)
  local t = 0
  frame:SetScript("OnUpdate", function(self, dt)
    t = math.min(1, t + dt / secs)
    fn(t)
    if t >= 1 then self:SetScript("OnUpdate", nil) if done then done() end end
  end)
end
local function easeOutBack(t)
  local c1, c3 = 1.70158, 2.70158
  return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end
local function easeOut(t) return 1 - (1 - t) ^ 3 end

---------------------------------------------------------------------------
-- the pill
---------------------------------------------------------------------------
local pill, card

local function place(f, where)
  f:ClearAllPoints()
  if where == "top" then f:SetPoint("TOP", UIParent, "TOP", 0, -90)
  else f:SetPoint("CENTER", UIParent, "CENTER", 0, 120) end
end

-- (1.4.29) the pill looks like the other popups (login, deaths…): 380 × 72, icon tile, small
-- kicker, title and a line of text, with Show and Close on the right
local function makePill()
  local f = CreateFrame("Frame", "ChillanRecapPill", UIParent)
  f:SetSize(PILL_W, PILL_H)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:Hide()
  f.panel = UI.OverlayPanel(f, C.window, C.activeLine, false)
  f.panel:SetAllPoints()
  f.panel:SetFrameLevel(f:GetFrameLevel())
  f.tile = UI.Panel(f, C.active, nil, false)
  f.tile:SetSize(44, 44)
  f.tile:SetPoint("LEFT", 14, 0)
  f.icon = UI.Icon(f.tile, "Star", 22, C.gold)
  f.icon:SetPoint("CENTER")
  f.edge = f:CreateTexture(nil, "OVERLAY")
  f.edge:SetWidth(3)
  f.edge:SetPoint("TOPLEFT", 0, 0)
  f.edge:SetPoint("BOTTOMLEFT", 0, 0)
  UI.Track(f.edge):SetColorTexture(hex(C.gold))
  f.kind = UI.Text(f, 10, "semi", C.dim)
  f.kind:SetPoint("TOPLEFT", f.tile, "TOPRIGHT", 14, -1)
  f.text = UI.Text(f, 15, "semi", C.text)
  f.text:SetPoint("LEFT", f.tile, "RIGHT", 14, 1)
  f.sub = UI.Text(f, 12, nil, C.muted)
  f.sub:SetPoint("BOTTOMLEFT", f.tile, "BOTTOMRIGHT", 14, 1)
  f.close = UI.Button(f, 58, 28, "Close", "secondary", function() R:ClosePill(true) end)
  f.close:SetPoint("RIGHT", -12, 0)
  f.show = UI.Button(f, 58, 28, "Show", "primary", function() R:OpenFromPill() end)
  f.show:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
  for _, fs in ipairs({ f.kind, f.text, f.sub }) do
    fs:SetPoint("RIGHT", f.show, "LEFT", -8, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
  end
  return f
end

-- (one pill at a time: a newer recap waits until the current one is dealt with)
local queue = {}

function R:Prompt(recap)
  if not enabled() or not recap then return end
  nextId = nextId + 1
  recap.id = nextId
  self.saved[recap.id] = recap
  if pill and pill:IsShown() or (card and card:IsShown()) then queue[#queue + 1] = recap return end
  self:ShowPill(recap)
end

function R:ShowPill(recap)
  pill = pill or makePill()
  pill.recap = recap
  pill.kind:SetText((recap.kicker or "RECAP"):upper())
  pill.text:SetText(recap.prompt)
  pill.sub:SetText(recap.teaser or recap.title or "")
  place(pill, recap.where)
  pill:SetAlpha(0)
  pill:SetScale(0.3)
  pill:Show()
  animate(pill, 0.35, function(t)
    pill:SetScale(math.max(0.05, 0.3 + 0.7 * easeOutBack(t)))
    pill:SetAlpha(math.min(1, t * 2))
  end)
  local token = {}
  pill.timer = token
  C_Timer.After(IGNORE_SECS, function() if pill.timer == token then R:ClosePill(false, true) end end)
end

local function nextInQueue()
  local r = table.remove(queue, 1)
  if r then C_Timer.After(0.6, function() R:ShowPill(r) end) end
end

-- Close (or ignored): the pill slides up and fades. Ignored ones leave a line in the feed.
function R:ClosePill(byHand, ignored)
  if not pill or not pill:IsShown() then return end
  pill.timer = nil
  local recap = pill.recap
  local p, rel, rp, x, y = pill:GetPoint(1)
  animate(pill, 0.25, function(t)
    pill:SetAlpha(1 - t)
    if p then pill:SetPoint(p, rel, rp, x, (y or 0) + 24 * easeOut(t)) end
  end, function()
    pill:Hide()
    place(pill, recap and recap.where)
    if ignored and recap then R:FeedLine(recap) end
    if recap and recap.onClose and byHand then pcall(recap.onClose) end
    nextInQueue()
  end)
end

function R:FeedLine(recap)
  if not (ns.EventWindow and ns.EventWindow.Add) then return end
  local line = UI.InlineIcon("Star", C.gold, 12) .. "  " .. ns.Colorize(recap.title, C.text)
    .. ns.Colorize(" recap ready · ", C.text2) .. "|Hchillanrecap:" .. recap.id .. "|h" .. ns.Colorize("[Show]", C.gold) .. "|h"
  pcall(ns.EventWindow.Add, ns.EventWindow, "ev", line)
end

function R:OpenFromPill()
  if not pill then return end
  pill.timer = nil
  local recap = pill.recap
  pill:Hide()
  if recap and recap.onShow then pcall(recap.onShow) end
  self:Open(recap and recap.id)
end

---------------------------------------------------------------------------
-- the card
---------------------------------------------------------------------------
local function makeCard()
  local f = CreateFrame("Frame", "ChillanRecapCard", UIParent)
  f:SetSize(CARD_W, 300)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:Hide()
  f.shadow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  f.shadow:SetTexture(ns.TEX .. "Shadow")
  f.shadow:SetPoint("TOPLEFT", -30, 24)
  f.shadow:SetPoint("BOTTOMRIGHT", 30, -36)
  f.shadow:SetVertexColor(0, 0, 0, 0.8)
  f.panel = UI.OverlayPanel(f, C.window, C.activeLine, false)
  f.panel:SetAllPoints()
  f.panel:SetFrameLevel(f:GetFrameLevel())
  f.body = CreateFrame("Frame", nil, f)
  f.body:SetAllPoints()
  f.body:SetFrameLevel(f:GetFrameLevel() + 2)
  local b = f.body
  f.title = UI.Text(b, 15, "semi", C.text)
  f.title:SetPoint("TOPLEFT", 16, -14)
  f.title:SetPoint("RIGHT", -110, 0)
  f.title:SetJustifyH("LEFT")
  f.title:SetWordWrap(false)
  f.sub = UI.Text(b, 11, nil, C.dim)
  f.sub:SetPoint("TOPRIGHT", -16, -17)
  f.sub:SetJustifyH("RIGHT")
  f.line1 = b:CreateTexture(nil, "ARTWORK")
  f.line1:SetHeight(1)
  f.line1:SetPoint("TOPLEFT", 1, -42)
  f.line1:SetPoint("TOPRIGHT", -1, -42)
  UI.Track(f.line1):SetColorTexture(hex(C.line))
  f.cells = {}
  local cw = (CARD_W - 32) / 4
  for i = 1, 4 do
    local c = {}
    c.v = UI.Text(b, 20, "semi", C.text)
    c.v:SetPoint("TOPLEFT", 16 + (i - 1) * cw, -54)
    c.k = UI.Text(b, 11, nil, C.dim)
    c.k:SetPoint("TOPLEFT", c.v, "BOTTOMLEFT", 0, -3)
    c.k:SetWidth(cw - 6)
    c.k:SetJustifyH("LEFT")
    c.k:SetWordWrap(false)
    f.cells[i] = c
  end
  f.momHead = UI.Text(b, 11, nil, C.dim)
  f.momHead:SetPoint("TOPLEFT", 16, -112)
  f.momHead:SetText("Best moments")
  f.moms = {}
  for i = 1, 4 do
    local m = {}
    m.icon = UI.Icon(b, "Star", 13, C.gold)
    m.icon:SetPoint("TOPLEFT", 16, -130 - (i - 1) * 20)
    m.text = UI.Text(b, 12, nil, C.text2)
    m.text:SetPoint("LEFT", m.icon, "RIGHT", 8, 0)
    m.text:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    m.text:SetJustifyH("LEFT")
    m.text:SetWordWrap(false)
    f.moms[i] = m
  end
  f.cmpHead = UI.Text(b, 11, nil, C.dim)
  f.barBg = b:CreateTexture(nil, "ARTWORK")
  f.barBg:SetHeight(6)
  UI.Track(f.barBg):SetColorTexture(hex(C.line))
  f.bar = b:CreateTexture(nil, "OVERLAY")
  f.bar:SetHeight(6)
  UI.Track(f.bar):SetColorTexture(hex(C.gold))
  f.cmpText = UI.Text(b, 11, nil, C.dim)
  f.share = UI.Button(b, 110, 28, "Share to gang", "secondary", function() R:Share() end)
  f.close = UI.Button(b, 70, 28, "Close", "secondary", function() R:CloseCard() end)
  f.extra = UI.Button(b, 80, 28, "", "primary", function() if f.extraFn then f.extraFn() end end)
  return f
end

-- numbers count up: "1h 04m" and "16/19" style values animate their first number
local function countText(v, t)
  if type(v) ~= "string" then return tostring(v) end
  local pre, num, post = v:match("^([^%d]*)(%d+)(.*)$")
  if not num or #num > 6 then return v end
  return pre .. math.floor(tonumber(num) * t + 0.5) .. post
end

function R:Open(id)
  local recap = id and self.saved[id]
  if not recap then return end
  card = card or makeCard()
  local f = card
  f.recap = recap
  f.title:SetText(recap.title)
  f.sub:SetText(recap.sub or "")
  for i, c in ipairs(f.cells) do
    local cell = recap.nums[i]
    c.v:SetText(cell and cell[1] or "")
    c.k:SetText(cell and cell[2] or "")
    c.v:SetTextColor(hex((cell and cell[3]) or C.text))
  end
  local y = -130
  local shown = 0
  for i, m in ipairs(f.moms) do
    local mo = recap.moments[i]
    if mo then
      m.icon:SetTexture(ns.TEX .. "Icon" .. (mo[1] or "Star"))
      UI.Track(m.icon):SetVertexColor(hex(mo[3] or C.gold))
      m.text:SetText(mo[2])
      m.icon:Show() m.text:Show()
      shown = shown + 1
    else m.icon:Hide() m.text:Hide() end
  end
  f.momHead:SetShown(shown > 0)
  y = (shown > 0) and (-130 - shown * 20 - 8) or -112
  local cmp = recap.compare
  f.cmpHead:ClearAllPoints() f.barBg:ClearAllPoints() f.bar:ClearAllPoints() f.cmpText:ClearAllPoints()
  if cmp then
    f.cmpHead:SetPoint("TOPLEFT", 16, y)
    f.cmpHead:SetText(cmp.label)
    f.barBg:SetPoint("TOPLEFT", 16, y - 18)
    f.barBg:SetPoint("TOPRIGHT", -16, y - 18)
    f.bar:SetPoint("TOPLEFT", f.barBg, "TOPLEFT")
    f.bar:SetWidth(1)
    f.cmpText:SetPoint("TOPLEFT", 16, y - 30)
    f.cmpText:SetText(cmp.text or "")
    f.cmpHead:Show() f.barBg:Show() f.bar:Show() f.cmpText:Show()
    y = y - 52
  else
    f.cmpHead:Hide() f.barBg:Hide() f.bar:Hide() f.cmpText:Hide()
  end
  f.share:ClearAllPoints() f.close:ClearAllPoints() f.extra:ClearAllPoints()
  f.close:SetPoint("TOPRIGHT", -16, y - 6)
  f.share:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
  f.share:SetShown(recap.share ~= nil)
  if recap.extra then
    f.extra:SetLabel(recap.extra.label)
    f.extraFn = recap.extra.fn
    f.extra:SetPoint("RIGHT", recap.share and f.share or f.close, "LEFT", -6, 0)
    f.extra:Show()
  else f.extra:Hide() end
  local h = -(y - 6) + 28 + 14
  place(f, recap.where)
  f:SetHeight(h)
  -- grow: from a pill-sized sliver to the full card, then numbers count up and the bar fills
  f.body:SetAlpha(0)
  f:SetAlpha(1)
  f:Show()
  local fullW = CARD_W
  animate(f, 0.4, function(t)
    local e = easeOut(t)
    f:SetSize(PILL_W + (fullW - PILL_W) * e, PILL_H + (h - PILL_H) * e)
  end, function()
    f:SetSize(fullW, h)
    animate(f.body, 0.9, function(t)
      f.body:SetAlpha(math.min(1, t * 3))
      local e = easeOut(t)
      for i, c in ipairs(f.cells) do
        local cell = recap.nums[i]
        if cell then c.v:SetText(countText(cell[1], e)) end
      end
      if cmp then f.bar:SetWidth(math.max(1, (f.barBg:GetWidth() or (fullW - 32)) * math.min(1, cmp.pct or 0) * e)) end
    end)
  end)
end

function R:CloseCard()
  if not card or not card:IsShown() then return end
  local recap = card.recap
  animate(card, 0.2, function(t) card:SetAlpha(1 - t) end, function()
    card:Hide()
    card:SetAlpha(1)
    if recap and recap.onClose then pcall(recap.onClose) end
    nextInQueue()
  end)
end

function R:Share()
  local recap = card and card.recap
  if not recap or not recap.share then return end
  ns.Data:SendChat(recap.share)
  card.share:SetLabel("Shared")
  C_Timer.After(2, function() if card then card.share:SetLabel("Share to gang") end end)
end

---------------------------------------------------------------------------
-- recap builders
---------------------------------------------------------------------------
local function money(c) return ns.Money(c or 0) end
local function secs(n)
  n = math.floor(n or 0)
  if n < 60 then return n .. "s" end
  if n < 3600 then return string.format("%d:%02d", math.floor(n / 60), n % 60) end
  return ns.Duration(n)
end
local function pct(a, b) if not b or b <= 0 then return 0 end return math.max(0, math.min(1, a / b)) end

-- a play session (Tracker summary + Pulse session)
function R.Session(sum, previous)
  if not sum then return nil end
  local P = ns.Pulse
  local s = P and P.sess or {}
  local at60 = (ns.S(UnitLevel, "player") or 0) >= 60
  local nums = { { ns.Duration(sum.online or 0), "played" } }
  if at60 and not previous then
    local hk, honor = P and P.SessionHonor and P:SessionHonor()
    nums[2] = { tostring(hk or sum.kills or 0), "honorable kills" }
    nums[3] = { tostring(s.bosses or 0), "bosses" }
  else
    nums[2] = { tostring(sum.quests or 0), "quests" }
    nums[3] = { ((sum.levels or 0) > 0 and "+" or "") .. (sum.levels or 0), (sum.levels == 1) and "level" or "levels" }
  end
  nums[4] = { "+" .. money(sum.gold), "gold earned" }
  local moments = {}
  local best = sum.best or (not previous and s.best)
  if best and best.link then moments[#moments + 1] = { "Diamond", "Best drop: " .. best.link } end
  if (sum.kills or 0) > 0 then moments[#moments + 1] = { "Target", ns.Plural(sum.kills, "Alliance kill") } end
  if (sum.deaths or 0) > 0 then moments[#moments + 1] = { "Skull", ns.Plural(sum.deaths, "death") .. (sum.killer and (" · last to " .. sum.killer) or ""), C.red } end
  if not previous and P and P.TopRep then
    local fac, n = P:TopRep()
    if fac then moments[#moments + 1] = { "Up", "+" .. ns.Num(n) .. " reputation with " .. fac, C.green } end
  end
  -- against your own longest session
  ns.db.sessRec = ns.db.sessRec or {}
  local rec = ns.db.sessRec.online or 0
  local cmp = rec > 0 and {
    label = "This session vs your longest (" .. ns.Duration(rec) .. ")",
    pct = pct(sum.online or 0, rec),
    text = (sum.online or 0) >= rec and "Your longest session yet" or (math.floor(pct(sum.online or 0, rec) * 100) .. " % of your record"),
  } or nil
  local share = "Session recap: " .. ns.Duration(sum.online or 0) .. " · " .. (nums[2][1] .. " " .. nums[2][2]) .. " · " .. (nums[3][1] .. " " .. nums[3][2])
    .. " · +" .. money(sum.gold) .. ((best and best.link) and (" · best drop " .. best.link) or "")
  local teaser = ns.Duration(sum.online or 0) .. " · " .. nums[2][1] .. " " .. nums[2][2] .. " · +" .. money(sum.gold)
  return { kind = "session", where = "center", kicker = previous and "Welcome back" or "Session", teaser = teaser,
    prompt = previous and "Show last session recap" or "Show session recap",
    title = previous and "Last session" or "Session recap",
    sub = ns.ShortName(sum.char or "") .. (previous and sum.at and (" · " .. date("%d.%m %H:%M", sum.at)) or ""),
    nums = nums, moments = moments, compare = cmp, share = share }
end

-- a dungeon or raid (Extras:RunSummary)
function R.Run(x)
  if not x then return nil end
  local nums = {
    { ns.Duration(x.dur or 0), "time inside" },
    { (x.bosses or 0) .. ((x.total and x.total > 0) and ("/" .. x.total) or ""), "bosses" },
    { tostring(x.deaths or 0), (x.deaths == 1) and "death" or "deaths", (x.deaths or 0) > 0 and C.red or nil },
    { money(x.value or 0), "loot value" },
  }
  local moments = {}
  if x.fast and x.fastSecs then moments[#moments + 1] = { "Clock", "Fastest boss: " .. x.fast .. " " .. secs(x.fastSecs) } end
  if x.drop then moments[#moments + 1] = { "Diamond", "Best drop: " .. x.drop } end
  if x.record then moments[#moments + 1] = { "Trophy", "New gang record for " .. (ns.ShortDungeonPlain and ns.ShortDungeonPlain(x.name) or x.name), C.gold } end
  if x.floor and (x.floorN or 0) > 0 then moments[#moments + 1] = { "Skull", "Floor inspector: " .. x.floor .. " (" .. ns.Plural(x.floorN, "death") .. ")", C.red } end
  if (x.wipes or 0) > 0 then moments[#moments + 1] = { "Skull", ns.Plural(x.wipes, "wipe"), C.red } end
  if (x.xp or 0) > 0 and #moments < 4 then moments[#moments + 1] = { "Up", ns.Num(x.xp) .. " XP", C.green } end
  local cmp
  if x.best and x.best > 0 then
    local faster = (x.dur or 0) <= x.best
    cmp = { label = "Your run vs the gang's best (" .. ns.Duration(x.best) .. ")",
      pct = faster and 1 or pct(x.best, x.dur or 1),
      text = faster and "Faster than the gang record" or (ns.Duration((x.dur or 0) - x.best) .. " slower than the gang record") }
  end
  local name = x.name or "Dungeon"
  local share = (x.raid and "Raid" or "Dungeon") .. " recap: " .. name .. " · " .. nums[2][1] .. " bosses · " .. ns.Duration(x.dur or 0)
    .. " · " .. ns.Plural(x.deaths or 0, "death") .. ((x.drop) and (" · best drop " .. x.drop) or "")
  local teaser = nums[2][1] .. " bosses · " .. nums[1][1] .. " · " .. ns.Plural(x.deaths or 0, "death")
  return { kind = "run", where = "top", kicker = (x.raid and "Raid" or "Dungeon") .. " complete", teaser = (x.name or "") .. " · " .. teaser, prompt = "Show " .. (x.raid and "raid" or "dungeon") .. " recap",
    title = name, sub = (x.raid and "Raid" or "Dungeon") .. ((x.total and x.bosses and x.bosses >= x.total) and " · full clear" or ""),
    nums = nums, moments = moments, compare = cmp, share = share }
end

-- a battleground (Pulse:BGSummary)
function R.BG(x)
  if not x then return nil end
  local me = x.me or {}
  local nums = {
    { tostring(me.hk or 0), "HKs" },
    { tostring(me.deaths or 0), (me.deaths == 1) and "death" or "deaths", (me.deaths or 0) > 0 and C.red or nil },
    { tostring(me.kb or 0), "killing blows" },
    { "+" .. ns.Num(x.honor or 0), "honor" },
  }
  local moments = {}
  if (x.best or 0) >= 3 then moments[#moments + 1] = { "Target", "Best killing streak: " .. x.best } end
  if x.hero and x.heroFlags then
    moments[#moments + 1] = { "Crown", x.hero .. ": " .. ns.Plural(x.heroFlags.cap or 0, "flag capture") .. ((x.heroFlags.ret or 0) > 0 and (", " .. ns.Plural(x.heroFlags.ret, "return")) or ""), C.gold }
  end
  if x.mvp and #(x.gang or {}) >= 2 then moments[#moments + 1] = { "Trophy", "Gang MVP: " .. x.mvp.name .. " (" .. ns.Plural(x.mvp.hk or 0, "HK") .. ")", C.gold } end
  if x.revs and #x.revs > 0 then moments[#moments + 1] = { "Skull", "Revenge on " .. table.concat(x.revs, ", ") } end
  if (x.streak or 0) >= 2 and x.won then moments[#moments + 1] = { "Up", x.streak .. " wins in a row today", C.green } end
  -- against your own best HKs in this battleground
  ns.db.bgRec = ns.db.bgRec or {}
  local rec = ns.db.bgRec[x.name or "?"]
  local cmp
  if rec and rec > 0 then
    cmp = { label = "Your HKs vs your best in " .. (x.name or "this battleground") .. " (" .. rec .. ")",
      pct = pct(me.hk or 0, rec), text = (me.hk or 0) >= rec and "New personal best" or ((rec - (me.hk or 0)) .. " HKs from your best") }
  end
  if (me.hk or 0) > (rec or 0) then ns.db.bgRec[x.name or "?"] = me.hk end
  local score = x.score and (" " .. x.score) or ""
  local result = (x.won == true and "Won" or x.won == false and "Lost" or "Ended") .. score
  local share = "Battleground recap: " .. result .. " " .. (x.name or "") .. " · " .. ns.Plural(me.hk or 0, "HK") .. " · " .. ns.Plural(me.deaths or 0, "death")
    .. " · +" .. ns.Num(x.honor or 0) .. " honor"
  return { kind = "bg", where = "top", kicker = "Battleground", teaser = (x.name or "") .. " · " .. result .. " · " .. ns.Plural(me.hk or 0, "HK"), prompt = "Show battleground recap",
    title = (x.name or "Battleground") .. " · " .. result, sub = x.dur and ns.Duration(x.dur) or "",
    nums = nums, moments = moments, compare = cmp, share = share }
end

---------------------------------------------------------------------------
-- hooks
---------------------------------------------------------------------------
function R:Init()
  ns:Listen("RUN_CARD", function(x) local r = R.Run(x) if r then R:Prompt(r) end end)
  ns:Listen("BG_CARD", function(x) local r = R.BG(x) if r then C_Timer.After(1, function() R:Prompt(r) end) end end)
end

-- logout: the game doesn't let an addon stop the logout countdown (CancelLogout is protected), so
-- the card simply opens while the countdown runs; the same recap is offered again at the next login
function R:Logout(sum)
  local r = R.Session(sum, false)
  if not r then return false end
  r.kicker = "Logging out"
  ns.db.sessRec = ns.db.sessRec or {}
  if (sum.online or 0) > (ns.db.sessRec.online or 0) then ns.db.sessRec.online = sum.online end
  R:Prompt(r)
  return true
end

function R:Login(last)
  local r = R.Session(last, true)
  if r then R:Prompt(r) return true end
  return false
end
