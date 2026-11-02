--!strict
-- DinoLegs (ModuleScript) -> ReplicatedStorage.DinoLegs
-- How a dino car's legs swing from the hip as it moves. Speed is signed, along
-- the car's forward direction, so the legs run backward in reverse. They settle
-- back to standing in the air.

local DinoLegs = {}

DinoLegs.Gait = {
	Degrees = 30, -- furthest a leg swings to each side of straight down
	FullAt = 25, -- studs per second at which the swing reaches Degrees
	RatePerStud = 0.35, -- radians of step per stud travelled
	MostRate = 16, -- radians per second, so they don't blur at top speed
	Follow = 8, -- how quickly the swing size catches up, per second
}

DinoLegs.AirCheck = 5 -- no ground this far under the hull's center means airborne

export type Moves = {
	phase: number,
	size: number, -- how far the legs swing this moment, in radians
}

function DinoLegs.newMoves(): Moves
	return { phase = 0, size = 0 }
end

function DinoLegs.isLeg(name: string): boolean
	return string.find(string.lower(name), "leg", 1, true) ~= nil
end

-- How far the legs swing at `speed`, in radians.
function DinoLegs.reach(speed: number): number
	local G = DinoLegs.Gait
	return math.rad(G.Degrees) * math.min(math.abs(speed) / G.FullAt, 1)
end

-- How fast the step goes at `speed`, in radians per second.
function DinoLegs.rate(speed: number): number
	local G = DinoLegs.Gait
	return math.clamp(speed * G.RatePerStud, -G.MostRate, G.MostRate)
end

-- Moves the legs on by `dt` seconds.
function DinoLegs.step(moves: Moves, speed: number, airborne: boolean, dt: number)
	local target = if airborne then 0 else DinoLegs.reach(speed)
	moves.size = target + (moves.size - target) * math.exp(-DinoLegs.Gait.Follow * dt)
	moves.phase = (moves.phase + DinoLegs.rate(speed) * dt) % (2 * math.pi)
end

-- The swing of the leg piece `name` this moment. Left legs lead two-legged
-- dinos; four-legged ones step in diagonal pairs.
function DinoLegs.angle(moves: Moves, name: string): number
	local lower = string.lower(name)
	local left = string.find(lower, "left", 1, true) ~= nil
	local back = string.find(lower, "back", 1, true) ~= nil
	local inStep = left ~= back
	return moves.size * math.sin(moves.phase + if inStep then 0 else math.pi)
end

return DinoLegs
