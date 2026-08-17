assert (ZygorGuidesViewer,"Zygor Guides Viewer not loaded properly!")

local ZGV=ZygorGuidesViewer
local Pointer = {}
ZGV.Pointer = Pointer

-- TEST163: compact runtime breadcrumbs consumed by the existing in-window
-- diagnostics.  Keep these as plain strings/numbers for Lua 5.0 safety.
ZygorPointerDebug163 = ZygorPointerDebug163 or {}
ZygorPointerDebug163.loaded = "yes"
ZygorPointerDebug163.startup = "not called"
ZygorPointerDebug163.ctrlTicks = 0
ZygorPointerDebug163.arrowTicks = 0
ZygorPointerDebug163.showCalls = 0

local _G,assert,table,string,tinsert,tonumber,tostring,type,ipairs,pairs,setmetatable,math,wipe = _G,assert,table,string,tinsert,tonumber,tostring,type,ipairs,pairs,setmetatable,math,wipe

local L=ZGV.L

Pointer.Debug = ZGV.Debug

Pointer.waypoints = {}


local scarlet_cont = 5
local scarlet_zone = 1


local Astrolabe = DongleStub("Astrolabe-0.4-Zygor")

local unusedMarkers = {}


local last_distance=0
local speed=0
local last_speed=0

local initialdist=nil

-- Vanilla has no stable global player-facing API. The rotating player model
-- attached to the minimap exposes GetFacing(), but its child index changes
-- with client builds and other addons (Questie sees 9; old Zygor assumed 49).
local playerFacingFrame112=nil
local function GetPlayerFacing112()
	if playerFacingFrame112 and playerFacingFrame112.GetFacing then
		local ok,value=pcall(playerFacingFrame112.GetFacing,playerFacingFrame112)
		if ok and type(value)=="number" then return value end
		playerFacingFrame112=nil
	end
	local children={Minimap:GetChildren()}
	-- Questie's working 1.12 arrow identifies the rotating player model as
	-- minimap child 9. Prefer that proven Vanilla object; the generic scan can
	-- otherwise select an unrelated child whose GetFacing() is always zero.
	local preferred=children[9]
	if preferred and preferred.GetFacing then
		local ok,value=pcall(preferred.GetFacing,preferred)
		if ok and type(value)=="number" then
			playerFacingFrame112=preferred
			ZygorPointerDebug163.facingChild=9
			return value
		end
	end
	for i=1,table.getn(children) do
		local child=children[i]
		if child and child.GetFacing then
			local ok,value=pcall(child.GetFacing,child)
			if ok and type(value)=="number" then
				playerFacingFrame112=child
				ZygorPointerDebug163.facingChild=i
				return value
			end
		end
	end
	return 0
end

local lastminimapdist=99999
local minimapcontrol_suspension=0
local minimap_lastset = 0

local cuedinged=nil

local profile={}

function Pointer:Startup()
	ZygorPointerDebug163.startup = "entered"
	self:CreateArrowFrame()
	ZygorPointerDebug163.startup = "frame created"

	profile = ZGV.db.profile
	ZygorPointerDebug163.startup = "profile assigned"

	profile.arrowsmooth = true

	--[[
	self.EventFrame = CreateFrame("FRAME")
	self.EventFrame:Show()
	self.EventFrame:SetScript("OnEvent",PointerEventFrame_OnEvent)
	self.EventFrame:RegisterEvent("WORLD_MAP_UPDATE")
	--]]

	local overlay = CreateFrame("FRAME","ZygorGuidesViewerPointerOverlay",WorldMapButton)
	self.OverlayFrame = overlay
	overlay:SetAllPoints(true)
	overlay:SetWidth(1002)
	overlay:SetHeight(668)
	--overlay:SetFrameStrata("DIALOG")
	--overlay:SetFrameLevel(WorldMapButton:GetFrameLevel()+1)
	overlay:SetScript("OnEvent",self.Overlay_OnEvent)
	overlay:RegisterEvent("PLAYER_ENTERING_WORLD")
	overlay:RegisterEvent("PLAYER_ALIVE")
	overlay:RegisterEvent("PLAYER_UNGHOST")
	overlay:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	overlay:RegisterEvent("WORLD_MAP_UPDATE")
	--overlay:EnableMouse(true)
	--overlay:SetScript("OnMouseUp",self.Overlay_OnClick)
	overlay:SetScript("OnUpdate",self.Overlay_OnUpdate)
	--hooksecurefunc("WorldMapButton_OnClick",ZGV.Pointer.hook_WorldMapButton_OnClick)

	local texture = overlay:CreateTexture("ZygorGuidesViewerPointerOverlayTexture","OVERLAY")
	texture:SetAllPoints(true)
	--texture:SetTexture(ZGV.DIR .. "\\Maps\\deadmines")
	texture:SetTexCoord(0,0.975,0,0.65)
	texture:Hide()
	overlay.texture = texture

	local youarehere = overlay:CreateTexture("ZygorGuidesViewerPointerOverlayYouarehere","OVERLAY")
	youarehere:SetTexture(ZGV.DIR .. "\\Skin\\minimaparrow-green-dot")
	overlay.youarehere = youarehere


	--hooksecurefunc("WorldMapFrame_OnShow",ZGV.Pointer.hook_WorldMapFrame_OnShow)


	--WorldMapFrame.PlayerCoord = WorldMapFrame:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	--WorldMapFrame.CursorCoord = WorldMapFrame:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	
	--WorldMapFrame.PlayerCoord:SetText("Player")
	--WorldMapFrame.CursorCoord:SetText("Cursor")

	--ZGV.ScheduleRepeatingTimer(self,"FixMapLevel", 1.0)

	Pointer.ready = true
	ZygorPointerDebug163.startup = "ready"

	self:HandleCamRegistration()
end

local is_moving=false
function Pointer:HandleCamRegistration()
	local LibCamera = LibStub.libs["LibCamera-1.0"]
	if not LibCamera then profile.arrowcam = false return end
	if profile.arrowcam then
		local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0")
		if not CallbackHandler then profile.arrowcam = false end
		if not self.callbacks then
			self.callbacks = CallbackHandler:New(self)
		end
		LibCamera.RegisterCallback(self,"LibCamera_Update")
		--[[
		hooksecurefunc("TurnOrActionStart",function() is_moving=true print("toastart") end)
		hooksecurefunc("TurnOrActionStop",function() is_moving=false print("toastop") end)
		hooksecurefunc("CameraOrSelectOrMoveStart",function() is_moving=true print("cosomstart") end)
		hooksecurefunc("CameraOrSelectOrMoveStop",function() is_moving=false print("cosomstop") end)
		hooksecurefunc("MoveForwardStart",function() is_moving=true print("mfstart") end)
		hooksecurefunc("MoveForwardStop",function() is_moving=false print("mfstop") end)
		hooksecurefunc("MoveAndSteerStart",function() is_moving=true print("masstart") end)
		hooksecurefunc("MoveAndSteerStop",function() is_moving=false print("masstop") end)
		--]]
	else
		LibCamera.UnregisterCallback(self,"LibCamera_Update")
	end
end

local cam_yaw=0
function Pointer:LibCamera_Update(target,p,y,d)
	cam_yaw=y
	--print (p.." "..y.." "..d)
end



