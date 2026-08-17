
-- TEST155 POINTER LOAD ORDER FIX

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if ZygorGuidesViewer and ZygorGuidesViewer.Pointer then
        ZygorGuidesViewer.Pointer:Startup()

        if ZygorGuidesViewer.Pointer.waypoints then
            local wp = ZygorGuidesViewer.Pointer.waypoints[1]
            if wp then
                ZygorGuidesViewer.Pointer:ShowArrow(wp)
            end
        end
    end
end)
