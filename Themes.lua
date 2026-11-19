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

local Lib = LibForeverThemes
Themes.CLASSIC = Lib.CLASSIC

-- Each theme's identity (backdrop, tint, ornament, wedge, rim colour,
-- fonts) is LibForeverThemes'; here only the bar's part on top.
-- look: settings the theme sets (light text with the client's OUTLINE on
-- every backdrop but the comic's light paper, which has dark ink; the
-- background colour tints the backdrop, kept dark enough for about 4.5:1).
-- font: for display text (the gold window's title); bodyFont: for body
-- text where the theme font does not read at small sizes (false: the theme
-- font). fontSizeAdd: how much larger the theme font must be to read like
-- Friz Quadrata; the standard font keeps the player's size. Every text on
-- the bar is body text (values, names, the clock): it has no headers.
-- art (ThemeArt.lua), the library's back, tint, ornament, ornamentColor,
-- wedge and strip (a window's title bar colour) with: rim = the line
-- towards the game (the library's ring colour) and rimSize; corners =
-- which ornaments (INNER = towards the game, OUTER = at the screen edge);
-- shadow = a soft shadow over the game, hardShadow = a solid one; bar =
-- the lines' texture, track = their thickness (thick enough to show it).
-- The icons take the colour's accent, on Pitwall the wedge's
-- (Themes.IconColor).
local function look(text, accent, bg, alpha, outline)
    return { dataBarFontOutline = outline or "OUTLINE", dataBarFontColor = text, dataBarAccent = accent,
        dataBarBgColor = bg, dataBarAlpha = alpha, dataBarEdge = false, dataBarDesign = "GLASS" }
end
local ALL = { "OUTERLEFT", "OUTERRIGHT", "INNERLEFT", "INNERRIGHT" }

Themes.SPECS = Lib.Specs({
    -- Oak boards, a rim in the family's gold (the GOLD ring elsewhere), brass rivets.
    WOOD = {
        look = look({ 0.96, 0.88, 0.70 }, { 0.94, 0.78, 0.55 }, { 0.1, 0.06, 0.02 }, 0),
        art = { rimSize = 2, corners = ALL, shadow = 6, shadowAlpha = 0.6, bar = "WoodBar", track = 4 },
    },
    -- Dark navy with a faint grid, a thin cyan line.
    TECH = {
        look = look({ 0.80, 0.97, 1 }, { 0.25, 0.88, 0.94 }, { 0.02, 0.05, 0.08 }, 0),
        art = { rimSize = 1, bar = "TechBar", track = 3 },
    },
    -- Parchment, a brown ink line, a wax seal.
    PARCHMENT = {
        look = look({ 1, 0.95, 0.82 }, { 0.85, 0.62, 0.30 }, { 0.22, 0.15, 0.07 }, 0),
        art = { rimSize = 2, corners = { "INNERLEFT" }, shadow = 5, shadowAlpha = 0.45, bar = "ParchmentBar", track = 4 },
    },
    -- Grey granite, a dark chiselled edge, glowing runes.
    RUNESTONE = {
        look = look({ 0.86, 0.95, 0.93 }, { 0.35, 0.95, 0.85 }, { 0.04, 0.05, 0.06 }, 0),
        art = { rimSize = 2, corners = { "INNERLEFT", "INNERRIGHT" }, shadow = 6, shadowAlpha = 0.7,
            bar = "StoneBar", track = 4 },
    },
    -- A mosaic of coloured glass, dark lead.
    GLASS = {
        look = look({ 1, 0.93, 0.75 }, { 1, 0.75, 0.3 }, { 0.05, 0.04, 0.06 }, 90),
        art = { rimSize = 3, shadow = 6, shadowAlpha = 0.55, bar = "GlassBar", track = 4 },
    },
    -- Halftone paper in the same grey as every Forever addon's comic,
    -- lettered like the Quest Log's titles: white Bangers, black outline
    -- (dark ink without one read as a smear); values as strong (valueAlpha);
    -- a yellow accent (red was bad on the icons). Bangers on the values too.
    COMIC = {
        bodyFont = false, valueAlpha = 1,
        look = look({ 1, 1, 1 }, { 1, 0.9, 0.1 }, { 0, 0, 0 }, 0, "OUTLINE"),
        art = { rimSize = 3, bar = "ComicBar", track = 4 },
    },
    -- Translucent ice with quieter cracks, a pale rim, a long soft shadow.
    FROST = {
        -- No outline: the texts keep their font object's 1 px drop shadow
        -- (GameFontHighlight*).
        look = look({ 0.92, 0.98, 1 }, { 0.6, 0.88, 1 }, { 0.02, 0.07, 0.15 }, 45, ""),
        art = { rimSize = 1, shadow = 8, shadowAlpha = 0.55, bar = "FrostBar", track = 3 },
    },
    -- Scan lines, a light pixel rim, a solid shadow.
    PIXEL = {
        look = look({ 1, 0.95, 0.91 }, { 0.3, 1, 0.4 }, { 0, 0, 0 }, 0),
        art = { rimSize = 2, bar = "PixelBar", track = 4 },
    },
    -- Swiss style: flat black, one white rule, one red accent. The bar's
    -- texts and the window title in the regular weight; the rim is the rule;
    -- a window's title bar black as Pitwall's.
    SWISS = {
        font = "Inter Tight", bodyFont = false,
        look = look({ 0.95, 0.95, 0.95 }, { 1, 0.176, 0.125 }, { 0.039, 0.039, 0.039 }, 100),
        art = { rim = Lib.THEMES.SWISS.rule, rimSize = 3, bar = "SwissBar", track = 3, strip = { 0, 0, 0, 1 } },
    },
    -- A terminal: near black with faint scan lines, a mint line, dashed
    -- lines; the mono face everywhere, the window title too.
    CONSOLE = {
        font = "IBM Plex Mono", bodyFont = false,
        look = look({ 0.9, 0.91, 0.93 }, { 0.306, 0.929, 0.69 }, { 0.06, 0.06, 0.07 }, 0),
        art = { rimSize = 1, bar = "ConsoleBar", track = 3 },
    },
    -- A timing screen: flat black, a carbon line, a red wedge, LED segments;
    -- the semibold face everywhere, the window title too.
    PITWALL = {
        font = "Titillium Web SemiBold", bodyFont = false,
        look = look({ 0.95, 0.95, 0.96 }, { 0.13, 0.77, 0.37 }, { 0.039, 0.039, 0.039 }, 100),
        art = { rimSize = 1, bar = "PitwallBar", track = 4 },
    },
    -- A window of the game's own world: light parchment, a walnut frame with
    -- a gold ring and corners. Dark ink without an outline on the page (as
    -- the Quest Log's), coloured values darkened (Themes.Ink); a window's
    -- title on the red banner in gold (bannerInk). On the thin bar the frame
    -- is narrower (frameSize) and runs along the edge towards the game only.
    AZEROTH = {
        -- Alegreya ran too thin at bar size (Stephan: hard to read): Friz in near-black ink.
        bodyFont = "Friz Quadrata", valueAlpha = 1, ink = true, bannerInk = { 1, 0.82, 0 },
        look = look({ 0.12, 0.07, 0.03 }, { 0.6, 0.12, 0.08 }, { 0, 0, 0 }, 0, ""),
        art = { rimSize = 1, frameSize = 3, windowFrameSize = 7, corners = ALL, shadow = 6, shadowAlpha = 0.5,
            bar = "WoodBar", track = 4, band = {}, windowOrnament = 22 },
    },
    -- A goblin workshop: sooty sheet metal, a copper frame with rivets; on a
    -- window a thin strip of warning stripes along the top of the title
    -- (band: never text on the stripes).
    GOBLIN = {
        -- Bungee runs wide: the gold window's headings smaller to fit their cards.
        displaySizeAdd = -2,
        look = look({ 0.96, 0.92, 0.85 }, { 0.95, 0.76, 0.19 }, { 0, 0, 0 }, 0),
        art = { rimSize = 1, frameSize = 3, windowFrameSize = 7, corners = ALL, shadow = 6, shadowAlpha = 0.6,
            bar = "TechBar", track = 4, band = { height = 5 }, windowOrnament = 11 },
    },
}, true) -- the HD themes too, each from its base theme's part here
-- Glass HD is there to show its glass: the dark fill over it at 60 % (Glass: 90 %).
Themes.SPECS.GLASS_HD.look.dataBarAlpha = 60

-- Keys of ForeverDataBarDB that belong to no theme's set (and survive a reset):
-- the gold records are data, not settings.
-- The Theme part's switch too: hiding it under one theme hides it under all.
local META = { language = true, theme = true, themeSets = true, themeColors = true,
    goldChars = true, goldItems = true, goldWindow = true, dataBarTheme = true }
Themes.META = META

-- The theme colours are the library's (Lib.COLORS, read at use), the same in
-- every Forever addon; which one is chosen is stored account wide, outside
-- the theme sets (themeColors). The bar has no dark ink (white outlined
-- text): the comic's dark papers need nothing more.

-- Raised whenever SPECS change a look: theme sets made before are made
-- anew from CLASSIC (Themes.Upgrade), so a changed theme shows as it is
-- now. CLASSIC is never touched. The library's part counts too: a change
-- there to what seeding copies (fonts, sizes) raises it (Lib.NeedsReseed).
local OWN_REVISION = 10

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

-- A theme's colour ids in order (themeId defaults to the current theme;
-- CLASSIC has none).
function Themes.Colors(themeId)
    return Lib.Colors(themeId or Themes.Current())
end

-- A theme's colour chosen; an unknown one stored reads as its first.
function Themes.Color(themeId)
    themeId = themeId or Themes.Current()
    return Lib.ValidColor(themeId, (ns.DB().themeColors or {})[themeId])
end

-- The backdrop's texture: the grey one under a colour that tints it.
function Themes.Back(art)
    return Lib.Back(art, Themes.Current(), Themes.Color())
end

-- The backdrop's tint: the comic's paper in its colour, or the grey texture
-- tinted to the colour, at the theme's own alpha.
function Themes.Tint(art)
    return Lib.Tint(art, Themes.Current(), Themes.Color())
end

-- The theme's display font for a window title, nil under Classic or on a
-- client the theme fonts cannot write.
function Themes.TitleFont()
    return Lib.LatinClient() and Themes.Spec(Themes.Current()).font or nil
end

-- The accent the bar shows: the colour's, else the setting.
-- On a light paper in ink (Azeroth) the bar's own accent (the banner's red):
-- the colour's gold, meant for the banner's titles, vanished on the parchment.
function Themes.Accent()
    if Themes.Spec(Themes.Current()).ink then return Settings.Get("dataBarAccent") end
    return Lib.Accent(Themes.Current(), Themes.Color()) or Settings.Get("dataBarAccent")
end

-- The rim's and the wedge's colours: the colour's, else the theme's.
function Themes.Rim(art)
    return Lib.Rim(Themes.Current(), Themes.Color()) or art.rim
end

function Themes.WedgeColor(art)
    return Lib.WedgeColor(art, Themes.Current(), Themes.Color())
end

-- The icons' colour: own (an element's own colour: a profession's, a
-- standing's, a maxed one) where it has one, else the colour's accent; on a
-- theme with a wedge (Pitwall) the wedge's, as the colour changes it there.
-- The comic's icons too (the bar has no dark ink: no Lib.IconColor). An own
-- colour in dark ink on a light page (Azeroth).
function Themes.IconColor(own)
    if own then return Themes.Ink(own) end
    local art = Themes.Spec(Themes.Current()).art
    return art and art.wedge and Themes.WedgeColor(art) or Themes.Accent()
end

-- Dark ink on a light page (Azeroth): luminance at most this, about 3:1 on
-- its parchment. Plain darkening turns yellow olive: yellow goes amber first.
local INK_LUMINANCE, AMBER = 0.13, 0.68
local function luminance(r, g, b)
    local function lin(v) return v <= 0.04045 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
end

-- A text colour { r, g, b } (a warning, a gain or loss, a quality) as dark
-- ink on a theme with a light page (ink), else as it is.
function Themes.Ink(c)
    if not Themes.Spec(Themes.Current()).ink then return c end
    local r, g, b = c[1], c[2], c[3]
    if r > 0.8 and g > 0.8 and b < 0.3 then g = r * AMBER end
    local lum = luminance(r, g, b)
    if lum <= INK_LUMINANCE then return { r, g, b } end
    local k = (INK_LUMINANCE / lum) ^ (1 / 2.2)
    return { r * k, g * k, b * k }
end

-- A window title's colour on the theme's banner (Azeroth's gold), nil
-- without one: never ink on the red banner.
function Themes.BannerInk()
    return Themes.Spec(Themes.Current()).bannerInk
end

-- The settings in use, without the keys of no theme.
local function liveSet()
    local set = {}
    for k, v in pairs(ns.DB()) do
        if not META[k] then set[k] = copy(v) end
    end
    return set
end

-- The stored sets; stale ones (an older revision) dropped.
local function storedSets()
    local db = ns.DB()
    local sets = db.themeSets or {}
    db.themeSets = sets
    if Lib.NeedsReseed(sets, OWN_REVISION) then
        for _, id in ipairs(Lib.SpecIds(Themes.SPECS)) do
            if id ~= Themes.CLASSIC then sets[id] = nil end
        end
        Lib.MarkSeeded(sets, OWN_REVISION)
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
    local font = Lib.LatinClient() and (spec.bodyFont or spec.font) or nil
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
    if not Lib.Colour(themeId, id) then return nil, "UNKNOWN" end
    local active = themeId == Themes.Current()
    local why = active and refuse()
    if why then return nil, why end
    local db = ns.DB()
    db.themeColors = db.themeColors or {}
    db.themeColors[themeId] = id ~= Lib.COLORS[themeId][1].id and id or nil
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
    -- A base and its HD theme share their settings: only the look changes.
    if Lib.SetKey(id) == Lib.SetKey(current) then
        ns.DB().theme = id
        Settings.Changed(nil)
        return true
    end
    local sets = storedSets()
    sets[Lib.SetKey(current)] = liveSet()
    local nextSet = sets[Lib.SetKey(id)]
    if not nextSet then
        -- CLASSIC is never made from a theme: without a stored one the
        -- settings stay as they are.
        local base = sets[Themes.CLASSIC] or liveSet()
        nextSet = Themes.Seed(id, base)
    end
    -- The live set is ForeverDataBarDB: no stale copy stays behind.
    sets[Lib.SetKey(id)] = nil
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

-- The themes with stored settings to copy from, in the themes' order.
function Themes.Stored()
    local sets, list = storedSets(), {}
    for _, id in ipairs(Lib.MenuIds(Lib.SpecIds(Themes.SPECS))) do
        if sets[id] and id ~= Lib.SetKey(Themes.Current()) then list[#list + 1] = id end
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

-- Whether two sets hold the same settings; the theme field does not count.
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if k ~= "theme" and not same(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if k ~= "theme" and a[k] == nil then return false end
    end
    return true
end

-- The live settings replaced by set, quietly (the bar is built later).
local function replaceLive(set)
    local db = ns.DB()
    for k in pairs(db) do
        if not META[k] then db[k] = nil end
    end
    for k, v in pairs(set) do
        if not META[k] then db[k] = v end
    end
end

-- At load, before the bar exists: a base and its HD theme, kept apart
-- before LibForeverThemes 9, made one set once per account (a customised
-- HD set wins); then a theme in use made under an older revision is made
-- anew from CLASSIC.
function Themes.Upgrade()
    local db = ns.DB()
    if not db.themeSets then return end
    local sets, current = db.themeSets, Themes.Current()
    local merged = Lib.MergeHD(sets, current, liveSet(), function(hdId, set)
        local classic = sets[Themes.CLASSIC] or (current == Themes.CLASSIC and liveSet())
        return not (classic and same(set, Themes.Seed(hdId, classic)))
    end)
    if merged then replaceLive(merged) end
    if not Lib.NeedsReseed(db.themeSets, OWN_REVISION) then return end
    local base = db.themeSets[Themes.CLASSIC]
    storedSets()
    local current = Themes.Current()
    if current == Themes.CLASSIC or not base then return end
    replaceLive(Themes.Seed(current, base))
end

-- The Theme part's switch was a theme setting before it joined META: hidden
-- under any theme, it stays hidden; the sets' copies go (META keys there
-- are never read).
function Themes.MigrateThemePart()
    local db = ns.DB()
    for _, set in pairs(db.themeSets or {}) do
        if type(set) == "table" then
            if set.dataBarTheme == false then db.dataBarTheme = false end
            set.dataBarTheme = nil
        end
    end
end

-- A central theme picker in another addon switches through this, as the
-- options do.
Lib.Register(ADDON, {
    title = "Forever Data Bar",
    Current = function() return Themes.Current() end,
    Switch = function(id) return Themes.Switch(id) end,
    Colors = function(themeId) return Themes.Colors(themeId) end,
    Color = function(themeId) return Themes.Color(themeId) end,
    SetColor = function(id, themeId) return Themes.SetColor(id, themeId) end,
})

-- "Apply to all Forever addons" (the options' theme rows): the other addons
-- registered above.
function Themes.HasOthers() return #Lib.Others(ADDON) > 0 end

-- Every other addon onto this theme and, where that theme has it, this
-- colour. Returns how many switched.
function Themes.ApplyToAll()
    return Lib.ApplyToAll(ADDON, Themes.Current(), Themes.Color())
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    Themes.MigrateComicColor()
    Themes.MigrateThemePart()
    Themes.Upgrade()
end)
