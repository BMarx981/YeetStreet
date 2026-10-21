--!strict
-- Tunnel (ModuleScript) -> ReplicatedStorage.Tunnel
-- The middle line of a tunnel, from straights and turns that can climb or
-- drop. A path starts at a point heading one way, and each segment carries
-- on from where the last one ended. Pure, see InputAxes.
--
-- Headings are unit vectors on the ground (x, z). A turn's angle is in
-- degrees, positive to the left, which is counterclockwise seen from above
-- the way CFrame.Angles(0, angle, 0) turns: facing -Z, left is -X. A
-- segment's Rise eases in and out (Tunnel.ease), so the line is level where
-- one segment meets the next and never folds.

local Tunnel = {}

-- A segment in a tunnel's layout: either Straight, studs long, or Turn,
-- degrees, around a circle of Radius studs, climbing Rise studs (negative
-- drops) along the way.
export type Segment = {
	Straight: number?,
	Turn: number?,
	Radius: number?,
	Rise: number?,
}

-- A straight or a turn of the middle line, from where the car enters it to
-- where it leaves, and its height there. A turn is also given as a sweep
-- counterclockwise from above, around its center, starting at `start`:
-- where the car enters a left turn, and where it leaves a right one.
export type Piece = {
	kind: "straight" | "arc",
	fromX: number,
	fromZ: number,
	fromY: number,
	toX: number,
	toZ: number,
	toY: number,
	centerX: number,
	centerZ: number,
	radius: number,
	startX: number,
	startZ: number,
	sweep: number, -- radians
	left: boolean, -- a turn to the left
}

export type Pose = {
	x: number,
	z: number,
	y: number,
	headingX: number,
	headingZ: number,
}

-- (x, z) turned `angle` radians to the left.
local function turned(x: number, z: number, angle: number): (number, number)
	local c, s = math.cos(angle), math.sin(angle)
	return x * c + z * s, -x * s + z * c
end

-- How far through a climb the line has risen at `t` of the way along it:
-- level at both ends.
function Tunnel.ease(t: number): number
	return t * t * (3 - 2 * t)
end

function Tunnel.path(
	x: number,
	z: number,
	headingX: number,
	headingZ: number,
	segments: { Segment },
	height: number?
): ({ Piece }, Pose)
	local y = height or 0
	local pieces: { Piece } = {}
	for _, segment in segments do
		local toY = y + (segment.Rise or 0)
		if segment.Straight then
			local length = segment.Straight
			local toX, toZ = x + headingX * length, z + headingZ * length
			table.insert(pieces, {
				kind = "straight",
				fromX = x,
				fromZ = z,
				fromY = y,
				toX = toX,
				toZ = toZ,
				toY = toY,
				centerX = 0,
				centerZ = 0,
				radius = 0,
				startX = x,
				startZ = z,
				sweep = 0,
				left = false,
			})
			x, z = toX, toZ
		else
			local angle = math.rad(segment.Turn or 0)
			local radius = segment.Radius or 0
			local side = if angle > 0 then 1 else -1
			-- To the left is the heading turned a quarter left.
			local leftX, leftZ = headingZ, -headingX
			local centerX, centerZ = x + leftX * side * radius, z + leftZ * side * radius
			local outX, outZ = turned(x - centerX, z - centerZ, angle)
			local toX, toZ = centerX + outX, centerZ + outZ
			table.insert(pieces, {
				kind = "arc",
				fromX = x,
				fromZ = z,
				fromY = y,
				toX = toX,
				toZ = toZ,
				toY = toY,
				centerX = centerX,
				centerZ = centerZ,
				radius = radius,
				startX = if angle > 0 then x else toX,
				startZ = if angle > 0 then z else toZ,
				sweep = math.abs(angle),
				left = angle > 0,
			})
			x, z = toX, toZ
			headingX, headingZ = turned(headingX, headingZ, angle)
		end
		y = toY
	end
	return pieces, { x = x, z = z, y = y, headingX = headingX, headingZ = headingZ }
end

-- The point `t` of the way along a piece, the way the car goes: x, y, z.
function Tunnel.pointAt(piece: Piece, t: number): (number, number, number)
	local y = piece.fromY + (piece.toY - piece.fromY) * Tunnel.ease(t)
	if piece.kind == "straight" then
		return piece.fromX + (piece.toX - piece.fromX) * t, y, piece.fromZ + (piece.toZ - piece.fromZ) * t
	end
	local outX, outZ = turned(
		piece.fromX - piece.centerX,
		piece.fromZ - piece.centerZ,
		piece.sweep * t * (if piece.left then 1 else -1)
	)
	return piece.centerX + outX, y, piece.centerZ + outZ
end

