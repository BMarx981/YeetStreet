--!strict
local Check = require("./Check")
local Coins = require("../src/shared/Coins")

local START: Coins.Point = { x = 0, y = 0, z = 0 }
local VELOCITY: Coins.Point = { x = 0, y = 100, z = 50 }
local GRAVITY = 100

local function arcTuning(max: number): Coins.ArcTuning
	return { FirstAt = 0.5, Gap = 0.5, Max = max }
end

Check.test("coins follow the arc at even times after the lip", function()
	local points = Coins.arc(START, VELOCITY, GRAVITY, arcTuning(10))
	Check.eq(#points, 4)
	Check.near(points[1].y, 37.5)
	Check.near(points[1].z, 25)
	Check.near(points[2].y, 50)
	Check.near(points[2].z, 50)
	Check.near(points[3].y, 37.5)
	Check.near(points[4].y, 0)
	Check.near(points[4].z, 100)
end)

Check.test("the arc stops once it falls below the lip", function()
	local points = Coins.arc(START, VELOCITY, GRAVITY, { FirstAt = 0.5, Gap = 0.4, Max = 10 })
	for _, p in points do
		Check.eq(p.y >= 0, true, `coin at y {p.y}`)
	end
	Check.eq(#points, 4)
end)

Check.test("the arc has at most Max coins", function()
	Check.eq(#Coins.arc(START, VELOCITY, GRAVITY, arcTuning(2)), 2)
end)

Check.test("the apex is where the climb stops", function()
	local top = Coins.apex(START, VELOCITY, GRAVITY)
	Check.near(top.x, 0)
	Check.near(top.y, 50)
	Check.near(top.z, 50)
end)

Check.test("near is within the radius", function()
	local a: Coins.Point = { x = 0, y = 0, z = 0 }
	Check.eq(Coins.near(a, { x = 3, y = 4, z = 0 }, 5), true)
	Check.eq(Coins.near(a, { x = 3, y = 4, z = 0.1 }, 5), false)
end)

Check.test("a gem comes back after its wait", function()
	Check.eq(Coins.gemReady(nil, 100, 300), true)
	Check.eq(Coins.gemReady(0, 299, 300), false)
	Check.eq(Coins.gemReady(0, 300, 300), true)
end)

Check.finish("Coins")
