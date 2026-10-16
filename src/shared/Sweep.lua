--!strict
-- Sweep (ModuleScript) -> ReplicatedStorage.Sweep
-- Whether something moving in a straight line this step passed through a box,
-- so a fast car cannot skip past a thin prop between two steps. Pure, see
-- InputAxes.

local Sweep = {}

-- Narrows the part of the path [tMin, tMax] that lies inside the box along one
-- axis. `a` is where the path starts, `d` how far it moves, `h` the box's half
-- size. Returns tMin > tMax when the path misses.
local function slab(a: number, d: number, h: number, tMin: number, tMax: number): (number, number)
	if math.abs(d) < 1e-9 then
		if math.abs(a) > h then
			return 1, 0
		end
		return tMin, tMax
	end
	local t1, t2 = (-h - a) / d, (h - a) / d
	if t1 > t2 then
		t1, t2 = t2, t1
	end
	return math.max(tMin, t1), math.min(tMax, t2)
end

-- The path from a to b against a box centered on the origin with half sizes
-- hx, hy, hz. Points are in the box's own space.
function Sweep.hitsBox(
	ax: number,
	ay: number,
	az: number,
	bx: number,
	by: number,
	bz: number,
	hx: number,
	hy: number,
	hz: number
): boolean
	local tMin, tMax = slab(ax, bx - ax, hx, 0, 1)
	tMin, tMax = slab(ay, by - ay, hy, tMin, tMax)
	tMin, tMax = slab(az, bz - az, hz, tMin, tMax)
	return tMin <= tMax
end

return Sweep
