-- Chillan? – gjengchat og aktivitet speiles i den vanlige chatten
local ADDON, ns = ...
local C = ns.C

-- Valgfritt (av som standard fra 0.6.0 – alt vises i hendelsesvinduet)
local PREFIX_CHAT = ns.UI.InlineIcon("Chat", "8FB8C9", 13) .. " "
local PREFIX_ACT = ns.UI.InlineIcon("Feed", "C8D1DC", 13) .. " "

local function out(text)
  -- personlenker blir vanlige spillerlenker (hover = personkort, klikk = hvisk); andre Chillan-lenker fjernes
  text = tostring(text):gsub("|Hchillan:([^|]*)|h(.-)|h", function(pid, shown)
    local p = ns:GetPerson(pid)
    local who = p and (p.whisperTo or p.main)
    if who then return "|Hplayer:" .. who .. "|h" .. shown .. "|h" end
    return shown
  end)
  text = text:gsub("|Hchillan[^|]*|h(.-)|h", "%1")
  local frame = DEFAULT_CHAT_FRAME or ChatFrame1
  if frame and frame.AddMessage then frame:AddMessage(text) end
end

-- Klikkbart navn i chatten (venstreklikk = hvisk, høyreklikk = meny)
local function playerLink(p, char)
  local c = (p and p.chars and p.chars[char]) or ns:PersonChar(p) or {}
  local shown = c.name or ns.ShortName(char)
  local link = "|Hplayer:" .. (char or shown) .. "|h" .. ns.Colorize(shown, ns.ClassHex(c.class)) .. "|h"
  local alias = ns:PersonAlias(p)
  if alias then link = link .. ns.Colorize(" (" .. alias .. ")", "9BA1A8") end
  return link
end

ns:Listen("CHAT", function(item)
  if not ns.db.settings.chatMirror then return end
  if (ns.Now() - (item.t or 0)) > 120 then return end -- ikke gammel historikk
  local p = ns:GetPerson(item.pid) or {}
  out(PREFIX_CHAT .. playerLink(p, item.char) .. ": " .. ns.RenderChatText(item.text, "D9F0F7"))
end)

ns:Listen("ACTIVITY", function(text)
  if not ns.db.settings.activityMirror then return end
  out(PREFIX_ACT .. text)
end)

ns:Listen("REACTION", function(item, rp, char, idx)
  if not ns.db.settings.activityMirror or not item then return end
  out(PREFIX_ACT .. ns:ShortWho(rp or {}, char) .. ns.Colorize(" to ", C.dim) .. ns:ShortWho(ns:GetPerson(item.pid) or {}, item.char)
    .. ": " .. ns.Colorize(ns.ReactionText(item, idx), C.purple))
end)
