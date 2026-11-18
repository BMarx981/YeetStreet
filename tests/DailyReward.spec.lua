--!strict
local Check = require("./Check")
local DailyReward = require("../src/shared/DailyReward")

local T: DailyReward.Tuning = {
	Days = {
		{ Cash = 10 },
		{ Cash = 20 },
		{ DoubleLaunches = 3 },
		{ Cash = 40 },
		{ Cash = 60 },
		{ DoubleLaunches = 5 },
		{ Cash = 150 },
	},
	WeekPrizes = { "A", "B", "C" },
	DoubleMultiplier = 2,
}

local DAY = 86400

local function claimDays(first: number, count: number): (DailyReward.State, DailyReward.Reward?)
	local state = DailyReward.newState()
	local reward: DailyReward.Reward? = nil
	for i = 0, count - 1 do
		state, reward = DailyReward.claim(state, first + i, T)
	end
	return state, reward
end

Check.test("dayOf counts whole UTC days since 1970", function()
	Check.eq(DailyReward.dayOf(0), 0)
	Check.eq(DailyReward.dayOf(DAY - 1), 0)
	Check.eq(DailyReward.dayOf(DAY), 1)
	Check.eq(DailyReward.dayOf(DAY * 20000 + 5), 20000)
end)

Check.test("secondsToNext counts down to the next UTC midnight", function()
	Check.eq(DailyReward.secondsToNext(0), DAY)
	Check.eq(DailyReward.secondsToNext(DAY - 1), 1)
	Check.eq(DailyReward.secondsToNext(DAY * 5 + 3600), DAY - 3600)
end)

Check.test("a new state has never claimed", function()
	local state = DailyReward.newState()
	Check.eq(state.LastDay, 0)
	Check.eq(state.Streak, 0)
	Check.eq(state.Weeks, 0)
	Check.eq(state.DoubleLaunches, 0)
end)

Check.test("reconcile keeps valid saved fields", function()
	local state = DailyReward.reconcile({ LastDay = 20000, Streak = 9, Weeks = 1, DoubleLaunches = 4 })
	Check.eq(state.LastDay, 20000)
	Check.eq(state.Streak, 9)
	Check.eq(state.Weeks, 1)
	Check.eq(state.DoubleLaunches, 4)
end)

Check.test("reconcile drops junk", function()
	local state = DailyReward.reconcile({ LastDay = "x", Streak = -2, Weeks = 1.5, DoubleLaunches = -1 })
	Check.eq(state.LastDay, 0)
	Check.eq(state.Streak, 0)
	Check.eq(state.Weeks, 0)
	Check.eq(state.DoubleLaunches, 0)
	Check.eq(DailyReward.reconcile(nil).Streak, 0)
end)

Check.test("a new player can claim day 1", function()
	local status = DailyReward.status(DailyReward.newState(), 20000)
	Check.eq(status.CanClaim, true)
	Check.eq(status.Day, 1)
end)

Check.test("claiming day 1 pays its cash and records the day", function()
	local state, reward = DailyReward.claim(DailyReward.newState(), 20000, T)
	assert(reward, "no reward")
	Check.eq(reward.Day, 1)
	Check.eq(reward.Cash, 10)
	Check.eq(reward.DoubleLaunches, 0)
	Check.eq(reward.Prize, nil)
	Check.eq(state.LastDay, 20000)
	Check.eq(state.Streak, 1)
end)

Check.test("a second claim on the same day gives nothing", function()
	local state = claimDays(20000, 1)
	local after, reward = DailyReward.claim(state, 20000, T)
	Check.eq(reward, nil)
	Check.eq(after.Streak, 1)
	local status = DailyReward.status(state, 20000)
	Check.eq(status.CanClaim, false)
	Check.eq(status.Day, 1)
end)

Check.test("claiming the next day moves the streak on", function()
	local state = claimDays(20000, 1)
	Check.eq(DailyReward.status(state, 20001).Day, 2)
	local after, reward = DailyReward.claim(state, 20001, T)
	assert(reward, "no reward")
	Check.eq(reward.Day, 2)
	Check.eq(reward.Cash, 20)
	Check.eq(after.Streak, 2)
end)

Check.test("missing a day starts over at day 1", function()
	local state = claimDays(20000, 4)
	Check.eq(DailyReward.status(state, 20005).Day, 1)
	local after, reward = DailyReward.claim(state, 20005, T)
	assert(reward, "no reward")
	Check.eq(reward.Day, 1)
	Check.eq(after.Streak, 1)
end)

Check.test("a day earlier than the last claim gives nothing", function()
	local state = claimDays(20000, 1)
	Check.eq(DailyReward.status(state, 19999).CanClaim, false)
	local _, reward = DailyReward.claim(state, 19999, T)
	Check.eq(reward, nil)
end)

Check.test("a double launch day adds launches that stack", function()
	local state, reward = claimDays(20000, 3)
	assert(reward, "no reward")
	Check.eq(reward.Cash, 0)
	Check.eq(reward.DoubleLaunches, 3)
	Check.eq(state.DoubleLaunches, 3)
	state = claimDays(20000, 6)
	Check.eq(state.DoubleLaunches, 8)
end)

Check.test("day 7 pays its cash and the first week's prize", function()
	local state, reward = claimDays(20000, 7)
	assert(reward, "no reward")
	Check.eq(reward.Day, 7)
	Check.eq(reward.Cash, 150)
	Check.eq(reward.Prize, "A")
	Check.eq(state.Weeks, 1)
end)

