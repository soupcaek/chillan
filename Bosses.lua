-- Chillan? – boss lists for dungeons and raids (1.4.0): "3 / 8 bosses", the hover list with the
-- bosses you've killed struck through, the boss track in the Now card and the run card.
-- Where the list comes from, best first:
--  1) the list below (classic names + the new Forever dungeons, from the launch client data)
--  2) the game's own encounter journal, for instances the list doesn't have
--  3) bosses the gang has killed in that instance before (learned from boss kills, shared in the feed)
-- "A|B" means the same boss under two names (the client and the guides don't always agree).
-- "?Name" is a boss the guides list but that may be optional: it only counts once it's killed.
local ADDON, ns = ...
local B = {}
ns.Bosses = B

local LIST = {
  -- classic dungeons
  ["ragefire chasm"] = { "Oggleflint", "Taragaman the Hungerer", "Jergosh the Invoker", "Bazzalan" },
  ["wailing caverns"] = { "Lady Anacondra", "Lord Cobrahn", "Kresh", "Lord Pythas", "Skum", "Lord Serpentis", "Verdan the Everliving", "Mutanus the Devourer" },
  ["deadmines"] = { "Rhahk'Zor", "Sneed", "Gilnid", "Mr. Smite", "Captain Greenskin", "Edwin VanCleef", "Cookie" },
  ["shadowfang keep"] = { "Rethilgore", "Razorclaw the Butcher", "Baron Silverlaine", "Commander Springvale", "Odo the Blindwatcher", "Fenrus the Devourer", "Wolf Master Nandos", "Archmage Arugal" },
  ["blackfathom deeps"] = { "Ghamoo-ra", "Lady Sarevess", "Gelihast", "Lorgus Jett", "Baron Aquanis", "Twilight Lord Kelris", "Old Serra'kis", "Aku'mai" },
  ["stockade"] = { "Targorr the Dread", "Kam Deepfury", "Hamhock", "Dextren Ward", "Bazil Thredd" },
  ["gnomeregan"] = { "Grubbis", "Viscous Fallout", "Electrocutioner 6000", "Crowd Pummeler 9-60", "Mekgineer Thermaplugg" },
  ["razorfen kraul"] = { "Roogug", "Aggem Thorncurse", "Death Speaker Jargba", "Overlord Ramtusk", "Agathelos the Raging", "Charlga Razorflank" },
  ["scarlet monastery"] = { wings = {
    { name = "Graveyard", list = { "Interrogator Vishas", "Bloodmage Thalnos" } },
    { name = "Library", list = { "Houndmaster Loksey", "Arcanist Doan" } },
    { name = "Armory", list = { "Herod" } },
    { name = "Cathedral", list = { "High Inquisitor Fairbanks", "Scarlet Commander Mograine", "High Inquisitor Whitemane" } },
  } },
  ["razorfen downs"] = { "Tuten'kash", "Mordresh Fire Eye", "Glutton", "Ragglesnout", "Amnennar the Coldbringer" },
  ["uldaman"] = { "Revelosh", "The Lost Dwarves", "Ironaya", "Obsidian Sentinel", "Ancient Stone Keeper", "Galgann Firehammer", "Grimlok", "Archaedas" },
  ["zul'farrak"] = { "Antu'sul", "Theka the Martyr", "Witch Doctor Zum'rah", "Nekrum Gutchewer", "Shadowpriest Sezz'ziz", "Sergeant Bly", "Hydromancer Velratha", "Gahz'rilla", "Chief Ukorz Sandscalp" },
  ["maraudon"] = { "Noxxion", "Razorlash", "Lord Vyletongue", "Celebras the Cursed", "Landslide", "Tinkerer Gizlock", "Rotgrip", "Princess Theradras" },
  ["sunken temple"] = { "Atal'alarion", "Dreamscythe", "Weaver", "Avatar of Hakkar", "Jammal'an the Prophet", "Ogom the Wretched", "Morphaz", "Hazzas", "Shade of Eranikus" },
  ["blackrock depths"] = { "High Interrogator Gerstahn", "Lord Roccor", "Houndmaster Grebmar", "Ring of Law", "Pyromancer Loregrain", "Lord Incendius", "Warder Stilgiss", "Fineous Darkvire", "Bael'Gar", "General Angerforge", "Golem Lord Argelmach", "Hurley Blackbreath", "Phalanx", "Ribbly Screwspigot", "Plugger Spazzring", "Ambassador Flamelash", "The Seven", "Magmus", "Emperor Dagran Thaurissan" },
  ["blackrock spire"] = { wings = {
    { name = "Lower", list = { "Highlord Omokk", "Shadow Hunter Vosh'gajin", "War Master Voone", "Mother Smolderweb", "Urok Doomhowl", "Quartermaster Zigris", "Halycon", "Gizrul the Slavener", "Overlord Wyrmthalak" } },
    { name = "Upper", list = { "Pyroguard Emberseer", "Solakar Flamewreath", "Warchief Rend Blackhand", "The Beast", "General Drakkisath" } },
  } },
  ["dire maul"] = { wings = {
    { name = "East", list = { "Zevrim Thornhoof", "Hydrospawn", "Lethtendris", "Alzzin the Wildshaper" } },
    { name = "West", list = { "Tendris Warpwood", "Illyanna Ravenoak", "Magister Kalendris", "Immol'thar", "Prince Tortheldrin" } },
    { name = "North", list = { "Guard Mol'dar", "Stomper Kreeg", "Guard Fengus", "Guard Slip'kik", "Captain Kromcrush", "King Gordok" } },
  } },
  ["stratholme"] = { wings = {
    { name = "Main Gate", list = { "Timmy the Cruel", "Malor the Zealous", "Cannon Master Willey", "Archivist Galford", "Balnazzar" } },
    { name = "Service Gate", list = { "Baroness Anastari", "Nerub'enkan", "Maleki the Pallid", "Magistrate Barthilas", "Ramstein the Gorger", "Baron Rivendare" } },
  } },
  ["scholomance"] = { "Kirtonos the Herald", "Jandice Barov", "Rattlegore", "Marduk Blackpool", "Vectus", "Ras Frostwhisper", "Instructor Malicia", "Doctor Theolen Krastinov", "Lorekeeper Polkelt", "The Ravenian", "Lord Alexei Barov", "Lady Illucia Barov", "Darkmaster Gandling" },
  -- new in WoW Forever
  ["hall of thanes"] = { "Faldrim Anvilmar", "Infurnus|Magmatus", "Plunder", "Durgen Dirgehammer" },
  ["ruins of lordaeron"] = { "Witherfang|Broodling", "The Abandoned", "The Baron", "Rath'mael", "Lordaeron Captain", "Viktor the Vile", "Bjork" },
  ["excavation site"] = { "Saltspine", "Shadetooth", "Highland Horror", "Relic Guardian" },
  ["city of dalaran"] = { "Arcane Anomaly", "Fel Ancient", "Mana Devourer", "Mana Elemental", "Unstable Sentinel", "Shade of the Archmage", "Lyn the Ignored", "Atrexis the Grave Knight", "Mana Wraith" },
  ["blackmaw hold"] = { "Impaan the Imprisoner", "Bonesnout the Unbroken", "Withermaw", "Unbound Spirit", "Elder Shaman Bloodmane",
    "Blackmaw Behemoth", "Varrox Bleakhoof", "?Moontouched Wanderer", "?Gortek the Apprentice", "?Tunnelweb Matriarch" },
  ["krol'dok stronghold"] = { "Slavecrusher Grox", "Twilight Commander Zarmork", "Handler Ashka", "Nar'Gurk", "Bossman Toof", "Overlord Mugg" },
  ["alcaz prison"] = { "Tidemistress Ca'zass", "Overseer Wrex", "The Questioner", "Katerina the Cleaner", "Blazeroar" },
  ["shaper's terrace"] = { "Cinder", "Titanosaur", "Snowtalon", "Tor'Rel and Izha'Rel", "Vitrix", "Direhorn Matriarch", "Thunderhoof", "Venomridge", "Bolt", "Nanaya" },
  ["drowned city"] = { "Zul'Alai", "Var'Taka", "Captain Dreadrise", "Deathless Marrow", "Primeval Elemental", "Min'loth the Serpent" },
  -- raids
  ["molten core"] = { "Lucifron", "Magmadar", "Gehennas", "Garr", "Shazzrah", "Baron Geddon", "Sulfuron Harbinger", "Golemagg the Incinerator", "Majordomo Executus", "Ragnaros" },
  ["onyxia's lair"] = { "Onyxia" },
  ["blackwing lair"] = { "Razorgore the Untamed", "Vaelastrasz the Corrupt", "Broodlord Lashlayer", "Firemaw", "Ebonroc", "Flamegor", "Chromaggus", "Nefarian" },
  ["zul'gurub"] = { "High Priestess Jeklik", "High Priest Venoxis", "High Priestess Mar'li", "Bloodlord Mandokir", "Edge of Madness", "High Priest Thekal", "Gahz'ranka", "High Priestess Arlokk", "Jin'do the Hexxer", "Hakkar" },
  ["ruins of ahn'qiraj"] = { "Kurinnaxx", "General Rajaxx", "Moam", "Buru the Gorger", "Ayamiss the Hunter", "Ossirian the Unscarred" },
  ["ahn'qiraj temple"] = { "The Prophet Skeram", "Silithid Royalty", "Battleguard Sartura", "Fankriss the Unyielding", "Viscidus", "Princess Huhuran", "Twin Emperors", "Ouro", "C'Thun" },
  ["naxxramas"] = { "Anub'Rekhan", "Grand Widow Faerlina", "Maexxna", "Noth the Plaguebringer", "Heigan the Unclean", "Loatheb", "Instructor Razuvious", "Gothik the Harvester", "The Four Horsemen", "Patchwerk", "Grobbulus", "Gluth", "Thaddius", "Sapphiron", "Kel'Thuzad" },
}
B.LIST = LIST

-- instance names as the game may write them → the key above
local ALIAS = {
  ["the deadmines"] = "deadmines", ["the stockade"] = "stockade", ["stormwind stockade"] = "stockade",
  ["the temple of atal'hakkar"] = "sunken temple", ["temple of atal'hakkar"] = "sunken temple",
  ["the hall of thanes"] = "hall of thanes", ["excavation site: wetlands"] = "excavation site",
  ["the drowned city"] = "drowned city", ["krol'dor stronghold"] = "krol'dok stronghold",
  ["alcaz island prison"] = "alcaz prison", ["the shaper's terrace"] = "shaper's terrace", ["shapers terrace"] = "shaper's terrace", ["dalaran"] = "city of dalaran",
  ["lower blackrock spire"] = "blackrock spire", ["upper blackrock spire"] = "blackrock spire",
  ["onyxia’s lair"] = "onyxia's lair", ["ahn'qiraj"] = "ahn'qiraj temple", ["temple of ahn'qiraj"] = "ahn'qiraj temple",
}

local function norm(s)
  s = tostring(s or ""):lower():gsub("’", "'"):gsub("^%s+", ""):gsub("%s+$", "")
  return s
end
function B.Key(instance)
  local k = norm(instance)
  if LIST[k] then return k end
  if ALIAS[k] then return ALIAS[k] end
  -- "Scarlet Monastery - Library", "Dire Maul (East)" and the like
  for key in pairs(LIST) do
    if k:sub(1, #key) == key then return key end
  end
  return k
end
local function wingHint(instance)
  local k = norm(instance)
  local entry = LIST[B.Key(instance)]
  if not (entry and entry.wings) then return nil end
  for i, w in ipairs(entry.wings) do
    if k:find(w.name:lower(), 1, true) then return i end
  end
  if k:find("lower", 1, true) then return 1 end
  if k:find("upper", 1, true) then return 2 end
end

-- does a killed encounter name match a list entry ("A|B" = either name; small spelling slips ok)
local function bare(s) return (norm(s):gsub("^%?", ""):gsub("^the ", ""):gsub("[^%w]", "")) end
function B.Same(entry, name)
  local n = bare(name)
  if n == "" then return false end
  for alt in tostring(entry):gmatch("[^|]+") do
    local a = bare(alt)
    if a == n or (#a > 4 and #n > 4 and (a:find(n, 1, true) or n:find(a, 1, true))) then return true end
  end
  return false
end
local function show(entry) return (tostring(entry):gsub("^%?", ""):match("^[^|]+")) end
local function optional(entry) return tostring(entry):sub(1, 1) == "?" end

-- the game's encounter journal, when it has the instance (cached per instance)
local ejCache = {}
local function fromJournal()
  if not (EJ_GetInstanceForMap and EJ_GetEncounterInfoByIndex and C_Map and C_Map.GetBestMapForUnit) then return nil end
  local okM, mapID = pcall(C_Map.GetBestMapForUnit, "player")
  if not okM or type(mapID) ~= "number" or ns.isSecret(mapID) then return nil end
  local okI, inst = pcall(EJ_GetInstanceForMap, mapID)
  if not okI or type(inst) ~= "number" or inst == 0 then return nil end
  if ejCache[inst] ~= nil then return ejCache[inst] or nil end
  local out = {}
  if EJ_SelectInstance then pcall(EJ_SelectInstance, inst) end
  for i = 1, 40 do
    local ok, name = pcall(EJ_GetEncounterInfoByIndex, i, inst)
    if not ok or type(name) ~= "string" or name == "" then break end
    out[#out + 1] = name
  end
  ejCache[inst] = #out > 0 and out or false
  return #out > 0 and out or nil
end

function B:Learned(instance)
  ns.db.bossLearn = ns.db.bossLearn or {}
  local k = B.Key(instance)
  ns.db.bossLearn[k] = ns.db.bossLearn[k] or {}
  return ns.db.bossLearn[k]
end

-- a boss the gang killed (from your own kill or a friend's BOSS line in the feed)
function B:Learn(instance, name)
  if type(instance) ~= "string" or type(name) ~= "string" or name == "" or instance == "" then return end
  local list = self:Learned(instance)
  for _, n in ipairs(list) do if B.Same(n, name) then return end end
  if #list < 40 then list[#list + 1] = name end
end

-- the bosses for this instance: { {name=, killed=bool, secs=}, ... }, plus the wing's name if any.
-- killed = { [name] = secs or true } from the run.
function B:For(instance, killed, here)
  killed = killed or {}
  local entry = LIST[B.Key(instance)]
  local base, wingName
  -- the journal only for instances our list doesn't know (its names may be from a later version of the game)
  local ej = here and not entry and fromJournal()
  if ej then
    base = ej
  elseif entry and entry.wings then
    local wi = wingHint(instance)
    if not wi then
      -- the wing whose bosses you've killed
      for i, w in ipairs(entry.wings) do
        for _, b in ipairs(w.list) do
          for k in pairs(killed) do if B.Same(b, k) then wi = i end end
        end
      end
    end
    if wi then base, wingName = entry.wings[wi].list, entry.wings[wi].name end
  elseif entry then
    base = entry
  end
  local out, used = {}, {}
  for _, b in ipairs(base or {}) do
    local hit
    for k, v in pairs(killed) do if not used[k] and B.Same(b, k) then hit = k used[k] = v end end
    out[#out + 1] = { name = show(b), killed = hit ~= nil, secs = hit and type(killed[hit]) == "number" and killed[hit] or nil, opt = optional(b) }
  end
  -- bosses the list doesn't know: the gang has killed them here (or you just did)
  local function add(name, v)
    for _, o in ipairs(out) do if B.Same(o.name, name) then return end end
    out[#out + 1] = { name = name, killed = v ~= nil, secs = type(v) == "number" and v or nil }
  end
  for k, v in pairs(killed) do if not used[k] then add(k, v) end end
  if not base or entry == nil then
    for _, n in ipairs(self:Learned(instance)) do add(n, killed[n]) end
  end
  -- known: the list is complete (journal or our table), or we've seen this many before
  local known = base ~= nil
  return out, wingName, known, (entry and entry.wings and not wingName) and entry.wings or nil
end

-- "3 / 8" for the box (or "3 / ?" when we don't know how many there are)
function B:Count(instance, killed)
  local list, _, known = self:For(instance, killed, true)
  local n, total = 0, 0
  for _, b in ipairs(list) do
    if b.killed then n = n + 1 end
    if b.killed or not b.opt then total = total + 1 end   -- an optional boss counts once it's dead
  end
  return n, (known or total > n) and total or nil, list
end

-- the next boss you haven't killed (by list order)
function B:Next(instance, killed)
  local list = self:For(instance, killed, true)
  for _, b in ipairs(list) do if not b.killed and not b.opt then return b.name end end
end
