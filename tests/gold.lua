-- The gold tooltip (Gold.lua): run from run.lua, which passes its helpers.
return function(ns, M, check)
    local G, D = ns.Gold, ns.DataBar
    local function at(day, hour) return os.time({ year = 2026, month = 11, day = day, hour = hour or 15 }) end
    local GOLD = 10000

    -- Session and day bookkeeping: the login reading is the baseline.
    local char = {}
    G.StartSession(char, 100 * GOLD, at(18, 9))
    check("login: no change counted", char.goldSession.gained + char.goldSession.spent, 0)
    check("login: today's closing balance", char.goldDays["2026-11-18"].close, 100 * GOLD)
    G.Update(char, 130 * GOLD, at(18, 10))
    G.Update(char, 110 * GOLD, at(18, 11))
    G.Update(char, 110 * GOLD, at(18, 11))
    check("session gained", char.goldSession.gained, 30 * GOLD)
    check("session spent", char.goldSession.spent, 20 * GOLD)
    check("today gained/spent", char.goldDays["2026-11-18"].gained .. "/" .. char.goldDays["2026-11-18"].spent,
        30 * GOLD .. "/" .. 20 * GOLD)
    check("per hour over two hours", G.PerHour(10 * GOLD, 7200), 5 * GOLD)
    check("per hour: negative", G.PerHour(-10 * GOLD, 3600), -10 * GOLD)
    check("per hour: no time, none", G.PerHour(5, 0), nil)
    check("no session: the first reading starts one", (function()
        local c = {}
        G.Update(c, 5, at(18))
        return c.goldSession.last .. "/" .. c.goldSession.gained
    end)(), "5/0")

    -- Day rollover: the next day gets its own record, the session runs on.
    G.Update(char, 150 * GOLD, at(19, 0) + 60)
    check("rollover: new day", char.goldDays["2026-11-19"].gained, 40 * GOLD)
    check("rollover: yesterday untouched", char.goldDays["2026-11-18"].close, 110 * GOLD)
    check("rollover: session sums both days", char.goldSession.gained, 70 * GOLD)

    -- The week starts on Monday (16 Nov 2026).
    local week = G.WeekKeys(at(19))
    check("week: Monday to Thursday", #week .. " " .. week[#week] .. " " .. week[1], "4 2026-11-16 2026-11-19")
    check("week on a Monday: one day", #G.WeekKeys(at(16)), 1)
    check("week on a Sunday: seven days", #G.WeekKeys(at(22)), 7)
    char.goldDays["2026-11-15"] = { gained = 999, spent = 0, close = 1 }   -- Sunday before: not this week
    check("week sums", table.concat({ G.Sum(char.goldDays, G.WeekKeys(at(19))) }, "/"), 70 * GOLD .. "/" .. 20 * GOLD)
    check("yesterday", G.DayKey(at(19), 1), "2026-11-18")
    check("across a month", G.DayKey(at(1), 1), "2026-10-31")

    -- Pruning: only the last KEEP_DAYS days stay.
    local days = { ["2026-07-01"] = {}, ["2026-08-21"] = {}, ["2026-08-22"] = {}, ["2026-11-19"] = {} }
    G.Prune(days, at(19))
    check("prune: 90 days back stays", days["2026-08-22"] ~= nil, true)
    check("prune: older goes", (days["2026-08-21"] or days["2026-07-01"]) == nil, true)
    check("prune: today stays", days["2026-11-19"] ~= nil, true)

    -- The realm's characters, any faction, with a total.
    local account = {}
    G.Remember(account, "Brannoc", "Mockrealm", "WARRIOR", 50 * GOLD)
    G.Remember(account, "Ysolde", "Mockrealm", "MAGE", 200 * GOLD)
    G.Remember(account, "Farwen", "Elsewhere", "PRIEST", 900 * GOLD)
    G.Remember(account, "Brannoc", "Mockrealm", "WARRIOR", 60 * GOLD)
    local list, total = G.RealmChars(account, "Mockrealm")
    check("realm: only its characters", #list, 2)
    check("realm: richest first", list[1].name, "Ysolde")
    check("realm: updated, not doubled", list[2].money, 60 * GOLD)
    check("realm: total of the listed", total, 260 * GOLD)

    -- The curve: from the first recorded day, gaps keep the balance, today live.
    local points = G.GraphPoints({ ["2026-11-15"] = { close = 10 }, ["2026-11-17"] = { close = 40 } }, at(19), 25)
    check("graph: one point per day", #points, 5)
    check("graph: a gap keeps the balance", points[2].value, 10)
    check("graph: today is live", points[5].value, 25)
    check("graph: min/max", table.concat({ G.Range(points) }, "/"), "10/40")
    check("graph: older than its span ignored", #G.GraphPoints({ ["2026-09-01"] = { close = 5 } }, at(19), 1), 1)
    local g = G.NewGraph(UIParent, 150, 60)
    check("graph: drawn", G.DrawGraph(g, points), true)
    check("graph: a line per step", g.lines[4]:IsShown() and #g.lines, 4)
    check("graph: max label", g.max:GetText(), D.GoldText(40))
    check("graph: first date", g.first:GetText(), os.date(ns.L.GOLD_DATE, at(15, 12)))
    G.DrawGraph(g, { { t = at(18), value = 7 }, { t = at(19), value = 7 } })
    check("graph: flat runs in the middle", g.lines[1]._start[2] == g.lines[1]._end[2], true)
    check("graph: fewer points hide old lines", g.lines[2]:IsShown(), false)
    check("graph: one point, nothing drawn", G.DrawGraph(g, { { t = at(19), value = 1 } }), false)
    check("graph: one point, no line, no label", tostring(g.lines[1]:IsShown()) .. g.max:GetText(), "false")
    check("graph: span chosen", #G.GraphPoints({ ["2026-08-25"] = { close = 5 } }, at(19), 1, 90), 87)

    -- Money text with a sign.
    check("signed: gain", (G.Signed(12 * GOLD + 300)), "+12g 3s")
    check("signed: loss", (G.Signed(-4 * GOLD)), "-4g 0s")
    check("signed: loss red", select(2, G.Signed(-1))[1], 1)
    check("signed: nothing", (G.Signed(0)), "0g 0s")

    -- The events and the tooltip itself.
    local savedChars = ForeverDataBarDB.goldChars
    M.state.money = 70 * GOLD
    M.Fire("PLAYER_ENTERING_WORLD", true)
    M.state.money = 75 * GOLD
    M.Fire("PLAYER_MONEY")
    check("event: gained counted", ForeverDataBarChar.goldSession.gained, 5 * GOLD)
    check("event: remembered account wide", ForeverDataBarDB.goldChars["Testeria-Mockrealm"].money, 75 * GOLD)
    M.Fire("PLAYER_ENTERING_WORLD", false)
    check("reload keeps the session", ForeverDataBarChar.goldSession.gained, 5 * GOLD)
    local part = D.frame.parts.GOLD
    part:GetScript("OnEnter")(part)
    local text = table.concat(GameTooltip._lines, "\n")
    check("tooltip: session", text:find(ns.L.GOLD_GAINED .. "|+5g 0s", 1, true) ~= nil, true)
    check("tooltip: realm total", text:find(ns.L.GOLD_TOTAL .. "|75g 0s", 1, true) ~= nil, true)
    part:GetScript("OnLeave")(part)
    check("leaving resets the tooltip width", GameTooltip._minWidth, 0)
    -- Data, not settings: no theme set takes it, a reset keeps it.
    check("gold records outside the theme sets", ns.Themes.META.goldChars and ns.Themes.META.goldItems, true)
    local height = ForeverDataBarDB.dataBarHeight
    ns.Settings.Reset()
    check("reset keeps the characters", ForeverDataBarDB.goldChars["Testeria-Mockrealm"] ~= nil, true)
    ForeverDataBarDB.dataBarHeight = height
    ForeverDataBarDB.goldChars, M.state.money = savedChars, nil
end
