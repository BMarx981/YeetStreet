--!strict
local Check = require("./Check")
local InputAxes = require("../src/shared/InputAxes")

Check.test("fromKeys gives -1, 0, or 1", function()
	Check.eq(InputAxes.fromKeys(false, false), 0)
	Check.eq(InputAxes.fromKeys(true, false), -1)
	Check.eq(InputAxes.fromKeys(false, true), 1)
	Check.eq(InputAxes.fromKeys(true, true), 0, "both held cancel")
end)

Check.test("deadzone zeroes small stick values", function()
	Check.eq(InputAxes.deadzone(0.1, 0.15), 0)
	Check.eq(InputAxes.deadzone(-0.15, 0.15), 0)
end)

Check.test("deadzone rescales so full deflection is still 1", function()
	Check.near(InputAxes.deadzone(1, 0.2), 1)
	Check.near(InputAxes.deadzone(-1, 0.2), -1)
	Check.near(InputAxes.deadzone(0.6, 0.2), 0.5)
end)

Check.test("combine sums sources and clamps to -1..1", function()
	Check.eq(InputAxes.combine({ 1, 1 }), 1)
	Check.eq(InputAxes.combine({ -1, 0.25 }), -0.75)
	Check.eq(InputAxes.combine({}), 0)
end)

Check.finish("InputAxes")
