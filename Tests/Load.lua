-- Offline smoke test: loads every file in toc order against stubs of the WoW API, Blizzard's Auction House and
-- Auctionator, then checks the parser, the Stats menu, badge and first-run tip, and the faded rows in both lists.
-- Run from the addon folder: lua Tests/Load.lua

local failures = 0
local function check(label, ok, detail)
    if not ok then failures = failures + 1 end
    print((ok and "ok   " or "FAIL ") .. label .. (ok and "" or ("  (" .. tostring(detail) .. ")")))
end

-- ===== Frames =====
-- Script-capable stand-ins; methods (capitalised) a test does not care about do nothing, unset fields read nil
local frameMethods = {}
local function noop() end
frameMethods.__index = function(_, key)
    if frameMethods[key] then return frameMethods[key] end
    if type(key) == "string" and key:match("^%u") then return noop end
end

function frameMethods:SetScript(kind, fn) self.scripts[kind] = fn end
function frameMethods:GetScript(kind) return self.scripts[kind] end
function frameMethods:HookScript(kind, fn)
    local old = self.scripts[kind]
    self.scripts[kind] = function(...) if old then old(...) end fn(...) end
end
function frameMethods:Show() self.shown = true end
function frameMethods:SetShown(shown) self.shown = shown and true or false end
function frameMethods:SetSize(w, h) self.width, self.height = w, h end
function frameMethods:SetAtlas(atlas) self.atlas = atlas end
function frameMethods:SetAllPoints() self.allPoints = true end
function frameMethods:SetJustifyH(justify) self.justifyH = justify end
function frameMethods:SetJustifyV(justify) self.justifyV = justify end
function frameMethods:SetRoundLayoutToNearestPixel(on) self.rounded = on end
function frameMethods:CreateTexture() local t = setmetatable({ scripts = {}, events = {}, shown = true, owner = self }, frameMethods) self.texture = t return t end
function frameMethods:CreateFontString() local f = setmetatable({ scripts = {}, events = {}, shown = true, owner = self }, frameMethods) return f end
function frameMethods:Hide() self.shown = false end
function frameMethods:IsShown() return self.shown end
function frameMethods:IsVisible() return self.shown and (self.owner == nil or self.owner:IsVisible()) end
function frameMethods:RegisterCallback(event, fn, owner) self.callbacks = self.callbacks or {} self.callbacks[event] = { fn = fn, owner = owner } end
function frameMethods:SetText(text) self.text = text end
function frameMethods:GetText() return self.text end
function frameMethods:SetWidth(w) self.width = w end
function frameMethods:GetWidth() return self.width or 93 end
function frameMethods:SetAlpha(alpha) self.alpha = alpha self.alphaSets = (self.alphaSets or 0) + 1 end
function frameMethods:SetPoint(point, relativeTo, relativePoint, x, y) self.points = self.points or {} self.points[point] = { relativeTo, relativePoint, x, y } end
function frameMethods:RegisterEvent(event) self.events[event] = true end
function frameMethods:UnregisterEvent(event) self.events[event] = nil end
-- WowDropdownFilterBehaviorMixin and DropdownButtonMixin, as far as the addon calls them
function frameMethods:SetupMenu(fn) self.menuGenerator = fn end
function frameMethods:SetDefaultCallback(fn) self.defaultCallback = fn end
function frameMethods:SetIsDefaultCallback(fn) self.isDefaultCallback = fn end
function frameMethods:ValidateResetState() self.resetShown = not self.isDefaultCallback() end

