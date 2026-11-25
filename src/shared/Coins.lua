--!strict
-- Coins (ModuleScript) -> ReplicatedStorage.Coins
-- Coins and gems in the air over the launchers (CoinService, CoinLook).
-- Pure, see InputAxes; points are plain x, y, z tables so the tests can run
-- outside Roblox.
--
-- A launcher's coins sit on the path a car flies off its top pad with no
-- jets: thrown at the pad's LaunchSpeed along its LookVector, falling only
-- under gravity (cars have no air drag). They start FirstAt seconds past the
-- lip, one every Gap seconds, until the path falls back below the lip, at
-- most Max of them. Its gem sits above the top of that path, out of reach
-- without jets.

local Coins = {}

export type Point = { x: number, y: number, z: number }

-- The fields of Tuning.Coins that place a launcher's coins.
export type ArcTuning = {
	FirstAt: number,
	Gap: number,
	Max: number,
}

local function at(start: Point, velocity: Point, gravity: number, t: number): Point
	return {
		x = start.x + velocity.x * t,
		y = start.y + velocity.y * t - gravity * t * t / 2,
		z = start.z + velocity.z * t,
	}
end

function Coins.arc(start: Point, velocity: Point, gravity: number, tuning: ArcTuning): { Point }
	local points: { Point } = {}
	local t = tuning.FirstAt
	while #points < tuning.Max do
		local p = at(start, velocity, gravity, t)
		if p.y < start.y then
			break
		end
		table.insert(points, p)
		t += tuning.Gap
	end
	return points
end

-- The top of the path.
function Coins.apex(start: Point, velocity: Point, gravity: number): Point
	return at(start, velocity, gravity, math.max(velocity.y / gravity, 0))
end

function Coins.near(a: Point, b: Point, radius: number): boolean
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return dx * dx + dy * dy + dz * dz <= radius * radius
end

-- Whether a gem taken at `takenAt` (nil if never) is back at `now`.
function Coins.gemReady(takenAt: number?, now: number, wait: number): boolean
	return takenAt == nil or now - takenAt >= wait
end

return Coins
