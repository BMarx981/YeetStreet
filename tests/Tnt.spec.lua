--!strict
local Check = require("./Check")
local Rng = require("../src/shared/Rng")
local Tnt = require("../src/shared/Tnt")

local CONFIG: Tnt.Config = {
	Width = 200,
	Depth = 100,
	Spacing = 50,
	Jitter = 10,
	Radius = 3,
	Height = 7,
	Trigger = 3,
	BlastRadius = 30,
	Up = 160,
	Out = 70,
	MinShare = 0.5,
	ChainRadius = 20,
}

Check.test("the field is a jittered grid, the same every time", function()
	local a, b = Tnt.layout(CONFIG, Rng.new(7)), Tnt.layout(CONFIG, Rng.new(7))
	Check.eq(#a, 8, "4 across by 2 deep")
	for i, spot in a do
		Check.eq(spot.x, b[i].x)
		Check.eq(spot.z, b[i].z)
	end
end)

Check.test("every barrel is near its grid spot, inside the field", function()
	local spots = Tnt.layout(CONFIG, Rng.new(7))
	local grid = { -75, -25, 25, 75 }
	for i, spot in spots do
		local column = grid[(i - 1) % 4 + 1]
		Check.eq(math.abs(spot.x - column) <= 10, true, `barrel {i} across`)
		Check.eq(math.abs(spot.x) <= 100 and math.abs(spot.z) <= 50, true, `barrel {i} inside`)
	end
end)

Check.test("another seed jitters them differently", function()
	local a, b = Tnt.layout(CONFIG, Rng.new(7)), Tnt.layout(CONFIG, Rng.new(8))
	local same = true
	for i, spot in a do
		same = same and spot.x == b[i].x and spot.z == b[i].z
	end
	Check.eq(same, false)
end)

Check.test("a car touches a barrel only close beside it and low enough", function()
	Check.eq(Tnt.touches(CONFIG, 5, 2, 0), true)
	Check.eq(Tnt.touches(CONFIG, 4, 2, 4), true, "corner")
	Check.eq(Tnt.touches(CONFIG, 7, 2, 0), false, "too far")
	Check.eq(Tnt.touches(CONFIG, 0, 11, 0), false, "flying over")
end)

Check.test("the blast throws a car up and out, less further away", function()
	local vx, vy, vz = Tnt.blast(CONFIG, 0, 0)
	Check.near(vx :: number, 0, "right on top: straight up")
	Check.near(vy :: number, 160)
	Check.near(vz :: number, 0)
	vx, vy, vz = Tnt.blast(CONFIG, 15, 0)
	Check.near(vx :: number, 70 * 0.75, "halfway: three quarters")
	Check.near(vy :: number, 160 * 0.75)
	Check.near(vz :: number, 0)
	vx, vy, vz = Tnt.blast(CONFIG, 0, -30)
	Check.near(vz :: number, -70 * 0.5, "at the edge: the least share")
	Check.eq(Tnt.blast(CONFIG, 31, 0), nil, "out of reach")
end)

Check.test("a blast sets off the barrels near it, but not itself", function()
	local spots = { { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 100, z = 0 }, { x = 0, z = -19 } }
	local near = Tnt.chained(CONFIG, spots, 1)
	table.sort(near)
	Check.eq(#near, 2)
	Check.eq(near[1], 2)
	Check.eq(near[2], 4)
end)

Check.finish("Tnt")
