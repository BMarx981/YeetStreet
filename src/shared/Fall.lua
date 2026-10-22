--!strict
-- Fall (ModuleScript) -> ReplicatedStorage.Fall
-- Dropping something so it lands on a target below it, such as a coconut
-- shaken down onto the car that hit its tree. Pure, see InputAxes.

local Fall = {}

-- The sideways speed (vx, vz) to let go with, from rest, so a drop lands on
-- a target `dx`, `dz` across and `drop` studs below, and how long it falls.
-- A target level with it or above gets no push.
function Fall.toward(dx: number, dz: number, drop: number, gravity: number): (number, number, number)
	if drop <= 0 then
		return 0, 0, 0
	end
	local time = math.sqrt(2 * drop / gravity)
	return dx / time, dz / time, time
end

return Fall
