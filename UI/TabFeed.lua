-- Chillan? – fanen "Feed": alt som har skjedd i gjengen
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("feed", "Feed", "Feed", function(tab)
  local filter = "ALL"
  local FILTERS = {
    { "ALL", "Alt" }, { "DING", "Level" }, { "LOOT", "Loot" }, { "DEAD", "Dødsfall" }, { "SOS", "SOS og fiender" },
  }

  local h = UI.Text(tab, 15, "semi", C.text)
  h:SetPoint("TOPLEFT", 16, -16)
  h:SetText("Gjengfeed")

  local buttons = {}
  local function paint()
    for k, b in pairs(buttons) do
      local on = k == filter
      b.panel:SetColors(on and C.active or nil, on and C.activeLine or C.inputLine)
      b.label:SetTextColor(hex(on and C.text or C.muted))
      b.style = { fill = on and C.active or nil, line = on and C.activeLine or C.inputLine, text = on and C.text or C.muted, hover = on and "33383E" or C.card }
    end
  end
  local prev
  for i = #FILTERS, 1, -1 do
    local def = FILTERS[i]
    local b = UI.Button(tab, 10, 28, def[2], "ghost", function() filter = def[1] paint() tab:Refresh() end)
    b:SetWidth(b.label:GetStringWidth() + 22)
    if prev then b:SetPoint("RIGHT", prev, "LEFT", -6, 0) else b:SetPoint("TOPRIGHT", -16, -12) end
    prev = b
    buttons[def[1]] = b
  end
  paint()

  local box = UI.Panel(tab, C.card, C.line, false)
  box:SetPoint("TOPLEFT", 12, -50)
  box:SetPoint("BOTTOMRIGHT", -12, 12)
  local feed = UI.MessageFrame(box, 13)
  feed:SetPoint("TOPLEFT", 14, -12)
  feed:SetPoint("BOTTOMRIGHT", -14, 12)
  feed:SetSpacing(9)

  local function match(it)
    if filter == "ALL" then return true end
    if filter == "SOS" then return it.kind == "SOS" or it.kind == "ENSEEN" end
    if filter == "LOOT" then return it.kind == "LOOT" or it.kind == "MOUNT" end
    return it.kind == filter
  end

  function tab:Refresh()
    feed:Clear()
    local n = 0
    for _, it in ipairs(ns.db.feed) do
      if match(it) then
        feed:AddMessage(ns.Colorize(date("%d.%m %H:%M", it.t), C.dim) .. "   " .. ns.FeedLine(it, false))
        n = n + 1
      end
    end
    if n == 0 then feed:AddMessage(ns.Colorize("Ingenting her ennå.", C.dim)) end
    feed:ScrollToBottom()
  end
end)
