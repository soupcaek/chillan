-- Chillan? – funny death lines: who/what killed you, and a line to match (different every time).
-- The dying player picks the line and sends its number with the death, so everyone sees the same one.
local ADDON, ns = ...

local D = {}
ns.Deaths = D

-- {n} = name, {k} = killer, {z} = zone, {c} = class/race of an Alliance player
D.POOLS = {
  PLAYER = {
    "{n} got absolutely fucked by a {c} in {z}. Rude as hell.",
    "{n} got clapped by {k} in {z}. Fucking embarrassing.",
    "{n} met {k} in {z} and it went fucking terribly.",
    "A {c} just deleted {n} in {z}. Who the fuck let that happen?",
    "{n} got farmed like a goddamn herb node by {k}.",
    "{k} turned {n} into a fucking loading screen in {z}.",
    "{n} got bent over by a {c} in {z}. Revenge is mandatory.",
    "{n} was sent to the graveyard by {k}. Fuck that guy in particular.",
    "{n} lost a fair fight to {k} in {z}. Just kidding, it was a fucking gank.",
    "{k} got a free honorable kill on {n}. Unacceptable bullshit.",
    "{n} got shit on by a {c} in {z}. Gang, assemble.",
    "{n} tried to 1v1 {k}. Bold. Stupid. Fucking dead.",
    "{n} got humbled by {k} in {z}. Bring friends next time, dumbass.",
    "{k} made {n} eat dirt in {z}. Add him to the shit list.",
    "{n} got wrecked so hard by {k} the spirit healer winced.",
    "{n} got mugged by a {c} in {z}. Fucking Alliance, man.",
    "{n} got one-shot by {k} and didn't even see the bastard coming.",
    "{n} is lying face down in {z} thanks to that prick {k}.",
    "{n} got rekt by an Alliance {c} in {z}. LOL.",
    "{n} met {k} in {z}. {k} won. Easily.",
    "{n} just got farmed by {k} ({c}) in {z}.",
    "Breaking news from {z}: {n} has been deleted by {k}.",
    "{k} sends their regards. {n} is lying face down in {z}.",
    "{n} tried to PvP. {k} said no.",
    "{n} got ganked by a {c} in {z}. Avenge them!",
    "{n} became a free honor point for {k}.",
    "{k} ({c}) just turned {n} into a corpse run in {z}.",
    "{n} challenged {k} to a fight in {z}. Bad idea.",
    "{z} is now Alliance territory. Ask {n}.",
    "{n} was last seen fighting {k}. Was.",
    "Somewhere in {z}, {k} is dancing on {n}'s corpse.",
    "{n} got outplayed by a {c}. Happens to the best of us. Rarely to them.",
    "{k} collected {n}'s skull in {z}. Who's next?",
    -- spicy
    "{n} got absolutely fucked by an Alliance {c} in {z}.",
    "{n} just got destroyed by {k}. Fucking embarrassing.",
    "{k} beat the shit out of {n} in {z}.",
    "{n} got clapped so hard by {k} the spirit healer felt it.",
    "Holy shit, {k} just deleted {n} in {z}.",
    "{n} got their ass handed to them by a {c} in {z}.",
    "{k} ({c}) made {n} his bitch in {z}. Revenge, anyone?",
    "{n} got bent over by {k} in {z}. Again.",
    "Fuck the Alliance. {k} just killed {n} in {z}.",
    "{n} got shit on by a {c} in {z}. Who's coming?",
    "{n} vs {k}: a short, sad, fucking massacre.",
    "{n} got fucked up beyond recognition by {k} in {z}.",
    "Some {c} named {k} just ruined {n}'s whole damn evening.",
    "{n} got ganked, tea-bagged and probably laughed at by {k}.",
    "{k} sent {n} to the graveyard in record time. Fucking hell.",
  },
  FALL = {
    "{n} forgot that gravity exists.",
    "{n} tried to fly in {z}. Bold. Wrong.",
    "{n} took the express way down in {z}.",
    "{n} jumped. The ground won.",
    "Gravity: 1, {n}: 0.",
    "{n} fell off a cliff like a fucking idiot.",
    "{n} found out the hard way that Tauren can't fly. Or whatever they are.",
    "{n} yeeted themselves off a cliff in {z}. Absolute legend.",
    "{n} missed the jump. By a lot. Like, a fucking lot.",
  },
  DROWN = {
    "{n} forgot to breathe in {z}.",
    "{n} went for a swim and never came back up.",
    "{n} drowned. In a game. With a breath bar.",
    "{n} is now sleeping with the fishes in {z}.",
    "{n} drowned like a fucking amateur.",
    "{n} tried to out-swim their own lungs. Lungs won, the dumbass.",
  },
  FIRE = {
    "{n} stood in the fire.",
    "{n} found out lava is hot.",
    "{n} got roasted in {z}. Medium rare.",
    "{n} stood in fire like a damn raid noob.",
    "{n} cooked themselves to death. Chef's fucking kiss.",
  },
  FATIGUE = {
    "{n} swam too far out and got tired. Of life.",
    "{n} tried to swim to the other continent.",
    "{n} found the edge of the map the hard way. Dumbass.",
  },
  MOB = {
    "{n} got absolutely fucked by {k} in {z}.",
    "{n} got bodied by {k}. A fucking {k}. In {z}.",
    "{k} made {n} its bitch in {z}.",
    "{n} got shit-stomped by {k} in {z}.",
    "{n} got fucking demolished by {k}. Not even close.",
    "{n} lost to {k}. The shame will outlive the repair bill.",
    "{k} slapped {n} into next week in {z}.",
    "{n} pulled {k} and immediately regretted every fucking choice.",
    "{n} got turned into paste by {k} in {z}. Gross.",
    "{k} absolutely clowned on {n} in {z}.",
    "{n} got fucking flattened by {k}. Pancake mode.",
    "{n} got merked by {k} in {z}. Holy shit.",
    "RIP {n}. Cause of death: {k} and a complete lack of brain cells.",
    "{n} got speedrun to the graveyard by {k}.",
    "{k} served {n} a full-course ass-kicking in {z}.",
    "{n} was killed by {k}. The gang is legally required to laugh.",
    "{n} got their shit rocked by {k} in {z}.",
    "{k} gave {n} a one-way ticket to the spirit healer. No refunds, bitch.",
    "{n} got killed by {k} in {z}.",
    "{k} was not impressed by {n}.",
    "{n} lost a fair fight to {k}. It was not close.",
    "{n} pulled {k}. {k} pulled harder.",
    "RIP {n}, killed by {k} in {z}. Gone but not forgotten. Mostly forgotten.",
    "{n} underestimated {k}. Classic.",
    "{k} has claimed another victim: {n}.",
    "{n} tried to solo {k}. Didn't work.",
    "{k} sends {n} back to the graveyard with love from {z}.",
    "{n} got carried out of {z} by the spirit healer, courtesy of {k}.",
    "{n} vs {k}: {k} by knockout.",
    "Note to self: {k} hits harder than {n} thought.",
    "{n} died to {k}. Let's never speak of this again.",
    "{n} learned an important lesson from {k} today.",
    "{k} 1 – {n} 0.",
    -- spicy
    "{n} got absolutely fucked by {k} in {z}.",
    "{n} got their shit kicked in by {k}.",
    "{k} just beat the hell out of {n} in {z}.",
    "{n} got bodied by a fucking {k}. In {z}.",
    "{n} lost to {k}. A fucking {k}.",
    "Holy shit, {n} got wrecked by {k}.",
    "{k} made {n} its little bitch in {z}.",
    "{n} got smacked the fuck out by {k}.",
    "{n} pulled {k} and immediately regretted every fucking decision.",
    "{k} did {n} dirty in {z}. Really fucking dirty.",
    "{n} died to {k}. Skill issue? Massive fucking skill issue.",
    "{n} got deleted by {k}. Unbelievable shit.",
    "{k} ate {n} for breakfast and is still hungry.",
    "{n} got stomped by {k} like a goddamn grape.",
    "{n} vs {k}: one-sided, brutal, fucking hilarious.",
  },
}

