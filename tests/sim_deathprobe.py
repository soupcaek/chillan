exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
L, G, ns = A
def last_dead():
    its = sorted([it for it in ns.db.feed.values() if it.kind == "DEAD" and it.pid == ns.pid], key=lambda i: i.t)
    it = its[-1]; return (it.b, it.c, it.d)
def result():
    log = ns.db.deathDebug
    return [log[i] for i in range(1, len(log)+1) if "Source" in log[i] or "Nothing" in log[i]]
L.execute('ADDON_NS.db.deathTest = true')
L.execute('''C_DeathRecap = { HasRecapEvents = function() return true end,
  GetRecapEvents = function() return { {timestamp=1794396796.564, event="SWING_DAMAGE", overkill=-1, sourceName="Drywallow Snapper", sourceGUID="Creature-0-6846-1-8-4343-E6445C1675", sourceFlags=2632},
    {timestamp=1794396796.564, event="SWING_DAMAGE", overkill=-1, sourceName="Drywallow Vicejaw", sourceGUID="Creature-0-1"} } end }''')
G.FIRE("MIRROR_TIMER_STOP", "BREATH"); G.FIRE("MIRROR_TIMER_STOP", "EXHAUSTION")
G.FIRE("PLAYER_DEAD"); run(5)
print("0 real:", result(), [l for l in ns.db.deathDebug.values() if "timer" in l])
# 1) readable recap: Alliance rogue
L.execute('''C_DeathRecap = { HasRecapEvents = function() return true end,
  GetRecapEvents = function() return { {timestamp=10, sourceName="Stabby-Realm", sourceGUID="Player-1-0001", amount=300, spellName="Ambush"},
                                      {timestamp=8, sourceName="Stabby-Realm", sourceGUID="Player-1-0001", amount=120} } end }''')
G.FIRE("PLAYER_DEAD"); run(5)
print("1 recap:", result(), last_dead())
# 2) recap readable mob
L.execute('C_DeathRecap.GetRecapEvents = function() return { {timestamp=5, sourceName="Fluffy", sourceGUID="Pet-0-1", amount=90} } end')
G.FIRE("PLAYER_DEAD"); run(5); print("2 mob:", result(), last_dead())
# 3) secret recap + drowning
L.execute('''local S = {}; issecretvalue = function(v) return v == S end
C_DeathRecap.GetRecapEvents = function() return { {timestamp=S, sourceName=S} } end''')
G.FIRE("MIRROR_TIMER_START", "BREATH", 0, 60000, -1, False, "Breath")
G.FIRE("PLAYER_DEAD"); run(5); print("3 drown:", result(), last_dead())
G.FIRE("MIRROR_TIMER_STOP", "BREATH"); run(3)
# 4) falling, no recap
L.execute('C_DeathRecap.HasRecapEvents = function() return false end; C_DeathRecap.GetRecapEvents = function() return {} end; FALLING = true; IsFalling = function() return FALLING end')
run(2); L.execute('FALLING = false'); run(0.3)
G.FIRE("PLAYER_DEAD"); run(5); print("4 fall:", result(), last_dead())
# 5) nothing at all
run(5); G.FIRE("PLAYER_DEAD"); run(5); print("5 none:", result(), last_dead())
print("all:", [it.b for it in sorted([i for i in ns.db.feed.values() if i.kind=="DEAD" and i.pid==ns.pid], key=lambda i:i.t)])
print("popup shown:", L.execute('return tostring(ChillanDeathTest and ChillanDeathTest:IsShown())'))
SlashCmd = L.execute('return SlashCmdList.CHILLAN'); SlashCmd("deathtest")
print("report lines:", len(ns.db.deathDebug))
print("\n".join(ns.db.deathDebug[i] for i in range(1, len(ns.db.deathDebug)+1)))
print("FEIL:", list(G.ERRORS.values())[:4])
