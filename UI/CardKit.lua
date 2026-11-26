-- Chillan? – pieces the person cards share (1.4.72): label/value rows, small number tiles and the
-- "who" lines. One fact per row: the label left and dim, the value right; a long value wraps under
-- itself instead of being cut with "…".
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

local function className(c)
  if not c or not c.class then return "" end
  return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class]) or c.class
end
ns.ClassName = className

---------------------------------------------------------------------------
-- rows: kv = UI.KVRows(parent); h = kv:Draw(rows, x, y, width, cols) – rows { {label, value}, … }
---------------------------------------------------------------------------
function UI.KVRows(parent)
  local o = { parent = parent, pool = {}, n = 0 }
  local function get(i)
    local r = o.pool[i]
    if not r then
      r = {}
      r.k = UI.Text(parent, 12, nil, C.muted)
      r.k:SetJustifyH("LEFT")
      r.k:SetWordWrap(false)
      r.v = UI.Text(parent, 12, nil, C.text)
      r.v:SetJustifyH("RIGHT")
      r.v:SetWordWrap(true)
      r.line = UI.Track(parent:CreateTexture(nil, "ARTWORK"))
      r.line:SetHeight(1)
      o.pool[i] = r
    end
    return r
  end
  function o:Hide()
    for _, r in ipairs(self.pool) do r.k:Hide() r.v:Hide() r.line:Hide() if r.hit then r.hit:Hide() end end
  end
  -- lays the rows out in `cols` columns, side by side row by row; returns the height used
  function o:Draw(rows, x, y, width, cols)
    cols = cols or 1
    self:Hide()
    local gap = 16
    local cw = math.floor((width - gap * (cols - 1)) / cols)
    local list = {}
    for _, row in ipairs(rows) do if row[2] ~= nil and row[2] ~= false then list[#list + 1] = row end end
    local ry, groupH = y, 0
    for i, row in ipairs(list) do
      local r = get(i)
      local c = ((i - 1) % cols) + 1
      local cx = x + (c - 1) * (cw + gap)
      r.k:SetText(row[1] or "")
      r.k:ClearAllPoints()
      r.k:SetPoint("TOPLEFT", parent, "TOPLEFT", cx, ry - 4)
      local kw = math.min(math.floor(cw * 0.55), math.ceil(r.k:GetStringWidth() or 60) + 2)
      r.k:SetWidth(kw)
      r.v:SetText(tostring(row[2]))
      r.v:ClearAllPoints()
      r.v:SetPoint("TOPRIGHT", parent, "TOPLEFT", cx + cw, ry - 4)
      r.v:SetWidth(math.max(40, cw - kw - 10))
      local h = math.max(14, math.ceil(r.v:GetStringHeight() or 14)) + 9
      groupH = math.max(groupH, h)
      r.cx = cx
      r.k:Show() r.v:Show()
      -- (1.4.72) an item link in a value: hover shows the item
      if row.link then
        if not r.hit then
          r.hit = CreateFrame("Frame", nil, parent)
          r.hit:EnableMouse(true)
          r.hit:SetScript("OnEnter", function(self)
            if not self.link then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
            GameTooltip:Show()
          end)
          r.hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        r.hit.link = row.link
        r.hit:ClearAllPoints()
        r.hit:SetPoint("TOPRIGHT", r.v, "TOPRIGHT")
        r.hit:SetSize(math.min(r.v:GetWidth(), math.ceil(r.v:GetStringWidth() or 60) + 2), math.max(14, r.v:GetStringHeight() or 14))
        r.hit:Show()
      elseif r.hit then
        r.hit:Hide()
      end
      if c == cols or i == #list then
        -- the line under the row, at the taller cell of the pair
        for j = i - c + 1, i do
          local q = self.pool[j]
          q.line:ClearAllPoints()
          q.line:SetPoint("TOPLEFT", parent, "TOPLEFT", q.cx, ry - groupH + 1)
          q.line:SetWidth(cw)
          q.line:SetColorTexture(hex(C.border or C.line))
          q.line:SetAlpha(0.45)
          q.line:Show()
        end
        ry = ry - groupH
        groupH = 0
      end
    end
    return y - ry
  end
  return o
end

---------------------------------------------------------------------------
-- a small number tile: t = UI.NumTile(parent); t:Set("64 640", "XP per hour")
---------------------------------------------------------------------------
function UI.NumTile(parent, big)
  local t = UI.Panel(parent, C.window or C.card, C.border or C.line, 6)
  t:SetHeight(big and 58 or 44)
  t.v = UI.Text(t, big and 18 or 15, "bold", C.text)
  t.v:SetPoint("TOPLEFT", 9, big and -9 or -7)
  t.v:SetPoint("RIGHT", -6, 0)
  t.v:SetJustifyH("LEFT")
  t.v:SetWordWrap(false)
  t.k = UI.Text(t, 10, nil, C.dim)
  t.k:SetPoint("BOTTOMLEFT", 9, big and 9 or 7)
  t.k:SetPoint("RIGHT", -6, 0)
  t.k:SetJustifyH("LEFT")
  t.k:SetWordWrap(false)
  function t:Set(v, k, col)
    self.v:SetText(v or "–")
    UI.Track(self.v):SetTextColor(hex(col or C.text))
    self.k:SetText(k or "")
  end
  if big then
    t.acc = UI.Track(t:CreateTexture(nil, "OVERLAY"))
    t.acc:SetHeight(2)
    t.acc:SetPoint("TOPLEFT", 3, 0)
    t.acc:SetPoint("TOPRIGHT", -3, 0)
    function t:Accent(col) self.acc:SetColorTexture(hex(col or C.accent)) end
    t:Accent(C.accent)
  end
  return t
end
-- n tiles side by side in a row
function UI.LayTiles(tiles, parent, x, y, width, gap)
  gap = gap or 6
  local n = #tiles
  local w = math.floor((width - gap * (n - 1)) / n)
  for i, t in ipairs(tiles) do
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x + (i - 1) * (w + gap), y)
    t:SetWidth(w)
  end
