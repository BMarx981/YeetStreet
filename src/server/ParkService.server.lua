--!strict
-- ParkService (Script) -> ServerScriptService.ParkService
-- Builds each stunt park in Tuning.Map into its own folder, workspace.Parks.<Id>:
-- a concrete floor over the park's ground and a name sign by its arrival
-- point. A park with a module in ServerScriptService.Parks (named by its Id)
-- also gets that module's build(folder, area) for its launchers and obstacles.
-- A park whose folder is already in workspace was saved with the place, so it
-- is left as it is. Warns at startup about anything wrong with the layout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)

type ParkModule = {
	build: (folder: Folder, area: MapLayout.Area) -> (),
}

local M = Tuning.Map
local areas: { MapLayout.Area } = M.Areas :: any

for _, problem in MapLayout.problems(areas, M.Bounds, M.Gap) do
	warn(`ParkService: {problem}`)
end

-- The area marks for building in edit mode (ServerStorage.Dev.ParkAreas)
-- never show in game.
local marks = workspace:FindFirstChild("ParkAreas")
if marks then
	marks:Destroy()
end

local FLOOR_THICKNESS = 1

local function floor(folder: Folder, area: MapLayout.Area)
	local part = Instance.new("Part")
	part.Name = "Floor"
	part.Anchored = true
	part.Size = Vector3.new(area.Width, FLOOR_THICKNESS, area.Depth)
	part.CFrame = CFrame.new(area.X, M.FloorTop - FLOOR_THICKNESS / 2, area.Z)
	part.Color = Color3.fromRGB(170, 170, 165)
	part.Material = Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder
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

local parks: Instance = workspace:FindFirstChild("Parks") or Instance.new("Folder")
parks.Name = "Parks"
parks.Parent = workspace

local modules = ServerScriptService:FindFirstChild("Parks")

for _, area in areas do
	if area.Kind ~= "Park" or parks:FindFirstChild(area.Id) then
		continue
	end
	local folder = Instance.new("Folder")
	folder.Name = area.Id
	floor(folder, area)
	sign(folder, area)
	local module = modules and modules:FindFirstChild(area.Id)
	if module and module:IsA("ModuleScript") then
		local park: ParkModule = (require :: any)(module)
		park.build(folder, area)
	end
	folder.Parent = parks
end
