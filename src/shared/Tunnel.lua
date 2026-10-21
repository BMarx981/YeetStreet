--!strict
-- Tunnel (ModuleScript) -> ReplicatedStorage.Tunnel
-- The middle line of a tunnel seen from above, from straights and turns.
-- A path starts at a point heading one way, and each segment carries on from
-- where the last one ended. Pure, see InputAxes.
--
-- Headings are unit vectors on the ground (x, z). A turn's angle is in
-- degrees, positive to the left, which is counterclockwise seen from above
-- the way CFrame.Angles(0, angle, 0) turns: facing -Z, left is -X.

local Tunnel = {}

-- A segment in a tunnel's layout: either Straight, studs long, or Turn,
-- degrees, around a circle of Radius studs.
export type Segment = {
	Straight: number?,
	Turn: number?,
	Radius: number?,
}

-- A straight or a turn of the middle line, from where the car enters it to
-- where it leaves. A turn is also given as a sweep counterclockwise from
-- above, around its center, starting at `start`: where the car enters a
-- left turn, and where it leaves a right one.
export type Piece = {
	kind: "straight" | "arc",
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	centerX: number,
	centerZ: number,
	radius: number,
	startX: number,
	startZ: number,
	sweep: number, -- radians
}

export type Pose = {
	x: number,
	z: number,
	headingX: number,
	headingZ: number,
}

-- (x, z) turned `angle` radians to the left.
local function turned(x: number, z: number, angle: number): (number, number)
	local c, s = math.cos(angle), math.sin(angle)
	return x * c + z * s, -x * s + z * c
end

function Tunnel.path(x: number, z: number, headingX: number, headingZ: number, segments: { Segment }): ({ Piece }, Pose)
	local pieces: { Piece } = {}
	for _, segment in segments do
		if segment.Straight then
			local length = segment.Straight
			local toX, toZ = x + headingX * length, z + headingZ * length
			table.insert(pieces, {
				kind = "straight",
				fromX = x,
				fromZ = z,
				toX = toX,
				toZ = toZ,
				centerX = 0,
				centerZ = 0,
				radius = 0,
				startX = x,
				startZ = z,
				sweep = 0,
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
				toX = toX,
				toZ = toZ,
				centerX = centerX,
				centerZ = centerZ,
				radius = radius,
				startX = if angle > 0 then x else toX,
				startZ = if angle > 0 then z else toZ,
				sweep = math.abs(angle),
			})
			x, z = toX, toZ
			headingX, headingZ = turned(headingX, headingZ, angle)
		end
	end
	return pieces, { x = x, z = z, headingX = headingX, headingZ = headingZ }
end

-- The dense city's tube tunnels (Tuning.City), in park coordinates: studs
-- from the park's center. The server builds the tubes from this layout
-- (Parks.City) and each driver's client finds the tube its car is in.
--
-- Each tunnel building takes Columns by Rows lots at the top of a block,
-- from lot Column out on Side (1 is +X; -1 is the mirror image). Its middle
-- line starts Offset into the side facing the avenue (from the street side)
-- or the street (from the avenue side), runs its shape's segments, then goes
-- straight out of whichever side it ends heading for.

-- How far a tube's bottom plank sits above the floor, so the two never
-- flicker.
Tunnel.LIFT = 0.05

export type Place = {
	Side: number,
	Block: number,
	Column: number,
	Shape: string,
}

export type Shape = {
	Start: string, -- "Avenue" or "Street"
	Offset: number,
	Segments: { Segment },
}

