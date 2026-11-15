local ADDON, ns = ...
local L = ns.L

--[[---------------------------------------------------------------------------
GoldWindow.lua -- the gold window, opened by a click on the gold part, in
four tabs: Overview (the money now, today and this week, tiles for the
session, all characters, today's biggest income and expense, the best
auction item, a 7-day curve), History (this character's balance over 7, 30
or 90 days), Income & expenses (per source over the same range,
GoldLedger.lua) and Items (the auction items with the best realized profit,
all characters of the realm, all time).

In the bar's theme (ThemeArt.StyleWindow): the accent draws only the curves
and marks the chosen tab and range; headings take the theme's display font
in the text colour, gains and losses keep green and red. Row heights follow
the bar's font size. Movable; place, tab and range kept in
ForeverDataBarDB.goldWindow; Escape closes it. A money change refills the
data only, a new look restyles.
-----------------------------------------------------------------------------]]
local Window = {}
ns.GoldWindow = Window

Window.RANGES = { 7, 30, 90 }
Window.TABS = { "OVERVIEW", "HISTORY", "FLOW", "ITEMS" }
local DEFAULT_RANGE, DEFAULT_TAB = 30, "OVERVIEW"
local OVERVIEW_DAYS = 7

local NAME = "ForeverDataBarGold"
local WIDTH, HEIGHT, INSET, GAP = 560, 540, 12, 8
local CONTENT_W = WIDTH - 2 * INSET
local GRAPH_LABEL_W = 70                 -- Gold.NewGraph's min/max column
local HISTORY_PLOT_H, OVERVIEW_PLOT_H = 230, 70
local ROW_PAD, TITLE_PAD, TAB_PAD = 6, 12, 10   -- around a text of the font's size
local TITLE_SIZE_ADD, BIG_SIZE_ADD = 3, 9
local UNDERLINE_H, CROSS_SIZE, CROSS_ANGLE = 2, 12, math.pi / 4
local TAB_MIN_W, RANGE_W = 70, 64
local MUTED_ALPHA = 0.6
local SOURCE_ROWS, ITEM_ROWS = 10, 12
local ITEM_COLUMNS = { SOLD = 70, BOUGHT = 70, PROFIT = 100 }   -- widths from the right, fixed
local LABEL_SHARE = 0.6                  -- a row's label of its width; the value takes the rest
local TILES_PER_ROW = 3

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
-- title, value (font only: its colour means gain or loss).
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
    local fonts = { title = { display, size + TITLE_SIZE_ADD }, head = { display, size }, big = { display, size + BIG_SIZE_ADD } }
    for _, t in ipairs(texts) do
        local f = fonts[t.role] or { path, size }
        ns.DataBar.SetFont(t.fs, f[1], f[2], outline)
        if t.role == "muted" then Paint(t.fs, colour, MUTED_ALPHA)
        elseif t.role ~= "value" then Paint(t.fs, colour) end
    end
end

-- -----------------------------------------------------------------------------
-- Building blocks
-- -----------------------------------------------------------------------------
-- A tab or range button: fainter until hovered, the chosen one underlined in the accent.
local buttons = {}
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
    buttons[#buttons + 1] = b
    return b
end

local function PaintSwitch(b, chosen)
    b.chosen = chosen
    Paint(b.text, TextColour(), chosen and 1 or MUTED_ALPHA)
    local a = ns.Themes.Accent()
    b.underline:SetColorTexture(a[1], a[2], a[3], 1)
    b.underline:SetShown(chosen)
end

-- Rows of a label left and a value right, `width` wide.
local function Rows(parent, n, width)
    local rows = { width = width }
    for i = 1, n do
        local label = Text(parent, "text")
        label:SetWidth(width * LABEL_SHARE)
        rows[i] = { label = label, value = Text(parent, "value", "RIGHT") }
    end
    return rows
end

local function PlaceRows(rows, parent, x, y)
    local h = RowH()
    for i, row in ipairs(rows) do
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - (i - 1) * h)
        row.value:ClearAllPoints()
        row.value:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + rows.width, y - (i - 1) * h)
    end
    return y - #rows * h
end

