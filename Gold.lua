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
  ForeverDataBarChar.goldDays = { ["YYYY-MM-DD"] = { gained, spent, close } }
  ForeverDataBarDB.goldChars = { ["Name-Realm"] = { name, realm, class, money } }
A day is the local calendar date; a week starts on Monday (ISO 8601), the
usual start in the addon's European languages.
-----------------------------------------------------------------------------]]
local Gold = {}
ns.Gold = Gold

Gold.KEEP_DAYS = 60     -- day records older than this are dropped
Gold.GRAPH_DAYS = 30    -- the curve's span, today included
local NOON = 12         -- days are counted at noon: summer time never skips or repeats one
local DAYS_SINCE_MONDAY_SHIFT = 5   -- date's wday counts from Sunday = 1
local SECONDS_PER_HOUR = 3600
local COPPER_PER_GOLD, COPPER_PER_SILVER = 10000, 100

local GREY, WHITE = { 0.8, 0.8, 0.8 }, { 1, 1, 1 }
local COLOUR_GAIN, COLOUR_LOSS = { 0.3, 1, 0.3 }, { 1, 0.25, 0.2 }

-- The curve: plot area, the min/max column right of it, the date row below.
local PLOT_W, PLOT_H, LABEL_W, DATE_ROW = 150, 60, 70, 14
local LINE_THICKNESS = 2

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
end

function Gold.PerHour(net, seconds)
    if not seconds or seconds <= 0 then return nil end
    return net / seconds * SECONDS_PER_HOUR
end

-- All characters of every realm and faction, account wide.
function Gold.Remember(account, name, realm, class, money)
    account.goldChars = account.goldChars or {}
    account.goldChars[name .. "-" .. realm] = { name = name, realm = realm, class = class, money = money }
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

-- One point per day over GRAPH_DAYS from the first recorded day on: the
-- closing balance, a day without a record keeps the day before's, today is
-- the money now.
function Gold.GraphPoints(days, now, money)
    local points, last = {}, nil
    for back = Gold.GRAPH_DAYS - 1, 1, -1 do
        local d = days[Gold.DayKey(now, back)]
        last = d and d.close or last
        if last then points[#points + 1] = { t = DayTime(now, back), value = last } end
    end
    points[#points + 1] = { t = DayTime(now, 0), value = money }
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
-- "+12g 3s" / "-4g 0s" / "0g 0s" and its colour.
function Gold.Signed(copper)
    local text = ns.DataBar.GoldText(math.abs(copper))
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

-- "+8g 0s (+12g 0s / -4g 0s)": net, then gained and spent.
function Gold.DayText(gained, spent)
    return Paint(Gold.Signed(gained - spent)) .. " " .. Paint("(", GREY) .. Paint(Gold.Signed(gained))
        .. Paint(" / ", GREY) .. Paint(Gold.Signed(-spent)) .. Paint(")", GREY)
end

local graph
local function Graph()
    if graph then return graph end
    graph = CreateFrame("Frame", nil, UIParent)
    graph:SetSize(PLOT_W + LABEL_W, PLOT_H + DATE_ROW)
    graph.lines = {}
    local function Label(point, x, y, justify)
        local fs = graph:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint(point, graph, "BOTTOMLEFT", x, y)
        fs:SetJustifyH(justify)
        fs:SetTextColor(GREY[1], GREY[2], GREY[3])
        return fs
    end
    graph.max = Label("TOPLEFT", PLOT_W + 4, DATE_ROW + PLOT_H, "LEFT")
    graph.min = Label("BOTTOMLEFT", PLOT_W + 4, DATE_ROW, "LEFT")
    graph.first = Label("BOTTOMLEFT", 0, 0, "LEFT")
    graph.last = Label("BOTTOMRIGHT", PLOT_W, 0, "RIGHT")
    graph:Hide()
    return graph
end

-- The curve in the theme's accent, or nil below two points.
function Gold.DrawGraph(points)
    if #points < 2 then return nil end
    local g = Graph()
    local lo, hi = Gold.Range(points)
    local c = ns.Themes.Accent()
    local function XY(i)
        local share = hi > lo and (points[i].value - lo) / (hi - lo) or 0.5
        return (i - 1) / (#points - 1) * PLOT_W, DATE_ROW + share * PLOT_H
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
    for i = #points, #g.lines do g.lines[i]:Hide() end
    g.max:SetText(ns.DataBar.GoldText(hi))
    g.min:SetText(ns.DataBar.GoldText(lo))
    g.first:SetText(date(L.GOLD_DATE, points[1].t))
    g.last:SetText(date(L.GOLD_DATE, points[#points].t))
    return g
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
        if rate then SignedRow(L.GOLD_PER_HOUR, math.floor(rate + 0.5)) end
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
    GameTooltip:AddLine(L.GOLD_REALM:format(realm), 1, 1, 1)
    for _, c in ipairs(list) do
        local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
        Row(c.name, ns.DataBar.GoldText(c.money), WHITE, cc and { cc.r, cc.g, cc.b })
    end
    Row(L.GOLD_TOTAL, ns.DataBar.GoldText(total), WHITE, WHITE)

    local g = Gold.DrawGraph(Gold.GraphPoints(days, now, money))
    if g then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.GOLD_GRAPH:format(Gold.GRAPH_DAYS), 1, 1, 1)
        -- Blizzard's own embedding: blank lines make the room, and clearing
        -- the tooltip hides the frame again.
        GameTooltip_InsertFrame(GameTooltip, g)
    end
    GameTooltip:Show()
end

-- InsertFrame widens the tooltip for the curve; the next tooltip must not keep that.
function Gold.HideTooltip(owner)
    if not GameTooltip:IsOwned(owner) then return end
    GameTooltip:SetMinimumWidth(0)
    GameTooltip:Hide()
end

local function Record(isLogin)
    local char, money, now = ns.CharDB(), GetMoney() or 0, Gold.Now()
    if isLogin or not char.goldSession then
        Gold.StartSession(char, money, now)
    else
        Gold.Update(char, money, now)
    end
    Gold.Remember(ns.AccountDB(), UnitName("player"), GetRealmName(), select(2, UnitClass("player")), money)
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_MONEY" }) do events:RegisterEvent(e) end
events:SetScript("OnEvent", function(_, event, isLogin)
    -- A fresh login starts a session; /reload and loading screens keep it.
    Record(event == "PLAYER_ENTERING_WORLD" and isLogin)
end)
