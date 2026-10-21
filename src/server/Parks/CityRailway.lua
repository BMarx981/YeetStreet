--!strict
-- CityRailway (ModuleScript) -> ServerScriptService.Parks.CityRailway
-- The dense city's train line (Railway), built by Parks.City. One loop of
-- track: a flat deck with a curve up to straight along each side, like the
-- corkscrew's middle ramp, so a drifting car rides up and back. Elevated on
-- pillars along one street, it ramps down each side strip past the ground,
-- where its curves lie flat so a car can drive on from the side, through
-- an open cutting, and under the ground along the other street, walled and
-- dimly lit with the ground for a roof. The cuttings are cut out of the
-- park's floor and the test park's ground while the game runs; the saved
-- place is never changed. The trains themselves are each client's
-- (TrainSet). Numbers are in Tuning.City.Railway.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CurveProfile = require(ReplicatedStorage.CurveProfile)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Railway = require(ReplicatedStorage.Railway)
local Tuning = require(ReplicatedStorage.Tuning)
local Tunnel = require(ReplicatedStorage.Tunnel)
local CurvedWall = require(ServerScriptService.Pieces.CurvedWall)
local Triangle = require(ServerScriptService.Pieces.Triangle)

local R = Tuning.City.Railway
local FLOOR = Tuning.Map.FloorTop

local DECK_COLOR = Color3.fromRGB(110, 106, 100)
local RAIL_COLOR = Color3.fromRGB(70, 70, 76)
local PILLAR_COLOR = Color3.fromRGB(150, 150, 150)
local WALL_COLOR = Color3.fromRGB(120, 116, 110)
local LIGHT_COLOR = Color3.fromRGB(255, 214, 160)

local CityRailway = {}

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

local function edgeOptions(): CurvedWall.Options
	return {
		radius = R.EdgeRadius,
		endAngle = 90,
		steps = R.EdgeSteps,
		thickness = R.Thickness,
		color = DECK_COLOR,
	}
end

-- From the deck's middle to the outside of its curves, either side.
local function halfWidth(): number
	return R.DeckWidth / 2 + R.EdgeRadius + R.Thickness
end

-- The deck at `t` along a piece: its middle on top, the way it runs, and
-- the way that is up from it.
local function frameAt(area: MapLayout.Area, piece: Tunnel.Piece, t: number): CFrame
	local function point(u: number): Vector3
		local x, y, z = Tunnel.pointAt(piece, math.clamp(u, 0, 1))
		return Vector3.new(area.X + x, FLOOR + y, area.Z + z)
	end
	local here = point(t)
	local along = (point(t + 0.001) - point(t - 0.001)).Unit
	return CFrame.lookAt(here, here + along, Vector3.yAxis)
end

-- A dim light on the subway's roof.
local function light(parent: Instance, cframe: CFrame)
	local fixture = block(parent, "Light", Vector3.new(6, 0.3, 2), cframe, LIGHT_COLOR)
	fixture.Material = Enum.Material.SmoothPlastic
	fixture.CanCollide = false
	fixture.CanQuery = false
	fixture.CanTouch = false
	local glow = Instance.new("PointLight")
	glow.Brightness = Tuning.City.Tunnels.LightBrightness
	glow.Range = Tuning.City.Tunnels.LightRange
	glow.Color = LIGHT_COLOR
	glow.Parent = fixture
end

-- The curve along each side of the deck between frames `a` and `b`, curled
-- from `curlA` to `curlB` (0 lies flat out from the deck, 1 is the full
-- curve), as rows of triangles (CurveProfile.curl).
local function curledEdges(parent: Instance, a: CFrame, b: CFrame, curlA: number, curlB: number)
	local profileA = CurveProfile.curl(R.EdgeRadius, 90, R.EdgeSteps, curlA)
	local profileB = CurveProfile.curl(R.EdgeRadius, 90, R.EdgeSteps, curlB)
	for _, side in { -1, 1 } do
		local function corner(frame: CFrame, p: CurveProfile.Point): Vector3
			return frame:PointToWorldSpace(Vector3.new(side * (R.DeckWidth / 2 + p.out), p.up, 0))
		end
		local inward = (a.UpVector - a.RightVector * side)
		for k = 1, #profileA - 1 do
			local a0, a1 = corner(a, profileA[k]), corner(a, profileA[k + 1])
			local b0, b1 = corner(b, profileB[k]), corner(b, profileB[k + 1])
			Triangle.make(parent, a0, a1, b1, inward, R.Thickness, DECK_COLOR)
			Triangle.make(parent, a0, b1, b0, inward, R.Thickness, DECK_COLOR)
		end
	end
