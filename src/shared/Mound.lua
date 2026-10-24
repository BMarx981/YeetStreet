--!strict
-- Mound (ModuleScript) -> ReplicatedStorage.Mound
-- A mound of dirt in Dino Valley that a car can drive up onto from any side:
-- a flat top `top` high, and round it rings, each a rounded rectangle
-- further out and lower than the last, easing in from the grass and easing
-- out at the top so there is no sharp bump at either end. Pure, see
-- InputAxes.

local Mound = {}

export type Point = {
	x: number,
	z: number,
}

-- How high ring `i` of `rings` is: ring 0 at the top's edge, `top` high,
-- and ring `rings` on the grass.
function Mound.height(i: number, rings: number, top: number): number
	return top * (1 + math.cos(math.pi * i / rings)) / 2
end

-- The points round a ring `out` from the top's edge, the top being `halfX`
-- by `halfZ` round its middle: `steps` + 1 points round each corner, going
-- counterclockwise in x, z from the +x, +z corner, so each ring's points
-- line up with the next ring's. At `out` 0 a corner's points are all the
-- corner itself.
function Mound.ring(halfX: number, halfZ: number, out: number, steps: number): { Point }
	local points: { Point } = {}
	local corners = { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } }
	for k, corner in corners do
		for s = 0, steps do
			local angle = (k - 1 + s / steps) * math.pi / 2
			table.insert(points, {
				x = corner[1] * halfX + out * math.cos(angle),
				z = corner[2] * halfZ + out * math.sin(angle),
			})
		end
	end
	return points
end

return Mound
