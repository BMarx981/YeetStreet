--!strict
local Check = require("./Check")
local EngineSound = require("../src/shared/EngineSound")

local T: EngineSound.Tuning = {
	IdlePitch = 0.8,
	TopPitch = 1.8,
	GasPitch = 0.2,
	IdleVolume = 0.5,
	TopVolume = 1,
	OthersPitch = 0.9,
	OthersVolume = 0.3,
}

Check.test("a stopped car with no gas idles", function()
	local pitch, volume = EngineSound.target(0, 100, 0, false, true, T)
	Check.near(pitch, 0.8, "pitch")
	Check.near(volume, 0.5, "volume")
end)

Check.test("top speed gives top pitch and full volume", function()
	local pitch, volume = EngineSound.target(100, 100, 0, false, true, T)
	Check.near(pitch, 1.8, "pitch")
	Check.near(volume, 1, "volume")
end)

Check.test("pitch and volume rise in step with speed", function()
	local pitch, volume = EngineSound.target(50, 100, 0, false, true, T)
	Check.near(pitch, 1.3, "pitch")
	Check.near(volume, 0.75, "volume")
end)

Check.test("gas at a standstill revs and gets loud", function()
	local pitch, volume = EngineSound.target(0, 100, 1, false, true, T)
	Check.near(pitch, 1.0, "pitch")
	Check.near(volume, 1, "volume")
end)

Check.test("half gas revs half as much", function()
	local pitch, volume = EngineSound.target(0, 100, 0.5, false, true, T)
	Check.near(pitch, 0.9, "pitch")
	Check.near(volume, 0.75, "volume")
end)

Check.test("gas adds to the pitch from speed", function()
	local pitch = EngineSound.target(100, 100, 1, false, true, T)
	Check.near(pitch, 2.0, "pitch")
end)

Check.test("going past top speed on jets stays at top", function()
	local pitch, volume = EngineSound.target(250, 100, 0, false, true, T)
	Check.near(pitch, 1.8, "pitch")
	Check.near(volume, 1, "volume")
end)

Check.test("reversing sounds the same as going forward", function()
	local forwardPitch, forwardVolume = EngineSound.target(30, 100, 1, false, true, T)
	local backPitch, backVolume = EngineSound.target(-30, 100, -1, false, true, T)
	Check.near(backPitch, forwardPitch, "pitch")
	Check.near(backVolume, forwardVolume, "volume")
end)

Check.test("in the air the engine idles whatever the speed and gas", function()
	local pitch, volume = EngineSound.target(100, 100, 1, true, true, T)
	Check.near(pitch, 0.8, "pitch")
	Check.near(volume, 0.5, "volume")
end)

Check.test("other players' cars are a little lower and much quieter", function()
	local pitch, volume = EngineSound.target(50, 100, 0, false, false, T)
	Check.near(pitch, 1.3 * 0.9, "pitch")
	Check.near(volume, 0.75 * 0.3, "volume")
end)

Check.test("other players' cars idle lower and quieter in the air too", function()
	local pitch, volume = EngineSound.target(100, 100, 0, true, false, T)
	Check.near(pitch, 0.8 * 0.9, "pitch")
	Check.near(volume, 0.5 * 0.3, "volume")
end)

Check.test("a car with no top speed idles instead of dividing by zero", function()
	local pitch, volume = EngineSound.target(20, 0, 0, false, true, T)
	Check.near(pitch, 0.8, "pitch")
	Check.near(volume, 0.5, "volume")
end)

Check.test("approach moves toward the target at the rate per second", function()
	Check.near(EngineSound.approach(0.8, 1.8, 2, 0.1), 1.0)
	Check.near(EngineSound.approach(1.8, 0.8, 2, 0.1), 1.6)
end)

Check.test("approach stops at the target instead of passing it", function()
	Check.eq(EngineSound.approach(1.7, 1.8, 2, 0.1), 1.8)
	Check.eq(EngineSound.approach(0.9, 0.8, 2, 0.1), 0.8)
end)

Check.test("approach stays put when already there", function()
	Check.eq(EngineSound.approach(1.2, 1.2, 2, 0.1), 1.2)
end)

Check.finish("EngineSound")
