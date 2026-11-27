-- Chillan? – start-up and slash commands
local ADDON, ns = ...

ns:On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  ns:InitDB()
  if ns.db.code then ns.codeHash = ns.Hash(ns.db.code) end
  ns.Comm:Init()
end)

ns:On("PLAYER_LOGIN", function()
  ns.Tracker:Start()
  ns.Data:Start()
  ns.Ach:Start()
  ns.QoL:Start()
  C_Timer.After(20, function() ns.Tracker:CountMounts() end)
  ns.Overlays:Init()
  ns.PersonCard:Init()
  ns.EventWindow:Init()
  if ns.BGPanel then ns.BGPanel:Init() end
  ns.Recap:Init()
  ns.Tiles:Init()
  ns.Overlays:UpdateMinibar()
  ns.MapPins:Init()
  ns:Listen("CODE_CHANGED", function() ns.Overlays:UpdateMinibar() end)
  -- Automatisk feilsøk etter et par minutter hvis vi ikke hører noen
  -- (1.4.49) not inside an instance: there the game blocks addon messages, so silence is expected.
  -- The check waits until you've been out for 90 s.
  local function check()
    if not ns.db.code then return end
    if ns.commBlindSince then C_Timer.After(30, check) return end
    local st = ns.Comm.stats
    local trial = (IsTrialAccount and IsTrialAccount()) or (IsVeteranTrialAccount and IsVeteranTrialAccount())
    if trial then
      ns.Print("|cffF2777ATrial account detected:|r WoW doesn't let trial accounts send addon messages, so the gang can't see you until the account is upgraded.")
    elseif st.recv == 0 and st.otherCode > 0 then
      ns.Print("|cffF2777AWe hear Chillan? from a different gang code, but nobody from yours.|r Check that the code (" .. ns.db.code .. ") is exactly the same as the others have.")
    elseif st.recv == 0 then
      ns.Print("We haven't heard from anyone in the gang yet. Type /chill debug and send a screenshot to the gang, or ask a friend to type /chill add " .. (ns.Comm:MyFull() or "your name") .. ".")
    end
  end
  C_Timer.After(90, check)
end)

local started = false
ns:On("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
  if started then
    -- ny layer/instans/sone: ta kontakt på nytt med gjengen
    ns.Comm:OnWorldChanged()
    return
  end
  started = true
  C_Timer.After(5, function() ns.Comm:JoinChannel() end)
  C_Timer.After(7, function()
    ns.Data:Hello()
    ns.Tracker:SendStatus(1)
    ns.Tracker:SendStats(2)
  end)
  C_Timer.After(9, function()
    -- hent /played én gang i døgnet per karakter (resten telles løpende)
    local c = ns.Tracker:MyChar()
    if not c.played or not c.playedAt or (ns.Now() - c.playedAt) > 86400 then
      RequestTimePlayed()
    end
  end)
  C_Timer.After(30, function() ns.Tracker:SendProfessions() end)
  if not isReload then
    C_Timer.After(8, function()
      local last = ns.db.lastSession
      if last and not ns.db.lastSessionShown and (last.online or 0) >= 300 then
        ns.db.lastSessionShown = true
        -- (1.4.28) a pill offers the recap instead of the big card
        if not (ns.Recap and ns.db.settings.recaps ~= false and ns.Recap:Login(last)) then ns:Fire("SHOW_SUMMARY", last, true) end
      end
    end)
    C_Timer.After(12, function()
      if ns.db.code and not ns.db.alias then
        ns.UI.Prompt("What's your name?", {
          { label = "Your name – shown next to all your characters", placeholder = "e.g. Henrik" },
        }, function(v) if not ns.SetAlias(v) then return true end end)
      end
    end)
    if not ns.db.code then
      C_Timer.After(10, function()
        ns.Print("Welcome! Type |cff" .. ns.C.accent .. "/chill|r to create or join a gang.")
      end)
    end
  end
end)

-- Lagre gjengkoden på nytt når den endres (bli med i ny kanal)
ns:Listen("CODE_CHANGED", function()
  ns.Comm:JoinChannel()
  C_Timer.After(3, function()
    ns.Data:Hello()
    ns.Tracker:SendStatus(1)
    ns.Tracker:SendStats(2)
  end)
end)

