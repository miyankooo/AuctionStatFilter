-- Offline check of the chat lines: the welcome line on the account's first login only, and /asf with help, intro and
-- an unknown word. Loads Chat.lua and Filter.lua on a fresh client per login, against stubs of the WoW API.
-- Run from the addon folder: lua Tests/Chat.lua

local failures = 0
local function check(label, ok, detail)
    if not ok then failures = failures + 1 end
    print((ok and "ok   " or "FAIL ") .. label .. (ok and "" or ("  (" .. tostring(detail) .. ")")))
end

-- ===== WoW API =====
C_AddOns = { GetAddOnMetadata = function(_, field) return field == "Title" and "Auction Stat Filter" or nil end }
NORMAL_FONT_COLOR = { WrapTextInColorCode = function(_, text) return "<gold>" .. text .. "</gold>" end }
function strtrim(text) return (text:gsub("^%s+", ""):gsub("%s+$", "")) end
SlashCmdList = {}

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
local START = "Open the Auction House and click Stats, left of Filter, to pick them."
local WELCOME = "<gold>[Auction Stat Filter]</gold>: Fades out Auction House gear without the item stats you want. "
    .. START .. " Type /asf help for the commands."

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

-- ===== Slash commands =====
local function slash(message) return capture(function() SlashCmdList.AUCTIONSTATFILTER(message) end) end
local HELP = "<gold>[Auction Stat Filter]</gold>: " .. START
    .. " Type /asf intro to see the welcome line and the tip again, or /asf help for this list."

check("/auctionstatfilter and /asf", SLASH_AUCTIONSTATFILTER1 == "/auctionstatfilter" and SLASH_AUCTIONSTATFILTER2 == "/asf")
for _, word in ipairs({ "", "help", "?", "  Help " }) do
    local lines = slash(word)
    check("/asf " .. word .. " prints the help line", #lines == 1 and lines[1] == HELP, lines[1])
end

AuctionStatFilterDB.tipSeen = true
local lines = slash("intro")
check("/asf intro prints the welcome line now", #lines == 1 and lines[1] == WELCOME, lines[1])
check("and shows the tip again", AuctionStatFilterDB.tipSeen == nil)

AuctionStatFilterDB.tipSeen = true
lines = slash("minimap")
check("an unknown word prints the hint", #lines == 1
    and lines[1] == "<gold>[Auction Stat Filter]</gold>: Unknown command. Type /asf help for the list.", lines[1])
check("and changes nothing", AuctionStatFilterDB.tipSeen == true)

print(failures == 0 and "All checks passed." or (failures .. " checks failed."))
os.exit(failures == 0 and 0 or 1)
