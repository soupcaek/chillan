exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
L, G, ns = A
# death lines: pools + rendering
r = L.execute('''
local ns = ADDON_NS
local D = ns.Deaths
local n = 0
for k, v in pairs(D.POOLS) do n = n + #v end
for k, f in pairs(D.FAMILIES) do n = n + #f.lines end
local out = {"total lines: "..n}
for _, cat in ipairs({"PLAYER","FALL","MOB","TURTLE","MURLOC"}) do
  local c, i = cat, D:Pick(cat)
  local item = { a = "Thousand Needles", b = c..":"..i, c = "Snapjaw Turtle", d = "Night Elf Hunter" }
  out[#out+1] = D:Kicker(item).." | "..D:Line(item, "Kenny", "FFFFFF")
end
return table.concat(out, "\\n")
''')
print(r)
# level-up flow
G.FIRE("CHAT_MSG_COMBAT_XP_GAIN", "Defias Thug dies, you gain 120 experience.")
G.FIRE("QUEST_TURNED_IN", 1, 900, 100)
run(60)
lv = L.eval('UnitLevel()')
L.execute('local n = UnitLevel() + 1; UnitLevel = function() return n end')
G.FIRE("PLAYER_XP_UPDATE", "player")
G.FIRE("PLAYER_LEVEL_UP", lv + 1)
run(5)
print("lastRecap:", ns.db.lastRecap and (ns.db.lastRecap["from"], ns.db.lastRecap["to"], ns.db.lastRecap["kills"], ns.db.lastRecap["quests"]))
print("box shown:", L.eval('return ChillanDingBox and ChillanDingBox:IsShown()') if False else L.execute('return tostring(ChillanDingBox and ChillanDingBox:IsShown())'))
L.execute('ADDON_NS.LevelRecapCard:ShowRecap(ADDON_NS.db.lastRecap)')
print("recap shown:", L.execute('return tostring(ChillanLevelRecap:IsShown())'))
print("share:", L.execute('return ADDON_NS.LevelRecap:ShareText(ADDON_NS.db.lastRecap)'))
# combat queue
L.execute('ChillanDingBox:Hide(); InCombatLockdown = function() return true end')
L.execute('ADDON_NS.LevelRecapCard:ShowBox(ADDON_NS.db.lastRecap)')
print("in combat shown:", L.execute('return tostring(ChillanDingBox:IsShown())'))
L.execute('InCombatLockdown = function() return false end'); G.FIRE("PLAYER_REGEN_ENABLED"); run(3)
print("after combat shown:", L.execute('return tostring(ChillanDingBox:IsShown())'))
print("FEIL:", list(G.ERRORS.values())[:4])