Check.test("after day 7 the calendar starts over at day 1", function()
	local state = claimDays(20000, 7)
	Check.eq(DailyReward.status(state, 20007).Day, 1)
	local _, reward = DailyReward.claim(state, 20007, T)
	assert(reward, "no reward")
	Check.eq(reward.Day, 1)
	Check.eq(reward.Cash, 10)
end)

Check.test("each full week gives the next prize, then cash only", function()
	local _, week2 = claimDays(20000, 14)
	local _, week3 = claimDays(20000, 21)
	local state, week4 = claimDays(20000, 28)
	assert(week2 and week3 and week4, "no reward")
	Check.eq(week2.Prize, "B")
	Check.eq(week3.Prize, "C")
	Check.eq(week4.Prize, nil)
	Check.eq(week4.Cash, 150)
	Check.eq(state.Weeks, 4)
end)

Check.test("a broken streak keeps the prizes already earned", function()
	local state = claimDays(20000, 7)
	state = DailyReward.claim(state, 20010, T)
	for i = 1, 5 do
		state = DailyReward.claim(state, 20010 + i, T)
	end
	local _, reward = DailyReward.claim(state, 20016, T)
	assert(reward, "no reward")
	Check.eq(reward.Day, 7)
	Check.eq(reward.Prize, "B")
end)

Check.test("useLaunch doubles while launches are left", function()
	local state = DailyReward.newState()
	state.DoubleLaunches = 2
	local after, multiplier = DailyReward.useLaunch(state, T, 100)
	Check.eq(multiplier, 2)
	Check.eq(after.DoubleLaunches, 1)
	Check.eq(state.DoubleLaunches, 2, "original untouched")
	after, multiplier = DailyReward.useLaunch(after, T, 100)
	Check.eq(multiplier, 2)
	after, multiplier = DailyReward.useLaunch(after, T, 100)
	Check.eq(multiplier, 1)
	Check.eq(after.DoubleLaunches, 0)
end)

Check.test("a run that pays nothing keeps its double launch", function()
	local state = DailyReward.newState()
	state.DoubleLaunches = 2
	local after, multiplier = DailyReward.useLaunch(state, T, 0)
	Check.eq(multiplier, 1)
	Check.eq(after.DoubleLaunches, 2)
end)

Check.test("skipDay makes the next claim continue the streak today", function()
	local state = claimDays(1000, 2)
	local skipped = DailyReward.skipDay(state)
	Check.eq(skipped.LastDay, 1000, "a day earlier")
	Check.eq(state.LastDay, 1001, "original untouched")
	local status = DailyReward.status(skipped, 1001, #T.Days)
	Check.eq(status.CanClaim, true)
	Check.eq(status.Day, 3)
end)

Check.test("skipDay leaves a player who never claimed alone", function()
	local state = DailyReward.newState()
	Check.eq(DailyReward.skipDay(state).LastDay, 0)
end)

Check.test("a new player's calendar has day 1 ready and the rest to come", function()
	local tiles = DailyReward.tiles(DailyReward.newState(), 1000, 7)
	Check.eq(#tiles, 7)
	Check.eq(tiles[1], "ready")
	Check.eq(tiles[2], "later")
	Check.eq(tiles[7], "later")
end)

Check.test("days claimed this week show as got, with the next one ready", function()
	local state = claimDays(1000, 2)
	local tiles = DailyReward.tiles(state, 1002, 7)
	Check.eq(tiles[1], "got")
	Check.eq(tiles[2], "got")
	Check.eq(tiles[3], "ready")
	Check.eq(tiles[4], "later")
end)

Check.test("after claiming today nothing is ready", function()
	local state = claimDays(1000, 3)
	local tiles = DailyReward.tiles(state, 1002, 7)
	Check.eq(tiles[3], "got")
	Check.eq(tiles[4], "later")
	Check.eq(table.find(tiles, "ready"), nil)
end)

Check.test("a broken streak shows day 1 ready again", function()
	local state = claimDays(1000, 4)
	local tiles = DailyReward.tiles(state, 1010, 7)
	Check.eq(tiles[1], "ready")
	Check.eq(tiles[2], "later")
end)

Check.test("the day after the last day starts a fresh calendar", function()
	local state = claimDays(1000, 7)
	Check.eq(DailyReward.tiles(state, 1006, 7)[7], "got", "on the last day")
	local tiles = DailyReward.tiles(state, 1007, 7)
	Check.eq(tiles[1], "ready")
	Check.eq(tiles[7], "later")
end)

Check.test("countdown shows hours, minutes, and seconds", function()
	Check.eq(DailyReward.countdown(3725), "1:02:05")
	Check.eq(DailyReward.countdown(59.7), "0:00:59")
	Check.eq(DailyReward.countdown(86400), "24:00:00")
	Check.eq(DailyReward.countdown(-3), "0:00:00")
end)

Check.test("the streak counts while it can still go on", function()
	local state = claimDays(1000, 3)
	Check.eq(DailyReward.streak(state, 1002), 3, "claimed today")
	Check.eq(DailyReward.streak(state, 1003), 3, "not yet claimed today")
	Check.eq(DailyReward.streak(state, 1004), 0, "a day missed")
	Check.eq(DailyReward.streak(DailyReward.newState(), 1000), 0, "never claimed")
end)

Check.finish("DailyReward")
