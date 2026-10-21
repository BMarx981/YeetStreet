--!strict
-- City (ModuleScript) -> ServerScriptService.Parks.City
-- The dense city, built by ParkService into workspace.Parks.City on top of
-- the park's floor. An avenue runs down the middle from the arrival, cross
-- streets split the rest into blocks of buildings, and open plazas sit at
-- both ends. The Highway Overpass climbs straight down the avenue to a broken
-- end, a kicker with boosters that throws the car on down the avenue.
-- Every building has a curve all around its foot, so a car driven at it
-- rides up the wall instead of stopping dead, and some have a round tube
-- tunnel through them. Numbers are in Tuning.City.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CurveProfile = require(ReplicatedStorage.CurveProfile)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local Tunnel = require(ReplicatedStorage.Tunnel)
local CurvedWall = require(ServerScriptService.Pieces.CurvedWall)
local LaunchPad = require(ServerScriptService.Pieces.LaunchPad)
local Triangle = require(ServerScriptService.Pieces.Triangle)

local C = Tuning.City
local FLOOR = Tuning.Map.FloorTop
local HULL_HEIGHT = Tuning.TestPark.SpawnHeight
local MAX_PART = 2048 -- engine limit on a part's size along any axis

local ROAD_COLOR = Color3.fromRGB(55, 55, 60)
local DASH_COLOR = Color3.fromRGB(240, 200, 40)
local RAMP_COLOR = Color3.fromRGB(196, 196, 190)
local BARRIER_COLOR = Color3.fromRGB(225, 225, 220)
local PILLAR_COLOR = Color3.fromRGB(150, 150, 150)
local LIGHT_COLOR = Color3.fromRGB(255, 214, 160)
local TUBE_COLOR = Color3.fromRGB(150, 156, 166)
-- Planks are this much wider than their chord so the seams stay closed.
local OVERLAP = 0.4
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

