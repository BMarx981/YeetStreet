--!strict
-- City (ModuleScript) -> ServerScriptService.Parks.City
-- The dense city, built by ParkService into workspace.Parks.City on top of
-- the park's floor. An avenue runs down the middle from the arrival, cross
-- streets split the rest into blocks of buildings, and open plazas sit at
-- both ends. The Highway Overpass climbs straight down the avenue to a broken
-- end, a kicker with boosters that throws the car on down the avenue,
-- through a YEET STREET billboard that shatters. Cranes on roofs swing
-- wrecking balls across the streets.
-- Every building has a curve all around its foot, so a car driven at it
-- rides up the wall instead of stopping dead. Chains of two buildings have
-- a twisting round tube through them that crosses the alley between them
-- overhead. A train line loops round, elevated and underground
-- (CityRailway). A kaiju walks the streets hunting cars (CityKaiju), and
-- walkers on the curbs dive out of cars' way (CityPedestrians). Every
-- roof has a lip along its edges, and some have a water tower to smash or
-- solar panels to drive up (CityRoofs).
-- Numbers are in Tuning.City.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Fingerprint = require(ReplicatedStorage.Fingerprint)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local Railway = require(ReplicatedStorage.Railway)
local Tunnel = require(ReplicatedStorage.Tunnel)
local WreckingBall = require(ReplicatedStorage.WreckingBall)
local WreckingBalls = require(ReplicatedStorage.WreckingBalls)
local CurvedWall = require(ServerScriptService.Pieces.CurvedWall)
local LaunchPad = require(ServerScriptService.Pieces.LaunchPad)
local Tube = require(ServerScriptService.Pieces.Tube)
local CityKaiju = require(script.Parent.CityKaiju)
local CityPedestrians = require(script.Parent.CityPedestrians)
local CityRailway = require(script.Parent.CityRailway)
local CityRoofs = require(script.Parent.CityRoofs)
local CollisionGroups = require(ServerScriptService.CollisionGroups)

local C = Tuning.City
local FLOOR = Tuning.Map.FloorTop
local HULL_HEIGHT = Tuning.TestPark.SpawnHeight
local MAX_PART = 2048 -- engine limit on a part's size along any axis

local ROAD_COLOR = Color3.fromRGB(55, 55, 60)
local DASH_COLOR = Color3.fromRGB(240, 200, 40)
local RAMP_COLOR = Color3.fromRGB(196, 196, 190)
local BARRIER_COLOR = Color3.fromRGB(225, 225, 220)
local PILLAR_COLOR = Color3.fromRGB(150, 150, 150)
local POLE_COLOR = Color3.fromRGB(60, 64, 70)
local LAMP_COLOR = Color3.fromRGB(255, 236, 190)
local BILLBOARD_COLOR = Color3.fromRGB(255, 200, 40)
local BILLBOARD_TEXT_COLOR = Color3.fromRGB(30, 30, 40)
local CRANE_COLOR = Color3.fromRGB(245, 185, 30)
local COUNTERWEIGHT_COLOR = Color3.fromRGB(150, 150, 145)
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

local THICKNESS = 2
local HALF_STEP = math.pi / C.Tunnels.Sides

-- A ring's outside corners are this far out from its curves' middles, for
-- curves `radius` around.
local function outsideOf(radius: number): number
	return (radius * math.cos(HALF_STEP) + THICKNESS) / math.cos(HALF_STEP)
end

type Hole = Tube.Hole

-- Every mouth on the ground has the same shape: a flat floor and roof
-- MouthFloor wide with curves MouthCurve around either side.
local MOUTH_FLAT = C.Tunnels.MouthFloor / 2
local MOUTH_MIDDLE = C.Tunnels.MouthCurve * math.cos(HALF_STEP) + Tunnel.LIFT

local function curveOptions(color: Color3, material: Enum.Material): CurvedWall.Options
	return {
		radius = C.Buildings.CurveRadius,
		endAngle = 90,
		steps = C.Buildings.CurveSteps,
		thickness = THICKNESS,
		color = color,
		material = material,
	}
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

