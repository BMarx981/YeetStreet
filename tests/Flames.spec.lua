--!strict
local Check = require("./Check")
local Flames = require("../src/shared/Flames")

local LOOKS: { [string]: Flames.Look } = {
	Rainbow = { Name = "Rainbow", Colors = { { 255, 0, 0 }, { 0, 255, 0 }, { 0, 0, 255 } } },
	Ice = { Name = "Ice", Colors = { { 200, 240, 255 } } },
}

Check.test("a new player has no flames and none on", function()
	local s = Flames.newState()
	Check.eq(#s.Owned, 0)
	Check.eq(s.Worn, nil)
end)

Check.test("give adds a flame and turns it on", function()
	local s = Flames.newState()
	local after = Flames.give(s, "Rainbow", LOOKS) :: Flames.State
	Check.eq(after.Owned[1], "Rainbow")
	Check.eq(after.Worn, "Rainbow")
	Check.eq(#s.Owned, 0, "old state unchanged")
end)

Check.test("give refuses an unknown flame or one already owned", function()
	local _, unknown = Flames.give(Flames.newState(), "Nope", LOOKS)
	Check.eq(unknown, "UnknownFlame")
	local owned = Flames.give(Flames.newState(), "Rainbow", LOOKS) :: Flames.State
	local _, again = Flames.give(owned, "Rainbow", LOOKS)
	Check.eq(again, "Owned")
end)

Check.test("wear turns an owned flame on, or all off with nil", function()
	local s = Flames.give(Flames.newState(), "Rainbow", LOOKS) :: Flames.State
	local off = Flames.wear(s, nil) :: Flames.State
	Check.eq(off.Worn, nil)
	Check.eq(s.Worn, "Rainbow", "old state unchanged")
	local on = Flames.wear(off, "Rainbow") :: Flames.State
	Check.eq(on.Worn, "Rainbow")
end)

Check.test("wear refuses a flame that isn't owned", function()
	local _, reason = Flames.wear(Flames.newState(), "Ice")
	Check.eq(reason, "NotOwned")
end)

Check.test("reconcile keeps known owned flames and drops junk", function()
	local s = Flames.reconcile({ Owned = { "Rainbow", "Gone", 5, "Rainbow" }, Worn = "Rainbow" }, LOOKS)
	Check.eq(#s.Owned, 1)
	Check.eq(s.Owned[1], "Rainbow")
	Check.eq(s.Worn, "Rainbow")
	Check.eq(#Flames.reconcile(nil, LOOKS).Owned, 0, "nothing saved")
	Check.eq(#Flames.reconcile("junk", LOOKS).Owned, 0, "not a table")
end)

Check.test("reconcile turns off a flame that isn't owned", function()
	Check.eq(Flames.reconcile({ Owned = {}, Worn = "Rainbow" }, LOOKS).Worn, nil, "not owned")
	Check.eq(Flames.reconcile({ Owned = { "Rainbow" }, Worn = 3 }, LOOKS).Worn, nil, "not a name")
end)

Check.test("the newest flame is the last one given", function()
	local s = Flames.give(Flames.newState(), "Ice", LOOKS) :: Flames.State
	s = Flames.give(s, "Rainbow", LOOKS) :: Flames.State
	Check.eq(Flames.newest(s), "Rainbow")
	Check.eq(Flames.newest(Flames.newState()), nil, "none yet")
end)

Check.test("stops spreads a flame's colors from the nozzle (0) to the tip (1)", function()
	local three = Flames.stops(3)
	Check.eq(#three, 3)
	Check.near(three[1], 0)
	Check.near(three[2], 0.5)
	Check.near(three[3], 1)
	local one = Flames.stops(1)
	Check.eq(#one, 2, "a single color still needs both ends")
	Check.near(one[1], 0)
	Check.near(one[2], 1)
end)

Check.finish("Flames")
