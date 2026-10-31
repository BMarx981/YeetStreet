--!strict
local Check = require("./Check")
local Silo = require("../src/shared/Silo")

local SHAPE: Silo.Shape = {
	Radius = 250,
	LipRadius = 60,
	Depth = 600,
	Margin = 20,
	BaseRadius = 50,
	Ramp = { Pitch = 80, OuterRadius = 130, LipHeight = 9, LipGrow = 65 },
	Wall = { Reach = 14 },
}

local DIAGONAL = math.sqrt(0.5)

Check.test("the base curve runs from the bottom up to the straight wall", function()
	local r, y = Silo.basePoint(SHAPE, 0)
	Check.near(r, 200, "floor radius")
	Check.near(y, -600, "floor height")
	r, y = Silo.basePoint(SHAPE, math.pi / 2)
	Check.near(r, 250, "wall radius")
	Check.near(y, -550, "wall height")
end)

Check.test("the straight wall pulls straight out, within reach of it", function()
	local x, y, z = Silo.wallPull(SHAPE, 240, -300, 0)
	Check.near(x :: number, 1, "x")
	Check.near(y :: number, 0, "y", 1e-9)
	Check.near(z :: number, 0, "z", 1e-9)
	x, y, z = Silo.wallPull(SHAPE, 0, -300, 240)
	Check.near(x :: number, 0, "other side x", 1e-9)
	Check.near(z :: number, 1, "other side z")
	Check.eq(Silo.wallPull(SHAPE, 230, -300, 0), nil, "out of reach")
end)

Check.test("the lip pulls into its curve", function()
	-- 5 off the surface, halfway round the curve.
	local at = 60 * DIAGONAL
	local x, y, z = Silo.wallPull(SHAPE, 310 - at - 5 * DIAGONAL, -60 + at + 5 * DIAGONAL, 0)
	Check.near(x :: number, DIAGONAL, "x")
	Check.near(y :: number, -DIAGONAL, "y")
	Check.near(z :: number, 0, "z", 1e-9)
end)

Check.test("the base curve pulls down and out into it", function()
	-- 5 off the surface, halfway round the curve.
	local at = 45 * DIAGONAL
	local x, y = Silo.wallPull(SHAPE, 200 + at, -550 - at, 0)
	Check.near(x :: number, DIAGONAL, "x")
	Check.near(y :: number, -DIAGONAL, "y")
end)

Check.test("nothing pulls on the floor, over the ground, or past the rim", function()
	Check.eq(Silo.wallPull(SHAPE, 90, -595, 0), nil, "the floor's middle")
	Check.eq(Silo.wallPull(SHAPE, 90, -300, 0), nil, "the ramp")
	Check.eq(Silo.wallPull(SHAPE, 300, 5, 0), nil, "over the ground")
	Check.eq(Silo.wallPull(SHAPE, 320, -5, 0), nil, "past the rim")
end)

Check.test("a slow car peels off and stays off until it leaves the wall", function()
	Check.eq(Silo.stepPeel(false, true, 60, 40), false, "fast enough")
	Check.eq(Silo.stepPeel(false, true, 30, 40), true, "too slow")
	Check.eq(Silo.stepPeel(true, true, 60, 40), true, "falling fast is still off")
	Check.eq(Silo.stepPeel(true, false, 0, 40), false, "away from the wall")
end)

Check.test("the ramp's lip grows in from nothing at both ends", function()
	local sweep = Silo.rampSweep(SHAPE)
	Check.near(Silo.rampLipHeight(SHAPE, 0), 0, "start")
	Check.near(Silo.rampLipHeight(SHAPE, 0.25), 4.5, "halfway in")
	Check.near(Silo.rampLipHeight(SHAPE, 0.5), 9, "full height")
	Check.near(Silo.rampLipHeight(SHAPE, sweep / 2), 9, "middle")
	Check.near(Silo.rampLipHeight(SHAPE, sweep - 0.25), 4.5, "halfway out")
	Check.near(Silo.rampLipHeight(SHAPE, sweep), 0, "end")
end)

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
