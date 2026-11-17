exec(open("sim_layer2.py").read().split("# same-layer")[0])
# Mario stands next to A: his nameplate shows
LA.execute('''_G.UnitExists_orig = UnitExists
UnitExists = function(u) if u == "nameplate3" then return true end return _G.UnitExists_orig(u) end
UnitIsPlayer = function(u) return u == "nameplate3" end
local un = UnitName
UnitName = function(u) if u == "nameplate3" then return "Mario", "Fistfury" end return un(u) end''')
GA.FIRE("NAME_PLATE_UNIT_ADDED", "nameplate3"); run(1)
print("seen Mario:", LA.eval('ADDON_NS.LayerHop.SeenNearby("Mario Fistfury-ClassicBetaPvP")'))
LA.execute('''ACCEPTED = 0; AcceptGroup = function() ACCEPTED = ACCEPTED + 1 end
ADDON_NS.LayerHop.mine = { id = "x", t = ADDON_NS.Now(), from = "6843", mode = "ls", whispered = { mariofistfury = true }, replies = {} }''')
GA.FIRE("PARTY_INVITE_REQUEST", "Mario Fistfury"); run(1)
print("Mario's invite accepted:", LA.eval('ACCEPTED'))
# whisper burst skips him
LA.execute('WHISPERS = {}; ADDON_NS.LayerHop.mine.whispered = {}; ADDON_NS.LayerHop:Whisper(ADDON_NS.LayerHop.mine, { "Mario Fistfury", "Far Away" })'); run(2)
print("whispered:", LA.eval('table.concat(WHISPERS, " | ")'))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5])
