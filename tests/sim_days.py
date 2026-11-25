# 1.4.66 per-day numbers: weekly totals written down per day, a day's value = growth since the day before
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
L, G, ns = A
res = L.execute('''
local St = ADDON_NS.St
local wk = ADDON_NS.WeekKey()
local now = time()
local back = (tonumber(date("%w", now)) + 6) % 7
ADDON_NS.db.dayStats = {}
local totals = {}
for i = 0, back do
  local day = date("%Y-%m-%d", now - (back - i) * 86400)
  totals[i + 1] = (i + 1) * 10 + i          -- 10, 21, 32, ...
  ADDON_NS.db.dayStats[day] = { a = { wk = wk, Online = totals[i + 1] }, b = { wk = "old", Online = 999 } }
end
local s = St:DaySeries("Online")
local ok = #s == 7
for i = 1, back + 1 do
  local want = totals[i] - (totals[i - 1] or 0)
  if s[i].value ~= want or not s[i].known then ok = false end
end
for i = back + 2, 7 do if not s[i].future then ok = false end end
-- SnapDay writes today's totals for people on this week
ADDON_NS.db.people["zz"] = { stats = { wk = wk, wOnline = 77 } }
St:SnapDay()
local today = ADDON_NS.db.dayStats[date("%Y-%m-%d")]
ok = ok and today.zz and today.zz.Online == 77
return ok
''')
print("day series + snapshot:", res); assert res
