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
  content:SetSize(700, 1300)
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
  -------------------------------------------------------------------------
  -- Your gang (1.1.7, moved here from the Gang page): code, your name, add a friend by hand
  -------------------------------------------------------------------------
  local gang = CreateFrame("Frame", nil, content)
  gang:SetPoint("TOPLEFT", 18, -14)
  gang:SetSize(700, 10)
  local gh = section(gang, nil, "Your gang")
  local gver = UI.Text(gang, 11, nil, C.dim)
  gver:SetPoint("LEFT", gh, "RIGHT", 10, 0)
  gver:SetText("version " .. ns.VERSION)
  local cl = UI.Text(gang, 11, nil, C.dim)
  cl:SetPoint("TOPLEFT", gh, "BOTTOMLEFT", 0, -8)
  cl:SetText("Gang code – share it with your group to join")
  local codeBox = UI.EditBox(gang, 200, 30, "No code")
  codeBox:SetPoint("TOPLEFT", cl, "BOTTOMLEFT", 0, -5)
  codeBox.edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  codeBox.edit:SetScript("OnTextChanged", function(self, user)
    if user then self:SetText(ns.db.code or "") self:HighlightText() end
  end)
  local change = UI.Button(gang, 76, 30, "Change", "ghost", function()
    UI.Prompt("Change gang", { { label = "New gang code", placeholder = "CHILL-XXXX" } }, function(v)
      if ns.ChangeCode(v) then ns.Print("Switched to the gang " .. ns.db.code .. ".") else return true end
    end)
  end)
  change:SetPoint("LEFT", codeBox, "RIGHT", 6, 0)
  local al = UI.Text(gang, 11, nil, C.dim)
  al:SetPoint("LEFT", cl, "LEFT", 320, 0)
  al:SetText("Display name – shown next to your characters")
  local aliasBox = UI.EditBox(gang, 200, 30, "e.g. Henrik", function(self) ns.SetAlias(self:GetText()) self:ClearFocus() end)
  aliasBox:SetPoint("TOPLEFT", al, "BOTTOMLEFT", 0, -5)
  local saveAlias = UI.Button(gang, 66, 30, "Save", "secondary", function() ns.SetAlias(aliasBox:GetText()) aliasBox.edit:ClearFocus() end)
  saveAlias:SetPoint("LEFT", aliasBox, "RIGHT", 6, 0)
  local addFriend = UI.Button(gang, 282, 26, "Member missing? Add by character name", "ghost", function()
    UI.Prompt("Add friend manually", {
      { label = "Character name (use this if a friend doesn't show up)", placeholder = "Name or Name-Realm" },
    }, function(v) ns.Data:AddManual(v) end)
  end)
  addFriend:SetPoint("TOPLEFT", codeBox, "BOTTOMLEFT", 0, -8)
  local cmds = UI.Text(gang, 11, nil, C.dim)
  cmds:SetPoint("LEFT", addFriend, "RIGHT", 38, 0)
  cmds:SetText("Commands: /chill · /cg text · /chill edit · /chill selftest")
  tab.gangRefresh = function()
    codeBox:SetText(ns.db.code or "")
    if not aliasBox.edit:HasFocus() then aliasBox:SetText(ns.db.alias or "") end
  end

  local top = CreateFrame("Frame", nil, content)
  top:SetPoint("TOPLEFT", addFriend, "BOTTOMLEFT", 0, -22)
  top:SetSize(660, 10)
  local ah = section(top, nil, "Appearance")
  local th = hint(top, ah, "Theme")

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
    UI.Track(card.dot):SetVertexColor(hex(t.c.accent))
    card.line = card.inner:CreateTexture(nil, "OVERLAY")
    UI.Track(card.line):SetColorTexture(hex(t.c.muted))
    card.line:SetSize(40, 3)
    card.line:SetPoint("LEFT", card.dot, "RIGHT", 6, 0)
    card.name = UI.Text(card, 12, "semi", t.c.text)
    card.name:SetPoint("BOTTOMLEFT", 8, 8)
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

  local acl = UI.Text(content, 11, nil, C.dim)
  acl:SetPoint("TOPLEFT", th, "BOTTOMLEFT", 0, -82)
  acl:SetText("Accent colour – buttons, tabs and highlights")
  local swatches = {}
  for i, a in ipairs(ns.ACCENTS) do
    local sw = CreateFrame("Button", nil, content)
    sw:SetSize(26, 26)
    sw:SetPoint("TOPLEFT", acl, "BOTTOMLEFT", (i - 1) * 32, -8)
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

  local opacity = UI.Slider(content, 300, 0.4, 1, 0.05,
    function() return S().overlayAlpha or 0.95 end,
    function(v) S().overlayAlpha = v UI.ApplyOverlayAlpha() end,
    function(v) return math.floor(v * 100 + 0.5) .. " %" end)
  opacity.label:SetText("Background opacity")
  opacity:SetPoint("TOPLEFT", acl, "BOTTOMLEFT", 0, -44)

  reloadBtn = UI.Button(content, 240, 28, "Apply theme (reloads the UI)", "primary", function() ReloadUI() end)
  reloadBtn:SetPoint("LEFT", opacity, "RIGHT", 30, -2)

  -- smaller screens (1080p): shrink the popups
  local psize = UI.Slider(content, 300, 0.6, 1.3, 0.05,
    function() return S().popupScale or 1 end,
    function(v) S().popupScale = v UI.ApplyPopupScale() if ns.Window.ApplyScale then ns.Window:ApplyScale() end end,
    function(v) return math.floor(v * 100 + 0.5) .. " %" end)
  psize.label:SetText("Interface scale")
  psize:SetPoint("TOPLEFT", opacity, "BOTTOMLEFT", 0, -44)
  local phint = UI.Text(content, 10, nil, C.dim)
  phint:SetPoint("TOPLEFT", psize, "BOTTOMLEFT", 0, -6)
  phint:SetText("Applies to the main window and notifications. 80 % is recommended at 1080p.")
  local ptest = UI.Button(content, 160, 26, "Show a test popup", "secondary", function()
    -- a pretend ding of your own (not sent to anyone) and a toast
    if ns.Overlays and ns.Overlays.ShowDing and ns.Tracker then
      local c = ns.Tracker:MyChar()
      ns.Overlays:ShowDing({ kind = "DING", id = "popup-test", pid = ns.pid, char = c and c.name, a = (c and c.level) or 1, t = ns.Now(), test = true })
    end
    ns:Fire("TOAST", { kind = "online", title = "Popup size test", text = "This is how big popups are now." })
  end)
  ptest:SetPoint("LEFT", psize, "RIGHT", 30, -2)
  local editBtn = UI.Button(content, 150, 26, "Move things on screen", "secondary", function() UI.EditMode(true) end)
  editBtn:SetPoint("LEFT", ptest, "RIGHT", 8, 0)
  editBtn.tooltip = "Edit mode: move all Chillan frames at once, with 1080p and 1440p presets (/chill edit)"

  -------------------------------------------------------------------------
  -- Two columns below
  -------------------------------------------------------------------------
  local left = CreateFrame("Frame", nil, content)
  left:SetPoint("TOPLEFT", phint, "BOTTOMLEFT", 0, -18)
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

  -------------------------------------------------------------------------
  -- Do not disturb + muted friends (left column, under the layout buttons)
  -------------------------------------------------------------------------
  local qh = section(left, resetPos, "Quiet", 22)
  local dnd = UI.Check(left, "Do not disturb (mutes all notifications and sounds)",
    function() return ns:IsDND() end,
    function(v) ns.Tracker:SetStatus(v and "DND" or "AUTO") end)
  dnd:SetWidth(320)
  -- how many popups (1.0.1): calm = milestones only, normal = deaths once per 10 min, all = every death. Kills never pop up (1.4.5)
  local plabel = UI.Text(left, 12, nil, C.text)
  plabel:SetPoint("TOPLEFT", qh, "BOTTOMLEFT", 0, -10)
  plabel:SetText("Popups")
  local LEVELS = {
    { "calm", "Calm", "Major events only: level 60, epic items, first mounts, rare achievements and enemy warnings. Deaths appear in the feed only." },
    { "normal", "Normal", "A member's death is shown once, then muted for 10 minutes (up to 6 per hour). Everything else appears in the feed." },
    { "all", "All", "Shows every death. Player kills appear in the feed only." },
  }
  local pbtns = {}
  local function paintLevels()
    for _, b in ipairs(pbtns) do b:SetStyle(ns.PopupLevel() == b.key and "primary" or "secondary") end
  end
  for i, lv in ipairs(LEVELS) do
    local b = UI.Button(left, 74, 24, lv[2], "secondary", function()
      S().popupLevel = lv[1]
      ns.PopupGateReset()
      paintLevels()
    end)
    b.key, b.tooltip = lv[1], lv[3]
    if i == 1 then b:SetPoint("LEFT", plabel, "LEFT", 60, 0) else b:SetPoint("LEFT", pbtns[i - 1], "RIGHT", 6, 0) end
    pbtns[i] = b
  end
  paintLevels()
  left:HookScript("OnShow", paintLevels)
  -- (1.4.18) where popups show: out of the Pulse window's side, free at the top of the screen, or not at all
  local wlabel = UI.Text(left, 12, nil, C.text)
  wlabel:SetPoint("TOPLEFT", plabel, "BOTTOMLEFT", 0, -18)
  wlabel:SetText("Where")
  local PLACES = {
    { "attached", "Attached", "Notifications slide out from the side of the Pulse window. When the Pulse window is hidden, they appear at the top of the screen." },
    { "free", "Free", "Notifications appear at the top of the screen. Unlock the layout to move them." },
    { "off", "Off", "No notifications. Events appear in the feed only." },
  }
  local wbtns = {}
  local function curPlace()
    if S().toasts == false then return "off" end
    return S().popupPlace or "attached"
  end
  local function paintPlaces()
    for _, b in ipairs(wbtns) do b:SetStyle(curPlace() == b.key and "primary" or "secondary") end
  end
  for i, pl in ipairs(PLACES) do
    local b = UI.Button(left, 74, 24, pl[2], "secondary", function()
      if pl[1] == "off" then S().toasts = false
      else S().toasts = true S().popupPlace = pl[1] end
      paintPlaces()
      if ns.Settings and ns.Settings.Refresh then pcall(ns.Settings.Refresh, ns.Settings) end
    end)
    b.key, b.tooltip = pl[1], pl[3]
    if i == 1 then b:SetPoint("LEFT", wlabel, "LEFT", 60, 0) else b:SetPoint("LEFT", wbtns[i - 1], "RIGHT", 6, 0) end
    wbtns[i] = b
  end
  paintPlaces()
  left:HookScript("OnShow", paintPlaces)
  dnd:SetPoint("TOPLEFT", wlabel, "BOTTOMLEFT", 0, -16)
  dnd:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Do not disturb", 1, 1, 1)
    GameTooltip:AddLine("Sets your status to Do not disturb. Everything still lands in the feed and the normal chat window – just no popups or sounds, @mentions included. Same as picking the status on the Friends page.", 0.75, 0.78, 0.82, true)
    GameTooltip:Show()
  end)
  dnd:HookScript("OnLeave", function() GameTooltip:Hide() end)
  checks[#checks + 1] = dnd
  local mutedHint = hint(left, dnd, "Muted members: no notifications or sounds.\nMute a member from the Gang page or their profile.")
  local mutedRows = {}
  for i = 1, 12 do
    local r = CreateFrame("Frame", nil, left)
    r:SetSize(320, 24)
    r:SetPoint("TOPLEFT", mutedHint, "BOTTOMLEFT", 0, -6 - (i - 1) * 26)
    r.name = UI.Text(r, 12, nil, C.text)
    r.name:SetPoint("LEFT")
    r.btn = UI.Button(r, 76, 22, "Unmute", "ghost")
    r.btn:SetPoint("LEFT", 200, 0)
    r:Hide()
    mutedRows[i] = r
  end
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
    mutedHint:SetText(#list == 0 and "Muted members: none. Mute a member from the Gang page\nor their profile to silence their notifications and sounds."
      or "Muted members (no notifications or sounds):")
  end

  local nh = section(right, nil, "Notifications")
  local lastN = checkList(right, nh, {
    { "Sounds", "sounds" },
    { "Notifications", "toasts" },
    { "Member logins", "onlineToasts" },
    { "Delay notifications until combat ends", "combatQueue", nil,
      "Level-ups, deaths and achievements are shown after you leave combat." },
    { "Summary at login", "briefing" },
    { "Level summary on level-up", "levelRecap" },
    { "Recaps after sessions, dungeons and battlegrounds", "recaps", nil, "A small prompt offers a recap at login and logout (middle of the screen) and when a dungeon, raid or battleground ends (top of the screen)." },
    { "Alert on @mentions", "mentionSound", nil,
      "Triggers on your display name, character name and @all." },
    { "Sound on new chat messages", "chatSound", nil, "Plays a short sound for new gang chat messages. Muted in combat." },
    { "Sound on member login and logout", "presenceSound" },
    { "Low durability warning (30 % and 10 %)", "duraWarn" },
    { "Copy to the default chat frame", "chatMirror", function(v) S().activityMirror = v end,
      "Gang chat and events are also shown in the default chat frame." },
  })

  local mh = section(right, lastN, "Modules")
  checkList(right, mh, {
    { "Quest buddy", "questBuddy", nil, "Notifies you when you accept a quest a member also has. Not shown while grouped." },
    { "Group radar", "radar", nil, "Notifies you when an ungrouped member within 3 levels is in your zone (at most once per 30 minutes)." },
    { "Weekly titles", "titles", function() ns:MarkDirty() end, "Notifies you when a weekly title changes holder." },
    { "Members on the world map", "mapPins", function() ns:Fire("MAP_PINS") end, "Shows class-coloured pins at members' positions." },
    { "Offline members on the map (last known position)", "mapPinsOffline", function() ns:Fire("MAP_PINS") end },
    { "Gang notes on the map", "mapNotes", function() ns:Fire("MAP_PINS") end, "Alt + right-click the world map to add a note. Right-click your own note to remove it." },
    { "Layer hop: host gang members", "layerHost", nil, "Invites members on another layer in your zone who request a layer hop. Only when you are ungrouped, out of combat and outside instances. They leave the group automatically." },
    { "Layer hop: host LayerSwap users", "layerStrangers", nil, "Invites LayerSwap users in your zone who request a layer change. At most 6 per 10 minutes, only while ungrouped." },
  })

  function tab:Refresh()
    if tab.gangRefresh then tab.gangRefresh() end
    S().blueLoot = (S().lootMinQuality or 4) <= 3
    for _, cb in ipairs(checks) do cb:Refresh() end
    refreshMuted()
    for _, card in ipairs(themeCards) do card.ring:SetShown((S().theme or "graphite") == card.key) end
    for _, sw in ipairs(swatches) do
      sw.ring:SetShown((S().accent or "class") == sw.key)
      UI.Track(sw.dot):SetVertexColor(hex(ns.AccentHex(sw.key, S().theme)))
    end
    opacity:Refresh()
    psize:Refresh()
    reloadBtn:Hide()   -- themes change live since 1.1.5
  end
end)