end

-- Cuts `holes` (park coordinates) out of every level, square part in
-- `parts` that they overlap, replacing it with the pieces around them.
local function cutGround(area: MapLayout.Area, parts: { BasePart }, holes: { Railway.Rect })
	local world: { Railway.Rect } = {}
	for _, hole in holes do
		table.insert(
			world,
			{ x1 = area.X + hole.x1, x2 = area.X + hole.x2, z1 = area.Z + hole.z1, z2 = area.Z + hole.z2 }
		)
	end
	for _, part in parts do
		if part.Orientation.Magnitude > 0.01 then
			continue
		end
		local p, s = part.Position, part.Size
		local rect = { x1 = p.X - s.X / 2, x2 = p.X + s.X / 2, z1 = p.Z - s.Z / 2, z2 = p.Z + s.Z / 2 }
		local pieces = Railway.cut(rect, world)
		if #pieces == 1 and pieces[1] == rect then
			continue
		end
		for _, piece in pieces do
			local copy = part:Clone()
			copy.Size = Vector3.new(piece.x2 - piece.x1, s.Y, piece.z2 - piece.z1)
			copy.CFrame = CFrame.new((piece.x1 + piece.x2) / 2, p.Y, (piece.z1 + piece.z2) / 2)
			copy.Parent = part.Parent
		end
		part:Destroy()
	end
end

-- The bottom of the test park's ground, which is the subway's roof.
local function groundBottom(): number
	local lowest = math.huge
	local testPark = workspace:FindFirstChild("TestPark")
	local ground = testPark and testPark:FindFirstChild("Ground")
	if ground then
		for _, tile in ground:GetChildren() do
			if tile:IsA("BasePart") then
				lowest = math.min(lowest, tile.Position.Y - tile.Size.Y / 2)
			end
		end
	end
	if lowest == math.huge then
		warn("CityRailway: no TestPark.Ground found; the subway's roof is open")
		return FLOOR - 4
	end
	return lowest
end