-- How long a piece's middle line is, seen from above.
function Tunnel.length(piece: Piece): number
	if piece.kind == "straight" then
		return math.sqrt((piece.toX - piece.fromX) ^ 2 + (piece.toZ - piece.fromZ) ^ 2)
	end
	return piece.radius * piece.sweep
end

-- The dense city's tunnels (Tuning.City), in park coordinates: studs from
-- the park's center, heights from the floor. The server builds them from
-- this layout (Parks.City) and each driver's client finds the one its car is
-- in.
--
-- Tunnels run in chains of two buildings, each Columns by Rows lots, side by
-- side across the alley between them on Side of the avenue (1 is +X; -1 is
-- the mirror image), against the Street at the Top or Bottom of their block.
-- A chain's middle line starts on the ground Offset in from that street, on
-- the first building's side facing the avenue, runs the Climb segments, then
-- goes straight across the alley at whatever height it has climbed to, so
-- traffic in the alley can drive under it. In the second building it runs
-- the Drop segments, then goes straight out of whichever side it is heading
-- for, back on the ground.

-- How far a tube's bottom plank sits above the floor, so the two never
-- flicker.
Tunnel.LIFT = 0.05

export type Place = {
	Side: number,
	Block: number,
	Street: string, -- "Top" or "Bottom"
}

export type Tunnels = {
	Radius: number,
	Sides: number,
	Columns: number,
	Rows: number,
	Offset: number,
	Climb: { Segment },
	Drop: { Segment },
	Places: { Place },
}

-- The parts of Tuning.City the layout needs.
export type City = {
	Avenue: { Width: number },
	Streets: { Width: number, Z: { number } },
	Buildings: { TopZ: number, Setback: number, Lot: number, Alley: number },
	Tunnels: Tunnels,
}

-- A footprint seen from above.
export type Rect = { x1: number, x2: number, z1: number, z2: number }

-- Where a chain's middle line goes through a building's side, on the floor.
export type Crossing = { x: number, z: number }

export type Chain = {
	place: Place,
	rects: { Rect }, -- the first building, then the second
	pieces: { Piece },
	entry: Crossing, -- on the ground, the first building's side facing the avenue
	exit: Crossing, -- on the ground, a side of the second building
	alley: { Crossing }, -- up high, the first building's side, then the second's
	alleyHeight: number,
	warning: string?, -- set when the layout does not fit its buildings
}

export type Block = { top: number, bottom: number }

-- The blocks of buildings between the cross streets, from TopZ down, each
-- from its top edge to its bottom edge.
function Tunnel.blocks(city: City): { Block }
	local blocks: { Block } = {}
	local half = city.Streets.Width / 2
	local top = city.Buildings.TopZ
	for _, z in city.Streets.Z do
		if top > z + half then
			table.insert(blocks, { top = top, bottom = z + half })
		end
		top = z - half
	end
	return blocks
end

-- Height of a tube's middle line on the ground: its bottom plank, flat
-- across, lies just above the floor.
function Tunnel.groundHeight(tunnels: Tunnels): number
	return tunnels.Radius * math.cos(math.pi / tunnels.Sides) + Tunnel.LIFT
end

-- How far from `pose` straight ahead to the side of `rect` it is heading
-- for, or nil when it is not heading square at one.
local function toSide(pose: Pose, rect: Rect): number?
	if math.abs(pose.headingZ) > 0.99 then
		return ((if pose.headingZ > 0 then rect.z2 else rect.z1) - pose.z) / pose.headingZ
	elseif math.abs(pose.headingX) > 0.99 then
		return ((if pose.headingX > 0 then rect.x2 else rect.x1) - pose.x) / pose.headingX
	end
	return nil
end

