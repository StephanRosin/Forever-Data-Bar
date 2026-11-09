local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings

--[[---------------------------------------------------------------------------
Data.lua -- what the data bar shows of professions and reputation: two
primary professions and two secondary skills (the skill list, read off the
running client), the four chosen reputations, and opening a profession the
way Blizzard's own tabs do. Taken over from Forever Progress Data.

Rules it is built by:
  * It never moves, hides or reparents a frame it does not own.
  * Every API that differs between clients is probed at runtime (Forever
    1.60 has C_SkillInfo / C_Reputation, older clients the globals) and
    degrades to "nothing to show" instead of a Lua error.
-----------------------------------------------------------------------------]]
local Data = {}
ns.Data = Data

-- Fixed values: not settings.
local CFG = {
    NUM_SLOTS = 4,          -- 2 primary professions + 2 secondary skills
    NUM_REP_SLOTS = 4,
    REFRESH_THROTTLE = 0.20,
    SKILLFRAME_RETRY = 1.00,
    COLORS = {
        ALCHEMY        = { 0.45, 0.85, 0.35 },  -- flask green
        BLACKSMITHING  = { 0.60, 0.60, 0.65 },  -- steel grey
        ENCHANTING     = { 0.75, 0.45, 0.95 },  -- arcane purple
        ENGINEERING    = { 0.95, 0.60, 0.20 },  -- copper orange
        HERBALISM      = { 0.25, 0.80, 0.45 },  -- leaf green
        JEWELCRAFTING  = { 0.95, 0.35, 0.55 },  -- ruby pink
        LEATHERWORKING = { 0.70, 0.50, 0.30 },  -- tanned leather
        MINING         = { 0.80, 0.70, 0.35 },  -- ore gold
        SKINNING       = { 0.80, 0.35, 0.30 },  -- raw hide red
        TAILORING      = { 0.45, 0.65, 0.95 },  -- bolt-of-cloth blue
        FIRST_AID      = { 0.95, 0.95, 0.95 },  -- bandage white
        COOKING        = { 0.95, 0.75, 0.45 },  -- warm bread
        FISHING        = { 0.35, 0.70, 0.90 },  -- water blue
        RIDING         = { 0.70, 0.65, 0.55 },  -- saddle brown
        UNKNOWN        = { 0.55, 0.55, 0.60 },
    },
}
ns.CFG = CFG


-- =============================================================================
-- Professions
--
-- Skill line names are localised, so nothing is matched by English name. Each
-- profession's localised name comes from its apprentice spell at login.
-- `openSpellID` is the spell whose cast opens the window, if there is one:
-- Mining opens nothing (Smelting does), gathering skills and Riding have no
-- window, and Fishing must never be wired (casting it starts fishing).
-- `ab` is the expansion a profession came with; Jewelcrafting (TBC) does not
-- exist on a vanilla content client such as Forever.
-- =============================================================================
local PROFESSIONS = {
    { key = "ALCHEMY",        spellID = 2259,  kind = "primary", openSpellID = 2259 },
    { key = "BLACKSMITHING",  spellID = 2018,  kind = "primary", openSpellID = 2018 },
    { key = "ENCHANTING",     spellID = 7411,  kind = "primary", openSpellID = 7411 },
    { key = "ENGINEERING",    spellID = 4036,  kind = "primary", openSpellID = 4036 },
    -- Spell 2366 is "Herb Gathering", the skill line "Herbalism": the alias
    -- gives the bar its colour on English clients.
    { key = "HERBALISM",      spellID = 2366,  kind = "primary", aliases = { "Herbalism" } },
    { key = "JEWELCRAFTING",  spellID = 25229, kind = "primary", openSpellID = 25229, ab = 2 },
    { key = "LEATHERWORKING", spellID = 2108,  kind = "primary", openSpellID = 2108 },
    { key = "MINING",         spellID = 2575,  kind = "primary", openSpellID = 2656 },
    { key = "SKINNING",       spellID = 8613,  kind = "primary" },
    { key = "TAILORING",      spellID = 3908,  kind = "primary", openSpellID = 3908 },
    -- Secondary skills, in display order.
    { key = "FIRST_AID",      spellID = 3273,  kind = "secondary", priority = 1, openSpellID = 3273 },
    { key = "COOKING",        spellID = 2550,  kind = "secondary", priority = 2, openSpellID = 2550 },
    { key = "FISHING",        spellID = 7620,  kind = "secondary", priority = 3 },
    { key = "RIDING",         spellID = 33388, kind = "secondary", priority = 4 },
}
Data.PROFESSIONS = PROFESSIONS

