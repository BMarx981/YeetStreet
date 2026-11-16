--!strict
-- LaunchRecords (ModuleScript) -> ReplicatedStorage.LaunchRecords
-- The launcher record signs' rules. Pure, see InputAxes. Values live in
-- Tuning.LaunchRecords.
--
-- Each park's biggest jump (a launcher, found by its path under workspace)
-- holds two records for the longest distance flown from it: this week's
-- (weeks as Leaderboard.week) and all time. A record is one key in a plain
-- DataStore, holding who set it and how far, in whole studs. A run beats a
-- record only by going farther; a tie keeps the holder. Studio keeps its
-- records in a store of its own.

local LaunchRecords = {}

export type Launcher = {
	Id: string, -- the record keys' start, and the pads' Launcher attribute
	Name: string, -- shown on the sign
	Path: string, -- the launcher's model under workspace, names joined by dots
}

-- Same fields as Tuning.LaunchRecords, declared here so this module needs no require.
export type Tuning = {
	Launchers: { Launcher },
	Store: string,
	StudioStore: string,
}

export type Record = {
	UserId: number,
	Name: string, -- the holder's display name when they set it
	Value: number, -- whole studs
}

-- The DataStore key of `launcherId`'s record: all-time, or `week`'s.
function LaunchRecords.key(launcherId: string, week: number?): string
	return if week then `{launcherId}_W{week}` else `{launcherId}_All`
end

function LaunchRecords.storeName(studio: boolean, tuning: Tuning): string
	return if studio then tuning.StudioStore else tuning.Store
end

function LaunchRecords.find(launcherId: string, tuning: Tuning): Launcher?
	for _, launcher in tuning.Launchers do
		if launcher.Id == launcherId then
			return launcher
		end
	end
	return nil
end

-- A run's distance as a record keeps it.
function LaunchRecords.encode(distance: number): number
	return math.floor(distance)
end

-- Whether `value` (whole studs) takes `record` over.
function LaunchRecords.beats(record: Record?, value: number): boolean
	return value > 0 and value > (if record then record.Value else 0)
end

local function isCount(value: any): boolean
	return typeof(value) == "number" and value == value and value >= 0 and value < math.huge
end

-- A record from what was saved, or nil if nothing whole was.
function LaunchRecords.reconcile(saved: any): Record?
	if typeof(saved) ~= "table" then
		return nil
	end
	if not (isCount(saved.UserId) and typeof(saved.Name) == "string" and isCount(saved.Value)) then
		return nil
	end
	return { UserId = saved.UserId, Name = saved.Name, Value = math.floor(saved.Value) }
end

-- A record's distance as its sign shows it.
function LaunchRecords.show(value: number): string
	local digits = tostring(math.floor(value)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return `{(digits:gsub("^,", ""))} studs`
end

return LaunchRecords
