--!strict
-- Glide (ModuleScript) -> ReplicatedStorage.Glide
-- How the air pushes on a PlaneCar flying with its wings out. Pure, see
-- InputAxes.
--
-- The wings push back on air moving across them, and the fin on air moving
-- sideways, harder the faster the car flies, so falling turns into gliding
-- forward and the path bends toward wherever the nose points: pitch up to
-- climb, bank or yaw to turn. Together those pushes are capped at MaxAccel.
-- A little drag along the nose slows the glide.
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
	return ax, ay, -tuning.Drag * vz
end

return Glide