--[[
local numlevels=0
local oldlevel=1
function Pointer.FixMapLevel()
	local x,y = GetPlayerMapPosition("player")
	if x<=0 and y<=0 then
		-- perhaps wrong floor indeed.
		numlevels = GetNumDungeonMapLevels()
		if numlevels>1 then
			oldlevel = GetCurrentMapDungeonLevel()
			for lev=1,numlevels do
				if lev~=oldlevel and GetPlayerMapPosition("player")>0 then
					GetCurrentMapDungeonLevel()
			end
		end
end
--]]

--[[
	data elements:
	title - guess
	type - 'way' 'poi' 'manual' 'corpse'
	icon - texture path
	onminimap - 'always' 'zone'
	overworld - show on world map
	persistent - don't hide when arrived at
--]]
function Pointer:SetWaypoint (c,z,x,y,data)
	if not data then data={} end
	if not data.title then data.title="Waypoint" end
	if not data.type then data.type="way" end
	if not data.icon then data.icon=ZGV.DIR .. "\\Skin\\minimaparrow-green-dot" end
	if not data.edgeicon then data.edgeicon=ZGV.DIR .. "\\Skin\\minimaparrow-green-edge" end

	local waypoint = self:CreateMapMarker (c,z,x,y,data)

	--ZGV:Debug("Adding waypoint type "..data.type.." in "..c..","..z..","..x..","..y)

	if not waypoint then return end

	waypoint.t=data.title
	waypoint.type=data.type
	-- Quest-assist markers are pooled with normal guide markers.  Explicitly
	-- clear these optional flags so a recycled marker cannot hide a later guide
	-- waypoint or suppress its arrow.
	waypoint.noarrow=data.noarrow and true or nil
	waypoint.hideworld=data.hideworld and true or nil
	waypoint.hideminimapsetting=data.hideminimapsetting and true or nil
	waypoint.hideminimapedge=data.hideminimapedge and true or nil

	waypoint.minimapFrame.icon:SetTexture(data.icon)
	waypoint.worldmapFrame.icon:SetTexture(data.icon)
	waypoint.minimapFrame.arrow:SetTexture(data.edgeicon)

	Pointer.MinimapButton_OnUpdate(waypoint.minimapFrame,1000)

	if waypoint.type~="poi" and not waypoint.noarrow then
		self:ShowArrow(waypoint)
	end

	self.waypoints[waypoint]=1

	return waypoint
end

function Pointer:CreateMapMarker (c,z,x,y,data)
	--ZGV:Debug("Internal CreateMapMarker: "..tostring(c).." "..tostring(z).." "..tostring(x).." "..tostring(y).." "..tostring(title))
	if not c and type(z)=="string" then
		c,z = ZGV:GetMapZoneNumbers(z)
	end
	if not c and not z then
		c,z = GetCurrentMapContinentAndZone()
	end
	--ZGV:Debug("Internal CreateMapMarker nums: "..tostring(c).." "..tostring(z).." "..tostring(x).." "..tostring(y).." "..tostring(title))

	--[[
	if c==-1 and z==0 and GetMapInfo()=="ScarletEnclave" then
		c,z = scarlet_cont,scarlet_zone
	end
	--]]

	if not c or not z or not x or x<0 or not y or y<0 then
		--ZGV:Print("Invalid zone, or what?")
		return
	end

	if x>1 or y>1 then
		x=x/100
		y=y/100
	end

	local waypoint = self:GetMarker()
	-- Clear TEST253 visibility flags before applying fresh data because markers
	-- are recycled from a shared pool.
	waypoint.noarrow=nil
	waypoint.hideworld=nil
	waypoint.hideminimapsetting=nil
	waypoint.hideminimapedge=nil
	table.zygor_join(waypoint,{ c=c,z=z,x=x,y=y })
	table.zygor_join(waypoint,data)
	-- TODO: add callbacks for distance detection

	waypoint.minimapFrame.waypoint = waypoint
	waypoint.worldmapFrame.waypoint = waypoint

	waypoint.minimapFrame:EnableMouse(true)
	waypoint.worldmapFrame:EnableMouse(true)

	local lc,lz = GetCurrentMapContinentAndZone()
	waypoint:UpdateWorldMapIcon(lc,lz)
	waypoint:UpdateMiniMapIcon(lc,lz)

	--if lc==c and lz==z then Astrolabe:PlaceIconOnMinimap(waypoint.minimapFrame, c, z, x, y) end
	
	return waypoint
end

function Pointer:ClearWaypoints (waytype)
	local n=0
	for way,w in pairs(self.waypoints) do
		if not waytype or way.type==waytype then
			n=n+1
			self:RemoveWaypoint(way)
		end
	end
	return n
end

function Pointer:RemoveWaypoint(waypoint)
	Astrolabe:RemoveIconFromMinimap(waypoint.minimapFrame)
	waypoint.minimapFrame:Hide()
	waypoint.minimapFrame.waypoint=nil
	waypoint.worldmapFrame:Hide()
	waypoint.worldmapFrame.waypoint=nil

	if self.ArrowFrame.waypoint==waypoint then self:HideArrow() end
	table.insert(unusedMarkers, waypoint)
	self.waypoints[waypoint]=nil
end

function Pointer:HideArrow()
	self.ArrowFrame.waypoint = nil
	self:ResetMinimapZoom() -- to perhaps reset the zoom
	self.ArrowFrame:Hide()
end

function Pointer:ShowArrow(waypoint)
	ZygorPointerDebug163.showCalls = (ZygorPointerDebug163.showCalls or 0) + 1
	ZygorPointerDebug163.lastShow = waypoint and (tostring(waypoint.c)..","..tostring(waypoint.z).." "..tostring(waypoint.x)..","..tostring(waypoint.y)) or "nil waypoint"
	if waypoint.type~="manual" then self:ClearWaypoints("manual") end

	Astrolabe:PlaceIconOnMinimap(waypoint.minimapFrame, waypoint.c, waypoint.z, waypoint.x, waypoint.y) -- if it's not already there, place it

	self.ArrowFrame.waypoint = waypoint
	self.ArrowFrame:SetFrameStrata("TOOLTIP")
	self.ArrowFrame:SetFrameLevel(100)
	-- A new waypoint must calculate its own arrival state.
	self.ArrowFrame.z112arrived = nil
	self.ArrowFrame.z112DirectionGood = nil
	self.ArrowFrame.z112VisualAngle = nil
	self.ArrowFrame.z112AtlasCell = nil

	last_distance=0
	speed=0
	lastbeeptime=GetTime()+3
	cuedinged=nil

	initialdist = nil
	lastminimapdist=99999

	-- TEST292: keep the waypoint and minimap marker alive when the player hides
	-- the screen arrow, but never briefly show the frame.  ArrowFrame_OnUpdate
	-- also guards this state; checking here removes the one-frame flash caused
	-- by route providers repeatedly calling ShowArrow.
	if ZygorClassicDB and ZygorClassicDB.arrowEnabled287==false then
		ZygorPointerDebug163.state="disabled before show"
		self.ArrowFrame:Hide()
		return
	end

	--self.ArrowFrame.temporarilyhidden = true
	self.ArrowFrame:Show()
end

--[[
function Pointer:GetWaypointBearings(way)
	--local dx,dy = 
	if type(way)==number then way=self.waypoints[way] end

end
--]]

local markerproto = {}
local markermeta = {__index=markerproto}

