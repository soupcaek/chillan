# 1.4.35 Disenchant next button: picks the item that gains most from disenchanting
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(3)
LA.execute('''IsPlayerSpell = function(id) return id == 13262 end
local M = ADDON_NS.Market
M:Set(11176, 20000, ADDON_NS.Now(), ADDON_NS.pid)  -- Dream Dust 2g
M:Set(16203, 60000, ADDON_NS.Now(), ADDON_NS.pid)
M:Set(14344, 90000, ADDON_NS.Now(), ADDON_NS.pid)
local items = { [1] = { id = 15000, q = 2, ilvl = 52 }, [2] = { id = 15001, q = 2, ilvl = 52 } }
C_Item = C_Item or {}
C_Item.GetItemInfo = function(id)
  for _, it in pairs(items) do if it.id == id then return "Green Thing " .. id, "|cff1eff00|Hitem:" .. id .. "|h[Green Thing]|h|r", it.q, it.ilvl, 50, "Armor", "Cloth", 1, "INVTYPE_CHEST", nil, 100, 4 end end
  return nil
end
GetItemInfo = C_Item.GetItemInfo
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(b) return b == 0 and 4 or 0 end
C_Container.GetContainerItemInfo = function(b, s) local it = items[s] if b == 0 and it then return { itemID = it.id, hyperlink = "|cff1eff00|Hitem:" .. it.id .. "|h[Green Thing]|h|r", isBound = true } end end''')
print("to disenchant:", LA.eval('#ADDON_NS.Disenchant:ToDisenchant()'))
LA.execute('ADDON_NS.Window:Create(); ADDON_NS.Window.frame:Show(); ADDON_NS.Window:Select("market")'); run(1)
LA.execute('B = nil; for _, f in ipairs({}) do end')
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5])
