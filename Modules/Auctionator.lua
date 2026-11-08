local _, ns = ...

-- Auctionator's Shopping tab, when Auctionator is installed: the Stats button beside Export Results, and result rows
-- that miss the chosen stats faded, as in Blizzard's list. Auctionator's own results stay as it built them.
if not Auctionator then return end

-- Auctionator creates its frames on or shortly after the first Auction House visit, so setup retries this often
local RETRY_SECONDS, RETRY_LIMIT = 0.5, 20

-- Between related controls
local GAP = 8

local dropdown, fading

-- True once both pieces are in place
local function ensure()
    local shopping = AuctionatorShoppingFrame
    if not shopping then return false end

    -- Parented to Export Results, so it hides with it whenever a buy screen covers the results
    if not dropdown and shopping.ExportCSV then
        dropdown = ns.Filter.CreateDropdown(shopping.ExportCSV)
        dropdown:SetPoint("RIGHT", shopping.ExportCSV, "LEFT", -GAP, 0)
        -- The button sits at the bottom of the window, so the tip points down at it from the results
        ns.Tip.Attach(dropdown, HelpTip.Point.TopEdgeCenter)
    end
    local listing = shopping.ResultsListing
    if not fading and listing and listing.ScrollArea and listing.ScrollArea.ScrollBox then
        ns.Fade.Attach(listing, listing.ScrollArea.ScrollBox)
        fading = true
    end
    return dropdown ~= nil and fading == true
end

local function ensureLater(attempt)
    if ensure() or attempt >= RETRY_LIMIT then return end
    C_Timer.After(RETRY_SECONDS, function() ensureLater(attempt + 1) end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:SetScript("OnEvent", function(self)
    if ensure() then
        self:UnregisterEvent("AUCTION_HOUSE_SHOW")
    else
        ensureLater(1)
    end
end)
