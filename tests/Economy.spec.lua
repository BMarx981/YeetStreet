--!strict
local Check = require("./Check")
local Economy = require("../src/shared/Economy")

local LADDER: { Economy.Car } = {
	{
		Id = "Junker",
		Name = "Junker",
		Price = 0,
		Bonus = 0,
		Caps = { Speed = 5, Jets = 5, Toughness = 5, Grip = 5, Brakes = 5 },
		Seed = 1,
		Archetype = "pickup",
		Tier = "Junker",
	},
	{
		Id = "Hatchback",
		Name = "Hatchback",
		Price = 5000,
		Bonus = 4,
		Caps = { Speed = 10, Jets = 10, Toughness = 10, Grip = 10, Brakes = 10 },
		Seed = 2,
		Archetype = "hatch",
		Tier = "Street",
	},
	{
		Id = "Muscle",
		Name = "Muscle Car",
		Price = 25000,
		Bonus = 8,
		Caps = { Speed = 15, Jets = 12, Toughness = 15, Grip = 12, Brakes = 12 },
		Seed = 3,
		Archetype = "muscle",
		Tier = "Sports",
		Bodies = { { Seed = 4, Archetype = "muscle" }, { Seed = 5, Archetype = "wedge" } },
		BodyPrice = 1000,
	},
}

local COSTS: Economy.CostTuning = {
	CostBase = 250,
	CostGrowth = 1.25,
	CostRound = 10,
}

local BASE: Economy.CarStats = {
	TopSpeed = 110,
	JetPower = 150,
	JetFuel = 3,
	FuelRecharge = 1.5,
	TurnRate = 4,
	Grip = 1.3,
	RollUnlocked = true,
	Toughness = 100,
	BrakePower = 10,
}

local STEPS: Economy.Steps = {
	TopSpeed = 6,
	JetPower = 8,
	JetFuel = 0.3,
	FuelRecharge = 0.1,
	TurnRate = 0.1,
	Toughness = 15,
	Grip = 0.03,
	BrakePower = 4,
}

local function levels(speed: number, jets: number, toughness: number, grip: number, brakes: number?): Economy.Levels
	return { Speed = speed, Jets = jets, Toughness = toughness, Grip = grip, Brakes = brakes or 0 }
end

local function state(cash: number, lv: Economy.Levels, cars: { string }, equipped: string): Economy.State
	return { Cash = cash, Levels = lv, Cars = cars, Equipped = equipped }
end

