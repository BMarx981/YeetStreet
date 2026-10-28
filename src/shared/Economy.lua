--!strict
-- Economy (ModuleScript) -> ReplicatedStorage.Economy
-- Cash, upgrade levels, and the car ladder. Pure, see InputAxes. Values live in
-- Tuning.Cash, Tuning.Upgrades, and Tuning.Ladder.
--
-- Upgrade levels belong to the player, not to a car. The equipped car's caps
-- set how far each stat can be bought, and how many levels count toward its
-- real stats, so a better car raises the ceiling without losing progress.
-- Each car also adds free levels to every stat, so a new car drives better
-- from its first run.
-- Purchases return a new state and never change the one passed in.

local Economy = {}

export type StatName = "Speed" | "Jets" | "Toughness" | "Grip" | "Brakes"

export type Levels = {
	Speed: number,
	Jets: number,
	Toughness: number,
	Grip: number,
	Brakes: number,
}

export type Car = {
	Id: string,
	Name: string, -- shown to players
	Price: number,
	Caps: Levels,
	Bonus: number, -- free levels on every stat, on top of the levels bought
	-- Its looks, from the car generator (CarDesign, CarKit).
	Seed: number,
	Archetype: string,
	Tier: string,
	ForSale: boolean?, -- false for cars only won, never bought (dino cars, invite prize)
}

-- A limited edition item from Tuning.Limiteds.
export type Limited = {
	Id: string,
	Name: string, -- shown to players
	Price: number,
	Stock: number, -- how many exist in total; decreases as players buy
	Description: string,
	AdminOnly: boolean?, -- if true, only obtainable via admin command, never purchasable
}

-- What a player owns. This is the saved part of their data.
export type State = {
	Cash: number,
	Levels: Levels,
	Cars: { string }, -- ids of owned cars, in the order they were bought
	Equipped: string,
	Limiteds: { string }, -- ids of owned limited items
}

export type CostTuning = {
	CostBase: number, -- price of level 1
	CostGrowth: number, -- each level costs this times the last
	CostRound: number, -- prices round to the nearest multiple of this
}

-- Same fields as Tuning.StarterCar, declared here so this module needs no require.
export type CarStats = {
	TopSpeed: number,
	JetPower: number,
	JetFuel: number,
	FuelRecharge: number,
	TurnRate: number,
	Grip: number,
	RollUnlocked: boolean,
	Toughness: number,
	BrakePower: number,
}

-- How much each real stat rises per level of the upgrade that drives it.
export type Steps = {
	TopSpeed: number,
	JetPower: number,
	JetFuel: number,
	FuelRecharge: number,
	TurnRate: number,
	Toughness: number,
	Grip: number,
	BrakePower: number,
}

-- The level of one stat, by name.
function Economy.level(levels: Levels, stat: StatName): number
	if stat == "Speed" then
		return levels.Speed
	elseif stat == "Jets" then
		return levels.Jets
	elseif stat == "Toughness" then
		return levels.Toughness
	elseif stat == "Grip" then
		return levels.Grip
	else
		return levels.Brakes
	end
end

local function withLevel(levels: Levels, stat: StatName, value: number): Levels
	local copy = table.clone(levels)
	if stat == "Speed" then
		copy.Speed = value
	elseif stat == "Jets" then
		copy.Jets = value
	elseif stat == "Toughness" then
		copy.Toughness = value
	elseif stat == "Grip" then
		copy.Grip = value
	else
		copy.Brakes = value
	end
	return copy
end

function Economy.newState(ladder: { Car }): State
	local first = ladder[1].Id
	return {
		Cash = 0,
		Levels = { Speed = 0, Jets = 0, Toughness = 0, Grip = 0, Brakes = 0 },
		Cars = { first },
		Equipped = first,
		Limiteds = {},
	}
end

local function count(value: any): number
	if typeof(value) == "number" and value == value and value >= 0 and value < math.huge then
		return value
	end
	return 0
end

-- A valid state from whatever was saved. Missing or bad fields start fresh,
-- the first car is always owned, and cars no longer on the ladder are kept
-- but never equipped.
function Economy.reconcile(saved: any, ladder: { Car }): State
	local state = Economy.newState(ladder)
	if typeof(saved) ~= "table" then
		return state
	end
	state.Cash = count(saved.Cash)
	local levels = if typeof(saved.Levels) == "table" then saved.Levels else {}
	state.Levels = {
		Speed = math.floor(count(levels.Speed)),
		Jets = math.floor(count(levels.Jets)),
		Toughness = math.floor(count(levels.Toughness)),
		Grip = math.floor(count(levels.Grip)),
		Brakes = math.floor(count(levels.Brakes)),
	}
	if typeof(saved.Cars) == "table" then
		for _, id in saved.Cars do
			if typeof(id) == "string" and not table.find(state.Cars, id) then
				table.insert(state.Cars, id)
			end
		end
	end
	state.Limiteds = {}
	if typeof(saved.Limiteds) == "table" then
		for _, id in saved.Limiteds do
			if typeof(id) == "string" and not table.find(state.Limiteds, id) then
				table.insert(state.Limiteds, id)
			end
		end
	end
	local equipped = saved.Equipped
	if typeof(equipped) == "string" and table.find(state.Cars, equipped) and Economy.findCar(ladder, equipped) then
		state.Equipped = equipped
	end
	return state
