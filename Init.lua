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
  ns.Overlays:Init()
  ns.MapPins:Init()
  ns:Listen("CODE_CHANGED", function() ns.Overlays:UpdateMinibar() end)
end)

local started = false
ns:On("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
  if started then
    ns.Tracker:SendStatusSoon()
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
    if not ns.db.code then
      C_Timer.After(10, function()
        ns.Print("Velkommen! Skriv |cffc8d1dc/chill|r for å lage eller bli med i en gjeng.")
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
  ns.Print("Kommandoer:")
  print("  /chill – åpne/lukk vinduet")
  print("  /chill sos – send SOS til gjengen")
  print("  /chill kveld – vis oppsummering av økten")
  print("  /chill fiende [notat] – legg målet ditt i fiendeloggen")
  print("  /chill legg til Navn – send hei til en venn som ikke dukker opp")
  print("  /chill minibar – vis/skjul minibaren")
  print("  /chill debug – vis teknisk status")
  print("  /cg tekst – skriv i gjengchatten")
end

-- Hurtigtast (Taster → AddOns)
BINDING_HEADER_CHILLAN = "Chillan?"
BINDING_NAME_CHILLAN_TOGGLE = "Åpne/lukk Chillan?"
BINDING_NAME_CHILLAN_CHAT = "Åpne gjengchatten"
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
  elseif cmd == "minibar" then
    ns.db.settings.minibar = not ns.db.settings.minibar
    ns:Fire("MINIBAR")
  elseif cmd == "reset" then
    ns.db.settings.window = nil
    ns.db.settings.minibarPos = nil
    ReloadUI()
  elseif cmd == "debug" then
    ns.debug = not ns.debug
    ns.Print("Debug " .. (ns.debug and "på" or "av"))
    ns.Comm:RefreshChannelId()
    print("  Gjeng:", ns.db.code or "ingen", " kanal:", ns.Comm:ChannelName() or "-", " id:", ns.Comm.chanId or "ikke koblet")
    print("  Versjon:", ns.VERSION, " kø:", ns.Comm:QueueSize(), " meg:", ns.Comm:MyFull(), " pid:", ns.pid)
    local n = 0
    for char, r in pairs(ns.db.roster) do
      if r.heard and ns.Now() - r.heard < 300 then
        n = n + 1
        print("   ", char, r.chan and (ns.Now() - r.chan < 150) and "kanal" or "whisper", ns.Ago(r.heard))
      end
    end
    print("  Hørt fra siste 5 min:", n)
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
  GameTooltip:AddLine(n .. " venner online", 0.6, 0.63, 0.66)
  GameTooltip:AddLine("Klikk: åpne · Høyreklikk: chat", 0.52, 0.55, 0.57)
  GameTooltip:Show()
end
function Chillan_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end
