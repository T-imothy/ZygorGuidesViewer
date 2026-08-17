-- TEST254: active-quest assistance for the Vanilla 1.12 client.
--
-- Objective locations follow every incomplete quest-log objective while the
-- normal Zygor window and arrow continue to control guide progression.

local ZGV=ZygorGuidesViewer
local DB=ZygorClassicQuestDB
if not ZGV or not DB then return end

ZygorClassicQuestAssist={}
local QA=ZygorClassicQuestAssist
local floor=math.floor
local sqrt=math.sqrt
local tinsert=table.insert
local tgetn=table.getn

QA.markerType="questobjective253"
QA.unitNames={}
QA.itemNames={}
QA.objectNames={}
QA.questNames={}
QA.worldDots={}
QA.minimapDots={}
QA.checks={}
QA.activeObjectives={}
QA.activeSources={}
QA.activeQuestCount=0
QA.unresolvedObjectives=0
QA.markerCount=0
QA.elapsed=0
QA.routeElapsed=0
QA.signature=nil

local function normalize(value)
    value=tostring(value or "")
    value=string.gsub(value,"|c%x%x%x%x%x%x%x%x","")
    value=string.gsub(value,"|r","")
    value=string.gsub(value,"^%s+","")
    value=string.gsub(value,"%s+$","")
    value=string.gsub(value,"%s+"," ")
    return string.lower(value)
end

local function addName(index,name,id)
    local key=normalize(name)
    if key=="" then return end
    if not index[key] then index[key]={} end
    tinsert(index[key],id)
end

for id,record in pairs(DB.u or {}) do addName(QA.unitNames,record.n,id) end
for id,record in pairs(DB.i or {}) do addName(QA.itemNames,record.n,id) end
for id,record in pairs(DB.o or {}) do addName(QA.objectNames,record.n,id) end
for id,record in pairs(DB.q or {}) do addName(QA.questNames,record.n,id) end

function QA:GetSettings()
    if not ZygorClassicDB then ZygorClassicDB={} end
    if not ZygorClassicDB.questAssist253 then ZygorClassicDB.questAssist253={} end
    local settings=ZygorClassicDB.questAssist253
    if settings.tooltips==nil then settings.tooltips=true end
    if settings.worldmap==nil then settings.worldmap=true end
    if settings.minimap==nil then settings.minimap=true end
    if settings.route==nil then settings.route=true end
    return settings
end

local function goalComplete(goal)
    if not goal then return true end
    if goal.status=="complete" or goal.status=="done" then return true end
    if goal.IsComplete then
        local ok,complete=pcall(goal.IsComplete,goal)
        if ok and complete then return true end
    end
    return false
end

local function goalProgress(goal,item)
    local have=nil
    local need=goal and goal.count
    if goal and goal.questid and goal.objnum and ZGV.questsbyid then
        local quest=ZGV.questsbyid[goal.questid]
        local objective=quest and quest.goals and quest.goals[goal.objnum]
        if objective then
            have=objective.num
            need=need or objective.needed
        end
    end
    if have==nil and GetItemCount and goal then
        have=GetItemCount((item and item.n) or goal.target or "")
    end
    if have~=nil and need then return tostring(have).."/"..tostring(need) end
    return nil
end

local function bestDropChance(item,unitIDs)
    if not item or not item.u or not unitIDs then return nil end
    local best=nil
    for _,source in ipairs(item.u) do
        if unitIDs[source[1]] and (not best or (source[2] or 0)>best) then
            best=source[2] or 0
        end
    end
    return best
end

function QA:ResolveItem(goal)
    if not goal then return nil,nil end
    local id=tonumber(goal.targetid)
    if id and DB.i[id] then return id,DB.i[id] end

    local named=self.itemNames[normalize(goal.target)]
    if named and tgetn(named)>0 then
        id=named[1]
        return id,DB.i[id]
    end

    local quest=goal.questid and DB.q[tonumber(goal.questid)]
    if quest and quest.i then
        if tgetn(quest.i)==1 and DB.i[quest.i[1]] then
            id=quest.i[1]
            return id,DB.i[id]
        end
        for _,itemID in ipairs(quest.i) do
            local item=DB.i[itemID]
            if item and normalize(item.n)==normalize(goal.target) then return itemID,item end
        end
    end
    return nil,nil
end

local function addIDSet(target,ids)
    if not ids then return end
    for _,id in ipairs(ids) do target[id]=true end
end

function QA:GetStepFromUnits(step)
    local result={}
    if not step or not step.goals then return result end
    for _,goal in ipairs(step.goals) do
        if goal.action=="from" and goal.mobs then
            for _,mob in ipairs(goal.mobs) do
                local id=tonumber(mob.id)
                if id and DB.u[id] then result[id]=true
                else addIDSet(result,self.unitNames[normalize(mob.name)]) end
            end
        end
    end
    return result
end

local function addSource(list,seen,kind,id,chance,label)
    id=tonumber(id)
    local record=(kind=="mob" and DB.u[id]) or (kind=="object" and DB.o[id])
    if not record or not record.c or tgetn(record.c)==0 then return end
    local key=kind..":"..tostring(id)..":"..normalize(label)
    if seen[key] then return end
    seen[key]=true
    tinsert(list,{kind=kind,id=id,chance=chance,label=label,record=record})
end

local function compact(value)
    value=normalize(value)
    value=string.gsub(value,"[^%a%d]","")
    return value
end

local function objectiveSubject(text)
    local subject=tostring(text or "")
    subject=string.gsub(subject,"%s*:%s*%d+%s*/%s*%d+.*$","")
    subject=string.gsub(subject,"%s+[Ss]lain$","")
    subject=string.gsub(subject,"%s+[Ff]ound$","")
    subject=string.gsub(subject,"^%s+","")
    subject=string.gsub(subject,"%s+$","")
    return subject
end

local function objectiveProgress(text)
    local _,_,have,need=string.find(tostring(text or ""),"(%d+)%s*/%s*(%d+)")
    if have and need then return tostring(have).."/"..tostring(need) end
    return nil
end

local function nameScore(subject,name)
    local wanted=compact(subject)
    local candidate=compact(name)
    if wanted=="" or candidate=="" then return 0 end
    if wanted==candidate then return 1000 end
    if string.find(wanted,candidate,1,true) then return 700 end
    if string.find(candidate,wanted,1,true) then return 600 end
    return 0
end

function QA:GetQuestIDsForLog(index,title)
    local result={}
    local seen={}
    local function add(value)
        value=tonumber(value)
        if value and DB.q[value] and not seen[value] then seen[value]=true tinsert(result,value) end
    end

    if GetQuestLink then
        local link=GetQuestLink(index)
        if link then
            local _,_,questID=string.find(link,"Hquest:(%d+)")
            add(questID)
        end
    end
    for _,quest in pairs(ZGV.quests or {}) do
        if quest and tonumber(quest.index)==tonumber(index) then add(quest.id) end
    end
    local named=self.questNames[normalize(title)]
    if named then for _,questID in ipairs(named) do add(questID) end end
    return result
end

local function addCandidate(candidates,kind,id,record,subject,bonus)
    if not record then return end
    local score=nameScore(subject,record.n)+(bonus or 0)
    tinsert(candidates,{kind=kind,id=id,record=record,score=score})
end

function QA:ResolveLogObjective(questIDs,subject,objectiveType)
    local candidates={}
    local preferredCount=0
    local preferred=nil
    for _,questID in ipairs(questIDs or {}) do
        local quest=DB.q[questID]
        if quest then
            for _,unitID in ipairs(quest.u or {}) do
                local bonus=(objectiveType=="monster") and 100 or 0
                addCandidate(candidates,"mob",unitID,DB.u[unitID],subject,bonus)
                if objectiveType=="monster" then preferredCount=preferredCount+1 preferred={kind="mob",id=unitID,record=DB.u[unitID]} end
            end
            for _,itemID in ipairs(quest.i or {}) do
                local bonus=(objectiveType=="item") and 100 or 0
                addCandidate(candidates,"item",itemID,DB.i[itemID],subject,bonus)
                if objectiveType=="item" then preferredCount=preferredCount+1 preferred={kind="item",id=itemID,record=DB.i[itemID]} end
            end
            for _,objectID in ipairs(quest.o or {}) do
                local bonus=(objectiveType=="object") and 100 or 0
                addCandidate(candidates,"object",objectID,DB.o[objectID],subject,bonus)
                if objectiveType=="object" then preferredCount=preferredCount+1 preferred={kind="object",id=objectID,record=DB.o[objectID]} end
            end
        end
    end
    table.sort(candidates,function(a,b) return a.score>b.score end)
    if candidates[1] and candidates[1].score>0 then return candidates[1] end
    if preferredCount==1 and preferred and preferred.record then return preferred end
    if tgetn(candidates)==1 then return candidates[1] end
    return nil
