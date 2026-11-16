--!strict
-- ObbySounds (LocalScript) -> StarterPlayerScripts.ObbySounds
-- A short chime when the server pays a new obby pad (ReplicatedStorage
-- .ObbyReward, from ObbyService), and the bigger fanfare instead on the finish
-- pad. Only the player who reached the pad hears them (Tuning.ObbySounds).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Obby = require(ReplicatedStorage.Obby)
local Tuning = require(ReplicatedStorage.Tuning)

-- Made up front so they have loaded by the first pad.
local function sound(name: string, spec: { Id: string, Pitch: number, Volume: number }): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = spec.Id
	s.PlaybackSpeed = spec.Pitch
	s.Volume = spec.Volume
	s.Parent = SoundService
	return s
end

local chime = sound("ObbyPad", Tuning.ObbySounds.Pad)
local fanfare = sound("ObbyFinish", Tuning.ObbySounds.Finish)

local reward = ReplicatedStorage:WaitForChild("ObbyReward")
if reward:IsA("RemoteEvent") then
	reward.OnClientEvent:Connect(function(info: any)
		local stage = if typeof(info) == "table" then info.Stage else nil
		if typeof(stage) ~= "number" then
			return
		end
		local s = if Obby.isFinish(stage, Tuning.Obby) then fanfare else chime
		s.TimePosition = 0
		s:Play()
	end)
else
	warn("ObbySounds: ReplicatedStorage.ObbyReward is not a RemoteEvent; obby pads stay silent")
end
