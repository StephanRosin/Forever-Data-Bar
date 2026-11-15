local ADDON, ns = ...
local L = ns.L
local S = ns.Settings.Get

--[[---------------------------------------------------------------------------
GoldWindow.lua -- the gold window, opened by a click on the gold part: this
character's balance over 7, 30 or 90 days, income and expenses per source
over the same days (GoldLedger.lua), and the auction house items with the
best realized profit. In the bar's theme (ThemeArt.StyleWindow); movable,
its place and range kept in ForeverDataBarDB.goldWindow; Escape closes it.
-----------------------------------------------------------------------------]]
local Window = {}
ns.GoldWindow = Window

Window.RANGES = { 7, 30, 90 }
local DEFAULT_RANGE = 30
local WIDTH, HEIGHT, INSET, TITLE_H, ROW_H = 520, 500, 12, 26, 16
local PLOT_W, PLOT_H = WIDTH - 2 * INSET - 70, 110   -- 70: the min/max column (Gold.NewGraph)
local SOURCE_ROWS, ITEM_ROWS = 7, 6
local TITLE_SIZE_ADD = 3
local NAME = "ForeverDataBarGold"
local GREY = { 0.8, 0.8, 0.8 }

local frame

local function Stored()
    local db = ns.AccountDB()
    db.goldWindow = db.goldWindow or {}
    return db.goldWindow
end

function Window.Range()
    local r = Stored().range
    for _, v in ipairs(Window.RANGES) do if v == r then return r end end
    return DEFAULT_RANGE
end

-- Every text takes the bar's body font; title: the theme's display font.
local texts = {}
local function Text(parent, role, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetJustifyH(justify or "LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    texts[#texts + 1] = { fs = fs, role = role }
    return fs
end

local function ApplyFonts()
    local path, size, outline, colour = ns.DataBar.FontFor("dataBar")
    local title = ns.Themes.TitleFont()
    for _, t in ipairs(texts) do
        if t.role == "title" then
            ns.DataBar.SetFont(t.fs, title and ns.Media.FontPath(title) or path, size + TITLE_SIZE_ADD, outline)
        else
            ns.DataBar.SetFont(t.fs, path, size, outline)
        end
        if t.role == "title" or t.role == "text" then t.fs:SetTextColor(colour[1], colour[2], colour[3], 1) end
        if t.role == "head" then
            local a = ns.Themes.Accent()
            t.fs:SetTextColor(a[1], a[2], a[3], 1)
        end
    end
end

local function Paint(fs, c) fs:SetTextColor(c[1], c[2], c[3], 1) end

-- A label left and a value right on one row.
local function Rows(parent, n, x, y, width)
    local rows = {}
    for i = 1, n do
        local label = Text(parent, "text")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - (i - 1) * ROW_H)
        label:SetWidth(width * 0.55)
        local value = Text(parent, "value", "RIGHT")
        value:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + width, y - (i - 1) * ROW_H)
        rows[i] = { label = label, value = value }
    end
    return rows
end

local function SavePlace()
    local point, _, relative, x, y = frame:GetPoint(1)
    Stored().place = { point, relative, x, y }
