--!strict
local Check = require("./Check")
local Leaderboard = require("../src/shared/Leaderboard")

local T: Leaderboard.Tuning = {
	Boards = {
		{ Id = "Best", Title = "BEST RUN", Kind = "Points" },
		{ Id = "Airtime", Title = "LONGEST AIRTIME", Kind = "Seconds" },
		{ Id = "Rebirths", Title = "MOST REBIRTHS", Kind = "Count" },
	},
	Top = 10,
	SecondsScale = 10,
	Store = "Boards1",
	StudioStore = "StudioBoards1",
}

local DAY = 86400
local MONDAY = 4 * DAY -- 1970-01-05, the first Monday after the Unix epoch

Check.test("weeks start on Monday 00:00 UTC", function()
	Check.eq(Leaderboard.week(0), 0, "Thursday 1970-01-01")
	Check.eq(Leaderboard.week(MONDAY - 1), 0, "Sunday night")
	Check.eq(Leaderboard.week(MONDAY), 1, "Monday")
	Check.eq(Leaderboard.week(MONDAY + 7 * DAY - 1), 1, "the next Sunday night")
	Check.eq(Leaderboard.week(MONDAY + 7 * DAY), 2, "the next Monday")
end)

Check.test("each board has an all-time store and one per week, and Studio has its own", function()
	Check.eq(Leaderboard.storeName("Best", nil, false, T), "Boards1_Best_All")
	Check.eq(Leaderboard.storeName("Airtime", 2918, false, T), "Boards1_Airtime_W2918")
	Check.eq(Leaderboard.storeName("Rebirths", nil, true, T), "StudioBoards1_Rebirths_All")
end)

Check.test("stored values are whole numbers, airtime in tenths of a second", function()
	Check.eq(Leaderboard.encode("Points", 12345.7, T), 12345, "points")
	Check.eq(Leaderboard.encode("Seconds", 12.36, T), 123, "seconds")
	Check.eq(Leaderboard.encode("Seconds", 12.34, T), 123, "seconds round down")
	Check.eq(Leaderboard.encode("Count", 3, T), 3, "count")
end)

Check.test("a stored value shows the way its board reads", function()
	Check.eq(Leaderboard.show("Points", 1234567, T), "1,234,567", "points")
	Check.eq(Leaderboard.show("Points", 950, T), "950", "small points")
	Check.eq(Leaderboard.show("Seconds", 123, T), "12.3 s", "seconds")
	Check.eq(Leaderboard.show("Seconds", 40, T), "4.0 s", "whole seconds")
	Check.eq(Leaderboard.show("Count", 7, T), "7", "count")
end)

Check.test("only a value above the last one, and above 0, is worth sending", function()
	Check.eq(Leaderboard.beats(nil, 10), true, "first")
	Check.eq(Leaderboard.beats(nil, 0), false, "zero")
	Check.eq(Leaderboard.beats(10, 10), false, "tie")
	Check.eq(Leaderboard.beats(10, 11), true, "better")
	Check.eq(Leaderboard.beats(10, 9), false, "worse")
end)

Check.test("this week's bests start fresh in a new week", function()
	local saved = { Week = 5, Best = 900, Airtime = 120, Rebirths = 1 }
	local same = Leaderboard.weekRecord(saved, 5)
	Check.eq(same.Best, 900, "same week Best")
	Check.eq(same.Airtime, 120, "same week Airtime")
	Check.eq(same.Rebirths, 1, "same week Rebirths")
	local next = Leaderboard.weekRecord(saved, 6)
	Check.eq(next.Week, 6, "new week")
	Check.eq(next.Best, 0, "new week Best")
	Check.eq(next.Airtime, 0, "new week Airtime")
	Check.eq(next.Rebirths, 0, "new week Rebirths")
end)

Check.test("a missing or broken weekly record starts fresh", function()
	local none = Leaderboard.weekRecord(nil, 3)
	Check.eq(none.Week, 3, "nil Week")
	Check.eq(none.Best, 0, "nil Best")
	local broken = Leaderboard.weekRecord({ Week = 3, Best = "lots", Airtime = -5, Rebirths = 0 / 0 }, 3)
	Check.eq(broken.Best, 0, "string Best")
	Check.eq(broken.Airtime, 0, "negative Airtime")
	Check.eq(broken.Rebirths, 0, "NaN Rebirths")
end)

Check.test("a run raises this week's best run and airtime, never lowers them", function()
	local week = { Week = 4, Best = 500, Airtime = 80, Rebirths = 2 }
	local better = Leaderboard.recordRun(week, 900.6, 12.37, T)
	Check.eq(better.Best, 900, "Best raised")
	Check.eq(better.Airtime, 123, "Airtime raised, in tenths")
	Check.eq(better.Rebirths, 2, "Rebirths kept")
	Check.eq(better.Week, 4, "Week kept")
	local worse = Leaderboard.recordRun(week, 100, 1.5, T)
	Check.eq(worse.Best, 500, "Best kept")
	Check.eq(worse.Airtime, 80, "Airtime kept")
	Check.eq(week.Best, 500, "the record passed in is unchanged")
end)

Check.test("a rebirth counts once on this week's record", function()
	local week = { Week = 4, Best = 500, Airtime = 80, Rebirths = 2 }
	local after = Leaderboard.recordRebirth(week)
	Check.eq(after.Rebirths, 3, "Rebirths")
	Check.eq(after.Best, 500, "Best kept")
	Check.eq(week.Rebirths, 2, "the record passed in is unchanged")
end)

Check.test("a board is found by id", function()
	local board = Leaderboard.find("Airtime", T)
	assert(board, "Airtime board")
	Check.eq(board.Kind, "Seconds")
	Check.eq(Leaderboard.find("Obby", T), nil, "unknown")
end)

Check.finish("Leaderboard")
