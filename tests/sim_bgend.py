# 1.4.19 BG result line: no "MVP <yourself>" when you were alone
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
for d in ["Entec:4:0:1", "Entec:4:230:1:1080", "Simon:12:300:3:900", "Entec:4"]:
    print(d, "->", LA.eval('table.concat(ADDON_NS.BGEndBits({ char = "Entec-Realm", d = "%s" }), " | ")' % d))
print("FEIL:", [e for e in list(GA.ERRORS.values()) if 'HookScript' not in str(e)][:5])
