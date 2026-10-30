--!strict
local Check = require("./Check")
local GarageRing = require("../src/shared/GarageRing")

Check.test("one dash per count, each on the circle", function()
	local dashes = GarageRing.dashes(35, 4, 0.5)
	Check.eq(#dashes, 4, "count")
	for _, d in dashes do
		Check.near(math.sqrt(d.x * d.x + d.z * d.z), 35, "on the circle", 1e-6)
	end
end)

Check.test("dashes go evenly around, starting on the +X side", function()
	local dashes = GarageRing.dashes(10, 4, 0.5)
	Check.near(dashes[1].x, 10, "first x", 1e-6)
	Check.near(dashes[1].z, 0, "first z", 1e-6)
	Check.near(dashes[2].x, 0, "second x", 1e-6)
	Check.near(dashes[2].z, 10, "second z", 1e-6)
end)

Check.test("each dash runs along the circle, square to its radius", function()
	for _, d in GarageRing.dashes(35, 7, 0.5) do
		local dot = (d.x * d.alongX + d.z * d.alongZ) / 35
		Check.near(dot, 0, "square to the radius", 1e-6)
		Check.near(d.alongX * d.alongX + d.alongZ * d.alongZ, 1, "unit length", 1e-6)
	end
end)

Check.test("a dash's length is its share of the gap between dashes", function()
	local dash = GarageRing.dashes(35, 36, 0.5)[1]
	Check.near(dash.length, 0.5 * 2 * math.pi * 35 / 36, "half the spacing", 1e-6)
end)

Check.finish("GarageRing")
