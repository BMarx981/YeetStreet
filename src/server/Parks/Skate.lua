--!strict
-- Skate (ModuleScript) -> ServerScriptService.Parks.Skate
-- The skate park's launchers and obstacles, built by ParkService into
-- workspace.Parks.Skate on top of the park's floor. Four launchers with
-- launch pads: the Mega Ramp straight ahead of the arrival, the Vert Ramp and
-- the Half Pipe (pads along the bottom of both walls) on the left, and the Bowl on the right, ringed by a ramp so it
-- can be entered from any side; jumping across it is the Bowl Gap. Grind
-- rails, a stair set with handrails to grind, a funbox, and a swing set sit
-- between them, and cones, benches, and trash cans get knocked flying.
-- Numbers are in Tuning.Skate.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CurveProfile = require(ReplicatedStorage.CurveProfile)
local GapZones = require(ReplicatedStorage.GapZones)
local GrindRails = require(ReplicatedStorage.GrindRails)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Swings = require(ReplicatedStorage.Swings)
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

	-- Persistent, so streaming never takes it from a client scoring a run.
	local zone = Instance.new("Model")
	zone.Name = "BowlGap"
	zone.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	zone.Parent = model
	local gap = block(zone, "Marker", Vector3.one, center, RAMP_COLOR)
	gap.Transparency = 1
	gap.CanCollide = false
	gap.CanQuery = false
	gap.CanTouch = false
	gap:SetAttribute("GapName", "Bowl Gap")
	gap:SetAttribute("Inner", bermInner - B.GapInside)
	gap:SetAttribute("Outer", bermOuter + B.GapOutside)
	gap:SetAttribute("MinAngle", B.GapAngle)
	CollectionService:AddTag(gap, GapZones.TAG)
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

-- Rails are only seen: the grind (GrindRide) moves a car along them, so
-- nothing about them can snag a car that misses one.
local function ghost(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

-- A grind rail from `a` to `b`, both in world space.
local function rail(parent: Instance, a: Vector3, b: Vector3)
	local mid = (a + b) / 2
	-- A cylinder's length runs along its X axis; turning a facing a quarter
	-- turn lays X along it.
	local part = block(
		parent,
		"Rail",
		Vector3.new((b - a).Magnitude, 1.5, 1.5),
		CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0),
		RAIL_COLOR
	)
	part.Shape = Enum.PartType.Cylinder
	part.Material = Enum.Material.Metal
	ghost(part)
	CollectionService:AddTag(part, GrindRails.TAG)
end

-- A post holding up a rail, from the surface at `foot` up `height`.
local function post(parent: Instance, foot: Vector3, height: number)
	local center = foot + Vector3.new(0, height / 2, 0)
	local part = block(parent, "Post", Vector3.new(1, height, 1), CFrame.new(center), POST_COLOR)
	ghost(part)
end

local function buildRails(parent: Instance, area: MapLayout.Area)
	local R = S.Rails
	local model = Instance.new("Model")
	model.Name = "Rails"
	model.Parent = parent

	for i = 1, R.Count do
		local x = R.X + (i - (R.Count + 1) / 2) * R.Spacing
		rail(model, at(area, x, R.Height, R.StartZ).Position, at(area, x, R.Height, R.StartZ - R.Length).Position)
		local posts = math.floor(R.Length / R.PostSpacing)
		for p = 0, posts do
			post(model, at(area, x, 0, R.StartZ - p * R.Length / posts).Position, R.Height)
		end
	end
end

-- A ramp up to a deck, then stairs down with a handrail along each side.
local function buildStairs(parent: Instance, area: MapLayout.Area)
	local T = S.Stairs
	local model = Instance.new("Model")
	model.Name = "Stairs"
	model.Parent = parent

	local rise = T.Height / T.Steps
	local bottomZ = T.TopZ - T.Steps * T.StepDepth
	block(
		model,
		"Deck",
		Vector3.new(T.Width, T.Height, T.DeckDepth),
		at(area, T.X, T.Height / 2, T.TopZ + T.DeckDepth / 2),
		RAMP_COLOR
	)
	for i = 1, T.Steps - 1 do
		local top = T.Height - i * rise
		block(
			model,
			"Step",
			Vector3.new(T.Width, top, T.StepDepth),
			at(area, T.X, top / 2, T.TopZ - (i - 0.5) * T.StepDepth),
			RAMP_COLOR
		)
	end

	-- A wedge rises toward its +Z end, so turn it to rise toward the deck.
	local ramp = Instance.new("WedgePart")
	ramp.Name = "Ramp"
	ramp.Anchored = true
	ramp.Size = Vector3.new(T.Width, T.Height, T.RampLength)
	ramp.CFrame = at(area, T.X, T.Height / 2, T.TopZ + T.DeckDepth + T.RampLength / 2) * FACE_BACK
	ramp.Color = RAMP_COLOR
	ramp.Material = Enum.Material.Concrete
	ramp.Parent = model

	-- Each handrail follows the line of the step noses, RailHeight above it.
	for _, side in { -1, 1 } do
		local x = T.X + side * (T.Width / 2 - T.RailInset)
		local top = at(area, x, T.Height, T.TopZ).Position
		local bottom = at(area, x, 0, bottomZ).Position
		local lift = Vector3.new(0, T.RailHeight, 0)
		rail(model, top + lift, bottom + lift)
		for _, f in { 0.05, 0.35, 0.65, 0.95 } do
			post(model, top:Lerp(bottom, f), T.RailHeight)
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

