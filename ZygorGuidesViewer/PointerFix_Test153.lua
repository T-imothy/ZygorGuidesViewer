
-- TEST153 POINTER ENABLE FIX
-- Uses existing Pointer/Waypoints modules. No custom arrow frames.

if ZygorPointerFix153 then return end
ZygorPointerFix153 = true

local function ZygorPointerFix153_Init()
    if ZGV and ZGV.Pointer then
        if ZGV.Pointer.Enable then
            ZGV.Pointer:Enable()
        end
    end

    if ZGV and ZGV.Waypoint then
        if ZGV.Waypoint.Update then
            ZGV.Waypoint:Update()
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    ZygorPointerFix153_Init()
end)
