-- Chillan? – "Chat": gang chat with the feed beside it
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

-- (1.3.12) short dungeon names in feed lines; hover shows the full name
local SHORT = {
  ["Ragefire Chasm"] = "RFC", ["Wailing Caverns"] = "WC", ["The Deadmines"] = "VC", ["Deadmines"] = "VC",
  ["Shadowfang Keep"] = "SFK", ["Blackfathom Deeps"] = "BFD", ["The Stockade"] = "Stocks",
  ["Gnomeregan"] = "Gnomer", ["Razorfen Kraul"] = "RFK", ["Scarlet Monastery"] = "SM",
  ["Razorfen Downs"] = "RFD", ["Uldaman"] = "Ulda", ["Zul'Farrak"] = "ZF", ["Maraudon"] = "Mara",
  ["Sunken Temple"] = "ST", ["The Temple of Atal'Hakkar"] = "ST", ["Blackrock Depths"] = "BRD",
  ["Lower Blackrock Spire"] = "LBRS", ["Upper Blackrock Spire"] = "UBRS", ["Blackrock Spire"] = "BRS",
  ["Dire Maul"] = "DM", ["Scholomance"] = "Scholo", ["Stratholme"] = "Strat",
}
function ns.ShortDungeonPlain(name)
  name = tostring(name or "?")
  return SHORT[name] or name
end
function ns.ShortDungeon(name)
  name = tostring(name or "?")
  local short = SHORT[name]
  if not short then
    local base, wing = name:match("^(.-)%s*[%-–:]%s*(.+)$")
    if base and SHORT[base] then short = SHORT[base] .. " " .. wing end
  end
  if not short then return name end
  return "|Hchillantip:" .. name .. "|h" .. short .. "|h"
end


-- (1.4.0) lines for bosses, raids, battlegrounds and "about to ding"
local function mmss(secs)
  secs = tonumber(secs) or 0
  if secs <= 0 then return nil end
  if secs >= 3600 then return ns.Duration(secs) end
  return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end
