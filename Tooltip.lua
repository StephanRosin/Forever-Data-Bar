local _, ns = ...

--[[---------------------------------------------------------------------------
Tooltip.lua -- the bar's tooltips in the chosen theme (Stephan's wish 23.11.2026).

ns.Tip stands in for GameTooltip in every tooltip of the bar and its windows:
SetOwner picks the tooltip for the theme of the moment and the calls up to
Show go to it. Under a theme with art that is our own frame, dressed as the
gold window (ThemeArt.BuildWindow/StyleWindow, the bar's fonts, the title font
for the first line); under Classic Blizzard's GameTooltip as before, so
nothing changes there for anyone (Forever Themes rule).

The own frame knows what the bar asks of a tooltip: lines and double lines
with |T|t icons, a minimum width, its lines for anchoring (the gold curve),
OnTooltipCleared. Colours: white and greys (r = g = b from 0.75) are the
theme's text colour, the click hints' blue (0.4, 0.8, 1) its accent; red and
green keep. Text widths can be secret values: such a line counts as
SECRET_W wide.
-----------------------------------------------------------------------------]]
local Tooltip = {}
ns.Tooltip = Tooltip

local S = ns.Settings.Get
local PAD, ROW_GAP, COL_GAP = 8, 3, 16
local SECRET_W = 120
local HINT = { 0.4, 0.8, 1 }
local GREY_FROM = 0.75

local own   -- the own frame, made on first use

-- Whether the current theme dresses tooltips (one with art; Classic has none).
function Tooltip.Themed()
    return ns.Themes.Spec(S("theme")).art ~= nil
end

local function Width(fs)
    local w = fs:GetStringWidth()
    if issecretvalue and issecretvalue(w) then return SECRET_W end
    return math.ceil(w or 0)
end

-- The colour a line asks for, in the theme: see the header.
local function InTheme(r, g, b)
    local text = select(4, ns.DataBar.FontFor("dataBar"))
    if r == nil then return text[1], text[2], text[3], 1 end
    if r == g and g == b and r >= GREY_FROM then return text[1], text[2], text[3], r end
    if r == HINT[1] and g == HINT[2] and b == HINT[3] then
        local a = ns.Themes.Accent()
        return a[1], a[2], a[3], 1
    end
    return r, g, b, 1
end

local Own = {}

local function Row(f, i)
    local row = f.rows[i]
    if not row then
        row = { left = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
            right = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") }
        row.left:SetJustifyH("LEFT")
        row.right:SetJustifyH("RIGHT")
        f.rows[i] = row
    end
    return row
end

local function Clear(f)
    for _, row in ipairs(f.rows) do
        row.left:Hide()
        row.right:Hide()
    end
    f.count, f.minWidth = 0, 0
    for _, fn in ipairs(f.cleared) do fn(f) end
end

function Own:SetOwner(owner, anchor)
    Clear(self)
    self.owner, self.anchor = owner, anchor
end

function Own:IsOwned(owner) return self:IsShown() and self.owner == owner end

function Own:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)
    self.count = self.count + 1
    local row = Row(self, self.count)
    row.left:SetText(left or "")
    row.left:SetTextColor(InTheme(lr, lg, lb))
    row.left:Show()
    row.right:SetText(right or "")
    row.right:SetTextColor(InTheme(rr, rg, rb))
    row.right:SetShown(right ~= nil)
end

function Own:AddLine(text, r, g, b)
    self:AddDoubleLine(text, nil, r, g, b)
end

function Own:SetText(text, r, g, b)
    Clear(self)
    self:AddLine(text, r, g, b)
end

function Own:NumLines() return self.count end
function Own:GetLeftLine(i) return self.rows[i] and self.rows[i].left end
function Own:SetMinimumWidth(w) self.minWidth = w or 0 end

