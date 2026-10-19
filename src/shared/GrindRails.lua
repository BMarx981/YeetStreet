--!strict
-- GrindRails (ModuleScript) -> ReplicatedStorage.GrindRails
-- Every part tagged GrindRail, as a Grind.Rail from one end of the part to
-- the other along its X axis, which is a Roblox cylinder's length. Parks tag
-- their rails; CarSensor and GrindRide find them here. Rails never move, so
-- each is measured once when it appears.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Grind = require(ReplicatedStorage.Grind)
local Tuning = require(ReplicatedStorage.Tuning)

local GrindRails = {}

GrindRails.TAG = "GrindRail"

local rails: { [BasePart]: Grind.Rail } = {}

local function add(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local a = instance.CFrame * Vector3.new(-instance.Size.X / 2, 0, 0)
	local b = instance.CFrame * Vector3.new(instance.Size.X / 2, 0, 0)
	rails[instance] = { ax = a.X, ay = a.Y, az = a.Z, bx = b.X, by = b.Y, bz = b.Z }
end

local function remove(instance: Instance)
	if instance:IsA("BasePart") then
		rails[instance] = nil
	end
end

for _, instance in CollectionService:GetTagged(GrindRails.TAG) do
	add(instance)
end
CollectionService:GetInstanceAddedSignal(GrindRails.TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(GrindRails.TAG):Connect(remove)

-- Every rail, by its part.
function GrindRails.all(): { [BasePart]: Grind.Rail }
	return rails
end

-- Whether a hull here moving like this is on any rail.
function GrindRails.onAny(position: Vector3, velocity: Vector3): boolean
	local G = Tuning.Grind
	for _, rail in rails do
		if Grind.onRail(rail, position.X, position.Y, position.Z, velocity.X, velocity.Y, velocity.Z, G) then
			return true
		end
	end
	return false
end

return GrindRails
