--!strict
-- PropSounds (LocalScript) -> StarterPlayerScripts.PropSounds
-- Plays the sound of props bursting, like the Scrapyard's junk pile, where
-- the car hit them: the server (PropService) fires ReplicatedStorage.PropBurst
-- with the name of one of Tuning.Props.BurstSounds and the place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)
local OneShot = require(script.Parent.OneShot)

local P = Tuning.Props

local remote = ReplicatedStorage:WaitForChild("PropBurst")
if not remote:IsA("RemoteEvent") then
	warn("PropSounds: ReplicatedStorage.PropBurst is not a RemoteEvent; props burst silently")
	return
end

remote.OnClientEvent:Connect(function(name: any, at: any)
	local spec = if typeof(name) == "string" then (P.BurstSounds :: any)[name] else nil
	if spec and typeof(at) == "Vector3" then
		OneShot.at(spec, at, P.BurstNear, P.BurstFar)
	end
end)
