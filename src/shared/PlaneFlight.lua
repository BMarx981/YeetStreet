--!strict
-- PlaneFlight (ModuleScript) -> ReplicatedStorage.PlaneFlight
-- Air control for a PlaneCar with its wings out. Pure, see InputAxes.
--
-- Instead of spinning the car, input sets the angle to hold: up and down
-- hold the nose MaxPitch above or below level, steering banks up to MaxBank
-- into the turn while the nose swings round, and with no input it flies
-- level and upright. So it can't flip over. Spin toward the held angle is
-- Gain per second for each radian off, up to the car's turn rate.
--
-- The car's attitude comes in as the heights of its look, right, and up
-- vectors (each dotted with up). Spin rates go out in the car's frame like
-- AirControl: x lifts the nose, y swings it left, z lifts the right side.

local PlaneFlight = {}

export type Tuning = {
	MaxPitch: number, -- radians
	MaxBank: number, -- radians
	Gain: number, -- spin per radian off the held angle, per second
	YawShare: number, -- of the turn rate, swinging the nose at full steer
}

function PlaneFlight.rates(
	lookUp: number,
	rightUp: number,
	upUp: number,
	pitchInput: number,
	steer: number,
	turnRate: number,
	tuning: Tuning
): (number, number, number)
	local pitch = math.asin(math.clamp(lookUp, -1, 1))
	local bank = math.atan2(rightUp, upUp)
	local x = math.clamp((pitchInput * tuning.MaxPitch - pitch) * tuning.Gain, -turnRate, turnRate)
	local z = math.clamp((-steer * tuning.MaxBank - bank) * tuning.Gain, -turnRate, turnRate)
	return x, -steer * turnRate * tuning.YawShare, z
end

return PlaneFlight
