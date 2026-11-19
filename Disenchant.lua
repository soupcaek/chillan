-- Chillan? Market – Disenchantry (1.3.5): what an item gives when disenchanted (classic table, the one
-- WoW Forever uses), what that's worth at the auction house, and whether disenchanting beats selling.
local ADDON, ns = ...
local D = {}
ns.Disenchant = D

local MAT = {
  strange = 10940, soul = 11083, vision = 11137, dream = 11176, illusion = 16204,
  lmagic = 10938, gmagic = 10939, lastral = 10998, gastral = 11082, lmystic = 11134, gmystic = 11135,
  lnether = 11174, gnether = 11175, leternal = 16202, geternal = 16203,
  sglim = 10978, lglim = 11084, sglow = 11138, lglow = 11139, srad = 11177, lrad = 11178,
  sbril = 14343, lbril = 14344, nexus = 20725,
}
D.MAT = MAT

-- green (uncommon) armor, by item level: { up to level, dust {id, min, max, chance}, essence, shard }
local GREEN = {
  { 15, { "strange", 1, 2, 0.80 }, { "lmagic", 1, 2, 0.20 } },
  { 20, { "strange", 2, 3, 0.75 }, { "gmagic", 1, 2, 0.20 }, { "sglim", 1, 1, 0.05 } },
  { 25, { "strange", 4, 6, 0.75 }, { "lastral", 1, 2, 0.15 }, { "sglim", 1, 1, 0.10 } },
  { 30, { "soul", 1, 2, 0.75 }, { "gastral", 1, 2, 0.20 }, { "lglim", 1, 1, 0.05 } },
  { 35, { "soul", 2, 5, 0.75 }, { "lmystic", 1, 2, 0.20 }, { "sglow", 1, 1, 0.05 } },
  { 40, { "vision", 1, 2, 0.75 }, { "gmystic", 1, 2, 0.20 }, { "lglow", 1, 1, 0.05 } },
  { 45, { "vision", 2, 5, 0.75 }, { "lnether", 1, 2, 0.20 }, { "srad", 1, 1, 0.05 } },
  { 50, { "dream", 1, 2, 0.75 }, { "gnether", 1, 2, 0.20 }, { "lrad", 1, 1, 0.05 } },
  { 55, { "dream", 2, 5, 0.75 }, { "leternal", 1, 2, 0.20 }, { "sbril", 1, 1, 0.05 } },
  { 60, { "illusion", 1, 2, 0.75 }, { "geternal", 1, 2, 0.20 }, { "lbril", 1, 1, 0.05 } },
  { 99, { "illusion", 2, 5, 0.75 }, { "geternal", 2, 3, 0.20 }, { "lbril", 1, 1, 0.05 } },
}
-- blue (rare): shards
local BLUE = {
  { 25, { "sglim", 1, 1, 1 } }, { 30, { "lglim", 1, 1, 1 } }, { 35, { "sglow", 1, 1, 1 } },
  { 40, { "lglow", 1, 1, 1 } }, { 45, { "srad", 1, 1, 1 } }, { 50, { "lrad", 1, 1, 1 } },
  { 55, { "sbril", 1, 1, 1 } }, { 99, { "lbril", 1, 1, 0.995 }, { "nexus", 1, 1, 0.005 } },
}
-- purple (epic)
local PURPLE = {
  { 45, { "srad", 2, 4, 1 } }, { 50, { "lrad", 2, 4, 1 } }, { 55, { "sbril", 2, 4, 1 } },
  { 60, { "nexus", 1, 1, 1 } }, { 99, { "nexus", 1, 2, 1 } },
}

local function info(id)
  local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not f then return nil end
  local ok, name, link, quality, ilvl, _, itype, _, _, loc, _, sell, classID = pcall(f, id)
  if not ok or not name then return nil end
  return { name = name, link = link, quality = quality, ilvl = ilvl, loc = loc, sell = sell, classID = classID, itype = itype }
end
D.Info = info

local ARMOR_CLASS, WEAPON_CLASS = 4, 2
local function isGear(i)
  if not i or not i.loc or i.loc == "" or i.loc == "INVTYPE_BAG" or i.loc == "INVTYPE_AMMO" or i.loc == "INVTYPE_QUIVER"
    or i.loc == "INVTYPE_TABARD" or i.loc == "INVTYPE_BODY" then return false end
  return i.classID == ARMOR_CLASS or i.classID == WEAPON_CLASS or i.classID == nil
end
local function isWeapon(i)
  return i.classID == WEAPON_CLASS or (i.loc and (i.loc:find("WEAPON") or i.loc == "INVTYPE_RANGED" or i.loc == "INVTYPE_2HWEAPON" or i.loc == "INVTYPE_RANGEDRIGHT"))
end

-- the possible results: { { id, min, max, chance }, … } or nil when it can't be disenchanted
function D:Results(id)
  local i = info(id)
  if not i or not isGear(i) or not i.quality or i.quality < 2 or i.quality > 4 or not i.ilvl then return nil end
  local tbl = i.quality == 2 and GREEN or i.quality == 3 and BLUE or PURPLE
  local row
  for _, r in ipairs(tbl) do if i.ilvl <= r[1] then row = r break end end
  if not row then return nil end
  local out = {}
  for k = 2, #row do
    local m = row[k]
    local chance = m[4]
    -- green weapons give essence where armor gives dust (and the other way around)
    if i.quality == 2 and isWeapon(i) and k <= 3 then chance = (k == 2) and row[3][4] or row[2][4] end
    out[#out + 1] = { id = MAT[m[1]], min = m[2], max = m[3], chance = chance }
  end
  return out, i
end

-- expected value at the auction house (after the 5 % cut); nil if no mat price is known
function D:Value(id)
  local res = self:Results(id)
  if not res or not ns.Market then return nil end
  local sum, known = 0, false
  for _, r in ipairs(res) do
    local e = ns.Market:Get(r.id)
    if e then
      known = true
      sum = sum + e.v * (r.min + r.max) / 2 * r.chance
    end
  end
  if not known then return nil end
  return math.floor(sum * 0.95), res
end

-- "Strange Dust 1–2 · Lesser Magic Essence 1–2 (20 %)"
function D:Describe(res)
  local parts = {}
  for _, r in ipairs(res or {}) do
    local i = info(r.id)
    local q = r.min == r.max and tostring(r.min) or (r.min .. "–" .. r.max)
    parts[#parts + 1] = ((i and i.name) or ("item " .. r.id)) .. " " .. q .. (r.chance < 1 and (" (" .. math.floor(r.chance * 100 + 0.5) .. " %)") or "")
  end
  return table.concat(parts, " · ")
end

-- the mats are in the price list, so a full scan prices them; ask the gang for any we're missing
function D:AskMats(id)
  local res = self:Results(id)
  if not res or not ns.Market then return end
  for _, r in ipairs(res) do if not ns.Market:Get(r.id) then ns.Market:Ask(r.id) end end
end
