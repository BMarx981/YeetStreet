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
-- one segment meets the next and never folds. A segment with an Ease climbs
-- evenly instead, but over that share of it at each end (Tunnel.easeEnds).

local Tunnel = {}

-- A segment in a tunnel's layout: either Straight, studs long, or Turn,
-- degrees, around a circle of Radius studs, climbing Rise studs (negative
-- drops) along the way.
export type Segment = {
	Straight: number?,
	Turn: number?,
	Radius: number?,
	Rise: number?,
	Ease: number?,
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
	ease: number?, -- the segment's Ease
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

-- How far through a climb the line has risen at `t` of the way along it,
-- climbing evenly but for `share` of the way at each end, where it eases in
-- from level and out to level.
function Tunnel.easeEnds(t: number, share: number): number
	local e = math.clamp(share, 0, 0.5)
	if e <= 0 then
		return t
	end
	local area = 1 - e
	if t < e then
		return t * t / (2 * e) / area
	elseif t <= 1 - e then
		return (t - e / 2) / area
	end
	local u = 1 - t
	return 1 - u * u / (2 * e) / area
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
				ease = segment.Ease,
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
				ease = segment.Ease,
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
	local climbed = if piece.ease then Tunnel.easeEnds(t, piece.ease) else Tunnel.ease(t)
	local y = piece.fromY + (piece.toY - piece.fromY) * climbed
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
-- climbs Loops round the middle, Pitch up each loop. The last half loop
-- climbs on up through the roof at the hatch, gently, and comes out level
-- on the roof heading back toward the street on the other side, and the
-- tube ends LevelRun on. Outside is from the tube's middle line to its
-- outside; the roof is RoofThickness thick, just over the last whole loop.
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
	runway: number, -- from the mouth to the roof's street edge
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
	-- Radius back toward it, and out on the inner side, level on the roof.
	local turn = -side * inward
	local segments: { Segment } = { { Straight = spirals.Inset } }
	for _ = 1, spirals.Loops do
		table.insert(segments, { Turn = turn * 360, Radius = R, Rise = spirals.Pitch })
	end
	local ground = Tunnel.groundHeight(city.Tunnels)
	local top = ground + spirals.Loops * spirals.Pitch
	local roof = top + spirals.Outside + spirals.RoofThickness
	table.insert(segments, { Turn = turn * 180, Radius = R, Rise = roof + ground - top })
	table.insert(segments, { Straight = spirals.LevelRun })
	local runway = spirals.Inset - spirals.LevelRun
	local x = middle + side * R
	local pieces = Tunnel.path(x, wall, 0, inward, segments, ground)

	local warning: string? = nil
	if runway <= 0 then
		warning = "a spiral's LevelRun runs off the roof"
	elseif spirals.Pitch < 2 * spirals.Outside then
		warning = "a spiral's Pitch lets its loops meet"
	elseif R + spirals.Outside > width / 2 or spirals.Inset + R + spirals.Outside > depth then
		warning = "a spiral does not fit its building"
	end

	-- The hatch takes in the whole last half loop, on the far side of the
	-- middle from the street.
	local outX = middle - side * R
	local hatchNear = wall + inward * spirals.Inset
	local hatchFar = wall + inward * (spirals.Inset + R + spirals.Outside)
	return {
		place = place,
		rect = rect,
		pieces = pieces,
		entry = { x = x, z = wall },
		roof = roof,
		hatch = {
			x1 = middle - R - spirals.Outside,
			x2 = middle + R + spirals.Outside,
			z1 = math.min(hatchNear, hatchFar),
			z2 = math.max(hatchNear, hatchFar),
		},
		exit = { x = outX, z = hatchNear },
		mouth = { x = outX, z = wall + inward * runway },
		runway = runway,
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

-- Dino Valley's volcano tube (Tuning.Dino.Volcano.Climb), in the volcano's
-- own space: from its middle on the ground, its front toward -Z, heights
-- from the floor. The tube comes in on the ground from a mouth Inset in
-- front of the middle, on the line Radius to the right (+X), straight in to
-- where it meets the circle Radius round the middle, then climbs Loops times
-- round it, Pitch up each loop, turning toward the middle. The last half
-- loop climbs gently up through the crater floor at the hatch, on the back
-- half, and comes out level on the floor heading for the front, on the line
-- Radius to the left, and the tube ends LevelRun on. Outside is from the
-- tube's middle line to its outside; the floor is FloorThickness thick,
-- just over the last whole loop.
export type VolcanoClimb = {
	Radius: number,
	Pitch: number,
	Loops: number,
	Inset: number,
	LevelRun: number,
	Outside: number,
	FloorThickness: number,
}

export type VolcanoTube = {
	pieces: { Piece },
	floor: number, -- the crater floor's top, from the ground
	hatch: Rect, -- where the tube comes up through the floor
	exit: Crossing, -- where the tube leaves the hatch, level on the floor
	mouth: Crossing, -- the tube's end on the floor
	warning: string?,
}

function Tunnel.volcano(climb: VolcanoClimb, tunnels: Tunnels): VolcanoTube
	local R, outside = climb.Radius, climb.Outside
	local ground = Tunnel.groundHeight(tunnels)
	local segments: { Segment } = { { Straight = climb.Inset } }
	for _ = 1, climb.Loops do
		table.insert(segments, { Turn = -360, Radius = R, Rise = climb.Pitch })
	end
	local top = ground + climb.Loops * climb.Pitch
	local floor = top + outside + climb.FloorThickness
	table.insert(segments, { Turn = -180, Radius = R, Rise = floor + ground - top })
	table.insert(segments, { Straight = climb.LevelRun })
	local pieces = Tunnel.path(R, -climb.Inset, 0, 1, segments, ground)
	return {
		pieces = pieces,
		floor = floor,
		hatch = { x1 = -R - outside, x2 = R + outside, z1 = 0, z2 = R + outside },
		exit = { x = -R, z = 0 },
		mouth = { x = -R, z = -climb.LevelRun },
		warning = if climb.Pitch < 2 * outside then "the volcano's Pitch lets its loops meet" else nil,
	}
end

-- The Corkscrew park's gravitron tubes (Tuning.Corkscrew.Gravitron.Tubes):
-- two, from mouths on the ground at opposite ends of the ride, that dive
-- under it and twist round each other up into its floor (Gravitron).
--
-- Each strand's twist is in the bowl's space (Gravitron): it starts on the
-- Z axis TwistRadius out, `side` 1 at +Z heading +X and -1 at -Z heading
-- -X, so the two start opposite each other, and climbs Loops whole loops
-- of Pitch round the axis to the left, its top loop's outside TopGap under
-- the floor. It climbs evenly, so the strands stay half a Pitch apart, but
-- for TwistEase of the way at each end, where it eases in from level and
-- out to level. Then it runs straight on, climbing to come up through the
-- floor at ExitAngle: its bottom plank meets the floor at the climb's
-- steepest, halfway along. Pieces.Tube cuts it off at the floor.
--
-- Each strand's approach is in the ride's ground space: in on the ground
-- from its mouth along X, level for Level, then diving no steeper than
-- DiveSlope to Dip under where its twist starts, and climbing back up over
-- the last DipLength to meet it, heading the same way. The other strand's
-- first half loop passes over the end of the approach, so the dip keeps
-- them apart.
export type GravitronTubes = {
	TwistRadius: number,
	Pitch: number,
	Loops: number,
	TwistEase: number,
	TopGap: number,
	ExitAngle: number,
	DiveSlope: number,
	Level: number,
	Dip: number,
	DipLength: number,
	Outside: number,
}

-- The bowl's tilt in degrees, and its floor's middle's height (Gravitron).
export type GravitronBowl = {
	Tilt: number,
	CenterHeight: number,
	FloorThickness: number,
}

export type GravitronStrand = {
	side: number,
	approach: { Piece }, -- ground space
	twist: { Piece }, -- bowl space
	mouth: Crossing, -- ground space, where the approach starts
	heading: number, -- along X, in from the mouth
	-- Radians to roll the twist's rings round its middle line so they meet
	-- the approach's: the twist's rings are square to the bowl's axis, the
	-- approach's to the ground.
	roll: number,
	top: number, -- bowl space: the top loop's middle line
}

function Tunnel.gravitron(tubes: GravitronTubes, bowl: GravitronBowl, tunnels: Tunnels): ({ GravitronStrand }, string?)
	local R = tubes.TwistRadius
	local face = tunnels.Radius * math.cos(math.pi / tunnels.Sides)
	local ground = Tunnel.groundHeight(tunnels)
	local tilt = math.rad(bowl.Tilt)
	local c, s = math.cos(tilt), math.sin(tilt)
	local top = -(bowl.FloorThickness + tubes.TopGap + tubes.Outside)
	local bottom = top - tubes.Loops * tubes.Pitch
	local exitAngle = math.rad(tubes.ExitAngle)
	-- The eased climb is steepest halfway, 1.5 times its average slope.
	local exitRise = 2 * (face / math.cos(exitAngle) - top)
	local exitLength = 1.5 * exitRise / math.tan(exitAngle)

	local strands: { GravitronStrand } = {}
	for _, side in { 1, -1 } do
		local segments: { Segment } = {
			{ Turn = 360 * tubes.Loops, Radius = R, Rise = tubes.Loops * tubes.Pitch, Ease = tubes.TwistEase },
			{ Straight = exitLength, Rise = exitRise },
		}
		local twist = Tunnel.path(0, side * R, side, 0, segments, bottom)

		-- Where the twist starts, in the ground space (Gravitron.fromLocal).
		local startY = bowl.CenterHeight + bottom * c - side * R * s
		local startZ = bottom * s + side * R * c
		local drop = ground - startY + tubes.Dip
		local dive = 1.5 * drop / math.tan(math.rad(tubes.DiveSlope))
		local mouthX = -side * (tubes.Level + dive + tubes.DipLength)
		local approach = Tunnel.path(mouthX, startZ, side, 0, {
			{ Straight = tubes.Level },
			{ Straight = dive, Rise = -drop },
			{ Straight = tubes.DipLength, Rise = tubes.Dip },
		}, ground)
		table.insert(strands, {
			side = side,
			approach = approach,
			twist = twist,
			mouth = { x = mouthX, z = startZ },
			heading = side,
			roll = side * tilt,
			top = top,
		})
	end
	local warning = if tubes.Pitch / 2 < 2 * tubes.Outside then "the gravitron's Pitch lets its tubes meet" else nil
	return strands, warning
end

-- The Corkscrew park's globe's tube (Tuning.Corkscrew.Globe), in its ground
-- space: on the floor under the globe's bottom, the tube heading +X. From a
-- mouth on the ground it runs Level, dives, runs Run level with its middle
-- line Depth under the floor, then climbs, steepest at ExitAngle halfway,
-- where its middle line passes `cut` under the bottom: the tube is cut off
-- there and the car carries on up into the globe. Given as a gravitron
-- strand, its climb as the twist, so the gravitron's funnel and launch pads
-- fit it.
export type GlobeTube = {
	ExitAngle: number,
	DiveSlope: number,
	Level: number,
	Run: number,
	Depth: number,
}

function Tunnel.globe(tube: GlobeTube, cut: number, tunnels: Tunnels): GravitronStrand
	local ground = Tunnel.groundHeight(tunnels)
	local bottom = -tube.Depth
	-- Eased climbs are steepest halfway, 1.5 times their average slope.
	local exitRise = 2 * (cut - bottom)
	local exitLength = 1.5 * exitRise / math.tan(math.rad(tube.ExitAngle))
	local drop = ground - bottom
	local dive = 1.5 * drop / math.tan(math.rad(tube.DiveSlope))
	local exitX = -exitLength / 2
	local mouthX = exitX - tube.Run - dive - tube.Level
	local approach = Tunnel.path(mouthX, 0, 1, 0, {
		{ Straight = tube.Level },
		{ Straight = dive, Rise = -drop },
		{ Straight = tube.Run },
	}, ground)
	local climb = Tunnel.path(exitX, 0, 1, 0, { { Straight = exitLength, Rise = exitRise } }, bottom)
	return {
		side = 1,
		approach = approach,
		twist = climb,
		mouth = { x = mouthX, z = 0 },
		heading = 1,
		roll = 0,
		top = bottom,
	}
end

-- The Corkscrew park's face's tubes (Tuning.Corkscrew.Globe), in its ground
-- space: on the floor under the middle of the face, which stands across Z,
-- the eyes Span out either side. From a mouth on the ground a stem runs
-- along +X to TurnRadius short of the face, and forks: each branch turns a
-- quarter on the ground, left to -Z or right to +Z, then climbs out under
-- its eye, steepest at ExitAngle halfway, right under it, where its middle
-- line passes `cut`, the height the face's eyes' bottoms are built at. Seen
-- from the mouth the branches make a smile.
export type FaceTubes = {
	Span: number,
	TurnRadius: number,
	ExitAngle: number,
	Stem: number,
}

export type Face = {
	stem: { Piece },
	left: { Piece },
	right: { Piece },
	mouth: Crossing, -- where the stem starts
	heading: number, -- along X, in from the mouth
	cut: number,
}

function Tunnel.face(tubes: FaceTubes, tunnels: Tunnels): Face
	local ground = Tunnel.groundHeight(tunnels)
	local r = tubes.TurnRadius
	local forkX = -r
	local mouthX = forkX - tubes.Stem
	local stem = Tunnel.path(mouthX, 0, 1, 0, { { Straight = tubes.Stem } }, ground)
	-- Eased climbs are steepest halfway, 1.5 times their average slope.
	local climbLength = 2 * (tubes.Span - r)
	local climbRise = climbLength * math.tan(math.rad(tubes.ExitAngle)) / 1.5
	local function branch(turn: number): { Piece }
		return (
			Tunnel.path(forkX, 0, 1, 0, {
				{ Turn = turn, Radius = r },
				{ Straight = climbLength, Rise = climbRise },
			}, ground)
		)
	end
	return {
		stem = stem,
		left = branch(90),
		right = branch(-90),
		mouth = { x = mouthX, z = 0 },
		heading = 1,
		cut = ground + climbRise / 2,
	}
end

-- How thick a tube's planks are (Pieces.Tube).
Tunnel.THICKNESS = 2

-- A tube's shape, as in Tuning.City.Tunnels.
export type Shape = {
	Radius: number,
	Sides: number,
	MouthFloor: number,
	MouthCurve: number,
	FlareLength: number,
}

-- A tube's outline across it, outside its planks: a flat floor and roof
-- `flat` either side of the middle, `middle` up from the ground, with
-- curves whose outside corners are `outside` round.
export type Section = {
	flat: number,
	outside: number,
	middle: number,
}

-- The outline `t` studs in from a mouth on the ground, as Pieces.Tube
-- flares it: the mouth's flat floor and MouthCurve curves easing into the
-- round tube over FlareLength.
function Tunnel.section(shape: Shape, t: number): Section
	local ease = Tunnel.ease(1 - math.clamp(t / shape.FlareLength, 0, 1))
	local radius = shape.Radius + (shape.MouthCurve - shape.Radius) * ease
	local c = math.cos(math.pi / shape.Sides)
	return {
		flat = shape.MouthFloor / 2 * ease,
		outside = (radius * c + Tunnel.THICKNESS) / c,
		middle = radius * c + Tunnel.LIFT,
	}
end

-- How far either side of its middle the outline reaches at `y` up from the
-- ground, or nil when it is all above or below.
function Tunnel.halfWidth(section: Section, y: number): number?
	local d = y - section.middle
	if math.abs(d) > section.outside then
		return nil
	end
	return section.flat + math.sqrt(section.outside * section.outside - d * d)
end

-- Seen from above, the box round the part of the tube along `piece`, its
-- outside `outside` from the middle line, whose top is higher than `y`, or
-- nil when none is.
function Tunnel.above(piece: Piece, outside: number, y: number): Rect?
	local x1, x2, z1, z2 = math.huge, -math.huge, math.huge, -math.huge
	local steps = math.max(1, math.ceil(Tunnel.length(piece) / 2))
	for i = 0, steps do
		local px, py, pz = Tunnel.pointAt(piece, i / steps)
		if py + outside > y then
			x1, x2 = math.min(x1, px - outside), math.max(x2, px + outside)
			z1, z2 = math.min(z1, pz - outside), math.max(z2, pz + outside)
		end
	end
	if x1 > x2 then
		return nil
	end
	return { x1 = x1, x2 = x2, z1 = z1, z2 = z2 }
end

-- From the nearest point on `piece`'s middle line to (x, y, z), each place
-- the point is alongside it: once on a straight, and once each time round a
-- turn that loops. None past either end.
local function offsets(piece: Piece, x: number, y: number, z: number): { { number } }
	-- How far along the piece the point is alongside it, seen from above.
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
	local found: { { number } } = {}
	for _, seen in alongside do
		-- Seen from above is not square to a line that climbs steeply, so
		-- slide along to the nearest point on it.
		local t = seen
		for _ = 1, 4 do
			local t0, t1 = math.max(t - 1e-3, 0), math.min(t + 1e-3, 1)
			local x0, y0, z0 = Tunnel.pointAt(piece, t0)
			local x1, y1, z1 = Tunnel.pointAt(piece, t1)
			local dx, dy, dz = (x1 - x0) / (t1 - t0), (y1 - y0) / (t1 - t0), (z1 - z0) / (t1 - t0)
			local px, py, pz = Tunnel.pointAt(piece, t)
			local d2 = dx * dx + dy * dy + dz * dz
			if d2 < 1e-12 then
				break
			end
			t = math.clamp(t + ((x - px) * dx + (y - py) * dy + (z - pz) * dz) / d2, 0, 1)
		end
		local ax, ay, az = Tunnel.pointAt(piece, t)
		table.insert(found, { x - ax, y - ay, z - az })
	end
	return found
end

-- The way a tube of `radius` around the middle line `pieces` pulls a car at
-- (x, y, z): straight out from the nearest point on the middle line through
-- the car, toward the nearest wall, as a unit vector. Nil outside the tube,
-- past either end or beyond its wall. On the middle line itself, straight
-- down.
function Tunnel.pull(pieces: { Piece }, radius: number, x: number, y: number, z: number): (number?, number?, number?)
	for _, piece in pieces do
		for _, offset in offsets(piece, x, y, z) do
			local px, py, pz = offset[1], offset[2], offset[3]
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

-- How far (x, y, z) is from the nearest point on the middle line `pieces`
-- that it is alongside, or nil when it is past both ends.
function Tunnel.distance(pieces: { Piece }, x: number, y: number, z: number): number?
	local best: number? = nil
	for _, piece in pieces do
		for _, offset in offsets(piece, x, y, z) do
			local distance = math.sqrt(offset[1] ^ 2 + offset[2] ^ 2 + offset[3] ^ 2)
			if not best or distance < best then
				best = distance
			end
		end
	end
	return best
end

return Tunnel
