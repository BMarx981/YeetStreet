--!strict
-- Garage (ModuleScript) -> ServerScriptService.Garage
-- Cash, upgrades, and cars on the server. The rules are Economy's; this runs
-- them on PlayerData and tells everyone else.
--
-- Clients buy through RemoteFunctions in ReplicatedStorage, each returning
-- (ok, reason) with Economy's reasons, plus "TooSoon" and "NotLoaded". A
-- BuyBoneShop of the Dino Mystery Box returns the id of the car won in place
-- of the reason, for the client to spin to:
--   BuyUpgrade(stat)  one level of Speed, Jets, Toughness, Grip, or Brakes
--   BuyCar(id)        a ladder car, without equipping it; "Locked" if the
--                     player has fewer rebirths than it needs
--   EquipCar(id)      an owned car
--   BuyBody(id, seed)   a body for an owned car, without putting it on
--   WearBody(id, seed)  an owned body, and gets in that car
--   Rebirth()         resets the cash ladder (Rebirth) if the player owns the
--                     car it needs; reason "NeedsCar" if not
--   WearLimited(id)   takes an owned limited with a Look off, or puts it on
-- An upgrade or equip changes the car's stats, so the car respawns through
-- ServerStorage.ResetPlayerCar (ScoreService), the same as a reset. Wearing a
-- body respawns it too, to rebuild its looks, and a rebirth respawns the
-- player in the first ladder car.
--
-- The state shows on the Player as attributes for the garage UI: Cash, one
-- per stat level (Speed, Jets, Toughness, Grip, Brakes), Equipped, and CarsOwned (ids
-- joined by commas). Each car with bodies also gets BodiesOwned_<id> (seeds
-- joined by commas) and BodyWorn_<id>. Rebirths is the player's rebirth
-- count. Cash is also in leaderstats. LimitedsOwned and LimitedsWorn list
-- limited ids, and the player's car gets each worn limited's Look attribute
-- (dressCar).
--
-- The panel opens near any model tagged Garage. The hand-placed
-- workspace.Shopkeeper gets that tag here, so it stays a garage.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local DinoBox = require(ReplicatedStorage.DinoBox)
local Economy = require(ReplicatedStorage.Economy)
local Leaderboard = require(ReplicatedStorage.Leaderboard)
local Rebirth = require(ReplicatedStorage.Rebirth)
local Tuning = require(ReplicatedStorage.Tuning)
local Analytics = require(ServerScriptService.Analytics)
local Leaderstats = require(ServerScriptService.Leaderstats)
local PlayerData = require(ServerScriptService.PlayerData)
local TrailService = require(ServerScriptService.TrailService)

local Garage = {}

local lastRequestAt: { [Player]: number } = {}

-- Sets each limited Look's attribute on `car`: true while worn, nil
-- otherwise, for every client to draw (LimitedLooks).
function Garage.dressCar(car: Model, state: Economy.State)
	local worn = Economy.limitedLooks(state, Tuning.Limiteds)
	for _, item: Economy.Limited in Tuning.Limiteds do
		if item.Look then
			car:SetAttribute(item.Look, if table.find(worn, item.Look) then true else nil)
		end
	end
end

local function publish(player: Player, state: Economy.State)
	player:SetAttribute("Cash", state.Cash)
	player:SetAttribute("Speed", state.Levels.Speed)
	player:SetAttribute("Jets", state.Levels.Jets)
	player:SetAttribute("Toughness", state.Levels.Toughness)
	player:SetAttribute("Grip", state.Levels.Grip)
	player:SetAttribute("Brakes", state.Levels.Brakes)
	player:SetAttribute("Equipped", state.Equipped)
	player:SetAttribute("CarsOwned", table.concat(state.Cars, ","))
	player:SetAttribute("LimitedsOwned", table.concat(state.Limiteds, ","))
	player:SetAttribute("LimitedsWorn", table.concat(state.LimitedsWorn, ","))
	local cars = workspace:FindFirstChild("Cars")
	local driven = cars and cars:FindFirstChild(`Car_{player.Name}`)
	if driven and driven:IsA("Model") then
		Garage.dressCar(driven, state)
	end
	for _, car in Tuning.Ladder do
		if car.Bodies then
			player:SetAttribute(`BodiesOwned_{car.Id}`, table.concat(state.Bodies[car.Id] or {}, ","))
		end
		if car.Bodies or car.Look == nil then
			player:SetAttribute(`BodyWorn_{car.Id}`, Economy.wornSeed(state, car, Tuning.AnyBodies))
		end
	end
	player:SetAttribute("BodiesOwned_Any", table.concat(Economy.anyBodiesOwned(state), ","))
	player:SetAttribute("BoneCoins", state.BoneCoins)
	Leaderstats.value(player, "Cash").Value = state.Cash
	Leaderstats.value(player, "Bones").Value = state.Bones
	Leaderstats.value(player, "BoneCoins").Value = state.BoneCoins
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
	local seed = Economy.wornSeed(state, car, Tuning.AnyBodies)
	return Economy.withSeed(car, seed, Tuning.AnyBodies), stats, Economy.lookLevels(state.Levels, car)
