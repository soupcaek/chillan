-- Chillan? Market – Disenchantry (1.3.5): what an item gives when disenchanted (classic table, the one
-- WoW Forever uses), what that's worth at the auction house, and whether disenchanting beats selling.
local ADDON, ns = ...
local D = {}
ns.Disenchant = D

local MAT = {
  strange = 10940, soul = 11083, vision = 11137, dream = 11176, illusion = 16204,
  lmagic = 10938, gmagic = 10939, lastral = 10998, gastral = 11082, lmystic = 11134, gmystic = 11135,
  lnether = 11174, gnether = 11175, leternal = 16202, geternal = 16203,
  sglim = 10978, lglim = 11084, sglow = 11138, lglow = 11139, srad = 11177, lrad = 11178,
  sbril = 14343, lbril = 14344, nexus = 20725,
}
D.MAT = MAT

-- green (uncommon) armor, by item level: { up to level, dust {id, min, max, chance}, essence, shard }
local GREEN = {
  { 15, { "strange", 1, 2, 0.80 }, { "lmagic", 1, 2, 0.20 } },
  { 20, { "strange", 2, 3, 0.75 }, { "gmagic", 1, 2, 0.20 }, { "sglim", 1, 1, 0.05 } },
  { 25, { "strange", 4, 6, 0.75 }, { "lastral", 1, 2, 0.15 }, { "sglim", 1, 1, 0.10 } },
  { 30, { "soul", 1, 2, 0.75 }, { "gastral", 1, 2, 0.20 }, { "lglim", 1, 1, 0.05 } },
  { 35, { "soul", 2, 5, 0.75 }, { "lmystic", 1, 2, 0.20 }, { "sglow", 1, 1, 0.05 } },
  { 40, { "vision", 1, 2, 0.75 }, { "gmystic", 1, 2, 0.20 }, { "lglow", 1, 1, 0.05 } },
  { 45, { "vision", 2, 5, 0.75 }, { "lnether", 1, 2, 0.20 }, { "srad", 1, 1, 0.05 } },
  { 50, { "dream", 1, 2, 0.75 }, { "gnether", 1, 2, 0.20 }, { "lrad", 1, 1, 0.05 } },
  { 55, { "dream", 2, 5, 0.75 }, { "leternal", 1, 2, 0.20 }, { "sbril", 1, 1, 0.05 } },
  { 60, { "illusion", 1, 2, 0.75 }, { "geternal", 1, 2, 0.20 }, { "lbril", 1, 1, 0.05 } },
  { 99, { "illusion", 2, 5, 0.75 }, { "geternal", 2, 3, 0.20 }, { "lbril", 1, 1, 0.05 } },
}
-- blue (rare): shards
local BLUE = {
  { 25, { "sglim", 1, 1, 1 } }, { 30, { "lglim", 1, 1, 1 } }, { 35, { "sglow", 1, 1, 1 } },
  { 40, { "lglow", 1, 1, 1 } }, { 45, { "srad", 1, 1, 1 } }, { 50, { "lrad", 1, 1, 1 } },
  { 55, { "sbril", 1, 1, 1 } }, { 99, { "lbril", 1, 1, 0.995 }, { "nexus", 1, 1, 0.005 } },
}
-- purple (epic)
local PURPLE = {
  { 45, { "srad", 2, 4, 1 } }, { 50, { "lrad", 2, 4, 1 } }, { 55, { "sbril", 2, 4, 1 } },
  { 60, { "nexus", 1, 1, 1 } }, { 99, { "nexus", 1, 2, 1 } },
}

local function info(id)
  local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not f then return nil end
  local ok, name, link, quality, ilvl, _, itype, _, _, loc, _, sell, classID = pcall(f, id)
  if not ok or not name then return nil end
  return { name = name, link = link, quality = quality, ilvl = ilvl, loc = loc, sell = sell, classID = classID, itype = itype }
end
D.Info = info

local ARMOR_CLASS, WEAPON_CLASS = 4, 2
local function isGear(i)
  if not i or not i.loc or i.loc == "" or i.loc == "INVTYPE_BAG" or i.loc == "INVTYPE_AMMO" or i.loc == "INVTYPE_QUIVER"
    or i.loc == "INVTYPE_TABARD" or i.loc == "INVTYPE_BODY" then return false end
  return i.classID == ARMOR_CLASS or i.classID == WEAPON_CLASS or i.classID == nil
