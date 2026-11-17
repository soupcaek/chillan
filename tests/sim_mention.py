exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
ns = A[2]
enc = ns.EncodeItems("look |cffa335ee|Hitem:12345::::|h[Epic Sword]|h|r and |cff1eff00|Hitem:999|h[Boots]|h|r")
print("enc:", enc)
print("render:", ns.RenderChatText(enc, "D9F0F7"))
ns.Data.SendChat(ns.Data, "check |cffa335ee|Hitem:12345::::|h[Epic Sword]|h|r @all"); run(5)
last = list(B[2].db.chat.values())[-1]
print("B fikk:", last.text, "mention:", last.mention)
E = ns.EventWindow; inp = E.input; e = inp.edit
e.SetFocus(e); ns.activeChatBox = e
e.SetText(e, "hei @"); e._scripts["OnTextChanged"](e, True)
import re
ml = None
# find list via global? use Accept through Tab
print("før tab:", e.GetText(e))
e._scripts["OnTabPressed"](e)
print("etter tab:", e.GetText(e))
e.SetText(e, "yo @gr"); e._scripts["OnTextChanged"](e, True); e._scripts["OnTabPressed"](e)
print("etter @gr+tab:", e.GetText(e))
print("FEIL:", list(A[1].ERRORS.values())[:5], list(B[1].ERRORS.values())[:3])
for pid, p in ns.db.people.items():
    print(pid == ns.pid, p.main, p.alias)
nm = B[2].db.people[B[2].pid].main
e.SetText(e, "yo @" + nm[:3].lower()); e._scripts["OnTextChanged"](e, True); e._scripts["OnTabPressed"](e)
print("etter prefix:", e.GetText(e))
