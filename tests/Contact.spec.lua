--!strict
local Check = require("./Check")
local Contact = require("../src/shared/Contact")

local AIR_DELAY = 0.1
local LAND_WHEELS = 2

Check.test("starts grounded", function()
	local s = Contact.new()
	Check.eq(s.airborne, false)
	Check.eq(s.airtime, 0)
end)

Check.test("a short hop under the delay stays grounded", function()
	local s = Contact.step(Contact.new(), 0, 0.05, AIR_DELAY, LAND_WHEELS)
	Check.eq(s.airborne, false)
	s = Contact.step(s, 4, 0.05, AIR_DELAY, LAND_WHEELS)
	Check.eq(s.airborne, false)
	Check.eq(s.airtime, 0, "touching resets the count")
end)

Check.test("no wheels down past the delay goes airborne", function()
	local s = Contact.step(Contact.new(), 0, 0.06, AIR_DELAY, LAND_WHEELS)
	s = Contact.step(s, 0, 0.06, AIR_DELAY, LAND_WHEELS)
	Check.eq(s.airborne, true)
	Check.near(s.airtime, 0.12, "airtime counts from lift off")
end)

Check.test("one wheel clipping something does not end the flight", function()
	local s = { airborne = true, airtime = 1 }
	s = Contact.step(s, 1, 0.1, AIR_DELAY, LAND_WHEELS)
	Check.eq(s.airborne, true)
	Check.near(s.airtime, 1.1)
end)

Check.test("enough wheels down lands", function()
	local s = Contact.step({ airborne = true, airtime = 2 }, 2, 0.1, AIR_DELAY, LAND_WHEELS)
	Check.eq(s.airborne, false)
	Check.eq(s.airtime, 0)
end)

Check.test("stuck timer counts only while upside down and slow", function()
	Check.near(Contact.stepStuck(1, -0.9, 1, 0.5, 0.3, 4), 1.5)
	Check.eq(Contact.stepStuck(1, 0.9, 1, 0.5, 0.3, 4), 0, "upright")
	Check.eq(Contact.stepStuck(1, -0.9, 10, 0.5, 0.3, 4), 0, "still moving")
end)

Check.finish("Contact")
