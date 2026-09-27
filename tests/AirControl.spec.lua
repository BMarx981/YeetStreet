--!strict
local Check = require("./Check")
local AirControl = require("../src/shared/AirControl")

local scales = { pitch = 1, yaw = 1, roll = 1, invertPitch = false }

-- Chassis-local axes: +x pitch lifts the nose, +y yaw swings the nose left,
-- +z roll lifts the right side.

Check.test("gas tips the nose down", function()
	local x = AirControl.targetRates(0, 1, 0, 4, scales)
	Check.eq(x, -4)
end)

Check.test("brake tips the nose up", function()
	local x = AirControl.targetRates(0, -1, 0, 4, scales)
	Check.eq(x, 4)
end)

Check.test("invertPitch swaps nose direction", function()
	local x = AirControl.targetRates(0, 1, 0, 4, { pitch = 1, yaw = 1, roll = 1, invertPitch = true })
	Check.eq(x, 4)
end)

Check.test("steering right swings the nose right", function()
	local _, y = AirControl.targetRates(1, 0, 0, 4, scales)
	Check.eq(y, -4)
end)

Check.test("rolling right drops the right side", function()
	local _, _, z = AirControl.targetRates(0, 0, 1, 4, scales)
	Check.eq(z, -4)
end)

Check.test("per-axis scales apply to the turn rate", function()
	local x, y, z = AirControl.targetRates(1, 1, 1, 2, { pitch = 0.5, yaw = 1.5, roll = 2, invertPitch = false })
	Check.eq(x, -1)
	Check.eq(y, -3)
	Check.eq(z, -4)
end)

Check.test("with input, spin moves toward target at most accel*dt", function()
	Check.near(AirControl.stepAxis(0, 4, true, 10, 1, 0.1), 1)
	Check.near(AirControl.stepAxis(3.5, 4, true, 10, 1, 0.1), 4, "does not overshoot")
	Check.near(AirControl.stepAxis(6, 4, true, 10, 1, 0.1), 5, "slows an over-fast spin")
end)

Check.test("without input, spin keeps momentum and bleeds slowly", function()
	Check.near(AirControl.stepAxis(4, 0, false, 10, 0.5, 1), 4 * math.exp(-0.5))
end)

Check.finish("AirControl")
