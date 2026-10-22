--!strict
local Check = require("./Check")
local Fall = require("../src/shared/Fall")

local GRAVITY = 196.2

Check.test("a drop lands on the target after the fall time", function()
	local vx, vz, time = Fall.toward(30, -40, 50, GRAVITY)
	Check.near(time, math.sqrt(2 * 50 / GRAVITY), "fall time")
	Check.near(vx * time, 30, "lands at dx")
	Check.near(vz * time, -40, "lands at dz")
end)

Check.test("a target straight below needs no sideways speed", function()
	local vx, vz = Fall.toward(0, 0, 50, GRAVITY)
	Check.near(vx, 0, "vx")
	Check.near(vz, 0, "vz")
end)

Check.test("a target level with or above the drop just lets go", function()
	local vx, vz, time = Fall.toward(20, 10, 0, GRAVITY)
	Check.eq(vx, 0, "level vx")
	Check.eq(vz, 0, "level vz")
	Check.eq(time, 0, "level time")
	vx, vz = Fall.toward(20, 10, -5, GRAVITY)
	Check.eq(vx, 0, "above vx")
	Check.eq(vz, 0, "above vz")
end)

Check.finish("Fall")
