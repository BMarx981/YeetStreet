--!strict
local Check = require("./Check")
local Railway = require("../src/shared/Railway")
local Tunnel = require("../src/shared/Tunnel")

local LINE: Railway.Line = {
	High = 40,
	Low = -34,
	Corner = 120,
	StreetZ = { 200, -600 },
	StripX = 980,
}

Check.test("the loop starts on the elevated street heading +X", function()
	local start = Railway.start(LINE)
	Check.near(start.x, -860, "a corner in from the west strip")
	Check.near(start.z, 200, "on the elevated street")
	Check.near(start.y, 40, "up high")
	Check.near(start.headingX, 1)
end)

Check.test("the loop closes where it started, on the level", function()
	local start = Railway.start(LINE)
	local pieces, finish =
		Tunnel.path(start.x, start.z, start.headingX, start.headingZ, Railway.segments(LINE), start.y)
	Check.eq(#pieces, 8)
	Check.near(finish.x, start.x, "x", 1e-6)
	Check.near(finish.z, start.z, "z", 1e-6)
	Check.near(finish.y, start.y, "height", 1e-6)
	Check.near(finish.headingX, 1, "heading", 1e-6)
end)

Check.test("the east strip ramps down to the subway street", function()
	local start = Railway.start(LINE)
	local pieces = Tunnel.path(start.x, start.z, start.headingX, start.headingZ, Railway.segments(LINE), start.y)
	local ramp = pieces[3]
	Check.near(ramp.fromX, 980, "down the east strip")
	Check.near(ramp.fromZ, 80)
	Check.near(ramp.toZ, -480)
	Check.near(ramp.fromY, 40)
	Check.near(ramp.toY, -34)
	Check.near(pieces[5].fromZ, -600, "along the subway street")
	Check.near(pieces[5].fromY, -34)
end)

Check.test("a distance along the loop is found on its piece, wrapping round", function()
	local index, t = Railway.locate({ 100, 50, 50 }, 125)
	Check.eq(index, 2)
	Check.near(t, 0.5)
	index, t = Railway.locate({ 100, 50, 50 }, 210)
	Check.eq(index, 1, "past the end wraps to the start")
	Check.near(t, 0.1)
	index, t = Railway.locate({ 100, 50, 50 }, -20)
	Check.eq(index, 3, "before the start wraps to the end")
	Check.near(t, 0.6)
end)

Check.test("trains spread evenly round the loop, carriages one behind the next", function()
	local trains: Railway.Trains = { Count = 2, Carriages = 3, Length = 40, Gap = 4, Speed = 50 }
	local spans = Railway.carriages(1000, 2, trains)
	Check.eq(#spans, 6)
	Check.near(spans[1].front, 100, "the first train has gone Speed times the time")
	Check.near(spans[1].back, 60)
	Check.near(spans[2].front, 56, "a gap behind")
	Check.near(spans[4].front, 600, "the second train half a loop on")
	Check.eq(spans[4].train, 2)
end)

local PUSH = { Margin = 2, Depth = 4, Ahead = 1.25, Side = 8 }

Check.test("a car in front of a train is pushed ahead faster than the train", function()
	local va, vc, vu = Railway.push(22, 1, 0, 10, 0, 0, 20, 10, 7, 50, PUSH)
	Check.near(va :: number, 62.5, "ahead")
	Check.near(vc :: number, 8, "nudged to its side")
	Check.near(vu :: number, 0)
end)

Check.test("a car already pulling away from a train is left alone ahead", function()
	local va = Railway.push(22, -1, 0, 90, -20, 0, 20, 10, 7, 50, PUSH)
	Check.near(va :: number, 90, "already faster")
end)

Check.test("a car just inside the train's nose is still pushed out ahead", function()
	local va = Railway.push(17, 0, 0, 0, 0, 0, 20, 10, 7, 50, PUSH)
	Check.near(va :: number, 62.5)
end)

Check.test("only the train's nose pushes", function()
	Check.eq(Railway.push(15, 0, 0, 0, 0, 0, 20, 10, 7, 50, PUSH), nil, "deeper inside than Depth")
	Check.eq(Railway.push(0, 11, 0, 0, 0, 0, 20, 10, 7, 50, PUSH), nil, "beside its middle")
	Check.eq(Railway.push(-21, 0, 0, 0, 0, 0, 20, 10, 7, 50, PUSH), nil, "behind its tail")
end)

Check.test("a car clear of a train is not pushed", function()
	Check.eq(Railway.push(23, 0, 0, 0, 0, 0, 20, 10, 7, 50, PUSH), nil, "ahead of it")
	Check.eq(Railway.push(21, 13, 0, 0, 0, 0, 20, 10, 7, 50, PUSH), nil, "beside its nose")
	Check.eq(Railway.push(21, 0, 10, 0, 0, 0, 20, 10, 7, 50, PUSH), nil, "above its nose")
end)

Check.test("touches is where the nose pushes, slack further each way", function()
	Check.eq(Railway.touches(22, 1, 0, 20, 10, 7, PUSH, 0), true, "in front of the nose")
	Check.eq(Railway.touches(23, 0, 0, 20, 10, 7, PUSH, 0), false, "past Margin")
	Check.eq(Railway.touches(23, 0, 0, 20, 10, 7, PUSH, 3), true, "within slack past Margin")
	Check.eq(Railway.touches(21, 14, 0, 20, 10, 7, PUSH, 3), true, "within slack beside the nose")
	Check.eq(Railway.touches(0, 11, 0, 20, 10, 7, PUSH, 3), false, "beside its middle")
end)

Check.test("cutting a hole from a tile leaves the four pieces around it", function()
	local pieces = Railway.cut({ x1 = 0, x2 = 100, z1 = 0, z2 = 100 }, { { x1 = 40, x2 = 60, z1 = 30, z2 = 70 } })
	Check.eq(#pieces, 4)
	local area = 0
	for _, piece in pieces do
		area += (piece.x2 - piece.x1) * (piece.z2 - piece.z1)
	end
	Check.near(area, 100 * 100 - 20 * 40, "everything but the hole")
end)

Check.test("a hole past a tile's edge cuts only what it covers", function()
	local pieces = Railway.cut({ x1 = 0, x2 = 100, z1 = 0, z2 = 100 }, { { x1 = 80, x2 = 150, z1 = -10, z2 = 30 } })
	local area = 0
	for _, piece in pieces do
		area += (piece.x2 - piece.x1) * (piece.z2 - piece.z1)
	end
	Check.near(area, 100 * 100 - 20 * 30)
	Check.eq(
		#Railway.cut({ x1 = 0, x2 = 100, z1 = 0, z2 = 100 }, { { x1 = 200, x2 = 300, z1 = 0, z2 = 10 } }),
		1,
		"a hole elsewhere leaves it whole"
	)
end)

Check.finish("Railway")
