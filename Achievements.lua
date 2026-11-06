-- Chillan? – achievements: definisjoner, tellere, evaluering og deling
local ADDON, ns = ...
local A = {}
ns.Ach = A

A.TIERS = {
  B = { name = "Bronse", points = 5, color = "C9946A" },
  S = { name = "Sølv", points = 10, color = "C8D1DC" },
  G = { name = "Gull", points = 25, color = "E0C068" },
  L = { name = "Legendarisk", points = 50, color = "B9AEDB" },
}

A.CATS = {
  { key = "lvl", name = "Leveling" }, { key = "first", name = "Først i gjengen" },
  { key = "time", name = "Tid og økter" }, { key = "quest", name = "Quests" },
  { key = "gold", name = "Gull" }, { key = "death", name = "Død og skam" },
  { key = "pvp", name = "PvP" }, { key = "gang", name = "Gjengen" },
  { key = "dung", name = "Dungeons og raid" }, { key = "expl", name = "Utforsking" },
  { key = "prof", name = "Profesjoner" }, { key = "gear", name = "Utstyr og mounts" },
  { key = "tempo", name = "Tempo" }, { key = "fun", name = "Hemmelige" },
}

---------------------------------------------------------------------------
-- Tellere (lagres per konto)
---------------------------------------------------------------------------
local function db() ns.db.cnt = ns.db.cnt or {} return ns.db.cnt end
function ns.Cnt(key, n)
  local c = db()
  c[key] = (c[key] or 0) + (n or 1)
  A:CheckSoon()
