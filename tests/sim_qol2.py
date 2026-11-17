exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(3)
LA.execute('''
INV = { [13] = "|cff0070dd|Hitem:1111::::|h[Dmg Trinket A]|h|r", [14] = "|cff0070dd|Hitem:2222::::|h[Dmg Trinket B]|h|r",
        [8] = "|Hitem:3333::::|h[Boots]|h", [10] = "|Hitem:4444::::|h[Gloves]|h" }
BAGS = { [0] = { [1] = "|Hitem:11122::::|h[Carrot on a Stick]|h", [2] = "|Hitem:5555:464:::|h[Spur Boots]|h" } }
BOUND = { [11122] = false, [5555] = true, [2222] = true, [3333] = true }
LOG = {}; ZONE = "Durotar"
MOUNTED, COMBAT = false, false
IsMounted = function() return MOUNTED end
InCombatLockdown = function() return COMBAT end
UnitAffectingCombat = function() return COMBAT end
UnitOnTaxi = function() return false end
UnitCastingInfo = function() return nil end; UnitChannelInfo = function() return nil end
GetCursorInfo = function() return nil end
GetRealZoneText = function() return ZONE end; GetZoneText = GetRealZoneText; GetSubZoneText = function() return "" end
MerchantFrame = nil; LootFrame = nil; MailFrame = nil; BankFrame = nil; BankPanel = nil; TradeFrame = nil; GuildBankFrame = nil
GetInventoryItemLink = function(_, s) return INV[s] end
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(b) return b == 0 and 4 or 0 end
C_Container.GetContainerItemLink = function(b, s) return BAGS[b] and BAGS[b][s] end
C_Container.GetContainerItemInfo = function(b, s) local l = BAGS[b] and BAGS[b][s]; if not l then return nil end
  local id = tonumber(l:match("item:(%d+)"))
  return { hyperlink = l, quality = 2, stackCount = 1, isBound = BOUND[id] or false, isLocked = false } end
C_Item = C_Item or {}
C_Item.GetItemInfo = function(l) local id = tonumber(tostring(l):match("item:(%d+)")) ; if not id then return end
  local loc = (id == 5555 or id == 3333) and "INVTYPE_FEET" or "INVTYPE_TRINKET"
  return "Item" .. id, l, 2, 30, 1, "Armor", "Misc", 1, loc, 0, 125, 4, 0, 2 end  -- bindType 2 = BoE
local function findBag(link) for b, t in pairs(BAGS) do for s, l in pairs(t) do if l == link then return b, s end end end end
C_Item.EquipItemByName = function(link, slot)
  table.insert(LOG, "equip " .. link:match("%[(.-)%]") .. " ->" .. slot)
  local b, s = findBag(link); local old = INV[slot]
  if b then INV[slot] = link; BAGS[b][s] = old end
end
PRINTS = {}; ADDON_NS.Print = function(...) table.insert(PRINTS, table.concat({...}, " ")) end
''')
def tick(n=6):
    for _ in range(n): LA.execute("ADDON_NS.QoL:MountTick()"); GA.ADVANCE(0.5)
LA.execute('MOUNTED = true'); tick()
print("1 unbound:", LA.eval("INV[14]"), "|", LA.eval("table.concat(PRINTS, \" // \")")[:160])
print("  boots (bound spurs) on:", LA.eval('INV[8]'))
LA.execute('MOUNTED = false'); tick()
print("  dismount boots back:", LA.eval('INV[8]'))
LA.execute('BOUND[11122] = true; LOG = {}; MOUNTED = true'); tick()
print("2 bound carrot mounted:", LA.eval('INV[14]'))
LA.execute('MOUNTED = false; COMBAT = true'); tick()
print("  dismount in combat (still carrot):", LA.eval('INV[14]'))
LA.execute('COMBAT = false'); tick()
print("  after combat:", LA.eval('INV[14]'), "| saved empty:", LA.eval('next(ADDON_NS.db.qolSaved) == nil'))
print("  log:", LA.eval('table.concat(LOG, "; ")'))
# equip by name silently does nothing -> switches to cursor
LA.execute('''LOG = {}; C_Item.EquipItemByName = function() table.insert(LOG, "noop") end
CURSOR = nil
C_Container.PickupContainerItem = function(b, s) CURSOR = { b = b, s = s, link = BAGS[b][s] }; table.insert(LOG, "pick") end
EquipCursorItem = function(slot) if CURSOR then local old = INV[slot]; INV[slot] = CURSOR.link; BAGS[CURSOR.b][CURSOR.s] = old; CURSOR = nil; table.insert(LOG, "place " .. slot) end end
CursorHasItem = function() return CURSOR ~= nil end; ClearCursor = function() CURSOR = nil end
MOUNTED = true''')
tick(14)
print("3 fallback mounted:", LA.eval('INV[14]'))
LA.execute('MOUNTED = false'); tick(10)
print("  fallback dismount:", LA.eval('INV[14]'), "| log:", LA.eval('table.concat(LOG, "; ")'))
# desert rose in Tanaris
LA.execute('BAGS[0][4] = "|Hitem:274648::::|h[The Desert Rose]|h"; BOUND[274648] = true; ZONE = "Tanaris"; MOUNTED = true'); tick(10)
print("4 Tanaris trinket:", LA.eval('INV[14]'))
LA.execute('ZONE = "Durotar"'); tick(10)
print("  left desert:", LA.eval('INV[14]'))
LA.execute('MOUNTED = false'); tick(10)
print("  dismount:", LA.eval('INV[14]'))
# blocked
LA.execute('ADDON_NS.QoL:OnBlocked("Chillan", "C_Item.EquipItemByName()")')
LA.execute('ADDON_NS.QoL:Test()')
print("test output:\n  " + LA.eval('table.concat(PRINTS, "\\n  ", math.max(1, #PRINTS - 9))'))
LA.execute('ADDON_NS.Window:Create(); ADDON_NS.Window.frame:Show(); ADDON_NS.Window:Select("qol")'); run(1)
print("tab:", LA.eval('ADDON_NS.Window.tabs.qol ~= nil'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:6])
