
-- TEST57: this file is intentionally loaded after every guide file.
-- It restores the current character only after RegisterGuide() has finished.

local function ZygorClassic_PostGuideInit57()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return end
    local total = table.getn(ZygorGuidesViewer.registeredguides)
    if total < 1 then return end

    local key
    if ZygorClassic_Key49 then
        key = ZygorClassic_Key49()
    else
        key = tostring(GetRealmName and GetRealmName() or "Realm") .. ":" ..
              tostring(UnitName("player") or "Unknown")
    end

    local restored = false

    -- Preferred persisted state from TEST51+.
    if ZygorClassicDB and ZygorClassicDB.smart51 and ZygorClassicDB.smart51[key] then
        local state = ZygorClassicDB.smart51[key]
        if state.guide and ZygorGuidesViewer.registeredguides[state.guide] then
            ZygorClassicGuideIndex = state.guide
            ZygorClassicStepIndex = state.step or 1
            restored = true
        end
    end

    -- Older persistence fallback.
    if not restored and ZygorClassicDB and ZygorClassicDB.characters and ZygorClassicDB.characters[key] then
        local state = ZygorClassicDB.characters[key]
        if state.guide and ZygorGuidesViewer.registeredguides[state.guide] then
            ZygorClassicGuideIndex = state.guide
            ZygorClassicStepIndex = state.step or 1
            restored = true
        end
    end

    -- Brand-new character: exact race/faction/level selection.
    if not restored and ZygorClassic_ForceExactGuide51 then
        restored = ZygorClassic_ForceExactGuide51() and true or false
    end

    if restored then
        ZygorClassicDB = ZygorClassicDB or {}
        ZygorClassicDB.smart49 = ZygorClassicDB.smart49 or {}
        ZygorClassicDB.smart50 = ZygorClassicDB.smart50 or {}
        ZygorClassicDB.smart54 = ZygorClassicDB.smart54 or {}
        ZygorClassicDB.smart49[key] = true
        ZygorClassicDB.smart50[key] = true
        ZygorClassicDB.smart54[key] = true

        if ZygorClassic_Render then ZygorClassic_Render() end
        if ZygorClassic_UpdateWaypointText then ZygorClassic_UpdateWaypointText() end
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end

        if DEFAULT_CHAT_FRAME then
            local g = ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00Zygor TEST57 post-guide init:|r " ..
                tostring(g and g.title or "?") ..
                " Step " .. tostring(ZygorClassicStepIndex or 1) ..
                " (" .. tostring(total) .. " guides)"
            )
        end
    end
end

-- Run immediately because this file is loaded after the guide scripts.
ZygorClassic_PostGuideInit57()
