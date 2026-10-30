--!strict
-- GarageRing (ModuleScript) -> ReplicatedStorage.GarageRing
-- The shape of the dashed ring painted around a garage. Pure, see InputAxes.

local GarageRing = {}

export type Dash = {
	x: number, -- middle of the dash, from the garage
	z: number,
	alongX: number, -- which way the dash runs, unit length
	alongZ: number,
	length: number,
}

-- `count` dashes evenly around a circle. `share` is how much of the spacing
-- each dash fills, the rest being the gap to the next one.
function GarageRing.dashes(radius: number, count: number, share: number): { Dash }
	local dashes = {}
	for i = 0, count - 1 do
		local angle = 2 * math.pi * i / count
		table.insert(dashes, {
			x = radius * math.cos(angle),
			z = radius * math.sin(angle),
			alongX = -math.sin(angle),
			alongZ = math.cos(angle),
			length = share * 2 * math.pi * radius / count,
		})
	end
	return dashes
end

return GarageRing
