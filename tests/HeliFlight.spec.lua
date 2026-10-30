--!strict
local Check = require("./Check")
local HeliFlight = require("../src/shared/HeliFlight")

local T: HeliFlight.Tuning = {
	UpSpeed = 40,
	DownSpeed = 25,
	HoldGain = 2,
	ClimbGain = 4,
	MaxVertical = 120,
	Accel = 60,
	Brake = 80,
	Coast = 25,
	SideGrip = 150,
	YawShare = 0.5,
	ReverseFraction = 0.5,
	BrakeSpeed = 5,
}
local DT = 1 / 60
local TOP = 100

Check.test("hovering at the held height needs nothing but gravity's share", function()
	Check.eq(HeliFlight.vertical(0, 0, 0, T), 0)
end)

Check.test("below the held height it climbs back, above it sinks back", function()
	Check.eq(HeliFlight.vertical(0, 5, 0, T) > 0, true, "below")
	Check.eq(HeliFlight.vertical(0, -5, 0, T) < 0, true, "above")
end)

Check.test("going back to the held height is no faster than the lift speeds", function()
	Check.near(HeliFlight.vertical(0, 1000, 40, T), 0, "up")
	Check.near(HeliFlight.vertical(0, -1000, -25, T), 0, "down")
end)

Check.test("lift aims for the up and down speeds", function()
	Check.near(HeliFlight.vertical(1, 0, 40, T), 0, "up at speed")
	Check.near(HeliFlight.vertical(-1, 0, -25, T), 0, "down at speed")
	Check.near(HeliFlight.vertical(1, 0, 0, T), 120, "up from a stop, capped")
	Check.near(HeliFlight.vertical(-1, 0, 0, T), -100, "down from a stop")
end)

Check.test("a fast fall is caught at no more than MaxVertical", function()
	Check.eq(HeliFlight.vertical(0, 0, -300, T), 120)
end)

Check.test("gas speeds it up to the car's top speed and no further", function()
	Check.eq(HeliFlight.forward(1, 0, TOP, 0, false, DT, T), 60, "from a stop")
	Check.near(HeliFlight.forward(1, TOP, TOP, 0, false, DT, T), 0, "at top speed")
end)

Check.test("gas never pulls back hard on a car past top speed", function()
	Check.eq(HeliFlight.forward(1, 150, TOP, 0, false, DT, T), -25, "coasts down")
	Check.eq(HeliFlight.forward(1, 150, TOP, 0, true, DT, T), 0, "jets keep the speed")
end)

Check.test("with no input it coasts to a stop, without overshooting", function()
	Check.eq(HeliFlight.forward(0, 50, TOP, 0, false, DT, T), -25, "coasting forward")
	Check.eq(HeliFlight.forward(0, -50, TOP, 0, false, DT, T), 25, "coasting backward")
	Check.near(HeliFlight.forward(0, 0.1, TOP, 0, false, DT, T), -0.1 / DT, "stops exactly")
end)

Check.test("burning jets aren't slowed by the coast", function()
	Check.eq(HeliFlight.forward(0, 50, TOP, 0, true, DT, T), 0)
end)

Check.test("brake slows it, helped by the Brakes upgrade", function()
	Check.eq(HeliFlight.forward(-1, 50, TOP, 0, false, DT, T), -80, "no upgrade")
	Check.eq(HeliFlight.forward(-1, 50, TOP, 40, false, DT, T), -120, "with upgrade")
	Check.eq(HeliFlight.forward(1, -50, TOP, 0, false, DT, T), 80, "gas while backing up")
end)

Check.test("once nearly stopped, brake backs up, slower than forward", function()
	Check.eq(HeliFlight.forward(-1, 2, TOP, 0, false, DT, T), -60, "starts backing up")
	Check.near(HeliFlight.forward(-1, -50, TOP, 0, false, DT, T), 0, "reverse limit")
end)

Check.test("sideways slide is gripped away, up to SideGrip", function()
	Check.eq(HeliFlight.side(100, DT, T), -150, "fast slide")
	Check.eq(HeliFlight.side(-100, DT, T), 150, "other way")
	Check.near(HeliFlight.side(1, DT, T), -1 / DT, "stops exactly")
end)

Check.test("hovering it turns at its share of the turn rate", function()
	Check.near(HeliFlight.yawRate(0, 5, T), 2.5, "standing still")
	Check.near(HeliFlight.yawRate(10, 5, T), 2.5, "slow")
end)

Check.test("fast, it turns only as tight as its side grip can bend its path", function()
	Check.near(HeliFlight.yawRate(150, 5, T), 1, "forward")
	Check.near(HeliFlight.yawRate(-150, 5, T), 1, "backward")
end)

Check.finish("HeliFlight")
