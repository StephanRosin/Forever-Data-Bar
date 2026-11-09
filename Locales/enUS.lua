local _, ns = ...

-- English is the base language and always loads first. Every other language
-- (Locales/<code>.lua) fills a table of its own; Locale.lua picks one. ns.L
-- holds no strings itself: it looks a key up in the chosen language, then in
-- English, and a key missing from both comes back as it is, so a missing
-- string shows in the game instead of raising an error.
local L = {}
ns.Locales = { enUS = L }

local active = L
ns.L = setmetatable({}, {
    __index = function(_, key)
        local v = active[key]
        if v == nil then v = L[key] end
        if v == nil then return key end
        return v
    end,
    __newindex = function() error("ns.L is read-only; add strings to Locales/*.lua") end,
})

-- Locale.lua only: shows the given language's table through ns.L.
function ns.SetActiveLocale(code)
    active = ns.Locales[code] or L
end

L.ADDON_NAME = "Forever Data Bar"

-- Chat
L.MSG_NO_SKILL_API = "This client has no skill list: the professions stay empty."

-- Tooltips
L.TIP_RANK = "Rank"
L.TIP_TO_CAP = "To the next cap"
L.TIP_CLICK_OPEN = "Click to open or close the profession"
L.TIP_REP_LEFT = "Left-click: choose a faction"
L.TIP_REP_RIGHT = "Right-click: reputation tab"
L.REP_EMPTY = "(empty)"

-- Minimap button
L.OPEN_OPTIONS = "Open the options"

-- Options window
L.OPT_LANGUAGE = "Language"
L.LANGUAGE_AUTO = "Game language"
L.PAGE_PROFESSIONS = "Professions"
L.PAGE_REPUTATION = "Reputation"

L.OPT_HIDE = "Hide"
L.RANK_APPRENTICE = "Apprentice"
L.RANK_JOURNEYMAN = "Journeyman"
L.RANK_EXPERT = "Expert"
L.RANK_ARTISAN = "Artisan"
L.RANK_MASTER = "Master"
L.PROF_ALCHEMY = "Alchemy"
L.PROF_BLACKSMITHING = "Blacksmithing"
L.PROF_ENCHANTING = "Enchanting"
L.PROF_ENGINEERING = "Engineering"
L.PROF_HERBALISM = "Herbalism"
L.PROF_JEWELCRAFTING = "Jewelcrafting"
L.PROF_LEATHERWORKING = "Leatherworking"
L.PROF_MINING = "Mining"
L.PROF_SKINNING = "Skinning"
L.PROF_TAILORING = "Tailoring"
L.PROF_FIRST_AID = "First Aid"
L.PROF_COOKING = "Cooking"
L.PROF_FISHING = "Fishing"
L.PROF_RIDING = "Riding"
L.STANDING_1 = "Hated"
L.STANDING_2 = "Hostile"
L.STANDING_3 = "Unfriendly"
L.STANDING_4 = "Neutral"
L.STANDING_5 = "Friendly"
L.STANDING_6 = "Honored"
L.STANDING_7 = "Revered"
L.STANDING_8 = "Exalted"
L.TIP_XP = "Experience"
L.TIP_XP_PROGRESS = "Progress"
L.TIP_XP_TO_LEVEL = "To the next level"
L.TIP_XP_RESTED = "Rested"
L.TIP_UNSPENT_TALENTS = "You have unspent talent points"
L.TIP_UNSPENT_TALENTS_CLICK = "Left-click: open talents"
L.MSG_TALENTS_IN_COMBAT = "Talents can't be opened from here in combat. Use the game's talent button."
L.XP_LEVEL = "Level %d"


L.OPT_PROFESSIONS = "Professions and skills"
L.OPT_PROFESSIONS_HINT = "Two primary professions and two secondary skills are shown. Untick a skill to hide it."
L.OPT_NO_SKILLS = "No skills found yet."

L.OPT_REPUTATION = "Reputation"
L.OPT_REP_HINT = "You can also left-click a reputation on the bar to pick its faction."
L.OPT_REP_SLOT = "Slot %d"
L.OPT_REP_RELOAD = "Reload the faction list"




-- XP lines (XpInfo.lua)
L.OPT_XPINFO_PERHOUR = "XP per hour"
L.OPT_XPINFO_TOLEVEL = "Next level in"
L.XPINFO_NONE = "--"
L.DUR_D = "%dd"
L.DUR_H = "%dh"
L.DUR_M = "%dm"
L.DUR_LESS = "< 1m"

