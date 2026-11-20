-- The "Character stats" part (CharInfo.lua). Run from run.lua; turns the part off again.
return function(ns, M, check)
    local C, D, Settings = ns.CharInfo, ns.DataBar, ns.Settings
    local part = D.frame.parts.CHAR
    check("off by default", part:IsShown(), false)
    Settings.Set("dataBarChar", true)
    D.UpdateStats()
    local savedSpell = C_Spell
    C_Spell = { GetSpellTexture = function(id) return (id ~= 2565 and id < 1000 or id == 8737) and "spell" .. id or nil end }
    -- Icons: the class's spell (a warlock's Shadow Bolt), else the value's file.
    check("caster: spell power, spell hit, spell crit", part.plain, "312 3.0% 5.2%")
    M.state.class = "WARLOCK"
    check("spell power: the class's damage spell", C.Icon(C.STATS[1]), "|Tspell686:18|t")
    M.state.class = nil
    check("armour without proficiency: cloth", C.Icon(C.STATS[8]), "|TInterface\\Icons\\INV_Chest_Cloth_21:18|t")
    IsSpellKnown = function(id) return id == 8737 or id == 9078 end
    check("armour: the heaviest proficiency's icon", C.Icon(C.STATS[8]), "|Tspell8737:18|t")
    IsSpellKnown = nil
    Settings.Set("dataBarHeight", 16)
    check("icons never taller than the bar", C.Icon(C.STATS[8]), "|TInterface\\Icons\\INV_Chest_Cloth_21:10|t")
    Settings.Set("dataBarHeight", nil)
    M.state.class = "WARRIOR"
    check("warrior: melee crit", C.Text(C.STATS[4]), "7.5%")
    check("warrior: melee hit", C.Text(C.STATS[3]), "1.0%")
    D.UpdateStats()
    check("warrior's default: attack power instead of spell power", part.plain, "1.0% 7.5% 115")
    M.state.class = nil
    for _, id in ipairs({ "Heal", "AP", "Dodge", "Parry", "Armor", "Block" }) do C.Choose(id, true) end
    for _, id in ipairs({ "Spell", "Hit", "Crit" }) do C.Choose(id, false) end
    check("stored per character", ForeverDataBarChar.charStats.Armor, true)
    check("not account wide", ForeverDataBarDB.dataBarCharArmor, nil)
    D.UpdateStats()
    check("each value as chosen", part.plain, "540 115 4.2% 5.0% 1200 0.0%")
    -- Forever makes values secret in combat: a sum it cannot form keeps the last value.
    local saved = issecretvalue
    issecretvalue = function(v) return v == 100 end
    check("secret sum: the last value", C.Text(C.STATS[5]), "115")
    -- A single secret value (here dodge) is shown live in its own text, never joined or measured.
    local dodge = D.frame.parts.CHAR.slots[6]
    local width = dodge.width
    -- A text that showed a secret reports even a readable width as secret: slots are never measured.
    for _, slot in ipairs(D.frame.parts.CHAR.slots) do slot.text.GetStringWidth = function() error("measured a slot") end end
    issecretvalue = function(v) return v == "4.2%" end
    check("secret value: shown, not readable", select(2, C.Text(C.STATS[6])), false)
    D.UpdateStats()
    check("secret value: in its slot", dodge.text:GetText(), "4.2%")
    check("secret value: keeps the slot's width", dodge.width, width)
    check("secret value: left out of the readable texts", part.plain, "540 115 5.0% 1200 0.0%")
    check("tooltip: only readable texts", (C.Text(C.STATS[6], true)), "4.2%")
    issecretvalue = saved
    M.ticker()
    C_Spell = savedSpell
    ForeverDataBarChar.charStats = nil
    Settings.Set("dataBarChar", false)
    D.UpdateStats()
    check("off again", part:IsShown(), false)
end