function Pointer:GetMarker()
	local marker = table.remove(unusedMarkers)
	if marker then return marker end

	-- create a new marker
	marker = {visible=true}
	setmetatable(marker,markermeta)

	marker.minimapFrame = CreateFrame("Button", nil, Minimap, "ZygorGuidesViewerPointerMinimapMarker")
	marker.worldmapFrame = CreateFrame("Button", nil, self.OverlayFrame, "ZygorGuidesViewerPointerWorldMapMarker")

	return marker
end

function markerproto:Hide(c,z)
	self.minimapFrame:Hide()
	self.worldmapFrame:Hide()
	self.visible = false
end

function markerproto:Show()
	self.minimapFrame:Show()
	self.worldmapFrame:Show()
	self.visible = true
end

function markerproto:UpdateWorldMapIcon(c,z)
	local show=true
	if not ZGV.Pointer.OverlayFrame:IsShown() or self.hidden or self.hideworld then show=false end

	if show and not c then c,z=GetCurrentMapContinentAndZone() end
	-- Cross-zone quest markers are useful on a continent map, but projecting
	-- them onto an open city/zone map creates unrelated bronze icons.
	if show and (not self.overworld or (z and z>0)) then
		if self.c~=c or self.z~=z then show=false end
	end
	
	if show then
		local x,y = Astrolabe:PlaceIconOnWorldMap(ZGV.Pointer.OverlayFrame, self.worldmapFrame, self.c, self.z, self.x, self.y)
		if not x or not y or x<0 or y<0 or x>1 or y>1 then
			show=false
		end
	end

	if show then
		self.worldmapFrame:Show()
		self.worldmapFrame.icon:ClearAllPoints()
		self.worldmapFrame.icon:SetAllPoints()
		--ZGV:Print("Showing "..way.title)
	else
		self.worldmapFrame:Hide()
	end
end

function markerproto:UpdateMiniMapIcon(c,z)
	if not c then c,z=GetCurrentMapContinentAndZone() end
	local allowMinimap=profile.minicons or self.type=="questobjective253"
	if allowMinimap and not self.hidden and not self.hideminimapsetting and (self.onminimap=="always" or ((self.onminimap=="zone" or self.onminimap=="zonedistance" or ZGV.Pointer.ArrowFrame.waypoint==self) and c==self.c and z==self.z)) then
		Astrolabe:PlaceIconOnMinimap(self.minimapFrame, self.c, self.z, self.x, self.y)
	else
		Astrolabe:RemoveIconFromMinimap(self.minimapFrame)
	end
end



-----------------------------------------------------------------------
--[[
do
	local lastx,lasty
	local x,y,zone
	function Pointer:GetPlayerPosition()
		local x,y = GetPlayerMapPosition("player")
	end
end

function Pointer:GetDistFromPlayer(c,z,x,y)
	local pc,pz,px,py

	local px, py = GetPlayerMapPosition("player")
	px, py, pzone = self:GetCurrentPlayerPosition()
	if pzone then
		pzone = BZL[pzone]
	end

	if px == 0 or py == 0 or not px or not py then
		return nil
	end
	if pzone and BZH[pzone] then
		pzone = BZL[pzone]
	end
	if zone and BZH[zone] then
		zone = BZL[zone]
	end
	if not zone then
		zone = GetRealZoneText()
	end
	if not pzone then
		pzone = zone
	end
	local dist = Tourist:GetYardDistance(zone, x, y, pzone, px, py)
	return dist
end
--]]


-- Code taken from HandyNotes, thanks Xinhuan
---------------------------------------------------------
-- Public functions for plugins to convert between MapFile <-> C,Z
--

--[[
local continentMapFile = {
	[WORLDMAP_COSMIC_ID] = "Cosmic", -- That constant is -1
	[0] = "World",
	[1] = "Kalimdor",
	[2] = "Azeroth",
	[3] = "Expansion01",
	[scarlet_cont] = "ScarletEnclave",
}
local reverseMapFileC = {}
local reverseMapFileZ = {}
for C in pairs(Astrolabe.ContinentList) do
	for Z = 1, ZGV_len(Astrolabe.ContinentList[C]) do
		local mapFile = Astrolabe.ContinentList[C][Z]
		reverseMapFileC[mapFile] = C
		reverseMapFileZ[mapFile] = Z
	end
end
for C = -1, 3 do
	local mapFile = continentMapFile[C]
	reverseMapFileC[mapFile] = C
	reverseMapFileZ[mapFile] = 0
end
--]]

--[[
function Pointer:GetMapFile(C, Z)
	if type(C)=="string" then return end
	if not C or not Z then return end
	if Z == 0 then
		return continentMapFile[C]
	elseif C > 0 then
		return Astrolabe.ContinentList[C][Z]
	end
end
function Pointer:GetCZ(mapFile)
	return reverseMapFileC[mapFile], reverseMapFileZ[mapFile]
end
--]]

local function FormatDistance(dist)
	if profile.arrowmeters then
		local mdist = dist * 0.9144
		if mdist>1000 then
			return string.format("%.1f km",mdist/1000)
		else
			return string.format("%d m",mdist)
		end
	else
		if dist>1760 then
			return string.format("%.1f mil",dist/1760)
		else
			return string.format("%d yd",dist)
		end
	end
end


---------------
function Pointer:CreateArrowFrame()
	self.ArrowFrame = CreateFrame("Frame","ZygorGuidesViewerPointerArrowFrame",UIParent,"ZygorGuidesViewerFloatingArrow")
	-- Keep navigation visible above the large diagnostic/player windows. They
	-- occupy the arrow's normal top-center area and can otherwise cover it.
	self.ArrowFrame:SetFrameStrata("TOOLTIP")
	self.ArrowFrame:SetFrameLevel(100)
	-- Use the bundled pfQuest 108-direction atlas instead of rotating the
	-- narrow silver triangle.  TEST278 keeps the layout frame transparent so
	-- only the arrow and navigation text are visible.
	self.ArrowFrame.z112AtlasArrow=true
	self.ArrowFrame:SetWidth(260)
	self.ArrowFrame:SetHeight(115)
	if self.ArrowFrame.arrow then
		self.ArrowFrame.arrow:SetTexture("Interface\\AddOns\\ZygorGuidesViewer\\Skin\\pfquest-arrow")
		self.ArrowFrame.arrow:ClearAllPoints()
		self.ArrowFrame.arrow:SetPoint("TOP",self.ArrowFrame,"TOP",0,-7)
		self.ArrowFrame.arrow:SetWidth(72)
		self.ArrowFrame.arrow:SetHeight(54)
	end
	if self.ArrowFrame.here then
		self.ArrowFrame.here:ClearAllPoints()
		self.ArrowFrame.here:SetPoint("TOP",self.ArrowFrame,"TOP",0,-8)
	end
	if self.ArrowFrame.title then
		self.ArrowFrame.title:ClearAllPoints()
		self.ArrowFrame.title:SetPoint("TOP",self.ArrowFrame,"TOP",0,-63)
		self.ArrowFrame.title:SetWidth(250)
		self.ArrowFrame.title:SetHeight(46)
		self.ArrowFrame.title:SetShadowColor(0,0,0,1)
		self.ArrowFrame.title:SetShadowOffset(1,-1)
	end

	-- The template already assigns the arrow texture.  The old two-step
	-- SetTexture(true) / SetTexture(path, false) refresh used signatures that
	-- are not valid on the 1.12 client and could abort startup before the
	-- always-visible controller frame was created.
	self.ArrowFrame:Hide()

	self.ArrowFrameCtrl = CreateFrame("Frame",nil,UIParent,nil)
	self.ArrowFrameCtrl:SetScript("OnUpdate",self.ArrowFrameControl_OnUpdate)
	self.ArrowFrameCtrl:Show()

	self:SetupArrowFreeze()
	self:SetScale(profile.arrowscale)
