--!strict
-- DailyRewards (ModuleScript) -> ServerScriptService.DailyRewards
-- The daily reward on the server. The rules are DailyReward's; this runs them.
--
-- Each player's calendar (PlayerData Daily) shows on them as the attributes
-- DailyLastDay, DailyStreak, DailyWeeks, and DailyDoubleLaunches, so their
-- client can work out what's claimable (DailyReward.status) from the
-- server's clock.
--
-- The client asks to claim on ReplicatedStorage.DailyClaimEvent. The server
-- checks the day by its own clock, pays the cash (Garage.pay, source Daily),
-- adds the double cash launches, and answers on the same event with the
-- reward (DailyReward.Reward). Week prizes are given as they're won, and
-- again on join for any earned before a prize existed (DailyBody, the gold
-- any-car body, Garage.giveAnyBody). Prizes not built yet are only counted.
--
-- ScoreService asks launchMultiplier for each run's payout. A double launch
-- is used only by a run that pays something.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DailyReward = require(ReplicatedStorage.DailyReward)
local Garage = require(ServerScriptService.Garage)
local PlayerData = require(ServerScriptService.PlayerData)
local Tuning = require(ReplicatedStorage.Tuning)

local T = Tuning.Daily

local DailyRewards = {}

local function today(): number
	return DailyReward.dayOf(os.time())
end

local function show(player: Player, state: DailyReward.State)
	player:SetAttribute("DailyLastDay", state.LastDay)
	player:SetAttribute("DailyStreak", state.Streak)
	player:SetAttribute("DailyWeeks", state.Weeks)
	player:SetAttribute("DailyDoubleLaunches", state.DoubleLaunches)
end

local function set(player: Player, state: DailyReward.State)
	PlayerData.update(player, function(data)
		data.Daily = state
	end)
	show(player, state)
end

-- The multiplier for a run that pays `payout` before it, using up one of
-- the player's double cash launches when it doubles.
function DailyRewards.launchMultiplier(player: Player, payout: number): number
	local data = PlayerData.get(player)
	if not data then
		return 1
	end
	local after, multiplier = DailyReward.useLaunch(data.Daily, T, payout)
	if after ~= data.Daily then
		set(player, after)
	end
	return multiplier
end

-- Opens the next day's claim now (DailyReward.skipDay). False if the
-- player's data hasn't loaded.
function DailyRewards.skipDay(player: Player): boolean
	local data = PlayerData.get(player)
	if not data then
		return false
	end
	set(player, DailyReward.skipDay(data.Daily))
	return true
end

-- Starts the player's calendar over, as if they never claimed. False if the
-- player's data hasn't loaded.
function DailyRewards.reset(player: Player): boolean
	if not PlayerData.get(player) then
		return false
	end
	set(player, DailyReward.newState())
	return true
end

-- Gives a week prize, if it's one that exists yet. Giving one twice does nothing.
local function givePrize(player: Player, prize: string)
	if prize == "DailyBody" then
		Garage.giveAnyBody(player, T.BodySeed)
	end
end

local event = ReplicatedStorage:WaitForChild("DailyClaimEvent") :: RemoteEvent

local function claim(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local after, reward = DailyReward.claim(data.Daily, today(), T)
	if not reward then
		return
	end
	set(player, after)
	Garage.pay(player, reward.Cash, "Daily")
	if reward.Prize then
		givePrize(player, reward.Prize)
	end
	event:FireClient(player, reward)
end

event.OnServerEvent:Connect(claim)

local function onPlayerAdded(player: Player)
	local data = PlayerData.waitFor(player)
	if data then
		show(player, data.Daily)
		for _, prize in DailyReward.prizesEarned(data.Daily, T) do
			givePrize(player, prize)
		end
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

return DailyRewards
