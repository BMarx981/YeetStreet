--!strict
-- Bonus (ModuleScript) -> ReplicatedStorage.Bonus
-- Surprise pay bonuses on a run. Pure, see InputAxes.
--
-- A lucky run: the server rolls a number from 0 up to 1 when a run ends, and
-- the tiers of Tuning.Bonus.Lucky take slices of it in order, each Chance
-- wide. A roll past every slice is not lucky.
--
-- A clean streak: clean landings in a row. Each one pays StreakStep more, up
-- to StreakMax of them, on the run that made it. Any other ending loses the
-- streak, except a wreck, which leaves it as it was (crashes are a reward).
--
-- The new bonuses (lucky, golden booster, clean streak) multiply together
-- and never pass Cap. They scale the run's cash only, never its score.

local Bonus = {}

export type Tier = {
	Name: string, -- shown on the run card
	Multiplier: number,
	Chance: number, -- out of 1, per run
}

-- What the server sends beside a run's result and score, for the run card.
export type Extras = {
	lucky: Tier?,
	streak: number, -- clean landings in a row after the run
	golden: number?, -- the golden booster's multiplier, if the run claimed it
	paid: number, -- cash the run paid
	cash: number, -- the player's cash after it
	launcher: string?, -- the record launcher it flew from, if it counts for one
	coins: number, -- coins grabbed on the run, and the cash they paid
	coinCash: number,
	gems: number,
	gemCash: number,
}

-- Same fields as Tuning.Bonus, declared here so this module needs no require.
export type Tuning = {
	Cap: number,
	Lucky: { Tier },
	StreakStep: number, -- pay added per clean landing in a row
	StreakMax: number, -- clean landings that count toward the pay
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

-- The streak after a run that ended this way. `ending` is a RunTracker
-- Ending; `clean` is whether it landed upright.
function Bonus.streakAfter(streak: number, ending: string, clean: boolean): number
	if ending == "wrecked" then
		return streak
	elseif ending == "landed" and clean then
		return streak + 1
	end
	return 0
end

function Bonus.streakMultiplier(streak: number, tuning: Tuning): number
	return 1 + tuning.StreakStep * math.min(streak, tuning.StreakMax)
end

function Bonus.combined(multipliers: { number }, tuning: Tuning): number
	local product = 1
	for _, m in multipliers do
		product *= m
	end
	return math.min(product, tuning.Cap)
end

return Bonus