end
local function isWeapon(i)
  return i.classID == WEAPON_CLASS or (i.loc and (i.loc:find("WEAPON") or i.loc == "INVTYPE_RANGED" or i.loc == "INVTYPE_2HWEAPON" or i.loc == "INVTYPE_RANGEDRIGHT"))
end

-- the possible results: { { id, min, max, chance }, … } or nil when it can't be disenchanted
function D:Results(id)
  local i = info(id)
  if not i or not isGear(i) or not i.quality or i.quality < 2 or i.quality > 4 or not i.ilvl then return nil end
  local tbl = i.quality == 2 and GREEN or i.quality == 3 and BLUE or PURPLE
  local row
  for _, r in ipairs(tbl) do if i.ilvl <= r[1] then row = r break end end
  if not row then return nil end
  local out = {}
  for k = 2, #row do
    local m = row[k]
    local chance = m[4]
    -- green weapons give essence where armor gives dust (and the other way around)
    if i.quality == 2 and isWeapon(i) and k <= 3 then chance = (k == 2) and row[3][4] or row[2][4] end
    out[#out + 1] = { id = MAT[m[1]], min = m[2], max = m[3], chance = chance }
  end
  return out, i
end

-- expected value at the auction house (after the 5 % cut); nil if no mat price is known
function D:Value(id)
  local res = self:Results(id)
  if not res or not ns.Market then return nil end
  local sum, known = 0, false
  for _, r in ipairs(res) do
    local e = ns.Market:Get(r.id)
    if e then
      known = true
      sum = sum + e.v * (r.min + r.max) / 2 * r.chance
    end
  end
  if not known then return nil end
  return math.floor(sum * 0.95), res
end

-- "Strange Dust 1–2 · Lesser Magic Essence 1–2 (20 %)"
function D:Describe(res)
  local parts = {}
  for _, r in ipairs(res or {}) do
    local i = info(r.id)
    local q = r.min == r.max and tostring(r.min) or (r.min .. "–" .. r.max)
    parts[#parts + 1] = ((i and i.name) or ("item " .. r.id)) .. " " .. q .. (r.chance < 1 and (" (" .. math.floor(r.chance * 100 + 0.5) .. " %)") or "")
  end
  return table.concat(parts, " · ")
end

-- the mats are in the price list, so a full scan prices them; ask the gang for any we're missing
function D:AskMats(id)
  local res = self:Results(id)
  if not res or not ns.Market then return end
  for _, r in ipairs(res) do if not ns.Market:Get(r.id) then ns.Market:Ask(r.id) end end
end

---------------------------------------------------------------------------
-- (1.4.35) "Disenchant next": the items in your bags that are worth more disenchanted than sold, and
-- a button that disenchants the best one per click (the game allows one spell per click). The
-- button sits under your bags and on the Market tab, only for characters who know Disenchant.
---------------------------------------------------------------------------
local DISENCHANT_SPELL = 13262
function D.CanDisenchant()
  if IsPlayerSpell then local ok, k = pcall(IsPlayerSpell, DISENCHANT_SPELL) if ok and k then return true end end
  if IsSpellKnown then local ok, k = pcall(IsSpellKnown, DISENCHANT_SPELL) if ok and k then return true end end
  return false
end

-- every disenchantable item in the bags with its value either way, best gain first
function D:BagItems()
  local out = {}
  for bag = 0, 4 do
    local n = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)) or 0
    for slot = 1, n do
      local ok, it = pcall(C_Container.GetContainerItemInfo, bag, slot)
      if ok and type(it) == "table" and it.hyperlink then
        local id = it.itemID or tonumber(it.hyperlink:match("item:(%d+)"))
        local res = id and self:Results(id)
        if res then
          local de = self:Value(id)
          if not de then self:AskMats(id) end
          local e = (not it.isBound) and ns.Market and ns.Market:Get(id)
          local net = e and math.floor(e.v * 0.95) or 0
          local vend = (ns.Market and ns.Market.VendorPrice(id)) or 0
          local sell, how = vend, "vendor"
          if net > vend then sell, how = net, "auction" end
          out[#out + 1] = { id = id, bag = bag, slot = slot, link = it.hyperlink, res = res, de = de, sell = sell, sellHow = how,
            gain = (de or 0) - sell, locked = it.isLocked }
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.gain > b.gain end)
  return out
