exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
ns = A[2]; W = ns.Window
W.Create(W); W.frame.Show(W.frame); W.Select(W, "stats")
st = W.tabs["stats"]; st.Refresh(st)
G = A[1]
G.ADVANCE(25)
st.NextSpot(st, 1)
print("FEIL:", list(G.ERRORS.values())[:5])
import re
L = A[0]
for i in range(6):
    st.NextSpot(st, 1)
    print(L.eval('''(function() local r = ChillanSpotDbg return r end)()'''))
