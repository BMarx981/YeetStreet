--!strict
-- Rex (ModuleScript) -> ReplicatedStorage.Rex
-- Dino Valley's T-Rex, seen from above: where it walks, which car it hunts,
-- and when its jaws catch one. Pure, see InputAxes. The server steps it and
-- decides every catch (Parks.DinoRex); clients only draw it.
--
--   roam     walks at WalkSpeed toward a spot within RoamRadius, picking a
--            new one on reaching it or after GoalTime
--   chase    runs at the nearest car on the ground within Sight, up to
--            RunSpeed, turning at most TurnRate degrees a second, so a sharp
--            turn throws it off. It gives up on a car past Lose, or one that
--            leaves its territory.
--   lunge    a car its jaws can reach where that car will be in WindUp +
--            Snap seconds (AirWindUp for a car in the air): in front, within
--            Cone degrees, Neck to Reach out and up to BiteHeight above the
--            floor. It stops and rears back for the wind-up, then snaps at
--            that spot, and a car within Bite of it then is caught.
--   recover  missed: Recover seconds walking after its car before it hunts
--            again
--   rest     caught one: Rest seconds ignoring every car, the first Chew of
--            them standing still while it chews
--
-- A car more than AirHeight above the floor is in the air: never chased,
-- only snapped at. Its territory is a rectangle less keep-out lines
-- (Scatter's shape: a line with a radius, one with no length a circle). It
-- keeps its middle Body inside the rectangle and Body clear of each
-- keep-out, steering round one in its way, and never hunts or bites a car
-- inside one or outside the rectangle.
--
-- Heading is in radians, 0 facing -Z and positive turning left, like the
-- parks' Heading. Positions are world studs.

local Rex = {}

-- Same as Rng.Rng and Scatter's shapes, declared here so this module needs
-- no require.
type Rng = {
	next: () -> number,
	range: (low: number, high: number) -> number,
	int: (low: number, high: number) -> number,
}

export type Rect = {
	MinX: number,
	MaxX: number,
	MinZ: number,
	MaxZ: number,
}

export type Line = {
	AX: number,
	AZ: number,
	BX: number,
	BZ: number,
	Radius: number,
}

export type Territory = {
	rect: Rect,
	keepOut: { Line },
	floor: number, -- the ground's height
}

-- A car's hull and how fast it moves, as the server sees it.
export type Car = {
	id: any,
	x: number,
	y: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
}

export type Mode = "roam" | "chase" | "lunge" | "recover" | "rest"

export type State = {
	mode: Mode,
	timer: number, -- seconds in this mode
	x: number,
	z: number,
	heading: number,
	speed: number,
	goalX: number, -- where it roams to
	goalZ: number,
	goalAge: number,
	target: any?, -- the id of the car it hunts
	-- Where its last lunge bites, and whether at a car in the air.
	jawX: number,
	jawY: number,
	jawZ: number,
	air: boolean,
}

export type Tuning = {
	WalkSpeed: number,
	RunSpeed: number,
	Accel: number, -- studs per second squared, speeding up or slowing down
	TurnRate: number, -- degrees per second
	Sight: number,
	Lose: number,
	RoamRadius: number,
	GoalReach: number,
	GoalTime: number,
	Body: number,
	Neck: number,
	Reach: number,
	BiteHeight: number,
	Cone: number, -- degrees
	WindUp: number,
	AirWindUp: number,
	Snap: number,
	Recover: number,
	Rest: number,
	Chew: number,
	Bite: number,
	AirHeight: number,
	Gravity: number,
}

local TAU = 2 * math.pi
-- Tries for a roaming spot clear of the keep-outs before standing still.
local GOAL_TRIES = 20
-- How much harder it brakes for a lunge than it speeds up.
local LUNGE_BRAKE = 3

local function wrap(angle: number): number
	return (angle + math.pi) % TAU - math.pi
end

function Rex.forward(heading: number): (number, number)
	return -math.sin(heading), -math.cos(heading)
end

function Rex.new(x: number, z: number, heading: number): State
	return {
		mode = "roam",
		timer = 0,
		x = x,
		z = z,
		heading = heading,
		speed = 0,
		goalX = x,
		goalZ = z,
		goalAge = 0,
		target = nil,
		jawX = x,
		jawY = 0,
		jawZ = z,
		air = false,
	}
end

-- The nearest point on the line to x, z.
local function nearest(line: Line, x: number, z: number): (number, number)
	local dx, dz = line.BX - line.AX, line.BZ - line.AZ
	local lengthSquared = dx * dx + dz * dz
	local t = if lengthSquared > 0
		then math.clamp(((x - line.AX) * dx + (z - line.AZ) * dz) / lengthSquared, 0, 1)
		else 0
	return line.AX + dx * t, line.AZ + dz * t
end

-- Whether x, z is in the rectangle, `clear` in from its edges and `clear`
-- beyond every keep-out's radius.
local function inside(territory: Territory, x: number, z: number, clear: number): boolean
	local r = territory.rect
	if x < r.MinX + clear or x > r.MaxX - clear or z < r.MinZ + clear or z > r.MaxZ - clear then
		return false
	end
	for _, line in territory.keepOut do
		local nx, nz = nearest(line, x, z)
		if (x - nx) ^ 2 + (z - nz) ^ 2 < (line.Radius + clear) ^ 2 then
			return false
		end
	end
	return true
end

local function airborne(car: Car, territory: Territory, tuning: Tuning): boolean
	return car.y - territory.floor > tuning.AirHeight
end

local function find(cars: { Car }, id: any): Car?
	for _, car in cars do
		if car.id == id then
			return car
		end
	end
	return nil
end

local function setMode(s: State, mode: Mode)
	s.mode = mode
	s.timer = 0
end

-- Where the car will be in `t` seconds, falling if it is in the air.
local function predict(
	car: Car,
	t: number,
	air: boolean,
	territory: Territory,
	tuning: Tuning
): (number, number, number)
	local y = car.y
	if air then
		y = math.max(car.y + car.vy * t - 0.5 * tuning.Gravity * t * t, territory.floor)
	end
	return car.x + car.vx * t, y, car.z + car.vz * t
end

local function reachable(s: State, x: number, y: number, z: number, territory: Territory, tuning: Tuning): boolean
	local dx, dz = x - s.x, z - s.z
	local out = math.sqrt(dx * dx + dz * dz)
	local fx, fz = Rex.forward(s.heading)
	local ahead = dx * fx + dz * fz
	return ahead >= tuning.Neck
		and out <= tuning.Reach
		and ahead >= out * math.cos(math.rad(tuning.Cone))
		and y - territory.floor <= tuning.BiteHeight
end

-- Starts a lunge at the car whose coming spot is nearest among those its
-- jaws can reach. Returns whether it did.
local function lungeAtAny(s: State, cars: { Car }, territory: Territory, tuning: Tuning): boolean
	local best, bestOut = nil, math.huge
	for _, car in cars do
		local air = airborne(car, territory, tuning)
		local t = (if air then tuning.AirWindUp else tuning.WindUp) + tuning.Snap
		local x, y, z = predict(car, t, air, territory, tuning)
		if
			inside(territory, car.x, car.z, 0)
			and inside(territory, x, z, 0)
			and reachable(s, x, y, z, territory, tuning)
		then
			local out = (x - s.x) ^ 2 + (z - s.z) ^ 2
			if out < bestOut then
				best, bestOut = { x = x, y = y, z = z, air = air }, out
			end
		end
	end
	if not best then
		return false
	end
	s.jawX, s.jawY, s.jawZ, s.air = best.x, best.y, best.z, best.air
	setMode(s, "lunge")
	return true
end

-- The car its jaws close on, if any.
local function bitten(s: State, cars: { Car }, tuning: Tuning): any?
	local best, bestDistance = nil, tuning.Bite
	for _, car in cars do
		local distance = math.sqrt((car.x - s.jawX) ^ 2 + (car.y - s.jawY) ^ 2 + (car.z - s.jawZ) ^ 2)
		if distance <= bestDistance then
			best, bestDistance = car.id, distance
		end
	end
	return best
end

-- A car it may keep hunting: in its territory and within Lose.
local function stillHunted(s: State, car: Car?, territory: Territory, tuning: Tuning): boolean
	return car ~= nil
		and inside(territory, car.x, car.z, 0)
		and (car.x - s.x) ^ 2 + (car.z - s.z) ^ 2 <= tuning.Lose * tuning.Lose
end

-- The nearest car on the ground in its territory within Sight.
local function spot(s: State, cars: { Car }, territory: Territory, tuning: Tuning): any?
	local best, bestDistance = nil, tuning.Sight * tuning.Sight
	for _, car in cars do
		local distance = (car.x - s.x) ^ 2 + (car.z - s.z) ^ 2
		if distance <= bestDistance and not airborne(car, territory, tuning) and inside(territory, car.x, car.z, 0) then
			best, bestDistance = car.id, distance
		end
	end
	return best
end

local function newGoal(s: State, territory: Territory, rng: Rng, tuning: Tuning)
	s.goalAge = 0
	for _ = 1, GOAL_TRIES do
		local angle = rng.range(0, TAU)
		local out = tuning.RoamRadius * math.sqrt(rng.next())
		local x, z = s.x + math.cos(angle) * out, s.z + math.sin(angle) * out
		if inside(territory, x, z, tuning.Body) then
			s.goalX, s.goalZ = x, z
			return
		end
	end
	s.goalX, s.goalZ = s.x, s.z
end

-- Turns a way round the keep-out in its way, if one is: along its edge, on
-- the side nearer the way it wants to go.
local function avoid(
	s: State,
	dx: number,
	dz: number,
	toGoal: number,
	territory: Territory,
	tuning: Tuning
): (number, number)
	for _, line in territory.keepOut do
		local nx, nz = nearest(line, s.x, s.z)
		local ox, oz = s.x - nx, s.z - nz
		local r = math.sqrt(ox * ox + oz * oz)
		local edge = line.Radius + tuning.Body
		if r > 1e-6 and r < edge + tuning.Body and toGoal > r - edge then
			ox, oz = ox / r, oz / r
			if dx * ox + dz * oz < 0 then
				local leftX, leftZ = -oz, ox
				if dx * leftX + dz * leftZ >= 0 then
					return leftX, leftZ
				end
				return -leftX, -leftZ
			end
		end
	end
	return dx, dz
end

-- Pushes it back inside its territory.
local function keepIn(s: State, territory: Territory, tuning: Tuning)
	local r = territory.rect
	local body = tuning.Body
	s.x = math.clamp(s.x, r.MinX + body, math.max(r.MaxX - body, r.MinX + body))
	s.z = math.clamp(s.z, r.MinZ + body, math.max(r.MaxZ - body, r.MinZ + body))
	for _, line in territory.keepOut do
		local nx, nz = nearest(line, s.x, s.z)
		local ox, oz = s.x - nx, s.z - nz
		local d = math.sqrt(ox * ox + oz * oz)
		local edge = line.Radius + body
		if d < edge then
			if d < 1e-6 then
				local fx, fz = Rex.forward(s.heading)
				ox, oz, d = -fx, -fz, 1
			end
			s.x, s.z = nx + ox / d * edge, nz + oz / d * edge
		end
	end
end

local function approach(value: number, goal: number, most: number): number
	if value < goal then
		return math.min(value + most, goal)
	end
	return math.max(value - most, goal)
end

-- Turns toward x, z, speeds up or slows to `speed`, and walks on.
local function walk(s: State, x: number, z: number, speed: number, territory: Territory, dt: number, tuning: Tuning)
	local dx, dz = x - s.x, z - s.z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance > 1e-6 then
		dx, dz = avoid(s, dx / distance, dz / distance, distance, territory, tuning)
		local turn = wrap(math.atan2(-dx, -dz) - s.heading)
		local most = math.rad(tuning.TurnRate) * dt
		s.heading = wrap(s.heading + math.clamp(turn, -most, most))
	end
	s.speed = approach(s.speed, speed, tuning.Accel * dt)
	local fx, fz = Rex.forward(s.heading)
	s.x += fx * s.speed * dt
	s.z += fz * s.speed * dt
	keepIn(s, territory, tuning)
end

local function roam(s: State, territory: Territory, rng: Rng, dt: number, tuning: Tuning)
	s.goalAge += dt
	local near = (s.goalX - s.x) ^ 2 + (s.goalZ - s.z) ^ 2 <= tuning.GoalReach * tuning.GoalReach
	if near or s.goalAge >= tuning.GoalTime then
		newGoal(s, territory, rng, tuning)
	end
	walk(s, s.goalX, s.goalZ, tuning.WalkSpeed, territory, dt, tuning)
end

-- One step of `dt` seconds. Returns the id of the car its jaws caught this
-- step, if any.
function Rex.step(s: State, cars: { Car }, territory: Territory, rng: Rng, dt: number, tuning: Tuning): any?
	s.timer += dt

	if s.mode == "lunge" then
		s.speed = approach(s.speed, 0, LUNGE_BRAKE * tuning.Accel * dt)
		local fx, fz = Rex.forward(s.heading)
		s.x += fx * s.speed * dt
		s.z += fz * s.speed * dt
		keepIn(s, territory, tuning)
		local windUp = if s.air then tuning.AirWindUp else tuning.WindUp
		if s.timer < windUp + tuning.Snap then
			return nil
		end
		local caught = bitten(s, cars, tuning)
		if caught ~= nil then
			s.target = nil
			setMode(s, "rest")
		else
			setMode(s, "recover")
		end
		return caught
	end

	if s.mode == "rest" and s.timer < tuning.Chew then
		s.speed = 0
		return nil
	end

	if s.mode == "rest" and s.timer >= tuning.Rest then
		setMode(s, "roam")
	elseif s.mode == "recover" and s.timer >= tuning.Recover then
		setMode(s, "chase")
	end

	if s.mode == "chase" or s.mode == "recover" then
		if not stillHunted(s, find(cars, s.target), territory, tuning) then
			s.target = nil
			setMode(s, "roam")
		end
	end
	if s.mode == "roam" then
		local seen = spot(s, cars, territory, tuning)
		if seen ~= nil then
			s.target = seen
			setMode(s, "chase")
		end
	end
	if (s.mode == "roam" or s.mode == "chase") and lungeAtAny(s, cars, territory, tuning) then
		return nil
	end

	local car = find(cars, s.target)
	if car and (s.mode == "chase" or s.mode == "recover") then
		walk(s, car.x, car.z, if s.mode == "chase" then tuning.RunSpeed else tuning.WalkSpeed, territory, dt, tuning)
	else
		roam(s, territory, rng, dt, tuning)
	end
	return nil
end

return Rex
