-- LibDataBroker feeds (Broker.lua) on the bar and their options page. A
-- small stand-in for the library: the addon only uses DataObjectIterator,
-- GetDataObjectByName and the two callbacks. Run from run.lua; removes the
-- library and turns the feeds off again.
return function(ns, M, check)
    local B, D, W, Settings = ns.Broker, ns.DataBar, ns.Window, ns.Settings
    local f = D.frame

    check("no library: no feeds", #B.Parts(), 0)
    W.Open("feeds")
    check("no feeds: no Data Broker page", W.Current(), "databar")
    W.Toggle()

    local objects, callbacks = {}, {}
    local lib = {}
    function lib:DataObjectIterator() return pairs(objects) end
    function lib:GetDataObjectByName(name) return objects[name] end
    function lib.RegisterCallback(_, event, fn) callbacks[event] = fn end
    local function newObject(name, obj)
        objects[name] = obj
        if callbacks.LibDataBroker_DataObjectCreated then callbacks.LibDataBroker_DataObjectCreated("x", name, obj) end
    end
    local function set(name, attr, value)
        objects[name][attr] = value
        callbacks.LibDataBroker_AttributeChanged("x", name, attr, value, objects[name])
    end
    _G.LibStub = function(major, silent)
        if major == "LibDataBroker-1.1" then return lib end
        assert(silent, major)
    end

    -- What a feed shows beside its icon.
    check("data source: its text", B.Text("A", { type = "data source", text = "60 fps", icon = "x" }), "60 fps")
    check("data source without text: its label", B.Text("A", { type = "data source", text = "", label = "Lbl" }), "Lbl")
    check("data source without text or label: its name", B.Text("A", { type = "data source" }), "A")
    check("launcher with icon: the icon only", B.Text("A", { type = "launcher", icon = "x", label = "Lbl" }), nil)
    check("launcher without icon: its label", B.Text("A", { type = "launcher", label = "Lbl" }), "Lbl")

    -- One feed before we look, one after (made at PLAYER_LOGIN, as Toban's).
    objects.Zeta = { type = "launcher", icon = "Interface\\Icons\\Zeta", label = "Zeta Launcher" }
    M.Fire("ADDON_LOADED", "SomeAddon")
    check("feed found at the first look", #B.Parts(), 1)
    local clicked
    newObject("Alpha", { type = "data source", text = "60 fps", icon = 1234, iconCoords = { 0.1, 0.9, 0.1, 0.9 },
        OnClick = function(_, button) clicked = button end,
        OnTooltipShow = function(tip) tip:AddLine("Alpha tip") end })
    check("new feed from the callback", #B.Parts(), 2)
    check("feeds by name", B.Parts()[1].name, "Alpha")
    check("title: the label", B.Title("Zeta"), "Zeta Launcher")
    check("title without label: the name", B.Title("Alpha"), "Alpha")

    local alpha, zeta = f.parts["FEED:Alpha"], f.parts["FEED:Zeta"]
    check("feed off by default", alpha:IsShown(), false)
    check("off: no width", alpha.width, 0)
    check("default column", Settings.Get(B.Key("Alpha") .. "Column"), 5)

    Settings.Set(B.Key("Alpha"), true)
    check("shown once chosen", alpha:IsShown(), true)
    check("its text", alpha.text:GetText(), "60 fps")
    check("its icon", alpha.icon._texture, 1234)
    check("its icon cut", alpha.icon._texCoord[2], 0.9)
    check("width: icon, gap, text", alpha.width, D.CFG.ICON + D.CFG.ICON_GAP + 6 * 7)
    check("stored under its name", ForeverDataBarDB[B.Key("Alpha")], true)

    set("Alpha", "text", "144 fps")
    check("text follows the feed", alpha.text:GetText(), "144 fps")
    check("wider text, wider part", alpha.width, D.CFG.ICON + D.CFG.ICON_GAP + 7 * 7)

    alpha:GetScript("OnClick")(alpha, "RightButton")
    check("click goes to the feed", clicked, "RightButton")

    Settings.Set(B.Key("Zeta"), true)
    check("launcher: icon only", zeta.text:IsShown(), false)
    check("launcher width: the icon", zeta.width, D.CFG.ICON)

    -- Placed like a part: column and X.
    Settings.Set(B.Key("Alpha") .. "Column", 1)
    local last = 0   -- the right end of column 1's built-in parts
    for _, p in ipairs(D.PARTS) do
        local g = f.parts[p.id]
        if g:IsShown() and g.width > 0 and Settings.Get(p.key .. "Column") == 1 then last = math.max(last, g.x + g.width) end
    end
    check("column 1, after the built-in parts", alpha.x, last + D.CFG.PROF_GAP)
    Settings.Set(B.Key("Alpha") .. "X", 30)
    check("X shifts it", alpha.x, last + D.CFG.PROF_GAP + 30)
    check("placement is no look (copied between themes)", ns.Themes.IsLook(B.Key("Alpha") .. "X"), false)

    W.Open("feeds")
    check("Data Broker page offered", W.Current(), "feeds")
    W.Toggle()

    -- Done: off, and no library for the tests after.
    for _, name in ipairs({ "Alpha", "Zeta" }) do
        Settings.Set(B.Key(name), false)
        Settings.Set(B.Key(name) .. "Column", 5)
        Settings.Set(B.Key(name) .. "X", 0)
    end
    _G.LibStub = nil
end
