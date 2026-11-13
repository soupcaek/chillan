-- Chillan? – oppstart og kommandoer
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
  C_Timer.After(20, function() ns.Tracker:CountMounts() end)
  ns.Overlays:Init()
  ns.PersonCard:Init()
  ns.EventWindow:Init()
  ns.Tiles:Init()
  ns.Overlays:UpdateMinibar()
  ns.MapPins:Init()
  ns:Listen("CODE_CHANGED", function() ns.Overlays:UpdateMinibar() end)
  -- Automatisk feilsøk etter et par minutter hvis vi ikke hører noen
  C_Timer.After(90, function()
    if not ns.db.code then return end
    local st = ns.Comm.stats
    local trial = (IsTrialAccount and IsTrialAccount()) or (IsVeteranTrialAccount and IsVeteranTrialAccount())
    if trial then
      ns.Print("|cffF2777ATrial account detected:|r WoW doesn't let trial accounts send addon messages, so the gang can't see you until the account is upgraded.")
    elseif st.recv == 0 and st.otherCode > 0 then
      ns.Print("|cffF2777AWe hear Chillan? from a different gang code, but nobody from yours.|r Check that the code (" .. ns.db.code .. ") is exactly the same as the others have.")
    elseif st.recv == 0 then
      ns.Print("We haven't heard from anyone in the gang yet. Type /chill debug and send a screenshot to the gang, or ask a friend to type /chill add " .. (ns.Comm:MyFull() or "your name") .. ".")
    end
  end)
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
        ns:Fire("SHOW_SUMMARY", last, true)
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
  print("  /chill sos – send an SOS to the gang")
  print("  /chill summary – show your session summary")
  print("  /chill enemy [note] – add your target to the enemy log")
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
BINDING_NAME_CHILLAN_SOS = "Send SOS"
function Chillan_ToggleBinding(key)
  if key == "chat" then ns.Window:Toggle("chat")
  elseif key == "sos" then ns.Data:SOS()
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
  elseif cmd == "sos" then
    ns.Data:SOS()
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
  elseif cmd == "discord" then
    ns.Discord:Slash(rest)
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
