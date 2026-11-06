-- Chillan? – fanen "Mer": gjeng, innstillinger, fiendelogg og hvem som kan lage hva
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

function ns.ChangeCode(code)
  if ns.Clean(code or "", 24) == "" then return false end
  ns.Comm:LeaveChannel(ns.Comm:ChannelName())
  return ns:SetCode(code) -- CODE_CHANGED kobler til ny kanal og sier hei
end

function ns.TagTarget(note)
  local name = ns.S(UnitName, "target")
  if not name then ns.Print("Velg en fiendtlig spiller som mål først.") return end
  if not (ns.S(UnitIsPlayer, "target") and ns.S(UnitIsEnemy, "player", "target")) then
    ns.Print("Målet ditt er ikke en fiendtlig spiller.")
    return
  end
  if ns.Data:AddEnemy(name, note) then ns.Print(name .. " er lagt i fiendeloggen.") end
end

ns:RegisterTab("more", "Mer", "More", function(tab)
  local LEFT_W = 300

  local left = CreateFrame("Frame", nil, tab)
  left:SetPoint("TOPLEFT", 16, -14)
  left:SetPoint("BOTTOMLEFT", 16, 14)
  left:SetWidth(LEFT_W)

  local h = UI.Text(left, 15, "semi", C.text)
  h:SetPoint("TOPLEFT")
  h:SetText("Gjengen")

  local cl = UI.Text(left, 12, nil, C.dim)
  cl:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -12)
  cl:SetText("Gjengkode – del med vennene dine (merk og Ctrl+C)")
  local code = UI.EditBox(left, LEFT_W - 96, 34, "Ingen kode")
  code:SetPoint("TOPLEFT", cl, "BOTTOMLEFT", 0, -6)
  code.edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  code.edit:SetScript("OnTextChanged", function(self, user)
    if user then self:SetText(ns.db.code or "") self:HighlightText() end
  end)
  local change = UI.Button(left, 88, 34, "Bytt", "ghost", function()
    UI.Prompt("Bytt gjeng", { { label = "Ny gjengkode", placeholder = "CHILL-XXXX" } }, function(v)
      if ns.ChangeCode(v) then ns.Print("Byttet til gjengen " .. ns.db.code .. ".") else return true end
    end)
  end)
  change:SetPoint("LEFT", code, "RIGHT", 8, 0)

  local nl = UI.Text(left, 12, nil, C.dim)
  nl:SetPoint("TOPLEFT", code, "BOTTOMLEFT", 0, -12)
  nl:SetText("Dukker ikke en venn opp?")
  local addFriend = UI.Button(left, LEFT_W, 34, "Legg til venn manuelt", "ghost", function()
    UI.Prompt("Legg til venn manuelt", {
      { label = "Karakternavn (bruk dette hvis en venn ikke dukker opp)", placeholder = "Navn eller Navn-Realm" },
    }, function(v) ns.Data:AddManual(v) end)
  end)
  addFriend.tooltip = "Send hei direkte til en karakter som ikke dukker opp automatisk"
  addFriend:SetPoint("TOPLEFT", nl, "BOTTOMLEFT", 0, -6)

  local sh = UI.Text(left, 15, "semi", C.text)
  sh:SetPoint("TOPLEFT", addFriend, "BOTTOMLEFT", 0, -22)
  sh:SetText("Innstillinger")
  local S = ns.db.settings
  local checks = {
    { "Vis minibar på skjermen", "minibar", function() ns:Fire("MINIBAR") end },
    { "Vis knapp ved minikartet", "minimapButton", function() ns:Fire("MINIBAR") end },
    { "Lyder", "sounds" },
    { "Popup-varsler", "toasts" },
    { "Varsel når venner logger på", "onlineToasts" },
    { "Venner på verdenskartet", "mapPins", function() ns:Fire("MAP_PINS") end },
  }
  local y = -10
  local checkFrames = {}
  for _, def in ipairs(checks) do
    local cb = UI.Check(left, def[1], function() return ns.db.settings[def[2]] end, function(v)
      ns.db.settings[def[2]] = v
      if def[3] then def[3]() end
    end)
    cb:SetPoint("TOPLEFT", sh, "BOTTOMLEFT", 0, y)
    y = y - 28
    checkFrames[#checkFrames + 1] = cb
  end
  local blue = UI.Check(left, "Del blå drops i feeden (ikke bare episke)",
    function() return (S.lootMinQuality or 4) <= 3 end,
    function(v) ns.db.settings.lootMinQuality = v and 3 or 4 end)
  blue:SetPoint("TOPLEFT", sh, "BOTTOMLEFT", 0, y)
  checkFrames[#checkFrames + 1] = blue

  local ver = UI.Text(left, 11, nil, C.dim)
  ver:SetPoint("BOTTOMLEFT", 0, 0)
  ver:SetText("Chillan? " .. ns.VERSION .. " · hurtigtast kan settes under Taster → AddOns")

  -- Høyre: fiendelogg og "kan lage"
  local right = CreateFrame("Frame", nil, tab)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 20, 0)
  right:SetPoint("BOTTOMRIGHT", -16, 14)

  local eh = UI.Text(right, 15, "semi", C.text)
  eh:SetPoint("TOPLEFT")
  eh:SetText("Fiendelogg")
  local tag = UI.Button(right, 130, 28, "Tagg målet ditt", "secondary", function()
    if not ns.S(UnitExists, "target") then ns.Print("Velg en fiendtlig spiller som mål først.") return end
    UI.Prompt("Legg i fiendeloggen", { { label = "Notat (valgfritt)", placeholder = "f.eks. ganker lowbies i STV" } },
      function(note) ns.TagTarget(note) end)
  end)
  tag:SetIcon("Target", 13)
  tag:SetPoint("TOPRIGHT", 0, 4)

  local function createEnemy(list)
    local row = CreateFrame("Frame", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.name = UI.Text(row, 13, "semi", C.red)
    row.name:SetPoint("TOPLEFT", 12, -8)
    row.name:SetPoint("RIGHT", -44, 0)
    row.note = UI.Text(row, 11, nil, C.dim)
    row.note:SetPoint("BOTTOMLEFT", 12, 8)
    row.note:SetPoint("RIGHT", -44, 0)
    row.del = UI.IconButton(row, 26, "Close", "Fjern fra loggen")
    row.del:SetPoint("RIGHT", -8, 0)
    return row
  end
  local function updateEnemy(row, e)
    row.name:SetText(e.name)
    local by = e.byChar and ns.ShortName(e.byChar) or "?"
    row.note:SetText((e.note ~= "" and (e.note .. " · ") or "") .. "tagget av " .. by .. " · " .. ns.Ago(e.t))
    row.del:SetScript("OnClick", function() ns.Data:RemoveEnemy(e.key) end)
  end
  local enemies = UI.List(right, 44, 6, createEnemy, updateEnemy)
  enemies:SetPoint("TOPLEFT", eh, "BOTTOMLEFT", 0, -10)
  enemies:SetPoint("RIGHT", right, "RIGHT", 6, 0)
  enemies:SetHeight(150)
  enemies.emptyText = "Ingen fiender ennå. Ta mål på en Alliance-spiller og trykk «Tagg målet ditt»."

  local kh = UI.Text(right, 15, "semi", C.text)
  kh:SetPoint("TOPLEFT", enemies, "BOTTOMLEFT", 0, -14)
  kh:SetText("Hvem kan lage hva?")
  local search
  search = UI.EditBox(right, 100, 32, "Søk etter oppskrift eller profesjon …", function(self) self:ClearFocus() end)
  search:SetPoint("TOPLEFT", kh, "BOTTOMLEFT", 0, -8)
  search:SetPoint("RIGHT", right, "RIGHT", 0, 0)
  search.edit:HookScript("OnTextChanged", function() tab:Refresh() end)

  local function createCraft(list)
    local row = CreateFrame("Frame", nil, list)
    row.panel = UI.Panel(row, C.card, C.line, false)
    row.panel:SetAllPoints()
    row.panel:SetFrameLevel(row:GetFrameLevel())
    row.what = UI.Text(row, 12, "semi", C.text)
    row.what:SetPoint("TOPLEFT", 12, -7)
    row.what:SetPoint("RIGHT", -90, 0)
    row.who = UI.Text(row, 11, nil, C.dim)
    row.who:SetPoint("BOTTOMLEFT", 12, 7)
    row.who:SetPoint("RIGHT", -90, 0)
    row.ask = UI.Button(row, 74, 26, "Be om", "secondary")
    row.ask:SetPoint("RIGHT", -8, 0)
    return row
  end
  local function updateCraft(row, it)
    row.what:SetText(it.what)
    local p = ns:GetPerson(it.pid) or {}
    local c = ns:PersonChar(p) or {}
    row.who:SetText(ns.Colorize(ns:PersonFirst(p), ns.ClassHex(c.class)) .. " · " .. it.detail)
    if it.pid == ns.pid then row.ask:Hide() else
      row.ask:Show()
      row.ask:SetScript("OnClick", function() ns.Data:RequestCraft(it.pid, it.what) end)
    end
  end
  local crafts = UI.List(right, 40, 6, createCraft, updateCraft)
  crafts:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -8)
  crafts:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 6, 0)
  crafts.emptyText = "Profesjoner deles automatisk. Åpne profesjonsvinduet ditt én gang, så deles oppskriftene også."

  local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
  end

  function tab:Refresh()
    code:SetText(ns.db.code or "")
    for _, cb in ipairs(checkFrames) do cb:Refresh() end

    local es = {}
    for key, e in pairs(ns.db.enemies) do e.key = key es[#es + 1] = e end
    table.sort(es, function(a, b) return (a.t or 0) > (b.t or 0) end)
    enemies:SetData(es)

    local q = (search:GetText() or ""):lower()
    local out = {}
    for pid, p in pairs(ns.db.people) do
      if p.main then
        for _, prof in ipairs(p.profs or {}) do
          if q == "" or prof.name:lower():find(q, 1, true) then
            out[#out + 1] = { pid = pid, what = prof.name, detail = prof.skill .. " / " .. prof.max, sort = 0 }
          end
        end
        if q ~= "" and #q >= 3 then
          for profName, ids in pairs(p.recipes or {}) do
            for _, id in ipairs(ids) do
              local name = spellName(id)
              if name and name:lower():find(q, 1, true) then
                out[#out + 1] = { pid = pid, what = name, detail = profName, sort = 1 }
              end
              if #out > 60 then break end
            end
          end
        end
      end
    end
    table.sort(out, function(a, b) if a.sort ~= b.sort then return a.sort < b.sort end return a.what < b.what end)
    crafts:SetData(out)
  end
end)
