local ADDON, ns = ...

--[[---------------------------------------------------------------------------
Gathering.lua -- which mining veins, herbs and smelting recipes still give
skill points at the current rank, for the Mining and Herbalism tooltips.

The game tells none of this without a window, so the levels are a fixed table
from Wowhead (veins and herbs as in Classic and TBC; Outland ones never show
below 300, the vanilla cap). Smelting is Classic only, see SMELTING.
A node is orange from its required skill, yellow at +25, green at +50 and grey
at +100. Names come from the
item the node gives (or the bar a recipe makes), so they follow the client's
language; the English name stands in until the item is cached.
-----------------------------------------------------------------------------]]
local Gathering = {}
ns.Gathering = Gathering

-- { required skill, item it gives, English fallback, rich vein }
local NODES = {
    MINING = {
        { 1, 2770, "Copper Ore" }, { 65, 2771, "Tin Ore" }, { 65, 3340, "Incendicite Ore" },
        { 75, 2775, "Silver Ore" }, { 75, 4278, "Lesser Bloodstone Ore" }, { 125, 2772, "Iron Ore" },
        { 155, 2776, "Gold Ore" }, { 175, 3858, "Mithril Ore" }, { 230, 7911, "Truesilver Ore" },
        { 230, 11370, "Dark Iron Ore" }, { 245, 10620, "Thorium Ore" }, { 275, 10620, "Thorium Ore", true },
        { 300, 23424, "Fel Iron Ore" }, { 325, 23425, "Adamantite Ore" }, { 350, 23425, "Adamantite Ore", true },
        { 350, 32464, "Nethercite Ore" }, { 375, 23426, "Khorium Ore" },
    },
    HERBALISM = {
        { 1, 2447, "Peacebloom" }, { 1, 765, "Silverleaf" },
        { 15, 2449, "Earthroot" }, { 50, 785, "Mageroyal" }, { 70, 2450, "Briarthorn" },
        { 85, 3820, "Stranglekelp" }, { 100, 2453, "Bruiseweed" }, { 115, 3355, "Wild Steelbloom" },
        { 120, 3369, "Grave Moss" }, { 125, 3356, "Kingsblood" }, { 150, 3357, "Liferoot" },
        { 160, 3818, "Fadeleaf" }, { 170, 3821, "Goldthorn" }, { 185, 3358, "Khadgar's Whisker" },
        { 195, 3819, "Wintersbite" }, { 205, 4625, "Firebloom" }, { 210, 8831, "Purple Lotus" },
        { 220, 8836, "Arthas' Tears" }, { 230, 8838, "Sungrass" }, { 235, 8839, "Blindweed" },
        { 245, 8845, "Ghost Mushroom" }, { 250, 8846, "Gromsblood" }, { 260, 13464, "Golden Sansam" },
        { 270, 13463, "Dreamfoil" }, { 280, 13465, "Mountain Silversage" }, { 285, 13466, "Plaguebloom" },
        { 290, 13467, "Icecap" }, { 300, 13468, "Black Lotus" }, { 300, 22785, "Felweed" },
        { 315, 22786, "Dreaming Glory" }, { 325, 22787, "Ragveil" }, { 325, 22789, "Terocone" },
        { 335, 22788, "Flame Cap" }, { 340, 22790, "Ancient Lichen" }, { 350, 22791, "Netherbloom" },
        { 350, 32468, "Netherdust Pollen" }, { 365, 22792, "Nightmare Vine" }, { 375, 22793, "Mana Thistle" },
    },
}

-- { orange, yellow, green, grey, bar made, English fallback }, Wowhead Classic
-- (Forever has vanilla content; TBC raised Silver and gave points for Mithril
-- and up). Tin is green from the start. Mithril, Truesilver, Dark Iron and
-- Thorium are grey as soon as learned there, so they are left out.
local SMELTING = {
    { 1, 25, 47, 70, 2840, "Copper Bar" }, { 65, 65, 65, 75, 3576, "Tin Bar" },
    { 65, 65, 90, 115, 2841, "Bronze Bar" }, { 75, 100, 112, 125, 2842, "Silver Bar" },
    { 125, 130, 135, 140, 3575, "Iron Bar" }, { 155, 170, 177, 185, 3577, "Gold Bar" },
}

local function itemName(id, fallback)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return name or fallback
end

-- The item's icon as a texture escape; GetItemInfoInstant needs no cache.
local function itemIcon(id)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    if not icon and GetItemInfoInstant then icon = select(5, GetItemInfoInstant(id)) end
    return icon and ("|T%s:14:14|t "):format(icon) or ""
end

-- 0 orange, 1 yellow, 2 green (DataBar.DIFFICULTY_COLOURS), nil when it gives
-- nothing: not reachable yet, grey, or the rank at its cap.
function Gathering.Difficulty(rank, orange, yellow, green, grey, maxRank)
    if rank < orange or rank >= grey or (maxRank and rank >= maxRank) then return nil end
    if rank < yellow then return 0 end
    if rank < green then return 1 end
    return 2
end

local function sorted(list)
    table.sort(list, function(a, b)
        if a.difficulty ~= b.difficulty then return a.difficulty < b.difficulty end
        if a.req ~= b.req then return a.req > b.req end
        return a.name < b.name
    end)
    return list
end

-- What gives points now ({ name, icon, difficulty, req }, hardest first), and
-- what unlocks next: every entry at the lowest required skill above the rank.
-- Outland items (ids above 20000) are left out of "next" on a 300 cap client.
local function collect(entries, rank, maxRank, levels)
    local list, nextList, nextReq = {}, {}, nil
    for _, e in ipairs(entries) do
        local req, yellow, green, grey, item, fallback, rich = levels(e)
        local name = itemName(item, fallback)
        if rich then name = name .. " " .. ns.L.TIP_RICH end
        local entry = { name = name, icon = itemIcon(item), req = req }
        entry.difficulty = Gathering.Difficulty(rank, req, yellow, green, grey, maxRank)
        if entry.difficulty then
            list[#list + 1] = entry
        elseif req > rank and (item < 20000 or (maxRank or 0) > 300) and (not nextReq or req <= nextReq) then
            if req ~= nextReq then nextList, nextReq = {}, req end
            nextList[#nextList + 1] = entry
        end
    end
    table.sort(nextList, function(a, b) return a.name < b.name end)
    return sorted(list), nextList
end

-- The veins or herbs of a profession key, see collect.
function Gathering.Nodes(key, rank, maxRank)
    return collect(NODES[key] or {}, rank, maxRank, function(n)
        return n[1], n[1] + 25, n[1] + 50, n[1] + 100, n[2], n[3], n[4]
    end)
end

-- The smelting recipes, see collect.
function Gathering.Smelting(rank, maxRank)
    return collect(SMELTING, rank, maxRank, function(r) return r[1], r[2], r[3], r[4], r[5], r[6] end)
end

function Gathering.Has(key) return NODES[key] ~= nil end