Check.test("a new player has no cash, no levels, and the first ladder car", function()
	local s = Economy.newState(LADDER)
	Check.eq(s.Cash, 0)
	Check.eq(s.Levels.Speed + s.Levels.Jets + s.Levels.Toughness + s.Levels.Grip + s.Levels.Brakes, 0, "levels")
	Check.eq(#s.Cars, 1, "cars owned")
	Check.eq(s.Cars[1], "Junker")
	Check.eq(s.Equipped, "Junker")
end)

Check.test("a run's score pays out as whole cash", function()
	Check.eq(Economy.payout(440, 1), 440)
	Check.eq(Economy.payout(2100.7, 1), 2100)
	Check.eq(Economy.payout(1000, 0.5), 500)
	Check.eq(Economy.payout(-10, 1), 0, "never negative")
end)

Check.test("each level costs CostGrowth times the last, rounded", function()
	Check.eq(Economy.upgradeCost(0, COSTS), 250, "level 1")
	Check.eq(Economy.upgradeCost(1, COSTS), 310, "level 2 (312.5)")
	Check.eq(Economy.upgradeCost(4, COSTS), 610, "level 5 (610.4)")
	Check.eq(Economy.upgradeCost(9, COSTS), 1860, "level 10 (1862.6)")
end)

Check.test("level 0 stats are the base car", function()
	local stats = Economy.stats(BASE, levels(0, 0, 0, 0), LADDER[1], STEPS)
	Check.eq(stats.TopSpeed, 110)
	Check.eq(stats.JetPower, 150)
	Check.eq(stats.JetFuel, 3)
	Check.eq(stats.FuelRecharge, 1.5)
	Check.eq(stats.TurnRate, 4)
	Check.eq(stats.Toughness, 100)
	Check.eq(stats.Grip, 1.3)
	Check.eq(stats.BrakePower, 10)
	Check.eq(stats.RollUnlocked, true)
end)

Check.test("each stat's levels raise only its own real stats", function()
	local stats = Economy.stats(BASE, levels(2, 3, 4, 5, 3), LADDER[1], STEPS)
	Check.near(stats.TopSpeed, 122, "Speed")
	Check.near(stats.JetPower, 174, "Jets: power")
	Check.near(stats.JetFuel, 3.9, "Jets: fuel")
	Check.near(stats.FuelRecharge, 1.8, "Jets: recharge")
	Check.near(stats.TurnRate, 4.3, "Jets: turn rate")
	Check.near(stats.Toughness, 160, "Toughness")
	Check.near(stats.Grip, 1.45, "Grip")
	Check.near(stats.BrakePower, 22, "Brakes")
end)

Check.test("levels above the car's cap count only up to the cap", function()
	local stats = Economy.stats(BASE, levels(10, 10, 10, 10, 10), LADDER[1], STEPS)
	Check.near(stats.TopSpeed, 140, "Speed capped at 5")
	Check.near(stats.Toughness, 175, "Toughness capped at 5")
	Check.near(stats.BrakePower, 30, "Brakes capped at 5")
	local muscle = Economy.stats(BASE, levels(20, 20, 20, 20), LADDER[3], STEPS)
	Check.near(muscle.TopSpeed, 248, "Speed cap 15, plus 8 free")
	Check.near(muscle.JetPower, 310, "Jets cap 12, plus 8 free")
end)

Check.test("a car's free levels add to every stat on top of the levels bought", function()
	local stats = Economy.stats(BASE, levels(0, 0, 0, 0), LADDER[2], STEPS)
	Check.near(stats.TopSpeed, 134, "Speed 0 + 4")
	Check.near(stats.JetPower, 182, "Jets 0 + 4")
	Check.near(stats.TurnRate, 4.4, "Jets 0 + 4")
	Check.near(stats.Toughness, 160, "Toughness 0 + 4")
	Check.near(stats.Grip, 1.42, "Grip 0 + 4")
	Check.near(stats.BrakePower, 26, "Brakes 0 + 4")
	local maxed = Economy.stats(BASE, levels(10, 10, 10, 10), LADDER[2], STEPS)
	Check.near(maxed.TopSpeed, 194, "the cap limits levels bought, not free ones: 10 + 4")
end)

Check.test("free levels beat the last car's max right away", function()
	local junker = Economy.stats(BASE, levels(5, 5, 5, 5), LADDER[1], STEPS)
	local hatchback = Economy.stats(BASE, levels(5, 5, 5, 5), LADDER[2], STEPS)
	Check.eq(hatchback.JetPower > junker.JetPower, true)
end)

Check.test("look levels are the levels the stats count: capped, plus free levels", function()
	local junker = Economy.lookLevels(levels(2, 9, 0, 5, 7), LADDER[1])
	Check.eq(junker.Speed, 2, "Speed under the cap")
	Check.eq(junker.Jets, 5, "Jets capped at 5")
	Check.eq(junker.Toughness, 0, "Toughness 0")
	Check.eq(junker.Grip, 5, "Grip at the cap")
	Check.eq(junker.Brakes, 5, "Brakes capped at 5")
	local muscle = Economy.lookLevels(levels(20, 20, 3, 0), LADDER[3])
	Check.eq(muscle.Speed, 23, "Speed cap 15, plus 8 free")
	Check.eq(muscle.Jets, 20, "Jets cap 12, plus 8 free")
	Check.eq(muscle.Toughness, 11, "Toughness 3, plus 8 free")
	Check.eq(muscle.Grip, 8, "Grip 0, plus 8 free")
	Check.eq(muscle.Brakes, 8, "Brakes 0, plus 8 free")
end)

Check.test("buying a level spends its cost and raises that stat", function()
	local before = state(1000, levels(0, 0, 0, 0), { "Junker" }, "Junker")
	local after, reason = Economy.upgrade(before, "Jets", LADDER, COSTS)
	assert(after, reason)
	Check.eq(after.Cash, 750)
	Check.eq(after.Levels.Jets, 1)
	Check.eq(after.Levels.Speed, 0, "other stats unchanged")
	Check.eq(before.Cash, 1000, "the old state is not changed")
	Check.eq(before.Levels.Jets, 0, "the old levels are not changed")
end)

Check.test("brakes are bought like any other stat", function()
	local after, reason =
		Economy.upgrade(state(1000, levels(0, 0, 0, 0), { "Junker" }, "Junker"), "Brakes", LADDER, COSTS)
	assert(after, reason)
	Check.eq(after.Cash, 750)
	Check.eq(after.Levels.Brakes, 1)
	local _, capped =
		Economy.upgrade(state(99999, levels(0, 0, 0, 0, 5), { "Junker" }, "Junker"), "Brakes", LADDER, COSTS)
	Check.eq(capped, "AtCap")
end)

Check.test("a level costs what the next level up is priced at", function()
	local after = Economy.upgrade(state(1000, levels(4, 0, 0, 0), { "Junker" }, "Junker"), "Speed", LADDER, COSTS)
	assert(after)
	Check.eq(after.Cash, 390)
	Check.eq(after.Levels.Speed, 5)
end)

Check.test("a level needs enough cash", function()
	local after, reason = Economy.upgrade(state(249, levels(0, 0, 0, 0), { "Junker" }, "Junker"), "Grip", LADDER, COSTS)
	Check.eq(after, nil)
	Check.eq(reason, "NotEnoughCash")
end)

Check.test("a level stops at the equipped car's cap", function()
	local s = state(99999, levels(5, 0, 0, 0), { "Junker", "Hatchback" }, "Junker")
	local after, reason = Economy.upgrade(s, "Speed", LADDER, COSTS)
	Check.eq(after, nil)
	Check.eq(reason, "AtCap")
	s.Equipped = "Hatchback"
	local raised = Economy.upgrade(s, "Speed", LADDER, COSTS)
	assert(raised)
	Check.eq(raised.Levels.Speed, 6, "a better car raises the ceiling")
end)

Check.test("buying a car spends its price and adds it without equipping it", function()
	local before = state(6000, levels(0, 0, 0, 0), { "Junker" }, "Junker")
	local after, reason = Economy.buyCar(before, "Hatchback", LADDER)
	assert(after, reason)
	Check.eq(after.Cash, 1000)
	Check.eq(#after.Cars, 2)
	Check.eq(after.Cars[2], "Hatchback")
	Check.eq(after.Equipped, "Junker")
	Check.eq(#before.Cars, 1, "the old state is not changed")
end)

Check.test("a car can't be bought twice, without the cash, or if it isn't on the ladder", function()
	local s = state(100000, levels(0, 0, 0, 0), { "Junker" }, "Junker")
	local _, owned = Economy.buyCar(s, "Junker", LADDER)
	Check.eq(owned, "Owned")
	local _, unknown = Economy.buyCar(s, "Spaceship", LADDER)
	Check.eq(unknown, "UnknownCar")
	s.Cash = 4999
	local _, broke = Economy.buyCar(s, "Hatchback", LADDER)
	Check.eq(broke, "NotEnoughCash")
end)

Check.test("a car that isn't for sale can't be bought, even for free", function()
	local prize = table.clone(LADDER[2])
	prize.Id = "Prize"
	prize.Price = 0
	prize.ForSale = false
	local ladder = table.clone(LADDER)
	table.insert(ladder, prize)
	local s = state(100000, levels(0, 0, 0, 0), { "Junker" }, "Junker")
	local after, reason = Economy.buyCar(s, "Prize", ladder)
	Check.eq(after, nil)
	Check.eq(reason, "NotForSale")
	local bought = Economy.buyCar(s, "Hatchback", ladder)
	assert(bought, "a car without ForSale is for sale")
end)

Check.test("only an owned car can be equipped", function()
	local s = state(0, levels(0, 0, 0, 0), { "Junker", "Hatchback" }, "Junker")
	local after = Economy.equip(s, "Hatchback")
	assert(after)
	Check.eq(after.Equipped, "Hatchback")
	Check.eq(s.Equipped, "Junker", "the old state is not changed")
	local none, reason = Economy.equip(s, "Muscle")
	Check.eq(none, nil)
	Check.eq(reason, "NotOwned")
end)

Check.test("findCar looks a car up by id", function()
	local car = Economy.findCar(LADDER, "Muscle")
	assert(car)
	Check.eq(car.Price, 25000)
	Check.eq(Economy.findCar(LADDER, "Spaceship"), nil)
end)

Check.test("level reads one stat by name", function()
	local lv = levels(1, 2, 3, 4, 5)
	Check.eq(Economy.level(lv, "Speed"), 1)
	Check.eq(Economy.level(lv, "Jets"), 2)
	Check.eq(Economy.level(lv, "Toughness"), 3)
	Check.eq(Economy.level(lv, "Grip"), 4)
	Check.eq(Economy.level(lv, "Brakes"), 5)
end)

Check.test("reconcile keeps a valid saved state", function()
	local saved = state(1234, levels(3, 2, 1, 0, 4), { "Junker", "Hatchback" }, "Hatchback")
	local s = Economy.reconcile(saved, LADDER)
	Check.eq(s.Cash, 1234)
	Check.eq(s.Levels.Speed, 3)
	Check.eq(s.Levels.Jets, 2)
	Check.eq(s.Levels.Toughness, 1)
	Check.eq(s.Levels.Brakes, 4)
	Check.eq(#s.Cars, 2)
	Check.eq(s.Equipped, "Hatchback")
end)

Check.test("reconcile starts fresh from nothing or junk", function()
	local function checkFresh(saved: any)
		local s = Economy.reconcile(saved, LADDER)
		Check.eq(s.Cash, 0)
		Check.eq(s.Cars[1], "Junker")
		Check.eq(s.Equipped, "Junker")
	end
	checkFresh(nil)
	checkFresh("junk")
	checkFresh(5)
end)

Check.test("reconcile fills missing or bad fields", function()
	local s = Economy.reconcile({ Cash = -5, Levels = { Speed = 2, Jets = "x" } }, LADDER)
	Check.eq(s.Cash, 0, "negative cash")
	Check.eq(s.Levels.Speed, 2)
	Check.eq(s.Levels.Jets, 0, "not a number")
	Check.eq(s.Levels.Grip, 0, "missing")
	Check.eq(s.Levels.Brakes, 0, "saved before brakes existed")
	Check.eq(s.Equipped, "Junker")
end)

Check.test("reconcile always owns the first car and drops repeats", function()
	local s = Economy.reconcile({ Cars = { "Muscle", "Muscle", 7 }, Equipped = "Muscle" }, LADDER)
	Check.eq(#s.Cars, 2)
	Check.eq(s.Cars[1], "Junker")
	Check.eq(s.Cars[2], "Muscle")
	Check.eq(s.Equipped, "Muscle")
end)

Check.test("reconcile keeps cars no longer on the ladder but won't equip one", function()
	local s = Economy.reconcile({ Cars = { "Junker", "OldCar" }, Equipped = "OldCar" }, LADDER)
	Check.eq(s.Cars[2], "OldCar")
	Check.eq(s.Equipped, "Junker")
	local unowned = Economy.reconcile({ Cars = { "Junker" }, Equipped = "Muscle" }, LADDER)
	Check.eq(unowned.Equipped, "Junker", "not owned")
end)

local function muscleOwner(cash: number): Economy.State
	local s = Economy.newState(LADDER)
	s.Cash = cash
	table.insert(s.Cars, "Muscle")
	return s
end

Check.test("a car wears its own seed until another body is put on", function()
	local car = Economy.findCar(LADDER, "Muscle") :: Economy.Car
	Check.eq(Economy.wornSeed(muscleOwner(0), car), 3)
end)

Check.test("buyBody takes the price and keeps the old state unchanged", function()
	local s = muscleOwner(1500)
	local after = Economy.buyBody(s, "Muscle", 4, LADDER) :: Economy.State
	Check.eq(after.Cash, 500)
	Check.eq(after.Bodies.Muscle[1], 4)
	Check.eq(s.Cash, 1500, "old cash")
	Check.eq(s.Bodies.Muscle, nil, "old bodies")
	local car = Economy.findCar(LADDER, "Muscle") :: Economy.Car
	Check.eq(Economy.wornSeed(after, car), 3, "buying doesn't put it on")
end)

Check.test("buyBody refuses with a reason", function()
	local _, unknownCar = Economy.buyBody(muscleOwner(1500), "Nope", 4, LADDER)
	Check.eq(unknownCar, "UnknownCar")
	local _, noCar = Economy.buyBody(Economy.newState(LADDER), "Muscle", 4, LADDER)
	Check.eq(noCar, "NotOwned", "needs the car first")
	local _, offList = Economy.buyBody(muscleOwner(1500), "Muscle", 99, LADDER)
	Check.eq(offList, "UnknownBody")
	local _, noList = Economy.buyBody(muscleOwner(1500), "Junker", 4, LADDER)
	Check.eq(noList, "UnknownBody", "a car with no list")
	local _, stock = Economy.buyBody(muscleOwner(1500), "Muscle", 3, LADDER)
	Check.eq(stock, "Owned", "the car's own seed comes with it")
	local _, poor = Economy.buyBody(muscleOwner(999), "Muscle", 4, LADDER)
	Check.eq(poor, "NotEnoughCash")
	local bought = Economy.buyBody(muscleOwner(1500), "Muscle", 4, LADDER) :: Economy.State
	local _, again = Economy.buyBody(bought, "Muscle", 4, LADDER)
	Check.eq(again, "Owned")
end)

Check.test("wearBody puts on an owned body and can go back to the car's own", function()
	local car = Economy.findCar(LADDER, "Muscle") :: Economy.Car
	local bought = Economy.buyBody(muscleOwner(1500), "Muscle", 4, LADDER) :: Economy.State
	local worn = Economy.wearBody(bought, "Muscle", 4, LADDER) :: Economy.State
	Check.eq(Economy.wornSeed(worn, car), 4)
	Check.eq(Economy.wornSeed(bought, car), 3, "old state unchanged")
	local back = Economy.wearBody(worn, "Muscle", 3, LADDER) :: Economy.State
	Check.eq(Economy.wornSeed(back, car), 3)
end)

Check.test("wearBody also gets in that car, so the body shows right away", function()
	local bought = Economy.buyBody(muscleOwner(1500), "Muscle", 4, LADDER) :: Economy.State
	Check.eq(bought.Equipped, "Junker", "buying doesn't")
	local worn = Economy.wearBody(bought, "Muscle", 4, LADDER) :: Economy.State
	Check.eq(worn.Equipped, "Muscle")
	Check.eq(bought.Equipped, "Junker", "old state unchanged")
end)

Check.test("wearBody refuses bodies that aren't owned", function()
	local _, unknownCar = Economy.wearBody(muscleOwner(0), "Nope", 4, LADDER)
	Check.eq(unknownCar, "UnknownCar")
	local _, noBody = Economy.wearBody(muscleOwner(0), "Muscle", 4, LADDER)
	Check.eq(noBody, "NotOwned")
	local _, noCar = Economy.wearBody(Economy.newState(LADDER), "Muscle", 3, LADDER)
	Check.eq(noCar, "NotOwned", "needs the car first")
end)

Check.test("withSeed changes only the looks", function()
	local car = Economy.findCar(LADDER, "Muscle") :: Economy.Car
	local dressed = Economy.withSeed(car, 5)
	Check.eq(dressed.Seed, 5)
	Check.eq(dressed.Archetype, "wedge", "a body can be another car type")
	Check.eq(dressed.Tier, "Sports")
	Check.eq(Economy.withSeed(car, 3).Archetype, "muscle", "its own seed")
	Check.eq(Economy.withSeed(car, 99).Archetype, "muscle", "off the list")
	Check.eq(car.Archetype, "muscle", "the ladder's car is unchanged")
	Check.eq(dressed.Id, "Muscle")
	Check.eq(dressed.Caps, car.Caps, "same caps")
	Check.eq(dressed.Bonus, car.Bonus, "same bonus")
	Check.eq(car.Seed, 3, "the ladder's car is unchanged")
end)

Check.test("reconcile keeps saved bodies and starts old saves with none", function()
	local car = Economy.findCar(LADDER, "Muscle") :: Economy.Car
	local old = Economy.reconcile({ Cars = { "Muscle" } }, LADDER)
	Check.eq(old.Bodies.Muscle, nil, "saved before bodies existed")
	Check.eq(Economy.wornSeed(old, car), 3)
	local s = Economy.reconcile({
		Cars = { "Muscle" },
		Bodies = { Muscle = { 4, 4, "x", 5 }, Junker = "bad", [7] = { 4 } },
		Worn = { Muscle = 5, Junker = "bad" },
	}, LADDER)
	Check.eq(#s.Bodies.Muscle, 2, "repeats and junk dropped")
	Check.eq(s.Bodies.Junker, nil, "not a list")
	Check.eq(Economy.wornSeed(s, car), 5)
	Check.eq(s.Worn.Junker, nil, "not a number")
end)

Check.test("a worn body that isn't owned or left the list falls back to the car's own", function()
	local car = Economy.findCar(LADDER, "Muscle") :: Economy.Car
	local notOwned = Economy.reconcile({ Cars = { "Muscle" }, Worn = { Muscle = 4 } }, LADDER)
	Check.eq(Economy.wornSeed(notOwned, car), 3)
	local gone = Economy.reconcile({ Cars = { "Muscle" }, Bodies = { Muscle = { 99 } }, Worn = { Muscle = 99 } }, LADDER)
	Check.eq(gone.Bodies.Muscle[1], 99, "kept, like a car off the ladder")
	Check.eq(Economy.wornSeed(gone, car), 3)
end)

Check.finish("Economy")
