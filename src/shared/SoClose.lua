--!strict
-- SoClose (ModuleScript) -> ReplicatedStorage.SoClose
-- The one "So close!" line a run card shows, if the run came close to
-- something. Pure, see InputAxes. In order, the first that fits:
--   a launcher record it fell short of, by up to RecordWithin of it
--   the player's Best, missed by up to BestWithin of it
--   the cheapest next upgrade, if one more run paying the same would buy it
--   the next combo step, if the run landed with tricks below the max combo,
--   which one more different trick gives

local SoClose = {}

-- Same fields as Tuning.SoClose, declared here so this module needs no require.
export type Tuning = {
	BestWithin: number, -- out of 1
	RecordWithin: number, -- out of 1
}

export type Facts = {
	total: number, -- the run's score
	best: number, -- the player's Best after the run
	landed: boolean, -- ended as a landing, so it kept its combo
	tricks: number,
	nextCombo: number?, -- the combo one more different trick gives, nil at the max
	distance: number, -- studs flown
	weekRecord: number?, -- the launcher's records, whole studs, if it has them
	allTimeRecord: number?,
	cash: number, -- after the run paid
	paid: number,
	upgradeCost: number?, -- the cheapest upgrade the car can still take
	upgradeName: string?, -- like "Jets 6"
}

local function withCommas(n: number): string
	local digits = tostring(math.floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (digits:gsub("^,", ""))
end

local function recordLine(facts: Facts, tuning: Tuning): string?
	local flown = math.floor(facts.distance)
	local record, name = facts.weekRecord, "this week's"
	if not record or flown >= record then
		record, name = facts.allTimeRecord, "the all-time"
	end
	if not record or flown >= record or flown < record * (1 - tuning.RecordWithin) then
		return nil
	end
	local gap = record - flown
	return `{withCommas(gap)} {if gap == 1 then "stud" else "studs"} short of {name} record!`
end

function SoClose.pick(facts: Facts, tuning: Tuning): string?
	local record = recordLine(facts, tuning)
	if record then
		return record
	end
	local best = facts.best
	if best > 0 and facts.total < best and facts.total >= best * (1 - tuning.BestWithin) then
		return `Only {withCommas(best - facts.total)} short of your best!`
	end
	local cost = facts.upgradeCost
	if cost and facts.upgradeName and facts.cash < cost and cost - facts.cash <= facts.paid then
		return `One more run like that buys {facts.upgradeName}!`
	end
	if facts.landed and facts.tricks > 0 and facts.nextCombo then
		return `One new trick for x{string.format("%g", facts.nextCombo)}!`
	end
	return nil
end

return SoClose