local function layoutChain(city: City, place: Place, block: Block): Chain
	local B, T = city.Buildings, city.Tunnels
	local side = place.Side
	-- Turns are mirrored on the -X side and against the bottom street.
	local flip = if place.Street == "Bottom" then -1 else 1
	local width = T.Columns * B.Lot + (T.Columns - 1) * B.Alley
	local depth = T.Rows * B.Lot + (T.Rows - 1) * B.Alley
	-- The block's lots, top to bottom, each Lot deep with an Alley between.
	local lotsTop = block.top - B.Setback
	local rows = math.floor((lotsTop - (block.bottom + B.Setback) + B.Alley) / (B.Lot + B.Alley))
	local lotsBottom = lotsTop - rows * B.Lot - (rows - 1) * B.Alley
	local z1 = if flip > 0 then lotsTop - depth else lotsBottom
	local street = if flip > 0 then lotsTop else lotsBottom

	local firstEdge = city.Avenue.Width / 2 + B.Setback
	local secondEdge = firstEdge + width + B.Alley
	local function rect(edge: number): Rect
		return {
			x1 = if side > 0 then edge else -edge - width,
			x2 = if side > 0 then edge + width else -edge,
			z1 = z1,
			z2 = z1 + depth,
		}
	end
	local first, second = rect(firstEdge), rect(secondEdge)

	local warning: string? = nil
	local function mirrored(list: { Segment }, into: { Segment })
		for _, segment in list do
			table.insert(into, {
				Straight = segment.Straight,
				Turn = if segment.Turn then segment.Turn * side * flip else nil,
				Radius = segment.Radius,
				Rise = segment.Rise,
			})
		end
	end

	local ground = Tunnel.groundHeight(T)
	local x, z = side * firstEdge, street - flip * T.Offset
	local segments: { Segment } = {}
	mirrored(T.Climb, segments)
	local _, climbed = Tunnel.path(x, z, side, 0, segments, ground)
	if climbed.headingX * side < 0.99 then
		warning = "a chain's Climb does not end heading for the alley"
	end
	-- Straight on through the first building's side, across the alley, and
	-- into the second building.
	local across = (side * secondEdge - climbed.x) * side
	table.insert(segments, { Straight = math.max(across, 0) })
	mirrored(T.Drop, segments)
	local _, dropped = Tunnel.path(x, z, side, 0, segments, ground)
	local out = toSide(dropped, second)
	if not out then
		warning = "a chain's Drop does not end heading square at a side of its building"
	end
	table.insert(segments, { Straight = math.max(out or 0, 0) })
	local pieces, finish = Tunnel.path(x, z, side, 0, segments, ground)
	if math.abs(finish.y - ground) > 0.01 then
		warning = "a chain's Climb and Drop do not bring it back to the ground"
	end

	return {
		place = place,
		rects = { first, second },
		pieces = pieces,
		entry = { x = x, z = z },
		exit = { x = finish.x, z = finish.z },
		alley = {
			{ x = side * (firstEdge + width), z = climbed.z },
			{ x = side * secondEdge, z = climbed.z },
		},
		alleyHeight = climbed.y,
		warning = warning,
	}
end

-- Every chain in Tunnels.Places whose block exists.
function Tunnel.layout(city: City): { Chain }
	local blocks = Tunnel.blocks(city)
	local chains: { Chain } = {}
	for _, place in city.Tunnels.Places do
		local block = blocks[place.Block]
		if block then
			table.insert(chains, layoutChain(city, place, block))
		end
	end
	return chains
end

-- Spiral towers (Tuning.City.Spirals): a building Columns by Rows lots from
-- lot Column of its Block on Side of the avenue, against the Street at the
-- Top or Bottom of the block. A tube comes in on the ground from that
-- street, Radius out from the building's middle, runs Inset in, and
-- climbs Loops and a half round the middle, Pitch up each loop, coming
-- out heading back toward the street on the other side. Then it climbs up
-- through the roof at the hatch, levels out on the roof, and ends after
-- LevelRun, KickRoom in from the roof's street edge. Outside is from the
-- tube's middle line to its outside; the roof is RoofThickness thick, just
-- over the top loop.
export type SpiralPlace = {
	Side: number,
	Block: number,
	Column: number,
	Street: string, -- "Top" or "Bottom"
}

export type Spirals = {
	Radius: number,
	Pitch: number,
	Loops: number,
	Inset: number,
	KickRoom: number,
	LevelRun: number,
	Outside: number,
	RoofThickness: number,
	Columns: number,
	Rows: number,
	Places: { SpiralPlace },
}

export type Spiral = {
	place: SpiralPlace,
	rect: Rect,
	pieces: { Piece },
	entry: Crossing, -- on the ground, the building's street side
	roof: number, -- the roof's top, from the floor
	hatch: Rect, -- where the tube comes up through the roof
	exit: Crossing, -- where the tube leaves the hatch, level on the roof
	mouth: Crossing, -- the tube's end on the roof
	outX: number, -- the way from the mouth toward the street
	outZ: number,
	warning: string?,
}

