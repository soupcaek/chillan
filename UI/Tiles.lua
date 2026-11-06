-- Chillan? – små stat-rubrikker som kan festes under minibaren
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

local T = {}
ns.Tiles = T

local MAX = 8
local PER_ROW = 4
local W, H, GAP = 104, 44, 6

local function me() return ns:GetPerson(ns.pid, true) end
local function s3() return ns.Tracker:S3Data() end
local function today(key) return ((ns.db.cnt or {})[key] or {})[date("%Y-%m-%d")] or 0 end

local startMoney, startHK
local function hk()
  if not GetPVPLifetimeStats then return nil end
  local ok, v = pcall(GetPVPLifetimeStats)
  if ok and type(v) == "number" and not ns.isSecret(v) then return v end
end

local function goldText(copper)
  if not copper then return "–" end
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  if g > 0 then return ns.Num(g) .. "g " .. s .. "s" end
  return s .. "s " .. (copper % 100) .. "c"
end

local function minDurability()
  if not GetInventoryItemDurability then return nil end
  local low
  for slot = 1, 18 do
    local ok, cur, max = pcall(GetInventoryItemDurability, slot)
    if ok and cur and max and max > 0 and not ns.isSecret(cur) then
      local pct = cur / max * 100
      if not low or pct < low then low = pct end
    end
  end
  return low
end

local function freeBags()
  local free, total = 0, 0
  local api = C_Container
  for bag = 0, 4 do
    local ok1, f = pcall(api and api.GetContainerNumFreeSlots or GetContainerNumFreeSlots, bag)
    local ok2, n = pcall(api and api.GetContainerNumSlots or GetContainerNumSlots, bag)
    if ok1 and type(f) == "number" then free = free + f end
    if ok2 and type(n) == "number" then total = total + n end
  end
  return free, total
end

