local ADDON, ns = ...
local L = ns.L

--[[---------------------------------------------------------------------------
Timed.lua -- crafts with a long cooldown (WoW: Forever 1.60.1 spell tables):
mooncloth, the transmutes (one shared cooldown), iron to gold, mithril to
truesilver and the salt shaker. Only those this character can make: a recipe
it knows (the spell book, or seen learned in its profession window), the salt
shaker in the bags. The game keeps the cooldowns; nothing is stored but which
recipes were seen (ForeverDataBarChar.timed[spellID] = true).
-----------------------------------------------------------------------------]]
local Timed = {}
ns.Timed = Timed

local GCD = 1.5   -- a shorter cooldown is the global one, not the craft's
local TRANSMUTES = { 17187, 1317279, 17559, 17560, 17561, 17562, 17563, 17564, 17565, 17566, 22430 }
Timed.LIST = {
    { prof = "TAILORING", spells = { 18560 } },                               -- Mooncloth
    { prof = "ALCHEMY", spells = TRANSMUTES, label = "TIMED_TRANSMUTE" },     -- Arcanite, Legionite, elements …
    { prof = "ALCHEMY", spells = { 11479 } },                                 -- Iron to Gold
    { prof = "ALCHEMY", spells = { 11480 } },                                 -- Mithril to Truesilver
    { prof = "LEATHERWORKING", item = 15846 },                                -- Salt Shaker (needs leatherworking)
}
Timed.IDS = {}
for _, e in ipairs(Timed.LIST) do for _, id in ipairs(e.spells or {}) do Timed.IDS[id] = true end end

local function seen()
    local char = ns.CharDB()
    char.timed = char.timed or {}
    return char.timed
end

function Timed.Learn(id) if Timed.IDS[id] then seen()[id] = true end end

local function knows(id)
    return seen()[id] or (C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id)) or false
end

-- Seconds left, 0 when ready; nil while the game keeps it secret.
function Timed.Left(start, duration)
    if issecretvalue and (issecretvalue(start) or issecretvalue(duration)) then return nil end
    if not start or start == 0 or not duration or duration <= GCD then return 0 end
    return math.max(0, start + duration - GetTime())
end

-- This character's crafts of a profession (its key, as ns.Data): { name, left } in LIST order.
function Timed.For(prof)
    local out = {}
    for _, e in ipairs(Timed.LIST) do
        if e.prof == prof then
            if e.item then
                if (C_Item.GetItemCount(e.item) or 0) > 0 then
                    out[#out + 1] = { name = C_Item.GetItemNameByID(e.item) or ("item:" .. e.item),
                        left = Timed.Left(C_Container.GetItemCooldown(e.item)) }
                end
            else
                for _, id in ipairs(e.spells) do
                    if knows(id) then
                        local cd = C_Spell.GetSpellCooldown(id)
                        out[#out + 1] = { name = e.label and L[e.label] or C_Spell.GetSpellName(id) or ("spell:" .. id),
                            left = cd and Timed.Left(cd.startTime, cd.duration) or 0 }
                        break
                    end
                end
            end
        end
    end
    return out
end
