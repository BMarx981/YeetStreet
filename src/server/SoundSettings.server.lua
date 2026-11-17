--!strict
-- SoundSettings (Script) -> ServerScriptService.SoundSettings
-- Keeps each player's engine sound setting (EngineSound.setting) in their
-- saved data. Once their data loads it is put on the player as the
-- EngineSound attribute, which their client's CarSounds reads. The CONTROLS
-- panel asks for a new one on ReplicatedStorage.EngineSoundEvent, and the
-- attribute changes once it is saved.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EngineSound = require(ReplicatedStorage.EngineSound)
local Tuning = require(ReplicatedStorage.Tuning)
local PlayerData = require(ServerScriptService.PlayerData)

local SETTINGS = Tuning.EngineSound.Settings

local function onPlayerAdded(player: Player)
	local data = PlayerData.waitFor(player)
	if data then
		player:SetAttribute("EngineSound", data.EngineSound)
	end
end

local event = ReplicatedStorage:WaitForChild("EngineSoundEvent")
if event:IsA("RemoteEvent") then
	event.OnServerEvent:Connect(function(player: Player, name: any)
		if typeof(name) ~= "string" or EngineSound.setting(name, SETTINGS) ~= name then
			return
		end
		if not PlayerData.get(player) then
			return
		end
		PlayerData.update(player, function(data)
			data.EngineSound = name
		end)
		player:SetAttribute("EngineSound", name)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