-- mob families, recognised by words in the name, each with its own lines
D.FAMILIES = {
  { key = "RAPTOR", words = { "raptor", "scytheclaw", "stalker" }, lines = {
    "{n} turned into raptor food in {z}.",
    "Clever girl. {k} got {n}.",
    "{n} found out raptors hunt in packs. Too late.",
    "{n} got shredded by a fucking raptor in {z}.",
    "{k} chewed {n} up and spat out the armor.",
  } },
  { key = "TURTLE", words = { "turtle", "snapjaw", "tortoise" }, lines = {
    "{n} lost a fight to a turtle. A TURTLE.",
    "{k} is slow, but {n} was slower.",
    "{n} got absolutely fucked by a {k} in {z}.",
    "{n} was beaten by something that moves at 1 mph. Damn.",
  } },
  { key = "MURLOC", words = { "murloc", "mrgl", "tidehunter", "oracle", "fin" }, lines = {
    "Mrglglglgl! {n} got drowned in murlocs in {z}.",
    "{n} pulled one murloc. Got nine.",
    "{n} lost to the most annoying creature in Azeroth: {k}.",
    "{n} got jumped by a whole fucking murloc party in {z}.",
    "Aaaurrrgh! The murlocs got {n}.",
  } },
  { key = "WOLF", words = { "wolf", "worg", "coyote", "jackal", "hyena", "dog" }, lines = {
    "{n} got eaten by a big bad {k}.",
    "{k} played fetch with {n}'s leg bones.",
    "Who let the dogs out? {k} did, and {n} died.",
    "{n} got mauled to shit by a {k}.",
  } },
  { key = "SPIDER", words = { "spider", "widow", "recluse", "tarantula", "webwood" }, lines = {
    "{n} got wrapped up for later by {k}.",
    "{n} walked into a web. Then into a {k}.",
    "{k} is having {n} for dinner tonight.",
    "{n} got fucked by eight legs and a lot of venom.",
  } },
  { key = "GNOLL", words = { "gnoll", "riverpaw", "redridge", "mosshide", "rot hide" }, lines = {
    "{n} got clubbed to death by a gnoll. Embarrassing.",
    "Yip yip! {k} got {n}.",
    "{n} got beaten up by a dog with a stick.",
    "A fucking gnoll, {n}. Really?",
  } },
  { key = "KOBOLD", words = { "kobold", "tunneler", "geomancer" }, lines = {
    "You no take candle! {n} took the candle. {n} died.",
    "{n} died to a kobold. Let that sink in.",
    "{k} defended its candle against {n}. And won.",
    "{n} got fucked up by a three-foot rat with a candle.",
  } },
  { key = "DEFIAS", words = { "defias", "bandit", "thug", "pillager", "rogue wizard", "highwayman", "brigand" }, lines = {
    "{n} tried to hug a {k}. The {k} said no.",
    "{n} got mugged by {k} in {z}.",
    "{k} took {n}'s gold and their life.",
    "{n} got robbed and fucking murdered by {k}.",
  } },
  { key = "TROLL", words = { "troll", "witchdoctor", "headhunter", "bloodscalp", "skullsplitter", "shadowhunter" }, lines = {
    "{n} got voodoo'd to death by {k}.",
    "{k} took {n}'s head as a trophy.",
    "Not even the trolls respect {n} anymore.",
    "{n} got fucked by a troll with a spear and a bad attitude.",
  } },
  { key = "UNDEAD", words = { "skeleton", "ghoul", "zombie", "ghost", "banshee", "wraith", "spirit", "lich", "risen", "rotting", "plague", "scourge" }, lines = {
    "{n} got killed by something that was already dead.",
    "{k} invited {n} to join the undead. Welcome!",
    "{n} is now as dead as {k}.",
    "{n} got fucked by a walking pile of bones.",
  } },
  { key = "ELEMENTAL", words = { "elemental", "fury", "rager", "tempest", "earth", "fire", "water", "air", "storm" }, lines = {
    "{n} got overruled by nature itself in {z}.",
    "{k} reminded {n} who's in charge of the elements.",
    "{n} got blasted to shit by {k}.",
  } },
  { key = "BOAR", words = { "boar", "pig", "razorback", "bristleback", "quilboar" }, lines = {
    "{n} got gored by a {k}. Bacon's revenge.",
    "{n} lost to a pig. Oink.",
    "{n} got fucked by a pig. Let that sink in.",
  } },
  { key = "BEAR", words = { "bear", "grizzly", "ursa", "furbolg" }, lines = {
    "{n} got a bear hug from {k}. A fatal one.",
    "{k} mauled {n}. Should have played dead. Oh wait.",
    "{n} got fucking demolished by a bear.",
  } },
  { key = "CAT", words = { "lion", "panther", "tiger", "puma", "lynx", "cat", "cougar", "shadowmaw", "prowler" }, lines = {
    "Here kitty kitty… {k} ate {n}.",
    "{n} tried to pet {k}. Bad idea.",
    "{n} got clawed to fucking pieces by a big cat.",
  } },
  { key = "BIRD", words = { "vulture", "hawk", "eagle", "buzzard", "owl", "harpy", "screecher", "talon" }, lines = {
    "{n} got pecked to death by {k}.",
    "{k} swooped down and picked {n} apart.",
    "{n} got shit on and killed by a {k}. In that order.",
  } },
  { key = "CENTAUR", words = { "centaur", "kolkar", "gelkis", "magram" }, lines = {
    "{n} got trampled by half a horse.",
    "{k} galloped over {n} in {z}.",
    "{n} got run the fuck over by a {k}.",
  } },
  { key = "OGRE", words = { "ogre", "mauler", "brute", "crushridge", "boulderfist" }, lines = {
    "{k} smashed {n}. {k} happy.",
    "{n} got flattened by a two-headed idiot.",
    "{n} got clubbed to shit by an ogre.",
  } },
  { key = "DRAGON", words = { "whelp", "drake", "dragon", "dragonkin", "wyrm" }, lines = {
    "{n} got toasted by {k}.",
    "{k} breathed on {n}. That was enough.",
    "{n} got fucking incinerated by {k}.",
  } },
  { key = "CROC", words = { "crocolisk", "croc", "snapper", "alligator", "basilisk" }, lines = {
    "{n} became a snack for {k}.",
    "{n} went for a swim. {k} was waiting.",
    "{n} got death-rolled the fuck out by {k}.",
  } },
  { key = "SCORPID", words = { "scorpid", "scorpion", "stinger" }, lines = {
    "{n} got stung to death by {k}.",
    "{k} poked {n} with its tail until {n} stopped moving.",
    "{n} got fucked by a stinger in {z}.",
  } },
  { key = "NAGA", words = { "naga", "siren", "myrmidon", "slitherblade" }, lines = {
    "{n} got sea-witched to death by {k}.",
    "{k} dragged {n} into the depths.",
    "{n} got fucked by a snake lady. Not the fun way.",
  } },
  { key = "DEMON", words = { "imp", "felhunter", "satyr", "voidwalker", "succubus", "felguard", "doomguard", "demon" }, lines = {
    "{n} got sent to the Twisting Nether by {k}.",
    "{k} made a deal with {n}. {n} lost.",
    "{n} got fucked by a demon. Hell of a way to go.",
  } },
  { key = "HUMAN", words = { "guard", "soldier", "footman", "knight", "scarlet", "crusader", "marshal", "watchman" }, lines = {
    "{n} got arrested and executed by {k}.",
    "{k} did their job. Unfortunately, {n} was the job.",
    "{n} got fucked by some fucking guard. Classic.",
  } },
}

