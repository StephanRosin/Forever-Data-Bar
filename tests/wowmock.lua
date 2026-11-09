-- A mock of the WoW API, just enough for Forever Data Bar. Lua 5.1, as in the game.
local M = { frames = {}, byName = {}, chat = {}, placed = {}, timers = {}, fontStrings = {},
            popups = {}, casts = {}, registered = {} }

local widget = {}
widget.__index = function(t, k)
    -- Only CamelCase keys are widget methods. Everything else is the addon's
    -- own data and must be nil as in the game.
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    local f = function() end
    rawset(t, k, f)
    return f
end

local function newWidget(name, kind)
    local w = setmetatable({ _name = name, _kind = kind, _scripts = {}, _events = {},
                             _w = 0, _h = 0, _shown = true, _attr = {} }, widget)
    function w:GetName() return self._name end
    function w:SetScript(s, fn) self._scripts[s] = fn end
    function w:GetScript(s) return self._scripts[s] end
    function w:HookScript(s, fn)
        local old = self._scripts[s]
        self._scripts[s] = function(...) if old then old(...) end return fn(...) end
    end
    function w:SetText(t) self._text = t end
    function w:GetText() return self._text end
    function w:GetAlpha() return self._alpha or 1 end
    function w:SetAlpha(v) self._alpha = v end
    function w:SetBlendMode(v) self._blend = v end
    function w:GetDrawLayer() return "OVERLAY", self._drawSub or 0 end
    function w:SetDrawLayer(_, sub) self._drawSub = sub end
    function w:GetBlendMode() return self._blend end
    function w:SetAllPoints(rel) self._allPoints = rel or true end
    function w:SetValue(v) self._value = v end
    function w:GetValue() return self._value end
    function w:SetMinMaxValues(a, b) self._min, self._max = a, b end
    -- The fill texture of a status bar (made on first ask).
    function w:GetStatusBarTexture()
        if not self._fillTex then self._fillTex = newWidget() end
        return self._fillTex
    end
    function w:SetStatusBarColor(r, g, b, a) self._color = { r, g, b, a } end
    function w:SetStatusBarTexture(t) self._barTex = t end
    function w:SetTextureSliceMargins(...) self._slice = { ... } end
    function w:SetTextColor(r, g, b, a) self._textColor = { r, g, b, a } end
    function w:SetChecked(v) self._checked = not not v end
    function w:GetChecked() return self._checked end
    function w:SetAttribute(k, v) self._attr[k] = v end
    function w:GetAttribute(k) return self._attr[k] end
    function w:SetSize(a, b) self._w, self._h = a, b end
    function w:SetWidth(v) self._w = v end
    function w:SetHeight(v) self._h = v end
    function w:GetWidth() return self._w end
    function w:GetHeight() return self._h end
    function w:Hide() self._shown = false end
    function w:Show() self._shown = true end
    function w:SetShown(v) if v then self:Show() else self:Hide() end end
    function w:IsShown() return self._shown end
    function w:IsVisible() return self._shown end
    function w:GetFrameLevel() return self._level or 3 end
    function w:SetParent(p) self._parent = p end
    function w:SetEnabled(on) self._enabled = on and true or false end
    function w:IsEnabled() return self._enabled ~= false end
    function w:GetParent() return self._parent end
    function w:SetFrameLevel(v) self._level = v end
    function w:GetEffectiveScale() return 1 end
    function w:SetMovable(v) self._movable = v end
    function w:IsMovable() return self._movable end
    function w:EnableMouse(v) self._mouse = v end
    function w:RegisterForDrag(...) self._drag = select("#", ...) > 0 end
    function w:RegisterEvent(e) self._events[e] = true end
    function w:UnregisterEvent(e) self._events[e] = nil end
    function w:SetPoint(p, rel, p2, x, y)
        if type(rel) == "number" then x, y, rel, p2 = rel, p2, nil, nil end
        self._points = self._points or {}
        self._points[p] = { rel, p2, x, y }
        M.placed[self] = { p, rel, p2, x, y }
    end
    function w:ClearAllPoints() self._points = {} end
    function w:SetScale(v) self._scale = v end
    function w:GetScale() return self._scale or 1 end
    function w:GetPoint(p) local a = self._points and self._points[p]; if a then return p, a[1], a[2], a[3], a[4] end end
    function w:SetColorTexture(r, g, b, a) self._texColor = { r, g, b, a } end
    function w:SetVertexColor(r, g, b, a) self._vertex = { r, g, b, a } end
    function w:SetGradient(dir, a, b) self._gradient = { dir, a, b } end
    function w:SetTexture(t) self._texture = t end
    function w:SetAtlas(a) self._atlas = a end
    function w:SetTexCoord(...) self._texCoord = { ... } end
    function w:CreateTexture()
        local t = newWidget(nil, "Texture")
        t._owner = self
        return t
    end
    function w:CreateMaskTexture() return newWidget(nil, "MaskTexture") end
    function w:CreateFontString(_, _, template)
        local fs = newWidget(nil, "FontString")
        fs._font = { "Fonts\\FRIZQT__.TTF", 10, "" }
        function fs:GetFont() return self._font[1], self._font[2], self._font[3] end
        function fs:SetFont(p, s, f) self._font = { p, s, f }; return true end
        function fs:GetStringWidth() return #(tostring(self._text or "")) * 7 end
        M.fontStrings[#M.fontStrings + 1] = fs
        return fs
    end
    return w
end
M.newWidget = newWidget

function CreateFrame(kind, name, parent, template)
    local f = newWidget(name, kind)
    f._parent, f._template = parent, template
    M.frames[#M.frames + 1] = f
    if name then M.byName[name] = f; _G[name] = f end
    if template == "InterfaceOptionsCheckButtonTemplate" and name then
        _G[name .. "Text"] = f:CreateFontString()
    end
    if template == "OptionsSliderTemplate" and name then
        _G[name .. "Text"] = f:CreateFontString()
    end
    return f
end

-- Delivers an event to every frame that registered it, in creation order.
function M.Fire(event, ...)
    for _, f in ipairs(M.frames) do
        local handler = f._events[event] and f:GetScript("OnEvent")
        if handler then handler(f, event, ...) end
    end
end

function M.RunTimers()
    local list = M.timers
    M.timers = {}
    for _, fn in ipairs(list) do fn() end
end

UIParent = newWidget("UIParent")
UIParent._w, UIParent._h = 1920, 1080
function UIParent:GetCenter() return 960, 540 end
function UIParent:GetTop() return 1080 end
Minimap = newWidget("Minimap")
Minimap._w, Minimap._h = 140, 140
function Minimap:GetCenter() return 1800, 950 end
GameTooltip = newWidget("GameTooltip")
function GameTooltip:AddLine(t) self._lines = self._lines or {}; self._lines[#self._lines + 1] = t end
function GameTooltip:AddDoubleLine(a, b) self._lines = self._lines or {}; self._lines[#self._lines + 1] = a .. "|" .. b end
function GameTooltip:SetOwner() self._lines = {} end
function GameTooltip:IsOwned() return true end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) M.chat[#M.chat + 1] = m end }
SlashCmdList = {}
UISpecialFrames = {}
tinsert = table.insert
StaticPopupDialogs = {}
function StaticPopup_Show(which, a) M.popups[#M.popups + 1] = { which = which, text = StaticPopupDialogs[which].text, arg = a } end
C_Timer = { After = function(_, fn) M.timers[#M.timers + 1] = fn end }
-- Atlases this client has; the ornate ring is missing on purpose.
M.atlases = { ["communities-ring-gold"] = true }
C_Texture = { GetAtlasInfo = function(a) if M.atlases[a] then return { width = 64, height = 64 } end end }
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
InterfaceOptions_AddCategory = function(panel) M.registered[#M.registered + 1] = panel.name end

M.locale = "enUS"
function GetLocale() return M.locale end
M.build = { "1.60.1", "70009", "Sep 25 2026", 16001 }
function GetBuildInfo() return M.build[1], M.build[2], M.build[3], M.build[4] end
M.state = { combat = false, time = 1000, level = 43, faction = "Alliance", class = "WARLOCK", sex = 2 }
function InCombatLockdown() return M.state.combat end
function GetTime() return M.state.time end
date = os.date
function GetMoney() return M.state.money or 0 end
function GetInventoryItemDurability(slot) local d = M.state.durability and M.state.durability[slot]; if d then return d[1], d[2] end end
function GetInventoryItemLink(_, slot) return "[Item " .. slot .. "]" end
NUM_BAG_SLOTS = 4
C_Container = {
    GetContainerNumSlots = function(bag) return (M.state.bags and M.state.bags[bag] or {})[1] or 0 end,
    GetContainerNumFreeSlots = function(bag) local b = M.state.bags and M.state.bags[bag] or {}; return b[2] or 0, b[3] or 0 end,
}
function GetServerTime() return M.state.serverTime or 1800000000 end
function UnitLevel() return M.state.level end
-- Experience: M.state.xp, xpMax, rested (nil = none), xpOff.
function UnitXP() return M.state.xp or 0 end
function UnitXPMax() return M.state.xpMax or 0 end
function GetXPExhaustion() return M.state.rested end
function IsXPUserDisabled() return M.state.xpOff == true end
function GetMaxPlayerLevel() return 60 end
-- Forever: the state only, no name or multiplier (M.state.restName to vary).
function GetRestState() return 1, M.state.restName, M.state.restMult end
function IsResting() return false end
function UnitFactionGroup() return M.state.faction end
function UnitClass() return "Warlock", M.state.class end
function UnitSex() return M.state.sex end
RAID_CLASS_COLORS = { WARLOCK = { r = 0.53, g = 0.53, b = 0.93 } }
function GetCursorPosition() return 0, 0 end

-- Skills in the old global shape: name, isHeader, isExpanded, rank,
-- tempPoints, modifier, maxRank, isAbandonable.
M.state.skills = {
    { "Professions",      true,  true },
    { "Alchemy",          false, false, 300, 0, 0, 375, true },
    { "Mining",           false, false, 250, 0, 0, 375, true },
    { "Secondary Skills", true,  true },
    { "First Aid",        false, false, 300, 0, 0, 375, false },
    { "Cooking",          false, false, 150, 0, 0, 225, false },
    { "Fishing",          false, false, 100, 0, 0, 375, false },
    { "Weapon Skills",    true,  true },
    { "Swords",           false, false, 200, 0, 0, 215, false },
    { "Armor Proficiencies", true, true },
    { "Cloth",            false, false, 1, 0, 0, 1, false },
}
function GetNumSkillLines() return #M.state.skills end
function GetSkillLineInfo(i)
    local s = M.state.skills[i]
    if not s then return nil end
    return s[1], s[2], s[3], s[4], s[5], s[6], s[7], s[8]
end
function ExpandSkillHeader() for _, s in ipairs(M.state.skills) do if s[2] then s[3] = true end end end
function CollapseSkillHeader(i) local s = M.state.skills[i]; if s then s[3] = false end end

M.state.spellNames = {
    [2259] = "Alchemy", [2575] = "Mining", [2656] = "Smelting",
    [3273] = "First Aid", [2550] = "Cooking", [7620] = "Fishing",
}
function GetSpellInfo(id) return M.state.spellNames[id] end
function GetSpellTexture(id) return "ICON" .. tostring(id) end

-- Professions in the spellbook, as GetProfessions / GetProfessionInfo list
-- them: name, icon, rank, max, numSpells, spellOffset, skillLine.
M.state.professions = {
    { "Alchemy", 0, 300, 375, 1, 10, 171 },
    { "Mining", 0, 250, 375, 1, 12, 186 },
    { "First Aid", 0, 300, 375, 1, 14, 129 },
    { "Cooking", 0, 150, 225, 1, 16, 185 },
}
function GetProfessions() return 1, 2, nil, 4, 3 end
function GetProfessionInfo(i)
    local p = M.state.professions[i]
    return p[1], p[2], p[3], p[4], p[5], p[6], p[7]
end
C_SpellBook = { CastSpellBookItem = function(slot, bank) M.casts[#M.casts + 1] = slot end }
Enum = { SpellBookSpellBank = { Player = 0 }, UITextureSliceMode = { Stretched = 0, Tiled = 1 } }

-- Reputation: name, desc, standing, min, max, value, atWar, canToggle,
-- isHeader, isCollapsed, hasRep, isWatched, isChild, factionID.
FACTION_BAR_COLORS = {
    { r = 0.8, g = 0.3, b = 0.2 }, { r = 0.8, g = 0.3, b = 0.2 }, { r = 0.9, g = 0.6, b = 0.2 },
    { r = 0.9, g = 0.9, b = 0.2 }, { r = 0.2, g = 0.8, b = 0.3 }, { r = 0.2, g = 0.8, b = 0.3 },
    { r = 0.2, g = 0.8, b = 0.3 }, { r = 0.2, g = 0.8, b = 0.3 },
}
M.state.factions = {
    { "Alliance",   nil, 4, 0,    0,     0,     false, false, true,  true,  false, false, false, 469 },
    { "Stormwind",  nil, 5, 3000, 9000,  4000,  false, false, false, false, true,  false, true,  72 },
    { "Ironforge",  nil, 6, 9000, 21000, 12000, false, false, false, false, true,  false, true,  47 },
    { "Darnassus",  nil, 4, 0,    3000,  1500,  false, false, false, false, true,  false, true,  69 },
    { "Gnomeregan", nil, 5, 3000, 9000,  3500,  false, false, false, false, true,  false, true,  54 },
    { "Cenarion Circle", nil, 4, 0, 3000, 100, false, false, false, false, true, false, false, 609 },
}
function GetNumFactions() return #M.state.factions end
function GetFactionInfo(i)
    local f = M.state.factions[i]
    if not f then return nil end
    return f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9], f[10], f[11], f[12], f[13], f[14]
end
function ExpandFactionHeader() for _, f in ipairs(M.state.factions) do if f[9] then f[10] = false end end end
function CollapseFactionHeader(i) local f = M.state.factions[i]; if f then f[10] = true end end
function ToggleCharacter(tab) M.state.characterTab = tab end
FACTION_STANDING_LABEL4 = "Neutral"
FACTION_STANDING_LABEL5 = "Friendly"
FACTION_STANDING_LABEL6 = "Honored"
FACTION_STANDING_LABEL5_FEMALE = "Friendly (f)"
function GetText(key, gender)
    if gender == 3 and _G[key .. "_FEMALE"] then return _G[key .. "_FEMALE"] end
    return _G[key]
end

return M