local byLocalised = {}
local resolved = false

local function Print(fmt, ...)
    local msg = (select("#", ...) > 0) and string.format(fmt, ...) or fmt
    local frame = DEFAULT_CHAT_FRAME or ChatFrame1
    if frame then frame:AddMessage("|cff66ccff" .. L.ADDON_NAME .. "|r: " .. msg) end
end
ns.Print = Print

-- The standing in the addon's language (Friendly, Honored, ...): own
-- strings, so they follow the language chosen in the options, not only the
-- client's.
-- In the client's own language Blizzard's label wins: it follows the
-- character's gender where the language does (French, Spanish).
local function SameAsClient()
    local client = GetLocale and GetLocale()
    local current = ns.Locale and ns.Locale.Current and ns.Locale.Current()
    if client == "esMX" then client = "esES" end
    return client == nil or current == nil or client == current
end

local function StandingText(standing)
    if not standing then return "" end
    if SameAsClient() then
        if type(GetText) == "function" then
            local ok, text = pcall(GetText, "FACTION_STANDING_LABEL" .. standing, UnitSex and UnitSex("player") or nil)
            if ok and type(text) == "string" and text ~= "" then return text end
        end
        local blizzard = _G["FACTION_STANDING_LABEL" .. standing]
        if blizzard then return blizzard end
    end
    local key = "STANDING_" .. standing
    local own = L[key]
    if own and own ~= key then return own end
    return _G["FACTION_STANDING_LABEL" .. standing] or ""
end

-- A profession's name in the addon's language; the client's name for one
-- the addon does not know.
local function ProfessionLabel(line)
    if not line then return "" end
    local key = line.key and ("PROF_" .. line.key)
    local own = key and L[key]
    if own and own ~= key then return own end
    return line.name or ""
end
Data.ProfessionLabel = ProfessionLabel
-- A spell's localised name, across the shapes this API has taken.
local function SpellName(spellID)
    if type(spellID) ~= "number" then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            return info.name
        end
    end
    if type(_G.GetSpellInfo) == "function" then
        local ok, a = pcall(_G.GetSpellInfo, spellID)
        if ok then
            if type(a) == "string" and a ~= "" then return a end
            if type(a) == "table" and type(a.name) == "string" then return a.name end
        end
    end
    return nil
end

local function SpellIcon(spellID)
    if type(spellID) ~= "number" then return nil end
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and icon then return icon end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" and info.iconID then return info.iconID end
    end
    if type(_G.GetSpellTexture) == "function" then
        local ok, icon = pcall(_G.GetSpellTexture, spellID)
        if ok and icon then return icon end
    end
    if type(_G.GetSpellInfo) == "function" then
        local ok, _, _, icon = pcall(_G.GetSpellInfo, spellID)
        if ok and icon then return icon end
    end
    return nil
end

local function ResolveProfessionNames()
    if resolved then return end
    resolved = true
    for _, p in ipairs(PROFESSIONS) do
        p.icon = SpellIcon(p.spellID)
        local name = SpellName(p.spellID)
        if name then
            p.spellName = name
            byLocalised[name] = p
        end
        if p.openSpellID then p.openSpellName = SpellName(p.openSpellID) end
        for _, alias in ipairs(p.aliases or {}) do
            if not byLocalised[alias] then byLocalised[alias] = p end
        end
    end
end

-- One shape for skills and reputation
--
-- TBC (2.5) has global functions with many return values, Forever (1.60) the
-- same data in C_SkillInfo / C_Reputation tables. Read off the running
-- client, not the retail documentation. One trap: the old isExpanded is the
-- new isCollapsed, inverted. The reputation thresholds are renamed too
-- (barMin/barMax/barValue -> currentReactionThreshold/nextReactionThreshold/
-- currentStanding, hasRep -> isHeaderWithRep).
-- =============================================================================
local Api = {}
ns.Api = Api

local function hasCSkill()
    return C_SkillInfo and type(C_SkillInfo.GetNumSkillLines) == "function"
       and type(C_SkillInfo.GetSkillLineInfo) == "function"