-- The data bar theme (DataBar.lua).
L.PAGE_DATABAR = "Look"
L.OPT_DATABAR_DESIGN = "Design"
L.DATABAR_DESIGN_HAIR = "Hairline"
L.DATABAR_DESIGN_SEGMENTS = "Segments"
L.DATABAR_DESIGN_GLASS = "Glass"
L.DATABAR_DESIGN_ICONS = "Icons only"
L.DATABAR_DESIGN_PHIAL = "Alchemy phial"
L.OPT_DATABAR_POS = "Position"
L.DATABAR_POS_TOP = "Top of the screen"
L.DATABAR_POS_BOTTOM = "Bottom of the screen"
L.OPT_DATABAR_HEIGHT = "Height"
L.OPT_DATABAR_ALPHA = "Background opacity"
L.OPT_DATABAR_ACCENT = "Accent colour"
L.OPT_DATABAR_HIDE_COMBAT = "Hide in combat"
L.OPT_DATABAR_HIDE_GROUP = "Hide in a group"
L.DATABAR_XP = "%d%% to level %d"
L.OPT_DATABAR_BG = "Background colour"
L.OPT_DATABAR_EDGE = "Line in the accent colour towards the game"
L.DATABAR_TALENTS = "Talents"
L.PAGE_DATABAR_PARTS = "Parts"
L.DATABAR_PART_XP = "Experience and talents"
L.DATABAR_PART_CLOCK = "Clock"
L.DATABAR_PART_PROFS = "Professions"
L.DATABAR_PART_REPS = "Reputation"
L.OPT_DATABAR_SHOW = "Show"
L.OPT_DATABAR_X = "Offset X"
L.OPT_DATABAR_PROF_COLOURS = "Own colours (professions, standing)"
-- Hated .. Exalted, short, for the data bar.
L.DATABAR_STANDING_1 = "Ha"
L.DATABAR_STANDING_2 = "Hs"
L.DATABAR_STANDING_3 = "U"
L.DATABAR_STANDING_4 = "N"
L.DATABAR_STANDING_5 = "F"
L.DATABAR_STANDING_6 = "H"
L.DATABAR_STANDING_7 = "R"
L.DATABAR_STANDING_8 = "E"
L.DATABAR_ADD_REP = "Add a faction"
L.DATABAR_PART_GOLD = "Gold"
L.DATABAR_PART_DURA = "Durability"
L.DATABAR_PART_BAGS = "Bags"
L.DATABAR_TIP_DURA_WORST = "Lowest: %s"
L.DATABAR_TIP_BAGS_FREE = "%d of %d slots free"
L.DATABAR_TIP_BAGS_SPECIAL = "Special bags: %d free"
L.DATABAR_TIP_BAGS_CLICK = "Left-click: open bags"
L.DATABAR_PERHOUR = "%s XP/h"
L.DATABAR_TOLEVEL = "Level in %s"
L.OPT_DATABAR_GEAR = "Gear for the options at the right edge"
L.DATABAR_TIP_OPTIONS = "Left-click: options"
L.OPT_DATABAR_COLUMN = "Column"
L.DATABAR_COLUMN_1 = "1 (left edge)"
L.DATABAR_COLUMN_2 = "2"
L.DATABAR_COLUMN_3 = "3 (middle)"
L.DATABAR_COLUMN_4 = "4"
L.DATABAR_COLUMN_5 = "5 (right edge)"
L.DATABAR_INFO_LEFT = "Left of the XP"
L.DATABAR_INFO_RIGHT = "Right of the XP"
L.OPT_DATABAR_PARTS_HINT = "Five columns across the bar; parts in one column line up in this order. X shifts a part to the right (negative: left)."
L.OPT_DATABAR_INFO_PLACE = "Beside the XP"
L.OPT_DATABAR_BAR = "Bar"
L.OPT_RESET = "Reset"
L.OPT_RESET_HINT = "Sets the look and the parts back to their defaults. Factions, hidden skills and the language stay."
L.OPT_RESET_BUTTON = "Reset to defaults"
L.PAGE_FONTS = "Font"
L.OPT_FONT_ALL = "All parts"
L.OPT_FONT = "Font"
L.OPT_FONT_SIZE = "Size"
L.OPT_FONT_COLOR = "Text colour"
L.OPT_OUTLINE = "Outline"
L.OUTLINE_NONE = "None"
L.OUTLINE_NORMAL = "Outline"
L.OUTLINE_THICK = "Thick outline"
L.OPT_FONT_HINT = "Values show a little fainter; durability keeps its warning colours, Talents its pulse. The clock is two points larger."
L.OPT_FONT_OWN = "Own font"
