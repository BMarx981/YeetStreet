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

local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
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

-- Fills the block from z1 down to z2 on both sides of the avenue with
-- buildings in a grid, each a random height, some lots left empty.
local function buildBlock(parent: Instance, area: MapLayout.Area, rng: Random, z1: number, z2: number)
	local B = C.Buildings
	local inner = C.Avenue.Width / 2 + B.Setback
	local outer = area.Width / 2 - B.Setback
	for _, side in { -1, 1 } do
		local x = inner
		while x + B.Lot <= outer do
			local z = z1 - B.Setback
			while z - B.Lot >= z2 + B.Setback do
				if rng:NextNumber() >= B.EmptyChance then
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
	for _, z in C.Streets.Z do
		if top > z + half then
			buildBlock(model, area, rng, top, z + half)
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
