--!strict
-- CoolingTower (ModuleScript) -> ReplicatedStorage.CoolingTower
-- The shape of the nuclear plant's cooling towers (Tuning.Plant.Tower), a
-- surface a car drives all the way over: from the ground up the outside, over
-- a round crest, and down the inside to a flat floor. Seen from the side it is
-- one line, the profile, spun round the tower's middle. R is studs from the
-- middle and Y studs above the floor. Each wall is a hyperbola, the real shape
-- of a cooling tower, and every join is tangent, so a car never meets a kink.
-- Pure, see InputAxes.

local CoolingTower = {}

export type Shape = {
	Height: number,
	WaistHeight: number, -- where both walls are narrowest
	WaistRadius: number, -- the outside wall's narrowest
	Curve: number, -- how fast the outside wall widens away from the waist; lower is faster
	CrestRadius: number, -- the round top, which has to hold a car over it
	InnerLean: number, -- degrees the inside wall leans where it leaves the crest; more widens the floor
	FootHeight: number, -- where the outside wall starts curving out to the ground
	FloorHeight: number, -- where the inside wall starts curving in to the floor
	Rows: { Foot: number, Outer: number, Crest: number, Inner: number, Floor: number },
}

export type Point = { R: number, Y: number }

-- A hyperbola r^2 = W^2 (1 + (y - waist)^2 / c^2), by W, waist and c.
local function radiusAt(w: number, waist: number, c: number, y: number): number
	local t = (y - waist) / c
	return w * math.sqrt(1 + t * t)
end

local function slopeAt(w: number, waist: number, c: number, y: number): number
	return w * w * (y - waist) / (c * c * radiusAt(w, waist, c, y))
end

-- The surface's normal, facing away from the solid wall, for a line followed
-- from the outside's foot toward the floor. As (out, up).
function CoolingTower.normal(a: Point, b: Point): (number, number)
	local dr, dy = b.R - a.R, b.Y - a.Y
	local length = math.sqrt(dr * dr + dy * dy)
	return dy / length, -dr / length
end

-- A curve to the ground from a wall at height `y`, where the wall has
-- `slope` (dr/dy) and `side` is 1 on the outside and -1 on the inside. Its
-- middle, radius and the angle from the ground to the wall.
local function groundCurve(r: number, y: number, slope: number, side: number): (number, number, number)
	local length = math.sqrt(1 + slope * slope)
	local nr, ny = side / length, -side * slope / length
	local radius = y / (1 - ny)
	return r + nr * radius, radius, math.atan2(nr, ny)
end

local function addArc(points: { Point }, middleR: number, radius: number, from: number, to: number, rows: number)
	for i = 0, rows do
		local a = from + (to - from) * i / rows
		table.insert(points, { R = middleR - radius * math.sin(a), Y = radius - radius * math.cos(a) })
	end
end

-- The profile, from the outside's foot on the ground, up and over, to the
-- inside's edge of the flat floor.
function CoolingTower.profile(shape: Shape): { Point }
	local W, waist, c = shape.WaistRadius, shape.WaistHeight, shape.Curve
	local K = shape.CrestRadius
	local rows = shape.Rows

	-- Where the outside wall meets the crest: the height that puts the crest's
	-- top at Height.
	local outerY = shape.Height - K
	local crestR, crestY, crestFrom = 0, 0, 0
	for _ = 1, 8 do
		local slope = slopeAt(W, waist, c, outerY)
		local length = math.sqrt(1 + slope * slope)
		local nr, ny = 1 / length, -slope / length
		crestR = radiusAt(W, waist, c, outerY) - nr * K
		crestY = outerY - ny * K
		crestFrom = math.atan2(ny, nr)
		outerY += shape.Height - (crestY + K)
	end

	-- The inside wall leaves the crest InnerLean past straight down, which
	-- settles its hyperbola, given the same waist height.
	local lean = math.rad(shape.InnerLean)
	local innerY = crestY + K * math.sin(lean)
	local innerR = crestR - K * math.cos(lean)
	local spread = innerR * math.tan(lean) / (innerY - waist)
	local innerW = math.sqrt(innerR * innerR - spread * (innerY - waist) ^ 2)
	local innerC = innerW / math.sqrt(spread)

	local points: { Point } = {}

	local footR, footRadius, footTo = groundCurve(
		radiusAt(W, waist, c, shape.FootHeight),
		shape.FootHeight,
		slopeAt(W, waist, c, shape.FootHeight),
		1
	)
	addArc(points, footR, footRadius, 0, footTo, rows.Foot)

	for i = 1, rows.Outer - 1 do
		local y = shape.FootHeight + (outerY - shape.FootHeight) * i / rows.Outer
		table.insert(points, { R = radiusAt(W, waist, c, y), Y = y })
	end

	local crestTo = math.pi - lean
	for i = 0, rows.Crest do
		local a = crestFrom + (crestTo - crestFrom) * i / rows.Crest
		table.insert(points, { R = crestR + K * math.cos(a), Y = crestY + K * math.sin(a) })
	end

	for i = 1, rows.Inner - 1 do
		local y = innerY + (shape.FloorHeight - innerY) * i / rows.Inner
		table.insert(points, { R = radiusAt(innerW, waist, innerC, y), Y = y })
	end

	local floorR, floorRadius, floorFrom = groundCurve(
		radiusAt(innerW, waist, innerC, shape.FloorHeight),
		shape.FloorHeight,
		slopeAt(innerW, waist, innerC, shape.FloorHeight),
		-1
	)
	addArc(points, floorR, floorRadius, floorFrom, 0, rows.Floor)

	return points
end

-- How far out the foot reaches on the ground.
function CoolingTower.footRadius(shape: Shape): number
	return CoolingTower.profile(shape)[1].R
end

-- How far out the flat floor inside reaches.
function CoolingTower.floorRadius(shape: Shape): number
	local profile = CoolingTower.profile(shape)
	return profile[#profile].R
end

return CoolingTower
