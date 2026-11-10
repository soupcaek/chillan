-- Chillan? – emotes from the Twitch Emotes v2 addon (if installed).
-- Chillan never ships emote images itself: it looks them up in that addon's own tables,
-- so anyone without it just sees the word ("Kappa").
local ADDON, ns = ...

local E = {}
ns.Emotes = E

local map, names, builtAt = nil, nil, 0

-- word -> texture path (+ size), from TwitchEmotes' tables
local function build()
  local pack = rawget(_G, "TwitchEmotes_defaultpack")
  local words = rawget(_G, "TwitchEmotes_emoticons")
  if type(pack) ~= "table" then map, names = nil, nil return end
  map, names = {}, {}
  local function add(word, name)
    local v = pack[name]
    if type(v) ~= "string" or map[word] then return end
    -- the pack stores "path:HEIGHT:WIDTH" (WoW's |T texture order), so wide emotes are e.g. ":28:56"
    local path, h, w = v:match("^(.-):(%d+):(%d+)")
    if not path then path, h, w = v, 28, 28 end
    map[word] = { path = path, w = tonumber(w) or 28, h = tonumber(h) or 28, name = name }
  end
  if type(words) == "table" then
    for word, name in pairs(words) do if type(word) == "string" then add(word, name) end end
  end
  for name in pairs(pack) do if type(name) == "string" then add(name, name) end end
  for word, e in pairs(map) do
    -- only "real" names in the picker/autocomplete (skip :) style shortcuts)
    if word:match("^[%w_]+$") and word == e.name then names[#names + 1] = word end
  end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
  builtAt = GetTime()
end

function E:Available()
  if not map and GetTime() - builtAt > 5 then build() end
  return map ~= nil and next(map) ~= nil
end

-- emote texture string at a given height (keeps the emote's shape)
-- link = true wraps the image in a |Hchillanemote:word|h link so Chillan's own message frames
-- can show a tooltip with the emote name (":Pog:") on hover
function E:Icon(word, h, link)
  if not self:Available() then return nil end
  local e = map[word]
  if not e then return nil end
  h = h or 18
  local w = math.floor(h * (e.w / math.max(1, e.h)) + 0.5)
  -- very wide emotes: keep the shape but never wider than ~7 lines of text so they fit the chat
  local maxW = math.floor(h * 7)
  if w > maxW then h = math.max(8, math.floor(h * maxW / w + 0.5)) w = maxW end
  local icon = string.format("|T%s:%d:%d|t", e.path, h, w)
  if link and not word:find("|", 1, true) then
    icon = "|Hchillanemote:" .. word .. "|h" .. icon .. "|h"
  end
  return icon
end

-- replace emote words in plain text (no colour codes inside) with their images
function E:Render(text, h, link)
  if type(text) ~= "string" or text == "" or not self:Available() then return text end
  return (text:gsub("%S+", function(word)
    local icon = self:Icon(word, h, link)
    if icon then return icon end
    -- "Kappa!" or "KEKW," – keep trailing punctuation
    local core, tail = word:match("^(.-)([%p]+)$")
    if core and core ~= "" then
      icon = self:Icon(core, h, link)
      if icon then return icon .. tail end
    end
    return nil
  end))
end

-- names starting with (or containing) prefix, best matches first
function E:Search(prefix, max)
  if not self:Available() then return {} end
  prefix = (prefix or ""):lower()
  local starts, contains = {}, {}
  for _, n in ipairs(names) do
    local l = n:lower()
    if prefix == "" or l:sub(1, #prefix) == prefix then starts[#starts + 1] = n
    elseif #prefix >= 3 and l:find(prefix, 1, true) then contains[#contains + 1] = n end
    if #starts >= (max or 40) then break end
  end
  for _, n in ipairs(contains) do
    if #starts >= (max or 40) then break end
    starts[#starts + 1] = n
  end
  return starts
end

function E:Info(word)
  if not self:Available() then return nil end
  return map[word]
end

function E:Count() return self:Available() and #names or 0 end

-- recently used / favourites (per account)
function E:Used(word)
  local r = ns.db.emoteRecent or {}
  for i = #r, 1, -1 do if r[i] == word then table.remove(r, i) end end
  table.insert(r, 1, word)
  while #r > 24 do table.remove(r) end
  ns.db.emoteRecent = r
end

function E:ToggleFav(word)
  ns.db.emoteFav = ns.db.emoteFav or {}
  ns.db.emoteFav[word] = (not ns.db.emoteFav[word]) or nil
end

function E:Favs()
  local out = {}
  for w in pairs(ns.db.emoteFav or {}) do if map and map[w] then out[#out + 1] = w end end
  table.sort(out)
  return out
end

-- TwitchEmotes (and its emote packs) fill their tables when they load
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  C_Timer.After(3, function() builtAt = 0 build() ns:Fire("CHAT") end)
end)