end
function ns.CntDay(key, n)
  local c = db()
  local day = date("%Y-%m-%d")
  c[key] = c[key] or {}
  c[key][day] = (c[key][day] or 0) + (n or 1)
  -- behold bare de siste dagene
  local keys = {}
  for k in pairs(c[key]) do keys[#keys + 1] = k end
  if #keys > 10 then
    table.sort(keys)
    for i = 1, #keys - 10 do c[key][keys[i]] = nil end
  end
  A:CheckSoon()
end
function ns.CntMax(key, v)
  local c = db()
  if v and v > (c[key] or 0) then c[key] = v A:CheckSoon() end
end
function ns.CntSet(key, sub)
  local c = db()
  c[key] = c[key] or {}
  if sub and sub ~= "" and not c[key][sub] then
    c[key][sub] = true
    A:CheckSoon()
  end
end
function ns.CntFlag(key)
  local c = db()
  if not c[key] then c[key] = true A:CheckSoon() end
end

local function cnt(k) local v = db()[k] return type(v) == "number" and v or 0 end
local function today(k) local t = db()[k] return type(t) == "table" and (t[date("%Y-%m-%d")] or 0) or 0 end
local function setSize(k)
  local n = 0
  for _ in pairs(db()[k] or {}) do n = n + 1 end
  return n
end
local function has(k) return db()[k] and true or false end
local function inSet(k, name) return (db()[k] or {})[name] and true or false end

local function me() return ns:GetPerson(ns.pid, true) end
local function stat(k) return (me().stats or {})["t" .. k] or 0 end
local function maxLevel() return ns:PersonMaxLevel(me()) end
local function maxPlayed()
  local m = 0
  for _, c in pairs(me().chars) do if (c.played or 0) > m then m = c.played end end
  return m
end
local function prof(name)
  for _, p in ipairs(me().profs or {}) do if p.name == name then return p.skill end end
  return 0
end
local function profsAtLeast(v)
  local n = 0
  for _, p in ipairs(me().profs or {}) do if (p.skill or 0) >= v then n = n + 1 end end
  return n
end
local function first(key)
  local f = ns.db.firsts[key]
  return f and f.pid == ns.pid
end
local function altsOver(lvl)
  local n = 0
  for _, c in pairs(me().chars) do if (c.level or 0) >= lvl then n = n + 1 end end
  return n
end

---------------------------------------------------------------------------
-- Definisjoner: { id, kategori, nivå, navn, beskrivelse, verdi-funksjon, mål, hemmelig }
---------------------------------------------------------------------------
local defs = {}
local function D(id, cat, tier, name, desc, value, goal, secret)
  defs[#defs + 1] = { id = id, cat = cat, tier = tier, name = name, desc = desc, value = value, goal = goal or 1, secret = secret }
end
local function V(fn) return fn end
local function flag(k) return function() return has(k) and 1 or 0 end end

-- Leveling
local L = { {5,"Første skritt","B"},{10,"Tosifret","B"},{15,"Lærling","B"},{20,"Eventyrer","B"},{25,"Veteran i emning","S"},
  {30,"Halvveis-ish","S"},{35,"Erfaren","S"},{40,"Rutinert","S"},{45,"Herdet","G"},{50,"Nesten der","G"},{55,"Siste etappe","G"},{60,"Legende","L"} }
for _, l in ipairs(L) do D("L" .. l[1], "lvl", l[3], l[2], "Nå level " .. l[1], maxLevel, l[1]) end
D("LV2S", "lvl", "S", "Dobbeltding", "2 levels i én økt", V(function() return cnt("bestSessionLevels") end), 2)
D("LV3S", "lvl", "G", "Ding-maskin", "3 levels i én økt", V(function() return cnt("bestSessionLevels") end), 3)
D("LVNT", "lvl", "S", "Nattding", "Ding mellom 00:00 og 05:00", flag("dingNight"))
D("LVDG", "lvl", "B", "Ding i dypet", "Ding inne i en dungeon", flag("dingDungeon"))
D("LVRS", "lvl", "B", "Uthvilt", "Ding med rested XP", flag("dingRested"))
D("LVAL", "lvl", "S", "Altoholiker", "Ha 3 karakterer over level 10", V(function() return altsOver(10) end), 3)

-- Først i gjengen
for _, n in ipairs({ 10, 20, 30, 40, 50, 60 }) do
  D("F" .. n, "first", n >= 40 and "G" or "S", "Først til " .. n, "Først i gjengen til level " .. n, V(function() return first("L" .. n) and 1 or 0 end))
end
D("FMNT", "first", "G", "Først med mount", "Først i gjengen med mount", V(function() return first("MOUNT") and 1 or 0 end))
D("FEPC", "first", "G", "Først med epic", "Først i gjengen med et episk drop", V(function() return first("EPIC") and 1 or 0 end))

-- Tid og økter
local D1 = 86400
for i, t in ipairs({ {1,"En hel dag","B"},{2,"Helgetur","S"},{5,"Hekta","S"},{10,"Ingen vei tilbake","G"},{20,"Bor i Azeroth","L"} }) do
  D("PL" .. t[1], "time", t[3], t[2], "/played " .. t[1] .. (t[1] == 1 and " døgn" or " døgn") .. " på én karakter", maxPlayed, t[1] * D1)
end
D("SE3", "time", "B", "Kveldsøkt", "Én økt på 3 timer", V(function() return stat("Longest") end), 3 * 3600)
D("SE6", "time", "S", "Maraton", "Én økt på 6 timer", V(function() return stat("Longest") end), 6 * 3600)
D("SE10", "time", "G", "Ultramaraton", "Én økt på 10 timer", V(function() return stat("Longest") end), 10 * 3600)
D("ST3", "time", "B", "Vane", "3 dager på rad", V(function() return ns.Tracker:Streak((me().stats or {}).days) end), 3)
D("ST7", "time", "S", "Ukesrytme", "7 dager på rad", V(function() return ns.Tracker:Streak((me().stats or {}).days) end), 7)
D("ST14", "time", "G", "Uten pause", "14 dager på rad", V(function() return ns.Tracker:Streak((me().stats or {}).days) end), 14)
D("ST30", "time", "L", "Trofast", "30 dager på rad", V(function() return ns.Tracker:Streak((me().stats or {}).days) end), 30)
D("OWL", "time", "S", "Nattugle", "Pålogget kl. 03:00", flag("online03"))
D("BIRD", "time", "S", "Morgenfugl", "Pålogget kl. 06:00", flag("online06"))
D("WKND", "time", "S", "Helgekriger", "10 timer på én helg", V(function() return cnt("bestWeekend") end), 10 * 3600)

-- Quests
for _, q in ipairs({ {10,"Oppdragstaker","B"},{50,"Hjelpsom","B"},{100,"Questmaskin","S"},{250,"Slitesterk","S"},{500,"Arbeidsjern","G"},{1000,"Tusen takk","G"},{2000,"Questguden","L"} }) do
  D("Q" .. q[1], "quest", q[3], q[2], q[1] .. " quests totalt", V(function() return stat("Quests") end), q[1])
end
D("QSES", "quest", "S", "Produktiv kveld", "20 quests i én økt", V(function() return cnt("bestSessionQuests") end), 20)
D("QDAY", "quest", "G", "Dagsverk", "40 quests på én dag", V(function() return today("questsDay") > 0 and math.max(today("questsDay"), cnt("bestDayQuests")) or cnt("bestDayQuests") end), 40)
D("QKNG", "quest", "G", "Ukens questkonge", "Flest quests i gjengen en uke", flag("kingQuests"))

-- Gull (kobber)
local G = 10000
for _, g in ipairs({ {10,"Lommepenger","B"},{100,"Sparebøssa","S"},{500,"Velstående","G"},{1000,"Goblin","L"} }) do
  D("GE" .. g[1], "gold", g[3], g[2], "Tjen " .. g[1] .. "g totalt", V(function() return stat("Gold") end), g[1] * G)
end
for _, g in ipairs({ {50,"Feit lommebok","S"},{100,"Rikmann","G"},{500,"Krøsus","L"} }) do
  D("GH" .. g[1], "gold", g[3], g[2], "Ha " .. g[1] .. "g på én gang", V(function() return cnt("maxMoney") end), g[1] * G)
end
D("GS10", "gold", "B", "Lønningsdag", "Tjen 10g i én økt", V(function() return cnt("bestSessionGold") end), 10 * G)
D("GS50", "gold", "G", "Gullgruve", "Tjen 50g i én økt", V(function() return cnt("bestSessionGold") end), 50 * G)
D("GKNG", "gold", "G", "Ukens kremmer", "Mest gull i gjengen en uke", flag("kingGold"))

-- Død og skam
D("DE1", "death", "B", "Første gang er verst", "Dø for første gang", V(function() return stat("Deaths") end), 1)
D("DE10", "death", "B", "Vanen tro", "10 dødsfall", V(function() return stat("Deaths") end), 10)
D("DE25", "death", "S", "Klumsete", "25 dødsfall", V(function() return stat("Deaths") end), 25)
D("DE50", "death", "G", "Spirit Healer-stamgjest", "50 dødsfall", V(function() return stat("Deaths") end), 50)
D("DE100", "death", "L", "Udødelig? Nei.", "100 dødsfall", V(function() return stat("Deaths") end), 100)
D("DES3", "death", "S", "Dårlig dag", "3 dødsfall i én økt", V(function() return cnt("bestSessionDeaths") end), 3)
D("DED5", "death", "G", "Katastrofekveld", "5 dødsfall på én dag", V(function() return math.max(today("deathsDay"), cnt("bestDayDeaths")) end), 5)
D("DELG", "death", "S", "Forbannet", "Dø innen 2 min etter innlogging", flag("deathAfterLogin"))
D("DEDG", "death", "S", "Kort glede", "Dø innen 2 min etter en ding", flag("deathAfterDing"))
D("DEZ5", "death", "S", "Stammested", "Dø 5 ganger i samme sone", V(function() return cnt("maxDeathsZone") end), 5)
D("DESTV", "death", "G", "Stranglethorn-turist", "Dø 10 ganger i Stranglethorn Vale", V(function() return (db().deathsByZone or {})["Stranglethorn Vale"] or 0 end), 10)
D("DEDN", "death", "B", "Dungeon-offer", "Dø inne i en dungeon", flag("deathDungeon"))
D("DE60", "death", "G", "Toppen er nådd", "Dø på level 60", flag("deathAt60"))
D("DENO", "death", "S", "Forsiktig sjel", "10 levels uten å dø", V(function() return cnt("bestLevelsNoDeath") end), 10)
D("DEWK", "death", "G", "Ufeilbarlig", "En hel uke (minst 5 t) uten å dø", flag("weekNoDeath"))
D("DKNG", "death", "S", "Skammens konge", "Flest dødsfall i gjengen en uke", flag("kingDeaths"))

-- PvP
for _, k in ipairs({ {1,"Første blod","B"},{10,"Fiende av Alliansen","B"},{50,"Plageånd","S"},{100,"Krigshisser","S"},{250,"Slakter","G"},{500,"Horde-helt","G"},{1000,"Lok'tar Ogar","L"} }) do
  D("K" .. k[1], "pvp", k[3], k[2], k[1] .. " honorable kills", V(function() return stat("Kills") end), k[1])
end
D("BG1", "pvp", "B", "Seier!", "Vinn en battleground", V(function() return cnt("bgWins") end), 1)
D("BG10", "pvp", "G", "Krigsherre", "Vinn 10 battlegrounds", V(function() return cnt("bgWins") end), 10)
for _, b in ipairs({ {"WSG","Ulveflagg","Warsong Gulch"},{"AB","Basebygger","Arathi Basin"},{"AV","Fjellgeneral","Alterac Valley"},{"DI","Øyas hersker","Darkspear Islands"} }) do
  D("BG" .. b[1], "pvp", "S", b[2], "Vinn " .. b[3], V(function() return inSet("bgWonMaps", b[3]) and 1 or 0 end))
end
D("SOS1", "pvp", "B", "Ropte på hjelp", "Send din første SOS", V(function() return cnt("sosSent") end), 1)
D("SOSA", "pvp", "B", "Rask hjelp", "Svar «på vei» på en SOS", V(function() return cnt("sosAnswered") end), 1)
D("SOS10", "pvp", "G", "Livvakt", "Svar på 10 SOS", V(function() return cnt("sosAnswered") end), 10)

-- Gjengen
D("CH1", "gang", "B", "Hei, gjengen!", "Første melding i gjengchatten", V(function() return cnt("chatMsgs") end), 1)
D("CH100", "gang", "S", "Pratmaker", "100 meldinger i gjengchatten", V(function() return cnt("chatMsgs") end), 100)
D("CH1K", "gang", "G", "Snakkesalig", "1000 meldinger i gjengchatten", V(function() return cnt("chatMsgs") end), 1000)
D("CHDY", "gang", "S", "Kjeftesmelle", "50 meldinger på én dag", V(function() return math.max(today("chatDay"), cnt("bestDayChat")) end), 50)
D("GG10", "gang", "B", "Heiagjeng", "Gi 10 gratulasjoner", V(function() return cnt("gratsGiven") end), 10)
D("GG50", "gang", "S", "Supporter", "Gi 50 gratulasjoner", V(function() return cnt("gratsGiven") end), 50)
D("GG200", "gang", "G", "Gjengens mamma", "Gi 200 gratulasjoner", V(function() return cnt("gratsGiven") end), 200)
D("GR10", "gang", "S", "Populær", "Få 10 gratulasjoner", V(function() return cnt("gratsGot") end), 10)
D("GR50", "gang", "G", "Kjendis", "Få 50 gratulasjoner", V(function() return cnt("gratsGot") end), 50)
D("GR5D", "gang", "G", "Festens midtpunkt", "Få 5 gratulasjoner på én ding", V(function() return cnt("maxGratsOneDing") end), 5)
D("LGH10", "gang", "S", "Skadefryd", "Le av 10 dødsfall", V(function() return cnt("laughsGiven") end), 10)
D("F10", "gang", "S", "Respekt", "Trykk «F» 10 ganger", V(function() return cnt("fGiven") end), 10)
D("LGHD", "gang", "G", "Klassens klovn", "Bli ledd av 20 ganger", V(function() return cnt("laughedAt") end), 20)
D("GRP2", "gang", "B", "Duo", "Vær i gruppe med 1 fra gjengen", V(function() return cnt("maxGangGroup") end), 2)
D("GRP3", "gang", "B", "Trio", "Vær i gruppe med 2 fra gjengen", V(function() return cnt("maxGangGroup") end), 3)
D("GRP5", "gang", "S", "Full gjeng", "5-manns gruppe bare med gjengen", V(function() return cnt("maxGangGroup") end), 5)
D("GRP10", "gang", "G", "Raidgjeng", "Raid med 10 fra gjengen", V(function() return cnt("maxGangGroup") end), 10)
D("ON8", "gang", "G", "Alle mann på dekk", "8 fra gjengen online samtidig", V(function() return cnt("maxOnline") end), 8)
D("POLL", "gang", "B", "Demokrat", "Lag en avstemning", V(function() return cnt("pollsCreated") end), 1)
D("VOTE", "gang", "S", "Stemmekveg", "Stem i 20 avstemninger", V(function() return cnt("votes") end), 20)
D("EVNT", "gang", "B", "Planlegger", "Lag en avtale", V(function() return cnt("eventsCreated") end), 1)
D("RSVP", "gang", "S", "Møter opp", "Svar «kommer» på 10 avtaler", V(function() return cnt("rsvpYes") end), 10)
D("MATS", "gang", "B", "Trenger hjelp", "Legg ut en mats-forespørsel", V(function() return cnt("matsPosted") end), 1)
D("MATO", "gang", "S", "Leverandør", "Svar «Jeg har!» 10 ganger", V(function() return cnt("matsOffered") end), 10)

-- Dungeons og raid
D("DG1", "dung", "B", "Ned i mørket", "Første dungeon", V(function() return cnt("dungeonRuns") end), 1)
D("DG5", "dung", "B", "Dungeonkrabber", "5 dungeon-runs", V(function() return cnt("dungeonRuns") end), 5)
D("DG10", "dung", "S", "Hulebeboer", "10 dungeon-runs", V(function() return cnt("dungeonRuns") end), 10)
D("DG25", "dung", "G", "Dypdykker", "25 dungeon-runs", V(function() return cnt("dungeonRuns") end), 25)
D("DG50", "dung", "L", "Innbitt", "50 dungeon-runs", V(function() return cnt("dungeonRuns") end), 50)
D("DGU5", "dung", "S", "Fem på rad", "5 forskjellige dungeons", V(function() return setSize("dungeonsSeen") end), 5)
D("DGU10", "dung", "G", "Samler", "10 forskjellige dungeons", V(function() return setSize("dungeonsSeen") end), 10)
D("RD1", "dung", "S", "Raid-debut", "Første raid", V(function() return setSize("raidsSeen") end), 1)
D("RDBD", "dung", "G", "Barrow Deeps", "Gå inn i Barrow Deeps", V(function() return inSet("raidsSeen", "Barrow Deeps") and 1 or 0 end))
D("RDHS", "dung", "L", "Hyjal Summit", "Gå inn i Hyjal Summit", V(function() return inSet("raidsSeen", "Hyjal Summit") and 1 or 0 end))
D("DGGG", "dung", "G", "Gjengtur", "En dungeon der alle fem er fra gjengen", flag("gangDungeon"))
D("DGD2", "dung", "S", "Dobbel dose", "2 dungeons på én kveld", V(function() return math.max(today("dungeonsDay"), cnt("bestDayDungeons")) end), 2)

-- Utforsking
D("Z10", "expl", "B", "Turist", "Besøk 10 soner", V(function() return setSize("zonesSeen") end), 10)
D("Z20", "expl", "S", "Reisende", "Besøk 20 soner", V(function() return setSize("zonesSeen") end), 20)
D("Z30", "expl", "G", "Oppdagelsesreisende", "Besøk 30 soner", V(function() return setSize("zonesSeen") end), 30)
D("Z40", "expl", "L", "Kartograf", "Besøk 40 soner", V(function() return setSize("zonesSeen") end), 40)
D("ZCAP", "expl", "S", "Hjemme i alle byer", "Besøk Orgrimmar, Thunder Bluff og Undercity", V(function()
  local n = 0
  for _, z in ipairs({ "Orgrimmar", "Thunder Bluff", "Undercity" }) do if inSet("zonesSeen", z) then n = n + 1 end end
  return n
end), 3)
D("ZBB", "expl", "B", "Pirathavn", "Besøk Booty Bay", V(function() return inSet("subzonesSeen", "Booty Bay") and 1 or 0 end))
D("ZGZ", "expl", "B", "Ørkenrotte", "Besøk Gadgetzan", V(function() return inSet("subzonesSeen", "Gadgetzan") and 1 or 0 end))
D("ZEL", "expl", "S", "Frostbitt", "Besøk Everlook", V(function() return inSet("subzonesSeen", "Everlook") and 1 or 0 end))
D("Z10H", "expl", "S", "Stamgjest", "10 timer i samme sone", V(function()
  local m = 0
  for _, v in pairs((me().stats or {}).zones or {}) do if v > m then m = v end end
  return m
end), 10 * 3600)
D("LAYR", "expl", "S", "Layer-hopper", "Bytt sone eller layer 100 ganger", V(function() return cnt("zoneChanges") end), 100)

-- Profesjoner
D("P75", "prof", "B", "Lærling", "Én profesjon på 75", V(function() return profsAtLeast(75) end), 1)
D("P150", "prof", "B", "Svenn", "Én profesjon på 150", V(function() return profsAtLeast(150) end), 1)
D("P225", "prof", "S", "Ekspert", "Én profesjon på 225", V(function() return profsAtLeast(225) end), 1)
D("P300", "prof", "G", "Mester", "Én profesjon på 300", V(function() return profsAtLeast(300) end), 1)
D("P300X2", "prof", "L", "Dobbel mester", "To profesjoner på 300", V(function() return profsAtLeast(300) end), 2)
D("PCOOK", "prof", "S", "Mesterkokk", "Cooking 300", V(function() return prof("Cooking") end), 300)
D("PFISH", "prof", "S", "Fiskehelt", "Fishing 300", V(function() return prof("Fishing") end), 300)
D("PFA", "prof", "S", "Lege", "First Aid 300", V(function() return prof("First Aid") end), 300)
D("PWK50", "prof", "S", "Flittig", "+50 skill i en profesjon på én uke", V(function()
  local m = 0
  for _, p in ipairs(me().profs or {}) do if p.base and (p.skill - p.base) > m then m = p.skill - p.base end end
  return m
end), 50)

-- Utstyr og mounts
D("EP1", "gear", "S", "Lilla glede", "Første episke drop", V(function() return cnt("epics") end), 1)
D("EP5", "gear", "G", "Epic-samler", "5 episke drops", V(function() return cnt("epics") end), 5)
D("EP15", "gear", "L", "Utstyrsfreak", "15 episke drops", V(function() return cnt("epics") end), 15)
for _, i in ipairs({ {20,"Godt kledd","B"},{40,"Velutstyrt","S"},{55,"Tungt bevæpnet","G"},{65,"Raid-klar","L"} }) do
  D("IL" .. i[1], "gear", i[3], i[2], "Item level " .. i[1], V(function() return cnt("maxIlvl") end), i[1])
end
D("MT1", "gear", "S", "Fire bein", "Første mount", V(function() return cnt("mounts") end), 1)
D("MT3", "gear", "G", "Stallgutt", "3 mounts", V(function() return cnt("mounts") end), 3)
D("MT5", "gear", "L", "Hestekar", "5 mounts", V(function() return cnt("mounts") end), 5)
D("MTE", "gear", "G", "Rytter", "Få en mount før level 40", flag("mountBefore40"))

-- Tempo
D("XP10", "tempo", "B", "Fart", "10 000 XP per time i én økt", V(function() return cnt("bestXPRate") end), 10000)
D("XP25", "tempo", "S", "Turbo", "25 000 XP per time i én økt", V(function() return cnt("bestXPRate") end), 25000)
D("XP50", "tempo", "G", "Lyshastighet", "50 000 XP per time i én økt", V(function() return cnt("bestXPRate") end), 50000)
D("LFST", "tempo", "S", "Lynding", "Et level på under 30 min spilletid", flag("fastLevel"))
D("SPRN", "tempo", "G", "Speedrunner", "Raskeste ding i gjengen (alle tider)", flag("fastestInGang"))
D("EFF", "tempo", "L", "Effektiv", "Level 60 på under 10 døgn /played", flag("efficient60"))
D("SNAIL", "tempo", "B", "Snegle", "Et level som tar over 5 timer spilletid", flag("slowLevel"))

-- Hemmelige / morsomme
D("BACK", "fun", "S", "Kom tilbake!", "Logg inn etter 7+ dager borte", flag("comeback"), 1, true)
D("LONE", "fun", "S", "Ensom ulv", "3 timer uten at noen fra gjengen er online", V(function() return cnt("bestLone") end), 3 * 3600, true)
D("AFK", "fun", "B", "AFK-mester", "Stå AFK i 30 minutter", flag("afk30"), 1, true)
D("WIN1", "fun", "G", "Ukens vinner", "Vinn ukens utfordring", V(function() return cnt("challengeWins") end), 1, true)
D("WIN5", "fun", "L", "Seriemester", "Vinn ukens utfordring 5 ganger", V(function() return cnt("challengeWins") end), 5, true)
D("SOS3", "fun", "S", "Spammer", "Send 3 SOS på én dag", V(function() return math.max(today("sosDay"), cnt("bestDaySos")) end), 3, true)
D("ENM10", "fun", "S", "Fiendejeger", "Tagg 10 fiender", V(function() return cnt("enemiesTagged") end), 10, true)
D("ENSN", "fun", "B", "Ser deg!", "Få et fiendevarsel", V(function() return cnt("enemySeen") end), 1, true)
D("ALL100", "fun", "L", "Komplettist", "Lås opp 100 achievements", V(function() return A:Count(ns.pid) end), 100, true)

A.defs = defs
A.byId = {}
for i, d in ipairs(defs) do d.order = i A.byId[d.id] = d end

---------------------------------------------------------------------------
-- Evaluering
---------------------------------------------------------------------------
function A:Mine() ns.db.ach = ns.db.ach or {} return ns.db.ach end

function A:Has(pid, id)
  if pid == ns.pid then return self:Mine()[id] end
  local p = ns:GetPerson(pid)
  return p and p.ach and p.ach[id]
end

function A:Count(pid)
  local n = 0
  local list = pid == ns.pid and self:Mine() or ((ns:GetPerson(pid) or {}).ach or {})
  for id in pairs(list) do if self.byId[id] then n = n + 1 end end
  return n
end

function A:Points(pid)
  local sum = 0
  local list = pid == ns.pid and self:Mine() or ((ns:GetPerson(pid) or {}).ach or {})
  for id in pairs(list) do
    local d = self.byId[id]
    if d then sum = sum + self.TIERS[d.tier].points end
  end
  return sum
end

function A:Progress(d)
  local ok, v = pcall(d.value)
  if not ok or type(v) ~= "number" then v = 0 end
  return v, d.goal
end

local checkPending = false
function A:CheckSoon()
  if checkPending or not ns.db then return end
  checkPending = true
  C_Timer.After(2, function()
    checkPending = false
    A:Check()
  end)
end

function A:Check()
  if not ns.db or not ns.db.people[ns.pid] then return end
  local mine = self:Mine()
  -- første gang noensinne: tildel det som allerede er oppnådd, uten popups
  local silent = not ns.db.achInit
  local newOnes = {}
  for _, d in ipairs(defs) do
    if not mine[d.id] then
      local v, goal = self:Progress(d)
      if v >= goal then
        mine[d.id] = ns.Now()
        newOnes[#newOnes + 1] = d
      end
    end
  end
  ns.db.achInit = true
  if #newOnes == 0 then return end
  if silent then
    self:SendList()
  else
    for _, d in ipairs(newOnes) do
      ns.Tracker:Event("ACH", d.id, d.tier)
      ns:Fire("TOAST", { kind = "trophy", sticky = false,
        title = "Achievement: " .. d.name, text = d.desc .. " · " .. self.TIERS[d.tier].name .. " (" .. self.TIERS[d.tier].points .. " p)" })
    end
  end
  ns:MarkDirty()
end

-- Del hele lista (stille) med gjengen
function A:SendList(target)
  if not ns.codeHash then return end
  local ids = {}
  for id in pairs(self:Mine()) do if self.byId[id] then ids[#ids + 1] = id end end
  table.sort(ids)
  local chunk, part, total = {}, 1, math.max(1, math.ceil(#ids / 30))
  if #ids == 0 then return end
  for i, id in ipairs(ids) do
    chunk[#chunk + 1] = id
    if #chunk == 30 or i == #ids then
      local msg = ns.Comm:Build("AL", ns.pid, part, total, table.concat(chunk, ","))
      if target then ns.Comm:SendTo(target, msg, 3) else ns.Comm:Broadcast(msg, 3) end
      chunk, part = {}, part + 1
    end
  end
end

ns.Comm:Handle("AL", function(f)
  local pid = f[1]
  if not pid or pid == ns.pid then return end
  local p = ns:GetPerson(pid, true)
  p.ach = p.ach or {}
  for _, id in ipairs(ns.Split(f[4] or "", ",")) do
    if id ~= "" and not p.ach[id] then p.ach[id] = true end
  end
  ns:MarkDirty()
end)

---------------------------------------------------------------------------
-- Hendelser som ikke fanges andre steder
---------------------------------------------------------------------------
local afkSince, loneThisSession = nil, 0
local lastDungeon, lastDungeonAt = nil, 0

function A:Tick(dt)
  local h = tonumber(date("%H"))
  if h == 3 then ns.CntFlag("online03") end
  if h == 6 then ns.CntFlag("online06") end
  -- helg: lørdag + søndag samme helg
  local wday = tonumber(date("%w"))
  local days = (me().stats or {}).days or {}
  if wday == 6 or wday == 0 then
    local sat = wday == 6 and ns.Now() or (ns.Now() - 86400)
    local total = (days[date("%Y-%m-%d", sat)] or 0) + (days[date("%Y-%m-%d", sat + 86400)] or 0)
    ns.CntMax("bestWeekend", total)
  end
  -- AFK
  if ns.S(UnitIsAFK, "player") then
    afkSince = afkSince or ns.Now()
    if ns.Now() - afkSince >= 1800 then ns.CntFlag("afk30") end
  else
    afkSince = nil
  end
  -- ensom ulv / hvor mange online
  local online = 0
  for pid, p in pairs(ns.db.people) do
    if pid ~= ns.pid and p.main and ns:IsOnline(p) then online = online + 1 end
  end
  ns.CntMax("maxOnline", online + 1)
  if online == 0 then
    loneThisSession = loneThisSession + dt
    ns.CntMax("bestLone", loneThisSession)
  end
  -- økt-rekorder
  local s = ns.session
  ns.CntMax("bestSessionLevels", s.levels or 0)
  ns.CntMax("bestSessionQuests", s.quests or 0)
  ns.CntMax("bestSessionGold", s.gold or 0)
  ns.CntMax("bestSessionDeaths", s.deaths or 0)
  local m = ns.S(GetMoney)
  if m then ns.CntMax("maxMoney", m) end
  local il = ns.Tracker:ItemLevel()
  if il then ns.CntMax("maxIlvl", il) end
  local sessSec = ns.Now() - (s.start or ns.Now())
  if sessSec >= 1200 and (s.xp or 0) > 0 then ns.CntMax("bestXPRate", math.floor(s.xp / sessSec * 3600)) end
  -- tempo fra levelhistorikk
  local times = ns.St:LevelTimes(me())
  for _, t in ipairs(times) do
    if t.secs < 1800 then ns.CntFlag("fastLevel") end
    if t.secs > 18000 then ns.CntFlag("slowLevel") end
  end
  if maxLevel() >= 60 and maxPlayed() > 0 and maxPlayed() < 10 * 86400 then ns.CntFlag("efficient60") end
  -- raskeste ding i hele gjengen
  local myBest
  for _, t in ipairs(times) do if not myBest or t.secs < myBest then myBest = t.secs end end
  if myBest then
    local beaten = false
    for pid, p in pairs(ns.db.people) do
      if pid ~= ns.pid then
        for _, t in ipairs(ns.St:LevelTimes(p)) do if t.secs < myBest then beaten = true break end end
      end
      if beaten then break end
    end
    if not beaten and ns:PersonMaxLevel(me()) >= 10 then ns.CntFlag("fastestInGang") end
  end
  self:Check()
end

-- Ukens konger og vinner (sjekkes etter innlogging, når data om forrige uke er synket)
function A:CheckWeekKings()
  local pwk = ns.PrevWeekKey()
  local function best(key)
    local bp, bv = nil, 0
    for pid, p in pairs(ns.db.people) do
      local s = p.stats or {}
      local v = 0
      if s.prev and s.prev.wk == pwk then v = s.prev[key] or 0 elseif s.wk == pwk then v = s["w" .. key] or 0 end
      if v > bv then bp, bv = pid, v end
    end
    return bp
  end
  if best("Quests") == ns.pid then ns.CntFlag("kingQuests") end
  if best("Gold") == ns.pid then ns.CntFlag("kingGold") end
  if best("Deaths") == ns.pid then ns.CntFlag("kingDeaths") end
  local s = me().stats or {}
  if s.prev and s.prev.wk == pwk and (s.prev.Deaths or 0) == 0 and (s.prev.Online or 0) >= 5 * 3600 then
    ns.CntFlag("weekNoDeath")
  end
  local ch, winner = ns.Data:LastWeekWinner()
  ns.db.cnt.winsCounted = ns.db.cnt.winsCounted or {}
  if winner and winner.pid == ns.pid and not ns.db.cnt.winsCounted[pwk] then
    ns.db.cnt.winsCounted[pwk] = true
    ns.Cnt("challengeWins")
  end
end

-- Dungeons, raid, soner og battlegrounds
local function onWorld()
  local inInst, kind = ns.S(IsInInstance)
  local zone = ns.S(GetRealZoneText)
  if zone and zone ~= "" and not inInst then ns.CntSet("zonesSeen", zone) end
  if inInst then
    local name = ns.S(GetInstanceInfo)
    if name and name ~= "" then
      if kind == "party" then
        ns.CntSet("dungeonsSeen", name)
        if name ~= lastDungeon or (ns.Now() - lastDungeonAt) > 1800 then
          ns.Cnt("dungeonRuns")
          ns.CntDay("dungeonsDay")
          ns.CntMax("bestDayDungeons", (db().dungeonsDay or {})[date("%Y-%m-%d")] or 0)
        end
        lastDungeon, lastDungeonAt = name, ns.Now()
      elseif kind == "raid" then
        ns.CntSet("raidsSeen", name)
      end
    end
  end
end
ns:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(3, onWorld) end)
ns:On("ZONE_CHANGED_NEW_AREA", function()
  ns.Cnt("zoneChanges")
  C_Timer.After(1, onWorld)
end)
ns:On("ZONE_CHANGED", function()
  local sub = ns.S(GetSubZoneText)
  if sub and sub ~= "" then ns.CntSet("subzonesSeen", sub) end
end)

ns:On("PVP_MATCH_COMPLETE", function(winner)
  if winner == nil or ns.isSecret(winner) then return end
  -- 0 = Horde, 1 = Alliance
  local faction = ns.S(UnitFactionGroup, "player")
  local mine = (faction == "Horde") and 0 or 1
  if winner == mine then
    ns.Cnt("bgWins")
    local map = ns.S(GetInstanceInfo)
    if map then ns.CntSet("bgWonMaps", map) end
  end
end)

-- Gruppe med folk fra gjengen
local function gangNames()
  local set = {}
  for char, r in pairs(ns.db.roster) do
    if r.pid then set[ns.ShortName(char):lower()] = true end
  end
  for pid, p in pairs(ns.db.people) do
    for full, c in pairs(p.chars or {}) do set[ns.ShortName(full):lower()] = true if c.name then set[c.name:lower()] = true end end
  end
  return set
end
ns:On("GROUP_ROSTER_UPDATE", function()
  local n = ns.S(GetNumGroupMembers) or 0
  if n < 2 then return end
  local set = gangNames()
  local raid = ns.S(IsInRaid)
  local count = 0
  for i = 1, n do
    local unit = raid and ("raid" .. i) or (i == n and "player" or ("party" .. i))
    local name = ns.S(UnitName, unit)
    if name and set[name:lower()] then count = count + 1 end
  end
  if not raid then count = count + 0 end
  ns.CntMax("maxGangGroup", count)
  local inInst, kind = ns.S(IsInInstance)
  if inInst and kind == "party" and n == 5 and count >= 5 then ns.CntFlag("gangDungeon") end
end)

function A:Start()
  -- «Kom tilbake!»: mer enn 7 dager siden forrige økt
  if ns.db.lastActive and (ns.Now() - ns.db.lastActive) > 7 * 86400 then ns.CntFlag("comeback") end
  C_Timer.NewTicker(15, function()
    ns.db.lastActive = ns.Now()
    A:Tick(15)
  end)
  C_Timer.After(10, function() A:Check() end)
  C_Timer.After(85, function() A:CheckWeekKings() end)
end
