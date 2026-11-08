-- Chillan? – eget hendelsesvindu på skjermen: alt som skjer i gjengen,
-- gjengchat, reaksjoner (samlet) og et felt for å skrive til gjengen.
local ADDON, ns = ...
local UI, C = ns.UI, ns.C
local hex = ns.hex

local E = {}
ns.EventWindow = E

local MAX_KEEP = 200
local FILTERS = { { "all", "All" }, { "ev", "Events" }, { "chat", "Chat" } }

E.entries = {}
E.pendingRx = {}

local function stamp(t)
  return ns.Colorize(date("%H:%M", t or time()), "6E747B") .. "  "
end

local function visible(kind)
  if kind == "sep" then return true end
  local f = ns.db.settings.evFilter or "all"
  if f == "all" then return kind ~= "chat" or ns.db.settings.feedChat end
  if f == "ev" then return kind == "ev" or kind == "rx" end
  return kind == "chat"
end

-- Reaksjoner som «brikker» bak hendelsen: Hahaha! 2   F   RIP
-- (hold musa over en brikke for å se hvem). Linja oppdaterer seg selv.
local function chips(item)
  if not item or not item.reacts or #item.reacts == 0 then return "" end
  local order, counts = {}, {}
  for _, r in ipairs(item.reacts) do
    local label = ns.ReactionText(item, r.idx)
    if not counts[label] then
      counts[label] = 0
      order[#order + 1] = { label = label, idx = r.idx }
    end
    counts[label] = counts[label] + 1
  end
  local parts = {}
  for _, o in ipairs(order) do
    local n = counts[o.label]
    -- [ Grats! 2 ] – brackets in a dim colour so each reaction stands apart
    local br = ns.C.activeLine
    parts[#parts + 1] = "|Hchillanrx:" .. tostring(item.id) .. ":" .. tostring(o.idx) .. "|h"
      .. ns.Colorize("[ ", br) .. ns.Colorize(o.label, C.purple) .. (n > 1 and ns.Colorize(" " .. n, C.muted) or "")
      .. ns.Colorize(" ]", br) .. "|h"
  end
  return "    " .. table.concat(parts, " ")
end

local function render(e)
  return stamp(e.t) .. e.base .. chips(e.item)
end

function E:Add(kind, text, t, item)
  local e = { kind = kind, base = text, t = t or time(), item = item }
  e.text = render(e)
  ns.PushCapped(self.entries, e, MAX_KEEP)
  if self.msg and visible(kind) then
    self.msg:AddMessage(e.text)
    if ns.db.settings.evMin and kind ~= "sep" then
      self.missed = (self.missed or 0) + 1
      self:UpdateCount()
    end
    if self.frame and not self.frame:IsMouseOver() then self:Flash() end
  end
end

function E:Redraw()
  if not self.msg then return end
  local off = self.msg.GetScrollOffset and self.msg:GetScrollOffset() or 0
  self.msg:Clear()
  for _, e in ipairs(self.entries) do
    if e.base then e.text = render(e) end
    if visible(e.kind) then self.msg:AddMessage(e.text) end
  end
  if off > 0 and self.msg.SetScrollOffset then pcall(self.msg.SetScrollOffset, self.msg, off) end
  for key, btn in pairs(self.filterBtns or {}) do
    local on = (ns.db.settings.evFilter or "all") == key
    btn.text:SetTextColor(hex(on and C.text or C.dim))
    btn.line:SetShown(on)
  end
end

-- Gjengchat: klikkbart navn (åpner spillersiden)
local function chatText(item)
  local p = ns:GetPerson(item.pid) or {}
  local name = "|Hchillan:" .. tostring(item.pid) .. "|h" .. ns:ShortWho(p, item.char) .. "|h"
  if item.mention then
    return UI.InlineIcon("At", C.gold, 12) .. "  " .. name .. ns.Colorize(": ", C.dim) .. ns.Colorize(item.text or "", C.gold)
  end
  return UI.InlineIcon("Chat", "8FB8C9", 12) .. "  " .. name .. ns.Colorize(": ", C.dim) .. ns.Colorize(item.text or "", "D9F0F7")
end

-- Reaksjoner samles i ~5 sek per hendelse, gruppert per reaksjon med hvem som ga den:
-- "★ Adee · «Populær»   Hahaha! Svenna, Olav  ·  GZ! Kenny"
function E:QueueReaction(item, rp, char, idx)
  if not item or not item.id then return end
  local q = self.pendingRx[item.id]
  if not q then
    q = { item = item, order = {}, by = {}, seen = {} }
    self.pendingRx[item.id] = q
    C_Timer.After(5, function() E:FlushReaction(item.id) end)
  end
  local label = ns.ReactionText(item, idx)
  if not q.by[label] then q.by[label] = {} q.order[#q.order + 1] = label end
  local key = (rp and rp.pid or "?") .. label
  if q.seen[key] then return end
  q.seen[key] = true
  table.insert(q.by[label], rp and ns:ShortWho(rp, char) or "?")
end

local function whatText(it)
  if it.kind == "ACH" then
    local d = ns.Ach and ns.Ach.byId[it.a]
    local tier = d and ns.Ach.TIERS[d.tier] or ns.Ach.TIERS.B
    return ns.AchLink(it.a, "«" .. (d and d.name or tostring(it.a)) .. "»", tier.color)
  elseif it.kind == "DING" then
    return ns.Colorize("level " .. tostring(it.a), C.green)
  elseif it.kind == "DEAD" then
    return ns.Colorize("died", C.red)
  end
  return ns.Colorize(tostring(it.kind):lower(), C.text2)
end

function E:OnReaction(item, rp, char, idx)
  if not item or not item.id then return end
  for i = #self.entries, 1, -1 do
    local e = self.entries[i]
    if e.item and e.item.id == item.id then
      e.item = item
      if not self.redrawPending then
        self.redrawPending = true
        C_Timer.After(0.3, function() E.redrawPending = false E:Redraw() end)
      end
      if self.frame and not self.frame:IsMouseOver() then self:Flash() end
      return
    end
  end
  -- hendelsen er for gammel til å stå i vinduet: vis reaksjonen samlet på én linje
  self:QueueReaction(item, rp, char, idx)
end

function E:FlushReaction(id)
  local q = self.pendingRx[id]
  self.pendingRx[id] = nil
  if not q then return end
  local parts = {}
  for _, label in ipairs(q.order) do
    local names = q.by[label]
    local shown = {}
    for i = 1, math.min(4, #names) do shown[i] = names[i] end
    local more = #names > 4 and ns.Colorize(" +" .. (#names - 4), C.dim) or ""
    parts[#parts + 1] = ns.Colorize(label, C.purple) .. " " .. table.concat(shown, ns.Colorize(", ", C.dim)) .. more
  end
  local target = ns:ShortWho(ns:GetPerson(q.item.pid) or {}, q.item.char)
  self:Add("rx", UI.InlineIcon("Star", C.purple, 11) .. "  " .. target .. ns.Colorize(" · ", C.dim) .. whatText(q.item)
    .. "     " .. table.concat(parts, ns.Colorize("   ·   ", C.dim)))
end

function E:Flash()
  if not self.frame or not self.frame:IsShown() then return end
  self.frame:SetAlpha(1)
  self.idleAt = GetTime()
end

function E:Create()
  local S = ns.db.settings
  local f = UI.OverlayPanel(UIParent, C.window, C.line, false)
  f:SetFrameStrata("MEDIUM")
  local sz = S.evSize or { w = 380, h = 210 }
  f:SetSize(sz.w, sz.h)
  f:SetResizable(true)
  if f.SetResizeBounds then f:SetResizeBounds(280, 130, 800, 600) end
  self.frame = f

  -- Topplinje (dra her for å flytte)
  local head = CreateFrame("Frame", nil, f)
  head:SetPoint("TOPLEFT", 0, 0)
  head:SetPoint("TOPRIGHT", 0, 0)
  head:SetHeight(28)
  UI.Movable(head, "eventwin", function(fr) fr:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 40, 260) end, f)

  local logo = UI.Icon(head, "Feed", 14, C.accent)
  logo:SetPoint("LEFT", 10, 0)
  local title = UI.Text(head, 12, "semi", C.text)
  title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
  title:SetText("Chillan?")
  self.count = UI.Text(head, 11, nil, C.muted)
  self.count:SetPoint("LEFT", title, "RIGHT", 6, 0)

  local close = UI.IconButton(head, 20, "Close", "Hide – right-click the Chillan? bar or minimap button (or /chill events) to bring it back", function()
    ns.db.settings.eventFeed = false
    E:Apply()
    ns.Print("Event window hidden. Right-click the Chillan? bar or the minimap button to bring it back.")
  end)
  close:SetPoint("RIGHT", -6, 0)
  -- attach/detach to the Chillan? bar
  local dock = UI.IconButton(head, 20, "Up", "Attach to the Chillan? bar", function()
    E:SetDocked(not ns.db.settings.evDocked)
  end)
  self.dockBtn = dock
  -- "–" folds the window down to just the header
  local mini = CreateFrame("Button", nil, head)
  mini:SetSize(20, 20)
  mini:SetPoint("RIGHT", close, "LEFT", -2, 0)
  dock:SetPoint("RIGHT", mini, "LEFT", -2, 0)
  mini.bar = mini:CreateTexture(nil, "OVERLAY")
  mini.bar:SetSize(10, 2)
  mini.bar:SetPoint("CENTER", 0, 0)
  mini.bar:SetColorTexture(hex(C.muted))
  mini:SetScript("OnEnter", function(self)
    self.bar:SetColorTexture(hex(C.text))
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(ns.db.settings.evMin and "Expand" or "Minimize to header")
    GameTooltip:Show()
  end)
  mini:SetScript("OnLeave", function(self) self.bar:SetColorTexture(hex(C.muted)) GameTooltip:Hide() end)
  mini:SetScript("OnClick", function() E:SetMinimized(not ns.db.settings.evMin) end)
  self.miniBtn = mini
  -- double-click the header does the same
  head:SetScript("OnMouseUp", function(_, btn)
    if btn ~= "LeftButton" then return end
    local now = GetTime()
    if E.lastHeadClick and now - E.lastHeadClick < 0.35 then
      E.lastHeadClick = nil
      E:SetMinimized(not ns.db.settings.evMin)
    else
      E.lastHeadClick = now
    end
  end)
  self.missed = 0

  -- Filtre
  self.filterBtns = {}
  local prev
  for i = #FILTERS, 1, -1 do
    local key, label = FILTERS[i][1], FILTERS[i][2]
    local b = CreateFrame("Button", nil, head)
    b.text = UI.Text(b, 11, "semi", C.dim)
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    b:SetSize(b.text:GetStringWidth() + 12, 22)
    b.line = b:CreateTexture(nil, "ARTWORK")
    b.line:SetColorTexture(hex(C.accent))
    b.line:SetHeight(1)
    b.line:SetPoint("BOTTOMLEFT", 6, 2)
    b.line:SetPoint("BOTTOMRIGHT", -6, 2)
    if prev then b:SetPoint("RIGHT", prev, "LEFT", 0, 0) else b:SetPoint("RIGHT", dock, "LEFT", -4, 0) end
    b:SetScript("OnClick", function() ns.db.settings.evFilter = key E:Redraw() end)
    self.filterBtns[key] = b
    prev = b
  end

  local sep = f:CreateTexture(nil, "ARTWORK")
  self.sep = sep
  sep:SetColorTexture(hex(C.line))
  sep:SetHeight(1)
  sep:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 8, 0)
  sep:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", -8, 0)

  -- Skrivefelt
  local input = UI.EditBox(f, 100, 26, "Write to the gang …  (Enter)", function(eb)
    local txt = eb:GetText()
    if txt and txt ~= "" then ns.Data:SendChat(txt) end
    eb:SetText("")
    eb:ClearFocus()
  end)
  input:SetPoint("BOTTOMLEFT", 8, 8)
  input:SetPoint("BOTTOMRIGHT", -22, 8)
  self.input = input

  -- Meldinger
  local m = UI.MessageFrame(f, 12)
  m:SetSpacing(3)
  m:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 2, -6)
  m:SetPoint("BOTTOMRIGHT", input, "TOPRIGHT", 12, 6)
  m:SetScript("OnHyperlinkClick", function(_, link)
    local pid = type(link) == "string" and link:match("^chillan:(.+)$")
    if pid and ns.Window and ns.Window.OpenPlayer then ns.Window:OpenPlayer(pid) end
    if type(link) == "string" and link:find("^chillantitle:") and ns.Window then
      ns.Window:Create()
      ns.Window.frame:Show()
      ns.Window:Select("stats")
      local st = ns.Window.tabs.stats
      if st and st.SetPage then st:SetPage("titles") end
    end
  end)
  self.msg = m

  -- Hjørne for å endre størrelse
  local grip = CreateFrame("Button", nil, f)
  self.grip = grip
  grip:SetSize(14, 14)
  grip:SetPoint("BOTTOMRIGHT", -3, 3)
  local gt = grip:CreateTexture(nil, "OVERLAY")
  gt:SetAllPoints()
  gt:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  gt:SetVertexColor(hex(C.muted))
  grip:SetShown(not UI.IsLocked() and not ns.db.settings.evMin)
  ns:Listen("LOCK_CHANGED", function(v) grip:SetShown(not v and not ns.db.settings.evMin) end)
  grip:SetScript("OnMouseDown", function()
    if UI.IsLocked() then return end
    f.sizing = true
    f:StartSizing("BOTTOMRIGHT")
  end)
  grip:SetScript("OnMouseUp", function()
    if not f.sizing then return end
    f.sizing = nil
    f:StopMovingOrSizing()
    ns.db.settings.evSize = { w = math.floor(f:GetWidth()), h = math.floor(f:GetHeight()) }
    UI.RestorePos(f)
    E:Redraw()
  end)

  -- Toner seg ned når ingenting skjer, kommer fram ved musepeker/nye linjer
  self.idleAt = GetTime()
  f:SetScript("OnUpdate", function(self, el)
    self.acc = (self.acc or 0) + el
    if self.acc < 0.1 then return end
    self.acc = 0
    local active = self:IsMouseOver() or input.edit:HasFocus()
    if active then E.idleAt = GetTime() end
    local target = 1
    if not active and ns.db.settings.evFade and (GetTime() - E.idleAt) > 20 then target = 0.45 end
    local a = self:GetAlpha() or 1
    if math.abs(a - target) > 0.01 then self:SetAlpha(a + (target - a) * 0.25) end
  end)

  self:Redraw()
  if ns.db.settings.evMin then self:SetMinimized(true, true) end
  if ns.db.settings.evDocked then C_Timer.After(0.2, function() E:SetDocked(true) end) end
end

-- Fold to header / unfold. Keeps the header where it is on screen.
function E:SetMinimized(on, silent)
  local f = self.frame
  if not f then return end
  local S = ns.db.settings
  S.evMin = on and true or nil
  local top, left = f:GetTop(), f:GetLeft()
  local sz = S.evSize or { w = 380, h = 210 }
  for _, r in ipairs({ self.msg, self.input, self.sep, self.grip }) do
    if r then r:SetShown(not on) end
  end
  if self.grip and not on then self.grip:SetShown(not UI.IsLocked()) end
  for _, b in pairs(self.filterBtns or {}) do b:SetShown(not on) end
  f:SetHeight(on and 28 or sz.h)
  if top and left and not silent and not f.noMove then
    -- re-anchor by the top-left corner so the header doesn't jump
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    S.pos = S.pos or {}
    S.pos.eventwin = { point = "TOPLEFT", rel = "BOTTOMLEFT", x = math.floor(left + 0.5), y = math.floor(top + 0.5) }
  end
  if self.miniBtn then
    self.miniBtn.bar:SetSize(on and 8 or 10, on and 8 or 2)
  end
  if f.noMove and self.grip then self.grip:Hide() end
  if ns.Overlays.UpdateGroup then ns.Overlays:UpdateGroup() end
  if not on then
    self.missed = 0
    self:Redraw()
  end
  self:UpdateCount()
end

-- Docking: the window hangs under the bar (or the pinned cards), same width, one shared background
function E:SetDocked(on)
  ns.db.settings.evDocked = on and true or nil
  if not on and self.frame then
    self.frame.noMove = nil
    self.frame.ofill, self.frame.oline = C.window, C.line
    self.frame:SetColors(C.window, C.line, UI.OverlayAlpha())
    if self.topLine then self.topLine:Hide() end
    UI.RestorePos(self.frame)
    if self.grip then self.grip:SetShown(not UI.IsLocked() and not ns.db.settings.evMin) end
  end
  if ns.Overlays.UpdateGroup then ns.Overlays:UpdateGroup() end
  if self.dockBtn then
    self.dockBtn.tooltip = on and "Detach from the Chillan? bar" or "Attach to the Chillan? bar"
  end
  self:Redraw()
end

-- called by the bar when its layout changes; returns true if the window is attached under `anchor`
function E:Reanchor(anchor)
  local f = self.frame
  if not f then return false end
  local m = ns.Overlays.minibar
  local want = ns.db.settings.evDocked and f:IsShown() and m and m:IsShown()
  if not want then
    if f.noMove then
      f.noMove = nil
      f.ofill, f.oline = C.window, C.line
      f:SetColors(C.window, C.line, UI.OverlayAlpha())
      if self.topLine then self.topLine:Hide() end
      local sz = ns.db.settings.evSize or { w = 380, h = 210 }
      f:SetWidth(sz.w)
      UI.RestorePos(f)
    end
    return false
  end
  f.noMove = true
  f.ofill, f.oline = nil, nil          -- the bar's background shows through
  f:SetColors(nil, nil)
  f:SetFrameLevel(m:GetFrameLevel() + 5)
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
  f:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
  local aw = anchor:GetWidth()
  if aw and aw > 0 then f:SetWidth(aw) end
  if not self.topLine then
    self.topLine = f:CreateTexture(nil, "ARTWORK")
    self.topLine:SetHeight(1)
    self.topLine:SetPoint("TOPLEFT", 8, 0)
    self.topLine:SetPoint("TOPRIGHT", -8, 0)
  end
  self.topLine:SetColorTexture(hex(C.line))
  self.topLine:SetShown(anchor ~= m)    -- the bar draws its own line when we hang right under it
  if self.grip then self.grip:Hide() end -- width follows the bar; detach to resize
  return true
end

function E:UpdateCount()
  if not self.count then return end
  local n = ns.Window and ns.Window.OnlineCount and ns.Window:OnlineCount() or 0
  local txt = ns.Colorize("· ", C.dim) .. ns.Colorize(n .. " online", n > 0 and C.green or C.muted)
  if ns.db.settings.evMin and (self.missed or 0) > 0 then
    txt = txt .. ns.Colorize("  · ", C.dim) .. ns.Colorize(self.missed .. " new", C.accent)
  end
  self.count:SetText(txt)
end

function E:Apply()
  if not self.frame then return end
  self.frame:SetShown(ns.db.settings.eventFeed and ns.codeHash ~= nil)
  if ns.Overlays.UpdateGroup then ns.Overlays:UpdateGroup() end
end

-- right-click on the bar / minimap button: bring it back if hidden or folded, otherwise hide it
function E:ShowOrToggle()
  local S = ns.db.settings
  if not S.eventFeed then
    S.eventFeed = true
    self:Apply()
    if S.evMin then self:SetMinimized(false) end
  elseif S.evMin then
    self:SetMinimized(false)
  else
    S.eventFeed = false
    self:Apply()
  end
end

function E:Toggle()
  ns.db.settings.eventFeed = not ns.db.settings.eventFeed
  self:Apply()
end

-- Litt historikk ved innlogging så vinduet ikke er tomt
function E:Backfill()
  local items = {}
  for _, it in ipairs(ns.db.feed or {}) do items[#items + 1] = { t = it.t, kind = "ev", it = it } end
  for _, it in ipairs(ns.db.chat or {}) do items[#items + 1] = { t = it.t, kind = "chat", it = it } end
  table.sort(items, function(a, b) return a.t < b.t end)
  local cutoff = time() - 2 * 3600
  local added = 0
  for i = math.max(1, #items - 20), #items do
    local x = items[i]
    if x.t >= cutoff then
      local ok, text = pcall(x.kind == "chat" and chatText or ns.FeedShort, x.it)
      if ok and text then
        -- tidligere hendelser vises dempet, så de ikke ser ut som nye
        local e = { kind = x.kind, base = ns.Colorize(text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""), "7A8088"), t = x.t, item = x.kind == "ev" and x.it or nil, old = true }
        e.text = render(e)
        ns.PushCapped(self.entries, e, MAX_KEEP)
        added = added + 1
      end
    end
  end
  if added > 0 then
    ns.PushCapped(self.entries, { kind = "sep", text = ns.Colorize("- - -  earlier today (new below)  - - -", "5A6067"), t = time() }, MAX_KEEP)
  end
end

function E:Init()
  local S = ns.db.settings
  -- 0.6.0: hendelser flyttes fra vanlig chat til eget vindu
  if not ns.db.migr060 then
    S.chatMirror, S.activityMirror = false, false
    S.eventFeed, S.feedChat = true, true
    ns.db.migr060 = true
  end
  if S.evFade == nil then S.evFade = true end
  self:Backfill()
  self:Create()
  self:UpdateCount()
  self:Apply()

  ns:Listen("FEEDEVENT", function(text, item) E:Add("ev", text, nil, item) end)
  ns:Listen("CHAT", function(item)
    if (ns.Now() - (item.t or 0)) > 120 then return end
    E:Add("chat", chatText(item), item.t)
  end)
  ns:Listen("REACTION", function(item, rp, char, idx) E:OnReaction(item, rp, char, idx) end)
  ns:Listen("CODE_CHANGED", function() E:Apply() end)
  C_Timer.NewTicker(10, function() E:UpdateCount() end)
end
