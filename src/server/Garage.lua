--!strict
-- Garage (ModuleScript) -> ServerScriptService.Garage
-- Cash, upgrades, and cars on the server. The rules are Economy's; this runs
-- them on PlayerData and tells everyone else.
--
-- Clients buy through RemoteFunctions in ReplicatedStorage, each returning
-- (ok, reason) with Economy's reasons, plus "TooSoon" and "NotLoaded":
--   BuyUpgrade(stat)  one level of Speed, Jets, Toughness, or Grip
--   BuyCar(id)        a ladder car, without equipping it
--   EquipCar(id)      an owned car
-- An upgrade or equip changes the car's stats, so the car respawns through
-- ServerStorage.ResetPlayerCar (ScoreService), the same as a reset.
--
-- The state shows on the Player as attributes for the garage UI: Cash, one
-- per stat level (Speed, Jets, Toughness, Grip), Equipped, and CarsOwned (ids
-- joined by commas). Cash is also in leaderstats.
--
-- The panel opens near any model tagged Garage. The hand-placed
-- workspace.Shopkeeper gets that tag here, so it stays a garage.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Economy = require(ReplicatedStorage.Economy)
local Tuning = require(ReplicatedStorage.Tuning)
local Leaderstats = require(ServerScriptService.Leaderstats)
local PlayerData = require(ServerScriptService.PlayerData)

local Garage = {}

local lastRequestAt: { [Player]: number } = {}

local function publish(player: Player, state: Economy.State)
	player:SetAttribute("Cash", state.Cash)
	player:SetAttribute("Speed", state.Levels.Speed)
	player:SetAttribute("Jets", state.Levels.Jets)
	player:SetAttribute("Toughness", state.Levels.Toughness)
	player:SetAttribute("Grip", state.Levels.Grip)
	player:SetAttribute("Equipped", state.Equipped)
	player:SetAttribute("CarsOwned", table.concat(state.Cars, ","))
	Leaderstats.value(player, "Cash").Value = state.Cash
end

-- The equipped ladder car, its stats from the player's levels, and the levels
-- it shows. Waits for their data; nil if they leave first.
function Garage.car(player: Player): (Economy.Car?, Economy.CarStats?, Economy.Levels?)
	local data = PlayerData.waitFor(player)
	if not data then
		return nil, nil, nil
	end
	local state = data.Economy
	local car = Economy.findCar(Tuning.Ladder, state.Equipped) or Tuning.Ladder[1]
	local stats = Economy.stats(Tuning.StarterCar, state.Levels, car, Tuning.Upgrades.Steps)
	return car, stats, Economy.lookLevels(state.Levels, car)
end

-- Adds `amount` cash, if the player's data is loaded.
function Garage.pay(player: Player, amount: number)
	local data = PlayerData.get(player)
	if data and amount > 0 then
		data.Economy.Cash += amount
		publish(player, data.Economy)
	end
end

-- Runs one purchase. `buy` returns the new state or why not, and `respawns`
-- says whether the car's stats changed.
local function request(
	player: Player,
	buy: (Economy.State) -> (Economy.State?, string?),
	respawns: boolean
): (boolean, string?)
	local now = os.clock()
	if now - (lastRequestAt[player] or -math.huge) < Tuning.Garage.RequestGap then
		return false, "TooSoon"
	end
	lastRequestAt[player] = now
	local data = PlayerData.get(player)
	if not data then
		return false, "NotLoaded"
	end
	local after, reason = buy(data.Economy)
	if not after then
		return false, reason
	end
	data.Economy = after
	publish(player, after)
	if respawns then
		(ServerStorage:FindFirstChild("ResetPlayerCar") :: BindableEvent):Fire(player)
	end
	return true, nil
end

local function remote(name: string, handler: (Player, any) -> (boolean, string?))
	local fn = Instance.new("RemoteFunction")
	fn.Name = name
	fn.OnServerInvoke = handler
	fn.Parent = ReplicatedStorage
end

remote("BuyUpgrade", function(player: Player, stat: any): (boolean, string?)
	if stat ~= "Speed" and stat ~= "Jets" and stat ~= "Toughness" and stat ~= "Grip" then
		return false, "UnknownStat"
	end
	return request(player, function(state)
		return Economy.upgrade(state, stat, Tuning.Ladder, Tuning.Upgrades)
	end, true)
end)

remote("BuyCar", function(player: Player, id: any): (boolean, string?)
	if typeof(id) ~= "string" then
		return false, "UnknownCar"
	end
	return request(player, function(state)
		return Economy.buyCar(state, id, Tuning.Ladder)
	end, false)
end)

remote("EquipCar", function(player: Player, id: any): (boolean, string?)
	if typeof(id) ~= "string" or not Economy.findCar(Tuning.Ladder, id) then
		return false, "UnknownCar"
	end
	local data = PlayerData.get(player)
	if data and data.Economy.Equipped == id then
		return true, nil
	end
	return request(player, function(state)
		return Economy.equip(state, id)
	end, true)
end)

local function onPlayerAdded(player: Player)
	Leaderstats.value(player, "Cash")
	local data = PlayerData.waitFor(player)
	if data then
		if RunService:IsStudio() then
			data.Economy.Cash = math.max(data.Economy.Cash, Tuning.Cash.StudioCash)
		end
		publish(player, data.Economy)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerRemoving:Connect(function(player: Player)
	lastRequestAt[player] = nil
end)

local shopkeeper = workspace:FindFirstChild("Shopkeeper")
if shopkeeper then
	CollectionService:AddTag(shopkeeper, "Garage")
end

return Garage
