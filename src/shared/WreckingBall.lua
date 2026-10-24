--!strict
-- WreckingBall (ModuleScript) -> ReplicatedStorage.WreckingBall
-- Downtown's cranes: each stands on a roof by a street, its jib out over the
-- street's middle, and a wrecking ball swings from the jib's tip across the
-- street, skimming the road at the bottom of its swing. Pure, see InputAxes.
--
-- Points are in the pivot's space, the jib's tip: X across the street (the
-- way the ball swings), Y up, Z along the street. The ball swings like a
-- pendulum its length long: its angle from straight down is
-- amplitude * sin(rate * time + phase), with time the server's clock, so
-- every machine has it in the same place without sending anything.
--
-- A ball that reaches a car smacks it away across the street and up, harder
-- the faster the ball swings into it (push). It never slows the car along
-- the street, so a car driving down the street is batted aside.
--
-- `site` picks the building a crane stands on.

local WreckingBall = {}

export type Tuning = {
	Gravity: number,
	Radius: number,
	Reach: number, -- a hull's middle this far from the ball's surface is touching it
	Smack: number, -- studs per second across, from a ball at full swing
	Lift: number, -- studs per second up, the same
	MinShare: number, -- of Smack and Lift, from a ball barely moving into the car
}

export type Ball = {
	length: number, -- from the pivot to the ball's middle
	amplitude: number, -- radians each way from straight down
	phase: number, -- radians along its cycle at time 0
}

-- A building, its square footprint centered on (x, z) in park coordinates.
export type Building = {
	x: number,
	z: number,
	height: number,
}

-- Where a crane goes: by the avenue when Street is nil, or by the cross
-- street whose middle is at z = Street. Along is how far along that street
-- (z for the avenue, x for a cross street), Side which side of it (+1 the
-- higher x or z).
export type Spot = {
	Street: number?,
	Along: number,
	Side: number,
	Phase: number?, -- a share of a whole swing
}

export type Layout = {
	AvenueWidth: number,
	StreetWidth: number,
	Lot: number,
	Alley: number,
	Setback: number,
}

export type Site = {
	building: Building,
	outX: number, -- from the building toward the street
	outZ: number,
	pivotX: number, -- the jib's tip, over the street's middle
	pivotZ: number,
	gap: number, -- from the building's face to the street's edge
	halfStreet: number,
}

local MAX_SINE = 0.9 -- no ball swings out past about 64 degrees
local SAMPLE = 1 / 60

-- How fast its cycle turns, in radians per second.
function WreckingBall.rate(ball: Ball, gravity: number): number
	return math.sqrt(gravity / ball.length)
end

-- The ball's middle at `time`, as (x, y), and how fast it moves, as (x, y).
function WreckingBall.center(ball: Ball, time: number, gravity: number): (number, number, number, number)
	local rate = WreckingBall.rate(ball, gravity)
	local cycle = rate * time + ball.phase
	local angle = ball.amplitude * math.sin(cycle)
	local turning = ball.amplitude * rate * math.cos(cycle)
	local c, s = math.cos(angle), math.sin(angle)
	return ball.length * s, -ball.length * c, ball.length * c * turning, ball.length * s * turning
end

-- The velocity a car at (x, y, z) moving at (vx, vy, vz) has once the ball
-- smacks it at `time`, or nil when the ball is not touching it. It goes
-- across away from the ball's middle and up, at Smack and Lift times how
-- fast the ball swings into it over its fastest, never less than MinShare
-- of them, unless it already goes faster.
function WreckingBall.push(
	ball: Ball,
	time: number,
	x: number,
	y: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
	tuning: Tuning
): (number?, number?, number?)
	local bx, by, sx = WreckingBall.center(ball, time, tuning.Gravity)
	local dx, dy = x - bx, y - by
	local reach = tuning.Radius + tuning.Reach
	if dx * dx + dy * dy + z * z > reach * reach then
		return nil, nil, nil
	end
	local away = if dx > 0 or (dx == 0 and sx >= 0) then 1 else -1
	local fastest = ball.amplitude * WreckingBall.rate(ball, tuning.Gravity) * ball.length
	local share = if fastest > 0 then math.clamp(sx * away / fastest, tuning.MinShare, 1) else tuning.MinShare
	return away * math.max(tuning.Smack * share, vx * away), math.max(vy, tuning.Lift * share), vz
end

-- Whether the ball's middle comes within `reach` of (x, y, z) at any time
-- from `from` to `to`, checked every 60th of a second.
function WreckingBall.reaches(
	ball: Ball,
	from: number,
	to: number,
	x: number,
	y: number,
	z: number,
	reach: number,
	gravity: number
): boolean
	local steps = math.max(math.ceil((to - from) / SAMPLE), 1)
	for i = 0, steps do
		local bx, by = WreckingBall.center(ball, from + (to - from) * i / steps, gravity)
		local dx, dy = x - bx, y - by
		if dx * dx + dy * dy + z * z <= reach * reach then
			return true
		end
	end
	return false
end

-- The amplitude that swings a ball `length` long out `sweep` either side.
function WreckingBall.amplitude(length: number, sweep: number): number
	return math.asin(math.clamp(sweep / length, 0, MAX_SINE))
end

-- The building for a crane at `spot`: of those in the row nearest the
-- street on that side, the one nearest Along, no more than `maxShift` off.
function WreckingBall.site(buildings: { Building }, spot: Spot, layout: Layout, maxShift: number): Site?
	local street = spot.Street
	local halfStreet = (if street then layout.StreetWidth else layout.AvenueWidth) / 2
	local best: Building? = nil
	local bestShift, bestGap = math.huge, math.huge
	for _, building in buildings do
		local across = if street then building.z - street else building.x
		local along = if street then building.x else building.z
		local gap = spot.Side * across - layout.Lot / 2 - halfStreet
		local shift = math.abs(along - spot.Along)
		local nearest = gap >= 0 and gap < layout.Setback + layout.Lot + layout.Alley
		if nearest and shift <= maxShift and (shift < bestShift or (shift == bestShift and gap < bestGap)) then
			best, bestShift, bestGap = building, shift, gap
		end
	end
	if not best then
		return nil
	end
	return {
		building = best,
		outX = if street then 0 else -spot.Side,
		outZ = if street then -spot.Side else 0,
		pivotX = if street then best.x else 0,
		pivotZ = if street then street else best.z,
		gap = bestGap,
		halfStreet = halfStreet,
	}
end

return WreckingBall
