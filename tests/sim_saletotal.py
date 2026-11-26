# 1.4.70 a sold stack is counted once: the game's amount may be per item or for the whole stack
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
L, G, ns = A
res = L.execute('''
local AH = ADDON_NS.AH
local st = AH.Stats()
st.unit = { [1234] = { p = 25 * 100 } }          -- asked 25s each
local a = AH.SaleTotal(1234, 20, 25 * 100, true)          -- game gave the price per item
local b = AH.SaleTotal(1234, 20, 25 * 100 * 20, true)     -- game gave the whole stack
local c = AH.SaleTotal(1234, 1, 9999, false)
return a == 50000 and b == 50000 and c == 9999
''')
print("sale total:", res); assert res