end

function Economy.findLimited(limiteds: { Limited }, id: string): Limited?
	for _, item in limiteds do
		if item.Id == id then
			return item
		end
	end
	return nil
end

function Economy.findCar(ladder: { Car }, id: string): Car?
	for _, car in ladder do
		if car.Id == id then
			return car
		end
	end
	return nil
end

-- Cash paid for a run that scored `score`.
function Economy.payout(score: number, cashPerPoint: number): number
	return math.max(math.floor(score * cashPerPoint), 0)
end

-- Price of going from `from` to the next level.
function Economy.upgradeCost(from: number, tuning: CostTuning): number
	local raw = tuning.CostBase * tuning.CostGrowth ^ from
	return math.floor(raw / tuning.CostRound + 0.5) * tuning.CostRound
end

-- The levels that count on this car: each only up to the car's cap, plus the
-- car's free levels. They set its stats and which stat parts it shows.
function Economy.lookLevels(levels: Levels, car: Car): Levels
	return {
		Speed = math.min(levels.Speed, car.Caps.Speed) + car.Bonus,
		Jets = math.min(levels.Jets, car.Caps.Jets) + car.Bonus,
		Toughness = math.min(levels.Toughness, car.Caps.Toughness) + car.Bonus,
		Grip = math.min(levels.Grip, car.Caps.Grip) + car.Bonus,
		Brakes = math.min(levels.Brakes, car.Caps.Brakes) + car.Bonus,
	}
end

-- The car's real stats for these levels (see lookLevels).
function Economy.stats(base: CarStats, levels: Levels, car: Car, steps: Steps): CarStats
	local counted = Economy.lookLevels(levels, car)
	local speed = counted.Speed
	local jets = counted.Jets
	local toughness = counted.Toughness
	local grip = counted.Grip
	local brakes = counted.Brakes
	return {
		TopSpeed = base.TopSpeed + steps.TopSpeed * speed,
		JetPower = base.JetPower + steps.JetPower * jets,
		JetFuel = base.JetFuel + steps.JetFuel * jets,
		FuelRecharge = base.FuelRecharge + steps.FuelRecharge * jets,
		TurnRate = base.TurnRate + steps.TurnRate * jets,
		Grip = base.Grip + steps.Grip * grip,
		RollUnlocked = base.RollUnlocked,
		Toughness = base.Toughness + steps.Toughness * toughness,
		BrakePower = base.BrakePower + steps.BrakePower * brakes,
	}
end

-- Buys one level of `stat`. Fails with "UnknownCar", "AtCap", or "NotEnoughCash".
function Economy.upgrade(state: State, stat: StatName, ladder: { Car }, tuning: CostTuning): (State?, string?)
	local car = Economy.findCar(ladder, state.Equipped)
	if not car then
		return nil, "UnknownCar"
	end
	local current = Economy.level(state.Levels, stat)
	if current >= Economy.level(car.Caps, stat) then
		return nil, "AtCap"
	end
	local cost = Economy.upgradeCost(current, tuning)
	if state.Cash < cost then
		return nil, "NotEnoughCash"
	end
	local after = table.clone(state)
	after.Cash -= cost
	after.Levels = withLevel(state.Levels, stat, current + 1)
	return after, nil
end

-- Buys a car without equipping it. Fails with "UnknownCar", "Owned", "NotForSale",
-- or "NotEnoughCash".
function Economy.buyCar(state: State, id: string, ladder: { Car }): (State?, string?)
	local car = Economy.findCar(ladder, id)
	if not car then
		return nil, "UnknownCar"
	end
	if table.find(state.Cars, id) then
		return nil, "Owned"
	end
	if car.ForSale == false then
		return nil, "NotForSale"
	end
	if state.Cash < car.Price then
		return nil, "NotEnoughCash"
	end
	local after = table.clone(state)
	after.Cash -= car.Price
	after.Cars = table.clone(state.Cars)
	table.insert(after.Cars, id)
	return after, nil
end

-- Equips an owned car. Fails with "NotOwned".
function Economy.equip(state: State, id: string): (State?, string?)
	if not table.find(state.Cars, id) then
		return nil, "NotOwned"
	end
	local after = table.clone(state)
	after.Equipped = id
	return after, nil
end

-- Buys a limited edition item. Fails with "UnknownLimited", "Owned", "SoldOut",
-- or "NotEnoughCash".
function Economy.buyLimited(state: State, id: string, limiteds: { Limited }, stock: { [string]: number }): (State?, string?)
	local item = Economy.findLimited(limiteds, id)
	if not item then
		return nil, "UnknownLimited"
	end
	if item.AdminOnly then
		return nil, "UnknownLimited"
	end
	if table.find(state.Limiteds, id) then
		return nil, "Owned"
	end
	if (stock[id] or item.Stock) <= 0 then
		return nil, "SoldOut"
	end
	if state.Cash < item.Price then
		return nil, "NotEnoughCash"
	end
	local after = table.clone(state)
	after.Cash -= item.Price
	after.Limiteds = table.clone(state.Limiteds)
	table.insert(after.Limiteds, id)
	stock[id] = (stock[id] or item.Stock) - 1
	return after, nil
end

return Economy
