local ADDON, ns = ...

--[[---------------------------------------------------------------------------
Gathering.lua -- which mining veins, herbs and smelting recipes still give
skill points at the current rank, for the Mining and Herbalism tooltips.

The game tells none of this without a window, so the levels are a fixed table
from Wowhead (TBC Classic data; Outland entries simply never show below 300).
A node is orange from its required skill, yellow at +25, green at +50 and grey
at +100. Smelting uses Wowhead's four numbers per recipe. Names come from the
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
        { 1, 2447, "Peacebloom" }, { 1, 765, "Silverleaf" }, { 1, 22710, "Bloodthistle" },
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

-- { orange, yellow, green, grey, bar made, English fallback }. Wowhead gives
-- Dark Iron and Elementium orange 0 (taught by a quest); their real minimum is set.
local SMELTING = {
    { 1, 25, 47, 70, 2840, "Copper Bar" }, { 65, 65, 70, 75, 3576, "Tin Bar" },
    { 65, 65, 90, 115, 2841, "Bronze Bar" }, { 75, 115, 122, 130, 2842, "Silver Bar" },
    { 125, 130, 145, 160, 3575, "Iron Bar" }, { 155, 170, 177, 185, 3577, "Gold Bar" },
    { 165, 165, 165, 165, 3859, "Steel Bar" }, { 175, 175, 202, 230, 3860, "Mithril Bar" },
    { 230, 235, 242, 250, 6037, "Truesilver Bar" }, { 230, 300, 305, 310, 11371, "Dark Iron Bar" },
    { 250, 250, 270, 290, 12359, "Thorium Bar" }, { 300, 350, 362, 375, 17771, "Elementium Bar" },
    { 300, 300, 307, 315, 23445, "Fel Iron Bar" }, { 325, 325, 332, 340, 23446, "Adamantite Bar" },
    { 350, 350, 357, 365, 23447, "Eternium Bar" }, { 350, 355, 367, 380, 23448, "Felsteel Bar" },
}

local function itemName(id, fallback)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return name or fallback
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

-- The veins or herbs of a profession key that give points: { name, difficulty, req }.
function Gathering.Nodes(key, rank, maxRank)
    local list = {}
    for _, n in ipairs(NODES[key] or {}) do
        local req = n[1]
        local d = Gathering.Difficulty(rank, req, req + 25, req + 50, req + 100, maxRank)
        if d then
            local name = itemName(n[2], n[3])
            if n[4] then name = name .. " " .. ns.L.TIP_RICH end
            list[#list + 1] = { name = name, difficulty = d, req = req }
        end
    end
    return sorted(list)
end

-- The smelting recipes that give points, same shape.
function Gathering.Smelting(rank, maxRank)
    local list = {}
    for _, s in ipairs(SMELTING) do
        local d = Gathering.Difficulty(rank, s[1], s[2], s[3], s[4], maxRank)
        if d then list[#list + 1] = { name = itemName(s[5], s[6]), difficulty = d, req = s[1] } end
    end
    return sorted(list)
end

function Gathering.Has(key) return NODES[key] ~= nil end