end

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
    bar:SetHeight(TITLE_H)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
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
    local close = CreateFrame("Button", nil, bar)
    close:SetSize(TITLE_H, TITLE_H)
    close:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    close.text = Text(close, "text", "CENTER")
    close.text:SetPoint("CENTER")
    close.text:SetText("x")
    close:SetScript("OnClick", function() frame:Hide() end)
    frame.close = close

    -- The range switch.
    frame.ranges = {}
    local x = INSET
    for i, days in ipairs(Window.RANGES) do
        local b = CreateFrame("Button", nil, frame)
        b:SetSize(70, ROW_H + 4)
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -(TITLE_H + 8))
        b.text = Text(b, "range", "LEFT")
        b.text:SetPoint("LEFT")
        b.text:SetText(L.GOLD_DAYS:format(days))
        b.days = days
        b:SetScript("OnClick", function()
            Stored().range = days
            Window.Refresh()
        end)
        frame.ranges[i] = b
        x = x + 80
    end

    local top = -(TITLE_H + 8 + ROW_H + 12)
    frame.graph = ns.Gold.NewGraph(frame, PLOT_W, PLOT_H)
    frame.graph:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET, top)
    frame.noGraph = Text(frame, "text")
    frame.noGraph:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET, top)
    frame.noGraph:SetText(L.GOLD_NOTHING)

    top = top - (PLOT_H + 14 + 14)
    local half = (WIDTH - 3 * INSET) / 2
    frame.incomeHead = Text(frame, "head")
    frame.incomeHead:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET, top)
    frame.incomeHead:SetText(L.GOLD_INCOME)
    frame.expenseHead = Text(frame, "head")
    frame.expenseHead:SetPoint("TOPLEFT", frame, "TOPLEFT", 2 * INSET + half, top)
    frame.expenseHead:SetText(L.GOLD_EXPENSES)
    frame.income = Rows(frame, SOURCE_ROWS, INSET, top - ROW_H - 2, half)
    frame.expenses = Rows(frame, SOURCE_ROWS, 2 * INSET + half, top - ROW_H - 2, half)

    top = top - (SOURCE_ROWS + 1) * ROW_H - 14
    frame.itemsHead = Text(frame, "head")
    frame.itemsHead:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET, top)
    frame.itemsHead:SetText(L.GOLD_ITEMS)
    frame.items = Rows(frame, ITEM_ROWS, INSET, top - ROW_H - 2, WIDTH - 2 * INSET)
    for _, row in ipairs(frame.items) do
        row.counts = Text(frame, "value", "RIGHT")
        row.counts:SetPoint("TOPRIGHT", row.value, "TOPLEFT", -12, 0)
    end

    frame:Hide()
    if UISpecialFrames then
        local listed = false
        for _, n in ipairs(UISpecialFrames) do if n == NAME then listed = true end end
        if not listed then table.insert(UISpecialFrames, NAME) end
    end
end

local function FillSources(rows, list, sign)
    for i, row in ipairs(rows) do
        local e = list[i]
        row.label:SetText(e and L["GOLD_SRC_" .. e.source] or (i == 1 and L.GOLD_NOTHING or ""))
        local text, c = ns.Gold.Signed(e and e.amount * sign or 0)
        row.value:SetText(e and text or "")
        Paint(row.value, c)
    end
end

function Window.Style()
    if not frame then return end
    ns.ThemeArt.StyleWindow(frame, frame.titleBar)
    frame.title:ClearAllPoints()
    frame.title:SetPoint("LEFT", frame.titleBar, "LEFT", ns.ThemeArt.TextStart(TITLE_H) or INSET, 0)
    ApplyFonts()
end

function Window.Refresh()
    if not frame then return end
    Window.Style()
    local range, now = Window.Range(), ns.Gold.Now()
    local accent, colour = ns.Themes.Accent(), select(4, ns.DataBar.FontFor("dataBar"))
    for _, b in ipairs(frame.ranges) do Paint(b.text, b.days == range and accent or colour) end

    local days = ns.CharDB().goldDays or {}
    local drawn = ns.Gold.DrawGraph(frame.graph, ns.Gold.GraphPoints(days, now, GetMoney() or 0, range))
    frame.noGraph:SetShown(not drawn)

    local income, expenses = ns.GoldLedger.Totals(days, ns.Gold.LastKeys(now, range))
    FillSources(frame.income, income, 1)
    FillSources(frame.expenses, expenses, -1)

    local items = ns.GoldLedger.TopItems(ns.GoldLedger.ItemsOf(ns.AccountDB(), GetRealmName()), ITEM_ROWS)
    for i, row in ipairs(frame.items) do
        local e = items[i]
        row.label:SetText(e and e.name or (i == 1 and L.GOLD_NOTHING or ""))
        row.counts:SetText(e and L.GOLD_ITEM_COUNTS:format(e.item.sellQty, e.item.buyQty) or "")
        Paint(row.counts, GREY)
        local text, c = ns.Gold.Signed(e and e.profit or 0)
        row.value:SetText(e and text or "")
        Paint(row.value, c)
    end
end

function Window.Toggle()
    if not frame then Build() end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        Window.Refresh()
    end
end

function Window.Frame() return frame end

-- New money (Gold.lua, once booked) or a new look while open.
function Window.Update()
    if frame and frame:IsShown() then Window.Refresh() end
end
ns.Settings.OnChange(Window.Update)
