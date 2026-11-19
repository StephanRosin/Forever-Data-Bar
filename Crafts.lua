local ADDON, ns = ...

--[[---------------------------------------------------------------------------
Crafts.lua -- recipes that still give skill points and whose materials are in
the bags, per profession (dataBarSkillUps, off by default).

The game tells a recipe's difficulty and materials only for the profession
whose window is open, so each one is read when its window shows and kept per
character (ForeverDataBarChar.crafts[skillLine][recipeID] = { n = name,
d = difficulty, r = { itemID, count, itemID, count, ... } }). Only recipes
that still give points are kept; one seen grey is dropped. Seen recipes are
merged, never cleared: the window's filters may hide some.
The bar never opens a profession itself (that would taint Blizzard's window).
-----------------------------------------------------------------------------]]
local Crafts = {}
ns.Crafts = Crafts

Crafts.TRIVIAL = 3          -- Enum.TradeskillRelativeDifficulty.Trivial: no more points
local BASIC = 1             -- Enum.CraftingReagentType.Basic: the materials
local SCAN_DELAY = 0.3      -- TRADE_SKILL_LIST_UPDATE comes in bursts

local function store()
    local char = ns.CharDB()
    char.crafts = char.crafts or {}
    return char.crafts
end

-- Whether this profession was ever read.
function Crafts.Known(skillLine) return skillLine ~= nil and store()[skillLine] ~= nil end

-- Reads the open profession window into the store; true when it did.
function Crafts.Scan()
    local api = C_TradeSkillUI
    if not (api and api.GetBaseProfessionInfo and api.GetFilteredRecipeIDs and api.GetRecipeInfo) then return false end
    -- Someone else's (a link, an NPC) is not ours.
    if api.IsNPCCrafting and api.IsNPCCrafting() then return false end
    if api.IsTradeSkillLinked and api.IsTradeSkillLinked() then return false end
    local ok, prof = pcall(api.GetBaseProfessionInfo)
    local skillLine = ok and type(prof) == "table" and prof.professionID
    if not skillLine or skillLine == 0 then return false end
    local ids = api.GetFilteredRecipeIDs() or {}
    if #ids == 0 then return false end
    local list = store()[skillLine] or {}
    for _, id in ipairs(ids) do
        local okInfo, info = pcall(api.GetRecipeInfo, id)
        if okInfo and type(info) == "table" and info.learned and info.relativeDifficulty then
            if info.relativeDifficulty >= Crafts.TRIVIAL then
                list[id] = nil
            else
                local reagents = {}
                local okSchematic, schematic = pcall(api.GetRecipeSchematic, id, false)
                for _, slot in ipairs(okSchematic and type(schematic) == "table" and schematic.reagentSlotSchematics or {}) do
                    local first = slot.reagents and slot.reagents[1]
                    if slot.reagentType == BASIC and first and first.itemID then
                        reagents[#reagents + 1] = first.itemID
                        reagents[#reagents + 1] = slot.quantityRequired or 1
                    end
                end
                list[id] = { n = info.name, d = info.relativeDifficulty, r = reagents }
            end
        end
    end
    store()[skillLine] = list
    return true
end

local function count(itemID)
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    return fn and fn(itemID) or 0
end

-- How often the bags hold the materials for one recipe.
function Crafts.Times(reagents)
    local times
    for i = 1, #reagents, 2 do
        local n = math.floor(count(reagents[i]) / math.max(1, reagents[i + 1]))
        times = times and math.min(times, n) or n
    end
    return times or 0
end

-- The recipes of a profession that give points and can be made now:
-- { name, difficulty, times }, hardest first.
function Crafts.SkillUps(skillLine)
    local list = {}
    for _, r in pairs(skillLine and store()[skillLine] or {}) do
        local times = Crafts.Times(r.r)
        if times > 0 then list[#list + 1] = { name = r.n or "?", difficulty = r.d, times = times } end
    end
    table.sort(list, function(a, b)
        if a.difficulty ~= b.difficulty then return a.difficulty < b.difficulty end
        return a.name < b.name
    end)
    return list
end

local pending
local events = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "BAG_UPDATE_DELAYED" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event)
    if not ns.Settings.Get("dataBarSkillUps") then return end
    if event == "BAG_UPDATE_DELAYED" then
        if ns.DataBar then ns.DataBar.UpdateProfessions() end
    elseif not pending then
        pending = true
        C_Timer.After(SCAN_DELAY, function()
            pending = false
            if Crafts.Scan() and ns.DataBar then ns.DataBar.UpdateProfessions() end
        end)
    end
end)
