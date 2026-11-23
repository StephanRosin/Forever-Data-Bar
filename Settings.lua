local ADDON, ns = ...

--[[---------------------------------------------------------------------------
Settings.lua -- the look and the parts account wide (ForeverDataBarDB), the
chosen factions, hidden skills and the XP session per character
(ForeverDataBarChar). A value equal to its default is not stored.
-----------------------------------------------------------------------------]]
local Settings = {}
ns.Settings = Settings

Settings.DEFAULTS = {
    theme = "CLASSIC",          -- see Themes.lua; switched only through Themes.Switch
    dataBarDesign = "GLASS",    -- see DataBar.DESIGNS
    dataBarPos = "TOP",         -- TOP or BOTTOM edge of the screen
    dataBarHeight = 24,
    dataBarAlpha = 75,          -- the background, percent
    dataBarBgColor = { 0, 0, 0 },
    dataBarAccent = { 1, 0.792, 0.188 },  -- Forever's gold, #FFCA30
    dataBarEdge = true,         -- a line in the accent on the side towards the game
    dataBarGear = true,         -- the options' gear at the right edge
    dataBarProfColours = true,  -- professions and standings in their own colours, not the accent
    -- The bar's own icons (white, tinted) for the character stats, currencies
    -- and hearthstone instead of the game's. New installs: on; accounts from
    -- before keep the game's (Settings.KeepForExisting).
    dataBarOwnIcons = true,
    -- The parts: shown, column (1..5, DataBar.Layout; parts in one column
    -- line up in this order) and a shift to the right (px).
    dataBarXp = true, dataBarXpColumn = 1, dataBarXpX = 0, dataBarXpWidth = 200,
    -- On the XP part: shown, LEFT or RIGHT of it.
    dataBarXpPerHour = true, dataBarXpPerHourPlace = "RIGHT",
    dataBarXpToLevel = true, dataBarXpToLevelPlace = "RIGHT",
    dataBarGold = true, dataBarGoldColumn = 2, dataBarGoldX = 0,
    dataBarDura = true, dataBarDuraColumn = 2, dataBarDuraX = 0,
    dataBarBags = true, dataBarBagsColumn = 2, dataBarBagsX = 0,
    dataBarClock = true, dataBarClockColumn = 3, dataBarClockX = 0,
    dataBarClock12 = false,     -- 12-hour clock (1:05 PM) instead of 24-hour
    dataBarClockStyle = "STANDARD",   -- how it looks (Clock.STYLES)
    dataBarClockSizeOwn = false, dataBarClockSize = 13,   -- own size, else the bar's font + 2
    dataBarMicro = true,        -- Blizzard's micro menu around the clock (Micro.lua)
    dataBarMicroCollections = false,
    dataBarProfs = true, dataBarProfsColumn = 5, dataBarProfsX = 0, dataBarProfsWidth = 96,
    dataBarSkillUps = true,     -- "+3": recipes giving skill points whose materials are in the bags (Crafts.lua)
    dataBarRepIcons = "LINES",  -- the standing as icon set or LETTER, see DataBar.STANDING_ICONS
    dataBarReps = true, dataBarRepsColumn = 4, dataBarRepsX = 0, dataBarRepsWidth = 96,
    -- Compact: only an icon and a word on the bar, the details in the tooltip (reputation, values, currencies).
    dataBarRepsCompact = false, dataBarCharCompact = false, dataBarCurrencyCompact = false,
    -- The character's combat values (CharInfo.lua), each one chosen.
    -- Which values: per character (CharInfo.Chosen).
    dataBarChar = false, dataBarCharColumn = 4, dataBarCharX = 0,
    -- Currencies and marks (Currencies.lua), each kind switched on its own; and the hearthstone.
    dataBarCurrency = false, dataBarCurrencyColumn = 2, dataBarCurrencyX = 0,
    dataBarCurHonor = true, dataBarCurFavor = true, dataBarCurReal = true, dataBarCurShards = true, dataBarCurMarks = true,
    dataBarCurZero = true,      -- currencies and shards at 0 too (the marks only when held)
    dataBarHearth = false, dataBarHearthColumn = 2, dataBarHearthX = 0,
    -- Crafts with a long cooldown (Timed.lua): those the character can make.
    dataBarTimed = true, dataBarTimedColumn = 2, dataBarTimedX = 0,
    -- Forever Themes' central theme: shows only while that addon is loaded.
    dataBarTheme = true, dataBarThemeColumn = 5, dataBarThemeX = 0,
    dataBarThemeIconOnly = false,   -- the theme part as its icon alone
    hideInCombat = false,
    hideInGroup = false,
    -- The font of every part (the Forever Quest Log's); the clock
    -- is two points larger.
    dataBarFont = "Friz Quadrata",
    dataBarFontSize = 11,
    dataBarFontOutline = "",    -- "", OUTLINE or THICKOUTLINE
    dataBarFontColor = { 0.729, 0.639, 0.478 },   -- parchment, #BAA37A
}

-- A part may have a font of its own: <part key>FontOwn, …Font, …FontSize,
-- …FontColor (see DataBar.PARTS).
Settings.FONT_PARTS = { "dataBarXp", "dataBarGold", "dataBarDura", "dataBarBags", "dataBarClock",
    "dataBarProfs", "dataBarReps", "dataBarChar", "dataBarCurrency", "dataBarHearth", "dataBarTimed", "dataBarTheme" }
Settings.FONT_SIZES = { 8, 20 }
-- Within a column: the smaller order further left; the same order keeps DataBar.PARTS'.
Settings.ORDER_RANGE, Settings.ORDER_DEFAULT = { 1, 20 }, 10
for _, key in ipairs(Settings.FONT_PARTS) do
    Settings.DEFAULTS[key .. "FontOwn"] = false
    Settings.DEFAULTS[key .. "Font"] = Settings.DEFAULTS.dataBarFont
    Settings.DEFAULTS[key .. "FontSize"] = Settings.DEFAULTS.dataBarFontSize
    Settings.DEFAULTS[key .. "FontColor"] = Settings.DEFAULTS.dataBarFontColor
    Settings.DEFAULTS[key .. "Order"] = Settings.ORDER_DEFAULT
end

Settings.RANGES = {
    dataBarHeight = { 16, 40 },
    dataBarClockSize = { 8, 30 },
    dataBarXpWidth = { 80, 800 },
    dataBarProfsWidth = { 40, 400 }, dataBarRepsWidth = { 40, 400 },
    dataBarAlpha = { 0, 100 },
    dataBarXpX = { -2000, 2000 }, dataBarGoldX = { -2000, 2000 },
    dataBarDuraX = { -2000, 2000 }, dataBarBagsX = { -2000, 2000 }, dataBarClockX = { -2000, 2000 },
    dataBarProfsX = { -2000, 2000 }, dataBarRepsX = { -2000, 2000 }, dataBarThemeX = { -2000, 2000 },
    dataBarCharX = { -2000, 2000 }, dataBarCurrencyX = { -2000, 2000 }, dataBarHearthX = { -2000, 2000 },
    dataBarTimedX = { -2000, 2000 },
}
Settings.RANGES.dataBarFontSize = Settings.FONT_SIZES
for _, key in ipairs(Settings.FONT_PARTS) do
    Settings.RANGES[key .. "FontSize"] = Settings.FONT_SIZES
    Settings.RANGES[key .. "Order"] = Settings.ORDER_RANGE
end

-- The capital cities of the player's side, until other factions are chosen.
Settings.DEFAULT_REPS = {
    Alliance = { 69, 54, 47, 72 },   -- Darnassus, Gnomeregan, Ironforge, Stormwind
    Horde = { 76, 530, 81, 68 },     -- Orgrimmar, Darkspear Trolls, Thunder Bluff, Undercity
}

-- Skills hidden until shown in the options.
Settings.DEFAULT_HIDDEN = { FISHING = true }

function ns.AccountDB()
    ForeverDataBarDB = ForeverDataBarDB or {}
    return ForeverDataBarDB
end
ns.DB = ns.AccountDB

function ns.CharDB()
    ForeverDataBarChar = ForeverDataBarChar or {}
    return ForeverDataBarChar
end

local listeners = {}

function Settings.OnChange(fn)
    listeners[#listeners + 1] = fn
end

-- key nil: everything may have changed.
function Settings.Changed(key)
    for _, fn in ipairs(listeners) do fn(key) end
end

function Settings.Get(key)
    local v = ns.DB()[key]
    if v == nil then v = Settings.DEFAULTS[key] end
    return v
end

-- The value as stored: numbers rounded and kept in their range, the
-- default as nil.
function Settings.Stored(key, value)
    local range = Settings.RANGES[key]
    if range and type(value) == "number" then
        value = math.max(range[1], math.min(range[2], math.floor(value + 0.5)))
    end
    if value == Settings.DEFAULTS[key] then value = nil end
    return value
end

function Settings.Set(key, value)
    ns.DB()[key] = Settings.Stored(key, value)
    Settings.Changed(key)
end

function Settings.Reps()
    local reps = ns.CharDB().reps
    if type(reps) == "table" then return reps end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return Settings.DEFAULT_REPS[faction] or { 0, 0, 0, 0 }
end

-- factionID 0: the slot stays empty.
function Settings.SetRep(slot, factionID)
    local reps = {}
    for i, v in ipairs(Settings.Reps()) do reps[i] = v end
    for i = 1, 4 do reps[i] = reps[i] or 0 end
    reps[slot] = factionID or 0
    ns.CharDB().reps = reps
    Settings.Changed("reps")
end

-- Look and parts back to their defaults, under a theme with its look;
-- factions, hidden skills, the language, the theme colours, the other themes' settings and the
-- gold records (Themes.META) stay.
function Settings.Reset()
    local old = ns.DB()
    local db = ns.Themes.Seed(old.theme, {})
    for key in pairs(ns.Themes.META) do db[key] = old[key] end
    ForeverDataBarDB = db
    Settings.Changed(nil)
end

-- By the skill's localised name; the default by its key.
function Settings.IsHidden(name, key)
    local hidden = ns.CharDB().hidden
    if type(hidden) == "table" and hidden[name] ~= nil then return hidden[name] end
    return Settings.DEFAULT_HIDDEN[key or ""] or false
end

function Settings.SetHidden(name, value)
    local char = ns.CharDB()
    char.hidden = char.hidden or {}
    char.hidden[name] = value and true or false
    Settings.Changed("hidden")
end

-- Defaults that changed for new installs: an account from before keeps the
-- old value, in the live settings and every theme set, once (ForeverDataBarDB.kept).
-- A first install (no saved settings yet) takes the new defaults.
Settings.KEPT = { dataBarOwnIcons = false }
function Settings.KeepForExisting()
    local fresh = ForeverDataBarDB == nil or next(ForeverDataBarDB) == nil
    local db = ns.DB()
    db.kept = db.kept or {}
    for key, old in pairs(Settings.KEPT) do
        if not db.kept[key] then
            db.kept[key] = true
            if not fresh then
                if db[key] == nil then db[key] = old end
                for _, set in pairs(db.themeSets or {}) do
                    if type(set) == "table" and set[key] == nil then set[key] = old end
                end
            end
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    Settings.KeepForExisting()
    Settings.Changed(nil)
end)
