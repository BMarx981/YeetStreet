--!strict
-- Economy (ModuleScript) -> ReplicatedStorage.Economy
-- Cash, upgrade levels, and the car ladder. Pure, see InputAxes. Values live in
-- Tuning.Cash, Tuning.Upgrades, and Tuning.Ladder.
--
-- Upgrade levels belong to the player, not to a car. The equipped car's caps
-- set how far each stat can be bought, and how many levels count toward its
-- real stats, so a better car raises the ceiling without losing progress.
-- Purchases return a new state and never change the one passed in.

local Economy = {}

export type StatName = "Speed" | "Jets" | "Toughness" | "Grip"

export type Levels = {
	Speed: number,
	Jets: number,
	Toughness: number,
	Grip: number,
}

export type Car = {
	Id: string,
	Price: number,
	Caps: Levels,
}

-- What a player owns. This is the saved part of their data.
export type State = {
	Cash: number,
	Levels: Levels,
	Cars: { string }, -- ids of owned cars, in the order they were bought
	Equipped: string,
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
}

local function level(levels: Levels, stat: StatName): number
	if stat == "Speed" then
		return levels.Speed
	elseif stat == "Jets" then
		return levels.Jets
	elseif stat == "Toughness" then
		return levels.Toughness
	else
		return levels.Grip
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
	else
		copy.Grip = value
	end
	return copy
end

function Economy.newState(ladder: { Car }): State
	local first = ladder[1].Id
	return {
		Cash = 0,
		Levels = { Speed = 0, Jets = 0, Toughness = 0, Grip = 0 },
		Cars = { first },
		Equipped = first,
	}
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

-- The car's real stats for these levels, each counted only up to the car's cap.
function Economy.stats(base: CarStats, levels: Levels, caps: Levels, steps: Steps): CarStats
	local speed = math.min(levels.Speed, caps.Speed)
	local jets = math.min(levels.Jets, caps.Jets)
	local toughness = math.min(levels.Toughness, caps.Toughness)
	local grip = math.min(levels.Grip, caps.Grip)
	return {
		TopSpeed = base.TopSpeed + steps.TopSpeed * speed,
		JetPower = base.JetPower + steps.JetPower * jets,
		JetFuel = base.JetFuel + steps.JetFuel * jets,
		FuelRecharge = base.FuelRecharge + steps.FuelRecharge * jets,
		TurnRate = base.TurnRate + steps.TurnRate * jets,
		Grip = base.Grip + steps.Grip * grip,
		RollUnlocked = base.RollUnlocked,
		Toughness = base.Toughness + steps.Toughness * toughness,
	}
end

-- Buys one level of `stat`. Fails with "UnknownCar", "AtCap", or "NotEnoughCash".
function Economy.upgrade(state: State, stat: StatName, ladder: { Car }, tuning: CostTuning): (State?, string?)
	local car = Economy.findCar(ladder, state.Equipped)
	if not car then
		return nil, "UnknownCar"
	end
	local current = level(state.Levels, stat)
	if current >= level(car.Caps, stat) then
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

-- Buys a car without equipping it. Fails with "UnknownCar", "Owned", or "NotEnoughCash".
function Economy.buyCar(state: State, id: string, ladder: { Car }): (State?, string?)
	local car = Economy.findCar(ladder, id)
	if not car then
		return nil, "UnknownCar"
	end
	if table.find(state.Cars, id) then
		return nil, "Owned"
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

return Economy
