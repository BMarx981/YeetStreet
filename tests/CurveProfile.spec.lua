--!strict
local Check = require("./Check")
local CurveProfile = require("../src/shared/CurveProfile")

local function topOf(plank: CurveProfile.Plank): (number, number)
	return plank.out + plank.length / 2 * math.cos(plank.tilt), plank.up + plank.length / 2 * math.sin(plank.tilt)
end

local function bottomOf(plank: CurveProfile.Plank): (number, number)
	return plank.out - plank.length / 2 * math.cos(plank.tilt), plank.up - plank.length / 2 * math.sin(plank.tilt)
end

Check.test("one plank per step", function()
	Check.eq(#CurveProfile.planks(60, 90, 10), 10)
end)

Check.test("a plank is the chord of its slice of the curve", function()
	local plank = CurveProfile.planks(60, 90, 2)[1]
	local half = math.rad(45)
	Check.near(plank.out, 60 * math.sin(half) / 2, "out")
	Check.near(plank.up, 60 * (1 - math.cos(half)) / 2, "up")
	Check.near(plank.length, 2 * 60 * math.sin(half / 2), "length")
	Check.near(plank.tilt, half / 2, "tilt")
end)

Check.test("the planks run end to end from the ground to the top of the curve", function()
	local planks = CurveProfile.planks(60, 120, 13)
	local startOut, startUp = bottomOf(planks[1])
	Check.near(startOut, 0, "starts at the base line")
	Check.near(startUp, 0, "starts on the ground")
	for i = 2, #planks do
		local prevOut, prevUp = topOf(planks[i - 1])
		local out, up = bottomOf(planks[i])
		Check.near(out, prevOut, `plank {i} meets the last`, 1e-9)
		Check.near(up, prevUp, `plank {i} meets the last`, 1e-9)
	end
	local endOut, endUp = topOf(planks[#planks])
	Check.near(endOut, 60 * math.sin(math.rad(120)), "ends leaning back")
	Check.near(endUp, 90, "ends at the top")
end)

Check.test("past vertical the planks lean back", function()
	local planks = CurveProfile.planks(60, 120, 12)
	Check.eq(planks[#planks].tilt > math.pi / 2, true)
end)

Check.test("extent of a quarter pipe and a lean-back wall", function()
	local depth, height = CurveProfile.extent(60, 90)
	Check.near(depth, 60)
	Check.near(height, 60)
	depth, height = CurveProfile.extent(60, 120)
	Check.near(depth, 60, "deepest at vertical")
	Check.near(height, 90)
	depth, height = CurveProfile.extent(60, 45)
	Check.near(depth, 60 * math.sin(math.rad(45)), "a ramp short of vertical")
	Check.near(height, 60 * (1 - math.cos(math.rad(45))))
end)

Check.test("a slice of a swept corner is long enough to meet its neighbors", function()
	Check.near(CurveProfile.sliceLength(100, 90), 200)
	Check.near(CurveProfile.sliceLength(100, 10), 2 * 100 * math.tan(math.rad(5)))
end)

Check.finish("CurveProfile")