local function layoutSpiral(city: City, spirals: Spirals, place: SpiralPlace, block: Block): Spiral
	local B = city.Buildings
	local side = place.Side
	local inward = if place.Street == "Bottom" then 1 else -1
	local width = spirals.Columns * B.Lot + (spirals.Columns - 1) * B.Alley
	local depth = spirals.Rows * B.Lot + (spirals.Rows - 1) * B.Alley
	local lotsTop = block.top - B.Setback
	local rows = math.floor((lotsTop - (block.bottom + B.Setback) + B.Alley) / (B.Lot + B.Alley))
	local lotsBottom = lotsTop - rows * B.Lot - (rows - 1) * B.Alley
	local z1 = if inward > 0 then lotsBottom else lotsTop - depth
	local wall = if inward > 0 then z1 else z1 + depth
	local edge = city.Avenue.Width / 2 + B.Setback + (place.Column - 1) * (B.Lot + B.Alley)
	local rect = {
		x1 = if side > 0 then edge else -edge - width,
		x2 = if side > 0 then edge + width else -edge,
		z1 = z1,
		z2 = z1 + depth,
	}
	local middle = (rect.x1 + rect.x2) / 2
	local R = spirals.Radius

	-- In on the outer side of the middle, round the middle so the center is
	-- Radius back toward it, and out on the inner side.
	local turn = -side * inward
	local segments: { Segment } = { { Straight = spirals.Inset } }
	for _ = 1, spirals.Loops do
		table.insert(segments, { Turn = turn * 360, Radius = R, Rise = spirals.Pitch })
	end
	table.insert(segments, { Turn = turn * 180, Radius = R, Rise = spirals.Pitch / 2 })
	local ground = Tunnel.groundHeight(city.Tunnels)
	local top = ground + (spirals.Loops + 0.5) * spirals.Pitch
	local roof = top + spirals.Outside + spirals.RoofThickness
	local climb = spirals.Inset - spirals.KickRoom - spirals.LevelRun
	table.insert(segments, { Straight = climb, Rise = roof + ground - top })
	table.insert(segments, { Straight = spirals.LevelRun })
	local x = middle + side * R
	local pieces = Tunnel.path(x, wall, 0, inward, segments, ground)

	local warning: string? = nil
	if climb <= 0 then
		warning = "a spiral's Inset leaves no room to climb through the roof"
	elseif spirals.Pitch < 2 * spirals.Outside then
		warning = "a spiral's Pitch lets its loops meet"
	elseif R + spirals.Outside > width / 2 or spirals.Inset + R + spirals.Outside > depth then
		warning = "a spiral does not fit its building"
	end

	local outX = middle - side * R
	local hatchNear = wall + inward * (spirals.KickRoom + spirals.LevelRun)
	local hatchFar = wall + inward * spirals.Inset
	return {
		place = place,
		rect = rect,
		pieces = pieces,
		entry = { x = x, z = wall },
		roof = roof,
		hatch = {
			x1 = outX - spirals.Outside,
			x2 = outX + spirals.Outside,
			z1 = math.min(hatchNear, hatchFar),
			z2 = math.max(hatchNear, hatchFar),
		},
		exit = { x = outX, z = hatchNear },
		mouth = { x = outX, z = wall + inward * spirals.KickRoom },
		outX = 0,
		outZ = -inward,
		warning = warning,
	}
end

-- Every spiral tower in Spirals.Places whose block exists.
function Tunnel.spirals(city: City, spirals: Spirals): { Spiral }
	local blocks = Tunnel.blocks(city)
	local list: { Spiral } = {}
	for _, place in spirals.Places do
		local block = blocks[place.Block]
		if block then
			table.insert(list, layoutSpiral(city, spirals, place, block))
		end
	end
	return list
end

-- The way a tube of `radius` around the middle line `pieces` pulls a car at
-- (x, y, z): straight out from the nearest point on the middle line through
-- the car, toward the nearest wall, as a unit vector. Nil outside the tube,
-- past either end or beyond its wall. On the middle line itself, straight
-- down.
function Tunnel.pull(pieces: { Piece }, radius: number, x: number, y: number, z: number): (number?, number?, number?)
	for _, piece in pieces do
		-- How far along the piece the car is alongside it: once on a
		-- straight, and once each time round a turn that loops.
		local alongside: { number } = {}
		if piece.kind == "straight" then
			local dx, dz = piece.toX - piece.fromX, piece.toZ - piece.fromZ
			local length2 = dx * dx + dz * dz
			local along = ((x - piece.fromX) * dx + (z - piece.fromZ) * dz) / length2
			if along >= 0 and along <= 1 then
				table.insert(alongside, along)
			end
		else
			local ux, uz = piece.startX - piece.centerX, piece.startZ - piece.centerZ
			local wx, wz = x - piece.centerX, z - piece.centerZ
			-- Radians around from the start, the way a left turn goes.
			local around = math.atan2(wx * uz - wz * ux, wx * ux + wz * uz)
			if around < 0 then
				around += 2 * math.pi
			end
			if (wx * wx + wz * wz) > 1e-9 then
				while around <= piece.sweep do
					table.insert(alongside, if piece.left then around / piece.sweep else 1 - around / piece.sweep)
					around += 2 * math.pi
				end
			end
		end
		for _, t in alongside do
			local ax, ay, az = Tunnel.pointAt(piece, t)
			local px, py, pz = x - ax, y - ay, z - az
			local distance = math.sqrt(px * px + py * py + pz * pz)
			if distance <= radius then
				if distance < 1e-9 then
					return 0, -1, 0
				end
				return px / distance, py / distance, pz / distance
			end
		end
	end
	return nil, nil, nil
end

return Tunnel
