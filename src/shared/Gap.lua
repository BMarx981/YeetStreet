--!strict
-- Gap (ModuleScript) -> ReplicatedStorage.Gap
-- Gaps: jumps that pay a bonus for taking off on one side of something and
-- coming down on the far side, such as across the skate park's bowl. Pure,
-- see InputAxes.
--
-- A gap is a ring around a center, seen from above, from `inner` to `outer`
-- studs out. A run clears it when it takes off inside the ring and ends
-- inside the ring at least `minAngle` degrees around from there. It must end
-- landed or crashed: coming down hard on the far side still made it across.

local Gap = {}

export type Gap = {
	name: string,
	x: number,
	z: number,
	inner: number,
	outer: number,
	minAngle: number,
}

-- The parts of a RunTracker result a gap needs.
export type Run = {
	ending: string,
	launchX: number,
	launchZ: number,
	endX: number,
	endZ: number,
}

-- Whether the point is inside the ring, and where it is from the center.
local function inRing(gap: Gap, x: number, z: number): (boolean, number, number)
	local dx, dz = x - gap.x, z - gap.z
	local out = math.sqrt(dx * dx + dz * dz)
	return out >= gap.inner and out <= gap.outer, dx, dz
end

function Gap.cleared(gap: Gap, run: Run): boolean
	if run.ending ~= "landed" and run.ending ~= "crashed" then
		return false
	end
	local fromRing, ax, az = inRing(gap, run.launchX, run.launchZ)
	local toRing, bx, bz = inRing(gap, run.endX, run.endZ)
	if not (fromRing and toRing) then
		return false
	end
	local cos = (ax * bx + az * bz) / (math.sqrt(ax * ax + az * az) * math.sqrt(bx * bx + bz * bz))
	return cos <= math.cos(math.rad(gap.minAngle)) + 1e-9
end

-- The names of every gap the run cleared.
function Gap.find(gaps: { Gap }, run: Run): { string }
	local names: { string } = {}
	for _, gap in gaps do
		if Gap.cleared(gap, run) then
			table.insert(names, gap.name)
		end
	end
	return names
end

return Gap
