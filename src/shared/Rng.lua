--!strict
-- Rng (ModuleScript) -> ReplicatedStorage.Rng
-- A small seeded random number generator (Park-Miller), so a seed gives the
-- same numbers on every client, the server, and the tests. Pure, see
-- InputAxes. Roblox's Random isn't available outside Roblox, and math.random
-- shares its state with every other script.
--
-- Rng.new returns its own functions, so pure modules that take an Rng (like
-- CarDesign) don't need to require this one.

local Rng = {}

local MODULUS = 2147483647 -- 2^31 - 1
local MULTIPLIER = 48271 -- state * MULTIPLIER stays below 2^53, so it's exact

export type Rng = {
	next: () -> number, -- from 0 up to, not including, 1
	range: (low: number, high: number) -> number, -- from low to high
	int: (low: number, high: number) -> number, -- a whole number, both ends included
}

function Rng.new(seed: number): Rng
	local state = math.floor(math.abs(seed)) % (MODULUS - 1) + 1

	local function next(): number
		state = state * MULTIPLIER % MODULUS
		return (state - 1) / (MODULUS - 1)
	end

	return {
		next = next,
		range = function(low: number, high: number): number
			return low + (high - low) * next()
		end,
		int = function(low: number, high: number): number
			return low + math.floor(next() * (high - low + 1))
		end,
	}
end

return Rng
