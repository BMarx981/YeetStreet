--!strict
-- City (ModuleScript) -> ServerScriptService.Parks.City
-- The dense city, built by ParkService into workspace.Parks.City on top of
-- the park's floor. An avenue runs down the middle from the arrival, cross
-- streets split the rest into blocks of buildings, and open plazas sit at
-- both ends. The Highway Overpass climbs straight down the avenue to a broken
-- end, a kicker with boosters that throws the car on down the avenue.
-- Every building has a curve all around its foot, so a car driven at it
-- rides up the wall instead of stopping dead. Numbers are in Tuning.City.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CurveProfile = require(ReplicatedStorage.CurveProfile)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local Tunnel = require(ReplicatedStorage.Tunnel)
local CurvedWall = require(ServerScriptService.Pieces.CurvedWall)
local LaunchPad = require(ServerScriptService.Pieces.LaunchPad)

local C = Tuning.City
local FLOOR = Tuning.Map.FloorTop
local HULL_HEIGHT = Tuning.TestPark.SpawnHeight
local MAX_PART = 2048 -- engine limit on a part's size along any axis

local ROAD_COLOR = Color3.fromRGB(55, 55, 60)
local DASH_COLOR = Color3.fromRGB(240, 200, 40)
local RAMP_COLOR = Color3.fromRGB(196, 196, 190)
local BARRIER_COLOR = Color3.fromRGB(225, 225, 220)
local PILLAR_COLOR = Color3.fromRGB(150, 150, 150)
local BUILDING_COLORS = {
	Color3.fromRGB(150, 160, 175),
	Color3.fromRGB(120, 90, 80),
	Color3.fromRGB(190, 180, 160),
	Color3.fromRGB(90, 100, 115),
	Color3.fromRGB(170, 120, 90),
	Color3.fromRGB(110, 140, 150),
}
local BUILDING_MATERIALS = {
	Enum.Material.Concrete,
	Enum.Material.Brick,
	Enum.Material.SmoothPlastic,
}

local City = {}

-- A point in the park, `y` above the floor. Faces -Z, away from the arrival.
local function at(area: MapLayout.Area, x: number, y: number, z: number): CFrame
	return CFrame.new(area.X + x, FLOOR + y, area.Z + z)
end

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

-- Road from x1 to x2 and z1 to z2 (x1 < x2, z1 > z2), a little above the
-- floor, in equal pieces where it is longer than one part can be.
local function road(parent: Instance, area: MapLayout.Area, x1: number, x2: number, z1: number, z2: number)
	local across = math.ceil((x2 - x1) / MAX_PART)
	local down = math.ceil((z1 - z2) / MAX_PART)
	local width, depth = (x2 - x1) / across, (z1 - z2) / down
	for i = 1, across do
		for j = 1, down do
			local part = block(
				parent,
				"Road",
				Vector3.new(width, 0.2, depth),
				at(area, x1 + (i - 0.5) * width, -0.05, z1 - (j - 0.5) * depth),
				ROAD_COLOR
			)
			part.Material = Enum.Material.Asphalt
		end
	end
end

local function buildStreets(parent: Instance, area: MapLayout.Area)
	local model = Instance.new("Model")
	model.Name = "Streets"
	model.Parent = parent

	local A = C.Avenue
	local halfWidth, halfDepth = area.Width / 2, area.Depth / 2
	road(model, area, -A.Width / 2, A.Width / 2, halfDepth, -halfDepth)
	for _, z in C.Streets.Z do
		local half = C.Streets.Width / 2
		road(model, area, -halfWidth, -A.Width / 2, z + half, z - half)
		road(model, area, A.Width / 2, halfWidth, z + half, z - half)
	end

	-- The center line starts past the overpass, which covers the avenue's top.
	local O = C.Overpass
	local z = O.StartZ - O.Run - 100
	while z - A.DashLength > -halfDepth do
		local dash =
			block(model, "Dash", Vector3.new(2, 0.1, A.DashLength), at(area, 0, 0.1, z - A.DashLength / 2), DASH_COLOR)
		dash.Material = Enum.Material.SmoothPlastic
		dash.CanCollide = false
		dash.CanQuery = false
		dash.CanTouch = false
		z -= A.DashEvery
	end
end

-- Outward from a building's middle to each side, in the order a turn to the
-- left goes around: -Z, -X, +Z, +X.
local SIDES = { Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0) }

