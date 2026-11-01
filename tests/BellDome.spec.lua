--!strict
local Check = require("./Check")
local BellDome = require("../src/shared/BellDome")

local RADIUS, HEIGHT, ROWS = 65, 18, 12
local profile = BellDome.profile(RADIUS, HEIGHT, ROWS)

Check.test("it runs from the rim on the roof to the top in the middle", function()
	Check.eq(#profile, ROWS + 1, "points")
	Check.near(profile[1].R, RADIUS, "rim radius")
	Check.near(profile[1].Y, 0, "rim height")
	Check.near(profile[#profile].R, 0, "top radius")
	Check.near(profile[#profile].Y, HEIGHT, "top height")
end)

Check.test("it only ever climbs on the way in", function()
	for i = 2, #profile do
		Check.eq(profile[i].R < profile[i - 1].R, true, `radius at {i}`)
		Check.eq(profile[i].Y > profile[i - 1].Y, true, `height at {i}`)
	end
end)

Check.test("no slope is steeper than a car can drive", function()
	for i = 2, #profile do
		local rise = profile[i].Y - profile[i - 1].Y
		local run = profile[i - 1].R - profile[i].R
		local degrees = math.deg(math.atan2(rise, run))
		Check.eq(degrees < 27, true, `{degrees} degrees at {i}`)
	end
end)

Check.test("it leaves the roof and meets the top almost flat", function()
	local function slope(a: BellDome.Point, b: BellDome.Point): number
		return math.deg(math.atan2(b.Y - a.Y, a.R - b.R))
	end
	Check.eq(slope(profile[1], profile[2]) < 8, true, "at the rim")
	Check.eq(slope(profile[#profile - 1], profile[#profile]) < 8, true, "at the top")
end)

Check.finish("BellDome")
