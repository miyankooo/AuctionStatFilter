local _, ns = ...

local UI = LibStub("LibNativeUI-1.0")

-- Blizzard's own Auction House: the Stats button beside its Filter button, and browse rows that miss the chosen stats
-- dimmed. Removing rows would mean changing Blizzard's result list, whose rows later feed the purchase calls, so the
-- addon only reads that list, from a frame of its own in OnUpdate, and never runs inside Blizzard's list updates.
local DIM_ALPHA = 0.35

-- The result and filter version each row was last painted for, kept here instead of on Blizzard's rows
local paintedData = setmetatable({}, { __mode = "k" })
local paintedVersion = setmetatable({}, { __mode = "k" })

-- Rows keep the same result table until Blizzard hands them another, so a row is only worked out again on a change
local function paintRow(row)
    local rowData = row.rowData
    if paintedData[row] == rowData and paintedVersion[row] == ns.Filter.version then return end

    local matches = rowData == nil or ns.Filter.Matches(rowData.itemKey)
    -- The item is still loading: the row stays as it is and is tried again next frame
    if matches == nil then return end

    -- Blizzard sets the alpha of a row's parts, never of the row itself, so this is the addon's alone
    row:SetAlpha(matches and 1 or DIM_ALPHA)
    paintedData[row], paintedVersion[row] = rowData, ns.Filter.version
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_AuctionHouseUI", function()
    local searchBar = AuctionHouseFrame.SearchBar
    local dropdown = ns.Filter.CreateDropdown(searchBar)
    dropdown:SetPoint("RIGHT", searchBar.FilterButton, "LEFT", -UI.Space.gap, 0)

    -- A child of the browse results, so it only runs while they show
    local browse = AuctionHouseFrame.BrowseResultsFrame
    local painter = CreateFrame("Frame", nil, browse)
    painter:SetScript("OnUpdate", function()
        browse.ItemList.ScrollBox:ForEachFrame(paintRow)
    end)
end)
