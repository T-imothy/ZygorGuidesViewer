
-- TEST220: finalizer runs after the deferred faction guide loaders.
-- Loaded last from the TOC, after guides and the native pointer.  Cold client
-- starts can expose character APIs slightly later, so readiness is retried.

local function ZygorClassic_FinalExpectedGuide211()
    local guides=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides
    if not guides or table.getn(guides)<1 then return nil,nil end
    local faction=(ZygorClassic_Faction262 and ZygorClassic_Faction262()) or UnitFactionGroup("player") or ""
    local race=UnitRace("player") or ""
    local level=UnitLevel("player") or 0
    if faction=="" or race=="" or level<1 then return nil,nil end

    local prefix="Zygor's "..faction.." Leveling Guides\\"
    local wanted
    if level<13 then wanted=prefix..race.." (1-13)"
    elseif level<20 then wanted=prefix.."Main Guide (13-20)"
    elseif level<25 then wanted=prefix.."Levels (20-25)"
    elseif level<30 then wanted=prefix.."Levels (25-30)"
    elseif level<35 then wanted=prefix.."Levels (30-35)"
    elseif level<40 then wanted=prefix.."Levels (35-40)"
    elseif level<45 then wanted=prefix.."Levels (40-45)"
    elseif level<50 then wanted=prefix.."Levels (45-50)"
    elseif level<55 then wanted=prefix.."Levels (50-55)"
    else wanted=prefix.."Levels (55-60)" end

    local i
    for i=1,table.getn(guides) do
        if tostring(guides[i].title or "")==wanted then return i,wanted end
    end
    return nil,wanted
end

local function ZygorClassic_Finalize58()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return false end

    local total = table.getn(ZygorGuidesViewer.registeredguides)
    if not UnitName("player") or (UnitLevel("player") or 0)<1 then return false end
    local expected,expectedTitle=ZygorClassic_FinalExpectedGuide211()
    -- Faction guide files are registered asynchronously. Waiting for the exact
    -- title is reliable for both the 115-guide Alliance and 111-guide Horde set.
    if not expected then return false end

    local key
    if ZygorClassic_Key49 then
        key = ZygorClassic_Key49()
    else
        key = tostring(GetRealmName and GetRealmName() or "Realm") .. ":" ..
              tostring(UnitName("player") or "Unknown")
    end

    local restored = false

    -- TEST188's engine record is the authoritative per-character state.
    if ZygorClassicDB and ZygorClassicDB.engine172 and ZygorClassicDB.engine172[key] then
        local state=ZygorClassicDB.engine172[key]
        -- TEST300: any valid authoritative saved guide wins.  Requiring it to
        -- equal the level recommendation made a level-13 reload reject a saved
        -- Human 1-13 route and overwrite it with Main Guide 13-20.
        if state.guide and ZygorGuidesViewer.registeredguides[state.guide] then
            ZygorClassicGuideIndex=state.guide
            ZygorClassicStepIndex=state.step or 1
            restored=true
        end
    end

    -- Restore exact persisted guide/step first.
    if not restored and ZygorClassicDB and ZygorClassicDB.smart51 and ZygorClassicDB.smart51[key] then
        local state = ZygorClassicDB.smart51[key]
        if state.guide and ZygorGuidesViewer.registeredguides[state.guide] then
            ZygorClassicGuideIndex = state.guide
            ZygorClassicStepIndex = state.step or 1
            restored = true
        end
    end

    -- Older persistence fallback.
    if not restored and ZygorClassicDB and ZygorClassicDB.characters and
       ZygorClassicDB.characters[key] then
        local state = ZygorClassicDB.characters[key]
        if state.guide and ZygorGuidesViewer.registeredguides[state.guide] then
            ZygorClassicGuideIndex = state.guide
            ZygorClassicStepIndex = state.step or 1
            restored = true
        end
    end

    -- Fresh character or stale cross-character state: select only the exact
    -- guide proven above. Never inherit whatever another character displayed.
    if not restored then
        ZygorClassicGuideIndex=expected
        ZygorClassicStepIndex=1
        restored=true
    end

    if restored then
        ZygorClassicDB = ZygorClassicDB or {}
        ZygorClassicDB.smart49 = ZygorClassicDB.smart49 or {}
        ZygorClassicDB.smart50 = ZygorClassicDB.smart50 or {}
        ZygorClassicDB.smart54 = ZygorClassicDB.smart54 or {}
        ZygorClassicDB.smart49[key] = true
        ZygorClassicDB.smart50[key] = true
        ZygorClassicDB.smart54[key] = true
        ZygorClassicDB.engine172=ZygorClassicDB.engine172 or {}
        -- Do not replace an existing engine record here.  It also owns the
        -- quest evidence used to distinguish completed, abandoned and
        -- numbered-chain quests; replacing it on login caused cold-boot
        -- rewinds even when the displayed guide/step had been restored.
        local engineState=ZygorClassicDB.engine172[key]
        if not engineState or engineState.guide~=ZygorClassicGuideIndex then
            engineState={}
            ZygorClassicDB.engine172[key]=engineState
        end
        engineState.guide=ZygorClassicGuideIndex
        engineState.step=ZygorClassicStepIndex
        ZygorClassicDB.smart51=ZygorClassicDB.smart51 or {}
        ZygorClassicDB.smart51[key]={guide=ZygorClassicGuideIndex,step=ZygorClassicStepIndex}

        if ZygorClassic_ColdRefresh217 then
            ZygorClassic_ColdRefresh217()
        else
            if ZygorClassic_Render then ZygorClassic_Render() end
            if ZygorClassic_UpdateWaypointText then ZygorClassic_UpdateWaypointText() end
            if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
        end

        if DEFAULT_CHAT_FRAME then
            local g = ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00Zygor TEST220 guide ready:|r " ..
                tostring(g and g.title or "?") ..
                " Step " .. tostring(ZygorClassicStepIndex or 1) ..
                " (" .. tostring(total) .. " guides)"
            )
        end
        return true
    end
    return false