end

local function addObjectiveSource(sources,seen,objective,kind,id,chance)
    id=tonumber(id)
    local record=(kind=="mob" and DB.u[id]) or (kind=="object" and DB.o[id])
    if not record or not record.c or tgetn(record.c)==0 then return end
    local label=objective.subject
    if objective.progress then label=label.." "..objective.progress end
    label=label.." - "..objective.questTitle
    local key=kind..":"..tostring(id)..":"..normalize(label)
    if seen[key] then return end
    seen[key]=true
    tinsert(sources,{
        kind=kind,id=id,chance=chance,label=label,record=record,
        objective=objective,questTitle=objective.questTitle
    })
    if kind=="mob" then objective.unitIDs[id]=chance or true
    else objective.objectIDs[id]=chance or true end
end

local function parseGuideGoto(line,mapContext)
    line=tostring(line or "")
    local payload=nil
    local pipeStart,pipeEnd=string.find(line,"|goto%s+")
    if pipeStart then
        payload=string.sub(line,pipeEnd+1)
    else
        local clean=string.gsub(line,"^%s+","")
        clean=string.gsub(clean,"^%.+","")
        if string.sub(clean,1,5)=="goto " then payload=string.sub(clean,6) end
    end
    if not payload then return mapContext,nil,nil end
    local metadata=string.find(payload,"|",1,true)
    if metadata then payload=string.sub(payload,1,metadata-1) end
    payload=string.gsub(payload,"^%s+","")
    payload=string.gsub(payload,"%s+$","")

    local parts={}
    local start=1
    while true do
        local comma=string.find(payload,",",start,true)
        if not comma then tinsert(parts,string.sub(payload,start)) break end
        tinsert(parts,string.sub(payload,start,comma-1))
        start=comma+1
    end
    if tgetn(parts)==1 and not tonumber(parts[1]) then return parts[1],nil,nil end
    if tgetn(parts)>=2 and tonumber(parts[1]) and tonumber(parts[2]) then
        return mapContext,tonumber(parts[1]),tonumber(parts[2])
    end
    if tgetn(parts)>=3 and tonumber(parts[2]) and tonumber(parts[3]) then
        return parts[1],tonumber(parts[2]),tonumber(parts[3])
    end
    return mapContext,nil,nil
end

local function lineMatchesQuest(line,questIDs,objectiveIndex,directive)
    line=tostring(line or "")
    for _,questID in ipairs(questIDs or {}) do
        if objectiveIndex then
            if string.find(line,"|q%s*"..tostring(questID).."%s*/%s*"..tostring(objectiveIndex)) then return true end
        elseif directive=="turnin" then
            if string.find(line,"turnin%s+.-##"..tostring(questID)) then return true end
        end
    end
    return false
end

function QA:FindGuideQuestWaypoint(questIDs,objectiveIndex,directive)
    local guide=nil
    if ZGV.registeredguides then guide=ZGV.registeredguides[ZygorClassicGuideIndex or 1] end
    if not guide then guide=ZGV.CurrentGuide end
    local raw=guide and guide.rawdata
    if type(raw)~="string" then return nil end

    local mapContext=(ZGV.CurrentStep and ZGV.CurrentStep.map) or (GetRealZoneText and GetRealZoneText())
    local stepX,stepY=nil,nil
    raw=raw.."\n"
    local position=1
    while position<=string.len(raw) do
        local lineEnd=string.find(raw,"\n",position,true)
        if not lineEnd then break end
        local line=string.sub(raw,position,lineEnd-1)
        position=lineEnd+1
        line=string.gsub(line,"\r","")
        local clean=string.gsub(line,"^%s+","")
        if string.sub(clean,1,4)=="step" then
            stepX=nil stepY=nil
        else
            local newMap,x,y=parseGuideGoto(line,mapContext)
            mapContext=newMap or mapContext
            if x and y then stepX=x stepY=y end
            if stepX and stepY and lineMatchesQuest(line,questIDs,objectiveIndex,directive) then
                return mapContext or (GetRealZoneText and GetRealZoneText()),stepX,stepY
            end
        end
    end
    return nil
end

local function addGuideSource(sources,seen,objective,zoneName,x,y,label)
    if not zoneName or not x or not y then return false end
    local key="misc:"..normalize(zoneName)..":"..tostring(x)..":"..tostring(y)..":"..normalize(label)
    if seen[key] then return false end
    seen[key]=true
    local record={n=label,c={}}
    tinsert(sources,{
        kind="misc",id=0,label=label,record=record,objective=objective,
        questTitle=objective and objective.questTitle,fixedCoords={{x,y,zoneName}}
    })
    if objective then objective.guideFallback=true objective.kind="guide" end
    return true
end

function QA:GatherActiveQuestData()
    local objectives={}
    local sources={}
    local seen={}
    local questCount=0
    local unresolved=0
    local activeQuests={}

    if not GetQuestLogTitle or not GetNumQuestLeaderBoards or not GetQuestLogLeaderBoard then
        self.activeObjectives=objectives
        self.activeSources=sources
        self.activeQuestCount=0
        self.unresolvedObjectives=0
        self.activeQuests=activeQuests
        return sources,objectives
    end

    -- Vanilla can still return underlying entries beyond the visible count when
    -- quest-zone headers are collapsed, so scan the same stable range pfQuest uses.
    for questIndex=1,40 do
        local title,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(questIndex)
        if title and not isHeader then
            questCount=questCount+1
            local questIDs=self:GetQuestIDsForLog(questIndex,title)
            local objectiveCount=GetNumQuestLeaderBoards(questIndex) or 0
            local questEntry={title=title,index=questIndex,ids=questIDs,complete=(isComplete==1 or isComplete==true),objectiveCount=objectiveCount,incomplete=0}
            tinsert(activeQuests,questEntry)
            for objectiveIndex=1,objectiveCount do
                local text,objectiveType,finished=GetQuestLogLeaderBoard(objectiveIndex,questIndex)
                if text and not (finished==1 or finished==true) then
                    questEntry.incomplete=questEntry.incomplete+1
                    local subject=objectiveSubject(text)
                    local resolved=self:ResolveLogObjective(questIDs,subject,objectiveType)
                    local objective={
                        questTitle=title,questIndex=questIndex,questIDs=questIDs,
                        objectiveIndex=objectiveIndex,text=text,subject=subject,
                        objectiveType=objectiveType,progress=objectiveProgress(text),
                        unitIDs={},objectIDs={}
                    }
                    local sourceCountBefore=tgetn(sources)
                    if resolved then
                        objective.kind=resolved.kind
                        objective.entityID=resolved.id
                        if resolved.kind=="mob" then
                            addObjectiveSource(sources,seen,objective,"mob",resolved.id,nil)
                        elseif resolved.kind=="object" then
                            addObjectiveSource(sources,seen,objective,"object",resolved.id,nil)
                        elseif resolved.kind=="item" then
                            objective.itemID=resolved.id
                            objective.item=resolved.record
                            for _,entry in ipairs((resolved.record and resolved.record.u) or {}) do
                                addObjectiveSource(sources,seen,objective,"mob",entry[1],entry[2])
                            end
                            for _,entry in ipairs((resolved.record and resolved.record.o) or {}) do
                                addObjectiveSource(sources,seen,objective,"object",entry[1],entry[2])
                            end
                        end
                    end
                    if not resolved or tgetn(sources)==sourceCountBefore then
                        local guideZone,guideX,guideY=self:FindGuideQuestWaypoint(questIDs,objectiveIndex,nil)
                        local fallbackLabel=subject
                        if objective.progress then fallbackLabel=fallbackLabel.." "..objective.progress end
                        fallbackLabel=fallbackLabel.." - "..title
                        if not addGuideSource(sources,seen,objective,guideZone,guideX,guideY,fallbackLabel) then
                            unresolved=unresolved+1
                        end
                    end
                    tinsert(objectives,objective)
                end
            end
            -- Completed quests and delivery/talk quests have no unfinished
            -- leaderboard row, so show their guide turn-in location instead.
            if questEntry.complete or (objectiveCount==0 and questEntry.incomplete==0) then
                local turninZone,turninX,turninY=self:FindGuideQuestWaypoint(questIDs,nil,"turnin")
                local stateLabel=questEntry.complete and "Turn in" or "Continue"
                local pseudoObjective={questTitle=title,subject=stateLabel,progress=nil,unitIDs={},objectIDs={},kind="guide",guideFallback=true}
                if addGuideSource(sources,seen,pseudoObjective,turninZone,turninX,turninY,stateLabel.." - "..title) then
                    tinsert(objectives,pseudoObjective)
                end
            end
        end
    end
    self.activeObjectives=objectives
    self.activeSources=sources
    self.activeQuestCount=questCount
    self.unresolvedObjectives=unresolved
    self.activeQuests=activeQuests
    return sources,objectives
