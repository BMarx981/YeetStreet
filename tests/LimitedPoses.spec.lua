--!strict
local Check = require("./Check")
local LimitedPoses = require("../src/shared/LimitedPoses")

local CROWN: LimitedPoses.Float = { Bob = 0.3, BobTime = 2, SpinTime = 5 }

Check.test("hue runs from 0 toward 1 over each cycle", function()
	Check.near(LimitedPoses.hue(0, 6), 0)
	Check.near(LimitedPoses.hue(3, 6), 0.5)
	Check.near(LimitedPoses.hue(7.5, 6), 0.25, "second cycle")
end)

Check.test("the crown bobs up and down around its rest height", function()
	local rest = LimitedPoses.crownFloat(0, CROWN)
	local up = LimitedPoses.crownFloat(0.5, CROWN)
	local down = LimitedPoses.crownFloat(1.5, CROWN)
	Check.near(rest, 0)
	Check.near(up, 0.3, "a quarter of the way")
	Check.near(down, -0.3, "three quarters")
end)

Check.test("the crown turns once per SpinTime", function()
	local _, start = LimitedPoses.crownFloat(0, CROWN)
	local _, half = LimitedPoses.crownFloat(2.5, CROWN)
	local _, again = LimitedPoses.crownFloat(5, CROWN)
	Check.near(start, 0)
	Check.near(half, math.pi)
	Check.near(again, 0, "a full turn")
end)

Check.test("ring pieces go evenly round and overlap a little", function()
	local pieces = LimitedPoses.ring(2, 4)
	Check.eq(#pieces, 4)
	Check.near(pieces[1].angle, 0)
	Check.near(pieces[2].angle, math.pi / 2)
	local around = 2 * math.pi * 2 / 4
	Check.eq(pieces[1].length > around, true, "longer than its share")
	Check.eq(pieces[1].length < around * 1.2, true, "but only a little")
end)

Check.finish("LimitedPoses")
