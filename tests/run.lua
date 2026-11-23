-- Tests for Forever Data Bar. Run with tests/run (Lua 5.1, as in WoW).
local M = dofile("wowmock.lua")
local ROOT = ADDONDIR
local ADDON = "ForeverDataBar"

local function tocFiles()
    local files = {}
    for line in io.lines(ROOT .. "/" .. ADDON .. ".toc") do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
    end
    return files
end

local ns = {}
for _, f in ipairs(tocFiles()) do
    local chunk, err = loadfile(ROOT .. "/" .. f)
    if not chunk then error(f .. ": " .. tostring(err)) end
    local ok, e = pcall(chunk, ADDON, ns)
    if not ok then error(f .. ": " .. tostring(e)) end
end

local pass, fail = 0, 0
local function check(label, got, want)
    if got == want then
        pass = pass + 1
    else
        fail = fail + 1
        print(("  FAIL %-50s -> %s   (want: %s)"):format(label, tostring(got), tostring(want)))
    end
end
local function section(name) print(name) end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

local S, Settings, Data = ns.Settings.Get, ns.Settings, ns.Data

M.Fire("ADDON_LOADED", ADDON)
M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD", true)
M.RunTimers()
M.RunTimers()

section("Professions")
local function name(i) return Data.Professions()[i] and Data.Professions()[i].name end
check("slot 1: first primary", name(1), "Alchemy")
check("slot 2: second primary", name(2), "Mining")
check("slot 3: First Aid first", name(3), "First Aid")
check("slot 4: Cooking", name(4), "Cooking")
check("weapon skills never shown", (function()
    for i = 1, 4 do if name(i) == "Swords" then return true end end
    return false
end)(), false)
check("Fishing hidden by default", Settings.IsHidden("Fishing", "FISHING"), true)
Settings.SetHidden("First Aid", true)
check("hiding First Aid: Cooking moves up", name(3), "Cooking")
check("hidden per character", ForeverDataBarChar.hidden["First Aid"], true)
Settings.SetHidden("First Aid", false)
check("back to First Aid", name(3), "First Aid")
Settings.SetHidden("Fishing", false)
check("Fishing shown beside First Aid and Cooking", name(5), "Fishing")
Settings.SetHidden("Fishing", true)
check("Fishing hidden again", name(5), nil)
Settings.SetHidden("Riding", false)
check("Riding never on the bar", name(5), nil)
check("Riding not in the options", (function()
    for _, l in ipairs(Data.KnownSkills()) do if l.name == "Riding" then return true end end
    return false
end)(), false)
Settings.SetHidden("Riding", true)
-- A collapsed header is expanded for the scan and collapsed again.
M.state.skills[4][3] = false
Data.Refresh()
check("collapsed header read anyway", name(3), "First Aid")
check("and collapsed again", M.state.skills[4][3], false)
M.state.skills[4][3] = true
-- Forever lists every profession twice.
table.insert(M.state.skills, 3, { "Alchemy", false, false, 300, 0, 0, 375, true })
Data.Refresh()
check("the repeat takes no second slot", name(2), "Mining")
table.remove(M.state.skills, 3)
Data.Refresh()
check("spellbook entry found", select(2, Data.ProfessionInfo("Alchemy")), 10)

section("Reputation")
local function rep(i) return Data.RepData(i) and Data.RepData(i).name end
check("Alliance default 1", rep(1), "Darnassus")
check("Alliance default 4", rep(4), "Stormwind")
check("standing text", Data.RepData(3).standingText, "Honored")
check("value relative to the standing", Data.RepData(3).rank .. "/" .. Data.RepData(3).maxRank, "3000/12000")
check("the faction list header was collapsed again", M.state.factions[1][10], true)
M.state.faction = "Horde"
check("Horde gets the Horde cities", Settings.Reps()[1], 76)
M.state.faction = "Alliance"
Settings.SetRep(1, 609)
check("choosing a faction", rep(1), "Cenarion Circle")
check("the others stay", rep(2), "Gnomeregan")
check("chosen per character", ForeverDataBarChar.reps[1], 609)
Settings.SetRep(1, 69)

section("Settings")
check("defaults not stored", next(ForeverDataBarDB) == nil or ForeverDataBarDB.dataBarHeight == nil, true)
Settings.Set("dataBarHeight", 30)
check("account wide", ForeverDataBarDB.dataBarHeight, 30)
Settings.Set("dataBarHeight", Settings.DEFAULTS.dataBarHeight)
check("back to the default: not stored", ForeverDataBarDB.dataBarHeight, nil)

section("XP session")
check("duration", ns.Xp.Duration(3 * 3600 + 120), "3h 2m")
check("gain across a level-up", ns.Xp.Gain(900, 1000, 50), 150)
check("no rate without time", ns.Xp.PerHour(100, 0), nil)

section("Defaults (Stephan's own setup)")
check("reputation shown, column 4", tostring(S("dataBarReps")) .. S("dataBarRepsColumn"), "true4")
check("gold, durability, bags in column 2", S("dataBarGoldColumn") .. S("dataBarDuraColumn") .. S("dataBarBagsColumn"), "222")
check("XP per hour and to level right", S("dataBarXpPerHourPlace") .. S("dataBarXpToLevelPlace"), "RIGHTRIGHT")
check("own colours", S("dataBarProfColours"), true)
-- The rest runs on a fixed layout, so it does not change with the defaults.
for k, v in pairs({ dataBarReps = false, dataBarRepsColumn = 5, dataBarGoldColumn = 1, dataBarDuraColumn = 1,
    dataBarBagsColumn = 1, dataBarProfColours = false, dataBarXpPerHour = false, dataBarXpToLevel = false,
    dataBarXpPerHourPlace = "RIGHT" }) do
    Settings.DEFAULTS[k] = v
end
Settings.Changed(nil)

