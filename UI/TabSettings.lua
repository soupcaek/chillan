-- Chillan? – "Settings" page (1.4.64: the Market look): a side list of groups with a search box,
-- each group a set of panels; on/off switches with an ⓘ for the explanation; choices as choice bars
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("settings", "Settings", "Gear", function(tab)
  local S = function() return ns.db.settings end
  local rows, refreshers = {}, {}
  local NAV_W = 190

  -------------------------------------------------------------------------
  -- the frame: groups on the left, the chosen group's panels on the right (scrolls)
  -------------------------------------------------------------------------
  local navP = UI.Section(tab, "Settings")
  navP:SetPoint("TOPLEFT", 12, -12)
  navP:SetPoint("BOTTOMLEFT", 12, 12)
  navP:SetWidth(NAV_W)
  local search = UI.EditBox(navP.body, NAV_W - 20, 26, "Search settings")
  search:SetPoint("TOPLEFT", 0, 0)

  local scroll = CreateFrame("ScrollFrame", nil, tab)
  scroll:SetPoint("TOPLEFT", navP, "TOPRIGHT", 12, 0)
  scroll:SetPoint("BOTTOMRIGHT", -12, 12)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(600, 600)
  scroll:SetScrollChild(content)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, content:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 40)))
  end)
  scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)

  local groups, order, navBtns = {}, {}, {}
  local current
  local function group(key, label)
    local g = CreateFrame("Frame", nil, content)
    g:SetPoint("TOPLEFT") g:SetPoint("TOPRIGHT")
    -- (1.4.66) a frame with no height has no place on screen, so nothing anchored to it was drawn
    -- (the right side of Settings stayed empty)
    g:SetHeight(1)
    g:Hide()
    g.key, g.label, g.h, g.panels = key, label, 0, {}
    groups[key] = g
    order[#order + 1] = key
    return g
  end
  -- a panel in a group, stacked under the last; build(body) returns the body's height
  local function panel(g, title, build, accent)
    local p = UI.Section(g, title, accent)
    p:SetPoint("TOPLEFT", 0, -g.h)
    p:SetPoint("TOPRIGHT", 0, -g.h)
    local h = build(p.body, p) or 30
    p:FitBody(h)
    g.h = g.h + p:GetHeight() + 10
    g.panels[#g.panels + 1] = p
    return p
  end
  -- on/off rows: { label, settingKey, onChange, explanation }
  local function switches(g, defs)
    return function(body)
      local y = 0
      for _, def in ipairs(defs) do
        local r = UI.SwitchRow(body, def[1], function() return S()[def[2]] and true or false end, function(v)
          S()[def[2]] = v
          if def[3] then def[3](v) end
        end, def[4])
        r:SetPoint("TOPLEFT", 0, -y) r:SetPoint("TOPRIGHT", 0, -y)
        rows[#rows + 1] = { group = g.key, label = def[1]:lower(), row = r }
        y = y + 30
      end
      return y
    end
  end
  local function hintText(body, text, y)
    local t = UI.Text(body, 11, nil, C.dim)
    t:SetPoint("TOPLEFT", 0, -(y or 0))
    t:SetPoint("RIGHT", body, "RIGHT", 0, 0)
    t:SetJustifyH("LEFT")
    t:SetText(text)
    return t
  end

  -------------------------------------------------------------------------
  -- Your gang: code, your name, add a member by hand
  -------------------------------------------------------------------------
  local gGang = group("gang", "Your gang")
  local codeBox, aliasBox
  panel(gGang, "Gang code", function(b)
    hintText(b, "Share it with your group to join. Version " .. ns.VERSION .. ".")
    codeBox = UI.EditBox(b, 220, 28, "No code")
    codeBox:SetPoint("TOPLEFT", 0, -20)
    codeBox.edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    codeBox.edit:SetScript("OnTextChanged", function(self, user)
      if user then self:SetText(ns.db.code or "") self:HighlightText() end
    end)
    local change = UI.Button(b, 80, 28, "Change", "secondary", function()
      UI.Prompt("Change gang", { { label = "New gang code", placeholder = "CHILL-XXXX" } }, function(v)
        if ns.ChangeCode(v) then ns.Print("Switched to the gang " .. ns.db.code .. ".") else return true end
      end)
    end)
    change:SetPoint("LEFT", codeBox, "RIGHT", 8, 0)
    return 50
  end, true)
  panel(gGang, "Display name", function(b)
    hintText(b, "Shown next to your characters.")
    aliasBox = UI.EditBox(b, 220, 28, "e.g. Henrik", function(self) ns.SetAlias(self:GetText()) self:ClearFocus() end)
    aliasBox:SetPoint("TOPLEFT", 0, -20)
    local save = UI.Button(b, 70, 28, "Save", "secondary", function() ns.SetAlias(aliasBox:GetText()) aliasBox.edit:ClearFocus() end)
    save:SetPoint("LEFT", aliasBox, "RIGHT", 8, 0)
    return 50
  end)
  panel(gGang, "Member missing?", function(b)
    local add = UI.Button(b, 230, 28, "Add by character name", "secondary", function()
      UI.Prompt("Add friend manually", {
        { label = "Character name (use this if a friend doesn't show up)", placeholder = "Name or Name-Realm" },
      }, function(v) ns.Data:AddManual(v) end)
    end)
    add:SetPoint("TOPLEFT", 0, 0)
    hintText(b, "Commands: /chill · /cg text · /chill edit · /chill price · /chill selftest", 36)
    return 50
  end)

  -------------------------------------------------------------------------
  -- Appearance: theme, accent, opacity and size
  -------------------------------------------------------------------------
  local gLook = group("appearance", "Appearance")
  local themeCards, swatches = {}, {}
  panel(gLook, "Theme", function(b)
    for i, t in ipairs(ns.THEMES) do
      local card = CreateFrame("Button", nil, b)
      card:SetSize(96, 58)
      card:SetPoint("TOPLEFT", ((i - 1) % 6) * 102, -math.floor((i - 1) / 6) * 64)
      card.key = t.key
      card.bg = UI.Panel(card, t.c.window, t.c.activeLine, false)
      card.bg:SetAllPoints()
      card.bg:SetFrameLevel(card:GetFrameLevel())
      card.inner = UI.Panel(card, t.c.card, nil, true)
      card.inner:SetPoint("TOPLEFT", 8, -8)
      card.inner:SetPoint("TOPRIGHT", -8, -8)
      card.inner:SetHeight(16)
      card.dot = card.inner:CreateTexture(nil, "OVERLAY")
      card.dot:SetTexture(ns.TEX .. "Circle")
      card.dot:SetSize(8, 8)
      card.dot:SetPoint("LEFT", 6, 0)
      UI.Track(card.dot):SetVertexColor(hex(t.c.accent))
      card.name = UI.Text(card, 12, "semi", t.c.text)
      card.name:SetPoint("BOTTOMLEFT", 8, 7)
      card.name:SetText(t.name)
      card.ring = UI.Panel(card, nil, C.accent, false)
      card.ring:SetPoint("TOPLEFT", -2, 2)
      card.ring:SetPoint("BOTTOMRIGHT", 2, -2)
      card:SetScript("OnClick", function() S().theme = t.key UI.ApplyThemeLive() tab:Refresh() end)
      card:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(t.name, 1, 1, 1)
        GameTooltip:AddLine(t.desc, 0.75, 0.78, 0.82)
        GameTooltip:Show()
      end)
      card:SetScript("OnLeave", function() GameTooltip:Hide() end)
      themeCards[#themeCards + 1] = card
    end
    return 58 + math.floor((#ns.THEMES - 1) / 6) * 64
  end, true)
  panel(gLook, "Accent colour", function(b)
    hintText(b, "Buttons, tabs and highlights everywhere, the Market too. T = the theme's own, C = your class.")
    for i, a in ipairs(ns.ACCENTS) do
      local sw = CreateFrame("Button", nil, b)
      sw:SetSize(26, 26)
      sw:SetPoint("TOPLEFT", (i - 1) * 32, -22)
      sw.key = a.key
      sw.ring = sw:CreateTexture(nil, "BACKGROUND")
      sw.ring:SetTexture(ns.TEX .. "Circle")
      sw.ring:SetAllPoints()
      UI.Track(sw.ring):SetVertexColor(hex(C.text))
      sw.dot = sw:CreateTexture(nil, "ARTWORK")
      sw.dot:SetTexture(ns.TEX .. "Circle")
      sw.dot:SetPoint("CENTER")
      sw.dot:SetSize(20, 20)
      if a.key == "theme" or a.key == "class" then
        sw.letter = UI.Text(sw, 10, "bold", "121417")
        sw.letter:SetPoint("CENTER")
        sw.letter:SetText(a.key == "theme" and "T" or "C")
      end
      sw:SetScript("OnClick", function() S().accent = a.key UI.ApplyThemeLive() tab:Refresh() end)
      sw:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(a.name, 1, 1, 1)
        if a.key == "theme" then GameTooltip:AddLine("Uses the theme's own accent", 0.75, 0.78, 0.82) end
        GameTooltip:Show()
      end)
      sw:SetScript("OnLeave", function() GameTooltip:Hide() end)
      swatches[#swatches + 1] = sw
    end
    return 52
  end)
  local opacity, psize
  panel(gLook, "Size and opacity", function(b)
    opacity = UI.Slider(b, 260, 0.4, 1, 0.05,
      function() return S().overlayAlpha or 0.95 end,
      function(v) S().overlayAlpha = v UI.ApplyOverlayAlpha() end,
      function(v) return math.floor(v * 100 + 0.5) .. " %" end)
    opacity.label:SetText("Background opacity")
    opacity:SetPoint("TOPLEFT", 0, -16)
    psize = UI.Slider(b, 260, 0.6, 1.3, 0.05,
      function() return S().popupScale or 1 end,
      function(v) S().popupScale = v UI.ApplyPopupScale() if ns.Window.ApplyScale then ns.Window:ApplyScale() end end,
      function(v) return math.floor(v * 100 + 0.5) .. " %" end)
    psize.label:SetText("Interface scale")
    psize:SetPoint("TOPLEFT", 300, -16)
    UI.InfoTip(b, psize.label, "Interface scale", "Applies to the main window and notifications. 80 % is recommended at 1080p.")
    local ptest = UI.Button(b, 150, 26, "Show a test popup", "secondary", function()
      if ns.Overlays and ns.Overlays.ShowDing and ns.Tracker then
        local c = ns.Tracker:MyChar()
        ns.Overlays:ShowDing({ kind = "DING", id = "popup-test", pid = ns.pid, char = c and c.name, a = (c and c.level) or 1, t = ns.Now(), test = true })
      end
      ns:Fire("TOAST", { kind = "online", title = "Popup size test", text = "This is how big popups are now." })
    end)
    ptest:SetPoint("TOPLEFT", 0, -62)
    local editBtn = UI.Button(b, 170, 26, "Move things on screen", "secondary", function() UI.EditMode(true) end)
    editBtn:SetPoint("LEFT", ptest, "RIGHT", 8, 0)
    editBtn.tooltip = "Edit mode: move all Chillan frames at once, with 1080p and 1440p presets (/chill edit)"
    return 90
  end)

  -------------------------------------------------------------------------
  -- Windows and layout
  -------------------------------------------------------------------------
  local gWin = group("windows", "Windows")
  local winDefs = {
    { "Minibar on screen", "minibar", function() ns:Fire("MINIBAR") end },
    { "Minimap button", "minimapButton", function() ns:Fire("MINIBAR") end },
    { "Event window", "eventFeed", function() ns.EventWindow:Apply() end },
    { "Gang chat in the event window", "feedChat", function() ns.EventWindow:Redraw() end },
    { "Attach the event window to the Chillan? bar", "evDocked", function(v) ns.EventWindow:SetDocked(v) end },
    { "Fade the event window when quiet", "evFade" },
    { "Battleground objectives in the event window", "bgPanel", function() if ns.BGPanel then ns.BGPanel:Apply() end end,
      "In a battleground the gang chat is paused, so the event window shows bases, timers, the win estimate and the flag carriers instead." },
    { "Lock positions", "locked", function(v) ns:Fire("LOCK_CHANGED", v) end,
      "Stops the minibar, event window and popups from being dragged by accident. Also /chill lock." },
  }
  panel(gWin, "Windows and layout", function(b)
    local h = switches(gWin, winDefs)(b)
    local reset = UI.Button(b, 170, 26, "Reset positions", "ghost", function()
      UI.ResetPositions()
      if ns.Overlays.placeMinimap then ns.Overlays.placeMinimap() end
      ns.Print("Everything is back in its default place.")
    end)
    reset:SetPoint("TOPLEFT", 0, -h - 8)
    return h + 36
  end, true)

  -------------------------------------------------------------------------
  -- Notifications: popups, sounds, recaps
  -------------------------------------------------------------------------
  local gNote = group("notifications", "Notifications")
  local LEVELS = {
    { "calm", "Calm", "Major events only: level 60, epic items, first mounts, rare achievements and enemy warnings. Deaths appear in the feed only." },
    { "normal", "Normal", "A member's death is shown once, then muted for 10 minutes (up to 6 per hour). Everything else appears in the feed." },
    { "all", "All", "Shows every death. Player kills appear in the feed only." },
  }
  local PLACES = {
    { "attached", "Attached", "Notifications slide out from the side of the Pulse window. When the Pulse window is hidden, they appear at the top of the screen." },
    { "free", "Free", "Notifications appear at the top of the screen. Unlock the layout to move them." },
    { "off", "Off", "No notifications. Events appear in the feed only." },
  }
  local function curPlace()
    if S().toasts == false then return "off" end
    return S().popupPlace or "attached"
  end
  panel(gNote, "Popups", function(b)
    local function choiceRow(y, label, tip, defs, get, set)
      local l = UI.Text(b, 12, nil, C.text)
      l:SetPoint("TOPLEFT", 0, -y - 6)
      l:SetText(label)
      UI.InfoTip(b, l, label, tip)
      local opts = {}
      for i, d in ipairs(defs) do opts[i] = { d[2], d[3] } end
      local sg = UI.Seg(b, opts, function()
        for i, d in ipairs(defs) do if d[1] == get() then return i end end
        return 1
      end, function(i) set(defs[i][1]) end)
      sg:SetPoint("TOPRIGHT", 0, -y)
      refreshers[#refreshers + 1] = function() sg:Refresh() end
      rows[#rows + 1] = { group = "notifications", label = label:lower() }
    end
    choiceRow(0, "How many", "How many things pop up. Calm: milestones only. Normal: a member's death once per 10 minutes. All: every death.", LEVELS,
      function() return ns.PopupLevel() end, function(k) S().popupLevel = k ns.PopupGateReset() end)
    choiceRow(34, "Where", "Attached: out of the Pulse window's side. Free: top of the screen. Off: the feed only.", PLACES, curPlace, function(k)
      if k == "off" then S().toasts = false else S().toasts = true S().popupPlace = k end
      if ns.Settings and ns.Settings.Refresh then pcall(ns.Settings.Refresh, ns.Settings) end
    end)
    local h = switches(gNote, {
      { "Delay until combat ends", "combatQueue", nil, "Level-ups, deaths and achievements are shown after you leave combat." },
      { "Member logins", "onlineToasts" },
    })(b)
    -- place the switch rows under the two choices
    local last = rows[#rows].row
    local first = rows[#rows - 1].row
    first:ClearAllPoints() first:SetPoint("TOPLEFT", 0, -68) first:SetPoint("TOPRIGHT", 0, -68)
    last:ClearAllPoints() last:SetPoint("TOPLEFT", 0, -98) last:SetPoint("TOPRIGHT", 0, -98)
    return 68 + h
  end, true)
  panel(gNote, "Sounds", switches(gNote, {
    { "Sounds", "sounds" },
    { "@mentions", "mentionSound", nil, "Triggers on your display name, character name and @all." },
    { "New chat messages", "chatSound", nil, "Plays a short sound for new gang chat messages. Muted in combat." },
    { "Member login and logout", "presenceSound" },
  }))
  panel(gNote, "Recaps", switches(gNote, {
    { "Summary at login", "briefing" },
    { "Level summary on level-up", "levelRecap" },
    { "After sessions, dungeons and battlegrounds", "recaps", nil, "A small prompt offers a recap of your last session at login, and when a dungeon, raid or battleground ends." },
  }))
  panel(gNote, "Other", switches(gNote, {
    { "Low durability warning (30 % and 10 %)", "duraWarn" },
    { "Copy to the default chat frame", "chatMirror", function(v) S().activityMirror = v end, "Gang chat and events are also shown in the default chat frame." },
  }))

  -------------------------------------------------------------------------
  -- Quiet: do not disturb, muted members
  -------------------------------------------------------------------------
  local gQuiet = group("quiet", "Quiet")
  local mutedRows, mutedHint = {}, nil
  panel(gQuiet, "Do not disturb", function(b)
    local r = UI.SwitchRow(b, "Do not disturb", function() return ns:IsDND() end,
      function(v) ns.Tracker:SetStatus(v and "DND" or "AUTO") end,
      "Sets your status to Do not disturb. Everything still lands in the feed and the normal chat window – just no popups or sounds, @mentions included. Same as picking the status on the Friends page.")
    r:SetPoint("TOPLEFT") r:SetPoint("TOPRIGHT")
    rows[#rows + 1] = { group = "quiet", label = "do not disturb", row = r }
    return 30
  end, true)
  panel(gQuiet, "Muted members", function(b)
    mutedHint = hintText(b, "")
    for i = 1, 12 do
      local r = CreateFrame("Frame", nil, b)
      r:SetHeight(26)
      r:SetPoint("TOPLEFT", 0, -20 - (i - 1) * 28)
      r:SetPoint("TOPRIGHT", 0, -20 - (i - 1) * 28)
      r.name = UI.Text(r, 12, nil, C.text)
      r.name:SetPoint("LEFT")
      r.btn = UI.Button(r, 76, 22, "Unmute", "ghost")
      r.btn:SetPoint("RIGHT")
      r:Hide()
      mutedRows[i] = r
    end
    return 20 + 12 * 28
  end)
  rows[#rows + 1] = { group = "quiet", label = "muted members unmute" }
  local function refreshMuted()
    local list = {}
    for pid in pairs(ns.db.muted or {}) do
      local p = ns:GetPerson(pid)
      if p then list[#list + 1] = p end
    end
    table.sort(list, function(a, b) return (ns:PersonFirst(a) or "") < (ns:PersonFirst(b) or "") end)
    for i, r in ipairs(mutedRows) do
      local p = list[i]
      r:SetShown(p ~= nil)
      if p then
        r.name:SetText(ns:PersonLabel(p))
        r.btn:SetScript("OnClick", function() ns:SetMuted(p.pid, false) tab:Refresh() end)
      end
    end
    if mutedHint then
      mutedHint:SetText(#list == 0 and "None. Mute a member from the Gang page or their profile to silence their notifications and sounds."
        or "No notifications or sounds from these members:")
    end
  end

  -------------------------------------------------------------------------
  -- Map & radar, Layer hop, Market
  -------------------------------------------------------------------------
  local gMap = group("map", "Map & radar")
  panel(gMap, "Map", switches(gMap, {
    { "Members on the world map", "mapPins", function() ns:Fire("MAP_PINS") end, "Shows class-coloured pins at members' positions." },
    { "Offline members (last known position)", "mapPinsOffline", function() ns:Fire("MAP_PINS") end },
    { "Gang notes on the map", "mapNotes", function() ns:Fire("MAP_PINS") end, "Alt + right-click the world map to add a note. Right-click your own note to remove it." },
  }), true)
  panel(gMap, "Radar and buddies", switches(gMap, {
    { "Group radar", "radar", nil, "Notifies you when an ungrouped member within 3 levels is in your zone (at most once per 30 minutes)." },
    { "Quest buddy", "questBuddy", nil, "Notifies you when you accept a quest a member also has. Not shown while grouped." },
    { "Weekly titles", "titles", function() ns:MarkDirty() end, "Notifies you when a weekly title changes holder." },
  }))
  local gLayer = group("layer", "Layer hop")
  panel(gLayer, "Layer hop", switches(gLayer, {
    { "Host gang members", "layerHost", nil, "Invites members on another layer in your zone who request a layer hop. Only when you are ungrouped, out of combat and outside instances. They leave the group automatically." },
    { "Host for layer addons", "layerStrangers", nil, "Invites players in your zone who ask for a layer change with LayerSwap, Layer Anarchy, Forever Layer Hop, VoidNet or AutoLayer. At most 6 per 10 minutes, only while ungrouped." },
  }), true)
  local gMarket = group("market", "Market")
  panel(gMarket, "Market", switches(gMarket, {
    { "Market on (prices in tooltips)", "market", function(v) if v and ns.Market then ns.Market:HookTooltips() end end, "The whole Chillan? Market: scanning, tooltip lines and sharing." },
    { "Market window beside the auction house", "mkWindow", nil, "Sell, Buy, My auctions, Item Tracker and Gang, beside the auction house." },
    { "Share prices with the gang", "marketShare", nil, "After you scan, the prices that changed go to the gang quietly; friends logging in get the newest ones." },
  }), true)
  panel(gMarket, "More", function(b)
    hintText(b, "Tooltip lines, disenchanting and price sharing details are on the Market page.")
    local go = UI.Button(b, 150, 26, "Open the Market page", "secondary", function() ns.Window:Select("market") end)
    go:SetPoint("TOPLEFT", 0, -20)
    return 48
  end)

  -------------------------------------------------------------------------
  -- the side list and the search
  -------------------------------------------------------------------------
  local function show(key)
    current = key
    for k, g in pairs(groups) do g:SetShown(k == key) end
    content:SetHeight(math.max(10, groups[key].h))
    scroll:SetVerticalScroll(0)
    for k, nb in pairs(navBtns) do
      local on = k == key
      nb.bg:SetShown(on) nb.bar:SetShown(on)
      nb.text:SetTextColor(hex(on and C.text or (nb.dimmed and C.dim or C.muted)))
    end
  end
  for i, key in ipairs(order) do
    local g = groups[key]
    local nb = CreateFrame("Button", nil, navP.body)
    nb:SetHeight(28)
    nb:SetPoint("TOPLEFT", 0, -34 - (i - 1) * 30)
    nb:SetPoint("TOPRIGHT", 0, -34 - (i - 1) * 30)
    nb.bg = UI.Track(nb:CreateTexture(nil, "BACKGROUND"))
    nb.bg:SetAllPoints()
    do local r, gg, b = hex(C.accent) nb.bg:SetColorTexture(r, gg, b, 0.13) end
    nb.bar = UI.Track(nb:CreateTexture(nil, "ARTWORK"))
    nb.bar:SetWidth(2)
    nb.bar:SetPoint("TOPLEFT") nb.bar:SetPoint("BOTTOMLEFT")
    nb.bar:SetColorTexture(hex(C.accent))
    nb.hl = nb:CreateTexture(nil, "HIGHLIGHT")
    nb.hl:SetAllPoints()
    nb.hl:SetColorTexture(1, 1, 1, 0.04)
    nb.text = UI.Text(nb, 12, "semi", C.muted)
    nb.text:SetPoint("LEFT", 10, 0)
    nb.text:SetText(g.label)
    nb.count = UI.Text(nb, 10, nil, C.dim)
    nb.count:SetPoint("RIGHT", -8, 0)
    nb:SetScript("OnClick", function() show(key) end)
    navBtns[key] = nb
  end
  local function filter()
    local q = (search:GetText() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local firstHit
    for _, key in ipairs(order) do
      local n = 0
      if q ~= "" then
        if groups[key].label:lower():find(q, 1, true) then n = n + 1 end
        for _, r in ipairs(rows) do if r.group == key and r.label:find(q, 1, true) then n = n + 1 end end
      end
      local nb = navBtns[key]
      nb.dimmed = q ~= "" and n == 0
      nb.count:SetText(q ~= "" and n > 0 and tostring(n) or "")
      if q ~= "" and n > 0 and not firstHit then firstHit = key end
    end
    if firstHit and (navBtns[current].dimmed) then show(firstHit) else show(current) end
  end
  search.edit:HookScript("OnTextChanged", filter)
  search.edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  show("gang")

  function tab:Refresh()
    if codeBox then codeBox:SetText(ns.db.code or "") end
    if aliasBox and not aliasBox.edit:HasFocus() then aliasBox:SetText(ns.db.alias or "") end
    S().blueLoot = (S().lootMinQuality or 4) <= 3
    for _, r in ipairs(rows) do if r.row then r.row:Refresh() end end
    for _, f in ipairs(refreshers) do f() end
    refreshMuted()
    for _, card in ipairs(themeCards) do card.ring:SetShown((S().theme or "graphite") == card.key) end
    for _, sw in ipairs(swatches) do
      sw.ring:SetShown((S().accent or "class") == sw.key)
      UI.Track(sw.dot):SetVertexColor(hex(ns.AccentHex(sw.key, S().theme)))
    end
    if opacity then opacity:Refresh() end
    if psize then psize:Refresh() end
  end
  -- open a group from elsewhere: ns.Window:Select("settings") then tab:ShowGroup("quiet")
  function tab:ShowGroup(key) if groups[key] then show(key) end end
end)
