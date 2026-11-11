-- Chillan? – own ding: "Gratz on the ding" box, then the level recap
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

local box, recapFrame
local pending -- recap waiting for combat to end

local function inCombat()
  if InCombatLockdown and InCombatLockdown() then return true end
  return ns.S(UnitAffectingCombat, "player") and true or false
end

local function panel(name, w, h, pos)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetSize(w, h)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  UI.Movable(f, pos, function(fr) fr:SetPoint("CENTER", UIParent, "CENTER", 0, 170) end)
  f.panel = UI.OverlayPanel(f, C.window, C.activeLine, false)
  f.panel:SetAllPoints()
  f.panel:SetFrameLevel(f:GetFrameLevel())
  f:Hide()
  return f
end

---------------------------------------------------------------------------
-- 1) the small box
---------------------------------------------------------------------------
local function createBox()
  local f = panel("ChillanDingBox", 500, 132, "dingbox")
  f.tile = UI.Panel(f, C.active, nil, false)
  f.tile:SetSize(52, 52)
  f.tile:SetPoint("TOPLEFT", 20, -20)
  f.icon = UI.Icon(f.tile, "Up", 26, C.green)
  f.icon:SetPoint("CENTER")
  f.kicker = UI.Text(f, 11, "semi", C.green)
  f.kicker:SetPoint("TOPLEFT", f.tile, "TOPRIGHT", 16, -2)
  f.title = UI.Text(f, 18, "bold", C.text)
  f.title:SetPoint("TOPLEFT", f.kicker, "BOTTOMLEFT", 0, -5)
  f.title:SetPoint("RIGHT", -20, 0)
  f.text = UI.Text(f, 12, nil, C.text2)
  f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -5)
  f.text:SetPoint("RIGHT", -20, 0)
  f.show = UI.Button(f, 330, 36, "Show level recap", "primary", function()
    f:Hide()
    ns.LevelRecapCard:ShowRecap(f.recap)
  end)
  f.show:SetPoint("BOTTOMLEFT", 20, 20)
  f.close = UI.Button(f, 120, 36, "Close", "ghost", function() f:Hide() end)
  f.close:SetPoint("BOTTOMRIGHT", -20, 20)
  return f
end

---------------------------------------------------------------------------
-- 2) the recap
---------------------------------------------------------------------------
local function createRecap()
  local f = panel("ChillanLevelRecap", 540, 470, "levelrecap")
  f.kicker = UI.Text(f, 11, "semi", C.accent)
  f.kicker:SetPoint("TOPLEFT", 22, -20)
  f.kicker:SetText("LEVEL RECAP")
  f.title = UI.Text(f, 20, "bold", C.text)
  f.title:SetPoint("TOPLEFT", f.kicker, "BOTTOMLEFT", 0, -4)
  f.sub = UI.Text(f, 12, nil, C.text2)
  f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
  f.sub:SetPoint("RIGHT", -22, 0)
  f.x = UI.IconButton(f, 24, "Close", nil, function() f:Hide() end)
  f.x:SetPoint("TOPRIGHT", -10, -10)
  f.x.panel:SetColors(nil, nil)
  f.x.icon:SetVertexColor(hex(C.dim))
  f.cards = {}
  for i = 1, 6 do
    local c = UI.Panel(f, C.card, C.line, false)
    c:SetSize(156, 74)
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    c:SetPoint("TOPLEFT", 22 + col * 166, -92 - row * 84)
    c.big = UI.Text(c, 19, "bold", C.text)
    c.big:SetPoint("TOPLEFT", 12, -10)
    c.label = UI.Text(c, 11, nil, C.text2)
    c.label:SetPoint("TOPLEFT", c.big, "BOTTOMLEFT", 0, -3)
    c.note = UI.Text(c, 11, nil, C.dim)
    c.note:SetPoint("TOPLEFT", c.label, "BOTTOMLEFT", 0, -3)
    c.note:SetPoint("RIGHT", -8, 0)
    c.note:SetWordWrap(false)
    f.cards[i] = c
  end
  f.list = UI.Panel(f, C.card, C.line, false)
  f.list:SetPoint("TOPLEFT", 22, -268)
  f.list:SetPoint("RIGHT", -22, 0)
  f.list:SetHeight(116)
  f.rows = {}
  for i = 1, 4 do
    local k = UI.Text(f.list, 12, nil, C.dim)
    k:SetPoint("TOPLEFT", 14, -12 - (i - 1) * 24)
    local v = UI.Text(f.list, 12, nil, C.text)
    v:SetPoint("TOPLEFT", 134, -12 - (i - 1) * 24)
    v:SetPoint("RIGHT", -12, 0)
    v:SetWordWrap(false)
    f.rows[i] = { k = k, v = v }
  end
  f.share = UI.Button(f, 360, 36, "Share in gang chat", "primary", function()
    if f.recap then
      ns.Data:SendChat(ns.LevelRecap:ShareText(f.recap))
      f.share:SetLabel("Shared!")
    end
  end)
  f.share:SetPoint("BOTTOMLEFT", 22, 20)
  f.close = UI.Button(f, 120, 36, "Close", "ghost", function() f:Hide() end)
  f.close:SetPoint("BOTTOMRIGHT", -22, 20)
  return f
end

