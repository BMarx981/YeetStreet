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

local function count(set: { [number]: boolean }): number
	local n = 0
	for _ in set do
		n += 1
	end
	return n
end

Check.test("nearest picks the closest cars up to the count", function()
	local picked = EngineSound.nearest({ 80, 20, 140, 50, 10 }, 3, 150)
	Check.eq(count(picked), 3, "count")
	Check.eq(picked[5], true, "10 studs")
	Check.eq(picked[2], true, "20 studs")
	Check.eq(picked[4], true, "50 studs")
	Check.eq(picked[1], nil, "80 studs")
	Check.eq(picked[3], nil, "140 studs")
end)

Check.test("nearest leaves out cars at or past the reach", function()
	local picked = EngineSound.nearest({ 150, 30, 400 }, 4, 150)
	Check.eq(count(picked), 1, "count")
	Check.eq(picked[2], true, "30 studs")
end)

Check.test("nearest takes every car in reach when there are fewer than the count", function()
	local picked = EngineSound.nearest({ 60, 90 }, 4, 150)
	Check.eq(count(picked), 2, "count")
end)

Check.test("nearest breaks ties by order so the pick doesn't flicker", function()
	local picked = EngineSound.nearest({ 40, 40, 40 }, 2, 150)
	Check.eq(picked[1], true, "first")
	Check.eq(picked[2], true, "second")
	Check.eq(picked[3], nil, "third")
end)

Check.test("nearest with no cars or a zero count picks none", function()
	Check.eq(count(EngineSound.nearest({}, 4, 150)), 0, "no cars")
	Check.eq(count(EngineSound.nearest({ 10 }, 0, 150)), 0, "zero count")
end)

Check.test("jets that aren't burning are silent", function()
	local _, volume = EngineSound.jet(false, true, T)
	Check.eq(volume, 0, "volume")
end)

Check.test("your own jets burn at full pitch and volume", function()
	local pitch, volume = EngineSound.jet(true, true, T)
	Check.near(pitch, 1, "pitch")
	Check.near(volume, 1, "volume")
end)

Check.test("other players' jets are a little lower and much quieter", function()
	local pitch, volume = EngineSound.jet(true, false, T)
	Check.near(pitch, 0.9, "pitch")
	Check.near(volume, 0.3, "volume")
end)

Check.test("jets keep their pitch while they fade out", function()
	local pitch = EngineSound.jet(false, false, T)
	Check.near(pitch, 0.9, "pitch")
end)

local SETTINGS: { EngineSound.Setting } = {
	{ Name = "On", Volume = 1 },
	{ Name = "Low", Volume = 0.35 },
	{ Name = "Off", Volume = 0 },
}

Check.test("a saved setting that is one of the choices is kept", function()
	Check.eq(EngineSound.setting("Low", SETTINGS), "Low")
	Check.eq(EngineSound.setting("Off", SETTINGS), "Off")
end)

Check.test("no setting or an unknown one falls back to the first choice", function()
	Check.eq(EngineSound.setting(nil, SETTINGS), "On", "nil")
	Check.eq(EngineSound.setting("Loud", SETTINGS), "On", "unknown name")
	Check.eq(EngineSound.setting(2, SETTINGS), "On", "a number")
end)

Check.test("each setting scales the volume by its own amount", function()
	Check.near(EngineSound.settingVolume("On", SETTINGS), 1, "on")
	Check.near(EngineSound.settingVolume("Low", SETTINGS), 0.35, "low")
	Check.near(EngineSound.settingVolume("Off", SETTINGS), 0, "off")
end)

Check.test("an unknown setting plays at the first choice's volume", function()
	Check.near(EngineSound.settingVolume(nil, SETTINGS), 1)
end)

Check.test("a crossfaded loop is silent at its seam and full halfway", function()
	Check.near(EngineSound.seamGain(0.05, 0.05, 2.05, 0.1), 0, "at the start")
	Check.near(EngineSound.seamGain(2.05, 0.05, 2.05, 0.1), 0, "at the end")
	Check.near(EngineSound.seamGain(1.05, 0.05, 2.05, 0.1), 1, "halfway")
end)

Check.test("a crossfaded loop stays silent for its quiet time either side of the seam", function()
	Check.near(EngineSound.seamGain(0.14, 0.05, 2.05, 0.1), 0, "just after the start")
	Check.near(EngineSound.seamGain(1.96, 0.05, 2.05, 0.1), 0, "just before the end")
	Check.eq(EngineSound.seamGain(0.2, 0.05, 2.05, 0.1) > 0, true, "past the quiet time")
end)

Check.test("a crossfaded loop is at full volume while its twin is quiet", function()
	Check.near(EngineSound.seamGain(0.98, 0.05, 2.05, 0.1), 1, "just before halfway")
	Check.near(EngineSound.seamGain(1.12, 0.05, 2.05, 0.1), 1, "just after halfway")
end)

Check.test("a crossfaded loop outside its region is silent", function()
	Check.near(EngineSound.seamGain(0, 0.05, 2.05, 0.1), 0, "before")
	Check.near(EngineSound.seamGain(3, 0.05, 2.05, 0.1), 0, "after")
end)

Check.test("the twin starts half a loop on, wrapping round the region", function()
	Check.near(EngineSound.twinStart(0.05, 0.05, 2.05), 1.05, "from the start")
	Check.near(EngineSound.twinStart(1.55, 0.05, 2.05), 0.55, "wrapped")
	Check.near(EngineSound.twinStart(0, 0.05, 2.05), 1.05, "from before the region")
end)

Check.test("two twins half a loop apart keep the same total power", function()
	for _, t in { 0.05, 0.1, 0.3, 0.8, 1.05, 1.6, 2.0 } do
		local a = EngineSound.seamGain(t, 0.05, 2.05, 0.1)
		local b = EngineSound.seamGain(EngineSound.twinStart(t, 0.05, 2.05), 0.05, 2.05, 0.1)
		Check.near(a * a + b * b, 1, `at {t}`)
	end
end)

Check.finish("EngineSound")
