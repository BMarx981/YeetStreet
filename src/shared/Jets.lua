--!strict
-- Jets (ModuleScript) -> ReplicatedStorage.Jets
-- Jet fuel rules. Fuel is measured in seconds of burn. Pure, see InputAxes.

local Jets = {}

-- Burning drains fuel and blocks recharge. Fuel refills only on the ground.
function Jets.stepFuel(
	fuel: number,
	maxFuel: number,
	burning: boolean,
	grounded: boolean,
	recharge: number,
	dt: number
): number
	if burning then
		return math.max(fuel - dt, 0)
	end
	if grounded then
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
