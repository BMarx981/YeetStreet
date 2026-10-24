--!strict
-- Pedestrian (ModuleScript) -> ReplicatedStorage.Pedestrian
-- One of Downtown's walkers (Pedestrians) getting out of a car's way. Pure,
-- see InputAxes. The server steps it (Parks.CityPedestrians) and says
-- which cars the walker can see past the buildings; clients only draw it,
-- from the same state, with `where`.
--
--   walk  round its loop. A car on the ground it can see, coming to pass
--         within DiveRadius of it in under SeeTime, makes it dive; a car
--         reaching it (within HitRadius and HitHeight), seen or not, or
--         landing on it from the air, knocks it flat. It never sees a car
--         in the air.
--   dive  out DiveDistance square to the car's way, on its own side of it
--         (or, out in the road, toward the nearer curb), over DiveTime.
--         The car that made it dive and then passed within NearMiss
--         without reaching it pays a near miss once it is past, unless
--         this walker paid one less than Cooldown seconds ago. A car
--         reaching it while it is still in the air knocks it flat.
--   flop  thrown FlopDistance the way the car was going, over FlopTime.
--         Pays nothing.
--
-- After either it lies there (DiveDown or FlopDown), gets up (GetUp),
-- shakes a fist (Fist) and walks back to where it left its loop at
-- ReturnSpeed, and nothing touches it from lying down until it walks on.
-- Its loop waits for it: `clock` stops while it is busy, so it walks on
-- from where it left off.
--
-- Points are level, X and Z in park coordinates.

local Pedestrian = {}

export type Tuning = {
	SeeDistance: number,
	SeeTime: number,
	SeeSpeed: number, -- slower cars it doesn't bother about
	DiveRadius: number,
	NearMiss: number,
	HitRadius: number,
	HitHeight: number, -- a car's middle within this above or below its feet
	DiveTime: number,
	DiveDistance: number,
	DiveDown: number,
	FlopTime: number,
	FlopDistance: number,
	FlopDown: number,
	GetUp: number,
	Fist: number,
	ReturnSpeed: number,
	Cooldown: number,
}

-- Where it is on its loop while walking (Pedestrians.Pose).
export type Spot = {
	x: number,
	z: number,
	headingX: number,
	headingZ: number,
	road: boolean,
	toCurb: number,
}

-- A car's hull as the server sees it, whether the walker can see it, and
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

export type Mode = "walk" | "dive" | "flop"

export type State = {
	mode: Mode,
	since: number, -- on the server's clock, when the dive or flop began
	startX: number, -- where it began
	startZ: number,
	anchorX: number, -- where it left its loop, to walk back to
	anchorZ: number,
	dirX: number, -- the way it dives or is thrown, a level unit
	dirZ: number,
	delay: number, -- seconds its loop is behind the server's clock
	car: any?, -- the car it is diving from, until it pays or goes
	closest: number, -- the nearest that car has come
	payable: number, -- on the server's clock, when it can next pay a near miss
}

export type Phase = "walk" | "dive" | "flop" | "down" | "up" | "fist" | "back"

export type Where = {
	x: number,
	z: number,
	facingX: number,
	facingZ: number,
	phase: Phase,
	progress: number, -- through the phase, 0 to 1
}

export type Event = {
	kind: "dive" | "hit" | "nearMiss",
	car: any,
}

function Pedestrian.new(): State
	return {
		mode = "walk",
		since = 0,
		startX = 0,
		startZ = 0,
		anchorX = 0,
		anchorZ = 0,
		dirX = 1,
		dirZ = 0,
		delay = 0,
		car = nil,
		closest = math.huge,
		payable = -math.huge,
	}
end

local function moveTime(s: State, tuning: Tuning): number
	return if s.mode == "flop" then tuning.FlopTime else tuning.DiveTime
end

local function downTime(s: State, tuning: Tuning): number
	return if s.mode == "flop" then tuning.FlopDown else tuning.DiveDown
end

-- Where the dive or flop leaves it.
local function landing(s: State, tuning: Tuning): (number, number)
	local distance = if s.mode == "flop" then tuning.FlopDistance else tuning.DiveDistance
	return s.startX + s.dirX * distance, s.startZ + s.dirZ * distance
end

