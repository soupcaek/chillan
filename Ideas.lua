-- Chillan? – idea box: suggestions for the addon, up/down votes and status set by the admin
local ADDON, ns = ...
local I = {}
ns.Ideas = I
local Comm = ns.Comm

I.STATUS = {
  new = { name = "New", color = "9BA1A8" },
  planned = { name = "Planned", color = "8FB8E8" },
  done = { name = "Done", color = "5FD18B" },
  rejected = { name = "Rejected", color = "F2777A" },
}
I.STATUS_ORDER = { "new", "planned", "done", "rejected" }

local function db() ns.db.ideas = ns.db.ideas or {} return ns.db.ideas end
local function num(v) return tonumber(v) end

-- Admin: the first person in the gang to claim it (/chill admin) – earliest claim wins
function I:Admin() return ns.db.ideaAdmin and ns.db.ideaAdmin.pid end
function I:IsAdmin() return self:Admin() == ns.pid end

function I:ClaimAdmin()
  if self:Admin() and self:Admin() ~= ns.pid then
    local p = ns:GetPerson(self:Admin()) or {}
    ns.Print("The idea box already has an admin: " .. (ns:PersonAlias(p) or ns:PersonName(p) or "?"))
    return
  end
  ns.db.ideaAdmin = { pid = ns.pid, t = ns.Now() }
  Comm:Broadcast(Comm:Build("IA0", ns.pid, 0), 2)
  ns.Print("You are now the admin of the idea box.")
  ns:MarkDirty()
end

local function acceptAdmin(pid, ago)
  if not pid or pid == "" then return end
  local t = ns.Now() - (num(ago) or 0)
  local cur = ns.db.ideaAdmin
  if not cur or (cur.pid ~= pid and t < cur.t) then
    ns.db.ideaAdmin = { pid = pid, t = t }
    ns:MarkDirty()
  end
end

Comm:Handle("IA0", function(f) acceptAdmin(f[1], f[2]) end)

function I:Score(it)
  local s, up, down = 0, 0, 0
  for _, v in pairs(it.votes or {}) do
    s = s + v
    if v > 0 then up = up + 1 elseif v < 0 then down = down + 1 end
  end
  return s, up, down
end