end

function Pointer:SetupArrowFreeze()
	self.ArrowFrame:EnableMouse(not profile.arrowfreeze)
	self.ArrowFrame:RegisterForDrag(not profile.arrowfreeze and "LeftButton")
end

function Pointer:UpdateWaypoints()
	-- worldmap updates only, so far
	for way,w in pairs(self.waypoints) do
		Astrolabe:PlaceIconOnWorldMap(WorldMapFrame, way.worldmapFrame, way.c, way.z, way.x, way.y )
	end
end

function Pointer:SetScale(scale)
	if not scale then return end
	self.ArrowFrame:SetScale(scale)
	self.ArrowFrame:SetScale(scale)
	self.ArrowFrame:SetScale(scale)
	self.ArrowFrame:SetScale(scale)
end

function Pointer:SetFontSize(size)
	local f=self.ArrowFrame.title:GetFont()
	self.ArrowFrame.title:SetFont(f,size)
	--[[
	self.ArrowFrame.dist:SetFont(f,size)
	self.ArrowFrame.eta:SetFont(f,size)

	self.ArrowFrame.title:SetHeight(size)
	self.ArrowFrame.dist:SetHeight(size)
	self.ArrowFrame.eta:SetHeight(size)
	--]]
end


function GetCurrentMapContinentAndZone()
	local c,z = GetCurrentMapContinent(), GetCurrentMapZone()
	if c==-1 and z==0 and GetMapInfo()=="ScarletEnclave" then c,z=5,1 end
	return c,z
end


function Pointer:MinimapZoomChanged()
	if profile.minimapzoom then
		--minimapcontrolled = true
	else
		--minimapcontrolled = false
		Minimap:SetZoom(0)
		MinimapZoomOut:Disable()
		MinimapZoomIn:Enable()
	end
end

function Pointer:ResetMinimapZoom()
	if profile.minimapzoom then
		Minimap:SetZoom(0)
		MinimapZoomOut:Disable()
		MinimapZoomIn:Enable()
	end
	--minimap_lastset = 0
end

local function ShowTooltip(button,tooltip)
	if not button.waypoint or not button.waypoint.t then return end
	tooltip:SetOwner(button,"ANCHOR_BOTTOM")
	tooltip:ClearLines()
	tooltip:SetText(button.waypoint.t)
	if button.waypoint.OnEnter then
		local r = button.waypoint:OnEnter(tooltip)
		if r==false then return end
	end
	--GameTooltip:SetFrameStrata("TOOLTIP")
	tooltip:Show()
end

function Pointer.MinimapButton_OnEnter(self,arg)
	if self.waypoint and (self.icon:IsVisible() or self.arrow:IsVisible()) then
		ShowTooltip(self,GameTooltip)
		GameTooltip:AddLine(string.format("Distance: %s",FormatDistance(self.dist)))
		GameTooltip:Show()
		self.hastooltip=true
	end
end

function Pointer.WorldmapButton_OnEnter(self,arg)
	if self.waypoint and (self.icon:IsVisible() or self.arrow:IsVisible()) then
		WorldMapFrame.old_allowBlobTooltip = WorldMapFrame.allowBlobTooltip
		WorldMapFrame.allowBlobTooltip = false

		ShowTooltip(self,WorldMapTooltip)
	end
end

function Pointer.MinimapButton_OnLeave(self)
	GameTooltip:Hide()
	self.hastooltip=false
end

function Pointer.WorldmapButton_OnLeave(self)
	WorldMapTooltip:Hide()

	WorldMapFrame.allowBlobTooltip = WorldMapFrame.old_allowBlobTooltip
	WorldMapFrame.old_allowBlobTooltip = nil
end


function Pointer.MinimapButton_OnUpdate(self,elapsed)
	local c = self.minimap_count
	if not c then c=0 end
	c = c + elapsed
	if c < 0.1 then
		self.minimap_count = c
		return
	end
	elapsed = c
	self.minimap_count = 0

	if not profile.minicons then self.icon:Hide() self.arrow:Hide() return end

	local dist,x,y = Astrolabe:GetDistanceToIcon(self)

	if not dist or IsInInstance() then self.icon:Hide() self.arrow:Hide() return end

	self.lastdist=self.dist
	self.dist = dist
	if self.waypoint.OnUpdate then self.waypoint:OnUpdate() end

	if self.waypoint.hidden or self.waypoint.hideminimap then
		self.icon:Hide()
		self.arrow:Hide()
		return
	end

	local edge = Astrolabe:IsIconOnEdge(self)

	if edge then
		-- Quest-assist sources are useful only at their real position.  Turning
		-- every off-screen source into the generic green rim arrow creates a
		-- ring of duplicate-looking waypoints that no longer identifies which
		-- mob/object it represents.  Keep those markers on the world map while
		-- showing only sources that are physically inside the minimap.
		if self.waypoint.hideminimapedge then
			self.icon:Hide()
			self.arrow:Hide()
			return
		end
		self.icon:Hide()
		self.arrow:Show()

		local angle = Astrolabe:GetDirectionToIcon(self)
		angle = angle + 2.356194  -- rad(135)

		if false then -- rotateMinimap CVar does not exist in WoW 1.12.1
			angle = angle - GetPlayerFacing()
		end

		-- Vanilla clamps out-of-range rotated texture coordinates to white.
		-- A half-width radius keeps every sampled corner inside 0..1.
		local sin,cos = math.sin(angle)*0.5, math.cos(angle) * 0.5
		self.arrow:SetTexCoord(0.5-sin, 0.5+cos, 0.5+cos, 0.5+sin, 0.5-cos, 0.5-sin, 0.5+sin, 0.5-cos)
	else
		self.icon:Show()
		self.arrow:Hide()
	end

	-- handle tooltip distance updates
	if self.lastdist~=self.dist and self.hastooltip then
		ZGV.Pointer.MinimapButton_OnEnter(self)
	end

	-- minimap autozoom
	if profile.minimapzoom then
		local Minimap = Minimap
		local getzoom = Minimap:GetZoom()
		if getzoom~=minimap_lastset then
			-- user playing with minimap; suspend our activities for a while
			minimapcontrol_suspension = 5.0
			minimap_lastset = getzoom
		end

		-- are we pointed to?
		if Pointer.ArrowFrame.waypoint==self.waypoint then
			if minimapcontrol_suspension>0 then
				minimapcontrol_suspension = minimapcontrol_suspension - elapsed
			else
				local old_minimap_lastset=minimap_lastset
				local dist = dist*2
				if dist~=lastminimapdist then
					local mapsizes = MinimapSize[Astrolabe.minimapOutside and 'outdoor' or 'indoor']

					minimap_lastset=0
					for i=1,Minimap:GetZoomLevels()-1 do
						if dist<mapsizes[i]*0.7 then minimap_lastset=i end
					end

					if old_minimap_lastset~=minimap_lastset then
						-- sanitise buttons
						if(minimap_lastset == (Minimap:GetZoomLevels() - 1)) then MinimapZoomIn:Disable() else MinimapZoomIn:Enable() end
						if(minimap_lastset == 0) then MinimapZoomOut:Disable() else MinimapZoomOut:Enable() end

						Minimap:SetZoom(minimap_lastset) 
					end
				end
				lastminimapdist=dist
			end
		end
	end
