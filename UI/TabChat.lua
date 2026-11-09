-- Chillan? – fanen "Chat": gjengchat og feed ved siden av
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

-- Tekst for en feed-hendelse (brukes også i Feed-fanen)
function ns.FeedLine(it, withTime)
  local p = ns:GetPerson(it.pid) or {}
  local c = (p.chars and p.chars[it.char]) or ns:PersonChar(p) or {}
  local who = ns:PersonLinked(p, ns:PersonLabel(p, it.char))
  local icon, color, text = "Star", C.purple, ""
  if it.kind == "DING" then
    icon, color = "Up", C.green
    text = "reached level " .. tostring(it.a)
    local played = tonumber(it.b)
    if played then text = text .. " · /played " .. ns.Duration(played) end
    if it.first then text = text .. ns.Colorize(" · first in the gang!", C.gold)
    elseif it.place and tonumber(it.a) and tonumber(it.a) % 10 == 0 then text = text .. " · no. " .. it.place .. " in the gang" end
    if it.reacts and #it.reacts > 0 then
      text = text .. ns.Colorize(" · " .. #it.reacts .. (#it.reacts == 1 and " reaction" or " reactions"), C.purple)
    end
  elseif it.kind == "DEAD" then
    icon, color = "Skull", C.dim
    text = "died in " .. tostring(it.a or "?")
    if it.reacts and #it.reacts > 0 then
      text = text .. ns.Colorize(" · " .. #it.reacts .. (#it.reacts == 1 and " reaction" or " reactions"), C.red)
    end
  elseif it.kind == "LOOT" then
    icon, color = "Star", ns.QUALITY_HEX[tonumber(it.b) or 4] or C.purple
    local id = tonumber(it.a)
    local link = id and select(2, C_Item.GetItemInfo(id))
    if not link and id then
      if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
      link = "[item " .. id .. "]"
    end
    text = "got " .. (link or "something nice")
  elseif it.kind == "MOUNT" then
    icon, color = "Star", C.amber
    text = it.first and ("got a mount – " .. ns.Colorize("first in the gang!", C.gold)) or "got a mount"
  elseif it.kind == "SOS" then
    icon, color = "SOS", C.red
    text = "sent an SOS in " .. tostring(it.a or "?")
  elseif it.kind == "ACH" then
    local d = ns.Ach and ns.Ach.byId[it.a]
    local tier = d and ns.Ach.TIERS[d.tier] or ns.Ach.TIERS.B
    icon, color = "Trophy", tier.color
    text = "unlocked " .. ns.AchLink(it.a, "«" .. (d and d.name or tostring(it.a)) .. "»", tier.color) .. ns.Colorize(" (" .. tier.name:lower() .. ")", C.dim)
    if it.reacts and #it.reacts > 0 then
      text = text .. ns.Colorize(" · " .. #it.reacts .. (#it.reacts == 1 and " reaction" or " reactions"), C.purple)
    end
  elseif it.kind == "ENSEEN" then
    icon, color = "Target", C.red
    text = "saw the enemy " .. tostring(it.a) .. " in " .. tostring(it.b or "?")
  elseif it.kind == "DUNGEON" then
    icon, color = "Shield", "8FB8E8"
    local members = ns.Extras:RunMembers(it)
    if #members > 1 then
      local names = {}
      for _, mp in ipairs(members) do names[#names + 1] = ns:ShortWho(mp) end
      who = table.concat(names, ns.Colorize(", ", C.dim))
    end
    local bosses = tostring(it.d or ""):match("^(%d+)")
    text = "finished " .. tostring(it.a) .. " · " .. ns.Duration(tonumber(it.b) or 0)
      .. " · " .. (tonumber(it.c) or 0) .. " deaths" .. (bosses and (" · " .. bosses .. " bosses") or "")
    if it.first then text = text .. ns.Colorize(" · first in the gang!", C.gold) end
  else
    text = tostring(it.kind)
  end
  local line = UI.InlineIcon(icon, color, 13) .. "  " .. who .. " " .. ns.Colorize(text, C.text2)
  if withTime then line = line .. ns.Colorize("  " .. ns.Ago(it.t), C.dim) end
  return line
end

-- Kort variant til hendelsesfeeden på skjermen
function ns.FeedShort(it)
  local p = ns:GetPerson(it.pid) or {}
  local who = ns:PersonLinked(p, ns:ShortWho(p, it.char))
  local I = function(name, color) return UI.InlineIcon(name, color, 12) .. "  " end
  if it.kind == "DING" then return I("Up", C.green) .. who .. ns.Colorize(" · level " .. tostring(it.a), C.text2) end
  if it.kind == "DEAD" then return I("Skull", C.red) .. who .. ns.Colorize(" died · " .. tostring(it.a or "?"), C.text2) end
  if it.kind == "ACH" then
    local d = ns.Ach and ns.Ach.byId[it.a]
    local tier = d and ns.Ach.TIERS[d.tier] or ns.Ach.TIERS.B
    return I("Trophy", tier.color) .. who .. " · " .. ns.AchLink(it.a, d and d.name or tostring(it.a), tier.color)
  end
  if it.kind == "LOOT" then
    -- ekte item-lenke (riktig kvalitetsfarge + tooltip når du holder musa over)
    local id = tonumber(it.a)
    local q = tonumber(it.b) or 4
    local qhex = ns.QUALITY_HEX[q] or ns.QUALITY_HEX[4]
    local link = id and C_Item.GetItemInfo and select(2, C_Item.GetItemInfo(id))
    if not link and id then
      if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
      link = "|Hitem:" .. id .. "|h" .. ns.Colorize("[item " .. id .. "]", qhex) .. "|h"
    end
    return I("Star", qhex) .. who .. " · " .. (link or ns.Colorize("nice drop", qhex))
  end
  if it.kind == "SOS" then return I("SOS", C.red) .. ns.Colorize("SOS: ", C.red) .. who .. ns.Colorize(" · " .. tostring(it.a or "?"), C.text2) end
  if it.kind == "MOUNT" then return I("Star", C.amber) .. who .. ns.Colorize(" got a mount", C.text2) end
  if it.kind == "ENSEEN" then return I("Target", C.red) .. "Enemy " .. tostring(it.a) .. ns.Colorize(" seen by", C.text2) .. who end
  if it.kind == "DUNGEON" then
    local bosses = tonumber(((it.d or ""):match("^(%d+)")))
    local deaths = tonumber(it.c) or 0
    return I("Shield", "8FB8E8") .. who .. ns.Colorize(" ran " .. tostring(it.a) .. " · " .. ns.Duration(tonumber(it.b) or 0)
      .. (bosses and (" · " .. bosses .. " boss" .. (bosses == 1 and "" or "es")) or "")
      .. (deaths > 0 and (" · " .. deaths .. " death" .. (deaths == 1 and "" or "s")) or ""), C.text2)
  end
  return I("Star", C.accent) .. who .. " · " .. tostring(it.kind)
end

function ns.ChatLine(it)
  local p = ns:GetPerson(it.pid) or {}
  local c = (p.chars and p.chars[it.char]) or ns:PersonChar(p) or {}
  local line = ns.Colorize(ns.Clock(it.t), C.dim) .. "  " .. ns:PersonLinked(p, ns:PersonLabel(p, it.char))
    .. "  " .. ns.RenderChatText(it.text, it.mention and C.gold or "D4D7DB")
  if it.mention then line = UI.InlineIcon("At", C.gold, 13) .. " " .. line end
  return line
end

ns:RegisterTab("chat", "Chat", "Chat", function(tab)
  local FEED_W = 0   -- the feed moved to Stats → History → Feed; chat takes the full width

  local h = UI.Text(tab, 15, "semi", C.text)
  h:SetPoint("TOPLEFT", 16, -16)
  h:SetText("Gang chat")
  local hint = UI.Text(tab, 11, nil, C.dim)
  hint:SetPoint("LEFT", h, "RIGHT", 10, 0)
  hint:SetText("Tip: /cg text sends straight from normal chat")


  local msgs = UI.MessageFrame(tab, 13)
  msgs:SetPoint("TOPLEFT", 16, -44)
  msgs:SetPoint("BOTTOMRIGHT", -FEED_W - 16, 60)

  local input
  local function send()
    ns.Data:SendChat(input:GetText())
    input:SetText("")
  end
  input = UI.EditBox(tab, 300, 36, "Write to the gang …", send)
  UI.AttachMentions(input)
  input:SetPoint("BOTTOMLEFT", 16, 14)
  input:SetPoint("RIGHT", tab, "RIGHT", -FEED_W - 90, 0)
  input.edit:SetScript("OnEnterPressed", function(self) send() self:SetFocus() end)
  local sendBtn = UI.Button(tab, 64, 36, "Send", "primary", send)
  sendBtn:SetPoint("LEFT", input, "RIGHT", 8, 0)

  local feedLink = UI.Button(tab, 120, 26, "Gang feed ›", "ghost", function()
    ns.Window:Select("stats")
    local st = ns.Window.tabs.stats
    if st and st.SetPage then st:SetPage("history", "feed") end
  end)
  feedLink:SetPoint("TOPRIGHT", -16, -12)

  local lastChatKey
  ns:Listen("ITEMINFO", function() if tab:IsShown() then tab:Refresh() end end)
  function tab:Refresh()
    local key = ns.chatRev or 0
    if key ~= lastChatKey then
      lastChatKey = key
      msgs:Clear()
      if #ns.db.chat == 0 then
        msgs:AddMessage(ns.Colorize("No messages yet. Say hi to the gang!", C.dim))
      end
      -- a line whenever the day changes ("Yesterday", "Today", or the date)
      local lastDay
      local today, yday = date("%Y-%m-%d"), date("%Y-%m-%d", time() - 86400)
      for _, it in ipairs(ns.db.chat) do
        local d = date("%Y-%m-%d", it.t or 0)
        if d ~= lastDay then
          lastDay = d
          local label = d == today and "Today" or (d == yday and "Yesterday" or date("%A %d.%m", it.t or 0))
          msgs:AddMessage(ns.Colorize("—— " .. label .. " ——", C.dim))
        end
        msgs:AddMessage(ns.ChatLine(it))
      end
    end
  end
end)