end
-- the ones to disenchant: worth more as mats (items with no mat prices yet are left alone)
function D:ToDisenchant()
  local out = {}
  for _, it in ipairs(self:BagItems()) do
    if it.de and it.gain > 0 and not it.locked then out[#out + 1] = it end
  end
  return out
end

local buttons = {}
local function refreshButtons()
  if InCombatLockdown and InCombatLockdown() then return end
  local can = D.CanDisenchant() and ns.db and ns.db.settings.mkDEButton ~= false
  local n = can and #D:ToDisenchant() or 0
  for _, b in ipairs(buttons) do
    b.label:SetText(n > 0 and ("Disenchant next (" .. n .. ")") or "Nothing to disenchant")
    b:SetAlpha(n > 0 and 1 or 0.55)
    if b.autoHide then b:SetShown(can and n > 0 and b.anchorShown) else b:SetShown(can) end
  end
end
D.RefreshButtons = refreshButtons

-- a secure button: PreClick picks the next item and sets the macro (only out of combat)
function D:MakeButton(parent, w, h, autoHide)
  local UI, C = ns.UI, ns.C
  local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
  b:SetSize(w, h)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "macro")
  b.panel = UI.Panel(b, C.card, C.line, true)
  b.panel:SetAllPoints()
  b.panel:SetFrameLevel(b:GetFrameLevel())
  b.icon = UI.Icon(b, "Diamond", 12, "B9AEDB")
  b.icon:SetPoint("LEFT", 8, 0)
  b.label = UI.Text(b, 11, "semi", C.text)
  b.label:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
  b.autoHide = autoHide
  b:SetScript("PreClick", function(self)
    if InCombatLockdown and InCombatLockdown() then return end
    local nextIt = D:ToDisenchant()[1]
    if nextIt then
      self:SetAttribute("macrotext", "/cast " .. ((C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(DISENCHANT_SPELL)) or "Disenchant")
        .. "\n/use " .. nextIt.bag .. " " .. nextIt.slot)
    else
      self:SetAttribute("macrotext", "")
    end
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Disenchant next", 1, 1, 1)
    local list = D:ToDisenchant()
    if #list == 0 then GameTooltip:AddLine("No item in your bags is worth more disenchanted than sold.", 0.6, 0.63, 0.66, true) end
    for i = 1, math.min(8, #list) do
      local it = list[i]
      GameTooltip:AddDoubleLine(it.link, "+" .. ns.Market.Coins(it.gain), 1, 1, 1, 0.6, 0.85, 0.6)
    end
    GameTooltip:AddLine("One click per item. Items are only picked when disenchanting beats selling.", 0.6, 0.63, 0.66, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  buttons[#buttons + 1] = b
  refreshButtons()
  return b
end

-- under the bags: the default bag frames (another bag addon hides them, then the Market tab has it)
local bagBtn
local function attachToBags()
  if bagBtn or (InCombatLockdown and InCombatLockdown()) then return end
  local host = _G.ContainerFrameCombinedBags or _G.ContainerFrame1
  if not host then return end
  bagBtn = D:MakeButton(UIParent, 170, 24, true)
  bagBtn:SetFrameStrata("HIGH")
  local function sync()
    if InCombatLockdown and InCombatLockdown() then return end
    local shown = (_G.ContainerFrameCombinedBags and _G.ContainerFrameCombinedBags:IsShown() and _G.ContainerFrameCombinedBags)
      or (_G.ContainerFrame1 and _G.ContainerFrame1:IsShown() and _G.ContainerFrame1)
    bagBtn.anchorShown = shown and true or false
    if shown then
      bagBtn:ClearAllPoints()
      bagBtn:SetPoint("TOPRIGHT", shown, "BOTTOMRIGHT", 0, -4)
    end
    refreshButtons()
  end
  for _, f in ipairs({ _G.ContainerFrameCombinedBags, _G.ContainerFrame1 }) do
    if f and f.HookScript then f:HookScript("OnShow", sync) f:HookScript("OnHide", sync) end
  end
  sync()
end
ns:On("PLAYER_LOGIN", function() C_Timer.After(3, attachToBags) end)
ns:On("BAG_UPDATE_DELAYED", function() refreshButtons() end)
ns:On("PLAYER_REGEN_ENABLED", function() refreshButtons() end)
ns:Listen("MARKET", function() refreshButtons() end)