end

function Pointer.MinimapButton_OnClick(self,button)
	if button=="RightButton" then
		if ZGV.Pointer.ArrowFrame.waypoint==self.waypoint then ZGV.Pointer:HideArrow() end
		if self.waypoint.type=="manual" then ZGV.Pointer:RemoveWaypoint(self.waypoint) end
		ZGV:SetWaypoint()
	else
		ZGV.Pointer:ShowArrow(self.waypoint)
	end
end

function Pointer.MinimapButton_OnEvent(self,event,...)
	self=self or this; event=event or _G.event
	-- temporarily unused
	ZGV:Print("MINIMAP ONEVENT "..event)
	if not self.waypoint then self:Hide() return end
	
	if event == "PLAYER_ENTERING_WORLD" then
		local way = self.waypoint

		if way then
			way:UpdateMiniMapIcon()
		end
	end
end

function Pointer.WorldMapButton_OnEvent(self,event,...)
	self=self or this; event=event or _G.event
	local way = self.waypoint
	
	--ZGV:Print("WORLDMAP ONEVENT "..event)
	if event == "WORLD_MAP_UPDATE" then
		--[[
		local show=true
		if not way.showinallzones then
			local c,z = GetCurrentMapContinentAndZone()
			if way.c~=c or way.z~=z then show=false end
		end

		if way and way.OnEvent then way:OnEvent(event,unpack(arg)) end
		if not way or way.hidden then self:Hide() return end
		
		local x,y = Astrolabe:PlaceIconOnWorldMap(ZGV.Pointer.OverlayFrame, self, self.waypoint.c, self.waypoint.z, self.waypoint.x, self.waypoint.y)
		if (x and y and (0 < x and x <= 1) and (0 < y and y <= 1)) then
			self:Show()
		else
			self:Hide()
		end

		self.icon:ClearAllPoints()
		self.icon:SetAllPoints()
		--]]

		--[[
		if GetCurrentMapZone()==0 then
			self:SetWidth(10)
			self:SetHeight(10)
		else
		end
		--]]

		--[[
		self:SetWidth(25)
		self:SetHeight(25)
		--]]

	elseif event == "PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED_NEW_AREA" then
		if way then way:UpdateMiniMapIcon() end
	end
end

local instancemaps = {
	["Deadmines"] = {
		map="deadmines"
	},
	["Sethekk Halls"] = {
		map="sethekkhalls"
	},
	["Mana-Tombs"] = {
		map="manatombs",
		rooms={
			["Ravaged Crypt"]	= {x=459/1000,y=214/667},
			["Crescent Hall"]	= {x=581/1000,y=421/667},
			["Hall of Twilight"]	= {x=381/1000,y=444/667},
		}
	},
}
if not ZGV_DEV then instancemaps={} end

function Pointer.Overlay_OnEvent(self,event,...)
	self=self or this; event=event or _G.event
	if event == "WORLD_MAP_UPDATE" then
		if not WorldMapFrame:IsVisible() then
			return

		elseif IsInInstance() and GetPlayerMapPosition("player")==0 then
			--magic!
			local inst = instancemaps[GetZoneText()]
			if inst then
				ZGV.Pointer.OverlayFrame.texture:SetTexture(ZGV.DIR .. "\\Maps\\" ..inst.map)
				ZGV.Pointer.OverlayFrame.texture:Show()
				ZGV.Pointer.OverlayFrame:EnableMouse(true)

				local room = inst.rooms and inst.rooms[GetMinimapZoneText()]
				if room then
					--ZGV:Print("room")
					self.youarehere:SetPoint("CENTER",self,"TOPLEFT",room.x*self:GetWidth(),-room.y*self:GetHeight())
					self.youarehere:Show()
				else
					self.youarehere:Hide()
				end

				WorldMapFrameTitle:SetText(GetZoneText())
				WorldMapFrameAreaLabel:SetAlpha(0)
			end

			for way,w in pairs(ZGV.Pointer.waypoints) do
				way:Hide()
			end

		else
			--magic!
			-- hide instance overlay
			ZGV.Pointer.OverlayFrame.texture:Hide()
			ZGV.Pointer.OverlayFrame:EnableMouse(false)
			WorldMapFrameAreaLabel:SetAlpha(1)

			--ZGV:Print("showing...")
			local c,z = GetCurrentMapContinentAndZone()
			local count=0
			for way,w in pairs(ZGV.Pointer.waypoints) do
				way:UpdateWorldMapIcon(c,z)
				if way.worldmapFrame:IsShown() and way.OnEvent then way:OnEvent(event,unpack(arg)) end
			end
		end
	elseif event=="PLAYER_ALIVE" or event=="PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED_NEW_AREA" then
		ZGV:Debug(event.." (dead?)")
		if UnitIsDeadOrGhost("player") and select(2, IsInInstance()) ~= "pvp" and not IsActiveBattlefieldArena() then
			ZGV:Debug("Player dead!")
			-- corpse arrow
			ZGV.Pointer:SetCorpseArrow()
		else
			ZGV.Pointer.corpsearrow = nil
			local n=ZGV.Pointer:ClearWaypoints("corpse")
			if n>0 then ZGV:SetWaypoint() end
		end

		--[[
		for way,w in pairs(ZGV.Pointer.waypoints) do
			way:UpdateMinimapIcon()
		end
		--]]

	elseif event=="PLAYER_UNGHOST" then
		ZGV:Debug("Player unghosted!")
		ZGV.Pointer:ClearWaypoints("corpse")
		ZGV.Pointer.corpsearrow = nil
		ZGV:SetWaypoint()
	end
end
------------------------------------------- ARROW -----------------


--[[
function Pointer.ArrowFrame_OnEvent(self,event,...)
	self=self or this; event=event or _G.event
	if event=="WORLD_MAP_UPDATE" then
		ZGV.Pointer:UpdateWaypoints()
	end
end
--]]



local oldangle = 0


local arrowctrl_elapsed=0

function Pointer.ArrowFrameControl_OnUpdate(self,elapsed)
	self = self or this
	elapsed = elapsed or arg1 or 0
	ZygorPointerDebug163.ctrlTicks = (ZygorPointerDebug163.ctrlTicks or 0) + 1
	arrowctrl_elapsed = arrowctrl_elapsed + elapsed
	-- The directional atlas is inexpensive to redraw.  Updating it at 40 Hz
	-- avoids the visible 20 Hz stepping of the old controller while leaving the
	-- heavier guide, quest and diagnostic polling rates unchanged.
	if arrowctrl_elapsed >= 0.025 then
		local ok,err=pcall(Pointer.ArrowFrame_OnUpdate,Pointer.ArrowFrame,arrowctrl_elapsed)
		if not ok then
			ZygorPointerDebug163.state="ERROR "..tostring(err)
			-- One useful diagnostic is enough; never flood the chat frame every tick.
			self:SetScript("OnUpdate",nil)
		end
		arrowctrl_elapsed = 0
	end
end

-- And we have an onupdating frame even if hidden. Yay!

local title,disttxt,etatxt

