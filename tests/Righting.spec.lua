--!strict
local Check = require("./Check")
local Righting = require("../src/shared/Righting")

local TUNING: Righting.Tuning = {
	StartUpY = 0.5,
	EndUpY = 0.95,
	LandWheels = 2,
	Rate = 4,
	SlowAngle = math.rad(30),
	TubeExit = 2,
}

Check.test("lying needs no wheels down, tipped over, and ground close below", function()
	Check.eq(Righting.lying(0, -1, true, TUNING), true, "on its roof")
	Check.eq(Righting.lying(0, 0, true, TUNING), true, "on its side")
	Check.eq(Righting.lying(1, -1, true, TUNING), false, "a wheel is down")
	Check.eq(Righting.lying(0, 0.9, true, TUNING), false, "upright")
	Check.eq(Righting.lying(0, -1, false, TUNING), false, "high in the air")
end)

Check.test("righting starts when lying and holds until upright", function()
	Check.eq(Righting.step(false, true, 0, -1, TUNING), true, "starts")
	Check.eq(Righting.step(true, false, 0, 0.7, TUNING), true, "past the start angle, keeps going")
	Check.eq(Righting.step(true, false, 0, 0.96, TUNING), false, "upright")
	Check.eq(Righting.step(true, false, 2, 0.7, TUNING), false, "wheels down")
	Check.eq(Righting.step(false, false, 0, 0.7, TUNING), false, "never started")
end)

Check.test("just out of a tube on its wall or roof, it rights in the air", function()
	Check.eq(Righting.afterTube(0.5, true, -1, TUNING), true, "off the roof")
	Check.eq(Righting.afterTube(0.5, true, 0, TUNING), true, "off the wall")
	Check.eq(Righting.afterTube(1.9, true, 0, TUNING), true, "still falling")
	Check.eq(Righting.afterTube(0.5, true, 0.9, TUNING), false, "came out upright")
	Check.eq(Righting.afterTube(0.5, false, -1, TUNING), false, "wheels still on the mouth's wall")
	Check.eq(Righting.afterTube(2.5, true, -1, TUNING), false, "left the tube long ago")
end)

Check.test("upright needs no turn", function()
	local x, y, z = Righting.rate(0, 1, 0, 0, 0, -1, TUNING)
	Check.eq(x, 0)
	Check.eq(y, 0)
	Check.eq(z, 0)
end)

Check.test("on its side it turns the roof up the short way", function()
	-- Roof pointing +X: turning about +Z swings +X up to +Y.
	local x, y, z = Righting.rate(1, 0, 0, 0, 0, -1, TUNING)
	Check.near(x, 0)
	Check.near(y, 0)
	Check.near(z, 4, "full rate when far from upright")
end)

Check.test("flat on its roof it rolls about its length", function()
	local x, y, z = Righting.rate(0, -1, 0, 0, 0, -1, TUNING)
	Check.near(math.sqrt(x * x + y * y + z * z), 4)
	Check.near(z, -4, "about the nose")
end)

Check.test("tipped a little off its roof, it keeps falling the way it leans", function()
	local tilt = math.rad(10)
	local x, _, z = Righting.rate(math.sin(tilt), -math.cos(tilt), 0, 0, 0, -1, TUNING)
	Check.near(x, 0)
	Check.near(z, 4)
end)

Check.test("it slows down near upright", function()
	local tilt = math.rad(15)
	local _, _, z = Righting.rate(math.sin(tilt), math.cos(tilt), 0, 0, 0, -1, TUNING)
	Check.near(z, 2, "half way into the slow angle, half the rate")
end)

Check.finish("Righting")
