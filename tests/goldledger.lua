-- Gold sources, auction invoices and the gold window (GoldLedger.lua,
-- GoldWindow.lua): run from run.lua, which passes its helpers.
return function(ns, M, check)
    local Ledger, G = ns.GoldLedger, ns.Gold
    local function fire(e, ...) M.Fire(e, ...) end
    local function fresh()
        Ledger.Forget()
        M.state.time = M.state.time + 100
        return {}
    end
    local function wait(s) M.state.time = M.state.time + s end
    local function sides(day)
        local t = {}
        for _, side in ipairs({ "inc", "out" }) do
            local keys = {}
            for k, v in pairs(day[side] or {}) do keys[#keys + 1] = k .. "=" .. v end
            table.sort(keys)
            t[#t + 1] = side .. ":" .. table.concat(keys, ",")
        end
        return table.concat(t, " ")
    end

    -- By the frames open now.
    local day = fresh()
    fire("MERCHANT_SHOW")
    Ledger.Book(day, -500)
    Ledger.Book(day, 300)
    fire("MERCHANT_CLOSED")
    wait(5)
    Ledger.Book(day, 7)
    check("merchant: buy and sale, then other", sides(day), "inc:OTHER=7,VENDOR_SALE=300 out:VENDOR_BUY=500")

    -- Repairs: the repair cost falling explains the merchant payment, in either order.
    day = fresh()
    M.state.repairCost = 1000
    fire("MERCHANT_SHOW")
    Ledger.Book(day, -1200)
    M.state.repairCost = 0
    fire("UPDATE_INVENTORY_DURABILITY")
    check("repair after the payment", sides(day), "inc: out:REPAIR=1000,VENDOR_BUY=200")
    day = fresh()
    M.state.repairCost = 400
    fire("MERCHANT_SHOW")
    M.state.repairCost = 0
    fire("UPDATE_INVENTORY_DURABILITY")
    Ledger.Book(day, -400)
    check("repair before the payment", sides(day), "inc: out:REPAIR=400")
    fire("MERCHANT_CLOSED")
    M.state.repairCost = nil

    -- Loot: the money message, or the loot window just closed.
    day = fresh()
    fire("CHAT_MSG_MONEY", "You loot 5 Silver")
    Ledger.Book(day, 500)
    check("loot message first", sides(day), "inc:LOOT=500 out:")
    day = fresh()
    Ledger.Book(day, 500)
    wait(1)
    fire("CHAT_MSG_MONEY", "You loot 5 Silver")
    check("loot message after", sides(day), "inc:LOOT=500 out:")
    day = fresh()
    Ledger.Book(day, 500)
    wait(3)
    fire("CHAT_MSG_MONEY", "You loot 5 Silver")
    check("loot message too late: other", sides(day), "inc:OTHER=500 out:")
    day = fresh()
    fire("LOOT_OPENED")
    fire("LOOT_CLOSED")
    wait(1)
    Ledger.Book(day, 80)
    check("loot window just closed", sides(day), "inc:LOOT=80 out:")
    wait(5)

    -- Quests: the reward's amount only.
    day = fresh()
    Ledger.Book(day, 200)
    fire("QUEST_TURNED_IN", 1, 0, 150)
    check("quest reward", sides(day), "inc:OTHER=50,QUEST=150 out:")

    -- Flight paths: the fare comes after the map closed.
    day = fresh()
    fire("TAXIMAP_OPENED", 0)
    fire("TAXIMAP_CLOSED")
    Ledger.Book(day, -30)
    check("flight fare", sides(day), "inc: out:FLIGHT=30")
    day = fresh()
    fire("TRAINER_SHOW")
    Ledger.Book(day, -900)
    fire("TRAINER_CLOSED")
    fire("TRADE_SHOW")
    Ledger.Book(day, 1000)
    fire("TRADE_CLOSED")
    check("trainer and trade", sides(day), "inc:TRADE=1000 out:TRAINING=900")

    -- Auction house: a purchase, and a deposit near a new auction.
    day = fresh()
    fire("AUCTION_HOUSE_SHOW")
    Ledger.Book(day, -1000)
    wait(10)
    fire("AUCTION_HOUSE_AUCTION_CREATED", 7)
    Ledger.Book(day, -60)
    fire("AUCTION_HOUSE_CLOSED")
    check("auction purchase and deposit", sides(day), "inc: out:AH_BUY=1000,AH_FEES=60")
    -- A claim without an amount takes one change only.
    day = fresh()
    fire("AUCTION_HOUSE_SHOW")
    Ledger.Book(day, -150)
    fire("AUCTION_HOUSE_AUCTION_CREATED", 1)
    wait(2)
    Ledger.Book(day, -500000)
    check("a deposit, then a buyout in its window", sides(day), "inc: out:AH_BUY=500000,AH_FEES=150")
    day = fresh()
    fire("AUCTION_HOUSE_SHOW")
    fire("AUCTION_HOUSE_AUCTION_CREATED", 1)
    Ledger.Book(day, -300)
    fire("AUCTION_HOUSE_PURCHASE_COMPLETED", 2)
    fire("AUCTION_HOUSE_CLOSED")
    check("a purchase event takes it back from the deposits", sides(day), "inc: out:AH_BUY=300")
    wait(5)
    day = fresh()
    fire("CHAT_MSG_MONEY", "You loot 2 Copper")
    Ledger.Book(day, 2)
    wait(1.5)
    fire("QUEST_TURNED_IN", 1, 0, 5000)
    Ledger.Book(day, 5000)
    check("loot, then a quest reward in its window", sides(day), "inc:LOOT=2,QUEST=5000 out:")

    -- The mailbox: "open all" takes two sales, a letter and a purchase for one money change.
    local realm = GetRealmName()
    local saved = ForeverDataBarDB.goldItems
    ForeverDataBarDB.goldItems = nil
    local function mails()
        return {
            { "Auction House", "Sold: Linen Cloth", 900, invoice = { "seller", "Linen Cloth", 1000, 50, 150, 10 } },
            { "Auction House", "Sold: Linen Cloth", 450, invoice = { "seller", "Linen Cloth", 500, 0, 50, 5 } },
            { "Brannoc", "Thanks", 100 },
            { "Auction House", "Won: Linen Cloth", 0, items = 1, invoice = { "buyer", "Linen Cloth", 600, 0, 0, 20 } },
            { "Brannoc", "Just a note", 0 },
        }
    end
    -- As "open all" does: take mail 1, the server removes it, the next is mail 1.
    local function openAll(keep)
        while M.state.mail[1] and M.state.mail[1] ~= keep do
            local m = M.state.mail[1]
            if m[3] > 0 then TakeInboxMoney(1) else TakeInboxItem(1, 1) end
            table.remove(M.state.mail, 1)
            fire("MAIL_INBOX_UPDATE")
        end
    end
    day = fresh()
    M.state.mail = mails()
    fire("MAIL_SHOW")
    fire("MAIL_INBOX_UPDATE")
    local note = M.state.mail[5]
    openAll(note)
    Ledger.Book(day, 1450)
    check("open all: sales and a letter", sides(day), "inc:AH_SALE=1350,MAIL=100 out:")
    local items = Ledger.ItemsOf(ForeverDataBarDB, realm)
    local cloth = items["Linen Cloth"]
    check("invoices: sold after the cut", cloth.sellNet .. "/" .. cloth.sellQty, "1300/15")
    check("invoices: bought", cloth.buyCost .. "/" .. cloth.buyQty, "600/20")
    fire("MAIL_CLOSED")
    M.state.mail = nil
    -- By hand: the money taken, the mail stays; a second click while the server works counts once.
    ForeverDataBarDB.goldItems = nil
    day = fresh()
    M.state.mail = { { "Auction House", "Sold: Ore", 9500, invoice = { "seller", "Ore", 10000, 0, 500, 5 } },
        { "Auction House", "Won: Herb", 0, items = 1, invoice = { "buyer", "Herb", 2000, 0, 0, 1 } } }
    fire("MAIL_SHOW")
    TakeInboxMoney(1)
    TakeInboxMoney(1)
    M.state.mail[1][3] = 0
    Ledger.Book(day, 9500)
    fire("MAIL_INBOX_UPDATE")
    TakeInboxMoney(1)
    TakeInboxItem(2, 1)
    M.state.mail[2].items = nil
    fire("MAIL_INBOX_UPDATE")
    fire("MAIL_CLOSED")
    local hand = Ledger.ItemsOf(ForeverDataBarDB, realm)
    check("by hand: a sale counted once", hand.Ore.sellQty .. "/" .. hand.Ore.sellNet, "5/9500")
    check("by hand: its money a sale", sides(day), "inc:AH_SALE=9500 out:")
    check("by hand: a purchase counted once", hand.Herb.buyQty .. "/" .. hand.Herb.buyCost, "1/2000")
    -- Shift-click takes all of a mail; a letter's money stays mail.
    wait(10)
    day = fresh()
    M.state.mail = { { "Auction House", "Won: Herb", 0, items = 1, invoice = { "buyer", "Herb", 2000, 0, 0, 1 } },
        { "Brannoc", "Thanks", 100 } }
    fire("MAIL_SHOW")
    AutoLootMailItem(1)
    AutoLootMailItem(2)
    Ledger.Book(day, 100)
    check("auto loot: a purchase", hand.Herb.buyQty, 2)
    check("auto loot: a letter stays mail", sides(day), "inc:MAIL=100 out:")
    fire("MAIL_CLOSED")
    -- "Open all" takes mails 1 and 2, mail 1 leaves, and it takes the same mail again as mail 1.
    ForeverDataBarDB.goldItems = nil
    day = fresh()
    M.state.mail = { { "Auction House", "Sold: Ore", 500, invoice = { "seller", "Ore", 500, 0, 0, 1 } },
        { "Auction House", "Sold: Herb", 300, invoice = { "seller", "Herb", 300, 0, 0, 1 } } }
    fire("MAIL_SHOW")
    TakeInboxMoney(1)
    TakeInboxMoney(2)
    table.remove(M.state.mail, 1)
    fire("MAIL_INBOX_UPDATE")
    TakeInboxMoney(1)
    Ledger.Book(day, 800)
    M.state.mail = {}
    fire("MAIL_INBOX_UPDATE")
    check("moved up and taken again: counted once", Ledger.ItemsOf(ForeverDataBarDB, realm).Herb.sellQty, 1)
    -- Forever sends no MAIL_CLOSED: the interaction manager's hide closes the mailbox.
    fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 17)
    wait(5)
    fire("QUEST_TURNED_IN", 1, 0, 700)
    Ledger.Book(day, 700)
    check("mailbox left without MAIL_CLOSED", sides(day), "inc:AH_SALE=800,QUEST=700 out:")
    -- Many alike sales: the inbox shows 50 of 60 and refills as it empties, an
    -- alike mail taking the place of the one taken; the money comes in batches.
    ForeverDataBarDB.goldItems = nil
    day = fresh()
    local server = {}
    for i = 1, 60 do server[i] = { "Auction House", "Sold: Ore", 95, invoice = { "seller", "Ore", 100, 0, 5, 1 } } end
    local function show() M.state.mail = { unpack(server, 1, math.min(50, #server)) } end
    show()
    fire("MAIL_SHOW")
    fire("MAIL_INBOX_UPDATE")
    local pending = 0
    for n = 1, 60 do
        TakeInboxMoney(1)
        table.remove(server, 1)
        pending = pending + 95
        show()
        fire("MAIL_INBOX_UPDATE")
        if n % 3 == 0 then Ledger.Book(day, pending); pending = 0 end
        wait(1)
    end
    fire("MAIL_CLOSED")
    check("many alike sales: all of them a sale", sides(day), "inc:AH_SALE=5700 out:")
    check("many alike sales: all counted", Ledger.ItemsOf(ForeverDataBarDB, realm).Ore.sellQty, 60)
    M.state.mail = nil
    ForeverDataBarDB.goldItems = { [realm] = items }

    -- Realized profit: sales after the cut less the sold ones at the average purchase price.
    check("profit", Ledger.Profit({ buyCost = 1000, buyQty = 10, sellNet = 600, sellQty = 4 }), 200)
    check("profit: never bought, the whole sale", Ledger.Profit({ buyCost = 0, buyQty = 0, sellNet = 600, sellQty = 4 }), 600)
    check("profit: only the bought ones carry a cost", Ledger.Profit({ buyCost = 10000, buyQty = 1, sellNet = 100000, sellQty = 20 }), 90000)
    check("profit: a loss", Ledger.Profit({ buyCost = 1000, buyQty = 2, sellNet = 400, sellQty = 1 }), -100)
    local top = Ledger.TopItems({
        A = { buyCost = 0, buyQty = 0, sellNet = 50, sellQty = 1 },
        B = { buyCost = 0, buyQty = 0, sellNet = 900, sellQty = 1 },
        C = { buyCost = 100, buyQty = 1, sellNet = 0, sellQty = 0 },
        D = { buyCost = 0, buyQty = 0, sellNet = 300, sellQty = 2 },
    }, 2)
    check("top items: best first, unsold left out, limited", #top .. top[1].name .. top[2].name, "2BD")

    -- Sums per source over a range of days.
    local now = os.time({ year = 2026, month = 11, day = 19, hour = 15 })
    local days = {
        ["2026-11-19"] = { inc = { LOOT = 100, QUEST = 50 }, out = { REPAIR = 30 } },
        ["2026-11-13"] = { inc = { LOOT = 1000 } },
        ["2026-10-01"] = { inc = { AH_SALE = 5000 }, out = { AH_BUY = 4000 } },
    }
    local inc, out = Ledger.Totals(days, G.LastKeys(now, 7))
    check("7 days: income per source", inc[1].source .. inc[1].amount .. inc[2].source .. #inc, "LOOT1100QUEST2")
    check("7 days: expenses", out[1].source .. out[1].amount .. #out, "REPAIR301")
    inc = Ledger.Totals(days, G.LastKeys(now, 90))
    check("90 days: older sources too", inc[1].source, "AH_SALE")
    check("last keys: today first", G.LastKeys(now, 2)[2], "2026-11-18")
    for _, source in ipairs({ "LOOT", "QUEST", "VENDOR_SALE", "VENDOR_BUY", "REPAIR", "AH_SALE", "AH_BUY", "AH_FEES",
        "MAIL", "TRADE", "TRAINING", "FLIGHT", "OTHER" }) do check("source label " .. source, ns.L["GOLD_SRC_" .. source] ~= nil, true) end

    -- Through PLAYER_MONEY: Gold.lua books the change.
    Ledger.Forget()
    M.state.money = 1000
    fire("PLAYER_ENTERING_WORLD", true)
    fire("MERCHANT_SHOW")
    M.state.money = 1300
    fire("PLAYER_MONEY")
    fire("MERCHANT_CLOSED")
    local today = ForeverDataBarChar.goldDays[G.DayKey(G.Now())]
    check("event: booked as a vendor sale", today.inc.VENDOR_SALE, 300)

    -- The window.
    local W = ns.GoldWindow
    local part = ns.DataBar.frame.parts.GOLD
    part:GetScript("OnClick")(part)
    local f = W.Frame()
    check("window: a click opens it", f:IsShown(), true)
    check("window: Escape closes it", (function()
        for _, n in ipairs(UISpecialFrames) do if n == "ForeverDataBarGold" then return true end end
    end)(), true)
    check("window: opens on the overview", f.pages.OVERVIEW:IsShown() and not f.pages.ITEMS:IsShown(), true)
    local o = f.pages.OVERVIEW
    check("overview: the money", o.money:GetText(), G.Money(1300))
    check("overview: today in green", o.today.value._textColor[2] > o.today.value._textColor[1], true)
    check("overview: today's arrow up", o.today.arrow._texCoord[3], 0)
    check("overview: all characters counted", o.tiles[2].sub:GetText():find(ns.L.GOLD_CHARS_COUNT:format(1), 1, true) ~= nil, true)
    check("overview: today's income as a bar", o.inPieces[1]:IsShown(), true)
    check("overview: the legend names it", o.legend[1].text:GetText():find(ns.L.GOLD_SRC_OTHER, 1, true) ~= nil, true)
    check("overview: one day, the curve explains itself", o.chart.empty:IsShown(), true)
    -- Two days of balance still span the whole week: six labels before today.
    ForeverDataBarChar.goldDays[G.DayKey(G.Now(), 1)] = { gained = 0, spent = 0, close = 1000, inc = {}, out = {} }
    W.Fill()
    local shown = 0
    for _, fs in ipairs(o.chart.xLabels) do if fs:IsShown() then shown = shown + 1 end end
    check("overview: all seven days labelled", shown, 7)
    check("overview: yesterday one step left of today", o.chart.xLabels[6]._points.BOTTOM[3], o.chart.plotW * 5 / 6)
    ForeverDataBarChar.goldDays[G.DayKey(G.Now(), 1)] = nil
    W.Fill()
    check("overview: no burst outside the comic", o.burst:IsShown(), false)
    check("tabs: the chosen one underlined", f.tabs[1].underline:IsShown() and not f.tabs[2].underline:IsShown(), true)
    check("tabs: the underline in the accent", f.tabs[1].underline._texColor[1], ns.Themes.Accent()[1])
    check("tabs: the label in the text colour", f.tabs[1].text._textColor[1], select(4, ns.DataBar.FontFor("dataBar"))[1])
    f.tabs[3]:GetScript("OnClick")(f.tabs[3])
    check("tabs: switched", f.pages.FLOW:IsShown() and not f.pages.OVERVIEW:IsShown(), true)
    check("tabs: remembered", ForeverDataBarDB.goldWindow.tab, "FLOW")
    local flow, sale = f.pages.FLOW, nil
    for _, row in ipairs(flow.income) do if row.label:GetText() == ns.L.GOLD_SRC_VENDOR_SALE then sale = row end end
    check("flow: vendor sale listed", sale and sale.value:GetText(), "+0g 3s")
    check("flow: in green", sale.value._textColor[2] > sale.value._textColor[1], true)
    flow.ranges[1]:GetScript("OnClick")(flow.ranges[1])
    check("range: stored", ForeverDataBarDB.goldWindow.range, 7)
    check("range: underlined", flow.ranges[1].underline:IsShown() and not flow.ranges[2].underline:IsShown(), true)
    check("range: scope named", flow.scope:GetText(), ns.L.GOLD_SCOPE_CHAR:format(7))
    check("range: history follows", f.pages.HISTORY.scope:GetText(), ns.L.GOLD_SCOPE_CHAR:format(7))
    flow.ranges[1]:GetScript("OnEnter")(flow.ranges[2])
    check("range: hover brightens", flow.ranges[2].text._textColor[4], 1)
    flow.ranges[1]:GetScript("OnLeave")(flow.ranges[2])
    check("range: and dims again", flow.ranges[2].text._textColor[4] < 1, true)
    f.tabs[4]:GetScript("OnClick")(f.tabs[4])
    local it = f.pages.ITEMS
    ForeverDataBarDB.goldItems[realm] = {}
    W.Fill()
    check("items: nothing yet explained", it.empty:IsShown(), true)
    ForeverDataBarDB.goldItems[realm]["Linen Cloth"] = cloth
    W.Fill()
    check("items: scope is the realm, all time", it.scope:GetText(), ns.L.GOLD_SCOPE_ITEMS:format(realm))
    check("items: best item", it.rows[1].name:GetText(), "Linen Cloth")
    check("items: its counts", it.rows[1].SOLD:GetText() .. "/" .. it.rows[1].BOUGHT:GetText(), cloth.sellQty .. "/" .. cloth.buyQty)
    check("items: its profit", it.rows[1].PROFIT:GetText(), (G.Signed(Ledger.Profit(cloth))))
    check("items: the value column fixed", it.rows[1].PROFIT:GetWidth(), it.rows[2].PROFIT:GetWidth())
    check("items: explanation gone", it.empty:IsShown(), false)
    check("overview: best item tile", o.tiles[3].value:GetText(), "Linen Cloth")
    check("overview: best item listed", o.items[1].name:GetText(), "Linen Cloth")
    check("items: unknown item, a question mark", it.rows[1].icon._texture, 134400)
    _G.C_Item = { GetItemInfo = function(x)
        if x == "Linen Cloth" or x == 2589 then return "Linen Cloth", "|cffffffff|Hitem:2589::|h[Linen Cloth]|h|r", 1, 5, 0, "", "", 200, "", 132889 end
    end, GetItemQualityColor = function() return 1, 1, 1, "ffffffff" end }
    W.Fill()
    check("items: icon once known", it.rows[1].icon._texture, 132889)
    check("items: id kept for the server", cloth.id, 2589)
    local linked
    _G.HandleModifiedItemClick = function(l) linked = l end
    it.rows[1]:GetScript("OnClick")(it.rows[1])
    check("items: a modified click links it", linked and linked:find("item:2589", 1, true) ~= nil, true)
    _G.C_Item, _G.HandleModifiedItemClick = nil, nil
    -- Ids from links: posting, owned auctions, purchase mails, bags.
    local items = {}
    Ledger.Learn(items, "|cff1eff00|Hitem:2554:0:0|h[Magic Wand]|h|r")
    check("learn: id from a link", items["Magic Wand"].id, 2554)
    Ledger.Learn(items, nil)
    check("learn: no link, nothing", next(items, next(items)), nil)
    items["Copper Bar"] = { buyCost = 0, buyQty = 0, sellNet = 5, sellQty = 1 }
    local bags = _G.C_Container
    _G.C_Container = { GetContainerNumSlots = function(b) return b == 0 and 2 or 0 end,
        GetContainerItemInfo = function(_, slot) return ({ { hyperlink = "|cffffffff|Hitem:2840::|h[Copper Bar]|h|r" },
            { hyperlink = "|cffffffff|Hitem:2589::|h[Linen Cloth]|h|r" } })[slot] end }
    Ledger.LearnFromBags(items)
    _G.C_Container = bags
    check("bags: a listed item learns its id", items["Copper Bar"].id, 2840)
    check("bags: no new entries", items["Linen Cloth"], nil)
    _G.C_Item = { GetItemInfo = function() return nil end, GetItemInfoInstant = function(id) return id, "", "", "", 135274 end }
    local link, _, icon = Ledger.ItemInfo("Copper Bar", items["Copper Bar"])
    check("not cached: the icon at once", icon, 135274)
    check("not cached: the tooltip by id", link, "item:2840")
    _G.C_Item = nil
    -- Rows follow the font size.
    local before = select(5, flow.income[2].label:GetPoint("TOPLEFT"))
    ns.Settings.Set("dataBarFontSize", 20)
    check("larger font: taller rows", select(5, flow.income[2].label:GetPoint("TOPLEFT")) < before, true)
    ns.Settings.Set("dataBarFontSize", nil)
    check("graph labels in the window's font", select(2, f.pages.HISTORY.chart.yLabels[1]:GetFont()), select(2, ns.DataBar.FontFor("dataBar")))
    f.close:GetScript("OnEnter")()
    check("close: hover", f.close.lines[1]._texColor[4], 1)
    f.close:GetScript("OnLeave")()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -50)
    f.titleBar:GetScript("OnDragStop")()
    check("window: place kept", table.concat(ForeverDataBarDB.goldWindow.place, ","), "TOPLEFT,TOPLEFT,40,-50")

    -- Themed: the bar's backdrop and background colour, its rim on every side.
    local snapshot = {}
    for k, v in pairs(ForeverDataBarDB) do snapshot[k] = v end
    local bar = ns.DataBar.frame
    check("classic: the options window's look", f.themeBack:IsShown() and "back" or f.bodyFill._texColor[4],
        ns.Style.COLORS.bg[4])
    for _, id in ipairs(LibForeverThemes.SpecIds(ns.Themes.SPECS)) do
        if id ~= "CLASSIC" then
            ns.Themes.Switch(id)
            local art, bg = ns.Themes.Spec(id).art, ns.Settings.Get("dataBarBgColor")
            check(id .. ": the bar's backdrop", f.themeBack._texture, bar.themeBack._texture)
            check(id .. ": its tint", table.concat(f.themeBack._vertex, ","), table.concat(bar.themeBack._vertex, ","))
            check(id .. ": the bar's background over it", table.concat(f.bodyFill._texColor, ","),
                table.concat({ bg[1], bg[2], bg[3], ns.Settings.Get("dataBarAlpha") / 100 }, ","))
            check(id .. ": rim", f.rims[3]._w, art.rimSize or 1)
            check(id .. ": the title strip inside the rim", select(4, f.titleBar:GetPoint("TOPLEFT")), art.rimSize or 1)
            check(id .. ": wedge only with one", f.titleBar.wedge:IsShown(), art.wedge ~= nil)
            check(id .. ": black title bar on Swiss and Pitwall", f.titleBar.fill:IsShown(), id == "SWISS" or id == "PITWALL")
        end
    end
    -- The comic's burst only on a day that made money; Comic HD wears it too.
    ns.Themes.Switch("COMIC_HD")
    check("comic HD: its base's ink", f.pages.OVERVIEW.burst:IsShown(),
        ForeverDataBarChar.goldDays[G.DayKey(G.Now())].gained > ForeverDataBarChar.goldDays[G.DayKey(G.Now())].spent)
    ns.Themes.Switch("COMIC")
    local today = ForeverDataBarChar.goldDays[G.DayKey(G.Now())]
    check("comic: a gain, the burst", f.pages.OVERVIEW.burst:IsShown(), today.gained > today.spent)
    local gained = today.gained
    today.gained = today.spent - 100
    W.Fill()
    check("comic: a loss, no burst", f.pages.OVERVIEW.burst:IsShown(), false)
    check("overview: a loss, the arrow down", f.pages.OVERVIEW.today.arrow._texCoord[3], 1)
    today.gained = gained
    ForeverDataBarDB = snapshot
    ForeverDataBarDB.themeSets = nil
    ns.Settings.Changed(nil)
    W.Toggle()
    check("window: closes again", f:IsShown(), false)
    ForeverDataBarDB.goldItems, ForeverDataBarDB.goldWindow, M.state.money = saved, nil, nil
end
