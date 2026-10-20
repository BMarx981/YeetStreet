--!strict
local Check = require("./Check")
local Gap = require("../src/shared/Gap")

-- A ring around (100, 200) from 300 to 600 out.
local BOWL: Gap.Gap = { name = "Bowl Gap", x = 100, z = 200, inner = 300, outer = 600, minAngle = 120 }

local function run(ending: string, launchX: number, launchZ: number, endX: number, endZ: number): Gap.Run
	return { ending = ending, launchX = launchX, launchZ = launchZ, endX = endX, endZ = endZ }
end

Check.test("taking off on one side and landing on the far side clears the gap", function()
	Check.eq(Gap.cleared(BOWL, run("landed", 100 + 350, 200, 100 - 400, 200)), true)
end)

Check.test("crashing on the far side still clears it", function()
	Check.eq(Gap.cleared(BOWL, run("crashed", 100, 200 + 350, 100, 200 - 320)), true)
end)

Check.test("a reset, wreck, or stop does not", function()
	for _, ending in { "aborted", "wrecked", "stopped" } do
		Check.eq(Gap.cleared(BOWL, run(ending, 100 + 350, 200, 100 - 400, 200)), false, ending)
	end
end)

Check.test("coming back down on the same side does not", function()
	Check.eq(Gap.cleared(BOWL, run("landed", 100 + 350, 200, 100 + 400, 200 + 100)), false)
end)

Check.test("it takes the whole angle around", function()
	local a = math.rad(110)
	Check.eq(Gap.cleared(BOWL, run("landed", 100 + 400, 200, 100 + 400 * math.cos(a), 200 + 400 * math.sin(a))), false)
	local b = math.rad(125)
	Check.eq(Gap.cleared(BOWL, run("landed", 100 + 400, 200, 100 + 400 * math.cos(b), 200 + 400 * math.sin(b))), true)
end)

Check.test("landing on the floor in the middle does not", function()
	Check.eq(Gap.cleared(BOWL, run("landed", 100 + 350, 200, 100 - 100, 200)), false)
end)

Check.test("taking off outside the ring does not", function()
	Check.eq(Gap.cleared(BOWL, run("landed", 100 + 900, 200, 100 - 400, 200)), false, "far outside")
	Check.eq(Gap.cleared(BOWL, run("landed", 100 + 50, 200, 100 - 400, 200)), false, "from the floor")
end)

Check.test("find names every gap cleared", function()
	local other: Gap.Gap = { name = "Other", x = 5000, z = 5000, inner = 10, outer = 20, minAngle = 90 }
	local names = Gap.find({ BOWL, other }, run("landed", 100 + 350, 200, 100 - 400, 200))
	Check.eq(#names, 1)
	Check.eq(names[1], "Bowl Gap")
	Check.eq(#Gap.find({ BOWL }, run("landed", 100 + 350, 200, 100 + 350, 200)), 0, "none")
end)

Check.finish("Gap")
