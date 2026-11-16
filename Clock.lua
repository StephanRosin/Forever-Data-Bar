local ADDON, ns = ...
local L = ns.L
local S = ns.Settings.Get

--[[---------------------------------------------------------------------------
Clock.lua -- how the clock on the bar looks (setting dataBarClockStyle):
  STANDARD  13:05
  SECONDS   13:05 with :47 smaller and fainter, on the same baseline
  DATE      Mo 16.11. 13:05, the date fainter, written as the language does
  DIAL      a small dial in the accent before the time
  DAYNIGHT  a sun or moon in the accent before the time
  LED       segments in the accent, the unlit ones shining through
  TILES     each digit on a tile with an accent edge
  DAYLINE   the time over a line that fills as the day goes by
The 12-hour clock works in every style (AM/PM after the digits).

The clock's size: the bar's font size plus two, or its own (dataBarClockSizeOwn,
dataBarClockSize). Everything sits in clock.body, which DataBar.lua places
between the micro menu's icons; Clock.Layout says how wide it is.
-----------------------------------------------------------------------------]]
local Clock = {}
ns.Clock = Clock

Clock.STYLES = { "STANDARD", "SECONDS", "DATE", "DIAL", "DAYNIGHT", "LED", "TILES", "DAYLINE" }
local DEFAULT_STYLE = "STANDARD"

local MEDIA = "Interface\\AddOns\\ForeverDataBar\\Media\\"
local PLUS = 2                     -- the clock is this much larger than the bar's font
local SMALL = 3                    -- seconds and AM/PM: this much smaller than the time
local GAP = 4                      -- between the pieces
local ICON = 0.95                  -- dial, sun, moon: of the time's size
local DAY_START, NIGHT_START = 6, 20
local LED_W, LED_GAP, LED_T = 0.5, 0.22, 0.13   -- of the size: digit width, gap, segment thickness
local LED_OFF = 0.15                             -- the unlit segments' alpha
local TILE_W, TILE_GAP = 0.9, 1                  -- of the size; px between tiles
local TILE_EDGE, TILE_FILL = 0.8, 0.85            -- accent edge, dark ground (alpha)
local HAND_HOUR, HAND_MINUTE = 0.24, 0.36        -- of the dial's size
local LINE_H, LINE_DOT, LINE_DIM = 1, 4, 0.3

-- 7 segments: a top, b top right, c bottom right, d bottom, e bottom left, f top left, g middle.
local SEGMENTS = { "a", "b", "c", "d", "e", "f", "g" }
local LIT = { ["0"] = "abcdef", ["1"] = "bc", ["2"] = "abdeg", ["3"] = "abcdg", ["4"] = "bcfg", ["5"] = "acdfg",
    ["6"] = "acdefg", ["7"] = "abc", ["8"] = "abcdefg", ["9"] = "abcdfg", [" "] = "" }

function Clock.Style()
    local s = S("dataBarClockStyle")
    for _, v in ipairs(Clock.STYLES) do if v == s then return s end end
    return DEFAULT_STYLE
end

-- The clock's font size for a bar font of `size`: own or two larger.
function Clock.Plus(size)
    if S("dataBarClockSizeOwn") then return S("dataBarClockSize") - size end
    return PLUS
end
function Clock.Size()
    local size = select(2, ns.DataBar.FontFor("dataBarClock"))
    return size + Clock.Plus(size)
end
local function SmallPlus(size) return Clock.Plus(size) - SMALL end

-- The time in pieces: hours as two characters (a blank before 1..9 on the
-- 12-hour clock), minutes, seconds, AM/PM or nil, and the hour 0..23.
function Clock.Parts(t)
    local h, m, s = tonumber(date("%H", t)), date("%M", t), date("%S", t)
    if not S("dataBarClock12") then return string.format("%02d", h), m, s, nil, h end
    return string.format("%2d", (h + 11) % 12 + 1), m, s, h < 12 and "AM" or "PM", h
end

