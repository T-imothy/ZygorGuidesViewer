
-- TEST154 POINTER MODULE LOAD FIX
-- Ensure existing pointer module gets initialization after login.

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if ZGV and ZGV.Pointer then
        if ZGV.Pointer.Show then
            ZGV.Pointer:Show()
        end
        if ZGV.Pointer.Update then
            ZGV.Pointer:Update()
        end
    end
end)
