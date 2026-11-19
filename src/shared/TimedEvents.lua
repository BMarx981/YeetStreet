--!strict
-- TimedEvents (ModuleScript) -> ReplicatedStorage.TimedEvents
-- Which server-wide event is on, from the clock alone, so every server
-- agrees without messaging. Time is cut into slots Every seconds long,
-- counted from the Unix epoch. Each slot starts with the next event in
-- Rotation, on for its first Duration seconds. An override (an admin's
-- `:event`) puts one event on, or none, until its untilTime. Pure.

local TimedEvents = {}

export type Tuning = {
	Every: number, -- seconds from one event's start to the next
	Duration: number, -- seconds each event lasts
	Rotation: { string }, -- event names, taking turns
}

export type Override = {
	name: string?, -- nil for no event
	untilTime: number,
}

export type Now = {
	current: string?, -- the event on now, if any
	endsIn: number, -- seconds until it ends, 0 if none
	next: string, -- the next scheduled event
	startsIn: number, -- seconds until it starts
}

local function eventOf(slot: number, tuning: Tuning): string
	return tuning.Rotation[slot % #tuning.Rotation + 1]
end

-- The events at `time` (Unix seconds).
function TimedEvents.at(time: number, tuning: Tuning, override: Override?): Now
	local slot = math.floor(time / tuning.Every)
	local into = time - slot * tuning.Every
	local current: string? = nil
	local endsIn = 0
	if into < tuning.Duration then
		current = eventOf(slot, tuning)
		endsIn = tuning.Duration - into
	end
	if override and time < override.untilTime then
		current = override.name
		endsIn = if current then override.untilTime - time else 0
	end
	return {
		current = current,
		endsIn = endsIn,
		next = eventOf(slot + 1, tuning),
		startsIn = tuning.Every - into,
	}
end

-- `seconds` as minutes and seconds ("4:12"), rounded up so a countdown
-- reads 0:00 only at the end.
function TimedEvents.clock(seconds: number): string
	local whole = math.max(math.ceil(seconds), 0)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

function TimedEvents.isEvent(name: string, tuning: Tuning): boolean
	return table.find(tuning.Rotation, name) ~= nil
end

return TimedEvents
