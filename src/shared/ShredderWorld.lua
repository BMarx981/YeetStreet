--!strict
-- ShredderWorld (ModuleScript) -> ReplicatedStorage.ShredderWorld
-- The Scrapyard's shredder in the world (Tuning.Scrapyard.Shredder): where
-- its hopper stands, and places along its lane. Shared by the server
-- (Parks.ScrapyardShredder), which builds it and catches cars, and every
-- client (ShredderLook, ShredderCamera), which draws and spins the rollers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)

local S = Tuning.Scrapyard.Shredder

local ShredderWorld = {}

local area = MapLayout.find(Tuning.Map.Areas :: any, "Scrapyard")

-- The middle of the hopper's floor, facing the way cars fly in. Its
-- Length runs along the LookVector, its Width along the RightVector.
ShredderWorld.frame = if area
	then CFrame.new(area.X + S.X, Tuning.Map.FloorTop, area.Z + S.Z) * CFrame.Angles(0, math.rad(S.Turn), 0)
	else CFrame.identity

-- A place on the floor `back` studs back along the kicker's line from the
-- opening's middle, facing the way cars drive along it.
function ShredderWorld.line(back: number): CFrame
	return ShredderWorld.frame * CFrame.new(0, 0, back)
end

-- A hull's middle in the hopper's terms (Shredder.inside): along its
-- Length, up from the floor, and across its Width.
function ShredderWorld.toHopper(position: Vector3): (number, number, number)
	local p = ShredderWorld.frame:PointToObjectSpace(position)
	return p.Z, p.Y, p.X
end

return ShredderWorld
