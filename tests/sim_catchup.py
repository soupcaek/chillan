exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
L, G, ns = A
L.execute('ADDON_NS.Discord:Slash("on")'); run(2)
L.execute('ADDON_NS.db.discord.since = time() - 10000')
before = L.eval('#ADDON_NS.db.discord.out')
for i, (k, a, b) in enumerate([("DEAD","Barrens","PLAYER:3"),("DING","30","1000"),("LOOT","6504","4"),("LOOT","1234","2")]):
    L.execute(f'ADDON_NS.Data:ApplyEvent("old{i}", ADDON_NS.pid, ADDON_NS:GetPerson(ADDON_NS.pid).main, "{k}", time() - 600, "{a}", "{b}", "Stabby", "")')
n = L.eval('ADDON_NS.Discord:CatchUp()')
n2 = L.eval('ADDON_NS.Discord:CatchUp()')
print("caught up:", n, "second run:", n2, "outbox grew:", L.eval('#ADDON_NS.db.discord.out') - before)
import json
for i in range(1, L.eval('#ADDON_NS.db.discord.out')+1):
    j = L.eval(f'ADDON_NS.db.discord.out[{i}].j')
    if j and '"cu":1' in j: print(json.loads(j)["k"], json.loads(j).get("cu"))
run(30)
print("FEIL:", list(G.ERRORS.values())[:3])
