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
	return throttle * limit / wheelRadius, tuning.DriveTorque
end

-- Wheel spin that rolls without slipping at `forwardSpeed`. Used in the air so
-- the wheels already match the ground when the car lands.
function Drive.freeRoll(forwardSpeed: number, wheelRadius: number): number
	return forwardSpeed / wheelRadius
end

-- Front wheel angle in degrees. Full lock when slow, narrowing linearly to
-- `highSpeedFactor` of full lock at top speed.
function Drive.steerAngle(
	steer: number,
	speed: number,
	topSpeed: number,
	maxAngle: number,
	highSpeedFactor: number
): number
	local t = math.clamp(math.abs(speed) / topSpeed, 0, 1)
	return steer * maxAngle * (1 + (highSpeedFactor - 1) * t)
end

return Drive
