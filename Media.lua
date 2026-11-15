local ADDON, ns = ...

-- Fonts for the bar: the game's own, the themes', plus every font another addon
-- registers with LibSharedMedia (the library itself is not shipped).
local Media = {}
ns.Media = Media

Media.BLIZZARD_FONTS = {
    { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow",  path = "Fonts\\ARIALN.TTF" },
    { name = "Skurri",        path = "Fonts\\SKURRI.TTF" },
    { name = "Morpheus",      path = "Fonts\\MORPHEUS.TTF" },
}
Media.DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"

-- The themes' fonts (Themes.lua), shipped in Media/Fonts (OFL, see
-- FONTS.txt); Latin letters only.
local FONTS = "Interface\\AddOns\\ForeverDataBar\\Media\\Fonts\\"
Media.OWN_FONTS = {
    { name = "Bangers",            path = FONTS .. "Bangers-Regular.ttf" },
    { name = "Cinzel",             path = FONTS .. "Cinzel-Bold.ttf" },
    { name = "IBM Plex Mono",      path = FONTS .. "IBMPlexMono-Regular.ttf" },
    { name = "IM Fell English SC", path = FONTS .. "IMFeENsc28P.ttf" },
    { name = "Inter Tight",        path = FONTS .. "InterTight-Regular.ttf" },
    { name = "Marcellus",          path = FONTS .. "Marcellus-Regular.ttf" },
    { name = "Space Grotesk",      path = FONTS .. "SpaceGrotesk-Bold.ttf" },
    { name = "Titillium Web",      path = FONTS .. "TitilliumWeb-SemiBold.ttf" },
    { name = "VT323",              path = FONTS .. "VT323-Regular.ttf" },
}

-- Loaded while the addon loads: a font file used the first time can be
-- refused (DataBar.lua tries again), so the first restyle should not be its
-- first use.
do
    local holder = CreateFrame("Frame")
    holder:Hide()
    for _, f in ipairs(Media.OWN_FONTS) do holder:CreateFontString():SetFont(f.path, 12, "") end
end

local function sharedMedia()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

-- Every font by name, sorted; Blizzard's first, then ours.
function Media.FontNames()
    local names, seen = {}, {}
    for _, list in ipairs({ Media.BLIZZARD_FONTS, Media.OWN_FONTS }) do
        for _, f in ipairs(list) do
            names[#names + 1] = f.name
            seen[f.name] = true
        end
    end
    local lsm = sharedMedia()
    if lsm then
        local extra = {}
        for _, name in ipairs(lsm:List("font") or {}) do
            if not seen[name] then extra[#extra + 1] = name end
        end
        table.sort(extra)
        for _, name in ipairs(extra) do names[#names + 1] = name end
    end
    return names
end

-- The file for a font name; unknown names get Friz Quadrata.
function Media.FontPath(name)
    for _, list in ipairs({ Media.BLIZZARD_FONTS, Media.OWN_FONTS }) do
        for _, f in ipairs(list) do
            if f.name == name then return f.path end
        end
    end
    local lsm = sharedMedia()
    local path = lsm and lsm:Fetch("font", name, true)
    return path or Media.DEFAULT_FONT
end
