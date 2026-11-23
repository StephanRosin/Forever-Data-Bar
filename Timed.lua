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
    return seen()[id] or (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id)) or false
end

-- Seconds left, 0 when ready; nil while the game keeps it secret.
function Timed.Left(start, duration)
    if issecretvalue and (issecretvalue(start) or issecretvalue(duration)) then return nil end
    if not start or start == 0 or not duration or duration <= GCD then return 0 end
    return math.max(0, start + duration - GetTime())
end

-- The spell of an entry this character knows (true for the salt shaker in the bags), else nil.
function Timed.Can(e)
    -- Guarded as Currencies.lua: early in a session (and in the tests) some C_ tables are partial.
    if e.item then return C_Item and C_Item.GetItemCount and (C_Item.GetItemCount(e.item) or 0) > 0 or nil end
    if not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
    for _, id in ipairs(e.spells) do if knows(id) then return id end end
end

-- Seconds left on an entry it can make (0: ready; nil: secret).
function Timed.EntryLeft(e)
    if e.item then return Timed.Left(C_Container.GetItemCooldown(e.item)) end
    local cd = C_Spell.GetSpellCooldown(Timed.Can(e))
    return cd and Timed.Left(cd.startTime, cd.duration) or 0
end

function Timed.Name(e)
    if e.item then return C_Item.GetItemNameByID(e.item) or ("item:" .. e.item) end
    local id = Timed.Can(e)
    return e.label and L[e.label] or C_Spell.GetSpellName(id) or ("spell:" .. id)
end

function Timed.Icon(e)
    if e.item then return C_Item.GetItemIconByID(e.item) or 134400 end
    return C_Spell.GetSpellTexture(Timed.Can(e)) or 134400   -- the question mark
end

-- "Ready", "2d 23h", "5h 12m", "40m": short, for the bar.
function Timed.Text(left)
    if left == nil then return "?" end
    if left <= 0 then return L.DATABAR_HEARTH_READY end
    local d, h, m = math.floor(left / 86400), math.floor(left % 86400 / 3600), math.floor(left % 3600 / 60)
    if d > 0 then return L.DUR_D:format(d) .. " " .. L.DUR_H:format(h) end
    if h > 0 then return L.DUR_H:format(h) .. " " .. L.DUR_M:format(m) end
    return m > 0 and L.DUR_M:format(m) or L.DUR_LESS
end

-- Every entry this character can make, in LIST order.
function Timed.Shown()
    local list = {}
    for _, e in ipairs(Timed.LIST) do if Timed.Can(e) then list[#list + 1] = e end end
    return list
end

-- This character's crafts of a profession (its key, as ns.Data): { name, left } in LIST order.
function Timed.For(prof)
    local out = {}
    for _, e in ipairs(Timed.Shown()) do
        if e.prof == prof then out[#out + 1] = { name = Timed.Name(e), left = Timed.EntryLeft(e) } end
    end
    return out
end
