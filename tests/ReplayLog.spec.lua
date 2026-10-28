--!strict
local Check = require("./Check")
local ReplayLog = require("../src/shared/ReplayLog")

-- A log of one key changing at each (time, value).
local function logged(key: string, changes: { { any } }): ReplayLog.Log
	local log = ReplayLog.new()
	for _, change in changes do
		ReplayLog.note(log, change[1], key, change[2])
	end
	return log
end

Check.test("a key has the value of its last change at or before a time", function()
	local log = logged("Mode", { { 1, "roam" }, { 4, "chase" }, { 6, "bite" } })
	Check.eq(ReplayLog.at(log, "Mode", 0.5), nil, "before any change")
	Check.eq(ReplayLog.at(log, "Mode", 1), "roam", "at the first")
	Check.eq(ReplayLog.at(log, "Mode", 3.9), "roam", "between")
	Check.eq(ReplayLog.at(log, "Mode", 4), "chase", "at the second")
	Check.eq(ReplayLog.at(log, "Mode", 99), "bite", "after the last")
	Check.eq(ReplayLog.at(log, "Other", 5), nil, "a key never noted")
end)

Check.test("noting the same value again adds no change", function()
	local log = logged("Chewing", { { 1, false }, { 2, false }, { 3, true }, { 4, true } })
	Check.eq(#log.Chewing, 2, "changes")
end)

Check.test("a key set to nil reads nil from then", function()
	local log = logged("HeldCar", { { 1, "Car_A" }, { 2, nil } })
	Check.eq(ReplayLog.at(log, "HeldCar", 1.5), "Car_A", "held")
	Check.eq(ReplayLog.at(log, "HeldCar", 2.5), nil, "dropped")
end)

Check.test("trimming keeps each key's value at the trim time", function()
	local log = logged("Mode", { { 1, "roam" }, { 4, "chase" }, { 6, "bite" }, { 9, "recover" } })
	ReplayLog.note(log, 2, "Shots", 1)
	ReplayLog.trim(log, 5)
	Check.eq(#log.Mode, 3, "chase, bite and recover left")
	Check.eq(ReplayLog.at(log, "Mode", 5), "chase", "value at the trim time")
	Check.eq(ReplayLog.at(log, "Shots", 7), 1, "a key with only old changes keeps its last")
end)

Check.test("a cut holds the changes in it and each key's value at its start, from zero", function()
	local log = logged("Mode", { { 1, "roam" }, { 4, "chase" }, { 6, "bite" }, { 9, "recover" } })
	ReplayLog.note(log, 2, "Shots", 1)
	ReplayLog.note(log, 3, "Shots", 2)
	ReplayLog.note(log, 7, "Shots", 3)
	local cut = ReplayLog.cut(log, 5, 8, 5.5)
	Check.eq(ReplayLog.at(cut, "Mode", -0.5), "chase", "value at the cut's start")
	Check.eq(ReplayLog.at(cut, "Mode", 0.4), "chase", "before the bite")
	Check.eq(ReplayLog.at(cut, "Mode", 0.5), "bite", "the bite, counted from zero")
	Check.eq(ReplayLog.at(cut, "Mode", 99), "bite", "the change after the cut is left out")
	Check.eq(ReplayLog.at(cut, "Shots", 0), 2, "shots at the start")
	Check.eq(ReplayLog.at(cut, "Shots", 1.5), 3, "a shot in the cut")
	Check.eq(#cut.Shots, 2, "only the start value and the shot")
end)

Check.test("a cut leaves out keys first noted after it", function()
	local log = logged("Mode", { { 9, "roam" } })
	local cut = ReplayLog.cut(log, 2, 5, 2)
	Check.eq(cut.Mode, nil, "not yet noted")
end)

Check.test("passed lists the changes going forward between two times", function()
	local log = logged("Shots", { { 1, 1 }, { 2, 2 }, { 3, 3 } })
	local passed = ReplayLog.passed(log, "Shots", 1, 3)
	Check.eq(#passed, 2, "after the start, up to the end")
	Check.eq(passed[1].value, 2, "first")
	Check.eq(passed[2].value, 3, "second")
	Check.eq(#ReplayLog.passed(log, "Shots", 3, 1), 0, "nothing going backward")
	Check.eq(#ReplayLog.passed(log, "Other", 0, 5), 0, "a key never noted")
end)

Check.finish("ReplayLog")
