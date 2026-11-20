-- Chillan? – gold coin on the quest reward that sells for the most (1.4.4)
-- When a quest lets you choose a reward, the choice with the highest vendor price (price × count)
-- gets a small gold coin on its icon – in the quest window and in the quest log. Hover the coin for
-- the price. Setting: QoL › Questing › "Gold coin on the best-selling reward".
local ADDON, ns = ...
local Q = {}
ns.QuestCoin = Q

local COIN = "Interface\\MoneyFrame\\UI-GoldIcon"

local function sellPrice(link)
  if not link then return nil end
  local info = C_Item and C_Item.GetItemInfo or GetItemInfo
  local ok, _, _, _, _, _, _, _, _, _, _, price = pcall(info, link)
  if ok and type(price) == "number" and not ns.isSecret(price) then return price end
  return nil   -- not cached yet
end

-- the reward buttons the game shows (they've had several names over the years)
local function buttons()
  local out = {}
  local rf = QuestInfoRewardsFrame
  if rf and type(rf.RewardButtons) == "table" then
    for _, b in ipairs(rf.RewardButtons) do out[#out + 1] = b end
  end
  if #out == 0 then
    for i = 1, 10 do
      local b = _G["QuestInfoRewardsFrameQuestInfoItem" .. i] or _G["QuestInfoItem" .. i]
      if b then out[#out + 1] = b end
    end
  end
  for _, prefix in ipairs({ "QuestRewardItem", "QuestLogItem", "MapQuestInfoRewardsFrameQuestInfoItem" }) do
    for i = 1, 10 do
      local b = _G[prefix .. i]
      if b then out[#out + 1] = b end
    end
  end
  return out
end

local function fromLog()
  return (QuestInfoFrame and QuestInfoFrame.questLog) or (QuestLogFrame and QuestLogFrame:IsShown() and not (QuestFrame and QuestFrame:IsShown()))
end

local function linkFor(b)
  local id = b.GetID and b:GetID() or 0
  if id < 1 then return nil end
  local log = fromLog()
  local fn = log and GetQuestLogItemLink or GetQuestItemLink
  if not fn then return nil end
  local ok, link = pcall(fn, "choice", id)
  if (not ok or not link) and not log and GetQuestLogItemLink then ok, link = pcall(GetQuestLogItemLink, "choice", id) end
  return ok and link or nil
end

local function countFor(b)
  local id = b.GetID and b:GetID() or 0
  local ok, n
  if fromLog() and GetQuestLogChoiceInfo then
    ok, _, _, n = pcall(GetQuestLogChoiceInfo, id)
  elseif GetQuestItemInfo then
    ok, _, _, n = pcall(GetQuestItemInfo, "choice", id)
  end
  if ok and type(n) == "number" and not ns.isSecret(n) and n > 0 then return n end
  return 1
end

local function coinOn(b)
  if not b.chillanCoin then
    local f = CreateFrame("Frame", nil, b)
    f:SetSize(16, 16)
    local icon = b.Icon or b.icon or (b.GetName and b:GetName() and _G[b:GetName() .. "IconTexture"])
    if icon then f:SetPoint("TOPLEFT", icon, "TOPLEFT", -5, 5) else f:SetPoint("TOPLEFT", b, "TOPLEFT", -4, 4) end
    f:SetFrameLevel(b:GetFrameLevel() + 5)
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints()
    f.tex:SetTexture(COIN)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine("Sells for the most", 1, 0.82, 0)
      if self.price then GameTooltip:AddLine(GetCoinTextureString and GetCoinTextureString(self.price) or tostring(self.price), 1, 1, 1) end
      GameTooltip:AddLine("Chillan? QoL – gold coin on the best-selling reward", 0.55, 0.57, 0.6)
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b.chillanCoin = f
  end
  return b.chillanCoin
end

function Q:Update()
  local all = buttons()
  for _, b in ipairs(all) do if b.chillanCoin then b.chillanCoin:Hide() end end
  if not ns.db or not ns.db.settings.qolRewardCoin then return end
  local best, bestPrice, choices, missing = nil, 0, 0, false
  for _, b in ipairs(all) do
    if b:IsShown() and b.type == "choice" and (b.objectType == nil or b.objectType == "item") then
      local link = linkFor(b)
      if link then
        choices = choices + 1
        local p = sellPrice(link)
        if p == nil then missing = true
        else
          p = p * countFor(b)
          if p > bestPrice then best, bestPrice = b, p end
        end
      end
    end
  end
  -- item info not loaded yet: try again in a moment
  if missing and (self.tries or 0) < 5 then
    self.tries = (self.tries or 0) + 1
    C_Timer.After(0.3, function() Q:Update() end)
    return
  end
  self.tries = 0
  if best and choices >= 2 and bestPrice > 0 then
    local c = coinOn(best)
    c.price = bestPrice
    c:Show()
  end
end

local function later() C_Timer.After(0.05, function() Q:Update() end) end
ns:On("QUEST_COMPLETE", later)
ns:On("QUEST_DETAIL", later)
ns:On("QUEST_LOG_UPDATE", function() if fromLog() then later() end end)
ns:On("GET_ITEM_INFO_RECEIVED", function() if QuestFrame and QuestFrame:IsShown() then later() end end)
if hooksecurefunc and QuestInfo_Display then hooksecurefunc("QuestInfo_Display", later) end
if hooksecurefunc and QuestLog_UpdateQuestDetails then hooksecurefunc("QuestLog_UpdateQuestDetails", later) end
