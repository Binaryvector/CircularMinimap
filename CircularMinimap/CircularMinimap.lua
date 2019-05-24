
--[[
The basic idea of this addon is to add two copies of the map.
Only the map tiles are copied, not the pins or anything else for performance reasons.
The circle can then be approximated like this, by adding a horizontal and a vertical map behind the default map:
       ------
   ----'----'----
---|            |---
|  |            |  |
|  |            |  |
---|            |---
   ----,----,----
       ------
]]--
local ADDON_NAME = "CircularMinimap"
CircularMinimap = {}

LibDAU:VerifyAddon(ADDON_NAME)

--GetTextureFileDimensions
CircularMinimap.textures = {
	["(Circular) Moosetrax Normal Wheel"] = "CircularMinimap/Textures/MNormalWheel.dds",
	["(Circular) Moosetrax Normal Lense Wheel"] = "CircularMinimap/Textures/MNormalLense1Wheel.dds",
	["(Circular) Moosetrax Astro Wheel"] = "CircularMinimap/Textures/MAstroWheel.dds",
	["(Circular) Moosetrax Astro Lense Wheel"] = "CircularMinimap/Textures/MAstroLense1Wheel.dds",
}


CircularMinimap.mapTiles = {}
CircularMinimap.newTiles = {}

-- figure our, which tiles were created yet
ZO_PreHook("CreateControlFromVirtual", function(name, parent, template, index)
	if template ~= "ZO_MapTile" then return end
	if parent ~= ZO_WorldMapContainer then return end
	CircularMinimap.newTiles[index] = true
	EVENT_MANAGER:RegisterForUpdate(ADDON_NAME, 0, CircularMinimap.OnNewTilesUpdate)
end)

-- list of ZO_MapPin methods which will be hooked
CircularMinimap.hookedFunctions = {
	"SetHidden", "SetDimensions", "ClearAnchors", "SetAnchor", "SetTexture",
}

function CircularMinimap.OnNewTilesUpdate()
	EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME)
	if not next(CircularMinimap.newTiles) then return end -- no new tiles
	
	-- for each newly created tile control
	-- create a new tile in the vertical and horizontal scroll container
	for tileIndex, _ in pairs(CircularMinimap.newTiles) do
		local zosTile = _G[ZO_WorldMapContainer:GetName() .. tostring(tileIndex)]
		for i, parent in ipairs(CircularMinimap.container) do
			local tile = CreateControlFromVirtual(
					parent:GetName(),
					parent,
					"ZO_MapTile", tileIndex)
					
			CircularMinimap.mapTiles[tileIndex] = tile
			
			-- hook methods so the new tiles are always copies of the original tile
			for _, functionName in pairs(CircularMinimap.hookedFunctions) do
				local origFunction = zosTile[functionName]
				zosTile[functionName] = function(self, ...)
					origFunction(self, ...)
					origFunction(tile, ...)
				end
			end
			
			-- copy existing properties
			tile:SetTexture(zosTile:GetTextureFileName())
			tile:SetHidden(zosTile:IsHidden())
			tile:SetDimensions(zosTile:GetDimensions())
			local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY, anchorConstrains = zosTile:GetAnchor(0)
			if isValidAnchor then
				tile:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY, anchorConstrains)
			end
			
			tile:SetDrawLevel(-1)
		end
	end	
	
	CircularMinimap.newTiles = {}
end

-- circular border texture
CircularMinimap.background = WINDOW_MANAGER:CreateControl("CircularBackground", ZO_WorldMap, CT_TEXTURE)
CircularMinimap.background:SetDrawLayer(1)
CircularMinimap.background:SetDrawLevel(1)
CircularMinimap.background:SetAnchor(CENTER, ZO_WorldMapScroll, CENTER, 0, 0)
CircularMinimap.background:SetHidden(true)

-- create two new scroll controls, a vertical and a horizontal one.
CircularMinimap.scroll = {}
for i = 1,2 do
	CircularMinimap.scroll[i] = WINDOW_MANAGER:CreateControl("CircularHorizontalScroll" .. i, ZO_WorldMap, CT_SCROLL)
	CircularMinimap.scroll[i]:SetDrawLayer(0)
	CircularMinimap.scroll[i]:SetAnchor(CENTER, ZO_WorldMapScroll, CENTER, 0, 0)
	CircularMinimap.scroll[i]:SetHidden(true)
end

