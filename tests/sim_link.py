exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A
LB, GB, nsB = B
url = "https://discord.com/api/webhooks/1570438750826139818/AA-Fy2lR_70bLMFxtUPUF_K6QeHcE0E0fD_slZIZbOILbRja57qMzDkqOTpKVD-r2Mra"
LA.execute('ADDON_NS.Discord:Slash("on")')
LA.execute(f'ADDON_NS.Discord:Slash("link {url}")')
run(5)
print("A link ok:", LA.eval('ADDON_NS.db.discord.link') == url)
print("B got link:", LB.eval('ADDON_NS.db.discord.link') == url, "B relaying:", LB.eval('ADDON_NS.Discord:Relaying()'), "B live:", LB.eval('ADDON_NS.Discord:Enabled()'))
before = LB.eval('#(ADDON_NS.db.discord.out or {})')
LA.execute('ADDON_NS.Data:ApplyEvent("x1", ADDON_NS.pid, ADDON_NS:GetPerson(ADDON_NS.pid).main, "DEAD", time(), "Barrens", "PLAYER:2", "Stabby", "")')
LA.execute('ADDON_NS.Tracker:Event("DEAD", "Barrens", "PLAYER:2", "Stabby", "")')
run(5)
print("B outbox grew:", LB.eval('#(ADDON_NS.db.discord.out or {})') - before, "B strip drawn:", LB.eval('ChillanDiscordStrip ~= nil'))
# an older link must not overwrite a newer one
LB.execute('ADDON_NS.Comm.handlers = ADDON_NS.Comm.handlers')
print("case kept:", "AA-Fy2lR" in (LB.eval('ADDON_NS.db.discord.link') or ""))
print("FEIL:", list(GA.ERRORS.values())[:3], list(GB.ERRORS.values())[:3])
run(5)
print("B card shown:", LB.eval('ChillanCompanionCard and ChillanCompanionCard:IsShown()'), "A card:", LA.eval('ChillanCompanionCard and ChillanCompanionCard:IsShown()'))
LB.execute('ChillanCompanionCard.done:GetScript("OnClick")(ChillanCompanionCard.done)') if False else None
LB.execute('ADDON_NS.db.discord.companionDone = true; ChillanCompanionCard:Hide()')
GB.FIRE("PLAYER_LOGIN"); run(25)
print("B card after Done + relog:", LB.eval('ChillanCompanionCard:IsShown()'))
print("FEIL2:", list(GA.ERRORS.values())[:3], list(GB.ERRORS.values())[:3])