function I:List(filter)
  local out = {}
  for _, it in pairs(db()) do
    if not it.deleted and (not filter or filter == "all" or it.status == filter
      or (filter == "open" and (it.status == "new" or it.status == "planned"))) then
      out[#out + 1] = it
    end
  end
  table.sort(out, function(a, b)
    local sa, sb = self:Score(a), self:Score(b)
    if sa ~= sb then return sa > sb end
    return (a.t or 0) > (b.t or 0)
  end)
  return out
end

local function buildIdea(it)
  return Comm:Build("ID", it.id, it.pid, it.char, math.max(0, ns.Now() - (it.t or ns.Now())),
    ns.Clean(it.title or "", 60), ns.Clean(it.desc or "", 200), it.status or "new")
end
local function buildVotes(it)
  local parts = {}
  for pid, v in pairs(it.votes or {}) do if v ~= 0 and #parts < 20 then parts[#parts + 1] = pid .. ":" .. v end end
  if #parts == 0 then return nil end
  return Comm:Build("IW", it.id, table.concat(parts, ","))
end

function I:Add(title, desc)
  title = ns.Clean(title or "", 60)
  if title == "" then ns.Print("Write a title for your idea first.") return end
  if not ns.codeHash then ns.Print("You need to join a gang first.") return end
  local it = { id = Comm:NewId(), pid = ns.pid, char = Comm:MyFull(), t = ns.Now(), title = title,
    desc = ns.Clean(desc or "", 200), status = "new", votes = { [ns.pid] = 1 } }
  db()[it.id] = it
  Comm:Seen(it.id)
  Comm:Broadcast(buildIdea(it), 2)
  Comm:Broadcast(Comm:Build("IV", it.id, ns.pid, 1), 2)
  ns:Fire("FEEDEVENT", ns.UI.InlineIcon("Star", ns.C.gold, 12) .. "  " .. ns:ShortWho(ns:GetPerson(ns.pid, true))
    .. ns.Colorize(" suggested: ", ns.C.text2) .. ns.Colorize(title, ns.C.text))
  ns:MarkDirty()
end

function I:Vote(id, v)
  local it = db()[id]
  if not it then return end
  it.votes = it.votes or {}
  if it.votes[ns.pid] == v then v = 0 end -- click again to undo
  it.votes[ns.pid] = v ~= 0 and v or nil
  Comm:Broadcast(Comm:Build("IV", id, ns.pid, v), 2)
  ns:MarkDirty()
end

function I:SetStatus(id, status)
  local it = db()[id]
  if not it or not self:IsAdmin() or not self.STATUS[status] then return end
  it.status = status
  Comm:Broadcast(Comm:Build("IS", id, status, ns.pid), 2)
  ns:MarkDirty()
end

function I:Delete(id)
  local it = db()[id]
  if not it or not (it.pid == ns.pid or self:IsAdmin()) then return end
  it.deleted = true
  Comm:Broadcast(Comm:Build("IX", id, ns.pid), 2)
  ns:MarkDirty()
end

-- Text for "Copy list": top ideas, ready to paste to whoever builds the addon
function I:ExportText()
  local lines = { "Chillan? idea box – top ideas" }
  for i, it in ipairs(self:List("open")) do
    if i > 15 then break end
    local s = self:Score(it)
    local p = ns:GetPerson(it.pid) or {}
    lines[#lines + 1] = string.format("%d. [%+d] %s%s (%s, %s)", i, s, it.title,
      (it.desc and it.desc ~= "") and (" – " .. it.desc) or "", ns:PersonAlias(p) or ns.ShortName(it.char or "?"),
      self.STATUS[it.status or "new"].name)
  end
  return table.concat(lines, "\n")
end

-- Send everything to a friend who just came online (ideas, votes, admin)
function I:SendAll(target)
  local n = 0
  for _, it in pairs(db()) do
    if n < 40 then
      n = n + 1
      if it.deleted then
        Comm:SendTo(target, Comm:Build("IX", it.id, it.pid), 3)
      else
        Comm:SendTo(target, buildIdea(it), 3)
        local v = buildVotes(it)
        if v then Comm:SendTo(target, v, 3) end
      end
    end
  end
  if ns.db.ideaAdmin then
    Comm:SendTo(target, Comm:Build("IA0", ns.db.ideaAdmin.pid, math.max(0, ns.Now() - ns.db.ideaAdmin.t)), 3)
  end
end

Comm:Handle("ID", function(f)
  local id = f[1]
  if not id or id == "" then return end
  local it = db()[id]
  local isNew = not it
  if isNew then
    it = { id = id, votes = {} }
    db()[id] = it
  end
  if it.deleted then return end
  it.pid, it.char = f[2], f[3]
  it.t = it.t or (ns.Now() - (num(f[4]) or 0))
  it.title, it.desc = f[5] or it.title, f[6] or it.desc
  -- status from anyone is only taken for new ideas; changes come through IS from the admin
  if isNew then it.status = I.STATUS[f[7] or ""] and f[7] or "new" end
  if isNew and (num(f[4]) or 0) < 300 then
    ns:Fire("FEEDEVENT", ns.UI.InlineIcon("Star", ns.C.gold, 12) .. "  " .. ns:ShortWho(ns:GetPerson(f[2]) or {}, f[3])
      .. ns.Colorize(" suggested: ", ns.C.text2) .. ns.Colorize(it.title or "", ns.C.text))
  end
  ns:MarkDirty()
end)

Comm:Handle("IV", function(f)
  local it = db()[f[1] or ""]
  if not it or not f[2] then return end
  it.votes = it.votes or {}
  local v = num(f[3]) or 0
  it.votes[f[2]] = v ~= 0 and v or nil
  ns:MarkDirty()
end)

-- Vote list from a friend (catch-up): only fills in votes we don't know about
Comm:Handle("IW", function(f)
  local it = db()[f[1] or ""]
  if not it then return end
  it.votes = it.votes or {}
  for _, e in ipairs(ns.Split(f[2] or "", ",")) do
    local pid, v = e:match("^([^:]+):(%-?%d)$")
    if pid and it.votes[pid] == nil then it.votes[pid] = tonumber(v) end
  end
  ns:MarkDirty()
end)

Comm:Handle("IS", function(f)
  local it = db()[f[1] or ""]
  if not it or not I.STATUS[f[2] or ""] then return end
  if f[3] ~= I:Admin() then return end -- only the admin can change status
  local was = it.status
  it.status = f[2]
  if was ~= f[2] then it.statusAt = ns.Now() end
  if f[2] == "done" and was ~= "done" then
    ns:Fire("TOAST", { kind = "info", title = "Idea done: " .. (it.title or ""), text = "From the idea box – update in WowUp to get it" })
    ns:Fire("FEEDEVENT", ns.UI.InlineIcon("Check", ns.C.green, 12) .. "  " .. ns.Colorize("Idea done: ", ns.C.green) .. (it.title or ""))
  end
  ns:MarkDirty()
end)

Comm:Handle("IX", function(f)
  local it = db()[f[1] or ""]
  if not it then
    db()[f[1] or "?"] = { id = f[1], deleted = true, pid = f[2] }
    return
  end
  if f[2] == it.pid or f[2] == I:Admin() then
    it.deleted = true
    ns:MarkDirty()
  end
end)
