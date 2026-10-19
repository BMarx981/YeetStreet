--!strict
-- Skate (ModuleScript) -> ServerScriptService.Parks.Skate
-- The skate park's launchers and obstacles, built by ParkService into
-- workspace.Parks.Skate on top of the park's floor. Three launchers, each with
-- a runway and launch pads: the Mega Ramp straight ahead of the arrival, the
-- Vert Ramp on the left, and the Bowl on the right. Rails and a funbox sit
-- between them for free play. Numbers are in Tuning.Skate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CurveProfile = require(ReplicatedStorage.CurveProfile)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local CurvedWall = require(ServerScriptService.Pieces.CurvedWall)
local LaunchPad = require(ServerScriptService.Pieces.LaunchPad)

local S = Tuning.Skate
local FLOOR = Tuning.Map.FloorTop
local HULL_HEIGHT = Tuning.TestPark.SpawnHeight

local RAMP_COLOR = Color3.fromRGB(196, 196, 190)
local RUNWAY_COLOR = Color3.fromRGB(120, 120, 126)
local RAIL_COLOR = Color3.fromRGB(200, 60, 60)
local POST_COLOR = Color3.fromRGB(60, 60, 66)

local Skate = {}

-- A point in the park, `y` above the floor. Faces -Z, away from the arrival.
local function at(area: MapLayout.Area, x: number, y: number, z: number): CFrame
	return CFrame.new(area.X + x, FLOOR + y, area.Z + z)
end

local FACE_BACK = CFrame.Angles(0, math.pi, 0) -- turns a facing toward +Z

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function wall(radius: number, angle: number, steps: number): CurvedWall.Options
	return {
		radius = radius,
		endAngle = angle,
		steps = steps,
		thickness = S.WallThickness,
		color = RAMP_COLOR,
	}
end

-- A strip of runway from z1 to z2 (z1 > z2), a little above the floor.
local function runway(parent: Instance, area: MapLayout.Area, x: number, width: number, z1: number, z2: number)
	block(parent, "Runway", Vector3.new(width, 0.2, z1 - z2), at(area, x, -0.05, (z1 + z2) / 2), RUNWAY_COLOR)
end

-- Where a reset puts a car that last launched from this runway.
local function respawnAt(area: MapLayout.Area, x: number, z: number): CFrame
	return at(area, x, HULL_HEIGHT, z - 20)
end

local function buildMega(parent: Instance, area: MapLayout.Area)
	local M = S.Mega
	local model = Instance.new("Model")
	model.Name = "MegaRamp"
	model.Parent = parent

	local kickDepth = CurveProfile.extent(M.KickRadius, M.KickAngle)
	local kickBaseZ = M.LipZ + kickDepth
	runway(model, area, M.X, M.Width, M.RunwayZ, kickBaseZ)

	local kickOptions = wall(M.KickRadius, M.KickAngle, M.KickSteps)
	local kicker = CurvedWall.straight(model, at(area, M.X, 0, kickBaseZ), M.Width, kickOptions)
	CurvedWall.fill(kicker, FLOOR, kickOptions)
	LaunchPad.top(kicker, M.PadPlanks, M.LaunchSpeed, respawnAt(area, M.X, M.RunwayZ))

	-- The landing ramp rises toward the kicker, steepest at its top.
	local landOptions = wall(M.LandRadius, M.LandAngle, M.LandSteps)
	local landDepth, landHeight = CurveProfile.extent(M.LandRadius, M.LandAngle)
	local landTopZ = M.LipZ - M.Gap
	local landing =
		CurvedWall.straight(model, at(area, M.X, 0, landTopZ - landDepth) * FACE_BACK, M.LandWidth, landOptions)
	CurvedWall.fill(landing, FLOOR, landOptions)
	block(
		model,
		"Deck",
		Vector3.new(M.LandWidth, landHeight, M.DeckDepth),
		at(area, M.X, landHeight / 2, landTopZ + M.DeckDepth / 2),
		RAMP_COLOR
	)
end

