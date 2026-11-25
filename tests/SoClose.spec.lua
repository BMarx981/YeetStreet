--!strict
local Check = require("./Check")
local SoClose = require("../src/shared/SoClose")

local T: SoClose.Tuning = { BestWithin = 0.15, RecordWithin = 0.15 }

-- A run that is close to nothing.
local function facts(): SoClose.Facts
	return {
		total = 500,
		best = 5000,
		landed = true,
		tricks = 0,
		nextCombo = 1.5,
		distance = 100,
		weekRecord = nil,
		allTimeRecord = nil,
		cash = 100,
		paid = 50,
		upgradeCost = nil,
		upgradeName = nil,
	}
end

Check.test("nothing close says nothing", function()
	Check.eq(SoClose.pick(facts(), T), nil)
end)

Check.test("near the best says how far short", function()
	local f = facts()
	f.total = 4660
	Check.eq(SoClose.pick(f, T), "Only 340 short of your best!")
end)

Check.test("too far from the best, or past it, says nothing", function()
	local f = facts()
	f.total = 4000
	Check.eq(SoClose.pick(f, T), nil)
	f.total = 5000
	Check.eq(SoClose.pick(f, T), nil)
	f.total = 6000
	Check.eq(SoClose.pick(f, T), nil)
end)

Check.test("no best yet says nothing about it", function()
	local f = facts()
	f.best = 0
	f.total = 0
	Check.eq(SoClose.pick(f, T), nil)
end)

Check.test("near this week's record", function()
	local f = facts()
	f.distance = 880.6
	f.weekRecord = 892
	f.allTimeRecord = 1500
	Check.eq(SoClose.pick(f, T), "12 studs short of this week's record!")
end)

Check.test("past this week's record, near the all-time one", function()
	local f = facts()
	f.distance = 1450
	f.weekRecord = 1200
	f.allTimeRecord = 1451
	Check.eq(SoClose.pick(f, T), "1 stud short of the all-time record!")
end)

Check.test("no record this week compares with the all-time one", function()
	local f = facts()
	f.distance = 1400
	f.allTimeRecord = 1500
	Check.eq(SoClose.pick(f, T), "100 studs short of the all-time record!")
end)

Check.test("far from the record says nothing", function()
	local f = facts()
	f.distance = 500
	f.weekRecord = 892
	Check.eq(SoClose.pick(f, T), nil)
end)

Check.test("one more run like it buys the cheapest upgrade", function()
	local f = facts()
	f.cash = 250
	f.paid = 80
	f.upgradeCost = 300
	f.upgradeName = "Jets 6"
	Check.eq(SoClose.pick(f, T), "One more run like that buys Jets 6!")
end)

Check.test("an upgrade already affordable, or more than a run away, says nothing", function()
	local f = facts()
	f.cash = 300
	f.paid = 80
	f.upgradeCost = 300
	f.upgradeName = "Jets 6"
	Check.eq(SoClose.pick(f, T), nil)
	f.cash = 200
	Check.eq(SoClose.pick(f, T), nil)
end)

Check.test("a landed run with tricks is one trick from more combo", function()
	local f = facts()
	f.tricks = 2
	Check.eq(SoClose.pick(f, T), "One new trick for x1.5!")
end)

Check.test("no combo hint at max combo, with no tricks, or after a crash", function()
	local f = facts()
	f.tricks = 6
	f.nextCombo = nil
	Check.eq(SoClose.pick(f, T), nil)
	f = facts()
	f.tricks = 0
	Check.eq(SoClose.pick(f, T), nil)
	f = facts()
	f.tricks = 2
	f.landed = false
	Check.eq(SoClose.pick(f, T), nil)
end)

Check.test("the record comes first, then the best, then the upgrade, then the combo", function()
	local f = facts()
	f.tricks = 2
	f.cash = 250
	f.paid = 80
	f.upgradeCost = 300
	f.upgradeName = "Jets 6"
	Check.eq(SoClose.pick(f, T), "One more run like that buys Jets 6!")
	f.total = 4660
	Check.eq(SoClose.pick(f, T), "Only 340 short of your best!")
	f.distance = 880
	f.weekRecord = 892
	Check.eq(SoClose.pick(f, T), "12 studs short of this week's record!")
end)

Check.finish("SoClose")
