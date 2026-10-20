--!strict
local Check = require("./Check")
local Scoring = require("../src/shared/Scoring")

local TUNING: Scoring.Tuning = {
	AirtimePerSecond = 50,
	DistancePerStud = 0.5,
	HeightPerStud = 1,
	FlipPoints = 200,
	SpinPoints = 100,
	RollPoints = 300,
	RepeatFalloff = 0.5,
	RepeatFloor = 0.1,
	ComboStep = 0.5,
	ComboMax = 2.5,
	CleanMultiplier = 1.5,
	SmashPoints = 100,
	GrindPerSecond = 80,
	GapPoints = 500,
	SwingPoints = 300,
}

local function trick(kind: Scoring.TrickKind, direction: number): Scoring.Trick
	return { kind = kind, direction = direction, airtime = 0 }
end

local function run(fields: { [string]: any }?): Scoring.Run
	local r: { [string]: any } = {
		ending = "landed",
		airtime = 0,
		distance = 0,
		height = 0,
		tricks = {},
		clean = false,
	}
	for key, value in fields or {} do
		r[key] = value
	end
	return (r :: any) :: Scoring.Run
end

Check.test("an empty run scores nothing", function()
	local score = Scoring.score(run(), TUNING)
	Check.eq(score.total, 0)
	Check.eq(score.combo, 1)
end)

Check.test("airtime, distance, and height each pay", function()
	local score = Scoring.score(run({ airtime = 2, distance = 300, height = 80 }), TUNING)
	Check.eq(score.airtime, 100)
	Check.eq(score.distance, 150)
	Check.eq(score.height, 80)
	Check.eq(score.base, 330)
	Check.eq(score.total, 330)
end)

Check.test("each trick kind has its own points", function()
	local score = Scoring.score(run({ tricks = { trick("flip", 1), trick("spin", 1), trick("roll", 1) } }), TUNING)
	Check.eq(score.trickPoints[1], 200)
	Check.eq(score.trickPoints[2], 100)
	Check.eq(score.trickPoints[3], 300)
	Check.eq(score.base, 600)
end)

Check.test("repeating a trick pays less each time, down to a floor", function()
	local flips = {}
	for _ = 1, 6 do
		table.insert(flips, trick("flip", 1))
	end
	local score = Scoring.score(run({ tricks = flips }), TUNING)
	Check.eq(score.trickPoints[1], 200)
	Check.eq(score.trickPoints[2], 100)
	Check.eq(score.trickPoints[3], 50)
	Check.eq(score.trickPoints[4], 25)
	Check.eq(score.trickPoints[5], 20, "floor is a tenth")
	Check.eq(score.trickPoints[6], 20)
	Check.eq(score.combo, 1, "one trick over and over is no combo")
end)

Check.test("the other direction is a different trick", function()
	local score = Scoring.score(run({ tricks = { trick("flip", 1), trick("flip", -1) } }), TUNING)
	Check.eq(score.trickPoints[2], 200)
	Check.near(score.combo, 1.5)
end)

Check.test("the combo grows with each different trick, up to the cap", function()
	local two = Scoring.score(run({ tricks = { trick("flip", 1), trick("spin", 1) } }), TUNING)
	Check.near(two.combo, 1.5)
	local three = Scoring.score(run({ tricks = { trick("flip", 1), trick("spin", 1), trick("roll", 1) } }), TUNING)
	Check.near(three.combo, 2)
	local five = Scoring.score(
		run({
			tricks = { trick("flip", 1), trick("spin", 1), trick("roll", 1), trick("flip", -1), trick("spin", -1) },
		}),
		TUNING
	)
	Check.near(five.combo, 2.5, "capped")
end)

Check.test("the combo multiplies the whole run", function()
	local score = Scoring.score(run({ airtime = 2, tricks = { trick("flip", 1), trick("spin", 1) } }), TUNING)
	Check.eq(score.base, 400)
	Check.eq(score.total, 600)
end)

Check.test("a clean landing multiplies on top of the combo", function()
	local score =
		Scoring.score(run({ airtime = 2, tricks = { trick("flip", 1), trick("spin", 1) }, clean = true }), TUNING)
	Check.near(score.clean, 1.5)
	Check.eq(score.total, 900)
end)

