--!strict
-- Laser (ModuleScript) -> ReplicatedStorage.Laser
-- The lasers from Downtown's kaiju's eyes. Pure, see InputAxes. The server
-- steps it (Parks.CityKaiju) and says which cars its eyes can see past the
-- buildings; clients only draw it.
--
--   ready   picks the nearest car it can see too far to bite, from MinRange
--           to MaxRange from its eyes, and starts charging at it
--   charge  its eyes glow for Charge seconds, aiming at its car. Lock
--           seconds before the shot the aim locks where the car will be
--           then, falling if it is in the air, so a car that swerves or
--           brakes is missed. Losing sight of its car before the lock, or
--           not being let fire, calls the shot off for Cancel seconds.
--   cool    Cooldown seconds after a shot before it charges again
--
-- The shot is a beam from its eyes to the aim (or whatever the server finds
-- in the way). The car nearest it within BeamRadius is struck (struck), and
-- blasted up at Lift and away along the beam at Push, keeping Keep of its
-- own speed across the ground (blast).

local Laser = {}

export type Tuning = {
	MinRange: number,
	MaxRange: number,
	Charge: number,
	Lock: number,
	Cooldown: number,
	Cancel: number,
	BeamRadius: number,
	Lift: number,
	Push: number,
	Keep: number,
	Gravity: number,
}

-- A car's hull as the server sees it, whether the eyes can see it, and
-- whether it is in the air.
export type Car = {
	id: any,
	x: number,
	y: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
	visible: boolean,
	air: boolean,
}

export type Mode = "ready" | "charge" | "cool"

export type State = {
	mode: Mode,
	timer: number, -- seconds charged, or left to cool
	target: any?,
	aimX: number,
	aimY: number,
	aimZ: number,
	locked: boolean,
}

-- Float steps never quite add up to a time.
local EPSILON = 1e-9

function Laser.new(): State
	return { mode = "ready", timer = 0, target = nil, aimX = 0, aimY = 0, aimZ = 0, locked = false }
end

local function find(cars: { Car }, id: any): Car?
	for _, car in cars do
		if car.id == id then
			return car
		end
	end
	return nil
end

local function cool(s: State, seconds: number)
	s.mode = "cool"
	s.timer = seconds
	s.target = nil
	s.locked = false
end

-- One step of `dt` seconds, with its eyes at x, y, z. `canFire` is false
-- while it is busy biting or holding. Returns true on the step it fires,
-- at s.aim.
function Laser.step(
	s: State,
	x: number,
	y: number,
	z: number,
	cars: { Car },
	canFire: boolean,
	dt: number,
	tuning: Tuning
): boolean
	if s.mode == "cool" then
		s.timer -= dt
		if s.timer <= EPSILON then
			s.mode = "ready"
			s.timer = 0
		end
		return false
	end

	if s.mode == "ready" then
		if not canFire then
			return false
		end
		local best, bestDistance = nil, math.huge
		for _, car in cars do
			local distance = math.sqrt((car.x - x) ^ 2 + (car.z - z) ^ 2)
			if
				car.visible
				and distance >= tuning.MinRange
				and distance <= tuning.MaxRange
				and distance < bestDistance
			then
				best, bestDistance = car, distance
			end
		end
		if best then
			s.mode = "charge"
			s.timer = 0
			s.target = best.id
			s.locked = false
			s.aimX, s.aimY, s.aimZ = best.x, best.y, best.z
		end
		return false
	end

	s.timer += dt
	local car = find(cars, s.target)
	if not s.locked then
		if not canFire or not (car and car.visible) then
			cool(s, tuning.Cancel)
			return false
		end
		if s.timer >= tuning.Charge - tuning.Lock - EPSILON then
			local t = tuning.Lock
			s.aimX, s.aimY, s.aimZ = car.x + car.vx * t, car.y + car.vy * t, car.z + car.vz * t
			if car.air then
				s.aimY -= 0.5 * tuning.Gravity * t * t
			end
			s.locked = true
		else
			s.aimX, s.aimY, s.aimZ = car.x, car.y, car.z
		end
	end
	if s.timer >= tuning.Charge - EPSILON then
		cool(s, tuning.Cooldown)
		return true
	end
	return false
end

-- The id of the car nearest the beam from (x1, y1, z1) to (x2, y2, z2),
-- within BeamRadius, if any.
function Laser.struck(
	x1: number,
	y1: number,
	z1: number,
	x2: number,
	y2: number,
	z2: number,
	cars: { Car },
	tuning: Tuning
): any?
	local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
	local lengthSquared = dx * dx + dy * dy + dz * dz
	local best, bestDistance = nil, tuning.BeamRadius
	for _, car in cars do
		local t = if lengthSquared > 0
			then math.clamp(((car.x - x1) * dx + (car.y - y1) * dy + (car.z - z1) * dz) / lengthSquared, 0, 1)
			else 0
		local px, py, pz = x1 + dx * t, y1 + dy * t, z1 + dz * t
		local distance = math.sqrt((car.x - px) ^ 2 + (car.y - py) ^ 2 + (car.z - pz) ^ 2)
		if distance <= bestDistance then
			best, bestDistance = car.id, distance
		end
	end
	return best
end

-- The velocity a struck car moving at (vx, vy, vz) is blasted to, the beam
-- heading (dirX, dirZ) across the ground (a unit vector).
function Laser.blast(
	dirX: number,
	dirZ: number,
	vx: number,
	vy: number,
	vz: number,
	tuning: Tuning
): (number, number, number)
	return dirX * tuning.Push + vx * tuning.Keep, math.max(tuning.Lift, vy), dirZ * tuning.Push + vz * tuning.Keep
end

return Laser
