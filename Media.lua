local ADDON, ns = ...

-- Fonts for the level number: the game's own, plus every font another addon
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

local function sharedMedia()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

-- Every font by name, sorted; Blizzard's first.
function Media.FontNames()
    local names, seen = {}, {}
    for _, f in ipairs(Media.BLIZZARD_FONTS) do
        names[#names + 1] = f.name
        seen[f.name] = true
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
    for _, f in ipairs(Media.BLIZZARD_FONTS) do
        if f.name == name then return f.path end
    end
    local lsm = sharedMedia()
    local path = lsm and lsm:Fetch("font", name, true)
    return path or Media.DEFAULT_FONT
end
