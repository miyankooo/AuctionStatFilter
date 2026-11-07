local _, ns = ...

-- Auctionator's Shopping tab, when Auctionator is installed: the Stats button beside Export Results, and results that
-- miss the chosen stats left out of the list. Auctionator's own buy code runs as addon code anyway, so its list can be
-- filtered, unlike Blizzard's.
if not Auctionator then return end

local UI = LibStub("LibNativeUI-1.0")

-- Auctionator creates its frames on or shortly after the first Auction House visit, so setup retries this often
local RETRY_SECONDS, RETRY_LIMIT = 0.5, 20

local dropdown, provider, originalAppend

-- Every entry Auctionator appended for the current search, so a filter change rebuilds the rows without a new search
local allEntries = {}

-- Bumps on every search start and refilter; item-load callbacks from before compare against it and drop out
local generation = 0

-- Append an entry once its item data arrives, if it passes by then; the provider dedups by item, so a second append is safe
local function appendOnLoad(entry)
    local startedGeneration = generation
    Item:CreateFromItemID(entry.itemKey.itemID):ContinueOnItemLoad(function()
        if generation ~= startedGeneration or not ns.Filter.Matches(entry.itemKey) then return end
        originalAppend(provider, { entry }, provider.searchCompleted)
    end)
end

local function filterEntries(entries)
    if not ns.Filter.IsActive() then return entries end

    local kept = {}
    for _, entry in ipairs(entries) do
        local matches = ns.Filter.Matches(entry.itemKey)
        if matches then
            kept[#kept + 1] = entry
        elseif matches == nil then
            appendOnLoad(entry)
        end
    end
    return kept
end

-- Rebuild the visible rows from the recorded entries under the current filter; Auctionator's search stays untouched
local function refilter()
    if not originalAppend then return end
    generation = generation + 1
    local searchWasComplete = provider.searchCompleted
    provider:Reset()
    originalAppend(provider, filterEntries(allEntries), searchWasComplete)
end
ns.Filter.OnChange(refilter)

-- Instance wrap, not a mixin hook: record the unfiltered entries and forward only the ones that pass
local function wrapProvider(shoppingProvider)
    provider, originalAppend = shoppingProvider, shoppingProvider.AppendEntries
    provider.AppendEntries = function(self, entries, isLastSet)
        for _, entry in ipairs(entries) do
            allEntries[#allEntries + 1] = entry
        end
        return originalAppend(self, filterEntries(entries), isLastSet)
    end
end

-- True once both pieces are in place
local function ensure()
    local shopping = AuctionatorShoppingFrame
    if not shopping then return false end

    -- Parented to Export Results, so it hides with it whenever a buy screen covers the results
    if not dropdown and shopping.ExportCSV then
        dropdown = ns.Filter.CreateDropdown(shopping.ExportCSV)
        dropdown:SetPoint("RIGHT", shopping.ExportCSV, "LEFT", -UI.Space.gap, 0)
    end
    if not originalAppend and shopping.DataProvider and type(shopping.DataProvider.AppendEntries) == "function" then
        wrapProvider(shopping.DataProvider)
    end
    return dropdown ~= nil and originalAppend ~= nil
end

local function ensureLater(attempt)
    if ensure() or attempt >= RETRY_LIMIT then return end
    C_Timer.After(RETRY_SECONDS, function() ensureLater(attempt + 1) end)
end

Auctionator.EventBus:Register({
    ReceiveEvent = function()
        generation = generation + 1
        allEntries = {}
    end,
}, { Auctionator.Shopping.Tab.Events.SearchStart })

local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:SetScript("OnEvent", function(self)
    if ensure() then
        self:UnregisterEvent("AUCTION_HOUSE_SHOW")
    else
        ensureLater(1)
    end
end)
