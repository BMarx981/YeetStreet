--!strict
-- NewBest (ModuleScript) -> ReplicatedStorage.NewBest
-- Whether a run that counts for Best is worth a NEW BEST banner, and whether
-- the rest of the server hears of it too. Pure, see InputAxes.
--
-- The very first run is never a new best, as there was nothing to beat.

local NewBest = {}

-- Same fields as Tuning.NewBest, declared here so this module needs no require.
export type Tuning = {
	ShoutFrom: number, -- a new best this high is shown to everyone in the server
}

-- `previous` is the player's Best before the run, `total` the run's score.
function NewBest.check(previous: number, total: number, tuning: Tuning): (boolean, boolean)
	local banner = previous > 0 and total > previous
	return banner, banner and total >= tuning.ShoutFrom
end

return NewBest
