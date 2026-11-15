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

    -- The mailbox: "open all" takes two sales, a letter and a purchase for one money change.
    local realm = GetRealmName()
    local saved = ForeverDataBarDB.goldItems
    ForeverDataBarDB.goldItems = nil
    local function mails()
        return {
            { "Auction House", "Sold: Linen Cloth", 900, invoice = { "seller", "Linen Cloth", 1000, 50, 150, 10 } },
            { "Auction House", "Sold: Linen Cloth", 450, invoice = { "seller", "Linen Cloth", 500, 0, 50, 5 } },
            { "Brannoc", "Thanks", 100 },
            { "Auction House", "Won: Linen Cloth", 0, invoice = { "buyer", "Linen Cloth", 600, 0, 0, 20 } },
            { "Brannoc", "Just a note", 0 },
        }
    end
    day = fresh()
    M.state.mail = mails()
    fire("MAIL_SHOW")
    M.state.mail = { M.state.mail[5] }
    Ledger.Book(day, 1450)
    fire("MAIL_INBOX_UPDATE")
    check("open all: sales and a letter", sides(day), "inc:AH_SALE=1350,MAIL=100 out:")
    local items = Ledger.ItemsOf(ForeverDataBarDB, realm)
    local cloth = items["Linen Cloth"]
    check("invoices: sold after the cut", cloth.sellNet .. "/" .. cloth.sellQty, "1300/15")
    check("invoices: bought", cloth.buyCost .. "/" .. cloth.buyQty, "600/20")
    -- The mails leave the inbox before the money arrives.
    day = fresh()
    M.state.mail = mails()
    fire("MAIL_SHOW")
    M.state.mail = { M.state.mail[2], M.state.mail[3], M.state.mail[4], M.state.mail[5] }
    fire("MAIL_INBOX_UPDATE")
    Ledger.Book(day, 900)
    check("sale mail first, money after", sides(day), "inc:AH_SALE=900 out:")
    -- Alike mails count each.
    M.state.mail = { M.state.mail[3], M.state.mail[4] }
    fire("MAIL_INBOX_UPDATE")
    Ledger.Book(day, 550)
    check("letter and second sale", sides(day), "inc:AH_SALE=1350,MAIL=100 out:")
    fire("MAIL_CLOSED")
    M.state.mail = nil
    check("gone: alike mails counted", #Ledger.Gone({ { sig = "a" }, { sig = "a" }, { sig = "b" } }, { { sig = "a" } }), 2)

    -- Realized profit: sales after the cut less the sold ones at the average purchase price.
    check("profit", Ledger.Profit({ buyCost = 1000, buyQty = 10, sellNet = 600, sellQty = 4 }), 200)
    check("profit: never bought, the whole sale", Ledger.Profit({ buyCost = 0, buyQty = 0, sellNet = 600, sellQty = 4 }), 600)
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
    for _, source in ipairs(Ledger.SOURCES) do check("source label " .. source, ns.L["GOLD_SRC_" .. source] ~= nil, true) end

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
    local sale
    for _, row in ipairs(f.income) do if row.label:GetText() == ns.L.GOLD_SRC_VENDOR_SALE then sale = row end end
    check("window: vendor sale listed", sale and sale.value:GetText(), "+0g 3s")
    check("window: in green", sale.value._textColor[2] > sale.value._textColor[1], true)
    ForeverDataBarDB.goldItems[realm]["Linen Cloth"] = cloth
    f.ranges[1]:GetScript("OnClick")(f.ranges[1])
    check("window: range stored", ForeverDataBarDB.goldWindow.range, 7)
    check("window: range button in the accent", f.ranges[1].text._textColor[1], ns.Themes.Accent()[1])
    check("window: best item", f.items[1].label:GetText(), "Linen Cloth")
    check("window: its profit", f.items[1].value:GetText(), (G.Signed(Ledger.Profit(cloth))))
    check("window: one day, no curve", f.noGraph:IsShown(), true)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -50)
    f.titleBar:GetScript("OnDragStop")()
    check("window: place kept", table.concat(ForeverDataBarDB.goldWindow.place, ","), "TOPLEFT,TOPLEFT,40,-50")

    -- Themed: the bar's backdrop and background colour, its rim on every side.
    local snapshot = {}
    for k, v in pairs(ForeverDataBarDB) do snapshot[k] = v end
    local bar = ns.DataBar.frame
    check("classic: the options window's look", f.themeBack:IsShown() and "back" or f.bodyFill._texColor[4],
        ns.Style.COLORS.bg[4])
    for _, id in ipairs(ns.Themes.IDS) do
        if id ~= "CLASSIC" then
            ns.Themes.Switch(id)
            local art, bg = ns.Themes.Spec(id).art, ns.Settings.Get("dataBarBgColor")
            check(id .. ": the bar's backdrop", f.themeBack._texture, bar.themeBack._texture)
            check(id .. ": its tint", table.concat(f.themeBack._vertex, ","), table.concat(bar.themeBack._vertex, ","))
            check(id .. ": the bar's background over it", table.concat(f.bodyFill._texColor, ","),
                table.concat({ bg[1], bg[2], bg[3], ns.Settings.Get("dataBarAlpha") / 100 }, ","))
            check(id .. ": rim", f.rims[3]._w, art.rimSize or 1)
            check(id .. ": wedge only with one", f.titleBar.wedge:IsShown(), art.wedge ~= nil)
            check(id .. ": black title bar on Swiss and Pitwall", f.titleBar.fill:IsShown(), id == "SWISS" or id == "PITWALL")
        end
    end
    ForeverDataBarDB = snapshot
    ForeverDataBarDB.themeSets = nil
    ns.Settings.Changed(nil)
    W.Toggle()
    check("window: closes again", f:IsShown(), false)
    ForeverDataBarDB.goldItems, ForeverDataBarDB.goldWindow, M.state.money = saved, nil, nil
end