-- A tile on the overview: a card with a heading and one value.
local function Tile(parent, heading)
    local t = CreateFrame("Frame", nil, parent)
    t.fill = t:CreateTexture(nil, "BACKGROUND")
    t.fill:SetAllPoints(t)
    t.head = Text(t, "head")
    t.head:SetPoint("TOPLEFT", t, "TOPLEFT", GAP, -GAP / 2)
    t.head:SetText(heading)
    t.value = Text(t, "value")
    t.value:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", GAP, GAP / 2)
    t.value:SetPoint("RIGHT", t, "RIGHT", -GAP, 0)
    return t
end

local function Graph(parent, plotH)
    local g = ns.Gold.NewGraph(parent, CONTENT_W - GRAPH_LABEL_W, plotH)
    for _, fs in ipairs(g.labels) do Register(fs, "muted") end
    g.empty = Text(parent, "muted")
    g.empty:SetPoint("CENTER", g, "CENTER")
    g.empty:SetText(L.GOLD_EMPTY_CURVE)
    return g
end

-- A text in the section's place while it has nothing to show.
local function Empty(parent, text)
    local fs = Text(parent, "muted")
    fs:SetText(text)
    return fs
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
        local c = TextColour()
        for _, t in ipairs(b.lines) do t:SetColorTexture(c[1], c[2], c[3], alpha) end
    end
    b:SetScript("OnEnter", function() b.Paint(1) end)
    b:SetScript("OnLeave", function() b.Paint(MUTED_ALPHA) end)
    b:SetScript("OnClick", function() frame:Hide() end)
    return b
end

local function BuildOverview(page)
    page.money = Text(page, "big")
    page.today = Text(page, "value")
    page.week = Text(page, "value")
    page.tiles = {
        Tile(page, L.GOLD_TILE_SESSION), Tile(page, L.GOLD_TILE_ALL), Tile(page, L.GOLD_TILE_ITEM),
        Tile(page, L.GOLD_TILE_INCOME), Tile(page, L.GOLD_TILE_EXPENSE),
    }
    page.curveHead = Text(page, "head")
    page.curveHead:SetText(L.GOLD_SCOPE_CHAR:format(OVERVIEW_DAYS))
    page.graph = Graph(page, OVERVIEW_PLOT_H)
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
end

local function BuildHistory(page)
    RangeSwitch(page)
    page.scope = Text(page, "head")
    page.graph = Graph(page, HISTORY_PLOT_H)
end

local function BuildFlow(page)
    RangeSwitch(page)
    page.scope = Text(page, "head")
    local half = (CONTENT_W - GAP) / 2
    page.incomeHead = Text(page, "head")
    page.incomeHead:SetText(L.GOLD_INCOME)
    page.expenseHead = Text(page, "head")
    page.expenseHead:SetText(L.GOLD_EXPENSES)
    page.income = Rows(page, SOURCE_ROWS, half)
    page.expenses = Rows(page, SOURCE_ROWS, half)
    page.empty = Empty(page, L.GOLD_EMPTY_SOURCES)
end

local function BuildItems(page)
    page.scope = Text(page, "head")
    page.columns = {}
    for _, key in ipairs({ "ITEM", "SOLD", "BOUGHT", "PROFIT" }) do
        page.columns[key] = Text(page, "head", key == "ITEM" and "LEFT" or "RIGHT")
        page.columns[key]:SetText(L["GOLD_COL_" .. key])
    end
    page.rows = {}
    for i = 1, ITEM_ROWS do
        local row = {}
        row.name = Text(page, "text")
        row.name:SetWidth(CONTENT_W - ITEM_COLUMNS.SOLD - ITEM_COLUMNS.BOUGHT - ITEM_COLUMNS.PROFIT)
        for _, key in ipairs({ "SOLD", "BOUGHT", "PROFIT" }) do
            row[key] = Text(page, key == "PROFIT" and "value" or "text", "RIGHT")
            row[key]:SetWidth(ITEM_COLUMNS[key])
        end
        page.rows[i] = row
    end
    page.empty = Empty(page, L.GOLD_EMPTY_ITEMS)
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
local function LayoutOverview(page)
    local h, y = RowH(), 0
    page.money:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
    y = y - (FontSize() + BIG_SIZE_ADD + ROW_PAD)
    page.today:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
    page.week:SetPoint("TOPLEFT", page, "TOPLEFT", CONTENT_W / 2, y)
    y = y - h - GAP
    local tileH = 2 * h + GAP
    local third = (CONTENT_W - (TILES_PER_ROW - 1) * GAP) / TILES_PER_ROW
    local half = (CONTENT_W - GAP) / 2
    for i, t in ipairs(page.tiles) do
        local top = i <= TILES_PER_ROW
        local w = top and third or half
        local col = top and (i - 1) or (i - TILES_PER_ROW - 1)
        t:SetSize(w, tileH)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", page, "TOPLEFT", col * (w + GAP), top and y or y - tileH - GAP)
    end
    y = y - 2 * (tileH + GAP) - GAP
    page.curveHead:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
    page.graph:ClearAllPoints()
    page.graph:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y - h - GAP / 2)
