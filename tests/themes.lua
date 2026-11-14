-- Themes (Themes.lua, ThemeArt.lua): run from run.lua, which passes its
-- helpers. Leaves the bar on Classic without stored theme sets.
return function(ns, M, check, ROOT)
    local Settings, Themes, D = ns.Settings, ns.Themes, ns.DataBar
    local S, f = Settings.Get, D.frame
    local function exists(path)
        local file = io.open(ROOT .. "/" .. path:gsub("\\", "/"):gsub("^Interface/AddOns/ForeverDataBar/", ""), "rb")
        if file then file:close() end
        return file ~= nil
    end

    -- Shipped with the addon.
    for _, font in ipairs(ns.Media.OWN_FONTS) do check("font shipped: " .. font.name, exists(font.path), true) end
    for _, id in ipairs(Themes.IDS) do
        check("theme " .. id .. ": label", ns.L["THEME_" .. id] ~= "THEME_" .. id, true)
        local spec = Themes.SPECS[id]
        check("theme " .. id .. ": spec", spec ~= nil, true)
        local art = spec.art or {}
        for _, file in ipairs({ art.back, art.bar, art.ornament }) do
            check("theme " .. id .. ": " .. file .. " shipped", exists("Media/Themes/" .. file .. ".tga"), true)
        end
        if spec.font then check("theme " .. id .. ": its font known", ns.Media.FontPath(spec.font) ~= ns.Media.DEFAULT_FONT, true) end
    end

    -- The player's own (Classic) bar.
    local registry = _G.ForeverThemes and _G.ForeverThemes.ForeverDataBar
    check("registry entry", registry ~= nil and registry.title, "Forever Data Bar")
    check("starts classic", Themes.Current(), "CLASSIC")
    check("registry: current", registry.Current(), "CLASSIC")
    Settings.Set("dataBarHeight", 30)
    Settings.Set("dataBarClockX", 15)
    Settings.Set("dataBarAccent", { 1, 0, 0 })
    check("nothing stored yet", #Themes.Stored(), 0)

    -- A theme the first time: the classic settings with the theme's look.
    check("switch to wood", Themes.Switch("WOOD"), true)
    check("wood: current", S("theme"), "WOOD")
    check("wood: keeps the height", S("dataBarHeight"), 30)
    check("wood: keeps a position", S("dataBarClockX"), 15)
    check("wood: its font", S("dataBarFont"), "Cinzel")
    check("wood: the client's outline", S("dataBarFontOutline"), "OUTLINE")
    check("wood: its accent", S("dataBarAccent")[1], Themes.SPECS.WOOD.look.dataBarAccent[1])
    check("wood: classic stored", ForeverDataBarDB.themeSets.CLASSIC.dataBarHeight, 30)
    check("wood: the live set is not stored twice", ForeverDataBarDB.themeSets.WOOD, nil)
    check("wood: the text in its font", f.xp.text._font[1], ns.Media.FontPath("Cinzel"))
    check("wood: backdrop", f.themeBack:IsShown() and f.themeBack._texture, D.CFG.MEDIA .. "Themes\\WoodBack")
    check("wood: rim instead of the accent line", f.themeRim:IsShown() and not f.edge:IsShown(), true)
    check("wood: four rivets", (function()
        local n = 0
        for _, o in ipairs(f.themeOrnaments) do if o:IsShown() then n = n + 1 end end
        return n
    end)(), 4)
    check("wood: rivets fit the bar", f.themeOrnaments[1]:GetWidth() <= 10, true)
    check("wood: rivet at the screen corner", f.themeOrnaments[1]:GetPoint("TOPLEFT") ~= nil, true)
    check("wood: lines in its texture", f.xp.line.fill._texture, D.CFG.MEDIA .. "Themes\\WoodBar")
    check("wood: lines thick enough to show it", f.xp.line:GetHeight(), 4)
    check("wood: soft shadow below the bar", f.themeShadow:IsShown() and f.themeShadow._gradient ~= nil, true)

    -- Changes stay with their theme; the registry switches as the options do.
    Settings.Set("dataBarClockX", 50)
    check("registry: switch to pixel", registry.Switch("PIXEL"), true)
    check("registry: reports pixel", registry.Current(), "PIXEL")
    check("pixel: from classic, not from wood", S("dataBarClockX"), 15)
    check("pixel: font larger", S("dataBarFontSize"), Settings.DEFAULTS.dataBarFontSize + 4)
    check("pixel: no solid shadow (stacked edges)", f.themeShadow:IsShown(), false)
    check("pixel: no ornaments", f.themeOrnaments[1]:IsShown(), false)
    check("comic: paper grey as in every addon", Themes.SPECS.COMIC.art.tint[1] .. Themes.SPECS.COMIC.art.tint[4], "0.71")
    check("glass: the mosaic at full brightness", Themes.SPECS.GLASS.art.tint, nil)
    check("tech: no corner brackets", Themes.SPECS.TECH.art.ornament, nil)
    check("pixel: two to copy from", #Themes.Stored(), 2)

    -- Positions from another theme, and back.
    local undo = Themes.CopyPlacement("WOOD")
    check("copy: done", undo ~= nil, true)
    check("copy: position taken", S("dataBarClockX"), 50)
    check("copy: look kept", S("dataBarFont"), "VT323")
    check("copy: sizes are no positions", S("dataBarHeight"), 30)
    check("copy: undo", Themes.Restore(undo), true)
    check("copy: undone", S("dataBarClockX"), 15)

    -- Back to classic: everything as it was.
    check("back to classic", Themes.Switch("CLASSIC"), true)
    check("classic: own accent", S("dataBarAccent")[2], 0)
    check("classic: own font", S("dataBarFont"), "Friz Quadrata")
    check("classic: own position", S("dataBarClockX"), 15)
    check("classic: no theme stored in the db", ForeverDataBarDB.theme, nil)
    check("classic: no backdrop", f.themeBack:IsShown(), false)
    check("classic: no rim, the accent line back", not f.themeRim:IsShown() and f.edge:IsShown(), true)
    check("classic: no shadow", f.themeShadow:IsShown(), false)
    check("classic: plain lines", f.xp.line.fill._texColor ~= nil and f.xp.line:GetHeight(), D.DESIGNS.GLASS.track)
    check("wood again", Themes.Switch("WOOD"), true)
    check("wood again: its own change came back", S("dataBarClockX"), 50)

    -- Reset: the theme anew from classic; the defaults under a theme keep its look.
    check("reset theme", Themes.Reset(), true)
    check("reset theme: from classic", S("dataBarClockX"), 15)
    Settings.Reset()
    check("reset all: the default height", S("dataBarHeight"), Settings.DEFAULTS.dataBarHeight)
    check("reset all: the theme's look stays", S("theme") .. S("dataBarFont"), "WOODCinzel")
    check("reset all: classic untouched", ForeverDataBarDB.themeSets.CLASSIC.dataBarHeight, 30)
    Themes.Switch("CLASSIC")
    check("reset: not classic", select(2, Themes.Reset()), "CLASSIC")

    -- Refused.
    M.state.combat = true
    check("combat", select(2, Themes.Switch("TECH")), "COMBAT")
    check("combat: registry too", select(2, registry.Switch("TECH")), "COMBAT")
    check("combat: no copy", select(2, Themes.CopyPlacement("WOOD")), "COMBAT")
    M.state.combat = false
    check("unknown", select(2, Themes.Switch("NOPE")), "UNKNOWN")
    check("copy from a theme never used", select(2, Themes.CopyPlacement("FROST")), "GONE")

    -- A changed look (REVISION): stored sets are made anew from classic.
    Themes.Switch("TECH")
    Settings.Set("dataBarClockX", 70)
    Themes.Switch("WOOD")
    ForeverDataBarDB.themeSets.revision = Themes.REVISION - 1
    Settings.Set("dataBarFont", "Skurri")
    Themes.Upgrade()
    check("upgrade: the theme in use from classic", S("dataBarClockX") .. S("dataBarFont"), "15Cinzel")
    check("upgrade: other themes dropped", ForeverDataBarDB.themeSets.TECH, nil)
    check("upgrade: classic kept", ForeverDataBarDB.themeSets.CLASSIC.dataBarHeight, 30)
    check("upgrade: revision stored", ForeverDataBarDB.themeSets.revision, Themes.REVISION)
    Themes.Switch("CLASSIC")

    -- Body text (all of the bar's): the theme font where it reads, else the
    -- standard font at the player's size.
    local BODY = { WOOD = "Cinzel", TECH = "Space Grotesk", RUNESTONE = "Marcellus", PIXEL = "VT323",
        PARCHMENT = "Friz Quadrata", FROST = "Friz Quadrata", GLASS = "Friz Quadrata", COMIC = "Bangers" }
    for id, font in pairs(BODY) do
        Themes.Switch(id)
        local add = font == "Friz Quadrata" and 0 or (Themes.SPECS[id].fontSizeAdd or 0)
        check("body font " .. id, S("dataBarFont") .. S("dataBarFontSize"), font .. (Settings.DEFAULTS.dataBarFontSize + add))
        -- Light text outlined everywhere, the comic's too (as the Quest Log's titles).
        check("outline " .. id, S("dataBarFontOutline"), "OUTLINE")
        Themes.Switch("CLASSIC")
    end
    check("revision raised for the new looks", Themes.REVISION, 6)
    Themes.Switch("COMIC")
    check("comic: values at full strength", f.profs[1].value._textColor[4], 1)
    Themes.Switch("CLASSIC")
    check("classic: values fainter again", f.profs[1].value._textColor[4] < 1, true)

    -- The comic's colours: paper and accent, kept apart from the theme sets.
    check("comic colours: registry list", table.concat(registry.ComicColors, ","), "GREY,DARKGREY,BLACK,WHITE,YELLOW,BLUE,RED,GREEN,PURPLE")
    check("comic colours: grey by default", registry.ComicColor(), "GREY")
    Themes.Switch("COMIC")
    local function back() return table.concat({ f.themeBack._vertex[1], f.themeBack._vertex[2], f.themeBack._vertex[3] }, ",") end
    local function accent() local c = Themes.Accent(); return table.concat({ c[1], c[2], c[3] }, ",") end
    check("comic grey: paper as today", back(), "0.7,0.7,0.7")
    check("comic grey: the yellow accent", accent(), "1,0.9,0.1")
    check("comic blue: set", registry.SetComicColor("BLUE"), true)
    check("comic blue: paper", back(), "0.45,0.6,0.86")
    check("comic blue: accent yellow", accent(), "1,0.9,0.1")
    check("comic yellow: set", Themes.SetComicColor("YELLOW"), true)
    check("comic yellow: accent blue", accent(), "0.15,0.45,0.95")
    check("comic colour: not in the set", Settings.Get("dataBarAccent")[1], 1)
    check("comic colour: unknown refused", select(2, Themes.SetComicColor("NOPE")), "UNKNOWN")
    M.state.combat = true
    check("comic colour: combat refused under the comic", select(2, Themes.SetComicColor("RED")), "COMBAT")
    M.state.combat = false
    Themes.Switch("WOOD")
    check("comic colour: nothing under wood", accent(), table.concat(Themes.SPECS.WOOD.look.dataBarAccent, ","))
    check("comic colour: chosen under wood", Themes.SetComicColor("RED"), true)
    Themes.Switch("COMIC")
    check("comic colour: survives the switch", registry.ComicColor() .. back(), "RED0.86,0.44,0.4")
    check("comic black: set", Themes.SetComicColor("BLACK"), true)
    check("comic black: paper", back(), "0.16,0.16,0.16")
    check("comic black: accent yellow", accent(), "1,0.9,0.1")
    check("comic black: text stays white", S("dataBarFontColor")[1], 1)
    check("comic white: set", Themes.SetComicColor("WHITE"), true)
    check("comic white: paper", back(), "1,1,1")
    check("comic white: accent blue", accent(), "0.15,0.45,0.95")
    ForeverDataBarDB.comicColor = "NOPE"
    check("comic colour: unknown stored reads grey", Themes.ComicColor(), "GREY")
    check("comic grey back: set", Themes.SetComicColor("GREY"), true)
    check("comic grey back: paper", back(), "0.7,0.7,0.7")
    check("comic grey back: nothing stored", ForeverDataBarDB.comicColor, nil)
    Themes.Switch("CLASSIC")

    -- The designs stay apart under a theme: thicker, each with its traits.
    Themes.Switch("WOOD")
    local tracks = {}
    for _, id in ipairs({ "HAIR", "GLASS", "SEGMENTS", "ICONS" }) do
        Settings.Set("dataBarDesign", id)
        tracks[#tracks + 1] = D.Design().track
    end
    check("designs under a theme: tracks apart", table.concat(tracks, ","), "3,4,5,4")
    Settings.Set("dataBarDesign", "SEGMENTS")
    check("designs under a theme: segments split", f.xp.line.dividers[1]:IsShown(), true)
    Settings.Set("dataBarDesign", "GLASS")
    check("designs under a theme: glass glows", D.Design().glow, true)
    Settings.Set("dataBarDesign", "HAIR")
    check("designs under a theme: hair fades", D.Design().fade, true)
    Settings.Set("dataBarDesign", nil)
    Themes.Switch("CLASSIC")

    -- Nothing but a soft shadow outside the bar's Classic box.
    local classicHeight = f:GetHeight()
    for _, id in ipairs(Themes.IDS) do
        Themes.Switch(id)
        local art = Themes.SPECS[id].art or {}
        local inside = f:GetHeight() == classicHeight
        if art.hardShadow then inside = inside and f.themeShadow:GetPoint("BOTTOMLEFT") ~= nil end
        for _, o in ipairs(f.themeOrnaments) do
            if o:IsShown() then
                local point, _, _, x, y = o:GetPoint(next(o._points))
                inside = inside and (point:find("LEFT") and x >= 0 or x <= 0) and (point:find("TOP") and y <= 0 or y >= 0)
            end
        end
        check("inside the Classic box: " .. id, inside, true)
    end
    Themes.Switch("CLASSIC")

    -- The theme fonts have Latin letters only.
    M.locale = "koKR"
    Themes.Switch("TECH")
    Themes.Reset()   -- made under enUS above
    check("korean client: the font stays", S("dataBarFont"), "Friz Quadrata")
    check("korean client: the rest of the look", S("dataBarFontOutline"), "OUTLINE")
    check("korean client: the size stays", S("dataBarFontSize"), Settings.DEFAULTS.dataBarFontSize)
    Themes.Switch("CLASSIC")
    M.locale = "enUS"

    -- A refused font: the default meanwhile, tried again.
    Themes.Switch("RUNESTONE")
    local fs, refusals = f.xp.text, 1
    local set = fs.SetFont
    function fs:SetFont(p, s, o)
        if p ~= ns.Media.DEFAULT_FONT and refusals > 0 then refusals = refusals - 1; return false end
        return set(self, p, s, o)
    end
    Settings.Changed(nil)
    check("refused font: the default meanwhile", fs._font[1], ns.Media.DEFAULT_FONT)
    M.RunTimers()
    check("refused font: taken on the next try", fs._font[1], ns.Media.FontPath("Marcellus"))
    fs.SetFont = set

    -- The options: the theme first on the first page.
    Themes.Switch("CLASSIC")
    ns.Window.Open("databar")
    local first
    for _, x in ipairs(M.fontStrings) do
        if x._text == ns.L.OPT_THEME then first = true end
    end
    check("options: theme section", first, true)
    ns.Window.Toggle()

    Settings.Reset()
    ForeverDataBarDB.themeSets = nil
end
