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

Check.test("fully curled, the curl is the curve's plank corners", function()
	local planks = CurveProfile.planks(15, 90, 12)
	local points = CurveProfile.curl(15, 90, 12, 1)
	Check.eq(#points, 13)
	for i, plank in planks do
		local out, up = bottomOf(plank)
		Check.near(points[i].out, out, `corner {i} out`, 1e-9)
		Check.near(points[i].up, up, `corner {i} up`, 1e-9)
	end
	local out, up = topOf(planks[#planks])
	Check.near(points[13].out, out, "top out", 1e-9)
	Check.near(points[13].up, up, "top up", 1e-9)
end)

Check.test("not curled, the curl lies flat as wide as the curve is long", function()
	local points = CurveProfile.curl(15, 90, 12, 0)
	local arc = 15 * math.pi / 2
	for i, point in points do
		Check.near(point.out, arc * (i - 1) / 12, `corner {i} out`)
		Check.near(point.up, 0, `corner {i} up`)
	end
end)

Check.test("half curled, the curl bends half as far, starting flat at the base line", function()
	local points = CurveProfile.curl(15, 90, 12, 0.5)
	Check.near(points[1].out, 0, "starts at the base line")
	Check.near(points[1].up, 0, "starts on the ground")
	Check.near(points[2].up / points[2].out, math.tan(math.rad(45) / 12 / 2), "starts nearly flat", 1e-9)
	local radius = 15 / 0.5
	Check.near(points[13].out, radius * math.sin(math.rad(45)), "top out")
	Check.near(points[13].up, radius * (1 - math.cos(math.rad(45))), "top up")
end)

Check.test("clipped at a height, the curve stops on it and runs flat out to the reach", function()
	local points = CurveProfile.clip(15, 90, 10, 5, 17)
	Check.eq(#points, 12, "the curve's corners and one more for the flat")
	Check.near(points[1].out, 0, "starts at the base line")
	Check.near(points[1].up, 0, "starts on the ground")
	for i = 1, 11 do
		local p = points[i]
		Check.near(p.out ^ 2 + (15 - p.up) ^ 2, 15 ^ 2, `corner {i} on the curve`, 1e-6)
	end
	Check.near(points[11].up, 5, "stops at the height")
	Check.near(points[11].out, math.sqrt(15 ^ 2 - 10 ^ 2), "where the curve reaches it")
	Check.near(points[12].out, 17, "flat out to the reach")
	Check.near(points[12].up, 5, "at the height")
end)

Check.test("clipped above its top, the curve is whole and the flat runs along its top", function()
	local points = CurveProfile.clip(15, 90, 10, 40, 17)
	local whole = CurveProfile.curl(15, 90, 10, 1)
	for i = 1, 11 do
		Check.near(points[i].out, whole[i].out, `corner {i} out`)
		Check.near(points[i].up, whole[i].up, `corner {i} up`)
	end
	Check.near(points[12].out, 17)
	Check.near(points[12].up, 15)
end)

Check.test("clipped at the ground, the curve shrinks to its base and the flat lies on the ground", function()
	local points = CurveProfile.clip(15, 90, 10, 0, 17)
	for i = 1, 11 do
		Check.near(points[i].out, 0, `corner {i} out`)
		Check.near(points[i].up, 0, `corner {i} up`)
	end
	Check.near(points[12].out, 17)
	Check.near(points[12].up, 0)
end)

Check.test("an arc of the curve runs between two angles, its corners on the curve", function()
	local points = CurveProfile.arc(30, 90, 120, 3)
	Check.eq(#points, 4)
	Check.near(points[1].out, 30, "starts straight up, a radius out")
	Check.near(points[1].up, 30, "and a radius up")
	Check.near(points[4].out, 30 * math.sin(math.rad(120)), "ends leaning back")
	Check.near(points[4].up, 45, "half a radius higher")
	for i, p in points do
		Check.near(p.out ^ 2 + (30 - p.up) ^ 2, 30 ^ 2, `corner {i} on the curve`, 1e-6)
	end
end)

Check.test("a slice of a swept corner is long enough to meet its neighbors", function()
	Check.near(CurveProfile.sliceLength(100, 90), 200)
	Check.near(CurveProfile.sliceLength(100, 10), 2 * 100 * math.tan(math.rad(5)))
end)

Check.finish("CurveProfile")
