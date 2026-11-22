--!strict
-- Tnt (ModuleScript) -> ReplicatedStorage.Tnt
-- The Scrapyard's TNT barrel field (Tuning.Scrapyard.Tnt). Barrels stand on
-- a grid Spacing apart across the field, each nudged up to Jitter from its
-- spot by a seeded Rng, so the field is the same on every server. A car whose
-- hull comes within Trigger of a barrel sets it off; the blast throws every
-- car within BlastRadius up and away from it, less further out; and it sets
-- off every barrel within ChainRadius. Places are studs from the field's
-- middle (x, z) or from the barrel (dx, dz), and up from the floor. Pure,
-- see InputAxes. The caller passes Rng.new(Seed) to layout.

local Tnt = {}

-- Same as Rng.Rng, declared here so this module needs no require.
type Rng = {
	next: () -> number,
	range: (low: number, high: number) -> number,
	int: (low: number, high: number) -> number,
}

export type Config = {
	Width: number,
	Depth: number,
	Spacing: number,
	Jitter: number,
	Radius: number,
	Height: number,
	Trigger: number,
	BlastRadius: number,
	Up: number,
	Out: number,
	MinShare: number, -- of Up and Out, at the edge of the blast
	ChainRadius: number,
}

export type Spot = { x: number, z: number }

-- Every barrel's spot, row by row.
function Tnt.layout(c: Config, rng: Rng): { Spot }
	local across = math.floor(c.Width / c.Spacing)
	local deep = math.floor(c.Depth / c.Spacing)
	local spots: { Spot } = {}
	for row = 1, deep do
		for column = 1, across do
			table.insert(spots, {
				x = (column - (across + 1) / 2) * c.Spacing + rng.range(-c.Jitter, c.Jitter),
				z = (row - (deep + 1) / 2) * c.Spacing + rng.range(-c.Jitter, c.Jitter),
			})
		end
	end
	return spots
end

-- Whether a car's hull at (dx, dz) from a barrel, `y` up from the floor,
-- sets it off.
function Tnt.touches(c: Config, dx: number, y: number, dz: number): boolean
	local reach = c.Radius + c.Trigger
	return dx * dx + dz * dz <= reach * reach and y <= c.Height + c.Trigger
end

-- The velocity a blast throws a car at (dx, dz) from the barrel, or nil out
-- of its reach.
function Tnt.blast(c: Config, dx: number, dz: number): (number?, number?, number?)
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance > c.BlastRadius then
		return nil, nil, nil
	end
	local share = c.MinShare + (1 - c.MinShare) * (1 - distance / c.BlastRadius)
	local outX, outZ = 0, 0
	if distance > 1e-6 then
		outX, outZ = dx / distance, dz / distance
	end
	return outX * c.Out * share, c.Up * share, outZ * c.Out * share
end

-- The barrels a blast at barrel `index` sets off.
function Tnt.chained(c: Config, spots: { Spot }, index: number): { number }
	local from = spots[index]
	local near = {}
	for i, spot in spots do
		local dx, dz = spot.x - from.x, spot.z - from.z
		if i ~= index and dx * dx + dz * dz <= c.ChainRadius * c.ChainRadius then
			table.insert(near, i)
		end
	end
	return near
end

return Tnt
