--!strict
local Check = require("./Check")
local Impact = require("../src/shared/Impact")

-- Velocity changes are in the car's own space, where the nose points to -Z.
-- A hit pushes the car away from whatever it hit.

Check.test("hitting a wall nose first pushes the car back: nose", function()
	Check.eq(Impact.slot(0, 0, 80), "nose")
end)

Check.test("being hit from behind pushes the car forward: tail", function()
	Check.eq(Impact.slot(0, 0, -80), "tail")
end)

Check.test("landing on its roof pushes the car toward its floor: roof", function()
	Check.eq(Impact.slot(0, -80, 0), "roof")
end)

Check.test("landing on its wheels or belly pushes the car up: underside", function()
	Check.eq(Impact.slot(0, 80, 0), "underside")
end)

Check.test("either side is sides", function()
	Check.eq(Impact.slot(80, 0, 0), "sides")
	Check.eq(Impact.slot(-80, 0, 0), "sides")
end)

Check.test("the biggest push wins", function()
	Check.eq(Impact.slot(30, -60, 20), "roof")
	Check.eq(Impact.slot(-50, 40, 45), "sides")
end)

Check.finish("Impact")
