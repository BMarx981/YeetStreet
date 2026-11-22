--!strict
local Check = require("./Check")
local Rng = require("../src/shared/Rng")
local Shredder = require("../src/shared/Shredder")

local CONFIG: Shredder.Config = {
	Length = 70,
	Width = 50,
	RimHeight = 14,
	CatchAbove = 4,
	ChewBase = 1.5,
	ChewPerToughness = 0.02,
	ChewMax = 6,
	Settle = 0.5,
	SinkDepth = 6,
	Shake = 0.4,
	ShakeRate = 9,
	SprayUp = 70,
	SprayUpJitter = 30,
	SpraySide = 20,
	Tiers = {
		{ Min = 0, Target = "Shredder" },
		{ Min = 350, Target = "Long shred" },
		{ Min = 550, Target = "Mega shred" },
	},
}

Check.test("a hull inside the opening and below the catch line is caught", function()
	Check.eq(Shredder.inside(CONFIG, 0, 14, 0), true, "middle, at the rim")
	Check.eq(Shredder.inside(CONFIG, 34, 2, 24), true, "near a corner, low")
	Check.eq(Shredder.inside(CONFIG, 0, 18.5, 0), false, "above the catch line")
	Check.eq(Shredder.inside(CONFIG, 36, 10, 0), false, "past the end")
	Check.eq(Shredder.inside(CONFIG, 0, 10, -26), false, "past the side")
	Check.eq(Shredder.inside(CONFIG, 0, -1, 0), false, "under the floor")
end)

Check.test("tougher cars take longer to chew, up to ChewMax", function()
	Check.near(Shredder.chewTime(CONFIG, 0), 1.5)
	Check.near(Shredder.chewTime(CONFIG, 100), 3.5)
	Check.near(Shredder.chewTime(CONFIG, 1000), 6)
end)

Check.test("a longer jump in pays a bigger target", function()
	Check.eq(Shredder.target(CONFIG, 0), "Shredder")
	Check.eq(Shredder.target(CONFIG, 349), "Shredder")
	Check.eq(Shredder.target(CONFIG, 350), "Long shred")
	Check.eq(Shredder.target(CONFIG, 549), "Long shred")
	Check.eq(Shredder.target(CONFIG, 900), "Mega shred")
end)

Check.test("the kicker's speed carries a car the distance to the rim's height", function()
	local gravity = 130
	for _, case in { { 220, 30, 4 }, { 150, 25, -3 }, { 300, 40, 10 } } do
		local distance, angle, rise = case[1], case[2], case[3]
		local speed = Shredder.launchSpeed(distance, angle, rise, gravity)
		assert(speed, "reachable")
		local a = math.rad(angle)
		local t = distance / (speed * math.cos(a))
		local height = speed * math.sin(a) * t - gravity * t * t / 2
		Check.near(height, rise, `height at {distance}`, 1e-6)
	end
end)

Check.test("no speed reaches a rim above the launch's line", function()
	Check.eq(Shredder.launchSpeed(100, 10, 30, 130), nil)
end)

Check.test("a caught car settles onto the rollers, then sinks into them while it is chewed", function()
	local chew = 3
	local start = Shredder.pose(CONFIG, 0, chew)
	Check.near(start.blend, 0, "blend at the catch")
	Check.near(start.sink, 0, "sink at the catch")
	local half = Shredder.pose(CONFIG, CONFIG.Settle + chew / 2, chew)
	Check.near(half.blend, 1, "settled")
	Check.near(half.sink, 3, "half sunk")
	local done = Shredder.pose(CONFIG, CONFIG.Settle + chew + 5, chew)
	Check.near(done.sink, CONFIG.SinkDepth, "no deeper than SinkDepth")
	for t = 0, 4, 0.13 do
		local pose = Shredder.pose(CONFIG, t, chew)
		assert(math.abs(pose.shakeX) <= CONFIG.Shake + 1e-9, "shakes no more than Shake across")
		assert(math.abs(pose.shakeZ) <= CONFIG.Shake + 1e-9, "shakes no more than Shake along")
		assert(pose.blend >= 0 and pose.blend <= 1, "blend in 0..1")
	end
end)

Check.test("chewed bits spray up out of the top, a little to the sides", function()
	local rng = Rng.new(3)
	local lowest, highest, widest = math.huge, -math.huge, 0
	for _ = 1, 500 do
		local x, y, z = Shredder.spray(CONFIG, rng)
		lowest = math.min(lowest, y)
		highest = math.max(highest, y)
		widest = math.max(widest, math.abs(x), math.abs(z))
	end
	assert(lowest >= CONFIG.SprayUp, `up at least SprayUp, got {lowest}`)
	assert(highest <= CONFIG.SprayUp + CONFIG.SprayUpJitter, `up at most SprayUp + SprayUpJitter, got {highest}`)
	assert(widest <= CONFIG.SpraySide, `sideways at most SpraySide, got {widest}`)
	assert(widest > CONFIG.SpraySide / 2, "spreads out")
end)

Check.finish("Shredder")
