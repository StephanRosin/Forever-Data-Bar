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

-- An item's link, quality and icon. By name the client answers only for
-- items it has cached; the id, kept once known, asks the server too
-- (GET_ITEM_INFO_RECEIVED then refills the window).
function Ledger.ItemInfo(name, it)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return nil end
    local _, link, quality, _, _, _, _, _, _, icon = get(it and it.id or name)
    if link and it and not it.id then it.id = tonumber(link:match("item:(%d+)")) end
    return link, quality, icon
end

-- An auction invoice still to be taken: a sale while it holds its money,
-- a purchase while it holds the item; nil for any other mail.
-- GetInboxHeaderInfo: icon, stationery, sender, subject, money, COD, daysLeft, itemCount, ...
-- GetInboxInvoiceInfo: type, itemName, playerName, bid, buyout, deposit, consignment,
-- moneyDelay, etaHour, etaMin, count.
local function ReadMail(i)
    local _, _, _, _, money, _, _, itemCount = GetInboxHeaderInfo(i)
    local kind, item, _, bid, _, deposit, consignment, _, _, _, count = GetInboxInvoiceInfo(i)
    local pending = (kind == "seller" and (money or 0) > 0) or (kind == "buyer" and (itemCount or 0) > 0)
    if not pending then return nil end
    count = (count and count > 0) and count or 1
    return {
        sig = table.concat({ kind, tostring(item), bid or 0, deposit or 0, consignment or 0, count }, "|"),
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
-- Forever was seen not to send MAIL_CLOSED: walking away from the mailbox
-- left it open, and quest rewards and auction deposits were booked as mail.
-- The interaction manager's hide closes a frame whichever event is missing.
local INTERACTIONS = { [1] = "TRADE", [5] = "MERCHANT", [6] = "TAXI", [7] = "TRAINER", [17] = "MAIL", [21] = "AH" }

local function RepairCost() return (GetRepairAllCost and GetRepairAllCost()) or 0 end

-- A take as the mail functions are called, before the server removes the
-- money or the item. "Open all" calls again for a mail that has moved up
-- while the server still works on it, and a second click does the same:
-- a take counts only while the inbox holds more such mails than are in
-- flight. A take is in flight until fewer such mails remain than when it
-- was taken, or for a few seconds.
-- shortcut: a refill landing in the same update as a removal keeps the take
-- in flight until it times out; an alike mail taken meanwhile is missed.
local IN_FLIGHT = 5
local inFlight = {}

local function PendingAlike(sig)
    local n = 0
    for j = 1, GetInboxNumItems() do
        local m = ReadMail(j)
        if m and m.sig == sig then n = n + 1 end
    end
    return n
end

local function Land(now)
    local counts = {}
    for k = #inFlight, 1, -1 do
        local t = inFlight[k]
        counts[t.sig] = counts[t.sig] or PendingAlike(t.sig)
        if counts[t.sig] < t.alike or now - t.time > IN_FLIGHT then table.remove(inFlight, k) end
    end
end

local function OnTake(i, kinds)
    local now = Now()
    local mail = i and ReadMail(i)
    if not (mail and kinds[mail.kind]) then return end
    Land(now)
    local flying = 0
    for _, t in ipairs(inFlight) do if t.sig == mail.sig then flying = flying + 1 end end
    local alike = PendingAlike(mail.sig)
    if flying >= alike then return end
    inFlight[#inFlight + 1] = { sig = mail.sig, alike = alike, time = now }
    Ledger.Taken(Ledger.ItemsOf(ns.AccountDB(), GetRealmName()), mail, now)
end
local MONEY, ITEM, BOTH = { seller = true }, { buyer = true }, { seller = true, buyer = true }
for name, kinds in pairs({ TakeInboxMoney = MONEY, TakeInboxItem = ITEM, AutoLootMailItem = BOTH }) do
    if _G[name] then hooksecurefunc(name, function(i) OnTake(i, kinds) end) end
end

local handlers = {
    MAIL_SHOW = function() for k = #inFlight, 1, -1 do inFlight[k] = nil end end,
    MAIL_INBOX_UPDATE = function(now) Land(now) end,
    PLAYER_INTERACTION_MANAGER_FRAME_HIDE = function(now, kind)
        local context = INTERACTIONS[kind]
        if context and open[context] == true then open[context] = now end
    end,
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
    if handlers[event] then handlers[event](now, ...) end
end)
