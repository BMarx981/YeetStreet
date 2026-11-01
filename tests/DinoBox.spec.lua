--!strict
local Check = require("./Check")
local DinoBox = require("../src/shared/DinoBox")

local REWARDS: { DinoBox.Reward } = {
	{ CarId = "Raptor", Weight = 3, Blurb = "" },
	{ CarId = "Trike", Weight = 1, Blurb = "" },
}

Check.test("a low roll lands on the first car", function()
	local reward = DinoBox.pick(REWARDS, {}, 0)
	Check.eq(reward and reward.CarId, "Raptor")
end)

Check.test("rolls split by weight", function()
	local below = DinoBox.pick(REWARDS, {}, 0.74)
	local above = DinoBox.pick(REWARDS, {}, 0.76)
	Check.eq(below and below.CarId, "Raptor")
	Check.eq(above and above.CarId, "Trike")
end)

Check.test("the top of the roll still lands on a car", function()
	local reward = DinoBox.pick(REWARDS, {}, 1)
	Check.eq(reward and reward.CarId, "Trike")
end)

Check.test("owned cars can't be won", function()
	local reward = DinoBox.pick(REWARDS, { "Raptor" }, 0)
	Check.eq(reward and reward.CarId, "Trike")
end)

Check.test("nothing to win once every car is owned", function()
	Check.eq(DinoBox.pick(REWARDS, { "Raptor", "Trike" }, 0), nil)
end)

Check.test("cars the box doesn't hold don't count as owning it out", function()
	Check.eq(DinoBox.allOwned(REWARDS, { "Junker", "Raptor" }), false)
	Check.eq(DinoBox.allOwned(REWARDS, { "Junker", "Raptor", "Trike" }), true)
end)

Check.test("the wheel stops on the winner after the full turns", function()
	Check.eq(DinoBox.stop(5, 1, 4), 20)
	Check.eq(DinoBox.stop(5, 3, 4), 22)
end)

Check.test("the spin starts at zero and ends exactly on the stop", function()
	Check.eq(DinoBox.position(0, 5, 22), 0)
	Check.eq(DinoBox.position(5, 5, 22), 22)
	Check.eq(DinoBox.position(9, 5, 22), 22)
end)

Check.test("the spin slows down", function()
	local early = DinoBox.position(1, 5, 22) - DinoBox.position(0, 5, 22)
	local late = DinoBox.position(5, 5, 22) - DinoBox.position(4, 5, 22)
	Check.eq(early > late, true)
end)

Check.test("the car at the position sits in the middle", function()
	Check.eq(DinoBox.offset(3, 22, 5), 0)
	Check.eq(DinoBox.offset(4, 22, 5), 1)
	Check.eq(DinoBox.offset(2, 22, 5), -1)
end)

Check.test("cars wrap around the wheel", function()
	Check.eq(DinoBox.offset(1, 4, 5), 1)
	Check.eq(DinoBox.offset(5, 0, 5), -1)
end)

Check.finish("DinoBox")
