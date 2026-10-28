--!strict
-- ReplayClock (ModuleScript) -> ReplicatedStorage.ReplayClock
-- Where a replay is in its clip, and how fast it moves: pause, speed, and
-- seeking from the scrub bar. Pure, see InputAxes.
--
-- Time runs past the clip's end while the last frame holds; the replay is
-- done once it has held for the hold time, unless it is paused. Playing
-- again from the end starts over.
--
-- Like RunTracker, the clock is changed in place.

local ReplayClock = {}

export type Clock = {
	time: number, -- seconds into the clip
	speed: number, -- 1 is real time
	paused: boolean,
	duration: number, -- the clip's length
}

function ReplayClock.new(duration: number): Clock
	return { time = 0, speed = 1, paused = false, duration = duration }
end

-- Moves the clock on by `dt` seconds of real time.
function ReplayClock.advance(clock: Clock, dt: number)
	if not clock.paused then
		clock.time += dt * clock.speed
	end
end

-- Whether the replay is over, having held its last frame for `hold` seconds.
function ReplayClock.done(clock: Clock, hold: number): boolean
	return not clock.paused and clock.time > clock.duration + hold
end

function ReplayClock.togglePause(clock: Clock)
	clock.paused = not clock.paused
	if not clock.paused and clock.time >= clock.duration then
		clock.time = 0
	end
end

-- Jumps to `fraction` (0 to 1) of the way through the clip.
function ReplayClock.seek(clock: Clock, fraction: number)
	clock.time = math.clamp(fraction, 0, 1) * clock.duration
end

-- How far through the clip it is, from 0 to 1.
function ReplayClock.fraction(clock: Clock): number
	if clock.duration <= 0 then
		return 1
	end
	return math.clamp(clock.time / clock.duration, 0, 1)
end

-- The speed after `speed` in `speeds`, wrapping round to the first.
function ReplayClock.nextSpeed(speed: number, speeds: { number }): number
	local at = table.find(speeds, speed)
	return speeds[if at then at % #speeds + 1 else 1]
end

return ReplayClock
