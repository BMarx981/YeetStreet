--!strict
-- Righting (ModuleScript) -> ReplicatedStorage.Righting
-- Flips a car lying on its roof or side back onto its wheels where it lies,
-- instead of leaving it stuck. Pure, see InputAxes. Vectors are passed as
-- world space components.

local Righting = {}

export type Tuning = {
	StartUpY: number,
	EndUpY: number,
	LandWheels: number,
	Rate: number,
	SlowAngle: number,
}

-- On its roof or side: no wheels down, tipped past StartUpY, and the ground
-- close below the hull.
function Righting.lying(wheelsDown: number, upY: number, groundClose: boolean, tuning: Tuning): boolean
	return wheelsDown == 0 and upY < tuning.StartUpY and groundClose
end

-- Whether to keep righting this step. Starts when lying and holds until the
-- car is upright or its wheels are down, so it does not drop back halfway.
function Righting.step(righting: boolean, lying: boolean, wheelsDown: number, upY: number, tuning: Tuning): boolean
	if lying then
		return true
	end
	if not righting then
		return false
	end
	return wheelsDown < tuning.LandWheels and upY < tuning.EndUpY
end

-- World angular velocity that turns the car's up vector toward world up the
-- short way, keeping its heading. Full Rate when far over, easing off inside
-- SlowAngle (radians) of upright. Flat on its roof, any level axis would do,
-- so it rolls about the nose.
function Righting.rate(
	upX: number,
	upY: number,
	upZ: number,
	lookX: number,
	lookY: number,
	lookZ: number,
	tuning: Tuning
): (number, number, number)
	local angle = math.acos(math.clamp(upY, -1, 1))
	local speed = tuning.Rate * math.min(angle / tuning.SlowAngle, 1)
	-- up x worldUp, which turns up toward worldUp.
	local axisX, axisZ = -upZ, upX
	local length = math.sqrt(axisX * axisX + axisZ * axisZ)
	if length < 1e-3 then
		if upY > 0 then
			return 0, 0, 0
		end
		return lookX * speed, lookY * speed, lookZ * speed
	end
	return axisX / length * speed, 0, axisZ / length * speed
end

return Righting
