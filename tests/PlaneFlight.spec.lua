--!strict
local Check = require("./Check")
local PlaneFlight = require("../src/shared/PlaneFlight")

local T: PlaneFlight.Tuning = {
	MaxPitch = math.rad(30),
	MaxBank = math.rad(35),
	Gain = 3,
	YawShare = 0.5,
}
local MAX = 2.5

-- The car's look, right, and up vectors' heights, pitched up by `pitch` and
-- banked right side up by `bank`.
local function attitude(pitch: number, bank: number): (number, number, number)
	return math.sin(pitch), math.sin(bank) * math.cos(pitch), math.cos(bank) * math.cos(pitch)
end

Check.test("level with no input, nothing turns", function()
	local look, right, up = attitude(0, 0)
	local x, y, z = PlaneFlight.rates(look, right, up, 0, 0, MAX, T)
	Check.near(x, 0, "pitch")
	Check.near(y, 0, "yaw")
	Check.near(z, 0, "roll")
end)

Check.test("holding up lifts the nose until it reaches MaxPitch", function()
	local look, right, up = attitude(0, 0)
	local x = PlaneFlight.rates(look, right, up, 1, 0, MAX, T)
	Check.eq(x > 0, true, "lifting")
	look, right, up = attitude(T.MaxPitch, 0)
	x = PlaneFlight.rates(look, right, up, 1, 0, MAX, T)
	Check.near(x, 0, "held there")
end)

Check.test("holding down drops the nose the same amount", function()
	local look, right, up = attitude(-T.MaxPitch, 0)
	local x = PlaneFlight.rates(look, right, up, -1, 0, MAX, T)
	Check.near(x, 0)
end)

Check.test("letting go levels the nose", function()
	local look, right, up = attitude(math.rad(20), 0)
	local x = PlaneFlight.rates(look, right, up, 0, 0, MAX, T)
	Check.eq(x < 0, true)
end)

Check.test("steering right banks right and swings the nose right", function()
	local look, right, up = attitude(0, 0)
	local _, y, z = PlaneFlight.rates(look, right, up, 0, 1, MAX, T)
	Check.eq(z < 0, true, "right side going down")
	Check.near(y, -MAX * T.YawShare, "nose swinging right")
	look, right, up = attitude(0, -T.MaxBank)
	_, _, z = PlaneFlight.rates(look, right, up, 0, 1, MAX, T)
	Check.near(z, 0, "held at MaxBank")
end)

Check.test("upside down, it rolls back over", function()
	local look, right, up = attitude(0, math.rad(179))
	local _, _, z = PlaneFlight.rates(look, right, up, 0, 0, MAX, T)
	Check.near(math.abs(z), MAX, "rolling as fast as it can")
end)

Check.test("no turn is faster than the car's turn rate", function()
	local look, right, up = attitude(math.rad(-80), math.rad(90))
	local x, _, z = PlaneFlight.rates(look, right, up, 1, 0, MAX, T)
	Check.near(x, MAX, "pitch")
	Check.near(z, -MAX, "roll")
end)

Check.finish("PlaneFlight")
