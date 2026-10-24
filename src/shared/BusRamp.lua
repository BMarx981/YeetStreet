--!strict
-- BusRamp (ModuleScript) -> ReplicatedStorage.BusRamp
-- The mound round an old safari bus in Dino Valley, lying on its side sunk
-- in dirt with its upturned side `top` high, so a car can drive up onto it
-- from any side. Seen from above, the mound is rings round the bus's side,
-- each a rounded rectangle further out and lower than the last, easing in
-- from the grass and easing out at the top so there is no sharp bump at
-- either end. Pure, see InputAxes.

local BusRamp = {}

export type Point = {
	x: number,
	z: number,
}

-- How high ring `i` of `rings` is: ring 0 at the bus, `top` high, and ring
-- `rings` on the grass.
function BusRamp.height(i: number, rings: number, top: number): number
	return top * (1 + math.cos(math.pi * i / rings)) / 2
end

-- The points round a ring `out` from the bus's side, which is `halfX` by
-- `halfZ` round its middle: `steps` + 1 points round each corner, going
-- counterclockwise in x, z from the +x, +z corner, so each ring's points
-- line up with the next ring's. At `out` 0 a corner's points are all the
-- corner itself.
function BusRamp.ring(halfX: number, halfZ: number, out: number, steps: number): { Point }
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

return BusRamp
