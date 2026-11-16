-- Chillan? – QoL: small helpers you switch on and off in the QoL tab
-- Mount gear (Carrot on a Stick & co), vendor (repair, sell junk), fast loot,
-- questing (auto accept / turn in, skip seen cutscenes, XP bar text),
-- annoyances (duels, guild invites, summons, res, error spam, camera zoom),
-- info (red tint on items you can't use, flight timer).
local ADDON, ns = ...
local Q = {}
ns.QoL = Q

local function S() return ns.db and ns.db.settings or {} end
local function on(key) return S()[key] and true or false end
local function secret(v) return ns.isSecret and ns.isSecret(v) end
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
  local ok, a, b, c, d, e, f2, g, h, i, j, k = pcall(f, x)
  if ok then return a, b, c, d, e, f2, g, h, i, j, k end
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

local function norm(name)
  if type(name) ~= "string" or secret(name) then return "" end
  return (ns.ShortName(name) or name):lower():gsub("[%s%-]", "")
end
function Q.IsGangChar(name)
  local short = norm(name)
  if short == "" then return false end
  for pid, p in pairs(ns.db.people or {}) do
    if pid ~= ns.pid then
      for key, c in pairs(p.chars or {}) do
        if norm((c and c.name) or key) == short then return true end
      end
    end
  end
  return false
end

local function money(c)
  if GetCoinTextureString then
    local ok, s = pcall(GetCoinTextureString, c)
    if ok and s then return s end
  end
  return string.format("%dg %ds %dc", math.floor(c / 10000), math.floor(c / 100) % 100, c % 100)
end

---------------------------------------------------------------------------
-- Mount gear: riding items on when you mount, your own gear back on dismount
---------------------------------------------------------------------------
-- best first; Riding Crop and Skybreaker Whip beat Carrot on a Stick
Q.RIDE_TRINKETS = { 25653, 32863, 11122 }
Q.FLIGHT_TRINKET = 32481 -- Charm of Swift Flight (druid flight form)
Q.ENCH_SPURS = 464       -- Mithril Spurs (boots)
Q.ENCH_RIDING = 930      -- Riding Skill (gloves)
-- swimming: Hydrocane (off hand), Azure Silk Belt, Deepdive Helmet
Q.SWIM = { { id = 9452, slot = 17 }, { id = 7052, slot = 6 }, { id = 10506, slot = 1 } }

local function equipped(slot) return ns.S(GetInventoryItemLink, "player", slot) end

-- where is the best item for slot? returns link or nil
local function findTrinket(ids)
  for _, want in ipairs(ids) do
    for _, s in ipairs({ 13, 14 }) do
      if idOf(equipped(s)) == want then return equipped(s), s end
    end
    local hit = bagSlots(function(bag, slot)
      local link = GetSlotLink and ns.S(GetSlotLink, bag, slot)
      if idOf(link) == want then return link end
    end)
    if hit then return hit end
  end
end
local function findEnchanted(equipLoc, ench)
  local cur = equipped(equipLoc == "INVTYPE_FEET" and 8 or 10)
  if enchOf(cur) == ench then return cur, true end
  return bagSlots(function(bag, slot)
    local link = GetSlotLink and ns.S(GetSlotLink, bag, slot)
    if link and enchOf(link) == ench then
      local _, _, _, _, _, _, _, _, loc = itemInfo(link)
      if loc == equipLoc then return link end
    end
  end)
end

local function saved() ns.db.qolSaved = ns.db.qolSaved or {} return ns.db.qolSaved end

Q.debug = false
Q.lastLog = {}
local function log(msg)
  table.insert(Q.lastLog, date("%H:%M:%S") .. " " .. msg)
  while #Q.lastLog > 12 do table.remove(Q.lastLog, 1) end
  if Q.debug then ns.Print("|cff8FB8E8QoL|r " .. msg) end
end
local function nameOf(link) return type(link) == "string" and (link:match("%[(.-)%]") or link) or "nothing" end
local function bagPos(link)
  local want, ench = idOf(link), enchOf(link)
  return bagSlots(function(bag, slot)
    local l = GetSlotLink(bag, slot)
    if l and idOf(l) == want and enchOf(l) == ench then return { bag, slot } end
  end)
end
local function isOn(slot, link)
  local cur = equipped(slot)
  return cur ~= nil and idOf(cur) == idOf(link) and enchOf(cur) == enchOf(link)
end

-- equip, check it worked, and fall back to pick up + put down (the ItemRack way)
local function doEquip(link, slot)
  local ok, err = equipByName(link, slot)
  log("equip " .. nameOf(link) .. " -> slot " .. slot .. (ok == false and (" (error: " .. tostring(err) .. ")") or ""))
  C_Timer.After(0.6, function()
    if isOn(slot, link) then log("ok: " .. nameOf(link) .. " is on") return end
    if fullCombat() then log("in combat – will retry after") return end
    local pos = bagPos(link)
    local pick = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
    if pos and pick and PickupInventoryItem then
      if ClearCursor then ClearCursor() end
      pcall(pick, pos[1], pos[2])
      pcall(PickupInventoryItem, slot)
      if CursorHasItem and CursorHasItem() and ClearCursor then ClearCursor() end
      log("fallback swap used for " .. nameOf(link))
      C_Timer.After(0.6, function()
        log(isOn(slot, link) and ("ok: " .. nameOf(link) .. " is on") or ("FAILED to put on " .. nameOf(link)))
      end)
    else
      log("FAILED: " .. nameOf(link) .. " not found in bags")
    end
  end)
end

-- put link into slot, remembering what was there (only once per ride)
local function swapIn(slot, link, tag)
  if not link or isOn(slot, link) then return false end
  local sv = saved()
  if not sv[slot] then sv[slot] = { link = equipped(slot) or false, tag = tag, put = link } end
  doEquip(link, slot)
  return true
end

-- put back what we took off, but only if the riding item is still the one there
local function restore(tag)
  local sv = saved()
  for slot, e in pairs(sv) do
    if e.tag == tag then
      local cur = equipped(slot)
      if not cur or idOf(cur) == idOf(e.put) then
        if e.link then doEquip(e.link, slot)
        elseif cur and PickupInventoryItem and PutItemInBackpack then
          pcall(PickupInventoryItem, slot)
          if CursorHasItem and CursorHasItem() then pcall(PutItemInBackpack) end
          log("took off " .. nameOf(cur))
        end
      end
      sv[slot] = nil
    end
  end
end

local function isFlightForm()
  local _, class = UnitClass("player")
  if class ~= "DRUID" then return false end
  local idx = GetShapeshiftForm and ns.S(GetShapeshiftForm)
  if not idx or idx == 0 then return false end
  local _, _, _, spellID = ns.S(GetShapeshiftFormInfo, idx)
  return spellID == 33943 or spellID == 40120
end

local mountState, swimSince, dryAt = nil, nil, nil
function Q:MountTick()
  if not on("qolMount") then return end
  if fullCombat() or (CursorHasItem and CursorHasItem()) or ns.S(UnitIsDeadOrGhost, "player") then return end
  if ns.S(UnitOnTaxi, "player") then return end
  local slot = (S().qolTrinketSlot == 13) and 13 or 14
  local mounted = ns.S(IsMounted) and true or false
  local flying = isFlightForm()
  local riding = mounted or flying
  if riding then
    if mountState ~= "ride" then
      mountState, Q.tries, Q.lastTry = "ride", 0, 0
      log("mounted" .. (flying and " (flight form)" or ""))
    end
    -- try (and retry a couple of times) until the riding gear is really on
    if Q.tries < 3 and GetTime() - Q.lastTry > 2 then
      local did = false
      local function trinket(ids)
        local link, worn = findTrinket(ids)
        if link and not worn and swapIn(slot, link, "ride") then did = true end
      end
      if flying then
        if on("qolDruidCharm") then trinket({ Q.FLIGHT_TRINKET }) end
      else
        trinket(Q.RIDE_TRINKETS)
        if on("qolMountArmor") then
          local boots, bw = findEnchanted("INVTYPE_FEET", Q.ENCH_SPURS)
          local gloves, gw = findEnchanted("INVTYPE_HAND", Q.ENCH_RIDING)
          if boots and not bw and swapIn(8, boots, "ride") then did = true end
          if gloves and not gw and swapIn(10, gloves, "ride") then did = true end
        end
      end
      if did then
        Q.tries, Q.lastTry = Q.tries + 1, GetTime()
        if on("qolMountMsg") and Q.tries == 1 then ns.Print("Riding gear on.") end
      end
    end
  elseif mountState == "ride" or next(saved()) then
    -- dismounted: give the gear back (also after a /reload while mounted)
    local any = false
    for _, e in pairs(saved()) do if e.tag == "ride" then any = true end end
    if mountState == "ride" then log("dismounted") end
    mountState = nil
    if any then
      restore("ride")
      if on("qolMountMsg") then ns.Print("Your own gear is back on.") end
    end
  end

  -- swimming gear (off while mounted)
  if on("qolSwim") and not riding then
    local swimming = ns.S(IsSwimming) and true or false
    if swimming then
      dryAt = nil
      swimSince = swimSince or GetTime()
      if GetTime() - swimSince > 1.5 then
        for _, w in ipairs(Q.SWIM) do
          local link = (idOf(equipped(w.slot)) == w.id) and equipped(w.slot) or bagSlots(function(bag, s)
            local l = GetSlotLink and ns.S(GetSlotLink, bag, s)
            if idOf(l) == w.id then return l end
          end)
          if link then swapIn(w.slot, link, "swim") end
        end
      end
    else
      swimSince = nil
      local any = false
      for _, e in pairs(saved()) do if e.tag == "swim" then any = true end end
      if any then
        dryAt = dryAt or GetTime()
        if GetTime() - dryAt > 2 then restore("swim") dryAt = nil end
      end
    end
  end
end

-- /chill qol test: what the mount swap sees right now, plus the last steps it took
function Q:Test()
  local slot = (S().qolTrinketSlot == 13) and 13 or 14
  local link, worn = findTrinket(Q.RIDE_TRINKETS)
  ns.Print(string.format("QoL mount: switch %s · mounted %s · combat %s · taxi %s · slot %d",
    on("qolMount") and "on" or "OFF", tostring(ns.S(IsMounted) and true or false), tostring(fullCombat()),
    tostring(ns.S(UnitOnTaxi, "player") and true or false), slot))
  ns.Print("  trinket found: " .. nameOf(link) .. (worn and (" (worn in slot " .. worn .. ")") or (link and " (in bags)" or "")))
  ns.Print("  in slot 13: " .. nameOf(equipped(13)) .. " · slot 14: " .. nameOf(equipped(14)))
  ns.Print("  equip API: " .. ((C_Item and C_Item.EquipItemByName) and "C_Item.EquipItemByName" or (EquipItemByName and "EquipItemByName" or "none")))
  for s2, e in pairs(saved()) do ns.Print("  waiting to give back: " .. nameOf(e.link) .. " -> slot " .. s2) end
  if #Q.lastLog == 0 then ns.Print("  no swaps tried yet – mount up and run this again")
  else for _, l in ipairs(Q.lastLog) do ns.Print("  " .. l) end end
end
function Q:Slash(rest)
  rest = (rest or ""):lower()
  if rest == "test" then Q:Test()
  elseif rest == "debug" then Q.debug = not Q.debug ns.Print("QoL debug " .. (Q.debug and "on – every swap step prints in chat." or "off."))
  else ns.Window:Toggle("qol") end
end

-- what the QoL tab shows next to the toggle
function Q:MountGearSummary()
  local parts = {}
  local t = findTrinket(Q.RIDE_TRINKETS)
  if t then parts[#parts + 1] = (itemInfo(t)) or "trinket" end
  if findEnchanted("INVTYPE_FEET", Q.ENCH_SPURS) then parts[#parts + 1] = "spurs boots" end
  if findEnchanted("INVTYPE_HAND", Q.ENCH_RIDING) then parts[#parts + 1] = "riding gloves" end
  if #parts == 0 then return "No riding gear found in your bags yet." end
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
        local ok, it = pcall(f.EnumerateValidItems, f)
        if ok and it then for _, btn in it do pcall(tintButton, btn) end end
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
  if not on("qolMount") then
    mountState = nil
    if not fullCombat() then restore("ride") restore("swim") end
  end
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
  if TakeTaxiNode then hooksecurefunc("TakeTaxiNode", function(i) Q:OnTakeTaxi(i) end) end
  for i = 1, (NUM_CONTAINER_FRAMES or 13) do
    local f = _G["ContainerFrame" .. i]
    if f then f:HookScript("OnShow", function() Q:QueueTint() end) end
  end
  if ContainerFrameCombinedBags then ContainerFrameCombinedBags:HookScript("OnShow", function() Q:QueueTint() end) end
  C_Timer.NewTicker(0.4, function()
    local ok, err = pcall(Q.MountTick, Q)
    if not ok and ns.debug then ns.Print("QoL mount:", err) end
    pcall(Q.FlightTick, Q)
  end)
  C_Timer.After(2, function() Q:Apply() end)
end
