local ADDON, ns = ...
local S = ns.Settings.Get

--[[---------------------------------------------------------------------------
ThemeArt.lua -- a theme's art on the bar beyond settings (Themes.lua): the
backdrop tiled across the whole strip under the background colour (which
tints it, so the art frames every part), a rim on the side towards the
game, small ornaments at the strip's corners and a shadow along the rim.
Everything but the soft shadow stays inside the bar's box: windows placed
edge to edge with it in Classic are not covered under a theme. The solid
shadow (comic, pixel) is therefore a stripe inside, next to the rim. Plain textures on the bar, which has no secure children:
they may change any time.
-----------------------------------------------------------------------------]]
local ThemeArt = {}
ns.ThemeArt = ThemeArt

-- Textures and Pitwall's wedge rule come with the embedded LibForeverThemes.
local Lib = LibForeverThemes
-- Ornaments stay in the margin before the first part and after the gear
-- (DataBar CFG.PAD 12), and two fit above each other on a thin bar.
local ORNAMENT_MAX, ORNAMENT_INSET = 10, 1
-- Texture coordinates of a top-left ornament for each corner: mirrored,
-- never rotated.
-- The wedge (Lib.WEDGE_PART of the texture) is drawn as wide as the bar is
-- high; the first part starts Lib.TITLE_GAP past it at mid-height, as the
-- title in every Forever addon.
local MIRROR = { TOPLEFT = { 0, 1, 0, 1 }, TOPRIGHT = { 1, 0, 0, 1 }, BOTTOMLEFT = { 0, 1, 1, 0 },
    BOTTOMRIGHT = { 1, 0, 1, 0 } }

function ThemeArt.Build(frame)
    -- Under the background colour (BACKGROUND 0).
    frame.themeBack = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.themeBack:SetAllPoints(frame)
    frame.themeBack:Hide()
    frame.themeShadow = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    frame.themeShadow:Hide()
    frame.themeRim = frame:CreateTexture(nil, "BORDER", nil, 1)
    frame.themeRim:Hide()
    frame.themeFrame = frame:CreateTexture(nil, "BORDER", nil, 0)
    frame.themeFrame:Hide()
    frame.themeWedge = frame:CreateTexture(nil, "OVERLAY", nil, 6)
    frame.themeWedge:Hide()
    frame.themeOrnaments = {}
    for i = 1, 4 do
        frame.themeOrnaments[i] = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        frame.themeOrnaments[i]:Hide()
    end
end

local function paintBack(back, art)
    if not art.back then
        back:Hide()
        return
    end
    back:SetTexture(Lib.Texture(ns.Themes.Back(art)), "REPEAT", "REPEAT")
    if back.SetHorizTile then
        back:SetHorizTile(true)
        back:SetVertTile(true)
    end
    local tint = ns.Themes.Tint(art) or { 1, 1, 1, 1 }
    back:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
    back:Show()
end

-- Along the inner edge: the rim inside the bar (in from it by `away`: past
-- the frame), the shadow outside it.
local function alongEdge(texture, frame, inner, outside, size, away)
    texture:ClearAllPoints()
    local from = outside and (inner == "BOTTOM" and "TOP" or "BOTTOM") or inner
    local dy = (away or 0) * (inner == "BOTTOM" and 1 or -1)
    texture:SetPoint(from .. "LEFT", frame, inner .. "LEFT", 0, dy)
    texture:SetPoint(from .. "RIGHT", frame, inner .. "RIGHT", 0, dy)
    texture:SetHeight(size)
end

-- A framed theme's material (its frame) along the bar's inner edge, inside
-- the box, repeating at its own size; returns how wide, 0 without.
local function paintFrame(strip, frame, art, inner)
    strip:SetShown(art.frame ~= nil)
    if not art.frame then return 0 end
    alongEdge(strip, frame, inner, false, art.frameSize)
    strip:SetTexture(Lib.Texture(art.frame), "REPEAT", "REPEAT")
    strip:SetHorizTile(true)
    strip:SetVertTile(true)
    strip:SetVertexColor(1, 1, 1, 1)
    return art.frameSize
