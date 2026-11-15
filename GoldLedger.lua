local ADDON, ns = ...

--[[---------------------------------------------------------------------------
GoldLedger.lua -- where each gold change came from or went to, and what the
auction house bought and sold per item.

A change is booked at once by the frames open now (Classify): at the
merchant a purchase or a sale, at the mailbox mail, at the auction house a
purchase, and so on, else OTHER. Events that come just before or after the
money then refine it (claims): a quest's reward moves its amount from OTHER
to QUEST, a loot message moves a change to LOOT, falling repair costs move
their amount from a merchant purchase to REPAIR, a new auction moves the
deposit to AH_FEES, and an auction sale's mail moves its money from MAIL to
AH_SALE. Either side may come first; both wait a few seconds for the other.

The API knows AUCTION_HOUSE_PURCHASE_COMPLETED and COMMODITY_PURCHASE_SUCCEEDED,
but Forever was seen not to send them; should they come, they move a change
just booked as a deposit back to AH_BUY. Purchases and sales per item come
from the mailbox invoices (GetInboxInvoiceInfo), read as a mail is taken:
TakeInboxMoney, TakeInboxItem and AutoLootMailItem are hooked, the paths of
taking by hand and of "Open all". Comparing the inbox before and after missed
sales: with more than 50 mails the inbox refills while it is emptied, and a
mail like the one just taken takes its place. "Open all" takes several mails
for one money change: the taken sales' money is matched against the mail
money booked until it is used up.

Known gaps: a bid that is outbid books as an auction purchase, and its
refund arrives as plain mail income. Plain mail money (letters, refunds)
stays MAIL.

Stored per day in ForeverDataBarChar.goldDays[day]: inc[source] and
out[source] in copper. Items per realm, account wide:
ForeverDataBarDB.goldItems[realm][item] = { buyCost, buyQty, sellNet, sellQty }
(sellNet after the house cut, without the deposit returned with it; the
deposit refund counts as part of the sale's money).
-----------------------------------------------------------------------------]]
local Ledger = {}
ns.GoldLedger = Ledger

-- Seconds (GetTime) a change and the event explaining it may lie apart.
local WINDOW = { LOOT = 2, QUEST = 5, REPAIR = 5, AH_FEES = 3, AH_BUY = 3, AH_SALE = 30 }
-- A frame counts as open this long after it closed: the taxi map closes
-- before the fare is taken, the loot window before the coins arrive.
local CLOSE_GRACE = 1.5
-- A claim without an amount: the first change in its window, whatever its size.
local ANY = math.huge

-- -----------------------------------------------------------------------------
-- Booking and claims
-- -----------------------------------------------------------------------------
local open, recent, claims = {}, {}, {}

local function Now() return GetTime() end

-- Debug trace of mailbox and booking (/fdb maildebug), kept in
-- ForeverDataBarDB.mailLog so it can be read from the SavedVariables file.
local LOG_MAX = 1000
function Ledger.Log(fmt, ...)
    local db = ns.AccountDB()
    if not db.mailDebug then return end
    db.mailLog = db.mailLog or {}
    local log = db.mailLog
    log[#log + 1] = string.format("%s %.1f ", date("%H:%M:%S"), GetTime()) .. string.format(fmt, ...)
    while #log > LOG_MAX do table.remove(log, 1) end
end

local function IsOpen(context, now)
    local v = open[context]
    return v == true or (type(v) == "number" and now - v <= CLOSE_GRACE)
end

-- The source by the frames open now.
function Ledger.Classify(delta, now)
    now = now or Now()
    local function is(c) return IsOpen(c, now) end
    if is("MAIL") then return "MAIL" end
    if is("AH") then return delta < 0 and "AH_BUY" or "OTHER" end
    if is("TRADE") then return "TRADE" end
    if is("TRAINER") and delta < 0 then return "TRAINING" end
    if is("TAXI") and delta < 0 then return "FLIGHT" end
    if is("MERCHANT") then return delta < 0 and "VENDOR_BUY" or "VENDOR_SALE" end
    if is("LOOT") and delta > 0 then return "LOOT" end
    return "OTHER"
end

local function Add(day, source, delta)
    local side = delta > 0 and "inc" or "out"
    day[side] = day[side] or {}
    day[side][source] = (day[side][source] or 0) + math.abs(delta)
end

local function Move(day, side, from, to, amount)
    day[side][from] = day[side][from] - amount
    if day[side][from] == 0 then day[side][from] = nil end
    day[side][to] = (day[side][to] or 0) + amount
end

local function Expire(list, now, span)
    for i = #list, 1, -1 do
        local x = list[i]
        if now - x.time > span(x) then
            if x.to and x.amount ~= ANY then Ledger.Log("claim expired %s<-%s left %d", x.to, x.from, x.amount) end
            table.remove(list, i)
        end
    end
end

local LONGEST = 0
for _, w in pairs(WINDOW) do LONGEST = math.max(LONGEST, w) end

-- Every claim takes from the changes it explains, up to its amount.
function Ledger.Reconcile(now)
    Expire(recent, now, function() return LONGEST end)
    Expire(claims, now, function(c) return WINDOW[c.to] end)
    for _, c in ipairs(claims) do
        for _, r in ipairs(recent) do
            if c.amount <= 0 then break end
            if r.source == c.from and r.amount * c.sign > 0 and math.abs(r.time - c.time) <= WINDOW[c.to] then
                local take = math.min(c.amount, math.abs(r.amount))
                Ledger.Log("move %d %s->%s", take, c.from, c.to)
                Move(r.day, c.sign > 0 and "inc" or "out", c.from, c.to, take)
                r.amount = r.amount - take * c.sign
                -- The moved part stays open to a later claim (a purchase event after a deposit's).
                recent[#recent + 1] = { day = r.day, source = c.to, amount = take * c.sign, time = r.time }
                c.amount = c.amount == ANY and 0 or c.amount - take
            end
        end
    end
    for i = #recent, 1, -1 do if recent[i].amount == 0 then table.remove(recent, i) end end
    for i = #claims, 1, -1 do if claims[i].amount <= 0 then table.remove(claims, i) end end
end

-- A change of `delta` copper on `day` (a goldDays record).
function Ledger.Book(day, delta, now)
    now = now or Now()
    local source = Ledger.Classify(delta, now)
    Add(day, source, delta)
    Ledger.Log("book %d %s", delta, source)
    recent[#recent + 1] = { day = day, source = source, amount = delta, time = now }
    Ledger.Reconcile(now)
    return source
end

-- `amount` (or ANY) of the changes booked as `from` belongs to `to`;
-- sign +1 for money in, -1 for money out.
function Ledger.Claim(to, from, sign, amount, now)
    now = now or Now()
    Ledger.Log("claim %s<-%s %s", to, from, amount == ANY and "any" or tostring(amount))
    claims[#claims + 1] = { to = to, from = from, sign = sign, amount = amount or ANY, time = now }
    Ledger.Reconcile(now)
end

-- For the tests: forget the changes and claims in flight.
function Ledger.Forget()
    for k in pairs(open) do open[k] = nil end
    for i = #recent, 1, -1 do recent[i] = nil end
    for i = #claims, 1, -1 do claims[i] = nil end
end

-- -----------------------------------------------------------------------------
-- Sums over days
-- -----------------------------------------------------------------------------
-- Income and expenses per source over the days' keys, each as a list
-- { source, amount } with the largest first.
function Ledger.Totals(days, keys)
    local sums = { inc = {}, out = {} }
    for _, k in ipairs(keys) do
        local d = days[k]
        for side, list in pairs(sums) do
            for source, amount in pairs(d and d[side] or {}) do list[source] = (list[source] or 0) + amount end
        end
    end
    local function sorted(map)
        local list = {}
        for source, amount in pairs(map) do
            if amount > 0 then list[#list + 1] = { source = source, amount = amount } end
        end
        table.sort(list, function(a, b)
            if a.amount ~= b.amount then return a.amount > b.amount end
            return a.source < b.source
        end)
        return list
    end
    return sorted(sums.inc), sorted(sums.out)
end

-- -----------------------------------------------------------------------------
-- The auction house per item, from the mailbox invoices
-- -----------------------------------------------------------------------------
function Ledger.ItemsOf(account, realm)
    account.goldItems = account.goldItems or {}
    account.goldItems[realm] = account.goldItems[realm] or {}
    return account.goldItems[realm]
end

local function Item(items, name)
    items[name] = items[name] or { buyCost = 0, buyQty = 0, sellNet = 0, sellQty = 0 }
    return items[name]
end

-- Sales after the cut less what the sold ones cost at the average purchase
-- price; only as many as were bought here carry a cost, the rest (farmed,
-- crafted) count in full.
function Ledger.Profit(it)
    local cost = it.buyQty > 0 and math.min(it.sellQty, it.buyQty) * it.buyCost / it.buyQty or 0
    return math.floor(it.sellNet - cost + 0.5)
end

-- The sold items, best profit first.
function Ledger.TopItems(items, limit)
    local list = {}
    for name, it in pairs(items) do
        if it.sellQty > 0 then list[#list + 1] = { name = name, item = it, profit = Ledger.Profit(it) } end
    end
    table.sort(list, function(a, b)
        if a.profit ~= b.profit then return a.profit > b.profit end
        return a.name < b.name
    end)
    for i = #list, limit + 1, -1 do list[i] = nil end
    return list
end

-- An auction invoice still to be taken: a sale while it holds its money,
-- a purchase while it holds the item; nil for any other mail.
-- GetInboxHeaderInfo: icon, stationery, sender, subject, money, COD, daysLeft, itemCount, ...
-- GetInboxInvoiceInfo: type, itemName, playerName, bid, buyout, deposit, consignment,
-- moneyDelay, etaHour, etaMin, count.
local function ReadMail(i)
    local _, _, sender, subject, money, _, _, itemCount = GetInboxHeaderInfo(i)
    local kind, item, _, bid, _, deposit, consignment, _, _, _, count = GetInboxInvoiceInfo(i)
    Ledger.Log("  mail %d %s | %s | money %s items %s | invoice %s %s bid %s dep %s cut %s",
        i, tostring(sender), tostring(subject), tostring(money), tostring(itemCount),
        tostring(kind), tostring(item), tostring(bid), tostring(deposit), tostring(consignment))
    local pending = (kind == "seller" and (money or 0) > 0) or (kind == "buyer" and (itemCount or 0) > 0)
    if not pending then return nil end
    count = (count and count > 0) and count or 1
    return {
        sig = table.concat({ i, kind, tostring(item), bid or 0, deposit or 0, consignment or 0, count }, "|"),
        money = money or 0, kind = kind, item = item, bid = bid or 0, deposit = deposit or 0,
        cut = consignment or 0, count = count,
    }
end

-- A mail taken: the invoice into the item's sums, a sale's money from MAIL to AH_SALE.
function Ledger.Taken(items, mail, now)
    if mail.kind == "buyer" then
        local it = Item(items, mail.item)
        it.buyCost, it.buyQty = it.buyCost + mail.bid, it.buyQty + mail.count
    elseif mail.kind == "seller" then
        local it = Item(items, mail.item)
        it.sellNet, it.sellQty = it.sellNet + mail.bid - mail.cut, it.sellQty + mail.count
        if mail.money > 0 then Ledger.Claim("AH_SALE", "MAIL", 1, mail.money, now) end
    end
end

-- -----------------------------------------------------------------------------
-- Events
-- -----------------------------------------------------------------------------
local repairCost
local CONTEXTS = {
    MERCHANT_SHOW = { "MERCHANT", true }, MERCHANT_CLOSED = { "MERCHANT", false },
    MAIL_SHOW = { "MAIL", true }, MAIL_CLOSED = { "MAIL", false },
    AUCTION_HOUSE_SHOW = { "AH", true }, AUCTION_HOUSE_CLOSED = { "AH", false },
    TRADE_SHOW = { "TRADE", true }, TRADE_CLOSED = { "TRADE", false },
    TRAINER_SHOW = { "TRAINER", true }, TRAINER_CLOSED = { "TRAINER", false },
    TAXIMAP_OPENED = { "TAXI", true }, TAXIMAP_CLOSED = { "TAXI", false },
    LOOT_OPENED = { "LOOT", true }, LOOT_CLOSED = { "LOOT", false },
}

local function RepairCost() return (GetRepairAllCost and GetRepairAllCost()) or 0 end

-- A take as the mail functions are called, before the server removes the
-- money or the item. A second click on the same money while the server still
-- works on the first must not count twice: the take is remembered until an
-- inbox update after the server is done, or one that shows that mail gone.
local lastTake
local function OnTake(i, kinds)
    local mail = i and ReadMail(i)
    Ledger.Log("take %s %s", tostring(i), mail and mail.kind or "-")
    if not (mail and kinds[mail.kind]) then return end
    if lastTake and lastTake.sig == mail.sig then return end
    lastTake = { i = i, sig = mail.sig, n = GetInboxNumItems() }
    Ledger.Taken(Ledger.ItemsOf(ns.AccountDB(), GetRealmName()), mail, Now())
end
local MONEY, ITEM, BOTH = { seller = true }, { buyer = true }, { seller = true, buyer = true }
for name, kinds in pairs({ TakeInboxMoney = MONEY, TakeInboxItem = ITEM, AutoLootMailItem = BOTH }) do
    if _G[name] then hooksecurefunc(name, function(i) OnTake(i, kinds) end) end
end

local function OnInbox()
    if not lastTake then return end
    if not (C_Mail and C_Mail.IsCommandPending and C_Mail.IsCommandPending()) then lastTake = nil; return end
    local now = lastTake.i <= GetInboxNumItems() and ReadMail(lastTake.i)
    if GetInboxNumItems() ~= lastTake.n or not now or now.sig ~= lastTake.sig then lastTake = nil end
end

local handlers = {
    MAIL_SHOW = function() lastTake = nil end,
    MAIL_INBOX_UPDATE = OnInbox,
    MERCHANT_SHOW = function() repairCost = RepairCost() end,
    UPDATE_INVENTORY_DURABILITY = function(now)
        if not (IsOpen("MERCHANT", now) and repairCost) then return end
        local cost = RepairCost()
        if cost < repairCost then Ledger.Claim("REPAIR", "VENDOR_BUY", -1, repairCost - cost, now) end
        repairCost = cost
    end,
    CHAT_MSG_MONEY = function(now) Ledger.Claim("LOOT", "OTHER", 1, ANY, now) end,
    QUEST_TURNED_IN = function(now, _, _, money)
        if (money or 0) > 0 then Ledger.Claim("QUEST", "OTHER", 1, money, now) end
    end,
    AUCTION_HOUSE_AUCTION_CREATED = function(now) Ledger.Claim("AH_FEES", "AH_BUY", -1, ANY, now) end,
    AUCTION_HOUSE_PURCHASE_COMPLETED = function(now) Ledger.Claim("AH_BUY", "AH_FEES", -1, ANY, now) end,
    COMMODITY_PURCHASE_SUCCEEDED = function(now) Ledger.Claim("AH_BUY", "AH_FEES", -1, ANY, now) end,
}

local events = CreateFrame("Frame")
for e in pairs(CONTEXTS) do pcall(events.RegisterEvent, events, e) end
for e in pairs(handlers) do pcall(events.RegisterEvent, events, e) end
events:SetScript("OnEvent", function(_, event, ...)
    local now = Now()
    local ctx = CONTEXTS[event]
    if ctx then open[ctx[1]] = ctx[2] or now end
    if event:find("^MAIL") then Ledger.Log("%s mailOpen=%s", event, tostring(IsOpen("MAIL", now))) end
    if handlers[event] then handlers[event](now, ...) end
end)