local speeds={}
local stoptime=0
local avgspeed=0

local eta_elapsed=0
local etadisp_elapsed=0

local lastbeeptime=GetTime()
local lastturntime=lastbeeptime
local laststoptime=lastbeeptime
local lastmovetime=lastbeeptime

function Pointer.ArrowFrame_OnUpdate(self,elapsed)
	ZygorPointerDebug163.arrowTicks = (ZygorPointerDebug163.arrowTicks or 0) + 1
	-- TEST287: the compact player window owns a saved arrow toggle. Keep the
	-- waypoint itself alive for map/minimap routing while hiding only this frame.
	if ZygorClassicDB and ZygorClassicDB.arrowEnabled287==false then
		ZygorPointerDebug163.state="disabled by player"
		self:Hide()
		return
	end

	--[[
	arrow_throttle = arrow_throttle + elapsed
	if arrow_throttle < 0.05 then return end
	elapsed = arrow_throttle
	arrow_throttle = 0
	--]]

	if not self.waypoint then ZygorPointerDebug163.state="no waypoint" self:Hide() return end
	-- The original viewer frame is intentionally replaced by the Vanilla
	-- backport UI.  Watching ZGV.Frame here hid a valid arrow a few seconds
	-- after login because that obsolete frame stays hidden.  Backport routes
	-- remain visible independently of the legacy guide-frame option.
	if profile.hidearrowwithguide and not ZygorClassicPlayerFrame246 and
	   self.waypoint.type=="way" and not ZGV.Frame:IsVisible() then
		ZygorPointerDebug163.state="hidden with guide"
		self:Hide()
		return
	end
	--if GetCurrentMapContinentAndZone()~=self.waypoint.c then end

	local dist,x,y = Astrolabe:GetDistanceToIcon(self.waypoint.minimapFrame)

	if not dist then
		dist=9999999
		x=0
		y=1000
	end

	if IsInInstance() then ZygorPointerDebug163.state="hidden in instance" self:Hide() return end

	-- okay, we're live. 3, 2, 1, action!

	self:Show()
	ZygorPointerDebug163.state="active dist="..tostring(dist)

	local msin,mcos,mabs=math.sin,math.cos,math.abs

	local playerangle = GetPlayerFacing112()
	ZygorPointerDebug163.facing=playerangle
	local angle=0

	-- Vanilla map coordinates jitter near a waypoint.  A single 10-yard
	-- threshold made the arrow and arrival graphic alternate rapidly.  Use
	-- hysteresis: arrive at 10 yards, but do not leave arrival mode until 14.
	if self.z112arrived then
		if dist > 14.0 then self.z112arrived = false end
	elseif dist <= 10.0 then
		self.z112arrived = true
	end

	if self.z112arrived then
		self.gem:Hide()
		self.gemhl:Hide()
		if self.z112AtlasArrow then
			-- TEST282: use Zygor's original, proven Vanilla arrow texture for the
			-- arrival marker. Flip that front-facing arrow vertically so its tip
			-- points straight down at the ground instead of toward the camera.
			self.here:Hide()
			self.back:Hide()
			self.arrow:Show()
			self.arrow:SetTexture("Interface\\AddOns\\ZygorGuidesViewer\\Skin\\arrow")
			self.arrow:SetWidth(64)
			self.arrow:SetHeight(64)
			self.arrow:SetVertexColor(0.20,1.00,0.20,1)
			self.arrow:SetTexCoord(0,1,1,0)
			self.z112AtlasCell=nil
			self.z112ArrivalTexture=true
			self.z112VisualAngle=nil
			self.arrow:ClearAllPoints()
			-- Keep the downward tip above the ARRIVED label while preserving the
			-- four-pixel vertical bob.
			self.arrow:SetPoint("TOP",self,"TOP",0,5+msin((self.heretime or 0)*5)*4)
			self.z112Bobbing=true
		else
			self.arrow:Hide()
			self.here:Show()
		end
		--self.eta:Hide()
		--self.dist:Hide()

		if not self.heretime then self.heretime=0 end
		self.heretime = self.heretime + elapsed
		if self.heretime>1 and self.waypoint.clearonarrival then
			ZGV.Pointer:RemoveWaypoint(self.waypoint)
			ZGV:SetWaypoint()
			return
		end

		--self.here.zoomy:Play()
		--self.back.turny:Play()
		self.back:SetTexCoord(0,0,0,1,1,0,1,1)

		--[[
			oldangle = oldangle + elapsed * 3
			while oldangle>6.28319 do oldangle = oldangle - 6.28319 end
			local sin,cos = msin(oldangle + 2.356194)*0.71, mcos(oldangle + 2.356194)*0.71
			self.back:SetTexCoord(0.5-sin, 0.5+cos, 0.5+cos, 0.5+sin, 0.5-cos, 0.5-sin, 0.5+sin, 0.5-cos)
			--]]

			--[[
			count = count + 1
			if count >= 55 then
				count = 0
			end

			cell = count
			local column = math.mod(cell, 9)
			local row = floor(cell / 9)

			local xstart = (column * 53) / 512
			local ystart = (row * 70) / 512
			local xend = ((column + 1) * 53) / 512
			local yend = ((row + 1) * 70) / 512
			arrow:SetTexCoord(xstart,xend,ystart,yend)
		--]]
	else
		self.here:Hide()
		--self.back.turny:Stop()
		--self.here.zoomy:Stop()
		self.heretime=0
		if self.z112Bobbing then
			self.arrow:ClearAllPoints()
			self.arrow:SetPoint("TOP",self,"TOP",0,-7)
			if self.z112ArrivalTexture then
				self.arrow:SetTexture("Interface\\AddOns\\ZygorGuidesViewer\\Skin\\pfquest-arrow")
				self.arrow:SetWidth(72)
				self.arrow:SetHeight(54)
				self.z112AtlasCell=nil
				self.z112ArrivalTexture=nil
			end
			self.z112Bobbing=nil
		end

		self.arrow:Show()
		if self.z112AtlasArrow then
			self.gem:Hide()
			self.gemhl:Hide()
			self.back:Hide()
		else
			self.gem:Show()
			self.gemhl:Show()
			self.back:Show()
		end
		self.title:Show()
		--self.eta:Show()
		--self.dist:Show()


		------------- angle
		angle = Astrolabe:GetDirectionToIcon(self.waypoint.minimapFrame)
		ZygorPointerDebug163.bearing=angle
		if not angle then
			angle=3.1415
		else
			--local player = profile.arrowcam and cam_yaw - (is_moving and GetPlayerFacing() or 0) or GetPlayerFacing()
			angle = angle - (profile.arrowcam and cam_yaw or playerangle)
		end

		------------ color
		local ar,ag,ab = 1,0,0
		local br,bg,bb = 0.8,0.7,0
		local cr,cg,cb = 0,1,0

		local perc

		while angle<0 do angle=angle+6.28319 end
		if profile.arrowcolordir then
			perc = mabs(1-angle*0.3183)  -- 1/pi
		else
			if not initialdist then initialdist=dist end
			if initialdist>500 then initialdist=500 end
			if initialdist<100 then initialdist=100 end
			perc=1-(dist/initialdist)
			if perc<0 then perc=0 end
		end
		local r,g,b = ZGV.gradient3(perc, ar,ag,ab, br,bg,bb, cr,cg,cb, 0.8)
		self.gem:SetVertexColor(r,g,b)

		--angle = angle + 2.356194  -- rad(135)

		if self.z112AtlasArrow then
			-- Filter the Vanilla facing signal independently from the guide's old
			-- arrow option.  Interpolate across the shortest side of the 0/2pi seam
			-- so a small turn through north never spins or snaps the long way round.
			local visual=self.z112VisualAngle
			if visual==nil then
				visual=angle
			else
				local delta=angle-visual
				while delta>3.14159 do delta=delta-6.28319 end
				while delta<-3.14159 do delta=delta+6.28319 end
				local blend=elapsed*14
				if blend>1 then blend=1 end
				visual=visual+delta*blend
				while visual>6.28319 do visual=visual-6.28319 end
				while visual<0 do visual=visual+6.28319 end
			end
			self.z112VisualAngle=visual
			angle=visual
		elseif profile.arrowsmooth then
			local dif = angle-oldangle
			if dif>0.001 or dif<-0.001 then
				while dif>3.14159 do dif=dif-6.28319 end
				while dif<-3.14159 do dif=dif+6.28319 end

				angle = angle-dif/(1+elapsed*10)

				--local newdif = newangle-oldangle
				--while newdif>3.14159 do newdif=newdif-6.28319 end
				--while newdif<-3.14159 do newdif=newdif+6.28319 end

				--if newdif*dif>0 then  -- no jittering
				--	angle=newangle
				while angle>6.28319 do angle=angle-6.28319 end
				while angle<0 do angle=angle+6.28319 end
				--end
			end
			oldangle=angle
		end

	
		local sin,cos = msin(angle + 2.356194)*0.5, mcos(angle + 2.356194)*0.5
		if self.z112AtlasArrow then
			-- Green means the waypoint is roughly ahead; red means the player is
			-- facing away. Hysteresis (50 degrees in, 70 degrees out) prevents
			-- rapid color flashing while turning near the boundary.
			local headingError=angle
			if headingError>3.14159 then headingError=6.28319-headingError end
			if self.z112DirectionGood==nil then
				self.z112DirectionGood=headingError<=1.04720
			elseif self.z112DirectionGood and headingError>1.22173 then
				self.z112DirectionGood=false
			elseif not self.z112DirectionGood and headingError<0.87266 then
				self.z112DirectionGood=true
			end
			if self.z112DirectionGood then
				self.arrow:SetVertexColor(0.20,1.00,0.20,1)
			else
				self.arrow:SetVertexColor(1.00,0.18,0.18,1)
			end
			local cell=math.mod(math.floor(angle/6.28319*108+0.5),108)
			if self.z112AtlasCell~=cell then
				local column=math.mod(cell,9)
				local row=math.floor(cell/9)
				local xstart=(column*56)/512
				local ystart=(row*42)/512
				self.arrow:SetTexCoord(xstart,xstart+56/512,ystart,ystart+42/512)
				self.z112AtlasCell=cell
			end
		else
			self.arrow:SetTexCoord(0.5-sin, 0.5+cos, 0.5+cos, 0.5+sin, 0.5-cos, 0.5-sin, 0.5+sin, 0.5-cos)
			self.gem:SetTexCoord(0.5-sin, 0.5+cos, 0.5+cos, 0.5+sin, 0.5-cos, 0.5-sin, 0.5+sin, 0.5-cos)
			self.gemhl:SetTexCoord(0.5-sin, 0.5+cos, 0.5+cos, 0.5+sin, 0.5-cos, 0.5-sin, 0.5+sin, 0.5-cos)
		end


		------------- background

		local wheelangle = angle*16
		sin,cos = msin(wheelangle + 2.356194)*0.5, mcos(wheelangle + 2.356194)*0.5
		self.back:SetTexCoord(0.5-sin, 0.5+cos, 0.5+cos, 0.5+sin, 0.5-cos, 0.5-sin, 0.5+sin, 0.5-cos)

		--[[
		local cell

		local perc = math.abs((math.pi - math.abs(angle)) / math.pi)

		local gr,gg,gb = unpack(TomTom.db.profile.arrow.goodcolor)
		local mr,mg,mb = unpack(TomTom.db.profile.arrow.middlecolor)
		local br,bg,bb = unpack(TomTom.db.profile.arrow.badcolor)
		local r,g,b = ColorGradient(perc, br, bg, bb, mr, mg, mb, gr, gg, gb)		
		arrow:SetVertexColor(r,g,b)

		cell = math.mod(floor(angle / twopi * 108 + 0.5), 108)
		local column = math.mod(cell, 9)
		local row = floor(cell / 9)

		local xstart = (column * 56) / 512
		local ystart = (row * 42) / 512
		local xend = ((column + 1) * 56) / 512
		local yend = ((row + 1) * 42) / 512
		arrow:SetTexCoord(xstart,xend,ystart,yend)
		--]]
	end

	-- labels

	if self.waypoint.t then
		title=self.waypoint.t
	else
		title=nil
	end
	-- The bridge title is redundant beside the guide window. The arrow now
	-- presents only actionable distance and coordinate information.
	if title=="Zygor Waypoint" then title=nil end

	if dist>9999998 then
		disttxt="Far away"
	else
		disttxt = FormatDistance(dist)
	end
	-- Astrolabe already maintains the current player position for this arrow,
	-- so using its cached value adds live coordinates without changing the
	-- world-map zoom or adding another polling loop.
	local playerx,playery=nil,nil
	if Astrolabe.LastPlayerPosition then
		playerx=Astrolabe.LastPlayerPosition[3]
		playery=Astrolabe.LastPlayerPosition[4]
	end
	if (not playerx or not playery or playerx<=0 or playery<=0) and GetPlayerMapPosition then
		playerx,playery=GetPlayerMapPosition("player")
	end
	if playerx and playery and playerx>0 and playery>0 then
		disttxt=disttxt.."\nYou: "..string.format("%.1f, %.1f",playerx*100,playery*100)
	end
	if self.waypoint and self.waypoint.x and self.waypoint.y then
		disttxt=disttxt.."  |  Target: "..
			string.format("%.1f, %.1f",self.waypoint.x*100,self.waypoint.y*100)
	end


	--ZGV:Debug(("dist %.2f  chg %.2f  speed %.2f  ela %.2f"):format(dist,last_distance-dist,speed,eta_elapsed))
	
	local limit,minlimit=30,5

	eta_elapsed = eta_elapsed + elapsed
	if eta_elapsed >= 0.2 then

		speed = (last_distance-dist) / eta_elapsed

		if last_distance == 0 then speed = 0 end

		if last_distance==dist then stoptime=stoptime+eta_elapsed else stoptime=0 end

		--speed=tonumber(("%.2f"):format(speed))
		--ZGV:Print(("dist %.2f  chg %.2f  speed %.2f  thr %.2f"):format(dist,last_distance-dist,speed,eta_elapsed))


		--ZGV:Debug(stoptime)

		if speed>=0 and stoptime<2 then
			table.insert(speeds,1,speed)
			if ZGV_len(speeds)>limit then table.remove(speeds) end
		else
			--if stoptime>=10 then
			speed=0
			wipe(speeds)
			--end
		end

		-- Speed meter. Perhaps one day.
		--[[
		profile.arrowshowspeed = true
		if profile.arrowshowspeed then
			local spd
			if profile.arrowmeters then
				spd=string.format("%.02f km/h",speed) --*3.6
			else
				spd=string.format("%.02f mph",speed) --*2.0454
			end
			print(spd)
			self.eta:SetText(spd)
		end
		--]]
		--ZGV:Print(eta_elapsed)
		
		--ZGV:Print(("elapsed %.2f  mov %.2f  speed %.2f  thr %.2f"):format(elapsed,last_distance-dist,speed,eta_elapsed))

		--ZGV:Debug(("%d stops, %.2f straight"):format(stoptime,t-lastturntime))
		if ZGV.db.profile.audiocues and IsFlying() then
			local t=GetTime()
			if lastplayerangle~=playerangle then lastturntime=t end
			if last_distance==dist then laststoptime=t else lastmovetime=t end
			if t-lastmovetime<=1 and t-laststoptime>3 and t-lastturntime>5 then
				-- if flying, basically.
				-- and beelining for the last 3 seconds.

				-- ZGV:Debug(("will cue; dist=%d initial=%d lastbeep=%d"):format(dist,initialdist,GetTime()-lastbeeptime))
				if dist<=100 and not cuedinged then
					PlaySoundFile("Sound\\Doodad\\BoatDockedWarning.wav")
					-- lastwayding=self.waypoint  -- DO NOT COMPARE WAYPOINTS. They come from a POOL and are REUSED!
					cuedinged=true
					--ZGV:Debug("dinging")
				else
					--ZGV:Debug("not dinging, dist="..dist..", lastway="..(lastwayding and lastwayding.t or "nil"))
				end
				--ZGV:Debug("cuedinged "..tostring(cuedinged))

				-- warning beeps
				if self.gem:IsVisible()  then
					local perc = mabs(1-angle*0.3183)  -- 1/pi
					if perc<=0.9 then
						if t-lastbeeptime>2 then
							PlaySoundFile( [[Sound\Item\Weapons\Ethereal\Ethereal2H3.wav]] )

							UIFrameFlash(self.gem,0.2,0.2,0.2, true,0,0)
							lastbeeptime=t
						end
					end
				end
			end
			lastplayerangle=playerangle
		end



		last_distance = dist
		eta_elapsed = 0
	end

	--ZGV:Print(table.concat(speeds,"  "))

	etadisp_elapsed = etadisp_elapsed + elapsed
	if etadisp_elapsed >= 0.9 then

		local avg,total,count=0,0,0
		for i=1,ZGV_len(speeds) do
			if type(speeds[i])=="number" then
				total=total+speeds[i]
				count=count+1
			end
		end
		if count>0 then avg=total/count end

		--ZGV:Debug("eta: #speeds="..#speeds)
		if ZGV_len(speeds)>=minlimit and avg>0 then
			local eta = math.abs(dist / avg)
			if eta<7200 and eta>0 then
				etatxt=string.format("%01d:%02d",eta / 60, math.mod(eta, 60))
			else
				etatxt=nil
			end
		else
			etatxt=nil
		end
		etadisp_elapsed = 0
	end

	-- Make the close-range state unmistakable on Vanilla.  The legacy
	-- arrow-here texture can fail to draw on some 1.12 renderers, which made a
	-- valid waypoint look as though it vanished after reload at the target.
	local arrivalText=self.z112arrived and "|cff33ff33ARRIVED|r\n" or ""
	self.title:Show()
	self.title:SetText(arrivalText .. (title and "|cffffffff"..title.."|r\n" or "") .. (disttxt and "|cffffcc00"..disttxt.."|r" or "") .. (etatxt and "  |cffff7700"..etatxt.."|r" or "") )

end

function Pointer.ArrowFrame_OnShow(frame)
	lastturntime=GetTime()
end

local leftbutdown
local rightbutdown
local old_c,old_z
local zonechangecount=0
function Pointer.Overlay_OnUpdate(frame,but,...)
	local c,z = GetCurrentMapContinentAndZone()
	
	-- zone change behaviour is out
	
	--[[
	local zonechanged
	if c~=old_c or z~=old_z then zonechangecount=1 end
	old_c,old_z=c,z
	if zonechangecount>0 then
		if not ZygorClassic_IsMouseButtonDown("LeftButton") then leftbutdown=false end
		if not ZygorClassic_IsMouseButtonDown("RightButton") then rightbutdown=false end
		zonechangecount=zonechangecount-1
		return
	end
	--]]

	if ZygorClassic_IsMouseButtonDown("LeftButton") and IsShiftKeyDown() then
		leftbutdown=true
	else
		if leftbutdown then
			leftbutdown=nil
			-- left click

			-- these are processed AFTER click procs. Necessary to IGNORE (not DELAY) clicks.
			local foc,foundWF=GetMouseFocus(),nil
			while foc do if foc==WorldMapButton then foundWF=true end foc=foc:GetParent() end
			if not foundWF then return end
			
			local mapframe = frame:GetParent()

			local x,y=GetCursorPosition()
			--ZGV:Print(x.." "..y)
			x=(x-(frame:GetLeft()*frame:GetEffectiveScale()))/(frame:GetWidth()*frame:GetEffectiveScale())
			y=(y-(frame:GetBottom()*frame:GetEffectiveScale()))/(frame:GetHeight()*frame:GetEffectiveScale())
			y=1-y
			--ZGV:Print(x.." "..y)
			if (x>0 and x<1 and y>0 and y<1) then
				ZGV.Pointer:ClearWaypoints("manual")
				ZGV.Pointer:SetWaypoint(nil,nil,x*100,y*100,{title=WorldMapFrameAreaLabel:GetText(),type="manual",clearonarrival=true,overworld=true,onminimap="always"})
			end
		end
	end
end

function Pointer:SetCorpseArrow()

	if self.corpsearrow then return end
	if not UnitIsDeadOrGhost("player") then ZGV:Debug("Pointer.SetCorpseArrow: not dead!") return end

	local x=0
	local y=0

	local mc,mz=GetCurrentMapContinent(),GetCurrentMapZone()
	-- some magic here...
	local c,z=0,0

	ZGV:Debug("SetCorpseArrow, mc/mz="..mc.."/"..mz)

	x,y = GetCorpseMapPosition()
	if x>0 and y>0 then
		c=mc
		z=mz
	else
		-- different zone, let's search
		ZGV:Debug("SetCorpseArrow, seeking corpse")

		for i=1,select("#",GetMapContinents()) do
			SetMapZoom(i)
			x,y = GetCorpseMapPosition()

			ZGV:Debug("SetCorpseArrow, corpse on c="..tostring(i).."? "..x..":"..y)

			if x>0 and y>0 then c=i break end
		end

		ZGV:Debug("SetCorpseArrow, corpse on cont "..tostring(c))

		if c then
			for oz=1,select("#",GetMapZones(c)) do
				SetMapZoom(c,oz)
				x,y = GetCorpseMapPosition()

				ZGV:Debug("SetCorpseArrow, corpse on z="..tostring(z).."? "..x..":"..y)
				if x>0 and y>0 then z=oz break end
			end
		end

		--[[
		if not c then
			-- failed! set a flag
			self.corpsewait=true
		end
		--]]
		SetMapZoom(mc,mz)
	end

	if x>0 and y>0 and c>0 and z>0 then
		self:ClearWaypoints("corpse")
		self:SetWaypoint(c,z,x,y,{title=L["pointer_corpselabel"..math.random(5)],type="corpse"})
		self.corpsearrow=true
	end
end
