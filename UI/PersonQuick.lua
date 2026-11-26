-- Chillan? – the quick card for a person (1.2.0): opens from a row on Friends (under the row, joined
-- to it) or from a card on Home (beside it). Pace, today, the week, all their characters – which
-- ones are online right now – and Whisper / Mute / Open player.
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

local function className(c)
  if not c or not c.class then return "" end
  return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class]) or c.class
end

-- every character of the person, with whether it's the one online right now (and where)
function ns.PersonCharsLive(p)
  local out = {}
  for _, x in ipairs(ns:AllChars(p)) do
    local q = ns.db.people[x.pid] or {}
    local on = ns:IsOnline(q) and (((q.live and q.live.char) or q.main) == x.full)
    out[#out + 1] = { full = x.full, ch = x.ch, pid = x.pid, online = on, zone = on and q.live and q.live.zone or nil }
  end
  table.sort(out, function(a, b)
    if a.online ~= b.online then return a.online end
    return (a.ch.level or 0) > (b.ch.level or 0)
  end)
  return out
end

-- opts: { side = "below" | "right", width = n, bounds = frame (keep inside) }
function UI.PersonQuick(parent, opts)
  opts = opts or {}
  local q = UI.Panel(parent, C.cardHover, C.accent, false)
  q:SetFrameStrata("DIALOG")
  q:EnableMouse(true)
  q:Hide()
  q.edge = UI.Track(q:CreateTexture(nil, "OVERLAY"))
  q.edge:SetColorTexture(hex(C.accent))
  q.edge:SetWidth(3)
  q.edge:SetPoint("TOPLEFT", 1, -10)
  q.edge:SetPoint("BOTTOMLEFT", 1, 10)
  -- (1.4.72) the canvas card: who, the level bar, four tiles, This week / Now as label–value rows
  q.avatar = UI.Avatar(q, 36)
  q.head = UI.Text(q, 14, "semi", C.text)
  q.head:SetWordWrap(false)
  q.headSub = UI.Text(q, 11, nil, C.muted)
  q.headSub:SetWordWrap(false)
  q.bar = UI.LevelBar(q)
  q.tiles = {}
  for i = 1, 4 do q.tiles[i] = UI.NumTile(q) end
  q.weekHead = UI.Text(q, 10, "bold", C.dim)
  q.weekHead:SetText("THIS WEEK")
  q.nowHead = UI.Text(q, 10, "bold", C.dim)
  q.nowHead:SetText("NOW")
  q.weekRows = UI.KVRows(q)
  q.nowRows = UI.KVRows(q)
  q.altHead = UI.Text(q, 10, "bold", C.dim)
  q.alts = {}
  for i = 1, 5 do
    local l = UI.Text(q, 12, nil, C.text2)
    l:SetWordWrap(false)
    q.alts[i] = l
  end
  q.open = UI.Button(q, 112, 26, "Open player ›", "primary")
  q.wh = UI.Button(q, 70, 26, "Whisper", "secondary")
  q.mute = UI.Button(q, 60, 26, "Mute", "ghost")
  q.watch = UI.Button(q, 70, 26, "Watch", "ghost")

  function q:Fill(p)
    local W = self:GetWidth()
    local s3 = ns:PersonS3(p) or {}
    local c = ns:PersonChar(p) or {}
    local pad = 14
    local inner = W - 2 * pad
    local y = -12
    -- who
    local online = ns:IsOnline(p)
    self.avatar:Set(c.name, c.class, (online or p.pid == ns.pid) and ((p.live or {}).status == "AFK" and C.amber or C.green) or "4A4F55", C.cardHover)
    self.avatar:ClearAllPoints()
    self.avatar:SetPoint("TOPLEFT", pad, y)
    local title = ns.TitleLine(p, 1)
    self.head:SetText(ns.WhoLine(p) .. (title ~= "" and ("   " .. title) or ""))
    self.head:ClearAllPoints()
    self.head:SetPoint("TOPLEFT", self.avatar, "TOPRIGHT", 10, -1)
    self.head:SetPoint("RIGHT", self, "RIGHT", -pad, 0)
    self.headSub:SetText(ns.WhereLine(p))
    self.headSub:ClearAllPoints()
    self.headSub:SetPoint("BOTTOMLEFT", self.avatar, "BOTTOMRIGHT", 10, 1)
    self.headSub:SetPoint("RIGHT", self, "RIGHT", -pad, 0)
    y = y - 36 - 12
    -- level bar
    local eta = ns.St:ETA(p)
    local nextL = (tonumber(c.level) or 0) + 1
    y = y - self.bar:Draw(p, pad, y, inner, eta and ("~" .. ns.Duration(eta) .. " to " .. nextL) or nil) - 8
    -- four tiles
    local rate = ns.St:XPRate(p)
    local atMax = (c.level or 0) >= 60
    local vals = {
      atMax and { s3.ilvl and tostring(s3.ilvl) or "–", "item level" } or { rate and ns.Num(rate) or "–", "XP per hour" },
      { s3.today and ns.Duration(s3.today) or "–", "online today" },
      { s3.streak and ns.Plural(s3.streak, "day") or "–", "streak" },
      { (ns:PersonPlayed(p) or 0) > 0 and ns.Duration(ns:PersonPlayed(p)) or "–", "Played" },
    }
    for i, t in ipairs(self.tiles) do t:Set(vals[i][1], vals[i][2]) end
    UI.LayTiles(self.tiles, self, pad, y, inner, 6)
    y = y - 44 - 12
    -- this week
    self.weekHead:ClearAllPoints()
    self.weekHead:SetPoint("TOPLEFT", pad, y)
    y = y - 12
    y = y - self.weekRows:Draw({
      { "Quests", ns.Num(math.floor(ns:WeekStat(p, "Quests"))) },
      { "Kills", ns.Num(math.floor(ns:WeekStat(p, "Kills"))) },
      { "Deaths", ns.Num(math.floor(ns:WeekStat(p, "Deaths"))) },
      { "Gold earned", ns.WeekGoldLine(p) },
    }, pad, y, inner, 2) - 10
    -- now
    self.nowHead:ClearAllPoints()
    self.nowHead:SetPoint("TOPLEFT", pad, y)
    y = y - 12
    local dura = s3.dura and ns.Colorize(s3.dura .. " %", s3.dura <= 10 and C.red or (s3.dura <= 30 and C.amber or C.text)) or nil
    y = y - self.nowRows:Draw({
      { "Gold", s3.money and ns.Money(s3.money) or "–" },
      { "Item level", s3.ilvl and tostring(s3.ilvl) or "–" },
      { "Durability", dura or "–" },
      { "Chillan", ns.VersionLine(p) or "–" },
    }, pad, y, inner, 2) - 10
    -- characters (all installs), online ones first
    local chars = ns.PersonCharsLive(p)
    for _, l in ipairs(self.alts) do l:Hide() end
    if #chars > 1 then
      self.altHead:ClearAllPoints()
      self.altHead:SetPoint("TOPLEFT", pad, y)
      self.altHead:SetText("CHARACTERS")
      self.altHead:Show()
      y = y - 16
      for i, x in ipairs(chars) do
        local l = self.alts[i]
        if not l then break end
        local r, g, b = hex(x.online and C.green or "4A4F55")
        local dot = string.format("|T%sCircle:8:8:0:0:64:64:0:64:0:64:%d:%d:%d|t", ns.TEX, r * 255, g * 255, b * 255)
        l:SetText(dot .. "  " .. ns.Colorize(x.ch.name or ns.ShortName(x.full), ns.ClassHex(x.ch.class))
          .. ns.Colorize("  " .. (x.ch.level or "?") .. " " .. className(x.ch), C.muted)
          .. (x.online and ns.Colorize("  ·  online" .. (x.zone and (" · " .. x.zone) or ""), C.green) or ""))
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", pad, y)
        l:SetPoint("RIGHT", self, "RIGHT", -pad, 0)
        l:Show()
        y = y - 18
      end
      y = y - 6
    else
      self.altHead:Hide()
    end
    -- buttons: Watch and Mute left, Whisper and Open player right
    y = y - 2
    self.open:ClearAllPoints()
    self.open:SetPoint("TOPRIGHT", self, "TOPRIGHT", -pad, y)
    self.wh:ClearAllPoints()
    self.wh:SetPoint("RIGHT", self.open, "LEFT", -6, 0)
    self.watch:ClearAllPoints()
    self.watch:SetPoint("TOPLEFT", self, "TOPLEFT", pad, y)
    self.mute:ClearAllPoints()
    self.mute:SetPoint("LEFT", self.watch:IsShown() and self.watch or self, self.watch:IsShown() and "RIGHT" or "LEFT", self.watch:IsShown() and 6 or pad, 0)
    self.watch:SetShown(p.pid ~= ns.pid and ns.Watch ~= nil)
    self.watch:SetLabel(ns.Watch and ns.Watch:Has(p.pid) and "Unwatch" or "Watch")
    self.watch.tooltip = "See where they are and their level under the Now card (up to 4)."
    self.watch:SetScript("OnClick", function()
      ns.Watch:Toggle(p.pid)
      self.watch:SetLabel(ns.Watch:Has(p.pid) and "Unwatch" or "Watch")
      if opts.onChange then opts.onChange() end
    end)
    local target = (p.live and p.live.char) or p.main
    self.wh:SetScript("OnClick", function() ns.Whisper(target) end)
    self.wh:SetShown(p.pid ~= ns.pid)
    self.mute:SetShown(p.pid ~= ns.pid)
    self.mute:SetLabel(ns:IsMuted(p.pid) and "Unmute" or "Mute")
    self.mute:SetScript("OnClick", function()
      ns:SetMuted(p.pid, not ns:IsMuted(p.pid))
      self.mute:SetLabel(ns:IsMuted(p.pid) and "Unmute" or "Mute")
      if opts.onChange then opts.onChange() end
    end)
    self.open:SetScript("OnClick", function() self:Close() ns.Window:OpenPlayer(p.pid) end)
    self:SetHeight(-y + 26 + 12)
  end

  -- the row it belongs to is marked while the card is open
  function q:Mark(row, on)
    if not row or not row.panel then return end
    if on then row.panel:SetColors(C.active, C.accent) row.quickOpen = true
    else if row.striped then row.panel:SetColors(row.stripe, nil) else row.panel:SetColors(C.card, C.line) end row.quickOpen = nil end
  end

  function q:Close()
    if self.row then self:Mark(self.row, false) end
    self.row, self.pid = nil, nil
    self:Hide()
  end

  function q:Toggle(row, p)
    if self:IsShown() and self.pid == p.pid then self:Close() return end
    if self.row then self:Mark(self.row, false) end
    self.pid, self.row, self.person = p.pid, row, p
    self:ClearAllPoints()
    if opts.side == "right" then
      self:SetWidth(opts.width or 340)
      self:SetPoint("TOPLEFT", row, "TOPRIGHT", 8, 0)
    else
      self:SetPoint("LEFT", row, "LEFT", 0, 0)
      self:SetPoint("RIGHT", row, "RIGHT", 0, 0)
      self:SetWidth(row:GetWidth() or 600)
    end
    self:Fill(p)
    if opts.side ~= "right" then
      -- joined to the row: under it if there's room, else above
      local rowBottom, b = row:GetBottom(), opts.bounds and opts.bounds:GetBottom()
      self:ClearAllPoints()
      self:SetPoint("LEFT", row, "LEFT", 0, 0)
      self:SetPoint("RIGHT", row, "RIGHT", 0, 0)
      if rowBottom and b and (rowBottom - self:GetHeight() - 6) < b then
        self:SetPoint("BOTTOM", row, "TOP", 0, -1)
      else
        self:SetPoint("TOP", row, "BOTTOM", 0, 1)
      end
    else
      -- keep inside the window
      local top, b = row:GetTop(), opts.bounds and opts.bounds:GetBottom()
      if top and b and (top - self:GetHeight()) < b then
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", row, "BOTTOMRIGHT", 8, 0)
      end
    end
    self:Mark(row, true)
    self:Show()
  end

  function q:Refresh()
    if self:IsShown() and self.person then
      if not self.row or not self.row.item or self.row.item.pid ~= self.pid then self:Close() return end
      self:Fill(self.row.item)
    end
  end
  return q
end