end

local function paintShadow(shadow, frame, art, inner)
    local size = art.hardShadow or art.shadow
    if not size then
        shadow:Hide()
        return
    end
    if art.hardShadow then
        alongEdge(shadow, frame, inner, false, (art.rimSize or 0) + size)
    else
        alongEdge(shadow, frame, inner, true, size)
    end
    if art.hardShadow or not (shadow.SetGradient and CreateColor) then
        shadow:SetColorTexture(0, 0, 0, art.hardShadow and 1 or art.shadowAlpha)
        shadow:SetVertexColor(1, 1, 1, 1)
    else
        -- Dark at the bar, gone towards the game. VERTICAL runs from the
        -- bottom colour to the top one.
        shadow:SetColorTexture(1, 1, 1, 1)
        local dark, clear = CreateColor(0, 0, 0, art.shadowAlpha), CreateColor(0, 0, 0, 0)
        if inner == "BOTTOM" then shadow:SetGradient("VERTICAL", clear, dark)
        else shadow:SetGradient("VERTICAL", dark, clear) end
    end
    shadow:Show()
end

local function paintOrnaments(pieces, frame, art, inner, height)
    local outer = inner == "BOTTOM" and "TOP" or "BOTTOM"
    local inset = art.ornamentInset or ORNAMENT_INSET
    local size = math.min(ORNAMENT_MAX, math.floor(height / 2) - inset)
    local c = art.ornamentColor or { 1, 1, 1, 1 }
    for i, piece in ipairs(pieces) do
        local corner = art.ornament and art.corners and art.corners[i]
        if corner then
            local point = (corner:find("INNER", 1, true) and inner or outer)
                .. (corner:find("LEFT", 1, true) and "LEFT" or "RIGHT")
            local dx = point:find("LEFT", 1, true) and inset or -inset
            local dy = point:find("TOP", 1, true) and -inset or inset
            piece:ClearAllPoints()
            piece:SetPoint(point, frame, point, dx, dy)
            piece:SetSize(size, size)
            piece:SetTexture(Lib.Texture(art.ornament))
            piece:SetTexCoord(unpack(MIRROR[point]))
            piece:SetVertexColor(c[1], c[2], c[3], c[4])
        end
        piece:SetShown(corner ~= nil)
    end
end

-- Where the first part starts on a bar height high: past the theme's
-- wedge, nil without one.
function ThemeArt.TextStart(height)
    local art = ns.Themes.Spec(S("theme")).art
    if not (art and art.wedge) then return nil end
    return Lib.WedgeReach(height, height / 2) + Lib.TITLE_GAP
end

local function paintWedge(wedge, frame, art, height)
    if art.wedge then
        wedge:ClearAllPoints()
        wedge:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        wedge:SetSize(height, height)
        wedge:SetTexture(Lib.Texture(art.wedge))
        wedge:SetTexCoord(0, Lib.WEDGE_PART, 0, 1)
        local c = ns.Themes.WedgeColor(art)
        wedge:SetVertexColor(c[1], c[2], c[3], c[4])
    end
    wedge:SetShown(art.wedge ~= nil)
end

function ThemeArt.Style(frame, atTop, height)
    local art = ns.Themes.Spec(S("theme")).art or {}
    local inner = atTop and "BOTTOM" or "TOP"
    paintBack(frame.themeBack, art)
    local framed = paintFrame(frame.themeFrame, frame, art, inner)
    if art.rim then
        local rim = ns.Themes.Rim(art)
        alongEdge(frame.themeRim, frame, inner, false, art.rimSize, framed)
        frame.themeRim:SetColorTexture(rim[1], rim[2], rim[3], rim[4])
    end
    frame.themeRim:SetShown(art.rim ~= nil)
    paintShadow(frame.themeShadow, frame, art, inner)
    paintOrnaments(frame.themeOrnaments, frame, art, inner, height)
    paintWedge(frame.themeWedge, frame, art, height)
end

