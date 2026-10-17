--!strict
-- Toughness (ModuleScript) -> ReplicatedStorage.Toughness
-- How much a hit hurts the car, and how many parts it knocks off. Pure, see
-- InputAxes. Hits are measured by CarSensor and placed on a slot by Impact.
--
-- Only body hits count: a hit on the underside is a landing on the wheels or
-- belly, which never hurts. Each slot keeps its own running damage, and every
-- BreakDamage of it breaks one part in that slot.

local Toughness = {}

-- Same as Impact.Slot, declared here so this module needs no require.
export type Slot = "nose" | "tail" | "roof" | "underside" | "sides"

export type Tuning = {
	HitThreshold: number,
	DamagePerSpeed: number,
	BreakDamage: number,
}

-- Toughness lost to a hit of `strength` studs per second on `slot`.
function Toughness.damage(strength: number, slot: Slot, tuning: Tuning): number
	if slot == "underside" then
		return 0
	end
	return math.max(strength - tuning.HitThreshold, 0) * tuning.DamagePerSpeed
end

-- Parts to break when a slot's running damage goes from `before` to `after`.
function Toughness.breaks(before: number, after: number, tuning: Tuning): number
	return math.floor(after / tuning.BreakDamage) - math.floor(before / tuning.BreakDamage)
end

return Toughness
