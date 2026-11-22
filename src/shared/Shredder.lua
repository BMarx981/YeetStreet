--!strict
-- Shredder (ModuleScript) -> ReplicatedStorage.Shredder
-- The Scrapyard's shredder (Tuning.Scrapyard.Shredder): a steel hopper of
-- spinning toothed rollers, open at the top, that a kicker throws cars into.
-- A car coming down into the opening is caught, settles onto the rollers,
-- shakes and sinks into them while it is chewed, and bits of it spray back
-- out of the top. The run that brought it pays a target by how far it flew.
-- Places are studs in the hopper's frame: X along its Length, Z across its
-- Width, Y up from the floor. Pure, see InputAxes.

local Shredder = {}

export type Tier = { Min: number, Target: string }

export type Config = {
	Length: number, -- the opening, inside the walls
	Width: number,
	RimHeight: number, -- the walls' top above the floor
	CatchAbove: number, -- a hull's middle this far over the rim, above the opening, is caught
	ChewBase: number, -- seconds, plus ChewPerToughness for each point of the car's Toughness
	ChewPerToughness: number,
	ChewMax: number,
	Settle: number, -- seconds to come to rest on the rollers once caught
	SinkDepth: number, -- how far it sinks into them by the end of the chewing
	Shake: number, -- studs either way it shakes while held
	ShakeRate: number, -- shakes a second
	SprayUp: number, -- a bit's upward speed, plus up to SprayUpJitter
	SprayUpJitter: number,
	SpraySide: number, -- at most this fast to each side
	Tiers: { Tier }, -- by Min, the run's distance, smallest first
}

-- Seeded random numbers (Rng), as a parameter so this module requires nothing.
type Rng = {
	next: () -> number,
	range: (low: number, high: number) -> number,
	int: (low: number, high: number) -> number,
}

export type Pose = {
	blend: number, -- 0 where it was caught, 1 resting on the rollers
	sink: number, -- studs down into them
	shakeX: number,
	shakeZ: number,
}

function Shredder.inside(c: Config, x: number, y: number, z: number): boolean
	return math.abs(x) <= c.Length / 2 and math.abs(z) <= c.Width / 2 and y >= 0 and y <= c.RimHeight + c.CatchAbove
end

function Shredder.chewTime(c: Config, toughness: number): number
	return math.min(c.ChewBase + c.ChewPerToughness * toughness, c.ChewMax)
end

-- The target a run coming down in it pays, by how far it flew.
function Shredder.target(c: Config, distance: number): string
	local found = c.Tiers[1].Target
	for _, tier in c.Tiers do
		if distance >= tier.Min then
			found = tier.Target
		end
	end
	return found
end

-- The speed that throws a car `angle` degrees up so that `distance` studs
-- on it is `rise` studs above where it left, or nil if none can.
function Shredder.launchSpeed(distance: number, angle: number, rise: number, gravity: number): number?
	local a = math.rad(angle)
	local climb = distance * math.tan(a) - rise
	if climb <= 0 then
		return nil
	end
	return math.sqrt(gravity * distance * distance / (2 * math.cos(a) ^ 2 * climb))
end

function Shredder.pose(c: Config, elapsed: number, chew: number): Pose
	local settled = math.clamp(elapsed / c.Settle, 0, 1)
	local chewed = math.clamp((elapsed - c.Settle) / chew, 0, 1)
	local turn = elapsed * c.ShakeRate * 2 * math.pi
	return {
		blend = settled * settled * (3 - 2 * settled),
		sink = c.SinkDepth * chewed,
		shakeX = c.Shake * math.sin(turn),
		shakeZ = c.Shake * math.sin(turn * 1.37 + 1),
	}
end

-- One chewed bit's velocity out of the top: x, y, z.
function Shredder.spray(c: Config, rng: Rng): (number, number, number)
	return rng.range(-c.SpraySide, c.SpraySide),
		c.SprayUp + rng.range(0, c.SprayUpJitter),
		rng.range(-c.SpraySide, c.SpraySide)
end

return Shredder
