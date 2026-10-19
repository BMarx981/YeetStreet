--!strict
-- Grind (ModuleScript) -> ReplicatedStorage.Grind
-- Grinding rails: where a car rides on a rail, when it gets on, and the
-- balance game that keeps it there. Pure, see InputAxes.
--
-- A rail is a straight segment from a to b along its center. A grinding car's
-- hull rides GrindHeight above it, on the grind line. A car gets on when it
-- comes within CaptureRadius of the grind line, between the ends, moving along
-- the rail (MinAlign is the cosine of the widest angle) at MinSpeed or more.
-- The server calls a car that is within HoldTolerance of a grind line and
-- moving along it grinding (onRail), from its motion alone.
--
-- The balance game is a bar from -1 to 1 with a zone and a marker. The zone
-- drifts toward a new random spot every so often. The marker tips away from
-- the middle, gets pushed by random gusts that grow stronger the longer the
-- grind lasts, and steering pushes it back. Outside the zone for Grace
-- seconds in a row, the car falls off.

local Grind = {}

export type Rail = {
	ax: number,
	ay: number,
	az: number,
	bx: number,
	by: number,
	bz: number,
}

export type Tuning = {
	GrindHeight: number,
	CaptureRadius: number,
	HoldTolerance: number,
	MinAlign: number,
	MinSpeed: number,
	ZoneHalf: number, -- half the zone's width, on a bar 2 wide
	ZoneSpeed: number, -- how fast the zone drifts, in bar units (the bar is 2) per second
	RetargetMin: number,
	RetargetMax: number,
	Tip: number,
	Wobble: number,
	WobbleGrowth: number, -- the gusts grow by this fraction per second on the rail
	GustTime: number,
	SteerForce: number,
	Damping: number,
	Grace: number,
}

export type Balance = {
	marker: number,
	velocity: number,
	zone: number,
	zoneTarget: number,
	retarget: number, -- seconds until the zone picks a new spot
	gust: number, -- -1 to 1, times the wobble
	gustLeft: number, -- seconds until the next gust
	time: number, -- seconds on the rail
	outside: number, -- seconds outside the zone in a row
}

-- The random numbers the balance game needs (an Rng from Rng.new).
export type Random = {
	range: (low: number, high: number) -> number,
}

function Grind.length(rail: Rail): number
	return math.sqrt((rail.bx - rail.ax) ^ 2 + (rail.by - rail.ay) ^ 2 + (rail.bz - rail.az) ^ 2)
end

-- The point on the grind line `t` of the way from a to b.
function Grind.point(rail: Rail, t: number, tuning: Tuning): (number, number, number)
	return rail.ax + (rail.bx - rail.ax) * t,
		rail.ay + (rail.by - rail.ay) * t + tuning.GrindHeight,
		rail.az + (rail.bz - rail.az) * t
end

-- How far along the grind line the point is (0 at a, 1 at b, past them
-- outside the rail) and how far it is from the line there.
local function locate(rail: Rail, x: number, y: number, z: number, tuning: Tuning): (number, number)
	local dx, dy, dz = rail.bx - rail.ax, rail.by - rail.ay, rail.bz - rail.az
	local lengthSquared = dx * dx + dy * dy + dz * dz
	local px, py, pz = x - rail.ax, y - (rail.ay + tuning.GrindHeight), z - rail.az
	local t = if lengthSquared > 0 then (px * dx + py * dy + pz * dz) / lengthSquared else 0
	local gx, gy, gz = Grind.point(rail, t, tuning)
	return t, math.sqrt((x - gx) ^ 2 + (y - gy) ^ 2 + (z - gz) ^ 2)
end

-- The velocity's speed along the rail, a to b positive, and the cosine of
-- the angle between them (0 when not moving).
local function along(rail: Rail, vx: number, vy: number, vz: number): (number, number)
	local length = Grind.length(rail)
	local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
	if length <= 0 or speed <= 0 then
		return 0, 0
	end
	local s = (vx * (rail.bx - rail.ax) + vy * (rail.by - rail.ay) + vz * (rail.bz - rail.az)) / length
	return s, math.abs(s) / speed
end

-- 1 if a car here moving like this gets on riding from a to b, -1 riding
-- from b to a, nil if it doesn't get on. Also returns how far along the rail
-- it is, and its speed along it (a to b positive).
function Grind.capture(
	rail: Rail,
	x: number,
	y: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
	tuning: Tuning
): (number?, number, number)
	local t, distance = locate(rail, x, y, z, tuning)
	local speed, alignment = along(rail, vx, vy, vz)
	if t < 0 or t > 1 or distance > tuning.CaptureRadius then
		return nil, t, speed
	end
	if math.abs(speed) < tuning.MinSpeed or alignment < tuning.MinAlign then
		return nil, t, speed
	end
	return if speed > 0 then 1 else -1, t, speed
end

-- Whether a car here moving like this is grinding the rail.
function Grind.onRail(
	rail: Rail,
	x: number,
	y: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
	tuning: Tuning
): boolean
	local t, distance = locate(rail, x, y, z, tuning)
	if t < 0 or t > 1 or distance > tuning.HoldTolerance then
		return false
	end
	local _, alignment = along(rail, vx, vy, vz)
	return alignment >= tuning.MinAlign
end

function Grind.balance(): Balance
	return {
		marker = 0,
		velocity = 0,
		zone = 0,
		zoneTarget = 0,
		retarget = 0,
		gust = 0,
		gustLeft = 0,
		time = 0,
		outside = 0,
	}
end

-- How hard the gusts push now.
function Grind.wobble(b: Balance, tuning: Tuning): number
	return tuning.Wobble * (1 + tuning.WobbleGrowth * b.time)
end

function Grind.inZone(b: Balance, tuning: Tuning): boolean
	return math.abs(b.marker - b.zone) <= tuning.ZoneHalf
end

-- Advances the balance game one step with `steer` from -1 to 1. Returns true
-- when the car falls off.
function Grind.stepBalance(b: Balance, steer: number, dt: number, rng: Random, tuning: Tuning): boolean
	b.time += dt

	b.retarget -= dt
	if b.retarget <= 0 then
		local limit = 1 - tuning.ZoneHalf
		b.zoneTarget = rng.range(-limit, limit)
		b.retarget = rng.range(tuning.RetargetMin, tuning.RetargetMax)
	end
	local move = tuning.ZoneSpeed * dt
	b.zone += math.clamp(b.zoneTarget - b.zone, -move, move)

	b.gustLeft -= dt
	if b.gustLeft <= 0 then
		b.gust = rng.range(-1, 1)
		b.gustLeft = tuning.GustTime
	end

	local accel = b.gust * Grind.wobble(b, tuning)
		+ b.marker * tuning.Tip
		+ steer * tuning.SteerForce
		- b.velocity * tuning.Damping
	b.velocity += accel * dt
	b.marker += b.velocity * dt
	if math.abs(b.marker) > 1 then
		b.marker = math.sign(b.marker)
		b.velocity = 0
	end

	if Grind.inZone(b, tuning) then
		b.outside = 0
	else
		b.outside += dt
	end
	return b.outside >= tuning.Grace - 1e-9
end

return Grind
