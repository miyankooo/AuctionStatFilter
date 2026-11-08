local addonName, ns = ...

-- Every line the addon prints: "[Auction Stat Filter]: Sentence." with the bracketed title in the gold of Blizzard's
-- own chat links (ItemRef.lua) and the message in the chat frame's colour. The only line is the welcome line, once on
-- the account's first login. The addon has no window or settings page, so the line carries no link and names where to
-- start instead.
ns.title = C_AddOns.GetAddOnMetadata(addonName, "Title")

function ns.Print(message)
    print(NORMAL_FONT_COLOR:WrapTextInColorCode("[" .. ns.title .. "]") .. ": " .. message)
end

local function PrintWelcome()
    ns.Print("Fades out Auction House gear without the item stats you want. Open the Auction House and click Stats, "
        .. "left of Filter, to pick them.")
end

-- At login, after the client's own load lines
EventUtil.ContinueOnPlayerLogin(function()
    if ns.firstRun then PrintWelcome() end
end)
