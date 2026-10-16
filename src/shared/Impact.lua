--!strict
-- Impact (ModuleScript) -> ReplicatedStorage.Impact
-- Names the part of the car a hit landed on. Touched events do not report
-- force, so a hit is measured as the change in the car's velocity between
-- steps that gravity does not explain (CarSensor). Pure, see InputAxes.

local Impact = {}

export type Slot = "nose" | "tail" | "roof" | "underside" | "sides"

-- The slot a velocity change came from, given in the car's own space (nose
-- toward -Z). A hit pushes the car away from what it hit, so a push toward +Z
-- came from the nose, and a push up came from below.
function Impact.slot(x: number, y: number, z: number): Slot
	local ax, ay, az = math.abs(x), math.abs(y), math.abs(z)
	if ay >= ax and ay >= az then
		return if y > 0 then "underside" else "roof"
	elseif az >= ax then
		return if z > 0 then "nose" else "tail"
	end
	return "sides"
end

return Impact
