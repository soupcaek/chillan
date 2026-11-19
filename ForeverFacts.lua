-- Chillan? – Forever facts: what WoW Forever really has, in one place.
-- Lesson from the mount swap (built twice): never build on items or rules from another WoW version.
-- Every entry says whether it was checked in Forever ("checked") or taken from elsewhere ("assumed").
-- Features read from here; /chill selftest shows what the client actually offers.
local ADDON, ns = ...

ns.FOREVER = {
  items = {
    carrot = { id = 11122, checked = "AutoCarrot Forever built-in; binds when equipped" },
    desertRose = { id = 274648, checked = "AutoCarrot Forever: +7% mount speed in Desert areas" },
    wintersaberGloves = { id = 284266, checked = "AutoCarrot Forever: +6% mounted speed in Winterspring" },
    -- Riding Crop (25653), Skybreaker Whip (32863), Hydrocane, Azure Silk Belt and Deepdive Helmet
    -- do NOT exist in Forever (AutoCarrot Forever, DESIGN §12).
  },
  enchants = {
    mithrilSpurs = { id = 464, checked = "boots; matched by enchant id only" },
    ridingSkill = { id = 930, checked = "gloves; Forever's item called Riding Gloves gives no speed" },
  },
  zones = {
    -- "Desert areas" for The Desert Rose; Desolace and Westfall confirmed in game by AutoCarrot Forever
    desert = { "Tanaris", "Silithus", "Desolace", "Westfall" },
    winterspring = { "Winterspring" },
  },
  -- what the client blocks or hides (each one cost us a bug)
  limits = {
    "Chat lines (loot, honour) and some event values can be secret mid-fight: use ns.S and fallbacks",
    "Addon messages are refused during an encounter (result 11): queue, never drop",
    "C_FriendList.SendWho only straight from a click or typed command",
    "The combat log is blocked",
    "An unbound Bind-on-Equip item can't be equipped by an addon",
    "The layer is the server part of a creature GUID; a world refresh can keep the number",
  },
}

-- /chill selftest: which game functions answer on this client
function ns.SelfTest()
  local function has(path)
    local t = _G
    for part in path:gmatch("[^%.]+") do
      if type(t) ~= "table" then return false end
      t = t[part]
    end
    return t ~= nil
  end
  local checks = {
    { "C_ChatInfo.SendAddonMessage", "talk to the gang" },
    { "C_ChatInfo.InChatMessagingLockdown", "know when messages are refused" },
    { "C_FriendList.SendWho", "layer hop search" },
    { "C_Container.GetContainerItemInfo", "bags (loot, QoL)" },
    { "C_Item.EquipItemByName", "mount gear swap" },
    { "C_TooltipInfo.GetBagItem", "red tint on bag items" },
    { "C_Map.GetBestMapForUnit", "map pins, layer hop" },
    { "GetEvictionTimeRemaining", "world refresh countdown" },
    { "issecretvalue", "secret value check" },
    { "CombatLogGetCurrentEventInfo", "combat log (blocked in Forever)" },
  }
  ns.Print("Self test – Chillan " .. (ns.VERSION or "?") .. ":")
  for _, c in ipairs(checks) do
    print(string.format("  %s %s – %s", has(c[1]) and "|cff5FD18Byes|r" or "|cffF2777Ano |r", c[1], c[2]))
  end
  local lock = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and ns.S(C_ChatInfo.InChatMessagingLockdown)
  print("  messages right now: " .. (lock and "|cffE0B04Fon hold (encounter)|r" or "free"))
  if ns.Comm and ns.Comm.ChannelStatusText then
    local ok, txt = pcall(ns.Comm.ChannelStatusText, ns.Comm)
    if ok and txt then print("  gang channel: " .. txt) end
  end
  local n = 0
  for pid, p in pairs(ns.db.people or {}) do if pid ~= ns.pid and ns:IsOnline(p) then n = n + 1 end end
  print("  gang members heard online: " .. n)
  if ns.Market then print("  auction house: " .. ns.Market:SelfTest()) end
  for _, f in ipairs({ "GetPVPSessionStats", "GetBattlefieldWinner" }) do
    print(string.format("  %s %s", (_G[f] and "|cff5FD18Byes|r" or "|cffF2777Ano |r"), f))
  end
end
