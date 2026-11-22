--!strict
-- SiloBlast (LocalScript) -> StarterPlayerScripts.SiloBlast
-- Draws a silo missile's blast where the server says it hit, on
-- ReplicatedStorage.MissileBlast: the full-size mushroom cloud, with its
-- flash, shock ring, and shake (MushroomCloud), and a boom.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)
local MushroomCloud = require(script.Parent.MushroomCloud)
local OneShot = require(script.Parent.OneShot)

local B = Tuning.Silo.Blast
local CONFIG: MushroomCloud.Config = B :: any
local BOOM: OneShot.Spec = { Id = B.BoomId, Pitch = 1, Volume = B.BoomVolume }

local remote = ReplicatedStorage:WaitForChild("MissileBlast") :: RemoteEvent
remote.OnClientEvent:Connect(function(at: Vector3)
	MushroomCloud.play(CONFIG, at)
	OneShot.at(BOOM, at, B.BoomFullDistance, B.BoomReach)
end)
