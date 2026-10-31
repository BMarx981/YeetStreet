--!strict
-- MissileCloud (ModuleScript) -> ReplicatedStorage.MissileCloud
-- What a silo missile's blast reaches, and the shape of its mushroom cloud
-- (Tuning.Silo.Blast): big round puffs in a stem, a wide cap with a crown on
-- top, and a ring round the base. Each client draws it (SiloBlast). Studs are
-- from the middle of the blast on the ground. Pure, see InputAxes.

local MissileCloud = {}

export type Config = {
	Rise: number, -- seconds for the cloud to climb to its full height
	Stem: { Puffs: number, Height: number, Radius: number },
	Cap: {
		Puffs: number,
		Height: number,
		Reach: number,
		Radius: number,
		Crown: number,
		CrownReach: number,
		CrownRise: number,
	},
	Base: { Puffs: number, Reach: number, Radius: number },
}

export type Puff = {
	kind: "stem" | "cap" | "base",
	x: number,
	y: number,
	z: number,
	radius: number,
	delay: number, -- seconds after the blast until it starts to swell
}

-- Whether (x, y, z) is within `radius` of the blast at (cx, cy, cz).
function MissileCloud.inBlast(
	radius: number,
	cx: number,
	cy: number,
	cz: number,
	x: number,
	y: number,
	z: number
): boolean
	local dx, dy, dz = x - cx, y - cy, z - cz
	return dx * dx + dy * dy + dz * dz <= radius * radius
end

function MissileCloud.puffs(config: Config, rng: { next: () -> number }): { Puff }
	local puffs: { Puff } = {}
	local top = config.Cap.Height + config.Cap.CrownRise
	local function add(kind: "stem" | "cap" | "base", x: number, y: number, z: number, radius: number)
		table.insert(
			puffs,
			{ kind = kind, x = x, y = y, z = z, radius = radius, delay = config.Rise * math.min(y / top, 1) }
		)
	end
	-- `count` puffs evenly round a ring, each a little out of place and size.
	local function ring(kind: "stem" | "cap" | "base", count: number, reach: number, y: number, radius: number)
		for i = 1, count do
			local angle = (i - 1 + rng.next() * 0.5) / count * 2 * math.pi
			local out = reach * (0.9 + rng.next() * 0.2)
			add(
				kind,
				out * math.cos(angle),
				y * (0.95 + rng.next() * 0.1),
				out * math.sin(angle),
				radius * (0.85 + rng.next() * 0.3)
			)
		end
	end

	local S = config.Stem
	for i = 1, S.Puffs do
		local out = S.Radius * 0.4 * rng.next()
		local angle = rng.next() * 2 * math.pi
		add(
			"stem",
			out * math.cos(angle),
			S.Height * i / S.Puffs,
			out * math.sin(angle),
			S.Radius * (0.9 + rng.next() * 0.3)
		)
	end
	local C = config.Cap
	ring("cap", C.Puffs, C.Reach, C.Height, C.Radius)
	ring("cap", C.Crown, C.CrownReach, C.Height + C.CrownRise, C.Radius * 1.1)
	local B = config.Base
	ring("base", B.Puffs, B.Reach, B.Radius * 0.4, B.Radius)
	return puffs
end

return MissileCloud
