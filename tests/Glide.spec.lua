--!strict
local Check = require("./Check")
local Glide = require("../src/shared/Glide")

local T: Glide.Tuning = {
	Lift = 0.04,
	Side = 0.03,
	Drag = 0.05,
	MaxAccel = 200,
}

Check.test("a car standing still in the air gets no push", function()
	local ax, ay, az = Glide.accel(0, 0, 0, T)
	Check.eq(ax, 0, "x")
	Check.eq(ay, 0, "y")
	Check.eq(az, 0, "z")
end)

Check.test("falling flat, the wings push the car up", function()
	local ax, ay, az = Glide.accel(0, -50, 0, T)
	Check.near(ax, 0, "x")
	Check.near(ay, 0.04 * 50 * 50, "y")
	Check.near(az, 0, "z")
end)

Check.test("flying straight along the nose only meets a little drag", function()
	local ax, ay, az = Glide.accel(0, 0, -100, T)
	Check.near(ax, 0, "x")
	Check.near(ay, 0, "y")
	Check.near(az, 0.05 * 100, "z, back against the motion")
end)

Check.test("the push across the wings grows with speed", function()
	local _, slow = Glide.accel(0, -10, -50, T)
	local _, fast = Glide.accel(0, -10, -100, T)
	Check.eq(fast > slow, true, "faster lifts more")
	Check.eq(slow > 0, true, "slow still lifts")
end)

Check.test("slipping sideways, the fin pushes back the other way", function()
	local right = Glide.accel(30, 0, -100, T)
	local left = Glide.accel(-30, 0, -100, T)
	Check.eq(right < 0, true, "slipping right is pushed left")
	Check.eq(left > 0, true, "slipping left is pushed right")
end)

Check.test("the push across the wings and fin is capped at MaxAccel", function()
	local ax, ay = Glide.accel(-300, -300, -50, T)
	Check.near(math.sqrt(ax * ax + ay * ay), 200, "capped")
	Check.eq(ax > 0 and ay > 0, true, "still against the motion")
end)

Check.finish("Glide")
