--!strict
-- Trails (ModuleScript) -> ReplicatedStorage.Trails
-- Car trails: which one a car wears, and when it shows. Pure, see InputAxes.
-- Values live in Tuning.Trails.
--
-- A car wears the newest trail its player has earned. For now that is the
-- rebirth trail, whose look steps through Tuning.Trails.Rebirth with each
-- rebirth and cycles after the last. The trail shows only in the air, once
-- the car has been up for a lift delay, so bumps and small hops don't light
-- it.

local Trails = {}

-- How long a car has been in the air.
export type Air = {
	aloft: number, -- seconds since it last had ground under it
}

-- The trail look id for a player with `rebirths`, from `looks` in order; nil
-- before the first rebirth.
function Trails.forRebirths(rebirths: number, looks: { string }): string?
	if rebirths < 1 or #looks == 0 then
		return nil
	end
	return looks[(rebirths - 1) % #looks + 1]
end

function Trails.newAir(): Air
	return { aloft = 0 }
end

-- Moves `air` on by `dt`, `grounded` or not, and says whether the trail
-- shows: once the car has been up for `liftDelay` seconds, until it lands.
function Trails.step(air: Air, grounded: boolean, dt: number, liftDelay: number): boolean
	if grounded then
		air.aloft = 0
		return false
	end
	air.aloft += dt
	return air.aloft >= liftDelay - 1e-9
end

return Trails
