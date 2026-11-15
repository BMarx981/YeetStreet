--!strict
local Check = require("./Check")
local Trails = require("../src/shared/Trails")

local REBIRTH = { "Rebirth1", "Rebirth2", "Rebirth3" }

Check.test("no rebirths wears no trail", function()
	Check.eq(Trails.forRebirths(0, REBIRTH), nil)
end)

Check.test("the rebirth trail steps through its looks by rebirth count, then cycles", function()
	Check.eq(Trails.forRebirths(1, REBIRTH), "Rebirth1", "1")
	Check.eq(Trails.forRebirths(2, REBIRTH), "Rebirth2", "2")
	Check.eq(Trails.forRebirths(3, REBIRTH), "Rebirth3", "3")
	Check.eq(Trails.forRebirths(4, REBIRTH), "Rebirth1", "4")
	Check.eq(Trails.forRebirths(9, REBIRTH), "Rebirth3", "9")
end)

Check.test("the trail starts only once the car has been in the air for the lift delay", function()
	local air = Trails.newAir()
	Check.eq(Trails.step(air, true, 0.1, 0.3), false, "on the ground")
	Check.eq(Trails.step(air, false, 0.1, 0.3), false, "0.1 s up")
	Check.eq(Trails.step(air, false, 0.1, 0.3), false, "0.2 s up")
	Check.eq(Trails.step(air, false, 0.1, 0.3), true, "0.3 s up")
	Check.eq(Trails.step(air, false, 0.1, 0.3), true, "0.4 s up")
end)

Check.test("landing stops the trail and a bump starts the delay over", function()
	local air = Trails.newAir()
	Trails.step(air, false, 0.5, 0.3)
	Check.eq(Trails.step(air, true, 0.1, 0.3), false, "landed")
	Check.eq(Trails.step(air, false, 0.2, 0.3), false, "short hop")
	Check.eq(Trails.step(air, true, 0.1, 0.3), false, "down again")
	Check.eq(Trails.step(air, false, 0.2, 0.3), false, "up again, delay starts over")
end)

Check.finish("Trails")
