--!strict
-- TutorialService (Script) -> ServerScriptService.TutorialService
-- Keeps whether each player has finished or skipped the tutorial (Tutorial)
-- in their saved data. Once their data loads it is put on the player as the
-- TutorialDone attribute, which their client's TutorialHints reads to start
-- it. The client fires ReplicatedStorage.TutorialEvent with "Step" and the
-- step's name as it reaches each step, "Done" when it is finished, and
-- "Skip" and the step's name when it is skipped. It holds no money or stats,
-- so the client's word is enough.
--
-- While a player's saved flag is still false, their steps go to the
-- Tutorial funnel (Tuning.Analytics.TutorialFunnel), one funnel session per
-- server visit, and a skip logs a TutorialSkip event. A replay from the
-- CONTROLS panel comes after the flag is set, so it logs nothing.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsEvents = require(ReplicatedStorage.AnalyticsEvents)
local Tuning = require(ReplicatedStorage.Tuning)
local Analytics = require(ServerScriptService.Analytics)
local PlayerData = require(ServerScriptService.PlayerData)

local A = Tuning.Analytics
local DONE = "Done"

type Funnel = { id: string, logged: number }

-- Each player's tutorial funnel session this visit.
local funnels: { [Player]: Funnel } = {}

-- Whether the player is on their first tutorial: data loaded, flag not set.
local function onFirstTutorial(player: Player): boolean
	local data = PlayerData.get(player)
	return data ~= nil and not data.TutorialDone
end

local function logStep(player: Player, name: string)
	local funnel = funnels[player]
	if not funnel then
		funnel = { id = HttpService:GenerateGUID(false), logged = 0 }
		funnels[player] = funnel
	end
	for _, step in AnalyticsEvents.tutorialSteps(funnel.logged, name, A.TutorialSteps) do
		Analytics.funnel(player, A.TutorialFunnel, funnel.id, step.Step, step.Name)
		funnel.logged = step.Step
	end
end

local function markDone(player: Player)
	PlayerData.update(player, function(changed)
		changed.TutorialDone = true
	end)
	player:SetAttribute("TutorialDone", true)
end

local function onPlayerAdded(player: Player)
	local data = PlayerData.waitFor(player)
	if data then
		player:SetAttribute("TutorialDone", data.TutorialDone)
	end
end

local event = ReplicatedStorage:WaitForChild("TutorialEvent")
if event:IsA("RemoteEvent") then
	event.OnServerEvent:Connect(function(player: Player, kind: any, name: any)
		if not onFirstTutorial(player) then
			return
		end
		if kind == "Step" and typeof(name) == "string" then
			logStep(player, name)
		elseif kind == DONE then
			logStep(player, DONE)
			markDone(player)
		elseif kind == "Skip" then
			local step = if typeof(name) == "string" and table.find(A.TutorialSteps, name) then name else "Unknown"
			Analytics.custom(player, A.Events.TutorialSkip, { step })
			markDone(player)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	funnels[player] = nil
end)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
