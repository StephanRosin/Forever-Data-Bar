local ADDON, ns = ...

--[[---------------------------------------------------------------------------
Settings.lua -- the look and the parts account wide (ForeverDataBarDB), the
chosen factions, hidden skills and the XP session per character
(ForeverDataBarChar). A value equal to its default is not stored.
-----------------------------------------------------------------------------]]
local Settings = {}
ns.Settings = Settings

Settings.DEFAULTS = {
    dataBarDesign = "GLASS",    -- see DataBar.DESIGNS
    dataBarPos = "TOP",         -- TOP or BOTTOM edge of the screen
    dataBarHeight = 24,
    dataBarAlpha = 75,          -- the background, percent
    dataBarBgColor = { 0, 0, 0 },
    dataBarAccent = { 1, 0.792, 0.188 },  -- Forever's gold, #FFCA30
    dataBarEdge = true,         -- a line in the accent on the side towards the game
    dataBarGear = true,         -- the options' gear at the right edge
    dataBarProfColours = true,  -- professions and standings in their own colours, not the accent
    -- The parts: shown, column (1..5, DataBar.Layout; parts in one column
    -- line up in this order) and a shift to the right (px).
    dataBarXp = true, dataBarXpColumn = 1, dataBarXpX = 0,
    -- On the XP part: shown, LEFT or RIGHT of it.
    dataBarXpPerHour = true, dataBarXpPerHourPlace = "RIGHT",
    dataBarXpToLevel = true, dataBarXpToLevelPlace = "RIGHT",
    dataBarGold = true, dataBarGoldColumn = 2, dataBarGoldX = 0,
    dataBarDura = true, dataBarDuraColumn = 2, dataBarDuraX = 0,
    dataBarBags = true, dataBarBagsColumn = 2, dataBarBagsX = 0,
    dataBarClock = true, dataBarClockColumn = 3, dataBarClockX = 0,
    dataBarMicro = true,        -- Blizzard's micro menu around the clock (Micro.lua)
    dataBarMicroCollections = false,
    dataBarProfs = true, dataBarProfsColumn = 5, dataBarProfsX = 0,
    dataBarReps = true, dataBarRepsColumn = 4, dataBarRepsX = 0,
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
    "dataBarProfs", "dataBarReps" }
Settings.FONT_SIZES = { 8, 20 }
for _, key in ipairs(Settings.FONT_PARTS) do
    Settings.DEFAULTS[key .. "FontOwn"] = false
    Settings.DEFAULTS[key .. "Font"] = Settings.DEFAULTS.dataBarFont
    Settings.DEFAULTS[key .. "FontSize"] = Settings.DEFAULTS.dataBarFontSize
    Settings.DEFAULTS[key .. "FontColor"] = Settings.DEFAULTS.dataBarFontColor
end

Settings.RANGES = {
    dataBarHeight = { 16, 40 },
    dataBarAlpha = { 0, 100 },
    dataBarXpX = { -2000, 2000 }, dataBarGoldX = { -2000, 2000 },
    dataBarDuraX = { -2000, 2000 }, dataBarBagsX = { -2000, 2000 }, dataBarClockX = { -2000, 2000 },
    dataBarProfsX = { -2000, 2000 }, dataBarRepsX = { -2000, 2000 },
}
Settings.RANGES.dataBarFontSize = Settings.FONT_SIZES
for _, key in ipairs(Settings.FONT_PARTS) do Settings.RANGES[key .. "FontSize"] = Settings.FONT_SIZES end

-- The capital cities of the player's side, until other factions are chosen.
Settings.DEFAULT_REPS = {
    Alliance = { 69, 54, 47, 72 },   -- Darnassus, Gnomeregan, Ironforge, Stormwind
    Horde = { 76, 530, 81, 68 },     -- Orgrimmar, Darkspear Trolls, Thunder Bluff, Undercity
}

-- Skills hidden until shown in the options.
Settings.DEFAULT_HIDDEN = { FISHING = true, RIDING = true }

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

-- Numbers are rounded and kept in their range.
function Settings.Set(key, value)
    local range = Settings.RANGES[key]
    if range and type(value) == "number" then
        value = math.max(range[1], math.min(range[2], math.floor(value + 0.5)))
    end
    if value == Settings.DEFAULTS[key] then value = nil end
    ns.DB()[key] = value
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

-- Look and parts back to their defaults; factions and hidden skills stay.
function Settings.Reset()
    local language = ns.DB().language
    ForeverDataBarDB = { language = language }
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

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    Settings.Changed(nil)
end)