end

local function hasCRep()
    return C_Reputation and type(C_Reputation.GetNumFactions) == "function"
       and type(C_Reputation.GetFactionDataByIndex) == "function"
end

function Api.SkillAPIAvailable()
    if hasCSkill() then
        return type(C_SkillInfo.ExpandSkillHeader) == "function"
           and type(C_SkillInfo.CollapseSkillHeader) == "function"
    end
    return type(GetNumSkillLines) == "function" and type(GetSkillLineInfo) == "function"
       and type(ExpandSkillHeader) == "function" and type(CollapseSkillHeader) == "function"
end

function Api.NumSkillLines()
    if hasCSkill() then return C_SkillInfo.GetNumSkillLines() or 0 end
    return (type(GetNumSkillLines) == "function" and GetNumSkillLines()) or 0
end

-- { name, isHeader, isCollapsed, rank, tempPoints, modifier, maxRank,
--   isAbandonable, skillID }
function Api.SkillLineInfo(i)
    if hasCSkill() then
        local d = C_SkillInfo.GetSkillLineInfo(i)
        if not d then return nil end
        return {
            name = d.name, isHeader = d.isHeader, isCollapsed = d.isCollapsed,
            rank = d.rank, tempPoints = d.tempPoints, modifier = d.modifier,
            maxRank = d.maxRank, isAbandonable = d.isAbandonable, skillID = d.skillID,
        }
    end
    if type(GetSkillLineInfo) ~= "function" then return nil end
    local name, isHeader, isExpanded, rank, tempPoints, modifier, maxRank, isAbandonable = GetSkillLineInfo(i)
    if not name then return nil end
    return {
        name = name, isHeader = isHeader, isCollapsed = not isExpanded,
        rank = rank, tempPoints = tempPoints, modifier = modifier,
        maxRank = maxRank, isAbandonable = isAbandonable,
    }
end

function Api.ExpandSkillHeader(i)
    if hasCSkill() then return C_SkillInfo.ExpandSkillHeader(i) end
    if type(ExpandSkillHeader) == "function" then return ExpandSkillHeader(i) end
end

function Api.CollapseSkillHeader(i)
    if hasCSkill() then return C_SkillInfo.CollapseSkillHeader(i) end
    if type(CollapseSkillHeader) == "function" then return CollapseSkillHeader(i) end
end

function Api.FactionAPIAvailable()
    return hasCRep() or (type(GetNumFactions) == "function" and type(GetFactionInfo) == "function")
end

function Api.NumFactions()
    if hasCRep() then return C_Reputation.GetNumFactions() or 0 end
    return (type(GetNumFactions) == "function" and GetNumFactions()) or 0
end

-- { name, standing, min, max, value, isHeader, isCollapsed, hasRep, factionID }
function Api.FactionInfo(i)
    if hasCRep() then
        local d = C_Reputation.GetFactionDataByIndex(i)
        if not d then return nil end
        return {
            name = d.name, standing = d.reaction,
            min = d.currentReactionThreshold, max = d.nextReactionThreshold,
            value = d.currentStanding, isHeader = d.isHeader, isCollapsed = d.isCollapsed,
            hasRep = d.isHeaderWithRep, factionID = d.factionID,
        }
    end
    if type(GetFactionInfo) ~= "function" then return nil end
    local name, _, standing, barMin, barMax, barValue, _, _, isHeader,
          isCollapsed, hasRep, _, _, factionID = GetFactionInfo(i)
    if not name then return nil end
    return {
        name = name, standing = standing, min = barMin, max = barMax, value = barValue,
        isHeader = isHeader, isCollapsed = isCollapsed, hasRep = hasRep, factionID = factionID,
    }
end

function Api.ExpandFactionHeader(i)
    if hasCRep() and type(C_Reputation.ExpandFactionHeader) == "function" then
        return C_Reputation.ExpandFactionHeader(i)
    end
    if type(ExpandFactionHeader) == "function" then return ExpandFactionHeader(i) end
end

function Api.CollapseFactionHeader(i)
    if hasCRep() and type(C_Reputation.CollapseFactionHeader) == "function" then
        return C_Reputation.CollapseFactionHeader(i)
    end
    if type(CollapseFactionHeader) == "function" then return CollapseFactionHeader(i) end
