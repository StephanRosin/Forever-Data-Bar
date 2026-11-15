local ADDON, ns = ...

SLASH_FOREVERDATABAR1 = "/fdb"
SLASH_FOREVERDATABAR2 = "/foreverdatabar"
SlashCmdList["FOREVERDATABAR"] = function(msg)
    if msg and msg:lower():match("^%s*maildebug") then
        local db = ns.AccountDB()
        db.mailDebug = not db.mailDebug
        if db.mailDebug then db.mailLog = {} end
        ns.Print("mail debug " .. (db.mailDebug and "on" or "off"))
        return
    end
    ns.Window.Toggle()
end

-- Blizzard's addon compartment (TOC: AddonCompartmentFunc).
function ForeverDataBar_OnAddonCompartmentClick() ns.Window.Toggle() end
