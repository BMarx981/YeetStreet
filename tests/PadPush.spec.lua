--!strict
local Check = require("./Check")
local PadPush = require("../src/shared/PadPush")

Check.test("an any-way pad throws the car the way it is going, tipped up", function()
	local x, y, z = PadPush.anyWay(50, 0, math.rad(25), 1)
	Check.near(x, math.cos(math.rad(25)), "x")
	Check.near(y, math.sin(math.rad(25)), "y")
	Check.near(z, 0, "z")
end)

Check.test("it goes by the car's way across the ground, not up or down", function()
	local x, y, z = PadPush.anyWay(-30, 40, math.rad(25), 1)
	local flat = math.cos(math.rad(25))
	Check.near(x, -0.6 * flat, "x")
	Check.near(y, math.sin(math.rad(25)), "y")
	Check.near(z, 0.8 * flat, "z")
end)

Check.test("a car barely moving across the ground has no way to go", function()
	local x = PadPush.anyWay(0.5, 0.5, math.rad(25), 1)
	Check.eq(x, nil, "no push")
end)

Check.test("a pad speeds up a car going slower than its speed", function()
	Check.near(PadPush.change(80, 130, false) :: number, 50)
end)

Check.test("a pad leaves a faster car alone", function()
	Check.eq(PadPush.change(200, 130, false), nil)
end)

Check.test("an exact pad slows a faster car to its speed", function()
	Check.near(PadPush.change(200, 130, true) :: number, -70)
end)

Check.test("an exact pad still speeds up a slower car", function()
	Check.near(PadPush.change(80, 130, true) :: number, 50)
end)

Check.finish("PadPush")