end

-- A cold client login can finish its base viewer initialization after the
-- immediate finalizer has already drawn.  Reapply the final renderer a handful
-- of times, then stop.  This is deliberately bounded and does no quest routing.
if not ZygorClassicColdRefresh217Frame then
    ZygorClassicColdRefresh217Frame=CreateFrame("Frame","ZygorClassicColdRefresh217Frame",UIParent)
    ZygorClassicColdRefresh217Frame.elapsed=0
    ZygorClassicColdRefresh217Frame.refreshes=0
    ZygorClassicColdRefresh217Frame.active=true
    ZygorClassicColdRefresh217Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    ZygorClassicColdRefresh217Frame:SetScript("OnEvent",function()
        this.elapsed=0
        this.refreshes=0
        this.active=true
        this:Show()
        -- Re-select the correct per-character guide before redrawing.  This
        -- also covers logout -> different character without a /reload.
        ZygorClassic_Finalize58()
        if ZygorClassic_ColdRefresh217 then ZygorClassic_ColdRefresh217() end
    end)
    ZygorClassicColdRefresh217Frame:SetScript("OnUpdate",function()
        if not this.active then return end
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.50 then return end
        this.elapsed=0
        if ZygorClassic_ColdRefresh217 then ZygorClassic_ColdRefresh217() end
        this.refreshes=(this.refreshes or 0)+1
        if this.refreshes>=8 then
            this.active=nil
            this:Hide()
        end
    end)
end

-- Run once immediately at the actual end of addon file loading.
ZygorClassicFinal58Done=ZygorClassic_Finalize58() and true or false

-- Also run once more on PLAYER_ENTERING_WORLD in case UnitName/realm weren't
-- available during file execution on a cold client start.
if not ZygorClassicFinal58Frame and not ZygorClassicFinal58Done then
    ZygorClassicFinal58Frame = CreateFrame("Frame", "ZygorClassicFinal58Frame", UIParent)
    ZygorClassicFinal58Frame.elapsed=0
    ZygorClassicFinal58Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    ZygorClassicFinal58Frame:SetScript("OnEvent", function()
        if ZygorClassic_Finalize58() then
            ZygorClassicFinal58Done=true
            this:UnregisterEvent("PLAYER_ENTERING_WORLD")
            this:SetScript("OnUpdate",nil)
        end
    end)
    ZygorClassicFinal58Frame:SetScript("OnUpdate",function()
        if ZygorClassicFinal58Done then this:SetScript("OnUpdate",nil) return end
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.25 then return end
        this.elapsed=0
        if ZygorClassic_Finalize58() then
            ZygorClassicFinal58Done=true
            this:UnregisterEvent("PLAYER_ENTERING_WORLD")
            this:SetScript("OnUpdate",nil)
        end
    end)
end
