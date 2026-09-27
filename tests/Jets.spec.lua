--!strict
local Check = require("./Check")
local Jets = require("../src/shared/Jets")

Check.test("burning drains one second of fuel per second", function()
	Check.near(Jets.stepFuel(3, 3, true, false, 2, 0.5), 2.5)
end)

Check.test("burning never goes below empty", function()
	Check.eq(Jets.stepFuel(0.1, 3, true, false, 2, 0.5), 0)
end)

Check.test("fuel recharges on the ground when not burning", function()
	Check.near(Jets.stepFuel(1, 3, false, true, 2, 0.25), 1.5)
end)

Check.test("recharge stops at the tank size", function()
	Check.eq(Jets.stepFuel(2.9, 3, false, true, 2, 1), 3)
end)

Check.test("no recharge in the air", function()
	Check.eq(Jets.stepFuel(1, 3, false, false, 2, 1), 1)
end)

Check.test("no recharge while burning on the ground", function()
	Check.near(Jets.stepFuel(1, 3, true, true, 2, 0.5), 0.5)
end)

Check.test("a burn can continue down to empty", function()
	Check.eq(Jets.canBurn(true, 0.01, true, 0.25), true)
	Check.eq(Jets.canBurn(true, 0, true, 0.25), false)
end)

Check.test("starting a burn needs the relight amount", function()
	Check.eq(Jets.canBurn(true, 0.1, false, 0.25), false)
	Check.eq(Jets.canBurn(true, 0.25, false, 0.25), true)
end)

Check.test("no burn without the button", function()
	Check.eq(Jets.canBurn(false, 3, true, 0.25), false)
end)

Check.finish("Jets")
