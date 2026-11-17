exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
ns = A[2]; W = ns.Window
B = ns.Badges
print("changelog før:", B.Count(B, "changelog"), "ideas:", B.Count(B, "ideas"))
for k in ["friends","quests","chat","stats","ach","ideas","more","settings","changelog"]:
    W.Select(W, k)
print("changelog etter:", B.Count(B, "changelog"), "total:", B.Total(B))
W.Select(W, "friends"); W.tabs["friends"].Refresh(W.tabs["friends"])
print("FEIL:", list(A[1].ERRORS.values())[:5])
st = W.tabs["stats"]
for pg, h in [("overview",None),("history","feed"),("history","milestones"),("history","facts")]:
    st.SetPage(st, pg, h)
W.Select(W, "friends"); fr = W.tabs["friends"]; fr.Refresh(fr)
W.Select(W, "quests"); W.Select(W, "chat"); W.Select(W, "ideas")
ns.VERSION = "0.17.0"; ns.Data.CheckVersion(ns.Data, "9.9.9", list(ns.db.people.keys())[0]); W.UpdateBadges(W)
print("upd:", W.updBtn.text.GetText(W.updBtn.text), W.updBtn.IsShown(W.updBtn))
print("FEIL5:", list(A[1].ERRORS.values())[:5])
print("VERSION", ns.VERSION, "newest", ns.newestVersion)