-- HelpTipTemplateMixin, as far as the addon calls it: Init takes the info, Acknowledge runs its callback and closes
local helpTips = {}
local function helpTip(frame)
    function frame:Init(parent, info, relativeRegion) self.info, self.anchorParent, self.relativeRegion = info, parent, relativeRegion end
    function frame:Acknowledge()
        local info = self.info
        self.info, self.shown = nil, false
        if info.onAcknowledgeCallback then info.onAcknowledgeCallback(info.callbackArg) end
    end
    -- What the template's OnHide does when its button hides: close without acknowledging
    function frame:CloseOnHide() self.info, self.shown = nil, false end
    helpTips[#helpTips + 1] = frame
end

function CreateFrame(kind, name, parent, template)
    local frame = setmetatable({ scripts = {}, events = {}, shown = true, owner = parent, kind = kind, template = template }, frameMethods)
    if name then _G[name] = frame end
    if template == "HelpTipTemplate" then frame.shown = false helpTip(frame) end
    return frame
end

UIParent = CreateFrame("Frame")

-- A menu description stand-in that records what the generator builds
local function description(text)
    local d = { text = text, items = {} }
    local function add(entry) table.insert(d.items, entry) return entry end
    function d:CreateRadio(label, isSelected, setSelected, data) return add({ kind = "radio", text = label, isSelected = isSelected, setSelected = setSelected, data = data }) end
    function d:CreateCheckbox(label, isSelected, setSelected, data) return add({ kind = "checkbox", text = label, isSelected = isSelected, setSelected = setSelected, data = data }) end
    function d:CreateDivider() return add({ kind = "divider" }) end
    function d:CreateButton(label) local sub = description(label) sub.kind = "submenu" return add(sub) end
    return d
end
local function openMenu(dropdown)
    local root = description()
    dropdown.menuGenerator(dropdown, root)
    return root
end

-- ===== WoW API =====
unpack = unpack or table.unpack
strmatch = string.match
function wipe(t) for k in pairs(t) do t[k] = nil end return t end

local nextFrame = {}
C_Timer = { After = function(_, fn) nextFrame[#nextFrame + 1] = fn end }
local function runNextFrame()
    local queued = nextFrame
    nextFrame = {}
    for _, fn in ipairs(queued) do fn() end
end

local function color(name)
    return { WrapTextInColorCode = function(_, text) return "<" .. name .. ">" .. text .. "</>" end, GetRGB = function() return 1, 1, 1 end }
end
HIGHLIGHT_FONT_COLOR, GREEN_FONT_COLOR, RED_FONT_COLOR = color("white"), color("green"), color("red")
GRAY_FONT_COLOR, YELLOW_FONT_COLOR, NORMAL_FONT_COLOR, WARNING_FONT_COLOR = color("gray"), color("yellow"), color("gold"), color("warn")

FILTER = "Filter"
SPELL_STAT1_NAME, SPELL_STAT2_NAME, SPELL_STAT3_NAME, SPELL_STAT4_NAME, SPELL_STAT5_NAME = "Strength", "Agility", "Stamina", "Intellect", "Spirit"
STAT_CATEGORY_ATTRIBUTES, STAT_CATEGORY_ATTACK, STAT_CATEGORY_SPELL, STAT_CATEGORY_DEFENSE = "Attributes", "Attack", "Spell", "Defense"
ITEM_SPELL_TRIGGER_ONEQUIP, ITEM_SPELL_TRIGGER_ONUSE, ITEM_SPELL_TRIGGER_ONPROC = "Equip:", "Use:", "Chance on hit:"
ITEM_SET_BONUS, ITEM_SET_BONUS_GRAY = "Set: %s", "(%d) Set: %s"
ITEM_MOD_STAMINA, ITEM_MOD_STAMINA_SHORT = "%c%s Stamina", "Stamina"
ITEM_MOD_SPELL_POWER, ITEM_MOD_SPELL_POWER_SHORT = "Increases spell power by %s.", "Spell Power"
ITEM_MOD_SPELL_PENETRATION_SHORT = "Spell Piercing"
ITEM_MOD_CRIT_RATING_SHORT = "Critical Strike"
ITEM_MOD_CRIT_TAKEN_RATING = "Improves your critical strike avoidance rating by %s."
ITEM_MOD_FIRE_DAMAGE_DONE_SHORT = "Fire Damage"
ITEM_MOD_DODGE_RATING_SHORT = "Dodge"

Enum = { ItemClass = { Weapon = 2, Armor = 4, Consumable = 0 } }
HelpTip = { width = 226, Point = { TopEdgeCenter = 2, BottomEdgeCenter = 5 }, ButtonStyle = { Close = 2 } }
DropdownButtonMixin = { Event = { OnMenuOpen = "OnMenuOpen" } }

-- Items by id: class and whether the client holds their data yet
local items = {
    [25] = { class = 4, cached = true, lines = { "Worn Vest", "+5 Strength" } },
    [26] = { class = 4, cached = true, lines = { "Robe", "Increases spell power by 12." } },
    [27] = { class = 0, cached = true, lines = { "Potion" } },
    [28] = { class = 4, cached = false, lines = { "Late Gloves", "+3 Strength" } },
}
local tooltipBuilds, loadRequests = 0, 0
C_Item = {
    GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, items[id] and items[id].class end,
    IsItemDataCachedByID = function(id) return items[id].cached end,
    RequestLoadItemDataByID = function() loadRequests = loadRequests + 1 end,
}
C_TooltipInfo = {
    GetItemKey = function(id)
        tooltipBuilds = tooltipBuilds + 1
        local lines = {}
        for _, text in ipairs(items[id].lines) do lines[#lines + 1] = { leftText = text } end
        return { lines = lines }
    end,
}

local addonLoaded = {}
EventUtil = { ContinueOnAddOnLoaded = function(name, fn) addonLoaded[name] = addonLoaded[name] or {} table.insert(addonLoaded[name], fn) end }

-- ===== Auctionator =====
Auctionator = {}

-- ===== Load in toc order =====
local ns = {}
local createFrame = CreateFrame
local eventFrames = {}
CreateFrame = function(kind, name, parent, template)
    local frame = createFrame(kind, name, parent, template)
    if kind == "Frame" and not parent then eventFrames[#eventFrames + 1] = frame end
    return frame
end
for line in io.lines("AuctionStatFilter.toc") do
    if line:match("%.lua$") and not line:match("^#") then
        assert(loadfile((line:gsub("\\", "/"))))("AuctionStatFilter", ns)
    end
end
CreateFrame = createFrame
check("files load in toc order", true)

local saved = Auctionator
Auctionator = nil
check("the Auctionator part loads without Auctionator", pcall(assert(loadfile("Modules/Auctionator.lua")), "AuctionStatFilter", {}))
Auctionator = saved

-- ===== Parser =====
local function parse(...) return ns.ItemStats.FullStatSet(table.concat({ ... }, "\n"):lower()) end
check("vanilla spell piercing parses", parse("equip: decreases the magical resistances of your spell targets by 10.").spellpenetration)
check("the client's long wording parses", parse("increases spell power by 12.").spellpower)
check("the client's short wording parses", parse("+7 stamina").stamina)
check("crit avoidance never reads as crit", not parse("improves your critical strike avoidance rating by 5.").crit)
check("Use effects carry no stats", not parse("use: increases strength by 50 for 20 sec.").strength)
check("lines without a number are skipped", next(parse("soulbound", "chest", "strength of the bear")) == nil)

-- ===== Blizzard's Auction House =====
local function row(itemID)
    local r = CreateFrame("Button")
    r.rowData = itemID and { itemKey = { itemID = itemID, itemLevel = 0, itemSuffix = 0 } }
    return r
end
local strong, robe, potion, late, empty = row(25), row(26), row(27), row(28), row(nil)
local browseRows = { strong, robe, potion, late, empty }

AuctionHouseFrame = CreateFrame("Frame")
AuctionHouseFrame.shown = false
AuctionHouseFrame.SearchBar = CreateFrame("Frame", nil, AuctionHouseFrame)
AuctionHouseFrame.SearchBar.FilterButton = CreateFrame("DropdownButton", nil, AuctionHouseFrame.SearchBar)
AuctionHouseFrame.BrowseResultsFrame = CreateFrame("Frame", nil, AuctionHouseFrame)
AuctionHouseFrame.BrowseResultsFrame.ItemList = { ScrollBox = { ForEachFrame = function(_, fn) for _, r in ipairs(browseRows) do fn(r) end end } }

local painters = {}
CreateFrame = function(kind, name, parent, template)
    local frame = createFrame(kind, name, parent, template)
    if parent == AuctionHouseFrame.BrowseResultsFrame then painters[#painters + 1] = frame end
    return frame
end
for _, fn in ipairs(addonLoaded.Blizzard_AuctionHouseUI or {}) do fn() end
CreateFrame = createFrame
local function paint() for _, painter in ipairs(painters) do painter.scripts.OnUpdate(painter) end end

check("one painter, on the browse results", #painters == 1, #painters)

-- Every dropdown the addon made, from its module's closure
local function upvalue(fn, name)
    local i = 1
    while true do
        local n, v = debug.getupvalue(fn, i)
        if not n then return nil end
        if n == name then return v end
        i = i + 1
    end
end
local dropdowns = upvalue(ns.Filter.CreateDropdown, "dropdowns")
local blizzardDropdown = dropdowns[1]
check("Stats sits left of Blizzard's Filter button", blizzardDropdown.points.RIGHT[1] == AuctionHouseFrame.SearchBar.FilterButton and blizzardDropdown.points.RIGHT[2] == "LEFT" and blizzardDropdown.points.RIGHT[3] % 4 == 0)
check("Stats is Blizzard's filter button, on the grid", blizzardDropdown.template == "WowStyle1FilterDropdownTemplate" and blizzardDropdown.text == "Stats" and blizzardDropdown.width % 4 == 0, blizzardDropdown.width)
local badge = blizzardDropdown.Badge
check("the badge is Blizzard's counter on the top left corner", badge.texture.atlas == "tokens-counterBG" and badge.points.CENTER[1] == blizzardDropdown and badge.points.CENTER[2] == "TOPLEFT" and badge.width % 4 == 0)
check("no stat, no badge", badge.shown == false)
check("the number centres in the circle's own box", badge.Count.allPoints and badge.texture.allPoints and badge.Count.justifyH == "CENTER" and badge.Count.justifyV == "MIDDLE")
check("circle and number round to whole pixels", badge.rounded and badge.texture.rounded and badge.Count.rounded)

local menu = openMenu(blizzardDropdown)
check("menu starts with Match All and Match Any", menu.items[1].text == "Match All" and menu.items[2].text == "Match Any" and menu.items[3].kind == "divider")
check("one submenu per stat category", menu.items[4].text == "Attributes" and menu.items[7].text == "Defense" and #menu.items == 7)
check("a stat without a client name is left out", #menu.items[4].items == 5 and #menu.items[7].items == 1, #menu.items[7].items)

paint()
check("no filter, no fading", strong.alpha == 1 and robe.alpha == 1 and late.alpha == 1)

local strength = menu.items[4].items[1]
strength.setSelected(strength.data)
check("ticking a stat saves it", AuctionStatFilterDB.stats.strength == true and strength.isSelected(strength.data))
check("the reset button shows with a stat chosen", blizzardDropdown.resetShown == true)
check("the badge shows one stat", badge.shown and tostring(badge.Count.text) == "1", badge.Count.text)
paint()
check("an item without the stat fades", robe.alpha < 1)
check("an item with the stat stays", strong.alpha == 1)
check("consumables always stay", potion.alpha == 1)
check("an empty row stays", empty.alpha == 1)
check("an uncached item waits instead of fading", late.alphaSets == 1 and late.alpha == 1)
paint()
paint()
check("its data is asked for once", loadRequests == 1, loadRequests)
check("unchanged rows are not painted again", strong.alphaSets == 2 and robe.alphaSets == 2, strong.alphaSets)
items[28].cached = true
paint()
check("the item is checked once its data arrives", late.alpha == 1 and late.alphaSets == 2)

-- Spell power also covers a school
local fire = menu.items[6].items[3]
check("Fire Damage sits in Spell", fire.text == "Fire Damage", fire.text)
strength.setSelected(strength.data)
fire.setSelected(fire.data)
paint()
check("spell power meets a school filter", robe.alpha == 1 and strong.alpha < 1)
check("the badge counts every stat", tostring(badge.Count.text) == "1")

menu.items[2].setSelected("OR")
strength.setSelected(strength.data)
paint()
check("Match Any passes either stat", AuctionStatFilterDB.logic == "OR" and robe.alpha == 1 and strong.alpha == 1)
check("two stats, badge 2", tostring(badge.Count.text) == "2", badge.Count.text)
menu.items[1].setSelected("AND")
paint()
check("Match All needs both", robe.alpha < 1 and strong.alpha < 1)

-- ===== First-run tip =====
check("no tip while the Auction House is closed", #helpTips == 0, #helpTips)
AuctionHouseFrame.shown = true
blizzardDropdown.scripts.OnShow(blizzardDropdown)
local tip = helpTips[1]
check("the tip shows with the Stats button", tip and tip.shown and tip.owner == blizzardDropdown and tip.relativeRegion == blizzardDropdown)
check("it is Blizzard's help tip at its own width", tip.template == "HelpTipTemplate" and tip.width == HelpTip.width)
check("it points up at Stats, with a close button", tip.info.targetPoint == HelpTip.Point.BottomEdgeCenter and tip.info.buttonStyle == HelpTip.ButtonStyle.Close)
check("its text is a plain sentence", tip.info.text:match("^%u.*%.$") ~= nil and not tip.info.text:find("[\128-\255]"), tip.info.text)
tip:CloseOnHide()
blizzardDropdown.scripts.OnShow(blizzardDropdown)
check("closing the Auction House brings it back next visit", tip.shown and tip.info and #helpTips == 1)
local menuOpen = blizzardDropdown.callbacks.OnMenuOpen
check("the menu callback has an owner of its own", menuOpen and type(menuOpen.owner) == "table")
menuOpen.fn()
check("opening Stats closes it for good", not tip.shown and AuctionStatFilterDB.tipSeen == true)
blizzardDropdown.scripts.OnShow(blizzardDropdown)
check("a seen tip never returns", not tip.shown and #helpTips == 1)

-- ===== Auctionator's Shopping tab =====
local shoppingRows = {}
AuctionatorShoppingFrame = CreateFrame("Frame")
AuctionatorShoppingFrame.ExportCSV = CreateFrame("Button")
AuctionatorShoppingFrame.ResultsListing = CreateFrame("Frame", nil, AuctionatorShoppingFrame)
AuctionatorShoppingFrame.ResultsListing.ScrollArea = { ScrollBox = { ForEachFrame = function(_, fn) for _, r in ipairs(shoppingRows) do fn(r) end end } }

local events = eventFrames[#eventFrames]
check("setup waits for the Auction House", events.events.AUCTION_HOUSE_SHOW)
-- A fresh account opens Auctionator first: its Stats button is made while its tab already shows
AuctionStatFilterDB.tipSeen = nil
CreateFrame = function(kind, name, parent, template)
    local frame = createFrame(kind, name, parent, template)
    if parent == AuctionatorShoppingFrame.ResultsListing then painters[#painters + 1] = frame end
    return frame
end
events.scripts.OnEvent(events, "AUCTION_HOUSE_SHOW")
CreateFrame = createFrame
check("setup done on the first visit", not events.events.AUCTION_HOUSE_SHOW)
check("one more painter, on the Shopping results", #painters == 2, #painters)
local shoppingDropdown = dropdowns[2]
check("Stats sits left of Export Results", shoppingDropdown and shoppingDropdown.points.RIGHT[1] == AuctionatorShoppingFrame.ExportCSV and shoppingDropdown.owner == AuctionatorShoppingFrame.ExportCSV)
check("its badge starts with the saved stats", shoppingDropdown.Badge.shown and tostring(shoppingDropdown.Badge.Count.text) == "2")
local shoppingTip = helpTips[2]
check("the tip shows at once on a button made while visible", shoppingTip and shoppingTip.shown and shoppingTip.owner == shoppingDropdown)
check("it points down at Stats from the results", shoppingTip.info.targetPoint == HelpTip.Point.TopEdgeCenter)
shoppingTip:Acknowledge()
check("its close button marks it seen", AuctionStatFilterDB.tipSeen == true and not shoppingTip.shown)
shoppingDropdown.callbacks.OnMenuOpen.fn()
check("opening Stats after that changes nothing", AuctionStatFilterDB.tipSeen == true)

-- Both stats chosen, Match All: Spell Power covers Fire Damage, so only gear with Strength and Spell Power passes
items[29] = { class = 4, cached = false, lines = { "Slow Belt", "+4 Strength", "Increases spell power by 3." } }
tooltipBuilds = 0
local vest, cloth, drink, belt = row(25), row(26), row(27), row(29)
shoppingRows = { vest, cloth, drink, belt }
paint()
check("Shopping rows without the stats fade", vest.alpha < 1 and cloth.alpha < 1)
check("Shopping consumables stay", drink.alpha == 1)
check("an uncached Shopping item waits instead of fading", belt.alphaSets == nil)
items[29].cached = true
paint()
check("it is checked once its data arrives", belt.alpha == 1)
check("both lists share each key's stats, read once", tooltipBuilds == 1, tooltipBuilds)

openMenu(shoppingDropdown).items[2].setSelected("OR")
paint()
check("a change refades without a new search", vest.alpha == 1 and cloth.alpha == 1 and belt.alpha == 1)
check("every Shopping row stays listed", #shoppingRows == 4)

shoppingDropdown.defaultCallback()
check("reset clears every stat", next(AuctionStatFilterDB.stats) == nil and not blizzardDropdown.resetShown and not shoppingDropdown.resetShown)
check("reset hides both badges", not badge.shown and not shoppingDropdown.Badge.shown)
paint()
check("reset unfades both lists", robe.alpha == 1 and strong.alpha == 1 and vest.alpha == 1 and cloth.alpha == 1)

runNextFrame()
print(failures == 0 and "All checks passed." or (failures .. " checks failed."))
os.exit(failures == 0 and 0 or 1)