CircularMinimap.container = {
	WINDOW_MANAGER:CreateControl("CircularHorizontalContainer1", CircularMinimap.scroll[1], CT_CONTROL),
	WINDOW_MANAGER:CreateControl("CircularHorizontalContainer2", CircularMinimap.scroll[2], CT_CONTROL)
}

-- on the 500 x 500 circular border image
-- the center scroll has its top left corner at (72, 72)
-- an the vertical scroll has its top left corner at (130,34)
local scale = (500 - 72 * 2)
local shortScale = (250 - 130) * 2 / scale
local longScale = (250 - 34) * 2 / scale
local borderScale = longScale * 500 / 410 -- ratio of the long side of the vertical scroll to the complete border image

ZO_PreHook(ZO_WorldMapScroll, "SetDimensions", function(self, width, height)
	CircularMinimap.scroll[1]:SetDimensions(shortScale * width, longScale * width)
	CircularMinimap.scroll[2]:SetDimensions(longScale * width, shortScale * width)
	CircularMinimap.background:SetDimensions(borderScale * width, borderScale * width)
end)

ZO_PreHook(ZO_WorldMapContainer, "SetDimensions", function(self, ...)
	CircularMinimap.container[1]:SetDimensions(...)
	CircularMinimap.container[2]:SetDimensions(...)
end)

ZO_PreHook(ZO_WorldMapContainer, "SetAnchor", function(self, ...)
	CircularMinimap.container[1]:SetAnchor(...)
	CircularMinimap.container[2]:SetAnchor(...)
end)

local function GetScene()
	return IsInGamepadPreferredMode() and GAMEPAD_WORLD_MAP_SCENE or WORLD_MAP_SCENE
end

ZO_PreHook(VOTANS_MINIMAP, "UpdateBorder", function()
	local inMiniMap = not GetScene():IsShowing()
	if not inMinimap then
		CircularMinimap.scroll[1]:SetHidden(true)
		CircularMinimap.scroll[2]:SetHidden(true)
		CircularMinimap.background:SetHidden(true)
	end
end)

for name, path in pairs(CircularMinimap.textures) do
	VOTANS_MINIMAP:AddBorderStyle(name, name, function(settings, background, frame)
		CircularMinimap.OnNewTilesUpdate()
		
		-- default ESO style from votan's minimap
		local alpha = settings.borderAlpha / 100 or 1
		background:SetCenterColor(0, 0, 0, alpha)
		background:SetEdgeColor(0, 0, 0, alpha)
		background:SetEdgeTexture("/esoui/art/chatwindow/chat_bg_edge.dds", 256, 128, 16)
		background:SetCenterTexture("/esoui/art/chatwindow/chat_bg_center.dds")
		background:SetInsets(16, 16, -16, -16)
		
		-- we have to hide the old border frame
		frame:SetHidden(true)
		
		ZO_WorldMapTitle:ClearAnchors()
		ZO_WorldMapTitle:SetAnchor(TOP, background, TOP, 0, 4)
		
		CircularMinimap.scroll[1]:SetHidden(false)
		CircularMinimap.scroll[2]:SetHidden(false)
		CircularMinimap.background:SetHidden(false)
		CircularMinimap.background:SetTexture(path)
		
		-- move the old background to the bottom of the minimap
		-- and adjust draw levels, so it isn't hidden behind the minimap
		background:ClearAnchors()
		background:SetAnchor(TOPLEFT, ZO_WorldMap, BOTTOMLEFT, -8, -64)
		background:SetAnchor(BOTTOMRIGHT, ZO_WorldMap, BOTTOMRIGHT, 6, 8)
		
		CircularMinimap.oldBackgroundDrawLevel = CircularMinimap.oldBackgroundDrawLevel or background:GetDrawLevel()
		CircularMinimap.oldBackgroundDrawLayer = CircularMinimap.oldBackgroundDrawLayer or background:GetDrawLayer()
		background:SetDrawLevel(2)
		background:SetDrawLayer(1)
	end,
	function(settings, background, frame)
		frame:SetHidden(false)
		
		background:ClearAnchors()
		background:SetAnchor(TOPLEFT, nil, TOPLEFT, -8, -4)
		background:SetAnchor(BOTTOMRIGHT, nil, BOTTOMRIGHT, 6, 0)
		
		background:SetDrawLevel(CircularMinimap.oldBackgroundDrawLevel)
		background:SetDrawLayer(CircularMinimap.oldBackgroundDrawLayer)
		
		CircularMinimap.scroll[1]:SetHidden(true)
		CircularMinimap.scroll[2]:SetHidden(true)
		CircularMinimap.background:SetHidden(true)
		
	end )
end