end

function QA:GatherStepSources(step)
    local sources={}
    local seen={}
    local fromUnits=self:GetStepFromUnits(step)
    local hasFrom=false
    for id in pairs(fromUnits) do hasFrom=true end
    local usedFrom={}

    if not step or not step.goals then return sources end
    for _,goal in ipairs(step.goals) do
        if not goalComplete(goal) then
            if goal.action=="kill" then
                local id=tonumber(goal.targetid)
                if id and DB.u[id] then
                    addSource(sources,seen,"mob",id,nil,goal.target or DB.u[id].n)
                else
                    local ids=self.unitNames[normalize(goal.target)]
                    if ids then for _,unitID in ipairs(ids) do addSource(sources,seen,"mob",unitID,nil,goal.target) end end
                end
            elseif goal.action=="get" or goal.action=="collect" then
                local itemID,item=self:ResolveItem(goal)
                local added=false
                if item then
                    if hasFrom then
                        for _,entry in ipairs(item.u or {}) do
                            if fromUnits[entry[1]] then
                                addSource(sources,seen,"mob",entry[1],entry[2],item.n)
                                usedFrom[entry[1]]=true
                                added=true
                            end
                        end
                        if not added then
                            for unitID in pairs(fromUnits) do
                                addSource(sources,seen,"mob",unitID,nil,item.n)
                                usedFrom[unitID]=true
                                added=true
                            end
                        end
                    else
                        for _,entry in ipairs(item.u or {}) do
                            addSource(sources,seen,"mob",entry[1],entry[2],item.n)
                            added=true
                        end
                        for _,entry in ipairs(item.o or {}) do
                            addSource(sources,seen,"object",entry[1],entry[2],item.n)
                            added=true
                        end
                    end
                end
            end
        end
    end

    -- A .from line can be useful on its own, even when its associated item name
    -- could not be resolved in the trimmed database.
    for unitID in pairs(fromUnits) do
        if not usedFrom[unitID] then
            local unit=DB.u[unitID]
            addSource(sources,seen,"mob",unitID,nil,unit and unit.n or "Quest target")
        end
    end
    return sources
end

local function stepAnchor(step)
    if not step or not step.goals then return nil,nil,nil end
    local fallbackX,fallbackY,fallbackMap
    for _,goal in ipairs(step.goals) do
        if goal.x and goal.y then
            fallbackX=tonumber(goal.x)
            fallbackY=tonumber(goal.y)
            fallbackMap=goal.map or step.map
            if goal.action=="goto" then return fallbackX,fallbackY,fallbackMap end
        end
    end
    return fallbackX,fallbackY,fallbackMap or step.map
end

local function distanceSquared(x1,y1,x2,y2)
    local dx=(x1 or 0)-(x2 or 0)
    local dy=(y1 or 0)-(y2 or 0)
    return dx*dx+dy*dy
end

local function appendLabel(group,label,chance)
    local text=tostring(label or "Quest objective")
    if chance and chance>0 then text=text.." ("..string.format("%.1f",chance).."%)" end
    if not group.labelSet[text] then
        group.labelSet[text]=true
        tinsert(group.labels,text)
    end
end

function QA:BuildMarkerData(step)
    local sources=self:GatherStepSources(step)
    local anchorX,anchorY,anchorMap=stepAnchor(step)
    local currentZone=GetRealZoneText and GetRealZoneText() or nil
    local zoneWanted=normalize(anchorMap or (step and step.map) or currentZone)
    local sortX,sortY=anchorX,anchorY
    if not sortX and GetPlayerMapPosition and normalize(currentZone)==zoneWanted then
        local playerX,playerY=GetPlayerMapPosition("player")
        if playerX and playerY and playerX>0 and playerY>0 then
            sortX=playerX*100
            sortY=playerY*100
        end
    end
    local points={}

    for _,source in ipairs(sources) do
        for _,coord in ipairs(source.record.c or {}) do
            local zoneName=DB.z[coord[3]]
            if zoneName and (zoneWanted=="" or normalize(zoneName)==zoneWanted) then
                tinsert(points,{x=coord[1],y=coord[2],zone=zoneName,kind=source.kind,label=source.label,chance=source.chance})
            end
        end
    end

    if anchorX and anchorY and tgetn(points)>0 then
        local nearby={}
        for _,point in ipairs(points) do
            if distanceSquared(point.x,point.y,anchorX,anchorY)<=784 then tinsert(nearby,point) end
        end
        if tgetn(nearby)>0 then points=nearby end
    end

    local groups={}
    for _,point in ipairs(points) do
        local gridX=floor(point.x/3)
        local gridY=floor(point.y/3)
        local key=point.kind..":"..normalize(point.zone)..":"..tostring(gridX)..":"..tostring(gridY)
        local group=groups[key]
        if not group then
            group={x=0,y=0,count=0,zone=point.zone,kind=point.kind,labels={},labelSet={}}
            groups[key]=group
        end
        group.x=group.x+point.x
        group.y=group.y+point.y
        group.count=group.count+1
        appendLabel(group,point.label,point.chance)
    end

    local result={}
    for _,group in pairs(groups) do
        group.x=group.x/group.count
        group.y=group.y/group.count
        group.distance=distanceSquared(group.x,group.y,sortX or group.x,sortY or group.y)
        tinsert(result,group)
    end
    table.sort(result,function(a,b)
        if a.distance==b.distance then return a.count>b.count end
        return a.distance<b.distance
    end)
    while tgetn(result)>14 do table.remove(result) end
    return result
end

local function preferredSourceCoords(source,currentZone,stepZone)
    local byZone={}
    local coordinates=source.fixedCoords or (source.record and source.record.c) or {}
    for _,coord in ipairs(coordinates) do
        local zoneName=source.fixedCoords and coord[3] or DB.z[coord[3]]
        if zoneName then
            local key=normalize(zoneName)
            if not byZone[key] then byZone[key]={name=zoneName,coords={}} end
            tinsert(byZone[key].coords,{coord[1],coord[2]})
        end
    end
    local current=byZone[normalize(currentZone)]
    if current then return current end
    local guide=byZone[normalize(stepZone)]
    if guide then return guide end
    local best=nil
    for _,entry in pairs(byZone) do
        if not best or tgetn(entry.coords)>tgetn(best.coords) then best=entry end
    end
    return best
end

