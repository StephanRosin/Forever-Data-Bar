local ADDON, ns = ...

SLASH_FOREVERDATABAR1 = "/fdb"
SLASH_FOREVERDATABAR2 = "/foreverdatabar"
SlashCmdList["FOREVERDATABAR"] = function() ns.Window.Toggle() end

-- Blizzard's addon compartment (TOC: AddonCompartmentFunc).
function ForeverDataBar_OnAddonCompartmentClick() ns.Window.Toggle() end
