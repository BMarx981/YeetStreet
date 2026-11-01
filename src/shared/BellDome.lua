--!strict
-- BellDome (ModuleScript) -> ReplicatedStorage.BellDome
-- A low dome a car can drive over: one line spun round its middle, flat where it
-- leaves the ground and flat again on top, steepest halfway. Its steepest slope
-- is pi * height / (2 * radius). Pure, see InputAxes.

local BellDome = {}

export type Point = { R: number, Y: number }

-- The line from the rim (R = radius, Y = 0) in to the top (R = 0, Y = height).
function BellDome.profile(radius: number, height: number, rows: number): { Point }
	local points: { Point } = {}
	for i = 0, rows do
		local r = radius * (1 - i / rows)
		table.insert(points, { R = r, Y = height * (1 + math.cos(math.pi * r / radius)) / 2 })
	end
	return points
end

return BellDome
