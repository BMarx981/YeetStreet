--!strict
-- LongJump (ModuleScript) -> ServerScriptService.Parks.LongJump
-- The long jump's bigger launchers, built by ParkService into
-- workspace.Parks.LongJump. Each is a runway into a tall curved kicker, beside
-- the hub launcher and firing the same way down the long jump field. The
-- field itself stays clear. Numbers are in Tuning.LongJump.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CurveProfile = require(ReplicatedStorage.CurveProfile)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local CurvedWall = require(ServerScriptService.Pieces.CurvedWall)
local LaunchPad = require(ServerScriptService.Pieces.LaunchPad)

local L = Tuning.LongJump
local GROUND = 0 -- the test park's grass, which the long jump field is part of
local HULL_HEIGHT = Tuning.TestPark.SpawnHeight

local RAMP_COLOR = Color3.fromRGB(196, 196, 190)
local RUNWAY_COLOR = Color3.fromRGB(120, 120, 126)

type Launcher = {
	Name: string,
	X: number,
	Width: number,
	Radius: number,
	Angle: number,
	Steps: number,
	LaunchSpeed: number,
}

local LongJump = {}

-- A point in world space, `y` above the ground. Faces -Z, down the field.
local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, GROUND + y, z)
end

local function buildLauncher(parent: Instance, launcher: Launcher)
	local model = Instance.new("Model")
	model.Name = launcher.Name
	model.Parent = parent

	local depth = CurveProfile.extent(launcher.Radius, launcher.Angle)
	local baseZ = L.LipZ + depth

	local runway = Instance.new("Part")
	runway.Name = "Runway"
	runway.Anchored = true
	runway.Size = Vector3.new(launcher.Width, 0.2, L.RunwayZ - baseZ)
	runway.CFrame = at(launcher.X, -0.05, (L.RunwayZ + baseZ) / 2)
	runway.Color = RUNWAY_COLOR
	runway.Material = Enum.Material.Concrete
	runway.TopSurface = Enum.SurfaceType.Smooth
	runway.BottomSurface = Enum.SurfaceType.Smooth
	runway.Parent = model

	local options: CurvedWall.Options = {
		radius = launcher.Radius,
		endAngle = launcher.Angle,
		steps = launcher.Steps,
		thickness = L.WallThickness,
		color = RAMP_COLOR,
	}
	local kicker = CurvedWall.straight(model, at(launcher.X, 0, baseZ), launcher.Width, options)
	CurvedWall.fill(kicker, GROUND, options)
	local respawn = at(launcher.X, HULL_HEIGHT, L.RunwayZ - 20)
	LaunchPad.top(kicker, launcher.Steps, launcher.LaunchSpeed, respawn)
end

function LongJump.build(folder: Folder, _area: MapLayout.Area)
	for _, launcher in L.Launchers do
		buildLauncher(folder, launcher)
	end
end

return LongJump
