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
    -- Halftone paper in the same grey as every Forever addon's comic,
    -- lettered like the Quest Log's titles: white Bangers, black outline
    -- (dark ink without one read as a smear); values as strong (valueAlpha);
    -- a yellow accent (red was bad on the icons).
    COMIC = {
        font = "Bangers", fontSizeAdd = 2, valueAlpha = 1,
        look = look({ 1, 1, 1 }, { 1, 0.9, 0.1 }, { 0, 0, 0 }, 0, "OUTLINE"),
        art = { back = "ComicBack", tint = { 0.7, 0.7, 0.7, 1 }, rim = { 0.07, 0.07, 0.07, 1 }, rimSize = 3,
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
        art = { back = "PixelBack", rim = { 1, 0.95, 0.91, 1 }, rimSize = 2,
            bar = "PixelBar", track = 4 },
    },
}

-- Keys of ForeverDataBarDB that belong to no theme's set.
local META = { language = true, theme = true, themeSets = true, themeColors = true }

-- Each theme's colours, the same in every Forever addon (none for CLASSIC).
-- The first is the theme as it is. Any other draws the backdrop from the
-- theme's grey texture (<back>Grey), tinted so its mean lands on `back`
-- (vertex colour = back / GREY_MEAN, at most 1), and brings its accent
-- (nil: the theme's own). The comic keeps its paper tint (COMIC_PAINT).
local GREY_MEAN = { WoodBack = 0.800, TechBack = 0.705, ParchmentBack = 0.799, StoneBack = 0.800,
    GlassBack = 0.777, FrostBack = 0.796, PixelBack = 0.800 }
local function colour(id, back, accent) return { id = id, back = back, accent = accent } end
Themes.COLORS = {
    WOOD = {
        colour("OAK"),
        colour("WALNUT", { 0.15, 0.09, 0.06 }),
        colour("BIRCH", { 0.38, 0.32, 0.22 }),
        colour("CHERRY", { 0.3, 0.12, 0.08 }),
        colour("EBONY", { 0.08, 0.07, 0.07 }),
        colour("DRIFTWOOD", { 0.25, 0.24, 0.22 }),
    },
    TECH = {
        colour("CYAN"),
        colour("GREEN", { 0.02, 0.1, 0.05 }, { 0.3, 0.95, 0.45 }),
        colour("AMBER", { 0.1, 0.07, 0.02 }, { 1, 0.75, 0.2 }),
        colour("MAGENTA", { 0.09, 0.03, 0.1 }, { 0.95, 0.4, 0.95 }),
        colour("BLUE", { 0.03, 0.05, 0.13 }, { 0.45, 0.65, 1 }),
        colour("GREY", { 0.07, 0.07, 0.08 }, { 0.85, 0.88, 0.9 }),
    },
    PARCHMENT = {
        colour("CLASSIC"),
        colour("AGED", { 0.32, 0.25, 0.15 }),
        colour("ASH", { 0.33, 0.33, 0.31 }),
        colour("SEA", { 0.25, 0.3, 0.33 }),
        colour("ROSE", { 0.36, 0.27, 0.26 }),
        colour("DARK", { 0.2, 0.17, 0.13 }),
    },
    RUNESTONE = {
        colour("GRANITE"),
        colour("SANDSTONE", { 0.33, 0.27, 0.18 }, { 1, 0.8, 0.35 }),
        colour("SLATE", { 0.15, 0.18, 0.25 }, { 0.55, 0.75, 1 }),
        colour("MOSS", { 0.15, 0.22, 0.14 }, { 0.5, 1, 0.45 }),
        colour("OBSIDIAN", { 0.07, 0.06, 0.09 }, { 0.75, 0.5, 1 }),
    },
    GLASS = {
        colour("CATHEDRAL"),
        colour("BLUE", { 0.08, 0.12, 0.28 }),
        colour("GREEN", { 0.07, 0.2, 0.1 }),
        colour("AMBER", { 0.28, 0.17, 0.05 }),
        colour("VIOLET", { 0.18, 0.08, 0.26 }),
        colour("RUBY", { 0.26, 0.05, 0.08 }),
    },
    FROST = {
        colour("ICE"),
        colour("DEEP", { 0.1, 0.18, 0.32 }, { 0.6, 0.85, 1 }),
        colour("AURORA", { 0.1, 0.27, 0.24 }, { 0.55, 1, 0.8 }),
        colour("VIOLET", { 0.22, 0.18, 0.33 }, { 0.85, 0.75, 1 }),
        colour("SILVER", { 0.3, 0.31, 0.33 }, { 0.92, 0.92, 0.95 }),
        colour("NIGHT", { 0.06, 0.08, 0.14 }, { 0.7, 0.85, 1 }),
    },
    PIXEL = {
        colour("NAVY"),
        colour("PLUM", { 0.23, 0.08, 0.16 }, { 1, 0.93, 0.15 }),
        colour("FOREST", { 0, 0.2, 0.12 }, { 1, 0.93, 0.15 }),
        colour("BROWN", { 0.2, 0.12, 0.08 }, { 1, 0.64, 0 }),
        colour("GREY", { 0.18, 0.17, 0.16 }),
        colour("BLACK", { 0.03, 0.03, 0.04 }, { 0, 0.89, 0.21 }),
        colour("TEAL", { 0.02, 0.17, 0.22 }, { 0.16, 0.68, 1 }),
        colour("PURPLE", { 0.15, 0.1, 0.25 }, { 1, 0.47, 0.66 }),
    },
    COMIC = { colour("GREY"), colour("DARKGREY"), colour("BLACK"), colour("WHITE"), colour("YELLOW"),
        colour("BLUE"), colour("RED"), colour("GREEN"), colour("PURPLE") },
}

-- The comic's colours: the paper's tint and the accent. GREY is the comic as
-- it is (accent nil: the set's own). The bar has no dark ink (white outlined
-- text): dark papers need nothing more.
local COMIC_YELLOW = { 1, 0.9, 0.1 }
local COMIC_PAINT = {
    GREY = { paper = { 0.70, 0.70, 0.70 } },
    DARKGREY = { paper = { 0.38, 0.38, 0.38 }, accent = COMIC_YELLOW },
    BLACK = { paper = { 0.16, 0.16, 0.16 }, accent = COMIC_YELLOW },
    WHITE = { paper = { 1, 1, 1 }, accent = { 0.15, 0.45, 0.95 } },
    YELLOW = { paper = { 0.86, 0.76, 0.36 }, accent = { 0.15, 0.45, 0.95 } },
    BLUE = { paper = { 0.45, 0.60, 0.86 }, accent = COMIC_YELLOW },
    RED = { paper = { 0.86, 0.44, 0.40 }, accent = COMIC_YELLOW },
    GREEN = { paper = { 0.50, 0.76, 0.46 }, accent = COMIC_YELLOW },
    PURPLE = { paper = { 0.70, 0.52, 0.84 }, accent = COMIC_YELLOW },
}

-- Raised whenever SPECS change a look: theme sets made before are made
-- anew from CLASSIC (Themes.Upgrade), so a changed theme shows as it is
-- now. CLASSIC is never touched.
Themes.REVISION = 6

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

local function colourOf(themeId, id)
    for _, c in ipairs(Themes.COLORS[themeId] or {}) do
        if c.id == id then return c end
    end
    return nil
end

-- A theme's colour ids in order (themeId defaults to the current theme;
-- CLASSIC has none).
function Themes.Colors(themeId)
    local list = {}
    for i, c in ipairs(Themes.COLORS[themeId or Themes.Current()] or {}) do list[i] = c.id end
    return list
