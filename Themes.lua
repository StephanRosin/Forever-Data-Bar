local ADDON, ns = ...
local Settings = ns.Settings

--[[---------------------------------------------------------------------------
Themes.lua -- a look for the bar, and a whole set of settings each (beta).

The setting `theme` names the one in use; ForeverDataBarDB holds its
settings. The others wait in ForeverDataBarDB.themeSets, one set per theme.
CLASSIC is the bar as it was before themes: no other theme ever changes it,
so going back to it restores every setting.

A theme chosen the first time starts from the CLASSIC set (columns, widths,
everything the player arranged) with the theme's look on top (SPECS[id]).
Its art beyond settings (backdrop, rim, ornaments, shadow, line texture) is
ThemeArt.lua's. The same themes as Forever Unit Frames', each addon with its
own choice.

Switching restyles the micro menu's secure buttons (Micro.lua), so it is
refused in combat.
-----------------------------------------------------------------------------]]
local Themes = {}
ns.Themes = Themes

Themes.CLASSIC = "CLASSIC"
-- The options' order. Stored by id: a new theme gets a new id.
Themes.IDS = { "CLASSIC", "WOOD", "TECH", "PARCHMENT", "RUNESTONE", "GLASS", "COMIC", "FROST", "PIXEL" }

-- The theme fonts have Latin letters only: on any other client the bar
-- keeps its font.
local LATIN_CLIENTS = { enUS = true, enGB = true, deDE = true, frFR = true, esES = true, esMX = true, itIT = true,
    ptBR = true }

-- look: settings the theme sets (light text with the client's OUTLINE on
-- every backdrop but the comic's light paper, which has dark ink; the
-- background colour tints the backdrop, kept dark enough for about 4.5:1).
-- font: shipped (Media.lua), for display text; bodyFont: for body text where
-- the theme font does not read at small sizes (nil: the theme font).
-- fontSizeAdd: how much larger the theme font must be to read like Friz
-- Quadrata; the standard font keeps the player's size. Every text on the bar
-- is body text (values, names, the clock): it has no headers. art (ThemeArt.lua): back = backdrop in Media/Themes, tint = its
-- colour; rim = the line towards the game and rimSize; ornament on corners
-- (INNER = towards the game, OUTER = at the screen edge); shadow = a soft
-- shadow over the game, hardShadow = a solid one; bar = the lines' texture,
-- track = their thickness (thick enough to show it).
local function look(text, accent, bg, alpha, outline)
    return { dataBarFontOutline = outline or "OUTLINE", dataBarFontColor = text, dataBarAccent = accent,
        dataBarBgColor = bg, dataBarAlpha = alpha, dataBarEdge = false, dataBarDesign = "GLASS" }
end
local ALL = { "OUTERLEFT", "OUTERRIGHT", "INNERLEFT", "INNERRIGHT" }

