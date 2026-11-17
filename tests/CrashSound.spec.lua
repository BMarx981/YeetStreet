--!strict
local Check = require("./Check")
local CrashSound = require("../src/shared/CrashSound")

local T: CrashSound.Tuning = {
	HitFrom = 30,
	HitFull = 130,
	HitMinVolume = 0.4,
	HitGap = 0.2,
	PushGrace = 0.3,
}

Check.test("a hit softer than HitFrom makes no thud", function()
	Check.eq(CrashSound.hitVolume(29, 10, 10, T), 0)
end)

Check.test("a hit at HitFrom thuds at the least volume", function()
	Check.near(CrashSound.hitVolume(30, 10, 10, T), 0.4)
end)

Check.test("harder hits thud louder", function()
	Check.near(CrashSound.hitVolume(80, 10, 10, T), 0.7)
end)

Check.test("a hit at or past HitFull thuds at full volume", function()
	Check.near(CrashSound.hitVolume(130, 10, 10, T), 1)
	Check.near(CrashSound.hitVolume(500, 10, 10, T), 1)
end)

Check.test("a hit right after the last thud makes none", function()
	Check.eq(CrashSound.hitVolume(100, 0.1, 10, T), 0)
end)

Check.test("a hit once the gap has passed thuds again", function()
	Check.near(CrashSound.hitVolume(130, 0.2, 10, T), 1)
end)

Check.test("a jolt just after the car was pushed, like a launch, makes no thud", function()
	Check.eq(CrashSound.hitVolume(130, 10, 0.1, T), 0)
end)

Check.test("a hit once PushGrace has passed since a push thuds", function()
	Check.near(CrashSound.hitVolume(130, 10, 0.3, T), 1)
end)

Check.test("pick turns a roll into one of the sounds", function()
	Check.eq(CrashSound.pick(2, 0), 1, "low roll")
	Check.eq(CrashSound.pick(2, 0.49), 1, "under half")
	Check.eq(CrashSound.pick(2, 0.5), 2, "half")
	Check.eq(CrashSound.pick(2, 0.99), 2, "high roll")
end)

Check.test("pick stays in range for a roll of 1", function()
	Check.eq(CrashSound.pick(2, 1), 2)
end)

Check.test("pick with one sound always picks it", function()
	Check.eq(CrashSound.pick(1, 0.7), 1)
end)

Check.finish("CrashSound")
