local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings
local S = Settings.Get

--[[---------------------------------------------------------------------------
Micro.lua -- Blizzard's micro menu as own icons around the clock: half of the
buttons left of it, half right.

Each icon is a secure button (type "click") that clicks Blizzard's own micro
button: the window then opens from secure code. Opened from addon code it
would be tainted (the character window then fails on Forever's secret
values), and in combat the panel manager refuses addon code altogether.

Secure buttons make their parent protected, so they sit on a holder of their
own on UIParent, not on the bar, and are never anchored to it: the bar stays
free to move and hide in combat. The holder takes the clock's place by
coordinates (DataBar.Layout), hides by a state driver ([combat] / [group],
as the bar), and is only touched out of combat; a change in combat waits for
PLAYER_REGEN_ENABLED.

A button counts while Blizzard's exists, shown or not: bar addons such as
Bartender hide or move Blizzard's micro menu.
-----------------------------------------------------------------------------]]
local Micro = {}
ns.Micro = Micro

-- The buttons Forever offers, in Blizzard's order (Camelot
-- MicroMenuMixin:GenerateButtonInfos); its game rules hide the others
-- (housing, adventure guide, help, shop, game menu).
Micro.BUTTONS = {
    { name = "CharacterMicroButton", icon = "MicroCharacter" },
    { name = "ProfessionMicroButton", icon = "MicroProfessions" },
    { name = "SpellbookMicroButton", icon = "MicroSpellbook" },
    { name = "TalentMicroButton", icon = "MicroTalents" },
    { name = "LegacyMicroButton", icon = "MicroLegacy" },
    { name = "QuestLogMicroButton", icon = "MicroQuestLog" },
    { name = "GuildMicroButton", icon = "MicroGuild" },
    { name = "LFDMicroButton", icon = "MicroLFD" },
    -- Off by default: eight split evenly, four on each side of the clock.
    { name = "CollectionsMicroButton", icon = "MicroCollections", key = "dataBarMicroCollections" },
}

local holder, buttons
local shown = {}          -- the Blizzard buttons with an icon, in order
local pending = false     -- a change waits for the end of combat

local function Wanted() return S("dataBarMicro") == true end

-- The Blizzard buttons there are, read out of combat only.
local function Collect()
    shown = {}
    for _, b in ipairs(Micro.BUTTONS) do
        if _G[b.name] and (not b.key or S(b.key)) then shown[#shown + 1] = b end
    end
end

-- Icons left and right of the clock.
function Micro.Count()
    if not Wanted() then return 0, 0 end
    if not InCombatLockdown() then Collect() end
    local n = #shown
    return math.ceil(n / 2), math.floor(n / 2)
end

local function ShowTooltip(self)
    local blizzard = _G[self.blizzard]
    GameTooltip:SetOwner(self, ns.DataBar.frame and ns.DataBar.frame.atTop and "ANCHOR_BOTTOM" or "ANCHOR_TOP")
    GameTooltip:AddLine((blizzard and blizzard.tooltipText) or self.blizzard, 1, 1, 1)
    GameTooltip:Show()
end

local function Build()
    if holder then return end
    holder = CreateFrame("Frame", "ForeverDataBarMicro", UIParent, "SecureHandlerStateTemplate")
    holder:SetFrameStrata("MEDIUM")
    holder:SetFrameLevel(20)
    holder:Hide()
    buttons = {}
    for i, b in ipairs(Micro.BUTTONS) do
        local button = CreateFrame("Button", "ForeverDataBarMicro" .. i, holder, "SecureActionButtonTemplate")
        button:RegisterForClicks("AnyUp", "AnyDown")
        button:SetAttribute("type", "click")
        button.blizzard = b.name
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints(button)
        button.icon:SetTexture(ns.DataBar.CFG.MEDIA .. b.icon)
        local glow = button:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints(button)
        glow:SetTexture(ns.DataBar.CFG.MEDIA .. b.icon)
        glow:SetBlendMode("ADD")
        button:SetScript("OnEnter", ShowTooltip)
        button:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
        button:Hide()
        buttons[i] = button
    end
end

-- Hidden as the bar is: in combat, in a group, or not at all.
local function Visibility()
    local rules = {}
    if S("hideInCombat") then rules[#rules + 1] = "[combat] hide" end
    if S("hideInGroup") then rules[#rules + 1] = "[group] hide" end
    rules[#rules + 1] = "show"
    return table.concat(rules, "; ")
end

-- At the clock's place: x from the screen's left edge, the bar's height.
-- left: the room on the left of the clock text, gap: the clock text's.
function Micro.Place(x, barHeight, atTop, left, gap)
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    Build()
    UnregisterStateDriver(holder, "visibility")
    if not Wanted() or #shown == 0 then
        holder:Hide()
        return
    end
    local cfg = ns.DataBar.CFG
    local step = cfg.ICON + cfg.ICON_GAP
    local nLeft = math.ceil(#shown / 2)
    holder:ClearAllPoints()
    holder:SetPoint("LEFT", UIParent, atTop and "TOPLEFT" or "BOTTOMLEFT", x, atTop and -barHeight / 2 or barHeight / 2)
    holder:SetSize(math.max(1, left + gap + (#shown - nLeft) * step), cfg.ICON)
    local accent = S("dataBarAccent")
    for _, button in ipairs(buttons) do button:Hide() end
    for i, b in ipairs(shown) do
        local button
        for _, candidate in ipairs(buttons) do if candidate.blizzard == b.name then button = candidate end end
        button:SetAttribute("clickbutton", _G[b.name])
        button:SetSize(cfg.ICON, cfg.ICON)
        button:ClearAllPoints()
        local offset = (i <= nLeft) and (i - 1) * step or (left + gap + cfg.ICON_GAP + (i - nLeft - 1) * step)
        button:SetPoint("LEFT", holder, "LEFT", offset, 0)
        button.icon:SetVertexColor(accent[1], accent[2], accent[3], 1)
        button:Show()
    end
    RegisterStateDriver(holder, "visibility", Visibility())
end

-- The bar is hidden for good (not by combat or group): so are the icons.
function Micro.Hide()
    if not holder or InCombatLockdown() then
        pending = pending or holder ~= nil
        return
    end
    UnregisterStateDriver(holder, "visibility")
    holder:Hide()
end

Micro.Holder = function() return holder end
Micro.Buttons = function() return buttons end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event)
    -- Blizzard shows or hides a button (a level, a game rule): count again.
    if event ~= "PLAYER_REGEN_ENABLED" or pending then
        if ns.DataBar.Apply then ns.DataBar.Apply() end
    end
end)
