--!strict
local Check = require("./Check")
local MapLayout = require("../src/shared/MapLayout")

local BOUNDS: MapLayout.Bounds = { MinX = -1000, MaxX = 1000, MinZ = -1000, MaxZ = 1000 }

local function area(id: string, x: number, z: number, width: number, depth: number): MapLayout.Area
	return {
		Id = id,
		Name = id,
		Kind = "Park",
		X = x,
		Z = z,
		Width = width,
		Depth = depth,
		ArriveX = x,
		ArriveZ = z,
		Heading = 0,
	}
end

local function has(problems: { string }, text: string): boolean
	for _, problem in problems do
		if string.find(problem, text, 1, true) then
			return true
		end
	end
	return false
end

Check.test("areas apart do not overlap", function()
	Check.eq(MapLayout.overlaps(area("A", 0, 0, 100, 100), area("B", 300, 0, 100, 100), 50), false)
end)

Check.test("areas that cross overlap", function()
	Check.eq(MapLayout.overlaps(area("A", 0, 0, 100, 100), area("B", 80, 20, 100, 100), 0), true)
end)

Check.test("areas closer than the gap overlap", function()
	-- Edges 20 apart, gap 50.
	Check.eq(MapLayout.overlaps(area("A", 0, 0, 100, 100), area("B", 120, 0, 100, 100), 50), true)
	Check.eq(MapLayout.overlaps(area("A", 0, 0, 100, 100), area("B", 120, 0, 100, 100), 10), false)
end)

Check.test("contains is true inside and on the edge, false outside", function()
	local a = area("A", 0, 0, 100, 200)
	Check.eq(MapLayout.contains(a, 10, -90), true, "inside")
	Check.eq(MapLayout.contains(a, 50, 100), true, "corner")
	Check.eq(MapLayout.contains(a, 51, 0), false, "past the side")
	Check.eq(MapLayout.contains(a, 0, -101), false, "past the front")
end)

Check.test("a good layout has no problems", function()
	local problems = MapLayout.problems({ area("A", -500, 0, 200, 200), area("B", 500, 0, 200, 200) }, BOUNDS, 100)
	Check.eq(#problems, 0)
end)

Check.test("overlapping areas are a problem naming both", function()
	local problems = MapLayout.problems({ area("A", 0, 0, 200, 200), area("B", 150, 0, 200, 200) }, BOUNDS, 0)
	Check.eq(#problems, 1)
	Check.eq(has(problems, "A") and has(problems, "B"), true)
end)

Check.test("an area past the bounds is a problem", function()
	local problems = MapLayout.problems({ area("Far", 950, 0, 200, 200) }, BOUNDS, 0)
	Check.eq(has(problems, "Far"), true)
end)

Check.test("an arrival point outside its own area is a problem", function()
	local a = area("A", 0, 0, 200, 200)
	a.ArriveX = 300
	local problems = MapLayout.problems({ a }, BOUNDS, 0)
	Check.eq(has(problems, "A"), true)
end)

Check.test("a repeated id is a problem", function()
	local problems = MapLayout.problems({ area("A", -500, 0, 100, 100), area("A", 500, 0, 100, 100) }, BOUNDS, 0)
	Check.eq(has(problems, "A"), true)
end)

Check.test("find returns the area with that id, or nil", function()
	local areas = { area("A", 0, 0, 10, 10), area("B", 100, 0, 10, 10) }
	local found = MapLayout.find(areas, "B")
	Check.eq(found and found.X, 100)
	Check.eq(MapLayout.find(areas, "C"), nil)
end)

Check.finish("MapLayout")
