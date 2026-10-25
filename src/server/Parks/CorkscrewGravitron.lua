--!strict
-- CorkscrewGravitron (ModuleScript) -> ServerScriptService.Parks.CorkscrewGravitron
-- The Corkscrew park's gravitron (GravitronRide, Tuning.Corkscrew.Gravitron):
-- a tilted bowl whose round floor curves up into a wall leaning out to an
-- open rim, on a skirt so nobody drives under it. Two tubes come in from
-- wide mouths at either end, with funnels in front that curl up into them,
-- dive under the ground, and twist round each other up through the floor,
-- where they are cut off and the floor closes round the holes. A ring of
-- launch pads near the top of each throws a car up the last climb.
--
-- The bowl does not turn. Each client draws it spinning (GravitronLook) and
-- pushes its car round (CarController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CurveProfile = require(ReplicatedStorage.CurveProfile)
local Gravitron = require(ReplicatedStorage.Gravitron)
local GravitronRide = require(ReplicatedStorage.GravitronRide)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Railway = require(ReplicatedStorage.Railway)
local Tunnel = require(ReplicatedStorage.Tunnel)
local Tuning = require(ReplicatedStorage.Tuning)
local CurvedWall = require(ServerScriptService.Pieces.CurvedWall)
local LaunchPad = require(ServerScriptService.Pieces.LaunchPad)
local Triangle = require(ServerScriptService.Pieces.Triangle)
local Tube = require(ServerScriptService.Pieces.Tube)

local G = Tuning.Corkscrew.Gravitron
local T = G.Tubes
local C = Tuning.City.Tunnels

local BOWL_COLOR = Color3.fromRGB(196, 200, 210)
local FUNNEL_COLOR = Color3.fromRGB(255, 150, 40)
local GROUND_COLOR = Color3.fromRGB(170, 170, 165) -- ParkBuilder's floor
local GROUND_THICKNESS = 1 -- ParkBuilder's floor
-- The bottom of TestPark's ground slab, under the park's floor.
local GROUND_BOTTOM = -4 - Tuning.Map.FloorTop
-- Planks are this much longer than their chord so the seams stay closed.
local OVERLAP = 0.4

local OPTIONS: Tube.Options = {
	Radius = C.Radius,
	Sides = C.Sides,
	MouthFloor = T.MouthFloor,
	MouthCurve = T.MouthCurve,
	FlareLength = T.FlareLength,
	FlareRows = T.FlareRows,
	StepLength = C.StepLength,
	LightEvery = C.LightEvery,
	LightBrightness = C.LightBrightness,
	LightRange = C.LightRange,
}

local CorkscrewGravitron = {}

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

local function triangle(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	up: Vector3,
	thickness: number,
	color: Color3
)
	if (b - a):Cross(c - a).Magnitude < 0.01 then
		return
	end
	Triangle.make(parent, a, b, c, up, thickness, color)
end

-- The curve from the floor up into the wall, then the wall leaning out to
-- the rim, one plank a slice, as wide as its slice at the rim, in a Model
-- named Bowl, whose planks each client paints in turning stripes
-- (GravitronLook).
local function buildBowl(model: Instance, bowl: CFrame)
	local parent = Instance.new("Model")
	parent.Name = "Bowl"
	parent.Parent = model
	CurvedWall.corner(parent, bowl, G.FloorRadius, 360, G.Slices, {
		radius = G.CurveRadius,
		endAngle = 90 - G.Lean,
		steps = G.CurveSteps,
		thickness = G.Thickness,
		color = BOWL_COLOR,
	})
	local footR, footY = Gravitron.foot(GravitronRide.shape)
	local rimR = Gravitron.rimRadius(GravitronRide.shape)
	local sliceAngle = 360 / G.Slices
	local size = Vector3.new(
		CurveProfile.sliceLength(rimR, sliceAngle),
		G.Thickness,
		(G.Height - footY) / math.cos(math.rad(G.Lean)) + OVERLAP
	)
	-- Laid like CurvedWall's planks: out along the slice's -Z, tilted up.
	local out, up = (footR + rimR) / 2 - G.FloorRadius, (footY + G.Height) / 2
	for i = 1, G.Slices do
		local base = bowl * CFrame.Angles(0, math.rad(sliceAngle * (i - 0.5)), 0) * CFrame.new(0, 0, -G.FloorRadius)
		block(
			parent,
			"Plank",
			size,
			base
				* CFrame.new(0, up, -out)
				* CFrame.Angles(math.rad(90 - G.Lean), 0, 0)
				* CFrame.new(0, -G.Thickness / 2, 0),
			BOWL_COLOR
		)
	end
end

-- A wall round under the bowl, from below the ground up to the floor's
-- underside, in triangles so its top follows the tilt.
local function buildSkirt(parent: Instance, ground: CFrame)
	local tilt = math.rad(G.Tilt)
	local function top(z: number): number
		return GravitronRide.centerHeight + (-G.Thickness - z * math.sin(tilt)) / math.cos(tilt)
	end
	local S, n = G.Skirt.Radius, G.Skirt.Slices
	for i = 0, n - 1 do
		local a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
		local x0, z0 = S * math.sin(a0), S * math.cos(a0)
		local x1, z1 = S * math.sin(a1), S * math.cos(a1)
		local b0 = ground:PointToWorldSpace(Vector3.new(x0, -GROUND_THICKNESS, z0))
		local b1 = ground:PointToWorldSpace(Vector3.new(x1, -GROUND_THICKNESS, z1))
		local t0 = ground:PointToWorldSpace(Vector3.new(x0, top(z0), z0))
		local t1 = ground:PointToWorldSpace(Vector3.new(x1, top(z1), z1))
		local inward = ground:VectorToWorldSpace(Vector3.new(-(x0 + x1), 0, -(z0 + z1))).Unit
		triangle(parent, b0, b1, t1, inward, G.Thickness, BOWL_COLOR)
		triangle(parent, b0, t1, t0, inward, G.Thickness, BOWL_COLOR)
	end
end

-- The floor round one hole: from the rectangle cut for it in to the hole's
-- outline, a quad from each edge of the outline out to where the rays from
-- the hole's middle through its ends meet the rectangle, and the
-- rectangle's corners between.
local function buildCollar(parent: Instance, bowl: CFrame, outline: { Vector2 }, middle: Vector2, rect: Railway.Rect)
	local function at(p: Vector2): Vector3
		return bowl:PointToWorldSpace(Vector3.new(p.X, 0, p.Y))
	end
	-- Sides 1 to 4 counterclockwise from +X, as the outline runs, and the
	-- corner after each.
	local corners = {
		Vector2.new(rect.x2, rect.z2),
		Vector2.new(rect.x1, rect.z2),
		Vector2.new(rect.x1, rect.z1),
		Vector2.new(rect.x2, rect.z1),
	}
	local function border(p: Vector2): (Vector2, number)
		local d = p - middle
		local best, side = math.huge, 1
		local function try(t: number, s: number)
			if t > 0 and t < best then
				best, side = t, s
			end
		end
		if d.X > 0 then
			try((rect.x2 - middle.X) / d.X, 1)
		elseif d.X < 0 then
			try((rect.x1 - middle.X) / d.X, 3)
		end
		if d.Y > 0 then
			try((rect.z2 - middle.Y) / d.Y, 2)
		elseif d.Y < 0 then
			try((rect.z1 - middle.Y) / d.Y, 4)
		end
		return middle + d * best, side
	end
	local up = bowl.UpVector
	for i, p in outline do
		local q = outline[i % #outline + 1]
		local bp, sp = border(p)
		local bq, sq = border(q)
		triangle(parent, at(p), at(q), at(bq), up, GROUND_THICKNESS, BOWL_COLOR)
		-- Fanned from p along the rectangle from bp, round any corners, to bq.
		local from, side = bp, sp
		while side ~= sq do
			local corner = corners[side]
			triangle(parent, at(p), at(from), at(corner), up, GROUND_THICKNESS, BOWL_COLOR)
			from = corner
			side = side % 4 + 1
		end
		triangle(parent, at(p), at(from), at(bq), up, GROUND_THICKNESS, BOWL_COLOR)
	end
end

-- The floor, in strips across the bowl's Z, with a rectangle cut round
-- each hole where a tube comes up (`outlines`, where its planks were cut
-- off) and a collar closing it in to the hole.
local function buildFloor(parent: Instance, bowl: CFrame, outlines: { { Vector3 } })
	local holes: { Railway.Rect } = {}
	local collars: { { outline: { Vector2 }, middle: Vector2, rect: Railway.Rect } } = {}
	for _, points in outlines do
		local outline: { Vector2 } = {}
		local sum = Vector2.zero
		for _, p in points do
			local q = bowl:PointToObjectSpace(p)
			table.insert(outline, Vector2.new(q.X, q.Z))
			sum += Vector2.new(q.X, q.Z)
		end
		if #outline < 3 then
			warn("CorkscrewGravitron: a tube did not come up through the floor")
			continue
		end
		local middle = sum / #outline
		table.sort(outline, function(a: Vector2, b: Vector2): boolean
			return math.atan2(a.Y - middle.Y, a.X - middle.X) < math.atan2(b.Y - middle.Y, b.X - middle.X)
		end)
		local kept: { Vector2 } = {}
		for _, p in outline do
			if #kept == 0 or (p - kept[#kept]).Magnitude > 0.3 then
				table.insert(kept, p)
			end
		end
		local rect = { x1 = math.huge, x2 = -math.huge, z1 = math.huge, z2 = -math.huge }
		for _, p in kept do
			rect.x1, rect.x2 = math.min(rect.x1, p.X - 2), math.max(rect.x2, p.X + 2)
			rect.z1, rect.z2 = math.min(rect.z1, p.Y - 2), math.max(rect.z2, p.Y + 2)
		end
		if math.sqrt(math.max(rect.x1 ^ 2, rect.x2 ^ 2) + math.max(rect.z1 ^ 2, rect.z2 ^ 2)) > G.FloorRadius then
			warn("CorkscrewGravitron: a tube comes up past the floor's edge; lower ExitAngle's reach or TwistRadius")
		end
		table.insert(holes, rect)
		table.insert(collars, { outline = kept, middle = middle, rect = rect })
	end

	local F = G.FloorRadius
	local z = -F
	while z < F - 1e-6 do
		local z2 = math.min(z + G.FloorStrip, F)
		-- As long as the strip's inner edge reaches; past the circle it lies
		-- under the curve.
		local inner = if z < 0 and z2 > 0 then 0 else math.min(math.abs(z), math.abs(z2))
		local half = math.sqrt(F * F - inner * inner)
		for _, piece in Railway.cut({ x1 = -half, x2 = half, z1 = z, z2 = z2 }, holes) do
			block(
				parent,
				"Floor",
				Vector3.new(piece.x2 - piece.x1, G.Thickness, piece.z2 - piece.z1),
				bowl * CFrame.new((piece.x1 + piece.x2) / 2, -G.Thickness / 2, (piece.z1 + piece.z2) / 2),
				BOWL_COLOR
			)
		end
		z = z2
	end
	for _, collar in collars do
		buildCollar(parent, bowl, collar.outline, collar.middle, collar.rect)
	end
end

-- Launch pads lining the tube BoostAt of the way along a strand's exit,
-- just inside its planks, so cars ride through them and CarSensor's rays
-- find them, pushing up the exit.
local function buildBoost(parent: Instance, bowl: CFrame, strand: Tunnel.GravitronStrand, respawn: CFrame)
	local exit = strand.twist[#strand.twist]
	local x, y, z = Tunnel.pointAt(exit, T.BoostAt)
	local x2, y2, z2 = Tunnel.pointAt(exit, T.BoostAt + 0.001)
	local middle = bowl:PointToWorldSpace(Vector3.new(x, y, z))
	local along = (bowl:PointToWorldSpace(Vector3.new(x2, y2, z2)) - middle).Unit
	local flat = bowl:VectorToObjectSpace(along)
	local side = bowl:VectorToWorldSpace(Vector3.new(-flat.Z, 0, flat.X).Unit)
	local up = side:Cross(along)
	local halfStep = math.pi / OPTIONS.Sides
	local face = OPTIONS.Radius * math.cos(halfStep)
	local chord = 2 * OPTIONS.Radius * math.sin(halfStep)
	for k = 0, OPTIONS.Sides - 1 do
		local angle = 2 * halfStep * k
		local out = -up * math.cos(angle) + side * math.sin(angle)
		local around = side * math.cos(angle) + up * math.sin(angle)
		local pad = block(
			parent,
			"LaunchPad",
			Vector3.new(chord, 0.2, T.BoostLength),
			CFrame.fromMatrix(middle + out * (face - 0.2), around, -out),
			BOWL_COLOR
		)
		pad.CanCollide = false
		pad.CanTouch = false
		LaunchPad.make(pad, T.BoostSpeed, respawn, G.PayScale, along)
	end
end

-- The funnel in front of a strand's mouth: a wall each side that lies flat
-- on the ground at its open end, FunnelSpread out, and curls in and up
-- over FunnelLength to the mouth's curve, in FunnelRows rows of triangles.
-- At the mouth its corners are the mouth's own (Pieces.Tube's flare), up to
-- the curve's top.
local function buildFunnel(parent: Instance, ground: CFrame, strand: Tunnel.GravitronStrand)
	local inward = ground:VectorToWorldSpace(Vector3.new(strand.heading, 0, 0))
	local side = Vector3.new(-inward.Z, 0, inward.X)
	local mouth = ground:PointToWorldSpace(Vector3.new(strand.mouth.x, 0, strand.mouth.z))
	local halfStep = math.pi / OPTIONS.Sides
	local R, flat = T.MouthCurve, T.MouthFloor / 2
	local middleY = R * math.cos(halfStep) + Tunnel.LIFT
	-- Across and up, curled into the mouth and lying flat the same length.
	local curled: { Vector2 } = {}
	local lying: { Vector2 } = {}
	for k = 0, OPTIONS.Sides // 4 - 1 do
		local angle = 2 * halfStep * k + halfStep
		table.insert(curled, Vector2.new(flat + R * math.sin(angle), middleY - R * math.cos(angle)))
		table.insert(lying, Vector2.new(flat + R * math.sin(halfStep) + R * (angle - halfStep), Tunnel.LIFT))
	end
	for _, sign in { 1, -1 } do
		local function row(j: number): { Vector3 }
			local e = Tunnel.ease(j / T.FunnelRows)
			local points: { Vector3 } = {}
			for k, c in curled do
				local p = lying[k]:Lerp(c, 1 - e)
				table.insert(
					points,
					mouth
						- inward * (T.FunnelLength * j / T.FunnelRows)
						+ side * (sign * (p.X + T.FunnelSpread * e))
						+ Vector3.yAxis * p.Y
				)
			end
			return points
		end
		local normal = (Vector3.yAxis - side * sign).Unit
		local back = row(0)
		for j = 1, T.FunnelRows do
			local front = row(j)
			for k = 1, #front - 1 do
				triangle(parent, back[k], back[k + 1], front[k + 1], normal, G.Thickness, FUNNEL_COLOR)
				triangle(parent, back[k], front[k + 1], front[k], normal, G.Thickness, FUNNEL_COLOR)
			end
			back = front
		end
	end
end

-- Seen from above in the ground space, where a strand's approach dives
-- through the ground: the stretch of X from where its outside first dips
-- under the floor to where its top is under the ground's slab, and how
-- wide its outside is at the floor along it.
local function diveThrough(strand: Tunnel.GravitronStrand, outside: number): { Vector2 }
	-- On the ground its planks already sink into the floor a little.
	local onGround = Tunnel.groundHeight(C :: any) - 0.01
	local stations: { Vector2 } = {}
	for _, piece in strand.approach do
		local steps = math.ceil(Tunnel.length(piece) / 4)
		for i = 0, steps do
			local t = i / steps
			local x, y = Tunnel.pointAt(piece, t)
			local x0, y0 = Tunnel.pointAt(piece, math.max(t - 0.001, 0))
			local x1, y1 = Tunnel.pointAt(piece, math.min(t + 0.001, 1))
			local cosine = math.cos(math.atan(math.abs(y1 - y0) / math.abs(x1 - x0)))
			local reach = outside / cosine
			if y < onGround and y - reach < 0 and y + reach > GROUND_BOTTOM then
				local d = math.abs(y) * cosine
				table.insert(stations, Vector2.new(x, math.sqrt(math.max(outside * outside - d * d, 0))))
			end
		end
	end
	return stations
end

-- Cuts `holes` (world, seen from above) out of every level, square part in
-- `parts` that they overlap, replacing it with the pieces around them.
local function cutGround(parts: { BasePart }, holes: { Railway.Rect })
	for _, part in parts do
		if part.Orientation.Magnitude > 0.01 then
			continue
		end
		local p, s = part.Position, part.Size
		local rect = { x1 = p.X - s.X / 2, x2 = p.X + s.X / 2, z1 = p.Z - s.Z / 2, z2 = p.Z + s.Z / 2 }
		local pieces = Railway.cut(rect, holes)
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

-- A rectangle in the ground space, seen from above in the world.
local function worldRect(ground: CFrame, x1: number, x2: number, z1: number, z2: number): Railway.Rect
	local a = ground:PointToWorldSpace(Vector3.new(x1, 0, z1))
	local b = ground:PointToWorldSpace(Vector3.new(x2, 0, z2))
	return { x1 = math.min(a.X, b.X), x2 = math.max(a.X, b.X), z1 = math.min(a.Z, b.Z), z2 = math.max(a.Z, b.Z) }
end

-- The hole in the ground where a strand's approach dives, as wide as the
-- tube, and new floor between its edges and the tube's outside at the
-- floor. Nil when the approach never goes under.
local function buildDiveHole(parent: Instance, ground: CFrame, strand: Tunnel.GravitronStrand): Railway.Rect?
	local outside = Tube.outsideOf(OPTIONS, OPTIONS.Radius)
	local W = outside + 1
	local stations = diveThrough(strand, outside)
	if #stations < 2 then
		return nil
	end
	local z = strand.mouth.z
	table.sort(stations, function(a: Vector2, b: Vector2): boolean
		return a.X < b.X
	end)
	local function at(x: number, across: number): Vector3
		return ground:PointToWorldSpace(Vector3.new(x, 0, z + across))
	end
	for i = 1, #stations - 1 do
		local a, b = stations[i], stations[i + 1]
		for _, sign in { 1, -1 } do
			triangle(
				parent,
				at(a.X, sign * a.Y),
				at(a.X, sign * W),
				at(b.X, sign * W),
				Vector3.yAxis,
				GROUND_THICKNESS,
				GROUND_COLOR
			)
			triangle(
				parent,
				at(a.X, sign * a.Y),
				at(b.X, sign * W),
				at(b.X, sign * b.Y),
				Vector3.yAxis,
				GROUND_THICKNESS,
				GROUND_COLOR
			)
		end
	end
	return worldRect(ground, stations[1].X, stations[#stations].X, z - W, z + W)
end

-- The park's floor parts in `folder` and TestPark's ground slab tiles under
-- them, for cutting holes in.
local function groundParts(folder: Folder): { BasePart }
	local parts: { BasePart } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Floor" then
			table.insert(parts, child)
		end
	end
	local testPark = workspace:FindFirstChild("TestPark")
	local slab = testPark and testPark:FindFirstChild("Ground")
	if slab then
		for _, tile in slab:GetChildren() do
			if tile:IsA("BasePart") then
				table.insert(parts, tile)
			end
		end
	end
	return parts
end

-- Holes in the ground for the tubes, and the floor closed back round them
-- where they dive (buildDiveHole). Where the twists come up through the
-- ground, inside the skirt, the hole is left open.
local function buildGroundHoles(parent: Instance, folder: Folder, ground: CFrame)
	local outside = Tube.outsideOf(OPTIONS, OPTIONS.Radius)
	local holes: { Railway.Rect } = {}
	for _, strand in GravitronRide.strands do
		local hole = buildDiveHole(parent, ground, strand)
		if hole then
			table.insert(holes, hole)
		end
	end

	-- The twists, inside the skirt: in rows across Z, each as wide as the
	-- twists passing through the ground across it, so the corners stay in.
	local reach = outside + 2
	local crossing: { Vector2 } = {}
	for _, strand in GravitronRide.strands do
		for _, piece in strand.twist do
			local steps = math.ceil(Tunnel.length(piece) / 4)
			for i = 0, steps do
				local bx, by, bz = Tunnel.pointAt(piece, i / steps)
				local x, y, z = Gravitron.fromLocal(GravitronRide.shape, bx, by, bz)
				if by < 0 and y < reach and y > GROUND_BOTTOM - reach then
					table.insert(crossing, Vector2.new(x, z))
				end
			end
		end
	end
	local ROW = 20
	local low, high = math.huge, -math.huge
	for _, p in crossing do
		low, high = math.min(low, p.Y - reach), math.max(high, p.Y + reach)
	end
	local z = low
	while z < high do
		local x1, x2 = math.huge, -math.huge
		for _, p in crossing do
			-- How far across the row a tube round this point reaches.
			local gap = math.max(z - p.Y, p.Y - (z + ROW), 0)
			if gap < reach then
				local across = math.sqrt(reach * reach - gap * gap)
				x1, x2 = math.min(x1, p.X - across), math.max(x2, p.X + across)
			end
		end
		if x1 < x2 then
			local farZ = math.max(math.abs(z), math.abs(z + ROW))
			if math.sqrt(math.max(x1 ^ 2, x2 ^ 2) + farZ ^ 2) > G.Skirt.Radius then
				warn("CorkscrewGravitron: the hole for the twists reaches past the skirt")
			end
			table.insert(holes, worldRect(ground, x1, x2, z, z + ROW))
		end
		z += ROW
	end

	cutGround(groundParts(folder), holes)
end

function CorkscrewGravitron.build(folder: Folder, _area: MapLayout.Area)
	local ground, bowl = GravitronRide.ground, GravitronRide.bowl
	if not ground or not bowl then
		return
	end
	if GravitronRide.warning then
		warn(`CorkscrewGravitron: {GravitronRide.warning}`)
	end
	if G.Heading % 90 ~= 0 then
		warn("CorkscrewGravitron: Heading must be a multiple of 90, or the ground holes come out wrong")
	end
	local model = Instance.new("Model")
	model.Name = "Gravitron"
	model.Parent = folder

	buildBowl(model, bowl)
	buildSkirt(model, ground)
	local outlines: { { Vector3 } } = {}
	for _, strand in GravitronRide.strands do
		local tube = Instance.new("Model")
		tube.Name = "GravitronTube"
		tube.Parent = model
		local respawn = GravitronRide.respawnFor(strand)
		Tube.build(tube, ground, strand.approach, T.SliceAngle, OPTIONS, { finishMouth = false })
		table.insert(
			outlines,
			Tube.build(tube, bowl, strand.twist, T.SliceAngle, OPTIONS, {
				startMouth = false,
				finishMouth = false,
				roll = strand.roll,
				cutAbove = 0,
			})
		)
		buildBoost(tube, bowl, strand, respawn)
		buildFunnel(tube, ground, strand)
	end
	buildFloor(model, bowl, outlines)
	buildGroundHoles(model, folder, ground)
end

-- Shared with the globe's tube (Parks.CorkscrewGlobe), which is built like
-- a strand's.
CorkscrewGravitron.OPTIONS = OPTIONS
CorkscrewGravitron.GROUND_BOTTOM = GROUND_BOTTOM
CorkscrewGravitron.buildBoost = buildBoost
CorkscrewGravitron.buildFunnel = buildFunnel
CorkscrewGravitron.buildDiveHole = buildDiveHole
CorkscrewGravitron.groundParts = groundParts
CorkscrewGravitron.cutGround = cutGround
CorkscrewGravitron.worldRect = worldRect

return CorkscrewGravitron
