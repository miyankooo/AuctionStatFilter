local _, ns = ...

local UI = LibStub("LibNativeUI-1.0")

-- Blizzard's own Auction House: the Stats button beside its Filter button, and browse rows that miss the chosen stats
-- faded
EventUtil.ContinueOnAddOnLoaded("Blizzard_AuctionHouseUI", function()
    local searchBar = AuctionHouseFrame.SearchBar
    local dropdown = ns.Filter.CreateDropdown(searchBar)
    dropdown:SetPoint("RIGHT", searchBar.FilterButton, "LEFT", -UI.Space.gap, 0)

    local browse = AuctionHouseFrame.BrowseResultsFrame
    ns.Fade.Attach(browse, browse.ItemList.ScrollBox)
end)
