--!strict
local Check = require("./Check")
local Juice = require("../src/shared/Juice")

local T: Juice.Tuning = {
	GoldFrom = 300,
	RainbowFrom = 500,
	PerfectUpY = 0.95,
	DingSemitones = 2,
	ScoreTiers = { 2, 3, 4 },
	LinesFrom = 0.6,
	ShakeFrom = 0.9,
	CashPerCoin = 250,
	MaxCoins = 12,
	RainFrom = 5000,
}

Check.test("small tricks pop white", function()
	Check.eq(Juice.popupTier(200, T), "White")
	Check.eq(Juice.popupTier(299, T), "White")
end)

Check.test("tricks from GoldFrom pop gold", function()
	Check.eq(Juice.popupTier(300, T), "Gold")
	Check.eq(Juice.popupTier(499, T), "Gold")
end)

Check.test("tricks from RainbowFrom pop rainbow", function()
	Check.eq(Juice.popupTier(500, T), "Rainbow")
	Check.eq(Juice.popupTier(2000, T), "Rainbow")
end)

Check.test("a repeat that pays less drops back a tier", function()
	Check.eq(Juice.popupTier(250, T), "White") -- a 500 gap paid at half
end)

Check.test("a landing that isn't clean is sloppy", function()
	Check.eq(Juice.grade(false, 0.5, T), "Sloppy")
end)

Check.test("clean decides sloppy even if the up vector looks perfect", function()
	Check.eq(Juice.grade(false, 0.99, T), "Sloppy")
end)

Check.test("a clean landing below PerfectUpY is clean", function()
	Check.eq(Juice.grade(true, 0.7, T), "Clean")
	Check.eq(Juice.grade(true, 0.949, T), "Clean")
end)

Check.test("a clean landing from PerfectUpY is perfect", function()
	Check.eq(Juice.grade(true, 0.95, T), "Perfect")
	Check.eq(Juice.grade(true, 1, T), "Perfect")
end)

Check.test("the ding plays at normal pitch with no combo", function()
	Check.near(Juice.dingPitch(1, 0.5, T), 1)
end)

Check.test("each combo step raises the ding DingSemitones", function()
	Check.near(Juice.dingPitch(1.5, 0.5, T), 2 ^ (2 / 12))
	Check.near(Juice.dingPitch(2, 0.5, T), 2 ^ (4 / 12))
end)

Check.test("the max combo of x4 is an octave up", function()
	Check.near(Juice.dingPitch(4, 0.5, T), 2)
end)

Check.test("the live score has no tier below x2", function()
	Check.eq(Juice.scoreTier(1, T), 0)
	Check.eq(Juice.scoreTier(1.5, T), 0)
end)

Check.test("the live score steps up at x2, x3 and x4", function()
	Check.eq(Juice.scoreTier(2, T), 1)
	Check.eq(Juice.scoreTier(2.5, T), 1)
	Check.eq(Juice.scoreTier(3, T), 2)
	Check.eq(Juice.scoreTier(3.5, T), 2)
	Check.eq(Juice.scoreTier(4, T), 3)
end)

Check.test("no speed lines below LinesFrom", function()
	Check.eq(Juice.speedLines(0, T), 0)
	Check.eq(Juice.speedLines(0.6, T), 0)
end)

Check.test("speed lines grow to full at top speed", function()
	Check.near(Juice.speedLines(0.8, T), 0.5)
	Check.near(Juice.speedLines(1, T), 1)
end)

Check.test("speed lines stay full past top speed", function()
	Check.near(Juice.speedLines(1.5, T), 1)
end)

Check.test("the top speed shake starts at ShakeFrom", function()
	Check.eq(Juice.topShake(0.89, T), 0)
	Check.near(Juice.topShake(0.95, T), 0.5)
	Check.near(Juice.topShake(1, T), 1)
end)

Check.test("no pay flies no coins", function()
	Check.eq(Juice.flyCoins(0, T), 0)
	Check.eq(Juice.flyCoins(-5, T), 0)
end)

Check.test("any pay flies at least one coin", function()
	Check.eq(Juice.flyCoins(1, T), 1)
end)

Check.test("one coin per CashPerCoin, rounded up", function()
	Check.eq(Juice.flyCoins(250, T), 1)
	Check.eq(Juice.flyCoins(251, T), 2)
	Check.eq(Juice.flyCoins(1000, T), 4)
end)

Check.test("coins stop at MaxCoins", function()
	Check.eq(Juice.flyCoins(1000000, T), 12)
end)

Check.test("cash rains from RainFrom", function()
	Check.eq(Juice.rains(4999, T), false)
	Check.eq(Juice.rains(5000, T), true)
end)

Check.finish("Juice")