end

-- Adds `amount` cash for `reason` (a source in Tuning.Analytics), if the
-- player's data is loaded.
function Garage.pay(player: Player, amount: number, reason: string)
	local data = PlayerData.get(player)
	if data and amount > 0 then
		data.Economy.Cash += amount
		publish(player, data.Economy)
		Analytics.gained(player, "Cash", reason, amount, data.Economy.Cash)
	end
end

-- Takes up to `amount` cash from the player, never below 0, and returns how
-- much it took. Only admins take cash, and admin cash is left out of the
-- economy events (Tuning.Analytics.Unlogged), so nothing is logged.
function Garage.take(player: Player, amount: number): number
	local data = PlayerData.get(player)
	if not data or amount <= 0 then
		return 0
	end
	local taken = math.min(amount, data.Economy.Cash)
	data.Economy.Cash -= taken
	publish(player, data.Economy)
	return taken
end

local function respawn(player: Player)
	(ServerStorage:FindFirstChild("ResetPlayerCar") :: BindableEvent):Fire(player)
end

-- Picking a car in the garage gets the player out of a car an admin toggle put
-- them in (:helicar, :planecar, :axolotl, :raptor, the Frog Car), which would otherwise replace
-- it at every respawn. Returns whether they were in one.
local function leaveAdminCar(player: Player): boolean
	local wasIn = false
	for _, attribute in { "HeliCarEquipped", "PlaneCarEquipped", "AxolotlEquipped", "VelociraptorEquipped", "FrogCarEquipped" } do
		if player:GetAttribute(attribute) == true then
			player:SetAttribute(attribute, false)
			wasIn = true
		end
	end
	return wasIn
end

