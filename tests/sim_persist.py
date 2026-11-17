import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__)) + "/"
REPO = _os.path.dirname(HERE.rstrip("/")) + "/"
exec(open("sim.py").read().split("A = client(")[0])
from lupa import lua51
SER = r'''
local bad = {}
local function ser(v, path, depth)
  local t = type(v)
  if t == "string" then return string.format("%q", v)
  elseif t == "number" or t == "boolean" then return tostring(v)
  elseif t == "table" then
    if depth > 30 then bad[#bad+1] = path .. " (for dyp)" return "nil" end
    local parts = {}
    for k, x in pairs(v) do
      local kt = type(k)
      if kt ~= "string" and kt ~= "number" then bad[#bad+1] = path .. "[nøkkel " .. kt .. "]"
      else parts[#parts+1] = "[" .. ser(k, path, depth+1) .. "]=" .. ser(x, path .. "." .. tostring(k), depth+1) end
    end
    return "{" .. table.concat(parts, ",") .. "}"
  else bad[#bad+1] = path .. " (" .. t .. ")" return "nil" end
end
return function(db) bad = {} local s = ser(db, "ChillanDB", 0) return s, table.concat(bad, "\n") end
'''
A = client("Grimtusk", "WARRIOR", "Orc", 33, "Barrens")
A[2].SetCode(A[2], "CHILL-TEST")
A[1].ADVANCE(5)
T = A[2].Tiles
T.Toggle(T, "dura"); T.Toggle(T, "bags"); T.Toggle(T, "eta")
print("festet før:", list(T.List(T).values()))
A[2].db.settings.theme = "midnight"; A[2].db.settings.accent = "theme"; A[2].db.settings.overlayAlpha = 0.7
A[1].FIRE("PLAYER_LOGOUT")
ser = A[0].execute(SER)
src, bad = ser(A[1].ChillanDB)
print("ulagringsbare verdier:", bad[:500] or "ingen", "| størrelse:", len(src))
# ny økt med lagret DB
L = lua51.LuaRuntime(unpack_returned_tuples=True)
mock = open(HERE + "mock.lua").read()
me = L.table_from({"name": "Grimtusk", "realm": "ClassicBetaPvP", "class": "WARRIOR", "race": "Orc", "level": 33, "zone": "Barrens", "money": 1000})
f = L.eval("function(src, me) local f = assert(loadstring(src)) f(me) end"); f(mock, me)
L.execute("ChillanDB = " + src)
ns = L.globals().LOAD(BASE, L.table_from(toc)); G = L.globals()
G.FIRE("ADDON_LOADED", "Chillan"); G.FIRE("PLAYER_LOGIN"); G.FIRE("PLAYER_ENTERING_WORLD", False, False)
G.ADVANCE(5)
print("festet etter ny innlogging:", list(ns.Tiles.List(ns.Tiles).values()))
print("vist:", [t.key for t in ns.Tiles.tiles.values() if t.key and t.IsShown(t)])
print("tema:", ns.C.window, ns.C.accent, "| alpha:", ns.UI.OverlayAlpha(), "| knappfarge:", ns.UI.STYLES.primary.fill)
ns.Window.Toggle(ns.Window); ns.Window.Select(ns.Window, "settings")
print("FEIL:", list(G.ERRORS.values())[:3])
