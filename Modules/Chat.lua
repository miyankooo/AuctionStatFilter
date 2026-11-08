local addonName, ns = ...

-- Every line the addon prints: "[Auction Stat Filter]: Sentence." with the bracketed title in the gold of Blizzard's
-- own chat links (ItemRef.lua) and the message in the chat frame's colour. The welcome line prints once on the
-- account's first login, the rest only when asked for with /asf. The addon has no window or settings page, so the
-- welcome line carries no link and names where to start instead.
ns.title = C_AddOns.GetAddOnMetadata(addonName, "Title")

function ns.Print(message)
    print(NORMAL_FONT_COLOR:WrapTextInColorCode("[" .. ns.title .. "]") .. ": " .. message)
end

-- Where to start, the second sentence of the welcome line and the first of the help line
local START = "Open the Auction House and click Stats, left of Filter, to pick them."

local function PrintWelcome()
    ns.Print("Fades out Auction House gear without the item stats you want. " .. START
        .. " Type /asf help for the commands.")
end

-- At login, after the client's own load lines
EventUtil.ContinueOnPlayerLogin(function()
    if ns.firstRun then PrintWelcome() end
end)

-- /asf intro: the welcome line now, and the Stats tip again, at once while a Stats button shows, otherwise the next
-- time one does
local function ReplayIntro()
    ns.db.tipSeen = nil
    ns.Filter.ShowTips()
    PrintWelcome()
end

-- One long command and one short alias. With no window or settings page to open, the bare command prints the help
-- line; intro is the other shared word, and any other word prints the hint.
SLASH_AUCTIONSTATFILTER1, SLASH_AUCTIONSTATFILTER2 = "/auctionstatfilter", "/asf"
SlashCmdList.AUCTIONSTATFILTER = function(message)
    local command = strtrim(message or ""):lower()
    if command == "" or command == "help" or command == "?" then
        ns.Print(START .. " Type /asf intro to see the welcome line and the tip again, or /asf help for this list.")
    elseif command == "intro" then
        ReplayIntro()
    else
        ns.Print("Unknown command. Type /asf help for the list.")
    end
end
