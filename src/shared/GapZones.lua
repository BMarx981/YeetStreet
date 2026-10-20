--!strict
-- GapZones (ModuleScript) -> ReplicatedStorage.GapZones
-- Every part tagged Gap, as a Gap.Gap centered on the part, with its name and
-- ring from the part's GapName, Inner, Outer, and MinAngle attributes. Parks
-- tag their gaps; whoever scores a run (CarController, ScoreService) asks
-- here which gaps it cleared. Gaps never move, so each is read once.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gap = require(ReplicatedStorage.Gap)

local GapZones = {}

GapZones.TAG = "Gap"

local gaps: { [BasePart]: Gap.Gap } = {}

local function add(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local name = instance:GetAttribute("GapName")
	local inner = instance:GetAttribute("Inner")
	local outer = instance:GetAttribute("Outer")
	local minAngle = instance:GetAttribute("MinAngle")
	if
		typeof(name) ~= "string"
		or typeof(inner) ~= "number"
		or typeof(outer) ~= "number"
		or typeof(minAngle) ~= "number"
	then
		warn(`GapZones: {instance:GetFullName()} is missing GapName, Inner, Outer, or MinAngle`)
		return
	end
	local p = instance.Position
	gaps[instance] = { name = name, x = p.X, z = p.Z, inner = inner, outer = outer, minAngle = minAngle }
end

local function remove(instance: Instance)
	if instance:IsA("BasePart") then
		gaps[instance] = nil
	end
end

for _, instance in CollectionService:GetTagged(GapZones.TAG) do
	add(instance)
end
CollectionService:GetInstanceAddedSignal(GapZones.TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(GapZones.TAG):Connect(remove)

-- The names of every gap the finished run cleared.
function GapZones.find(run: Gap.Run): { string }
	local list: { Gap.Gap } = {}
	for _, gap in gaps do
		table.insert(list, gap)
	end
	return Gap.find(list, run)
end

return GapZones
