--!strict
local Check = require("./Check")
local Silo = require("../src/shared/Silo")

local SHAPE: Silo.Shape = {
	Radius = 250,
	LipRadius = 60,
	Depth = 600,
	Margin = 20,
	Ramp = { Pitch = 80 },
}

Check.test("the rim is the shaft plus the lip", function()
	Check.near(Silo.rimRadius(SHAPE), 310)
end)

Check.test("the lip runs from the top of the straight wall out to the ground", function()
	local r, y = Silo.lipPoint(SHAPE, 0)
	Check.near(r, 250, "bottom radius")
	Check.near(y, -60, "bottom height")
	r, y = Silo.lipPoint(SHAPE, math.pi / 2)
	Check.near(r, 310, "top radius")
	Check.near(y, 0, "top height", 1e-9)
end)

Check.test("the ramp starts level with the ground and ends on the bottom", function()
	local sweep = Silo.rampSweep(SHAPE)
	Check.near(sweep, 2 * math.pi * 7.5)
	local x, y, z = Silo.rampPoint(SHAPE, 90, 0)
	Check.near(x, 90, "start x")
	Check.near(y, 0, "start height")
	Check.near(z, 0, "start z")
	_, y = Silo.rampPoint(SHAPE, 90, sweep)
	Check.near(y, -600, "end height")
end)

Check.test("the ramp leaves its start heading -Z, along the bridge", function()
	local _, _, z = Silo.rampPoint(SHAPE, 90, 0.01)
	Check.eq(z < 0, true)
end)

Check.test("one turn of the ramp drops one pitch and comes back round", function()
	local x, y, z = Silo.rampPoint(SHAPE, 90, 2 * math.pi)
	Check.near(x, 90, "x")
	Check.near(y, -80, "drop")
	Check.near(z, 0, "z", 1e-9)
end)

Check.test("a square's edge is found along a ray from its middle", function()
	local x, z = Silo.squareEdge(100, 0)
	Check.near(x, 100, "east x")
	Check.near(z, 0, "east z", 1e-9)
	x, z = Silo.squareEdge(100, math.pi / 4)
	Check.near(x, 100, "corner x")
	Check.near(z, 100, "corner z")
	x, z = Silo.squareEdge(100, math.atan2(-1, 2))
	Check.near(x, 100, "shallow x")
	Check.near(z, -50, "shallow z")
end)

Check.test("inside is under the ground, within the rim, and not far below the bottom", function()
	Check.eq(Silo.inside(SHAPE, 0, -300, 0), true, "middle")
	Check.eq(Silo.inside(SHAPE, 305, -5, 0), true, "under the rim")
	Check.eq(Silo.inside(SHAPE, 0, 5, 0), false, "above the ground")
	Check.eq(Silo.inside(SHAPE, 320, -5, 0), false, "past the rim")
	Check.eq(Silo.inside(SHAPE, 0, -615, 0), true, "within the margin")
	Check.eq(Silo.inside(SHAPE, 0, -625, 0), false, "through the bottom")
end)

Check.finish()