local ENV = { Falling = "FALL", Drowning = "DROWN", Lava = "FIRE", Fire = "FIRE", Fatigue = "FATIGUE", Slime = "FIRE" }

---------------------------------------------------------------------------
-- who killed me? last damage taken, from the combat log
---------------------------------------------------------------------------
local last
local function onCombat()
  if not CombatLogGetCurrentEventInfo then return end
  local ok, _, sub, _, srcGUID, srcName, srcFlags, _, dstGUID, _, _, _, a12 = pcall(CombatLogGetCurrentEventInfo)
  if not ok or ns.isSecret(dstGUID) or ns.isSecret(sub) then return end
  if dstGUID ~= ns.S(UnitGUID, "player") then return end
  if sub == "ENVIRONMENTAL_DAMAGE" then
    local env = ns.isSecret(a12) and nil or a12
    last = { kind = "ENV", env = env, at = GetTime() }
  elseif type(sub) == "string" and (sub:find("_DAMAGE$") or sub == "SWING_DAMAGE") then
    if ns.isSecret(srcName) or ns.isSecret(srcGUID) or not srcName then return end
    last = { kind = "UNIT", name = srcName, guid = srcGUID, flags = srcFlags, at = GetTime() }
  end
end
-- Clients on the Midnight addon rules (12.x engine, incl. WoW Forever) refuse this event in every
-- context and flag the attempt as a blocked action, so only register where the old rules apply.
if not issecretvalue and not C_DamageMeter then
  pcall(function() ns:On("COMBAT_LOG_EVENT_UNFILTERED", onCombat) end)