Check.test("a crash keeps the base points but loses the combo", function()
	for _, ending in { "stopped", "aborted", "crashed", "wrecked" } do
		local score = Scoring.score(
			run({ ending = ending, airtime = 2, tricks = { trick("flip", 1), trick("spin", 1) }, clean = true }),
			TUNING
		)
		Check.eq(score.base, 400, ending)
		Check.eq(score.combo, 1, ending)
		Check.eq(score.clean, 1, ending)
		Check.eq(score.total, 400, ending)
	end
end)

Check.test("points round to whole numbers", function()
	local score =
		Scoring.score(run({ airtime = 1.234, distance = 3, tricks = { trick("flip", 1), trick("spin", 1) } }), TUNING)
	Check.eq(score.airtime, 62)
	Check.eq(score.distance, 2)
	Check.eq(score.base, 364)
	Check.eq(score.total, 546)
end)

Check.test("each part smashed off the car pays Smash points", function()
	local score = Scoring.score(run({ airtime = 2 }), TUNING, 3)
	Check.eq(score.smash, 300)
	Check.eq(score.base, 400)
	Check.eq(score.total, 400)
end)

Check.test("a crash keeps its Smash points", function()
	local score = Scoring.score(run({ ending = "crashed" }), TUNING, 2)
	Check.eq(score.total, 200)
end)

Check.test("no smashes given means none", function()
	Check.eq(Scoring.score(run({ airtime = 2 }), TUNING).smash, 0)
end)

Check.test("seconds on rails pay grind points in the base", function()
	local score = Scoring.score(run({ airtime = 1, grind = 2.5 }), TUNING)
	Check.eq(score.grind, 200)
	Check.eq(score.base, 250)
end)

Check.test("grind points get the combo and clean bonus like the rest", function()
	local tricks = { trick("flip", 1), trick("spin", 1) }
	local score = Scoring.score(run({ grind = 1, tricks = tricks, clean = true }), TUNING)
	Check.eq(score.base, 380)
	Check.eq(score.total, 855)
end)

Check.test("a run without grind time has no grind points", function()
	Check.eq(Scoring.score(run({ airtime = 2 }), TUNING).grind, 0)
end)

Check.test("each gap cleared pays gap points in the base", function()
	local score = Scoring.score(run({ airtime = 1, gaps = { "Bowl Gap" } }), TUNING)
	Check.eq(score.gap, 500)
	Check.eq(score.base, 550)
	Check.eq(Scoring.score(run({ gaps = { "A", "B" } }), TUNING).gap, 1000, "two gaps")
	Check.eq(Scoring.score(run({ airtime = 1 }), TUNING).gap, 0, "none")
end)

Check.test("landing on a swing pays swing points in the base", function()
	local score = Scoring.score(run({ airtime = 1, swing = true }), TUNING)
	Check.eq(score.swing, 300)
	Check.eq(score.base, 350)
	Check.eq(Scoring.score(run({ airtime = 1, swing = false }), TUNING).swing, 0, "no swing")
end)

Check.test("a crash across a gap keeps the gap points but no combo", function()
	local tricks = { trick("flip", 1), trick("spin", 1) }
	local score = Scoring.score(run({ ending = "crashed", gaps = { "Bowl Gap" }, tricks = tricks }), TUNING)
	Check.eq(score.base, 800)
	Check.eq(score.total, 800)
end)

Check.test("tricks are named by kind and direction", function()
	Check.eq(Scoring.trickName(trick("flip", 1)), "Backflip", "nose up")
	Check.eq(Scoring.trickName(trick("flip", -1)), "Frontflip")
	Check.eq(Scoring.trickName(trick("spin", 1)), "Spin left", "nose left")
	Check.eq(Scoring.trickName(trick("spin", -1)), "Spin right")
	Check.eq(Scoring.trickName(trick("roll", 1)), "Barrel roll left", "right side up")
	Check.eq(Scoring.trickName(trick("roll", -1)), "Barrel roll right")
end)

Check.finish("Scoring")
