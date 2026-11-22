--!strict
-- MagnetCraneWorld (ModuleScript) -> ReplicatedStorage.MagnetCraneWorld
-- The Scrapyard's magnet crane in the world: where its tower and pad are,
-- and MagnetCrane's angles and heights as world places. Nothing is sent
-- while it moves: the server (Parks.ScrapyardCrane) and every client
-- (CraneLook) place the magnet from the server's clock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MagnetCrane = require(ReplicatedStorage.MagnetCrane)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)

local K = Tuning.Scrapyard.Crane
local CONFIG: MagnetCrane.Config = K :: any

local MagnetCraneWorld = {}

local area = MapLayout.find(Tuning.Map.Areas :: any, "Scrapyard")

-- The tower's middle on the floor.
MagnetCraneWorld.tower = if area then Vector3.new(area.X + K.X, Tuning.Map.FloorTop, area.Z + K.Z) else Vector3.zero

-- The middle of the magnet's underside with the boom at `angle` and the
-- magnet `height` above the floor, facing out along the boom.
function MagnetCraneWorld.at(angle: number, height: number): CFrame
	local x, z = MagnetCrane.spot(CONFIG, angle)
	local p = MagnetCraneWorld.tower + Vector3.new(x, height, z)
	return CFrame.lookAt(p, p + Vector3.new(x, 0, z))
end

-- The magnet `elapsed` seconds into a cycle.
function MagnetCraneWorld.magnet(elapsed: number): CFrame
	return MagnetCraneWorld.at(MagnetCrane.pose(CONFIG, elapsed))
end

-- The pad's middle on the floor, facing out along the boom.
MagnetCraneWorld.pad = MagnetCraneWorld.at(K.PadAngle, 0)

return MagnetCraneWorld