end

local function isPlayer(l)
  if type(l.guid) == "string" and l.guid:find("^Player%-") then return true end
  local bit = bit or bit32
  if bit and type(l.flags) == "number" and COMBATLOG_OBJECT_TYPE_PLAYER then
    return bit.band(l.flags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
  end
  return false
end

-- returns { cat = "PLAYER"/"FALL"/.../"MOB"/family key, killer = name, extra = "Night Elf Rogue" } or nil
function D:Killer()
  local l = last
  if not l or GetTime() - l.at > 8 then
    -- fallback: a hostile target that was attacking me
    local t = ns.S(UnitName, "target")
    if t and ns.S(UnitCanAttack, "player", "target") and ns.S(UnitIsUnit, "targettarget", "player") then
      l = { kind = "UNIT", name = t, guid = ns.S(UnitGUID, "target") }
    else
      return nil
    end
  end
  if l.kind == "ENV" then
    return { cat = ENV[l.env or ""] or "FALL" }
  end
  if isPlayer(l) then
    local extra
    if GetPlayerInfoByGUID and l.guid then
      local ok, cls, _, race = pcall(GetPlayerInfoByGUID, l.guid)
      if ok and cls and not ns.isSecret(cls) then extra = ((race and not ns.isSecret(race)) and (race .. " ") or "") .. cls:lower() end
    end
    return { cat = "PLAYER", killer = l.name:match("^[^%-]+"), extra = extra or "player" }
  end
  local lower = l.name:lower()
  for _, fam in ipairs(self.FAMILIES) do
    for _, w in ipairs(fam.words) do
      if lower:find(w, 1, true) then return { cat = fam.key, killer = l.name } end
    end
  end
  return { cat = "MOB", killer = l.name }
end

function D:Pool(cat)
  if self.POOLS[cat] then return self.POOLS[cat] end
  for _, fam in ipairs(self.FAMILIES) do
    if fam.key == cat then
      -- family lines plus the general mob lines, so there's always variety
      if not fam.all then
        fam.all = {}
        for _, l in ipairs(fam.lines) do fam.all[#fam.all + 1] = l end
        for _, l in ipairs(self.POOLS.MOB) do fam.all[#fam.all + 1] = l end
      end
      return fam.all
    end
  end
  return nil
end

-- pick a line number, avoiding the last 10 used on this account
function D:Pick(cat)
  local pool = self:Pool(cat)
  if not pool then return nil end
  ns.db.deathRecent = ns.db.deathRecent or {}
  local recent = {}
  for _, r in ipairs(ns.db.deathRecent) do recent[r] = true end
  local idx
  for _ = 1, 12 do
    idx = math.random(#pool)
    -- family lines first more often
    if not recent[cat .. ":" .. idx] then break end
  end
  table.insert(ns.db.deathRecent, 1, cat .. ":" .. idx)
  while #ns.db.deathRecent > 10 do table.remove(ns.db.deathRecent) end
  return idx
end

-- the funny line for a DEAD feed item (nil if it has no killer info)
-- item.b = "CAT:idx", item.c = killer, item.d = extra (class/race)
function D:Line(item, nameText, baseHex)
  if type(item.b) ~= "string" then return nil end
  local cat, idx = item.b:match("^(%u+):(%d+)$")
  if not cat then return nil end
  local pool = self:Pool(cat)
  local line = pool and pool[tonumber(idx)]
  if not line then return nil end
  local C = ns.C
  -- after a coloured name, continue in the base colour (|r would reset to white)
  local back = baseHex and ("|cff" .. baseHex) or ""
  local k = "|cff" .. C.red .. (item.c ~= "" and item.c or "something") .. "|r" .. back
  nameText = nameText .. back
  local zone = item.a and item.a ~= "" and item.a or "the middle of nowhere"
  line = line:gsub("{n}", function() return nameText end)
  line = line:gsub("{k}", function() return k end)
  line = line:gsub("{z}", function() return zone end)
  line = line:gsub("{c}", function() return item.d ~= "" and item.d or "player" end)
  if baseHex then line = "|cff" .. baseHex .. line .. "|r" end
  return line
end

function D:Kicker(item)
  local cat = type(item.b) == "string" and item.b:match("^(%u+):")
  if cat == "PLAYER" then return "KILLED BY THE ALLIANCE" end
  if cat == "FALL" then return "GRAVITY WINS" end
  if cat == "DROWN" then return "DROWNED" end
  if cat == "FIRE" then return "BURNED" end
  if cat == "FATIGUE" then return "EXHAUSTED" end
  return "DEAD!"
end
