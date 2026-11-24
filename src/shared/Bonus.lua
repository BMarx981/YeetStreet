--!strict
-- Bonus (ModuleScript) -> ReplicatedStorage.Bonus
-- Surprise pay bonuses on a run. Pure, see InputAxes.
--
-- A lucky run: the server rolls a number from 0 up to 1 when a run ends, and
-- the tiers of Tuning.Bonus.Lucky take slices of it in order, each Chance
-- wide. A roll past every slice is not lucky.
--
-- The new bonuses (lucky, golden booster, clean streak) multiply together
-- and never pass Cap. They scale the run's cash only, never its score.

local Bonus = {}

export type Tier = {
	Name: string, -- shown on the run card
	Multiplier: number,
	Chance: number, -- out of 1, per run
}

-- Same fields as Tuning.Bonus, declared here so this module needs no require.
export type Tuning = {
	Cap: number,
	Lucky: { Tier },
}

function Bonus.lucky(roll: number, tuning: Tuning): Tier?
	local edge = 0
	for _, tier in tuning.Lucky do
		edge += tier.Chance
		if roll < edge then
			return tier
		end
	end
	return nil
end

-- The chance a run is lucky at all.
function Bonus.luckyChance(tuning: Tuning): number
	local total = 0
	for _, tier in tuning.Lucky do
		total += tier.Chance
	end
	return total
end

function Bonus.combined(multipliers: { number }, tuning: Tuning): number
	local product = 1
	for _, m in multipliers do
		product *= m
	end
	return math.min(product, tuning.Cap)
end

return Bonus
