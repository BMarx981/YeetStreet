--!strict
-- Golden (ModuleScript) -> ReplicatedStorage.Golden
-- The golden booster's rules. Pure, see InputAxes. Every so often one of the
-- record launchers (LaunchRecords) turns gold for a while (GoldenService).
-- The first launch off it, outside Mega Boosters, claims it: that run pays
-- Tuning.Golden.Multiplier more (Bonus), and the launcher goes back to normal.

local Golden = {}

-- Same fields as Tuning.Golden, declared here so this module needs no require.
export type Tuning = {
	FirstAfter: number, -- seconds after the server starts
	Every: number, -- seconds from one golden booster's start to the next
	Duration: number, -- seconds it stays gold if nobody claims it
	Multiplier: number,
	Launchers: { string }, -- LaunchRecords launcher ids that can turn gold
}

-- The launcher to turn gold, from a roll from 0 up to 1, never `last` again
-- unless it is the only one.
function Golden.pick(ids: { string }, last: string?, roll: number): string?
	local choices: { string } = {}
	for _, id in ids do
		if id ~= last then
			table.insert(choices, id)
		end
	end
	if #choices == 0 then
		choices = ids
	end
	if #choices == 0 then
		return nil
	end
	return choices[math.min(math.floor(roll * #choices) + 1, #choices)]
end

-- Whether a launch from `launcher` claims the golden booster `golden`.
function Golden.claims(golden: string?, launcher: string?, mega: boolean): boolean
	return golden ~= nil and launcher == golden and not mega
end

return Golden
