local addonName, ns = ...

-- The chosen stats and how they combine, shared by every auction list, and the Stats button that sets them
ns.Filter = {}

-- Fixed on the grid, narrow enough to fit between Blizzard's search box and its own Filter button
local DROPDOWN_WIDTH = 80
-- Between Stats and the button on its right
local GAP = 8
local DROPDOWN_LABEL = "Stats"
local TIP_TEXT = "Pick item stats here to fade out gear without them."

-- How the chosen stats combine, the radios at the top of the menu
local LOGIC = {
    { label = "Match All", logic = "AND", help = "Gear fades unless it has every stat you tick." },
    { label = "Match Any", logic = "OR", help = "Gear fades unless it has at least one stat you tick." },
}

-- The stats on offer in the character sheet's categories; each key is one ns.ItemStats reads
local CATEGORIES = {
    { STAT_CATEGORY_ATTRIBUTES, { "strength", "agility", "stamina", "intellect", "spirit" } },
    { STAT_CATEGORY_ATTACK, { "attackpower", "rangedattackpower", "hit", "crit", "haste", "expertise", "armorpenetration" } },
    { STAT_CATEGORY_SPELL, { "spellpower", "healing", "spellhit", "spellcrit", "spellpenetration", "mp5",
        "arcanedamage", "firedamage", "frostdamage", "holydamage", "naturedamage", "shadowdamage" } },
    { STAT_CATEGORY_DEFENSE, { "defense", "dodge", "parry", "block", "blockvalue" } },
}

-- Labels are the client's own stat names, so they read like the item tooltips in every locale
local LABELS = {
    strength = SPELL_STAT1_NAME,
    agility = SPELL_STAT2_NAME,
    stamina = SPELL_STAT3_NAME,
    intellect = SPELL_STAT4_NAME,
    spirit = SPELL_STAT5_NAME,
    attackpower = ITEM_MOD_ATTACK_POWER_SHORT,
    rangedattackpower = ITEM_MOD_RANGED_ATTACK_POWER_SHORT,
    hit = ITEM_MOD_HIT_RATING_SHORT,
    crit = ITEM_MOD_CRIT_RATING_SHORT,
    haste = ITEM_MOD_HASTE_RATING_SHORT,
    expertise = ITEM_MOD_EXPERTISE_RATING_SHORT,
    armorpenetration = ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT,
    spellpower = ITEM_MOD_SPELL_POWER_SHORT,
    healing = ITEM_MOD_SPELL_HEALING_DONE_SHORT,
    spellhit = ITEM_MOD_HIT_SPELL_RATING_SHORT,
    spellcrit = ITEM_MOD_CRIT_SPELL_RATING_SHORT,
    spellpenetration = ITEM_MOD_SPELL_PENETRATION_SHORT,
    mp5 = ITEM_MOD_MANA_REGENERATION_SHORT,
    arcanedamage = ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT,
    firedamage = ITEM_MOD_FIRE_DAMAGE_DONE_SHORT,
    frostdamage = ITEM_MOD_FROST_DAMAGE_DONE_SHORT,
    holydamage = ITEM_MOD_HOLY_DAMAGE_DONE_SHORT,
    naturedamage = ITEM_MOD_NATURE_DAMAGE_DONE_SHORT,
    shadowdamage = ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT,
    defense = ITEM_MOD_DEFENSE_SKILL_RATING_SHORT,
    dodge = ITEM_MOD_DODGE_RATING_SHORT,
    parry = ITEM_MOD_PARRY_RATING_SHORT,
    block = ITEM_MOD_BLOCK_RATING_SHORT,
    blockvalue = ITEM_MOD_BLOCK_VALUE_SHORT,
}

-- Bumps on every change, so the lists know when to filter again
ns.Filter.version = 0

local dropdowns = {}

-- Account-wide { stats = { strength = true, ... }, logic = "AND" or "OR", tipSeen = true once the tip is done } in
-- ns.db from ADDON_LOADED on. An absent table marks the account's first run, for the welcome line. A saved stat the
-- menu no longer offers is dropped
EventUtil.ContinueOnAddOnLoaded(addonName, function()
    ns.firstRun = type(AuctionStatFilterDB) ~= "table"
    if ns.firstRun then AuctionStatFilterDB = {} end
    local db = AuctionStatFilterDB
    if type(db.stats) ~= "table" then db.stats = {} end
    if db.logic ~= "OR" then db.logic = "AND" end
    for key in pairs(db.stats) do
        if not LABELS[key] then db.stats[key] = nil end
    end
    ns.db = db
end)

