--!strict
-- Tube (ModuleScript) -> ServerScriptService.Pieces.Tube
-- A round tube along a middle line from Tunnel.path: a ring of Sides planks
-- all the way round every `sliceAngle` degrees of its turns and StepLength
-- of its climbs, so a car can drive up its walls and along its roof, and
-- climb (CarController pulls a car toward the wall inside one). Over
-- FlareLength at each end the tube opens out into a mouth with a wide flat
-- floor and curves up each side, like the corkscrew's middle ramp, so a car
-- can drive in off center or at an angle; each end's floor is a ground
-- height below its middle line. Dim lights hang along the roof. Used by
-- Downtown's tunnel chains and spiral towers, and Dino Valley's volcano.
-- Tube.holePlate closes a wall round where a tube goes through it.
--
-- The middle line's points are in the space of `base`: a park's floor at
-- its middle, say. Rings stand square to base's ground, so a tilted base
-- tilts them. A mouth assumes base only turns about Y, so up stays up.
--
-- Ends can leave off either end's mouth, roll the rings round the middle
-- line, and cut the tube off at a height in base's space, as where it comes
-- up through a floor: planks over it are left out, and planks across it are
-- cut off at it (or, for planks facing up, low enough that their outside
-- stays under it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CurveProfile = require(ReplicatedStorage.CurveProfile)
local Tunnel = require(ReplicatedStorage.Tunnel)
local Triangle = require(ServerScriptService.Pieces.Triangle)

local Tube = {}

-- The tube's shape, as in Tuning.City.Tunnels.
export type Options = {
	Radius: number, -- from the middle line to the planks
	Sides: number, -- planks around the ring
	MouthFloor: number,
	MouthCurve: number,
	FlareLength: number,
	FlareRows: number,
	StepLength: number,
	LightEvery: number,
	LightBrightness: number,
	LightRange: number,
}

export type Ends = {
	startMouth: boolean?, -- false leaves off the mouth at the first piece's start
	finishMouth: boolean?, -- and the last piece's end
	roll: number?, -- radians round the middle line, the way from `up` to `side`
	cutAbove: number?, -- nothing over this height in base's space
	-- How far into something else a point is, as where two tubes fork, so
	-- planks are cut back to where it is 0 and left out past it.
	trim: ((Vector3) -> number)?,
}

-- Where the planks were cut off, for building a floor round the hole.
type Cut = {
	base: CFrame,
	above: number,
	points: { Vector3 },
}

local THICKNESS = 2
local LIGHT_COLOR = Color3.fromRGB(255, 214, 160)
local TUBE_COLOR = Color3.fromRGB(150, 156, 166)
-- Planks are this much wider than their chord so the seams stay closed.
local OVERLAP = 0.4

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

-- What is left of the polygon `corners` where `over` is at most 0, `over`
-- taken as running straight between corners, and where its edges cross 0.
local function clip(corners: { Vector3 }, over: (Vector3) -> number): ({ Vector3 }, { Vector3 })
	local kept: { Vector3 } = {}
	local ends: { Vector3 } = {}
	for i, a in corners do
		local b = corners[i % #corners + 1]
		local oa, ob = over(a), over(b)
		if oa <= 0 then
			table.insert(kept, a)
		end
		if (oa <= 0) ~= (ob <= 0) then
			local p = a:Lerp(b, oa / (oa - ob))
			table.insert(kept, p)
			table.insert(ends, p)
		end
	end
	return kept, ends
end

-- The polygon `kept`, the inside face of a plank facing `out`'s opposite,
-- as triangles.
local function fan(parent: Instance, kept: { Vector3 }, out: Vector3)
	for i = 2, #kept - 1 do
		if (kept[i] - kept[1]):Cross(kept[i + 1] - kept[1]).Magnitude > 0.01 then
			for _, wedge in Triangle.make(parent, kept[1], kept[i], kept[i + 1], -out, THICKNESS, TUBE_COLOR) do
				wedge.Name = "Plank"
			end
		end
	end
end

-- The plank whose inside face is the rectangle `corners`, facing `out`'s
-- opposite, cut off where `cut` says: as triangles from what is left under
-- the cut. The cut's ends on the outside go in cut.points.
local function cutPlank(parent: Instance, corners: { Vector3 }, out: Vector3, cut: Cut)
	-- A plank facing up is cut lower, so its outside stays under the cut.
	local rise = cut.base:VectorToObjectSpace(out).Y
	local level = cut.above - THICKNESS * math.max(rise, 0)
	local kept, ends = clip(corners, function(p: Vector3): number
		return cut.base:PointToObjectSpace(p).Y - level
	end)
	if #kept < 3 then
		return
	end
	fan(parent, kept, out)
	for _, p in ends do
		table.insert(cut.points, if rise > 0 then p + out * THICKNESS else p)
	end
end

-- One ring of Sides planks around a middle line at `middle`, its cross
-- section square to the line: `side` level across it and `up` square to
-- both. The curves are `radius` around, pulled `flat` apart either side into
-- a flat floor and roof. Each plank is `lengthAt` long, given where its
-- middle is from the middle line. With a `cut`, planks are cut off at it;
-- with a `trim`, cut back to where it is 0 (Ends.trim).
local function ring(
	parent: Instance,
	options: Options,
	middle: Vector3,
	side: Vector3,
	up: Vector3,
	flat: number,
	radius: number,
	lengthAt: (Vector3) -> number,
	cut: Cut?,
	trim: ((Vector3) -> number)?
)
	local halfStep = math.pi / options.Sides
	local face = radius * math.cos(halfStep)
	local chord = 2 * radius * math.sin(halfStep)
	for k = 0, options.Sides - 1 do
		local angle = 2 * halfStep * k -- from the bottom, round toward `side`
		local s = math.sin(angle)
		local out = -up * math.cos(angle) + side * s
		local around = side * math.cos(angle) + up * s
		-- The floor and roof planks span the flat; the rest move out to it.
		local level = math.abs(s) < 1e-6
		local width = chord + OVERLAP + (if level then 2 * flat else 0)
		local shift = if level then 0 else flat * math.sign(s)
		local length = lengthAt(side * shift + out * face)
		local cframe = CFrame.fromMatrix(middle + side * shift + out * (face + THICKNESS / 2), around, -out)
		if cut or trim then
			local inside = cframe.Position - out * (THICKNESS / 2)
			local a, z = around * (width / 2), cframe.ZVector * (length / 2)
			local corners = { inside + a + z, inside - a + z, inside - a - z, inside + a - z }
			if cut then
				local highest = -math.huge
				for _, p in corners do
					local inner = cut.base:PointToObjectSpace(p).Y
					highest = math.max(highest, inner, cut.base:PointToObjectSpace(p + out * THICKNESS).Y)
				end
				if highest > cut.above then
					cutPlank(parent, corners, out, cut)
					continue
				end
			end
			if trim then
				local over = 0
				for _, p in corners do
					if trim(p) > 0 then
						over += 1
					end
				end
				if over == #corners then
					continue
				elseif over > 0 then
					local kept = clip(corners, trim)
					if #kept >= 3 then
						fan(parent, kept, out)
					end
					continue
				end
			end
		end
		block(parent, "Plank", Vector3.new(width, THICKNESS, length), cframe, TUBE_COLOR)
	end
end

-- A dim light on a tunnel's roof.
local function light(parent: Instance, options: Options, cframe: CFrame)
	local fixture = block(parent, "Light", Vector3.new(6, 0.3, 2), cframe, LIGHT_COLOR)
	fixture.Material = Enum.Material.SmoothPlastic
	fixture.CanCollide = false
	fixture.CanQuery = false
	fixture.CanTouch = false
	local glow = Instance.new("PointLight")
	glow.Brightness = options.LightBrightness
	glow.Range = options.LightRange
	glow.Color = LIGHT_COLOR
	glow.Parent = fixture
end

-- A ring's outside corners are this far out from its curves' middles, for
-- curves `radius` around.
function Tube.outsideOf(options: Options, radius: number): number
	local halfStep = math.pi / options.Sides
	return (radius * math.cos(halfStep) + THICKNESS) / math.cos(halfStep)
end

-- A hole in a building's side for a tube: on the ground, a mouth with a flat
-- floor and roof `flat` either side of its middle and curves beyond; up
-- high, the round tube crossing the alley. `point` is on the floor below
-- its middle, which is `middleY` up, and its outline's corners are
-- `outside` out from its curves' middles.
export type Hole = {
	point: Vector3,
	ground: boolean,
	middleY: number,
	flat: number,
	outside: number,
}

-- The building's side around a hole facing `out`: the corners between the
-- hole's outline and the square cut for it, a sill below it when it is up
-- high, and a lintel above it up to `towerBottom`.
function Tube.holePlate(
	parent: Instance,
	options: Options,
	hole: Hole,
	out: Vector3,
	towerBottom: number,
	color: Color3,
	material: Enum.Material
)
	local halfStep = math.pi / options.Sides
	local across = Vector3.new(out.Z, 0, -out.X)
	local function point(t: number, y: number): Vector3
		return hole.point + across * t + Vector3.new(0, hole.middleY + y, 0)
	end
	local function triangle(a: Vector3, b: Vector3, c: Vector3)
		if (b - a):Cross(c - a).Magnitude < 0.01 then
			return
		end
		for _, wedge in Triangle.make(parent, a, b, c, out, THICKNESS, color) do
			wedge.Material = material
		end
	end
	local outside, half = hole.outside, hole.flat + hole.outside
	-- Corner k of the outline, from the bottom round toward +across.
	local sides = options.Sides
	local function corner(k: number): Vector3
		local angle = (2 * k + 1) * halfStep
		local s = math.sin(angle)
		return point(outside * s + hole.flat * math.sign(s), -outside * math.cos(angle))
	end
	-- Each side's lower and upper quarter of the outline, fanned from the
	-- square's corner beside it, and between them out to the square's edge.
	local quarter = sides // 4
	for _, sign in { 1, -1 } do
		local function edge(k: number): Vector3
			return if sign > 0 then corner(k) else corner(sides - 1 - k)
		end
		local low = point(sign * half, -outside)
		local level = point(sign * half, 0)
		local high = point(sign * half, outside)
		for k = 0, quarter - 2 do
			triangle(low, edge(k), edge(k + 1))
		end
		triangle(low, edge(quarter - 1), level)
		triangle(edge(quarter - 1), edge(quarter), level)
		triangle(high, level, edge(quarter))
		for k = quarter, 2 * quarter - 2 do
			triangle(high, edge(k), edge(k + 1))
		end
	end
	local function wall(bottom: number, top: number)
		if top - bottom > 0.05 then
			local middle = hole.point - out + Vector3.new(0, (bottom + top) / 2, 0)
			block(
				parent,
				"Wall",
				Vector3.new(2 * half, top - bottom, THICKNESS),
				CFrame.lookAt(middle, middle + out),
				color
			).Material =
				material
		end
	end
	local edgeHeight = outside * math.cos(halfStep)
	wall(0, hole.middleY - edgeHeight)
	wall(hole.middleY + edgeHeight, towerBottom)
end

-- Builds the tube along `pieces` into `model`. With ends.cutAbove, returns
-- where the planks were cut off on the outside, round the hole.
function Tube.build(
	model: Instance,
	base: CFrame,
	pieces: { Tunnel.Piece },
	sliceAngle: number,
	options: Options,
	ends: Ends?
): { Vector3 }
	local T = options
	local startMouth = not ends or ends.startMouth ~= false
	local finishMouth = not ends or ends.finishMouth ~= false
	local roll = ends and ends.roll or 0
	local cutAbove = ends and ends.cutAbove
	local trim = ends and ends.trim
	local cut: Cut? = if cutAbove then { base = base, above = cutAbove, points = {} } else nil
	local halfStep = math.pi / T.Sides
	local face = T.Radius * math.cos(halfStep) -- from the middle line to each plank's inside face
	local ground = T.Radius * math.cos(halfStep) + Tunnel.LIFT
	local mouthFlat = T.MouthFloor / 2

	local function pointAt(piece: Tunnel.Piece, t: number): Vector3
		local x, y, z = Tunnel.pointAt(piece, math.clamp(t, 0, 1))
		return base:PointToWorldSpace(Vector3.new(x, y, z))
	end
	-- The way the middle line runs at `t` along a piece.
	local function tangentAt(piece: Tunnel.Piece, t: number): Vector3
		return (pointAt(piece, t + 0.001) - pointAt(piece, t - 0.001)).Unit
	end
	-- How steeply `along` climbs in base's space.
	local function rise(along: Vector3): number
		return base:VectorToObjectSpace(along).Y
	end
	-- A ring's `side`, level across the line in base's space, and its `up`,
	-- rolled by `roll`.
	local function frameAt(along: Vector3): (Vector3, Vector3)
		local flat = base:VectorToObjectSpace(along)
		local side = base:VectorToWorldSpace(Vector3.new(-flat.Z, 0, flat.X).Unit)
		local up = side:Cross(along)
		local c, s = math.cos(roll), math.sin(roll)
		return side * c + up * s, up * c - side * s
	end

	-- The opening from a mouth on the floor at `mouth` in along `inward` to
	-- where it meets the tube, in FlareRows rows of triangles between rings
	-- of the planks' inside corners. Each ring is the tube's, pulled apart
	-- across the middle into a flat floor and roof, its curves eased from
	-- MouthCurve around to Radius and its floor from MouthFloor wide to
	-- nothing, so it meets the tube without a fold.
	local function flare(mouth: Vector3, inward: Vector3)
		local side = Vector3.new(-inward.Z, 0, inward.X)
		local function corners(row: number): ({ Vector3 }, Vector3)
			local ease = Tunnel.ease(1 - row / T.FlareRows)
			local radius = T.Radius + (T.MouthCurve - T.Radius) * ease
			local flat = mouthFlat * ease
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
				for _, wedge in Triangle.make(model, back[k], back[n], front[n], inside, THICKNESS, TUBE_COLOR) do
					wedge.Name = "Plank"
				end
				for _, wedge in Triangle.make(model, back[k], front[n], front[k], inside, THICKNESS, TUBE_COLOR) do
					wedge.Name = "Plank"
				end
			end
			back, backMiddle = front, frontMiddle
		end
	end

	local total = 0
	for _, piece in pieces do
		total += Tunnel.length(piece)
	end
	if
		(startMouth and Tunnel.length(pieces[1]) < T.FlareLength)
		or (finishMouth and Tunnel.length(pieces[#pieces]) < T.FlareLength)
	then
		warn("Tube: a tube needs a level straight at least FlareLength long at each end with a mouth")
	end
	-- Lights every LightEvery of the middle line, but not in the mouths.
	local travelled = 0

	for index, piece in pieces do
		local length = Tunnel.length(piece)
		local climbs = math.abs(piece.toY - piece.fromY) > 0.01
		-- The part of this piece the rings cover: all of it, but the mouths'
		-- openings at either end of the chain.
		local start = if index == 1 and startMouth then T.FlareLength / length else 0
		local finish = if index == #pieces and finishMouth then 1 - T.FlareLength / length else 1
		local steps = if piece.kind == "arc"
			then math.ceil(math.deg(piece.sweep) / sliceAngle)
			elseif climbs then math.ceil(length / T.StepLength)
			else 1
		local slice = math.deg(piece.sweep) / steps
		local center = Vector3.new(piece.centerX, 0, piece.centerZ)
		for i = 1, steps do
			local t0 = start + (finish - start) * (i - 1) / steps
			local t1 = start + (finish - start) * i / steps
			local middle = pointAt(piece, (t0 + t1) / 2)
			local along = tangentAt(piece, (t0 + t1) / 2)
			local side, up = frameAt(along)
			-- Planks are this much longer where the line bends up or down
			-- between rings, so the seams stay closed.
			local bend = face * math.abs(math.asin(rise(tangentAt(piece, t1))) - math.asin(rise(tangentAt(piece, t0))))
			local lengthAt: (Vector3) -> number
			if piece.kind == "arc" then
				local spot = base:PointToObjectSpace(middle)
				local outward = base:VectorToWorldSpace(Vector3.new(spot.X - center.X, 0, spot.Z - center.Z).Unit)
				local level = math.sqrt(1 - rise(along) ^ 2)
				lengthAt = function(offset: Vector3): number
					return CurveProfile.sliceLength(piece.radius + offset:Dot(outward), slice) / level + bend
				end
			else
				local stretch = (pointAt(piece, t1) - pointAt(piece, t0)).Magnitude + bend
				lengthAt = function(_: Vector3): number
					return stretch
				end
			end
			ring(model, T, middle, side, up, 0, T.Radius, lengthAt, cut, trim)
		end
		if index == 1 and startMouth then
			flare(pointAt(piece, 0) - Vector3.new(0, ground, 0), tangentAt(piece, 0))
		end
		if index == #pieces and finishMouth then
			flare(pointAt(piece, 1) - Vector3.new(0, ground, 0), -tangentAt(piece, 1))
		end

		local d = (T.LightEvery / 2 - travelled) % T.LightEvery
		while d <= length do
			local reached = travelled + d
			local clearStart = not startMouth or reached > T.FlareLength
			local clearFinish = not finishMouth or reached < total - T.FlareLength
			if clearStart and clearFinish then
				local t = d / length
				local along = tangentAt(piece, t)
				local flat = base:VectorToObjectSpace(along)
				local up = base:VectorToWorldSpace(Vector3.new(-flat.Z, 0, flat.X).Unit):Cross(along)
				local spot = pointAt(piece, t) + up * (face - 0.1)
				if not cutAbove or base:PointToObjectSpace(spot).Y < cutAbove - 2 * T.Radius then
					light(model, T, CFrame.lookAt(spot, spot + along, up))
				end
			end
			d += T.LightEvery
		end
		travelled += length
	end
	return if cut then cut.points else {}
end

return Tube
