--!strict
-- Scatter (ModuleScript) -> ReplicatedStorage.Scatter
-- Spots for things dotted about a park, such as trees, seen from above:
-- seeded random points inside a rectangle, at least a gap apart, and clear
-- of keep-out lines (a line with a radius, such as a ride's path; one with
-- no length is a circle). Pure, see InputAxes. The caller passes
-- Rng.new(seed).

local Scatter = {}

-- Same as Rng.Rng, declared here so this module needs no require.
type Rng = {
	next: () -> number,
	range: (low: number, high: number) -> number,
	int: (low: number, high: number) -> number,
}

export type Rect = {
	MinX: number,
	MaxX: number,
	MinZ: number,
	MaxZ: number,
}

export type Line = {
	AX: number,
	AZ: number,
	BX: number,
	BZ: number,
	Radius: number,
}

export type Point = {
	x: number,
	z: number,
}

-- Tries for each point asked for before giving up on the rest.
local TRIES = 30

-- How far the point is from the nearest point on the line.
function Scatter.distanceTo(line: Line, x: number, z: number): number
	local dx, dz = line.BX - line.AX, line.BZ - line.AZ
	local lengthSquared = dx * dx + dz * dz
	local t = if lengthSquared > 0
		then math.clamp(((x - line.AX) * dx + (z - line.AZ) * dz) / lengthSquared, 0, 1)
		else 0
	local nearX, nearZ = line.AX + dx * t, line.AZ + dz * t
	return math.sqrt((x - nearX) ^ 2 + (z - nearZ) ^ 2)
end

-- Up to `count` points, fewer if the rectangle fills up first.
function Scatter.points(rng: Rng, count: number, rect: Rect, gap: number, keepOut: { Line }): { Point }
	local points: { Point } = {}
	local tries = 0
	while #points < count and tries < count * TRIES do
		tries += 1
		local x, z = rng.range(rect.MinX, rect.MaxX), rng.range(rect.MinZ, rect.MaxZ)
		local clear = true
		for _, line in keepOut do
			if Scatter.distanceTo(line, x, z) < line.Radius then
				clear = false
				break
			end
		end
		if clear then
			for _, p in points do
				if (p.x - x) ^ 2 + (p.z - z) ^ 2 < gap * gap then
					clear = false
					break
				end
			end
		end
		if clear then
			table.insert(points, { x = x, z = z })
		end
	end
	return points
end

return Scatter