function QA:BuildAllMarkerData(sources)
    local currentZone=GetRealZoneText and GetRealZoneText() or ""
    local anchorX,anchorY,stepZone=stepAnchor(ZGV.CurrentStep)
    local playerX,playerY=nil,nil
    if GetPlayerMapPosition then
        playerX,playerY=GetPlayerMapPosition("player")
        if playerX and playerY and playerX>0 and playerY>0 then
            playerX=playerX*100
            playerY=playerY*100
        else
            playerX=nil playerY=nil
        end
    end

    local groups={}
    for _,source in ipairs(sources or {}) do
        local selected=preferredSourceCoords(source,currentZone,stepZone)
        if selected then
            for _,coord in ipairs(selected.coords) do
                local gridX=floor(coord[1]/4)
                local gridY=floor(coord[2]/4)
                local key=source.kind..":"..normalize(selected.name)..":"..tostring(gridX)..":"..tostring(gridY)
                local group=groups[key]
                if not group then
                    group={x=0,y=0,count=0,zone=selected.name,kind=source.kind,labels={},labelSet={}}
                    groups[key]=group
                end
                group.x=group.x+coord[1]
                group.y=group.y+coord[2]
                group.count=group.count+1
                appendLabel(group,source.label,source.chance)
            end
        end
    end

    local byZone={}
    for _,group in pairs(groups) do
        group.x=group.x/group.count
        group.y=group.y/group.count
        if normalize(group.zone)==normalize(currentZone) and playerX and playerY then
            group.distance=distanceSquared(group.x,group.y,playerX,playerY)
        elseif normalize(group.zone)==normalize(stepZone) and anchorX and anchorY then
            group.distance=distanceSquared(group.x,group.y,anchorX,anchorY)
        else
            group.distance=10000-group.count
        end
        local zoneKey=normalize(group.zone)
        if not byZone[zoneKey] then byZone[zoneKey]={} end
        tinsert(byZone[zoneKey],group)
    end

    local result={}
    for _,zoneGroups in pairs(byZone) do
        table.sort(zoneGroups,function(a,b)
            if a.distance==b.distance then return a.count>b.count end
            return a.distance<b.distance
        end)
        local limit=tgetn(zoneGroups)
        if limit>18 then limit=18 end
        for index=1,limit do tinsert(result,zoneGroups[index]) end
    end
    return result
end

function QA:ClearMarkers()
    if ZGV.Pointer and ZGV.Pointer.ArrowFrame then
        local selected=ZGV.Pointer.ArrowFrame.waypoint
        if selected and selected.type==self.markerType then
            self.selectedObjective={c=selected.c,z=selected.z,x=selected.x,y=selected.y}
        else
            self.selectedObjective=nil
        end
    end
    if ZGV.Pointer and ZGV.Pointer.ClearWaypoints then ZGV.Pointer:ClearWaypoints(self.markerType) end
end

function QA:RestoreGuideArrow()
    if not ZGV.Pointer or not ZGV.Pointer.ArrowFrame or ZGV.Pointer.ArrowFrame.waypoint then return end
    for waypoint in pairs(ZGV.Pointer.waypoints or {}) do
        if waypoint.type=="way" and ZGV.Pointer.ShowArrow then
            ZGV.Pointer:ShowArrow(waypoint)
            return
        end
    end
end

local function markerTitle(group)
    local prefix="Quest items: "
    if group.kind=="mob" then prefix="Quest mobs: "
    elseif group.kind=="misc" then prefix="Quest destination: " end
    local title=prefix
    for index,label in ipairs(group.labels) do
        if index>1 then title=title..", " end
        title=title..label
        if index>=3 and tgetn(group.labels)>3 then title=title.." +"..tostring(tgetn(group.labels)-3) break end
    end
    if group.count>1 then title=title.."  ["..tostring(group.count).." nearby spawns]" end
    return title
end

function QA:RefreshMarkers()
    self:ClearMarkers()
    local settings=self:GetSettings()
    self.markerCount=0
    if not settings.worldmap and not settings.minimap then self:RestoreGuideArrow() return end
    if not ZGV.Pointer or not ZGV.Pointer.SetWaypoint then self:RestoreGuideArrow() return end

    local activeSources=self:GatherActiveQuestData()
    local markers=nil
    if activeSources and tgetn(activeSources)>0 then
        markers=self:BuildAllMarkerData(activeSources)
    elseif ZGV.CurrentStep then
        markers=self:BuildMarkerData(ZGV.CurrentStep)
    else
        markers={}
    end
    local closest=nil
    local closestDistance=nil
    for _,group in ipairs(markers) do
        local continent,zone=ZGV:GetMapZoneNumbers(group.zone)
        if continent and continent>0 and zone and zone>0 then
            local icon="Interface\\AddOns\\ZygorGuidesViewer\\QuestAssist\\cluster_item"
            if group.kind=="mob" then icon="Interface\\AddOns\\ZygorGuidesViewer\\QuestAssist\\cluster_mob" end
            if group.kind=="misc" then icon="Interface\\AddOns\\ZygorGuidesViewer\\QuestAssist\\cluster_misc" end
            local waypoint=ZGV.Pointer:SetWaypoint(continent,zone,group.x,group.y,{
                title=markerTitle(group),
                type=self.markerType,
                noarrow=true,
                persistent=true,
                -- Let Astrolabe project objective sources onto continent/zone
                -- views instead of limiting them to an exact current-map match.
                overworld=true,
                onminimap="zone",
                hideworld=not settings.worldmap,
                hideminimapsetting=not settings.minimap,
                hideminimapedge=true,
                icon=icon
            })
            self.markerCount=self.markerCount+1
            if waypoint and self.selectedObjective and continent==self.selectedObjective.c and zone==self.selectedObjective.z then
                local candidateDistance=distanceSquared(waypoint.x,waypoint.y,self.selectedObjective.x,self.selectedObjective.y)
                if not closestDistance or candidateDistance<closestDistance then
                    closest=waypoint
                    closestDistance=candidateDistance
                end
            end
        end
    end
    if closest and ZGV.Pointer.ShowArrow then
        ZGV.Pointer:ShowArrow(closest)
    else
        self:RestoreGuideArrow()
    end
end

function QA:ActiveQuestSignature()
    if not GetQuestLogTitle or not GetNumQuestLeaderBoards or not GetQuestLogLeaderBoard then return "noquestapi" end
    local parts={}
    for questIndex=1,40 do
        local title,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(questIndex)
        if title and not isHeader then
            tinsert(parts,tostring(title))
            tinsert(parts,tostring(isComplete))
            local objectiveCount=GetNumQuestLeaderBoards(questIndex) or 0
            for objectiveIndex=1,objectiveCount do
                local text,objectiveType,finished=GetQuestLogLeaderBoard(objectiveIndex,questIndex)
                tinsert(parts,tostring(text or ""))
                tinsert(parts,tostring(objectiveType or ""))
                tinsert(parts,tostring(finished))
            end
        end
    end
    return table.concat(parts,"^")
end

function QA:StepSignature()
    local step=ZGV.CurrentStep
    local parts={tostring(ZGV.CurrentGuideName or ""),
        tostring(ZygorClassicStepIndex or ZGV.CurrentStepNum or 0)}
    if step and step.goals then
        for _,goal in ipairs(step.goals) do
            local itemID,item=self:ResolveItem(goal)
            tinsert(parts,tostring(goal.action or ""))
            tinsert(parts,tostring(goal.target or goal.quest or ""))
            tinsert(parts,tostring(goal.status or ""))
            tinsert(parts,tostring(goalComplete(goal)))
            tinsert(parts,tostring(goalProgress(goal,item) or ""))
        end
    end
    local settings=self:GetSettings()
    tinsert(parts,tostring(settings.worldmap))
    tinsert(parts,tostring(settings.minimap))
    tinsert(parts,self:ActiveQuestSignature())
    return table.concat(parts,"|")
end

function QA:ForceRefresh()
    self.signature=nil
    self:SyncChecks()
end

local function unitIDSetForName(name)
    local result={}
    addIDSet(result,QA.unitNames[normalize(name)])
    return result
end

local function objectIDSetForName(name)
    local result={}
    addIDSet(result,QA.objectNames[normalize(name)])
    return result
end

local function chanceText(chance)
    if not chance or chance<=0 then return nil end
    return "|cff888888Drop chance: "..string.format("%.1f",chance).."%|r"
end