local function backTime(s: State, tuning: Tuning): number
	local x, z = landing(s, tuning)
	return math.sqrt((x - s.anchorX) ^ 2 + (z - s.anchorZ) ^ 2) / tuning.ReturnSpeed
end

-- Seconds from the start of a dive or flop until it walks on.
function Pedestrian.duration(s: State, tuning: Tuning): number
	if s.mode == "walk" then
		return 0
	end
	return moveTime(s, tuning) + downTime(s, tuning) + tuning.GetUp + tuning.Fist + backTime(s, tuning)
end

-- The time on its loop's clock (Pedestrians.at) at `now` on the server's:
-- stopped during a dive or flop, and on again after it even before the
-- server has stepped it back to walking.
function Pedestrian.clock(s: State, now: number, tuning: Tuning): number
	if s.mode == "walk" then
		return now - s.delay
	end
	local duration = Pedestrian.duration(s, tuning)
	if now < s.since + duration then
		return s.since - s.delay
	end
	return now - s.delay - duration
end

local function easeOut(p: number): number
	return 1 - (1 - p) * (1 - p)
end

local function smooth(p: number): number
	return p * p * (3 - 2 * p)
end

-- Where it is during a dive or flop, which way it faces, and what it is
-- doing. Walking, it is wherever its loop puts it: phase "walk".
function Pedestrian.where(s: State, now: number, tuning: Tuning): Where
	local t = now - s.since
	local move, down = moveTime(s, tuning), downTime(s, tuning)
	local back = backTime(s, tuning)
	local outX, outZ = landing(s, tuning)
	local function at(x: number, z: number, fx: number, fz: number, phase: Phase, progress: number): Where
		return { x = x, z = z, facingX = fx, facingZ = fz, phase = phase, progress = math.clamp(progress, 0, 1) }
	end
	if s.mode == "walk" or t >= move + down + tuning.GetUp + tuning.Fist + back then
		return at(s.anchorX, s.anchorZ, s.dirX, s.dirZ, "walk", 0)
	end
	-- A dive faces where it leaps; thrown, it faces back the way it came.
	local fx, fz = s.dirX, s.dirZ
	if s.mode == "flop" then
		fx, fz = -s.dirX, -s.dirZ
	end
	if t < move then
		local p = easeOut(t / move)
		return at(s.startX + (outX - s.startX) * p, s.startZ + (outZ - s.startZ) * p, fx, fz, s.mode, t / move)
	end
	t -= move
	if t < down then
		return at(outX, outZ, fx, fz, "down", t / down)
	end
	t -= down
	if t < tuning.GetUp then
		return at(outX, outZ, fx, fz, "up", t / tuning.GetUp)
	end
	t -= tuning.GetUp
	if t < tuning.Fist then
		return at(outX, outZ, -s.dirX, -s.dirZ, "fist", t / tuning.Fist)
	end
	t -= tuning.Fist
	local p = if back > 0 then t / back else 1
	local dx, dz = s.anchorX - outX, s.anchorZ - outZ
	local length = math.sqrt(dx * dx + dz * dz)
	if length > 1e-6 then
		fx, fz = dx / length, dz / length
	end
	local e = smooth(math.clamp(p, 0, 1))
	return at(outX + dx * e, outZ + dz * e, fx, fz, "back", p)
end

local function reaches(car: Car, x: number, z: number, y: number, tuning: Tuning): boolean
	return math.abs(car.y - y) <= tuning.HitHeight
		and (car.x - x) ^ 2 + (car.z - z) ^ 2 <= tuning.HitRadius * tuning.HitRadius
end

-- Seconds until the car passes nearest the spot, and how near, if it is a
-- car the walker would dive from.
local function threat(car: Car, spot: Spot, y: number, tuning: Tuning): number?
	if car.air or not car.visible or math.abs(car.y - y) > tuning.HitHeight then
		return nil
	end
	local speed2 = car.vx * car.vx + car.vz * car.vz
	if speed2 < tuning.SeeSpeed * tuning.SeeSpeed then
		return nil
	end
	local rx, rz = spot.x - car.x, spot.z - car.z
	if rx * rx + rz * rz > tuning.SeeDistance * tuning.SeeDistance then
		return nil
	end
	local t = (rx * car.vx + rz * car.vz) / speed2
	if t < 0 or t > tuning.SeeTime then
		return nil
	end
	local gx, gz = rx - car.vx * t, rz - car.vz * t
	if gx * gx + gz * gz >= tuning.DiveRadius * tuning.DiveRadius then
		return nil
	end
	return t
