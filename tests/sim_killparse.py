exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
L, G, ns = A
L.execute('COMBATLOG_HONORGAIN = "%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)"; COMBATLOG_HONORGAIN_NO_RANK = "%s dies, honorable kill (Estimated Honor Points: %d)"')
for t in ["Stabby dies, honorable kill Rank: Sergeant (Estimated Honor Points: 42)", "Foxy Femboy dies, honorable kill (Estimated Honor Points: 7)", "random text"]:
    print(repr(t[:30]), "->", L.eval(f'ADDON_NS.Kills:VictimFrom({t!r})'.replace("'", '"')))
