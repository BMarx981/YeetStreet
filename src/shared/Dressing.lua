--!strict
-- Dressing (ModuleScript) -> ReplicatedStorage.Dressing
-- Where the Scrapyard's junk stands along its walls (ScrapyardDressing), from
-- a seeded Rng so it is the same on every server. Everything stands on a
-- band just inside the wall's foot: HalfX from the middle on the east and
-- west sides, HalfZ on the north and south, only along each side's straight
-- run (SpanX or SpanZ either way from the middle; past that the corners
-- curve). A floodlight stands at every step of LightEvery along each side,
-- and between them a piece of junk about every Every studs, a kind picked by
-- weight, none within LightClear of a light. Nothing stands within a
-- keep-out line's Radius (as in Scatter). Places are studs from the yard's
-- middle; `facing` is the yaw, in degrees, that turns a thing's front
-- (-Z) to face into the yard. Pure, see InputAxes. The caller passes
-- Rng.new(seed).

local Dressing = {}

-- Same as Rng.Rng, declared here so this module needs no require.
type Rng = {
	next: () -> number,
	range: (low: number, high: number) -> number,
	int: (low: number, high: number) -> number,
}

export type Line = { AX: number, AZ: number, BX: number, BZ: number, Radius: number }

export type Config = {
	HalfX: number,
	HalfZ: number,
	SpanX: number, -- along the north and south sides
	SpanZ: number, -- along the east and west sides
	Every: number,
	Jitter: number,
	LightEvery: number,
	LightClear: number,
	KeepOut: { Line },
	Kinds: { { Kind: string, Weight: number } },
}

export type Spot = { kind: string, x: number, z: number, facing: number }

local function kept(lines: { Line }, x: number, z: number): boolean
	for _, line in lines do
		local dx, dz = line.BX - line.AX, line.BZ - line.AZ
		local lengthSquared = dx * dx + dz * dz
		local t = if lengthSquared > 0
			then math.clamp(((x - line.AX) * dx + (z - line.AZ) * dz) / lengthSquared, 0, 1)
			else 0
		if (x - line.AX - dx * t) ^ 2 + (z - line.AZ - dz * t) ^ 2 < line.Radius * line.Radius then
			return true
		end
	end
	return false
end

local function pick(kinds: { { Kind: string, Weight: number } }, rng: Rng): string
	local total = 0
	for _, kind in kinds do
		total += kind.Weight
	end
	local roll = rng.next() * total
	for _, kind in kinds do
		roll -= kind.Weight
		if roll < 0 then
			return kind.Kind
		end
	end
	return kinds[#kinds].Kind
end

function Dressing.spots(c: Config, rng: Rng): { Spot }
	local spots: { Spot } = {}
	local sides = {
		{
			span = c.SpanX,
			facing = 0,
			place = function(t: number)
				return t, c.HalfZ
			end,
		},
		{
			span = c.SpanX,
			facing = 180,
			place = function(t: number)
				return t, -c.HalfZ
			end,
		},
		{
			span = c.SpanZ,
			facing = 90,
			place = function(t: number)
				return c.HalfX, t
			end,
		},
		{
			span = c.SpanZ,
			facing = 270,
			place = function(t: number)
				return -c.HalfX, t
			end,
		},
	}
	for _, side in sides do
		local lights: { number } = {}
		for k = math.ceil(-side.span / c.LightEvery), math.floor(side.span / c.LightEvery) do
			local t = k * c.LightEvery
			local x, z = side.place(t)
			if not kept(c.KeepOut, x, z) then
				table.insert(lights, t)
				table.insert(spots, { kind = "Light", x = x, z = z, facing = side.facing })
			end
		end
		local t = -side.span + c.Every / 2
		while t <= side.span - c.Every / 2 + 1e-9 do
			local at = math.clamp(t + rng.range(-c.Jitter, c.Jitter), -side.span, side.span)
			local kind = pick(c.Kinds, rng)
			local x, z = side.place(at)
			local clear = not kept(c.KeepOut, x, z)
			for _, light in lights do
				if math.abs(at - light) < c.LightClear then
					clear = false
				end
			end
			if clear then
				table.insert(spots, { kind = kind, x = x, z = z, facing = side.facing })
			end
			t += c.Every
		end
	end
	return spots
end

return Dressing
