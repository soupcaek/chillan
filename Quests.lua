-- Chillan? – quest-kompis: hvem i gjengen har de samme questene som deg
local ADDON, ns = ...
local Q = {}
ns.Quests = Q
local Comm = ns.Comm

local GROUP_TAGS = { Group = true, Elite = true, Dungeon = true, Raid = true, Gruppe = true }

-- Mine quests: { [id] = "g" for gruppe/elite/dungeon, "" ellers }
function Q:Mine()
  local out = {}
  local QL = C_QuestLog
  if not QL or not QL.GetNumQuestLogEntries then return out end
  local n = ns.S(QL.GetNumQuestLogEntries) or 0
  for i = 1, n do
    local info = ns.S(QL.GetInfo, i)
    if type(info) == "table" and not info.isHeader and not info.isHidden and info.questID and info.questID > 0 then
      local flag = ""
      if (info.suggestedGroup or 0) > 1 then flag = "g" end
      local tag = QL.GetQuestTagInfo and ns.S(QL.GetQuestTagInfo, info.questID)
      if type(tag) == "table" and tag.tagName and GROUP_TAGS[tag.tagName] then flag = "g" end
      out[info.questID] = flag
      if info.title then Q.titles[info.questID] = info.title end
    end
  end
  return out
end

Q.titles = {}
function Q:Title(id)
  if Q.titles[id] then return Q.titles[id] end
  local QL = C_QuestLog
  local t = QL and QL.GetTitleForQuestID and ns.S(QL.GetTitleForQuestID, id)
  if t and t ~= "" then Q.titles[id] = t return t end
  if QL and QL.RequestLoadQuestByID then pcall(QL.RequestLoadQuestByID, id) end
  return "Quest #" .. id
end

function Q:Build()
  local parts = {}
  for id, flag in pairs(self:Mine()) do
    if #parts < 30 then parts[#parts + 1] = id .. flag end
  end
  table.sort(parts)
  return Comm:Build("QL", ns.pid, table.concat(parts, ","))
end

local pending = false
function Q:SendSoon()
  if pending or not ns.codeHash then return end
  pending = true
  C_Timer.After(4, function()
    pending = false
    Comm:Broadcast(Q:Build(), 3)
    local me = ns:GetPerson(ns.pid, true)
    me.quests = Q:Mine()
    ns:MarkDirty()
  end)
end

function Q:SendTo(target)
  Comm:SendTo(target, self:Build(), 3)
end

Comm:Handle("QL", function(f)
  local pid = f[1]
  if not pid or pid == ns.pid then return end
  local p = ns:GetPerson(pid, true)
  local list = {}
  for _, e in ipairs(ns.Split(f[2] or "", ",")) do
    local id, flag = e:match("^(%d+)(g?)$")
    if id then list[tonumber(id)] = flag end
  end
  p.quests = list
  p.questsAt = ns.Now()
  ns:MarkDirty()
end)

-- Er denne personen i gruppa mi nå?
function ns.InMyGroup(p)
  if not p then return false end
  local names = {}
  for _, c in pairs(p.chars or {}) do if c.name then names[c.name] = true end end
  local n = ns.S(GetNumGroupMembers) or 0
  if n == 0 then return false end
  local prefix = (ns.S(IsInRaid) and "raid") or "party"
  for i = 1, n do
    local name = ns.S(UnitName, prefix .. i)
    if name and names[name] then return true end
  end
  return false
end

-- Hvem i gjengen har denne questen?
function Q:Holders(id, onlineOnly)
  local out = {}
  for pid, p in pairs(ns.db.people) do
    if pid ~= ns.pid and p.main and p.quests and p.quests[id] and (not onlineOnly or ns:IsOnline(p)) then
      out[#out + 1] = p
    end
  end
  return out
end

-- Liste til Quests-fanen: felles quests og gruppe-quests i gjengen
function Q:Overview()
  local mine = self:Mine()
  local shared, group, seen = {}, {}, {}
  for id in pairs(mine) do
    local h = self:Holders(id)
    if #h > 0 then shared[#shared + 1] = { id = id, holders = h, mine = true, group = mine[id] == "g" } end
  end
  for pid, p in pairs(ns.db.people) do
    if pid ~= ns.pid and p.main and p.quests then
      for id, flag in pairs(p.quests) do
        if flag == "g" and not seen[id] then
          seen[id] = true
          group[#group + 1] = { id = id, holders = self:Holders(id), mine = mine[id] ~= nil, group = true }
        end
      end
    end
  end
  local function online(e) local n = 0 for _, p in ipairs(e.holders) do if ns:IsOnline(p) then n = n + 1 end end return n end
  local function sort(a, b)
    local oa, ob = online(a), online(b)
    if oa ~= ob then return oa > ob end
    if #a.holders ~= #b.holders then return #a.holders > #b.holders end
    return a.id < b.id
  end
  table.sort(shared, sort)
  table.sort(group, sort)
  return shared, group
end

-- Du plukket opp en quest: si fra hvis en kompis (online, ikke i gruppa) har den
local alerted = {}
local function onAccepted(...)
  local n = select("#", ...)
  local id
  for i = n, 1, -1 do
    local v = select(i, ...)
    if type(v) == "number" and v > 0 then id = v break end
  end
  Q:SendSoon()
  if not id or alerted[id] or not ns.db.settings.questBuddy then return end
  C_Timer.After(1, function()
    local buddies = {}
    for _, p in ipairs(Q:Holders(id, true)) do
      if not ns.InMyGroup(p) then buddies[#buddies + 1] = p end
    end
    if #buddies == 0 then return end
    alerted[id] = true
    local names = {}
    for i = 1, math.min(3, #buddies) do names[i] = ns:ShortWho(buddies[i]) end
    local first = buddies[1]
    ns:Fire("TOAST", { kind = "quest", pid = first.pid, char = (first.live and first.live.char) or first.main,
      title = table.concat(names, ", ") .. (#buddies > 3 and (" +" .. (#buddies - 3)) or "") .. " also has this one",
      text = "«" .. Q:Title(id) .. "» – do it together?" })
  end)
end

function Q:Start()
  ns:On("QUEST_ACCEPTED", onAccepted)
  ns:On("QUEST_REMOVED", function() Q:SendSoon() end)
  ns:On("QUEST_TURNED_IN", function() Q:SendSoon() end)
  ns:On("QUEST_DATA_LOAD_RESULT", function() ns:MarkDirty() end)
  C_Timer.After(12, function() Q:SendSoon() end)
  C_Timer.NewTicker(300, function() Q:SendSoon() end)
end