local function card(c, big, label, note, color, noteColor)
  c.big:SetText(big)
  c.big:SetTextColor(hex(color or C.text))
  c.label:SetText(label)
  c.note:SetText(note or "")
  c.note:SetTextColor(hex(noteColor or C.dim))
end

local function money(v)
  return (ns.Money(v or 0) or "0c")
end

local L = {}
ns.LevelRecapCard = L

function L:ShowRecap(x)
  if not x then return end
  recapFrame = recapFrame or createRecap()
  local f = recapFrame
  f.recap = x
  f.title:SetText("Level " .. x.from .. " → " .. x.to)
  local where = {}
  for _, z in ipairs(x.zones or {}) do if z then where[#where + 1] = z end end
  f.sub:SetText(((#where > 0) and ("Mostly in " .. table.concat(where, " and ")) or "")
    .. ((x.sessions or 0) > 1 and (" · " .. x.sessions .. " sessions") or "")
    .. (x.partial and ns.Colorize("  · counted since Chillan? started tracking", C.dim) or ""))

  local vs = x.vsPrev
  card(f.cards[1], ns.Duration(x.time or 0), "time on this level",
    vs and (vs < 0 and (ns.Duration(-vs) .. " faster than " .. (x.from - 1)) or (ns.Duration(vs) .. " slower than " .. (x.from - 1))) or nil,
    nil, vs and (vs < 0 and C.green or C.red))
  card(f.cards[2], x.xph and ns.Num(x.xph) or "–", "XP per hour", (x.xph and x.bestXph) and "best yet" or nil, nil, C.green)
  card(f.cards[3], tostring(x.deaths or 0), "deaths",
    (x.deaths or 0) > 0 and ((x.alli or 0) .. " to Alliance, " .. math.max(0, x.deaths - (x.alli or 0)) .. " to mobs") or "clean level!",
    (x.deaths or 0) > 0 and C.red or C.green)
  card(f.cards[4], tostring(x.kills or 0), "mobs killed", x.topMob and ("most: " .. x.topMob .. " (" .. x.topMobN .. ")") or nil)
  card(f.cards[5], "+" .. money(x.money), "money gained", (x.repairs or 0) > 0 and (money(x.repairs) .. " spent on repairs") or nil, C.gold)
  card(f.cards[6], tostring(x.quests or 0), "quests completed", x.questShare and (x.questShare .. " % of the XP") or nil)

  local rows = {}
  if x.loot and x.loot.id then
    local name = (C_Item and C_Item.GetItemInfo or GetItemInfo)(x.loot.id)
    rows[#rows + 1] = { "Best loot", ns.Colorize("[" .. (name or "item") .. "]", ns.QUALITY_HEX[x.loot.q] or C.text) }
  end
  if x.with then
    local p = ns:GetPerson(x.with)
    if p then rows[#rows + 1] = { "Played with", ns:ShortWho(p) .. ns.Colorize("  (" .. ns.Duration(x.withSecs or 0) .. " in the same group)", C.dim) } end
  end
  if x.rank then
    local ord = ({ "1st", "2nd", "3rd" })[x.rank.place] or (x.rank.place .. "th")
    local fp = x.rank.fastest and ns:GetPerson(x.rank.fastest.pid)
    rows[#rows + 1] = { "Gang ranking", ord .. " fastest " .. x.from .. " → " .. x.to .. " of " .. x.rank.of
      .. ((x.rank.place > 1 and fp) and ns.Colorize("  (" .. ns:PersonFirst(fp) .. ": " .. ns.Duration(x.rank.fastest.t) .. ")", C.dim) or "") }
  end
  local also = {}
  if (x.ach or 0) > 0 then also[#also + 1] = x.ach .. " achievement" .. (x.ach == 1 and "" or "s") end
  if x.dgs and #x.dgs > 0 then also[#also + 1] = #x.dgs .. " dungeon" .. (#x.dgs == 1 and "" or "s") .. " (" .. table.concat(x.dgs, ", ") .. ")" end
  if #also > 0 then rows[#rows + 1] = { "Also this level", table.concat(also, " · ") } end
  for i, r in ipairs(f.rows) do
    local d = rows[i]
    r.k:SetText(d and d[1] or "")
    r.v:SetText(d and d[2] or "")
  end
  f.list:SetShown(#rows > 0)
  f.list:SetHeight(math.max(30, #rows * 24 + 14))
  f:SetHeight(268 + (#rows > 0 and (#rows * 24 + 14 + 14) or 0) + 76)
  f.share:SetLabel("Share in gang chat")
  f:Show()
end

function L:ShowBox(x)
  if not x then return end
  if ns.db.settings.combatQueue ~= false and inCombat() then pending = x return end
  box = box or createBox()
  box.recap = x
  local name = ns:PersonFirst(ns:GetPerson(ns.pid, true)) or (ns.S(UnitName, "player"))
  box.kicker:SetText("DING! LEVEL " .. x.to)
  box.title:SetText("Gratz on the ding, " .. tostring(name) .. "!")
  box.text:SetText(x.time and ("That one took " .. ns.Duration(x.time) .. ". Want to see how it went?") or "Want to see how the level went?")
  box:Show()
end

ns:Listen("LEVEL_RECAP", function(x) L:ShowBox(x) end)
ns:On("PLAYER_REGEN_ENABLED", function()
  if pending then
    local x = pending
    pending = nil
    C_Timer.After(1, function() L:ShowBox(x) end)
  end
end)
