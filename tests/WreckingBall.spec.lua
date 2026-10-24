--!strict
local Check = require("./Check")
local WreckingBall = require("../src/shared/WreckingBall")

local TUNING: WreckingBall.Tuning = {
	Period = 4,
	Radius = 8,
	Reach = 5,
	Smack = 140,
	Lift = 110,
	MinShare = 0.5,
}

local LAYOUT: WreckingBall.Layout = {
	AvenueWidth = 160,
	StreetWidth = 100,
	Lot = 160,
	Alley = 50,
	Setback = 20,
}

local BALL: WreckingBall.Ball = { length = 200, amplitude = math.rad(20), phase = 0 }
local PERIOD = 4
local RATE = 2 * math.pi / PERIOD

Check.test("a ball swings back and forth once a Period", function()
	Check.near(WreckingBall.rate(PERIOD), RATE)
	local x, y = WreckingBall.center(BALL, 0, PERIOD)
	Check.near(x, 0, "straight down at the start")
	Check.near(y, -200, "a length below the pivot")
	local x2, y2 = WreckingBall.center(BALL, PERIOD, PERIOD)
	Check.near(x2, x, "back after a period", 1e-6)
	Check.near(y2, y, "back after a period", 1e-6)
end)

Check.test("it reaches its amplitude a quarter period in, still for a moment", function()
	local x, y, sx, sy = WreckingBall.center(BALL, PERIOD / 4, PERIOD)
	Check.near(x, 200 * math.sin(math.rad(20)), "out across", 1e-6)
	Check.near(y, -200 * math.cos(math.rad(20)), "and up a little", 1e-6)
	Check.near(sx, 0, "stopped", 1e-6)
	Check.near(sy, 0, "stopped", 1e-6)
end)

Check.test("it is fastest at the bottom, moving across", function()
	local _, _, sx, sy = WreckingBall.center(BALL, 0, PERIOD)
	Check.near(sx, math.rad(20) * RATE * 200, "full speed across", 1e-6)
	Check.near(sy, 0, "level", 1e-6)
end)

Check.test("the phase shifts the swing along its cycle", function()
	local shifted: WreckingBall.Ball = { length = 200, amplitude = math.rad(20), phase = math.pi / 2 }
	local x = WreckingBall.center(shifted, 0, PERIOD)
	Check.near(x, 200 * math.sin(math.rad(20)), "starts at the end of its swing", 1e-6)
end)

Check.test("a car out of reach is not pushed", function()
	local vx, vy, vz = WreckingBall.push(BALL, 0, 30, -200, 0, 0, 0, 50, TUNING)
	Check.eq(vx, nil)
	Check.eq(vy, nil)
	Check.eq(vz, nil)
end)

Check.test("the ball swinging into a car at the bottom smacks it away at full strength", function()
	-- The ball moves +X at the bottom; the car is just ahead of it.
	local vx, vy, vz = WreckingBall.push(BALL, 0, 10, -200, 0, 0, 0, 50, TUNING)
	Check.near(vx :: number, 140, "thrown the way the ball swings")
	Check.near(vy :: number, 110, "and up")
	Check.near(vz :: number, 50, "keeping its speed along the street")
end)

Check.test("a car the ball swings away from is pushed off it at the least", function()
	local vx, vy = WreckingBall.push(BALL, 0, -10, -200, 0, 0, 0, 0, TUNING)
	Check.near(vx :: number, -70, "away from the ball, MinShare of Smack")
	Check.near(vy :: number, 55, "MinShare of Lift")
end)

Check.test("a ball at the end of its swing still pushes at the least", function()
	local x, y = WreckingBall.center(BALL, PERIOD / 4, PERIOD)
	local vx, vy = WreckingBall.push(BALL, PERIOD / 4, x - 9, y, 0, 0, 0, 0, TUNING)
	Check.near(vx :: number, -70, "pushed away")
	Check.near(vy :: number, 55)
end)

Check.test("a car already going faster away keeps its speed", function()
	local vx, vy = WreckingBall.push(BALL, 0, 10, -200, 0, 200, 150, 0, TUNING)
	Check.near(vx :: number, 200, "already faster across")
	Check.near(vy :: number, 150, "already climbing faster")
end)

Check.test("reaches finds the ball passing a point within the time window", function()
	-- The ball is at the bottom at times 0 and PERIOD / 2.
	Check.eq(WreckingBall.reaches(BALL, -0.1, 0.1, 0, -200, 0, 10, PERIOD), true)
	Check.eq(WreckingBall.reaches(BALL, PERIOD / 4 - 0.1, PERIOD / 4 + 0.1, 0, -200, 0, 10, PERIOD), false)
	Check.eq(WreckingBall.reaches(BALL, -0.1, 0.1, 0, -200, 30, 10, PERIOD), false, "too far along the street")
end)

Check.test("amplitude sweeps the ball out to the given distance", function()
	Check.near(WreckingBall.amplitude(200, 66), math.asin(66 / 200))
	Check.near(WreckingBall.amplitude(50, 66), math.asin(0.9), "never past MaxSine")
	Check.near(WreckingBall.amplitude(200, -5), 0, "no room, no swing")
end)

local function building(x: number, z: number): WreckingBall.Building
	return { x = x, z = z, height = 100 }
end

Check.test("an avenue site is the first column's building nearest the spot", function()
	local buildings = {
		building(180, -160),
		building(180, -370),
		building(390, -370), -- second column, not on the avenue
		building(-180, -370), -- the other side
	}
	local site = WreckingBall.site(buildings, { Along = -400, Side = 1 }, LAYOUT, 220) :: WreckingBall.Site
	Check.eq(site.building, buildings[2])
	Check.near(site.outX, -1, "facing the avenue")
	Check.near(site.outZ, 0)
	Check.near(site.pivotX, 0, "over the avenue's middle")
	Check.near(site.pivotZ, -370)
	Check.near(site.gap, 20, "the setback")
	Check.near(site.halfStreet, 80)
end)

Check.test("a cross street site takes the nearest row on its side, however far back", function()
	local buildings = {
		building(600, -370), -- the bottom row, its face 100 back from the street
		building(600, -160), -- a row further back
		building(600, -750), -- the other side of the street
	}
	local site =
		WreckingBall.site(buildings, { Street = -600, Along = 600, Side = 1 }, LAYOUT, 220) :: WreckingBall.Site
	Check.eq(site.building, buildings[1])
	Check.near(site.outX, 0)
	Check.near(site.outZ, -1, "facing the street")
	Check.near(site.pivotX, 600)
	Check.near(site.pivotZ, -600, "over the street's middle")
	Check.near(site.gap, 100)
	Check.near(site.halfStreet, 50)

	local south =
		WreckingBall.site(buildings, { Street = -600, Along = 600, Side = -1 }, LAYOUT, 220) :: WreckingBall.Site
	Check.eq(south.building, buildings[3])
	Check.near(south.outZ, 1)
	Check.near(south.gap, 20)
end)

Check.test("no site when the nearest building is too far along", function()
	local buildings = { building(180, -900) }
	Check.eq(WreckingBall.site(buildings, { Along = -400, Side = 1 }, LAYOUT, 220), nil)
end)

Check.finish("WreckingBall")