Themes.SPECS = {
    CLASSIC = {},
    -- Oak boards, a bronze rim, brass rivets.
    WOOD = {
        font = "Cinzel",
        look = look({ 0.96, 0.88, 0.70 }, { 0.94, 0.78, 0.55 }, { 0.1, 0.06, 0.02 }, 30),
        art = { back = "WoodBack", rim = { 0.76, 0.56, 0.33, 1 }, rimSize = 2, ornament = "Rivet", corners = ALL,
            shadow = 6, shadowAlpha = 0.6, bar = "WoodBar", track = 4 },
    },
    -- Dark navy with a faint grid, a thin cyan line.
    TECH = {
        font = "Space Grotesk",
        look = look({ 0.80, 0.97, 1 }, { 0.25, 0.88, 0.94 }, { 0.02, 0.05, 0.08 }, 40),
        art = { back = "TechBack", rim = { 0.25, 0.88, 0.94, 0.9 }, rimSize = 1, bar = "TechBar", track = 3 },
    },
    -- Parchment, a brown ink line, a wax seal.
    PARCHMENT = {
        font = "IM Fell English SC", bodyFont = "Friz Quadrata", fontSizeAdd = 1,
        look = look({ 1, 0.95, 0.82 }, { 0.85, 0.62, 0.30 }, { 0.22, 0.15, 0.07 }, 65),
        art = { back = "ParchmentBack", rim = { 0.29, 0.2, 0.12, 1 }, rimSize = 2, ornament = "Seal",
            corners = { "INNERLEFT" }, shadow = 5, shadowAlpha = 0.45, bar = "ParchmentBar", track = 4 },
    },
    -- Grey granite, a dark chiselled edge, glowing runes.
    RUNESTONE = {
        font = "Marcellus", fontSizeAdd = 1,
        look = look({ 0.86, 0.95, 0.93 }, { 0.35, 0.95, 0.85 }, { 0.04, 0.05, 0.06 }, 45),
        art = { back = "StoneBack", rim = { 0.1, 0.1, 0.12, 1 }, rimSize = 2, ornament = "Rune",
            corners = { "INNERLEFT", "INNERRIGHT" }, ornamentColor = { 0.35, 0.95, 0.85, 1 },
            shadow = 6, shadowAlpha = 0.7, bar = "StoneBar", track = 4 },
    },
    -- A mosaic of coloured glass, dark lead.
    GLASS = {
        font = "Morpheus", bodyFont = "Friz Quadrata", fontSizeAdd = 1,
        look = look({ 1, 0.93, 0.75 }, { 1, 0.75, 0.3 }, { 0.05, 0.04, 0.06 }, 35),
        art = { back = "GlassBack", rim = { 0.07, 0.06, 0.05, 1 }, rimSize = 3, shadow = 6, shadowAlpha = 0.55,
            bar = "GlassBar", track = 4 },
    },
    -- Halftone paper in the same grey as every Forever addon's comic, dark
    -- ink lettering without an outline (an outline smears it into blobs),
    -- values as dark as the rest (valueAlpha), a solid shadow.
    COMIC = {
        font = "Bangers", bodyFont = "Friz Quadrata", fontSizeAdd = 2, valueAlpha = 1,
        look = look({ 0.1, 0.08, 0.06 }, { 0.95, 0.2, 0.15 }, { 0, 0, 0 }, 0, ""),
        art = { back = "ComicBack", tint = { 0.7, 0.7, 0.7, 1 }, rim = { 0.07, 0.07, 0.07, 1 }, rimSize = 3, hardShadow = 4,
            bar = "ComicBar", track = 4 },
    },
    -- Translucent ice with quieter cracks, a pale rim, a long soft shadow.
    FROST = {
        font = "Cormorant SC", bodyFont = "Friz Quadrata", fontSizeAdd = 2,
        look = look({ 0.92, 0.98, 1 }, { 0.6, 0.88, 1 }, { 0.04, 0.12, 0.22 }, 50),
        art = { back = "FrostBack", tint = { 0.6, 0.6, 0.6, 0.75 }, rim = { 0.86, 0.96, 1, 0.8 }, rimSize = 1,
            shadow = 8, shadowAlpha = 0.55, bar = "FrostBar", track = 3 },
    },
    -- Scan lines, a light pixel rim, a solid shadow.
    PIXEL = {
        font = "VT323", fontSizeAdd = 4,
        look = look({ 1, 0.95, 0.91 }, { 0.3, 1, 0.4 }, { 0, 0, 0 }, 0),
        art = { back = "PixelBack", rim = { 1, 0.95, 0.91, 1 }, rimSize = 2, hardShadow = 3,
            bar = "PixelBar", track = 4 },
    },
}

-- Keys of ForeverDataBarDB that belong to no theme's set.
local META = { language = true, theme = true, themeSets = true }

-- Raised whenever SPECS change a look: theme sets made before are made
-- anew from CLASSIC (Themes.Upgrade), so a changed theme shows as it is
-- now. CLASSIC is never touched.
Themes.REVISION = 3

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

function Themes.Current()
    return Settings.Get("theme")
end

function Themes.Spec(id)
    return Themes.SPECS[id] or Themes.SPECS.CLASSIC
end

-- The settings in use, without the keys of no theme.
local function liveSet()
    local set = {}
    for k, v in pairs(ns.DB()) do
        if not META[k] then set[k] = copy(v) end
    end
    return set
end

-- The stored sets; stale ones (an older REVISION) dropped.
local function storedSets()
    local db = ns.DB()
    local sets = db.themeSets or {}
    db.themeSets = sets
    if sets.revision ~= Themes.REVISION then
        for _, id in ipairs(Themes.IDS) do
            if id ~= Themes.CLASSIC then sets[id] = nil end
        end
        sets.revision = Themes.REVISION
    end
    return sets
end

-- A theme's settings: the base set with the theme's look on top. Parts
-- with a font of their own take the theme's font and colour too.
function Themes.Seed(id, base)
    local set = copy(base)
    if id == nil or id == Themes.CLASSIC then return set end
    local spec = Themes.Spec(id)
    local function put(key, value) set[key] = Settings.Stored(key, copy(value)) end
    local function get(key)
        local v = set[key]
        if v == nil then v = Settings.DEFAULTS[key] end
        return v
    end
    for key, value in pairs(spec.look or {}) do put(key, value) end
    -- Every text on the bar is body text.
    local font = LATIN_CLIENTS[GetLocale()] and (spec.bodyFont or spec.font) or nil
    local add = (font and not spec.bodyFont) and spec.fontSizeAdd or 0
    if font then put("dataBarFont", font) end
    put("dataBarFontSize", get("dataBarFontSize") + add)
    for _, key in ipairs(Settings.FONT_PARTS) do
        if get(key .. "FontOwn") then
            if font then put(key .. "Font", font) end
            put(key .. "FontSize", get(key .. "FontSize") + add)
            put(key .. "FontColor", spec.look.dataBarFontColor)
        end
    end
    return set
