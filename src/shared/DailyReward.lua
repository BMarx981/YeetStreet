--!strict
-- DailyReward (ModuleScript) -> ReplicatedStorage.DailyReward
-- The daily reward calendar. Pure, see InputAxes.
--
-- One claim per UTC day. Claiming on the day after the last claim moves the
-- streak on; missing a day starts it over at day 1. The calendar is
-- Tuning.Daily.Days long and loops back to day 1 after its last day. Each time
-- the last day is claimed, the next of WeekPrizes is given as well, until they
-- run out.
--
-- Some days give double cash launches instead of cash: the next that many
-- run payouts are multiplied by DoubleMultiplier (useLaunch).

local DailyReward = {}

local SECONDS_PER_DAY = 86400

export type Day = {
	Cash: number?,
	DoubleLaunches: number?,
}

-- Same fields as Tuning.Daily, declared here so this module needs no require.
export type Tuning = {
	Days: { Day },
	WeekPrizes: { string }, -- given in order on each claim of the last day
	DoubleMultiplier: number,
}

export type State = {
	LastDay: number, -- UTC day of the last claim (dayOf), 0 if never
	Streak: number, -- days claimed in a row, ending on LastDay
	Weeks: number, -- times the last day has been claimed
	DoubleLaunches: number, -- double cash launches left
}

export type Status = {
	CanClaim: boolean,
	Day: number, -- the calendar day claimable now, or the one claimed today
}

export type Reward = {
	Day: number,
	Cash: number,
	DoubleLaunches: number,
	Prize: string?,
}

local function isCount(value: any): boolean
	return typeof(value) == "number" and value >= 0 and value % 1 == 0
end

-- The UTC day number of unix time `t`.
function DailyReward.dayOf(t: number): number
	return math.floor(t / SECONDS_PER_DAY)
end

-- Seconds from unix time `t` to the next UTC midnight.
function DailyReward.secondsToNext(t: number): number
	return SECONDS_PER_DAY - t % SECONDS_PER_DAY
end

function DailyReward.newState(): State
	return { LastDay = 0, Streak = 0, Weeks = 0, DoubleLaunches = 0 }
end

function DailyReward.reconcile(saved: any): State
	local state = DailyReward.newState()
	if typeof(saved) ~= "table" then
		return state
	end
	for key in state do
		if isCount(saved[key]) then
			state[key] = saved[key]
		end
	end
	return state
end

local function cycleDay(streak: number, length: number): number
	return (streak - 1) % length + 1
end

-- Whether `state` can claim on UTC day `today`, and which calendar day.
function DailyReward.status(state: State, today: number, length: number?): Status
	local days = length or 7
	if state.Streak > 0 and today <= state.LastDay then
		return { CanClaim = false, Day = cycleDay(state.Streak, days) }
	end
	if state.Streak > 0 and today == state.LastDay + 1 then
		return { CanClaim = true, Day = cycleDay(state.Streak + 1, days) }
	end
	return { CanClaim = true, Day = 1 }
end

-- `state` after claiming on UTC day `today`, and what that gives. The reward
-- is nil, and `state` unchanged, if it can't claim today.
function DailyReward.claim(state: State, today: number, tuning: Tuning): (State, Reward?)
	local length = #tuning.Days
	local status = DailyReward.status(state, today, length)
	if not status.CanClaim then
		return state, nil
	end
	local day = tuning.Days[status.Day]
	local reward: Reward = {
		Day = status.Day,
		Cash = day.Cash or 0,
		DoubleLaunches = day.DoubleLaunches or 0,
		Prize = nil,
	}
	local weeks = state.Weeks
	if status.Day == length then
		weeks += 1
		reward.Prize = tuning.WeekPrizes[weeks]
	end
	return {
		LastDay = today,
		Streak = if status.Day == 1 then 1 else state.Streak + 1,
		Weeks = weeks,
		DoubleLaunches = state.DoubleLaunches + reward.DoubleLaunches,
	},
		reward
end

-- `state` after one run payout, and the multiplier for that payout.
function DailyReward.useLaunch(state: State, tuning: Tuning): (State, number)
	if state.DoubleLaunches <= 0 then
		return state, 1
	end
	local after = table.clone(state)
	after.DoubleLaunches -= 1
	return after, tuning.DoubleMultiplier
end

return DailyReward