---------------------------------------------------------------------------
-- Kommandoer
---------------------------------------------------------------------------
local function help()
  ns.Print("Commands:")
  print("  /chill – open/close the window")
  print("  /chill market – auction prices: how many you have (/chill market sync asks the gang)")
  print("  /chill selftest – which game functions work on this client")
  print("  /chill edit – move all Chillan pieces on screen")
  print("  /chill summary – show your session summary")
  print("  /chill enemy [reason] – put your target on the Cunt List")
  print("  /chill add Name – say hi to a friend who doesn't show up")
  print("  /chill events – show/hide the event window")
  print("  /chill lock – lock/unlock on-screen positions")
  print("  /chill ready – ready check before a dungeon")
  print("  /chill note text – gang note on the map where you stand (or Alt+right-click the map)")
  print("  /chill settings – open the settings")
  print("  /chill ideas – open the idea box")
  print("  /chill admin – become admin of the idea box (first one wins)")
  print("  /chill minibar – show/hide the minibar")
  print("  /chill debug – show technical status")
  print("  /chill channel – reconnect to the gang channel")
  print("  /cg text – write in gang chat")
end

-- Hurtigtast (Taster → AddOns)
BINDING_HEADER_CHILLAN = "Chillan?"
BINDING_NAME_CHILLAN_TOGGLE = "Open/close Chillan?"
BINDING_NAME_CHILLAN_CHAT = "Open gang chat"
function Chillan_ToggleBinding(key)
  if key == "chat" then ns.Window:Toggle("chat")
  else ns.Window:Toggle() end
end

