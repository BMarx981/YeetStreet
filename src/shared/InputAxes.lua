--!strict
-- InputAxes (ModuleScript) -> ReplicatedStorage.InputAxes
-- Turns raw keyboard, gamepad, and touch state into -1..1 axes. Pure: no
-- services, so tests/ can run it under the luau CLI.

local InputAxes = {}

function InputAxes.fromKeys(negative: boolean, positive: boolean): number
	return (if positive then 1 else 0) - (if negative then 1 else 0)
end

-- Zero inside the zone, then rescaled so the edge of the zone reads 0 and full
-- deflection still reads 1.
function InputAxes.deadzone(value: number, zone: number): number
	local magnitude = math.abs(value)
	if magnitude <= zone then
		return 0
	end
	return math.sign(value) * math.min((magnitude - zone) / (1 - zone), 1)
end

function InputAxes.combine(values: { number }): number
	local total = 0
	for _, value in values do
		total += value
	end
	return math.clamp(total, -1, 1)
end

return InputAxes
