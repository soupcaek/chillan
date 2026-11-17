-- Chillan? – QoL: small helpers you switch on and off in the QoL tab
-- Mount gear (Carrot on a Stick, Desert Rose, spurs, riding gloves), vendor (repair, sell junk), fast loot,
-- questing (auto accept / turn in, skip seen cutscenes, XP bar text),
-- annoyances (duels, guild invites, summons, res, error spam, camera zoom),
-- info (red tint on items you can't use, flight timer).
local ADDON, ns = ...
local Q = {}
local wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end return t end
ns.QoL = Q

local S = ns.U.Settings
local function on(key) return S()[key] and true or false end
local secret = ns.U.Secret
local function fullCombat() return InCombatLockdown() or (ns.S(UnitAffectingCombat, "player") and true or false) end

-- looked up on every call (never cached at load) so late-loaded APIs work
local function GetNumSlots(bag) local f = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots return f and f(bag) end
local function GetSlotLink(bag, slot) local f = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink return f and f(bag, slot) end
local function UseSlot(bag, slot) local f = (C_Container and C_Container.UseContainerItem) or UseContainerItem return f and f(bag, slot) end
local function slotInfo(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local ok, t = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if ok and type(t) == "table" then return t end
    return nil
  end
  if GetContainerItemInfo then
    local _, count, locked, quality, _, _, link, _, noValue, id = GetContainerItemInfo(bag, slot)
    if link then return { stackCount = count, isLocked = locked, quality = quality, hyperlink = link, hasNoValue = noValue, itemID = id } end
  end
end
local function itemInfo(x)
  local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not f then return end
  local r = { pcall(f, x) }
  if r[1] then return select(2, unpack(r, 1, 20)) end
end
local function equipByName(link, slot)
  local f = (C_Item and C_Item.EquipItemByName) or EquipItemByName
  if f then return pcall(f, link, slot) end
end
local function idOf(link) return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil end
local function enchOf(link) return type(link) == "string" and tonumber(link:match("item:%d+:(%d*)") or "") or nil end

local function bagSlots(fn)
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    local n = GetNumSlots and ns.S(GetNumSlots, bag) or 0
    for slot = 1, (n or 0) do
      local r = fn(bag, slot)
      if r then return r end
    end
  end
end

Q.IsGangChar = ns.U.IsGangChar

local money = ns.U.Money

---------------------------------------------------------------------------
-- Mount gear: speed gear on when you mount, your own gear back on dismount
-- Built for WoW Forever's items. Riding Crop, Skybreaker Whip, the swim gear
-- and flight forms don't exist there.
---------------------------------------------------------------------------
-- slot 0 = either trinket slot (the one picked in the QoL tab)
-- zones: only worn there; listed before the plain item so it wins in its zones
local F = ns.FOREVER
Q.RIDE = {
  { key = "desertRose", item = F.items.desertRose.id, slot = 0, zones = F.zones.desert, opt = "qolMountZone" },
  { key = "carrot", item = F.items.carrot.id, slot = 0 },
  { key = "wintersaber", item = F.items.wintersaberGloves.id, slot = 10, zones = F.zones.winterspring, opt = "qolMountZone" },
  { key = "ridingSkill", ench = F.enchants.ridingSkill.id, slot = 10, opt = "qolMountArmor" },  -- Riding Skill (gloves)
  { key = "spurs", ench = F.enchants.mithrilSpurs.id, slot = 8, opt = "qolMountArmor" },         -- Mithril Spurs (boots)
}
local BIND_NONE = (Enum and Enum.ItemBind and Enum.ItemBind.None) or 0
local BLOCK_FRAMES = { "MerchantFrame", "MailFrame", "TradeFrame", "BankFrame", "BankPanel", "LootFrame", "GuildBankFrame" }

local function equipped(slot) return ns.S(GetInventoryItemLink, "player", slot) end
local function saved() ns.db.qolSaved = ns.db.qolSaved or {} return ns.db.qolSaved end
local function nameOf(link) return type(link) == "string" and (link:match("%[(.-)%]") or link) or "nothing" end
local function sameItem(a, b) return a and b and idOf(a) == idOf(b) and (enchOf(a) or 0) == (enchOf(b) or 0) end

Q.debug = false
Q.lastLog = {}
local warned = {}
local function log(msg)
  table.insert(Q.lastLog, date("%H:%M:%S") .. " " .. msg)
  while #Q.lastLog > 12 do table.remove(Q.lastLog, 1) end
  if Q.debug then ns.Print("|cff8FB8E8QoL|r " .. msg) end
end
local function warnOnce(key, msg)
  if warned[key] then return end
  warned[key] = true
  ns.Print(msg)
  log(msg)
end

local function inZones(list)
  if not list then return true end
  local here = {}
  for _, n in ipairs({ ns.S(GetRealZoneText), ns.S(GetZoneText), ns.S(GetSubZoneText) }) do
    if type(n) == "string" and n ~= "" then here[n:lower()] = true end
  end
  for _, z in ipairs(list) do if here[z:lower()] then return true end end
  return false
end

local function matches(rule, link)
  if not link then return false end
  if rule.item then return idOf(link) == rule.item end
  return enchOf(link) == rule.ench
end

-- every bag copy of a rule's item: { bag, slot, link, bound }
local function bagCopies(rule)
  local list = {}
  bagSlots(function(bag, slot)
    local t = slotInfo(bag, slot)
    if t and t.hyperlink and matches(rule, t.hyperlink) then
      list[#list + 1] = { bag = bag, slot = slot, link = t.hyperlink, bound = t.isBound, locked = t.isLocked }
    end
  end)
  return list
end

-- may an addon equip this copy? Unbound Bind-on-Equip items need you to equip them once by hand
local function canEquip(copy)
  if copy.bound then return true end
  local bind = select(14, itemInfo(copy.link))
  if bind == nil then return true end -- not cached yet; try, the game says no if it must
  return bind == BIND_NONE
end

local function blocker()
  if Q.blocked then return "blocked" end
  if fullCombat() then return "combat" end
  if ns.S(UnitIsDeadOrGhost, "player") then return "dead" end
  if ns.S(UnitOnTaxi, "player") then return "taxi" end
  if (ns.S(UnitCastingInfo, "player")) or (ns.S(UnitChannelInfo, "player")) then return "casting" end
  if GetCursorInfo and GetCursorInfo() then return "cursor" end
  for _, n in ipairs(BLOCK_FRAMES) do
    local f = _G[n]
    if f and f.IsVisible and f:IsVisible() then return "window" end
  end
end

-- what should be on right now? { [slot] = { rule, copy } }
function Q:Plan(mounted)
  local plan = {}
  if not mounted then return plan end
  local tslot = (S().qolTrinketSlot == 13) and 13 or 14
  for _, r in ipairs(Q.RIDE) do
    local slot = r.slot == 0 and tslot or r.slot
    if not plan[slot] and (not r.opt or on(r.opt)) and inZones(r.zones) then
      -- already worn in the other trinket slot counts as done
      local worn
      for _, s in ipairs(r.slot == 0 and { 13, 14 } or { slot }) do
        if matches(r, equipped(s)) then worn = s end
      end
      if worn then
        plan[worn] = { rule = r, worn = true }
      else
        local usable, unbound
        for _, c in ipairs(bagCopies(r)) do
          if canEquip(c) then usable = usable or c else unbound = unbound or c end
        end
        if usable then plan[slot] = { rule = r, copy = usable }
        elseif unbound then
          warnOnce("bind:" .. r.key, "Chillan QoL: " .. unbound.link .. " isn't soulbound yet, so the game won't let an addon put it on. Equip it once by hand – after that it swaps automatically.")
        end
      end
    end
  end
  return plan
end

-- flights: swaps sent to the game, waiting for PLAYER_EQUIPMENT_CHANGED
local flights = {}
local function startFlight(slot, want, kind)
  flights[slot] = { want = want, kind = kind, at = GetTime() }
end

local function sendEquip(copy, slot)
  if not Q.useCursor then
    local ok, err = equipByName(copy.link, slot)
    if ok == false then log("equip error: " .. tostring(err)) end
    return true
  end
  local pick = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
  if not pick or not EquipCursorItem then return false end
  pcall(pick, copy.bag, copy.slot)
  if not (CursorHasItem and CursorHasItem()) then return false end
  pcall(EquipCursorItem, slot)
  return true
end

local failures = {}
local function fail(slot, what)
  failures[slot] = (failures[slot] or 0) + 1
  log("swap in slot " .. slot .. " didn't happen (" .. failures[slot] .. ")")
  if failures[slot] == 2 and not Q.useCursor then
    Q.useCursor = true
    log("switching to pick-up-and-place swaps")
  elseif failures[slot] >= 4 then
    warnOnce("fail:" .. slot, "Chillan QoL: couldn't swap " .. nameOf(what) .. ". Type /chill qol test and send a screenshot.")
  end
end

local function checkFlights()
  for slot, f in pairs(flights) do
    local cur = equipped(slot)
    local done = (f.want == false and cur == nil) or (f.want and sameItem(cur, f.want))
    if done then
      flights[slot] = nil
      failures[slot] = nil
      log("ok: slot " .. slot .. " now " .. nameOf(cur))
    elseif GetTime() - f.at > 1.5 then
      flights[slot] = nil
      if CursorHasItem and CursorHasItem() and ClearCursor then ClearCursor() end
      fail(slot, f.want)
    end
  end
end

local function freeBagSlot()
  return bagSlots(function(bag, slot)
    if bag ~= 5 and not slotInfo(bag, slot) then return { bag, slot } end
  end)
end

function Q:MountTick()
  checkFlights()
  if next(flights) then return end
  local sv = saved()
  if not on("qolMount") then
    if next(sv) and not blocker() then Q:RestoreAll() end
    return
  end
  local why = blocker()
  if why then Q.waiting = why return end
  Q.waiting = nil
  local mounted = (ns.S(IsMounted) and not ns.S(UnitOnTaxi, "player")) and true or false
  if mounted ~= Q.wasMounted then
    log(mounted and "mounted" or "dismounted")
    Q.wasMounted = mounted
    if mounted and on("qolMountMsg") then Q.sayOn = true end
  end
  local plan = Q:Plan(mounted)

  -- put on what's planned
  for slot, p in pairs(plan) do
    if not p.worn and p.copy and not p.copy.locked then
      if sv[slot] == nil then
        local cur = equipped(slot)
        local curIsSpeed = false
        for _, r in ipairs(Q.RIDE) do if matches(r, cur) then curIsSpeed = true end end
        sv[slot] = (cur and not curIsSpeed) and cur or false
      end
      if sendEquip(p.copy, slot) then
        log("putting on " .. nameOf(p.copy.link) .. " (slot " .. slot .. ")")
        startFlight(slot, p.copy.link, "equip")
        if Q.sayOn then Q.sayOn = nil ns.Print("Riding gear on.") end
        return -- one swap at a time, the next tick does the next
      else
        fail(slot, p.copy.link)
      end
    end
  end

  -- give back slots we took that are no longer planned
  for slot in pairs(sv) do
    if not plan[slot] then
      Q:RestoreSlot(slot)
      if on("qolMountMsg") and not next(saved()) then ns.Print("Your own gear is back on.") end
      return
    end
  end
end

function Q:RestoreSlot(slot)
  local sv = saved()
  local want = sv[slot]
  local cur = equipped(slot)
  if want == nil then return end
  if want == false then
    -- slot was empty: take the speed item off into a free bag slot
    if not cur then sv[slot] = nil return end
    local free = freeBagSlot()
    if not free or not PickupInventoryItem then
      warnOnce("bagsfull", "Chillan QoL: bags are full, so " .. nameOf(cur) .. " stays on until a bag slot is free.")
      return
    end
    pcall(PickupInventoryItem, slot)
    local pick = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
    if CursorHasItem and CursorHasItem() and pick then pcall(pick, free[1], free[2]) end
    sv[slot] = nil
    startFlight(slot, false, "restore")
    return
  end
  if sameItem(cur, want) then sv[slot] = nil return end
  local copy
  bagSlots(function(bag, s)
    local l = GetSlotLink(bag, s)
    if l and sameItem(l, want) then copy = { bag = bag, slot = s, link = l } return true end
  end)
  if not copy then
    warnOnce("gone:" .. slot, "Chillan QoL: " .. nameOf(want) .. " isn't in your bags any more, so the speed item stays on.")
    sv[slot] = nil
    return
  end
  if sendEquip(copy, slot) then
    log("putting back " .. nameOf(want) .. " (slot " .. slot .. ")")
    sv[slot] = nil
    startFlight(slot, want, "restore")
  else
    fail(slot, want)
  end
end
function Q:RestoreAll()
  for slot in pairs(saved()) do
    if not next(flights) then Q:RestoreSlot(slot) end
  end
end

-- the game refused one of our calls: say what, and switch method
function Q:OnBlocked(addon, func)
  if addon ~= ADDON then return end
  func = tostring(func or "?"):gsub("%(%)$", "")
  local short = func:match("([%w_]+)$") or func
  wipe(flights)
  if CursorHasItem and CursorHasItem() and ClearCursor then ClearCursor() end
  if short == "EquipItemByName" and not Q.useCursor then
    Q.useCursor = true
    warnOnce("blk:" .. func, "Chillan QoL: the game blocked " .. func .. "() – switching to another way of swapping.")
  elseif short == "EquipItemByName" or short == "PickupContainerItem" or short == "EquipCursorItem" then
    Q.blocked = func
    warnOnce("blocked", "Chillan QoL: the game is blocking addons from swapping gear (" .. func .. "), so the mount swap is paused until /reload.")
  end
end

-- /chill qol test: what the mount swap sees right now, plus the last steps it took
function Q:Test()
  local slot = (S().qolTrinketSlot == 13) and 13 or 14
  ns.Print(string.format("QoL mount: switch %s · mounted %s · waiting for: %s · trinket slot %d · method: %s",
    on("qolMount") and "on" or "OFF", tostring(ns.S(IsMounted) and true or false), blocker() or "nothing",
    slot, Q.blocked and "BLOCKED" or (Q.useCursor and "pick up + place" or "equip by name")))
  local any = false
  for _, r in ipairs(Q.RIDE) do
    local worn
    for _, s in ipairs(r.slot == 0 and { 13, 14 } or { r.slot }) do if matches(r, equipped(s)) then worn = s end end
    local copies = bagCopies(r)
    if worn or #copies > 0 then
      any = true
      local c = copies[1]
      local state = worn and ("worn (slot " .. worn .. ")") or (canEquip(c) and "in bags, ok" or "|cffF2777Ain bags, NOT soulbound – equip it once by hand|r")
      local name = nameOf((worn and equipped(worn)) or c.link)
      ns.Print("  " .. name .. ": " .. state .. (r.zones and (" · only in " .. table.concat(r.zones, ", ")) or "")
        .. ((r.opt and not on(r.opt)) and " · switched off" or ""))
    end
  end
  if not any then ns.Print("  no speed items found (Carrot on a Stick, Desert Rose, Wintersaber gloves, Riding Skill gloves, Mithril Spurs boots)") end
  for s2, v in pairs(saved()) do ns.Print("  will give back: " .. (v and nameOf(v) or "empty slot") .. " -> slot " .. s2) end
  if #Q.lastLog == 0 then ns.Print("  nothing tried yet – mount up and run this again")
  else for _, l in ipairs(Q.lastLog) do ns.Print("  " .. l) end end
end
function Q:Slash(rest)
  rest = (rest or ""):lower()
  if rest == "test" then Q:Test()
  elseif rest == "debug" then Q.debug = not Q.debug ns.Print("QoL debug " .. (Q.debug and "on – every swap step prints in chat." or "off."))
  elseif rest == "reset" then Q.blocked, Q.useCursor = nil, nil wipe(warned) wipe(failures) ns.Print("QoL mount swap reset.")
  else ns.Window:Toggle("qol") end
end

-- what the QoL tab shows under the switch
function Q:MountGearSummary()
  local parts, warn = {}, false
  for _, r in ipairs(Q.RIDE) do
    local worn = false
    for _, s in ipairs(r.slot == 0 and { 13, 14 } or { r.slot }) do if matches(r, equipped(s)) then worn = equipped(s) end end
    local c = bagCopies(r)[1]
    if worn or c then
      local n = nameOf(worn or c.link)
      if not worn and not canEquip(c) then n = n .. " (equip once by hand)" warn = true end
      parts[#parts + 1] = n
    end
  end
  if #parts == 0 then return "No speed gear found in your bags yet." end
  return "Found: " .. table.concat(parts, ", ")
end
---------------------------------------------------------------------------
-- Vendor: repair and sell junk (hold Shift when you open the vendor to skip)
---------------------------------------------------------------------------
local selling
function Q:OnMerchant()
  if IsShiftKeyDown() then return end
  if on("qolRepair") and ns.S(CanMerchantRepair) then
    local cost, can = ns.S(GetRepairAllCost)
    if cost and cost > 0 and can then
      local usedGuild = false
      if on("qolGuildRepair") and ns.S(IsInGuild) and ns.S(CanGuildBankRepair) then
        local ok = pcall(RepairAllItems, true)
        local left = ns.S(GetRepairAllCost) or 0
        usedGuild = ok and left == 0
      end
      if not usedGuild then
        local left = ns.S(GetRepairAllCost) or cost
        if left > 0 and (ns.S(GetMoney) or 0) >= left then pcall(RepairAllItems) end
      end
      C_Timer.After(0.3, function()
        local still = ns.S(GetRepairAllCost) or 0
        if still == 0 then if on("qolRepairMsg") then ns.Print("Repaired for " .. money(cost) .. (usedGuild and " (guild bank)" or "") .. ".") end
        else ns.Print("Not enough gold to repair everything (" .. money(still) .. ").") end
      end)
    end
  end
  if on("qolJunk") and not selling then
    local list, total = {}, 0
    bagSlots(function(bag, slot)
      local t = slotInfo(bag, slot)
      if t and t.quality == 0 and not t.hasNoValue and not t.isLocked and t.hyperlink then
        local price = select(11, itemInfo(t.hyperlink)) or 0
        if price > 0 then
          list[#list + 1] = { bag, slot }
          total = total + price * (t.stackCount or 1)
        end
      end
    end)
    if #list == 0 then return end
    selling = true
    local i = 0
    local function step()
      if not (MerchantFrame and MerchantFrame:IsShown()) then selling = nil return end
      i = i + 1
      local s = list[i]
      if not s then
        selling = nil
        if on("qolJunkMsg") then ns.Print("Sold " .. #list .. " junk item" .. (#list == 1 and "" or "s") .. " for " .. money(total) .. ".") end
        return
      end
      pcall(UseSlot, s[1], s[2])
      C_Timer.After(0.12, step)
    end
    step()
  end
end

---------------------------------------------------------------------------
-- Fast loot
---------------------------------------------------------------------------
local lastLoot = 0
function Q:OnLootReady()
  if not on("qolFastLoot") then return end
  local auto = GetCVarBool and GetCVarBool("autoLootDefault")
  local mod = IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE")
  if auto == mod then return end
  if GetTime() - lastLoot < 0.3 then return end
  lastLoot = GetTime()
  local n = ns.S(GetNumLootItems) or 0
  for i = n, 1, -1 do pcall(LootSlot, i) end
end

---------------------------------------------------------------------------
-- Questing: auto accept and turn in (hold Shift to talk normally)
---------------------------------------------------------------------------
local function questSkip() return not on("qolAutoQuest") or IsShiftKeyDown() end

function Q:OnQuestDetail()
  if questSkip() then return end
  if QuestGetAutoAccept and ns.S(QuestGetAutoAccept) then
    if AcknowledgeAutoAcceptQuest then pcall(AcknowledgeAutoAcceptQuest) end
    return
  end
  pcall(AcceptQuest)
end

-- never hand in repeatable item turn-ins (cloth, tokens) on your behalf
local function safeToComplete()
  local items = ns.S(GetNumQuestItems) or 0
  if items == 0 then return true end
  local qid = GetQuestID and ns.S(GetQuestID)
  if qid and qid > 0 and C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
    return ns.S(C_QuestLog.GetLogIndexForQuestID, qid) ~= nil
  end
  return false
end

function Q:OnQuestProgress()
  if questSkip() or not on("qolQuestTurnIn") then return end
  if ns.S(IsQuestCompletable) and safeToComplete() then pcall(CompleteQuest) end
end

function Q:OnQuestComplete()
  if questSkip() or not on("qolQuestTurnIn") then return end
  local n = ns.S(GetNumQuestChoices) or 0
  if n > 1 then return end -- you pick the reward
  pcall(GetQuestReward, n)
end

function Q:OnGossip()
  if questSkip() or not C_GossipInfo or not on("qolQuestGossip") then return end
  local active = ns.S(C_GossipInfo.GetActiveQuests) or {}
  for _, q in ipairs(active) do
    if q.isComplete and q.questID then return pcall(C_GossipInfo.SelectActiveQuest, q.questID) end
  end
  local avail = ns.S(C_GossipInfo.GetAvailableQuests) or {}
  for _, q in ipairs(avail) do
    if q.questID and not q.repeatable then return pcall(C_GossipInfo.SelectAvailableQuest, q.questID) end
  end
end

function Q:OnQuestGreeting()
  if questSkip() or not on("qolQuestGossip") then return end
  for i = 1, (ns.S(GetNumActiveQuests) or 0) do
    local _, done = ns.S(GetActiveTitle, i)
    if done then return pcall(SelectActiveQuest, i) end
  end
  if (ns.S(GetNumAvailableQuests) or 0) > 0 then pcall(SelectAvailableQuest, 1) end
end

---------------------------------------------------------------------------
-- Skip cutscenes you've already seen
---------------------------------------------------------------------------
local function seen() ns.db.qolSeen = ns.db.qolSeen or {} return ns.db.qolSeen end
function Q:OnMovie(movieID)
  if not movieID or secret(movieID) then return end
  local key = "m" .. tostring(movieID)
  if on("qolSkipCine") and seen()[key] and not IsShiftKeyDown() then
    C_Timer.After(0, function()
      if MovieFrame and MovieFrame.StopMovie then pcall(MovieFrame.StopMovie, MovieFrame)
      elseif GameMovieFinished then pcall(GameMovieFinished) end
    end)
    ns.Print("Skipped a cutscene you've seen (hold Shift next time to watch it).")
  end
  seen()[key] = true
end
function Q:OnCinematic()
  local zone = (ns.S(GetRealZoneText) or "?") .. "/" .. (ns.S(GetSubZoneText) or "")
  local key = "c" .. zone
  if on("qolSkipCine") and seen()[key] and not IsShiftKeyDown() then
    C_Timer.After(0.1, function()
      if CinematicFrame_CancelCinematic then pcall(CinematicFrame_CancelCinematic)
      elseif StopCinematic then pcall(StopCinematic) end
    end)
  end
  seen()[key] = true
end

---------------------------------------------------------------------------
-- XP bar text: % done, rested, and about how many quests to level
---------------------------------------------------------------------------
local xpText
local function xpBar()
  return (MainStatusTrackingBarContainer) or (StatusTrackingBarManager) or (MainMenuExpBar)
end
function Q:QuestXP(xp)
  if not xp or secret(xp) or xp <= 0 then return end
  local h = ns.db.qolQuestXP or {}
  table.insert(h, xp)
  while #h > 10 do table.remove(h, 1) end
  ns.db.qolQuestXP = h
  Q:UpdateXP()
end
function Q:UpdateXP()
  local bar = xpBar()
  if not on("qolXPText") or not bar then if xpText then xpText:Hide() end return end
  local max = ns.S(UnitXPMax, "player") or 0
  local cur = ns.S(UnitXP, "player") or 0
  local lvl = ns.S(UnitLevel, "player")
  if max <= 0 or (lvl and GetMaxPlayerLevel and lvl >= GetMaxPlayerLevel()) then if xpText then xpText:Hide() end return end
  if not xpText then
    local holder = CreateFrame("Frame", nil, bar)
    holder:SetAllPoints(bar)
    holder:SetFrameLevel((bar:GetFrameLevel() or 1) + 20)
    xpText = holder:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    xpText:SetPoint("CENTER", holder, "CENTER", 0, 1)
  end
  local parts = { string.format("%.1f%%", cur / max * 100) }
  local rested = ns.S(GetXPExhaustion)
  if on("qolXPRested") and rested and rested > 0 then parts[#parts + 1] = string.format("rested %d%%", math.floor(rested / max * 100 + 0.5)) end
  local h = ns.db.qolQuestXP or {}
  if on("qolXPQuests") and #h >= 3 then
    local sum = 0
    for _, v in ipairs(h) do sum = sum + v end
    local avg = sum / #h
    if avg > 0 then parts[#parts + 1] = "~" .. math.ceil((max - cur) / avg) .. " quests to go" end
  end
  xpText:SetText(table.concat(parts, "  ·  "))
  xpText:Show()
  xpText:GetParent():Show()
end

---------------------------------------------------------------------------
-- Annoyances
---------------------------------------------------------------------------
function Q:OnDuel(name)
  if not on("qolNoDuels") or (on("qolDuelsGang") and Q.IsGangChar(name)) then return end
  pcall(CancelDuel)
  if StaticPopup_Hide then StaticPopup_Hide("DUEL_REQUESTED") end
end
function Q:OnGuildInvite(inviter)
  if not on("qolNoGuildInv") or (on("qolGuildGang") and Q.IsGangChar(inviter)) then return end
  pcall(DeclineGuild)
  if StaticPopup_Hide then StaticPopup_Hide("GUILD_INVITE") end
end
function Q:OnPetition()
  if not on("qolNoGuildInv") or not GetPetitionInfo then return end
  local _, _, _, _, originator, isOriginator = ns.S(GetPetitionInfo)
  if isOriginator or not originator or (on("qolGuildGang") and Q.IsGangChar(originator)) then return end
  pcall(ClosePetition)
end
function Q:OnSummon()
  if not on("qolSummon") or fullCombat() then return end
  C_Timer.After(0.5, function()
    if fullCombat() then return end
    if C_SummonInfo and C_SummonInfo.ConfirmSummon then pcall(C_SummonInfo.ConfirmSummon)
    elseif ConfirmSummon then pcall(ConfirmSummon) end
    if StaticPopup_Hide then StaticPopup_Hide("CONFIRM_SUMMON") end
  end)
end
function Q:OnRes(name)
  if not on("qolRes") then return end
  -- a res during a boss fight is the healer's call, not ours
  if on("qolResBoss") and ns.S(IsEncounterInProgress) then return end
  C_Timer.After(0.3, function()
    pcall(AcceptResurrect)
    if StaticPopup_Hide then
      StaticPopup_Hide("RESURRECT") StaticPopup_Hide("RESURRECT_NO_SICKNESS") StaticPopup_Hide("RESURRECT_NO_TIMER")
    end
  end)
end

-- red error text: keep the useful ones, drop the spam
local SPAM_KEYS = {
  "ERR_OUT_OF_RAGE", "ERR_OUT_OF_ENERGY", "ERR_OUT_OF_MANA", "ERR_OUT_OF_FOCUS", "ERR_OUT_OF_RUNIC_POWER",
  "ERR_ABILITY_COOLDOWN", "ERR_SPELL_COOLDOWN", "ERR_ITEM_COOLDOWN", "ERR_NO_ATTACK_TARGET", "ERR_GENERIC_NO_TARGET",
  "ERR_OUT_OF_RANGE", "ERR_SPELL_OUT_OF_RANGE", "ERR_BADATTACKFACING", "ERR_BADATTACKPOS", "ERR_INVALID_ATTACK_TARGET",
  "SPELL_FAILED_NO_COMBO_POINTS", "SPELL_FAILED_TARGETS_DEAD", "SPELL_FAILED_BAD_TARGETS", "SPELL_FAILED_OUT_OF_RANGE",
  "SPELL_FAILED_SPELL_IN_PROGRESS", "SPELL_FAILED_UNIT_NOT_INFRONT", "SPELL_FAILED_NOT_READY", "SPELL_FAILED_MOVING",
  "SPELL_FAILED_NOT_BEHIND", "SPELL_FAILED_CASTER_AURASTATE", "SPELL_FAILED_TARGET_AURASTATE", "ERR_NOT_WHILE_MOVING",
  "SPELL_FAILED_NO_ENDURANCE", "OUT_OF_ENERGY", "OUT_OF_RAGE", "OUT_OF_MANA",
}
local spam
local function buildSpam()
  spam = {}
  for _, k in ipairs(SPAM_KEYS) do
    local v = _G[k]
    if type(v) == "string" and v ~= "" then spam[v] = true end
  end
end
local errHooked, errFrame
function Q:ApplyErrors()
  if not UIErrorsFrame then return end
  if on("qolNoErrors") then
    if not errHooked then
      buildSpam()
      errHooked = true
      pcall(UIErrorsFrame.UnregisterEvent, UIErrorsFrame, "UI_ERROR_MESSAGE")
      errFrame = errFrame or CreateFrame("Frame")
      errFrame:RegisterEvent("UI_ERROR_MESSAGE")
      errFrame:SetScript("OnEvent", function(_, _, errType, msg)
        if type(msg) == "string" and not secret(msg) and spam[msg] then return end
        if UIErrorsFrame.TryDisplayMessage then
          pcall(UIErrorsFrame.TryDisplayMessage, UIErrorsFrame, errType, msg, 1, 0.1, 0.1)
        else
          pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, msg, 1, 0.1, 0.1, 1)
        end
      end)
    end
  elseif errHooked then
    errHooked = false
    if errFrame then errFrame:UnregisterAllEvents() end
    pcall(UIErrorsFrame.RegisterEvent, UIErrorsFrame, "UI_ERROR_MESSAGE")
  end
end

function Q:ApplyZoom()
  if not SetCVar then return end
  if on("qolMaxZoom") then
    if not ns.db.qolZoomOld then ns.db.qolZoomOld = (GetCVar and GetCVar("cameraDistanceMaxZoomFactor")) or "1.9" end
    pcall(SetCVar, "cameraDistanceMaxZoomFactor", "2.6")
  elseif ns.db.qolZoomOld then
    pcall(SetCVar, "cameraDistanceMaxZoomFactor", ns.db.qolZoomOld)
    ns.db.qolZoomOld = nil
  end
end

---------------------------------------------------------------------------
-- Info: red tint on bag items you can't use
---------------------------------------------------------------------------
local usableCache = {}
local function cannotUse(bag, slot, link)
  if usableCache[link] ~= nil then return usableCache[link] end
  local bad = false
  if C_TooltipInfo and C_TooltipInfo.GetBagItem then
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if ok and data and data.lines then
      for i = 2, #data.lines do
        for _, side in ipairs({ "leftColor", "rightColor" }) do
          local c = data.lines[i][side]
          if c and c.r and not secret(c.r) and c.r > 0.95 and c.g < 0.2 and c.b < 0.2 then bad = true end
        end
      end
    else
      return false
    end
  else
    return false
  end
  usableCache[link] = bad
  return bad
end

local function tintButton(btn)
  if not btn or not btn.GetID then return end
  local bag = (btn.GetBagID and btn:GetBagID()) or (btn:GetParent() and btn:GetParent().GetID and btn:GetParent():GetID())
  local slot = btn:GetID()
  if not bag or not slot then return end
  local icon = btn.icon or btn.Icon or (btn.GetName and btn:GetName() and _G[btn:GetName() .. "IconTexture"])
  if not icon or not icon.SetVertexColor then return end
  local link = GetSlotLink and ns.S(GetSlotLink, bag, slot)
  if on("qolTint") and link and cannotUse(bag, slot, link) then
    icon:SetVertexColor(1, 0.25, 0.25)
    btn.chillTint = true
  elseif btn.chillTint then
    icon:SetVertexColor(1, 1, 1)
    btn.chillTint = nil
  end
end

function Q:TintBags()
  local frames = {}
  if ContainerFrameCombinedBags then frames[#frames + 1] = ContainerFrameCombinedBags end
  for i = 1, (NUM_CONTAINER_FRAMES or 13) do
    local f = _G["ContainerFrame" .. i]
    if f then frames[#frames + 1] = f end
  end
  for _, f in ipairs(frames) do
    if f:IsShown() then
      if f.EnumerateValidItems then
        -- the iterator needs its state values too, so call it in the for line itself
        pcall(function()
          for _, btn in f:EnumerateValidItems() do pcall(tintButton, btn) end
        end)
      else
        local name = f:GetName()
        for s = 1, 40 do
          local btn = _G[name .. "Item" .. s]
          if not btn then break end
          if btn:IsShown() then pcall(tintButton, btn) end
        end
      end
    end
  end
end
local tintQueued
function Q:QueueTint()
  if tintQueued then return end
  tintQueued = true
  C_Timer.After(0.05, function() tintQueued = nil Q:TintBags() end)
end

---------------------------------------------------------------------------
-- Info: flight timer (learns each route the first time you fly it)
---------------------------------------------------------------------------
local flight
local function flights() ns.db.qolFlights = ns.db.qolFlights or {} return ns.db.qolFlights end
local flightBar
local function fmtTime(s)
  s = math.max(0, math.floor(s + 0.5))
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end
local function showFlightBar()
  if not flightBar then
    local UI, C = ns.UI, ns.C
    local f = CreateFrame("Frame", "ChillanFlightTimer", UIParent)
    f:SetSize(220, 40)
    f:SetPoint("TOP", UIParent, "TOP", 0, -120)
    f:SetFrameStrata("MEDIUM")
    f.bg = UI.OverlayPanel and UI.OverlayPanel(f, C.window, C.line, true)
    if f.bg then f.bg:SetAllPoints() end
    f.title = UI.Text(f, 12, "semi", C.text)
    f.title:SetPoint("TOPLEFT", 10, -6)
    f.title:SetPoint("RIGHT", -10, 0)
    f.title:SetJustifyH("LEFT")
    f.bar = f:CreateTexture(nil, "ARTWORK")
    f.bar:SetColorTexture(ns.hex(C.accent))
    f.bar:SetPoint("BOTTOMLEFT", 10, 7)
    f.bar:SetHeight(4)
    f.track = f:CreateTexture(nil, "BORDER")
    f.track:SetColorTexture(1, 1, 1, 0.08)
    f.track:SetPoint("BOTTOMLEFT", 10, 7)
    f.track:SetPoint("BOTTOMRIGHT", -10, 7)
    f.track:SetHeight(4)
    if UI.Movable then UI.Movable(f, "flighttimer") end
    f:SetScript("OnUpdate", function(self, el)
      self.acc = (self.acc or 0) + el
      if self.acc < 0.25 then return end
      self.acc = 0
      if not flight then self:Hide() return end
      local spent = GetTime() - flight.start
      local known = flights()[flight.key]
      local w = self.track:GetWidth()
      if known and known > 0 then
        self.title:SetText("To " .. flight.dest .. "  ·  " .. fmtTime(known - spent) .. " left")
        self.bar:SetWidth(math.max(1, math.min(1, spent / known) * w))
      else
        self.title:SetText("To " .. flight.dest .. "  ·  " .. fmtTime(spent) .. " (learning this route)")
        self.bar:SetWidth(1)
      end
    end)
    flightBar = f
  end
  flightBar:Show()
end

function Q:OnTakeTaxi(index)
  if not index then return end
  local dest = ns.S(TaxiNodeName, index)
  local origin
  for i = 1, (ns.S(NumTaxiNodes) or 0) do
    if ns.S(TaxiNodeGetType, i) == "CURRENT" then origin = ns.S(TaxiNodeName, i) break end
  end
  if not dest then return end
  flight = { dest = ns.ShortName(dest:match("^([^,]+)") or dest), key = (origin or "?") .. ">" .. dest, start = GetTime(), pending = true }
end
function Q:FlightTick()
  if not flight then return end
  local onTaxi = ns.S(UnitOnTaxi, "player")
  if onTaxi then
    if flight.pending then
      flight.pending = nil
      flight.start = GetTime()
      if on("qolFlightTimer") then showFlightBar() end
    end
  elseif not flight.pending then
    local dur = GetTime() - flight.start
    if dur > 10 then flights()[flight.key] = math.floor(dur) end
    flight = nil
    if flightBar then flightBar:Hide() end
  elseif GetTime() - flight.start > 8 then
    flight = nil -- never took off
  end
end

---------------------------------------------------------------------------
-- Toggles: the QoL tab calls this after a switch changes
---------------------------------------------------------------------------
function Q:Apply()
  Q:ApplyErrors()
  Q:ApplyZoom()
  Q:UpdateXP()
  Q:QueueTint()
  if not on("qolFlightTimer") and flightBar then flightBar:Hide() end
end

function Q:Start()
  ns:On("MERCHANT_SHOW", function() C_Timer.After(0.1, function() Q:OnMerchant() end) end)
  ns:On("MERCHANT_CLOSED", function() selling = nil end)
  ns:On("LOOT_READY", function() Q:OnLootReady() end)
  ns:On("QUEST_DETAIL", function() Q:OnQuestDetail() end)
  ns:On("QUEST_PROGRESS", function() Q:OnQuestProgress() end)
  ns:On("QUEST_COMPLETE", function() Q:OnQuestComplete() end)
  ns:On("QUEST_GREETING", function() Q:OnQuestGreeting() end)
  ns:On("GOSSIP_SHOW", function() Q:OnGossip() end)
  ns:On("QUEST_TURNED_IN", function(_, xp) Q:QuestXP(xp) end)
  ns:On("PLAY_MOVIE", function(id) Q:OnMovie(id) end)
  ns:On("CINEMATIC_START", function() Q:OnCinematic() end)
  ns:On("PLAYER_XP_UPDATE", function() Q:UpdateXP() end)
  ns:On("UPDATE_EXHAUSTION", function() Q:UpdateXP() end)
  ns:On("PLAYER_LEVEL_UP", function() usableCache = {} C_Timer.After(1, function() Q:UpdateXP() Q:QueueTint() end) end)
  ns:On("DUEL_REQUESTED", function(name) Q:OnDuel(name) end)
  ns:On("GUILD_INVITE_REQUEST", function(name) Q:OnGuildInvite(name) end)
  ns:On("PETITION_SHOW", function() Q:OnPetition() end)
  ns:On("CONFIRM_SUMMON", function() Q:OnSummon() end)
  ns:On("RESURRECT_REQUEST", function(name) Q:OnRes(name) end)
  ns:On("BAG_UPDATE_DELAYED", function() Q:QueueTint() end)
  ns:On("PLAYER_EQUIPMENT_CHANGED", function() usableCache = {} Q:QueueTint() end)
  ns:On("PLAYER_REGEN_ENABLED", function() Q:MountTick() end)
  ns:On("PLAYER_MOUNT_DISPLAY_CHANGED", function() C_Timer.After(0.1, function() Q:MountTick() end) end)
  ns:On("PLAYER_EQUIPMENT_CHANGED", function() C_Timer.After(0, function() Q:MountTick() end) end)
  ns:On("ADDON_ACTION_BLOCKED", function(a, f) Q:OnBlocked(a, f) end)
  ns:On("ADDON_ACTION_FORBIDDEN", function(a, f) Q:OnBlocked(a, f) end)
  if TakeTaxiNode then hooksecurefunc("TakeTaxiNode", function(i) Q:OnTakeTaxi(i) end) end
  for i = 1, (NUM_CONTAINER_FRAMES or 13) do
    local f = _G["ContainerFrame" .. i]
    if f then f:HookScript("OnShow", function() Q:QueueTint() end) end
  end
  if ContainerFrameCombinedBags then ContainerFrameCombinedBags:HookScript("OnShow", function() Q:QueueTint() end) end
  C_Timer.NewTicker(0.25, function()
    local ok, err = pcall(Q.MountTick, Q)
    if not ok and ns.debug then ns.Print("QoL mount:", err) end
    pcall(Q.FlightTick, Q)
  end)
  C_Timer.After(2, function() Q:Apply() end)
end