SLASH_CHILLAN1 = "/chill"
SLASH_CHILLAN2 = "/chillan"
SlashCmdList.CHILLAN = function(msg)
  msg = msg or ""
  local cmd, rest = msg:match("^(%S*)%s*(.-)$")
  cmd = (cmd or ""):lower()
  if cmd == "" then
    ns.Window:Toggle()
  elseif cmd == "todo" then
    if ns.Notes then ns.Notes.Slash(rest) end
  elseif cmd == "notes" then
    if ns.Notes then ns.Notes.Open() end
  elseif cmd == "mktrace" then
    ns.db.settings.mkTrace = not ns.db.settings.mkTrace or nil
    ns.Print("Market trace " .. (ns.db.settings.mkTrace and "on." or "off."))
  elseif cmd == "rolls" or cmd == "lastroll" then
    if ns.LootRolls then ns.LootRolls:ShowPast(rest) end
  elseif cmd == "need" then
    if ns.LootRolls then ns.LootRolls:Test() end
  elseif cmd == "pull" then
    if ns.Extras.Pull then ns.Extras:Pull(rest) end
  elseif cmd == "versions" or cmd == "version" or cmd == "ver" then
    ns.PrintVersions()
  elseif cmd == "selftest" or cmd == "test" then
    ns.SelfTest()
  elseif cmd == "kit" and ns.Kit then
    ns.Kit:Toggle()
  elseif cmd == "popups" then
    ns.Print("Popups this session (newest last):")
    if not ns.popupLog or #ns.popupLog == 0 then print("  none") end
    for _, x in ipairs(ns.popupLog or {}) do print("  " .. date("%H:%M:%S", x.t) .. "  " .. x.kind .. "  " .. x.what) end
  elseif cmd == "market" and ns.Market then
    if rest == "who" then
      ns.Print("Market – online: " .. ns.Market:WhoText())
    elseif rest == "sync" then
      ns.Comm:Broadcast(ns.Comm:Build("MQ", 0), 2)
      ns.Print("Market: asked the gang for their prices – they arrive over the next few minutes.")
    else
      ns.Print("Market: " .. ns.Market:StatusText() .. ". /chill market sync asks the gang again, /chill market who shows who can share.")
    end
  elseif cmd == "kveld" or cmd == "summary" then
    ns:Fire("SHOW_SUMMARY", ns.Tracker:SessionSummary(), false)
  elseif cmd == "fiende" or cmd == "enemy" then
    ns.TagTarget(rest)
  elseif cmd == "legg" then
    ns.Data:AddManual((rest or ""):gsub("^til%s+", ""))
  elseif cmd == "add" then
    ns.Data:AddManual(rest)
  elseif cmd == "kanal" or cmd == "channel" then
    local old = ns.Comm:ChannelName()
    ns.Comm:LeaveChannel(old)
    C_Timer.After(1, function() ns.Comm:JoinChannel() end)
    C_Timer.After(4, function() ns.Print("Channel: " .. ns.Comm:ChannelStatusText()) end)
  elseif cmd == "hendelser" or cmd == "feed" or cmd == "events" then
    ns.EventWindow:Toggle()
  elseif cmd == "lås" or cmd == "las" or cmd == "lock" then
    ns.db.settings.locked = not ns.db.settings.locked
    ns:Fire("LOCK_CHANGED", ns.db.settings.locked)
    ns.Print(ns.db.settings.locked and "Positions are locked." or "Positions are unlocked – drag what you want to move.")
  elseif cmd == "klar" or cmd == "ready" then
    ns.Extras:StartReadyCheck()
  elseif cmd == "notat" or cmd == "note" then
    local L = ns.Tracker:UpdateLive()
    if L.mapID and L.x then ns.Extras:AddNote(L.mapID, L.x, L.y, "text", rest, 3)
    else ns.Print("Couldn't find your position here.") end
  elseif cmd == "cunt" or cmd == "cunts" then
    ns.Cunts:Slash(rest)
  elseif cmd == "edit" or cmd == "move" then
    ns.UI.EditMode()
  elseif cmd == "qol" then
    ns.QoL:Slash(rest)
  elseif cmd == "kills" then
    ns.Kills:Report()
  elseif cmd == "layer" or cmd == "hop" or cmd == "lag" then
    ns.LayerHop:Slash(rest)
  elseif cmd == "emotes" or cmd == "emotar" then
    local E = ns.Emotes
    if E:Available() then
      ns.Print("Emotes: " .. E:Count() .. " from Twitch Emotes v2. Example: Kappa " .. (E:Icon("Kappa", 18) or "(not found)"))
    else
      ns.Print("Emotes: Twitch Emotes v2 not found (or not loaded yet). Install it to see emotes in Chillan?.")
    end
  elseif cmd == "admin" then
    ns.Ideas:ClaimAdmin()
  elseif cmd == "ideas" or cmd == "ideer" then
    ns.Window:Create()
    ns.Window.frame:Show()
    ns.Window:Select("more")
    ns.Window:Select("ideas")
  elseif cmd == "oppsett" or cmd == "settings" then
    ns.Window:Toggle("settings")
  elseif cmd == "deathtest" or cmd == "dodstest" then
    if rest == "off" then ns.db.deathTest = false ns.Print("Death test off.")
    else ns.db.deathTest = true ns.Deaths:ShowTest() end
  elseif cmd == "minibar" then
    ns.db.settings.minibar = not ns.db.settings.minibar
    ns:Fire("MINIBAR")
  elseif cmd == "reset" then
    ns.db.settings.window = nil
    ns.db.settings.minibarPos = nil
    ReloadUI()
  elseif cmd == "perf" then
    -- (1.4.55) how much memory Chillan uses next to your other addons
    local upd = UpdateAddOnMemoryUsage or (C_AddOns and C_AddOns.UpdateAddOnMemoryUsage)
    local get = GetAddOnMemoryUsage or (C_AddOns and C_AddOns.GetAddOnMemoryUsage)
    local num = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
    local info = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
    if not (upd and get and num and info) then ns.Print("The game doesn't report addon memory here.") return end
    pcall(upd)
    local list, total = {}, 0
    for i = 1, num() do
      local name = info(i)
      local ok, kb = pcall(get, i)
      if ok and type(kb) == "number" and not ns.isSecret(kb) and kb > 0 then
        list[#list + 1] = { name = name, kb = kb }
        total = total + kb
      end
    end
    table.sort(list, function(a, b) return a.kb > b.kb end)
    local function mb(kb) return string.format("%.1f MB", kb / 1024) end
    local mine
    for i, a in ipairs(list) do if a.name == ADDON then mine = i end end
    ns.Print("Addon memory, " .. #list .. " addons, " .. mb(total) .. " in all:")
    for i = 1, math.min(6, #list) do
      local a = list[i]
      print(string.format("  %d. %s  %s", i, a.name == ADDON and ns.Colorize(a.name, ns.C.green) or a.name, mb(a.kb)))
    end
    if mine and mine > 6 then print(string.format("  %d. %s  %s", mine, ns.Colorize(ADDON, ns.C.green), mb(list[mine].kb))) end
  elseif cmd == "price" or cmd == "pris" then
    -- (1.4.59) an item's price graph: /chill price arcane crystal (or shift-click the item in)
    local id = ns.MarketWin and ns.MarketWin.ResolveItem(rest)
    if id then ns.MarketWin:ShowPrice(id)
    else ns.Print("Price: type an item's name or shift-click it, e.g. /chill price arcane crystal") end
  elseif cmd == "bgdebug" then
    if ns.BGObj then ns.BGObj.Debug() end
  elseif cmd == "debug" then
    ns.debug = not ns.debug
    ns.Print("Debug " .. (ns.debug and "on" or "off"))
    ns.Comm:RefreshChannelId()
    print("  Gang:", ns.db.code or "none", " channel:", ns.Comm:ChannelName() or "-")
    print("  Channel status:", ns.Comm:ChannelStatusText())
    print("  Version:", ns.VERSION, " queue:", ns.Comm:QueueSize(), " me:", ns.Comm:MyFull(), " pid:", ns.pid)
    print("  Code ID:", ns.codeHash or "-", "(must be the same for everyone in the gang)")
    local st = ns.Comm.stats
    print("  Messages received:", st.recv, "(channel " .. st.recvChan .. ", whisper " .. (st.recvWhisper - (st.recvBN or 0)) .. ", battle.net " .. (st.recvBN or 0) .. ")",
      " sent:", st.sent, " failed:", st.failed, st.lastErr and ("(last error: " .. st.lastErr .. ")") or "")
    if st.otherCode > 0 then
      ns.Print("|cffF2777AGot " .. st.otherCode .. " messages from a DIFFERENT gang code|r (e.g. " .. tostring(st.otherCodeFrom) .. "). Check that the code is exactly the same – O and 0 are not the same.")
    end
    local trial = (IsTrialAccount and IsTrialAccount()) or (IsVeteranTrialAccount and IsVeteranTrialAccount())
    if trial then
      ns.Print("|cffF2777AThis is a trial account.|r WoW doesn't let trial accounts send addon messages or use chat channels, so Chillan? can't connect.")
    end
    if st.recv == 0 and st.sent > 0 then
      print("  No messages received yet. Ask someone in the gang to type /chill add " .. (ns.Comm:MyFull() or "<your name>"))
    end
    local n = 0
    for char, r in pairs(ns.db.roster) do
      if r.heard and ns.Now() - r.heard < 300 then
        n = n + 1
        local forced = r.forceWhisper and (ns.Now() - r.forceWhisper) < 120
        local who = char
        if r.bn and r.pid then
          local p = ns.db.people[r.pid]
          who = "Battle.net: " .. ((p and (ns:PersonAlias(p) or ns:PersonName(p))) or char)
        end
        local via = r.bn and "battle.net" or ((r.chan and (ns.Now() - r.chan < 150)) and "channel" or "whisper")
        print("   ", who, via, ns.Ago(r.heard), forced and "(doesn't hear us on the channel – sending directly)" or "")
      end
    end
    print("  Heard from in the last 5 min:", n)
  else
    help()
  end
end

SLASH_CHILLANGANG1 = "/cg"
SlashCmdList.CHILLANGANG = function(msg)
  if msg and msg ~= "" then ns.Data:SendChat(msg) else ns.Window:Toggle("chat") end
end

-- Knappen i addon-skuffen ved minikartet
function Chillan_OnAddonCompartmentClick(_, button)
  if button == "RightButton" then ns.Window:Toggle("chat") else ns.Window:Toggle() end
end
function Chillan_OnAddonCompartmentEnter(_, frame)
  GameTooltip:SetOwner(frame or UIParent, "ANCHOR_LEFT")
  GameTooltip:AddLine("Chillan?", 1, 1, 1)
  local n = ns.Window.OnlineCount and ns.Window:OnlineCount() or 0
  GameTooltip:AddLine(n .. " friends online", 0.6, 0.63, 0.66)
  GameTooltip:AddLine("Click: open · Right-click: chat", 0.52, 0.55, 0.57)
  GameTooltip:Show()
end
function Chillan_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end
