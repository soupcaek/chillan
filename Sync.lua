-- Chillan? – "hvem hører hvem" og automatisk utjevning av chat og hendelser.
--
-- Hvert 30. sek sender alle en HR-melding med:
--   1) hvilke venner de hører (og om det er via kanal eller bare whisper)
--   2) et lite fingeravtrykk av chat + hendelser siste 3 timer (16 bøtter)
-- Da kan alle:
--   • se at en venn IKKE hører dem på kanalen → hviske til ham i stedet
--   • regne venner som online hvis noen andre i gjengen hører dem
--   • oppdage at de mangler meldinger og hente akkurat de bøttene som mangler
local ADDON, ns = ...
local Sync = {}
ns.Sync = Sync
local Comm = ns.Comm

local WINDOW = 3 * 3600
local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"
local startAt = 0

local function bucketOf(id)
  local h = 0
  for i = 1, #(id or "") do h = (h * 31 + id:byte(i)) % 65521 end
  return h % 16
end

local function idSum(id)
  local h = 7
  for i = 1, #(id or "") do h = (h * 17 + id:byte(i)) % 997 end
  return h
end

local function c36(n) n = math.max(0, math.min(35, n)) return B36:sub(n + 1, n + 1) end
local function n36(ch) local i = B36:find(ch or "", 1, true) return i and (i - 1) or 0 end

local function eachRecent(fn)
  local cutoff = ns.Now() - WINDOW
  for _, it in ipairs(ns.db.chat or {}) do if it.t and it.t > cutoff and it.id then fn(it, "CH") end end
  for _, it in ipairs(ns.db.feed or {}) do if it.t and it.t > cutoff and it.id then fn(it, "EV") end end
end

-- 32 tegn: per bøtte antall + sjekksum av id-ene
function Sync:Digest()
  local cnt, sum = {}, {}
  for b = 0, 15 do cnt[b], sum[b] = 0, 0 end
  eachRecent(function(it)
    local b = bucketOf(it.id)
    cnt[b] = cnt[b] + 1
    sum[b] = (sum[b] + idSum(it.id)) % 36
  end)
  local out = {}
  for b = 0, 15 do out[#out + 1] = c36(cnt[b]) .. c36(sum[b]) end
  return table.concat(out)
end

-- Hvem hører jeg nå? "pid" = via kanalen, "pid*" = bare via whisper
function Sync:HeardList()
  local t, byPid = ns.Now(), {}
  for _, r in pairs(ns.db.roster) do
    if r.pid and r.pid ~= ns.pid and r.heard and (t - r.heard) < 90 then
      local viaChan = r.chan and (t - r.chan) < Comm.CHAN_FRESH
      byPid[r.pid] = byPid[r.pid] or viaChan or false
    end
  end
  local out = {}
  for pid, chan in pairs(byPid) do
    if #out < 18 then out[#out + 1] = pid .. (chan and "" or "*") end
  end
  return table.concat(out, ",")
end

function Sync:Send()
  if not ns.codeHash then return end
  Comm:Broadcast(Comm:Build("HR", ns.pid, self:HeardList(), self:Digest()), 3)
end

Comm:Handle("HR", function(f, sender)
  local pid = f[1]
  if not pid or pid == ns.pid then return end
  local t = ns.Now()
  local r = ns.db.roster[sender]
  if r then r.pid = pid end

  -- 1) Hører han meg – og hvordan?
  local mine
  for _, e in ipairs(ns.Split(f[2] or "", ",")) do
    local epid, star = e:match("^([^%*]+)(%*?)$")
    if epid == ns.pid then
      mine = (star == "*") and "whisper" or "chan"
    elseif epid and epid ~= "" then
      -- 2) Venner han hører regnes som online hos meg også
      local p = ns.db.people[epid]
      if p then
        p.via = t
        local direct = p.heard and (t - p.heard) < 100
        if not direct and p.main and not Comm:IsMe(p.main) and (not p.hiAt or (t - p.hiAt) > 90) then
          p.hiAt = t
          local rr = ns.db.roster[p.main] or {}
          ns.db.roster[p.main] = rr
          rr.pid, rr.offlineAt = epid, nil
          Comm:SendTo(p.main, Comm:Build("HI", ns.pid, Comm:MyFull(), 1, ns.VERSION), 2)
        end
      end
    end
  end
  if r then
    if mine == "chan" then
      r.forceWhisper = nil
    elseif (GetTime() - startAt) > 40 then
      -- han hører meg ikke på kanalen (annen layer/server): hvisk alt til ham
      r.forceWhisper = t
    end
  end

  -- 3) Mangler jeg meldinger han har?
  local theirs, own = f[3] or "", Sync:Digest()
  if #theirs == 32 and theirs ~= own and r then
    local want = {}
    for b = 0, 15 do
      local i = b * 2 + 1
      local tc, ts = n36(theirs:sub(i, i)), theirs:sub(i + 1, i + 1)
      local oc, osum = n36(own:sub(i, i)), own:sub(i + 1, i + 1)
      if tc > oc or (tc == oc and ts ~= osum and tc > 0) then want[#want + 1] = c36(b) end
    end
    if #want > 0 and (not r.syncAt or (t - r.syncAt) > 45) then
      r.syncAt = t
      Comm:SendTo(sender, Comm:Build("SB", ns.pid, table.concat(want)), 2)
    end
  end
  ns:MarkDirty()
end)

-- Send chat og hendelser i bøttene som ble etterspurt
Comm:Handle("SB", function(f, sender)
  local want = {}
  for ch in (f[2] or ""):gmatch(".") do want[n36(ch)] = true end
  local n, t = 0, ns.Now()
  eachRecent(function(it, kind)
    if n >= 30 or not want[bucketOf(it.id)] then return end
    n = n + 1
    if kind == "CH" then
      Comm:SendTo(sender, Comm:Build("CH", it.id, it.pid, it.char, t - it.t, it.text), 3, true)
    else
      Comm:SendTo(sender, Comm:Build("EV", it.id, it.pid, it.char, it.kind, t - it.t, it.a or "", it.b or "", it.c or "", it.d or ""), 3)
    end
  end)
end)

function Sync:Start()
  startAt = GetTime()
  C_Timer.After(8, function() Sync:Send() end)
  C_Timer.NewTicker(30, function() Sync:Send() end)
end