end

---------------------------------------------------------------------------
-- the "who" lines
---------------------------------------------------------------------------
-- "Yung Link  Eirik" (the character in its class colour, the person's own name dim)
function ns.WhoLine(p)
  local c = ns:PersonChar(p) or {}
  local alias = ns:PersonAlias(p)
  return ns.Colorize(c.name or "?", ns.ClassHex(c.class)) .. (alias and alias ~= c.name and ns.Colorize("  " .. alias, C.muted) or "")
end
-- "Level 53 Orc Shaman · ● Online · Blackrock Depths" / "… · ● Offline · 2 min ago · zone"
function ns.WhereLine(p)
  local c = ns:PersonChar(p) or {}
  local L = p.live or {}
  local online = ns:IsOnline(p)
  local zone = L.zone or ""
  local who = "Level " .. (c.level or "?") .. " " .. ((c.race and c.race ~= "") and (c.race .. " ") or "") .. className(c)
  local st
  if p.pid == ns.pid then st = ns.Colorize("● You", C.green)
  elseif online then st = ns.Colorize(L.status == "AFK" and "● AFK" or "● Online", L.status == "AFK" and C.amber or C.green)
  else st = ns.Colorize("● Offline · " .. ns.Ago(p.lastSeen), C.dim) end
  return ns.Colorize(who, C.muted) .. ns.Colorize("  ·  ", C.dim) .. st .. (zone ~= "" and ns.Colorize("  ·  " .. zone, C.muted) or "")
end
-- the titles held this week, as gold text ("" when none)
-- (1.4.72) a crown and "+3" (how many titles they hold); hover a TitleHit for the list
function ns.TitleLine(p)
  if not (ns.Titles and ns.Titles.For) then return "" end
  local n = #(ns.Titles:For(p.pid) or {})
  if n == 0 then return "" end
  return ns.UI.InlineIcon("Crown", "E0C068", 13) .. ns.Colorize(" +" .. n, C.gold)
end
function ns.TitleTooltip(owner, p)
  local list = ns.Titles and ns.Titles:For(p.pid) or {}
  if #list == 0 then return end
  GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
  GameTooltip:AddLine("Titles this week", 1, 1, 1)
  local cur = ns.Titles:Current()
  for _, def in ipairs(list) do
    local h = cur[def.key]
    GameTooltip:AddDoubleLine(def.name, h and ns.Titles:Format(def, h.value) or "", 0.88, 0.75, 0.41, 1, 1, 1)
    GameTooltip:AddLine(def.desc, 0.6, 0.6, 0.65, true)
  end
  GameTooltip:Show()
end
-- a FontString with the crown that shows the titles on hover: t = UI.TitleHit(parent); t:Set(p)
function UI.TitleHit(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(40, 18)
  f.text = UI.Text(f, 13, "semi", C.gold)
  f.text:SetPoint("LEFT")
  f:EnableMouse(true)
  f:SetScript("OnEnter", function(self) if self.p then ns.TitleTooltip(self, self.p) end end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  function f:Set(p)
    self.p = p
    local t = ns.TitleLine(p)
    self.text:SetText(t)
    self:SetWidth(math.max(1, math.ceil(self.text:GetStringWidth() or 0) + 2))
    self:SetShown(t ~= "")
  end
  return f
end
-- "6d 1h" played over all characters, and how many characters
function ns.PlayedLine(p)
  local played = ns:PersonPlayed(p)
  if not played or played <= 0 then return nil end
  local n = 0
  for _ in pairs(p.chars or {}) do n = n + 1 end
  return ns.Duration(played) .. (n > 1 and (" · " .. n .. " chars") or "")
end
-- "v1.4.72" or a yellow "v0.30.7 · old"
function ns.VersionLine(p, short)
  local v = (p.pid == ns.pid) and ns.VERSION or p.version
  if not v then return nil end
  if ns.IsOutdated(p) then return ns.Colorize("v" .. v .. (short and " · update" or " · old"), C.gold or "E0C068") end
  return "v" .. v
end
-- gold earned this week, or "needs update" when their Chillan can't count it right
function ns.WeekGoldLine(p)
  if not ns.GoldTrusted(p) then return ns.Colorize("needs update", C.gold or "E0C068") end
  return ns.Money(math.floor(ns:WeekStat(p, "Gold") / 100) * 100)
end

---------------------------------------------------------------------------
-- a level bar: b = UI.LevelBar(parent); h = b:Draw(p, x, y, width, rightText)
---------------------------------------------------------------------------
function UI.LevelBar(parent)
  local b = {}
  b.left = UI.Text(parent, 11, nil, C.muted)
  b.right = UI.Text(parent, 11, nil, C.muted)
  b.right:SetJustifyH("RIGHT")
  b.track = parent:CreateTexture(nil, "ARTWORK")
  b.track:SetTexture(ns.TEX .. "RoundedSmall")
  b.track:SetHeight(6)
  b.fill = parent:CreateTexture(nil, "OVERLAY")
  b.fill:SetTexture(ns.TEX .. "RoundedSmall")
  b.fill:SetHeight(6)
  function b:Draw(p, x, y, width, right)
    local c = ns:PersonChar(p) or {}
    local s3 = ns:PersonS3(p) or {}
    local lvl = tonumber(c.level)
    local maxL = ns.S(GetMaxPlayerLevel) or 60
    local frac = (s3.xp and s3.xpMax and s3.xpMax > 0) and math.max(0, math.min(1, s3.xp / s3.xpMax)) or nil
    local atMax = lvl and lvl >= maxL
    self.left:SetText(ns.Colorize("Level " .. (lvl or "?"), C.text) .. ((frac and not atMax) and ns.Colorize("  ·  " .. math.floor(frac * 100) .. " %", C.muted) or ""))
    self.left:ClearAllPoints()
    self.left:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    self.right:SetText(right or (atMax and "max level" or ""))
    self.right:ClearAllPoints()
    self.right:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + width, y)
    UI.Track(self.track):SetVertexColor(hex(C.active))
    UI.Track(self.fill):SetVertexColor(hex(ns.ClassHex(c.class)))
    self.track:ClearAllPoints()
    self.track:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 17)
    self.track:SetWidth(width)
    self.fill:ClearAllPoints()
    self.fill:SetPoint("TOPLEFT", self.track, "TOPLEFT")
    local f = atMax and 1 or (frac or 0)
    self.fill:SetWidth(math.max(1, width * f))
    self.fill:SetShown(f > 0)
    return 25
  end
  return b
end