section("Data bar")
do
    local D, W = ns.DataBar, ns.Window
    local f = D.frame
    check("text: percent and next level", D.XpText(32, 750, 1000), "75% to level 33")
    check("text: rounds down", D.XpText(9, 999, 1000), "99% to level 10")
    check("text: no maximum, no text", D.XpText(9, 5, 0), "")
    M.state.xp, M.state.xpMax, M.state.rested = 750, 1000, 100
    M.Fire("PLAYER_XP_UPDATE")
    check("data bar shown", f:IsShown(), true)
    check("at the top by default", f:GetPoint("TOPLEFT") ~= nil, true)
    check("height", f:GetHeight(), Settings.DEFAULTS.dataBarHeight)
    check("background black by default", f.bg._texColor[1] .. f.bg._texColor[2] .. f.bg._texColor[3], "000")
    check("background at its opacity", near(f.bg._texColor[4], Settings.DEFAULTS.dataBarAlpha / 100), true)
    Settings.Set("dataBarBgColor", { 0.2, 0.1, 0 })
    check("background colour chosen", near(f.bg._texColor[1], 0.2), true)
    Settings.Set("dataBarBgColor", nil)
    check("XP text", f.xp.text:GetText(), "75% to level 44")
    check("XP fill: three quarters", near(f.xp.line.fill:GetWidth(), S("dataBarXpWidth") * 0.75), true)
    check("rested part after the fill", near(f.xp.line.rest:GetWidth(), S("dataBarXpWidth") * 0.1), true)
    -- The professions as the progress bars found them, right to left.
    local p = f.profs
    check("first profession", p[1].data and p[1].data.name, Data.Professions()[1].name)
    -- Five columns on a bar 1920 wide.
    f:SetWidth(1920)
    D.Layout()
    local function x(g) return select(4, g:GetPoint("LEFT")) end
    local gearRoom = D.CFG.ICON + D.CFG.PROF_GAP
    local rightEdge = 1920 - D.CFG.PAD - gearRoom
    check("professions in column 5: end left of the gear", x(f.profBox) + f.profBox.width, rightEdge)
    check("XP in column 1: at the left edge", x(f.xp), D.CFG.PAD)
    check("clock in column 3: centred", x(f.clock) + f.clock.width / 2, 960)
    check("first profession leftmost in its part", x(p[1]), 0)
    check("reputation off by default", f.repBox:IsShown(), false)
    Settings.Set("dataBarReps", true)
    check("reputation: shown", f.repBox:IsShown(), true)
    check("reputation: the slot's faction", f.reps[1].data and f.reps[1].data.name, Data.RepData(1) and Data.RepData(1).name)
    local standing = f.reps[1].data.standing
    check("reputation: standing icon by default", f.reps[1].icon._texture, D.CFG.MEDIA .. "RepLines" .. standing .. ".tga")
    check("reputation: no letter beside the icon", f.reps[1].value:GetText(), "")
    for _, id in ipairs(D.STANDING_ICON_ORDER) do
        check("standing icons " .. id .. ": label", ns.L["REP_ICONS_" .. id] ~= nil, true)
        if id ~= "LETTER" then
            Settings.Set("dataBarRepIcons", id)
            check("standing icons " .. id .. ": file", f.reps[1].icon._texture, D.CFG.MEDIA .. D.STANDING_ICONS[id] .. standing .. ".tga")
            for n = 1, 8 do
                local file = io.open(ROOT .. "/Media/" .. D.STANDING_ICONS[id] .. n .. ".tga", "rb")
                check("standing icons " .. id .. n .. ": shipped", file ~= nil, true)
                if file then file:close() end
            end
        end
    end
    Settings.Set("dataBarRepIcons", "LETTER")
    check("letter: no icon", f.reps[1].icon:IsShown(), false)
    check("letter: the short word", f.reps[1].value:GetText(), D.ShortStanding(f.reps[1].data))
    check("beyond Exalted: the word, no icon", D.StandingIcon(9), nil)
    Settings.Set("dataBarRepIcons", nil)
    local reps = Settings.Reps()
    local keep = reps[2]
    Settings.SetRep(2, 0)
    check("empty slot: the + shows", f.addRep:IsShown(), true)
    check("empty slot: + picks that slot", f.addRep.slot, 2)
    check("+ after the entries", x(f.addRep) > 0, true)
    for i = 1, 4 do Settings.SetRep(i, 0) end
    check("all empty: the part stays for the +", f.repBox:IsShown() and f.addRep.slot == 1, true)
    for i = 1, 4 do Settings.SetRep(i, reps[i]) end
    Settings.SetRep(2, keep)
    Settings.Set("dataBarRepsWidth", 150)
    check("reputation width: each line", f.reps[1].line.width, 150)
    check("professions keep theirs", p[1].line.width, 96)
    Settings.Set("dataBarProfsWidth", 1)
    check("profession width: at least 40", p[1].line.width, 40)
    Settings.Set("dataBarProfsWidth", nil)
    Settings.Set("dataBarRepsWidth", nil)
    check("standing short", D.ShortStanding({ standing = 5, standingText = "Friendly" }), "F")
    check("standing unknown: the full word", D.ShortStanding({ standing = 9, standingText = "Paragon" }), "Paragon")
    check("reputation outermost in column 5", x(f.repBox) + f.repBox.width, rightEdge)
    check("professions beside it, not over it", x(f.profBox) + f.profBox.width + D.CFG.PROF_GAP, x(f.repBox))
    for _, k in ipairs({ "dataBarGold", "dataBarDura", "dataBarBags" }) do Settings.Set(k, false) end
    Settings.Set("dataBarProfsColumn", 1)
    check("professions in column 1, after the XP", x(f.profBox), D.CFG.PAD + f.xp.width + D.CFG.PROF_GAP)
    Settings.Set("dataBarXpX", 30)
    check("X shifts only its part", x(f.xp) .. " " .. x(f.profBox),
        (D.CFG.PAD + 30) .. " " .. (D.CFG.PAD + f.xp.width + D.CFG.PROF_GAP))
    Settings.Set("dataBarClockColumn", 2)
    check("column 2: centred on 30 %", x(f.clock) + f.clock.width / 2, 1920 * 0.3)
    Settings.Set("dataBarClockColumn", 4)
    check("column 4: centred on 70 %", x(f.clock) + f.clock.width / 2, 1920 * 0.7)
    Settings.Set("dataBarGear", false)
    check("no gear: column 5 at the edge", x(f.repBox) + f.repBox.width, 1920 - D.CFG.PAD)
    Settings.Set("dataBarGear", nil)
    check("gear at the right edge", f.gear:IsShown() and select(4, f.gear:GetPoint("RIGHT")), -D.CFG.PAD)
    local toggled = W.IsShown()
    f.gear:GetScript("OnClick")(f.gear)
    check("gear opens the options", W.IsShown(), not toggled)
    W.Toggle()
    for _, k in ipairs({ "dataBarReps", "dataBarProfsColumn", "dataBarXpX", "dataBarClockColumn",
        "dataBarGold", "dataBarDura", "dataBarBags" }) do Settings.Set(k, nil) end
    Settings.Set("dataBarClock", false)
    check("clock off", f.clock:IsShown(), false)
    Settings.Set("dataBarClock", nil)
    -- XP per hour and time to the level: left or right of the XP.
    check("per hour text", D.XpInfoText("PerHour", 12345.6, 0), "12345 XP/h")
    check("to level text", D.XpInfoText("ToLevel", 1000, 500), "Level in 30m")
    check("no rate yet", D.XpInfoText("ToLevel", nil, 500), "Level in " .. ns.L.XPINFO_NONE)
    check("both off by default", f.xp.info.LEFT:IsShown() or f.xp.info.RIGHT:IsShown(), false)
    Settings.Set("dataBarXpPerHour", true)
    check("per hour right of the XP", f.xp.info.RIGHT:IsShown(), true)
    check("right: on the XP text's line", select(3, f.xp.info.RIGHT:GetPoint("TOPLEFT")), "TOPRIGHT")
    Settings.Set("dataBarXpWidth", 300)
    check("XP width: the line", f.xp.line.width .. " " .. f.xp.main:GetWidth(), "300 300")
    check("XP width: the part", f.xp.width, 300 + D.CFG.PROF_GAP + #f.xp.info.RIGHT:GetText() * 7)
    Settings.Set("dataBarXpWidth", 5)
    check("XP width: at least 80", S("dataBarXpWidth"), 80)
    Settings.Set("dataBarXpWidth", nil)
    check("right: the line keeps its width", f.xp.line.width, S("dataBarXpWidth"))
    check("right: the part grows", f.xp.width, S("dataBarXpWidth") + D.CFG.PROF_GAP + #f.xp.info.RIGHT:GetText() * 7)
    Settings.Set("dataBarXpToLevel", true)
    check("same side: side by side", f.xp.info.RIGHT:GetText():find("XP/h   Level in", 1, true) ~= nil, true)
    Settings.Set("dataBarXpToLevelPlace", "LEFT")
    check("left of the XP", f.xp.info.LEFT:GetText():find("Level in", 1, true), 1)
    local leftRoom = #f.xp.info.LEFT:GetText() * 7 + D.CFG.PROF_GAP
    check("left: the XP moves right", select(4, f.xp.main:GetPoint("LEFT")), leftRoom)
    check("left and right: the part holds both", f.xp.width,
        leftRoom + S("dataBarXpWidth") + D.CFG.PROF_GAP + #f.xp.info.RIGHT:GetText() * 7)
    for _, k in ipairs({ "dataBarXpPerHour", "dataBarXpToLevel", "dataBarXpPerHourPlace", "dataBarXpToLevelPlace" }) do
        Settings.Set(k, nil)
    end
    check("off again", f.xp.info.LEFT:IsShown() or f.xp.info.RIGHT:IsShown(), false)
    check("off again: XP back at the start", select(4, f.xp.main:GetPoint("LEFT")), 0)
    -- Gold, durability, bags.
    check("gold text", D.GoldText(1234567), "123g 45s")
    check("gold text: nothing", D.GoldText(0), "0g 0s")
    M.state.money = 1234567
    M.state.durability = { [1] = { 30, 60 }, [5] = { 10, 100 }, [16] = { 80, 100 } }
    M.state.bags = { [0] = { 16, 4, 0 }, [1] = { 10, 2, 0 }, [2] = { 20, 15, 1 } }
    M.Fire("PLAYER_MONEY")
    local gold, dura, bags = f.parts.GOLD, f.parts.DURA, f.parts.BAGS
    check("gold shown", gold:IsShown() and gold.text:GetText(), "123g 45s")
    check("worst durability", select(2, D.WorstDurability()), 5)
    check("durability: the worst item", dura.text:GetText(), "10%")
    check("durability low: red", dura.text._textColor[2] < 0.5, true)
    check("bags: special bags apart", table.concat({ D.BagSpace() }, ","), "6,26,15")
    check("bags: used of all", bags.text:GetText(), "20/26")
    D.Layout()
    check("order: gold left of bags (same order, listed first)", gold.x < bags.x, true)
    Settings.Set("dataBarGoldOrder", 15)
    D.Layout()
    check("order: a larger order moves gold right of bags", gold.x > bags.x, true)
    Settings.Set("dataBarGoldOrder", 10)
    D.Layout()
    local accent = ns.Themes.IconColor()
    check("bags: room enough, icon in the accent", bags.icon._vertex[1] .. "," .. bags.icon._vertex[2],
        accent[1] .. "," .. accent[2])
    M.state.bags[0][2] = 1
    M.Fire("BAG_UPDATE_DELAYED")
    check("bags: three free, orange icon", bags.icon._vertex[1] .. "," .. bags.icon._vertex[2], "1,0.5")
    check("bags: text colour unchanged", bags.text._textColor[1], D.TextColour("dataBarBags")[1])
    M.state.bags[0][2], M.state.bags[1][2] = 0, 0
    M.Fire("BAG_UPDATE_DELAYED")
    check("bags: full", bags.text:GetText(), "26/26")
    check("bags: full, red icon", bags.icon._vertex[2] < 0.3, true)
    M.state.bags[0][2], M.state.bags[1][2] = 4, 2
    M.Fire("BAG_UPDATE_DELAYED")
    check("bags: room again, accent again", bags.icon._vertex[2], accent[2])
    -- Icons in a warm colour already (Pitwall orange): the text warns too.
    local iconColour = ns.Themes.IconColor
    ns.Themes.IconColor = function() return { 0.95, 0.55, 0.1 } end
    M.state.bags[0][2], M.state.bags[1][2] = 1, 2
    M.Fire("BAG_UPDATE_DELAYED")
    check("bags: orange theme, the text warns", bags.text._textColor[1] .. "," .. bags.text._textColor[2], "1,0.5")
    M.state.bags[0][2], M.state.bags[1][2] = 4, 2
    M.Fire("BAG_UPDATE_DELAYED")
    check("bags: room again, text as before", bags.text._textColor[1], D.TextColour("dataBarBags")[1])
    ns.Themes.IconColor = iconColour
    check("close colours", D.CloseColours({ 1, 0.5, 0 }, { 0.9, 0.6, 0.1 }), true)
    check("far colours", D.CloseColours({ 1, 0.5, 0 }, { 1, 0.82, 0 }), false)
    check("own icon in the accent", bags.icon._texture, D.CFG.MEDIA .. "StatBags")
    check("column 1: XP, gold, durability, bags in a row", select(4, gold:GetPoint("LEFT")), D.CFG.PAD + f.xp.width + D.CFG.PROF_GAP)
    check("bags after durability", select(4, bags:GetPoint("LEFT")),
        select(4, dura:GetPoint("LEFT")) + dura.width + D.CFG.PROF_GAP)
    check("width follows the text", gold.width, D.CFG.ICON + D.CFG.ICON_GAP + #"123g 45s" * 7)
    local opened = 0
    ToggleAllBags = function() opened = opened + 1 end
    bags:GetScript("OnClick")(bags)
    check("bags: click opens them", opened, 1)
    ToggleAllBags = nil
    M.state.durability = nil
    M.Fire("UPDATE_INVENTORY_DURABILITY")
    check("durability: no click (taint)", dura:GetScript("OnClick"), nil)
    check("nothing equipped: no durability", dura:IsShown(), false)
    Settings.Set("dataBarGold", false)
    check("gold off", gold:IsShown(), false)
    check("bags move up", select(4, bags:GetPoint("LEFT")), D.CFG.PAD + f.xp.width + D.CFG.PROF_GAP)
    Settings.Set("dataBarGold", nil)
    M.state.money, M.state.bags = nil, nil
    -- Unspent talents: beside the line, and alone at the top level.
    local hasPoints = true
    TalentMicroButton = CreateFrame("Button", "TalentMicroButton")
    C_ClassTalents = { HasUnspentTalentPoints = function() return hasPoints end }
    M.Fire("PLAYER_TALENT_UPDATE")
    check("talents: shown", f.xp.talents:IsShown(), true)
    check("talents: beside the XP", select(2, f.xp.talents:GetPoint("LEFT")), f.xp.main)
    check("talents: label", f.xp.talents.text:GetText(), "Talents")
    local click = D.TalentClick()
    check("talents: secure click on Blizzard's button", click:GetAttribute("type") .. " " .. tostring(click:GetAttribute("clickbutton") == TalentMicroButton), "click true")
    check("talents: click button not on the bar", click:GetParent(), UIParent)
    check("talents: click button shown over the text", click:IsShown() and click:GetWidth() == f.xp.talents:GetWidth(), true)
    check("talents: hidden in combat by a state driver", click._driver, "[combat] hide; show")
    local toggled = false
    PlayerSpellsUtil = { ToggleClassTalentOrSpecFrame = function() toggled = true end }
    f.xp.talents:GetScript("OnClick")(f.xp.talents)
    check("talents: the text itself never opens from addon code", toggled, false)
    PlayerSpellsUtil, TalentMicroButton = nil, nil
    f.xp.talents:GetScript("OnUpdate")(f.xp.talents, 0)
    check("talents: pulsing", f.xp.talents.text._textColor ~= nil, true)
    M.state.level = 60
    M.Fire("PLAYER_TALENT_UPDATE")
    check("top level: talents alone", f.xp:IsShown() and not f.xp.main:IsShown(), true)
    check("top level: at the start", select(4, f.xp.talents:GetPoint("LEFT")), 0)
    M.state.level = 43
    hasPoints = false
    M.Fire("PLAYER_TALENT_UPDATE")
    check("points spent: gone", f.xp.talents:IsShown(), false)
    C_ClassTalents, PlayerSpellsUtil = nil, nil
    check("own icon", p[1].icon._texture, D.CFG.MEDIA .. "ProfAlchemy")
    check("icon in the accent", near(p[1].icon._vertex[1], S("dataBarAccent")[1]), true)
    Settings.Set("dataBarProfColours", true)
    check("own colours: Alchemy green", near(p[1].icon._vertex[1], ns.CFG.COLORS.ALCHEMY[1]), true)
    Settings.Set("dataBarProfColours", nil)
    Settings.Set("dataBarPos", "BOTTOM")
    check("bottom", f:GetPoint("BOTTOMLEFT") ~= nil, true)
    Settings.Set("dataBarHeight", 99)
    check("height clamped", f:GetHeight(), 40)
    for _, id in ipairs(D.DESIGN_ORDER) do
        check("design " .. id .. " applies", pcall(Settings.Set, "dataBarDesign", id), true)
        check("design " .. id .. ": label", ns.L["DATABAR_DESIGN_" .. id] ~= nil, true)
    end
    Settings.Set("dataBarDesign", "SEGMENTS")
    check("segments: 19 dividers on the XP line", (function()
        local n = 0
        for _, d in ipairs(f.xp.line.dividers) do if d:IsShown() then n = n + 1 end end
        return n
    end)(), 19)
    Settings.Set("dataBarDesign", "ICONS")
    check("icons only: no label", p[1].name:IsShown(), false)
    Settings.Set("dataBarDesign", "PHIAL")
    check("phial: brass caps", f.xp.line.caps[1]:IsShown(), true)
    check("phial: tinted liquid", f.xp.line.fill._texture, D.CFG.MEDIA .. "FillShade.tga")
    Settings.Set("dataBarDesign", "GLASS")
    check("glass: no caps", f.xp.line.caps[1]:IsShown(), false)
    check("accent: Forever's gold", near(S("dataBarAccent")[2], 0.792), true)
    check("edge line on, in the accent", f.edge:IsShown() and near(f.edge._texColor[2], 0.792), true)
    Settings.Set("dataBarEdge", false)
    check("edge line off", f.edge:IsShown(), false)
    Settings.Set("dataBarEdge", nil)
    Settings.Set("hideInCombat", true)
    M.state.combat = true
    M.Fire("PLAYER_REGEN_DISABLED")
    check("hidden in combat", f:IsShown(), false)
    M.state.combat = false
    M.Fire("PLAYER_REGEN_ENABLED")
    check("back after combat", f:IsShown(), true)
    Settings.Set("hideInCombat", nil)
    M.state.level = 60
    M.Fire("PLAYER_XP_UPDATE")
    check("max level: no XP part", f.xp:IsShown(), false)
    M.state.level = 43
    M.Fire("PLAYER_XP_UPDATE")
    for _, k in ipairs({ "dataBarPos", "dataBarHeight", "dataBarDesign" }) do Settings.Set(k, nil) end
    StatusTrackingBarManager = CreateFrame("Frame")
    Settings.Set("dataBarXp", false)
    check("XP off: Blizzard's bar back", ns.Xp.blizzardShown, true)
    Settings.Set("dataBarXp", nil)
    check("XP on: Blizzard's bar hidden", ns.Xp.blizzardShown == false and not StatusTrackingBarManager:IsShown(), true)
    StatusTrackingBarManager = nil
end


section("Skill-ups")
do
    local D, C, f = ns.DataBar, ns.Crafts, ns.DataBar.frame
    local first = f.profs[1]
    local recipes = {
        [1] = { name = "Elixir", learned = true, relativeDifficulty = 0, r = { { 500, 2 } } },
        [2] = { name = "Potion", learned = true, relativeDifficulty = 1, maxTrivialLevel = 400, r = { { 501, 1 }, { 500, 1 } } },
        [3] = { name = "Old Potion", learned = true, relativeDifficulty = 3, r = { { 500, 1 } } },
        [4] = { name = "Unknown", learned = false, relativeDifficulty = 0, r = { { 500, 1 } } },
    }
    local profID = first.skillLine
    C_TradeSkillUI = {
        -- As in Forever: id 0, the name is what tells it.
        GetBaseProfessionInfo = function() return { professionID = 0, professionName = first.data.name } end,
        GetFilteredRecipeIDs = function() return { 1, 2, 3, 4 } end,
        GetRecipeInfo = function(id) return recipes[id] end,
        GetRecipeSchematic = function(id)
            local slots = {}
            for _, r in ipairs(recipes[id].r) do
                slots[#slots + 1] = { reagentType = 1, quantityRequired = r[2], reagents = { { itemID = r[1] } } }
            end
            slots[#slots + 1] = { reagentType = 0, quantityRequired = 1, reagents = { { itemID = 999 } } }
            return { reagentSlotSchematics = slots }
        end,
        IsNPCCrafting = function() return false end,
    }
    local items = {}
    local oldItem = C_Item
    C_Item = setmetatable({ GetItemCount = function(id) return items[id] or 0 end }, { __index = oldItem })
    check("skill-ups: on by default", Settings.DEFAULTS.dataBarSkillUps, true)
    check("skill-ups: not read yet", C.Known(profID), false)
    Settings.Set("dataBarSkillUps", true)
    check("skill-ups: never read, the tooltip says to open it", (function()
        GameTooltip._lines = nil
        first:GetScript("OnEnter")(first)
        return table.concat(GameTooltip._lines or {}, "\n"):find(ns.L.TIP_SKILLUPS_UNKNOWN, 1, true) ~= nil
    end)(), true)
    M.Fire("TRADE_SKILL_SHOW")
    M.RunTimers()
    check("skill-ups: read when the window shows", C.Known(profID), true)
    local kept = ns.CharDB().crafts[profID]
    check("skill-ups: grey and unlearned ones not kept", (kept[3] == nil and kept[4] == nil and kept[1] ~= nil), true)
    check("skill-ups: only materials, not optional reagents", #kept[2].r, 4)
    check("skill-ups: nothing in the bags, none", #C.SkillUps(profID), 0)
    items[500], items[501] = 5, 1
    M.Fire("BAG_UPDATE_DELAYED")
    local list = C.SkillUps(profID)
    check("skill-ups: both can be made, orange first", #list .. " " .. list[1].name .. " " .. list[1].times, "2 Elixir 2")
    check("skill-ups: limited by the scarcest material", list[2].times, 1)
    check("skill-ups: +2 behind the rank", first.value:GetText():find("+2", 1, true) ~= nil, true)
    check("skill-ups: grey from its trivial rank on", #C.SkillUps(profID, 400), 1)
    check("skill-ups: below it still counted", #C.SkillUps(profID, 399), 2)
    -- A recipe turns grey: dropped when the window shows it again.
    recipes[1].relativeDifficulty = 3
    M.Fire("TRADE_SKILL_LIST_UPDATE")
    M.RunTimers()
    check("skill-ups: grey now, dropped", #C.SkillUps(profID), 1)
    -- Another player's profession (a link) or an NPC's is not read.
    C_TradeSkillUI.IsNPCCrafting = function() return true end
    check("skill-ups: NPC crafting not read", C.Scan(), false)
    Settings.Set("dataBarSkillUps", false)
    check("skill-ups: off, the rank alone", first.value:GetText(), tostring(first.data.rank))
    Settings.Set("dataBarSkillUps", nil)
    C_TradeSkillUI, C_Item = nil, oldItem
    ns.CharDB().crafts = nil
end


section("Gathering skill-ups")
do
    local G = ns.Gathering
    local function names(list) local t = {} for _, r in ipairs(list) do t[#t + 1] = r.name .. (r.difficulty and "=" .. r.difficulty or "") end return table.concat(t, ",") end
    check("gathering: a vein is orange at its skill", G.Difficulty(125, 125, 150, 175, 225), 0)
    check("gathering: yellow at +25, green at +50", G.Difficulty(150, 125, 150, 175, 225) .. G.Difficulty(175, 125, 150, 175, 225), "12")
    check("gathering: grey at +100, nothing", G.Difficulty(225, 125, 150, 175, 225), nil)
    check("gathering: not reachable yet, nothing", G.Difficulty(124, 125, 150, 175, 225), nil)
    check("gathering: at the cap, nothing", G.Difficulty(300, 300, 325, 350, 400, 300), nil)
    check("gathering: herbs at 60, hardest first", names(G.Nodes("HERBALISM", 60, 75)), "Mageroyal=0,Earthroot=1,Peacebloom=2,Silverleaf=2")
    check("gathering: a rich vein marked", names(G.Nodes("MINING", 280, 300)):find("Thorium Ore " .. ns.L.TIP_RICH .. "=0", 1, true) ~= nil, true)
    check("gathering: Outland stays away below 300", names(G.Nodes("MINING", 299, 300)):find("Fel Iron", 1, true), nil)
    check("smelting: Wowhead's numbers", names(G.Smelting(112, 150)), "Silver Bar=2,Bronze Bar=2")
    local _, nextHerbs = G.Nodes("HERBALISM", 60, 75)
    check("next: the herb unlocking next", names(nextHerbs), "Briarthorn")
    local _, nextVeins = G.Nodes("MINING", 70, 75)
    check("next: all veins at the next skill", #nextVeins .. " " .. nextVeins[1].req, "2 75")
    local _, nextVanilla = G.Nodes("MINING", 290, 300)
    check("next: no Outland vein on a 300 cap", #nextVanilla, 0)
    local _, nextOutland = G.Nodes("MINING", 290, 375)
    check("next: Fel Iron on a 375 cap", nextOutland[1] and nextOutland[1].req, 300)
    local _, nextSmelt = G.Smelting(112, 150)
    check("next: smelting unlocks Iron at 125", nextSmelt[1].name .. " " .. nextSmelt[1].req, "Iron Bar 125")
    check("gathering: no table for crafting", G.Has("ALCHEMY"), false)
    -- The Mining slot (250/375 in the mock) lists veins and smelting, not the window hint.
    local mining = ns.DataBar.frame.profs[2]
    local oldItem = C_Item
    C_Item = setmetatable({ GetItemIconByID = function(id) return 100000 + id end }, { __index = oldItem })
    GameTooltip._lines = nil
    mining:GetScript("OnEnter")(mining)
    C_Item = oldItem
    local tip = table.concat(GameTooltip._lines or {}, "\n")
    check("mining tooltip: veins", tip:find(ns.L.TIP_GATHER_VEINS, 1, true) ~= nil and tip:find(ns.L.TIP_GATHER_HERBS, 1, true) == nil and tip:find("|T", 1, true) ~= nil and tip:find("Rich Thorium", 1, true) == nil and tip:find("Thorium Ore", 1, true) ~= nil, true)
    check("mining tooltip: at 250 no smelting gives points, no heading", tip:find(ns.L.TIP_GATHER_SMELTING, 1, true), nil)
    check("mining tooltip: next vein shown", tip:find(ns.L.TIP_GATHER_NEXT .. " Thorium Ore", 1, true) ~= nil, true)
    check("mining tooltip: no open-the-window hint", tip:find(ns.L.TIP_SKILLUPS_UNKNOWN, 1, true), nil)
end

section("Fonts")
do
    local f = ns.DataBar.frame
    local function font(fs) return fs._font[1] end
    check("default: the Quest Log's font", S("dataBarFont"), "Friz Quadrata")
    check("default: size 11", S("dataBarFontSize"), 11)
    check("XP text in it", font(f.xp.text), "Fonts\\FRIZQT__.TTF")
    check("clock two points larger", f.clock.text._font[2], 13)
    Settings.Set("dataBarFont", "Morpheus")
    Settings.Set("dataBarFontColor", { 1, 0, 0 })
    check("all: the XP text follows", font(f.xp.text), "Fonts\\MORPHEUS.TTF")
    check("all: a profession's name too", font(f.profs[1].name), "Fonts\\MORPHEUS.TTF")
    check("all: the colour", f.xp.text._textColor[2], 0)
    check("values fainter", f.profs[1].value._textColor[4] < 1, true)
    Settings.Set("dataBarClockFontOwn", true)
    Settings.Set("dataBarClockFontSize", 18)
    check("own font: the clock alone", font(f.clock.text) .. f.clock.text._font[2], "Fonts\\FRIZQT__.TTF20")
    check("own font: the clock grows", f.clock.width >= 40, true)
    check("own font: the others keep all", font(f.xp.text), "Fonts\\MORPHEUS.TTF")
    Settings.Set("dataBarFontSize", 99)
    check("size kept in its range", S("dataBarFontSize"), 20)
    check("the XP part grows with it", f.xp:GetHeight() > 20, true)
    for _, k in ipairs({ "dataBarFont", "dataBarFontColor", "dataBarFontSize", "dataBarClockFontOwn",
        "dataBarClockFontSize" }) do Settings.Set(k, nil) end
    ns.Window.Open("fonts")
    check("font page", ns.Window.Current(), "fonts")
    ns.Window.ShowPage("databar")
    ns.Window.Toggle()
end

section("Micro menu")
do
    local D, Mi = ns.DataBar, ns.Micro
    local f = D.frame
    for _, b in ipairs(Mi.BUTTONS) do _G[b.name] = CreateFrame("Button", b.name) end
    Settings.Changed("dataBarMicro")
    local holder = Mi.Holder()
    local function count()
        local n = 0
        for _, b in ipairs(Mi.Buttons()) do if b:IsShown() then n = n + 1 end end
        return n
    end
    check("eight icons without collections", count(), 8)
    check("four left of the clock", f.clock.microLeft, 4 * (D.CFG.ICON + D.CFG.ICON_GAP))
    check("the clock part holds them", f.clock.width, 8 * (D.CFG.ICON + D.CFG.ICON_GAP) + f.clock.textWidth)
    check("the clock between them", select(4, f.clock.body:GetPoint("LEFT")), f.clock.microLeft + (f.clock.textWidth - f.clock.bodyWidth) / 2)
    check("holder at the clock's place", select(4, holder:GetPoint("LEFT")), f.clock.x)
    check("holder not on the bar", holder:GetParent(), UIParent)
    local first = Mi.Buttons()[1]
    check("secure click on Blizzard's button", first:GetAttribute("type") .. " " .. tostring(first:GetAttribute("clickbutton") == CharacterMicroButton), "click true")
    check("shown by a state driver", holder._driver, "show")
    Settings.Set("hideInCombat", true)
    check("hides in combat as the bar", holder._driver, "[combat] hide; show")
    Settings.Set("hideInCombat", nil)
    Settings.Set("dataBarMicroCollections", true)
    check("collections as an option", count(), 9)
    check("then five left", f.clock.microLeft, 5 * (D.CFG.ICON + D.CFG.ICON_GAP))
    Settings.Set("dataBarMicroCollections", nil)
    M.state.combat = true
    Settings.Set("dataBarMicro", false)
    check("in combat: the icons wait", count(), 8)
    M.state.combat = false
    M.Fire("PLAYER_REGEN_ENABLED")
    check("after combat: gone", holder:IsShown(), false)
    Settings.Set("dataBarMicro", nil)
    check("back", holder:IsShown() and count(), 8)
    local C = ns.Clock
    local t = os.time({ year = 2026, month = 11, day = 16, hour = 13, min = 5, sec = 47 })
    local function parts(at) local h, m, sec, ap = C.Parts(at) return h .. ":" .. m .. ":" .. sec .. (ap and " " .. ap or "") end
    check("24-hour clock", parts(t), "13:05:47")
    Settings.Set("dataBarClock12", true)
    check("12-hour clock", parts(t), " 1:05:47 PM")
    check("12-hour clock: midnight", parts(t - 13 * 3600), "12:05:47 AM")
    check("12-hour clock: noon", parts(t - 3600), "12:05:47 PM")
    C.Update(f.clock)
    check("12-hour clock on the bar: no blank before the hour", f.clock.text:GetText():sub(1, 1) ~= " ", true)
    check("12-hour clock on the bar: AM/PM", f.clock.ampm:GetText() == "AM" or f.clock.ampm:GetText() == "PM", true)
    Settings.Set("dataBarClock12", nil)
    -- The date as the language writes it, with the addon's weekday names.
    check("date: English order", C.DateText(t, "{wd} {m}/{d}", "Sun Mon Tue Wed Thu Fri Sat"), "Mon 11/16")
    check("date: German order", C.DateText(t, "{wd} {d}.{m}.", "So Mo Di Mi Do Fr Sa"), "Mo 16.11.")
    check("date: the language's", C.DateText(t), (ns.L.CLOCK_DATE:gsub("{(%a+)}", { wd = "Mon", d = 16, m = 11 })))
    check("day share: noon is half", C.DayShare(os.time({ year = 2026, month = 11, day = 16, hour = 12 })), 0.5)
    -- Every style lays out and shows its own pieces.
    for _, style in ipairs(C.STYLES) do
        Settings.Set("dataBarClockStyle", style)
        check(style .. ": a width", f.clock.bodyWidth > 0, true)
        check(style .. ": the plain time only where it belongs", f.clock.text:IsShown(), style ~= "LED" and style ~= "TILES")
    end
    Settings.Set("dataBarClockStyle", "SECONDS")
    check("seconds: on the time's baseline", select(3, f.clock.sec:GetPoint("BOTTOMLEFT")), "BOTTOMRIGHT")
    check("seconds: no vertical offset", select(5, f.clock.sec:GetPoint("BOTTOMLEFT")), 0)
    -- A narrower time than the widest (digits differ): centred in its room, not left with the slack on the right.
    local measure = f.clock.text.GetStringWidth
    f.clock.text.GetStringWidth = function() return 10 end
    C.Update(f.clock)
    local x = select(4, f.clock.text:GetPoint("LEFT"))
    check("seconds: a narrow time centred", x > f.clock.timeX and x - f.clock.timeX < f.clock.timeRoom / 2, true)
    f.clock.text.GetStringWidth = measure
    Settings.Set("dataBarClockStyle", "LED")
    C.Update(f.clock, os.time({ year = 2026, month = 11, day = 16, hour = 18, min = 1 }))
    local d1 = f.clock.digits[1].segments
    check("LED: a 1 lights b and c", d1.b._texColor[4] == 1 and d1.c._texColor[4] == 1 and d1.a._texColor[4] < 1, true)
    check("LED: an 8 lights all", f.clock.digits[2].segments.g._texColor[4], 1)
    Settings.Set("dataBarClockStyle", "TILES")
    Settings.Set("dataBarClock12", true)
    C.Update(f.clock, os.time({ year = 2026, month = 11, day = 16, hour = 9, min = 30 }))
    check("tiles: no tile for a blank hour digit", f.clock.digits[1].edge:IsShown(), false)
    local wide = f.clock.bodyWidth
    C.Update(f.clock, os.time({ year = 2026, month = 11, day = 16, hour = 10, min = 30 }))
    check("tiles: the width stays at 10 o'clock", f.clock.bodyWidth, wide)
    Settings.Set("dataBarClock12", nil)
    Settings.Set("dataBarClockStyle", nil)
    -- Own size: the clock alone.
    Settings.Set("dataBarClockSizeOwn", true)
    Settings.Set("dataBarClockSize", 20)
    check("own size", select(2, f.clock.text:GetFont()), 20)
    check("own size: the seconds smaller", select(2, f.clock.sec:GetFont()), 17)
    Settings.Set("dataBarClockSizeOwn", nil)
    Settings.Set("dataBarClockSize", nil)
    check("own size off: the bar's font + 2", select(2, f.clock.text:GetFont()), select(2, D.FontFor("dataBarClock")) + 2)
    Settings.Set("dataBarClock", false)
    check("clock off: the icons stay", holder:IsShown() and f.clock:IsShown() and not f.clock.body:IsShown(), true)
    Settings.Set("dataBarClock", nil)
    for _, b in ipairs(Mi.BUTTONS) do _G[b.name] = nil end
    Settings.Changed("dataBarMicro")
    check("no Blizzard buttons: no icons", holder:IsShown(), false)
end

section("Options window")
local W = ns.Window
W.Open()
check("window shown", W.IsShown(), true)
check("opens on the look", W.Current(), "databar")
local function shown(want)
    for _, fs in ipairs(M.fontStrings) do if fs._text == want then return true end end
    for _, f in ipairs(M.frames) do if f._text == want then return true end end
    return false
end
for _, p in ipairs(W.PAGES) do
    W.ShowPage(p.id)
    -- A page not offered (Data Broker without feeds) gives way to the first.
    local offered = not p.shown or p.shown()
    check("page " .. p.id .. " opens", W.Current(), offered and p.id or "databar")
    check("page " .. p.id .. " labelled", ns.L[p.label] ~= p.label, true)
end
local function rowFor(label, field)
    for _, f in ipairs(M.frames) do
        if f[field] and f.label and f.label._text and f.label._text:find(label, 1, true)
           and f:IsShown() ~= false then
            return f
        end
    end
end
W.ShowPage("professions")
local skillRow = rowFor("Alchemy", "box")
check("a checkbox per skill", skillRow ~= nil, true)
skillRow.box:GetScript("OnClick")(skillRow.box)
check("unticking hides it", Settings.IsHidden("Alchemy", "ALCHEMY"), true)
Settings.SetHidden("Alchemy", false)
W.Toggle()
check("toggled closed", W.IsShown(), false)
check("interface options page", M.registered[1], "Forever Data Bar")
W.Open("parts")
Settings.Set("dataBarGold", false)
local goldColumn
for _, f in ipairs(M.frames) do
    if f.label and f.label._text == "Column" and f:IsShown() ~= false and f.button and not f.button:IsEnabled() then goldColumn = f end
end
check("part off: its column dimmed", goldColumn ~= nil, true)
Settings.Set("dataBarGold", nil)
W.Open("reputation")
check("reputation page: its own switch", rowFor("Show", "box") ~= nil, true)
Settings.Set("dataBarHeight", 30)
Settings.Set("dataBarAccent", { 1, 0, 0 })
ns.Locale.Set("deDE")
Settings.SetRep(2, 609)
Settings.Reset()
check("reset: height back", S("dataBarHeight"), Settings.DEFAULTS.dataBarHeight)
check("reset: accent back", S("dataBarAccent")[2], Settings.DEFAULTS.dataBarAccent[2])
check("reset: language stays", ForeverDataBarDB.language, "deDE")
check("reset: factions stay", Settings.Reps()[2], 609)
Settings.SetRep(2, 54)
ns.Locale.Set("AUTO")
W.Toggle()
SlashCmdList.FOREVERDATABAR("")
check("/fdb opens the options", W.IsShown(), true)
W.Toggle()

section("Gold")
dofile("gold.lua")(ns, M, check)
dofile("goldledger.lua")(ns, M, check)

section("Themes")
dofile("themes.lua")(ns, M, check, ROOT)

section("Forever Themes hub")
dofile("hub.lua")(ns, M, check)

section("Character stats part")
dofile("charinfo.lua")(ns, M, check)

section("Currencies and hearthstone")
dofile("currencies.lua")(ns, M, check)

section("Data broker feeds")
dofile("broker.lua")(ns, M, check)

section("Languages")
local base = ns.Locales.enUS
for code, strings in pairs(ns.Locales) do
    for key in pairs(base) do check(code .. " has " .. key, strings[key] ~= nil, true) end
    for key in pairs(strings) do check(code .. ": " .. key .. " is known", base[key] ~= nil, true) end
    for key, value in pairs(base) do
        local want = select(2, value:gsub("%%[ds]", ""))
        local got = strings[key] and select(2, strings[key]:gsub("%%[ds]", "")) or want
        check(code .. ": placeholders of " .. key, got, want)
    end
end
for key, value in pairs(ns.Locales.deDE) do check("no sharp s in " .. key, value:find("ß", 1, true), nil) end
ns.Locale.Set("deDE")
W.Open("parts")
check("options in German", shown("Spalte"), true)
check("language stored account wide", ForeverDataBarDB.language, "deDE")
ns.Locale.Set("AUTO")
W.Toggle()

section("Embedded LibForeverThemes")
-- The copy in Libs/ is the library's own (ForeverThemes, tools/sync there):
-- checked when that repository sits next to this one (not in CI).
do
    local LIBREPO = ROOT .. "/../ForeverThemes"
    if io.open(LIBREPO .. "/LibForeverThemes.lua") then
        local diff = io.popen("diff -rq '" .. LIBREPO .. "/LibForeverThemes.lua' '" .. ROOT
            .. "/Libs/LibForeverThemes/LibForeverThemes.lua' && diff -rq '" .. LIBREPO .. "/Media' '" .. ROOT
            .. "/Libs/LibForeverThemes/Media' 2>&1"):read("*a")
        check("copy equals ForeverThemes (run its tools/sync)", diff, "")
    else
        print("  (skipped: ForeverThemes not next to this addon)")
    end
end
check("library loaded from our copy", LibForeverThemes.FOLDER, ADDON)

section("Timed crafts")
do
    local T = ns.Timed
    local known, cds, items = {}, {}, {}
    C_SpellBook.IsSpellKnown = function(id) return known[id] == true end
    C_Spell = { GetSpellCooldown = function(id) return cds[id] or { startTime = 0, duration = 0 } end,
        GetSpellName = function(id) return "Spell " .. id end }
    C_Item = { GetItemCount = function(id) return items[id] or 0 end, GetItemNameByID = function(id) return "Item " .. id end }
    C_Container.GetItemCooldown = function() return M.state.time - 3600, 3 * 86400 end
    check("nothing known: nothing shown", #T.For("ALCHEMY"), 0)
    known[17187] = true
    check("one transmute known: one line", #T.For("ALCHEMY"), 1)
    check("transmutes under one name", T.For("ALCHEMY")[1].name, ns.L.TIMED_TRANSMUTE)
    check("ready", T.For("ALCHEMY")[1].left, 0)
    cds[17187] = { startTime = M.state.time - 10, duration = 100 }
    check("time left", T.For("ALCHEMY")[1].left, 90)
    cds[17187] = { startTime = M.state.time, duration = 1.5 }
    check("global cooldown counts as ready", T.For("ALCHEMY")[1].left, 0)
    T.Learn(18560)
    check("seen in the window counts", T.For("TAILORING")[1].name, "Spell 18560")
    T.Learn(12345)
    check("other recipes not kept", ForeverDataBarChar.timed[12345], nil)
    check("salt shaker only in the bags", #T.For("LEATHERWORKING"), 0)
    items[15846] = 1
    check("salt shaker: time left", T.For("LEATHERWORKING")[1].left, 2 * 86400 + 82800)
    check("part: what the character can make", #T.Shown(), 3)
    check("part text: ready", T.Text(0), ns.L.DATABAR_HEARTH_READY)
    check("part text: days and hours", T.Text(2 * 86400 + 82800 + 59), "2d 23h")
    check("part text: hours and minutes", T.Text(5 * 3600 + 12 * 60), "5h 12m")
    check("part text: minutes", T.Text(40 * 60), "40m")
    check("part text: secret", T.Text(nil), "?")
    check("part listed, on by default", ns.DataBar.STATS.TIMED ~= nil and ns.Settings.DEFAULTS.dataBarTimed, true)
    M.state.time = 1000
    check("cooldown from before the boot (start 2^32 ms late)", math.floor(T.Left(1000 + 2 ^ 32 / 1000 - 3600, 7200) + 0.5), 3600)
    C_Item.GetItemIconByID = function(id) return "ICON" .. id end
    check("icon of what it makes (mooncloth)", T.Icon(T.LIST[1]), "ICON14342")
    check("transmute icon: arcanite", T.Icon(T.LIST[2]), "ICON12360")
    check("salt shaker: the salt", T.Icon(T.LIST[5]), "ICON15409")
    cds[17187] = { startTime = M.state.time - 10, duration = 100 }
    check("out of combat: read and kept", T.EntryLeft(T.LIST[2]), 90)
    M.state.combat = true
    cds[17187] = nil
    check("in combat: the kept end, not ready", T.EntryLeft(T.LIST[2]), 90)
    M.state.serverTime = (M.state.serverTime or 1800000000) + 30
    check("in combat: the kept end counts down", T.EntryLeft(T.LIST[2]), 60)
    check("in combat: no recipe opened", T.Open(T.LIST[2]), false)
    M.state.combat = nil
    local opened
    C_TradeSkillUI = C_TradeSkillUI or {}
    C_TradeSkillUI.OpenRecipe = function(id) opened = id end
    check("click: opens the recipe", T.Open(T.LIST[2]) and opened, 17187)
    check("click: not the salt shaker", T.Open(T.LIST[5]), false)
    check("own icon art", T.LIST[1].art, "TimedMooncloth")
    check("dedicated study: not known, not shown", T.Can(T.LIST[6]), nil)
    known[1225469] = true
    C_Spell.GetSpellTexture = function(id) return "SPELL" .. id end
    check("dedicated study: its spell's icon", T.Icon(T.LIST[6]), "SPELL1225469")
    cds[1225469] = { startTime = M.state.time - 3600, duration = 82800 }
    check("dedicated study: time left", T.EntryLeft(T.LIST[6]), 79200)
    check("dedicated study: no recipe to open", T.Open(T.LIST[6]), false)
    check("dedicated study: not under a profession", #T.For("ALCHEMY"), 1)
    check("dedicated study: own icon art", T.LIST[6].art, "TimedStudy")
    -- On the bar: a secure button casts it; each slot its own tooltip.
    local D = ns.DataBar
    ns.Settings.Set("dataBarTimed", true)
    D.Apply()
    D.UpdateStats()
    local g = D.frame.parts.TIMED
    D.PlaceCastClick()
    local cast = D.CastClick()
    check("cast: secure spell button", cast and cast:GetAttribute("type") .. " " .. cast:GetAttribute("spell"), "spell 1225469")
    check("cast: hidden in combat", cast._driver, "[combat] hide; show")
    check("cast: over its slot", cast._points.BOTTOMLEFT[3], (g:GetLeft() + g.slots[6].from) * g:GetEffectiveScale() / UIParent:GetEffectiveScale())
    local realCursor = GetCursorPosition
    local function hoverSlot(i)
        GetCursorPosition = function() return (g:GetLeft() + g.slots[i].from + 1) * g:GetEffectiveScale(), 0 end
        GameTooltip._lines, GameTooltip._left = nil, {}
    end
    hoverSlot(2)
    g:GetScript("OnEnter")(g)
    local tip2 = GameTooltip._lines and table.concat(GameTooltip._lines, "\n") or ""
    check("tooltip: only the slot under the cursor", tip2:find(ns.L.TIMED_TRANSMUTE, 1, true) ~= nil and tip2:find("1225469", 1, true) == nil, true)
    hoverSlot(6)
    g:GetScript("OnUpdate")(g)
    local tip6 = GameTooltip._lines and table.concat(GameTooltip._lines, "\n") or ""
    check("tooltip: follows the cursor", tip6:find("Spell 1225469", 1, true) ~= nil and tip6:find(ns.L.TIMED_TRANSMUTE, 1, true) == nil, true)
    check("tooltip: the cast hint", tip6:find(ns.L.DATABAR_TIP_TIMED_CAST, 1, true) ~= nil, true)
    g:GetScript("OnLeave")(g)
    check("tooltip: stops following on leave", g:GetScript("OnUpdate"), nil)
    GetCursorPosition = realCursor
    issecretvalue = function(v) return v == 999 end
    check("secret: unknown", T.Left(999, 5), nil)
    issecretvalue = nil
    ForeverDataBarChar.timed = nil
end

section("Part descriptions")
for _, part in ipairs(ns.DataBar.PARTS) do
    check("description for " .. part.id, ns.L["OPT_PART_DESC_" .. part.id] ~= "OPT_PART_DESC_" .. part.id, true)
end

section("Tooltips in the theme")
do
    local D, Themes, Tooltip = ns.DataBar, ns.Themes, ns.Tooltip
    local owner = CreateFrame("Button")
    GameTooltip._lines = nil
    ns.Tip:SetOwner(owner, "ANCHOR_TOPLEFT")
    ns.Tip:AddLine("Head", 1, 1, 1)
    ns.Tip:Show()
    check("classic: Blizzard's tooltip as before", GameTooltip._lines and GameTooltip._lines[1], "Head")
    check("classic: ours stays unused", Tooltip.Active(), GameTooltip)
    Themes.Switch("PITWALL")
    ns.Tip:SetOwner(owner, "ANCHOR_BOTTOMLEFT")
    ns.Tip:AddLine("Head", 1, 1, 1)
    ns.Tip:AddDoubleLine("Left", "Right", 0.8, 0.8, 0.8, 0.3, 1, 0.3)
    ns.Tip:AddLine("Click", 0.4, 0.8, 1)
    ns.Tip:Show()
    local own = Tooltip.Own()
    check("theme: our own tooltip", Tooltip.Active() == own and own:IsShown(), true)
    check("theme: owned by the part", ns.Tip:IsOwned(owner), true)
    check("theme: three lines", own:NumLines(), 3)
    check("theme: double line's right text", own.rows[2].right:GetText(), "Right")
    local text = select(4, D.FontFor("dataBar"))
    check("theme: white in the theme's text colour", own.rows[1].left._textColor[1], text[1])
    check("theme: grey too, a little fainter", own.rows[2].left._textColor[4], 0.8)
    check("theme: green keeps", own.rows[2].right._textColor[2], 1)
    check("theme: the click hint in the accent", own.rows[3].left._textColor[1], Themes.Accent()[1])
    check("theme: the first line in the title font", own.rows[1].left:GetFont() ~= nil, true)
    check("theme: wide enough for the double line", own._w >= own.rows[2].left:GetStringWidth() + own.rows[2].right:GetStringWidth(), true)
    check("theme: dressed as the windows", own.rims ~= nil and own.themeBack ~= nil, true)
    _G.issecretvalue = function(v) return v == 999 end
    local w = own.rows[1].left.GetStringWidth
    own.rows[1].left.GetStringWidth = function() return 999 end
    ns.Tip:Show()
    check("theme: a secret width counts as some width", own._w > 0, true)
    own.rows[1].left.GetStringWidth = w
    _G.issecretvalue = nil
    Tooltip.HideFor(owner)
    check("hidden on leave", own:IsShown(), false)
    -- The gold tooltip's curve: over blank lines of our tooltip.
    ForeverDataBarChar.goldDays = ForeverDataBarChar.goldDays or {}
    ForeverDataBarChar.goldDays[ns.Gold.DayKey(ns.Gold.Now(), 1)] = { gained = 0, spent = 0, close = 1, inc = {}, out = {} }
    local gold = D.frame.parts.GOLD
    gold:GetScript("OnEnter")(gold)
    local graph = ns.Gold.TooltipGraph(own)
    check("gold: the curve in our tooltip", graph:IsShown() and graph:GetParent() == own, true)
    check("gold: wide enough for it", own.minWidth, graph.width)

    -- The theme part as its icon alone.
    local follows = {}
    LibForeverThemes.SetHub({ Follows = function() return true end, Theme = function() return "PITWALL" end,
        Color = function() return nil end, OpenMenu = function() end, OpenOptions = function() end })
    local theme = D.frame.parts.THEME
    ns.Settings.Set("dataBarThemeIconOnly", true)
    D.UpdateStats()
    check("theme part: icon only", theme:IsShown() and theme.width, D.CFG.ICON)
    ns.Settings.Set("dataBarThemeIconOnly", false)
    D.UpdateStats()
    check("theme part: with its name again", theme.width > D.CFG.ICON, true)
    LibForeverThemes.SetHub(nil)

    -- Compact: an icon and a word, the details in the tooltip.
    ns.Settings.Set("dataBarChar", true)
    ns.CharInfo.Choose(ns.CharInfo.STATS[1].id, true)
    D.UpdateStats()
    local char = D.frame.parts.CHAR
    check("char: values on the bar", char.slots[1].icon:IsShown(), true)
    ns.Settings.Set("dataBarCharCompact", true)
    D.UpdateStats()
    check("char compact: the word", char.text:IsShown() and char.text:GetText(), ns.L.DATABAR_COMPACT_CHAR)
    check("char compact: its icon", char.icon:IsShown() and char.icon._texture, D.CFG.MEDIA .. "StatChar")
    check("char compact: no values on the bar", char.slots[1].icon:IsShown(), false)
    char:GetScript("OnEnter")(char)
    check("char compact: the values in the tooltip", own:NumLines() >= 2, true)
    ns.Settings.Set("dataBarCharCompact", false)
    D.UpdateStats()
    check("char: back to the values", char.slots[1].icon:IsShown() and not char.icon:IsShown(), true)
    ns.Settings.Set("dataBarChar", false)
    D.UpdateStats()

    local repsWere = ns.Settings.Get("dataBarReps")
    ns.Settings.Set("dataBarReps", true)
    ns.Settings.Set("dataBarRepsCompact", true)
    D.UpdateReps()
    local reps = D.frame.repCompact
    check("reps compact: the word", reps:IsShown() and reps.text:GetText(), ns.L.DATABAR_COMPACT_REPS)
    check("reps compact: no entries", D.frame.reps[1]:IsShown(), false)
    check("reps compact: its own icon", reps.icon._texture, D.CFG.MEDIA .. "StatRep")
    reps:GetScript("OnEnter")(reps)
    check("reps compact: every faction in the tooltip", own:NumLines(), 2 + 4)
    check("reps compact: name and standing", own.rows[2].left:GetText() ~= nil and own.rows[2].right:GetText():find("/", 1, true) ~= nil, true)
    ns.Settings.Set("dataBarRepsCompact", false)
    D.UpdateReps()
    check("reps: the entries again", D.frame.reps[1]:IsShown() and not reps:IsShown(), true)
    ns.Settings.Set("dataBarReps", repsWere)
    D.UpdateReps()
    Themes.Switch("CLASSIC")
end

section("Only SavedVariables, nothing private")
for _, f in ipairs(tocFiles()) do
    local src = io.open(ROOT .. "/" .. f):read("*a")
    check("no CVar storage in " .. f, src:find("CVar", 1, true), nil)
    check("no ChatPanel fonts in " .. f, src:find("ChatPanel", 1, true), nil)
end

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
