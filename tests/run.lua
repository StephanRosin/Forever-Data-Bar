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
    check("bags: free slots", bags.text:GetText(), "6")
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
    local hasPoints, toggles = true, 0
    C_ClassTalents = { HasUnspentTalentPoints = function() return hasPoints end }
    PlayerSpellsUtil = { ToggleClassTalentOrSpecFrame = function() toggles = toggles + 1 end }
    M.Fire("PLAYER_TALENT_UPDATE")
    check("talents: shown", f.xp.talents:IsShown(), true)
    check("talents: beside the XP", select(2, f.xp.talents:GetPoint("LEFT")), f.xp.main)
    check("talents: label", f.xp.talents.text:GetText(), "Talents")
    f.xp.talents:GetScript("OnClick")(f.xp.talents)
    check("talents: click opens", toggles, 1)
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
    check("the clock text between them", select(4, f.clock.text:GetPoint("CENTER")), f.clock.microLeft + f.clock.textWidth / 2)
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
    Settings.Set("dataBarClock", false)
    check("clock off: the icons stay", holder:IsShown() and f.clock:IsShown() and not f.clock.text:IsShown(), true)
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
    check("page " .. p.id .. " opens", W.Current(), p.id)
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

section("Only SavedVariables, nothing private")
for _, f in ipairs(tocFiles()) do
    local src = io.open(ROOT .. "/" .. f):read("*a")
    check("no CVar storage in " .. f, src:find("CVar", 1, true), nil)
    check("no ChatPanel fonts in " .. f, src:find("ChatPanel", 1, true), nil)
end

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