end

-- =============================================================================
-- Skill scan
--
-- The skill list reports only lines under EXPANDED headers, so everything is
-- expanded, read and put back as it was. Collapsing shifts the indices of
-- the lines below, so the restore walks the headers backwards. Expanding and
-- collapsing fire SKILL_LINES_CHANGED; the `scanning` flag and a short
-- suppression window keep scan -> event -> scan from looping.
-- =============================================================================
local scanning = false
local suppressSkillEventsUntil = 0

local function SkillWindowOpen()
    local f = _G.SkillFrame
    if not f then return false end
    if f.IsVisible then return f:IsVisible() end
    return f:IsShown()
end

-- Every non-header line, grouped under its header.
local function CollectLines()
    local order, current = {}, nil
    for i = 1, Api.NumSkillLines() do
        local d = Api.SkillLineInfo(i)
        if d and d.name then
            if d.isHeader then
                current = { name = d.name, lines = {} }
                order[#order + 1] = current
            elseif current then
                local rank, maxRank = tonumber(d.rank) or 0, tonumber(d.maxRank) or 0
                -- Forever lists every profession TWICE in a row, with the same
                -- rank. Only an exact repeat under the same header is dropped,
                -- so two different skills can never merge.
                local repeated = false
                for _, seen in ipairs(current.lines) do
                    if seen.name == d.name and seen.rank == rank and seen.maxRank == maxRank then
                        repeated = true
                        break
                    end
                end
                if not repeated then
                    current.lines[#current.lines + 1] = {
                        name = d.name, rank = rank, maxRank = maxRank,
                        modifier = tonumber(d.modifier) or 0,
                        tempPoints = tonumber(d.tempPoints) or 0,
                        isAbandonable = d.isAbandonable and true or false,
                        skillID = d.skillID, prof = byLocalised[d.name],
                    }
                end
            end
        end
    end
    return order
end

-- primaries, secondaries; or nil, nil, reason ("skillframe", "noapi", "error").
local function ScanSkills()
    if not Api.SkillAPIAvailable() then return nil, nil, "noapi" end
    -- Expanding headers under the player's nose would scroll an open skill
    -- window around; the caller retries when it is closed.
    if SkillWindowOpen() then return nil, nil, "skillframe" end

    scanning = true
    local collapsed, groups, mutated = {}, nil, false
    local ok = pcall(function()
        local any = false
        for i = 1, Api.NumSkillLines() do
            local d = Api.SkillLineInfo(i)
            if d and d.isHeader and d.isCollapsed then
                collapsed[d.name] = true
                any = true
            end
        end
        -- Index 0 means "all" for both expand and collapse.
        if any then
            Api.ExpandSkillHeader(0)
            mutated = true
        end
        groups = CollectLines()
    end)
    if mutated then
        pcall(function()
            local headers = {}
            for i = 1, Api.NumSkillLines() do
                local d = Api.SkillLineInfo(i)
                if d and d.isHeader then headers[#headers + 1] = { index = i, name = d.name } end
            end
            for i = #headers, 1, -1 do
                if collapsed[headers[i].name] then Api.CollapseSkillHeader(headers[i].index) end
            end
        end)
        suppressSkillEventsUntil = GetTime() + 0.5
    end
    scanning = false
    if not ok then return nil, nil, "error" end

    -- Classification, locale independent, most reliable first:
    --   a) the header holding a recognised primary (secondary) skill is the
    --      professions (secondary skills) header: all its lines belong to it;
    --   b) else primary professions are the only skills you can unlearn;
    --   c) else by name.
    local primaryHeader, secondaryHeader
    for _, h in ipairs(groups or {}) do
        for _, line in ipairs(h.lines) do
            if line.prof then
                if line.prof.kind == "primary" and not primaryHeader then
                    primaryHeader = h
                elseif line.prof.kind == "secondary" and not secondaryHeader then
                    secondaryHeader = h
                end
            end
        end
    end
    if not primaryHeader then
        for _, h in ipairs(groups or {}) do
            for _, line in ipairs(h.lines) do
                if line.isAbandonable and h ~= secondaryHeader then
                    primaryHeader = h
                    break
                end
            end
            if primaryHeader then break end
        end
    end

    local primaries, secondaries = {}, {}
    local function accept(list, line, kind)
        -- Weapon and armour proficiencies have a maximum of 1.
        if (line.maxRank or 0) <= 1 then return end
        line.key = line.prof and line.prof.key or "UNKNOWN"
        line.kind = kind
        list[#list + 1] = line
    end
    for _, h in ipairs(groups or {}) do
        for _, line in ipairs(h.lines) do
            if h == primaryHeader then
                accept(primaries, line, "primary")
            elseif h == secondaryHeader then
                accept(secondaries, line, "secondary")
            elseif line.prof then
                accept(line.prof.kind == "primary" and primaries or secondaries, line, line.prof.kind)
            end
        end
    end
    table.sort(secondaries, function(a, b)
        local pa = a.prof and a.prof.priority or 99
        local pb = b.prof and b.prof.priority or 99
        if pa ~= pb then return pa < pb end
        return a.name < b.name
    end)
    return primaries, secondaries
end
Data.ScanSkills = function() return ScanSkills() end

-- =============================================================================
-- Opening a profession, the way Blizzard's own tabs do
--
-- After ProfessionsLargeRightTabMixin:CastProfessionSpell
-- (Blizzard_ProfessionsTemplates.lua): cast the SPELLBOOK ENTRY
-- (spellOffset + 1), and only when that profession is not already selected;
-- otherwise every click sends a new request and the answers overtake each
-- other. skillLine and spellOffset come from GetProfessions() and
-- GetProfessionInfo(index), which include Cooking and First Aid.
-- =============================================================================
local function ProfessionInfo(name)
    if not name or type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
        return nil
    end
    local ok, i1, i2, i3, i4, i5, i6, i7 = pcall(GetProfessions)
    if not ok then return nil end
    -- Not ipairs: GetProfessions returns gaps (nil for a missing second
    -- primary), and ipairs would stop there.
    local indices = { i1, i2, i3, i4, i5, i6, i7 }
    for i = 1, 7 do
        local index = indices[i]
        if index then
            local okInfo, found, _, _, _, _, spellOffset, skillLine = pcall(GetProfessionInfo, index)
            if okInfo and found == name and type(spellOffset) == "number" then
                return skillLine, spellOffset
            end
        end
    end
    return nil
end
Data.ProfessionInfo = ProfessionInfo

local function IsSelected(skillLine)
    if not skillLine then return false end
    local f = _G.Professions
    if not (f and type(f.IsSelectedProfession) == "function") then return false end
    local ok, yes = pcall(f.IsSelectedProfession, skillLine)
    return ok and yes and true or false
end

local function WindowShown()
    local f = _G.ProfessionsFrame
    return (f and f.IsShown and f:IsShown()) and true or false
end

-- The profession to show once the window stands.
--
-- On showing, the window makes EVERY tab cast its profession spell
-- (EventRegistry "ProfessionsFrame.Show"), and the last answer wins: a click
-- on Cooking loaded Cooking and then jumped to another profession. So until
-- the deadline, every trade skill event switches back to ours; it comes
-- after the last answer and wins. Nothing happens while ours is selected.
local wantedTab, wantedUntil
local TAB_DEADLINE = 2

-- Switching the window to a profession: C_TradeSkillUI.OpenTradeSkill, as
-- Blizzard's own bootstrap does, only when another profession is shown.
-- Never Blizzard's profession tabs: pressing them from an addon runs
-- Blizzard's window code in the addon's execution, which leaves the window
-- tainted. In combat that is refused at once (Frame:Hide on the tabs); out
-- of combat a later protected action in the window (crafting) is then
-- refused: "ForeverProgressBars has been blocked from an action only
-- available to the Blizzard UI". OpenTradeSkill changes the profession in
-- the game; the window follows through its own events, untainted.
local function SelectProfession(skillLine)
    local api = C_TradeSkillUI
    if not (api and api.OpenTradeSkill) then return false end
    local ok, info = pcall(function() return api.GetBaseProfessionInfo and api.GetBaseProfessionInfo() end)
    if ok and type(info) == "table" and info.professionID == skillLine then return true end
    pcall(api.OpenTradeSkill, skillLine)
    return true
end

local function OpenProfession(skillLine, spellOffset)
    if not spellOffset then return "no data" end
    -- Open and already selected: close it.
    if WindowShown() and IsSelected(skillLine) then
        wantedTab, wantedUntil = nil, nil
        if C_TradeSkillUI and C_TradeSkillUI.CloseTradeSkill then pcall(C_TradeSkillUI.CloseTradeSkill) end
        return "closed"
    end
    -- Open on another profession: switch to this one.
    if WindowShown() and SelectProfession(skillLine) then
        wantedTab, wantedUntil = nil, nil
        return "switched"
    end
    -- Closed: cast and remember which profession is wanted.
    local cast = C_SpellBook and C_SpellBook.CastSpellBookItem
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if type(cast) ~= "function" or bank == nil then return "no spellbook" end
    wantedTab = skillLine
    wantedUntil = ((GetTime and GetTime()) or 0) + TAB_DEADLINE
    pcall(cast, spellOffset + 1, bank)
    return "opened"
end
Data.OpenProfession = OpenProfession

-- After opening, every tab of the window casts its profession and the last
-- answer wins; until the deadline each trade skill event switches back to
-- the wanted one.
local function PressWantedTab()
    if not wantedTab then return "none" end
    local now = (GetTime and GetTime()) or 0
    if wantedUntil and now > wantedUntil then
        wantedTab, wantedUntil = nil, nil
        return "expired"
    end
    if SelectProfession(wantedTab) then return "switched" end
    return "no api"
end
Data.PressWantedTab = PressWantedTab

-- =============================================================================
-- What shows: two primaries and two secondaries, hidden ones skipped
-- =============================================================================
local shown = {}            -- slot -> skill line (nil: empty)
local lastScan = { primaries = {}, secondaries = {} }
local warnedNoAPI, pendingRefresh = false, false

-- Every skill the last scan found, primaries first (for the options).
function Data.KnownSkills()
    local list = {}
    for _, l in ipairs(lastScan.primaries) do list[#list + 1] = l end
    for _, l in ipairs(lastScan.secondaries) do list[#list + 1] = l end
    return list
end

-- The four slots' skill lines; an empty slot stays empty, nothing shifts.
function Data.Professions() return shown end

function Data.Refresh()
    ResolveProfessionNames()
    local primaries, secondaries, reason = ScanSkills()
    if not primaries then
        if reason == "skillframe" then
            if C_Timer then C_Timer.After(CFG.SKILLFRAME_RETRY, Data.Refresh) end
        elseif reason == "noapi" and not warnedNoAPI then
            warnedNoAPI = true
            Print(L.MSG_NO_SKILL_API)
        end
        return
    end
    lastScan.primaries, lastScan.secondaries = primaries, secondaries
    local p, s = {}, {}
    for _, line in ipairs(primaries) do
        if not Settings.IsHidden(line.name, line.key) and #p < 2 then p[#p + 1] = line end
    end
    for _, line in ipairs(secondaries) do
        if not Settings.IsHidden(line.name, line.key) and #s < 2 then s[#s + 1] = line end
    end
    shown = { p[1], p[2], s[1], s[2] }
    if ns.DataBar then ns.DataBar.UpdateProfessions() end
end

local function ScheduleRefresh(delay)
    if pendingRefresh or scanning then return end
    pendingRefresh = true
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or CFG.REFRESH_THROTTLE, function()
            pendingRefresh = false
            Data.Refresh()
        end)
    else
        pendingRefresh = false
        Data.Refresh()
    end
end

-- =============================================================================
-- Reputation
--
-- The same trap as the skill list: only factions under expanded headers are
-- listed. Colours come from FACTION_BAR_COLORS, the table the character
-- sheet uses.
-- =============================================================================
local scanningFactions = false
local factionCache

local function ScanFactions()
    if not Api.FactionAPIAvailable() then return nil end
    scanningFactions = true
    local collapsed, list, mutated = {}, {}, false
    local ok = pcall(function()
        local any = false
        for i = 1, Api.NumFactions() do
            local d = Api.FactionInfo(i)
            if d and d.isHeader and d.isCollapsed and d.name then
                collapsed[d.name] = true
                any = true
            end
        end
        if any then
            Api.ExpandFactionHeader(0)
            mutated = true
        end
        for i = 1, Api.NumFactions() do
            local d = Api.FactionInfo(i) or {}
            -- Headers can carry reputation of their own (Alliance Forces).
            if d.name and d.factionID and (not d.isHeader or d.hasRep) then
                list[#list + 1] = {
                    id = d.factionID, name = d.name, standing = d.standing,
                    min = d.min or 0, max = d.max or 0, value = d.value or 0,
                }
            end
        end
    end)
    if mutated then
        pcall(function()
            local headers = {}
            for i = 1, Api.NumFactions() do
                local d = Api.FactionInfo(i)
                if d and d.isHeader then headers[#headers + 1] = { index = i, name = d.name } end
            end
            for i = #headers, 1, -1 do
                if collapsed[headers[i].name] then Api.CollapseFactionHeader(headers[i].index) end
            end
        end)
    end
    scanningFactions = false
    if not ok then return nil end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function ns.Factions(force)
    if force or not factionCache then factionCache = ScanFactions() end
    return factionCache or {}
end

Data.StandingText = StandingText

local function FactionColour(standing)
    local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[standing]
    if c and c.r then return c.r, c.g, c.b end
    return unpack(CFG.COLORS.UNKNOWN)
end

-- A reputation slot's faction as values, or nil (empty slot, unknown faction).
function Data.RepData(index)
    local wanted = Settings.Reps()[index]
    if not wanted or wanted == 0 then return nil end
    for _, f in ipairs(ns.Factions()) do
        if f.id == wanted then
            return {
                name = f.name, rank = f.value - f.min, maxRank = math.max(1, f.max - f.min),
                standingText = StandingText(f.standing), standing = f.standing,
                colour = { FactionColour(f.standing) },
            }
        end
    end
    return nil
end

function ns.RefreshReputation()
    ns.Factions(true)
    if ns.DataBar then ns.DataBar.UpdateReps() end
end

-- The faction for a slot, from a menu of every faction the character knows.
local factionMenu, menuSlot

function ns.OpenFactionMenu(slot, anchor)
    if not (UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo
            and UIDropDownMenu_AddButton and ToggleDropDownMenu) then
        return false
    end
    menuSlot = slot
    if not factionMenu then
        factionMenu = CreateFrame("Frame", "ForeverDataBarFactionMenu", UIParent, "UIDropDownMenuTemplate")
    end
    UIDropDownMenu_Initialize(factionMenu, function(_, level)
        local chosen = Settings.Reps()[menuSlot]
        local empty = UIDropDownMenu_CreateInfo()
        empty.text = L.REP_EMPTY
        empty.checked = (chosen == nil or chosen == 0)
        empty.func = function()
            Settings.SetRep(menuSlot, 0)
            if CloseDropDownMenus then CloseDropDownMenus() end
        end
        UIDropDownMenu_AddButton(empty, level)
        for _, f in ipairs(ns.Factions()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = f.name
            info.checked = (chosen == f.id)
            local id = f.id
            info.func = function()
                Settings.SetRep(menuSlot, id)
                if CloseDropDownMenus then CloseDropDownMenus() end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")
    ToggleDropDownMenu(1, nil, factionMenu, anchor or "cursor", 0, 0)
    return true
end


-- =============================================================================
-- Events
-- =============================================================================
local WANTED_EVENTS = {
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL",
    "LEARNED_SPELL_IN_SKILL_LINE", "LEARNED_SPELL_IN_TAB",   -- RegisterEvent throws if unknown
    "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "UPDATE_FACTION",
}

local events = CreateFrame("Frame")
for _, e in ipairs(WANTED_EVENTS) do pcall(events.RegisterEvent, events, e) end

events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        ResolveProfessionNames()
        ScheduleRefresh(0)
        -- The faction list is not ready at login yet.
        if C_Timer and C_Timer.After then C_Timer.After(2, ns.RefreshReputation) end
    elseif event == "UPDATE_FACTION" then
        -- Our own expand/collapse fires this again.
        if not scanningFactions then ns.RefreshReputation() end
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
        PressWantedTab()
    elseif event == "SKILL_LINES_CHANGED" then
        if scanning or GetTime() < suppressSkillEventsUntil then return end
        ScheduleRefresh()
    elseif not scanning then
        ScheduleRefresh()
    end
end)

Settings.OnChange(function(key)
    if key == "hidden" or key == nil then Data.Refresh() end
    if key == "reps" or key == nil then ns.RefreshReputation() end
end)
ns.Locale.OnChange(function()
    Data.Refresh()
    ns.RefreshReputation()
end)
