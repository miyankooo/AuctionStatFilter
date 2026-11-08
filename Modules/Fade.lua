local _, ns = ...

-- Fades the rows of an auction list whose item misses the chosen stats, the same way in Blizzard's Auction House and
-- in Auctionator. Rows are faded, not removed, so the player sees that a filter is on, and the lists stay as their
-- owners built them: Blizzard's rows later feed the purchase calls, so the addon only reads them, from a frame of its
-- own in OnUpdate, and never runs inside Blizzard's list updates.
ns.Fade = {}

local FADED_ALPHA = 0.35

-- The result and filter version each row was last painted for, kept here instead of on the rows
local paintedData = setmetatable({}, { __mode = "k" })
local paintedVersion = setmetatable({}, { __mode = "k" })

-- Rows keep the same result table until their list hands them another, so a row is only worked out again on a change
local function paintRow(row)
    local rowData = row.rowData
    if paintedData[row] == rowData and paintedVersion[row] == ns.Filter.version then return end

    local matches = rowData == nil or ns.Filter.Matches(rowData.itemKey)
    -- The item is still loading: the row shows unfaded, so no fade from an earlier result or filter stays on it, and
    -- is tried again next frame
    if matches == nil then
        if row:GetAlpha() ~= 1 then row:SetAlpha(1) end
        return
    end

    -- Blizzard sets the alpha of a browse row's parts and Auctionator none on a Shopping row, never the row's own,
    -- so this is the addon's alone
    row:SetAlpha(matches and 1 or FADED_ALPHA)
    paintedData[row], paintedVersion[row] = rowData, ns.Filter.version
end

-- Fades the rows of a results ScrollBox whose rows keep their result, with its itemKey, on row.rowData. The painter
-- is a child of parent, so it only runs while the results show
function ns.Fade.Attach(parent, scrollBox)
    local painter = CreateFrame("Frame", nil, parent)
    painter:SetScript("OnUpdate", function()
        scrollBox:ForEachFrame(paintRow)
    end)
end