-- One building, its footprint centered on (x, z), with a curve along the
-- foot of each side rising toward it and one around each corner.
local function buildBuilding(
	parent: Instance,
	area: MapLayout.Area,
	x: number,
	z: number,
	height: number,
	color: Color3,
	material: Enum.Material
)
	local B = C.Buildings
	local model = Instance.new("Model")
	model.Name = "Building"
	model.Parent = parent

	local part = block(model, "Tower", Vector3.new(B.Lot, height, B.Lot), at(area, x, height / 2, z), color)
	part.Material = material

	local options: CurvedWall.Options = {
		radius = B.CurveRadius,
		endAngle = 90,
		steps = B.CurveSteps,
		thickness = 2,
		color = color,
		material = material,
	}
	local middle = at(area, x, 0, z).Position
	for i, out in SIDES do
		local base = middle + out * (B.Lot / 2 + B.CurveRadius)
		CurvedWall.straight(model, CFrame.lookAt(base, base - out), B.Lot, options)
		-- The corner between this side and the next one around.
		local corner = middle + (out + SIDES[i % #SIDES + 1]) * B.Lot / 2
		CurvedWall.outside(model, CFrame.lookAt(corner, corner + out), B.CurveRadius, 90, B.CornerSlices, options)
	end
end

-- A corner's curve around the outside of `corner` (on the floor), between the
-- sides facing `a` and `b`, a quarter turn apart.
local function outsideCorner(parent: Instance, corner: Vector3, a: Vector3, b: Vector3, options: CurvedWall.Options)
	-- The curve turns left from where it starts.
	local left = Vector3.new(a.Z, 0, -a.X)
	local start = if left:Dot(b) > 0.5 then a else b
	CurvedWall.outside(
		parent,
		CFrame.lookAt(corner, corner + start),
		C.Buildings.CurveRadius,
		90,
		C.Buildings.CornerSlices,
		options
	)
end

-- A footprint in park coordinates, seen from above.
type Rect = { x1: number, x2: number, z1: number, z2: number }

-- A building with a tunnel through its ground floor, on `side` of the
-- avenue at the top of the block whose street side is `top`. The tunnel's
-- walls are curves rising away from its flat floor up to straight walls, and
-- the building above is its ceiling. The walls run out through each mouth
-- into the curves along the building's foot.
local function buildTunnel(parent: Instance, area: MapLayout.Area, rng: Random, side: number, top: number): Rect
	local B, T = C.Buildings, C.Tunnels
	local inner = C.Avenue.Width / 2 + B.Setback
	local width = T.Columns * B.Lot + (T.Columns - 1) * B.Alley
	local depth = T.Rows * B.Lot + (T.Rows - 1) * B.Alley
	local rect: Rect = {
		x1 = if side > 0 then inner else -inner - width,
		x2 = if side > 0 then inner + width else -inner,
		z1 = top - depth,
		z2 = top,
	}
	local height = rng:NextInteger(math.max(B.MinHeight, T.Height + 20), B.MaxHeight)
	local color = BUILDING_COLORS[rng:NextInteger(1, #BUILDING_COLORS)]
	local material = BUILDING_MATERIALS[rng:NextInteger(1, #BUILDING_MATERIALS)]

	local model = Instance.new("Model")
	model.Name = "TunnelBuilding"
	model.Parent = parent

	local tower = block(
		model,
		"Tower",
		Vector3.new(width, height - T.Height, depth),
		at(area, (rect.x1 + rect.x2) / 2, (height + T.Height) / 2, (rect.z1 + rect.z2) / 2),
		color
	)
	tower.Material = material

	local options: CurvedWall.Options = {
		radius = B.CurveRadius,
		endAngle = 90,
		steps = B.CurveSteps,
		thickness = 2,
		color = color,
		material = material,
	}
	local R = B.CurveRadius
	local band = T.Floor / 2 + R -- from the middle line to each straight wall
	local wallHeight = T.Height - R
	local function floorAt(x: number, z: number): Vector3
		return at(area, x, 0, z).Position
	end
	-- A straight wall from the top of a curve up to the ceiling, its outer
	-- face on `face` and facing along `out`, `length` long.
	local function wall(face: Vector3, out: Vector3, length: number)
		local middle = face + out * 1 + Vector3.new(0, R + wallHeight / 2, 0)
		block(model, "Wall", Vector3.new(length, wallHeight, 2), CFrame.lookAt(middle, middle + out), color).Material =
			material
	end

	-- The middle line, mirrored on the -X side.
	local segments: { Tunnel.Segment } = {}
	for _, segment in T.Segments do
		table.insert(segments, {
			Straight = segment.Straight,
			Turn = if segment.Turn then segment.Turn * side else nil,
			Radius = segment.Radius,
		})
	end
	local entryX, entryZ = side * inner, top - T.EntryBack
	local pieces, finish = Tunnel.path(entryX, entryZ, side, 0, segments)
	if math.abs(finish.z - top) > 0.01 or finish.headingZ < 0.99 then
		warn(`City: a tunnel ends at ({finish.x}, {finish.z}), not on its building's street side at Z {top}`)
	end

	for _, piece in pieces do
		if piece.kind == "straight" then
			local from, to = floorAt(piece.fromX, piece.fromZ), floorAt(piece.toX, piece.toZ)
			local length = (to - from).Magnitude
			local along = (to - from).Unit
			local middle = (from + to) / 2
			for _, out in { Vector3.new(along.Z, 0, -along.X), Vector3.new(-along.Z, 0, along.X) } do
				local base = middle + out * T.Floor / 2
				CurvedWall.straight(model, CFrame.lookAt(base, base + out), length, options)
				wall(middle + out * band, out, length)
			end
		else
			local center = floorAt(piece.centerX, piece.centerZ)
			local pivot = CFrame.lookAt(center, floorAt(piece.startX, piece.startZ))
			local turn = math.deg(piece.sweep)
			CurvedWall.corner(model, pivot, piece.radius + T.Floor / 2, turn, T.Slices, options)
			CurvedWall.outside(model, pivot, piece.radius - T.Floor / 2, turn, T.Slices, options)
			local sliceAngle = turn / T.Slices
			for i = 1, T.Slices do
				local spoke = (pivot * CFrame.Angles(0, math.rad(sliceAngle * (i - 0.5)), 0)).LookVector
				local outer, innerRadius = piece.radius + band, piece.radius - band
				wall(center + spoke * outer, spoke, CurveProfile.sliceLength(outer + 2, sliceAngle))
				wall(center + spoke * innerRadius, -spoke, CurveProfile.sliceLength(innerRadius, sliceAngle))
			end
		end
	end

	-- The building's sides, each with the curve along its foot and a straight
	-- wall up to the tower, broken where a tunnel mouth opens in it.
	local mouths = { floorAt(entryX, entryZ), floorAt(finish.x, finish.z) }
	local corners = {
		floorAt(rect.x1, rect.z1),
		floorAt(rect.x2, rect.z1),
		floorAt(rect.x2, rect.z2),
		floorAt(rect.x1, rect.z2),
	}
	local outs = { Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0) }
	for i, from in corners do
		local to = corners[i % 4 + 1]
		local out = outs[i]
		local along = (to - from).Unit
		local length = (to - from).Magnitude
		outsideCorner(model, from, outs[(i + 2) % 4 + 1], out, options)
		-- The stretches of this side between its mouths.
		local stretches = { { 0, length } }
		for _, mouth in mouths do
			local offset = mouth - from
			if math.abs(offset:Dot(out)) < 0.01 then
				local m = offset:Dot(along)
				local last = stretches[#stretches]
				stretches[#stretches] = { last[1], m - band }
				table.insert(stretches, { m + band, last[2] })
				outsideCorner(model, from + along * (m - band), out, along, options)
				outsideCorner(model, from + along * (m + band), out, -along, options)
			end
		end
		for _, stretch in stretches do
			local a, b = stretch[1], stretch[2]
			local face = from + along * (a + b) / 2
			local base = face + out * R
			CurvedWall.straight(model, CFrame.lookAt(base, base - out), b - a, options)
			wall(face - out * 2, out, b - a)
		end
	end
	return rect
end

-- Fills the block from z1 down to z2 on both sides of the avenue with
-- buildings in a grid, each a random height, some lots left empty and none
-- where a tunnel building already stands.
local function buildBlock(parent: Instance, area: MapLayout.Area, rng: Random, z1: number, z2: number, taken: { Rect })
	local B = C.Buildings
	local inner = C.Avenue.Width / 2 + B.Setback
	local outer = area.Width / 2 - B.Setback
	local function free(x: number, z: number): boolean
		for _, rect in taken do
			if x > rect.x1 and x < rect.x2 and z > rect.z1 and z < rect.z2 then
				return false
			end
		end
		return true
	end
	for _, side in { -1, 1 } do
		local x = inner
		while x + B.Lot <= outer do
			local z = z1 - B.Setback
			while z - B.Lot >= z2 + B.Setback do
				if free(side * (x + B.Lot / 2), z - B.Lot / 2) and rng:NextNumber() >= B.EmptyChance then
					local height = rng:NextInteger(B.MinHeight, B.MaxHeight)
					local color = BUILDING_COLORS[rng:NextInteger(1, #BUILDING_COLORS)]
					local material = BUILDING_MATERIALS[rng:NextInteger(1, #BUILDING_MATERIALS)]
					buildBuilding(parent, area, side * (x + B.Lot / 2), z - B.Lot / 2, height, color, material)
				end
				z -= B.Lot + B.Alley
			end
			x += B.Lot + B.Alley
		end
	end
end

local function buildBuildings(parent: Instance, area: MapLayout.Area)
	local model = Instance.new("Model")
	model.Name = "Buildings"
	model.Parent = parent

	local rng = Random.new(C.Buildings.Seed)
	local half = C.Streets.Width / 2
	local top = C.Buildings.TopZ
	local index = 0
	for _, z in C.Streets.Z do
		if top > z + half then
			index += 1
			local taken: { Rect } = {}
			for _, place in C.Tunnels.Places do
				if place.Block == index then
					table.insert(taken, buildTunnel(model, area, rng, place.Side, top - C.Buildings.Setback))
				end
			end
			buildBlock(model, area, rng, top, z + half, taken)
		end
		top = z - half
	end
end

local function buildOverpass(parent: Instance, area: MapLayout.Area)
	local O = C.Overpass
	local model = Instance.new("Model")
	model.Name = "HighwayOverpass"
	model.Parent = parent

	local start = at(area, 0, 0, O.StartZ).Position
	local axis = CFrame.lookAt(start, start + Vector3.new(0, O.Rise, -O.Run), Vector3.yAxis)
	local length = math.sqrt(O.Run * O.Run + O.Rise * O.Rise)
	local respawn = at(area, 0, HULL_HEIGHT, O.StartZ + 40)

	block(
		model,
		"Ramp",
		Vector3.new(O.Width, O.Thickness, length),
		axis * CFrame.new(0, -O.Thickness / 2, -length / 2),
		RAMP_COLOR
	)
	for _, side in { -1, 1 } do
		block(
			model,
			"Barrier",
			Vector3.new(O.BarrierWidth, O.BarrierHeight, length),
			axis * CFrame.new(side * (O.Width + O.BarrierWidth) / 2, O.BarrierHeight / 2, -length / 2),
			BARRIER_COLOR
		)
	end

	-- Pillars from the floor up to the ramp's underside, where it is high
	-- enough to need them.
	local d = O.PillarEvery
	while d < O.Run do
		local height = O.Rise * d / O.Run - O.Thickness
		if height > O.PillarSize then
			block(
				model,
				"Pillar",
				Vector3.new(O.PillarSize, height, O.PillarSize),
				at(area, 0, height / 2, O.StartZ - d),
				PILLAR_COLOR
			)
		end
		d += O.PillarEvery
	end

	d = O.BoostLength / 2 + 5
	while d < length - O.BoostLength / 2 do
		LaunchPad.flat(model, axis * CFrame.new(0, 0.1, -d), O.Width, O.BoostLength, O.BoostSpeed, respawn)
		d += O.BoostEvery
	end

	local options: CurvedWall.Options = {
		radius = O.KickRadius,
		endAngle = O.KickAngle,
		steps = O.KickSteps,
		thickness = O.Thickness,
		color = RAMP_COLOR,
	}
	local kicker = CurvedWall.straight(model, axis * CFrame.new(0, 0, -length), O.Width, options)
	LaunchPad.top(kicker, O.KickSteps, O.LaunchSpeed, respawn)
end

function City.build(folder: Folder, area: MapLayout.Area)
	buildStreets(folder, area)
	buildBuildings(folder, area)
	buildOverpass(folder, area)
end

return City