end

-- The set in ForeverDataBarDB, the rest of it kept; everything restyles.
local function use(set, id)
    local db = ns.DB()
    for k in pairs(db) do
        if not META[k] then db[k] = nil end
    end
    for k, v in pairs(set) do
        if not META[k] then db[k] = copy(v) end
    end
    db.theme = Settings.Stored("theme", id)
    Settings.Changed(nil)
end

local function refuse()
    if InCombatLockdown() then return "COMBAT" end
    return nil
end

-- Moves to theme id: the current settings are kept for the current theme,
-- id's come back (or are made, the first time). true, or nil and why not.
function Themes.Switch(id)
    if not Themes.SPECS[id] then return nil, "UNKNOWN" end
    local why = refuse()
    if why then return nil, why end
    local current = Themes.Current()
    if id == current then return true end
    local sets = storedSets()
    sets[current] = liveSet()
    local nextSet = sets[id]
    if not nextSet then
        -- CLASSIC is never made from a theme: without a stored one the
        -- settings stay as they are.
        local base = sets[Themes.CLASSIC] or liveSet()
        nextSet = Themes.Seed(id, base)
    end
    -- The live set is ForeverDataBarDB: no stale copy stays behind.
    sets[id] = nil
    use(nextSet, id)
    return true
end

-- The current theme made anew from CLASSIC. Not for CLASSIC itself.
function Themes.Reset()
    local id = Themes.Current()
    if id == Themes.CLASSIC then return nil, "CLASSIC" end
    local why = refuse()
    if why then return nil, why end
    local base = storedSets()[Themes.CLASSIC]
    if not base then return nil, "NO_CLASSIC" end
    use(Themes.Seed(id, base), id)
    return true
end

-- The themes with stored settings to copy from, in IDS order.
function Themes.Stored()
    local sets, list = storedSets(), {}
    for _, id in ipairs(Themes.IDS) do
        if sets[id] and id ~= Themes.Current() then list[#list + 1] = id end
    end
    return list
end

-- Every setting that places something: the bar's edge, each part's column
-- and shift, the side of the XP's extra texts.
function Themes.PlacementKeys()
    local keys = { "dataBarPos" }
    for _, part in ipairs(ns.DataBar.PARTS) do
        keys[#keys + 1] = part.key .. "Column"
        keys[#keys + 1] = part.key .. "X"
    end
    for _, info in ipairs(ns.DataBar.XP_INFOS) do keys[#keys + 1] = info.key .. "Place" end
    return keys
end

-- The positions of theme `from` taken over into the current one. Returns
-- what it replaced (Themes.Restore puts it back), or nil and why not.
function Themes.CopyPlacement(from)
    local why = refuse()
    if why then return nil, why end
    local source = storedSets()[from]
    if not source or from == Themes.Current() then return nil, "GONE" end
    local db, undo = ns.DB(), {}
    for i, key in ipairs(Themes.PlacementKeys()) do
        undo[i] = { key, copy(db[key]) }
        db[key] = copy(source[key])
    end
    Settings.Changed(nil)
    return undo
end

function Themes.Restore(undo)
    if refuse() then return nil end
    local db = ns.DB()
    for _, saved in ipairs(undo) do db[saved[1]] = saved[2] end
    Settings.Changed(nil)
    return true
end

-- At load, before the bar exists: a theme in use made under an older
-- REVISION is made anew from CLASSIC, quietly (the bar is built later).
function Themes.Upgrade()
    local db = ns.DB()
    if not db.themeSets or db.themeSets.revision == Themes.REVISION then return end
    local base = db.themeSets[Themes.CLASSIC]
    storedSets()
    local current = Themes.Current()
    if current == Themes.CLASSIC or not base then return end
    local fresh = Themes.Seed(current, base)
    for k in pairs(db) do
        if not META[k] then db[k] = nil end
    end
    for k, v in pairs(fresh) do db[k] = v end
end

-- A central theme picker in another addon switches through this, as the
-- options do.
_G.ForeverThemes = _G.ForeverThemes or {}
_G.ForeverThemes[ADDON] = {
    title = "Forever Data Bar",
    Current = function() return Themes.Current() end,
    Switch = function(id) return Themes.Switch(id) end,
}

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    Themes.Upgrade()
end)
