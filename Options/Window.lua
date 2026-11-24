local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings
local S = Settings.Get

-- The options window, built like Forever Unit Frames' (Style.lua and
-- Widgets.lua are the same): a title bar, the pages on the left with the
-- language at the bottom, the chosen page on the right, a footer. Opened
-- from the gear on the bar or /fdb; the page under Interface Options ->
-- AddOns only has a button to open it.
local Window = {}
ns.Window = Window

local Style, Widgets = ns.Style, ns.Widgets

local function num(key, label)
    local range = Settings.RANGES[key]
    return {
        label = label, min = range[1], max = range[2], step = 1, unit = "px",
        get = function() return S(key) end,
        set = function(v) Settings.Set(key, v) end,
    }
end

local function check(key, label)
    return {
        type = "check", label = label,
        get = function() return S(key) end,
        set = function(v) Settings.Set(key, v) end,
    }
end

local function choice(key, label, values, prefix)
    return {
        type = "select", label = label,
        choices = function()
            local list = {}
            for _, v in ipairs(values) do list[#list + 1] = { label = L[prefix .. v], value = v } end
            return list
        end,
        get = function() return S(key) end,
        set = function(v) Settings.Set(key, v) end,
    }
end

-- Allgemein: what shows, how it is arranged, where it sits.

-- Several bars: the count, each bar's edge, and a part's bar (only while there is more than one).
local function severalBars() return ns.DataBar.Count() > 1 end
local function barRows()
    local count = { label = "OPT_DATABAR_COUNT", min = Settings.RANGES.dataBarCount[1],
        max = Settings.RANGES.dataBarCount[2], step = 1,
        get = function() return S("dataBarCount") end, set = function(v) Settings.Set("dataBarCount", v) end }
    local rows = { count }
    for i = 1, Settings.RANGES.dataBarCount[2] do
        local pos = choice(ns.DataBar.PosKey(i), "OPT_DATABAR_POS", { "TOP", "BOTTOM" }, "DATABAR_POS_")
        pos.label = function() return severalBars() and L.OPT_DATABAR_POS_N:format(i) or L.OPT_DATABAR_POS end
        if i > 1 then pos.visible = function() return ns.DataBar.Count() >= i end end
        rows[#rows + 1] = pos
    end
    rows[#rows + 1] = { type = "text", label = "OPT_DATABAR_COUNT_HINT", height = 40, visible = severalBars }
    return rows
end

local function partBarRow(key, enabled)
    return {
        type = "select", label = "OPT_DATABAR_PART_BAR", visible = severalBars, enabled = enabled,
        choices = function()
            local list = {}
            for i = 1, ns.DataBar.Count() do list[i] = { label = L.DATABAR_BAR_N:format(i), value = i } end
            return list
        end,
        -- A bar taken away: the part shows on bar 1 (DataBar.Layout), so does the menu.
        get = function()
            local b = tonumber(S(key .. "Bar")) or 1
            return b <= ns.DataBar.Count() and b or 1
        end,
        set = function(v) Settings.Set(key .. "Bar", v) end,
    }
end

local function colorRow(key, label, noOpacity)
    return {
        type = "color", label = label, noOpacity = noOpacity,
        get = function()
            local c = S(key)
            return { c[1], c[2], c[3], c[4] or 1 }
        end,
        set = function(c)
            Settings.Set(key, noOpacity and { c[1], c[2], c[3] } or { c[1], c[2], c[3], c[4] })
        end,
    }
end

-- Forever's rim: none, flat in a colour, or gold; its width; and the gold
-- marker where the fill ends. Dimmed outside Forever (styleKey: xpStyle or
-- barStyle); the colour counts only for a flat rim.

local function repRows()
    local rows = {
        { type = "header", label = "OPT_REPUTATION" },
        -- Off by default: chosen factions would not show without it.
        check("dataBarReps", "OPT_DATABAR_SHOW"),
        choice("dataBarRepIcons", "OPT_REP_ICONS", ns.DataBar.STANDING_ICON_ORDER, "REP_ICONS_"),
        { type = "text", label = "OPT_REP_HINT" },
    }
    for slot = 1, 4 do
        rows[#rows + 1] = {
            type = "select",
            label = function() return L.OPT_REP_SLOT:format(slot) end,
            -- A function: factions discovered later appear on the next open.
            choices = function()
                local list = { { label = L.REP_EMPTY, value = 0 } }
                for _, f in ipairs(ns.Factions()) do list[#list + 1] = { label = f.name, value = f.id } end
                return list
            end,
            get = function() return Settings.Reps()[slot] or 0 end,
            set = function(v) Settings.SetRep(slot, v) end,
        }
    end
    rows[#rows + 1] = { type = "buttons", buttons = {
        { label = "OPT_REP_RELOAD", width = 200, onClick = function()
            ns.RefreshReputation()
            Window.Refresh()
        end },
    } }
    return rows
end

-- The look of a level badge: font, size, outline, colour, style. keys: the
-- settings it reads (ns.Data.XP_BADGE).

local WIDTH, HEIGHT = 780, 560
local TITLE_H, NAV_W, FOOTER_H = 32, 160, 40
local NAV_ROW_H, NAV_TOP, NAV_BAR_W, NAV_CAPTION_H = 26, 6, 3, 20
local SCROLLBAR_W, WHEEL_STEP = 10, 40
local CONTENT_W = WIDTH - NAV_W - SCROLLBAR_W
local PAGE_TOP, PAGE_BOTTOM, SECTION_GAP, INSET = 4, 16, 8, 16
local TEXT_AREA_H, HINT_ROW_H = 70, 26
local BUTTON_H, BUTTON_W, BUTTON_GAP = 24, 140, 8

-- A label: a locale key or a function (read again on refresh).
local function labelText(label)
    if type(label) == "function" then return label() end
    return L[label]
end

-- Stacks rows top to bottom; a header after other rows gets a gap.
local function newStack(page)
    local stack = { y = PAGE_TOP, rows = {} }
    function stack.add(row, height)
        if row.isSection and #stack.rows > 0 then stack.y = stack.y + SECTION_GAP end
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -stack.y)
        row:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -stack.y)
        row:SetHeight(height or row:GetHeight())
        stack.rows[#stack.rows + 1] = row
        stack.y = stack.y + (height or row:GetHeight())
    end
    return stack
end

-- A muted line of explanation.
local function hintRow(page, opt)
    local row = CreateFrame("Frame", nil, page)
    row.text = Style.Text(row, 11, "muted")
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", INSET, -4)
    row.text:SetPoint("RIGHT", row, "RIGHT", -INSET, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)
    row.text:SetText(labelText(opt.label))
    function row:Refresh() end
    function row:SetEnabled() end
    return row, opt.height or HINT_ROW_H
end

-- Several buttons side by side.
local function buttonsRow(page, opt)
    local row = CreateFrame("Frame", nil, page)
    local x = INSET
    row.buttons = {}
    for _, b in ipairs(opt.buttons) do
        local button = Widgets.Button(row, { text = labelText(b.label), width = b.width or BUTTON_W,
            onClick = b.onClick })
        button:SetPoint("LEFT", row, "LEFT", x, 0)
        x = x + (b.width or BUTTON_W) + BUTTON_GAP
        row.buttons[#row.buttons + 1] = button
    end
    function row:Refresh() end
    function row:SetEnabled(on) for _, button in ipairs(row.buttons) do button:SetEnabled(on) end end
    return row, BUTTON_H + 12
end

-- A text area to copy from or paste into (export / import).
local function editRow(page, opt)
    local row = CreateFrame("Frame", nil, page)
    local area = Widgets.TextArea(row, { width = CONTENT_W - 2 * INSET, height = TEXT_AREA_H })
    area:SetPoint("TOPLEFT", row, "TOPLEFT", INSET, -4)
    -- The buttons use it like an edit box.
    function area:SetFocus() area.edit:SetFocus() end
    function area:HighlightText() area.edit:HighlightText() end
    if opt.ref then opt.ref.box = area end
    function row:Refresh() end
    function row:SetEnabled() end
    return row, TEXT_AREA_H + 12
end

-- The widget for one spec row, and its height (nil: the widget's own).
local function widgetFor(page, opt)
    local kind = opt.type or "slider"
    if kind == "header" then
        local row = Widgets.Header(page, labelText(opt.label))
        row.isSection = true
        return row
    elseif kind == "text" then
        return hintRow(page, opt)
    elseif kind == "buttons" then
        return buttonsRow(page, opt)
    elseif kind == "edit" then
        return editRow(page, opt)
    end
    local o = { label = labelText(opt.label), get = opt.get, set = opt.set,
        placeholder = opt.placeholder and labelText(opt.placeholder) }
    local row
    if kind == "check" then
        row = Widgets.Checkbox(page, o)
    elseif kind == "select" then
        o.items = function()
            local items = {}
            for _, c in ipairs(opt.choices()) do
                items[#items + 1] = { value = c.value, text = c.label, font = c.font }
            end
            return items
        end
        row = Widgets.Dropdown(page, o)
    elseif kind == "color" then
        o.noOpacity = opt.noOpacity
        row = Widgets.Color(page, o)
    else
        o.min, o.max, o.step = opt.min, opt.max, opt.step or 1
        row = Widgets.Slider(page, o)
    end
    -- A row that is only usable under a setting.
    if opt.enabled then
        local refresh = row.Refresh
        function row:Refresh()
            refresh(self)
            row:SetEnabled(opt.enabled())
        end
    end
    -- A label that follows the settings (e.g. "X" for a free level).
    if type(opt.label) == "function" then
        local refresh = row.Refresh
        function row:Refresh()
            row:SetLabel(opt.label())
            refresh(self)
        end
    end
    return row
end

-- A row with `visible` comes and goes: page.relayout stacks the page anew.
local function buildRows(page, spec)
    local built = {}
    for i, opt in ipairs(spec) do
        local row, height = widgetFor(page, opt)
        built[i] = { row = row, height = height, visible = opt.visible }
    end
    page.relayout = function()
        local stack = newStack(page)
        for _, b in ipairs(built) do
            local shown = not b.visible or b.visible()
            b.row:SetShown(shown)
            if shown then
                b.row:ClearAllPoints()
                stack.add(b.row, b.height)
            end
        end
        page.rows, page.height = stack.rows, stack.y + PAGE_BOTTOM
    end
    page.relayout()
end

-- The professions page: one checkbox per known skill, rebuilt on every
-- show, since skills are learned and unlearned.
local function buildSkillPage(page)
    local stack = newStack(page)
    local header = Widgets.Header(page, L.OPT_PROFESSIONS)
    header.isSection = true
    stack.add(header)
    local hint = hintRow(page, { label = "OPT_PROFESSIONS_HINT", height = 40 })
    stack.add(hint, 40)
    local top = stack.y
    local empty = Style.Text(page, 12, "muted")
    empty:SetPoint("TOPLEFT", page, "TOPLEFT", INSET, -top - 6)
    empty:SetText(L.OPT_NO_SKILLS)
    local checks = {}
    page.fixedRows = stack.rows
    page.rebuild = function()
        local skills = ns.Data.KnownSkills()
        for i, line in ipairs(skills) do
            local c = checks[i]
            if not c then
                c = Widgets.Checkbox(page, {
                    label = "",
                    get = function() return not Settings.IsHidden(c.skillName, c.skillKey) end,
                    set = function(v) Settings.SetHidden(c.skillName, not v) end,
                })
                c:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -(top + (i - 1) * Widgets.ROW_H))
                c:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -(top + (i - 1) * Widgets.ROW_H))
                checks[i] = c
            end
            c.skillName, c.skillKey = line.name, line.key
            c:SetLabel(("%s  |cff888888%d/%d|r"):format(ns.Data.ProfessionLabel(line), line.rank, line.maxRank))
            c:Show()
        end
        for i = #skills + 1, #checks do checks[i]:Hide() end
        empty:SetShown(#skills == 0)
        local rows = {}
        for _, r in ipairs(page.fixedRows) do rows[#rows + 1] = r end
        for i = 1, #skills do rows[#rows + 1] = checks[i] end
        page.rows = rows
        page.height = top + math.max(1, #skills) * Widgets.ROW_H + PAGE_BOTTOM
    end
    page.rebuild()
end

-- XP lines: one block per line, all alike (show, place, across, up/down).

-- The theme (beta, Themes.lua): each one has every setting of its own, so
-- it comes first. Names shown in the theme's font.
local function themeRefused(ok, why)
    if not ok and why then ns.Print(L["THEME_REFUSED_" .. why]) end
end

-- While Forever Themes (the hub) sets this addon's theme, the pickers are
-- its: dimmed here, with a way there. Asked anew on every refresh: the
-- player may switch "own theme" in the hub at any time.
local function hubFollowed() return LibForeverThemes.Follows(ADDON) end
local function notHubFollowed() return not hubFollowed() end
local function noHub() return LibForeverThemes.Hub() == nil end
-- The hub's texts are the library's, in the client's language.
local function hubText(key) return function() return LibForeverThemes.Text(key, ns.Locale.Current()) end end
local function showHubLink() LibForeverThemes.ShowHubLink(nil, ns.Locale.Current()) end

local function themeRow()
    return {
        type = "select", label = "OPT_THEME_CHOICE",
        choices = function()
            local list = {}
            -- HD themes are colours of their base (colour menu below).
            for _, id in ipairs(LibForeverThemes.MenuIds(LibForeverThemes.SpecIds(ns.Themes.SPECS))) do
                list[#list + 1] = { label = L["THEME_" .. id], value = id, font = ns.Themes.SPECS[id].font }
            end
            return list
        end,
        get = function() return LibForeverThemes.BaseTheme(ns.Themes.Current()) end,
        -- The base shown already (on its HD theme too): nothing changes, HD stays.
        set = function(v)
            if v == LibForeverThemes.BaseTheme(ns.Themes.Current()) then return end
            themeRefused(ns.Themes.Switch(v))
        end,
        enabled = notHubFollowed,
    }
end

-- The current theme's colours, kept apart from the theme sets; none under
-- Classic.
local function themeColorRow()
    return {
        type = "select", label = "OPT_THEME_COLOR",
        visible = function() return #ns.Themes.Colors() > 0 end,
        choices = function()
            local Lib, list = LibForeverThemes, {}
            for _, e in ipairs(Lib.MenuColors(ns.Themes.SPECS, ns.Themes.Current())) do
                local label = L["THEME_COLOR_" .. e.theme .. "_" .. e.color]
                list[#list + 1] = { label = e.hd and "HD " .. label or label, value = Lib.MenuValue(e.theme, e.color) }
            end
            return list
        end,
        get = function() return LibForeverThemes.MenuValue(ns.Themes.Current(), ns.Themes.Color()) end,
        -- An HD colour switches to the HD theme (same settings), a plain one back.
        set = function(v)
            local theme, color = LibForeverThemes.ParseMenuValue(v)
            local ok, why = ns.Themes.Switch(theme)
            if ok then ok, why = ns.Themes.SetColor(color, theme) end
            themeRefused(ok, why)
        end,
        enabled = notHubFollowed,
    }
end

-- The parts' settings another theme's set has (shown, places, compact ...),
-- taken over into the current one; the look stays.
-- What it replaced comes back with "Undo" in the same list, until the theme
-- changes or /reload.
local themeUndo
-- What "Spread to all themes" replaced, until /reload.
local spreadUndo
local UNDO_THEME, NONE_THEME = "__undo", "__none"
local function themeCopyRow()
    return {
        type = "select", label = "OPT_THEME_COPY", placeholder = "OPT_THEME_COPY_PICK",
        choices = function()
            local list = {}
            if themeUndo and themeUndo.theme == ns.Themes.Current() then
                list[1] = { label = L.OPT_THEME_COPY_UNDO, value = UNDO_THEME }
            end
            for _, id in ipairs(ns.Themes.Stored()) do list[#list + 1] = { label = L["THEME_" .. id], value = id } end
            if #list == 0 then list[1] = { label = L.OPT_THEME_COPY_NONE, value = NONE_THEME } end
            return list
        end,
        get = function() return nil end,
        set = function(id)
            if id == NONE_THEME then return end
            if id == UNDO_THEME then
                local undo = themeUndo
                themeUndo = nil
                if undo then ns.Themes.Restore(undo.saved) end
                return
            end
            local saved, why = ns.Themes.CopyParts(id)
            if not saved then return themeRefused(nil, why) end
            themeUndo = { theme = ns.Themes.Current(), saved = saved }
        end,
    }
end

-- The data bar theme: its look, its place, when it hides.
local function dataBarRows()
    local rows = {
        { type = "header", label = "OPT_THEME" },
        themeRow(),
        themeColorRow(),
        -- Without the hub: the one way to theme every Forever addon at once.
        { type = "text", label = hubText("HUB_MISSING"), visible = noHub },
        { type = "buttons", visible = noHub, buttons = {
            { label = hubText("HUB_LINK"), width = 200, onClick = showHubLink },
        } },
        { type = "text", label = hubText("HUB_FOLLOWS"), visible = hubFollowed },
        { type = "buttons", visible = hubFollowed, buttons = {
            { label = hubText("HUB_OPEN"), width = 200, onClick = function() LibForeverThemes.Hub().OpenOptions() end },
        } },
        { type = "text", label = "OPT_THEME_HINT", height = 66 },
        { type = "buttons", visible = function() return ns.Themes.HasOthers() and not hubFollowed() end, buttons = {
            { label = "OPT_THEME_ALL", width = 240, onClick = function()
                ns.Print(L.MSG_THEME_ALL, ns.Themes.ApplyToAll())
            end },
        } },
        themeCopyRow(),
        { type = "text", label = "OPT_THEME_SPREAD_HINT", height = 40 },
        { type = "buttons", buttons = {
            { label = "OPT_THEME_SPREAD", width = 240, onClick = function()
                local saved, why = ns.Themes.SpreadParts()
                if not saved then return themeRefused(nil, why) end
                spreadUndo = saved
                ns.Print(L.MSG_THEME_SPREAD)
                Window.Refresh()
            end },
        } },
        { type = "buttons", visible = function() return spreadUndo ~= nil end, buttons = {
            { label = "OPT_THEME_SPREAD_UNDO", width = 240, onClick = function()
                if spreadUndo and ns.Themes.RestoreSpread(spreadUndo) then spreadUndo = nil end
                Window.Refresh()
            end },
        } },
        { type = "buttons", buttons = {
            { label = "OPT_THEME_RESET", width = 200, onClick = function()
                themeRefused(ns.Themes.Reset())
                Window.Refresh()
            end },
        } },
        { type = "header", label = "OPT_DATABAR_BAR" },
        choice("dataBarDesign", "OPT_DATABAR_DESIGN", ns.DataBar.DESIGN_ORDER, "DATABAR_DESIGN_"),
    }
    for _, row in ipairs(barRows()) do rows[#rows + 1] = row end
    for _, row in ipairs({
        num("dataBarHeight", "OPT_DATABAR_HEIGHT"),
        { label = "OPT_DATABAR_ALPHA", min = 0, max = 100, step = 5, unit = "%",
          get = function() return S("dataBarAlpha") end, set = function(v) Settings.Set("dataBarAlpha", v) end },
        colorRow("dataBarBgColor", "OPT_DATABAR_BG", true),
        colorRow("dataBarAccent", "OPT_DATABAR_ACCENT", true),
        check("dataBarEdge", "OPT_DATABAR_EDGE"),
        check("dataBarProfColours", "OPT_DATABAR_PROF_COLOURS"),
        check("dataBarOwnIcons", "OPT_DATABAR_OWN_ICONS"),
        check("dataBarGear", "OPT_DATABAR_GEAR"),
        { type = "header", label = "OPT_HIDE" },
        check("hideInCombat", "OPT_DATABAR_HIDE_COMBAT"),
        check("hideInGroup", "OPT_DATABAR_HIDE_GROUP"),
        { type = "header", label = "OPT_RESET" },
        { type = "text", label = "OPT_RESET_HINT", height = 40 },
        { type = "buttons", buttons = {
            { label = "OPT_RESET_BUTTON", width = 200, onClick = function()
                Settings.Reset()
                Window.Refresh()
            end },
        } },
    }) do rows[#rows + 1] = row end
    return rows
end

-- Where each part sits: shown, on which bar, left / middle / right, shifted by X.
local function dataBarPartRows()
    local rows = { { type = "text", label = "OPT_DATABAR_PARTS_HINT", height = 40 } }
    for _, part in ipairs(ns.DataBar.PARTS) do
        rows[#rows + 1] = { type = "header", label = "DATABAR_PART_" .. part.id }
        rows[#rows + 1] = { type = "text", label = "OPT_PART_DESC_" .. part.id, height = 36 }
        -- Column and X only while the part shows.
        local function on() return S(part.key) == true end
        rows[#rows + 1] = check(part.key, "OPT_DATABAR_SHOW")
        local column = choice(part.key .. "Column", "OPT_DATABAR_COLUMN", ns.DataBar.COLUMNS, "DATABAR_COLUMN_")
        local x = num(part.key .. "X", "OPT_DATABAR_X")
        local order = num(part.key .. "Order", "OPT_DATABAR_ORDER")
        column.enabled, x.enabled, order.enabled = on, on, on
        if part.id == "THEME" then
            -- Only Forever Themes has a central theme to show.
            local function hub() return LibForeverThemes.Hub() ~= nil end
            rows[#rows].enabled = hub
            column.enabled = function() return hub() and on() end
            x.enabled, order.enabled = column.enabled, column.enabled
            rows[#rows + 1] = { type = "text", label = "OPT_HUB_NEEDED", visible = noHub }
            rows[#rows + 1] = { type = "buttons", visible = noHub, buttons = {
                { label = hubText("HUB_LINK"), width = 200, onClick = showHubLink },
            } }
        end
        rows[#rows + 1] = partBarRow(part.key, column.enabled)
        rows[#rows + 1] = column
        rows[#rows + 1] = order
        rows[#rows + 1] = x
        if part.id == "THEME" then
            local iconOnly = check("dataBarThemeIconOnly", "OPT_DATABAR_THEME_ICON_ONLY")
            iconOnly.enabled = column.enabled
            rows[#rows + 1] = iconOnly
        end
        if part.id == "REPS" or part.id == "CHAR" or part.id == "CURRENCY" then
            local compact = check(part.key .. "Compact", "OPT_DATABAR_COMPACT")
            compact.enabled = on
            rows[#rows + 1] = compact
        end
        if part.id == "CLOCK" then
            local style = choice("dataBarClockStyle", "OPT_DATABAR_CLOCK_STYLE", ns.Clock.STYLES, "CLOCK_STYLE_")
            local twelve = check("dataBarClock12", "OPT_DATABAR_CLOCK12")
            local own = check("dataBarClockSizeOwn", "OPT_DATABAR_CLOCK_SIZE_OWN")
            local size = num("dataBarClockSize", "OPT_FONT_SIZE")
            style.enabled, twelve.enabled, own.enabled = on, on, on
            size.enabled = function() return on() and S("dataBarClockSizeOwn") == true end
            for _, row in ipairs({ style, twelve, own, size }) do rows[#rows + 1] = row end
            rows[#rows + 1] = check("dataBarMicro", "OPT_DATABAR_MICRO")
            local collections = check("dataBarMicroCollections", "OPT_DATABAR_MICRO_COLLECTIONS")
            collections.enabled = function() return S("dataBarMicro") == true end
            rows[#rows + 1] = collections
        end
        -- The width of the line (each entry's, for professions and reputation).
        if part.id == "XP" or part.id == "PROFS" or part.id == "REPS" then
            local width = num(part.key .. "Width", part.id == "XP" and "OPT_DATABAR_XP_WIDTH" or "OPT_DATABAR_ENTRY_WIDTH")
            width.enabled = on
            rows[#rows + 1] = width
        end
        if part.id == "CHAR" then
            for _, stat in ipairs(ns.CharInfo.STATS) do
                -- Per character, not in the theme sets.
                local show = { type = "check", label = "CHAR_STAT_" .. stat.id:upper(), enabled = on,
                    get = function() return ns.CharInfo.Chosen(stat.id) end,
                    set = function(v) ns.CharInfo.Choose(stat.id, v) end }
                rows[#rows + 1] = show
            end
        end
        if part.id == "CURRENCY" then
            for _, key in ipairs(ns.Currencies.KEYS) do
                local show = check("dataBarCur" .. key, "CURRENCY_" .. key:upper())
                show.enabled = on
                rows[#rows + 1] = show
            end
            local zero = check("dataBarCurZero", "OPT_DATABAR_CUR_ZERO")
            zero.enabled = on
            rows[#rows + 1] = zero
            rows[#rows + 1] = { type = "text", label = "OPT_DATABAR_CURRENCY_HINT" }
        end
        if part.id == "PROFS" then
            local skillUps = check("dataBarSkillUps", "OPT_DATABAR_SKILLUPS")
            skillUps.enabled = on
            rows[#rows + 1] = skillUps
            rows[#rows + 1] = { type = "text", label = "OPT_DATABAR_SKILLUPS_HINT" }
        end
        if part.id == "XP" then
            for _, info in ipairs(ns.DataBar.XP_INFOS) do
                local show = check(info.key, "OPT_XPINFO_" .. info.id:upper())
                show.enabled = on
                rows[#rows + 1] = show
                local place = choice(info.key .. "Place", "OPT_DATABAR_INFO_PLACE", ns.DataBar.XP_INFO_PLACES, "DATABAR_INFO_")
                place.enabled = function() return on() and S(info.key) == true end
                rows[#rows + 1] = place
            end
        end
    end
    return rows
end

-- The data broker feeds (Broker.lua), placed like the parts; the page only
-- while some addon offers one.
local function feedRows()
    local rows = { { type = "text", label = "OPT_FEEDS_HINT", height = 54 } }
    for _, part in ipairs(ns.Broker.Parts()) do
        rows[#rows + 1] = { type = "header", label = function() return ns.Broker.Title(part.name) end }
        local function on() return S(part.key) == true end
        rows[#rows + 1] = check(part.key, "OPT_DATABAR_SHOW")
        local column = choice(part.key .. "Column", "OPT_DATABAR_COLUMN", ns.DataBar.COLUMNS, "DATABAR_COLUMN_")
        local x = num(part.key .. "X", "OPT_DATABAR_X")
        local order = num(part.key .. "Order", "OPT_DATABAR_ORDER")
        column.enabled, x.enabled, order.enabled = on, on, on
        rows[#rows + 1] = partBarRow(part.key, on)
        rows[#rows + 1] = column
        rows[#rows + 1] = order
        rows[#rows + 1] = x
    end
    return rows
end

-- In two groups: the progress bars (professions, reputation, the level

-- A font by name, each shown in itself.
local function fontRow(key, label)
    return {
        type = "select", label = label,
        choices = function()
            local list = {}
            for _, name in ipairs(ns.Media.FontNames()) do list[#list + 1] = { label = name, value = name, font = name } end
            return list
        end,
        -- A font stored under an older name shows under the one listed.
        get = function() return LibForeverThemes.FontName(S(key)) end,
        set = function(v) Settings.Set(key, v) end,
    }
end

local function outlineRow(key)
    return {
        type = "select", label = "OPT_OUTLINE",
        choices = function()
            return {
                { label = L.OUTLINE_NONE, value = "" },
                { label = L.OUTLINE_NORMAL, value = "OUTLINE" },
                { label = L.OUTLINE_THICK, value = "THICKOUTLINE" },
            }
        end,
        get = function() return S(key) end,
        set = function(v) Settings.Set(key, v) end,
    }
end

-- The font of all parts, then each part's own (dimmed while it follows all).
local function fontRows()
    local rows = {
        { type = "header", label = "OPT_FONT_ALL" },
        fontRow("dataBarFont", "OPT_FONT"),
        num("dataBarFontSize", "OPT_FONT_SIZE"),
        outlineRow("dataBarFontOutline"),
        colorRow("dataBarFontColor", "OPT_FONT_COLOR", true),
        { type = "text", label = "OPT_FONT_HINT", height = 40 },
    }
    for _, part in ipairs(ns.DataBar.PARTS) do
        local key = part.key
        local function own() return S(key .. "FontOwn") == true end
        rows[#rows + 1] = { type = "header", label = "DATABAR_PART_" .. part.id }
        rows[#rows + 1] = check(key .. "FontOwn", "OPT_FONT_OWN")
        for _, row in ipairs({ fontRow(key .. "Font", "OPT_FONT"), num(key .. "FontSize", "OPT_FONT_SIZE"),
            colorRow(key .. "FontColor", "OPT_FONT_COLOR", true) }) do
            row.enabled = own
            rows[#rows + 1] = row
        end
    end
    return rows
end

Window.PAGES = {
    { id = "databar", label = "PAGE_DATABAR", rows = dataBarRows },
    { id = "parts", label = "PAGE_DATABAR_PARTS", rows = dataBarPartRows },
    { id = "feeds", label = "PAGE_FEEDS", rows = feedRows, shown = function() return #ns.Broker.Parts() > 0 end },
    { id = "fonts", label = "PAGE_FONTS", rows = fontRows },
    { id = "professions", label = "PAGE_PROFESSIONS", build = buildSkillPage },
    { id = "reputation", label = "PAGE_REPUTATION", rows = repRows },
}

-- --------------------------------------------------------------------------
local frame, current
local pages = {}

local function line(parent, colorKey)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(unpack(Style.COLORS[colorKey]))
    return t
end

local function horizontalLine(parent, anchor)
    local t = line(parent, "border")
    t:SetHeight(1)
    t:SetPoint(anchor .. "LEFT"); t:SetPoint(anchor .. "RIGHT")
    return t
end

local function pageFor(id)
    if pages[id] then return pages[id] end
    local spec
    for _, p in ipairs(Window.PAGES) do if p.id == id then spec = p end end
    if not spec then return nil end
    local page = CreateFrame("Frame", "ForeverDataBarPage" .. id, frame.scrollChild)
    page:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 0, 0)
    page:SetWidth(CONTENT_W)
    if spec.build then spec.build(page) else buildRows(page, spec.rows()) end
    page:SetHeight(page.height)
    page:Hide()
    pages[id] = page
    return page
end

-- Scrolling: a thin accent thumb, as in Forever Unit Frames.
local function updateScrollbar()
    local scroll, thumb = frame.scroll, frame.scrollThumb
    local range, view = scroll:GetVerticalScrollRange() or 0, scroll:GetHeight() or 0
    if range <= 0 or view <= 0 then thumb:Hide(); return end
    local thumbH = view * view / (view + range)
    thumb:SetHeight(thumbH)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", SCROLLBAR_W - 3,
        -(view - thumbH) * (scroll:GetVerticalScroll() or 0) / range)
    thumb:Show()
end

local function onWheel(scroll, delta)
    local v = (scroll:GetVerticalScroll() or 0) - delta * WHEEL_STEP
    scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange() or 0, v)))
    updateScrollbar()
end

-- Besides the wheel the thumb can be dragged, and a click on the track above
-- or below it turns a page (reported: with a broken wheel the lower options
-- were out of reach). The thumb is a button as wide as the track, its bar
-- 2 px at the right edge, 4 px while hovered or dragged.
local function setScroll(v)
    local scroll = frame.scroll
    scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange() or 0, v)))
    updateScrollbar()
end

local function cursorY(region)
    return select(2, GetCursorPosition()) / region:GetEffectiveScale()
end

local function followDrag(thumb)
    local scroll = frame.scroll
    local free = (scroll:GetHeight() or 0) - thumb:GetHeight()
    if free > 0 then
        setScroll(thumb.startScroll + (thumb.startY - cursorY(thumb)) * (scroll:GetVerticalScrollRange() or 0) / free)
    end
end

local function createThumb(body)
    local thumb = CreateFrame("Button", nil, body)
    thumb:SetWidth(SCROLLBAR_W - 3)
    thumb:SetFrameLevel(body:GetFrameLevel() + 5)
    local bar = thumb:CreateTexture(nil, "ARTWORK")
    bar:SetColorTexture(unpack(Style.COLORS.accent))
    bar:SetPoint("TOPRIGHT"); bar:SetPoint("BOTTOMRIGHT")
    bar:SetWidth(2)
    local function wide(on) bar:SetWidth((on or thumb.startY) and 4 or 2) end
    thumb:SetScript("OnEnter", function() wide(true) end)
    thumb:SetScript("OnLeave", function() wide(false) end)
    thumb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self.startY, self.startScroll = cursorY(self), frame.scroll:GetVerticalScroll() or 0
        self:SetScript("OnUpdate", followDrag)
    end)
    thumb:SetScript("OnMouseUp", function(self)
        self.startY = nil
        self:SetScript("OnUpdate", nil)
        wide(self:IsMouseOver())
    end)
    thumb:EnableMouseWheel(true)
    thumb:SetScript("OnMouseWheel", function(_, delta) onWheel(frame.scroll, delta) end)
    thumb:Hide()
    return thumb
end

local function createTrack(body, scroll)
    local track = CreateFrame("Frame", nil, body)
    track:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 0, 0)
    track:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", SCROLLBAR_W, 0)
    track:EnableMouse(true)
    track:EnableMouseWheel(true)
    track:SetScript("OnMouseWheel", function(_, delta) onWheel(scroll, delta) end)
    track:SetScript("OnMouseDown", function(self, button)
        local thumb = frame.scrollThumb
        if button ~= "LeftButton" or not thumb:IsShown() then return end
        local step = (scroll:GetHeight() or 0) - WHEEL_STEP
        setScroll((scroll:GetVerticalScroll() or 0) + (cursorY(self) < thumb:GetBottom() and step or -step))
    end)
end

local function createScroll(body)
    local scroll = CreateFrame("ScrollFrame", "ForeverDataBarOptionsScroll", body)
    scroll:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -SCROLLBAR_W, 0)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", onWheel)
    scroll:SetScript("OnScrollRangeChanged", updateScrollbar)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(CONTENT_W, 1)
    scroll:SetScrollChild(child)
    createTrack(body, scroll)
    local thumb = createThumb(body)
    frame.scroll, frame.scrollChild, frame.scrollThumb = scroll, child, thumb
end

-- Navigation ----------------------------------------------------------------------
local function paintNav()
    for id, b in pairs(frame.navButtons) do
        local selected = id == current
        Style.Paint(b.text, selected and "accent" or "text")
        b.selected = selected
        b.bar:SetShown(selected)
    end
end

local function navButton(nav, page, y)
    local b = CreateFrame("Button", "ForeverDataBarNav" .. page.id, nav)
    b:SetHeight(NAV_ROW_H)
    b:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, -y)
    b:SetPoint("TOPRIGHT", nav, "TOPRIGHT", -1, -y)
    b.hover = Style.Fill(b, "hover", "ARTWORK")
    b.hover:Hide()
    b.bar = line(b, "accent")
    b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetWidth(NAV_BAR_W)
    b.text = Style.Text(b, 12, "text")
    b.text:SetPoint("LEFT", b, "LEFT", INSET, 0)
    b.text:SetText(L[page.label])
    b:SetScript("OnEnter", function(self) self.hover:Show() end)
    b:SetScript("OnLeave", function(self) self.hover:Hide() end)
    b:SetScript("OnClick", function() Window.ShowPage(page.id) end)
    frame.navButtons[page.id] = b
end

-- The language, at the bottom of the navigation: a label above a dropdown
-- as wide as the column; the list opens upwards.
local LANGUAGE_BUTTON_H, LANGUAGE_LABEL_H, LANGUAGE_BOTTOM = 22, 18, 10

local function languageRow(nav)
    local row = Widgets.Dropdown(nav, {
        label = L.OPT_LANGUAGE,
        items = function()
            local list = { { value = "AUTO", text = L.LANGUAGE_AUTO } }
            for _, c in ipairs(ns.Locale.CHOICES) do list[#list + 1] = { value = c.value, text = c.label } end
            return list
        end,
        get = function() return ns.Locale.Setting() end,
        set = function(v) ns.Locale.Set(v) end,
        listAbove = true,
    })
    row:SetHeight(LANGUAGE_LABEL_H + LANGUAGE_BUTTON_H)
    row:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", INSET, LANGUAGE_BOTTOM)
    row:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", -INSET, LANGUAGE_BOTTOM)
    row:EnableMouse(false)
    row.hover:SetAlpha(0)
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    Style.Paint(row.label, "muted")
    row.button:ClearAllPoints()
    row.button:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.button:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.button:SetHeight(LANGUAGE_BUTTON_H)
    row:Refresh()
    frame.languageRow = row
end

local function createNav(parent)
    local nav = CreateFrame("Frame", nil, parent)
    nav:SetWidth(NAV_W)
    Style.Fill(nav, "panel")
    local edge = line(nav, "border")
    edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
    frame.navButtons, frame.navCaptions, frame.nav = {}, {}, nav
    for _, page in ipairs(Window.PAGES) do
        navButton(nav, page, 0)
        if page.group then frame.navButtons[page.id].text:SetPoint("LEFT", frame.navButtons[page.id], "LEFT", INSET + 8, 0) end
        if page.group and not frame.navCaptions[page.group] then
            local caption = Style.Text(nav, 10, "muted")
            caption:SetText(L[page.group]:upper())
            frame.navCaptions[page.group] = caption
        end
    end
    languageRow(nav)
    return nav
end

local function pageShown(page)
    return not page.shown or page.shown()
end

-- The navigation's order: a caption above each group, the pages in it
-- indented; a page not shown (its part off, or `shown` says no) and a group
-- with none leave no gap.
local function layoutNav()
    if not frame or not frame.nav then return end
    local nav, y, group = frame.nav, NAV_TOP, nil
    for _, caption in pairs(frame.navCaptions) do caption:Hide() end
    for _, page in ipairs(Window.PAGES) do
        local b = frame.navButtons[page.id]
        local shown = pageShown(page)
        b:SetShown(shown)
        if shown then
            if page.group ~= group then
                group = page.group
                local caption = group and frame.navCaptions[group]
                if caption then
                    caption:Show()
                    caption:ClearAllPoints()
                    caption:SetPoint("TOPLEFT", nav, "TOPLEFT", INSET, -(y + NAV_CAPTION_H - 14))
                    y = y + NAV_CAPTION_H
                end
            end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, -y)
            b:SetPoint("TOPRIGHT", nav, "TOPRIGHT", -1, -y)
            y = y + NAV_ROW_H
        end
    end
end

local function createFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT")
    Style.Fill(footer, "panel")
    horizontalLine(footer, "TOP")
    return footer
end

-- Title bar with the version and a drawn close cross.
local CROSS_SIZE, CROSS_ANGLE = 14, math.pi / 4

local function closeButton(titleBar)
    local b = CreateFrame("Button", nil, titleBar)
    b:SetSize(TITLE_H, TITLE_H)
    b:SetPoint("RIGHT", titleBar, "RIGHT", 0, 0)
    b.lines = {}
    for i, angle in ipairs({ CROSS_ANGLE, -CROSS_ANGLE }) do
        local t = line(b, "muted")
        t:SetSize(CROSS_SIZE, 2)
        t:SetPoint("CENTER")
        if t.SetRotation then t:SetRotation(angle) end
        b.lines[i] = t
    end
    local function paint(colorKey)
        for _, t in ipairs(b.lines) do t:SetColorTexture(unpack(Style.COLORS[colorKey])) end
    end
    b:SetScript("OnEnter", function() paint("accent") end)
    b:SetScript("OnLeave", function() paint("muted") end)
    b:SetScript("OnClick", function() frame:Hide() end)
    return b
end

local function createTitleBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(TITLE_H)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    Style.Fill(bar, "panel")
    horizontalLine(bar, "BOTTOM")
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local title = Style.Text(bar, 16, "text")
    title:SetPoint("LEFT", bar, "LEFT", INSET, 0)
    title:SetText(L.ADDON_NAME)
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version = Style.Text(bar, 11, "muted")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
    version:SetText("v" .. ((getMetadata and getMetadata(ADDON, "Version")) or ""))
    bar.close = closeButton(bar)
    return bar
end

local WINDOW_NAME = "ForeverDataBarOptions"

local function createWindow()
    frame = CreateFrame("Frame", WINDOW_NAME, UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    Style.Fill(frame, "bg")
    Style.Border(frame)
    frame.titleBar = createTitleBar(frame)
    local footer = createFooter(frame)
    local nav = createNav(frame)
    nav:SetPoint("TOPLEFT", frame.titleBar, "BOTTOMLEFT", 0, 0)
    nav:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 0)
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", frame.titleBar, "BOTTOMLEFT", NAV_W, 0)
    body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
    frame.body = body
    createScroll(body)
    -- Hiding the window (ESC, the cross) takes an open dropdown list along.
    frame:SetScript("OnHide", function() Widgets.CloseList() end)
    frame:SetScript("OnShow", function() Window.Refresh() end)
    frame:Hide()
    if UISpecialFrames then
        local listed = false
        for _, name in ipairs(UISpecialFrames) do if name == WINDOW_NAME then listed = true end end
        if not listed then table.insert(UISpecialFrames, WINDOW_NAME) end
    end
end

local function ensureWindow()
    if not frame then createWindow() end
end

-- Public API ----------------------------------------------------------------------

function Window.ShowPage(id)
    ensureWindow()
    layoutNav()
    -- A page of a part switched off is not offered: General instead.
    for _, p in ipairs(Window.PAGES) do
        if p.id == id and not pageShown(p) then id = "databar" end
    end
    local page = pageFor(id)
    if not page then return end
    Widgets.CloseList()
    for _, p in pairs(pages) do if p ~= page then p:Hide() end end
    current = id
    -- Rows that come and go (the hub may have come or gone) stack anew.
    if page.relayout then
        page.relayout()
        page:SetHeight(page.height)
    end
    if page.rebuild then
        page.rebuild()
        page:SetHeight(page.height)
    end
    frame.scrollChild:SetHeight(page.height)
    frame.scroll:SetVerticalScroll(0)
    page:Show()
    for _, row in ipairs(page.rows or {}) do row:Refresh() end
    paintNav()
    updateScrollbar()
end

-- Fetches every value on the visible page again; a page no longer offered
-- gives way to the one before it.
function Window.Refresh()
    if not frame or not current then return end
    layoutNav()
    local page = pages[current]
    if not page then return end
    if page.relayout then
        page.relayout()
        page:SetHeight(page.height)
        frame.scrollChild:SetHeight(page.height)
        updateScrollbar()
    end
    for _, row in ipairs(page.rows or {}) do row:Refresh() end
    if frame.languageRow then frame.languageRow:Refresh() end
end
ns.RefreshOptions = Window.Refresh

function Window.Open(pageID)
    ensureWindow()
    frame:Show()
    Window.ShowPage(pageID or current or "databar")
end

function Window.Toggle()
    if Window.IsShown() then frame:Hide() else Window.Open() end
end

-- The page on show (the tests).
function Window.Current() return current end

function Window.IsShown()
    return frame ~= nil and frame:IsShown()
end

-- A change from elsewhere (dragging, a slash command, a profile) shows on
-- the page.
Settings.OnChange(function()
    if frame and frame:IsShown() then Window.Refresh() end
end)

-- A feed made later (an addon loaded on demand): its rows were not built.
-- Frames cannot be destroyed, so the old page stays hidden and unreferenced.
ns.Broker.OnChange(function()
    if not frame then return end
    if pages.feeds then
        pages.feeds:Hide()
        pages.feeds = nil
    end
    if frame:IsShown() then Window.ShowPage(current) else layoutNav() end
end)

-- Every label is set when its widget is built: a new language gets a new
-- window. Frames cannot be destroyed, so the old one stays hidden and
-- unreferenced; the new one takes over its global name and page.
ns.Locale.OnChange(function()
    if not frame then return end
    local wasOpen, page = frame:IsShown(), current
    frame:Hide()
    frame, pages = nil, {}
    if wasOpen then Window.Open(page) end
end)
