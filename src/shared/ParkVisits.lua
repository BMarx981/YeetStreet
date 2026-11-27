--!strict
-- ParkVisits (ModuleScript) -> ReplicatedStorage.ParkVisits
-- One player's visits to parks, for the ParkTime analytics event
-- (AnalyticsWatch). It is fed where the player is now, a park's name or ""
-- between parks, and says when a visit ends: on being seen in another park,
-- or after Grace seconds seen in none, so clipping a park's edge doesn't split
-- a visit. A visit lasts from when it started to when the player was last
-- seen in the park, and one shorter than MinSeconds, such as driving through,
-- ends unreported. Pure.

local ParkVisits = {}

export type Tuning = {
	MinSeconds: number,
	Grace: number,
}

export type State = {
	park: string?, -- the visit in progress
	since: number,
	lastSeen: number,
}

export type Visit = {
	park: string,
	seconds: number,
}

function ParkVisits.new(): State
	return { park = nil, since = 0, lastSeen = 0 }
end

-- Ends the visit in progress, returning it if it was long enough.
local function close(state: State, tuning: Tuning): Visit?
	local park = state.park
	state.park = nil
	if not park then
		return nil
	end
	local seconds = state.lastSeen - state.since
	return if seconds >= tuning.MinSeconds then { park = park, seconds = seconds } else nil
end

-- The player is in `park` ("" for none) at `now` seconds. Returns the visit
-- that just ended, if one did and was long enough.
function ParkVisits.step(state: State, park: string, now: number, tuning: Tuning): Visit?
	if park ~= "" and park == state.park then
		state.lastSeen = now
		return nil
	end
	local ended: Visit? = nil
	if state.park and (park ~= "" or now - state.lastSeen >= tuning.Grace) then
		ended = close(state, tuning)
	end
	if park ~= "" and not state.park then
		state.park = park
		state.since = now
		state.lastSeen = now
	end
	return ended
end

-- Ends the visit in progress, as when the player leaves the game.
function ParkVisits.finish(state: State, tuning: Tuning): Visit?
	return close(state, tuning)
end

return ParkVisits