function QA:EnhanceTooltip()
    local settings=self:GetSettings()
    if not settings.tooltips or not GameTooltip then return end
    local hasUnit=UnitExists and UnitExists("mouseover")
    local name=hasUnit and UnitName and UnitName("mouseover") or nil
    if not name and getglobal then
        local line=getglobal("GameTooltipTextLeft1")
        if line and line.GetText then name=line:GetText() end
    end
    if not name then return end

    local hovered=unitIDSetForName(name)
    local hoveredObjects=objectIDSetForName(name)
    local hoveredKnown=false
    for id in pairs(hovered) do hoveredKnown=true end
    for id in pairs(hoveredObjects) do hoveredKnown=true end
    if not hoveredKnown then return end

    if tgetn(self.activeObjectives or {})==0 then self:GatherActiveQuestData() end
    local step=ZGV.CurrentStep
    local fromUnits=self:GetStepFromUnits(step)
    local fromMatch=false
    for id in pairs(hovered) do if fromUnits[id] then fromMatch=true end end
    local lines={}
    local seen={}
    local hasActiveMatch=false
    local hasStepMatch=false

    for _,objective in ipairs(self.activeObjectives or {}) do
        local match=false
        local chance=nil
        for id in pairs(hovered) do
            local value=objective.unitIDs and objective.unitIDs[id]
            if value then
                match=true
                if type(value)=="number" and (not chance or value>chance) then chance=value end
            end
        end
        for id in pairs(hoveredObjects) do
            if objective.objectIDs and objective.objectIDs[id] then match=true end
        end
        if match then
            hasActiveMatch=true
            local targetText=(hasUnit and "Kill target: " or "Quest object: ")..tostring(name)
            if not seen[targetText] then seen[targetText]=true tinsert(lines,targetText) end
            local text="|cffffcc33"..tostring(objective.questTitle).."|r: "..tostring(objective.subject)
            if objective.progress then text=text.."  |cffaaaaaa"..objective.progress.."|r" end
            if not seen[text] then seen[text]=true tinsert(lines,text) end
            local dropLine=chanceText(chance)
            if dropLine and not seen[dropLine] then seen[dropLine]=true tinsert(lines,dropLine) end
        end
    end

    for _,goal in ipairs((step and step.goals) or {}) do
        if not goalComplete(goal) then
            if goal.action=="from" and goal.mobs then
                local match=false
                local targetName=nil
                for _,mob in ipairs(goal.mobs) do
                    local targetID=tonumber(mob.id)
                    if (targetID and hovered[targetID]) or normalize(mob.name)==normalize(name) then
                        match=true
                        targetName=mob.name or name
                    end
                end
                if match then
                    hasStepMatch=true
                    local text="Kill target: "..tostring(targetName or name)
                    if not seen[text] then seen[text]=true tinsert(lines,text) end
                end
            elseif goal.action=="kill" then
                local match=false
                local targetID=tonumber(goal.targetid)
                if targetID and hovered[targetID] then match=true end
                if normalize(goal.target)==normalize(name) then match=true end
                if match then
                    hasStepMatch=true
                    local text="Kill: "..tostring(goal.target or name)
                    local progress=goalProgress(goal,nil)
                    if progress then text=text.."  |cffaaaaaa"..progress.."|r" end
                    if not seen[text] then seen[text]=true tinsert(lines,text) end
                end
            elseif goal.action=="get" or goal.action=="collect" then
                local itemID,item=self:ResolveItem(goal)
                local chance=bestDropChance(item,hovered)
                local objectMatch=false
                for _,source in ipairs((item and item.o) or {}) do
                    if hoveredObjects[source[1]] then objectMatch=true break end
                end
                if chance or fromMatch or objectMatch then
                    hasStepMatch=true
                    local text="Collect: "..tostring((item and item.n) or goal.target or "Quest item")
                    local progress=goalProgress(goal,item)
                    if progress then text=text.."  |cffaaaaaa"..progress.."|r" end
                    if not seen[text] then seen[text]=true tinsert(lines,text) end
                    local dropLine=chanceText(chance)
                    if dropLine and not seen[dropLine] then seen[dropLine]=true tinsert(lines,dropLine) end
                end
            end
        end
    end

    if tgetn(lines)==0 and fromMatch then
        hasStepMatch=true
        tinsert(lines,"Quest target for the current step")
    end
    if tgetn(lines)==0 then return end
    local baseHeight=(GameTooltip.GetHeight and GameTooltip:GetHeight()) or 0
    local currentWidth=(GameTooltip.GetWidth and GameTooltip:GetWidth()) or 0
    if GameTooltip.SetWidth and currentWidth<340 then GameTooltip:SetWidth(340) end
    GameTooltip:AddLine(" ")
    local context=nil
    local guideStep=ZygorClassicStepIndex or ZGV.CurrentStepNum or "?"
    if hasActiveMatch and hasStepMatch then
        context="Active Quest  /  Guide Step "..tostring(guideStep)
    elseif hasActiveMatch then
        context="Active Quest"
    else
        context="Guide Step "..tostring(guideStep)
    end
    GameTooltip:AddLine("|cffffcc33Zygor Quest Assist|r  |cff888888"..context.."|r",1,0.82,0.18)
    for _,line in ipairs(lines) do GameTooltip:AddLine(line,0.82,0.92,1,true) end
    -- Vanilla calculates the unit-tooltip frame before OnShow hooks finish.
    -- Reserve the rows explicitly so wrapped quest text is not drawn below
    -- the tooltip border and clipped from view.
    if GameTooltip.SetHeight then
        local targetHeight=baseHeight+30+(tgetn(lines)*28)
        local currentHeight=(GameTooltip.GetHeight and GameTooltip:GetHeight()) or 0
        if currentHeight<targetHeight then GameTooltip:SetHeight(targetHeight) end
    end
end

function QA:GetDot(pool,parent,index)
    local dot=pool[index]
    if not dot then
        dot=parent:CreateTexture(nil,"OVERLAY")
        dot:SetTexture("Interface\\AddOns\\ZygorGuidesViewer\\QuestAssist\\route")
        dot:SetWidth(7)
        dot:SetHeight(7)
        dot:SetVertexColor(1,0.82,0.05,1)
        pool[index]=dot
    end
    return dot
end

local function hideDots(pool)
    for _,dot in ipairs(pool) do dot:Hide() end
end

function QA:DrawDots(pool,parent,x1,y1,x2,y2,spacing,limit)
    hideDots(pool)
    local dx=x2-x1
    local dy=y2-y1
    local length=sqrt(dx*dx+dy*dy)
    if length<6 then return 0 end
    local count=floor(length/spacing)
    if count<1 then count=1 end
    if count>limit then count=limit end
    for index=1,count do
        local fraction=index/(count+1)
        local dot=self:GetDot(pool,parent,index)
        dot:ClearAllPoints()
        dot:SetPoint("CENTER",parent,"CENTER",x1+dx*fraction,y1+dy*fraction)
        dot:Show()
    end
    return count
end

function QA:EnsureRouteLayers()
    if not self.worldRouteFrame and WorldMapButton then
        self.worldRouteFrame=CreateFrame("Frame","ZygorClassicWorldRoute254",WorldMapButton)
        self.worldRouteFrame:SetAllPoints(WorldMapButton)
        if self.worldRouteFrame.SetFrameLevel and WorldMapButton.GetFrameLevel then
            self.worldRouteFrame:SetFrameLevel((WorldMapButton:GetFrameLevel() or 0)+20)
        end
        self.worldRouteFrame:Show()
    end
    if not self.minimapRouteFrame and Minimap then
        self.minimapRouteFrame=CreateFrame("Frame","ZygorClassicMinimapRoute254",Minimap)
        self.minimapRouteFrame:SetAllPoints(Minimap)
        if self.minimapRouteFrame.SetFrameLevel and Minimap.GetFrameLevel then
            self.minimapRouteFrame:SetFrameLevel((Minimap:GetFrameLevel() or 0)+20)
        end
        self.minimapRouteFrame:Show()
    end
end

