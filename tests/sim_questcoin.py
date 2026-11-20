# 1.4.4 gold coin on the best-selling quest reward
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A
run(2)
LA.execute('''
QuestFrame = CreateFrame("Frame"); QuestFrame:Show()
local prices = { [1] = 500, [2] = 2600, [3] = 900 }
for i = 1, 3 do local b = CreateFrame("Button", "QuestInfoRewardsFrameQuestInfoItem" .. i, UIParent); b.GetID = function() return i end; b.type = "choice"; b.objectType = "item"; b:Show() end
GetQuestItemLink = function(kind, i) return "|cff1eff00|Hitem:" .. (100 + i) .. "::::|h[Reward " .. i .. "]|h|r" end
GetQuestItemInfo = function(kind, i) return "Reward", 0, i == 3 and 4 or 1 end
GetItemInfo = function(link) local id = tonumber(link:match("item:(%d+)")) - 100; local p = ({ 500, 2600, 900 })[id] return "x", link, 2, 10, 10, "Armor", "Cloth", 1, "", 0, p end
C_Item = C_Item or {}; C_Item.GetItemInfo = GetItemInfo
FIRE("QUEST_COMPLETE")''')
run(3)
print("coin on:", LA.eval('(function() for i = 1, 3 do local b = _G["QuestInfoRewardsFrameQuestInfoItem" .. i] if b.chillanCoin and b.chillanCoin:IsShown() then return i .. " price " .. b.chillanCoin.price end end return "none" end)()'))
print("FEIL:", list(GA.ERRORS.values())[:4])
LA.execute('ADDON_NS.QuestCoin:Update()')
print("again:", LA.eval('(function() for i = 1, 3 do local b = _G["QuestInfoRewardsFrameQuestInfoItem" .. i] if b.chillanCoin and b.chillanCoin:IsShown() then return i .. " price " .. b.chillanCoin.price end end return "none" end)()'), list(GA.ERRORS.values())[:4])
