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
	Rebirths: number?, -- rebirths a player needs before they can buy it (the rebirth cars)
	Look: string?, -- a fixed look in place of the generated one ("Axolotl", or one of DinoCars.Looks)
	-- Other bodies it can wear for a new shape, on top of its own Seed, which
	-- comes free with the car. Any car type of the same Tier, with the same
	-- stats. Seeds are what get saved, so each is used once per car.
	Bodies: { Body }?,
	BodyPrice: number?,
	Paint: { number }?, -- the worn body's paint, set by withSeed
}

export type Body = {
	Seed: number,
	Archetype: string,
	Paint: { number }?, -- paints the whole body this color (CarDesign)
}

-- When a limited is sold, as "YYYY-MM-DD" UTC dates. On sale from midnight
-- at the start of Starts until midnight at the start of Ends.
export type Sale = {
	Starts: string,
	Ends: string,
}

-- A limited edition item from Tuning.Limiteds. Admins can give any of them;
-- players buy one with Robux only while its Sale window is open.
export type Limited = {
	Id: string,
	Name: string, -- shown to players
	Description: string,
	Sale: Sale?, -- none means never on sale, admin only
	ProductId: number?, -- the Robux developer product that sells it
}

-- What a player owns. This is the saved part of their data.
export type State = {
	Cash: number,
	Levels: Levels,
	Cars: { string }, -- ids of owned cars, in the order they were bought
	Equipped: string,
	Limiteds: { string }, -- ids of owned limited items
	Bodies: { [string]: { number } }, -- by car id, the seeds bought for that car
	Worn: { [string]: number }, -- by car id, the seed it wears; none means its own
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
		Bodies = {},
		Worn = {},
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
	if typeof(saved.Bodies) == "table" then
		for id, seeds in saved.Bodies do
			if typeof(id) == "string" and typeof(seeds) == "table" then
				local kept = {}
				for _, seed in seeds do
					if typeof(seed) == "number" and not table.find(kept, seed) then
						table.insert(kept, seed)
					end
				end
				state.Bodies[id] = kept
			end
		end
	end
	if typeof(saved.Worn) == "table" then
		for id, seed in saved.Worn do
			if typeof(id) == "string" and typeof(seed) == "number" then
				state.Worn[id] = seed
			end
		end
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

-- Unix time of midnight UTC at the start of a "YYYY-MM-DD" date, or nil if
-- it isn't a real date. Days from 1970 by Howard Hinnant's days_from_civil.
local function utcMidnight(date: string): number?
	local y, m, d = string.match(date, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	if not y then
		return nil
	end
	local year, month, day = tonumber(y) :: number, tonumber(m) :: number, tonumber(d) :: number
	local leap = year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
	local lengths = { 31, if leap then 29 else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	if month < 1 or month > 12 or day < 1 or day > lengths[month] then
		return nil
	end
	local shifted = if month <= 2 then year - 1 else year
	local era = math.floor(shifted / 400)
	local yearOfEra = shifted - era * 400
	local dayOfYear = math.floor((153 * (if month > 2 then month - 3 else month + 9) + 2) / 5) + day - 1
	local dayOfEra = yearOfEra * 365 + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100) + dayOfYear
	return (era * 146097 + dayOfEra - 719468) * 86400
end

-- Whether players can buy `item` at unix time `now`.
function Economy.onSale(item: Limited, now: number): boolean
	local sale = item.Sale
	if not sale then
		return false
	end
	local starts, ends = utcMidnight(sale.Starts), utcMidnight(sale.Ends)
	return starts ~= nil and ends ~= nil and now >= starts and now < ends
end

-- Seconds from unix time `now` until `item`'s sale window closes; nil when
-- it isn't on sale.
function Economy.saleLeft(item: Limited, now: number): number?
	local sale = item.Sale
	if not sale or not Economy.onSale(item, now) then
		return nil
	end
	return (utcMidnight(sale.Ends) :: number) - now
end

-- `seconds` left as its two biggest units, such as "3d 4h", "5h 12m", or
-- "12m 5s".
function Economy.leavesIn(seconds: number): string
	local whole = math.max(math.floor(seconds), 0)
	if whole >= 86400 then
		return `{whole // 86400}d {whole // 3600 % 24}h`
	elseif whole >= 3600 then
		return `{whole // 3600}h {whole // 60 % 60}m`
	end
	return `{whole // 60}m {whole % 60}s`
end

-- The limited that the Robux developer product `productId` sells.
function Economy.findLimitedByProduct(limiteds: { Limited }, productId: number): Limited?
	for _, item in limiteds do
		if item.ProductId == productId then
			return item
		end
	end
	return nil
end

-- Why `state` can't be offered `item` for Robux at unix time `now`:
-- "OffSale" off its window or before it has a product, or "Owned". Nil
-- if it can.
function Economy.robuxProblem(state: State, item: Limited, now: number): string?
	if not item.ProductId or not Economy.onSale(item, now) then
		return "OffSale"
	end
	if table.find(state.Limiteds, item.Id) then
		return "Owned"
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

-- A typed word as admin commands match it: lowercase, no spaces or dashes.
local function squash(text: string): string
	return (string.gsub(string.lower(text), "[%s%-]", ""))
end

-- The cars a typed word names, for admin commands: a car's Id or Name in any
-- case, with spaces and dashes ignored ("t-rex", "muscle car"), or every Tier
-- "Dino" car for "dinos". Empty if nothing matches.
function Economy.matchCars(ladder: { Car }, word: string): { Car }
	local wanted = squash(word)
	local found: { Car } = {}
	if wanted == "" then
		return found
	end
	for _, car in ladder do
		if (wanted == "dinos" and car.Tier == "Dino") or squash(car.Id) == wanted or squash(car.Name) == wanted then
			table.insert(found, car)
		end
	end
	return found
end

-- The limiteds a typed word names, for admin commands: an Id or Name matched
-- like matchCars, or every limited for "all". Empty if nothing matches.
function Economy.matchLimiteds(limiteds: { Limited }, word: string): { Limited }
	local wanted = squash(word)
	local found: { Limited } = {}
	if wanted == "" then
		return found
	end
	for _, item in limiteds do
		if wanted == "all" or squash(item.Id) == wanted or squash(item.Name) == wanted then
			table.insert(found, item)
		end
	end
	return found
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

-- Buys a car without equipping it, for a player with `rebirths` (none if not
-- given). Fails with "UnknownCar", "Owned", "NotForSale", "Locked" (it needs
-- more rebirths), or "NotEnoughCash".
function Economy.buyCar(state: State, id: string, ladder: { Car }, rebirths: number?): (State?, string?)
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
	if (rebirths or 0) < (car.Rebirths or 0) then
		return nil, "Locked"
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

-- Where a player's any-car bodies are kept in State.Bodies. Any-car bodies
-- are given, never bought, and every car with a generated look (no Look) can
-- wear them. Functions that take `anyBodies` (Tuning.AnyBodies) know them.
local ANY = "Any"

local function inList(bodies: { Body }?, seed: number): Body?
	if bodies then
		for _, body in bodies do
			if body.Seed == seed then
				return body
			end
		end
	end
	return nil
end

local function findBody(car: Car, seed: number, anyBodies: { Body }?): Body?
	return inList(car.Bodies, seed) or if car.Look == nil then inList(anyBodies, seed) else nil
end

local function onBodyList(car: Car, seed: number, anyBodies: { Body }?): boolean
	return findBody(car, seed, anyBodies) ~= nil
end

local function ownsBody(state: State, car: Car, seed: number, anyBodies: { Body }?): boolean
	if seed == car.Seed then
		return true
	end
	local bought = state.Bodies[car.Id]
	if bought ~= nil and table.find(bought, seed) ~= nil then
		return true
	end
	local given = state.Bodies[ANY]
	return car.Look == nil and inList(anyBodies, seed) ~= nil and given ~= nil and table.find(given, seed) ~= nil
end

-- The seed this car wears: its own, unless the player owns another on its
-- list or an any-car body.
function Economy.wornSeed(state: State, car: Car, anyBodies: { Body }?): number
	local worn = state.Worn[car.Id]
	if worn and onBodyList(car, worn, anyBodies) and ownsBody(state, car, worn, anyBodies) then
		return worn
	end
	return car.Seed
end

-- The same car with another seed's looks, in that body's car type and paint
-- if it's on the list or an any-car body. Nothing else about it changes.
function Economy.withSeed(car: Car, seed: number, anyBodies: { Body }?): Car
	local dressed = table.clone(car)
	dressed.Seed = seed
	local body = findBody(car, seed, anyBodies)
	if body then
		dressed.Archetype = body.Archetype
		dressed.Paint = body.Paint
	end
	return dressed
end

-- Gives the any-car body `seed`. Fails with "UnknownBody" or "Owned".
function Economy.giveAnyBody(state: State, seed: number, anyBodies: { Body }): (State?, string?)
	if not inList(anyBodies, seed) then
		return nil, "UnknownBody"
	end
	local given = state.Bodies[ANY] or {}
	if table.find(given, seed) then
		return nil, "Owned"
	end
	local after = table.clone(state)
	after.Bodies = table.clone(state.Bodies)
	local kept = table.clone(given)
	table.insert(kept, seed)
	after.Bodies[ANY] = kept
	return after, nil
end

-- The any-car bodies the player has been given, as seeds.
function Economy.anyBodiesOwned(state: State): { number }
	return state.Bodies[ANY] or {}
end

-- Buys a body for an owned car without putting it on. Fails with "UnknownCar",
-- "NotOwned", "UnknownBody", "Owned", or "NotEnoughCash".
function Economy.buyBody(state: State, id: string, seed: number, ladder: { Car }): (State?, string?)
	local car = Economy.findCar(ladder, id)
	if not car then
		return nil, "UnknownCar"
	end
	if not table.find(state.Cars, id) then
		return nil, "NotOwned"
	end
	if ownsBody(state, car, seed) then
		return nil, "Owned"
	end
	if not onBodyList(car, seed) then
		return nil, "UnknownBody"
	end
	local price = car.BodyPrice or 0
	if state.Cash < price then
		return nil, "NotEnoughCash"
	end
	local after = table.clone(state)
	after.Cash -= price
	after.Bodies = table.clone(state.Bodies)
	local bought = table.clone(state.Bodies[id] or {})
	table.insert(bought, seed)
	after.Bodies[id] = bought
	return after, nil
end

-- Puts an owned body on an owned car and gets in it, so the body shows right
-- away. Fails with "UnknownCar" or "NotOwned".
function Economy.wearBody(
	state: State,
	id: string,
	seed: number,
	ladder: { Car },
	anyBodies: { Body }?
): (State?, string?)
	local car = Economy.findCar(ladder, id)
	if not car then
		return nil, "UnknownCar"
	end
	if not table.find(state.Cars, id) or not ownsBody(state, car, seed, anyBodies) then
		return nil, "NotOwned"
	end
	local after = table.clone(state)
	after.Worn = table.clone(state.Worn)
	after.Worn[id] = seed
	after.Equipped = id
	return after, nil
end

return Economy
