exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
ns = A[2]
for t in ["cnIQ2 test |cnIQ2:|Hitem:2852::::::::30:::::::::|h[Rough Bronze Leggings]|h|r test",
          "|cnIQ1:|Hitem:4306::::|h[Silk Cloth]|h|r",
          "|cffa335ee|Hitem:12345::::|h[Epic Sword]|h|r",
          "hei @kenny bolt og @Kenny, @all!"]:
    e = ns.EncodeItems(t); print(repr(e)); print("  ->", ns.RenderChatText(ns.Clean(e,200), "D9F0F7"))
print("FEIL:", list(A[1].ERRORS.values())[:3])