-- Runs one purchase. `buy` returns the new state or why not, and `respawns`
-- says whether the car's stats changed. Cash it spends is logged as `sink`
-- `id` (Tuning.Analytics.Sinks).
local function request(
	player: Player,
	buy: (Economy.State) -> (Economy.State?, string?),
	respawns: boolean,
	sink: string,
	id: string
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
	local before = data.Economy
	local after, reason = buy(before)
	if not after then
		return false, reason
	end
	data.Economy = after
	publish(player, after)
	Analytics.spent(player, "Cash", sink, id, before.Cash - after.Cash, after.Cash)
	if respawns then
		respawn(player)
	end
	return true, nil
end

local function remote(name: string, handler: (Player, any, any) -> (boolean, string?))
	local fn = Instance.new("RemoteFunction")
	fn.Name = name
	fn.OnServerInvoke = handler
	fn.Parent = ReplicatedStorage
end

remote("BuyUpgrade", function(player: Player, stat: any): (boolean, string?)
	if stat ~= "Speed" and stat ~= "Jets" and stat ~= "Toughness" and stat ~= "Grip" and stat ~= "Brakes" then
		return false, "UnknownStat"
	end
	return request(player, function(state)
		local after, reason = Economy.upgrade(state, stat, Tuning.Ladder, Tuning.Upgrades)
		if after then
			local levels = state.Levels
			Analytics.upgraded(player, levels.Speed + levels.Jets + levels.Toughness + levels.Grip + levels.Brakes == 0)
		end
		return after, reason
	end, true, "Upgrade", stat)
end)

remote("BuyCar", function(player: Player, id: any): (boolean, string?)
	if typeof(id) ~= "string" then
		return false, "UnknownCar"
	end
	return request(player, function(state)
		local data = PlayerData.get(player)
		local after, reason = Economy.buyCar(state, id, Tuning.Ladder, if data then data.Rebirths else 0)
		if after then
			Analytics.gotCar(player, #state.Cars == 1)
		end
		return after, reason
	end, false, "Car", id)
end)

remote("EquipCar", function(player: Player, id: any): (boolean, string?)
	if typeof(id) ~= "string" or not Economy.findCar(Tuning.Ladder, id) then
		return false, "UnknownCar"
	end
	local data = PlayerData.get(player)
	if data and data.Economy.Equipped == id then
		if leaveAdminCar(player) then
			respawn(player)
		end
		return true, nil
	end
	return request(player, function(state)
		local after, reason = Economy.equip(state, id)
		if after then
			leaveAdminCar(player)
		end
		return after, reason
	end, true, "Car", id)
end)

remote("BuyBody", function(player: Player, id: any, seed: any): (boolean, string?)
	if typeof(id) ~= "string" or typeof(seed) ~= "number" then
		return false, "UnknownBody"
	end
	return request(player, function(state)
		return Economy.buyBody(state, id, seed, Tuning.Ladder)
	end, false, "Body", id)
end)

remote("WearBody", function(player: Player, id: any, seed: any): (boolean, string?)
	if typeof(id) ~= "string" or typeof(seed) ~= "number" then
		return false, "UnknownBody"
	end
	local car = Economy.findCar(Tuning.Ladder, id)
	local data = PlayerData.get(player)
	local worn = if car and data then Economy.wornSeed(data.Economy, car, Tuning.AnyBodies) else nil
	if data and data.Economy.Equipped == id and worn == seed then
		return true, nil
	end
	return request(player, function(state)
		local after, reason = Economy.wearBody(state, id, seed, Tuning.Ladder, Tuning.AnyBodies)
		if after then
			leaveAdminCar(player)
		end
		return after, reason
	end, true, "Body", id)
end)

local reborn = Instance.new("RemoteEvent")
reborn.Name = "Reborn"
reborn.Parent = ReplicatedStorage

-- The player's car in workspace.Cars (CarService names it), if there is one.
local function carOf(player: Player): Instance?
	local cars = workspace:FindFirstChild("Cars")
	return cars and cars:FindFirstChild(`Car_{player.Name}`)
end

-- Tells every client that `player` was reborn for the `count`th time, for the
-- banner and burst (RebirthFx), with their new car once the respawn has
-- replaced `old` (nil if that takes longer than CarWait).
local function announce(player: Player, count: number, old: Instance?)
	local deadline = os.clock() + Tuning.RebirthFx.CarWait
	local car = carOf(player)
	while (car == nil or car == old) and os.clock() < deadline do
		task.wait(0.1)
		car = carOf(player)
	end
	reborn:FireAllClients(player, count, if car ~= old then car else nil)
end

-- The new economy state and the added rebirth are set together, with nothing
-- between them that yields, so a save never holds one without the other.
-- Every client hears of it on ReplicatedStorage.Reborn (announce).
remote("Rebirth", function(player: Player): (boolean, string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "NotLoaded"
	end
	local count = data.Rebirths + 1
	local old = carOf(player)
	local ok, reason = request(player, function(state)
		local after, problem = Rebirth.rebirth(state, data.Rebirths, Tuning.Ladder, Tuning.Rebirth)
		if after then
			data.Rebirths = count
			TrailService.reborn(player)
			local week = Leaderboard.weekRecord(data.ThisWeek, Leaderboard.week(os.time()))
			data.ThisWeek = Leaderboard.recordRebirth(week)
			leaveAdminCar(player)
		end
		return after, problem
	end, true, "Rebirth", tostring(count))
	if ok then
		player:SetAttribute("Rebirths", count)
		Analytics.reborn(player, count)
		task.spawn(announce, player, count, old)
	end
	return ok, reason
end)

remote("WearLimited", function(player: Player, id: any): (boolean, string?)
	if typeof(id) ~= "string" then
		return false, "UnknownLimited"
	end
	return request(player, function(state)
		return Economy.wearLimited(state, id, Tuning.Limiteds)
	end, false, "Limited", id)
end)

remote("BuyBoneShop", function(player: Player, id: any): (boolean, string?)
	if typeof(id) ~= "string" then
		return false, "UnknownBoneShop"
	end
	local item
	for _, shopItem in Tuning.BoneShop do
		if shopItem.Id == id then
			item = shopItem
			break
		end
	end
	if not item then
		return false, "UnknownBoneShop"
	end
	local now = os.clock()
	if now - (lastRequestAt[player] or -math.huge) < Tuning.Garage.RequestGap then
		return false, "TooSoon"
	end
	lastRequestAt[player] = now
	local data = PlayerData.get(player)
	if not data then
		return false, "NotLoaded"
	end
	if item.Mystery and DinoBox.allOwned(Tuning.DinoMystery.Rewards, data.Economy.Cars) then
		return false, "AllOwned"
	end
	if item.CarId and table.find(data.Economy.Cars, item.CarId) then
		return false, "Owned"
	end
	local paid, problem = Economy.spendBones(data.Economy, item.BonePrice)
	if not paid then
		return false, problem
	end
	data.Economy = paid
	if item.Mystery then
		local won = DinoBox.pick(Tuning.DinoMystery.Rewards, data.Economy.Cars, math.random()) :: DinoBox.Reward
		table.insert(data.Economy.Cars, won.CarId)
		publish(player, data.Economy)
		Analytics.spent(player, "Bones", "BoneShop", item.Id, item.BonePrice, data.Economy.BoneCoins)
		Analytics.gotCar(player, #data.Economy.Cars == 2)
		return true, won.CarId
	end
	if item.CarId then
		table.insert(data.Economy.Cars, item.CarId)
	else
		data.Economy.Cash += item.CashReward
	end
	publish(player, data.Economy)
	Analytics.spent(player, "Bones", "BoneShop", item.Id, item.BonePrice, data.Economy.BoneCoins)
	if item.CarId then
		Analytics.gotCar(player, #data.Economy.Cars == 2)
	else
		Analytics.gained(player, "Cash", "BoneTrade", item.CashReward, data.Economy.Cash)
	end
	return true, nil
end)

-- Adds `bones` to the "Bones" count (shown on the HUD) and `coins` to the
-- "BoneCoins" currency (spent at the Bone Trader), saved with the player's
-- economy state. Bone rain pickups (DinoWeather) come through here. `reason`
-- is a source in Tuning.Analytics.
function Garage.addBones(player: Player, bones: number, coins: number, reason: string)
	local data = PlayerData.get(player)
	if not data or bones < 0 or coins <= 0 then
		return
	end
	data.Economy = Economy.addBones(data.Economy, bones, coins)
	publish(player, data.Economy)
	Analytics.gained(player, "Bones", reason, coins, data.Economy.BoneCoins)
end

-- Adds `amount` bones, the same as collecting that many from bone rain:
-- both the "Bones" counter and the "BoneCoins" currency go up. Used by admin
-- commands (e.g. :bones).
function Garage.giveBones(player: Player, amount: number, reason: string)
	if amount > 0 then
		Garage.addBones(player, amount, amount, reason)
	end
end

-- Grants the limited `id` without charge (Economy.giveLimited): admin
-- commands and Robux receipts (RobuxShop). One with a Look goes on, and one
-- with a Trail gives that prize trail and puts it on (TrailService).
function Garage.giveLimited(player: Player, id: string)
	local data = PlayerData.get(player)
	local item = Economy.findLimited(Tuning.Limiteds, id)
	if not (data and item) then
		return
	end
	local after = Economy.giveLimited(data.Economy, item)
	if after then
		data.Economy = after
		publish(player, after)
	end
	if item.Trail then
		TrailService.give(player, item.Trail)
	end
end

-- Grants a ladder car without charge, such as an invite prize
-- (InviteRewards). Adds it to the player's cars without equipping it.
function Garage.giveCar(player: Player, id: string)
	local data = PlayerData.get(player)
	if not data or not Economy.findCar(Tuning.Ladder, id) then
		return
	end
	if not table.find(data.Economy.Cars, id) then
		table.insert(data.Economy.Cars, id)
		publish(player, data.Economy)
		Analytics.gotCar(player, #data.Economy.Cars == 2)
	end
end

-- Gives the player the any-car body `seed` (Tuning.AnyBodies), saved. Does
-- nothing if they already have it.
function Garage.giveAnyBody(player: Player, seed: number)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local after = Economy.giveAnyBody(data.Economy, seed, Tuning.AnyBodies)
	if after then
		data.Economy = after
		publish(player, after)
	end
end

local function onPlayerAdded(player: Player)
	Leaderstats.value(player, "Cash")
	local data = PlayerData.waitFor(player)
	if data then
		if RunService:IsStudio() then
			data.Economy.Cash = math.max(data.Economy.Cash, Tuning.Cash.StudioCash)
		end
		publish(player, data.Economy)
		player:SetAttribute("Rebirths", data.Rebirths)
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
