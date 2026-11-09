-- Chillan? – layer hop: ask the gang for a group invite to change layer.
-- In WoW Forever you move to the inviter's layer by joining their group, and stay there
-- while you stay in the group (leaving sends you back). There is no other way for addons.
local ADDON, ns = ...
local UI, C, hex, Comm = ns.UI, ns.C, ns.hex, ns.Comm

local L = {}
ns.LayerHop = L
L.mine = nil      -- my open request { id, t }
L.open = {}       -- requests from others I can answer: id -> { pid, target, t }

local function canHelp()
  if IsInGroup and IsInGroup() then return false end
  if IsInInstance and IsInInstance() then return false end
  if InCombatLockdown and InCombatLockdown() then return false end
  return true
end

-- I want to change layer
function L:Request()
  if IsInGroup and IsInGroup() then
    ns.Print("Leave your group first – you change layer by joining someone's group.")
    return
  end
  if IsInInstance and IsInInstance() then
    ns.Print("You can't change layer inside a dungeon.")
    return
  end
  if self.mine and ns.Now() - self.mine.t < 30 then
    ns.Print("Already asked – wait a little (layer changes also have a cooldown in the game).")
    return
  end
  local id = Comm:NewId()
  self.mine = { id = id, t = ns.Now() }
  Comm:Broadcast(Comm:Build("LH", id, ns.pid, Comm:MyFull()), 1)
  ns.Print("Asked the gang for a layer-hop invite.")
  C_Timer.After(45, function()
    if self.mine and self.mine.id == id and not self.mine.by then
      ns.Print("Nobody could invite you for a layer hop right now.")
      self.mine = nil
    end
  end)
end

-- someone in the gang wants a hop
Comm:Handle("LH", function(f)
  local id, pid, target = f[1], f[2], f[3]
  if not id or not pid or pid == ns.pid or not target or target == "" then return end
  if not canHelp() then return end
  L.open[id] = { pid = pid, target = target, t = ns.Now() }
  L:ShowAsk(id)
end)

-- someone took it: close the popup everywhere, tell the asker who's inviting
Comm:Handle("LT", function(f)
  local id, by = f[1], f[2]
  if not id then return end
  L.open[id] = nil
  if L.frame and L.frame.id == id then L.frame:Hide() end
  if L.mine and L.mine.id == id and by and by ~= ns.pid and not L.mine.by then
    L.mine.by = by
    L.mine.t = ns.Now()
    local p = ns:GetPerson(by)
    ns.Print((p and ns:ShortWho(p) or "Someone") .. " is inviting you for a layer hop.")
  end
end)

function L:Help(id)
  local r = self.open[id]
  if not r then return end
  self.open[id] = nil
  Comm:Broadcast(Comm:Build("LT", id, ns.pid), 1)
  ns.Invite(r.target)
  if self.frame then self.frame:Hide() end
end

-- the asker accepts the gang invite automatically (only while a request is open)
local function isGangChar(name)
  if not name or name == "" then return false end
  local short = ns.ShortName(name):lower():gsub("[%s%-]", "")
  for pid, p in pairs(ns.db.people or {}) do
    if pid ~= ns.pid then
      for key, c in pairs(p.chars or {}) do
        local n = ((c and c.name) or ns.ShortName(key) or ""):lower():gsub("[%s%-]", "")
        if n == short then return true end
      end
    end
  end
  return false
end

ns:On("PARTY_INVITE_REQUEST", function(inviter)
  local m = L.mine
  if not m or ns.Now() - m.t > 60 then return end
  if not isGangChar(inviter) then return end
  if AcceptGroup then AcceptGroup() end
  if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
  L.mine = nil
end)

-- small popup for the helpers
function L:ShowAsk(id)
  local r = self.open[id]
  if not r then return end
  if not self.frame then
    local f = UI.OverlayPanel and UI.OverlayPanel(UIParent, C.window, C.activeLine, true) or UI.Panel(UIParent, C.window, C.activeLine, true)
    f:SetSize(340, 96)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    UI.Movable(f, "layerhop", function(fr) fr:SetPoint("TOP", UIParent, "TOP", 0, -150) end)
    f.title = UI.Text(f, 13, "semi", C.text)
    f.title:SetPoint("TOPLEFT", 14, -14)
    f.title:SetPoint("RIGHT", -14, 0)
    f.sub = UI.Text(f, 11, nil, C.text2)
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -5)
    f.sub:SetPoint("RIGHT", -14, 0)
    f.yes = UI.Button(f, 150, 28, "Invite", "primary", function() L:Help(f.id) end)
    f.yes:SetPoint("BOTTOMLEFT", 14, 12)
    f.no = UI.Button(f, 150, 28, "Not now", "ghost", function() f:Hide() end)
    f.no:SetPoint("BOTTOMRIGHT", -14, 12)
    self.frame = f
  end
  local f = self.frame
  local p = ns:GetPerson(r.pid)
  f.id = id
  f.title:SetText((p and ns:ShortWho(p) or "Someone") .. ns.Colorize(" asks for an invite to change layer", C.text))
  f.sub:SetText("They join your group and your layer. You can leave the group whenever you like.")
  f:Show()
  if ns.Sound then pcall(ns.Sound, "mention") end
  C_Timer.After(30, function() if f.id == id and f:IsShown() then f:Hide() end end)
end
