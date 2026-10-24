--!strict
-- ParkBuilder (ModuleScript) -> ServerScriptService.ParkBuilder
-- Builds one park's folder, and starts what moves in it while the game
-- runs. ParkService does both for every park when a server starts. A park
-- frozen into the place (its folder saved in workspace.Parks) was built once
-- in Studio by ServerStorage.Dev.ParkFreeze and is only started.
--
-- build makes the folder for an area: for a Park, a concrete floor over its
-- ground and a name sign by its arrival point, then the build(folder, area)
-- of its module in ServerScriptService.Parks (named by its Id), if it has
-- one. It stamps the folder's Fingerprint attribute with the module's
-- fingerprint(), the tuning its parts were built from.
--
-- start runs the module's start(folder, area), if it has one, for its
-- creatures and anything else that moves. For a saved park it first warns
-- when the module's fingerprint no longer matches the folder's: its tuning
-- has changed since it was frozen, and its saved parts were not rebuilt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)

export type ParkModule = {
	build: (folder: Folder, area: MapLayout.Area) -> (),
	start: ((folder: Folder, area: MapLayout.Area) -> ())?,
	fingerprint: (() -> string)?,
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

-- Ahead of the arrival point and to its left, facing back at an arriving car.
local function sign(folder: Folder, area: MapLayout.Area)
	local facing = CFrame.new(area.ArriveX, 0, area.ArriveZ) * CFrame.Angles(0, math.rad(area.Heading), 0)
	local part = Instance.new("Part")
	part.Name = "Sign"
	part.Anchored = true
	part.Size = Vector3.new(60, 14, 2)
	part.CFrame = facing * CFrame.new(-50, 12, -100)
	part.Color = Color3.fromRGB(30, 30, 40)
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = folder

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- the face an arriving car looks at
	gui.PixelsPerStud = 20
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = area.Name
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(255, 200, 40)
	label.Parent = gui
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
		sign(folder, area)
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
