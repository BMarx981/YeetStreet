--!strict
-- Swing (ModuleScript) -> ReplicatedStorage.Swing
-- A giant swing: a seat hanging Length below a pivot, swinging about the
-- pivot's X axis. Pure, see InputAxes.
--
-- Points are in the pivot's space: X along the beam, Y up, and -Z forward
-- (the pivot's LookVector). The angle is 0 hanging straight down and grows
-- as the seat swings forward; speed is how fast the angle changes, in radians
-- per second.
--
-- Gravity swings it like a pendulum. Left alone it keeps swinging at
-- BaseAngle: whenever it swings lower, a push along its motion tops it up. A
-- rider pumps with `pump` from -1 to 1, positive pushing forward: pumping
-- with the motion swings it higher, against it slows it. High enough, it goes
-- all the way over the top. Damping slowly takes back what pumping added, and
-- the seat never moves faster than MaxSpeed.
--
-- A car riding a seat drives around on it like on the ground, only slower
-- (drive): gas pumps the way its nose points along the swing (pump), so
-- driving back and forth in time with the swing swings it higher. Driving
-- past an edge takes it off the seat.

local Swing = {}

export type Tuning = {
	Gravity: number,
	Length: number, -- from the pivot to the seat's top face
	BaseAngle: number, -- degrees
	BaseDrive: number, -- radians per second squared
	PumpAccel: number, -- radians per second squared at full pump
	Damping: number, -- per second
	MaxSpeed: number, -- studs per second at the seat
	SeatWidth: number, -- along X
	SeatDepth: number, -- along the swing
	HoldHeight: number, -- a hull up to this far above the seat's top face is on it
	DriveSpeed: number, -- studs per second a car drives on the seat
	DriveAccel: number,
	SteerRate: number, -- radians per second of turn at DriveSpeed
}

export type State = {
	angle: number, -- radians, from -pi to pi
	speed: number,
}

-- A car on a seat, in the seat's space (see toSeat): its hull's x and z,
-- its heading (0 nose forward, positive turned left), and its speed along
-- its nose.
export type Rider = {
	x: number,
	z: number,
	yaw: number,
	speed: number,
}

local SUBSTEP = 1 / 120
local TAU = 2 * math.pi

function Swing.new(angle: number): State
	return { angle = angle, speed = 0 }
end

-- Gravity over length: the swing's angular acceleration per unit of sin(angle).
local function pull(tuning: Tuning): number
	return tuning.Gravity / tuning.Length
end

-- Energy per unit of moment of inertia, 0 hanging still.
local function energy(s: State, tuning: Tuning): number
	return 0.5 * s.speed * s.speed + pull(tuning) * (1 - math.cos(s.angle))
end

local function wrap(angle: number): number
	return (angle + math.pi) % TAU - math.pi
end

-- Slows a seat moving faster than MaxSpeed down to it.
function Swing.limit(s: State, tuning: Tuning)
	local most = 0.5 * (tuning.MaxSpeed / tuning.Length) ^ 2
	if energy(s, tuning) <= most then
		return
	end
	local height = pull(tuning) * (1 - math.cos(s.angle))
	local left = math.max(most - height, 0)
	s.speed = (if s.speed < 0 then -1 else 1) * math.sqrt(2 * left)
end

function Swing.step(s: State, pump: number, dt: number, tuning: Tuning)
	local k = pull(tuning)
	local base = k * (1 - math.cos(math.rad(tuning.BaseAngle)))
	local steps = math.max(math.ceil(dt / SUBSTEP), 1)
	local h = dt / steps
	for _ = 1, steps do
		local accel = -k * math.sin(s.angle) - tuning.Damping * s.speed + tuning.PumpAccel * pump
		if energy(s, tuning) < base then
			accel += tuning.BaseDrive * (if s.speed < 0 then -1 else 1)
		end
		s.speed += accel * h
		s.angle = wrap(s.angle + s.speed * h)
		Swing.limit(s, tuning)
	end
end

-- The center of the seat's top face at this angle, as (y, z).
function Swing.seatPoint(angle: number, tuning: Tuning): (number, number)
	return -tuning.Length * math.cos(angle), -tuning.Length * math.sin(angle)
end

-- A point in the seat's own space: x across it, y up off its top face
-- (toward the pivot), z along it, forward negative.
function Swing.toSeat(s: State, x: number, y: number, z: number, tuning: Tuning): (number, number, number)
	local c, sn = math.cos(s.angle), math.sin(s.angle)
	return x, c * y + sn * z + tuning.Length, -sn * y + c * z
end

-- Whether a hull at this point sits on the seat: over its top face and no
-- more than HoldHeight above it. `slack` grows the footprint by that many
-- studs every way, for a seat known only roughly.
function Swing.onSeat(s: State, x: number, y: number, z: number, slack: number, tuning: Tuning): boolean
	local sx, sy, sz = Swing.toSeat(s, x, y, z, tuning)
	return math.abs(sx) <= tuning.SeatWidth / 2 + slack
		and math.abs(sz) <= tuning.SeatDepth / 2 + slack
		and sy >= -slack
		and sy <= tuning.HoldHeight + slack
end

-- Drives a car on the seat one step with `throttle` and `steer` from -1 to
-- 1, positive steer turning right. Returns false once the hull's center is
-- past an edge: it drove off.
function Swing.drive(r: Rider, throttle: number, steer: number, dt: number, tuning: Tuning): boolean
	local change = tuning.DriveAccel * dt
	r.speed += math.clamp(throttle * tuning.DriveSpeed - r.speed, -change, change)
	r.yaw -= steer * tuning.SteerRate * (r.speed / tuning.DriveSpeed) * dt
	r.x -= math.sin(r.yaw) * r.speed * dt
	r.z -= math.cos(r.yaw) * r.speed * dt
	return math.abs(r.x) <= tuning.SeatWidth / 2 and math.abs(r.z) <= tuning.SeatDepth / 2
end

-- How hard the rider pumps the swing, from -1 to 1: gas along the way its
-- nose points along the swing.
function Swing.pump(r: Rider, throttle: number): number
	return throttle * math.cos(r.yaw)
end

return Swing
