-- Zygor Guides Viewer - WoW 1.12.1 / Lua 5.0 compatibility layer
-- This file must remain parseable by the original Vanilla Lua 5.0 runtime.

-- WoW 1.12 does not expose the later _G alias. Publish it explicitly.
_G = getfenv()

-- Some Vanilla/private-server clients return nil from UnitFactionGroup even
-- after PLAYER_ENTERING_WORLD.  Infer the original 1.12 faction from race so
-- faction-gated guide files cannot wait forever with zero registered guides.
function ZygorClassic_Faction262()
    local faction=UnitFactionGroup and UnitFactionGroup("player") or nil
    if faction=="Alliance" or faction=="Horde" then return faction end
    local race,token=nil,nil
    if UnitRace then race,token=UnitRace("player") end
    race=token or race or ""
    if race=="Human" or race=="Dwarf" or race=="NightElf" or
       race=="Night Elf" or race=="Gnome" then return "Alliance" end
    if race=="Orc" or race=="Troll" or race=="Tauren" or
       race=="Scourge" or race=="Undead" then return "Horde" end
    return nil
end

-- LibStub bootstrap for WoW 1.12.1.
-- Loaded here BEFORE embeds.xml so every embedded library can see LibStub.
if not _G then _G = getfenv() end

if not LibStub then
    LibStub = { libs = {}, minors = {} }

    function LibStub:NewLibrary(major, minor)
        local oldminor
        local _, _, num

        assert(type(major) == "string", "Bad argument #2 to NewLibrary (string expected)")

        if type(minor) ~= "number" then
            _, _, num = string.find(tostring(minor), "(%d+)")
            minor = tonumber(num)
        end

        assert(minor, "Minor version must either be a number or contain a number.")

        oldminor = self.minors[major]
        if oldminor and oldminor >= minor then
            return nil
        end

        self.minors[major] = minor
        if not self.libs[major] then
            self.libs[major] = {}
        end

        return self.libs[major], oldminor
    end

    function LibStub:GetLibrary(major, silent)
        if not self.libs[major] and not silent then
            error("Cannot find a library instance of " .. tostring(major) .. ".", 2)
        end
        return self.libs[major], self.minors[major]
    end

    function LibStub:IterateLibraries()
        return pairs(self.libs)
    end

    setmetatable(LibStub, { __call = LibStub.GetLibrary })
end

_G.LibStub = LibStub

-- Common later-era global helpers.
if not strfind then strfind = string.find end
if not strsub then strsub = string.sub end
if not strlen then strlen = string.len end
if not strlower then strlower = string.lower end
if not strupper then strupper = string.upper end
if not format then format = string.format end

-- Lua 5.1 string.match compatibility using Lua 5.0 string.find captures.
if not string.match then
    function string.match(s, pattern, init)
        local r = { string.find(s, pattern, init) }
        if not r[1] then return nil end
        if table.getn(r) > 2 then
            return unpack(r, 3, table.getn(r))
        end
        return string.sub(s, r[1], r[2])
    end
end
if not strmatch then strmatch = string.match end
if not string.gmatch then string.gmatch = string.gfind end



-- Lua 5.1 select() compatibility for the Vanilla Lua 5.0 runtime.
if not select then
    function select(index, ...)
        local n = table.getn(arg)
        if index == "#" then return n end
        index = tonumber(index)
        if not index then error("bad argument #1 to 'select' (number expected)") end
        if index < 0 then index = n + index + 1 end
        if index < 1 then index = 1 end
        return unpack(arg, index, n)
    end
end

-- AceAddon uses this later-client API only as a login-state guard.
if not IsLoggedIn then
    function IsLoggedIn() return true end
end

-- Converted source uses this instead of Lua 5.1's # operator.
function ZGV_len(v)
    if type(v) == "string" then return string.len(v) end
    if type(v) == "table" then return table.getn(v) end
    return 0
end

if not wipe then
    function wipe(t)
        local k
        for k in pairs(t) do t[k] = nil end
        return t
    end
end

if not table.maxn then
    function table.maxn(t)
        local m = 0
        local k
        for k in pairs(t) do
            if type(k) == "number" and k > m then m = k end
        end
        return m
    end
end

if not strtrim then
    function strtrim(s)
        s = s or ""
        s = string.gsub(s, "^%s+", "")
        s = string.gsub(s, "%s+$", "")
        return s
    end
end

if not InCombatLockdown then
    function InCombatLockdown() return false end
end

if not IsInInstance then
    function IsInInstance() return false, "none" end
end

-- Arena battlegrounds and this query API were added after Vanilla 1.12.
-- Pointer.lua checks it while updating the corpse arrow on death/respawn.
if not IsActiveBattlefieldArena then
    function IsActiveBattlefieldArena() return false end
end

ZGV_LibTaxiLocale = ZGV_LibTaxiLocale or {}


-- Vanilla 1.12 has no hooksecurefunc. This lightweight compatibility wrapper
-- preserves the original global function and calls the hook afterward.
if not hooksecurefunc then
    function hooksecurefunc(target, method, hook)
        if type(target) == "string" then
            local name = target
            local original = _G[name]
            local callback = method
            if type(original) ~= "function" or type(callback) ~= "function" then return end
            _G[name] = function(...)
                local results = { original(unpack(arg)) }
                callback(unpack(arg))
                return unpack(results)
            end
        elseif type(target) == "table" and type(method) == "string" and type(hook) == "function" then
            local original = target[method]
            if type(original) ~= "function" then return end
            target[method] = function(self, ...)
                local results = { original(self, unpack(arg)) }
                hook(self, unpack(arg))
                return unpack(results)
            end
        end
    end
end

-- Some later quest UI globals do not exist in Vanilla.
if not QUEST_MONSTERS_KILLED then
    QUEST_MONSTERS_KILLED = "%s slain: %d/%d"
end


-- Additional WoW 1.12 message/API fallbacks used by the old Zygor code.
ERR_QUEST_COMPLETE_S = ERR_QUEST_COMPLETE_S or "%s completed."
ERR_LEARN_RECIPE_S = ERR_LEARN_RECIPE_S or "You have learned how to create a new item: %s."
QUEST_MONSTERS_KILLED = QUEST_MONSTERS_KILLED or "%s slain: %d/%d"


-- Additional Vanilla map/UI compatibility helpers.
if not GetPlayerMapPosition then
    function GetPlayerMapPosition()
        return 0, 0
    end
end

if not WorldMapFrame then
    WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent)
end

if not GetMapInfo then
    function GetMapInfo()
        return nil
    end
end


-- WoW 1.12 explicit Zygor slash commands.
-- The original build's slash-command registration is commented out.
SLASH_ZYGORCLASSIC1 = "/zygor"
SLASH_ZYGORCLASSIC2 = "/zgv"

SlashCmdList["ZYGORCLASSIC"] = function(msg)
    if ZygorGuidesViewer and ZygorGuidesViewer.ToggleFrame then
        ZygorGuidesViewer:ToggleFrame()
    elseif ZygorGuidesViewerFrame then
        if ZygorGuidesViewerFrame:IsShown() then
            ZygorGuidesViewerFrame:Hide()
        else
            ZygorGuidesViewerFrame:Show()
        end
    else
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("Zygor: viewer frame is not available.")
        end
    end
end


-- Bind the XML viewer frame after the Vanilla UI has finished creating globals.
if not ZygorClassicFrameBinder then
    ZygorClassicFrameBinder = CreateFrame("Frame", "ZygorClassicFrameBinder", UIParent)
    ZygorClassicFrameBinder:RegisterEvent("PLAYER_ENTERING_WORLD")
    ZygorClassicFrameBinder:SetScript("OnEvent", function()
        if ZygorGuidesViewer and ZygorGuidesViewerFrame then
            ZygorGuidesViewer.Frame = ZygorGuidesViewerFrame
            -- The original viewer persists a generic `visible` flag and uses it
            -- to reopen this large backport diagnostics workspace on startup.
            -- The compact player guide is the normal UI now, so diagnostics are
            -- deliberately opt-in through its Diag button.
            ZygorGuidesViewerFrame:Hide()
            if ZygorGuidesViewer.db and ZygorGuidesViewer.db.profile then
                ZygorGuidesViewer.db.profile.visible = false
            end
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("Zygor: viewer frame bound.")
            end
        end
    end)
end


-- ---------------------------------------------------------------------------
-- Vanilla-native Zygor viewer frame
-- The later Zygor XML does not successfully create its main frame on 1.12.
-- Create a safe native frame before the core addon initializes.
-- ---------------------------------------------------------------------------
if not ZygorGuidesViewerFrame then
    local master = CreateFrame("Frame", "ZygorGuidesViewerFrameMaster", UIParent)
    master:SetWidth(360)
    master:SetHeight(260)
    master:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    local f = CreateFrame("Frame", "ZygorGuidesViewerFrame", master)
    f:SetWidth(360)
    f:SetHeight(260)
    f:SetPoint("TOPLEFT", master, "TOPLEFT", 0, 0)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0, 0, 0, 0.90)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    local title = f:CreateFontString("ZygorClassicTitle", "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    title:SetText("Zygor Guides Viewer - Classic 1.12")

    local body = f:CreateFontString("ZygorClassicBody", "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -38)
    body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 38)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetText("Zygor Classic backport loaded.\n\nUse /zygor to show or hide this window.")

    local close = CreateFrame("Button", "ZygorClassicCloseButton", f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() ZygorGuidesViewerFrame:Hide() end)

    f:Hide()
end


-- ---------------------------------------------------------------------------
-- TEST30: Vanilla-native guide browser / step viewer
-- ---------------------------------------------------------------------------

local function ZygorClassic_Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Zygor:|r " .. tostring(msg))
    end
end

local function ZygorClassic_GuideCount()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return 0 end
    return table.getn(ZygorGuidesViewer.registeredguides)
end

local function ZygorClassic_EnsureParsed(guide)
    if not guide then return false end
    if guide.classic_steps then return true end
    if not guide.rawdata then return false end

    local parsed, parseerr = ZygorClassic_ParseRawGuide(guide.rawdata)

    if not parsed then
        ZygorClassicLastParseError =
            "Guide data could not be parsed." .. string.char(10) .. string.char(10) ..
            "Guide: " .. tostring(guide.title or "Unknown") .. string.char(10) ..
            "Error: " .. tostring(parseerr or "unknown parser error")
        return false
    end

    guide.classic_steps = parsed.steps
    guide.classic_author = parsed.author
    guide.classic_defaultfor = parsed.defaultfor
    -- Guide bodies are Lua long strings, so their written `\\` separator is
    -- preserved literally; registered guide titles contain one backslash.
    guide.classic_next = parsed.next and string.gsub(parsed.next, "\\\\", "\\") or nil
    guide.classic_startlevel = parsed.startlevel
    -- TEST233: attach stable compiler coordinates to every parsed step.  The
    -- generated Vanilla manifest is keyed by guide title and original step
    -- number, so it does not depend on directive metadata surviving rendering.
    local classicIndex233
    for classicIndex233=1,table.getn(guide.classic_steps) do
        guide.classic_steps[classicIndex233].classic_guide_title=guide.title
        guide.classic_steps[classicIndex233].classic_step_index=classicIndex233
    end
    return true
end

local function ZygorClassic_GoalText(goal)
    if not goal then return "" end

    if goal.GetText then
        local ok, txt = pcall(goal.GetText, goal, false)
        if ok and txt then return tostring(txt) end
    end

    if goal.text then return tostring(goal.text) end
    if goal.title then return tostring(goal.title) end
    if goal.action then return tostring(goal.action) end
    return ""
end

function ZygorClassic_Render()
    if not ZygorClassicBody then return end

    local z = ZygorGuidesViewer
    if not z then
        ZygorClassicBody:SetText("Zygor core is not loaded.")
        return
    end

    local total = ZygorClassic_GuideCount()

    if total == 0 then
        ZygorClassicBody:SetText(
            "No guides registered.\n\n" ..
            "Faction: " .. tostring(ZygorClassic_Faction262() or "Unknown")
        )
        return
    end

    ZygorClassicGuideIndex = ZygorClassicGuideIndex or 1
    if ZygorClassicGuideIndex < 1 then ZygorClassicGuideIndex = total end
    if ZygorClassicGuideIndex > total then ZygorClassicGuideIndex = 1 end

    local guide = z.registeredguides[ZygorClassicGuideIndex]
    if not guide then return end

    local header =
        "Guide " .. tostring(ZygorClassicGuideIndex) .. "/" .. tostring(total) ..
        "\n" .. tostring(guide.title or "Unknown Guide") .. "\n"

    if not ZygorClassic_EnsureParsed(guide) then
        ZygorClassicBody:SetText(header .. "\n" .. (ZygorClassicLastParseError or "Guide data could not be parsed."))
        return
    end

    local steps = guide.classic_steps or {}
    local stepcount = table.getn(steps)

    ZygorClassicStepIndex = ZygorClassicStepIndex or 1
    if ZygorClassicStepIndex < 1 then ZygorClassicStepIndex = 1 end
    if stepcount > 0 and ZygorClassicStepIndex > stepcount then
        ZygorClassicStepIndex = stepcount
    end

    local step = steps[ZygorClassicStepIndex]
    local body =
        header ..
        "Step " .. tostring(ZygorClassicStepIndex) .. "/" .. tostring(stepcount) ..
        "\n--------------------------------\n"

    if step and step.raw then
        local i
        for i = 1, table.getn(step.raw) do
            local txt = step.raw[i]
            if txt and txt ~= "" then
                body = body .. txt .. "\n"
            end
        end
    else
        body = body .. "No step data."
    end

    ZygorClassicBody:SetText(body)

    -- Keep core state synchronized without invoking the incompatible old frame renderer.
    z.CurrentGuide = guide
    z.CurrentGuideName = guide.title
    z.CurrentStepNum = ZygorClassicStepIndex
    z.CurrentStep = nil
end

function ZygorClassic_NextGuide(delta)
    local total = ZygorClassic_GuideCount()
    if total < 1 then return end
    ZygorClassicGuideIndex = (ZygorClassicGuideIndex or 1) + delta
    if ZygorClassicGuideIndex < 1 then ZygorClassicGuideIndex = total end
    if ZygorClassicGuideIndex > total then ZygorClassicGuideIndex = 1 end
    ZygorClassicStepIndex = 1
    ZygorClassic_Render()
    ZygorClassic_UpdateWaypointText()
end

function ZygorClassic_NextStep(delta)
    ZygorClassicStepIndex = (ZygorClassicStepIndex or 1) + delta
    if ZygorClassicStepIndex < 1 then ZygorClassicStepIndex = 1 end
    ZygorClassic_Render()
    ZygorClassic_UpdateWaypointText()
end

-- Add controls to the native frame created earlier in this compatibility file.
if ZygorGuidesViewerFrame and not ZygorClassicPrevGuideButton then
    local f = ZygorGuidesViewerFrame

    -- Give the text area room for navigation buttons.
    if ZygorClassicBody then
        ZygorClassicBody:ClearAllPoints()
        ZygorClassicBody:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -38)
        ZygorClassicBody:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 66)
    end

    local pg = CreateFrame("Button", "ZygorClassicPrevGuideButton", f, "UIPanelButtonTemplate")
    pg:SetWidth(70)
    pg:SetHeight(22)
    pg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 36)
    pg:SetText("< Guide")
    pg:SetScript("OnClick", function() ZygorClassic_NextGuide(-1) end)

    local ng = CreateFrame("Button", "ZygorClassicNextGuideButton", f, "UIPanelButtonTemplate")
    ng:SetWidth(70)
    ng:SetHeight(22)
    ng:SetPoint("LEFT", pg, "RIGHT", 5, 0)
    ng:SetText("Guide >")
    ng:SetScript("OnClick", function() ZygorClassic_NextGuide(1) end)

    local ps = CreateFrame("Button", "ZygorClassicPrevStepButton", f, "UIPanelButtonTemplate")
    ps:SetWidth(70)
    ps:SetHeight(22)
    ps:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    ps:SetText("< Step")
    ps:SetScript("OnClick", function() ZygorClassic_NextStep(-1) end)

    local ns = CreateFrame("Button", "ZygorClassicNextStepButton", f, "UIPanelButtonTemplate")
    ns:SetWidth(70)
    ns:SetHeight(22)
    ns:SetPoint("LEFT", ps, "RIGHT", 5, 0)
    ns:SetText("Step >")
    ns:SetScript("OnClick", function() ZygorClassic_NextStep(1) end)
end

-- Refresh guide data after the character is fully in the world.
if not ZygorClassicGuideLoader then
    ZygorClassicGuideLoader = CreateFrame("Frame", "ZygorClassicGuideLoader", UIParent)
    ZygorClassicGuideLoader:RegisterEvent("PLAYER_ENTERING_WORLD")
    ZygorClassicGuideLoader:SetScript("OnEvent", function()
        ZygorClassicGuideIndex = 1
        ZygorClassicStepIndex = 1
        ZygorClassic_Render()
    end)
end

-- Refresh the native browser every time /zygor is used.
SLASH_ZYGORCLASSIC1 = "/zygor"
SLASH_ZYGORCLASSIC2 = "/zgv"
SlashCmdList["ZYGORCLASSIC"] = function(msg)
    if not ZygorGuidesViewerFrame then
        ZygorClassic_Print("viewer frame is not loaded.")
        return
    end
    if ZygorGuidesViewerFrame:IsShown() then
        ZygorGuidesViewerFrame:Hide()
    else
        ZygorClassic_Render()
        ZygorGuidesViewerFrame:Show()
    end
end


-- ---------------------------------------------------------------------------
-- TEST34: Vanilla-native raw guide parser for the Classic viewer.
-- ---------------------------------------------------------------------------
function ZygorClassic_ParseRawGuide(raw)
    if type(raw) ~= "string" then
        return nil, "raw guide data is not a string"
    end

    local parsed = { steps = {} }
    local current = nil
    local newline = string.char(10)
    local carriage = string.char(13)

    raw = raw .. newline
    local pos = 1
    local total = string.len(raw)

    while pos <= total do
        local s, e = string.find(raw, newline, pos)
        if not s then break end

        local line = string.sub(raw, pos, s - 1)
        pos = e + 1

        line = string.gsub(line or "", carriage, "")
        line = string.gsub(line, "^%s+", "")
        line = string.gsub(line, "%s+$", "")

        if line ~= "" then
            -- Direct detection: actual files contain "step //1", "step //2", etc.
            if string.sub(line, 1, 4) == "step" and
               (string.len(line) == 4 or string.sub(line, 5, 5) == " " or string.sub(line, 5, 5) == string.char(9)) then

                current = { raw = {} }
                table.insert(parsed.steps, current)

            elseif current == nil then
                if string.sub(line, 1, 7) == "author " then
                    parsed.author = string.sub(line, 8)
                elseif string.sub(line, 1, 11) == "defaultfor " then
                    parsed.defaultfor = string.sub(line, 12)
                elseif string.sub(line, 1, 5) == "next " then
                    parsed.next = string.sub(line, 6)
                elseif string.sub(line, 1, 11) == "startlevel " then
                    parsed.startlevel = tonumber(string.sub(line, 12))
                end

            else
                -- Keep the real Zygor instruction text for the temporary viewer.
                local display = line
                display = string.gsub(display, "^%.%.", "")
                display = string.gsub(display, "^%.", "")
                display = string.gsub(display, "^'%s*", "")
                display = string.gsub(display, "|tip%s*", " - ")
                display = string.gsub(display, "|q%s*[%d/]+", "")
                display = string.gsub(display, "|noway", "")
                display = string.gsub(display, "|c$", "")
                display = string.gsub(display, "##%d+", "")

                if display ~= "" then
                    table.insert(current.raw, display)
                end
            end
        end
    end

    if table.getn(parsed.steps) == 0 then
        return nil, "no step tags found in raw guide data"
    end

    return parsed
end



-- ---------------------------------------------------------------------------
-- TEST42: automatic guide selection and basic quest-aware step progression.
-- ---------------------------------------------------------------------------

local function ZygorClassic_GetQuestLogTitles()
    local titles = {}
    local i
    for i = 1, GetNumQuestLogEntries() do
        local title, level, tag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
        if title and not isHeader then
            titles[title] = {
                index = i,
                complete = (isComplete == 1)
            }
        end
    end
    return titles
end

local function ZygorClassic_LineQuestTitle(line)
    if type(line) ~= "string" then return nil end

    local t = string.match(line, "^accept%s+(.+)$")
    if t then return t, "accept" end

    t = string.match(line, "^turnin%s+(.+)$")
    if t then return t, "turnin" end

    return nil, nil
end

local function ZygorClassic_StepSatisfied(step)
    if not step or not step.raw then return false end

    local quests = ZygorClassic_GetQuestLogTitles()
    local sawQuestDirective = false
    local i

    for i = 1, table.getn(step.raw) do
        local line = step.raw[i]
        local qtitle, qtype = ZygorClassic_LineQuestTitle(line)

        if qtitle then
            sawQuestDirective = true

            if qtype == "accept" then
                if not quests[qtitle] then
                    return false
                end

            elseif qtype == "turnin" then
                -- If it's still in the quest log, assume it has not been turned in yet.
                if quests[qtitle] then
                    return false
                end
            end
        end
    end

    return sawQuestDirective
end

local function ZygorClassic_GuideMatchesPlayer(guide)
    if not guide then return false end

    local title = tostring(guide.title or "")
    local race = UnitRace("player") or ""
    local faction = ZygorClassic_Faction262() or ""
    local level = UnitLevel("player") or 1

    -- Prefer explicit race guide when available.
    if race ~= "" and string.find(title, "\\" .. race .. " ", 1, true) then
        return true
    end

    -- Otherwise prefer a faction leveling guide.
    if faction == "Alliance" and string.find(title, "Alliance Leveling Guides", 1, true) then
        return true
    end
    if faction == "Horde" and string.find(title, "Horde Leveling Guides", 1, true) then
        return true
    end

    return false
end

function ZygorClassic_AutoSelectGuide()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return end

    local guides = ZygorGuidesViewer.registeredguides
    local total = table.getn(guides)
    local i

    for i = 1, total do
        if ZygorClassic_GuideMatchesPlayer(guides[i]) then
            ZygorClassicGuideIndex = i
            ZygorClassicStepIndex = 1
            return
        end
    end
end

function ZygorClassic_AutoAdvance()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return end

    local guide = ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide then return end

    if not ZygorClassic_EnsureParsed(guide) then return end

    local steps = guide.classic_steps or {}
    local count = table.getn(steps)
    local idx = ZygorClassicStepIndex or 1

    while idx < count and ZygorClassic_StepSatisfied(steps[idx]) do
        idx = idx + 1
    end

    ZygorClassicStepIndex = idx
    ZygorClassic_Render()
end

local function ZygorClassic_CurrentGoto()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return nil end

    local guide = ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return nil end

    local step = guide.classic_steps and guide.classic_steps[ZygorClassicStepIndex or 1]
    if not step or not step.raw then return nil end

    local i
    for i = 1, table.getn(step.raw) do
        local line = step.raw[i]
        local map, x, y = string.match(line, "^goto%s+([^,]+),([0-9%.]+),([0-9%.]+)")
        if map and x and y then
            return map, tonumber(x), tonumber(y)
        end

        x, y = string.match(line, "^goto%s+([0-9%.]+),([0-9%.]+)")
        if x and y then
            return nil, tonumber(x), tonumber(y)
        end
    end

    return nil
end

function ZygorClassic_UpdateWaypointText()
    if not ZygorClassicBody then return end

    local map, x, y = ZygorClassic_CurrentGoto()
    if not x or not y then return end

    -- Keep this simple for now: show the parsed target in chat once per change.
    local key = tostring(map or "") .. ":" .. tostring(x) .. ":" .. tostring(y)
    if key ~= ZygorClassicLastWaypoint then
        ZygorClassicLastWaypoint = key
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00Zygor waypoint:|r " ..
                (map and (map .. " ") or "") ..
                tostring(x) .. ", " .. tostring(y)
            )
        end
    end
end

-- Refresh on the quest-log events available in Vanilla.
-- TEST225: own the confirmed turn-in pair in the first quest event frame in
-- this file. Later automation can claim a reward while the same event is
-- being dispatched, so a witness registered near the end of Compat_112.lua
-- is not early enough on every 1.12 server/addon event dispatcher.
ZygorClassicConfirmedTurnin225Pending=ZygorClassicConfirmedTurnin225Pending or {}

local function ZygorClassic_CharacterKey225()
    if ZygorClassic_Key49 then return ZygorClassic_Key49() end
    return tostring(GetRealmName and GetRealmName() or "Realm")..":"..
           tostring(UnitName("player") or "Unknown")
end

local function ZygorClassic_RewardTitle225()
    local title=GetTitleText and GetTitleText() or nil
    if (not title or title=="") and GetQuestLogSelection and GetQuestLogTitle then
        local selected=GetQuestLogSelection()
        if selected then title=GetQuestLogTitle(selected) end
    end
    if title and title~="" then return title end
    return nil
end

function ZygorClassic_StageConfirmedTurnin225()
    local title=ZygorClassic_RewardTitle225()
    if not title then return false end
    local key=ZygorClassic_CharacterKey225()
    ZygorClassicConfirmedTurnin225Pending[key]=title
    ZygorClassicDB=ZygorClassicDB or {}
    ZygorClassicDB.pendingTurnins225=ZygorClassicDB.pendingTurnins225 or {}
    ZygorClassicDB.pendingTurnins225[key]=title
    return true
end

function ZygorClassic_CommitConfirmedTurnin225()
    local key=ZygorClassic_CharacterKey225()
    local title=ZygorClassicConfirmedTurnin225Pending[key] or
                (ZygorClassicDB and ZygorClassicDB.pendingTurnins225 and
                 ZygorClassicDB.pendingTurnins225[key])
    if not title then return false end
    ZygorClassicDB=ZygorClassicDB or {}
    ZygorClassicDB.turnins62=ZygorClassicDB.turnins62 or {}
    ZygorClassicDB.confirmedTurnins224=ZygorClassicDB.confirmedTurnins224 or {}
    ZygorClassicDB.turnins62[key]=ZygorClassicDB.turnins62[key] or {}
    ZygorClassicDB.confirmedTurnins224[key]=ZygorClassicDB.confirmedTurnins224[key] or {}
    ZygorClassicDB.turnins62[key][title]=true
    ZygorClassicDB.confirmedTurnins224[key][title]=true
    -- TEST231: bind the reward event to the exact ##questID on the current
    -- guide turn-in step. Vanilla's live title omits chain suffixes.
    local state=ZygorClassicDB.engine172 and ZygorClassicDB.engine172[key]
    local guide=state and ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[state.guide]
    local step=guide and guide.classic_steps and guide.classic_steps[state.step]
    local wanted=string.gsub(tostring(title or ""),"%s*%(%d+%)%s*$","")
    local i
    for i=1,table.getn((step and step.source) or {}) do
        local clean=string.gsub(tostring(step.source[i] or ""),"^%.+","")
        local startPos,endPos,guideTitle,questID=
            string.find(clean,"^turnin%s+(.+)##(%d+)")
        guideTitle=string.gsub(tostring(guideTitle or ""),"%s*%(%d+%)%s*$","")
        if questID and guideTitle==wanted and ZygorClassic_RecordQuestIDTurnin216 then
            ZygorClassic_RecordQuestIDTurnin216(questID)
        end
    end
    ZygorClassicConfirmedTurnin225Pending[key]=nil
    if ZygorClassicDB.pendingTurnins225 then ZygorClassicDB.pendingTurnins225[key]=nil end
    return title
end

if not ZygorClassicAutoFrame then
    ZygorClassicAutoFrame = CreateFrame("Frame", "ZygorClassicAutoFrame", UIParent)
    ZygorClassicAutoFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    ZygorClassicAutoFrame:RegisterEvent("QUEST_LOG_UPDATE")
    ZygorClassicAutoFrame:RegisterEvent("QUEST_ACCEPTED")
    ZygorClassicAutoFrame:RegisterEvent("QUEST_COMPLETE")
    ZygorClassicAutoFrame:RegisterEvent("QUEST_FINISHED")

    ZygorClassicAutoFrame:SetScript("OnEvent", function()
        if event == "QUEST_COMPLETE" then
            ZygorClassic_StageConfirmedTurnin225()
        elseif event == "QUEST_FINISHED" then
            local confirmedTitle=ZygorClassic_CommitConfirmedTurnin225()
            if confirmedTitle and ZygorClassicDebug82 then
                ZygorClassicDebug82.event="CONFIRMED TURNIN: "..tostring(confirmedTitle)
            end
        end
        if event == "PLAYER_ENTERING_WORLD" then
            ZygorClassic_AutoSelectGuide()
        end
        ZygorClassic_AutoAdvance()
        ZygorClassic_UpdateWaypointText()
    end)
end


-- ---------------------------------------------------------------------------
-- TEST43: visibly expose automatic tracking and choose a likely current step.
-- ---------------------------------------------------------------------------

ZygorClassicSeenQuests = ZygorClassicSeenQuests or {}

local function ZygorClassic_RecordSeenQuests()
    local i
    for i = 1, GetNumQuestLogEntries() do
        local title, level, tag, isHeader = GetQuestLogTitle(i)
        if title and not isHeader then
            ZygorClassicSeenQuests[title] = true
        end
    end
end

local function ZygorClassic_FindQuestInStep(step)
    if not step or not step.raw then return nil, nil end
    local i
    for i = 1, table.getn(step.raw) do
        local line = step.raw[i]
        if type(line) == "string" then
            local q = string.match(line, "^accept%s+(.+)$")
            if q then return q, "accept" end
            q = string.match(line, "^turnin%s+(.+)$")
            if q then return q, "turnin" end
        end
    end
    return nil, nil
end

function ZygorClassic_AutoFindCurrentStep()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return end
    local guide = ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return end

    local quests = ZygorClassic_GetQuestLogTitles()
    local steps = guide.classic_steps or {}
    local best = nil
    local i

    -- Prefer a step that directly references a quest currently in the log.
    for i = 1, table.getn(steps) do
        local q, kind = ZygorClassic_FindQuestInStep(steps[i])
        if q and quests[q] then
            best = i
        end
    end

    -- If nothing matched, stay at the first step.
    if best then
        ZygorClassicStepIndex = best
    elseif not ZygorClassicStepIndex then
        ZygorClassicStepIndex = 1
    end
end

-- Preserve original renderer and add visible AUTO information.
if not ZygorClassic_Render_Base then
    ZygorClassic_Render_Base = ZygorClassic_Render
    ZygorClassic_Render = function()
        ZygorClassic_Render_Base()

        if not ZygorClassicBody or not ZygorGuidesViewer then return end
        local guide = ZygorGuidesViewer.registeredguides and ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
        if not guide or not guide.classic_steps then return end

        local step = guide.classic_steps[ZygorClassicStepIndex or 1]
        local q, kind = ZygorClassic_FindQuestInStep(step)
        local quests = ZygorClassic_GetQuestLogTitles()
        local map, x, y = ZygorClassic_CurrentGoto()

        local extra = "\n\nAUTO: quest tracking ON"
        extra = extra .. "\nPlayer: " .. tostring(UnitRace("player") or "?") .. " level " .. tostring(UnitLevel("player") or "?")

        if q then
            local state = quests[q] and "IN QUEST LOG" or "NOT IN QUEST LOG"
            extra = extra .. "\nQuest: " .. tostring(q) .. " [" .. state .. "]"
        else
            extra = extra .. "\nQuest: no accept/turnin on this step"
        end

        if x and y then
            extra = extra .. "\nWaypoint: " .. (map and (tostring(map) .. " ") or "") .. tostring(x) .. ", " .. tostring(y)
        end

        local current = ZygorClassicBody:GetText() or ""
        ZygorClassicBody:SetText(current .. extra)
    end
end

-- Replace the TEST42 event handler with a more visible/robust one.
if ZygorClassicAutoFrame then
    ZygorClassicAutoFrame:SetScript("OnEvent", function()
        ZygorClassic_RecordSeenQuests()

        if event == "PLAYER_ENTERING_WORLD" then
            ZygorClassic_AutoSelectGuide()
            ZygorClassic_AutoFindCurrentStep()
        else
            ZygorClassic_AutoFindCurrentStep()
            ZygorClassic_AutoAdvance()
        end

        ZygorClassic_Render()
        ZygorClassic_UpdateWaypointText()
    end)
end


-- ---------------------------------------------------------------------------
-- TEST44: parse Zygor ##questID markers instead of treating "##783" as text.
-- ---------------------------------------------------------------------------

local function ZygorClassic_ParseQuestDirective(line)
    if type(line) ~= "string" then return nil, nil, nil end

    local kind = nil
    local rest = nil

    if string.sub(line, 1, 7) == "accept " then
        kind = "accept"
        rest = string.sub(line, 8)
    elseif string.sub(line, 1, 7) == "turnin " then
        kind = "turnin"
        rest = string.sub(line, 8)
    else
        return nil, nil, nil
    end

    local title = rest
    local qid = nil
    local p = string.find(rest, "##")
    if p then
        title = string.sub(rest, 1, p - 1)
        qid = tonumber(string.sub(rest, p + 2))
    end

    title = string.gsub(title or "", "%s+$", "")
    return title, kind, qid
end

-- Override the earlier TEST42 helper.
ZygorClassic_LineQuestTitle = function(line)
    local title, kind, qid = ZygorClassic_ParseQuestDirective(line)
    return title, kind, qid
end

local function ZygorClassic_FindQuestInStep44(step)
    if not step or not step.raw then return nil, nil, nil end
    local i
    for i = 1, table.getn(step.raw) do
        local title, kind, qid = ZygorClassic_ParseQuestDirective(step.raw[i])
        if title then return title, kind, qid end
    end
    return nil, nil, nil
end

-- Override visible tracker helper so it displays the real quest title.
ZygorClassic_FindQuestInStep = ZygorClassic_FindQuestInStep44

-- Override satisfaction check with cleaned quest names.
ZygorClassic_StepSatisfied = function(step)
    if not step or not step.raw then return false end
    local quests = ZygorClassic_GetQuestLogTitles()
    local saw = false
    local i

    for i = 1, table.getn(step.raw) do
        local title, kind = ZygorClassic_ParseQuestDirective(step.raw[i])
        if title then
            saw = true
            if kind == "accept" and not quests[title] then
                return false
            elseif kind == "turnin" and quests[title] then
                return false
            end
        end
    end

    return saw
end

-- Override current-step matching using cleaned titles.
ZygorClassic_AutoFindCurrentStep = function()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return end
    local guide = ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return end

    local quests = ZygorClassic_GetQuestLogTitles()
    local steps = guide.classic_steps or {}
    local best = nil
    local i

    for i = 1, table.getn(steps) do
        local title = ZygorClassic_FindQuestInStep44(steps[i])
        if title and quests[title] then
            best = i
        end
    end

    if best then
        ZygorClassicStepIndex = best
    elseif not ZygorClassicStepIndex then
        ZygorClassicStepIndex = 1
    end
end

-- Replace TEST43's renderer wrapper with one that shows cleaned quest title + ID.
if ZygorClassic_Render_Base then
    ZygorClassic_Render = function()
        ZygorClassic_Render_Base()

        if not ZygorClassicBody or not ZygorGuidesViewer then return end
        local guide = ZygorGuidesViewer.registeredguides and ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
        if not guide or not guide.classic_steps then return end

        local step = guide.classic_steps[ZygorClassicStepIndex or 1]
        local q, kind, qid = ZygorClassic_FindQuestInStep44(step)
        local quests = ZygorClassic_GetQuestLogTitles()
        local map, x, y = ZygorClassic_CurrentGoto()

        local extra = "\n\nAUTO: quest tracking ON"
        extra = extra .. "\nPlayer: " .. tostring(UnitRace("player") or "?") .. " level " .. tostring(UnitLevel("player") or "?")

        if q then
            local state = quests[q] and "IN QUEST LOG" or "NOT IN QUEST LOG"
            extra = extra .. "\nQuest: " .. tostring(q)
            if qid then extra = extra .. " (#" .. tostring(qid) .. ")" end
            extra = extra .. " [" .. state .. "]"
        else
            extra = extra .. "\nQuest: no accept/turnin on this step"
        end

        if x and y then
            extra = extra .. "\nWaypoint: " .. (map and (tostring(map) .. " ") or "") .. tostring(x) .. ", " .. tostring(y)
        end

        local current = ZygorClassicBody:GetText() or ""
        ZygorClassicBody:SetText(current .. extra)
    end
end


-- ---------------------------------------------------------------------------
-- TEST45: persistent progress + level/race-aware smart starting guide.
-- Vanilla 1.12 cannot query complete historical quest completion, so first-run
-- sync uses race/faction + guide level ranges + current quest log.
-- ---------------------------------------------------------------------------

ZygorClassicDB = ZygorClassicDB or {}
ZygorClassicDB.characters = ZygorClassicDB.characters or {}

local function ZygorClassic_CharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName and GetRealmName() or "Realm"
    return tostring(realm) .. ":" .. tostring(name)
end

-- Return the furthest trustworthy checkpoint recorded by any generation of
-- the backport.  Older packages wrote characters/smart51 while the current
-- state machine writes engine172.  Treating a missing newest record as a new
-- character loses real progress and lets quest-log bootstrap rewind the guide.
local function ZygorClassic_SavedCheckpoint342(key)
    if not ZygorClassicDB then return nil,nil end
    local candidates={}
    if type(ZygorClassicDB.engine172)=="table" then
        table.insert(candidates,ZygorClassicDB.engine172[key])
    end
    if type(ZygorClassicDB.smart51)=="table" then
        table.insert(candidates,ZygorClassicDB.smart51[key])
    end
    if type(ZygorClassicDB.characters)=="table" then
        table.insert(candidates,ZygorClassicDB.characters[key])
    end

    local bestGuide,bestStep=nil,nil
    local i
    for i=1,table.getn(candidates) do
        local candidate=candidates[i]
        local guide=candidate and tonumber(candidate.guide)
        local step=candidate and tonumber(candidate.step)
        if guide and guide>0 and step and step>0 then
            if not bestGuide then
                bestGuide,bestStep=guide,step
            elseif guide==bestGuide and step>bestStep then
                bestStep=step
            end
        end
    end
    return bestGuide,bestStep
end

local function ZygorClassic_CharDB()
    -- SavedVariables from older revisions may restore ZygorClassicDB without
    -- the per-character subtable after this file's initial defaults run.
    -- Repair the shape at the point of use so login and reload are safe.
    ZygorClassicDB = ZygorClassicDB or {}
    if type(ZygorClassicDB.characters) ~= "table" then
        ZygorClassicDB.characters = {}
    end
    local key = ZygorClassic_CharacterKey()
    if not ZygorClassicDB.characters[key] then
        local savedGuide,savedStep=ZygorClassic_SavedCheckpoint342(key)
        ZygorClassicDB.characters[key] = {
            guide = savedGuide,
            step = savedStep,
            seenQuests = {}
        }
    else
        -- Fill a partially migrated record, and recover a later same-guide
        -- checkpoint if an older renderer saved more recently than this table.
        local char=ZygorClassicDB.characters[key]
        local savedGuide,savedStep=ZygorClassic_SavedCheckpoint342(key)
        if savedGuide and savedStep and
           (not tonumber(char.guide) or not tonumber(char.step) or
            (tonumber(char.guide)==savedGuide and savedStep>tonumber(char.step))) then
            char.guide=savedGuide
            char.step=savedStep
        end
        char.seenQuests=char.seenQuests or {}
    end
    return ZygorClassicDB.characters[key]
end

local function ZygorClassic_GuideLevelRange(title)
    if type(title) ~= "string" then return nil, nil end

    -- Parse common guide title ranges such as "(1-13)", "(13-20)", etc.
    local a, b = string.match(title, "%((%d+)%-(%d+)%)")
    if a and b then return tonumber(a), tonumber(b) end

    a = string.match(title, "%((%d+)%)")
    if a then
        a = tonumber(a)
        return a, a
    end

    return nil, nil
end

local function ZygorClassic_GuideFactionScore(title, race, faction)
    local score = 0
    title = tostring(title or "")

    if race ~= "" and string.find(title, race, 1, true) then
        score = score + 100
    end

    if faction == "Alliance" and string.find(title, "Alliance", 1, true) then
        score = score + 30
    elseif faction == "Horde" and string.find(title, "Horde", 1, true) then
        score = score + 30
    end

    return score
end

function ZygorClassic_SmartSelectGuide()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return end

    local db = ZygorClassic_CharDB()
    local guides = ZygorGuidesViewer.registeredguides
    local total = table.getn(guides)

    -- Restore saved guide/step first.
    if db.guide and guides[db.guide] then
        ZygorClassicGuideIndex = db.guide
        ZygorClassicStepIndex = db.step or 1
        return
    end

    local level = UnitLevel("player") or 1
    local race = UnitRace("player") or ""
    local faction = ZygorClassic_Faction262() or ""
    local bestIndex = nil
    local bestScore = -999999
    local i

    for i = 1, total do
        local g = guides[i]
        local title = tostring(g.title or "")
        local lo, hi = ZygorClassic_GuideLevelRange(title)

        if lo and hi then
            local score = ZygorClassic_GuideFactionScore(title, race, faction)

            if level >= lo and level <= hi then
                score = score + 1000
            elseif level > hi then
                score = score - ((level - hi) * 20)
            else
                score = score - ((lo - level) * 20)
            end

            if score > bestScore then
                bestScore = score
                bestIndex = i
            end
        end
    end

    if bestIndex then
        ZygorClassicGuideIndex = bestIndex
        ZygorClassicStepIndex = 1
    else
        ZygorClassicGuideIndex = 1
        ZygorClassicStepIndex = 1
    end
end

function ZygorClassic_SaveProgress()
    local db = ZygorClassic_CharDB()
    db.guide = ZygorClassicGuideIndex or 1
    db.step = ZygorClassicStepIndex or 1
end

-- Track quest names observed while the addon is installed.
function ZygorClassic_RecordSeenQuests45()
    local db = ZygorClassic_CharDB()
    db.seenQuests = db.seenQuests or {}

    local i
    for i = 1, GetNumQuestLogEntries() do
        local title, level, tag, isHeader = GetQuestLogTitle(i)
        if title and not isHeader then
            db.seenQuests[title] = true
        end
    end
end

-- Wrap renderer so every successful render persists position.
if not ZygorClassic_Render_Test45_Base then
    ZygorClassic_Render_Test45_Base = ZygorClassic_Render
    ZygorClassic_Render = function()
        ZygorClassic_Render_Test45_Base()
        ZygorClassic_SaveProgress()
    end
end

-- Use smart start and restore saved progress at login.
if ZygorClassicAutoFrame then
    ZygorClassicAutoFrame:SetScript("OnEvent", function()
        ZygorClassic_RecordSeenQuests45()

        if event == "PLAYER_ENTERING_WORLD" then
            ZygorClassic_SmartSelectGuide()
            ZygorClassic_AutoFindCurrentStep()
        else
            ZygorClassic_AutoFindCurrentStep()
            ZygorClassic_AutoAdvance()
        end

        ZygorClassic_Render()
        ZygorClassic_UpdateWaypointText()
    end)
end


-- TEST49: do NOT lock Smart Start when only the first guide has registered.
-- Wait for the full guide registry (this package has 115 guides), then select
-- the correct faction/level bracket exactly once for this build.

ZygorClassicDB = ZygorClassicDB or {}
ZygorClassicDB.smart49 = ZygorClassicDB.smart49 or {}

local function ZygorClassic_Key49()
    return tostring(GetRealmName and GetRealmName() or "Realm") .. ":" .. tostring(UnitName("player") or "Unknown")
end

local function ZygorClassic_Select49()
    local z = ZygorGuidesViewer
    if not z or not z.registeredguides then return false end
    local guides = z.registeredguides
    local total = table.getn(guides)

    -- Critical TEST49 fix: TEST48 could run when Guide 1 existed but the other
    -- 114 guides had not registered yet. Never select until the full set exists.
    if total < 115 then return false end

    local level = UnitLevel("player") or 1
    local faction = ZygorClassic_Faction262() or ""
    local race = UnitRace("player") or ""
    local best, bestScore = nil, -999999
    local i

    for i=1,total do
        local title = tostring(guides[i].title or "")
        local lo,hi = string.match(title, "%((%d+)%-(%d+)%)")
        lo,hi = tonumber(lo),tonumber(hi)

        if lo and hi then
            local score = 0
            local alliance = string.find(title, "Zygor's Alliance Leveling Guides", 1, true)
            local horde = string.find(title, "Zygor's Horde Leveling Guides", 1, true)

            if (faction=="Alliance" and alliance) or (faction=="Horde" and horde) then
                score = score + 100000
            else
                score = score - 100000
            end

            -- Level 25 belongs to 25-30, not 20-25.
            if level >= lo and level < hi then
                score = score + 10000
            elseif level < lo then
                score = score - ((lo-level)*100)
            else
                score = score - ((level-hi+1)*100)
            end

            if level < 13 and race ~= "" and string.find(title, "\\"..race.." ", 1, true) then
                score = score + 5000
            end

            score = score + lo
            if score > bestScore then
                bestScore, best = score, i
            end
        end
    end

    if not best then return false end

    ZygorClassicGuideIndex = best
    ZygorClassicStepIndex = 1
    ZygorClassicDB.smart49[ZygorClassic_Key49()] = true

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Zygor Smart Start TEST49:|r "..tostring(guides[best].title or "?"))
    end
    return true
end

if not ZygorClassic_Render49_Base then
    ZygorClassic_Render49_Base = ZygorClassic_Render
    ZygorClassic_Render = function()
        local key = ZygorClassic_Key49()
        if not ZygorClassicDB.smart49[key] then
            ZygorClassic_Select49()
        end
        ZygorClassic_Render49_Base()
    end
end


-- TEST50: exact bracket selector. TEST49 proved all 115 guides were present,
-- so registration timing is solved. Avoid score/range ambiguity entirely.
ZygorClassicDB.smart50 = ZygorClassicDB.smart50 or {}

local function ZygorClassic_Select50()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return false end
    local guides=ZygorGuidesViewer.registeredguides
    if table.getn(guides)<115 then return false end

    local level=UnitLevel("player") or 1
    local faction=ZygorClassic_Faction262() or ""
    local race=UnitRace("player") or ""
    local prefix="Zygor's "..faction.." Leveling Guides\\"
    local wanted=nil

    if level < 13 then
        wanted=prefix..race.." (1-13)"
    elseif level < 20 then
        wanted=prefix.."Main Guide (13-20)"
    elseif level < 25 then wanted=prefix.."Levels (20-25)"
    elseif level < 30 then wanted=prefix.."Levels (25-30)"
    elseif level < 35 then wanted=prefix.."Levels (30-35)"
    elseif level < 40 then wanted=prefix.."Levels (35-40)"
    elseif level < 45 then wanted=prefix.."Levels (40-45)"
    elseif level < 50 then wanted=prefix.."Levels (45-50)"
    elseif level < 55 then wanted=prefix.."Levels (50-55)"
    elseif level < 60 then wanted=prefix.."Levels (55-60)"
    end

    local i
    if wanted then
        for i=1,table.getn(guides) do
            if tostring(guides[i].title or "")==wanted then
                ZygorClassicGuideIndex=i
                ZygorClassicStepIndex=1
                ZygorClassicDB.smart50[ZygorClassic_Key49()]=true
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Zygor Smart Start TEST50:|r "..wanted.." [Guide "..tostring(i).."]")
                end
                return true
            end
        end
    end

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Zygor TEST50: exact guide not found:|r "..tostring(wanted))
    end
    return false
end

if not ZygorClassic_Render50_Base then
    ZygorClassic_Render50_Base=ZygorClassic_Render
    ZygorClassic_Render=function()
        local key=ZygorClassic_Key49()
        if not ZygorClassicDB.smart50[key] then ZygorClassic_Select50() end
        ZygorClassic_Render50_Base()
    end
end


-- TEST51: TEST50 selected Guide 9 correctly, then the older TEST49 render
-- wrapper immediately selected Human (1-13) again. Disable the obsolete
-- TEST49 selector before rendering and force the exact TEST50 bracket.

ZygorClassicDB = ZygorClassicDB or {}
ZygorClassicDB.smart51 = ZygorClassicDB.smart51 or {}

local function ZygorClassic_ForceExactGuide51()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return false end
    local guides = ZygorGuidesViewer.registeredguides
    if table.getn(guides) < 115 then return false end

    local level = UnitLevel("player") or 1
    local faction = ZygorClassic_Faction262() or ""
    local race = UnitRace("player") or ""
    local prefix = "Zygor's "..faction.." Leveling Guides\\"
    local wanted = nil

    if level < 13 then wanted = prefix..race.." (1-13)"
    elseif level < 20 then wanted = prefix.."Main Guide (13-20)"
    elseif level < 25 then wanted = prefix.."Levels (20-25)"
    elseif level < 30 then wanted = prefix.."Levels (25-30)"
    elseif level < 35 then wanted = prefix.."Levels (30-35)"
    elseif level < 40 then wanted = prefix.."Levels (35-40)"
    elseif level < 45 then wanted = prefix.."Levels (40-45)"
    elseif level < 50 then wanted = prefix.."Levels (45-50)"
    elseif level < 55 then wanted = prefix.."Levels (50-55)"
    else wanted = prefix.."Levels (55-60)" end

    local i
    for i=1,table.getn(guides) do
        if tostring(guides[i].title or "") == wanted then
            local key = ZygorClassic_Key49()

            -- Prevent TEST49 from undoing this selection inside its old wrapper.
            ZygorClassicDB.smart49 = ZygorClassicDB.smart49 or {}
            ZygorClassicDB.smart49[key] = true

            -- Also mark TEST50 as handled so its nested wrapper does not interfere.
            ZygorClassicDB.smart50 = ZygorClassicDB.smart50 or {}
            ZygorClassicDB.smart50[key] = true

            ZygorClassicGuideIndex = i
            ZygorClassicStepIndex = 1
            ZygorClassicDB.smart51[key] = {guide=i, step=1}

            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Zygor Smart Start TEST51:|r "..wanted.." [Guide "..tostring(i).."]")
            end
            return true
        end
    end
    return false
end

if not ZygorClassic_Render51_Base then
    ZygorClassic_Render51_Base = ZygorClassic_Render
    ZygorClassic_Render = function()
        local key = ZygorClassic_Key49()
        local state = ZygorClassicDB.smart51[key]

        if not state then
            ZygorClassic_ForceExactGuide51()
            state = ZygorClassicDB.smart51[key]
        end

        if state and state.guide and ZygorGuidesViewer and
           ZygorGuidesViewer.registeredguides and
           ZygorGuidesViewer.registeredguides[state.guide] then
            -- Set the old selector flags BEFORE entering the nested renderers.
            ZygorClassicDB.smart49[key] = true
            ZygorClassicDB.smart50[key] = true
            ZygorClassicGuideIndex = state.guide
            if not ZygorClassicStepIndex then ZygorClassicStepIndex = state.step or 1 end
        end

        ZygorClassic_Render51_Base()
    end
end


-- ---------------------------------------------------------------------------
-- TEST52: quest-log Smart Sync.
-- Uses the character's CURRENT quest log to place the viewer deeper inside the
-- selected guide instead of always beginning at Step 1.
-- ---------------------------------------------------------------------------

-- Re-parse raw guides while preserving the original Zygor line as `source`.
-- The native viewer still displays the cleaned `raw` line.
function ZygorClassic_ParseRawGuide(raw)
    if type(raw) ~= "string" then
        return nil, "raw guide data is not a string"
    end

    local parsed = { steps = {} }
    local current = nil
    local newline = string.char(10)
    local carriage = string.char(13)

    raw = raw .. newline
    local pos = 1
    local total = string.len(raw)

    while pos <= total do
        local s, e = string.find(raw, newline, pos)
        if not s then break end

        local line = string.sub(raw, pos, s - 1)
        pos = e + 1

        line = string.gsub(line or "", carriage, "")
        line = string.gsub(line, "^%s+", "")
        line = string.gsub(line, "%s+$", "")

        if line ~= "" then
            if string.sub(line, 1, 4) == "step" and
               (string.len(line) == 4 or string.sub(line, 5, 5) == " " or string.sub(line, 5, 5) == string.char(9)) then

                current = { raw = {}, source = {} }
                table.insert(parsed.steps, current)

            elseif current == nil then
                if string.sub(line, 1, 7) == "author " then
                    parsed.author = string.sub(line, 8)
                elseif string.sub(line, 1, 11) == "defaultfor " then
                    parsed.defaultfor = string.sub(line, 12)
                elseif string.sub(line, 1, 5) == "next " then
                    parsed.next = string.sub(line, 6)
                elseif string.sub(line, 1, 11) == "startlevel " then
                    parsed.startlevel = tonumber(string.sub(line, 12))
                end

            else
                table.insert(current.source, line)

                local display = line
                display = string.gsub(display, "^%.%.", "")
                display = string.gsub(display, "^%.", "")
                display = string.gsub(display, "^'%s*", "")
                display = string.gsub(display, "|tip%s*", " - ")
                display = string.gsub(display, "|q%s*[%d/]+", "")
                display = string.gsub(display, "|noway", "")
                display = string.gsub(display, "|c$", "")
                display = string.gsub(display, "##%d+", "")

                if display ~= "" then
                    table.insert(current.raw, display)
                end
            end
        end
    end

    if table.getn(parsed.steps) == 0 then
        return nil, "no step tags found in raw guide data"
    end

    return parsed
end

local function ZygorClassic_QuestLog52()
    local q = {}
    local i
    for i=1,GetNumQuestLogEntries() do
        local title, level, tag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
        if title and not isHeader then
            q[title] = {
                index=i,
                complete=(isComplete==1),
                objectives={}
            }

            local n = 0
            if GetNumQuestLeaderBoards then
                n = GetNumQuestLeaderBoards(i) or 0
            end

            local o
            for o=1,n do
                local text, objectiveType, finished = GetQuestLogLeaderBoard(o,i)
                q[title].objectives[o] = (finished == 1 or finished == true)
            end
        end
    end
    return q
end

local function ZygorClassic_BuildGuideQuestMap52(guide)
    local map = {}
    local steps = guide.classic_steps or {}
    local i,j

    for i=1,table.getn(steps) do
        local step=steps[i]
        local source=step.source or {}

        for j=1,table.getn(source) do
            local line=source[j]

            -- accept/turnin title##ID
            local cleaned=string.gsub(line,"^%.+","")
            local title,kind,qid = ZygorClassic_ParseQuestDirective(cleaned)
            if title and qid then
                map[title]=map[title] or {id=qid, objectives={}}
                map[title].id=qid
                if kind=="accept" then map[title].acceptStep=i end
                if kind=="turnin" then map[title].turninStep=i end
            end
        end
    end

    -- Second pass: associate |q ID/objective lines with the quest title.
    local titleByID={}
    local title,data
    for title,data in pairs(map) do
        if data.id then titleByID[data.id]=title end
    end

    for i=1,table.getn(steps) do
        local source=steps[i].source or {}
        for j=1,table.getn(source) do
            local line=source[j]
            local qid,obj = string.match(line,"|q%s*(%d+)/(%d+)")
            qid=tonumber(qid)
            obj=tonumber(obj)
            if qid and titleByID[qid] then
                title=titleByID[qid]
                data=map[title]
                data.objectives[obj]=data.objectives[obj] or {}
                table.insert(data.objectives[obj],i)
            end
        end
    end

    return map
end

function ZygorClassic_SyncCurrentStep52(showMessage)
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return false end
    local guide=ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return false end

    local log=ZygorClassic_QuestLog52()
    local map=ZygorClassic_BuildGuideQuestMap52(guide)
    local best=nil
    local reason=nil
    local title,info,data,obj,steps,k

    for title,info in pairs(log) do
        data=map[title]
        if data then
            local candidate=nil
            local why=nil

            if info.complete and data.turninStep then
                candidate=data.turninStep
                why=title.." complete -> turn in"

            else
                -- Find the first unfinished objective that exists in this guide.
                for obj,steps in pairs(data.objectives) do
                    if not info.objectives[obj] and steps and table.getn(steps)>0 then
                        candidate=steps[1]
                        why=title.." objective "..tostring(obj)
                        break
                    end
                end

                -- Accepted but no objective mapping: move just beyond accept.
                if not candidate and data.acceptStep then
                    candidate=data.acceptStep+1
                    why=title.." already accepted"
                end
            end

            if candidate and (not best or candidate>best) then
                best=candidate
                reason=why
            end
        end
    end

    if best then
        local count=table.getn(guide.classic_steps or {})
        if best<1 then best=1 end
        if best>count then best=count end
        ZygorClassicStepIndex=best

        -- Update TEST51's persistent state.
        local key=ZygorClassic_Key49()
        ZygorClassicDB.smart51=ZygorClassicDB.smart51 or {}
        ZygorClassicDB.smart51[key]=ZygorClassicDB.smart51[key] or {}
        ZygorClassicDB.smart51[key].guide=ZygorClassicGuideIndex
        ZygorClassicDB.smart51[key].step=best

        if showMessage and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00Zygor Quest Sync:|r Step "..tostring(best)..
                (reason and (" - "..reason) or "")
            )
        end
        return true
    end

    if showMessage and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Zygor Quest Sync:|r no current quest-log match; keeping saved/current step.")
    end
    return false
end

-- Force a one-time sync for TEST52 after Guide 9/appropriate bracket is stable.
ZygorClassicDB.smart52 = ZygorClassicDB.smart52 or {}

if not ZygorClassic_Render52_Base then
    ZygorClassic_Render52_Base=ZygorClassic_Render
    ZygorClassic_Render=function()
        local key=ZygorClassic_Key49()

        if ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
           table.getn(ZygorGuidesViewer.registeredguides)>=115 and
           not ZygorClassicDB.smart52[key] then

            -- Let TEST51 establish the correct guide first.
            ZygorClassic_Render52_Base()

            if ZygorClassic_SyncCurrentStep52(true) then
                ZygorClassicDB.smart52[key]=true
                -- Render again at the synced step.
                ZygorClassic_Render52_Base()
            else
                ZygorClassicDB.smart52[key]=true
            end
            return
        end

        ZygorClassic_Render52_Base()
    end
end

-- Manual re-sync command for testing and future use.
SLASH_ZYGORSYNC1="/zsync"
SlashCmdList["ZYGORSYNC"]=function(msg)
    if ZygorClassic_SyncCurrentStep52(true) then
        ZygorClassic_Render()
        ZygorClassic_UpdateWaypointText()
    end
end


-- ---------------------------------------------------------------------------
-- TEST53: first-run level fallback + live quest progression.
-- If the 1.12 client has no historical quest match, choose a reasonable point
-- inside the correct level bracket instead of blindly remaining at Step 1.
-- Then resync whenever the quest log changes.
-- ---------------------------------------------------------------------------

ZygorClassicDB.smart53 = ZygorClassicDB.smart53 or {}

local function ZygorClassic_LevelFallback53()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return false end
    local guide = ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return false end

    local title = tostring(guide.title or "")
    local lo, hi = string.match(title, "%((%d+)%-(%d+)%)")
    lo, hi = tonumber(lo), tonumber(hi)
    if not lo or not hi or hi <= lo then return false end

    local level = UnitLevel("player") or lo
    local steps = guide.classic_steps or {}
    local count = table.getn(steps)
    if count < 1 then return false end

    -- Estimate position within this guide from level. Keep a small amount of
    -- headroom so we do not skip too aggressively on a first-time import.
    local pct = (level - lo) / (hi - lo)
    if pct < 0 then pct = 0 end
    if pct > 1 then pct = 1 end

    local idx = math.floor((count - 1) * pct) + 1
    if idx < 1 then idx = 1 end
    if idx > count then idx = count end

    ZygorClassicStepIndex = idx

    local key = ZygorClassic_Key49()
    ZygorClassicDB.smart51 = ZygorClassicDB.smart51 or {}
    ZygorClassicDB.smart51[key] = ZygorClassicDB.smart51[key] or {}
    ZygorClassicDB.smart51[key].guide = ZygorClassicGuideIndex
    ZygorClassicDB.smart51[key].step = idx

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffffcc00Zygor Level Sync:|r no quest-history match; estimated Step "..
            tostring(idx).."/"..tostring(count).." from level "..tostring(level)
        )
    end
    return true
end

function ZygorClassic_Resync53(showMessage)
    -- First preference is a concrete quest/objective match.
    if ZygorClassic_SyncCurrentStep52(showMessage) then
        return true
    end

    -- Vanilla 1.12 cannot tell us every quest completed before this addon was
    -- installed, so only use the level fallback once for this build/character.
    local key = ZygorClassic_Key49()
    if not ZygorClassicDB.smart53[key] then
        ZygorClassicDB.smart53[key] = true
        return ZygorClassic_LevelFallback53()
    end

    return false
end

-- Run once after TEST51 has established the correct guide.
if not ZygorClassic_Render53_Base then
    ZygorClassic_Render53_Base = ZygorClassic_Render
    ZygorClassic_Render = function()
        local key = ZygorClassic_Key49()
        if not ZygorClassicDB.smart53[key] and
           ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
           table.getn(ZygorGuidesViewer.registeredguides) >= 115 then

            -- Render once so nested TEST51 selector establishes Guide 9/etc.
            ZygorClassic_Render53_Base()

            ZygorClassic_Resync53(true)
            ZygorClassic_Render53_Base()
            return
        end

        ZygorClassic_Render53_Base()
    end
end

-- Live quest-log tracking: once quests are accepted/completed/turned in,
-- concrete quest data overrides the initial level estimate.
if not ZygorClassicLive53 then
    ZygorClassicLive53 = CreateFrame("Frame", "ZygorClassicLive53", UIParent)
    ZygorClassicLive53:RegisterEvent("QUEST_LOG_UPDATE")
    ZygorClassicLive53:RegisterEvent("QUEST_ACCEPTED")
    ZygorClassicLive53:RegisterEvent("QUEST_COMPLETE")
    ZygorClassicLive53:RegisterEvent("QUEST_FINISHED")
    ZygorClassicLive53:SetScript("OnEvent", function()
        if ZygorClassic_SyncCurrentStep52(false) then
            ZygorClassic_Render()
            ZygorClassic_UpdateWaypointText()
        end
    end)
end

-- Upgrade /zsync to include the level fallback.
SlashCmdList["ZYGORSYNC"] = function(msg)
    if ZygorClassic_Resync53(true) then
        ZygorClassic_Render()
        ZygorClassic_UpdateWaypointText()
    end
end


-- ---------------------------------------------------------------------------
-- TEST54: new-character initialization.
-- On a brand-new character the viewer can open before the 115 guide files
-- finish RegisterGuide(). Earlier builds then leave "No guides registered"
-- on screen because nothing forces a second render after registration.
-- TEST54 waits for the full registry, initializes the character, then rerenders.
-- ---------------------------------------------------------------------------

ZygorClassicDB = ZygorClassicDB or {}
ZygorClassicDB.smart54 = ZygorClassicDB.smart54 or {}

local function ZygorClassic_InitNewCharacter54()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return false end
    if table.getn(ZygorGuidesViewer.registeredguides) < 115 then return false end

    local key = ZygorClassic_Key49()
    if ZygorClassicDB.smart54[key] then return true end

    -- TEST51's exact selector handles race-specific 1-13 guides correctly.
    -- Clear its per-character state so a brand-new character gets evaluated.
    ZygorClassicDB.smart51 = ZygorClassicDB.smart51 or {}
    ZygorClassicDB.smart50 = ZygorClassicDB.smart50 or {}
    ZygorClassicDB.smart49 = ZygorClassicDB.smart49 or {}
    ZygorClassicDB.smart52 = ZygorClassicDB.smart52 or {}
    ZygorClassicDB.smart53 = ZygorClassicDB.smart53 or {}

    ZygorClassicDB.smart51[key] = nil
    ZygorClassicDB.smart50[key] = nil
    ZygorClassicDB.smart49[key] = nil
    ZygorClassicDB.smart52[key] = nil
    ZygorClassicDB.smart53[key] = nil

    -- Force exact faction/race/level selection now that all guides exist.
    if ZygorClassic_ForceExactGuide51 and ZygorClassic_ForceExactGuide51() then
        ZygorClassicStepIndex = 1
        ZygorClassicDB.smart54[key] = true

        if DEFAULT_CHAT_FRAME then
            local g = ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00Zygor TEST54 initialized:|r " ..
                tostring(g and g.title or "?") ..
                " [Guide " .. tostring(ZygorClassicGuideIndex or "?") .. "]"
            )
        end

        ZygorClassic_Render()
        ZygorClassic_UpdateWaypointText()
        return true
    end

    return false
end

if not ZygorClassicNewChar54 then
    ZygorClassicNewChar54 = CreateFrame("Frame", "ZygorClassicNewChar54", UIParent)
    ZygorClassicNewChar54.elapsed = 0
    ZygorClassicNewChar54:SetScript("OnUpdate", function()
        this.elapsed = (this.elapsed or 0) + (arg1 or 0)
        if this.elapsed < 0.25 then return end
        this.elapsed = 0

        if ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
           table.getn(ZygorGuidesViewer.registeredguides) >= 115 then

            ZygorClassic_InitNewCharacter54()
            this:Hide()
        end
    end)
end


-- ---------------------------------------------------------------------------
-- TEST55: real waypoint parsing + visible navigation arrow.
-- ---------------------------------------------------------------------------

-- Do not use the old string.match compatibility shim for coordinates.
-- Parse the displayed goto line manually so "29.8,73.8" can never become
-- string.find's start/end positions (the TEST54 "1, 14" bug).
local function ZygorClassic_ParseGoto55(line)
    if type(line) ~= "string" then return nil end

    line = string.gsub(line, "^%s+", "")
    if string.sub(line,1,5) ~= "goto " then return nil end
    local rest = string.sub(line,6)

    local c1 = string.find(rest, ",", 1, true)
    if not c1 then return nil end
    local a = string.sub(rest,1,c1-1)
    local rem = string.sub(rest,c1+1)

    local c2 = string.find(rem, ",", 1, true)
    if c2 then
        local b = string.sub(rem,1,c2-1)
        local c = string.sub(rem,c2+1)
        local x,y = tonumber(b),tonumber(c)
        if x and y then return a,x,y end
    end

    local x,y = tonumber(a),tonumber(rem)
    if x and y then return nil,x,y end
    return nil
end

function ZygorClassic_CurrentGoto55()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return nil end
    local guideIndex,stepIndex=ZygorClassicGuideIndex or 1,ZygorClassicStepIndex or 1
    if ZygorClassic_AuthoritativePosition289 then
        guideIndex,stepIndex=ZygorClassic_AuthoritativePosition289()
    end
    local guide = ZygorGuidesViewer.registeredguides[guideIndex]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return nil end
    local step = guide.classic_steps and guide.classic_steps[stepIndex]
    if not step then return nil end

    local lines = step.raw or step.source
    if not lines then return nil end

    local i
    for i=1,table.getn(lines) do
        local map,x,y = ZygorClassic_ParseGoto55(lines[i])
        if x and y then return map,x,y end
    end
    return nil
end

-- Navigation frame.
if not ZygorClassicArrow55 then
    ZygorClassicArrow55 = CreateFrame("Frame","ZygorClassicArrow55",UIParent)
    ZygorClassicArrow55:SetWidth(170)
    ZygorClassicArrow55:SetHeight(70)
    ZygorClassicArrow55:SetPoint("TOP",UIParent,"TOP",0,-90)
    ZygorClassicArrow55:SetFrameStrata("HIGH")
    ZygorClassicArrow55:EnableMouse(true)
    ZygorClassicArrow55:SetMovable(true)
    ZygorClassicArrow55:RegisterForDrag("LeftButton")
    ZygorClassicArrow55:SetScript("OnDragStart",function() this:StartMoving() end)
    ZygorClassicArrow55:SetScript("OnDragStop",function() this:StopMovingOrSizing() end)

    local bg=ZygorClassicArrow55:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints(ZygorClassicArrow55)
    bg:SetTexture(0,0,0,0.65)

    ZygorClassicArrow55.title=ZygorClassicArrow55:CreateFontString(nil,"OVERLAY","GameFontNormal")
    ZygorClassicArrow55.title:SetPoint("TOP",ZygorClassicArrow55,"TOP",0,-6)
    ZygorClassicArrow55.title:SetText("Zygor Waypoint")

    ZygorClassicArrow55.dir=ZygorClassicArrow55:CreateFontString(nil,"OVERLAY","GameFontNormalHuge")
    ZygorClassicArrow55.dir:SetPoint("CENTER",ZygorClassicArrow55,"CENTER",0,1)
    ZygorClassicArrow55.dir:SetText("^^")

    ZygorClassicArrow55.info=ZygorClassicArrow55:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    ZygorClassicArrow55.info:SetPoint("BOTTOM",ZygorClassicArrow55,"BOTTOM",0,6)
    ZygorClassicArrow55.info:SetText("")
end

local dirs55={"N","NE","E","SE","S","SW","W","NW"}

local function ZygorClassic_Direction55(dx,dy)
    -- Map Y grows downward, so north is negative Y.
    local angle
    if math.atan2 then
        angle=math.atan2(dx,-dy)
    else
        -- Lua 5.0-safe atan2 approximation.
        if dy==0 then
            angle=(dx>=0) and (math.pi/2) or (-math.pi/2)
        else
            angle=math.atan(dx/(-dy))
            if -dy < 0 then angle=angle+math.pi end
        end
    end
    if angle < 0 then angle=angle+2*math.pi end
    local idx=math.floor((angle/(2*math.pi))*8+0.5)+1
    if idx>8 then idx=1 end
    return dirs55[idx]
end

function ZygorClassic_UpdateArrow55()
    local map,x,y=ZygorClassic_CurrentGoto55()
    if not x or not y then
        if ZygorClassicArrow55:IsShown() then ZygorClassicArrow55:Hide() end
        ZygorClassicArrow55.lastDir182=nil
        ZygorClassicArrow55.lastInfo182=nil
        return
    end

    if not ZygorClassicArrow55:IsShown() then ZygorClassicArrow55:Show() end

    -- SetMapToCurrentZone can trigger UI/map redraws on Vanilla.  Calling it
    -- every ticker pass made this diagnostic box visibly flash.  Refresh only
    -- when the actual zone changes.
    local zone=GetZoneText and GetZoneText() or ""
    if SetMapToCurrentZone and ZygorClassicArrow55.mapZone182~=zone then
        SetMapToCurrentZone()
        ZygorClassicArrow55.mapZone182=zone
    end
    local px,py=GetPlayerMapPosition("player")
    px=(px or 0)*100
    py=(py or 0)*100

    local targetMap=map or zone

    if px<=0 and py<=0 then
        local direction="TARGET"
        local info=tostring(targetMap).."  "..tostring(x)..", "..tostring(y)
        if ZygorClassicArrow55.lastDir182~=direction then
            ZygorClassicArrow55.dir:SetText(direction)
            ZygorClassicArrow55.lastDir182=direction
        end
        if ZygorClassicArrow55.lastInfo182~=info then
            ZygorClassicArrow55.info:SetText(info)
            ZygorClassicArrow55.lastInfo182=info
        end
        return
    end

    local dx=x-px
    local dy=y-py
    local direction=ZygorClassic_Direction55(dx,dy)
    local dist=math.sqrt(dx*dx+dy*dy)

    local info=tostring(targetMap).."  "..string.format("%.1f, %.1f",x,y)..
        "   ("..string.format("%.1f",dist).."% map)"
    if ZygorClassicArrow55.lastDir182~=direction then
        ZygorClassicArrow55.dir:SetText(direction)
        ZygorClassicArrow55.lastDir182=direction
    end
    if ZygorClassicArrow55.lastInfo182~=info then
        ZygorClassicArrow55.info:SetText(info)
        ZygorClassicArrow55.lastInfo182=info
    end
end

-- Correct the visible waypoint diagnostic and update arrow continuously.
ZygorClassicLastWaypoint55=nil
local function ZygorClassic_WaypointMessage55()
    local map,x,y=ZygorClassic_CurrentGoto55()
    if not x or not y then return end
    local key=tostring(map or "")..":"..tostring(x)..":"..tostring(y)
    if key~=ZygorClassicLastWaypoint55 then
        ZygorClassicLastWaypoint55=key
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Zygor waypoint TEST55:|r "..
                (map and (map.." ") or "")..tostring(x)..", "..tostring(y))
        end
    end
end

if not ZygorClassicArrowTicker55 then
    ZygorClassicArrowTicker55=CreateFrame("Frame","ZygorClassicArrowTicker55",UIParent)
    ZygorClassicArrowTicker55.elapsed=0
    ZygorClassicArrowTicker55:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.15 then return end
        this.elapsed=0
        -- The native graphical pointer now owns live direction/distance.
        -- This older text box is informational only; redrawing its changing
        -- distance every tick visibly flashes fonts on the Vanilla client.
        local map,x,y=ZygorClassic_CurrentGoto55()
        local key=x and y and (tostring(map or "")..":"..tostring(x)..":"..tostring(y)) or "none"
        -- The route key usually avoids needless font redraws.  Also repair
        -- visibility whenever another legacy renderer has hidden the box;
        -- UpdateArrow55 itself only changes text whose value actually changed.
        if this.waypointKey185~=key or
           (x and y and not ZygorClassicArrow55:IsShown()) or
           (not x and not y and ZygorClassicArrow55:IsShown()) then
            this.waypointKey185=key
            ZygorClassic_UpdateArrow55()
        end
    end)
end

-- Add the corrected waypoint to the viewer after all older render wrappers.
if not ZygorClassic_Render55_Base then
    ZygorClassic_Render55_Base=ZygorClassic_Render
    ZygorClassic_Render=function()
        ZygorClassic_Render55_Base()
        local map,x,y=ZygorClassic_CurrentGoto55()
        if ZygorClassicBody and x and y then
            local text=ZygorClassicBody:GetText() or ""
            text=string.gsub(text,"\nWaypoint:%s*[%w%s%.,%-]+$","")
            ZygorClassicBody:SetText(text.."\nWaypoint TEST55: "..
                (map and (map.." ") or "")..tostring(x)..", "..tostring(y))
        end
        ZygorClassic_WaypointMessage55()
        ZygorClassic_UpdateArrow55()
    end
end


-- TEST61: WoW 1.12 mouse-button compatibility.
if not ZygorClassic_IsMouseButtonDown then
    function ZygorClassic_IsMouseButtonDown(button)
        if IsMouseButtonDown then
            return IsMouseButtonDown(button)
        end
        -- Vanilla 1.12 has no reliable global equivalent for this use-case.
        -- Returning false is safe here; it only disables the pointer's
        -- "while mouse held" interaction behavior.
        return false
    end
end


-- ---------------------------------------------------------------------------
-- TEST62: fix quest turn-in regression + class/race conditional display.
-- ---------------------------------------------------------------------------

ZygorClassicDB = ZygorClassicDB or {}
ZygorClassicDB.turnins62 = ZygorClassicDB.turnins62 or {}
ZygorClassicDB.questSnapshot62 = ZygorClassicDB.questSnapshot62 or {}

local function ZygorClassic_Key62()
    if ZygorClassic_Key49 then return ZygorClassic_Key49() end
    return tostring(GetRealmName and GetRealmName() or "Realm") .. ":" ..
           tostring(UnitName("player") or "Unknown")
end

local function ZygorClassic_QuestSnapshot62()
    local q = {}
    local i
    for i=1,GetNumQuestLogEntries() do
        local title,level,tag,isHeader,isCollapsed,isComplete = GetQuestLogTitle(i)
        if title and not isHeader then
            q[title] = { complete=(isComplete==1) }
        end
    end
    return q
end

local function ZygorClassic_NormalizeQuestTitle170(title)
    title=tostring(title or "")
    -- The original guide bundle contains literal ellipses inside quest names.
    -- An old vararg compatibility pass accidentally rewrote some of them to
    -- the visible text "unpack(arg)".  Restore the punctuation before every
    -- title comparison so active, completed, and turned-in quests still match.
    title=string.gsub(title,"unpack%(arg%)","...")
    title=string.gsub(title,"%s*%(%d+%)%s*$","")
    return title
end

local function ZygorClassic_RecordTurnins62()
    ZygorClassicDB = ZygorClassicDB or {}
    ZygorClassicDB.questSnapshot62 = ZygorClassicDB.questSnapshot62 or {}
    ZygorClassicDB.turnins62 = ZygorClassicDB.turnins62 or {}

    local key = ZygorClassic_Key62()
    local now = ZygorClassic_QuestSnapshot62()
    local done = ZygorClassicDB.turnins62[key] or {}

    -- TEST224: disappearance is also caused by abandon/log replacement and is
    -- not a turn-in witness.  turnins62 is now written only by the confirmed
    -- QUEST_COMPLETE -> QUEST_FINISHED event pair below.
    ZygorClassicDB.turnins62[key] = done
    ZygorClassicDB.questSnapshot62[key] = now
end

local function ZygorClassic_TurnedIn62(title)
    ZygorClassicDB = ZygorClassicDB or {}
    ZygorClassicDB.turnins62 = ZygorClassicDB.turnins62 or {}
    local key = ZygorClassic_Key62()
    local t = ZygorClassicDB.turnins62[key] or {}
    local confirmed = ZygorClassicDB.confirmedTurnins224 and
                      ZygorClassicDB.confirmedTurnins224[key] or {}
    if t[title] then return true end
    if confirmed[title] then return true end
    local wanted=ZygorClassic_NormalizeQuestTitle170(title)
    local recorded
    for recorded in pairs(t) do
        if ZygorClassic_NormalizeQuestTitle170(recorded)==wanted then return true end
    end
    for recorded in pairs(confirmed) do
        if ZygorClassic_NormalizeQuestTitle170(recorded)==wanted then return true end
    end
    return false
end

local function ZygorClassic_CleanDirective62(line)
    if type(line)~="string" then return "" end
    -- Repair the same ellipsis conversion at the directive boundary.  This
    -- also covers damaged directive prefixes such as unpack(arg)accept and
    -- keeps the player-facing step text free of the conversion artifact.
    line=string.gsub(line,"unpack%(arg%)","...")
    line=string.gsub(line,"^%.+","")
    return line
end

local function ZygorClassic_OnlyApplies62(cond)
    cond = ZygorClassic_CleanDirective62(cond)
    if string.sub(cond,1,5)=="only " then cond=string.sub(cond,6) end

    local race = UnitRace("player") or ""
    local localizedClass, classToken = UnitClass("player")
    localizedClass = localizedClass or ""
    classToken = classToken or ""

    local classes={"Warrior","Paladin","Hunter","Rogue","Priest","Shaman","Mage","Warlock","Druid"}
    local races={"Human","Dwarf","Night Elf","Gnome","Orc","Tauren","Troll","Undead"}

    local mentionsClass=false
    local mentionsRace=false
    local classOK=false
    local raceOK=false
    local i

    for i=1,table.getn(classes) do
        if string.find(cond,classes[i],1,true) then
            mentionsClass=true
            if classes[i]==localizedClass or string.upper(classes[i])==string.upper(classToken) then classOK=true end
        end
    end

    for i=1,table.getn(races) do
        if string.find(cond,races[i],1,true) then
            mentionsRace=true
            if races[i]==race then raceOK=true end
        end
    end

    if mentionsClass and not classOK then return false end
    if mentionsRace and not raceOK then return false end
    return true
end

local function ZygorClassic_FilterLines62(step)
    local src = step and step.raw or {}
    local out={}
    local i=1

    while i<=table.getn(src) do
        local line=src[i]
        local nextline=src[i+1]
        local clean=ZygorClassic_CleanDirective62(line)
        local nextclean=ZygorClassic_CleanDirective62(nextline)

        if nextline and string.sub(nextclean,1,5)=="only " then
            if ZygorClassic_OnlyApplies62(nextclean) then table.insert(out,line) end
            i=i+2
        elseif string.sub(clean,1,5)=="only " then
            i=i+1
        else
            table.insert(out,line)
            i=i+1
        end
    end
    return out
end

-- After a quest is turned in, find its turn-in step and move forward from it.
local function ZygorClassic_AdvancePastTurnin62()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return false end
    local guide=ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return false end

    local steps=guide.classic_steps or {}
    local current=ZygorClassicStepIndex or 1
    local i,j

    for i=current,table.getn(steps) do
        local lines=steps[i].raw or {}
        for j=1,table.getn(lines) do
            local title,kind=ZygorClassic_ParseQuestDirective(ZygorClassic_CleanDirective62(lines[j]))
            if title and kind=="turnin" and ZygorClassic_TurnedIn62(title) then
                ZygorClassicStepIndex=i+1
                if ZygorClassicStepIndex>table.getn(steps) then ZygorClassicStepIndex=table.getn(steps) end

                local key=ZygorClassic_Key62()
                ZygorClassicDB.smart51=ZygorClassicDB.smart51 or {}
                ZygorClassicDB.smart51[key]=ZygorClassicDB.smart51[key] or {}
                ZygorClassicDB.smart51[key].guide=ZygorClassicGuideIndex
                ZygorClassicDB.smart51[key].step=ZygorClassicStepIndex

                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Zygor Turn-in:|r "..title..
                        " -> Step "..tostring(ZygorClassicStepIndex))
                end
                return true
            end
        end
    end
    return false
end

-- Live event watcher: record disappearance BEFORE older sync logic can throw us
-- back to Step 1 because the quest is no longer in the log.
if not ZygorClassicTurninFrame62 then
    ZygorClassicTurninFrame62=CreateFrame("Frame","ZygorClassicTurninFrame62",UIParent)
    ZygorClassicTurninFrame62:RegisterEvent("PLAYER_ENTERING_WORLD")
    ZygorClassicTurninFrame62:RegisterEvent("QUEST_LOG_UPDATE")
    ZygorClassicTurninFrame62:RegisterEvent("QUEST_FINISHED")
    ZygorClassicTurninFrame62:SetScript("OnEvent",function()
        ZygorClassic_RecordTurnins62()
        if event~="PLAYER_ENTERING_WORLD" and ZygorClassic_AdvancePastTurnin62() then
            ZygorClassic_Render()
            ZygorClassic_UpdateWaypointText()
            if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
        end
    end)
end

-- Final renderer wrapper: suppress non-applicable "only ..." instructions.
if not ZygorClassic_Render62_Base then
    ZygorClassic_Render62_Base=ZygorClassic_Render
    ZygorClassic_Render=function()
        ZygorClassic_Render62_Base()

        if not ZygorClassicBody or not ZygorGuidesViewer then return end
        local guide=ZygorGuidesViewer.registeredguides and
                    ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
        if not guide or not guide.classic_steps then return end
        local step=guide.classic_steps[ZygorClassicStepIndex or 1]
        if not step then return end

        local filtered=ZygorClassic_FilterLines62(step)
        local body =
            "Guide "..tostring(ZygorClassicGuideIndex or 1).."/"..tostring(table.getn(ZygorGuidesViewer.registeredguides))..
            "\n"..tostring(guide.title or "")..
            "\nStep "..tostring(ZygorClassicStepIndex or 1).."/"..tostring(table.getn(guide.classic_steps))..
            "\n--------------------------------\n"

        local i
        for i=1,table.getn(filtered) do body=body..filtered[i].."\n" end

        local map,x,y=ZygorClassic_CurrentGoto55()
        body=body.."\nAUTO: quest tracking ON"
        body=body.."\nPlayer: "..tostring(UnitRace("player") or "?").." level "..tostring(UnitLevel("player") or "?")
        if x and y then
            body=body.."\nWaypoint: "..(map and (map.." ") or "")..tostring(x)..", "..tostring(y)
        end
        ZygorClassicBody:SetText(body)
    end
end


-- ---------------------------------------------------------------------------
-- TEST64: recover this character from the already-lost Dwarven Outfitters
-- turn-in, then keep future turn-ins from regressing.
-- ---------------------------------------------------------------------------

ZygorClassicDB = ZygorClassicDB or {}
ZygorClassicDB.recovery64 = ZygorClassicDB.recovery64 or {}

local function ZygorClassic_QuestInLog64(title)
    local i
    for i=1,GetNumQuestLogEntries() do
        local qtitle,level,tag,isHeader=GetQuestLogTitle(i)
        if qtitle and not isHeader and qtitle==title then return true end
    end
    return false
end

local function ZygorClassic_Recover64()
    ZygorClassicDB = ZygorClassicDB or {}
    ZygorClassicDB.recovery64 = ZygorClassicDB.recovery64 or {}
    ZygorClassicDB.turnins62 = ZygorClassicDB.turnins62 or {}
    ZygorClassicDB.smart51 = ZygorClassicDB.smart51 or {}

    local key=ZygorClassic_Key62()
    if ZygorClassicDB.recovery64[key] then return false end
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return false end

    local guide=ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return false end

    -- This recovery is intentionally narrow: the test character is level 2,
    -- Dwarf guide, Dwarven Outfitters is absent because it was turned in under
    -- TEST61 before turn-in history existed. Move to the step immediately after
    -- its turn-in block once, then future progress is tracked normally.
    if UnitRace("player")=="Dwarf" and (UnitLevel("player") or 1)>=2 and
       not ZygorClassic_QuestInLog64("Dwarven Outfitters") then

        local steps=guide.classic_steps or {}
        local i,j
        for i=1,table.getn(steps) do
            local lines=steps[i].raw or {}
            for j=1,table.getn(lines) do
                local title,kind=ZygorClassic_ParseQuestDirective(ZygorClassic_CleanDirective62(lines[j]))
                if title=="Dwarven Outfitters" and kind=="turnin" then
                    -- Mark it as known turned-in and advance one step.
                    ZygorClassicDB.turnins62=ZygorClassicDB.turnins62 or {}
                    ZygorClassicDB.turnins62[key]=ZygorClassicDB.turnins62[key] or {}
                    ZygorClassicDB.turnins62[key][title]=true

                    ZygorClassicStepIndex=i+1
                    if ZygorClassicStepIndex>table.getn(steps) then ZygorClassicStepIndex=table.getn(steps) end

                    ZygorClassicDB.smart51=ZygorClassicDB.smart51 or {}
                    ZygorClassicDB.smart51[key]=ZygorClassicDB.smart51[key] or {}
                    ZygorClassicDB.smart51[key].guide=ZygorClassicGuideIndex
                    ZygorClassicDB.smart51[key].step=ZygorClassicStepIndex
                    ZygorClassicDB.recovery64[key]=true

                    if DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Zygor TEST64 recovery:|r Dwarven Outfitters already turned in -> Step "..tostring(ZygorClassicStepIndex))
                    end
                    return true
                end
            end
        end
    end

    ZygorClassicDB.recovery64 = ZygorClassicDB.recovery64 or {}
    ZygorClassicDB.recovery64[key]=true
    return false
end

-- Run recovery once after the viewer is available.
if not ZygorClassicRecoveryFrame64 then
    ZygorClassicRecoveryFrame64=CreateFrame("Frame","ZygorClassicRecoveryFrame64",UIParent)
    ZygorClassicRecoveryFrame64.elapsed=0
    ZygorClassicRecoveryFrame64:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.5 then return end
        this.elapsed=0
        if ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and table.getn(ZygorGuidesViewer.registeredguides)>=115 then
            if ZygorClassic_Recover64() then
                ZygorClassic_Render()
                ZygorClassic_UpdateWaypointText()
                if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
            end
            this:Hide()
        end
    end)
end


-- ---------------------------------------------------------------------------
-- TEST67: class-branch aware progression.
-- Steps like Dwarf 4-8 are alternatives, not sequential steps. Select the step
-- whose "only Race Class" condition matches the current character.
-- ---------------------------------------------------------------------------

local function ZygorClassic_StepOnlyCondition67(step)
    if not step or not step.raw then return nil end
    local i
    for i=1,table.getn(step.raw) do
        local clean=ZygorClassic_CleanDirective62(step.raw[i])
        if string.sub(clean,1,5)=="only " then return clean end
    end
    return nil
end

local function ZygorClassic_StepApplies67(step)
    -- TEST233: the offline compiler checks every quest reference against the
    -- CMaNGOS 1.12 database and emits exact guide/step exclusions.  Runtime
    -- applicability consumes that generated result; it never guesses from ID
    -- ranges and never relies on IDs surviving the display parser.
    if step and ZygorClassicVanillaUnavailableSteps233 then
        local guideSteps=ZygorClassicVanillaUnavailableSteps233[step.classic_guide_title]
        if guideSteps and guideSteps[step.classic_step_index] then return false end
    end
    local cond=ZygorClassic_StepOnlyCondition67(step)
    if not cond then return true end
    return ZygorClassic_OnlyApplies62(cond)
end

local function ZygorClassic_FindApplicableSibling67(guide, around)
    local steps=guide.classic_steps or {}
    local count=table.getn(steps)
    local start=around-6
    local finish=around+6
    if start<1 then start=1 end
    if finish>count then finish=count end

    local i
    for i=start,finish do
        if ZygorClassic_StepOnlyCondition67(steps[i]) and ZygorClassic_StepApplies67(steps[i]) then
            return i
        end
    end
    return nil
end

-- Override TEST62 turn-in advancement: after a turn-in, if nearby steps are a
-- class/race branch, jump to the branch that applies to THIS character.
ZygorClassic_AdvancePastTurnin62 = function()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return false end
    local guide=ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return false end

    local steps=guide.classic_steps or {}
    local current=ZygorClassicStepIndex or 1
    local i,j

    for i=1,table.getn(steps) do
        local lines=steps[i].raw or {}
        for j=1,table.getn(lines) do
            local title,kind=ZygorClassic_ParseQuestDirective(ZygorClassic_CleanDirective62(lines[j]))
            if title and kind=="turnin" and ZygorClassic_TurnedIn62(title) then
                local target=ZygorClassic_FindApplicableSibling67(guide,i)
                if not target then target=i+1 end
                if target>table.getn(steps) then target=table.getn(steps) end

                if ZygorClassicStepIndex~=target then
                    ZygorClassicStepIndex=target

                    local key=ZygorClassic_Key62()
                    ZygorClassicDB.smart51=ZygorClassicDB.smart51 or {}
                    ZygorClassicDB.smart51[key]=ZygorClassicDB.smart51[key] or {}
                    ZygorClassicDB.smart51[key].guide=ZygorClassicGuideIndex
                    ZygorClassicDB.smart51[key].step=target

                    if DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Zygor class branch:|r "..title..
                            " -> Step "..tostring(target).." for "..tostring(UnitClass("player") or "?"))
                    end
                    return true
                end
            end
        end
    end
    return false
end

-- One-time correction from TEST65/66: place this Dwarf on the correct class
-- branch for the already-turned-in Dwarven Outfitters.
ZygorClassicDB.branch67=ZygorClassicDB.branch67 or {}
if not ZygorClassicBranch67Frame then
    ZygorClassicBranch67Frame=CreateFrame("Frame","ZygorClassicBranch67Frame",UIParent)
    ZygorClassicBranch67Frame.elapsed=0
    ZygorClassicBranch67Frame:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.5 then return end
        this.elapsed=0

        if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides or
           table.getn(ZygorGuidesViewer.registeredguides)<1 then return end

        ZygorClassicDB.branch67=ZygorClassicDB.branch67 or {}
        local key=ZygorClassic_Key62()

        if not ZygorClassicDB.branch67[key] and ZygorClassic_TurnedIn62("Dwarven Outfitters") then
            local guide=ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
            if guide and ZygorClassic_EnsureParsed(guide) then
                local target=ZygorClassic_FindApplicableSibling67(guide,ZygorClassicStepIndex or 1)
                if target then
                    ZygorClassicStepIndex=target
                    ZygorClassicDB.smart51=ZygorClassicDB.smart51 or {}
                    ZygorClassicDB.smart51[key]=ZygorClassicDB.smart51[key] or {}
                    ZygorClassicDB.smart51[key].guide=ZygorClassicGuideIndex
                    ZygorClassicDB.smart51[key].step=target
                    ZygorClassicDB.branch67[key]=true
                    ZygorClassic_Render()
                    ZygorClassic_UpdateWaypointText()
                    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
                end
            end
        end
        this:Hide()
    end)
end


-- TEST68: larger native viewer + hide already-completed turn-in lines.
local function ZygorClassic_IsQuestLive227(title)
    local wanted=ZygorClassic_NormalizeQuestTitle170 and
                 ZygorClassic_NormalizeQuestTitle170(title) or tostring(title or "")
    local live=ZygorClassic_QuestSnapshot62 and ZygorClassic_QuestSnapshot62() or {}
    local liveTitle
    for liveTitle in pairs(live) do
        local key=ZygorClassic_NormalizeQuestTitle170 and
                  ZygorClassic_NormalizeQuestTitle170(liveTitle) or tostring(liveTitle or "")
        if key==wanted then return true end
    end
    return false
end

local function ZygorClassic_FilterCompleted68(lines)
    local out={}
    local i
    for i=1,table.getn(lines or {}) do
        local line=lines[i]
        local clean=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(line) or line
        local title,kind=nil,nil
        if ZygorClassic_ParseQuestDirective then
            title,kind=ZygorClassic_ParseQuestDirective(clean)
        end
        -- TEST227: a live quest is authoritative. Stale historical evidence
        -- must never hide its ready turn-in instruction from a multi-action
        -- turn-in/accept step.
        if not (title and kind=="turnin" and
                not ZygorClassic_IsQuestLive227(title) and
                ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title)) then
            table.insert(out,line)
        end
    end
    return out
end

-- Scale up the whole native viewer substantially.
if ZygorClassicFrame then
    ZygorClassicFrame:SetScale(1.35)
    ZygorClassicFrame:SetWidth(520)
    ZygorClassicFrame:SetHeight(390)
end
if ZygorClassicBody then
    ZygorClassicBody:SetFont("Fonts\\FRIZQT__.TTF", 15)
    ZygorClassicBody:SetWidth(480)
end
if ZygorClassicTitle then
    ZygorClassicTitle:SetFont("Fonts\\FRIZQT__.TTF", 17)
end

-- Wrap the final renderer from TEST67: remove completed turn-ins from visible text.
if not ZygorClassic_Render68_Base then
    ZygorClassic_Render68_Base=ZygorClassic_Render
    ZygorClassic_Render=function()
        ZygorClassic_Render68_Base()
        if not ZygorClassicBody or not ZygorGuidesViewer then return end
        local guide=ZygorGuidesViewer.registeredguides and ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
        if not guide or not guide.classic_steps then return end
        local step=guide.classic_steps[ZygorClassicStepIndex or 1]
        if not step then return end

        local lines=ZygorClassic_FilterLines62 and ZygorClassic_FilterLines62(step) or step.raw or {}
        lines=ZygorClassic_FilterCompleted68(lines)

        local body="Guide "..tostring(ZygorClassicGuideIndex or 1).."/"..tostring(table.getn(ZygorGuidesViewer.registeredguides))..
            "\n"..tostring(guide.title or "")..
            "\nStep "..tostring(ZygorClassicStepIndex or 1).."/"..tostring(table.getn(guide.classic_steps))..
            "\n--------------------------------\n"
        local i
        for i=1,table.getn(lines) do body=body..lines[i].."\n" end
        local map,x,y=ZygorClassic_CurrentGoto55()
        body=body.."\nAUTO: quest tracking ON"
        body=body.."\nPlayer: "..tostring(UnitRace("player") or "?").." level "..tostring(UnitLevel("player") or "?")
        if x and y then body=body.."\nWaypoint: "..(map and (map.." ") or "")..tostring(x)..", "..tostring(y) end
        ZygorClassicBody:SetText(body)
    end
end


-- ---------------------------------------------------------------------------
-- TEST72: resize the ACTUAL native viewer + its master frame.
-- Actual names from the creation block:
--   ZygorGuidesViewerFrameMaster
--   ZygorGuidesViewerFrame
--   ZygorClassicPrevGuideButton / NextGuideButton
--   ZygorClassicPrevStepButton  / NextStepButton
-- ---------------------------------------------------------------------------

if ZygorGuidesViewerFrameMaster then
    ZygorGuidesViewerFrameMaster:SetScale(1.0)
    ZygorGuidesViewerFrameMaster:SetWidth(820)
    ZygorGuidesViewerFrameMaster:SetHeight(600)
end

if ZygorGuidesViewerFrame then
    ZygorGuidesViewerFrame:SetScale(1.0)
    ZygorGuidesViewerFrame:SetWidth(820)
    ZygorGuidesViewerFrame:SetHeight(600)
end

if ZygorClassicBody and ZygorGuidesViewerFrame then
    ZygorClassicBody:ClearAllPoints()
    ZygorClassicBody:SetPoint("TOPLEFT", ZygorGuidesViewerFrame, "TOPLEFT", 18, -48)
    ZygorClassicBody:SetPoint("BOTTOMRIGHT", ZygorGuidesViewerFrame, "BOTTOMRIGHT", -18, 92)
    ZygorClassicBody:SetFont("Fonts\\FRIZQT__.TTF", 15)
    ZygorClassicBody:SetJustifyH("LEFT")
    ZygorClassicBody:SetJustifyV("TOP")
end

if ZygorClassicTitle then
    ZygorClassicTitle:SetFont("Fonts\\FRIZQT__.TTF", 17)
end

if ZygorClassicPrevGuideButton then
    ZygorClassicPrevGuideButton:ClearAllPoints()
    ZygorClassicPrevGuideButton:SetPoint("BOTTOMLEFT", ZygorGuidesViewerFrame, "BOTTOMLEFT", 20, 52)
end

if ZygorClassicNextGuideButton then
    ZygorClassicNextGuideButton:ClearAllPoints()
    ZygorClassicNextGuideButton:SetPoint("LEFT", ZygorClassicPrevGuideButton, "RIGHT", 14, 0)
end

if ZygorClassicPrevStepButton then
    ZygorClassicPrevStepButton:ClearAllPoints()
    ZygorClassicPrevStepButton:SetPoint("BOTTOMLEFT", ZygorGuidesViewerFrame, "BOTTOMLEFT", 20, 18)
end

if ZygorClassicNextStepButton then
    ZygorClassicNextStepButton:ClearAllPoints()
    ZygorClassicNextStepButton:SetPoint("LEFT", ZygorClassicPrevStepButton, "RIGHT", 14, 0)
end

-- Temporary reload button for rapid testing.
if ZygorGuidesViewerFrame and not ZygorClassicReload72 then
    ZygorClassicReload72 = CreateFrame("Button", "ZygorClassicReload72", ZygorGuidesViewerFrame, "UIPanelButtonTemplate")
    ZygorClassicReload72:SetWidth(110)
    ZygorClassicReload72:SetHeight(24)
    ZygorClassicReload72:SetPoint("BOTTOMRIGHT", ZygorGuidesViewerFrame, "BOTTOMRIGHT", -20, 18)
    ZygorClassicReload72:SetText("Reload UI")
    ZygorClassicReload72:SetScript("OnClick", function()
        ReloadUI()
    end)
    ZygorClassicReload72:Show()
end


-- ---------------------------------------------------------------------------
-- TEST73: multi-action step completion + no rewind to an already-handled branch.
--
-- Step 7 contains three quest accepts. Earlier logic only understood single
-- quest directives, so it stayed on Step 7 even after all three were accepted.
-- ---------------------------------------------------------------------------

ZygorClassicDB = ZygorClassicDB or {}
ZygorClassicDB.handledBranches73 = ZygorClassicDB.handledBranches73 or {}

local function ZygorClassic_Key73()
    if ZygorClassic_Key62 then return ZygorClassic_Key62() end
    if ZygorClassic_Key49 then return ZygorClassic_Key49() end
    return tostring(GetRealmName and GetRealmName() or "Realm") .. ":" ..
           tostring(UnitName("player") or "Unknown")
end

local function ZygorClassic_QuestState73()
    local q = {}
    local i
    for i=1,GetNumQuestLogEntries() do
        local title,level,tag,isHeader,isCollapsed,isComplete = GetQuestLogTitle(i)
        if title and not isHeader then
            q[title] = {
                complete = (isComplete==1)
            }
        end
    end
    return q
end

local function ZygorClassic_NextApplicableStep73(guide, idx)
    local steps = guide.classic_steps or {}
    local i = idx + 1
    while i <= table.getn(steps) do
        if not ZygorClassic_StepApplies67 or ZygorClassic_StepApplies67(steps[i]) then
            return i
        end
        i = i + 1
    end
    return idx
end

local function ZygorClassic_StepActionsSatisfied73(step)
    if not step or not step.raw then return false end

    local quests = ZygorClassic_QuestState73()
    local sawAction = false
    local i = 1

    while i <= table.getn(step.raw) do
        local line = step.raw[i]
        local nextline = step.raw[i+1]
        local clean = ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(line) or line
        local nextclean = ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(nextline) or nextline

        -- Skip an instruction if its immediately-following "only" condition
        -- does not apply to this character.
        local applicable = true
        if nextline and string.sub(nextclean,1,5)=="only " and ZygorClassic_OnlyApplies62 then
            applicable = ZygorClassic_OnlyApplies62(nextclean)
        end

        if applicable then
            local title,kind = nil,nil
            if ZygorClassic_ParseQuestDirective then
                title,kind = ZygorClassic_ParseQuestDirective(clean)
            end

            if title and kind=="accept" then
                sawAction = true
                -- Accepted means it must now be in the log OR already recorded
                -- as turned in/completed from earlier progress.
                local done = false
                if quests[title] then done = true end
                if ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title) then done = true end
                if not done then return false end

            elseif title and kind=="turnin" then
                sawAction = true
                if ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title) then
                    -- satisfied
                else
                    -- If still in log, turn-in is not satisfied.
                    if quests[title] then return false end
                    -- Unknown historical state: don't claim completion.
                    return false
                end
            end
        end

        if nextline and string.sub(nextclean,1,5)=="only " then
            i = i + 2
        else
            i = i + 1
        end
    end

    return sawAction
end

function ZygorClassic_AutoProgress73()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return false end
    local guide = ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return false end

    local idx = ZygorClassicStepIndex or 1
    local step = guide.classic_steps and guide.classic_steps[idx]
    if not step then return false end

    if ZygorClassic_StepActionsSatisfied73(step) then
        local target = ZygorClassic_NextApplicableStep73(guide, idx)
        if target and target ~= idx then
            ZygorClassicStepIndex = target

            local key = ZygorClassic_Key73()
            ZygorClassicDB.smart51 = ZygorClassicDB.smart51 or {}
            ZygorClassicDB.smart51[key] = ZygorClassicDB.smart51[key] or {}
            ZygorClassicDB.smart51[key].guide = ZygorClassicGuideIndex
            ZygorClassicDB.smart51[key].step = target

            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cffffcc00Zygor progress:|r Step "..tostring(idx)..
                    " complete -> Step "..tostring(target)
                )
            end
            return true
        end
    end
    return false
end

-- Replace the TEST67 turn-in branch routine with an idempotent version.
-- Once Dwarven Outfitters has already placed this Paladin on Step 7, never
-- rewind back to that branch after progressing to Step 9+.
ZygorClassic_AdvancePastTurnin62 = function()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return false end
    local guide=ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return false end

    ZygorClassicDB.handledBranches73 = ZygorClassicDB.handledBranches73 or {}
    local key = ZygorClassic_Key73()
    ZygorClassicDB.handledBranches73[key] = ZygorClassicDB.handledBranches73[key] or {}
    local handled = ZygorClassicDB.handledBranches73[key]

    local steps=guide.classic_steps or {}
    local current=ZygorClassicStepIndex or 1
    local i,j

    for i=1,table.getn(steps) do
        local lines=steps[i].raw or {}
        for j=1,table.getn(lines) do
            local title,kind=ZygorClassic_ParseQuestDirective(
                ZygorClassic_CleanDirective62(lines[j])
            )

            if title and kind=="turnin" and
               ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title) then

                local token = title
                if not handled[token] then
                    local target = ZygorClassic_FindApplicableSibling67 and
                                   ZygorClassic_FindApplicableSibling67(guide,i) or nil
                    if not target then target=i+1 end

                    -- If we're already at or beyond this resolved branch, simply
                    -- mark it handled and DO NOT rewind.
                    if current >= target then
                        handled[token] = true
                        return false
                    end

                    handled[token] = true
                    ZygorClassicStepIndex = target

                    ZygorClassicDB.smart51 = ZygorClassicDB.smart51 or {}
                    ZygorClassicDB.smart51[key] = ZygorClassicDB.smart51[key] or {}
                    ZygorClassicDB.smart51[key].guide = ZygorClassicGuideIndex
                    ZygorClassicDB.smart51[key].step = target
                    return true
                end
            end
        end
    end
    return false
end

-- Hide accept directives that are already satisfied, in addition to the
-- completed turn-ins TEST68 already hides.
local function ZygorClassic_FilterSatisfied73(lines)
    local quests = ZygorClassic_QuestState73()
    local out = {}
    local i
    for i=1,table.getn(lines or {}) do
        local line = lines[i]
        local clean = ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(line) or line
        local title,kind=nil,nil
        if ZygorClassic_ParseQuestDirective then
            title,kind=ZygorClassic_ParseQuestDirective(clean)
        end

        local hide = false
        if title and kind=="accept" and quests[title] then
            hide = true
        elseif title and kind=="turnin" and
               not ZygorClassic_IsQuestLive227(title) and
               ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title) then
            hide = true
        end

        if not hide then table.insert(out,line) end
    end
    return out
end

-- Final renderer: retain TEST72 dimensions, but show only remaining work.
if not ZygorClassic_Render73_Base then
    ZygorClassic_Render73_Base = ZygorClassic_Render
    ZygorClassic_Render = function()
        ZygorClassic_Render73_Base()

        if not ZygorClassicBody or not ZygorGuidesViewer then return end
        local guide=ZygorGuidesViewer.registeredguides and
                    ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
        if not guide or not guide.classic_steps then return end
        local step=guide.classic_steps[ZygorClassicStepIndex or 1]
        if not step then return end

        local lines = ZygorClassic_FilterLines62 and ZygorClassic_FilterLines62(step) or step.raw or {}
        lines = ZygorClassic_FilterCompleted68 and ZygorClassic_FilterCompleted68(lines) or lines
        lines = ZygorClassic_FilterSatisfied73(lines)

        local body =
            "Guide "..tostring(ZygorClassicGuideIndex or 1).."/"..tostring(table.getn(ZygorGuidesViewer.registeredguides))..
            "\n"..tostring(guide.title or "")..
            "\nStep "..tostring(ZygorClassicStepIndex or 1).."/"..tostring(table.getn(guide.classic_steps))..
            "\n--------------------------------\n"

        local i
        for i=1,table.getn(lines) do body=body..lines[i].."\n" end

        local map,x,y=ZygorClassic_CurrentGoto55()
        body=body.."\nAUTO: quest tracking ON"
        body=body.."\nPlayer: "..tostring(UnitRace("player") or "?").." level "..tostring(UnitLevel("player") or "?")
        if x and y then
            body=body.."\nWaypoint: "..(map and (map.." ") or "")..tostring(x)..", "..tostring(y)
        end
        ZygorClassicBody:SetText(body)
    end
end

-- Live progression after quest accepts/turn-ins/objective changes.
if not ZygorClassicProgress73Frame then
    ZygorClassicProgress73Frame = CreateFrame("Frame","ZygorClassicProgress73Frame",UIParent)
    ZygorClassicProgress73Frame:RegisterEvent("QUEST_LOG_UPDATE")
    ZygorClassicProgress73Frame:RegisterEvent("QUEST_ACCEPTED")
    ZygorClassicProgress73Frame:RegisterEvent("QUEST_FINISHED")
    ZygorClassicProgress73Frame:SetScript("OnEvent",function()
        if ZygorClassic_AutoProgress73() then
            ZygorClassic_Render()
            if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
        else
            ZygorClassic_Render()
        end
    end)
end

-- Silence the obsolete TEST42 waypoint chat path that reports bogus "1,14".
ZygorClassic_UpdateWaypointText = function()
    -- TEST55/arrow system owns waypoint display now.
end


-- ---------------------------------------------------------------------------
-- TEST74: earliest unresolved applicable step.
--
-- Do NOT jump to a later completed quest turn-in just because it is ready.
-- Follow guide order and choose the earliest applicable step whose work is
-- still unresolved for this character.
-- ---------------------------------------------------------------------------

local function ZygorClassic_QuestLogDetailed74()
    local q = {}
    local i
    for i=1,GetNumQuestLogEntries() do
        local title,level,tag,isHeader,isCollapsed,isComplete = GetQuestLogTitle(i)
        if title and not isHeader then
            q[title] = {
                complete = (isComplete==1),
                index = i
            }
        end
    end
    return q
end

local function ZygorClassic_StepResolved74(step, quests)
    if not step or not step.raw then return true end
    if ZygorClassic_StepApplies67 and not ZygorClassic_StepApplies67(step) then
        return true
    end

    local sawMeaningful = false
    local i = 1

    while i <= table.getn(step.raw) do
        local line = step.raw[i]
        local nextline = step.raw[i+1]
        local clean = ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(line) or line
        local nextclean = ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(nextline) or nextline

        local applicable = true
        if nextline and string.sub(nextclean,1,5)=="only " and ZygorClassic_OnlyApplies62 then
            applicable = ZygorClassic_OnlyApplies62(nextclean)
        end

        if applicable then
            local title,kind = nil,nil
            if ZygorClassic_ParseQuestDirective then
                title,kind = ZygorClassic_ParseQuestDirective(clean)
            end

            if title and kind=="accept" then
                sawMeaningful = true
                if not quests[title] and not (ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title)) then
                    return false
                end

            elseif title and kind=="turnin" then
                sawMeaningful = true
                if not (ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title)) then
                    return false
                end

            else
                -- Quest objective lines: |q ID/objective.
                local qid,obj = string.match(clean,"|q%s*(%d+)/(%d+)")
                if qid and obj then
                    sawMeaningful = true

                    -- Find the quest title in the current guide by ID.
                    local guide = ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
                    local qmap = ZygorClassic_BuildGuideQuestMap52 and ZygorClassic_BuildGuideQuestMap52(guide) or {}
                    local qtitle,data
                    for qtitle,data in pairs(qmap) do
                        if tostring(data.id)==tostring(qid) then
                            local qstate = quests[qtitle]
                            if not qstate then
                                return false
                            end
                            if qstate.complete then
                                -- Quest objective work is satisfied.
                            else
                                return false
                            end
                            break
                        end
                    end
                end
            end
        end

        if nextline and string.sub(nextclean,1,5)=="only " then
            i=i+2
        else
            i=i+1
        end
    end

    -- Non-quest travel/talk-only steps are not automatically declared resolved.
    if not sawMeaningful then return false end
    return true
end

function ZygorClassic_FindEarliestUnresolved74()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return nil end
    local guide = ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return nil end

    local quests = ZygorClassic_QuestLogDetailed74()
    local steps = guide.classic_steps or {}
    local current = ZygorClassicStepIndex or 1
    local i

    -- Start at current guide position and walk FORWARD only.
    -- Never let a later ready-to-turn-in quest skip an earlier unfinished step.
    for i=current,table.getn(steps) do
        if not ZygorClassic_StepResolved74(steps[i], quests) then
            if not ZygorClassic_StepApplies67 or ZygorClassic_StepApplies67(steps[i]) then
                return i
            end
        end
    end
    return current
end

function ZygorClassic_ReconcileProgress74(showMessage)
    local target = ZygorClassic_FindEarliestUnresolved74()
    if not target then return false end

    local current = ZygorClassicStepIndex or 1
    if target ~= current then
        ZygorClassicStepIndex = target

        local key = ZygorClassic_Key73 and ZygorClassic_Key73() or ZygorClassic_Key62()
        ZygorClassicDB.smart51 = ZygorClassicDB.smart51 or {}
        ZygorClassicDB.smart51[key] = ZygorClassicDB.smart51[key] or {}
        ZygorClassicDB.smart51[key].guide = ZygorClassicGuideIndex
        ZygorClassicDB.smart51[key].step = target

        if showMessage and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00Zygor order sync:|r Step "..tostring(current)..
                " -> Step "..tostring(target)
            )
        end
        return true
    end
    return false
end

-- Force one correction for TEST73's jump to the Paladin rune turn-in.
ZygorClassicDB.order74 = ZygorClassicDB.order74 or {}
if not ZygorClassicOrder74Frame then
    ZygorClassicOrder74Frame = CreateFrame("Frame","ZygorClassicOrder74Frame",UIParent)
    ZygorClassicOrder74Frame.elapsed = 0
    ZygorClassicOrder74Frame:SetScript("OnUpdate",function()
        this.elapsed = (this.elapsed or 0) + (arg1 or 0)
        if this.elapsed < 0.5 then return end
        this.elapsed = 0

        if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides or
           table.getn(ZygorGuidesViewer.registeredguides) < 115 then return end

        local key = ZygorClassic_Key73 and ZygorClassic_Key73() or ZygorClassic_Key62()
        ZygorClassicDB.order74 = ZygorClassicDB.order74 or {}

        if not ZygorClassicDB.order74[key] then
            -- For this already-in-progress character, rewind only as far as the
            -- first unresolved applicable step from the class branch area.
            local guide = ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
            if guide and ZygorClassic_EnsureParsed(guide) then
                if (ZygorClassicStepIndex or 1) > 9 then
                    ZygorClassicStepIndex = 9
                end
                ZygorClassic_ReconcileProgress74(true)
                ZygorClassicDB.order74[key] = true
                ZygorClassic_Render()
                if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
            end
        end
        this:Hide()
    end)
end

-- Replace TEST73's live progression with ordered reconciliation.
if ZygorClassicProgress73Frame then
    ZygorClassicProgress73Frame:SetScript("OnEvent", function()
        ZygorClassic_ReconcileProgress74(false)
        ZygorClassic_Render()
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    end)
end


-- ---------------------------------------------------------------------------
-- TEST75: ordered quest routing.
-- Disable the old "furthest matching quest" synchronizer that keeps pushing
-- this character to Step 15. Route active quests by earliest applicable guide
-- objective/turn-in instead.
-- ---------------------------------------------------------------------------

local function ZygorClassic_QuestInfo75(title)
    local i
    for i=1,GetNumQuestLogEntries() do
        local qtitle,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(i)
        if qtitle and not isHeader and qtitle==title then
            return {index=i, complete=(isComplete==1)}
        end
    end
    return nil
end

local function ZygorClassic_FindQuestObjectiveStep75(guide, title)
    if not guide or not ZygorClassic_EnsureParsed(guide) then return nil end
    local map=ZygorClassic_BuildGuideQuestMap52 and ZygorClassic_BuildGuideQuestMap52(guide) or {}
    local data=map[title]
    if not data then return nil end

    local best=nil
    local obj,steps
    for obj,steps in pairs(data.objectives or {}) do
        if steps then
            local i
            for i=1,table.getn(steps) do
                local n=steps[i]
                if (not ZygorClassic_StepApplies67) or ZygorClassic_StepApplies67(guide.classic_steps[n]) then
                    if not best or n<best then best=n end
                end
            end
        end
    end
    return best
end

function ZygorClassic_RouteActiveQuests75(showMessage)
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return false end
    local guide=ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return false end

    local qmap=ZygorClassic_BuildGuideQuestMap52 and ZygorClassic_BuildGuideQuestMap52(guide) or {}
    local best=nil
    local reason=nil
    local title,data

    for title,data in pairs(qmap) do
        local q=ZygorClassic_QuestInfo75(title)
        if q then
            local candidate=nil

            if not q.complete then
                -- Incomplete quest: objective step takes priority.
                candidate=ZygorClassic_FindQuestObjectiveStep75(guide,title)
                if not candidate and data.acceptStep then candidate=data.acceptStep+1 end
            else
                -- Complete quest: its turn-in is eligible, but guide ordering
                -- still wins against an earlier incomplete quest.
                candidate=data.turninStep
            end

            if candidate and
               ((not ZygorClassic_StepApplies67) or ZygorClassic_StepApplies67(guide.classic_steps[candidate])) and
               (not best or candidate<best) then
                best=candidate
                reason=title
            end
        end
    end

    if not best then return false end

    if ZygorClassicStepIndex~=best then
        ZygorClassicStepIndex=best
        local key=ZygorClassic_Key73 and ZygorClassic_Key73() or ZygorClassic_Key62()
        ZygorClassicDB.smart51=ZygorClassicDB.smart51 or {}
        ZygorClassicDB.smart51[key]=ZygorClassicDB.smart51[key] or {}
        ZygorClassicDB.smart51[key].guide=ZygorClassicGuideIndex
        ZygorClassicDB.smart51[key].step=best

        if showMessage and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Zygor route TEST75:|r Step "..tostring(best).." - "..tostring(reason))
        end
        return true
    end
    return false
end

-- Disable the old TEST52 synchronizer. It chose the furthest matching quest
-- and is the reason TEST74 was being overwritten back to Step 15.
ZygorClassic_SyncCurrentStep52=function(showMessage)
    return ZygorClassic_RouteActiveQuests75(showMessage)
end

-- Make the old live tracker use the ordered router too.
if ZygorClassicLive53 then
    ZygorClassicLive53:SetScript("OnEvent",function()
        if ZygorClassic_RouteActiveQuests75(false) then
            ZygorClassic_Render()
            if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
        end
    end)
end

if ZygorClassicProgress73Frame then
    ZygorClassicProgress73Frame:SetScript("OnEvent",function()
        ZygorClassic_RouteActiveQuests75(false)
        ZygorClassic_Render()
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    end)
end

-- Correct immediately after reload once all guides exist.
if not ZygorClassicRoute75Frame then
    ZygorClassicRoute75Frame=CreateFrame("Frame","ZygorClassicRoute75Frame",UIParent)
    ZygorClassicRoute75Frame.elapsed=0
    ZygorClassicRoute75Frame:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.5 then return end
        this.elapsed=0
        if ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
           table.getn(ZygorGuidesViewer.registeredguides)>=115 then
            ZygorClassic_RouteActiveQuests75(true)
            ZygorClassic_Render()
            if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
            this:Hide()
        end
    end)
end


-- ---------------------------------------------------------------------------
-- TEST76: ordered step engine.
-- Keeps TEST75's correct Step 9 routing, but after objectives/turn-ins it now
-- walks the guide FORWARD in order instead of routing only among active quests.
-- This prevents skipping future "accept" steps such as A Refugee's Quandary.
-- ---------------------------------------------------------------------------

local function ZygorClassic_QuestState76()
    local q = {}
    local i
    for i=1,GetNumQuestLogEntries() do
        local title,level,tag,isHeader,isCollapsed,isComplete = GetQuestLogTitle(i)
        if title and not isHeader then
            q[title] = { complete=(isComplete==1), index=i }
        end
    end
    return q
end

local function ZygorClassic_FindQuestTitleByID76(guide, qid)
    if not ZygorClassic_BuildGuideQuestMap52 then return nil end
    local map = ZygorClassic_BuildGuideQuestMap52(guide) or {}
    local title,data
    for title,data in pairs(map) do
        if tostring(data.id)==tostring(qid) then return title end
    end
    return nil
end

local function ZygorClassic_StepResolved76(guide, step)
    if not step then return true end

    -- Non-applicable race/class branch is skipped.
    if ZygorClassic_StepApplies67 and not ZygorClassic_StepApplies67(step) then
        return true
    end

    local quests = ZygorClassic_QuestState76()
    local sawAction = false
    local i = 1

    while i <= table.getn(step.raw or {}) do
        local line = step.raw[i]
        local nextline = step.raw[i+1]
        local clean = ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(line) or line
        local nextclean = ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(nextline) or nextline

        local applicable = true
        if nextline and string.sub(nextclean,1,5)=="only " and ZygorClassic_OnlyApplies62 then
            applicable = ZygorClassic_OnlyApplies62(nextclean)
        end

        if applicable then
            local title,kind=nil,nil
            if ZygorClassic_ParseQuestDirective then
                title,kind = ZygorClassic_ParseQuestDirective(clean)
            end

            if title and kind=="accept" then
                sawAction = true
                if not quests[title] and not (ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title)) then
                    return false
                end

            elseif title and kind=="turnin" then
                sawAction = true
                if not (ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title)) then
                    return false
                end

            else
                -- Quest objective line, e.g. |q 170/1
                local qid,obj = string.match(clean,"|q%s*(%d+)/(%d+)")
                if qid and obj then
                    sawAction = true
                    local qtitle = ZygorClassic_FindQuestTitleByID76(guide,qid)
                    if not qtitle or not quests[qtitle] or not quests[qtitle].complete then
                        return false
                    end
                end

                -- "ding N" is resolved once the character reaches N.
                local ding = string.match(clean,"^ding%s+(%d+)")
                if ding then
                    sawAction = true
                    if (UnitLevel("player") or 1) < tonumber(ding) then
                        return false
                    end
                end
            end
        end

        if nextline and string.sub(nextclean,1,5)=="only " then
            i=i+2
        else
            i=i+1
        end
    end

    -- Pure travel/talk/click step: stop here and let the player follow it.
    if not sawAction then return false end
    return true
end

function ZygorClassic_ReconcileOrdered76(showMessage)
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return false end
    local guide = ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return false end

    local steps = guide.classic_steps or {}
    local current = ZygorClassicStepIndex or 1
    local target = current

    -- Only move forward. Never rewind to an older branch/turn-in.
    while target <= table.getn(steps) and ZygorClassic_StepResolved76(guide,steps[target]) do
        target = target + 1
    end

    -- Skip any non-applicable branch steps immediately after a resolved step.
    while target <= table.getn(steps) and
          ZygorClassic_StepApplies67 and
          not ZygorClassic_StepApplies67(steps[target]) do
        target = target + 1
    end

    if target > table.getn(steps) then target = table.getn(steps) end

    if target ~= current then
        ZygorClassicStepIndex = target

        local key = ZygorClassic_Key73 and ZygorClassic_Key73() or ZygorClassic_Key62()
        ZygorClassicDB.smart51 = ZygorClassicDB.smart51 or {}
        ZygorClassicDB.smart51[key] = ZygorClassicDB.smart51[key] or {}
        ZygorClassicDB.smart51[key].guide = ZygorClassicGuideIndex
        ZygorClassicDB.smart51[key].step = target

        if showMessage and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00Zygor TEST76:|r Step "..tostring(current).." -> "..tostring(target)
            )
        end
        return true
    end
    return false
end

-- TEST75 got us correctly onto Step 9. From here onward the ordered engine owns
-- live progression.
if ZygorClassicLive53 then
    ZygorClassicLive53:SetScript("OnEvent",function()
        if ZygorClassic_RecordTurnins62 then ZygorClassic_RecordTurnins62() end
        ZygorClassic_ReconcileOrdered76(false)
        ZygorClassic_Render()
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    end)
end

if ZygorClassicProgress73Frame then
    ZygorClassicProgress73Frame:SetScript("OnEvent",function()
        if ZygorClassic_RecordTurnins62 then ZygorClassic_RecordTurnins62() end
        ZygorClassic_ReconcileOrdered76(false)
        ZygorClassic_Render()
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    end)
end

-- Extra watcher for objective completion/level-up events.
if not ZygorClassicOrdered76Frame then
    ZygorClassicOrdered76Frame=CreateFrame("Frame","ZygorClassicOrdered76Frame",UIParent)
    ZygorClassicOrdered76Frame:RegisterEvent("QUEST_LOG_UPDATE")
    ZygorClassicOrdered76Frame:RegisterEvent("QUEST_FINISHED")
    ZygorClassicOrdered76Frame:RegisterEvent("QUEST_ACCEPTED")
    ZygorClassicOrdered76Frame:RegisterEvent("PLAYER_LEVEL_UP")
    ZygorClassicOrdered76Frame:SetScript("OnEvent",function()
        if ZygorClassic_RecordTurnins62 then ZygorClassic_RecordTurnins62() end
        ZygorClassic_ReconcileOrdered76(false)
        ZygorClassic_Render()
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    end)
end

-- Stop TEST75's active-quest router from overriding ordered progression after
-- this point.
ZygorClassic_RouteActiveQuests75 = function(showMessage)
    return ZygorClassic_ReconcileOrdered76(showMessage)
end
ZygorClassic_SyncCurrentStep52 = function(showMessage)
    return ZygorClassic_ReconcileOrdered76(showMessage)
end


-- ---------------------------------------------------------------------------
-- TEST77: startup ordering fix.
-- TEST75 corrected Step 15 -> Step 9 after reload, but TEST76's startup path
-- allowed the older saved/current step (15) to survive before its ordered
-- engine took ownership. On startup, route active quests FIRST (TEST75 logic),
-- then hand progression to TEST76's forward-only engine.
-- ---------------------------------------------------------------------------

local function ZygorClassic_InitialRoute77()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return false end
    if table.getn(ZygorGuidesViewer.registeredguides) < 115 then return false end

    local guide=ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return false end

    -- Re-implement TEST75's initial route locally because TEST76 intentionally
    -- replaced ZygorClassic_RouteActiveQuests75 with the forward-only engine.
    local qmap=ZygorClassic_BuildGuideQuestMap52 and ZygorClassic_BuildGuideQuestMap52(guide) or {}
    local best=nil
    local title,data

    for title,data in pairs(qmap) do
        local q=nil
        local i
        for i=1,GetNumQuestLogEntries() do
            local qtitle,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(i)
            if qtitle and not isHeader and qtitle==title then
                q={complete=(isComplete==1)}
                break
            end
        end

        if q then
            local candidate=nil

            if not q.complete then
                -- Earliest objective step for an incomplete active quest.
                local obj,steps,j
                for obj,steps in pairs(data.objectives or {}) do
                    if steps then
                        for j=1,table.getn(steps) do
                            local n=steps[j]
                            if ((not ZygorClassic_StepApplies67) or
                                ZygorClassic_StepApplies67(guide.classic_steps[n])) and
                               (not candidate or n<candidate) then
                                candidate=n
                            end
                        end
                    end
                end
                if not candidate and data.acceptStep then candidate=data.acceptStep+1 end
            else
                candidate=data.turninStep
            end

            if candidate and
               ((not ZygorClassic_StepApplies67) or
                ZygorClassic_StepApplies67(guide.classic_steps[candidate])) and
               (not best or candidate<best) then
                best=candidate
            end
        end
    end

    if best and ZygorClassicStepIndex~=best then
        ZygorClassicStepIndex=best

        local key=ZygorClassic_Key73 and ZygorClassic_Key73() or ZygorClassic_Key62()
        ZygorClassicDB.smart51=ZygorClassicDB.smart51 or {}
        ZygorClassicDB.smart51[key]=ZygorClassicDB.smart51[key] or {}
        ZygorClassicDB.smart51[key].guide=ZygorClassicGuideIndex
        ZygorClassicDB.smart51[key].step=best

        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Zygor TEST77 initial route:|r Step "..tostring(best))
        end
        return true
    end
    return false
end

-- Run after all older startup/recovery frames have had time to settle.
if not ZygorClassicStartup77Frame then
    ZygorClassicStartup77Frame=CreateFrame("Frame","ZygorClassicStartup77Frame",UIParent)
    ZygorClassicStartup77Frame.elapsed=0
    ZygorClassicStartup77Frame:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<1.0 then return end
        this.elapsed=0

        if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides or
           table.getn(ZygorGuidesViewer.registeredguides)<1 then return end

        ZygorClassic_InitialRoute77()
        ZygorClassic_Render()
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
        this:Hide()
    end)
end


-- ---------------------------------------------------------------------------
-- TEST78: objective-level progress, not whole-quest-complete guessing.
-- TEST76 treated every |q objective line as unresolved until the entire quest
-- was complete. TEST78 reads GetQuestLogLeaderBoard() for the exact objective.
-- ---------------------------------------------------------------------------

local function ZygorClassic_QuestObjectiveState78(title, objective)
    local i
    for i=1,GetNumQuestLogEntries() do
        local qtitle,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(i)
        if qtitle and not isHeader and qtitle==title then
            if isComplete==1 then return true end
            local n=GetNumQuestLeaderBoards and (GetNumQuestLeaderBoards(i) or 0) or 0
            local o
            for o=1,n do
                local text,otype,finished=GetQuestLogLeaderBoard(o,i)
                if o==tonumber(objective) then
                    return (finished==1 or finished==true)
                end
            end
            return false
        end
    end
    return false
end

local function ZygorClassic_StepResolved78(guide,step)
    if not step then return true end
    if ZygorClassic_StepApplies67 and not ZygorClassic_StepApplies67(step) then return true end

    local quests=ZygorClassic_QuestState76 and ZygorClassic_QuestState76() or {}
    local saw=false
    local i=1

    while i<=table.getn(step.raw or {}) do
        local line=step.raw[i]
        local nextline=step.raw[i+1]
        local clean=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(line) or line
        local nextclean=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(nextline) or nextline

        local applicable=true
        if nextline and string.sub(nextclean,1,5)=="only " and ZygorClassic_OnlyApplies62 then
            applicable=ZygorClassic_OnlyApplies62(nextclean)
        end

        if applicable then
            local title,kind=nil,nil
            if ZygorClassic_ParseQuestDirective then title,kind=ZygorClassic_ParseQuestDirective(clean) end

            if title and kind=="accept" then
                saw=true
                if not quests[title] and not (ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title)) then
                    return false
                end
            elseif title and kind=="turnin" then
                saw=true
                if not (ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title)) then
                    return false
                end
            else
                local qid,obj=string.match(clean,"|q%s*(%d+)/(%d+)")
                if qid and obj then
                    saw=true
                    local qtitle=ZygorClassic_FindQuestTitleByID76 and ZygorClassic_FindQuestTitleByID76(guide,qid)
                    if not qtitle or not ZygorClassic_QuestObjectiveState78(qtitle,obj) then
                        return false
                    end
                end

                local ding=string.match(clean,"^ding%s+(%d+)")
                if ding then
                    saw=true
                    if (UnitLevel("player") or 1)<tonumber(ding) then return false end
                end
            end
        end

        if nextline and string.sub(nextclean,1,5)=="only " then i=i+2 else i=i+1 end
    end

    if not saw then return false end
    return true
end

-- Replace TEST76 resolver with exact-objective resolver.
ZygorClassic_StepResolved76 = ZygorClassic_StepResolved78

-- Reconcile immediately and on the existing event frames.
if ZygorClassicLive53 then
    ZygorClassicLive53:SetScript("OnEvent",function()
        if ZygorClassic_RecordTurnins62 then ZygorClassic_RecordTurnins62() end
        ZygorClassic_ReconcileOrdered76(false)
        ZygorClassic_Render()
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    end)
end

if ZygorClassicProgress73Frame then
    ZygorClassicProgress73Frame:SetScript("OnEvent",function()
        if ZygorClassic_RecordTurnins62 then ZygorClassic_RecordTurnins62() end
        ZygorClassic_ReconcileOrdered76(false)
        ZygorClassic_Render()
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    end)
end

if ZygorClassicOrdered76Frame then
    ZygorClassicOrdered76Frame:SetScript("OnEvent",function()
        if ZygorClassic_RecordTurnins62 then ZygorClassic_RecordTurnins62() end
        ZygorClassic_ReconcileOrdered76(false)
        ZygorClassic_Render()
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    end)
end

-- Startup correction remains TEST77's responsibility; once at Step 9,
-- TEST78 owns exact objective advancement.


-- TEST79: final startup owner.
-- TEST77 correctly routes to Step 9, then an older delayed startup frame runs
-- afterward and overwrites it back to Step 15. Reassert the ordered initial
-- route after ALL legacy delayed startup frames have fired, then keep TEST78
-- objective progression as the live owner.

if not ZygorClassicStartup79Frame then
    ZygorClassicStartup79Frame=CreateFrame("Frame","ZygorClassicStartup79Frame",UIParent)
    ZygorClassicStartup79Frame.elapsed=0
    ZygorClassicStartup79Frame:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<2.5 then return end
        this.elapsed=0

        if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides or
           table.getn(ZygorGuidesViewer.registeredguides)<1 then return end

        if ZygorClassic_InitialRoute77 then
            ZygorClassic_InitialRoute77()
        end

        ZygorClassic_Render()
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end

        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Zygor TEST79 startup finalized:|r Step "..tostring(ZygorClassicStepIndex or "?"))
        end
        this:Hide()
    end)
end

-- Once TEST79 has loaded, legacy one-shot recovery/startup frames must not be
-- allowed to rewrite progression later in the session.
local legacy79={
    ZygorClassicNewChar54,
    ZygorClassicRecoveryFrame64,
    ZygorClassicBranch67Frame,
    ZygorClassicOrder74Frame,
    ZygorClassicRoute75Frame,
    ZygorClassicStartup77Frame
}
local i
for i=1,table.getn(legacy79) do
    if legacy79[i] and legacy79[i]~=ZygorClassicStartup79Frame then
        legacy79[i]:Hide()
        legacy79[i]:SetScript("OnUpdate",nil)
    end
end


-- TEST80: render/state lock.
-- Chat proves TEST79 leaves ZygorClassicStepIndex at Step 9, but the viewer and
-- arrow are still rendering Step 15 afterward. An older render wrapper is
-- selecting/rendering independently of the authoritative step index.
-- Make one final renderer own BOTH visible guide text and waypoint state.

local function ZygorClassic_FinalRender80()
    if not ZygorClassicBody or not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return end
    local guide=ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return end

    local steps=guide.classic_steps or {}
    local idx=ZygorClassicStepIndex or 1
    if idx<1 then idx=1 end
    if idx>table.getn(steps) then idx=table.getn(steps) end
    ZygorClassicStepIndex=idx

    local step=steps[idx]
    local lines=ZygorClassic_FilterLines62 and ZygorClassic_FilterLines62(step) or step.raw or {}
    lines=ZygorClassic_FilterCompleted68 and ZygorClassic_FilterCompleted68(lines) or lines
    lines=ZygorClassic_FilterSatisfied73 and ZygorClassic_FilterSatisfied73(lines) or lines

    local body=
        "Guide "..tostring(ZygorClassicGuideIndex or 1).."/"..tostring(table.getn(ZygorGuidesViewer.registeredguides))..
        "\n"..tostring(guide.title or "")..
        "\nStep "..tostring(idx).."/"..tostring(table.getn(steps))..
        "\n--------------------------------\n"

    local i
    for i=1,table.getn(lines) do body=body..lines[i].."\n" end

    local map,x,y=ZygorClassic_CurrentGoto55()
    body=body.."\nAUTO: quest tracking ON"
    body=body.."\nPlayer: "..tostring(UnitRace("player") or "?").." level "..tostring(UnitLevel("player") or "?")
    if x and y then
        body=body.."\nWaypoint: "..(map and (map.." ") or "")..tostring(x)..", "..tostring(y)
    end

    ZygorClassicBody:SetText(body)

    -- Keep original core bookkeeping aligned with our authoritative state.
    ZygorGuidesViewer.CurrentGuide=guide
    ZygorGuidesViewer.CurrentGuideName=guide.title
    ZygorGuidesViewer.CurrentStepNum=idx
end

-- Final override: no older wrapper may reinterpret the step during rendering.
ZygorClassic_Render = ZygorClassic_FinalRender80

-- Ensure every live progression path renders through TEST80.
local function ZygorClassic_Update80()
    if ZygorClassic_RecordTurnins62 then ZygorClassic_RecordTurnins62() end
    if ZygorClassic_ReconcileOrdered76 then ZygorClassic_ReconcileOrdered76(false) end
    ZygorClassic_FinalRender80()
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
end

if ZygorClassicLive53 then ZygorClassicLive53:SetScript("OnEvent",ZygorClassic_Update80) end
if ZygorClassicProgress73Frame then ZygorClassicProgress73Frame:SetScript("OnEvent",ZygorClassic_Update80) end
if ZygorClassicOrdered76Frame then ZygorClassicOrdered76Frame:SetScript("OnEvent",ZygorClassic_Update80) end

-- Finalize after TEST79 startup routing and immediately render that exact state.
if not ZygorClassicRender80Frame then
    ZygorClassicRender80Frame=CreateFrame("Frame","ZygorClassicRender80Frame",UIParent)
    ZygorClassicRender80Frame.elapsed=0
    ZygorClassicRender80Frame:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<3.0 then return end
        this.elapsed=0
        if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides or
           table.getn(ZygorGuidesViewer.registeredguides)<1 then return end

        if ZygorClassic_InitialRoute77 then ZygorClassic_InitialRoute77() end
        ZygorClassic_FinalRender80()
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end

        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Zygor TEST80 render locked:|r Step "..tostring(ZygorClassicStepIndex or "?"))
        end
        this:Hide()
    end)
end


-- TEST81: single state renderer.
-- TEST80 proved ZygorClassicStepIndex == 9 while visible text remained Step 15.
-- The remaining cause is later legacy code directly writing ZygorClassicBody.
-- TEST81 refreshes the visible body from authoritative state after all legacy
-- event handlers have run, and arrow coordinates are parsed from that same step.

local function ZygorClassic_GotoForStep81(step)
    if not step or not step.raw then return nil end
    local i
    for i=1,table.getn(step.raw) do
        local map,x,y=ZygorClassic_ParseGoto55(step.raw[i])
        if x and y then return map,x,y end
    end
    return nil
end

-- TEST241: source lines contain pipe-delimited routing metadata that the
-- backport needs internally but players should not see in the guide body.
-- Also expand the terse legacy action verbs without changing step semantics.
local function ZygorClassic_PresentLine241(line)
    line=tostring(line or "")
    line=string.gsub(line,"|.*$","")
    line=string.gsub(line,"^%s+","")
    line=string.gsub(line,"%s+$","")
    local startPos,endPos,value=string.find(line,"^talk%s+(.+)$")
    if value then return "Talk to "..value end
    startPos,endPos,value=string.find(line,"^fpath%s+(.+)$")
    if value then return "Learn the "..value.." flight path" end
    startPos,endPos,value=string.find(line,"^home%s+(.+)$")
    if value then return "Make "..value.." your home" end
    startPos,endPos,value=string.find(line,"^accept%s+(.+)$")
    if value then return "Accept "..value end
    startPos,endPos,value=string.find(line,"^turnin%s+(.+)$")
    if value then return "Turn in "..value end
    return line
end

local function ZygorClassic_RenderAuthoritative81()
    if not ZygorClassicBody or not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return end
    local guideIndex,idx=ZygorClassicGuideIndex or 1,ZygorClassicStepIndex or 1
    if ZygorClassic_AuthoritativePosition289 then
        guideIndex,idx=ZygorClassic_AuthoritativePosition289()
    end
    local guide=ZygorGuidesViewer.registeredguides[guideIndex]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return end
    local steps=guide.classic_steps or {}
    if idx<1 then idx=1 end
    if idx>table.getn(steps) then idx=table.getn(steps) end
    local step=steps[idx]
    if not step then return end

    local lines=ZygorClassic_FilterLines62 and ZygorClassic_FilterLines62(step) or step.raw or {}
    lines=ZygorClassic_FilterCompleted68 and ZygorClassic_FilterCompleted68(lines) or lines
    lines=ZygorClassic_FilterSatisfied73 and ZygorClassic_FilterSatisfied73(lines) or lines

    local body="Guide "..tostring(ZygorClassicGuideIndex or 1).."/"..tostring(table.getn(ZygorGuidesViewer.registeredguides))..
        "\n"..tostring(guide.title or "")..
        "\nStep "..tostring(idx).."/"..tostring(table.getn(steps))..
        "\n--------------------------------\n"
    local i
    for i=1,table.getn(lines) do
        body=body..ZygorClassic_PresentLine241(lines[i]).."\n"
    end

    local map,x,y=ZygorClassic_GotoForStep81(step)
    body=body.."\nAUTO: quest tracking ON"
    body=body.."\nPlayer: "..tostring(UnitRace("player") or "?").." level "..tostring(UnitLevel("player") or "?")
    if x and y then body=body.."\nWaypoint: "..(map and (map.." ") or "")..tostring(x)..", "..tostring(y) end
    ZygorClassicBody:SetText(body)

    -- Do not drive ZygorClassicArrow55 here.  This renderer uses the filtered
    -- step parser, which can briefly return no coordinates during cold-load
    -- reconciliation.  It used to hide the valid navigation box every 0.1s.
    -- ZygorClassic_UpdateArrow55 is now its sole visibility owner and reads
    -- the same stable current-route source used by the native pointer.
end

-- Authoritative visible refresh runs after legacy writers every frame, but only
-- actually rewrites the text when the authoritative step or displayed step differ.
if not ZygorClassicVisible81Frame then
    ZygorClassicVisible81Frame=CreateFrame("Frame","ZygorClassicVisible81Frame",UIParent)
    ZygorClassicVisible81Frame.elapsed=0
    ZygorClassicVisible81Frame:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.10 then return end
        this.elapsed=0
        if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides or
           table.getn(ZygorGuidesViewer.registeredguides)<1 then return end
        ZygorClassic_RenderAuthoritative81()
    end)
end

-- All explicit renders also use the same renderer.
ZygorClassic_Render=ZygorClassic_RenderAuthoritative81


-- TEST82: in-window diagnostics; stop relying on noisy chat.
ZygorClassicDebug82 = ZygorClassicDebug82 or {
    route="-",
    event="-",
    quest="-",
    error="-"
}

local function ZygorClassic_DebugSet82(k,v)
    ZygorClassicDebug82=ZygorClassicDebug82 or {}
    ZygorClassicDebug82[k]=tostring(v or "-")
end

-- Dedicated debug/status text in the viewer.
if ZygorGuidesViewerFrame and not ZygorClassicDebugText82 then
    ZygorClassicDebugText82=ZygorGuidesViewerFrame:CreateFontString("ZygorClassicDebugText82","OVERLAY","GameFontHighlightSmall")
    ZygorClassicDebugText82:SetPoint("TOPRIGHT",ZygorGuidesViewerFrame,"TOPRIGHT",-28,-58)
    ZygorClassicDebugText82:SetWidth(360)
    ZygorClassicDebugText82:SetJustifyH("LEFT")
    ZygorClassicDebugText82:SetJustifyV("TOP")
    ZygorClassicDebugText82:SetFont("Fonts\\FRIZQT__.TTF",12)
end

local function ZygorClassic_UpdateDebug82()
    if not ZygorClassicDebugText82 then return end
    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local step=ZygorClassicStepIndex or 1
    local map,x,y=nil,nil,nil
    if guide and guide.classic_steps and guide.classic_steps[step] then
        map,x,y=ZygorClassic_GotoForStep81(guide.classic_steps[step])
    end

    local txt="TEST82 DEBUG\n"..
        "Authoritative step: "..tostring(step).."\n"..
        "Guide: "..tostring(ZygorClassicGuideIndex or "?").."/"..tostring(ZygorClassic_GuideCount and ZygorClassic_GuideCount() or "?").."\n"..
        "Last route: "..tostring(ZygorClassicDebug82.route or "-").."\n"..
        "Last event: "..tostring(ZygorClassicDebug82.event or "-").."\n"..
        "Quest: "..tostring(ZygorClassicDebug82.quest or "-").."\n"..
        "Waypoint: "..tostring(map or "").." "..tostring(x or "-")..","..tostring(y or "-").."\n"..
        "Error: "..tostring(ZygorClassicDebug82.error or "none")
    ZygorClassicDebugText82:SetText(txt)
end

-- Wrap ordered reconciliation to record route changes in-window.
local ZygorClassic_ReconcileOrdered76_Base82=ZygorClassic_ReconcileOrdered76
ZygorClassic_ReconcileOrdered76=function(showMessage)
    local before=ZygorClassicStepIndex or 1
    local changed=ZygorClassic_ReconcileOrdered76_Base82(false)
    local after=ZygorClassicStepIndex or 1
    if changed then
        ZygorClassic_DebugSet82("route",tostring(before).." -> "..tostring(after))
    else
        ZygorClassic_DebugSet82("route","stay "..tostring(after))
    end
    return changed
end

-- Final event owner with useful event diagnostics.
local function ZygorClassic_Update82()
    ZygorClassic_DebugSet82("event",event or "update")
    if ZygorClassic_RecordTurnins62 then ZygorClassic_RecordTurnins62() end
    ZygorClassic_ReconcileOrdered76(false)
    ZygorClassic_Render()
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    ZygorClassic_UpdateDebug82()
end

if ZygorClassicLive53 then ZygorClassicLive53:SetScript("OnEvent",ZygorClassic_Update82) end
if ZygorClassicProgress73Frame then ZygorClassicProgress73Frame:SetScript("OnEvent",ZygorClassic_Update82) end
if ZygorClassicOrdered76Frame then ZygorClassicOrdered76Frame:SetScript("OnEvent",ZygorClassic_Update82) end

-- Update debug panel after authoritative renderer refresh.
if ZygorClassicVisible81Frame then
    ZygorClassicVisible81Frame:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.10 then return end
        this.elapsed=0
        if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides or
           table.getn(ZygorGuidesViewer.registeredguides)<1 then return end
        ZygorClassic_RenderAuthoritative81()
        ZygorClassic_UpdateDebug82()
    end)
end


-- ---------------------------------------------------------------------------
-- TEST83: quiet chat + live route lock.
-- 1) Suppress Zygor test/debug spam in chat; keep diagnostics in-window.
-- 2) On every quest-log event, re-evaluate the earliest active quest route
--    before the ordered engine can be overwritten by stale step state.
-- ---------------------------------------------------------------------------

-- Quiet only Zygor-generated debug/status chat. Do NOT suppress normal chat.
if DEFAULT_CHAT_FRAME and not ZygorClassicOriginalAddMessage83 then
    ZygorClassicOriginalAddMessage83 = DEFAULT_CHAT_FRAME.AddMessage
    DEFAULT_CHAT_FRAME.AddMessage = function(self, msg, r, g, b, id)
        local t = tostring(msg or "")
        if string.find(t, "Zygor ", 1, true) == 1 or
           string.find(t, "|cffffcc00Zygor", 1, true) == 1 or
           string.find(t, "Zygor:", 1, true) == 1 then
            -- Capture last suppressed line in the in-window panel.
            if ZygorClassicDebug82 then
                ZygorClassicDebug82.event = t
            end
            return
        end
        return ZygorClassicOriginalAddMessage83(self, msg, r, g, b, id)
    end
end

local function ZygorClassic_InitialRoute83()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return false end
    local guide = ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return false end

    local qmap = ZygorClassic_BuildGuideQuestMap52 and ZygorClassic_BuildGuideQuestMap52(guide) or {}
    local best = nil
    local reason = "-"
    local title,data

    for title,data in pairs(qmap) do
        local q = nil
        local i
        for i=1,GetNumQuestLogEntries() do
            local qtitle,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(i)
            if qtitle and not isHeader and qtitle==title then
                q={complete=(isComplete==1)}
                break
            end
        end

        if q then
            local candidate=nil

            if not q.complete then
                -- Incomplete active quest: earliest objective step wins.
                local obj,steps,j
                for obj,steps in pairs(data.objectives or {}) do
                    if steps then
                        for j=1,table.getn(steps) do
                            local n=steps[j]
                            if ((not ZygorClassic_StepApplies67) or
                                ZygorClassic_StepApplies67(guide.classic_steps[n])) and
                               (not candidate or n<candidate) then
                                candidate=n
                            end
                        end
                    end
                end
                if not candidate and data.acceptStep then candidate=data.acceptStep+1 end
            else
                -- Complete active quest: turn-in is eligible.
                candidate=data.turninStep
            end

            if candidate and
               ((not ZygorClassic_StepApplies67) or
                ZygorClassic_StepApplies67(guide.classic_steps[candidate])) and
               (not best or candidate<best) then
                best=candidate
                reason=title
            end
        end
    end

    if best then
        local before=ZygorClassicStepIndex or 1
        ZygorClassicStepIndex=best
        if ZygorClassicDebug82 then
            ZygorClassicDebug82.route=tostring(before).." -> "..tostring(best)
            ZygorClassicDebug82.quest=reason
        end

        local key=ZygorClassic_Key73 and ZygorClassic_Key73() or ZygorClassic_Key62()
        ZygorClassicDB.smart51=ZygorClassicDB.smart51 or {}
        ZygorClassicDB.smart51[key]=ZygorClassicDB.smart51[key] or {}
        ZygorClassicDB.smart51[key].guide=ZygorClassicGuideIndex
        ZygorClassicDB.smart51[key].step=best
        return before~=best
    end
    return false
end

-- One event owner: route first, then render authoritative state.
local function ZygorClassic_Update83()
    local ev=event or "update"
    if ZygorClassicDebug82 then ZygorClassicDebug82.event=ev end

    if ZygorClassic_RecordTurnins62 then ZygorClassic_RecordTurnins62() end
    ZygorClassic_InitialRoute83()

    if ZygorClassic_Render then ZygorClassic_Render() end
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
end

if ZygorClassicLive53 then ZygorClassicLive53:SetScript("OnEvent",ZygorClassic_Update83) end
if ZygorClassicProgress73Frame then ZygorClassicProgress73Frame:SetScript("OnEvent",ZygorClassic_Update83) end
if ZygorClassicOrdered76Frame then ZygorClassicOrdered76Frame:SetScript("OnEvent",ZygorClassic_Update83) end

-- Keep the visible renderer authoritative and update diagnostics.
if ZygorClassicVisible81Frame then
    ZygorClassicVisible81Frame:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.10 then return end
        this.elapsed=0
        if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides or
           table.getn(ZygorGuidesViewer.registeredguides)<1 then return end
        ZygorClassic_RenderAuthoritative81()
        if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
    end)
end

-- Reassert correct route once after reload, after all startup writers.
if not ZygorClassicRouteLock83Frame then
    ZygorClassicRouteLock83Frame=CreateFrame("Frame","ZygorClassicRouteLock83Frame",UIParent)
    ZygorClassicRouteLock83Frame.elapsed=0
    ZygorClassicRouteLock83Frame:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<3.2 then return end
        this.elapsed=0
        if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides or
           table.getn(ZygorGuidesViewer.registeredguides)<1 then return end

        ZygorClassic_InitialRoute83()
        ZygorClassic_RenderAuthoritative81()
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
        if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
        this:Hide()
    end)
end


-- TEST84: show exact live quest objective counters in-window and advance when
-- every objective on the current guide step is finished.

local function ZygorClassic_ObjectiveDebug84()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return "-" end
    local guide=ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return "-" end
    local step=guide.classic_steps and guide.classic_steps[ZygorClassicStepIndex or 1]
    if not step then return "-" end

    local out=""
    local i
    for i=1,table.getn(step.raw or {}) do
        local clean=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(step.raw[i]) or step.raw[i]
        local qid,obj=string.match(clean,"|q%s*(%d+)/(%d+)")
        if qid and obj then
            local title=ZygorClassic_FindQuestTitleByID76 and ZygorClassic_FindQuestTitleByID76(guide,qid)
            if title then
                local qi
                for qi=1,GetNumQuestLogEntries() do
                    local qt,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(qi)
                    if qt and not isHeader and qt==title then
                        local text,otype,finished=GetQuestLogLeaderBoard(tonumber(obj),qi)
                        out=out..tostring(obj)..": "..tostring(text or "?")..
                            " ["..((finished==1 or finished==true) and "DONE" or "TODO").."]\n"
                        break
                    end
                end
            end
        end
    end
    if out=="" then out="-" end
    return out
end

-- Extend the existing debug panel with objective state.
local ZygorClassic_UpdateDebug82_Base84=ZygorClassic_UpdateDebug82
ZygorClassic_UpdateDebug82=function()
    if ZygorClassic_UpdateDebug82_Base84 then ZygorClassic_UpdateDebug82_Base84() end
    if not ZygorClassicDebugText82 then return end

    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local step=ZygorClassicStepIndex or 1
    local map,x,y=nil,nil,nil
    if guide and guide.classic_steps and guide.classic_steps[step] then
        map,x,y=ZygorClassic_GotoForStep81(guide.classic_steps[step])
    end

    local txt="TEST84 DEBUG\n"..
        "Authoritative step: "..tostring(step).."\n"..
        "Guide: "..tostring(ZygorClassicGuideIndex or "?").."/"..tostring(ZygorClassic_GuideCount and ZygorClassic_GuideCount() or "?").."\n"..
        "Last route: "..tostring(ZygorClassicDebug82.route or "-").."\n"..
        "Last event: "..tostring(ZygorClassicDebug82.event or "-").."\n"..
        "Quest: "..tostring(ZygorClassicDebug82.quest or "-").."\n"..
        "Waypoint: "..tostring(map or "").." "..tostring(x or "-")..","..tostring(y or "-").."\n"..
        "Objectives:\n"..ZygorClassic_ObjectiveDebug84()..
        "Error: "..tostring(ZygorClassicDebug82.error or "none")
    ZygorClassicDebugText82:SetText(txt)
end

-- Live owner: keep TEST83's earliest-route lock, then use exact objective
-- completion to advance forward once the current step is truly finished.
local function ZygorClassic_Update84()
    if ZygorClassicDebug82 then ZygorClassicDebug82.event=event or "update" end
    if ZygorClassic_RecordTurnins62 then ZygorClassic_RecordTurnins62() end

    -- First keep us on the earliest active quest route.
    if ZygorClassic_InitialRoute83 then ZygorClassic_InitialRoute83() end

    -- If current exact objectives are all done, ordered engine may advance.
    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local step=guide and guide.classic_steps and guide.classic_steps[ZygorClassicStepIndex or 1]
    if guide and step and ZygorClassic_StepResolved78 and ZygorClassic_StepResolved78(guide,step) then
        local before=ZygorClassicStepIndex or 1
        ZygorClassicStepIndex=before+1
        while guide.classic_steps[ZygorClassicStepIndex] and
              ZygorClassic_StepApplies67 and
              not ZygorClassic_StepApplies67(guide.classic_steps[ZygorClassicStepIndex]) do
            ZygorClassicStepIndex=ZygorClassicStepIndex+1
        end
        if ZygorClassicDebug82 then
            ZygorClassicDebug82.route=tostring(before).." -> "..tostring(ZygorClassicStepIndex)
        end
    end

    ZygorClassic_Render()
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    ZygorClassic_UpdateDebug82()
end

if ZygorClassicLive53 then ZygorClassicLive53:SetScript("OnEvent",ZygorClassic_Update84) end
if ZygorClassicProgress73Frame then ZygorClassicProgress73Frame:SetScript("OnEvent",ZygorClassic_Update84) end
if ZygorClassicOrdered76Frame then ZygorClassicOrdered76Frame:SetScript("OnEvent",ZygorClassic_Update84) end


-- TEST85: objective debug/progression fallback.
-- TEST84 showed no objective rows, meaning the guide quest-ID -> title map did
-- not resolve these |q 170/1 and |q 170/2 lines. Resolve quest ID directly
-- from the guide's accept/turnin directives, then read Vanilla leaderboard.

local function ZygorClassic_TitleForQuestID85(guide,qid)
    if not guide or not guide.classic_steps then return nil end
    local i,j
    for i=1,table.getn(guide.classic_steps) do
        local raw=guide.classic_steps[i].raw or {}
        for j=1,table.getn(raw) do
            local line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(raw[j]) or raw[j]
            local id=string.match(line,"##(%d+)")
            if id and tostring(id)==tostring(qid) then
                local title,kind=nil,nil
                if ZygorClassic_ParseQuestDirective then
                    title,kind=ZygorClassic_ParseQuestDirective(line)
                end
                if title and (kind=="accept" or kind=="turnin") then return title end
            end
        end
    end
    return nil
end

ZygorClassic_FindQuestTitleByID76=function(guide,qid)
    return ZygorClassic_TitleForQuestID85(guide,qid)
end

-- Override objective debug using direct ID resolution.
ZygorClassic_ObjectiveDebug84=function()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return "-" end
    local guide=ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return "-" end
    local step=guide.classic_steps and guide.classic_steps[ZygorClassicStepIndex or 1]
    if not step then return "-" end

    local out=""
    local i
    for i=1,table.getn(step.raw or {}) do
        local clean=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(step.raw[i]) or step.raw[i]
        local qid,obj=string.match(clean,"|q%s*(%d+)/(%d+)")
        if qid and obj then
            local title=ZygorClassic_TitleForQuestID85(guide,qid)
            if title then
                local found=false
                local qi
                for qi=1,GetNumQuestLogEntries() do
                    local qt,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(qi)
                    if qt and not isHeader and qt==title then
                        found=true
                        local text,otype,finished=GetQuestLogLeaderBoard(tonumber(obj),qi)
                        out=out..tostring(obj)..": "..tostring(text or "?")..
                            " ["..((finished==1 or finished==true) and "DONE" or "TODO").."]\n"
                        break
                    end
                end
                if not found then
                    out=out..tostring(obj)..": "..tostring(title).." [NOT IN LOG]\n"
                end
            else
                out=out..tostring(obj)..": quest id "..tostring(qid).." [TITLE?]\n"
            end
        end
    end
    if out=="" then out="-" end
    return out
end


-- TEST86: expanded in-window diagnostics.
-- Show the raw step, active quest-log states, objective leaderboards, route
-- candidates, class/race applicability and authoritative/saved state.

local function ZygorClassic_QuestLogDump86()
    local out=""
    local i
    for i=1,GetNumQuestLogEntries() do
        local title,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(i)
        if title and not isHeader then
            out=out..title.." ["..((isComplete==1) and "COMPLETE" or "ACTIVE").."]"
            local n=GetNumQuestLeaderBoards and (GetNumQuestLeaderBoards(i) or 0) or 0
            if n>0 then
                local j
                for j=1,n do
                    local text,otype,finished=GetQuestLogLeaderBoard(j,i)
                    out=out.."\n  "..j..": "..tostring(text or "?").." ["..
                        ((finished==1 or finished==true) and "DONE" or "TODO").."]"
                end
            end
            out=out.."\n"
        end
    end
    if out=="" then out="(empty)" end
    return out
end

local function ZygorClassic_RawStep86()
    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local step=guide and guide.classic_steps and guide.classic_steps[ZygorClassicStepIndex or 1]
    if not step then return "-" end
    local out=""
    local i
    for i=1,table.getn(step.raw or {}) do
        out=out..tostring(i)..": "..tostring(step.raw[i]).."\n"
    end
    return out=="" and "-" or out
end

local function ZygorClassic_SavedState86()
    local key=ZygorClassic_Key73 and ZygorClassic_Key73() or
              (ZygorClassic_Key62 and ZygorClassic_Key62() or "?")
    local state=ZygorClassicDB and ZygorClassicDB.smart51 and ZygorClassicDB.smart51[key]
    if state then
        return "guide "..tostring(state.guide or "?")..", step "..tostring(state.step or "?")
    end
    return "none"
end

-- Widen/reposition diagnostic panel to use the empty right half.
if ZygorClassicDebugText82 then
    ZygorClassicDebugText82:ClearAllPoints()
    ZygorClassicDebugText82:SetPoint("TOPLEFT",ZygorGuidesViewerFrame,"TOPLEFT",430,-58)
    ZygorClassicDebugText82:SetWidth(365)
    ZygorClassicDebugText82:SetFont("Fonts\\FRIZQT__.TTF",11)
end

ZygorClassic_UpdateDebug82=function()
    if not ZygorClassicDebugText82 then return end
    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local step=ZygorClassicStepIndex or 1
    local map,x,y=nil,nil,nil
    local applies="-"
    if guide and guide.classic_steps and guide.classic_steps[step] then
        map,x,y=ZygorClassic_GotoForStep81(guide.classic_steps[step])
        if ZygorClassic_StepApplies67 then
            applies=ZygorClassic_StepApplies67(guide.classic_steps[step]) and "YES" or "NO"
        end
    end

    local txt="TEST86 FULL DIAGNOSTICS\n"..
        "Authoritative: G"..tostring(ZygorClassicGuideIndex or "?").." S"..tostring(step).."\n"..
        "Saved state: "..ZygorClassic_SavedState86().."\n"..
        "Race/Class: "..tostring(UnitRace("player") or "?").." / "..tostring(UnitClass("player") or "?").."\n"..
        "Level: "..tostring(UnitLevel("player") or "?").."  Step applies: "..tostring(applies).."\n"..
        "Last route: "..tostring(ZygorClassicDebug82 and ZygorClassicDebug82.route or "-").."\n"..
        "Last event: "..tostring(ZygorClassicDebug82 and ZygorClassicDebug82.event or "-").."\n"..
        "Matched quest: "..tostring(ZygorClassicDebug82 and ZygorClassicDebug82.quest or "-").."\n"..
        "Waypoint: "..tostring(map or "").." "..tostring(x or "-")..","..tostring(y or "-").."\n\n"..
        "CURRENT RAW STEP\n"..ZygorClassic_RawStep86().."\n"..
        "CURRENT STEP OBJECTIVES\n"..(ZygorClassic_ObjectiveDebug84 and ZygorClassic_ObjectiveDebug84() or "-").."\n"..
        "QUEST LOG\n"..ZygorClassic_QuestLogDump86()..
        "\nError: "..tostring(ZygorClassicDebug82 and ZygorClassicDebug82.error or "none")

    ZygorClassicDebugText82:SetText(txt)
end


-- TEST87: objective matching fix.
-- TEST86 proves Vanilla leaderboard data is perfect (0/6 TODO), while the
-- current-step objective parser is blank. The raw parser strips |q metadata
-- from step.raw, so match objective instructions by mob/item text against the
-- active quest leaderboard instead of depending on |q surviving parsing.

local function ZygorClassic_Normalize87(t)
    t=string.lower(tostring(t or ""))
    t=string.gsub(t,"[%p]"," ")
    t=string.gsub(t,"%s+"," ")
    return t
end

local function ZygorClassic_ObjectiveStateForLine87(line)
    local norm=ZygorClassic_Normalize87(line)
    local i
    for i=1,GetNumQuestLogEntries() do
        local title,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(i)
        if title and not isHeader then
            local n=GetNumQuestLeaderBoards and (GetNumQuestLeaderBoards(i) or 0) or 0
            local j
            for j=1,n do
                local text,otype,finished=GetQuestLogLeaderBoard(j,i)
                local onorm=ZygorClassic_Normalize87(text)
                -- Pull objective subject from "X slain: 0/6", "Item: 0/8", etc.
                local subject=string.match(onorm,"^(.-)%s+slain%s") or
                              string.match(onorm,"^(.-)%s+%d+%s*/%s*%d+") or onorm
                subject=string.gsub(subject,"%s+$","")
                if subject~="" and string.find(norm,subject,1,true) then
                    return title,text,(finished==1 or finished==true)
                end
            end
        end
    end
    return nil,nil,false
end

local function ZygorClassic_StepObjectiveLines87(step)
    local results={}
    local i
    for i=1,table.getn(step and step.raw or {}) do
        local line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(step.raw[i]) or step.raw[i]
        if string.find(line,"kill ",1,true)==1 or
           string.find(line,"get ",1,true)==1 or
           string.find(line,"goal ",1,true)==1 or
           string.find(line,"from ",1,true)==1 then
            local qtitle,text,done=ZygorClassic_ObjectiveStateForLine87(line)
            if qtitle then
                table.insert(results,{line=line,title=qtitle,text=text,done=done})
            end
        end
    end
    return results
end

-- Exact current-step resolver using the matched Vanilla leaderboard rows.
ZygorClassic_StepResolved78=function(guide,step)
    if not step then return true end
    if ZygorClassic_StepApplies67 and not ZygorClassic_StepApplies67(step) then return true end

    local objectives=ZygorClassic_StepObjectiveLines87(step)
    if table.getn(objectives)>0 then
        local i
        for i=1,table.getn(objectives) do
            if not objectives[i].done then return false end
        end
        return true
    end

    -- Fall back to TEST76 for accepts/turnins/ding/non-objective steps.
    if ZygorClassic_StepResolved76 and ZygorClassic_StepResolved76~=ZygorClassic_StepResolved78 then
        return ZygorClassic_StepResolved76(guide,step)
    end
    return false
end

ZygorClassic_ObjectiveDebug84=function()
    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local step=guide and guide.classic_steps and guide.classic_steps[ZygorClassicStepIndex or 1]
    if not step then return "-" end
    local objs=ZygorClassic_StepObjectiveLines87(step)
    if table.getn(objs)==0 then return "-" end
    local out=""
    local i
    for i=1,table.getn(objs) do
        out=out..tostring(i)..": "..tostring(objs[i].text or objs[i].line)..
            " ["..(objs[i].done and "DONE" or "TODO").."]\n"
    end
    return out
end


-- TEST88: robust objective text matcher.
-- TEST87 still showed blank CURRENT STEP OBJECTIVES. Match the creature/item
-- name from parsed guide lines against the creature/item name before ": x/y"
-- in Vanilla's leaderboard, ignoring verbs/counts/plurals.

local function ZygorClassic_ObjectiveSubject88(text)
    local t=string.lower(tostring(text or ""))
    -- leaderboard: "Rockjaw Trogg slain: 0/6"
    t=string.gsub(t,"%s+slain%s*:.*$","")
    t=string.gsub(t,"%s*:%s*%d+%s*/%s*%d+.*$","")
    t=string.gsub(t,"^%s+","")
    t=string.gsub(t,"%s+$","")
    return t
end

local function ZygorClassic_GuideSubject88(line)
    local t=string.lower(tostring(line or ""))
    -- Parsed guide lines may retain Zygor metadata such as "|q 183/1".
    -- It is not part of the creature/item name used by the quest leaderboard.
    t=string.gsub(t,"|.*$","")
    t=string.gsub(t,"^%s*kill%s+%d+%s+","")
    t=string.gsub(t,"^%s*get%s+%d+%s+","")
    t=string.gsub(t,"^%s*kill%s+","")
    t=string.gsub(t,"^%s*get%s+","")
    t=string.gsub(t,"^%s*from%s+","")
    t=string.gsub(t,"^%s*goal%s+","")
    t=string.gsub(t,"%s+$","")
    return t
end

local function ZygorClassic_ObjectiveStateForLine88(line)
    local subject=ZygorClassic_GuideSubject88(line)
    local i
    for i=1,GetNumQuestLogEntries() do
        local title,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(i)
        if title and not isHeader then
            local n=GetNumQuestLeaderBoards and (GetNumQuestLeaderBoards(i) or 0) or 0
            local j
            for j=1,n do
                local text,otype,finished=GetQuestLogLeaderBoard(j,i)
                local objsubject=ZygorClassic_ObjectiveSubject88(text)
                if subject~="" and objsubject~="" and
                   (string.find(subject,objsubject,1,true) or string.find(objsubject,subject,1,true)) then
                    return title,text,(finished==1 or finished==true)
                end
            end
        end
    end
    return nil,nil,false
end

ZygorClassic_StepObjectiveLines87=function(step)
    local results={}
    local i
    for i=1,table.getn(step and step.raw or {}) do
        local line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(step.raw[i]) or step.raw[i]
        local lower=string.lower(tostring(line or ""))
        if string.find(lower,"kill ",1,true)==1 or
           string.find(lower,"get ",1,true)==1 or
           string.find(lower,"goal ",1,true)==1 or
           string.find(lower,"from ",1,true)==1 then
            local qtitle,text,done=ZygorClassic_ObjectiveStateForLine88(line)
            if qtitle then
                table.insert(results,{line=line,title=qtitle,text=text,done=done})
            end
        end
    end
    return results
end


-- TEST89: step-resolution diagnostics + clean debug event tracking.
-- TEST88 proved objective matching now works. TEST89 shows whether the current
-- step is considered resolved and what the next applicable step will be.

ZygorClassicDebug82 = ZygorClassicDebug82 or {}
ZygorClassicDebug82.lastChat = ZygorClassicDebug82.lastChat or "-"

-- Replace TEST83's chat suppression hook so suppressed Zygor debug lines do not
-- overwrite Last event. Keep them in a separate field if needed.
if DEFAULT_CHAT_FRAME and ZygorClassicOriginalAddMessage83 then
    DEFAULT_CHAT_FRAME.AddMessage = function(self, msg, r, g, b, id)
        local t=tostring(msg or "")
        if string.find(t,"Zygor ",1,true)==1 or
           string.find(t,"|cffffcc00Zygor",1,true)==1 or
           string.find(t,"Zygor:",1,true)==1 then
            ZygorClassicDebug82.lastChat=t
            return
        end
        return ZygorClassicOriginalAddMessage83(self,msg,r,g,b,id)
    end
end

local function ZygorClassic_NextApplicable89(guide,idx)
    local i=idx+1
    while guide and guide.classic_steps and i<=table.getn(guide.classic_steps) do
        if not ZygorClassic_StepApplies67 or ZygorClassic_StepApplies67(guide.classic_steps[i]) then
            return i
        end
        i=i+1
    end
    return idx
end

-- Expanded diagnostic panel for progression decisions.
ZygorClassic_UpdateDebug82=function()
    if not ZygorClassicDebugText82 then return end

    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local stepidx=ZygorClassicStepIndex or 1
    local step=guide and guide.classic_steps and guide.classic_steps[stepidx]
    local map,x,y=nil,nil,nil
    local applies="-"
    local resolved="-"
    local nextstep="-"

    if step then
        map,x,y=ZygorClassic_GotoForStep81(step)
        if ZygorClassic_StepApplies67 then
            applies=ZygorClassic_StepApplies67(step) and "YES" or "NO"
        end
        if ZygorClassic_StepResolved78 then
            resolved=ZygorClassic_StepResolved78(guide,step) and "YES" or "NO"
        end
        nextstep=tostring(ZygorClassic_NextApplicable89(guide,stepidx))
    end

    local txt="TEST89 FULL DIAGNOSTICS\n"..
        "Authoritative: G"..tostring(ZygorClassicGuideIndex or "?").." S"..tostring(stepidx).."\n"..
        "Saved state: "..(ZygorClassic_SavedState86 and ZygorClassic_SavedState86() or "-").."\n"..
        "Race/Class: "..tostring(UnitRace("player") or "?").." / "..tostring(UnitClass("player") or "?").."\n"..
        "Level: "..tostring(UnitLevel("player") or "?").."  Step applies: "..tostring(applies).."\n"..
        "Step resolved: "..tostring(resolved).."  Next applicable: "..tostring(nextstep).."\n"..
        "Last route: "..tostring(ZygorClassicDebug82.route or "-").."\n"..
        "Last event: "..tostring(ZygorClassicDebug82.event or "-").."\n"..
        "Matched quest: "..tostring(ZygorClassicDebug82.quest or "-").."\n"..
        "Waypoint: "..tostring(map or "").." "..tostring(x or "-")..","..tostring(y or "-").."\n\n"..
        "CURRENT RAW STEP\n"..(ZygorClassic_RawStep86 and ZygorClassic_RawStep86() or "-").."\n"..
        "CURRENT STEP OBJECTIVES\n"..(ZygorClassic_ObjectiveDebug84 and ZygorClassic_ObjectiveDebug84() or "-").."\n"..
        "QUEST LOG\n"..(ZygorClassic_QuestLogDump86 and ZygorClassic_QuestLogDump86() or "-")..
        "\nError: "..tostring(ZygorClassicDebug82.error or "none")

    ZygorClassicDebugText82:SetText(txt)
end

-- Final live owner for this build: record the real WoW event, route/resolve,
-- render, then refresh diagnostics.
local function ZygorClassic_Update89()
    ZygorClassicDebug82.event=event or "update"
    if ZygorClassic_RecordTurnins62 then ZygorClassic_RecordTurnins62() end

    -- Keep correct active-quest route.
    if ZygorClassic_InitialRoute83 then ZygorClassic_InitialRoute83() end

    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local idx=ZygorClassicStepIndex or 1
    local step=guide and guide.classic_steps and guide.classic_steps[idx]

    if guide and step and ZygorClassic_StepResolved78 and ZygorClassic_StepResolved78(guide,step) then
        local target=ZygorClassic_NextApplicable89(guide,idx)
        if target~=idx then
            ZygorClassicStepIndex=target
            ZygorClassicDebug82.route=tostring(idx).." -> "..tostring(target)
        end
    end

    ZygorClassic_Render()
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    ZygorClassic_UpdateDebug82()
end

if ZygorClassicLive53 then ZygorClassicLive53:SetScript("OnEvent",ZygorClassic_Update89) end
if ZygorClassicProgress73Frame then ZygorClassicProgress73Frame:SetScript("OnEvent",ZygorClassic_Update89) end
if ZygorClassicOrdered76Frame then ZygorClassicOrdered76Frame:SetScript("OnEvent",ZygorClassic_Update89) end


-- TEST90: live objective progress test.
-- TEST89 proves Step 9 is unresolved, next applicable is Step 10, and both
-- exact Vanilla objectives are mapped correctly. Keep this stable path and
-- make the event owner persist/advance cleanly when both become DONE.

local function ZygorClassic_SaveStep90()
    local key=ZygorClassic_Key73 and ZygorClassic_Key73() or
              (ZygorClassic_Key62 and ZygorClassic_Key62() or nil)
    if not key then return end
    ZygorClassicDB.smart51=ZygorClassicDB.smart51 or {}
    ZygorClassicDB.smart51[key]=ZygorClassicDB.smart51[key] or {}
    ZygorClassicDB.smart51[key].guide=ZygorClassicGuideIndex
    ZygorClassicDB.smart51[key].step=ZygorClassicStepIndex
end

local function ZygorClassic_Update90()
    ZygorClassicDebug82.event=event or "update"
    if ZygorClassic_RecordTurnins62 then ZygorClassic_RecordTurnins62() end

    -- While current step is unresolved, keep earliest-active routing.
    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local idx=ZygorClassicStepIndex or 1
    local step=guide and guide.classic_steps and guide.classic_steps[idx]

    if guide and step and ZygorClassic_StepResolved78 and
       not ZygorClassic_StepResolved78(guide,step) then
        if ZygorClassic_InitialRoute83 then ZygorClassic_InitialRoute83() end
        idx=ZygorClassicStepIndex or 1
        step=guide.classic_steps[idx]
    end

    -- Once all current objectives/actions are satisfied, advance exactly once
    -- to the next applicable guide step and persist it.
    if guide and step and ZygorClassic_StepResolved78 and
       ZygorClassic_StepResolved78(guide,step) then
        local target=ZygorClassic_NextApplicable89(guide,idx)
        if target~=idx then
            ZygorClassicStepIndex=target
            ZygorClassicDebug82.route=tostring(idx).." -> "..tostring(target)
            ZygorClassic_SaveStep90()
        end
    else
        ZygorClassic_SaveStep90()
    end

    ZygorClassic_Render()
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    ZygorClassic_UpdateDebug82()
end

if ZygorClassicLive53 then ZygorClassicLive53:SetScript("OnEvent",ZygorClassic_Update90) end
if ZygorClassicProgress73Frame then ZygorClassicProgress73Frame:SetScript("OnEvent",ZygorClassic_Update90) end
if ZygorClassicOrdered76Frame then ZygorClassicOrdered76Frame:SetScript("OnEvent",ZygorClassic_Update90) end


-- TEST91: objective label correctness.
-- TEST90 shows progression state is good, but CURRENT STEP OBJECTIVES labels
-- both rows as Rockjaw Trogg. Use exact guide-line subject to pair each guide
-- objective with the best unmatched Vanilla leaderboard row.

local function ZygorClassic_SubjectScore91(a,b)
    a=ZygorClassic_GuideSubject88(a)
    b=ZygorClassic_ObjectiveSubject88(b)
    if a==b then return 1000 end
    if string.find(a,b,1,true) or string.find(b,a,1,true) then
        return string.len(b)
    end
    -- Word overlap fallback, favor distinctive/longer objective names.
    local score=0
    local word
    for word in string.gfind(a,"%S+") do
        if string.len(word)>2 and string.find(b,word,1,true) then
            score=score+string.len(word)
        end
    end
    return score
end

ZygorClassic_StepObjectiveLines87=function(step)
    local guideLines={}
    local i
    for i=1,table.getn(step and step.raw or {}) do
        local line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(step.raw[i]) or step.raw[i]
        local lower=string.lower(tostring(line or ""))
        if string.find(lower,"kill ",1,true)==1 or
           string.find(lower,"get ",1,true)==1 or
           string.find(lower,"goal ",1,true)==1 or
           string.find(lower,"from ",1,true)==1 then
            table.insert(guideLines,line)
        end
    end

    local board={}
    local qi
    for qi=1,GetNumQuestLogEntries() do
        local title,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(qi)
        if title and not isHeader then
            local n=GetNumQuestLeaderBoards and (GetNumQuestLeaderBoards(qi) or 0) or 0
            local j
            for j=1,n do
                local text,otype,finished=GetQuestLogLeaderBoard(j,qi)
                table.insert(board,{
                    title=title,text=text,done=(finished==1 or finished==true),used=false
                })
            end
        end
    end

    local results={}
    for i=1,table.getn(guideLines) do
        local line=guideLines[i]
        local best=nil
        local bestScore=0
        local j
        for j=1,table.getn(board) do
            if not board[j].used then
                local score=ZygorClassic_SubjectScore91(line,board[j].text)
                if score>bestScore then
                    bestScore=score
                    best=j
                end
            end
        end
        if best and bestScore>0 then
            board[best].used=true
            table.insert(results,{
                line=line,
                title=board[best].title,
                text=board[best].text,
                done=board[best].done
            })
        end
    end
    return results
end


-- TEST92: live kill validation instrumentation.
-- Objective mapping is now correct. Track changes to the two leaderboard rows
-- and expose the last observed objective transition in-window.

ZygorClassicDebug82=ZygorClassicDebug82 or {}
ZygorClassicDebug82.objectiveChange=ZygorClassicDebug82.objectiveChange or "-"
ZygorClassicObjectiveSnapshot92=ZygorClassicObjectiveSnapshot92 or {}

local function ZygorClassic_CheckObjectiveChanges92()
    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local step=guide and guide.classic_steps and guide.classic_steps[ZygorClassicStepIndex or 1]
    if not step or not ZygorClassic_StepObjectiveLines87 then return end

    local objs=ZygorClassic_StepObjectiveLines87(step)
    local i
    for i=1,table.getn(objs) do
        local key=tostring(objs[i].title or "?").."#"..tostring(i)
        local now=tostring(objs[i].text or "?")
        local old=ZygorClassicObjectiveSnapshot92[key]
        if old and old~=now then
            ZygorClassicDebug82.objectiveChange=old.." -> "..now
        end
        ZygorClassicObjectiveSnapshot92[key]=now
    end
end

local ZygorClassic_UpdateDebug82_Base92=ZygorClassic_UpdateDebug82
ZygorClassic_UpdateDebug82=function()
    if ZygorClassic_UpdateDebug82_Base92 then ZygorClassic_UpdateDebug82_Base92() end
    if not ZygorClassicDebugText82 then return end

    -- Append only one compact extra line to the existing TEST89 diagnostics.
    local current=ZygorClassicDebugText82:GetText() or ""
    if not string.find(current,"Last objective change:",1,true) then
        current=current.."\nLast objective change: "..tostring(ZygorClassicDebug82.objectiveChange or "-")
    end
    ZygorClassicDebugText82:SetText(current)
end

local function ZygorClassic_Update92()
    ZygorClassicDebug82.event=event or "update"
    if ZygorClassic_RecordTurnins62 then ZygorClassic_RecordTurnins62() end
    ZygorClassic_CheckObjectiveChanges92()

    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local idx=ZygorClassicStepIndex or 1
    local step=guide and guide.classic_steps and guide.classic_steps[idx]

    if guide and step and ZygorClassic_StepResolved78 and
       not ZygorClassic_StepResolved78(guide,step) then
        if ZygorClassic_InitialRoute83 then ZygorClassic_InitialRoute83() end
        idx=ZygorClassicStepIndex or 1
        step=guide.classic_steps[idx]
    end

    if guide and step and ZygorClassic_StepResolved78 and
       ZygorClassic_StepResolved78(guide,step) then
        local target=ZygorClassic_NextApplicable89(guide,idx)
        if target~=idx then
            ZygorClassicStepIndex=target
            ZygorClassicDebug82.route=tostring(idx).." -> "..tostring(target)
            if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
        end
    elseif ZygorClassic_SaveStep90 then
        ZygorClassic_SaveStep90()
    end

    ZygorClassic_Render()
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    ZygorClassic_UpdateDebug82()
end

if ZygorClassicLive53 then ZygorClassicLive53:SetScript("OnEvent",ZygorClassic_Update92) end
if ZygorClassicProgress73Frame then ZygorClassicProgress73Frame:SetScript("OnEvent",ZygorClassic_Update92) end
if ZygorClassicOrdered76Frame then ZygorClassicOrdered76Frame:SetScript("OnEvent",ZygorClassic_Update92) end


-- TEST93: counter refresh ownership.
-- TEST92 instrumentation exists but the visible objective snapshot remains 0/6.
-- Refresh leaderboard state after QUEST_LOG_UPDATE settles, then render/debug.

if not ZygorClassicDelayedQuest93 then
    ZygorClassicDelayedQuest93=CreateFrame("Frame","ZygorClassicDelayedQuest93",UIParent)
    ZygorClassicDelayedQuest93.pending=false
    ZygorClassicDelayedQuest93.elapsed=0
    ZygorClassicDelayedQuest93:Hide()

    ZygorClassicDelayedQuest93:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.20 then return end
        this.elapsed=0
        this:Hide()

        if ZygorClassicDebug82 then ZygorClassicDebug82.event="QUEST_LOG_UPDATE (settled)" end
        if ZygorClassic_CheckObjectiveChanges92 then ZygorClassic_CheckObjectiveChanges92() end

        local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                    ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
        local idx=ZygorClassicStepIndex or 1
        local step=guide and guide.classic_steps and guide.classic_steps[idx]

        if guide and step and ZygorClassic_StepResolved78 and ZygorClassic_StepResolved78(guide,step) then
            local target=ZygorClassic_NextApplicable89(guide,idx)
            if target~=idx then
                ZygorClassicStepIndex=target
                if ZygorClassicDebug82 then ZygorClassicDebug82.route=tostring(idx).." -> "..tostring(target) end
                if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
            end
        end

        if ZygorClassic_Render then ZygorClassic_Render() end
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
        if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
    end)
end

local function ZygorClassic_Update93()
    if ZygorClassicDebug82 then ZygorClassicDebug82.event=event or "update" end

    if event=="QUEST_LOG_UPDATE" then
        -- Vanilla can fire this while quest leaderboard text is still settling.
        ZygorClassicDelayedQuest93.elapsed=0
        ZygorClassicDelayedQuest93:Show()
        return
    end

    if ZygorClassic_RecordTurnins62 then ZygorClassic_RecordTurnins62() end
    if ZygorClassic_CheckObjectiveChanges92 then ZygorClassic_CheckObjectiveChanges92() end

    if ZygorClassic_Render then ZygorClassic_Render() end
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
end

if ZygorClassicLive53 then ZygorClassicLive53:SetScript("OnEvent",ZygorClassic_Update93) end
if ZygorClassicProgress73Frame then ZygorClassicProgress73Frame:SetScript("OnEvent",ZygorClassic_Update93) end
if ZygorClassicOrdered76Frame then ZygorClassicOrdered76Frame:SetScript("OnEvent",ZygorClassic_Update93) end


-- TEST94: route-before-resolve fix.
-- TEST93's delayed handler evaluated stale Step 15 and advanced it to 17.
-- Always restore the earliest active quest route FIRST, then evaluate whether
-- THAT step is resolved.

local function ZygorClassic_SettledUpdate94()
    if ZygorClassicDebug82 then ZygorClassicDebug82.event="QUEST_LOG_UPDATE (settled)" end
    if ZygorClassic_RecordTurnins62 then ZygorClassic_RecordTurnins62() end
    if ZygorClassic_CheckObjectiveChanges92 then ZygorClassic_CheckObjectiveChanges92() end

    -- Critical ordering: current active quest route first.
    if ZygorClassic_InitialRoute83 then ZygorClassic_InitialRoute83() end

    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local idx=ZygorClassicStepIndex or 1
    local step=guide and guide.classic_steps and guide.classic_steps[idx]

    -- Only resolve/advance the freshly-routed step.
    if guide and step and ZygorClassic_StepResolved78 and ZygorClassic_StepResolved78(guide,step) then
        local target=ZygorClassic_NextApplicable89(guide,idx)
        if target~=idx then
            ZygorClassicStepIndex=target
            if ZygorClassicDebug82 then ZygorClassicDebug82.route=tostring(idx).." -> "..tostring(target) end
            if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
        end
    else
        if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
    end

    if ZygorClassic_Render then ZygorClassic_Render() end
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
end

if ZygorClassicDelayedQuest93 then
    ZygorClassicDelayedQuest93:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.20 then return end
        this.elapsed=0
        this:Hide()
        ZygorClassic_SettledUpdate94()
    end)
end

local function ZygorClassic_Update94()
    if ZygorClassicDebug82 then ZygorClassicDebug82.event=event or "update" end
    if event=="QUEST_LOG_UPDATE" then
        ZygorClassicDelayedQuest93.elapsed=0
        ZygorClassicDelayedQuest93:Show()
        return
    end
    if ZygorClassic_RecordTurnins62 then ZygorClassic_RecordTurnins62() end
    if ZygorClassic_Render then ZygorClassic_Render() end
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
end

if ZygorClassicLive53 then ZygorClassicLive53:SetScript("OnEvent",ZygorClassic_Update94) end
if ZygorClassicProgress73Frame then ZygorClassicProgress73Frame:SetScript("OnEvent",ZygorClassic_Update94) end
if ZygorClassicOrdered76Frame then ZygorClassicOrdered76Frame:SetScript("OnEvent",ZygorClassic_Update94) end


-- TEST95: live kill counter validation.
-- TEST94 now keeps Step 9 stable after settled QUEST_LOG_UPDATE. Add a compact
-- heartbeat snapshot so we can distinguish "event never fired" from "event
-- fired but leaderboard did not change."

ZygorClassicDebug82=ZygorClassicDebug82 or {}
ZygorClassicDebug82.questUpdateCount=ZygorClassicDebug82.questUpdateCount or 0
ZygorClassicDebug82.lastLeaderboard="-"

local function ZygorClassic_LeaderboardSnapshot95()
    local out=""
    local i
    for i=1,GetNumQuestLogEntries() do
        local title,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(i)
        if title and not isHeader and title=="A New Threat" then
            local n=GetNumQuestLeaderBoards and (GetNumQuestLeaderBoards(i) or 0) or 0
            local j
            for j=1,n do
                local text,otype,finished=GetQuestLogLeaderBoard(j,i)
                if out~="" then out=out.." | " end
                out=out..tostring(text or "?")
            end
        end
    end
    return out=="" and "-" or out
end

-- Wrap TEST94 settled handler with event count/snapshot.
local ZygorClassic_SettledUpdate94_Base95=ZygorClassic_SettledUpdate94
ZygorClassic_SettledUpdate94=function()
    ZygorClassicDebug82.questUpdateCount=(ZygorClassicDebug82.questUpdateCount or 0)+1
    ZygorClassicDebug82.lastLeaderboard=ZygorClassic_LeaderboardSnapshot95()
    ZygorClassic_SettledUpdate94_Base95()
end

local ZygorClassic_UpdateDebug82_Base95=ZygorClassic_UpdateDebug82
ZygorClassic_UpdateDebug82=function()
    if ZygorClassic_UpdateDebug82_Base95 then ZygorClassic_UpdateDebug82_Base95() end
    if not ZygorClassicDebugText82 then return end
    local t=ZygorClassicDebugText82:GetText() or ""
    if not string.find(t,"Quest updates:",1,true) then
        t=t.."\nQuest updates: "..tostring(ZygorClassicDebug82.questUpdateCount or 0)..
          "\nLeaderboard snapshot: "..tostring(ZygorClassicDebug82.lastLeaderboard or "-")
    end
    ZygorClassicDebugText82:SetText(t)
end


-- TEST96: establish clean live-kill baseline.
-- TEST95 shows exactly one settled quest update at 0/6, before any kills.
-- Record the initial leaderboard snapshot as baseline so the next actual
-- objective update can be compared cleanly.

ZygorClassicDebug82=ZygorClassicDebug82 or {}
ZygorClassicDebug82.baselineLeaderboard=ZygorClassicDebug82.baselineLeaderboard or "-"
ZygorClassicDebug82.changedSinceBaseline="NO"

local function ZygorClassic_UpdateBaseline96()
    local now=ZygorClassic_LeaderboardSnapshot95 and ZygorClassic_LeaderboardSnapshot95() or "-"
    if ZygorClassicDebug82.baselineLeaderboard=="-" then
        ZygorClassicDebug82.baselineLeaderboard=now
    end
    ZygorClassicDebug82.changedSinceBaseline=
        (now~=ZygorClassicDebug82.baselineLeaderboard) and "YES" or "NO"
end

local ZygorClassic_SettledUpdate94_Base96=ZygorClassic_SettledUpdate94
ZygorClassic_SettledUpdate94=function()
    ZygorClassic_UpdateBaseline96()
    ZygorClassic_SettledUpdate94_Base96()
    ZygorClassic_UpdateBaseline96()
end

local ZygorClassic_UpdateDebug82_Base96=ZygorClassic_UpdateDebug82
ZygorClassic_UpdateDebug82=function()
    if ZygorClassic_UpdateDebug82_Base96 then ZygorClassic_UpdateDebug82_Base96() end
    if not ZygorClassicDebugText82 then return end
    local t=ZygorClassicDebugText82:GetText() or ""
    if not string.find(t,"Baseline:",1,true) then
        t=t.."\nBaseline: "..tostring(ZygorClassicDebug82.baselineLeaderboard or "-")..
            "\nChanged since baseline: "..tostring(ZygorClassicDebug82.changedSinceBaseline or "NO")
    end
    ZygorClassicDebugText82:SetText(t)
end

ZygorClassic_UpdateBaseline96()


-- TEST97: objective-change tracking fix.
-- TEST96 proves live Vanilla counters update correctly (0/6 -> 1/6), but the
-- old per-object snapshot did not populate Last objective change. Compare the
-- raw leaderboard snapshot directly against the previous settled snapshot.

ZygorClassicDebug82=ZygorClassicDebug82 or {}
ZygorClassicDebug82.previousLeaderboard=ZygorClassicDebug82.previousLeaderboard or
    (ZygorClassic_LeaderboardSnapshot95 and ZygorClassic_LeaderboardSnapshot95() or "-")

local function ZygorClassic_RecordLeaderboardChange97()
    local now=ZygorClassic_LeaderboardSnapshot95 and ZygorClassic_LeaderboardSnapshot95() or "-"
    local old=ZygorClassicDebug82.previousLeaderboard or "-"
    if old~="-" and now~="-" and old~=now then
        ZygorClassicDebug82.objectiveChange=old.." -> "..now
    end
    ZygorClassicDebug82.previousLeaderboard=now
end

-- Add this to the settled quest-log path, before diagnostics render.
local ZygorClassic_SettledUpdate94_Base97=ZygorClassic_SettledUpdate94
ZygorClassic_SettledUpdate94=function()
    ZygorClassic_RecordLeaderboardChange97()
    ZygorClassic_SettledUpdate94_Base97()
    ZygorClassic_RecordLeaderboardChange97()
end


-- TEST98: persistent baseline/change diagnostics across /reload.
-- TEST97 was installed after the first kill, so its new baseline naturally
-- started at 1/6. Preserve baseline and previous snapshot in SavedVariables so
-- subsequent reloads don't erase the comparison history.

ZygorClassicDB=ZygorClassicDB or {}
ZygorClassicDB.debug98=ZygorClassicDB.debug98 or {}

local function ZygorClassic_DebugKey98()
    return (ZygorClassic_Key73 and ZygorClassic_Key73()) or
           (ZygorClassic_Key62 and ZygorClassic_Key62()) or
           tostring(UnitName("player") or "player")
end

local function ZygorClassic_LoadPersistentDebug98()
    local key=ZygorClassic_DebugKey98()
    ZygorClassicDB.debug98[key]=ZygorClassicDB.debug98[key] or {}
    local d=ZygorClassicDB.debug98[key]
    local now=ZygorClassic_LeaderboardSnapshot95 and ZygorClassic_LeaderboardSnapshot95() or "-"

    if not d.baseline or d.baseline=="-" then d.baseline=now end
    if not d.previous or d.previous=="-" then d.previous=now end

    ZygorClassicDebug82.baselineLeaderboard=d.baseline
    ZygorClassicDebug82.previousLeaderboard=d.previous
    ZygorClassicDebug82.changedSinceBaseline=(now~=d.baseline) and "YES" or "NO"
end

local function ZygorClassic_RecordPersistent98()
    local key=ZygorClassic_DebugKey98()
    ZygorClassicDB.debug98[key]=ZygorClassicDB.debug98[key] or {}
    local d=ZygorClassicDB.debug98[key]
    local now=ZygorClassic_LeaderboardSnapshot95 and ZygorClassic_LeaderboardSnapshot95() or "-"
    local old=d.previous or now

    if old~="-" and now~="-" and old~=now then
        ZygorClassicDebug82.objectiveChange=old.." -> "..now
    end

    if not d.baseline or d.baseline=="-" then d.baseline=now end
    d.previous=now

    ZygorClassicDebug82.baselineLeaderboard=d.baseline
    ZygorClassicDebug82.previousLeaderboard=now
    ZygorClassicDebug82.changedSinceBaseline=(now~=d.baseline) and "YES" or "NO"
end

local ZygorClassic_SettledUpdate94_Base98=ZygorClassic_SettledUpdate94
ZygorClassic_SettledUpdate94=function()
    ZygorClassic_RecordPersistent98()
    ZygorClassic_SettledUpdate94_Base98()
    ZygorClassic_RecordPersistent98()
end

ZygorClassic_LoadPersistentDebug98()


-- TEST99: startup route after reload.
-- TEST98 screenshot shows saved state remains Step 9 but authoritative state
-- comes up Step 15 immediately after reload. Force the same route-before-resolve
-- logic once after all startup handlers settle.

if not ZygorClassicStartup99Frame then
    ZygorClassicStartup99Frame=CreateFrame("Frame","ZygorClassicStartup99Frame",UIParent)
    ZygorClassicStartup99Frame.elapsed=0
    ZygorClassicStartup99Frame:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<3.5 then return end
        this.elapsed=0

        if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides or
           table.getn(ZygorGuidesViewer.registeredguides)<1 then return end

        -- Restore earliest active quest objective before anything can resolve
        -- the stale class-turnin step.
        if ZygorClassic_InitialRoute83 then ZygorClassic_InitialRoute83() end
        if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end

        -- Initialize persistent diagnostic baseline only after route is correct.
        if ZygorClassic_LoadPersistentDebug98 then ZygorClassic_LoadPersistentDebug98() end

        if ZygorClassic_Render then ZygorClassic_Render() end
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
        if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
        this:Hide()
    end)
end


-- TEST100: clean live-counter state after startup.
-- TEST99 confirms startup route is fixed (G4 S9 / saved S9). Initialize the
-- current leaderboard snapshot after startup correction so future kills have
-- a clean previous-value comparison and Quest updates starts from this build.

ZygorClassicDebug82=ZygorClassicDebug82 or {}

if not ZygorClassicInit100Frame then
    ZygorClassicInit100Frame=CreateFrame("Frame","ZygorClassicInit100Frame",UIParent)
    ZygorClassicInit100Frame.elapsed=0
    ZygorClassicInit100Frame:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<4.0 then return end
        this.elapsed=0

        if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides or
           table.getn(ZygorGuidesViewer.registeredguides)<1 then return end

        if ZygorClassic_InitialRoute83 then ZygorClassic_InitialRoute83() end
        if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end

        local now=ZygorClassic_LeaderboardSnapshot95 and ZygorClassic_LeaderboardSnapshot95() or "-"
        ZygorClassicDebug82.previousLeaderboard=now
        ZygorClassicDebug82.lastLeaderboard=now
        ZygorClassicDebug82.questUpdateCount=0
        ZygorClassicDebug82.objectiveChange="-"

        -- Keep persistent baseline as-is, but make current previous snapshot
        -- equal to the actual state at TEST100 startup.
        local key=ZygorClassic_DebugKey98 and ZygorClassic_DebugKey98()
        if key and ZygorClassicDB and ZygorClassicDB.debug98 then
            ZygorClassicDB.debug98[key]=ZygorClassicDB.debug98[key] or {}
            ZygorClassicDB.debug98[key].previous=now
        end

        if ZygorClassic_Render then ZygorClassic_Render() end
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
        if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
        this:Hide()
    end)
end


-- TEST101: next-kill transition validation.
-- TEST100 is a clean baseline at Rockjaw 1/6, Burly 0/6. Keep a session-local
-- previous snapshot initialized to that state and record the next settled
-- leaderboard transition directly.

ZygorClassicDebug82=ZygorClassicDebug82 or {}
ZygorClassicDebug82.sessionPrevious101 =
    ZygorClassic_LeaderboardSnapshot95 and ZygorClassic_LeaderboardSnapshot95() or "-"

local function ZygorClassic_RecordSessionChange101()
    local now=ZygorClassic_LeaderboardSnapshot95 and ZygorClassic_LeaderboardSnapshot95() or "-"
    local old=ZygorClassicDebug82.sessionPrevious101 or "-"
    if old~="-" and now~="-" and old~=now then
        ZygorClassicDebug82.objectiveChange=old.." -> "..now
        ZygorClassicDebug82.changedSinceBaseline="YES"
    end
    ZygorClassicDebug82.sessionPrevious101=now
end

local ZygorClassic_SettledUpdate94_Base101=ZygorClassic_SettledUpdate94
ZygorClassic_SettledUpdate94=function()
    ZygorClassic_RecordSessionChange101()
    ZygorClassic_SettledUpdate94_Base101()
    ZygorClassic_RecordSessionChange101()
end


-- TEST102: fix nil debug98 table causing spam at lines ~5044/5058.
-- Some code paths assume ZygorClassicDB.debug98 exists before SavedVariables
-- initialization completes. Ensure the table hierarchy always exists.

ZygorClassicDB = ZygorClassicDB or {}
ZygorClassicDB.debug98 = ZygorClassicDB.debug98 or {}

local function ZygorClassic_DebugKey102()
    if ZygorClassic_DebugKey98 then
        local k=ZygorClassic_DebugKey98()
        if k then return k end
    end
    if ZygorClassic_Key73 then
        local k=ZygorClassic_Key73()
        if k then return k end
    end
    if ZygorClassic_Key62 then
        local k=ZygorClassic_Key62()
        if k then return k end
    end
    return tostring(UnitName("player") or "player")
end

local function ZygorClassic_EnsureDebug98_102()
    ZygorClassicDB = ZygorClassicDB or {}
    ZygorClassicDB.debug98 = ZygorClassicDB.debug98 or {}
    local key=ZygorClassic_DebugKey102()
    ZygorClassicDB.debug98[key]=ZygorClassicDB.debug98[key] or {}
    return ZygorClassicDB.debug98[key], key
end

-- Replace the persistent-debug helpers with guarded versions.
ZygorClassic_LoadPersistentDebug98=function()
    local d,key=ZygorClassic_EnsureDebug98_102()
    local now=ZygorClassic_LeaderboardSnapshot95 and ZygorClassic_LeaderboardSnapshot95() or "-"

    if not d.baseline or d.baseline=="-" then d.baseline=now end
    if not d.previous or d.previous=="-" then d.previous=now end

    ZygorClassicDebug82=ZygorClassicDebug82 or {}
    ZygorClassicDebug82.baselineLeaderboard=d.baseline
    ZygorClassicDebug82.previousLeaderboard=d.previous
    ZygorClassicDebug82.changedSinceBaseline=(now~=d.baseline) and "YES" or "NO"
end

ZygorClassic_RecordPersistent98=function()
    local d,key=ZygorClassic_EnsureDebug98_102()
    local now=ZygorClassic_LeaderboardSnapshot95 and ZygorClassic_LeaderboardSnapshot95() or "-"
    local old=d.previous or now

    ZygorClassicDebug82=ZygorClassicDebug82 or {}
    if old~="-" and now~="-" and old~=now then
        ZygorClassicDebug82.objectiveChange=old.." -> "..now
    end

    if not d.baseline or d.baseline=="-" then d.baseline=now end
    d.previous=now

    ZygorClassicDebug82.baselineLeaderboard=d.baseline
    ZygorClassicDebug82.previousLeaderboard=now
    ZygorClassicDebug82.changedSinceBaseline=(now~=d.baseline) and "YES" or "NO"
end

-- Reinitialize safely once this patch loads.
ZygorClassic_LoadPersistentDebug98()


-- TEST103: clean next-kill validation after debug98 nil fix.
-- Current state is stable at Step 9, Rockjaw 1/6, Burly 0/6.
-- Establish a guarded session snapshot and record the next real leaderboard
-- transition without touching the persistent debug98 hierarchy directly.

ZygorClassicDebug82=ZygorClassicDebug82 or {}
ZygorClassicDebug82.sessionPrev103 =
    ZygorClassic_LeaderboardSnapshot95 and ZygorClassic_LeaderboardSnapshot95() or "-"

local function ZygorClassic_RecordChange103()
    local now=ZygorClassic_LeaderboardSnapshot95 and ZygorClassic_LeaderboardSnapshot95() or "-"
    local old=ZygorClassicDebug82.sessionPrev103 or "-"
    if old~="-" and now~="-" and old~=now then
        ZygorClassicDebug82.objectiveChange=old.." -> "..now
        ZygorClassicDebug82.changedSinceBaseline="YES"
    end
    ZygorClassicDebug82.sessionPrev103=now
    ZygorClassicDebug82.lastLeaderboard=now
end

local ZygorClassic_SettledUpdate94_Base103=ZygorClassic_SettledUpdate94
ZygorClassic_SettledUpdate94=function()
    ZygorClassic_RecordChange103()
    ZygorClassic_SettledUpdate94_Base103()
    ZygorClassic_RecordChange103()
end


-- TEST104: make the next kill transition visible without relying on old
-- diagnostic counters. Session baseline is the current leaderboard state.
ZygorClassicDebug82=ZygorClassicDebug82 or {}
ZygorClassicDebug82.killBaseline104 =
    ZygorClassic_LeaderboardSnapshot95 and ZygorClassic_LeaderboardSnapshot95() or "-"

local function ZygorClassic_KillTransition104()
    local now=ZygorClassic_LeaderboardSnapshot95 and ZygorClassic_LeaderboardSnapshot95() or "-"
    local base=ZygorClassicDebug82.killBaseline104 or "-"
    if base~="-" and now~="-" and base~=now then
        ZygorClassicDebug82.objectiveChange=base.." -> "..now
        ZygorClassicDebug82.changedSinceBaseline="YES"
    end
end

local ZygorClassic_SettledUpdate94_Base104=ZygorClassic_SettledUpdate94
ZygorClassic_SettledUpdate94=function()
    ZygorClassic_KillTransition104()
    ZygorClassic_SettledUpdate94_Base104()
    ZygorClassic_KillTransition104()
end


-- TEST105: multi-objective completion validation.
-- TEST104 proved live event + objective transition tracking works.
-- Keep current progression logic and add compact completion summary so we can
-- validate partial -> complete -> Step 10 transition across both objectives.

ZygorClassicDebug82=ZygorClassicDebug82 or {}
ZygorClassicDebug82.completion105="-"

local function ZygorClassic_CompletionSummary105()
    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local step=guide and guide.classic_steps and guide.classic_steps[ZygorClassicStepIndex or 1]
    if not step or not ZygorClassic_StepObjectiveLines87 then return "-" end
    local objs=ZygorClassic_StepObjectiveLines87(step)
    if table.getn(objs)==0 then return "no objectives" end
    local done=0
    local i
    for i=1,table.getn(objs) do
        if objs[i].done then done=done+1 end
    end
    return tostring(done).."/"..tostring(table.getn(objs)).." objectives DONE"
end

local ZygorClassic_UpdateDebug82_Base105=ZygorClassic_UpdateDebug82
ZygorClassic_UpdateDebug82=function()
    ZygorClassicDebug82.completion105=ZygorClassic_CompletionSummary105()
    if ZygorClassic_UpdateDebug82_Base105 then ZygorClassic_UpdateDebug82_Base105() end
    if ZygorClassicDebugText82 then
        local t=ZygorClassicDebugText82:GetText() or ""
        if not string.find(t,"Completion summary:",1,true) then
            t=t.."\nCompletion summary: "..tostring(ZygorClassicDebug82.completion105)
        end
        ZygorClassicDebugText82:SetText(t)
    end
end


-- TEST106: completion run.
-- TEST105 confirms both objectives map independently and completion summary is
-- 0/2 at 1/6 + 1/6. Preserve the working engine and make the summary/event
-- refresh use the settled leaderboard state for the full 6/6 + 6/6 run.

local function ZygorClassic_RefreshCompletion106()
    if ZygorClassicDebug82 then
        ZygorClassicDebug82.completion105 =
            ZygorClassic_CompletionSummary105 and ZygorClassic_CompletionSummary105() or "-"
    end
end

local ZygorClassic_SettledUpdate94_Base106=ZygorClassic_SettledUpdate94
ZygorClassic_SettledUpdate94=function()
    ZygorClassic_SettledUpdate94_Base106()
    ZygorClassic_RefreshCompletion106()
    if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
end


-- TEST107: polling progress engine.
-- TEST106 exposed that relying only on quest events can leave counters stale.
-- Poll the actual Vanilla quest log every 0.25s and drive both diagnostics
-- and automatic step progression from the live leaderboard state.

ZygorClassicDebug82 = ZygorClassicDebug82 or {}
ZygorClassicDebug82.poll107 = 0
ZygorClassicDebug82.pollSnapshot107 = "-"

local function ZygorClassic_PollProgress107()
    if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return end
    if table.getn(ZygorGuidesViewer.registeredguides) < 1 then return end

    -- Keep the correct active-quest route first.
    if ZygorClassic_InitialRoute83 then
        ZygorClassic_InitialRoute83()
    end

    local guide = ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return end

    local idx = ZygorClassicStepIndex or 1
    local step = guide.classic_steps and guide.classic_steps[idx]

    ZygorClassicDebug82.poll107 = (ZygorClassicDebug82.poll107 or 0) + 1
    ZygorClassicDebug82.pollSnapshot107 =
        ZygorClassic_LeaderboardSnapshot95 and ZygorClassic_LeaderboardSnapshot95() or "-"

    -- Track visible objective changes from live leaderboard data.
    if ZygorClassic_RecordChange103 then
        ZygorClassic_RecordChange103()
    elseif ZygorClassic_KillTransition104 then
        ZygorClassic_KillTransition104()
    end

    -- Advance only when the freshly-polled current step is actually resolved.
    if step and ZygorClassic_StepResolved78 and ZygorClassic_StepResolved78(guide,step) then
        local target = ZygorClassic_NextApplicable89 and ZygorClassic_NextApplicable89(guide,idx) or idx
        if target ~= idx then
            ZygorClassicStepIndex = target
            ZygorClassicDebug82.route = tostring(idx).." -> "..tostring(target)
            if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
        end
    else
        if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
    end

    if ZygorClassic_Render then ZygorClassic_Render() end
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
end

if not ZygorClassicPoll107Frame then
    ZygorClassicPoll107Frame = CreateFrame("Frame","ZygorClassicPoll107Frame",UIParent)
    ZygorClassicPoll107Frame.elapsed = 0
    ZygorClassicPoll107Frame:SetScript("OnUpdate",function()
        this.elapsed = (this.elapsed or 0) + (arg1 or 0)
        if this.elapsed < 0.25 then return end
        this.elapsed = 0
        ZygorClassic_PollProgress107()
    end)
end

-- Append polling diagnostics so a single screenshot tells us whether the
-- live quest log is being sampled even if no WoW quest event fires.
local ZygorClassic_UpdateDebug82_Base107 = ZygorClassic_UpdateDebug82
ZygorClassic_UpdateDebug82 = function()
    if ZygorClassic_UpdateDebug82_Base107 then
        ZygorClassic_UpdateDebug82_Base107()
    end
    if ZygorClassicDebugText82 then
        local t = ZygorClassicDebugText82:GetText() or ""
        if not string.find(t,"Polls:",1,true) then
            t = t.."\nPolls: "..tostring(ZygorClassicDebug82.poll107 or 0)..
                "\nPoll snapshot: "..tostring(ZygorClassicDebug82.pollSnapshot107 or "-")
        end
        ZygorClassicDebugText82:SetText(t)
    end
end


-- TEST109: polling confirmed working.
-- TEST107 screenshot proves polling reads the true live state (5/6 + 1/6).
-- Keep polling as authoritative and make completion summary refresh directly
-- from each poll rather than stale event-only diagnostics.

local ZygorClassic_PollProgress107_Base109=ZygorClassic_PollProgress107
ZygorClassic_PollProgress107=function()
    ZygorClassic_PollProgress107_Base109()

    if ZygorClassicDebug82 then
        if ZygorClassic_CompletionSummary105 then
            ZygorClassicDebug82.completion105=ZygorClassic_CompletionSummary105()
        end
        ZygorClassicDebug82.event="POLL (live)"
    end

    if ZygorClassic_UpdateDebug82 then
        ZygorClassic_UpdateDebug82()
    end
end


-- TEST110: partial completion lock.
-- TEST109 proves polling is authoritative: Rockjaw 6/6 DONE, Burly 1/6 TODO,
-- completion summary 1/2 DONE, and Step 9 correctly remains unresolved.
-- Preserve that behavior and explicitly expose whether automatic advancement
-- is currently blocked by remaining objectives.

ZygorClassicDebug82=ZygorClassicDebug82 or {}
ZygorClassicDebug82.advance110="BLOCKED"

local function ZygorClassic_AdvanceState110()
    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local idx=ZygorClassicStepIndex or 1
    local step=guide and guide.classic_steps and guide.classic_steps[idx]
    if guide and step and ZygorClassic_StepResolved78 then
        ZygorClassicDebug82.advance110 =
            ZygorClassic_StepResolved78(guide,step) and "READY" or "BLOCKED"
    else
        ZygorClassicDebug82.advance110="UNKNOWN"
    end
end

local ZygorClassic_PollProgress107_Base110=ZygorClassic_PollProgress107
ZygorClassic_PollProgress107=function()
    ZygorClassic_PollProgress107_Base110()
    ZygorClassic_AdvanceState110()
end

local ZygorClassic_UpdateDebug82_Base110=ZygorClassic_UpdateDebug82
ZygorClassic_UpdateDebug82=function()
    ZygorClassic_AdvanceState110()
    if ZygorClassic_UpdateDebug82_Base110 then ZygorClassic_UpdateDebug82_Base110() end
    if ZygorClassicDebugText82 then
        local t=ZygorClassicDebugText82:GetText() or ""
        if not string.find(t,"Auto advance:",1,true) then
            t=t.."\nAuto advance: "..tostring(ZygorClassicDebug82.advance110 or "UNKNOWN")
        end
        ZygorClassicDebugText82:SetText(t)
    end
end


-- TEST111: turn-in step validation.
-- TEST110 successfully advanced Step 9 -> Step 10 when both objectives hit
-- 6/6. Step 10 is a turn-in/ding step, so expose turn-in readiness separately
-- from objective completion and keep polling authoritative.

ZygorClassicDebug82=ZygorClassicDebug82 or {}
ZygorClassicDebug82.turnin111="-"

local function ZygorClassic_TurninState111()
    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local step=guide and guide.classic_steps and guide.classic_steps[ZygorClassicStepIndex or 1]
    if not step then return "-" end

    local i
    for i=1,table.getn(step.raw or {}) do
        local line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(step.raw[i]) or step.raw[i]
        local title,kind,questID=nil,nil,nil
        if ZygorClassic_ParseQuestDirective then title,kind,questID=ZygorClassic_ParseQuestDirective(line) end
        if title and kind=="turnin" then
            if not questID and ZygorClassic_DirectiveIDForStep309 then
                questID=ZygorClassic_DirectiveIDForStep309(step,title,kind)
            end
            if questID and ZygorClassic_QuestIDTurnedIn216 and
               ZygorClassic_QuestIDTurnedIn216(questID) then
                return title.." [TURNED IN]"
            end
            local qi
            for qi=1,GetNumQuestLogEntries() do
                local qt,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(qi)
                if qt and not isHeader and
                   ZygorClassic_NormalizeQuestTitle170(qt)==ZygorClassic_NormalizeQuestTitle170(title) then
                    return title.." ["..((isComplete==1) and "READY" or "NOT READY").."]"
                end
            end
            if ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title) then
                return title.." [TURNED IN]"
            end
            return title.." [NOT IN LOG]"
        end
    end
    return "none"
end

local ZygorClassic_UpdateDebug82_Base111=ZygorClassic_UpdateDebug82
ZygorClassic_UpdateDebug82=function()
    ZygorClassicDebug82.turnin111=ZygorClassic_TurninState111()
    if ZygorClassic_UpdateDebug82_Base111 then ZygorClassic_UpdateDebug82_Base111() end
    if ZygorClassicDebugText82 then
        local t=ZygorClassicDebugText82:GetText() or ""
        if not string.find(t,"Turn-in state:",1,true) then
            t=t.."\nTurn-in state: "..tostring(ZygorClassicDebug82.turnin111 or "-")
        end
        ZygorClassicDebugText82:SetText(t)
    end
end


-- TEST112: turn-in advancement.
-- TEST111 proves Step 10 correctly detects A New Threat [READY].
-- After the quest disappears from the log and is recorded as turned in,
-- advance to the next applicable step and persist/render it.

local function ZygorClassic_TurninResolved112(guide,step)
    if not step then return false end
    local i
    for i=1,table.getn(step.raw or {}) do
        local line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(step.raw[i]) or step.raw[i]
        local title,kind=nil,nil
        if ZygorClassic_ParseQuestDirective then title,kind=ZygorClassic_ParseQuestDirective(line) end
        if title and kind=="turnin" then
            if ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title) then
                return true,title
            end
            return false,title
        end
    end
    return false,nil
end

local ZygorClassic_PollProgress107_Base112=ZygorClassic_PollProgress107
ZygorClassic_PollProgress107=function()
    ZygorClassic_PollProgress107_Base112()

    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local idx=ZygorClassicStepIndex or 1
    local step=guide and guide.classic_steps and guide.classic_steps[idx]
    local done,title=ZygorClassic_TurninResolved112(guide,step)

    if done then
        local target=ZygorClassic_NextApplicable89 and ZygorClassic_NextApplicable89(guide,idx) or idx
        if target~=idx then
            ZygorClassicStepIndex=target
            ZygorClassicDebug82.route=tostring(idx).." -> "..tostring(target).." (turnin "..tostring(title)..")"
            if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
            if ZygorClassic_Render then ZygorClassic_Render() end
            if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
            if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
        end
    end
end


-- TEST113: turn-in chain lock.
-- TEST112 successfully advanced after A New Threat turn-in, but an older route
-- selector jumped to Step 15 because Consecrated Rune is also READY. After a
-- witnessed turn-in, preserve sequential guide order instead of re-routing to
-- another active quest farther ahead.

ZygorClassicDebug82=ZygorClassicDebug82 or {}
ZygorClassicDebug82.sequential113=false
ZygorClassicDebug82.sequentialFrom113=nil

local ZygorClassic_TurninResolved112_Base113=ZygorClassic_TurninResolved112

-- Wrap the turn-in advancement so entering the next step enables sequential mode.
local ZygorClassic_PollProgress107_Base113=ZygorClassic_PollProgress107
ZygorClassic_PollProgress107=function()
    local before=ZygorClassicStepIndex or 1
    ZygorClassic_PollProgress107_Base113()
    local after=ZygorClassicStepIndex or 1

    if after~=before and ZygorClassicDebug82 and
       ZygorClassicDebug82.route and
       string.find(ZygorClassicDebug82.route,"turnin",1,true) then
        ZygorClassicDebug82.sequential113=true
        ZygorClassicDebug82.sequentialFrom113=after
    end
end

-- Once a real turn-in has advanced us, do not let the broad "earliest active
-- quest" recovery router jump forward over intervening guide steps.
local ZygorClassic_InitialRoute83_Base113=ZygorClassic_InitialRoute83
ZygorClassic_InitialRoute83=function()
    if ZygorClassicDebug82 and ZygorClassicDebug82.sequential113 then
        return false
    end
    return ZygorClassic_InitialRoute83_Base113()
end

-- One-time correction for the current TEST112 state: A New Threat is gone,
-- Step 15 was selected because Consecrated Rune is ready. Return to the next
-- applicable step after Step 10.
if not ZygorClassicCorrect113Frame then
    ZygorClassicCorrect113Frame=CreateFrame("Frame","ZygorClassicCorrect113Frame",UIParent)
    ZygorClassicCorrect113Frame.elapsed=0
    ZygorClassicCorrect113Frame:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<2.0 then return end
        this.elapsed=0

        if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return end
        local guide=ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
        if not guide or not ZygorClassic_EnsureParsed(guide) then return end

        local aNewThreatInLog=false
        local i
        for i=1,GetNumQuestLogEntries() do
            local qt,level,tag,isHeader=GetQuestLogTitle(i)
            if qt=="A New Threat" and not isHeader then aNewThreatInLog=true end
        end

        if not aNewThreatInLog and (ZygorClassicStepIndex or 1)>10 then
            local target=ZygorClassic_NextApplicable89 and ZygorClassic_NextApplicable89(guide,10) or 11
            ZygorClassicStepIndex=target
            ZygorClassicDebug82.sequential113=true
            ZygorClassicDebug82.sequentialFrom113=target
            ZygorClassicDebug82.route="10 -> "..tostring(target).." (sequential after turnin)"
            if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
            if ZygorClassic_Render then ZygorClassic_Render() end
            if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
            if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
        end
        this:Hide()
    end)
end

local ZygorClassic_UpdateDebug82_Base113=ZygorClassic_UpdateDebug82
ZygorClassic_UpdateDebug82=function()
    if ZygorClassic_UpdateDebug82_Base113 then ZygorClassic_UpdateDebug82_Base113() end
    if ZygorClassicDebugText82 then
        local t=ZygorClassicDebugText82:GetText() or ""
        if not string.find(t,"Sequential mode:",1,true) then
            t=t.."\nSequential mode: "..((ZygorClassicDebug82.sequential113 and "ON") or "OFF")
        end
        ZygorClassicDebugText82:SetText(t)
    end
end


-- TEST114: sequential render lock.
-- TEST113 proves sequential mode is ON and the correction selected Step 11,
-- but another later writer/render path still puts authoritative state back at
-- Step 15. Store the sequential step separately and reassert it on every poll
-- before render/routing.

ZygorClassicDebug82=ZygorClassicDebug82 or {}
if ZygorClassicDebug82.sequential113 and not ZygorClassicDebug82.sequentialStep114 then
    ZygorClassicDebug82.sequentialStep114=ZygorClassicDebug82.sequentialFrom113 or 11
end

local function ZygorClassic_AssertSequential114()
    if not ZygorClassicDebug82 or not ZygorClassicDebug82.sequential113 then return end
    local seq=ZygorClassicDebug82.sequentialStep114 or ZygorClassicDebug82.sequentialFrom113
    if seq and (ZygorClassicStepIndex or 1)~=seq then
        ZygorClassicStepIndex=seq
        if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
    end
end

-- Reassert sequential state before and after the polling engine.
local ZygorClassic_PollProgress107_Base114=ZygorClassic_PollProgress107
ZygorClassic_PollProgress107=function()
    ZygorClassic_AssertSequential114()
    ZygorClassic_PollProgress107_Base114()
    ZygorClassic_AssertSequential114()

    if ZygorClassic_Render then ZygorClassic_Render() end
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
end

-- Current-state recovery: TEST113 screenshot shows route says 10 -> 11 while
-- authoritative is 15. Lock to 11 immediately after startup.
if not ZygorClassicCorrect114Frame then
    ZygorClassicCorrect114Frame=CreateFrame("Frame","ZygorClassicCorrect114Frame",UIParent)
    ZygorClassicCorrect114Frame.elapsed=0
    ZygorClassicCorrect114Frame:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<1.0 then return end
        this.elapsed=0

        if ZygorClassicDebug82 and ZygorClassicDebug82.sequential113 then
            ZygorClassicDebug82.sequentialStep114=
                ZygorClassicDebug82.sequentialFrom113 or 11
            ZygorClassic_AssertSequential114()
            ZygorClassicDebug82.route="sequential lock -> "..tostring(ZygorClassicStepIndex or "?")
            if ZygorClassic_Render then ZygorClassic_Render() end
            if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
            if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
        end
        this:Hide()
    end)
end

local ZygorClassic_UpdateDebug82_Base114=ZygorClassic_UpdateDebug82
ZygorClassic_UpdateDebug82=function()
    if ZygorClassic_UpdateDebug82_Base114 then ZygorClassic_UpdateDebug82_Base114() end
    if ZygorClassicDebugText82 then
        local t=ZygorClassicDebugText82:GetText() or ""
        if not string.find(t,"Sequential target:",1,true) then
            t=t.."\nSequential target: "..tostring(ZygorClassicDebug82.sequentialStep114 or "-")
        end
        ZygorClassicDebugText82:SetText(t)
    end
end


-- TEST115: sequential accept-step progression.
-- TEST114 proves sequential lock is now authoritative at Step 11.
-- Step 11 contains "accept A Refugee's Quandary". Advance sequential target
-- only after the accept directive is actually satisfied.

local function ZygorClassic_AcceptResolved115(step)
    if not step then return false,nil end
    local sawAccept=false
    local acceptedTitles=""
    local i
    for i=1,table.getn(step.raw or {}) do
        local line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(step.raw[i]) or step.raw[i]
        local title,kind,questID=nil,nil,nil
        if ZygorClassic_ParseQuestDirective then title,kind,questID=ZygorClassic_ParseQuestDirective(line) end
        if title and kind=="accept" then
            sawAccept=true
            if not questID and ZygorClassic_DirectiveIDForStep309 then
                questID=ZygorClassic_DirectiveIDForStep309(step,title,kind)
            end
            -- TEST309: Vanilla removes Zygor's numbered suffix from the live
            -- title.  On a turn-in/accept handoff such as Bashal'Aran (1) ->
            -- Bashal'Aran (2), part (1) must not satisfy part (2).
            if ZygorClassic_ChainBarrier309 and
               ZygorClassic_ChainBarrier309(step,title,questID) then
                return false,title
            end
            local found=false
            local qi
            for qi=1,GetNumQuestLogEntries() do
                local qt,level,tag,isHeader=GetQuestLogTitle(qi)
                if qt and not isHeader and
                   ZygorClassic_NormalizeQuestTitle170(qt)==ZygorClassic_NormalizeQuestTitle170(title) then
                    found=true
                    break
                end
            end
            if not found then return false,title end
            if acceptedTitles~="" then acceptedTitles=acceptedTitles..", " end
            acceptedTitles=acceptedTitles..title
        end
    end
    return sawAccept,acceptedTitles
end

local ZygorClassic_PollProgress107_Base115=ZygorClassic_PollProgress107
ZygorClassic_PollProgress107=function()
    ZygorClassic_PollProgress107_Base115()

    if not ZygorClassicDebug82 or not ZygorClassicDebug82.sequential113 then return end

    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local idx=ZygorClassicStepIndex or 1
    local step=guide and guide.classic_steps and guide.classic_steps[idx]
    local accepted,title=ZygorClassic_AcceptResolved115(step)

    if accepted then
        local target=ZygorClassic_NextApplicable89 and ZygorClassic_NextApplicable89(guide,idx) or idx
        if target~=idx then
            ZygorClassicDebug82.sequentialStep114=target
            ZygorClassicStepIndex=target
            ZygorClassicDebug82.route=tostring(idx).." -> "..tostring(target).." (accepted "..tostring(title)..")"
            if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
            if ZygorClassic_Render then ZygorClassic_Render() end
            if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
            if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
        end
    end
end

local ZygorClassic_UpdateDebug82_Base115=ZygorClassic_UpdateDebug82
ZygorClassic_UpdateDebug82=function()
    if ZygorClassic_UpdateDebug82_Base115 then ZygorClassic_UpdateDebug82_Base115() end
    if ZygorClassicDebugText82 then
        local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                    ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
        local step=guide and guide.classic_steps and guide.classic_steps[ZygorClassicStepIndex or 1]
        local ok,title=ZygorClassic_AcceptResolved115(step)
        local t=ZygorClassicDebugText82:GetText() or ""
        if not string.find(t,"Accept state:",1,true) then
            t=t.."\nAccept state: "..tostring(title or "none").." ["..(ok and "ACCEPTED" or "WAITING").."]"
        end
        ZygorClassicDebugText82:SetText(t)
    end
end


-- TEST126: clean baseline + visible build version.
-- No arrow experiments loaded. Quest progression remains from TEST115.

ZYGOR_BACKPORT_VERSION = "TEST126"

if not ZygorBuildVersion126 then
    ZygorBuildVersion126 = CreateFrame("Frame","ZygorBuildVersion126",UIParent)
    ZygorBuildVersion126:SetWidth(260)
    ZygorBuildVersion126:SetHeight(20)
    ZygorBuildVersion126:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -10)

    local text = ZygorBuildVersion126:CreateFontString(nil,"OVERLAY","GameFontNormal")
    text:SetPoint("TOPLEFT", ZygorBuildVersion126, "TOPLEFT", 0, 0)
    text:SetText("Zygor Backport "..ZYGOR_BACKPORT_VERSION)
    ZygorBuildVersion126.text = text
end






-- TEST140 PFQUEST STYLE PORT START
-- Stop using custom SetPoint experiments.
-- This revision uses the existing built-in waypoint selection only and prepares
-- a safe hook point for importing PFQuest/Questie arrow behavior.

ZygorArrowTestVersion = "TEST140"

-- Intentionally no custom frame creation.
-- Next step is direct port of PFQuest arrow implementation.




-- TEST149 BUILTIN WAYPOINT TRACE
-- Diagnostic only. Does not create UI or alter waypoint behavior.

ZygorWaypointTrace149 = {}

local function ZygorTraceWaypoint149()
    local found = {}

    local checks = {
        "ZygorWaypoint",
        "ZygorWaypointFrame",
        "ZygorWaypointArrow",
        "Zygor_SetWaypoint",
        "ZygorGuidesViewer",
        "ZGV",
        "SetWaypoint",
    }

    local i,n
    for i,n in ipairs(checks) do
        if _G[n] then
            table.insert(found,n)
        end
    end

    if ZygorClassicDebug82 then
        ZygorClassicDebug82.waypoint149 = "Objects: "..table.concat(found,", ")
    end
end

if not ZygorWaypointTraceFrame149 then
    ZygorWaypointTraceFrame149 = CreateFrame("Frame")
    ZygorWaypointTraceFrame149.elapsed = 0
    ZygorWaypointTraceFrame149:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed > 3 then
            this.elapsed = 0
            ZygorTraceWaypoint149()
        end
    end)
end


-- TEST150 WAYPOINT TRACE 2
-- Expands the scan to include known Zygor waypoint globals without changing UI.

local function ZygorWaypointTrace150()
    ZygorClassicDebug82 = ZygorClassicDebug82 or {}

    local found = {}

    local checks = {
        "ZGV",
        "ZGV_Waypoint",
        "ZGV_WaypointArrow",
        "ZGV_ShowWaypoint",
        "ZGV_SetWaypoint",
        "ZygorWaypoint",
        "ZygorWaypointFrame",
        "ZygorArrow",
        "WaypointFrame",
        "WaypointArrow",
    }

    local i,n
    for i,n in ipairs(checks) do
        if _G[n] then
            table.insert(found,n)
        end
    end

    ZygorClassicDebug82.waypoint150 = "Found: "..table.concat(found,", ")
end

if not ZygorWaypointTraceTimer150 then
    ZygorWaypointTraceTimer150 = CreateFrame("Frame")
    ZygorWaypointTraceTimer150.elapsed = 0
    ZygorWaypointTraceTimer150:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed > 3 then
            this.elapsed = 0
            ZygorWaypointTrace150()
        end
    end)
end


-- TEST151 WAYPOINT MODULE SCAN
-- Search loaded globals and addon state for built-in waypoint components.

local function ZygorWaypointModuleScan151()
    ZygorClassicDebug82 = ZygorClassicDebug82 or {}

    local found = {}

    local checks = {
        "ZGV",
        "ZGVFrame",
        "ZGVFramePointer",
        "ZGV.Pointer",
        "Pointer",
        "Waypoint",
        "Waypointing",
        "BuiltIn",
        "TomTom",
    }

    for _,name in ipairs(checks) do
        if _G[name] then
            table.insert(found,name)
        end
    end

    ZygorClassicDebug82.waypoint151 = "Modules: "..table.concat(found,", ")
end

if not ZygorWaypointModuleScanFrame151 then
    ZygorWaypointModuleScanFrame151 = CreateFrame("Frame")
    ZygorWaypointModuleScanFrame151.elapsed = 0
    ZygorWaypointModuleScanFrame151:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed > 3 then
            this.elapsed = 0
            ZygorWaypointModuleScan151()
        end
    end)
end


-- TEST152 POINTER TRACE
-- Finds loaded addon modules related to pointer/arrow/waypoint.

local function ZygorPointerTrace152()
    ZygorClassicDebug82 = ZygorClassicDebug82 or {}

    local result = {}

    local files = {
        "Pointer.lua",
        "Arrow.lua",
        "Waypoint.lua",
        "Waypointing.lua",
        "ZygorGuidesViewerPointer.lua",
        "ZygorGuidesViewerPointer",
        "GuidePointer",
    }

    for _,v in ipairs(files) do
        if _G[v] then
            table.insert(result,v)
        end
    end

    ZygorClassicDebug82.pointer152 = "Pointer objects: "..table.concat(result,", ")
end

if not ZygorPointerTraceFrame152 then
    ZygorPointerTraceFrame152 = CreateFrame("Frame")
    ZygorPointerTraceFrame152.elapsed = 0
    ZygorPointerTraceFrame152:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed > 3 then
            this.elapsed = 0
            ZygorPointerTrace152()
        end
    end)
end


-- TEST163: native Zygor pointer diagnostics in the existing right-side panel.
-- This does not create another arrow or change waypoint selection.
ZYGOR_BACKPORT_VERSION = "TEST163"

local function ZygorPointerSafe163(fn)
    local ok,value=pcall(fn)
    if ok then return tostring(value) end
    return "ERR:"..tostring(value)
end

local ZygorClassic_UpdateDebug82_Base163=ZygorClassic_UpdateDebug82
ZygorClassic_UpdateDebug82=function()
    if ZygorClassic_UpdateDebug82_Base163 then ZygorClassic_UpdateDebug82_Base163() end
    if not ZygorClassicDebugText82 then return end

    local d=ZygorPointerDebug163 or {}
    local p=ZygorGuidesViewer and ZygorGuidesViewer.Pointer
    local f=p and p.ArrowFrame
    local ctrl=p and p.ArrowFrameCtrl
    local wp=f and f.waypoint
    local pos="-"
    if f then
        pos=ZygorPointerSafe163(function()
            return tostring(math.floor((f:GetLeft() or -1)+0.5))..","..
                   tostring(math.floor((f:GetBottom() or -1)+0.5))
        end)
    end
    local tex="-"
    if f and f.arrow then
        tex=ZygorPointerSafe163(function() return f.arrow:GetTexture() or "nil" end)
    end

    local extra="\n\nTEST189 NATIVE POINTER"..
        "\nModule/ready: "..(p and "YES" or "NO").." / "..tostring(p and p.ready)..
        "\nStartup: "..tostring(d.startup or "no breadcrumbs")..
        "\nWaypoint: "..(wp and (tostring(wp.c)..","..tostring(wp.z).." "..tostring(wp.x)..","..tostring(wp.y)) or "nil")..
        "\nTicks ctrl/arrow: "..tostring(d.ctrlTicks or 0).." / "..tostring(d.arrowTicks or 0)..
        "\nShow calls/state: "..tostring(d.showCalls or 0).." / "..tostring(d.state or "-")..
        "\nFacing child/value: "..tostring(d.facingChild or "-").." / "..tostring(d.facing or "-")..
        "\nBridge: "..tostring(d.bridge or "waiting")
    ZygorClassicDebugText82:SetText((ZygorClassicDebugText82:GetText() or "")..extra)
end


-- TEST164: bridge the authoritative Classic backport route into the original
-- Zygor pointer.  The backport renderer uses ZygorClassic_CurrentGoto55(),
-- while the legacy Pointer module only receives calls through Waypoints.lua;
-- those two paths were never connected.
local ZygorPointerBridgeKey164=nil

local function ZygorPointerBridge164()
    ZygorPointerDebug163=ZygorPointerDebug163 or {}
    local p=ZygorGuidesViewer and ZygorGuidesViewer.Pointer
    if not p or not p.ready or not p.ArrowFrame then
        ZygorPointerDebug163.bridge="pointer not ready"
        return
    end
    if not ZygorClassic_CurrentGoto55 then
        ZygorPointerDebug163.bridge="route function missing"
        return
    end

    local map,x,y=ZygorClassic_CurrentGoto55()
    if not x or not y then
        if ZygorPointerBridgeKey164 then
            p:ClearWaypoints("way")
            ZygorPointerBridgeKey164=nil
        end
        ZygorPointerDebug163.bridge="no active goto"
        return
    end

    local key=tostring(map or "")..":"..tostring(x)..":"..tostring(y)
    if key==ZygorPointerBridgeKey164 and p.ArrowFrame.waypoint then
        ZygorPointerDebug163.bridge="active "..key
        return
    end

    p:ClearWaypoints("way")
    local ok,way=pcall(function()
        return p:SetWaypoint(nil,map,x,y,{
            title="Zygor Waypoint",
            type="way",
            onminimap="always",
            overworld=true,
            persistent=true
        })
    end)
    if ok and way then
        ZygorPointerBridgeKey164=key
        ZygorPointerDebug163.bridge="connected "..key
    elseif ok then
        ZygorPointerDebug163.bridge="SetWaypoint returned nil"
    else
        ZygorPointerDebug163.bridge="ERROR "..tostring(way)
    end
end

if not ZygorPointerBridgeFrame164 then
    ZygorPointerBridgeFrame164=CreateFrame("Frame","ZygorPointerBridgeFrame164",UIParent)
    ZygorPointerBridgeFrame164.elapsed=0
    ZygorPointerBridgeFrame164:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.25 then return end
        this.elapsed=0
        ZygorPointerBridge164()
    end)
end

ZYGOR_BACKPORT_VERSION = "TEST168"


-- TEST169: prevent legacy recovery routers from jumping over unresolved
-- sequential steps. Only the single next class/race-applicable step may be
-- entered from the current sequential target.
if not ZygorSequentialGuard169 then
    ZygorSequentialGuard169=CreateFrame("Frame","ZygorSequentialGuard169",UIParent)
    ZygorSequentialGuard169.elapsed=0
    ZygorSequentialGuard169:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.10 then return end
        this.elapsed=0
        if not ZygorClassicDebug82 or not ZygorClassicDebug82.sequential113 then return end
        local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                    ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
        if not guide or not guide.classic_steps then return end
        local seq=ZygorClassicDebug82.sequentialStep114 or ZygorClassicStepIndex or 1
        local allowed=ZygorClassic_NextApplicable89 and ZygorClassic_NextApplicable89(guide,seq) or (seq+1)
        local current=ZygorClassicStepIndex or 1
        if current>allowed then
            ZygorClassicStepIndex=allowed
            ZygorClassicDebug82.sequentialStep114=allowed
            ZygorClassicDebug82.route=tostring(current).." -> "..tostring(allowed).." (TEST169 leap guard)"
            if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
            if ZygorClassic_Render then ZygorClassic_Render() end
            if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
            if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
        end
    end)
end

ZYGOR_BACKPORT_VERSION = "TEST169"


-- TEST170: expanded diagnostic workspace. Keep both columns and all appended
-- pointer/progression diagnostics inside the visible frame at common 1.12
-- resolutions.
if ZygorGuidesViewerFrame then
    ZygorGuidesViewerFrame:SetWidth(900)
    ZygorGuidesViewerFrame:SetHeight(700)
end
if ZygorGuidesViewerFrameMaster then
    ZygorGuidesViewerFrameMaster:SetWidth(900)
    ZygorGuidesViewerFrameMaster:SetHeight(700)
end
if ZygorClassicDebugText82 and ZygorGuidesViewerFrame then
    ZygorClassicDebugText82:ClearAllPoints()
    ZygorClassicDebugText82:SetPoint("TOPLEFT",ZygorGuidesViewerFrame,"TOPLEFT",455,-58)
    ZygorClassicDebugText82:SetWidth(420)
    ZygorClassicDebugText82:SetFont("Fonts\\FRIZQT__.TTF",11)
end

ZYGOR_BACKPORT_VERSION = "TEST170"


-- TEST171: never select a turn-in step for a quest that is still active and
-- incomplete. Rewind to the preceding applicable objective/travel step.
local function ZygorClassic_NotReadyTurnin171(step)
    local i
    for i=1,table.getn(step and step.raw or {}) do
        local line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(step.raw[i]) or step.raw[i]
        local title,kind=nil,nil
        if ZygorClassic_ParseQuestDirective then title,kind=ZygorClassic_ParseQuestDirective(line) end
        if title and kind=="turnin" then
            local wanted=ZygorClassic_NormalizeQuestTitle170(title)
            local qi
            for qi=1,GetNumQuestLogEntries() do
                local qt,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(qi)
                if qt and not isHeader and ZygorClassic_NormalizeQuestTitle170(qt)==wanted then
                    if isComplete~=1 and isComplete~=true then return title end
                    return nil
                end
            end
        end
    end
    return nil
end

if not ZygorTurninGuard171 then
    ZygorTurninGuard171=CreateFrame("Frame","ZygorTurninGuard171",UIParent)
    ZygorTurninGuard171.elapsed=0
    ZygorTurninGuard171:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.15 then return end
        this.elapsed=0
        local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                    ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
        local idx=ZygorClassicStepIndex or 1
        local step=guide and guide.classic_steps and guide.classic_steps[idx]
        local title=ZygorClassic_NotReadyTurnin171(step)
        if not title then return end
        local target=idx-1
        while target>1 and ZygorClassic_StepApplies67 and
              not ZygorClassic_StepApplies67(guide.classic_steps[target]) do
            target=target-1
        end
        if target<idx then
            ZygorClassicStepIndex=target
            if ZygorClassicDebug82 then
                ZygorClassicDebug82.sequential113=true
                ZygorClassicDebug82.sequentialStep114=target
                ZygorClassicDebug82.route=tostring(idx).." -> "..tostring(target)..
                    " (not-ready turnin "..tostring(title)..")"
            end
            if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
            if ZygorClassic_Render then ZygorClassic_Render() end
            if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
            if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
        end
    end)
end

ZYGOR_BACKPORT_VERSION = "TEST171"


-- TEST172: one authoritative sequential state machine. Older recovery/event
-- paths may still run, but this engine owns and reasserts the actual step.
local function ZygorClassic_QuestLog172()
    local result={}
    local i
    for i=1,GetNumQuestLogEntries() do
        local title,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(i)
        if title and not isHeader then
            local objectiveCount=0
            if GetNumQuestLeaderBoards then
                objectiveCount=GetNumQuestLeaderBoards(i) or 0
            end
            result[ZygorClassic_NormalizeQuestTitle170(title)]={
                title=title,
                complete=(isComplete==1 or isComplete==true),
                objectiveCount=objectiveCount,
                index=i,
                questID=ZygorClassic_InferLiveQuestID310 and
                        ZygorClassic_InferLiveQuestID310(title,i) or nil
            }
        end
    end
    return result
end

local function ZygorClassic_ObjectiveOwner178(guide,stepIndex,objectiveLine)
    if not guide or not guide.classic_steps or not stepIndex then return nil,nil end

    -- Read the quest ID directly from the objective's original guide line.
    -- This avoids relying on the older derived objective map, which may not
    -- contain an entry after a completed quest has left the live quest log.
    local step=guide.classic_steps[stepIndex]
    local qid=nil
    local objectiveIndex=nil
    local i,j
    for i=1,table.getn((step and step.source) or {}) do
        local sourceLine=ZygorClassic_CleanDirective62 and
                         ZygorClassic_CleanDirective62(step.source[i]) or step.source[i]
        local sameObjective=(not objectiveLine) or
                            string.find(sourceLine,tostring(objectiveLine),1,true)==1
        -- Use string.find captures directly. The Lua 5.0 string.match shim can
        -- return a match position here instead of capture 1 (observed as 25).
        local matchStart,matchEnd,found,foundObjective=
            string.find(step.source[i],"|q%s*(%d+)%s*/%s*(%d+)")
        if found and sameObjective then
            qid=tonumber(found)
            objectiveIndex=tonumber(foundObjective)
            break
        end
    end
    if not qid then return nil,nil,nil end

    -- Resolve that stable ID back to the guide's quest title. Either accept
    -- or turnin metadata can supply it, so this works across the full guide.
    for i=1,table.getn(guide.classic_steps) do
        local source=guide.classic_steps[i].source or {}
        for j=1,table.getn(source) do
            local cleaned=string.gsub(source[j],"^%.+","")
            local title,kind,directiveID=ZygorClassic_ParseQuestDirective(cleaned)
            if title and directiveID==qid then
                return title,qid,objectiveIndex
            end
        end
    end
    return nil,qid,objectiveIndex
end

-- TEST229: score an objective only inside its guide-declared live quest. The
-- old global leaderboard search could borrow a completed row from another
-- quest and mark an unrelated |q objective complete.
local function ZygorClassic_ObjectiveStateForQuest229(line,quest,objectiveIndex)
    if not quest or not quest.index then return nil,false end
    -- TEST230: |q questID/objectiveIndex is stronger than text matching. Read
    -- that exact leaderboard slot first (771/2 Ambercorn vs 771/1 Well Stone).
    objectiveIndex=tonumber(objectiveIndex)
    if objectiveIndex then
        local exactText,exactType,exactFinished=
            GetQuestLogLeaderBoard(objectiveIndex,quest.index)
        if exactText then
            return exactText,(exactFinished==1 or exactFinished==true)
        end
    end
    local bestText=nil
    local bestDone=false
    local bestScore=0
    local count=GetNumQuestLeaderBoards and (GetNumQuestLeaderBoards(quest.index) or 0) or 0
    local i
    for i=1,count do
        local text,otype,finished=GetQuestLogLeaderBoard(i,quest.index)
        local score=ZygorClassic_SubjectScore91 and ZygorClassic_SubjectScore91(line,text) or 0
        if score>bestScore then
            bestScore=score
            bestText=text
            bestDone=(finished==1 or finished==true)
        end
    end
    if bestScore>0 then return bestText,bestDone end
    return nil,false
end

local function ZygorClassic_ItemCount197(itemID)
    itemID=tonumber(itemID)
    if not itemID then return 0 end
    local apiCount=nil
    if GetItemCount then
        local ok,count=pcall(GetItemCount,itemID)
        if ok and tonumber(count) then apiCount=tonumber(count) end
        -- Several Vanilla clients accept item names but not numeric IDs here.
        -- The name form also includes special containers such as the keyring
        -- even when GetContainerNumSlots(-2) is not exposed by the client UI.
        if GetItemInfo then
            local infoOK,itemName=pcall(GetItemInfo,itemID)
            if infoOK and itemName then
                local nameOK,nameCount=pcall(GetItemCount,itemName)
                if nameOK and tonumber(nameCount) and
                   (not apiCount or tonumber(nameCount)>apiCount) then
                    apiCount=tonumber(nameCount)
                end
            end
        end
    end
    local total=0
    local bag
    -- Vanilla's keyring is container -2.  Skip -1 (the bank) so guide
    -- inventory checks count carried keys and normal bags only.
    for bag=-2,4 do
        if bag~=-1 then
            local slots=GetContainerNumSlots and (GetContainerNumSlots(bag) or 0) or 0
            -- The 1.12 client exposes keyring capacity through a separate API;
            -- GetContainerNumSlots(KEYRING_CONTAINER) commonly returns zero.
            if bag==-2 and GetKeyRingSize then
                slots=GetKeyRingSize() or slots
            end
            local slot
            for slot=1,slots do
                local link=GetContainerItemLink and GetContainerItemLink(bag,slot)
                local found=nil
                if link then
                    local startPos,endPos,captured=string.find(link,"item:(%d+)")
                    found=tonumber(captured)
                end
                if found==itemID then
                    local texture,count=GetContainerItemInfo(bag,slot)
                    total=total+(tonumber(count) or 1)
                end
            end
        end
    end
    if apiCount and apiCount>total then return apiCount end
    return total
end

local function ZygorClassic_QuestTitleByID198(guide,qid)
    qid=tonumber(qid)
    if not qid or not guide or not guide.classic_steps then return nil end
    local i,j
    for i=1,table.getn(guide.classic_steps) do
        local source=guide.classic_steps[i].source or {}
        for j=1,table.getn(source) do
            local cleaned=string.gsub(source[j],"^%.+","")
            local title,kind,directiveID=ZygorClassic_ParseQuestDirective(cleaned)
            if title and tonumber(directiveID)==qid then return title end
        end
    end
    return nil
end

-- TEST329: the original goal engine understands `buy`, but the authoritative
-- Vanilla resolver below works from preserved guide source and previously
-- ignored purchase directives.  Resolve a purchased item by explicit ##ID
-- when present, otherwise use the trimmed item database to translate its
-- guide name to a stable Vanilla item ID.  GetItemCount(name) remains a final
-- fallback for custom guides whose item is not in the bundled database.
ZygorClassicBuyItemIDs329=ZygorClassicBuyItemIDs329 or {}
ZygorClassicBuyItemIndexReady329=ZygorClassicBuyItemIndexReady329 or false

function ZygorClassic_BuyItemID329(itemName,explicitID)
    explicitID=tonumber(explicitID)
    if explicitID then return explicitID end
    local key=string.lower(tostring(itemName or ""))
    key=string.gsub(key,"^%s+","")
    key=string.gsub(key,"%s+$","")
    if key=="" then return nil end
    if not ZygorClassicBuyItemIndexReady329 then
        local id,data
        for id,data in pairs((ZygorClassicQuestDB and ZygorClassicQuestDB.i) or {}) do
            if data and data.n then
                ZygorClassicBuyItemIDs329[string.lower(tostring(data.n))]=tonumber(id)
            end
        end
        ZygorClassicBuyItemIndexReady329=true
    end
    return ZygorClassicBuyItemIDs329[key]
end

function ZygorClassic_BuyItemCount329(itemName,itemID)
    itemID=ZygorClassic_BuyItemID329(itemName,itemID)
    if itemID then return ZygorClassic_ItemCount197(itemID),itemID end
    if GetItemCount then
        local ok,count=pcall(GetItemCount,itemName)
        if ok and tonumber(count) then return tonumber(count),nil end
    end
    return 0,nil
end

local function ZygorClassic_HomeKey203(target)
    target=string.lower(tostring(target or ""))
    target=string.gsub(target,"^%s+","")
    target=string.gsub(target,"%s+$","")
    return target
end

-- Vanilla reports some hearth binds by the inn building's name while the
-- guide names the settlement.  Keep that translation in one data-driven
-- table so every `home` directive uses the same comparison path.  Additional
-- client/server naming differences can be added here without quest logic.
local ZygorClassic_HomeAliases204={
    ["gallows' end tavern"]="brill",
    ["stoutlager inn"]="thelsamar",
    ["thunderbrew distillery"]="kharanos",
}

local function ZygorClassic_HomeCanonical204(target)
    target=ZygorClassic_HomeKey203(target)
    return ZygorClassic_HomeAliases204[target] or target
end

local function ZygorClassic_HomeResolved203(target,guideIndex,stepIndex)
    target=ZygorClassic_HomeCanonical204(target)
    local bound=ZygorClassic_HomeKey203(GetBindLocation and GetBindLocation() or "")
    local canonicalBound=ZygorClassic_HomeCanonical204(bound)
    if target~="" and (canonicalBound==target or string.find(canonicalBound,target,1,true) or string.find(target,canonicalBound,1,true)) then
        return true,bound
    end
    ZygorClassicDB=ZygorClassicDB or {}
    ZygorClassicDB.homeWitness203=ZygorClassicDB.homeWitness203 or {}
    local charKey=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
    local stepKey=tostring(guideIndex or ZygorClassicGuideIndex or 1)..":"..
                  tostring(stepIndex or ZygorClassicStepIndex or 1)
    local witnessed=ZygorClassicDB.homeWitness203[charKey] and
                    ZygorClassicDB.homeWitness203[charKey][stepKey]
    return ZygorClassic_HomeCanonical204(witnessed)==target,bound
end

-- Level-only guide steps are easy to lose because the display parser treats
-- most directives as ordinary text and the travel resolver may then complete
-- the step from nearby coordinates. Read the preserved source first and make
-- `ding N` an explicit state-machine prerequisite everywhere.
local function ZygorClassic_LevelRequirement212(step)
    if not step then return nil end
    local required=nil
    local function scan(lines)
        local i
        for i=1,table.getn(lines or {}) do
            local line=ZygorClassic_CleanDirective62 and
                       ZygorClassic_CleanDirective62(lines[i]) or lines[i]
            local lower=string.lower(tostring(line or ""))
            local startPos,endPos,captured=string.find(lower,"^ding%s+(%d+)")
            local level=tonumber(captured)
            if level and (not required or level>required) then required=level end
        end
    end
    scan(step.source)
    scan(step.raw)
    return required
end

-- TEST236: item-started quests commonly use an unowned display checkpoint
-- (`get Item|n`), followed by `use Item##id` and an accept on the same step.
-- Once that exact accepted quest is live, the item was necessarily obtained
-- and used; do not leave the untagged get line blocking behind it.  Correlate
-- the item names and same-step accept instead of naming an item, quest, or guide.
local function ZygorClassic_ItemStartAccepted236(step,line,quests)
    if not step or not line then return nil end
    local lower=string.lower(tostring(line or ""))
    local startPos,endPos,wanted=string.find(lower,"^get%s+(.+)$")
    if not wanted then return nil end
    -- The parser preserves the non-objective `|n` marker in raw display data,
    -- while the paired `|use Item##id` capture naturally ends at the item name.
    -- Remove trailing guide metadata before comparing those two representations.
    wanted=string.gsub(wanted,"|.*$","")
    wanted=string.gsub(wanted,"^%s+","")
    wanted=string.gsub(wanted,"%s+$","")

    local matchingUse=false
    local acceptedTitle=nil
    local i
    for i=1,table.getn(step.source or {}) do
        local source=tostring(step.source[i] or "")
        local sourceLower=string.lower(source)
        local useStart,useEnd,useName=string.find(sourceLower,"|use%s+([^#|]+)")
        if useName then
            useName=string.gsub(useName,"^%s+","")
            useName=string.gsub(useName,"%s+$","")
            if useName==wanted then matchingUse=true end
        end
        local cleaned=ZygorClassic_CleanDirective62 and
                      ZygorClassic_CleanDirective62(source) or source
        local title,kind=nil,nil
        if ZygorClassic_ParseQuestDirective then
            title,kind=ZygorClassic_ParseQuestDirective(cleaned)
        end
        if title and kind=="accept" and
           quests[ZygorClassic_NormalizeQuestTitle170(title)] then
            acceptedTitle=title
        end
    end
    if matchingUse and acceptedTitle then return acceptedTitle end
    return nil
end

-- TEST338: a completed same-step accept is durable proof that its preceding
-- setup actions happened.  This is needed for item-started quests because the
-- item is consumed before the resolver can poll inventory again (for example
-- collect envelope -> use envelope -> accept quest).  Require every accept on
-- the step so one accepted quest cannot hide another pending NPC offer.
function ZygorClassic_SameStepAcceptProof338(step,quests)
    if not step or not quests then return false,nil end
    local sawAccept=false
    local acceptedTitles=""
    local i
    for i=1,table.getn(step.source or {}) do
        local source=tostring(step.source[i] or "")
        local cleaned=ZygorClassic_CleanDirective62 and
                      ZygorClassic_CleanDirective62(source) or source
        local title,kind,questID=nil,nil,nil
        if ZygorClassic_ParseQuestDirective then
            title,kind,questID=ZygorClassic_ParseQuestDirective(cleaned)
        end
        if title and kind=="accept" then
            sawAccept=true
            local key=ZygorClassic_NormalizeQuestTitle170(title)
            local live=quests[key]~=nil
            local chainBlocked=ZygorClassic_ChainBarrier309 and
                               ZygorClassic_ChainBarrier309(step,title,questID)
            local durable=(questID and ZygorClassic_QuestIDTurnedIn216 and
                           ZygorClassic_QuestIDTurnedIn216(questID)) or
                          (not questID and ZygorClassic_TurnedIn62 and
                           ZygorClassic_TurnedIn62(title))
            if chainBlocked or (not live and not durable) then
                return false,title
            end
            if acceptedTitles~="" then acceptedTitles=acceptedTitles..", " end
            acceptedTitles=acceptedTitles..title
        end
    end
    return sawAccept,acceptedTitles
end

-- TEST238: Vanilla exposes a reliable completion signal for flight-path steps:
-- the current node in TAXIMAP_OPENED.  Store that node per character so an
-- `fpath Name` directive remains resolved after the taxi window closes/reload.
local function ZygorClassic_FlightPathKey238(name)
    name=string.lower(tostring(name or ""))
    name=string.gsub(name,",.*$","")
    name=string.gsub(name,"^%s+","")
    name=string.gsub(name,"%s+$","")
    -- TEST240: Vanilla taxi nodes may include a leading article even when the
    -- guide directive does not ("The Sepulcher" versus "Sepulcher").
    name=string.gsub(name,"^the%s+","")
    -- Vanilla's Stormwind taxi node is named "Stormwind, Elwynn", while
    -- leveling guides conventionally call the same destination "Stormwind
    -- City".  Normalize the city suffix before comparing recorded nodes.
    if name=="stormwind city" then name="stormwind" end
    return name
end

local function ZygorClassic_RecordCurrentFlightPath238()
    if not NumTaxiNodes or not TaxiNodeGetType or not TaxiNodeName then return nil end
    local i
    for i=1,(NumTaxiNodes() or 0) do
        if TaxiNodeGetType(i)=="CURRENT" then
            local name=TaxiNodeName(i)
            local pathKey=ZygorClassic_FlightPathKey238(name)
            if pathKey~="" then
                ZygorClassicDB=ZygorClassicDB or {}
                ZygorClassicDB.flightPaths238=ZygorClassicDB.flightPaths238 or {}
                local charKey=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
                ZygorClassicDB.flightPaths238[charKey]=ZygorClassicDB.flightPaths238[charKey] or {}
                ZygorClassicDB.flightPaths238[charKey][pathKey]=true
                return name
            end
        end
    end
    return nil
end

local function ZygorClassic_FlightPathKnown238(name)
    local wanted=ZygorClassic_FlightPathKey238(name)
    if wanted=="" then return false end
    local charKey=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
    local known=ZygorClassicDB and ZygorClassicDB.flightPaths238 and
                ZygorClassicDB.flightPaths238[charKey]
    if not known then return false end
    if known[wanted] then return true end
    -- Accept witnesses recorded by TEST238/239 before article normalization.
    -- This lets an existing "the sepulcher" record resolve immediately after
    -- replacing the addon, without requiring the taxi window to be reopened.
    local pathKey,value
    for pathKey,value in pairs(known) do
        if value and ZygorClassic_FlightPathKey238(pathKey)==wanted then
            known[wanted]=true
            return true
        end
    end
    return false
end

-- TEST271: Vanilla exposes no completed-quest API.  After reload, a live
-- follow-up accepted on the same guide step that turns in a missing predecessor
-- is durable proof that the predecessor was accepted and completed.  Record
-- that exact handoff so both its pickup and turn-in steps resolve generically.
function ZygorClassic_AcceptProvenByLiveFollowup271(guide,quests,stepIndex,missingTitle,missingID)
    if not guide or not guide.classic_steps or not missingTitle then return false end
    local missingKey=ZygorClassic_NormalizeQuestTitle170(missingTitle)
    -- TEST284: follow the guide's handoff chain transitively. A character may
    -- complete several nearby steps out of display order, so a live grandchild
    -- (or later descendant) is just as strong as a directly-live follow-up.
    local frontierKeys={[missingKey]=true}
    local frontierIDs={}
    if missingID then frontierIDs[tonumber(missingID)]=true end
    local i,j
    for i=(tonumber(stepIndex) or 1)+1,table.getn(guide.classic_steps) do
        local future=guide.classic_steps[i]
        local sameTurnin=false
        local stepAccepts={}
        for j=1,table.getn((future and future.source) or {}) do
            local line=ZygorClassic_CleanDirective62 and
                       ZygorClassic_CleanDirective62(future.source[j]) or future.source[j]
            local title,kind,questID=nil,nil,nil
            if ZygorClassic_ParseQuestDirective then
                title,kind,questID=ZygorClassic_ParseQuestDirective(line)
            end
            if title and kind=="turnin" then
                local turninKey=ZygorClassic_NormalizeQuestTitle170(title)
                if (questID and frontierIDs[tonumber(questID)]) or frontierKeys[turninKey] then
                    sameTurnin=true
                end
            elseif title and kind=="accept" then
                table.insert(stepAccepts,{title=title,id=questID,
                    key=ZygorClassic_NormalizeQuestTitle170(title)})
            end
        end
        if sameTurnin then
            local acceptIndex
            for acceptIndex=1,table.getn(stepAccepts) do
                local accepted=stepAccepts[acceptIndex]
                if quests[accepted.key] then
                    ZygorClassicDB=ZygorClassicDB or {}
                    ZygorClassicDB.turnins62=ZygorClassicDB.turnins62 or {}
                    local charKey=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
                    ZygorClassicDB.turnins62[charKey]=ZygorClassicDB.turnins62[charKey] or {}
                    ZygorClassicDB.turnins62[charKey][missingTitle]=true
                    if missingID and ZygorClassic_RecordQuestIDTurnin216 then
                        ZygorClassic_RecordQuestIDTurnin216(missingID)
                    end
                    if ZygorClassicDebug82 then
                        ZygorClassicDebug82.event="live descendant proves "..tostring(missingTitle)..
                            " -> "..tostring(accepted.title)
                    end
                    return true,i,accepted.title
                end
            end
            -- No live quest at this handoff yet; carry every accepted child
            -- forward so later turn-in/accept steps can prove the same chain.
            for acceptIndex=1,table.getn(stepAccepts) do
                local accepted=stepAccepts[acceptIndex]
                frontierKeys[accepted.key]=true
                if accepted.id then frontierIDs[tonumber(accepted.id)]=true end
            end
        end
    end
    return false
end

local function ZygorClassic_StepState172(step,quests,guide,stepIndex)
    if not step then return false,"missing step" end
    if ZygorClassic_StepApplies67 and not ZygorClassic_StepApplies67(step) then
        return true,"not applicable"
    end
    local requiredLevel=ZygorClassic_LevelRequirement212(step)
    if requiredLevel and (UnitLevel("player") or 1)<requiredLevel then
        return false,"waiting level "..tostring(requiredLevel)
    end
    local saw=requiredLevel and true or false
    local accepts={}
    local acceptIDs={}
    local acceptTitles={}
    local turninIDs={}
    local chainKeys={}
    local sameStepAcceptProof=ZygorClassic_SameStepAcceptProof338 and
                              ZygorClassic_SameStepAcceptProof338(step,quests)
    -- Collect instructions are inventory checkpoints, not necessarily quest
    -- leaderboard objectives. Read the preserved source metadata and verify
    -- the real item ID/count in the player's bags.
    local sourceIndex
    for sourceIndex=1,table.getn(step.source or {}) do
        local sourceLine=tostring(step.source[sourceIndex] or "")
        local cleanedSource=ZygorClassic_CleanDirective62 and
                            ZygorClassic_CleanDirective62(sourceLine) or sourceLine
        local fpathStart,fpathEnd,fpathName=string.find(cleanedSource,"^fpath%s+(.+)")
        if fpathName then
            saw=true
            fpathName=string.gsub(fpathName,"|.*$","")
            fpathName=string.gsub(fpathName,"^%s+","")
            fpathName=string.gsub(fpathName,"%s+$","")
            if not ZygorClassic_FlightPathKnown238(fpathName) then
                return false,"waiting flight path: "..tostring(fpathName)
            end
        end
        local startPos,endPos,required,itemID=string.find(sourceLine,"collect%s+(%d+)%s+.-##(%d+)")
        if required and itemID then
            saw=true
            local have=ZygorClassic_ItemCount197(itemID)
            if have<tonumber(required) then
                local qStart,qEnd,qid=string.find(sourceLine,"|q%s*(%d+)")
                local owner=ZygorClassic_QuestTitleByID198(guide,qid)
                local ownerQuest=owner and quests[ZygorClassic_NormalizeQuestTitle170(owner)]
                local consumedAndResolved=(ownerQuest and ownerQuest.complete) or
                    (owner and ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(owner))
                if not consumedAndResolved and not sameStepAcceptProof then
                    return false,"collect item "..tostring(itemID)..": "..tostring(have).."/"..tostring(required)
                end
            end
        end
        local buyStart,buyEnd,buyRequired,buyName=
            string.find(cleanedSource,"^buy%s+(%d+)%s+([^|]+)")
        if buyRequired and buyName then
            saw=true
            local explicitBuyID=string.match(buyName,"##(%d+)")
            buyName=string.gsub(buyName,"##%d+","")
            buyName=string.gsub(buyName,"^%s+","")
            buyName=string.gsub(buyName,"%s+$","")
            local have,resolvedBuyID=
                ZygorClassic_BuyItemCount329(buyName,explicitBuyID)
            if have<tonumber(buyRequired) then
                return false,"buy item "..tostring(resolvedBuyID or buyName)..": "..
                    tostring(have).."/"..tostring(buyRequired)
            end
        end
        -- Zygor often embeds a goal after prose, for example:
        -- "Click the grave|goal Samuel's Remains Buried|q 6395/1".
        -- The cleaned display line no longer begins with "goal", so validate
        -- the preserved metadata against the live leaderboard here.
        local goalStart,goalEnd,goalName=string.find(sourceLine,"|goal%s+([^|]+)")
        if goalName then
            saw=true
            local qtitle,text,done=ZygorClassic_ObjectiveStateForLine88("goal "..goalName)
            if qtitle and not quests[ZygorClassic_NormalizeQuestTitle170(qtitle)] and
               ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(qtitle) then done=true end
            if not qtitle or not done then
                return false,"objective TODO: "..tostring(text or goalName)
            end
        end
    end
    -- The paired objective mapper tolerates private-server changes to names
    -- and required totals (for example guide 5 vs live quest 8).
    local pairedObjectives=ZygorClassic_StepObjectiveLines87 and
                           ZygorClassic_StepObjectiveLines87(step) or {}
    local i
    -- Read the preserved source here. The display/raw copy intentionally strips
    -- ##questID, which is exactly the information needed to distinguish chain
    -- parts such as (1)##427 and (2)##370.
    for i=1,table.getn(step.source or {}) do
        local line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(step.source[i]) or step.source[i]
        local title,kind,directiveID=nil,nil,nil
        if ZygorClassic_ParseQuestDirective then title,kind,directiveID=ZygorClassic_ParseQuestDirective(line) end
        if title and kind=="accept" then
            local acceptKey=ZygorClassic_NormalizeQuestTitle170(title)
            accepts[acceptKey]=true
            acceptIDs[acceptKey]=directiveID
            acceptTitles[acceptKey]=title
        elseif title and kind=="turnin" then
            turninIDs[ZygorClassic_NormalizeQuestTitle170(title)]=directiveID
        end
    end
    -- Vanilla's quest log omits quest IDs, while Zygor suffixes numbered
    -- chains as (1), (2), etc.  A live part (1) must never satisfy the accept
    -- for part (2) merely because both normalize to the same title.  Require
    -- an actual QUEST_FINISHED witness for a same-title, different-ID handoff.
    local chainKey,acceptID
    for chainKey,acceptID in pairs(acceptIDs) do
        local turninID=turninIDs[chainKey]
        if acceptID and turninID and tonumber(acceptID)~=tonumber(turninID) then
            chainKeys[chainKey]=true
            -- TEST231: a normalized title witness from part (1) cannot prove
            -- the later part (2) handoff. Require this step's exact turn-in ID.
            if not (ZygorClassic_QuestIDTurnedIn216 and
                    ZygorClassic_QuestIDTurnedIn216(turninID)) then
                return false,"waiting chain handoff: "..tostring(chainKey)
            end
        end
    end
    -- The rendered/raw line list can omit quest directives while the preserved
    -- source still contains them.  Every source-level accept is a real barrier:
    -- do not leave a multi-action step merely because its preceding turn-in is
    -- complete.  Prefer the guide's exact quest ID so stale title history cannot
    -- falsely satisfy a follow-up accept.
    local sourceAcceptKey,sourceAcceptTitle
    for sourceAcceptKey,sourceAcceptTitle in pairs(acceptTitles) do
        saw=true
        if not quests[sourceAcceptKey] then
            local sourceAcceptID=acceptIDs[sourceAcceptKey]
            local followupProof=ZygorClassic_AcceptProvenByLiveFollowup271 and
                ZygorClassic_AcceptProvenByLiveFollowup271(
                    guide,quests,stepIndex,sourceAcceptTitle,sourceAcceptID)
            if sourceAcceptID then
                if not (ZygorClassic_QuestIDTurnedIn216 and
                        ZygorClassic_QuestIDTurnedIn216(sourceAcceptID)) and
                    not followupProof then
                    return false,"waiting source accept: "..tostring(sourceAcceptTitle)
                end
            elseif not (ZygorClassic_TurnedIn62 and
                        ZygorClassic_TurnedIn62(sourceAcceptTitle)) and
                   not followupProof then
                return false,"waiting source accept: "..tostring(sourceAcceptTitle)
            end
        end
    end
    for i=1,table.getn(step.raw or {}) do
        local line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(step.raw[i]) or step.raw[i]
        local lower=string.lower(tostring(line or ""))
        local title,kind,directiveID=nil,nil,nil
        if ZygorClassic_ParseQuestDirective then title,kind,directiveID=ZygorClassic_ParseQuestDirective(line) end
        if title and kind=="accept" then
            saw=true
            local key=ZygorClassic_NormalizeQuestTitle170(title)
            if chainKeys[key] and not quests[key] and
               not (ZygorClassic_QuestIDTurnedIn216 and
                    ZygorClassic_QuestIDTurnedIn216(acceptIDs[key])) then
                return false,"waiting chain accept: "..title
            elseif not chainKeys[key] and not quests[key] and not (ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title)) then
                return false,"waiting accept: "..title
            end
        elseif title and kind=="turnin" then
            saw=true
            local key=ZygorClassic_NormalizeQuestTitle170(title)
            -- TEST312: rendered/raw lines omit ##questID. Restore the exact
            -- source ID so an active later same-title chain part does not
            -- keep an already-completed earlier turn-in step and waypoint.
            if not directiveID then directiveID=turninIDs[key] end
            local downstreamProof=ZygorClassic_AcceptProvenByLiveFollowup271 and
                ZygorClassic_AcceptProvenByLiveFollowup271(
                    guide,quests,stepIndex,title,directiveID)
            local liveDescendant=ZygorClassic_LiveDescendantProof310 and
                ZygorClassic_LiveDescendantProof310(quests,title,directiveID)
            -- If the same step turns in part (1) and accepts part (2), Vanilla
            -- exposes both under one base title. The active replacement proves
            -- the handoff happened. Otherwise active always means not turned in.
            if quests[key] and not accepts[key] and not downstreamProof and not liveDescendant then
                return false,"waiting turnin: "..title
            elseif not quests[key] and
                   not (ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title)) and
                   not downstreamProof and not liveDescendant then
                return false,"waiting turnin: "..title
            end
        elseif string.find(lower,"kill ",1,true)==1 or
               string.find(lower,"get ",1,true)==1 or
               string.find(lower,"goal ",1,true)==1 then
            saw=true
            local owner,qid,objectiveIndex=ZygorClassic_ObjectiveOwner178(guide,stepIndex,line)
            local ownerQuest=owner and quests[ZygorClassic_NormalizeQuestTitle170(owner)] or nil
            local qtitle,text,done=nil,nil,false
            if ownerQuest then
                qtitle=ownerQuest.title
                if qid and ownerQuest.questID and tonumber(ownerQuest.questID)>tonumber(qid) and
                   ZygorClassic_NormalizeQuestTitle170(ownerQuest.title)==
                   ZygorClassic_NormalizeQuestTitle170(owner) then
                    text="advanced to quest "..tostring(ownerQuest.questID)
                    done=true
                    if ZygorClassic_RecordQuestIDTurnin216 then
                        ZygorClassic_RecordQuestIDTurnin216(qid)
                    end
                else
                    text,done=ZygorClassic_ObjectiveStateForQuest229(line,ownerQuest,objectiveIndex)
                    if ownerQuest.complete then done=true end
                end
                if not text and not done then
                    return false,"objective TODO: "..tostring(line)
                end
            elseif not owner then
                qtitle,text,done=ZygorClassic_ObjectiveStateForLine88(line)
            end
            if not qtitle and not owner then
                local pairedIndex
                for pairedIndex=1,table.getn(pairedObjectives) do
                    if pairedObjectives[pairedIndex].line==line then
                        qtitle=pairedObjectives[pairedIndex].title
                        text=pairedObjectives[pairedIndex].text
                        done=pairedObjectives[pairedIndex].done
                        break
                    end
                end
            end
            if not qtitle and not owner then
                local itemStartTitle=ZygorClassic_ItemStartAccepted236(step,line,quests)
                if itemStartTitle then
                    qtitle=itemStartTitle
                    text=line
                    done=true
                end
            end
            if not qtitle then
                -- TEST285: guides commonly use an untagged kill line as prose
                -- immediately before the real tagged loot objective (for
                -- example "Kill Princess" then "get Brass Collar|q 88/1").
                -- If every paired/tagged objective on this step is complete,
                -- that loot is durable proof that the introductory kill also
                -- happened. Do not invent ownership when any paired objective
                -- is still unfinished.
                local pairedProof=string.find(lower,"kill ",1,true)==1 and
                                  table.getn(pairedObjectives)>0
                local proofIndex
                if pairedProof then
                    for proofIndex=1,table.getn(pairedObjectives) do
                        if not pairedObjectives[proofIndex].done then
                            pairedProof=false
                            break
                        end
                    end
                end
                if not owner and pairedProof then
                    qtitle="paired tagged objective"
                    done=true
                elseif not owner then
                    return false,"objective owner missing q="..tostring(qid)..": "..tostring(line)
                end
                if owner then
                    if not (ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(owner)) then
                        if not done then
                            return false,"objective quest not recorded turned in: "..tostring(owner)
                        end
                    else
                        done=true
                    end
                end
            end
            -- TEST224: QUEST_FINISHED is stronger than a stale live-objective
            -- row. Some Vanilla servers leave that row visible for a poll,
            -- which previously let TEST220 restore an already turned-in quest.
            if qtitle and not quests[ZygorClassic_NormalizeQuestTitle170(qtitle)] and
               ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(qtitle) then done=true end
            if not done then return false,"objective TODO: "..tostring(text or line) end
        else
            local homeStart,homeEnd,bindTarget=string.find(lower,"^home%s+(.+)")
            if bindTarget then
                saw=true
                bindTarget=string.gsub(bindTarget,"^%s+","")
                bindTarget=string.gsub(bindTarget,"%s+$","")
                local homeResolved,bound=ZygorClassic_HomeResolved203(bindTarget,ZygorClassicGuideIndex,stepIndex)
                if not homeResolved then
                    return false,"waiting home: "..tostring(bindTarget).." (current "..tostring(bound)..")"
                end
            end
            -- `ding N` was handled above from preserved source metadata.
        end
    end
    if not saw then return false,"manual/travel step" end
    return true,"all actions resolved"
end

-- TEST280: use the source-aware resolver everywhere, including the legacy
-- diagnostic and auto-advance paths.  The older resolver only inspected the
-- rendered line list, which can omit source-level accept directives.  That
-- made a turn-in + multiple follow-up step report "resolved" while the live
-- quest log was still missing one or more of those follow-ups.
ZygorClassic_StepResolvedBefore280=ZygorClassic_StepResolved78
ZygorClassic_StepResolved78=function(guide,step)
    if not step then return true end
    if not guide or not guide.classic_steps then
        if ZygorClassic_StepResolvedBefore280 then
            return ZygorClassic_StepResolvedBefore280(guide,step)
        end
        return false
    end
    local stepIndex=nil
    local i
    for i=1,table.getn(guide.classic_steps) do
        if guide.classic_steps[i]==step then
            stepIndex=i
            break
        end
    end
    if not stepIndex then
        if ZygorClassic_StepResolvedBefore280 then
            return ZygorClassic_StepResolvedBefore280(guide,step)
        end
        return false
    end
    local quests=ZygorClassic_QuestLog172 and ZygorClassic_QuestLog172() or {}
    local resolved=ZygorClassic_StepState172(step,quests,guide,stepIndex)
    return resolved and true or false
end

if not ZygorClassicFlightPathWitness238 then
    ZygorClassicFlightPathWitness238=CreateFrame(
        "Frame","ZygorClassicFlightPathWitness238",UIParent)
    ZygorClassicFlightPathWitness238:RegisterEvent("TAXIMAP_OPENED")
    ZygorClassicFlightPathWitness238:SetScript("OnEvent",function()
        if event=="TAXIMAP_OPENED" then
            local name=ZygorClassic_RecordCurrentFlightPath238()
            if name and ZygorClassicDebug82 then
                ZygorClassicDebug82.event="FLIGHT PATH OPENED: "..tostring(name)
            end
        end
    end)
end

local function ZygorClassic_PreviousChainHandoff207(guide,quests,idx)
    -- Recover only a nearby skipped handoff.  The short window catches a
    -- handoff followed by level/travel steps without rewinding old history.
    local minimum=math.max(1,(idx or 1)-3)
    local i
    for i=(idx or 1)-1,minimum,-1 do
        local step=guide and guide.classic_steps and guide.classic_steps[i]
        if step and ((not ZygorClassic_StepApplies67) or ZygorClassic_StepApplies67(step)) then
            local resolved,reason=ZygorClassic_StepState172(step,quests,guide,i)
            -- Before the turn-in we wait for its witness; after the witness we
            -- must still rewind until the follow-up accepted on that source
            -- step is actually live.  TEST222 also made source accepts a hard
            -- barrier, so nearby recovery must recognize both representations
            -- of the same interrupted handoff.  Keeping this title/ID driven
            -- makes the repair apply to every guide rather than one quest.
            local recoveryReason=tostring(reason or "")
            if not resolved and
               (string.find(recoveryReason,"waiting chain ",1,true)==1 or
                string.find(recoveryReason,"waiting source accept: ",1,true)==1) then
                return i,reason
            end
        end
    end
    return nil,nil
end

local function ZygorClassic_NextStep172(guide,idx)
    local i=idx+1
    while guide and guide.classic_steps and i<=table.getn(guide.classic_steps) do
        if not ZygorClassic_StepApplies67 or ZygorClassic_StepApplies67(guide.classic_steps[i]) then return i end
        i=i+1
    end
    return idx
end

-- A completed objective on the next applicable step proves that a preceding
-- travel-only instruction was already followed.  This lets the engine recover
-- when arrival coordinates are too coarse (especially at cave entrances)
-- without hardcoding a guide, quest, or step number.
local function ZygorClassic_NextObjectiveProof182(guide,idx)
    local target=ZygorClassic_NextStep172(guide,idx)
    if target==idx then return nil,nil end
    local step=guide and guide.classic_steps and guide.classic_steps[target]
    local i
    for i=1,table.getn(step and step.raw or {}) do
        local line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(step.raw[i]) or step.raw[i]
        local lower=string.lower(tostring(line or ""))
        if string.find(lower,"kill ",1,true)==1 or
           string.find(lower,"get ",1,true)==1 or
           string.find(lower,"goal ",1,true)==1 then
            local qtitle,text,done=ZygorClassic_ObjectiveStateForLine88(line)
            if qtitle and done then return target,text or line end
        end
    end
    return nil,nil
end

local function ZygorClassic_ArrivalProof186(step)
    -- Only Zygor travel directives explicitly marked complete-on-arrival may
    -- advance from proximity alone.  TEST334 also accepts an objective-free
    -- travel step whose author supplied a goto but omitted |c.  StepState172
    -- calls this function only for manual/travel steps, so quest actions cannot
    -- be completed merely by walking near their waypoint.
    local marked=false
    local implicitTravel=false
    local i
    for i=1,table.getn(step and step.source or {}) do
        local source=tostring(step.source[i] or "")
        local lower=string.lower(source)
        if string.find(source,"|c",1,true) then marked=true end
        if string.find(lower,"|goto",1,true) and
           (string.find(lower,"go ",1,true) or
            string.find(lower,"inside",1,true) or
            string.find(lower,"enter",1,true) or
            string.find(lower,"leave",1,true) or
            string.find(lower,"follow",1,true) or
            string.find(lower,"travel",1,true) or
            string.find(lower,"ride",1,true) or
            string.find(lower,"fly",1,true) or
            string.find(lower,"hearth",1,true) or
            string.find(lower,"cross",1,true)) then
            implicitTravel=true
        end
    end
    if not marked and not implicitTravel then return nil end

    -- TEST288: guide authors deliberately give hearth and other imprecise
    -- travel landings a wider fourth `goto` radius. Honor that source radius
    -- before falling back to the legacy fixed ten-yard check.
    if ZygorClassic_ArrivedAtStep216 and ZygorClassic_ArrivedAtStep216(step) then
        return "guide radius"
    end

    local p=ZygorGuidesViewer and ZygorGuidesViewer.Pointer
    local way=p and p.ArrowFrame and p.ArrowFrame.waypoint
    if way and way.minimapFrame and Astrolabe and Astrolabe.GetDistanceToIcon then
        local dist=Astrolabe:GetDistanceToIcon(way.minimapFrame)
        if dist and dist<=(implicitTravel and 15 or 10) then return dist end
    end

    -- Fallback for clients where Astrolabe cannot return a yard distance.
    local map,x,y=ZygorClassic_CurrentGoto55()
    local px,py=GetPlayerMapPosition("player")
    if x and y and px and py and (px>0 or py>0) then
        local dx=x-px*100
        local dy=y-py*100
        local mapdist=math.sqrt(dx*dx+dy*dy)
        if mapdist<=(implicitTravel and 0.75 or 0.3) then
            return tostring(mapdist).."% map"
        end
    end
    return nil
end

-- TEST234: zone-only directives ("goto The Barrens") have no coordinates and
-- no quest event.  Resolve them only after the client reports the destination
-- zone; this is the actual completion signal exposed by Vanilla.
local function ZygorClassic_ZoneArrivalProof234(step)
    local lines=step and (step.source or step.raw) or {}
    local i
    for i=1,table.getn(lines) do
        local line=tostring(lines[i] or "")
        local at=string.find(line,"goto ",1,true)
        if at then
            local destination=string.sub(line,at+5)
            destination=string.gsub(destination,"|.*$","")
            destination=string.gsub(destination,"^%s+","")
            destination=string.gsub(destination,"%s+$","")
            if destination~="" and not string.find(destination,",",1,true) then
                local real=GetRealZoneText and GetRealZoneText() or ""
                local zone=GetZoneText and GetZoneText() or ""
                if string.lower(real)==string.lower(destination) or
                   string.lower(zone)==string.lower(destination) then
                    return destination
                end
            end
        end
    end
    return nil
end

-- TEST232: Vanilla has no dependable generic "item successfully used" event.
-- For consumable guide actions, the bag-count decrease is the durable signal.
-- Track it only while that exact step is authoritative; this prevents an old
-- consumption from resolving a later step that happens to use the same item.
local function ZygorClassic_UseConsumptionProof232(step,state,guideIndex,stepIndex)
    if not step or not state or not GetItemCount then return nil,nil end
    local itemID=nil
    local i
    for i=1,table.getn(step.source or {}) do
        local line=tostring(step.source[i] or "")
        local id=string.match(line,"|use%s+.-##(%d+)")
        if id then itemID=tonumber(id) break end
    end
    if not itemID then
        state.useTracker232=nil
        return nil,nil
    end

    local count=tonumber(GetItemCount(itemID)) or 0
    local tracker=state.useTracker232
    if not tracker or tracker.guide~=guideIndex or tracker.step~=stepIndex or tracker.item~=itemID then
        state.useTracker232={guide=guideIndex,step=stepIndex,item=itemID,last=count,consumed=false}
        return nil,itemID
    end
    if tracker.last and tracker.last>count and tracker.last>0 then tracker.consumed=true end
    tracker.last=count
    return tracker.consumed,itemID
end

local function ZygorClassic_PendingPriorTurnin174(guide,quests,idx)
    local i
    -- TEST221: choose the earliest unresolved live handoff.  Delivery quests
    -- can be turn-in ready while Vanilla/CMaNGOS still reports them merely
    -- ACTIVE; their zero-objective quest-log entry is the usable evidence.
    -- Scanning forward preserves guide order when more than one handoff was
    -- skipped by an older recovery jump.
    for i=1,idx-1 do
        local step=guide.classic_steps[i]
        if not ZygorClassic_StepApplies67 or ZygorClassic_StepApplies67(step) then
            local j
            for j=1,table.getn(step and step.raw or {}) do
                local line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(step.raw[j]) or step.raw[j]
                local title,kind=nil,nil
                if ZygorClassic_ParseQuestDirective then title,kind=ZygorClassic_ParseQuestDirective(line) end
                if title and kind=="turnin" then
                    local q=quests[ZygorClassic_NormalizeQuestTitle170(title)]
                    -- TEST228: Vanilla removes chain suffixes. A live part (2)
                    -- must not restore the already-confirmed part (1) turn-in.
                    if q and (q.complete or q.objectiveCount==0) and
                       not (ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title)) then
                        local resolved=ZygorClassic_StepState172(step,quests,guide,i)
                        if not resolved then return i,title end
                    end
                end
            end
        end
    end
    return nil,nil
end

-- A confirmed turn-in plus a currently live accept on the same guide step is
-- direct proof that the handoff occurred. This repairs old saves after a
-- suffix-collision rewind without naming a quest, race, or step.
local function ZygorClassic_ConfirmedLiveHandoff228(guide,quests)
    local best=nil
    local i
    for i=1,table.getn(guide and guide.classic_steps or {}) do
        local step=guide.classic_steps[i]
        if not ZygorClassic_StepApplies67 or ZygorClassic_StepApplies67(step) then
            local confirmedTurnin=false
            local liveAccept=false
            local j
            for j=1,table.getn(step.raw or {}) do
                local line=ZygorClassic_CleanDirective62 and
                           ZygorClassic_CleanDirective62(step.raw[j]) or step.raw[j]
                local title,kind=nil,nil
                if ZygorClassic_ParseQuestDirective then title,kind=ZygorClassic_ParseQuestDirective(line) end
                if title and kind=="turnin" and ZygorClassic_TurnedIn62 and
                   ZygorClassic_TurnedIn62(title) then
                    confirmedTurnin=true
                elseif title and kind=="accept" and
                       quests[ZygorClassic_NormalizeQuestTitle170(title)] then
                    liveAccept=true
                end
            end
            if confirmedTurnin and liveAccept then
                local target=ZygorClassic_NextStep172(guide,i)
                if target and (not best or target>best) then best=target end
            end
        end
    end
    return best
end

-- Recover failed/abandoned quests that were accepted behind the current step
-- and are scheduled for a turn-in ahead.  Absence from both the live log and
-- turn-in history means the quest must be picked up again.
local function ZygorClassic_MissingInflightQuest187(guide,quests,idx,state)
    local qmap=ZygorClassic_BuildGuideQuestMap52 and ZygorClassic_BuildGuideQuestMap52(guide) or {}
    local best=nil
    local bestTitle=nil
    state=state or {}
    state.inflightSeen191=state.inflightSeen191 or {}
    state.missingSince191=state.missingSince191 or {}
    local title,data
    for title,data in pairs(qmap) do
        if data.acceptStep and data.turninStep and
           data.acceptStep<idx and data.turninStep>idx and
           (not best or data.acceptStep>best) then
            local key=ZygorClassic_NormalizeQuestTitle170(title)
            local acceptStep=guide.classic_steps[data.acceptStep]
            local applies=(not ZygorClassic_StepApplies67) or ZygorClassic_StepApplies67(acceptStep)
            local handoffResolved=false
            -- A live follow-up accepted on the same step as this quest's
            -- turn-in is stronger proof than a missed Vanilla turn-in event.
            -- StepState172 already recognizes that turn-in/accept handoff.
            if data.turninStep<=idx then
                local turninStep=guide.classic_steps[data.turninStep]
                handoffResolved=ZygorClassic_StepState172(turninStep,quests,guide,data.turninStep)
            end
            if quests[key] then
                state.inflightSeen191[key]=true
                state.missingSince191[key]=nil
            elseif ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title) then
                state.missingSince191[key]=nil
            elseif handoffResolved then
                state.missingSince191[key]=nil
            elseif applies and state.inflightSeen191[key] then
                -- Do not rewind on the first frame where a quest vanishes.
                -- A normal reward hand-in briefly has the same log shape as
                -- an abandon; TEST191's turn-in witness settles it first.
                if not state.missingSince191[key] then
                    state.missingSince191[key]=GetTime and GetTime() or 0
                end
                local elapsed=(GetTime and GetTime() or 0)-state.missingSince191[key]
                if elapsed>=1.0 then
                    best=data.acceptStep
                    bestTitle=title
                end
            end
        end
    end
    return best,bestTitle
end

-- TEST199: recover a save that an earlier missing-quest check already rewound.
-- If a later step turns in a previously observed quest and its follow-up is
-- currently active, the whole handoff step is proven complete. Resume after it.
local function ZygorClassic_ProvenHandoffAhead199(guide,quests,idx,state,missingTitle,missingQuestID)
    if not guide or not guide.classic_steps then return nil end
    local missingKey=ZygorClassic_NormalizeQuestTitle170(missingTitle or "")
    local i
    for i=(idx or 1)+1,table.getn(guide.classic_steps) do
        local step=guide.classic_steps[i]
        if not ZygorClassic_StepApplies67 or ZygorClassic_StepApplies67(step) then
            local sawAbsentTurnin=false
            local sawActiveAccept=false
            local sawLiveAccept=false
            local j
            for j=1,table.getn(step.raw or {}) do
                local line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(step.raw[j]) or step.raw[j]
                local title,kind,questID=nil,nil,nil
                if ZygorClassic_ParseQuestDirective then title,kind,questID=ZygorClassic_ParseQuestDirective(line) end
                if title and kind=="turnin" then
                    local key=ZygorClassic_NormalizeQuestTitle170(title)
                    -- A later handoff only proves the *same* quest whose
                    -- acceptance is missing at the current step.  An unrelated
                    -- active quest must never leap over the current pickup.
                    local sameQuest=false
                    if missingQuestID and questID then
                        sameQuest=(tonumber(missingQuestID)==tonumber(questID))
                    else
                        sameQuest=(missingKey~="" and key==missingKey)
                    end
                    if sameQuest and not quests[key] then sawAbsentTurnin=true end
                elseif title and kind=="accept" then
                    local key=ZygorClassic_NormalizeQuestTitle170(title)
                    if quests[key] then
                        sawActiveAccept=true
                        sawLiveAccept=true
                    elseif ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title) then
                        sawActiveAccept=true
                    end
                end
            end
            -- The active accepted follow-up is direct proof of this handoff,
            -- even after a reload erased the older in-memory seen cache.
            if sawAbsentTurnin and sawActiveAccept then
                -- A *live* follow-up is durable evidence that the missing
                -- predecessor was accepted and handed in. Record that fact so
                -- StepState can validate the handoff after reload. Historical
                -- accepts may still prove a fully resolved step, but cannot
                -- pull the viewer onto a partially completed old handoff.
                if sawLiveAccept then
                    ZygorClassicDB=ZygorClassicDB or {}
                    ZygorClassicDB.turnins62=ZygorClassicDB.turnins62 or {}
                    local charKey=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
                    ZygorClassicDB.turnins62[charKey]=ZygorClassicDB.turnins62[charKey] or {}
                    ZygorClassicDB.turnins62[charKey][missingTitle]=true
                end
                local resolved=ZygorClassic_StepState172(step,quests,guide,i)
                if resolved then return ZygorClassic_NextStep172(guide,i),i end
                -- The handoff itself is proven, but another action on that
                -- same step is still missing (for example a class note). Stop
                -- on the handoff instead of remaining stranded at its pickup.
                if sawLiveAccept then return i,i end
            end
        end
    end
    return nil
end

-- TEST202: a forward-chain repair is appropriate only when the current saved
-- step is itself blocked on an absent acceptance. Running it during ordinary
-- turn-ins can jump over manual instructions such as setting a hearthstone.
local function ZygorClassic_CurrentMissingAccept202(guide,quests,idx)
    local step=guide and guide.classic_steps and guide.classic_steps[idx or 1]
    local i
    for i=1,table.getn((step and step.raw) or {}) do
        local line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(step.raw[i]) or step.raw[i]
        local title,kind,questID=nil,nil,nil
        if ZygorClassic_ParseQuestDirective then title,kind,questID=ZygorClassic_ParseQuestDirective(line) end
        if title and kind=="accept" then
            local key=ZygorClassic_NormalizeQuestTitle170(title)
            if not quests[key] and not (ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title)) then
                return true,title,questID
            end
        end
    end
    return false,nil
end

-- TEST251: an objective can be current even though its earlier accept step was
-- skipped before the quest ever appeared in the live log.  TEST187 deliberately
-- required an "observed live" witness, so that case could strand a mixed
-- objective step (one active quest plus one never-accepted quest).  Resolve the
-- objective's preserved |q questID/objective metadata back to its exact earlier
-- accept and return there. This is guide-generic and never guesses from text.
function ZygorClassic_CurrentObjectivePickup251(guide,quests,idx)
    if not guide or not guide.classic_steps then return nil,nil,nil end
    idx=tonumber(idx) or 1
    local step=guide.classic_steps[idx]
    local i,j
    for i=1,table.getn((step and step.source) or {}) do
        local sourceLine=tostring(step.source[i] or "")
        local matchStart,matchEnd,capturedID=
            string.find(sourceLine,"|q%s*(%d+)%s*/%s*%d+")
        local questID=tonumber(capturedID)
        if questID then
            local title=ZygorClassic_QuestTitleByID198(guide,questID)
            local key=title and ZygorClassic_NormalizeQuestTitle170(title)
            local active=key and quests and quests[key]
            local alreadyFinished=ZygorClassic_QuestIDTurnedIn216 and
                                  ZygorClassic_QuestIDTurnedIn216(questID)
            if title and not active and not alreadyFinished then
                for j=idx-1,1,-1 do
                    local acceptStep=guide.classic_steps[j]
                    if acceptStep and ((not ZygorClassic_StepApplies67) or
                       ZygorClassic_StepApplies67(acceptStep)) then
                        local k
                        for k=1,table.getn(acceptStep.source or {}) do
                            local cleaned=string.gsub(acceptStep.source[k],"^%.+","")
                            local acceptTitle,kind,directiveID=
                                ZygorClassic_ParseQuestDirective(cleaned)
                            if acceptTitle and kind=="accept" and
                               tonumber(directiveID)==questID then
                                return j,acceptTitle,questID
                            end
                        end
                    end
                end
            end
        end
    end
    return nil,nil,nil
end

local function ZygorClassic_PreviousHomeUnfinished202(guide,current)
    local previous=(current or 1)-1
    if previous<1 or not guide or not guide.classic_steps then return nil end
    local step=guide.classic_steps[previous]
    if not step or (ZygorClassic_StepApplies67 and not ZygorClassic_StepApplies67(step)) then return nil end
    local i
    for i=1,table.getn(step.raw or {}) do
        local line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(step.raw[i]) or step.raw[i]
        local homeStart,homeEnd,target=string.find(string.lower(tostring(line or "")),"^home%s+(.+)")
        if target then
            target=string.gsub(target,"^%s+","")
            target=string.gsub(target,"%s+$","")
            local resolved=ZygorClassic_HomeResolved203(target,ZygorClassicGuideIndex,previous)
            if not resolved then return previous,target end
        end
    end
    return nil
end

local function ZygorClassic_Bootstrap172(guide,quests)
    local best=nil
    local levelGate=nil
    local i
    for i=1,table.getn(guide.classic_steps or {}) do
        local step=guide.classic_steps[i]
        if not ZygorClassic_StepApplies67 or ZygorClassic_StepApplies67(step) then
            local requiredLevel=ZygorClassic_LevelRequirement212(step)
            if requiredLevel and (UnitLevel("player") or 1)<requiredLevel and
               (not levelGate or i<levelGate) then
                levelGate=i
            end
            local j
            for j=1,table.getn(step.raw or {}) do
                local line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(step.raw[j]) or step.raw[j]
                local title,kind=nil,nil
                if ZygorClassic_ParseQuestDirective then title,kind=ZygorClassic_ParseQuestDirective(line) end
                if title and kind=="turnin" then
                    local q=quests[ZygorClassic_NormalizeQuestTitle170(title)]
                    if q and q.complete and (not best or i<best) then best=i end
                else
                    local lower=string.lower(tostring(line or ""))
                    if string.find(lower,"kill ",1,true)==1 or string.find(lower,"get ",1,true)==1 or
                       string.find(lower,"goal ",1,true)==1 then
                        local qtitle,text,done=ZygorClassic_ObjectiveStateForLine88(line)
                        local owner=ZygorClassic_ObjectiveOwner178 and
                                    ZygorClassic_ObjectiveOwner178(guide,i,line) or nil
                        local ownerMatches=(not owner) or
                            ZygorClassic_NormalizeQuestTitle170(owner)==
                            ZygorClassic_NormalizeQuestTitle170(qtitle)
                        -- TEST226: leaderboard text from another live quest
                        -- must not make this guide step a bootstrap candidate.
                        -- The preserved |q metadata is the authoritative owner.
                        if qtitle and ownerMatches and not done and
                           not (ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(qtitle)) and
                           (not best or i<best) then best=i end
                    end
                end
            end
        end
    end
    -- A level gate may constrain quest-log evidence found later in the guide,
    -- but by itself it is not permission to jump a fresh character over all
    -- preceding steps.
    if best and levelGate and levelGate<best then best=levelGate end
    return best or ZygorClassicStepIndex or 1
end

-- Repair saved progress created by older revisions that skipped a level gate.
-- This is data-driven: it searches the active guide's preceding applicable
-- steps and never names a race, quest, guide, or step number.
local function ZygorClassic_PreviousLevelUnmet212(guide,current)
    local i
    for i=(current or 1)-1,1,-1 do
        local step=guide and guide.classic_steps and guide.classic_steps[i]
        if step and ((not ZygorClassic_StepApplies67) or ZygorClassic_StepApplies67(step)) then
            local requiredLevel=ZygorClassic_LevelRequirement212(step)
            if requiredLevel and (UnitLevel("player") or 1)<requiredLevel then
                return i,requiredLevel
            end
        end
    end
    return nil,nil
end

-- TEST218: recovery rules may repair stale automatic progress, but they must
-- never rewind behind a step the player explicitly selected or a later step
-- proven by live quest evidence.  Keep that lower boundary in the persisted
-- per-character engine state so the protection survives /reload and login.
local function ZygorClassic_RecoveryAllowed218(state,candidate)
    local floor=state and tonumber(state.recoveryFloor218)
    local hard=state and tonumber(state.hardFloor324)
    if hard and (not floor or hard>floor) then floor=hard end
    return candidate and (not floor or candidate>=floor)
end

local function ZygorClassic_RaiseRecoveryFloor218(state,target)
    if not state or not target then return end
    local floor=tonumber(state.recoveryFloor218)
    if not floor or target>floor then state.recoveryFloor218=target end
end

-- TEST220: live unfinished objectives are stronger evidence than inferred
-- handoffs.  Older ordering allowed a recovery helper to jump away before the
-- current step's objective state was evaluated.  Keep this generic: the
-- objective text and owner come entirely from the active guide and quest log.
local function ZygorClassic_IsObjectiveTodo220(reason)
    return type(reason)=="string" and string.find(reason,"objective TODO:",1,true)==1
end

local function ZygorClassic_EarlierLiveObjective220(guide,quests,current)
    local candidate=ZygorClassic_Bootstrap172(guide,quests)
    if not candidate or candidate>=(current or 1) then return nil,nil end
    local step=guide and guide.classic_steps and guide.classic_steps[candidate]
    if not step then return nil,nil end
    local resolved,reason=ZygorClassic_StepState172(step,quests,guide,candidate)
    if not resolved and ZygorClassic_IsObjectiveTodo220(reason) then
        return candidate,reason
    end
    return nil,nil
end

-- Manual browsing must be released by a real quest-log change even when the
-- client fires that event immediately after the button click.  TEST194 used a
-- time-only guard and could discard the only useful event, leaving a stale
-- manual selection authoritative indefinitely.
local function ZygorClassic_QuestSignature213(quests)
    local parts={}
    local key,quest
    for key,quest in pairs(quests or {}) do
        table.insert(parts,tostring(key).."="..(quest.complete and "1" or "0"))
    end
    table.sort(parts)
    return table.concat(parts,"|")
end

local function ZygorClassic_PreviousStep213(guide,idx)
    local i=(idx or 1)-1
    while guide and guide.classic_steps and i>=1 do
        if not ZygorClassic_StepApplies67 or ZygorClassic_StepApplies67(guide.classic_steps[i]) then return i end
        i=i-1
    end
    return idx or 1
end

-- Return the single faction/level guide expected for this character.  This
-- deliberately avoids the Lua 5.0 string.match shim and exacts the same
-- bracket policy previously proven by TEST51.
local function ZygorClassic_ExpectedGuide188()
    local guides=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides
    if not guides or table.getn(guides)<1 then return nil,nil end
    local level=UnitLevel("player") or 1
    local faction=ZygorClassic_Faction262() or ""
    local race=UnitRace("player") or ""
    if faction=="" or race=="" then return nil,nil end
    local prefix="Zygor's "..faction.." Leveling Guides\\"
    local wanted=nil
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

-- TEST242: level brackets choose a guide only for a character with no saved
-- progress.  A guide boundary is crossed by resolving the old guide's final
-- step, never merely by reaching its advertised level.
function ZygorClassic_FindGuideByTitle242(title)
    local guides=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides
    if not guides or not title then return nil,nil end
    local i
    for i=1,table.getn(guides) do
        if tostring(guides[i].title or "")==tostring(title) then
            return i,guides[i]
        end
    end
    return nil,nil
end

function ZygorClassic_LiveTurninStep242(guide,quests)
    if not guide or not ZygorClassic_EnsureParsed(guide) then return nil,nil end
    local best=nil
    local bestTitle=nil
    local i,j
    for i=1,table.getn(guide.classic_steps or {}) do
        local step=guide.classic_steps[i]
        if not ZygorClassic_StepApplies67 or ZygorClassic_StepApplies67(step) then
            for j=1,table.getn(step.source or step.raw or {}) do
                local line=(step.source or step.raw)[j]
                line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(line) or line
                local title,kind=nil,nil
                if ZygorClassic_ParseQuestDirective then
                    title,kind=ZygorClassic_ParseQuestDirective(line)
                end
                local quest=title and quests[ZygorClassic_NormalizeQuestTitle170(title)]
                if kind=="turnin" and quest and quest.complete and (not best or i<best) then
                    best=i
                    bestTitle=title
                end
            end
        end
    end
    return best,bestTitle
end

function ZygorClassic_ConfirmedTurninStep244(guide)
    if not guide or not ZygorClassic_EnsureParsed(guide) then return nil,nil end
    local best=nil
    local bestTitle=nil
    local i,j
    for i=1,table.getn(guide.classic_steps or {}) do
        local step=guide.classic_steps[i]
        if not ZygorClassic_StepApplies67 or ZygorClassic_StepApplies67(step) then
            for j=1,table.getn(step.source or step.raw or {}) do
                local line=(step.source or step.raw)[j]
                line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(line) or line
                local title,kind=nil,nil
                if ZygorClassic_ParseQuestDirective then
                    title,kind=ZygorClassic_ParseQuestDirective(line)
                end
                if kind=="turnin" and title and ZygorClassic_TurnedIn62 and
                   ZygorClassic_TurnedIn62(title) and (not best or i>best) then
                    best=i
                    bestTitle=title
                end
            end
        end
    end
    return best,bestTitle
end

function ZygorClassic_TravelZoneArrived244(step)
    local lines=step and (step.source or step.raw) or {}
    local real=GetRealZoneText and GetRealZoneText() or ""
    local zone=GetZoneText and GetZoneText() or ""
    local i
    for i=1,table.getn(lines) do
        local line=tostring(lines[i] or "")
        local at=string.find(line,"goto ",1,true)
        if at then
            local destination=string.sub(line,at+5)
            destination=string.gsub(destination,"|.*$","")
            local comma=string.find(destination,",",1,true)
            if comma then destination=string.sub(destination,1,comma-1) end
            destination=string.gsub(destination,"^%s+","")
            destination=string.gsub(destination,"%s+$","")
            if destination~="" and not tonumber(destination) and
               (string.lower(real)==string.lower(destination) or
                string.lower(zone)==string.lower(destination)) then
                return destination
            end
        end
    end
    return nil
end

-- TEST302: alternate travel methods may land the player at the destination of
-- a later consecutive travel instruction (for example flying to Ironforge
-- instead of walking to the Stormwind tram entrance). Catch up only across
-- travel-only steps; never cross an NPC, quest, item, combat or home action.
local function ZygorClassic_IsTravelOnly302(step)
    local lines=step and (step.source or step.raw) or {}
    local hasTravel=false
    local i
    for i=1,table.getn(lines) do
        local line=string.lower(tostring(lines[i] or ""))
        if string.find(line,"goto ",1,true) then hasTravel=true end
        if string.find(line,".talk ",1,true) or
           string.find(line,"accept ",1,true) or
           string.find(line,"turnin ",1,true) or
           string.find(line,".kill ",1,true) or
           string.find(line,".get ",1,true) or
           string.find(line,".goal ",1,true) or
           string.find(line,".from ",1,true) or
           string.find(line,"home ",1,true) or
           string.find(line,"fpath ",1,true) or
           string.find(line,".buy ",1,true) or
           string.find(line,"|q ",1,true) then
            return false
        end
    end
    return hasTravel
end

local function ZygorClassic_TravelCatchup302(guide,current)
    if not guide or not guide.classic_steps or
       not ZygorClassic_IsTravelOnly302(guide.classic_steps[current]) then return nil end
    local scan=current
    local checked=0
    while checked<8 do
        local nextStep=ZygorClassic_NextStep172(guide,scan)
        if not nextStep or nextStep==scan then break end
        local candidate=guide.classic_steps[nextStep]
        if not ZygorClassic_IsTravelOnly302(candidate) then break end
        local arrived=ZygorClassic_TravelZoneArrived244(candidate)
        if arrived then return nextStep,arrived end
        scan=nextStep
        checked=checked+1
    end
    return nil
end

function ZygorClassic_PredecessorRecovery242(currentIndex,quests)
    local guides=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides
    local current=guides and guides[currentIndex]
    if not current then return nil,nil,nil end
    local race=UnitRace("player") or ""
    local i
    for i=1,table.getn(guides) do
        local candidate=guides[i]
        if i~=currentIndex and ZygorClassic_EnsureParsed(candidate) and
           tostring(candidate.classic_next or "")==tostring(current.title or "") then
            local defaultfor=tostring(candidate.classic_defaultfor or "")
            local title=tostring(candidate.title or "")
            local raceGuide=(defaultfor==race) or
                (race~="" and string.find(title,"\\"..race.." ",1,true))
            if raceGuide then
                local turninStep,turninTitle=ZygorClassic_LiveTurninStep242(candidate,quests)
                local confirmed=false
                if not turninStep then
                    turninStep,turninTitle=ZygorClassic_ConfirmedTurninStep244(candidate)
                    confirmed=turninStep and true or false
                end
                if turninStep then
                    local target=nil
                    if confirmed then
                        target=ZygorClassic_NextStep172(candidate,turninStep)
                        local travelStep=candidate.classic_steps[target]
                        local travelResolved,travelReason=
                            ZygorClassic_StepState172(travelStep,quests,candidate,target)
                        if not travelResolved and travelReason=="manual/travel step" and
                           ZygorClassic_TravelZoneArrived244(travelStep) then
                            target=ZygorClassic_NextStep172(candidate,target)
                        end
                    else
                        target=turninStep
                        local previous=ZygorClassic_PreviousStep213(candidate,turninStep)
                        local previousStep=candidate.classic_steps[previous]
                        local previousResolved,previousReason=
                            ZygorClassic_StepState172(previousStep,quests,candidate,previous)
                        if not previousResolved and previousReason=="manual/travel step" and
                           not ZygorClassic_ZoneArrivalProof234(previousStep) then
                            target=previous
                        end
                    end
                    return i,target,turninTitle
                end
            end
        end
    end
    return nil,nil,nil
end

-- Composite travel lines may contain prose before "goto", a zone name,
-- radius, and |noway|c flags. Extract the first usable coordinate pair.
local function ZygorClassic_ParseGoto234(line)
    line=tostring(line or "")
    local at=string.find(line,"goto ",1,true)
    if not at then return nil,nil,nil,nil end
    local rest=string.sub(line,at+5)
    rest=string.gsub(rest,"|.*$","")
    local parts={}
    local start=1
    while true do
        local comma=string.find(rest,",",start,true)
        local part
        if comma then part=string.sub(rest,start,comma-1) else part=string.sub(rest,start) end
        part=string.gsub(part,"^%s+","")
        part=string.gsub(part,"%s+$","")
        table.insert(parts,part)
        if not comma then break end
        start=comma+1
    end
    if table.getn(parts)>=2 and tonumber(parts[1]) and tonumber(parts[2]) then
        return nil,tonumber(parts[1]),tonumber(parts[2]),nil
    elseif table.getn(parts)>=3 and tonumber(parts[2]) and tonumber(parts[3]) then
        return parts[1],tonumber(parts[2]),tonumber(parts[3]),nil
    elseif table.getn(parts)==1 and parts[1]~="" then
        return nil,nil,nil,parts[1]
    end
    return nil,nil,nil,nil
end

-- TEST318: a zone-only/remote-zone `goto` can tell the player *where the
-- journey ends* but cannot give the arrow a useful point on the current map.
-- Keep the destination intact for normal arrival detection, while using a
-- handoff node (portal, gate, ferry, etc.) as the temporary local target.
-- Entries are deliberately data-only so the same mechanism can cover every
-- guide without adding one-off behavior to the step resolver.
local ZygorClassicTravelHandoffs318={
    ["darnassus>teldrassil"]={map="Darnassus",x=31.0,y=42.0,
        label="Pink portal to Rut'theran Village"},
    ["darkshore>teldrassil"]={map="Darkshore",x=36.4,y=45.6,
        label="Auberdine flight master"},
    ["teldrassil>darkshore"]={map="Teldrassil",x=58.4,y=94.0,
        label="Rut'theran Village flight master"},
}

-- TEST331: some NPC coordinates are vertically correct but unreachable by a
-- straight 2-D arrow (flight masters on walls, balconies, raised platforms).
-- Route to the authored approach first, then hand the arrow back to the real
-- NPC coordinate.  This stays data-driven so future multi-level NPCs can be
-- added without special-casing guide or step numbers.
ZygorClassicNpcApproaches331={
    [352]={map="Stormwind City",x=68.6,y=72.9,
        label="Ramp up to Dungar Longdrink"},
}

function ZygorClassic_NpcApproach331(lines,map,x,y)
    if not lines or not map or not x or not y then return map,x,y,nil end
    local current=GetRealZoneText and GetRealZoneText() or
                  (GetZoneText and GetZoneText()) or ""
    if string.lower(tostring(current))~=string.lower(tostring(map)) then
        return map,x,y,nil
    end
    local npcID=nil
    local i
    for i=1,table.getn(lines) do
        npcID=tonumber(string.match(tostring(lines[i] or ""),
            "talk[^#]*##(%d+)"))
        if npcID then break end
    end
    local approach=npcID and ZygorClassicNpcApproaches331[npcID]
    if not approach or string.lower(tostring(approach.map))~=
       string.lower(tostring(map)) then return map,x,y,nil end

    local px,py=GetPlayerMapPosition("player")
    px=(tonumber(px) or 0)*100
    py=(tonumber(py) or 0)*100
    if px<=0 or py<=0 then return map,x,y,nil end
    local key=tostring(ZygorClassicGuideIndex or 0)..":"..
              tostring(ZygorClassicStepIndex or 0)..":"..tostring(npcID)
    if ZygorClassicNpcApproachKey331~=key then
        ZygorClassicNpcApproachKey331=key
        ZygorClassicNpcApproachReached331=nil
    end
    local npcDistance=((px-x)*(px-x)+(py-y)*(py-y))^0.5
    local approachDistance=((px-approach.x)*(px-approach.x)+
                            (py-approach.y)*(py-approach.y))^0.5
    if npcDistance<=1.5 or approachDistance<=4.5 then
        ZygorClassicNpcApproachReached331=true
    end
    if not ZygorClassicNpcApproachReached331 then
        return approach.map,approach.x,approach.y,approach.label
    end
    return map,x,y,nil
end

local function ZygorClassic_HandoffGoto318(destination,x,y)
    if not destination then return destination,x,y,nil end
    local current=GetRealZoneText and GetRealZoneText() or
                  (GetZoneText and GetZoneText()) or ""
    local key=string.lower(tostring(current))..">"..
              string.lower(tostring(destination))
    local handoff=ZygorClassicTravelHandoffs318[key]
    if handoff then return handoff.map,handoff.x,handoff.y,handoff.label end
    return destination,x,y,nil
end

-- TEST322: most guide transport steps name only the remote landing point,
-- but the immediately preceding step normally contains the flight master,
-- dock, tram, or portal coordinate.  Use that nearby local coordinate as a
-- safe generic fallback when a curated handoff node is not yet in the table.
local function ZygorClassic_TransportDeparture322(guide,stepIndex,lines,destination)
    local hasTransport=false
    local lineIndex
    for lineIndex=1,table.getn(lines or {}) do
        local lower=string.lower(tostring(lines[lineIndex] or ""))
        if string.find(lower,"fly ",1,true) or string.find(lower,"boat",1,true) or
           string.find(lower,"ship",1,true) or string.find(lower,"tram",1,true) or
           string.find(lower,"train",1,true) or string.find(lower,"portal",1,true) then
            hasTransport=true
            break
        end
    end
    if not hasTransport then return nil,nil,nil end
    local current=GetRealZoneText and GetRealZoneText() or
                  (GetZoneText and GetZoneText()) or ""
    if current=="" or string.lower(current)==string.lower(tostring(destination or "")) then
        return nil,nil,nil
    end
    local function findLocal(candidateLines)
        local i
        for i=table.getn(candidateLines or {}),1,-1 do
            local map,x,y=ZygorClassic_ParseGoto234(candidateLines[i])
            if x and y and (not map or string.lower(map)==string.lower(current)) then
                return current,x,y
            end
        end
        return nil,nil,nil
    end
    local map,x,y=findLocal(lines)
    if x and y then return map,x,y end
    local scan
    for scan=(tonumber(stepIndex) or 1)-1,math.max(1,(tonumber(stepIndex) or 1)-2),-1 do
        local prior=guide and guide.classic_steps and guide.classic_steps[scan]
        map,x,y=findLocal(prior and (prior.source or prior.raw))
        if x and y then return map,x,y end
    end
    return nil,nil,nil
end

function ZygorClassic_CurrentGoto55()
    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return nil end
    local step=guide.classic_steps and guide.classic_steps[ZygorClassicStepIndex or 1]
    local lines=step and (step.raw or step.source)
    if not lines then return nil end
    local i
    local zoneTarget234=nil
    for i=1,table.getn(lines) do
        local map,x,y,zoneTarget=ZygorClassic_ParseGoto234(lines[i])
        if x and y then
            -- A remote coordinate means this transition has a known local
            -- handoff node.  Use it until the player actually changes zones.
            local handoffMap,handoffX,handoffY,handoffLabel=
                ZygorClassic_HandoffGoto318(map,x,y)
            if handoffMap~=map or handoffX~=x or handoffY~=y then
                return handoffMap,handoffX,handoffY,handoffLabel
            end
            local departureMap,departureX,departureY=
                ZygorClassic_TransportDeparture322(guide,ZygorClassicStepIndex,lines,map)
            if departureX and departureY then return departureMap,departureX,departureY end
            local approachMap,approachX,approachY,approachLabel=
                ZygorClassic_NpcApproach331(lines,map,x,y)
            return approachMap,approachX,approachY,approachLabel
        end
        if zoneTarget then zoneTarget234=zoneTarget end
    end
    -- A zone-only step inherits the first coordinate found just inside that
    -- destination.  Search physical source order (not class applicability): an
    -- adjacent class branch still supplies a safe point inside the same zone.
    if zoneTarget234 then
        local scan=(ZygorClassicStepIndex or 1)+1
        local finish=math.min(table.getn(guide.classic_steps or {}),scan+7)
        while scan<=finish do
            local future=guide.classic_steps[scan]
            local futureLines=future and (future.source or future.raw) or {}
            for i=1,table.getn(futureLines) do
                local map,x,y=ZygorClassic_ParseGoto234(futureLines[i])
                if x and y and ((not map) or string.lower(map)==string.lower(zoneTarget234)) then
                    return ZygorClassic_HandoffGoto318(zoneTarget234,x,y)
                end
            end
            scan=scan+1
        end
        -- TEST245: the same fallback must cross an explicit guide boundary.
        -- Final travel steps have no later step in their own guide, so borrow
        -- the first waypoint inside the destination from the declared `next`
        -- guide instead of hiding the arrow.
        if (ZygorClassicStepIndex or 1)>=table.getn(guide.classic_steps or {}) and
           guide.classic_next and ZygorClassic_FindGuideByTitle242 then
            local nextIndex,nextGuide=ZygorClassic_FindGuideByTitle242(guide.classic_next)
            if nextIndex and nextGuide and ZygorClassic_EnsureParsed(nextGuide) then
                local nextStep=1
                local nextFinish=math.min(table.getn(nextGuide.classic_steps or {}),12)
                while nextStep<=nextFinish do
                    local future=nextGuide.classic_steps[nextStep]
                    local futureLines=future and (future.source or future.raw) or {}
                    for i=1,table.getn(futureLines) do
                        local map,x,y=ZygorClassic_ParseGoto234(futureLines[i])
                        if x and y and ((not map) or
                           string.lower(map)==string.lower(zoneTarget234)) then
                            return zoneTarget234,x,y
                        end
                    end
                    nextStep=nextStep+1
                end
            end
        end
    end
    -- Legacy `home` steps may carry no coordinate of their own. Inherit the
    -- previous route only when that step explicitly names an innkeeper; blindly
    -- reusing any previous coordinate leaves the arrow stuck on flight masters.
    local hasHome=false
    for i=1,table.getn(lines) do
        if string.find(string.lower(tostring(lines[i] or "")),"^home%s+") then hasHome=true break end
    end
    if hasHome and (ZygorClassicStepIndex or 1)>1 then
        local previous=guide.classic_steps[(ZygorClassicStepIndex or 1)-1]
        local previousLines=previous and (previous.raw or previous.source) or {}
        local previousIsInnkeeper=false
        for i=1,table.getn(previousLines) do
            local line=string.lower(tostring(previousLines[i] or ""))
            if string.find(line,"talk ",1,true) and string.find(line,"innkeeper",1,true) then
                previousIsInnkeeper=true
                break
            end
        end
        if previousIsInnkeeper then
            for i=1,table.getn(previousLines) do
                local line=string.lower(tostring(previousLines[i] or ""))
                local s,e,x,y=string.find(line,"goto%s+([%d%.]+),%s*([%d%.]+)")
                if x and y then return nil,tonumber(x),tonumber(y) end
                local s2,e2,map,x2,y2=string.find(line,"goto%s+([^,]+),%s*([%d%.]+),%s*([%d%.]+)")
                if map and x2 and y2 then return map,tonumber(x2),tonumber(y2) end
            end
        end
    end
    return nil
end

if ZygorSequentialGuard169 then ZygorSequentialGuard169:SetScript("OnUpdate",nil) end
if ZygorTurninGuard171 then ZygorTurninGuard171:SetScript("OnUpdate",nil) end

if not ZygorStateMachine172 then
    ZygorStateMachine172=CreateFrame("Frame","ZygorStateMachine172",UIParent)
    ZygorStateMachine172.elapsed=0
    ZygorStateMachine172.initialized=false
    ZygorStateMachine172:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.25 then return end
        this.elapsed=0
        local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                    ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
        if not guide or not ZygorClassic_EnsureParsed(guide) then return end
        if not ZygorStateMachine172.legacyDisabled then
            local legacy={
                "ZygorClassicLive53",
                "ZygorClassicTurninFrame62",
                "ZygorClassicRecoveryFrame64",
                "ZygorClassicBranch67Frame",
                "ZygorClassicProgress73Frame",
                "ZygorClassicOrder74Frame",
                "ZygorClassicRoute75Frame",
                "ZygorClassicOrdered76Frame",
                "ZygorClassicStartup77Frame",
                "ZygorClassicStartup79Frame",
                "ZygorClassicRouteLock83Frame",
                "ZygorClassicDelayedQuest93",
                "ZygorClassicStartup99Frame",
                "ZygorClassicInit100Frame",
                "ZygorClassicPoll107Frame",
                "ZygorClassicCorrect113Frame",
                "ZygorClassicCorrect114Frame"
            }
            local n
            for n=1,table.getn(legacy) do
                local frame=_G[legacy[n]]
                if frame then
                    frame:SetScript("OnUpdate",nil)
                    frame:SetScript("OnEvent",nil)
                end
            end
            ZygorStateMachine172.legacyDisabled=true
        end
        if ZygorClassic_RecordTurnins62 then ZygorClassic_RecordTurnins62() end
        local quests=ZygorClassic_QuestLog172()
        ZygorClassicDB=ZygorClassicDB or {}
        local key=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
        ZygorClassicDB.engine172=ZygorClassicDB.engine172 or {}
        local state=ZygorClassicDB.engine172[key]
        local startupGuideChanged188=false
        if ZygorStateMachine172.guideOwnerKey188~=key then
            -- First authoritative tick for this character. Saved progress is
            -- authoritative even when the player has reached the next guide's
            -- start level; the explicit final-step handoff below owns changes.
            local expected,expectedTitle=ZygorClassic_ExpectedGuide188()
            -- Guide registration is deferred and Alliance/Horde have different
            -- totals. Do not claim this character (or persist the currently
            -- displayed character's guide) until its exact title is present.
            if not expected then return end
            if state and state.guide and ZygorGuidesViewer.registeredguides[state.guide] then
                    if ZygorClassicGuideIndex~=state.guide then startupGuideChanged188=true end
                    ZygorClassicGuideIndex=state.guide
                    ZygorClassicStepIndex=state.step or 1
                    guide=ZygorGuidesViewer.registeredguides[state.guide]
                    if not guide or not ZygorClassic_EnsureParsed(guide) then return end
            elseif expected then
                    local savedGuide,savedStep=ZygorClassic_SavedCheckpoint342(key)
                    if savedGuide and savedStep and
                       ZygorGuidesViewer.registeredguides[savedGuide] then
                        startupGuideChanged188=true
                        ZygorClassicGuideIndex=savedGuide
                        ZygorClassicStepIndex=savedStep
                        guide=ZygorGuidesViewer.registeredguides[savedGuide]
                        if not guide or not ZygorClassic_EnsureParsed(guide) then return end
                        state={
                            guide=savedGuide,
                            step=savedStep,
                            recoveryFloor218=savedStep,
                            objectiveOwnerRevision229="TEST229",
                            objectiveSlotRevision230="TEST230",
                            exactChainRevision231="TEST231"
                        }
                        ZygorClassicDB.engine172[key]=state
                        if ZygorClassicDebug82 then
                            ZygorClassicDebug82.route="restored saved checkpoint -> G"..
                                tostring(savedGuide).." S"..tostring(savedStep).." (TEST342)"
                        end
                    else
                        startupGuideChanged188=true
                        ZygorClassicGuideIndex=expected
                        ZygorClassicStepIndex=1
                        guide=ZygorGuidesViewer.registeredguides[expected]
                        if not guide or not ZygorClassic_EnsureParsed(guide) then return end
                        state={guide=expected,step=ZygorClassic_Bootstrap172(guide,quests)}
                        ZygorClassicDB.engine172[key]=state
                        if ZygorClassicDebug82 then
                            ZygorClassicDebug82.route="startup guide -> "..tostring(expected)..
                                " ("..tostring(expectedTitle)..")"
                        end
                    end
            end
            ZygorStateMachine172.guideOwnerKey188=key

            -- Synchronize the older per-character stores once so their render
            -- wrappers cannot restore the rejected guide afterward.
            if state then
                local char=ZygorClassic_CharDB and ZygorClassic_CharDB()
                if char then
                    char.guide=state.guide
                    char.step=state.step
                end
                ZygorClassicDB.smart51=ZygorClassicDB.smart51 or {}
                ZygorClassicDB.smart51[key]={guide=state.guide,step=state.step}
                ZygorClassicDB.smart49=ZygorClassicDB.smart49 or {}
                ZygorClassicDB.smart50=ZygorClassicDB.smart50 or {}
                ZygorClassicDB.smart49[key]=true
                ZygorClassicDB.smart50[key]=true
            end
        elseif not state then
            guide=ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
            if not guide or not ZygorClassic_EnsureParsed(guide) then return end
            state={guide=ZygorClassicGuideIndex,step=ZygorClassic_Bootstrap172(guide,quests)}
            ZygorClassicDB.engine172[key]=state
        elseif state.guide~=ZygorClassicGuideIndex then
            -- TEST244: loading screens and legacy selectors may rewrite the
            -- displayed guide. Only the Guide button override below mutates
            -- authoritative state, so every unmarked mismatch is rejected.
            ZygorClassicGuideIndex=state.guide
            ZygorClassicStepIndex=state.step or 1
            guide=ZygorGuidesViewer.registeredguides[state.guide]
            if not guide or not ZygorClassic_EnsureParsed(guide) then return end
            startupGuideChanged188=true
            if ZygorClassicDebug82 then
                ZygorClassicDebug82.event="rejected non-user guide change"
            end
        end
        -- Repair saves already overwritten by the old level-only selector.
        -- A completed live quest whose turn-in belongs to the race guide is
        -- concrete evidence that its `next` guide was selected too early.
        ZygorClassicDB.crossGuideRepair242=ZygorClassicDB.crossGuideRepair242 or {}
        if state and not ZygorClassicDB.crossGuideRepair242[key] then
            local previousGuide,previousStep,pendingTitle=
                ZygorClassic_PredecessorRecovery242(state.guide,quests)
            ZygorClassicDB.crossGuideRepair242[key]=true
            if previousGuide and previousStep then
                local oldGuide=state.guide
                local oldStep=state.step or 1
                state.guide=previousGuide
                state.step=previousStep
                state.recoveryFloor218=previousStep
                ZygorClassicGuideIndex=previousGuide
                ZygorClassicStepIndex=previousStep
                guide=ZygorGuidesViewer.registeredguides[previousGuide]
                startupGuideChanged188=true
                local char=ZygorClassic_CharDB and ZygorClassic_CharDB()
                if char then
                    char.guide=previousGuide
                    char.step=previousStep
                end
                ZygorClassicDB.smart51=ZygorClassicDB.smart51 or {}
                ZygorClassicDB.smart51[key]={guide=previousGuide,step=previousStep}
                if ZygorClassicDebug82 then
                    ZygorClassicDebug82.route="G"..tostring(oldGuide).." S"..tostring(oldStep)..
                        " -> G"..tostring(previousGuide).." S"..tostring(previousStep)..
                        " (TEST242 pending turnin "..tostring(pendingTitle)..")"
                end
            end
        end
        -- TEST244 repeats the predecessor audit with confirmed-turn-in evidence
        -- for characters whose TEST243 state was overwritten during a hearth.
        ZygorClassicDB.crossGuideRepair244=ZygorClassicDB.crossGuideRepair244 or {}
        if state and not ZygorClassicDB.crossGuideRepair244[key] then
            local previousGuide,previousStep,pendingTitle=
                ZygorClassic_PredecessorRecovery242(state.guide,quests)
            ZygorClassicDB.crossGuideRepair244[key]=true
            if previousGuide and previousStep then
                local oldGuide=state.guide
                local oldStep=state.step or 1
                state.guide=previousGuide
                state.step=previousStep
                state.recoveryFloor218=previousStep
                ZygorClassicGuideIndex=previousGuide
                ZygorClassicStepIndex=previousStep
                guide=ZygorGuidesViewer.registeredguides[previousGuide]
                startupGuideChanged188=true
                local char=ZygorClassic_CharDB and ZygorClassic_CharDB()
                if char then
                    char.guide=previousGuide
                    char.step=previousStep
                end
                ZygorClassicDB.smart51=ZygorClassicDB.smart51 or {}
                ZygorClassicDB.smart51[key]={guide=previousGuide,step=previousStep}
                if ZygorClassicDebug82 then
                    ZygorClassicDebug82.route="G"..tostring(oldGuide).." S"..tostring(oldStep)..
                        " -> G"..tostring(previousGuide).." S"..tostring(previousStep)..
                        " (TEST244 confirmed predecessor "..tostring(pendingTitle)..")"
                end
            end
        end
        -- TEST226 repairs saves already stranded by the old cross-quest
        -- objective match. Re-evaluate once with strict |q ownership and only
        -- move forward; a completed live quest then lands on its real turn-in
        -- step without erasing deliberate earlier/manual progress.
        if state and state.bootstrapRevision226~="TEST226" then
            local repaired=ZygorClassic_Bootstrap172(guide,quests)
            state.bootstrapRevision226="TEST226"
            if repaired and repaired>(state.step or 1) then
                local old=state.step or 1
                state.step=repaired
                state.recoveryFloor218=repaired
                ZygorClassicStepIndex=repaired
                startupGuideChanged188=true
                if ZygorClassicDebug82 then
                    ZygorClassicDebug82.route=tostring(old).." -> "..tostring(repaired)..
                        " (TEST226 strict objective-owner rebootstrap)"
                end
            end
        end
        if state and state.handoffRevision228~="TEST228" then
            local handoffRepair=ZygorClassic_ConfirmedLiveHandoff228(guide,quests)
            state.handoffRevision228="TEST228"
            if handoffRepair and handoffRepair>(state.step or 1) then
                local old=state.step or 1
                state.step=handoffRepair
                state.recoveryFloor218=handoffRepair
                ZygorClassicStepIndex=handoffRepair
                startupGuideChanged188=true
                if ZygorClassicDebug82 then
                    ZygorClassicDebug82.route=tostring(old).." -> "..tostring(handoffRepair)..
                        " (TEST228 confirmed live handoff)"
                end
            end
        end
        -- Repair the single step skipped by the old cross-quest objective
        -- matcher. This is deliberately adjacent and objective-only.
        if state and state.objectiveOwnerRevision229~="TEST229" then
            state.objectiveOwnerRevision229="TEST229"
            local previous=ZygorClassic_PreviousStep213 and
                           ZygorClassic_PreviousStep213(guide,state.step or 1) or
                           ((state.step or 1)-1)
            local previousStep=guide.classic_steps[previous]
            local previousResolved,previousReason=
                ZygorClassic_StepState172(previousStep,quests,guide,previous)
            if previous and previous<(state.step or 1) and not previousResolved and
               ZygorClassic_IsObjectiveTodo220(previousReason) then
                local old=state.step or 1
                state.step=previous
                state.recoveryFloor218=previous
                ZygorClassicStepIndex=previous
                startupGuideChanged188=true
                if ZygorClassicDebug82 then
                    ZygorClassicDebug82.route=tostring(old).." -> "..tostring(previous)..
                        " (TEST229 restore quest-owned objective)"
                end
            end
        end
        if state and state.objectiveSlotRevision230~="TEST230" then
            state.objectiveSlotRevision230="TEST230"
            local previous=ZygorClassic_PreviousStep213 and
                           ZygorClassic_PreviousStep213(guide,state.step or 1) or
                           ((state.step or 1)-1)
            local previousStep=guide.classic_steps[previous]
            local previousResolved,previousReason=
                ZygorClassic_StepState172(previousStep,quests,guide,previous)
            if previous and previous<(state.step or 1) and not previousResolved and
               ZygorClassic_IsObjectiveTodo220(previousReason) then
                local old=state.step or 1
                state.step=previous
                state.recoveryFloor218=previous
                ZygorClassicStepIndex=previous
                startupGuideChanged188=true
                if ZygorClassicDebug82 then
                    ZygorClassicDebug82.route=tostring(old).." -> "..tostring(previous)..
                        " (TEST230 restore exact objective slot)"
                end
            end
        end
        if state and state.exactChainRevision231~="TEST231" then
            state.exactChainRevision231="TEST231"
            local previous=ZygorClassic_PreviousStep213 and
                           ZygorClassic_PreviousStep213(guide,state.step or 1) or
                           ((state.step or 1)-1)
            local previousStep=guide.classic_steps[previous]
            local previousResolved,previousReason=
                ZygorClassic_StepState172(previousStep,quests,guide,previous)
            if previous and previous<(state.step or 1) and not previousResolved and
               string.find(tostring(previousReason or ""),"waiting chain handoff:",1,true)==1 then
                local old=state.step or 1
                state.step=previous
                state.recoveryFloor218=previous
                ZygorClassicStepIndex=previous
                startupGuideChanged188=true
                if ZygorClassicDebug82 then
                    ZygorClassicDebug82.route=tostring(old).." -> "..tostring(previous)..
                        " (TEST231 restore exact chain turnin)"
                end
            end
        end
        local changed=startupGuideChanged188
        -- A saved position can point at content newly classified as unavailable
        -- by a backport revision. Move to the next applicable step while keeping
        -- original guide numbering and any valid steps between excluded blocks.
        local currentApplicable232=guide.classic_steps[state.step or 1]
        if currentApplicable232 and ZygorClassic_StepApplies67 and
           not ZygorClassic_StepApplies67(currentApplicable232) then
            local old=state.step or 1
            local target=ZygorClassic_NextStep172(guide,old)
            if target and target~=old then
                state.step=target
                state.recoveryFloor218=target
                ZygorClassicStepIndex=target
                startupGuideChanged188=true
                changed=true
                if ZygorClassicDebug82 then
                    ZygorClassicDebug82.route=tostring(old).." -> "..tostring(target)..
                        " (TEST233 generated unavailable 1.12 step)"
                end
            end
        end
        if (ZygorClassicStepIndex or 1)~=state.step then
            ZygorClassicStepIndex=state.step
            changed=true
        end
        -- Capture live quest evidence before honoring a manual browse lock.
        -- Without this, a quest accepted or completed while the user had used a
        -- Step button was never recorded, so a later cold boot could mistake a
        -- finished numbered chain for an unaccepted one and restore stale data.
        state.inflightSeen191=state.inflightSeen191 or {}
        local activeTitle
        for activeTitle in pairs(quests) do state.inflightSeen191[activeTitle]=true end
        -- A manual Step-button selection is a browsing decision. Hold it long
        -- enough to render and inspect, but do not leave it permanently locked
        -- when the live quest state already proves the selected step complete.
        -- TEST218's persisted recovery floor prevents the old rewind while this
        -- short TEST219 stability window lets the normal resolver resume.
        if ZygorClassicManualLock194 and ZygorClassicManualLock194[key] then
            local meta=ZygorClassicManualMeta213 and ZygorClassicManualMeta213[key]
            local signature=ZygorClassic_QuestSignature213(quests)
            local now=GetTime and GetTime() or 0
            local since=tonumber(ZygorClassicManualLock194[key]) or now
            local stable=(now-since)>=2.00
            if (meta and meta.signature~=signature) or stable then
                ZygorClassicManualLock194[key]=nil
                if ZygorClassicManualMeta213 then ZygorClassicManualMeta213[key]=nil end
                if ZygorClassicDebug82 then
                    if stable then
                        ZygorClassicDebug82.event="manual browse released: stable boundary"
                    else
                        ZygorClassicDebug82.event="manual browse released: live quest state changed"
                    end
                end
            end
        end
        if ZygorClassicManualLock194 and ZygorClassicManualLock194[key] then
            if ZygorClassicDebug82 then
                ZygorClassicDebug82.engine172="S"..tostring(state.step).." manual browse lock"
            end
            if changed then
                if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
                if ZygorClassic_Render then ZygorClassic_Render() end
                if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
                if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
            end
            return
        end
        -- Persist proof of quests actually observed on this character.  The
        -- recovery engine may only rewind one of these; absence alone is not
        -- proof that an earlier guide quest was abandoned.
        state.inflightSeen191=state.inflightSeen191 or {}
        -- Evaluate direct live objective evidence before any inferred
        -- recovery.  If an older revision raised the recovery floor past a
        -- still-active unfinished objective, repair that saved state once and
        -- lower the floor to the objective.  While the current step owns an
        -- unfinished objective, no recovery helper may move away from it.
        -- A current objective for a quest that was never accepted is direct
        -- evidence that the saved route crossed its pickup.  Repair it before
        -- ordinary recovery-floor rules, then pin this poll on the accept step.
        local missingPickup251,missingPickupTitle251,missingPickupID251=
            ZygorClassic_CurrentObjectivePickup251(guide,quests,state.step)
        if missingPickup251 and missingPickup251<state.step and
           (not tonumber(state.hardFloor324) or missingPickup251>=tonumber(state.hardFloor324)) then
            local old=state.step
            state.step=missingPickup251
            state.recoveryFloor218=missingPickup251
            state.missingSince191={}
            ZygorClassicStepIndex=missingPickup251
            changed=true
            if ZygorClassicDebug82 then
                ZygorClassicDebug82.route=tostring(old).." -> "..tostring(missingPickup251)..
                    " (TEST251 accept missing q="..tostring(missingPickupID251)..
                    " "..tostring(missingPickupTitle251)..")"
                ZygorClassicDebug82.event="RECOVER QUEST PICKUP: "..tostring(missingPickupTitle251)
            end
        end
        local currentStep220=guide.classic_steps[state.step]
        local currentResolved220,currentReason220=
            ZygorClassic_StepState172(currentStep220,quests,guide,state.step)
        local objectivePinned220=
            (missingPickup251 and true) or
            ((not currentResolved220) and ZygorClassic_IsObjectiveTodo220(currentReason220))
        if not objectivePinned220 and tonumber(state.recoveryFloor218) then
            local repairStep220,repairReason220=
                ZygorClassic_EarlierLiveObjective220(guide,quests,state.step)
            if repairStep220 and repairStep220<tonumber(state.recoveryFloor218) and
               (not tonumber(state.hardFloor324) or repairStep220>=tonumber(state.hardFloor324)) then
                local old=state.step
                state.step=repairStep220
                state.recoveryFloor218=repairStep220
                ZygorClassicStepIndex=repairStep220
                changed=true
                objectivePinned220=true
                currentReason220=repairReason220
                if ZygorClassicDebug82 then
                    ZygorClassicDebug82.route=tostring(old).." -> "..tostring(repairStep220)..
                        " (TEST220 restore live objective)"
                end
            end
        end
        -- TEST221: a live quest whose earlier guide step turns it in is direct
        -- evidence, just like an unfinished objective.  It may repair a stale
        -- recovery floor raised by an oversized forward jump.  Pin this poll
        -- so later inferred recovery rules cannot immediately move away again.
        if not objectivePinned220 then
            local liveTurnin221,liveTurninTitle221=
                ZygorClassic_PendingPriorTurnin174(guide,quests,state.step)
            if liveTurnin221 and liveTurnin221<state.step and
               (not tonumber(state.hardFloor324) or liveTurnin221>=tonumber(state.hardFloor324)) then
                local old=state.step
                state.step=liveTurnin221
                state.recoveryFloor218=liveTurnin221
                ZygorClassicStepIndex=liveTurnin221
                changed=true
                objectivePinned220=true
                if ZygorClassicDebug82 then
                    ZygorClassicDebug82.route=tostring(old).." -> "..tostring(liveTurnin221)..
                        " (TEST221 restore live turnin "..tostring(liveTurninTitle221)..")"
                end
            end
        end
        if not objectivePinned220 then
        -- A numbered follow-up can disappear at its own turn-in before the
        -- Vanilla client reports a usable reward event.  Recover that exact
        -- quest part from the adjacent guide handoff and the destination
        -- coordinates before older missing-accept recovery can rewind it.
        if ZygorClassic_ForwardTurninRecovery216 then
            local recoveredStep,recoveredTitle,recoveredID=
                ZygorClassic_ForwardTurninRecovery216(guide,quests,state)
            if recoveredStep and recoveredStep>state.step then
                local old=state.step
                state.step=recoveredStep
                ZygorClassic_RaiseRecoveryFloor218(state,recoveredStep)
                ZygorClassicStepIndex=recoveredStep
                changed=true
                if ZygorClassicDebug82 then
                    ZygorClassicDebug82.route=tostring(old).." -> "..tostring(recoveredStep)..
                        " (exact turnin q="..tostring(recoveredID).." "..tostring(recoveredTitle)..")"
                end
            end
        end
        local missingAccept202,missingAcceptTitle202,missingAcceptQuestID202=
            ZygorClassic_CurrentMissingAccept202(guide,quests,state.step)
        local handoffTarget,handoffStep=nil,nil
        if missingAccept202 then
            handoffTarget,handoffStep=ZygorClassic_ProvenHandoffAhead199(
                guide,quests,state.step,state,missingAcceptTitle202,missingAcceptQuestID202)
        end
        if handoffTarget and handoffTarget>state.step then
            local old=state.step
            state.step=handoffTarget
            ZygorClassic_RaiseRecoveryFloor218(state,handoffTarget)
            ZygorClassicStepIndex=handoffTarget
            changed=true
            if ZygorClassicDebug82 then
                ZygorClassicDebug82.route=tostring(old).." -> "..tostring(handoffTarget)..
                    " (follow-up proves handoff S"..tostring(handoffStep)..")"
            end
        end
        local missingStep,missingTitle=ZygorClassic_MissingInflightQuest187(guide,quests,state.step,state)
        if ZygorClassic_RecoveryAllowed218(state,missingStep) then
            local old=state.step
            state.step=missingStep
            ZygorClassicStepIndex=missingStep
            changed=true
            if ZygorClassicDebug82 then
                ZygorClassicDebug82.route=tostring(old).." -> "..tostring(missingStep)..
                    " (reacquire missing "..tostring(missingTitle)..")"
            end
        end
        local previousLevel,requiredLevel=ZygorClassic_PreviousLevelUnmet212(guide,state.step)
        if ZygorClassic_RecoveryAllowed218(state,previousLevel) then
            local old=state.step
            state.step=previousLevel
            ZygorClassicStepIndex=previousLevel
            changed=true
            if ZygorClassicDebug82 then
                ZygorClassicDebug82.route=tostring(old).." -> "..tostring(previousLevel)..
                    " (recover level "..tostring(requiredLevel).." gate)"
            end
        end
        local previousHome,homeTarget=ZygorClassic_PreviousHomeUnfinished202(guide,state.step)
        if ZygorClassic_RecoveryAllowed218(state,previousHome) then
            local old=state.step
            state.step=previousHome
            ZygorClassicStepIndex=previousHome
            changed=true
            if ZygorClassicDebug82 then
                ZygorClassicDebug82.route=tostring(old).." -> "..tostring(previousHome)..
                    " (set home "..tostring(homeTarget)..")"
            end
        end
        local previousChain,chainReason=ZygorClassic_PreviousChainHandoff207(guide,quests,state.step)
        if ZygorClassic_RecoveryAllowed218(state,previousChain) then
            local old=state.step
            state.step=previousChain
            ZygorClassicStepIndex=previousChain
            changed=true
            if ZygorClassicDebug82 then
                ZygorClassicDebug82.route=tostring(old).." -> "..tostring(previousChain)..
                    " (recover "..tostring(chainReason)..")"
            end
        end
        -- If an older objective matcher advanced past the immediately previous
        -- step, recover that one skipped objective.  Limiting this to one step
        -- avoids rewinding into deliberately deferred quests elsewhere in the
        -- guide while still repairing saved state after a matcher upgrade.
        if ZygorClassic_PreviousObjectiveUnfinished196 then
            local previous,previousText=ZygorClassic_PreviousObjectiveUnfinished196(guide,state.step)
            if ZygorClassic_RecoveryAllowed218(state,previous) then
                local old=state.step
                state.step=previous
                ZygorClassicStepIndex=previous
                changed=true
                if ZygorClassicDebug82 then
                    ZygorClassicDebug82.route=tostring(old).." -> "..tostring(previous)..
                        " (recover skipped objective "..tostring(previousText)..")"
                end
            end
        end
        local pending,pendingTitle=ZygorClassic_PendingPriorTurnin174(guide,quests,state.step)
        if ZygorClassic_RecoveryAllowed218(state,pending) then
            local old=state.step
            state.step=pending
            ZygorClassicStepIndex=pending
            changed=true
            if ZygorClassicDebug82 then
                ZygorClassicDebug82.route=tostring(old).." -> "..tostring(pending)..
                    " (pending turnin "..tostring(pendingTitle)..")"
            end
        end
        end
        local step=guide.classic_steps[state.step]
        -- Some 1.12 servers remove a handed-in quest without firing the
        -- QUEST_COMPLETE/QUEST_FINISHED pair used by TEST191.  TEST215 adds a
        -- conservative fallback: the quest must have been observed live on
        -- this character, must now be absent on its explicit turn-in step,
        -- and the player must be standing at that step's waypoint.
        if ZygorClassic_TurninArrivalWitness215 then
            local witnessed,witnessTitle=ZygorClassic_TurninArrivalWitness215(step,quests,state)
            if witnessed then
                changed=true
                if ZygorClassicDebug82 then
                    ZygorClassicDebug82.event="TURNIN ARRIVAL WITNESS: "..tostring(witnessTitle)
                end
            end
        end
        local resolved,reason=ZygorClassic_StepState172(step,quests,guide,state.step)
        if not resolved and reason=="manual/travel step" then
            local catchupStep,catchupZone=ZygorClassic_TravelCatchup302(guide,state.step)
            if catchupStep and catchupStep>state.step then
                local old=state.step
                state.step=catchupStep
                ZygorClassicStepIndex=catchupStep
                step=guide.classic_steps[catchupStep]
                resolved,reason=ZygorClassic_StepState172(step,quests,guide,catchupStep)
                changed=true
                if ZygorClassicDebug82 then
                    ZygorClassicDebug82.route=tostring(old).." -> "..tostring(catchupStep)..
                        " (TEST302 travel catch-up: "..tostring(catchupZone)..")"
                end
            end
            local zoneArrival=ZygorClassic_ZoneArrivalProof234(step)
            if zoneArrival then
                resolved=true
                reason="zone arrival: "..tostring(zoneArrival)
            else
                local consumed,useItemID=ZygorClassic_UseConsumptionProof232(
                    step,state,state.guide or ZygorClassicGuideIndex,state.step)
                if consumed then
                    resolved=true
                    reason="use item consumed: "..tostring(useItemID)
                else
                    local proofStep,proofText=ZygorClassic_NextObjectiveProof182(guide,state.step)
                    if proofStep then
                        resolved=true
                        reason="travel proven by S"..tostring(proofStep)..": "..tostring(proofText)
                    else
                        local arrival=ZygorClassic_ArrivalProof186(step)
                        if arrival then
                            resolved=true
                            reason="travel arrival: "..tostring(arrival)
                        end
                    end
                end
            end
        end
        if ZygorClassicDebug82 then
            ZygorClassicDebug82.engine172="S"..tostring(state.step).." "..tostring(reason)
        end
        if resolved then
            local target=ZygorClassic_NextStep172(guide,state.step)
            if target~=state.step then
                local old=state.step
                state.step=target
                ZygorClassicStepIndex=target
                changed=true
                if ZygorClassicDebug82 then
                    local skipped=target-old-1
                    local trace=""
                    if skipped>0 then
                        trace="; skipped "..tostring(skipped).." non-applicable "..
                              (skipped==1 and "step" or "steps")
                    end
                    ZygorClassicDebug82.route=tostring(old).." -> "..tostring(target)..
                        " (engine172"..trace..")"
                end
            elseif state.step>=table.getn(guide.classic_steps or {}) and guide.classic_next then
                local nextGuideIndex,nextGuide=
                    ZygorClassic_FindGuideByTitle242(guide.classic_next)
                if nextGuideIndex and nextGuide and ZygorClassic_EnsureParsed(nextGuide) then
                    local oldGuide=state.guide
                    state.guide=nextGuideIndex
                    state.step=1
                    state.recoveryFloor218=1
                    ZygorClassicGuideIndex=nextGuideIndex
                    ZygorClassicStepIndex=1
                    guide=nextGuide
                    changed=true
                    if ZygorClassicDebug82 then
                        ZygorClassicDebug82.route="G"..tostring(oldGuide).." complete -> G"..
                            tostring(nextGuideIndex).." S1 (TEST242 explicit guide handoff)"
                    end
                end
            end
        end
        if changed then
            if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
            if ZygorClassic_Render then ZygorClassic_Render() end
            if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
            if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
        end
    end)
end

ZygorClassic_UpdateDebug82_Base172=ZygorClassic_UpdateDebug82
ZygorClassic_UpdateDebug82=function()
    if ZygorClassic_UpdateDebug82_Base172 then ZygorClassic_UpdateDebug82_Base172() end
    if ZygorClassicDebugText82 then
        local t=ZygorClassicDebugText82:GetText() or ""
        t=t.."\nEngine172: "..tostring(ZygorClassicDebug82 and ZygorClassicDebug82.engine172 or "starting")
        ZygorClassicDebugText82:SetText(t)
    end
end

ZYGOR_BACKPORT_VERSION = "TEST172"

ZYGOR_BACKPORT_VERSION = "TEST173"

ZYGOR_BACKPORT_VERSION = "TEST174"

ZYGOR_BACKPORT_VERSION = "TEST189"

-- TEST190: Vanilla may not expose UnitFactionGroup during initial addon file
-- execution on a cold client start.  Guide database files use this helper to
-- postpone their one-time registration until the character API is ready.
function ZygorClassic_DeferredGuideLoad190(loader,name)
    ZygorClassicDeferred190Status=ZygorClassicDeferred190Status or {}
    if loader and loader() then
        ZygorClassicDeferred190Status[name or "Guides"]="done"
        return
    end
    ZygorClassicDeferred190Status[name or "Guides"]="waiting for faction"
    local frameName="ZygorClassicDeferred190"..tostring(name or "Guides")
    if _G[frameName] then return end
    local frame=CreateFrame("Frame",frameName,UIParent)
    frame.elapsed=0
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent",function()
        if loader and loader() then
            ZygorClassicDeferred190Status[name or "Guides"]="done"
            this:UnregisterEvent("PLAYER_ENTERING_WORLD")
            this:SetScript("OnUpdate",nil)
        end
    end)
    frame:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.10 then return end
        this.elapsed=0
        if loader and loader() then
            ZygorClassicDeferred190Status[name or "Guides"]="done"
            this:UnregisterEvent("PLAYER_ENTERING_WORLD")
            this:SetScript("OnUpdate",nil)
        end
    end)
end

ZygorClassic_UpdateDebug82_Base190=ZygorClassic_UpdateDebug82
ZygorClassic_UpdateDebug82=function()
    if ZygorClassic_UpdateDebug82_Base190 then ZygorClassic_UpdateDebug82_Base190() end
    if ZygorClassicDebugText82 then
        local total=0
        if ZygorGuidesViewer and ZygorGuidesViewer.registeredguides then
            total=table.getn(ZygorGuidesViewer.registeredguides)
        end
        local faction=ZygorClassic_Faction262() or "waiting"
        local t=ZygorClassicDebugText82:GetText() or ""
        if not string.find(t,"Cold load190:",1,true) then
            t=t.."\nCold load190: "..tostring(total).." guides / "..tostring(faction)
        end
        ZygorClassicDebugText82:SetText(t)
    end
end

ZYGOR_BACKPORT_VERSION = "TEST190"

-- TEST191: authoritative Vanilla turn-in witness. QUEST_COMPLETE identifies
-- the reward-dialog quest; after QUEST_FINISHED, disappearance from the live
-- log proves a hand-in rather than an abandon.
ZygorClassicTurninWitness191Pending=ZygorClassicTurninWitness191Pending or {}

function ZygorClassic_WitnessTitle191()
    local title=GetTitleText and GetTitleText() or nil
    if not title or title=="" then
        local selected=GetQuestLogSelection and GetQuestLogSelection() or nil
        if selected then title=GetQuestLogTitle(selected) end
    end
    if title and title~="" then return title end
    return nil
end

function ZygorClassic_CommitWitness191(title)
    if not title then return false end
    ZygorClassicDB=ZygorClassicDB or {}
    ZygorClassicDB.turnins62=ZygorClassicDB.turnins62 or {}
    ZygorClassicDB.confirmedTurnins224=ZygorClassicDB.confirmedTurnins224 or {}
    local key=ZygorClassic_Key62()
    ZygorClassicDB.turnins62[key]=ZygorClassicDB.turnins62[key] or {}
    ZygorClassicDB.confirmedTurnins224[key]=ZygorClassicDB.confirmedTurnins224[key] or {}
    ZygorClassicDB.turnins62[key][title]=true
    ZygorClassicDB.confirmedTurnins224[key][title]=true
    return true
end

if not ZygorClassicTurninWitness191 then
    ZygorClassicTurninWitness191=CreateFrame("Frame","ZygorClassicTurninWitness191",UIParent)
    ZygorClassicTurninWitness191:RegisterEvent("QUEST_COMPLETE")
    ZygorClassicTurninWitness191:RegisterEvent("QUEST_FINISHED")
    ZygorClassicTurninWitness191.elapsed=0
    ZygorClassicTurninWitness191:SetScript("OnEvent",function()
        if event=="QUEST_COMPLETE" then
            if ZygorClassic_StageConfirmedTurnin225 then ZygorClassic_StageConfirmedTurnin225() end
            local title=ZygorClassic_WitnessTitle191()
            if title then
                local key=ZygorClassic_Key62()
                ZygorClassicTurninWitness191Pending[key]=title
            end
        elseif event=="QUEST_FINISHED" then
            local earlyTitle=nil
            if ZygorClassic_CommitConfirmedTurnin225 then
                earlyTitle=ZygorClassic_CommitConfirmedTurnin225()
            end
            local key=ZygorClassic_Key62()
            local title=ZygorClassicTurninWitness191Pending[key]
            if title and not earlyTitle then
                ZygorClassicDB=ZygorClassicDB or {}
                ZygorClassicDB.chainHandoffs207=ZygorClassicDB.chainHandoffs207 or {}
                ZygorClassicDB.chainHandoffs207[key]=ZygorClassicDB.chainHandoffs207[key] or {}
                ZygorClassicDB.chainHandoffs207[key][ZygorClassic_NormalizeQuestTitle170(title)]=true
                ZygorClassic_CommitWitness191(title)
                ZygorClassicTurninWitness191Pending[key]=nil
                if ZygorClassicDebug82 then ZygorClassicDebug82.event="CONFIRMED TURNIN: "..tostring(title) end
            end
        end
    end)
    -- TEST224 commits synchronously in QUEST_FINISHED. No poll/disappearance
    -- fallback may promote the staged title into confirmed history.
    ZygorClassicTurninWitness191:SetScript("OnUpdate",nil)
end

ZYGOR_BACKPORT_VERSION = "TEST191"

-- TEST192: navigation buttons write through to engine172, the same state
-- automation reads every tick.  Older buttons changed only the visible global
-- index, so the authoritative engine immediately snapped the viewer back.
function ZygorClassic_NextStep(delta,userClick)
    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return end

    -- Only the two visible Step buttons may create a manual browse state.
    -- Older/internal calls that happen during quest-dialog updates must never
    -- overwrite the authoritative engine position.
    if not userClick then
        if ZygorClassicDebug82 then
            ZygorClassicDebug82.event="ignored internal step navigation"
        end
        return
    end

    ZygorClassicDB=ZygorClassicDB or {}
    ZygorClassicDB.engine172=ZygorClassicDB.engine172 or {}
    local key=ZygorClassic_Key62()
    local state=ZygorClassicDB.engine172[key] or {}
    local base=ZygorClassicStepIndex or 1
    if state.guide==(ZygorClassicGuideIndex or 1) and state.step then base=state.step end
    local target=base
    if (delta or 0)>0 then
        target=ZygorClassic_NextStep172(guide,base)
    elseif (delta or 0)<0 then
        target=ZygorClassic_PreviousStep213(guide,base)
    end
    local count=table.getn(guide.classic_steps or {})
    if target<1 then target=1 end
    if count>0 and target>count then target=count end

    ZygorClassicStepIndex=target
    state.guide=ZygorClassicGuideIndex or 1
    state.step=target
    -- A deliberate manual choice overrides stale recovery evidence. Preserve
    -- quests already observed on this character and establish a durable lower
    -- boundary so a later quest event cannot snap behind the selected step.
    state.recoveryFloor218=target
    state.hardFloor324=target
    state.inflightSeen191=state.inflightSeen191 or {}
    state.missingSince191={}
    ZygorClassicDB.engine172[key]=state
    ZygorClassicManualLock194=ZygorClassicManualLock194 or {}
    ZygorClassicManualLock194[key]=GetTime and GetTime() or 0
    ZygorClassicManualMeta213=ZygorClassicManualMeta213 or {}
    ZygorClassicManualMeta213[key]={
        signature=ZygorClassic_QuestSignature213(ZygorClassic_QuestLog172()),
        target=target
    }

    if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
    if ZygorClassic_SaveProgress then ZygorClassic_SaveProgress() end
    if ZygorClassicDebug82 then
        ZygorClassicDebug82.route="manual -> "..tostring(target)
        ZygorClassicDebug82.engine172="S"..tostring(target).." manual selection"
    end
    if ZygorClassic_Render then ZygorClassic_Render() end
    if ZygorClassic_UpdateWaypointText then ZygorClassic_UpdateWaypointText() end
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
end

-- Replace the early closures so only a genuine click passes userClick=true.
-- This also makes the buttons traverse applicable class/race steps from the
-- authoritative engine index rather than a stale rendered global index.
if ZygorClassicPrevStepButton then
    ZygorClassicPrevStepButton:SetScript("OnClick",function() ZygorClassic_NextStep(-1,true) end)
end
if ZygorClassicNextStepButton then
    ZygorClassicNextStepButton:SetScript("OnClick",function() ZygorClassic_NextStep(1,true) end)
end

-- TEST244: Guide navigation follows the same explicit-click rule as Step
-- navigation. This function updates authoritative state itself, so a random
-- guide-index rewrite during PLAYER_ENTERING_WORLD can never impersonate it.
function ZygorClassic_NextGuide(delta,userClick)
    if not userClick then return end
    local guides=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides
    local total=guides and table.getn(guides) or 0
    if total<1 then return end
    local target=(ZygorClassicGuideIndex or 1)+(delta or 0)
    if target<1 then target=total end
    if target>total then target=1 end
    local guide=guides[target]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return end
    ZygorClassicDB=ZygorClassicDB or {}
    ZygorClassicDB.engine172=ZygorClassicDB.engine172 or {}
    local key=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
    local state=ZygorClassicDB.engine172[key] or {}
    state.guide=target
    state.step=1
    state.recoveryFloor218=1
    ZygorClassicDB.engine172[key]=state
    ZygorClassicDB.manualGuide247=ZygorClassicDB.manualGuide247 or {}
    ZygorClassicDB.manualGuide247[key]=target
    ZygorClassicGuideIndex=target
    ZygorClassicStepIndex=1
    if ZygorClassicDebug82 then
        ZygorClassicDebug82.route="manual guide -> G"..tostring(target).." S1"
    end
    if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
    if ZygorClassic_Render then ZygorClassic_Render() end
    if ZygorClassic_UpdateWaypointText then ZygorClassic_UpdateWaypointText() end
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
end

if ZygorClassicPrevGuideButton then
    ZygorClassicPrevGuideButton:SetScript("OnClick",function() ZygorClassic_NextGuide(-1,true) end)
end
if ZygorClassicNextGuideButton then
    ZygorClassicNextGuideButton:SetScript("OnClick",function() ZygorClassic_NextGuide(1,true) end)
end

ZYGOR_BACKPORT_VERSION = "TEST192"

-- TEST193: show the live Vanilla/private-server objective text in the main
-- step panel when it differs from the imported guide requirement.
function ZygorClassic_PlainReplace193(text,old,new)
    local first,last=string.find(text or "",old or "",1,true)
    if not first then return text end
    return string.sub(text,1,first-1)..tostring(new or old)..string.sub(text,last+1)
end

ZygorClassic_Render_Base193=ZygorClassic_Render
ZygorClassic_Render=function()
    if ZygorClassic_Render_Base193 then ZygorClassic_Render_Base193() end
    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local step=guide and guide.classic_steps and guide.classic_steps[ZygorClassicStepIndex or 1]
    if not ZygorClassicBody or not step or not ZygorClassic_StepObjectiveLines87 then return end
    local body=ZygorClassicBody:GetText() or ""
    local objectives=ZygorClassic_StepObjectiveLines87(step)
    local i
    for i=1,table.getn(objectives) do
        if objectives[i].line and objectives[i].text then
            body=ZygorClassic_PlainReplace193(body,objectives[i].line,objectives[i].text)
        end
    end
    ZygorClassicBody:SetText(body)
end

ZYGOR_BACKPORT_VERSION = "TEST193"

-- TEST194: release manual browsing only when gameplay state changes.  The
-- short guard ignores a quest-log event already queued before the click.
if not ZygorClassicManualUnlock194 then
    ZygorClassicManualUnlock194=CreateFrame("Frame","ZygorClassicManualUnlock194",UIParent)
    ZygorClassicManualUnlock194:RegisterEvent("QUEST_LOG_UPDATE")
    ZygorClassicManualUnlock194:RegisterEvent("QUEST_ACCEPTED")
    ZygorClassicManualUnlock194:RegisterEvent("QUEST_COMPLETE")
    ZygorClassicManualUnlock194:RegisterEvent("QUEST_FINISHED")
    ZygorClassicManualUnlock194:RegisterEvent("PLAYER_LEVEL_UP")
    ZygorClassicManualUnlock194:SetScript("OnEvent",function()
        if not ZygorClassicManualLock194 then return end
        local key=ZygorClassic_Key62()
        local since=ZygorClassicManualLock194[key]
        if since and ((GetTime and GetTime() or 0)-since)>0.30 then
            ZygorClassicManualLock194[key]=nil
            if ZygorClassicManualMeta213 then ZygorClassicManualMeta213[key]=nil end
            if ZygorClassicDebug82 then ZygorClassicDebug82.event="manual browse released: "..tostring(event) end
        end
    end)
end

ZYGOR_BACKPORT_VERSION = "TEST194"

-- TEST195: authoritative native-pointer route ownership. The TEST164 bridge
-- cached only coordinates and could remain attached to an older step after
-- automatic progression. Key by guide+step+route and verify the actual marker.
if ZygorPointerBridgeFrame164 then ZygorPointerBridgeFrame164:SetScript("OnUpdate",nil) end
ZygorPointerRouteKey195=nil

function ZygorClassic_PointerTitle195()
    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local step=guide and guide.classic_steps and guide.classic_steps[ZygorClassicStepIndex or 1]
    -- TEST230: use the guide's exact |q quest/objective slot and choose the
    -- first unfinished row. Completed objectives (or a stale cross-quest
    -- match such as Prairie Wolf Heart) must not own the arrow label.
    local quests=ZygorClassic_QuestLog172 and ZygorClassic_QuestLog172() or {}
    local i
    for i=1,table.getn((step and step.raw) or {}) do
        local line=ZygorClassic_CleanDirective62 and
                   ZygorClassic_CleanDirective62(step.raw[i]) or step.raw[i]
        local lower=string.lower(tostring(line or ""))
        if string.find(lower,"kill ",1,true)==1 or
           string.find(lower,"get ",1,true)==1 or
           string.find(lower,"goal ",1,true)==1 then
            local owner,qid,objectiveIndex=
                ZygorClassic_ObjectiveOwner178(guide,ZygorClassicStepIndex or 1,line)
            local quest=owner and quests[ZygorClassic_NormalizeQuestTitle170(owner)] or nil
            if quest then
                local text,done=ZygorClassic_ObjectiveStateForQuest229(line,quest,objectiveIndex)
                if text and not done then return text end
            end
        end
    end
    local objectives=step and ZygorClassic_StepObjectiveLines87 and
                     ZygorClassic_StepObjectiveLines87(step) or {}
    for i=1,table.getn(objectives) do
        if objectives[i].text and not objectives[i].done then return objectives[i].text end
    end
    return "Zygor Waypoint"
end

function ZygorClassic_RefreshPointer195()
    ZygorPointerDebug163=ZygorPointerDebug163 or {}
    local p=ZygorGuidesViewer and ZygorGuidesViewer.Pointer
    if not p or not p.ready or not p.ArrowFrame then
        ZygorPointerDebug163.bridge="pointer195 not ready"
        return
    end
    local ownerKey=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
    if ZygorStateMachine172 and ZygorStateMachine172.guideOwnerKey188~=ownerKey then
        ZygorPointerDebug163.bridge="pointer195 waiting for authoritative state"
        return
    end
    local map,x,y=nil,nil,nil
    if ZygorClassic_CurrentGoto55 then map,x,y=ZygorClassic_CurrentGoto55() end
    if not x or not y then
        if ZygorPointerRouteKey195 then pcall(function() p:ClearWaypoints("way") end) end
        ZygorPointerRouteKey195=nil
        ZygorPointerDebug163.bridge="pointer195 no active goto"
        return
    end
    local pointerTitle=ZygorClassic_PointerTitle195()
    local key=tostring(ZygorClassicGuideIndex or 1)..":"..
              tostring(ZygorClassicStepIndex or 1)..":"..
              tostring(map or "")..":"..tostring(x)..":"..tostring(y)..":"..
              tostring(pointerTitle or "")
    local wp=p.ArrowFrame.waypoint
    local actualOK=false
    if wp and wp.x and wp.y then
        actualOK=math.abs(wp.x-(x/100))<0.0001 and math.abs(wp.y-(y/100))<0.0001
    end
    if actualOK then
        -- Objective polling may improve the title several times while the
        -- route coordinates stay identical. Update the existing marker in
        -- place instead of clearing/recreating it and visibly flickering.
        wp.t=pointerTitle
        wp.title=pointerTitle
        ZygorPointerRouteKey195=key
        if p.ArrowFrame.IsShown and not p.ArrowFrame:IsShown() and p.ShowArrow then
            p:ShowArrow(wp)
        end
        ZygorPointerDebug163.bridge="active195 "..key
        return
    end

    local ok,result=pcall(function()
        p:ClearWaypoints("way")
        return p:SetWaypoint(nil,map,x,y,{
            title=pointerTitle,
            type="way",
            onminimap="always",
            overworld=true,
            persistent=true
        })
    end)
    if ok and result then
        ZygorPointerRouteKey195=key
        ZygorPointerDebug163.bridge="connected195 "..key
    elseif ok then
        ZygorPointerDebug163.bridge="pointer195 SetWaypoint nil"
    else
        ZygorPointerDebug163.bridge="pointer195 ERROR "..tostring(result)
    end
end

if not ZygorPointerRouteFrame195 then
    ZygorPointerRouteFrame195=CreateFrame("Frame","ZygorPointerRouteFrame195",UIParent)
    ZygorPointerRouteFrame195.elapsed=0
ZygorPointerRouteFrame195:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.25 then return end
        this.elapsed=0
        ZygorClassic_RefreshPointer195()
end)


-- TEST196: distinguish objectives whose names contain one another.
-- "Night Web Spider" must not inherit the completed state of
-- "Young Night Web Spider" merely because it is a substring.  Score every
-- live leaderboard row and prefer an exact normalized subject match.
ZygorClassic_ObjectiveStateForLine88=function(line)
    local bestTitle,bestText,bestDone=nil,nil,false
    local bestScore=0
    local i
    for i=1,GetNumQuestLogEntries() do
        local title,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(i)
        if title and not isHeader then
            local n=GetNumQuestLeaderBoards and (GetNumQuestLeaderBoards(i) or 0) or 0
            local j
            for j=1,n do
                local text,otype,finished=GetQuestLogLeaderBoard(j,i)
                local score=ZygorClassic_SubjectScore91 and
                            ZygorClassic_SubjectScore91(line,text) or 0
                if score>bestScore then
                    bestScore=score
                    bestTitle=title
                    bestText=text
                    bestDone=(finished==1 or finished==true)
                end
            end
        end
    end
    if bestScore>0 then return bestTitle,bestText,bestDone end
    return nil,nil,false
end

function ZygorClassic_PreviousObjectiveUnfinished196(guide,current)
    local previous=(current or 1)-1
    if previous<1 or not guide or not guide.classic_steps then return nil end
    local step=guide.classic_steps[previous]
    if not step or (ZygorClassic_StepApplies67 and not ZygorClassic_StepApplies67(step)) then return nil end
    -- The diagnostic/objective row can briefly retain a 0/1 value after the
    -- quest itself is complete.  Never let that display-only stale row rewind
    -- a fully resolved guide step (Night Elf Raven Claw -> Druid of the Claw).
    local quests=ZygorClassic_QuestLog172 and ZygorClassic_QuestLog172() or {}
    local resolved=ZygorClassic_StepState172(step,quests,guide,previous)
    if resolved then return nil end
    local objectives=ZygorClassic_StepObjectiveLines87 and
                     ZygorClassic_StepObjectiveLines87(step) or {}
    local i
    for i=1,table.getn(objectives) do
        local lower=string.lower(tostring(objectives[i].line or ""))
        -- Collected quest items are commonly consumed by the following step.
        -- Their later absence must not rewind progression.
        if string.find(lower,"collect ",1,true)~=1 and not objectives[i].done then
            return previous,objectives[i].text or objectives[i].line
        end
    end
    return nil
end


-- TEST197: expose inventory-backed collect steps to diagnostics, rendering,
-- and pointer labels.  A preceding "from" line only names a loot source and
-- must never be paired with an unrelated live quest objective.
ZygorClassic_StepObjectiveLines_Base197=ZygorClassic_StepObjectiveLines87
ZygorClassic_StepObjectiveLines87=function(step)
    local results={}
    local base=ZygorClassic_StepObjectiveLines_Base197 and
               ZygorClassic_StepObjectiveLines_Base197(step) or {}
    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    local stepIndex=ZygorClassicStepIndex or 1
    if guide and guide.classic_steps and guide.classic_steps[stepIndex]~=step then
        local findIndex
        for findIndex=1,table.getn(guide.classic_steps) do
            if guide.classic_steps[findIndex]==step then stepIndex=findIndex break end
        end
    end
    local quests=ZygorClassic_QuestLog172 and ZygorClassic_QuestLog172() or {}
    local seen={}
    local i,j
    for i=1,table.getn((step and step.raw) or {}) do
        local line=ZygorClassic_CleanDirective62 and
                   ZygorClassic_CleanDirective62(step.raw[i]) or step.raw[i]
        local lower=string.lower(tostring(line or ""))
        if string.find(lower,"kill ",1,true)==1 or
           string.find(lower,"get ",1,true)==1 or
           string.find(lower,"goal ",1,true)==1 then
            seen[line]=true
            local owner,qid,objectiveIndex=
                ZygorClassic_ObjectiveOwner178(guide,stepIndex,line)
            local quest=owner and quests[ZygorClassic_NormalizeQuestTitle170(owner)] or nil
            local exactText,exactDone=nil,false
            if quest then
                exactText,exactDone=
                    ZygorClassic_ObjectiveStateForQuest229(line,quest,objectiveIndex)
                -- A quest marked complete by the 1.12 client is stronger
                -- evidence than a stale individual leaderboard row.
                if quest.complete then exactDone=true end
            end
            if exactText then
                table.insert(results,{
                    line=line,
                    title=quest.title,
                    text=exactText,
                    done=exactDone
                })
            else
                for j=1,table.getn(base) do
                    if base[j].line==line then table.insert(results,base[j]) break end
                end
            end
        end
    end
    -- Preserve non-|q legacy objectives, but do not re-add the globally
    -- matched rows that exact slot resolution replaced above.
    for i=1,table.getn(base) do
        local lower=string.lower(tostring(base[i].line or ""))
        if string.find(lower,"from ",1,true)~=1 and not seen[base[i].line] then
            table.insert(results,base[i])
        end
    end
    for i=1,table.getn((step and step.source) or {}) do
        local sourceLine=tostring(step.source[i] or "")
        local startPos,endPos,required,itemName,itemID=
            string.find(sourceLine,"collect%s+(%d+)%s+(.-)##(%d+)")
        if required and itemID then
            itemName=string.gsub(tostring(itemName or "Item"),"^%s+","")
            itemName=string.gsub(itemName,"%s+$","")
            local have=ZygorClassic_ItemCount197(itemID)
            table.insert(results,{
                line="collect "..tostring(required).." "..itemName,
                title=nil,
                text=itemName..": "..tostring(have).."/"..tostring(required),
                done=(have>=tonumber(required))
            })
        end
    end
    return results
end
end

-- TEST200: a quest normally disappears while the player is on its scheduled
-- turn-in step. Missing-inflight recovery is therefore restricted to steps
-- strictly before that turn-in. This prevents chained hand-in rewinds such as
-- 34 -> 32 -> 28 while the player is accepting a follow-up quest.
-- TEST201: an active follow-up quest directly proves its earlier handoff step;
-- recovery no longer depends on a persisted seen-quest cache.
-- TEST202: gate that repair to missing-accept states and track `home` steps via
-- GetBindLocation so hearthstone setup cannot be silently skipped.
if not ZygorClassicHomeWitness203 then
    ZygorClassicHomeWitness203=CreateFrame("Frame","ZygorClassicHomeWitness203",UIParent)
    ZygorClassicHomeWitness203:RegisterEvent("HEARTHSTONE_BOUND")
    ZygorClassicHomeWitness203:SetScript("OnEvent",function()
        local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                    ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
        local step=guide and guide.classic_steps and guide.classic_steps[ZygorClassicStepIndex or 1]
        local target=nil
        local i
        for i=1,table.getn((step and step.raw) or {}) do
            local line=string.lower(tostring(step.raw[i] or ""))
            local s,e,captured=string.find(line,"^home%s+(.+)")
            if captured then target=ZygorClassic_HomeKey203(captured) break end
        end
        if target then
            ZygorClassicDB=ZygorClassicDB or {}
            ZygorClassicDB.homeWitness203=ZygorClassicDB.homeWitness203 or {}
            local charKey=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
            local stepKey=tostring(ZygorClassicGuideIndex or 1)..":"..tostring(ZygorClassicStepIndex or 1)
            ZygorClassicDB.homeWitness203[charKey]=ZygorClassicDB.homeWitness203[charKey] or {}
            ZygorClassicDB.homeWitness203[charKey][stepKey]=target
            if ZygorClassicManualLock194 then ZygorClassicManualLock194[charKey]=nil end
            if ZygorClassicDebug82 then ZygorClassicDebug82.event="HEARTHSTONE_BOUND: "..tostring(target) end
        end
    end)
end

-- TEST203: reliable hearthstone event witness and inherited innkeeper pointer.
-- TEST204: canonical bind aliases (for example Gallows' End Tavern = Brill).
-- TEST205: forward handoff proof must belong to the currently missing quest.
-- TEST206: parse numeric goto x,y,radius triples as coordinates plus radius.
-- TEST207: numbered quest-chain parts with one normalized title require a
-- witnessed turn-in before the replacement part can satisfy the handoff.
-- TEST208: detect those chain IDs from preserved source directives; display
-- directives have already had their ##questID metadata removed.
-- TEST209: a witnessed numbered-chain turn-in remains unresolved until the
-- replacement quest is present in the live quest log.
-- TEST210: an unrelated accepted quest can no longer prove that another quest
-- on the same multi-action step was turned in. Only the actual turn-in witness
-- or the specifically matched numbered-chain replacement may do that.
-- TEST211: guide readiness is based on the exact faction/race title instead of
-- Alliance's 115-guide total, fixing live character switches and Horde starts.
-- TEST212: `ding N` is a first-class level prerequisite in live resolution,
-- saved-state recovery, and cold-start bootstrap; it cannot be mistaken for a
-- travel step and skipped from coordinates or next-step proof.
-- TEST213: manual navigation is accepted only from the visible Step buttons,
-- starts from engine172's authoritative index, skips inapplicable class/race
-- branches, and unlocks on a verified quest-log state change.
-- TEST214: a live follow-up quest restores a partially completed handoff step
-- and records durable proof of the predecessor turn-in. Display this revision
-- in both the window title and diagnostic panel for screenshot verification.
-- TEST215: when Vanilla omits the reward-dialog event sequence, an explicitly
-- scheduled turn-in may be witnessed from prior live ownership, disappearance,
-- a short stability delay, and arrival at that step's waypoint.  This is guide-
-- generic and does not contain quest names or quest IDs.
function ZygorClassic_TurninArrivalWitness215(step,quests,state)
    if not step or not state or not state.inflightSeen191 then return false,nil end
    state.turninArrivalMissing215=state.turninArrivalMissing215 or {}

    local distance=nil
    local pointer=ZygorGuidesViewer and ZygorGuidesViewer.Pointer
    local waypoint=pointer and pointer.ArrowFrame and pointer.ArrowFrame.waypoint
    if waypoint and waypoint.minimapFrame and Astrolabe and Astrolabe.GetDistanceToIcon then
        distance=Astrolabe:GetDistanceToIcon(waypoint.minimapFrame)
    end
    if not distance then
        local map,x,y=ZygorClassic_CurrentGoto55()
        local px,py=GetPlayerMapPosition("player")
        if x and y and px and py and (px>0 or py>0) then
            local dx=x-px*100
            local dy=y-py*100
            local mapDistance=math.sqrt(dx*dx+dy*dy)
            if mapDistance<=0.4 then distance=0 end
        end
    end
    local arrived=distance and distance<=15

    local titles={}
    local seen={}
    local function scan(lines)
        local i
        for i=1,table.getn(lines or {}) do
            local line=ZygorClassic_CleanDirective62 and
                       ZygorClassic_CleanDirective62(lines[i]) or lines[i]
            local title,kind,questID=nil,nil,nil
            if ZygorClassic_ParseQuestDirective then
                title,kind,questID=ZygorClassic_ParseQuestDirective(line)
            end
            if title and kind=="turnin" then
                local key=ZygorClassic_NormalizeQuestTitle170(title)
                if not seen[key] then
                    seen[key]=true
                    table.insert(titles,{title=title,key=key,questID=questID})
                end
            end
        end
    end
    scan(step.source)
    scan(step.raw)

    local now=GetTime and GetTime() or 0
    local i
    for i=1,table.getn(titles) do
        local title=titles[i].title
        local key=titles[i].key
        if quests[key] or (ZygorClassic_TurnedIn62 and ZygorClassic_TurnedIn62(title)) then
            state.turninArrivalMissing215[key]=nil
        elseif not state.inflightSeen191[key] or not arrived then
            state.turninArrivalMissing215[key]=nil
        else
            local since=state.turninArrivalMissing215[key]
            if not since then
                state.turninArrivalMissing215[key]=now
            elseif now-since>=0.75 and ZygorClassic_CommitWitness191(title) then
                if ZygorClassic_RecordQuestIDTurnin216 then
                    ZygorClassic_RecordQuestIDTurnin216(titles[i].questID)
                end
                state.turninArrivalMissing215[key]=nil
                return true,title
            end
        end
    end
    return false,nil
end

-- TEST216: distinguish numbered quest-chain parts by their preserved ##questID.
-- The Vanilla quest log exposes only the shared title, so part (2) disappearing
-- at its turn-in could make recovery rewind to the step that accepted it.  Keep
-- durable exact-ID turn-in evidence, and recover a just-completed handoff from
-- the next few applicable guide steps when the player is at that step's goto.
function ZygorClassic_RecordQuestIDTurnin216(questID)
    questID=tonumber(questID)
    if not questID then return false end
    ZygorClassicDB=ZygorClassicDB or {}
    ZygorClassicDB.questIDTurnins216=ZygorClassicDB.questIDTurnins216 or {}
    local charKey=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
    ZygorClassicDB.questIDTurnins216[charKey]=ZygorClassicDB.questIDTurnins216[charKey] or {}
    ZygorClassicDB.questIDTurnins216[charKey][tostring(questID)]=true
    return true
end

function ZygorClassic_QuestIDTurnedIn216(questID)
    questID=tonumber(questID)
    if not questID then return false end
    local charKey=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
    local all=ZygorClassicDB and ZygorClassicDB.questIDTurnins216
    return all and all[charKey] and all[charKey][tostring(questID)] and true or false
end

function ZygorClassic_GotoForStep216(step)
    local lines=step and (step.raw or step.source) or {}
    local i
    for i=1,table.getn(lines) do
        local line=tostring(lines[i] or "")
        local at=string.find(line,"goto ",1,true)
        if at then
            local rest=string.sub(line,at+5)
            rest=string.gsub(rest,"|.*$","")
            local parts={}
            local start=1
            while true do
                local comma=string.find(rest,",",start,true)
                local part
                if comma then part=string.sub(rest,start,comma-1) else part=string.sub(rest,start) end
                part=string.gsub(part,"^%s+","")
                part=string.gsub(part,"%s+$","")
                table.insert(parts,part)
                if not comma then break end
                start=comma+1
            end
            if table.getn(parts)>=2 and tonumber(parts[1]) and tonumber(parts[2]) then
                return nil,tonumber(parts[1]),tonumber(parts[2]),tonumber(parts[3])
            elseif table.getn(parts)>=3 and tonumber(parts[2]) and tonumber(parts[3]) then
                return parts[1],tonumber(parts[2]),tonumber(parts[3]),tonumber(parts[4])
            end
        end
    end
    return nil,nil,nil
end

function ZygorClassic_ArrivedAtStep216(step)
    local map,x,y,radius=ZygorClassic_GotoForStep216(step)
    if not x or not y then return false end
    if map and map~="" and GetRealZoneText then
        local real=GetRealZoneText() or ""
        if real~="" and string.lower(real)~=string.lower(map) then return false end
    end
    local px,py=GetPlayerMapPosition("player")
    if not px or not py or (px==0 and py==0) then return false end
    local dx=x-px*100
    local dy=y-py*100
    -- Never tighten the tolerance that already proved reliable for Tauren and
    -- other 0.1-radius hearth steps; authored radii may only widen it.
    return math.sqrt(dx*dx+dy*dy)<=math.max(radius or 0,0.45)
end

function ZygorClassic_ForwardTurninRecovery216(guide,quests,state)
    if not guide or not guide.classic_steps or not state then return nil end
    state.forwardTurninMissing216=state.forwardTurninMissing216 or {}
    local current=guide.classic_steps[state.step or 1]
    local accepted={}
    local i
    for i=1,table.getn((current and current.source) or {}) do
        local line=ZygorClassic_CleanDirective62 and
                   ZygorClassic_CleanDirective62(current.source[i]) or current.source[i]
        local title,kind,questID=ZygorClassic_ParseQuestDirective(line)
        if title and kind=="accept" and questID then
            accepted[tonumber(questID)]={title=title,key=ZygorClassic_NormalizeQuestTitle170(title)}
        end
    end
    if not next(accepted) then return nil end

    local now=GetTime and GetTime() or 0
    local checked=0
    local target=ZygorClassic_NextStep172(guide,state.step or 1)
    while target and target>(state.step or 1) and checked<3 do
        local step=guide.classic_steps[target]
        local j
        for j=1,table.getn((step and step.source) or {}) do
            local line=ZygorClassic_CleanDirective62 and
                       ZygorClassic_CleanDirective62(step.source[j]) or step.source[j]
            local title,kind,questID=ZygorClassic_ParseQuestDirective(line)
            questID=tonumber(questID)
            local prior=questID and accepted[questID]
            if prior and kind=="turnin" then
                local timerKey=tostring(questID)
                if quests[prior.key] or ZygorClassic_QuestIDTurnedIn216(questID) or
                   not (state.inflightSeen191 and state.inflightSeen191[prior.key]) or
                   not ZygorClassic_ArrivedAtStep216(step) then
                    state.forwardTurninMissing216[timerKey]=nil
                else
                    local since=state.forwardTurninMissing216[timerKey]
                    if not since then
                        state.forwardTurninMissing216[timerKey]=now
                    elseif now-since>=0.75 then
                        ZygorClassic_RecordQuestIDTurnin216(questID)
                        state.forwardTurninMissing216[timerKey]=nil
                        return target,title,questID
                    end
                end
            end
        end
        checked=checked+1
        local nextTarget=ZygorClassic_NextStep172(guide,target)
        if not nextTarget or nextTarget==target then break end
        target=nextTarget
    end
    return nil
end

ZYGOR_BACKPORT_VERSION = "TEST245"

-- Global by design: this compatibility chunk sits at Vanilla's 200-local
-- ceiling, and the saved wrapper does not need file-local visibility.
ZygorClassic_UpdateDebug82_Base214=ZygorClassic_UpdateDebug82
ZygorClassic_UpdateDebug82=function()
    if ZygorClassic_UpdateDebug82_Base214 then ZygorClassic_UpdateDebug82_Base214() end
    local revision=tostring(ZYGOR_BACKPORT_VERSION or "UNKNOWN")
    if ZygorClassicTitle then
        ZygorClassicTitle:SetText("Zygor Guides Viewer - Classic 1.12 ["..revision.."]")
    end
    if ZygorBuildVersion126 and ZygorBuildVersion126.text then
        ZygorBuildVersion126.text:SetText("Zygor Backport "..revision)
    end
    if ZygorClassicDebugText82 then
        local text=ZygorClassicDebugText82:GetText() or ""
        text=string.gsub(text,"^TEST89 FULL DIAGNOSTICS","BACKPORT REVISION: "..revision.."\nFULL DIAGNOSTICS",1)
        ZygorClassicDebugText82:SetText(text)
    end
end

-- TEST217: ColdStart_Finalizer.lua is a separate Lua chunk, so it cannot call
-- the file-local diagnostic function directly.  Export one closure that owns
-- the final render, pointer and revision-stamped diagnostics refresh.
function ZygorClassic_ColdRefresh217()
    if ZygorClassic_Render then ZygorClassic_Render() end
    if ZygorClassic_UpdateWaypointText then ZygorClassic_UpdateWaypointText() end
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
end


-- TEST246: a separate player-facing guide preview.  Keep the proven 900x700
-- diagnostic workspace intact while UI work continues in an independent,
-- compact frame driven by the same authoritative guide and step indexes.
-- TEST307: authored guide tips are useful navigation, not diagnostic noise.
-- The compact tracker previously stripped them at the first pipe.  NPC hints
-- fill only known vertical/interior gaps that the original guide omitted.
ZygorClassicInteriorHints307=ZygorClassicInteriorHints307 or {
    [3666]="Upstairs inside the Auberdine inn."
}

-- TEST308: optional, dependency-free quest automation provider.  Consumers
-- such as LTP can ask whether a pickup belongs to the active guide without
-- importing Zygor files or changing either addon's standalone behavior.
function ZygorClassic_ShouldAcceptQuest308(title)
    if not title or not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides then return false end
    local guideIndex,stepIndex=ZygorClassicGuideIndex or 1,ZygorClassicStepIndex or 1
    if ZygorClassic_AuthoritativePosition289 then
        guideIndex,stepIndex=ZygorClassic_AuthoritativePosition289()
    end
    local guide=ZygorGuidesViewer.registeredguides[guideIndex]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return false end
    local wanted=ZygorClassic_NormalizeQuestTitle170 and
        ZygorClassic_NormalizeQuestTitle170(title) or string.lower(tostring(title))
    local steps=guide.classic_steps or {}
    local last=math.min(table.getn(steps),stepIndex+20)
    local index,lineIndex
    for index=stepIndex,last do
        local step=steps[index]
        local lines=ZygorClassic_FilterLines62 and ZygorClassic_FilterLines62(step) or step.raw or {}
        for lineIndex=1,table.getn(lines) do
            local questTitle,kind=nil,nil
            if ZygorClassic_ParseQuestDirective then
                questTitle,kind=ZygorClassic_ParseQuestDirective(lines[lineIndex])
            end
            if questTitle and kind=="accept" then
                local normalized=ZygorClassic_NormalizeQuestTitle170 and
                    ZygorClassic_NormalizeQuestTitle170(questTitle) or string.lower(tostring(questTitle))
                if normalized==wanted then return true end
            end
        end
    end
    return false
end

-- TEST309: identify a same-title, different-ID quest handoff on one guide
-- step.  The 1.12 quest log supplies only the shared display title, so the
-- exact turn-in witness is the only safe proof that the replacement part can
-- be considered accepted.
function ZygorClassic_DirectiveIDForStep309(step,wantedTitle,wantedKind)
    if not step or not wantedTitle or not wantedKind then return nil end
    local wanted=ZygorClassic_NormalizeQuestTitle170(wantedTitle)
    local lines=step.source or {}
    local i
    for i=1,table.getn(lines) do
        local line=ZygorClassic_CleanDirective62 and
                   ZygorClassic_CleanDirective62(lines[i]) or lines[i]
        local title,kind,questID=ZygorClassic_ParseQuestDirective(line)
        if title and kind==wantedKind and
           ZygorClassic_NormalizeQuestTitle170(title)==wanted then
            return tonumber(questID)
        end
    end
    return nil
end

function ZygorClassic_ChainBarrier309(step,acceptTitle,acceptID)
    acceptID=tonumber(acceptID)
    if not step or not acceptTitle or not acceptID then return false,nil end
    local wanted=ZygorClassic_NormalizeQuestTitle170(acceptTitle)
    local lines=step.source or step.raw or {}
    local i
    for i=1,table.getn(lines) do
        local line=ZygorClassic_CleanDirective62 and
                   ZygorClassic_CleanDirective62(lines[i]) or lines[i]
        local title,kind,questID=ZygorClassic_ParseQuestDirective(line)
        questID=tonumber(questID)
        if title and kind=="turnin" and questID and questID~=acceptID and
           ZygorClassic_NormalizeQuestTitle170(title)==wanted then
            local resolved=ZygorClassic_QuestIDTurnedIn216 and
                           ZygorClassic_QuestIDTurnedIn216(questID)
            return not resolved,questID
        end
    end
    return false,nil
end

function ZygorClassic_PlayerAction246(line,step,quests)
    local raw=tostring(line or "")
    local _,_,authoredTip=string.find(raw,"|tip%s*([^|]+)")
    local _,_,npcIdText=string.find(raw,"##(%d+)")
    local clean=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(line) or raw
    clean=string.gsub(tostring(clean or ""),"|.*$","")
    clean=string.gsub(clean,"^%s+","")
    clean=string.gsub(clean,"%s+$","")
    if clean=="" then return nil,"info" end

    local lower=string.lower(clean)
    local display=ZygorClassic_PresentLine241 and ZygorClassic_PresentLine241(clean) or clean
    local state="pending"
    local title,kind,directiveID=nil,nil,nil
    if ZygorClassic_ParseQuestDirective then title,kind,directiveID=ZygorClassic_ParseQuestDirective(clean) end
    if title and kind then
        if not directiveID and ZygorClassic_DirectiveIDForStep309 then
            directiveID=ZygorClassic_DirectiveIDForStep309(step,title,kind)
        end
        local questKey=ZygorClassic_NormalizeQuestTitle170 and
                       ZygorClassic_NormalizeQuestTitle170(title) or string.lower(title)
        local chainBlocked=kind=="accept" and ZygorClassic_ChainBarrier309 and
                           ZygorClassic_ChainBarrier309(step,title,directiveID)
        if kind=="accept" and quests and quests[questKey] and not chainBlocked then
            state="done"
        elseif kind=="turnin" then
            -- TEST311: an exact completed part remains done even while the
            -- next same-title chain part is live in the Vanilla quest log.
            if directiveID and ZygorClassic_QuestIDTurnedIn216 and
               ZygorClassic_QuestIDTurnedIn216(directiveID) then
                state="done"
            elseif not (quests and quests[questKey]) and not directiveID and
                   ZygorClassic_TurnedIn62 and
                   ZygorClassic_TurnedIn62(title) then
                state="done"
            end
        end
    end

    local startPos,endPos,value=string.find(clean,"^goto%s+(.+)$")
    if value then
        display="Go to "..string.gsub(value,",",", ")
        if ZygorClassic_ArrivedAtStep216 and ZygorClassic_ArrivedAtStep216(step) then state="done" end
    else
        startPos,endPos,value=string.find(clean,"^from%s+(.+)$")
        if value then
            display="Kill nearby: "..value
            state="info"
        else
            startPos,endPos,value=string.find(clean,"^get%s+(.+)$")
            if value then display="Collect "..value end
            startPos,endPos,value=string.find(clean,"^kill%s+(.+)$")
            if value then display="Kill "..value end
            startPos,endPos,value=string.find(clean,"^use%s+(.+)$")
            if value then display="Use "..value end
            startPos,endPos,value=string.find(clean,"^ding%s+(%d+)$")
            if value then
                display="Reach level "..value
                if (UnitLevel("player") or 1)>=tonumber(value) then state="done" end
            end
        end
    end

    if string.sub(lower,1,5)=="kill " or string.sub(lower,1,4)=="get " or
       string.sub(lower,1,5)=="goal " then
        local objectiveTitle,objectiveText,objectiveDone=nil,nil,false
        if ZygorClassic_ObjectiveStateForLine88 then
            objectiveTitle,objectiveText,objectiveDone=ZygorClassic_ObjectiveStateForLine88(clean)
        end
        if objectiveText and objectiveText~="" then
            if string.sub(lower,1,5)=="kill " then
                display="Kill: "..objectiveText
            else
                display="Collect: "..objectiveText
            end
        end
        if objectiveDone then state="done" end
    end
    -- Once all accepts on this step are proven, their prerequisite prose,
    -- collect, and use rows are historical facts even if a consumed item is
    -- no longer present. Keep explanatory `from` rows informational.
    if state~="info" and ZygorClassic_SameStepAcceptProof338 and
       ZygorClassic_SameStepAcceptProof338(step,quests) then
        state="done"
    end
    local interiorHint=npcIdText and ZygorClassicInteriorHints307[tonumber(npcIdText)] or nil
    if authoredTip and authoredTip~="" then
        display=display.." - "..authoredTip
    elseif interiorHint and string.find(lower,"^talk%s") then
        display=display.." - "..interiorHint
    end
    return display,state
end

function ZygorClassic_PlayerRender246()
    if not ZygorClassicPlayerFrame246 or not ZygorGuidesViewer or
       not ZygorGuidesViewer.registeredguides then return end
    local guideIndex,stepIndex=ZygorClassicGuideIndex or 1,ZygorClassicStepIndex or 1
    if ZygorClassic_AuthoritativePosition289 then
        guideIndex,stepIndex=ZygorClassic_AuthoritativePosition289()
    end
    local guide=ZygorGuidesViewer.registeredguides[guideIndex]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return end
    local steps=guide.classic_steps or {}
    local stepCount=table.getn(steps)
    if stepIndex<1 then stepIndex=1 end
    if stepCount>0 and stepIndex>stepCount then stepIndex=stepCount end
    local step=steps[stepIndex]
    if not step then return end

    local title=tostring(guide.title or "Guide")
    local shortTitle=title
    local scan=1
    local slash=nil
    while true do
        local found=string.find(title,"\\",scan,true)
        if not found then break end
        slash=found
        scan=found+1
    end
    if slash then shortTitle=string.sub(title,slash+1) end

    local quests=ZygorClassic_QuestLog172 and ZygorClassic_QuestLog172() or {}
    local lines=ZygorClassic_FilterLines62 and ZygorClassic_FilterLines62(step) or step.raw or {}
    local actionText=""
    local actionCount=0
    local modernRows={}
    local activeChosen=false
    local i
    for i=1,table.getn(lines) do
        local display,state=ZygorClassic_PlayerAction246(lines[i],step,quests)
        if display and display~="" then
            actionCount=actionCount+1
            if state=="done" then
                actionText=actionText.."|cff55dd55[done]|r |cffb7e8b7"..display.."|r\n"
                table.insert(modernRows,{text=display,state="done"})
            elseif state=="info" then
                actionText=actionText.."|cff888888   -|r |cffbbbbbb"..display.."|r\n"
                table.insert(modernRows,{text=display,state="info"})
            elseif not activeChosen then
                actionText=actionText.."|cffffcc00   >|r |cffffffff"..display.."|r\n"
                table.insert(modernRows,{text=display,state="active"})
                activeChosen=true
            else
                actionText=actionText.."|cff777777   o|r |cffdddddd"..display.."|r\n"
                table.insert(modernRows,{text=display,state="pending"})
            end
        end
    end
    if actionCount==0 then
        actionText="|cffaaaaaaNo player-facing actions on this step.|r"
        table.insert(modernRows,{text="No player-facing actions on this step.",state="info"})
    end

    if ZygorClassicPlayerTitle246 then
        ZygorClassicPlayerTitle246:SetText("Zygor Guides  |cffaaaaaa["..tostring(ZYGOR_BACKPORT_VERSION or "TEST").."]|r")
    end
    if ZygorClassicPlayerGuide246 then ZygorClassicPlayerGuide246:SetText(shortTitle) end
    if ZygorClassicPlayerMeta246 then
        local guideMode=ZygorClassic_GuideMode248 and ZygorClassic_GuideMode248() or "AUTO"
        local modeColor=guideMode=="MANUAL" and "|cffffcc00" or "|cff55dd55"
        ZygorClassicPlayerMeta246:SetText(
            "Step |cffffcc00"..tostring(stepIndex).."|r of "..tostring(stepCount)..
            "   |cff888888/|r   "..tostring(UnitRace("player") or "?").." "..
            tostring(UnitClass("player") or "?").."   Level "..tostring(UnitLevel("player") or "?")..
            "   "..modeColor..guideMode.."|r"
        )
    end
    if ZygorClassicPlayerActions246 then ZygorClassicPlayerActions246:SetText(actionText) end
    if ZygorClassicPlayerProgress246 then
        ZygorClassicPlayerProgress246:SetMinMaxValues(0,stepCount>0 and stepCount or 1)
        ZygorClassicPlayerProgress246:SetValue(stepIndex)
    end
    if ZygorClassicPlayerProgressText246 then
        local percent=stepCount>0 and math.floor((stepIndex/stepCount)*100) or 0
        ZygorClassicPlayerProgressText246:SetText(tostring(percent).."%")
    end
    if ZygorClassic_RenderModern291 then
        ZygorClassic_RenderModern291(modernRows,stepIndex,stepCount,shortTitle)
    end
end

function ZygorClassic_ToggleDiagnostics246()
    if not ZygorGuidesViewerFrame then return end
    if ZygorGuidesViewerFrame:IsShown() then
        ZygorGuidesViewerFrame:Hide()
    else
        ZygorGuidesViewerFrame:Show()
        if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
    end
end

function ZygorClassic_TogglePlayer246()
    if not ZygorClassicPlayerFrame246 then return end
    if ZygorClassicPlayerFrame246:IsShown() then
        ZygorClassicPlayerFrame246:Hide()
    else
        ZygorClassic_PlayerRender246()
        ZygorClassicPlayerFrame246:Show()
    end
end

if not ZygorClassicPlayerFrame246 then
    ZygorClassicPlayerFrame246=CreateFrame("Frame","ZygorClassicPlayerFrame246",UIParent)
    ZygorClassicPlayerFrame246:SetWidth(470)
    ZygorClassicPlayerFrame246:SetHeight(340)
    ZygorClassicPlayerFrame246:SetPoint("TOPLEFT",UIParent,"TOPLEFT",24,-170)
    ZygorClassicPlayerFrame246:SetFrameStrata("HIGH")
    ZygorClassicPlayerFrame246:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true,tileSize=16,edgeSize=16,
        insets={left=5,right=5,top=5,bottom=5}
    })
    ZygorClassicPlayerFrame246:SetBackdropColor(0.025,0.025,0.025,0.96)
    ZygorClassicPlayerFrame246:SetBackdropBorderColor(0.55,0.42,0.12,1)
    ZygorClassicPlayerFrame246:SetMovable(true)
    ZygorClassicPlayerFrame246:EnableMouse(true)
    ZygorClassicPlayerFrame246:RegisterForDrag("LeftButton")
    ZygorClassicPlayerFrame246:SetScript("OnDragStart",function() this:StartMoving() end)
    ZygorClassicPlayerFrame246:SetScript("OnDragStop",function() this:StopMovingOrSizing() end)

    ZygorClassicPlayerLogo246=ZygorClassicPlayerFrame246:CreateTexture("ZygorClassicPlayerLogo246","ARTWORK")
    -- arrow-here.tga is a bottom-origin, 32-bit texture already proven by the
    -- live Vanilla pointer.  The newer top-origin logo sprites render as solid
    -- white blocks on this client.
    ZygorClassicPlayerLogo246:SetTexture("Interface\\AddOns\\ZygorGuidesViewer\\Skin\\arrow-here")
    ZygorClassicPlayerLogo246:SetTexCoord(0,1,0,1)
    ZygorClassicPlayerLogo246:SetWidth(38)
    ZygorClassicPlayerLogo246:SetHeight(38)
    ZygorClassicPlayerLogo246:SetPoint("TOPLEFT",ZygorClassicPlayerFrame246,"TOPLEFT",12,-10)

    ZygorClassicPlayerTitle246=ZygorClassicPlayerFrame246:CreateFontString("ZygorClassicPlayerTitle246","OVERLAY","GameFontNormal")
    ZygorClassicPlayerTitle246:SetPoint("TOPLEFT",ZygorClassicPlayerFrame246,"TOPLEFT",56,-12)
    ZygorClassicPlayerTitle246:SetFont("Fonts\\FRIZQT__.TTF",15)
    ZygorClassicPlayerTitle246:SetTextColor(1,0.82,0.18)

    ZygorClassicPlayerGuide246=ZygorClassicPlayerFrame246:CreateFontString("ZygorClassicPlayerGuide246","OVERLAY","GameFontHighlightSmall")
    ZygorClassicPlayerGuide246:SetPoint("TOPLEFT",ZygorClassicPlayerFrame246,"TOPLEFT",56,-31)
    ZygorClassicPlayerGuide246:SetWidth(370)
    ZygorClassicPlayerGuide246:SetJustifyH("LEFT")
    ZygorClassicPlayerGuide246:SetTextColor(0.78,0.78,0.78)

    ZygorClassicPlayerClose246=CreateFrame("Button","ZygorClassicPlayerClose246",ZygorClassicPlayerFrame246,"UIPanelCloseButton")
    ZygorClassicPlayerClose246:SetPoint("TOPRIGHT",ZygorClassicPlayerFrame246,"TOPRIGHT",-3,-3)
    ZygorClassicPlayerClose246:SetScript("OnClick",function() ZygorClassicPlayerFrame246:Hide() end)

    ZygorClassicPlayerMeta246=ZygorClassicPlayerFrame246:CreateFontString("ZygorClassicPlayerMeta246","OVERLAY","GameFontHighlightSmall")
    ZygorClassicPlayerMeta246:SetPoint("TOPLEFT",ZygorClassicPlayerFrame246,"TOPLEFT",16,-61)
    ZygorClassicPlayerMeta246:SetWidth(438)
    ZygorClassicPlayerMeta246:SetJustifyH("LEFT")
    ZygorClassicPlayerMeta246:SetTextColor(0.82,0.82,0.82)

    ZygorClassicPlayerRule246=ZygorClassicPlayerFrame246:CreateTexture("ZygorClassicPlayerRule246","ARTWORK")
    ZygorClassicPlayerRule246:SetTexture("Interface\\AddOns\\ZygorGuidesViewer\\Skin\\white")
    ZygorClassicPlayerRule246:SetVertexColor(0.58,0.42,0.10,0.65)
    ZygorClassicPlayerRule246:SetHeight(1)
    ZygorClassicPlayerRule246:SetPoint("TOPLEFT",ZygorClassicPlayerFrame246,"TOPLEFT",14,-82)
    ZygorClassicPlayerRule246:SetPoint("TOPRIGHT",ZygorClassicPlayerFrame246,"TOPRIGHT",-14,-82)

    ZygorClassicPlayerCurrent246=ZygorClassicPlayerFrame246:CreateFontString("ZygorClassicPlayerCurrent246","OVERLAY","GameFontNormalSmall")
    ZygorClassicPlayerCurrent246:SetPoint("TOPLEFT",ZygorClassicPlayerFrame246,"TOPLEFT",16,-94)
    ZygorClassicPlayerCurrent246:SetText("CURRENT STEP")
    ZygorClassicPlayerCurrent246:SetTextColor(1,0.75,0.10)

    ZygorClassicPlayerActions246=ZygorClassicPlayerFrame246:CreateFontString("ZygorClassicPlayerActions246","OVERLAY","GameFontHighlightSmall")
    ZygorClassicPlayerActions246:SetPoint("TOPLEFT",ZygorClassicPlayerFrame246,"TOPLEFT",16,-116)
    ZygorClassicPlayerActions246:SetWidth(438)
    ZygorClassicPlayerActions246:SetHeight(154)
    ZygorClassicPlayerActions246:SetJustifyH("LEFT")
    ZygorClassicPlayerActions246:SetJustifyV("TOP")
    ZygorClassicPlayerActions246:SetFont("Fonts\\FRIZQT__.TTF",13)

    ZygorClassicPlayerProgress246=CreateFrame("StatusBar","ZygorClassicPlayerProgress246",ZygorClassicPlayerFrame246)
    ZygorClassicPlayerProgress246:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    -- TEST312: use a calm completion-green fill instead of the old gold bar.
    ZygorClassicPlayerProgress246:SetStatusBarColor(0.18,0.68,0.34)
    ZygorClassicPlayerProgress246:SetWidth(438)
    ZygorClassicPlayerProgress246:SetHeight(9)
    ZygorClassicPlayerProgress246:SetPoint("BOTTOMLEFT",ZygorClassicPlayerFrame246,"BOTTOMLEFT",16,55)
    ZygorClassicPlayerProgress246:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true,tileSize=8,edgeSize=8,
        insets={left=2,right=2,top=2,bottom=2}
    })
    ZygorClassicPlayerProgress246:SetBackdropColor(0.05,0.05,0.05,0.9)

    ZygorClassicPlayerProgressText246=ZygorClassicPlayerProgress246:CreateFontString("ZygorClassicPlayerProgressText246","OVERLAY","GameFontHighlightSmall")
    ZygorClassicPlayerProgressText246:SetPoint("CENTER",ZygorClassicPlayerProgress246,"CENTER",0,0)
    ZygorClassicPlayerProgressText246:SetFont("Fonts\\FRIZQT__.TTF",9)

    ZygorClassicPlayerPrev246=CreateFrame("Button","ZygorClassicPlayerPrev246",ZygorClassicPlayerFrame246,"UIPanelButtonTemplate")
    ZygorClassicPlayerPrev246:SetWidth(72)
    ZygorClassicPlayerPrev246:SetHeight(22)
    ZygorClassicPlayerPrev246:SetPoint("BOTTOMLEFT",ZygorClassicPlayerFrame246,"BOTTOMLEFT",14,18)
    ZygorClassicPlayerPrev246:SetText("< Step")
    ZygorClassicPlayerPrev246:SetScript("OnClick",function() ZygorClassic_NextStep(-1,true) end)

    ZygorClassicPlayerNext246=CreateFrame("Button","ZygorClassicPlayerNext246",ZygorClassicPlayerFrame246,"UIPanelButtonTemplate")
    ZygorClassicPlayerNext246:SetWidth(72)
    ZygorClassicPlayerNext246:SetHeight(22)
    ZygorClassicPlayerNext246:SetPoint("LEFT",ZygorClassicPlayerPrev246,"RIGHT",6,0)
    ZygorClassicPlayerNext246:SetText("Step >")
    ZygorClassicPlayerNext246:SetScript("OnClick",function() ZygorClassic_NextStep(1,true) end)

    ZygorClassicPlayerDebug246=CreateFrame("Button","ZygorClassicPlayerDebug246",ZygorClassicPlayerFrame246,"UIPanelButtonTemplate")
    ZygorClassicPlayerDebug246:SetWidth(96)
    ZygorClassicPlayerDebug246:SetHeight(22)
    ZygorClassicPlayerDebug246:SetPoint("BOTTOMRIGHT",ZygorClassicPlayerFrame246,"BOTTOMRIGHT",-14,18)
    ZygorClassicPlayerDebug246:SetText("Diagnostics")
    ZygorClassicPlayerDebug246:SetScript("OnClick",ZygorClassic_ToggleDiagnostics246)

    ZygorClassicPlayerFrame246.elapsed=0
    ZygorClassicPlayerFrame246:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.50 then return end
        this.elapsed=0
        ZygorClassic_PlayerRender246()
    end)
    ZygorClassicPlayerFrame246:Show()
end

if ZygorGuidesViewerFrame and not ZygorClassicPlayerToggle246 then
    ZygorClassicPlayerToggle246=CreateFrame("Button","ZygorClassicPlayerToggle246",ZygorGuidesViewerFrame,"UIPanelButtonTemplate")
    ZygorClassicPlayerToggle246:SetWidth(96)
    ZygorClassicPlayerToggle246:SetHeight(24)
    if ZygorClassicReload72 then
        ZygorClassicPlayerToggle246:SetPoint("RIGHT",ZygorClassicReload72,"LEFT",-10,0)
    else
        ZygorClassicPlayerToggle246:SetPoint("BOTTOMRIGHT",ZygorGuidesViewerFrame,"BOTTOMRIGHT",-140,18)
    end
    ZygorClassicPlayerToggle246:SetText("Player UI")
    ZygorClassicPlayerToggle246:SetScript("OnClick",ZygorClassic_TogglePlayer246)
end

ZYGOR_BACKPORT_VERSION = "TEST246"


-- TEST247: hybrid guide selection.  Automatic race/level selection remains the
-- default, but the player can deliberately choose any same-faction Vanilla
-- leveling route.  A manual choice is written into authoritative engine172
-- state so the next poll cannot replace it with the recommendation.
function ZygorClassic_GuideChoices247()
    local choices={}
    local faction=ZygorClassic_Faction262() or ""
    local factionText=faction=="Alliance" and "Alliance Leveling Guides" or "Horde Leveling Guides"
    local guides=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides or {}
    local i
    for i=1,table.getn(guides) do
        local title=tostring(guides[i] and guides[i].title or "")
        local invalid=string.find(title,"Blood Elf",1,true) or
                      string.find(title,"Draenei",1,true) or
                      string.find(title,"Death Knight",1,true) or
                      string.find(title,"Outland",1,true) or
                      string.find(title,"Northrend",1,true)
        local startPos,endPos,low,high=string.find(title,"%((%d+)%-(%d+)%)")
        low=tonumber(low)
        high=tonumber(high)
        if string.find(title,factionText,1,true) and not invalid and low and high and high<=60 then
            table.insert(choices,{index=i,title=title,low=low,high=high})
        end
    end
    return choices
end

function ZygorClassic_ShortGuideTitle247(title)
    title=tostring(title or "Guide")
    local scan=1
    local slash=nil
    while true do
        local found=string.find(title,"\\",scan,true)
        if not found then break end
        slash=found
        scan=found+1
    end
    if slash then return string.sub(title,slash+1) end
    return title
end

function ZygorClassic_LevelStart247(guide,level)
    if not guide or not ZygorClassic_EnsureParsed(guide) then return 1 end
    local steps=guide.classic_steps or {}
    local target=1
    local i,j
    for i=1,table.getn(steps) do
        for j=1,table.getn(steps[i].raw or {}) do
            local line=ZygorClassic_CleanDirective62 and ZygorClassic_CleanDirective62(steps[i].raw[j]) or steps[i].raw[j]
            local startPos,endPos,wanted=string.find(tostring(line or ""),"^ding%s+(%d+)")
            wanted=tonumber(wanted)
            if wanted and wanted<=level then target=i+1 end
        end
    end
    if target>table.getn(steps) then target=table.getn(steps) end
    while target<table.getn(steps) and ZygorClassic_StepApplies67 and
          not ZygorClassic_StepApplies67(steps[target]) do
        target=target+1
    end
    if target<1 then target=1 end
    return target
end

function ZygorClassic_SelectGuide247(guideIndex,automatic)
    local guides=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides
    local guide=guides and guides[guideIndex]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return end
    -- TEST249: selecting the current row means "keep this route manually";
    -- never recalculate its level start and disturb the exact current step.
    if not automatic and guideIndex==(ZygorClassicGuideIndex or 1) and
       ZygorClassic_LockCurrentGuide249 then
        ZygorClassic_LockCurrentGuide249()
        return
    end
    local target=ZygorClassic_LevelStart247(guide,UnitLevel("player") or 1)
    ZygorClassicDB=ZygorClassicDB or {}
    ZygorClassicDB.engine172=ZygorClassicDB.engine172 or {}
    ZygorClassicDB.manualGuide247=ZygorClassicDB.manualGuide247 or {}
    local key=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
    local state=ZygorClassicDB.engine172[key] or {}
    state.guide=guideIndex
    state.step=target
    state.recoveryFloor218=target
    state.missingSince191={}
    ZygorClassicDB.engine172[key]=state
    if automatic then
        ZygorClassicDB.manualGuide247[key]=nil
    else
        ZygorClassicDB.manualGuide247[key]=guideIndex
    end
    ZygorClassicGuideIndex=guideIndex
    ZygorClassicStepIndex=target
    ZygorClassicManualLock194=ZygorClassicManualLock194 or {}
    ZygorClassicManualLock194[key]=GetTime and GetTime() or 0
    if ZygorClassicDebug82 then
        if automatic then
            ZygorClassicDebug82.route="recommended guide -> G"..tostring(guideIndex).." S"..tostring(target)
            ZygorClassicDebug82.event="AUTO RECOMMENDED GUIDE: "..ZygorClassic_ShortGuideTitle247(guide.title)
        else
            ZygorClassicDebug82.route="manual guide picker -> G"..tostring(guideIndex).." S"..tostring(target)
            ZygorClassicDebug82.event="PLAYER SELECTED GUIDE: "..ZygorClassic_ShortGuideTitle247(guide.title)
        end
    end
    if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
    if ZygorClassic_SaveProgress then ZygorClassic_SaveProgress() end
    if ZygorClassic_Render then ZygorClassic_Render() end
    if ZygorClassic_UpdateWaypointText then ZygorClassic_UpdateWaypointText() end
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
    if ZygorClassicGuidePicker247 then ZygorClassicGuidePicker247:Hide() end
    ZygorClassic_PlayerRender246()
end

function ZygorClassic_RenderGuidePicker247()
    if not ZygorClassicGuidePicker247 or not ZygorClassicGuideRows247 then return end
    local choices=ZygorClassic_GuideChoices247()
    local perPage=8
    local pages=math.ceil(table.getn(choices)/perPage)
    if pages<1 then pages=1 end
    ZygorClassicGuidePage247=ZygorClassicGuidePage247 or 1
    if ZygorClassicGuidePage247<1 then ZygorClassicGuidePage247=pages end
    if ZygorClassicGuidePage247>pages then ZygorClassicGuidePage247=1 end
    local level=UnitLevel("player") or 1
    local row
    for row=1,perPage do
        local choice=choices[(ZygorClassicGuidePage247-1)*perPage+row]
        local button=ZygorClassicGuideRows247[row]
        if choice then
            local prefix=""
            if choice.index==(ZygorClassicGuideIndex or 1) then
                prefix="|cffffcc00CURRENT|r  "
            elseif level>=choice.low and level<=choice.high then
                prefix="|cff55dd55LEVEL MATCH|r  "
            end
            button.guideIndex=choice.index
            button:SetText(prefix..ZygorClassic_ShortGuideTitle247(choice.title))
            button:Show()
        else
            button.guideIndex=nil
            button:Hide()
        end
    end
    if ZygorClassicGuidePickerPage247 then
        ZygorClassicGuidePickerPage247:SetText("Page "..tostring(ZygorClassicGuidePage247).." / "..tostring(pages))
    end
    if ZygorClassicGuidePickerHint247 then
        ZygorClassicGuidePickerHint247:SetText(
            "Same-faction Vanilla leveling guides. Level-matched routes are marked in green. "..
            "Selecting a route starts near your current level."
        )
    end
end

function ZygorClassic_ChangeGuidePage247(delta)
    ZygorClassicGuidePage247=(ZygorClassicGuidePage247 or 1)+(delta or 0)
    ZygorClassic_RenderGuidePicker247()
end

function ZygorClassic_ToggleGuidePicker247()
    if not ZygorClassicGuidePicker247 then return end
    if ZygorClassicGuidePicker247:IsShown() then
        ZygorClassicGuidePicker247:Hide()
    else
        ZygorClassic_RenderGuidePicker247()
        ZygorClassicGuidePicker247:Show()
    end
end

function ZygorClassic_CreateGuidePicker247()
    if ZygorClassicGuidePicker247 then return end
    local frame=CreateFrame("Frame","ZygorClassicGuidePicker247",UIParent)
    frame:SetWidth(430)
    frame:SetHeight(390)
    frame:SetPoint("TOPLEFT",ZygorClassicPlayerFrame246,"TOPRIGHT",10,0)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true,tileSize=16,edgeSize=16,
        insets={left=5,right=5,top=5,bottom=5}
    })
    frame:SetBackdropColor(0.025,0.025,0.025,0.98)
    frame:SetBackdropBorderColor(0.55,0.42,0.12,1)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",function() this:StartMoving() end)
    frame:SetScript("OnDragStop",function() this:StopMovingOrSizing() end)

    local title=frame:CreateFontString("ZygorClassicGuidePickerTitle247","OVERLAY","GameFontNormal")
    title:SetPoint("TOPLEFT",frame,"TOPLEFT",16,-14)
    title:SetText("Choose a Leveling Guide")
    title:SetTextColor(1,0.82,0.18)
    local close=CreateFrame("Button","ZygorClassicGuidePickerClose247",frame,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-3,-3)
    close:SetScript("OnClick",function() ZygorClassicGuidePicker247:Hide() end)
    ZygorClassicGuidePickerHint247=frame:CreateFontString("ZygorClassicGuidePickerHint247","OVERLAY","GameFontHighlightSmall")
    ZygorClassicGuidePickerHint247:SetPoint("TOPLEFT",frame,"TOPLEFT",16,-42)
    ZygorClassicGuidePickerHint247:SetWidth(398)
    ZygorClassicGuidePickerHint247:SetJustifyH("LEFT")
    ZygorClassicGuidePickerHint247:SetTextColor(0.72,0.72,0.72)

    ZygorClassicGuideRows247={}
    local row
    for row=1,8 do
        local button=CreateFrame("Button","ZygorClassicGuideRow247_"..tostring(row),frame,"UIPanelButtonTemplate")
        button:SetWidth(398)
        button:SetHeight(27)
        button:SetPoint("TOPLEFT",frame,"TOPLEFT",16,-88-(row-1)*31)
        button:SetScript("OnClick",function()
            if this.guideIndex then ZygorClassic_SelectGuide247(this.guideIndex) end
        end)
        if button.GetFontString then
            local fontString=button:GetFontString()
            if fontString then fontString:SetJustifyH("LEFT") end
        end
        ZygorClassicGuideRows247[row]=button
    end

    local previous=CreateFrame("Button","ZygorClassicGuidePickerPrev247",frame,"UIPanelButtonTemplate")
    previous:SetWidth(70)
    previous:SetHeight(22)
    previous:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",16,16)
    previous:SetText("< Page")
    previous:SetScript("OnClick",function() ZygorClassic_ChangeGuidePage247(-1) end)
    local nextButton=CreateFrame("Button","ZygorClassicGuidePickerNext247",frame,"UIPanelButtonTemplate")
    nextButton:SetWidth(70)
    nextButton:SetHeight(22)
    nextButton:SetPoint("LEFT",previous,"RIGHT",8,0)
    nextButton:SetText("Page >")
    nextButton:SetScript("OnClick",function() ZygorClassic_ChangeGuidePage247(1) end)
    ZygorClassicGuidePickerPage247=frame:CreateFontString("ZygorClassicGuidePickerPage247","OVERLAY","GameFontHighlightSmall")
    ZygorClassicGuidePickerPage247:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-18,21)
    frame:Hide()
end

ZygorClassic_CreateGuidePicker247()

if ZygorClassicPlayerFrame246 and not ZygorClassicChooseGuide247 then
    ZygorClassicChooseGuide247=CreateFrame("Button","ZygorClassicChooseGuide247",ZygorClassicPlayerFrame246,"UIPanelButtonTemplate")
    ZygorClassicChooseGuide247:SetWidth(104)
    ZygorClassicChooseGuide247:SetHeight(22)
    ZygorClassicChooseGuide247:SetPoint("LEFT",ZygorClassicPlayerNext246,"RIGHT",8,0)
    ZygorClassicChooseGuide247:SetText("Choose Guide")
    ZygorClassicChooseGuide247:SetScript("OnClick",ZygorClassic_ToggleGuidePicker247)
end

ZYGOR_BACKPORT_VERSION = "TEST247"


-- TEST248: complete the hybrid guide mode. AUTO recommends by faction, race
-- and level, and may change guides at a level boundary. Any explicit guide
-- choice switches to MANUAL and blocks those automatic changes until the
-- player presses Use Recommended.
function ZygorClassic_GuideMode248()
    ZygorClassicDB=ZygorClassicDB or {}
    ZygorClassicDB.manualGuide247=ZygorClassicDB.manualGuide247 or {}
    local key=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
    if ZygorClassicDB.manualGuide247[key] then return "MANUAL" end
    return "AUTO"
end

function ZygorClassic_RecommendedGuide248()
    local choices=ZygorClassic_GuideChoices247 and ZygorClassic_GuideChoices247() or {}
    local level=UnitLevel("player") or 1
    local race=UnitRace("player") or ""
    local bestIndex=nil
    local bestScore=nil
    local i
    for i=1,table.getn(choices) do
        local choice=choices[i]
        local score=0
        if level>=choice.low and level<=choice.high then
            score=1000-(choice.high-choice.low)
            -- At exact bracket boundaries, prefer the guide beginning at this
            -- level (13-20, 20-25, etc.) over the guide that just ended.
            if choice.low==level and choice.low>1 then score=score+600 end
            -- Before the first handoff, recommend the character's own starting
            -- route. Other same-faction starting zones remain manual options.
            if level<13 and string.find(choice.title,"\\"..race.." (",1,true) then
                score=score+800
            end
        else
            local distance=choice.low-level
            if level>choice.high then distance=level-choice.high end
            score=100-math.abs(distance)
        end
        if not bestScore or score>bestScore then
            bestScore=score
            bestIndex=choice.index
        end
    end
    return bestIndex
end

function ZygorClassic_UseRecommended248()
    ZygorClassicDB=ZygorClassicDB or {}
    ZygorClassicDB.manualGuide247=ZygorClassicDB.manualGuide247 or {}
    local key=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
    ZygorClassicDB.manualGuide247[key]=nil
    local recommended=ZygorClassic_RecommendedGuide248()
    if recommended and recommended~=(ZygorClassicGuideIndex or 1) then
        ZygorClassic_SelectGuide247(recommended,true)
    else
        if ZygorClassicDebug82 then
            ZygorClassicDebug82.event="AUTO MODE: current guide is recommended"
        end
        if ZygorClassicGuidePicker247 then ZygorClassic_RenderGuidePicker247() end
        if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
        ZygorClassic_PlayerRender246()
    end
end

function ZygorClassic_ApplyRecommendation248()
    if ZygorClassic_GuideMode248()~="AUTO" then return end
    -- TEST297: reaching the first level of the next bracket is a recommendation,
    -- not proof that the current route is finished. Preserve the active guide
    -- until its final step (or an explicit finish step); the existing guide-end
    -- transition and Use Recommended button can then perform the handoff.
    local viewer=ZygorGuidesViewer
    local guide=viewer and viewer.CurrentGuide
    local steps=guide and guide.steps
    if steps and table.getn(steps)>0 then
        local current=tonumber(ZygorClassicStepIndex or viewer.CurrentStepNum or 1) or 1
        local finish=viewer.CurrentStep and viewer.CurrentStep.finish
        if current<table.getn(steps) and not finish then
            if ZygorClassicDebug82 then
                ZygorClassicDebug82.event="AUTO HOLD: finish current guide before bracket handoff"
            end
            return
        end
    end
    local recommended=ZygorClassic_RecommendedGuide248()
    if recommended and recommended~=(ZygorClassicGuideIndex or 1) then
        ZygorClassic_SelectGuide247(recommended,true)
    end
end

-- Add recommendation and mode labels without replacing the proven TEST247
-- picker implementation.
ZygorClassic_RenderGuidePicker247_Base248=ZygorClassic_RenderGuidePicker247
ZygorClassic_RenderGuidePicker247=function()
    if ZygorClassic_RenderGuidePicker247_Base248 then ZygorClassic_RenderGuidePicker247_Base248() end
    if not ZygorClassicGuideRows247 then return end
    local recommended=ZygorClassic_RecommendedGuide248()
    local choices=ZygorClassic_GuideChoices247()
    local perPage=8
    local level=UnitLevel("player") or 1
    local row
    for row=1,perPage do
        local choice=choices[((ZygorClassicGuidePage247 or 1)-1)*perPage+row]
        local button=ZygorClassicGuideRows247[row]
        if choice and button then
            local prefix=""
            if choice.index==(ZygorClassicGuideIndex or 1) then
                if choice.index==recommended and ZygorClassic_GuideMode248()=="AUTO" then
                    prefix="|cff55dd55AUTO CURRENT|r  "
                else
                    prefix="|cffffcc00CURRENT|r  "
                end
            elseif choice.index==recommended then
                prefix="|cff55dd55RECOMMENDED|r  "
            elseif level>=choice.low and level<=choice.high then
                prefix="|cff99cc99LEVEL MATCH|r  "
            end
            button:SetText(prefix..ZygorClassic_ShortGuideTitle247(choice.title))
        end
    end
    if ZygorClassicGuidePickerHint247 then
        local recommendedTitle="None"
        local guides=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides
        if recommended and guides and guides[recommended] then
            recommendedTitle=ZygorClassic_ShortGuideTitle247(guides[recommended].title)
        end
        ZygorClassicGuidePickerHint247:SetText(
            "Mode: |cffffcc00"..ZygorClassic_GuideMode248().."|r   Recommended: |cff55dd55"..
            recommendedTitle.."|r\nChoose any same-faction Vanilla route, or return control to AUTO below."
        )
    end
end

if ZygorClassicGuidePicker247 and not ZygorClassicUseRecommended248 then
    ZygorClassicUseRecommended248=CreateFrame("Button","ZygorClassicUseRecommended248",ZygorClassicGuidePicker247,"UIPanelButtonTemplate")
    ZygorClassicUseRecommended248:SetWidth(138)
    ZygorClassicUseRecommended248:SetHeight(22)
    ZygorClassicUseRecommended248:SetPoint("LEFT",ZygorClassicGuidePickerNext247,"RIGHT",8,0)
    ZygorClassicUseRecommended248:SetText("Use Recommended")
    ZygorClassicUseRecommended248:SetScript("OnClick",ZygorClassic_UseRecommended248)
end

if not ZygorClassicGuideAutoFrame248 then
    ZygorClassicGuideAutoFrame248=CreateFrame("Frame","ZygorClassicGuideAutoFrame248",UIParent)
    ZygorClassicGuideAutoFrame248:RegisterEvent("PLAYER_ENTERING_WORLD")
    ZygorClassicGuideAutoFrame248:RegisterEvent("PLAYER_LEVEL_UP")
    ZygorClassicGuideAutoFrame248.elapsed=0
    ZygorClassicGuideAutoFrame248.pending=nil
    ZygorClassicGuideAutoFrame248:SetScript("OnEvent",function()
        this.pending=true
        this.elapsed=0
    end)
    ZygorClassicGuideAutoFrame248:SetScript("OnUpdate",function()
        if not this.pending then return end
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.80 then return end
        if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides or
           table.getn(ZygorGuidesViewer.registeredguides)<1 then return end
        this.pending=nil
        this.elapsed=0
        ZygorClassic_ApplyRecommendation248()
    end)
end

ZYGOR_BACKPORT_VERSION = "TEST248"


-- TEST249: AUTO can now be disabled without changing guides or resetting the
-- current step. Choosing a different guide still enters MANUAL through TEST247.
function ZygorClassic_LockCurrentGuide249()
    ZygorClassicDB=ZygorClassicDB or {}
    ZygorClassicDB.manualGuide247=ZygorClassicDB.manualGuide247 or {}
    local key=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
    ZygorClassicDB.manualGuide247[key]=ZygorClassicGuideIndex or 1
    if ZygorClassicDebug82 then
        ZygorClassicDebug82.event="MANUAL MODE: current guide locked"
        ZygorClassicDebug82.route="manual lock G"..tostring(ZygorClassicGuideIndex or 1)..
                                  " S"..tostring(ZygorClassicStepIndex or 1)
    end
    if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
    if ZygorClassic_SaveProgress then ZygorClassic_SaveProgress() end
    if ZygorClassicGuidePicker247 then ZygorClassic_RenderGuidePicker247() end
    if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
    ZygorClassic_PlayerRender246()
end

if ZygorClassicGuidePicker247 then
    ZygorClassicGuidePicker247:SetHeight(420)
end

if ZygorClassicUseRecommended248 then
    ZygorClassicUseRecommended248:ClearAllPoints()
    ZygorClassicUseRecommended248:SetWidth(168)
    ZygorClassicUseRecommended248:SetPoint("BOTTOMLEFT",ZygorClassicGuidePicker247,"BOTTOMLEFT",16,48)
end

if ZygorClassicGuidePicker247 and not ZygorClassicLockCurrent249 then
    ZygorClassicLockCurrent249=CreateFrame("Button","ZygorClassicLockCurrent249",ZygorClassicGuidePicker247,"UIPanelButtonTemplate")
    ZygorClassicLockCurrent249:SetWidth(168)
    ZygorClassicLockCurrent249:SetHeight(22)
    ZygorClassicLockCurrent249:SetPoint("LEFT",ZygorClassicUseRecommended248,"RIGHT",8,0)
    ZygorClassicLockCurrent249:SetText("Lock Current (Manual)")
    ZygorClassicLockCurrent249:SetScript("OnClick",ZygorClassic_LockCurrentGuide249)
end

ZygorClassic_RenderGuidePicker247_Base249=ZygorClassic_RenderGuidePicker247
ZygorClassic_RenderGuidePicker247=function()
    if ZygorClassic_RenderGuidePicker247_Base249 then ZygorClassic_RenderGuidePicker247_Base249() end
    if ZygorClassicGuidePickerHint247 then
        local recommended=ZygorClassic_RecommendedGuide248()
        local recommendedTitle="None"
        local guides=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides
        if recommended and guides and guides[recommended] then
            recommendedTitle=ZygorClassic_ShortGuideTitle247(guides[recommended].title)
        end
        ZygorClassicGuidePickerHint247:SetText(
            "Mode: |cffffcc00"..ZygorClassic_GuideMode248().."|r   Recommended: |cff55dd55"..
            recommendedTitle.."|r\nChoose another route or Lock Current for MANUAL. Use Recommended returns to AUTO."
        )
    end
end

ZYGOR_BACKPORT_VERSION = "TEST249"

ZYGOR_BACKPORT_VERSION = "TEST251"


-- TEST252: player-facing help for the backported guide controls. Keep the
-- diagnostic panel available for troubleshooting, but explain normal use in a
-- separate compact window so a new player does not need to interpret debug data.
function ZygorClassic_ToggleHelp252()
    if not ZygorClassicHelp252 then return end
    if ZygorClassicHelp252:IsShown() then ZygorClassicHelp252:Hide()
    else ZygorClassicHelp252:Show() end
end

function ZygorClassic_CreateHelp252()
    if ZygorClassicHelp252 then return end
    ZygorClassicHelp252=CreateFrame("Frame","ZygorClassicHelp252",UIParent)
    ZygorClassicHelp252:SetWidth(590)
    ZygorClassicHelp252:SetHeight(500)
    ZygorClassicHelp252:SetPoint("CENTER",UIParent,"CENTER",0,20)
    ZygorClassicHelp252:SetFrameStrata("DIALOG")
    ZygorClassicHelp252:SetMovable(true)
    ZygorClassicHelp252:EnableMouse(true)
    ZygorClassicHelp252:RegisterForDrag("LeftButton")
    ZygorClassicHelp252:SetScript("OnDragStart",function() this:StartMoving() end)
    ZygorClassicHelp252:SetScript("OnDragStop",function() this:StopMovingOrSizing() end)
    ZygorClassicHelp252:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true,tileSize=16,edgeSize=16,
        insets={left=5,right=5,top=5,bottom=5}
    })
    ZygorClassicHelp252:SetBackdropColor(0.025,0.025,0.025,0.98)
    ZygorClassicHelp252:SetBackdropBorderColor(0.55,0.42,0.12,1)

    ZygorClassicHelpTitle252=ZygorClassicHelp252:CreateFontString(
        "ZygorClassicHelpTitle252","OVERLAY","GameFontNormalLarge")
    ZygorClassicHelpTitle252:SetPoint("TOPLEFT",ZygorClassicHelp252,"TOPLEFT",18,-16)
    ZygorClassicHelpTitle252:SetText("Zygor Guides - Player Help")
    ZygorClassicHelpTitle252:SetTextColor(1,0.82,0.18)
    ZygorClassicHelpClose252=CreateFrame(
        "Button","ZygorClassicHelpClose252",ZygorClassicHelp252,"UIPanelCloseButton")
    ZygorClassicHelpClose252:SetPoint("TOPRIGHT",ZygorClassicHelp252,"TOPRIGHT",-4,-4)
    ZygorClassicHelpClose252:SetScript("OnClick",function() ZygorClassicHelp252:Hide() end)
    ZygorClassicHelpRule252=ZygorClassicHelp252:CreateTexture(
        "ZygorClassicHelpRule252","ARTWORK")
    ZygorClassicHelpRule252:SetTexture("Interface\\AddOns\\ZygorGuidesViewer\\Skin\\white")
    ZygorClassicHelpRule252:SetVertexColor(0.58,0.42,0.10,0.70)
    ZygorClassicHelpRule252:SetHeight(1)
    ZygorClassicHelpRule252:SetPoint("TOPLEFT",ZygorClassicHelp252,"TOPLEFT",16,-44)
    ZygorClassicHelpRule252:SetPoint("TOPRIGHT",ZygorClassicHelp252,"TOPRIGHT",-16,-44)
    ZygorClassicHelpBody252=ZygorClassicHelp252:CreateFontString(
        "ZygorClassicHelpBody252","OVERLAY","GameFontHighlightSmall")
    ZygorClassicHelpBody252:SetPoint("TOPLEFT",ZygorClassicHelp252,"TOPLEFT",20,-59)
    ZygorClassicHelpBody252:SetWidth(550)
    ZygorClassicHelpBody252:SetHeight(420)
    ZygorClassicHelpBody252:SetJustifyH("LEFT")
    ZygorClassicHelpBody252:SetJustifyV("TOP")
    ZygorClassicHelpBody252:SetText(
        "|cffffcc33CURRENT STEP|r\n"..
        "- The gold > marks the action to do now. Green [done] lines are complete.\n"..
        "- The waypoint arrow follows the current step's guide coordinates.\n"..
        "- Quest accepts, objectives and turn-ins advance from the live quest log.\n\n"..
        "|cffffcc33STEP CONTROLS|r\n"..
        "- < Step and Step > let you inspect nearby steps manually. Normal tracking resumes after a stable quest change.\n"..
        "- If an objective is reached without its required quest, the recovery engine returns to that quest's accept step.\n\n"..
        "|cffffcc33CHOOSE GUIDE|r\n"..
        "- AUTO recommends a same-faction Vanilla route for your race and level.\n"..
        "- Choosing another route or Lock Current switches to MANUAL and preserves that guide.\n"..
        "- Use Recommended returns control to AUTO. Guide changes begin near your current level.\n\n"..
        "|cffffcc33WINDOWS AND TROUBLESHOOTING|r\n"..
        "- Player UI is the compact everyday tracker. Drag its border area to move it.\n"..
        "- Arrow On/Off toggles the graphical pointer. Right-click Arrow to rebuild a stuck waypoint.\n"..
        "- Diagnostics opens the large technical panel. Use it only when a step or waypoint looks wrong; include it in a screenshot.\n"..
        "- Reload UI reloads addon code without logging out. The minimap icon opens the guide interface.\n"..
        "- Addon updates are checked by the launcher; the Vanilla client cannot contact GitHub directly.\n\n"..
        "|cffaaaaaaTip: complete steps in guide order when possible. Manual navigation never changes your selected AUTO/MANUAL guide mode.|r"
    )
    ZygorClassicHelp252:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames,"ZygorClassicHelp252") end
end

ZygorClassic_CreateHelp252()

if ZygorClassicPlayerFrame246 and not ZygorClassicPlayerHelp252 then
    ZygorClassicPlayerHelp252=CreateFrame(
        "Button","ZygorClassicPlayerHelp252",ZygorClassicPlayerFrame246,"UIPanelButtonTemplate")
    ZygorClassicPlayerHelp252:SetWidth(62)
    ZygorClassicPlayerHelp252:SetHeight(22)
    if ZygorClassicChooseGuide247 then
        ZygorClassicPlayerHelp252:SetPoint("LEFT",ZygorClassicChooseGuide247,"RIGHT",8,0)
    else
        ZygorClassicPlayerHelp252:SetPoint("LEFT",ZygorClassicPlayerNext246,"RIGHT",8,0)
    end
    ZygorClassicPlayerHelp252:SetText("Help")
    ZygorClassicPlayerHelp252:SetScript("OnClick",ZygorClassic_ToggleHelp252)
end

if ZygorGuidesViewerFrame and not ZygorClassicMainHelp252 then
    ZygorClassicMainHelp252=CreateFrame(
        "Button","ZygorClassicMainHelp252",ZygorGuidesViewerFrame,"UIPanelButtonTemplate")
    ZygorClassicMainHelp252:SetWidth(78)
    ZygorClassicMainHelp252:SetHeight(24)
    if ZygorClassicPlayerToggle246 then
        ZygorClassicMainHelp252:SetPoint("RIGHT",ZygorClassicPlayerToggle246,"LEFT",-10,0)
    else
        ZygorClassicMainHelp252:SetPoint("BOTTOMRIGHT",ZygorGuidesViewerFrame,"BOTTOMRIGHT",-240,18)
    end
    ZygorClassicMainHelp252:SetText("Help")
    ZygorClassicMainHelp252:SetScript("OnClick",ZygorClassic_ToggleHelp252)
end

-- TEST269: ClassicQuestAssist is loaded in a later TOC chunk, while this
-- renderer is file-local.  Ask the later module for its live diagnostics from
-- inside this scope so the block actually appears in the large window.
-- Keep this slot global: the original 1.12 client permits only 200 locals in
-- one Lua chunk, and this large compatibility file is already at that limit.
ZygorClassic_UpdateDebug82_Base266=ZygorClassic_UpdateDebug82
ZygorClassic_UpdateDebug82=function()
    if ZygorClassic_UpdateDebug82_Base266 then ZygorClassic_UpdateDebug82_Base266() end
    if not ZygorClassicDebugText82 or not ZygorClassicQuestAssist or
       not ZygorClassicQuestAssist.DiagnosticText then return end
    local current=ZygorClassicDebugText82:GetText() or ""
    local firstBreak=string.find(current,"\n",1,true)
    local block=ZygorClassicQuestAssist:DiagnosticText()
    if firstBreak then
        current=string.sub(current,1,firstBreak)..block.."\n"..string.sub(current,firstBreak+1)
    else
        current=block.."\n"..current
    end
    ZygorClassicDebugText82:SetText(current)
end

-- Public bridge for later TOC files.  The renderer itself is intentionally
-- local to this compatibility chunk, so ClassicQuestAssist cannot call it by
-- name without this small hand-off.
function ZygorClassic_RefreshDiagnostics266()
    if ZygorClassic_UpdateDebug82 then ZygorClassic_UpdateDebug82() end
end

-- TEST269: the old visible renderer rebuilt the full guide and chained debug
-- panel ten times per second even while Diagnostics was closed.  Keep the same
-- information, but render only while that window is visible and leave debug
-- formatting to ClassicQuestAssist's single two-second diagnostics owner.
if ZygorClassicVisible81Frame then
    ZygorClassicVisible81Frame.elapsed=0
    ZygorClassicVisible81Frame:SetScript("OnUpdate",function()
        if not ZygorGuidesViewerFrame or not ZygorGuidesViewerFrame:IsShown() then return end
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<1.00 then return end
        this.elapsed=0
        if not ZygorGuidesViewer or not ZygorGuidesViewer.registeredguides or
           table.getn(ZygorGuidesViewer.registeredguides)<1 then return end
        ZygorClassic_RenderAuthoritative81()
    end)
end

-- TEST287: retire the redundant text-only waypoint box. The graphical pointer
-- now contains distance plus player/target coordinates in one compact display.
ZygorClassic_UpdateArrow55=function()
    if ZygorClassicArrow55 and ZygorClassicArrow55:IsShown() then
        ZygorClassicArrow55:Hide()
    end
end
if ZygorClassicArrow55 then
    ZygorClassicArrow55:Hide()
    ZygorClassicArrow55:EnableMouse(false)
end

function ZygorClassic_UpdateArrowButton287()
    if not ZygorClassicPlayerArrow287 then return end
    ZygorClassicDB=ZygorClassicDB or {}
    if ZygorClassicDB.arrowEnabled287==false then
        ZygorClassicPlayerArrow287:SetText("Arrow Off")
    else
        ZygorClassicPlayerArrow287:SetText("Arrow On")
    end
end

function ZygorClassic_ResetWaypoint287(silent)
    if ZygorGuidesViewer and ZygorGuidesViewer.Pointer then
        ZygorGuidesViewer.Pointer:ClearWaypoints("way")
    end
    ZygorPointerBridgeKey164=nil
    if ZygorPointerBridge164 then ZygorPointerBridge164() end
    if ZygorClassicDB and ZygorClassicDB.arrowEnabled287==false and
       ZygorGuidesViewer and ZygorGuidesViewer.Pointer and
       ZygorGuidesViewer.Pointer.ArrowFrame then
        ZygorGuidesViewer.Pointer.ArrowFrame:Hide()
    end
    if not silent and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Zygor:|r waypoint rebuilt from the current step.")
    end
end

function ZygorClassic_ToggleArrow287()
    ZygorClassicDB=ZygorClassicDB or {}
    ZygorClassicDB.arrowEnabled287=not (ZygorClassicDB.arrowEnabled287~=false)
    if ZygorClassicDB.arrowEnabled287 then
        ZygorClassic_ResetWaypoint287(true)
    elseif ZygorGuidesViewer and ZygorGuidesViewer.Pointer and
           ZygorGuidesViewer.Pointer.ArrowFrame then
        ZygorGuidesViewer.Pointer.ArrowFrame:Hide()
    end
    ZygorClassic_UpdateArrowButton287()
end

if ZygorClassicPlayerFrame246 then
    ZygorClassicPlayerPrev246:SetWidth(62)
    ZygorClassicPlayerNext246:SetWidth(62)
    ZygorClassicPlayerNext246:ClearAllPoints()
    ZygorClassicPlayerNext246:SetPoint("LEFT",ZygorClassicPlayerPrev246,"RIGHT",4,0)
    if ZygorClassicChooseGuide247 then
        ZygorClassicChooseGuide247:SetWidth(90)
        ZygorClassicChooseGuide247:ClearAllPoints()
        ZygorClassicChooseGuide247:SetPoint("LEFT",ZygorClassicPlayerNext246,"RIGHT",5,0)
    end
    if ZygorClassicPlayerHelp252 then
        ZygorClassicPlayerHelp252:SetWidth(48)
        ZygorClassicPlayerHelp252:ClearAllPoints()
        ZygorClassicPlayerHelp252:SetPoint("LEFT",ZygorClassicChooseGuide247,"RIGHT",5,0)
    end
    ZygorClassicPlayerDebug246:SetWidth(84)

    if not ZygorClassicPlayerArrow287 then
        ZygorClassicPlayerArrow287=CreateFrame(
            "Button","ZygorClassicPlayerArrow287",ZygorClassicPlayerFrame246,"UIPanelButtonTemplate")
        ZygorClassicPlayerArrow287:SetWidth(68)
        ZygorClassicPlayerArrow287:SetHeight(22)
        ZygorClassicPlayerArrow287:SetPoint("LEFT",ZygorClassicPlayerHelp252,"RIGHT",5,0)
        ZygorClassicPlayerArrow287:RegisterForClicks("LeftButtonUp","RightButtonUp")
        ZygorClassicPlayerArrow287:SetScript("OnClick",function()
            if arg1=="RightButton" or (IsShiftKeyDown and IsShiftKeyDown()) then
                ZygorClassic_ResetWaypoint287(false)
            else
                ZygorClassic_ToggleArrow287()
            end
        end)
    end
    ZygorClassic_UpdateArrowButton287()
end

-- TEST289: engine172 is the sole owner of the active guide and step.  A few
-- retained legacy callbacks can still write the old display globals (for
-- example 180 while the engine remains at 87).  All visible consumers read
-- this position, and the inexpensive guard projects it back to the globals.
-- It never changes engine state or quest-resolution evidence.
function ZygorClassic_AuthoritativePosition289()
    local guideIndex=ZygorClassicGuideIndex or 1
    local stepIndex=ZygorClassicStepIndex or 1
    local key=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
    local state=ZygorClassicDB and ZygorClassicDB.engine172 and
                ZygorClassicDB.engine172[key]
    if state and tonumber(state.guide) and tonumber(state.step) then
        guideIndex=tonumber(state.guide)
        stepIndex=tonumber(state.step)
    end
    return guideIndex,stepIndex,state
end

function ZygorClassic_ReconcilePosition289()
    local guideIndex,stepIndex,state=ZygorClassic_AuthoritativePosition289()
    if not state then return false end
    local changed=(ZygorClassicGuideIndex~=guideIndex or
                   ZygorClassicStepIndex~=stepIndex)
    if changed then
        ZygorClassicGuideIndex=guideIndex
        ZygorClassicStepIndex=stepIndex
    end
    return changed
end

if not ZygorClassicPositionGuard289 then
    ZygorClassicPositionGuard289=CreateFrame("Frame","ZygorClassicPositionGuard289",UIParent)
    ZygorClassicPositionGuard289.elapsed=0
    ZygorClassicPositionGuard289:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.20 then return end
        this.elapsed=0
        if ZygorClassic_ReconcilePosition289() then
            if ZygorClassic_PlayerRender246 then ZygorClassic_PlayerRender246() end
            if ZygorClassic_Render then ZygorClassic_Render() end
            if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
        end
    end)
end

-- TEST291: compact retail-inspired player tracker.  The guide engine and
-- action resolver are unchanged; this replaces only the visible shell.
function ZygorClassic_ModernButton291(name,parent,label,width,callback)
    local button=CreateFrame("Button",name,parent)
    button:SetWidth(width)
    button:SetHeight(22)
    button.bg=button:CreateTexture(nil,"BACKGROUND")
    button.bg:SetAllPoints(button)
    button.bg:SetTexture("Interface\\AddOns\\ZygorGuidesViewer\\Skin\\white")
    button.bg:SetVertexColor(0.13,0.14,0.16,0.96)
    button.text=button:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    button.text:SetPoint("CENTER",button,"CENTER",0,0)
    button.text:SetText(label)
    button:SetScript("OnEnter",function() this.bg:SetVertexColor(0.25,0.27,0.30,1) end)
    button:SetScript("OnLeave",function() this.bg:SetVertexColor(0.13,0.14,0.16,0.96) end)
    button:SetScript("OnMouseDown",function() this.bg:SetVertexColor(0.42,0.12,0.10,1) end)
    button:SetScript("OnMouseUp",function()
        this.bg:SetVertexColor(0.25,0.27,0.30,1)
        if callback then callback(arg1) end
    end)
    return button
end

function ZygorClassic_ModernRow291(index)
    ZygorClassicModernRows291=ZygorClassicModernRows291 or {}
    if ZygorClassicModernRows291[index] then return ZygorClassicModernRows291[index] end
    local row=CreateFrame("Frame","ZygorClassicModernRow291_"..tostring(index),ZygorClassicPlayerFrame246)
    row.bg=row:CreateTexture(nil,"BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetTexture("Interface\\AddOns\\ZygorGuidesViewer\\Skin\\white")
    row.text=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT",row,"TOPLEFT",9,-4)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetFont("Fonts\\FRIZQT__.TTF",13)
    ZygorClassicModernRows291[index]=row
    return row
end

-- TEST301: scale the compact tracker typography with its resizable width.
-- The limits preserve readability without letting large windows become noisy.
local function ZygorClassic_ModernFont301(base,width,minimum,maximum)
    local size=math.floor((base*((width or 380)/380))+0.5)
    if size<minimum then size=minimum end
    if size>maximum then size=maximum end
    return size
end

-- TEST304: Vanilla's FontString height can lag one layout behind after a
-- resize.  Estimate wrapped lines as well so state backgrounds always cover
-- every rendered line instead of only the first one.
local function ZygorClassic_WrappedLines304(text,charactersPerLine)
    local lines=0
    local logical=tostring(text or "").."\n"
    for paragraph in string.gfind(logical,"([^\n]*)\n") do
        local used=0
        local found=false
        for word in string.gfind(paragraph,"%S+") do
            found=true
            local length=string.len(word)
            if used==0 then
                used=length
            elseif used+1+length<=charactersPerLine then
                used=used+1+length
            else
                lines=lines+1
                used=length
            end
        end
        lines=lines+1
        if not found then used=0 end
    end
    if lines<1 then lines=1 end
    return lines
end

function ZygorClassic_RenderModern291(rows,stepIndex,stepCount,shortTitle)
    if not ZygorClassicPlayerFrame246 then return end
    ZygorClassicModernLastRows291=rows
    ZygorClassicModernLastStep291=stepIndex
    ZygorClassicModernLastCount291=stepCount
    ZygorClassicModernLastGuide291=shortTitle
    if ZygorClassicModernLayoutBusy291 then return end
    ZygorClassicModernLayoutBusy291=true

    local frame=ZygorClassicPlayerFrame246
    local width=frame:GetWidth() or 380
    if width<320 then width=320 frame:SetWidth(width) end
    local contentWidth=width-20
    local rowFont=ZygorClassic_ModernFont301(14,width,12,24)
    local titleFont=ZygorClassic_ModernFont301(22,width,18,32)
    local headerFont=ZygorClassic_ModernFont301(14,width,12,22)
    local guideFont=ZygorClassic_ModernFont301(12,width,10,18)
    local footerFont=ZygorClassic_ModernFont301(11,width,10,17)
    local percentFont=ZygorClassic_ModernFont301(9,width,9,15)
    local footerScale=math.max(0.90,math.min(1.65,width/380))
    local footerHeight=math.max(22,footerFont+10)
    local footerBottom=9
    local progressHeight=math.max(7,percentFont+4)
    local progressBottom=footerBottom+footerHeight+6
    local footerReserve=progressBottom+progressHeight+8
    -- TEST305: every vertical anchor follows the scaled typography.  Fixed
    -- header offsets caused the step label to wrap underneath the first row.
    local titleTop=8
    local guideTop=titleTop+titleFont+8
    local controlsTop=guideTop+guideFont+7
    local controlHeight=math.max(24,headerFont+9)
    local rowTop=controlsTop+controlHeight+7
    local nextX=52+math.max(110,headerFont*8)
    if ZygorClassicPlayerTitle246 then
        ZygorClassicPlayerTitle246:ClearAllPoints()
        ZygorClassicPlayerTitle246:SetPoint("TOP",frame,"TOP",0,-titleTop)
        ZygorClassicPlayerTitle246:SetFont("Fonts\\FRIZQT__.TTF",titleFont)
    end
    if ZygorClassicPlayerGuide246 then
        ZygorClassicPlayerGuide246:ClearAllPoints()
        ZygorClassicPlayerGuide246:SetPoint("TOPLEFT",frame,"TOPLEFT",12,-guideTop)
        ZygorClassicPlayerGuide246:SetWidth(width-24)
        ZygorClassicPlayerGuide246:SetFont("Fonts\\FRIZQT__.TTF",guideFont)
    end
    if ZygorClassicModernPrev291 then
        ZygorClassicModernPrev291:ClearAllPoints()
        ZygorClassicModernPrev291:SetPoint("TOPLEFT",frame,"TOPLEFT",12,-controlsTop)
        ZygorClassicModernPrev291:SetHeight(controlHeight)
    end
    if ZygorClassicPlayerMeta246 then
        ZygorClassicPlayerMeta246:ClearAllPoints()
        ZygorClassicPlayerMeta246:SetPoint("TOPLEFT",frame,"TOPLEFT",52,-controlsTop-4)
        ZygorClassicPlayerMeta246:SetWidth(math.max(100,nextX-58))
        ZygorClassicPlayerMeta246:SetFont("Fonts\\FRIZQT__.TTF",headerFont)
    end
    if ZygorClassicModernNext291 then
        ZygorClassicModernNext291:ClearAllPoints()
        ZygorClassicModernNext291:SetPoint("TOPLEFT",frame,"TOPLEFT",nextX,-controlsTop)
        ZygorClassicModernNext291:SetHeight(controlHeight)
    end
    if ZygorClassicModernMode291 then
        ZygorClassicModernMode291:ClearAllPoints()
        ZygorClassicModernMode291:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-35,-controlsTop-4)
    end
    if ZygorClassicModernHeader291 then
        ZygorClassicModernHeader291:ClearAllPoints()
        ZygorClassicModernHeader291:SetPoint("TOPLEFT",frame,"TOPLEFT",3,-guideTop+4)
        ZygorClassicModernHeader291:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-3,-guideTop+4)
        ZygorClassicModernHeader291:SetHeight(rowTop-guideTop+2)
    end
    if ZygorClassicPlayerRule246 then
        ZygorClassicPlayerRule246:ClearAllPoints()
        ZygorClassicPlayerRule246:SetPoint("TOPLEFT",frame,"TOPLEFT",10,-rowTop+3)
        ZygorClassicPlayerRule246:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-10,-rowTop+3)
    end
    local totalHeight=0
    local i
    for i=1,table.getn(rows or {}) do
        local data=rows[i]
        local row=ZygorClassic_ModernRow291(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",frame,"TOPLEFT",10,-rowTop-totalHeight)
        row:SetWidth(contentWidth)
        row.text:SetWidth(contentWidth-18)
        row.text:SetFont("Fonts\\FRIZQT__.TTF",rowFont)
        local prefix="o  "
        if data.state=="done" then
            prefix="[x] "
            row.bg:SetVertexColor(0.05,0.18,0.10,0.92)
            row.text:SetTextColor(0.55,0.90,0.62)
        elseif data.state=="active" then
            prefix="!  "
            row.bg:SetVertexColor(0.48,0.08,0.07,0.96)
            row.text:SetTextColor(1,1,1)
        elseif data.state=="info" then
            prefix="-  "
            row.bg:SetVertexColor(0.07,0.075,0.085,0.90)
            row.text:SetTextColor(0.70,0.72,0.75)
        else
            row.bg:SetVertexColor(0.09,0.095,0.105,0.94)
            row.text:SetTextColor(0.84,0.85,0.87)
        end
        local displayText=prefix..tostring(data.text or "")
        row.text:SetText(displayText)
        local textHeight=row.text.GetStringHeight and row.text:GetStringHeight() or rowFont
        local charactersPerLine=math.max(12,math.floor((contentWidth-18)/(rowFont*0.54)))
        local estimatedLines=ZygorClassic_WrappedLines304(displayText,charactersPerLine)
        local measuredLines=math.max(1,math.ceil((tonumber(textHeight) or rowFont)/(rowFont+2)))
        local wrappedLines=math.max(estimatedLines,measuredLines)
        local rowHeight=math.max(rowFont+9,wrappedLines*(rowFont+2)+8)
        row:SetHeight(rowHeight)
        row.text:SetHeight(rowHeight-8)
        row:Show()
        totalHeight=totalHeight+rowHeight+2
    end
    if ZygorClassicModernRows291 then
        for i=table.getn(rows or {})+1,table.getn(ZygorClassicModernRows291) do
            ZygorClassicModernRows291[i]:Hide()
        end
    end

    local neededHeight=rowTop+totalHeight+footerReserve
    ZygorClassicDB=ZygorClassicDB or {}
    local savedHeight=tonumber(ZygorClassicDB.playerHeight291) or 0
    if not ZygorClassicModernUserSizing291 then
        frame:SetHeight(math.max(neededHeight,savedHeight))
    end
    if ZygorClassicPlayerTitle246 then
        ZygorClassicPlayerTitle246:SetFont("Fonts\\FRIZQT__.TTF",titleFont)
        ZygorClassicPlayerTitle246:SetText("ZYGOR")
    end
    if ZygorClassicPlayerGuide246 then
        ZygorClassicPlayerGuide246:SetFont("Fonts\\FRIZQT__.TTF",guideFont)
        ZygorClassicPlayerGuide246:SetText("|cffffb000XP|r  "..tostring(shortTitle or "Guide"))
    end
    if ZygorClassicPlayerMeta246 then
        ZygorClassicPlayerMeta246:SetFont("Fonts\\FRIZQT__.TTF",headerFont)
        ZygorClassicPlayerMeta246:SetText("Step |cffffffff"..tostring(stepIndex).."|r / "..tostring(stepCount))
    end
    if ZygorClassicModernMode291 then
        ZygorClassicModernMode291:SetFont("Fonts\\FRIZQT__.TTF",guideFont)
        local mode=ZygorClassic_GuideMode248 and ZygorClassic_GuideMode248() or "AUTO"
        ZygorClassicModernMode291:SetText(mode)
        if mode=="MANUAL" then ZygorClassicModernMode291:SetTextColor(1,0.72,0.15)
        else ZygorClassicModernMode291:SetTextColor(0.35,0.90,0.45) end
    end
    if ZygorClassicPlayerProgress246 then
        ZygorClassicPlayerProgress246:ClearAllPoints()
        ZygorClassicPlayerProgress246:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",10,progressBottom)
        ZygorClassicPlayerProgress246:SetWidth(contentWidth)
        ZygorClassicPlayerProgress246:SetHeight(progressHeight)
    end
    if ZygorClassicPlayerProgressText246 then
        ZygorClassicPlayerProgressText246:SetFont("Fonts\\FRIZQT__.TTF",percentFont)
    end
    local function ScaleFooterButton306(button,baseWidth)
        if not button then return end
        button:SetWidth(math.floor(baseWidth*footerScale+0.5))
        button:SetHeight(footerHeight)
        if button.text then button.text:SetFont("Fonts\\FRIZQT__.TTF",footerFont) end
    end
    ScaleFooterButton306(ZygorClassicModernGuide291,54)
    ScaleFooterButton306(ZygorClassicModernHelp291,28)
    ScaleFooterButton306(ZygorClassicModernArrow291,64)
    ScaleFooterButton306(ZygorClassicModernDebug291,44)
    if ZygorClassicModernGuide291 then
        ZygorClassicModernGuide291:ClearAllPoints()
        ZygorClassicModernGuide291:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",10,footerBottom)
    end
    if ZygorClassicModernHelp291 then
        ZygorClassicModernHelp291:ClearAllPoints()
        ZygorClassicModernHelp291:SetPoint("LEFT",ZygorClassicModernGuide291,"RIGHT",math.max(4,math.floor(4*footerScale)),0)
    end
    if ZygorClassicModernArrow291 then
        ZygorClassicModernArrow291:ClearAllPoints()
        ZygorClassicModernArrow291:SetPoint("LEFT",ZygorClassicModernHelp291,"RIGHT",math.max(4,math.floor(4*footerScale)),0)
    end
    if ZygorClassicModernDebug291 then
        ZygorClassicModernDebug291:ClearAllPoints()
        ZygorClassicModernDebug291:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-24,footerBottom)
    end
    if ZygorClassicModernResize291 then
        local gripSize=math.max(14,math.floor(14*footerScale+0.5))
        ZygorClassicModernResize291:SetWidth(gripSize)
        ZygorClassicModernResize291:SetHeight(gripSize)
        if ZygorClassicModernResize291.label then
            ZygorClassicModernResize291.label:SetFont("Fonts\\FRIZQT__.TTF",math.max(9,percentFont))
        end
    end
    ZygorClassicModernLayoutBusy291=nil
end

function ZygorClassic_ResetModernSize291()
    ZygorClassicDB=ZygorClassicDB or {}
    ZygorClassicDB.playerWidth291=380
    ZygorClassicDB.playerHeight291=nil
    ZygorClassicPlayerFrame246:SetWidth(380)
    if ZygorClassicModernLastRows291 then
        ZygorClassic_RenderModern291(ZygorClassicModernLastRows291,
            ZygorClassicModernLastStep291,ZygorClassicModernLastCount291,ZygorClassicModernLastGuide291)
    end
end

if ZygorClassicPlayerFrame246 then
    ZygorClassicDB=ZygorClassicDB or {}
    local frame=ZygorClassicPlayerFrame246
    frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true,tileSize=16,edgeSize=8,
        insets={left=2,right=2,top=2,bottom=2}
    })
    frame:SetBackdropColor(0.015,0.018,0.022,0.96)
    frame:SetBackdropBorderColor(0.16,0.17,0.19,1)
    frame:SetWidth(tonumber(ZygorClassicDB.playerWidth291) or 380)
    if frame.SetResizable then frame:SetResizable(true) end
    if frame.SetMinResize then frame:SetMinResize(320,145) end
    if frame.SetMaxResize then frame:SetMaxResize(650,650) end

    if ZygorClassicPlayerLogo246 then ZygorClassicPlayerLogo246:Hide() end
    if ZygorClassicPlayerCurrent246 then ZygorClassicPlayerCurrent246:Hide() end
    if ZygorClassicPlayerActions246 then ZygorClassicPlayerActions246:Hide() end
    if ZygorClassicPlayerRule246 then
        ZygorClassicPlayerRule246:ClearAllPoints()
        ZygorClassicPlayerRule246:SetPoint("TOPLEFT",frame,"TOPLEFT",10,-86)
        ZygorClassicPlayerRule246:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-10,-86)
        ZygorClassicPlayerRule246:SetVertexColor(0.25,0.26,0.28,1)
    end
    ZygorClassicPlayerTitle246:ClearAllPoints()
    ZygorClassicPlayerTitle246:SetPoint("TOP",frame,"TOP",0,-8)
    ZygorClassicPlayerTitle246:SetFont("Fonts\\FRIZQT__.TTF",20)
    ZygorClassicPlayerTitle246:SetTextColor(1,1,1)
    ZygorClassicPlayerGuide246:ClearAllPoints()
    ZygorClassicPlayerGuide246:SetPoint("TOPLEFT",frame,"TOPLEFT",12,-37)
    ZygorClassicPlayerGuide246:SetWidth(frame:GetWidth()-24)
    ZygorClassicPlayerMeta246:ClearAllPoints()
    ZygorClassicPlayerMeta246:SetPoint("TOPLEFT",frame,"TOPLEFT",48,-64)
    ZygorClassicPlayerMeta246:SetWidth(100)
    ZygorClassicPlayerMeta246:SetFont("Fonts\\FRIZQT__.TTF",13)

    ZygorClassicModernHeader291=frame:CreateTexture(nil,"BACKGROUND")
    ZygorClassicModernHeader291:SetTexture("Interface\\AddOns\\ZygorGuidesViewer\\Skin\\white")
    ZygorClassicModernHeader291:SetVertexColor(0.10,0.105,0.115,0.96)
    ZygorClassicModernHeader291:SetPoint("TOPLEFT",frame,"TOPLEFT",3,-31)
    ZygorClassicModernHeader291:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-3,-31)
    ZygorClassicModernHeader291:SetHeight(54)

    ZygorClassicModernMode291=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    ZygorClassicModernMode291:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-35,-64)

    ZygorClassicModernPrev291=ZygorClassic_ModernButton291("ZygorClassicModernPrev291",frame,"<",28,
        function() ZygorClassic_NextStep(-1,true) end)
    ZygorClassicModernPrev291:SetPoint("TOPLEFT",frame,"TOPLEFT",12,-55)
    ZygorClassicModernNext291=ZygorClassic_ModernButton291("ZygorClassicModernNext291",frame,">",28,
        function() ZygorClassic_NextStep(1,true) end)
    ZygorClassicModernNext291:SetPoint("TOPLEFT",frame,"TOPLEFT",150,-55)

    ZygorClassicModernGuide291=ZygorClassic_ModernButton291("ZygorClassicModernGuide291",frame,"Guide",54,
        function() if ZygorClassic_ToggleGuidePicker247 then ZygorClassic_ToggleGuidePicker247() end end)
    ZygorClassicModernGuide291:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",10,9)
    ZygorClassicModernHelp291=ZygorClassic_ModernButton291("ZygorClassicModernHelp291",frame,"?",28,
        function() if ZygorClassic_ToggleHelp252 then ZygorClassic_ToggleHelp252() end end)
    ZygorClassicModernHelp291:SetPoint("LEFT",ZygorClassicModernGuide291,"RIGHT",4,0)
    ZygorClassicModernArrow291=ZygorClassic_ModernButton291("ZygorClassicModernArrow291",frame,"Arrow",54,
        function(button)
            if button=="RightButton" then ZygorClassic_ResetWaypoint287(false)
            else ZygorClassic_ToggleArrow287() end
        end)
    ZygorClassicModernArrow291:RegisterForClicks("LeftButtonUp","RightButtonUp")
    ZygorClassicModernArrow291:SetPoint("LEFT",ZygorClassicModernHelp291,"RIGHT",4,0)
    ZygorClassicModernDebug291=ZygorClassic_ModernButton291("ZygorClassicModernDebug291",frame,"Diag",44,
        function() ZygorClassic_ToggleDiagnostics246() end)
    ZygorClassicModernDebug291:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-24,9)

    if ZygorClassicPlayerPrev246 then ZygorClassicPlayerPrev246:Hide() end
    if ZygorClassicPlayerNext246 then ZygorClassicPlayerNext246:Hide() end
    if ZygorClassicChooseGuide247 then ZygorClassicChooseGuide247:Hide() end
    if ZygorClassicPlayerHelp252 then ZygorClassicPlayerHelp252:Hide() end
    if ZygorClassicPlayerArrow287 then ZygorClassicPlayerArrow287:Hide() end
    if ZygorClassicPlayerDebug246 then ZygorClassicPlayerDebug246:Hide() end

    ZygorClassicModernResize291=CreateFrame("Button","ZygorClassicModernResize291",frame)
    ZygorClassicModernResize291:SetWidth(14)
    ZygorClassicModernResize291:SetHeight(14)
    ZygorClassicModernResize291:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-2,2)
    ZygorClassicModernResize291.label=ZygorClassicModernResize291:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    ZygorClassicModernResize291.label:SetAllPoints(ZygorClassicModernResize291)
    ZygorClassicModernResize291.label:SetText("///")
    ZygorClassicModernResize291:RegisterForClicks("LeftButtonUp","RightButtonUp")
    ZygorClassicModernResize291:SetScript("OnMouseDown",function()
        if arg1=="RightButton" then return end
        ZygorClassicModernUserSizing291=true
        frame:StartSizing("BOTTOMRIGHT")
    end)
    ZygorClassicModernResize291:SetScript("OnMouseUp",function()
        frame:StopMovingOrSizing()
        if arg1=="RightButton" then
            ZygorClassic_ResetModernSize291()
        else
            ZygorClassicDB.playerWidth291=frame:GetWidth()
            ZygorClassicDB.playerHeight291=frame:GetHeight()
        end
        ZygorClassicModernUserSizing291=nil
        ZygorClassic_PlayerRender246()
    end)
    frame:SetScript("OnSizeChanged",function()
        if ZygorClassicPlayerGuide246 then ZygorClassicPlayerGuide246:SetWidth((this:GetWidth() or 380)-24) end
        if ZygorClassicModernLastRows291 and not ZygorClassicModernLayoutBusy291 then
            ZygorClassic_RenderModern291(ZygorClassicModernLastRows291,
                ZygorClassicModernLastStep291,ZygorClassicModernLastCount291,ZygorClassicModernLastGuide291)
        end
    end)
    ZygorClassic_PlayerRender246()
end

-- TEST292: mirror the saved pointer state on the compact flat button. Pointer.lua
-- owns the corresponding pre-Show guard that removes disabled-state blinking.
ZygorClassic_UpdateArrowButton287_Base292=ZygorClassic_UpdateArrowButton287
ZygorClassic_UpdateArrowButton287=function()
    if ZygorClassic_UpdateArrowButton287_Base292 then ZygorClassic_UpdateArrowButton287_Base292() end
    if not ZygorClassicModernArrow291 or not ZygorClassicModernArrow291.text then return end
    ZygorClassicDB=ZygorClassicDB or {}
    if ZygorClassicDB.arrowEnabled287==false then
        ZygorClassicModernArrow291.text:SetText("Arrow Off")
        if ZygorClassicModernArrow291.bg then
            ZygorClassicModernArrow291.bg:SetVertexColor(0.28,0.07,0.06,1)
        end
    else
        ZygorClassicModernArrow291.text:SetText("Arrow On")
        if ZygorClassicModernArrow291.bg then
            ZygorClassicModernArrow291.bg:SetVertexColor(0.13,0.14,0.16,0.96)
        end
    end
end
ZygorClassic_UpdateArrowButton287()

-- TEST293: bring the guide chooser into the same compact, flat visual system as
-- the TEST291 player tracker.  This deliberately reuses every proven picker
-- callback; only layout, labels and button presentation change.
function ZygorClassic_SetGuideButtonColor293(button,state)
    if not button or not button.modernBg293 then return end
    button.modernState293=state or button.modernState293 or "normal"
    if button.modernState293=="current" then
        button.modernBg293:SetVertexColor(0.06,0.27,0.15,0.98)
        if button.modernAccent293 then button.modernAccent293:SetVertexColor(0.30,0.92,0.45,1) end
    elseif button.modernState293=="recommended" then
        button.modernBg293:SetVertexColor(0.08,0.18,0.12,0.98)
        if button.modernAccent293 then button.modernAccent293:SetVertexColor(0.28,0.78,0.40,1) end
    elseif button.modernState293=="primary" then
        button.modernBg293:SetVertexColor(0.16,0.30,0.20,0.98)
        if button.modernAccent293 then button.modernAccent293:SetVertexColor(0.35,0.90,0.45,1) end
    elseif button.modernState293=="manual" then
        button.modernBg293:SetVertexColor(0.24,0.17,0.07,0.98)
        if button.modernAccent293 then button.modernAccent293:SetVertexColor(1.00,0.67,0.12,1) end
    else
        button.modernBg293:SetVertexColor(0.10,0.105,0.115,0.98)
        if button.modernAccent293 then button.modernAccent293:SetVertexColor(0.27,0.28,0.31,1) end
    end
end

function ZygorClassic_FlatGuideButton293(button,state,leftAligned)
    if not button then return end
    if button.SetNormalTexture then button:SetNormalTexture("") end
    if button.SetPushedTexture then button:SetPushedTexture("") end
    if button.SetHighlightTexture then button:SetHighlightTexture("") end
    if button.SetDisabledTexture then button:SetDisabledTexture("") end
    if not button.modernBg293 then
        button.modernBg293=button:CreateTexture(nil,"BACKGROUND")
        button.modernBg293:SetAllPoints(button)
        button.modernBg293:SetTexture("Interface\\AddOns\\ZygorGuidesViewer\\Skin\\white")
        button.modernAccent293=button:CreateTexture(nil,"ARTWORK")
        button.modernAccent293:SetTexture("Interface\\AddOns\\ZygorGuidesViewer\\Skin\\white")
        button.modernAccent293:SetPoint("TOPLEFT",button,"TOPLEFT",0,0)
        button.modernAccent293:SetPoint("BOTTOMLEFT",button,"BOTTOMLEFT",0,0)
        button.modernAccent293:SetWidth(3)
        button:SetScript("OnEnter",function()
            if this.modernBg293 then this.modernBg293:SetVertexColor(0.23,0.24,0.27,1) end
        end)
        button:SetScript("OnLeave",function()
            ZygorClassic_SetGuideButtonColor293(this,this.modernState293)
        end)
    end
    button.modernState293=state or "normal"
    ZygorClassic_SetGuideButtonColor293(button,button.modernState293)
    if button.GetFontString then
        local fontString=button:GetFontString()
        if fontString then
            fontString:ClearAllPoints()
            if leftAligned then
                fontString:SetPoint("LEFT",button,"LEFT",11,0)
                fontString:SetPoint("RIGHT",button,"RIGHT",-8,0)
                fontString:SetJustifyH("LEFT")
            else
                fontString:SetPoint("CENTER",button,"CENTER",0,0)
                fontString:SetJustifyH("CENTER")
            end
            fontString:SetFont("Fonts\\FRIZQT__.TTF",12)
        end
    end
end

function ZygorClassic_StyleGuidePicker293()
    if not ZygorClassicGuidePicker247 then return end
    local frame=ZygorClassicGuidePicker247
    frame:SetWidth(430)
    frame:SetHeight(420)
    frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true,tileSize=16,edgeSize=8,
        insets={left=2,right=2,top=2,bottom=2}
    })
    frame:SetBackdropColor(0.015,0.018,0.022,0.97)
    frame:SetBackdropBorderColor(0.16,0.17,0.19,1)

    if ZygorClassicGuidePickerTitle247 then
        ZygorClassicGuidePickerTitle247:ClearAllPoints()
        ZygorClassicGuidePickerTitle247:SetPoint("TOP",frame,"TOP",0,-10)
        ZygorClassicGuidePickerTitle247:SetText("CHOOSE GUIDE")
        ZygorClassicGuidePickerTitle247:SetTextColor(1,1,1)
        ZygorClassicGuidePickerTitle247:SetFont("Fonts\\FRIZQT__.TTF",17)
    end
    if ZygorClassicGuidePickerClose247 then
        ZygorClassicGuidePickerClose247:Hide()
    end
    if not ZygorClassicGuidePickerClose293 then
        ZygorClassicGuidePickerClose293=ZygorClassic_ModernButton291(
            "ZygorClassicGuidePickerClose293",frame,"X",24,
            function() frame:Hide() end)
        ZygorClassicGuidePickerClose293:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-7,-7)
    end
    if ZygorClassicGuidePickerHint247 then
        ZygorClassicGuidePickerHint247:ClearAllPoints()
        ZygorClassicGuidePickerHint247:SetPoint("TOPLEFT",frame,"TOPLEFT",14,-37)
        ZygorClassicGuidePickerHint247:SetWidth(402)
        ZygorClassicGuidePickerHint247:SetTextColor(0.70,0.72,0.75)
    end
    if not ZygorClassicGuidePickerRule293 then
        ZygorClassicGuidePickerRule293=frame:CreateTexture(nil,"ARTWORK")
        ZygorClassicGuidePickerRule293:SetTexture("Interface\\AddOns\\ZygorGuidesViewer\\Skin\\white")
        ZygorClassicGuidePickerRule293:SetVertexColor(0.25,0.26,0.28,1)
        ZygorClassicGuidePickerRule293:SetPoint("TOPLEFT",frame,"TOPLEFT",12,-80)
        ZygorClassicGuidePickerRule293:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-12,-80)
        ZygorClassicGuidePickerRule293:SetHeight(1)
    end

    if ZygorClassicGuideRows247 then
        local choices=ZygorClassic_GuideChoices247 and ZygorClassic_GuideChoices247() or {}
        local recommended=ZygorClassic_RecommendedGuide248 and ZygorClassic_RecommendedGuide248() or nil
        local row
        for row=1,8 do
            local button=ZygorClassicGuideRows247[row]
            if button then
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT",frame,"TOPLEFT",14,-88-(row-1)*31)
                button:SetWidth(402)
                button:SetHeight(27)
                local choice=choices[((ZygorClassicGuidePage247 or 1)-1)*8+row]
                local state="normal"
                if choice and choice.index==(ZygorClassicGuideIndex or 1) then state="current"
                elseif choice and choice.index==recommended then state="recommended" end
                ZygorClassic_FlatGuideButton293(button,state,true)
            end
        end
    end

    if ZygorClassicUseRecommended248 then
        ZygorClassicUseRecommended248:ClearAllPoints()
        ZygorClassicUseRecommended248:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",14,42)
        ZygorClassicUseRecommended248:SetWidth(196)
        ZygorClassicUseRecommended248:SetHeight(25)
        ZygorClassicUseRecommended248:SetText("Use Recommended (Auto)")
        ZygorClassic_FlatGuideButton293(ZygorClassicUseRecommended248,"primary",false)
    end
    if ZygorClassicLockCurrent249 then
        ZygorClassicLockCurrent249:ClearAllPoints()
        ZygorClassicLockCurrent249:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-14,42)
        ZygorClassicLockCurrent249:SetWidth(196)
        ZygorClassicLockCurrent249:SetHeight(25)
        ZygorClassicLockCurrent249:SetText("Keep Current (Manual)")
        ZygorClassic_FlatGuideButton293(ZygorClassicLockCurrent249,"manual",false)
    end
    if ZygorClassicGuidePickerPrev247 then
        ZygorClassicGuidePickerPrev247:ClearAllPoints()
        ZygorClassicGuidePickerPrev247:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",14,12)
        ZygorClassicGuidePickerPrev247:SetWidth(34)
        ZygorClassicGuidePickerPrev247:SetHeight(22)
        ZygorClassicGuidePickerPrev247:SetText("<")
        ZygorClassic_FlatGuideButton293(ZygorClassicGuidePickerPrev247,"normal",false)
    end
    if ZygorClassicGuidePickerNext247 then
        ZygorClassicGuidePickerNext247:ClearAllPoints()
        ZygorClassicGuidePickerNext247:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",52,12)
        ZygorClassicGuidePickerNext247:SetWidth(34)
        ZygorClassicGuidePickerNext247:SetHeight(22)
        ZygorClassicGuidePickerNext247:SetText(">")
        ZygorClassic_FlatGuideButton293(ZygorClassicGuidePickerNext247,"normal",false)
    end
    if ZygorClassicGuidePickerPage247 then
        ZygorClassicGuidePickerPage247:ClearAllPoints()
        ZygorClassicGuidePickerPage247:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",96,17)
        ZygorClassicGuidePickerPage247:SetTextColor(0.70,0.72,0.75)
    end
end

ZygorClassic_RenderGuidePicker247_Base293=ZygorClassic_RenderGuidePicker247
ZygorClassic_RenderGuidePicker247=function()
    if ZygorClassic_RenderGuidePicker247_Base293 then ZygorClassic_RenderGuidePicker247_Base293() end
    ZygorClassic_StyleGuidePicker293()
end
ZygorClassic_StyleGuidePicker293()

-- TEST310: infer an exact live quest ID from its leaderboard objective names.
-- Vanilla's quest-log API omits IDs, and several chains reuse one title for
-- every part.  The bundled quest database preserves each part's item/mob/object
-- objectives, providing a deterministic fingerprint without server commands.
function ZygorClassic_ObjectiveName310(text)
    text=string.lower(tostring(text or ""))
    text=string.gsub(text,"^%s+","")
    text=string.gsub(text,"%s*:%s*%d+%s*/%s*%d+.*$","")
    text=string.gsub(text,"%s+slain$","")
    text=string.gsub(text,"%s+$","")
    return text
end

function ZygorClassic_QuestTitleIndex310()
    if ZygorClassicQuestTitleIndexCache310 then return ZygorClassicQuestTitleIndexCache310 end
    local result={}
    local id,quest
    for id,quest in pairs((ZygorClassicQuestDB and ZygorClassicQuestDB.q) or {}) do
        local key=ZygorClassic_NormalizeQuestTitle170(quest.n)
        result[key]=result[key] or {}
        table.insert(result[key],tonumber(id))
    end
    ZygorClassicQuestTitleIndexCache310=result
    return result
end

function ZygorClassic_QuestObjectiveNames310(questID)
    local db=ZygorClassicQuestDB or {}
    local quest=db.q and db.q[tonumber(questID)]
    local result={}
    if not quest then return result end
    local groups={{quest.i,db.i},{quest.u,db.u},{quest.o,db.o}}
    local groupIndex,itemIndex
    for groupIndex=1,table.getn(groups) do
        local ids,records=groups[groupIndex][1] or {},groups[groupIndex][2] or {}
        for itemIndex=1,table.getn(ids) do
            local record=records[tonumber(ids[itemIndex])]
            if record and record.n then
                result[ZygorClassic_ObjectiveName310(record.n)]=true
            end
        end
    end
    return result
end

function ZygorClassic_InferLiveQuestID310(title,questLogIndex)
    local candidates=ZygorClassic_QuestTitleIndex310()[ZygorClassic_NormalizeQuestTitle170(title)] or {}
    if table.getn(candidates)==1 then return candidates[1] end
    local live={}
    local count=GetNumQuestLeaderBoards and (GetNumQuestLeaderBoards(questLogIndex) or 0) or 0
    local i
    for i=1,count do
        local text=GetQuestLogLeaderBoard(i,questLogIndex)
        local key=ZygorClassic_ObjectiveName310(text)
        if key~="" then live[key]=true end
    end
    local best,bestScore,tied=nil,0,false
    for i=1,table.getn(candidates) do
        local id=candidates[i]
        local expected=ZygorClassic_QuestObjectiveNames310(id)
        local score=0
        local key
        for key in pairs(live) do if expected[key] then score=score+1 end end
        if score>bestScore then best,bestScore,tied=id,score,false
        elseif score>0 and score==bestScore then tied=true end
    end
    if bestScore>0 and not tied then return best end
    return nil
end

function ZygorClassic_LiveDescendantProof310(quests,title,questID)
    questID=tonumber(questID)
    if not quests or not title or not questID then return false end
    local live=quests[ZygorClassic_NormalizeQuestTitle170(title)]
    if live and tonumber(live.questID) and tonumber(live.questID)>questID then
        if ZygorClassic_RecordQuestIDTurnin216 then ZygorClassic_RecordQuestIDTurnin216(questID) end
        return true
    end
    return false
end

ZYGOR_BACKPORT_VERSION = "TEST322"

-- TEST301: the old Human step 138 used the post-Vanilla Stormwind Harbor.
-- Migrate saved positions once after the guide gains the real Vanilla travel
-- steps through Ironforge, Dun Algaz and Menethil Harbor, plus the return path.
if not ZygorClassicBoatMigration301 then
    ZygorClassicBoatMigration301=CreateFrame("Frame","ZygorClassicBoatMigration301",UIParent)
    ZygorClassicBoatMigration301.elapsed=0
    ZygorClassicBoatMigration301:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.5 then return end
        this.elapsed=0
        local key=ZygorClassic_Key62 and ZygorClassic_Key62() or nil
        local state=key and ZygorClassicDB and ZygorClassicDB.engine172 and ZygorClassicDB.engine172[key]
        local guides=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides
        local guide=state and guides and guides[tonumber(state.guide) or 0]
        if not state or not guide then return end
        if not state.vanillaBoatRoute301 then
            local title=tostring(guide.title or "")
            if string.find(title,"Human (1-13)",1,true) then
                local oldStep=tonumber(state.step) or 1
                if oldStep==139 then
                    local zone=GetRealZoneText and GetRealZoneText() or ""
                    state.step=(zone=="Darkshore") and 148 or 138
                elseif oldStep>161 then
                    state.step=oldStep+11
                elseif oldStep>139 then
                    state.step=oldStep+9
                end
                if tonumber(state.step) then
                    ZygorClassicStepIndex=tonumber(state.step)
                    if ZygorClassicDB.smart51 and ZygorClassicDB.smart51[key] then
                        ZygorClassicDB.smart51[key].step=tonumber(state.step)
                    end
                end
            end
            state.vanillaBoatRoute301=true
        end
        this:SetScript("OnUpdate",nil)
        if ZygorClassic_PlayerRender246 then ZygorClassic_PlayerRender246() end
        if ZygorClassic_Render then ZygorClassic_Render() end
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    end)
end

-- TEST323: a level bracket is only a recommendation for a character without
-- authoritative progress.  TEST297 inspected the obsolete native
-- CurrentGuide.steps table; backported guides use engine172 plus
-- registeredguides[].classic_steps, so its hold could silently fall through on
-- PLAYER_LEVEL_UP and replace an unfinished 1-13 route with Main Guide (13-20).
-- The state machine's explicit classic_next handoff remains the sole automatic
-- way to leave a valid saved guide.
function ZygorClassic_AutoGuideHold323()
    local key=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
    local state=ZygorClassicDB and ZygorClassicDB.engine172 and
                ZygorClassicDB.engine172[key]
    local guides=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides
    local guide=state and guides and guides[tonumber(state.guide) or 0]
    if not state or not guide or not ZygorClassic_EnsureParsed(guide) then
        return false
    end

    -- Project authoritative state back immediately.  This closes the brief
    -- level-up window before the regular TEST289 reconciliation tick.
    ZygorClassicGuideIndex=tonumber(state.guide) or ZygorClassicGuideIndex
    ZygorClassicStepIndex=tonumber(state.step) or ZygorClassicStepIndex or 1
    if ZygorClassicDebug82 then
        ZygorClassicDebug82.event="AUTO HOLD: saved guide owns bracket boundary"
    end
    return true
end

function ZygorClassic_ApplyRecommendation248()
    if ZygorClassic_GuideMode248()~="AUTO" then return end
    if ZygorClassic_AutoGuideHold323() then return end
    local recommended=ZygorClassic_RecommendedGuide248()
    if recommended and recommended~=(ZygorClassicGuideIndex or 1) then
        ZygorClassic_SelectGuide247(recommended,true)
    end
end

-- Repair the exact bad save written by the former level-up selector.  This is
-- deliberately narrow: level 13, Main Guide step 1/2, and concrete bootstrap
-- evidence inside the character's own unfinished 1-13 guide.
function ZygorClassic_RepairBoundary323()
    local key=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
    ZygorClassicDB=ZygorClassicDB or {}
    ZygorClassicDB.boundaryRepair323=ZygorClassicDB.boundaryRepair323 or {}
    if ZygorClassicDB.boundaryRepair323[key] then return true end

    local state=ZygorClassicDB.engine172 and ZygorClassicDB.engine172[key]
    local guides=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides
    local current=state and guides and guides[tonumber(state.guide) or 0]
    if not state or not current or table.getn(guides or {})<1 then return false end

    local level=UnitLevel("player") or 1
    local currentTitle=tostring(current.title or "")
    if level~=13 or (tonumber(state.step) or 1)>2 or
       not string.find(currentTitle,"Main Guide (13-20)",1,true) then
        ZygorClassicDB.boundaryRepair323[key]=true
        return true
    end

    local faction=ZygorClassic_Faction262() or ""
    local race=UnitRace("player") or ""
    local wanted="Zygor's "..faction.." Leveling Guides\\"..race.." (1-13)"
    local startIndex,startGuide=ZygorClassic_FindGuideByTitle242(wanted)
    if not startIndex or not startGuide or not ZygorClassic_EnsureParsed(startGuide) then
        return false
    end
    local quests=ZygorClassic_QuestLog172 and ZygorClassic_QuestLog172() or {}
    local target=ZygorClassic_Bootstrap172(startGuide,quests)
    local total=table.getn(startGuide.classic_steps or {})
    if not target or target<=1 or target>=total then return false end

    state.guide=startIndex
    state.step=target
    state.recoveryFloor218=target
    state.missingSince191={}
    ZygorClassicGuideIndex=startIndex
    ZygorClassicStepIndex=target
    local char=ZygorClassic_CharDB and ZygorClassic_CharDB()
    if char then char.guide=startIndex; char.step=target end
    ZygorClassicDB.smart51=ZygorClassicDB.smart51 or {}
    ZygorClassicDB.smart51[key]={guide=startIndex,step=target}
    ZygorClassicDB.boundaryRepair323[key]=true
    if ZygorClassicDebug82 then
        ZygorClassicDebug82.route="G Main S1 -> G"..tostring(startIndex)..
            " S"..tostring(target).." (TEST323 level-only handoff repair)"
        ZygorClassicDebug82.event="RESTORED unfinished "..race.." 1-13 guide"
    end
    if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
    if ZygorClassic_SaveProgress then ZygorClassic_SaveProgress() end
    if ZygorClassic_PlayerRender246 then ZygorClassic_PlayerRender246() end
    if ZygorClassic_Render then ZygorClassic_Render() end
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    return true
end

if not ZygorClassicBoundaryRepairFrame323 then
    ZygorClassicBoundaryRepairFrame323=CreateFrame("Frame","ZygorClassicBoundaryRepairFrame323",UIParent)
    ZygorClassicBoundaryRepairFrame323.elapsed=0
    ZygorClassicBoundaryRepairFrame323.attempts=0
    ZygorClassicBoundaryRepairFrame323:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<1 then return end
        this.elapsed=0
        this.attempts=(this.attempts or 0)+1
        if ZygorClassic_RepairBoundary323() or this.attempts>=12 then
            this:SetScript("OnUpdate",nil)
        end
    end)
end

ZYGOR_BACKPORT_VERSION = "TEST323"

-- TEST324: TEST323 correctly restored the race guide, but its generic
-- bootstrap selected the earliest unfinished side quest.  Recover forward from
-- that temporary checkpoint using stronger world-position evidence: the first
-- later step whose authored zone is the zone the player has already reached.
-- A hard floor then prevents lingering optional objectives from dragging AUTO
-- back behind that proven location.
function ZygorClassic_ZoneProgressRepair324()
    local key=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
    ZygorClassicDB=ZygorClassicDB or {}
    ZygorClassicDB.boundaryRepair324=ZygorClassicDB.boundaryRepair324 or {}
    if ZygorClassicDB.boundaryRepair324[key] then return true end
    local state=ZygorClassicDB.engine172 and ZygorClassicDB.engine172[key]
    local guides=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides
    local guide=state and guides and guides[tonumber(state.guide) or 0]
    if not state or not guide or not ZygorClassic_EnsureParsed(guide) then return false end

    local title=tostring(guide.title or "")
    local race=UnitRace("player") or ""
    if not ZygorClassicDB.boundaryRepair323 or not ZygorClassicDB.boundaryRepair323[key] or
       (UnitLevel("player") or 1)~=13 or
       not string.find(title,"\\"..race.." (1-13)",1,true) then
        ZygorClassicDB.boundaryRepair324[key]=true
        return true
    end

    local from=tonumber(state.step) or 1
    local confirmed=ZygorClassic_ConfirmedTurninStep244 and
                    ZygorClassic_ConfirmedTurninStep244(guide) or nil
    if confirmed then
        local after=ZygorClassic_NextStep172(guide,confirmed)
        if after and after>from then from=after end
    end
    local target=nil
    local i
    for i=from,table.getn(guide.classic_steps or {}) do
        if ZygorClassic_TravelZoneArrived244(guide.classic_steps[i]) then
            target=i
            break
        end
    end
    ZygorClassicDB.boundaryRepair324[key]=true
    if not target or target<=(tonumber(state.step) or 1) then return true end

    state.step=target
    state.recoveryFloor218=target
    state.hardFloor324=target
    state.missingSince191={}
    ZygorClassicStepIndex=target
    local char=ZygorClassic_CharDB and ZygorClassic_CharDB()
    if char then char.guide=state.guide; char.step=target end
    ZygorClassicDB.smart51=ZygorClassicDB.smart51 or {}
    ZygorClassicDB.smart51[key]={guide=state.guide,step=target}
    if ZygorClassicDebug82 then
        ZygorClassicDebug82.route="TEST323 checkpoint -> S"..tostring(target)..
            " (TEST324 current-zone progress proof)"
        ZygorClassicDebug82.event="RESTORED furthest proven route position"
    end
    if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
    if ZygorClassic_SaveProgress then ZygorClassic_SaveProgress() end
    if ZygorClassic_PlayerRender246 then ZygorClassic_PlayerRender246() end
    if ZygorClassic_Render then ZygorClassic_Render() end
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    return true
end

if not ZygorClassicZoneProgressFrame324 then
    ZygorClassicZoneProgressFrame324=CreateFrame("Frame","ZygorClassicZoneProgressFrame324",UIParent)
    ZygorClassicZoneProgressFrame324.elapsed=0
    ZygorClassicZoneProgressFrame324.attempts=0
    ZygorClassicZoneProgressFrame324:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<1 then return end
        this.elapsed=0
        this.attempts=(this.attempts or 0)+1
        if ZygorClassic_ZoneProgressRepair324() or this.attempts>=12 then
            this:SetScript("OnUpdate",nil)
        end
    end)
end

-- Direct step entry keeps normal AUTO tracking after the jump.  The typed step
-- becomes the new hard floor, while deliberately typing an earlier number also
-- lowers that floor so the player remains in control.
function ZygorClassic_JumpToStep324(value)
    local target=tonumber(value)
    local guideIndex,stepIndex,state=ZygorClassic_AuthoritativePosition289()
    local guides=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides
    local guide=guides and guides[guideIndex]
    if not target or not state or not guide or not ZygorClassic_EnsureParsed(guide) then return false end
    local count=table.getn(guide.classic_steps or {})
    target=math.floor(target)
    if target<1 then target=1 end
    if target>count then target=count end
    state.step=target
    state.recoveryFloor218=target
    state.hardFloor324=target
    state.missingSince191={}
    ZygorClassicStepIndex=target
    ZygorClassicDB.engine172[ZygorClassic_Key62()]=state
    if ZygorClassicDebug82 then
        ZygorClassicDebug82.route=tostring(stepIndex).." -> "..tostring(target).." (typed step)"
        ZygorClassicDebug82.event="PLAYER ENTERED STEP "..tostring(target)
    end
    if ZygorClassic_SaveStep90 then ZygorClassic_SaveStep90() end
    if ZygorClassic_SaveProgress then ZygorClassic_SaveProgress() end
    if ZygorClassic_PlayerRender246 then ZygorClassic_PlayerRender246() end
    if ZygorClassic_Render then ZygorClassic_Render() end
    if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    return true
end

function ZygorClassic_CreateStepInput324()
    if ZygorClassicModernStepInput324 or not ZygorClassicPlayerFrame246 then return end
    local frame=ZygorClassicPlayerFrame246
    local input=CreateFrame("EditBox","ZygorClassicModernStepInput324",frame,"InputBoxTemplate")
    input:SetWidth(44)
    input:SetHeight(24)
    input:SetAutoFocus(false)
    if input.SetNumeric then input:SetNumeric(true) end
    input:SetJustifyH("CENTER")
    input:SetScript("OnEditFocusGained",function()
        ZygorClassicStepEditing324=true
        this:HighlightText()
    end)
    input:SetScript("OnEditFocusLost",function() ZygorClassicStepEditing324=nil end)
    input:SetScript("OnEnterPressed",function()
        local value=this:GetText()
        this:ClearFocus()
        ZygorClassic_JumpToStep324(value)
    end)
    input:SetScript("OnEscapePressed",function()
        this:ClearFocus()
        if ZygorClassic_PlayerRender246 then ZygorClassic_PlayerRender246() end
    end)
    ZygorClassicModernStepInput324=input
    ZygorClassicModernStepTotal324=frame:CreateFontString(
        "ZygorClassicModernStepTotal324","OVERLAY","GameFontHighlight")
    ZygorClassicModernStepTotal324:SetJustifyH("LEFT")
end

ZygorClassic_CreateStepInput324()
ZygorClassic_RenderModern291_Base324=ZygorClassic_RenderModern291
ZygorClassic_RenderModern291=function(rows,stepIndex,stepCount,shortTitle)
    if ZygorClassic_RenderModern291_Base324 then
        ZygorClassic_RenderModern291_Base324(rows,stepIndex,stepCount,shortTitle)
    end
    ZygorClassic_CreateStepInput324()
    local frame=ZygorClassicPlayerFrame246
    local input=ZygorClassicModernStepInput324
    local total=ZygorClassicModernStepTotal324
    if not frame or not input or not total then return end
    local width=frame:GetWidth() or 380
    local headerFont=ZygorClassic_ModernFont301(14,width,12,22)
    local guideFont=ZygorClassic_ModernFont301(12,width,10,18)
    local titleFont=ZygorClassic_ModernFont301(22,width,18,32)
    local guideTop=8+titleFont+8
    local controlsTop=guideTop+guideFont+7
    local controlHeight=math.max(24,headerFont+9)
    if ZygorClassicPlayerMeta246 then ZygorClassicPlayerMeta246:Hide() end
    input:ClearAllPoints()
    input:SetPoint("TOPLEFT",frame,"TOPLEFT",52,-controlsTop)
    input:SetHeight(controlHeight)
    input:SetFont("Fonts\\FRIZQT__.TTF",headerFont)
    if not ZygorClassicStepEditing324 then input:SetText(tostring(stepIndex or 1)) end
    total:ClearAllPoints()
    total:SetPoint("LEFT",input,"RIGHT",4,0)
    total:SetFont("Fonts\\FRIZQT__.TTF",headerFont)
    total:SetText("/ "..tostring(stepCount or 0))
    input:Show()
    total:Show()
end

ZYGOR_BACKPORT_VERSION = "TEST324"

-- TEST325: restore the authored Ban'ethil quest-chain order after TEST317's
-- over-specific workaround.  Exact quest-objective state remains authoritative;
-- the guide data now supplies floor, bridge, and tunnel directions without
-- changing saved step numbers or weakening the generic rewind safeguards.
ZYGOR_BACKPORT_VERSION = "TEST325"

-- TEST326: resolve stationary guide NPCs from a conservative Vanilla database
-- instead of blindly trusting every authored `goto`.  The generated table
-- contains only NPC IDs for which pfQuest and Questie agree on one fixed point.
-- Roaming, duplicated, cross-zone, and otherwise ambiguous NPCs are omitted,
-- so those steps continue to use their authored approach waypoint.
function ZygorClassic_MapEqual326(left,right)
    left=string.lower(tostring(left or ""))
    right=string.lower(tostring(right or ""))
    left=string.gsub(left,"^%s+","")
    left=string.gsub(left,"%s+$","")
    right=string.gsub(right,"^%s+","")
    right=string.gsub(right,"%s+$","")
    return left~="" and left==right
end

function ZygorClassic_TalkGroupPending326(step,first,last,quests)
    local lines=step and (step.source or step.raw) or {}
    local directives=0
    local index
    for index=(first or 1)+1,(last or table.getn(lines)) do
        local line=lines[index]
        local clean=ZygorClassic_CleanDirective62 and
                    ZygorClassic_CleanDirective62(line) or tostring(line or "")
        local title,kind=nil,nil
        if ZygorClassic_ParseQuestDirective then
            title,kind=ZygorClassic_ParseQuestDirective(clean)
        end
        if title and kind then
            directives=directives+1
            local display,state=nil,"pending"
            if ZygorClassic_PlayerAction246 then
                display,state=ZygorClassic_PlayerAction246(line,step,quests)
            end
            if state~="done" then return true end
        end
    end
    -- Non-quest NPC instructions (train, bind, repair, or learn a flight path)
    -- still need the fixed NPC position. If a step has several such NPCs, the
    -- first one remains authoritative just as it was in the authored guide.
    return directives==0
end

function ZygorClassic_CurrentTalkGoto326()
    if not ZygorClassicTalkWaypointDB or not ZygorGuidesViewer or
       not ZygorGuidesViewer.registeredguides then return nil end
    local guide=ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return nil end
    local step=guide.classic_steps and guide.classic_steps[ZygorClassicStepIndex or 1]
    local lines=step and (step.source or step.raw) or {}
    if table.getn(lines)<1 then return nil end
    local quests=ZygorClassic_QuestLog172 and ZygorClassic_QuestLog172() or {}
    local current=GetRealZoneText and GetRealZoneText() or
                  (GetZoneText and GetZoneText()) or ""
    local talkIndexes={}
    local talkIDs={}
    local index
    for index=1,table.getn(lines) do
        local line=tostring(lines[index] or "")
        line=string.gsub(line,"^%s+","")
        local startPos,endPos,id=string.find(line,"^%.talk%s+.-##(%d+)")
        if id then
            table.insert(talkIndexes,index)
            table.insert(talkIDs,tonumber(id))
        end
    end
    for index=1,table.getn(talkIndexes) do
        local finish=(talkIndexes[index+1] or (table.getn(lines)+1))-1
        if ZygorClassic_TalkGroupPending326(step,talkIndexes[index],finish,quests) then
            local npc=ZygorClassicTalkWaypointDB[talkIDs[index]]
            if npc and ZygorClassic_MapEqual326(current,npc.map) then
                return npc.map,npc.x,npc.y,"Talk to "..tostring(npc.name or "NPC")
            end
            -- The first unresolved NPC is authoritative. Never skip it to aim
            -- at a later NPC merely because that later entry has database data.
            return nil
        end
    end
    return nil
end

ZygorClassic_CurrentGoto55_Base326=ZygorClassic_CurrentGoto55
ZygorClassic_CurrentGoto55=function()
    local map,x,y,label=ZygorClassic_CurrentTalkGoto326()
    if x and y then return map,x,y,label end
    if ZygorClassic_CurrentGoto55_Base326 then
        return ZygorClassic_CurrentGoto55_Base326()
    end
    return nil
end

ZYGOR_BACKPORT_VERSION = "TEST326"

-- TEST327: separate the authoritative live step readout from the direct-jump
-- editor.  TEST324 made the current number itself editable, which meant an
-- empty edit box could hide the guide's real position even though the engine
-- continued normally.  The header now always says "Step N / Total" while a
-- clearly labelled, normally empty "Go:" box remains available for jumps.
function ZygorClassic_EnsureStepHeader327()
    if not ZygorClassicPlayerFrame246 or not ZygorClassicModernStepInput324 then return end
    local frame=ZygorClassicPlayerFrame246
    if not ZygorClassicModernStepGoLabel327 then
        ZygorClassicModernStepGoLabel327=frame:CreateFontString(
            "ZygorClassicModernStepGoLabel327","OVERLAY","GameFontHighlight")
        ZygorClassicModernStepGoLabel327:SetJustifyH("LEFT")
        ZygorClassicModernStepGoLabel327:SetText("Go:")
    end
    local input=ZygorClassicModernStepInput324
    input:SetScript("OnEditFocusGained",function()
        ZygorClassicStepEditing324=true
        this:HighlightText()
    end)
    input:SetScript("OnEditFocusLost",function()
        ZygorClassicStepEditing324=nil
        this:SetText("")
    end)
    input:SetScript("OnEnterPressed",function()
        local value=this:GetText()
        ZygorClassic_JumpToStep324(value)
        this:SetText("")
        this:ClearFocus()
        if ZygorClassic_PlayerRender246 then ZygorClassic_PlayerRender246() end
    end)
    input:SetScript("OnEscapePressed",function()
        this:SetText("")
        this:ClearFocus()
        if ZygorClassic_PlayerRender246 then ZygorClassic_PlayerRender246() end
    end)
end

ZygorClassic_EnsureStepHeader327()
ZygorClassic_RenderModern291_Base327=ZygorClassic_RenderModern291
ZygorClassic_RenderModern291=function(rows,stepIndex,stepCount,shortTitle)
    if ZygorClassic_RenderModern291_Base327 then
        ZygorClassic_RenderModern291_Base327(rows,stepIndex,stepCount,shortTitle)
    end
    ZygorClassic_EnsureStepHeader327()
    local frame=ZygorClassicPlayerFrame246
    local live=ZygorClassicPlayerMeta246
    local previous=ZygorClassicModernPrev291
    local following=ZygorClassicModernNext291
    local input=ZygorClassicModernStepInput324
    local oldTotal=ZygorClassicModernStepTotal324
    local goLabel=ZygorClassicModernStepGoLabel327
    if not frame or not live or not input or not goLabel then return end
    local width=frame:GetWidth() or 380
    local headerFont=ZygorClassic_ModernFont301(14,width,12,22)
    local guideFont=ZygorClassic_ModernFont301(12,width,10,18)
    local titleFont=ZygorClassic_ModernFont301(22,width,18,32)
    local controlsTop=8+titleFont+8+guideFont+7
    local controlHeight=math.max(24,headerFont+9)
    local liveWidth=math.max(94,math.min(154,headerFont*7.4))
    local nextX=52+liveWidth+4
    local goX=nextX+38
    local inputWidth=math.max(38,math.min(56,headerFont*3.2))

    live:ClearAllPoints()
    live:SetPoint("TOPLEFT",frame,"TOPLEFT",52,-controlsTop-4)
    live:SetWidth(liveWidth)
    live:SetFont("Fonts\\FRIZQT__.TTF",headerFont)
    live:SetText("Step |cffffffff"..tostring(stepIndex or 1).."|r / "..tostring(stepCount or 0))
    live:Show()

    if previous then
        previous:ClearAllPoints()
        previous:SetPoint("TOPLEFT",frame,"TOPLEFT",12,-controlsTop)
        previous:SetHeight(controlHeight)
    end
    if following then
        following:ClearAllPoints()
        following:SetPoint("TOPLEFT",frame,"TOPLEFT",nextX,-controlsTop)
        following:SetHeight(controlHeight)
    end

    goLabel:ClearAllPoints()
    goLabel:SetPoint("TOPLEFT",frame,"TOPLEFT",goX,-controlsTop-4)
    goLabel:SetFont("Fonts\\FRIZQT__.TTF",headerFont)
    goLabel:SetText("Go:")
    goLabel:Show()
    input:ClearAllPoints()
    input:SetPoint("LEFT",goLabel,"RIGHT",4,0)
    input:SetWidth(inputWidth)
    input:SetHeight(controlHeight)
    input:SetFont("Fonts\\FRIZQT__.TTF",headerFont)
    if not ZygorClassicStepEditing324 then input:SetText("") end
    input:Show()
    if oldTotal then oldTotal:Hide() end
end

ZYGOR_BACKPORT_VERSION = "TEST327"

-- TEST328: Vanilla may identify a hearth bind by the inn/building rather than
-- the settlement used by the guide, and some 1.12 servers do not dispatch the
-- HEARTHSTONE_BOUND event reliably.  Kharanos is reported as Thunderbrew
-- Distillery.  In addition to that canonical alias, watch GetBindLocation for
-- an actual change while an applicable `home` step is current and preserve a
-- step-scoped witness.  This makes bind completion generic without completing
-- a home instruction merely because the player reached its waypoint.
function ZygorClassic_CurrentHomeTarget328()
    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return nil end
    local step=guide.classic_steps and guide.classic_steps[ZygorClassicStepIndex or 1]
    if not step then return nil end
    local lines=step.source or step.raw or {}
    local i
    for i=1,table.getn(lines) do
        local line=ZygorClassic_CleanDirective62 and
                   ZygorClassic_CleanDirective62(lines[i]) or tostring(lines[i] or "")
        line=string.lower(tostring(line or ""))
        local startPos,endPos,target=string.find(line,"^home%s+(.+)")
        if target then
            target=string.gsub(target,"|.*$","")
            target=string.gsub(target,"^%s+","")
            target=string.gsub(target,"%s+$","")
            return target
        end
    end
    return nil
end

function ZygorClassic_RecordHomeWitness328(target,bound)
    if not target or target=="" then return end
    ZygorClassicDB=ZygorClassicDB or {}
    ZygorClassicDB.homeWitness203=ZygorClassicDB.homeWitness203 or {}
    local charKey=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
    local stepKey=tostring(ZygorClassicGuideIndex or 1)..":"..
                  tostring(ZygorClassicStepIndex or 1)
    ZygorClassicDB.homeWitness203[charKey]=ZygorClassicDB.homeWitness203[charKey] or {}
    ZygorClassicDB.homeWitness203[charKey][stepKey]=target
    if ZygorClassicManualLock194 then ZygorClassicManualLock194[charKey]=nil end
    if ZygorClassicDebug82 then
        ZygorClassicDebug82.event="BIND CHANGED: "..tostring(bound).." -> "..tostring(target)
    end
end

if not ZygorClassicHomePoll328 then
    ZygorClassicHomePoll328=CreateFrame("Frame","ZygorClassicHomePoll328",UIParent)
    ZygorClassicHomePoll328.elapsed=0
    ZygorClassicHomePoll328.lastBind=GetBindLocation and GetBindLocation() or ""
    ZygorClassicHomePoll328:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.20 then return end
        this.elapsed=0
        local bound=GetBindLocation and GetBindLocation() or ""
        if bound~="" and this.lastBind~="" and bound~=this.lastBind then
            local target=ZygorClassic_CurrentHomeTarget328()
            if target then ZygorClassic_RecordHomeWitness328(target,bound) end
        end
        this.lastBind=bound
    end)
end

ZYGOR_BACKPORT_VERSION = "TEST328"

-- TEST329: inventory-backed `buy N Item` completion for Vanilla guide steps.
ZygorClassic_StepObjectiveLinesBefore329=ZygorClassic_StepObjectiveLines87
ZygorClassic_StepObjectiveLines87=function(step)
    local results=ZygorClassic_StepObjectiveLinesBefore329 and
                  ZygorClassic_StepObjectiveLinesBefore329(step) or {}
    local lines=step and (step.source or step.raw) or {}
    local i
    for i=1,table.getn(lines) do
        local line=ZygorClassic_CleanDirective62 and
                   ZygorClassic_CleanDirective62(lines[i]) or tostring(lines[i] or "")
        local startPos,endPos,required,itemName=
            string.find(line,"^buy%s+(%d+)%s+([^|]+)")
        if required and itemName then
            local explicitID=string.match(itemName,"##(%d+)")
            itemName=string.gsub(itemName,"##%d+","")
            itemName=string.gsub(itemName,"^%s+","")
            itemName=string.gsub(itemName,"%s+$","")
            local have=ZygorClassic_BuyItemCount329(itemName,explicitID)
            table.insert(results,{
                line="buy "..tostring(required).." "..itemName,
                title=nil,
                text=itemName..": "..tostring(have).."/"..tostring(required),
                done=(have>=tonumber(required))
            })
        end
    end
    return results
end

ZYGOR_BACKPORT_VERSION = "TEST329"

-- TEST330: keep TEST329's purchase helpers out of Compat_112.lua's shared
-- local namespace.  Vanilla Lua 5.1 limits a chunk to 200 active locals.
ZYGOR_BACKPORT_VERSION = "TEST330"

-- TEST331: staged approaches for vertically separated NPCs.
ZYGOR_BACKPORT_VERSION = "TEST331"

-- TEST332: some later Alliance and class guides still describe the Wrath-era
-- Stormwind Harbor boat to Auberdine.  Rewriting every occurrence as many new
-- guide steps would invalidate existing saved step numbers.  Instead, detect
-- the shared travel instruction and give every affected guide the real
-- Vanilla route as a staged pointer overlay:
--   Deeprun Tram -> Ironforge -> Dun Morogh -> Loch Modan -> Wetlands -> dock.
-- Azuremyst/Teldrassil departures are intentionally not included; their boats
-- and flights to Auberdine are valid and retain the authored route.
ZygorClassicAuberdineRoute332={
    ["stormwind city"]={
        {69.0,30.9,"Enter the Deeprun Tram station"},
    },
    ["ironforge"]={
        {15.0,87.0,"Leave Ironforge for Dun Morogh"},
    },
    ["dun morogh"]={
        {68.7,56.0,"Follow the eastern road through Dun Morogh"},
        {78.1,50.4,"Continue east past Gol'Bolar Quarry"},
        {87.4,51.1,"Use the South Gate Pass to Loch Modan"},
    },
    ["loch modan"]={
        {22.4,68.2,"Follow the road north from South Gate Pass"},
        {25.6,45.4,"Keep north past Thelsamar"},
        {24.8,22.1,"Continue north toward Dun Algaz"},
        {25.4,10.4,"Enter the northern Dun Algaz tunnels"},
    },
    ["wetlands"]={
        {49.7,79.5,"Go through the first Dun Algaz tunnels"},
        {53.9,70.3,"Finish crossing Dun Algaz"},
        {49.9,57.2,"Follow the road northwest"},
        {33.5,49.6,"Continue west through the Wetlands"},
        {18.5,51.2,"Follow the western road to Menethil Harbor"},
        {9.5,59.7,"Learn the Menethil Harbor flight path"},
        {4.6,57.2,"Go to the Auberdine boat dock"},
    },
}

function ZygorClassic_IsAuberdineTravel332()
    local guide=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides and
                ZygorGuidesViewer.registeredguides[ZygorClassicGuideIndex or 1]
    if not guide or not ZygorClassic_EnsureParsed(guide) then return false end
    local step=guide.classic_steps and guide.classic_steps[ZygorClassicStepIndex or 1]
    local lines=step and (step.source or step.raw) or {}
    local sawBoat=false
    local sawAuberdine=false
    local sawDarkshore=false
    local i
    for i=1,table.getn(lines) do
        local line=string.lower(tostring(lines[i] or ""))
        if string.find(line,"boat",1,true) or string.find(line,"ship",1,true) then
            sawBoat=true
        end
        if string.find(line,"auberdine",1,true) then sawAuberdine=true end
        if string.find(line,"goto darkshore",1,true) then sawDarkshore=true end
    end
    return sawBoat and sawAuberdine and sawDarkshore
end

function ZygorClassic_AuberdineRouteTarget332()
    if not ZygorClassic_IsAuberdineTravel332() then return nil end
    local current=GetRealZoneText and GetRealZoneText() or
                  (GetZoneText and GetZoneText()) or ""
    local zoneKey=string.lower(tostring(current or ""))
    local route=ZygorClassicAuberdineRoute332[zoneKey]
    if not route or table.getn(route)<1 then return nil end

    local px,py=GetPlayerMapPosition("player")
    px=(tonumber(px) or 0)*100
    py=(tonumber(py) or 0)*100
    ZygorClassicDB=ZygorClassicDB or {}
    ZygorClassicDB.travelRoute332=ZygorClassicDB.travelRoute332 or {}
    local character=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
    local stateKey=tostring(character)..":"..tostring(ZygorClassicGuideIndex or 1)..
                   ":"..tostring(ZygorClassicStepIndex or 1)
    local state=ZygorClassicDB.travelRoute332[stateKey]
    if not state or state.zone~=zoneKey then
        state={zone=zoneKey,index=1}
        -- A reload or reinstall may occur halfway across a zone. Start at the
        -- nearest authored road node rather than sending the player backward
        -- to the beginning of that zone's route.
        if px>0 and py>0 then
            local bestDistance=nil
            local i
            for i=1,table.getn(route) do
                local dx=px-route[i][1]
                local dy=py-route[i][2]
                local distance=(dx*dx+dy*dy)^0.5
                if not bestDistance or distance<bestDistance then
                    bestDistance=distance
                    state.index=i
                end
            end
        end
        ZygorClassicDB.travelRoute332[stateKey]=state
    end

    local index=math.max(1,math.min(table.getn(route),tonumber(state.index) or 1))
    local node=route[index]
    if px>0 and py>0 and index<table.getn(route) then
        local dx=px-node[1]
        local dy=py-node[2]
        if (dx*dx+dy*dy)^0.5<=4.5 then
            index=index+1
            state.index=index
            node=route[index]
        end
    end
    return current,node[1],node[2],node[3]
end

ZygorClassic_CurrentGoto55_Base332=ZygorClassic_CurrentGoto55
ZygorClassic_CurrentGoto55=function()
    local map,x,y,label=ZygorClassic_AuberdineRouteTarget332()
    if x and y then return map,x,y,label end
    if ZygorClassic_CurrentGoto55_Base332 then
        return ZygorClassic_CurrentGoto55_Base332()
    end
    return nil
end

ZYGOR_BACKPORT_VERSION = "TEST332"

-- TEST333: the Gnome 1-13 guide incorrectly used the post-Vanilla
-- Auberdine-to-Stormwind Harbor route.  In 1.12 the ship lands at Menethil;
-- continue by flight to Ironforge and the Deeprun Tram.  Preserve an active
-- TEST332 save at displayed step 165 in Wetlands so it resumes at the new
-- Menethil flight step.  Saves already beyond the crossing move by the two
-- newly inserted travel steps.
if not ZygorClassicGnomeBoatMigration333 then
    ZygorClassicGnomeBoatMigration333=CreateFrame("Frame","ZygorClassicGnomeBoatMigration333",UIParent)
    ZygorClassicGnomeBoatMigration333.elapsed=0
    ZygorClassicGnomeBoatMigration333:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.5 then return end
        this.elapsed=0
        local key=ZygorClassic_Key62 and ZygorClassic_Key62() or nil
        local state=key and ZygorClassicDB and ZygorClassicDB.engine172 and ZygorClassicDB.engine172[key]
        local guides=ZygorGuidesViewer and ZygorGuidesViewer.registeredguides
        local guide=state and guides and guides[tonumber(state.guide) or 0]
        if not state or not guide then return end
        if not state.vanillaGnomeBoat333 then
            local title=tostring(guide.title or "")
            if string.find(title,"Gnome (1-13)",1,true) then
                local oldStep=tonumber(state.step) or 1
                local zone=GetRealZoneText and GetRealZoneText() or ""
                if oldStep>165 or (oldStep==165 and zone~="Wetlands") then
                    state.step=oldStep+2
                end
                if tonumber(state.step) then
                    ZygorClassicStepIndex=tonumber(state.step)
                    if ZygorClassicDB.smart51 and ZygorClassicDB.smart51[key] then
                        ZygorClassicDB.smart51[key].step=tonumber(state.step)
                    end
                    local char=ZygorClassic_CharDB and ZygorClassic_CharDB()
                    if char then char.step=tonumber(state.step) end
                end
            end
            state.vanillaGnomeBoat333=true
        end
        this:SetScript("OnUpdate",nil)
        if ZygorClassic_PlayerRender246 then ZygorClassic_PlayerRender246() end
        if ZygorClassic_Render then ZygorClassic_Render() end
        if ZygorClassic_UpdateArrow55 then ZygorClassic_UpdateArrow55() end
    end)
end

ZYGOR_BACKPORT_VERSION = "TEST333"

-- TEST334: objective-free waypoint travel steps inherit the pointer's arrival
-- radius even when the source guide omitted its explicit |c marker.
ZYGOR_BACKPORT_VERSION = "TEST334"

-- TEST335: include Vanilla's keyring in authoritative item-count checks so
-- collected keys resolve guide objectives without counting bank contents.
ZYGOR_BACKPORT_VERSION = "TEST335"

-- TEST336: Vanilla GetItemCount may require an item name rather than an ID;
-- use that path to count keys in clients whose keyring cannot be enumerated.
ZYGOR_BACKPORT_VERSION = "TEST336"

-- TEST337: enumerate KEYRING_CONTAINER with Vanilla's GetKeyRingSize API.
ZYGOR_BACKPORT_VERSION = "TEST337"

-- TEST338: accepted item-started quests resolve their consumed same-step
-- collect/use prerequisites without weakening partial multi-accept steps.
ZYGOR_BACKPORT_VERSION = "TEST338"

-- TEST339: restore ellipses corrupted by the historic vararg conversion in
-- guide directives and quest titles before parsing, display, and matching.
ZYGOR_BACKPORT_VERSION = "TEST339"

-- TEST340: route The Admiral's Orders (2) to its Vanilla recipient Nazgrel
-- instead of the neighboring Vol'jin waypoint in both Horde starter guides.
ZYGOR_BACKPORT_VERSION = "TEST340"

-- TEST341: harden per-character state initialization against legacy or
-- partially migrated SavedVariables that do not contain the characters table.
ZYGOR_BACKPORT_VERSION = "TEST341"

-- TEST342: restore the furthest saved same-guide checkpoint across legacy and
-- current state stores before quest-log bootstrap can rewind the character.
ZYGOR_BACKPORT_VERSION = "TEST342"

-- TEST343: keep the technical diagnostics workspace closed on every login.
-- This late event owner runs after the legacy viewer has consumed its saved
-- visibility setting.  It does not affect the compact player guide, and the
-- Diag button can still explicitly toggle the workspace at any time.
if not ZygorClassicDiagnosticsStartup343 then
    ZygorClassicDiagnosticsStartup343 = CreateFrame(
        "Frame", "ZygorClassicDiagnosticsStartup343", UIParent)
    ZygorClassicDiagnosticsStartup343:RegisterEvent("PLAYER_ENTERING_WORLD")
    ZygorClassicDiagnosticsStartup343:SetScript("OnEvent", function()
        if ZygorGuidesViewerFrame then
            ZygorGuidesViewerFrame:Hide()
        end
        if ZygorGuidesViewer and ZygorGuidesViewer.db and
           ZygorGuidesViewer.db.profile then
            ZygorGuidesViewer.db.profile.visible = false
        end
    end)
end

ZYGOR_BACKPORT_VERSION = "TEST343"
