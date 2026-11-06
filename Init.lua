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
      ns.Print("|cffF2777APrøvekonto oppdaget:|r WoW lar ikke prøvekontoer sende addon-meldinger, så gjengen kan ikke se deg før kontoen er oppgradert.")
    elseif st.recv == 0 and st.otherCode > 0 then
      ns.Print("|cffF2777AVi hører Chillan? fra en annen gjengkode, men ingen fra din.|r Sjekk at koden (" .. ns.db.code .. ") er helt lik den de andre har.")
    elseif st.recv == 0 then
      ns.Print("Vi har ikke hørt fra noen i gjengen ennå. Skriv /chill debug og send skjermbilde til gjengen, eller be en kompis skrive /chill legg til " .. (ns.Comm:MyFull() or "navnet ditt") .. ".")
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
        ns.UI.Prompt("Hva heter du?", {
          { label = "Navnet ditt – vises ved alle karakterene dine", placeholder = "f.eks. Henrik" },
        }, function(v) if not ns.SetAlias(v) then return true end end)
      end
    end)
    if not ns.db.code then
      C_Timer.After(10, function()
        ns.Print("Velkommen! Skriv |cff" .. ns.C.accent .. "/chill|r for å lage eller bli med i en gjeng.")
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
  print("  /chill hendelser – vis/skjul hendelsesvinduet")
  print("  /chill lås – lås/lås opp posisjonene på skjermen")
  print("  /chill klar – klar-sjekk før dungeon")
  print("  /chill notat tekst – gjengnotat på kartet der du står (eller Alt+høyreklikk på kartet)")
  print("  /chill oppsett – åpne innstillingene")
  print("  /chill minibar – vis/skjul minibaren")
  print("  /chill debug – vis teknisk status")
  print("  /chill kanal – koble til gjengkanalen på nytt")
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
  elseif cmd == "kanal" then
    local old = ns.Comm:ChannelName()
    ns.Comm:LeaveChannel(old)
    C_Timer.After(1, function() ns.Comm:JoinChannel() end)
    C_Timer.After(4, function() ns.Print("Kanal: " .. ns.Comm:ChannelStatusText()) end)
  elseif cmd == "hendelser" or cmd == "feed" or cmd == "events" then
    ns.EventWindow:Toggle()
  elseif cmd == "lås" or cmd == "las" or cmd == "lock" then
    ns.db.settings.locked = not ns.db.settings.locked
    ns:Fire("LOCK_CHANGED", ns.db.settings.locked)
    ns.Print(ns.db.settings.locked and "Posisjonene er låst." or "Posisjonene er låst opp – dra det du vil flytte.")
  elseif cmd == "klar" or cmd == "ready" then
    ns.Extras:StartReadyCheck()
  elseif cmd == "notat" or cmd == "note" then
    local L = ns.Tracker:UpdateLive()
    if L.mapID and L.x then ns.Extras:AddNote(L.mapID, L.x, L.y, "text", rest, 3)
    else ns.Print("Fant ikke posisjonen din her.") end
  elseif cmd == "oppsett" or cmd == "settings" then
    ns.Window:Toggle("settings")
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
    print("  Gjeng:", ns.db.code or "ingen", " kanal:", ns.Comm:ChannelName() or "-")
    print("  Kanalstatus:", ns.Comm:ChannelStatusText())
    print("  Versjon:", ns.VERSION, " kø:", ns.Comm:QueueSize(), " meg:", ns.Comm:MyFull(), " pid:", ns.pid)
    print("  Kode-ID:", ns.codeHash or "-", "(skal være lik hos alle i gjengen)")
    local st = ns.Comm.stats
    print("  Meldinger mottatt:", st.recv, "(kanal " .. st.recvChan .. ", whisper " .. (st.recvWhisper - (st.recvBN or 0)) .. ", battle.net " .. (st.recvBN or 0) .. ")",
      " sendt:", st.sent, " feilet:", st.failed, st.lastErr and ("(siste feil: " .. st.lastErr .. ")") or "")
    if st.otherCode > 0 then
      ns.Print("|cffF2777AFikk " .. st.otherCode .. " meldinger fra en ANNEN gjengkode|r (bl.a. " .. tostring(st.otherCodeFrom) .. "). Sjekk at koden er helt lik – O og 0 er ikke det samme.")
    end
    local trial = (IsTrialAccount and IsTrialAccount()) or (IsVeteranTrialAccount and IsVeteranTrialAccount())
    if trial then
      ns.Print("|cffF2777ADette er en prøvekonto.|r WoW lar ikke prøvekontoer sende addon-meldinger eller bruke chatkanaler, så Chillan? kan ikke koble til.")
    end
    if st.recv == 0 and st.sent > 0 then
      print("  Ingen meldinger mottatt ennå. Be en i gjengen skrive /chill legg til " .. (ns.Comm:MyFull() or "<ditt navn>"))
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
        local via = r.bn and "battle.net" or ((r.chan and (ns.Now() - r.chan < 150)) and "kanal" or "whisper")
        print("   ", who, via, ns.Ago(r.heard), forced and "(hører ikke oss på kanalen - sender direkte)" or "")
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