-- -----------------------------------------------------------------------------
-- A window (the gold window): under a theme the bar's backdrop with its
-- background colour over it (one background per theme in every Forever
-- addon), the rim on every side, the title bar's colour and the wedge in it;
-- under Classic the options window's flat look. A framed theme (Goblin)
-- puts its frame around the rim's outside with its ornaments on the
-- frame's corners, and its banner into the title bar (band: { height }, nil
-- height: the bar's).
-- -----------------------------------------------------------------------------
function ThemeArt.BuildWindow(frame, titleBar)
    frame.themeBack = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.themeBack:SetAllPoints(frame)
    frame.bodyFill = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    frame.bodyFill:SetAllPoints(frame)
    frame.rims = {}
    for i = 1, 4 do frame.rims[i] = frame:CreateTexture(nil, "BORDER", nil, 1) end
    titleBar.fill = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBar.fill:SetAllPoints(titleBar)
    titleBar.wedge = titleBar:CreateTexture(nil, "OVERLAY", nil, 6)
    titleBar.banner = titleBar:CreateTexture(nil, "BACKGROUND", nil, 1)
    titleBar.ends = {}
    for i = 1, 2 do titleBar.ends[i] = titleBar:CreateTexture(nil, "BACKGROUND", nil, 1) end
    frame.frames, frame.corners = {}, {}
    for i = 1, 4 do frame.frames[i] = frame:CreateTexture(nil, "OVERLAY", nil, 6) end
    for i = 1, 4 do frame.corners[i] = frame:CreateTexture(nil, "OVERLAY", nil, 7) end
end

-- The frame's four strips around the window's outside, the top and bottom
-- ones across the corners; the ornaments on its outer corners.
local CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local function paintWindowFrame(frame, art)
    local framed = art.frame ~= nil
    for i = 1, 4 do
        frame.frames[i]:SetShown(framed)
        frame.corners[i]:SetShown(framed and art.ornament ~= nil)
    end
    if not framed then return end
    local w = art.windowFrameSize
    local spots = {
        { "TOPLEFT", -w, w, "TOPRIGHT", w, 0 },
        { "BOTTOMLEFT", -w, 0, "BOTTOMRIGHT", w, -w },
        { "TOPLEFT", -w, 0, "BOTTOMLEFT", 0, 0 },
        { "TOPRIGHT", 0, 0, "BOTTOMRIGHT", w, 0 },
    }
    for i, s in ipairs(frame.frames) do
        local p = spots[i]
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", frame, p[1], p[2], p[3])
        s:SetPoint("BOTTOMRIGHT", frame, p[4], p[5], p[6])
        s:SetTexture(Lib.Texture(art.frame), "REPEAT", "REPEAT")
        s:SetHorizTile(true)
        s:SetVertTile(true)
        s:SetVertexColor(1, 1, 1, 1)
    end
    if not art.ornament then return end
    local c = art.ornamentColor or { 1, 1, 1, 1 }
    for i, piece in ipairs(frame.corners) do
        local point = CORNERS[i]
        local dx = point:find("LEFT", 1, true) and -w or w
        local dy = point:find("TOP", 1, true) and w or -w
        piece:ClearAllPoints()
        piece:SetPoint(point, frame, point, dx, dy)
        piece:SetSize(art.windowOrnament, art.windowOrnament)
        piece:SetTexture(Lib.Texture(art.ornament))
        piece:SetTexCoord(unpack(MIRROR[point]))
        piece:SetVertexColor(c[1], c[2], c[3], c[4])
    end
end

-- A banner end's width per height of the band (the file is half as wide as high).
local BANNER_END = 0.5

local function bannerHeight(art, titleBar)
    return art.band and (art.band.height or titleBar:GetHeight()) or 0
end

