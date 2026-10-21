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

-- The edge along each side of the deck between frames `a` and `b`, shaped
-- from `profileA` to `profileB` (CurveProfile points with as many corners),
-- as rows of triangles. Rows shrunk to nothing at one end are left out.
local function sideEdges(
	parent: Instance,
	a: CFrame,
	b: CFrame,
	profileA: { CurveProfile.Point },
	profileB: { CurveProfile.Point }
)
	for _, side in { -1, 1 } do
		local function corner(frame: CFrame, p: CurveProfile.Point): Vector3
			return frame:PointToWorldSpace(Vector3.new(side * (R.DeckWidth / 2 + p.out), p.up, 0))
		end
		local function triangle(p: Vector3, q: Vector3, r: Vector3, inward: Vector3)
			if (q - p):Cross(r - p).Magnitude > 1e-4 then
				Triangle.make(parent, p, q, r, inward, R.Thickness, DECK_COLOR)
			end
		end
		local inward = (a.UpVector - a.RightVector * side)
		for k = 1, #profileA - 1 do
			local a0, a1 = corner(a, profileA[k]), corner(a, profileA[k + 1])
			local b0, b1 = corner(b, profileB[k]), corner(b, profileB[k + 1])
			triangle(a0, a1, b1, inward)
			triangle(a0, b1, b0, inward)
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
		-- either way and beyond. Downhill is the open cutting, where the
		-- curves are cut off at the ground instead.
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
				-- Up high, a wall on top of each curve to keep a car on the
				-- turn, each block as long as its slice at the wall's face
				-- that is farther round.
				if y > R.FillBelow then
					for _, side in { -1, 1 } do
						local far = if side > 0 then piece.radius + half else piece.radius - half + R.Thickness
						local centre = middle.Position + middle.RightVector * side * (half - R.Thickness / 2)
						block(
							model,
							"TurnWall",
							Vector3.new(R.Thickness, R.TurnWall + 1, CurveProfile.sliceLength(far, sliceAngle)),
							CFrame.new(centre + Vector3.new(0, R.EdgeRadius + (R.TurnWall - 1) / 2, 0))
								* middle.Rotation,
							DECK_COLOR
						)
					end
					-- Its top curves on past straight up, leaning in over the
					-- track, so a car leaving it heads back over the deck: a
					-- plank per step of the curve, as long as its slice where
					-- it is farther round, its back away from the curve's middle.
					local lip = CurveProfile.arc(R.TurnLipRadius, 90, R.TurnLipAngle, R.TurnLipSteps)
					local base = R.DeckWidth / 2 + R.EdgeRadius - R.TurnLipRadius
					for _, side in { -1, 1 } do
						local lateral = middle.RightVector * side
						for k = 1, #lip - 1 do
							local p, q = lip[k], lip[k + 1]
							local out, up = (p.out + q.out) / 2, (p.up + q.up) / 2
							local away = (lateral * out + Vector3.yAxis * (up - R.TurnLipRadius)).Unit
							local far = if side > 0
								then piece.radius + base + math.max(p.out, q.out) + R.Thickness
								else piece.radius - base - math.min(p.out, q.out)
							block(
								model,
								"TurnLip",
								Vector3.new(
									CurveProfile.sliceLength(far, sliceAngle),
									R.Thickness,
									math.sqrt((q.out - p.out) ^ 2 + (q.up - p.up) ^ 2) + 0.4
								),
								CFrame.fromMatrix(
									middle.Position
										+ lateral * (base + out)
										+ Vector3.yAxis * (R.EdgeRadius + R.TurnWall - R.TurnLipRadius + up)
										+ away * R.Thickness / 2,
									middle.LookVector,
									away
								),
								DECK_COLOR
							)
						end
					end
				end
			else
				block(
					model,
					"Deck",
					Vector3.new(R.DeckWidth, R.Thickness, span + R.Thickness * bend),
					middle * CFrame.new(0, -R.Thickness / 2, 0),
					DECK_COLOR
				)
				local c0, c1 = curl(t0), curl(t1)
				local _, y0 = Tunnel.pointAt(piece, t0)
				local _, y1 = Tunnel.pointAt(piece, t1)
				if y < 0 and y > -R.RoofClear and math.min(-y0, -y1) < R.EdgeRadius then
					-- In the open cutting, curves that would stick up past the
					-- ground stop at it and run flat out to the hole's edge, so
					-- a car rolls over the edge and drops in from the side.
					local reach = R.EdgeRadius + R.Thickness
					sideEdges(
						model,
						a,
						b,
						CurveProfile.clip(R.EdgeRadius, 90, R.EdgeSteps, -y0 / a.UpVector.Y, reach),
						CurveProfile.clip(R.EdgeRadius, 90, R.EdgeSteps, -y1 / b.UpVector.Y, reach)
					)
				elseif c0 < 0.999 or c1 < 0.999 then
					sideEdges(
						model,
						a,
						b,
						CurveProfile.curl(R.EdgeRadius, 90, R.EdgeSteps, c0),
						CurveProfile.curl(R.EdgeRadius, 90, R.EdgeSteps, c1)
					)
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

			-- Under the deck: pillars every PillarEvery where it is high, but
			-- none on the turns, a solid fill where a car could only just get
			-- under it, nothing where it is under the ground. Under the
			-- ground: walls up to the roof, or to the floor in the open
			-- cutting.
			local under = y - R.Thickness
			if under > R.FillBelow then
				local at = untilPillar
				while at <= span do
					local spot = a.Position:Lerp(b.Position, at / span)
					local height = spot.Y - FLOOR - R.Thickness
					if piece.kind ~= "arc" then
						block(
							model,
							"Pillar",
							Vector3.new(R.PillarSize, height, R.PillarSize),
							CFrame.new(spot.X, FLOOR + height / 2, spot.Z),
							PILLAR_COLOR
						)
					end
					at += R.PillarEvery
				end
				untilPillar = at - span
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
					-- On a turn, as long as the slice is at the walls' outside
					-- face, so the outer wall's blocks meet.
					local wallLength = if piece.kind == "arc"
						then CurveProfile.sliceLength(piece.radius + half, math.deg(piece.sweep) * (t1 - t0))
						else span + 2
					for _, side in { -1, 1 } do
						local level = CFrame.lookAt(
							middle.Position,
							middle.Position + Vector3.new(middle.LookVector.X, 0, middle.LookVector.Z)
						)
						local centre = level.Position + level.RightVector * side * (half - R.Thickness / 2)
						block(
							model,
							"Wall",
							Vector3.new(R.Thickness, top - bottom, wallLength),
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

	-- Each elevated turn's walls taper down to its curves' tops over
	-- TurnWallRun along the straights either side, as a triangle each side.
	for index, piece in pieces do
		if piece.kind ~= "arc" or piece.fromY <= R.FillBelow then
			continue
		end
		local before = pieces[(index - 2) % #pieces + 1]
		local after = pieces[index % #pieces + 1]
		for _, finish in
			{ { t = 0, neighbor = before, from = 1, toward = -1 }, { t = 1, neighbor = after, from = 0, toward = 1 } }
		do
			local here = frameAt(area, piece, finish.t)
			local run = R.TurnWallRun / Tunnel.length(finish.neighbor)
			local there = frameAt(area, finish.neighbor, finish.from + finish.toward * run)
			for _, side in { -1, 1 } do
				local function face(frame: CFrame, up: number): Vector3
					return frame.Position + frame.RightVector * side * (half - R.Thickness) + Vector3.new(0, up, 0)
				end
				Triangle.make(
					model,
					face(here, R.EdgeRadius - 1),
					face(here, R.EdgeRadius + R.TurnWall),
					face(there, R.EdgeRadius - 1),
					-here.RightVector * side,
					R.Thickness,
					DECK_COLOR
				)
			end
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
