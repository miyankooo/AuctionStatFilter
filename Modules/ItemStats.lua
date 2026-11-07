local _, ns = ...

-- The stats of an auction item key, read from the client's own tooltip data and stat strings
ns.ItemStats = {}

-- Primary stat names, lowercased to match the lowercased tooltip text
local STAT_TOKENS = {
    strength = SPELL_STAT1_NAME:lower(),
    agility = SPELL_STAT2_NAME:lower(),
    stamina = SPELL_STAT3_NAME:lower(),
    intellect = SPELL_STAT4_NAME:lower(),
    spirit = SPELL_STAT5_NAME:lower(),
}

local function escapePattern(text)
    return (text:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0"))
end

-- Lua pattern for a client stat string: %c is the sign and %s or %d the amount ("%c%s Agility"). Specifiers are marked before escaping so the text around them stays literal
local function modPattern(format)
    local marked = format:lower():gsub("%%c", "\1"):gsub("%%%d?%$?[sd]", "\2")
    local pattern = escapePattern(marked):gsub("\1", "[+-]"):gsub("\2", "([%%d%%.,]+)")
    return "^" .. pattern .. "$"
end

-- Stat suffixes of the client's ITEM_MOD_<name> strings. Stats the filter never offers stay listed, so their lines
-- match here first and never reach the heuristics: "critical strike avoidance" must not read as critical strike
local MOD_STATS = {
    STRENGTH = "strength", AGILITY = "agility", STAMINA = "stamina", INTELLECT = "intellect", SPIRIT = "spirit",
    HEALTH = "health", MANA = "mana", EXTRA_ARMOR = "bonusarmor",
    HEALTH_REGEN = "hp5", HEALTH_REGENERATION = "hp5", MANA_REGENERATION = "mp5",
    ATTACK_POWER = "attackpower", RANGED_ATTACK_POWER = "rangedattackpower", FERAL_ATTACK_POWER = "feralattackpower",
    HIT_RATING = "hit", HIT_MELEE_RATING = "hit", HIT_RANGED_RATING = "hit", HIT_SPELL_RATING = "spellhit",
    CRIT_RATING = "crit", CRIT_MELEE_RATING = "crit", CRIT_RANGED_RATING = "crit", CRIT_SPELL_RATING = "spellcrit",
    HASTE_RATING = "haste", EXPERTISE_RATING = "expertise", ARMOR_PENETRATION_RATING = "armorpenetration",
    SPELL_POWER = "spellpower", SPELL_DAMAGE_DONE = "spellpower", SPELL_HEALING_DONE = "healing",
    PHYSICAL_DAMAGE_DONE = "physicaldamage", ARCANE_DAMAGE_DONE = "arcanedamage", FIRE_DAMAGE_DONE = "firedamage",
    FROST_DAMAGE_DONE = "frostdamage", HOLY_DAMAGE_DONE = "holydamage", NATURE_DAMAGE_DONE = "naturedamage",
    SHADOW_DAMAGE_DONE = "shadowdamage",
    SPELL_PENETRATION = "spellpenetration", ARCANE_PENETRATION = "arcanepenetration", FIRE_PENETRATION = "firepenetration",
    FROST_PENETRATION = "frostpenetration", NATURE_PENETRATION = "naturepenetration", SHADOW_PENETRATION = "shadowpenetration",
    SPELL_RESISTANCE_ALL_SCHOOLS = "spellresistance",
    DEFENSE_SKILL_RATING = "defense", DODGE_RATING = "dodge", PARRY_RATING = "parry",
    BLOCK_RATING = "block", BLOCK_VALUE = "blockvalue",
    HIT_TAKEN_RATING = "hitavoidance", HIT_TAKEN_MELEE_RATING = "hitavoidance", HIT_TAKEN_RANGED_RATING = "hitavoidance",
    HIT_TAKEN_SPELL_RATING = "hitavoidance", CRIT_TAKEN_RATING = "critavoidance", CRIT_TAKEN_MELEE_RATING = "critavoidance",
    CRIT_TAKEN_RANGED_RATING = "critavoidance", CRIT_TAKEN_SPELL_RATING = "critavoidance", RESILIENCE_RATING = "resilience",
}

-- Each stat line in both forms the client prints: long "increases your haste by 12." and short "+12 haste". Built from the client's own strings, so they parse in any locale and a stat only exists where the client has its string
local MOD_PATTERNS = {}
for name, key in pairs(MOD_STATS) do
    local long, short = _G["ITEM_MOD_" .. name], _G["ITEM_MOD_" .. name .. "_SHORT"]
    if long then
        MOD_PATTERNS[#MOD_PATTERNS + 1] = { modPattern(long), key }
    end
    if short then
        MOD_PATTERNS[#MOD_PATTERNS + 1] = { "^[+-]([%d%.,]+) " .. escapePattern(short:lower()) .. "$", key }
    end
end

-- Key of a line in the client's stat wording; nil for any other line
local function modStat(line)
    for _, entry in ipairs(MOD_PATTERNS) do
        if line:match(entry[1]) then return entry[2] end
    end
    return nil
end

-- Leading text of a format string up to its %s, escaped for a pattern
local function prefixOf(format)
    return escapePattern(format:lower():match("^(.-)%%s"))
end

local EQUIP_PREFIX = "^" .. escapePattern(ITEM_SPELL_TRIGGER_ONEQUIP:lower()) .. " ?"

-- Active set bonuses print "Set: ...", inactive ones "(2) Set: ..."; ITEM_SET_BONUS_GRAY keeps its %d, which the pattern reads as the single-digit piece count
local SKIPPED_PREFIXES = {
    "^" .. escapePattern(ITEM_SPELL_TRIGGER_ONUSE:lower()),
    "^" .. escapePattern(ITEM_SPELL_TRIGGER_ONPROC:lower()),
    "^" .. prefixOf(ITEM_SET_BONUS),
    "^" .. prefixOf(ITEM_SET_BONUS_GRAY),
}

-- Use effects, procs and set bonuses carry numbers but are not item stats
local function isSkipped(line)
    for _, prefix in ipairs(SKIPPED_PREFIXES) do
        if line:find(prefix) then return true end
    end
    return false
end

-- Primary stats, robust to "+N Stat", "Stat increased by N" and "+N to all attributes"
local function addPrimaryStats(line, present)
    if line:find("all attributes", 1, true) or line:find("all stats", 1, true) then
        for key in pairs(STAT_TOKENS) do present[key] = true end
        return
    end
    for key, token in pairs(STAT_TOKENS) do
        if line:find(token, 1, true) then present[key] = true end
    end
end

-- Spell schools as they appear in vanilla school damage lines
local SPELL_SCHOOLS = { "arcane", "fire", "frost", "holy", "nature", "shadow" }

-- Generic spell power wordings: Equip effects, random-suffix lines and the combined stat
local SPELL_POWER_TOKENS = { "magical spells", "damage done by spells", "damage from spells", "damage and healing", "spell damage", "spell power" }

local function findAny(line, tokens)
    for _, token in ipairs(tokens) do
        if line:find(token, 1, true) then return true end
    end
    return false
end

-- Secondary stats from vanilla Equip wordings the client strings do not cover (English client). Creature-specific and form-only bonuses are skipped, so they never pass as plain attack power
local function addSecondaryStats(line, present)
    if findAny(line, { "when fighting", "damage done to", " vs ", "slaying", "against", "forms only" }) then return end

    if line:find("attack power", 1, true) then
        present[line:find("ranged", 1, true) and "rangedattackpower" or "attackpower"] = true
    end

    local schoolDamage = false
    for _, school in ipairs(SPELL_SCHOOLS) do
        if line:find(school, 1, true) and line:find("spell", 1, true) and line:find("damage", 1, true) then
            present[school .. "damage"] = true
            schoolDamage = true
        end
    end
    if not schoolDamage and findAny(line, SPELL_POWER_TOKENS) then
        present.spellpower = true
    end
    if line:find("healing", 1, true) and not line:find("damage", 1, true) then
        present.healing = true
    end

    -- Vanilla spell piercing reads "Decreases the magical resistances of your spell targets by 10."
    if line:find("magical resistances", 1, true) then
        present.spellpenetration = true
    end

    local spell = line:find("spell", 1, true) or line:find("magic", 1, true)
    if line:find("critical", 1, true) then
        present[spell and "spellcrit" or "crit"] = true
    end
    if line:find("chance to hit", 1, true) or line:find("spell hit", 1, true) or line:match("%% hit") or line:match("hit %+%d") then
        if spell then present.spellhit = true end
        if not spell or findAny(line, { "melee", "weapon", "missile", "attacks" }) then present.hit = true end
    end

    if line:find("defense", 1, true) then present.defense = true end
    if line:find("dodge", 1, true) then present.dodge = true end
    if line:find("parry", 1, true) then present.parry = true end
    if line:find("block value", 1, true) or line:match("^%d+ block$") then
        present.blockvalue = true
    elseif line:find("block", 1, true) then
        present.block = true
    end

    if line:find("5 sec", 1, true) and line:find("mana", 1, true) then present.mp5 = true end
end

-- Set of stat keys in an item's lowercased tooltip text. The client's own stat wording wins, older Equip wordings fall back to the heuristics. Only lines with a number can carry a stat, so the rest skip the pattern scan
function ns.ItemStats.FullStatSet(itemText)
    local present = {}
    for rawLine in itemText:gmatch("[^\n]+") do
        if rawLine:find("%d") then
            local line = rawLine:gsub(EQUIP_PREFIX, "")
            local key = modStat(line)
            if key then
                present[key] = true
            elseif not isSkipped(line) then
                addPrimaryStats(line, present)
                addSecondaryStats(line, present)
            end
        end
    end
    return present
end

-- Flatten tooltip data into lowercased text, left then right text per line; nil without lines
local function textOf(data)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    local parts = {}
    for _, line in ipairs(data.lines) do
        if type(line.leftText) == "string" and line.leftText ~= "" then parts[#parts + 1] = line.leftText end
        if type(line.rightText) == "string" and line.rightText ~= "" then parts[#parts + 1] = line.rightText end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, "\n"):lower()
end

-- Stat sets by item key, kept for the session: an item key's stats never change, and both auction lists ask for the same keys again on every refilter
local cache = {}

-- Item ids already asked of the server, so a row that waits for its data asks once
local requested = {}

-- Stat set of an auction item key; nil while the client still loads the item. Vanilla random suffixes carry fixed stats per suffix id, so the key renders the exact stats without a full link
function ns.ItemStats.ForItemKey(itemKey)
    local itemID, itemLevel, itemSuffix = itemKey.itemID, itemKey.itemLevel or 0, itemKey.itemSuffix or 0
    local cacheKey = itemID .. ":" .. itemLevel .. ":" .. itemSuffix
    local stats = cache[cacheKey]
    if stats then return stats end

    if not C_Item.IsItemDataCachedByID(itemID) then
        if not requested[itemID] then
            requested[itemID] = true
            C_Item.RequestLoadItemDataByID(itemID)
        end
        return nil
    end

    local ok, data = pcall(C_TooltipInfo.GetItemKey, itemID, itemLevel, itemSuffix)
    local text = ok and textOf(data)
    if not text then return nil end
    stats = ns.ItemStats.FullStatSet(text)
    cache[cacheKey] = stats
    return stats
end
