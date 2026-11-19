local ADDON, ns = ...
local L = ns.L

--[[---------------------------------------------------------------------------
GoldWindow.lua -- the gold window, opened by a click on the gold part, in
four tabs:
  Overview: the money with its coins, today and this week as chips, tiles
    for the session, all characters and the best auction item, today's
    money as a bar by source (income above, expenses below), a 7-day
    curve, the three best items.
  History: this character's balance over 7, 30 or 90 days, its change,
    high, low and best day above the curve.
  Income & expenses: per source over the same range (GoldLedger.lua),
    totals as tiles, each source with a bar of its share.
  Items: the auction items with the best realized profit, all characters
    of the realm, all time, each with its icon; hover shows the item's
    tooltip, a modified click links it (chat) as everywhere in the game.

One layout for every theme; the theme gives the backdrop, rim, title strip
and wedge (ThemeArt.StyleWindow), the display font for headings, the text
font and colour for the rest, the card shade, the accent and the icons'
colour (Themes.IconColor), all from the colour chosen for the theme. The
accent draws the curves, the chosen tab and range; gains and losses keep
green and red. A few themes add their own touch to the cards (DECOR):
corner brackets on Tech, a frosted top on Frost, an ink outline and a hard
shadow on Comic (and a burst when today made money), the wedge's colour as
an edge on Pitwall (and a chequered flag at today's point).

Row heights follow the bar's font size. Movable; place, tab and range kept
in ForeverDataBarDB.goldWindow; Escape closes it. A money change refills
the data only, a new look restyles.
-----------------------------------------------------------------------------]]
local Window = {}
ns.GoldWindow = Window

Window.RANGES = { 7, 30, 90 }
Window.TABS = { "OVERVIEW", "HISTORY", "FLOW", "ITEMS" }
local DEFAULT_RANGE, DEFAULT_TAB = 30, "OVERVIEW"
local OVERVIEW_DAYS = 7

local NAME = "ForeverDataBarGold"
local WIDTH, HEIGHT, INSET, GAP = 580, 620, 12, 8
local CONTENT_W = WIDTH - 2 * INSET
local ROW_PAD, TITLE_PAD, TAB_PAD = 6, 12, 10   -- around a text of the font's size
local TITLE_SIZE_ADD, BIG_SIZE_ADD = 3, 9
local UNDERLINE_H, CROSS_SIZE, CROSS_ANGLE = 2, 12, math.pi / 4
local TAB_MIN_W, RANGE_W = 70, 64
local MUTED_ALPHA = 0.6
local SOURCE_ROWS, ITEM_ROWS, OVERVIEW_ITEMS = 8, 12, 3
local ITEM_COLUMNS = { SOLD = 60, BOUGHT = 60, PROFIT = 96 }   -- widths from the right, fixed
local TILES_PER_ROW = 3

-- The pieces' sizes beyond the font.
local CHIP_W, CHIP_ALPHA, CHIP_RIM_ALPHA = 180, 0.16, 0.7
local COINS_ADD = 14                     -- the coin stack: the money's line plus this
local ICON_ALPHA = 0.15                  -- the round ground under a tile's symbol
local BAR_H, OUT_H, LEGEND_BOX = 10, 5, 8
local INCOME_SHADES = { 1, 0.7, 0.48, 0.3, 0.2 }   -- the sources' alpha on the income bar, largest first
local OUTCOME_SHADES = { 1, 0.65, 0.4, 0.25 }
local SHARE_BAR_H, SHARE_ALPHA = 4, 0.55
local MIN_PLOT_H = 60                    -- the curves take the page's height left, at least this
local Y_LABEL_W, X_ROW = 74, 16          -- the chart's value column and date row
local GRID_LINES, GRID_ALPHA = 4, 0.12
local LINE_THICKNESS, AREA_ALPHA = 2, 0.18
local DOT, RING, DOTS_UP_TO = 9, 7, 14   -- rings on every day only on short spans
local DELTA_W, DELTA_SHARE, DELTA_ALPHA, DELTAS_UP_TO = 10, 0.3, 0.4, 31
local FLAG_PAD, FLAG_LIFT = 6, 8
local DARK_ON = 0.6                      -- an accent this bright takes dark text on its flag
local BURST, BURST_INK = 72, 5           -- Comic's burst and its black edge
local BRACKET, BRACKET_T = 10, 2         -- Tech's card corners
local SHEEN_ALPHA, SHADOW_OFF = 0.10, 4  -- Frost's frosted top, Comic's hard shadow
local QUESTION_MARK = 134400             -- fileID of the question mark icon, until an item is known

local MEDIA = "Interface\\AddOns\\ForeverDataBar\\Media\\"
local frame

local function Stored()
    local db = ns.AccountDB()
    db.goldWindow = db.goldWindow or {}
    return db.goldWindow
end

local function Valid(list, v, default)
    for _, x in ipairs(list) do if x == v then return v end end
    return default
end
function Window.Range() return Valid(Window.RANGES, Stored().range, DEFAULT_RANGE) end
function Window.Tab() return Valid(Window.TABS, Stored().tab, DEFAULT_TAB) end

-- -----------------------------------------------------------------------------
-- Texts and their fonts
-- -----------------------------------------------------------------------------
-- role: text (text colour), muted (fainter), head (display font), big,
-- title, value (font only: its colour means gain or loss, a quality), flag
-- (font only and no outline: dark text on a bright accent, an outline blots it).
local texts = {}
local function Register(fs, role)
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    texts[#texts + 1] = { fs = fs, role = role }
    return fs
end

local function Text(parent, role, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetJustifyH(justify or "LEFT")
    return Register(fs, role)
end

local function FontSize() return select(2, ns.DataBar.FontFor("dataBar")) end
local function RowH() return FontSize() + ROW_PAD end
local function TextColour() return select(4, ns.DataBar.FontFor("dataBar")) end

local function Paint(fs, c, a) fs:SetTextColor(c[1], c[2], c[3], a or 1) end

local function ApplyFonts()
    local path, size, outline, colour = ns.DataBar.FontFor("dataBar")
    local display = ns.Themes.TitleFont()
    display = display and ns.Media.FontPath(display) or path
    -- A wide display font (Goblin's Bungee) a point or so smaller: headings stay on their card.
    local d = size + (ns.Themes.Spec(ns.Themes.Current()).displaySizeAdd or 0)
    local fonts = { title = { display, d + TITLE_SIZE_ADD }, head = { display, d }, big = { display, d + BIG_SIZE_ADD } }
    for _, t in ipairs(texts) do
        local f = fonts[t.role] or { path, size }
        ns.DataBar.SetFont(t.fs, f[1], f[2], t.role == "flag" and "" or outline)
        if t.role == "muted" then Paint(t.fs, colour, MUTED_ALPHA)
        elseif t.role ~= "value" and t.role ~= "flag" then Paint(t.fs, colour) end
    end
end

-- -----------------------------------------------------------------------------
-- Theme touches
-- -----------------------------------------------------------------------------
-- The base theme: an HD theme wears its base's touches.
local function ThemeId() return LibForeverThemes.BaseTheme(ns.Themes.Current()) end

local function Colour(t, c, a) t:SetColorTexture(c[1], c[2], c[3], a or c[4] or 1) end

local function Tint(t, c, a) t:SetVertexColor(c[1], c[2], c[3], a or 1) end

-- A vertical fade of colour c from alpha `top` down to `bottom`.
local function Fade(t, c, top, bottom)
    if t.SetGradient and CreateColor then
        t:SetColorTexture(1, 1, 1, 1)
        t:SetGradient("VERTICAL", CreateColor(c[1], c[2], c[3], bottom), CreateColor(c[1], c[2], c[3], top))
    else
        Colour(t, c, (top + bottom) / 2)
    end
end

local function Media(t, name) t:SetTexture(MEDIA .. name) end

-- Each theme's touch on a card: built on every card, shown under its theme.
local DECOR = { TECH = "brackets", FROST = "sheen", COMIC = "ink", PITWALL = "edge" }

-- -----------------------------------------------------------------------------
-- Building blocks
-- -----------------------------------------------------------------------------
-- A tab or range button: fainter until hovered, the chosen one underlined in the accent.
local function SwitchButton(parent, label, onClick)
    local b = CreateFrame("Button", nil, parent)
    b.text = Text(b, "muted", "CENTER")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 1)
    b.text:SetText(label)
    b.underline = b:CreateTexture(nil, "ARTWORK")
    b.underline:SetHeight(UNDERLINE_H)
    b.underline:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 4, 0)
    b.underline:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 0)
    b:SetScript("OnEnter", function(self) Paint(self.text, TextColour()) end)
    b:SetScript("OnLeave", function(self) Paint(self.text, TextColour(), self.chosen and 1 or MUTED_ALPHA) end)
    b:SetScript("OnClick", onClick)
    return b
end

local function PaintSwitch(b, chosen)
    b.chosen = chosen
    Paint(b.text, TextColour(), chosen and 1 or MUTED_ALPHA)
    Colour(b.underline, ns.Themes.Accent(), 1)
    b.underline:SetShown(chosen)
end

-- A card: the theme's card shade with every theme's touch ready (Card.Style picks one).
local function Card(parent)
    local c = CreateFrame("Frame", nil, parent)
    c.shadow = c:CreateTexture(nil, "BACKGROUND", nil, -2)
    c.shadow:SetPoint("TOPLEFT", c, "TOPLEFT", SHADOW_OFF, -SHADOW_OFF)
    c.shadow:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", SHADOW_OFF, -SHADOW_OFF)
    c.fill = c:CreateTexture(nil, "BACKGROUND", nil, -1)
    c.fill:SetAllPoints(c)
    c.sheen = c:CreateTexture(nil, "BACKGROUND", nil, 0)
    c.sheen:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    c.sheen:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, 0)
    c.edge = c:CreateTexture(nil, "BORDER")
    c.edge:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    c.edge:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
    c.ink, c.brackets = {}, {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = c:CreateTexture(nil, "BORDER")
        t:SetPoint(side[1], c, side[1], 0, 0)
        t:SetPoint(side[2], c, side[2], 0, 0)
        t.vertical = i > 2
        c.ink[i] = t
    end
    for _, corner in ipairs({ { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }) do
        for _, along in ipairs({ true, false }) do
            local t = c:CreateTexture(nil, "BORDER")
            t:SetPoint(corner[1], c, corner[1], 0, 0)
            if along then t:SetSize(BRACKET, BRACKET_T) else t:SetSize(BRACKET_T, BRACKET) end
            c.brackets[#c.brackets + 1] = t
        end
    end
    return c
end

local function StyleCard(c)
    local decor, accent, ink = DECOR[ThemeId()], ns.Themes.Accent(), { 0, 0, 0, 1 }
    Colour(c.fill, ns.ThemeArt.CardColour())
    local rim = ns.ThemeArt.WindowRim()
    for _, t in ipairs(c.ink) do
        if t.vertical then t:SetWidth(rim) else t:SetHeight(rim) end
        Colour(t, ink)
        t:SetShown(decor == "ink")
    end
    Colour(c.shadow, ink)
    c.shadow:SetShown(decor == "ink")
    for _, t in ipairs(c.brackets) do
        Colour(t, accent)
        t:SetShown(decor == "brackets")
    end
    c.sheen:SetHeight(math.max(1, (c:GetHeight() or 0) * 0.45))
    Fade(c.sheen, { 1, 1, 1 }, SHEEN_ALPHA, 0)
    c.sheen:SetShown(decor == "sheen")
    c.edge:SetWidth(3)
    Colour(c.edge, ns.Themes.IconColor())
    c.edge:SetShown(decor == "edge")
end

local cards = {}
local function NewCard(parent)
    local c = Card(parent)
    cards[#cards + 1] = c
    return c
end

-- A tile: a card with a round symbol, a heading, a value and a line below.
local function Tile(parent, heading, symbol)
    local t = NewCard(parent)
    t.ground = t:CreateTexture(nil, "ARTWORK")
    Media(t.ground, "GoldDot")
    t.symbol = t:CreateTexture(nil, "OVERLAY")
    if symbol then Media(t.symbol, symbol) end
    t.ground:SetShown(symbol ~= nil)
    t.symbol:SetShown(symbol ~= nil)
    t.head = Text(t, "head")
    t.head:SetText(heading)
    t.value = Text(t, "value")
    t.sub = Text(t, "muted")
    return t
end

local function LayoutTile(t, w, h)
    t:SetSize(w, h)
    local icon = t.symbol:IsShown() and 2 * RowH() or 0
    local x = icon > 0 and icon + 2 * GAP or GAP
    t.ground:SetSize(icon, icon)
    t.ground:ClearAllPoints()
    t.ground:SetPoint("LEFT", t, "LEFT", GAP, 0)
    t.symbol:SetSize(icon * 0.6, icon * 0.6)
    t.symbol:ClearAllPoints()
    t.symbol:SetPoint("CENTER", t.ground, "CENTER", 0, 0)
    local row = RowH()
    for i, fs in ipairs({ t.head, t.value, t.sub }) do
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", t, "TOPLEFT", x, -(GAP / 2 + (i - 1) * row))
        fs:SetPoint("TOPRIGHT", t, "TOPRIGHT", -GAP, -(GAP / 2 + (i - 1) * row))
    end
end

local function PaintTile(t)
    StyleCard(t)
    local c = ns.Themes.IconColor()
    Tint(t.ground, c, ICON_ALPHA)
    Tint(t.symbol, c, 1)
end

-- A chip: today's or this week's change with an arrow, in green or red.
local function Chip(parent, label)
    local c = CreateFrame("Frame", nil, parent)
    c.fill = c:CreateTexture(nil, "BACKGROUND")
    c.fill:SetAllPoints(c)
    c.rims = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = c:CreateTexture(nil, "BORDER")
        t:SetPoint(side[1], c, side[1], 0, 0)
        t:SetPoint(side[2], c, side[2], 0, 0)
        if i > 2 then t:SetWidth(1) else t:SetHeight(1) end
        c.rims[i] = t
    end
    c.arrow = c:CreateTexture(nil, "ARTWORK")
    Media(c.arrow, "GoldArrow")
    c.label = Text(c, "muted")
    c.label:SetText(label)
    c.value = Text(c, "value", "RIGHT")
    return c
end

local function LayoutChip(c, w, h)
    c:SetSize(w, h)
    local a = h * 0.5
    c.arrow:SetSize(a, a)
    c.arrow:ClearAllPoints()
    c.arrow:SetPoint("LEFT", c, "LEFT", GAP, 0)
    c.label:ClearAllPoints()
    c.label:SetPoint("LEFT", c, "LEFT", GAP * 2 + a, 0)
    c.value:ClearAllPoints()
    c.value:SetPoint("RIGHT", c, "RIGHT", -GAP, 0)
end

local function FillChip(c, copper)
    local text, colour = ns.Gold.Signed(copper)
    c.value:SetText(text)
    Paint(c.value, colour)
    Colour(c.fill, colour, CHIP_ALPHA)
    for _, t in ipairs(c.rims) do Colour(t, colour, CHIP_RIM_ALPHA) end
    Tint(c.arrow, colour, 1)
    -- Down: the arrow mirrored top to bottom.
    if copper < 0 then c.arrow:SetTexCoord(0, 1, 1, 0) else c.arrow:SetTexCoord(0, 1, 0, 1) end
    c.arrow:SetShown(copper ~= 0)
end

-- A horizontal bar of pieces (income or expenses by source), drawn as textures.
local function Pieces(parent, n)
    local list = {}
    for i = 1, n do list[i] = parent:CreateTexture(nil, "ARTWORK") end
    return list
end

-- -----------------------------------------------------------------------------
-- The chart: the balance as an area under a line, a grid with values, the
-- days below, the day's change as columns, today's value on a flag.
-- -----------------------------------------------------------------------------
local function Chart(parent)
    local c = CreateFrame("Frame", nil, parent)
    c.grid, c.yLabels, c.xLabels, c.lines, c.dots, c.deltas, c.lows, c.highs = {}, {}, {}, {}, {}, {}, {}, {}
    for i = 1, GRID_LINES do
        c.grid[i] = c:CreateTexture(nil, "BORDER")
        c.yLabels[i] = Text(c, "muted")
    end
    c.flag = c:CreateTexture(nil, "OVERLAY", nil, 1)
    c.flagText = Text(c, "flag", "CENTER")
    if c.flagText.SetShadowOffset then c.flagText:SetShadowOffset(0, 0) end
    c.flagText:SetDrawLayer("OVERLAY", 2)
    c.finish = c:CreateTexture(nil, "OVERLAY", nil, 3)
    Media(c.finish, "GoldFlag")
    c.empty = Text(parent, "muted")
    c.empty:SetPoint("CENTER", c, "CENTER")
    c.empty:SetText(L.GOLD_EMPTY_CURVE)
    return c
end

local function SizeChart(c, plotH)
    c.plotW, c.plotH = CONTENT_W - Y_LABEL_W, plotH
    c:SetSize(CONTENT_W, plotH + X_ROW)
end

local function Get(list, i, make)
    list[i] = list[i] or make()
    return list[i]
end

local function HideAll(list) for _, x in ipairs(list) do x:Hide() end end

-- The weekday's short name (os.date's %w: 0 = Sunday).
local function Weekday(t)
    local names = {}
    for n in L.GOLD_WEEKDAYS:gmatch("%S+") do names[#names + 1] = n end
    return names[tonumber(date("%w", t)) + 1] or ""
end

-- Dark text on a bright accent, light text on a dark one.
local function FlagInk(c)
    local light = 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]
    return light > DARK_ON and { 0.05, 0.05, 0.05 } or { 1, 1, 1 }
end

-- The day labels: each weekday on a week, else the first, middle and last date.
-- By calendar day, also where there is no balance yet: every weekday on
-- short spans, else first, middle and today.
local function DayLabels(c, today, span, XBack)
    local backs = {}
    if span <= OVERVIEW_DAYS then
        for back = span - 1, 0, -1 do backs[#backs + 1] = back end
    else
        backs = { span - 1, math.floor((span - 1) / 2), 0 }
    end
    HideAll(c.xLabels)
    for k, back in ipairs(backs) do
        local t = ns.Gold.DayTime(today, back)
        local fs = Get(c.xLabels, k, function() return Text(c, "muted", "CENTER") end)
        fs:ClearAllPoints()
        fs:SetPoint("BOTTOM", c, "BOTTOMLEFT", XBack(back), 0)
        fs:SetText(span <= OVERVIEW_DAYS and Weekday(t) or date(L.GOLD_DATE, t))
        Paint(fs, TextColour(), back == 0 and 1 or MUTED_ALPHA)
        fs:Show()
    end
end

-- Under the line: per step a rectangle up to the lower point and a wedge
-- between the two points, all at one alpha (a fade would seam where they meet).
local function Area(c, x1, y1, x2, y2, i, accent)
    local low, high = math.min(y1, y2), math.max(y1, y2)
    local base = Get(c.lows, i, function() return c:CreateTexture(nil, "BACKGROUND", nil, 2) end)
    base:ClearAllPoints()
    base:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", x1, X_ROW)
    base:SetSize(math.max(1, x2 - x1), math.max(1, low - X_ROW))
    Colour(base, accent, AREA_ALPHA)
    base:Show()
    local wedge = Get(c.highs, i, function()
        local t = c:CreateTexture(nil, "BACKGROUND", nil, 2)
        Media(t, "GoldWedge")
        return t
    end)
    wedge:ClearAllPoints()
    wedge:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", x1, low)
    wedge:SetSize(math.max(1, x2 - x1), math.max(1, high - low))
    -- The texture rises to the right; mirrored when the balance fell.
    if y2 >= y1 then wedge:SetTexCoord(0, 1, 0, 1) else wedge:SetTexCoord(1, 0, 0, 1) end
    Tint(wedge, accent, AREA_ALPHA)
    wedge:SetShown(high - low >= 1)
end

-- The curve over `span` days (points as Gold.GraphPoints); false below two points.
local function DrawChart(c, points, span)
    for _, list in ipairs({ c.lines, c.dots, c.deltas, c.lows, c.highs, c.xLabels }) do HideAll(list) end
    for i = 1, GRID_LINES do
        c.grid[i]:Hide()
        c.yLabels[i]:SetText("")
    end
    c.flag:Hide()
    c.flagText:SetText("")
    c.finish:Hide()
    c.empty:SetShown(#points < 2)
    if #points < 2 then return false end
    local lo, hi = ns.Gold.Range(points)
    local accent, text = ns.Themes.Accent(), TextColour()
    -- Always the whole span: days before the first balance stay empty on the
    -- left, so a new character's first days are not stretched over the width.
    local first = math.max(1, span - 1)
    local function XBack(back) return (first - back) / first * c.plotW end
    local function X(i) return XBack(points[i].back) end
    local function Y(v)
        local share = hi > lo and (v - lo) / (hi - lo) or 0.5
        return X_ROW + share * c.plotH
    end
    for i = 1, GRID_LINES do
        local share = (i - 1) / (GRID_LINES - 1)
        local y = X_ROW + share * c.plotH
        local g = c.grid[i]
        g:ClearAllPoints()
        g:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, y)
        g:SetSize(c.plotW, 1)
        Colour(g, text, GRID_ALPHA)
        g:Show()
        local fs = c.yLabels[i]
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", c, "BOTTOMLEFT", c.plotW + GAP, y)
        fs:SetText(ns.Gold.Money(math.floor(lo + share * (hi - lo) + 0.5)))
    end
    -- The day's change as a column from the base: up green, down red.
    local biggest = 0
    for i = 2, #points do biggest = math.max(biggest, math.abs(points[i].value - points[i - 1].value)) end
    if span <= DELTAS_UP_TO and biggest > 0 then
        for i = 2, #points do
            local dv = points[i].value - points[i - 1].value
            if dv ~= 0 then
                local col = Get(c.deltas, i, function() return c:CreateTexture(nil, "BACKGROUND", nil, 3) end)
                local _, colour = ns.Gold.Signed(dv)
                col:ClearAllPoints()
                col:SetPoint("BOTTOM", c, "BOTTOMLEFT", X(i), X_ROW)
                col:SetSize(DELTA_W, math.max(1, math.abs(dv) / biggest * c.plotH * DELTA_SHARE))
                Colour(col, colour, DELTA_ALPHA)
                col:Show()
            end
        end
    end
    for i = 2, #points do
        local x1, y1, x2, y2 = X(i - 1), Y(points[i - 1].value), X(i), Y(points[i].value)
        Area(c, x1, y1, x2, y2, i, accent)
        local line = Get(c.lines, i - 1, function() return c:CreateLine(nil, "ARTWORK") end)
        line:SetThickness(LINE_THICKNESS)
        Colour(line, accent, 1)
        line:SetStartPoint("BOTTOMLEFT", c, x1, y1)
        line:SetEndPoint("BOTTOMLEFT", c, x2, y2)
        line:Show()
    end
    for i = 1, #points do
        local last = i == #points
        if last or span <= DOTS_UP_TO then
            local d = Get(c.dots, i, function() return c:CreateTexture(nil, "OVERLAY") end)
            Media(d, last and "GoldDot" or "GoldRing")
            d:SetSize(last and DOT or RING, last and DOT or RING)
            d:ClearAllPoints()
            d:SetPoint("CENTER", c, "BOTTOMLEFT", X(i), Y(points[i].value))
            Tint(d, accent, 1)
            d:Show()
        end
    end
    DayLabels(c, points[#points].t, span, XBack)
    -- Today's value on a flag left above its point.
    local lx, ly = X(#points), Y(points[#points].value)
    c.flagText:SetText(ns.Gold.Money(points[#points].value))
    Paint(c.flagText, FlagInk(accent))
    local fw, fh = (c.flagText:GetStringWidth() or 0) + 2 * FLAG_PAD, RowH()
    c.flag:ClearAllPoints()
    -- Inside the plot: at the top the flag hangs below the point.
    c.flag:SetPoint("BOTTOMRIGHT", c, "BOTTOMLEFT", lx - FLAG_PAD, math.min(ly + FLAG_LIFT - fh / 2, X_ROW + c.plotH - fh))
    c.flag:SetSize(fw, fh)
    Colour(c.flag, accent, 1)
    c.flag:Show()
    c.flagText:ClearAllPoints()
    c.flagText:SetPoint("CENTER", c.flag, "CENTER", 0, 0)
    if DECOR[ThemeId()] == "edge" then
        c.finish:SetSize(fh, fh)
        c.finish:ClearAllPoints()
        c.finish:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", lx - 2, ly)
        c.finish:Show()
    end
    return true
end

-- -----------------------------------------------------------------------------
-- Items: icon, name in its quality's colour, the game's tooltip on hover,
-- a modified click links it (shift: chat).
-- -----------------------------------------------------------------------------
local function ItemRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.name = Text(r, "value")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", GAP, 0)
    r.share = r:CreateTexture(nil, "BACKGROUND")
    r:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self)
        -- Only a full link goes to the chat; a bare "item:id" (not cached yet) shows the tooltip only.
        if self.link and self.link:find("|H", 1, true) and HandleModifiedItemClick then HandleModifiedItemClick(self.link) end
    end)
    return r
end

local function FillItemRow(r, e, best)
    r:SetShown(e ~= nil)
    r.link = nil
    if not e then return end
    local link, quality, icon = ns.GoldLedger.ItemInfo(e.name, e.item)
    r.link = link
    r.icon:SetTexture(icon or QUESTION_MARK)
    r.name:SetText(e.name)
    local q = quality and C_Item and C_Item.GetItemQualityColor and { C_Item.GetItemQualityColor(quality) }
    Paint(r.name, q and q[1] and q or TextColour())
    local _, colour = ns.Gold.Signed(e.profit)
    r.share:SetWidth(math.max(1, r.shareW * math.max(0, e.profit) / math.max(1, best)))
    Colour(r.share, colour, SHARE_ALPHA)
    r.share:SetShown(e.profit > 0)
end

-- -----------------------------------------------------------------------------
-- The window
-- -----------------------------------------------------------------------------
local function SavePlace()
    local point, _, relative, x, y = frame:GetPoint(1)
    Stored().place = { point, relative, x, y }
end

-- The cross of the options window, fainter until hovered.
local function CloseButton(bar)
    local b = CreateFrame("Button", nil, bar)
    b.lines = {}
    for i, angle in ipairs({ CROSS_ANGLE, -CROSS_ANGLE }) do
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetSize(CROSS_SIZE, UNDERLINE_H)
        t:SetPoint("CENTER")
        if t.SetRotation then t:SetRotation(angle) end
        b.lines[i] = t
    end
    function b.Paint(alpha)
        for _, t in ipairs(b.lines) do Colour(t, TextColour(), alpha) end
    end
    b:SetScript("OnEnter", function() b.Paint(1) end)
    b:SetScript("OnLeave", function() b.Paint(MUTED_ALPHA) end)
    b:SetScript("OnClick", function() frame:Hide() end)
    return b
end

local function BuildOverview(page)
    page.coins = page:CreateTexture(nil, "ARTWORK")
    Media(page.coins, "GoldCoins")
    page.money = Text(page, "big")
    page.burst = page:CreateTexture(nil, "BORDER", nil, 1)
    page.burstInk = page:CreateTexture(nil, "BORDER", nil, 0)
    Media(page.burst, "ComicBurst")
    Media(page.burstInk, "ComicBurst")
    page.kaching = Text(page, "head", "CENTER")
    page.kaching:SetText(L.GOLD_KACHING)
    page.today = Chip(page, L.GOLD_TODAY)
    page.week = Chip(page, L.GOLD_WEEK)
    page.tiles = {
        Tile(page, L.GOLD_TILE_SESSION, "GoldHourglass"), Tile(page, L.GOLD_TILE_ALL, "GoldPeople"),
        Tile(page, L.GOLD_TILE_ITEM, "GoldGavel"),
    }
    page.dayHead = Text(page, "head")
    page.dayHead:SetText(L.GOLD_TODAY)
    page.daySum = Text(page, "muted", "RIGHT")
    page.inPieces, page.outPieces = Pieces(page, #INCOME_SHADES), Pieces(page, #OUTCOME_SHADES)
    page.legend = {}
    page.curveHead = Text(page, "head")
    page.curveHead:SetText(L.GOLD_SCOPE_CHAR:format(OVERVIEW_DAYS))
    page.chart = Chart(page)
    page.itemsHead = Text(page, "head")
    page.itemsHead:SetText(L.GOLD_BEST_ITEMS)
    page.itemsScope = Text(page, "muted", "RIGHT")
    page.items = {}
    for i = 1, OVERVIEW_ITEMS do
        page.items[i] = ItemRow(page)
        page.items[i].profit = Text(page.items[i], "value", "RIGHT")
    end
end

local function RangeSwitch(page)
    page.ranges = {}
    for i, days in ipairs(Window.RANGES) do
        page.ranges[i] = SwitchButton(page, L.GOLD_DAYS:format(days), function()
            Stored().range = days
            Window.Fill()
        end)
        page.ranges[i].days = days
    end
    page.scope = Text(page, "head")
end

local function BuildHistory(page)
    RangeSwitch(page)
    page.tiles = {
        Tile(page, L.GOLD_HIST_CHANGE), Tile(page, L.GOLD_HIST_HIGH), Tile(page, L.GOLD_HIST_LOW), Tile(page, L.GOLD_HIST_BEST),
    }
    page.chart = Chart(page)
end

-- Rows of a source: its name and amount, a bar of its share below.
local function SourceRows(page, n)
    local rows = {}
    for i = 1, n do
        rows[i] = { label = Text(page, "text"), value = Text(page, "value", "RIGHT"), bar = page:CreateTexture(nil, "ARTWORK") }
    end
    return rows
end

local function BuildFlow(page)
    RangeSwitch(page)
    page.tiles = { Tile(page, L.GOLD_INCOME), Tile(page, L.GOLD_EXPENSES), Tile(page, L.GOLD_NET) }
    page.incomeHead = Text(page, "head")
    page.incomeHead:SetText(L.GOLD_INCOME)
    page.expenseHead = Text(page, "head")
    page.expenseHead:SetText(L.GOLD_EXPENSES)
    page.income = SourceRows(page, SOURCE_ROWS)
    page.expenses = SourceRows(page, SOURCE_ROWS)
    page.empty = Text(page, "muted")
    page.empty:SetText(L.GOLD_EMPTY_SOURCES)
end

local function BuildItems(page)
    page.scope = Text(page, "head")
    page.columns = {}
    for _, key in ipairs({ "ITEM", "SOLD", "BOUGHT", "PROFIT" }) do
        page.columns[key] = Text(page, "muted", key == "ITEM" and "LEFT" or "RIGHT")
        page.columns[key]:SetText(L["GOLD_COL_" .. key])
    end
    page.rows = {}
    for i = 1, ITEM_ROWS do
        local row = ItemRow(page)
        for _, key in ipairs({ "SOLD", "BOUGHT", "PROFIT" }) do
            row[key] = Text(row, key == "PROFIT" and "value" or "text", "RIGHT")
            row[key]:SetWidth(ITEM_COLUMNS[key])
        end
        page.rows[i] = row
    end
    page.empty = Text(page, "muted")
    page.empty:SetText(L.GOLD_EMPTY_ITEMS)
end

local BUILD = { OVERVIEW = BuildOverview, HISTORY = BuildHistory, FLOW = BuildFlow, ITEMS = BuildItems }

local function Build()
    frame = CreateFrame("Frame", NAME, UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    local place = Stored().place
    if place then frame:SetPoint(place[1], UIParent, place[2], place[3], place[4]) else frame:SetPoint("CENTER") end

    local bar = CreateFrame("Frame", nil, frame)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePlace()
    end)
    frame.titleBar = bar
    ns.ThemeArt.BuildWindow(frame, bar)
    frame.title = Text(bar, "title")
    frame.title:SetText(L.DATABAR_PART_GOLD)
    frame.close = CloseButton(bar)

    frame.tabs, frame.pages = {}, {}
    for i, id in ipairs(Window.TABS) do
        frame.tabs[i] = SwitchButton(frame, L["GOLD_TAB_" .. id], function() Window.ShowTab(id) end)
        frame.tabs[i].id = id
        local page = CreateFrame("Frame", nil, frame)
        BUILD[id](page)
        page:Hide()
        frame.pages[id] = page
    end

    frame:Hide()
    if UISpecialFrames then
        local listed = false
        for _, n in ipairs(UISpecialFrames) do if n == NAME then listed = true end end
        if not listed then table.insert(UISpecialFrames, NAME) end
    end
end

-- -----------------------------------------------------------------------------
-- Layout (follows the font size) and look
-- -----------------------------------------------------------------------------
local function At(region, page, x, y, point)
    region:ClearAllPoints()
    region:SetPoint(point or "TOPLEFT", page, "TOPLEFT", x, y)
end

local function TileRow(page, tiles, y, h)
    local w = (CONTENT_W - (#tiles - 1) * GAP) / #tiles
    for i, t in ipairs(tiles) do
        LayoutTile(t, w, h)
        At(t, page, (i - 1) * (w + GAP), y)
    end
    return y - h - GAP
end

local function TileH(withSub) return (withSub and 3 or 2) * RowH() + GAP end

local function LayoutOverview(page, pageH)
    local h = RowH()
    local chipH = h + 4
    local heroH = math.max(2 * chipH + GAP / 2, FontSize() + BIG_SIZE_ADD + COINS_ADD)
    local coins = FontSize() + BIG_SIZE_ADD + COINS_ADD
    page.coins:SetSize(coins, coins)
    At(page.coins, page, 0, -(heroH - coins) / 2)
    page.money:ClearAllPoints()
    page.money:SetPoint("LEFT", page.coins, "RIGHT", GAP, 0)
    LayoutChip(page.today, CHIP_W, chipH)
    LayoutChip(page.week, CHIP_W, chipH)
    At(page.today, page, CONTENT_W - CHIP_W, 0)
    At(page.week, page, CONTENT_W - CHIP_W, -(chipH + GAP / 2))
    for _, t in ipairs({ page.burst, page.burstInk }) do t:ClearAllPoints() end
    page.burstInk:SetSize(BURST + BURST_INK, BURST + BURST_INK)
    page.burst:SetSize(BURST, BURST)
    page.burstInk:SetPoint("CENTER", page.today, "LEFT", -BURST / 2, -chipH / 2)
    page.burst:SetPoint("CENTER", page.burstInk, "CENTER", 0, 0)
    page.kaching:ClearAllPoints()
    page.kaching:SetPoint("CENTER", page.burst, "CENTER", 0, 0)
    local y = TileRow(page, page.tiles, -(heroH + GAP), TileH(true)) - GAP / 2

    At(page.dayHead, page, 0, y)
    At(page.daySum, page, CONTENT_W, y, "TOPRIGHT")
    page.barY = y - h
    y = page.barY - BAR_H - 3 - OUT_H - GAP / 2
    page.legendY = y
    y = y - h - GAP

    local rowH = math.max(h, 2 * FontSize())
    local itemsH = h + OVERVIEW_ITEMS * (rowH + 2)
    local plotH = math.max(MIN_PLOT_H, pageH + y - h - GAP / 2 - X_ROW - GAP - itemsH)
    At(page.curveHead, page, 0, y)
    SizeChart(page.chart, plotH)
    At(page.chart, page, 0, y - h - GAP / 2)
    y = y - h - GAP / 2 - plotH - X_ROW - GAP

    At(page.itemsHead, page, 0, y)
    At(page.itemsScope, page, CONTENT_W, y, "TOPRIGHT")
    for i, r in ipairs(page.items) do
        r:SetSize(CONTENT_W, rowH)
        At(r, page, 0, y - h - (i - 1) * (rowH + 2))
        r.icon:SetSize(rowH - 2, rowH - 2)
        r.shareW = CONTENT_W / 3
        r.share:ClearAllPoints()
        r.share:SetPoint("RIGHT", r, "RIGHT", -ITEM_COLUMNS.PROFIT, 0)
        r.share:SetHeight(SHARE_BAR_H)
        r.profit:ClearAllPoints()
        r.profit:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    end
end

local function LayoutRanges(page)
    local h = RowH()
    for i, b in ipairs(page.ranges) do
        b:SetSize(RANGE_W, h + UNDERLINE_H + 2)
        At(b, page, (i - 1) * (RANGE_W + GAP) - 4, 0)
    end
    At(page.scope, page, CONTENT_W, -(UNDERLINE_H + 2), "TOPRIGHT")
    page.scope:SetJustifyH("RIGHT")
    return -(h + UNDERLINE_H + 2 * GAP)
end

local function LayoutHistory(page, pageH)
    local y = TileRow(page, page.tiles, LayoutRanges(page), TileH(false)) - GAP
    SizeChart(page.chart, math.max(MIN_PLOT_H, pageH + y - X_ROW))
    At(page.chart, page, 0, y)
end

local function LayoutFlow(page)
    local y = TileRow(page, page.tiles, LayoutRanges(page), TileH(false)) - GAP
    local half = (CONTENT_W - 2 * GAP) / 2
    At(page.incomeHead, page, 0, y)
    At(page.expenseHead, page, half + 2 * GAP, y)
    y = y - RowH() - GAP / 2
    local step = RowH() + SHARE_BAR_H + GAP / 2
    for k, rows in ipairs({ page.income, page.expenses }) do
        local x = (k - 1) * (half + 2 * GAP)
        for i, row in ipairs(rows) do
            local at = y - (i - 1) * step
            At(row.label, page, x, at)
            row.label:SetWidth(half * 0.6)
            At(row.value, page, x + half, at, "TOPRIGHT")
            row.bar:SetHeight(SHARE_BAR_H)
            At(row.bar, page, x, at - FontSize() - 3)
            row.width = half
        end
    end
    At(page.empty, page, 0, y)
end

local function LayoutItems(page)
    local h = RowH()
    At(page.scope, page, 0, 0)
    local y = -(h + GAP)
    local rowH = math.max(h, 2 * FontSize())
    local nameW = CONTENT_W - ITEM_COLUMNS.SOLD - ITEM_COLUMNS.BOUGHT - ITEM_COLUMNS.PROFIT
    local function columns(row, parent, x0)
        local right = CONTENT_W
        for _, key in ipairs({ "PROFIT", "BOUGHT", "SOLD" }) do
            row[key]:ClearAllPoints()
            row[key]:SetPoint("RIGHT", parent, "LEFT", right - x0, 0)
            right = right - ITEM_COLUMNS[key]
        end
    end
    At(page.columns.ITEM, page, rowH + GAP, y)
    local right = CONTENT_W
    for _, key in ipairs({ "PROFIT", "BOUGHT", "SOLD" }) do
        page.columns[key]:SetWidth(ITEM_COLUMNS[key])
        At(page.columns[key], page, right, y, "TOPRIGHT")
        right = right - ITEM_COLUMNS[key]
    end
    y = y - h
    for i, row in ipairs(page.rows) do
        row:SetSize(CONTENT_W, rowH)
        At(row, page, 0, y - (i - 1) * (rowH + 2))
        row.icon:SetSize(rowH - 2, rowH - 2)
        row.name:SetWidth(nameW - rowH - 2 * GAP)
        columns(row, row, 0)
        row.shareW = nameW - rowH - GAP
        row.share:ClearAllPoints()
        row.share:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", rowH + GAP, 0)
        row.share:SetHeight(2)
    end
    At(page.empty, page, 0, y)
end

local LAYOUT = { OVERVIEW = LayoutOverview, HISTORY = LayoutHistory, FLOW = LayoutFlow, ITEMS = LayoutItems }

-- Under the rim: the title strip inset by its size, as in every Forever window.
function Window.Style()
    if not frame then return end
    local rim, size = ns.ThemeArt.WindowRim(), FontSize()
    local titleH = size + TITLE_SIZE_ADD + TITLE_PAD
    local bar = frame.titleBar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", rim, -rim)
    bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -rim, -rim)
    bar:SetHeight(titleH)
    ns.ThemeArt.StyleWindow(frame, bar)
    frame.title:ClearAllPoints()
    frame.title:SetPoint("LEFT", bar, "LEFT", ns.ThemeArt.TitleStart(titleH) or INSET, 0)
    frame.close:SetSize(titleH, titleH)
    frame.close:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    frame.close.Paint(MUTED_ALPHA)

    local tabH, x = size + TAB_PAD, INSET - 4
    local pageH = HEIGHT - 2 * rim - titleH - (tabH + GAP + GAP / 2) - INSET
    for _, b in ipairs(frame.tabs) do
        b:SetSize(math.max(TAB_MIN_W, (b.text:GetStringWidth() or 0) + 2 * GAP), tabH)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", x - rim, -GAP / 2)
        x = x + b:GetWidth()
    end
    for id, page in pairs(frame.pages) do
        page:ClearAllPoints()
        page:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", INSET - rim, -(tabH + GAP + GAP / 2))
        page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -INSET, INSET)
        LAYOUT[id](page, pageH)
        for _, t in ipairs(page.tiles or {}) do PaintTile(t) end
    end
    ApplyFonts()
    local accent = ns.Themes.Accent()
    local o = frame.pages.OVERVIEW
    Tint(o.burst, accent, 1)
    Tint(o.burstInk, { 0, 0, 0 }, 1)
end

-- -----------------------------------------------------------------------------
-- Data
-- -----------------------------------------------------------------------------
local function SetSigned(fs, copper, prefix)
    local text, c = ns.Gold.Signed(copper)
    fs:SetText((prefix or "") .. text)
    Paint(fs, c)
end

local function SetDash(fs)
    fs:SetText(ns.Gold.NONE)
    Paint(fs, TextColour(), MUTED_ALPHA)
end

-- The money with the game's coin icons where it has them.
local function CoinText(copper, size)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        local s = C_CurrencyInfo.GetCoinTextureString(copper, size)
        if s then return s end
    end
    return ns.Gold.Money(copper)
end

-- A bar of pieces from x0, `width` for `total`; the rest hidden.
local function FillPieces(pieces, list, x0, y, h, scale, colour, shades, page)
    local x = x0
    for i, t in ipairs(pieces) do
        local e = list[i]
        -- The last piece takes every source after it.
        local amount = e and e.amount or 0
        if i == #pieces then for k = i + 1, #list do amount = amount + list[k].amount end end
        local w = amount * scale
        t:SetShown(w >= 1)
        if w >= 1 then
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
            t:SetSize(math.max(1, w - 1), h)
            Colour(t, colour, shades[i])
        end
        x = x + w
    end
end

-- The legend under today's bar: a box and name per source, as many as fit.
local function FillLegend(page, entries)
    local x = 0
    for _, l in ipairs(page.legend) do
        l.box:Hide()
        l.text:Hide()
    end
    for i, e in ipairs(entries) do
        local l = page.legend[i]
        if not l then
            l = { box = page:CreateTexture(nil, "ARTWORK"), text = Text(page, "muted") }
            page.legend[i] = l
            ApplyFonts()
        end
        l.text:SetText(e.label)
        local w = LEGEND_BOX + 4 + (l.text:GetStringWidth() or 0) + 2 * GAP
        if x + w > CONTENT_W then break end
        l.box:SetSize(LEGEND_BOX, LEGEND_BOX)
        At(l.box, page, x, page.legendY - (RowH() - LEGEND_BOX) / 2 + ROW_PAD / 2)
        Colour(l.box, e.colour, e.alpha)
        At(l.text, page, x + LEGEND_BOX + 4, page.legendY)
        l.box:Show()
        l.text:Show()
        x = x + w
    end
end

local function FillToday(page, days, now)
    local G, Ledger = ns.Gold, ns.GoldLedger
    local inc, out = Ledger.Totals(days, { G.DayKey(now) })
    local tin, tout = 0, 0
    for _, e in ipairs(inc) do tin = tin + e.amount end
    for _, e in ipairs(out) do tout = tout + e.amount end
    page.daySum:SetText((G.Signed(tin)) .. "  ·  " .. (G.Signed(-tout)))
    local gain, loss = select(2, G.Signed(1)), select(2, G.Signed(-1))
    local scale = math.max(tin, tout) > 0 and CONTENT_W / math.max(tin, tout) or 0
    FillPieces(page.inPieces, inc, 0, page.barY, BAR_H, scale, gain, INCOME_SHADES, page)
    FillPieces(page.outPieces, out, 0, page.barY - BAR_H - 3, OUT_H, scale, loss, OUTCOME_SHADES, page)
    local entries = {}
    for i, e in ipairs(inc) do
        if i > #INCOME_SHADES then break end
        entries[#entries + 1] = { label = L["GOLD_SRC_" .. e.source] .. " " .. G.Money(e.amount), colour = gain, alpha = INCOME_SHADES[i] }
    end
    for i, e in ipairs(out) do
        if i > #OUTCOME_SHADES then break end
        entries[#entries + 1] = { label = L["GOLD_SRC_" .. e.source] .. " " .. G.Money(e.amount), colour = loss, alpha = OUTCOME_SHADES[i] }
    end
    FillLegend(page, entries)
    return tin - tout
end

local function FillOverview(page, days, now, money)
    local G, Ledger = ns.Gold, ns.GoldLedger
    page.money:SetText(CoinText(money, FontSize() + BIG_SIZE_ADD))
    local gained, spent = G.Sum(days, { G.DayKey(now) })
    page.todayNet = gained - spent
    FillChip(page.today, page.todayNet)
    gained, spent = G.Sum(days, G.WeekKeys(now))
    FillChip(page.week, gained - spent)
    local comic = ThemeId() == "COMIC" and page.todayNet > 0
    for _, t in ipairs({ page.burst, page.burstInk, page.kaching }) do t:SetShown(comic) end

    local session, all, item = unpack(page.tiles)
    local s = ns.CharDB().goldSession
    if s then
        local net = s.gained - s.spent
        local rate = G.PerHour(net, now - s.start)
        SetSigned(session.value, net)
        session.sub:SetText(rate and L.GOLD_PER_HOUR_SHORT:format((G.Signed(math.floor(rate + 0.5)))) or G.NONE)
    else
        SetDash(session.value)
        session.sub:SetText("")
    end
    local realm = GetRealmName()
    local chars, total = G.RealmChars(ns.AccountDB(), realm)
    all.value:SetText(G.Money(total))
    Paint(all.value, TextColour())
    all.sub:SetText(L.GOLD_CHARS_COUNT:format(#chars) .. " · " .. G.RealmLabel(realm))
    local top = Ledger.TopItems(Ledger.ItemsOf(ns.AccountDB(), realm), OVERVIEW_ITEMS)
    local best = top[1]
    if best then
        item.value:SetText(best.name)
        local _, quality = Ledger.ItemInfo(best.name, best.item)
        local q = quality and C_Item and C_Item.GetItemQualityColor and { C_Item.GetItemQualityColor(quality) }
        Paint(item.value, q and q[1] and q or TextColour())
        item.sub:SetText(L.GOLD_PROFIT_SUB:format((G.Signed(best.profit))))
    else
        SetDash(item.value)
        item.sub:SetText("")
    end
    FillToday(page, days, now)
    DrawChart(page.chart, G.GraphPoints(days, now, money, OVERVIEW_DAYS), OVERVIEW_DAYS)
    page.itemsScope:SetText(L.GOLD_ALL_CHARS)
    for i, r in ipairs(page.items) do
        FillItemRow(r, top[i], best and best.profit or 1)
        if top[i] then SetSigned(r.profit, top[i].profit) end
    end
end

local function FillRanges(page, range)
    for _, b in ipairs(page.ranges) do PaintSwitch(b, b.days == range) end
    page.scope:SetText(L.GOLD_SCOPE_CHAR:format(range))
end

-- Change, high, low and best day over the range's points.
local function FillHistory(page, days, now, money, range)
    local G = ns.Gold
    FillRanges(page, range)
    local points = G.GraphPoints(days, now, money, range)
    local change, high, low, best = page.tiles[1], page.tiles[2], page.tiles[3], page.tiles[4]
    if #points < 2 then
        for _, t in ipairs(page.tiles) do SetDash(t.value) end
    else
        local lo, hi = G.Range(points)
        SetSigned(change.value, points[#points].value - points[1].value)
        high.value:SetText(G.Money(hi))
        Paint(high.value, TextColour())
        low.value:SetText(G.Money(lo))
        Paint(low.value, TextColour())
        local bestDelta, bestT = nil, nil
        for i = 2, #points do
            local dv = points[i].value - points[i - 1].value
            if not bestDelta or dv > bestDelta then bestDelta, bestT = dv, points[i].t end
        end
        SetSigned(best.value, bestDelta, date(L.GOLD_DATE, bestT) .. "  ")
    end
    DrawChart(page.chart, points, range)
end

local function FillSources(rows, list, sign, total)
    for i, row in ipairs(rows) do
        local e = list[i]
        row.label:SetText(e and L["GOLD_SRC_" .. e.source] or "")
        row.bar:SetShown(e ~= nil)
        if e then
            local _, c = ns.Gold.Signed(sign)
            SetSigned(row.value, e.amount * sign)
            row.bar:SetWidth(math.max(1, row.width * e.amount / math.max(1, total)))
            Colour(row.bar, c, SHARE_ALPHA)
        else
            row.value:SetText("")
        end
    end
end

local function FillFlow(page, days, now, range)
    local G = ns.Gold
    FillRanges(page, range)
    local income, expenses = ns.GoldLedger.Totals(days, G.LastKeys(now, range))
    local tin, tout = 0, 0
    for _, e in ipairs(income) do tin = tin + e.amount end
    for _, e in ipairs(expenses) do tout = tout + e.amount end
    SetSigned(page.tiles[1].value, tin)
    SetSigned(page.tiles[2].value, -tout)
    SetSigned(page.tiles[3].value, tin - tout)
    FillSources(page.income, income, 1, tin)
    FillSources(page.expenses, expenses, -1, tout)
    page.empty:SetShown(#income == 0 and #expenses == 0)
end

local function FillItems(page)
    local realm = GetRealmName()
    page.scope:SetText(L.GOLD_SCOPE_ITEMS:format(ns.Gold.RealmLabel(realm)))
    local list = ns.GoldLedger.TopItems(ns.GoldLedger.ItemsOf(ns.AccountDB(), realm), ITEM_ROWS)
    local best = list[1] and list[1].profit or 1
    for i, row in ipairs(page.rows) do
        local e = list[i]
        FillItemRow(row, e, best)
        row.SOLD:SetText(e and tostring(e.item.sellQty) or "")
        row.BOUGHT:SetText(e and tostring(e.item.buyQty) or "")
        if e then SetSigned(row.PROFIT, e.profit) else row.PROFIT:SetText("") end
    end
    page.empty:SetShown(#list == 0)
end

-- The data only; the look stays (Window.Style).
function Window.Fill()
    if not frame then return end
    local range, now, money = Window.Range(), ns.Gold.Now(), GetMoney() or 0
    local days = ns.CharDB().goldDays or {}
    local p = frame.pages
    for _, b in ipairs(frame.tabs) do PaintSwitch(b, b.id == Window.Tab()) end
    FillOverview(p.OVERVIEW, days, now, money)
    FillHistory(p.HISTORY, days, now, money, range)
    FillFlow(p.FLOW, days, now, range)
    FillItems(p.ITEMS)
    for _, c in ipairs(cards) do StyleCard(c) end
end

function Window.ShowTab(id)
    Stored().tab = Valid(Window.TABS, id, DEFAULT_TAB)
    for tab, page in pairs(frame.pages) do page:SetShown(tab == Window.Tab()) end
    Window.Fill()
end

function Window.Toggle()
    if not frame then Build() end
    if frame:IsShown() then
        frame:Hide()
        return
    end
    frame:Show()
    Window.Style()
    Window.ShowTab(Window.Tab())
end

function Window.Frame() return frame end

-- New money (Gold.lua, once booked) or an item's info from the server: the data; a new look: everything.
function Window.Update()
    if frame and frame:IsShown() then Window.Fill() end
end
-- An item's info arrived from the server: its icon, link and quality.
local itemInfo = CreateFrame("Frame")
pcall(itemInfo.RegisterEvent, itemInfo, "GET_ITEM_INFO_RECEIVED")
itemInfo:SetScript("OnEvent", Window.Update)
ns.Settings.OnChange(function()
    if frame and frame:IsShown() then
        Window.Style()
        Window.Fill()
    end
end)
