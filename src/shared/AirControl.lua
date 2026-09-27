--!strict
-- AirControl (ModuleScript) -> ReplicatedStorage.AirControl
-- Maps flight input to spin rates in the chassis frame. Pure, see InputAxes.
--
-- Chassis-local axes (the car faces -Z):
--   x  pitch, positive lifts the nose
--   y  yaw, positive swings the nose left
--   z  roll, positive lifts the right side

local AirControl = {}

export type Scales = {
	pitch: number,
	yaw: number,
	roll: number,
	invertPitch: boolean,
}

-- Gas tips the nose down and brake tips it up, steer yaws, roll rolls.
-- Positive steer and roll mean right.
function AirControl.targetRates(
	steer: number,
	throttle: number,
	roll: number,
	turnRate: number,
	scales: Scales
): (number, number, number)
	local pitchSign = if scales.invertPitch then 1 else -1
	return pitchSign * throttle * turnRate * scales.pitch,
		-steer * turnRate * scales.yaw,
		-roll * turnRate * scales.roll
end

-- One axis of spin for one frame. With input, move toward the target by at most
-- accel * dt. Without input, keep the spin and bleed it off slowly, so a flip
-- carries through after the stick is released.
function AirControl.stepAxis(
	current: number,
	target: number,
	hasInput: boolean,
	accel: number,
	damping: number,
	dt: number
): number
	if not hasInput then
		return current * math.exp(-damping * dt)
	end
	local maxStep = accel * dt
	return current + math.clamp(target - current, -maxStep, maxStep)
end

return AirControl
