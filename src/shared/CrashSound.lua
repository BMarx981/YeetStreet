--!strict
-- CrashSound (ModuleScript) -> ReplicatedStorage.CrashSound
-- How loud the driver's thud is for a hit, and which wreck sound to play.
-- Hits softer than HitFrom make none, harder ones are louder up to HitFull,
-- and a hit within HitGap of the last thud makes none, so scraping along a
-- wall doesn't rattle. Pure.

local CrashSound = {}

export type Tuning = {
	HitFrom: number, -- hit strength, studs per second
	HitFull: number,
	HitMinVolume: number, -- a fraction of the Hit sound's Volume
	HitGap: number, -- seconds
}

-- The thud's volume for a hit of `strength`, `sinceLast` seconds after the
-- last thud. 0 means no thud.
function CrashSound.hitVolume(strength: number, sinceLast: number, tuning: Tuning): number
	if strength < tuning.HitFrom or sinceLast < tuning.HitGap then
		return 0
	end
	local fraction = math.clamp((strength - tuning.HitFrom) / (tuning.HitFull - tuning.HitFrom), 0, 1)
	return tuning.HitMinVolume + (1 - tuning.HitMinVolume) * fraction
end

-- Which of `count` sounds a random `roll` from 0 to 1 picks.
function CrashSound.pick(count: number, roll: number): number
	return math.clamp(math.floor(roll * count) + 1, 1, count)
end

return CrashSound
