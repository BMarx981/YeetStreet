--!strict
-- Leaderboards (Script) -> ServerScriptService.Leaderboards
-- Sends each player's bests to the global leaderboards (Leaderboard). Every
-- SendEvery seconds, each of their lists that beats what this session last
-- sent goes to its ordered store through PlayerData.raiseBoard. A session
-- starts with nothing sent, so the first send after joining puts all of a
-- player's bests up, including ones from before the boards existed. A best
-- set less than SendEvery before leaving goes up on the next join. Studio
-- sends to its own lists.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Leaderboard = require(ReplicatedStorage.Leaderboard)
local Tuning = require(ReplicatedStorage.Tuning)
local PlayerData = require(ServerScriptService.PlayerData)

local B = Tuning.Leaderboards
local studio = RunService:IsStudio()

-- By player, what this session has sent to each list.
local sent: { [Player]: { [string]: number } } = {}

local function send(player: Player)
	local data = PlayerData.get(player)
	local mine = sent[player]
	if not (data and mine) then
		return
	end
	local week = Leaderboard.weekRecord(data.ThisWeek, Leaderboard.week(os.time()))
	local lists = Leaderboard.lists(data.Best, data.BestAirtime, data.Rebirths, week, studio, B)
	for name, value in Leaderboard.changed(lists, mine) do
		if PlayerData.raiseBoard(name, player.UserId, value) then
			mine[name] = value
		end
	end
end

Players.PlayerAdded:Connect(function(player: Player)
	sent[player] = {}
end)
for _, player in Players:GetPlayers() do
	sent[player] = {}
end
Players.PlayerRemoving:Connect(function(player: Player)
	sent[player] = nil
end)

while true do
	task.wait(B.SendEvery)
	for player in sent do
		task.spawn(send, player)
	end
end
