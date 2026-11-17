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
	Check.eq(CrashSound.hitVolume(29, "nose", 10, 10, T), 0)
end)

Check.test("a hit at HitFrom thuds at the least volume", function()
	Check.near(CrashSound.hitVolume(30, "nose", 10, 10, T), 0.4)
end)

Check.test("harder hits thud louder", function()
	Check.near(CrashSound.hitVolume(80, "nose", 10, 10, T), 0.7)
end)

Check.test("a hit at or past HitFull thuds at full volume", function()
	Check.near(CrashSound.hitVolume(130, "nose", 10, 10, T), 1)
	Check.near(CrashSound.hitVolume(500, "nose", 10, 10, T), 1)
end)

Check.test("a hit right after the last thud makes none", function()
	Check.eq(CrashSound.hitVolume(100, "nose", 0.1, 10, T), 0)
end)

Check.test("a hit once the gap has passed thuds again", function()
	Check.near(CrashSound.hitVolume(130, "nose", 0.2, 10, T), 1)
end)

Check.test("a jolt just after the car was pushed, like a launch, makes no thud", function()
	Check.eq(CrashSound.hitVolume(130, "nose", 10, 0.1, T), 0)
end)

Check.test("a hit once PushGrace has passed since a push thuds", function()
	Check.near(CrashSound.hitVolume(130, "nose", 10, 0.3, T), 1)
end)

Check.test("a landing on the underside makes no thud, however hard", function()
	Check.eq(CrashSound.hitVolume(500, "underside", 10, 10, T), 0)
end)

Check.test("hits on the roof, tail, and sides thud like the nose", function()
	Check.near(CrashSound.hitVolume(130, "roof", 10, 10, T), 1, "roof")
	Check.near(CrashSound.hitVolume(130, "tail", 10, 10, T), 1, "tail")
	Check.near(CrashSound.hitVolume(130, "sides", 10, 10, T), 1, "sides")
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