end

-- A theme's colour chosen; an unknown one stored reads as its first.
function Themes.Color(themeId)
    themeId = themeId or Themes.Current()
    local colours = Themes.COLORS[themeId]
    if not colours then return nil end
    local id = (ns.DB().themeColors or {})[themeId]
    return colourOf(themeId, id) and id or colours[1].id
end

-- The comic's paint in use, or nil under any other theme.
local function comicPaint()
    if Themes.Current() ~= "COMIC" then return nil end
    return COMIC_PAINT[Themes.Color("COMIC")]
end

-- Any other theme's colour in use when it is not the theme's own look.
local function themePaint()
    local c = colourOf(Themes.Current(), Themes.Color())
    return c and c.back and c or nil
end

-- The backdrop's texture: the grey one under a colour.
function Themes.Back(art)
    return themePaint() and art.back .. "Grey" or art.back
end

-- The backdrop's tint: the comic's paper in its colour, or the grey texture
-- tinted to the colour, at the theme's own alpha.
function Themes.Tint(art)
    local paint = comicPaint()
    if paint and art.tint then return { paint.paper[1], paint.paper[2], paint.paper[3], art.tint[4] } end
    local c = themePaint()
    if c then
        local mean = GREY_MEAN[art.back]
        return { math.min(1, c.back[1] / mean), math.min(1, c.back[2] / mean), math.min(1, c.back[3] / mean),
            art.tint and art.tint[4] or 1 }
    end
    return art.tint
end

-- The accent the bar shows: the colour's, else the setting.
function Themes.Accent()
    local paint = comicPaint() or themePaint()
    return paint and paint.accent or Settings.Get("dataBarAccent")
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

-- A theme's colour (themeId defaults to the current theme), stored outside
-- the theme sets; repaints at once under that theme, which restyles the
-- micro menu's secure buttons.
function Themes.SetColor(id, themeId)
    themeId = themeId or Themes.Current()
    if not colourOf(themeId, id) then return nil, "UNKNOWN" end
    local active = themeId == Themes.Current()
    local why = active and refuse()
    if why then return nil, why end
    local db = ns.DB()
    db.themeColors = db.themeColors or {}
    db.themeColors[themeId] = id ~= Themes.COLORS[themeId][1].id and id or nil
    if active then Settings.Changed(nil) end
    return true
end

-- The comic's colour from before every theme had colours, moved once.
function Themes.MigrateComicColor()
    local db = ns.DB()
    if db.comicColor == nil then return end
    db.themeColors = db.themeColors or {}
    if db.themeColors.COMIC == nil then db.themeColors.COMIC = db.comicColor end
    db.comicColor = nil
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
    Colors = function(themeId) return Themes.Colors(themeId) end,
    Color = function(themeId) return Themes.Color(themeId) end,
    SetColor = function(id, themeId) return Themes.SetColor(id, themeId) end,
}

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    Themes.MigrateComicColor()
    Themes.Upgrade()
end)
