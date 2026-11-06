-- Chillan? – "Sammenlign": deg mot en kompis, side om side
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex
local W = ns.Window

function W:OpenCompare(pid)
  self:Create()
  if not self.frame:IsShown() then self.frame:Show() end
  self.comparePid = pid
  self:Select("compare")
end

local function s3(p) return ns:PersonS3(p) or {} end
local function achPoints(p) return (ns.Ach and ns.Ach.Points and ns.Ach:Points(p.pid)) or 0 end

-- { navn, verdi(p), format, lavest er best }
local ROWS = {
  { "Level", function(p) return ns:PersonMaxLevel(p) end, "n" },
  { "XP per time", function(p) return ns.St:XPRate(p) or 0 end, "n" },
  { "XP denne uka", function(p) return s3(p).wXP or 0 end, "n" },
  { "Quests denne uka", function(p) return ns:WeekStat(p, "Quests") end, "n" },
  { "Quests totalt", function(p) return ns:TotalStat(p, "Quests") end, "n" },
  { "Online denne uka", function(p) return ns:WeekStat(p, "Online") end, "t" },
  { "/played", function(p) return ns:PersonPlayed(p) end, "t" },
  { "Lengste økt", function(p) return (p.stats or {}).tLongest or 0 end, "t" },
  { "Gull tjent (uka)", function(p) return ns:WeekStat(p, "Gold") end, "g" },
  { "PvP-drap totalt", function(p) return ns:TotalStat(p, "Kills") end, "n" },
  { "Dødsfall totalt", function(p) return ns:TotalStat(p, "Deaths") end, "n", true },
  { "Achievement-poeng", achPoints, "n" },
  { "Streak", function(p) return s3(p).streak or 0 end, "d" },
  { "Item level", function(p) return s3(p).ilvl or 0 end, "n" },
}

local function fmt(kind, v)
  if kind == "t" then return ns.Duration(v) end
  if kind == "g" then return ns.Money(v) end
  if kind == "d" then return math.floor(v) .. " d" end
  return ns.Num(v)
end

ns:RegisterTab("compare", "Sammenlign", "Compare", function(tab)
  local back = UI.Button(tab, 80, 26, "‹ Tilbake", "ghost", function()
    if W.comparePid then W:OpenPlayer(W.comparePid) else W:Select("friends") end
  end)
  back:SetPoint("TOPLEFT", 16, -14)

  local leftName = UI.Text(tab, 17, "bold", C.text)
  leftName:SetPoint("TOPRIGHT", tab, "TOP", -60, -50)
  leftName:SetJustifyH("RIGHT")
  local vs = UI.Text(tab, 12, "semi", C.dim)
  vs:SetPoint("TOP", 0, -54)
  vs:SetText("VS")
  local rightName = UI.Text(tab, 17, "bold", C.text)
  rightName:SetPoint("TOPLEFT", tab, "TOP", 60, -50)
  local score = UI.Text(tab, 12, nil, C.muted)
  score:SetPoint("TOP", 0, -76)

  local CENTER_W = 150
  local rows = {}
  for i = 1, #ROWS do
    local r = {}
    local y = -100 - (i - 1) * 25
    r.label = UI.Text(tab, 11, nil, C.muted)
    r.label:SetPoint("TOP", tab, "TOP", 0, y - 4)
    r.label:SetJustifyH("CENTER")
    r.label:SetWidth(CENTER_W)
    r.lv = UI.Text(tab, 13, "semi", C.text)
    r.lv:SetPoint("TOPRIGHT", tab, "TOP", -CENTER_W / 2 - 8, y - 3)
    r.lv:SetJustifyH("RIGHT")
    r.rv = UI.Text(tab, 13, "semi", C.text)
    r.rv:SetPoint("TOPLEFT", tab, "TOP", CENTER_W / 2 + 8, y - 3)
    r.lbar = tab:CreateTexture(nil, "ARTWORK")
    r.lbar:SetTexture(ns.TEX .. "RoundedSmall")
    r.lbar:SetHeight(6)
    r.lbar:SetPoint("TOPRIGHT", tab, "TOP", -CENTER_W / 2 - 80, y - 8)
    r.rbar = tab:CreateTexture(nil, "ARTWORK")
    r.rbar:SetTexture(ns.TEX .. "RoundedSmall")
    r.rbar:SetHeight(6)
    r.rbar:SetPoint("TOPLEFT", tab, "TOP", CENTER_W / 2 + 80, y - 8)
    rows[i] = r
  end

  -- stolpene vokser fram når siden åpnes
  local anim = 0
  tab:SetScript("OnUpdate", function(self, dt)
    if anim >= 1 then return end
    anim = math.min(1, anim + dt * 2.5)
    for _, r in ipairs(rows) do
      if r.lw then r.lbar:SetWidth(math.max(1, r.lw * anim)) r.rbar:SetWidth(math.max(1, r.rw * anim)) end
    end
  end)

  local lastPid
  function tab:Refresh()
    local me = ns:GetPerson(ns.pid, true)
    local them = ns:GetPerson(W.comparePid)
    if not them then return end
    leftName:SetText(ns:ShortWho(me))
    rightName:SetText(ns:ShortWho(them))
    local MAXW = 150
    local lw, rw = 0, 0
    for i, def in ipairs(ROWS) do
      local r = rows[i]
      local a = def[2](me) or 0
      local b = def[2](them) or 0
      r.label:SetText(def[1])
      r.lv:SetText(fmt(def[3], a))
      r.rv:SetText(fmt(def[3], b))
      local top = math.max(a, b)
      r.lw = top > 0 and (MAXW * a / top) or 1
      r.rw = top > 0 and (MAXW * b / top) or 1
      local aWins = (def[4] and a < b) or (not def[4] and a > b)
      local bWins = (def[4] and b < a) or (not def[4] and b > a)
      if aWins then lw = lw + 1 end
      if bWins then rw = rw + 1 end
      r.lbar:SetVertexColor(hex(aWins and C.accent or C.activeLine))
      r.rbar:SetVertexColor(hex(bWins and C.accent or C.activeLine))
      r.lv:SetTextColor(hex(aWins and C.text or C.muted))
      r.rv:SetTextColor(hex(bWins and C.text or C.muted))
    end
    score:SetText("Du leder " .. lw .. " – " .. rw .. (lw > rw and "  ·  bra jobba" or (lw < rw and "  ·  på tide å ta igjen" or "  ·  helt likt")))
    if lastPid ~= W.comparePid then
      lastPid = W.comparePid
      anim = 0
    end
  end
end, true)
