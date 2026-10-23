--!strict
-- Ptero (ModuleScript) -> ReplicatedStorage.Ptero
-- Dino Valley's pterodactyl: where it flies, which car it swoops on, and
-- when its talons grab one. Pure, see InputAxes. The server steps it and
-- decides every grab and drop (Parks.DinoPtero); clients only draw it.
--
--   perch    sits on its perch for PerchTime, ignoring every car
--   circle   flies at CruiseSpeed and CruiseHeight above the floor toward
--            spots in its territory Edge in from the rectangle's sides,
--            picking a new one on reaching it or after GoalTime, turning at
--            most TurnRate degrees a second
--   swoop    a car on the ground in its territory within Sight, measured
--            flat: for Warn seconds it holds its height and turns toward
--            it, then dives at it, up to DiveSpeed, turning up to
--            DiveTurnRate and dropping up to DiveDrop studs a second, so
--            that it comes down as it gets there. Its talons within Grab of
--            the car's top (CarTop above the hull) grab it. It gives up on a
--            car that takes off, leaves its territory or gets past Lose, or
--            after SwoopTime of diving.
--   recover  missed: Recover seconds flying back up, ignoring every car
--   carry    grabbed one: spirals CarryRadius round a spot beside it, kept
--            CarryEdge inside the rectangle, at CarrySpeed, climbing
--            CarryClimb studs a second to CarryHeight above the floor and
--            circling there, until the server lets go (letGo). It lets go
--            on EscapeJets seconds of jets, at a fumble's height if the
--            grab rolled one (fumble, FumbleChance), or at the top
--            (releases).
--   home     let go: flies back to its perch, ignoring every car, and sits
--
-- A car more than AirHeight above the floor is in the air and never
-- swooped on. Its territory is a rectangle less keep-out lines (Scatter's
-- shape, as for Rex). It flies over keep-outs, but never swoops on a car
-- inside one or outside the rectangle.
--
-- Its position is its talons, where a held car's top is. Heading is in
-- radians, 0 facing -Z and positive turning left, like the parks' Heading.
-- Positions are world studs.

local Ptero = {}

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

export type Mode = "perch" | "circle" | "swoop" | "recover" | "carry" | "home"

export type State = {
	mode: Mode,
	timer: number, -- seconds in this mode
	x: number,
	y: number,
	z: number,
	heading: number,
	speed: number, -- flat studs per second along its heading
	vy: number, -- studs per second up
	goalX: number, -- where it circles to
	goalZ: number,
	goalAge: number,
	target: any?, -- the id of the car it swoops on
	perchX: number,
	perchY: number,
	perchZ: number,
	-- The middle of its carrying spiral, and which way round it turns (1 or
	-- -1, about the vertical as the radius turns from +X toward +Z).
	spinX: number,
	spinZ: number,
	spinWay: number,
}

export type Tuning = {
	CruiseHeight: number,
	CruiseSpeed: number,
	TurnRate: number, -- degrees per second
	Accel: number, -- studs per second squared, speeding up or slowing down
	ClimbRate: number,
	Edge: number,
	GoalReach: number,
	GoalTime: number,
	Sight: number,
	AirHeight: number,
	Warn: number,
	DiveSpeed: number,
	DiveTurnRate: number, -- degrees per second
	DiveDrop: number,
	SwoopTime: number,
	Lose: number,
	Grab: number,
	CarTop: number,
	Recover: number,
	CarryHeight: number,
	CarryClimb: number,
	CarrySpeed: number,
	CarryRadius: number,
	CarryEdge: number,
	EscapeJets: number,
	FumbleChance: number,
	FumbleFrom: number,
	FumbleTo: number,
	PerchTime: number,
	PerchReach: number,
}