-- A row of giant swings (Swings) hanging from a beam on two A-frames, with a
-- kicker in front aimed at the seats and a deck at each end of the row, level
-- with the end seat at the bottom of its swing. The server builds no seats:
-- each client builds and moves its own (SwingSet).
local function buildSwings(parent: Instance, area: MapLayout.Area)
	local W = S.Swings
	local seatWidth, length = Tuning.Swing.SeatWidth, Tuning.Swing.Length
	local model = Instance.new("Model")
	model.Name = "SwingSet"
	model.Parent = parent

	local pivotY = W.SeatHeight + length
	local half = (W.Count - 1) / 2 * W.Spacing + seatWidth / 2 -- out to the end seats' far edges
	local beamHalf = half + W.LegGap
	block(model, "Beam", Vector3.new(2 * beamHalf, 4, 4), at(area, W.X, pivotY, W.Z), POST_COLOR)
	for _, side in { -1, 1 } do
		local top = at(area, W.X + side * beamHalf, pivotY, W.Z).Position
		for _, spread in { -1, 1 } do
			local foot = at(area, W.X + side * beamHalf, 0, W.Z + spread * W.LegSpread).Position
			local leg = CFrame.lookAt((top + foot) / 2, top)
			block(model, "Leg", Vector3.new(3, 3, (top - foot).Magnitude), leg, POST_COLOR)
		end
	end

	for i = 1, W.Count do
		local swing = Instance.new("Model")
		swing.Name = `Swing{i}`
		local x = W.X + (i - (W.Count + 1) / 2) * W.Spacing
		swing:SetAttribute("Pivot", at(area, x, pivotY, W.Z))
		swing:SetAttribute("State", Vector2.new(math.rad(W.StartAngles[i] or 0), 0))
		swing:SetAttribute("RiderId", 0)
		swing.Parent = model
		CollectionService:AddTag(swing, Swings.TAG)
	end

	-- The kicker rises toward the seats from the +Z side.
	local kickDepth = CurveProfile.extent(W.KickRadius, W.KickAngle)
	local kickBaseZ = W.Z + W.LipDistance + kickDepth
	local runwayZ = kickBaseZ + W.RunwayLength
	runway(model, area, W.X, 2 * half, runwayZ, kickBaseZ)
	local options = wall(W.KickRadius, W.KickAngle, W.KickSteps)
	local kicker = CurvedWall.straight(model, at(area, W.X, 0, kickBaseZ), 2 * half, options)
	CurvedWall.fill(kicker, FLOOR, options)
	LaunchPad.top(kicker, W.PadPlanks, W.LaunchSpeed, respawnAt(area, W.X, runwayZ))

	for _, side in { -1, 1 } do
		local inner = half + W.DeckGap
		block(
			model,
			"Deck",
			Vector3.new(W.DeckLength, W.SeatHeight, W.DeckWidth),
			at(area, W.X + side * (inner + W.DeckLength / 2), W.SeatHeight / 2, W.Z),
			RAMP_COLOR
		)
		-- A wedge rises toward its +Z end, so turn that end toward the deck.
		local ramp = Instance.new("WedgePart")
		ramp.Name = "Ramp"
		ramp.Anchored = true
		ramp.Size = Vector3.new(W.DeckWidth, W.SeatHeight, W.RampLength)
		ramp.CFrame = at(area, W.X + side * (inner + W.DeckLength + W.RampLength / 2), W.SeatHeight / 2, W.Z)
			* CFrame.Angles(0, -side * math.pi / 2, 0)
		ramp.Color = RAMP_COLOR
		ramp.Material = Enum.Material.Concrete
		ramp.Parent = model
	end
end

function Skate.build(folder: Folder, area: MapLayout.Area)
	buildMega(folder, area)
	buildVert(folder, area)
	buildBowl(folder, area)
	buildHalfPipe(folder, area)
	buildRails(folder, area)
	buildStairs(folder, area)
	buildFunbox(folder, area)
	buildSwings(folder, area)
	buildProps(folder, area)
end

return Skate
