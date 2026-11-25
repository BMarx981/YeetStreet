--!strict
-- CloseCall (ModuleScript) -> StarterPlayerScripts.CloseCall
-- The "So close!" line for a run's card (SoClose), from what this client
-- can see: the Best in leaderstats, the record launcher's records in
-- ReplicatedStorage.LaunchRecordData, and the cheapest upgrade the equipped
-- car can still take, from the player's level attributes. The server sends
-- the rest with the run (Bonus.Extras).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bonus = require(ReplicatedStorage.Bonus)
local Economy = require(ReplicatedStorage.Economy)
local LaunchRecords = require(ReplicatedStorage.LaunchRecords)
local Scoring = require(ReplicatedStorage.Scoring)
local SoClose = require(ReplicatedStorage.SoClose)
local Tuning = require(ReplicatedStorage.Tuning)

local STATS: { Economy.StatName } = { "Speed", "Jets", "Toughness", "Grip", "Brakes" }

local player = Players.LocalPlayer :: Player

local CloseCall = {}

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function best(): number
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Best")
	return if value and value:IsA("IntValue") then value.Value else 0
end

-- This week's and the all-time record distance, whole studs, if it has them.
local function records(launcher: string?): (number?, number?)
	local folder = ReplicatedStorage:FindFirstChild("LaunchRecordData")
	local source = if launcher and folder then folder:FindFirstChild(launcher) else nil
	if not (source and source:IsA("StringValue")) then
		return nil, nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, source.Value)
	if not ok or typeof(decoded) ~= "table" then
		return nil, nil
	end
	local week = LaunchRecords.reconcile(decoded.ThisWeek)
	local allTime = LaunchRecords.reconcile(decoded.AllTime)
	return if week then week.Value else nil, if allTime then allTime.Value else nil
end

-- The cheapest next level the equipped car still has room for, as the
-- garage prices it, and its name like "Jets 6".
local function cheapestUpgrade(): (number?, string?)
	local equipped = player:GetAttribute("Equipped")
	local car = (if typeof(equipped) == "string" then Economy.findCar(Tuning.Ladder, equipped) else nil)
		or Tuning.Ladder[1]
	local cost: number?, name: string? = nil, nil
	for _, stat in STATS do
		local level = number(stat)
		if level < Economy.level(car.Caps, stat) then
			local price = Economy.upgradeCost(level, Tuning.Upgrades)
			if not cost or price < cost then
				cost, name = price, `{stat} {level + 1}`
			end
		end
	end
	return cost, name
end

function CloseCall.line(run: Scoring.Run, score: Scoring.Score, extras: Bonus.Extras): string?
	local S = Tuning.Score
	local week, allTime = records(extras.launcher)
	local cost, name = cheapestUpgrade()
	return SoClose.pick({
		total = score.total,
		best = best(),
		landed = run.ending == "landed",
		tricks = #run.tricks,
		nextCombo = if score.combo < S.ComboMax then math.min(score.combo + S.ComboStep, S.ComboMax) else nil,
		distance = run.distance,
		weekRecord = week,
		allTimeRecord = allTime,
		cash = extras.cash,
		paid = extras.paid,
		upgradeCost = cost,
		upgradeName = name,
	}, Tuning.SoClose)
end

return CloseCall