end

-- Knocked flat at (x, z) by `car`, now. Its loop's clock stays where it
-- stopped if it was already diving.
local function flop(s: State, car: Car, x: number, z: number, spot: Spot, now: number)
	if s.mode == "walk" then
		s.anchorX, s.anchorZ = x, z
	else
		s.delay += now - s.since
	end
	local speed = math.sqrt(car.vx * car.vx + car.vz * car.vz)
	local dx, dz = spot.headingX, spot.headingZ
	if speed >= 1 then
		dx, dz = car.vx / speed, car.vz / speed
	else
		local ax, az = x - car.x, z - car.z
		local away = math.sqrt(ax * ax + az * az)
		if away > 1e-6 then
			dx, dz = ax / away, az / away
		end
	end
	s.mode = "flop"
	s.since = now
	s.startX, s.startZ = x, z
	s.dirX, s.dirZ = dx, dz
	s.car = nil
end

local function dive(s: State, car: Car, spot: Spot, now: number)
	local dx, dz
	if spot.road and spot.toCurb ~= 0 then
		dx, dz = spot.headingX * spot.toCurb, spot.headingZ * spot.toCurb
	else
		local speed = math.sqrt(car.vx * car.vx + car.vz * car.vz)
		local nx, nz = -car.vz / speed, car.vx / speed
		local side = (spot.x - car.x) * nx + (spot.z - car.z) * nz
		local sign = if side < 0 then -1 else 1
		dx, dz = nx * sign, nz * sign
	end
	s.mode = "dive"
	s.since = now
	s.startX, s.startZ = spot.x, spot.z
	s.anchorX, s.anchorZ = spot.x, spot.z
	s.dirX, s.dirZ = dx, dz
	s.car = car.id
	s.closest = math.sqrt((car.x - spot.x) ^ 2 + (car.z - spot.z) ^ 2)
end

-- One step at `now` on the server's clock, with the walker at `spot` on
-- its loop (at Pedestrian.clock) and its feet `y` high. Returns what
-- happened, if anything.
function Pedestrian.step(s: State, spot: Spot, y: number, cars: { Car }, now: number, tuning: Tuning): Event?
	if s.mode ~= "walk" then
		local duration = Pedestrian.duration(s, tuning)
		if now < s.since + duration then
			local here = Pedestrian.where(s, now, tuning)
			if s.mode == "dive" and here.phase == "dive" then
				for _, car in cars do
					if reaches(car, here.x, here.z, y, tuning) then
						flop(s, car, here.x, here.z, spot, now)
						return { kind = "hit", car = car.id }
					end
				end
			end
			local id = s.car
			if s.mode == "dive" and id ~= nil then
				local tracked: Car? = nil
				for _, car in cars do
					if car.id == id then
						tracked = car
					end
				end
				if not tracked then
					s.car = nil
					return nil
				end
				local gap = math.sqrt((tracked.x - here.x) ^ 2 + (tracked.z - here.z) ^ 2)
				s.closest = math.min(s.closest, gap)
				if s.closest <= tuning.NearMiss and gap > tuning.NearMiss then
					s.car = nil
					if now >= s.payable then
						s.payable = now + tuning.Cooldown
						return { kind = "nearMiss", car = id }
					end
				end
			end
			return nil
		end
		s.delay += duration
		s.mode = "walk"
		s.car = nil
	end

	for _, car in cars do
		if reaches(car, spot.x, spot.z, y, tuning) then
			flop(s, car, spot.x, spot.z, spot, now)
			return { kind = "hit", car = car.id }
		end
	end
	local soonest: Car? = nil
	local soonestTime = math.huge
	for _, car in cars do
		local t = threat(car, spot, y, tuning)
		if t and t < soonestTime then
			soonest, soonestTime = car, t
		end
	end
	if soonest then
		dive(s, soonest, spot, now)
		return { kind = "dive", car = soonest.id }
	end
	return nil
end

return Pedestrian
