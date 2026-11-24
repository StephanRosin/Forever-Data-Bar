local ADDON, ns = ...
local Settings = ns.Settings

--[[---------------------------------------------------------------------------
Broker.lua -- LibDataBroker feeds: other addons' "data source" (a text) and
"launcher" (an icon and a click) objects, each a part of the bar that shows,
sits in a column and shifts like the built-in ones (DataBar.PARTS). Every
feed is off until chosen on its own options page.

No library of our own: a feed exists only where its addon brought
LibDataBroker-1.1, so the copy already loaded is the one to ask. Found at
every ADDON_LOADED until there, then told of new feeds by its callbacks
(Toban's FPS Profiler, for one, makes its feed at PLAYER_LOGIN).

Drawn by DataBar.lua (UpdateFeeds), offered by Options/Window.lua.
-----------------------------------------------------------------------------]]
local Broker = {}
ns.Broker = Broker

local LIB = "LibDataBroker-1.1"
local KEY_PREFIX = "dataBarFeed:"   -- settings: <key>, <key>Column, <key>X, <key>Order, <key>Bar
local DEFAULT_COLUMN = 5
local X_RANGE = { -2000, 2000 }

local parts, byName, listeners = {}, {}, {}
local lib

function Broker.Lib()
    return lib
end

function Broker.Key(name) return KEY_PREFIX .. name end

-- The feeds as parts ({ id, key, name }), by name: the bar lines them up
-- in this order after the built-in parts of their column.
function Broker.Parts() return parts end

function Broker.Object(name)
    return lib and lib:GetDataObjectByName(name)
end

-- The feed's own name for itself, else the name it registered under.
function Broker.Title(name)
    local obj = Broker.Object(name)
    local label = obj and obj.label
    if type(label) == "string" and label ~= "" then return label end
    return name
end

-- What the bar shows of a feed beside its icon: a data source its text
-- (its label while that is empty), a launcher nothing but its icon, or
-- its label when it has none. nil: the icon only.
function Broker.Text(name, obj)
    local fallback = obj.label or name
    if obj.type ~= "data source" then
        if obj.icon then return nil end
        return tostring(fallback)
    end
    local text = obj.text
    if text == nil or text == "" then text = fallback end
    return tostring(text)
end

-- fn(): the list of feeds changed.
function Broker.OnChange(fn) listeners[#listeners + 1] = fn end

local function changed()
    for _, fn in ipairs(listeners) do fn() end
end

local function add(name)
    if type(name) ~= "string" or byName[name] then return false end
    local part = { id = "FEED:" .. name, key = Broker.Key(name), name = name }
    byName[name] = part
    parts[#parts + 1] = part
    table.sort(parts, function(a, b) return a.name < b.name end)
    local d, r = Settings.DEFAULTS, Settings.RANGES
    d[part.key], d[part.key .. "Column"], d[part.key .. "X"] = false, DEFAULT_COLUMN, 0
    r[part.key .. "X"] = X_RANGE
    d[part.key .. "Order"], r[part.key .. "Order"] = ns.Settings.ORDER_DEFAULT, ns.Settings.ORDER_RANGE
    d[part.key .. "Bar"] = 1
    return true
end

-- A new feed, from the library's callback or the first look.
function Broker.Add(name)
    if not add(name) then return end
    changed()
    ns.DataBar.UpdateFeeds()
end

local function attributeChanged(_, name)
    if byName[name] then ns.DataBar.UpdateFeed(byName[name]) end
end

-- Takes the library once some addon has loaded it: the feeds there so far,
-- then each one to come.
function Broker.Attach()
    if lib or not LibStub then return end
    lib = LibStub(LIB, true)
    if not lib then return end
    local any = false
    for name in lib:DataObjectIterator() do any = add(name) or any end
    lib.RegisterCallback(Broker, "LibDataBroker_DataObjectCreated", function(_, name) Broker.Add(name) end)
    lib.RegisterCallback(Broker, "LibDataBroker_AttributeChanged", attributeChanged)
    if any then
        changed()
        ns.DataBar.UpdateFeeds()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
    Broker.Attach()
    if lib then self:UnregisterAllEvents() end
end)
