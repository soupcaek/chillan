-- Chillan? Dungeon Journal – data: Wailing Caverns (WoW Forever)
-- Bosses, quest givers, chains and coordinates from public Forever dungeon guides.
-- Quest IDs: from the Classic database; /cdj debug checks them against the game.
-- Boss pin positions on the dungeon map are first guesses – fix them in-game with "Edit pins".
local ADDON, ns = ...

local WC = {
  key = "wc",
  name = "Wailing Caverns",
  zone = "The Barrens",
  where = "Lushwater Oasis",
  levels = { 15, 24 }, entry = 10, finder = 17, size = 5,
  clear = "30–40 min",
  map = { names = { "Wailing Caverns" }, hint = 279 },
  zoneMap = { names = { "The Barrens", "Northern Barrens" }, hint = 1413 },
  tbMap = { names = { "Thunder Bluff" }, hint = 1456 },
  entrance = { x = 0.460, y = 0.363 },
  entranceSteps = {
    "Cave opening at Lushwater Oasis, The Barrens (46.0, 36.3) – the Cavern of Mists.",
    "Follow it down to the big cavern with a pool – the portal is there.",
    "Elites patrol the outer cave – go in together.",
  },
  tips = {
    { color = "amber", text = "Leaders of the Fang needs a 3-step chain in Thunder Bluff first (Hamuul, then Nara)." },
    { color = "amber", text = "Smart Drinks unlocks after Raptor Horns (Mebok Mizzyrix, Ratchet)." },
    { color = "blue", text = "Plan to run it twice – Deviate Hides and Smart Drinks rarely finish in one run." },
  },

  bosses = {
    { n = 1, name = "Kresh", where = "Turtle wandering the stream in the central cavern. No abilities – just hits hard.",
      quest = "Deviate Hide", loot = { "Worn Turtle Shell Shield", "Kresh's Back" }, pin = { 0.47, 0.52 } },
    { n = 2, name = "Lady Anacondra", where = "Spawns at one of the ritual circles on the upper ledges of the central cavern.",
      quest = "Gem of Anacondra", loot = { "Serpent's Shoulders", "Belt of the Fang", "Searing Blade" }, pin = { 0.38, 0.46 } },
    { n = 3, name = "Lord Cobrahn", where = "First wing, the Pit of Fangs. Kill the three Deviate Pythons first.",
      quest = "Gem of Cobrahn", loot = { "Robe of the Moccasin", "Cobrahn's Grasp", "Leggings of the Fang" }, pin = { 0.25, 0.38 } },
    { n = "R", name = "Deviate Faerie Dragon", rare = true, where = "Spawns only now and then, in several spots.",
      pin = { 0.55, 0.40 } },
    { n = 4, name = "Lord Pythas", where = "In the larger wing, with a Druid of the Fang beside him.",
      quest = "Gem of Pythas", loot = { "Armor of the Fang", "Stinging Viper", "Stormbringer Belt" }, pin = { 0.66, 0.30 } },
    { n = 5, name = "Skum", where = "Thunder lizard in the Winding Chasm.",
      quest = "Deviate Hide", loot = { "Glowing Lizardscale Cloak", "Tail Spike" }, pin = { 0.72, 0.55 } },
    { n = 6, name = "Lord Serpentis", where = "Also in the larger wing, no adds. Last gem for Leaders of the Fang.",
      quest = "Gem of Serpentis", loot = { "Savage Trodders", "Serpent Gloves", "Venomstrike", "Footpads of the Fang" }, pin = { 0.78, 0.22 } },
    { n = 7, name = "Verdan the Everliving", where = "Elemental near the waterfall, after Lord Serpentis.",
      loot = { "Seedcloud Buckler", "Living Root", "Sporid Cape" }, pin = { 0.84, 0.34 } },
    { n = 8, name = "Mutanus the Devourer", final = true,
      where = "Escort the Disciple of Naralex to the ritual stone in the last room – Mutanus rises from the pool.",
      quest = "Glowing Shard (starts a quest)", loot = { "Slime-encrusted Pads", "Deep Fathom Ring", "Mutant Scale Breastplate" }, pin = { 0.50, 0.30 } },
  },
  others = {
    { name = "Mad Magglish", where = "Goblin inside – has the 99-Year-Old Port for Trouble at the Docks.", pin = { 0.60, 0.62 } },
  },

  chains = {
    {
      name = "Leaders of the Fang", faction = "Horde", note = "3 steps · starts in Thunder Bluff",
      steps = {
        { name = "Hamuul Runetotem", level = 16, text = "Speak with Hamuul · Thunder Bluff, Elder Rise" },
        { name = "Nara Wildmane", level = 16, text = "Speak with Nara · Thunder Bluff (75.6, 31.2)",
          wp = { map = "tb", x = 0.756, y = 0.312 } },
        { name = "Leaders of the Fang", id = 914, level = 22, inside = true,
          text = "Gems of Anacondra, Cobrahn, Pythas and Serpentis then back to Nara Wildmane" },
      },
    },
    {
      name = "Smart Drinks", note = "2 steps · Ratchet",
      steps = {
        { name = "Raptor Horns", id = 865, pre = true, text = "5 Intact Raptor Horns from Sunscale Scytheclaws · Mebok Mizzyrix, Ratchet",
          wp = { map = "zone", x = 0.624, y = 0.376 } },
        { name = "Smart Drinks", id = 1491, level = 18, inside = true,
          text = "6 Wailing Essence from the ectoplasmic creatures then back to Mebok (62.4, 37.6)", wp = { map = "zone", x = 0.624, y = 0.376 } },
      },
    },
    {
      name = "The Glowing Shard", note = "starts from a drop · not shareable",
      steps = {
        { name = "The Glowing Shard", id = 6981, level = 15, text = "Loot the Glowing Shard from Mutanus" },
        { name = "Sputtervalve", text = "Talk to him in Ratchet (63.0, 37.2)", wp = { map = "zone", x = 0.630, y = 0.372 }, talk = true },
        { name = "Falla Sagewind", text = "Hut on the hill above the cave (48.2, 32.8) – path up from (45.4, 34.1)",
          wp = { map = "zone", x = 0.482, y = 0.328 }, talk = true },
        { name = "In Nightmares", text = "Take it to Hamuul Runetotem, Thunder Bluff" },
      },
    },
  },
  singles = {
    { name = "Deviate Hides", id = 1486, level = 17, text = "Nalpak, above the entrance · 20 Deviate Hide" },
    { name = "Deviate Eradication", id = 1487, level = 21, text = "Ebru, outside the instance (moves, goes invisible) · 7 each of 4 Deviates" },
    { name = "Trouble at the Docks", id = 959, level = 18, text = "Crane Operator Bigglefuzz, Ratchet (63.0, 37.4) · 99-Year-Old Port from Mad Magglish",
      wp = { map = "zone", x = 0.630, y = 0.374 } },
    { name = "Serpentbloom", id = 962, level = 18, faction = "Horde", text = "Apothecary Zamah, Thunder Bluff (23.0, 21.0) · 10 Serpentbloom, in and outside",
      wp = { map = "tb", x = 0.230, y = 0.210 } },
  },
  givers = {
    { name = "Nalpak", where = "above the entrance" },
    { name = "Ebru", where = "outer cave, moves around" },
    { name = "Falla Sagewind", where = "hilltop hut (48.2, 32.8)", wp = { map = "zone", x = 0.482, y = 0.328 } },
    { name = "Path up the hill", where = "starts at (45.4, 34.1)", wp = { map = "zone", x = 0.454, y = 0.341 } },
  },
}

-- flat list of every quest (chain steps that are real quests + singles), for counting and /cdj debug
WC.allQuests = {}
for _, ch in ipairs(WC.chains) do
  for _, s in ipairs(ch.steps) do if not s.talk then WC.allQuests[#WC.allQuests + 1] = s end end
end
for _, q in ipairs(WC.singles) do WC.allQuests[#WC.allQuests + 1] = q end

ns.DUNGEONS = { WC }

-- the rest of the list (not filled in yet in this demo)
ns.COMING = {
  { name = "Ragefire Chasm", levels = "13–18", zone = "Orgrimmar" },
  { name = "Ruins of Lordaeron", levels = "15–20", zone = "Tirisfal Glades", new = true },
  { name = "Shadowfang Keep", levels = "22–30", zone = "Silverpine Forest" },
  { name = "Excavation Site", levels = "24–29", zone = "Wetlands", new = true },
  { name = "Blackfathom Deeps", levels = "24–32", zone = "Ashenvale" },
  { name = "Razorfen Kraul", levels = "30–40", zone = "The Barrens" },
}