function ns.SceneLine(it, who)
  local C = ns.C
  if it.kind == "BOSS" then
    local deaths, tries, gangN = tostring(it.d or ""):match("^(%d*):?(%d*):?(%d*)")
    deaths, tries, gangN = tonumber(deaths) or 0, tonumber(tries) or 1, tonumber(gangN) or 1
    local subject = gangN > 1 and "Gang" or who
    local bits = { ns.Colorize(" killed ", C.text2) .. ns.Colorize(tostring(it.b or "?"), C.text) }
    local t = mmss(it.c)
    if t then bits[#bits + 1] = t end
    if deaths == 0 then bits[#bits + 1] = ns.Colorize("no deaths", C.green)
    else bits[#bits + 1] = ns.Plural(deaths, "death") end
    if tries > 1 then bits[#bits + 1] = ns.Colorize((tries == 2 and "2nd" or tries == 3 and "3rd" or (tries .. "th")) .. " try", C.amber) end
    return "Shield", "8FB8E8", subject .. table.concat(bits, ns.Colorize(" · ", C.dim))
      .. ns.Colorize(" · " .. ns.ShortDungeon(it.a), C.dim)
  elseif it.kind == "RAID" then
    local bosses, gangN = tostring(it.d or ""):match("^([^|]*)|?(%d*)")
    return "Crown", "F0A060", who .. ns.Colorize(" · raid night in " .. tostring(it.a) .. " · " .. (bosses or "?") .. " bosses · "
      .. ns.Duration(tonumber(it.b) or 0) .. " · " .. ns.Plural(tonumber(it.c) or 0, "wipe"), C.text2)
  elseif it.kind == "NEARDING" then
    return "Up", "E0B04F", who .. ns.Colorize(" is " .. (tonumber(it.b) or 2) .. " % from level " .. tostring(it.a) .. " – get your grats ready", C.text2)
  elseif it.kind == "BGEND" then
    if it.a == "streak" then
      return "Trophy", "E0C068", who .. ns.Colorize(" won " .. tostring(it.b) .. " battlegrounds in a row today", C.text2)
    end
    local won = tostring(it.b) == "1"
    local mvp, hk, honor = tostring(it.d or ""):match("^([^:]*):?(%d*):?(%d*)")
    local line = ns.Colorize(won and "Won " or "Lost ", won and C.green or C.red) .. ns.Colorize(tostring(it.a), C.text)
      .. ((it.c and it.c ~= "") and ns.Colorize(" " .. it.c, C.text2) or "")
    if mvp and mvp ~= "" then line = line .. ns.Colorize(" · MVP " .. mvp .. ((tonumber(hk) or 0) > 0 and (" (" .. hk .. " HKs)") or ""), C.text2) end
    return "Trophy", won and "5FD18B" or "F2777A", who .. ns.Colorize(" · ", C.dim) .. line
  elseif it.kind == "BGREV" then
    return "Target", "5FD18B", who .. ns.Colorize(" got Revenge on ", C.text2) .. ns.Colorize(tostring(it.a), C.red)
      .. ((it.b and it.b ~= "") and ns.Colorize(" · " .. it.b, C.dim) or "")
  elseif it.kind == "FLAG" then
    return "Star", "E0C068", who .. ns.Colorize(it.a == "cap" and " captured the flag" or " returned the flag", C.text2)
      .. ((it.b and it.b ~= "") and ns.Colorize(" · " .. it.b, C.dim) or "")
  end
end

-- Tekst for en feed-hendelse (brukes også i Feed-fanen)
function ns.FeedLine(it, withTime)
  local p = ns:GetPerson(it.pid) or {}
  local c = (p.chars and p.chars[it.char]) or ns:PersonChar(p) or {}
  local who = ns:PersonLinked(p, ns:PersonLabel(p, it.char))
  local icon, color, text = "Star", C.purple, ""
  local sIcon, sColor, sLine = ns.SceneLine(it, who)
  if sIcon then
    local line = UI.InlineIcon(sIcon, sColor, 13) .. "  " .. sLine
    if it.reacts and #it.reacts > 0 then line = line .. ns.Colorize(" · " .. #it.reacts .. (#it.reacts == 1 and " reaction" or " reactions"), C.purple) end
    if withTime then line = line .. ns.Colorize("  " .. ns.Ago(it.t), C.dim) end
    return line
  end
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
  elseif it.kind == "KILL" and ns.Kills then
    local funny = ns.Kills:Line(it, ns.Kills:Names(it, true), C.text2)
    local line = UI.InlineIcon("Target", C.gold, 13) .. "  " .. (funny or (who .. " killed " .. tostring(it.c)))
    if it.reacts and #it.reacts > 0 then
      line = line .. ns.Colorize(" · " .. #it.reacts .. (#it.reacts == 1 and " reaction" or " reactions"), C.gold)
    end
    if withTime then line = line .. ns.Colorize("  " .. ns.Ago(it.t), C.dim) end
    return line
  elseif it.kind == "DEAD" then
    icon, color = "Skull", C.dim
    local funny = ns.Deaths and ns.Deaths:Line(it, who, C.text2)
    if funny then
      local line = UI.InlineIcon(icon, color, 13) .. "  " .. funny
      if it.reacts and #it.reacts > 0 then
        line = line .. ns.Colorize(" · " .. #it.reacts .. (#it.reacts == 1 and " reaction" or " reactions"), C.red)
      end
      if withTime then line = line .. ns.Colorize("  " .. ns.Ago(it.t), C.dim) end
      return line
    end
    text = "died in " .. tostring(it.a or "?")
    if it.reacts and #it.reacts > 0 then
      text = text .. ns.Colorize(" · " .. #it.reacts .. (#it.reacts == 1 and " reaction" or " reactions"), C.red)
    end
  elseif it.kind == "LOOT" then
    icon, color = "Star", ns.QUALITY_HEX[tonumber(it.b) or 4] or C.purple
    text = "got " .. (ns.ItemLink(it.a) or ns.Colorize("an item (loading…)", C.dim))
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
    if it.c and it.c ~= "" then text = text .. ns.Colorize(" · " .. it.c, C.text2) end
    if it.reacts and #it.reacts > 0 then
      text = text .. ns.Colorize(" · " .. #it.reacts .. (#it.reacts == 1 and " reaction" or " reactions"), C.purple)
    end
  elseif it.kind == "CUNT" then
    icon, color = "Skull", C.red
    text = "put " .. ns.Colorize(tostring(it.a), C.red) .. " on the Cunt List" .. ns.Colorize(" – " .. tostring(it.b or ""), C.dim)
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
    text = "finished " .. ns.ShortDungeon(it.a) .. " · " .. ns.Duration(tonumber(it.b) or 0)
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
  local sIcon, sColor, sLine = ns.SceneLine(it, who)
  if sIcon then return I(sIcon, sColor) .. sLine end
  if it.kind == "DING" then return I("Up", C.green) .. who .. ns.Colorize(" · level " .. tostring(it.a), C.text2) end
  if it.kind == "KILL" and ns.Kills then
    local funny = ns.Kills:Line(it, ns.Kills:Names(it, true), C.text2)
    return I("Target", C.gold) .. (funny or (who .. ns.Colorize(" killed " .. tostring(it.c), C.text2)))
  end
  if it.kind == "DEAD" then
    local funny = ns.Deaths and ns.Deaths:Line(it, who, C.text2)
    if funny then return I("Skull", C.red) .. funny end
    return I("Skull", C.red) .. who .. ns.Colorize(" died · " .. tostring(it.a or "?"), C.text2)
  end
  if it.kind == "ACH" then
    local d = ns.Ach and ns.Ach.byId[it.a]
    local tier = d and ns.Ach.TIERS[d.tier] or ns.Ach.TIERS.B
    return I("Trophy", tier.color) .. who .. " · " .. ns.AchLink(it.a, d and d.name or tostring(it.a), tier.color)
      .. ((it.c and it.c ~= "") and ns.Colorize(" · " .. it.c, C.text2) or "")
  end
  if it.kind == "LOOT" then
    -- ekte item-lenke (riktig kvalitetsfarge + tooltip når du holder musa over)
    local qhex = ns.QUALITY_HEX[tonumber(it.b) or 4] or ns.QUALITY_HEX[4]
    return I("Star", qhex) .. who .. " · " .. (ns.ItemLink(it.a) or ns.Colorize("a nice drop (loading…)", C.dim))
  end
  if it.kind == "SOS" then return I("SOS", C.red) .. ns.Colorize("SOS: ", C.red) .. who .. ns.Colorize(" · " .. tostring(it.a or "?"), C.text2) end
  if it.kind == "MOUNT" then return I("Star", C.amber) .. who .. ns.Colorize(" got a mount", C.text2) end
  if it.kind == "CUNT" then return I("Skull", C.red) .. who .. ns.Colorize(" put ", C.text2) .. ns.Colorize(tostring(it.a), C.red) .. ns.Colorize(" on the Cunt List", C.text2) end
  if it.kind == "ENSEEN" then return I("Target", C.red) .. "Enemy " .. tostring(it.a) .. ns.Colorize(" seen by", C.text2) .. who end
  if it.kind == "DUNGEON" then
    local bosses = tonumber(((it.d or ""):match("^(%d+)")))
    local deaths = tonumber(it.c) or 0
    return I("Shield", "8FB8E8") .. who .. ns.Colorize(" ran " .. ns.ShortDungeon(it.a) .. " · " .. ns.Duration(tonumber(it.b) or 0)
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
    ns.Window:Select("history")
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
