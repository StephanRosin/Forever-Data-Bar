-- The "Currencies" and "Hearthstone" parts (Currencies.lua). Run from run.lua; turns them off again.
return function(ns, M, check)
    local D, Settings, Cur, Hearth = ns.DataBar, ns.Settings, ns.Currencies, ns.Hearth
    local cur, hearth = D.frame.parts.CURRENCY, D.frame.parts.HEARTH
    check("currencies: off by default", cur:IsShown(), false)
    check("hearthstone: off by default", hearth:IsShown(), false)

    -- The game: honour found in the currency list by name, an item count per id.
    local items = { [6265] = 7, [20558] = 3, [6948] = 1 }
    local currencies = { [42] = { name = "Honor", quantity = 1500, maxQuantity = 25000, iconFileID = 111 },
        [3402] = { name = "Merchant's Favor", quantity = 0, iconFileID = 222 } }
    HONOR = "Honor"
    C_CurrencyInfo = {
        GetCurrencyInfo = function(id) return currencies[id] end,
        GetCurrencyListSize = function() return 2 end,
        GetCurrencyListInfo = function(i) return i == 1 and { isHeader = true, name = "PvP" } or { name = "Honor", currencyID = 42 } end,
    }
    C_Item = { GetItemCount = function(id) return items[id] or 0 end,
        GetItemIconByID = function(id) return "icon" .. id end,
        GetItemNameByID = function(id) return id == 6948 and "Hearthstone" or nil end }

    Settings.Set("dataBarCurrency", true)
    D.UpdateStats()
    check("currencies: shown", cur:IsShown(), true)
    check("currencies: known ones at 0 too, marks only held, in order", cur.plain, "1500 0 7 3")
    check("honour: found by name", select(3, Cur.LIST[1].read()), "Honor")
    check("honour: its cap", select(4, Cur.LIST[1].read()), 25000)
    check("item: the game's icon", Cur.IconFile(Cur.LIST[4]), "icon6265")
    Settings.Set("dataBarCurShards", false)
    D.UpdateStats()
    check("a kind switched off", cur.plain, "1500 0 3")
    Settings.Set("dataBarCurShards", nil)
    currencies[42].quantity, items[6265], items[20558] = 0, 0, 0
    D.UpdateStats()
    check("nothing held: zeros, no marks", cur.plain, "0 0 0")
    for _, key in ipairs(Cur.KEYS) do Settings.Set("dataBarCur" .. key, false) end
    D.UpdateStats()
    check("all kinds off: the part goes", cur:IsShown(), false)
    for _, key in ipairs(Cur.KEYS) do Settings.Set("dataBarCur" .. key, nil) end
    Settings.Set("dataBarCurrency", false)

    -- Hearthstone: the time left (not the global cooldown), else ready.
    local cd = { 0, 0 }
    C_Container.GetItemCooldown = function() return cd[1], cd[2] end
    M.state.time = 1000
    Settings.Set("dataBarHearth", true)
    D.UpdateStats()
    check("hearthstone: ready", hearth.text:GetText(), "Ready")
    check("hearthstone: its icon", hearth.icon._texture, "icon6948")
    cd = { 999, 1.5 }
    check("global cooldown: still ready", Hearth.Left(), 0)
    cd = { 400, 3600 }
    D.UpdateStats()
    check("cooling down: time left", hearth.text:GetText(), "50:00")
    check("over an hour", Hearth.Format(3753), "1:02:33")
    local click = D.HearthClick()
    check("click: secure item button", click and click:GetAttribute("type") .. " " .. click:GetAttribute("item"), "item Hearthstone")
    check("click: not on the bar", click:GetParent(), UIParent)
    check("click: hidden in combat", click._driver, "[combat] hide; show")
    items[6948] = 0
    D.UpdateStats()
    check("no hearthstone: the part goes", hearth:IsShown(), false)
    Settings.Set("dataBarHearth", false)
    D.UpdateStats()
    C_Container.GetItemCooldown, C_CurrencyInfo, C_Item, HONOR = nil, nil, nil, nil
end