function QA:UpdateRoute()
    hideDots(self.worldDots)
    hideDots(self.minimapDots)
    self.routeWorldState="waiting"
    self.routeMinimapState="waiting"
    if not self:GetSettings().route then
        self.routeWorldState="disabled in Player Help"
        self.routeMinimapState="disabled in Player Help"
        return
    end
    if not ZGV.Pointer or not ZGV.Pointer.ArrowFrame then
        self.routeWorldState="pointer unavailable"
        self.routeMinimapState="pointer unavailable"
        return
    end
    local waypoint=ZGV.Pointer.ArrowFrame.waypoint
    if not waypoint then
        self.routeWorldState="no arrow waypoint"
        self.routeMinimapState="no arrow waypoint"
        return
    end

    self:EnsureRouteLayers()

    local worldLayer=self.worldRouteFrame
    if not WorldMapButton or not WorldMapButton:IsShown() then
        self.routeWorldState="world map closed"
    elseif not worldLayer then
        self.routeWorldState="draw layer unavailable"
    elseif GetPlayerMapPosition then
        local continent,zone=GetCurrentMapContinentAndZone()
        local playerX,playerY=GetPlayerMapPosition("player")
        local width=WorldMapButton:GetWidth()
        local height=WorldMapButton:GetHeight()
        if continent==waypoint.c and zone==waypoint.z and playerX and playerY and playerX>0 and playerY>0 and width and height and width>0 and height>0 then
            local x1=playerX*width-width/2
            local y1=height/2-playerY*height
            local x2=waypoint.x*width-width/2
            local y2=height/2-waypoint.y*height
            local count=self:DrawDots(self.worldDots,worldLayer,x1,y1,x2,y2,12,55)
            self.routeWorldState=(count>0 and ("drawn "..tostring(count).." dots")) or "target is too close"
        elseif continent~=waypoint.c or zone~=waypoint.z then
            self.routeWorldState="map/waypoint mismatch "..tostring(continent)..","..tostring(zone).." vs "..tostring(waypoint.c)..","..tostring(waypoint.z)
        elseif not playerX or not playerY or playerX<=0 or playerY<=0 then
            self.routeWorldState="player position unavailable on this map"
        else
            self.routeWorldState="world map has no size"
        end
    else
        self.routeWorldState="player-position API unavailable"
    end

    local marker=waypoint.minimapFrame
    local minimapLayer=self.minimapRouteFrame
    if not minimapLayer then
        self.routeMinimapState="draw layer unavailable"
    elseif not marker then
        self.routeMinimapState="waypoint has no minimap marker"
    elseif not marker:IsShown() then
        self.routeMinimapState="waypoint minimap marker hidden"
    elseif marker.GetCenter and minimapLayer.GetCenter then
        local mapX,mapY=minimapLayer:GetCenter()
        local markerX,markerY=marker:GetCenter()
        if mapX and mapY and markerX and markerY then
            local count=self:DrawDots(self.minimapDots,minimapLayer,0,0,markerX-mapX,markerY-mapY,9,28)
            self.routeMinimapState=(count>0 and ("drawn "..tostring(count).." dots")) or "target is too close"
        else
            self.routeMinimapState="marker center unavailable"
        end
    else
        self.routeMinimapState="marker-position API unavailable"
    end
end

