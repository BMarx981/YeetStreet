--!strict
local Check = require("./Check")
local ReplayOrbit = require("../src/shared/ReplayOrbit")

local TUNING: ReplayOrbit.Tuning = {
	MinPitch = 5,
	MaxPitch = 80,
	MinDistance = 10,
	MaxDistance = 100,
}

local RIGHT = math.pi / 2

Check.test("a new orbit keeps its angles and distance inside the limits", function()
	local orbit = ReplayOrbit.new(1, math.rad(30), 40, TUNING)
	Check.near(orbit.yaw, 1, "yaw")
	Check.near(orbit.pitch, math.rad(30), "pitch")
	Check.near(orbit.distance, 40, "distance")
	local wild = ReplayOrbit.new(0, math.rad(120), 500, TUNING)
	Check.near(wild.pitch, math.rad(80), "pitch held at MaxPitch")
	Check.near(wild.distance, 100, "distance held at MaxDistance")
end)

Check.test("turning adds to both angles", function()
	local orbit = ReplayOrbit.turn(ReplayOrbit.new(1, math.rad(30), 40, TUNING), 0.5, math.rad(10), TUNING)
	Check.near(orbit.yaw, 1.5, "yaw")
	Check.near(orbit.pitch, math.rad(40), "pitch")
	Check.near(orbit.distance, 40, "distance unchanged")
end)

Check.test("turning stops at the pitch limits but yaw goes round freely", function()
	local start = ReplayOrbit.new(0, math.rad(30), 40, TUNING)
	Check.near(ReplayOrbit.turn(start, 0, math.rad(90), TUNING).pitch, math.rad(80), "over the top")
	Check.near(ReplayOrbit.turn(start, 0, math.rad(-90), TUNING).pitch, math.rad(5), "under the ground")
	Check.near(ReplayOrbit.turn(start, 10, 0, TUNING).yaw, 10, "many times round")
end)

Check.test("zooming scales the distance inside the limits", function()
	local start = ReplayOrbit.new(0, math.rad(30), 40, TUNING)
	Check.near(ReplayOrbit.zoom(start, 0.5, TUNING).distance, 20, "in")
	Check.near(ReplayOrbit.zoom(start, 2, TUNING).distance, 80, "out")
	Check.near(ReplayOrbit.zoom(start, 0.01, TUNING).distance, 10, "held at MinDistance")
	Check.near(ReplayOrbit.zoom(start, 100, TUNING).distance, 100, "held at MaxDistance")
	Check.near(ReplayOrbit.zoom(start, 0.5, TUNING).yaw, 0, "yaw unchanged")
end)

Check.test("the offset points along yaw round the vertical, tipped up by pitch", function()
	local x, y, z = ReplayOrbit.offset(ReplayOrbit.new(0, math.rad(5), 10, TUNING))
	Check.near(x, 0, "yaw 0 x")
	Check.near(y, 10 * math.sin(math.rad(5)), "yaw 0 y")
	Check.near(z, 10 * math.cos(math.rad(5)), "yaw 0 z")
	x, y, z = ReplayOrbit.offset(ReplayOrbit.new(RIGHT, math.rad(5), 10, TUNING))
	Check.near(x, 10 * math.cos(math.rad(5)), "yaw 90 x")
	Check.near(z, 0, "yaw 90 z")
end)

Check.test("the offset is as long as the distance", function()
	local x, y, z = ReplayOrbit.offset(ReplayOrbit.new(2.3, math.rad(47), 33, TUNING))
	Check.near(math.sqrt(x * x + y * y + z * z), 33, "length")
end)

Check.test("facing gives the yaw that points the offset along a flat direction", function()
	Check.near(ReplayOrbit.facing(0, 1), 0, "+z")
	Check.near(ReplayOrbit.facing(1, 0), RIGHT, "+x")
	local x, _, z = ReplayOrbit.offset(ReplayOrbit.new(ReplayOrbit.facing(-3, -4), math.rad(5), 10, TUNING))
	Check.near(x / z, 3 / 4, "same direction")
	Check.eq(x < 0 and z < 0, true, "same side")
end)

Check.finish("ReplayOrbit")
