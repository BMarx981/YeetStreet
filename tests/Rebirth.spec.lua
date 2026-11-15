--!strict
local Check = require("./Check")
local Rebirth = require("../src/shared/Rebirth")

local T: Rebirth.Tuning = {
	Needs = { "Axolotl", "Phoenix", "Comet", "Eclipse" },
	PayPerRebirth = 1,
}

local function car(id: string, forSale: boolean?): Rebirth.Car
	return {
		Id = id,
		Name = id,
		Price = 0,
		Caps = { Speed = 10, Jets = 10, Toughness = 10, Grip = 10, Brakes = 10 },
		Bonus = 0,
		Seed = 1,
		Archetype = "pickup",
		Tier = "Junker",
		ForSale = forSale,
	}
end

local LADDER: { Rebirth.Car } = {
	car("Junker"),
	car("Hatchback"),
	car("Speed"),
	car("Axolotl"),
	car("Phoenix"),
	car("Squad", false),
	car("TRex", false),
}

local function state(cars: { string }, equipped: string): Rebirth.State
	return {
		Cash = 90000,
		Levels = { Speed = 30, Jets = 24, Toughness = 12, Grip = 7, Brakes = 3 },
		Cars = cars,
		Equipped = equipped,
		Limiteds = { "FrogCar" },
		Bodies = { Speed = { 7, 8 } },
		Worn = { Speed = 7 },
	}
end

Check.test("the first rebirth needs the first car, then each in turn, then the last forever", function()
	Check.eq(Rebirth.neededCar(0, T), "Axolotl", "rebirth 1")
	Check.eq(Rebirth.neededCar(1, T), "Phoenix", "rebirth 2")
	Check.eq(Rebirth.neededCar(2, T), "Comet", "rebirth 3")
	Check.eq(Rebirth.neededCar(3, T), "Eclipse", "rebirth 4")
	Check.eq(Rebirth.neededCar(4, T), "Eclipse", "rebirth 5")
	Check.eq(Rebirth.neededCar(40, T), "Eclipse", "rebirth 41")
end)

Check.test("a player can rebirth only owning the car the next rebirth needs", function()
	Check.eq(Rebirth.canRebirth(state({ "Junker", "Speed" }, "Speed"), 0, T), false, "no Axolotl")
	Check.eq(Rebirth.canRebirth(state({ "Junker", "Axolotl" }, "Junker"), 0, T), true, "Axolotl")
	Check.eq(Rebirth.canRebirth(state({ "Junker", "Axolotl" }, "Junker"), 1, T), false, "Axolotl at rebirth 2")
	Check.eq(Rebirth.canRebirth(state({ "Junker", "Phoenix" }, "Junker"), 1, T), true, "Phoenix at rebirth 2")
	Check.eq(Rebirth.canRebirth(state({ "Junker", "Comet" }, "Junker"), 5, T), false, "Comet at rebirth 6")
	Check.eq(Rebirth.canRebirth(state({ "Junker", "Eclipse" }, "Junker"), 5, T), true, "Eclipse at rebirth 6")
end)

Check.test("run pay is multiplied by 1 plus the rebirths, with no cap", function()
	Check.eq(Rebirth.payMultiplier(0, T), 1)
	Check.eq(Rebirth.payMultiplier(1, T), 2)
	Check.eq(Rebirth.payMultiplier(2, T), 3)
	Check.eq(Rebirth.payMultiplier(250, T), 251)
end)

Check.test("only cars that are for sale are on the cash ladder", function()
	Check.eq(Rebirth.onCashLadder(LADDER[1]), true, "Junker")
	Check.eq(Rebirth.onCashLadder(LADDER[4]), true, "Axolotl")
	Check.eq(Rebirth.onCashLadder(LADDER[6]), false, "Squad")
	Check.eq(Rebirth.onCashLadder(LADDER[7]), false, "TRex")
end)

Check.test("split lists the cars a rebirth takes and the ones it leaves, without the first car", function()
	local lost, kept = Rebirth.split({ "Junker", "TRex", "Hatchback", "OldCar", "Axolotl", "Squad" }, LADDER)
	Check.eq(table.concat(lost, ","), "Hatchback,Axolotl", "lost")
	Check.eq(table.concat(kept, ","), "TRex,OldCar,Squad", "kept")
end)