local function buildVert(parent: Instance, area: MapLayout.Area)
	local V = S.Vert
	local model = Instance.new("Model")
	model.Name = "VertRamp"
	model.Parent = parent

	local padEndZ = V.BaseZ + V.PadLength
	runway(model, area, V.X, V.Width, V.RunwayZ, padEndZ)
	LaunchPad.flat(
		model,
		at(area, V.X, 0.1, V.BaseZ + V.PadLength / 2),
		V.Width,
		V.PadLength,
		V.LaunchSpeed,
		respawnAt(area, V.X, V.RunwayZ)
	)

	local options = wall(V.Radius, 90, V.Steps)
	local pipe = CurvedWall.straight(model, at(area, V.X, 0, V.BaseZ), V.Width, options)
	CurvedWall.fill(pipe, FLOOR, options)
	local topZ = V.BaseZ - V.Radius
	block(
		model,
		"Deck",
		Vector3.new(V.Width, V.Radius, V.DeckDepth),
		at(area, V.X, V.Radius / 2, topZ - V.DeckDepth / 2),
		RAMP_COLOR
	)
end

local function buildBowl(parent: Instance, area: MapLayout.Area)
	local B = S.Bowl
	local model = Instance.new("Model")
	model.Name = "Bowl"
	model.Parent = parent

	-- The wall turns left from its start, so starting half the opening past
	-- +Z leaves the opening centered on +Z, facing the arrival.
	local turn = 360 - B.Opening
	local start = 180 + B.Opening / 2
	local options = wall(B.Radius, B.Angle, B.Steps)
	local pivot = at(area, B.X, 0, B.Z) * CFrame.Angles(0, math.rad(start), 0)
	local bowl = CurvedWall.corner(model, pivot, B.FloorRadius, turn, B.Slices, options)
	bowl.Name = "Wall"
	CurvedWall.fill(bowl, FLOOR, options)

	runway(model, area, B.X, B.RunwayWidth, B.RunwayZ, B.Z + B.FloorRadius)
	LaunchPad.flat(
		model,
		at(area, B.X, 0.1, B.Z),
		B.PadWidth,
		B.PadLength,
		B.LaunchSpeed,
		respawnAt(area, B.X, B.RunwayZ)
	)
end

local function buildRails(parent: Instance, area: MapLayout.Area)
	local R = S.Rails
	local model = Instance.new("Model")
	model.Name = "Rails"
	model.Parent = parent

	local centerZ = R.StartZ - R.Length / 2
	for i = 1, R.Count do
		local x = R.X + (i - (R.Count + 1) / 2) * R.Spacing
		local rail = block(
			model,
			"Rail",
			Vector3.new(R.Length, 1.5, 1.5),
			at(area, x, R.Height, centerZ) * CFrame.Angles(0, math.pi / 2, 0),
			RAIL_COLOR
		)
		rail.Shape = Enum.PartType.Cylinder
		rail.Material = Enum.Material.Metal
		local posts = math.floor(R.Length / R.PostSpacing)
		for p = 0, posts do
			local z = R.StartZ - p * R.Length / posts
			block(model, "Post", Vector3.new(1, R.Height, 1), at(area, x, R.Height / 2, z), POST_COLOR)
		end
	end
end

local function buildFunbox(parent: Instance, area: MapLayout.Area)
	local F = S.Funbox
	local model = Instance.new("Model")
	model.Name = "Funbox"
	model.Parent = parent

	local options = wall(F.Radius, F.Angle, F.Steps)
	local depth, height = CurveProfile.extent(F.Radius, F.Angle)
	local edge = F.DeckLength / 2 + depth
	local front = CurvedWall.straight(model, at(area, F.X, 0, F.Z + edge), F.Width, options)
	local back = CurvedWall.straight(model, at(area, F.X, 0, F.Z - edge) * FACE_BACK, F.Width, options)
	CurvedWall.fill(front, FLOOR, options)
	CurvedWall.fill(back, FLOOR, options)
	block(model, "Deck", Vector3.new(F.Width, height, F.DeckLength), at(area, F.X, height / 2, F.Z), RAMP_COLOR)
end

function Skate.build(folder: Folder, area: MapLayout.Area)
	buildMega(folder, area)
	buildVert(folder, area)
	buildBowl(folder, area)
	buildRails(folder, area)
	buildFunbox(folder, area)
end

return Skate
