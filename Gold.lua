local ADDON, ns = ...
local L = ns.L

--[[---------------------------------------------------------------------------
Gold.lua -- the gold part's tooltip: the session since login, this
character's days (today, yesterday, this week), the realm's characters with
a total, and a curve of this character's balance.

Every PLAYER_MONEY counts the difference to the last reading: up is gained,
down is spent (mail, auction house, vendors alike). The reading at login is
the baseline and counts nothing.

Stored (copper):
  ForeverDataBarChar.goldSession = { start, gained, spent, last }  -- survives /reload
  ForeverDataBarChar.goldDays = { ["YYYY-MM-DD"] = { gained, spent, close, inc, out } }
    (inc/out: per source, GoldLedger.lua)
  ForeverDataBarDB.goldChars = { ["Name-Realm"] = { name, realm, class, money } }
A day is the local calendar date; a week starts on Monday (ISO 8601), the
usual start in the addon's European languages.
-----------------------------------------------------------------------------]]
local Gold = {}
ns.Gold = Gold

Gold.KEEP_DAYS = 90     -- day records older than this are dropped (the window shows up to 90)
Gold.GRAPH_DAYS = 30    -- the tooltip curve's span, today included
local NOON = 12         -- days are counted at noon: summer time never skips or repeats one
local DAYS_SINCE_MONDAY_SHIFT = 5   -- date's wday counts from Sunday = 1
local SECONDS_PER_HOUR = 3600
Gold.MIN_RATE_SECONDS = 300
local COPPER_PER_GOLD, COPPER_PER_SILVER = 10000, 100

local GREY, WHITE = { 0.8, 0.8, 0.8 }, { 1, 1, 1 }
local COLOUR_GAIN, COLOUR_LOSS = { 0.3, 1, 0.3 }, { 1, 0.25, 0.2 }

