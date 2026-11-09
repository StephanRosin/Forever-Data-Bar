local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings
local S = Settings.Get

--[[---------------------------------------------------------------------------
DataBar.lua -- one thin strip across the screen, at its top or bottom edge:
experience ("75% to level 33" over a hairline), gold, durability, bags, the
clock, up to four professions (icon, name, value, hairline) and the four
reputations if wanted. Each part sits in one of five columns, shifted by its
own X.

What it shows of professions and reputation comes from Data.lua
(Data.Professions, Data.RepData), which calls DataBar.UpdateProfessions and
DataBar.UpdateReps when something changes.

A plain frame without secure children: it may show and hide in combat.
-----------------------------------------------------------------------------]]
local DataBar = {}
ns.DataBar = DataBar

-- Fixed values: not settings.
local CFG = {
    PAD = 12,               -- from the screen edges
    PROF_GAP = 16,          -- between entries, and between parts at one place
    CLOCK_WIDTH = 40,
    TALENT_WIDTH = 48,      -- "Talents" beside the XP line
    ICON = 15,
    ICON_GAP = 6,
    TEXT_GAP = 3,           -- between a label and its line
    CLOCK_PLUS = 2,         -- the clock: larger than its font size
    ADD_PLUS = 5,           -- the reputation's "+"
    CLOCK_INTERVAL = 1,     -- seconds between clock checks
    TRACK = { 0.12, 0.12, 0.12 },   -- the empty part of a line (white at 12 %)
    CAP_COLOR = { 0.89, 0.71, 0.29 },  -- at the cap: time for the trainer
    REST_ALPHA = 0.35,
    EDGE_ALPHA = 0.7,
    SEGMENT_GAP = { 0, 0, 0, 0.85 },
    MEDIA = "Interface\\AddOns\\ForeverDataBar\\Media\\",
    PHIAL_GLASS = { 0.09, 0.085, 0.12 },
    PHIAL_RIM = { 0.48, 0.42, 0.25, 1 },
    PHIAL_CAP_W = 4,        -- the brass caps, outside the tube's ends
    PHIAL_CAP_OVER = 2,     -- how far a cap stands above and below the tube
}
DataBar.CFG = CFG

-- The looks. track: line thickness in px; segments: XP and profession
-- line split in that many parts; glow: the fill glows; iconsOnly: the
-- professions without labels, their values in the tooltip.
DataBar.DESIGNS = {
    HAIR = { track = 1, fade = true },
    SEGMENTS = { track = 3, segments = { 20, 10 } },
    GLASS = { track = 2, glow = true },
    ICONS = { track = 2, iconsOnly = true },
    -- An alchemy phial, small: a glass tube between brass
    -- caps, the liquid in the line's colour, bubbles and a gloss.
    PHIAL = { track = 5, phial = true },
}
DataBar.DESIGN_ORDER = { "GLASS", "HAIR", "SEGMENTS", "ICONS", "PHIAL" }

-- The icon file per profession key (Media/Prof<Name>.tga, own art, white).
DataBar.ICONS = {
    ALCHEMY = "ProfAlchemy", BLACKSMITHING = "ProfBlacksmithing", ENCHANTING = "ProfEnchanting",
    ENGINEERING = "ProfEngineering", HERBALISM = "ProfHerbalism", JEWELCRAFTING = "ProfJewelcrafting",
    LEATHERWORKING = "ProfLeatherworking", MINING = "ProfMining", SKINNING = "ProfSkinning",
    TAILORING = "ProfTailoring", FIRST_AID = "ProfFirstAid", COOKING = "ProfCooking",
    FISHING = "ProfFishing", RIDING = "ProfRiding",
}

-- Plain values in, text out, so the tests need no game.
function DataBar.XpText(level, cur, max)
    if type(cur) ~= "number" or type(max) ~= "number" or max <= 0 then return "" end
    return L.DATABAR_XP:format(math.floor(cur / max * 100), (level or 0) + 1)
end

function DataBar.Design()
    return DataBar.DESIGNS[S("dataBarDesign")] or DataBar.DESIGNS.GLASS
end

local frame
local inCombat = false

local function InGroup()
    if IsInGroup then return IsInGroup() and true or false end
    return (GetNumGroupMembers and GetNumGroupMembers() or 0) > 0
end

function DataBar.Wanted()
    if S("hideInCombat") and inCombat then return false end
    if S("hideInGroup") and InGroup() then return false end
    return true
end

-- -----------------------------------------------------------------------------
-- Building
-- -----------------------------------------------------------------------------
-- The font of a part: its own, or the one for all parts.
-- Returns path, size, outline and colour.
function DataBar.FontFor(key)
    local own = S(key .. "FontOwn") and key or "dataBar"
    return ns.Media.FontPath(S(own .. "Font")), S(own .. "FontSize"), S("dataBarFontOutline"), S(own .. "FontColor")
end

