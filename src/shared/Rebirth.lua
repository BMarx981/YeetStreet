--!strict
-- Rebirth (ModuleScript) -> ReplicatedStorage.Rebirth
-- Rebirth trades the cash ladder for a bigger run pay multiplier. Pure, see
-- InputAxes. Values live in Tuning.Rebirth.
--
-- Each rebirth needs a car: the first of Needs for the first rebirth, the
-- next for the next, and the last one for every rebirth after that.
--
-- A rebirth resets cash, every upgrade level, and every car on the cash
-- ladder, and puts the player back in the first ladder car. A car is on the
-- cash ladder unless it is never for sale (ForSale = false: the dino cars and
-- the invite prize). Everything else in the state stays: limiteds, owned
-- bodies (worn again once their car is bought back), and cars no longer on the
-- ladder. Data outside the economy state (best score, invites, the obby prize)
-- is not touched here.
-- Rebirths return a new state and never change the one passed in.

local Rebirth = {}

-- Same fields as Tuning.Rebirth, declared here so this module needs no require.
export type Tuning = {
	Needs: { string }, -- car ids, by rebirth; the last repeats forever
	PayPerRebirth: number, -- run pay multiplier added by each rebirth
}

type Levels = {
	Speed: number,
	Jets: number,
	Toughness: number,
	Grip: number,
	Brakes: number,
}

-- Same fields as Economy.Car, so Tuning.Ladder can be passed in. Only Id and
-- ForSale are read.
export type Car = {
	Id: string,
	Name: string,
	Price: number,
	Caps: Levels,
	Bonus: number,
	Seed: number,
	Archetype: string,
	Tier: string,
	ForSale: boolean?,
	Look: string?,
	Bodies: { { Seed: number, Archetype: string } }?,
	BodyPrice: number?,
}

-- Same fields as Economy.State.
export type State = {
	Cash: number,
	Levels: Levels,
	Cars: { string },
	Equipped: string,
	Limiteds: { string },
	Bodies: { [string]: { number } },
	Worn: { [string]: number },
}

-- The rebirths in a save: a whole number, 0 or more, or 0 if it isn't one.
function Rebirth.count(saved: any): number
	if typeof(saved) == "number" and saved >= 0 and saved < math.huge and saved % 1 == 0 then
		return saved
	end
	return 0
end

-- The car id a player with `rebirths` so far must own to rebirth again.
function Rebirth.neededCar(rebirths: number, tuning: Tuning): string
	local needs = tuning.Needs
	return needs[math.clamp(rebirths + 1, 1, #needs)]
end

function Rebirth.canRebirth(state: State, rebirths: number, tuning: Tuning): boolean
	return table.find(state.Cars, Rebirth.neededCar(rebirths, tuning)) ~= nil
end

-- Run pay is multiplied by this. Flat rewards are not.
function Rebirth.payMultiplier(rebirths: number, tuning: Tuning): number
	return 1 + tuning.PayPerRebirth * rebirths
end

function Rebirth.onCashLadder(car: Car): boolean
	return car.ForSale ~= false
end

local function findCar(ladder: { Car }, id: string): Car?
	for _, car in ladder do
		if car.Id == id then
			return car
		end
	end
	return nil
end

-- Of the owned `cars`, the ones a rebirth takes and the ones it leaves, in
-- the order owned. Neither lists the first ladder car, which is always owned.
function Rebirth.split(cars: { string }, ladder: { Car }): ({ string }, { string })
	local first = ladder[1].Id
	local lost: { string } = {}
	local kept: { string } = {}
	for _, id in cars do
		local car = findCar(ladder, id)
		if id == first then
			continue
		elseif car and Rebirth.onCashLadder(car) then
			table.insert(lost, id)
		else
			table.insert(kept, id)
		end
	end
	return lost, kept
end

-- The state after a rebirth, without checking whether the player may.
function Rebirth.reset(state: State, ladder: { Car }): State
	local first = ladder[1].Id
	local _, kept = Rebirth.split(state.Cars, ladder)
	local cars = { first }
	table.move(kept, 1, #kept, 2, cars)
	local after = table.clone(state)
	after.Cash = 0
	after.Levels = { Speed = 0, Jets = 0, Toughness = 0, Grip = 0, Brakes = 0 }
	after.Cars = cars
	after.Equipped = first
	return after
end

-- Rebirths a player with `rebirths` so far. Fails with "NeedsCar". The caller
-- adds one to the player's rebirths.
function Rebirth.rebirth(state: State, rebirths: number, ladder: { Car }, tuning: Tuning): (State?, string?)
	if not Rebirth.canRebirth(state, rebirths, tuning) then
		return nil, "NeedsCar"
	end
	return Rebirth.reset(state, ladder), nil
end

return Rebirth
