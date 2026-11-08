-- Chillan? – fanen "Trophies": alle achievements, fremdrift og hvem som har dem
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("ach", "Trophies", "Trophy", function(tab)
  local A = ns.Ach
  local cat = "all"
  local LEFT_W = 176

  local left = CreateFrame("Frame", nil, tab)
  left:SetPoint("TOPLEFT", 16, -14)
  left:SetPoint("BOTTOMLEFT", 16, 14)
  left:SetWidth(LEFT_W)

  local h = UI.Text(left, 15, "semi", C.text)
  h:SetPoint("TOPLEFT")
  h:SetText("Achievements")

  -- hvem vises
  local who = UI.Button(left, LEFT_W, 30, "", "ghost")
  who:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -10)
  who.label:ClearAllPoints()
  who.label:SetPoint("LEFT", 10, 0)
  who.label:SetPoint("RIGHT", -10, 0)
  who:SetScript("OnClick", function(self)
    local items = {}
    for _, p in ipairs(ns:SortedPeople()) do
      local pid = p.pid
      items[#items + 1] = { text = ns:PersonName(p) .. (ns:PersonAlias(p) and (" (" .. ns:PersonAlias(p) .. ")") or ""),
        func = function() ns.Window.achPid = pid tab:Refresh() end }
    end
    UI.Menu(self, items)
  end)

  local big = UI.Text(left, 22, "bold", C.text)
  big:SetPoint("TOPLEFT", who, "BOTTOMLEFT", 2, -12)
  local pts = UI.Text(left, 12, nil, C.muted)
  pts:SetPoint("TOPLEFT", big, "BOTTOMLEFT", 0, -2)

  local catButtons = {}
  local cats = { { key = "all", name = "All" } }
  for _, c in ipairs(A.CATS) do cats[#cats + 1] = c end
  local function paintCats()
    for k, b in pairs(catButtons) do
      local on = k == cat
      b.panel:SetColors(on and C.active or nil, nil)
      b.label:SetTextColor(hex(on and C.text or C.muted))
      b.style = { fill = on and C.active or nil, text = on and C.text or C.muted, hover = C.card }
    end
  end
  for i, c in ipairs(cats) do
    local b = UI.Button(left, LEFT_W, 20, "", "nav", function() cat = c.key paintCats() tab:Refresh() end)
    b:SetPoint("TOPLEFT", pts, "BOTTOMLEFT", -2, -8 - (i - 1) * 20)
    b.label:ClearAllPoints()
    b.label:SetPoint("LEFT", 8, 0)
    b.label:SetFont(ns.FONT, 12, "")
    b.count = UI.Text(b, 11, nil, C.dim)
    b.count:SetPoint("RIGHT", -8, 0)
    b:SetLabel(c.name)
    catButtons[c.key] = b
  end
  paintCats()

  -------------------------------------------------------------------------
  -- Liste over achievements
  -------------------------------------------------------------------------
  local function createRow(list)
    local row = CreateFrame("Frame", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.tile = UI.Panel(row, C.active, nil, true)
    row.tile:SetSize(38, 38)
    row.tile:SetPoint("LEFT", 10, 0)
    row.icon = UI.Icon(row.tile, "Trophy", 20, C.dim)
    row.icon:SetPoint("CENTER")
    row.name = UI.Text(row, 13, "semi", C.text)
    row.name:SetPoint("TOPLEFT", 58, -9)
    row.name:SetPoint("RIGHT", -110, 0)
    row.desc = UI.Text(row, 11, nil, C.muted)
    row.desc:SetPoint("TOPLEFT", 58, -27)
    row.desc:SetPoint("RIGHT", -110, 0)
    row.track = row:CreateTexture(nil, "ARTWORK")
    row.track:SetTexture(ns.TEX .. "RoundedSmall")
    row.track:SetVertexColor(hex(C.active))
    row.track:SetHeight(4)
    row.track:SetPoint("BOTTOMLEFT", 58, 8)
    row.track:SetPoint("RIGHT", -110, 0)
    row.bar = row:CreateTexture(nil, "OVERLAY")
    row.bar:SetTexture(ns.TEX .. "RoundedSmall")
    row.bar:SetHeight(4)
    row.bar:SetPoint("LEFT", row.track, "LEFT")
    row.tier = UI.Text(row, 11, "semi", C.text)
    row.tier:SetPoint("TOPRIGHT", -12, -10)
    row.tier:SetJustifyH("RIGHT")
    row.right = UI.Text(row, 11, nil, C.muted)
    row.right:SetPoint("TOPRIGHT", -12, -28)
    row.right:SetJustifyH("RIGHT")
    row.others = UI.Text(row, 10, nil, C.dim)
    row.others:SetPoint("BOTTOMRIGHT", -12, 6)
    row.others:SetJustifyH("RIGHT")
    row.others:SetWidth(96) -- holdes innenfor høyre kolonne så den ikke legger seg over fremdriftsstolpen
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
      self.panel:SetColors(C.cardHover, C.line)
      local d = self.item
      if d and not (d.secret and not A:Has(ns.Window.achPid or ns.pid, d.id)) then UI.AchTooltip(self, d.id) end
    end)
    row:SetScript("OnLeave", function(self) self.panel:SetColors(C.card, C.line) GameTooltip:Hide() end)
    return row
  end

  local function others(id, exceptPid)
    local names = {}
    for pid, p in pairs(ns.db.people) do
      if pid ~= exceptPid and p.main and A:Has(pid, id) then names[#names + 1] = ns:PersonAlias(p) or ns:PersonName(p) end
    end
    table.sort(names)
    return names
  end

  local function updateRow(row, d)
    local pid = ns.Window.achPid or ns.pid
    local got = A:Has(pid, d.id)
    local tier = A.TIERS[d.tier]
    local hidden = d.secret and not got
    row.name:SetText(hidden and "Secret achievement" or d.name)
    row.name:SetTextColor(hex(got and C.text or C.text2))
    row.desc:SetText(hidden and "Unlock it to see what it is" or d.desc)
    row.icon:SetVertexColor(hex(got and tier.color or C.dim))
    row.tile:SetColors(got and C.active or C.input, nil)
    row:SetAlpha(got and 1 or 0.8)
    row.tier:SetText(tier.name .. " · " .. tier.points .. " p")
    row.tier:SetTextColor(hex(tier.color))
    -- fremdrift (bare for deg selv; andres tellere kjenner vi ikke)
    row.track:Hide() row.bar:Hide()
    if got then
      local t = got
      row.right:SetText(type(t) == "number" and ("Unlocked " .. date("%d.%m.%y", t)) or "Unlocked")
    elseif pid == ns.pid and not hidden and d.goal > 1 then
      local v = A:Progress(d)
      local pct = math.min(1, v / d.goal)
      local function fmt(x)
        if d.cat == "gold" then return math.floor(x / 10000) .. "g" end
        if d.goal >= 3600 and (d.cat == "time" or d.cat == "expl") then return ns.Duration(x) end
        return ns.Num(x)
      end
      row.right:SetText(fmt(math.min(v, d.goal)) .. " / " .. fmt(d.goal))
      local w = row.track:GetWidth()
      if not w or w <= 0 then w = 300 end
      row.bar:SetWidth(math.max(1, w * pct))
      row.bar:SetVertexColor(hex(tier.color))
      row.track:Show() row.bar:Show()
    else
      row.right:SetText("")
    end
    local o = others(d.id, pid)
    if #o > 0 and not hidden then
      row.others:SetText("Also: " .. table.concat(o, ", ", 1, math.min(3, #o)) .. (#o > 3 and (" +" .. (#o - 3)) or ""))
    else
      row.others:SetText("")
    end
  end

  local list = UI.List(tab, 54, 6, createRow, updateRow)
  list:SetPoint("TOPLEFT", left, "TOPRIGHT", 14, 0)
  list:SetPoint("BOTTOMRIGHT", -10, 14)

  function tab:Refresh()
    local pid = ns.Window.achPid or ns.pid
    local p = ns:GetPerson(pid) or {}
    who:SetLabel("Showing: " .. ((pid == ns.pid) and "me" or (ns:PersonAlias(p) or ns:PersonName(p))) .. "  · switch")
    local total = #A.defs
    big:SetText(A:Count(pid) .. " / " .. total)
    pts:SetText(A:Points(pid) .. " points")
    -- antall per kategori
    local per, gotPer = {}, {}
    for _, d in ipairs(A.defs) do
      per[d.cat] = (per[d.cat] or 0) + 1
      if A:Has(pid, d.id) then gotPer[d.cat] = (gotPer[d.cat] or 0) + 1 end
    end
    for key, b in pairs(catButtons) do
      if key == "all" then b.count:SetText(A:Count(pid) .. "/" .. total)
      else b.count:SetText((gotPer[key] or 0) .. "/" .. (per[key] or 0)) end
    end
    local rows = {}
    for _, d in ipairs(A.defs) do
      if cat == "all" or d.cat == cat then rows[#rows + 1] = d end
    end
    -- opplåste først (nyeste øverst), så resten i fast rekkefølge
    table.sort(rows, function(a, b)
      local ga, gb = A:Has(pid, a.id), A:Has(pid, b.id)
      if (ga and true or false) ~= (gb and true or false) then return ga and true or false end
      if ga and gb and type(ga) == "number" and type(gb) == "number" and ga ~= gb then return ga > gb end
      return a.order < b.order
    end)
    list:SetData(rows)
  end
end)
