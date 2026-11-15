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

Forever sends no event for an auction purchase. Purchases and sales per
item come from the mailbox invoices instead (GetInboxInvoiceInfo): the
inbox is read whenever it changes, and an invoice mail that is gone has
been taken. "Open all" takes several mails for one money change; the gone
mails' money is matched against the mail money booked until it is used up.

Stored per day in ForeverDataBarChar.goldDays[day]: inc[source] and
out[source] in copper. Items per realm, account wide:
ForeverDataBarDB.goldItems[realm][item] = { buyCost, buyQty, sellNet, sellQty }
(sellNet after the house cut, without the deposit returned with it; the
deposit refund counts as part of the sale's money).
-----------------------------------------------------------------------------]]
local Ledger = {}
ns.GoldLedger = Ledger

Ledger.SOURCES = { "LOOT", "QUEST", "VENDOR_SALE", "VENDOR_BUY", "REPAIR", "AH_SALE", "AH_BUY", "AH_FEES",
    "MAIL", "TRADE", "TRAINING", "FLIGHT", "OTHER" }

-- Seconds (GetTime) a change and the event explaining it may lie apart.
local WINDOW = { LOOT = 2, QUEST = 5, REPAIR = 5, AH_FEES = 3, AH_SALE = 30 }
-- A frame counts as open this long after it closed: the taxi map closes
-- before the fare is taken, the loot window before the coins arrive.
local CLOSE_GRACE = 1.5
local ANY = math.huge   -- a claim without an amount: whatever comes in its window

-- -----------------------------------------------------------------------------
-- Booking and claims
-- -----------------------------------------------------------------------------
local open, recent, claims = {}, {}, {}
Ledger.open = open

local function Now() return GetTime() end

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
        if now - list[i].time > span(list[i]) then table.remove(list, i) end
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
                Move(r.day, c.sign > 0 and "inc" or "out", c.from, c.to, take)
                r.amount = r.amount - take * c.sign
                if c.amount ~= ANY then c.amount = c.amount - take end
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
    recent[#recent + 1] = { day = day, source = source, amount = delta, time = now }
    Ledger.Reconcile(now)
    return source
end

-- `amount` (or ANY) of the changes booked as `from` belongs to `to`;
-- sign +1 for money in, -1 for money out.
function Ledger.Claim(to, from, sign, amount, now)
    now = now or Now()
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
-- price; never bought here: no cost known, the whole sale counts.
function Ledger.Profit(it)
    local cost = it.buyQty > 0 and it.sellQty * it.buyCost / it.buyQty or 0
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

-- One inbox mail worth remembering: money in it or an auction invoice.
-- GetInboxHeaderInfo: icon, stationery, sender, subject, money, COD, daysLeft, itemCount, ...
-- GetInboxInvoiceInfo: type, itemName, playerName, bid, buyout, deposit, consignment,
-- moneyDelay, etaHour, etaMin, count.
local function ReadMail(i)
    local _, _, sender, subject, money = GetInboxHeaderInfo(i)
    local kind, item, _, bid, _, deposit, consignment, _, _, _, count = GetInboxInvoiceInfo(i)
    if kind ~= "buyer" and kind ~= "seller" then kind = nil end
    if (money or 0) <= 0 and not kind then return nil end
    return {
        sig = table.concat({ tostring(sender), tostring(subject), money or 0, tostring(kind), tostring(item),
            bid or 0 }, "|"),
        money = money or 0, kind = kind, item = item, bid = bid or 0, deposit = deposit or 0,
        cut = consignment or 0, count = (count and count > 0) and count or 1,
    }
end

function Ledger.ScanInbox()
    local list = {}
    for i = 1, GetInboxNumItems() do list[#list + 1] = ReadMail(i) end
    return list
end

-- The mails of `before` no longer in `after` (alike mails counted).
function Ledger.Gone(before, after)
    local left = {}
    for _, m in ipairs(after) do left[m.sig] = (left[m.sig] or 0) + 1 end
    local gone = {}
    for _, m in ipairs(before) do
        if (left[m.sig] or 0) > 0 then left[m.sig] = left[m.sig] - 1 else gone[#gone + 1] = m end
    end
    return gone
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
local inbox, repairCost
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

local function OnInbox(now)
    local after = Ledger.ScanInbox()
    if inbox then
        local items = Ledger.ItemsOf(ns.AccountDB(), GetRealmName())
        for _, mail in ipairs(Ledger.Gone(inbox, after)) do Ledger.Taken(items, mail, now) end
    end
    inbox = after
end

local handlers = {
    MAIL_SHOW = function(now) inbox = nil; OnInbox(now) end,
    MAIL_INBOX_UPDATE = function(now) if IsOpen("MAIL", now) then OnInbox(now) end end,
    MAIL_CLOSED = function() inbox = nil end,
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
}

Ledger.events = CreateFrame("Frame")
for e in pairs(CONTEXTS) do pcall(Ledger.events.RegisterEvent, Ledger.events, e) end
for e in pairs(handlers) do pcall(Ledger.events.RegisterEvent, Ledger.events, e) end
Ledger.events:SetScript("OnEvent", function(_, event, ...)
    local now = Now()
    local ctx = CONTEXTS[event]
    if ctx then open[ctx[1]] = ctx[2] or now end
    if handlers[event] then handlers[event](now, ...) end
end)