export type Tunnels = {
	Radius: number,
	Sides: number,
	Columns: number,
	Rows: number,
	Shapes: { [string]: Shape },
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

export type Tube = {
	place: Place,
	rect: Rect,
	pieces: { Piece },
	entry: { x: number, z: number },
	finish: Pose,
	warning: string?, -- set when the tunnel does not end heading out of a side
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

local function layoutOne(city: City, place: Place, top: number): Tube
	local B, T = city.Buildings, city.Tunnels
	local side = place.Side
	local shape = T.Shapes[place.Shape]
	-- From the avenue's middle to the building's side nearest it.
	local edge = city.Avenue.Width / 2 + B.Setback + (place.Column - 1) * (B.Lot + B.Alley)
	local width = T.Columns * B.Lot + (T.Columns - 1) * B.Alley
	local depth = T.Rows * B.Lot + (T.Rows - 1) * B.Alley
	local rect: Rect = {
		x1 = if side > 0 then edge else -edge - width,
		x2 = if side > 0 then edge + width else -edge,
		z1 = top - depth,
		z2 = top,
	}

	local segments: { Segment } = {}
	for _, segment in shape.Segments do
		table.insert(segments, {
			Straight = segment.Straight,
			Turn = if segment.Turn then segment.Turn * side else nil,
			Radius = segment.Radius,
		})
	end
	local x, z, headingX, headingZ
	if shape.Start == "Avenue" then
		x, z, headingX, headingZ = side * edge, top - shape.Offset, side, 0
	else
		x, z, headingX, headingZ = side * (edge + shape.Offset), top, 0, -1
	end

	local _, bent = Tunnel.path(x, z, headingX, headingZ, segments)
	local toSide = 0
	local warning: string? = nil
	if math.abs(bent.headingZ) > 0.99 then
		toSide = ((if bent.headingZ > 0 then rect.z2 else rect.z1) - bent.z) / bent.headingZ
	elseif math.abs(bent.headingX) > 0.99 then
		toSide = ((if bent.headingX > 0 then rect.x2 else rect.x1) - bent.x) / bent.headingX
	else
		warning = `a {place.Shape} tunnel does not end heading straight at a side of its building`
	end
	table.insert(segments, { Straight = math.max(toSide, 0) })
	local pieces, finish = Tunnel.path(x, z, headingX, headingZ, segments)
	return {
		place = place,
		rect = rect,
		pieces = pieces,
		entry = { x = x, z = z },
		finish = finish,
		warning = warning,
	}
end

-- Every tunnel in Tunnels.Places whose block exists.
function Tunnel.layout(city: City): { Tube }
	local blocks = Tunnel.blocks(city)
	local tubes: { Tube } = {}
	for _, place in city.Tunnels.Places do
		local block = blocks[place.Block]
		if block then
			table.insert(tubes, layoutOne(city, place, block.top - city.Buildings.Setback))
		end
	end
	return tubes
end

-- Height of a tube's middle line for a park floor whose top is at
-- `floorTop`: its bottom plank, flat across, lies just above the floor.
function Tunnel.centerHeight(tunnels: Tunnels, floorTop: number): number
	return floorTop + tunnels.Radius * math.cos(math.pi / tunnels.Sides) + Tunnel.LIFT
end

-- The way a tube of `radius` around the middle line `pieces`, at height
-- `centerY`, pulls a car at (x, y, z): straight out from the middle line
-- through the car, toward the nearest wall, as a unit vector. Nil outside
-- the tube, past either end or beyond its wall. On the middle line itself,
-- straight down.
function Tunnel.pull(
	pieces: { Piece },
	radius: number,
	centerY: number,
	x: number,
	y: number,
	z: number
): (number?, number?, number?)
	for _, piece in pieces do
		-- The nearest point on the middle line, if the car is alongside it.
		local ax, az
		if piece.kind == "straight" then
			local dx, dz = piece.toX - piece.fromX, piece.toZ - piece.fromZ
			local length = math.sqrt(dx * dx + dz * dz)
			local along = ((x - piece.fromX) * dx + (z - piece.fromZ) * dz) / length
			if along >= 0 and along <= length then
				ax, az = piece.fromX + dx / length * along, piece.fromZ + dz / length * along
			end
		else
			local ux, uz = piece.startX - piece.centerX, piece.startZ - piece.centerZ
			local wx, wz = x - piece.centerX, z - piece.centerZ
			local out = math.sqrt(wx * wx + wz * wz)
			-- Radians around from the start, the way a left turn goes.
			local around = math.atan2(wx * uz - wz * ux, wx * ux + wz * uz)
			if around < 0 then
				around += 2 * math.pi
			end
			if out > 1e-9 and around <= piece.sweep then
				ax, az = piece.centerX + wx / out * piece.radius, piece.centerZ + wz / out * piece.radius
			end
		end
		if ax and az then
			local px, py, pz = x - ax, y - centerY, z - az
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