local TAU = 2 * math.pi
-- The slowest it flies diving or landing, so it can still turn.
local SLOWEST = 15
-- Coming home it slows to this many studs a second for each stud left.
local LANDING_SLOW = 0.5
-- The shortest time it plans to come down in, so it never drops all at once.
local SHORTEST_DESCENT = 0.25
-- Carrying, it chases a spot this far round its spiral ahead of it.
local SPIRAL_AHEAD = 0.4
-- The longest it leads a car it dives at, in seconds.
local LONGEST_LEAD = 2

local function wrap(angle: number): number
	return (angle + math.pi) % TAU - math.pi
end

function Ptero.forward(heading: number): (number, number)
	return -math.sin(heading), -math.cos(heading)
end

-- A pterodactyl sitting on its perch at x, y, z, facing `heading`.
function Ptero.new(x: number, y: number, z: number, heading: number): State
	return {
		mode = "perch",
		timer = 0,
		x = x,
		y = y,
		z = z,
		heading = heading,
		speed = 0,
		vy = 0,
		goalX = x,
		goalZ = z,
		goalAge = 0,
		target = nil,
		perchX = x,
		perchY = y,
		perchZ = z,
		spinX = x,
		spinZ = z,
		spinWay = 1,
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

-- Whether x, z is in the rectangle and beyond every keep-out's radius.
local function inside(territory: Territory, x: number, z: number): boolean
	local r = territory.rect
	if x < r.MinX or x > r.MaxX or z < r.MinZ or z > r.MaxZ then
		return false
	end
	for _, line in territory.keepOut do
		local nx, nz = nearest(line, x, z)
		if (x - nx) ^ 2 + (z - nz) ^ 2 < line.Radius ^ 2 then
			return false
		end
	end
	return true
end

-- x, z kept `edge` inside the rectangle, or at its middle if it is narrower.
local function within(rect: Rect, x: number, z: number, edge: number): (number, number)
	local function clamp(value: number, low: number, high: number): number
		return if low <= high then math.clamp(value, low, high) else (low + high) / 2
	end
	return clamp(x, rect.MinX + edge, rect.MaxX - edge), clamp(z, rect.MinZ + edge, rect.MaxZ - edge)
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

local function approach(value: number, goal: number, most: number): number
	if value < goal then
		return math.min(value + most, goal)
	end
	return math.max(value - most, goal)
end

-- Turns toward x, z at most `rate` degrees a second.
local function steer(s: State, x: number, z: number, rate: number, dt: number)
	local dx, dz = x - s.x, z - s.z
	if dx * dx + dz * dz < 1e-12 then
		return
	end
	local turn = wrap(math.atan2(-dx, -dz) - s.heading)
	local most = math.rad(rate) * dt
	s.heading = wrap(s.heading + math.clamp(turn, -most, most))
end

-- Flies on along its heading at its speed, and up at vy.
local function fly(s: State, dt: number)
	local fx, fz = Ptero.forward(s.heading)
	s.x += fx * s.speed * dt
	s.z += fz * s.speed * dt
	s.y += s.vy * dt
end

-- Climbs or sinks toward `height` at most `rate` studs a second.
local function holdHeight(s: State, height: number, rate: number, dt: number)
	local y = approach(s.y, height, rate * dt)
	s.vy = (y - s.y) / dt
end

-- Comes down toward `height` so as to get there as it covers the `flat`
-- studs left at its speed, no faster than DiveDrop, rising at most
-- ClimbRate.
local function descend(s: State, height: number, flat: number, tuning: Tuning)
	local time = math.max(flat / math.max(s.speed, SLOWEST), SHORTEST_DESCENT)
	s.vy = math.clamp((height - s.y) / time, -tuning.DiveDrop, tuning.ClimbRate)
end

local function newGoal(s: State, territory: Territory, rng: Rng, tuning: Tuning)
	s.goalAge = 0
	local r = territory.rect
	s.goalX, s.goalZ = within(r, rng.range(r.MinX, r.MaxX), rng.range(r.MinZ, r.MaxZ), tuning.Edge)
end

-- Circles toward its goal at cruise height and speed.
local function cruise(s: State, territory: Territory, rng: Rng, dt: number, tuning: Tuning)
	s.goalAge += dt
	local near = (s.goalX - s.x) ^ 2 + (s.goalZ - s.z) ^ 2 <= tuning.GoalReach * tuning.GoalReach
	if near or s.goalAge >= tuning.GoalTime then
		newGoal(s, territory, rng, tuning)
	end
	steer(s, s.goalX, s.goalZ, tuning.TurnRate, dt)
	s.speed = approach(s.speed, tuning.CruiseSpeed, tuning.Accel * dt)
	holdHeight(s, territory.floor + tuning.CruiseHeight, tuning.ClimbRate, dt)
	fly(s, dt)
end

-- The nearest car on the ground in its territory within Sight, flat.
local function spot(s: State, cars: { Car }, territory: Territory, tuning: Tuning): any?
	local best, bestDistance = nil, tuning.Sight * tuning.Sight
	for _, car in cars do
		local distance = (car.x - s.x) ^ 2 + (car.z - s.z) ^ 2
		if distance <= bestDistance and not airborne(car, territory, tuning) and inside(territory, car.x, car.z) then
			best, bestDistance = car.id, distance
		end
	end
	return best
end

-- Starts carrying: picks the middle of its spiral beside it, on its left,
-- kept CarryEdge inside the rectangle, and the way round that carries on
-- the way it faces.
local function startCarry(s: State, territory: Territory, tuning: Tuning)
	local fx, fz = Ptero.forward(s.heading)
	local leftX, leftZ = -fz, fx
	s.spinX, s.spinZ =
		within(territory.rect, s.x + leftX * tuning.CarryRadius, s.z + leftZ * tuning.CarryRadius, tuning.CarryEdge)
	local rx, rz = s.x - s.spinX, s.z - s.spinZ
	-- Turning the radius +X toward +Z moves it along (-rz, rx).
	s.spinWay = if -rz * fx + rx * fz >= 0 then 1 else -1
	setMode(s, "carry")
end

-- Spirals up round its spiral's middle at CarrySpeed.
local function carry(s: State, territory: Territory, dt: number, tuning: Tuning)
	local rx, rz = s.x - s.spinX, s.z - s.spinZ
	local r = math.sqrt(rx * rx + rz * rz)
	local angle = if r > 1e-6 then math.atan2(rz, rx) else 0
	angle += s.spinWay * SPIRAL_AHEAD
	-- Chasing a spot this far out keeps it on the spiral's radius.
	local out = tuning.CarryRadius / math.cos(SPIRAL_AHEAD)
	steer(s, s.spinX + math.cos(angle) * out, s.spinZ + math.sin(angle) * out, tuning.DiveTurnRate, dt)
	s.speed = approach(s.speed, tuning.CarrySpeed, tuning.Accel * dt)
	holdHeight(s, territory.floor + tuning.CarryHeight, tuning.CarryClimb, dt)
	fly(s, dt)
end

-- Dives at its car. Returns whether its talons reach it.
local function dive(s: State, car: Car, dt: number, tuning: Tuning): boolean
	local topY = car.y + tuning.CarTop
	local dx, dz = car.x - s.x, car.z - s.z
	local flat = math.sqrt(dx * dx + dz * dz)
	if flat * flat + (topY - s.y) ^ 2 <= tuning.Grab * tuning.Grab then
		return true
	end
	if s.timer < tuning.Warn then
		steer(s, car.x, car.z, tuning.TurnRate, dt)
		s.speed = approach(s.speed, tuning.CruiseSpeed, tuning.Accel * dt)
		s.vy = 0
		fly(s, dt)
		return false
	end
	local lead = math.min(flat / math.max(s.speed, SLOWEST), LONGEST_LEAD)
	steer(s, car.x + car.vx * lead, car.z + car.vz * lead, tuning.DiveTurnRate, dt)
	-- No faster across than it can come down.
	local above = math.max(s.y - topY, 0)
	local wanted = if above > 0 then flat * tuning.DiveDrop / above else tuning.DiveSpeed
	s.speed = approach(s.speed, math.clamp(wanted, SLOWEST, tuning.DiveSpeed), tuning.Accel * dt)
	descend(s, topY, flat, tuning)
	fly(s, dt)
	return false
end

-- Flies home and lands on its perch.
local function home(s: State, dt: number, tuning: Tuning)
	local dx, dz = s.perchX - s.x, s.perchZ - s.z
	local flat = math.sqrt(dx * dx + dz * dz)
	if flat <= tuning.PerchReach and math.abs(s.y - s.perchY) <= tuning.PerchReach then
		s.x, s.y, s.z = s.perchX, s.perchY, s.perchZ
		s.speed, s.vy = 0, 0
		setMode(s, "perch")
		return
	end
	steer(s, s.perchX, s.perchZ, tuning.DiveTurnRate, dt)
	local wanted = math.clamp(flat * LANDING_SLOW, SLOWEST, tuning.CruiseSpeed)
	s.speed = approach(s.speed, wanted, tuning.Accel * dt)
	descend(s, s.perchY, flat, tuning)
	fly(s, dt)
end

-- One step of `dt` seconds. Returns the id of the car its talons grabbed
-- this step, if any.
function Ptero.step(s: State, cars: { Car }, territory: Territory, rng: Rng, dt: number, tuning: Tuning): any?
	s.timer += dt

	if s.mode == "perch" then
		s.speed, s.vy = 0, 0
		if s.timer < tuning.PerchTime then
			return nil
		end
		newGoal(s, territory, rng, tuning)
		setMode(s, "circle")
	end

	if s.mode == "carry" then
		carry(s, territory, dt, tuning)
		return nil
	end
	if s.mode == "home" then
		home(s, dt, tuning)
		return nil
	end

	if s.mode == "swoop" then
		local car = find(cars, s.target)
		local dx = if car then car.x - s.x else 0
		local dz = if car then car.z - s.z else 0
		if
			not car
			or airborne(car, territory, tuning)
			or not inside(territory, car.x, car.z)
			or dx * dx + dz * dz > tuning.Lose * tuning.Lose
			or s.timer > tuning.Warn + tuning.SwoopTime
		then
			s.target = nil
			setMode(s, "recover")
		else
			if dive(s, car, dt, tuning) then
				s.target = nil
				startCarry(s, territory, tuning)
				return car.id
			end
			return nil
		end
	end

	if s.mode == "recover" and s.timer >= tuning.Recover then
		setMode(s, "circle")
	end
	if s.mode == "circle" then
		local seen = spot(s, cars, territory, tuning)
		if seen ~= nil then
			s.target = seen
			setMode(s, "swoop")
			return nil
		end
	end
	cruise(s, territory, rng, dt, tuning)
	return nil
end

-- Lets go of the car it carries and flies home.
function Ptero.letGo(s: State)
	s.target = nil
	setMode(s, "home")
end

-- The height above the floor a grab fumbles its car at, if it does, from
-- two rolls from 0 up to 1: one for whether, one for where.
function Ptero.fumble(roll: number, at: number, tuning: Tuning): number?
	if roll >= tuning.FumbleChance then
		return nil
	end
	return tuning.FumbleFrom + at * (tuning.FumbleTo - tuning.FumbleFrom)
end

-- Whether it lets go of a car carried `height` above the floor, with
-- `jets` seconds of its jets burning so far, that fumbles at `fumbleAt`
-- (nil if it never does).
function Ptero.releases(height: number, jets: number, fumbleAt: number?, tuning: Tuning): boolean
	-- A hair under, so the top it climbs to always counts.
	local top = tuning.CarryHeight - 1e-6
	return jets >= tuning.EscapeJets or (fumbleAt ~= nil and height >= fumbleAt) or height >= top
end

return Ptero
