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

local PATH = "Interface\\AddOns\\ForeverDataBar\\Media\\Themes\\"
-- Ornaments stay in the margin before the first part and after the gear
-- (DataBar CFG.PAD 12), and two fit above each other on a thin bar.
local ORNAMENT_MAX, ORNAMENT_INSET = 10, 1
-- Texture coordinates of a top-left ornament for each corner: mirrored,
-- never rotated.
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
    back:SetTexture(PATH .. art.back, "REPEAT", "REPEAT")
    if back.SetHorizTile then
        back:SetHorizTile(true)
        back:SetVertTile(true)
    end
    local tint = art.tint or { 1, 1, 1, 1 }
    back:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
    back:Show()
end

-- Along the inner edge: the rim inside the bar, the shadow outside it.
local function alongEdge(texture, frame, inner, outside, size)
    texture:ClearAllPoints()
    local from = outside and (inner == "BOTTOM" and "TOP" or "BOTTOM") or inner
    texture:SetPoint(from .. "LEFT", frame, inner .. "LEFT", 0, 0)
    texture:SetPoint(from .. "RIGHT", frame, inner .. "RIGHT", 0, 0)
    texture:SetHeight(size)
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
            piece:SetTexture(PATH .. art.ornament)
            piece:SetTexCoord(unpack(MIRROR[point]))
            piece:SetVertexColor(c[1], c[2], c[3], c[4])
        end
        piece:SetShown(corner ~= nil)
    end
end

function ThemeArt.Style(frame, atTop, height)
    local art = ns.Themes.Spec(S("theme")).art or {}
    local inner = atTop and "BOTTOM" or "TOP"
    paintBack(frame.themeBack, art)
    if art.rim then
        alongEdge(frame.themeRim, frame, inner, false, art.rimSize)
        frame.themeRim:SetColorTexture(art.rim[1], art.rim[2], art.rim[3], art.rim[4])
    end
    frame.themeRim:SetShown(art.rim ~= nil)
    paintShadow(frame.themeShadow, frame, art, inner)
    paintOrnaments(frame.themeOrnaments, frame, art, inner, height)
end
