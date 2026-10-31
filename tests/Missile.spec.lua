--!strict
local Check = require("./Check")
local Missile = require("../src/shared/Missile")
local Rng = require("../src/shared/Rng")

local CONFIG: Missile.Config = {
	Ignition = 1,
	Speed = 260,
	ExitHeight = 120,
	PitchRate = 12,
	MinPitch = -80,
	SteerYaw = 5,
	SteerPitch = 6,
	Wander = 3,
	WanderRate = 0.7,
}

local BOUNDS = { MinX = -2900, MaxX = 2900, MinZ = -5900, MaxZ = 800 }

local function flying(): Missile.State
	local s = Missile.new(0, -600, 0, 0, 0)
	s.wait = 0
	s.y = 200
	return s
end

Check.test("it waits out its ignition, then goes straight up", function()
	local s = Missile.new(10, -600, 20, 0, 0)
	Missile.step(s, CONFIG, 0, 0, 0.5)
	Check.near(s.y, -600, "still on the pad")
	Missile.step(s, CONFIG, 0, 0, 0.5)
	Missile.step(s, CONFIG, 0, 0, 1)
	Check.near(s.y, -340, "a second of thrust")
	Check.near(s.x, 10, "x")
	Check.near(s.z, 20, "z")
end)

Check.test("steering does nothing until it is out of the hole", function()
	local s = Missile.new(0, -600, 0, 0, 0)
	s.wait = 0
	Missile.step(s, CONFIG, 1, 1, 1)
	Check.near(s.azimuth, 0, "azimuth")
	Check.near(s.pitch, 90, "pitch")
	Check.eq(Missile.climbing(s, CONFIG), true)
end)

Check.test("coming back down low is not climbing", function()
	local s = flying()
	s.pitch = -40
	s.y = 50
	Check.eq(Missile.climbing(s, CONFIG), false, "low on the way down")
	Missile.step(s, CONFIG, 0, 0, 1)
	Check.near(s.pitch, -52, "still turning")
end)

Check.test("out of the hole it pitches over on its own", function()
	local s = flying()
	Check.eq(Missile.climbing(s, CONFIG), false)
	Missile.step(s, CONFIG, 0, 0, 1)
	Check.near(s.pitch, 78)
end)

Check.test("full nose up slows the dive but can't stop it", function()
	local s = flying()
	Missile.step(s, CONFIG, 0, 1, 1)
	Check.near(s.pitch, 84)
end)

local CALM = table.clone(CONFIG)
CALM.Wander = 0

Check.test("steering turns it only a little", function()
	local s = flying()
	Missile.step(s, CALM, 1, 0, 1)
	Check.near(s.azimuth, 5, "right")
	Missile.step(s, CALM, -1, 0, 2)
	Check.near(s.azimuth, -5, "left")
end)

Check.test("steering past full is held to full", function()
	local s = flying()
	Missile.step(s, CALM, 100, 0, 1)
	Check.near(s.azimuth, 5)
end)

Check.test("the nose never goes past MinPitch", function()
	local s = flying()
	Missile.step(s, CONFIG, 0, 0, 100)
	Check.near(s.pitch, -80)
end)

Check.test("the direction is along the heading and pitch", function()
	local s = flying()
	s.pitch = 0
	local x, y, z = Missile.direction(s)
	Check.near(x, 1, "x")
	Check.near(y, 0, "y", 1e-9)
	Check.near(z, 0, "z", 1e-9)
	s.azimuth, s.pitch = 90, 30
	x, y, z = Missile.direction(s)
	Check.near(x, 0, "x", 1e-9)
	Check.near(y, 0.5, "y")
	Check.near(z, math.sqrt(0.75), "z")
end)

Check.test("the roof stays square to the nose, and leans back on the way up", function()
	local s = flying()
	s.azimuth, s.pitch = 0, 90
	local x, y, z = Missile.up(s)
	Check.near(x, -1, "straight up, roof back")
	Check.near(y, 0, "y", 1e-9)
	Check.near(z, 0, "z", 1e-9)
	s.pitch = 0
	x, y, z = Missile.up(s)
	Check.near(x, 0, "level, roof up", 1e-9)
	Check.near(y, 1, "y")
end)

Check.test("it moves at its speed along its direction", function()
	local s = flying()
	s.pitch = 90
	Missile.step(s, CONFIG, 0, 0, 0.001)
	Check.near(s.y, 200.26, "up", 0.01)
end)

Check.test("the wander drifts it with no steering", function()
	local s = flying()
	s.wander = math.pi / 2
	Missile.step(s, CONFIG, 0, 0, 0.1)
	Check.eq(s.azimuth ~= 0, true)
end)

Check.test("a picked heading lands on the map from the silo, without steering", function()
	local rng = Rng.new(5)
	for _ = 1, 20 do
		local azimuth = Missile.pickHeading(CONFIG, rng, 1750, -600, -5235, BOUNDS)
		local x, z = Missile.landing(CONFIG, 1750, -600, -5235, azimuth)
		Check.eq(x >= BOUNDS.MinX and x <= BOUNDS.MaxX, true, "x")
		Check.eq(z >= BOUNDS.MinZ and z <= BOUNDS.MaxZ, true, "z")
	end
end)

Check.test("picked headings differ", function()
	local rng = Rng.new(5)
	local first = Missile.pickHeading(CONFIG, rng, 1750, -600, -5235, BOUNDS)
	local differs = false
	for _ = 1, 10 do
		if math.abs(Missile.pickHeading(CONFIG, rng, 1750, -600, -5235, BOUNDS) - first) > 5 then
			differs = true
		end
	end
	Check.eq(differs, true)
end)

Check.finish()
