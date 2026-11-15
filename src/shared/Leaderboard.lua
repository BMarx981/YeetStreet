--!strict
-- Leaderboard (ModuleScript) -> ReplicatedStorage.Leaderboard
-- The global leaderboards' rules. Pure, see InputAxes. Values live in
-- Tuning.Leaderboards.
--
-- Each board (best run, longest airtime, most rebirths) has an all-time list
-- and one list per week, each an ordered store. Weeks run from Monday 00:00
-- UTC. Ordered stores hold whole numbers, so airtime is stored in fractions
-- of a second (SecondsScale), always rounded down. Studio's stores have
-- names of their own, so testing never reaches the live boards.
--
-- A player's own bests for this week are saved with them (weekRecord), so a
-- value is sent only when it beats the last one sent (beats). The weekly
-- rebirths list counts the rebirths done that week.

local Leaderboard = {}

local DAY = 86400
local WEEK = 7 * DAY
-- The Unix epoch was a Thursday; this moves week starts to Mondays.
local MONDAY_SHIFT = 3 * DAY

-- "Points", "Seconds", or "Count" (anything else shows as a count). A plain
-- string, since Tuning's table literals type their strings that way.
export type Kind = string

export type Board = {
	Id: string, -- also the store name's middle, and the key in a weekly record
	Title: string, -- shown on the board
	Kind: Kind,
}

-- Same fields as Tuning.Leaderboards, declared here so this module needs no require.
export type Tuning = {
	Boards: { Board },
	Top: number, -- entries shown per list
	SecondsScale: number, -- stored units per second
	Store: string, -- store name prefix
	StudioStore: string, -- store name prefix in Studio
}

-- A player's bests this week, as stored values.
export type Week = {
	Week: number,
	Best: number,
	Airtime: number,
	Rebirths: number,
}

-- The week a Unix time falls in, counted from the first Monday after the epoch.
function Leaderboard.week(unixTime: number): number
	return math.floor((unixTime + MONDAY_SHIFT) / WEEK)
end

-- The ordered store for `boardId`: all-time, or `week`'s.
function Leaderboard.storeName(boardId: string, week: number?, studio: boolean, tuning: Tuning): string
	local prefix = if studio then tuning.StudioStore else tuning.Store
	local span = if week then `W{week}` else "All"
	return `{prefix}_{boardId}_{span}`
end

-- `value` as the whole number a store keeps.
function Leaderboard.encode(kind: Kind, value: number, tuning: Tuning): number
	if kind == "Seconds" then
		return math.floor(value * tuning.SecondsScale + 1e-6)
	end
	return math.floor(value)
end

local function withCommas(n: number): string
	local digits = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (digits:gsub("^,", ""))
end

-- A stored value as its board shows it.
function Leaderboard.show(kind: Kind, stored: number, tuning: Tuning): string
	if kind == "Seconds" then
		return string.format("%.1f s", stored / tuning.SecondsScale)
	elseif kind == "Points" then
		return withCommas(math.floor(stored))
	end
	return tostring(math.floor(stored))
end

-- Whether `value` is worth sending over the last value sent, `stored`.
function Leaderboard.beats(stored: number?, value: number): boolean
	return value > 0 and value > (stored or 0)
end

local function count(value: any): number
	if typeof(value) == "number" and value == value and value >= 0 and value < math.huge then
		return math.floor(value)
	end
	return 0
end

-- The player's bests for `week` from what was saved: kept if saved in that
-- week, fresh otherwise.
function Leaderboard.weekRecord(saved: any, week: number): Week
	local raw = if typeof(saved) == "table" then saved else {}
	if raw.Week ~= week then
		return { Week = week, Best = 0, Airtime = 0, Rebirths = 0 }
	end
	return { Week = week, Best = count(raw.Best), Airtime = count(raw.Airtime), Rebirths = count(raw.Rebirths) }
end

function Leaderboard.find(boardId: string, tuning: Tuning): Board?
	for _, board in tuning.Boards do
		if board.Id == boardId then
			return board
		end
	end
	return nil
end

return Leaderboard
