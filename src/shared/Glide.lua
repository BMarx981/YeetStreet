--!strict
-- Glide (ModuleScript) -> ReplicatedStorage.Glide
-- How the air pushes on a PlaneCar flying with its wings out, and how hard
-- its engine pushes. Pure, see InputAxes.
--
-- The wings push back on air moving across them, and the fin on air moving
-- sideways, harder the faster the car flies, so falling turns into gliding
-- forward and the path bends toward wherever the nose points: pitch up to
-- climb, bank or yaw to turn. Together those pushes are capped at MaxAccel.
-- The wings also lift by Camber times the forward speed squared, up to
-- MaxCamber, so going fast enough with the nose level takes off and climbs.
-- A little drag along the nose slows it.
--
-- Velocities and pushes are in the car's frame, studs per second: x right,
-- y up, z back (the nose is -z). Pushes are acceleration, so the caller
-- multiplies by mass.

local Glide = {}

export type Tuning = {
	Lift: number, -- push across the wings per unit of speed times speed across
	Side: number, -- the same for the fin, sideways
	Drag: number, -- along the nose, per second
	MaxAccel: number, -- cap on the wings' and fin's push together
	Camber: number, -- lift per forward speed squared
	MaxCamber: number, -- cap on that lift
}

function Glide.accel(vx: number, vy: number, vz: number, tuning: Tuning): (number, number, number)
	local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
	local ax = -tuning.Side * speed * vx
	local ay = -tuning.Lift * speed * vy
	local across = math.sqrt(ax * ax + ay * ay)
	if across > tuning.MaxAccel then
		local scale = tuning.MaxAccel / across
		ax *= scale
		ay *= scale
	end
	local forward = math.max(-vz, 0)
	ay += math.min(tuning.Camber * forward * forward, tuning.MaxCamber)
	return ax, ay, -tuning.Drag * vz
end

-- The engine's push along the nose: `power` from a standstill, fading to
-- nothing at `topSpeed` going forward.
function Glide.thrust(power: number, forwardSpeed: number, topSpeed: number): number
	return power * math.clamp(1 - forwardSpeed / topSpeed, 0, 1)
end

return Glide
