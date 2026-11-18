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

-- Prize trail looks a player can be given, by id.
local PRIZES: { [string]: any } = { Rainbow = true, Comet = true }

Check.test("a new player owns no prize trails and wears the rebirth trail", function()
	local s = Trails.newState()
	Check.eq(#s.Owned, 0)
	Check.eq(Trails.worn(s, 0, REBIRTH), nil, "no rebirths yet")
	Check.eq(Trails.worn(s, 2, REBIRTH), "Rebirth2", "after two")
end)

Check.test("give adds a prize trail and puts it on", function()
	local s = Trails.newState()
	local after = Trails.give(s, "Rainbow", PRIZES) :: Trails.State
	Check.eq(after.Owned[1], "Rainbow")
	Check.eq(Trails.worn(after, 2, REBIRTH), "Rainbow")
	Check.eq(#s.Owned, 0, "old state unchanged")
	local _, again = Trails.give(after, "Rainbow", PRIZES)
	Check.eq(again, "Owned")
	local _, unknown = Trails.give(s, "Nope", PRIZES)
	Check.eq(unknown, "UnknownTrail")
end)

Check.test("the choices are the rebirth trail if earned, each prize trail, then off", function()
	local s = Trails.give(Trails.newState(), "Rainbow", PRIZES) :: Trails.State
	local both = Trails.options(s, 1)
	Check.eq(table.concat(both, ","), "Rebirth,Rainbow,Off")
	Check.eq(table.concat(Trails.options(s, 0), ","), "Rainbow,Off", "no rebirths yet")
	Check.eq(table.concat(Trails.options(Trails.newState(), 0), ","), "Off", "nothing at all")
end)

Check.test("nextChoice cycles through the choices", function()
	local s = Trails.give(Trails.newState(), "Rainbow", PRIZES) :: Trails.State
	Check.eq(Trails.current(s, 1), "Rainbow")
	s = Trails.nextChoice(s, 1)
	Check.eq(Trails.current(s, 1), "Off")
	Check.eq(Trails.worn(s, 1, REBIRTH), nil, "off wears nothing")
	s = Trails.nextChoice(s, 1)
	Check.eq(Trails.current(s, 1), "Rebirth")
	Check.eq(Trails.worn(s, 1, REBIRTH), "Rebirth1")
	s = Trails.nextChoice(s, 1)
	Check.eq(Trails.current(s, 1), "Rainbow")
end)

Check.test("with no rebirths, the rebirth choice counts as off", function()
	local s = Trails.newState()
	Check.eq(Trails.current(s, 0), "Off")
	s = Trails.give(s, "Rainbow", PRIZES) :: Trails.State
	s = Trails.nextChoice(s, 0)
	Check.eq(Trails.current(s, 0), "Off")
	s = Trails.nextChoice(s, 0)
	Check.eq(Trails.current(s, 0), "Rainbow")
end)

Check.test("a rebirth switches to the new rebirth trail", function()
	local s = Trails.give(Trails.newState(), "Rainbow", PRIZES) :: Trails.State
	s = Trails.reborn(s)
	Check.eq(Trails.worn(s, 3, REBIRTH), "Rebirth3")
end)

Check.test("reconcile keeps known prize trails and a valid choice", function()
	local s = Trails.reconcile({ Owned = { "Rainbow", "Gone", 4, "Rainbow" }, Choice = "Rainbow" }, PRIZES)
	Check.eq(table.concat(s.Owned, ","), "Rainbow")
	Check.eq(Trails.worn(s, 1, REBIRTH), "Rainbow")
	local off = Trails.reconcile({ Owned = {}, Choice = "Off" }, PRIZES)
	Check.eq(Trails.worn(off, 1, REBIRTH), nil, "off is kept")
	local lost = Trails.reconcile({ Owned = {}, Choice = "Comet" }, PRIZES)
	Check.eq(Trails.worn(lost, 1, REBIRTH), "Rebirth1", "a choice not owned goes back to the rebirth trail")
	Check.eq(#Trails.reconcile(nil, PRIZES).Owned, 0, "nothing saved")
end)

Check.finish("Trails")
