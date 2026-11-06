-- Chillan? – fanen "Chat": gjengchat og feed ved siden av
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

-- Tekst for en feed-hendelse (brukes også i Feed-fanen)
function ns.FeedLine(it, withTime)
  local p = ns:GetPerson(it.pid) or {}
  local c = (p.chars and p.chars[it.char]) or ns:PersonChar(p) or {}
  local who = ns:PersonLabel(p, it.char)
  local icon, color, text = "Star", C.purple, ""
  if it.kind == "DING" then
    icon, color = "Up", C.green
    text = "nådde level " .. tostring(it.a)
    local played = tonumber(it.b)
    if played then text = text .. " · /played " .. ns.Duration(played) end
    if it.first then text = text .. ns.Colorize(" · først i gjengen!", C.gold)
    elseif it.place and tonumber(it.a) and tonumber(it.a) % 10 == 0 then text = text .. " · nr. " .. it.place .. " i gjengen" end
    if it.reacts and #it.reacts > 0 then
      text = text .. ns.Colorize(" · " .. #it.reacts .. (#it.reacts == 1 and " gratulasjon" or " gratulasjoner"), C.purple)
    end
  elseif it.kind == "DEAD" then
    icon, color = "Skull", C.dim
    text = "døde i " .. tostring(it.a or "?")
    if it.reacts and #it.reacts > 0 then
      text = text .. ns.Colorize(" · " .. #it.reacts .. " ler", C.red)
    end
  elseif it.kind == "LOOT" then
    icon, color = "Star", C.purple
    local id = tonumber(it.a)
    local link = id and select(2, C_Item.GetItemInfo(id))
    if not link and id then
      if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
      link = "[item " .. id .. "]"
    end
    text = "fikk " .. (link or "noe fint")
  elseif it.kind == "MOUNT" then
    icon, color = "Star", C.amber
    text = it.first and ("fikk mount – " .. ns.Colorize("først i gjengen!", C.gold)) or "fikk mount"
  elseif it.kind == "SOS" then
    icon, color = "SOS", C.red
    text = "sendte SOS i " .. tostring(it.a or "?")
  elseif it.kind == "ENSEEN" then
    icon, color = "Target", C.red
    text = "så fienden " .. tostring(it.a) .. " i " .. tostring(it.b or "?")
  else
    text = tostring(it.kind)
  end
  local line = UI.InlineIcon(icon, color, 13) .. "  " .. who .. " " .. ns.Colorize(text, C.text2)
  if withTime then line = line .. ns.Colorize("  " .. ns.Ago(it.t), C.dim) end
  return line
end

function ns.ChatLine(it)
  local p = ns:GetPerson(it.pid) or {}
  local c = (p.chars and p.chars[it.char]) or ns:PersonChar(p) or {}
  return ns.Colorize(ns.Clock(it.t), C.dim) .. "  " .. ns:PersonLabel(p, it.char)
    .. "  " .. ns.Colorize(it.text, "D4D7DB")
end

ns:RegisterTab("chat", "Chat", "Chat", function(tab)
  local FEED_W = 236

  local h = UI.Text(tab, 15, "semi", C.text)
  h:SetPoint("TOPLEFT", 16, -16)
  h:SetText("Gjengchat")
  local hint = UI.Text(tab, 11, nil, C.dim)
  hint:SetPoint("LEFT", h, "RIGHT", 10, 0)
  hint:SetText("Tips: /cg tekst sender rett fra vanlig chat")

  local divider = UI.SolidLine(tab)
  divider:SetPoint("TOPRIGHT", -FEED_W, 0)
  divider:SetPoint("BOTTOMRIGHT", -FEED_W, 0)
  divider:SetWidth(1)

  local msgs = UI.MessageFrame(tab, 13)
  msgs:SetPoint("TOPLEFT", 16, -44)
  msgs:SetPoint("BOTTOMRIGHT", -FEED_W - 16, 60)

  local input
  local function send()
    ns.Data:SendChat(input:GetText())
    input:SetText("")
  end
  input = UI.EditBox(tab, 300, 36, "Skriv til gjengen …", send)
  input:SetPoint("BOTTOMLEFT", 16, 14)
  input:SetPoint("RIGHT", tab, "RIGHT", -FEED_W - 90, 0)
  input.edit:SetScript("OnEnterPressed", function(self) send() self:SetFocus() end)
  local sendBtn = UI.Button(tab, 64, 36, "Send", "primary", send)
  sendBtn:SetPoint("LEFT", input, "RIGHT", 8, 0)

  local fh = UI.Text(tab, 15, "semi", C.text)
  fh:SetPoint("TOPLEFT", tab, "TOPRIGHT", -FEED_W + 14, -16)
  fh:SetText("Gjengfeed")
  local feed = UI.MessageFrame(tab, 12)
  feed:SetPoint("TOPLEFT", tab, "TOPRIGHT", -FEED_W + 14, -44)
  feed:SetPoint("BOTTOMRIGHT", -12, 14)
  feed:SetSpacing(8)

  local lastChatKey
  function tab:Refresh()
    local last = ns.db.chat[#ns.db.chat]
    local key = #ns.db.chat .. (last and last.id or "")
    if key ~= lastChatKey then
      lastChatKey = key
      msgs:Clear()
      if #ns.db.chat == 0 then
        msgs:AddMessage(ns.Colorize("Ingen meldinger ennå. Si hei til gjengen!", C.dim))
      end
      for _, it in ipairs(ns.db.chat) do msgs:AddMessage(ns.ChatLine(it)) end
    end
    feed:Clear()
    local start = math.max(1, #ns.db.feed - 40)
    for i = start, #ns.db.feed do feed:AddMessage(ns.FeedLine(ns.db.feed[i], true)) end
    if #ns.db.feed == 0 then feed:AddMessage(ns.Colorize("Her dukker dings, drops, dødsfall og SOS opp.", C.dim)) end
  end
end)
