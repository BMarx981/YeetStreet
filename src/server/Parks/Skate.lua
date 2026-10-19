--!strict
-- Skate (ModuleScript) -> ServerScriptService.Parks.Skate
-- The skate park's launchers and obstacles, built by ParkService into
-- workspace.Parks.Skate on top of the park's floor. Four launchers with
-- launch pads: the Mega Ramp straight ahead of the arrival, the Vert Ramp and
-- the Half Pipe (pads along the bottom of both walls) on the left, and the Bowl on the right, ringed by a ramp so it
-- can be entered from any side. Rails and a funbox sit between them for free
-- play, and cones, benches, and trash cans get knocked flying. Numbers are in
-- Tuning.Skate.

local CollectionService = game:GetService("CollectionService")
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
local CONE_COLOR = Color3.fromRGB(255, 120, 30)
local BENCH_COLOR = Color3.fromRGB(130, 90, 60)
local CAN_COLOR = Color3.fromRGB(60, 110, 70)

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

	-- The outside ramp hides the space behind the wall, so neither needs fill.
	local center = at(area, B.X, 0, B.Z)
	local depth, height = CurveProfile.extent(B.Radius, B.Angle)
	local bermInner = B.FloorRadius + depth + S.WallThickness
	local bermOuter = bermInner + B.BermRun
	-- Resets come back outside the ramp on the arrival side, facing the bowl.
	local respawn = at(area, B.X, HULL_HEIGHT, B.Z + bermOuter + 30)

	local bowl = CurvedWall.bowl(model, center, B.FloorRadius, B.Slices, wall(B.Radius, B.Angle, B.Steps))
	LaunchPad.top(bowl, B.PadPlanks * B.Slices, B.LaunchSpeed, respawn)

	-- A berm is straight, so only the thickness and color of its options count.
	local straight = wall(0, 0, 0)
	local berm = CurvedWall.berm(model, center, bermOuter, height, B.BermRun, B.BermSlices, B.BermSteps, straight)
	LaunchPad.bottom(berm, B.BermSlices, B.BoostSpeed, respawn)
end

local function buildHalfPipe(parent: Instance, area: MapLayout.Area)
	local H = S.HalfPipe
	local model = Instance.new("Model")
	model.Name = "HalfPipe"
	model.Parent = parent

	-- The walls rise to either side (±X) and the pipe runs along Z, open at
	-- both ends; resets come back just inside the end nearer the arrival.
	local options = wall(H.Radius, H.Angle, H.Steps)
	local center = at(area, H.X, 0, H.Z) * CFrame.Angles(0, math.pi / 2, 0)
	local pipe = CurvedWall.halfPipe(model, center, H.FlatWidth, H.Length, options)
	CurvedWall.fill(pipe, FLOOR, options)
	local respawn = at(area, H.X, HULL_HEIGHT, H.Z + H.Length / 2 - 20)
	LaunchPad.bottom(pipe, H.PadPlanks * 2, H.LaunchSpeed, respawn)

	local depth, height = CurveProfile.extent(H.Radius, H.Angle)
	for _, side in { -1, 1 } do
		local x = H.X + side * (H.FlatWidth / 2 + depth + H.DeckDepth / 2)
		block(model, "Deck", Vector3.new(H.DeckDepth, height, H.Length), at(area, x, height / 2, H.Z), RAMP_COLOR)
	end
end

-- A prop that cars knock flying (PropService): anchored, and standing on the
-- floor with its base at `cframe`.
local function prop(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = block(parent, name, size, cframe * CFrame.new(0, size.Y / 2, 0), color)
	CollectionService:AddTag(part, "Knockable")
	return part
end

-- An upright cylinder, which Roblox lays along X.
local function upright(part: Part, height: number, diameter: number)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = part.CFrame * CFrame.Angles(0, 0, math.pi / 2)
end

local function buildProps(parent: Instance, area: MapLayout.Area)
	local P = S.Props
	local model = Instance.new("Model")
	model.Name = "Props"
	model.Parent = parent

	local z = P.ConeStartZ
	while z >= P.ConeEndZ do
		for _, side in { -1, 1 } do
			local x = S.Mega.X + side * P.ConeX
			local cone = prop(model, "Cone", Vector3.new(1.6, 3, 1.6), at(area, x, 0, z), CONE_COLOR)
			upright(cone, 3, 1.6)
		end
		z -= P.ConeSpacing
	end

	for _, spot in P.Benches do
		local base = at(area, spot.X, 0, spot.Z) * CFrame.Angles(0, math.rad(spot.Turn), 0)
		prop(model, "Bench", Vector3.new(7, 2, 2), base, BENCH_COLOR)
		local can = prop(model, "TrashCan", Vector3.new(2.4, 3.4, 2.4), base * CFrame.new(5.5, 0, 0), CAN_COLOR)
		upright(can, 3.4, 2.4)
	end
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
	buildHalfPipe(folder, area)
	buildRails(folder, area)
	buildFunbox(folder, area)
	buildProps(folder, area)
end

return Skate
