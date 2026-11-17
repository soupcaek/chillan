# Layer hop verdict (1.0): "not moved" needs 3 creatures still on the old layer; no creatures = keep looking, give up at 60 s
exec(open("sim_layer2.py").read().split("# same-layer")[0])
LA.execute('''PRINTS = {}; local p = ADDON_NS.Print; ADDON_NS.Print = function(...) table.insert(PRINTS, table.concat({...}, " ")) end
PLATES = {}
local ue, ug = UnitExists, UnitGUID
UnitExists = function(u) if PLATES[u] then return true end if tostring(u):match("^nameplate") then return false end return ue(u) end
UnitGUID = function(u) if PLATES[u] then return PLATES[u] end return ug(u) end
UnitPlayerControlled = function() return false end''')
def hop():
    LA.execute('''PRINTS = {}; ADDON_NS.LayerHop.mine = { id = "v", t = ADDON_NS.Now(), from = "6843", mode = "ls", whispered = { hosty = true }, replies = {} }''')
    GA.FIRE("PARTY_INVITE_REQUEST", "Hosty")
# 1) three old-layer creatures in view -> not moved after 15 s, not before
hop()
LA.execute('PLATES = { nameplate1 = "Creature-0-6843-1-11-100-0001", nameplate2 = "Creature-0-6843-1-11-101-0002", nameplate3 = "Creature-0-6843-1-11-102-0003" }')
GA.ADVANCE(10)
print("at 10 s still checking:", LA.eval('ADDON_NS.LayerHop.mine ~= nil'))
GA.ADVANCE(8)
print("at 18 s verdict:", LA.eval('table.concat(PRINTS, " / ")')[-90:])
# 2) nothing in view -> no verdict at 30 s, gives up at 60 s
LA.execute('PLATES = {}')
hop()
GA.ADVANCE(30)
print("no creatures, 30 s, still open:", LA.eval('ADDON_NS.LayerHop.mine ~= nil'))
GA.ADVANCE(35)
print("60 s:", LA.eval('table.concat(PRINTS, " / ")')[-80:])
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5])
