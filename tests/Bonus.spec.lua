--!strict
local Check = require("./Check")
local Bonus = require("../src/shared/Bonus")

local T: Bonus.Tuning = {
	Cap = 10,
	StreakStep = 0.1,
	StreakMax = 5,
	Lucky = {
		{ Name = "JACKPOT", Multiplier = 10, Chance = 0.005 },
		{ Name = "LUCKY", Multiplier = 3, Chance = 0.025 },
		{ Name = "LUCKY", Multiplier = 2, Chance = 0.05 },
	},
}

local function multiplierOf(roll: number): number
	local tier = Bonus.lucky(roll, T)
	return if tier then tier.Multiplier else 1
end

Check.test("the lowest rolls hit the first tier", function()
	Check.eq(multiplierOf(0), 10)
	Check.eq(multiplierOf(0.0049), 10)
end)

Check.test("each tier takes the next slice of rolls", function()
	Check.eq(multiplierOf(0.005), 3)
	Check.eq(multiplierOf(0.0299), 3)
	Check.eq(multiplierOf(0.0301), 2)
	Check.eq(multiplierOf(0.0799), 2)
end)

Check.test("rolls past every tier are not lucky", function()
	Check.eq(Bonus.lucky(0.08, T), nil)
	Check.eq(Bonus.lucky(0.5, T), nil)
	Check.eq(Bonus.lucky(0.9999, T), nil)
end)

Check.test("the tier carries its name", function()
	local tier = Bonus.lucky(0, T)
	Check.eq(tier and tier.Name, "JACKPOT")
end)

Check.test("chance adds up every tier", function()
	Check.near(Bonus.luckyChance(T), 0.08)
end)

Check.test("combined multiplies the bonuses", function()
	Check.eq(Bonus.combined({}, T), 1)
	Check.eq(Bonus.combined({ 3 }, T), 3)
	Check.eq(Bonus.combined({ 2, 1.5 }, T), 3)
end)

Check.test("combined never goes past the cap", function()
	Check.eq(Bonus.combined({ 10, 1.5 }, T), 10)
	Check.eq(Bonus.combined({ 3, 10, 1.5 }, T), 10)
	Check.eq(Bonus.combined({ 3, 3 }, T), 9)
end)

Check.test("a clean landing adds to the streak", function()
	Check.eq(Bonus.streakAfter(0, "landed", true), 1)
	Check.eq(Bonus.streakAfter(4, "landed", true), 5)
	Check.eq(Bonus.streakAfter(7, "landed", true), 8)
end)

Check.test("a sloppy landing, crash, stop, or reset loses the streak", function()
	Check.eq(Bonus.streakAfter(3, "landed", false), 0)
	Check.eq(Bonus.streakAfter(3, "crashed", false), 0)
	Check.eq(Bonus.streakAfter(3, "stopped", false), 0)
	Check.eq(Bonus.streakAfter(3, "aborted", false), 0)
end)

Check.test("a wreck keeps the streak as it was", function()
	Check.eq(Bonus.streakAfter(3, "wrecked", false), 3)
	Check.eq(Bonus.streakAfter(0, "wrecked", false), 0)
end)

Check.test("the streak pays StreakStep per clean landing up to StreakMax", function()
	Check.near(Bonus.streakMultiplier(0, T), 1)
	Check.near(Bonus.streakMultiplier(1, T), 1.1)
	Check.near(Bonus.streakMultiplier(3, T), 1.3)
	Check.near(Bonus.streakMultiplier(5, T), 1.5)
	Check.near(Bonus.streakMultiplier(9, T), 1.5)
end)

Check.finish("Bonus")
