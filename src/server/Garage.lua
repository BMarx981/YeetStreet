--!strict
-- Garage (ModuleScript) -> ServerScriptService.Garage
-- Cash, upgrades, and cars on the server. The rules are Economy's; this runs
-- them on PlayerData and tells everyone else.
--
-- Clients buy through RemoteFunctions in ReplicatedStorage, each returning
-- (ok, reason) with Economy's reasons, plus "TooSoon" and "NotLoaded":
--   BuyUpgrade(stat)  one level of Speed, Jets, Toughness, Grip, or Brakes
--   BuyCar(id)        a ladder car, without equipping it
--   EquipCar(id)      an owned car
--   BuyBody(id, seed)   a body for an owned car, without putting it on
--   WearBody(id, seed)  an owned body, and gets in that car
-- An upgrade or equip changes the car's stats, so the car respawns through
-- ServerStorage.ResetPlayerCar (ScoreService), the same as a reset. Wearing a
-- body respawns it too, to rebuild its looks.
--
-- The state shows on the Player as attributes for the garage UI: Cash, one
-- per stat level (Speed, Jets, Toughness, Grip, Brakes), Equipped, and CarsOwned (ids
-- joined by commas). Each car with bodies also gets BodiesOwned_<id> (seeds
-- joined by commas) and BodyWorn_<id>. Cash is also in leaderstats.
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

-- Remaining stock for limited items, shared across all players. Initialized from
-- Tuning.Limiteds on first use; decreases as players buy.
local limitedStock: { [string]: number } = {}
local function initLimitedStock()
	for _, item in Tuning.Limiteds do
		if limitedStock[item.Id] == nil then
			limitedStock[item.Id] = item.Stock
		end
	end
end
initLimitedStock()

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
	-- Publish remaining stock for each limited item so the UI can show it.
	for _, item in Tuning.Limiteds do
		player:SetAttribute(`LimitedStock_{item.Id}`, limitedStock[item.Id] or item.Stock)
	end
	for _, car in Tuning.Ladder do
		if car.Bodies then
			player:SetAttribute(`BodiesOwned_{car.Id}`, table.concat(state.Bodies[car.Id] or {}, ","))
			player:SetAttribute(`BodyWorn_{car.Id}`, Economy.wornSeed(state, car))
		end
	end
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
	return Economy.withSeed(car, Economy.wornSeed(state, car)), stats, Economy.lookLevels(state.Levels, car)
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

remote("BuyBody", function(player: Player, id: any, seed: any): (boolean, string?)
	if typeof(id) ~= "string" or typeof(seed) ~= "number" then
		return false, "UnknownBody"
	end
	return request(player, function(state)
		return Economy.buyBody(state, id, seed, Tuning.Ladder)
	end, false)
end)

remote("WearBody", function(player: Player, id: any, seed: any): (boolean, string?)
	if typeof(id) ~= "string" or typeof(seed) ~= "number" then
		return false, "UnknownBody"
	end
	local car = Economy.findCar(Tuning.Ladder, id)
	local data = PlayerData.get(player)
	if car and data and data.Economy.Equipped == id and Economy.wornSeed(data.Economy, car) == seed then
		return true, nil
	end
	return request(player, function(state)
		return Economy.wearBody(state, id, seed, Tuning.Ladder)
	end, true)
end)

remote("BuyLimited", function(player: Player, id: any): (boolean, string?)
	if typeof(id) ~= "string" then
		return false, "UnknownLimited"
	end
	return request(player, function(state)
		return Economy.buyLimited(state, id, Tuning.Limiteds, limitedStock)
	end, false)
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
	local boneCoins = Leaderstats.value(player, "BoneCoins")
	if not boneCoins or boneCoins.Value < item.BonePrice then
		return false, "NotEnoughBones"
	end
	boneCoins.Value -= item.BonePrice
	player:SetAttribute("BoneCoins", boneCoins.Value)
	if item.Mystery then
		-- Roll a weighted reward from the Dino Mystery table.
		local rewards = Tuning.DinoMystery.Rewards
		local totalWeight = 0
		for _, reward in rewards do
			totalWeight += reward.Weight
		end
		local roll = math.random() * totalWeight
		local picked
		for _, reward in rewards do
			roll -= reward.Weight
			if roll <= 0 then
				picked = reward
				break
			end
		end
		picked = picked or rewards[#rewards]
		if picked.Kind == "Car" then
			if table.find(data.Economy.Cars, picked.CarId) then
				-- Already owns that dino: reroll once, so a duplicate egg still pays out.
				local fallback = rewards[#rewards]
				for _, reward in rewards do
					if reward.Kind ~= "Car" then
						fallback = reward
						break
					end
				end
				local amount = fallback.Amount or 20000
				data.Economy.Cash += amount
				publish(player, data.Economy)
				return true, "You already had that dino, so the egg held $" .. amount .. " cash!"
			end
			table.insert(data.Economy.Cars, picked.CarId)
			publish(player, data.Economy)
			return true, "The egg hatched... " .. picked.Label
		elseif picked.Kind == "Bones" then
			boneCoins.Value += picked.Amount
			player:SetAttribute("BoneCoins", boneCoins.Value)
			return true, "The egg held " .. picked.Label .. "!"
		else
			data.Economy.Cash += picked.Amount
			publish(player, data.Economy)
			return true, "The egg held " .. picked.Label .. "!"
		end
	end
	if item.CarId then
		if table.find(data.Economy.Cars, item.CarId) then
			boneCoins.Value += item.BonePrice
			player:SetAttribute("BoneCoins", boneCoins.Value)
			return false, "Owned"
		end
		table.insert(data.Economy.Cars, item.CarId)
	else
		data.Economy.Cash += item.CashReward
	end
	publish(player, data.Economy)
	return true, nil
end)

-- Adds `amount` bones, the same as collecting that many from bone rain:
-- both the "Bones" counter (shown on the HUD) and the "BoneCoins" currency
-- (used in the bone shop) go up. Used by admin commands (e.g. :bones).
function Garage.giveBones(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local bones = Leaderstats.value(player, "Bones")
	bones.Value += amount
	local coins = Leaderstats.value(player, "BoneCoins")
	coins.Value += amount
	player:SetAttribute("BoneCoins", coins.Value)
end

-- Grants a limited item without charge. Used by admin commands (e.g. :frog)
-- to give admin-only limiteds like the Frog Car. Adds the id to the player's
-- saved Limiteds and publishes the update so the garage UI refreshes.
function Garage.giveLimited(player: Player, id: string)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	if not table.find(data.Economy.Limiteds, id) then
		table.insert(data.Economy.Limiteds, id)
		publish(player, data.Economy)
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