-- Every text, with its part and how it takes the part's font: "text" in
-- the colour, "value" in the colour but fainter, "size" the font only
-- (its colour means something); plus: larger by this much.
local texts = {}
local VALUE_ALPHA = 0.63
local function Font(fs, key, role, plus)
    texts[#texts + 1] = { fs = fs, key = key, role = role or "text", plus = plus or 0 }
    if fs.SetWordWrap then fs:SetWordWrap(false) end
end

local function ApplyFonts()
    for _, t in ipairs(texts) do
        local path, size, outline, c = DataBar.FontFor(t.key)
        if not t.fs:SetFont(path, size + t.plus, outline) then
            t.fs:SetFont(ns.Media.DEFAULT_FONT, size + t.plus, outline)
        end
        if t.role == "text" then t.fs:SetTextColor(c[1], c[2], c[3], 1)
        elseif t.role == "value" then t.fs:SetTextColor(c[1], c[2], c[3], VALUE_ALPHA) end
    end
end

-- The text colour of a part, for texts coloured later (gold, bags).
function DataBar.TextColour(key) return select(4, DataBar.FontFor(key)) end
local function TextHeight(key) return select(2, DataBar.FontFor(key)) end

-- A line: track, rested part, fill, glow, and dividers made on demand.
local function NewLine(parent, width)
    local line = CreateFrame("Frame", nil, parent)
    line:SetWidth(width)
    line.width = width
    line.track = line:CreateTexture(nil, "BACKGROUND")
    line.track:SetAllPoints(line)
    line.glow = line:CreateTexture(nil, "BORDER")
    line.rest = line:CreateTexture(nil, "ARTWORK", nil, 1)
    line.fill = line:CreateTexture(nil, "ARTWORK", nil, 2)
    line.dividers = {}
    -- The phial's parts, shown only in that design.
    line.bubbles = line:CreateTexture(nil, "ARTWORK", nil, 3)
    line.bubbles:SetTexture(CFG.MEDIA .. "PhialBubbles.tga", "REPEAT", "CLAMP")
    if line.bubbles.SetHorizTile then line.bubbles:SetHorizTile(true) end
    line.bubbles:SetAllPoints(line.fill)
    line.gloss = line:CreateTexture(nil, "OVERLAY", nil, 1)
    line.gloss:SetColorTexture(1, 1, 1, 0.18)
    line.gloss:SetPoint("TOPLEFT", line, "TOPLEFT", 0, -1)
    line.gloss:SetPoint("TOPRIGHT", line, "TOPRIGHT", 0, -1)
    line.gloss:SetHeight(1)
    line.rims = {}
    for i, edge in ipairs({ "TOP", "BOTTOM" }) do
        local r = line:CreateTexture(nil, "OVERLAY")
        r:SetColorTexture(unpack(CFG.PHIAL_RIM))
        r:SetPoint(edge .. "LEFT", line, edge .. "LEFT", 0, 0)
        r:SetPoint(edge .. "RIGHT", line, edge .. "RIGHT", 0, 0)
        r:SetHeight(1)
        line.rims[i] = r
    end
    line.caps = {}
    for i, side in ipairs({ "LEFT", "RIGHT" }) do
        local c = line:CreateTexture(nil, "OVERLAY", nil, 2)
        c:SetTexture(CFG.MEDIA .. "PhialCap.tga")
        if side == "RIGHT" then c:SetTexCoord(1, 0, 0, 1) end
        c:SetPoint(side == "LEFT" and "RIGHT" or "LEFT", line, side, 0, 0)
        line.caps[i] = c
    end
    return line
end

local function ShowPhial(line, design, shown)
    for _, t in ipairs(line.rims) do t:SetShown(shown) end
    for _, t in ipairs(line.caps) do
        t:SetSize(CFG.PHIAL_CAP_W, design.track + 2 * CFG.PHIAL_CAP_OVER)
        t:SetShown(shown)
    end
    line.gloss:SetShown(shown)
end

local function SetPart(tex, line, from, share)
    share = math.max(0, math.min(1 - from, share or 0))
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", line, "TOPLEFT", from * line.width, 0)
    tex:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", from * line.width, 0)
    tex:SetWidth(math.max(0.01, share * line.width))
    tex:SetShown(share > 0)
end

-- share: filled part (0..1), rested: the rested part after it.
local function PaintLine(line, design, colour, share, rested, segments)
    line:SetHeight(design.track)
    if design.phial then
        line.track:SetColorTexture(CFG.PHIAL_GLASS[1], CFG.PHIAL_GLASS[2], CFG.PHIAL_GLASS[3], 1)
        line.fill:SetTexture(CFG.MEDIA .. "FillShade.tga")
        line.fill:SetVertexColor(colour[1], colour[2], colour[3], 1)
    else
        line.track:SetColorTexture(1, 1, 1, CFG.TRACK[1])
        line.fill:SetColorTexture(colour[1], colour[2], colour[3], 1)
        line.fill:SetVertexColor(1, 1, 1, 1)
    end
    SetPart(line.fill, line, 0, share)
    line.bubbles:SetShown(design.phial and share > 0 or false)
    ShowPhial(line, design, design.phial or false)
    line.rest:SetColorTexture(colour[1], colour[2], colour[3], CFG.REST_ALPHA)
    SetPart(line.rest, line, share, rested or 0)
    -- The glow: the fill, wider and faint, around it.
    line.glow:SetColorTexture(colour[1], colour[2], colour[3], 0.3)
    line.glow:ClearAllPoints()
    line.glow:SetPoint("TOPLEFT", line.fill, "TOPLEFT", -1, 2)
    line.glow:SetPoint("BOTTOMRIGHT", line.fill, "BOTTOMRIGHT", 1, -2)
    line.glow:SetShown(design.glow and share > 0 or false)
    for i = 1, math.max(#line.dividers, (segments or 1) - 1) do
        local d = line.dividers[i]
        if not d then
            d = line:CreateTexture(nil, "OVERLAY")
            d:SetColorTexture(unpack(CFG.SEGMENT_GAP))
            d:SetWidth(1)
            line.dividers[i] = d
        end
        if segments and i < segments then
            d:ClearAllPoints()
            d:SetPoint("TOP", line, "TOPLEFT", line.width * i / segments, 0)
            d:SetPoint("BOTTOM", line, "BOTTOMLEFT", line.width * i / segments, 0)
            d:Show()
        else
            d:Hide()
        end
    end
end

local function ShowXpTooltip(self)
    ns.Xp.ShowTooltip(self)
end

local function ShowProfTooltip(self)
    local d = self.data
    if not d then return end
    GameTooltip:SetOwner(self, frame.atTop and "ANCHOR_BOTTOMLEFT" or "ANCHOR_TOPLEFT")
    GameTooltip:AddLine(ns.Data.ProfessionLabel(d), 1, 1, 1)
    GameTooltip:AddDoubleLine(L.TIP_RANK, ("%d / %d"):format(d.rank, d.maxRank), 0.8, 0.8, 0.8, 1, 1, 1)
    local remaining = math.max(0, d.maxRank - d.rank)
    GameTooltip:AddDoubleLine(L.TIP_TO_CAP, tostring(remaining), 0.8, 0.8, 0.8, 1, 1, 1)
    if self.spellOffset then GameTooltip:AddLine(L.TIP_CLICK_OPEN, 0.4, 0.8, 1) end
    GameTooltip:Show()
end

local function HideTooltip(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

local function ShowRepTooltip(self)
    local d = self.data
    if not d then return end
    GameTooltip:SetOwner(self, frame.atTop and "ANCHOR_BOTTOMLEFT" or "ANCHOR_TOPLEFT")
    GameTooltip:AddLine(d.name, 1, 1, 1)
    GameTooltip:AddDoubleLine(d.standingText or "", ("%d / %d"):format(d.rank, d.maxRank), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddLine(L.TIP_REP_LEFT, 0.4, 0.8, 1)
    GameTooltip:AddLine(L.TIP_REP_RIGHT, 0.4, 0.8, 1)
    GameTooltip:Show()
end

-- shortcut: opens only through the spellbook route (Forever 1.60 has it);
-- a /cast fallback (older clients) needs a secure button, which
-- would lock the bar in combat. Upgrade if a client without it matters.
local function OpenProf(self)
    if self.spellOffset then ns.Data.OpenProfession(self.skillLine, self.spellOffset) end
end

-- As the reputation bars: left picks the faction, right opens the tab.
local function ClickRep(self, button)
    if button == "RightButton" then
        if ToggleCharacter then ToggleCharacter("ReputationFrame") end
    else
        ns.OpenFactionMenu(self.index, self)
    end
end

-- One entry of the professions or reputations: icon (professions), name,
-- value and line.
local function BuildEntry(parent, index, onClick, onEnter, key)
    local b = CreateFrame("Button", nil, parent)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", onEnter)
    b:SetScript("OnLeave", HideTooltip)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(CFG.ICON, CFG.ICON)
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.name:SetJustifyH("LEFT")
    Font(b.name, key)
    b.value = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.value:SetJustifyH("RIGHT")
    Font(b.value, key, "value")
    b.key = key
    b.line = NewLine(b, 1)   -- its width: FillEntry, from <part>Width
    b.index = index
    b:Hide()
    return b
end

-- A part's frame; `width` is kept on it for the layout.
local function NewGroup()
    local g = CreateFrame("Frame", nil, frame)
    g:SetSize(1, 1)
    g.width = 0
    return g
end

-- -----------------------------------------------------------------------------
-- Gold, durability, bags: an icon and a value each (as Forever Info Panel
-- reckons them). Plain values in, text out, so the tests need no game.
-- -----------------------------------------------------------------------------
local EQUIPMENT_SLOTS = 18                      -- 1..18; only some have durability
local DURABILITY_LOW, DURABILITY_WARN = 25, 50  -- percent: red, yellow below
local COLOUR_LOW, COLOUR_WARN = { 1, 0.25, 0.2 }, { 1, 0.82, 0 }

function DataBar.GoldText(copper)
    copper = copper or 0
    return ("%dg %ds"):format(math.floor(copper / 10000), math.floor(copper % 10000 / 100))
end

-- The worst equipped item in percent and its slot, nil without any.
function DataBar.WorstDurability()
    if not GetInventoryItemDurability then return nil end
    local worst, worstSlot = nil, nil
    for slot = 1, EQUIPMENT_SLOTS do
        local cur, maximum = GetInventoryItemDurability(slot)
        if cur and maximum and maximum > 0 and (not worst or cur / maximum * 100 < worst) then
            worst, worstSlot = cur / maximum * 100, slot
        end
    end
    return worst, worstSlot
end

-- Free slots in ordinary bags; special bags (soul pouch, quiver: family
-- ~= 0) only take their own things and count apart.
function DataBar.BagSpace()
    local free, total, special = 0, 0, 0
    if not (C_Container and C_Container.GetContainerNumSlots) then return nil end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        local empty, family = C_Container.GetContainerNumFreeSlots(bag)
        if (family or 0) == 0 then
            free, total = free + (empty or 0), total + slots
        else
            special = special + (empty or 0)
        end
    end
    return free, total, special
end

local function TipOwner(self)
    GameTooltip:SetOwner(self, frame.atTop and "ANCHOR_BOTTOMLEFT" or "ANCHOR_TOPLEFT")
end

-- Each: its icon, its value (text, colour or nil: nothing to show), tooltip
-- and click.
DataBar.STATS = {
    GOLD = {
        icon = "StatGold",
        value = function() return GetMoney and DataBar.GoldText(GetMoney()) end,
        tip = function(self)
            local c = GetMoney() or 0
            TipOwner(self)
            GameTooltip:AddLine(L.DATABAR_PART_GOLD, 1, 1, 1)
            GameTooltip:AddLine(("%dg %ds %dc"):format(math.floor(c / 10000), math.floor(c % 10000 / 100), c % 100), 1, 1, 1)
            GameTooltip:Show()
        end,
    },
    DURA = {
        icon = "StatDurability",
        value = function()
            local pct = DataBar.WorstDurability()
            if not pct then return nil end
            local colour = (pct < DURABILITY_LOW and COLOUR_LOW) or (pct < DURABILITY_WARN and COLOUR_WARN) or nil
            return ("%d%%"):format(math.floor(pct + 0.5)), colour
        end,
        tip = function(self)
            local _, slot = DataBar.WorstDurability()
            TipOwner(self)
            GameTooltip:AddLine(L.DATABAR_PART_DURA, 1, 1, 1)
            local link = slot and GetInventoryItemLink and GetInventoryItemLink("player", slot)
            if link then GameTooltip:AddLine(L.DATABAR_TIP_DURA_WORST:format(link), 0.8, 0.8, 0.8) end
            GameTooltip:Show()
        end,
        -- No click: the character window opened from addon code is tainted,
        -- and its health text then fails on Forever's secret values.
    },
    BAGS = {
        icon = "StatBags",
        value = function()
            local free = DataBar.BagSpace()
            return free and tostring(free)
        end,
        tip = function(self)
            local free, total, special = DataBar.BagSpace()
            TipOwner(self)
            GameTooltip:AddLine(L.DATABAR_PART_BAGS, 1, 1, 1)
            if free then GameTooltip:AddLine(L.DATABAR_TIP_BAGS_FREE:format(free, total), 0.8, 0.8, 0.8) end
            if (special or 0) > 0 then GameTooltip:AddLine(L.DATABAR_TIP_BAGS_SPECIAL:format(special), 0.8, 0.8, 0.8) end
            GameTooltip:AddLine(L.DATABAR_TIP_BAGS_CLICK, 0.4, 0.8, 1)
            GameTooltip:Show()
        end,
        -- Looked up at the click: bag addons such as Baganator replace it after we load.
        click = function() if ToggleAllBags then ToggleAllBags() end end,
    },
}

local function BuildStat(id)
    local def = DataBar.STATS[id]
    local g = CreateFrame("Button", nil, frame)
    g.width = 0
    g:SetHeight(CFG.ICON)
    g:RegisterForClicks("LeftButtonUp")
    if def.click then g:SetScript("OnClick", def.click) end
    g:SetScript("OnEnter", def.tip)
    g:SetScript("OnLeave", HideTooltip)
    g.icon = g:CreateTexture(nil, "ARTWORK")
    g.icon:SetSize(CFG.ICON, CFG.ICON)
    g.icon:SetPoint("LEFT", g, "LEFT", 0, 0)
    g.icon:SetTexture(CFG.MEDIA .. def.icon)
    g.text = g:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    g.text:SetPoint("LEFT", g.icon, "RIGHT", CFG.ICON_GAP, 0)
    for _, p in ipairs(DataBar.PARTS) do if p.id == id then g.key = p.key end end
    Font(g.text, g.key, "size")
    g.id = id
    g:Hide()
    return g
end

local function Build()
    if frame then return end
    frame = CreateFrame("Frame", "ForeverDataBarFrame", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:Hide()
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(frame)
    frame.edge = frame:CreateTexture(nil, "BORDER")
    frame.edge:SetHeight(1)
    -- Columns 2 to 5 hang on the width: a new screen size moves them.
    frame:SetScript("OnSizeChanged", function() DataBar.Layout() end)

    -- The XP part: [texts left] [XP text over its line] [texts right]
    -- [Talents], each anchored to the one before it.
    local xp = NewGroup()
    -- Widths from dataBarXpWidth: ApplyFrame.
    local main = CreateFrame("Frame", nil, xp)
    main:EnableMouse(true)
    main:SetScript("OnEnter", ShowXpTooltip)
    main:SetScript("OnLeave", HideTooltip)
    xp.main = main
    xp.text = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    xp.text:SetPoint("TOPLEFT", main, "TOPLEFT", 0, 0)
    xp.text:SetJustifyH("LEFT")
    Font(xp.text, "dataBarXp")
    xp.line = NewLine(main, 1)
    xp.line:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 0, 0)
    frame.xp = xp

    -- Unspent talent points: "Talents" beside the line, pulsing with a
    -- glow behind it, as the level does in the Forever theme.
    local t = CreateFrame("Button", nil, xp)
    t:SetWidth(CFG.TALENT_WIDTH)   -- height: ApplyFrame, from the font
    t:RegisterForClicks("LeftButtonUp")
    t:SetScript("OnClick", function() ns.Xp.ToggleTalents() end)
    t:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, frame.atTop and "ANCHOR_BOTTOMLEFT" or "ANCHOR_TOPLEFT")
        GameTooltip:AddLine(L.TIP_UNSPENT_TALENTS, 1, 1, 1)
        GameTooltip:AddLine(L.TIP_UNSPENT_TALENTS_CLICK, 0.4, 0.8, 1)
        GameTooltip:Show()
    end)
    t:SetScript("OnLeave", HideTooltip)
    t.sun = t:CreateTexture(nil, "BACKGROUND")
    t.sun:SetTexture(ns.Xp.SUN_TEXTURE)
    t.sun:SetBlendMode("ADD")
    t.sun:SetPoint("CENTER", t, "CENTER", 0, 0)
    t.sun:SetSize(CFG.TALENT_WIDTH, CFG.TALENT_WIDTH)
    t.text = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.text:SetPoint("CENTER", t, "CENTER", 0, 0)
    Font(t.text, "dataBarXp", "size")
    t:SetScript("OnUpdate", function(self)
        local wave = (math.sin(GetTime() * ns.Xp.TALENT_PULSE_SPEED) + 1) / 2
        local c = S("dataBarAccent")
        self.text:SetTextColor(ns.Xp.PulseColour(c, wave))
        self.sun:SetVertexColor(c[1], c[2], c[3])
        -- Squared: the shine belongs to the bright end of the pulse.
        self.sun:SetAlpha(wave * wave)
    end)
    t:Hide()
    xp.talents = t

    -- XP per hour and time to the next level, left or right of the XP on
    -- the line of its text; the texts on one side side by side.
    xp.info = {}
    for _, place in ipairs(DataBar.XP_INFO_PLACES) do
        local fs = xp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        Font(fs, "dataBarXp", "value")
        fs:Hide()
        xp.info[place] = fs
    end
    xp.info.LEFT:SetPoint("TOPRIGHT", main, "TOPLEFT", -CFG.PROF_GAP, 0)
    xp.info.LEFT:SetJustifyH("RIGHT")
    xp.info.RIGHT:SetPoint("TOPLEFT", main, "TOPRIGHT", CFG.PROF_GAP, 0)

    local clock = NewGroup()
    clock.width = CFG.CLOCK_WIDTH
    clock:SetWidth(CFG.CLOCK_WIDTH)   -- grows with the font: ApplyFrame
    clock.text = clock:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    clock.text:SetPoint("CENTER", clock, "CENTER", 0, 0)
    Font(clock.text, "dataBarClock", "text", CFG.CLOCK_PLUS)
    frame.clock = clock

    frame.profBox, frame.repBox = NewGroup(), NewGroup()
    frame.profs, frame.reps = {}, {}
    for i = 1, ns.CFG.NUM_SLOTS do frame.profs[i] = BuildEntry(frame.profBox, i, OpenProf, ShowProfTooltip, "dataBarProfs") end
    for i = 1, ns.CFG.NUM_REP_SLOTS do frame.reps[i] = BuildEntry(frame.repBox, i, ClickRep, ShowRepTooltip, "dataBarReps") end
    -- "+": a faction for the first empty reputation slot.
    local add = CreateFrame("Button", nil, frame.repBox)
    add:SetSize(CFG.ICON, CFG.ICON)
    add:RegisterForClicks("LeftButtonUp")
    add:SetScript("OnClick", function(self) ns.OpenFactionMenu(self.slot, self) end)
    add:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, frame.atTop and "ANCHOR_BOTTOMLEFT" or "ANCHOR_TOPLEFT")
        GameTooltip:AddLine(L.DATABAR_ADD_REP, 1, 1, 1)
        GameTooltip:AddLine(L.TIP_REP_LEFT, 0.4, 0.8, 1)
        GameTooltip:Show()
    end)
    add:SetScript("OnLeave", HideTooltip)
    add.text = add:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    add.text:SetPoint("CENTER", add, "CENTER", 0, 0)
    add.text:SetText("+")
    Font(add.text, "dataBarReps", "size", CFG.ADD_PLUS)
    add:Hide()
    frame.addRep = add
    frame.parts = { XP = frame.xp, CLOCK = frame.clock, PROFS = frame.profBox, REPS = frame.repBox }
    for id in pairs(DataBar.STATS) do frame.parts[id] = BuildStat(id) end

    -- The options, fixed at the right edge; the parts on the right line up
    -- left of it.
    local gear = CreateFrame("Button", nil, frame)
    gear:SetSize(CFG.ICON, CFG.ICON)
    gear:SetPoint("RIGHT", frame, "RIGHT", -CFG.PAD, 0)
    gear:RegisterForClicks("LeftButtonUp")
    gear:SetScript("OnClick", function() ns.Window.Toggle() end)
    gear:SetScript("OnEnter", function(self)
        TipOwner(self)
        GameTooltip:AddLine(L.ADDON_NAME, 1, 1, 1)
        GameTooltip:AddLine(L.DATABAR_TIP_OPTIONS, 0.4, 0.8, 1)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", HideTooltip)
    gear.icon = gear:CreateTexture(nil, "ARTWORK")
    gear.icon:SetAllPoints(gear)
    gear.icon:SetTexture(CFG.MEDIA .. "StatOptions")
    frame.gear = gear

    local since = CFG.CLOCK_INTERVAL
    frame:SetScript("OnUpdate", function(_, elapsed)
        since = since + (elapsed or 0)
        if since < CFG.CLOCK_INTERVAL then return end
        since = 0
        if clock:IsShown() then clock.text:SetText(date("%H:%M")) end
        -- The rate and the time to the level run on with the clock.
        if S("dataBarXpPerHour") or S("dataBarXpToLevel") then DataBar.UpdateXp() end
    end)
    DataBar.frame = frame
end

-- -----------------------------------------------------------------------------
-- Layout: the parts at each place
-- -----------------------------------------------------------------------------
-- In the order they line up at one place, with their settings' names.
DataBar.PARTS = {
    { id = "XP", key = "dataBarXp" },
    { id = "GOLD", key = "dataBarGold" },
    { id = "DURA", key = "dataBarDura" },
    { id = "BAGS", key = "dataBarBags" },
    { id = "CLOCK", key = "dataBarClock" },
    { id = "PROFS", key = "dataBarProfs" },
    { id = "REPS", key = "dataBarReps" },
}
-- Five columns: the first starts at the left edge, the last ends at the
-- right one (left of the gear), the three between are centred on 30, 50
-- and 70 % of the width.
DataBar.COLUMNS = { 1, 2, 3, 4, 5 }
DataBar.COLUMN_CENTRE = { [2] = 0.3, [3] = 0.5, [4] = 0.7 }

-- Each column lines its parts up in PARTS order, PROF_GAP apart. A part's
-- X shifts only itself, so it may run into its neighbour on purpose.
function DataBar.Layout()
    if not frame then return end
    local at = { {}, {}, {}, {}, {} }
    for _, p in ipairs(DataBar.PARTS) do
        local g = frame.parts[p.id]
        if g:IsShown() and g.width > 0 then
            local list = at[tonumber(S(p.key .. "Column"))] or at[1]
            list[#list + 1] = { g = g, x = S(p.key .. "X") }
        end
    end
    local width = frame:GetWidth()
    if not width or width <= 0 then width = UIParent:GetWidth() or 0 end
    for column, list in ipairs(at) do
        local total = -CFG.PROF_GAP
        for _, e in ipairs(list) do total = total + e.g.width + CFG.PROF_GAP end
        local cursor
        if column == 1 then
            cursor = CFG.PAD
        elseif column == 5 then
            cursor = width - CFG.PAD - total - (frame.gear:IsShown() and (CFG.ICON + CFG.PROF_GAP) or 0)
        else
            cursor = width * DataBar.COLUMN_CENTRE[column] - total / 2
        end
        for _, e in ipairs(list) do
            e.g:ClearAllPoints()
            e.g:SetPoint("LEFT", frame, "LEFT", cursor + e.x, 0)
            e.g.x = cursor + e.x
            cursor = cursor + e.g.width + CFG.PROF_GAP
        end
    end
    local clock = frame.clock
    if frame:IsShown() and clock:IsShown() and clock.micro then
        ns.Micro.Place(clock.x, frame:GetHeight(), frame.atTop, clock.microLeft, clock.textWidth)
    else
        ns.Micro.Hide()
    end
end

-- -----------------------------------------------------------------------------
-- Look and values
-- -----------------------------------------------------------------------------
local function Accent()
    local c = S("dataBarAccent")
    return { c[1], c[2], c[3] }
end

local function ProfColour(d)
    if d.rank >= d.maxRank then return CFG.CAP_COLOR end
    if S("dataBarProfColours") then return ns.CFG.COLORS[d.key] or ns.CFG.COLORS.UNKNOWN end
    return Accent()
end

local function RepColour(d)
    if S("dataBarProfColours") then return d.colour end
    return Accent()
end

local function ApplyFrame(design)
    local h, alpha = S("dataBarHeight"), S("dataBarAlpha") / 100
    local atTop = S("dataBarPos") ~= "BOTTOM"
    frame.atTop = atTop
    frame:ClearAllPoints()
    local edge = atTop and "TOP" or "BOTTOM"
    frame:SetPoint(edge .. "LEFT", UIParent, edge .. "LEFT", 0, 0)
    frame:SetPoint(edge .. "RIGHT", UIParent, edge .. "RIGHT", 0, 0)
    frame:SetHeight(h)

    local bg = S("dataBarBgColor")
    frame.bg:SetColorTexture(1, 1, 1, 1)
    if design.fade and frame.bg.SetGradient and CreateColor then
        -- Solid at the screen edge, gone towards the game. VERTICAL runs
        -- from the bottom colour to the top one.
        local solid, clear = CreateColor(bg[1], bg[2], bg[3], alpha), CreateColor(bg[1], bg[2], bg[3], 0)
        if atTop then frame.bg:SetGradient("VERTICAL", clear, solid)
        else frame.bg:SetGradient("VERTICAL", solid, clear) end
    else
        frame.bg:SetColorTexture(bg[1], bg[2], bg[3], alpha)
        frame.bg:SetVertexColor(1, 1, 1, 1)
    end

    -- The edge towards the game.
    local inner = atTop and "BOTTOM" or "TOP"
    frame.edge:ClearAllPoints()
    frame.edge:SetPoint(inner .. "LEFT", frame, inner .. "LEFT", 0, 0)
    frame.edge:SetPoint(inner .. "RIGHT", frame, inner .. "RIGHT", 0, 0)
    local c = Accent()
    frame.edge:SetColorTexture(c[1], c[2], c[3], CFG.EDGE_ALPHA)
    frame.edge:SetShown(S("dataBarEdge"))

    ApplyFonts()
    local xpWidth = S("dataBarXpWidth")
    frame.xp.main:SetWidth(xpWidth)
    frame.xp.line:SetWidth(xpWidth)
    frame.xp.line.width = xpWidth
    local xpHeight = TextHeight("dataBarXp") + CFG.TEXT_GAP + design.track
    frame.xp:SetHeight(xpHeight)
    frame.xp.main:SetHeight(xpHeight)
    frame.xp.talents:SetHeight(TextHeight("dataBarXp") + 4)
    frame.gear:SetShown(S("dataBarGear"))
    frame.gear.icon:SetVertexColor(c[1], c[2], c[3], 1)
    -- The clock with the micro menu around it: [icons] 12:34 [icons].
    -- The icons are secure and sit elsewhere (Micro.lua); here only the room.
    local clock, clockOn = frame.clock, S("dataBarClock")
    clock.text:SetText(date("%H:%M"))
    clock.text:SetShown(clockOn)
    clock.textWidth = clockOn and math.max(CFG.CLOCK_WIDTH, math.ceil(clock.text:GetStringWidth() or 0) + 4) or 0
    local left, right = ns.Micro.Count()
    local step = CFG.ICON + CFG.ICON_GAP
    clock.microLeft, clock.micro = left * step, left + right > 0
    clock.width = clock.microLeft + clock.textWidth + right * step
    clock:SetSize(math.max(1, clock.width), TextHeight("dataBarClock") + CFG.CLOCK_PLUS)
    clock.text:ClearAllPoints()
    clock.text:SetPoint("CENTER", clock, "LEFT", clock.microLeft + clock.textWidth / 2, 0)
    clock:SetShown(clockOn or clock.micro)
end

-- Where XP per hour and the time to the level can sit on the XP part.
DataBar.XP_INFO_PLACES = { "LEFT", "RIGHT" }
DataBar.XP_INFOS = { { id = "PerHour", key = "dataBarXpPerHour" }, { id = "ToLevel", key = "dataBarXpToLevel" } }
local INFO_JOIN = "   "

-- The two texts, short for the bar ("--" while the session has no XP yet).
function DataBar.XpInfoText(id, rate, left)
    local none = L.XPINFO_NONE
    if id == "PerHour" then
        local big = BreakUpLargeNumbers or tostring
        return L.DATABAR_PERHOUR:format(rate and big(math.floor(rate)) or none)
    end
    return L.DATABAR_TOLEVEL:format(rate and ns.Xp.Duration(left / rate * 3600) or none)
end

-- place -> text, the shown lines joined.
local function XpInfoByPlace(cur, max)
    local rate, by = ns.Xp.Rate(), {}
    for _, info in ipairs(DataBar.XP_INFOS) do
        if S(info.key) then
            local place = S(info.key .. "Place") == "LEFT" and "LEFT" or "RIGHT"
            local text = DataBar.XpInfoText(info.id, rate, max - cur)
            by[place] = by[place] and (by[place] .. INFO_JOIN .. text) or text
        end
    end
    return by
end

-- The XP part: the line while there is experience to show, its extra
-- texts, "Talents" beside it while points are unspent (at the top level
-- too).
function DataBar.UpdateXp()
    if not frame then return end
    local xp, design = frame.xp, DataBar.Design()
    local active = ns.Xp.Active()
    local talents = ns.Xp.HasUnspentTalents()
    local shown = S("dataBarXp") and (active or talents) or false
    local before = xp.width
    xp:SetShown(shown)
    xp.main:SetShown(active)
    local infos = {}
    if active then
        local cur, max = UnitXP("player") or 0, UnitXPMax("player") or 1
        local rested = (GetXPExhaustion and GetXPExhaustion()) or 0
        xp.text:SetText(DataBar.XpText(UnitLevel("player"), cur, max))
        PaintLine(xp.line, design, Accent(), cur / max, rested / max, design.segments and design.segments[1])
        infos = XpInfoByPlace(cur, max)
    end
    for place, fs in pairs(xp.info) do
        fs:SetText(infos[place] or "")
        fs:SetShown(infos[place] ~= nil)
    end
    local function textWidth(place)
        return infos[place] and (math.ceil(xp.info[place]:GetStringWidth() or 0) + CFG.PROF_GAP) or 0
    end
    -- The texts on the left push the XP to the right.
    local left = textWidth("LEFT")
    xp.main:ClearAllPoints()
    xp.main:SetPoint("LEFT", xp, "LEFT", left, 0)
    local width = active and (left + S("dataBarXpWidth") + textWidth("RIGHT")) or 0
    xp.talents:SetShown(talents)
    xp.talents.text:SetText(L.DATABAR_TALENTS)
    xp.talents:ClearAllPoints()
    if not active then
        xp.talents:SetPoint("LEFT", xp, "LEFT", 0, 0)
    elseif infos.RIGHT then
        xp.talents:SetPoint("LEFT", xp.info.RIGHT, "RIGHT", CFG.PROF_GAP, 0)
    else
        xp.talents:SetPoint("LEFT", xp.main, "RIGHT", CFG.PROF_GAP, 0)
    end
    if talents then width = width + (width > 0 and CFG.PROF_GAP or 0) + CFG.TALENT_WIDTH end
    xp.width = width
    xp:SetWidth(math.max(1, xp.width))
    if before ~= xp.width or not shown then DataBar.Layout() end
end

-- One entry at x in its part: icon (professions), name, value, line.
-- Returns its width. Icons only: the icon over its line, no texts.
local function FillEntry(b, design, x, colour, name, value, share, icon)
    b.icon:ClearAllPoints()
    b.line:ClearAllPoints()
    b.name:ClearAllPoints()
    b.value:ClearAllPoints()
    b.icon:SetShown(icon ~= nil)
    if icon then
        b.icon:SetTexture(icon)
        b.icon:SetVertexColor(colour[1], colour[2], colour[3], 1)
    end
    local lineWidth, width
    if design.iconsOnly and icon then
        lineWidth = CFG.ICON + 4
        width = lineWidth
        b:SetSize(width, CFG.ICON + CFG.TEXT_GAP + design.track)
        b.icon:SetPoint("TOP", b, "TOP", 0, 0)
        b.name:Hide()
        b.value:Hide()
    else
        lineWidth = S(b.key .. "Width")
        local left = icon and (CFG.ICON + CFG.ICON_GAP) or 0
        width = left + lineWidth
        b:SetSize(width, TextHeight(b.key) + CFG.TEXT_GAP + design.track)
        if icon then b.icon:SetPoint("LEFT", b, "LEFT", 0, 0) end
        b.value:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
        b.name:SetPoint("TOPLEFT", b, "TOPLEFT", left, 0)
        b.name:SetPoint("RIGHT", b.value, "LEFT", -4, 0)
        b.name:SetText(name)
        b.value:SetText(value)
        b.name:Show()
        b.value:Show()
    end
    b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    b.line:SetWidth(lineWidth)
    b.line.width = lineWidth
    PaintLine(b.line, design, colour, share, 0, design.segments and design.segments[2])
    b:ClearAllPoints()
    b:SetPoint("LEFT", b:GetParent(), "LEFT", x, 0)
    b:Show()
    return width
end

-- Fills a part's entries left to right from `datas` (nil: empty slot,
-- no gap) and sizes the part.
-- tail: a button after the entries while a slot is empty (the "+").
local function FillPart(box, entries, datas, shown, fill, tail)
    local design, x, empty = DataBar.Design(), 0, nil
    for i, b in ipairs(entries) do
        local d = shown and datas[i] or nil
        b.data = d
        if d then
            x = x + fill(b, d, design, x) + CFG.PROF_GAP
        else
            b:Hide()
            empty = empty or i
        end
    end
    if tail then
        tail.slot = shown and empty or nil
        tail:SetShown(tail.slot ~= nil)
        if tail.slot then
            tail:ClearAllPoints()
            tail:SetPoint("LEFT", box, "LEFT", x, 0)
            x = x + tail:GetWidth() + CFG.PROF_GAP
        end
    end
    box.width = math.max(0, x - CFG.PROF_GAP)
    box:SetSize(math.max(1, box.width), CFG.ICON + CFG.TEXT_GAP + design.track)
    box:SetShown(box.width > 0)
    DataBar.Layout()
end

local function FillProf(b, d, design, x)
    b.skillLine, b.spellOffset = ns.Data.ProfessionInfo(d.name)
    local file = DataBar.ICONS[d.key]
    return FillEntry(b, design, x, ProfColour(d), ns.Data.ProfessionLabel(d), tostring(d.rank),
        d.rank / math.max(1, d.maxRank), file and (CFG.MEDIA .. file) or (d.prof and d.prof.icon))
end

-- The standing, short ("F" for Friendly): the faction's name gets the
-- room. The tooltip keeps the full word.
function DataBar.ShortStanding(d)
    local standing = tonumber(d.standing)
    -- Only Hated (1) .. Exalted (8) have a short word; ns.L answers an
    -- unknown key with the key itself.
    if standing and standing >= 1 and standing <= 8 then return L["DATABAR_STANDING_" .. standing] end
    return d.standingText or ""
end

local function FillRep(b, d, design, x)
    return FillEntry(b, design, x, RepColour(d), d.name, DataBar.ShortStanding(d), d.rank / math.max(1, d.maxRank))
end

function DataBar.UpdateProfessions()
    if not frame then return end
    local datas = {}
    local shown = ns.Data.Professions()
    for i = 1, ns.CFG.NUM_SLOTS do datas[i] = shown[i] end
    FillPart(frame.profBox, frame.profs, datas, S("dataBarProfs"), FillProf)
end

function DataBar.UpdateReps()
    if not frame then return end
    local datas = {}
    for i = 1, ns.CFG.NUM_REP_SLOTS do datas[i] = ns.Data.RepData(i) end
    local c = Accent()
    frame.addRep.text:SetTextColor(c[1], c[2], c[3])
    FillPart(frame.repBox, frame.reps, datas, S("dataBarReps"), FillRep, frame.addRep)
end

-- Gold, durability, bags: value, colour and width; a new width moves the
-- parts beside it.
function DataBar.UpdateStats()
    if not frame then return end
    local accent, moved = Accent(), false
    for _, p in ipairs(DataBar.PARTS) do
        local def, g = DataBar.STATS[p.id], frame.parts[p.id]
        if def then
            local text, colour
            if S(p.key) then text, colour = def.value() end
            local before = g.width
            if text then
                g.icon:SetVertexColor(accent[1], accent[2], accent[3], 1)
                g.text:SetText(text)
                colour = colour or DataBar.TextColour(p.key)
                g.text:SetTextColor(colour[1], colour[2], colour[3])
                g.width = CFG.ICON + CFG.ICON_GAP + math.ceil(g.text:GetStringWidth() or 0)
                g:SetWidth(g.width)
            else
                g.width = 0
            end
            g:SetShown(text ~= nil)
            moved = moved or before ~= g.width
        end
    end
    if moved then DataBar.Layout() end
end

function DataBar.Update()
    if not frame then return end
    DataBar.UpdateStats()
    DataBar.UpdateXp()
    DataBar.UpdateProfessions()
    DataBar.UpdateReps()
    DataBar.Layout()
end

function DataBar.UpdateVisibility()
    if not frame then return end
    local was = frame:IsShown()
    frame:SetShown(DataBar.Wanted())
    -- Shown again (out of combat, the group left): the icons come back.
    if frame:IsShown() and not was then DataBar.Layout() end
end

function DataBar.Apply()
    Build()
    -- Blizzard's XP bar only while ours is off.
    ns.Xp.BlizzardBars(not S("dataBarXp"))
    ApplyFrame(DataBar.Design())
    DataBar.Update()
    DataBar.UpdateVisibility()
end

local KEYS = { hideInCombat = true, hideInGroup = true }
Settings.OnChange(function(key)
    if not frame then return end
    if key == nil or KEYS[key] or (type(key) == "string" and key:sub(1, 7) == "dataBar") then DataBar.Apply() end
end)

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP",
    "ENABLE_XP_GAIN", "DISABLE_XP_GAIN", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE",
    "TRAIT_CONFIG_UPDATED", "ACTIVE_COMBAT_CONFIG_CHANGED", "PLAYER_REGEN_DISABLED",
    "PLAYER_MONEY", "UPDATE_INVENTORY_DURABILITY", "BAG_UPDATE_DELAYED", "BAG_UPDATE", "PLAYER_REGEN_ENABLED",
    "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        DataBar.Apply()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        inCombat = event == "PLAYER_REGEN_DISABLED"
        DataBar.UpdateVisibility()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        if event == "PLAYER_ENTERING_WORLD" then
            inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false
        end
        DataBar.UpdateVisibility()
        DataBar.UpdateXp()
        DataBar.UpdateStats()
    elseif event == "PLAYER_MONEY" or event == "UPDATE_INVENTORY_DURABILITY" or event:sub(1, 10) == "BAG_UPDATE" then
        DataBar.UpdateStats()
    else
        DataBar.UpdateXp()
    end
end)
