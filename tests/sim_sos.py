exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
nsA.Data.SOS(nsA.Data); run(5)
sa = nsA.Overlays.sos; sb = nsB.Overlays.sos
print("A egen popup:", sa is not None and sa.IsShown(sa), "| B popup:", sb.IsShown(sb), sb.react.label.GetText(sb.react.label))
sb.react._scripts["OnClick"](sb.react); run(6)
item = [it for it in nsA.db.feed.values() if it.kind == "SOS"][-1]
print("A fikk reaksjon:", len(item.reacts) if item.reacts else 0)
print("FEIL:", list(GA.ERRORS.values())[:4], list(GB.ERRORS.values())[:4])
