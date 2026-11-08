local _, ns = ...

-- Points new players at the Stats button with Blizzard's help tip, the yellow glowing callout the Auction House itself
-- uses for its undercut tip (Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSellFrame.lua:507), with the close
-- button. It comes back on every visit until the player closes it or opens the Stats menu, then never again on the
-- account.
ns.Tip = {}

local TEXT = "Pick item stats here to fade out gear without them."

local function seen()
    return ns.Filter.Saved().tipSeen == true
end

local function markSeen()
    ns.Filter.Saved().tipSeen = true
end

-- One owner for the menu callbacks, so the registry takes it instead of counting up an id of Blizzard's own
local callbackOwner = {}

-- Gives a Stats button the tip, pointing from targetPoint, a HelpTip.Point
function ns.Tip.Attach(dropdown, targetPoint)
    -- A tip of the button's own from Blizzard's template, made on first need. HelpTip:Show would take a frame from
    -- Blizzard's shared pool, and writing to that pool from addon code would taint the help tips Blizzard shows later
    local tip
    local info = {
        text = TEXT,
        buttonStyle = HelpTip.ButtonStyle.Close,
        targetPoint = targetPoint,
        onAcknowledgeCallback = markSeen,
    }

    local function show()
        if seen() then return end
        if not tip then
            tip = CreateFrame("Frame", nil, dropdown, "HelpTipTemplate")
            -- The width HelpTip:Show gives each tip before it lays out
            tip.width = HelpTip.width
            tip:SetWidth(tip.width)
        end
        tip:Init(dropdown, info, dropdown)
        tip:Show()
    end

    -- The tip is a child of the button, so it hides with it; the template closes it on hide without marking it seen
    dropdown:HookScript("OnShow", show)
    dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuOpen, function()
        if tip and tip.info then
            tip:Acknowledge()
        else
            markSeen()
        end
    end, callbackOwner)

    -- Auctionator's button can be made while its tab already shows, so it gets no OnShow of its own
    if dropdown:IsVisible() then show() end
end