local function chat(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcc33Zygor Quest Assist:|r "..message) end
end

local function countKeys(values)
    local count=0
    for key in pairs(values or {}) do count=count+1 end
    return count
end

local function shortText(value,limit)
    value=tostring(value or "")
    if string.len(value)>limit then return string.sub(value,1,limit-3).."..." end
    return value
end

function QA:DiagnosticText()
    -- Live quest and route state are already maintained by the signature and
    -- route pollers.  Diagnostics must only format that cache; rescanning the
    -- entire quest log and redrawing every dot here caused periodic frame-time
    -- spikes whenever the diagnostics window was open.
    local settings=self:GetSettings()
    local objectiveCount=tgetn(self.activeObjectives or {})
    local resolved=objectiveCount-(self.unresolvedObjectives or 0)
    if resolved<0 then resolved=0 end
    local profile=ZGV.db and ZGV.db.profile or {}
    local continent,zone=nil,nil
    if GetCurrentMapContinentAndZone then continent,zone=GetCurrentMapContinentAndZone() end
    local playerX,playerY=nil,nil
    if GetPlayerMapPosition then playerX,playerY=GetPlayerMapPosition("player") end
    local waypoint=ZGV.Pointer and ZGV.Pointer.ArrowFrame and ZGV.Pointer.ArrowFrame.waypoint
    local waypointText="none"
    if waypoint then
        local miniShown=waypoint.minimapFrame and waypoint.minimapFrame:IsShown()
        waypointText=shortText(waypoint.t or waypoint.title or waypoint.type or "waypoint",28)..
            " ["..tostring(waypoint.type or "?").."] "..
            tostring(waypoint.c or "?")..","..tostring(waypoint.z or "?").." "..
            string.format("%.1f,%.1f",(tonumber(waypoint.x) or 0)*100,(tonumber(waypoint.y) or 0)*100)..
            " mini="..(miniShown and "shown" or "hidden")
    end

    local output="[QUEST ASSIST TEST294]\n"..
        "Settings T/W/M/R: "..(settings.tooltips and "ON" or "OFF").."/"..
        (settings.worldmap and "ON" or "OFF").."/"..
        (settings.minimap and "ON" or "OFF").."/"..
        (settings.route and "ON" or "OFF").."  legacy minicons="..tostring(profile.minicons).."\n"..
        "Quest scan: "..tostring(self.activeQuestCount or 0).." active, "..
        tostring(objectiveCount).." tracked objectives, "..tostring(resolved).." resolved, "..
        tostring(self.unresolvedObjectives or 0).." unresolved\n"..
        "Sources/markers: "..tostring(tgetn(self.activeSources or {})).." / "..tostring(self.markerCount or 0).."\n"..
        "Player/map: "..tostring(GetRealZoneText and GetRealZoneText() or "?").."  "..
        tostring(continent or "?")..","..tostring(zone or "?").."  "..
        string.format("%.1f,%.1f",(tonumber(playerX) or 0)*100,(tonumber(playerY) or 0)*100).."\n"..
        "Arrow: "..waypointText.."\n"..
        "Route mini: "..tostring(self.routeMinimapState or "not checked").."\n"..
        "Route map: "..tostring(self.routeWorldState or "not checked").."\n"..
        "OBJECTIVE RESOLUTION\n"

    local shown=0
    for _,objective in ipairs(self.activeObjectives or {}) do
        shown=shown+1
        if shown>7 then
            output=output.."  +"..tostring(objectiveCount-7).." more objectives\n"
            break
        end
        local unitCount=countKeys(objective.unitIDs)
        local objectCount=countKeys(objective.objectIDs)
        local status="NO MATCH"
        if objective.guideFallback then status="OK guide coord"
        elseif objective.kind and unitCount+objectCount>0 then status="OK "..tostring(objective.kind)
        elseif objective.kind then status="NO SPAWNS "..tostring(objective.kind) end
        output=output.."  ["..status.."] "..shortText(objective.questTitle,22)..": "..
            shortText(objective.subject,25).." "..tostring(objective.progress or "")..
            " -> U"..tostring(unitCount).." O"..tostring(objectCount).."\n"
    end
    if objectiveCount==0 then output=output.."  (no incomplete quest-log objectives detected)\n" end
    return output.."[END QUEST ASSIST]"
end

local function healthColor263(ok,text)
    if ok then return "|cff55dd55"..text.."|r" end
    return "|cffff5555"..text.."|r"
end

local function shortGuide263(title)
    title=tostring(title or "-")
    local last=1
    local scan=1
    while true do
        local found=string.find(title,"\\",scan,true)
        if not found then break end
        last=found+1
        scan=found+1
    end
    return string.sub(title,last)
end

function QA:HealthText263()
    local guides=ZGV.registeredguides or {}
    local guideCount=tgetn(guides)
    local guideIndex=ZygorClassicGuideIndex or 1
    local stepIndex=ZygorClassicStepIndex or 1
    local guide=guides[guideIndex]
    local stepCount=guide and guide.classic_steps and tgetn(guide.classic_steps) or 0
    local step=guide and guide.classic_steps and guide.classic_steps[stepIndex]
    local factionNative=UnitFactionGroup and UnitFactionGroup("player") or nil
    local faction=(ZygorClassic_Faction262 and ZygorClassic_Faction262()) or factionNative or "unknown"
    local factionSource=factionNative and "native API" or "race fallback"
    local key=ZygorClassic_Key62 and ZygorClassic_Key62() or "character"
    local engine=ZygorClassicDB and ZygorClassicDB.engine172 and ZygorClassicDB.engine172[key]
    local stateMatch=engine and engine.guide==guideIndex and engine.step==stepIndex
    local waypoint=ZGV.Pointer and ZGV.Pointer.ArrowFrame and ZGV.Pointer.ArrowFrame.waypoint
    local arrowShown=ZGV.Pointer and ZGV.Pointer.ArrowFrame and
        ZGV.Pointer.ArrowFrame.IsShown and ZGV.Pointer.ArrowFrame:IsShown()
    local routeMap,routeX,routeY=nil,nil,nil
    if ZygorClassic_CurrentGoto55 then routeMap,routeX,routeY=ZygorClassic_CurrentGoto55() end
    local pointerState=ZygorPointerDebug163 and ZygorPointerDebug163.state or "not reported"
    local arrived=ZGV.Pointer and ZGV.Pointer.ArrowFrame and ZGV.Pointer.ArrowFrame.z112arrived
    local arrowEnabled=not (ZygorClassicDB and ZygorClassicDB.arrowEnabled287==false)
    local resolved=tgetn(self.activeObjectives or {})-(self.unresolvedObjectives or 0)
    if resolved<0 then resolved=0 end

    local diagnosis="All core systems are ready."
    local action="No repair action needed."
    if guideCount==0 then
        diagnosis="Guide database is not loaded; no step or arrow can exist."
        action="Restart after TEST262+ and verify the loader count becomes non-zero."
    elseif not guide then
        diagnosis="The selected guide index is absent from the loaded database."
        action="Use Choose Guide > Use Recommended, then reopen Diagnostics."
    elseif not step then
        diagnosis="The saved step is outside the parsed guide."
        action="Use a Step button once or Use Recommended to rebuild the route."
    elseif engine and not stateMatch then
        diagnosis="Displayed progress and authoritative saved state disagree."
        action="Leave this open for one poll; capture it again if mismatch remains."
    elseif routeX and routeY and not waypoint then
        diagnosis="The step has coordinates, but the native pointer owns no waypoint."
        action="Run /zqa refresh. If still missing, this panel preserves the evidence."
    elseif waypoint and not arrowShown and arrowEnabled then
        diagnosis="The pointer owns the route, but its visible frame is hidden."
        action="The visibility controller will restore it above open Zygor windows."
    elseif arrived then
        diagnosis="Waypoint is healthy and you are inside its arrival radius."
        action="Complete the nearby objective; the arrow resumes on the next route."
    elseif (self.unresolvedObjectives or 0)>0 then
        diagnosis="Some active objectives have no location match in the database."
        action="The raw panel identifies each NO MATCH objective for database repair."
    end

    return "|cffffcc33SYSTEM HEALTH|r\n"..
        "Guide database: "..healthColor263(guideCount>0,tostring(guideCount).." loaded").."\n"..
        "Faction: "..tostring(faction).."  |cff888888("..factionSource..")|r\n"..
        "Character: "..tostring(UnitRace and UnitRace("player") or "?").." / "..
            tostring(UnitClass and UnitClass("player") or "?").." / level "..
            tostring(UnitLevel and UnitLevel("player") or "?").."\n\n"..
        "|cffffcc33ROUTE STATE|r\n"..
        "Guide: "..shortGuide263(guide and guide.title).."\n"..
        "Displayed: G"..tostring(guideIndex).." S"..tostring(stepIndex).."/"..tostring(stepCount).."  "..
            healthColor263(step and true or false,step and "READY" or "MISSING").."\n"..
        "Saved engine: "..(engine and ("G"..tostring(engine.guide or "?").." S"..tostring(engine.step or "?")) or "none").."  "..
            healthColor263(stateMatch and true or false,stateMatch and "MATCH" or "CHECK").."\n"..
        "Route: "..tostring(routeMap or "-").." "..tostring(routeX or "-")..","..tostring(routeY or "-").."\n"..
        "Pointer: "..healthColor263(waypoint and (arrowShown or not arrowEnabled),waypoint and
            (not arrowEnabled and "DISABLED" or
             (arrowShown and (arrived and "ARRIVED / VISIBLE" or "ACTIVE / VISIBLE") or "ACTIVE / HIDDEN")) or "NONE").."\n"..
        "Pointer detail: "..tostring(pointerState).."\n"..
        "Arrow control: "..(arrowEnabled and "ON" or "OFF").."  |cff888888(right-click resets)|r\n\n"..
        "|cffffcc33QUEST ASSIST|r\n"..
        "Active quests: "..tostring(self.activeQuestCount or 0).."\n"..
        "Objectives: "..tostring(tgetn(self.activeObjectives or {})).."  resolved "..tostring(resolved)..
            "  missing "..tostring(self.unresolvedObjectives or 0).."\n"..
        "Map markers: "..tostring(self.markerCount or 0).."\n\n"..
        "|cffffcc33LIKELY STATUS|r\n"..diagnosis.."\n\n"..
        "|cffffcc33NEXT ACTION|r\n"..action
end

function QA:ApplyDiagnosticLayout264()
    if not ZygorGuidesViewerFrame then return end
    local screenWidth=(UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1024
    local screenHeight=(UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 768
    local frameWidth=1000
    local frameHeight=820
    if screenWidth>0 and frameWidth>screenWidth-30 then frameWidth=screenWidth-30 end
    if screenHeight>0 and frameHeight>screenHeight-30 then frameHeight=screenHeight-30 end
    if frameWidth<900 then frameWidth=900 end
    if frameHeight<700 then frameHeight=700 end
    ZygorGuidesViewerFrame:SetWidth(frameWidth)
    ZygorGuidesViewerFrame:SetHeight(frameHeight)
    if ZygorGuidesViewerFrameMaster then
        ZygorGuidesViewerFrameMaster:SetWidth(frameWidth)
        ZygorGuidesViewerFrameMaster:SetHeight(frameHeight)
    end

    local rightX=floor(frameWidth*0.53)
    if ZygorClassicDebugText82 then
        ZygorClassicDebugText82:ClearAllPoints()
        ZygorClassicDebugText82:SetPoint("TOPLEFT",ZygorGuidesViewerFrame,"TOPLEFT",rightX,-58)
        ZygorClassicDebugText82:SetWidth(frameWidth-rightX-24)
        ZygorClassicDebugText82:SetHeight(frameHeight-120)
        ZygorClassicDebugText82:SetFont("Fonts\\FRIZQT__.TTF",9)
        ZygorClassicDebugText82:SetJustifyH("LEFT")
        ZygorClassicDebugText82:SetJustifyV("TOP")
    end
    if ZygorClassicHealthText263 then
        ZygorClassicHealthText263:ClearAllPoints()
        -- The current-step summary can contain six or more action rows.  Keep
        -- health below its worst-case footprint rather than letting the two
        -- independent font strings draw through one another.
        ZygorClassicHealthText263:SetPoint("TOPLEFT",ZygorGuidesViewerFrame,"TOPLEFT",20,-305)
        ZygorClassicHealthText263:SetWidth(rightX-45)
        ZygorClassicHealthText263:SetHeight(frameHeight-390)
        ZygorClassicHealthText263:SetFont("Fonts\\FRIZQT__.TTF",11)
    end
end

function QA:RefreshHealth263()
    if not ZygorGuidesViewerFrame then return end
    if not ZygorClassicHealthText263 then
        ZygorClassicHealthText263=ZygorGuidesViewerFrame:CreateFontString(
            "ZygorClassicHealthText263","OVERLAY","GameFontHighlightSmall")
        ZygorClassicHealthText263:SetPoint("TOPLEFT",ZygorGuidesViewerFrame,"TOPLEFT",20,-305)
        ZygorClassicHealthText263:SetWidth(365)
        ZygorClassicHealthText263:SetHeight(415)
        ZygorClassicHealthText263:SetJustifyH("LEFT")
        ZygorClassicHealthText263:SetJustifyV("TOP")
        ZygorClassicHealthText263:SetFont("Fonts\\FRIZQT__.TTF",12)
    end
    self:ApplyDiagnosticLayout264()
    ZygorClassicHealthText263:SetText(self:HealthText263())
end

-- Compat_112's public diagnostics bridge already appends this module's block.
-- Only install the fallback wrapper on builds where that bridge is absent;
-- wrapping both paths composed the same expensive diagnostics twice.
if ZygorClassic_UpdateDebug82 and not ZygorClassic_RefreshDiagnostics266 then
    QA.baseDebugUpdate255=ZygorClassic_UpdateDebug82
    ZygorClassic_UpdateDebug82=function()
        QA.baseDebugUpdate255()
        if not ZygorClassicDebugText82 then return end
        local current=ZygorClassicDebugText82:GetText() or ""
        local firstBreak=string.find(current,"\n",1,true)
        local diagnostics=QA:DiagnosticText()
        if firstBreak then
            current=string.sub(current,1,firstBreak)..diagnostics.."\n"..string.sub(current,firstBreak+1)
        else
            current=diagnostics.."\n"..current
        end
        ZygorClassicDebugText82:SetText(current)
    end
end

function QA:SyncChecks()
    local settings=self:GetSettings()
    for key,check in pairs(self.checks) do check:SetChecked(settings[key] and 1 or nil) end
end

local function createCheck(name,label,key,x,y)
    local check=CreateFrame("CheckButton",name,ZygorClassicHelp252,"UICheckButtonTemplate")
    check:SetWidth(24)
    check:SetHeight(24)
    check:SetPoint("TOPLEFT",ZygorClassicHelp252,"TOPLEFT",x,y)
    check.setting=key
    local text=getglobal(name.."Text")
    if text then text:SetText(label) text:SetTextColor(0.90,0.90,0.90) end
    check:SetScript("OnClick",function()
        local settings=QA:GetSettings()
        settings[this.setting]=this:GetChecked() and true or false
        QA:ForceRefresh()
        QA:UpdateRoute()
    end)
    QA.checks[key]=check
end

function QA:CreateHelpOptions()
    if not ZygorClassicHelp252 or ZygorClassicQuestAssistTitle253 then return end
    ZygorClassicHelp252:SetWidth(610)
    ZygorClassicHelp252:SetHeight(650)
    if ZygorClassicHelpBody252 then
        ZygorClassicHelpBody252:SetWidth(570)
        ZygorClassicHelpBody252:SetHeight(485)
        ZygorClassicHelpBody252:SetText(ZygorClassicHelpBody252:GetText()..
            "\n\n|cffffcc33QUEST ASSIST|r\n"..
            "- Hover a quest mob to see every matching active quest and drop. Sword/item clusters cover all incomplete objectives in your quest log; click one to point the arrow at it. Gold dots connect you to the selected waypoint on the minimap and zone map. Type /zqa for live status."
        )
    end
    ZygorClassicQuestAssistTitle253=ZygorClassicHelp252:CreateFontString(
        "ZygorClassicQuestAssistTitle253","OVERLAY","GameFontNormal")
    ZygorClassicQuestAssistTitle253:SetPoint("TOPLEFT",ZygorClassicHelp252,"TOPLEFT",20,-548)
    ZygorClassicQuestAssistTitle253:SetText("Recommended quest-assist settings")
    ZygorClassicQuestAssistTitle253:SetTextColor(1,0.82,0.18)
    createCheck("ZygorClassicQuestAssistTooltip253","All active-quest tooltips","tooltips",18,-568)
    createCheck("ZygorClassicQuestAssistWorld253","All world-map objectives","worldmap",18,-596)
    createCheck("ZygorClassicQuestAssistMini253","All minimap objectives","minimap",310,-568)
    createCheck("ZygorClassicQuestAssistRoute253","Dotted waypoint route","route",310,-596)
    self:SyncChecks()
end

SLASH_ZYGORQUESTASSIST1="/zqa"
SlashCmdList["ZYGORQUESTASSIST"]=function(message)
    local command=normalize(message)
    local settings=QA:GetSettings()
    local key=nil
    if command=="tooltip" or command=="tooltips" then key="tooltips"
    elseif command=="world" or command=="worldmap" then key="worldmap"
    elseif command=="mini" or command=="minimap" then key="minimap"
    elseif command=="route" or command=="dots" then key="route" end
    if command=="all" then
        settings.tooltips=true settings.worldmap=true settings.minimap=true settings.route=true
        chat("all recommended features enabled.")
        QA:ForceRefresh()
    elseif command=="refresh" then
        QA:ForceRefresh()
        QA:RefreshMarkers()
        QA:UpdateRoute()
        chat("refreshed active quest objectives and route dots.")
    elseif key then
        settings[key]=not settings[key]
        chat(key.." "..(settings[key] and "enabled" or "disabled")..".")
        QA:ForceRefresh()
    else
        chat("TEST294 loaded. Active quests "..tostring(QA.activeQuestCount or 0)..", objective markers "..tostring(QA.markerCount or 0)..", unresolved objectives "..tostring(QA.unresolvedObjectives or 0)..".")
        local worldDotCount=0
        local minimapDotCount=0
        for _,dot in ipairs(QA.worldDots or {}) do if dot:IsShown() then worldDotCount=worldDotCount+1 end end
        for _,dot in ipairs(QA.minimapDots or {}) do if dot:IsShown() then minimapDotCount=minimapDotCount+1 end end
        local hasTarget=ZGV.Pointer and ZGV.Pointer.ArrowFrame and ZGV.Pointer.ArrowFrame.waypoint
        chat("Arrow target "..(hasTarget and "YES" or "NO")..", visible route dots: minimap "..tostring(minimapDotCount)..", map "..tostring(worldDotCount)..".")
        chat("/zqa tooltips, /zqa world, /zqa mini, /zqa route, /zqa refresh, or /zqa all")
        chat("Tooltips "..(settings.tooltips and "ON" or "OFF")..", world map "..(settings.worldmap and "ON" or "OFF")..", minimap "..(settings.minimap and "ON" or "OFF")..", route dots "..(settings.route and "ON" or "OFF")..".")
    end
end

QA.frame=CreateFrame("Frame","ZygorClassicQuestAssistFrame253",UIParent)
QA.frame:RegisterEvent("VARIABLES_LOADED")
QA.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
QA.frame:RegisterEvent("QUEST_LOG_UPDATE")
QA.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
QA.frame:RegisterEvent("WORLD_MAP_UPDATE")
QA.frame:SetScript("OnEvent",function()
    QA:GetSettings()
    QA:CreateHelpOptions()
    QA:ForceRefresh()
end)
QA.frame:SetScript("OnUpdate",function()
    QA.elapsed=QA.elapsed+arg1
    QA.routeElapsed=QA.routeElapsed+arg1
    if QA.elapsed>=0.75 then
        QA.elapsed=0
        local signature=QA:StepSignature()
        if signature~=QA.signature then
            QA.signature=signature
            QA:RefreshMarkers()
        end
    end
    if QA.routeElapsed>=0.30 then
        QA.routeElapsed=0
        QA:UpdateRoute()
    end
    QA.debugElapsed=(QA.debugElapsed or 0)+arg1
    if QA.debugElapsed>=2.0 then
        QA.debugElapsed=0
        if ZygorGuidesViewerFrame and ZygorGuidesViewerFrame:IsShown() and ZygorClassic_RefreshDiagnostics266 then
            ZygorClassic_RefreshDiagnostics266()
            QA:RefreshHealth263()
        end
    end
end)

QA:GetSettings()
QA:CreateHelpOptions()
QA:RefreshHealth263()

if GameTooltip then
    QA.oldTooltipOnShow=GameTooltip:GetScript("OnShow")
    GameTooltip:SetScript("OnShow",function()
        if QA.oldTooltipOnShow then QA.oldTooltipOnShow() end
        QA:EnhanceTooltip()
    end)
end

-- The package revision is owned by Compat_112.lua.  Do not assign it here:
-- this module loads later and previously made a correctly installed TEST297
-- package falsely report the old Quest Assist development revision TEST294.
