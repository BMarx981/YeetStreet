--!strict
-- Drive (ModuleScript) -> ReplicatedStorage.Drive
-- Ground driving: wheel motor targets and steering angle. Pure, see InputAxes.

local Drive = {}

export type Tuning = {
	DriveTorque: number,
	BrakeTorque: number,
	CoastTorque: number,
	ReverseFraction: number,
	BrakeSpeed: number,
}

-- Returns the wheel spin to aim for (radians per second, positive rolls the car
-- forward) and the motor torque allowed to get there. Pressing against the
-- direction of travel brakes; once nearly stopped, brake becomes reverse.
-- When the car already goes faster than the throttle asks for (jets), the
-- wheels roll free instead of being held back, so they keep their grip.
function Drive.motor(
	throttle: number,
	forwardSpeed: number,
	topSpeed: number,
	wheelRadius: number,
	tuning: Tuning
): (number, number)
	if throttle == 0 then
		return 0, tuning.CoastTorque
	end
	if throttle * forwardSpeed < 0 and math.abs(forwardSpeed) > tuning.BrakeSpeed then
		return 0, tuning.BrakeTorque
	end
	local limit = if throttle > 0 then topSpeed else topSpeed * tuning.ReverseFraction
	local target = throttle * limit
	if math.abs(forwardSpeed) > math.abs(target) then
		return Drive.freeRoll(forwardSpeed, wheelRadius), tuning.CoastTorque
	end
	return target / wheelRadius, tuning.DriveTorque
end

-- The Brakes upgrade's push on the car, as acceleration along the nose
-- (positive is forward). It works with the wheel brake from `motor` whenever
-- that brakes, and since it pushes the car itself and not the tyres, it still
-- slows a car that is already skidding. A part press pushes part as hard.
function Drive.brakePush(throttle: number, forwardSpeed: number, brakePower: number, tuning: Tuning): number
	if throttle * forwardSpeed >= 0 or math.abs(forwardSpeed) <= tuning.BrakeSpeed then
		return 0
	end
	return throttle * brakePower
end

-- Wheel spin that rolls without slipping at `forwardSpeed`. Used in the air so
-- the wheels already match the ground when the car lands.
function Drive.freeRoll(forwardSpeed: number, wheelRadius: number): number
	return forwardSpeed / wheelRadius
end

-- Front wheel angle in degrees. Full lock when slow, narrowing linearly to
-- `highSpeedFactor` of full lock at top speed. It is also capped so the turn
-- never asks for more sideways acceleration than `maxLateral` (studs/s^2),
-- using a = speed^2 * tan(angle) / wheelbase. Past that the tires slide, and
-- the tail steps out.
function Drive.steerAngle(
	steer: number,
	speed: number,
	topSpeed: number,
	maxAngle: number,
	highSpeedFactor: number,
	maxLateral: number,
	wheelbase: number
): number
	local t = math.clamp(math.abs(speed) / topSpeed, 0, 1)
	local angle = steer * maxAngle * (1 + (highSpeedFactor - 1) * t)
	local limit = math.deg(math.atan(maxLateral * wheelbase / (speed * speed)))
	return math.clamp(angle, -limit, limit)
end

return Drive
