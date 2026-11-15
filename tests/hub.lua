-- Forever Themes, the hub (LibForeverThemes.Hub): the bar's Theme part and
-- the options while the hub sets this addon's theme. Run from run.lua after
-- the themes; leaves no hub behind.
return function(ns, M, check)
    local Lib, Settings, D, W = LibForeverThemes, ns.Settings, ns.DataBar, ns.Window
    local f = D.frame
    local part = f.parts.THEME

    -- Shown on screen: the widget and every frame above it.
    local function visible(w)
        w = w and (w._owner or w)
        while w do
            if not w:IsShown() then return false end
            w = w:GetParent()
        end
        return true
    end
    local function visibleText(want)
        for _, fs in ipairs(M.fontStrings) do
            if fs._text == want and visible(fs) then return fs end
        end
    end
    -- The visible options row labelled `label` with the control `field`.
    local function row(label, field)
        for _, w in ipairs(M.frames) do
            if w[field] and w.label and w.label._text == label and visible(w) then return w end
        end
    end
    local function clickButton(text)
        local fs = visibleText(text)
        local button = fs and fs._owner
        if button then button:GetScript("OnClick")(button) end
        return button ~= nil
    end
    local function tick() f:GetScript("OnUpdate")(f, D.CFG.CLOCK_INTERVAL) end

    -- Another Forever addon in the registry, for the tooltip and "Apply to all".
    _G.ForeverThemes.ForeverOther = { title = "Another Addon", Current = function() return "CLASSIC" end,
        Switch = function() return true end }

    -- Without the hub: no part, its options dimmed with the way to get it.
    Lib.SetHub(nil)
    D.Update()
    check("no hub: the theme part stays away", part:IsShown(), false)
    W.Open("parts")
    check("no hub: 'Requires Forever Themes'", visibleText(ns.L.OPT_HUB_NEEDED) ~= nil, true)
    local show
    for _, w in ipairs(M.frames) do
        if w.box and w.label and w.label._text == ns.L.OPT_DATABAR_SHOW and visible(w) then show = w end
    end
    check("no hub: the theme part's switch dimmed", show and show.box:IsEnabled(), false)
    M.popups = {}
    check("no hub: link button", clickButton(ns.L.OPT_HUB_LINK), true)
    local popup = M.popups[1]
    check("link: Blizzard's text popup", popup and popup.which, "FOREVERDATABAR_HUB_LINK")
    local box = { SetText = function(self, t) self.text = t end, HighlightText = function() end, SetFocus = function() end }
    StaticPopupDialogs.FOREVERDATABAR_HUB_LINK.OnShow({ GetEditBox = function() return box end })
    check("link: the hub's CurseForge page", box.text, "https://www.curseforge.com/wow/addons/forever-themes")
    W.Open("databar")
    check("no hub: theme picker usable", row(ns.L.OPT_THEME_CHOICE, "button").button:IsEnabled(), true)
    check("no hub: no 'Follows'", visibleText(ns.L.OPT_HUB_FOLLOWS), nil)
    check("no hub: 'Apply to all' offered", visibleText(ns.L.OPT_THEME_ALL) ~= nil, true)

    -- The hub, this addon following it.
    local follows, calls = { ForeverOther = false }, {}
    local central = { theme = "PITWALL", color = Lib.Colors("PITWALL")[1] }
    Lib.SetHub({
        Follows = function(folder) return follows[folder] ~= false end,
        Theme = function() return central.theme end,
        Color = function() return central.color end,
        OpenMenu = function(anchor) calls[#calls + 1] = { "menu", anchor } end,
        OpenOptions = function() calls[#calls + 1] = { "options" } end,
    })
    tick()
    local label = ns.L.THEME_PITWALL .. " · " .. ns.L["THEME_COLOR_PITWALL_" .. central.color]
    check("hub: the theme part shows", part:IsShown(), true)
    check("hub: central theme and colour", part.text:GetText(), label)
    check("hub: in column 5 by default", Settings.Get("dataBarThemeColumn"), 5)
    part:GetScript("OnEnter")(part)
    local tip = table.concat(GameTooltip._lines, "\n")
    check("tooltip: the central theme", tip:find(label, 1, true) ~= nil, true)
    check("tooltip: this addon follows", tip:find("Forever Data Bar|" .. ns.L.DATABAR_TIP_THEME_FOLLOWS, 1, true) ~= nil, true)
    check("tooltip: the other keeps its own", tip:find("Another Addon|" .. ns.L.DATABAR_TIP_THEME_OWN, 1, true) ~= nil, true)
    part:GetScript("OnClick")(part, "LeftButton")
    check("left-click: the hub's menu at the part", calls[1] and calls[1][1] == "menu" and calls[1][2] == part, true)
    part:GetScript("OnClick")(part, "RightButton")
    check("right-click: the hub's options", calls[2] and calls[2][1], "options")
    central.theme, central.color = "CLASSIC", nil
    tick()
    check("central theme changed: the label follows", part.text:GetText(), ns.L.THEME_CLASSIC)

    W.Open("databar")
    check("follows: theme picker dimmed", row(ns.L.OPT_THEME_CHOICE, "button").button:IsEnabled(), false)
    check("follows: picker still shows the theme", ns.Themes.Current() ~= nil, true)
    check("follows: 'Follows Forever Themes'", visibleText(ns.L.OPT_HUB_FOLLOWS) ~= nil, true)
    check("follows: no 'Apply to all'", visibleText(ns.L.OPT_THEME_ALL), nil)
    check("follows: 'Open Forever Themes'", clickButton(ns.L.OPT_HUB_OPEN), true)
    check("follows: opens the hub's options", calls[3] and calls[3][1], "options")
    W.Open("parts")
    check("hub: no 'Requires Forever Themes'", visibleText(ns.L.OPT_HUB_NEEDED), nil)

    -- Own theme in the hub: as without it, the part stays.
    follows.ForeverDataBar = false
    W.Open("databar")
    check("own theme: theme picker usable", row(ns.L.OPT_THEME_CHOICE, "button").button:IsEnabled(), true)
    check("own theme: no 'Follows'", visibleText(ns.L.OPT_HUB_FOLLOWS), nil)
    check("own theme: 'Apply to all' offered", visibleText(ns.L.OPT_THEME_ALL) ~= nil, true)
    W.Toggle()

    check("hub's Classic: plain name, not 'your bar'", D.ThemeLabel("CLASSIC"), ns.L.HUB_THEME_CLASSIC)
    Lib.SetHub(nil)
    _G.ForeverThemes.ForeverOther = nil
    tick()
    check("hub gone: the part goes", part:IsShown(), false)
end
