-- Chillan? – fanen "Innstillinger": utseende, vinduer, varsler og moduler
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("settings", "Oppsett", "Gear", function(tab)
  local S = function() return ns.db.settings end
  local checks = {}

  local function section(parent, anchor, title, gap)
    local h = UI.Text(parent, 14, "semi", C.text)
    if anchor then h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or 18)) else h:SetPoint("TOPLEFT") end
    h:SetText(title)
    return h
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

  local left = CreateFrame("Frame", nil, tab)
  left:SetPoint("TOPLEFT", 18, -16)
  left:SetPoint("BOTTOMLEFT", 18, 14)
  left:SetWidth(330)
  local right = CreateFrame("Frame", nil, tab)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 24, 0)
  right:SetPoint("BOTTOMRIGHT", -16, 14)

  -------------------------------------------------------------------------
  -- Utseende: aksentfarge
  -------------------------------------------------------------------------
  local ah = section(left, nil, "Utseende")
  local al = UI.Text(left, 11, nil, C.dim)
  al:SetPoint("TOPLEFT", ah, "BOTTOMLEFT", 0, -6)
  al:SetText("Aksentfarge – knapper, faner og markeringer")
  local swatches = {}
  local reloadBtn
  local function refreshSwatches()
    for _, sw in ipairs(swatches) do
      local on = (S().accent or "grey") == sw.key
      sw.ring:SetShown(on)
    end
    reloadBtn:SetShown((S().accent or "grey") ~= (tab.appliedAccent or "grey"))
  end
  for i, a in ipairs(ns.ACCENTS) do
    local sw = CreateFrame("Button", nil, left)
    sw:SetSize(26, 26)
    sw:SetPoint("TOPLEFT", al, "BOTTOMLEFT", (i - 1) * 32, -8)
    sw.key = a.key
    sw.ring = sw:CreateTexture(nil, "BACKGROUND")
    sw.ring:SetTexture(ns.TEX .. "Circle")
    sw.ring:SetPoint("CENTER")
    sw.ring:SetSize(26, 26)
    sw.ring:SetVertexColor(hex(C.text))
    sw.dot = sw:CreateTexture(nil, "ARTWORK")
    sw.dot:SetTexture(ns.TEX .. "Circle")
    sw.dot:SetPoint("CENTER")
    sw.dot:SetSize(20, 20)
    sw.dot:SetVertexColor(hex(ns.AccentHex(a.key)))
    sw:SetScript("OnClick", function() S().accent = a.key refreshSwatches() end)
    sw:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(a.name, 1, 1, 1)
      GameTooltip:Show()
    end)
    sw:SetScript("OnLeave", function() GameTooltip:Hide() end)
    swatches[#swatches + 1] = sw
  end
  reloadBtn = UI.Button(left, 200, 28, "Bruk fargen (laster UI på nytt)", "primary", function() ReloadUI() end)
  reloadBtn:SetPoint("TOPLEFT", al, "BOTTOMLEFT", 0, -42)
  tab.appliedAccent = S().accent or "grey"

  -------------------------------------------------------------------------
  -- Vinduer og plassering
  -------------------------------------------------------------------------
  local wh = section(left, reloadBtn, "Vinduer og plassering", 14)
  local lastW = checkList(left, wh, {
    { "Minibar på skjermen", "minibar", function() ns:Fire("MINIBAR") end },
    { "Knapp ved minikartet", "minimapButton", function() ns:Fire("MINIBAR") end },
    { "Hendelsesvindu", "eventFeed", function() ns.EventWindow:Apply() end },
    { "Gjengchat i hendelsesvinduet", "feedChat", function() ns.EventWindow:Redraw() end },
    { "Ton ned hendelsesvinduet når det er stille", "evFade" },
    { "Lås posisjoner", "locked", function(v) ns:Fire("LOCK_CHANGED", v) end,
      "Når låst kan ikke minibar, hendelsesvindu og varsler dras ved et uhell. Også /chill lås." },
  })
  local resetPos = UI.Button(left, 170, 26, "Tilbakestill posisjoner", "ghost", function()
    UI.ResetPositions()
    if ns.Overlays.placeMinimap then ns.Overlays.placeMinimap() end
    ns.Print("Alt er flyttet tilbake til standardplassen.")
  end)
  resetPos:SetPoint("TOPLEFT", lastW, "BOTTOMLEFT", 0, -8)

  -------------------------------------------------------------------------
  -- Varsler
  -------------------------------------------------------------------------
  local nh = section(right, nil, "Varsler")
  local lastN = checkList(right, nh, {
    { "Lyder", "sounds" },
    { "Varsel når utstyret er slitt (30 % og 10 %)", "duraWarn" },
    { "Popup-varsler", "toasts" },
    { "Varsel når venner logger på", "onlineToasts" },
    { "Vent med popups til etter kamp", "combatQueue", nil,
      "Ding, dødsfall, achievements og varsler vises når du er ute av kamp. SOS vises alltid med en gang." },
    { "Lyd og varsel når noen skriver @navnet ditt", "mentionSound", nil,
      "Treffer IRL-navnet ditt, karakternavnet ditt og @alle." },
    { "Også i vanlig WoW-chat", "chatMirror", function(v) S().activityMirror = v end,
      "Gjengchat og hendelser skrives også i standard chatvindu." },
  })

  local mh = section(right, lastN, "Moduler")
  checkList(right, mh, {
    { "Quest-kompis", "questBuddy", nil, "Varsel når du plukker opp en quest en kompis også har (ikke når dere er i gruppe)." },
    { "Gruppe-radar", "radar", nil, "Varsel når en kompis innen ±3 level er i samme sone og dere ikke er i gruppe (maks én gang per halvtime)." },
    { "Ukentlige titler", "titles", function() ns:MarkDirty() end, "Varsel når en tittel som «Gulvinspektør» bytter eier." },
    { "Gjeng-notater på kartet", "mapNotes", function() ns:Fire("MAP_PINS") end, "Alt + høyreklikk på verdenskartet for å legge til. Høyreklikk ditt eget notat for å fjerne det." },
    { "Del blå drops i feeden (ikke bare episke)", "blueLoot", function(v) S().lootMinQuality = v and 3 or 4 end },
  })

  function tab:Refresh()
    S().blueLoot = (S().lootMinQuality or 4) <= 3
    for _, cb in ipairs(checks) do cb:Refresh() end
    refreshSwatches()
  end
end)