-- Alle rubrikkene: key, navn i menyen, funksjon som gir verdi + undertekst (+ ev. farge)
T.DEFS = {
  { key = "level", name = "Level og % til neste", get = function()
    local d, c = s3(), ns.Tracker:MyChar() or {}
    local pct = ns.Pct(d.xp, d.xpMax)
    return tostring(c.level or "?"), pct and (pct .. " % til neste") or "level"
  end },
  { key = "xph", name = "XP per time", get = function()
    local rate, label = ns.St:XPRate(me())
    return rate and ns.Num(rate) or "–", "XP/t" .. (label == "denne økten" and " · økt" or label and " · uke" or "")
  end },
  { key = "eta", name = "Tid til neste level", get = function()
    local eta = ns.St:ETA(me())
    return eta and ns.Duration(eta) or "–", "til neste level"
  end },
  { key = "gold", name = "Gull (+/− denne økta)", get = function()
    local m = ns.S(GetMoney)
    if type(m) ~= "number" then return "–", "gull" end
    startMoney = startMoney or m
    local diff = m - startMoney
    local sub = diff == 0 and "gull" or ((diff > 0 and "+" or "−") .. goldText(math.abs(diff)) .. " i økta")
    return goldText(m), sub, diff > 0 and C.green or diff < 0 and C.red or nil
  end },
  { key = "rested", name = "Rested XP", get = function()
    local d = s3()
    local pct = ns.Pct(d.rested or 0, d.xpMax)
    return pct and (pct .. " %") or "–", "rested av level"
  end },
  { key = "session", name = "Økt-tid", get = function()
    return ns.Duration(s3().sessSec or 0), "denne økta"
  end },
  { key = "today", name = "Online i dag", get = function()
    return ns.Duration(s3().today or 0), "online i dag"
  end },
  { key = "played", name = "Total spilletid", get = function()
    local p = ns:PersonPlayed(me())
    return p > 0 and ns.Duration(p) or "–", "/played"
  end },
  { key = "quests", name = "Quests i dag", get = function()
    return tostring(today("questsDay")), "quests i dag"
  end },
  { key = "kills", name = "Drap (økt / uke)", get = function()
    local now = hk()
    startHK = startHK or now
    local sess = (now and startHK) and (now - startHK) or 0
    return tostring(sess), "drap i økta · " .. ns:WeekStat(me(), "Kills") .. " uka"
  end },
  { key = "deaths", name = "Dødsfall i dag", get = function()
    local n = today("deathsDay")
    return tostring(n), "dødsfall i dag", n > 0 and C.red or nil
  end },
  { key = "ilvl", name = "Item level", get = function()
    local v = s3().ilvl
    return v and tostring(math.floor(v)) or "–", "item level"
  end },
  { key = "dura", name = "Holdbarhet", get = function()
    local low = minDurability()
    if not low then return "–", "holdbarhet" end
    local col = low < 20 and C.red or low < 50 and C.amber or nil
    return math.floor(low) .. " %", "laveste utstyr", col
  end },
  { key = "bags", name = "Ledige bag-plasser", get = function()
    local free, total = freeBags()
    return tostring(free), "ledig av " .. total, free <= 3 and C.red or free <= 8 and C.amber or nil
  end },
  { key = "ach", name = "Achievement-poeng", get = function()
    return tostring(ns.Ach and ns.Ach:Points(ns.pid) or 0), "achievement-poeng"
  end },
  { key = "streak", name = "Streak", get = function()
    local n = s3().streak or 0
    return n .. (n == 1 and " dag" or " dager"), "på rad"
  end },
  { key = "event", name = "Neste avtale", get = function()
    local ev = ns.db.events and ns.db.events[#ns.db.events]
    if not ev then return "–", "ingen avtaler" end
    return ev.title or "Avtale", (ev.when and ev.when ~= "") and ev.when or "avtale"
  end },
}
T.byKey = {}
for _, d in ipairs(T.DEFS) do T.byKey[d.key] = d end

function T:List()
  local S = ns.db.settings
  if S.tiles == nil then S.tiles = { "level", "xph", "eta" } end
  return S.tiles
end

function T:IsPinned(key)
  for _, k in ipairs(self:List()) do if k == key then return true end end
  return false
end

function T:Toggle(key)
  local list = self:List()
  for i, k in ipairs(list) do
    if k == key then table.remove(list, i) self:Layout() return false end
  end
  if #list >= MAX then
    ns.Print("Du kan feste maks " .. MAX .. " rubrikker. Høyreklikk en for å fjerne den.")
    return false
  end
  list[#list + 1] = key
  self:Layout()
  return true
end

function T:OpenMenu(anchor)
  local items = {}
  for _, d in ipairs(self.DEFS) do
    local on = self:IsPinned(d.key)
    items[#items + 1] = {
      text = (on and "Fjern: " or "Fest: ") .. d.name,
      color = on and C.green or C.text2,
      func = function() T:Toggle(d.key) end,
    }
  end
  UI.Menu(anchor, items, true)
end

local function makeTile(i)
  local t = CreateFrame("Button", nil, T.holder)
  t:SetSize(W, H)
  t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  t.panel = UI.Panel(t, C.window, C.inputLine, true, 0.92)
  t.panel:SetAllPoints()
  t.panel:SetFrameLevel(t:GetFrameLevel())
  t.v = UI.Text(t, 14, "bold", C.text)
  t.v:SetPoint("TOPLEFT", 9, -7)
  t.v:SetPoint("RIGHT", -6, 0)
  t.v:SetWordWrap(false)
  t.k = UI.Text(t, 10, nil, C.muted)
  t.k:SetPoint("BOTTOMLEFT", 9, 7)
  t.k:SetPoint("RIGHT", -6, 0)
  t.k:SetWordWrap(false)
  t:SetScript("OnClick", function(self, btn)
    if btn == "RightButton" then
      if self.key then T:Toggle(self.key) end
    else
      ns.Window:OpenPlayer(ns.pid)
    end
  end)
  t:SetScript("OnEnter", function(self)
    local d = self.key and T.byKey[self.key]
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(d and d.name or "Chillan?", 1, 1, 1)
    GameTooltip:AddLine("Venstreklikk: Min side  ·  Høyreklikk: fjern", 0.52, 0.55, 0.57)
    GameTooltip:Show()
  end)
  t:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return t
end

function T:Update()
  if not self.holder or not self.holder:IsShown() then return end
  for _, t in ipairs(self.tiles) do
    if t:IsShown() and t.key then
      local d = self.byKey[t.key]
      local ok, v, sub, col = pcall(d.get)
      if not ok then v, sub, col = "–", d.name, nil end
      t.v:SetText(v or "–")
      t.v:SetTextColor(hex(col or C.text))
      t.k:SetText(sub or "")
    end
  end
end

function T:Layout()
  if not self.holder then return end
  local m = ns.Overlays.minibar
  local list = self:List()
  local show = m and m:IsShown() and #list > 0
  self.holder:SetShown(show and true or false)
  if not show then return end
  local n = 0
  for i = 1, MAX do
    local t = self.tiles[i] or makeTile(i)
    self.tiles[i] = t
    local key = list[i]
    if key and self.byKey[key] then
      n = n + 1
      t.key = key
      local row, col = math.floor((n - 1) / PER_ROW), (n - 1) % PER_ROW
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", self.holder, "TOPLEFT", col * (W + GAP), -row * (H + GAP))
      t:Show()
    else
      t.key = nil
      t:Hide()
    end
  end
  local rows = math.ceil(n / PER_ROW)
  self.holder:SetSize(math.min(n, PER_ROW) * (W + GAP), math.max(1, rows) * (H + GAP))
  self:Update()
end

function T:Init()
  local m = ns.Overlays.minibar
  if not m then return end
  self.tiles = {}
  local holder = CreateFrame("Frame", "ChillanTiles", UIParent)
  holder:SetFrameStrata("MEDIUM")
  holder:SetPoint("TOPLEFT", m, "BOTTOMLEFT", 0, -GAP)
  self.holder = holder

  -- "+"-knapp på minibaren
  local plus = UI.IconButton(m, 22, "Plus", "Fest stats under baren", function(b) T:OpenMenu(b) end)
  plus:SetScript("OnClick", function(b) T:OpenMenu(b) end)
  m.plus = plus

  m:HookScript("OnShow", function() T:Layout() end)
  m:HookScript("OnHide", function() T:Layout() end)
  ns:Listen("MINIBAR", function() T:Layout() end)
  ns:Listen("DATA", function() T:Update() end)
  ns:On("PLAYER_REGEN_DISABLED", function() holder:SetAlpha(0.3) end)
  ns:On("PLAYER_REGEN_ENABLED", function() holder:SetAlpha(1) end)
  C_Timer.NewTicker(2, function() T:Update() end)
  C_Timer.After(1, function()
    startMoney = startMoney or (type(ns.S(GetMoney)) == "number" and ns.S(GetMoney)) or nil
    startHK = startHK or hk()
    T:Layout()
  end)
end
