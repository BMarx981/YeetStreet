--!strict
-- HeliFlight (ModuleScript) -> ReplicatedStorage.HeliFlight
-- How a HeliCar with its rotor out moves through the air. Pure, see InputAxes.
--
-- The rotor carries the car's weight, so it hovers at the height it was left
-- at. Lift input climbs and sinks. Otherwise it drives like a car on the
-- ground: gas up to its top speed, brake then reverse, no sideways slide, and
-- a coast to a stop with no input. Jets still push along the nose as usual,
-- past top speed, and nothing here holds them back.
--
-- Speeds are studs per second, and the pushes back are acceleration, so the
-- caller multiplies by mass. `vertical` leaves out what holds up the weight.

local HeliFlight = {}

export type Tuning = {
	UpSpeed: number,
	DownSpeed: number,
	HoldGain: number, -- climb speed per stud off the held height
	ClimbGain: number, -- push per stud per second off the wanted climb speed
	MaxVertical: number, -- cap on that push
	Accel: number, -- gas, up to top speed
	Brake: number, -- on top of the car's Brakes upgrade
	Coast: number, -- slowing down with no input, or past top speed
	SideGrip: number, -- cap on the push against sideways slide
	YawShare: number, -- of the car's turn rate, turning at full steer
	ReverseFraction: number, -- reverse top speed as a fraction of top speed
	BrakeSpeed: number, -- below this speed, brake turns into reverse
}

-- A push that reaches `target` from `speed` within this step if it can.
local function toward(speed: number, target: number, limit: number, dt: number): number
	return math.clamp((target - speed) / dt, -limit, limit)
end

-- `lift` is -1..1, `heldOff` is how far the held height is above the car, and
-- `upSpeed` is the car's climb speed now.
function HeliFlight.vertical(lift: number, heldOff: number, upSpeed: number, tuning: Tuning): number
	local want
	if lift > 0 then
		want = lift * tuning.UpSpeed
	elseif lift < 0 then
		want = lift * tuning.DownSpeed
	else
		want = math.clamp(heldOff * tuning.HoldGain, -tuning.DownSpeed, tuning.UpSpeed)
	end
	return math.clamp((want - upSpeed) * tuning.ClimbGain, -tuning.MaxVertical, tuning.MaxVertical)
end

-- The push along the nose, as Drive.motor and Drive.brakePush do on the ground.
function HeliFlight.forward(
	throttle: number,
	speed: number,
	topSpeed: number,
	brakePower: number,
	jets: boolean,
	dt: number,
	tuning: Tuning
): number
	if throttle * speed < 0 and math.abs(speed) > tuning.BrakeSpeed then
		return throttle * (tuning.Brake + brakePower)
	end
	local limit = if throttle > 0 then topSpeed else topSpeed * tuning.ReverseFraction
	local target = throttle * limit
	if math.abs(speed) > math.abs(target) then
		return if jets then 0 else toward(speed, target, tuning.Coast, dt)
	end
	return toward(speed, target, tuning.Accel, dt)
end

-- The push across the car, against any sideways slide.
function HeliFlight.side(speed: number, dt: number, tuning: Tuning): number
	return toward(speed, 0, tuning.SideGrip, dt)
end

-- How fast full steer turns the nose, radians per second. Fast, that is only
-- as tight as the side grip can bend the car's path, so it turns like tyres
-- on a road instead of spinning out.
function HeliFlight.yawRate(speed: number, turnRate: number, tuning: Tuning): number
	local rate = turnRate * tuning.YawShare
	local moving = math.abs(speed)
	return if moving > 1e-3 then math.min(rate, tuning.SideGrip / moving) else rate
end

return HeliFlight
