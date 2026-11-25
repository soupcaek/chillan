exec(open("sim.py").read().split("A = client(")[0])
A = client("Grimtusk", "WARRIOR", "Orc", 33, "Barrens")
B = client("Kenny Bolt", "ROGUE", "Undead", 32, "Barrens")
C = client("Svenna", "ROGUE", "Undead", 34, "Ashenvale")
cl=[A,B,C]; full={id(A):"Grimtusk-ClassicBetaPvP", id(B):"Kenny Bolt-ClassicBetaPvP", id(C):"Svenna-ClassicBetaPvP"}
def route():
    outs=[(c,list(c[1].OUTBOX.values())) for c in cl]
    for c in cl: c[1].OUTBOX=c[0].table_from([])
    for src,out in outs:
        for m in out:
            for dst in cl:
                if dst is src: continue
                if m[3]=="WHISPER" and m[4]!=full[id(dst)]: continue
                dst[1].FIRE("CHAT_MSG_ADDON", m[1], m[2], m[3], full[id(src)], m[4])
def run(sec):
    for i in range(int(sec/2)):
        for c in cl: c[1].ADVANCE(2)
        route()
for c in cl: c[2].SetCode(c[2],"CHILL-TEST")
for c in cl: c[1].FIRE("PLAYER_LOGIN"); c[1].FIRE("PLAYER_ENTERING_WORLD")
run(200)
LA, GA, nsA = A; LB, GB, nsB = B; LC, GC, nsC = C
for L in (LA, LB, LC):
    L.execute('COMBATLOG_HONORGAIN = "%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)"')
LA.execute('ADDON_NS.db.settings.combatQueue = false')
msg = "Stabby dies, honorable kill Rank: Sergeant (Estimated Honor Points: 42)"
GA.FIRE("CHAT_MSG_COMBAT_HONOR_GAIN", msg)
GB.FIRE("CHAT_MSG_COMBAT_HONOR_GAIN", msg)
run(5)
def kills(L):
    return L.execute('''local n, out = 0, {} for _, it in ipairs(ADDON_NS.db.feed) do if it.kind == "KILL" then n = n + 1 out[#out+1] = ADDON_NS.Kills:Names(it) .. " | " .. (ADDON_NS.Kills:Line(it, ADDON_NS.Kills:Names(it)) or "?") end end return n .. " :: " .. table.concat(out, " || ")''')
print("A:", kills(LA)); print("B:", kills(LB)); print("C:", kills(LC))
print("C popup title:", LC.eval('ChillanDing and ChillanDing.title and ChillanDing.title:GetText()') if False else LC.execute('local d = ADDON_NS.Overlays and ADDON_NS.Overlays.ding return d and d:IsShown() and d.title:GetText() or "no popup frame"'))
# revenge: B has Stabby2 in enemy log
LB.execute('ADDON_NS.db.enemies = ADDON_NS.db.enemies or {}; ADDON_NS.db.enemies["foxy"] = {name="Foxy"}')
GB.FIRE("CHAT_MSG_COMBAT_HONOR_GAIN", "Foxy dies, honorable kill Rank: Private (Estimated Honor Points: 10)")
run(3)
print("revenge on C:", LC.execute('for i = #ADDON_NS.db.feed, 1, -1 do local it = ADDON_NS.db.feed[i] if it.kind == "KILL" and it.c == "Foxy" then return it.b .. " / " .. ADDON_NS.Kills:Kicker(it) end end return "none"'))
# battleground: nothing
LA.execute('IsInInstance = function() return true, "pvp" end')
GA.FIRE("CHAT_MSG_COMBAT_HONOR_GAIN", "Bgguy dies, honorable kill Rank: Private (Estimated Honor Points: 10)")
run(3)
print("BG kill posted:", LC.execute('for _, it in ipairs(ADDON_NS.db.feed) do if it.c == "Bgguy" then return "YES" end end return "no"'))
print("FEIL:", list(GA.ERRORS.values())[:3], list(GB.ERRORS.values())[:3], list(GC.ERRORS.values())[:3])