end

local function LayoutRanges(page)
    local h = RowH()
    for i, b in ipairs(page.ranges) do
        b:SetSize(RANGE_W, h + UNDERLINE_H + 2)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", page, "TOPLEFT", (i - 1) * (RANGE_W + GAP) - 4, 0)
    end
    page.scope:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -(h + UNDERLINE_H + GAP))
    return -(2 * h + UNDERLINE_H + 2 * GAP)
end

local function LayoutHistory(page)
    local y = LayoutRanges(page)
    page.graph:ClearAllPoints()
    page.graph:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
end

local function LayoutFlow(page)
    local y = LayoutRanges(page)
    local half = (CONTENT_W - GAP) / 2
    page.incomeHead:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
    page.expenseHead:SetPoint("TOPLEFT", page, "TOPLEFT", half + GAP, y)
    y = y - RowH() - GAP / 2
    PlaceRows(page.income, page, 0, y)
    PlaceRows(page.expenses, page, half + GAP, y)
    page.empty:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
end

local function LayoutItems(page)
    local h = RowH()
    page.scope:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    local y = -(h + GAP)
    local function columns(row, at)
        local right = CONTENT_W
        for _, key in ipairs({ "PROFIT", "BOUGHT", "SOLD" }) do
            row[key]:ClearAllPoints()
            row[key]:SetPoint("TOPRIGHT", page, "TOPLEFT", right, at)
            right = right - ITEM_COLUMNS[key]
        end
    end
    page.columns.ITEM:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
    for _, key in ipairs({ "SOLD", "BOUGHT", "PROFIT" }) do page.columns[key]:SetWidth(ITEM_COLUMNS[key]) end
    columns(page.columns, y)
    for i, row in ipairs(page.rows) do
        local at = y - i * h
        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", page, "TOPLEFT", 0, at)
        columns(row, at)
    end
    page.empty:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y - h)
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
    frame.title:SetPoint("LEFT", bar, "LEFT", ns.ThemeArt.TextStart(titleH) or INSET, 0)
    frame.close:SetSize(titleH, titleH)
    frame.close:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    frame.close.Paint(MUTED_ALPHA)

    local tabH, x = size + TAB_PAD, INSET - 4
    for _, b in ipairs(frame.tabs) do
        b:SetSize(math.max(TAB_MIN_W, (b.text:GetStringWidth() or 0) + 2 * GAP), tabH)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", x - rim, -GAP / 2)
        x = x + b:GetWidth()
    end
    local card = ns.ThemeArt.CardColour()
    for id, page in pairs(frame.pages) do
        page:ClearAllPoints()
        page:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", INSET - rim, -(tabH + GAP + GAP / 2))
        page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -INSET, INSET)
        LAYOUT[id](page)
        for _, t in ipairs(page.tiles or {}) do t.fill:SetColorTexture(card[1], card[2], card[3], card[4]) end
    end
    ApplyFonts()
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

