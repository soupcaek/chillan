exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
W = A[2].Window
W.Select(W, "stats")
st = W.tabs["stats"]
for pg, h in [("overview",None),("graph",None),("titles",None),("history","milestones"),("history","dungeons"),("history","facts")]:
    st.SetPage(st, pg, h)
W.Select(W, "settings")
print("FEIL:", list(A[1].ERRORS.values())[:5])
