--!strict
-- TutorialService (Script) -> ServerScriptService.TutorialService
-- Keeps whether each player has finished or skipped the tutorial (Tutorial)
-- in their saved data. Once their data loads it is put on the player as the
-- TutorialDone attribute, which their client's TutorialHints reads to start
-- it. The client fires ReplicatedStorage.TutorialEvent when it is finished or
-- skipped. It holds no money or stats, so the client's word is enough.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService.PlayerData)

local function onPlayerAdded(player: Player)
	local data = PlayerData.waitFor(player)
	if data then
		player:SetAttribute("TutorialDone", data.TutorialDone)
	end
end

local event = ReplicatedStorage:WaitForChild("TutorialEvent")
if event:IsA("RemoteEvent") then
	event.OnServerEvent:Connect(function(player: Player)
		local data = PlayerData.get(player)
		if not data or data.TutorialDone then
			return
		end
		PlayerData.update(player, function(changed)
			changed.TutorialDone = true
		end)
		player:SetAttribute("TutorialDone", true)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
