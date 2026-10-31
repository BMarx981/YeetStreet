--!strict
-- ParkBuilder (ModuleScript) -> ServerScriptService.ParkBuilder
-- Builds one park's folder, and starts what moves in it while the game
-- runs. ParkService does both for every park when a server starts. A park
-- frozen into the place (its folder saved in workspace.Parks) was built once
-- in Studio by ServerStorage.Dev.ParkFreeze and is only started.
--
-- build makes the folder for an area: for a Park, a concrete floor over its
-- ground, then the build(folder, area) of its module in
-- ServerScriptService.Parks (named by its Id), if it has one. It stamps the
-- folder's Fingerprint attribute with the module's fingerprint(), the tuning
-- its parts were built from.
--
-- start adds a Park's name sign by its arrival point, never saved with the
-- place, then runs the module's start(folder, area), if it has one, for its
-- creatures and anything else that moves. For a saved park it first warns
-- when the module's fingerprint no longer matches the folder's: its tuning
-- has changed since it was frozen, and its saved parts were not rebuilt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local ParkLooks = require(ReplicatedStorage.ParkLooks)
local Tuning = require(ReplicatedStorage.Tuning)

export type ParkModule = {
	build: (folder: Folder, area: MapLayout.Area) -> (),
	start: ((folder: Folder, area: MapLayout.Area) -> ())?,
	fingerprint: (() -> string)?,
	-- Pieces of a saved park that can be rebuilt in place (ParkFreeze.patch).
	patches: { [string]: (folder: Folder, area: MapLayout.Area) -> () }?,
}

local M = Tuning.Map

local ParkBuilder = {}

local FLOOR_THICKNESS = 1
local MAX_PART = 2048 -- engine limit on a part's size along any axis

-- In equal tiles where the park is bigger than one part can be.
local function floor(folder: Folder, area: MapLayout.Area)
	local across = math.ceil(area.Width / MAX_PART)
	local down = math.ceil(area.Depth / MAX_PART)
	local width, depth = area.Width / across, area.Depth / down
	for i = 1, across do
		for j = 1, down do
			local part = Instance.new("Part")
			part.Name = "Floor"
			part.Anchored = true
			part.Size = Vector3.new(width, FLOOR_THICKNESS, depth)
			part.CFrame = CFrame.new(
				area.X - area.Width / 2 + (i - 0.5) * width,
				M.FloorTop - FLOOR_THICKNESS / 2,
				area.Z - area.Depth / 2 + (j - 0.5) * depth
			)
			part.Color = Color3.fromRGB(170, 170, 165)
			part.Material = Enum.Material.Concrete
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.Parent = folder
		end
	end
end

-- Ahead of the arrival point and to its left. A solid post, and a blank board
-- on top that cars and rays pass through, since it only turns on each client,
-- which also paints it (ParkSigns).
local function sign(folder: Folder, area: MapLayout.Area)
	local S = Tuning.ParkSign
	local look = ParkLooks.of(area.Id).sign
	local spot = (CFrame.new(area.ArriveX, 0, area.ArriveZ) * CFrame.Angles(0, math.rad(area.Heading), 0))
		* CFrame.new(-50, 0, -100)
	local model = Instance.new("Model")
	model.Name = "Sign"

	local postHeight = S.CenterHeight - S.Height / 2
	local post = Instance.new("Part")
	post.Name = "Post"
	post.Anchored = true
	post.Size = Vector3.new(S.PostWidth, postHeight, S.PostWidth)
	post.CFrame = spot * CFrame.new(0, postHeight / 2, 0)
	post.Color = Color3.fromHex(look.post)
	post.Material = (Enum.Material :: any)[look.postMaterial]
	post.Parent = model

	local board = Instance.new("Part")
	board.Name = "Board"
	board.Anchored = true
	board.CanCollide = false
	board.CanQuery = false
	board.CanTouch = false
	board.Size = Vector3.new(S.Width, S.Height, S.Thickness)
	board.CFrame = spot * CFrame.new(0, S.CenterHeight, 0)
	board.Color = Color3.fromRGB(22, 22, 26)
	board.Material = Enum.Material.SmoothPlastic
	board:SetAttribute("AreaId", area.Id)
	board:AddTag("ParkSign")
	board.Parent = model

	model.Parent = folder
end

-- The area's module, if it has one.
function ParkBuilder.module(area: MapLayout.Area): ParkModule?
	local modules = ServerScriptService:FindFirstChild("Parks")
	local module = modules and modules:FindFirstChild(area.Id)
	if module and module:IsA("ModuleScript") then
		return (require :: any)(module)
	end
	return nil
end

-- The area's folder, named by its Id and not yet in workspace, or nil for an
-- area with nothing to build.
function ParkBuilder.build(area: MapLayout.Area): Folder?
	local park = ParkBuilder.module(area)
	if area.Kind ~= "Park" and not park then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = area.Id
	if area.Kind == "Park" then
		floor(folder, area)
	end
	if park then
		park.build(folder, area)
		if park.fingerprint then
			folder:SetAttribute("Fingerprint", park.fingerprint())
		end
	end
	return folder
end

-- Starts what moves in the area's folder, once it is in workspace. `saved`
-- says it was saved with the place rather than built just now.
function ParkBuilder.start(folder: Folder, area: MapLayout.Area, saved: boolean)
	if area.Kind == "Park" then
		sign(folder, area)
	end
	local park = ParkBuilder.module(area)
	if not park then
		return
	end
	if saved and park.fingerprint then
		local built = folder:GetAttribute("Fingerprint")
		if built ~= park.fingerprint() then
			warn(
				`ParkBuilder: {area.Name} is saved with the place, but its tuning has changed since it was frozen; its saved parts were not rebuilt (thaw and freeze it again with ServerStorage.Dev.ParkFreeze)`
			)
		end
	end
	if park.start then
		park.start(folder, area)
	end
end

return ParkBuilder
