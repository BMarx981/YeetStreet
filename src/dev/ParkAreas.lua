--!strict
-- ParkAreas (ModuleScript) -> ServerStorage.Dev.ParkAreas
-- A Studio tool that marks where the stunt parks and open fields in
-- Tuning.Map sit, for building by hand around them. Parks are built by code
-- when a server starts, so edit mode shows nothing there. Run it from the
-- command bar in edit mode:
--
--   local A = require(game.ServerStorage.Dev.ParkAreas:Clone())
--   A.show()    marks every area in workspace.ParkAreas
--   A.clear()
--
-- The marks are saved with the place, so everyone in Team Create sees them,
-- and nothing about them is solid. ParkService removes them when a server
-- starts, so they never show in game. Run show() again after the layout
-- changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParkAreas = {}

local FOLDER_NAME = "ParkAreas"
local PARK_COLOR = Color3.fromRGB(255, 140, 40)
local OPEN_COLOR = Color3.fromRGB(60, 160, 255)
local MARK_HEIGHT = 0.4 -- just above the grass and any park floor

local function ghost(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

function ParkAreas.clear()
	local old = workspace:FindFirstChild(FOLDER_NAME)
	if old then
		old:Destroy()
	end
end

function ParkAreas.show(): Folder
	ParkAreas.clear()
	-- A fresh copy, in case the command bar hands back an old one after a sync.
	local Tuning = (require :: any)(ReplicatedStorage.Tuning:Clone())

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, area in Tuning.Map.Areas do
		if area.Kind == "Hub" then
			continue
		end
		local color = if area.Kind == "Park" then PARK_COLOR else OPEN_COLOR

		local mark = Instance.new("Part")
		mark.Name = area.Id
		mark.Size = Vector3.new(area.Width, 0.2, area.Depth)
		mark.CFrame = CFrame.new(area.X, MARK_HEIGHT, area.Z)
		mark.Color = color
		mark.Material = Enum.Material.SmoothPlastic
		mark.Transparency = 0.6
		ghost(mark)
		mark.Parent = folder

		local outline = Instance.new("SelectionBox")
		outline.Adornee = mark
		outline.Color3 = color
		outline.LineThickness = 1.5
		outline.Parent = mark
	end
	folder.Parent = workspace
	print(`ParkAreas: marked {#folder:GetChildren()} areas.`)
	return folder
end

return ParkAreas
