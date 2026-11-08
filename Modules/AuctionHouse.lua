local _, ns = ...

-- Blizzard's own Auction House: the Stats button beside its Filter button, and browse rows that miss the chosen stats
-- faded
EventUtil.ContinueOnAddOnLoaded("Blizzard_AuctionHouseUI", function()
    local searchBar = AuctionHouseFrame.SearchBar
    -- The results lie below the search bar, so the tip points up from there
    ns.Filter.CreateDropdown(searchBar, searchBar.FilterButton, HelpTip.Point.BottomEdgeCenter)

    local browse = AuctionHouseFrame.BrowseResultsFrame
    ns.Fade.Attach(browse, browse.ItemList.ScrollBox)
end)
