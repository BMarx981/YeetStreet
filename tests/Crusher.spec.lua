--!strict
local Check = require("./Check")
local Crusher = require("../src/shared/Crusher")

local CONFIG: Crusher.Config = {
	BedWidth = 30,
	BedLength = 40,
	CatchHeight = 10,
	TopHeight = 30,
	ContactHeight = 10,
	FlatHeight = 2,
	Close = 1,
	Hold = 1,
	Open = 2,
	CrushBase = 1.5,
	CrushPerToughness = 0.02,
	CrushMax = 8,
	TonsPerSecond = 20,
	MinSquash = 0.15,
	Fill = 3,
}

Check.test("tougher cars take longer to crush, up to the most", function()
	Check.near(Crusher.crushTime(CONFIG, 60), 2.7)
	Check.near(Crusher.crushTime(CONFIG, 200), 5.5)
	Check.near(Crusher.crushTime(CONFIG, 1000), 8)
	Check.near(Crusher.crushTime(CONFIG, -5), 1.5)
end)

Check.test("a cycle is the slam, the crush, the hold, and the opening", function()
	Check.near(Crusher.cycleLength(CONFIG, 3), 7)
end)

Check.test("the phases follow each other", function()
	Check.eq(Crusher.phase(CONFIG, -1, 3), "idle", "before it starts")
	Check.eq(Crusher.phase(CONFIG, 0.5, 3), "closing")
	Check.eq(Crusher.phase(CONFIG, 2, 3), "crushing")
	Check.eq(Crusher.phase(CONFIG, 4.5, 3), "holding")
	Check.eq(Crusher.phase(CONFIG, 6, 3), "opening")
	Check.eq(Crusher.phase(CONFIG, 7.5, 3), "idle", "after it ends")
end)

Check.test("the head slams down to the car, then crushes it flat, then rises", function()
	Check.near(Crusher.headHeight(CONFIG, -1, 3), 30, "open while idle")
	Check.near(Crusher.headHeight(CONFIG, 0, 3), 30, "starts open")
	Check.near(Crusher.headHeight(CONFIG, 1, 3), 10, "slammed to the contact height")
	Check.near(Crusher.headHeight(CONFIG, 2.5, 3), 6, "halfway through the crush")
	Check.near(Crusher.headHeight(CONFIG, 4, 3), 2, "flat")
	Check.near(Crusher.headHeight(CONFIG, 4.5, 3), 2, "held flat")
	Check.near(Crusher.headHeight(CONFIG, 7, 3), 30, "open again")
end)

Check.test("the slam speeds up as it falls", function()
	local quarter = 30 - Crusher.headHeight(CONFIG, 0.25, 3)
	local half = 30 - Crusher.headHeight(CONFIG, 0.5, 3)
	Check.eq(half > 2 * quarter, true)
end)

Check.test("the pressure climbs through the crush and stays at its peak", function()
	Check.near(Crusher.tons(CONFIG, 0.5, 3), 0, "not yet crushing")
	Check.near(Crusher.tons(CONFIG, 2.5, 3), 30)
	Check.near(Crusher.tons(CONFIG, 6, 3), 60, "peak")
end)

Check.test("a car is on the bed only inside it and low enough", function()
	Check.eq(Crusher.onBed(CONFIG, 10, -15, 3), true)
	Check.eq(Crusher.onBed(CONFIG, 16, 0, 3), false, "off the side")
	Check.eq(Crusher.onBed(CONFIG, 0, 21, 3), false, "off the end")
	Check.eq(Crusher.onBed(CONFIG, 0, 0, 12), false, "flying over")
	Check.eq(Crusher.onBed(CONFIG, 0, 0, -3), false, "under it")
end)

Check.test("a car squashes to fit under the head, but never past the least", function()
	Check.near(Crusher.squash(CONFIG, 8, 12), 1, "head above the car")
	Check.near(Crusher.squash(CONFIG, 8, 4), 0.5)
	Check.near(Crusher.squash(CONFIG, 8, 0.4), 0.15, "least")
	Check.near(Crusher.squash(CONFIG, 0, 4), 1, "nothing to squash")
end)

Check.test("the countdown shows whole seconds left until the press starts", function()
	Check.eq(Crusher.countdown(CONFIG, 0), 3)
	Check.eq(Crusher.countdown(CONFIG, 0.2), 3)
	Check.eq(Crusher.countdown(CONFIG, 1.5), 2)
	Check.eq(Crusher.countdown(CONFIG, 2.9), 1)
	Check.eq(Crusher.countdown(CONFIG, 3.5), 0, "never below 0")
	Check.eq(tostring(Crusher.countdown(CONFIG, 3.01)), "0", "never shows -0")
end)

Check.finish("Crusher")
