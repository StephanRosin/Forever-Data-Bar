local ADDON, ns = ...

--[[---------------------------------------------------------------------------
Currencies.lua -- the "Currencies" and "Hearthstone" parts, as the Forever
Info Panel reckons them.

Currencies: honour, Merchant's Favor, Tarnished Undermine Real (currencies),
soul shards and the battleground marks (items in the bags). Each kind can be
switched off (dataBarCur<Key>). With dataBarCurZero (on), as in the Info
Panel, the currencies and the shards show at 0 too (where the client keeps
them); the marks only when held.

Hearthstone: the time left, or ready; the click uses it from a secure button
(DataBar.PlaceHearthClick).
-----------------------------------------------------------------------------]]
local Currencies = {}
ns.Currencies = Currencies

local function CurrencyInfo(id)
    if not (id and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil end
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
    if not ok or type(info) ~= "table" or type(info.quantity) ~= "number" then return nil end
    -- An id the client does not keep can come back as a table without a name.
    if info.name == "" then return nil end
    return info
end

-- Forever's honour currency has no id in the UI source: found in the
-- currency list by its name (HONOR), else the retail id (as the Info Panel).
local honorID
local function HonorID()
    if honorID and CurrencyInfo(honorID) then return honorID end
    honorID = nil
    local api = C_CurrencyInfo
    if api and api.GetCurrencyListSize and api.GetCurrencyListInfo then
        local wanted = HONOR or "Honor"
        for i = 1, api.GetCurrencyListSize() or 0 do
            local info = api.GetCurrencyListInfo(i)
            if type(info) == "table" and not info.isHeader and info.name == wanted then
                local id = info.currencyID
                if not id and api.GetCurrencyListLink and api.GetCurrencyIDFromLink then
                    id = api.GetCurrencyIDFromLink(api.GetCurrencyListLink(i))
                end
                if CurrencyInfo(id) then
                    honorID = id
                    return honorID
                end
            end
        end
    end
    if CurrencyInfo(1792) then honorID = 1792 end
    return honorID
end

local function FromCurrency(id)
    local info = CurrencyInfo(id)
    if not info then return nil end
    local max = (type(info.maxQuantity) == "number" and info.maxQuantity > 0) and info.maxQuantity or nil
    return info.quantity, info.iconFileID, info.name, max
end

local function FromItem(id, fallback)
    local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id) or 0
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    return count, icon, name or fallback
end

-- In the order they line up; key: the switch dataBarCur<key> (the marks share one);
-- art: the bar's own icon (dataBarOwnIcons).
-- read: count, icon, name, max.
Currencies.LIST = {
    { key = "Honor", art = "CurHonor", read = function() return FromCurrency(HonorID()) end },
    { key = "Favor", art = "CurFavor", read = function() return FromCurrency(3402) end },   -- Merchant's Favor
    { key = "Real", art = "CurReal", read = function() return FromCurrency(3469) end },    -- Tarnished Undermine Real
    { key = "Shards", art = "CurShards", read = function() return FromItem(6265, "Soul Shard") end },
    { key = "Marks", held = true, art = "MarkWSG", read = function() return FromItem(20558, "Warsong Gulch Mark of Honor") end },
    { key = "Marks", held = true, art = "MarkAB", read = function() return FromItem(20559, "Arathi Basin Mark of Honor") end },
    { key = "Marks", held = true, art = "MarkAV", read = function() return FromItem(20560, "Alterac Valley Mark of Honor") end },
    { key = "Marks", held = true, art = "MarkDS", read = function() return FromItem(274895, "Darkspear Islands Mark of Honor") end },
}
-- The switches, once each, for the options.
Currencies.KEYS = { "Honor", "Favor", "Real", "Shards", "Marks" }

-- Switched on and known to the client (held: the marks, only with some).
function Currencies.On(entry)
    if not ns.Settings.Get("dataBarCur" .. entry.key) then return false end
    local count = entry.read()
    if entry.held or not ns.Settings.Get("dataBarCurZero") then return (count or 0) > 0 end
    return count ~= nil
end

function Currencies.Shown()
    local list = {}
    for _, entry in ipairs(Currencies.LIST) do
        if Currencies.On(entry) then list[#list + 1] = entry end
    end
    return list
end

function Currencies.Text(entry)
    local count = entry.read()
    return tostring(count or 0)
end

function Currencies.IconFile(entry)
    local _, icon = entry.read()
    return icon or 134400   -- the question mark
end

-- -----------------------------------------------------------------------------
-- Hearthstone
-- -----------------------------------------------------------------------------
local Hearth = {}
ns.Hearth = Hearth
Hearth.ITEM = 6948
-- The global cooldown shows on items too (at most 1.5 s); the stone's runs an hour.
local GCD_MAX = 2

function Hearth.Left()
    if not (C_Container and C_Container.GetItemCooldown) then return 0 end
    local ok, start, duration = pcall(C_Container.GetItemCooldown, Hearth.ITEM)
    if not ok or not start or not duration or duration <= GCD_MAX then return 0 end
    return math.max(0, start + duration - GetTime())
end

function Hearth.Owned()
    return C_Item and C_Item.GetItemCount and (C_Item.GetItemCount(Hearth.ITEM) or 0) > 0 or false
end

-- "12:05", "1:02:33"; the seconds tick, the last minute is what one watches.
function Hearth.Format(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    local h, m, s = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60
    if h > 0 then return ("%d:%02d:%02d"):format(h, m, s) end
    return ("%d:%02d"):format(m, s)
end

-- The use attribute needs the item's name: "item:6948" means nothing to UseItemByName.
function Hearth.Name()
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(Hearth.ITEM)
    if type(name) == "string" and name ~= "" then return name end
end

function Hearth.Icon()
    return C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(Hearth.ITEM) or 134414
end
