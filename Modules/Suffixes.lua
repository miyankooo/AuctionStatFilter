local _, ns = ...

-- Written by Tools/suffixes.py from the client's item tables, build 1.60.1.70938. Do not edit by hand.

-- The stats a random suffix adds, by the suffix id an auction item key carries. Suffix gear keeps its stats in
-- the suffix, not on the item, so the tooltip of an item key does not show them. Stats the filter cannot read,
-- such as resistances, are left out
ns.SuffixStats = {
    [14296] = { "intellect" }, -- of Intellect
    [14297] = { "spirit" }, -- of Spirit
    [14298] = { "stamina" }, -- of Stamina
    [14299] = { "intellect", "spirit" }, -- of the Owl
    [14300] = { "intellect", "stamina" }, -- of the Eagle
    [14301] = { "spirit", "stamina" }, -- of the Whale
    [14302] = { "stamina", "strength" }, -- of the Bear
    [14303] = { "intellect", "strength" }, -- of the Gorilla
    [14304] = { "agility", "intellect" }, -- of the Falcon
    [14305] = { "spirit", "strength" }, -- of the Boar
    [14306] = { "agility", "spirit" }, -- of the Wolf
    [14307] = { "agility", "strength" }, -- of the Tiger
    [14308] = { "agility" }, -- of Agility
    [14309] = { "intellect" }, -- of Intellect
    [14310] = { "spirit" }, -- of Spirit
    [14311] = { "stamina" }, -- of Stamina
    [14312] = { "strength" }, -- of Strength
    [14313] = { "attackpower" }, -- of Power
    [14314] = { "spellpower" }, -- of Magic
    [14315] = { "healing", "spellpower" }, -- of Healing
    [14316] = { "defense" }, -- of Defense
    [14317] = { "hp5" }, -- of Regeneration
    [14318] = { "mp5" }, -- of Concentration
    [14319] = { "agility" }, -- of Eluding
    [14320] = { "stamina" }, -- of Arcane Protection
    [14321] = { "stamina" }, -- of Fire Protection
    [14322] = { "stamina" }, -- of Frost Protection
    [14323] = { "stamina" }, -- of Nature Protection
    [14324] = { "stamina" }, -- of Shadow Protection
    [14325] = { "intellect", "spellpower", "stamina" }, -- of the Sorcerer
    [14326] = { "intellect", "spellpower", "spirit" }, -- of the Elder
    [14327] = { "spellpower", "spirit", "stamina" }, -- of the Channeler
    [14328] = { "healing", "intellect", "spellpower", "stamina" }, -- of the Physician
    [14329] = { "healing", "spellpower", "spirit", "stamina" }, -- of the Hierophant
    [14330] = { "agility", "attackpower", "stamina" }, -- of the Bandit
    [14331] = { "agility", "stamina", "strength" }, -- of the Beast
    [14332] = { "defense", "stamina", "strength" }, -- of the Champion
    [14333] = { "defense", "spellpower", "stamina" }, -- of the Defender
    [14334] = { "spellpower", "stamina", "strength" }, -- of the Knight
    [14335] = { "arcanedamage" }, -- of Arcane Wrath
    [14336] = { "firedamage" }, -- of Fiery Wrath
    [14337] = { "frostdamage" }, -- of Frozen Wrath
    [14338] = { "holydamage" }, -- of Holy Wrath
    [14339] = { "naturedamage" }, -- of Nature's Wrath
    [14340] = { "shadowdamage" }, -- of Shadow Wrath
    [14455] = { "agility", "stamina" }, -- of the Monkey
    [14473] = { "healing", "intellect", "spellpower", "spirit" }, -- of the Prophet
}

-- Items whose suffix adds other stats than it does on most gear, such as weapons of Magic with Intellect
ns.SuffixItemStats = {
    { suffix = 14314, stats = { "intellect", "spellpower" }, items = { -- of Magic
        727, 789, 790, 863, 864, 865, 866, 1207, 1259, 1608, 1613, 1639, 1640, 1990, 1994, 2072, 2073, 2075, 2077,
        2078, 2079, 2080, 2140, 2632, 2819, 3184, 3185, 3186, 3187, 3193, 3195, 3198, 3199, 3201, 3208, 3210, 3740,
        4088, 4561, 4562, 4564, 4566, 4568, 4569, 4570, 4571, 4575, 8194, 8196, 10828, 15210, 15211, 15212, 15213,
        15214, 15215, 15216, 15217, 15218, 15219, 15220, 15221, 15222, 15223, 15224, 15225, 15226, 15227, 15228,
        15229, 15230, 15231, 15232, 15233, 15234, 15235, 15236, 15237, 15238, 15239, 15240, 15241, 15242, 15243,
        15244, 15245, 15246, 15247, 15259, 15260, 15261, 15262, 15263, 15264, 15265, 15266, 15267, 15268, 15269,
        15270, 15271, 15272, 15273, 15274, 15275, 15276, 15278, 16792, 17342,
    } },
    { suffix = 14315, stats = { "healing", "intellect", "spellpower" }, items = { -- of Healing
        727, 789, 790, 863, 864, 865, 866, 1207, 1259, 1608, 1613, 1625, 1639, 1640, 1990, 1994, 2072, 2073, 2075,
        2077, 2078, 2079, 2080, 2140, 2632, 2819, 3184, 3185, 3186, 3187, 3192, 3193, 3195, 3196, 3197, 3198, 3199,
        3201, 3206, 3208, 3210, 3740, 4088, 4561, 4562, 4564, 4566, 4567, 4568, 4569, 4570, 4571, 4575, 8178, 8194,
        8196, 8199, 10828, 15210, 15211, 15212, 15213, 15214, 15215, 15216, 15217, 15218, 15219, 15220, 15221, 15222,
        15223, 15224, 15225, 15226, 15227, 15228, 15229, 15230, 15231, 15232, 15233, 15234, 15235, 15236, 15237,
        15238, 15239, 15240, 15241, 15242, 15243, 15244, 15245, 15246, 15247, 15248, 15249, 15250, 15251, 15252,
        15253, 15254, 15255, 15256, 15257, 15258, 15259, 15260, 15261, 15262, 15263, 15264, 15265, 15266, 15267,
        15268, 15269, 15270, 15271, 15272, 15273, 15274, 15275, 15276, 15278, 16792, 17342,
    } },
    { suffix = 14344, stats = { "stamina" }, items = { -- of Arcane Resistance
        10777, 11764, 11765, 11766, 11767,
    } },
}