Check.test("split of only the first car is empty both ways", function()
	local lost, kept = Rebirth.split({ "Junker" }, LADDER)
	Check.eq(#lost, 0, "lost")
	Check.eq(#kept, 0, "kept")
end)

Check.test("reset clears cash and every upgrade level", function()
	local after = Rebirth.reset(state({ "Junker", "Axolotl" }, "Axolotl"), LADDER)
	Check.eq(after.Cash, 0, "Cash")
	Check.eq(after.Levels.Speed, 0, "Speed")
	Check.eq(after.Levels.Jets, 0, "Jets")
	Check.eq(after.Levels.Toughness, 0, "Toughness")
	Check.eq(after.Levels.Grip, 0, "Grip")
	Check.eq(after.Levels.Brakes, 0, "Brakes")
end)

Check.test("reset drops cash ladder cars and keeps the rest in order, Junker first", function()
	local before = state({ "Junker", "TRex", "Hatchback", "Speed", "Squad", "Axolotl", "Phoenix" }, "Phoenix")
	local after = Rebirth.reset(before, LADDER)
	Check.eq(table.concat(after.Cars, ","), "Junker,TRex,Squad")
end)

Check.test("reset keeps cars no longer on the ladder", function()
	local after = Rebirth.reset(state({ "Junker", "Speed", "OldCar" }, "Speed"), LADDER)
	Check.eq(table.concat(after.Cars, ","), "Junker,OldCar")
end)

Check.test("reset puts the player in the Junker, even from a car they keep", function()
	Check.eq(Rebirth.reset(state({ "Junker", "Axolotl" }, "Axolotl"), LADDER).Equipped, "Junker", "from Axolotl")
	Check.eq(Rebirth.reset(state({ "Junker", "TRex" }, "TRex"), LADDER).Equipped, "Junker", "from TRex")
end)

Check.test("reset keeps limiteds, owned bodies, and the bodies cars wear", function()
	local after = Rebirth.reset(state({ "Junker", "Speed" }, "Speed"), LADDER)
	Check.eq(table.concat(after.Limiteds, ","), "FrogCar", "Limiteds")
	Check.eq(table.concat(after.Bodies.Speed, ","), "7,8", "Bodies")
	Check.eq(after.Worn.Speed, 7, "Worn")
end)

Check.test("reset never changes the state passed in", function()
	local before = state({ "Junker", "Speed", "TRex" }, "Speed")
	Rebirth.reset(before, LADDER)
	Check.eq(before.Cash, 90000, "Cash")
	Check.eq(before.Levels.Speed, 30, "Speed level")
	Check.eq(table.concat(before.Cars, ","), "Junker,Speed,TRex", "Cars")
	Check.eq(before.Equipped, "Speed", "Equipped")
end)

Check.test("rebirth resets when the player owns the needed car", function()
	local after, problem = Rebirth.rebirth(state({ "Junker", "Axolotl", "TRex" }, "Axolotl"), 0, LADDER, T)
	Check.eq(problem, nil, "problem")
	assert(after, "no state")
	Check.eq(after.Cash, 0, "Cash")
	Check.eq(table.concat(after.Cars, ","), "Junker,TRex", "Cars")
end)

Check.test("rebirth fails with NeedsCar without the needed car", function()
	local after, problem = Rebirth.rebirth(state({ "Junker", "Axolotl" }, "Axolotl"), 1, LADDER, T)
	Check.eq(after, nil, "state")
	Check.eq(problem, "NeedsCar", "problem")
end)

Check.test("count keeps a saved whole number of rebirths and starts anything else at 0", function()
	Check.eq(Rebirth.count(3), 3, "3")
	Check.eq(Rebirth.count(0), 0, "0")
	Check.eq(Rebirth.count(nil), 0, "nil")
	Check.eq(Rebirth.count("2"), 0, "string")
	Check.eq(Rebirth.count(-1), 0, "negative")
	Check.eq(Rebirth.count(2.5), 0, "fraction")
	Check.eq(Rebirth.count(0 / 0), 0, "NaN")
	Check.eq(Rebirth.count(math.huge), 0, "infinity")
end)

Check.finish("Rebirth")
