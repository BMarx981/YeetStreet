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
	RollRate = 12,
	RollSnap = 1,
	StopHold = 0.08,
	StopCatch = 0.1,
	PunchFov = 8,
	PunchTime = 0.25,
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

Check.test("the live score doesn't move with no time passed", function()
	Check.eq(Juice.roll(100, 500, 0, T), 100)
end)

Check.test("the live score closes part of the gap each step", function()
	Check.near(Juice.roll(100, 500, 0.05, T), 100 + 400 * (1 - math.exp(-12 * 0.05)))
end)

Check.test("the live score never passes its target", function()
	Check.eq(Juice.roll(100, 500, 10, T), 500)
end)

Check.test("the live score snaps the last RollSnap", function()
	Check.eq(Juice.roll(499.2, 500, 0.001, T), 500)
end)

Check.test("the live score rolls down too", function()
	local shown = Juice.roll(500, 100, 0.05, T)
	Check.eq(shown < 500 and shown > 100, true)
end)

Check.test("hit-stop holds the camera still at first", function()
	local stop = Juice.hitStop(0, T)
	Check.eq(stop.blend, 0)
	Check.eq(stop.fov, 0)
	Check.eq(stop.done, false)
	Check.eq(Juice.hitStop(0.079, T).blend, 0)
end)

Check.test("hit-stop catches the camera up after the hold", function()
	Check.near(Juice.hitStop(0.13, T).blend, 0.5)
	Check.eq(Juice.hitStop(0.181, T).blend, 1)
	Check.eq(Juice.hitStop(0.3, T).blend, 1)
end)

Check.test("hit-stop punches the zoom in after the hold and back out", function()
	Check.eq(Juice.hitStop(0.05, T).fov, 0, "not during the hold")
	Check.near(Juice.hitStop(0.08 + 0.125, T).fov, -8, "fully in halfway")
	Check.near(Juice.hitStop(0.08 + 0.0625, T).fov, -8 * math.sin(math.pi / 4))
	Check.eq(Juice.hitStop(0.08 + 0.25, T).fov, 0, "back out at the end")
end)

Check.test("hit-stop is done once the catch up and the punch are over", function()
	Check.eq(Juice.hitStop(0.32, T).done, false)
	Check.eq(Juice.hitStop(0.33, T).done, true)
end)

Check.finish("Juice")
