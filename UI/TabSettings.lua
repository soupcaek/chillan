-- Chillan? – "Settings" tab: appearance, windows, notifications and modules (scrollable)
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("settings", "Settings", "Gear", function(tab)
  local S = function() return ns.db.settings end
  local checks = {}

  -- scroll area so the page can grow
  local scroll = CreateFrame("ScrollFrame", nil, tab)
  scroll:SetPoint("TOPLEFT", 0, -4)
  scroll:SetPoint("BOTTOMRIGHT", 0, 4)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(700, 900)
  scroll:SetScrollChild(content)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, content:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 40)))
  end)
  scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)

  local function section(parent, anchor, title, gap)
    local h = UI.Text(parent, 14, "semi", C.text)
    if anchor then h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or 18)) else h:SetPoint("TOPLEFT") end
    h:SetText(title)
    return h
  end
  local function hint(parent, anchor, text)
    local t = UI.Text(parent, 11, nil, C.dim)
    t:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -5)
    t:SetText(text)
    return t
  end

  local function checkList(parent, anchor, defs)
    local last = anchor
    for i, def in ipairs(defs) do
      local cb = UI.Check(parent, def[1], function() return S()[def[2]] and true or false end, function(v)
        S()[def[2]] = v
        if def[3] then def[3](v) end
      end)
      cb:SetWidth(320)
      cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, i == 1 and -8 or -2)
      if def[4] then
        cb:HookScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:AddLine(def[1], 1, 1, 1)
          GameTooltip:AddLine(def[4], 0.75, 0.78, 0.82, true)
          GameTooltip:Show()
        end)
        cb:HookScript("OnLeave", function() GameTooltip:Hide() end)
      end
      checks[#checks + 1] = cb
      last = cb
    end
    return last
  end

  local applied = { theme = S().theme or "graphite", accent = S().accent or "class" }
  local reloadBtn

  -------------------------------------------------------------------------
  -- Appearance (full width)
  -------------------------------------------------------------------------
  local top = CreateFrame("Frame", nil, content)
  top:SetPoint("TOPLEFT", 18, -14)
  top:SetSize(660, 10)
  local ah = section(top, nil, "Appearance")
  local th = hint(top, ah, "Theme – changes the whole addon")

  local themeCards = {}
  for i, t in ipairs(ns.THEMES) do
    local card = CreateFrame("Button", nil, content)
    card:SetSize(104, 62)
    card:SetPoint("TOPLEFT", th, "BOTTOMLEFT", (i - 1) * 110, -8)
    card.key = t.key
    card.bg = UI.Panel(card, t.c.window, t.c.line, false)
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
    card.dot:SetVertexColor(hex(t.c.accent))
    card.line = card.inner:CreateTexture(nil, "OVERLAY")
    card.line:SetColorTexture(hex(t.c.muted))
    card.line:SetSize(40, 3)
    card.line:SetPoint("LEFT", card.dot, "RIGHT", 6, 0)
    card.name = UI.Text(card, 12, "semi", t.c.text)
    card.name:SetPoint("BOTTOMLEFT", 8, 8)
    card.name:SetText(t.name)
    card.ring = UI.Panel(card, nil, C.accent, false)
    card.ring:SetPoint("TOPLEFT", -2, 2)
    card.ring:SetPoint("BOTTOMRIGHT", 2, -2)
    card:SetScript("OnClick", function() S().theme = t.key tab:Refresh() end)
    card:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(t.name, 1, 1, 1)
      GameTooltip:AddLine(t.desc, 0.75, 0.78, 0.82)
      GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function() GameTooltip:Hide() end)
    themeCards[#themeCards + 1] = card
  end

  local acl = UI.Text(content, 11, nil, C.dim)
  acl:SetPoint("TOPLEFT", th, "BOTTOMLEFT", 0, -82)
  acl:SetText("Accent – buttons, tabs and highlights")
  local swatches = {}
  for i, a in ipairs(ns.ACCENTS) do
    local sw = CreateFrame("Button", nil, content)
    sw:SetSize(26, 26)
    sw:SetPoint("TOPLEFT", acl, "BOTTOMLEFT", (i - 1) * 32, -8)
    sw.key = a.key
    sw.ring = sw:CreateTexture(nil, "BACKGROUND")
    sw.ring:SetTexture(ns.TEX .. "Circle")
    sw.ring:SetAllPoints()
    sw.ring:SetVertexColor(hex(C.text))
    sw.dot = sw:CreateTexture(nil, "ARTWORK")
    sw.dot:SetTexture(ns.TEX .. "Circle")
    sw.dot:SetPoint("CENTER")
    sw.dot:SetSize(20, 20)
    if a.key == "theme" or a.key == "class" then
      sw.letter = UI.Text(sw, 10, "bold", "121417")
      sw.letter:SetPoint("CENTER")
      sw.letter:SetText(a.key == "theme" and "T" or "C")
    end
    sw:SetScript("OnClick", function() S().accent = a.key tab:Refresh() end)
    sw:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(a.name, 1, 1, 1)
      if a.key == "theme" then GameTooltip:AddLine("Uses the theme's own accent", 0.75, 0.78, 0.82) end
      GameTooltip:Show()
    end)
    sw:SetScript("OnLeave", function() GameTooltip:Hide() end)
    swatches[#swatches + 1] = sw
  end

  local opacity = UI.Slider(content, 300, 0.4, 1, 0.05,
    function() return S().overlayAlpha or 0.95 end,
    function(v) S().overlayAlpha = v UI.ApplyOverlayAlpha() end,
    function(v) return math.floor(v * 100 + 0.5) .. " %" end)
  opacity.label:SetText("Opacity of popups, event window and tiles")
  opacity:SetPoint("TOPLEFT", acl, "BOTTOMLEFT", 0, -44)

  reloadBtn = UI.Button(content, 240, 28, "Apply theme (reloads the UI)", "primary", function() ReloadUI() end)
  reloadBtn:SetPoint("LEFT", opacity, "RIGHT", 30, -2)

  -------------------------------------------------------------------------
  -- Two columns below
  -------------------------------------------------------------------------
  local left = CreateFrame("Frame", nil, content)
  left:SetPoint("TOPLEFT", opacity, "BOTTOMLEFT", 0, -22)
  left:SetSize(330, 10)
  local right = CreateFrame("Frame", nil, content)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 24, 0)
  right:SetSize(330, 10)

  local wh = section(left, nil, "Windows and layout")
  local lastW = checkList(left, wh, {
    { "Minibar on screen", "minibar", function() ns:Fire("MINIBAR") end },
    { "Minimap button", "minimapButton", function() ns:Fire("MINIBAR") end },
    { "Event window", "eventFeed", function() ns.EventWindow:Apply() end },
    { "Gang chat in the event window", "feedChat", function() ns.EventWindow:Redraw() end },
    { "Attach the event window to the Chillan? bar", "evDocked", function(v) ns.EventWindow:SetDocked(v) end },
    { "Fade the event window when quiet", "evFade" },
    { "Lock positions", "locked", function(v) ns:Fire("LOCK_CHANGED", v) end,
      "Stops the minibar, event window and popups from being dragged by accident. Also /chill lock." },
  })
  local resetPos = UI.Button(left, 170, 26, "Reset positions", "ghost", function()
    UI.ResetPositions()
    if ns.Overlays.placeMinimap then ns.Overlays.placeMinimap() end
    ns.Print("Everything is back in its default place.")
  end)
  resetPos:SetPoint("TOPLEFT", lastW, "BOTTOMLEFT", 0, -8)

  local nh = section(right, nil, "Notifications")
  local lastN = checkList(right, nh, {
    { "Sounds", "sounds" },
    { "Popup notifications", "toasts" },
    { "When friends log in", "onlineToasts" },
    { "Hold popups until after combat", "combatQueue", nil,
      "Dings, deaths, achievements and notifications wait until you leave combat. SOS always shows right away." },
    { "\"Since you last played\" card at login", "briefing" },
    { "Sound and alert when someone @mentions you", "mentionSound", nil,
      "Matches your nickname, your character name and @all." },
    { "Sound for new gang chat messages", "chatSound", nil, "A short pop when someone writes in gang chat (not in combat)." },
    { "Sound when friends log in and out", "presenceSound" },
    { "Warn when gear durability is low (30 % and 10 %)", "duraWarn" },
    { "Also in the normal WoW chat", "chatMirror", function(v) S().activityMirror = v end,
      "Gang chat and events are also printed in the default chat window." },
  })

  local mh = section(right, lastN, "Modules")
  checkList(right, mh, {
    { "Quest buddy", "questBuddy", nil, "Alert when you pick up a quest a friend also has (not when you're grouped)." },
    { "Group radar", "radar", nil, "Alert when a friend within ±3 levels is in your zone and you're not grouped (max once per 30 min)." },
    { "Weekly titles", "titles", function() ns:MarkDirty() end, "Alert when a title like «Floor Inspector» changes hands." },
    { "Friends on the world map", "mapPins", function() ns:Fire("MAP_PINS") end, "Class-coloured pins where your friends are." },
    { "Offline friends on the map (last known spot, dimmed)", "mapPinsOffline", function() ns:Fire("MAP_PINS") end },
    { "Gang notes on the map", "mapNotes", function() ns:Fire("MAP_PINS") end, "Alt + right-click the world map to add one. Right-click your own note to remove it." },
    { "Share blue drops in the feed (not just epics)", "blueLoot", function(v) S().lootMinQuality = v and 3 or 4 end },
  })

  function tab:Refresh()
    S().blueLoot = (S().lootMinQuality or 4) <= 3
    for _, cb in ipairs(checks) do cb:Refresh() end
    for _, card in ipairs(themeCards) do card.ring:SetShown((S().theme or "graphite") == card.key) end
    for _, sw in ipairs(swatches) do
      sw.ring:SetShown((S().accent or "class") == sw.key)
      sw.dot:SetVertexColor(hex(ns.AccentHex(sw.key, S().theme)))
    end
    opacity:Refresh()
    reloadBtn:SetShown((S().theme or "graphite") ~= applied.theme or (S().accent or "class") ~= applied.accent)
  end
end)
