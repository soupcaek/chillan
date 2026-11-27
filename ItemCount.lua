-- Chillan? – (1.4.76) how many you have: hover an item for "Bags 12 · Bank 40 = 52".
-- The bank is remembered each time you open it, so the count is right anywhere.
-- A setting of its own (Tools › Interface, on by default), works with the Market off too.
local ADDON, ns = ...
local IC = {}
ns.ItemCount = IC

local function on() return ns.db and ns.db.settings and ns.db.settings.itemCount ~= false end
local function me() return ns.Comm and ns.Comm.MyFull and ns.Comm:MyFull() or "me" end
local function count(id, bank)
  local f = (C_Item and C_Item.GetItemCount) or GetItemCount
  if not f then return 0 end
  local ok, n = pcall(f, id, bank and true or false)
  return (ok and type(n) == "number" and not ns.isSecret(n)) and n or 0
end

-- what's in the bank now (only while it's open)
local function bankBags()
  local list = { (Enum and Enum.BagIndex and Enum.BagIndex.Bank) or BANK_CONTAINER or -1 }
  local first = (NUM_BAG_SLOTS or 4) + 1
  for b = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do list[#list + 1] = b end
  return list
end
function IC:ScanBank()
  if not (C_Container and C_Container.GetContainerNumSlots) then return end
  local out = {}
  for _, bag in ipairs(bankBags()) do
    local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
    for slot = 1, (ok and n or 0) do
      local okI, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
      if okI and type(info) == "table" and info.itemID then
        out[info.itemID] = (out[info.itemID] or 0) + (info.stackCount or 1)
      end
    end
  end
  ns.db.bankCount = ns.db.bankCount or {}
  ns.db.bankCount[me()] = out
end

-- bags, bank, total
function IC.For(id)
  id = tonumber(id)
  if not id then return 0, 0, 0 end
  local bags = count(id, false)
  local bank = math.max(0, count(id, true) - bags)
  if not IC.bankOpen then
    -- the game only knows the bank once it's been open this session: use what was there last time
    local saved = ns.db and ns.db.bankCount and ns.db.bankCount[me()]
    if saved and bank == 0 then bank = saved[id] or 0 end
  end
  return bags, bank, bags + bank
end

local function addLine(tt, id)
  if not on() or not tt or not tt.AddDoubleLine then return end
  local bags, bank, total = IC.For(id)
  if total <= 0 then return end
  local right = "Bags " .. bags .. (bank > 0 and (" · Bank " .. bank) or "") .. (bank > 0 and bags > 0 and (" = " .. total) or "")
  tt:AddDoubleLine("You have", right, 0.75, 0.78, 0.82, 1, 1, 1)
  if tt.Show then tt:Show() end
end
IC.AddLine = addLine

local function itemId(link) return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil end
local function hook()
  if IC.hooked then return end
  IC.hooked = true
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
      local id = data and data.id
      if (not id or ns.isSecret(id)) and tt.GetItem then
        local ok, _, link = pcall(tt.GetItem, tt)
        id = ok and itemId(link) or nil
      end
      if id and not ns.isSecret(id) then pcall(addLine, tt, id) end
    end)
  else
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
      if tt and tt.HookScript then
        tt:HookScript("OnTooltipSetItem", function(self)
          local ok, _, link = pcall(self.GetItem, self)
          if ok then pcall(addLine, self, itemId(link)) end
        end)
      end
    end
  end
end

ns:On("PLAYER_LOGIN", hook)
ns:On("BANKFRAME_OPENED", function() IC.bankOpen = true IC:ScanBank() end)
ns:On("BANKFRAME_CLOSED", function() if IC.bankOpen then IC:ScanBank() end IC.bankOpen = nil end)
ns:On("PLAYERBANKSLOTS_CHANGED", function() if IC.bankOpen then IC:ScanBank() end end)
ns:On("BAG_UPDATE_DELAYED", function() if IC.bankOpen then IC:ScanBank() end end)