function Own:HookScript(name, fn)
    if name == "OnTooltipCleared" then
        self.cleared[#self.cleared + 1] = fn
    else
        self.frameHookScript(self, name, fn)
    end
end

-- Next to its owner, away from the bar's edge; clamped to the screen.
local function Place(f)
    local owner, anchor, gap = f.owner, f.anchor or "ANCHOR_TOPLEFT", ns.ThemeArt.TooltipGap()
    f:ClearAllPoints()
    if anchor == "ANCHOR_RIGHT" then
        f:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", gap, gap)
    elseif anchor:find("BOTTOM", 1, true) then
        local side = anchor == "ANCHOR_BOTTOM" and "" or "LEFT"
        f:SetPoint("TOP" .. side, owner, "BOTTOM" .. side, 0, -gap)
    else
        local side = anchor == "ANCHOR_TOP" and "" or "LEFT"
        f:SetPoint("BOTTOM" .. side, owner, "TOP" .. side, 0, gap)
    end
end

function Own:Show()
    local path, size, outline = ns.DataBar.FontFor("dataBar")
    local title = ns.Themes.TitleFont()
    title = title and ns.Media.FontPath(title) or path
    local width, y = self.minWidth, PAD
    for i = 1, self.count do
        local row = self.rows[i]
        ns.DataBar.SetFont(row.left, i == 1 and title or path, size + (i == 1 and 1 or 0), outline)
        ns.DataBar.SetFont(row.right, path, size, outline)
        local w = Width(row.left) + (row.right:IsShown() and COL_GAP + Width(row.right) or 0)
        width = math.max(width, w)
    end
    for i = 1, self.count do
        local row = self.rows[i]
        local h = size + (i == 1 and 1 or 0) + ROW_GAP
        row.left:ClearAllPoints()
        row.left:SetPoint("TOPLEFT", self, "TOPLEFT", PAD, -y)
        row.right:ClearAllPoints()
        row.right:SetPoint("TOPRIGHT", self, "TOPRIGHT", -PAD, -y)
        y = y + h
    end
    self:SetSize(width + 2 * PAD, y - ROW_GAP + PAD)
    ns.ThemeArt.StyleWindow(self, self.titleBar)
    Place(self)
    self.frameShow(self)
end

local function Build()
    local f = CreateFrame("Frame", "ForeverDataBarTooltip", UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    -- StyleWindow dresses a window with a title bar: here one without height, never shown.
    f.titleBar = CreateFrame("Frame", nil, f)
    f.titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.titleBar:SetSize(1, 0)
    f.titleBar:Hide()
    ns.ThemeArt.BuildWindow(f, f.titleBar)
    f.rows, f.cleared, f.count, f.minWidth = {}, {}, 0, 0
    f.frameShow, f.frameHookScript = f.Show, f.HookScript
    for name, fn in pairs(Own) do f[name] = fn end
    f:SetScript("OnHide", function(self) self.owner = nil end)
    f:Hide()
    return f
end

function Tooltip.Own()
    own = own or Build()
    return own
end

-- The tooltip SetOwner chose; calls up to Show go to it.
local active = GameTooltip

-- ns.Tip: GameTooltip's calls, sent to the tooltip of the theme.
ns.Tip = setmetatable({}, { __index = function(_, method)
    if method == "SetOwner" then
        return function(_, ...)
            active = Tooltip.Themed() and Tooltip.Own() or GameTooltip
            -- The other one may still show for this owner (theme switched meanwhile).
            local other = active == GameTooltip and own or GameTooltip
            if other and other:IsShown() and other:IsOwned(...) then other:Hide() end
            return active:SetOwner(...)
        end
    end
    if method == "IsOwned" then
        return function(_, owner) return GameTooltip:IsOwned(owner) or (own ~= nil and own:IsOwned(owner)) end
    end
    if method == "Hide" then
        return function() active:Hide() end
    end
    if method == "Show" then
        return function()
            if active == GameTooltip then Tooltip.BarFont(GameTooltip) end
            return active:Show()
        end
    end
    return function(_, ...) return active[method](active, ...) end
end })

-- A line's height in our tooltip (the gold curve sits over blank lines).
function Tooltip.LineHeight()
    return select(2, ns.DataBar.FontFor("dataBar")) + ROW_GAP
end

local TIP_LINE_SPACING = 2

-- A blank line's height in tip: ours from the bar's font; Blizzard's too,
-- as Tooltip.BarFont sets its lines in it. Sizes from our own settings,
-- never read back from the tooltip's lines or frames: those can be secret
-- values once another addon has filled the tooltip.
local function BlankHeight(tip)
    if tip ~= GameTooltip then return Tooltip.LineHeight() end
    return select(2, ns.DataBar.FontFor("dataBar")) + TIP_LINE_SPACING
end

-- Classic: Blizzard's tooltip keeps its frame, but the bar's lines take the
-- bar's font and text colour (as the reputation table in it), the first
-- line one size up; red, green and the click hints keep their colour.
-- What each line had comes back when the tooltip is cleared, so no other
-- tooltip changes.
local restyled, hooked = {}, false
local function RestoreFonts()
    for fs, font in pairs(restyled) do
        if font.object then fs:SetFontObject(font.object) else fs:SetFont(font[1], font[2], font[3]) end
        restyled[fs] = nil
    end
end

function Tooltip.BarFont(tip)
    local path, size, outline, text = ns.DataBar.FontFor("dataBar")
    if not hooked then
        hooked = true   -- a flag of our own: nothing written into Blizzard's frame
        tip:HookScript("OnTooltipCleared", RestoreFonts)
    end
    local name = tip:GetName()
    for i = 1, tip:NumLines() do
        for _, side in ipairs({ "Left", "Right" }) do
            local fs = _G[name .. "Text" .. side .. i]
            if fs then
                if not restyled[fs] then
                    local object = fs:GetFontObject()
                    restyled[fs] = object and { object = object } or { fs:GetFont() }
                end
                fs:SetFont(path, size + (i == 1 and 1 or 0), outline)
                -- White and greys in the bar's text colour (AddLine sets the colour anew each time).
                local r, g, b = fs:GetTextColor()
                if not (issecretvalue and issecretvalue(r)) and r == g and g == b and r >= GREY_FROM then
                    fs:SetTextColor(text[1], text[2], text[3], r)
                end
            end
        end
    end
end

-- A frame of our own (f.width, f.height) inside tip, over blank lines: not
-- through GameTooltip_InsertFrame (addon code writing the tooltip's
-- insertedFrames would taint Blizzard's callers).
function Tooltip.Embed(tip, f)
    local first = tip:NumLines() + 1
    for _ = 1, math.ceil(f.height / BlankHeight(tip)) do tip:AddLine(" ") end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", tip:GetLeftLine(first), "TOPLEFT", 0, 0)
    tip:SetMinimumWidth(f.width)
    f:Show()
end

-- Hides whichever tooltip owner has (Blizzard's or ours).
function Tooltip.HideFor(owner)
    if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
    if own and own:IsOwned(owner) then own:Hide() end
end

-- The tooltip ns.Tip writes to now (the gold curve anchors to its lines).
function Tooltip.Active() return active end