-- The curve: plot area (the tooltip's), the min/max column right of it, the date row below.
local PLOT_W, PLOT_H, LABEL_W, LABEL_GAP, DATE_ROW = 150, 60, 70, 4, 14
local LINE_THICKNESS, AXIS_ALPHA = 2, 0.35
-- Blank tooltip lines for the curve: the line's font size plus Blizzard's spacing.
local TIP_LINE_FALLBACK, TIP_LINE_SPACING = 12, 2

function Gold.Now() return time() end

local function DayTime(t, back)
    local d = date("*t", t)
    return time({ year = d.year, month = d.month, day = d.day - (back or 0), hour = NOON })
end

-- The local date `back` days before t, as "YYYY-MM-DD".
function Gold.DayKey(t, back) return date("%Y-%m-%d", DayTime(t, back)) end

-- Monday of this week up to today.
function Gold.WeekKeys(now)
    local keys = {}
    for back = 0, (date("*t", now).wday + DAYS_SINCE_MONDAY_SHIFT) % 7 do keys[#keys + 1] = Gold.DayKey(now, back) end
    return keys
end

function Gold.Sum(days, keys)
    local gained, spent = 0, 0
    for _, k in ipairs(keys) do
        local d = days[k]
        if d then gained, spent = gained + d.gained, spent + d.spent end
    end
    return gained, spent
end

-- Keys sort like dates, so older days compare smaller.
function Gold.Prune(days, now)
    local oldest = Gold.DayKey(now, Gold.KEEP_DAYS - 1)
    for k in pairs(days) do
        if k < oldest then days[k] = nil end
    end
end

-- Today's record with the money as its closing balance.
function Gold.Close(char, money, now)
    char.goldDays = char.goldDays or {}
    local key = Gold.DayKey(now)
    local day = char.goldDays[key]
    if not day then
        day = { gained = 0, spent = 0 }
        char.goldDays[key] = day
        Gold.Prune(char.goldDays, now)
    end
    day.close = money
    return day
end

function Gold.StartSession(char, money, now)
    char.goldSession = { start = now, gained = 0, spent = 0, last = money }
    Gold.Close(char, money, now)
end

function Gold.Update(char, money, now)
    local s = char.goldSession
    if not s then return Gold.StartSession(char, money, now) end
    local delta = money - s.last
    s.last = money
    local day = Gold.Close(char, money, now)
    if delta > 0 then
        s.gained, day.gained = s.gained + delta, day.gained + delta
    elseif delta < 0 then
        s.spent, day.spent = s.spent - delta, day.spent - delta
    end
    if delta ~= 0 then ns.GoldLedger.Book(day, delta) end
end

-- nil before MIN_RATE_SECONDS: a few minutes say nothing about an hour.
function Gold.PerHour(net, seconds)
    if not seconds or seconds < Gold.MIN_RATE_SECONDS then return nil end
    return net / seconds * SECONDS_PER_HOUR
end

-- All characters of every realm and faction, account wide.
function Gold.Remember(account, name, realm, class, money)
    account.goldChars = account.goldChars or {}
    account.goldChars[name .. "-" .. realm] = { name = name, realm = realm, class = class, money = money }
end

-- The realm as the realm list shows it: Forever's internal "CAMWOW EU4 Realm 7 PvE"
-- is "EU PvE" there; any other name stays as it is. Data stays under the internal name.
function Gold.RealmLabel(realm)
    local region, kind = realm:match("^CAMWOW%s*(%a+)%d*%s*Realm%s*%d+%s*(.+)$")
    return region and (region .. " " .. kind) or realm
end

-- The realm's characters, richest first, and their total.
function Gold.RealmChars(account, realm)
    local list, total = {}, 0
    for _, c in pairs(account.goldChars or {}) do
        if c.realm == realm then
            list[#list + 1] = c
            total = total + c.money
        end
    end
    table.sort(list, function(a, b)
        if a.money ~= b.money then return a.money > b.money end
        return a.name < b.name
    end)
    return list, total
end

-- The last `span` days' keys, today first.
function Gold.LastKeys(now, span)
    local keys = {}
    for back = 0, span - 1 do keys[#keys + 1] = Gold.DayKey(now, back) end
    return keys
end

-- One point per day over `span` days (GRAPH_DAYS) from the first recorded
-- day on: the closing balance, a day without a record keeps the day
-- before's, today is the money now.
-- A balance from before the span carries into it. back: days before today.
function Gold.GraphPoints(days, now, money, span)
    span = span or Gold.GRAPH_DAYS
    local first, seedKey, last = Gold.DayKey(now, span - 1), nil, nil
    for k, d in pairs(days) do
        if k < first and d.close and (not seedKey or k > seedKey) then seedKey, last = k, d.close end
    end
    local points = {}
    for back = span - 1, 1, -1 do
        local d = days[Gold.DayKey(now, back)]
        last = d and d.close or last
        if last then points[#points + 1] = { t = DayTime(now, back), back = back, value = last } end
    end
    points[#points + 1] = { t = DayTime(now, 0), back = 0, value = money }
    return points
end

function Gold.Range(points)
    local lo, hi = math.huge, -math.huge
    for _, p in ipairs(points) do lo, hi = math.min(lo, p.value), math.max(hi, p.value) end
    return lo, hi
end

-- -----------------------------------------------------------------------------
-- The tooltip
-- -----------------------------------------------------------------------------
-- Copper as the bar writes it ("12g 3s"); below a silver the copper ("50c").
function Gold.Money(copper)
    if copper > 0 and copper < COPPER_PER_SILVER then return L.GOLD_COPPER:format(copper) end
    return ns.DataBar.GoldText(copper)
end

-- "+12g 3s" / "-4g 0s" / "+50c" / "0g 0s" and its colour.
function Gold.Signed(copper)
    local text = Gold.Money(math.abs(copper))
    if copper > 0 then return "+" .. text, COLOUR_GAIN end
    if copper < 0 then return "-" .. text, COLOUR_LOSS end
    return text, WHITE
end

local function Paint(text, c)
    return ("|cff%02x%02x%02x%s|r"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255), text)
end

local function Row(label, value, c, lc)
    c, lc = c or WHITE, lc or GREY
    GameTooltip:AddDoubleLine(label, value, lc[1], lc[2], lc[3], c[1], c[2], c[3])
end

local function SignedRow(label, copper)
    local text, c = Gold.Signed(copper)
    Row(label, text, c)
end

-- "+8g 0s (+12g 0s / -4g 0s)": net, then gained and spent; a dash for a day without any.
Gold.NONE = "–"
function Gold.DayText(gained, spent)
    if gained == 0 and spent == 0 then return Paint(Gold.NONE, GREY) end
    return Paint(Gold.Signed(gained - spent)) .. " " .. Paint("(", GREY) .. Paint(Gold.Signed(gained))
        .. Paint(" / ", GREY) .. Paint(Gold.Signed(-spent)) .. Paint(")", GREY)
end

-- A curve plotW x plotH with min/max right of it and the dates below, a
-- baseline and a left edge; g.labels for a window's fonts.
function Gold.NewGraph(parent, plotW, plotH)
    local g = CreateFrame("Frame", nil, parent)
    -- The size kept too: read back from a frame on the tooltip it can be secret.
    g.width, g.height = plotW + LABEL_W, plotH + DATE_ROW
    g:SetSize(g.width, g.height)
    g.plotW, g.plotH, g.lines = plotW, plotH, {}
    g.axes = {}
    for i, size in ipairs({ { plotW, 1 }, { 1, plotH } }) do
        local t = g:CreateTexture(nil, "BORDER")
        t:SetSize(size[1], size[2])
        t:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 0, DATE_ROW)
        t:SetColorTexture(GREY[1], GREY[2], GREY[3], AXIS_ALPHA)
        g.axes[i] = t
    end
    local function Label(point, x, y, justify)
        local fs = g:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint(point, g, "BOTTOMLEFT", x, y)
        fs:SetJustifyH(justify)
        fs:SetTextColor(GREY[1], GREY[2], GREY[3])
        return fs
    end
    g.max = Label("TOPLEFT", plotW + LABEL_GAP, DATE_ROW + plotH, "LEFT")
    g.min = Label("BOTTOMLEFT", plotW + LABEL_GAP, DATE_ROW, "LEFT")
    g.first = Label("BOTTOMLEFT", 0, 0, "LEFT")
    g.last = Label("BOTTOMRIGHT", plotW, 0, "RIGHT")
    g.labels = { g.max, g.min, g.first, g.last }
    return g
end

-- The curve in the theme's accent over `span` days, each point at its day
-- (a short history stays at the right end); false below two points.
function Gold.DrawGraph(g, points, span)
    span = span or Gold.GRAPH_DAYS
    for _, line in ipairs(g.lines) do line:Hide() end
    for _, fs in ipairs(g.labels) do fs:SetText("") end
    if #points < 2 then return false end
    local lo, hi = Gold.Range(points)
    local c = ns.Themes.Accent()
    local function XY(i)
        local share = hi > lo and (points[i].value - lo) / (hi - lo) or 0.5
        return (span - 1 - points[i].back) / (span - 1) * g.plotW, DATE_ROW + share * g.plotH
    end
    for i = 2, #points do
        local line = g.lines[i - 1] or g:CreateLine(nil, "ARTWORK")
        g.lines[i - 1] = line
        line:SetThickness(LINE_THICKNESS)
        line:SetColorTexture(c[1], c[2], c[3], 1)
        local x1, y1 = XY(i - 1)
        local x2, y2 = XY(i)
        line:SetStartPoint("BOTTOMLEFT", g, x1, y1)
        line:SetEndPoint("BOTTOMLEFT", g, x2, y2)
        line:Show()
    end
    g.max:SetText(Gold.Money(hi))
    g.min:SetText(Gold.Money(lo))
    g.first:ClearAllPoints()
    g.first:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", (XY(1)), 0)
    g.first:SetText(date(L.GOLD_DATE, points[1].t))
    g.last:SetText(date(L.GOLD_DATE, points[#points].t))
    return true
end

-- The tooltip's curve: parented and anchored here over blank lines, not
-- through GameTooltip_InsertFrame (addon code writing the tooltip's
-- insertedFrames would taint Blizzard's callers). It hides with the
-- tooltip or when the tooltip is cleared for someone else, and then gives
-- the tooltip its normal width back.
local tipGraph
function Gold.TooltipGraph()
    if tipGraph then return tipGraph end
    tipGraph = Gold.NewGraph(GameTooltip, PLOT_W, PLOT_H)
    tipGraph:Hide()
    tipGraph:SetScript("OnHide", function() GameTooltip:SetMinimumWidth(0) end)
    GameTooltip:HookScript("OnTooltipCleared", function() tipGraph:Hide() end)
    return tipGraph
end

local function EmbedGraph(g)
    local first = GameTooltip:NumLines() + 1
    -- Sizes from the font object and our own numbers, never read back from
    -- the tooltip's lines or frames: those can be secret values once another
    -- addon has filled the tooltip, and arithmetic on them errors.
    local _, size = GameTooltipText:GetFont()
    if issecretvalue and issecretvalue(size) then size = nil end
    for _ = 1, math.ceil(g.height / ((size or TIP_LINE_FALLBACK) + TIP_LINE_SPACING)) do GameTooltip:AddLine(" ") end
    g:ClearAllPoints()
    g:SetPoint("TOPLEFT", GameTooltip:GetLeftLine(first), "TOPLEFT", 0, 0)
    GameTooltip:SetMinimumWidth(g.width)
    g:Show()
end

function Gold.FillTooltip()
    local money, now = GetMoney() or 0, Gold.Now()
    local char = ns.CharDB()
    GameTooltip:AddLine(L.DATABAR_PART_GOLD, 1, 1, 1)
    GameTooltip:AddLine(("%dg %ds %dc"):format(math.floor(money / COPPER_PER_GOLD),
        math.floor(money % COPPER_PER_GOLD / COPPER_PER_SILVER), money % COPPER_PER_SILVER), 1, 1, 1)

    local s = char.goldSession
    if s then
        local seconds = now - s.start
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.GOLD_SESSION:format(ns.Xp.Duration(seconds)), 1, 1, 1)
        SignedRow(L.GOLD_GAINED, s.gained)
        SignedRow(L.GOLD_SPENT, -s.spent)
        SignedRow(L.GOLD_NET, s.gained - s.spent)
        local rate = Gold.PerHour(s.gained - s.spent, seconds)
        if rate then SignedRow(L.GOLD_PER_HOUR, math.floor(rate + 0.5)) else Row(L.GOLD_PER_HOUR, Gold.NONE) end
    end

    local days = char.goldDays or {}
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.GOLD_CHARACTER, 1, 1, 1)
    Row(L.GOLD_TODAY, Gold.DayText(Gold.Sum(days, { Gold.DayKey(now) })))
    Row(L.GOLD_YESTERDAY, Gold.DayText(Gold.Sum(days, { Gold.DayKey(now, 1) })))
    Row(L.GOLD_WEEK, Gold.DayText(Gold.Sum(days, Gold.WeekKeys(now))))

    local realm = GetRealmName()
    local list, total = Gold.RealmChars(ns.AccountDB(), realm)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.GOLD_REALM:format(Gold.RealmLabel(realm)), 1, 1, 1)
    for _, c in ipairs(list) do
        local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
        Row(c.name, Gold.Money(c.money), WHITE, cc and { cc.r, cc.g, cc.b })
    end
    Row(L.GOLD_TOTAL, Gold.Money(total), WHITE, WHITE)

    local g = Gold.TooltipGraph()
    if Gold.DrawGraph(g, Gold.GraphPoints(days, now, money)) then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.GOLD_GRAPH:format(Gold.GRAPH_DAYS), 1, 1, 1)
        EmbedGraph(g)
    end
    GameTooltip:AddLine(L.GOLD_CLICK, 0.4, 0.8, 1)
    GameTooltip:Show()
end

local function Record(isLogin)
    local char, money, now = ns.CharDB(), GetMoney() or 0, Gold.Now()
    if isLogin or not char.goldSession then
        Gold.StartSession(char, money, now)
    else
        Gold.Update(char, money, now)
    end
    Gold.Remember(ns.AccountDB(), UnitName("player"), GetRealmName(), select(2, UnitClass("player")), money)
    ns.GoldWindow.Update()
end

-- Money changes count only after this UI's first PLAYER_ENTERING_WORLD:
-- one before it would compare against last login's reading.
local entered = false
local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_MONEY" }) do events:RegisterEvent(e) end
events:SetScript("OnEvent", function(_, event, isLogin)
    if event == "PLAYER_ENTERING_WORLD" then entered = true elseif not entered then return end
    -- A fresh login starts a session; /reload and loading screens keep it.
    Record(event == "PLAYER_ENTERING_WORLD" and isLogin)
end)