local function FillOverview(page, days, now, money)
    local G, Ledger = ns.Gold, ns.GoldLedger
    page.money:SetText(G.Money(money))
    local gained, spent = G.Sum(days, { G.DayKey(now) })
    SetSigned(page.today, gained - spent, L.GOLD_TODAY .. "  ")
    gained, spent = G.Sum(days, G.WeekKeys(now))
    SetSigned(page.week, gained - spent, L.GOLD_WEEK .. "  ")

    local session, all, item, income, expense = unpack(page.tiles)
    local s = ns.CharDB().goldSession
    if s then
        local net = s.gained - s.spent
        local rate = G.PerHour(net, now - s.start)
        local perHour = rate and L.GOLD_PER_HOUR_SHORT:format((G.Signed(math.floor(rate + 0.5)))) or G.NONE
        SetSigned(session.value, net)
        session.value:SetText(session.value:GetText() .. "   " .. perHour)
    else
        SetDash(session.value)
    end
    local _, total = G.RealmChars(ns.AccountDB(), GetRealmName())
    all.value:SetText(G.Money(total))
    Paint(all.value, TextColour())
    local best = Ledger.TopItems(Ledger.ItemsOf(ns.AccountDB(), GetRealmName()), 1)[1]
    if best then
        SetSigned(item.value, best.profit, best.name .. "  ")
    else
        SetDash(item.value)
    end
    local inc, out = Ledger.Totals(days, { G.DayKey(now) })
    if inc[1] then SetSigned(income.value, inc[1].amount, L["GOLD_SRC_" .. inc[1].source] .. "  ") else SetDash(income.value) end
    if out[1] then SetSigned(expense.value, -out[1].amount, L["GOLD_SRC_" .. out[1].source] .. "  ") else SetDash(expense.value) end

    page.graph.empty:SetShown(not G.DrawGraph(page.graph, G.GraphPoints(days, now, money, OVERVIEW_DAYS), OVERVIEW_DAYS))
end

local function FillRanges(page, range)
    for _, b in ipairs(page.ranges) do PaintSwitch(b, b.days == range) end
    page.scope:SetText(L.GOLD_SCOPE_CHAR:format(range))
end

local function FillSources(rows, list, sign)
    for i, row in ipairs(rows) do
        local e = list[i]
        row.label:SetText(e and L["GOLD_SRC_" .. e.source] or "")
        if e then SetSigned(row.value, e.amount * sign) else row.value:SetText("") end
    end
end

local function FillItems(page)
    local realm = GetRealmName()
    page.scope:SetText(L.GOLD_SCOPE_ITEMS:format(ns.Gold.RealmLabel(realm)))
    local list = ns.GoldLedger.TopItems(ns.GoldLedger.ItemsOf(ns.AccountDB(), realm), ITEM_ROWS)
    for i, row in ipairs(page.rows) do
        local e = list[i]
        row.name:SetText(e and e.name or "")
        row.SOLD:SetText(e and tostring(e.item.sellQty) or "")
        row.BOUGHT:SetText(e and tostring(e.item.buyQty) or "")
        if e then SetSigned(row.PROFIT, e.profit) else row.PROFIT:SetText("") end
    end
    page.empty:SetShown(#list == 0)
end

-- The data only; the look stays (Window.Style).
function Window.Fill()
    if not frame then return end
    local G, range, now, money = ns.Gold, Window.Range(), ns.Gold.Now(), GetMoney() or 0
    local days = ns.CharDB().goldDays or {}
    local p = frame.pages
    for _, b in ipairs(frame.tabs) do PaintSwitch(b, b.id == Window.Tab()) end
    FillOverview(p.OVERVIEW, days, now, money)
    FillRanges(p.HISTORY, range)
    p.HISTORY.graph.empty:SetShown(not G.DrawGraph(p.HISTORY.graph, G.GraphPoints(days, now, money, range), range))
    FillRanges(p.FLOW, range)
    local income, expenses = ns.GoldLedger.Totals(days, G.LastKeys(now, range))
    FillSources(p.FLOW.income, income, 1)
    FillSources(p.FLOW.expenses, expenses, -1)
    p.FLOW.empty:SetShown(#income == 0 and #expenses == 0)
    FillItems(p.ITEMS)
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

-- New money (Gold.lua, once booked): the data; a new look: everything.
function Window.Update()
    if frame and frame:IsShown() then Window.Fill() end
end
ns.Settings.OnChange(function()
    if frame and frame:IsShown() then
        Window.Style()
        Window.Fill()
    end
end)