local function isActive()
    return next(ns.db.stats) ~= nil
end

local function activeCount()
    local count = 0
    for _ in pairs(ns.db.stats) do count = count + 1 end
    return count
end

-- Shows the number of chosen stats, and nothing while none is chosen, like the reset button
local function updateBadge(dropdown)
    local count = activeCount()
    dropdown.Badge.Count:SetText(count)
    dropdown.Badge:SetShown(count > 0)
end

-- The lists read the version on their next frame; the buttons update at once
local function changed()
    ns.Filter.version = ns.Filter.version + 1
    for _, dropdown in ipairs(dropdowns) do
        dropdown:ValidateResetState()
        updateBadge(dropdown)
    end
end

-- A school filter is also met by generic spell power, which boosts every school
local function hasStat(present, key)
    if present[key] then return true end
    return key:match("damage$") ~= nil and present.spellpower ~= nil
end

-- Whether an auction item key passes: true or false, nil while its item data loads. Only weapons and armour are
-- filtered, so consumables, trade goods and Auctionator's placeholder for a missing search term (item 1217) always pass
function ns.Filter.Matches(itemKey)
    if not isActive() or not itemKey or not itemKey.itemID then return true end
    local classID = select(6, C_Item.GetItemInfoInstant(itemKey.itemID))
    if classID ~= Enum.ItemClass.Weapon and classID ~= Enum.ItemClass.Armor then return true end

    local present = ns.ItemStats.ForItemKey(itemKey)
    if not present then return nil end

    -- Match Any passes on the first stat found, Match All fails on the first one missing
    local any = ns.db.logic == "OR"
    for key in pairs(ns.db.stats) do
        if hasStat(present, key) == any then return any end
    end
    return not any
end

local function isLogic(logic) return ns.db.logic == logic end
local function setLogic(logic)
    ns.db.logic = logic
    changed()
end

local function isChecked(key) return ns.db.stats[key] == true end
local function toggle(key)
    local stats = ns.db.stats
    stats[key] = not stats[key] or nil
    changed()
end

local function clearStats()
    wipe(ns.db.stats)
    changed()
end

-- A GameTooltip owned by the hovered frame, filled with Blizzard's GameTooltip_* line helpers. A frame whose
-- template already sets OnEnter gets HookScript instead.
local function AttachTooltip(frame, fill, anchor)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        fill(GameTooltip, self)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", GameTooltip_Hide)
end

-- Rounds a length derived from text up to the 4 px grid.
local function Snap(length)
    return math.ceil(length / 4) * 4
end

-- Blizzard's Filter button (Blizzard_Menu/Mainline/MenuTemplates.xml:66), as on the Who list. The template sizes
-- itself to its text; the width is fixed on the grid so later text never moves it. Set SetDefaultCallback and
-- SetIsDefaultCallback before SetupMenu; the template then shows its own reset button.
local function CreateFilterDropdown(parent, width)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1FilterDropdownTemplate")
    dropdown.resizeToText = false
    dropdown:SetWidth(width or Snap(dropdown:GetWidth()))
    return dropdown
end

-- The count badge Blizzard puts on a button's corner, as on the shop's cart button
-- (Blizzard_GenericShoppingCart/Blizzard_GenericShoppingCartTemplates.xml:255): atlas tokens-counterBG, 24 px, on
-- the top left corner 3 px in, mirroring a filter's reset button on the top right (MenuTemplates.xml:85). The
-- number sits on the circle's centre (Blizzard_CatalogShop/Blizzard_CatalogShop.xml:301), moved right by half its
-- drop shadow so its odd-width box lands on a whole pixel. Show it with a count, hide it at zero.
local function CreateCountBadge(button)
    local badge = CreateFrame("Frame", nil, button)
    badge:SetSize(24, 24)
    badge:SetPoint("CENTER", button, "TOPLEFT", 3, 0)
    local circle = badge:CreateTexture(nil, "ARTWORK")
    circle:SetAtlas("tokens-counterBG")
    circle:SetAllPoints()
    badge.Count = badge:CreateFontString(nil, "OVERLAY")
    badge.Count:SetFontObject(GameFontHighlight)
    badge.Count:SetPoint("CENTER", badge, "CENTER", badge.Count:GetShadowOffset() / 2, 0)
    -- A button that sizes itself to its text can sit between pixels; whole pixels keep the number centred.
    badge:SetRoundLayoutToNearestPixel(true)
    circle:SetRoundLayoutToNearestPixel(true)
    badge:Hide()
    return badge
