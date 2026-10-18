--!strict
-- CarDamage (ModuleScript) -> ServerScriptService.CarDamage
-- Counts the parts knocked off a car. The parts exist only on clients
-- (CarVisuals), built from the car's look attributes, so the server works out
-- the same breakable parts from CarDesign and writes how many are broken in
-- each slot as Broken<Slot> attributes (CarParts). Every client knocks off the
-- same parts, in CarDesign.breakable order. A respawned car is a new model,
-- with none broken.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarDesign = require(ReplicatedStorage.CarDesign)
local CarParts = require(ReplicatedStorage.CarParts)

local CarDamage = {}

-- Breakable parts in each slot, worked out once per car.
local totals: { [Model]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any

local function totalsFor(car: Model): { [string]: number }?
	local cached = totals[car]
	if cached then
		return cached
	end
	local design = CarParts.designFor(car)
	if not design then
		warn(`CarDamage: {car.Name} has no look attributes`)
		return nil
	end
	local counts = {}
	for _, slot in CarParts.Slots do
		counts[slot] = #CarDesign.breakable(design, slot)
	end
	totals[car] = counts
	return counts
end

-- Breaks up to `count` parts in `slot`, or in any slot when `slot` is nil.
-- Returns how many broke, which is fewer once there are none left to break.
function CarDamage.breakParts(car: Model, slot: string?, count: number): number
	local counts = totalsFor(car)
	if not counts then
		return 0
	end
	local broken = 0
	for _, s in CarParts.Slots do
		if slot == nil or s == slot then
			local attribute = CarParts.brokenAttribute(s)
			local value = car:GetAttribute(attribute)
			local already = if typeof(value) == "number" then value else 0
			local more = math.clamp(count - broken, 0, counts[s] - already)
			if more > 0 then
				car:SetAttribute(attribute, already + more)
				broken += more
			end
		end
	end
	return broken
end

return CarDamage
