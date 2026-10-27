--!strict
local Check = require("./Check")
local Pips = require("../src/shared/Pips")

Check.test("nothing at level 0", function()
	Check.eq(Pips.filled(0, 10, 10), 0)
end)

Check.test("one pip per level when the cap matches the pip count", function()
	Check.eq(Pips.filled(4, 10, 10), 4)
end)

Check.test("scales to the cap", function()
	Check.eq(Pips.filled(15, 30, 10), 5)
	Check.eq(Pips.filled(24, 40, 10), 6)
end)

Check.test("any progress shows at least one pip", function()
	Check.eq(Pips.filled(1, 40, 10), 1)
end)

Check.test("only a maxed stat fills every pip", function()
	Check.eq(Pips.filled(39, 40, 10), 9)
	Check.eq(Pips.filled(40, 40, 10), 10)
end)

Check.test("levels above the car's cap still show full", function()
	Check.eq(Pips.filled(30, 10, 10), 10)
end)

Check.test("a zero cap shows nothing", function()
	Check.eq(Pips.filled(0, 0, 10), 0)
end)

Check.finish("Pips")