end

-- One owner for the menu callbacks, so the registry takes it instead of counting up an id of Blizzard's own
local callbackOwner = {}

-- Blizzard's yellow help tip, the one the Auction House uses for its undercut tip
-- (Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSellFrame.lua:507), with the close button. An own
-- HelpTipTemplate frame of the target, never HelpTip:Show, which takes a frame from Blizzard's shared pool, and
-- writing to that pool from addon code taints the help tips Blizzard shows later. It shows each time the target shows
-- until the player closes it or opens the menu, then never again on the account; it hides with the target unmarked.
local function AttachTip(target, text, targetPoint)
    local tip
    local info = {
        text = text,
        buttonStyle = HelpTip.ButtonStyle.Close,
        targetPoint = targetPoint,
        onAcknowledgeCallback = function() ns.db.tipSeen = true end,
    }
    local function ShowTip()
        if ns.db.tipSeen then return end
        if not tip then
            tip = CreateFrame("Frame", nil, target, "HelpTipTemplate")
            tip.width = HelpTip.width
            tip:SetWidth(tip.width)
        end
        tip:Init(target, info, target)
        tip:Show()
    end
    target:HookScript("OnShow", ShowTip)
    -- Opening the menu is using the feature
    target:RegisterCallback(DropdownButtonMixin.Event.OnMenuOpen, function()
        if tip and tip.info then tip:Acknowledge() else ns.db.tipSeen = true end
    end, callbackOwner)
    -- Auctionator's button can be made while its tab already shows, so it gets no OnShow of its own
    if target:IsVisible() then ShowTip() end
end

-- Blizzard's Filter button, labelled Stats, with one submenu per stat category, as the Collections filters group
-- long lists, one gap left of neighbour. Its reset button clears every stat, its badge counts them, and its help tip
-- points from tipPoint, a HelpTip.Point
function ns.Filter.CreateDropdown(parent, neighbour, tipPoint)
    local dropdown = CreateFilterDropdown(parent, DROPDOWN_WIDTH)
    dropdown:SetPoint("RIGHT", neighbour, "LEFT", -GAP, 0)
    dropdown:SetText(DROPDOWN_LABEL)
    dropdown:SetDefaultCallback(clearStats)
    dropdown:SetIsDefaultCallback(function() return not isActive() end)
    dropdown:SetupMenu(function(_, root)
        for _, option in ipairs(LOGIC) do
            root:CreateRadio(option.label, isLogic, setLogic, option.logic):SetTooltip(function(tooltip)
                GameTooltip_SetTitle(tooltip, option.label)
                GameTooltip_AddNormalLine(tooltip, option.help)
            end)
        end
        root:CreateDivider()
        for _, category in ipairs(CATEGORIES) do
            local submenu = root:CreateButton(category[1])
            for _, key in ipairs(category[2]) do
                -- A stat whose name the client lacks is one its items never carry
                if LABELS[key] then submenu:CreateCheckbox(LABELS[key], isChecked, toggle, key) end
            end
        end
    end)
    -- The template's OnEnter drives the button's art, so the tooltips hook in after it
    AttachTooltip(dropdown, function(tooltip)
        GameTooltip_SetTitle(tooltip, DROPDOWN_LABEL)
        GameTooltip_AddNormalLine(tooltip, "Fades out gear without the stats you tick. Items that are not gear, such "
            .. "as consumables, always stay.")
    end)
    AttachTooltip(dropdown.ResetButton, function(tooltip)
        GameTooltip_SetTitle(tooltip, CLEAR_ALL)
        GameTooltip_AddNormalLine(tooltip, "Clears every stat, so no gear fades.")
    end)
    dropdown.Badge = CreateCountBadge(dropdown)
    updateBadge(dropdown)
    dropdowns[#dropdowns + 1] = dropdown
    AttachTip(dropdown, TIP_TEXT, tipPoint)
    return dropdown
end
