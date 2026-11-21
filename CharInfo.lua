local ADDON, ns = ...

--[[---------------------------------------------------------------------------
CharInfo.lua -- the character's combat values for the "Character stats" part,
as the character window shows them: spell power, healing, hit, crit, attack
power, dodge, parry, armour, block. Each one is shown or not
per character (ForeverDataBarChar.charStats[id]; until chosen: power, hit
and crit of the class's kind). Hit and crit follow the class: casters see the spell
values, the others melee (hunters ranged); hybrids whichever power is larger.

Forever can make the values secret in combat: they can then only be shown
alone, never added up or compared. A value that cannot be formed keeps the
last one read.
-----------------------------------------------------------------------------]]
local CharInfo = {}
ns.CharInfo = CharInfo

local function Secret(v) return issecretvalue and issecretvalue(v) end

local function Sum(...)
    local n = 0
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if Secret(v) then return nil end
        n = n + (v or 0)
    end
    return n
end

local function Class() return select(2, UnitClass("player")) end

-- The strongest school (2 holy to 7 arcane; 1 is physical).
local function SpellPower()
    local best = GetSpellBonusDamage(2)
    for school = 3, 7 do
        local v = GetSpellBonusDamage(school)
        if Secret(v) or Secret(best) then return nil end
        if v and v > best then best = v end
    end
    return best
end

local function AttackPower()
    if Class() == "HUNTER" then return Sum(UnitRangedAttackPower("player")) end
    return Sum(UnitAttackPower("player"))
end

local MELEE = { WARRIOR = true, ROGUE = true, HUNTER = true, DEATHKNIGHT = true }
local CASTER = { MAGE = true, PRIEST = true, WARLOCK = true }
function CharInfo.Caster()
    local class = Class()
    if MELEE[class] then return false end
    if CASTER[class] then return true end
    local ap, sp = AttackPower(), SpellPower()
    return not (ap and sp and ap > sp)
end

local function Hit()
    if CharInfo.Caster() then return Sum(GetCombatRatingBonus(CR_HIT_SPELL or 8), GetSpellHitModifier()) end
    if Class() == "HUNTER" then return Sum(GetCombatRatingBonus(CR_HIT_RANGED or 7), GetRangedHitModifier()) end
    return Sum(GetCombatRatingBonus(CR_HIT_MELEE or 6), GetHitModifier())
end

local function Crit()
    if CharInfo.Caster() then return GetSpellCritChance() end
    if Class() == "HUNTER" then return GetRangedCritChance() end
    return GetCritChance()
end

-- In the order they line up; pct: a percentage. spell: its icon stands for
-- the value (the game's own), icon: the file when the spell has none; art:
-- the bar's own icon (dataBarOwnIcons, Media/<art>.tga).
CharInfo.STATS = {
    { id = "Spell", art = "StatSpell", read = SpellPower, icon = "Spell_Fire_Fireball02" },
    { id = "Heal", art = "StatHeal", read = function() return GetSpellBonusHealing() end, icon = "Spell_Holy_FlashHeal" },
    { id = "Hit", art = "StatHit", read = Hit, pct = true, spell = 78, icon = "Ability_Rogue_Ambush" },            -- Heroic Strike
    { id = "Crit", art = "StatCrit", read = Crit, pct = true, spell = 12294, icon = "Ability_Warrior_SavageBlow" }, -- Mortal Strike
    { id = "AP", art = "StatAP", read = AttackPower, spell = 6673, icon = "Ability_Warrior_BattleShout" },       -- Battle Shout
    { id = "Dodge", art = "StatDodge", read = function() return GetDodgeChance() end, pct = true, spell = 81, icon = "Ability_Rogue_Feint" },
    { id = "Parry", art = "StatParry", read = function() return GetParryChance() end, pct = true, spell = 3127, icon = "Ability_Parry" },
    { id = "Armor", art = "StatArmor", read = function() return select(2, UnitArmor("player")) end, icon = "INV_Chest_Cloth_21" },
    { id = "Block", art = "StatBlock", read = function() return GetBlockChance() end, pct = true, spell = 2565, icon = "Ability_Defend" }, -- Shield Block
}

-- Spell power and healing: a damage and a healing spell of the class (as the Info Panel's).
local CLASS_SPELLS = {
    PRIEST = { Spell = 589, Heal = 2061 },    -- Shadow Word: Pain, Flash Heal
    WARLOCK = { Spell = 686, Heal = 689 },    -- Shadow Bolt, Drain Life
    MAGE = { Spell = 133, Heal = 1459 },      -- Fireball, Arcane Intellect
    DRUID = { Spell = 5176, Heal = 5185 },    -- Wrath, Healing Touch
    PALADIN = { Spell = 879, Heal = 635 },    -- Exorcism, Holy Light
    SHAMAN = { Spell = 403, Heal = 331 },     -- Lightning Bolt, Healing Wave
}

-- Armour: the heaviest armour proficiency known, as in the spellbook.
local ARMOR_SPELLS = { 750, 8737, 9077, 9078 }   -- Plate Mail, Mail, Leather, Cloth

local function ArmorSpell()
    local known = IsPlayerSpell or IsSpellKnown
    for _, id in ipairs(ARMOR_SPELLS) do
        if known and known(id) then return id end
    end
end

-- Icons a little larger than the bar's text, never taller than the bar.
local ICON_SIZE, ICON_MARGIN = 18, 6

function CharInfo.IconSize()
    return math.min(ICON_SIZE, ns.Settings.Get("dataBarHeight") - ICON_MARGIN)
end

-- The value's icon file: the class's spell, the armour proficiency, else its own.
function CharInfo.IconFile(stat)
    local own = CLASS_SPELLS[Class()]
    local spell = own and own[stat.id] or stat.spell
    if stat.id == "Armor" then spell = ArmorSpell() end
    local tex = spell and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spell)
    return tex or "Interface\\Icons\\" .. stat.icon
end

-- As an inline texture (the tooltip).
function CharInfo.Icon(stat)
    return ("|T%s:%d|t"):format(CharInfo.IconFile(stat), CharInfo.IconSize())
end

local last = {}

-- Chosen on this character; unset: power, hit and crit fitting the class.
function CharInfo.Chosen(id)
    local chosen = ns.CharDB().charStats
    if type(chosen) == "table" and chosen[id] ~= nil then return chosen[id] end
    if id == "Hit" or id == "Crit" then return true end
    return id == (CharInfo.Caster() and "Spell" or "AP")
end

function CharInfo.Choose(id, value)
    local char = ns.CharDB()
    char.charStats = char.charStats or {}
    char.charStats[id] = value and true or false
    ns.Settings.Changed("dataBarChar" .. id)
end

-- The value as text ("312", "5.2%") and whether it is readable. A single
-- secret value (in combat) becomes a secret text, shown live but never
-- joined, compared or measured (as the Info Panel's); a sum that cannot be
-- formed or a missing API: the last readable text. plainOnly: never secret.
function CharInfo.Text(stat, plainOnly)
    local ok, v = pcall(stat.read)
    if ok and v ~= nil then
        local done, text = pcall(string.format, stat.pct and "%.1f%%" or "%d", v)
        if done and Secret(text) then
            if not plainOnly then return text, false end
        elseif done then
            last[stat.id] = text
        end
    end
    return last[stat.id] or "?", true
end

-- The chosen stats in STATS order.
function CharInfo.Shown()
    local list = {}
    for _, stat in ipairs(CharInfo.STATS) do
        if CharInfo.Chosen(stat.id) then list[#list + 1] = stat end
    end
    return list
end
