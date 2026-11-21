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
	local week = { Week = 4, Best = 500, Airtime = 80, Rebirths = 2, Mega = 0 }
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
	local week = { Week = 4, Best = 500, Airtime = 80, Rebirths = 2, Mega = 0 }
	local after = Leaderboard.recordRebirth(week)
	Check.eq(after.Rebirths, 3, "Rebirths")
	Check.eq(after.Best, 500, "Best kept")
	Check.eq(week.Rebirths, 2, "the record passed in is unchanged")
end)

Check.test("a player's six lists hold their all-time and this week's bests", function()
	local week = { Week = 2918, Best = 400, Airtime = 55, Rebirths = 1, Mega = 0 }
	local lists = Leaderboard.lists(1234.9, 8.79, 3, 0, week, false, T)
	Check.eq(lists["Boards1_Best_All"], 1234, "all-time best")
	Check.eq(lists["Boards1_Airtime_All"], 87, "all-time airtime")
	Check.eq(lists["Boards1_Rebirths_All"], 3, "all-time rebirths")
	Check.eq(lists["Boards1_Best_W2918"], 400, "weekly best")
	Check.eq(lists["Boards1_Airtime_W2918"], 55, "weekly airtime")
	Check.eq(lists["Boards1_Rebirths_W2918"], 1, "weekly rebirths")
	local n = 0
	for _ in lists do
		n += 1
	end
	Check.eq(n, 6, "six lists")
	local studio = Leaderboard.lists(1, 1, 1, 0, week, true, T)
	Check.eq(studio["StudioBoards1_Best_All"], 1, "Studio lists")
end)

Check.test("this week's Mega best is kept within the week and starts fresh in a new one", function()
	local saved = { Week = 5, Best = 900, Airtime = 120, Rebirths = 1, Mega = 3000 }
	Check.eq(Leaderboard.weekRecord(saved, 5).Mega, 3000, "same week")
	Check.eq(Leaderboard.weekRecord(saved, 6).Mega, 0, "new week")
	Check.eq(Leaderboard.weekRecord({ Week = 5, Mega = "lots" }, 5).Mega, 0, "broken")
	Check.eq(Leaderboard.weekRecord({ Week = 5, Best = 10 }, 5).Mega, 0, "saved before Mega existed")
end)

Check.test("a Mega run raises this week's Mega best only, never lowers it", function()
	local week = { Week = 4, Best = 500, Airtime = 80, Rebirths = 2, Mega = 1000 }
	local better = Leaderboard.recordMega(week, 2500.7, T)
	Check.eq(better.Mega, 2500, "Mega raised")
	Check.eq(better.Best, 500, "Best kept")
	Check.eq(better.Airtime, 80, "Airtime kept")
	Check.eq(Leaderboard.recordMega(week, 10, T).Mega, 1000, "Mega kept")
	Check.eq(week.Mega, 1000, "the record passed in is unchanged")
end)

Check.test("a normal run leaves this week's Mega best alone", function()
	local week = { Week = 4, Best = 500, Airtime = 80, Rebirths = 2, Mega = 1000 }
	Check.eq(Leaderboard.recordRun(week, 9000, 30, T).Mega, 1000)
end)

Check.test("a Mega board gets its all-time and weekly lists", function()
	local withMega = table.clone(T)
	withMega.Boards = table.clone(T.Boards)
	table.insert(withMega.Boards, { Id = "Mega", Title = "MEGA BOOSTERS", Kind = "Points" })
	local week = { Week = 2918, Best = 400, Airtime = 55, Rebirths = 1, Mega = 1500 }
	local lists = Leaderboard.lists(1234.9, 8.79, 3, 4321.5, week, false, withMega)
	Check.eq(lists["Boards1_Mega_All"], 4321, "all-time Mega")
	Check.eq(lists["Boards1_Mega_W2918"], 1500, "weekly Mega")
	Check.eq(lists["Boards1_Best_All"], 1234, "Best unchanged")
end)

Check.test("only lists that beat what was sent go out", function()
	local lists = { A = 10, B = 5, C = 0, D = 7 }
	local sent = { A = 10, B = 4, D = 9 }
	local out = Leaderboard.changed(lists, sent)
	Check.eq(out.A, nil, "tie")
	Check.eq(out.B, 5, "better")
	Check.eq(out.C, nil, "zero, never sent")
	Check.eq(out.D, nil, "lower than sent")
	local first = Leaderboard.changed({ A = 10, C = 0 }, {})
	Check.eq(first.A, 10, "a new session sends everything above 0")
	Check.eq(first.C, nil, "but not zeros")
end)

Check.test("a sorted page becomes ranked rows with names", function()
	local page = {
		{ key = "111", value = 900 },
		{ key = "222", value = 800 },
		{ key = "nope", value = 700 },
		{ key = "333", value = 600 },
	}
	local names = { [111] = "Ann", [333] = "Cy" }
	local rows = Leaderboard.rows(page, names, T)
	Check.eq(#rows, 3, "rows, the bad key skipped")
	Check.eq(rows[1].Rank, 1, "first rank")
	Check.eq(rows[1].Name, "Ann", "first name")
	Check.eq(rows[1].Value, 900, "first value")
	Check.eq(rows[1].UserId, 111, "first user")
	Check.eq(rows[2].Name, "Player 222", "a name not found yet")
	Check.eq(rows[3].Rank, 3, "ranks count only real rows")
	Check.eq(rows[3].Name, "Cy", "third name")
end)

Check.test("rows stop at the board's top", function()
	local page = {}
	for i = 1, 15 do
		table.insert(page, { key = tostring(i), value = 100 - i })
	end
	Check.eq(#Leaderboard.rows(page, {}, T), 10)
end)

Check.test("Studio test players (UserId 0 or below) never count", function()
	Check.eq(Leaderboard.counts(9569197820), true, "real account")
	Check.eq(Leaderboard.counts(0), false, "zero")
	Check.eq(Leaderboard.counts(-1), false, "Player1")
	Check.eq(Leaderboard.counts(-2), false, "Player2")
end)

Check.test("rows skip Studio test players", function()
	local rows = Leaderboard.rows({
		{ key = "-2", value = 900 },
		{ key = "42", value = 800 },
		{ key = "-1", value = 700 },
	}, {}, T)
	Check.eq(#rows, 1)
	Check.eq(rows[1].UserId, 42)
	Check.eq(rows[1].Rank, 1)
end)

Check.test("a board is found by id", function()
	local board = Leaderboard.find("Airtime", T)
	assert(board, "Airtime board")
	Check.eq(board.Kind, "Seconds")
	Check.eq(Leaderboard.find("Obby", T), nil, "unknown")
end)

Check.finish("Leaderboard")
