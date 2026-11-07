-- Chillan? – "What's new" tab: changelog, newest version at the top, read top-down
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("changelog", "New", "Scroll", function(tab)
  local h = UI.Text(tab, 15, "semi", C.text)
  h:SetPoint("TOPLEFT", 16, -16)
  h:SetText("What's new in Chillan?")
  local sub = UI.Text(tab, 11, nil, C.dim)
  sub:SetPoint("LEFT", h, "RIGHT", 10, 0)

  local box = UI.Panel(tab, C.card, C.line, false)
  box:SetPoint("TOPLEFT", 16, -44)
  box:SetPoint("BOTTOMRIGHT", -16, 14)

  local scroll = CreateFrame("ScrollFrame", nil, box)
  scroll:SetPoint("TOPLEFT", 4, -4)
  scroll:SetPoint("BOTTOMRIGHT", -4, 4)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(600, 400)
  scroll:SetScrollChild(content)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, content:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 40)))
  end)

  -- pools so Refresh can be called many times without leaking regions
  local pools = { head = {}, item = {}, bullet = {}, line = {} }
  local used = {}
  local function get(kind, make)
    used[kind] = (used[kind] or 0) + 1
    local r = pools[kind][used[kind]]
    if not r then r = make() pools[kind][used[kind]] = r end
    r:ClearAllPoints()
    r:Show()
    return r
  end

  local lastSeen
  local function layout()
    for _, pool in pairs(pools) do for _, r in ipairs(pool) do r:Hide() end end
    used = {}
    local w = math.max(300, (scroll:GetWidth() or 600))
    content:SetWidth(w)
    local y = -14
    local list = ns.CHANGELOG or {}
    local seenV = lastSeen or (ns.db.seen and ns.db.seen.changelogPrev) or "0"
    for i, e in ipairs(list) do
      if i > 1 then
        -- separator between versions
        local ln = get("line", function() return UI.SolidLine(content) end)
        ln:SetHeight(1)
        ln:SetPoint("TOPLEFT", 14, y - 2)
        ln:SetPoint("TOPRIGHT", -14, y - 2)
        y = y - 16
      end
      local hd = get("head", function() return UI.Text(content, 14, "semi", C.text) end)
      hd:SetPoint("TOPLEFT", 16, y)
      local isNew = ns.NewerVersion and ns.NewerVersion(e.v, seenV)
      hd:SetText(ns.Colorize("v" .. e.v, C.text) .. ns.Colorize("   " .. (e.date or ""), C.dim)
        .. (isNew and ("   " .. ns.Colorize("NEW", C.green)) or "")
        .. ((e.v == ns.VERSION) and ns.Colorize("   (installed)", C.dim) or ""))
      y = y - 24
      for _, text in ipairs(e.items or {}) do
        local b = get("bullet", function() return UI.Text(content, 13, nil, C.accent) end)
        b:SetText("•")
        b:SetPoint("TOPLEFT", 28, y)
        local t = get("item", function()
          local fs = UI.Text(content, 13, nil, C.text2)
          fs:SetJustifyH("LEFT")
          fs:SetWordWrap(true)
          return fs
        end)
        t:SetWidth(w - 44 - 20)
        t:SetText(text)
        t:SetPoint("TOPLEFT", 44, y)
        y = y - math.max(16, t:GetStringHeight() or 16) - 5
      end
      y = y - 6
    end
    content:SetHeight(-y + 10)
  end

  function tab:Refresh()
    sub:SetText("you have v" .. tostring(ns.VERSION) .. "  ·  update in WowUp and /reload")
    layout()
  end
  scroll:SetScript("OnSizeChanged", function() if tab:IsShown() then layout() end end)

  tab:HookScript("OnShow", function()
    -- remember which version you had seen before, so "NEW" marks everything since then
    ns.db.seen = ns.db.seen or {}
    lastSeen = ns.db.seen.changelogPrev
    scroll:SetVerticalScroll(0)
  end)
end)