-- The title's banner: its two ends (the right one mirrored) and between
-- them the banner, stretched or repeated at its own size (bannerTile).
-- SetHeight(0) would draw the file at its own height: no height, no banner.
local function paintBanner(titleBar, art)
    local h = bannerHeight(art, titleBar)
    local shown = art.banner ~= nil and h > 0
    titleBar.banner:SetShown(shown)
    local withEnds = shown and art.bannerEnd ~= nil
    for _, e in ipairs(titleBar.ends) do e:SetShown(withEnds) end
    if not shown then return end
    local w = withEnds and math.floor(h * BANNER_END + 0.5) or 0
    for i, e in ipairs(titleBar.ends) do
        local point = i == 1 and "TOPLEFT" or "TOPRIGHT"
        e:ClearAllPoints()
        e:SetPoint(point, titleBar, point, 0, 0)
        e:SetSize(w, h)
        e:SetTexture(Lib.Texture(art.bannerEnd or art.banner))
        if i == 1 then e:SetTexCoord(0, 1, 0, 1) else e:SetTexCoord(1, 0, 0, 1) end
    end
    local b, tile = titleBar.banner, art.bannerTile == true
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", titleBar, "TOPLEFT", w, 0)
    b:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -w, 0)
    b:SetHeight(h)
    b:SetTexture(Lib.Texture(art.banner), tile and "REPEAT" or nil, tile and "REPEAT" or nil)
    b:SetHorizTile(tile)
    b:SetVertTile(tile)
end

-- Where a window's title starts in a title bar `height` high: past the
-- banner's end or the wedge; nil: the window's own inset.
function ThemeArt.TitleStart(height)
    local art = ns.Themes.Spec(S("theme")).art
    if art and art.band and not art.band.height and art.banner and art.bannerEnd then
        return math.floor(height * BANNER_END + 0.5) + Lib.TITLE_GAP
    end
    return ThemeArt.TextStart(height)
end

local function paintRims(rims, frame, c, size)
    local sides = { { "TOPLEFT", "TOPRIGHT", "SetHeight" }, { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
        { "TOPLEFT", "BOTTOMLEFT", "SetWidth" }, { "TOPRIGHT", "BOTTOMRIGHT", "SetWidth" } }
    for i, side in ipairs(sides) do
        local t = rims[i]
        t:ClearAllPoints()
        t:SetPoint(side[1], frame, side[1], 0, 0)
        t:SetPoint(side[2], frame, side[2], 0, 0)
        t[side[3]](t, size)
        t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    end
end

-- The rim's size, by which a window's title strip sits inside it.
function ThemeArt.WindowRim()
    local art = ns.Themes.Spec(S("theme")).art
    return art and art.rimSize or 1
end

-- Cards on a window: the options' panel under Classic; dark on Swiss and
-- Pitwall's black as in every Forever addon; a light shade elsewhere.
local CARD_SOLID, CARD_SHADE = { 0, 0, 0, 0.85 }, { 0, 0, 0, 0.3 }
function ThemeArt.CardColour()
    local art = ns.Themes.Spec(S("theme")).art
    if not art then return ns.Style.COLORS.panel end
    return art.strip and CARD_SOLID or CARD_SHADE
end

function ThemeArt.StyleWindow(frame, titleBar)
    local art = ns.Themes.Spec(S("theme")).art
    if not art then
        local Style = ns.Style.COLORS
        frame.themeBack:Hide()
        frame.bodyFill:SetColorTexture(unpack(Style.bg))
        paintRims(frame.rims, frame, Style.border, 1)
        titleBar.fill:SetColorTexture(unpack(Style.panel))
        titleBar.fill:Show()
        titleBar.wedge:Hide()
        paintBanner(titleBar, {})
        paintWindowFrame(frame, {})
        return
    end
    paintBack(frame.themeBack, art)
    local bg = S("dataBarBgColor")
    frame.bodyFill:SetColorTexture(bg[1], bg[2], bg[3], S("dataBarAlpha") / 100)
    paintRims(frame.rims, frame, ns.Themes.Rim(art) or { 0, 0, 0, 1 }, ThemeArt.WindowRim())
    if art.strip then titleBar.fill:SetColorTexture(unpack(art.strip)) end
    titleBar.fill:SetShown(art.strip ~= nil)
    paintWedge(titleBar.wedge, titleBar, art, titleBar:GetHeight())
    paintBanner(titleBar, art)
    paintWindowFrame(frame, art)
end