-- A building with a round tube tunnel through its ground floor, laid out by
-- Tunnel.layout. The tube is a ring of Sides planks all the way round, so a
-- car can drive up its walls and along its roof (CarController pulls a car
-- toward the wall inside one). The building above sits on the tube. Over
-- FlareLength at each end the tube opens out into a mouth with a wide flat
-- floor and curves up each side, like the corkscrew's middle ramp, so a car
-- can drive in off center or at an angle. Each mouth is a hole in a plate
-- across the building's side, and the curve along the building's foot wraps
-- in to meet it. Dim lights hang along the roof.
local function buildTunnel(parent: Instance, area: MapLayout.Area, rng: Random, tube: Tunnel.Tube)
	local B, T = C.Buildings, C.Tunnels
	local rect = tube.rect
	local R = B.CurveRadius
	local thickness = 2
	local halfStep = math.pi / T.Sides
	local face = T.Radius * math.cos(halfStep) -- from the middle line to each plank's inside face
	local chord = 2 * T.Radius * math.sin(halfStep)
	local middleY = Tunnel.centerHeight(T, FLOOR) - FLOOR
	-- The ring's outside corners are this far from the middle line.
	local outside = (face + thickness) / math.cos(halfStep)
	local towerBottom = middleY + outside
	-- The same for the mouths, whose curves are MouthCurve around and sit
	-- either side of a flat floor and roof MouthFloor wide.
	local mouthHalf = T.MouthFloor / 2
	local mouthFace = T.MouthCurve * math.cos(halfStep)
	local mouthMiddleY = mouthFace + Tunnel.LIFT
	local mouthOutside = (mouthFace + thickness) / math.cos(halfStep)

	local height = rng:NextInteger(math.max(B.MinHeight, math.ceil(towerBottom) + 20), B.MaxHeight)
	local color = BUILDING_COLORS[rng:NextInteger(1, #BUILDING_COLORS)]
	local material = BUILDING_MATERIALS[rng:NextInteger(1, #BUILDING_MATERIALS)]
	if tube.warning then
		warn(`City: {tube.warning}`)
	end

	local model = Instance.new("Model")
	model.Name = "TunnelBuilding"
	model.Parent = parent

	local width, depth = rect.x2 - rect.x1, rect.z2 - rect.z1
	local tower = block(
		model,
		"Tower",
		Vector3.new(width, height - towerBottom, depth),
		at(area, (rect.x1 + rect.x2) / 2, (height + towerBottom) / 2, (rect.z1 + rect.z2) / 2),
		color
	)
	tower.Material = material

	local function floorAt(x: number, z: number): Vector3
		return at(area, x, 0, z).Position
	end
	local function plank(cframe: CFrame, length: number)
		block(model, "Plank", Vector3.new(chord + OVERLAP, thickness, length), cframe, TUBE_COLOR)
	end
	-- One ring of planks around the middle line at `middle`, whose cross
	-- section has `side` level and square to the line, `length` along it, or
	-- `lengthAt` for each plank, given how far out to the side it is.
	local function ring(middle: Vector3, side: Vector3, lengthAt: (number) -> number)
		for k = 0, T.Sides - 1 do
			local angle = 2 * halfStep * k -- from the bottom, round toward `side`
			local out = -Vector3.yAxis * math.cos(angle) + side * math.sin(angle)
			local around = side * math.cos(angle) + Vector3.yAxis * math.sin(angle)
			local position = middle + out * (face + thickness / 2)
			plank(CFrame.fromMatrix(position, around, -out), lengthAt(face * math.sin(angle)))
		end
	end

	-- Dim lights along the roof, every LightEvery studs of the middle line.
	local function light(cframe: CFrame)
		local fixture = block(model, "Light", Vector3.new(6, 0.3, 2), cframe, LIGHT_COLOR)
		fixture.Material = Enum.Material.SmoothPlastic
		fixture.CanCollide = false
		fixture.CanQuery = false
		fixture.CanTouch = false
		local glow = Instance.new("PointLight")
		glow.Brightness = T.LightBrightness
		glow.Range = T.LightRange
		glow.Color = LIGHT_COLOR
		glow.Parent = fixture
	end
	local roof = middleY + face - 0.1
	local untilLight = T.LightEvery / 2

	-- The opening from a mouth on the floor at `mouth` in along `inward` to
	-- where it meets the tube, in FlareRows rows of triangles between rings
	-- of the planks' inside corners. Each ring is the tube's, pulled apart
	-- across the middle into a flat floor and roof, its curves eased from
	-- MouthCurve around to Radius and its floor from MouthFloor wide to
	-- nothing, so it meets the tube without a fold.
	local function flare(mouth: Vector3, inward: Vector3)
		local side = Vector3.new(-inward.Z, 0, inward.X)
		local function corners(row: number): ({ Vector3 }, Vector3)
			local t = 1 - row / T.FlareRows
			local ease = t * t * (3 - 2 * t)
			local radius = T.Radius + (T.MouthCurve - T.Radius) * ease
			local flat = mouthHalf * ease
			local middle = mouth
				+ inward * (T.FlareLength * row / T.FlareRows)
				+ Vector3.new(0, radius * math.cos(halfStep) + Tunnel.LIFT, 0)
			local points: { Vector3 } = {}
			for k = 0, T.Sides - 1 do
				local angle = 2 * halfStep * k + halfStep
				local across = radius * math.sin(angle) + flat * math.sign(math.sin(angle))
				table.insert(points, middle + side * across - Vector3.yAxis * radius * math.cos(angle))
			end
			return points, middle
		end
		local back, backMiddle = corners(0)
		for row = 1, T.FlareRows do
			local front, frontMiddle = corners(row)
			local middle = (backMiddle + frontMiddle) / 2
			for k = 1, T.Sides do
				local n = k % T.Sides + 1
				local inside = middle - (back[k] + front[n]) / 2
				for _, wedge in Triangle.make(model, back[k], back[n], front[n], inside, thickness, TUBE_COLOR) do
					wedge.Name = "Plank"
				end
				for _, wedge in Triangle.make(model, back[k], front[n], front[k], inside, thickness, TUBE_COLOR) do
					wedge.Name = "Plank"
				end
			end
			back, backMiddle = front, frontMiddle
		end
	end

	-- The first and last pieces are straights, their outer FlareLength the
	-- bells.
	local pieces = tube.pieces
	local firstPiece, lastPiece = pieces[1], pieces[#pieces]
	local function straightLength(piece: Tunnel.Piece): number
		return if piece.kind == "straight"
			then math.sqrt((piece.toX - piece.fromX) ^ 2 + (piece.toZ - piece.fromZ) ^ 2)
			else 0
	end
	if straightLength(firstPiece) < T.FlareLength or straightLength(lastPiece) < T.FlareLength then
		warn(`City: a {tube.place.Shape} tunnel needs a straight at least FlareLength long at each end`)
	end
	local total = 0
	for _, piece in pieces do
		total += if piece.kind == "straight" then straightLength(piece) else piece.radius * piece.sweep
	end
	-- No lights hang in the bells, where the roof is higher.
	local travelled = 0
	local function lit(distance: number): boolean
		local reached = travelled + distance
		return reached > T.FlareLength and reached < total - T.FlareLength
	end

	for index, piece in pieces do
		if piece.kind == "straight" then
			local from, to = floorAt(piece.fromX, piece.fromZ), floorAt(piece.toX, piece.toZ)
			local length = (to - from).Magnitude
			local along = (to - from).Unit
			local start = if index == 1 then T.FlareLength else 0
			local finish = length - (if index == #pieces then T.FlareLength else 0)
			if finish > start then
				local middle = from + along * (start + finish) / 2 + Vector3.new(0, middleY, 0)
				ring(middle, Vector3.new(-along.Z, 0, along.X), function(_: number): number
					return finish - start
				end)
			end
			if index == 1 then
				flare(from, along)
			end
			if index == #pieces then
				flare(to, -along)
			end
			while untilLight <= length do
				local spot = from + along * untilLight + Vector3.new(0, roof, 0)
				if lit(untilLight) then
					light(CFrame.lookAt(spot, spot + along))
				end
				untilLight += T.LightEvery
			end
			untilLight -= length
			travelled += length
		else
			local center = floorAt(piece.centerX, piece.centerZ)
			local pivot = CFrame.lookAt(center, floorAt(piece.startX, piece.startZ))
			local turn = math.deg(piece.sweep)
			local slices = math.ceil(turn / T.SliceAngle)
			local sliceAngle = turn / slices
			for i = 1, slices do
				local spoke = (pivot * CFrame.Angles(0, math.rad(sliceAngle * (i - 0.5)), 0)).LookVector
				-- Each plank as long as its slice where the car drives on it.
				ring(center + spoke * piece.radius + Vector3.new(0, middleY, 0), spoke, function(out: number): number
					return CurveProfile.sliceLength(piece.radius + out, sliceAngle)
				end)
			end
			-- Lights by distance around the middle line the way the car goes,
			-- which for a right turn is back from the sweep's start.
			local length = piece.radius * piece.sweep
			local left = piece.startX == piece.fromX and piece.startZ == piece.fromZ
			while untilLight <= length do
				local around = if left then untilLight else length - untilLight
				local spot = pivot
					* CFrame.Angles(0, around / piece.radius, 0)
					* CFrame.new(0, roof, -piece.radius)
					* CFrame.Angles(0, math.pi / 2, 0)
				if lit(untilLight) then
					light(spot)
				end
				untilLight += T.LightEvery
			end
			untilLight -= length
			travelled += length
		end
	end

	-- A plate across the building's side at a mouth on the floor at `mouth`,
	-- facing `out`, from `reach` either side of it and from below the floor up
	-- to the tower, with the mouth's outline cut out of it.
	local reach = mouthHalf + mouthOutside + R
	local up, down = towerBottom - mouthMiddleY, mouthOutside
	local function portal(mouth: Vector3, out: Vector3)
		local across = Vector3.new(out.Z, 0, -out.X)
		local function point(t: number, y: number): Vector3
			return mouth + across * t + Vector3.new(0, mouthMiddleY + y, 0)
		end
		local function triangle(a: Vector3, b: Vector3, c: Vector3)
			if (b - a):Cross(c - a).Magnitude < 0.01 then
				return
			end
			for _, wedge in Triangle.make(model, a, b, c, out, thickness, color) do
				wedge.Material = material
			end
		end
		-- The mouth's outline and where each corner of it, seen straight out
		-- from its middle, meets the plate's edge.
		local corners: { { t: number, y: number } } = {}
		local edges: { { t: number, y: number } } = {}
		for k = 0, T.Sides - 1 do
			local angle = 2 * halfStep * k + halfStep
			local t = mouthOutside * math.sin(angle) + mouthHalf * math.sign(math.sin(angle))
			local y = -mouthOutside * math.cos(angle)
			table.insert(corners, { t = t, y = y })
			local scale = math.min(reach / math.abs(t), (if y > 0 then up else down) / math.max(math.abs(y), 1e-9))
			table.insert(edges, { t = t * scale, y = y * scale })
		end
		for k = 1, T.Sides do
			local n = k % T.Sides + 1
			local a, b = corners[k], corners[n]
			local ea, eb = edges[k], edges[n]
			triangle(point(a.t, a.y), point(b.t, b.y), point(eb.t, eb.y))
			triangle(point(a.t, a.y), point(eb.t, eb.y), point(ea.t, ea.y))
			-- Round a corner of the plate where the two edge points are on
			-- different sides of it.
			local onSideA = math.abs(math.abs(ea.t) - reach) < 1e-6
			local onSideB = math.abs(math.abs(eb.t) - reach) < 1e-6
			if onSideA ~= onSideB then
				local corner =
					point(reach * math.sign(ea.t + eb.t), if (if onSideA then eb.y else ea.y) > 0 then up else -down)
				triangle(point(ea.t, ea.y), point(eb.t, eb.y), corner)
			end
		end
	end

	-- The building's sides, each with the curve along its foot and a wall up
	-- to the tower, broken where a mouth opens in it.
	local options: CurvedWall.Options = {
		radius = R,
		endAngle = 90,
		steps = B.CurveSteps,
		thickness = 2,
		color = color,
		material = material,
	}
	local mouths = { floorAt(tube.entry.x, tube.entry.z), floorAt(tube.finish.x, tube.finish.z) }
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
		local stretches = { { 0, length } }
		for _, mouth in mouths do
			local offset = mouth - from
			if math.abs(offset:Dot(out)) < 0.01 then
				local m = offset:Dot(along)
				local last = stretches[#stretches]
				stretches[#stretches] = { last[1], m - reach }
				table.insert(stretches, { m + reach, last[2] })
				outsideCorner(model, from + along * (m - reach), out, along, options)
				outsideCorner(model, from + along * (m + reach), out, -along, options)
				portal(mouth, out)
			end
		end
		for _, stretch in stretches do
			local a, b = stretch[1], stretch[2]
			local middle = from + along * (a + b) / 2
			local base = middle + out * R
			CurvedWall.straight(model, CFrame.lookAt(base, base - out), b - a, options)
			local wallMiddle = middle - out + Vector3.new(0, towerBottom / 2, 0)
			block(model, "Wall", Vector3.new(b - a, towerBottom, 2), CFrame.lookAt(wallMiddle, wallMiddle + out), color).Material =
				material
		end
	end
end

-- Fills the block from z1 down to z2 on both sides of the avenue with
-- buildings in a grid, each a random height, some lots left empty and none
-- where a tunnel building already stands.
local function buildBlock(
	parent: Instance,
	area: MapLayout.Area,
	rng: Random,
	z1: number,
	z2: number,
	taken: { Tunnel.Rect }
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
	local city: Tunnel.City = C :: any
	local tubes = Tunnel.layout(city)
	for index, lots in Tunnel.blocks(city) do
		local taken: { Tunnel.Rect } = {}
		for _, tube in tubes do
			if tube.place.Block == index then
				buildTunnel(model, area, rng, tube)
				table.insert(taken, tube.rect)
			end
		end
		buildBlock(model, area, rng, lots.top, lots.bottom, taken)
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