-- A building's sides around `rect` (park coordinates): along the foot of
-- each a curve, with one round each corner, and above it a wall up to
-- `towerBottom`. The wall breaks where a hole opens in a side; the curve
-- breaks for a mouth on the ground and wraps round into it, but runs on
-- under a tube crossing up high.
local function buildSides(
	parent: Instance,
	area: MapLayout.Area,
	rect: Tunnel.Rect,
	holes: { Hole },
	towerBottom: number,
	color: Color3,
	material: Enum.Material
)
	local R = C.Buildings.CurveRadius
	local options = curveOptions(color, material)
	local corners = {
		at(area, rect.x1, 0, rect.z1).Position,
		at(area, rect.x2, 0, rect.z1).Position,
		at(area, rect.x2, 0, rect.z2).Position,
		at(area, rect.x1, 0, rect.z2).Position,
	}
	local outs = { Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0) }
	for i, from in corners do
		local to = corners[i % 4 + 1]
		local out = outs[i]
		local along = (to - from).Unit
		local length = (to - from).Magnitude
		outsideCorner(parent, from, outs[(i + 2) % 4 + 1], out, options)
		-- The stretches of this side left for the curve and for the wall.
		local curves = { { 0, length } }
		local walls = { { 0, length } }
		local function cut(stretches: { { number } }, a: number, b: number)
			local last = stretches[#stretches]
			stretches[#stretches] = { last[1], a }
			table.insert(stretches, { b, last[2] })
		end
		for _, hole in holes do
			local offset = hole.point - from
			if math.abs(offset:Dot(out)) < 0.01 then
				local m = offset:Dot(along)
				local half = hole.flat + hole.outside
				cut(walls, m - half, m + half)
				if hole.ground then
					cut(curves, m - half - R, m + half + R)
					outsideCorner(parent, from + along * (m - half - R), out, along, options)
					outsideCorner(parent, from + along * (m + half + R), out, -along, options)
				end
				Tube.holePlate(parent, C.Tunnels, hole, out, towerBottom, color, material)
			end
		end
		for _, stretch in curves do
			local a, b = stretch[1], stretch[2]
			local base = from + along * (a + b) / 2 + out * R
			CurvedWall.straight(parent, CFrame.lookAt(base, base - out), b - a, options)
		end
		if towerBottom > 0 then
			for _, stretch in walls do
				local a, b = stretch[1], stretch[2]
				local middle = from + along * (a + b) / 2 - out + Vector3.new(0, towerBottom / 2, 0)
				block(
					parent,
					"Wall",
					Vector3.new(b - a, towerBottom, THICKNESS),
					CFrame.lookAt(middle, middle + out),
					color
				).Material =
					material
			end
		end
	end
end

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

	local tower = block(model, "Tower", Vector3.new(B.Lot, height, B.Lot), at(area, x, height / 2, z), color)
	tower.Material = material
	local half = B.Lot / 2
	buildSides(model, area, { x1 = x - half, x2 = x + half, z1 = z - half, z2 = z + half }, {}, 0, color, material)
end

-- A chain of two buildings with a round tube tunnel through their ground
-- floors, laid out by Tunnel.layout. The tube is a ring of Sides planks all
-- the way round, so a car can drive up its walls and along its roof, and
-- climb (CarController pulls a car toward the wall inside one). It snakes
-- and climbs through the first building, crosses the alley high enough to
-- drive under, then sweeps and drops through the second. The buildings sit
-- on the tube. Over FlareLength at each end on the ground the tube opens
-- out into a mouth with a wide flat floor and curves up each side, like the
-- corkscrew's middle ramp, so a car can drive in off center or at an angle,
-- and the curve along the building's foot wraps in to meet it. Dim lights
-- hang along the roof.
local function buildChain(parent: Instance, area: MapLayout.Area, rng: Random, chain: Tunnel.Chain)
	local B, T = C.Buildings, C.Tunnels
	local towerBottom = chain.alleyHeight + outsideOf(T.Radius)
	if chain.warning then
		warn(`City: {chain.warning}`)
	end

	local model = Instance.new("Model")
	model.Name = "TunnelChain"
	model.Parent = parent

	local function floorAt(x: number, z: number): Vector3
		return at(area, x, 0, z).Position
	end
	Tube.build(model, at(area, 0, 0, 0), chain.pieces, T.SliceAngle, T)

	-- The two buildings, each on the tube, with the holes in their sides.
	local ground = function(crossing: Tunnel.Crossing): Hole
		return {
			point = floorAt(crossing.x, crossing.z),
			ground = true,
			middleY = MOUTH_MIDDLE,
			flat = MOUTH_FLAT,
			outside = outsideOf(T.MouthCurve),
		}
	end
	local raised = function(crossing: Tunnel.Crossing): Hole
		return {
			point = floorAt(crossing.x, crossing.z),
			ground = false,
			middleY = chain.alleyHeight,
			flat = 0,
			outside = outsideOf(T.Radius),
		}
	end
	local holes = {
		{ ground(chain.entry), raised(chain.alley[1]) },
		{ raised(chain.alley[2]), ground(chain.exit) },
	}
	for i, rect in chain.rects do
		local height = rng:NextInteger(math.max(B.MinHeight, math.ceil(towerBottom) + T.AboveTunnel), B.MaxHeight)
		local color = BUILDING_COLORS[rng:NextInteger(1, #BUILDING_COLORS)]
		local material = BUILDING_MATERIALS[rng:NextInteger(1, #BUILDING_MATERIALS)]
		local building = Instance.new("Model")
		building.Name = "TunnelBuilding"
		building.Parent = model
		local tower = block(
			building,
			"Tower",
			Vector3.new(rect.x2 - rect.x1, height - towerBottom, rect.z2 - rect.z1),
			at(area, (rect.x1 + rect.x2) / 2, (height + towerBottom) / 2, (rect.z1 + rect.z2) / 2),
			color
		)
		tower.Material = material
		buildSides(building, area, rect, holes[i], towerBottom, color, material)
	end
end

-- A spiral tower, laid out by Tunnel.spirals: a hollow building whose round
-- tube comes in on the ground from the street, climbs round and round
-- inside, comes up through the roof under a hut and runs along the roof to
-- a mouth, with a kicker beyond it off the roof's street edge. A reset after
-- a launch from the kicker puts the car back in the mouth.
local function buildSpiral(parent: Instance, area: MapLayout.Area, rng: Random, spiral: Tunnel.Spiral)
	local S, T = C.Spirals, C.Tunnels
	if spiral.warning then
		warn(`City: {spiral.warning}`)
	end
	local model = Instance.new("Model")
	model.Name = "SpiralTower"
	model.Parent = parent
	Tube.build(model, at(area, 0, 0, 0), spiral.pieces, S.SliceAngle, T)

	local color = BUILDING_COLORS[rng:NextInteger(1, #BUILDING_COLORS)]
	local material = BUILDING_MATERIALS[rng:NextInteger(1, #BUILDING_MATERIALS)]
	local roof = spiral.roof
	local out = Vector3.new(spiral.outX, 0, spiral.outZ)
	local function wall(name: string, size: Vector3, middle: Vector3)
		block(model, name, size, CFrame.new(middle), color).Material = material
	end

	-- The building, its walls up to the roof and the tube's mouth in its
	-- street side, and the roof over it but for the hatch.
	local mouth: Hole = {
		point = at(area, spiral.entry.x, 0, spiral.entry.z).Position,
		ground = true,
		middleY = MOUTH_MIDDLE,
		flat = MOUTH_FLAT,
		outside = outsideOf(T.MouthCurve),
	}
	buildSides(model, area, spiral.rect, { mouth }, roof - S.RoofThickness, color, material)
	for _, piece in Railway.cut(spiral.rect, { spiral.hatch }) do
		wall(
			"Roof",
			Vector3.new(piece.x2 - piece.x1, S.RoofThickness, piece.z2 - piece.z1),
			at(area, (piece.x1 + piece.x2) / 2, roof - S.RoofThickness / 2, (piece.z1 + piece.z2) / 2).Position
		)
	end

	-- The hut over the hatch, the whole far half of the roof: the tube leaves
	-- through a round hole in its street side, level on the roof.
	local hut = spiral.hatch
	local exit: Hole = {
		point = at(area, spiral.exit.x, roof, spiral.exit.z).Position,
		ground = false,
		middleY = Tunnel.groundHeight(T),
		flat = 0,
		outside = outsideOf(T.Radius),
	}
	Tube.holePlate(model, C.Tunnels, exit, out, S.HutHeight, color, material)
	local width, depth = hut.x2 - hut.x1, hut.z2 - hut.z1
	local middle = at(area, (hut.x1 + hut.x2) / 2, roof + S.HutHeight / 2, (hut.z1 + hut.z2) / 2).Position
	for _, sign in { -1, 1 } do
		wall(
			"Wall",
			Vector3.new(THICKNESS, S.HutHeight, depth),
			middle + Vector3.new(sign * (width / 2 - THICKNESS / 2), 0, 0)
		)
		-- The street side either side of the hole.
		local from = spiral.exit.x + sign * exit.outside
		local to = if sign > 0 then hut.x2 else hut.x1
		if math.abs(to - from) > 0.05 then
			wall(
				"Wall",
				Vector3.new(math.abs(to - from), S.HutHeight, THICKNESS),
				at(area, (from + to) / 2, roof + S.HutHeight / 2, spiral.exit.z).Position - out * THICKNESS / 2
			)
		end
	end
	wall("Wall", Vector3.new(width, S.HutHeight, THICKNESS), middle - out * (depth / 2 - THICKNESS / 2))
	wall(
		"Roof",
		Vector3.new(width, S.RoofThickness, depth),
		middle + Vector3.new(0, S.HutHeight / 2 - S.RoofThickness / 2, 0)
	)

	-- The kicker at the roof's edge, a runway on from the mouth.
	local K = S.Kick
	local respawn = at(area, spiral.mouth.x, roof + HULL_HEIGHT, spiral.mouth.z).Position - out * 15
	local base = at(area, spiral.mouth.x, roof, spiral.mouth.z).Position
		+ out * (spiral.runway - K.Radius * math.sin(math.rad(K.Angle)) - 5)
	local kicker = CurvedWall.straight(model, CFrame.lookAt(base, base + out), K.Width, {
		radius = K.Radius,
		endAngle = K.Angle,
		steps = K.Steps,
		thickness = THICKNESS,
		color = RAMP_COLOR,
	})
	LaunchPad.top(kicker, K.Steps, K.LaunchSpeed, CFrame.lookAt(respawn, respawn + out))
end

-- Fills the block from z1 down to z2 on both sides of the avenue with
-- buildings in a grid, each a random height, some lots left empty and none
-- where a tunnel building already stands. Each building goes in `plain`.
local function buildBlock(
	parent: Instance,
	area: MapLayout.Area,
	rng: Random,
	z1: number,
	z2: number,
	taken: { Tunnel.Rect },
	plain: { WreckingBall.Building }
)
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
					table.insert(plain, { x = side * (x + B.Lot / 2), z = z - B.Lot / 2, height = height })
				end
				z -= B.Lot + B.Alley
			end
			x += B.Lot + B.Alley
		end
	end
end

-- Returns the plain buildings, without tunnels.
local function buildBuildings(parent: Instance, area: MapLayout.Area): { WreckingBall.Building }
	local model = Instance.new("Model")
	model.Name = "Buildings"
	model.Parent = parent

	local plain: { WreckingBall.Building } = {}
	local rng = Random.new(C.Buildings.Seed)
	local city: Tunnel.City = C :: any
	local chains = Tunnel.layout(city)
	local spirals = Tunnel.spirals(city, C.Spirals :: any)
	for index, lots in Tunnel.blocks(city) do
		local taken: { Tunnel.Rect } = {}
		for _, chain in chains do
			if chain.place.Block == index then
				buildChain(model, area, rng, chain)
				for _, rect in chain.rects do
					table.insert(taken, rect)
				end
			end
		end
		for _, spiral in spirals do
			if spiral.place.Block == index then
				buildSpiral(model, area, rng, spiral)
				table.insert(taken, spiral.rect)
			end
		end
		buildBlock(model, area, rng, lots.top, lots.bottom, taken, plain)
	end
	return plain
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

	-- The pads lie 0.1 above the ramp, so cars pass through them and ride the
	-- one smooth ramp block: at jet speeds even a 0.1 step throws a car off.
	-- CarSensor's rays still find them.
	d = O.BoostLength / 2 + 5
	while d < length - O.BoostLength / 2 do
		local pad = LaunchPad.flat(model, axis * CFrame.new(0, 0.1, -d), O.Width, O.BoostLength, O.BoostSpeed, respawn)
		pad.CanCollide = false
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

-- A street light standing at (x, z), its arm reaching out over the road
-- toward `facing` (level). The pole is the prop PropService knocks flying;
-- the arm and lamp are welded to it and fly with it. No part of it ever
-- touches a car.
local function streetLight(parent: Instance, area: MapLayout.Area, x: number, z: number, facing: Vector3)
	local L = C.StreetLights
	local model = Instance.new("Model")
	model.Name = "StreetLight"
	local base = at(area, x, 0, z).Position
	local pole = block(
		model,
		"Pole",
		Vector3.new(L.Height, 1, 1),
		CFrame.new(base + Vector3.new(0, L.Height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		POLE_COLOR
	)
	pole.Shape = Enum.PartType.Cylinder
	pole.Material = Enum.Material.Metal
	pole:SetAttribute("ResetTime", L.ResetTime)
	pole:SetAttribute("CarSpeedShare", L.CarSpeedShare)
	local top = base + Vector3.new(0, L.Height - 0.3, 0)
	local arm = block(
		model,
		"Arm",
		Vector3.new(0.6, 0.6, L.Reach),
		CFrame.lookAt(top + facing * L.Reach / 2, top + facing * L.Reach),
		POLE_COLOR
	)
	arm.Material = Enum.Material.Metal
	local lamp = block(
		model,
		"Lamp",
		Vector3.new(2.5, 0.8, 4),
		CFrame.lookAt(
			top + facing * (L.Reach - 1) - Vector3.new(0, 0.7, 0),
			top + facing * L.Reach * 2 - Vector3.new(0, 0.7, 0)
		),
		LAMP_COLOR
	)
	lamp.Material = Enum.Material.Neon
	for _, part in { pole, arm, lamp } do
		part.CollisionGroup = CollisionGroups.Props
	end
	for _, part in { arm, lamp } do
		part.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = pole
		weld.Part1 = part
		weld.Parent = part
	end
	CollectionService:AddTag(pole, "Knockable")
	model.Parent = parent
end

-- Street lights along both edges of the avenue and of every cross street,
-- leaving the crossings clear.
local function buildStreetLights(parent: Instance, area: MapLayout.Area)
	local L = C.StreetLights
	local model = Instance.new("Model")
	model.Name = "StreetLights"
	local halfWidth, halfDepth = area.Width / 2, area.Depth / 2
	local avenue, street = C.Avenue.Width / 2, C.Streets.Width / 2
	local function crossing(z: number): boolean
		for _, middle in C.Streets.Z do
			if math.abs(z - middle) < street + L.Inset then
				return true
			end
		end
		return false
	end
	for _, side in { -1, 1 } do
		local z = halfDepth - L.Every / 2
		while z > -halfDepth do
			if not crossing(z) then
				streetLight(model, area, side * (avenue - L.Inset), z, Vector3.new(-side, 0, 0))
			end
			z -= L.Every
		end
		for _, middle in C.Streets.Z do
			for _, edge in { -1, 1 } do
				local x = avenue + L.Every / 2
				while x < halfWidth do
					streetLight(model, area, side * x, middle + edge * (street - L.Inset), Vector3.new(0, 0, -edge))
					x += L.Every
				end
			end
		end
	end
	model.Parent = parent
end

-- The slice of the board's text a tile shows on one face. `column` counts
-- from the left as someone facing that face sees it, `row` from the top. The
-- whole text is laid out the same on every tile and clipped to its own slice,
-- so the slices line up into one sign.
local function billboardSlice(tile: BasePart, face: Enum.NormalId, column: number, row: number)
	local B = C.Billboard
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = B.PixelsPerStud
	gui.LightInfluence = 0
	local clip = Instance.new("Frame")
	clip.Size = UDim2.fromScale(1, 1)
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Parent = gui
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(B.Columns, B.Rows)
	label.Position = UDim2.fromScale(-column, -row)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = "YEET\nSTREET"
	label.TextScaled = true
	label.TextColor3 = BILLBOARD_TEXT_COLOR
	label.Parent = clip
	gui.Parent = tile
end

-- The YEET STREET billboard across the avenue, its face toward the overpass.
-- The face tiles are knockable props in a Shatter model with Target
-- Billboard, so flying through any of them sends them all flying and pays
-- on the run (PropService, ScoreService). The posts stand; the frame along
-- the top and bottom is in the Props group, so cars pass through it.
local function buildBillboard(parent: Instance, area: MapLayout.Area)
	local B = C.Billboard
	local model = Instance.new("Model")
	model.Name = "Billboard"
	model:SetAttribute("Shatter", true)
	local center = at(area, 0, B.Bottom + B.Height / 2, B.Z).Position
	-- Facing +Z, toward the overpass, so the Front face meets the cars and
	-- the board's own +X is the park's -X.
	local board = CFrame.lookAt(center, center + Vector3.zAxis)
	local tileWidth, tileHeight = B.Width / B.Columns, B.Height / B.Rows
	for column = 0, B.Columns - 1 do
		for row = 0, B.Rows - 1 do
			local tile = block(
				model,
				"Tile",
				Vector3.new(tileWidth, tileHeight, B.Thickness),
				board
					* CFrame.new(-B.Width / 2 + (column + 0.5) * tileWidth, B.Height / 2 - (row + 0.5) * tileHeight, 0),
				BILLBOARD_COLOR
			)
			tile.Material = Enum.Material.SmoothPlastic
			tile:SetAttribute("Target", "Billboard")
			tile:SetAttribute("ResetTime", B.ResetTime)
			tile:SetAttribute("CarSpeedShare", B.CarSpeedShare)
			-- Facing the Front face, the board's +X is on the left; facing
			-- the Back, its -X is.
			billboardSlice(tile, Enum.NormalId.Front, B.Columns - 1 - column, row)
			billboardSlice(tile, Enum.NormalId.Back, column, row)
			CollectionService:AddTag(tile, "Knockable")
		end
	end

	local top = B.Bottom + B.Height + B.Beam
	for _, side in { -1, 1 } do
		local x = side * (B.Width + B.PostSize) / 2
		local post = block(
			model,
			"BillboardPost",
			Vector3.new(B.PostSize, top, B.PostSize),
			at(area, x, top / 2, B.Z),
			POLE_COLOR
		)
		post.Material = Enum.Material.Metal
	end
	for _, y in { B.Bottom - B.Beam / 2, B.Bottom + B.Height + B.Beam / 2 } do
		local beam =
			block(model, "BillboardBeam", Vector3.new(B.Width, B.Beam, B.Thickness), at(area, 0, y, B.Z), POLE_COLOR)
		beam.Material = Enum.Material.Metal
		beam.CollisionGroup = CollisionGroups.Props
	end
	model.Parent = parent
end

-- A tower crane on the roof of the building nearest each of
-- Tuning.City.Cranes' Spots (WreckingBall.site): a mast MastBack in from
-- the roof's street edge, and a jib from a counterweight behind it out over
-- the street's middle. The trolley at the jib's tip is tagged WreckingBall
-- with its ball's Length, Amplitude and Phase, and each client draws the
-- ball swinging from it (WreckingBallLook), skimming the road at the bottom
-- and out to Margin from the street's edges.
local function buildCranes(parent: Instance, area: MapLayout.Area, buildings: { WreckingBall.Building })
	local K, B = C.Cranes, C.Buildings
	local model = Instance.new("Model")
	model.Name = "Cranes"
	local layout: WreckingBall.Layout = {
		AvenueWidth = C.Avenue.Width,
		StreetWidth = C.Streets.Width,
		Lot = B.Lot,
		Alley = B.Alley,
		Setback = B.Setback,
	}
	for index, spot in K.Spots :: { any } do
		local site = WreckingBall.site(buildings, spot, layout, K.MaxShift)
		if not site then
			warn(`City: no building for crane {index}`)
			continue
		end
		local crane = Instance.new("Model")
		crane.Name = "Crane"
		local roof = site.building.height
		local top = roof + K.MastHeight
		local out = Vector3.new(site.outX, 0, site.outZ)
		local mast = Vector3.new(site.building.x, 0, site.building.z) + out * (B.Lot / 2 - K.MastBack)
		local tip = Vector3.new(site.pivotX, 0, site.pivotZ)
		local back = mast - out * K.CounterJib
		local function point(x: Vector3, y: number): Vector3
			return at(area, x.X, y, x.Z).Position
		end

		block(
			crane,
			"Mast",
			Vector3.new(K.MastSize, K.MastHeight, K.MastSize),
			CFrame.new(point(mast, roof + K.MastHeight / 2)),
			CRANE_COLOR
		).Material =
			Enum.Material.Metal
		local jibY = top + K.JibSize / 2
		block(
			crane,
			"Jib",
			Vector3.new(K.JibSize, K.JibSize, (tip - back).Magnitude),
			CFrame.lookAt(point((back + tip) / 2, jibY), point(tip, jibY)),
			CRANE_COLOR
		).Material =
			Enum.Material.Metal
		block(
			crane,
			"Counterweight",
			Vector3.one * K.CounterweightSize,
			CFrame.new(point(back + out * K.CounterweightSize / 2, top - K.CounterweightSize / 2)),
			COUNTERWEIGHT_COLOR
		)

		-- The trolley's X is across the street, the way the ball swings.
		local trolley = block(
			crane,
			"Trolley",
			Vector3.new(4, 2, 4),
			CFrame.fromMatrix(point(tip, top - 1), out, Vector3.yAxis),
			CRANE_COLOR
		)
		trolley.Material = Enum.Material.Metal
		trolley.CanCollide = false
		trolley.CanQuery = false
		trolley.CanTouch = false
		local length = top - 1 - (K.Gap + K.Ball.Radius)
		trolley:SetAttribute("Length", length)
		trolley:SetAttribute("Amplitude", WreckingBall.amplitude(length, site.halfStreet - K.Ball.Radius - K.Margin))
		trolley:SetAttribute("Phase", (spot.Phase or 0) * 2 * math.pi)
		CollectionService:AddTag(trolley, WreckingBalls.TAG)
		crane.Parent = model
	end
	model.Parent = parent
end

function City.build(folder: Folder, area: MapLayout.Area)
	buildStreets(folder, area)
	local plain = buildBuildings(folder, area)
	buildOverpass(folder, area)
	buildBillboard(folder, area)
	buildStreetLights(folder, area)
	buildCranes(folder, area, plain)
	CityRoofs.build(folder, area)
	CityRailway.build(folder, area)
end

-- Pieces a saved city can have rebuilt in place (ParkFreeze.patch).
City.patches = {
	Roofs = CityRoofs.build,
}

-- What moves while the game runs, for a park just built or saved with the
-- place: the kaiju, the walkers, and cracks in the roofs' solar panels. (The
-- trains and the wrecking balls are drawn on each client.)
function City.start(folder: Folder, area: MapLayout.Area)
	CityKaiju.build(folder, area)
	CityPedestrians.start(folder, area)
	CityRoofs.start(folder, area)
end

-- The tuning the parts are built from: all of Tuning.City but the numbers
-- only used while the game runs.
function City.fingerprint(): string
	return Fingerprint.of(C :: any, {
		"Kaiju",
		"Pedestrians",
		"Cranes.Ball",
		"Cranes.Server",
		"Railway.Trains",
		"Railway.Push",
		"Railway.Server",
		"Roofs.Crack",
		"Roofs.Splash",
	})
end

return City