function CityRailway.build(folder: Folder, area: MapLayout.Area)
	local model = Instance.new("Model")
	model.Name = "Railway"
	model.Parent = folder

	local line: Railway.Line = R :: any
	local start = Railway.start(line)
	local pieces = Tunnel.path(start.x, start.z, start.headingX, start.headingZ, Railway.segments(line) :: any, start.y)
	local roof = groundBottom() - FLOOR -- from the floor, like the deck's heights
	local half = halfWidth()
	local options = edgeOptions()
	local holes: { Railway.Rect } = {}
	local untilPillar = R.PillarEvery / 2
	local untilLight = R.LightEvery / 2

	for _, piece in pieces do
		local length = Tunnel.length(piece)
		local climbs = math.abs(piece.toY - piece.fromY) > 0.01

		-- Where along the piece each part of deck starts and ends. A ramp
		-- passing the ground gets CurlRows short parts over CurlLength on its
		-- uphill side, whose curves curl flat toward the ground.
		local cuts: { number } = {}
		local curlFrom, curlTo = -1, -1
		if piece.kind == "arc" then
			local slices = math.ceil(math.deg(piece.sweep) / R.SliceAngle)
			for i = 0, slices do
				table.insert(cuts, i / slices)
			end
			-- Turns are level: a curve swept round the outside edge, rising
			-- away from the turn, and round the inside edge, rising toward it.
			local center = Vector3.new(area.X + piece.centerX, FLOOR + piece.fromY, area.Z + piece.centerZ)
			local pivot =
				CFrame.lookAt(center, Vector3.new(area.X + piece.startX, FLOOR + piece.fromY, area.Z + piece.startZ))
			local turn = math.deg(piece.sweep)
			CurvedWall.corner(model, pivot, piece.radius + R.DeckWidth / 2, turn, slices, options)
			CurvedWall.outside(model, pivot, piece.radius - R.DeckWidth / 2, turn, slices, options)
		elseif climbs then
			-- Where the deck's top passes the floor: height is fromY +
			-- (toY - fromY) * ease(t), solved by bisection.
			local lo, hi = 0, 1
			for _ = 1, 40 do
				local mid = (lo + hi) / 2
				local _, y = Tunnel.pointAt(piece, mid)
				if (y > 0) == (piece.fromY > 0) then
					lo = mid
				else
					hi = mid
				end
			end
			local ground = (lo + hi) / 2
			local uphill = if piece.toY > piece.fromY then 1 else -1
			local reach = R.CurlLength / length
			curlFrom, curlTo = math.min(ground, ground + uphill * reach), math.max(ground, ground + uphill * reach)
			local steps = math.ceil(length / R.StepLength)
			for i = 0, steps do
				local t = i / steps
				if t < curlFrom or t > curlTo then
					table.insert(cuts, t)
				end
			end
			for i = 0, R.CurlRows do
				table.insert(cuts, curlFrom + (curlTo - curlFrom) * i / R.CurlRows)
			end
			table.sort(cuts)
		else
			cuts = { 0, 1 }
		end

		-- This piece's open cutting, if it has one.
		local cutting: Railway.Rect? = nil

		-- How flat the curves lie at `t`: 0 at the ground, 1 a CurlLength
		-- either way and beyond. Downhill, the flat curves go under the
		-- ground beside the cutting.
		local function curl(t: number): number
			if curlTo < 0 then
				return 1
			end
			local ground = if piece.toY > piece.fromY then curlFrom else curlTo
			return Tunnel.ease(math.clamp(math.abs(t - ground) * length / R.CurlLength, 0, 1))
		end

		for i = 1, #cuts - 1 do
			local t0, t1 = cuts[i], cuts[i + 1]
			if t1 - t0 < 1e-6 then
				continue
			end
			local a, b = frameAt(area, piece, t0), frameAt(area, piece, t1)
			local middle = frameAt(area, piece, (t0 + t1) / 2)
			local _, y = Tunnel.pointAt(piece, (t0 + t1) / 2)
			local span = (b.Position - a.Position).Magnitude
			-- Long enough to close the seam where the deck bends up or down.
			local bend = math.abs(math.asin(b.LookVector.Y) - math.asin(a.LookVector.Y))

			if piece.kind == "arc" then
				-- A slice of the turn: deck as wide as its outer edge, so the
				-- slices overlap on the inside, and a curve each side.
				local sliceAngle = math.deg(piece.sweep) * (t1 - t0)
				local deckLength = CurveProfile.sliceLength(piece.radius + R.DeckWidth / 2, sliceAngle)
				block(
					model,
					"Deck",
					Vector3.new(R.DeckWidth, R.Thickness, deckLength),
					middle * CFrame.new(0, -R.Thickness / 2, 0),
					DECK_COLOR
				)
			else
				block(
					model,
					"Deck",
					Vector3.new(R.DeckWidth, R.Thickness, span + R.Thickness * bend),
					middle * CFrame.new(0, -R.Thickness / 2, 0),
					DECK_COLOR
				)
				local c0, c1 = curl(t0), curl(t1)
				if c0 < 0.999 or c1 < 0.999 then
					curledEdges(model, a, b, c0, c1)
				else
					for _, side in { -1, 1 } do
						local edge = middle * CFrame.new(side * R.DeckWidth / 2, 0, 0)
						local out = edge.RightVector * side
						CurvedWall.straight(
							model,
							CFrame.fromMatrix(edge.Position, out:Cross(edge.UpVector), edge.UpVector),
							span + R.EdgeRadius * bend,
							options
						)
					end
				end
			end
			-- Rails, for show only.
			for _, side in { -1, 1 } do
				local rail =
					block(model, "Rail", Vector3.new(1, 0.4, span), middle * CFrame.new(side * 6, 0.2, 0), RAIL_COLOR)
				rail.CanCollide = false
				rail.CanQuery = false
				rail.CanTouch = false
			end

			-- Under the deck: pillars where it is high, a solid fill where a
			-- car could only just get under it, nothing where it is under the
			-- ground. Under the ground: walls up to the roof, or to the floor
			-- in the open cutting.
			local under = y - R.Thickness
			if under > R.FillBelow then
				untilPillar -= span
				if untilPillar <= 0 then
					block(
						model,
						"Pillar",
						Vector3.new(R.PillarSize, under, R.PillarSize),
						CFrame.new(middle.Position.X, FLOOR + under / 2, middle.Position.Z),
						PILLAR_COLOR
					)
					untilPillar += R.PillarEvery
				end
			elseif under > 0 then
				block(
					model,
					"Fill",
					Vector3.new(2 * half, under, span),
					CFrame.lookAt(
						Vector3.new(middle.Position.X, FLOOR + under / 2, middle.Position.Z),
						Vector3.new(middle.Position.X, FLOOR + under / 2, middle.Position.Z)
							+ Vector3.new(middle.LookVector.X, 0, middle.LookVector.Z)
					),
					DECK_COLOR
				)
			elseif y < 0 then
				local covered = y <= -R.RoofClear
				local top = if covered then roof else 0
				local bottom = y + R.EdgeRadius
				if top > bottom then
					for _, side in { -1, 1 } do
						local level = CFrame.lookAt(
							middle.Position,
							middle.Position + Vector3.new(middle.LookVector.X, 0, middle.LookVector.Z)
						)
						local centre = level.Position + level.RightVector * side * (half - R.Thickness / 2)
						block(
							model,
							"Wall",
							Vector3.new(R.Thickness, top - bottom, span + 2),
							CFrame.new(centre.X, FLOOR + (top + bottom) / 2, centre.Z) * level.Rotation,
							WALL_COLOR
						)
					end
				end
				if covered then
					untilLight -= span
					if untilLight <= 0 then
						local spot = Vector3.new(middle.Position.X, FLOOR + roof - 0.2, middle.Position.Z)
						light(model, CFrame.lookAt(spot, spot + middle.LookVector * Vector3.new(1, 0, 1)))
						untilLight += R.LightEvery
					end
				else
					-- The open cutting: grow this piece's hole in the ground
					-- over this part.
					local p = middle.Position
					local x, z = p.X - area.X, p.Z - area.Z
					local reachX = math.abs(middle.LookVector.X) * span / 2 + math.abs(middle.LookVector.Z) * half
					local reachZ = math.abs(middle.LookVector.Z) * span / 2 + math.abs(middle.LookVector.X) * half
					local hole = cutting or { x1 = math.huge, x2 = -math.huge, z1 = math.huge, z2 = -math.huge }
					hole.x1, hole.x2 = math.min(hole.x1, x - reachX), math.max(hole.x2, x + reachX)
					hole.z1, hole.z2 = math.min(hole.z1, z - reachZ), math.max(hole.z2, z + reachZ)
					cutting = hole
				end
			end
		end
		if cutting then
			table.insert(holes, cutting)
		end
	end

	-- Open the cuttings in the park's floor and the test park's ground.
	local parts: { BasePart } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Floor" then
			table.insert(parts, child)
		end
	end
	local testPark = workspace:FindFirstChild("TestPark")
	local ground = testPark and testPark:FindFirstChild("Ground")
	if ground then
		for _, tile in ground:GetChildren() do
			if tile:IsA("BasePart") then
				table.insert(parts, tile)
			end
		end
	end
	cutGround(area, parts, holes)
end

return CityRailway
