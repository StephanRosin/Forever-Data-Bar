local ADDON, ns = ...
local L = ns.L

--[[---------------------------------------------------------------------------
Xp.lua -- what the XP part needs from the game: whether there is experience
to show, its tooltip, unspent talents, and the session behind "XP/h" and
"Level in". The session starts at login and survives /reload (kept per
character in ForeverDataBarChar.xpSession).
-----------------------------------------------------------------------------]]
local Xp = {}
ns.Xp = Xp

Xp.TALENT_PULSE_SPEED = 3
local PULSE_BRIGHTEST = 1

-- Whether there is experience to show: not at the maximum level, not
-- switched off.
function Xp.Active()
    if IsXPUserDisabled and IsXPUserDisabled() then return false end
    local level = UnitLevel and UnitLevel("player") or 0
    local maxLevel = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion())
        or (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
    return level < maxLevel and (UnitXPMax("player") or 0) > 0
end

-- A colour lighter by wave (0..1) towards white.
function Xp.PulseColour(c, wave)
    local k = wave * PULSE_BRIGHTEST
    return c[1] + (1 - c[1]) * k, c[2] + (1 - c[2]) * k, c[3] + (1 - c[3]) * k
end

function Xp.ShowTooltip(self)
    local cur, max = UnitXP("player"), UnitXPMax("player")
    if not max or max <= 0 then return end
    local big = BreakUpLargeNumbers or tostring
    local grey, white = { 0.8, 0.8, 0.8 }, { 1, 1, 1 }
    local function row(label, value, c)
        c = c or white
        GameTooltip:AddDoubleLine(label, value, grey[1], grey[2], grey[3], c[1], c[2], c[3])
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.XP_LEVEL:format(UnitLevel("player") or 0), 1, 1, 1)
    row(L.TIP_XP, ("%s / %s"):format(big(cur), big(max)))
    row(L.TIP_XP_PROGRESS, ("%d%%"):format(math.floor(cur / max * 100)))
    row(L.TIP_XP_TO_LEVEL, big(max - cur))
    local rested = GetXPExhaustion and GetXPExhaustion()
    if rested and rested > 0 then
        row(L.TIP_XP_RESTED, ("%s (%d%%)"):format(big(rested), math.floor(rested / max * 100)), { 0.4, 0.6, 1 })
    end
    GameTooltip:Show()
end

function Xp.HasUnspentTalents()
    local api = C_ClassTalents and C_ClassTalents.HasUnspentTalentPoints
    return api ~= nil and api() == true
end

-- From addon code the panel manager refuses in combat.
function Xp.ToggleTalents()
    if InCombatLockdown() then
        ns.Print(L.MSG_TALENTS_IN_COMBAT)
        return
    end
    PlayerSpellsUtil.ToggleClassTalentOrSpecFrame()
end

-- Blizzard's experience and reputation bars, hidden while the XP part shows.
local hooked = false
function Xp.BlizzardBars(show)
    local manager = _G.StatusTrackingBarManager
    if not manager then return end
    if not hooked then
        hooked = true
        -- HookScript, never hooksecurefunc on a frame method (Forever).
        manager:HookScript("OnShow", function(self)
            if not Xp.blizzardShown then self:Hide() end
        end)
    end
    Xp.blizzardShown = show
    if show then manager:Show() else manager:Hide() end
end

-- -----------------------------------------------------------------------------
-- The session: XP per hour and the time to the next level
-- -----------------------------------------------------------------------------
function Xp.Now() return (GetServerTime or time)() end

-- 2d 14h 11m; below a minute "< 1m".
function Xp.Duration(sec)
    sec = math.floor(sec or 0)
    if sec < 60 then return L.DUR_LESS end
    local d, h, m = math.floor(sec / 86400), math.floor(sec % 86400 / 3600), math.floor(sec % 3600 / 60)
    local parts = {}
    if d > 0 then parts[#parts + 1] = L.DUR_D:format(d) end
    if d > 0 or h > 0 then parts[#parts + 1] = L.DUR_H:format(h) end
    parts[#parts + 1] = L.DUR_M:format(m)
    return table.concat(parts, " ")
end

-- XP per hour, or nil while there is nothing to go by.
function Xp.PerHour(gained, seconds)
    if not gained or gained <= 0 or not seconds or seconds <= 0 then return nil end
    return gained / seconds * 3600
end

-- XP gained between two readings; across a level-up the rest of the old
-- level counts too.
function Xp.Gain(lastXP, lastMax, xp)
    if xp >= lastXP then return xp - lastXP end
    return math.max(0, lastMax - lastXP) + xp
end

local function session() return ns.CharDB().xpSession end

function Xp.Rate()
    local s = session()
    return s and Xp.PerHour(s.gained, Xp.Now() - s.start)
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE" }) do pcall(events.RegisterEvent, events, e) end
events:SetScript("OnEvent", function(_, event, isLogin)
    if event == "PLAYER_ENTERING_WORLD" then
        -- A fresh login starts a session; /reload and loading screens keep it.
        if isLogin or not session() then
            ns.CharDB().xpSession = { start = Xp.Now(), gained = 0,
                lastXP = UnitXP("player") or 0, lastMax = UnitXPMax("player") or 0 }
        end
    else
        local s = session()
        if s then
            local xp = UnitXP("player") or 0
            s.gained = s.gained + Xp.Gain(s.lastXP, s.lastMax, xp)
            s.lastXP, s.lastMax = xp, UnitXPMax("player") or 0
        end
    end
end)