-- The date as the language writes it (L.CLOCK_DATE: {wd} {d} {m}), with the
-- addon's own weekday names: the game's date() names them in English.
function Clock.DateText(t, format, weekdays)
    local names = {}
    for n in (weekdays or L.GOLD_WEEKDAYS):gmatch("%S+") do names[#names + 1] = n end
    local wd = names[tonumber(date("%w", t)) + 1] or ""
    return ((format or L.CLOCK_DATE):gsub("{(%a+)}", { wd = wd, d = tonumber(date("%d", t)), m = tonumber(date("%m", t)) }))
end

-- The day gone by, 0..1.
function Clock.DayShare(t)
    return (tonumber(date("%H", t)) * 3600 + tonumber(date("%M", t)) * 60 + tonumber(date("%S", t))) / 86400
end

-- -----------------------------------------------------------------------------
-- Building: every style's pieces once, the style shows its own.
-- -----------------------------------------------------------------------------
function Clock.Build(clock, Font)
    local body = CreateFrame("Frame", nil, clock)
    body:SetSize(1, 1)
    clock.body = body
    clock.text:SetParent(body)
    local function text(role, plus)
        local fs = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        Font(fs, "dataBarClock", role, plus)
        return fs
    end
    clock.sec = text("value", SmallPlus)
    clock.date = text("value", Clock.Plus)
    clock.ampm = text("value", SmallPlus)
    clock.icon = body:CreateTexture(nil, "ARTWORK")
    clock.dial = CreateFrame("Frame", nil, body)
    clock.dial.ring = clock.dial:CreateTexture(nil, "ARTWORK")
    clock.dial.ring:SetAllPoints(clock.dial)
    clock.dial.ring:SetTexture(MEDIA .. "GoldRing")
    clock.dial.hour = clock.dial:CreateLine(nil, "OVERLAY")
    clock.dial.minute = clock.dial:CreateLine(nil, "OVERLAY")
    clock.digits = {}
    for i = 1, 4 do
        local d = { segments = {} }
        for _, k in ipairs(SEGMENTS) do d.segments[k] = body:CreateTexture(nil, "ARTWORK") end
        d.edge = body:CreateTexture(nil, "BACKGROUND", nil, 1)
        d.fill = body:CreateTexture(nil, "BACKGROUND", nil, 2)
        d.text = text("text", Clock.Plus)
        clock.digits[i] = d
    end
    clock.colon = { body:CreateTexture(nil, "ARTWORK"), body:CreateTexture(nil, "ARTWORK") }
    clock.colonText = text("text", Clock.Plus)
    clock.colonText:SetText(":")
    clock.track = body:CreateTexture(nil, "ARTWORK")
    clock.fill = body:CreateTexture(nil, "ARTWORK", nil, 1)
    clock.dot = body:CreateTexture(nil, "OVERLAY")
    clock.dot:SetTexture(MEDIA .. "GoldDot")
end

-- -----------------------------------------------------------------------------
-- Layout: the pieces of the style in use, left to right; the width.
-- -----------------------------------------------------------------------------
local function Width(fs, sample)
    local before = fs:GetText()
    fs:SetText(sample)
    local w = math.ceil(fs:GetStringWidth() or 0)
    fs:SetText(before)
    return w
end

local function Colour(t, c, a) t:SetColorTexture(c[1], c[2], c[3], a or 1) end

-- A segment's place in a digit w x h at x: { left, top, width, height }.
local function SegmentBox(k, w, h, t)
    local half = h / 2
    local boxes = {
        a = { t, 0, w - 2 * t, t }, g = { t, half - t / 2, w - 2 * t, t }, d = { t, h - t, w - 2 * t, t },
        f = { 0, t, t, half - 1.5 * t }, b = { w - t, t, t, half - 1.5 * t },
        e = { 0, half + t / 2, t, half - 1.5 * t }, c = { w - t, half + t / 2, t, half - 1.5 * t },
    }
    return boxes[k]
end

local function HideAll(clock)
    for _, r in ipairs({ clock.sec, clock.date, clock.ampm, clock.icon, clock.dial, clock.colon[1], clock.colon[2],
        clock.colonText, clock.track, clock.fill, clock.dot }) do r:Hide() end
    for _, d in ipairs(clock.digits) do
        for _, s in pairs(d.segments) do s:Hide() end
        d.edge:Hide()
        d.fill:Hide()
        d.text:Hide()
    end
end

local function At(region, body, x, point)
    region:ClearAllPoints()
    region:SetPoint(point or "LEFT", body, "LEFT", x, 0)
end

-- The widest time the setting can show, so the micro menu does not move.
local function WidestTime() return S("dataBarClock12") and "12:00" or "00:00" end

-- Place the style's pieces; returns the body's width. Fonts must be set.
function Clock.Layout(clock)
    local style, size = Clock.Style(), Clock.Size()
    local body, accent = clock.body, ns.Themes.IconColor()
    clock.style = style
    HideAll(clock)
    clock.text:SetShown(style ~= "LED" and style ~= "TILES")
    local x = 0
    if style == "DATE" then
        clock.date:Show()
        local widest = 0
        for n in L.GOLD_WEEKDAYS:gmatch("%S+") do
            widest = math.max(widest, Width(clock.date, (L.CLOCK_DATE:gsub("{(%a+)}", { wd = n, d = 28, m = 12 }))))
        end
        x = widest + 2 * GAP
        -- Right against the time: the room is the widest date's, the gap stays.
        clock.date:ClearAllPoints()
        clock.date:SetPoint("RIGHT", body, "LEFT", widest, 0)
    elseif style == "DIAL" or style == "DAYNIGHT" then
        local icon = math.floor(size * ICON + 0.5)
        local piece = style == "DIAL" and clock.dial or clock.icon
        piece:SetSize(icon, icon)
        At(piece, body, 0)
        piece:Show()
        clock.dial.ring:SetVertexColor(accent[1], accent[2], accent[3], 1)
        clock.icon:SetVertexColor(accent[1], accent[2], accent[3], 1)
        x = icon + GAP
    end

    local ampm = S("dataBarClock12") and Width(clock.ampm, "PM") + GAP / 2 or 0
    if style == "LED" or style == "TILES" then
        local led = style == "LED"
        local w = math.floor(size * (led and LED_W or TILE_W) + 0.5)
        local gap = led and math.max(1, math.floor(size * LED_GAP + 0.5)) or TILE_GAP
        local thick = math.max(1, math.floor(size * LED_T + 0.5))
        local colonW = led and thick + gap or Width(clock.colonText, ":") + 2
        for i, d in ipairs(clock.digits) do
            d.x, d.w, d.h = x, w, size
            if led then
                for _, k in ipairs(SEGMENTS) do
                    local b = SegmentBox(k, w, size, thick)
                    local seg = d.segments[k]
                    seg:ClearAllPoints()
                    seg:SetPoint("TOPLEFT", body, "LEFT", x + b[1], size / 2 - b[2])
                    seg:SetSize(math.max(1, b[3]), math.max(1, b[4]))
                end
            else
                d.edge:ClearAllPoints()
                d.edge:SetPoint("LEFT", body, "LEFT", x, 0)
                d.edge:SetSize(w, size + 4)
                Colour(d.edge, accent, TILE_EDGE)
                d.fill:ClearAllPoints()
                d.fill:SetPoint("CENTER", d.edge, "CENTER", 0, 0)
                d.fill:SetSize(w - 2, size + 2)
                Colour(d.fill, { 0, 0, 0 }, TILE_FILL)
                d.edge:Show()
                d.fill:Show()
                d.text:ClearAllPoints()
                d.text:SetPoint("CENTER", d.edge, "CENTER", 0, 0)
                d.text:Show()
            end
            x = x + w + gap
            if i == 2 then
                if led then
                    for k, c in ipairs(clock.colon) do
                        c:ClearAllPoints()
                        c:SetPoint("CENTER", body, "LEFT", x + thick / 2, (k == 1 and 1 or -1) * size / 4)
                        c:SetSize(thick, thick)
                        Colour(c, accent, 1)
                        c:Show()
                    end
                else
                    At(clock.colonText, body, x)
                    clock.colonText:Show()
                end
                x = x + colonW
            end
        end
        x = x - gap
    else
        At(clock.text, body, x)
        x = x + Width(clock.text, WidestTime())
    end
    if style == "SECONDS" then
        -- On the time's baseline: both by their bottom (a smaller font's descent differs by under a pixel).
        clock.sec:ClearAllPoints()
        clock.sec:SetPoint("BOTTOMLEFT", clock.text, "BOTTOMRIGHT", 1, 0)
        clock.sec:Show()
        x = x + 1 + Width(clock.sec, ":00")
    end
    if ampm > 0 then
        clock.ampm:ClearAllPoints()
        clock.ampm:SetPoint("BOTTOMLEFT", body, "LEFT", x + GAP / 2, -size / 2)
        clock.ampm:Show()
        x = x + ampm
    end
    if style == "DAYLINE" then
        clock.track:ClearAllPoints()
        clock.track:SetPoint("TOPLEFT", body, "LEFT", 0, -size / 2 - 1)
        clock.track:SetSize(x, LINE_H)
        Colour(clock.track, ns.DataBar.TextColour("dataBarClock"), LINE_DIM)
        clock.track:Show()
        Colour(clock.fill, accent, 1)
        clock.fill:SetHeight(LINE_H + 1)
        clock.dot:SetSize(LINE_DOT, LINE_DOT)
        clock.dot:SetVertexColor(accent[1], accent[2], accent[3], 1)
        clock.fill:Show()
        clock.dot:Show()
    end
    clock.bodyWidth = x
    body:SetSize(math.max(1, x), size + 4)
    Clock.Update(clock)
    return x
