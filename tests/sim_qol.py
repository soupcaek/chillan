exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(3)
LA.execute('''
INV = { [13] = "|cff0070dd|Hitem:1111::::|h[Dmg Trinket A]|h|r", [14] = "|cff0070dd|Hitem:2222::::|h[Dmg Trinket B]|h|r",
        [8] = "|Hitem:3333::::|h[Boots]|h", [10] = "|Hitem:4444::::|h[Gloves]|h" }
BAGS = { [0] = { [1] = "|Hitem:11122::::|h[Carrot on a Stick]|h", [2] = "|Hitem:5555:464:::|h[Spur Boots]|h", [3] = "|Hitem:6666::::|h[Grey Junk]|h" } }
LOG = {}
MOUNTED, COMBAT = false, false
IsMounted = function() return MOUNTED end
InCombatLockdown = function() return COMBAT end
UnitAffectingCombat = function() return COMBAT end
UnitOnTaxi = function() return false end
IsSwimming = function() return false end
GetInventoryItemLink = function(_, s) return INV[s] end
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(b) return b == 0 and 4 or 0 end
C_Container.GetContainerItemLink = function(b, s) return BAGS[b] and BAGS[b][s] end
C_Container.GetContainerItemInfo = function(b, s) local l = BAGS[b] and BAGS[b][s]; if not l then return nil end
  return { hyperlink = l, quality = l:find("Junk") and 0 or 2, stackCount = 3, hasNoValue = false, isLocked = false } end
C_Container.UseContainerItem = function(b, s) table.insert(LOG, "sell " .. tostring(BAGS[b][s])); BAGS[b][s] = nil end
C_Item = C_Item or {}
C_Item.GetItemInfo = function(l) local id = tonumber(tostring(l):match("item:(%d+)")) ; if not id then return end
  local loc = (id == 5555 or id == 3333) and "INVTYPE_FEET" or "INVTYPE_TRINKET"
  return "Item" .. id, l, 2, 30, 1, "Armor", "Misc", 1, loc, 0, 125 end
local function findBag(link) for b, t in pairs(BAGS) do for s, l in pairs(t) do if l == link then return b, s end end end end
C_Item.EquipItemByName = function(link, slot)
  table.insert(LOG, "equip " .. link:match("%[(.-)%]") .. " ->" .. slot)
  local b, s = findBag(link); local old = INV[slot]
  if b then INV[slot] = link; BAGS[b][s] = old else
    for os, l in pairs(INV) do if l == link then INV[os], INV[slot] = old, link end end end
end
''')
nsA = LA.eval('ADDON_NS')
def tick():
    LA.execute('ADDON_NS.QoL:MountTick()'); run(2)
