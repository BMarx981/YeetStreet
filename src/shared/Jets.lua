--!strict
-- Jets (ModuleScript) -> ReplicatedStorage.Jets
-- Jet fuel rules. Fuel is measured in seconds of burn. Pure, see InputAxes.

local Jets = {}

-- Burning drains fuel and blocks recharge. Fuel refills only while `refilling`:
-- on the ground, or in a HeliCar flying on its rotor.
function Jets.stepFuel(
	fuel: number,
	maxFuel: number,
	burning: boolean,
	refilling: boolean,
	recharge: number,
	dt: number
): number
	if burning then
		return math.max(fuel - dt, 0)
	end
	if refilling then
		return math.min(fuel + recharge * dt, maxFuel)
	end
	return fuel
end

-- A running burn continues until the tank is empty, but a new burn needs at
-- least `relight` fuel. Without that, holding the button on the ground with an
-- empty tank would stutter the jet on and off every frame as it refills.
function Jets.canBurn(held: boolean, fuel: number, wasBurning: boolean, relight: number): boolean
	if not held then
		return false
	end
	if wasBurning then
		return fuel > 0
	end
	return fuel >= relight
end

return Jets
