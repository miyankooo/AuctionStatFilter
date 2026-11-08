-- Offline check of the chat lines: the welcome line on the account's first login only. Loads Chat.lua and Filter.lua
-- on a fresh client per login, against stubs of the WoW API.
-- Run from the addon folder: lua Tests/Chat.lua

local failures = 0
local function check(label, ok, detail)
    if not ok then failures = failures + 1 end
    print((ok and "ok   " or "FAIL ") .. label .. (ok and "" or ("  (" .. tostring(detail) .. ")")))
end

-- ===== WoW API =====
C_AddOns = { GetAddOnMetadata = function(_, field) return field == "Title" and "Auction Stat Filter" or nil end }
NORMAL_FONT_COLOR = { WrapTextInColorCode = function(_, text) return "<gold>" .. text .. "</gold>" end }

local onLoaded, onLogin
EventUtil = {
    ContinueOnAddOnLoaded = function(name, fn) if name == "AuctionStatFilter" then onLoaded = fn end end,
    ContinueOnPlayerLogin = function(fn) onLogin = fn end,
}

-- The chat lines printed while fn runs
local function capture(fn)
    local lines, realPrint = {}, print
    print = function(line) lines[#lines + 1] = line end
    fn()
    print = realPrint
    return lines
end

-- Loads the addon on a fresh client with the given saved table, as the client logs in: the files, ADDON_LOADED, then
-- PLAYER_LOGIN. Returns the lines each part printed and the addon table
local function login(saved)
    AuctionStatFilterDB = saved
    local ns = {}
    local loadLines = capture(function()
        for _, file in ipairs({ "Modules/Chat.lua", "Modules/Filter.lua" }) do
            assert(loadfile(file))("AuctionStatFilter", ns)
        end
        onLoaded()
    end)
    return loadLines, capture(onLogin), ns
end

-- ===== Welcome line =====
local WELCOME = "<gold>[Auction Stat Filter]</gold>: Fades out Auction House gear without the item stats you want. "
    .. "Open the Auction House and click Stats, left of Filter, to pick them."

local loadLines, loginLines, ns = login(nil)
check("the first load prints nothing", #loadLines == 0, #loadLines)
check("it marks the first run and makes the saved table", ns.firstRun == true and type(AuctionStatFilterDB) == "table")
check("the first login prints one line", #loginLines == 1, #loginLines)
check("it is the welcome line, the gold title and an uncoloured message", loginLines[1] == WELCOME, loginLines[1])
local message = loginLines[1]:match("^<gold>%[Auction Stat Filter%]</gold>: (.*)$")
check("it says where to start, with no link", message and message:find("click Stats", 1, true) and not message:find("|H", 1, true))
check("it reads as plain sentences", message and message:match("%.$") and not message:find("[!<>\128-\255]"), message)

loadLines, loginLines = login(AuctionStatFilterDB)
check("a later load prints nothing", #loadLines == 0, #loadLines)
check("a later login prints nothing", #loginLines == 0, #loginLines)

print(failures == 0 and "All checks passed." or (failures .. " checks failed."))
os.exit(failures == 0 and 0 or 1)
