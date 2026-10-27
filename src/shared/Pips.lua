--!strict
-- Pips (ModuleScript) -> ReplicatedStorage.Pips
-- How many pips of a level bar to fill. The bar spans the car's cap, so a
-- 40 cap car shows 4 levels per pip. Any progress lights at least one pip and
-- only a maxed stat lights them all, so the bar never looks empty or done
-- when it isn't.

local Pips = {}

function Pips.filled(level: number, cap: number, count: number): number
	if cap <= 0 or level <= 0 then
		return 0
	elseif level >= cap then
		return count
	end
	return math.clamp(math.floor(level / cap * count), 1, count - 1)
end

return Pips
