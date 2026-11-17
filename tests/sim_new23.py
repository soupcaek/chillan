exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
for L in (LA, LB):
    L.execute('''
    GEAR = { [1]="|cff0070dd|Hitem:1001::::::::20:::::::|h[Helm]|h|r", [5]="|cff1eff00|Hitem:1005:0:0:0:0:0:1017:0::20|h[Vest of the Bear]|h|r" }
    GetInventoryItemLink = function(u, s) return GEAR[s] end
    C_Item = C_Item or {}
    C_Item.GetDetailedItemLevelInfo = function(s) local id = tonumber(s:match("item:(%d+)")) return id and (id - 980) end
    ''')
LB.execute('GEAR[1] = "|cffa335ee|Hitem:1010::::::::20:::::::|h[Epic Helm]|h|r"')
nsB.Gear.SendTo(nsB.Gear, nsA.Comm.MyFull(nsA.Comm)); run(5)
pb = nsA.db.people[nsB.pid]
print("A har Bs gear:", dict(pb.gear) if pb.gear else None)
print("compare:", dict(nsA.Gear.Compare(nsA.Gear, pb)))
W = nsA.Window; W.Create(W); W.frame.Show(W.frame); W.OpenCompare(W, nsB.pid)
ct = W.tabs["compare"]
# gear mode
for b in []: pass
nsA.PersonCard.Show(nsA.PersonCard, W.frame, nsB.pid)
print("card gear:", nsA.PersonCard.frame.gear.GetText(nsA.PersonCard.frame.gear))
# legend
nsA.Legend.Backfill(nsA.Legend)
wk = list(nsA.Legend.Weeks(nsA.Legend).values())
ch = nsA.Legend.Chapter(nsA.Legend, wk[-1])
print("legend:", ch.title, ch.range, "|", list(ch.story.values())[:3])
W.Select(W, "stats"); st = W.tabs["stats"]; st.SetPage(st, "legend")
# briefing
nsA.Briefing.Show(nsA.Briefing, True)
bc = GA.ChillanBriefing
print("briefing:", bc.title.GetText(bc.title), "|", bc.body.GetText(bc.body)[:200])
print("FEIL:", list(GA.ERRORS.values())[:5], list(GB.ERRORS.values())[:3])
W.OpenCompare(W, nsB.pid); ct = W.tabs["compare"]
print(GA.ERRORS and list(GA.ERRORS.values())[:3])
ct.SetMode(ct, "gear")
print("gear mode errs:", list(GA.ERRORS.values())[:3])
