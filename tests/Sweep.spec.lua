--!strict
local Check = require("./Check")
local Sweep = require("../src/shared/Sweep")

-- A thin board centered on the origin: 14 wide, 8 tall, 1 thick.
local function hits(ax: number, ay: number, az: number, bx: number, by: number, bz: number): boolean
	return Sweep.hitsBox(ax, ay, az, bx, by, bz, 7, 4, 0.5)
end

Check.test("a path through the box hits", function()
	Check.eq(hits(0, 0, 10, 0, 0, -10), true)
end)

Check.test("a fast path that starts and ends either side of a thin box hits", function()
	Check.eq(hits(2, 1, 3, 2, 1, -3), true, "neither end is inside")
end)

Check.test("a path that passes beside the box misses", function()
	Check.eq(hits(10, 0, 10, 10, 0, -10), false, "to the side")
	Check.eq(hits(0, 6, 10, 0, 6, -10), false, "over the top")
end)

Check.test("a path that stops short of the box misses", function()
	Check.eq(hits(0, 0, 10, 0, 0, 1), false)
end)

Check.test("a path that ends inside the box hits", function()
	Check.eq(hits(0, 0, 10, 0, 0, 0.2), true)
end)

Check.test("a diagonal path that clips a corner hits, one that misses it does not", function()
	Check.eq(hits(6, 0, 2, 8, 0, -2), true, "crosses x = 7 after passing z = 0.5")
	Check.eq(hits(7.5, 0, 2, 9, 0, -2), false)
end)

Check.test("a car standing still hits only from inside", function()
	Check.eq(hits(1, 1, 0, 1, 1, 0), true)
	Check.eq(hits(1, 1, 3, 1, 1, 3), false)
end)

Check.finish("Sweep")
