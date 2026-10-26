--!strict
local Check = require("./Check")
local Guns = require("../src/shared/Guns")

Check.test("pressing fire shoots at once", function()
	local _, fire = Guns.step(0, true, 1 / 60, 5)
	Check.eq(fire, true)
end)

Check.test("holding fire shoots Rate times a second", function()
	local cooldown, shots = 0, 0
	for _ = 1, 60 do
		local fire
		cooldown, fire = Guns.step(cooldown, true, 1 / 60, 5)
		if fire then
			shots += 1
		end
	end
	Check.eq(shots, 5, "shots in one second")
end)

Check.test("letting go stops shooting but the gun still cools down", function()
	local cooldown = Guns.step(0, true, 1 / 60, 5)
	local after, fire = Guns.step(cooldown, false, 0.1, 5)
	Check.eq(fire, false, "no shot")
	Check.near(after, cooldown - 0.1, "cooling")
	local rested = Guns.step(after, false, 1, 5)
	Check.eq(rested, 0, "never below zero")
end)

Check.test("the server takes a shot a little early, for network jitter", function()
	Check.eq(Guns.allowed(10, 10.2, 5, 0.75), true, "on time")
	Check.eq(Guns.allowed(10, 10.16, 5, 0.75), true, "a little early")
	Check.eq(Guns.allowed(10, 10.1, 5, 0.75), false, "too fast")
end)

Check.test("the guns take turns", function()
	Check.eq(Guns.nextGun(1), 2)
	Check.eq(Guns.nextGun(2), 1)
end)

Check.finish("Guns")
