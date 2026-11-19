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
    for _, font in ipairs(LibForeverThemes.FONTS) do check("font shipped: " .. font.name, exists(font.path), true) end
    for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
        check("theme " .. id .. ": label", ns.L["THEME_" .. id] ~= "THEME_" .. id, true)
        local spec = Themes.SPECS[id]
        check("theme " .. id .. ": spec", spec ~= nil, true)
        local art = spec.art or {}
        for _, file in ipairs({ art.back, art.bar, art.ornament, art.wedge }) do
            check("theme " .. id .. ": " .. file .. " shipped", exists("Libs/LibForeverThemes/Media/Themes/" .. file .. ".tga"), true)
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
    check("wood: values in Friz", S("dataBarFont"), "Friz Quadrata")
    check("wood: the client's outline", S("dataBarFontOutline"), "OUTLINE")
    check("wood: its accent", S("dataBarAccent")[1], Themes.SPECS.WOOD.look.dataBarAccent[1])
    check("wood: classic stored", ForeverDataBarDB.themeSets.CLASSIC.dataBarHeight, 30)
    check("wood: the live set is not stored twice", ForeverDataBarDB.themeSets.WOOD, nil)
    check("wood: the text in Friz", f.xp.text._font[1], ns.Media.FontPath("Friz Quadrata"))
    check("wood: backdrop", f.themeBack:IsShown() and f.themeBack._texture, LibForeverThemes.Texture("WoodBack"))
    check("wood: rim instead of the accent line", f.themeRim:IsShown() and not f.edge:IsShown(), true)
    check("wood: rim in the family's gold", table.concat(f.themeRim._texColor, ","), "0.906,0.702,0.161,1")
    check("wood: four rivets", (function()
        local n = 0
        for _, o in ipairs(f.themeOrnaments) do if o:IsShown() then n = n + 1 end end
        return n
    end)(), 4)
    check("wood: rivets fit the bar", f.themeOrnaments[1]:GetWidth() <= 10, true)
    check("wood: rivet at the screen corner", f.themeOrnaments[1]:GetPoint("TOPLEFT") ~= nil, true)
    check("wood: lines in its texture", f.xp.line.fill._texture, LibForeverThemes.Texture("WoodBar"))
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
    check("reset all: the theme's look stays", S("theme") .. S("dataBarFont"), "WOODFriz Quadrata")
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
    ForeverDataBarDB.themeSets.revision = 9
    Settings.Set("dataBarFont", "Skurri")
    Themes.Upgrade()
    check("upgrade: the theme in use from classic", S("dataBarClockX") .. S("dataBarFont"), "15Friz Quadrata")
    check("upgrade: other themes dropped", ForeverDataBarDB.themeSets.TECH, nil)
    check("upgrade: classic kept", ForeverDataBarDB.themeSets.CLASSIC.dataBarHeight, 30)
    check("upgrade: revision stored", ForeverDataBarDB.themeSets.revision, 10)
    Themes.Switch("CLASSIC")

    -- Body text (all of the bar's): the theme font where it reads, else the
    -- standard font at the player's size.
    local BODY = { WOOD = "Friz Quadrata", TECH = "Space Grotesk", RUNESTONE = "Marcellus", PIXEL = "VT323",
        PARCHMENT = "Friz Quadrata", FROST = "Julius Sans One", GLASS = "Friz Quadrata", COMIC = "Bangers",
        SWISS = "Inter Tight", CONSOLE = "IBM Plex Mono", PITWALL = "Titillium Web SemiBold" }
    for id, font in pairs(BODY) do
        Themes.Switch(id)
        local add = font == "Friz Quadrata" and 0 or (Themes.SPECS[id].fontSizeAdd or 0)
        check("body font " .. id, S("dataBarFont") .. S("dataBarFontSize"), font .. (Settings.DEFAULTS.dataBarFontSize + add))
        -- Light text outlined everywhere, the comic's too (as the Quest Log's
        -- titles); Frost's only shadowed (its template's drop shadow).
        check("outline " .. id, S("dataBarFontOutline"), id == "FROST" and "" or "OUTLINE")
        if id == "FROST" then
            check("frost: drawn without outline", select(3, f.profs[1].value:GetFont()), "")
            check("frost: in a shadowed font object", f.profs[1].value._template, "GameFontHighlightSmall")
        end
        Themes.Switch("CLASSIC")
    end
    Themes.Switch("COMIC")
    check("comic: values at full strength", f.profs[1].value._textColor[4], 1)
    Themes.Switch("CLASSIC")
    check("classic: values fainter again", f.profs[1].value._textColor[4] < 1, true)

    -- Every theme's colours, kept apart from the theme sets.
    local function back() return table.concat({ f.themeBack._vertex[1], f.themeBack._vertex[2], f.themeBack._vertex[3] }, ",") end
    local function alpha() return f.themeBack._vertex[4] end
    local function accent() local c = Themes.Accent(); return table.concat({ c[1], c[2], c[3] }, ",") end
    local function rgb(t) return table.concat({ t[1], t[2], t[3] }, ",") end
    local PATH = LibForeverThemes.Texture("")
    check("colours: none under classic", #registry.Colors(), 0)
    check("colours: classic has no colour", registry.Color(), nil)
    check("colours: comic list", table.concat(registry.Colors("COMIC"), ","), "GREY,DARKGREY,BLACK,WHITE,YELLOW,BLUE,RED,GREEN,PURPLE")
    check("colours: pixel list", table.concat(registry.Colors("PIXEL"), ","), "NAVY,PLUM,FOREST,BROWN,GREY,BLACK,TEAL,PURPLE,HANDHELD")
    for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
        if id ~= "CLASSIC" then
            local art = Themes.SPECS[id].art
            Themes.Switch(id)
            local first = registry.Colors()[1]
            check(id .. ": the first colour by default", registry.Color(), first)
            check(id .. ": default keeps its texture", f.themeBack._texture, PATH .. art.back)
            check(id .. ": default keeps its tint", back() .. "/" .. alpha(), art.tint and rgb(art.tint) .. "/" .. art.tint[4] or "1,1,1/1")
            -- An HD default wears its own accent where it has one.
            check(id .. ": default keeps its accent", accent(),
                rgb(LibForeverThemes.Accent(id, first) or Themes.SPECS[id].look.dataBarAccent))
            for i, colour in ipairs(registry.Colors()) do
                check(id .. " " .. colour .. ": named", ns.L["THEME_COLOR_" .. id .. "_" .. colour] ~= "THEME_COLOR_" .. id .. "_" .. colour, true)
                if LibForeverThemes.COLORS[id][i].back then
                    check(id .. " " .. colour .. ": grey texture shipped", exists("Libs/LibForeverThemes/Media/Themes/" .. art.back .. "Grey.tga"), true)
                end
            end
            Themes.Switch("CLASSIC")
        end
    end
    -- A non-default colour: the grey texture tinted to target / mean, its accent.
    Themes.Switch("PIXEL")
    check("pixel plum: set", registry.SetColor("PLUM"), true)
    check("pixel plum: grey texture", f.themeBack._texture, PATH .. "PixelBackGrey")
    check("pixel plum: tint target / mean", back(), rgb({ 0.23 / 0.8, 0.08 / 0.8, 0.16 / 0.8 }))
    check("pixel plum: accent", accent(), "1,0.93,0.15")
    check("pixel handheld: listed last", registry.Colors()[9], "HANDHELD")
    Themes.SetColor("HANDHELD")
    check("pixel handheld: grey texture tinted", f.themeBack._texture .. back(), PATH .. "PixelBackGrey" .. rgb({ 0.059 / 0.8, 0.122 / 0.8, 0.059 / 0.8 }))
    check("pixel handheld: accent", accent(), "0.784,0.941,0.439")
    check("pixel grey: no accent keeps the theme's", Themes.SetColor("GREY") and accent(), rgb(Themes.SPECS.PIXEL.look.dataBarAccent))
    check("colour: not in the set", Settings.Get("dataBarAccent")[1], Themes.SPECS.PIXEL.look.dataBarAccent[1])
    check("colour: unknown refused", select(2, Themes.SetColor("NOPE")), "UNKNOWN")
    check("colour: another theme's id refused", select(2, Themes.SetColor("OAK")), "UNKNOWN")
    M.state.combat = true
    check("colour: combat refused for the theme in use", select(2, Themes.SetColor("NAVY")), "COMBAT")
    check("colour: another theme's set in combat", Themes.SetColor("DEEP", "FROST"), true)
    M.state.combat = false
    Themes.Switch("FROST")
    check("frost deep: tint clamps and keeps the alpha", back() .. "/" .. alpha(), rgb({ 0.1 / 0.796, 0.18 / 0.796, 0.32 / 0.796 }) .. "/0.85")
    Themes.Switch("PIXEL")
    check("colours: each theme keeps its own", registry.Color() .. "/" .. registry.Color("FROST"), "GREY/DEEP")
    Themes.SetColor("NAVY")
    check("colour back to default: nothing stored", ForeverDataBarDB.themeColors.PIXEL, nil)
    Themes.SetColor("ICE", "FROST")
    -- The flat themes keep their backdrop in every colour.
    Themes.Switch("SWISS")
    local function rim() return rgb(f.themeRim._texColor) end
    check("swiss: one white rule towards the game", f.themeRim:GetHeight() .. "/" .. rim(), "3/0.949,0.949,0.949")
    check("swiss: red accent", accent(), "1,0.176,0.125")
    check("swiss: icons in the red accent", rgb(f.parts.GOLD.icon._vertex) .. " " .. rgb(f.gear.icon._vertex),
        "1,0.176,0.125 1,0.176,0.125")
    check("swiss blue: set", registry.SetColor("BLUE"), true)
    check("swiss blue: backdrop kept", f.themeBack._texture .. back(), PATH .. "SwissBack1,1,1")
    check("swiss blue: accent", accent(), "0.176,0.42,1")
    check("swiss blue: icons follow", rgb(f.parts.GOLD.icon._vertex) .. " " .. rgb(f.gear.icon._vertex),
        "0.176,0.42,1 0.176,0.42,1")
    Themes.SetColor("RED")
    Themes.Switch("CONSOLE")
    check("console: mint line", rim(), "0.306,0.929,0.69")
    check("console: dashed lines", f.xp.line.fill._texture, PATH .. "ConsoleBar")
    Themes.SetColor("AMBER")
    check("console amber: the line follows the accent", rim() .. "/" .. accent(), "1,0.69,0/1,0.69,0")
    check("console amber: backdrop kept", f.themeBack._texture, PATH .. "ConsoleBack")
    Themes.SetColor("MINT")
    Themes.Switch("PITWALL")
    check("pitwall: a carbon line", f.themeRim:IsShown() and f.themeRim:GetHeight(), 1)
    check("pitwall: red wedge at the left end", f.themeWedge:IsShown() and rgb(f.themeWedge._vertex), "0.882,0.024,0")
    local h = f:GetHeight()
    check("pitwall: wedge as high as the bar, as wide as high", f.themeWedge:GetHeight() .. "x" .. f.themeWedge:GetWidth(),
        h .. "x" .. h)
    -- The family rule: the first part starts 8 past the wedge's edge at mid-height.
    local first
    for _, p in ipairs(D.PARTS) do
        local g = f.parts[p.id]
        if not first and g:IsShown() and g.width > 0 and tonumber(S(p.key .. "Column")) == 1 then
            first = g.x - S(p.key .. "X")
        end
    end
    check("pitwall: first part 8 past the wedge", first, math.floor(0.8 * h + 0.5) + 8)
    Themes.SetColor("ORANGE")
    check("pitwall orange: the wedge's colour", rgb(f.themeWedge._vertex), "1,0.541,0")
    check("pitwall orange: accent kept", accent(), rgb(Themes.SPECS.PITWALL.look.dataBarAccent))
    check("pitwall orange: icons follow the wedge", rgb(f.parts.GOLD.icon._vertex) .. " " .. rgb(f.gear.icon._vertex)
        .. " " .. rgb(f.profs[1].icon._vertex), "1,0.541,0 1,0.541,0 1,0.541,0")
    check("pitwall orange: the lines keep the accent", rgb(f.profs[1].line.glow._texColor),
        rgb(Themes.SPECS.PITWALL.look.dataBarAccent))
    Settings.Set("dataBarProfColours", true)
    check("pitwall orange: a profession's own colour kept", rgb(f.profs[1].icon._vertex) ~= "1,0.541,0", true)
    Settings.Set("dataBarProfColours", false)
    Themes.SetColor("RED")
    check("pitwall red: icons in the wedge's red", rgb(f.gear.icon._vertex), "0.882,0.024,0")
    -- Every icon accent readable on its backdrop (back, else the black
    -- bar): at least 3:1, the contrast WCAG asks of icons.
    local function luminance(c)
        local function lin(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
        return 0.2126 * lin(c[1]) + 0.7152 * lin(c[2]) + 0.0722 * lin(c[3])
    end
    for id, colours in pairs(LibForeverThemes.COLORS) do
        for _, c in ipairs(id ~= "COMIC" and colours or {}) do
            local a = c.accent or c.wedge
            if a then
                local ratio = (luminance(a) + 0.05) / (luminance(c.back or { 0, 0, 0 }) + 0.05)
                check(id .. " " .. c.id .. ": icon accent readable", ratio >= 3, true)
            end
        end
    end
    -- Swiss and Pitwall share one black with every Forever addon: the flat
    -- backdrop untinted, the background #0a0a0a, opaque.
    for _, id in ipairs({ "SWISS", "PITWALL" }) do
        Themes.Switch(id)
        check(id .. ": the shared black", f.themeBack._texture .. " " .. back() .. "," .. alpha() .. " "
            .. table.concat(f.bg._texColor, ","), PATH .. "SwissBack 1,1,1,1 0.039,0.039,0.039,1")
    end
    Themes.Switch("CLASSIC")
    check("classic: no wedge", f.themeWedge:IsShown(), false)
    -- The rim is the same in every Forever addon, for every theme and
    -- colour: the theme's own; only Console's colours and Pixel's Handheld
    -- recolour it, never the accent.
    local RINGS = { WOOD = "0.906,0.702,0.161,1", TECH = "0.25,0.88,0.94,0.9", PARCHMENT = "0.29,0.2,0.12,1",
        RUNESTONE = "0.1,0.1,0.12,1", GLASS = "0.07,0.06,0.05,1", COMIC = "0.07,0.07,0.07,1",
        FROST = "0.86,0.96,1,0.8", PIXEL = "1,0.95,0.91,1", SWISS = "0.949,0.949,0.949,1",
        PITWALL = "0.043,0.047,0.055,1", AZEROTH = "0.79,0.635,0.29,1", GOBLIN = "0.23,0.11,0.05,1" }
    local OWN_RING = { CONSOLE = { MINT = "0.306,0.929,0.69,1", AMBER = "1,0.69,0,1", PHOSPHOR = "0.224,1,0.078,1",
        VIOLET = "0.627,0.471,1,1" }, PIXEL = { HANDHELD = "0.784,0.941,0.439,1" } }
    for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
        if id ~= "CLASSIC" then
            Themes.Switch(id)
            local chosen = registry.Color()
            for _, c in ipairs(registry.Colors()) do
                Themes.SetColor(c)
                check("rim " .. id .. " " .. c, f.themeRim:IsShown() and table.concat(f.themeRim._texColor, ","),
                    (OWN_RING[id] or {})[c] or RINGS[LibForeverThemes.BaseTheme(id)])
            end
            Themes.SetColor(chosen)
        end
    end
    -- HD: each theme on its base's part, in every colour its own backdrop, untinted.
    check("HD: offered after the others", table.concat(LibForeverThemes.SpecIds(Themes.SPECS), " ", 13, 19),
        "WOOD_HD TECH_HD PARCHMENT_HD RUNESTONE_HD GLASS_HD COMIC_HD FROST_HD")
    check("framed: after them", table.concat(LibForeverThemes.SpecIds(Themes.SPECS), " ", 20), "AZEROTH GOBLIN")
    check("glass HD: lighter fill to show the glass", Themes.SPECS.GLASS_HD.look.dataBarAlpha .. "/"
        .. Themes.SPECS.GLASS.look.dataBarAlpha, "60/90")
    for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
        local base = LibForeverThemes.BaseTheme(id)
        if base ~= id then
            check(id .. ": its base's bar", Themes.SPECS[id].art.bar, Themes.SPECS[base].art.bar)
            check(id .. ": named after its base", ns.L["THEME_" .. id], ns.L["THEME_" .. base] .. " HD")
            Themes.Switch(id)
            check(id .. ": its base's look", rgb(S("dataBarAccent")), rgb(Themes.SPECS[base].look.dataBarAccent))
            for _, c in ipairs(registry.Colors()) do
                Themes.SetColor(c)
                check(id .. " " .. c .. ": own backdrop", f.themeBack._texture, PATH .. LibForeverThemes.Colour(id, c).texture)
                check(id .. " " .. c .. ": untinted", back(), "1,1,1")
            end
            Themes.SetColor(registry.Colors()[1])
            Themes.Switch("CLASSIC")
        end
    end
    -- The comic as built: paper tint and accent.
    Themes.Switch("COMIC")
    check("comic blue: set", registry.SetColor("BLUE"), true)
    check("comic blue: paper", f.themeBack._texture .. back(), PATH .. "ComicBack0.45,0.6,0.86")
    check("comic blue: accent yellow", accent(), "1,0.9,0.1")
    check("comic yellow: accent blue", Themes.SetColor("YELLOW") and accent(), "0.15,0.45,0.95")
    check("comic black: paper", Themes.SetColor("BLACK") and back(), "0.16,0.16,0.16")
    check("comic black: text stays white", S("dataBarFontColor")[1], 1)
    ForeverDataBarDB.themeColors.COMIC = "NOPE"
    check("colour: unknown stored reads the first", Themes.Color(), "GREY")
    Themes.SetColor("GREY")
    check("comic grey: paper as today", back(), "0.7,0.7,0.7")
    -- The comic colour of before moves into themeColors once.
    ForeverDataBarDB.comicColor = "RED"
    Themes.MigrateComicColor()
    check("migration: comic colour moved", registry.Color("COMIC") .. tostring(ForeverDataBarDB.comicColor), "REDnil")
    ForeverDataBarDB.comicColor = "BLUE"
    Themes.MigrateComicColor()
    check("migration: a colour already set wins", registry.Color("COMIC"), "RED")
    Themes.SetColor("GREY")
    -- The options: one colour list, the current theme's; none under Classic.
    local function colourRow()
        for _, x in ipairs(M.frames) do
            if x.opts and x.label and x.label._text == ns.L.OPT_THEME_COLOR and x:IsShown() ~= false then return x end
        end
    end
    ns.Window.Open("databar")
    local row = colourRow()
    local items = row and row.opts.items() or {}
    check("options: the comic's colours, then HD", #items .. items[1].text, "13" .. ns.L.THEME_COLOR_COMIC_GREY)
    Themes.Switch("WOOD")
    row = colourRow()
    items = row and row.opts.items() or {}
    check("options: wood's colours after the switch, then HD", #items .. items[1].text, "10" .. ns.L.THEME_COLOR_WOOD_OAK)
    Themes.Switch("CLASSIC")
    check("options: no colour under classic", colourRow(), nil)
    -- HD is a colour of its base: one set of settings for both.
    local function themeRow()
        for _, x in ipairs(M.frames) do
            if x.opts and x.label and x.label._text == ns.L.OPT_THEME_CHOICE and x:IsShown() ~= false then return x end
        end
    end
    local texts = {}
    for _, item in ipairs(themeRow().opts.items()) do texts[#texts + 1] = item.value end
    check("hd: not in the theme menu", table.concat(texts, " "):find("_HD") == nil, true)
    themeRow().opts.set("TECH")
    Settings.Set("dataBarClockX", 33)
    items = colourRow().opts.items()
    check("hd: colour menu lists tech's, then HD", #items .. " " .. items[1].text .. " / " .. items[7].text,
        "8 " .. ns.L.THEME_COLOR_TECH_CYAN .. " / HD " .. ns.L.THEME_COLOR_TECH_HD_CARBON)
    colourRow().opts.set(items[8].value)
    check("hd: colour switches to the HD theme", Themes.Current() .. " " .. Themes.Color(), "TECH_HD STEEL")
    check("hd: settings kept", S("dataBarClockX"), 33)
    check("hd: theme menu shows the base", themeRow().opts.get(), "TECH")
    check("hd: colour menu shows HD steel", colourRow().opts.get(), "TECH_HD:STEEL")
    check("hd: no own set stored", ForeverDataBarDB.themeSets.TECH_HD, nil)
    themeRow().opts.set("TECH")
    check("hd: choosing the base shown keeps HD", Themes.Current() .. " " .. Themes.Color(), "TECH_HD STEEL")
    colourRow().opts.set(items[2].value)
    check("hd: back to a plain colour", Themes.Current() .. " " .. Themes.Color() .. " " .. S("dataBarClockX"),
        "TECH GREEN 33")
    Themes.Switch("TECH_HD")
    themeRow().opts.set("PIXEL")
    check("hd: stored under tech", ForeverDataBarDB.themeSets.TECH.dataBarClockX, 33)
    local stored = table.concat(Themes.Stored(), " ")
    check("copy from: tech listed, no HD", stored:find("TECH") ~= nil and stored:find("_HD") == nil, true)
    themeRow().opts.set("TECH")
    check("pixel -> tech: the shared set", S("dataBarClockX") .. " " .. Themes.Current(), "33 TECH")
    Themes.SetColor("CYAN", "TECH")
    Themes.SetColor("CARBON", "TECH_HD")

    -- Sets kept apart before LibForeverThemes 9, merged once per account:
    -- a customised HD set wins, a plain one loses to the base's.
    Themes.Switch("PIXEL")
    local sets = ForeverDataBarDB.themeSets
    sets.TECH_HD = Themes.Seed("TECH_HD", sets.CLASSIC)
    sets.TECH.dataBarClockX = 44
    sets.hdMerged = nil
    Themes.Upgrade()
    check("merge: plain HD set, tech's stays", sets.TECH.dataBarClockX, 44)
    check("merge: HD set gone", sets.TECH_HD, nil)
    check("merge: once only", sets.hdMerged, true)
    sets.TECH_HD = Themes.Seed("TECH_HD", sets.CLASSIC)
    sets.TECH_HD.dataBarClockX = 55
    sets.hdMerged = nil
    Themes.Upgrade()
    check("merge: customised HD set wins", sets.TECH.dataBarClockX, 55)
    -- On the HD theme itself: its live settings win when customised.
    Themes.Switch("TECH")
    ForeverDataBarDB.theme = "TECH_HD"
    Settings.Set("dataBarClockX", 66)
    sets.TECH = Themes.Seed("TECH", sets.CLASSIC)
    sets.TECH.dataBarClockX = 11
    sets.hdMerged = nil
    Themes.Upgrade()
    check("merge: on customised HD, it stays live", S("dataBarClockX") .. " " .. Themes.Current(), "66 TECH_HD")
    check("merge: no stale tech set", sets.TECH, nil)
    -- On a plain HD theme, the base's stored set comes in.
    Themes.Reset()
    sets.TECH = Themes.Seed("TECH", sets.CLASSIC)
    sets.TECH.dataBarClockX = 12
    sets.hdMerged = nil
    Themes.Upgrade()
    check("merge: on plain HD, tech's set comes in", S("dataBarClockX") .. " " .. Themes.Current(), "12 TECH_HD")
    Themes.Switch("CLASSIC")
    ns.Window.Toggle()
    ForeverDataBarDB.themeColors = nil
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
    for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
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
    local update, relaid = D.Update, 0
    D.Update = function() relaid = relaid + 1 end
    M.RunTimers()
    check("refused font: taken on the next try", fs._font[1], ns.Media.FontPath("Marcellus"))
    M.RunTimers()
    -- Measured with the client's font so far (a wide font overlapped its neighbours).
    check("refused font: the bar laid out anew, once", relaid, 1)
    D.Update = update
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


    -- "Apply to all Forever addons": only with another addon listed; puts it on
    -- this theme and colour, skips it when it lacks the theme.
    local allRow
    for _, row in ipairs(ns.Window.PAGES[1].rows()) do
        if row.buttons and row.buttons[1].label == "OPT_THEME_ALL" then allRow = row end
    end
    check("apply all: hidden alone", allRow.visible(), false)
    local pick = Themes.Colors("PIXEL")[2]
    local other, known = { theme = "CLASSIC" }, { CLASSIC = {}, PIXEL = { "NAVY", pick } }
    _G.ForeverThemes.FakeOther = {
        title = "Fake", Current = function() return other.theme end,
        Switch = function(id)
            if not known[id] then return nil, "UNKNOWN" end
            other.theme = id
            return true
        end,
        Colors = function(theme) return known[theme] end,
        SetColor = function(id) other.color = id; return true end,
    }
    check("apply all: shown with another", allRow.visible(), true)
    Themes.Switch("PIXEL")
    Themes.SetColor(pick)
    M.chat = {}
    allRow.buttons[1].onClick()
    check("apply all: theme and colour", other.theme .. " " .. tostring(other.color), "PIXEL " .. pick)
    check("apply all: says how many", (M.chat[1] or ""):find("1 other", 1, true) ~= nil, true)
    Themes.Switch("WOOD")
    check("apply all: unknown theme skipped", Themes.ApplyToAll() .. " " .. other.theme, "0 PIXEL")
    _G.ForeverThemes.FakeOther = nil
    Themes.SetColor(Themes.Colors("PIXEL")[1], "PIXEL")
    Themes.Switch("CLASSIC")
    Settings.Reset()
    ForeverDataBarDB.themeSets = nil

    -- The framed themes (LibForeverThemes 10): their frame along the edge
    -- towards the game, inside the bar, the rim inside it.
    local function file(tex) return tex._texture and tex._texture:match("[^\\]+$") end
    Themes.Switch("AZEROTH")
    check("azeroth: fonts", S("dataBarFont"), "Alegreya")
    check("azeroth: light parchment", file(f.themeBack), "AzerothParchment")
    check("azeroth: walnut frame along the inner edge", f.themeFrame:IsShown() and file(f.themeFrame), "WoodHDWalnut")
    check("azeroth: frame inside the bar, repeating", select(5, f.themeFrame:GetPoint("BOTTOMLEFT")) .. " "
        .. f.themeFrame:GetHeight() .. " " .. tostring(f.themeFrame:GetHorizTile()), "0 3 true")
    check("azeroth: the gold rim inside the frame", select(5, f.themeRim:GetPoint("BOTTOMLEFT")), 3)
    check("azeroth: no corner pieces", f.themeOrnaments[1]:IsShown(), false)
    check("azeroth: dark ink, no outline", S("dataBarFontOutline") .. " " .. tostring(S("dataBarFontColor")[1] < 0.3), " true")
    check("azeroth: values at full strength", f.profs[1].value._textColor[4], 1)
    local amber = Themes.Ink({ 1, 0.82, 0 })
    check("azeroth: yellow warning in dark amber, not olive", amber[1] > amber[2] and amber[1] < 0.6, true)
    check("azeroth: a light colour darkened", Themes.Ink({ 0.3, 1, 0.3 })[2] < 0.5, true)
    check("azeroth: dark already: as it is", table.concat(Themes.Ink({ 0.1, 0.2, 0.1 }), "/"), "0.1/0.2/0.1")
    check("azeroth: own icon colours in ink", Themes.IconColor({ 1, 1, 1 })[1] < 0.5, true)
    Themes.Switch("GOBLIN")
    check("goblin: fonts", S("dataBarFont"), "Rubik Medium")
    check("goblin: copper frame", f.themeFrame:IsShown() and file(f.themeFrame), "GoblinCopper")
    check("goblin: rivets", file(f.themeOrnaments[1]), "Rivet")
    check("goblin: light text, outlined", S("dataBarFontOutline"), "OUTLINE")
    check("goblin: colours as they are", table.concat(Themes.Ink({ 1, 1, 1 }), "/"), "1/1/1")
    Themes.Switch("SWISS")
    check("swiss after them: no frame, the rim at the edge", tostring(f.themeFrame:IsShown()) .. " "
        .. select(5, f.themeRim:GetPoint("BOTTOMLEFT")), "false 0")
    Themes.Switch("CLASSIC")
    check("classic after them: no frame", f.themeFrame:IsShown(), false)
    ForeverDataBarDB.themeSets = nil

    -- The shipped look is Stephan's: his stored Wood and Pitwall sets, less
    -- what comes from his Classic (columns, widths, font size). Fonts by the
    -- file they stand for (his Pitwall stores the older "Titillium Web").
    local function rgb(c) return c and table.concat(c, ",") end
    local STEPHAN = {
        WOOD = { font = "Friz Quadrata", text = "0.96,0.88,0.7", accent = "0.94,0.78,0.55", bg = "0.1,0.06,0.02", alpha = 0 },
        PITWALL = { font = "Titillium Web", text = "0.95,0.95,0.96", accent = "0.13,0.77,0.37", bg = "0.039,0.039,0.039", alpha = 100 },
    }
    for id, want in pairs(STEPHAN) do
        local seed = Themes.Seed(id, {})
        local function get(key) if seed[key] == nil then return Settings.DEFAULTS[key] end return seed[key] end
        check("stephan's " .. id .. ": font", LibForeverThemes.FontName(get("dataBarFont")), LibForeverThemes.FontName(want.font))
        check("stephan's " .. id .. ": look", table.concat({ rgb(get("dataBarFontColor")), rgb(get("dataBarAccent")),
            rgb(get("dataBarBgColor")), get("dataBarAlpha"), get("dataBarFontOutline"), tostring(get("dataBarEdge")) }, " "),
            table.concat({ want.text, want.accent, want.bg, want.alpha, "OUTLINE", "false" }, " "))
    end

    -- A set stored by the current release (revision 10, no seedRevision) stays as it is at load.
    ForeverDataBarDB.themeSets = { revision = 10, CLASSIC = {}, WOOD = { dataBarAlpha = 35 } }
    Themes.Upgrade()
    check("load: a stored set untouched", ForeverDataBarDB.themeSets.WOOD and ForeverDataBarDB.themeSets.WOOD.dataBarAlpha, 35)
    check("load: still marked current", ForeverDataBarDB.themeSets.revision, 10)

    -- The Theme part's switch belongs to no theme: hidden in one, hidden in all.
    ForeverDataBarDB.themeSets = { revision = 10, CLASSIC = {}, WOOD = { dataBarTheme = false } }
    Themes.MigrateThemePart()
    check("theme part: hidden in a stored set stays hidden", S("dataBarTheme"), false)
    check("theme part: gone from the sets", ForeverDataBarDB.themeSets.WOOD.dataBarTheme, nil)
    Settings.Set("dataBarTheme", true)
    Themes.MigrateThemePart()
    check("theme part: shown again stays shown", S("dataBarTheme"), true)
    Settings.Set("dataBarTheme", false)
    Themes.Switch("TECH")
    check("theme part: a switch keeps it hidden", S("dataBarTheme"), false)
    check("theme part: not in the stored set", ForeverDataBarDB.themeSets.CLASSIC.dataBarTheme, nil)
    Themes.Switch("CLASSIC")
    Settings.Set("dataBarTheme", true)
    ForeverDataBarDB.themeSets = nil
end
