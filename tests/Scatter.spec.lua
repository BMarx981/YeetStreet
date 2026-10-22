--!strict
local Check = require("./Check")
local Rng = require("../src/shared/Rng")
local Scatter = require("../src/shared/Scatter")

local RECT: Scatter.Rect = { MinX = -500, MaxX = 500, MinZ = -1000, MaxZ = 1000 }

Check.test("distanceTo a line is square to it between its ends, and to the nearer end past them", function()
	local line: Scatter.Line = { AX = 0, AZ = 0, BX = 100, BZ = 0, Radius = 10 }
	Check.near(Scatter.distanceTo(line, 50, 30), 30, "beside the middle")
	Check.near(Scatter.distanceTo(line, -30, 40), 50, "past the start")
	Check.near(Scatter.distanceTo(line, 130, -40), 50, "past the end")
	local dot: Scatter.Line = { AX = 5, AZ = 5, BX = 5, BZ = 5, Radius = 10 }
	Check.near(Scatter.distanceTo(dot, 8, 9), 5, "a line with no length is a point")
end)

Check.test("every point is inside the rectangle", function()
	for _, p in Scatter.points(Rng.new(3), 40, RECT, 50, {}) do
		Check.eq(p.x >= RECT.MinX and p.x <= RECT.MaxX, true, `x {p.x}`)
		Check.eq(p.z >= RECT.MinZ and p.z <= RECT.MaxZ, true, `z {p.z}`)
	end
end)

Check.test("points are at least the gap apart", function()
	local points = Scatter.points(Rng.new(3), 40, RECT, 120, {})
	Check.eq(#points, 40, "room for all of them")
	for i = 1, #points do
		for j = i + 1, #points do
			local d = math.sqrt((points[i].x - points[j].x) ^ 2 + (points[i].z - points[j].z) ^ 2)
			Check.eq(d >= 120, true, `points {i} and {j} are {d} apart`)
		end
	end
end)

Check.test("no point lands within a keep-out line's radius", function()
	local keepOut: { Scatter.Line } = {
		{ AX = -500, AZ = -1000, BX = 500, BZ = 1000, Radius = 150 },
		{ AX = 300, AZ = -600, BX = 300, BZ = -600, Radius = 200 },
	}
	local points = Scatter.points(Rng.new(9), 30, RECT, 60, keepOut)
	Check.eq(#points > 0, true, "some fit")
	for _, p in points do
		for k, line in keepOut do
			Check.eq(Scatter.distanceTo(line, p.x, p.z) >= line.Radius, true, `point in keep-out {k}`)
		end
	end
end)

Check.test("the same seed gives the same points", function()
	local a = Scatter.points(Rng.new(21), 20, RECT, 80, {})
	local b = Scatter.points(Rng.new(21), 20, RECT, 80, {})
	Check.eq(#a, #b, "count")
	for i = 1, #a do
		Check.eq(a[i].x, b[i].x, `x {i}`)
		Check.eq(a[i].z, b[i].z, `z {i}`)
	end
end)

Check.test("a crowded rectangle gives back fewer points instead of looping forever", function()
	local small: Scatter.Rect = { MinX = 0, MaxX = 100, MinZ = 0, MaxZ = 100 }
	local points = Scatter.points(Rng.new(5), 50, small, 60, {})
	Check.eq(#points >= 1 and #points <= 5, true, `{#points} points`)
end)

Check.finish("Scatter")
