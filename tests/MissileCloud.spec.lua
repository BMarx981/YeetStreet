--!strict
local Check = require("./Check")
local MissileCloud = require("../src/shared/MissileCloud")
local Rng = require("../src/shared/Rng")

local CLOUD: MissileCloud.Config = {
	Rise = 3,
	Stem = { Puffs = 10, Height = 180, Radius = 22 },
	Cap = { Puffs = 18, Height = 200, Reach = 90, Radius = 38, Crown = 8, CrownReach = 40, CrownRise = 35 },
	Base = { Puffs = 10, Reach = 60, Radius = 28 },
}

local function kinds(puffs: { MissileCloud.Puff }, kind: string): { MissileCloud.Puff }
	local found = {}
	for _, puff in puffs do
		if puff.kind == kind then
			table.insert(found, puff)
		end
	end
	return found
end

Check.test("a car inside the radius is caught, and one past it is not", function()
	Check.eq(MissileCloud.inBlast(100, 0, 0, 0, 99, 0, 0), true, "inside")
	Check.eq(MissileCloud.inBlast(100, 0, 0, 0, 101, 0, 0), false, "outside")
	Check.eq(MissileCloud.inBlast(100, 10, 50, 10, 10, 149, 10), true, "above")
	Check.eq(MissileCloud.inBlast(100, 10, 50, 10, 10, 151, 10), false, "too far above")
end)

Check.test("the cloud has every puff", function()
	local puffs = MissileCloud.puffs(CLOUD, Rng.new(1))
	Check.eq(#kinds(puffs, "stem"), 10, "stem")
	Check.eq(#kinds(puffs, "cap"), 26, "cap and crown")
	Check.eq(#kinds(puffs, "base"), 10, "base")
end)

Check.test("the stem climbs to the cap, and stays narrow", function()
	local top = 0
	for _, puff in kinds(MissileCloud.puffs(CLOUD, Rng.new(1)), "stem") do
		top = math.max(top, puff.y)
		Check.eq(math.sqrt(puff.x ^ 2 + puff.z ^ 2) < 22, true, "narrow")
	end
	Check.near(top, 180, "reaches its height", 1)
end)

Check.test("the cap is far wider than the stem, and on top of it", function()
	local widest, lowest = 0, math.huge
	for _, puff in kinds(MissileCloud.puffs(CLOUD, Rng.new(1)), "cap") do
		widest = math.max(widest, math.sqrt(puff.x ^ 2 + puff.z ^ 2) + puff.radius)
		lowest = math.min(lowest, puff.y)
	end
	Check.eq(widest > 100, true, "wide")
	Check.eq(lowest > 180, true, "above the stem's top")
end)

Check.test("puffs higher up start later, within the rise", function()
	local low, high = math.huge, -math.huge
	for _, puff in MissileCloud.puffs(CLOUD, Rng.new(1)) do
		Check.eq(puff.delay >= 0 and puff.delay <= 3, true, "within the rise")
		if puff.kind == "base" then
			low = math.min(low, puff.delay)
		elseif puff.kind == "cap" then
			high = math.max(high, puff.delay)
		end
	end
	Check.eq(high > low, true)
end)

Check.test("the same seed makes the same cloud", function()
	local a = MissileCloud.puffs(CLOUD, Rng.new(7))
	local b = MissileCloud.puffs(CLOUD, Rng.new(7))
	Check.near(a[5].x, b[5].x, "x")
	Check.near(a[5].radius, b[5].radius, "radius")
end)

Check.finish()
