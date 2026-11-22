--!strict
-- Junk (ModuleScript) -> ReplicatedStorage.Junk
-- Where the Scrapyard's loose junk lies, from a seeded Rng so it is the same
-- on every server. A mound is an oval heap, RadiusAcross by RadiusAlong and
-- Height tall in the middle, sloping to nothing at its edge; its pieces are
-- spread through it, each in one of Sectors slices round the middle, so a
-- car hitting one side bursts only that side (ScrapyardAlley's junk pile).
-- A flank is the sloped side of Scrap Mountain: a triangle from the ramp's
-- edge, which climbs `rise` over `length`, down to the ground `width` out
-- at the top (ScrapyardMountain). A stack is a tower of crushed cars, a little
-- askew (ScrapyardStacks). Places are studs: x across, z along, y up.
-- Pure, see InputAxes. The caller passes Rng.new(seed).

local Junk = {}

-- Same as Rng.Rng, declared here so this module needs no require.
type Rng = {
	next: () -> number,
	range: (low: number, high: number) -> number,
	int: (low: number, high: number) -> number,
}

export type Mound = {
	RadiusAcross: number,
	RadiusAlong: number,
	Height: number,
	Pieces: number,
	Sectors: number,
	Kinds: { string },
}

export type Piece = {
	kind: string,
	x: number,
	y: number,
	z: number,
	yaw: number, -- degrees
	tilt: number, -- degrees
	sector: number,
}

local function piece(kinds: { string }, rng: Rng, x: number, y: number, z: number, sector: number): Piece
	return {
		kind = kinds[rng.int(1, #kinds)],
		x = x,
		y = y,
		z = z,
		yaw = rng.range(0, 360),
		tilt = rng.range(-30, 30),
		sector = sector,
	}
end

export type Stack = {
	MinCars: number,
	MaxCars: number,
	CarHeight: number,
	Wobble: number, -- studs each car may sit off the stack's middle
	Turn: number, -- degrees each car above the bottom may be turned from it
}

-- A stack of crushed cars, bottom first, each lying flat on the one below.
function Junk.stack(c: Stack, rng: Rng): { Piece }
	local cars: { Piece } = {}
	local base = rng.range(0, 360)
	for i = 1, rng.int(c.MinCars, c.MaxCars) do
		table.insert(cars, {
			kind = "Car",
			x = rng.range(-c.Wobble, c.Wobble),
			y = (i - 1) * c.CarHeight,
			z = rng.range(-c.Wobble, c.Wobble),
			yaw = if i == 1 then base else base + rng.range(-c.Turn, c.Turn),
			tilt = 0,
			sector = 1,
		})
	end
	return cars
end

-- Every piece of a mound round its middle on the ground.
function Junk.mound(c: Mound, rng: Rng): { Piece }
	local pieces: { Piece } = {}
	for _ = 1, c.Pieces do
		local r = math.sqrt(rng.next()) -- even over the oval
		local angle = rng.range(0, 2 * math.pi)
		local y = rng.range(0, c.Height * (1 - r * r))
		local sector = math.min(math.floor(angle / (2 * math.pi) * c.Sectors) + 1, c.Sectors)
		table.insert(
			pieces,
			piece(c.Kinds, rng, c.RadiusAcross * r * math.cos(angle), y, c.RadiusAlong * r * math.sin(angle), sector)
		)
	end
	return pieces
end

-- The flank's height `along` the ramp from its foot and `out` from its
-- edge, or nil off the flank.
function Junk.flankHeight(along: number, out: number, length: number, width: number, rise: number): number?
	if along < 0 or along > length or out < 0 then
		return nil
	end
	local t = along / length
	if out > width * t + 1e-9 then
		return nil
	end
	return rise * t - rise * out / width
end

-- `count` pieces lying on a flank, x out from the ramp's edge and z along it.
function Junk.onFlank(
	kinds: { string },
	rng: Rng,
	count: number,
	length: number,
	width: number,
	rise: number
): { Piece }
	local pieces: { Piece } = {}
	for _ = 1, count do
		local along = length * math.sqrt(rng.next()) -- even over the triangle
		local out = width * (along / length) * rng.next()
		local y = Junk.flankHeight(along, out, length, width, rise) :: number
		table.insert(pieces, piece(kinds, rng, out, y, along, 1))
	end
	return pieces
end

return Junk