tick()
LA.execute('MOUNTED = true'); tick(); tick()
print("mounted:", LA.eval('INV[14]'), "|", LA.eval('INV[8]'))
LA.execute('MOUNTED = false; COMBAT = true'); tick()
print("dismount in combat (still carrot):", LA.eval('INV[14]'))
LA.execute('COMBAT = false'); tick()
print("after combat:", LA.eval('INV[14]'), "|", LA.eval('INV[8]'), "| saved left:", LA.eval('next(ADDON_NS.db.qolSaved) == nil'))
print("log:", LA.eval('table.concat(LOG, "; ")'))
# carrot already worn in slot 13 -> no swap
LA.execute('LOG = {}; INV[13] = "|Hitem:11122::::|h[Carrot on a Stick]|h"; BAGS[0][1] = nil; MOUNTED = true'); tick()
print("already worn, log:", LA.eval('table.concat(LOG, "; ")'))
LA.execute('MOUNTED = false'); tick()
# vendor
LA.execute('''LOG = {}; MerchantFrame = MerchantFrame or CreateFrame("Frame"); MerchantFrame.IsShown = function() return true end
CanMerchantRepair = function() return true end; REP = 1234; GetRepairAllCost = function() return REP, true end
IsInGuild = function() return false end; GetMoney = function() return 99999 end
RepairAllItems = function() table.insert(LOG, "repair"); REP = 0 end; IsShiftKeyDown = function() return false end
PRINTS = {}; local p = ADDON_NS.Print; ADDON_NS.Print = function(...) table.insert(PRINTS, table.concat({...}, " ")) end''')
LA.execute('ADDON_NS.QoL:OnMerchant()'); run(2)
print("vendor log:", LA.eval('table.concat(LOG, "; ")'), "| prints:", LA.eval('table.concat(PRINTS, " / ")'))
# quests: off by default
LA.execute('LOG = {}; AcceptQuest = function() table.insert(LOG, "accept") end'); LA.execute('ADDON_NS.QoL:OnQuestDetail()')
print("autoquest default off:", LA.eval('#LOG == 0'))
LA.execute('ADDON_NS.db.settings.qolAutoQuest = true; ADDON_NS.QoL:OnQuestDetail()')
LA.execute('''GetNumQuestItems = function() return 2 end; GetQuestID = function() return 77 end; C_QuestLog = C_QuestLog or {}
C_QuestLog.GetLogIndexForQuestID = function() return nil end; IsQuestCompletable = function() return true end
CompleteQuest = function() table.insert(LOG, "complete") end; ADDON_NS.QoL:OnQuestProgress()''')
LA.execute('GetNumQuestChoices = function() return 3 end; GetQuestReward = function() table.insert(LOG, "reward") end; ADDON_NS.QoL:OnQuestComplete()')
print("quest log (accept only, no repeatable turn-in, no multi reward):", LA.eval('table.concat(LOG, "; ")'))
# duel from gang vs stranger
LA.execute('LOG = {}; ADDON_NS.db.settings.qolNoDuels = true; CancelDuel = function() table.insert(LOG, "cancel") end')
LA.execute('ADDON_NS.QoL:OnDuel("Randomguy")')
print("duel stranger:", LA.eval('table.concat(LOG, ";")'))
# errors filter
LA.execute('ERR_OUT_OF_RAGE = "Not enough rage"; UIErrorsFrame = UIErrorsFrame or CreateFrame("Frame"); SHOWN = {}; UIErrorsFrame.AddMessage = function(_, m) table.insert(SHOWN, m) end; UIErrorsFrame.TryDisplayMessage = nil')
LA.execute('ADDON_NS.QoL:ApplyErrors()')
print("errors hooked:", LA.eval('ADDON_NS.QoL ~= nil'))
# equip API silently does nothing (like in game) -> fallback pick up / put down
LA.execute('''LOG = {}; INV[13] = "|cff0070dd|Hitem:1111::::|h[Dmg Trinket A]|h|r"; BAGS[0][1] = "|Hitem:11122::::|h[Carrot on a Stick]|h"
C_Item.EquipItemByName = function() table.insert(LOG, "noop-equip") end
CURSOR = nil
C_Container.PickupContainerItem = function(b, s) CURSOR = { b = b, s = s, link = BAGS[b][s] } end
PickupInventoryItem = function(slot) if CURSOR then local old = INV[slot]; INV[slot] = CURSOR.link; BAGS[CURSOR.b][CURSOR.s] = old; CURSOR = nil; table.insert(LOG, "pickup-swap " .. slot) end end
CursorHasItem = function() return CURSOR ~= nil end; ClearCursor = function() CURSOR = nil end
MOUNTED = true''')
tick(); tick()
print("fallback mounted slot14:", LA.eval('INV[14]'))
LA.execute('MOUNTED = false'); tick(); tick()
print("fallback dismount slot14:", LA.eval('INV[14]'), "| log:", LA.eval('table.concat(LOG, "; ")'))
LA.execute('ADDON_NS.QoL:Test()')
# tab
LA.execute('ADDON_NS.Window:Create(); ADDON_NS.Window.frame:Show(); ADDON_NS.Window:Select("qol")'); run(1)
print("tab built:", LA.eval('ADDON_NS.Window.tabs.qol ~= nil'))
LA.execute('ADDON_NS.QoL:UpdateXP(); ADDON_NS.QoL:TintBags(); ADDON_NS.QoL:OnTakeTaxi(1); ADDON_NS.QoL:FlightTick(); ADDON_NS.QoL:Apply()')
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:6])
