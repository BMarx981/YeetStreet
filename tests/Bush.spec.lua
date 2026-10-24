--!strict
local Check = require("./Check")
local Bush = require("../src/shared/Bush")

local TUNING: Bush.Tuning = {
	MinSpeed = 4,
	Rise = 5,
	Fade = 2,
	Tilt = 10,
	Rate = 3,
}

Check.test("a car moving through a bush rustles it, up to full", function()
	local level = 0
	level = Bush.rustle(level, true, 30, 0.1, TUNING)
	Check.near(level, 0.5, "half a second of rise in a tenth")
	level = Bush.rustle(level, true, 30, 0.5, TUNING)
	Check.near(level, 1, "never past full")
end)

Check.test("a car stopped in a bush, or one only crawling, leaves it still", function()
	Check.near(Bush.rustle(0, true, 0, 0.5, TUNING), 0, "stopped")
	Check.near(Bush.rustle(0, true, 3.9, 0.5, TUNING), 0, "under MinSpeed")
end)

Check.test("a rustle fades away once the car is gone", function()
	local level = Bush.rustle(1, false, 30, 0.25, TUNING)
	Check.near(level, 0.5, "fading")
	level = Bush.rustle(level, false, 0, 1, TUNING)
	Check.near(level, 0, "never below still")
end)

Check.test("a still bush stands straight, and a rustling one leans at most Tilt", function()
	for t = 0, 2, 0.05 do
		Check.near(Bush.sway(0, t, 1.3, TUNING), 0, `still at {t}`)
		local lean = Bush.sway(1, t, 1.3, TUNING)
		Check.eq(math.abs(lean) <= math.rad(TUNING.Tilt) + 1e-9, true, `lean {lean} at {t}`)
	end
end)

Check.test("a rustling bush swings both ways", function()
	local most, least = 0, 0
	for t = 0, 1, 0.01 do
		local lean = Bush.sway(1, t, 0, TUNING)
		most, least = math.max(most, lean), math.min(least, lean)
	end
	Check.near(most, math.rad(TUNING.Tilt), "leans out", 0.01)
	Check.near(least, -math.rad(TUNING.Tilt), "and back", 0.01)
end)

Check.finish("Bush")