end

-- -----------------------------------------------------------------------------
-- Every second: the texts, the lit segments, the hands, the line.
-- -----------------------------------------------------------------------------
local function Hand(line, dial, share, length, thickness, c)
    local r = dial:GetWidth() * length
    local a = share * 2 * math.pi
    line:SetThickness(thickness)
    line:SetColorTexture(c[1], c[2], c[3], 1)
    line:SetStartPoint("CENTER", dial, 0, 0)
    line:SetEndPoint("CENTER", dial, math.sin(a) * r, math.cos(a) * r)
end

function Clock.Update(clock, t)
    local style = clock.style or Clock.Style()
    local hh, mm, ss, suffix, hour = Clock.Parts(t)
    clock.text:SetText(hh:gsub("^ ", "") .. ":" .. mm)
    clock.sec:SetText(":" .. ss)
    clock.ampm:SetText(suffix or "")
    if style == "DATE" then clock.date:SetText(Clock.DateText(t)) end
    if style == "DAYNIGHT" then
        clock.icon:SetTexture(MEDIA .. ((hour >= DAY_START and hour < NIGHT_START) and "ClockSun" or "ClockMoon"))
    elseif style == "DIAL" then
        local c = ns.DataBar.TextColour("dataBarClock")
        local m = tonumber(mm)
        Hand(clock.dial.hour, clock.dial, ((hour % 12) + m / 60) / 12, HAND_HOUR, 1.5, c)
        Hand(clock.dial.minute, clock.dial, m / 60, HAND_MINUTE, 1, c)
    elseif style == "LED" or style == "TILES" then
        local chars = hh .. mm
        local accent = ns.Themes.IconColor()
        for i, d in ipairs(clock.digits) do
            local ch = chars:sub(i, i)
            if style == "LED" then
                local lit = LIT[ch] or ""
                for k, seg in pairs(d.segments) do
                    Colour(seg, accent, lit:find(k, 1, true) and 1 or LED_OFF)
                    seg:Show()
                end
            else
                d.text:SetText(ch)
                -- A blank hour digit (1..9 on the 12-hour clock) has no tile.
                d.edge:SetShown(ch ~= " ")
                d.fill:SetShown(ch ~= " ")
            end
        end
    elseif style == "DAYLINE" then
        local x = math.floor((clock.bodyWidth or 0) * Clock.DayShare(t) + 0.5)
        clock.fill:ClearAllPoints()
        clock.fill:SetPoint("LEFT", clock.track, "LEFT", 0, 0)
        clock.fill:SetWidth(math.max(1, x))
        clock.dot:ClearAllPoints()
        clock.dot:SetPoint("CENTER", clock.track, "LEFT", x, 0)
    end
end
