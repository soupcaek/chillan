-- Chillan? – unread badges on the side menu (Chat, Ideas, What's new)
local ADDON, ns = ...
local B = {}
ns.Badges = B

local function seen() ns.db.seen = ns.db.seen or {} return ns.db.seen end

-- How many unread items does a tab have?
function B:Count(key)
  local s = seen()
  if key == "chat" then
    -- the event window already shows gang chat: then there's nothing to flag
    if ns.db.settings.eventFeed and ns.db.settings.feedChat then return 0 end
    local since, n = s.chat or 0, 0
    for _, it in ipairs(ns.db.chat or {}) do if it.t and it.t > since and it.pid ~= ns.pid then n = n + 1 end end
    return n
  elseif key == "ideas" then
    local since, n = s.ideas or 0, 0
    for _, it in pairs(ns.db.ideas or {}) do
      if not it.deleted and ((it.t and it.t > since and it.pid ~= ns.pid) or (it.statusAt and it.statusAt > since)) then n = n + 1 end
    end
    return n
  elseif key == "changelog" then
    return (s.changelog ~= ns.VERSION) and 1 or 0
  end
  return 0
end

function B:Total()
  return self:Count("chat") + self:Count("ideas") + self:Count("changelog")
end

function B:MarkSeen(key)
  local s = seen()
  local before = self:Count(key)
  if key == "changelog" then
    if s.changelog ~= ns.VERSION then s.changelogPrev = s.changelog or "0" end
    s.changelog = ns.VERSION
  else s[key] = ns.Now() end
  if before > 0 then ns:Fire("BADGES") end
end

-- refresh badges whenever data changes
local pending = false
local function soon()
  if pending then return end
  pending = true
  C_Timer.After(0.5, function() pending = false ns:Fire("BADGES") end)
end
ns:Listen("DATA", soon)
ns:Listen("CHAT", soon)

-- red dot on the minibar logo when something is unread
ns:Listen("BADGES", function()
  local m = ns.Overlays and ns.Overlays.minibar
  if not m or not m.logo then return end
  if not m.unread then
    m.unread = m:CreateTexture(nil, "OVERLAY")
    m.unread:SetTexture(ns.TEX .. "Circle")
    m.unread:SetSize(7, 7)
    m.unread:SetPoint("CENTER", m.logo, "TOPRIGHT", 2, -1)
    m.unread:SetVertexColor(ns.hex(ns.C.red))
  end
  m.unread:SetShown(B:Total() > 0 and not (ns.Window.frame and ns.Window.frame:IsShown()))
end)
