exec(open("sim_v08.py").read().split("# quest-kompis")[0])
I_A, I_B = A[2].Ideas, B[2].Ideas
I_A.ClaimAdmin(I_A); run(4)
I_A.Add(I_A, "Durability on minibar", "show it next to online count"); run(4)
I_B.Add(I_B, "Auto repair", ""); run(4)
ideaA = [i for i in A[2].db.ideas.values() if i.title == "Durability on minibar"][0]
ideaB = [i for i in A[2].db.ideas.values() if i.title == "Auto repair"][0]
I_B.Vote(I_B, ideaA.id, 1); I_A.Vote(I_A, ideaB.id, -1); run(4)
print("A ser:", [(i.title, I_A.Score(I_A, i)) for i in I_A.List(I_A, "open").values()])
print("B ser:", [(i.title, I_B.Score(I_B, i)) for i in I_B.List(I_B, "open").values()])
print("B admin:", I_B.Admin(I_B) == A[2].pid)
I_B.SetStatus(I_B, ideaA.id, "done"); run(4)   # ikke admin – skal ignoreres
print("status etter B prøver:", [i.status for i in B[2].db.ideas.values() if i.title.startswith("Dur")])
I_A.SetStatus(I_A, ideaA.id, "done"); run(4)
print("status etter admin:", [i.status for i in B[2].db.ideas.values() if i.title.startswith("Dur")])
I_B.Delete(I_B, ideaA.id); run(4)   # B er ikke forfatter – ignoreres hos A
print("A sletting ignorert:", not ideaA.deleted)
print(I_A.ExportText(I_A))
A[1].SlashCmdList.CHILLAN("ideas")
for c,l in ((A,"A"),(B,"B")): print("FEIL", l, list(c[1].ERRORS.values())[:3])
